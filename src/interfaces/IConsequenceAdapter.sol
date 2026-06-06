// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";

interface IConsequenceAdapter {
    function validateConsequence(
        AVADataTypes.Role actingRole,
        uint256 recognisedStateId,
        AVADataTypes.ConsequenceKind kind,
        bytes32 subjectId,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri,
        address actor
    ) external view;
}
