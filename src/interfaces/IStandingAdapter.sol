// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";

interface IStandingAdapter {
    function validateStandingUpdate(
        AVADataTypes.Role actingRole,
        uint256 recognisedStateId,
        bytes32 subjectId,
        string calldata dimension,
        int256 delta,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri,
        address actor
    ) external view;
}
