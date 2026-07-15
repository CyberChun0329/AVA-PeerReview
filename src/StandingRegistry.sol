// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "./AVADataTypes.sol";
import {AuthorityMatrix} from "./AuthorityMatrix.sol";
import {AVAStateMachine} from "./AVAStateMachine.sol";
import {AVARulePackageRegistry} from "./AVARulePackageRegistry.sol";
import {EvidenceCommitmentRegistry} from "./EvidenceCommitmentRegistry.sol";
import {StandingRevisionRegistry} from "./StandingRevisionRegistry.sol";

contract StandingRegistry {
    AuthorityMatrix public immutable authorityMatrix;
    AVAStateMachine public immutable stateMachine;
    AVARulePackageRegistry public immutable rulePackageRegistry;
    EvidenceCommitmentRegistry public immutable evidenceRegistry;
    StandingRevisionRegistry public immutable standingRevisionRegistry;
    uint256 public nextStandingUpdateId = 1;
    uint256 public nextStandingComputationRecordId = 1;

    mapping(uint256 => AVADataTypes.StandingUpdateRecord) private standingUpdates;
    mapping(uint256 => AVADataTypes.StandingComputationRecord) private standingComputationRecords;
    mapping(bytes32 => uint256) private standingUpdateIdByInputHash;

    event StandingUpdateRecorded(
        uint256 indexed id, uint256 indexed recognisedStateId, bytes32 indexed subjectId, string dimension, int256 delta
    );
    event StandingComputationRecorded(
        uint256 indexed id, uint256 indexed recognisedStateId, bytes32 indexed subjectId, bytes32 vectorKey
    );
    event StandingComputationSuperseded(uint256 indexed id, uint256 indexed supersededBy, bytes32 authorityId);
    event StandingComputationInvalidated(uint256 indexed id, uint256 indexed evidenceReceiptId, bytes32 authorityId);

    constructor(
        AuthorityMatrix authorityMatrix_,
        AVAStateMachine stateMachine_,
        AVARulePackageRegistry rulePackageRegistry_,
        EvidenceCommitmentRegistry evidenceRegistry_,
        StandingRevisionRegistry standingRevisionRegistry_
    ) {
        if (address(standingRevisionRegistry_) == address(0)) {
            revert AVADataTypes.EmptyValue();
        }
        authorityMatrix = authorityMatrix_;
        stateMachine = stateMachine_;
        rulePackageRegistry = rulePackageRegistry_;
        evidenceRegistry = evidenceRegistry_;
        standingRevisionRegistry = standingRevisionRegistry_;
    }

    function recordStandingUpdate(
        AVADataTypes.Role actingRole,
        uint256 recognisedStateId,
        bytes32 subjectId,
        string calldata dimension,
        int256 delta,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.RecordStandingUpdate, authorityId
        );
        AVADataTypes.RecognisedStateRecord memory recognisedState = _requireAllowedRecognisedState(recognisedStateId);
        if (
            subjectId == bytes32(0) || bytes(dimension).length == 0 || evidenceReceiptId == 0
                || authorityId == bytes32(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
        authorityMatrix.requireKnownActiveSubject(subjectId);
        _requireRecognisedStateSubject(recognisedState, subjectId);
        _validateStandingUpdateModules(
            actingRole, recognisedState, subjectId, dimension, delta, evidenceReceiptId, authorityId, uri
        );
        id = nextStandingUpdateId++;
        AVADataTypes.StandingUpdateRecord storage standingUpdate = standingUpdates[id];
        standingUpdate.id = id;
        standingUpdate.recognisedStateId = recognisedStateId;
        standingUpdate.packageId = recognisedState.packageId;
        standingUpdate.subjectId = subjectId;
        standingUpdate.dimension = dimension;
        standingUpdate.delta = delta;
        standingUpdate.evidenceReceiptId = evidenceReceiptId;
        standingUpdate.authorityRole = actingRole;
        standingUpdate.authorityId = authorityId;
        standingUpdate.uri = uri;
        standingUpdate.recordedBy = msg.sender;
        bytes32 inputHash = _standingUpdateInputHash(standingUpdate);
        if (standingUpdateIdByInputHash[inputHash] != 0) {
            revert AVADataTypes.InvalidState(standingUpdateIdByInputHash[inputHash]);
        }
        standingUpdateIdByInputHash[inputHash] = id;
        standingRevisionRegistry.advanceRevision(
            recognisedState.packageId, subjectId, AVADataTypes.StandingRevisionReason.StandingUpdate, id
        );

        emit StandingUpdateRecorded(id, recognisedStateId, subjectId, dimension, delta);
    }

    function getStandingUpdate(uint256 id) external view returns (AVADataTypes.StandingUpdateRecord memory) {
        AVADataTypes.StandingUpdateRecord memory standingUpdate = standingUpdates[id];
        if (standingUpdate.id == 0) revert AVADataTypes.UnknownReference(id);
        return standingUpdate;
    }

    function recordStandingComputationReadiness(
        AVADataTypes.Role actingRole,
        AVADataTypes.StandingComputationContext calldata context,
        string calldata uri
    ) external returns (uint256 id) {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.RecordStandingUpdate, context.authorityId
        );
        id = _recordStandingComputationReadiness(actingRole, context, uri);
    }

    function _recordStandingComputationReadiness(
        AVADataTypes.Role actingRole,
        AVADataTypes.StandingComputationContext calldata context,
        string calldata uri
    ) internal returns (uint256 id) {
        AVADataTypes.RecognisedStateRecord memory recognisedState =
            _requireAllowedRecognisedState(context.recognisedStateId);
        if (
            context.subjectId == bytes32(0) || bytes(context.dimension).length == 0 || context.vectorKey == bytes32(0)
                || context.fieldKey == bytes32(0) || context.evidenceReceiptId == 0 || context.epoch == 0
                || context.sourceRecordSetHash == bytes32(0) || context.computationRuleHash == bytes32(0)
                || context.authorityId == bytes32(0) || context.actor != msg.sender
        ) {
            revert AVADataTypes.EmptyValue();
        }
        authorityMatrix.requireKnownActiveSubject(context.subjectId);
        _requireRecognisedStateSubject(recognisedState, context.subjectId);
        _requireUsableEvidenceForRecognisedState(context.evidenceReceiptId, recognisedState);
        AVARulePackageRegistry.RulePackage memory rulePackage =
            rulePackageRegistry.getRulePackageById(recognisedState.packageId);
        _validateEvidenceLifecycle(rulePackage, recognisedState.evidenceReceiptId);
        if (context.evidenceReceiptId != recognisedState.evidenceReceiptId) {
            _validateEvidenceLifecycle(rulePackage, context.evidenceReceiptId);
        }
        _validateAntiAbuse(
            rulePackage, recognisedState.workflowKey, actingRole, context.subjectId, context.recognisedStateId
        );
        rulePackage.standingComputationModule.validateStandingComputation(context);
        uint256 standingRevision =
            standingRevisionRegistry.currentRevision(recognisedState.packageId, context.subjectId);

        id = nextStandingComputationRecordId++;
        standingComputationRecords[id] = AVADataTypes.StandingComputationRecord({
            id: id,
            recognisedStateId: context.recognisedStateId,
            packageId: recognisedState.packageId,
            standingRevision: standingRevision,
            subjectId: context.subjectId,
            dimension: context.dimension,
            vectorKey: context.vectorKey,
            currentValue: context.currentValue,
            delta: context.delta,
            effectiveAt: context.effectiveAt,
            epoch: context.epoch,
            sourceRecordSetHash: context.sourceRecordSetHash,
            computationRuleHash: context.computationRuleHash,
            reversible: context.reversible,
            fieldKey: context.fieldKey,
            evidenceReceiptId: context.evidenceReceiptId,
            authorityId: context.authorityId,
            status: AVADataTypes.StandingComputationStatus.Active,
            supersededBy: 0,
            invalidatedByEvidenceReceiptId: 0,
            uri: uri,
            recordedBy: msg.sender
        });

        emit StandingComputationRecorded(id, context.recognisedStateId, context.subjectId, context.vectorKey);
    }

    function supersedeStandingComputationReadiness(
        AVADataTypes.Role actingRole,
        uint256 oldComputationId,
        AVADataTypes.StandingComputationContext calldata context,
        string calldata uri
    ) external returns (uint256 id) {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.RecordStandingUpdate, context.authorityId
        );
        AVADataTypes.StandingComputationRecord storage oldComputation = standingComputationRecords[oldComputationId];
        if (oldComputation.id == 0) revert AVADataTypes.UnknownReference(oldComputationId);
        if (oldComputation.status != AVADataTypes.StandingComputationStatus.Active) {
            revert AVADataTypes.InvalidState(oldComputationId);
        }
        id = _recordStandingComputationReadiness(actingRole, context, uri);
        AVADataTypes.StandingComputationRecord memory newComputation = standingComputationRecords[id];
        if (
            newComputation.packageId != oldComputation.packageId || newComputation.subjectId != oldComputation.subjectId
                || newComputation.vectorKey != oldComputation.vectorKey
                || keccak256(bytes(newComputation.dimension)) != keccak256(bytes(oldComputation.dimension))
                || newComputation.epoch <= oldComputation.epoch
        ) {
            revert AVADataTypes.InvalidState(oldComputationId);
        }
        oldComputation.status = AVADataTypes.StandingComputationStatus.Superseded;
        oldComputation.supersededBy = id;
        emit StandingComputationSuperseded(oldComputationId, id, context.authorityId);
    }

    function invalidateStandingComputation(
        AVADataTypes.Role actingRole,
        uint256 computationId,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.RecordStandingUpdate, authorityId
        );
        AVADataTypes.StandingComputationRecord storage computation = standingComputationRecords[computationId];
        if (computation.id == 0) revert AVADataTypes.UnknownReference(computationId);
        if (
            computation.status != AVADataTypes.StandingComputationStatus.Active || evidenceReceiptId == 0
                || authorityId == bytes32(0) || bytes(uri).length == 0
        ) {
            revert AVADataTypes.InvalidState(computationId);
        }
        AVADataTypes.RecognisedStateRecord memory recognisedState =
            stateMachine.getRecognisedState(computation.recognisedStateId);
        _requireUsableEvidenceForRecognisedState(evidenceReceiptId, recognisedState);
        computation.status = AVADataTypes.StandingComputationStatus.Invalidated;
        computation.invalidatedByEvidenceReceiptId = evidenceReceiptId;
        emit StandingComputationInvalidated(computationId, evidenceReceiptId, authorityId);
        return computationId;
    }

    function isStandingComputationActive(uint256 computationId) external view returns (bool) {
        AVADataTypes.StandingComputationRecord memory record = standingComputationRecords[computationId];
        if (
            record.id == 0 || record.status != AVADataTypes.StandingComputationStatus.Active
                || record.standingRevision
                    != standingRevisionRegistry.currentRevision(record.packageId, record.subjectId)
                || !authorityMatrix.roleRegistry().isKnownActiveSubject(record.subjectId)
        ) {
            return false;
        }
        try stateMachine.getRecognisedState(record.recognisedStateId) returns (
            AVADataTypes.RecognisedStateRecord memory recognisedState
        ) {
            if (recognisedState.packageId != record.packageId || recognisedState.subjectId != record.subjectId) {
                return false;
            }
            try rulePackageRegistry.getRulePackageById(record.packageId) returns (
                AVARulePackageRegistry.RulePackage memory rulePackage
            ) {
                if (rulePackage.workflowKey != recognisedState.workflowKey) return false;
            } catch {
                return false;
            }
            try evidenceRegistry.requireUsableEvidenceReceipt(
                recognisedState.evidenceReceiptId, recognisedState.appId, recognisedState.workflowKey
            ) returns (
                AVADataTypes.EvidenceReceipt memory stateReceipt
            ) {
                if (stateReceipt.packageId != record.packageId) return false;
            } catch {
                return false;
            }
            try evidenceRegistry.requireUsableEvidenceReceipt(
                record.evidenceReceiptId, recognisedState.appId, recognisedState.workflowKey
            ) returns (
                AVADataTypes.EvidenceReceipt memory receipt
            ) {
                return receipt.packageId == record.packageId;
            } catch {
                return false;
            }
        } catch {
            return false;
        }
    }

    function getStandingComputationRecord(uint256 id)
        external
        view
        returns (AVADataTypes.StandingComputationRecord memory)
    {
        AVADataTypes.StandingComputationRecord memory record = standingComputationRecords[id];
        if (record.id == 0) revert AVADataTypes.UnknownReference(id);
        return record;
    }

    function _requireAllowedRecognisedState(uint256 recognisedStateId)
        internal
        view
        returns (AVADataTypes.RecognisedStateRecord memory recognisedState)
    {
        recognisedState = stateMachine.getRecognisedState(recognisedStateId);
        AVADataTypes.RecognisedStateStatus status = recognisedState.status;
        if (
            status != AVADataTypes.RecognisedStateStatus.Vested && status != AVADataTypes.RecognisedStateStatus.Restored
                && status != AVADataTypes.RecognisedStateStatus.Downgraded
                && status != AVADataTypes.RecognisedStateStatus.Voided
        ) {
            revert AVADataTypes.InvalidState(recognisedStateId);
        }
        _requireUsableEvidenceForRecognisedState(recognisedState.evidenceReceiptId, recognisedState);
    }

    function _validateAntiAbuse(
        AVARulePackageRegistry.RulePackage memory rulePackage,
        bytes32 workflowKey,
        AVADataTypes.Role actingRole,
        bytes32 subjectId,
        uint256 recognisedStateId
    ) internal view {
        rulePackage.antiAbuseModule
            .validateUse(
                workflowKey,
                actingRole,
                AVADataTypes.Action.RecordStandingUpdate,
                subjectId,
                bytes32(recognisedStateId),
                msg.sender
            );
    }

    function _requireRecognisedStateSubject(
        AVADataTypes.RecognisedStateRecord memory recognisedState,
        bytes32 subjectId
    ) internal pure {
        if (recognisedState.subjectId != subjectId) {
            revert AVADataTypes.InvalidState(recognisedState.id);
        }
    }

    function _validateStandingUpdateModules(
        AVADataTypes.Role actingRole,
        AVADataTypes.RecognisedStateRecord memory recognisedState,
        bytes32 subjectId,
        string calldata dimension,
        int256 delta,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri
    ) internal view {
        _requireUsableEvidenceForRecognisedState(evidenceReceiptId, recognisedState);
        AVARulePackageRegistry.RulePackage memory rulePackage =
            rulePackageRegistry.getRulePackageById(recognisedState.packageId);
        _validateEvidenceLifecycle(rulePackage, recognisedState.evidenceReceiptId);
        if (evidenceReceiptId != recognisedState.evidenceReceiptId) {
            _validateEvidenceLifecycle(rulePackage, evidenceReceiptId);
        }
        _validateAntiAbuse(rulePackage, recognisedState.workflowKey, actingRole, subjectId, recognisedState.id);
        rulePackage.standingAdapter
            .validateStandingUpdate(
                actingRole,
                recognisedState.id,
                subjectId,
                dimension,
                delta,
                evidenceReceiptId,
                authorityId,
                uri,
                msg.sender
            );
    }

    function _requireUsableEvidenceForRecognisedState(
        uint256 evidenceReceiptId,
        AVADataTypes.RecognisedStateRecord memory recognisedState
    ) internal view {
        AVADataTypes.EvidenceReceipt memory receipt =
            evidenceRegistry.requireUsableEvidenceReceipt(
                evidenceReceiptId, recognisedState.appId, recognisedState.workflowKey
            );
        if (receipt.packageId != recognisedState.packageId) revert AVADataTypes.InvalidState(evidenceReceiptId);
    }

    function _validateEvidenceLifecycle(
        AVARulePackageRegistry.RulePackage memory rulePackage,
        uint256 evidenceReceiptId
    ) internal view {
        rulePackage.evidenceLifecycleModule
            .validateEvidenceLifecycle(
                rulePackage.workflowKey,
                AVADataTypes.Action.RecordStandingUpdate,
                evidenceReceiptId,
                AVADataTypes.EvidenceLifecycleKind.None,
                0,
                bytes32(0),
                msg.sender
            );
    }

    function _standingUpdateInputHash(AVADataTypes.StandingUpdateRecord storage standingUpdate)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                standingUpdate.packageId,
                standingUpdate.recognisedStateId,
                standingUpdate.subjectId,
                keccak256(bytes(standingUpdate.dimension))
            )
        );
    }
}
