// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RuleModuleIdentity} from "../interfaces/IRuleModuleIdentity.sol";

import {AVADataTypes} from "../AVADataTypes.sol";
import {IVerificationModule} from "../interfaces/IVerificationModule.sol";

contract DefaultVerificationModule is IVerificationModule, RuleModuleIdentity {
    function validateVerification(VerificationContext calldata context) external pure {
        if (
            context.workflowKey == bytes32(0) || context.packageId == 0 || context.objectId == bytes32(0)
                || context.evidenceReceiptId == 0 || context.subjectId == bytes32(0) || context.actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
    }
}
