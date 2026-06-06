// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";

interface IValueExecutionAdapter {
    /// @notice Validator-only value-readiness seam.
    /// @dev In this demo, asset, payer, amount, mode, and executionReference
    /// are record/readiness fields only. Success must not transfer value,
    /// execute a queue, execute a sanction, or grant reward entitlement.
    function validateValueExecution(AVADataTypes.ValueExecutionContext calldata context) external view;
}
