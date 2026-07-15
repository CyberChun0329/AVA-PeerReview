// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "./AVADataTypes.sol";
import {AuthorityMatrix} from "./AuthorityMatrix.sol";
import {RoleIdentityRegistry} from "./RoleIdentityRegistry.sol";
import {AllocationExecutor} from "./AllocationExecutor.sol";
import {ConsequenceExecutor} from "./ConsequenceExecutor.sol";
import {AVARulePackageRegistry} from "./AVARulePackageRegistry.sol";
import {AVAStateMachine} from "./AVAStateMachine.sol";
import {EvidenceCommitmentRegistry} from "./EvidenceCommitmentRegistry.sol";
import {IValueSettlementExecutor} from "./interfaces/IValueSettlementExecutor.sol";
import {StandingRevisionRegistry} from "./StandingRevisionRegistry.sol";

interface IERC20SettlementAsset {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IPriorityTokenAsset {
    function mint(address to, uint256 amount) external;
    function consumeFrom(address from, uint256 amount) external;
}

contract ValueSettlementExecutor is IValueSettlementExecutor {
    bytes32 public constant VALUE_SETTLEMENT_CONTEXT_DOMAIN = keccak256("AVA_VALUE_SETTLEMENT_CONTEXT_V2");

    struct SourceSnapshot {
        uint256 recognisedStateId;
        uint256 evidenceReceiptId;
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
        uint256 recognisedStateId;
        uint256 packageId;
        bytes32 subjectId;
        address asset;
        address payer;
        address recipient;
        uint256 amountOrUnits;
        AVADataTypes.ValueExecutionMode sourceExecutionMode;
        AVADataTypes.ValueSettlementKind sourceSettlementKind;
        bytes32 sourceExecutionReference;
        uint256 originSettlementId;
        uint256 penaltyConsequenceId;
        uint256 repaymentObligationId;
        AVADataTypes.ValueSettlementKind settlementKind;
        AVADataTypes.ValueSettlementStatus status;
    }

    struct SettlementWriteInput {
        AVADataTypes.ExecutionSourceType sourceType;
        uint256 sourceRecordId;
        AVADataTypes.ValueSettlementKind kind;
        AVADataTypes.ValueSettlementStatus status;
        address recipient;
        uint256 originSettlementId;
        uint256 penaltyConsequenceId;
        uint256 repaymentObligationId;
    }

    AuthorityMatrix public immutable authorityMatrix;
    AllocationExecutor public immutable allocationExecutor;
    ConsequenceExecutor public immutable consequenceExecutor;
    StandingRevisionRegistry public immutable standingRevisionRegistry;
    uint256 public nextValueSettlementId = 1;
    bool private settlementExecutionLocked;

    mapping(uint256 => AVADataTypes.ValueSettlementRecord) private settlements;
    mapping(bytes32 => AVADataTypes.ValueSettlementStatus) public settlementStatusBySourceKey;
    mapping(bytes32 => uint256) public latestSettlementIdBySourceKey;
    mapping(uint256 => uint256) public repaymentObligationIdByOriginSettlementId;
    mapping(uint256 => AVADataTypes.ValueSettlementStatus) public recoveryTerminalStatusByObligationId;
    mapping(uint256 => uint256) public recoveryTerminalSettlementIdByObligationId;

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
        ConsequenceExecutor consequenceExecutor_,
        StandingRevisionRegistry standingRevisionRegistry_
    ) {
        if (address(standingRevisionRegistry_) == address(0)) {
            revert AVADataTypes.EmptyValue();
        }
        authorityMatrix = authorityMatrix_;
        allocationExecutor = allocationExecutor_;
        consequenceExecutor = consequenceExecutor_;
        standingRevisionRegistry = standingRevisionRegistry_;
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
            sourceType,
            sourceRecordId,
            AVADataTypes.ValueExecutionMode.Claim,
            AVADataTypes.ValueSettlementKind.TokenTransfer
        );
        _requireSettlementAuthority(actingRole, authorityId, uri);
        _requireUnusedFinalSource(sourceType, sourceRecordId);
        address recipient = _subjectAccount(source.subjectId);
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
        _transferFromPayer(source.asset, source.payer, recipient, source.amountOrUnits);
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
            sourceType,
            sourceRecordId,
            AVADataTypes.ValueExecutionMode.Escrow,
            AVADataTypes.ValueSettlementKind.EscrowDeposit
        );
        _requireSettlementAuthority(actingRole, authorityId, uri);
        bytes32 sourceKey = _sourceKey(sourceType, sourceRecordId);
        if (settlementStatusBySourceKey[sourceKey] != AVADataTypes.ValueSettlementStatus.None) {
            revert AVADataTypes.InvalidState(sourceRecordId);
        }
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
        _transferFromPayer(source.asset, source.payer, address(this), source.amountOrUnits);
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
            sourceType,
            sourceRecordId,
            AVADataTypes.ValueExecutionMode.Escrow,
            AVADataTypes.ValueSettlementKind.EscrowClaim
        );
        _requireSettlementAuthority(actingRole, authorityId, uri);
        _requireEscrowDeposited(sourceType, sourceRecordId);
        address recipient = _subjectAccount(source.subjectId);
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
        _transfer(source.asset, recipient, source.amountOrUnits);
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
            sourceType,
            sourceRecordId,
            AVADataTypes.ValueExecutionMode.Escrow,
            AVADataTypes.ValueSettlementKind.EscrowRefund
        );
        _requireSettlementAuthority(actingRole, authorityId, uri);
        _requireEscrowDeposited(sourceType, sourceRecordId);
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
        _transfer(source.asset, source.payer, source.amountOrUnits);
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
        IPriorityTokenAsset(source.asset).mint(recipient, source.amountOrUnits);
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
        IPriorityTokenAsset(source.asset).consumeFrom(recipient, source.amountOrUnits);
        _exitSettlementExecution();
    }

    function settleClawback(
        AVADataTypes.Role actingRole,
        uint256 repaymentObligationId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        _enterSettlementExecution();
        (AVADataTypes.ValueSettlementRecord memory obligation, SourceSnapshot memory source) =
            _requireRecoveryObligation(repaymentObligationId);
        _requireCurrentConsequenceEvidence(source.packageId, source.evidenceReceiptId);
        _requireSettlementAuthority(actingRole, authorityId, uri);
        address clawbackPayer = _subjectAccount(source.subjectId);
        address recipient = obligation.recipient;
        id = _recordRecoveryReceipt(
            actingRole,
            repaymentObligationId,
            AVADataTypes.ValueSettlementKind.ClawbackTransfer,
            AVADataTypes.ValueSettlementStatus.Settled,
            authorityId,
            uri
        );
        _transferFromPayer(source.asset, clawbackPayer, recipient, source.amountOrUnits);
        _exitSettlementExecution();
    }

    function recordRepaymentObligation(
        AVADataTypes.Role actingRole,
        uint256 penaltyConsequenceId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        _requireNoSettlementExecutionInProgress();
        _requireSettlementAuthority(actingRole, authorityId, uri);
        (AVADataTypes.ConsequenceRecord memory penalty, SourceSnapshot memory source) =
            _requireRecoveryPenalty(penaltyConsequenceId);
        AVADataTypes.ValueSettlementRecord memory origin = _requireCompletedOriginSettlement(penalty, source);
        if (repaymentObligationIdByOriginSettlementId[penalty.originSettlementId] != 0) {
            revert AVADataTypes.InvalidState(penalty.originSettlementId);
        }
        id = _recordLinkedSettlement(
            actingRole,
            source,
            SettlementWriteInput({
                sourceType: AVADataTypes.ExecutionSourceType.ConsequenceRecord,
                sourceRecordId: penaltyConsequenceId,
                kind: AVADataTypes.ValueSettlementKind.RepaymentObligation,
                status: AVADataTypes.ValueSettlementStatus.ObligationRecorded,
                recipient: origin.payer,
                originSettlementId: penalty.originSettlementId,
                penaltyConsequenceId: penaltyConsequenceId,
                repaymentObligationId: 0
            }),
            authorityId,
            uri
        );
        repaymentObligationIdByOriginSettlementId[penalty.originSettlementId] = id;
    }

    function recordFuturePayoutSetoff(
        AVADataTypes.Role actingRole,
        uint256 repaymentObligationId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        id = _recordRecoveryTerminalReceipt(
            actingRole,
            repaymentObligationId,
            AVADataTypes.ValueSettlementKind.FuturePayoutSetoff,
            AVADataTypes.ValueSettlementStatus.SetoffRecorded,
            authorityId,
            uri
        );
    }

    function recordWaiver(
        AVADataTypes.Role actingRole,
        uint256 repaymentObligationId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        id = _recordRecoveryTerminalReceipt(
            actingRole,
            repaymentObligationId,
            AVADataTypes.ValueSettlementKind.Waiver,
            AVADataTypes.ValueSettlementStatus.Waived,
            authorityId,
            uri
        );
    }

    function recordSatisfaction(
        AVADataTypes.Role actingRole,
        uint256 repaymentObligationId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        id = _recordRecoveryTerminalReceipt(
            actingRole,
            repaymentObligationId,
            AVADataTypes.ValueSettlementKind.Satisfaction,
            AVADataTypes.ValueSettlementStatus.Satisfied,
            authorityId,
            uri
        );
    }

    function _recordRecoveryTerminalReceipt(
        AVADataTypes.Role actingRole,
        uint256 repaymentObligationId,
        AVADataTypes.ValueSettlementKind kind,
        AVADataTypes.ValueSettlementStatus status,
        bytes32 authorityId,
        string calldata uri
    ) internal returns (uint256 id) {
        _requireNoSettlementExecutionInProgress();
        _requireSettlementAuthority(actingRole, authorityId, uri);
        id = _recordRecoveryReceipt(actingRole, repaymentObligationId, kind, status, authorityId, uri);
    }

    function _recordRecoveryReceipt(
        AVADataTypes.Role actingRole,
        uint256 repaymentObligationId,
        AVADataTypes.ValueSettlementKind kind,
        AVADataTypes.ValueSettlementStatus status,
        bytes32 authorityId,
        string calldata uri
    ) internal returns (uint256 id) {
        (AVADataTypes.ValueSettlementRecord memory obligation, SourceSnapshot memory source) =
            _requireRecoveryObligation(repaymentObligationId);
        id = _recordLinkedSettlement(
            actingRole,
            source,
            SettlementWriteInput({
                sourceType: AVADataTypes.ExecutionSourceType.ValueSettlementRecord,
                sourceRecordId: repaymentObligationId,
                kind: kind,
                status: status,
                recipient: obligation.recipient,
                originSettlementId: obligation.originSettlementId,
                penaltyConsequenceId: obligation.penaltyConsequenceId,
                repaymentObligationId: repaymentObligationId
            }),
            authorityId,
            uri
        );
        _recordRecoveryTerminal(repaymentObligationId, id, status);
    }

    function getValueSettlement(uint256 id) external view returns (AVADataTypes.ValueSettlementRecord memory) {
        AVADataTypes.ValueSettlementRecord memory settlement = settlements[id];
        if (settlement.id == 0) revert AVADataTypes.UnknownReference(id);
        return settlement;
    }

    function computeSettlementContextHash(SettlementContextInput memory input) public pure returns (bytes32) {
        if (
            input.sourceType == AVADataTypes.ExecutionSourceType.None || input.sourceRecordId == 0
                || input.recognisedStateId == 0 || input.packageId == 0 || input.subjectId == bytes32(0)
                || input.asset == address(0) || input.payer == address(0) || input.recipient == address(0)
                || input.amountOrUnits == 0 || input.sourceExecutionMode == AVADataTypes.ValueExecutionMode.None
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
                input.recognisedStateId,
                input.packageId,
                input.subjectId,
                input.sourceExecutionMode,
                input.sourceSettlementKind,
                input.sourceExecutionReference
            )
        );
        bytes32 valueHash = keccak256(abi.encode(input.asset, input.payer, input.recipient, input.amountOrUnits));
        bytes32 receiptHash = keccak256(
            abi.encode(
                input.settlementKind,
                input.status,
                input.originSettlementId,
                input.penaltyConsequenceId,
                input.repaymentObligationId
            )
        );
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
        return _recordLinkedSettlement(
            actingRole,
            source,
            SettlementWriteInput({
                sourceType: sourceType,
                sourceRecordId: sourceRecordId,
                kind: kind,
                status: status,
                recipient: recipient,
                originSettlementId: 0,
                penaltyConsequenceId: 0,
                repaymentObligationId: 0
            }),
            authorityId,
            uri
        );
    }

    function _recordLinkedSettlement(
        AVADataTypes.Role actingRole,
        SourceSnapshot memory source,
        SettlementWriteInput memory input,
        bytes32 authorityId,
        string calldata uri
    ) internal returns (uint256 id) {
        _requireSettlementAuthority(actingRole, authorityId, uri);
        if (input.recipient == address(0)) {
            revert AVADataTypes.EmptyValue();
        }
        bytes32 settlementContextHash = _settlementContextHash(
            input.sourceType,
            input.sourceRecordId,
            source,
            input.kind,
            input.status,
            input.recipient,
            input.originSettlementId,
            input.penaltyConsequenceId,
            input.repaymentObligationId
        );
        if (settlementContextHash == bytes32(0)) revert AVADataTypes.EmptyValue();

        id = nextValueSettlementId++;
        settlements[id] = AVADataTypes.ValueSettlementRecord({
            id: id,
            sourceType: input.sourceType,
            sourceRecordId: input.sourceRecordId,
            recognisedStateId: source.recognisedStateId,
            packageId: source.packageId,
            kind: input.kind,
            status: input.status,
            asset: source.asset,
            payer: source.payer,
            recipient: input.recipient,
            subjectId: source.subjectId,
            amountOrUnits: source.amountOrUnits,
            sourceExecutionMode: source.executionMode,
            sourceSettlementKind: source.settlementKind,
            sourceExecutionReference: source.executionReference,
            originSettlementId: input.originSettlementId,
            penaltyConsequenceId: input.penaltyConsequenceId,
            repaymentObligationId: input.repaymentObligationId,
            settlementContextHash: settlementContextHash,
            authorityRole: actingRole,
            authorityId: authorityId,
            uri: uri,
            executedBy: msg.sender
        });
        bytes32 key = _sourceKey(input.sourceType, input.sourceRecordId);
        settlementStatusBySourceKey[key] = input.status;
        latestSettlementIdBySourceKey[key] = id;
        _advanceStandingRevisionIfRelevant(source, input.kind, id);
        emit ValueSettlementRecorded(id, input.sourceType, input.sourceRecordId, input.kind, input.status);
    }

    function _advanceStandingRevisionIfRelevant(
        SourceSnapshot memory source,
        AVADataTypes.ValueSettlementKind kind,
        uint256 settlementId
    ) internal {
        AVADataTypes.StandingRevisionReason reason;
        if (
            kind == AVADataTypes.ValueSettlementKind.TokenTransfer
                || kind == AVADataTypes.ValueSettlementKind.EscrowClaim
        ) {
            reason = AVADataTypes.StandingRevisionReason.RewardSettlement;
        } else if (
            kind == AVADataTypes.ValueSettlementKind.ClawbackTransfer
                || kind == AVADataTypes.ValueSettlementKind.RepaymentObligation
                || kind == AVADataTypes.ValueSettlementKind.FuturePayoutSetoff
                || kind == AVADataTypes.ValueSettlementKind.Waiver
                || kind == AVADataTypes.ValueSettlementKind.Satisfaction
        ) {
            reason = AVADataTypes.StandingRevisionReason.RecoverySettlement;
        } else {
            return;
        }
        standingRevisionRegistry.advanceRevision(source.packageId, source.subjectId, reason, settlementId);
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
            _requireCurrentAllocationSource(allocation, settlementKind);
            source = SourceSnapshot({
                recognisedStateId: allocation.recognisedStateId,
                evidenceReceiptId: allocation.evidenceReceiptId,
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
            _requireCurrentConsequenceSource(consequence, settlementKind);
            source = SourceSnapshot({
                recognisedStateId: consequence.recognisedStateId,
                evidenceReceiptId: consequence.evidenceReceiptId,
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
                || source.executionMode != requiredMode || !_settlementKindAllows(source.settlementKind, settlementKind)
        ) {
            revert AVADataTypes.InvalidState(sourceRecordId);
        }
        if (settlementKind != AVADataTypes.ValueSettlementKind.EscrowRefund) {
            authorityMatrix.requireKnownActiveSubject(source.subjectId);
        }
    }

    function _requireRecoveryPenalty(uint256 penaltyConsequenceId)
        internal
        view
        returns (AVADataTypes.ConsequenceRecord memory penalty, SourceSnapshot memory source)
    {
        penalty = consequenceExecutor.getConsequence(penaltyConsequenceId);
        if (
            penalty.kind != AVADataTypes.ConsequenceKind.PenaltyRecord || penalty.challengeId == 0
                || penalty.findingKind == AVADataTypes.GovernanceFindingKind.None || penalty.originSettlementId == 0
                || penalty.executionMode != AVADataTypes.ValueExecutionMode.Claim
                || penalty.settlementKind != AVADataTypes.ValueSettlementKind.ClawbackTransfer
        ) {
            revert AVADataTypes.InvalidState(penaltyConsequenceId);
        }
        _requireCurrentConsequenceSource(penalty, AVADataTypes.ValueSettlementKind.ClawbackTransfer);
        source = SourceSnapshot({
            recognisedStateId: penalty.recognisedStateId,
            evidenceReceiptId: penalty.evidenceReceiptId,
            packageId: penalty.packageId,
            subjectId: penalty.subjectId,
            asset: penalty.asset,
            payer: penalty.payer,
            amountOrUnits: penalty.amountOrUnits,
            executionMode: penalty.executionMode,
            settlementKind: penalty.settlementKind,
            executionReference: penalty.executionReference
        });
        if (
            source.packageId == 0 || source.subjectId == bytes32(0) || source.asset == address(0)
                || source.payer == address(0) || source.amountOrUnits == 0 || source.executionReference == bytes32(0)
        ) {
            revert AVADataTypes.InvalidState(penaltyConsequenceId);
        }
        authorityMatrix.requireKnownActiveSubject(source.subjectId);
    }

    function _requireCurrentAllocationSource(
        AVADataTypes.AllocationExecutionRecord memory allocation,
        AVADataTypes.ValueSettlementKind requestedKind
    ) internal view {
        AVADataTypes.RecognisedStateRecord memory state =
            allocationExecutor.stateMachine().getRecognisedState(allocation.recognisedStateId);
        if (state.packageId != allocation.packageId) revert AVADataTypes.InvalidState(allocation.id);
        if (requestedKind == AVADataTypes.ValueSettlementKind.EscrowRefund) return;
        AVARulePackageRegistry.RulePackage memory rulePackage =
            allocationExecutor.rulePackageRegistry().getRulePackageById(allocation.packageId);
        if (
            (allocation.allocationKind == AVADataTypes.AllocationKind.RewardValueRecord
                    || allocation.allocationKind == AVADataTypes.AllocationKind.AdministrativeQueueRecord)
                && state.status != AVADataTypes.RecognisedStateStatus.Vested
                && state.status != AVADataTypes.RecognisedStateStatus.Restored
        ) {
            revert AVADataTypes.InvalidState(allocation.recognisedStateId);
        }
        AVADataTypes.EvidenceReceipt memory stateEvidence = allocationExecutor.evidenceRegistry()
            .requireUsableEvidenceReceipt(state.evidenceReceiptId, state.appId, state.workflowKey);
        AVADataTypes.EvidenceReceipt memory sourceEvidence = allocationExecutor.evidenceRegistry()
            .requireUsableEvidenceReceipt(allocation.evidenceReceiptId, state.appId, state.workflowKey);
        if (stateEvidence.packageId != state.packageId || sourceEvidence.packageId != allocation.packageId) {
            revert AVADataTypes.InvalidState(allocation.evidenceReceiptId);
        }
        _validateEvidenceLifecycle(rulePackage, state.evidenceReceiptId);
        if (allocation.evidenceReceiptId != state.evidenceReceiptId) {
            _validateEvidenceLifecycle(rulePackage, allocation.evidenceReceiptId);
        }
    }

    function _requireCurrentConsequenceSource(
        AVADataTypes.ConsequenceRecord memory consequence,
        AVADataTypes.ValueSettlementKind requestedKind
    ) internal view {
        (AVAStateMachine consequenceStateMachine,,) = consequenceExecutor.consequenceSubstrate();
        consequenceStateMachine.getRecognisedState(consequence.recognisedStateId);
        if (requestedKind == AVADataTypes.ValueSettlementKind.EscrowRefund) return;
        _requireCurrentConsequenceEvidence(consequence.packageId, consequence.evidenceReceiptId);
    }

    function _requireCurrentConsequenceEvidence(uint256 packageId, uint256 evidenceReceiptId) internal view {
        (
            ,
            AVARulePackageRegistry consequenceRulePackageRegistry,
            EvidenceCommitmentRegistry consequenceEvidenceRegistry
        ) = consequenceExecutor.consequenceSubstrate();
        AVARulePackageRegistry.RulePackage memory rulePackage =
            consequenceRulePackageRegistry.getRulePackageById(packageId);
        AVADataTypes.EvidenceReceipt memory sourceEvidence = consequenceEvidenceRegistry.requireUsableEvidenceReceipt(
            evidenceReceiptId, rulePackage.appId, rulePackage.workflowKey
        );
        if (sourceEvidence.packageId != packageId) {
            revert AVADataTypes.InvalidState(evidenceReceiptId);
        }
        _validateEvidenceLifecycle(rulePackage, evidenceReceiptId);
    }

    function _validateEvidenceLifecycle(
        AVARulePackageRegistry.RulePackage memory rulePackage,
        uint256 evidenceReceiptId
    ) internal view {
        rulePackage.evidenceLifecycleModule
            .validateEvidenceLifecycle(
                rulePackage.workflowKey,
                AVADataTypes.Action.ExecuteValueSettlement,
                evidenceReceiptId,
                AVADataTypes.EvidenceLifecycleKind.None,
                0,
                bytes32(0),
                msg.sender
            );
    }

    function _requireCompletedOriginSettlement(
        AVADataTypes.ConsequenceRecord memory penalty,
        SourceSnapshot memory source
    ) internal view returns (AVADataTypes.ValueSettlementRecord memory origin) {
        origin = settlements[penalty.originSettlementId];
        if (origin.id == 0) revert AVADataTypes.UnknownReference(penalty.originSettlementId);
        bool completedTokenTransfer = origin.kind == AVADataTypes.ValueSettlementKind.TokenTransfer
            && origin.status == AVADataTypes.ValueSettlementStatus.Settled;
        bool completedEscrowClaim = origin.kind == AVADataTypes.ValueSettlementKind.EscrowClaim
            && origin.status == AVADataTypes.ValueSettlementStatus.Claimed;
        if (
            (!completedTokenTransfer && !completedEscrowClaim) || origin.packageId != source.packageId
                || origin.recognisedStateId != source.recognisedStateId || origin.subjectId != source.subjectId
                || origin.asset != source.asset || origin.payer != source.payer
                || origin.amountOrUnits != source.amountOrUnits
        ) {
            revert AVADataTypes.InvalidState(penalty.originSettlementId);
        }
    }

    function _requireRecoveryObligation(uint256 repaymentObligationId)
        internal
        view
        returns (AVADataTypes.ValueSettlementRecord memory obligation, SourceSnapshot memory source)
    {
        obligation = settlements[repaymentObligationId];
        if (
            obligation.id == 0 || obligation.kind != AVADataTypes.ValueSettlementKind.RepaymentObligation
                || obligation.status != AVADataTypes.ValueSettlementStatus.ObligationRecorded
                || obligation.originSettlementId == 0 || obligation.penaltyConsequenceId == 0
                || repaymentObligationIdByOriginSettlementId[obligation.originSettlementId] != repaymentObligationId
                || recoveryTerminalStatusByObligationId[repaymentObligationId]
                    != AVADataTypes.ValueSettlementStatus.None
        ) {
            revert AVADataTypes.InvalidState(repaymentObligationId);
        }
        AVADataTypes.ConsequenceRecord memory penalty =
            consequenceExecutor.getConsequence(obligation.penaltyConsequenceId);
        source = SourceSnapshot({
            recognisedStateId: penalty.recognisedStateId,
            evidenceReceiptId: penalty.evidenceReceiptId,
            packageId: obligation.packageId,
            subjectId: obligation.subjectId,
            asset: obligation.asset,
            payer: obligation.payer,
            amountOrUnits: obligation.amountOrUnits,
            executionMode: obligation.sourceExecutionMode,
            settlementKind: obligation.sourceSettlementKind,
            executionReference: obligation.sourceExecutionReference
        });
        _requireCompletedOriginSettlement(penalty, source);
    }

    function _requireAllocationSource(
        AVADataTypes.ExecutionSourceType sourceType,
        uint256 sourceRecordId,
        AVADataTypes.AllocationKind allocationKind
    ) internal view {
        if (sourceType != AVADataTypes.ExecutionSourceType.AllocationRecord) {
            revert AVADataTypes.InvalidState(sourceRecordId);
        }
        AVADataTypes.AllocationExecutionRecord memory allocation =
            allocationExecutor.getAllocationExecution(sourceRecordId);
        if (allocation.allocationKind != allocationKind) revert AVADataTypes.InvalidState(sourceRecordId);
    }

    function _requireSettlementAuthority(AVADataTypes.Role actingRole, bytes32 authorityId, string calldata uri)
        internal
        view
    {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.ExecuteValueSettlement, authorityId
        );
        if (authorityId == bytes32(0) || bytes(uri).length == 0) {
            revert AVADataTypes.EmptyValue();
        }
    }

    function _requireUnusedFinalSource(AVADataTypes.ExecutionSourceType sourceType, uint256 sourceRecordId)
        internal
        view
    {
        AVADataTypes.ValueSettlementStatus status = settlementStatusBySourceKey[_sourceKey(sourceType, sourceRecordId)];
        if (status != AVADataTypes.ValueSettlementStatus.None) revert AVADataTypes.InvalidState(sourceRecordId);
    }

    function _requireEscrowDeposited(AVADataTypes.ExecutionSourceType sourceType, uint256 sourceRecordId)
        internal
        view
    {
        AVADataTypes.ValueSettlementStatus status = settlementStatusBySourceKey[_sourceKey(sourceType, sourceRecordId)];
        if (status != AVADataTypes.ValueSettlementStatus.Deposited) revert AVADataTypes.InvalidState(sourceRecordId);
    }

    function _recordRecoveryTerminal(
        uint256 repaymentObligationId,
        uint256 settlementId,
        AVADataTypes.ValueSettlementStatus status
    ) internal {
        recoveryTerminalStatusByObligationId[repaymentObligationId] = status;
        recoveryTerminalSettlementIdByObligationId[repaymentObligationId] = settlementId;
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

    function _settlementKindAllows(
        AVADataTypes.ValueSettlementKind storedKind,
        AVADataTypes.ValueSettlementKind requestedKind
    ) internal pure returns (bool) {
        if (storedKind == requestedKind) return true;
        return storedKind == AVADataTypes.ValueSettlementKind.EscrowDeposit
            && (requestedKind == AVADataTypes.ValueSettlementKind.EscrowClaim
                || requestedKind == AVADataTypes.ValueSettlementKind.EscrowRefund);
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
        address recipient,
        uint256 originSettlementId,
        uint256 penaltyConsequenceId,
        uint256 repaymentObligationId
    ) internal pure returns (bytes32) {
        SettlementContextInput memory input;
        input.sourceType = sourceType;
        input.sourceRecordId = sourceRecordId;
        input.recognisedStateId = source.recognisedStateId;
        input.packageId = source.packageId;
        input.subjectId = source.subjectId;
        input.asset = source.asset;
        input.payer = source.payer;
        input.recipient = recipient;
        input.amountOrUnits = source.amountOrUnits;
        input.sourceExecutionMode = source.executionMode;
        input.sourceSettlementKind = source.settlementKind;
        input.sourceExecutionReference = source.executionReference;
        input.originSettlementId = originSettlementId;
        input.penaltyConsequenceId = penaltyConsequenceId;
        input.repaymentObligationId = repaymentObligationId;
        input.settlementKind = kind;
        input.status = status;
        return computeSettlementContextHash(input);
    }
}
