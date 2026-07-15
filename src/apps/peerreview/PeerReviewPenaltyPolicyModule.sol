// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RuleModuleIdentity} from "../../interfaces/IRuleModuleIdentity.sol";
import {IAVAExtensionPolicyModule} from "../../extensions/shared/IAVAExtensionPolicyModule.sol";
import {AVAChallengeExtension} from "../../extensions/challenge/AVAChallengeExtension.sol";
import {AVACoreTypes} from "../../core/AVACoreTypes.sol";
import {PeerReviewTypes} from "./PeerReviewTypes.sol";

contract PeerReviewPenaltyPolicyModule is IAVAExtensionPolicyModule, RuleModuleIdentity {
    uint256 public constant MAX_ABSOLUTE_STANDING_DELTA = 1_000_000;
    uint64 public constant MAX_RESTRICTION_DURATION = 365 days;

    function validateExtensionRecord(ExtensionPolicyContext calldata context) external view {
        if (context.appId != PeerReviewTypes.APP_ID) revert AVACoreTypes.InvalidState(context.sourceRecordId);
        if (context.actionKey == AVACoreTypes.ACTION_RECORD_PENALTY) {
            _validateFinding(context.recordTypeKey, context.scopeKey, context.sourceRecordId);
            return;
        }
        if (context.actionKey == AVACoreTypes.ACTION_RECORD_STANDING_PENALTY_INPUT) {
            if (context.unsignedValue == 0 || context.unsignedValue > MAX_ABSOLUTE_STANDING_DELTA) {
                revert AVACoreTypes.InvalidState(context.sourceRecordId);
            }
            return;
        }
        if (context.actionKey == AVACoreTypes.ACTION_RECORD_ELIGIBILITY_RESTRICTION) {
            if (
                !_isSupportedRestriction(context.recordTypeKey) || context.validUntil <= block.timestamp
                    || context.validUntil > block.timestamp + MAX_RESTRICTION_DURATION
            ) revert AVACoreTypes.InvalidState(context.sourceRecordId);
        }
    }

    function _validateFinding(bytes32 findingKey, bytes32 outcomeKey, uint256 sourceRecordId) private pure {
        bytes32 upheld = bytes32(uint256(uint8(AVAChallengeExtension.ChallengeOutcome.Upheld)));
        bytes32 negligent = bytes32(uint256(uint8(AVAChallengeExtension.ChallengeOutcome.Negligent)));
        bytes32 malicious =
            bytes32(uint256(uint8(AVAChallengeExtension.ChallengeOutcome.MaliciousOrFabricated)));
        bool valid = outcomeKey == upheld
            && (findingKey == PeerReviewTypes.FINDING_ACADEMIC_FRAUD
                || findingKey == PeerReviewTypes.FINDING_IRRESPONSIBLE_REVIEW);
        valid = valid || (outcomeKey == negligent && findingKey == PeerReviewTypes.FINDING_NEGLIGENT_CHALLENGE);
        valid = valid
            || (outcomeKey == malicious && findingKey == PeerReviewTypes.FINDING_MALICIOUS_OR_FABRICATED_CHALLENGE);
        if (!valid) revert AVACoreTypes.InvalidState(sourceRecordId);
    }

    function _isSupportedRestriction(bytes32 restrictionKey) private pure returns (bool) {
        return restrictionKey == PeerReviewTypes.RESTRICTION_REVIEW_ELIGIBILITY
            || restrictionKey == PeerReviewTypes.RESTRICTION_CHALLENGE_INTAKE
            || restrictionKey == PeerReviewTypes.RESTRICTION_PANEL_ELIGIBILITY;
    }

    function _moduleConfigurationHash() internal pure override returns (bytes32) {
        return keccak256(
            abi.encode(PeerReviewTypes.APP_ID, MAX_ABSOLUTE_STANDING_DELTA, MAX_RESTRICTION_DURATION)
        );
    }
}
