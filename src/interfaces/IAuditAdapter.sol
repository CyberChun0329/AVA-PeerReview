// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";

interface IAuditAdapter {
    function validateAuditRecord(
        bytes32 workflowKey,
        AVADataTypes.Role actingRole,
        AVADataTypes.Action action,
        bytes32 objectId,
        uint256 evidenceReceiptId,
        bytes32 attestationHash,
        address actor
    ) external view;
}
