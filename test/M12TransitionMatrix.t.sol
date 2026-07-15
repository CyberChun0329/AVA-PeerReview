// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVATransitionMatrix} from "../script/AVATransitionMatrix.s.sol";

contract M12TransitionMatrixTest {
    function testCanonicalTransitionMatrixEnumeratesEveryKernelRuleCombination() public {
        AVATransitionMatrix matrix = new AVATransitionMatrix();
        require(matrix.rowCount() == 330, "canonical transition matrix is not exhaustive");
        string memory csv = matrix.matrixCsv();
        _assertContains(
            csv,
            "initial_formation,FormRecognisedState,None,Vested,InitialFormation,rejected,no-ledger,kernel-shared-transition-rule"
        );
        _assertContains(
            csv,
            "generic_transition,TransitionRecognisedState,Registered,Provisional,Generic,allowed,recognised-state-transition,kernel-shared-transition-rule"
        );
        _assertContains(
            csv,
            "vesting,VestRecognisedState,Challengeable,Vested,Vesting,allowed,recognised-state-transition,kernel-shared-transition-rule"
        );
        _assertContains(
            csv,
            "challenge_target,FileChallenge,Vested,Vested,None,allowed,challenge-lifecycle-and-challenge-state-transition,kernel-shared-transition-rule"
        );
        _assertContains(
            csv,
            "challenge_correction,RequestSourceBoundTransition,Vested,Voided,ChallengeCorrection,allowed,recognised-state-transition,kernel-shared-transition-rule"
        );
        _assertContains(
            csv,
            "restoration,RequestSourceBoundTransition,Downgraded,Restored,Restoration,allowed,recognised-state-transition,kernel-shared-transition-rule"
        );
    }

    function testCanonicalTransitionMatrixContainsNonDelegableHardBoundaries() public {
        string memory csv = new AVATransitionMatrix().matrixCsv();
        _assertContains(
            csv,
            "generic_transition,TransitionRecognisedState,Registered,Downgraded,Generic,rejected,no-ledger,kernel-shared-transition-rule"
        );
        _assertContains(
            csv,
            "vesting,VestRecognisedState,Downgraded,Vested,Vesting,rejected,no-ledger,kernel-shared-transition-rule"
        );
        _assertContains(
            csv,
            "challenge_target,FileChallenge,Downgraded,Downgraded,None,rejected,no-ledger,kernel-shared-transition-rule"
        );
        _assertContains(
            csv,
            "challenge_correction,RequestSourceBoundTransition,Registered,Voided,ChallengeCorrection,rejected,no-ledger,kernel-shared-transition-rule"
        );
        _assertContains(
            csv,
            "restoration,RequestSourceBoundTransition,Registered,Restored,Restoration,rejected,no-ledger,kernel-shared-transition-rule"
        );
    }

    function _assertContains(string memory text, string memory needle) internal pure {
        require(_contains(bytes(text), bytes(needle)), "missing matrix row");
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
