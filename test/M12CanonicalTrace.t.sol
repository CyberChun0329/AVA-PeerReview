// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../src/AVADataTypes.sol";
import {AVACanonicalTrace} from "../script/AVACanonicalTrace.s.sol";

contract M12CanonicalTraceTest {
    function testM124CanonicalTraceExportsPaperFacingScenarioNames() public {
        string memory trace = new AVACanonicalTrace().runTrace();
        _assertContains(trace, '"schema":"ava-canonical-trace-v1"');
        _assertContains(trace, '"name":"honest_review_challenge_window_vesting"');
        _assertContains(trace, '"name":"upheld_challenge_correction_standing_record"');
        _assertContains(trace, '"name":"malicious_challenge_penalty_and_eligibility_restriction"');
        _assertContains(trace, '"name":"restoration_after_correction"');
    }

    function testM124CanonicalTraceUsesBoundarySafeVariableNames() public {
        string memory trace = new AVACanonicalTrace().runTrace();
        _assertContains(trace, "review_registered");
        _assertContains(trace, "challenge_upheld");
        _assertContains(trace, "standing_penalty_input_recorded");
        _assertContains(trace, "eligibility_restricted");
        _assertContains(trace, "restoration_applied");
        _assertNotContains(trace, "sanction_executed");
        _assertNotContains(trace, "truth_decided");
        _assertNotContains(trace, "manuscript_accepted");
        _assertNotContains(trace, "merit_scored");
    }

    function testM132CanonicalTraceTokensMapToReturnedIds() public {
        AVACanonicalTrace canonicalTrace = new AVACanonicalTrace();
        AVACanonicalTrace.HonestReviewTraceRecord memory honest = canonicalTrace.honestReviewTraceRecord();
        require(honest.manuscriptId != 0, "review trace missing manuscript id");
        require(honest.recognisedStateId != 0, "review trace missing recognised state id");
        require(honest.reviewContributionId != 0, "review trace missing review id");
        require(honest.reviewEvidenceId != 0, "review trace missing review evidence id");
        require(honest.vestingTransitionId != 0, "review trace missing vesting transition id");

        AVACanonicalTrace.UpheldChallengeTraceRecord memory upheld = canonicalTrace.upheldChallengeTraceRecord();
        require(upheld.challengeId != 0, "upheld trace missing challenge id");
        require(upheld.challengeEvidenceId != 0, "upheld trace missing challenge evidence id");
        require(upheld.challengeTransitionId != 0, "upheld trace missing challenge transition id");
        require(upheld.recognisedStateTransitionId != 0, "upheld trace missing state transition id");
        require(upheld.consequenceId != 0, "upheld trace missing consequence id");
        require(upheld.standingUpdateId != 0, "upheld trace missing standing update id");
        require(upheld.consequenceEvidenceReceiptId == upheld.challengeEvidenceId, "consequence evidence mismatch");
        require(upheld.standingEvidenceReceiptId == upheld.challengeEvidenceId, "standing evidence mismatch");

        AVACanonicalTrace.MaliciousChallengeTraceRecord memory malicious =
            canonicalTrace.maliciousChallengeTraceRecord();
        require(malicious.challengeId != 0, "malicious trace missing challenge id");
        require(malicious.challengeEvidenceId != 0, "malicious trace missing challenge evidence id");
        require(malicious.penaltyConsequenceId != 0, "malicious trace missing penalty id");
        require(malicious.standingPenaltyInputId != 0, "malicious trace missing standing penalty id");
        require(malicious.eligibilityRestrictionId != 0, "malicious trace missing eligibility id");
        require(malicious.penaltyEvidenceReceiptId == malicious.challengeEvidenceId, "penalty evidence mismatch");
        require(
            malicious.standingPenaltyEvidenceReceiptId == malicious.challengeEvidenceId,
            "standing penalty evidence mismatch"
        );
        require(
            malicious.eligibilityEvidenceReceiptId == malicious.challengeEvidenceId,
            "eligibility evidence mismatch"
        );

        AVACanonicalTrace.RestorationTraceRecord memory restoration = canonicalTrace.restorationTraceRecord();
        require(restoration.recognisedStateId != 0, "restoration trace missing recognised state id");
        require(restoration.challengeId != 0, "restoration trace missing challenge id");
        require(restoration.restorationChallengeTransitionId != 0, "restoration trace missing challenge transition id");
        require(restoration.restorationStateTransitionId != 0, "restoration trace missing state transition id");
    }

    function testM132CanonicalTraceRecordsHaveExpectedStatuses() public {
        AVACanonicalTrace canonicalTrace = new AVACanonicalTrace();
        AVACanonicalTrace.HonestReviewTraceRecord memory honest = canonicalTrace.honestReviewTraceRecord();
        require(
            honest.recognisedStateStatus == AVADataTypes.RecognisedStateStatus.Vested,
            "review trace did not vest state"
        );
        require(
            honest.vestingFromStatus == AVADataTypes.RecognisedStateStatus.Challengeable,
            "review trace wrong vesting source"
        );
        require(
            honest.vestingToStatus == AVADataTypes.RecognisedStateStatus.Vested,
            "review trace wrong vesting target"
        );

        AVACanonicalTrace.UpheldChallengeTraceRecord memory upheld = canonicalTrace.upheldChallengeTraceRecord();
        require(upheld.challengeOutcome == AVADataTypes.ChallengeOutcome.Upheld, "upheld trace wrong outcome");
        require(
            upheld.challengeStatus == AVADataTypes.ChallengeLifecycleStatus.Resolved,
            "upheld trace wrong lifecycle status"
        );
        require(
            upheld.challengeTransitionKind == AVADataTypes.ChallengeTransitionKind.OutcomeResolved,
            "upheld trace wrong challenge transition"
        );
        require(
            upheld.recognisedStateStatus == AVADataTypes.RecognisedStateStatus.Downgraded,
            "upheld trace did not downgrade"
        );
        require(
            upheld.stateTransitionToStatus == AVADataTypes.RecognisedStateStatus.Downgraded,
            "upheld trace wrong state transition"
        );
        require(
            upheld.consequenceKind == AVADataTypes.ConsequenceKind.ProcedureCorrection,
            "upheld trace wrong consequence kind"
        );

        AVACanonicalTrace.MaliciousChallengeTraceRecord memory malicious =
            canonicalTrace.maliciousChallengeTraceRecord();
        require(
            malicious.challengeOutcome == AVADataTypes.ChallengeOutcome.MaliciousOrFabricated,
            "malicious trace wrong outcome"
        );
        require(
            malicious.standingPenaltyKind == AVADataTypes.StandingPenaltyKind.MaliciousOrFabricatedChallenge,
            "malicious trace wrong standing penalty kind"
        );
        require(
            malicious.eligibilityRestrictionKind == AVADataTypes.EligibilityRestrictionKind.ChallengeIntake,
            "malicious trace wrong eligibility restriction"
        );
        require(malicious.penaltySubjectId == malicious.standingPenaltySubjectId, "penalty subject mismatch");
        require(malicious.penaltySubjectId == malicious.eligibilitySubjectId, "eligibility subject mismatch");

        AVACanonicalTrace.RestorationTraceRecord memory restoration = canonicalTrace.restorationTraceRecord();
        require(restoration.challengeOutcome == AVADataTypes.ChallengeOutcome.Upheld, "restoration wrong outcome");
        require(
            restoration.challengeStatus == AVADataTypes.ChallengeLifecycleStatus.RestorationApplied,
            "restoration wrong lifecycle status"
        );
        require(
            restoration.challengeTransitionKind == AVADataTypes.ChallengeTransitionKind.RestorationRecorded,
            "restoration wrong transition kind"
        );
        require(
            restoration.recognisedStateStatus == AVADataTypes.RecognisedStateStatus.Restored,
            "restoration did not restore state"
        );
        require(
            restoration.stateTransitionToStatus == AVADataTypes.RecognisedStateStatus.Restored,
            "restoration wrong state transition"
        );
    }

    function _assertContains(string memory text, string memory needle) internal pure {
        require(_contains(bytes(text), bytes(needle)), "missing trace token");
    }

    function _assertNotContains(string memory text, string memory needle) internal pure {
        require(!_contains(bytes(text), bytes(needle)), "forbidden trace token");
    }

    function _contains(bytes memory text, bytes memory needle) internal pure returns (bool) {
        if (needle.length == 0 || needle.length > text.length) return false;
        for (uint256 i = 0; i <= text.length - needle.length; i++) {
            bool matched = true;
            for (uint256 j = 0; j < needle.length; j++) {
                if (text[i + j] != needle[j]) {
                    matched = false;
                    break;
                }
            }
            if (matched) return true;
        }
        return false;
    }
}
