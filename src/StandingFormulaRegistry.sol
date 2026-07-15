// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "./AVADataTypes.sol";
import {AuthorityMatrix} from "./AuthorityMatrix.sol";
import {AVARulePackageRegistry} from "./AVARulePackageRegistry.sol";
import {EvidenceCommitmentRegistry} from "./EvidenceCommitmentRegistry.sol";
import {IStandingFormulaRegistry} from "./interfaces/IStandingFormulaRegistry.sol";
import {StandingRevisionRegistry} from "./StandingRevisionRegistry.sol";

contract StandingFormulaRegistry is IStandingFormulaRegistry {
    AuthorityMatrix public immutable authorityMatrix;
    AVARulePackageRegistry public immutable rulePackageRegistry;
    EvidenceCommitmentRegistry public immutable evidenceRegistry;
    StandingRevisionRegistry public immutable standingRevisionRegistry;

    uint256 public nextStandingFormulaId = 1;
    uint256 public nextSourceSetCommitmentId = 1;
    uint256 public nextSourceSetCompletenessAttestationId = 1;
    uint256 public nextStandingComputationStatementId = 1;

    mapping(uint256 => StandingFormulaRecord) private formulas;
    mapping(uint256 => SourceSetCommitmentRecord) private sourceSetCommitments;
    mapping(uint256 => SourceSetCompletenessAttestationRecord) private sourceSetCompletenessAttestations;
    mapping(uint256 => StandingComputationStatementRecord) private computationStatements;
    mapping(bytes32 => uint256) private formulaIdByKey;
    mapping(bytes32 => uint256) private sourceSetCommitmentIdByProofKey;
    mapping(uint256 => uint256) private sourceSetCompletenessAttestationIdBySourceSet;
    mapping(bytes32 => uint256) private computationStatementIdByKey;

    struct StatementBinding {
        SourceSetCommitmentRecord commitment;
        StandingFormulaRecord formula;
    }

    event StandingFormulaRegistered(
        uint256 indexed id,
        bytes32 indexed workflowKey,
        uint256 indexed packageId,
        bytes32 vectorKey,
        bytes32 computationRuleHash
    );

    event SourceSetCommitmentRegistered(
        uint256 indexed id, uint256 indexed formulaId, bytes32 indexed subjectCommitment, bytes32 sourceRecordSetRoot
    );

    event SourceSetCompletenessAttestationRegistered(
        uint256 indexed id,
        uint256 indexed sourceSetCommitmentId,
        bytes32 indexed subjectCommitment,
        bytes32 completenessAttestationHash
    );

    event StandingComputationStatementRegistered(
        uint256 indexed id,
        uint256 indexed sourceSetCommitmentId,
        bytes32 indexed subjectCommitment,
        bytes32 outputCommitmentHash
    );
    event StandingComputationStatementSuperseded(
        uint256 indexed id, uint256 indexed supersededBy, bytes32 indexed subjectCommitment, bytes32 authorityId
    );
    event StandingComputationStatementInvalidated(
        uint256 indexed id,
        uint256 indexed evidenceReceiptId,
        bytes32 indexed subjectCommitment,
        bytes32 authorityId,
        string uri
    );

    constructor(
        AuthorityMatrix authorityMatrix_,
        AVARulePackageRegistry rulePackageRegistry_,
        EvidenceCommitmentRegistry evidenceRegistry_,
        StandingRevisionRegistry standingRevisionRegistry_
    ) {
        if (
            address(authorityMatrix_) == address(0) || address(rulePackageRegistry_) == address(0)
                || address(evidenceRegistry_) == address(0) || address(standingRevisionRegistry_) == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
        authorityMatrix = authorityMatrix_;
        rulePackageRegistry = rulePackageRegistry_;
        evidenceRegistry = evidenceRegistry_;
        standingRevisionRegistry = standingRevisionRegistry_;
    }

    function registerStandingFormula(AVADataTypes.Role actingRole, StandingFormulaInput calldata input)
        external
        returns (uint256 id)
    {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.RegisterStandingFormula, input.authorityId
        );
        if (
            input.appId == bytes32(0) || input.workflowKey == bytes32(0) || input.vectorKey == bytes32(0)
                || input.formulaVersion == 0 || input.computationRuleHash == bytes32(0)
                || input.sourceSetPolicyHash == bytes32(0) || input.decayPolicyHash == bytes32(0)
                || input.capPolicyHash == bytes32(0) || input.restorationPolicyHash == bytes32(0)
                || input.verifier == address(0) || input.authorityId == bytes32(0) || bytes(input.uri).length == 0
        ) {
            revert AVADataTypes.EmptyValue();
        }

        uint256 packageId = rulePackageRegistry.getRulePackage(input.appId, input.workflowKey).packageId;
        bytes32 key = _formulaKey(
            packageId, input.vectorKey, input.formulaVersion, input.computationRuleHash, input.sourceSetPolicyHash
        );
        if (formulaIdByKey[key] != 0) revert AVADataTypes.InvalidState(formulaIdByKey[key]);

        id = nextStandingFormulaId++;
        formulas[id] = StandingFormulaRecord({
            id: id,
            appId: input.appId,
            workflowKey: input.workflowKey,
            packageId: packageId,
            vectorKey: input.vectorKey,
            formulaVersion: input.formulaVersion,
            computationRuleHash: input.computationRuleHash,
            sourceSetPolicyHash: input.sourceSetPolicyHash,
            decayPolicyHash: input.decayPolicyHash,
            capPolicyHash: input.capPolicyHash,
            restorationPolicyHash: input.restorationPolicyHash,
            verifier: input.verifier,
            authorityRole: actingRole,
            authorityId: input.authorityId,
            uri: input.uri,
            registeredBy: msg.sender,
            active: true
        });
        formulaIdByKey[key] = id;
        emit StandingFormulaRegistered(id, input.workflowKey, packageId, input.vectorKey, input.computationRuleHash);
    }

    function registerSourceSetCommitment(AVADataTypes.Role actingRole, SourceSetCommitmentInput calldata input)
        external
        returns (uint256 id)
    {
        StandingFormulaRecord memory formula = formulas[input.formulaId];
        if (formula.id == 0) revert AVADataTypes.UnknownReference(input.formulaId);
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.RegisterStandingSourceSetCommitment, input.authorityId
        );
        if (
            !formula.active || input.subjectCommitment == bytes32(0) || input.categoryHash == bytes32(0)
                || input.epoch == 0 || input.sourceRecordSetRoot == bytes32(0) || input.evidenceReceiptId == 0
                || input.completenessAttestationHash == bytes32(0) || input.authorityId == bytes32(0)
                || bytes(input.uri).length == 0
        ) {
            revert AVADataTypes.EmptyValue();
        }
        _validateEvidenceUses(
            formula.packageId,
            formula.workflowKey,
            AVADataTypes.Action.RegisterStandingSourceSetCommitment,
            input.evidenceReceiptId,
            0,
            0
        );
        AVADataTypes.EvidenceReceipt memory receipt =
            evidenceRegistry.requireUsableEvidenceReceipt(input.evidenceReceiptId, formula.appId, formula.workflowKey);
        if (receipt.packageId != formula.packageId) revert AVADataTypes.InvalidState(input.evidenceReceiptId);

        uint256 standingRevision = standingRevisionRegistry.currentRevision(formula.packageId, input.subjectCommitment);
        bytes32 proofKey = _proofKey(
            formula.packageId,
            input.subjectCommitment,
            standingRevision,
            formula.vectorKey,
            input.categoryHash,
            input.epoch,
            input.sourceRecordSetRoot,
            formula.computationRuleHash
        );
        if (sourceSetCommitmentIdByProofKey[proofKey] != 0) {
            revert AVADataTypes.InvalidState(sourceSetCommitmentIdByProofKey[proofKey]);
        }

        id = nextSourceSetCommitmentId++;
        sourceSetCommitments[id] = SourceSetCommitmentRecord({
            id: id,
            formulaId: input.formulaId,
            workflowKey: formula.workflowKey,
            packageId: formula.packageId,
            standingRevision: standingRevision,
            subjectCommitment: input.subjectCommitment,
            vectorKey: formula.vectorKey,
            categoryHash: input.categoryHash,
            epoch: input.epoch,
            sourceRecordSetRoot: input.sourceRecordSetRoot,
            computationRuleHash: formula.computationRuleHash,
            sourceSetPolicyHash: formula.sourceSetPolicyHash,
            evidenceReceiptId: input.evidenceReceiptId,
            completenessAttestationHash: input.completenessAttestationHash,
            authorityRole: actingRole,
            authorityId: input.authorityId,
            uri: input.uri,
            registeredBy: msg.sender
        });
        sourceSetCommitmentIdByProofKey[proofKey] = id;
        emit SourceSetCommitmentRegistered(id, input.formulaId, input.subjectCommitment, input.sourceRecordSetRoot);
    }

    function registerSourceSetCompletenessAttestation(
        AVADataTypes.Role actingRole,
        SourceSetCompletenessAttestationInput calldata input
    ) external returns (uint256 id) {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.RegisterSourceSetCompletenessAttestation, input.authorityId
        );
        SourceSetCommitmentRecord memory commitment = sourceSetCommitments[input.sourceSetCommitmentId];
        if (commitment.id == 0) revert AVADataTypes.UnknownReference(input.sourceSetCommitmentId);
        StandingFormulaRecord memory formula = formulas[commitment.formulaId];
        if (
            !formula.active || input.includedRecordClassesHash == bytes32(0) || input.exclusionPolicyHash == bytes32(0)
                || input.evidenceReceiptId == 0 || input.completenessAttestationHash == bytes32(0)
                || input.authorityId == bytes32(0) || bytes(input.uri).length == 0
        ) {
            revert AVADataTypes.EmptyValue();
        }
        if (input.completenessAttestationHash != commitment.completenessAttestationHash) {
            revert AVADataTypes.InvalidState(input.sourceSetCommitmentId);
        }
        if (
            commitment.standingRevision
                != standingRevisionRegistry.currentRevision(commitment.packageId, commitment.subjectCommitment)
        ) {
            revert AVADataTypes.InvalidState(input.sourceSetCommitmentId);
        }
        _validateEvidenceUses(
            commitment.packageId,
            commitment.workflowKey,
            AVADataTypes.Action.RegisterSourceSetCompletenessAttestation,
            commitment.evidenceReceiptId,
            input.evidenceReceiptId,
            0
        );
        _requireUsableEvidenceForPackage(commitment.evidenceReceiptId, commitment.workflowKey, commitment.packageId);
        uint256 existing = sourceSetCompletenessAttestationIdBySourceSet[input.sourceSetCommitmentId];
        if (existing != 0) revert AVADataTypes.InvalidState(existing);
        _requireUsableEvidenceForPackage(input.evidenceReceiptId, commitment.workflowKey, commitment.packageId);

        id = nextSourceSetCompletenessAttestationId++;
        sourceSetCompletenessAttestations[id] = SourceSetCompletenessAttestationRecord({
            id: id,
            sourceSetCommitmentId: input.sourceSetCommitmentId,
            formulaId: commitment.formulaId,
            workflowKey: commitment.workflowKey,
            packageId: commitment.packageId,
            standingRevision: commitment.standingRevision,
            subjectCommitment: commitment.subjectCommitment,
            vectorKey: commitment.vectorKey,
            categoryHash: commitment.categoryHash,
            epoch: commitment.epoch,
            sourceRecordSetRoot: commitment.sourceRecordSetRoot,
            computationRuleHash: commitment.computationRuleHash,
            sourceSetPolicyHash: commitment.sourceSetPolicyHash,
            includedRecordClassesHash: input.includedRecordClassesHash,
            exclusionPolicyHash: input.exclusionPolicyHash,
            evidenceReceiptId: input.evidenceReceiptId,
            completenessAttestationHash: input.completenessAttestationHash,
            authorityRole: actingRole,
            authorityId: input.authorityId,
            uri: input.uri,
            registeredBy: msg.sender,
            active: true
        });
        sourceSetCompletenessAttestationIdBySourceSet[input.sourceSetCommitmentId] = id;
        emit SourceSetCompletenessAttestationRegistered(
            id, input.sourceSetCommitmentId, commitment.subjectCommitment, input.completenessAttestationHash
        );
    }

    function registerStandingComputationStatement(
        AVADataTypes.Role actingRole,
        StandingComputationStatementInput calldata input
    ) external returns (uint256 id) {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.RegisterStandingComputationStatement, input.authorityId
        );
        StatementBinding memory binding =
            _validateStatementInput(input, AVADataTypes.Action.RegisterStandingComputationStatement);
        id = _storeComputationStatement(actingRole, input, binding);
    }

    function supersedeStandingComputationStatement(
        AVADataTypes.Role actingRole,
        uint256 oldStatementId,
        StandingComputationStatementInput calldata input
    ) external returns (uint256 id) {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.SupersedeStandingComputationStatement, input.authorityId
        );
        StandingComputationStatementRecord storage oldStatement = computationStatements[oldStatementId];
        if (oldStatement.id == 0) revert AVADataTypes.UnknownReference(oldStatementId);
        if (oldStatement.status != AVADataTypes.StandingComputationStatus.Active) {
            revert AVADataTypes.InvalidState(oldStatementId);
        }
        StatementBinding memory binding =
            _validateStatementInput(input, AVADataTypes.Action.SupersedeStandingComputationStatement);
        if (
            oldStatement.packageId != binding.formula.packageId
                || oldStatement.subjectCommitment != input.subjectCommitment
                || oldStatement.vectorKey != input.vectorKey || oldStatement.categoryHash != input.categoryHash
                || input.epoch <= oldStatement.epoch
        ) {
            revert AVADataTypes.InvalidState(oldStatementId);
        }
        id = _storeComputationStatement(actingRole, input, binding);
        oldStatement.status = AVADataTypes.StandingComputationStatus.Superseded;
        oldStatement.supersededBy = id;
        emit StandingComputationStatementSuperseded(oldStatementId, id, input.subjectCommitment, input.authorityId);
    }

    function invalidateStandingComputationStatement(
        AVADataTypes.Role actingRole,
        uint256 statementId,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri
    ) external {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.InvalidateStandingComputationStatement, authorityId
        );
        StandingComputationStatementRecord storage statement = computationStatements[statementId];
        if (statement.id == 0) revert AVADataTypes.UnknownReference(statementId);
        if (
            statement.status != AVADataTypes.StandingComputationStatus.Active || evidenceReceiptId == 0
                || authorityId == bytes32(0) || bytes(uri).length == 0
        ) {
            revert AVADataTypes.InvalidState(statementId);
        }
        AVADataTypes.EvidenceReceipt memory receipt = evidenceRegistry.requireUsableEvidenceReceipt(
            evidenceReceiptId, formulas[statement.formulaId].appId, statement.workflowKey
        );
        if (receipt.packageId != statement.packageId) revert AVADataTypes.InvalidState(evidenceReceiptId);
        statement.status = AVADataTypes.StandingComputationStatus.Invalidated;
        statement.invalidatedByEvidenceReceiptId = evidenceReceiptId;
        emit StandingComputationStatementInvalidated(
            statementId, evidenceReceiptId, statement.subjectCommitment, authorityId, uri
        );
    }

    function _storeComputationStatement(
        AVADataTypes.Role actingRole,
        StandingComputationStatementInput calldata input,
        StatementBinding memory binding
    ) internal returns (uint256 id) {
        bytes32 statementKey = _statementKey(
            input.sourceSetCommitmentId,
            input.sourceSetCompletenessAttestationId,
            input.threshold,
            input.lowerBound,
            input.upperBound,
            input.outputCommitmentHash,
            input.proofDomainHash
        );
        if (computationStatementIdByKey[statementKey] != 0) {
            revert AVADataTypes.InvalidState(computationStatementIdByKey[statementKey]);
        }

        id = nextStandingComputationStatementId++;
        computationStatements[id] = StandingComputationStatementRecord({
            id: id,
            sourceSetCommitmentId: input.sourceSetCommitmentId,
            sourceSetCompletenessAttestationId: input.sourceSetCompletenessAttestationId,
            formulaId: binding.formula.id,
            workflowKey: binding.formula.workflowKey,
            packageId: binding.formula.packageId,
            standingRevision: binding.commitment.standingRevision,
            subjectCommitment: input.subjectCommitment,
            vectorKey: input.vectorKey,
            categoryHash: input.categoryHash,
            threshold: input.threshold,
            lowerBound: input.lowerBound,
            upperBound: input.upperBound,
            epoch: input.epoch,
            sourceRecordSetRoot: input.sourceRecordSetRoot,
            computationRuleHash: input.computationRuleHash,
            outputCommitmentHash: input.outputCommitmentHash,
            verifier: binding.formula.verifier,
            proofDomainHash: input.proofDomainHash,
            formulaVersion: binding.formula.formulaVersion,
            sourceSetPolicyHash: binding.formula.sourceSetPolicyHash,
            evidenceReceiptId: input.evidenceReceiptId,
            authorityRole: actingRole,
            authorityId: input.authorityId,
            status: AVADataTypes.StandingComputationStatus.Active,
            supersededBy: 0,
            invalidatedByEvidenceReceiptId: 0,
            uri: input.uri,
            registeredBy: msg.sender
        });
        computationStatementIdByKey[statementKey] = id;
        emit StandingComputationStatementRegistered(
            id, input.sourceSetCommitmentId, input.subjectCommitment, input.outputCommitmentHash
        );
    }

    function proofInputMatchesRegisteredCommitment(
        bytes32 appId,
        bytes32 workflowKey,
        bytes32 subjectCommitment,
        bytes32 vectorKey,
        bytes32 categoryHash,
        uint256 epoch,
        bytes32 sourceRecordSetRoot,
        bytes32 computationRuleHash,
        address verifier
    ) external view returns (bool) {
        return getSourceSetCommitmentIdForProofInput(
            appId,
            workflowKey,
            subjectCommitment,
            vectorKey,
            categoryHash,
            epoch,
            sourceRecordSetRoot,
            computationRuleHash,
            verifier
        ) != 0;
    }

    function getSourceSetCommitmentIdForProofInput(
        bytes32 appId,
        bytes32 workflowKey,
        bytes32 subjectCommitment,
        bytes32 vectorKey,
        bytes32 categoryHash,
        uint256 epoch,
        bytes32 sourceRecordSetRoot,
        bytes32 computationRuleHash,
        address verifier
    ) public view returns (uint256) {
        if (appId == bytes32(0) || workflowKey == bytes32(0)) return 0;
        uint256 packageId = rulePackageRegistry.getRulePackage(appId, workflowKey).packageId;
        return _sourceSetCommitmentIdForPackageProofInput(
            packageId,
            workflowKey,
            subjectCommitment,
            vectorKey,
            categoryHash,
            epoch,
            sourceRecordSetRoot,
            computationRuleHash,
            verifier
        );
    }

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
    ) external view returns (uint256) {
        return _sourceSetCommitmentIdForPackageProofInput(
            packageId,
            workflowKey,
            subjectCommitment,
            vectorKey,
            categoryHash,
            epoch,
            sourceRecordSetRoot,
            computationRuleHash,
            verifier
        );
    }

    function _sourceSetCommitmentIdForPackageProofInput(
        uint256 packageId,
        bytes32 workflowKey,
        bytes32 subjectCommitment,
        bytes32 vectorKey,
        bytes32 categoryHash,
        uint256 epoch,
        bytes32 sourceRecordSetRoot,
        bytes32 computationRuleHash,
        address verifier
    ) internal view returns (uint256) {
        if (
            packageId == 0 || workflowKey == bytes32(0) || subjectCommitment == bytes32(0) || vectorKey == bytes32(0)
                || categoryHash == bytes32(0) || epoch == 0 || sourceRecordSetRoot == bytes32(0)
                || computationRuleHash == bytes32(0) || verifier == address(0)
                || !_isHistoricalPackageValid(packageId, workflowKey)
        ) {
            return 0;
        }
        uint256 standingRevision = standingRevisionRegistry.currentRevision(packageId, subjectCommitment);
        uint256 sourceSetCommitmentId = sourceSetCommitmentIdByProofKey[
            _proofKey(
                packageId,
                subjectCommitment,
                standingRevision,
                vectorKey,
                categoryHash,
                epoch,
                sourceRecordSetRoot,
                computationRuleHash
            )
        ];
        if (sourceSetCommitmentId == 0) return 0;
        SourceSetCommitmentRecord memory commitment = sourceSetCommitments[sourceSetCommitmentId];
        StandingFormulaRecord memory formula = formulas[commitment.formulaId];
        if (
            formula.active && commitment.standingRevision == standingRevision && formula.workflowKey == workflowKey
                && formula.packageId == packageId && formula.vectorKey == vectorKey
                && formula.computationRuleHash == computationRuleHash && formula.verifier == verifier
        ) {
            return sourceSetCommitmentId;
        }
        return 0;
    }

    function getStandingFormula(uint256 id) external view returns (StandingFormulaRecord memory) {
        StandingFormulaRecord memory formula = formulas[id];
        if (formula.id == 0) revert AVADataTypes.UnknownReference(id);
        return formula;
    }

    function getSourceSetCommitment(uint256 id) external view returns (SourceSetCommitmentRecord memory) {
        SourceSetCommitmentRecord memory commitment = sourceSetCommitments[id];
        if (commitment.id == 0) revert AVADataTypes.UnknownReference(id);
        return commitment;
    }

    function getSourceSetCompletenessAttestation(uint256 id)
        external
        view
        returns (SourceSetCompletenessAttestationRecord memory)
    {
        SourceSetCompletenessAttestationRecord memory attestation = sourceSetCompletenessAttestations[id];
        if (attestation.id == 0) revert AVADataTypes.UnknownReference(id);
        return attestation;
    }

    function isSourceSetCompletenessAttestationActive(uint256 id) external view returns (bool) {
        SourceSetCompletenessAttestationRecord memory attestation = sourceSetCompletenessAttestations[id];
        if (
            !attestation.active
                || attestation.standingRevision
                    != standingRevisionRegistry.currentRevision(attestation.packageId, attestation.subjectCommitment)
                || !_isHistoricalPackageValid(attestation.packageId, attestation.workflowKey)
        ) {
            return false;
        }
        SourceSetCommitmentRecord memory commitment = sourceSetCommitments[attestation.sourceSetCommitmentId];
        return commitment.id != 0 && commitment.packageId == attestation.packageId
            && commitment.workflowKey == attestation.workflowKey
            && _isEvidenceUsableForPackage(commitment.evidenceReceiptId, attestation.workflowKey, attestation.packageId)
            && _isEvidenceUsableForPackage(
            attestation.evidenceReceiptId, attestation.workflowKey, attestation.packageId
        );
    }

    function getStandingComputationStatement(uint256 id)
        external
        view
        returns (StandingComputationStatementRecord memory)
    {
        StandingComputationStatementRecord memory statement = computationStatements[id];
        if (statement.id == 0) revert AVADataTypes.UnknownReference(id);
        return statement;
    }

    function isStandingComputationStatementActive(uint256 id) external view returns (bool) {
        StandingComputationStatementRecord memory statement = computationStatements[id];
        if (
            statement.id == 0 || statement.status != AVADataTypes.StandingComputationStatus.Active
                || statement.standingRevision
                    != standingRevisionRegistry.currentRevision(statement.packageId, statement.subjectCommitment)
                || !_isHistoricalPackageValid(statement.packageId, statement.workflowKey)
        ) {
            return false;
        }
        SourceSetCommitmentRecord memory commitment = sourceSetCommitments[statement.sourceSetCommitmentId];
        SourceSetCompletenessAttestationRecord memory attestation =
            sourceSetCompletenessAttestations[statement.sourceSetCompletenessAttestationId];
        if (
            commitment.id == 0 || attestation.id == 0 || !attestation.active
                || commitment.packageId != statement.packageId || attestation.packageId != statement.packageId
                || commitment.workflowKey != statement.workflowKey || attestation.workflowKey != statement.workflowKey
                || attestation.sourceSetCommitmentId != commitment.id
        ) {
            return false;
        }
        return _isEvidenceUsableForPackage(commitment.evidenceReceiptId, statement.workflowKey, statement.packageId)
            && _isEvidenceUsableForPackage(attestation.evidenceReceiptId, statement.workflowKey, statement.packageId)
            && _isEvidenceUsableForPackage(statement.evidenceReceiptId, statement.workflowKey, statement.packageId);
    }

    function _validateStatementInput(StandingComputationStatementInput calldata input, AVADataTypes.Action action)
        internal
        view
        returns (StatementBinding memory binding)
    {
        if (
            input.sourceSetCommitmentId == 0 || input.sourceSetCompletenessAttestationId == 0
                || input.workflowKey == bytes32(0) || input.subjectCommitment == bytes32(0)
                || input.vectorKey == bytes32(0) || input.categoryHash == bytes32(0) || input.epoch == 0
                || input.sourceRecordSetRoot == bytes32(0) || input.computationRuleHash == bytes32(0)
                || input.outputCommitmentHash == bytes32(0) || input.proofDomainHash == bytes32(0)
                || input.evidenceReceiptId == 0 || input.authorityId == bytes32(0) || bytes(input.uri).length == 0
                || input.lowerBound > input.threshold || input.threshold > input.upperBound
        ) {
            revert AVADataTypes.EmptyValue();
        }
        binding.commitment = sourceSetCommitments[input.sourceSetCommitmentId];
        if (binding.commitment.id == 0) revert AVADataTypes.UnknownReference(input.sourceSetCommitmentId);
        binding.formula = formulas[binding.commitment.formulaId];
        if (
            !binding.formula.active || binding.formula.workflowKey != input.workflowKey
                || binding.commitment.workflowKey != input.workflowKey
                || binding.commitment.packageId != binding.formula.packageId
                || binding.commitment.standingRevision
                    != standingRevisionRegistry.currentRevision(
                        binding.commitment.packageId, binding.commitment.subjectCommitment
                    ) || binding.commitment.subjectCommitment != input.subjectCommitment
                || binding.commitment.vectorKey != input.vectorKey
                || binding.commitment.categoryHash != input.categoryHash || binding.commitment.epoch != input.epoch
                || binding.commitment.sourceRecordSetRoot != input.sourceRecordSetRoot
                || binding.commitment.computationRuleHash != input.computationRuleHash
        ) {
            revert AVADataTypes.InvalidState(input.sourceSetCommitmentId);
        }
        SourceSetCompletenessAttestationRecord memory attestation =
            sourceSetCompletenessAttestations[input.sourceSetCompletenessAttestationId];
        if (
            !attestation.active || attestation.sourceSetCommitmentId != input.sourceSetCommitmentId
                || attestation.formulaId != binding.formula.id || attestation.workflowKey != input.workflowKey
                || attestation.packageId != binding.formula.packageId
                || attestation.standingRevision != binding.commitment.standingRevision
                || attestation.subjectCommitment != input.subjectCommitment || attestation.vectorKey != input.vectorKey
                || attestation.categoryHash != input.categoryHash || attestation.epoch != input.epoch
                || attestation.sourceRecordSetRoot != input.sourceRecordSetRoot
                || attestation.computationRuleHash != input.computationRuleHash
                || attestation.sourceSetPolicyHash != binding.formula.sourceSetPolicyHash
                || attestation.completenessAttestationHash != binding.commitment.completenessAttestationHash
        ) {
            revert AVADataTypes.InvalidState(input.sourceSetCompletenessAttestationId);
        }
        _validateEvidenceUses(
            binding.formula.packageId,
            binding.formula.workflowKey,
            action,
            binding.commitment.evidenceReceiptId,
            attestation.evidenceReceiptId,
            input.evidenceReceiptId
        );
        _requireUsableEvidenceForPackage(
            binding.commitment.evidenceReceiptId, input.workflowKey, binding.formula.packageId
        );
        _requireUsableEvidenceForPackage(attestation.evidenceReceiptId, input.workflowKey, binding.formula.packageId);
        _requireUsableEvidenceForPackage(input.evidenceReceiptId, input.workflowKey, binding.formula.packageId);
    }

    function _requireUsableEvidenceForPackage(uint256 evidenceReceiptId, bytes32 workflowKey, uint256 packageId)
        internal
        view
    {
        AVARulePackageRegistry.RulePackage memory rulePackage = rulePackageRegistry.getRulePackageById(packageId);
        AVADataTypes.EvidenceReceipt memory receipt =
            evidenceRegistry.requireUsableEvidenceReceipt(evidenceReceiptId, rulePackage.appId, workflowKey);
        if (receipt.packageId != packageId) revert AVADataTypes.InvalidState(evidenceReceiptId);
    }

    function _isEvidenceUsableForPackage(uint256 evidenceReceiptId, bytes32 workflowKey, uint256 packageId)
        internal
        view
        returns (bool)
    {
        AVARulePackageRegistry.RulePackage memory rulePackage = rulePackageRegistry.getRulePackageById(packageId);
        try evidenceRegistry.requireUsableEvidenceReceipt(evidenceReceiptId, rulePackage.appId, workflowKey) returns (
            AVADataTypes.EvidenceReceipt memory receipt
        ) {
            return receipt.packageId == packageId;
        } catch {
            return false;
        }
    }

    function _validateEvidenceUses(
        uint256 packageId,
        bytes32 workflowKey,
        AVADataTypes.Action action,
        uint256 firstEvidenceReceiptId,
        uint256 secondEvidenceReceiptId,
        uint256 thirdEvidenceReceiptId
    ) internal view {
        AVARulePackageRegistry.RulePackage memory rulePackage = rulePackageRegistry.getRulePackageById(packageId);
        if (rulePackage.workflowKey != workflowKey) revert AVADataTypes.InvalidState(packageId);
        _validateEvidenceUse(rulePackage, action, firstEvidenceReceiptId);
        if (secondEvidenceReceiptId != 0 && secondEvidenceReceiptId != firstEvidenceReceiptId) {
            _validateEvidenceUse(rulePackage, action, secondEvidenceReceiptId);
        }
        if (
            thirdEvidenceReceiptId != 0 && thirdEvidenceReceiptId != firstEvidenceReceiptId
                && thirdEvidenceReceiptId != secondEvidenceReceiptId
        ) {
            _validateEvidenceUse(rulePackage, action, thirdEvidenceReceiptId);
        }
    }

    function _validateEvidenceUse(
        AVARulePackageRegistry.RulePackage memory rulePackage,
        AVADataTypes.Action action,
        uint256 evidenceReceiptId
    ) internal view {
        rulePackage.evidenceLifecycleModule
            .validateEvidenceLifecycle(
                rulePackage.workflowKey,
                action,
                evidenceReceiptId,
                AVADataTypes.EvidenceLifecycleKind.None,
                0,
                bytes32(0),
                msg.sender
            );
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

    function _formulaKey(
        uint256 packageId,
        bytes32 vectorKey,
        uint64 formulaVersion,
        bytes32 computationRuleHash,
        bytes32 sourceSetPolicyHash
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(packageId, vectorKey, formulaVersion, computationRuleHash, sourceSetPolicyHash));
    }

    function _proofKey(
        uint256 packageId,
        bytes32 subjectCommitment,
        uint256 standingRevision,
        bytes32 vectorKey,
        bytes32 categoryHash,
        uint256 epoch,
        bytes32 sourceRecordSetRoot,
        bytes32 computationRuleHash
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                packageId,
                subjectCommitment,
                standingRevision,
                vectorKey,
                categoryHash,
                epoch,
                sourceRecordSetRoot,
                computationRuleHash
            )
        );
    }

    function _statementKey(
        uint256 sourceSetCommitmentId,
        uint256 sourceSetCompletenessAttestationId,
        int256 threshold,
        int256 lowerBound,
        int256 upperBound,
        bytes32 outputCommitmentHash,
        bytes32 proofDomainHash
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                sourceSetCommitmentId,
                sourceSetCompletenessAttestationId,
                threshold,
                lowerBound,
                upperBound,
                outputCommitmentHash,
                proofDomainHash
            )
        );
    }
}
