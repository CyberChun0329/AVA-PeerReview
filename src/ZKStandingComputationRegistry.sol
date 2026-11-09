// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "./AVADataTypes.sol";
import {AVARulePackageRegistry} from "./AVARulePackageRegistry.sol";
import {IStandingFormulaRegistry} from "./interfaces/IStandingFormulaRegistry.sol";
import {IZKProofVerifier} from "./interfaces/IZKProofVerifier.sol";
import {StandingRevisionRegistry} from "./StandingRevisionRegistry.sol";

contract ZKStandingComputationRegistry {
    bytes32 public constant STANDING_CONTEXT_DOMAIN = keccak256("AVA_ZK_STANDING_COMPUTATION_CONTEXT_V1");
    bytes32 public constant STANDING_NULLIFIER_DOMAIN = keccak256("AVA_ZK_STANDING_COMPUTATION_NULLIFIER_V1");

    struct StandingProofInput {
        uint256 standingComputationStatementId;
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
    }

    struct StandingProofReceipt {
        uint256 id;
        bytes32 workflowKey;
        uint256 packageId;
        uint256 standingRevision;
        uint256 formulaId;
        uint256 sourceSetCommitmentId;
        uint256 standingComputationStatementId;
        uint64 formulaVersion;
        bytes32 sourceSetPolicyHash;
        address verifier;
        bytes32 proofDomainHash;
        bytes32 contextHash;
        bytes32 subjectCommitment;
        bytes32 nullifierHash;
        bytes32 vectorKey;
        bytes32 categoryHash;
        int256 threshold;
        int256 lowerBound;
        int256 upperBound;
        uint256 epoch;
        bytes32 sourceRecordSetRoot;
        bytes32 computationRuleHash;
        bytes32 outputCommitmentHash;
        bytes32 proofHash;
        address registeredBy;
    }

    IZKProofVerifier public immutable verifier;
    bytes32 public immutable VERIFIER_CODE_HASH;
    bytes32 public immutable PROOF_DOMAIN_HASH;
    AVARulePackageRegistry public immutable rulePackageRegistry;
    IStandingFormulaRegistry public immutable standingFormulaRegistry;
    StandingRevisionRegistry public immutable standingRevisionRegistry;
    uint256 public nextStandingProofReceiptId = 1;

    struct ProofBinding {
        uint256 packageId;
        uint256 formulaId;
        uint256 sourceSetCommitmentId;
        uint256 standingComputationStatementId;
        uint256 standingRevision;
        uint64 formulaVersion;
        bytes32 sourceSetPolicyHash;
    }

    mapping(uint256 => StandingProofReceipt) private standingProofReceipts;
    mapping(bytes32 => uint256) private receiptIdByContextHash;
    mapping(bytes32 => uint256) private receiptIdByNullifierHash;

    event ZKStandingComputationProofRecorded(
        uint256 indexed id,
        bytes32 indexed contextHash,
        bytes32 indexed nullifierHash,
        uint256 packageId,
        bytes32 subjectCommitment,
        bytes32 vectorKey,
        bytes32 categoryHash,
        bytes32 sourceRecordSetRoot,
        bytes32 computationRuleHash,
        address registeredBy
    );

    constructor(
        IZKProofVerifier verifier_,
        AVARulePackageRegistry rulePackageRegistry_,
        IStandingFormulaRegistry standingFormulaRegistry_,
        StandingRevisionRegistry standingRevisionRegistry_
    ) {
        if (
            address(verifier_) == address(0) || address(verifier_).code.length == 0
                || address(rulePackageRegistry_) == address(0)
                || address(standingFormulaRegistry_) == address(0)
                || address(standingRevisionRegistry_) == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
        verifier = verifier_;
        bytes32 proofDomainHash = verifier_.proofDomain();
        if (proofDomainHash == bytes32(0)) revert AVADataTypes.EmptyValue();
        VERIFIER_CODE_HASH = address(verifier_).codehash;
        PROOF_DOMAIN_HASH = proofDomainHash;
        rulePackageRegistry = rulePackageRegistry_;
        standingFormulaRegistry = standingFormulaRegistry_;
        standingRevisionRegistry = standingRevisionRegistry_;
    }

    function registerStandingProof(
        StandingProofInput calldata input,
        IZKProofVerifier.SchnorrProof calldata proof
    ) external returns (uint256 id) {
        _requireStableVerifier();
        bytes32 contextHash = computeStandingComputationContextHash(input);
        bytes32 nullifierHash = computeNullifierHash(contextHash, input.subjectCommitment);
        bytes32 proofDomainHash = PROOF_DOMAIN_HASH;
        if (
            contextHash == bytes32(0) || nullifierHash == bytes32(0) || receiptIdByContextHash[contextHash] != 0
                || receiptIdByNullifierHash[nullifierHash] != 0
        ) {
            revert AVADataTypes.InvalidState(uint256(contextHash));
        }
        ProofBinding memory binding = _proofBinding(input, contextHash);
        if (input.subjectCommitment != computeSubjectCommitment(proof.publicKey)) {
            revert AVADataTypes.InvalidState(uint256(input.subjectCommitment));
        }
        if (!verifier.verify(contextHash, proof)) revert AVADataTypes.InvalidState(uint256(contextHash));

        id = nextStandingProofReceiptId++;
        bytes32 proofHash = keccak256(abi.encode(proof));
        standingProofReceipts[id] = StandingProofReceipt({
            id: id,
            workflowKey: input.workflowKey,
            packageId: binding.packageId,
            standingRevision: binding.standingRevision,
            formulaId: binding.formulaId,
            sourceSetCommitmentId: binding.sourceSetCommitmentId,
            standingComputationStatementId: binding.standingComputationStatementId,
            formulaVersion: binding.formulaVersion,
            sourceSetPolicyHash: binding.sourceSetPolicyHash,
            verifier: address(verifier),
            proofDomainHash: proofDomainHash,
            contextHash: contextHash,
            subjectCommitment: input.subjectCommitment,
            nullifierHash: nullifierHash,
            vectorKey: input.vectorKey,
            categoryHash: input.categoryHash,
            threshold: input.threshold,
            lowerBound: input.lowerBound,
            upperBound: input.upperBound,
            epoch: input.epoch,
            sourceRecordSetRoot: input.sourceRecordSetRoot,
            computationRuleHash: input.computationRuleHash,
            outputCommitmentHash: input.outputCommitmentHash,
            proofHash: proofHash,
            registeredBy: msg.sender
        });
        receiptIdByContextHash[contextHash] = id;
        receiptIdByNullifierHash[nullifierHash] = id;

        _emitStandingProofRecorded(id);
    }

    function computeStandingComputationContextHash(StandingProofInput calldata input) public view returns (bytes32) {
        return computeStandingComputationContextHashForProofDomain(input, PROOF_DOMAIN_HASH);
    }

    function computeStandingComputationContextHashForProofDomain(
        StandingProofInput calldata input,
        bytes32 proofDomainHash
    ) public view returns (bytes32) {
        if (!_verifierStable() || proofDomainHash != PROOF_DOMAIN_HASH) return bytes32(0);
        if (!_hasRequiredInput(input)) return bytes32(0);
        (uint256 packageId, uint256 standingRevision) = _statementBindingForContext(input);
        if (packageId == 0) return bytes32(0);
        return keccak256(
            abi.encode(
                STANDING_CONTEXT_DOMAIN,
                keccak256(abi.encode(block.chainid, address(this), address(verifier))),
                proofDomainHash,
                packageId,
                standingRevision,
                input
            )
        );
    }

    function computeSubjectCommitment(IZKProofVerifier.G1Point calldata publicKey) public pure returns (bytes32) {
        return keccak256(abi.encode(publicKey.x, publicKey.y));
    }

    function computeNullifierHash(bytes32 contextHash, bytes32 subjectCommitment) public pure returns (bytes32) {
        if (contextHash == bytes32(0) || subjectCommitment == bytes32(0)) return bytes32(0);
        return keccak256(abi.encode(STANDING_NULLIFIER_DOMAIN, contextHash, subjectCommitment));
    }

    function standingProofSupportsCredential(
        uint256 receiptId,
        uint256 packageId,
        bytes32 subjectCommitment,
        bytes32 vectorKey,
        bytes32 categoryHash,
        int256 requiredThreshold
    ) external view returns (bool) {
        if (!_verifierStable()) return false;
        StandingProofReceipt memory receipt = standingProofReceipts[receiptId];
        if (receipt.id == 0) return false;
        if (!_receiptStatementStillActive(receipt)) return false;
        return receipt.packageId == packageId && receipt.subjectCommitment == subjectCommitment
            && receipt.vectorKey == vectorKey && receipt.categoryHash == categoryHash && receipt.threshold >= requiredThreshold
            && requiredThreshold >= receipt.lowerBound
            && requiredThreshold <= receipt.upperBound;
    }

    function hasVerifiedStandingProof(bytes32 contextHash) external view returns (bool) {
        return _verifierStable() && receiptIdByContextHash[contextHash] != 0;
    }

    function getStandingProofReceiptId(bytes32 contextHash) external view returns (uint256) {
        if (!_verifierStable()) return 0;
        return receiptIdByContextHash[contextHash];
    }

    function getStandingProofReceiptIdByNullifier(bytes32 nullifierHash) external view returns (uint256) {
        if (!_verifierStable()) return 0;
        return receiptIdByNullifierHash[nullifierHash];
    }

    function getStandingProofReceipt(uint256 id) external view returns (StandingProofReceipt memory) {
        StandingProofReceipt memory receipt = standingProofReceipts[id];
        if (receipt.id == 0) revert AVADataTypes.UnknownReference(id);
        return receipt;
    }

    function _hasRequiredInput(StandingProofInput calldata input) internal pure returns (bool) {
        return input.standingComputationStatementId != 0 && input.workflowKey != bytes32(0)
            && input.subjectCommitment != bytes32(0)
            && input.vectorKey != bytes32(0) && input.categoryHash != bytes32(0) && input.epoch != 0
            && input.sourceRecordSetRoot != bytes32(0) && input.computationRuleHash != bytes32(0)
            && input.outputCommitmentHash != bytes32(0)
            && input.lowerBound <= input.threshold && input.threshold <= input.upperBound
            && input.lowerBound <= input.upperBound;
    }

    function _proofBinding(StandingProofInput calldata input, bytes32 contextHash)
        internal
        view
        returns (ProofBinding memory binding)
    {
        IStandingFormulaRegistry.StandingComputationStatementRecord memory statement =
            standingFormulaRegistry.getStandingComputationStatement(input.standingComputationStatementId);
        if (
            !standingFormulaRegistry.isStandingComputationStatementActive(statement.id)
                || statement.status != AVADataTypes.StandingComputationStatus.Active
                || !_isHistoricalPackageValid(statement.packageId, statement.workflowKey)
                || statement.workflowKey != input.workflowKey || statement.subjectCommitment != input.subjectCommitment
                || statement.vectorKey != input.vectorKey || statement.categoryHash != input.categoryHash
                || statement.threshold != input.threshold || statement.lowerBound != input.lowerBound
                || statement.upperBound != input.upperBound || statement.epoch != input.epoch
                || statement.sourceRecordSetRoot != input.sourceRecordSetRoot
                || statement.computationRuleHash != input.computationRuleHash
                || statement.outputCommitmentHash != input.outputCommitmentHash
                || statement.verifier != address(verifier) || statement.proofDomainHash != verifier.proofDomain()
                || statement.standingRevision
                    != standingRevisionRegistry.currentRevision(statement.packageId, statement.subjectCommitment)
        ) {
            revert AVADataTypes.InvalidState(uint256(contextHash));
        }
        _validateProofEvidenceLifecycle(statement);
        binding.packageId = statement.packageId;
        binding.formulaId = statement.formulaId;
        binding.sourceSetCommitmentId = statement.sourceSetCommitmentId;
        binding.standingComputationStatementId = statement.id;
        binding.standingRevision = statement.standingRevision;
        binding.formulaVersion = statement.formulaVersion;
        binding.sourceSetPolicyHash = statement.sourceSetPolicyHash;
    }

    function _receiptStatementStillActive(StandingProofReceipt memory receipt) internal view returns (bool) {
        if (!_verifierStable()) return false;
        if (receipt.standingComputationStatementId == 0) return false;
        try standingFormulaRegistry.getStandingComputationStatement(receipt.standingComputationStatementId) returns (
            IStandingFormulaRegistry.StandingComputationStatementRecord memory statement
        ) {
            if (
                !standingFormulaRegistry.isStandingComputationStatementActive(statement.id)
                    || statement.status != AVADataTypes.StandingComputationStatus.Active
                    || !_isHistoricalPackageValid(statement.packageId, statement.workflowKey)
                    || statement.id != receipt.standingComputationStatementId
                    || statement.packageId != receipt.packageId || statement.formulaId != receipt.formulaId
                    || statement.standingRevision != receipt.standingRevision
                    || statement.standingRevision
                        != standingRevisionRegistry.currentRevision(statement.packageId, statement.subjectCommitment)
                    || statement.sourceSetCommitmentId != receipt.sourceSetCommitmentId
                    || statement.workflowKey != receipt.workflowKey
                    || statement.subjectCommitment != receipt.subjectCommitment
            ) {
                return false;
            }
            if (
                statement.vectorKey != receipt.vectorKey || statement.categoryHash != receipt.categoryHash
                    || statement.threshold != receipt.threshold || statement.lowerBound != receipt.lowerBound
                    || statement.upperBound != receipt.upperBound || statement.epoch != receipt.epoch
            ) {
                return false;
            }
            return statement.sourceRecordSetRoot == receipt.sourceRecordSetRoot
                && statement.computationRuleHash == receipt.computationRuleHash
                && statement.outputCommitmentHash == receipt.outputCommitmentHash
                && statement.verifier == receipt.verifier
                && statement.proofDomainHash == receipt.proofDomainHash
                && statement.formulaVersion == receipt.formulaVersion
                && statement.sourceSetPolicyHash == receipt.sourceSetPolicyHash;
        } catch {
            return false;
        }
    }

    function _statementBindingForContext(StandingProofInput calldata input)
        internal
        view
        returns (uint256 packageId, uint256 standingRevision)
    {
        try standingFormulaRegistry.getStandingComputationStatement(input.standingComputationStatementId) returns (
            IStandingFormulaRegistry.StandingComputationStatementRecord memory statement
        ) {
            if (
                !standingFormulaRegistry.isStandingComputationStatementActive(statement.id)
                    || statement.status != AVADataTypes.StandingComputationStatus.Active
                    || !_isHistoricalPackageValid(statement.packageId, statement.workflowKey)
                    || statement.workflowKey != input.workflowKey || statement.subjectCommitment != input.subjectCommitment
                    || statement.standingRevision
                        != standingRevisionRegistry.currentRevision(statement.packageId, statement.subjectCommitment)
            ) {
                return (0, 0);
            }
            return (statement.packageId, statement.standingRevision);
        } catch {
            return (0, 0);
        }
    }

    function _isHistoricalPackageValid(uint256 packageId, bytes32 workflowKey) internal view returns (bool) {
        try rulePackageRegistry.getRulePackageById(packageId) returns (
            AVARulePackageRegistry.RulePackage memory rulePackage
        ) {
            return rulePackage.workflowKey == workflowKey;
        } catch {
            return false;
        }
    }

    function _validateProofEvidenceLifecycle(
        IStandingFormulaRegistry.StandingComputationStatementRecord memory statement
    ) internal view {
        AVARulePackageRegistry.RulePackage memory rulePackage =
            rulePackageRegistry.getRulePackageById(statement.packageId);
        if (rulePackage.workflowKey != statement.workflowKey) revert AVADataTypes.InvalidState(statement.packageId);
        IStandingFormulaRegistry.SourceSetCommitmentRecord memory commitment =
            standingFormulaRegistry.getSourceSetCommitment(statement.sourceSetCommitmentId);
        IStandingFormulaRegistry.SourceSetCompletenessAttestationRecord memory attestation =
            standingFormulaRegistry.getSourceSetCompletenessAttestation(statement.sourceSetCompletenessAttestationId);
        if (
            commitment.packageId != statement.packageId || attestation.packageId != statement.packageId
                || commitment.workflowKey != statement.workflowKey || attestation.workflowKey != statement.workflowKey
        ) {
            revert AVADataTypes.InvalidState(statement.id);
        }
        _validateProofEvidenceReceipt(rulePackage, commitment.evidenceReceiptId);
        if (attestation.evidenceReceiptId != commitment.evidenceReceiptId) {
            _validateProofEvidenceReceipt(rulePackage, attestation.evidenceReceiptId);
        }
        if (
            statement.evidenceReceiptId != commitment.evidenceReceiptId
                && statement.evidenceReceiptId != attestation.evidenceReceiptId
        ) {
            _validateProofEvidenceReceipt(rulePackage, statement.evidenceReceiptId);
        }
    }

    function _validateProofEvidenceReceipt(
        AVARulePackageRegistry.RulePackage memory rulePackage,
        uint256 evidenceReceiptId
    ) internal view {
        rulePackage.evidenceLifecycleModule.validateEvidenceLifecycle(
            rulePackage.workflowKey,
            AVADataTypes.Action.RegisterStandingProof,
            evidenceReceiptId,
            AVADataTypes.EvidenceLifecycleKind.None,
            0,
            bytes32(0),
            msg.sender
        );
    }

    function _emitStandingProofRecorded(uint256 id) internal {
        StandingProofReceipt memory receipt = standingProofReceipts[id];
        emit ZKStandingComputationProofRecorded(
            id,
            receipt.contextHash,
            receipt.nullifierHash,
            receipt.packageId,
            receipt.subjectCommitment,
            receipt.vectorKey,
            receipt.categoryHash,
            receipt.sourceRecordSetRoot,
            receipt.computationRuleHash,
            receipt.registeredBy
        );
    }

    function _requireStableVerifier() internal view {
        if (!_verifierStable()) revert AVADataTypes.InvalidState(uint256(PROOF_DOMAIN_HASH));
    }

    function _verifierStable() internal view returns (bool) {
        if (address(verifier).codehash != VERIFIER_CODE_HASH) return false;
        try verifier.proofDomain() returns (bytes32 proofDomainHash) {
            return proofDomainHash == PROOF_DOMAIN_HASH;
        } catch {
            return false;
        }
    }
}
