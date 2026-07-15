// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "./AVADataTypes.sol";
import {AuthorityMatrix} from "./AuthorityMatrix.sol";
import {AVARulePackageRegistry} from "./AVARulePackageRegistry.sol";
import {EvidenceCommitmentRegistry} from "./EvidenceCommitmentRegistry.sol";
import {AVAStateMachine} from "./AVAStateMachine.sol";
import {AVAChallengeWorkflow} from "./AVAChallengeWorkflow.sol";

contract AttestationAuditModule {
    AuthorityMatrix public immutable authorityMatrix;
    AVARulePackageRegistry public immutable rulePackageRegistry;
    EvidenceCommitmentRegistry public immutable evidenceRegistry;
    AVAStateMachine public immutable stateMachine;
    AVAChallengeWorkflow public immutable challengeWorkflow;
    uint256 public nextAttestationId = 1;

    mapping(uint256 => AVADataTypes.AttestationRecord) private attestations;

    struct AttestationContext {
        AVADataTypes.Role actingRole;
        bytes32 workflowKey;
        AVADataTypes.AttestationTargetKind targetKind;
        AVADataTypes.Action action;
        bytes32 objectId;
        uint256 evidenceReceiptId;
        bytes32 attestationHash;
        bytes32 authorityId;
    }

    event AttestationRecorded(
        uint256 indexed id,
        bytes32 indexed objectId,
        AVADataTypes.AttestationTargetKind targetKind,
        AVADataTypes.Action action,
        string attestationType,
        string uri,
        address indexed recordedBy
    );

    constructor(
        AuthorityMatrix authorityMatrix_,
        AVARulePackageRegistry rulePackageRegistry_,
        EvidenceCommitmentRegistry evidenceRegistry_,
        AVAStateMachine stateMachine_,
        AVAChallengeWorkflow challengeWorkflow_
    ) {
        authorityMatrix = authorityMatrix_;
        rulePackageRegistry = rulePackageRegistry_;
        evidenceRegistry = evidenceRegistry_;
        stateMachine = stateMachine_;
        challengeWorkflow = challengeWorkflow_;
    }

    function recordAttestation(
        AVADataTypes.Role actingRole,
        bytes32 workflowKey,
        AVADataTypes.Action action,
        bytes32 objectId,
        uint256 evidenceReceiptId,
        bytes32 attestationHash,
        bytes32 authorityId,
        string calldata attestationType,
        string calldata uri
    ) external returns (uint256 id) {
        return _recordEvidenceReceiptAttestation(
            AttestationContext({
                actingRole: actingRole,
                workflowKey: workflowKey,
                targetKind: AVADataTypes.AttestationTargetKind.EvidenceReceipt,
                action: action,
                objectId: objectId,
                evidenceReceiptId: evidenceReceiptId,
                attestationHash: attestationHash,
                authorityId: authorityId
            }),
            attestationType,
            uri
        );
    }

    function recordRecognisedStateAttestation(
        AVADataTypes.Role actingRole,
        uint256 recognisedStateId,
        bytes32 attestationHash,
        bytes32 authorityId,
        string calldata attestationType,
        string calldata uri
    ) external returns (uint256 id) {
        AVADataTypes.RecognisedStateRecord memory recognisedState = stateMachine.getRecognisedState(recognisedStateId);
        return _recordAttestationWithPackage(
            AttestationContext({
                actingRole: actingRole,
                workflowKey: recognisedState.workflowKey,
                targetKind: AVADataTypes.AttestationTargetKind.RecognisedState,
                action: AVADataTypes.Action.RecordAttestation,
                objectId: bytes32(recognisedStateId),
                evidenceReceiptId: recognisedState.evidenceReceiptId,
                attestationHash: attestationHash,
                authorityId: authorityId
            }),
            recognisedState.packageId,
            attestationType,
            uri
        );
    }

    function recordRecognisedStateTransitionAttestation(
        AVADataTypes.Role actingRole,
        uint256 transitionId,
        bytes32 attestationHash,
        bytes32 authorityId,
        string calldata attestationType,
        string calldata uri
    ) external returns (uint256 id) {
        AVADataTypes.RecognisedStateTransitionRecord memory transition =
            stateMachine.getRecognisedStateTransition(transitionId);
        AVARulePackageRegistry.RulePackage memory decisionPackage =
            rulePackageRegistry.getRulePackageById(transition.decisionPackageId);
        return _recordAttestationWithPackage(
            AttestationContext({
                actingRole: actingRole,
                workflowKey: decisionPackage.workflowKey,
                targetKind: AVADataTypes.AttestationTargetKind.RecognisedStateTransition,
                action: transition.action,
                objectId: bytes32(transitionId),
                evidenceReceiptId: transition.evidenceReceiptId,
                attestationHash: attestationHash,
                authorityId: authorityId
            }),
            transition.decisionPackageId,
            attestationType,
            uri
        );
    }

    function recordChallengeTransitionAttestation(
        AVADataTypes.Role actingRole,
        uint256 transitionId,
        bytes32 attestationHash,
        bytes32 authorityId,
        string calldata attestationType,
        string calldata uri
    ) external returns (uint256 id) {
        AVADataTypes.ChallengeTransitionRecord memory transition =
            challengeWorkflow.getChallengeTransition(transitionId);
        return _recordAttestationWithPackage(
            AttestationContext({
                actingRole: actingRole,
                workflowKey: transition.workflowKey,
                targetKind: AVADataTypes.AttestationTargetKind.ChallengeTransition,
                action: _challengeTransitionAction(transition.transitionKind),
                objectId: bytes32(transitionId),
                evidenceReceiptId: transition.evidenceReceiptId,
                attestationHash: attestationHash,
                authorityId: authorityId
            }),
            transition.packageId,
            attestationType,
            uri
        );
    }

    function _recordEvidenceReceiptAttestation(
        AttestationContext memory context,
        string calldata attestationType,
        string calldata uri
    ) internal returns (uint256 id) {
        AVADataTypes.EvidenceReceipt memory receipt = evidenceRegistry.getEvidenceReceipt(context.evidenceReceiptId);
        receipt = evidenceRegistry.requireUsableEvidenceReceipt(
            context.evidenceReceiptId, receipt.appId, context.workflowKey
        );
        if (context.objectId != bytes32(receipt.id)) revert AVADataTypes.InvalidState(receipt.id);
        return _recordAttestationWithPackage(context, receipt.packageId, attestationType, uri);
    }

    function _recordAttestationWithPackage(
        AttestationContext memory context,
        uint256 packageId,
        string calldata attestationType,
        string calldata uri
    ) internal returns (uint256 id) {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, context.actingRole, AVADataTypes.Action.RecordAttestation, context.authorityId
        );
        if (
            context.workflowKey == bytes32(0) || context.objectId == bytes32(0) || context.evidenceReceiptId == 0
                || context.attestationHash == bytes32(0) || context.authorityId == bytes32(0)
                || context.targetKind == AVADataTypes.AttestationTargetKind.None || bytes(attestationType).length == 0
        ) {
            revert AVADataTypes.EmptyValue();
        }
        AVARulePackageRegistry.RulePackage memory rulePackage = rulePackageRegistry.getRulePackageById(packageId);
        if (rulePackage.workflowKey != context.workflowKey) revert AVADataTypes.InvalidState(packageId);
        AVADataTypes.EvidenceReceipt memory evidence = evidenceRegistry.requireUsableEvidenceReceipt(
            context.evidenceReceiptId, rulePackage.appId, context.workflowKey
        );
        if (evidence.packageId != packageId) revert AVADataTypes.InvalidState(context.evidenceReceiptId);
        rulePackage.evidenceLifecycleModule
            .validateEvidenceLifecycle(
                context.workflowKey,
                AVADataTypes.Action.RecordAttestation,
                context.evidenceReceiptId,
                AVADataTypes.EvidenceLifecycleKind.None,
                0,
                bytes32(0),
                msg.sender
            );
        rulePackage.auditAdapter
            .validateAuditRecord(
                context.workflowKey,
                context.actingRole,
                context.action,
                context.objectId,
                context.evidenceReceiptId,
                context.attestationHash,
                msg.sender
            );

        id = nextAttestationId++;
        attestations[id] = AVADataTypes.AttestationRecord({
            id: id,
            workflowKey: context.workflowKey,
            packageId: packageId,
            targetKind: context.targetKind,
            action: context.action,
            objectId: context.objectId,
            evidenceReceiptId: context.evidenceReceiptId,
            attestationHash: context.attestationHash,
            authorityRole: context.actingRole,
            authorityId: context.authorityId,
            attestationType: attestationType,
            uri: uri,
            recordedBy: msg.sender
        });

        emit AttestationRecorded(
            id, context.objectId, context.targetKind, context.action, attestationType, uri, msg.sender
        );
    }

    function _challengeTransitionAction(AVADataTypes.ChallengeTransitionKind transitionKind)
        internal
        pure
        returns (AVADataTypes.Action)
    {
        if (transitionKind == AVADataTypes.ChallengeTransitionKind.AdmissibilityScreened) {
            return AVADataTypes.Action.ScreenChallenge;
        }
        if (transitionKind == AVADataTypes.ChallengeTransitionKind.OutcomeResolved) {
            return AVADataTypes.Action.ResolveChallenge;
        }
        if (transitionKind == AVADataTypes.ChallengeTransitionKind.RestorationRecorded) {
            return AVADataTypes.Action.ApplyRestoration;
        }
        if (transitionKind == AVADataTypes.ChallengeTransitionKind.Closed) {
            return AVADataTypes.Action.CloseChallenge;
        }
        revert AVADataTypes.InvalidState(uint256(transitionKind));
    }

    function getAttestation(uint256 id) external view returns (AVADataTypes.AttestationRecord memory) {
        AVADataTypes.AttestationRecord memory attestation = attestations[id];
        if (attestation.id == 0) revert AVADataTypes.UnknownReference(id);
        return attestation;
    }
}
