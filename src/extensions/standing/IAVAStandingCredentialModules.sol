// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRuleModuleIdentity} from "../../interfaces/IRuleModuleIdentity.sol";

interface IAVAStandingComputationPolicyModule is IRuleModuleIdentity {
    struct StandingComputationContext {
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        uint256 recognisedStateId;
        uint256 recognisedStateTransitionId;
        bytes32 subjectId;
        bytes32 roleKey;
        uint256 evidenceId;
        uint256 revision;
        bytes32 vectorKey;
        bytes32 categoryHash;
        int256 lowerBound;
        int256 upperBound;
        bytes32 thresholdSetHash;
        bytes32 computationRuleHash;
        bytes32 sourceSetCommitment;
        bytes32 outputCommitment;
        bytes32 authorityId;
        address actor;
    }

    function validateStandingComputation(StandingComputationContext calldata context) external view;
}

interface IAVAStandingCredentialPolicyModule is IRuleModuleIdentity {
    struct StandingCredentialContext {
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        uint256 computationId;
        bytes32 subjectId;
        bytes32 roleKey;
        uint256 evidenceId;
        uint256 revision;
        bytes32 vectorKey;
        bytes32 categoryHash;
        int256 lowerBound;
        int256 upperBound;
        bytes32 actionKey;
        uint64 expiresAt;
        bytes32 authorityId;
        address actor;
    }

    function validateStandingCredential(StandingCredentialContext calldata context) external view;
}
