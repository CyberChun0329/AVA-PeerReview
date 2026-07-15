// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVACoreTypes} from "../AVACoreTypes.sol";
import {IRuleModuleIdentity} from "../../interfaces/IRuleModuleIdentity.sol";

interface IAVATransitionGuard is IRuleModuleIdentity {
    function validateTransition(
        uint256 packageId,
        uint256 recognisedStateId,
        AVACoreTypes.RecognisedStateStatus fromStatus,
        AVACoreTypes.RecognisedStateStatus toStatus,
        AVACoreTypes.TransitionKind kind
    ) external view;
}
