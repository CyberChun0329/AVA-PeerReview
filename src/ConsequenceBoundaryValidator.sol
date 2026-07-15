// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "./AVADataTypes.sol";

/// @notice Non-delegable pure boundaries used by ConsequenceExecutor.
/// @dev ConsequenceExecutor deploys and binds this validator itself. Rule packages
/// cannot replace it or widen these checks.
contract ConsequenceBoundaryValidator {
    function requireExecutionContext(
        AVADataTypes.ConsequenceKind consequenceKind,
        AVADataTypes.ValueExecutionContext calldata context,
        address actor,
        bool genericConsequencePath
    ) external pure {
        if (
            consequenceKind == AVADataTypes.ConsequenceKind.None || context.recognisedStateId == 0
                || context.recipientSubjectId == bytes32(0) || context.amount == 0
                || context.executionReference == bytes32(0) || context.evidenceReceiptId == 0
                || context.authorityId == bytes32(0) || context.actor != actor
                || (context.mode == AVADataTypes.ValueExecutionMode.RecordOnly
                    && context.settlementKind != AVADataTypes.ValueSettlementKind.None)
                || (context.mode != AVADataTypes.ValueExecutionMode.RecordOnly
                    && context.settlementKind == AVADataTypes.ValueSettlementKind.None)
        ) {
            revert AVADataTypes.EmptyValue();
        }
        if (
            genericConsequencePath
                && (consequenceKind == AVADataTypes.ConsequenceKind.PenaltyRecord
                    || consequenceKind == AVADataTypes.ConsequenceKind.RestorationRecord)
        ) {
            revert AVADataTypes.InvalidState(context.recognisedStateId);
        }
        if (
            context.mode != AVADataTypes.ValueExecutionMode.RecordOnly
                && (consequenceKind != AVADataTypes.ConsequenceKind.PenaltyRecord
                    || context.mode != AVADataTypes.ValueExecutionMode.Claim
                    || context.settlementKind != AVADataTypes.ValueSettlementKind.ClawbackTransfer)
        ) {
            revert AVADataTypes.InvalidState(context.recognisedStateId);
        }
    }

    function requireCompatibleFindingSubject(
        AVADataTypes.ChallengeOutcome challengeOutcome,
        uint256 challengeId,
        bytes32 challengerSubjectId,
        bytes32 recognisedStateSubjectId,
        AVADataTypes.GovernanceFindingKind findingKind,
        bytes32 subjectId,
        AVADataTypes.Role subjectRole
    ) external pure {
        if (challengeOutcome == AVADataTypes.ChallengeOutcome.RejectedGoodFaith) {
            revert AVADataTypes.InvalidState(challengeId);
        }
        if (
            (findingKind == AVADataTypes.GovernanceFindingKind.MaliciousOrFabricatedChallenge
                    && challengeOutcome != AVADataTypes.ChallengeOutcome.MaliciousOrFabricated)
                || (findingKind == AVADataTypes.GovernanceFindingKind.NegligentChallenge
                    && challengeOutcome != AVADataTypes.ChallengeOutcome.Negligent)
                || ((findingKind == AVADataTypes.GovernanceFindingKind.AcademicFraud
                        || findingKind == AVADataTypes.GovernanceFindingKind.IrresponsibleReview)
                    && challengeOutcome != AVADataTypes.ChallengeOutcome.Upheld)
        ) {
            revert AVADataTypes.InvalidState(challengeId);
        }

        bool targetFinding = findingKind == AVADataTypes.GovernanceFindingKind.AcademicFraud
            || findingKind == AVADataTypes.GovernanceFindingKind.IrresponsibleReview;
        if (
            (targetFinding && subjectId != recognisedStateSubjectId)
                || (!targetFinding && challengerSubjectId != subjectId)
        ) {
            revert AVADataTypes.InvalidState(challengeId);
        }
        if (
            (findingKind == AVADataTypes.GovernanceFindingKind.AcademicFraud && subjectRole != AVADataTypes.Role.Author)
                || (findingKind == AVADataTypes.GovernanceFindingKind.IrresponsibleReview
                    && subjectRole != AVADataTypes.Role.Reviewer)
                || ((findingKind == AVADataTypes.GovernanceFindingKind.NegligentChallenge
                        || findingKind == AVADataTypes.GovernanceFindingKind.MaliciousOrFabricatedChallenge)
                    && subjectRole != AVADataTypes.Role.Challenger)
        ) {
            revert AVADataTypes.InvalidState(challengeId);
        }
    }

    function requireCompatibleEligibilityOutcome(
        AVADataTypes.ChallengeOutcome challengeOutcome,
        AVADataTypes.GovernanceFindingKind findingKind,
        uint256 challengeId,
        AVADataTypes.EligibilityRestrictionKind restrictionKind
    ) external pure {
        if (challengeOutcome == AVADataTypes.ChallengeOutcome.RejectedGoodFaith) {
            revert AVADataTypes.InvalidState(challengeId);
        }
        if (
            restrictionKind == AVADataTypes.EligibilityRestrictionKind.ChallengeIntake
                && findingKind != AVADataTypes.GovernanceFindingKind.NegligentChallenge
                && findingKind != AVADataTypes.GovernanceFindingKind.MaliciousOrFabricatedChallenge
        ) {
            revert AVADataTypes.InvalidState(challengeId);
        }
    }
}
