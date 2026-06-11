// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";

interface IStandingFormulaRegistry {
    struct StandingFormulaInput {
        bytes32 workflowKey;
        bytes32 vectorKey;
        uint64 formulaVersion;
        bytes32 computationRuleHash;
        bytes32 sourceSetPolicyHash;
        bytes32 decayPolicyHash;
        bytes32 capPolicyHash;
        bytes32 restorationPolicyHash;
        address verifier;
        bytes32 authorityId;
        string uri;
    }

    struct StandingFormulaRecord {
        uint256 id;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 vectorKey;
        uint64 formulaVersion;
        bytes32 computationRuleHash;
        bytes32 sourceSetPolicyHash;
        bytes32 decayPolicyHash;
        bytes32 capPolicyHash;
        bytes32 restorationPolicyHash;
        address verifier;
        AVADataTypes.Role authorityRole;
        bytes32 authorityId;
        string uri;
        address registeredBy;
        bool active;
    }

    struct SourceSetCommitmentInput {
        uint256 formulaId;
        bytes32 subjectCommitment;
        bytes32 categoryHash;
        uint256 epoch;
        bytes32 sourceRecordSetRoot;
        uint256 evidenceReceiptId;
        bytes32 completenessAttestationHash;
        bytes32 authorityId;
        string uri;
    }

    struct SourceSetCommitmentRecord {
        uint256 id;
        uint256 formulaId;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 subjectCommitment;
        bytes32 vectorKey;
        bytes32 categoryHash;
        uint256 epoch;
        bytes32 sourceRecordSetRoot;
        bytes32 computationRuleHash;
        bytes32 sourceSetPolicyHash;
        uint256 evidenceReceiptId;
        bytes32 completenessAttestationHash;
        AVADataTypes.Role authorityRole;
        bytes32 authorityId;
        string uri;
        address registeredBy;
    }

    struct SourceSetCompletenessAttestationInput {
        uint256 sourceSetCommitmentId;
        bytes32 includedRecordClassesHash;
        bytes32 exclusionPolicyHash;
        uint256 evidenceReceiptId;
        bytes32 completenessAttestationHash;
        bytes32 authorityId;
        string uri;
    }

    struct SourceSetCompletenessAttestationRecord {
        uint256 id;
        uint256 sourceSetCommitmentId;
        uint256 formulaId;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 subjectCommitment;
        bytes32 vectorKey;
        bytes32 categoryHash;
        uint256 epoch;
        bytes32 sourceRecordSetRoot;
        bytes32 computationRuleHash;
        bytes32 sourceSetPolicyHash;
        bytes32 includedRecordClassesHash;
        bytes32 exclusionPolicyHash;
        uint256 evidenceReceiptId;
        bytes32 completenessAttestationHash;
        AVADataTypes.Role authorityRole;
        bytes32 authorityId;
        string uri;
        address registeredBy;
        bool active;
    }

    struct StandingComputationStatementInput {
        uint256 sourceSetCommitmentId;
        uint256 sourceSetCompletenessAttestationId;
        bytes32 workflowKey;
        bytes32 subjectCommitment;
        bytes32 vectorKey;
        bytes32 categoryHash;
        int256 threshold;
        int256 lowerBound;
        int256 upperBound;
        uint256 epoch;
        bytes32 sourceRecordSetRoot;
        bytes32 computationRuleHash;
        bytes32 outputCommitmentHash;
        bytes32 proofDomainHash;
        uint256 evidenceReceiptId;
        bytes32 authorityId;
        string uri;
    }

    struct StandingComputationStatementRecord {
        uint256 id;
        uint256 sourceSetCommitmentId;
        uint256 sourceSetCompletenessAttestationId;
        uint256 formulaId;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 subjectCommitment;
        bytes32 vectorKey;
        bytes32 categoryHash;
        int256 threshold;
        int256 lowerBound;
        int256 upperBound;
        uint256 epoch;
        bytes32 sourceRecordSetRoot;
        bytes32 computationRuleHash;
        bytes32 outputCommitmentHash;
        address verifier;
        bytes32 proofDomainHash;
        uint64 formulaVersion;
        bytes32 sourceSetPolicyHash;
        uint256 evidenceReceiptId;
        AVADataTypes.Role authorityRole;
        bytes32 authorityId;
        AVADataTypes.StandingComputationStatus status;
        uint256 supersededBy;
        uint256 invalidatedByEvidenceReceiptId;
        string uri;
        address registeredBy;
    }

    function registerStandingFormula(AVADataTypes.Role actingRole, StandingFormulaInput calldata input)
        external
        returns (uint256 id);

    function registerSourceSetCommitment(AVADataTypes.Role actingRole, SourceSetCommitmentInput calldata input)
        external
        returns (uint256 id);

    function registerSourceSetCompletenessAttestation(
        AVADataTypes.Role actingRole,
        SourceSetCompletenessAttestationInput calldata input
    ) external returns (uint256 id);

    function registerStandingComputationStatement(
        AVADataTypes.Role actingRole,
        StandingComputationStatementInput calldata input
    ) external returns (uint256 id);

    function supersedeStandingComputationStatement(
        AVADataTypes.Role actingRole,
        uint256 oldStatementId,
        StandingComputationStatementInput calldata input
    ) external returns (uint256 id);

    function invalidateStandingComputationStatement(
        AVADataTypes.Role actingRole,
        uint256 statementId,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri
    ) external;

    function proofInputMatchesRegisteredCommitment(
        bytes32 workflowKey,
        bytes32 subjectCommitment,
        bytes32 vectorKey,
        bytes32 categoryHash,
        uint256 epoch,
        bytes32 sourceRecordSetRoot,
        bytes32 computationRuleHash,
        address verifier
    ) external view returns (bool);

    function getSourceSetCommitmentIdForProofInput(
        bytes32 workflowKey,
        bytes32 subjectCommitment,
        bytes32 vectorKey,
        bytes32 categoryHash,
        uint256 epoch,
        bytes32 sourceRecordSetRoot,
        bytes32 computationRuleHash,
        address verifier
    ) external view returns (uint256);

    function getSourceSetCommitmentIdForPackageProofInput(
        uint256 packageId,
        bytes32 workflowKey,
        bytes32 subjectCommitment,
        bytes32 vectorKey,
        bytes32 categoryHash,
        uint256 epoch,
        bytes32 sourceRecordSetRoot,
        bytes32 computationRuleHash,
        address verifier
    ) external view returns (uint256);

    function getStandingFormula(uint256 id) external view returns (StandingFormulaRecord memory);

    function getSourceSetCommitment(uint256 id) external view returns (SourceSetCommitmentRecord memory);

    function getSourceSetCompletenessAttestation(uint256 id)
        external
        view
        returns (SourceSetCompletenessAttestationRecord memory);

    function isSourceSetCompletenessAttestationActive(uint256 id) external view returns (bool);

    function getStandingComputationStatement(uint256 id)
        external
        view
        returns (StandingComputationStatementRecord memory);

    function isStandingComputationStatementActive(uint256 id) external view returns (bool);
}
