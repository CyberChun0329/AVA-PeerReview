// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";
import {IDisclosureExecutionModule} from "../interfaces/IDisclosureExecutionModule.sol";

contract DefaultDisclosureExecutionModule is IDisclosureExecutionModule {
    function validateDisclosureExecution(DisclosureExecutionContext calldata context) external pure {
        if (
            context.workflowKey == bytes32(0) || context.kind == AVADataTypes.DisclosureExecutionKind.None
                || context.targetKind == AVADataTypes.DisclosureTargetKind.None || context.disclosurePolicyId == 0
                || context.actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
        if (
            context.targetKind != AVADataTypes.DisclosureTargetKind.Workflow && context.targetId == 0
        ) {
            revert AVADataTypes.EmptyValue();
        }
        if (
            context.kind == AVADataTypes.DisclosureExecutionKind.AccessGrant
                && context.subjectId == bytes32(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
        if (
            context.kind == AVADataTypes.DisclosureExecutionKind.AnonymousChallengeUse
                && (context.subjectCommitment == bytes32(0) || context.nullifierHash == bytes32(0)
                    || context.proofReceiptId == 0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
    }
}

contract KindRejectingDisclosureExecutionModule is IDisclosureExecutionModule {
    AVADataTypes.DisclosureExecutionKind public immutable blockedKind;

    constructor(AVADataTypes.DisclosureExecutionKind blockedKind_) {
        blockedKind = blockedKind_;
    }

    function validateDisclosureExecution(DisclosureExecutionContext calldata context) external view {
        if (context.kind == blockedKind) revert AVADataTypes.InvalidState(uint256(blockedKind));
    }
}
