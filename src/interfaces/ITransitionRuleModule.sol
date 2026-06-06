// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";

interface ITransitionRuleModule {
    /// @notice Validator-only recognised-state transition seam.
    /// @dev Success means no transition veto only. Substrate hard gates still
    /// own status mutation, transition records, and high-impact status limits.
    function validateTransition(
        bytes32 workflowKey,
        AVADataTypes.Action action,
        AVADataTypes.RecognisedStateStatus fromStatus,
        AVADataTypes.RecognisedStateStatus toStatus,
        AVADataTypes.ChallengeOutcome outcome
    ) external view;
}
