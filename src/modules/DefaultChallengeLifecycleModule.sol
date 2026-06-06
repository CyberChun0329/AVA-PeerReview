// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";
import {IChallengeLifecycleModule} from "../interfaces/IChallengeLifecycleModule.sol";

contract DefaultChallengeLifecycleModule is IChallengeLifecycleModule {
    function validateChallengeAction(ChallengeLifecycleContext calldata context) external pure {
        if (context.workflowKey == bytes32(0)) revert AVADataTypes.EmptyValue();

        if (context.action == AVADataTypes.Action.FileChallenge) {
            _requireAction(
                context.fromLifecycleStatus == AVADataTypes.ChallengeLifecycleStatus.None
                    && context.toLifecycleStatus == AVADataTypes.ChallengeLifecycleStatus.ConcernFiled
                    && context.outcome == AVADataTypes.ChallengeOutcome.None
                    && context.challengedStateStatus == AVADataTypes.RecognisedStateStatus.Challengeable
                    && context.proposedStateStatus == context.challengedStateStatus
            );
            return;
        }

        if (context.action == AVADataTypes.Action.ScreenChallenge) {
            _requireAction(
                context.fromLifecycleStatus == AVADataTypes.ChallengeLifecycleStatus.ConcernFiled
                    && context.toLifecycleStatus == AVADataTypes.ChallengeLifecycleStatus.AdmissibilityScreening
                    && context.outcome == AVADataTypes.ChallengeOutcome.None
                    && context.proposedStateStatus == context.challengedStateStatus
            );
            return;
        }

        if (context.action == AVADataTypes.Action.ResolveChallenge) {
            bool validOutcome = context.outcome == AVADataTypes.ChallengeOutcome.Upheld
                || context.outcome == AVADataTypes.ChallengeOutcome.RejectedGoodFaith
                || context.outcome == AVADataTypes.ChallengeOutcome.Negligent
                || context.outcome == AVADataTypes.ChallengeOutcome.MaliciousOrFabricated;
            _requireAction(
                context.fromLifecycleStatus == AVADataTypes.ChallengeLifecycleStatus.AdmissibilityScreening
                    && context.toLifecycleStatus == AVADataTypes.ChallengeLifecycleStatus.Resolved && validOutcome
                    && (context.outcome == AVADataTypes.ChallengeOutcome.Upheld
                        || context.proposedStateStatus == context.challengedStateStatus)
                    && context.actor != context.filedBy
            );
            return;
        }

        if (context.action == AVADataTypes.Action.ApplyRestoration) {
            bool restoresRejectedChallenge = context.outcome == AVADataTypes.ChallengeOutcome.RejectedGoodFaith
                || context.outcome == AVADataTypes.ChallengeOutcome.MaliciousOrFabricated;
            bool restoresAdverseCorrection = context.outcome == AVADataTypes.ChallengeOutcome.Upheld
                && (
                    context.challengedStateStatus == AVADataTypes.RecognisedStateStatus.Downgraded
                        || context.challengedStateStatus == AVADataTypes.RecognisedStateStatus.Voided
                );
            _requireAction(
                context.fromLifecycleStatus == AVADataTypes.ChallengeLifecycleStatus.Resolved
                    && context.toLifecycleStatus == AVADataTypes.ChallengeLifecycleStatus.RestorationAvailable
                    && (restoresRejectedChallenge || restoresAdverseCorrection)
                    && context.proposedStateStatus == AVADataTypes.RecognisedStateStatus.Restored
            );
            return;
        }

        if (context.action == AVADataTypes.Action.CloseChallenge) {
            _requireAction(
                (context.fromLifecycleStatus == AVADataTypes.ChallengeLifecycleStatus.Resolved
                    || context.fromLifecycleStatus == AVADataTypes.ChallengeLifecycleStatus.RestorationAvailable)
                    && context.toLifecycleStatus == AVADataTypes.ChallengeLifecycleStatus.Closed
                    && context.outcome != AVADataTypes.ChallengeOutcome.None
                    && context.proposedStateStatus == context.challengedStateStatus
            );
            return;
        }

        revert AVADataTypes.InvalidState(uint256(context.action));
    }

    function _requireAction(bool condition) internal pure {
        if (!condition) revert AVADataTypes.InvalidState(0);
    }
}
