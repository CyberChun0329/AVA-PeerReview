// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";

interface IEvidencePolicyModule {
    function validateEvidencePolicy(
        bytes32 workflowKey,
        AVADataTypes.Role actingRole,
        AVADataTypes.Action action,
        uint256 evidenceReceiptId,
        bytes32 evidenceTypeHash,
        address actor
    ) external view;
}
