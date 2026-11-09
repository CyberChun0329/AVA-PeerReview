// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IZKProofVerifier} from "../../interfaces/IZKProofVerifier.sol";
import {IAVAApplicationModule} from "../../interfaces/IAVAApplicationModule.sol";
import {AVAAuthorityMatrix} from "../../core/AVAAuthorityMatrix.sol";
import {AVACapabilityKeys} from "../../core/AVACapabilityKeys.sol";
import {AVACoreRulePackageRegistry} from "../../core/AVACoreRulePackageRegistry.sol";
import {AVACoreTypes} from "../../core/AVACoreTypes.sol";
import {AVADisclosurePolicyRegistry} from "../../core/AVADisclosurePolicyRegistry.sol";
import {AVAEvidenceRegistry} from "../../core/AVAEvidenceRegistry.sol";
import {AVAGovernanceKernel} from "../../core/AVAGovernanceKernel.sol";
import {AVAIdentityRegistry} from "../../core/AVAIdentityRegistry.sol";
import {IAVAAntiAbusePolicyModule} from "../../core/interfaces/IAVACoreRuleModules.sol";
import {AVAExtensionRecordBase} from "../shared/AVAExtensionRecordBase.sol";
import {IAVAExtensionPolicyModule} from "../shared/IAVAExtensionPolicyModule.sol";
import {IAVAStandingRevision} from "./IAVAStandingRevision.sol";

contract AVAStandingProvenanceExtension is AVAExtensionRecordBase {
    enum StatementStatus {
        None,
        Active,
        Superseded,
        Invalidated
    }

    struct FormulaInput {
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 roleKey;
        bytes32 authorityId;
        bytes32 vectorKey;
        uint64 formulaVersion;
        bytes32 computationRuleHash;
        bytes32 sourceSetPolicyHash;
        bytes32 decayPolicyHash;
        bytes32 capPolicyHash;
        bytes32 restorationPolicyHash;
        address verifier;
        bytes32 proofDomainHash;
        string uri;
    }

    struct FormulaRecord {
        uint256 id;
        bytes32 appId;
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
        bytes32 proofDomainHash;
        bytes32 authorityId;
        string uri;
        address registeredBy;
        uint64 registeredAt;
        bool active;
    }

    struct FormulaModules {
        AVACoreRulePackageRegistry.VerifiedPackageContext rulePackage;
        IAVAExtensionPolicyModule standingProvenance;
        IAVAAntiAbusePolicyModule antiAbuse;
    }

    struct SourceSetInput {
        uint256 formulaId;
        uint256 recognisedStateId;
        bytes32 roleKey;
        bytes32 authorityId;
        bytes32 subjectId;
        bytes32 subjectCommitment;
        bytes32 categoryHash;
        uint256 epoch;
        bytes32 sourceRecordSetRoot;
        uint256 evidenceId;
        bytes32 completenessCommitment;
        string uri;
    }

    struct SourceSetRecord {
        uint256 id;
        uint256 formulaId;
        uint256 recognisedStateId;
        uint256 recognisedStateTransitionId;
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        uint256 revision;
        bytes32 subjectId;
        bytes32 subjectCommitment;
        bytes32 vectorKey;
        bytes32 categoryHash;
        uint256 epoch;
        bytes32 sourceRecordSetRoot;
        uint256 evidenceId;
        bytes32 completenessCommitment;
        bytes32 authorityId;
        string uri;
        address registeredBy;
        uint64 registeredAt;
    }

    struct CompletenessInput {
        uint256 sourceSetId;
        bytes32 roleKey;
        bytes32 authorityId;
        uint256 evidenceId;
        bytes32 includedRecordClassesHash;
        bytes32 exclusionPolicyHash;
        bytes32 attestationHash;
        string uri;
    }

    struct CompletenessRecord {
        uint256 id;
        uint256 sourceSetId;
        uint256 packageId;
        uint256 revision;
        uint256 evidenceId;
        bytes32 includedRecordClassesHash;
        bytes32 exclusionPolicyHash;
        bytes32 attestationHash;
        bytes32 authorityId;
        string uri;
        address registeredBy;
        uint64 registeredAt;
        bool active;
    }

    struct StatementInput {
        uint256 sourceSetId;
        uint256 completenessAttestationId;
        bytes32 roleKey;
        bytes32 authorityId;
        uint256 evidenceId;
        int256 threshold;
        int256 lowerBound;
        int256 upperBound;
        bytes32 outputCommitment;
        string uri;
    }

    struct StatementRecord {
        uint256 id;
        uint256 formulaId;
        uint256 sourceSetId;
        uint256 completenessAttestationId;
        uint256 recognisedStateId;
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        uint256 revision;
        bytes32 subjectId;
        bytes32 subjectCommitment;
        bytes32 vectorKey;
        bytes32 categoryHash;
        int256 threshold;
        int256 lowerBound;
        int256 upperBound;
        uint256 epoch;
        bytes32 sourceRecordSetRoot;
        bytes32 computationRuleHash;
        bytes32 sourceSetPolicyHash;
        bytes32 outputCommitment;
        address verifier;
        bytes32 proofDomainHash;
        uint256 evidenceId;
        bytes32 authorityId;
        StatementStatus status;
        uint256 supersededBy;
        uint256 invalidatedByEvidenceId;
        string uri;
        address registeredBy;
        uint64 registeredAt;
    }

    bytes32 private constant FORMULA_TYPE = keccak256("ava.standing.formula.v1");
    bytes32 private constant SOURCE_SET_TYPE = keccak256("ava.standing.source-set.v1");
    bytes32 private constant COMPLETENESS_TYPE = keccak256("ava.standing.source-set-completeness.v1");
    bytes32 private constant STATEMENT_TYPE = keccak256("ava.standing.computation-statement.v1");

    IAVAStandingRevision public immutable REVISION_REGISTRY;

    mapping(uint256 => FormulaRecord) private formulas;
    mapping(uint256 => SourceSetRecord) private sourceSets;
    mapping(uint256 => CompletenessRecord) private completenessRecords;
    mapping(uint256 => StatementRecord) private statements;
    mapping(bytes32 => uint256) public formulaIdByVersion;
    mapping(bytes32 => uint256) public sourceSetIdByCommitment;
    mapping(uint256 => uint256) public completenessIdBySourceSet;
    mapping(uint256 => uint256) public activeStatementIdBySourceSet;
    uint256 public nextFormulaId = 1;
    uint256 public nextSourceSetId = 1;
    uint256 public nextCompletenessId = 1;
    uint256 public nextStatementId = 1;

    event StandingFormulaRegistered(uint256 indexed id, uint256 indexed packageId, bytes32 indexed vectorKey);
    event StandingSourceSetRegistered(
        uint256 indexed id, uint256 indexed formulaId, bytes32 indexed subjectCommitment, uint256 revision
    );
    event StandingSourceSetCompletenessRecorded(uint256 indexed id, uint256 indexed sourceSetId);
    event StandingComputationStatementRecorded(
        uint256 indexed id, uint256 indexed sourceSetId, bytes32 indexed subjectCommitment, uint256 revision
    );
    event StandingComputationStatementSuperseded(uint256 indexed id, uint256 indexed replacementId);
    event StandingComputationStatementInvalidated(uint256 indexed id, uint256 indexed evidenceId);

    constructor(
        AVAGovernanceKernel governanceKernel_,
        AVAAuthorityMatrix authorityMatrix_,
        AVAIdentityRegistry identityRegistry_,
        AVACoreRulePackageRegistry rulePackageRegistry_,
        AVAEvidenceRegistry evidenceRegistry_,
        AVADisclosurePolicyRegistry disclosureRegistry_,
        IAVAStandingRevision revisionRegistry_
    )
        AVAExtensionRecordBase(
            governanceKernel_,
            authorityMatrix_,
            identityRegistry_,
            rulePackageRegistry_,
            evidenceRegistry_,
            disclosureRegistry_
        )
    {
        if (address(revisionRegistry_) == address(0) || address(revisionRegistry_).code.length == 0) {
            revert AVACoreTypes.EmptyValue();
        }
        if (address(revisionRegistry_.GOVERNANCE_KERNEL()) != address(governanceKernel_)) {
            revert AVACoreTypes.InvalidState(0);
        }
        REVISION_REGISTRY = revisionRegistry_;
    }

    function registerFormula(FormulaInput calldata input) external returns (uint256 id) {
        _requireFormulaInput(input);
        FormulaModules memory modules = _verifiedFormulaModules(input.packageId);
        if (modules.rulePackage.appId != input.appId || modules.rulePackage.workflowKey != input.workflowKey) {
            revert AVACoreTypes.InvalidState(input.packageId);
        }
        AUTHORITY_MATRIX.requireAuthorisedSubject(
            msg.sender, input.appId, input.roleKey, AVACoreTypes.ACTION_REGISTER_STANDING_FORMULA, input.authorityId
        );
        if (IZKProofVerifier(input.verifier).proofDomain() != input.proofDomainHash) {
            revert AVACoreTypes.InvalidState(input.packageId);
        }
        bytes32 versionKey = keccak256(abi.encode(input.packageId, input.vectorKey, input.formulaVersion));
        if (formulaIdByVersion[versionKey] != 0) revert AVACoreTypes.InvalidState(formulaIdByVersion[versionKey]);
        _validatePackagePolicy(
            input,
            keccak256(
                abi.encode(
                    input.computationRuleHash,
                    input.sourceSetPolicyHash,
                    input.decayPolicyHash,
                    input.capPolicyHash,
                    input.restorationPolicyHash,
                    input.verifier,
                    input.proofDomainHash
                )
            ),
            modules.standingProvenance
        );
        _validateFormulaAntiAbuse(input, modules.antiAbuse);
        id = nextFormulaId++;
        FormulaRecord storage record = formulas[id];
        record.id = id;
        record.appId = input.appId;
        record.workflowKey = input.workflowKey;
        record.packageId = input.packageId;
        record.vectorKey = input.vectorKey;
        record.formulaVersion = input.formulaVersion;
        record.computationRuleHash = input.computationRuleHash;
        record.sourceSetPolicyHash = input.sourceSetPolicyHash;
        record.decayPolicyHash = input.decayPolicyHash;
        record.capPolicyHash = input.capPolicyHash;
        record.restorationPolicyHash = input.restorationPolicyHash;
        record.verifier = input.verifier;
        record.proofDomainHash = input.proofDomainHash;
        record.authorityId = input.authorityId;
        record.uri = input.uri;
        record.registeredBy = msg.sender;
        record.registeredAt = uint64(block.timestamp);
        record.active = true;
        formulaIdByVersion[versionKey] = id;
        emit StandingFormulaRegistered(id, input.packageId, input.vectorKey);
    }

    function registerSourceSet(SourceSetInput calldata input) external returns (uint256 id) {
        if (
            input.formulaId == 0 || input.recognisedStateId == 0 || input.subjectCommitment == bytes32(0)
                || input.categoryHash == bytes32(0) || input.epoch == 0 || input.sourceRecordSetRoot == bytes32(0)
                || input.completenessCommitment == bytes32(0)
        ) revert AVACoreTypes.EmptyValue();
        FormulaRecord memory formula = getFormula(input.formulaId);
        AVAGovernanceKernel.RecognisedStateReference memory state = _validateExtension(
            ExtensionValidationInput({
                recognisedStateId: input.recognisedStateId,
                roleKey: input.roleKey,
                authorityId: input.authorityId,
                subjectId: input.subjectId,
                evidenceId: input.evidenceId,
                capabilityKey: AVACapabilityKeys.STANDING_PROVENANCE,
                actionKey: AVACoreTypes.ACTION_REGISTER_STANDING_SOURCE_SET,
                recordTypeKey: SOURCE_SET_TYPE,
                scopeKey: formula.vectorKey,
                sourceTypeKey: FORMULA_TYPE,
                sourceRecordId: formula.id,
                unsignedValue: input.epoch,
                validUntil: 0,
                payloadHash: keccak256(
                    abi.encode(
                        input.subjectCommitment,
                        input.categoryHash,
                        input.sourceRecordSetRoot,
                        input.completenessCommitment
                    )
                ),
                requireActiveSubject: true,
                contextHash: keccak256(
                    abi.encode(formula.id, input.recognisedStateId, input.subjectCommitment, input.epoch)
                )
            })
        );
        if (
            !formula.active || formula.appId != state.appId || formula.workflowKey != state.workflowKey
                || formula.packageId != state.packageId || !_isStandingStatus(state.status)
        ) revert AVACoreTypes.InvalidState(input.formulaId);
        uint256 revision = REVISION_REGISTRY.currentRevision(state.packageId, state.subjectId);
        if (revision == 0) revert AVACoreTypes.InvalidState(input.recognisedStateId);
        bytes32 sourceKey = keccak256(
            abi.encode(
                state.packageId,
                state.subjectId,
                input.subjectCommitment,
                formula.vectorKey,
                input.categoryHash,
                input.epoch,
                input.sourceRecordSetRoot
            )
        );
        if (sourceSetIdByCommitment[sourceKey] != 0) {
            revert AVACoreTypes.InvalidState(sourceSetIdByCommitment[sourceKey]);
        }
        id = nextSourceSetId++;
        SourceSetRecord storage record = sourceSets[id];
        record.id = id;
        record.formulaId = formula.id;
        record.recognisedStateId = state.id;
        record.recognisedStateTransitionId = state.lastTransitionId;
        record.appId = state.appId;
        record.workflowKey = state.workflowKey;
        record.packageId = state.packageId;
        record.revision = revision;
        record.subjectId = state.subjectId;
        record.subjectCommitment = input.subjectCommitment;
        record.vectorKey = formula.vectorKey;
        record.categoryHash = input.categoryHash;
        record.epoch = input.epoch;
        record.sourceRecordSetRoot = input.sourceRecordSetRoot;
        record.evidenceId = input.evidenceId;
        record.completenessCommitment = input.completenessCommitment;
        record.authorityId = input.authorityId;
        record.uri = input.uri;
        record.registeredBy = msg.sender;
        record.registeredAt = uint64(block.timestamp);
        sourceSetIdByCommitment[sourceKey] = id;
        emit StandingSourceSetRegistered(id, formula.id, input.subjectCommitment, revision);
    }

    function recordCompletenessAttestation(CompletenessInput calldata input) external returns (uint256 id) {
        if (
            input.sourceSetId == 0 || input.includedRecordClassesHash == bytes32(0)
                || input.exclusionPolicyHash == bytes32(0) || input.attestationHash == bytes32(0)
        ) revert AVACoreTypes.EmptyValue();
        SourceSetRecord memory sourceSet = getSourceSet(input.sourceSetId);
        _validateExtension(
            ExtensionValidationInput({
                recognisedStateId: sourceSet.recognisedStateId,
                roleKey: input.roleKey,
                authorityId: input.authorityId,
                subjectId: sourceSet.subjectId,
                evidenceId: input.evidenceId,
                capabilityKey: AVACapabilityKeys.STANDING_PROVENANCE,
                actionKey: AVACoreTypes.ACTION_ATTEST_STANDING_SOURCE_SET,
                recordTypeKey: COMPLETENESS_TYPE,
                scopeKey: sourceSet.vectorKey,
                sourceTypeKey: SOURCE_SET_TYPE,
                sourceRecordId: sourceSet.id,
                unsignedValue: sourceSet.epoch,
                validUntil: 0,
                payloadHash: keccak256(
                    abi.encode(input.includedRecordClassesHash, input.exclusionPolicyHash, input.attestationHash)
                ),
                requireActiveSubject: true,
                contextHash: keccak256(abi.encode(sourceSet.id, input.attestationHash))
            })
        );
        if (!_isSourceSetCurrent(sourceSet) || completenessIdBySourceSet[sourceSet.id] != 0) {
            revert AVACoreTypes.InvalidState(sourceSet.id);
        }
        id = nextCompletenessId++;
        CompletenessRecord storage record = completenessRecords[id];
        record.id = id;
        record.sourceSetId = sourceSet.id;
        record.packageId = sourceSet.packageId;
        record.revision = sourceSet.revision;
        record.evidenceId = input.evidenceId;
        record.includedRecordClassesHash = input.includedRecordClassesHash;
        record.exclusionPolicyHash = input.exclusionPolicyHash;
        record.attestationHash = input.attestationHash;
        record.authorityId = input.authorityId;
        record.uri = input.uri;
        record.registeredBy = msg.sender;
        record.registeredAt = uint64(block.timestamp);
        record.active = true;
        completenessIdBySourceSet[sourceSet.id] = id;
        emit StandingSourceSetCompletenessRecorded(id, sourceSet.id);
    }

    function recordComputationStatement(StatementInput calldata input) external returns (uint256 id) {
        id = _recordStatement(input, AVACoreTypes.ACTION_RECORD_STANDING_COMPUTATION_STATEMENT, 0);
    }

    function supersedeComputationStatement(uint256 statementId, StatementInput calldata input)
        external
        returns (uint256 id)
    {
        StatementRecord storage previous = _statementStorage(statementId);
        if (previous.status != StatementStatus.Active || previous.sourceSetId != input.sourceSetId) {
            revert AVACoreTypes.InvalidState(statementId);
        }
        id = _recordStatement(input, AVACoreTypes.ACTION_SUPERSEDE_STANDING_COMPUTATION_STATEMENT, statementId);
        previous.status = StatementStatus.Superseded;
        previous.supersededBy = id;
        emit StandingComputationStatementSuperseded(statementId, id);
    }

    function invalidateComputationStatement(
        uint256 statementId,
        uint256 evidenceId,
        bytes32 roleKey,
        bytes32 authorityId
    ) external {
        StatementRecord storage statement = _statementStorage(statementId);
        if (statement.status != StatementStatus.Active || evidenceId == 0) {
            revert AVACoreTypes.InvalidState(statementId);
        }
        SourceSetRecord memory sourceSet = getSourceSet(statement.sourceSetId);
        _validateExtension(
            ExtensionValidationInput({
                recognisedStateId: sourceSet.recognisedStateId,
                roleKey: roleKey,
                authorityId: authorityId,
                subjectId: sourceSet.subjectId,
                evidenceId: evidenceId,
                capabilityKey: AVACapabilityKeys.STANDING_PROVENANCE,
                actionKey: AVACoreTypes.ACTION_INVALIDATE_STANDING_COMPUTATION_STATEMENT,
                recordTypeKey: STATEMENT_TYPE,
                scopeKey: sourceSet.vectorKey,
                sourceTypeKey: STATEMENT_TYPE,
                sourceRecordId: statementId,
                unsignedValue: sourceSet.epoch,
                validUntil: 0,
                payloadHash: bytes32(statementId),
                requireActiveSubject: false,
                contextHash: keccak256(abi.encode(statementId, evidenceId, authorityId))
            })
        );
        statement.status = StatementStatus.Invalidated;
        statement.invalidatedByEvidenceId = evidenceId;
        delete activeStatementIdBySourceSet[sourceSet.id];
        emit StandingComputationStatementInvalidated(statementId, evidenceId);
    }

    function isComputationStatementActive(uint256 statementId) public view returns (bool) {
        StatementRecord memory statement = statements[statementId];
        if (statement.id == 0 || statement.status != StatementStatus.Active) return false;
        if (activeStatementIdBySourceSet[statement.sourceSetId] != statement.id) return false;
        SourceSetRecord memory sourceSet = sourceSets[statement.sourceSetId];
        CompletenessRecord memory completeness = completenessRecords[statement.completenessAttestationId];
        if (
            sourceSet.id == 0 || completeness.id == 0 || !completeness.active
                || completeness.sourceSetId != sourceSet.id || sourceSet.packageId != statement.packageId
                || sourceSet.revision != statement.revision || completeness.revision != statement.revision
        ) return false;
        if (!_isSourceSetCurrent(sourceSet)) return false;
        return
            _isEvidenceCurrent(completeness.evidenceId, statement)
                && _isEvidenceCurrent(statement.evidenceId, statement);
    }

    function getFormula(uint256 id) public view returns (FormulaRecord memory record) {
        record = formulas[id];
        if (record.id == 0) revert AVACoreTypes.UnknownReference(id);
    }

    function getSourceSet(uint256 id) public view returns (SourceSetRecord memory record) {
        record = sourceSets[id];
        if (record.id == 0) revert AVACoreTypes.UnknownReference(id);
    }

    function getCompletenessAttestation(uint256 id) external view returns (CompletenessRecord memory record) {
        record = completenessRecords[id];
        if (record.id == 0) revert AVACoreTypes.UnknownReference(id);
    }

    function getComputationStatement(uint256 id) public view returns (StatementRecord memory record) {
        record = statements[id];
        if (record.id == 0) revert AVACoreTypes.UnknownReference(id);
    }

    function _recordStatement(StatementInput calldata input, bytes32 actionKey, uint256 replacedStatementId)
        private
        returns (uint256 id)
    {
        if (
            input.sourceSetId == 0 || input.completenessAttestationId == 0 || input.outputCommitment == bytes32(0)
                || input.lowerBound > input.threshold || input.threshold > input.upperBound
        ) revert AVACoreTypes.EmptyValue();
        SourceSetRecord memory sourceSet = getSourceSet(input.sourceSetId);
        CompletenessRecord memory completeness = completenessRecords[input.completenessAttestationId];
        if (
            completeness.id == 0 || !completeness.active || completeness.sourceSetId != sourceSet.id
                || completeness.packageId != sourceSet.packageId || completeness.revision != sourceSet.revision
                || !_isSourceSetCurrent(sourceSet)
        ) revert AVACoreTypes.InvalidState(input.completenessAttestationId);
        uint256 activeId = activeStatementIdBySourceSet[sourceSet.id];
        if (activeId != replacedStatementId) revert AVACoreTypes.InvalidState(activeId);
        _validateExtension(
            ExtensionValidationInput({
                recognisedStateId: sourceSet.recognisedStateId,
                roleKey: input.roleKey,
                authorityId: input.authorityId,
                subjectId: sourceSet.subjectId,
                evidenceId: input.evidenceId,
                capabilityKey: AVACapabilityKeys.STANDING_PROVENANCE,
                actionKey: actionKey,
                recordTypeKey: STATEMENT_TYPE,
                scopeKey: sourceSet.vectorKey,
                sourceTypeKey: SOURCE_SET_TYPE,
                sourceRecordId: sourceSet.id,
                unsignedValue: sourceSet.epoch,
                validUntil: 0,
                payloadHash: keccak256(
                    abi.encode(input.threshold, input.lowerBound, input.upperBound, input.outputCommitment)
                ),
                requireActiveSubject: true,
                contextHash: keccak256(
                    abi.encode(
                        sourceSet.id, input.completenessAttestationId, input.outputCommitment, replacedStatementId
                    )
                )
            })
        );
        FormulaRecord memory formula = getFormula(sourceSet.formulaId);
        id = nextStatementId++;
        StatementRecord storage record = statements[id];
        record.id = id;
        record.formulaId = formula.id;
        record.sourceSetId = sourceSet.id;
        record.completenessAttestationId = completeness.id;
        record.recognisedStateId = sourceSet.recognisedStateId;
        record.appId = sourceSet.appId;
        record.workflowKey = sourceSet.workflowKey;
        record.packageId = sourceSet.packageId;
        record.revision = sourceSet.revision;
        record.subjectId = sourceSet.subjectId;
        record.subjectCommitment = sourceSet.subjectCommitment;
        record.vectorKey = sourceSet.vectorKey;
        record.categoryHash = sourceSet.categoryHash;
        record.threshold = input.threshold;
        record.lowerBound = input.lowerBound;
        record.upperBound = input.upperBound;
        record.epoch = sourceSet.epoch;
        record.sourceRecordSetRoot = sourceSet.sourceRecordSetRoot;
        record.computationRuleHash = formula.computationRuleHash;
        record.sourceSetPolicyHash = formula.sourceSetPolicyHash;
        record.outputCommitment = input.outputCommitment;
        record.verifier = formula.verifier;
        record.proofDomainHash = formula.proofDomainHash;
        record.evidenceId = input.evidenceId;
        record.authorityId = input.authorityId;
        record.status = StatementStatus.Active;
        record.invalidatedByEvidenceId = 0;
        record.uri = input.uri;
        record.registeredBy = msg.sender;
        record.registeredAt = uint64(block.timestamp);
        activeStatementIdBySourceSet[sourceSet.id] = id;
        emit StandingComputationStatementRecorded(id, sourceSet.id, sourceSet.subjectCommitment, sourceSet.revision);
    }

    function _validatePackagePolicy(FormulaInput calldata input, bytes32 payloadHash, IAVAExtensionPolicyModule policy)
        private
        view
    {
        policy.validateExtensionRecord(
            IAVAExtensionPolicyModule.ExtensionPolicyContext({
                appId: input.appId,
                workflowKey: input.workflowKey,
                packageId: input.packageId,
                capabilityKey: AVACapabilityKeys.STANDING_PROVENANCE,
                actionKey: AVACoreTypes.ACTION_REGISTER_STANDING_FORMULA,
                recordTypeKey: FORMULA_TYPE,
                scopeKey: input.vectorKey,
                sourceTypeKey: bytes32(0),
                recognisedStateId: 0,
                recognisedStateTransitionId: 0,
                subjectId: input.authorityId,
                evidenceId: 0,
                disclosurePolicyId: 0,
                sourceRecordId: 0,
                unsignedValue: input.formulaVersion,
                validUntil: 0,
                payloadHash: payloadHash,
                contextHash: keccak256(abi.encode(input.packageId, input.vectorKey, input.formulaVersion, payloadHash)),
                authorityId: input.authorityId,
                actor: msg.sender
            })
        );
    }

    function _validateFormulaAntiAbuse(FormulaInput calldata input, IAVAAntiAbusePolicyModule antiAbuse) private view {
        if (address(antiAbuse) == address(0)) return;
        antiAbuse.validateAntiAbuse(
            IAVAAntiAbusePolicyModule.AntiAbuseContext({
                appId: input.appId,
                workflowKey: input.workflowKey,
                packageId: input.packageId,
                actionKey: AVACoreTypes.ACTION_REGISTER_STANDING_FORMULA,
                roleKey: input.roleKey,
                targetId: input.packageId,
                targetTypeKey: input.vectorKey,
                actorSubjectId: input.authorityId,
                targetSubjectId: input.authorityId,
                authorityId: input.authorityId,
                actor: msg.sender
            })
        );
    }

    function _verifiedFormulaModules(uint256 packageId) private view returns (FormulaModules memory modules) {
        bytes32[] memory keys = new bytes32[](2);
        keys[0] = AVACapabilityKeys.STANDING_PROVENANCE;
        keys[1] = AVACapabilityKeys.ANTI_ABUSE;
        (AVACoreRulePackageRegistry.VerifiedPackageContext memory rulePackage, address[] memory addresses) =
            RULE_PACKAGE_REGISTRY.getVerifiedModulesCompact(packageId, keys);
        if (addresses[0] == address(0)) revert AVACoreTypes.UnknownReference(packageId);
        modules = FormulaModules({
            rulePackage: rulePackage,
            standingProvenance: IAVAExtensionPolicyModule(addresses[0]),
            antiAbuse: IAVAAntiAbusePolicyModule(addresses[1])
        });
    }

    function _requireFormulaInput(FormulaInput calldata input) private view {
        if (
            input.appId == bytes32(0) || input.workflowKey == bytes32(0) || input.packageId == 0
                || input.roleKey == bytes32(0) || input.authorityId == bytes32(0) || input.vectorKey == bytes32(0)
                || input.formulaVersion == 0 || input.computationRuleHash == bytes32(0)
                || input.sourceSetPolicyHash == bytes32(0) || input.decayPolicyHash == bytes32(0)
                || input.capPolicyHash == bytes32(0) || input.restorationPolicyHash == bytes32(0)
                || input.verifier == address(0) || input.verifier.code.length == 0
                || input.proofDomainHash == bytes32(0)
        ) revert AVACoreTypes.EmptyValue();
    }

    function _isSourceSetCurrent(SourceSetRecord memory sourceSet) private view returns (bool) {
        if (sourceSet.id == 0) return false;
        try GOVERNANCE_KERNEL.getRecognisedState(sourceSet.recognisedStateId) returns (
            AVACoreTypes.RecognisedStateRecord memory state
        ) {
            if (
                state.packageId != sourceSet.packageId || state.subjectId != sourceSet.subjectId
                    || !_isStandingStatus(state.status)
                    || REVISION_REGISTRY.currentRevision(state.packageId, state.subjectId) != sourceSet.revision
            ) return false;
            RULE_PACKAGE_REGISTRY.getVerifiedPackageContext(state.packageId);
            IDENTITY_REGISTRY.requireActiveSubjectReference(state.subjectId, state.appId);
            return _isSourceEvidenceCurrent(sourceSet);
        } catch {
            return false;
        }
    }

    function _isSourceEvidenceCurrent(SourceSetRecord memory sourceSet) private view returns (bool) {
        try EVIDENCE_REGISTRY.requireUsableEvidenceReferenceForPackage(
            sourceSet.evidenceId, sourceSet.packageId
        ) returns (
            bytes32 appId, bytes32 workflowKey, uint256, bytes32 subjectId, uint256
        ) {
            return appId == sourceSet.appId && workflowKey == sourceSet.workflowKey && subjectId == sourceSet.subjectId;
        } catch {
            return false;
        }
    }

    function _isEvidenceCurrent(uint256 evidenceId, StatementRecord memory statement) private view returns (bool) {
        try EVIDENCE_REGISTRY.requireUsableEvidenceReferenceForPackage(evidenceId, statement.packageId) returns (
            bytes32 appId, bytes32 workflowKey, uint256, bytes32 subjectId, uint256
        ) {
            return appId == statement.appId && workflowKey == statement.workflowKey && subjectId == statement.subjectId;
        } catch {
            return false;
        }
    }

    function _statementStorage(uint256 id) private view returns (StatementRecord storage statement) {
        statement = statements[id];
        if (statement.id == 0) revert AVACoreTypes.UnknownReference(id);
    }

    function _isStandingStatus(AVACoreTypes.RecognisedStateStatus status) private pure returns (bool) {
        return status == AVACoreTypes.RecognisedStateStatus.Vested
            || status == AVACoreTypes.RecognisedStateStatus.Restored
            || status == AVACoreTypes.RecognisedStateStatus.Downgraded
            || status == AVACoreTypes.RecognisedStateStatus.Voided;
    }
}

contract AVAStandingZKProofExtension {
    bytes32 public constant PROOF_CONTEXT_DOMAIN = keccak256("ava.standing.zk-proof.context.v1");
    bytes32 public constant PROOF_NULLIFIER_DOMAIN = keccak256("ava.standing.zk-proof.nullifier.v1");

    struct ProofInput {
        uint256 statementId;
        bytes32 roleKey;
        bytes32 authorityId;
        IZKProofVerifier.SchnorrProof proof;
        string uri;
    }

    struct ProofReceipt {
        uint256 id;
        uint256 statementId;
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        uint256 revision;
        bytes32 subjectId;
        bytes32 subjectCommitment;
        bytes32 vectorKey;
        bytes32 categoryHash;
        int256 threshold;
        int256 lowerBound;
        int256 upperBound;
        uint256 epoch;
        bytes32 sourceRecordSetRoot;
        bytes32 computationRuleHash;
        bytes32 outputCommitment;
        uint256 evidenceId;
        bytes32 proofDomainHash;
        bytes32 contextHash;
        bytes32 nullifierHash;
        bytes32 proofHash;
        bytes32 authorityId;
        string uri;
        address registeredBy;
        uint64 registeredAt;
    }

    struct ProofModules {
        AVACoreRulePackageRegistry.VerifiedPackageContext rulePackage;
        IAVAApplicationModule application;
        IAVAExtensionPolicyModule proofPolicy;
        IAVAAntiAbusePolicyModule antiAbuse;
    }

    bytes32 private constant PROOF_TYPE = keccak256("ava.standing.zk-proof-receipt.v1");

    AVAAuthorityMatrix public immutable AUTHORITY_MATRIX;
    AVAIdentityRegistry public immutable IDENTITY_REGISTRY;
    AVACoreRulePackageRegistry public immutable RULE_PACKAGE_REGISTRY;
    AVAEvidenceRegistry public immutable EVIDENCE_REGISTRY;
    IAVAStandingRevision public immutable REVISION_REGISTRY;
    AVAStandingProvenanceExtension public immutable PROVENANCE_REGISTRY;
    IZKProofVerifier public immutable VERIFIER;
    bytes32 public immutable PROOF_DOMAIN_HASH;
    bytes32 public immutable VERIFIER_CODE_HASH;

    mapping(uint256 => ProofReceipt) private proofReceipts;
    mapping(bytes32 => uint256) public receiptIdByContextHash;
    mapping(bytes32 => uint256) public receiptIdByNullifierHash;
    uint256 public nextProofReceiptId = 1;

    event StandingZKProofRecorded(
        uint256 indexed id, uint256 indexed statementId, bytes32 indexed subjectCommitment, bytes32 nullifierHash
    );

    constructor(
        AVAAuthorityMatrix authorityMatrix_,
        AVAIdentityRegistry identityRegistry_,
        AVACoreRulePackageRegistry rulePackageRegistry_,
        AVAEvidenceRegistry evidenceRegistry_,
        IAVAStandingRevision revisionRegistry_,
        AVAStandingProvenanceExtension provenanceRegistry_,
        IZKProofVerifier verifier_
    ) {
        if (
            address(authorityMatrix_) == address(0) || address(identityRegistry_) == address(0)
                || address(rulePackageRegistry_) == address(0) || address(evidenceRegistry_) == address(0)
                || address(revisionRegistry_) == address(0) || address(provenanceRegistry_) == address(0)
                || address(verifier_) == address(0) || address(verifier_).code.length == 0
        ) revert AVACoreTypes.EmptyValue();
        if (
            address(provenanceRegistry_.AUTHORITY_MATRIX()) != address(authorityMatrix_)
                || address(provenanceRegistry_.IDENTITY_REGISTRY()) != address(identityRegistry_)
                || address(provenanceRegistry_.RULE_PACKAGE_REGISTRY()) != address(rulePackageRegistry_)
                || address(provenanceRegistry_.EVIDENCE_REGISTRY()) != address(evidenceRegistry_)
                || address(provenanceRegistry_.REVISION_REGISTRY()) != address(revisionRegistry_)
        ) revert AVACoreTypes.InvalidState(0);
        bytes32 proofDomainHash = verifier_.proofDomain();
        if (proofDomainHash == bytes32(0)) revert AVACoreTypes.EmptyValue();
        AUTHORITY_MATRIX = authorityMatrix_;
        IDENTITY_REGISTRY = identityRegistry_;
        RULE_PACKAGE_REGISTRY = rulePackageRegistry_;
        EVIDENCE_REGISTRY = evidenceRegistry_;
        REVISION_REGISTRY = revisionRegistry_;
        PROVENANCE_REGISTRY = provenanceRegistry_;
        VERIFIER = verifier_;
        PROOF_DOMAIN_HASH = proofDomainHash;
        VERIFIER_CODE_HASH = address(verifier_).codehash;
    }

    function registerProof(ProofInput calldata input) external returns (uint256 id) {
        _requireStableVerifier();
        if (input.statementId == 0 || input.roleKey == bytes32(0) || input.authorityId == bytes32(0)) {
            revert AVACoreTypes.EmptyValue();
        }
        AVAStandingProvenanceExtension.StatementRecord memory statement =
            PROVENANCE_REGISTRY.getComputationStatement(input.statementId);
        if (!PROVENANCE_REGISTRY.isComputationStatementActive(statement.id)) {
            revert AVACoreTypes.InvalidState(statement.id);
        }
        ProofModules memory modules = _verifiedProofModules(statement.packageId);
        if (modules.rulePackage.appId != statement.appId || modules.rulePackage.workflowKey != statement.workflowKey) {
            revert AVACoreTypes.InvalidState(statement.packageId);
        }
        AUTHORITY_MATRIX.requireAuthorisedSubject(
            msg.sender, statement.appId, input.roleKey, AVACoreTypes.ACTION_RECORD_STANDING_ZK_PROOF, input.authorityId
        );
        _validateApplicationAndAntiAbuse(statement, input.roleKey, input.authorityId, modules);
        if (
            statement.verifier != address(VERIFIER) || statement.proofDomainHash != PROOF_DOMAIN_HASH
                || statement.subjectCommitment != _subjectCommitment(input.proof.publicKey)
        ) revert AVACoreTypes.InvalidState(statement.id);
        bytes32 contextHash = _proofContext(statement);
        bytes32 nullifierHash = keccak256(abi.encode(PROOF_NULLIFIER_DOMAIN, contextHash, statement.subjectCommitment));
        if (receiptIdByContextHash[contextHash] != 0 || receiptIdByNullifierHash[nullifierHash] != 0) {
            revert AVACoreTypes.InvalidState(uint256(contextHash));
        }
        _validatePolicy(statement, input, contextHash, modules.proofPolicy);
        if (!VERIFIER.verify(contextHash, input.proof)) revert AVACoreTypes.InvalidState(uint256(contextHash));
        id = nextProofReceiptId++;
        _storeProofReceipt(id, statement, input, contextHash, nullifierHash);
        receiptIdByContextHash[contextHash] = id;
        receiptIdByNullifierHash[nullifierHash] = id;
        emit StandingZKProofRecorded(id, statement.id, statement.subjectCommitment, nullifierHash);
    }

    function proofSupports(
        uint256 receiptId,
        uint256 packageId,
        bytes32 subjectCommitment,
        bytes32 vectorKey,
        bytes32 categoryHash,
        int256 requiredThreshold
    ) public view returns (bool) {
        ProofReceipt memory receipt = proofReceipts[receiptId];
        return receipt.id != 0 && receipt.packageId == packageId && receipt.subjectCommitment == subjectCommitment
            && receipt.vectorKey == vectorKey && receipt.categoryHash == categoryHash
            && receipt.threshold >= requiredThreshold && requiredThreshold >= receipt.lowerBound
            && requiredThreshold <= receipt.upperBound && isProofUsable(receiptId);
    }

    function isProofUsable(uint256 receiptId) public view returns (bool) {
        ProofReceipt memory receipt = proofReceipts[receiptId];
        if (
            receipt.id == 0 || !_verifierStable()
                || !PROVENANCE_REGISTRY.isComputationStatementActive(receipt.statementId)
        ) return false;
        AVAStandingProvenanceExtension.StatementRecord memory statement =
            PROVENANCE_REGISTRY.getComputationStatement(receipt.statementId);
        if (!_receiptMatchesStatement(receipt, statement)) return false;
        try RULE_PACKAGE_REGISTRY.getVerifiedPackageContext(receipt.packageId) returns (
            AVACoreRulePackageRegistry.VerifiedPackageContext memory package
        ) {
            if (package.appId != receipt.appId || package.workflowKey != receipt.workflowKey) return false;
        } catch {
            return false;
        }
        try IDENTITY_REGISTRY.requireActiveSubjectReference(receipt.subjectId, receipt.appId) {}
        catch {
            return false;
        }
        return _isEvidenceCurrent(receipt);
    }

    function getProofReceipt(uint256 id) external view returns (ProofReceipt memory receipt) {
        receipt = proofReceipts[id];
        if (receipt.id == 0) revert AVACoreTypes.UnknownReference(id);
    }

    function _storeProofReceipt(
        uint256 id,
        AVAStandingProvenanceExtension.StatementRecord memory statement,
        ProofInput calldata input,
        bytes32 contextHash,
        bytes32 nullifierHash
    ) private {
        ProofReceipt storage receipt = proofReceipts[id];
        receipt.id = id;
        receipt.statementId = statement.id;
        receipt.appId = statement.appId;
        receipt.workflowKey = statement.workflowKey;
        receipt.packageId = statement.packageId;
        receipt.revision = statement.revision;
        receipt.subjectId = statement.subjectId;
        receipt.subjectCommitment = statement.subjectCommitment;
        receipt.vectorKey = statement.vectorKey;
        receipt.categoryHash = statement.categoryHash;
        receipt.threshold = statement.threshold;
        receipt.lowerBound = statement.lowerBound;
        receipt.upperBound = statement.upperBound;
        receipt.epoch = statement.epoch;
        receipt.sourceRecordSetRoot = statement.sourceRecordSetRoot;
        receipt.computationRuleHash = statement.computationRuleHash;
        receipt.outputCommitment = statement.outputCommitment;
        receipt.evidenceId = statement.evidenceId;
        receipt.proofDomainHash = statement.proofDomainHash;
        receipt.contextHash = contextHash;
        receipt.nullifierHash = nullifierHash;
        receipt.proofHash = keccak256(abi.encode(input.proof));
        receipt.authorityId = input.authorityId;
        receipt.uri = input.uri;
        receipt.registeredBy = msg.sender;
        receipt.registeredAt = uint64(block.timestamp);
    }

    function _validatePolicy(
        AVAStandingProvenanceExtension.StatementRecord memory statement,
        ProofInput calldata input,
        bytes32 contextHash,
        IAVAExtensionPolicyModule proofPolicy
    ) private view {
        proofPolicy.validateExtensionRecord(
            IAVAExtensionPolicyModule.ExtensionPolicyContext({
                appId: statement.appId,
                workflowKey: statement.workflowKey,
                packageId: statement.packageId,
                capabilityKey: AVACapabilityKeys.STANDING_ZK_PROOF,
                actionKey: AVACoreTypes.ACTION_RECORD_STANDING_ZK_PROOF,
                recordTypeKey: PROOF_TYPE,
                scopeKey: statement.vectorKey,
                sourceTypeKey: keccak256("ava.standing.computation-statement.v1"),
                recognisedStateId: statement.recognisedStateId,
                recognisedStateTransitionId: 0,
                subjectId: statement.subjectId,
                evidenceId: statement.evidenceId,
                disclosurePolicyId: 0,
                sourceRecordId: statement.id,
                unsignedValue: statement.epoch,
                validUntil: 0,
                payloadHash: statement.outputCommitment,
                contextHash: contextHash,
                authorityId: input.authorityId,
                actor: msg.sender
            })
        );
    }

    function _validateApplicationAndAntiAbuse(
        AVAStandingProvenanceExtension.StatementRecord memory statement,
        bytes32 roleKey,
        bytes32 authorityId,
        ProofModules memory modules
    ) private view {
        AVAGovernanceKernel kernel = PROVENANCE_REGISTRY.GOVERNANCE_KERNEL();
        AVACoreTypes.RecognisedStateRecord memory state = kernel.getRecognisedState(statement.recognisedStateId);
        AVAGovernanceKernel.GovernedObjectReference memory objectRecord =
            kernel.getGovernedObjectReference(state.governedObjectId);
        if (
            state.appId != statement.appId || state.workflowKey != statement.workflowKey
                || state.packageId != statement.packageId || state.subjectId != statement.subjectId
        ) revert AVACoreTypes.InvalidState(statement.recognisedStateId);
        modules.application
            .validateDownstreamRecord(
                IAVAApplicationModule.DownstreamRecordContext({
                    appId: statement.appId,
                    workflowKey: statement.workflowKey,
                    packageId: statement.packageId,
                    actionKey: AVACoreTypes.ACTION_RECORD_STANDING_ZK_PROOF,
                    roleKey: roleKey,
                    recognisedStateId: state.id,
                    governedObjectId: state.governedObjectId,
                    objectTypeKey: objectRecord.objectTypeKey,
                    subjectId: statement.subjectId,
                    evidenceReceiptId: statement.evidenceId,
                    recordTypeKey: PROOF_TYPE,
                    authorityId: authorityId,
                    actor: msg.sender
                })
            );
        if (address(modules.antiAbuse) == address(0)) return;
        modules.antiAbuse
            .validateAntiAbuse(
                IAVAAntiAbusePolicyModule.AntiAbuseContext({
                    appId: statement.appId,
                    workflowKey: statement.workflowKey,
                    packageId: statement.packageId,
                    actionKey: AVACoreTypes.ACTION_RECORD_STANDING_ZK_PROOF,
                    roleKey: roleKey,
                    targetId: state.id,
                    targetTypeKey: PROOF_TYPE,
                    actorSubjectId: authorityId,
                    targetSubjectId: statement.subjectId,
                    authorityId: authorityId,
                    actor: msg.sender
                })
            );
    }

    function _verifiedProofModules(uint256 packageId) private view returns (ProofModules memory modules) {
        bytes32[] memory keys = new bytes32[](3);
        keys[0] = AVACapabilityKeys.APPLICATION;
        keys[1] = AVACapabilityKeys.STANDING_ZK_PROOF;
        keys[2] = AVACapabilityKeys.ANTI_ABUSE;
        (AVACoreRulePackageRegistry.VerifiedPackageContext memory rulePackage, address[] memory addresses) =
            RULE_PACKAGE_REGISTRY.getVerifiedModulesCompact(packageId, keys);
        if (addresses[1] == address(0)) revert AVACoreTypes.UnknownReference(packageId);
        modules = ProofModules({
            rulePackage: rulePackage,
            application: IAVAApplicationModule(addresses[0]),
            proofPolicy: IAVAExtensionPolicyModule(addresses[1]),
            antiAbuse: IAVAAntiAbusePolicyModule(addresses[2])
        });
    }

    function _proofContext(AVAStandingProvenanceExtension.StatementRecord memory statement)
        private
        view
        returns (bytes32)
    {
        bytes32 boundsHash = keccak256(
            abi.encode(
                statement.vectorKey,
                statement.categoryHash,
                statement.threshold,
                statement.lowerBound,
                statement.upperBound,
                statement.epoch
            )
        );
        bytes32 provenanceHash = keccak256(
            abi.encode(statement.sourceRecordSetRoot, statement.computationRuleHash, statement.outputCommitment)
        );
        return keccak256(
            abi.encode(
                PROOF_CONTEXT_DOMAIN,
                keccak256(abi.encode(block.chainid, address(this), address(VERIFIER))),
                statement.proofDomainHash,
                statement.packageId,
                statement.revision,
                statement.id,
                statement.subjectCommitment,
                boundsHash,
                provenanceHash
            )
        );
    }

    function _receiptMatchesStatement(
        ProofReceipt memory receipt,
        AVAStandingProvenanceExtension.StatementRecord memory statement
    ) private view returns (bool) {
        if (
            receipt.statementId != statement.id || receipt.packageId != statement.packageId
                || receipt.revision != statement.revision
                || receipt.revision != REVISION_REGISTRY.currentRevision(receipt.packageId, receipt.subjectId)
                || receipt.subjectId != statement.subjectId || receipt.subjectCommitment != statement.subjectCommitment
        ) return false;
        if (
            receipt.vectorKey != statement.vectorKey || receipt.categoryHash != statement.categoryHash
                || receipt.threshold != statement.threshold || receipt.lowerBound != statement.lowerBound
                || receipt.upperBound != statement.upperBound || receipt.epoch != statement.epoch
        ) return false;
        return receipt.sourceRecordSetRoot == statement.sourceRecordSetRoot
            && receipt.computationRuleHash == statement.computationRuleHash
            && receipt.outputCommitment == statement.outputCommitment && receipt.evidenceId == statement.evidenceId
            && receipt.proofDomainHash == statement.proofDomainHash && statement.verifier == address(VERIFIER);
    }

    function _isEvidenceCurrent(ProofReceipt memory receipt) private view returns (bool) {
        try EVIDENCE_REGISTRY.requireUsableEvidenceReferenceForPackage(receipt.evidenceId, receipt.packageId) returns (
            bytes32 appId, bytes32 workflowKey, uint256, bytes32 subjectId, uint256
        ) {
            return appId == receipt.appId && workflowKey == receipt.workflowKey && subjectId == receipt.subjectId;
        } catch {
            return false;
        }
    }

    function _requireStableVerifier() private view {
        if (!_verifierStable()) revert AVACoreTypes.InvalidState(uint256(PROOF_DOMAIN_HASH));
    }

    function _verifierStable() private view returns (bool) {
        if (address(VERIFIER).codehash != VERIFIER_CODE_HASH) return false;
        try VERIFIER.proofDomain() returns (bytes32 proofDomainHash) {
            return proofDomainHash == PROOF_DOMAIN_HASH;
        } catch {
            return false;
        }
    }

    function _subjectCommitment(IZKProofVerifier.G1Point calldata publicKey) private pure returns (bytes32) {
        return keccak256(abi.encode(publicKey.x, publicKey.y));
    }
}

/// @notice Role-subject-linkable ZK standing proof carriers over authorised computation receipts.
/// @dev Records bind both subjectId and subjectCommitment; they reduce history disclosure but do not claim unlinkability.
contract AVAStandingZKCredentialExtension {
    uint256 public constant MAX_CREDENTIAL_VALIDITY = 365 days;
    bytes32 public constant USE_CONTEXT_DOMAIN = keccak256("ava.standing.zk-credential.use-context.v1");
    bytes32 public constant USE_NULLIFIER_DOMAIN = keccak256("ava.standing.zk-credential.use-nullifier.v1");
    bytes32 public constant CREDENTIAL_TYPE = keccak256("ava.standing.zk-credential.v1");
    bytes32 public constant CREDENTIAL_USE_TYPE = keccak256("ava.standing.zk-credential-use.v1");

    struct CredentialInput {
        uint256 proofReceiptId;
        bytes32 roleKey;
        bytes32 authorityId;
        bytes32 credentialCommitment;
        uint64 expiresAt;
        string uri;
    }

    struct CredentialRecord {
        uint256 id;
        uint256 proofReceiptId;
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        uint256 revision;
        bytes32 subjectId;
        bytes32 subjectCommitment;
        bytes32 vectorKey;
        bytes32 categoryHash;
        int256 threshold;
        int256 lowerBound;
        int256 upperBound;
        uint256 epoch;
        uint256 evidenceId;
        bytes32 credentialCommitment;
        bytes32 authorityId;
        uint64 issuedAt;
        uint64 expiresAt;
        string uri;
        address issuedBy;
        uint256 supersededBy;
        bool revoked;
    }

    struct CredentialUseInput {
        uint256 credentialId;
        uint256 packageId;
        address beneficiary;
        bytes32 subjectCommitment;
        bytes32 vectorKey;
        bytes32 categoryHash;
        int256 minimumThreshold;
        bytes32 targetContextHash;
        bytes32 actionKey;
        string uri;
    }

    struct CredentialUseRecord {
        uint256 id;
        uint256 credentialId;
        uint256 packageId;
        bytes32 subjectCommitment;
        bytes32 targetContextHash;
        bytes32 actionKey;
        bytes32 contextHash;
        bytes32 nullifierHash;
        bytes32 proofHash;
        string uri;
        address usedBy;
        uint64 usedAt;
    }

    struct CredentialPolicyModules {
        AVACoreRulePackageRegistry.VerifiedPackageContext rulePackage;
        IAVAApplicationModule application;
        IAVAExtensionPolicyModule credentialPolicy;
        IAVAAntiAbusePolicyModule antiAbuse;
    }

    AVAAuthorityMatrix public immutable AUTHORITY_MATRIX;
    AVAIdentityRegistry public immutable IDENTITY_REGISTRY;
    AVACoreRulePackageRegistry public immutable RULE_PACKAGE_REGISTRY;
    AVAEvidenceRegistry public immutable EVIDENCE_REGISTRY;
    IAVAStandingRevision public immutable REVISION_REGISTRY;
    AVAStandingProvenanceExtension public immutable PROVENANCE_REGISTRY;
    AVAStandingZKProofExtension public immutable PROOF_REGISTRY;
    IZKProofVerifier public immutable VERIFIER;

    mapping(uint256 => CredentialRecord) private credentials;
    mapping(uint256 => CredentialUseRecord) private useRecords;
    mapping(bytes32 => uint256) public credentialIdByCommitment;
    mapping(bytes32 => uint256) public activeCredentialId;
    mapping(bytes32 => uint256) public useRecordIdByNullifier;
    uint256 public nextCredentialId = 1;
    uint256 public nextUseRecordId = 1;

    event StandingZKCredentialIssued(
        uint256 indexed id, uint256 indexed proofReceiptId, bytes32 indexed subjectCommitment, uint64 expiresAt
    );
    event StandingZKCredentialRevoked(uint256 indexed id, bytes32 indexed authorityId);
    event StandingZKCredentialSuperseded(uint256 indexed id, uint256 indexed replacementId);
    event StandingZKCredentialUsed(
        uint256 indexed id, uint256 indexed credentialId, bytes32 indexed nullifierHash, bytes32 targetContextHash
    );

    constructor(
        AVAAuthorityMatrix authorityMatrix_,
        AVAIdentityRegistry identityRegistry_,
        AVACoreRulePackageRegistry rulePackageRegistry_,
        AVAEvidenceRegistry evidenceRegistry_,
        IAVAStandingRevision revisionRegistry_,
        AVAStandingProvenanceExtension provenanceRegistry_,
        AVAStandingZKProofExtension proofRegistry_,
        IZKProofVerifier verifier_
    ) {
        if (
            address(authorityMatrix_) == address(0) || address(identityRegistry_) == address(0)
                || address(rulePackageRegistry_) == address(0) || address(evidenceRegistry_) == address(0)
                || address(revisionRegistry_) == address(0) || address(provenanceRegistry_) == address(0)
                || address(proofRegistry_) == address(0) || address(verifier_) == address(0)
        ) revert AVACoreTypes.EmptyValue();
        if (
            address(proofRegistry_.AUTHORITY_MATRIX()) != address(authorityMatrix_)
                || address(proofRegistry_.IDENTITY_REGISTRY()) != address(identityRegistry_)
                || address(proofRegistry_.RULE_PACKAGE_REGISTRY()) != address(rulePackageRegistry_)
                || address(proofRegistry_.EVIDENCE_REGISTRY()) != address(evidenceRegistry_)
                || address(proofRegistry_.REVISION_REGISTRY()) != address(revisionRegistry_)
                || address(proofRegistry_.PROVENANCE_REGISTRY()) != address(provenanceRegistry_)
                || address(proofRegistry_.VERIFIER()) != address(verifier_)
        ) revert AVACoreTypes.InvalidState(0);
        AUTHORITY_MATRIX = authorityMatrix_;
        IDENTITY_REGISTRY = identityRegistry_;
        RULE_PACKAGE_REGISTRY = rulePackageRegistry_;
        EVIDENCE_REGISTRY = evidenceRegistry_;
        REVISION_REGISTRY = revisionRegistry_;
        PROVENANCE_REGISTRY = provenanceRegistry_;
        PROOF_REGISTRY = proofRegistry_;
        VERIFIER = verifier_;
    }

    function issueCredential(CredentialInput calldata input) external returns (uint256 id) {
        id = _issue(input, 0, AVACoreTypes.ACTION_ISSUE_STANDING_ZK_CREDENTIAL);
    }

    function supersedeCredential(uint256 credentialId, CredentialInput calldata input)
        external
        returns (uint256 replacementId)
    {
        CredentialRecord storage previous = _credentialStorage(credentialId);
        if (
            previous.revoked || previous.supersededBy != 0
                || activeCredentialId[_credentialKey(previous)] != previous.id
        ) revert AVACoreTypes.InvalidState(credentialId);
        replacementId = _issue(input, credentialId, AVACoreTypes.ACTION_SUPERSEDE_STANDING_ZK_CREDENTIAL);
        CredentialRecord memory replacement = credentials[replacementId];
        if (
            replacement.packageId != previous.packageId || replacement.subjectId != previous.subjectId
                || replacement.subjectCommitment != previous.subjectCommitment
                || replacement.vectorKey != previous.vectorKey || replacement.categoryHash != previous.categoryHash
                || replacement.epoch <= previous.epoch
        ) revert AVACoreTypes.InvalidState(credentialId);
        previous.supersededBy = replacementId;
        emit StandingZKCredentialSuperseded(credentialId, replacementId);
    }

    function revokeCredential(uint256 credentialId, bytes32 roleKey, bytes32 authorityId) external {
        CredentialRecord storage credential = _credentialStorage(credentialId);
        if (!_isActive(credential)) revert AVACoreTypes.InvalidState(credentialId);
        AUTHORITY_MATRIX.requireAuthorisedSubject(
            msg.sender, credential.appId, roleKey, AVACoreTypes.ACTION_REVOKE_STANDING_ZK_CREDENTIAL, authorityId
        );
        _validatePolicy(
            credential,
            AVACoreTypes.ACTION_REVOKE_STANDING_ZK_CREDENTIAL,
            roleKey,
            authorityId,
            credential.expiresAt,
            bytes32(credentialId)
        );
        credential.revoked = true;
        delete activeCredentialId[_credentialKey(credential)];
        emit StandingZKCredentialRevoked(credentialId, authorityId);
    }

    function credentialProves(
        uint256 credentialId,
        uint256 packageId,
        bytes32 subjectCommitment,
        bytes32 vectorKey,
        bytes32 categoryHash,
        int256 minimumThreshold
    ) public view returns (bool) {
        CredentialRecord storage credential = credentials[credentialId];
        return credential.id != 0 && credential.packageId == packageId
            && credential.subjectCommitment == subjectCommitment && credential.vectorKey == vectorKey
            && credential.categoryHash == categoryHash && credential.threshold >= minimumThreshold
            && minimumThreshold >= credential.lowerBound && minimumThreshold <= credential.upperBound
            && _isActive(credential);
    }

    function recordCredentialUse(CredentialUseInput calldata input, IZKProofVerifier.SchnorrProof calldata proof)
        external
        returns (uint256 id)
    {
        if (
            input.credentialId == 0 || input.packageId == 0 || input.subjectCommitment == bytes32(0)
                || input.vectorKey == bytes32(0) || input.categoryHash == bytes32(0)
                || input.targetContextHash == bytes32(0) || input.actionKey == bytes32(0)
                || input.beneficiary == address(0) || input.beneficiary != msg.sender
        ) revert AVACoreTypes.EmptyValue();
        if (
            !credentialProves(
                    input.credentialId,
                    input.packageId,
                    input.subjectCommitment,
                    input.vectorKey,
                    input.categoryHash,
                    input.minimumThreshold
                ) || input.subjectCommitment != keccak256(abi.encode(proof.publicKey.x, proof.publicKey.y))
        ) revert AVACoreTypes.InvalidState(input.credentialId);
        CredentialRecord storage credential = credentials[input.credentialId];
        bytes32 contextHash = keccak256(
            abi.encode(
                USE_CONTEXT_DOMAIN,
                keccak256(abi.encode(block.chainid, address(this), address(VERIFIER))),
                credential.id,
                credential.packageId,
                credential.revision,
                input.beneficiary,
                input.subjectCommitment,
                input.vectorKey,
                input.categoryHash,
                input.minimumThreshold,
                input.targetContextHash,
                input.actionKey
            )
        );
        bytes32 nullifierHash = keccak256(abi.encode(USE_NULLIFIER_DOMAIN, contextHash, credential.subjectCommitment));
        if (useRecordIdByNullifier[nullifierHash] != 0) {
            revert AVACoreTypes.InvalidState(useRecordIdByNullifier[nullifierHash]);
        }
        IAVAExtensionPolicyModule(
                RULE_PACKAGE_REGISTRY.getModule(credential.packageId, AVACapabilityKeys.STANDING_ZK_CREDENTIAL)
            )
            .validateExtensionRecord(
                IAVAExtensionPolicyModule.ExtensionPolicyContext({
                    appId: credential.appId,
                    workflowKey: credential.workflowKey,
                    packageId: credential.packageId,
                    capabilityKey: AVACapabilityKeys.STANDING_ZK_CREDENTIAL,
                    actionKey: AVACoreTypes.ACTION_USE_STANDING_ZK_CREDENTIAL,
                    recordTypeKey: CREDENTIAL_USE_TYPE,
                    scopeKey: input.actionKey,
                    sourceTypeKey: CREDENTIAL_TYPE,
                    recognisedStateId: 0,
                    recognisedStateTransitionId: 0,
                    subjectId: credential.subjectId,
                    evidenceId: credential.evidenceId,
                    disclosurePolicyId: 0,
                    sourceRecordId: credential.id,
                    unsignedValue: credential.epoch,
                    validUntil: credential.expiresAt,
                    payloadHash: keccak256(abi.encode(proof)),
                    contextHash: contextHash,
                    authorityId: credential.subjectCommitment,
                    actor: msg.sender
                })
            );
        if (!VERIFIER.verify(contextHash, proof)) revert AVACoreTypes.InvalidState(input.credentialId);
        id = nextUseRecordId++;
        CredentialUseRecord storage record = useRecords[id];
        record.id = id;
        record.credentialId = credential.id;
        record.packageId = credential.packageId;
        record.subjectCommitment = credential.subjectCommitment;
        record.targetContextHash = input.targetContextHash;
        record.actionKey = input.actionKey;
        record.contextHash = contextHash;
        record.nullifierHash = nullifierHash;
        record.proofHash = keccak256(abi.encode(proof));
        record.uri = input.uri;
        record.usedBy = msg.sender;
        record.usedAt = uint64(block.timestamp);
        useRecordIdByNullifier[nullifierHash] = id;
        emit StandingZKCredentialUsed(id, credential.id, nullifierHash, input.targetContextHash);
    }

    function isCredentialActive(uint256 credentialId) external view returns (bool) {
        CredentialRecord storage credential = credentials[credentialId];
        return credential.id != 0 && _isActive(credential);
    }

    function getCredential(uint256 id) external view returns (CredentialRecord memory credential) {
        credential = credentials[id];
        if (credential.id == 0) revert AVACoreTypes.UnknownReference(id);
    }

    function getCredentialUse(uint256 id) external view returns (CredentialUseRecord memory record) {
        record = useRecords[id];
        if (record.id == 0) revert AVACoreTypes.UnknownReference(id);
    }

    function _issue(CredentialInput calldata input, uint256 replacedId, bytes32 actionKey)
        private
        returns (uint256 id)
    {
        if (
            input.proofReceiptId == 0 || input.roleKey == bytes32(0) || input.authorityId == bytes32(0)
                || input.credentialCommitment == bytes32(0) || input.expiresAt <= block.timestamp
                || input.expiresAt > block.timestamp + MAX_CREDENTIAL_VALIDITY
                || credentialIdByCommitment[input.credentialCommitment] != 0
        ) revert AVACoreTypes.EmptyValue();
        AVAStandingZKProofExtension.ProofReceipt memory proofReceipt =
            PROOF_REGISTRY.getProofReceipt(input.proofReceiptId);
        if (!PROOF_REGISTRY.isProofUsable(proofReceipt.id)) revert AVACoreTypes.InvalidState(proofReceipt.id);
        AUTHORITY_MATRIX.requireAuthorisedSubject(
            msg.sender, proofReceipt.appId, input.roleKey, actionKey, input.authorityId
        );
        bytes32 key = _credentialKey(
            proofReceipt.packageId,
            proofReceipt.subjectId,
            proofReceipt.subjectCommitment,
            proofReceipt.vectorKey,
            proofReceipt.categoryHash
        );
        if (activeCredentialId[key] != replacedId) revert AVACoreTypes.InvalidState(activeCredentialId[key]);
        _validatePolicy(proofReceipt, input, actionKey);
        id = nextCredentialId++;
        CredentialRecord storage credential = credentials[id];
        credential.id = id;
        credential.proofReceiptId = proofReceipt.id;
        credential.appId = proofReceipt.appId;
        credential.workflowKey = proofReceipt.workflowKey;
        credential.packageId = proofReceipt.packageId;
        credential.revision = proofReceipt.revision;
        credential.subjectId = proofReceipt.subjectId;
        credential.subjectCommitment = proofReceipt.subjectCommitment;
        credential.vectorKey = proofReceipt.vectorKey;
        credential.categoryHash = proofReceipt.categoryHash;
        credential.threshold = proofReceipt.threshold;
        credential.lowerBound = proofReceipt.lowerBound;
        credential.upperBound = proofReceipt.upperBound;
        credential.epoch = proofReceipt.epoch;
        credential.evidenceId = proofReceipt.evidenceId;
        credential.credentialCommitment = input.credentialCommitment;
        credential.authorityId = input.authorityId;
        credential.issuedAt = uint64(block.timestamp);
        credential.expiresAt = input.expiresAt;
        credential.uri = input.uri;
        credential.issuedBy = msg.sender;
        credentialIdByCommitment[input.credentialCommitment] = id;
        activeCredentialId[key] = id;
        emit StandingZKCredentialIssued(id, proofReceipt.id, proofReceipt.subjectCommitment, input.expiresAt);
    }

    function _validatePolicy(
        AVAStandingZKProofExtension.ProofReceipt memory proofReceipt,
        CredentialInput calldata input,
        bytes32 actionKey
    ) private view {
        CredentialPolicyModules memory modules = _verifiedCredentialPolicyModules(proofReceipt.packageId);
        _validateApplicationAndAntiAbuse(proofReceipt, input.roleKey, input.authorityId, actionKey, modules);
        modules.credentialPolicy
            .validateExtensionRecord(
                IAVAExtensionPolicyModule.ExtensionPolicyContext({
                    appId: proofReceipt.appId,
                    workflowKey: proofReceipt.workflowKey,
                    packageId: proofReceipt.packageId,
                    capabilityKey: AVACapabilityKeys.STANDING_ZK_CREDENTIAL,
                    actionKey: actionKey,
                    recordTypeKey: CREDENTIAL_TYPE,
                    scopeKey: proofReceipt.vectorKey,
                    sourceTypeKey: keccak256("ava.standing.zk-proof-receipt.v1"),
                    recognisedStateId: 0,
                    recognisedStateTransitionId: 0,
                    subjectId: proofReceipt.subjectId,
                    evidenceId: proofReceipt.evidenceId,
                    disclosurePolicyId: 0,
                    sourceRecordId: proofReceipt.id,
                    unsignedValue: proofReceipt.epoch,
                    validUntil: input.expiresAt,
                    payloadHash: input.credentialCommitment,
                    contextHash: keccak256(abi.encode(proofReceipt.id, input.credentialCommitment, input.expiresAt)),
                    authorityId: input.authorityId,
                    actor: msg.sender
                })
            );
    }

    function _validatePolicy(
        CredentialRecord storage credential,
        bytes32 actionKey,
        bytes32 roleKey,
        bytes32 authorityId,
        uint64 validUntil,
        bytes32 payloadHash
    ) private view {
        AVAStandingZKProofExtension.ProofReceipt memory proofReceipt =
            PROOF_REGISTRY.getProofReceipt(credential.proofReceiptId);
        CredentialPolicyModules memory modules = _verifiedCredentialPolicyModules(credential.packageId);
        _validateApplicationAndAntiAbuse(proofReceipt, roleKey, authorityId, actionKey, modules);
        modules.credentialPolicy
            .validateExtensionRecord(
                IAVAExtensionPolicyModule.ExtensionPolicyContext({
                    appId: credential.appId,
                    workflowKey: credential.workflowKey,
                    packageId: credential.packageId,
                    capabilityKey: AVACapabilityKeys.STANDING_ZK_CREDENTIAL,
                    actionKey: actionKey,
                    recordTypeKey: CREDENTIAL_TYPE,
                    scopeKey: credential.vectorKey,
                    sourceTypeKey: CREDENTIAL_TYPE,
                    recognisedStateId: 0,
                    recognisedStateTransitionId: 0,
                    subjectId: credential.subjectId,
                    evidenceId: credential.evidenceId,
                    disclosurePolicyId: 0,
                    sourceRecordId: credential.id,
                    unsignedValue: credential.epoch,
                    validUntil: validUntil,
                    payloadHash: payloadHash,
                    contextHash: keccak256(abi.encode(credential.id, actionKey, authorityId)),
                    authorityId: authorityId,
                    actor: msg.sender
                })
            );
    }

    function _validateApplicationAndAntiAbuse(
        AVAStandingZKProofExtension.ProofReceipt memory proofReceipt,
        bytes32 roleKey,
        bytes32 authorityId,
        bytes32 actionKey,
        CredentialPolicyModules memory modules
    ) private view {
        AVAStandingProvenanceExtension.StatementRecord memory statement =
            PROVENANCE_REGISTRY.getComputationStatement(proofReceipt.statementId);
        AVAGovernanceKernel kernel = PROVENANCE_REGISTRY.GOVERNANCE_KERNEL();
        AVACoreTypes.RecognisedStateRecord memory state = kernel.getRecognisedState(statement.recognisedStateId);
        AVAGovernanceKernel.GovernedObjectReference memory objectRecord =
            kernel.getGovernedObjectReference(state.governedObjectId);
        if (
            state.appId != proofReceipt.appId || state.workflowKey != proofReceipt.workflowKey
                || state.packageId != proofReceipt.packageId || state.subjectId != proofReceipt.subjectId
                || statement.packageId != proofReceipt.packageId || statement.subjectId != proofReceipt.subjectId
                || modules.rulePackage.appId != proofReceipt.appId
                || modules.rulePackage.workflowKey != proofReceipt.workflowKey
        ) revert AVACoreTypes.InvalidState(proofReceipt.id);
        modules.application
            .validateDownstreamRecord(
                IAVAApplicationModule.DownstreamRecordContext({
                    appId: proofReceipt.appId,
                    workflowKey: proofReceipt.workflowKey,
                    packageId: proofReceipt.packageId,
                    actionKey: actionKey,
                    roleKey: roleKey,
                    recognisedStateId: state.id,
                    governedObjectId: state.governedObjectId,
                    objectTypeKey: objectRecord.objectTypeKey,
                    subjectId: proofReceipt.subjectId,
                    evidenceReceiptId: proofReceipt.evidenceId,
                    recordTypeKey: CREDENTIAL_TYPE,
                    authorityId: authorityId,
                    actor: msg.sender
                })
            );
        if (address(modules.antiAbuse) == address(0)) return;
        modules.antiAbuse
            .validateAntiAbuse(
                IAVAAntiAbusePolicyModule.AntiAbuseContext({
                    appId: proofReceipt.appId,
                    workflowKey: proofReceipt.workflowKey,
                    packageId: proofReceipt.packageId,
                    actionKey: actionKey,
                    roleKey: roleKey,
                    targetId: state.id,
                    targetTypeKey: CREDENTIAL_TYPE,
                    actorSubjectId: authorityId,
                    targetSubjectId: proofReceipt.subjectId,
                    authorityId: authorityId,
                    actor: msg.sender
                })
            );
    }

    function _verifiedCredentialPolicyModules(uint256 packageId)
        private
        view
        returns (CredentialPolicyModules memory modules)
    {
        bytes32[] memory keys = new bytes32[](3);
        keys[0] = AVACapabilityKeys.APPLICATION;
        keys[1] = AVACapabilityKeys.STANDING_ZK_CREDENTIAL;
        keys[2] = AVACapabilityKeys.ANTI_ABUSE;
        (AVACoreRulePackageRegistry.VerifiedPackageContext memory rulePackage, address[] memory addresses) =
            RULE_PACKAGE_REGISTRY.getVerifiedModulesCompact(packageId, keys);
        if (addresses[1] == address(0)) revert AVACoreTypes.UnknownReference(packageId);
        modules = CredentialPolicyModules({
            rulePackage: rulePackage,
            application: IAVAApplicationModule(addresses[0]),
            credentialPolicy: IAVAExtensionPolicyModule(addresses[1]),
            antiAbuse: IAVAAntiAbusePolicyModule(addresses[2])
        });
    }

    function _isActive(CredentialRecord storage credential) private view returns (bool) {
        if (credential.revoked || credential.supersededBy != 0 || credential.expiresAt <= block.timestamp) {
            return false;
        }
        if (activeCredentialId[_credentialKey(credential)] != credential.id) return false;
        if (!PROOF_REGISTRY.isProofUsable(credential.proofReceiptId)) return false;
        if (REVISION_REGISTRY.currentRevision(credential.packageId, credential.subjectId) != credential.revision) {
            return false;
        }
        try IDENTITY_REGISTRY.requireActiveSubjectReference(credential.subjectId, credential.appId) {}
        catch {
            return false;
        }
        return true;
    }

    function _credentialStorage(uint256 id) private view returns (CredentialRecord storage credential) {
        credential = credentials[id];
        if (credential.id == 0) revert AVACoreTypes.UnknownReference(id);
    }

    function _credentialKey(CredentialRecord storage credential) private view returns (bytes32) {
        return _credentialKey(
            credential.packageId,
            credential.subjectId,
            credential.subjectCommitment,
            credential.vectorKey,
            credential.categoryHash
        );
    }

    function _credentialKey(
        uint256 packageId,
        bytes32 subjectId,
        bytes32 subjectCommitment,
        bytes32 vectorKey,
        bytes32 categoryHash
    ) private pure returns (bytes32) {
        return keccak256(abi.encode(packageId, subjectId, subjectCommitment, vectorKey, categoryHash));
    }
}
