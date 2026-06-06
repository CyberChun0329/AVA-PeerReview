// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";
import {DisclosurePolicyRegistry} from "../DisclosurePolicyRegistry.sol";
import {IDisclosurePolicyModule} from "../interfaces/IDisclosurePolicyModule.sol";

contract AnonymousChallengeDisclosureModule is IDisclosurePolicyModule {
    DisclosurePolicyRegistry public immutable disclosureRegistry;
    uint256 public immutable anonymousChallengePolicyId;

    constructor(DisclosurePolicyRegistry disclosureRegistry_, uint256 anonymousChallengePolicyId_) {
        if (anonymousChallengePolicyId_ == 0) revert AVADataTypes.EmptyValue();
        disclosureRegistry = disclosureRegistry_;
        anonymousChallengePolicyId = anonymousChallengePolicyId_;
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
        if (_isChallengeAction(action)) {
            if (disclosurePolicyId != anonymousChallengePolicyId || stage != AVADataTypes.AVAStage.Verification) {
                revert AVADataTypes.InvalidState(disclosurePolicyId);
            }
            _validateChallengeRole(action, actingRole);
        }
    }

    function _validatePolicyIfSpecified(uint256 disclosurePolicyId) internal view {
        if (disclosurePolicyId != 0) {
            disclosureRegistry.getDisclosurePolicy(disclosurePolicyId);
        }
    }

    function _isChallengeAction(AVADataTypes.Action action) internal pure returns (bool) {
        return action == AVADataTypes.Action.FileChallenge || action == AVADataTypes.Action.ScreenChallenge
            || action == AVADataTypes.Action.ResolveChallenge || action == AVADataTypes.Action.ApplyRestoration
            || action == AVADataTypes.Action.CloseChallenge;
    }

    function _validateChallengeRole(AVADataTypes.Action action, AVADataTypes.Role actingRole) internal pure {
        if (action == AVADataTypes.Action.FileChallenge) {
            if (actingRole != AVADataTypes.Role.Challenger) revert AVADataTypes.InvalidRole();
        } else if (action == AVADataTypes.Action.ScreenChallenge) {
            if (actingRole != AVADataTypes.Role.Editor) revert AVADataTypes.InvalidRole();
        } else if (actingRole != AVADataTypes.Role.Panel) {
            revert AVADataTypes.InvalidRole();
        }
    }
}
