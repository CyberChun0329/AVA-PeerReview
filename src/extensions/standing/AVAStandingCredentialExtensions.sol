// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVAAuthorityMatrix} from "../../core/AVAAuthorityMatrix.sol";
import {AVACapabilityKeys} from "../../core/AVACapabilityKeys.sol";
import {AVACoreRulePackageRegistry} from "../../core/AVACoreRulePackageRegistry.sol";
import {AVACoreTypes} from "../../core/AVACoreTypes.sol";
import {AVAEvidenceRegistry} from "../../core/AVAEvidenceRegistry.sol";
import {AVAGovernanceKernel} from "../../core/AVAGovernanceKernel.sol";
import {AVAIdentityRegistry} from "../../core/AVAIdentityRegistry.sol";
import {IAVAApplicationModule} from "../../interfaces/IAVAApplicationModule.sol";
import {IAVAAntiAbusePolicyModule} from "../../core/interfaces/IAVACoreRuleModules.sol";
import {IAVAStandingRevision} from "./IAVAStandingRevision.sol";
import {
    IAVAStandingComputationPolicyModule,
    IAVAStandingCredentialPolicyModule
} from "./IAVAStandingCredentialModules.sol";

contract AVAStandingComputationExtension {
    bytes32 private constant COMPUTATION_TYPE = keccak256("ava.extension.standing-computation.v1");

    struct ComputationInput {
        uint256 recognisedStateId;
        bytes32 roleKey;
        bytes32 authorityId;
        bytes32 subjectId;
        uint256 evidenceId;
        bytes32 vectorKey;
        bytes32 categoryHash;
        int256 lowerBound;
        int256 upperBound;
        bytes32 thresholdSetHash;
        bytes32 computationRuleHash;
        bytes32 sourceSetCommitment;
        bytes32 outputCommitment;
        uint64 epoch;
        string uri;
    }

    struct ComputationRecord {
        uint256 id;
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        uint256 recognisedStateId;
        uint256 recognisedStateTransitionId;
        bytes32 subjectId;
        uint256 evidenceId;
        uint256 revision;
        bytes32 vectorKey;
        bytes32 categoryHash;
        int256 lowerBound;
        int256 upperBound;
        bytes32 thresholdSetHash;
        bytes32 computationRuleHash;
        bytes32 sourceSetCommitment;
        bytes32 outputCommitment;
        uint64 epoch;
        string uri;
        bytes32 authorityId;
        address recordedBy;
        uint64 recordedAt;
        uint256 supersededBy;
        bool active;
    }

    struct ComputationModules {
        AVACoreRulePackageRegistry.VerifiedPackageContext rulePackage;
        IAVAApplicationModule application;
        IAVAStandingComputationPolicyModule standingComputation;
        IAVAAntiAbusePolicyModule antiAbuse;
    }

    AVAGovernanceKernel public immutable GOVERNANCE_KERNEL;
    AVAAuthorityMatrix public immutable AUTHORITY_MATRIX;
    AVAIdentityRegistry public immutable IDENTITY_REGISTRY;
    AVACoreRulePackageRegistry public immutable RULE_PACKAGE_REGISTRY;
    AVAEvidenceRegistry public immutable EVIDENCE_REGISTRY;
    IAVAStandingRevision public immutable REVISION_REGISTRY;

    mapping(uint256 => ComputationRecord) private computations;
    mapping(bytes32 => uint256) public activeComputationId;
    uint256 public nextComputationId = 1;

    event StandingComputationRecorded(
        uint256 indexed computationId,
        bytes32 indexed appId,
        bytes32 indexed subjectId,
        uint256 packageId,
        uint256 revision,
        bytes32 vectorKey,
        address recordedBy
    );
    event StandingComputationSuperseded(uint256 indexed computationId, uint256 indexed replacementComputationId);

    constructor(
        AVAGovernanceKernel governanceKernel_,
        AVAAuthorityMatrix authorityMatrix_,
        AVAIdentityRegistry identityRegistry_,
        AVACoreRulePackageRegistry rulePackageRegistry_,
        AVAEvidenceRegistry evidenceRegistry_,
        IAVAStandingRevision revisionRegistry_
    ) {
        if (
            address(governanceKernel_) == address(0) || address(authorityMatrix_) == address(0)
                || address(identityRegistry_) == address(0) || address(rulePackageRegistry_) == address(0)
                || address(evidenceRegistry_) == address(0) || address(revisionRegistry_) == address(0)
                || address(revisionRegistry_).code.length == 0
        ) revert AVACoreTypes.EmptyValue();
        if (
            address(governanceKernel_.AUTHORITY_MATRIX()) != address(authorityMatrix_)
                || address(governanceKernel_.IDENTITY_REGISTRY()) != address(identityRegistry_)
                || address(governanceKernel_.RULE_PACKAGE_REGISTRY()) != address(rulePackageRegistry_)
                || address(governanceKernel_.EVIDENCE_REGISTRY()) != address(evidenceRegistry_)
                || address(revisionRegistry_.GOVERNANCE_KERNEL()) != address(governanceKernel_)
        ) revert AVACoreTypes.InvalidState(0);
        GOVERNANCE_KERNEL = governanceKernel_;
        AUTHORITY_MATRIX = authorityMatrix_;
        IDENTITY_REGISTRY = identityRegistry_;
        RULE_PACKAGE_REGISTRY = rulePackageRegistry_;
        EVIDENCE_REGISTRY = evidenceRegistry_;
        REVISION_REGISTRY = revisionRegistry_;
    }

    function recordComputation(ComputationInput calldata input) external returns (uint256 computationId) {
        _requireInput(input);
        AVACoreTypes.RecognisedStateRecord memory state = GOVERNANCE_KERNEL.getRecognisedState(input.recognisedStateId);
        if (state.subjectId != input.subjectId || !_isStandingStatus(state.status)) {
            revert AVACoreTypes.InvalidState(input.recognisedStateId);
        }
        IDENTITY_REGISTRY.requireActiveSubjectReference(input.subjectId, state.appId);
        AUTHORITY_MATRIX.requireAuthorisedSubject(
            msg.sender, state.appId, input.roleKey, AVACoreTypes.ACTION_RECORD_STANDING_COMPUTATION, input.authorityId
        );
        ComputationModules memory modules = _verifiedComputationModules(state.packageId);
        if (modules.rulePackage.appId != state.appId || modules.rulePackage.workflowKey != state.workflowKey) {
            revert AVACoreTypes.InvalidState(state.packageId);
        }
        _requireEvidence(state.evidenceReceiptId, state);
        if (input.evidenceId != state.evidenceReceiptId) _requireEvidence(input.evidenceId, state);
        uint256 revision = REVISION_REGISTRY.currentRevision(state.packageId, input.subjectId);
        if (
            revision == 0
                || address(GOVERNANCE_KERNEL.postTransitionHookByPackage(state.packageId)) != address(REVISION_REGISTRY)
        ) revert AVACoreTypes.InvalidState(input.recognisedStateId);
        _validateApplicationAndAntiAbuse(input, state, modules);
        _validatePolicy(input, state, revision, modules.standingComputation);

        computationId = nextComputationId++;
        bytes32 key = _computationKey(state.packageId, input.subjectId, input.vectorKey);
        uint256 previousComputationId = activeComputationId[key];
        if (previousComputationId != 0) {
            computations[previousComputationId].active = false;
            computations[previousComputationId].supersededBy = computationId;
            emit StandingComputationSuperseded(previousComputationId, computationId);
        }
        computations[computationId] = ComputationRecord({
            id: computationId,
            appId: state.appId,
            workflowKey: state.workflowKey,
            packageId: state.packageId,
            recognisedStateId: state.id,
            recognisedStateTransitionId: state.lastTransitionId,
            subjectId: input.subjectId,
            evidenceId: input.evidenceId,
            revision: revision,
            vectorKey: input.vectorKey,
            categoryHash: input.categoryHash,
            lowerBound: input.lowerBound,
            upperBound: input.upperBound,
            thresholdSetHash: input.thresholdSetHash,
            computationRuleHash: input.computationRuleHash,
            sourceSetCommitment: input.sourceSetCommitment,
            outputCommitment: input.outputCommitment,
            epoch: input.epoch,
            uri: input.uri,
            authorityId: input.authorityId,
            recordedBy: msg.sender,
            recordedAt: uint64(block.timestamp),
            supersededBy: 0,
            active: true
        });
        activeComputationId[key] = computationId;
        emit StandingComputationRecorded(
            computationId, state.appId, input.subjectId, state.packageId, revision, input.vectorKey, msg.sender
        );
    }

    function getComputation(uint256 computationId) external view returns (ComputationRecord memory record) {
        record = computations[computationId];
        if (record.id == 0) revert AVACoreTypes.UnknownReference(computationId);
    }

    function isComputationCurrent(uint256 computationId) public view returns (bool) {
        ComputationRecord memory record = computations[computationId];
        if (!record.active || record.id == 0) return false;
        if (activeComputationId[_computationKey(record.packageId, record.subjectId, record.vectorKey)] != record.id) {
            return false;
        }
        try REVISION_REGISTRY.currentRevision(record.packageId, record.subjectId) returns (uint256 revision) {
            if (revision != record.revision) return false;
        } catch {
            return false;
        }
        try IDENTITY_REGISTRY.getSubjectContext(record.subjectId) returns (
            AVAIdentityRegistry.SubjectContext memory subject
        ) {
            if (!subject.active || subject.appId != record.appId) return false;
        } catch {
            return false;
        }
        AVACoreTypes.RecognisedStateRecord memory state;
        try GOVERNANCE_KERNEL.getRecognisedState(record.recognisedStateId) returns (
            AVACoreTypes.RecognisedStateRecord memory currentState
        ) {
            state = currentState;
            if (
                state.appId != record.appId || state.workflowKey != record.workflowKey
                    || state.packageId != record.packageId || state.subjectId != record.subjectId
                    || !_isStandingStatus(state.status)
            ) return false;
        } catch {
            return false;
        }
        if (!_isUsableEvidence(state.evidenceReceiptId, record, state.disclosurePolicyId)) return false;
        if (
            record.evidenceId != state.evidenceReceiptId
                && !_isUsableEvidence(record.evidenceId, record, state.disclosurePolicyId)
        ) {
            return false;
        }
        try RULE_PACKAGE_REGISTRY.getVerifiedPackageContext(record.packageId) returns (
            AVACoreRulePackageRegistry.VerifiedPackageContext memory rulePackage
        ) {
            return rulePackage.appId == record.appId && rulePackage.workflowKey == record.workflowKey;
        } catch {
            return false;
        }
    }

    function _validatePolicy(
        ComputationInput calldata input,
        AVACoreTypes.RecognisedStateRecord memory state,
        uint256 revision,
        IAVAStandingComputationPolicyModule standingComputation
    ) private view {
        standingComputation.validateStandingComputation(
            IAVAStandingComputationPolicyModule.StandingComputationContext({
                appId: state.appId,
                workflowKey: state.workflowKey,
                packageId: state.packageId,
                recognisedStateId: state.id,
                recognisedStateTransitionId: state.lastTransitionId,
                subjectId: input.subjectId,
                roleKey: input.roleKey,
                evidenceId: input.evidenceId,
                revision: revision,
                vectorKey: input.vectorKey,
                categoryHash: input.categoryHash,
                lowerBound: input.lowerBound,
                upperBound: input.upperBound,
                thresholdSetHash: input.thresholdSetHash,
                computationRuleHash: input.computationRuleHash,
                sourceSetCommitment: input.sourceSetCommitment,
                outputCommitment: input.outputCommitment,
                authorityId: input.authorityId,
                actor: msg.sender
            })
        );
    }

    function _validateApplicationAndAntiAbuse(
        ComputationInput calldata input,
        AVACoreTypes.RecognisedStateRecord memory state,
        ComputationModules memory modules
    ) private view {
        AVAGovernanceKernel.GovernedObjectReference memory
            objectRecord = GOVERNANCE_KERNEL.getGovernedObjectReference(state.governedObjectId);
        modules.application
            .validateDownstreamRecord(
                IAVAApplicationModule.DownstreamRecordContext({
                    appId: state.appId,
                    workflowKey: state.workflowKey,
                    packageId: state.packageId,
                    actionKey: AVACoreTypes.ACTION_RECORD_STANDING_COMPUTATION,
                    roleKey: input.roleKey,
                    recognisedStateId: state.id,
                    governedObjectId: state.governedObjectId,
                    objectTypeKey: objectRecord.objectTypeKey,
                    subjectId: input.subjectId,
                    evidenceReceiptId: input.evidenceId,
                    recordTypeKey: COMPUTATION_TYPE,
                    authorityId: input.authorityId,
                    actor: msg.sender
                })
            );
        if (address(modules.antiAbuse) == address(0)) return;
        modules.antiAbuse
            .validateAntiAbuse(
                IAVAAntiAbusePolicyModule.AntiAbuseContext({
                    appId: state.appId,
                    workflowKey: state.workflowKey,
                    packageId: state.packageId,
                    actionKey: AVACoreTypes.ACTION_RECORD_STANDING_COMPUTATION,
                    roleKey: input.roleKey,
                    targetId: state.id,
                    targetTypeKey: COMPUTATION_TYPE,
                    actorSubjectId: input.authorityId,
                    targetSubjectId: input.subjectId,
                    authorityId: input.authorityId,
                    actor: msg.sender
                })
            );
    }

    function _verifiedComputationModules(uint256 packageId) private view returns (ComputationModules memory modules) {
        bytes32[] memory keys = new bytes32[](3);
        keys[0] = AVACapabilityKeys.APPLICATION;
        keys[1] = AVACapabilityKeys.STANDING_COMPUTATION;
        keys[2] = AVACapabilityKeys.ANTI_ABUSE;
        (AVACoreRulePackageRegistry.VerifiedPackageContext memory rulePackage, address[] memory addresses) =
            RULE_PACKAGE_REGISTRY.getVerifiedModulesCompact(packageId, keys);
        if (addresses[1] == address(0)) revert AVACoreTypes.UnknownReference(packageId);
        modules = ComputationModules({
            rulePackage: rulePackage,
            application: IAVAApplicationModule(addresses[0]),
            standingComputation: IAVAStandingComputationPolicyModule(addresses[1]),
            antiAbuse: IAVAAntiAbusePolicyModule(addresses[2])
        });
    }

    function _requireEvidence(uint256 evidenceId, AVACoreTypes.RecognisedStateRecord memory state) private view {
        (bytes32 appId, bytes32 workflowKey,, bytes32 subjectId, uint256 disclosurePolicyId) =
            EVIDENCE_REGISTRY.requireUsableEvidenceReferenceForPackage(evidenceId, state.packageId);
        if (
            appId != state.appId || workflowKey != state.workflowKey
                || subjectId != state.subjectId || disclosurePolicyId != state.disclosurePolicyId
        ) revert AVACoreTypes.InvalidState(evidenceId);
    }

    function _requireInput(ComputationInput calldata input) private pure {
        if (
            input.recognisedStateId == 0 || input.roleKey == bytes32(0) || input.authorityId == bytes32(0)
                || input.subjectId == bytes32(0) || input.evidenceId == 0 || input.vectorKey == bytes32(0)
                || input.categoryHash == bytes32(0) || input.lowerBound > input.upperBound
                || input.thresholdSetHash == bytes32(0) || input.computationRuleHash == bytes32(0)
                || input.sourceSetCommitment == bytes32(0) || input.outputCommitment == bytes32(0) || input.epoch == 0
        ) revert AVACoreTypes.EmptyValue();
    }

    function _isUsableEvidence(uint256 evidenceId, ComputationRecord memory record, uint256 expectedDisclosurePolicyId)
        private
        view
        returns (bool)
    {
        try EVIDENCE_REGISTRY.requireUsableEvidenceReferenceForPackage(evidenceId, record.packageId) returns (
            bytes32 appId, bytes32 workflowKey, uint256, bytes32 subjectId, uint256 disclosurePolicyId
        ) {
            return appId == record.appId && workflowKey == record.workflowKey
                && subjectId == record.subjectId && disclosurePolicyId == expectedDisclosurePolicyId;
        } catch {
            return false;
        }
    }

    function _isStandingStatus(AVACoreTypes.RecognisedStateStatus status) private pure returns (bool) {
        return status == AVACoreTypes.RecognisedStateStatus.Vested
            || status == AVACoreTypes.RecognisedStateStatus.Restored
            || status == AVACoreTypes.RecognisedStateStatus.Downgraded
            || status == AVACoreTypes.RecognisedStateStatus.Voided;
    }

    function _computationKey(uint256 packageId, bytes32 subjectId, bytes32 vectorKey) private pure returns (bytes32) {
        return keccak256(abi.encode(packageId, subjectId, vectorKey));
    }
}

contract AVAStandingCredentialExtension {
    uint256 public constant MAX_CREDENTIAL_VALIDITY = 365 days;
    bytes32 private constant CREDENTIAL_TYPE = keccak256("ava.extension.standing-credential.v1");

    struct CredentialInput {
        uint256 computationId;
        bytes32 roleKey;
        bytes32 authorityId;
        uint64 expiresAt;
        string uri;
    }

    struct CredentialRecord {
        uint256 id;
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        uint256 computationId;
        bytes32 subjectId;
        uint256 evidenceId;
        uint256 revision;
        bytes32 vectorKey;
        bytes32 categoryHash;
        int256 lowerBound;
        int256 upperBound;
        uint64 issuedAt;
        uint64 expiresAt;
        string uri;
        bytes32 authorityId;
        address issuedBy;
        uint256 supersededBy;
        bool revoked;
    }

    struct CredentialModules {
        AVACoreRulePackageRegistry.VerifiedPackageContext rulePackage;
        IAVAApplicationModule application;
        IAVAStandingCredentialPolicyModule standingCredential;
        IAVAAntiAbusePolicyModule antiAbuse;
    }

    AVAAuthorityMatrix public immutable AUTHORITY_MATRIX;
    AVAIdentityRegistry public immutable IDENTITY_REGISTRY;
    AVACoreRulePackageRegistry public immutable RULE_PACKAGE_REGISTRY;
    AVAEvidenceRegistry public immutable EVIDENCE_REGISTRY;
    IAVAStandingRevision public immutable REVISION_REGISTRY;
    AVAStandingComputationExtension public immutable COMPUTATION_REGISTRY;

    mapping(uint256 => CredentialRecord) private credentials;
    mapping(bytes32 => uint256) public activeCredentialId;
    uint256 public nextCredentialId = 1;

    event StandingCredentialIssued(
        uint256 indexed credentialId,
        bytes32 indexed appId,
        bytes32 indexed subjectId,
        uint256 packageId,
        uint256 computationId,
        uint64 expiresAt,
        address issuedBy
    );
    event StandingCredentialRevoked(uint256 indexed credentialId, bytes32 authorityId, address revokedBy);
    event StandingCredentialSuperseded(
        uint256 indexed credentialId, uint256 indexed replacementCredentialId, bytes32 authorityId
    );

    constructor(
        AVAAuthorityMatrix authorityMatrix_,
        AVAIdentityRegistry identityRegistry_,
        AVACoreRulePackageRegistry rulePackageRegistry_,
        AVAEvidenceRegistry evidenceRegistry_,
        IAVAStandingRevision revisionRegistry_,
        AVAStandingComputationExtension computationRegistry_
    ) {
        if (
            address(authorityMatrix_) == address(0) || address(identityRegistry_) == address(0)
                || address(rulePackageRegistry_) == address(0) || address(evidenceRegistry_) == address(0)
                || address(revisionRegistry_) == address(0) || address(computationRegistry_) == address(0)
        ) revert AVACoreTypes.EmptyValue();
        if (
            address(computationRegistry_.AUTHORITY_MATRIX()) != address(authorityMatrix_)
                || address(computationRegistry_.IDENTITY_REGISTRY()) != address(identityRegistry_)
                || address(computationRegistry_.RULE_PACKAGE_REGISTRY()) != address(rulePackageRegistry_)
                || address(computationRegistry_.EVIDENCE_REGISTRY()) != address(evidenceRegistry_)
                || address(computationRegistry_.REVISION_REGISTRY()) != address(revisionRegistry_)
        ) revert AVACoreTypes.InvalidState(0);
        AUTHORITY_MATRIX = authorityMatrix_;
        IDENTITY_REGISTRY = identityRegistry_;
        RULE_PACKAGE_REGISTRY = rulePackageRegistry_;
        EVIDENCE_REGISTRY = evidenceRegistry_;
        REVISION_REGISTRY = revisionRegistry_;
        COMPUTATION_REGISTRY = computationRegistry_;
    }

    function issueCredential(CredentialInput calldata input) external returns (uint256 credentialId) {
        AVAStandingComputationExtension.ComputationRecord memory computation =
            _requireIssuableComputation(input, AVACoreTypes.ACTION_ISSUE_STANDING_CREDENTIAL);
        bytes32 key = _credentialKey(
            computation.packageId, computation.subjectId, computation.vectorKey, computation.categoryHash
        );
        if (activeCredentialId[key] != 0) revert AVACoreTypes.InvalidState(activeCredentialId[key]);
        credentialId = _issue(input, computation);
        activeCredentialId[key] = credentialId;
    }

    function supersedeCredential(uint256 credentialId, CredentialInput calldata input)
        external
        returns (uint256 replacementCredentialId)
    {
        CredentialRecord storage previous = _credentialStorage(credentialId);
        if (
            previous.revoked || previous.supersededBy != 0
                || activeCredentialId[
                        _credentialKey(
                            previous.packageId, previous.subjectId, previous.vectorKey, previous.categoryHash
                        )
                    ] != previous.id
        ) revert AVACoreTypes.InvalidState(credentialId);
        AVAStandingComputationExtension.ComputationRecord memory computation =
            _requireIssuableComputation(input, AVACoreTypes.ACTION_SUPERSEDE_STANDING_CREDENTIAL);
        if (
            previous.packageId != computation.packageId || previous.subjectId != computation.subjectId
                || previous.vectorKey != computation.vectorKey
        ) revert AVACoreTypes.InvalidState(credentialId);
        bytes32 replacementKey = _credentialKey(
            computation.packageId, computation.subjectId, computation.vectorKey, computation.categoryHash
        );
        uint256 occupiedCredentialId = activeCredentialId[replacementKey];
        if (occupiedCredentialId != 0 && occupiedCredentialId != credentialId) {
            revert AVACoreTypes.InvalidState(occupiedCredentialId);
        }
        replacementCredentialId = _issue(input, computation);
        previous.supersededBy = replacementCredentialId;
        delete activeCredentialId[
            _credentialKey(previous.packageId, previous.subjectId, previous.vectorKey, previous.categoryHash)
        ];
        activeCredentialId[replacementKey] = replacementCredentialId;
        emit StandingCredentialSuperseded(credentialId, replacementCredentialId, input.authorityId);
    }

    function revokeCredential(uint256 credentialId, bytes32 roleKey, bytes32 authorityId) external {
        CredentialRecord storage credential = _credentialStorage(credentialId);
        if (credential.revoked || credential.supersededBy != 0) revert AVACoreTypes.InvalidState(credentialId);
        AUTHORITY_MATRIX.requireAuthorisedSubject(
            msg.sender, credential.appId, roleKey, AVACoreTypes.ACTION_REVOKE_STANDING_CREDENTIAL, authorityId
        );
        _validateCredentialPolicy(
            credential, roleKey, authorityId, AVACoreTypes.ACTION_REVOKE_STANDING_CREDENTIAL, credential.expiresAt
        );
        credential.revoked = true;
        delete activeCredentialId[
            _credentialKey(credential.packageId, credential.subjectId, credential.vectorKey, credential.categoryHash)
        ];
        emit StandingCredentialRevoked(credentialId, authorityId, msg.sender);
    }

    function credentialProves(
        uint256 packageId,
        uint256 credentialId,
        bytes32 subjectId,
        bytes32 vectorKey,
        bytes32 categoryHash,
        int256 minimumLowerBound
    ) external view returns (bool) {
        CredentialRecord storage credential = credentials[credentialId];
        return credential.id != 0 && credential.packageId == packageId && credential.subjectId == subjectId
            && credential.vectorKey == vectorKey && credential.categoryHash == categoryHash
            && credential.lowerBound >= minimumLowerBound && _isActive(credential);
    }

    function isCredentialActive(uint256 credentialId) external view returns (bool) {
        CredentialRecord storage credential = credentials[credentialId];
        return credential.id != 0 && _isActive(credential);
    }

    function getCredential(uint256 credentialId) external view returns (CredentialRecord memory record) {
        record = credentials[credentialId];
        if (record.id == 0) revert AVACoreTypes.UnknownReference(credentialId);
    }

    function _requireIssuableComputation(CredentialInput calldata input, bytes32 actionKey)
        private
        view
        returns (AVAStandingComputationExtension.ComputationRecord memory computation)
    {
        if (
            input.computationId == 0 || input.roleKey == bytes32(0) || input.authorityId == bytes32(0)
                || input.expiresAt <= block.timestamp || input.expiresAt > block.timestamp + MAX_CREDENTIAL_VALIDITY
        ) revert AVACoreTypes.EmptyValue();
        computation = COMPUTATION_REGISTRY.getComputation(input.computationId);
        if (!COMPUTATION_REGISTRY.isComputationCurrent(input.computationId)) {
            revert AVACoreTypes.InvalidState(input.computationId);
        }
        CredentialModules memory modules = _verifiedCredentialModules(computation.packageId);
        if (
            modules.rulePackage.appId != computation.appId || modules.rulePackage.workflowKey != computation.workflowKey
        ) {
            revert AVACoreTypes.InvalidState(computation.packageId);
        }
        AUTHORITY_MATRIX.requireAuthorisedSubject(
            msg.sender, computation.appId, input.roleKey, actionKey, input.authorityId
        );
        _validateApplicationAndAntiAbuse(computation, input.roleKey, input.authorityId, actionKey, modules);
        modules.standingCredential
            .validateStandingCredential(
                IAVAStandingCredentialPolicyModule.StandingCredentialContext({
                    appId: computation.appId,
                    workflowKey: computation.workflowKey,
                    packageId: computation.packageId,
                    computationId: computation.id,
                    subjectId: computation.subjectId,
                    roleKey: input.roleKey,
                    evidenceId: computation.evidenceId,
                    revision: computation.revision,
                    vectorKey: computation.vectorKey,
                    categoryHash: computation.categoryHash,
                    lowerBound: computation.lowerBound,
                    upperBound: computation.upperBound,
                    actionKey: actionKey,
                    expiresAt: input.expiresAt,
                    authorityId: input.authorityId,
                    actor: msg.sender
                })
            );
    }

    function _validateApplicationAndAntiAbuse(
        AVAStandingComputationExtension.ComputationRecord memory computation,
        bytes32 roleKey,
        bytes32 authorityId,
        bytes32 actionKey,
        CredentialModules memory modules
    ) private view {
        AVAGovernanceKernel kernel = COMPUTATION_REGISTRY.GOVERNANCE_KERNEL();
        AVACoreTypes.RecognisedStateRecord memory state = kernel.getRecognisedState(computation.recognisedStateId);
        AVAGovernanceKernel.GovernedObjectReference memory objectRecord =
            kernel.getGovernedObjectReference(state.governedObjectId);
        if (
            state.appId != computation.appId || state.workflowKey != computation.workflowKey
                || state.packageId != computation.packageId || state.subjectId != computation.subjectId
        ) revert AVACoreTypes.InvalidState(computation.recognisedStateId);
        modules.application
            .validateDownstreamRecord(
                IAVAApplicationModule.DownstreamRecordContext({
                    appId: computation.appId,
                    workflowKey: computation.workflowKey,
                    packageId: computation.packageId,
                    actionKey: actionKey,
                    roleKey: roleKey,
                    recognisedStateId: state.id,
                    governedObjectId: state.governedObjectId,
                    objectTypeKey: objectRecord.objectTypeKey,
                    subjectId: computation.subjectId,
                    evidenceReceiptId: computation.evidenceId,
                    recordTypeKey: CREDENTIAL_TYPE,
                    authorityId: authorityId,
                    actor: msg.sender
                })
            );
        if (address(modules.antiAbuse) == address(0)) return;
        modules.antiAbuse
            .validateAntiAbuse(
                IAVAAntiAbusePolicyModule.AntiAbuseContext({
                    appId: computation.appId,
                    workflowKey: computation.workflowKey,
                    packageId: computation.packageId,
                    actionKey: actionKey,
                    roleKey: roleKey,
                    targetId: state.id,
                    targetTypeKey: CREDENTIAL_TYPE,
                    actorSubjectId: authorityId,
                    targetSubjectId: computation.subjectId,
                    authorityId: authorityId,
                    actor: msg.sender
                })
            );
    }

    function _issue(
        CredentialInput calldata input,
        AVAStandingComputationExtension.ComputationRecord memory computation
    ) private returns (uint256 credentialId) {
        credentialId = nextCredentialId++;
        credentials[credentialId] = CredentialRecord({
            id: credentialId,
            appId: computation.appId,
            workflowKey: computation.workflowKey,
            packageId: computation.packageId,
            computationId: computation.id,
            subjectId: computation.subjectId,
            evidenceId: computation.evidenceId,
            revision: computation.revision,
            vectorKey: computation.vectorKey,
            categoryHash: computation.categoryHash,
            lowerBound: computation.lowerBound,
            upperBound: computation.upperBound,
            issuedAt: uint64(block.timestamp),
            expiresAt: input.expiresAt,
            uri: input.uri,
            authorityId: input.authorityId,
            issuedBy: msg.sender,
            supersededBy: 0,
            revoked: false
        });
        emit StandingCredentialIssued(
            credentialId,
            computation.appId,
            computation.subjectId,
            computation.packageId,
            computation.id,
            input.expiresAt,
            msg.sender
        );
    }

    function _validateCredentialPolicy(
        CredentialRecord storage credential,
        bytes32 roleKey,
        bytes32 authorityId,
        bytes32 actionKey,
        uint64 expiresAt
    ) private view {
        AVAStandingComputationExtension.ComputationRecord memory computation =
            COMPUTATION_REGISTRY.getComputation(credential.computationId);
        CredentialModules memory modules = _verifiedCredentialModules(credential.packageId);
        if (modules.rulePackage.appId != credential.appId || modules.rulePackage.workflowKey != credential.workflowKey)
        {
            revert AVACoreTypes.InvalidState(credential.packageId);
        }
        _validateApplicationAndAntiAbuse(computation, roleKey, authorityId, actionKey, modules);
        modules.standingCredential
            .validateStandingCredential(
                IAVAStandingCredentialPolicyModule.StandingCredentialContext({
                    appId: credential.appId,
                    workflowKey: credential.workflowKey,
                    packageId: credential.packageId,
                    computationId: credential.computationId,
                    subjectId: credential.subjectId,
                    roleKey: roleKey,
                    evidenceId: credential.evidenceId,
                    revision: credential.revision,
                    vectorKey: credential.vectorKey,
                    categoryHash: credential.categoryHash,
                    lowerBound: credential.lowerBound,
                    upperBound: credential.upperBound,
                    actionKey: actionKey,
                    expiresAt: expiresAt,
                    authorityId: authorityId,
                    actor: msg.sender
                })
            );
    }

    function _verifiedCredentialModules(uint256 packageId) private view returns (CredentialModules memory modules) {
        bytes32[] memory keys = new bytes32[](3);
        keys[0] = AVACapabilityKeys.APPLICATION;
        keys[1] = AVACapabilityKeys.STANDING_CREDENTIAL;
        keys[2] = AVACapabilityKeys.ANTI_ABUSE;
        (AVACoreRulePackageRegistry.VerifiedPackageContext memory rulePackage, address[] memory addresses) =
            RULE_PACKAGE_REGISTRY.getVerifiedModulesCompact(packageId, keys);
        if (addresses[1] == address(0)) revert AVACoreTypes.UnknownReference(packageId);
        modules = CredentialModules({
            rulePackage: rulePackage,
            application: IAVAApplicationModule(addresses[0]),
            standingCredential: IAVAStandingCredentialPolicyModule(addresses[1]),
            antiAbuse: IAVAAntiAbusePolicyModule(addresses[2])
        });
    }

    function _isActive(CredentialRecord storage credential) private view returns (bool) {
        if (credential.revoked || credential.supersededBy != 0 || credential.expiresAt <= block.timestamp) {
            return false;
        }
        if (
            activeCredentialId[
                    _credentialKey(
                        credential.packageId, credential.subjectId, credential.vectorKey, credential.categoryHash
                    )
                ] != credential.id
        ) return false;
        return COMPUTATION_REGISTRY.isComputationCurrent(credential.computationId);
    }

    function _credentialStorage(uint256 credentialId) private view returns (CredentialRecord storage credential) {
        credential = credentials[credentialId];
        if (credential.id == 0) revert AVACoreTypes.UnknownReference(credentialId);
    }

    function _credentialKey(uint256 packageId, bytes32 subjectId, bytes32 vectorKey, bytes32 categoryHash)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(packageId, subjectId, vectorKey, categoryHash));
    }
}
