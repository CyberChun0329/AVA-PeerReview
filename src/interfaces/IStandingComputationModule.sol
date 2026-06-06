// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";

interface IStandingComputationModule {
    function validateStandingComputation(AVADataTypes.StandingComputationContext calldata context) external view;
}
