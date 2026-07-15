// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../src/AVADataTypes.sol";
import {AVAChallengeWorkflow} from "../src/AVAChallengeWorkflow.sol";
import {Actor, AVASkeletonFixture} from "./helpers/AVASkeletonFixture.sol";

contract AVASkeletonChallengeLineageTest is AVASkeletonFixture {
    function testChallengeDecisionHashBindsTargetTransitionId() public view {
        bytes32 first = _computeChallengeDecisionHash(
            AVAChallengeWorkflow.ChallengeDecisionContext({
                challengeId: 1,
                challengePackageId: 2,
                targetPackageId: 3,
                action: AVADataTypes.Action.ResolveChallenge,
                lifecycleStatus: AVADataTypes.ChallengeLifecycleStatus.AdmissibilityScreening,
                challengeTransitionId: 4,
                fromStatus: AVADataTypes.RecognisedStateStatus.Challengeable,
                toStatus: AVADataTypes.RecognisedStateStatus.Downgraded,
                outcome: AVADataTypes.ChallengeOutcome.Upheld,
                evidenceReceiptId: 5,
                targetTransitionId: 6,
                reasonHash: keccak256("reason")
            })
        );
        bytes32 second = _computeChallengeDecisionHash(
            AVAChallengeWorkflow.ChallengeDecisionContext({
                challengeId: 1,
                challengePackageId: 2,
                targetPackageId: 3,
                action: AVADataTypes.Action.ResolveChallenge,
                lifecycleStatus: AVADataTypes.ChallengeLifecycleStatus.AdmissibilityScreening,
                challengeTransitionId: 4,
                fromStatus: AVADataTypes.RecognisedStateStatus.Challengeable,
                toStatus: AVADataTypes.RecognisedStateStatus.Downgraded,
                outcome: AVADataTypes.ChallengeOutcome.Upheld,
                evidenceReceiptId: 5,
                targetTransitionId: 7,
                reasonHash: keccak256("reason")
            })
        );
        require(first != second, "decision hash ignored target transition");
    }

    function testChallengeDecisionHashBindsChallengeLifecycleVersion() public view {
        AVAChallengeWorkflow.ChallengeDecisionContext memory context = AVAChallengeWorkflow.ChallengeDecisionContext({
            challengeId: 1,
            challengePackageId: 2,
            targetPackageId: 3,
            action: AVADataTypes.Action.CloseChallenge,
            lifecycleStatus: AVADataTypes.ChallengeLifecycleStatus.ConcernFiled,
            challengeTransitionId: 0,
            fromStatus: AVADataTypes.RecognisedStateStatus.Challengeable,
            toStatus: AVADataTypes.RecognisedStateStatus.Challengeable,
            outcome: AVADataTypes.ChallengeOutcome.None,
            evidenceReceiptId: 4,
            targetTransitionId: 5,
            reasonHash: keccak256("reason")
        });
        bytes32 filed = _computeChallengeDecisionHash(context);
        context.lifecycleStatus = AVADataTypes.ChallengeLifecycleStatus.AdmissibilityScreening;
        context.challengeTransitionId = 6;
        bytes32 screened = _computeChallengeDecisionHash(context);
        require(filed != screened, "decision hash ignored challenge lifecycle version");
    }

    function testRejectedChallengeCannotRestoreStateMutatedByIndependentUpheldChallenge() public {
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 challengeA = _fileChallengeForState(recognisedStateId, "lineage-challenge-a");
        (Actor secondChallenger, bytes32 secondChallengerSubject) =
            _newChallengerActor("lineage-challenge-b");
        uint256 challengeB = _fileChallengeForStateAs(
            recognisedStateId, "lineage-challenge-b", secondChallenger, secondChallengerSubject
        );

        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeA, EDITOR_AUTHORITY);
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeB, EDITOR_AUTHORITY);
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeB,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Voided,
            keccak256("panel-authority"),
            "ipfs://lineage-challenge-b-upheld"
        );
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeA,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Voided,
            keccak256("panel-authority"),
            "ipfs://lineage-challenge-a-rejected"
        );

        try challengeWorkflow.applyRestoration(
            AVADataTypes.Role.Panel, challengeA, keccak256("panel-authority"), "ipfs://lineage-stale-restoration"
        ) {
            revert("stale rejected challenge restored independent correction");
        } catch {}

        require(
            stateMachine.getRecognisedState(recognisedStateId).status == AVADataTypes.RecognisedStateStatus.Voided,
            "independent correction was overwritten"
        );
        challengeWorkflow.closeChallenge(
            AVADataTypes.Role.Panel, challengeA, keccak256("panel-authority"), "ipfs://lineage-stale-challenge-closed"
        );
        require(
            challengeWorkflow.getChallenge(challengeA).status == AVADataTypes.ChallengeLifecycleStatus.Closed,
            "stale record-only challenge could not close"
        );
    }

    function testStaleUpheldChallengeCannotMutateNewerTargetVersion() public {
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 staleChallenge = _fileChallengeForState(recognisedStateId, "lineage-stale-upheld");
        (Actor secondChallenger, bytes32 secondChallengerSubject) =
            _newChallengerActor("lineage-current-upheld");
        uint256 correctionChallenge = _fileChallengeForStateAs(
            recognisedStateId, "lineage-current-upheld", secondChallenger, secondChallengerSubject
        );
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, staleChallenge, EDITOR_AUTHORITY);
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, correctionChallenge, EDITOR_AUTHORITY);
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            correctionChallenge,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            keccak256("panel-authority"),
            "ipfs://lineage-current-correction"
        );

        try challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            staleChallenge,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Voided,
            keccak256("panel-authority"),
            "ipfs://lineage-stale-correction"
        ) {
            revert("stale upheld challenge mutated newer target version");
        } catch {}

        require(
            stateMachine.getRecognisedState(recognisedStateId).status == AVADataTypes.RecognisedStateStatus.Downgraded,
            "stale upheld challenge changed target"
        );
    }

    function testUpheldCorrectionRestorationPreservesTransitionLineage() public {
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 challengeId = _fileChallengeForState(recognisedStateId, "lineage-upheld-restoration");
        uint256 filingTransitionId = stateMachine.getRecognisedState(recognisedStateId).lastTransitionId;
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            keccak256("panel-authority"),
            "ipfs://lineage-upheld-resolution"
        );

        AVADataTypes.ChallengeTransitionRecord memory resolution =
            challengeWorkflow.getChallengeTransition(challengeWorkflow.getChallenge(challengeId).lastTransitionId);
        require(resolution.targetTransitionIdBefore == filingTransitionId, "resolution lost filing transition");
        require(resolution.targetTransitionIdAfter != filingTransitionId, "correction transition not linked");

        challengeWorkflow.applyRestoration(
            AVADataTypes.Role.Panel, challengeId, keccak256("panel-authority"), "ipfs://lineage-upheld-restoration"
        );
        AVADataTypes.ChallengeTransitionRecord memory restoration =
            challengeWorkflow.getChallengeTransition(challengeWorkflow.getChallenge(challengeId).lastTransitionId);
        require(
            restoration.targetTransitionIdBefore == resolution.targetTransitionIdAfter,
            "restoration did not consume correction transition"
        );
        require(
            restoration.targetTransitionIdAfter == stateMachine.getRecognisedState(recognisedStateId).lastTransitionId,
            "restoration did not bind resulting transition"
        );
        require(
            stateMachine.getRecognisedState(recognisedStateId).status
                == AVADataTypes.RecognisedStateStatus.Challengeable,
            "upheld correction did not restore filing status"
        );
    }

    function testAlreadyRestoredTargetRecordsRestorationWithoutNoOpStateTransition() public {
        (uint256 recognisedStateId, uint256 evidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            DEFAULT_WORKFLOW, AVADataTypes.RecognisedStateStatus.Restored, "lineage-already-restored"
        );
        evidenceId;
        uint256 challengeId = _fileChallengeForState(recognisedStateId, "lineage-restored-challenge");
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Restored,
            keccak256("panel-authority"),
            "ipfs://lineage-restored-resolution"
        );
        uint256 lastStateTransitionId = stateMachine.getRecognisedState(recognisedStateId).lastTransitionId;

        challengeWorkflow.applyRestoration(
            AVADataTypes.Role.Panel, challengeId, keccak256("panel-authority"), "ipfs://lineage-restored-record"
        );

        AVADataTypes.ChallengeTransitionRecord memory restoration =
            challengeWorkflow.getChallengeTransition(challengeWorkflow.getChallenge(challengeId).lastTransitionId);
        require(restoration.targetTransitionIdBefore == lastStateTransitionId, "record-only restoration source wrong");
        require(
            restoration.targetTransitionIdAfter == lastStateTransitionId,
            "record-only restoration wrote state transition"
        );
        require(
            stateMachine.getRecognisedState(recognisedStateId).lastTransitionId == lastStateTransitionId,
            "already-restored target wrote no-op state transition"
        );
    }

    function _fileChallengeForState(uint256 recognisedStateId, string memory seed) internal returns (uint256) {
        return _fileChallengeForStateAs(recognisedStateId, seed, challengerActor, CHALLENGER_SUBJECT);
    }

    function _fileChallengeForStateAs(
        uint256 recognisedStateId,
        string memory seed,
        Actor actor,
        bytes32 challengerSubjectId
    ) internal returns (uint256) {
        uint256 evidenceId = actor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256(bytes(seed)),
            string.concat("ipfs://", seed),
            "review-quality-challenge",
            0
        );
        return actor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            recognisedStateId,
            challengerSubjectId,
            evidenceId,
            0
        );
    }
}
