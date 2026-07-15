// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVACoreTypes} from "../src/core/AVACoreTypes.sol";
import {AVAChallengeExtension} from "../src/extensions/challenge/AVAChallengeExtension.sol";
import {AVACanonicalTrace} from "../script/AVACanonicalTrace.s.sol";
import {AVATransitionMatrix} from "../script/AVATransitionMatrix.s.sol";

contract M13TransitionMatrixExecutionTest {
    function testCanonicalMatrixAllowedVestingMatchesPublicKernelExecution() public {
        AVACanonicalTrace.HonestReviewTraceRecord memory record =
            new AVACanonicalTrace().honestReviewTraceRecord();
        require(record.recognisedStateStatus == AVACoreTypes.RecognisedStateStatus.Vested, "vesting failed");
        require(record.vestingTransitionId != 0, "vesting ledger missing");
    }

    function testCanonicalMatrixAllowedCorrectionMatchesPublicChallengeExecution() public {
        AVACanonicalTrace.UpheldChallengeTraceRecord memory record =
            new AVACanonicalTrace().upheldChallengeTraceRecord();
        require(record.outcome == AVAChallengeExtension.ChallengeOutcome.Upheld, "upheld outcome missing");
        require(record.targetStatus == AVACoreTypes.RecognisedStateStatus.Downgraded, "correction failed");
        require(record.targetRecognisedStateTransitionId != 0, "correction ledger missing");
    }

    function testCanonicalMatrixAllowedRestorationMatchesPublicChallengeExecution() public {
        AVACanonicalTrace.RestorationTraceRecord memory record =
            new AVACanonicalTrace().restorationTraceRecord();
        require(record.targetStatus == AVACoreTypes.RecognisedStateStatus.Restored, "restoration failed");
        require(record.restorationStateTransitionId != record.correctionStateTransitionId, "lineage collapsed");
    }

    function testCanonicalMatrixHashIsNonZeroAndDeterministic() public {
        AVATransitionMatrix first = new AVATransitionMatrix();
        AVATransitionMatrix second = new AVATransitionMatrix();
        require(
            first.matrixHash() == 0x9cba1aa4d1a8141ded47fb76ad2a2f2d96a4a83608a76bbf29e1bbe48e73dd97,
            "canonical matrix hash drifted"
        );
        require(first.matrixHash() == second.matrixHash(), "matrix hash is nondeterministic");
    }
}
