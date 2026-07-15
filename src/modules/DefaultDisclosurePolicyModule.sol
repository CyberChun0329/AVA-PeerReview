// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RuleModuleIdentity} from "../interfaces/IRuleModuleIdentity.sol";

import {AVADataTypes} from "../AVADataTypes.sol";
import {DisclosurePolicyRegistry} from "../DisclosurePolicyRegistry.sol";
import {IDisclosurePolicyModule} from "../interfaces/IDisclosurePolicyModule.sol";

contract DefaultDisclosurePolicyModule is IDisclosurePolicyModule, RuleModuleIdentity {
    DisclosurePolicyRegistry public immutable disclosureRegistry;

    constructor(DisclosurePolicyRegistry disclosureRegistry_) {
        disclosureRegistry = disclosureRegistry_;
    }

    function validateDisclosurePolicy(uint256 disclosurePolicyId) external view {
        if (disclosurePolicyId != 0) {
            disclosureRegistry.getDisclosurePolicy(disclosurePolicyId);
        }
    }

    function validateDisclosureForAction(
        uint256 disclosurePolicyId,
        AVADataTypes.Role,
        AVADataTypes.Action,
        AVADataTypes.AVAStage,
        bytes32,
        bytes32,
        uint256,
        bytes32
    ) external view {
        if (disclosurePolicyId != 0) {
            disclosureRegistry.getDisclosurePolicy(disclosurePolicyId);
        }
    }
}
