// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";

interface IAllocationAdapter {
    function validateAllocation(
        AVADataTypes.Role actingRole,
        uint256 recognisedStateId,
        AVADataTypes.AllocationKind allocationKind,
        bytes32 subjectId,
        uint256 amountOrUnits,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri,
        address actor
    ) external view;
}
