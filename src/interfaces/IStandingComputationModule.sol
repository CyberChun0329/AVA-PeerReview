// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";
import {IRuleModuleIdentity} from "./IRuleModuleIdentity.sol";

interface IStandingComputationModule is IRuleModuleIdentity {
    function validateStandingComputation(AVADataTypes.StandingComputationContext calldata context) external view;
}
