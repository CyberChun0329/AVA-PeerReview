// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVACoreTypes} from "./AVACoreTypes.sol";

/// @notice Non-delegable recognised-state graph shared by the kernel and its extensions.
library AVACoreTransitionRules {
    function isInitialStatus(AVACoreTypes.RecognisedStateStatus status) internal pure returns (bool) {
        return status == AVACoreTypes.RecognisedStateStatus.Draft
            || status == AVACoreTypes.RecognisedStateStatus.Registered
            || status == AVACoreTypes.RecognisedStateStatus.Provisional
            || status == AVACoreTypes.RecognisedStateStatus.Challengeable;
    }

    function isGenericTransition(
        AVACoreTypes.RecognisedStateStatus fromStatus,
        AVACoreTypes.RecognisedStateStatus toStatus
    ) internal pure returns (bool) {
        if (fromStatus == AVACoreTypes.RecognisedStateStatus.Draft) {
            return toStatus == AVACoreTypes.RecognisedStateStatus.Registered;
        }
        if (fromStatus == AVACoreTypes.RecognisedStateStatus.Registered) {
            return toStatus == AVACoreTypes.RecognisedStateStatus.Provisional
                || toStatus == AVACoreTypes.RecognisedStateStatus.Challengeable;
        }
        if (fromStatus == AVACoreTypes.RecognisedStateStatus.Provisional) {
            return toStatus == AVACoreTypes.RecognisedStateStatus.Challengeable;
        }
        if (fromStatus == AVACoreTypes.RecognisedStateStatus.Challengeable) {
            return toStatus == AVACoreTypes.RecognisedStateStatus.Frozen;
        }
        if (fromStatus == AVACoreTypes.RecognisedStateStatus.Frozen) {
            return toStatus == AVACoreTypes.RecognisedStateStatus.Challengeable;
        }
        return false;
    }

    function isVestingSource(AVACoreTypes.RecognisedStateStatus status) internal pure returns (bool) {
        return status == AVACoreTypes.RecognisedStateStatus.Registered
            || status == AVACoreTypes.RecognisedStateStatus.Provisional
            || status == AVACoreTypes.RecognisedStateStatus.Challengeable;
    }

    function isChallengeTarget(AVACoreTypes.RecognisedStateStatus status) internal pure returns (bool) {
        return status == AVACoreTypes.RecognisedStateStatus.Challengeable
            || status == AVACoreTypes.RecognisedStateStatus.Vested
            || status == AVACoreTypes.RecognisedStateStatus.Restored;
    }

    function isSourceBoundTransition(
        AVACoreTypes.RecognisedStateStatus fromStatus,
        AVACoreTypes.RecognisedStateStatus toStatus,
        AVACoreTypes.TransitionKind kind
    ) internal pure returns (bool) {
        if (kind == AVACoreTypes.TransitionKind.Generic) return isGenericTransition(fromStatus, toStatus);
        if (kind == AVACoreTypes.TransitionKind.Vesting) {
            return toStatus == AVACoreTypes.RecognisedStateStatus.Vested && isVestingSource(fromStatus);
        }
        if (kind == AVACoreTypes.TransitionKind.ChallengeCorrection) {
            return isChallengeTarget(fromStatus)
                && (toStatus == AVACoreTypes.RecognisedStateStatus.Downgraded
                    || toStatus == AVACoreTypes.RecognisedStateStatus.Voided);
        }
        if (kind == AVACoreTypes.TransitionKind.Restoration) {
            if (
                fromStatus == AVACoreTypes.RecognisedStateStatus.Downgraded
                    || fromStatus == AVACoreTypes.RecognisedStateStatus.Voided
            ) {
                return toStatus == AVACoreTypes.RecognisedStateStatus.Challengeable
                    || toStatus == AVACoreTypes.RecognisedStateStatus.Restored;
            }
            return fromStatus == AVACoreTypes.RecognisedStateStatus.Vested
                && toStatus == AVACoreTypes.RecognisedStateStatus.Restored;
        }
        return false;
    }
}
