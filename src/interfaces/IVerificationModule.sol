// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";

interface IVerificationModule {
    function validateVerification(
        bytes32 workflowKey,
        AVADataTypes.Role actingRole,
        AVADataTypes.AVAStage stage,
        bytes32 objectId,
        uint256 evidenceReceiptId
    ) external view;
}
