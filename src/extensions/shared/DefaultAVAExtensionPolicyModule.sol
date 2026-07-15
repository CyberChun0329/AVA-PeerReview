// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RuleModuleIdentity} from "../../interfaces/IRuleModuleIdentity.sol";
import {
    IAVAStandingComputationPolicyModule,
    IAVAStandingCredentialPolicyModule
} from "../standing/IAVAStandingCredentialModules.sol";
import {IAVAExtensionPolicyModule} from "./IAVAExtensionPolicyModule.sol";

/// @notice Shared stateless implementation for default downstream extension policy capabilities.
/// @dev Capability keys remain independently bound and replaceable in each rule package.
contract DefaultAVAExtensionPolicyModule is
    IAVAExtensionPolicyModule,
    IAVAStandingComputationPolicyModule,
    IAVAStandingCredentialPolicyModule,
    RuleModuleIdentity
{
    function validateExtensionRecord(ExtensionPolicyContext calldata) external pure {}

    function validateStandingComputation(StandingComputationContext calldata) external pure {}

    function validateStandingCredential(StandingCredentialContext calldata) external pure {}
}
