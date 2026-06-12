// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVATransitionMatrix} from "../script/AVATransitionMatrix.s.sol";

contract M12TransitionMatrixTest {
    function testM122TransitionMatrixContainsSubstrateHardBoundaries() public {
        string memory matrix = new AVATransitionMatrix().matrixCsv();
        _assertContains(
            matrix,
            "recognised_state,RegisterRecognisedState,None,Vested,None,rejected,no-ledger,high-impact-status-must-be-transition-generated"
        );
        _assertContains(
            matrix,
            "generic_transition,TransitionRecognisedState,Registered,Downgraded,None,rejected,no-ledger,correction-status-needs-challenge-path"
        );
        _assertContains(
            matrix,
            "generic_transition,TransitionRecognisedState,Draft,Vested,None,rejected,no-ledger,generic-transition-source-must-be-registered"
        );
        _assertContains(
            matrix,
            "generic_transition,TransitionRecognisedState,Frozen,Vested,None,rejected,no-ledger,generic-transition-source-must-be-registered"
        );
        _assertContains(
            matrix,
            "challenge,ResolveChallenge,Challengeable,Downgraded,Upheld,allowed,challenge-and-recognised-state-transition,upheld-challenge-can-mutate-state"
        );
        _assertContains(
            matrix,
            "challenge,ResolveChallenge,Challengeable,Challengeable,RejectedGoodFaith,allowed,challenge-transition-only,failed-good-faith-challenge-no-state-mutation"
        );
        _assertContains(
            matrix,
            "restoration,ApplyRestoration,Downgraded,Restored,Upheld,allowed,challenge-and-recognised-state-transition,explicit-restoration-after-correction"
        );
    }

    function testM122TransitionMatrixHashIsStable() public {
        bytes32 expectedHash = 0x6d648d1dfd79f57bb1bb6f3db34d638b6d6ea78ac13337ef35285c09431b944f;
        require(new AVATransitionMatrix().matrixHash() == expectedHash, "transition matrix hash drifted");
    }

    function _assertContains(string memory text, string memory needle) internal pure {
        require(_contains(bytes(text), bytes(needle)), "missing matrix row");
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
