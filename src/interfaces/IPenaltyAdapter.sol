// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";
import {IRuleModuleIdentity} from "./IRuleModuleIdentity.sol";

interface IPenaltyAdapter is IRuleModuleIdentity {
    function validatePenaltyRecord(
        AVADataTypes.Role actingRole,
        uint256 recognisedStateId,
        uint256 challengeId,
        AVADataTypes.GovernanceFindingKind findingKind,
        AVADataTypes.ChallengeOutcome challengeOutcome,
        bytes32 subjectId,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri,
        address actor
    ) external view;

    function validateStandingPenaltyInput(AVADataTypes.StandingPenaltyValidationContext calldata context)
        external
        view;

    function validateEligibilityRestriction(AVADataTypes.EligibilityRestrictionValidationContext calldata context)
        external
        view;
}
