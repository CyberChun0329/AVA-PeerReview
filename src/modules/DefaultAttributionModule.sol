// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RuleModuleIdentity} from "../interfaces/IRuleModuleIdentity.sol";

import {AVADataTypes} from "../AVADataTypes.sol";
import {IAttributionModule} from "../interfaces/IAttributionModule.sol";

contract DefaultAttributionModule is IAttributionModule, RuleModuleIdentity {
    function validateAttribution(AttributionContext calldata context)
        external
        pure
        returns (bytes32 attributedObjectId)
    {
        if (
            context.workflowKey == bytes32(0) || context.packageId == 0 || context.objectId == bytes32(0)
                || context.subjectId == bytes32(0) || context.actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
        return context.objectId;
    }
}
