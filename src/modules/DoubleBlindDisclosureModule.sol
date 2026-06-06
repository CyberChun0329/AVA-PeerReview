// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";
import {DisclosurePolicyRegistry} from "../DisclosurePolicyRegistry.sol";
import {IDisclosurePolicyModule} from "../interfaces/IDisclosurePolicyModule.sol";

contract DoubleBlindDisclosureModule is IDisclosurePolicyModule {
    DisclosurePolicyRegistry public immutable disclosureRegistry;
    uint256 public immutable blindedReviewPolicyId;

    constructor(DisclosurePolicyRegistry disclosureRegistry_, uint256 blindedReviewPolicyId_) {
        if (blindedReviewPolicyId_ == 0) revert AVADataTypes.EmptyValue();
        disclosureRegistry = disclosureRegistry_;
        blindedReviewPolicyId = blindedReviewPolicyId_;
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
        if (
            action == AVADataTypes.Action.RegisterReviewContribution
                || action == AVADataTypes.Action.ProvisionallyRecogniseReview
                || action == AVADataTypes.Action.OpenChallengeWindow
        ) {
            if (disclosurePolicyId != blindedReviewPolicyId) revert AVADataTypes.InvalidState(disclosurePolicyId);
            if (action == AVADataTypes.Action.RegisterReviewContribution) {
                if (actingRole != AVADataTypes.Role.Reviewer || stage != AVADataTypes.AVAStage.Attribution) {
                    revert AVADataTypes.InvalidRole();
                }
            } else if (actingRole != AVADataTypes.Role.Editor || stage != AVADataTypes.AVAStage.Verification) {
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
