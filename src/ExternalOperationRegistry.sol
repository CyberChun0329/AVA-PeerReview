// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "./AVADataTypes.sol";
import {AuthorityMatrix} from "./AuthorityMatrix.sol";
import {AVAStateMachine} from "./AVAStateMachine.sol";
import {EvidenceCommitmentRegistry} from "./EvidenceCommitmentRegistry.sol";
import {AllocationExecutor} from "./AllocationExecutor.sol";
import {ConsequenceExecutor} from "./ConsequenceExecutor.sol";
import {IExternalOperationRegistry} from "./interfaces/IExternalOperationRegistry.sol";

contract ExternalOperationRegistry is IExternalOperationRegistry {
    bytes32 public constant EXTERNAL_OPERATION_CONTEXT_DOMAIN = keccak256("AVA_EXTERNAL_OPERATION_CONTEXT_V1");

    AuthorityMatrix public immutable authorityMatrix;
    AVAStateMachine public immutable stateMachine;
    EvidenceCommitmentRegistry public immutable evidenceRegistry;
    AllocationExecutor public immutable allocationExecutor;
    ConsequenceExecutor public immutable consequenceExecutor;
    uint256 public nextExternalOperationId = 1;

    mapping(uint256 => AVADataTypes.ExternalOperationRecord) private externalOperations;
    mapping(uint256 => uint256) public terminalReceiptIdByOperation;

    event ExternalOperationRecorded(
        uint256 indexed id,
        bytes32 indexed workflowKey,
        AVADataTypes.ExternalOperationKind indexed kind,
        AVADataTypes.ExternalOperationTargetKind targetKind,
        uint256 targetId,
        AVADataTypes.ExternalOperationStatus status
    );

    constructor(
        AuthorityMatrix authorityMatrix_,
        AVAStateMachine stateMachine_,
        EvidenceCommitmentRegistry evidenceRegistry_,
        AllocationExecutor allocationExecutor_,
        ConsequenceExecutor consequenceExecutor_
    ) {
        authorityMatrix = authorityMatrix_;
        stateMachine = stateMachine_;
        evidenceRegistry = evidenceRegistry_;
        allocationExecutor = allocationExecutor_;
        consequenceExecutor = consequenceExecutor_;
    }

    function requestOperation(
        AVADataTypes.Role actingRole,
        bytes32 workflowKey,
        AVADataTypes.ExternalOperationKind kind,
        AVADataTypes.ExternalOperationTargetKind targetKind,
        uint256 targetId,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata referenceURI
    ) external returns (uint256 id) {
        return _recordOperation(
            actingRole,
            workflowKey,
            kind,
            AVADataTypes.ExternalOperationStatus.Requested,
            0,
            targetKind,
            targetId,
            evidenceReceiptId,
            authorityId,
            referenceURI
        );
    }

    function acknowledgeOperation(
        AVADataTypes.Role actingRole,
        uint256 operationId,
        bytes32 authorityId,
        string calldata referenceURI
    ) external returns (uint256 id) {
        return _recordStatusChange(
            actingRole, operationId, AVADataTypes.ExternalOperationStatus.Acknowledged, authorityId, referenceURI
        );
    }

    function cancelOperation(
        AVADataTypes.Role actingRole,
        uint256 operationId,
        bytes32 authorityId,
        string calldata referenceURI
    ) external returns (uint256 id) {
        return _recordStatusChange(
            actingRole, operationId, AVADataTypes.ExternalOperationStatus.Cancelled, authorityId, referenceURI
        );
    }

    function supersedeOperation(
        AVADataTypes.Role actingRole,
        uint256 operationId,
        bytes32 authorityId,
        string calldata referenceURI
    ) external returns (uint256 id) {
        return _recordStatusChange(
            actingRole, operationId, AVADataTypes.ExternalOperationStatus.Superseded, authorityId, referenceURI
        );
    }

    function getExternalOperation(uint256 id) external view returns (AVADataTypes.ExternalOperationRecord memory) {
        AVADataTypes.ExternalOperationRecord memory operation = externalOperations[id];
        if (operation.id == 0) revert AVADataTypes.UnknownReference(id);
        return operation;
    }

    function computeOperationContextHash(
        bytes32 workflowKey,
        uint256 packageId,
        AVADataTypes.ExternalOperationKind kind,
        AVADataTypes.ExternalOperationTargetKind targetKind,
        uint256 targetId,
        uint256 evidenceReceiptId
    ) public pure returns (bytes32) {
        if (
            workflowKey == bytes32(0) || packageId == 0 || kind == AVADataTypes.ExternalOperationKind.None
                || targetKind == AVADataTypes.ExternalOperationTargetKind.None || targetId == 0 || evidenceReceiptId == 0
        ) {
            return bytes32(0);
        }
        return keccak256(
            abi.encode(
                EXTERNAL_OPERATION_CONTEXT_DOMAIN, workflowKey, packageId, kind, targetKind, targetId, evidenceReceiptId
            )
        );
    }

    function _recordStatusChange(
        AVADataTypes.Role actingRole,
        uint256 operationId,
        AVADataTypes.ExternalOperationStatus status,
        bytes32 authorityId,
        string calldata referenceURI
    ) internal returns (uint256 id) {
        AVADataTypes.ExternalOperationRecord memory operation = externalOperations[operationId];
        if (operation.id == 0) revert AVADataTypes.UnknownReference(operationId);
        if (operation.status != AVADataTypes.ExternalOperationStatus.Requested) {
            revert AVADataTypes.InvalidState(operationId);
        }
        if (terminalReceiptIdByOperation[operationId] != 0) {
            revert AVADataTypes.InvalidState(operationId);
        }
        id = _recordOperation(
            actingRole,
            operation.workflowKey,
            operation.kind,
            status,
            operationId,
            operation.targetKind,
            operation.targetId,
            operation.evidenceReceiptId,
            authorityId,
            referenceURI
        );
        terminalReceiptIdByOperation[operationId] = id;
    }

    function _recordOperation(
        AVADataTypes.Role actingRole,
        bytes32 workflowKey,
        AVADataTypes.ExternalOperationKind kind,
        AVADataTypes.ExternalOperationStatus status,
        uint256 sourceOperationId,
        AVADataTypes.ExternalOperationTargetKind targetKind,
        uint256 targetId,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata referenceURI
    ) internal returns (uint256 id) {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.RecordExternalOperation, authorityId
        );
        if (
            workflowKey == bytes32(0) || kind == AVADataTypes.ExternalOperationKind.None
                || status == AVADataTypes.ExternalOperationStatus.None
                || targetKind == AVADataTypes.ExternalOperationTargetKind.None || targetId == 0 || evidenceReceiptId == 0
                || authorityId == bytes32(0) || bytes(referenceURI).length == 0
        ) {
            revert AVADataTypes.EmptyValue();
        }

        uint256 packageId = _requireTarget(workflowKey, targetKind, targetId);
        _requireEvidenceForPackage(evidenceReceiptId, workflowKey, packageId);
        bytes32 operationContextHash =
            computeOperationContextHash(workflowKey, packageId, kind, targetKind, targetId, evidenceReceiptId);
        if (operationContextHash == bytes32(0)) revert AVADataTypes.EmptyValue();

        id = nextExternalOperationId++;
        externalOperations[id] = AVADataTypes.ExternalOperationRecord({
            id: id,
            sourceOperationId: sourceOperationId,
            workflowKey: workflowKey,
            packageId: packageId,
            kind: kind,
            status: status,
            targetKind: targetKind,
            targetId: targetId,
            evidenceReceiptId: evidenceReceiptId,
            operationContextHash: operationContextHash,
            authorityRole: actingRole,
            authorityId: authorityId,
            referenceURI: referenceURI,
            recordedBy: msg.sender
        });
        _emitExternalOperationRecorded(id);
    }

    function _requireTarget(
        bytes32 workflowKey,
        AVADataTypes.ExternalOperationTargetKind targetKind,
        uint256 targetId
    ) internal view returns (uint256 packageId) {
        if (targetKind == AVADataTypes.ExternalOperationTargetKind.RecognisedState) {
            AVADataTypes.RecognisedStateRecord memory state = stateMachine.getRecognisedState(targetId);
            if (state.workflowKey != workflowKey) revert AVADataTypes.InvalidState(targetId);
            packageId = state.packageId;
        } else if (targetKind == AVADataTypes.ExternalOperationTargetKind.Challenge) {
            AVADataTypes.ChallengeRecord memory challenge = stateMachine.getChallenge(targetId);
            if (challenge.workflowKey != workflowKey) revert AVADataTypes.InvalidState(targetId);
            packageId = challenge.packageId;
        } else if (targetKind == AVADataTypes.ExternalOperationTargetKind.EvidenceReceipt) {
            AVADataTypes.EvidenceReceipt memory evidence = evidenceRegistry.getEvidenceReceipt(targetId);
            if (evidence.workflowKey != workflowKey) revert AVADataTypes.InvalidState(targetId);
            packageId = evidence.packageId;
        } else if (targetKind == AVADataTypes.ExternalOperationTargetKind.AllocationRecord) {
            AVADataTypes.AllocationExecutionRecord memory allocation =
                allocationExecutor.getAllocationExecution(targetId);
            AVADataTypes.RecognisedStateRecord memory state = stateMachine.getRecognisedState(allocation.recognisedStateId);
            if (state.workflowKey != workflowKey) revert AVADataTypes.InvalidState(targetId);
            packageId = allocation.packageId;
        } else if (targetKind == AVADataTypes.ExternalOperationTargetKind.ConsequenceRecord) {
            AVADataTypes.ConsequenceRecord memory consequence = consequenceExecutor.getConsequence(targetId);
            AVADataTypes.RecognisedStateRecord memory state = stateMachine.getRecognisedState(consequence.recognisedStateId);
            if (state.workflowKey != workflowKey) revert AVADataTypes.InvalidState(targetId);
            packageId = consequence.packageId;
        } else {
            revert AVADataTypes.InvalidState(uint256(targetKind));
        }
        if (packageId == 0) revert AVADataTypes.InvalidState(targetId);
    }

    function _requireEvidenceForPackage(uint256 evidenceReceiptId, bytes32 workflowKey, uint256 packageId) internal view {
        AVADataTypes.EvidenceReceipt memory evidence =
            evidenceRegistry.requireUsableEvidenceReceipt(evidenceReceiptId, workflowKey);
        if (evidence.packageId != packageId) revert AVADataTypes.InvalidState(evidenceReceiptId);
    }

    function _emitExternalOperationRecorded(uint256 id) internal {
        AVADataTypes.ExternalOperationRecord memory operation = externalOperations[id];
        emit ExternalOperationRecorded(
            id, operation.workflowKey, operation.kind, operation.targetKind, operation.targetId, operation.status
        );
    }
}
