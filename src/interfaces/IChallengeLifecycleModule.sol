// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";

interface IChallengeLifecycleModule {
    struct ChallengeLifecycleContext {
        bytes32 workflowKey;
        AVADataTypes.Action action;
        AVADataTypes.ChallengeLifecycleStatus fromLifecycleStatus;
        AVADataTypes.ChallengeLifecycleStatus toLifecycleStatus;
        AVADataTypes.ChallengeOutcome outcome;
        AVADataTypes.RecognisedStateStatus challengedStateStatus;
        AVADataTypes.RecognisedStateStatus proposedStateStatus;
        address actor;
        address filedBy;
    }

    /// @notice Validator-only challenge lifecycle seam.
    /// @dev Success means no lifecycle veto only. It must not mutate
    /// recognised states, sanction anyone, update standing, or reveal identity.
    function validateChallengeAction(ChallengeLifecycleContext calldata context) external view;
}
