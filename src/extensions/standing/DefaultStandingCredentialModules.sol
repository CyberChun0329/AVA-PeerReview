// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RuleModuleIdentity} from "../../interfaces/IRuleModuleIdentity.sol";
import {
    IAVAStandingComputationPolicyModule,
    IAVAStandingCredentialPolicyModule
} from "./IAVAStandingCredentialModules.sol";

contract DefaultStandingComputationPolicyModule is IAVAStandingComputationPolicyModule, RuleModuleIdentity {
    function validateStandingComputation(StandingComputationContext calldata) external pure {}
}

contract DefaultStandingCredentialPolicyModule is IAVAStandingCredentialPolicyModule, RuleModuleIdentity {
    function validateStandingCredential(StandingCredentialContext calldata) external pure {}
}
