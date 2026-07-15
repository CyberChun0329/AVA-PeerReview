// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVACoreTypes} from "../AVACoreTypes.sol";
import {IRuleModuleIdentity} from "../../interfaces/IRuleModuleIdentity.sol";

interface IAVAPostTransitionHook is IRuleModuleIdentity {
    struct TransitionContext {
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        uint256 governedObjectId;
        uint256 recognisedStateId;
        uint256 transitionId;
        bytes32 subjectId;
        AVACoreTypes.RecognisedStateStatus fromStatus;
        AVACoreTypes.RecognisedStateStatus toStatus;
        AVACoreTypes.TransitionKind kind;
    }

    function onRecognisedStateTransition(TransitionContext calldata context) external;
}
