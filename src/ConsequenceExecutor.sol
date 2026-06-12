// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "./AVADataTypes.sol";
import {AuthorityMatrix} from "./AuthorityMatrix.sol";
import {AVAStateMachine} from "./AVAStateMachine.sol";
import {AVARulePackageRegistry} from "./AVARulePackageRegistry.sol";
import {EvidenceCommitmentRegistry} from "./EvidenceCommitmentRegistry.sol";

contract ConsequenceExecutor {
    AuthorityMatrix public immutable authorityMatrix;
    AVAStateMachine public immutable stateMachine;
    AVARulePackageRegistry public immutable rulePackageRegistry;
    EvidenceCommitmentRegistry public immutable evidenceRegistry;
    uint256 public nextConsequenceId = 1;
    uint256 public nextStandingPenaltyInputId = 1;
    uint256 public nextEligibilityRestrictionId = 1;

    mapping(uint256 => AVADataTypes.ConsequenceRecord) private consequences;
    mapping(uint256 => AVADataTypes.StandingPenaltyInputRecord) private standingPenaltyInputs;
    mapping(uint256 => AVADataTypes.EligibilityRestrictionRecord) private eligibilityRestrictions;
    mapping(bytes32 => uint256) private activeEligibilityRestrictionIdBySubjectKind;

    event ConsequenceRegistered(
        uint256 indexed id,
        uint256 indexed recognisedStateId,
        AVADataTypes.ConsequenceKind indexed kind,
        bytes32 subjectId,
        uint256 evidenceReceiptId,
        AVADataTypes.Role authorityRole,
        bytes32 authorityId,
        string uri,
        address registeredBy
    );
    event StandingPenaltyInputRecorded(
        uint256 indexed id,
        uint256 indexed penaltyConsequenceId,
        AVADataTypes.StandingPenaltyKind indexed penaltyKind,
        bytes32 subjectId,
        int256 delta
    );
    event EligibilityRestrictionRecorded(
        uint256 indexed id,
        uint256 indexed penaltyConsequenceId,
        AVADataTypes.EligibilityRestrictionKind indexed restrictionKind,
        bytes32 subjectId
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

    function registerConsequence(
        AVADataTypes.Role actingRole,
        uint256 recognisedStateId,
        AVADataTypes.ConsequenceKind kind,
        bytes32 subjectId,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        return _registerConsequenceWithExecution(
            actingRole, kind, _defaultValueExecutionContext(recognisedStateId, subjectId, 1, evidenceReceiptId, authorityId, uri)
        );
    }

    function registerConsequenceWithExecution(
        AVADataTypes.Role actingRole,
        AVADataTypes.ConsequenceKind kind,
        AVADataTypes.ValueExecutionContext calldata executionContext
    ) external returns (uint256 id) {
        return _registerConsequenceWithExecution(actingRole, kind, executionContext);
    }

    function recordPenalty(
        AVADataTypes.Role actingRole,
        uint256 recognisedStateId,
        bytes32 subjectId,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        return _recordPenaltyWithExecution(
            actingRole, _defaultValueExecutionContext(recognisedStateId, subjectId, 1, evidenceReceiptId, authorityId, uri)
        );
    }

    function recordPenaltyWithExecution(
        AVADataTypes.Role actingRole,
        AVADataTypes.ValueExecutionContext calldata executionContext
    ) external returns (uint256 id) {
        return _recordPenaltyWithExecution(actingRole, executionContext);
    }

    function recordRestoration(
        AVADataTypes.Role actingRole,
        uint256 recognisedStateId,
        bytes32 subjectId,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        return _recordRestorationWithExecution(
            actingRole, _defaultValueExecutionContext(recognisedStateId, subjectId, 1, evidenceReceiptId, authorityId, uri)
        );
    }

    function recordRestorationWithExecution(
        AVADataTypes.Role actingRole,
        AVADataTypes.ValueExecutionContext calldata executionContext
    ) external returns (uint256 id) {
        return _recordRestorationWithExecution(actingRole, executionContext);
    }

    function getConsequence(uint256 id) external view returns (AVADataTypes.ConsequenceRecord memory) {
        AVADataTypes.ConsequenceRecord memory consequence = consequences[id];
        if (consequence.id == 0) revert AVADataTypes.UnknownReference(id);
        return consequence;
    }

    function recordStandingPenaltyInput(
        AVADataTypes.Role actingRole,
        uint256 penaltyConsequenceId,
        uint256 challengeId,
        AVADataTypes.StandingPenaltyKind penaltyKind,
        string calldata dimension,
        int256 delta,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.RegisterConsequence, authorityId
        );
        if (
            penaltyKind == AVADataTypes.StandingPenaltyKind.None || bytes(dimension).length == 0 || delta >= 0
                || evidenceReceiptId == 0 || authorityId == bytes32(0) || bytes(uri).length == 0
        ) {
            revert AVADataTypes.EmptyValue();
        }
        AVADataTypes.ConsequenceRecord memory penalty = _requirePenaltyConsequence(penaltyConsequenceId);
        AVADataTypes.ChallengeOutcome outcome = _requireCompatiblePenaltyOutcome(challengeId, penalty, penaltyKind);
        _requirePenaltySubjectMatchesRecognisedState(penalty);
        _requireEvidenceForPenalty(evidenceReceiptId, penalty);

        id = nextStandingPenaltyInputId++;
        standingPenaltyInputs[id] = AVADataTypes.StandingPenaltyInputRecord({
            id: id,
            penaltyConsequenceId: penaltyConsequenceId,
            challengeId: challengeId,
            penaltyKind: penaltyKind,
            challengeOutcome: outcome,
            subjectId: penalty.subjectId,
            dimension: dimension,
            delta: delta,
            evidenceReceiptId: evidenceReceiptId,
            authorityRole: actingRole,
            authorityId: authorityId,
            uri: uri,
            recordedBy: msg.sender
        });
        emit StandingPenaltyInputRecorded(id, penaltyConsequenceId, penaltyKind, penalty.subjectId, delta);
    }

    function recordEligibilityRestriction(
        AVADataTypes.Role actingRole,
        uint256 penaltyConsequenceId,
        uint256 challengeId,
        AVADataTypes.EligibilityRestrictionKind restrictionKind,
        uint256 expiresAt,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.RegisterConsequence, authorityId
        );
        if (
            restrictionKind == AVADataTypes.EligibilityRestrictionKind.None || expiresAt <= block.timestamp
                || evidenceReceiptId == 0 || authorityId == bytes32(0) || bytes(uri).length == 0
        ) {
            revert AVADataTypes.EmptyValue();
        }
        AVADataTypes.ConsequenceRecord memory penalty = _requirePenaltyConsequence(penaltyConsequenceId);
        AVADataTypes.ChallengeOutcome outcome =
            _requireCompatibleEligibilityOutcome(challengeId, penalty, restrictionKind);
        _requireEvidenceForPenalty(evidenceReceiptId, penalty);

        id = nextEligibilityRestrictionId++;
        eligibilityRestrictions[id] = AVADataTypes.EligibilityRestrictionRecord({
            id: id,
            penaltyConsequenceId: penaltyConsequenceId,
            challengeId: challengeId,
            restrictionKind: restrictionKind,
            challengeOutcome: outcome,
            subjectId: penalty.subjectId,
            expiresAt: expiresAt,
            evidenceReceiptId: evidenceReceiptId,
            authorityRole: actingRole,
            authorityId: authorityId,
            uri: uri,
            recordedBy: msg.sender
        });
        _indexActiveEligibilityRestriction(penalty.packageId, penalty.subjectId, restrictionKind, id, expiresAt);
        emit EligibilityRestrictionRecorded(id, penaltyConsequenceId, restrictionKind, penalty.subjectId);
    }

    function getStandingPenaltyInput(uint256 id)
        external
        view
        returns (AVADataTypes.StandingPenaltyInputRecord memory)
    {
        AVADataTypes.StandingPenaltyInputRecord memory record = standingPenaltyInputs[id];
        if (record.id == 0) revert AVADataTypes.UnknownReference(id);
        return record;
    }

    function activeEligibilityRestrictionId(
        uint256 packageId,
        bytes32 subjectId,
        AVADataTypes.EligibilityRestrictionKind restrictionKind
    ) external view returns (uint256) {
        return _activeEligibilityRestrictionId(packageId, subjectId, restrictionKind);
    }

    function hasActiveEligibilityRestriction(
        uint256 packageId,
        bytes32 subjectId,
        AVADataTypes.EligibilityRestrictionKind restrictionKind
    ) external view returns (bool) {
        return _activeEligibilityRestrictionId(packageId, subjectId, restrictionKind) != 0;
    }

    function getEligibilityRestriction(uint256 id)
        external
        view
        returns (AVADataTypes.EligibilityRestrictionRecord memory)
    {
        AVADataTypes.EligibilityRestrictionRecord memory record = eligibilityRestrictions[id];
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

    function _recordConsequence(
        AVADataTypes.Role actingRole,
        AVADataTypes.ConsequenceKind kind,
        AVADataTypes.ValueExecutionContext memory executionContext,
        uint256 packageId
    ) internal returns (uint256 id) {
        id = nextConsequenceId++;
        consequences[id] = AVADataTypes.ConsequenceRecord({
            id: id,
            recognisedStateId: executionContext.recognisedStateId,
            packageId: packageId,
            kind: kind,
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
            registeredBy: msg.sender
        });

        emit ConsequenceRegistered(
            id,
            executionContext.recognisedStateId,
            kind,
            executionContext.recipientSubjectId,
            executionContext.evidenceReceiptId,
            actingRole,
            executionContext.authorityId,
            executionContext.uri,
            msg.sender
        );
    }

    function _validateAntiAbuse(
        AVARulePackageRegistry.RulePackage memory rulePackage,
        bytes32 workflowKey,
        AVADataTypes.Role actingRole,
        bytes32 subjectId,
        uint256 recognisedStateId
    ) internal view {
        rulePackage.antiAbuseModule.validateUse(
            workflowKey, actingRole, AVADataTypes.Action.RegisterConsequence, subjectId, bytes32(recognisedStateId), msg.sender
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

    function _registerConsequenceWithExecution(
        AVADataTypes.Role actingRole,
        AVADataTypes.ConsequenceKind kind,
        AVADataTypes.ValueExecutionContext memory executionContext
    ) internal returns (uint256 id) {
        if (kind == AVADataTypes.ConsequenceKind.None) {
            revert AVADataTypes.EmptyValue();
        }
        _requireGenericConsequenceKind(kind, executionContext.recognisedStateId);
        _requireSettlementKindForConsequence(kind, executionContext);
        AVARulePackageRegistry.RulePackage memory rulePackage =
            _prepareConsequenceExecution(actingRole, executionContext);
        rulePackage.consequenceAdapter.validateConsequence(
            actingRole,
            executionContext.recognisedStateId,
            kind,
            executionContext.recipientSubjectId,
            executionContext.evidenceReceiptId,
            executionContext.authorityId,
            executionContext.uri,
            msg.sender
        );
        id = _recordConsequence(actingRole, kind, executionContext, rulePackage.packageId);
    }

    function _requireGenericConsequenceKind(AVADataTypes.ConsequenceKind kind, uint256 recognisedStateId)
        internal
        pure
    {
        if (
            kind == AVADataTypes.ConsequenceKind.PenaltyRecord
                || kind == AVADataTypes.ConsequenceKind.RestorationRecord
        ) {
            revert AVADataTypes.InvalidState(recognisedStateId);
        }
    }

    function _recordPenaltyWithExecution(
        AVADataTypes.Role actingRole,
        AVADataTypes.ValueExecutionContext memory executionContext
    ) internal returns (uint256 id) {
        AVARulePackageRegistry.RulePackage memory rulePackage =
            _prepareConsequenceExecution(actingRole, executionContext);
        _requireSettlementKindForConsequence(AVADataTypes.ConsequenceKind.PenaltyRecord, executionContext);
        rulePackage.penaltyAdapter.validatePenaltyRecord(
            actingRole,
            executionContext.recognisedStateId,
            executionContext.recipientSubjectId,
            executionContext.evidenceReceiptId,
            executionContext.authorityId,
            executionContext.uri,
            msg.sender
        );
        id = _recordConsequence(
            actingRole, AVADataTypes.ConsequenceKind.PenaltyRecord, executionContext, rulePackage.packageId
        );
    }

    function _recordRestorationWithExecution(
        AVADataTypes.Role actingRole,
        AVADataTypes.ValueExecutionContext memory executionContext
    ) internal returns (uint256 id) {
        AVARulePackageRegistry.RulePackage memory rulePackage =
            _prepareConsequenceExecution(actingRole, executionContext);
        _requireSettlementKindForConsequence(AVADataTypes.ConsequenceKind.RestorationRecord, executionContext);
        rulePackage.restorationAdapter.validateRestorationRecord(
            actingRole,
            executionContext.recognisedStateId,
            executionContext.recipientSubjectId,
            executionContext.evidenceReceiptId,
            executionContext.authorityId,
            executionContext.uri,
            msg.sender
        );
        id = _recordConsequence(
            actingRole, AVADataTypes.ConsequenceKind.RestorationRecord, executionContext, rulePackage.packageId
        );
    }

    function _prepareConsequenceExecution(
        AVADataTypes.Role actingRole,
        AVADataTypes.ValueExecutionContext memory executionContext
    ) internal view returns (AVARulePackageRegistry.RulePackage memory rulePackage) {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.RegisterConsequence, executionContext.authorityId
        );
        AVADataTypes.RecognisedStateRecord memory recognisedState =
            _requireAllowedRecognisedState(executionContext.recognisedStateId);
        _requireValidExecutionContext(executionContext);
        authorityMatrix.requireKnownActiveSubject(executionContext.recipientSubjectId);
        _requireRecognisedStateSubject(recognisedState, executionContext.recipientSubjectId);
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

    function _requireSettlementKindForConsequence(
        AVADataTypes.ConsequenceKind consequenceKind,
        AVADataTypes.ValueExecutionContext memory executionContext
    ) internal pure {
        if (executionContext.mode == AVADataTypes.ValueExecutionMode.RecordOnly) {
            return;
        }
        if (
            consequenceKind != AVADataTypes.ConsequenceKind.PenaltyRecord
                || executionContext.mode != AVADataTypes.ValueExecutionMode.Claim
                || executionContext.settlementKind != AVADataTypes.ValueSettlementKind.ClawbackTransfer
        ) {
            revert AVADataTypes.InvalidState(executionContext.recognisedStateId);
        }
    }

    function _requirePenaltyConsequence(uint256 penaltyConsequenceId)
        internal
        view
        returns (AVADataTypes.ConsequenceRecord memory penalty)
    {
        penalty = consequences[penaltyConsequenceId];
        if (penalty.id == 0) revert AVADataTypes.UnknownReference(penaltyConsequenceId);
        if (penalty.kind != AVADataTypes.ConsequenceKind.PenaltyRecord) {
            revert AVADataTypes.InvalidState(penaltyConsequenceId);
        }
        authorityMatrix.requireKnownActiveSubject(penalty.subjectId);
    }

    function _requireCompatiblePenaltyOutcome(
        uint256 challengeId,
        AVADataTypes.ConsequenceRecord memory penalty,
        AVADataTypes.StandingPenaltyKind penaltyKind
    ) internal view returns (AVADataTypes.ChallengeOutcome outcome) {
        if (challengeId == 0) revert AVADataTypes.InvalidState(challengeId);
        AVADataTypes.ChallengeRecord memory challenge = _requirePenaltyChallenge(challengeId, penalty);
        outcome = challenge.outcome;
        if (outcome == AVADataTypes.ChallengeOutcome.RejectedGoodFaith) {
            revert AVADataTypes.InvalidState(challengeId);
        }
        if (
            penaltyKind == AVADataTypes.StandingPenaltyKind.MaliciousOrFabricatedChallenge
                && outcome != AVADataTypes.ChallengeOutcome.MaliciousOrFabricated
        ) {
            revert AVADataTypes.InvalidState(challengeId);
        }
        if (
            penaltyKind == AVADataTypes.StandingPenaltyKind.NegligentChallenge
                && outcome != AVADataTypes.ChallengeOutcome.Negligent
        ) {
            revert AVADataTypes.InvalidState(challengeId);
        }
        if (
            (penaltyKind == AVADataTypes.StandingPenaltyKind.AcademicFraud
                || penaltyKind == AVADataTypes.StandingPenaltyKind.IrresponsibleReview)
                && outcome != AVADataTypes.ChallengeOutcome.Upheld
        ) {
            revert AVADataTypes.InvalidState(challengeId);
        }
        if (
            penaltyKind == AVADataTypes.StandingPenaltyKind.AcademicFraud
                || penaltyKind == AVADataTypes.StandingPenaltyKind.IrresponsibleReview
        ) {
            if (challenge.challengedRecognisedStateId != penalty.recognisedStateId) {
                revert AVADataTypes.InvalidState(challengeId);
            }
        } else if (challenge.challengerSubjectId != penalty.subjectId) {
            revert AVADataTypes.InvalidState(challengeId);
        }
    }

    function _requireCompatibleEligibilityOutcome(
        uint256 challengeId,
        AVADataTypes.ConsequenceRecord memory penalty,
        AVADataTypes.EligibilityRestrictionKind restrictionKind
    ) internal view returns (AVADataTypes.ChallengeOutcome outcome) {
        if (challengeId == 0) revert AVADataTypes.InvalidState(challengeId);
        AVADataTypes.ChallengeRecord memory challenge = _requirePenaltyChallenge(challengeId, penalty);
        outcome = challenge.outcome;
        if (outcome == AVADataTypes.ChallengeOutcome.RejectedGoodFaith) {
            revert AVADataTypes.InvalidState(challengeId);
        }
        if (restrictionKind == AVADataTypes.EligibilityRestrictionKind.ChallengeIntake) {
            if (
                outcome != AVADataTypes.ChallengeOutcome.Negligent
                    && outcome != AVADataTypes.ChallengeOutcome.MaliciousOrFabricated
            ) {
                revert AVADataTypes.InvalidState(challengeId);
            }
            if (challenge.challengerSubjectId != penalty.subjectId) revert AVADataTypes.InvalidState(challengeId);
        }
    }

    function _challengeOutcome(uint256 challengeId, AVADataTypes.ConsequenceRecord memory penalty)
        internal
        view
        returns (AVADataTypes.ChallengeOutcome outcome)
    {
        if (challengeId == 0) return AVADataTypes.ChallengeOutcome.None;
        return _requirePenaltyChallenge(challengeId, penalty).outcome;
    }

    function _requirePenaltyChallenge(uint256 challengeId, AVADataTypes.ConsequenceRecord memory penalty)
        internal
        view
        returns (AVADataTypes.ChallengeRecord memory challenge)
    {
        challenge = stateMachine.getChallenge(challengeId);
        if (challenge.packageId != penalty.packageId) revert AVADataTypes.InvalidState(challengeId);
        if (challenge.outcome == AVADataTypes.ChallengeOutcome.None) revert AVADataTypes.InvalidState(challengeId);
    }

    function _requireRecognisedStateSubject(
        AVADataTypes.RecognisedStateRecord memory recognisedState,
        bytes32 subjectId
    ) internal pure {
        if (recognisedState.subjectId != subjectId) revert AVADataTypes.InvalidState(recognisedState.id);
    }

    function _requirePenaltySubjectMatchesRecognisedState(AVADataTypes.ConsequenceRecord memory penalty) internal view {
        AVADataTypes.RecognisedStateRecord memory recognisedState = stateMachine.getRecognisedState(penalty.recognisedStateId);
        _requireRecognisedStateSubject(recognisedState, penalty.subjectId);
    }

    function _requireEvidenceForPenalty(uint256 evidenceReceiptId, AVADataTypes.ConsequenceRecord memory penalty)
        internal
        view
    {
        AVADataTypes.RecognisedStateRecord memory recognisedState = stateMachine.getRecognisedState(penalty.recognisedStateId);
        AVADataTypes.EvidenceReceipt memory evidence =
            evidenceRegistry.requireUsableEvidenceReceipt(evidenceReceiptId, recognisedState.workflowKey);
        if (evidence.packageId != recognisedState.packageId) revert AVADataTypes.InvalidState(evidenceReceiptId);
    }

    function _indexActiveEligibilityRestriction(
        uint256 packageId,
        bytes32 subjectId,
        AVADataTypes.EligibilityRestrictionKind restrictionKind,
        uint256 restrictionId,
        uint256 expiresAt
    ) internal {
        bytes32 key = keccak256(abi.encode(packageId, subjectId, restrictionKind));
        uint256 currentId = activeEligibilityRestrictionIdBySubjectKind[key];
        if (currentId == 0) {
            activeEligibilityRestrictionIdBySubjectKind[key] = restrictionId;
            return;
        }
        AVADataTypes.EligibilityRestrictionRecord memory current = eligibilityRestrictions[currentId];
        if (current.id == 0 || current.expiresAt <= block.timestamp || expiresAt >= current.expiresAt) {
            activeEligibilityRestrictionIdBySubjectKind[key] = restrictionId;
        }
    }

    function _activeEligibilityRestrictionId(
        uint256 packageId,
        bytes32 subjectId,
        AVADataTypes.EligibilityRestrictionKind restrictionKind
    ) internal view returns (uint256) {
        if (packageId == 0 || subjectId == bytes32(0) || restrictionKind == AVADataTypes.EligibilityRestrictionKind.None) {
            return 0;
        }
        uint256 id = activeEligibilityRestrictionIdBySubjectKind[
            keccak256(abi.encode(packageId, subjectId, restrictionKind))
        ];
        if (id == 0) return 0;
        AVADataTypes.EligibilityRestrictionRecord memory record = eligibilityRestrictions[id];
        if (record.id == 0 || record.expiresAt <= block.timestamp) return 0;
        return id;
    }
}
