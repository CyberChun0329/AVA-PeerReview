// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";
import {IVerificationModule} from "../interfaces/IVerificationModule.sol";

contract DefaultVerificationModule is IVerificationModule {
    function validateVerification(
        bytes32 workflowKey,
        AVADataTypes.Role,
        AVADataTypes.AVAStage,
        bytes32 objectId,
        uint256 evidenceReceiptId
    ) external pure {
        if (workflowKey == bytes32(0) || objectId == bytes32(0) || evidenceReceiptId == 0) {
            revert AVADataTypes.EmptyValue();
        }
    }
}
