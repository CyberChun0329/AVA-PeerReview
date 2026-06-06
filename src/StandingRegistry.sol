// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "./AVADataTypes.sol";
import {AuthorityMatrix} from "./AuthorityMatrix.sol";
import {AVAStateMachine} from "./AVAStateMachine.sol";
import {AVARulePackageRegistry} from "./AVARulePackageRegistry.sol";
import {EvidenceCommitmentRegistry} from "./EvidenceCommitmentRegistry.sol";

contract StandingRegistry {
    AuthorityMatrix public immutable authorityMatrix;
    AVAStateMachine public immutable stateMachine;
    AVARulePackageRegistry public immutable rulePackageRegistry;
    EvidenceCommitmentRegistry public immutable evidenceRegistry;
    uint256 public nextStandingInputId = 1;
    uint256 public nextStandingUpdateId = 1;
    uint256 public nextStandingComputationRecordId = 1;

    mapping(uint256 => AVADataTypes.StandingInputRecord) private standingInputs;
    mapping(uint256 => AVADataTypes.StandingUpdateRecord) private standingUpdates;
    mapping(uint256 => AVADataTypes.StandingComputationRecord) private standingComputationRecords;

    event StandingInputRegistered(
        uint256 indexed id,
        uint256 indexed recognisedStateId,
        bytes32 indexed subjectId,
        string dimension,
        string uri,
        address registeredBy
    );

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
        EvidenceCommitmentRegistry evidenceRegistry_
    ) {
        authorityMatrix = authorityMatrix_;
        stateMachine = stateMachine_;
        rulePackageRegistry = rulePackageRegistry_;
        evidenceRegistry = evidenceRegistry_;
    }

    function registerStandingInput(
        AVADataTypes.Role actingRole,
        uint256 recognisedStateId,
        bytes32 subjectId,
        string calldata dimension,
        string calldata uri
    ) external view returns (uint256) {
        authorityMatrix.requireAuthorised(msg.sender, actingRole, AVADataTypes.Action.RegisterStandingInput);
        (recognisedStateId, subjectId, dimension, uri);
        revert AVADataTypes.InvalidState(recognisedStateId);
    }

    function getStandingInput(uint256 id) external view returns (AVADataTypes.StandingInputRecord memory) {
        AVADataTypes.StandingInputRecord memory standingInput = standingInputs[id];
        if (standingInput.id == 0) revert AVADataTypes.UnknownReference(id);
        return standingInput;
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
        AVADataTypes.StandingComputationContext memory context = AVADataTypes.StandingComputationContext({
            recognisedStateId: recognisedStateId,
            subjectId: subjectId,
            dimension: dimension,
            vectorKey: keccak256(bytes(dimension)),
            currentValue: 0,
            delta: delta,
            effectiveAt: 0,
            epoch: 1,
            sourceRecordSetHash: keccak256(abi.encode(recognisedStateId, subjectId, dimension, delta, evidenceReceiptId)),
            computationRuleHash: keccak256("ava-standing-update-record-rule-v1"),
            reversible: true,
            fieldKey: bytes32(uint256(recognisedState.stage)),
            evidenceReceiptId: evidenceReceiptId,
            authorityId: authorityId,
            actor: msg.sender
        });
        _validateStandingUpdateModules(actingRole, recognisedState, context, uri);

        id = nextStandingUpdateId++;
        standingUpdates[id] = AVADataTypes.StandingUpdateRecord({
            id: id,
            recognisedStateId: recognisedStateId,
            packageId: recognisedState.packageId,
            subjectId: context.subjectId,
            dimension: context.dimension,
            delta: context.delta,
            evidenceReceiptId: context.evidenceReceiptId,
            authorityRole: actingRole,
            authorityId: context.authorityId,
            uri: uri,
            recordedBy: msg.sender
        });

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
        _requireUsableEvidenceForRecognisedState(context.evidenceReceiptId, recognisedState);
        AVARulePackageRegistry.RulePackage memory rulePackage =
            rulePackageRegistry.getRulePackageById(recognisedState.packageId);
        _validateAntiAbuse(
            rulePackage, recognisedState.workflowKey, actingRole, context.subjectId, context.recognisedStateId
        );
        rulePackage.standingComputationModule.validateStandingComputation(context);

        id = nextStandingComputationRecordId++;
        standingComputationRecords[id] = AVADataTypes.StandingComputationRecord({
            id: id,
            recognisedStateId: context.recognisedStateId,
            packageId: recognisedState.packageId,
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
        return record.id != 0 && record.status == AVADataTypes.StandingComputationStatus.Active;
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
    }

    function _validateAntiAbuse(
        AVARulePackageRegistry.RulePackage memory rulePackage,
        bytes32 workflowKey,
        AVADataTypes.Role actingRole,
        bytes32 subjectId,
        uint256 recognisedStateId
    ) internal view {
        rulePackage.antiAbuseModule.validateUse(
            workflowKey, actingRole, AVADataTypes.Action.RecordStandingUpdate, subjectId, bytes32(recognisedStateId), msg.sender
        );
    }

    function _validateStandingUpdateModules(
        AVADataTypes.Role actingRole,
        AVADataTypes.RecognisedStateRecord memory recognisedState,
        AVADataTypes.StandingComputationContext memory context,
        string calldata uri
    ) internal view {
        _requireUsableEvidenceForRecognisedState(context.evidenceReceiptId, recognisedState);
        AVARulePackageRegistry.RulePackage memory rulePackage =
            rulePackageRegistry.getRulePackageById(recognisedState.packageId);
        _validateAntiAbuse(rulePackage, recognisedState.workflowKey, actingRole, context.subjectId, context.recognisedStateId);
        rulePackage.standingComputationModule.validateStandingComputation(context);
        rulePackage.standingAdapter.validateStandingUpdate(
            actingRole,
            context.recognisedStateId,
            context.subjectId,
            context.dimension,
            context.delta,
            context.evidenceReceiptId,
            context.authorityId,
            uri,
            msg.sender
        );
    }

    function _requireUsableEvidenceForRecognisedState(
        uint256 evidenceReceiptId,
        AVADataTypes.RecognisedStateRecord memory recognisedState
    ) internal view {
        AVADataTypes.EvidenceReceipt memory receipt =
            evidenceRegistry.requireUsableEvidenceReceipt(evidenceReceiptId, recognisedState.workflowKey);
        if (receipt.packageId != recognisedState.packageId) revert AVADataTypes.InvalidState(evidenceReceiptId);
    }
}
