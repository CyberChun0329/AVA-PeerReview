// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "./AVADataTypes.sol";
import {AuthorityMatrix} from "./AuthorityMatrix.sol";
import {AVAStateMachine} from "./AVAStateMachine.sol";
import {AVARulePackageRegistry} from "./AVARulePackageRegistry.sol";
import {EvidenceCommitmentRegistry} from "./EvidenceCommitmentRegistry.sol";
import {DisclosurePolicyRegistry} from "./DisclosurePolicyRegistry.sol";
import {ZKProofRegistry} from "./ZKProofRegistry.sol";
import {IDisclosureExecutionModule} from "./interfaces/IDisclosureExecutionModule.sol";

contract DisclosureAccessExecutor {
    AuthorityMatrix public immutable authorityMatrix;
    AVARulePackageRegistry public immutable rulePackageRegistry;
    EvidenceCommitmentRegistry public immutable evidenceRegistry;
    DisclosurePolicyRegistry public immutable disclosureRegistry;
    AVAStateMachine public immutable stateMachine;
    ZKProofRegistry public immutable proofRegistry;
    IDisclosureExecutionModule public immutable defaultExecutionModule;
    uint256 public nextDisclosureExecutionId = 1;

    mapping(uint256 => AVADataTypes.DisclosureExecutionRecord) private disclosureExecutions;
    mapping(bytes32 => uint256) public disclosureExecutionIdByNullifier;

    event DisclosureExecutionModuleConfigured(bytes32 indexed workflowKey, address indexed module, address configuredBy);
    event DisclosureExecutionRecorded(
        uint256 indexed id,
        bytes32 indexed workflowKey,
        AVADataTypes.DisclosureExecutionKind indexed kind,
        AVADataTypes.DisclosureTargetKind targetKind,
        uint256 targetId
    );

    constructor(
        AuthorityMatrix authorityMatrix_,
        AVARulePackageRegistry rulePackageRegistry_,
        EvidenceCommitmentRegistry evidenceRegistry_,
        DisclosurePolicyRegistry disclosureRegistry_,
        AVAStateMachine stateMachine_,
        ZKProofRegistry proofRegistry_,
        IDisclosureExecutionModule defaultExecutionModule_
    ) {
        if (address(defaultExecutionModule_) == address(0)) revert AVADataTypes.EmptyValue();
        authorityMatrix = authorityMatrix_;
        rulePackageRegistry = rulePackageRegistry_;
        evidenceRegistry = evidenceRegistry_;
        disclosureRegistry = disclosureRegistry_;
        stateMachine = stateMachine_;
        proofRegistry = proofRegistry_;
        defaultExecutionModule = defaultExecutionModule_;
    }

    /// @dev Legacy compatibility entrypoint. Disclosure execution modules are
    /// bound in AVA rule packages; this function cannot mutate runtime module
    /// configuration or override a target package.
    function configureWorkflowExecutionModule(
        AVADataTypes.Role actingRole,
        bytes32 workflowKey,
        IDisclosureExecutionModule module,
        bytes32 authorityId
    ) external view {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.RecordDisclosureExecution, authorityId
        );
        if (workflowKey == bytes32(0) || address(module) == address(0) || address(module).code.length == 0) {
            revert AVADataTypes.EmptyValue();
        }
        AVARulePackageRegistry.RulePackage memory rulePackage = rulePackageRegistry.getRulePackage(workflowKey);
        (module);
        revert AVADataTypes.InvalidState(rulePackage.packageId);
    }

    function recordAccessGrant(
        AVADataTypes.Role actingRole,
        bytes32 workflowKey,
        AVADataTypes.DisclosureTargetKind targetKind,
        uint256 targetId,
        uint256 disclosurePolicyId,
        bytes32 subjectId,
        uint256 expiresAt,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.RecordDisclosureExecution, authorityId
        );
        authorityMatrix.requireKnownActiveSubject(subjectId);
        if (expiresAt <= block.timestamp) revert AVADataTypes.InvalidState(expiresAt);
        uint256 packageId = _validateTarget(workflowKey, targetKind, targetId, disclosurePolicyId);
        IDisclosureExecutionModule.DisclosureExecutionContext memory context;
        context.workflowKey = workflowKey;
        context.kind = AVADataTypes.DisclosureExecutionKind.AccessGrant;
        context.targetKind = targetKind;
        context.targetId = targetId;
        context.disclosurePolicyId = disclosurePolicyId;
        context.subjectId = subjectId;
        _validateExecutionModule(packageId, context);
        AVADataTypes.DisclosureExecutionRecord memory record;
        record.workflowKey = workflowKey;
        record.packageId = packageId;
        record.kind = AVADataTypes.DisclosureExecutionKind.AccessGrant;
        record.status = AVADataTypes.DisclosureExecutionStatus.Recorded;
        record.targetKind = targetKind;
        record.targetId = targetId;
        record.disclosurePolicyId = disclosurePolicyId;
        record.subjectId = subjectId;
        record.expiresAt = expiresAt;
        record.authorityRole = actingRole;
        record.authorityId = authorityId;
        record.uri = uri;
        id = _recordDisclosureExecution(record);
    }

    function recordAccessRevocation(
        AVADataTypes.Role actingRole,
        uint256 grantExecutionId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.RecordDisclosureExecution, authorityId
        );
        AVADataTypes.DisclosureExecutionRecord storage grant = disclosureExecutions[grantExecutionId];
        if (grant.id == 0) revert AVADataTypes.UnknownReference(grantExecutionId);
        if (
            grant.kind != AVADataTypes.DisclosureExecutionKind.AccessGrant
                || grant.status != AVADataTypes.DisclosureExecutionStatus.Recorded
        ) {
            revert AVADataTypes.InvalidState(grantExecutionId);
        }
        if (grant.expiresAt <= block.timestamp) revert AVADataTypes.InvalidState(grantExecutionId);
        IDisclosureExecutionModule.DisclosureExecutionContext memory context;
        context.workflowKey = grant.workflowKey;
        context.kind = AVADataTypes.DisclosureExecutionKind.AccessRevocation;
        context.targetKind = grant.targetKind;
        context.targetId = grant.targetId;
        context.disclosurePolicyId = grant.disclosurePolicyId;
        context.subjectId = grant.subjectId;
        _validateExecutionModule(grant.packageId, context);
        grant.status = AVADataTypes.DisclosureExecutionStatus.Revoked;
        AVADataTypes.DisclosureExecutionRecord memory record;
        record.workflowKey = grant.workflowKey;
        record.packageId = grant.packageId;
        record.kind = AVADataTypes.DisclosureExecutionKind.AccessRevocation;
        record.status = AVADataTypes.DisclosureExecutionStatus.Recorded;
        record.targetKind = grant.targetKind;
        record.targetId = grant.targetId;
        record.disclosurePolicyId = grant.disclosurePolicyId;
        record.subjectId = grant.subjectId;
        record.sourceDisclosureExecutionId = grantExecutionId;
        record.authorityRole = actingRole;
        record.authorityId = authorityId;
        record.uri = uri;
        id = _recordDisclosureExecution(record);
    }

    function recordAccessExpiry(
        AVADataTypes.Role actingRole,
        uint256 grantExecutionId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.RecordDisclosureExecution, authorityId
        );
        AVADataTypes.DisclosureExecutionRecord storage grant = disclosureExecutions[grantExecutionId];
        if (grant.id == 0) revert AVADataTypes.UnknownReference(grantExecutionId);
        if (
            grant.kind != AVADataTypes.DisclosureExecutionKind.AccessGrant
                || grant.status != AVADataTypes.DisclosureExecutionStatus.Recorded
                || grant.expiresAt > block.timestamp
        ) {
            revert AVADataTypes.InvalidState(grantExecutionId);
        }
        IDisclosureExecutionModule.DisclosureExecutionContext memory context;
        context.workflowKey = grant.workflowKey;
        context.kind = AVADataTypes.DisclosureExecutionKind.ExpiryExecuted;
        context.targetKind = grant.targetKind;
        context.targetId = grant.targetId;
        context.disclosurePolicyId = grant.disclosurePolicyId;
        context.subjectId = grant.subjectId;
        _validateExecutionModule(grant.packageId, context);
        grant.status = AVADataTypes.DisclosureExecutionStatus.Expired;
        AVADataTypes.DisclosureExecutionRecord memory record;
        record.workflowKey = grant.workflowKey;
        record.packageId = grant.packageId;
        record.kind = AVADataTypes.DisclosureExecutionKind.ExpiryExecuted;
        record.status = AVADataTypes.DisclosureExecutionStatus.Expired;
        record.targetKind = grant.targetKind;
        record.targetId = grant.targetId;
        record.disclosurePolicyId = grant.disclosurePolicyId;
        record.subjectId = grant.subjectId;
        record.sourceDisclosureExecutionId = grantExecutionId;
        record.expiresAt = grant.expiresAt;
        record.authorityRole = actingRole;
        record.authorityId = authorityId;
        record.uri = uri;
        id = _recordDisclosureExecution(record);
    }

    function recordAccessSupersession(
        AVADataTypes.Role actingRole,
        uint256 grantExecutionId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.RecordDisclosureExecution, authorityId
        );
        AVADataTypes.DisclosureExecutionRecord storage grant = disclosureExecutions[grantExecutionId];
        if (grant.id == 0) revert AVADataTypes.UnknownReference(grantExecutionId);
        if (
            grant.kind != AVADataTypes.DisclosureExecutionKind.AccessGrant
                || grant.status != AVADataTypes.DisclosureExecutionStatus.Recorded
        ) {
            revert AVADataTypes.InvalidState(grantExecutionId);
        }
        if (grant.expiresAt <= block.timestamp) revert AVADataTypes.InvalidState(grantExecutionId);
        IDisclosureExecutionModule.DisclosureExecutionContext memory context;
        context.workflowKey = grant.workflowKey;
        context.kind = AVADataTypes.DisclosureExecutionKind.SupersessionExecuted;
        context.targetKind = grant.targetKind;
        context.targetId = grant.targetId;
        context.disclosurePolicyId = grant.disclosurePolicyId;
        context.subjectId = grant.subjectId;
        _validateExecutionModule(grant.packageId, context);
        grant.status = AVADataTypes.DisclosureExecutionStatus.Superseded;
        AVADataTypes.DisclosureExecutionRecord memory record;
        record.workflowKey = grant.workflowKey;
        record.packageId = grant.packageId;
        record.kind = AVADataTypes.DisclosureExecutionKind.SupersessionExecuted;
        record.status = AVADataTypes.DisclosureExecutionStatus.Superseded;
        record.targetKind = grant.targetKind;
        record.targetId = grant.targetId;
        record.disclosurePolicyId = grant.disclosurePolicyId;
        record.subjectId = grant.subjectId;
        record.sourceDisclosureExecutionId = grantExecutionId;
        record.expiresAt = grant.expiresAt;
        record.authorityRole = actingRole;
        record.authorityId = authorityId;
        record.uri = uri;
        id = _recordDisclosureExecution(record);
    }

    function recordDisclosureLifecycleExecution(
        AVADataTypes.Role actingRole,
        bytes32 workflowKey,
        AVADataTypes.DisclosureExecutionKind kind,
        AVADataTypes.DisclosureTargetKind targetKind,
        uint256 targetId,
        uint256 disclosurePolicyId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.RecordDisclosureExecution, authorityId
        );
        if (
            kind != AVADataTypes.DisclosureExecutionKind.ExpiryExecuted
                && kind != AVADataTypes.DisclosureExecutionKind.SupersessionExecuted
        ) {
            revert AVADataTypes.InvalidState(uint256(kind));
        }
        uint256 packageId = _validateTarget(workflowKey, targetKind, targetId, disclosurePolicyId);
        IDisclosureExecutionModule.DisclosureExecutionContext memory context;
        context.workflowKey = workflowKey;
        context.kind = kind;
        context.targetKind = targetKind;
        context.targetId = targetId;
        context.disclosurePolicyId = disclosurePolicyId;
        _validateExecutionModule(packageId, context);
        AVADataTypes.DisclosureExecutionRecord memory record;
        record.workflowKey = workflowKey;
        record.packageId = packageId;
        record.kind = kind;
        record.status = kind == AVADataTypes.DisclosureExecutionKind.SupersessionExecuted
            ? AVADataTypes.DisclosureExecutionStatus.Superseded
            : AVADataTypes.DisclosureExecutionStatus.Expired;
        record.targetKind = targetKind;
        record.targetId = targetId;
        record.disclosurePolicyId = disclosurePolicyId;
        record.authorityRole = actingRole;
        record.authorityId = authorityId;
        record.uri = uri;
        id = _recordDisclosureExecution(record);
    }

    function recordVoluntaryDisclosureIntent(
        AVADataTypes.Role actingRole,
        bytes32 workflowKey,
        AVADataTypes.DisclosureTargetKind targetKind,
        uint256 targetId,
        uint256 disclosurePolicyId,
        bytes32 subjectId,
        string calldata uri
    ) external returns (uint256 id) {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.RecordDisclosureExecution, subjectId
        );
        uint256 packageId = _validateTarget(workflowKey, targetKind, targetId, disclosurePolicyId);
        IDisclosureExecutionModule.DisclosureExecutionContext memory context;
        context.workflowKey = workflowKey;
        context.kind = AVADataTypes.DisclosureExecutionKind.VoluntaryDisclosureIntent;
        context.targetKind = targetKind;
        context.targetId = targetId;
        context.disclosurePolicyId = disclosurePolicyId;
        context.subjectId = subjectId;
        _validateExecutionModule(packageId, context);
        AVADataTypes.DisclosureExecutionRecord memory record;
        record.workflowKey = workflowKey;
        record.packageId = packageId;
        record.kind = AVADataTypes.DisclosureExecutionKind.VoluntaryDisclosureIntent;
        record.status = AVADataTypes.DisclosureExecutionStatus.Recorded;
        record.targetKind = targetKind;
        record.targetId = targetId;
        record.disclosurePolicyId = disclosurePolicyId;
        record.subjectId = subjectId;
        record.authorityRole = actingRole;
        record.authorityId = subjectId;
        record.uri = uri;
        id = _recordDisclosureExecution(record);
    }

    function recordAnonymousChallengeProofUse(
        AVADataTypes.Role actingRole,
        uint256 challengeId,
        uint256 disclosurePolicyId,
        uint256 proofReceiptId,
        bytes32 subjectCommitment,
        bytes32 nullifierHash,
        string calldata uri
    ) external returns (uint256 id) {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.RecordDisclosureExecution, subjectCommitment
        );
        AVADataTypes.ChallengeRecord memory challenge = stateMachine.getChallenge(challengeId);
        _validateTarget(
            challenge.workflowKey, AVADataTypes.DisclosureTargetKind.Challenge, challengeId, disclosurePolicyId
        );
        _validateAnonymousChallengeProofUse(
            actingRole, challengeId, challenge, disclosurePolicyId, proofReceiptId, subjectCommitment, nullifierHash
        );
        IDisclosureExecutionModule.DisclosureExecutionContext memory context;
        context.workflowKey = challenge.workflowKey;
        context.kind = AVADataTypes.DisclosureExecutionKind.AnonymousChallengeUse;
        context.targetKind = AVADataTypes.DisclosureTargetKind.Challenge;
        context.targetId = challengeId;
        context.disclosurePolicyId = disclosurePolicyId;
        context.subjectCommitment = subjectCommitment;
        context.nullifierHash = nullifierHash;
        context.proofReceiptId = proofReceiptId;
        _validateExecutionModule(challenge.packageId, context);
        AVADataTypes.DisclosureExecutionRecord memory record;
        record.workflowKey = challenge.workflowKey;
        record.packageId = challenge.packageId;
        record.kind = AVADataTypes.DisclosureExecutionKind.AnonymousChallengeUse;
        record.status = AVADataTypes.DisclosureExecutionStatus.Recorded;
        record.targetKind = AVADataTypes.DisclosureTargetKind.Challenge;
        record.targetId = challengeId;
        record.disclosurePolicyId = disclosurePolicyId;
        record.subjectCommitment = subjectCommitment;
        record.nullifierHash = nullifierHash;
        record.proofReceiptId = proofReceiptId;
        ZKProofRegistry.ProofReceipt memory proofReceipt = proofRegistry.getProofReceipt(proofReceiptId);
        record.proofContextHash = proofReceipt.contextHash;
        record.proofVerifier = proofReceipt.verifier;
        record.proofDomainHash = proofReceipt.proofDomainHash;
        record.authorityRole = actingRole;
        record.authorityId = subjectCommitment;
        record.uri = uri;
        id = _recordDisclosureExecution(record);
        disclosureExecutionIdByNullifier[nullifierHash] = id;
    }

    function getDisclosureExecution(uint256 id) external view returns (AVADataTypes.DisclosureExecutionRecord memory) {
        AVADataTypes.DisclosureExecutionRecord memory record = disclosureExecutions[id];
        if (record.id == 0) revert AVADataTypes.UnknownReference(id);
        return record;
    }

    function getWorkflowExecutionModule(bytes32 workflowKey) external view returns (IDisclosureExecutionModule) {
        AVARulePackageRegistry.RulePackage memory rulePackage = rulePackageRegistry.getRulePackage(workflowKey);
        return _executionModule(rulePackage.packageId);
    }

    function _recordDisclosureExecution(AVADataTypes.DisclosureExecutionRecord memory record)
        internal
        returns (uint256 id)
    {
        if (
            record.kind == AVADataTypes.DisclosureExecutionKind.None || bytes(record.uri).length == 0
                || record.authorityId == bytes32(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
        id = nextDisclosureExecutionId++;
        record.id = id;
        record.recordedBy = msg.sender;
        disclosureExecutions[id] = record;
        emit DisclosureExecutionRecorded(id, record.workflowKey, record.kind, record.targetKind, record.targetId);
    }

    function _validateTarget(
        bytes32 workflowKey,
        AVADataTypes.DisclosureTargetKind targetKind,
        uint256 targetId,
        uint256 disclosurePolicyId
    ) internal view returns (uint256 packageId) {
        if (workflowKey == bytes32(0) || targetKind == AVADataTypes.DisclosureTargetKind.None || disclosurePolicyId == 0) {
            revert AVADataTypes.EmptyValue();
        }
        disclosureRegistry.getDisclosurePolicy(disclosurePolicyId);
        if (targetKind == AVADataTypes.DisclosureTargetKind.EvidenceReceipt) {
            AVADataTypes.EvidenceReceipt memory receipt = evidenceRegistry.getEvidenceReceipt(targetId);
            if (receipt.workflowKey != workflowKey || receipt.disclosurePolicyId != disclosurePolicyId) {
                revert AVADataTypes.InvalidState(targetId);
            }
            packageId = receipt.packageId;
        } else if (targetKind == AVADataTypes.DisclosureTargetKind.RecognisedState) {
            AVADataTypes.RecognisedStateRecord memory state = stateMachine.getRecognisedState(targetId);
            if (state.workflowKey != workflowKey || state.disclosurePolicyId != disclosurePolicyId) {
                revert AVADataTypes.InvalidState(targetId);
            }
            packageId = state.packageId;
        } else if (targetKind == AVADataTypes.DisclosureTargetKind.Challenge) {
            AVADataTypes.ChallengeRecord memory challenge = stateMachine.getChallenge(targetId);
            if (challenge.workflowKey != workflowKey || challenge.disclosurePolicyId != disclosurePolicyId) {
                revert AVADataTypes.InvalidState(targetId);
            }
            packageId = challenge.packageId;
        } else if (targetKind == AVADataTypes.DisclosureTargetKind.Workflow) {
            if (targetId != 0) revert AVADataTypes.InvalidState(targetId);
            packageId = rulePackageRegistry.getRulePackage(workflowKey).packageId;
        } else if (targetKind == AVADataTypes.DisclosureTargetKind.DisclosurePolicy) {
            if (targetId != disclosurePolicyId) revert AVADataTypes.InvalidState(targetId);
            packageId = rulePackageRegistry.getRulePackage(workflowKey).packageId;
        } else {
            revert AVADataTypes.InvalidState(uint256(targetKind));
        }
    }

    function _validateExecutionModule(
        uint256 packageId,
        IDisclosureExecutionModule.DisclosureExecutionContext memory context
    )
        internal
        view
    {
        context.actor = msg.sender;
        _executionModule(packageId).validateDisclosureExecution(context);
    }

    function _validateAnonymousChallengeProofUse(
        AVADataTypes.Role actingRole,
        uint256 challengeId,
        AVADataTypes.ChallengeRecord memory challenge,
        uint256 disclosurePolicyId,
        uint256 proofReceiptId,
        bytes32 subjectCommitment,
        bytes32 nullifierHash
    ) internal view {
        ZKProofRegistry.ProofReceipt memory proofReceipt = proofRegistry.getProofReceipt(proofReceiptId);
        bytes32 expectedContextHash = proofRegistry.computeDisclosureContextHashForPackage(
            challenge.packageId,
            challenge.workflowKey,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.RecordDisclosureExecution,
            bytes32(challengeId),
            actingRole,
            disclosurePolicyId,
            subjectCommitment
        );
        if (
            subjectCommitment == bytes32(0) || nullifierHash == bytes32(0)
                || challenge.challengerSubjectId != subjectCommitment || proofReceipt.packageId != challenge.packageId
                || proofReceipt.contextHash != expectedContextHash || proofReceipt.subjectCommitment != subjectCommitment
                || proofReceipt.nullifierHash != nullifierHash || disclosureExecutionIdByNullifier[nullifierHash] != 0
        ) {
            revert AVADataTypes.InvalidState(proofReceiptId);
        }
    }

    function _executionModule(uint256 packageId) internal view returns (IDisclosureExecutionModule module) {
        module = rulePackageRegistry.getRulePackageById(packageId).disclosureExecutionModule;
        if (address(module) == address(0)) {
            module = defaultExecutionModule;
        }
    }
}
