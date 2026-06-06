// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";

interface IStandingCredentialIssuer {
    struct StandingCredentialInput {
        uint256 standingComputationRecordId;
        bytes32 categoryHash;
        int256 threshold;
        int256 lowerBound;
        int256 upperBound;
        uint256 epoch;
        uint256 expiresAt;
        bytes32 computationRuleHash;
        bytes32 authorityId;
        string uri;
    }

    function issueCredential(
        AVADataTypes.Role actingRole,
        StandingCredentialInput calldata input
    ) external returns (uint256 id);

    function revokeCredential(
        AVADataTypes.Role actingRole,
        uint256 credentialId,
        bytes32 authorityId,
        string calldata uri
    ) external;

    function supersedeCredential(
        AVADataTypes.Role actingRole,
        uint256 credentialId,
        StandingCredentialInput calldata input
    ) external returns (uint256 id);

    function recordStandingRelevantSettlement(
        AVADataTypes.Role actingRole,
        uint256 credentialId,
        AVADataTypes.StandingRelevantSettlementKind kind,
        AVADataTypes.ExecutionSourceType sourceType,
        uint256 sourceRecordId,
        uint256 settlementId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id);

    function credentialProves(
        uint256 credentialId,
        bytes32 subjectId,
        bytes32 vectorKey,
        bytes32 categoryHash,
        int256 requiredThreshold
    ) external view returns (bool);

    function credentialProvesSubjectStanding(
        uint256 credentialId,
        uint256 packageId,
        bytes32 subjectId,
        bytes32 vectorKey,
        bytes32 categoryHash,
        int256 requiredThreshold
    ) external view returns (bool);

    function getStandingCredential(uint256 id) external view returns (AVADataTypes.StandingCredentialRecord memory);

    function getStandingCredentialSettlement(uint256 id)
        external
        view
        returns (AVADataTypes.StandingCredentialSettlementRecord memory);
}
