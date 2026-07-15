// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";
import {IRuleModuleIdentity} from "./IRuleModuleIdentity.sol";

interface IAntiAbuseModule is IRuleModuleIdentity {
    function validateUse(
        bytes32 workflowKey,
        AVADataTypes.Role actingRole,
        AVADataTypes.Action action,
        bytes32 subjectId,
        bytes32 objectId,
        address actor
    ) external view;
}
