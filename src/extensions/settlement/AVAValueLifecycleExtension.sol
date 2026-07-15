// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVAAuthorityMatrix} from "../../core/AVAAuthorityMatrix.sol";
import {AVACapabilityKeys} from "../../core/AVACapabilityKeys.sol";
import {AVACoreRulePackageRegistry} from "../../core/AVACoreRulePackageRegistry.sol";
import {AVACoreTypes} from "../../core/AVACoreTypes.sol";
import {AVADisclosurePolicyRegistry} from "../../core/AVADisclosurePolicyRegistry.sol";
import {AVAEvidenceRegistry} from "../../core/AVAEvidenceRegistry.sol";
import {AVAGovernanceKernel} from "../../core/AVAGovernanceKernel.sol";
import {AVAIdentityRegistry} from "../../core/AVAIdentityRegistry.sol";
import {
    AVARewardPriorityExtension,
    AVAPenaltyRestorationExtension
} from "../governance/AVABoundedGovernanceExtensions.sol";
import {AVAExtensionRecordBase} from "../shared/AVAExtensionRecordBase.sol";
import {DefaultAVAExtensionPolicyModule} from "../shared/DefaultAVAExtensionPolicyModule.sol";
import {IAVAStandingRevision} from "../standing/IAVAStandingRevision.sol";

contract DefaultAVAValueExecutionPolicyModule is DefaultAVAExtensionPolicyModule {}

contract AVAValueLifecycleExtension is AVAExtensionRecordBase {
    enum ValueSourceKind {
        None,
        Reward,
        AdministrativePriority
    }

    enum RewardLifecycleKind {
        None,
        Freeze,
        Vest,
        Void,
        Restore
    }

    enum RewardLifecycleStatus {
        None,
        Granted,
        Frozen,
        Vested,
        Voided,
        Restored
    }

    enum RecoveryOutcome {
        None,
        Clawback,
        Setoff,
        Waiver,
        Satisfaction
    }

    struct RewardLifecycleInput {
        uint256 rewardId;
        bytes32 roleKey;
        bytes32 authorityId;
        RewardLifecycleKind kind;
        bytes32 reasonHash;
        string uri;
    }

    struct RewardLifecycleRecord {
        uint256 id;
        uint256 rewardId;
        bytes32 appId;
        uint256 packageId;
        bytes32 subjectId;
        RewardLifecycleKind kind;
        RewardLifecycleStatus fromStatus;
        RewardLifecycleStatus toStatus;
        uint256 evidenceId;
        bytes32 authorityId;
        bytes32 reasonHash;
        string uri;
        address recordedBy;
        uint64 recordedAt;
    }

    struct ValueSettlementInput {
        ValueSourceKind sourceKind;
        uint256 sourceId;
        bytes32 roleKey;
        bytes32 authorityId;
        bytes32 settlementKindKey;
        uint256 units;
        bytes32 referenceHash;
        string uri;
    }

    struct ValueSettlementRecord {
        uint256 id;
        ValueSourceKind sourceKind;
        uint256 sourceId;
        uint256 recognisedStateId;
        uint256 recognisedStateTransitionId;
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 subjectId;
        uint256 evidenceId;
        bytes32 settlementKindKey;
        uint256 units;
        bytes32 referenceHash;
        bytes32 authorityId;
        string uri;
        address recordedBy;
        uint64 recordedAt;
    }

    struct RepaymentObligationInput {
        uint256 originSettlementId;
        uint256 penaltyId;
        bytes32 roleKey;
        bytes32 authorityId;
        uint256 units;
        bytes32 reasonHash;
        string uri;
    }

    struct RepaymentObligationRecord {
        uint256 id;
        uint256 originSettlementId;
        uint256 penaltyId;
        bytes32 appId;
        uint256 packageId;
        bytes32 subjectId;
        uint256 evidenceId;
        uint256 units;
        bytes32 authorityId;
        bytes32 reasonHash;
        string uri;
        address recordedBy;
        uint64 recordedAt;
    }

    struct RecoveryOutcomeInput {
        uint256 obligationId;
        bytes32 roleKey;
        bytes32 authorityId;
        RecoveryOutcome outcome;
        bytes32 referenceHash;
        string uri;
    }

    struct RecoveryOutcomeRecord {
        uint256 id;
        uint256 obligationId;
        uint256 originSettlementId;
        uint256 penaltyId;
        bytes32 appId;
        uint256 packageId;
        bytes32 subjectId;
        uint256 evidenceId;
        uint256 units;
        RecoveryOutcome outcome;
        bytes32 referenceHash;
        bytes32 authorityId;
        string uri;
        address recordedBy;
        uint64 recordedAt;
    }

    struct SourceSnapshot {
        uint256 sourceId;
        uint256 recognisedStateId;
        uint256 recognisedStateTransitionId;
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 subjectId;
        uint256 evidenceId;
        bytes32 kindKey;
        uint256 units;
        bytes32 sourceTypeKey;
    }

    bytes32 private constant REWARD_SOURCE_TYPE = keccak256("ava.extension.reward-record-source.v1");
    bytes32 private constant PRIORITY_SOURCE_TYPE =
        keccak256("ava.extension.administrative-priority-record-source.v1");
    bytes32 private constant SETTLEMENT_SOURCE_TYPE = keccak256("ava.extension.value-settlement-source.v1");
    bytes32 private constant OBLIGATION_SOURCE_TYPE = keccak256("ava.extension.repayment-obligation-source.v1");
    bytes32 private constant REWARD_SETTLEMENT_REVISION = keccak256("ava.standing-revision.reward-settlement.v1");
    bytes32 private constant REWARD_LIFECYCLE_REVISION = keccak256("ava.standing-revision.reward-lifecycle.v1");
    bytes32 private constant REPAYMENT_OBLIGATION_REVISION =
        keccak256("ava.standing-revision.repayment-obligation.v1");
    bytes32 private constant RECOVERY_REVISION = keccak256("ava.standing-revision.recovery-outcome.v1");

    AVARewardPriorityExtension public immutable REWARD_PRIORITY_EXTENSION;
    AVAPenaltyRestorationExtension public immutable PENALTY_EXTENSION;
    IAVAStandingRevision public immutable REVISION_REGISTRY;

    mapping(uint256 => RewardLifecycleRecord) private rewardLifecycleRecords;
    mapping(uint256 => ValueSettlementRecord) private settlements;
    mapping(uint256 => RepaymentObligationRecord) private obligations;
    mapping(uint256 => RecoveryOutcomeRecord) private recoveryOutcomes;
    mapping(uint256 => RewardLifecycleStatus) public rewardLifecycleStatus;
    mapping(bytes32 => uint256) public settlementIdBySource;
    mapping(uint256 => uint256) public obligationIdByOriginSettlement;
    mapping(uint256 => uint256) public recoveryOutcomeIdByObligation;
    uint256 public nextRewardLifecycleRecordId = 1;
    uint256 public nextSettlementId = 1;
    uint256 public nextObligationId = 1;
    uint256 public nextRecoveryOutcomeId = 1;

    event RewardLifecycleRecorded(
        uint256 indexed recordId,
        uint256 indexed rewardId,
        RewardLifecycleKind indexed kind,
        RewardLifecycleStatus fromStatus,
        RewardLifecycleStatus toStatus,
        address recordedBy
    );
    event ValueSettlementRecorded(
        uint256 indexed settlementId,
        ValueSourceKind indexed sourceKind,
        uint256 indexed sourceId,
        bytes32 subjectId,
        uint256 packageId,
        uint256 units,
        address recordedBy
    );
    event RepaymentObligationRecorded(
        uint256 indexed obligationId,
        uint256 indexed originSettlementId,
        uint256 indexed penaltyId,
        bytes32 subjectId,
        uint256 units,
        address recordedBy
    );
    event RecoveryOutcomeRecorded(
        uint256 indexed outcomeId,
        uint256 indexed obligationId,
        RecoveryOutcome indexed outcome,
        bytes32 subjectId,
        address recordedBy
    );

    constructor(
        AVAGovernanceKernel governanceKernel_,
        AVAAuthorityMatrix authorityMatrix_,
        AVAIdentityRegistry identityRegistry_,
        AVACoreRulePackageRegistry rulePackageRegistry_,
        AVAEvidenceRegistry evidenceRegistry_,
        AVADisclosurePolicyRegistry disclosureRegistry_,
        AVARewardPriorityExtension rewardPriorityExtension_,
        AVAPenaltyRestorationExtension penaltyExtension_,
        IAVAStandingRevision revisionRegistry_
    )
        AVAExtensionRecordBase(
            governanceKernel_,
            authorityMatrix_,
            identityRegistry_,
            rulePackageRegistry_,
            evidenceRegistry_,
            disclosureRegistry_
        )
    {
        if (
            address(rewardPriorityExtension_) == address(0) || address(penaltyExtension_) == address(0)
                || address(revisionRegistry_) == address(0) || address(revisionRegistry_).code.length == 0
        ) revert AVACoreTypes.EmptyValue();
        if (
            address(rewardPriorityExtension_.GOVERNANCE_KERNEL()) != address(governanceKernel_)
                || address(penaltyExtension_.GOVERNANCE_KERNEL()) != address(governanceKernel_)
                || address(revisionRegistry_.GOVERNANCE_KERNEL()) != address(governanceKernel_)
        ) revert AVACoreTypes.InvalidState(0);
        REWARD_PRIORITY_EXTENSION = rewardPriorityExtension_;
        PENALTY_EXTENSION = penaltyExtension_;
        REVISION_REGISTRY = revisionRegistry_;
    }

    function recordRewardLifecycle(RewardLifecycleInput calldata input) external returns (uint256 recordId) {
        if (
            input.rewardId == 0 || input.kind == RewardLifecycleKind.None || input.roleKey == bytes32(0)
                || input.authorityId == bytes32(0) || input.reasonHash == bytes32(0)
        ) revert AVACoreTypes.EmptyValue();
        SourceSnapshot memory source = _rewardSource(input.rewardId);
        RewardLifecycleStatus fromStatus = rewardLifecycleStatus[input.rewardId];
        if (fromStatus == RewardLifecycleStatus.None) fromStatus = RewardLifecycleStatus.Granted;
        RewardLifecycleStatus toStatus = _nextRewardStatus(fromStatus, input.kind);
        _validateRewardLifecycleSource(source, input);
        recordId = nextRewardLifecycleRecordId++;
        rewardLifecycleRecords[recordId] = RewardLifecycleRecord({
            id: recordId,
            rewardId: source.sourceId,
            appId: source.appId,
            packageId: source.packageId,
            subjectId: source.subjectId,
            kind: input.kind,
            fromStatus: fromStatus,
            toStatus: toStatus,
            evidenceId: source.evidenceId,
            authorityId: input.authorityId,
            reasonHash: input.reasonHash,
            uri: input.uri,
            recordedBy: msg.sender,
            recordedAt: uint64(block.timestamp)
        });
        rewardLifecycleStatus[input.rewardId] = toStatus;
        REVISION_REGISTRY.advanceRevision(
            source.appId, source.packageId, source.subjectId, REWARD_LIFECYCLE_REVISION, recordId
        );
        emit RewardLifecycleRecorded(recordId, source.sourceId, input.kind, fromStatus, toStatus, msg.sender);
    }

    function recordValueSettlement(ValueSettlementInput calldata input) external returns (uint256 settlementId) {
        if (
            input.sourceKind == ValueSourceKind.None || input.sourceId == 0 || input.settlementKindKey == bytes32(0)
                || input.units == 0 || input.referenceHash == bytes32(0)
        ) revert AVACoreTypes.EmptyValue();
        SourceSnapshot memory source = input.sourceKind == ValueSourceKind.Reward
            ? _rewardSource(input.sourceId)
            : _prioritySource(input.sourceId);
        if (source.units != input.units) revert AVACoreTypes.InvalidState(input.sourceId);
        if (input.sourceKind == ValueSourceKind.Reward) {
            RewardLifecycleStatus status = rewardLifecycleStatus[input.sourceId];
            if (status != RewardLifecycleStatus.Vested && status != RewardLifecycleStatus.Restored) {
                revert AVACoreTypes.InvalidState(input.sourceId);
            }
        }
        bytes32 sourceKey = keccak256(abi.encode(input.sourceKind, input.sourceId));
        if (settlementIdBySource[sourceKey] != 0) {
            revert AVACoreTypes.InvalidState(settlementIdBySource[sourceKey]);
        }
        _validateSettlementSource(source, input);
        settlementId = nextSettlementId++;
        settlements[settlementId] = ValueSettlementRecord({
            id: settlementId,
            sourceKind: input.sourceKind,
            sourceId: source.sourceId,
            recognisedStateId: source.recognisedStateId,
            recognisedStateTransitionId: source.recognisedStateTransitionId,
            appId: source.appId,
            workflowKey: source.workflowKey,
            packageId: source.packageId,
            subjectId: source.subjectId,
            evidenceId: source.evidenceId,
            settlementKindKey: input.settlementKindKey,
            units: input.units,
            referenceHash: input.referenceHash,
            authorityId: input.authorityId,
            uri: input.uri,
            recordedBy: msg.sender,
            recordedAt: uint64(block.timestamp)
        });
        settlementIdBySource[sourceKey] = settlementId;
        if (input.sourceKind == ValueSourceKind.Reward) {
            REVISION_REGISTRY.advanceRevision(
                source.appId, source.packageId, source.subjectId, REWARD_SETTLEMENT_REVISION, settlementId
            );
        }
        emit ValueSettlementRecorded(
            settlementId, input.sourceKind, source.sourceId, source.subjectId, source.packageId, input.units, msg.sender
        );
    }

    function recordRepaymentObligation(RepaymentObligationInput calldata input)
        external
        returns (uint256 obligationId)
    {
        if (
            input.originSettlementId == 0 || input.penaltyId == 0 || input.units == 0
                || input.reasonHash == bytes32(0)
        ) revert AVACoreTypes.EmptyValue();
        ValueSettlementRecord memory origin = _settlement(input.originSettlementId);
        AVAPenaltyRestorationExtension.PenaltyRecord memory penalty = PENALTY_EXTENSION.getPenalty(input.penaltyId);
        if (
            origin.sourceKind != ValueSourceKind.Reward || origin.appId != penalty.appId
                || origin.packageId != penalty.packageId || origin.subjectId != penalty.subjectId
                || origin.recognisedStateId != penalty.recognisedStateId || origin.evidenceId != penalty.evidenceId
                || origin.units != input.units
                || obligationIdByOriginSettlement[origin.id] != 0
        ) revert AVACoreTypes.InvalidState(input.originSettlementId);
        SourceSnapshot memory source = _settlementSource(origin);
        _validateHistoricalSource(
            source,
            input.roleKey,
            input.authorityId,
            AVACoreTypes.ACTION_RECORD_REPAYMENT_OBLIGATION,
            source.kindKey,
            PENALTY_EXTENSION_SOURCE_TYPE(),
            penalty.id,
            input.reasonHash,
            input.units,
            true
        );
        obligationId = nextObligationId++;
        obligations[obligationId] = RepaymentObligationRecord({
            id: obligationId,
            originSettlementId: origin.id,
            penaltyId: penalty.id,
            appId: origin.appId,
            packageId: origin.packageId,
            subjectId: origin.subjectId,
            evidenceId: origin.evidenceId,
            units: input.units,
            authorityId: input.authorityId,
            reasonHash: input.reasonHash,
            uri: input.uri,
            recordedBy: msg.sender,
            recordedAt: uint64(block.timestamp)
        });
        obligationIdByOriginSettlement[origin.id] = obligationId;
        REVISION_REGISTRY.advanceRevision(
            origin.appId, origin.packageId, origin.subjectId, REPAYMENT_OBLIGATION_REVISION, obligationId
        );
        emit RepaymentObligationRecorded(
            obligationId, origin.id, penalty.id, origin.subjectId, input.units, msg.sender
        );
    }

    function recordRecoveryOutcome(RecoveryOutcomeInput calldata input) external returns (uint256 outcomeId) {
        if (
            input.obligationId == 0 || input.outcome == RecoveryOutcome.None || input.referenceHash == bytes32(0)
        ) revert AVACoreTypes.EmptyValue();
        RepaymentObligationRecord memory obligation = _obligation(input.obligationId);
        if (recoveryOutcomeIdByObligation[obligation.id] != 0) {
            revert AVACoreTypes.InvalidState(recoveryOutcomeIdByObligation[obligation.id]);
        }
        ValueSettlementRecord memory origin = _settlement(obligation.originSettlementId);
        SourceSnapshot memory source = _settlementSource(origin);
        _validateHistoricalSource(
            source,
            input.roleKey,
            input.authorityId,
            AVACoreTypes.ACTION_RECORD_RECOVERY_OUTCOME,
            source.kindKey,
            OBLIGATION_SOURCE_TYPE,
            obligation.id,
            input.referenceHash,
            obligation.units,
            input.outcome == RecoveryOutcome.Clawback
        );
        outcomeId = nextRecoveryOutcomeId++;
        recoveryOutcomes[outcomeId] = RecoveryOutcomeRecord({
            id: outcomeId,
            obligationId: obligation.id,
            originSettlementId: obligation.originSettlementId,
            penaltyId: obligation.penaltyId,
            appId: obligation.appId,
            packageId: obligation.packageId,
            subjectId: obligation.subjectId,
            evidenceId: obligation.evidenceId,
            units: obligation.units,
            outcome: input.outcome,
            referenceHash: input.referenceHash,
            authorityId: input.authorityId,
            uri: input.uri,
            recordedBy: msg.sender,
            recordedAt: uint64(block.timestamp)
        });
        recoveryOutcomeIdByObligation[obligation.id] = outcomeId;
        REVISION_REGISTRY.advanceRevision(
            obligation.appId, obligation.packageId, obligation.subjectId, RECOVERY_REVISION, outcomeId
        );
        emit RecoveryOutcomeRecorded(outcomeId, obligation.id, input.outcome, obligation.subjectId, msg.sender);
    }

    function getRewardLifecycleRecord(uint256 recordId)
        external
        view
        returns (RewardLifecycleRecord memory record)
    {
        record = rewardLifecycleRecords[recordId];
        if (record.id == 0) revert AVACoreTypes.UnknownReference(recordId);
    }

    function getValueSettlement(uint256 settlementId) external view returns (ValueSettlementRecord memory) {
        return _settlement(settlementId);
    }

    function getRepaymentObligation(uint256 obligationId) external view returns (RepaymentObligationRecord memory) {
        return _obligation(obligationId);
    }

    function getRecoveryOutcome(uint256 outcomeId) external view returns (RecoveryOutcomeRecord memory record) {
        record = recoveryOutcomes[outcomeId];
        if (record.id == 0) revert AVACoreTypes.UnknownReference(outcomeId);
    }

    function PENALTY_EXTENSION_SOURCE_TYPE() public pure returns (bytes32) {
        return keccak256("ava.extension.penalty-record-source.v1");
    }

    function _rewardSource(uint256 rewardId) private view returns (SourceSnapshot memory source) {
        AVARewardPriorityExtension.RewardRecord memory reward = REWARD_PRIORITY_EXTENSION.getReward(rewardId);
        source = SourceSnapshot({
            sourceId: reward.id,
            recognisedStateId: reward.recognisedStateId,
            recognisedStateTransitionId: reward.recognisedStateTransitionId,
            appId: reward.appId,
            workflowKey: reward.workflowKey,
            packageId: reward.packageId,
            subjectId: reward.subjectId,
            evidenceId: reward.evidenceId,
            kindKey: reward.kindKey,
            units: reward.units,
            sourceTypeKey: REWARD_SOURCE_TYPE
        });
    }

    function _prioritySource(uint256 priorityId) private view returns (SourceSnapshot memory source) {
        AVARewardPriorityExtension.PriorityRecord memory priority = REWARD_PRIORITY_EXTENSION.getPriority(priorityId);
        source = SourceSnapshot({
            sourceId: priority.id,
            recognisedStateId: priority.recognisedStateId,
            recognisedStateTransitionId: priority.recognisedStateTransitionId,
            appId: priority.appId,
            workflowKey: priority.workflowKey,
            packageId: priority.packageId,
            subjectId: priority.subjectId,
            evidenceId: priority.evidenceId,
            kindKey: priority.kindKey,
            units: priority.units,
            sourceTypeKey: PRIORITY_SOURCE_TYPE
        });
    }

    function _settlementSource(ValueSettlementRecord memory settlement)
        private
        pure
        returns (SourceSnapshot memory source)
    {
        source = SourceSnapshot({
            sourceId: settlement.id,
            recognisedStateId: settlement.recognisedStateId,
            recognisedStateTransitionId: settlement.recognisedStateTransitionId,
            appId: settlement.appId,
            workflowKey: settlement.workflowKey,
            packageId: settlement.packageId,
            subjectId: settlement.subjectId,
            evidenceId: settlement.evidenceId,
            kindKey: settlement.settlementKindKey,
            units: settlement.units,
            sourceTypeKey: SETTLEMENT_SOURCE_TYPE
        });
    }

    function _validateCurrentSource(
        SourceSnapshot memory source,
        bytes32 roleKey,
        bytes32 authorityId,
        bytes32 actionKey,
        bytes32 recordTypeKey,
        bytes32 payloadHash,
        uint256 units
    ) private view {
        AVACoreTypes.RecognisedStateRecord memory state = GOVERNANCE_KERNEL.getRecognisedState(source.recognisedStateId);
        if (
            state.appId != source.appId || state.workflowKey != source.workflowKey || state.packageId != source.packageId
                || state.subjectId != source.subjectId || state.evidenceReceiptId != source.evidenceId
                || state.lastTransitionId != source.recognisedStateTransitionId
        ) revert AVACoreTypes.InvalidState(source.recognisedStateId);
        _validateExtension(
            ExtensionValidationInput({
                recognisedStateId: source.recognisedStateId,
                roleKey: roleKey,
                authorityId: authorityId,
                subjectId: source.subjectId,
                evidenceId: source.evidenceId,
                capabilityKey: AVACapabilityKeys.VALUE_EXECUTION,
                actionKey: actionKey,
                recordTypeKey: recordTypeKey,
                scopeKey: source.kindKey,
                sourceTypeKey: source.sourceTypeKey,
                sourceRecordId: source.sourceId,
                unsignedValue: units,
                validUntil: 0,
                payloadHash: payloadHash,
                requireActiveSubject: true,
                contextHash: _contextHash(source, actionKey, recordTypeKey, payloadHash)
            })
        );
    }

    function _validateRewardLifecycleSource(
        SourceSnapshot memory source,
        RewardLifecycleInput calldata input
    ) private view {
        bytes32 lifecycleKind = bytes32(uint256(uint8(input.kind)));
        if (input.kind == RewardLifecycleKind.Vest) {
            _validateCurrentSource(
                source,
                input.roleKey,
                input.authorityId,
                AVACoreTypes.ACTION_RECORD_REWARD_LIFECYCLE,
                lifecycleKind,
                input.reasonHash,
                0
            );
            return;
        }
        AVACoreTypes.RecognisedStateRecord memory state =
            GOVERNANCE_KERNEL.getRecognisedState(source.recognisedStateId);
        if (
            input.kind == RewardLifecycleKind.Restore
                && state.status != AVACoreTypes.RecognisedStateStatus.Restored
        ) revert AVACoreTypes.InvalidState(source.recognisedStateId);
        _validateHistoricalSource(
            source,
            input.roleKey,
            input.authorityId,
            AVACoreTypes.ACTION_RECORD_REWARD_LIFECYCLE,
            lifecycleKind,
            source.sourceTypeKey,
            source.sourceId,
            input.reasonHash,
            0,
            input.kind == RewardLifecycleKind.Restore
        );
    }

    function _validateSettlementSource(SourceSnapshot memory source, ValueSettlementInput calldata input)
        private
        view
    {
        if (
            input.sourceKind == ValueSourceKind.Reward
                && rewardLifecycleStatus[input.sourceId] == RewardLifecycleStatus.Restored
        ) {
            AVACoreTypes.RecognisedStateRecord memory state =
                GOVERNANCE_KERNEL.getRecognisedState(source.recognisedStateId);
            if (state.status != AVACoreTypes.RecognisedStateStatus.Restored) {
                revert AVACoreTypes.InvalidState(source.recognisedStateId);
            }
            _validateHistoricalSource(
                source,
                input.roleKey,
                input.authorityId,
                AVACoreTypes.ACTION_RECORD_VALUE_SETTLEMENT,
                input.settlementKindKey,
                source.sourceTypeKey,
                source.sourceId,
                input.referenceHash,
                input.units,
                true
            );
            return;
        }
        _validateCurrentSource(
            source,
            input.roleKey,
            input.authorityId,
            AVACoreTypes.ACTION_RECORD_VALUE_SETTLEMENT,
            input.settlementKindKey,
            input.referenceHash,
            input.units
        );
    }

    function _validateHistoricalSource(
        SourceSnapshot memory source,
        bytes32 roleKey,
        bytes32 authorityId,
        bytes32 actionKey,
        bytes32 recordTypeKey,
        bytes32 sourceTypeKey,
        uint256 sourceRecordId,
        bytes32 payloadHash,
        uint256 units,
        bool requireActiveReferences
    ) private view {
        AVACoreTypes.RecognisedStateRecord memory state = GOVERNANCE_KERNEL.getRecognisedState(source.recognisedStateId);
        if (
            state.appId != source.appId || state.packageId != source.packageId || state.subjectId != source.subjectId
                || state.evidenceReceiptId != source.evidenceId
        ) revert AVACoreTypes.InvalidState(source.recognisedStateId);
        SourceSnapshot memory validationSource = source;
        validationSource.sourceTypeKey = sourceTypeKey;
        validationSource.sourceId = sourceRecordId;
        ExtensionValidationInput memory validationInput = ExtensionValidationInput({
                recognisedStateId: source.recognisedStateId,
                roleKey: roleKey,
                authorityId: authorityId,
                subjectId: source.subjectId,
                evidenceId: source.evidenceId,
                capabilityKey: AVACapabilityKeys.VALUE_EXECUTION,
                actionKey: actionKey,
                recordTypeKey: recordTypeKey,
                scopeKey: source.kindKey,
                sourceTypeKey: sourceTypeKey,
                sourceRecordId: sourceRecordId,
                unsignedValue: units,
                validUntil: 0,
                payloadHash: payloadHash,
                requireActiveSubject: requireActiveReferences,
                contextHash: _contextHash(validationSource, actionKey, recordTypeKey, payloadHash)
            });
        if (requireActiveReferences) {
            _validateExtension(validationInput);
        } else {
            _validateExtensionForDefensiveCloseout(validationInput);
        }
    }

    function _contextHash(
        SourceSnapshot memory source,
        bytes32 actionKey,
        bytes32 recordTypeKey,
        bytes32 payloadHash
    ) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                source.appId,
                source.packageId,
                source.recognisedStateId,
                source.recognisedStateTransitionId,
                source.subjectId,
                source.sourceTypeKey,
                source.sourceId,
                actionKey,
                recordTypeKey,
                payloadHash
            )
        );
    }

    function _nextRewardStatus(RewardLifecycleStatus fromStatus, RewardLifecycleKind kind)
        private
        pure
        returns (RewardLifecycleStatus)
    {
        if (kind == RewardLifecycleKind.Freeze && fromStatus == RewardLifecycleStatus.Granted) {
            return RewardLifecycleStatus.Frozen;
        }
        if (
            kind == RewardLifecycleKind.Vest
                && (fromStatus == RewardLifecycleStatus.Granted || fromStatus == RewardLifecycleStatus.Frozen)
        ) return RewardLifecycleStatus.Vested;
        if (
            kind == RewardLifecycleKind.Void
                && (fromStatus == RewardLifecycleStatus.Granted || fromStatus == RewardLifecycleStatus.Frozen
                    || fromStatus == RewardLifecycleStatus.Vested)
        ) return RewardLifecycleStatus.Voided;
        if (kind == RewardLifecycleKind.Restore && fromStatus == RewardLifecycleStatus.Voided) {
            return RewardLifecycleStatus.Restored;
        }
        revert AVACoreTypes.InvalidState(uint256(fromStatus));
    }

    function _settlement(uint256 settlementId) private view returns (ValueSettlementRecord memory record) {
        record = settlements[settlementId];
        if (record.id == 0) revert AVACoreTypes.UnknownReference(settlementId);
    }

    function _obligation(uint256 obligationId) private view returns (RepaymentObligationRecord memory record) {
        record = obligations[obligationId];
        if (record.id == 0) revert AVACoreTypes.UnknownReference(obligationId);
    }
}
