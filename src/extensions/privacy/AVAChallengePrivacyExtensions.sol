// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RuleModuleIdentity} from "../../interfaces/IRuleModuleIdentity.sol";
import {IAVAApplicationModule} from "../../interfaces/IAVAApplicationModule.sol";
import {AVAAuthorityMatrix} from "../../core/AVAAuthorityMatrix.sol";
import {AVACapabilityKeys} from "../../core/AVACapabilityKeys.sol";
import {AVACoreRulePackageRegistry} from "../../core/AVACoreRulePackageRegistry.sol";
import {AVACoreTypes} from "../../core/AVACoreTypes.sol";
import {AVAEvidenceRegistry} from "../../core/AVAEvidenceRegistry.sol";
import {AVAGovernanceKernel} from "../../core/AVAGovernanceKernel.sol";
import {AVAIdentityRegistry} from "../../core/AVAIdentityRegistry.sol";
import {IAVADisclosurePolicyModule, IAVAAntiAbusePolicyModule} from "../../core/interfaces/IAVACoreRuleModules.sol";
import {AVAChallengeExtension} from "../challenge/AVAChallengeExtension.sol";
import {IAVAExtensionPolicyModule} from "../shared/IAVAExtensionPolicyModule.sol";
import {AVAPrivacyProofExtension} from "./AVAPrivacyProofExtension.sol";

contract ChallengeProofDisclosurePolicyModule is IAVADisclosurePolicyModule, RuleModuleIdentity {
    AVAPrivacyProofExtension public immutable PROOF_REGISTRY;
    uint256 public immutable DISCLOSURE_POLICY_ID;
    bytes32 public immutable CHALLENGER_ROLE_KEY;

    constructor(AVAPrivacyProofExtension proofRegistry_, uint256 disclosurePolicyId_, bytes32 challengerRoleKey_) {
        if (address(proofRegistry_) == address(0) || disclosurePolicyId_ == 0 || challengerRoleKey_ == bytes32(0)) {
            revert AVACoreTypes.EmptyValue();
        }
        PROOF_REGISTRY = proofRegistry_;
        DISCLOSURE_POLICY_ID = disclosurePolicyId_;
        CHALLENGER_ROLE_KEY = challengerRoleKey_;
    }

    function validateDisclosure(DisclosureContext calldata context) external view {
        if (context.disclosurePolicyId != DISCLOSURE_POLICY_ID) {
            revert AVACoreTypes.InvalidState(context.disclosurePolicyId);
        }
        if (context.actionKey != AVACoreTypes.ACTION_FILE_CHALLENGE) return;
        if (
            context.roleKey != CHALLENGER_ROLE_KEY || context.subjectId != context.authorityId
                || !PROOF_REGISTRY.hasChallengeFilingProof(
                    context.packageId,
                    context.targetId,
                    context.subjectId,
                    context.evidenceId,
                    context.disclosurePolicyId,
                    context.actionKey,
                    context.roleKey
                )
        ) revert AVACoreTypes.InvalidState(context.targetId);
    }

    function _moduleConfigurationHash() internal view override returns (bytes32) {
        return keccak256(abi.encode(address(PROOF_REGISTRY), DISCLOSURE_POLICY_ID, CHALLENGER_ROLE_KEY));
    }
}

contract AVAChallengeProofUseExtension {
    bytes32 public constant PROOF_USE_TYPE = keccak256("ava.extension.challenge-proof-use.v1");
    bytes32 public constant PROOF_USE_CONTEXT_DOMAIN = keccak256("ava.extension.challenge-proof-use.context.v1");
    bytes32 public constant PROOF_USE_NULLIFIER_DOMAIN = keccak256("ava.extension.challenge-proof-use.nullifier.v1");

    struct ProofUseInput {
        uint256 challengeId;
        uint256 proofReceiptId;
        bytes32 roleKey;
        bytes32 authorityId;
        bytes32 reasonHash;
        string uri;
    }

    struct ProofUseRecord {
        uint256 id;
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        uint256 targetPackageId;
        uint256 challengeId;
        uint256 recognisedStateId;
        uint256 recognisedStateTransitionId;
        uint256 proofReceiptId;
        bytes32 subjectId;
        uint256 evidenceId;
        uint256 disclosurePolicyId;
        bytes32 contextHash;
        bytes32 nullifierHash;
        bytes32 reasonHash;
        bytes32 authorityId;
        string uri;
        address recordedBy;
        uint64 recordedAt;
    }

    struct ProofUseModules {
        AVACoreRulePackageRegistry.VerifiedPackageContext rulePackage;
        IAVAApplicationModule application;
        IAVAExtensionPolicyModule disclosureReceipt;
        IAVAAntiAbusePolicyModule antiAbuse;
    }

    AVAGovernanceKernel public immutable GOVERNANCE_KERNEL;
    AVAAuthorityMatrix public immutable AUTHORITY_MATRIX;
    AVAIdentityRegistry public immutable IDENTITY_REGISTRY;
    AVACoreRulePackageRegistry public immutable RULE_PACKAGE_REGISTRY;
    AVAEvidenceRegistry public immutable EVIDENCE_REGISTRY;
    AVAChallengeExtension public immutable CHALLENGE_EXTENSION;
    AVAPrivacyProofExtension public immutable PROOF_REGISTRY;

    mapping(uint256 => ProofUseRecord) private proofUseRecords;
    mapping(bytes32 => uint256) public proofUseRecordIdByNullifier;
    uint256 public nextProofUseRecordId = 1;

    event ChallengeProofUseRecorded(
        uint256 indexed recordId,
        uint256 indexed challengeId,
        uint256 indexed proofReceiptId,
        bytes32 nullifierHash,
        address recordedBy
    );

    constructor(
        AVAGovernanceKernel governanceKernel_,
        AVAAuthorityMatrix authorityMatrix_,
        AVAIdentityRegistry identityRegistry_,
        AVACoreRulePackageRegistry rulePackageRegistry_,
        AVAEvidenceRegistry evidenceRegistry_,
        AVAChallengeExtension challengeExtension_,
        AVAPrivacyProofExtension proofRegistry_
    ) {
        if (
            address(governanceKernel_) == address(0) || address(authorityMatrix_) == address(0)
                || address(identityRegistry_) == address(0) || address(rulePackageRegistry_) == address(0)
                || address(evidenceRegistry_) == address(0) || address(challengeExtension_) == address(0)
                || address(proofRegistry_) == address(0)
        ) revert AVACoreTypes.EmptyValue();
        if (
            address(governanceKernel_.AUTHORITY_MATRIX()) != address(authorityMatrix_)
                || address(governanceKernel_.IDENTITY_REGISTRY()) != address(identityRegistry_)
                || address(governanceKernel_.RULE_PACKAGE_REGISTRY()) != address(rulePackageRegistry_)
                || address(governanceKernel_.EVIDENCE_REGISTRY()) != address(evidenceRegistry_)
                || address(challengeExtension_.GOVERNANCE_KERNEL()) != address(governanceKernel_)
                || address(proofRegistry_.GOVERNANCE_KERNEL()) != address(governanceKernel_)
        ) revert AVACoreTypes.InvalidState(0);
        GOVERNANCE_KERNEL = governanceKernel_;
        AUTHORITY_MATRIX = authorityMatrix_;
        IDENTITY_REGISTRY = identityRegistry_;
        RULE_PACKAGE_REGISTRY = rulePackageRegistry_;
        EVIDENCE_REGISTRY = evidenceRegistry_;
        CHALLENGE_EXTENSION = challengeExtension_;
        PROOF_REGISTRY = proofRegistry_;
    }

    function recordProofUse(ProofUseInput calldata input) external returns (uint256 recordId) {
        if (
            input.challengeId == 0 || input.proofReceiptId == 0 || input.roleKey == bytes32(0)
                || input.authorityId == bytes32(0) || input.reasonHash == bytes32(0)
        ) revert AVACoreTypes.EmptyValue();
        AVAChallengeExtension.ChallengeRecord memory challenge = CHALLENGE_EXTENSION.getChallenge(input.challengeId);
        if (
            challenge.status != AVAChallengeExtension.ChallengeStatus.ConcernFiled
                && challenge.status != AVAChallengeExtension.ChallengeStatus.AdmissibilityScreening
        ) revert AVACoreTypes.InvalidState(input.challengeId);
        if (input.authorityId != challenge.challengerSubjectId) {
            revert AVACoreTypes.SubjectMismatch(challenge.challengerSubjectId, input.authorityId);
        }
        AUTHORITY_MATRIX.requireAuthorisedSubject(
            msg.sender, challenge.appId, input.roleKey, AVACoreTypes.ACTION_RECORD_DISCLOSURE_RECEIPT, input.authorityId
        );
        AVAPrivacyProofExtension.ProofReceipt memory proof = PROOF_REGISTRY.getProofReceipt(input.proofReceiptId);
        if (
            challenge.packageId != proof.packageId
                || challenge.targetPackageId != PROOF_REGISTRY.targetPackageIdByProofReceipt(proof.id)
                || challenge.challengedRecognisedStateId != proof.recognisedStateId
                || challenge.challengerSubjectId != proof.subjectId || challenge.evidenceReceiptId != proof.evidenceId
                || challenge.disclosurePolicyId != proof.disclosurePolicyId
                || !PROOF_REGISTRY.challengeProofMatches(
                    AVAPrivacyProofExtension.ChallengeProofMatchInput({
                        proofReceiptId: proof.id,
                        packageId: challenge.packageId,
                        recognisedStateId: challenge.challengedRecognisedStateId,
                        subjectId: challenge.challengerSubjectId,
                        evidenceId: challenge.evidenceReceiptId,
                        disclosurePolicyId: challenge.disclosurePolicyId,
                        roleKey: input.roleKey
                    })
                )
        ) revert AVACoreTypes.InvalidState(input.proofReceiptId);
        AVACoreTypes.RecognisedStateRecord memory state =
            GOVERNANCE_KERNEL.getRecognisedState(challenge.challengedRecognisedStateId);
        AVAGovernanceKernel.GovernedObjectReference memory objectRecord =
            GOVERNANCE_KERNEL.getGovernedObjectReference(state.governedObjectId);
        bytes32 contextHash = keccak256(
            abi.encode(
                PROOF_USE_CONTEXT_DOMAIN,
                challenge.appId,
                challenge.packageId,
                challenge.targetPackageId,
                challenge.id,
                state.id,
                proof.id,
                proof.contextHash,
                challenge.challengerSubjectId,
                challenge.disclosurePolicyId
            )
        );
        bytes32 nullifierHash = keccak256(abi.encode(PROOF_USE_NULLIFIER_DOMAIN, contextHash, proof.nullifierHash));
        if (proofUseRecordIdByNullifier[nullifierHash] != 0) {
            revert AVACoreTypes.InvalidState(proofUseRecordIdByNullifier[nullifierHash]);
        }
        _validatePolicies(challenge, state, objectRecord.objectTypeKey, proof, input, contextHash);
        recordId = nextProofUseRecordId++;
        proofUseRecords[recordId] = ProofUseRecord({
            id: recordId,
            appId: challenge.appId,
            workflowKey: challenge.workflowKey,
            packageId: challenge.packageId,
            targetPackageId: challenge.targetPackageId,
            challengeId: challenge.id,
            recognisedStateId: state.id,
            recognisedStateTransitionId: state.lastTransitionId,
            proofReceiptId: proof.id,
            subjectId: challenge.challengerSubjectId,
            evidenceId: challenge.evidenceReceiptId,
            disclosurePolicyId: challenge.disclosurePolicyId,
            contextHash: contextHash,
            nullifierHash: nullifierHash,
            reasonHash: input.reasonHash,
            authorityId: input.authorityId,
            uri: input.uri,
            recordedBy: msg.sender,
            recordedAt: uint64(block.timestamp)
        });
        proofUseRecordIdByNullifier[nullifierHash] = recordId;
        emit ChallengeProofUseRecorded(recordId, challenge.id, proof.id, nullifierHash, msg.sender);
    }

    function getProofUseRecord(uint256 recordId) external view returns (ProofUseRecord memory record) {
        record = proofUseRecords[recordId];
        if (record.id == 0) revert AVACoreTypes.UnknownReference(recordId);
    }

    function _validatePolicies(
        AVAChallengeExtension.ChallengeRecord memory challenge,
        AVACoreTypes.RecognisedStateRecord memory state,
        bytes32 objectTypeKey,
        AVAPrivacyProofExtension.ProofReceipt memory proof,
        ProofUseInput calldata input,
        bytes32 contextHash
    ) private view {
        ProofUseModules memory modules = _verifiedProofUseModules(challenge.packageId);
        if (modules.rulePackage.appId != challenge.appId || modules.rulePackage.workflowKey != challenge.workflowKey) {
            revert AVACoreTypes.InvalidState(challenge.packageId);
        }
        modules.application
            .validateDownstreamRecord(
                IAVAApplicationModule.DownstreamRecordContext({
                    appId: challenge.appId,
                    workflowKey: challenge.workflowKey,
                    packageId: challenge.packageId,
                    actionKey: AVACoreTypes.ACTION_RECORD_DISCLOSURE_RECEIPT,
                    roleKey: input.roleKey,
                    recognisedStateId: state.id,
                    governedObjectId: state.governedObjectId,
                    objectTypeKey: objectTypeKey,
                    subjectId: challenge.challengerSubjectId,
                    evidenceReceiptId: challenge.evidenceReceiptId,
                    recordTypeKey: PROOF_USE_TYPE,
                    authorityId: input.authorityId,
                    actor: msg.sender
                })
            );
        modules.disclosureReceipt
            .validateExtensionRecord(
                IAVAExtensionPolicyModule.ExtensionPolicyContext({
                    appId: challenge.appId,
                    workflowKey: challenge.workflowKey,
                    packageId: challenge.packageId,
                    capabilityKey: AVACapabilityKeys.DISCLOSURE_RECEIPT,
                    actionKey: AVACoreTypes.ACTION_RECORD_DISCLOSURE_RECEIPT,
                    recordTypeKey: PROOF_USE_TYPE,
                    scopeKey: proof.scopeKey,
                    sourceTypeKey: PROOF_REGISTRY.PROOF_RECORD_TYPE(),
                    recognisedStateId: state.id,
                    recognisedStateTransitionId: state.lastTransitionId,
                    subjectId: challenge.challengerSubjectId,
                    evidenceId: challenge.evidenceReceiptId,
                    disclosurePolicyId: challenge.disclosurePolicyId,
                    sourceRecordId: proof.id,
                    unsignedValue: challenge.id,
                    validUntil: 0,
                    payloadHash: input.reasonHash,
                    contextHash: contextHash,
                    authorityId: input.authorityId,
                    actor: msg.sender
                })
            );
        if (address(modules.antiAbuse) == address(0)) return;
        modules.antiAbuse
            .validateAntiAbuse(
                IAVAAntiAbusePolicyModule.AntiAbuseContext({
                    appId: challenge.appId,
                    workflowKey: challenge.workflowKey,
                    packageId: challenge.packageId,
                    actionKey: AVACoreTypes.ACTION_RECORD_DISCLOSURE_RECEIPT,
                    roleKey: input.roleKey,
                    targetId: challenge.id,
                    targetTypeKey: PROOF_USE_TYPE,
                    actorSubjectId: challenge.challengerSubjectId,
                    targetSubjectId: state.subjectId,
                    authorityId: input.authorityId,
                    actor: msg.sender
                })
            );
    }

    function _verifiedProofUseModules(uint256 packageId) private view returns (ProofUseModules memory modules) {
        bytes32[] memory keys = new bytes32[](3);
        keys[0] = AVACapabilityKeys.APPLICATION;
        keys[1] = AVACapabilityKeys.DISCLOSURE_RECEIPT;
        keys[2] = AVACapabilityKeys.ANTI_ABUSE;
        (AVACoreRulePackageRegistry.VerifiedPackageContext memory rulePackage, address[] memory addresses) =
            RULE_PACKAGE_REGISTRY.getVerifiedModulesCompact(packageId, keys);
        if (addresses[1] == address(0)) revert AVACoreTypes.UnknownReference(packageId);
        modules = ProofUseModules({
            rulePackage: rulePackage,
            application: IAVAApplicationModule(addresses[0]),
            disclosureReceipt: IAVAExtensionPolicyModule(addresses[1]),
            antiAbuse: IAVAAntiAbusePolicyModule(addresses[2])
        });
    }
}
