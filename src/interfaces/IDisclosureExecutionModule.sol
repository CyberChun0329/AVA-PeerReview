// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";

interface IDisclosureExecutionModule {
    struct DisclosureExecutionContext {
        bytes32 workflowKey;
        AVADataTypes.DisclosureExecutionKind kind;
        AVADataTypes.DisclosureTargetKind targetKind;
        uint256 targetId;
        uint256 disclosurePolicyId;
        bytes32 subjectId;
        bytes32 subjectCommitment;
        bytes32 nullifierHash;
        uint256 proofReceiptId;
        address actor;
    }

    function validateDisclosureExecution(DisclosureExecutionContext calldata context) external view;
}
