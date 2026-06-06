// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";
import {DisclosurePolicyRegistry} from "../DisclosurePolicyRegistry.sol";
import {IDisclosurePolicyModule} from "../interfaces/IDisclosurePolicyModule.sol";

contract PanelVisibleDisclosureModule is IDisclosurePolicyModule {
    DisclosurePolicyRegistry public immutable disclosureRegistry;
    uint256 public immutable panelVisiblePolicyId;

    constructor(DisclosurePolicyRegistry disclosureRegistry_, uint256 panelVisiblePolicyId_) {
        if (panelVisiblePolicyId_ == 0) revert AVADataTypes.EmptyValue();
        disclosureRegistry = disclosureRegistry_;
        panelVisiblePolicyId = panelVisiblePolicyId_;
    }

    function validateDisclosurePolicy(uint256 disclosurePolicyId) external view {
        _validatePolicyIfSpecified(disclosurePolicyId);
    }

    function validateDisclosureForAction(
        uint256 disclosurePolicyId,
        AVADataTypes.Role actingRole,
        AVADataTypes.Action,
        AVADataTypes.AVAStage,
        bytes32,
        bytes32,
        uint256,
        bytes32
    ) external view {
        _validatePolicyIfSpecified(disclosurePolicyId);
        if (disclosurePolicyId == panelVisiblePolicyId) {
            if (actingRole != AVADataTypes.Role.Editor && actingRole != AVADataTypes.Role.Panel) {
                revert AVADataTypes.InvalidRole();
            }
        }
    }

    function _validatePolicyIfSpecified(uint256 disclosurePolicyId) internal view {
        if (disclosurePolicyId != 0) {
            disclosureRegistry.getDisclosurePolicy(disclosurePolicyId);
        }
    }
}
