// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";

interface IPriorityAdapter {
    function validatePriorityRecord(
        AVADataTypes.Role actingRole,
        uint256 recognisedStateId,
        bytes32 subjectId,
        uint256 amountOrUnits,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri,
        address actor
    ) external view;
}
