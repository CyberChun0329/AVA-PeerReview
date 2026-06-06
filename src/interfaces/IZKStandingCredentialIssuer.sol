// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";
import {IZKProofVerifier} from "./IZKProofVerifier.sol";

interface IZKStandingCredentialIssuer {
    enum ZKStandingCredentialSuspensionSourceKind {
        None,
        ValueSettlement,
        ChallengeTransition
    }

    struct ZKStandingCredentialInput {
        uint256 standingProofReceiptId;
        uint256 packageId;
        bytes32 subjectCommitment;
        bytes32 credentialCommitment;
        bytes32 credentialNullifierHash;
        bytes32 vectorKey;
        bytes32 categoryHash;
        int256 threshold;
        int256 lowerBound;
        int256 upperBound;
        uint256 epoch;
        bytes32 sourceRecordSetRoot;
        bytes32 computationRuleHash;
        uint256 expiresAt;
        bytes32 authorityId;
        string uri;
    }

    struct ZKStandingCredentialRecord {
        uint256 id;
        uint256 standingProofReceiptId;
        uint256 standingComputationStatementId;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 subjectCommitment;
        bytes32 credentialCommitment;
        bytes32 credentialNullifierHash;
        bytes32 vectorKey;
        bytes32 categoryHash;
        int256 threshold;
        int256 lowerBound;
        int256 upperBound;
        uint256 epoch;
        bytes32 sourceRecordSetRoot;
        bytes32 computationRuleHash;
        uint256 issuedAt;
        uint256 expiresAt;
        AVADataTypes.Role authorityRole;
        bytes32 authorityId;
        AVADataTypes.StandingCredentialStatus status;
        uint256 supersededBy;
        bytes32 statusReference;
        string statusURI;
        string uri;
        address issuedBy;
    }

    struct ZKStandingCredentialUseRecord {
        uint256 id;
        uint256 credentialId;
        uint256 packageId;
        bytes32 subjectCommitment;
        bytes32 vectorKey;
        bytes32 categoryHash;
        int256 requiredThreshold;
        bytes32 targetContextHash;
        bytes32 proofUseNullifierHash;
        address usedBy;
    }

    struct ZKStandingCredentialUseInput {
        uint256 credentialId;
        uint256 packageId;
        bytes32 subjectCommitment;
        bytes32 vectorKey;
        bytes32 categoryHash;
        int256 requiredThreshold;
        bytes32 targetContextHash;
        bytes32 proofUseNullifierHash;
    }

    struct ZKStandingCredentialSuspensionRecord {
        uint256 id;
        uint256 credentialId;
        ZKStandingCredentialSuspensionSourceKind sourceKind;
        uint256 packageId;
        bytes32 subjectCommitment;
        AVADataTypes.StandingRelevantSettlementKind standingKind;
        AVADataTypes.ExecutionSourceType settlementSourceType;
        uint256 sourceRecordId;
        uint256 settlementId;
        uint256 challengeTransitionId;
        AVADataTypes.ChallengeOutcome challengeOutcome;
        AVADataTypes.Role authorityRole;
        bytes32 authorityId;
        string uri;
        address recordedBy;
    }

    function issueCredential(
        AVADataTypes.Role actingRole,
        ZKStandingCredentialInput calldata input
    ) external returns (uint256 id);

    function revokeCredential(
        AVADataTypes.Role actingRole,
        uint256 credentialId,
        bytes32 subjectCommitment,
        bytes32 authorityId,
        string calldata uri
    ) external;

    function supersedeCredential(
        AVADataTypes.Role actingRole,
        uint256 credentialId,
        ZKStandingCredentialInput calldata input
    ) external returns (uint256 id);

    function recordSettlementBoundSuspension(
        AVADataTypes.Role actingRole,
        uint256 credentialId,
        AVADataTypes.StandingRelevantSettlementKind kind,
        AVADataTypes.ExecutionSourceType sourceType,
        uint256 sourceRecordId,
        uint256 settlementId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id);

    function recordChallengeTransitionBoundSuspension(
        AVADataTypes.Role actingRole,
        uint256 credentialId,
        uint256 challengeTransitionId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id);

    function credentialProves(
        uint256 credentialId,
        uint256 packageId,
        bytes32 subjectCommitment,
        bytes32 vectorKey,
        bytes32 categoryHash,
        int256 requiredThreshold
    ) external view returns (bool);

    function recordCredentialUse(ZKStandingCredentialUseInput calldata input, IZKProofVerifier.SchnorrProof calldata proof)
        external
        returns (uint256 id);

    function computeCredentialCommitment(IZKProofVerifier.G1Point calldata publicKey) external pure returns (bytes32);

    function computeCredentialUseContextHash(
        uint256 credentialId,
        uint256 packageId,
        bytes32 subjectCommitment,
        bytes32 vectorKey,
        bytes32 categoryHash,
        int256 requiredThreshold,
        bytes32 targetContextHash
    ) external pure returns (bytes32);

    function computeCredentialUseNullifierHash(bytes32 useContextHash, bytes32 credentialCommitment)
        external
        pure
        returns (bytes32);

    /// @notice Returns only the credential carrier's local status/expiry state.
    /// @dev Consumers that need a standing proof must call `credentialProves`
    /// or record a target-bound credential-use receipt, because those paths also
    /// re-check the source standing proof and computation statement.
    function isCredentialActive(uint256 credentialId) external view returns (bool);

    function getCredential(uint256 id) external view returns (ZKStandingCredentialRecord memory);

    function getCredentialUseRecord(uint256 id) external view returns (ZKStandingCredentialUseRecord memory);

    function getCredentialSuspensionRecord(uint256 id)
        external
        view
        returns (ZKStandingCredentialSuspensionRecord memory);
}
