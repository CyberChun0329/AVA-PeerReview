// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";
import {IRuleModuleIdentity} from "./IRuleModuleIdentity.sol";

interface IRulePackageLifecycleModule is IRuleModuleIdentity {
    struct RulePackageLifecycleContext {
        bytes32 workflowKey;
        bytes32 modulesHash;
        bytes32 modulesIdentityHash;
        AVADataTypes.RulePackageLifecycleKind kind;
        uint64 version;
        bytes32 compatibilityKey;
        string dependencyURI;
        bool deprecated;
        bytes32 targetWorkflowKey;
        uint256 targetPackageId;
        bytes32 targetModulesHash;
        bytes32 targetModulesIdentityHash;
        uint64 targetVersion;
        bytes32 targetCompatibilityKey;
        AVADataTypes.Role authorityRole;
        address actor;
    }

    /// @notice Validator-only package compatibility seam.
    /// @dev Success means modulesHash/version/compatibilityKey and any target
    /// package context were not vetoed.
    /// It does not grant authority, mutate old packages, or migrate state.
    function validateRulePackageLifecycle(RulePackageLifecycleContext calldata context) external view;
}
