// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAVAApplicationModule} from "../../interfaces/IAVAApplicationModule.sol";
import {AVAAuthorityMatrix} from "../../core/AVAAuthorityMatrix.sol";
import {AVACapabilityKeys} from "../../core/AVACapabilityKeys.sol";
import {AVACoreRulePackageRegistry} from "../../core/AVACoreRulePackageRegistry.sol";
import {AVACoreTypes} from "../../core/AVACoreTypes.sol";
import {AVADisclosurePolicyRegistry} from "../../core/AVADisclosurePolicyRegistry.sol";
import {AVAEvidenceRegistry} from "../../core/AVAEvidenceRegistry.sol";
import {AVAGovernanceKernel} from "../../core/AVAGovernanceKernel.sol";
import {AVAIdentityRegistry} from "../../core/AVAIdentityRegistry.sol";
import {IAVAAntiAbusePolicyModule} from "../../core/interfaces/IAVACoreRuleModules.sol";
import {AVAChallengeExtension} from "../challenge/AVAChallengeExtension.sol";
import {IAVADownstreamRecordSource} from "../downstream/IAVADownstreamRecordSource.sol";
import {AVAExtensionRecordBase} from "../shared/AVAExtensionRecordBase.sol";
import {DefaultAVAExtensionPolicyModule} from "../shared/DefaultAVAExtensionPolicyModule.sol";
import {IAVAExtensionPolicyModule} from "../shared/IAVAExtensionPolicyModule.sol";
import {IAVAStandingRevision} from "../standing/IAVAStandingRevision.sol";

interface IAVARewardPolicyModule is IAVAExtensionPolicyModule {}
interface IAVAPriorityPolicyModule is IAVAExtensionPolicyModule {}
interface IAVAPenaltyPolicyModule is IAVAExtensionPolicyModule {}
interface IAVARestorationPolicyModule is IAVAExtensionPolicyModule {}

contract DefaultAVARewardPolicyModule is DefaultAVAExtensionPolicyModule {}
contract DefaultAVAPriorityPolicyModule is DefaultAVAExtensionPolicyModule {}
contract DefaultAVAPenaltyPolicyModule is DefaultAVAExtensionPolicyModule {}
contract DefaultAVARestorationPolicyModule is DefaultAVAExtensionPolicyModule {}

contract AVARewardPriorityExtension is AVAExtensionRecordBase {
    bytes32 public constant ALLOCATION_SOURCE_TYPE = keccak256("ava.extension.allocation-record-source.v1");

    struct RewardPriorityInput {
        uint256 allocationId;
        bytes32 roleKey;
        bytes32 authorityId;
        bytes32 subjectId;
        uint256 evidenceId;
        bytes32 kindKey;
        uint256 units;
        bytes32 reasonHash;
        string uri;
    }

    struct RewardRecord {
        uint256 id;
        uint256 allocationId;
        uint256 recognisedStateId;
        uint256 recognisedStateTransitionId;
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 subjectId;
        uint256 evidenceId;
        bytes32 kindKey;
        uint256 units;
        bytes32 authorityId;
        bytes32 reasonHash;
        string uri;
        address recordedBy;
        uint64 recordedAt;
    }

    struct PriorityRecord {
        uint256 id;
        uint256 allocationId;
        uint256 recognisedStateId;
        uint256 recognisedStateTransitionId;
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 subjectId;
        uint256 evidenceId;
        bytes32 kindKey;
        uint256 units;
        bytes32 authorityId;
        bytes32 reasonHash;
        string uri;
        address recordedBy;
        uint64 recordedAt;
    }

    IAVADownstreamRecordSource public immutable ALLOCATION_SOURCE;
    mapping(uint256 => RewardRecord) private rewards;
    mapping(uint256 => PriorityRecord) private priorities;
    mapping(bytes32 => uint256) public rewardIdBySource;
    mapping(bytes32 => uint256) public priorityIdBySource;
    uint256 public nextRewardId = 1;
    uint256 public nextPriorityId = 1;

    event RewardRecorded(
        uint256 indexed rewardId,
        uint256 indexed allocationId,
        bytes32 indexed subjectId,
        uint256 packageId,
        bytes32 kindKey,
        uint256 units,
        address recordedBy
    );
    event AdministrativePriorityRecorded(
        uint256 indexed priorityId,
        uint256 indexed allocationId,
        bytes32 indexed subjectId,
        uint256 packageId,
        bytes32 kindKey,
        uint256 units,
        address recordedBy
    );

    constructor(
        AVAGovernanceKernel governanceKernel_,
        AVAAuthorityMatrix authorityMatrix_,
        AVAIdentityRegistry identityRegistry_,
        AVACoreRulePackageRegistry rulePackageRegistry_,
        AVAEvidenceRegistry evidenceRegistry_,
        AVADisclosurePolicyRegistry disclosureRegistry_,
        IAVADownstreamRecordSource allocationSource_
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
        if (address(allocationSource_) == address(0) || address(allocationSource_).code.length == 0) {
            revert AVACoreTypes.EmptyValue();
        }
        if (address(allocationSource_.GOVERNANCE_KERNEL()) != address(governanceKernel_)) {
            revert AVACoreTypes.InvalidState(0);
        }
        ALLOCATION_SOURCE = allocationSource_;
    }

    function recordReward(RewardPriorityInput calldata input) external returns (uint256 rewardId) {
        IAVADownstreamRecordSource.DownstreamSourceContext memory source = _validateInput(
            input, AVACapabilityKeys.REWARD, AVACoreTypes.ACTION_RECORD_REWARD
        );
        bytes32 sourceKey = keccak256(abi.encode(address(ALLOCATION_SOURCE), input.allocationId));
        if (rewardIdBySource[sourceKey] != 0) revert AVACoreTypes.InvalidState(rewardIdBySource[sourceKey]);
        rewardId = nextRewardId++;
        rewards[rewardId] = RewardRecord({
            id: rewardId,
            allocationId: source.id,
            recognisedStateId: source.recognisedStateId,
            recognisedStateTransitionId: source.recognisedStateTransitionId,
            appId: source.appId,
            workflowKey: source.workflowKey,
            packageId: source.packageId,
            subjectId: source.subjectId,
            evidenceId: source.evidenceId,
            kindKey: input.kindKey,
            units: input.units,
            authorityId: input.authorityId,
            reasonHash: input.reasonHash,
            uri: input.uri,
            recordedBy: msg.sender,
            recordedAt: uint64(block.timestamp)
        });
        rewardIdBySource[sourceKey] = rewardId;
        emit RewardRecorded(
            rewardId, source.id, source.subjectId, source.packageId, input.kindKey, input.units, msg.sender
        );
    }

    function recordAdministrativePriority(RewardPriorityInput calldata input) external returns (uint256 priorityId) {
        IAVADownstreamRecordSource.DownstreamSourceContext memory source = _validateInput(
            input, AVACapabilityKeys.PRIORITY, AVACoreTypes.ACTION_RECORD_ADMINISTRATIVE_PRIORITY
        );
        bytes32 sourceKey = keccak256(abi.encode(address(ALLOCATION_SOURCE), input.allocationId));
        if (priorityIdBySource[sourceKey] != 0) revert AVACoreTypes.InvalidState(priorityIdBySource[sourceKey]);
        priorityId = nextPriorityId++;
        priorities[priorityId] = PriorityRecord({
            id: priorityId,
            allocationId: source.id,
            recognisedStateId: source.recognisedStateId,
            recognisedStateTransitionId: source.recognisedStateTransitionId,
            appId: source.appId,
            workflowKey: source.workflowKey,
            packageId: source.packageId,
            subjectId: source.subjectId,
            evidenceId: source.evidenceId,
            kindKey: input.kindKey,
            units: input.units,
            authorityId: input.authorityId,
            reasonHash: input.reasonHash,
            uri: input.uri,
            recordedBy: msg.sender,
            recordedAt: uint64(block.timestamp)
        });
        priorityIdBySource[sourceKey] = priorityId;
        emit AdministrativePriorityRecorded(
            priorityId, source.id, source.subjectId, source.packageId, input.kindKey, input.units, msg.sender
        );
    }

    function getReward(uint256 rewardId) external view returns (RewardRecord memory record) {
        record = rewards[rewardId];
        if (record.id == 0) revert AVACoreTypes.UnknownReference(rewardId);
    }

    function getPriority(uint256 priorityId) external view returns (PriorityRecord memory record) {
        record = priorities[priorityId];
        if (record.id == 0) revert AVACoreTypes.UnknownReference(priorityId);
    }

    function _validateInput(RewardPriorityInput calldata input, bytes32 capabilityKey, bytes32 actionKey)
        private
        view
        returns (IAVADownstreamRecordSource.DownstreamSourceContext memory source)
    {
        if (
            input.allocationId == 0 || input.kindKey == bytes32(0) || input.units == 0
                || input.reasonHash == bytes32(0)
        ) revert AVACoreTypes.EmptyValue();
        source = ALLOCATION_SOURCE.getDownstreamSource(input.allocationId);
        if (
            source.id != input.allocationId || source.sourceTypeKey != ALLOCATION_SOURCE_TYPE
                || source.subjectId != input.subjectId || source.evidenceId != input.evidenceId
                || source.units != input.units
        ) revert AVACoreTypes.InvalidState(input.allocationId);
        AVACoreTypes.RecognisedStateRecord memory state = GOVERNANCE_KERNEL.getRecognisedState(source.recognisedStateId);
        if (
            state.appId != source.appId || state.workflowKey != source.workflowKey || state.packageId != source.packageId
                || state.subjectId != source.subjectId || state.lastTransitionId != source.recognisedStateTransitionId
                || (state.status != AVACoreTypes.RecognisedStateStatus.Vested
                    && state.status != AVACoreTypes.RecognisedStateStatus.Restored)
        ) revert AVACoreTypes.InvalidState(source.recognisedStateId);
        bytes32 contextHash = keccak256(
            abi.encode(
                capabilityKey,
                actionKey,
                source.packageId,
                source.id,
                source.recognisedStateTransitionId,
                input.kindKey,
                input.units,
                input.reasonHash
            )
        );
        _validateExtension(
            ExtensionValidationInput({
                recognisedStateId: source.recognisedStateId,
                roleKey: input.roleKey,
                authorityId: input.authorityId,
                subjectId: input.subjectId,
                evidenceId: input.evidenceId,
                capabilityKey: capabilityKey,
                actionKey: actionKey,
                recordTypeKey: input.kindKey,
                scopeKey: source.recordTypeKey,
                sourceTypeKey: source.sourceTypeKey,
                sourceRecordId: source.id,
                unsignedValue: input.units,
                validUntil: 0,
                payloadHash: input.reasonHash,
                requireActiveSubject: true,
                contextHash: contextHash
            })
        );
    }
}

contract AVAPenaltyRestorationExtension {
    bytes32 private constant PENALTY_SOURCE_TYPE = keccak256("ava.extension.penalty-record-source.v1");
    bytes32 private constant CHALLENGE_TRANSITION_SOURCE =
        keccak256("ava.extension.challenge-transition-source.v1");
    bytes32 private constant STANDING_PENALTY_SOURCE = keccak256("ava.extension.standing-penalty-input.v1");
    bytes32 private constant ELIGIBILITY_SOURCE = keccak256("ava.extension.eligibility-restriction.v1");

    struct PenaltyInput {
        uint256 challengeTransitionId;
        bytes32 roleKey;
        bytes32 authorityId;
        bytes32 findingKey;
        bytes32 reasonHash;
        string uri;
    }

    struct PenaltyRecord {
        uint256 id;
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        uint256 targetPackageId;
        uint256 recognisedStateId;
        uint256 recognisedStateTransitionId;
        uint256 challengeId;
        uint256 challengeTransitionId;
        AVAChallengeExtension.ChallengeOutcome outcome;
        bytes32 subjectId;
        uint256 evidenceId;
        bytes32 findingKey;
        bytes32 authorityId;
        bytes32 reasonHash;
        string uri;
        address recordedBy;
        uint64 recordedAt;
    }

    struct StandingPenaltyInput {
        uint256 penaltyId;
        bytes32 roleKey;
        bytes32 authorityId;
        bytes32 dimensionKey;
        int256 delta;
        bytes32 reasonHash;
        string uri;
    }

    struct StandingPenaltyInputRecord {
        uint256 id;
        uint256 penaltyId;
        bytes32 appId;
        uint256 packageId;
        bytes32 subjectId;
        bytes32 dimensionKey;
        int256 delta;
        uint256 evidenceId;
        bytes32 authorityId;
        bytes32 reasonHash;
        string uri;
        address recordedBy;
        uint64 recordedAt;
    }

    struct EligibilityRestrictionInput {
        uint256 penaltyId;
        bytes32 roleKey;
        bytes32 authorityId;
        bytes32 restrictionKey;
        uint64 expiresAt;
        bytes32 reasonHash;
        string uri;
    }

    struct EligibilityRestrictionRecord {
        uint256 id;
        uint256 penaltyId;
        bytes32 appId;
        uint256 packageId;
        bytes32 subjectId;
        bytes32 restrictionKey;
        uint64 expiresAt;
        uint256 evidenceId;
        bytes32 authorityId;
        bytes32 reasonHash;
        string uri;
        address recordedBy;
        uint64 recordedAt;
    }

    struct RestorationInput {
        uint256 challengeTransitionId;
        bytes32 roleKey;
        bytes32 authorityId;
        bytes32 reasonHash;
        string uri;
    }

    struct RestorationRecord {
        uint256 id;
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        uint256 recognisedStateId;
        uint256 recognisedStateTransitionId;
        uint256 challengeId;
        uint256 challengeTransitionId;
        bytes32 subjectId;
        uint256 evidenceId;
        bytes32 authorityId;
        bytes32 reasonHash;
        string uri;
        address recordedBy;
        uint64 recordedAt;
    }

    struct DecisionValidationInput {
        uint256 packageId;
        bytes32 subjectId;
        uint256 evidenceId;
        bytes32 roleKey;
        bytes32 authorityId;
        bytes32 capabilityKey;
        bytes32 actionKey;
        bytes32 recordTypeKey;
        bytes32 scopeKey;
        bytes32 sourceTypeKey;
        uint256 sourceRecordId;
        uint256 unsignedValue;
        bytes32 reasonHash;
        uint64 validUntil;
        bool allowInactiveReferences;
    }

    struct DecisionModules {
        AVACoreRulePackageRegistry.VerifiedPackageContext rulePackage;
        IAVAApplicationModule application;
        IAVAExtensionPolicyModule policy;
        IAVAAntiAbusePolicyModule antiAbuse;
    }

    AVAGovernanceKernel public immutable GOVERNANCE_KERNEL;
    AVAAuthorityMatrix public immutable AUTHORITY_MATRIX;
    AVAIdentityRegistry public immutable IDENTITY_REGISTRY;
    AVACoreRulePackageRegistry public immutable RULE_PACKAGE_REGISTRY;
    AVAEvidenceRegistry public immutable EVIDENCE_REGISTRY;
    AVADisclosurePolicyRegistry public immutable DISCLOSURE_REGISTRY;
    AVAChallengeExtension public immutable CHALLENGE_EXTENSION;
    IAVAStandingRevision public immutable REVISION_REGISTRY;

    mapping(uint256 => PenaltyRecord) private penalties;
    mapping(uint256 => StandingPenaltyInputRecord) private standingPenaltyInputs;
    mapping(uint256 => EligibilityRestrictionRecord) private eligibilityRestrictions;
    mapping(uint256 => RestorationRecord) private restorations;
    mapping(bytes32 => uint256) public penaltyIdByChallengeSubject;
    mapping(bytes32 => uint256) public standingPenaltyIdByPenaltyDimension;
    mapping(bytes32 => uint256) public restrictionIdByPenaltyKind;
    mapping(uint256 => uint256) public restorationIdByChallenge;
    uint256 public nextPenaltyId = 1;
    uint256 public nextStandingPenaltyInputId = 1;
    uint256 public nextEligibilityRestrictionId = 1;
    uint256 public nextRestorationId = 1;
    uint256 public constant MAX_ABSOLUTE_STANDING_PENALTY_DELTA = 1_000_000;
    uint64 public constant MAX_ELIGIBILITY_RESTRICTION_DURATION = 365 days;

    event PenaltyRecorded(
        uint256 indexed penaltyId,
        uint256 indexed challengeId,
        bytes32 indexed subjectId,
        uint256 packageId,
        bytes32 findingKey,
        AVAChallengeExtension.ChallengeOutcome outcome,
        address recordedBy
    );
    event StandingPenaltyInputRecorded(
        uint256 indexed recordId,
        uint256 indexed penaltyId,
        bytes32 indexed subjectId,
        bytes32 dimensionKey,
        int256 delta,
        address recordedBy
    );
    event EligibilityRestrictionRecorded(
        uint256 indexed recordId,
        uint256 indexed penaltyId,
        bytes32 indexed subjectId,
        bytes32 restrictionKey,
        uint64 expiresAt,
        address recordedBy
    );
    event RestorationRecorded(
        uint256 indexed restorationId,
        uint256 indexed challengeId,
        uint256 indexed recognisedStateId,
        uint256 packageId,
        address recordedBy
    );

    constructor(
        AVAGovernanceKernel governanceKernel_,
        AVAAuthorityMatrix authorityMatrix_,
        AVAIdentityRegistry identityRegistry_,
        AVACoreRulePackageRegistry rulePackageRegistry_,
        AVAEvidenceRegistry evidenceRegistry_,
        AVADisclosurePolicyRegistry disclosureRegistry_,
        AVAChallengeExtension challengeExtension_,
        IAVAStandingRevision revisionRegistry_
    ) {
        if (
            address(governanceKernel_) == address(0) || address(authorityMatrix_) == address(0)
                || address(identityRegistry_) == address(0) || address(rulePackageRegistry_) == address(0)
                || address(evidenceRegistry_) == address(0) || address(disclosureRegistry_) == address(0)
                || address(challengeExtension_) == address(0) || address(revisionRegistry_) == address(0)
                || address(revisionRegistry_).code.length == 0
        ) revert AVACoreTypes.EmptyValue();
        if (
            address(governanceKernel_.AUTHORITY_MATRIX()) != address(authorityMatrix_)
                || address(governanceKernel_.IDENTITY_REGISTRY()) != address(identityRegistry_)
                || address(governanceKernel_.RULE_PACKAGE_REGISTRY()) != address(rulePackageRegistry_)
                || address(governanceKernel_.EVIDENCE_REGISTRY()) != address(evidenceRegistry_)
                || address(governanceKernel_.DISCLOSURE_REGISTRY()) != address(disclosureRegistry_)
                || address(challengeExtension_.GOVERNANCE_KERNEL()) != address(governanceKernel_)
                || address(revisionRegistry_.GOVERNANCE_KERNEL()) != address(governanceKernel_)
        ) revert AVACoreTypes.InvalidState(0);
        GOVERNANCE_KERNEL = governanceKernel_;
        AUTHORITY_MATRIX = authorityMatrix_;
        IDENTITY_REGISTRY = identityRegistry_;
        RULE_PACKAGE_REGISTRY = rulePackageRegistry_;
        EVIDENCE_REGISTRY = evidenceRegistry_;
        DISCLOSURE_REGISTRY = disclosureRegistry_;
        CHALLENGE_EXTENSION = challengeExtension_;
        REVISION_REGISTRY = revisionRegistry_;
    }

    function recordPenalty(PenaltyInput calldata input) external returns (uint256 penaltyId) {
        if (
            input.challengeTransitionId == 0 || input.roleKey == bytes32(0) || input.authorityId == bytes32(0)
                || input.findingKey == bytes32(0) || input.reasonHash == bytes32(0)
        ) revert AVACoreTypes.EmptyValue();
        (PenaltyRecord memory record, bytes32 penaltyKey) = _preparePenalty(input);
        penaltyId = nextPenaltyId++;
        record.id = penaltyId;
        record.recordedBy = msg.sender;
        record.recordedAt = uint64(block.timestamp);
        penalties[penaltyId] = record;
        penaltyIdByChallengeSubject[penaltyKey] = penaltyId;
        emit PenaltyRecorded(
            penaltyId,
            record.challengeId,
            record.subjectId,
            record.packageId,
            record.findingKey,
            record.outcome,
            msg.sender
        );
    }

    function _preparePenalty(PenaltyInput calldata input)
        private
        view
        returns (PenaltyRecord memory record, bytes32 penaltyKey)
    {
        AVAChallengeExtension.ChallengeTransitionRecord memory transition =
            CHALLENGE_EXTENSION.getChallengeTransition(input.challengeTransitionId);
        if (
            transition.kind != AVAChallengeExtension.ChallengeTransitionKind.Resolution
                || transition.outcome == AVAChallengeExtension.ChallengeOutcome.None
                || transition.outcome == AVAChallengeExtension.ChallengeOutcome.RejectedGoodFaith
        ) revert AVACoreTypes.InvalidState(input.challengeTransitionId);
        AVAChallengeExtension.ChallengeRecord memory challenge = CHALLENGE_EXTENSION.getChallenge(transition.challengeId);
        AVACoreTypes.RecognisedStateRecord memory targetState =
            GOVERNANCE_KERNEL.getRecognisedState(challenge.challengedRecognisedStateId);
        bool targetFinding = transition.outcome == AVAChallengeExtension.ChallengeOutcome.Upheld;
        AVACoreTypes.RecognisedStateRecord memory state = targetFinding
            ? targetState
            : GOVERNANCE_KERNEL.getRecognisedState(challenge.challengeRecognisedStateId);
        uint256 decisionPackageId = targetFinding ? challenge.targetPackageId : challenge.packageId;
        bytes32 subjectId = state.subjectId;
        uint256 evidenceId = state.evidenceReceiptId;
        if (
            challenge.outcome != transition.outcome
                || challenge.targetTransitionIdAfterResolution != transition.targetTransitionIdAfter
                || (targetFinding && targetState.lastTransitionId != transition.targetTransitionIdAfter)
                || transition.packageId != challenge.packageId || transition.targetPackageId != challenge.targetPackageId
                || state.packageId != decisionPackageId
                || (!targetFinding
                    && (state.subjectId != challenge.challengerSubjectId
                        || state.evidenceReceiptId != challenge.evidenceReceiptId
                        || state.lastTransitionId != challenge.challengeStateTransitionIdAfterResolution))
                || (challenge.status != AVAChallengeExtension.ChallengeStatus.Resolved
                    && challenge.status != AVAChallengeExtension.ChallengeStatus.RestorationAvailable
                    && challenge.status != AVAChallengeExtension.ChallengeStatus.Closed)
        ) revert AVACoreTypes.InvalidState(input.challengeTransitionId);
        penaltyKey = keccak256(abi.encode(challenge.id, subjectId));
        if (penaltyIdByChallengeSubject[penaltyKey] != 0) {
            revert AVACoreTypes.InvalidState(penaltyIdByChallengeSubject[penaltyKey]);
        }
        DecisionValidationInput memory validation;
        validation.packageId = decisionPackageId;
        validation.subjectId = subjectId;
        validation.evidenceId = evidenceId;
        validation.roleKey = input.roleKey;
        validation.authorityId = input.authorityId;
        validation.capabilityKey = AVACapabilityKeys.PENALTY;
        validation.actionKey = AVACoreTypes.ACTION_RECORD_PENALTY;
        validation.recordTypeKey = input.findingKey;
        validation.scopeKey = bytes32(uint256(uint8(transition.outcome)));
        validation.sourceTypeKey = CHALLENGE_TRANSITION_SOURCE;
        validation.sourceRecordId = transition.id;
        validation.reasonHash = input.reasonHash;
        validation.allowInactiveReferences = targetFinding;
        AVACoreRulePackageRegistry.VerifiedPackageContext memory rulePackage =
            _validateDecisionRecord(state, validation);
        record = PenaltyRecord({
            id: 0,
            appId: state.appId,
            workflowKey: rulePackage.workflowKey,
            packageId: decisionPackageId,
            targetPackageId: challenge.targetPackageId,
            recognisedStateId: state.id,
            recognisedStateTransitionId: state.lastTransitionId,
            challengeId: challenge.id,
            challengeTransitionId: transition.id,
            outcome: transition.outcome,
            subjectId: subjectId,
            evidenceId: evidenceId,
            findingKey: input.findingKey,
            authorityId: input.authorityId,
            reasonHash: input.reasonHash,
            uri: input.uri,
            recordedBy: address(0),
            recordedAt: 0
        });
    }

    function recordStandingPenaltyInput(StandingPenaltyInput calldata input) external returns (uint256 recordId) {
        if (
            input.penaltyId == 0 || input.dimensionKey == bytes32(0) || input.delta >= 0
                || input.delta < -int256(MAX_ABSOLUTE_STANDING_PENALTY_DELTA)
                || input.reasonHash == bytes32(0)
        ) revert AVACoreTypes.EmptyValue();
        PenaltyRecord memory penalty = _penalty(input.penaltyId);
        bytes32 inputKey = keccak256(abi.encode(penalty.id, input.dimensionKey));
        if (standingPenaltyIdByPenaltyDimension[inputKey] != 0) {
            revert AVACoreTypes.InvalidState(standingPenaltyIdByPenaltyDimension[inputKey]);
        }
        AVACoreTypes.RecognisedStateRecord memory state = GOVERNANCE_KERNEL.getRecognisedState(penalty.recognisedStateId);
        _requireCurrentPenaltyStateVersion(state, penalty);
        DecisionValidationInput memory validation;
        validation.packageId = penalty.packageId;
        validation.subjectId = penalty.subjectId;
        validation.evidenceId = penalty.evidenceId;
        validation.roleKey = input.roleKey;
        validation.authorityId = input.authorityId;
        validation.capabilityKey = AVACapabilityKeys.PENALTY;
        validation.actionKey = AVACoreTypes.ACTION_RECORD_STANDING_PENALTY_INPUT;
        validation.recordTypeKey = input.dimensionKey;
        validation.sourceTypeKey = PENALTY_SOURCE_TYPE;
        validation.sourceRecordId = penalty.id;
        validation.unsignedValue = uint256(-input.delta);
        validation.reasonHash = input.reasonHash;
        validation.allowInactiveReferences = penalty.outcome == AVAChallengeExtension.ChallengeOutcome.Upheld;
        _validateDecisionRecord(state, validation);
        recordId = nextStandingPenaltyInputId++;
        standingPenaltyInputs[recordId] = StandingPenaltyInputRecord({
            id: recordId,
            penaltyId: penalty.id,
            appId: penalty.appId,
            packageId: penalty.packageId,
            subjectId: penalty.subjectId,
            dimensionKey: input.dimensionKey,
            delta: input.delta,
            evidenceId: penalty.evidenceId,
            authorityId: input.authorityId,
            reasonHash: input.reasonHash,
            uri: input.uri,
            recordedBy: msg.sender,
            recordedAt: uint64(block.timestamp)
        });
        standingPenaltyIdByPenaltyDimension[inputKey] = recordId;
        REVISION_REGISTRY.advanceRevision(penalty.appId, penalty.packageId, penalty.subjectId, STANDING_PENALTY_SOURCE, recordId);
        emit StandingPenaltyInputRecorded(
            recordId, penalty.id, penalty.subjectId, input.dimensionKey, input.delta, msg.sender
        );
    }

    function recordEligibilityRestriction(EligibilityRestrictionInput calldata input)
        external
        returns (uint256 recordId)
    {
        if (
            input.penaltyId == 0 || input.restrictionKey == bytes32(0) || input.expiresAt <= block.timestamp
                || input.expiresAt > block.timestamp + MAX_ELIGIBILITY_RESTRICTION_DURATION
                || input.reasonHash == bytes32(0)
        ) revert AVACoreTypes.EmptyValue();
        PenaltyRecord memory penalty = _penalty(input.penaltyId);
        bytes32 inputKey = keccak256(abi.encode(penalty.id, input.restrictionKey));
        if (restrictionIdByPenaltyKind[inputKey] != 0) {
            revert AVACoreTypes.InvalidState(restrictionIdByPenaltyKind[inputKey]);
        }
        AVACoreTypes.RecognisedStateRecord memory state = GOVERNANCE_KERNEL.getRecognisedState(penalty.recognisedStateId);
        _requireCurrentPenaltyStateVersion(state, penalty);
        DecisionValidationInput memory validation;
        validation.packageId = penalty.packageId;
        validation.subjectId = penalty.subjectId;
        validation.evidenceId = penalty.evidenceId;
        validation.roleKey = input.roleKey;
        validation.authorityId = input.authorityId;
        validation.capabilityKey = AVACapabilityKeys.PENALTY;
        validation.actionKey = AVACoreTypes.ACTION_RECORD_ELIGIBILITY_RESTRICTION;
        validation.recordTypeKey = input.restrictionKey;
        validation.sourceTypeKey = PENALTY_SOURCE_TYPE;
        validation.sourceRecordId = penalty.id;
        validation.reasonHash = input.reasonHash;
        validation.validUntil = input.expiresAt;
        validation.allowInactiveReferences = penalty.outcome == AVAChallengeExtension.ChallengeOutcome.Upheld;
        _validateDecisionRecord(state, validation);
        recordId = nextEligibilityRestrictionId++;
        eligibilityRestrictions[recordId] = EligibilityRestrictionRecord({
            id: recordId,
            penaltyId: penalty.id,
            appId: penalty.appId,
            packageId: penalty.packageId,
            subjectId: penalty.subjectId,
            restrictionKey: input.restrictionKey,
            expiresAt: input.expiresAt,
            evidenceId: penalty.evidenceId,
            authorityId: input.authorityId,
            reasonHash: input.reasonHash,
            uri: input.uri,
            recordedBy: msg.sender,
            recordedAt: uint64(block.timestamp)
        });
        restrictionIdByPenaltyKind[inputKey] = recordId;
        REVISION_REGISTRY.advanceRevision(penalty.appId, penalty.packageId, penalty.subjectId, ELIGIBILITY_SOURCE, recordId);
        emit EligibilityRestrictionRecorded(
            recordId, penalty.id, penalty.subjectId, input.restrictionKey, input.expiresAt, msg.sender
        );
    }

    function recordRestoration(RestorationInput calldata input) external returns (uint256 restorationId) {
        if (
            input.challengeTransitionId == 0 || input.roleKey == bytes32(0) || input.authorityId == bytes32(0)
                || input.reasonHash == bytes32(0)
        ) revert AVACoreTypes.EmptyValue();
        AVAChallengeExtension.ChallengeTransitionRecord memory transition =
            CHALLENGE_EXTENSION.getChallengeTransition(input.challengeTransitionId);
        if (transition.kind != AVAChallengeExtension.ChallengeTransitionKind.Restoration) {
            revert AVACoreTypes.InvalidState(input.challengeTransitionId);
        }
        AVAChallengeExtension.ChallengeRecord memory challenge = CHALLENGE_EXTENSION.getChallenge(transition.challengeId);
        AVACoreTypes.RecognisedStateRecord memory state =
            GOVERNANCE_KERNEL.getRecognisedState(challenge.challengedRecognisedStateId);
        if (
            challenge.status != AVAChallengeExtension.ChallengeStatus.Closed || challenge.lastTransitionId != transition.id
                || state.lastTransitionId != transition.targetTransitionIdAfter
                || restorationIdByChallenge[challenge.id] != 0
        ) revert AVACoreTypes.InvalidState(input.challengeTransitionId);
        DecisionValidationInput memory validation;
        validation.packageId = challenge.targetPackageId;
        validation.subjectId = state.subjectId;
        validation.evidenceId = state.evidenceReceiptId;
        validation.roleKey = input.roleKey;
        validation.authorityId = input.authorityId;
        validation.capabilityKey = AVACapabilityKeys.RESTORATION;
        validation.actionKey = AVACoreTypes.ACTION_RECORD_RESTORATION;
        validation.recordTypeKey = bytes32(uint256(uint8(transition.outcome)));
        validation.sourceTypeKey = CHALLENGE_TRANSITION_SOURCE;
        validation.sourceRecordId = transition.id;
        validation.reasonHash = input.reasonHash;
        _validateDecisionRecord(state, validation);
        restorationId = nextRestorationId++;
        restorations[restorationId] = RestorationRecord({
            id: restorationId,
            appId: state.appId,
            workflowKey: state.workflowKey,
            packageId: state.packageId,
            recognisedStateId: state.id,
            recognisedStateTransitionId: state.lastTransitionId,
            challengeId: challenge.id,
            challengeTransitionId: transition.id,
            subjectId: state.subjectId,
            evidenceId: state.evidenceReceiptId,
            authorityId: input.authorityId,
            reasonHash: input.reasonHash,
            uri: input.uri,
            recordedBy: msg.sender,
            recordedAt: uint64(block.timestamp)
        });
        restorationIdByChallenge[challenge.id] = restorationId;
        emit RestorationRecorded(restorationId, challenge.id, state.id, state.packageId, msg.sender);
    }

    function getPenalty(uint256 penaltyId) external view returns (PenaltyRecord memory) {
        return _penalty(penaltyId);
    }

    function getStandingPenaltyInput(uint256 recordId)
        external
        view
        returns (StandingPenaltyInputRecord memory record)
    {
        record = standingPenaltyInputs[recordId];
        if (record.id == 0) revert AVACoreTypes.UnknownReference(recordId);
    }

    function getEligibilityRestriction(uint256 recordId)
        external
        view
        returns (EligibilityRestrictionRecord memory record)
    {
        record = eligibilityRestrictions[recordId];
        if (record.id == 0) revert AVACoreTypes.UnknownReference(recordId);
    }

    function getRestoration(uint256 restorationId) external view returns (RestorationRecord memory record) {
        record = restorations[restorationId];
        if (record.id == 0) revert AVACoreTypes.UnknownReference(restorationId);
    }

    function _penalty(uint256 penaltyId) private view returns (PenaltyRecord memory record) {
        record = penalties[penaltyId];
        if (record.id == 0) revert AVACoreTypes.UnknownReference(penaltyId);
    }

    function _requireCurrentPenaltyStateVersion(
        AVACoreTypes.RecognisedStateRecord memory state,
        PenaltyRecord memory penalty
    ) private pure {
        if (state.lastTransitionId != penalty.recognisedStateTransitionId) {
            revert AVACoreTypes.InvalidState(penalty.id);
        }
    }

    function _validateDecisionRecord(
        AVACoreTypes.RecognisedStateRecord memory state,
        DecisionValidationInput memory input
    ) private view returns (AVACoreRulePackageRegistry.VerifiedPackageContext memory rulePackage) {
        DecisionModules memory modules = _decisionModules(input.packageId, input.capabilityKey);
        rulePackage = modules.rulePackage;
        if (rulePackage.appId != state.appId) revert AVACoreTypes.InvalidState(input.packageId);
        _requireDecisionSubject(state, input);
        AUTHORITY_MATRIX.requireAuthorisedSubject(
            msg.sender, state.appId, input.roleKey, input.actionKey, input.authorityId
        );
        uint256 policyId = _requireDecisionEvidence(state, input, rulePackage.workflowKey);
        DISCLOSURE_REGISTRY.requireActivePolicyReference(policyId, state.appId);
        _validateDecisionApplication(state, input, rulePackage.workflowKey, modules.application);
        _validateDecisionPolicy(state, input, rulePackage.workflowKey, policyId, modules.policy);
        _validateDecisionAntiAbuse(state, input, rulePackage.workflowKey, modules.antiAbuse);
    }

    function _decisionModules(uint256 packageId, bytes32 capabilityKey)
        private
        view
        returns (DecisionModules memory modules)
    {
        bytes32[] memory capabilityKeys = new bytes32[](3);
        capabilityKeys[0] = AVACapabilityKeys.APPLICATION;
        capabilityKeys[1] = capabilityKey;
        capabilityKeys[2] = AVACapabilityKeys.ANTI_ABUSE;
        address[] memory moduleAddresses;
        (modules.rulePackage, moduleAddresses) =
            RULE_PACKAGE_REGISTRY.getVerifiedModulesCompact(packageId, capabilityKeys);
        if (moduleAddresses[0] == address(0) || moduleAddresses[1] == address(0)) {
            revert AVACoreTypes.UnknownReference(packageId);
        }
        modules.application = IAVAApplicationModule(moduleAddresses[0]);
        modules.policy = IAVAExtensionPolicyModule(moduleAddresses[1]);
        modules.antiAbuse = IAVAAntiAbusePolicyModule(moduleAddresses[2]);
    }

    function _requireDecisionSubject(
        AVACoreTypes.RecognisedStateRecord memory state,
        DecisionValidationInput memory input
    ) private view {
        if (input.allowInactiveReferences) {
            AVAIdentityRegistry.SubjectContext memory subject = IDENTITY_REGISTRY.getSubjectContext(input.subjectId);
            if (subject.appId != state.appId) {
                revert AVACoreTypes.CrossApplicationReference(state.appId, subject.appId);
            }
        } else {
            IDENTITY_REGISTRY.requireActiveSubjectReference(input.subjectId, state.appId);
        }
    }

    function _requireDecisionEvidence(
        AVACoreTypes.RecognisedStateRecord memory state,
        DecisionValidationInput memory input,
        bytes32 workflowKey
    ) private view returns (uint256 policyId) {
        bytes32 evidenceAppId;
        bytes32 evidenceWorkflow;
        uint256 evidencePackage;
        bytes32 evidenceSubject;
        if (input.allowInactiveReferences) {
            (evidenceAppId, evidenceWorkflow, evidencePackage, evidenceSubject, policyId) =
                EVIDENCE_REGISTRY.requireEvidenceReferenceForPackage(input.evidenceId, input.packageId);
        } else {
            (evidenceAppId, evidenceWorkflow, evidencePackage, evidenceSubject, policyId) =
                EVIDENCE_REGISTRY.requireUsableEvidenceReferenceForPackage(input.evidenceId, input.packageId);
        }
        if (
            evidenceAppId != state.appId || evidenceWorkflow != workflowKey
                || evidencePackage != input.packageId || evidenceSubject != input.subjectId
        ) revert AVACoreTypes.InvalidState(input.evidenceId);
    }

    function _validateDecisionApplication(
        AVACoreTypes.RecognisedStateRecord memory state,
        DecisionValidationInput memory input,
        bytes32 workflowKey,
        IAVAApplicationModule application
    ) private view {
        AVAGovernanceKernel.GovernedObjectReference memory objectRecord =
            GOVERNANCE_KERNEL.getGovernedObjectReference(state.governedObjectId);
        application.validateDownstreamRecord(
            IAVAApplicationModule.DownstreamRecordContext({
                appId: state.appId,
                workflowKey: workflowKey,
                packageId: input.packageId,
                actionKey: input.actionKey,
                roleKey: input.roleKey,
                recognisedStateId: state.id,
                governedObjectId: state.governedObjectId,
                objectTypeKey: objectRecord.objectTypeKey,
                subjectId: input.subjectId,
                evidenceReceiptId: input.evidenceId,
                recordTypeKey: input.recordTypeKey,
                authorityId: input.authorityId,
                actor: msg.sender
            })
        );
    }

    function _validateDecisionPolicy(
        AVACoreTypes.RecognisedStateRecord memory state,
        DecisionValidationInput memory input,
        bytes32 workflowKey,
        uint256 policyId,
        IAVAExtensionPolicyModule policy
    ) private view {
        bytes32 contextHash = keccak256(
            abi.encode(
                input.packageId,
                state.id,
                state.lastTransitionId,
                input.subjectId,
                input.sourceTypeKey,
                input.sourceRecordId,
                input.reasonHash
            )
        );
        policy.validateExtensionRecord(
            IAVAExtensionPolicyModule.ExtensionPolicyContext({
                appId: state.appId,
                workflowKey: workflowKey,
                packageId: input.packageId,
                capabilityKey: input.capabilityKey,
                actionKey: input.actionKey,
                recordTypeKey: input.recordTypeKey,
                scopeKey: input.scopeKey == bytes32(0) ? input.recordTypeKey : input.scopeKey,
                sourceTypeKey: input.sourceTypeKey,
                recognisedStateId: state.id,
                recognisedStateTransitionId: state.lastTransitionId,
                subjectId: input.subjectId,
                evidenceId: input.evidenceId,
                disclosurePolicyId: policyId,
                sourceRecordId: input.sourceRecordId,
                unsignedValue: input.unsignedValue,
                validUntil: input.validUntil,
                payloadHash: input.reasonHash,
                contextHash: contextHash,
                authorityId: input.authorityId,
                actor: msg.sender
                })
            );
    }

    function _validateDecisionAntiAbuse(
        AVACoreTypes.RecognisedStateRecord memory state,
        DecisionValidationInput memory input,
        bytes32 workflowKey,
        IAVAAntiAbusePolicyModule antiAbuse
    ) private view {
        if (address(antiAbuse) != address(0)) {
            antiAbuse.validateAntiAbuse(
                IAVAAntiAbusePolicyModule.AntiAbuseContext({
                    appId: state.appId,
                    workflowKey: workflowKey,
                    packageId: input.packageId,
                    actionKey: input.actionKey,
                    roleKey: input.roleKey,
                    targetId: state.id,
                    targetTypeKey: input.recordTypeKey,
                    actorSubjectId: input.authorityId,
                    targetSubjectId: input.subjectId,
                    authorityId: input.authorityId,
                    actor: msg.sender
                })
            );
        }
    }
}
