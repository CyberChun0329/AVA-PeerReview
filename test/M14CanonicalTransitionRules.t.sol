// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVACoreTransitionRules} from "../src/core/AVACoreTransitionRules.sol";
import {AVACoreTypes} from "../src/core/AVACoreTypes.sol";

contract M14CanonicalTransitionRulesTest {
    function testCanonicalRuleSourceDefinesInitialAndChallengeTargetBoundaries() public pure {
        require(
            AVACoreTransitionRules.isInitialStatus(AVACoreTypes.RecognisedStateStatus.Draft),
            "draft must remain initial"
        );
        require(
            AVACoreTransitionRules.isInitialStatus(AVACoreTypes.RecognisedStateStatus.Challengeable),
            "challengeable must remain initial"
        );
        require(
            !AVACoreTransitionRules.isInitialStatus(AVACoreTypes.RecognisedStateStatus.Vested),
            "vested became directly formable"
        );
        require(
            AVACoreTransitionRules.isChallengeTarget(AVACoreTypes.RecognisedStateStatus.Vested),
            "vested must remain challengeable"
        );
        require(
            !AVACoreTransitionRules.isChallengeTarget(AVACoreTypes.RecognisedStateStatus.Downgraded),
            "downgraded became a fresh challenge target"
        );
    }

    function testCanonicalRuleSourceKeepsHighImpactStatusesSourceBound() public pure {
        require(
            !AVACoreTransitionRules.isGenericTransition(
                AVACoreTypes.RecognisedStateStatus.Registered,
                AVACoreTypes.RecognisedStateStatus.Downgraded
            ),
            "generic downgrade admitted"
        );
        require(
            AVACoreTransitionRules.isSourceBoundTransition(
                AVACoreTypes.RecognisedStateStatus.Vested,
                AVACoreTypes.RecognisedStateStatus.Voided,
                AVACoreTypes.TransitionKind.ChallengeCorrection
            ),
            "challenge correction missing"
        );
        require(
            AVACoreTransitionRules.isSourceBoundTransition(
                AVACoreTypes.RecognisedStateStatus.Downgraded,
                AVACoreTypes.RecognisedStateStatus.Restored,
                AVACoreTypes.TransitionKind.Restoration
            ),
            "restoration missing"
        );
        require(
            !AVACoreTransitionRules.isSourceBoundTransition(
                AVACoreTypes.RecognisedStateStatus.Registered,
                AVACoreTypes.RecognisedStateStatus.Restored,
                AVACoreTypes.TransitionKind.Restoration
            ),
            "unlinked restoration admitted"
        );
    }
}
