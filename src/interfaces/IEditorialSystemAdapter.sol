// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";
import {IRuleModuleIdentity} from "./IRuleModuleIdentity.sol";

interface IEditorialSystemAdapter is IRuleModuleIdentity {
    function validateEditorialReference(
        bytes32 workflowKey,
        AVADataTypes.Role actingRole,
        AVADataTypes.Action action,
        bytes32 objectId,
        string calldata externalReferenceURI,
        address actor
    ) external view;
}
