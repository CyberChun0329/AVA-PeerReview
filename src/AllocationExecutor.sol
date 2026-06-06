// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "./AVADataTypes.sol";
import {AuthorityMatrix} from "./AuthorityMatrix.sol";
import {AVAStateMachine} from "./AVAStateMachine.sol";
import {AVARulePackageRegistry} from "./AVARulePackageRegistry.sol";
import {EvidenceCommitmentRegistry} from "./EvidenceCommitmentRegistry.sol";

contract AllocationExecutor {
    AuthorityMatrix public immutable authorityMatrix;
    AVAStateMachine public immutable stateMachine;
    AVARulePackageRegistry public immutable rulePackageRegistry;
    EvidenceCommitmentRegistry public immutable evidenceRegistry;
    uint256 public nextAllocationExecutionId = 1;

    mapping(uint256 => AVADataTypes.AllocationExecutionRecord) private allocationExecutions;

    event AllocationExecuted(
        uint256 indexed id, uint256 indexed recognisedStateId, AVADataTypes.AllocationKind indexed allocationKind
    );

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

    function executeAllocation(
        AVADataTypes.Role actingRole,
        uint256 recognisedStateId,
        AVADataTypes.AllocationKind allocationKind,
        bytes32 subjectId,
        uint256 amountOrUnits,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        return _executeAllocationWithExecution(
            actingRole,
            allocationKind,
            _defaultValueExecutionContext(recognisedStateId, subjectId, amountOrUnits, evidenceReceiptId, authorityId, uri)
        );
    }

    function executeAllocationWithExecution(
        AVADataTypes.Role actingRole,
        AVADataTypes.AllocationKind allocationKind,
        AVADataTypes.ValueExecutionContext calldata executionContext
    ) external returns (uint256 id) {
        return _executeAllocationWithExecution(actingRole, allocationKind, executionContext);
    }

    function recordRewardValue(
        AVADataTypes.Role actingRole,
        uint256 recognisedStateId,
        bytes32 subjectId,
        uint256 amountOrUnits,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        return _recordRewardValueWithExecution(
            actingRole,
            _defaultValueExecutionContext(recognisedStateId, subjectId, amountOrUnits, evidenceReceiptId, authorityId, uri)
        );
    }

    function recordRewardValueWithExecution(
        AVADataTypes.Role actingRole,
        AVADataTypes.ValueExecutionContext calldata executionContext
    ) external returns (uint256 id) {
        return _recordRewardValueWithExecution(actingRole, executionContext);
    }

    function recordAdministrativePriority(
        AVADataTypes.Role actingRole,
        uint256 recognisedStateId,
        bytes32 subjectId,
        uint256 amountOrUnits,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        return _recordAdministrativePriorityWithExecution(
            actingRole,
            _defaultValueExecutionContext(recognisedStateId, subjectId, amountOrUnits, evidenceReceiptId, authorityId, uri)
        );
    }

    function recordAdministrativePriorityWithExecution(
        AVADataTypes.Role actingRole,
        AVADataTypes.ValueExecutionContext calldata executionContext
    ) external returns (uint256 id) {
        return _recordAdministrativePriorityWithExecution(actingRole, executionContext);
    }

    function getAllocationExecution(uint256 id) external view returns (AVADataTypes.AllocationExecutionRecord memory) {
        AVADataTypes.AllocationExecutionRecord memory allocationExecution = allocationExecutions[id];
        if (allocationExecution.id == 0) revert AVADataTypes.UnknownReference(id);
        return allocationExecution;
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

    function _recordAllocation(
        AVADataTypes.Role actingRole,
        AVADataTypes.AllocationKind allocationKind,
        AVADataTypes.ValueExecutionContext memory executionContext,
        uint256 packageId
    ) internal returns (uint256 id) {
        id = nextAllocationExecutionId++;
        allocationExecutions[id] = AVADataTypes.AllocationExecutionRecord({
            id: id,
            recognisedStateId: executionContext.recognisedStateId,
            packageId: packageId,
            allocationKind: allocationKind,
            subjectId: executionContext.recipientSubjectId,
            asset: executionContext.asset,
            payer: executionContext.payer,
            amountOrUnits: executionContext.amount,
            executionMode: executionContext.mode,
            settlementKind: executionContext.settlementKind,
            executionReference: executionContext.executionReference,
            evidenceReceiptId: executionContext.evidenceReceiptId,
            authorityRole: actingRole,
            authorityId: executionContext.authorityId,
            uri: executionContext.uri,
            executedBy: msg.sender
        });

        emit AllocationExecuted(id, executionContext.recognisedStateId, allocationKind);
    }

    function _validateAntiAbuse(
        AVARulePackageRegistry.RulePackage memory rulePackage,
        bytes32 workflowKey,
        AVADataTypes.Role actingRole,
        bytes32 subjectId,
        uint256 recognisedStateId
    ) internal view {
        rulePackage.antiAbuseModule.validateUse(
            workflowKey, actingRole, AVADataTypes.Action.ExecuteAllocation, subjectId, bytes32(recognisedStateId), msg.sender
        );
    }

    function _validateValueExecution(
        AVARulePackageRegistry.RulePackage memory rulePackage,
        AVADataTypes.ValueExecutionContext memory executionContext
    ) internal view {
        rulePackage.valueExecutionAdapter.validateValueExecution(executionContext);
    }

    function _defaultValueExecutionContext(
        uint256 recognisedStateId,
        bytes32 subjectId,
        uint256 amountOrUnits,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri
    ) internal view returns (AVADataTypes.ValueExecutionContext memory) {
        return AVADataTypes.ValueExecutionContext({
            recognisedStateId: recognisedStateId,
            asset: address(0),
            payer: address(0),
            recipientSubjectId: subjectId,
            amount: amountOrUnits,
            mode: AVADataTypes.ValueExecutionMode.RecordOnly,
            settlementKind: AVADataTypes.ValueSettlementKind.None,
            executionReference: keccak256(bytes(uri)),
            authorityId: authorityId,
            evidenceReceiptId: evidenceReceiptId,
            uri: uri,
            actor: msg.sender
        });
    }

    function _requireValidExecutionContext(AVADataTypes.ValueExecutionContext memory executionContext) internal view {
        if (
            executionContext.recognisedStateId == 0 || executionContext.recipientSubjectId == bytes32(0)
                || executionContext.amount == 0 || executionContext.executionReference == bytes32(0)
                || executionContext.evidenceReceiptId == 0 || executionContext.authorityId == bytes32(0)
                || executionContext.actor != msg.sender
                || (executionContext.mode == AVADataTypes.ValueExecutionMode.RecordOnly
                    && executionContext.settlementKind != AVADataTypes.ValueSettlementKind.None)
                || (executionContext.mode != AVADataTypes.ValueExecutionMode.RecordOnly
                    && executionContext.settlementKind == AVADataTypes.ValueSettlementKind.None)
        ) {
            revert AVADataTypes.EmptyValue();
        }
    }

    function _executeAllocationWithExecution(
        AVADataTypes.Role actingRole,
        AVADataTypes.AllocationKind allocationKind,
        AVADataTypes.ValueExecutionContext memory executionContext
    ) internal returns (uint256 id) {
        if (allocationKind == AVADataTypes.AllocationKind.None) {
            revert AVADataTypes.EmptyValue();
        }
        _requireCoreAllocationKind(allocationKind, executionContext.recognisedStateId);
        AVARulePackageRegistry.RulePackage memory rulePackage =
            _prepareAllocationExecution(actingRole, executionContext);
        _requireSettlementKindForAllocation(allocationKind, executionContext);
        rulePackage.allocationModule.validateAllocation(
            actingRole,
            executionContext.recognisedStateId,
            allocationKind,
            executionContext.recipientSubjectId,
            executionContext.amount,
            executionContext.evidenceReceiptId,
            executionContext.authorityId,
            executionContext.uri,
            msg.sender
        );
        id = _recordAllocation(actingRole, allocationKind, executionContext, rulePackage.packageId);
    }

    function _requireCoreAllocationKind(AVADataTypes.AllocationKind allocationKind, uint256 recognisedStateId)
        internal
        pure
    {
        if (
            allocationKind == AVADataTypes.AllocationKind.RewardValueRecord
                || allocationKind == AVADataTypes.AllocationKind.AdministrativeQueueRecord
        ) {
            revert AVADataTypes.InvalidState(recognisedStateId);
        }
    }

    function _recordRewardValueWithExecution(
        AVADataTypes.Role actingRole,
        AVADataTypes.ValueExecutionContext memory executionContext
    ) internal returns (uint256 id) {
        AVARulePackageRegistry.RulePackage memory rulePackage =
            _prepareAllocationExecution(actingRole, executionContext);
        _requireSettlementKindForAllocation(AVADataTypes.AllocationKind.RewardValueRecord, executionContext);
        rulePackage.rewardAdapter.validateRewardRecord(
            actingRole,
            executionContext.recognisedStateId,
            executionContext.recipientSubjectId,
            executionContext.amount,
            executionContext.evidenceReceiptId,
            executionContext.authorityId,
            executionContext.uri,
            msg.sender
        );
        id = _recordAllocation(
            actingRole, AVADataTypes.AllocationKind.RewardValueRecord, executionContext, rulePackage.packageId
        );
    }

    function _recordAdministrativePriorityWithExecution(
        AVADataTypes.Role actingRole,
        AVADataTypes.ValueExecutionContext memory executionContext
    ) internal returns (uint256 id) {
        AVARulePackageRegistry.RulePackage memory rulePackage =
            _prepareAllocationExecution(actingRole, executionContext);
        _requireSettlementKindForAllocation(AVADataTypes.AllocationKind.AdministrativeQueueRecord, executionContext);
        rulePackage.priorityAdapter.validatePriorityRecord(
            actingRole,
            executionContext.recognisedStateId,
            executionContext.recipientSubjectId,
            executionContext.amount,
            executionContext.evidenceReceiptId,
            executionContext.authorityId,
            executionContext.uri,
            msg.sender
        );
        id = _recordAllocation(
            actingRole, AVADataTypes.AllocationKind.AdministrativeQueueRecord, executionContext, rulePackage.packageId
        );
    }

    function _prepareAllocationExecution(
        AVADataTypes.Role actingRole,
        AVADataTypes.ValueExecutionContext memory executionContext
    ) internal view returns (AVARulePackageRegistry.RulePackage memory rulePackage) {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.ExecuteAllocation, executionContext.authorityId
        );
        AVADataTypes.RecognisedStateRecord memory recognisedState =
            _requireAllowedRecognisedState(executionContext.recognisedStateId);
        _requireValidExecutionContext(executionContext);
        authorityMatrix.requireKnownActiveSubject(executionContext.recipientSubjectId);
        AVADataTypes.EvidenceReceipt memory evidence =
            evidenceRegistry.requireUsableEvidenceReceipt(executionContext.evidenceReceiptId, recognisedState.workflowKey);
        if (evidence.packageId != recognisedState.packageId) {
            revert AVADataTypes.InvalidState(executionContext.evidenceReceiptId);
        }
        rulePackage = rulePackageRegistry.getRulePackageById(recognisedState.packageId);
        _validateAntiAbuse(
            rulePackage,
            recognisedState.workflowKey,
            actingRole,
            executionContext.recipientSubjectId,
            executionContext.recognisedStateId
        );
        _validateValueExecution(rulePackage, executionContext);
    }

    function _requireSettlementKindForAllocation(
        AVADataTypes.AllocationKind allocationKind,
        AVADataTypes.ValueExecutionContext memory executionContext
    ) internal pure {
        if (executionContext.mode == AVADataTypes.ValueExecutionMode.RecordOnly) {
            return;
        }
        if (allocationKind == AVADataTypes.AllocationKind.RewardValueRecord) {
            bool validRewardSettlement = executionContext.settlementKind == AVADataTypes.ValueSettlementKind.TokenTransfer
                || executionContext.settlementKind == AVADataTypes.ValueSettlementKind.EscrowDeposit;
            if (!validRewardSettlement) revert AVADataTypes.InvalidState(executionContext.recognisedStateId);
        } else if (allocationKind == AVADataTypes.AllocationKind.AdministrativeQueueRecord) {
            bool validPrioritySettlement =
                executionContext.settlementKind == AVADataTypes.ValueSettlementKind.PriorityTokenMint
                    || executionContext.settlementKind == AVADataTypes.ValueSettlementKind.PriorityTokenConsume;
            if (!validPrioritySettlement) revert AVADataTypes.InvalidState(executionContext.recognisedStateId);
        } else {
            revert AVADataTypes.InvalidState(executionContext.recognisedStateId);
        }
    }
}
