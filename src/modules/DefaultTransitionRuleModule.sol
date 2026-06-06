// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";
import {ITransitionRuleModule} from "../interfaces/ITransitionRuleModule.sol";

contract DefaultTransitionRuleModule is ITransitionRuleModule {
    function validateTransition(
        bytes32 workflowKey,
        AVADataTypes.Action,
        AVADataTypes.RecognisedStateStatus fromStatus,
        AVADataTypes.RecognisedStateStatus toStatus,
        AVADataTypes.ChallengeOutcome
    ) external pure {
        if (
            workflowKey == bytes32(0) || fromStatus == AVADataTypes.RecognisedStateStatus.None
                || toStatus == AVADataTypes.RecognisedStateStatus.None
        ) {
            revert AVADataTypes.EmptyValue();
        }
    }
}
