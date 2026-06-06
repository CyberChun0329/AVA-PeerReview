// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";
import {IAttributionModule} from "../interfaces/IAttributionModule.sol";

contract DefaultAttributionModule is IAttributionModule {
    function validateAttribution(
        bytes32 workflowKey,
        AVADataTypes.Role,
        AVADataTypes.AVAStage,
        bytes32 objectId,
        bytes32 subjectId,
        uint256
    ) external pure returns (bytes32 attributedObjectId) {
        if (workflowKey == bytes32(0) || objectId == bytes32(0) || subjectId == bytes32(0)) {
            revert AVADataTypes.EmptyValue();
        }
        return objectId;
    }
}
