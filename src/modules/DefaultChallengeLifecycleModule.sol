// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RuleModuleIdentity} from "../interfaces/IRuleModuleIdentity.sol";

import {AVADataTypes} from "../AVADataTypes.sol";
import {AVASubstrateTransitionRules} from "../AVASubstrateTransitionRules.sol";
import {IChallengeLifecycleModule} from "../interfaces/IChallengeLifecycleModule.sol";

contract DefaultChallengeLifecycleModule is IChallengeLifecycleModule, RuleModuleIdentity {
    function validateChallengeAction(ChallengeLifecycleContext calldata context) external pure {
        if (context.workflowKey == bytes32(0)) revert AVADataTypes.EmptyValue();

        if (context.action == AVADataTypes.Action.FileChallenge) {
            _requireAction(
                context.fromLifecycleStatus == AVADataTypes.ChallengeLifecycleStatus.None
                    && context.toLifecycleStatus == AVADataTypes.ChallengeLifecycleStatus.ConcernFiled
                    && context.outcome == AVADataTypes.ChallengeOutcome.None
                    && _isChallengeTargetStatus(context.challengedStateStatus)
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
            bool validStateEffect = context.outcome == AVADataTypes.ChallengeOutcome.Upheld
                ? AVASubstrateTransitionRules.isChallengeCorrection(
                    context.challengedStateStatus, context.proposedStateStatus, context.outcome
                )
                : context.proposedStateStatus == context.challengedStateStatus;
            _requireAction(
                context.fromLifecycleStatus == AVADataTypes.ChallengeLifecycleStatus.AdmissibilityScreening
                    && context.toLifecycleStatus == AVADataTypes.ChallengeLifecycleStatus.Resolved && validOutcome
                    && validStateEffect && context.actor != context.filedBy
            );
            return;
        }

        if (context.action == AVADataTypes.Action.ApplyRestoration) {
            _requireAction(
                context.fromLifecycleStatus == AVADataTypes.ChallengeLifecycleStatus.Resolved
                    && context.toLifecycleStatus == AVADataTypes.ChallengeLifecycleStatus.RestorationApplied
                    && AVASubstrateTransitionRules.isRestorationShape(
                        context.outcome, context.challengedStateStatus, context.proposedStateStatus
                    )
            );
            return;
        }

        if (context.action == AVADataTypes.Action.CloseChallenge) {
            bool preResolutionClose =
                (context.fromLifecycleStatus == AVADataTypes.ChallengeLifecycleStatus.ConcernFiled
                    || context.fromLifecycleStatus == AVADataTypes.ChallengeLifecycleStatus.AdmissibilityScreening)
                    && context.outcome == AVADataTypes.ChallengeOutcome.None;
            bool postResolutionClose =
                (context.fromLifecycleStatus == AVADataTypes.ChallengeLifecycleStatus.Resolved
                    || context.fromLifecycleStatus == AVADataTypes.ChallengeLifecycleStatus.RestorationApplied)
                    && context.outcome != AVADataTypes.ChallengeOutcome.None;
            _requireAction(
                (preResolutionClose || postResolutionClose)
                    && context.toLifecycleStatus == AVADataTypes.ChallengeLifecycleStatus.Closed
                    && context.proposedStateStatus == context.challengedStateStatus
            );
            return;
        }

        revert AVADataTypes.InvalidState(uint256(context.action));
    }

    function _requireAction(bool condition) internal pure {
        if (!condition) revert AVADataTypes.InvalidState(0);
    }

    function _isChallengeTargetStatus(AVADataTypes.RecognisedStateStatus status) internal pure returns (bool) {
        return AVASubstrateTransitionRules.isChallengeTarget(status);
    }
}
