// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RuleModuleIdentity} from "../interfaces/IRuleModuleIdentity.sol";

import {AVADataTypes} from "../AVADataTypes.sol";
import {IPenaltyAdapter} from "../interfaces/IPenaltyAdapter.sol";

contract DefaultPenaltyAdapter is IPenaltyAdapter, RuleModuleIdentity {
    uint256 public immutable MAX_ABSOLUTE_STANDING_DELTA;
    uint256 public immutable MAX_RESTRICTION_DURATION;

    constructor(uint256 maxAbsoluteStandingDelta_, uint256 maxRestrictionDuration_) {
        if (maxAbsoluteStandingDelta_ == 0 || maxRestrictionDuration_ == 0) revert AVADataTypes.EmptyValue();
        MAX_ABSOLUTE_STANDING_DELTA = maxAbsoluteStandingDelta_;
        MAX_RESTRICTION_DURATION = maxRestrictionDuration_;
    }

    function validatePenaltyRecord(
        AVADataTypes.Role,
        uint256,
        uint256 challengeId,
        AVADataTypes.GovernanceFindingKind findingKind,
        AVADataTypes.ChallengeOutcome challengeOutcome,
        bytes32 subjectId,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata,
        address
    ) external pure {
        if (
            challengeId == 0 || findingKind == AVADataTypes.GovernanceFindingKind.None
                || challengeOutcome == AVADataTypes.ChallengeOutcome.None || subjectId == bytes32(0)
                || evidenceReceiptId == 0 || authorityId == bytes32(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
    }

    function validateStandingPenaltyInput(AVADataTypes.StandingPenaltyValidationContext calldata context)
        external
        view
    {
        if (
            context.penaltyConsequenceId == 0 || context.packageId == 0 || context.challengeId == 0
                || context.findingKind == AVADataTypes.GovernanceFindingKind.None
                || context.challengeOutcome == AVADataTypes.ChallengeOutcome.None
                || context.challengeOutcome == AVADataTypes.ChallengeOutcome.RejectedGoodFaith
                || context.subjectId == bytes32(0) || bytes(context.dimension).length == 0
                || context.delta >= 0 || context.delta == type(int256).min
                || uint256(-context.delta) > MAX_ABSOLUTE_STANDING_DELTA
                || context.evidenceReceiptId == 0 || context.authorityId == bytes32(0)
                || context.actor == address(0)
        ) {
            revert AVADataTypes.InvalidState(context.penaltyConsequenceId);
        }
    }

    function validateEligibilityRestriction(AVADataTypes.EligibilityRestrictionValidationContext calldata context)
        external
        view
    {
        bool compatibleFinding = context.findingKind == AVADataTypes.GovernanceFindingKind.NegligentChallenge
            || context.findingKind == AVADataTypes.GovernanceFindingKind.MaliciousOrFabricatedChallenge;
        if (
            context.penaltyConsequenceId == 0 || context.packageId == 0 || context.challengeId == 0
                || context.challengeOutcome == AVADataTypes.ChallengeOutcome.None
                || context.challengeOutcome == AVADataTypes.ChallengeOutcome.RejectedGoodFaith
                || !compatibleFinding
                || context.restrictionKind != AVADataTypes.EligibilityRestrictionKind.ChallengeIntake
                || context.subjectId == bytes32(0) || context.expiresAt <= block.timestamp
                || context.expiresAt - block.timestamp > MAX_RESTRICTION_DURATION
                || context.evidenceReceiptId == 0 || context.authorityId == bytes32(0)
                || context.actor == address(0)
        ) {
            revert AVADataTypes.InvalidState(context.penaltyConsequenceId);
        }
    }

    function _moduleConfigurationHash() internal view override returns (bytes32) {
        return keccak256(abi.encode(MAX_ABSOLUTE_STANDING_DELTA, MAX_RESTRICTION_DURATION));
    }
}
