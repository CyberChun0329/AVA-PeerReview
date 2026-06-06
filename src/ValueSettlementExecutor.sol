// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "./AVADataTypes.sol";
import {AuthorityMatrix} from "./AuthorityMatrix.sol";
import {RoleIdentityRegistry} from "./RoleIdentityRegistry.sol";
import {AllocationExecutor} from "./AllocationExecutor.sol";
import {ConsequenceExecutor} from "./ConsequenceExecutor.sol";
import {IValueSettlementExecutor} from "./interfaces/IValueSettlementExecutor.sol";

interface IERC20SettlementAsset {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IPriorityTokenAsset {
    function mint(address to, uint256 amount) external;
    function consumeFrom(address from, uint256 amount) external;
}

contract ValueSettlementExecutor is IValueSettlementExecutor {
    bytes32 public constant VALUE_SETTLEMENT_CONTEXT_DOMAIN = keccak256("AVA_VALUE_SETTLEMENT_CONTEXT_V1");

    struct SourceSnapshot {
        uint256 packageId;
        bytes32 subjectId;
        address asset;
        address payer;
        uint256 amountOrUnits;
        AVADataTypes.ValueExecutionMode executionMode;
        AVADataTypes.ValueSettlementKind settlementKind;
        bytes32 executionReference;
    }

    struct SettlementContextInput {
        AVADataTypes.ExecutionSourceType sourceType;
        uint256 sourceRecordId;
        uint256 packageId;
        bytes32 subjectId;
        address asset;
        address payer;
        address recipient;
        uint256 amountOrUnits;
        AVADataTypes.ValueExecutionMode sourceExecutionMode;
        AVADataTypes.ValueSettlementKind sourceSettlementKind;
        bytes32 sourceExecutionReference;
        AVADataTypes.ValueSettlementKind settlementKind;
        AVADataTypes.ValueSettlementStatus status;
    }

    AuthorityMatrix public immutable authorityMatrix;
    AllocationExecutor public immutable allocationExecutor;
    ConsequenceExecutor public immutable consequenceExecutor;
    uint256 public nextValueSettlementId = 1;
    bool private settlementExecutionLocked;

    mapping(uint256 => AVADataTypes.ValueSettlementRecord) private settlements;
    mapping(bytes32 => AVADataTypes.ValueSettlementStatus) public settlementStatusBySourceKey;
    mapping(bytes32 => uint256) public latestSettlementIdBySourceKey;
    mapping(bytes32 => AVADataTypes.ValueSettlementStatus) public recoveryTerminalStatusBySourceKey;
    mapping(bytes32 => uint256) public recoveryTerminalSettlementIdBySourceKey;

    event ValueSettlementRecorded(
        uint256 indexed id,
        AVADataTypes.ExecutionSourceType indexed sourceType,
        uint256 indexed sourceRecordId,
        AVADataTypes.ValueSettlementKind kind,
        AVADataTypes.ValueSettlementStatus status
    );

    constructor(
        AuthorityMatrix authorityMatrix_,
        AllocationExecutor allocationExecutor_,
        ConsequenceExecutor consequenceExecutor_
    ) {
        authorityMatrix = authorityMatrix_;
        allocationExecutor = allocationExecutor_;
        consequenceExecutor = consequenceExecutor_;
    }

    function settleTokenTransfer(
        AVADataTypes.Role actingRole,
        AVADataTypes.ExecutionSourceType sourceType,
        uint256 sourceRecordId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        _enterSettlementExecution();
        SourceSnapshot memory source = _requireExecutableSource(
            sourceType, sourceRecordId, AVADataTypes.ValueExecutionMode.Claim, AVADataTypes.ValueSettlementKind.TokenTransfer
        );
        _requireSettlementAuthority(actingRole, authorityId, uri);
        _requireUnusedFinalSource(sourceType, sourceRecordId);
        address recipient = _subjectAccount(source.subjectId);
        _transferFromPayer(source.asset, source.payer, recipient, source.amountOrUnits);
        id = _recordSettlement(
            actingRole,
            sourceType,
            sourceRecordId,
            source,
            AVADataTypes.ValueSettlementKind.TokenTransfer,
            AVADataTypes.ValueSettlementStatus.Settled,
            recipient,
            authorityId,
            uri
        );
        _exitSettlementExecution();
    }

    function depositEscrow(
        AVADataTypes.Role actingRole,
        AVADataTypes.ExecutionSourceType sourceType,
        uint256 sourceRecordId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        _enterSettlementExecution();
        SourceSnapshot memory source = _requireExecutableSource(
            sourceType, sourceRecordId, AVADataTypes.ValueExecutionMode.Escrow, AVADataTypes.ValueSettlementKind.EscrowDeposit
        );
        _requireSettlementAuthority(actingRole, authorityId, uri);
        bytes32 sourceKey = _sourceKey(sourceType, sourceRecordId);
        if (settlementStatusBySourceKey[sourceKey] != AVADataTypes.ValueSettlementStatus.None) {
            revert AVADataTypes.InvalidState(sourceRecordId);
        }
        _transferFromPayer(source.asset, source.payer, address(this), source.amountOrUnits);
        id = _recordSettlement(
            actingRole,
            sourceType,
            sourceRecordId,
            source,
            AVADataTypes.ValueSettlementKind.EscrowDeposit,
            AVADataTypes.ValueSettlementStatus.Deposited,
            address(this),
            authorityId,
            uri
        );
        _exitSettlementExecution();
    }

    function claimEscrow(
        AVADataTypes.Role actingRole,
        AVADataTypes.ExecutionSourceType sourceType,
        uint256 sourceRecordId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        _enterSettlementExecution();
        SourceSnapshot memory source = _requireExecutableSource(
            sourceType, sourceRecordId, AVADataTypes.ValueExecutionMode.Escrow, AVADataTypes.ValueSettlementKind.EscrowClaim
        );
        _requireSettlementAuthority(actingRole, authorityId, uri);
        _requireEscrowDeposited(sourceType, sourceRecordId);
        address recipient = _subjectAccount(source.subjectId);
        _transfer(source.asset, recipient, source.amountOrUnits);
        id = _recordSettlement(
            actingRole,
            sourceType,
            sourceRecordId,
            source,
            AVADataTypes.ValueSettlementKind.EscrowClaim,
            AVADataTypes.ValueSettlementStatus.Claimed,
            recipient,
            authorityId,
            uri
        );
        _exitSettlementExecution();
    }

    function refundEscrow(
        AVADataTypes.Role actingRole,
        AVADataTypes.ExecutionSourceType sourceType,
        uint256 sourceRecordId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        _enterSettlementExecution();
        SourceSnapshot memory source = _requireExecutableSource(
            sourceType, sourceRecordId, AVADataTypes.ValueExecutionMode.Escrow, AVADataTypes.ValueSettlementKind.EscrowRefund
        );
        _requireSettlementAuthority(actingRole, authorityId, uri);
        _requireEscrowDeposited(sourceType, sourceRecordId);
        _transfer(source.asset, source.payer, source.amountOrUnits);
        id = _recordSettlement(
            actingRole,
            sourceType,
            sourceRecordId,
            source,
            AVADataTypes.ValueSettlementKind.EscrowRefund,
            AVADataTypes.ValueSettlementStatus.Refunded,
            source.payer,
            authorityId,
            uri
        );
        _exitSettlementExecution();
    }

    function mintPriorityToken(
        AVADataTypes.Role actingRole,
        AVADataTypes.ExecutionSourceType sourceType,
        uint256 sourceRecordId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        _enterSettlementExecution();
        SourceSnapshot memory source = _requireExecutableSource(
            sourceType,
            sourceRecordId,
            AVADataTypes.ValueExecutionMode.Claim,
            AVADataTypes.ValueSettlementKind.PriorityTokenMint
        );
        _requireSettlementAuthority(actingRole, authorityId, uri);
        _requireAllocationSource(sourceType, sourceRecordId, AVADataTypes.AllocationKind.AdministrativeQueueRecord);
        _requireUnusedFinalSource(sourceType, sourceRecordId);
        address recipient = _subjectAccount(source.subjectId);
        IPriorityTokenAsset(source.asset).mint(recipient, source.amountOrUnits);
        id = _recordSettlement(
            actingRole,
            sourceType,
            sourceRecordId,
            source,
            AVADataTypes.ValueSettlementKind.PriorityTokenMint,
            AVADataTypes.ValueSettlementStatus.Settled,
            recipient,
            authorityId,
            uri
        );
        _exitSettlementExecution();
    }

    function consumePriorityToken(
        AVADataTypes.Role actingRole,
        AVADataTypes.ExecutionSourceType sourceType,
        uint256 sourceRecordId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        _enterSettlementExecution();
        SourceSnapshot memory source = _requireExecutableSource(
            sourceType,
            sourceRecordId,
            AVADataTypes.ValueExecutionMode.Claim,
            AVADataTypes.ValueSettlementKind.PriorityTokenConsume
        );
        _requireSettlementAuthority(actingRole, authorityId, uri);
        _requireAllocationSource(sourceType, sourceRecordId, AVADataTypes.AllocationKind.AdministrativeQueueRecord);
        _requireUnusedFinalSource(sourceType, sourceRecordId);
        address recipient = _subjectAccount(source.subjectId);
        IPriorityTokenAsset(source.asset).consumeFrom(recipient, source.amountOrUnits);
        id = _recordSettlement(
            actingRole,
            sourceType,
            sourceRecordId,
            source,
            AVADataTypes.ValueSettlementKind.PriorityTokenConsume,
            AVADataTypes.ValueSettlementStatus.Settled,
            recipient,
            authorityId,
            uri
        );
        _exitSettlementExecution();
    }

    function settleClawback(
        AVADataTypes.Role actingRole,
        uint256 consequenceRecordId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        _enterSettlementExecution();
        SourceSnapshot memory source = _requireExecutableSource(
            AVADataTypes.ExecutionSourceType.ConsequenceRecord,
            consequenceRecordId,
            AVADataTypes.ValueExecutionMode.Claim,
            AVADataTypes.ValueSettlementKind.ClawbackTransfer
        );
        _requireSettlementAuthority(actingRole, authorityId, uri);
        _requireConsequenceKind(consequenceRecordId, AVADataTypes.ConsequenceKind.PenaltyRecord);
        _requireUnusedFinalSource(AVADataTypes.ExecutionSourceType.ConsequenceRecord, consequenceRecordId);
        address clawbackPayer = _subjectAccount(source.subjectId);
        address recipient = source.payer;
        _transferFromPayer(source.asset, clawbackPayer, recipient, source.amountOrUnits);
        id = _recordSettlement(
            actingRole,
            AVADataTypes.ExecutionSourceType.ConsequenceRecord,
            consequenceRecordId,
            source,
            AVADataTypes.ValueSettlementKind.ClawbackTransfer,
            AVADataTypes.ValueSettlementStatus.Settled,
            recipient,
            authorityId,
            uri
        );
        _exitSettlementExecution();
    }

    function recordRepaymentObligation(
        AVADataTypes.Role actingRole,
        AVADataTypes.ExecutionSourceType sourceType,
        uint256 sourceRecordId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        _requireNoSettlementExecutionInProgress();
        SourceSnapshot memory source = _requireSettlementSource(sourceType, sourceRecordId);
        _requireSettlementAuthority(actingRole, authorityId, uri);
        _requireRecoveryOpen(sourceType, sourceRecordId);
        id = _recordSettlement(
            actingRole,
            sourceType,
            sourceRecordId,
            source,
            AVADataTypes.ValueSettlementKind.RepaymentObligation,
            AVADataTypes.ValueSettlementStatus.ObligationRecorded,
            _recoveryRecipient(source),
            authorityId,
            uri
        );
    }

    function recordFuturePayoutSetoff(
        AVADataTypes.Role actingRole,
        AVADataTypes.ExecutionSourceType sourceType,
        uint256 sourceRecordId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        _requireNoSettlementExecutionInProgress();
        SourceSnapshot memory source = _requireSettlementSource(sourceType, sourceRecordId);
        _requireSettlementAuthority(actingRole, authorityId, uri);
        _requireRecoveryOpen(sourceType, sourceRecordId);
        id = _recordSettlement(
            actingRole,
            sourceType,
            sourceRecordId,
            source,
            AVADataTypes.ValueSettlementKind.FuturePayoutSetoff,
            AVADataTypes.ValueSettlementStatus.SetoffRecorded,
            _recoveryRecipient(source),
            authorityId,
            uri
        );
        _recordRecoveryTerminal(sourceType, sourceRecordId, id, AVADataTypes.ValueSettlementStatus.SetoffRecorded);
    }

    function recordWaiver(
        AVADataTypes.Role actingRole,
        AVADataTypes.ExecutionSourceType sourceType,
        uint256 sourceRecordId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        _requireNoSettlementExecutionInProgress();
        SourceSnapshot memory source = _requireSettlementSource(sourceType, sourceRecordId);
        _requireSettlementAuthority(actingRole, authorityId, uri);
        _requireRecoveryOpen(sourceType, sourceRecordId);
        id = _recordSettlement(
            actingRole,
            sourceType,
            sourceRecordId,
            source,
            AVADataTypes.ValueSettlementKind.Waiver,
            AVADataTypes.ValueSettlementStatus.Waived,
            _recoveryRecipient(source),
            authorityId,
            uri
        );
        _recordRecoveryTerminal(sourceType, sourceRecordId, id, AVADataTypes.ValueSettlementStatus.Waived);
    }

    function recordSatisfaction(
        AVADataTypes.Role actingRole,
        AVADataTypes.ExecutionSourceType sourceType,
        uint256 sourceRecordId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        _requireNoSettlementExecutionInProgress();
        SourceSnapshot memory source = _requireSettlementSource(sourceType, sourceRecordId);
        _requireSettlementAuthority(actingRole, authorityId, uri);
        _requireRecoveryOpen(sourceType, sourceRecordId);
        id = _recordSettlement(
            actingRole,
            sourceType,
            sourceRecordId,
            source,
            AVADataTypes.ValueSettlementKind.Satisfaction,
            AVADataTypes.ValueSettlementStatus.Satisfied,
            _recoveryRecipient(source),
            authorityId,
            uri
        );
        _recordRecoveryTerminal(sourceType, sourceRecordId, id, AVADataTypes.ValueSettlementStatus.Satisfied);
    }

    function getValueSettlement(uint256 id) external view returns (AVADataTypes.ValueSettlementRecord memory) {
        AVADataTypes.ValueSettlementRecord memory settlement = settlements[id];
        if (settlement.id == 0) revert AVADataTypes.UnknownReference(id);
        return settlement;
    }

    function computeSettlementContextHash(SettlementContextInput memory input) public pure returns (bytes32) {
        if (
            input.sourceType == AVADataTypes.ExecutionSourceType.None || input.sourceRecordId == 0 || input.packageId == 0
                || input.subjectId == bytes32(0) || input.asset == address(0) || input.payer == address(0)
                || input.recipient == address(0) || input.amountOrUnits == 0
                || input.sourceExecutionMode == AVADataTypes.ValueExecutionMode.None
                || input.sourceSettlementKind == AVADataTypes.ValueSettlementKind.None
                || input.sourceExecutionReference == bytes32(0)
                || input.settlementKind == AVADataTypes.ValueSettlementKind.None
                || input.status == AVADataTypes.ValueSettlementStatus.None
        ) {
            return bytes32(0);
        }
        bytes32 sourceHash = keccak256(
            abi.encode(
                input.sourceType,
                input.sourceRecordId,
                input.packageId,
                input.subjectId,
                input.sourceExecutionMode,
                input.sourceSettlementKind,
                input.sourceExecutionReference
            )
        );
        bytes32 valueHash =
            keccak256(abi.encode(input.asset, input.payer, input.recipient, input.amountOrUnits));
        bytes32 receiptHash = keccak256(abi.encode(input.settlementKind, input.status));
        return keccak256(abi.encode(VALUE_SETTLEMENT_CONTEXT_DOMAIN, sourceHash, valueHash, receiptHash));
    }

    function _recordSettlement(
        AVADataTypes.Role actingRole,
        AVADataTypes.ExecutionSourceType sourceType,
        uint256 sourceRecordId,
        SourceSnapshot memory source,
        AVADataTypes.ValueSettlementKind kind,
        AVADataTypes.ValueSettlementStatus status,
        address recipient,
        bytes32 authorityId,
        string calldata uri
    ) internal returns (uint256 id) {
        _requireSettlementAuthority(actingRole, authorityId, uri);
        if (recipient == address(0)) {
            revert AVADataTypes.EmptyValue();
        }
        bytes32 settlementContextHash = _settlementContextHash(
            sourceType, sourceRecordId, source, kind, status, recipient
        );
        if (settlementContextHash == bytes32(0)) revert AVADataTypes.EmptyValue();

        id = nextValueSettlementId++;
        settlements[id] = AVADataTypes.ValueSettlementRecord({
            id: id,
            sourceType: sourceType,
            sourceRecordId: sourceRecordId,
            packageId: source.packageId,
            kind: kind,
            status: status,
            asset: source.asset,
            payer: source.payer,
            recipient: recipient,
            subjectId: source.subjectId,
            amountOrUnits: source.amountOrUnits,
            sourceExecutionMode: source.executionMode,
            sourceSettlementKind: source.settlementKind,
            sourceExecutionReference: source.executionReference,
            settlementContextHash: settlementContextHash,
            authorityRole: actingRole,
            authorityId: authorityId,
            uri: uri,
            executedBy: msg.sender
        });
        bytes32 key = _sourceKey(sourceType, sourceRecordId);
        settlementStatusBySourceKey[key] = status;
        latestSettlementIdBySourceKey[key] = id;
        emit ValueSettlementRecorded(id, sourceType, sourceRecordId, kind, status);
    }

    function _enterSettlementExecution() internal {
        if (settlementExecutionLocked) revert AVADataTypes.InvalidState(0);
        settlementExecutionLocked = true;
    }

    function _exitSettlementExecution() internal {
        settlementExecutionLocked = false;
    }

    function _requireNoSettlementExecutionInProgress() internal view {
        if (settlementExecutionLocked) revert AVADataTypes.InvalidState(0);
    }

    function _requireExecutableSource(
        AVADataTypes.ExecutionSourceType sourceType,
        uint256 sourceRecordId,
        AVADataTypes.ValueExecutionMode requiredMode,
        AVADataTypes.ValueSettlementKind settlementKind
    ) internal view returns (SourceSnapshot memory source) {
        if (
            sourceType == AVADataTypes.ExecutionSourceType.None || sourceRecordId == 0
                || settlementKind == AVADataTypes.ValueSettlementKind.None
        ) {
            revert AVADataTypes.EmptyValue();
        }
        if (sourceType == AVADataTypes.ExecutionSourceType.AllocationRecord) {
            AVADataTypes.AllocationExecutionRecord memory allocation =
                allocationExecutor.getAllocationExecution(sourceRecordId);
            source = SourceSnapshot({
                packageId: allocation.packageId,
                subjectId: allocation.subjectId,
                asset: allocation.asset,
                payer: allocation.payer,
                amountOrUnits: allocation.amountOrUnits,
                executionMode: allocation.executionMode,
                settlementKind: allocation.settlementKind,
                executionReference: allocation.executionReference
            });
        } else if (sourceType == AVADataTypes.ExecutionSourceType.ConsequenceRecord) {
            AVADataTypes.ConsequenceRecord memory consequence = consequenceExecutor.getConsequence(sourceRecordId);
            source = SourceSnapshot({
                packageId: consequence.packageId,
                subjectId: consequence.subjectId,
                asset: consequence.asset,
                payer: consequence.payer,
                amountOrUnits: consequence.amountOrUnits,
                executionMode: consequence.executionMode,
                settlementKind: consequence.settlementKind,
                executionReference: consequence.executionReference
            });
        } else {
            revert AVADataTypes.InvalidState(uint256(sourceType));
        }
        if (
            source.packageId == 0 || source.subjectId == bytes32(0) || source.asset == address(0)
                || source.payer == address(0) || source.amountOrUnits == 0 || source.executionReference == bytes32(0)
                || source.executionMode != requiredMode
                || !_settlementKindAllows(source.settlementKind, settlementKind)
        ) {
            revert AVADataTypes.InvalidState(sourceRecordId);
        }
        authorityMatrix.requireKnownActiveSubject(source.subjectId);
    }

    function _requireSettlementSource(AVADataTypes.ExecutionSourceType sourceType, uint256 sourceRecordId)
        internal
        view
        returns (SourceSnapshot memory source)
    {
        if (sourceType == AVADataTypes.ExecutionSourceType.None || sourceRecordId == 0) {
            revert AVADataTypes.EmptyValue();
        }
        if (sourceType == AVADataTypes.ExecutionSourceType.AllocationRecord) {
            AVADataTypes.AllocationExecutionRecord memory allocation =
                allocationExecutor.getAllocationExecution(sourceRecordId);
            source = SourceSnapshot({
                packageId: allocation.packageId,
                subjectId: allocation.subjectId,
                asset: allocation.asset,
                payer: allocation.payer,
                amountOrUnits: allocation.amountOrUnits,
                executionMode: allocation.executionMode,
                settlementKind: allocation.settlementKind,
                executionReference: allocation.executionReference
            });
        } else if (sourceType == AVADataTypes.ExecutionSourceType.ConsequenceRecord) {
            AVADataTypes.ConsequenceRecord memory consequence = consequenceExecutor.getConsequence(sourceRecordId);
            source = SourceSnapshot({
                packageId: consequence.packageId,
                subjectId: consequence.subjectId,
                asset: consequence.asset,
                payer: consequence.payer,
                amountOrUnits: consequence.amountOrUnits,
                executionMode: consequence.executionMode,
                settlementKind: consequence.settlementKind,
                executionReference: consequence.executionReference
            });
        } else {
            revert AVADataTypes.InvalidState(uint256(sourceType));
        }
        if (
            source.packageId == 0 || source.subjectId == bytes32(0) || source.amountOrUnits == 0
                || source.executionMode == AVADataTypes.ValueExecutionMode.RecordOnly
                || source.settlementKind == AVADataTypes.ValueSettlementKind.None
        ) {
            revert AVADataTypes.InvalidState(sourceRecordId);
        }
        authorityMatrix.requireKnownActiveSubject(source.subjectId);
    }

    function _requireAllocationSource(
        AVADataTypes.ExecutionSourceType sourceType,
        uint256 sourceRecordId,
        AVADataTypes.AllocationKind allocationKind
    ) internal view {
        if (sourceType != AVADataTypes.ExecutionSourceType.AllocationRecord) {
            revert AVADataTypes.InvalidState(sourceRecordId);
        }
        AVADataTypes.AllocationExecutionRecord memory allocation = allocationExecutor.getAllocationExecution(sourceRecordId);
        if (allocation.allocationKind != allocationKind) revert AVADataTypes.InvalidState(sourceRecordId);
    }

    function _requireConsequenceKind(uint256 consequenceRecordId, AVADataTypes.ConsequenceKind kind) internal view {
        AVADataTypes.ConsequenceRecord memory consequence = consequenceExecutor.getConsequence(consequenceRecordId);
        if (consequence.kind != kind) revert AVADataTypes.InvalidState(consequenceRecordId);
    }

    function _requireSettlementAuthority(
        AVADataTypes.Role actingRole,
        bytes32 authorityId,
        string calldata uri
    ) internal view {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.ExecuteValueSettlement, authorityId
        );
        if (authorityId == bytes32(0) || bytes(uri).length == 0) {
            revert AVADataTypes.EmptyValue();
        }
    }

    function _requireUnusedFinalSource(AVADataTypes.ExecutionSourceType sourceType, uint256 sourceRecordId) internal view {
        AVADataTypes.ValueSettlementStatus status = settlementStatusBySourceKey[_sourceKey(sourceType, sourceRecordId)];
        if (status != AVADataTypes.ValueSettlementStatus.None) revert AVADataTypes.InvalidState(sourceRecordId);
    }

    function _requireEscrowDeposited(AVADataTypes.ExecutionSourceType sourceType, uint256 sourceRecordId) internal view {
        AVADataTypes.ValueSettlementStatus status = settlementStatusBySourceKey[_sourceKey(sourceType, sourceRecordId)];
        if (status != AVADataTypes.ValueSettlementStatus.Deposited) revert AVADataTypes.InvalidState(sourceRecordId);
    }

    function _requireRecoveryOpen(AVADataTypes.ExecutionSourceType sourceType, uint256 sourceRecordId) internal view {
        bytes32 key = _sourceKey(sourceType, sourceRecordId);
        AVADataTypes.ValueSettlementStatus status = settlementStatusBySourceKey[key];
        if (
            status == AVADataTypes.ValueSettlementStatus.Deposited
                || status == AVADataTypes.ValueSettlementStatus.Refunded
                || status == AVADataTypes.ValueSettlementStatus.SetoffRecorded
                || status == AVADataTypes.ValueSettlementStatus.Waived
                || status == AVADataTypes.ValueSettlementStatus.Satisfied
                || recoveryTerminalStatusBySourceKey[key] != AVADataTypes.ValueSettlementStatus.None
        ) {
            revert AVADataTypes.InvalidState(sourceRecordId);
        }
    }

    function _recordRecoveryTerminal(
        AVADataTypes.ExecutionSourceType sourceType,
        uint256 sourceRecordId,
        uint256 settlementId,
        AVADataTypes.ValueSettlementStatus status
    ) internal {
        bytes32 key = _sourceKey(sourceType, sourceRecordId);
        recoveryTerminalStatusBySourceKey[key] = status;
        recoveryTerminalSettlementIdBySourceKey[key] = settlementId;
    }

    function _subjectAccount(bytes32 subjectId) internal view returns (address account) {
        RoleIdentityRegistry registry = authorityMatrix.roleRegistry();
        account = registry.getSubject(subjectId).account;
        if (account == address(0)) revert AVADataTypes.UnknownSubject(subjectId);
    }

    function _transferFromPayer(address asset, address payer, address recipient, uint256 amount) internal {
        if (!IERC20SettlementAsset(asset).transferFrom(payer, recipient, amount)) {
            revert AVADataTypes.InvalidState(amount);
        }
    }

    function _transfer(address asset, address recipient, uint256 amount) internal {
        if (!IERC20SettlementAsset(asset).transfer(recipient, amount)) {
            revert AVADataTypes.InvalidState(amount);
        }
    }

    function _recoveryRecipient(SourceSnapshot memory source) internal view returns (address recipient) {
        recipient = source.payer;
        if (recipient == address(0)) {
            recipient = _subjectAccount(source.subjectId);
        }
    }

    function _settlementKindAllows(
        AVADataTypes.ValueSettlementKind storedKind,
        AVADataTypes.ValueSettlementKind requestedKind
    ) internal pure returns (bool) {
        if (storedKind == requestedKind) return true;
        return storedKind == AVADataTypes.ValueSettlementKind.EscrowDeposit
            && (
                requestedKind == AVADataTypes.ValueSettlementKind.EscrowClaim
                    || requestedKind == AVADataTypes.ValueSettlementKind.EscrowRefund
            );
    }

    function _sourceKey(AVADataTypes.ExecutionSourceType sourceType, uint256 sourceRecordId)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(sourceType, sourceRecordId));
    }

    function _settlementContextHash(
        AVADataTypes.ExecutionSourceType sourceType,
        uint256 sourceRecordId,
        SourceSnapshot memory source,
        AVADataTypes.ValueSettlementKind kind,
        AVADataTypes.ValueSettlementStatus status,
        address recipient
    ) internal pure returns (bytes32) {
        SettlementContextInput memory input;
        input.sourceType = sourceType;
        input.sourceRecordId = sourceRecordId;
        input.packageId = source.packageId;
        input.subjectId = source.subjectId;
        input.asset = source.asset;
        input.payer = source.payer;
        input.recipient = recipient;
        input.amountOrUnits = source.amountOrUnits;
        input.sourceExecutionMode = source.executionMode;
        input.sourceSettlementKind = source.settlementKind;
        input.sourceExecutionReference = source.executionReference;
        input.settlementKind = kind;
        input.status = status;
        return computeSettlementContextHash(input);
    }
}
