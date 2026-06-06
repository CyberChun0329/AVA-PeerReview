// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "./AVADataTypes.sol";
import {AuthorityMatrix} from "./AuthorityMatrix.sol";
import {AVARulePackageRegistry} from "./AVARulePackageRegistry.sol";
import {EvidenceCommitmentRegistry} from "./EvidenceCommitmentRegistry.sol";
import {AVAStateMachine} from "./AVAStateMachine.sol";

contract AttestationAuditModule {
    AuthorityMatrix public immutable authorityMatrix;
    AVARulePackageRegistry public immutable rulePackageRegistry;
    EvidenceCommitmentRegistry public immutable evidenceRegistry;
    AVAStateMachine public immutable stateMachine;
    uint256 public nextAttestationId = 1;

    mapping(uint256 => AVADataTypes.AttestationRecord) private attestations;

    struct AttestationContext {
        AVADataTypes.Role actingRole;
        bytes32 workflowKey;
        AVADataTypes.Action action;
        bytes32 objectId;
        uint256 evidenceReceiptId;
        bytes32 attestationHash;
        bytes32 authorityId;
    }

    event AttestationRecorded(
        uint256 indexed id, bytes32 indexed objectId, string attestationType, string uri, address indexed recordedBy
    );

    constructor(
        AuthorityMatrix authorityMatrix_,
        AVARulePackageRegistry rulePackageRegistry_,
        EvidenceCommitmentRegistry evidenceRegistry_,
        AVAStateMachine stateMachine_
    ) {
        authorityMatrix = authorityMatrix_;
        rulePackageRegistry = rulePackageRegistry_;
        evidenceRegistry = evidenceRegistry_;
        stateMachine = stateMachine_;
    }

    function recordAttestation(
        AVADataTypes.Role actingRole,
        bytes32 objectId,
        string calldata attestationType,
        string calldata uri
    ) external pure returns (uint256) {
        (actingRole, objectId, attestationType, uri);
        revert AVADataTypes.InvalidState(0);
    }

    function recordAttestation(
        AVADataTypes.Role actingRole,
        bytes32 workflowKey,
        AVADataTypes.Action action,
        bytes32 objectId,
        uint256 evidenceReceiptId,
        bytes32 attestationHash,
        string calldata attestationType,
        string calldata uri
    ) external pure returns (uint256) {
        (actingRole, workflowKey, action, objectId, evidenceReceiptId, attestationHash, attestationType, uri);
        revert AVADataTypes.InvalidState(0);
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
        AVADataTypes.RecognisedStateRecord memory recognisedState =
            stateMachine.getRecognisedState(transition.recognisedStateId);
        return _recordAttestationWithPackage(
            AttestationContext({
                actingRole: actingRole,
                workflowKey: recognisedState.workflowKey,
                action: transition.action,
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

    function recordChallengeTransitionAttestation(
        AVADataTypes.Role actingRole,
        uint256 transitionId,
        bytes32 attestationHash,
        bytes32 authorityId,
        string calldata attestationType,
        string calldata uri
    ) external returns (uint256 id) {
        AVADataTypes.ChallengeTransitionRecord memory transition = stateMachine.getChallengeTransition(transitionId);
        return _recordAttestationWithPackage(
            AttestationContext({
                actingRole: actingRole,
                workflowKey: transition.workflowKey,
                action: AVADataTypes.Action.RecordAttestation,
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
        AVADataTypes.EvidenceReceipt memory receipt =
            evidenceRegistry.requireUsableEvidenceReceipt(context.evidenceReceiptId, context.workflowKey);
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
                || bytes(attestationType).length == 0
        ) {
            revert AVADataTypes.EmptyValue();
        }
        AVADataTypes.EvidenceReceipt memory evidence =
            evidenceRegistry.requireUsableEvidenceReceipt(context.evidenceReceiptId, context.workflowKey);
        if (evidence.packageId != packageId) revert AVADataTypes.InvalidState(context.evidenceReceiptId);
        AVARulePackageRegistry.RulePackage memory rulePackage = rulePackageRegistry.getRulePackageById(packageId);
        if (rulePackage.workflowKey != context.workflowKey) revert AVADataTypes.InvalidState(packageId);
        rulePackage.auditAdapter.validateAuditRecord(
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
            objectId: context.objectId,
            evidenceReceiptId: context.evidenceReceiptId,
            attestationHash: context.attestationHash,
            authorityRole: context.actingRole,
            authorityId: context.authorityId,
            attestationType: attestationType,
            uri: uri,
            recordedBy: msg.sender
        });

        emit AttestationRecorded(id, context.objectId, attestationType, uri, msg.sender);
    }

    function getAttestation(uint256 id) external view returns (AVADataTypes.AttestationRecord memory) {
        AVADataTypes.AttestationRecord memory attestation = attestations[id];
        if (attestation.id == 0) revert AVADataTypes.UnknownReference(id);
        return attestation;
    }
}
