// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IZKProofVerifier} from "../../interfaces/IZKProofVerifier.sol";
import {AVAAuthorityMatrix} from "../../core/AVAAuthorityMatrix.sol";
import {AVACapabilityKeys} from "../../core/AVACapabilityKeys.sol";
import {AVACoreRulePackageRegistry} from "../../core/AVACoreRulePackageRegistry.sol";
import {AVACoreTypes} from "../../core/AVACoreTypes.sol";
import {AVADisclosurePolicyRegistry} from "../../core/AVADisclosurePolicyRegistry.sol";
import {AVAEvidenceRegistry} from "../../core/AVAEvidenceRegistry.sol";
import {AVAGovernanceKernel} from "../../core/AVAGovernanceKernel.sol";
import {AVAIdentityRegistry} from "../../core/AVAIdentityRegistry.sol";
import {IAVAApplicationModule} from "../../interfaces/IAVAApplicationModule.sol";
import {IAVAAntiAbusePolicyModule} from "../../core/interfaces/IAVACoreRuleModules.sol";
import {AVAExtensionRecordBase} from "../shared/AVAExtensionRecordBase.sol";
import {IAVAExtensionPolicyModule} from "../shared/IAVAExtensionPolicyModule.sol";

contract AVAPrivacyProofExtension is AVAExtensionRecordBase {
    bytes32 public constant PROOF_CONTEXT_DOMAIN = keccak256("ava.extension.privacy-proof.context.v1");
    bytes32 public constant NULLIFIER_DOMAIN = keccak256("ava.extension.privacy-proof.nullifier.v1");
    bytes32 public constant PROOF_RECORD_TYPE = keccak256("ava.extension.privacy-proof.record.v1");
    bytes32 public constant CHALLENGE_PROOF_CONTEXT_DOMAIN =
        keccak256("ava.extension.privacy-proof.challenge-filing-context.v1");
    bytes32 public constant CHALLENGE_PROOF_SCOPE = keccak256("ava.extension.challenge-filing-proof.v1");

    struct ProofInput {
        uint256 recognisedStateId;
        bytes32 roleKey;
        bytes32 authorityId;
        bytes32 subjectId;
        uint256 evidenceId;
        bytes32 scopeKey;
        bytes32 subjectCommitment;
        IZKProofVerifier.SchnorrProof proof;
        string uri;
    }

    struct ChallengeProofInput {
        uint256 packageId;
        uint256 recognisedStateId;
        bytes32 roleKey;
        bytes32 authorityId;
        uint256 evidenceId;
        uint256 disclosurePolicyId;
        IZKProofVerifier.SchnorrProof proof;
        string uri;
    }

    struct ChallengeProofMatchInput {
        uint256 proofReceiptId;
        uint256 packageId;
        uint256 recognisedStateId;
        bytes32 subjectId;
        uint256 evidenceId;
        uint256 disclosurePolicyId;
        bytes32 roleKey;
    }

    struct ChallengeProofModules {
        AVACoreRulePackageRegistry.VerifiedPackageContext rulePackage;
        IAVAApplicationModule application;
        IAVAExtensionPolicyModule privacyProof;
        IAVAAntiAbusePolicyModule antiAbuse;
    }

    struct ProofReceipt {
        uint256 id;
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        uint256 recognisedStateId;
        uint256 recognisedStateTransitionId;
        bytes32 subjectId;
        uint256 evidenceId;
        uint256 disclosurePolicyId;
        bytes32 scopeKey;
        bytes32 subjectCommitment;
        address verifier;
        bytes32 proofDomainHash;
        bytes32 contextHash;
        bytes32 nullifierHash;
        bytes32 proofHash;
        bytes32 authorityId;
        address registeredBy;
        uint64 registeredAt;
        string uri;
    }

    IZKProofVerifier public immutable VERIFIER;
    bytes32 public immutable PROOF_DOMAIN_HASH;
    bytes32 public immutable VERIFIER_CODE_HASH;

    mapping(uint256 => ProofReceipt) private proofReceipts;
    mapping(bytes32 => uint256) public proofReceiptIdByContextHash;
    mapping(bytes32 => uint256) public proofReceiptIdByNullifierHash;
    mapping(bytes32 => uint256) public challengeProofReceiptIdByGateKey;
    mapping(uint256 => bool) public isChallengeFilingProof;
    mapping(uint256 => uint256) public targetPackageIdByProofReceipt;
    uint256 public nextProofReceiptId = 1;

    event PrivacyProofReceiptRecorded(
        uint256 indexed proofReceiptId,
        bytes32 indexed appId,
        bytes32 indexed subjectId,
        uint256 packageId,
        uint256 recognisedStateId,
        bytes32 contextHash,
        bytes32 nullifierHash,
        address registeredBy
    );

    constructor(
        AVAGovernanceKernel governanceKernel_,
        AVAAuthorityMatrix authorityMatrix_,
        AVAIdentityRegistry identityRegistry_,
        AVACoreRulePackageRegistry rulePackageRegistry_,
        AVAEvidenceRegistry evidenceRegistry_,
        AVADisclosurePolicyRegistry disclosureRegistry_,
        IZKProofVerifier verifier_
    )
        AVAExtensionRecordBase(
            governanceKernel_,
            authorityMatrix_,
            identityRegistry_,
            rulePackageRegistry_,
            evidenceRegistry_,
            disclosureRegistry_
        )
    {
        if (address(verifier_) == address(0) || address(verifier_).code.length == 0) {
            revert AVACoreTypes.EmptyValue();
        }
        bytes32 proofDomainHash = verifier_.proofDomain();
        if (proofDomainHash == bytes32(0)) revert AVACoreTypes.EmptyValue();
        VERIFIER = verifier_;
        PROOF_DOMAIN_HASH = proofDomainHash;
        VERIFIER_CODE_HASH = address(verifier_).codehash;
    }

    function registerProof(ProofInput calldata input) external returns (uint256 proofReceiptId) {
        _requireStableVerifier();
        if (
            input.scopeKey == bytes32(0) || input.subjectCommitment == bytes32(0)
                || computeSubjectCommitment(input.proof.publicKey) != input.subjectCommitment
        ) revert AVACoreTypes.EmptyValue();
        AVAGovernanceKernel.RecognisedStateReference memory state =
            GOVERNANCE_KERNEL.getRecognisedStateReference(input.recognisedStateId);
        bytes32 contextHash = _contextHash(input, state);
        bytes32 nullifierHash = keccak256(abi.encode(NULLIFIER_DOMAIN, contextHash, input.subjectCommitment));
        if (proofReceiptIdByContextHash[contextHash] != 0 || proofReceiptIdByNullifierHash[nullifierHash] != 0) {
            revert AVACoreTypes.InvalidState(uint256(contextHash));
        }
        bytes32 proofHash = keccak256(abi.encode(input.proof));
        _validateExtensionWithState(
            ExtensionValidationInput({
                recognisedStateId: input.recognisedStateId,
                roleKey: input.roleKey,
                authorityId: input.authorityId,
                subjectId: input.subjectId,
                evidenceId: input.evidenceId,
                capabilityKey: AVACapabilityKeys.PRIVACY_PROOF,
                actionKey: AVACoreTypes.ACTION_RECORD_PRIVACY_PROOF,
                recordTypeKey: PROOF_RECORD_TYPE,
                scopeKey: input.scopeKey,
                sourceTypeKey: PROOF_DOMAIN_HASH,
                sourceRecordId: 0,
                unsignedValue: 0,
                validUntil: 0,
                payloadHash: proofHash,
                requireActiveSubject: true,
                contextHash: contextHash
            }),
            state
        );
        if (!VERIFIER.verify(contextHash, input.proof)) {
            revert AVACoreTypes.InvalidState(uint256(contextHash));
        }
        proofReceiptId = nextProofReceiptId++;
        proofReceipts[proofReceiptId] = ProofReceipt({
            id: proofReceiptId,
            appId: state.appId,
            workflowKey: state.workflowKey,
            packageId: state.packageId,
            recognisedStateId: state.id,
            recognisedStateTransitionId: state.lastTransitionId,
            subjectId: input.subjectId,
            evidenceId: input.evidenceId,
            disclosurePolicyId: state.disclosurePolicyId,
            scopeKey: input.scopeKey,
            subjectCommitment: input.subjectCommitment,
            verifier: address(VERIFIER),
            proofDomainHash: PROOF_DOMAIN_HASH,
            contextHash: contextHash,
            nullifierHash: nullifierHash,
            proofHash: proofHash,
            authorityId: input.authorityId,
            registeredBy: msg.sender,
            registeredAt: uint64(block.timestamp),
            uri: input.uri
        });
        proofReceiptIdByContextHash[contextHash] = proofReceiptId;
        proofReceiptIdByNullifierHash[nullifierHash] = proofReceiptId;
        targetPackageIdByProofReceipt[proofReceiptId] = state.packageId;
        emit PrivacyProofReceiptRecorded(
            proofReceiptId,
            state.appId,
            input.subjectId,
            state.packageId,
            state.id,
            contextHash,
            nullifierHash,
            msg.sender
        );
    }

    function registerChallengeProof(ChallengeProofInput calldata input) external returns (uint256 proofReceiptId) {
        _requireStableVerifier();
        if (
            input.packageId == 0 || input.recognisedStateId == 0 || input.roleKey == bytes32(0)
                || input.authorityId == bytes32(0) || input.evidenceId == 0 || input.disclosurePolicyId == 0
                || computeSubjectCommitment(input.proof.publicKey) != input.authorityId
        ) revert AVACoreTypes.EmptyValue();
        AVAGovernanceKernel.RecognisedStateReference memory state =
            GOVERNANCE_KERNEL.getRecognisedStateReference(input.recognisedStateId);
        ChallengeProofModules memory modules = _verifiedChallengeProofModules(input.packageId);
        bytes32 workflowKey = _validateChallengeProofInput(input, state, modules.rulePackage);
        bytes32 contextHash = _challengeContextHash(input, state);
        bytes32 nullifierHash = keccak256(abi.encode(NULLIFIER_DOMAIN, contextHash, input.authorityId));
        bytes32 gateKey = _challengeGateKeyForInput(input, state.lastTransitionId);
        uint256 currentReceiptId = challengeProofReceiptIdByGateKey[gateKey];
        if (
            proofReceiptIdByContextHash[contextHash] != 0 || proofReceiptIdByNullifierHash[nullifierHash] != 0
                || (currentReceiptId != 0 && _isProofUsable(proofReceipts[currentReceiptId]))
        ) revert AVACoreTypes.InvalidState(uint256(contextHash));
        _validateChallengeProofPolicies(input, state, workflowKey, contextHash, modules);
        if (!VERIFIER.verify(contextHash, input.proof)) revert AVACoreTypes.InvalidState(uint256(contextHash));
        proofReceiptId = nextProofReceiptId++;
        _storeChallengeProof(proofReceiptId, input, state, workflowKey, contextHash, nullifierHash);
        proofReceiptIdByContextHash[contextHash] = proofReceiptId;
        proofReceiptIdByNullifierHash[nullifierHash] = proofReceiptId;
        challengeProofReceiptIdByGateKey[gateKey] = proofReceiptId;
        isChallengeFilingProof[proofReceiptId] = true;
        emit PrivacyProofReceiptRecorded(
            proofReceiptId,
            state.appId,
            input.authorityId,
            input.packageId,
            state.id,
            contextHash,
            nullifierHash,
            msg.sender
        );
    }

    function getProofReceipt(uint256 proofReceiptId) external view returns (ProofReceipt memory receipt) {
        receipt = proofReceipts[proofReceiptId];
        if (receipt.id == 0) revert AVACoreTypes.UnknownReference(proofReceiptId);
    }

    function proofMatches(
        uint256 proofReceiptId,
        uint256 packageId,
        uint256 recognisedStateId,
        bytes32 subjectId,
        uint256 evidenceId,
        bytes32 scopeKey
    ) external view returns (bool) {
        ProofReceipt memory receipt = proofReceipts[proofReceiptId];
        return receipt.id != 0 && receipt.packageId == packageId && receipt.recognisedStateId == recognisedStateId
            && receipt.subjectId == subjectId && receipt.evidenceId == evidenceId && receipt.scopeKey == scopeKey
            && _isProofUsable(receipt);
    }

    function hasChallengeFilingProof(
        uint256 packageId,
        uint256 recognisedStateId,
        bytes32 subjectId,
        uint256 evidenceId,
        uint256 disclosurePolicyId,
        bytes32 actionKey,
        bytes32 roleKey
    ) external view returns (bool) {
        AVAGovernanceKernel.RecognisedStateReference memory state =
            GOVERNANCE_KERNEL.getRecognisedStateReference(recognisedStateId);
        uint256 receiptId = challengeProofReceiptIdByGateKey[
            _challengeGateKey(
                packageId,
                recognisedStateId,
                state.lastTransitionId,
                subjectId,
                evidenceId,
                disclosurePolicyId,
                actionKey,
                roleKey
            )
        ];
        return receiptId != 0 && _isProofUsable(proofReceipts[receiptId]);
    }

    function challengeProofMatches(ChallengeProofMatchInput calldata input) external view returns (bool) {
        ProofReceipt memory receipt = proofReceipts[input.proofReceiptId];
        if (receipt.id == 0 || !isChallengeFilingProof[input.proofReceiptId]) return false;
        AVAGovernanceKernel.RecognisedStateReference memory state =
            GOVERNANCE_KERNEL.getRecognisedStateReference(input.recognisedStateId);
        if (
            challengeProofReceiptIdByGateKey[
                    _challengeGateKey(
                        input.packageId,
                        input.recognisedStateId,
                        state.lastTransitionId,
                        input.subjectId,
                        input.evidenceId,
                        input.disclosurePolicyId,
                        AVACoreTypes.ACTION_FILE_CHALLENGE,
                        input.roleKey
                    )
                ] != input.proofReceiptId
        ) return false;
        return receipt.packageId == input.packageId && receipt.recognisedStateId == input.recognisedStateId
            && receipt.subjectId == input.subjectId && receipt.evidenceId == input.evidenceId
            && receipt.disclosurePolicyId == input.disclosurePolicyId && _isProofUsable(receipt);
    }

    function isProofUsable(uint256 proofReceiptId) external view returns (bool) {
        ProofReceipt memory receipt = proofReceipts[proofReceiptId];
        return receipt.id != 0 && _isProofUsable(receipt);
    }

    function computeSubjectCommitment(IZKProofVerifier.G1Point calldata publicKey) public pure returns (bytes32) {
        return keccak256(abi.encode(publicKey.x, publicKey.y));
    }

    function _isProofUsable(ProofReceipt memory receipt) private view returns (bool) {
        if (!_verifierStable()) return false;
        AVAGovernanceKernel.RecognisedStateReference memory state;
        try GOVERNANCE_KERNEL.getRecognisedStateReference(receipt.recognisedStateId) returns (
            AVAGovernanceKernel.RecognisedStateReference memory currentState
        ) {
            state = currentState;
            if (
                state.appId != receipt.appId || state.packageId != targetPackageIdByProofReceipt[receipt.id]
                    || state.lastTransitionId != receipt.recognisedStateTransitionId
            ) return false;
            if (
                !isChallengeFilingProof[receipt.id]
                    && (state.workflowKey != receipt.workflowKey
                        || state.subjectId != receipt.subjectId
                        || state.disclosurePolicyId != receipt.disclosurePolicyId)
            ) return false;
        } catch {
            return false;
        }
        try IDENTITY_REGISTRY.getSubjectContext(receipt.subjectId) returns (
            AVAIdentityRegistry.SubjectContext memory subject
        ) {
            if (!subject.active || subject.appId != receipt.appId) return false;
        } catch {
            return false;
        }
        if (!isChallengeFilingProof[receipt.id] && !_evidenceUsable(state.evidenceReceiptId, receipt)) {
            return false;
        }
        if (!_evidenceUsable(receipt.evidenceId, receipt)) return false;
        try DISCLOSURE_REGISTRY.requireActivePolicyReference(receipt.disclosurePolicyId, receipt.appId) {}
        catch {
            return false;
        }
        try RULE_PACKAGE_REGISTRY.getVerifiedPackageContext(receipt.packageId) returns (
            AVACoreRulePackageRegistry.VerifiedPackageContext memory rulePackage
        ) {
            if (rulePackage.appId != receipt.appId || rulePackage.workflowKey != receipt.workflowKey) return false;
            if (isChallengeFilingProof[receipt.id]) {
                try RULE_PACKAGE_REGISTRY.getVerifiedPackageContext(targetPackageIdByProofReceipt[receipt.id]) returns (
                    AVACoreRulePackageRegistry.VerifiedPackageContext memory targetPackage
                ) {
                    return targetPackage.appId == receipt.appId
                        && targetPackage.compatibilityKey == rulePackage.compatibilityKey;
                } catch {
                    return false;
                }
            }
            return targetPackageIdByProofReceipt[receipt.id] == receipt.packageId;
        } catch {
            return false;
        }
    }

    function _validateChallengeProofPolicies(
        ChallengeProofInput calldata input,
        AVAGovernanceKernel.RecognisedStateReference memory state,
        bytes32 workflowKey,
        bytes32 contextHash,
        ChallengeProofModules memory modules
    ) private view {
        _validateChallengeApplication(input, state, workflowKey, modules.application);
        _validateChallengeExtensionPolicy(input, state, workflowKey, contextHash, modules.privacyProof);
        _validateChallengeAntiAbuse(input, state, workflowKey, modules.antiAbuse);
    }

    function _validateChallengeApplication(
        ChallengeProofInput calldata input,
        AVAGovernanceKernel.RecognisedStateReference memory state,
        bytes32 workflowKey,
        IAVAApplicationModule application
    ) private view {
        AVAGovernanceKernel.GovernedObjectReference memory objectRecord =
            GOVERNANCE_KERNEL.getGovernedObjectReference(state.governedObjectId);
        application.validateDownstreamRecord(
            IAVAApplicationModule.DownstreamRecordContext({
                appId: state.appId,
                workflowKey: workflowKey,
                packageId: input.packageId,
                actionKey: AVACoreTypes.ACTION_RECORD_PRIVACY_PROOF,
                roleKey: input.roleKey,
                recognisedStateId: state.id,
                governedObjectId: state.governedObjectId,
                objectTypeKey: objectRecord.objectTypeKey,
                subjectId: input.authorityId,
                evidenceReceiptId: input.evidenceId,
                recordTypeKey: PROOF_RECORD_TYPE,
                authorityId: input.authorityId,
                actor: msg.sender
            })
        );
    }

    function _validateChallengeExtensionPolicy(
        ChallengeProofInput calldata input,
        AVAGovernanceKernel.RecognisedStateReference memory state,
        bytes32 workflowKey,
        bytes32 contextHash,
        IAVAExtensionPolicyModule privacyProof
    ) private view {
        privacyProof.validateExtensionRecord(
            IAVAExtensionPolicyModule.ExtensionPolicyContext({
                appId: state.appId,
                workflowKey: workflowKey,
                packageId: input.packageId,
                capabilityKey: AVACapabilityKeys.PRIVACY_PROOF,
                actionKey: AVACoreTypes.ACTION_RECORD_PRIVACY_PROOF,
                recordTypeKey: PROOF_RECORD_TYPE,
                scopeKey: CHALLENGE_PROOF_SCOPE,
                sourceTypeKey: CHALLENGE_PROOF_CONTEXT_DOMAIN,
                recognisedStateId: state.id,
                recognisedStateTransitionId: state.lastTransitionId,
                subjectId: input.authorityId,
                evidenceId: input.evidenceId,
                disclosurePolicyId: input.disclosurePolicyId,
                sourceRecordId: 0,
                unsignedValue: 0,
                validUntil: 0,
                payloadHash: keccak256(abi.encode(input.proof)),
                contextHash: contextHash,
                authorityId: input.authorityId,
                actor: msg.sender
            })
        );
    }

    function _validateChallengeAntiAbuse(
        ChallengeProofInput calldata input,
        AVAGovernanceKernel.RecognisedStateReference memory state,
        bytes32 workflowKey,
        IAVAAntiAbusePolicyModule antiAbuse
    ) private view {
        if (address(antiAbuse) == address(0)) return;
        antiAbuse.validateAntiAbuse(
            IAVAAntiAbusePolicyModule.AntiAbuseContext({
                appId: state.appId,
                workflowKey: workflowKey,
                packageId: input.packageId,
                actionKey: AVACoreTypes.ACTION_RECORD_PRIVACY_PROOF,
                roleKey: input.roleKey,
                targetId: state.id,
                targetTypeKey: PROOF_RECORD_TYPE,
                actorSubjectId: input.authorityId,
                targetSubjectId: state.subjectId,
                authorityId: input.authorityId,
                actor: msg.sender
            })
        );
    }

    function _validateChallengeProofInput(
        ChallengeProofInput calldata input,
        AVAGovernanceKernel.RecognisedStateReference memory state,
        AVACoreRulePackageRegistry.VerifiedPackageContext memory package
    ) private view returns (bytes32 workflowKey) {
        AVACoreRulePackageRegistry.VerifiedPackageContext memory targetPackage = state.packageId == input.packageId
            ? package
            : RULE_PACKAGE_REGISTRY.getVerifiedPackageContext(state.packageId);
        if (
            package.appId != state.appId || targetPackage.appId != state.appId
                || package.compatibilityKey != targetPackage.compatibilityKey
        ) revert AVACoreTypes.InvalidState(input.packageId);
        AUTHORITY_MATRIX.requireAuthorisedSubject(
            msg.sender, state.appId, input.roleKey, AVACoreTypes.ACTION_RECORD_PRIVACY_PROOF, input.authorityId
        );
        DISCLOSURE_REGISTRY.requireActivePolicyReference(input.disclosurePolicyId, state.appId);
        (
            bytes32 evidenceAppId,
            bytes32 evidenceWorkflowKey,
            ,
            bytes32 evidenceSubjectId,
            uint256 evidencePolicyId
        ) = EVIDENCE_REGISTRY.requireUsableEvidenceReferenceForPackage(input.evidenceId, input.packageId);
        if (
            evidenceAppId != state.appId || evidenceWorkflowKey != package.workflowKey
                || evidenceSubjectId != input.authorityId
                || evidencePolicyId != input.disclosurePolicyId
        ) revert AVACoreTypes.InvalidState(input.evidenceId);
        workflowKey = package.workflowKey;
    }

    function _verifiedChallengeProofModules(uint256 packageId)
        private
        view
        returns (ChallengeProofModules memory modules)
    {
        bytes32[] memory keys = new bytes32[](3);
        keys[0] = AVACapabilityKeys.APPLICATION;
        keys[1] = AVACapabilityKeys.PRIVACY_PROOF;
        keys[2] = AVACapabilityKeys.ANTI_ABUSE;
        (AVACoreRulePackageRegistry.VerifiedPackageContext memory rulePackage, address[] memory addresses) =
            RULE_PACKAGE_REGISTRY.getVerifiedModulesCompact(packageId, keys);
        if (addresses[1] == address(0)) revert AVACoreTypes.UnknownReference(packageId);
        modules = ChallengeProofModules({
            rulePackage: rulePackage,
            application: IAVAApplicationModule(addresses[0]),
            privacyProof: IAVAExtensionPolicyModule(addresses[1]),
            antiAbuse: IAVAAntiAbusePolicyModule(addresses[2])
        });
    }

    function _storeChallengeProof(
        uint256 proofReceiptId,
        ChallengeProofInput calldata input,
        AVAGovernanceKernel.RecognisedStateReference memory state,
        bytes32 workflowKey,
        bytes32 contextHash,
        bytes32 nullifierHash
    ) private {
        ProofReceipt storage receipt = proofReceipts[proofReceiptId];
        receipt.id = proofReceiptId;
        receipt.appId = state.appId;
        receipt.workflowKey = workflowKey;
        receipt.packageId = input.packageId;
        receipt.recognisedStateId = state.id;
        receipt.recognisedStateTransitionId = state.lastTransitionId;
        receipt.subjectId = input.authorityId;
        receipt.evidenceId = input.evidenceId;
        receipt.disclosurePolicyId = input.disclosurePolicyId;
        receipt.scopeKey = CHALLENGE_PROOF_SCOPE;
        receipt.subjectCommitment = input.authorityId;
        receipt.verifier = address(VERIFIER);
        receipt.proofDomainHash = PROOF_DOMAIN_HASH;
        receipt.contextHash = contextHash;
        receipt.nullifierHash = nullifierHash;
        receipt.proofHash = keccak256(abi.encode(input.proof));
        receipt.authorityId = input.authorityId;
        receipt.registeredBy = msg.sender;
        receipt.registeredAt = uint64(block.timestamp);
        receipt.uri = input.uri;
        targetPackageIdByProofReceipt[proofReceiptId] = state.packageId;
    }

    function _challengeContextHash(
        ChallengeProofInput calldata input,
        AVAGovernanceKernel.RecognisedStateReference memory state
    )
        private
        view
        returns (bytes32)
    {
        bytes32 targetHash =
            keccak256(abi.encode(state.appId, input.packageId, state.packageId, state.id, state.lastTransitionId));
        bytes32 proofUseHash = keccak256(
            abi.encode(
                input.authorityId,
                input.evidenceId,
                input.disclosurePolicyId,
                AVACoreTypes.ACTION_FILE_CHALLENGE,
                input.roleKey,
                CHALLENGE_PROOF_SCOPE
            )
        );
        return keccak256(
            abi.encode(
                CHALLENGE_PROOF_CONTEXT_DOMAIN, _deploymentDomainHash(), targetHash, proofUseHash, PROOF_DOMAIN_HASH
            )
        );
    }

    function _challengeGateKey(
        uint256 packageId,
        uint256 recognisedStateId,
        uint256 transitionId,
        bytes32 subjectId,
        uint256 evidenceId,
        uint256 disclosurePolicyId,
        bytes32 actionKey,
        bytes32 roleKey
    ) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                packageId,
                recognisedStateId,
                transitionId,
                subjectId,
                evidenceId,
                disclosurePolicyId,
                actionKey,
                roleKey
            )
        );
    }

    function _challengeGateKeyForInput(ChallengeProofInput calldata input, uint256 transitionId)
        private
        pure
        returns (bytes32)
    {
        return _challengeGateKey(
            input.packageId,
            input.recognisedStateId,
            transitionId,
            input.authorityId,
            input.evidenceId,
            input.disclosurePolicyId,
            AVACoreTypes.ACTION_FILE_CHALLENGE,
            input.roleKey
        );
    }

    function _evidenceUsable(uint256 evidenceId, ProofReceipt memory receipt) private view returns (bool) {
        try EVIDENCE_REGISTRY.requireUsableEvidenceReferenceForPackage(evidenceId, receipt.packageId) returns (
            bytes32 appId, bytes32 workflowKey, uint256, bytes32 subjectId, uint256 disclosurePolicyId
        ) {
            return appId == receipt.appId && workflowKey == receipt.workflowKey
                && subjectId == receipt.subjectId && disclosurePolicyId == receipt.disclosurePolicyId;
        } catch {
            return false;
        }
    }

    function _contextHash(ProofInput calldata input, AVAGovernanceKernel.RecognisedStateReference memory state)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                PROOF_CONTEXT_DOMAIN,
                _deploymentDomainHash(),
                state.appId,
                state.workflowKey,
                state.packageId,
                state.id,
                state.lastTransitionId,
                input.subjectId,
                input.evidenceId,
                state.disclosurePolicyId,
                input.scopeKey,
                input.subjectCommitment,
                address(VERIFIER),
                PROOF_DOMAIN_HASH
            )
        );
    }

    function _requireStableVerifier() private view {
        if (!_verifierStable()) revert AVACoreTypes.InvalidState(uint256(PROOF_DOMAIN_HASH));
    }

    function _deploymentDomainHash() private view returns (bytes32) {
        return keccak256(abi.encode(block.chainid, address(this), address(VERIFIER), PROOF_DOMAIN_HASH));
    }

    function _verifierStable() private view returns (bool) {
        if (address(VERIFIER).codehash != VERIFIER_CODE_HASH) return false;
        try VERIFIER.proofDomain() returns (bytes32 proofDomainHash) {
            return proofDomainHash == PROOF_DOMAIN_HASH;
        } catch {
            return false;
        }
    }
}
