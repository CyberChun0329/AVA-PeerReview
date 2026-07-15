// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRuleModuleIdentity} from "../../interfaces/IRuleModuleIdentity.sol";

interface IAVAExtensionPolicyModule is IRuleModuleIdentity {
    struct ExtensionPolicyContext {
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 capabilityKey;
        bytes32 actionKey;
        bytes32 recordTypeKey;
        bytes32 scopeKey;
        bytes32 sourceTypeKey;
        uint256 recognisedStateId;
        uint256 recognisedStateTransitionId;
        bytes32 subjectId;
        uint256 evidenceId;
        uint256 disclosurePolicyId;
        uint256 sourceRecordId;
        uint256 unsignedValue;
        uint64 validUntil;
        bytes32 payloadHash;
        bytes32 contextHash;
        bytes32 authorityId;
        address actor;
    }

    function validateExtensionRecord(ExtensionPolicyContext calldata context) external view;
}
