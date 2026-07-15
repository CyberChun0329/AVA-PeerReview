// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVACoreTypes} from "../src/core/AVACoreTypes.sol";
import {AVAChallengeExtension} from "../src/extensions/challenge/AVAChallengeExtension.sol";
import {PeerReviewTypes} from "../src/apps/peerreview/PeerReviewTypes.sol";
import {AVACanonicalTrace} from "../script/AVACanonicalTrace.s.sol";
import {CanonicalPeerReviewFixture} from "../script/helpers/CanonicalPeerReviewFixture.sol";

contract CanonicalPackageProfileHarness is CanonicalPeerReviewFixture {
    function capabilityCounts() external returns (uint256 reviewCount, uint256 challengeCount) {
        _deployCanonicalPeerReview();
        reviewCount = packageRegistry.getCapabilityKeys(reviewPackageId).length;
        challengeCount = packageRegistry.getCapabilityKeys(challengePackageId).length;
    }
}

contract M12CanonicalTraceTest {
    function testCanonicalDemoPackagesBindOnlyScenarioCapabilities() public {
        (uint256 reviewCount, uint256 challengeCount) = new CanonicalPackageProfileHarness().capabilityCounts();
        require(reviewCount == 12 && challengeCount == 12, "canonical package profile widened");
    }

    function testCanonicalTraceExportsBoundarySafeScenarioNames() public {
        string memory trace = new AVACanonicalTrace().runTrace();
        _assertContains(trace, '"schema":"ava-canonical-trace-v2"');
        _assertContains(trace, '"name":"honest_review_vesting"');
        _assertContains(trace, '"name":"upheld_recursive_challenge_and_downstream_records"');
        _assertContains(trace, '"name":"malicious_or_fabricated_challenge_record_only"');
        _assertContains(trace, '"name":"explicit_restoration_with_lineage"');
        _assertNotContains(trace, "sanction_executed");
        _assertNotContains(trace, "truth_decided");
        _assertNotContains(trace, "manuscript_accepted");
        _assertNotContains(trace, "merit_scored");
    }

    function testCanonicalHonestReviewTraceUsesCoreKernelAndPinnedPackage() public {
        AVACanonicalTrace.HonestReviewTraceRecord memory record = new AVACanonicalTrace().honestReviewTraceRecord();
        require(record.appId == PeerReviewTypes.APP_ID, "wrong application");
        require(record.reviewPackageId != 0, "review package missing");
        require(record.manuscriptObjectId != 0 && record.reviewObjectId != 0, "governed objects missing");
        require(record.recognisedStateId != 0 && record.reviewEvidenceId != 0, "state evidence missing");
        require(record.vestingTransitionId != 0, "vesting transition missing");
        require(record.recognisedStateStatus == AVACoreTypes.RecognisedStateStatus.Vested, "state not vested");
        require(record.vestingFromStatus == AVACoreTypes.RecognisedStateStatus.Challengeable, "wrong source");
        require(record.vestingToStatus == AVACoreTypes.RecognisedStateStatus.Vested, "wrong target");
    }

    function testCanonicalUpheldChallengeTraceIsRecursiveAndUsesChallengeStateDownstream() public {
        AVACanonicalTrace.UpheldChallengeTraceRecord memory record =
            new AVACanonicalTrace().upheldChallengeTraceRecord();
        require(record.appId == PeerReviewTypes.APP_ID, "wrong application");
        require(record.reviewPackageId != 0 && record.challengePackageId != 0, "package missing");
        require(record.reviewPackageId != record.challengePackageId, "challenge package not independent");
        require(record.challengeObjectId != 0 && record.challengeRecognisedStateId != 0, "challenge state missing");
        require(record.challengeId != 0 && record.challengeTransitionId != 0, "challenge lineage missing");
        require(record.targetRecognisedStateTransitionId != 0, "target transition missing");
        require(record.challengeStateTransitionId != 0, "challenge state transition missing");
        require(record.outcome == AVAChallengeExtension.ChallengeOutcome.Upheld, "wrong outcome");
        require(record.targetStatus == AVACoreTypes.RecognisedStateStatus.Downgraded, "target not corrected");
        require(record.challengeStateStatus == AVACoreTypes.RecognisedStateStatus.Vested, "challenge not vested");
        require(record.consequenceId != 0 && record.standingUpdateId != 0, "downstream records missing");
        require(
            record.consequenceRecognisedStateId == record.challengeRecognisedStateId,
            "consequence bypassed challenge state"
        );
        require(
            record.standingRecognisedStateId == record.challengeRecognisedStateId, "standing bypassed challenge state"
        );
    }

    function testCanonicalMaliciousChallengeTraceIsRecordOnly() public {
        AVACanonicalTrace.MaliciousChallengeTraceRecord memory record =
            new AVACanonicalTrace().maliciousChallengeTraceRecord();
        require(record.outcome == AVAChallengeExtension.ChallengeOutcome.MaliciousOrFabricated, "wrong outcome");
        require(record.status == AVAChallengeExtension.ChallengeStatus.Resolved, "challenge not resolved");
        require(record.targetTransitionIdAfter == record.targetTransitionIdAtFiling, "target mutated");
        require(record.nextConsequenceId == 1, "raw outcome created consequence");
        require(record.nextStandingUpdateId == 1, "raw outcome created standing update");
    }

    function testCanonicalRestorationTraceWritesExplicitTargetLineage() public {
        AVACanonicalTrace.RestorationTraceRecord memory record = new AVACanonicalTrace().restorationTraceRecord();
        require(record.challengeId != 0, "challenge missing");
        require(record.restorationChallengeTransitionId != 0, "challenge restoration missing");
        require(record.restorationStateTransitionId != 0, "state restoration missing");
        require(record.restorationStateTransitionId != record.correctionStateTransitionId, "silent overwrite");
        require(record.challengeStatus == AVAChallengeExtension.ChallengeStatus.Closed, "challenge not closed");
        require(record.targetStatus == AVACoreTypes.RecognisedStateStatus.Restored, "target not restored");
        require(record.challengeStateStatus == AVACoreTypes.RecognisedStateStatus.Vested, "challenge history lost");
    }

    function _assertContains(string memory text, string memory needle) internal pure {
        require(_contains(bytes(text), bytes(needle)), "missing trace token");
    }

    function _assertNotContains(string memory text, string memory needle) internal pure {
        require(!_contains(bytes(text), bytes(needle)), "forbidden trace token");
    }

    function _contains(bytes memory text, bytes memory needle) internal pure returns (bool) {
        if (needle.length == 0 || needle.length > text.length) return false;
        for (uint256 i; i <= text.length - needle.length; ++i) {
            bool matched = true;
            for (uint256 j; j < needle.length; ++j) {
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
