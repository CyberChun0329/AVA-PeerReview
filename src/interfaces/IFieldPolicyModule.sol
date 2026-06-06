// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";

interface IFieldPolicyModule {
    function validateFieldPolicy(
        bytes32 workflowKey,
        AVADataTypes.Role actingRole,
        AVADataTypes.Action action,
        AVADataTypes.AVAStage stage,
        bytes32 objectId,
        uint256 evidenceReceiptId
    ) external view;
}
