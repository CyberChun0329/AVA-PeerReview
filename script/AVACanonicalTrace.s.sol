// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../src/AVADataTypes.sol";
import {AVADemoScenario} from "./AVADemoScenario.s.sol";

contract AVACanonicalTrace is AVADemoScenario {
    bytes32 private constant TRACE_REVIEWER_SUBJECT = keccak256("demo-reviewer");
    bytes32 private constant TRACE_CHALLENGER_SUBJECT = keccak256("demo-challenger");
    bytes32 private constant TRACE_EDITOR_AUTHORITY = keccak256("demo-editor-authority");
    bytes32 private constant TRACE_PANEL_AUTHORITY = keccak256("demo-panel-authority");

    struct ReviewContext {
        uint256 disclosurePolicyId;
        uint256 manuscriptId;
        uint256 reviewContributionId;
        uint256 recognisedStateId;
        uint256 reviewEvidenceId;
    }

    struct HonestReviewTraceRecord {
        uint256 manuscriptId;
        uint256 recognisedStateId;
        uint256 reviewContributionId;
        uint256 reviewEvidenceId;
        uint256 vestingTransitionId;
        AVADataTypes.RecognisedStateStatus recognisedStateStatus;
        AVADataTypes.RecognisedStateStatus vestingFromStatus;
        AVADataTypes.RecognisedStateStatus vestingToStatus;
    }

    struct UpheldChallengeTraceRecord {
        uint256 recognisedStateId;
        uint256 challengeId;
        uint256 challengeEvidenceId;
        uint256 challengeTransitionId;
        uint256 recognisedStateTransitionId;
        uint256 consequenceId;
        uint256 standingUpdateId;
        AVADataTypes.ChallengeOutcome challengeOutcome;
        AVADataTypes.ChallengeLifecycleStatus challengeStatus;
        AVADataTypes.ChallengeTransitionKind challengeTransitionKind;
        AVADataTypes.RecognisedStateStatus recognisedStateStatus;
        AVADataTypes.RecognisedStateStatus stateTransitionToStatus;
        AVADataTypes.ConsequenceKind consequenceKind;
        bytes32 standingSubjectId;
        uint256 consequenceEvidenceReceiptId;
        uint256 standingEvidenceReceiptId;
    }

    struct MaliciousChallengeTraceRecord {
        uint256 challengeId;
        uint256 challengeEvidenceId;
        uint256 penaltyConsequenceId;
        uint256 standingPenaltyInputId;
        uint256 eligibilityRestrictionId;
        AVADataTypes.ChallengeOutcome challengeOutcome;
        AVADataTypes.StandingPenaltyKind standingPenaltyKind;
        AVADataTypes.EligibilityRestrictionKind eligibilityRestrictionKind;
        bytes32 penaltySubjectId;
        bytes32 standingPenaltySubjectId;
        bytes32 eligibilitySubjectId;
        uint256 penaltyEvidenceReceiptId;
        uint256 standingPenaltyEvidenceReceiptId;
        uint256 eligibilityEvidenceReceiptId;
    }

    struct RestorationTraceRecord {
        uint256 recognisedStateId;
        uint256 challengeId;
        uint256 restorationChallengeTransitionId;
        uint256 restorationStateTransitionId;
        AVADataTypes.ChallengeOutcome challengeOutcome;
        AVADataTypes.ChallengeLifecycleStatus challengeStatus;
        AVADataTypes.ChallengeTransitionKind challengeTransitionKind;
        AVADataTypes.RecognisedStateStatus recognisedStateStatus;
        AVADataTypes.RecognisedStateStatus stateTransitionToStatus;
    }

    function artifactPath() external pure returns (string memory) {
        return "generated/canonical-scenario-traces.json";
    }

    function runTrace() external returns (string memory) {
        return string.concat(
            '{"schema":"ava-canonical-trace-v1","scenarios":[',
            _honestReviewTrace(),
            ",",
            _upheldChallengeTrace(),
            ",",
            _maliciousChallengeRestrictionTrace(),
            ",",
            _restorationTrace(),
            "]}"
        );
    }

    function honestReviewTraceRecord() external returns (HonestReviewTraceRecord memory record) {
        _deployAndConfigure();
        ReviewContext memory context = _startReview("m132-honest");
        record.vestingTransitionId = panelDemoActor.vestReviewRecognition(
            stateMachine,
            AVADataTypes.Role.Panel,
            context.reviewContributionId,
            TRACE_PANEL_AUTHORITY,
            "ipfs://m132-honest-vesting"
        );
        AVADataTypes.RecognisedStateRecord memory recognisedState =
            stateMachine.getRecognisedState(context.recognisedStateId);
        AVADataTypes.RecognisedStateTransitionRecord memory transition =
            stateMachine.getRecognisedStateTransition(record.vestingTransitionId);

        record.manuscriptId = context.manuscriptId;
        record.recognisedStateId = context.recognisedStateId;
        record.reviewContributionId = context.reviewContributionId;
        record.reviewEvidenceId = context.reviewEvidenceId;
        record.recognisedStateStatus = recognisedState.status;
        record.vestingFromStatus = transition.fromStatus;
        record.vestingToStatus = transition.toStatus;
    }

    function upheldChallengeTraceRecord() external returns (UpheldChallengeTraceRecord memory record) {
        _deployAndConfigure();
        ReviewContext memory context = _startReview("m132-upheld");
        (uint256 challengeId, uint256 challengeEvidenceId) =
            _fileScreenResolveChallenge(context, "m132-upheld", AVADataTypes.ChallengeOutcome.Upheld);
        uint256 consequenceId = panelDemoActor.registerConsequence(
            consequenceExecutor,
            AVADataTypes.Role.Panel,
            context.recognisedStateId,
            AVADataTypes.ConsequenceKind.ProcedureCorrection,
            TRACE_REVIEWER_SUBJECT,
            challengeEvidenceId,
            TRACE_PANEL_AUTHORITY,
            "ipfs://m132-procedure-correction"
        );
        uint256 standingUpdateId = panelDemoActor.recordStandingUpdate(
            standingRegistry,
            AVADataTypes.Role.Panel,
            context.recognisedStateId,
            TRACE_REVIEWER_SUBJECT,
            "review-procedure-weight",
            -1,
            challengeEvidenceId,
            TRACE_PANEL_AUTHORITY,
            "ipfs://m132-standing-update"
        );

        AVADataTypes.ChallengeRecord memory challenge = stateMachine.getChallenge(challengeId);
        AVADataTypes.ChallengeTransitionRecord memory challengeTransition =
            stateMachine.getChallengeTransition(challenge.lastTransitionId);
        AVADataTypes.RecognisedStateTransitionRecord memory stateTransition =
            stateMachine.getRecognisedStateTransition(stateMachine.nextRecognisedStateTransitionId() - 1);
        AVADataTypes.RecognisedStateRecord memory recognisedState =
            stateMachine.getRecognisedState(context.recognisedStateId);
        AVADataTypes.ConsequenceRecord memory consequence = consequenceExecutor.getConsequence(consequenceId);
        AVADataTypes.StandingUpdateRecord memory standingUpdate = standingRegistry.getStandingUpdate(standingUpdateId);

        record.recognisedStateId = context.recognisedStateId;
        record.challengeId = challengeId;
        record.challengeEvidenceId = challengeEvidenceId;
        record.challengeTransitionId = challenge.lastTransitionId;
        record.recognisedStateTransitionId = stateTransition.id;
        record.consequenceId = consequenceId;
        record.standingUpdateId = standingUpdateId;
        record.challengeOutcome = challenge.outcome;
        record.challengeStatus = challenge.status;
        record.challengeTransitionKind = challengeTransition.transitionKind;
        record.recognisedStateStatus = recognisedState.status;
        record.stateTransitionToStatus = stateTransition.toStatus;
        record.consequenceKind = consequence.kind;
        record.standingSubjectId = standingUpdate.subjectId;
        record.consequenceEvidenceReceiptId = consequence.evidenceReceiptId;
        record.standingEvidenceReceiptId = standingUpdate.evidenceReceiptId;
    }

    function maliciousChallengeTraceRecord() external returns (MaliciousChallengeTraceRecord memory record) {
        _deployAndConfigure();
        ReviewContext memory context = _startReview("m132-malicious");
        (uint256 challengeId, uint256 challengeEvidenceId) =
            _fileScreenResolveChallenge(context, "m132-malicious", AVADataTypes.ChallengeOutcome.MaliciousOrFabricated);
        uint256 penaltyStateId = _createVestedStateForSubject(
            TRACE_CHALLENGER_SUBJECT, challengeEvidenceId, "m132-malicious-penalty-state"
        );
        uint256 penaltyId = panelDemoActor.recordPenalty(
            consequenceExecutor,
            AVADataTypes.Role.Panel,
            penaltyStateId,
            TRACE_CHALLENGER_SUBJECT,
            challengeEvidenceId,
            TRACE_PANEL_AUTHORITY,
            "ipfs://m132-malicious-penalty"
        );
        uint256 standingPenaltyInputId = panelDemoActor.recordStandingPenaltyInput(
            consequenceExecutor,
            AVADataTypes.Role.Panel,
            penaltyId,
            challengeId,
            AVADataTypes.StandingPenaltyKind.MaliciousOrFabricatedChallenge,
            "challenge-integrity-standing",
            -1,
            challengeEvidenceId,
            TRACE_PANEL_AUTHORITY,
            "ipfs://m132-malicious-standing-input"
        );
        uint256 restrictionId = panelDemoActor.recordEligibilityRestriction(
            consequenceExecutor,
            AVADataTypes.Role.Panel,
            penaltyId,
            challengeId,
            AVADataTypes.EligibilityRestrictionKind.ChallengeIntake,
            block.timestamp + 7 days,
            challengeEvidenceId,
            TRACE_PANEL_AUTHORITY,
            "ipfs://m132-malicious-eligibility"
        );

        AVADataTypes.ChallengeRecord memory challenge = stateMachine.getChallenge(challengeId);
        AVADataTypes.ConsequenceRecord memory penalty = consequenceExecutor.getConsequence(penaltyId);
        AVADataTypes.StandingPenaltyInputRecord memory standingPenalty =
            consequenceExecutor.getStandingPenaltyInput(standingPenaltyInputId);
        AVADataTypes.EligibilityRestrictionRecord memory restriction =
            consequenceExecutor.getEligibilityRestriction(restrictionId);

        record.challengeId = challengeId;
        record.challengeEvidenceId = challengeEvidenceId;
        record.penaltyConsequenceId = penaltyId;
        record.standingPenaltyInputId = standingPenaltyInputId;
        record.eligibilityRestrictionId = restrictionId;
        record.challengeOutcome = challenge.outcome;
        record.standingPenaltyKind = standingPenalty.penaltyKind;
        record.eligibilityRestrictionKind = restriction.restrictionKind;
        record.penaltySubjectId = penalty.subjectId;
        record.standingPenaltySubjectId = standingPenalty.subjectId;
        record.eligibilitySubjectId = restriction.subjectId;
        record.penaltyEvidenceReceiptId = penalty.evidenceReceiptId;
        record.standingPenaltyEvidenceReceiptId = standingPenalty.evidenceReceiptId;
        record.eligibilityEvidenceReceiptId = restriction.evidenceReceiptId;
    }

    function restorationTraceRecord() external returns (RestorationTraceRecord memory record) {
        _deployAndConfigure();
        authorityMatrix.setPermission(AVADataTypes.Role.Panel, AVADataTypes.Action.ApplyRestoration, true);
        ReviewContext memory context = _startReview("m132-restoration");
        (uint256 challengeId,) = _fileScreenResolveChallenge(context, "m132-restoration", AVADataTypes.ChallengeOutcome.Upheld);
        panelDemoActor.applyRestoration(
            stateMachine, AVADataTypes.Role.Panel, challengeId, TRACE_PANEL_AUTHORITY, "ipfs://m132-restoration"
        );

        AVADataTypes.ChallengeRecord memory challenge = stateMachine.getChallenge(challengeId);
        AVADataTypes.ChallengeTransitionRecord memory challengeTransition =
            stateMachine.getChallengeTransition(challenge.lastTransitionId);
        AVADataTypes.RecognisedStateTransitionRecord memory stateTransition =
            stateMachine.getRecognisedStateTransition(stateMachine.nextRecognisedStateTransitionId() - 1);
        AVADataTypes.RecognisedStateRecord memory recognisedState =
            stateMachine.getRecognisedState(context.recognisedStateId);

        record.recognisedStateId = context.recognisedStateId;
        record.challengeId = challengeId;
        record.restorationChallengeTransitionId = challenge.lastTransitionId;
        record.restorationStateTransitionId = stateTransition.id;
        record.challengeOutcome = challenge.outcome;
        record.challengeStatus = challenge.status;
        record.challengeTransitionKind = challengeTransition.transitionKind;
        record.recognisedStateStatus = recognisedState.status;
        record.stateTransitionToStatus = stateTransition.toStatus;
    }

    function _honestReviewTrace() internal returns (string memory) {
        _deployAndConfigure();
        ReviewContext memory context = _startReview("m124-honest");
        uint256 vestingTransitionId = panelDemoActor.vestReviewRecognition(
            stateMachine,
            AVADataTypes.Role.Panel,
            context.reviewContributionId,
            TRACE_PANEL_AUTHORITY,
            "ipfs://m124-honest-vesting"
        );
        return string.concat(
            '{"name":"honest_review_challenge_window_vesting","trace":["review_registered","challenge_opened","recognition_vested"],',
            '"ids":{"manuscriptId":',
            _u(context.manuscriptId),
            ',"recognisedStateId":',
            _u(context.recognisedStateId),
            ',"reviewContributionId":',
            _u(context.reviewContributionId),
            ',"vestingTransitionId":',
            _u(vestingTransitionId),
            "}}"
        );
    }

    function _upheldChallengeTrace() internal returns (string memory) {
        _deployAndConfigure();
        ReviewContext memory context = _startReview("m124-upheld");
        (uint256 challengeId, uint256 challengeEvidenceId) =
            _fileScreenResolveChallenge(context, "m124-upheld", AVADataTypes.ChallengeOutcome.Upheld);
        uint256 consequenceId = panelDemoActor.registerConsequence(
            consequenceExecutor,
            AVADataTypes.Role.Panel,
            context.recognisedStateId,
            AVADataTypes.ConsequenceKind.ProcedureCorrection,
            TRACE_REVIEWER_SUBJECT,
            challengeEvidenceId,
            TRACE_PANEL_AUTHORITY,
            "ipfs://m124-procedure-correction"
        );
        uint256 standingUpdateId = panelDemoActor.recordStandingUpdate(
            standingRegistry,
            AVADataTypes.Role.Panel,
            context.recognisedStateId,
            TRACE_REVIEWER_SUBJECT,
            "review-procedure-weight",
            -1,
            challengeEvidenceId,
            TRACE_PANEL_AUTHORITY,
            "ipfs://m124-standing-update"
        );
        return string.concat(
            '{"name":"upheld_challenge_correction_standing_record","trace":["challenge_filed","challenge_screened","challenge_upheld","recognition_downgraded","bounded_consequence_recorded","standing_update_recorded"],',
            '"ids":{"recognisedStateId":',
            _u(context.recognisedStateId),
            ',"challengeId":',
            _u(challengeId),
            ',"consequenceId":',
            _u(consequenceId),
            ',"standingUpdateId":',
            _u(standingUpdateId),
            "}}"
        );
    }

    function _maliciousChallengeRestrictionTrace() internal returns (string memory) {
        _deployAndConfigure();
        ReviewContext memory context = _startReview("m124-malicious");
        (uint256 challengeId, uint256 challengeEvidenceId) =
            _fileScreenResolveChallenge(context, "m124-malicious", AVADataTypes.ChallengeOutcome.MaliciousOrFabricated);
        uint256 penaltyStateId = _createVestedStateForSubject(
            TRACE_CHALLENGER_SUBJECT, challengeEvidenceId, "m124-malicious-penalty-state"
        );
        uint256 penaltyId = panelDemoActor.recordPenalty(
            consequenceExecutor,
            AVADataTypes.Role.Panel,
            penaltyStateId,
            TRACE_CHALLENGER_SUBJECT,
            challengeEvidenceId,
            TRACE_PANEL_AUTHORITY,
            "ipfs://m124-malicious-penalty"
        );
        uint256 standingPenaltyInputId = panelDemoActor.recordStandingPenaltyInput(
            consequenceExecutor,
            AVADataTypes.Role.Panel,
            penaltyId,
            challengeId,
            AVADataTypes.StandingPenaltyKind.MaliciousOrFabricatedChallenge,
            "challenge-integrity-standing",
            -1,
            challengeEvidenceId,
            TRACE_PANEL_AUTHORITY,
            "ipfs://m124-malicious-standing-input"
        );
        uint256 restrictionId = panelDemoActor.recordEligibilityRestriction(
            consequenceExecutor,
            AVADataTypes.Role.Panel,
            penaltyId,
            challengeId,
            AVADataTypes.EligibilityRestrictionKind.ChallengeIntake,
            block.timestamp + 7 days,
            challengeEvidenceId,
            TRACE_PANEL_AUTHORITY,
            "ipfs://m124-malicious-eligibility"
        );
        return string.concat(
            '{"name":"malicious_challenge_penalty_and_eligibility_restriction","trace":["challenge_malicious_or_fabricated","penalty_recorded","standing_penalty_input_recorded","eligibility_restricted"],',
            '"ids":{"challengeId":',
            _u(challengeId),
            ',"penaltyConsequenceId":',
            _u(penaltyId),
            ',"standingPenaltyInputId":',
            _u(standingPenaltyInputId),
            ',"eligibilityRestrictionId":',
            _u(restrictionId),
            "}}"
        );
    }

    function _restorationTrace() internal returns (string memory) {
        _deployAndConfigure();
        authorityMatrix.setPermission(AVADataTypes.Role.Panel, AVADataTypes.Action.ApplyRestoration, true);
        ReviewContext memory context = _startReview("m124-restoration");
        (uint256 challengeId,) = _fileScreenResolveChallenge(context, "m124-restoration", AVADataTypes.ChallengeOutcome.Upheld);
        panelDemoActor.applyRestoration(
            stateMachine, AVADataTypes.Role.Panel, challengeId, TRACE_PANEL_AUTHORITY, "ipfs://m124-restoration"
        );
        return string.concat(
            '{"name":"restoration_after_correction","trace":["challenge_upheld","recognition_downgraded","restoration_applied","recognition_restored"],',
            '"ids":{"recognisedStateId":',
            _u(context.recognisedStateId),
            ',"challengeId":',
            _u(challengeId),
            ',"restorationChallengeTransitionId":',
            _u(stateMachine.getChallenge(challengeId).lastTransitionId),
            ',"restorationStateTransitionId":',
            _u(stateMachine.nextRecognisedStateTransitionId() - 1),
            "}}"
        );
    }

    function _startReview(string memory seed) internal returns (ReviewContext memory context) {
        context.disclosurePolicyId = demoActor.registerDisclosurePolicy(
            disclosureRegistry,
            AVADataTypes.Role.Editor,
            string.concat(seed, "-policy"),
            string.concat("ipfs://", seed, "-policy")
        );
        context.reviewEvidenceId = demoActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256(bytes(string.concat(seed, "-review-evidence"))),
            string.concat("ipfs://", seed, "-review-evidence"),
            "review-service-occurrence",
            context.disclosurePolicyId
        );
        context.manuscriptId = demoActor.registerManuscript(
            stateMachine, AVADataTypes.Role.Author, keccak256(bytes(string.concat(seed, "-manuscript"))), string.concat("ipfs://", seed, "-manuscript")
        );
        context.reviewContributionId = demoActor.registerReviewContribution(
            stateMachine,
            AVADataTypes.Role.Reviewer,
            context.manuscriptId,
            TRACE_REVIEWER_SUBJECT,
            context.reviewEvidenceId,
            context.disclosurePolicyId
        );
        context.recognisedStateId = demoActor.provisionallyRecogniseReview(
            stateMachine, AVADataTypes.Role.Editor, context.reviewContributionId, TRACE_EDITOR_AUTHORITY
        );
        demoActor.openReviewChallengeWindow(
            stateMachine, AVADataTypes.Role.Editor, context.reviewContributionId, TRACE_EDITOR_AUTHORITY
        );
    }

    function _fileScreenResolveChallenge(
        ReviewContext memory context,
        string memory seed,
        AVADataTypes.ChallengeOutcome outcome
    ) internal returns (uint256 challengeId, uint256 challengeEvidenceId) {
        challengeEvidenceId = challengerDemoActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256(bytes(string.concat(seed, "-challenge-evidence"))),
            string.concat("ipfs://", seed, "-challenge-evidence"),
            "review-quality-challenge",
            context.disclosurePolicyId
        );
        challengeId = challengerDemoActor.fileChallenge(
            stateMachine,
            AVADataTypes.Role.Challenger,
            context.recognisedStateId,
            TRACE_CHALLENGER_SUBJECT,
            challengeEvidenceId,
            context.disclosurePolicyId
        );
        demoActor.screenChallenge(stateMachine, AVADataTypes.Role.Editor, challengeId, TRACE_EDITOR_AUTHORITY);
        AVADataTypes.RecognisedStateStatus toStatus = outcome == AVADataTypes.ChallengeOutcome.Upheld
            ? AVADataTypes.RecognisedStateStatus.Downgraded
            : AVADataTypes.RecognisedStateStatus.Challengeable;
        panelDemoActor.resolveChallenge(
            stateMachine,
            AVADataTypes.Role.Panel,
            challengeId,
            outcome,
            toStatus,
            TRACE_PANEL_AUTHORITY,
            string.concat("ipfs://", seed, "-resolution")
        );
    }

    function _createVestedStateForSubject(
        bytes32 subjectId,
        uint256 evidenceId,
        string memory seed
    ) internal returns (uint256 recognisedStateId) {
        recognisedStateId = demoActor.registerRecognisedState(
            stateMachine,
            AVADataTypes.Role.Editor,
            keccak256("demo-review-workflow"),
            AVADataTypes.AVAStage.Verification,
            keccak256(bytes(seed)),
            subjectId,
            evidenceId,
            0,
            TRACE_EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        );
        panelDemoActor.transitionRecognisedState(
            stateMachine,
            AVADataTypes.Role.Panel,
            recognisedStateId,
            AVADataTypes.RecognisedStateStatus.Vested,
            TRACE_PANEL_AUTHORITY,
            string.concat("ipfs://", seed, "-vesting")
        );
    }

    function _u(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            // value % 10 is always 0..9, so the ASCII digit fits into uint8.
            // forge-lint: disable-next-line(unsafe-typecast)
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
