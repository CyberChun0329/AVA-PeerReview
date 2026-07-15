// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RuleModuleIdentity} from "../interfaces/IRuleModuleIdentity.sol";

import {AVADataTypes} from "../AVADataTypes.sol";
import {IStandingAdapter} from "../interfaces/IStandingAdapter.sol";
import {IRewardAdapter} from "../interfaces/IRewardAdapter.sol";
import {IPriorityAdapter} from "../interfaces/IPriorityAdapter.sol";
import {IPenaltyAdapter} from "../interfaces/IPenaltyAdapter.sol";
import {IRestorationAdapter} from "../interfaces/IRestorationAdapter.sol";
import {IConsequenceAdapter} from "../interfaces/IConsequenceAdapter.sol";

contract VectorStandingAdapter is IStandingAdapter, RuleModuleIdentity {
    function validateStandingUpdate(
        AVADataTypes.Role,
        uint256 recognisedStateId,
        bytes32 subjectId,
        string calldata dimension,
        int256,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata,
        address actor
    ) external pure {
        if (
            recognisedStateId == 0 || subjectId == bytes32(0) || bytes(dimension).length == 0
                || evidenceReceiptId == 0 || authorityId == bytes32(0) || actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
        if (keccak256(bytes(dimension)) == keccak256("public-prestige")) {
            revert AVADataTypes.InvalidState(recognisedStateId);
        }
    }
}

contract StablecoinRecordRewardAdapter is IRewardAdapter, RuleModuleIdentity {
    function validateRewardRecord(
        AVADataTypes.Role,
        uint256 recognisedStateId,
        bytes32 subjectId,
        uint256 amountOrUnits,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri,
        address actor
    ) external pure {
        _requireRecordFields(recognisedStateId, subjectId, amountOrUnits, evidenceReceiptId, authorityId, uri, actor);
        if (keccak256(bytes(uri)) == keccak256("transfer")) revert AVADataTypes.InvalidState(recognisedStateId);
    }

    function _requireRecordFields(
        uint256 recognisedStateId,
        bytes32 subjectId,
        uint256 amountOrUnits,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri,
        address actor
    ) internal pure {
        if (
            recognisedStateId == 0 || subjectId == bytes32(0) || amountOrUnits == 0 || evidenceReceiptId == 0
                || authorityId == bytes32(0) || bytes(uri).length == 0 || actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
    }
}

contract GenericTokenRecordRewardAdapter is IRewardAdapter, RuleModuleIdentity {
    function validateRewardRecord(
        AVADataTypes.Role,
        uint256 recognisedStateId,
        bytes32 subjectId,
        uint256 amountOrUnits,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri,
        address actor
    ) external pure {
        if (
            recognisedStateId == 0 || subjectId == bytes32(0) || amountOrUnits == 0 || evidenceReceiptId == 0
                || authorityId == bytes32(0) || bytes(uri).length == 0 || actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
    }
}

contract PriorityTokenRecordAdapter is IPriorityAdapter, RuleModuleIdentity {
    function validatePriorityRecord(
        AVADataTypes.Role,
        uint256 recognisedStateId,
        bytes32 subjectId,
        uint256 amountOrUnits,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri,
        address actor
    ) external pure {
        if (
            recognisedStateId == 0 || subjectId == bytes32(0) || amountOrUnits == 0 || evidenceReceiptId == 0
                || authorityId == bytes32(0) || bytes(uri).length == 0 || actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
        if (keccak256(bytes(uri)) == keccak256("publication-priority")) {
            revert AVADataTypes.InvalidState(recognisedStateId);
        }
    }
}

contract RentedPriorityRecordAdapter is IPriorityAdapter, RuleModuleIdentity {
    function validatePriorityRecord(
        AVADataTypes.Role,
        uint256 recognisedStateId,
        bytes32 subjectId,
        uint256 amountOrUnits,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri,
        address actor
    ) external pure {
        if (
            recognisedStateId == 0 || subjectId == bytes32(0) || amountOrUnits == 0 || evidenceReceiptId == 0
                || authorityId == bytes32(0) || bytes(uri).length == 0 || actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
    }
}

contract ProceduralPenaltyRecordAdapter is IPenaltyAdapter, RuleModuleIdentity {
    function validatePenaltyRecord(
        AVADataTypes.Role,
        uint256 recognisedStateId,
        uint256 challengeId,
        AVADataTypes.GovernanceFindingKind findingKind,
        AVADataTypes.ChallengeOutcome challengeOutcome,
        bytes32 subjectId,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri,
        address actor
    ) external pure {
        if (
            recognisedStateId == 0 || challengeId == 0 || findingKind == AVADataTypes.GovernanceFindingKind.None
                || challengeOutcome == AVADataTypes.ChallengeOutcome.None || subjectId == bytes32(0)
                || evidenceReceiptId == 0 || authorityId == bytes32(0) || bytes(uri).length == 0
                || actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
    }

    function validateStandingPenaltyInput(AVADataTypes.StandingPenaltyValidationContext calldata context)
        external
        pure
    {
        _validateStandingPenaltyInput(context);
    }

    function validateEligibilityRestriction(AVADataTypes.EligibilityRestrictionValidationContext calldata context)
        external
        view
    {
        _validateEligibilityRestriction(context);
    }

    function _validateStandingPenaltyInput(AVADataTypes.StandingPenaltyValidationContext calldata context)
        internal
        pure
    {
        if (
            context.penaltyConsequenceId == 0 || context.challengeId == 0
                || context.findingKind == AVADataTypes.GovernanceFindingKind.None
                || context.challengeOutcome == AVADataTypes.ChallengeOutcome.None
                || context.challengeOutcome == AVADataTypes.ChallengeOutcome.RejectedGoodFaith
                || context.subjectId == bytes32(0) || bytes(context.dimension).length == 0
                || context.delta >= 0 || context.evidenceReceiptId == 0
                || context.authorityId == bytes32(0) || context.actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
    }

    function _validateEligibilityRestriction(AVADataTypes.EligibilityRestrictionValidationContext calldata context)
        internal
        view
    {
        if (
            context.penaltyConsequenceId == 0 || context.challengeId == 0
                || context.challengeOutcome == AVADataTypes.ChallengeOutcome.None
                || context.challengeOutcome == AVADataTypes.ChallengeOutcome.RejectedGoodFaith
                || context.restrictionKind != AVADataTypes.EligibilityRestrictionKind.ChallengeIntake
                || context.subjectId == bytes32(0) || context.expiresAt <= block.timestamp
                || context.evidenceReceiptId == 0 || context.authorityId == bytes32(0)
                || context.actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
    }
}

contract PriorityReturnObligationRecordAdapter is IPenaltyAdapter, RuleModuleIdentity {
    function validatePenaltyRecord(
        AVADataTypes.Role,
        uint256 recognisedStateId,
        uint256 challengeId,
        AVADataTypes.GovernanceFindingKind findingKind,
        AVADataTypes.ChallengeOutcome challengeOutcome,
        bytes32 subjectId,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri,
        address actor
    ) external pure {
        if (
            recognisedStateId == 0 || challengeId == 0 || findingKind == AVADataTypes.GovernanceFindingKind.None
                || challengeOutcome == AVADataTypes.ChallengeOutcome.None || subjectId == bytes32(0)
                || evidenceReceiptId == 0 || authorityId == bytes32(0) || bytes(uri).length == 0
                || actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
    }

    function validateStandingPenaltyInput(AVADataTypes.StandingPenaltyValidationContext calldata context)
        external
        pure
    {
        if (
            context.penaltyConsequenceId == 0 || context.challengeId == 0
                || context.findingKind == AVADataTypes.GovernanceFindingKind.None
                || context.challengeOutcome == AVADataTypes.ChallengeOutcome.None
                || context.challengeOutcome == AVADataTypes.ChallengeOutcome.RejectedGoodFaith
                || context.subjectId == bytes32(0) || bytes(context.dimension).length == 0
                || context.delta >= 0 || context.evidenceReceiptId == 0
                || context.authorityId == bytes32(0) || context.actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
    }

    function validateEligibilityRestriction(AVADataTypes.EligibilityRestrictionValidationContext calldata context)
        external
        view
    {
        if (
            context.penaltyConsequenceId == 0 || context.challengeId == 0
                || context.challengeOutcome == AVADataTypes.ChallengeOutcome.None
                || context.challengeOutcome == AVADataTypes.ChallengeOutcome.RejectedGoodFaith
                || context.restrictionKind != AVADataTypes.EligibilityRestrictionKind.ChallengeIntake
                || context.subjectId == bytes32(0) || context.expiresAt <= block.timestamp
                || context.evidenceReceiptId == 0 || context.authorityId == bytes32(0)
                || context.actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
    }
}

contract RestorationProcedureRecordAdapter is IRestorationAdapter, RuleModuleIdentity {
    function validateRestorationRecord(
        AVADataTypes.Role,
        uint256 recognisedStateId,
        bytes32 subjectId,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri,
        address actor
    ) external pure {
        if (
            recognisedStateId == 0 || subjectId == bytes32(0) || evidenceReceiptId == 0 || authorityId == bytes32(0)
                || bytes(uri).length == 0 || actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
    }
}

contract CorrectionRestorationRecordAdapter is IRestorationAdapter, RuleModuleIdentity {
    function validateRestorationRecord(
        AVADataTypes.Role,
        uint256 recognisedStateId,
        bytes32 subjectId,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri,
        address actor
    ) external pure {
        if (
            recognisedStateId == 0 || subjectId == bytes32(0) || evidenceReceiptId == 0 || authorityId == bytes32(0)
                || bytes(uri).length == 0 || actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
    }
}

contract BoundedConsequenceExampleAdapter is IConsequenceAdapter, RuleModuleIdentity {
    function validateConsequence(
        AVADataTypes.Role,
        uint256 recognisedStateId,
        AVADataTypes.ConsequenceKind kind,
        bytes32 subjectId,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri,
        address actor
    ) external pure {
        if (
            recognisedStateId == 0 || kind == AVADataTypes.ConsequenceKind.None || subjectId == bytes32(0)
                || evidenceReceiptId == 0 || authorityId == bytes32(0) || bytes(uri).length == 0
                || actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
    }
}
