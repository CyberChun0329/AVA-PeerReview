// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";
import {DisclosurePolicyRegistry} from "../DisclosurePolicyRegistry.sol";
import {IDisclosurePolicyModule} from "../interfaces/IDisclosurePolicyModule.sol";

contract PostRecognitionAuthorRevealModule is IDisclosurePolicyModule {
    DisclosurePolicyRegistry public immutable disclosureRegistry;
    uint256 public immutable authorRevealPolicyId;

    constructor(DisclosurePolicyRegistry disclosureRegistry_, uint256 authorRevealPolicyId_) {
        if (authorRevealPolicyId_ == 0) revert AVADataTypes.EmptyValue();
        disclosureRegistry = disclosureRegistry_;
        authorRevealPolicyId = authorRevealPolicyId_;
    }

    function validateDisclosurePolicy(uint256 disclosurePolicyId) external view {
        _validatePolicyIfSpecified(disclosurePolicyId);
    }

    function validateDisclosureForAction(
        uint256 disclosurePolicyId,
        AVADataTypes.Role actingRole,
        AVADataTypes.Action action,
        AVADataTypes.AVAStage stage,
        bytes32,
        bytes32,
        uint256,
        bytes32
    ) external view {
        _validatePolicyIfSpecified(disclosurePolicyId);
        if (disclosurePolicyId == authorRevealPolicyId) {
            if (
                actingRole != AVADataTypes.Role.Editor || action != AVADataTypes.Action.RegisterRecognisedState
                    || stage != AVADataTypes.AVAStage.Verification
            ) {
                revert AVADataTypes.InvalidState(disclosurePolicyId);
            }
        }
    }

    function _validatePolicyIfSpecified(uint256 disclosurePolicyId) internal view {
        if (disclosurePolicyId != 0) {
            disclosureRegistry.getDisclosurePolicy(disclosurePolicyId);
        }
    }
}
