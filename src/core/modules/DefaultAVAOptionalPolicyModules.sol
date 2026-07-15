// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RuleModuleIdentity} from "../../interfaces/IRuleModuleIdentity.sol";
import {
    IAVAFieldPolicyModule,
    IAVAAntiAbusePolicyModule
} from "../interfaces/IAVACoreRuleModules.sol";

contract DefaultAVAFieldPolicyModule is IAVAFieldPolicyModule, RuleModuleIdentity {
    function validateFieldPolicy(FieldPolicyContext calldata) external pure {}
}

contract DefaultAVAAntiAbusePolicyModule is IAVAAntiAbusePolicyModule, RuleModuleIdentity {
    function validateAntiAbuse(AntiAbuseContext calldata) external pure {}
}
