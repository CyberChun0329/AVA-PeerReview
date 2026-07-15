// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVACoreTypes} from "../../core/AVACoreTypes.sol";
import {AVAEvidenceRegistry} from "../../core/AVAEvidenceRegistry.sol";
import {AVAGovernanceKernel} from "../../core/AVAGovernanceKernel.sol";
import {AVAChallengeExtension} from "../challenge/AVAChallengeExtension.sol";
import {IAVADownstreamRecordSource} from "../downstream/IAVADownstreamRecordSource.sol";
import {IAVASettlementReceiptSource} from "../settlement/IAVASettlementReceiptSource.sol";

enum AVAExternalOperationTargetKind {
    None,
    RecognisedState,
    Challenge,
    EvidenceReceipt,
    AllocationRecord,
    ConsequenceRecord,
    SettlementReceipt
}

interface IAVAExternalOperationTargetResolver {
    struct TargetContext {
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        uint256 recognisedStateId;
        uint256 recognisedStateTransitionId;
        uint256 targetVersionId;
        bytes32 subjectId;
        uint256 evidenceId;
        bytes32 sourceTypeKey;
        uint256 sourceRecordId;
        uint256 units;
    }

    function GOVERNANCE_KERNEL() external view returns (AVAGovernanceKernel);

    function resolveTarget(AVAExternalOperationTargetKind targetKind, uint256 targetId)
        external
        view
        returns (TargetContext memory context);
}

contract AVAExternalOperationTargetResolver is IAVAExternalOperationTargetResolver {
    bytes32 public constant STATE_SOURCE_TYPE = keccak256("ava.core.recognised-state-source.v1");
    bytes32 public constant CHALLENGE_SOURCE_TYPE = keccak256("ava.extension.challenge-source.v1");
    bytes32 public constant EVIDENCE_SOURCE_TYPE = keccak256("ava.core.evidence-receipt-source.v1");

    AVAGovernanceKernel public immutable GOVERNANCE_KERNEL;
    AVAEvidenceRegistry public immutable EVIDENCE_REGISTRY;
    AVAChallengeExtension public immutable CHALLENGE_EXTENSION;
    IAVADownstreamRecordSource public immutable ALLOCATION_SOURCE;
    IAVADownstreamRecordSource public immutable CONSEQUENCE_SOURCE;
    IAVASettlementReceiptSource public immutable SETTLEMENT_SOURCE;

    constructor(
        AVAGovernanceKernel governanceKernel_,
        AVAEvidenceRegistry evidenceRegistry_,
        AVAChallengeExtension challengeExtension_,
        IAVADownstreamRecordSource allocationSource_,
        IAVADownstreamRecordSource consequenceSource_,
        IAVASettlementReceiptSource settlementSource_
    ) {
        if (address(governanceKernel_) == address(0) || address(evidenceRegistry_) == address(0)) {
            revert AVACoreTypes.EmptyValue();
        }
        if (address(governanceKernel_.EVIDENCE_REGISTRY()) != address(evidenceRegistry_)) {
            revert AVACoreTypes.InvalidState(0);
        }
        _requireKernel(address(challengeExtension_), address(governanceKernel_));
        _requireKernel(address(allocationSource_), address(governanceKernel_));
        _requireKernel(address(consequenceSource_), address(governanceKernel_));
        _requireKernel(address(settlementSource_), address(governanceKernel_));
        GOVERNANCE_KERNEL = governanceKernel_;
        EVIDENCE_REGISTRY = evidenceRegistry_;
        CHALLENGE_EXTENSION = challengeExtension_;
        ALLOCATION_SOURCE = allocationSource_;
        CONSEQUENCE_SOURCE = consequenceSource_;
        SETTLEMENT_SOURCE = settlementSource_;
    }

    function resolveTarget(AVAExternalOperationTargetKind targetKind, uint256 targetId)
        external
        view
        returns (TargetContext memory context)
    {
        if (targetKind == AVAExternalOperationTargetKind.None || targetId == 0) {
            revert AVACoreTypes.EmptyValue();
        }
        if (targetKind == AVAExternalOperationTargetKind.RecognisedState) return _stateTarget(targetId);
        if (targetKind == AVAExternalOperationTargetKind.Challenge) return _challengeTarget(targetId);
        if (targetKind == AVAExternalOperationTargetKind.EvidenceReceipt) return _evidenceTarget(targetId);
        if (targetKind == AVAExternalOperationTargetKind.AllocationRecord) {
            return _downstreamTarget(ALLOCATION_SOURCE, targetId);
        }
        if (targetKind == AVAExternalOperationTargetKind.ConsequenceRecord) {
            return _downstreamTarget(CONSEQUENCE_SOURCE, targetId);
        }
        if (targetKind == AVAExternalOperationTargetKind.SettlementReceipt) return _settlementTarget(targetId);
        revert AVACoreTypes.InvalidState(uint256(targetKind));
    }

    function _stateTarget(uint256 stateId) private view returns (TargetContext memory context) {
        AVAGovernanceKernel.RecognisedStateReference memory state =
            GOVERNANCE_KERNEL.getRecognisedStateReference(stateId);
        context = TargetContext({
            appId: state.appId,
            workflowKey: state.workflowKey,
            packageId: state.packageId,
            recognisedStateId: state.id,
            recognisedStateTransitionId: state.lastTransitionId,
            targetVersionId: state.lastTransitionId,
            subjectId: state.subjectId,
            evidenceId: state.evidenceReceiptId,
            sourceTypeKey: STATE_SOURCE_TYPE,
            sourceRecordId: state.id,
            units: 0
        });
    }

    function _challengeTarget(uint256 challengeId) private view returns (TargetContext memory context) {
        if (address(CHALLENGE_EXTENSION) == address(0)) revert AVACoreTypes.InvalidState(challengeId);
        AVAChallengeExtension.ChallengeRecord memory challenge = CHALLENGE_EXTENSION.getChallenge(challengeId);
        AVAGovernanceKernel.RecognisedStateReference memory state =
            GOVERNANCE_KERNEL.getRecognisedStateReference(challenge.challengeRecognisedStateId);
        if (
            state.appId != challenge.appId || state.workflowKey != challenge.workflowKey
                || state.packageId != challenge.packageId || state.subjectId != challenge.challengerSubjectId
                || state.evidenceReceiptId != challenge.evidenceReceiptId
                || state.disclosurePolicyId != challenge.disclosurePolicyId
        ) {
            revert AVACoreTypes.InvalidState(challengeId);
        }
        context = TargetContext({
            appId: challenge.appId,
            workflowKey: challenge.workflowKey,
            packageId: challenge.packageId,
            recognisedStateId: state.id,
            recognisedStateTransitionId: state.lastTransitionId,
            targetVersionId: challenge.lastTransitionId,
            subjectId: challenge.challengerSubjectId,
            evidenceId: challenge.evidenceReceiptId,
            sourceTypeKey: CHALLENGE_SOURCE_TYPE,
            sourceRecordId: challenge.id,
            units: 0
        });
    }

    function _evidenceTarget(uint256 evidenceId) private view returns (TargetContext memory context) {
        AVAEvidenceRegistry.EvidenceReference memory evidence = EVIDENCE_REGISTRY.getEvidenceReference(evidenceId);
        context = TargetContext({
            appId: evidence.appId,
            workflowKey: evidence.workflowKey,
            packageId: evidence.packageId,
            recognisedStateId: 0,
            recognisedStateTransitionId: 0,
            targetVersionId: evidence.lastLifecycleRecordId,
            subjectId: evidence.subjectId,
            evidenceId: evidence.id,
            sourceTypeKey: EVIDENCE_SOURCE_TYPE,
            sourceRecordId: evidence.id,
            units: 0
        });
    }

    function _downstreamTarget(IAVADownstreamRecordSource sourceRegistry, uint256 targetId)
        private
        view
        returns (TargetContext memory context)
    {
        if (address(sourceRegistry) == address(0)) revert AVACoreTypes.InvalidState(targetId);
        IAVADownstreamRecordSource.DownstreamSourceContext memory source =
            sourceRegistry.getDownstreamSource(targetId);
        if (source.id != targetId) revert AVACoreTypes.InvalidState(targetId);
        AVAGovernanceKernel.RecognisedStateReference memory state =
            GOVERNANCE_KERNEL.getRecognisedStateReference(source.recognisedStateId);
        _requireStateSource(state, source);
        context = TargetContext({
            appId: source.appId,
            workflowKey: source.workflowKey,
            packageId: source.packageId,
            recognisedStateId: source.recognisedStateId,
            recognisedStateTransitionId: source.recognisedStateTransitionId,
            targetVersionId: source.recognisedStateTransitionId,
            subjectId: source.subjectId,
            evidenceId: source.evidenceId,
            sourceTypeKey: source.sourceTypeKey,
            sourceRecordId: source.id,
            units: source.units
        });
    }

    function _settlementTarget(uint256 settlementId) private view returns (TargetContext memory context) {
        if (address(SETTLEMENT_SOURCE) == address(0)) revert AVACoreTypes.InvalidState(settlementId);
        IAVASettlementReceiptSource.SettlementSourceContext memory source =
            SETTLEMENT_SOURCE.getSettlementSource(settlementId);
        if (source.id != settlementId) revert AVACoreTypes.InvalidState(settlementId);
        AVAGovernanceKernel.RecognisedStateReference memory state =
            GOVERNANCE_KERNEL.getRecognisedStateReference(source.recognisedStateId);
        if (
            state.appId != source.appId || state.workflowKey != source.workflowKey
                || state.packageId != source.packageId || state.subjectId != source.subjectId
        ) revert AVACoreTypes.InvalidState(settlementId);
        context = TargetContext({
            appId: source.appId,
            workflowKey: source.workflowKey,
            packageId: source.packageId,
            recognisedStateId: source.recognisedStateId,
            recognisedStateTransitionId: source.recognisedStateTransitionId,
            targetVersionId: source.recognisedStateTransitionId,
            subjectId: source.subjectId,
            evidenceId: source.evidenceId,
            sourceTypeKey: source.sourceTypeKey,
            sourceRecordId: source.id,
            units: source.units
        });
    }

    function _requireStateSource(
        AVAGovernanceKernel.RecognisedStateReference memory state,
        IAVADownstreamRecordSource.DownstreamSourceContext memory source
    ) private pure {
        if (
            state.appId != source.appId || state.workflowKey != source.workflowKey
                || state.packageId != source.packageId || state.subjectId != source.subjectId
        ) revert AVACoreTypes.InvalidState(source.id);
    }

    function _requireKernel(address source, address expectedKernel) private view {
        if (source == address(0)) return;
        if (source.code.length == 0) revert AVACoreTypes.InvalidState(0);
        (bool success, bytes memory result) = source.staticcall(abi.encodeWithSignature("GOVERNANCE_KERNEL()"));
        if (!success || result.length != 32 || abi.decode(result, (address)) != expectedKernel) {
            revert AVACoreTypes.InvalidState(0);
        }
    }
}
