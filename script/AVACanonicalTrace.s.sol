// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVACoreTypes} from "../src/core/AVACoreTypes.sol";
import {AVAChallengeExtension} from "../src/extensions/challenge/AVAChallengeExtension.sol";
import {
    AVAStandingRecordExtension,
    AVAConsequenceRecordExtension
} from "../src/extensions/downstream/AVADownstreamRecordExtensions.sol";
import {PeerReviewTypes} from "../src/apps/peerreview/PeerReviewTypes.sol";
import {CanonicalPeerReviewFixture} from "./helpers/CanonicalPeerReviewFixture.sol";

/// @notice Deterministic paper/model handoff traces executed on the canonical AVA stack.
contract AVACanonicalTrace is CanonicalPeerReviewFixture {
    struct HonestReviewTraceRecord {
        bytes32 appId;
        uint256 reviewPackageId;
        uint256 manuscriptObjectId;
        uint256 reviewObjectId;
        uint256 recognisedStateId;
        uint256 reviewEvidenceId;
        uint256 vestingTransitionId;
        AVACoreTypes.RecognisedStateStatus recognisedStateStatus;
        AVACoreTypes.RecognisedStateStatus vestingFromStatus;
        AVACoreTypes.RecognisedStateStatus vestingToStatus;
    }

    struct UpheldChallengeTraceRecord {
        bytes32 appId;
        uint256 reviewPackageId;
        uint256 challengePackageId;
        uint256 targetRecognisedStateId;
        uint256 challengeObjectId;
        uint256 challengeRecognisedStateId;
        uint256 challengeId;
        uint256 challengeEvidenceId;
        uint256 challengeTransitionId;
        uint256 targetRecognisedStateTransitionId;
        uint256 challengeStateTransitionId;
        uint256 consequenceId;
        uint256 standingUpdateId;
        uint256 consequenceRecognisedStateId;
        uint256 standingRecognisedStateId;
        AVAChallengeExtension.ChallengeOutcome outcome;
        AVACoreTypes.RecognisedStateStatus targetStatus;
        AVACoreTypes.RecognisedStateStatus challengeStateStatus;
    }

    struct MaliciousChallengeTraceRecord {
        uint256 targetRecognisedStateId;
        uint256 challengeRecognisedStateId;
        uint256 challengeId;
        uint256 targetTransitionIdAtFiling;
        uint256 targetTransitionIdAfter;
        uint256 nextConsequenceId;
        uint256 nextStandingUpdateId;
        AVAChallengeExtension.ChallengeStatus status;
        AVAChallengeExtension.ChallengeOutcome outcome;
    }

    struct RestorationTraceRecord {
        uint256 targetRecognisedStateId;
        uint256 challengeRecognisedStateId;
        uint256 challengeId;
        uint256 correctionStateTransitionId;
        uint256 restorationChallengeTransitionId;
        uint256 restorationStateTransitionId;
        AVAChallengeExtension.ChallengeStatus challengeStatus;
        AVACoreTypes.RecognisedStateStatus targetStatus;
        AVACoreTypes.RecognisedStateStatus challengeStateStatus;
    }

    function artifactPath() external pure returns (string memory) {
        return "generated/canonical-scenario-traces.json";
    }

    function runTrace() external returns (string memory) {
        HonestReviewTraceRecord memory honest = _honestReviewTraceRecord();
        UpheldChallengeTraceRecord memory upheld = _upheldChallengeTraceRecord();
        MaliciousChallengeTraceRecord memory malicious = _maliciousChallengeTraceRecord();
        RestorationTraceRecord memory restoration = _restorationTraceRecord();
        return string.concat(
            '{"schema":"ava-canonical-trace-v2","scenarios":[',
            _honestJson(honest),
            ",",
            _upheldJson(upheld),
            ",",
            _maliciousJson(malicious),
            ",",
            _restorationJson(restoration),
            "]}"
        );
    }

    function honestReviewTraceRecord() external returns (HonestReviewTraceRecord memory) {
        return _honestReviewTraceRecord();
    }

    function upheldChallengeTraceRecord() external returns (UpheldChallengeTraceRecord memory) {
        return _upheldChallengeTraceRecord();
    }

    function maliciousChallengeTraceRecord() external returns (MaliciousChallengeTraceRecord memory) {
        return _maliciousChallengeTraceRecord();
    }

    function restorationTraceRecord() external returns (RestorationTraceRecord memory) {
        return _restorationTraceRecord();
    }

    function _honestReviewTraceRecord() private returns (HonestReviewTraceRecord memory record) {
        _deployCanonicalPeerReview();
        ReviewPath memory path = _createReviewPath("canonical-honest", false);
        uint256 transitionId = _vestState(path.recognisedStateId, "canonical-honest");
        AVACoreTypes.RecognisedStateRecord memory state = governanceKernel.getRecognisedState(path.recognisedStateId);
        AVACoreTypes.RecognisedStateTransitionRecord memory transition =
            governanceKernel.getRecognisedStateTransition(transitionId);
        record = HonestReviewTraceRecord({
            appId: state.appId,
            reviewPackageId: state.packageId,
            manuscriptObjectId: path.manuscriptObjectId,
            reviewObjectId: path.reviewObjectId,
            recognisedStateId: state.id,
            reviewEvidenceId: path.reviewEvidenceId,
            vestingTransitionId: transitionId,
            recognisedStateStatus: state.status,
            vestingFromStatus: transition.fromStatus,
            vestingToStatus: transition.toStatus
        });
    }

    function _upheldChallengeTraceRecord() private returns (UpheldChallengeTraceRecord memory record) {
        _deployCanonicalPeerReview();
        ReviewPath memory review = _createReviewPath("canonical-upheld", true);
        ChallengePath memory path = _createChallengePath(review.recognisedStateId, "canonical-upheld");
        _screenAndResolve(
            path,
            AVAChallengeExtension.ChallengeOutcome.Upheld,
            AVACoreTypes.RecognisedStateStatus.Downgraded,
            "canonical-upheld"
        );
        AVAChallengeExtension.ChallengeRecord memory challenge = challengeExtension.getChallenge(path.challengeId);
        uint256 consequenceId = panelActor.recordConsequence(
            consequenceExtension,
            AVAConsequenceRecordExtension.ConsequenceInput({
                recognisedStateId: path.challengeRecognisedStateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: PANEL_SUBJECT,
                subjectId: CHALLENGER_SUBJECT,
                evidenceId: path.challengeEvidenceId,
                consequenceKindKey: keccak256("canonical.procedure-correction-record.v1"),
                reasonHash: keccak256("canonical-upheld-consequence"),
                uri: "ipfs://canonical-upheld-consequence"
            })
        );
        uint256 standingUpdateId = panelActor.recordStanding(
            standingExtension,
            AVAStandingRecordExtension.StandingInput({
                recognisedStateId: path.challengeRecognisedStateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: PANEL_SUBJECT,
                subjectId: CHALLENGER_SUBJECT,
                evidenceId: path.challengeEvidenceId,
                dimensionKey: keccak256("canonical.challenge-procedure-standing.v1"),
                delta: 1,
                reasonHash: keccak256("canonical-upheld-standing"),
                uri: "ipfs://canonical-upheld-standing"
            })
        );
        AVACoreTypes.RecognisedStateRecord memory target =
            governanceKernel.getRecognisedState(review.recognisedStateId);
        AVACoreTypes.RecognisedStateRecord memory challengeState =
            governanceKernel.getRecognisedState(path.challengeRecognisedStateId);
        AVAConsequenceRecordExtension.ConsequenceRecord memory consequence =
            consequenceExtension.getConsequence(consequenceId);
        AVAStandingRecordExtension.StandingUpdateRecord memory standing =
            standingExtension.getStandingUpdate(standingUpdateId);
        record = UpheldChallengeTraceRecord({
            appId: target.appId,
            reviewPackageId: target.packageId,
            challengePackageId: challenge.packageId,
            targetRecognisedStateId: target.id,
            challengeObjectId: path.challengeObjectId,
            challengeRecognisedStateId: challengeState.id,
            challengeId: challenge.id,
            challengeEvidenceId: path.challengeEvidenceId,
            challengeTransitionId: challenge.lastTransitionId,
            targetRecognisedStateTransitionId: challenge.targetTransitionIdAfterResolution,
            challengeStateTransitionId: challenge.challengeStateTransitionIdAfterResolution,
            consequenceId: consequenceId,
            standingUpdateId: standingUpdateId,
            consequenceRecognisedStateId: consequence.recognisedStateId,
            standingRecognisedStateId: standing.recognisedStateId,
            outcome: challenge.outcome,
            targetStatus: target.status,
            challengeStateStatus: challengeState.status
        });
    }

    function _maliciousChallengeTraceRecord() private returns (MaliciousChallengeTraceRecord memory record) {
        _deployCanonicalPeerReview();
        ReviewPath memory review = _createReviewPath("canonical-malicious", true);
        ChallengePath memory path = _createChallengePath(review.recognisedStateId, "canonical-malicious");
        _screenAndResolve(
            path,
            AVAChallengeExtension.ChallengeOutcome.MaliciousOrFabricated,
            AVACoreTypes.RecognisedStateStatus.Vested,
            "canonical-malicious"
        );
        AVAChallengeExtension.ChallengeRecord memory challenge = challengeExtension.getChallenge(path.challengeId);
        record = MaliciousChallengeTraceRecord({
            targetRecognisedStateId: challenge.challengedRecognisedStateId,
            challengeRecognisedStateId: challenge.challengeRecognisedStateId,
            challengeId: challenge.id,
            targetTransitionIdAtFiling: challenge.targetTransitionIdAtFiling,
            targetTransitionIdAfter: challenge.targetTransitionIdAfterResolution,
            nextConsequenceId: consequenceExtension.nextConsequenceId(),
            nextStandingUpdateId: standingExtension.nextStandingUpdateId(),
            status: challenge.status,
            outcome: challenge.outcome
        });
    }

    function _restorationTraceRecord() private returns (RestorationTraceRecord memory record) {
        _deployCanonicalPeerReview();
        ReviewPath memory review = _createReviewPath("canonical-restoration", true);
        ChallengePath memory path = _createChallengePath(review.recognisedStateId, "canonical-restoration");
        _screenAndResolve(
            path,
            AVAChallengeExtension.ChallengeOutcome.Upheld,
            AVACoreTypes.RecognisedStateStatus.Downgraded,
            "canonical-restoration"
        );
        AVAChallengeExtension.ChallengeRecord memory resolved = challengeExtension.getChallenge(path.challengeId);
        panelActor.recordRestorationAvailability(
            challengeExtension,
            path.challengeId,
            PANEL_SUBJECT,
            keccak256("canonical-restoration-available")
        );
        uint256 restorationChallengeTransitionId = panelActor.applyRestoration(
            challengeExtension, path.challengeId, PANEL_SUBJECT, keccak256("canonical-restoration-applied")
        );
        AVAChallengeExtension.ChallengeRecord memory restored = challengeExtension.getChallenge(path.challengeId);
        AVAChallengeExtension.ChallengeTransitionRecord memory restorationTransition =
            challengeExtension.getChallengeTransition(restorationChallengeTransitionId);
        AVACoreTypes.RecognisedStateRecord memory target =
            governanceKernel.getRecognisedState(review.recognisedStateId);
        AVACoreTypes.RecognisedStateRecord memory challengeState =
            governanceKernel.getRecognisedState(path.challengeRecognisedStateId);
        record = RestorationTraceRecord({
            targetRecognisedStateId: target.id,
            challengeRecognisedStateId: challengeState.id,
            challengeId: restored.id,
            correctionStateTransitionId: resolved.targetTransitionIdAfterResolution,
            restorationChallengeTransitionId: restorationChallengeTransitionId,
            restorationStateTransitionId: restorationTransition.targetTransitionIdAfter,
            challengeStatus: restored.status,
            targetStatus: target.status,
            challengeStateStatus: challengeState.status
        });
    }

    function _honestJson(HonestReviewTraceRecord memory record) private pure returns (string memory) {
        return string.concat(
            '{"name":"honest_review_vesting","trace":["review_registered","recognised_state_formed","recognition_vested"],"ids":{"reviewObjectId":',
            _u(record.reviewObjectId),
            ',"recognisedStateId":',
            _u(record.recognisedStateId),
            ',"vestingTransitionId":',
            _u(record.vestingTransitionId),
            "}}"
        );
    }

    function _upheldJson(UpheldChallengeTraceRecord memory record) private pure returns (string memory) {
        return string.concat(
            '{"name":"upheld_recursive_challenge_and_downstream_records","trace":["challenge_object_registered","challenge_state_formed","challenge_upheld","target_corrected","challenge_vested","bounded_consequence_recorded","standing_update_recorded"],"ids":{"challengeId":',
            _u(record.challengeId),
            ',"targetRecognisedStateTransitionId":',
            _u(record.targetRecognisedStateTransitionId),
            ',"challengeStateTransitionId":',
            _u(record.challengeStateTransitionId),
            "}}"
        );
    }

    function _maliciousJson(MaliciousChallengeTraceRecord memory record) private pure returns (string memory) {
        return string.concat(
            '{"name":"malicious_or_fabricated_challenge_record_only","trace":["challenge_filed","challenge_screened","malicious_or_fabricated_outcome_recorded","no_automatic_consequence"],"ids":{"challengeId":',
            _u(record.challengeId),
            ',"targetTransitionId":',
            _u(record.targetTransitionIdAfter),
            "}}"
        );
    }

    function _restorationJson(RestorationTraceRecord memory record) private pure returns (string memory) {
        return string.concat(
            '{"name":"explicit_restoration_with_lineage","trace":["challenge_upheld","target_corrected","restoration_available","restoration_transition_recorded","target_restored"],"ids":{"challengeId":',
            _u(record.challengeId),
            ',"correctionStateTransitionId":',
            _u(record.correctionStateTransitionId),
            ',"restorationStateTransitionId":',
            _u(record.restorationStateTransitionId),
            "}}"
        );
    }

    function _u(uint256 value) private pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temporary = value;
        uint256 digits;
        while (temporary != 0) {
            ++digits;
            temporary /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            --digits;
            buffer[digits] = bytes1(uint8(48 + (value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
