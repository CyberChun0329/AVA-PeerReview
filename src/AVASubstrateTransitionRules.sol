// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "./AVADataTypes.sol";

/// @notice Non-delegable recognised-state transition boundaries shared by the substrate.
library AVASubstrateTransitionRules {
    function requireExternallyRegistrableStatus(AVADataTypes.RecognisedStateStatus status) internal pure {
        if (!isExternallyRegistrableStatus(status)) {
            revert AVADataTypes.InvalidState(uint256(status));
        }
    }

    function isExternallyRegistrableStatus(AVADataTypes.RecognisedStateStatus status) internal pure returns (bool) {
        return status != AVADataTypes.RecognisedStateStatus.None && status != AVADataTypes.RecognisedStateStatus.Vested
            && status != AVADataTypes.RecognisedStateStatus.Restored
            && status != AVADataTypes.RecognisedStateStatus.Downgraded
            && status != AVADataTypes.RecognisedStateStatus.Voided;
    }

    function requireGenericTransition(
        AVADataTypes.RecognisedStateStatus fromStatus,
        AVADataTypes.RecognisedStateStatus toStatus
    ) internal pure {
        if (fromStatus != AVADataTypes.RecognisedStateStatus.Registered) {
            revert AVADataTypes.InvalidState(uint256(fromStatus));
        }
        if (!isGenericTransition(fromStatus, toStatus)) {
            revert AVADataTypes.InvalidState(uint256(toStatus));
        }
    }

    function isGenericTransition(
        AVADataTypes.RecognisedStateStatus fromStatus,
        AVADataTypes.RecognisedStateStatus toStatus
    ) internal pure returns (bool) {
        return fromStatus == AVADataTypes.RecognisedStateStatus.Registered
            && toStatus == AVADataTypes.RecognisedStateStatus.Vested;
    }

    function isChallengeTarget(AVADataTypes.RecognisedStateStatus status) internal pure returns (bool) {
        return status == AVADataTypes.RecognisedStateStatus.Challengeable
            || status == AVADataTypes.RecognisedStateStatus.Vested
            || status == AVADataTypes.RecognisedStateStatus.Restored;
    }

    function isChallengeCorrection(
        AVADataTypes.RecognisedStateStatus fromStatus,
        AVADataTypes.RecognisedStateStatus toStatus,
        AVADataTypes.ChallengeOutcome outcome
    ) internal pure returns (bool) {
        if (outcome != AVADataTypes.ChallengeOutcome.Upheld) return false;
        if (
            toStatus != AVADataTypes.RecognisedStateStatus.Downgraded
                && toStatus != AVADataTypes.RecognisedStateStatus.Voided
        ) {
            return false;
        }
        if (fromStatus == AVADataTypes.RecognisedStateStatus.Downgraded) {
            return toStatus == AVADataTypes.RecognisedStateStatus.Voided;
        }
        return isChallengeTarget(fromStatus);
    }

    function restorationTargetStatus(AVADataTypes.RecognisedStateStatus targetStatusAtFiling)
        internal
        pure
        returns (AVADataTypes.RecognisedStateStatus)
    {
        if (targetStatusAtFiling == AVADataTypes.RecognisedStateStatus.Challengeable) {
            return AVADataTypes.RecognisedStateStatus.Challengeable;
        }
        if (
            targetStatusAtFiling == AVADataTypes.RecognisedStateStatus.Vested
                || targetStatusAtFiling == AVADataTypes.RecognisedStateStatus.Restored
        ) {
            return AVADataTypes.RecognisedStateStatus.Restored;
        }
        revert AVADataTypes.InvalidState(uint256(targetStatusAtFiling));
    }

    function isRestorationShape(
        AVADataTypes.ChallengeOutcome outcome,
        AVADataTypes.RecognisedStateStatus fromStatus,
        AVADataTypes.RecognisedStateStatus toStatus
    ) internal pure returns (bool) {
        if (
            outcome == AVADataTypes.ChallengeOutcome.RejectedGoodFaith
                || outcome == AVADataTypes.ChallengeOutcome.MaliciousOrFabricated
        ) {
            return (fromStatus == AVADataTypes.RecognisedStateStatus.Challengeable && toStatus == fromStatus)
                || (fromStatus == AVADataTypes.RecognisedStateStatus.Vested
                    && toStatus == AVADataTypes.RecognisedStateStatus.Restored)
                || (fromStatus == AVADataTypes.RecognisedStateStatus.Restored && toStatus == fromStatus);
        }
        return outcome == AVADataTypes.ChallengeOutcome.Upheld
            && (fromStatus == AVADataTypes.RecognisedStateStatus.Downgraded
                || fromStatus == AVADataTypes.RecognisedStateStatus.Voided)
            && (toStatus == AVADataTypes.RecognisedStateStatus.Challengeable
                || toStatus == AVADataTypes.RecognisedStateStatus.Restored);
    }

    function isRestorationTransition(
        AVADataTypes.ChallengeOutcome outcome,
        AVADataTypes.RecognisedStateStatus fromStatus,
        AVADataTypes.RecognisedStateStatus toStatus,
        AVADataTypes.RecognisedStateStatus targetStatusAtFiling
    ) internal pure returns (bool) {
        return toStatus == restorationTargetStatus(targetStatusAtFiling)
            && isRestorationShape(outcome, fromStatus, toStatus);
    }
}
