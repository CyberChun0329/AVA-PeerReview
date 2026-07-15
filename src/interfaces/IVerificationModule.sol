// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";
import {IRuleModuleIdentity} from "./IRuleModuleIdentity.sol";

interface IVerificationModule is IRuleModuleIdentity {
    struct VerificationContext {
        bytes32 workflowKey;
        uint256 packageId;
        AVADataTypes.Role actingRole;
        AVADataTypes.Action action;
        AVADataTypes.AVAStage stage;
        bytes32 objectId;
        bytes32 subjectId;
        uint256 evidenceReceiptId;
        uint256 disclosurePolicyId;
        address actor;
    }

    function validateVerification(VerificationContext calldata context) external view;
}
