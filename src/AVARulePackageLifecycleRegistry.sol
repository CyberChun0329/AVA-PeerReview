// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "./AVADataTypes.sol";
import {AuthorityMatrix} from "./AuthorityMatrix.sol";
import {AVARulePackageRegistry, IRecognisedStateReader, IEvidenceReceiptReader} from "./AVARulePackageRegistry.sol";
import {DisclosurePolicyRegistry} from "./DisclosurePolicyRegistry.sol";
import {IRulePackageLifecycleModule} from "./interfaces/IRulePackageLifecycleModule.sol";

/// @notice Append-only lifecycle, migration-readiness, and disclosure-readiness records for rule packages.
contract AVARulePackageLifecycleRegistry {
    struct ObjectMigrationReadinessInput {
        uint256 lifecycleRecordId;
        bytes32 objectId;
        uint256 recognisedStateId;
        uint256 evidenceReceiptId;
        bytes32 boundaryHash;
        bytes32 authorityId;
        string uri;
    }

    AuthorityMatrix public immutable AUTHORITY_MATRIX;
    AVARulePackageRegistry public immutable RULE_PACKAGE_REGISTRY;
    DisclosurePolicyRegistry public immutable DISCLOSURE_REGISTRY;
    IRecognisedStateReader public immutable STATE_READER;
    IEvidenceReceiptReader public immutable EVIDENCE_READER;

    mapping(uint256 => AVADataTypes.RulePackageLifecycleRecord) private lifecycleRecords;
    mapping(uint256 => AVADataTypes.ObjectMigrationReadinessRecord) private objectMigrationReadinessRecords;
    mapping(uint256 => AVADataTypes.DisclosureLifecycleRecord) private disclosureLifecycleRecords;

    uint256 public nextRulePackageLifecycleRecordId = 1;
    uint256 public nextObjectMigrationReadinessRecordId = 1;
    uint256 public nextDisclosureLifecycleRecordId = 1;

    event RulePackageLifecycleRecorded(
        uint256 indexed id,
        bytes32 indexed workflowKey,
        AVADataTypes.RulePackageLifecycleKind indexed kind,
        bytes32 targetWorkflowKey,
        uint256 targetPackageId
    );
    event RulePackageLifecyclePackageBinding(
        uint256 indexed id,
        uint256 indexed packageId,
        uint256 indexed targetPackageId,
        bytes32 modulesHash,
        bytes32 modulesIdentityHash,
        bytes32 targetModulesHash,
        bytes32 targetModulesIdentityHash
    );
    event ObjectMigrationReadinessRecorded(
        uint256 indexed id,
        uint256 indexed lifecycleRecordId,
        bytes32 indexed objectId,
        uint256 packageId,
        uint256 targetPackageId
    );
    event DisclosureLifecycleRecorded(
        uint256 indexed id,
        bytes32 indexed workflowKey,
        uint256 indexed disclosurePolicyId,
        AVADataTypes.DisclosureLifecycleKind kind
    );

    constructor(
        AuthorityMatrix authorityMatrix_,
        AVARulePackageRegistry rulePackageRegistry_,
        DisclosurePolicyRegistry disclosureRegistry_,
        IRecognisedStateReader stateReader_,
        IEvidenceReceiptReader evidenceReader_
    ) {
        if (
            address(authorityMatrix_) == address(0) || address(rulePackageRegistry_) == address(0)
                || address(disclosureRegistry_) == address(0) || address(stateReader_) == address(0)
                || address(evidenceReader_) == address(0) || address(stateReader_).code.length == 0
                || address(evidenceReader_).code.length == 0
        ) {
            revert AVADataTypes.EmptyValue();
        }
        AUTHORITY_MATRIX = authorityMatrix_;
        RULE_PACKAGE_REGISTRY = rulePackageRegistry_;
        DISCLOSURE_REGISTRY = disclosureRegistry_;
        STATE_READER = stateReader_;
        EVIDENCE_READER = evidenceReader_;
    }

    function recordRulePackageLifecycle(
        AVADataTypes.Role actingRole,
        bytes32 appId,
        bytes32 workflowKey,
        AVADataTypes.RulePackageLifecycleKind kind,
        bytes32 targetWorkflowKey,
        string calldata uri
    ) external returns (uint256 id) {
        bytes32 authorityId = AUTHORITY_MATRIX.requireAuthorisedCanonicalSubject(
            msg.sender, actingRole, AVADataTypes.Action.RegisterRulePackage
        );
        if (appId == bytes32(0) || workflowKey == bytes32(0) || kind == AVADataTypes.RulePackageLifecycleKind.None) {
            revert AVADataTypes.EmptyValue();
        }
        uint256 packageId = RULE_PACKAGE_REGISTRY.getActivePackageId(appId, workflowKey);
        bool targetRequired = _targetRequired(kind);
        uint256 targetPackageId;
        if (targetRequired) {
            if (targetWorkflowKey == bytes32(0)) revert AVADataTypes.EmptyValue();
            targetPackageId = RULE_PACKAGE_REGISTRY.getActivePackageId(appId, targetWorkflowKey);
        } else if (targetWorkflowKey != bytes32(0)) {
            revert AVADataTypes.InvalidState(uint256(targetWorkflowKey));
        }
        id = _recordRulePackageLifecycleForPackage(actingRole, packageId, kind, targetPackageId, uri, authorityId);
    }

    function recordRulePackageLifecycleForPackage(
        AVADataTypes.Role actingRole,
        uint256 packageId,
        AVADataTypes.RulePackageLifecycleKind kind,
        uint256 targetPackageId,
        string calldata uri
    ) external returns (uint256 id) {
        bytes32 authorityId = AUTHORITY_MATRIX.requireAuthorisedCanonicalSubject(
            msg.sender, actingRole, AVADataTypes.Action.RegisterRulePackage
        );
        id = _recordRulePackageLifecycleForPackage(actingRole, packageId, kind, targetPackageId, uri, authorityId);
    }

    function recordObjectMigrationReadiness(AVADataTypes.Role actingRole, ObjectMigrationReadinessInput calldata input)
        external
        returns (uint256 id)
    {
        AUTHORITY_MATRIX.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.RegisterRulePackage, input.authorityId
        );
        if (
            input.lifecycleRecordId == 0 || input.objectId == bytes32(0) || input.evidenceReceiptId == 0
                || input.boundaryHash == bytes32(0) || input.authorityId == bytes32(0) || bytes(input.uri).length == 0
        ) {
            revert AVADataTypes.EmptyValue();
        }
        AVADataTypes.RulePackageLifecycleRecord memory lifecycleRecord = lifecycleRecords[input.lifecycleRecordId];
        if (lifecycleRecord.id == 0) revert AVADataTypes.UnknownReference(input.lifecycleRecordId);
        if (lifecycleRecord.kind != AVADataTypes.RulePackageLifecycleKind.MigrationReady) {
            revert AVADataTypes.InvalidState(input.lifecycleRecordId);
        }
        RULE_PACKAGE_REGISTRY.getRulePackageById(lifecycleRecord.packageId);
        RULE_PACKAGE_REGISTRY.getRulePackageById(lifecycleRecord.targetPackageId);
        _requireMigrationReferences(lifecycleRecord, input);

        id = nextObjectMigrationReadinessRecordId++;
        objectMigrationReadinessRecords[id] = AVADataTypes.ObjectMigrationReadinessRecord({
            id: id,
            lifecycleRecordId: input.lifecycleRecordId,
            workflowKey: lifecycleRecord.workflowKey,
            packageId: lifecycleRecord.packageId,
            targetWorkflowKey: lifecycleRecord.targetWorkflowKey,
            targetPackageId: lifecycleRecord.targetPackageId,
            objectId: input.objectId,
            recognisedStateId: input.recognisedStateId,
            evidenceReceiptId: input.evidenceReceiptId,
            boundaryHash: input.boundaryHash,
            authorityRole: actingRole,
            authorityId: input.authorityId,
            uri: input.uri,
            createdAt: block.timestamp,
            recordedBy: msg.sender
        });
        emit ObjectMigrationReadinessRecorded(
            id, input.lifecycleRecordId, input.objectId, lifecycleRecord.packageId, lifecycleRecord.targetPackageId
        );
    }

    function recordDisclosureLifecycleReadiness(
        AVADataTypes.Role actingRole,
        bytes32 appId,
        bytes32 workflowKey,
        uint256 disclosurePolicyId,
        AVADataTypes.DisclosureLifecycleKind kind,
        bytes32 lifecycleReference,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        AUTHORITY_MATRIX.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.RecordDisclosureLifecycle, authorityId
        );
        if (
            appId == bytes32(0) || workflowKey == bytes32(0) || disclosurePolicyId == 0
                || kind == AVADataTypes.DisclosureLifecycleKind.None || lifecycleReference == bytes32(0)
                || authorityId == bytes32(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
        if (DISCLOSURE_REGISTRY.getDisclosurePolicy(disclosurePolicyId).appId != appId) {
            revert AVADataTypes.InvalidState(disclosurePolicyId);
        }
        AVARulePackageRegistry.RulePackage memory rulePackage = RULE_PACKAGE_REGISTRY.getRulePackage(appId, workflowKey);
        rulePackage.disclosureLifecycleModule
            .validateDisclosureLifecycle(
                workflowKey,
                AVADataTypes.Action.RecordDisclosureLifecycle,
                disclosurePolicyId,
                kind,
                lifecycleReference,
                msg.sender
            );

        id = nextDisclosureLifecycleRecordId++;
        disclosureLifecycleRecords[id] = AVADataTypes.DisclosureLifecycleRecord({
            id: id,
            workflowKey: workflowKey,
            packageId: rulePackage.packageId,
            disclosurePolicyId: disclosurePolicyId,
            kind: kind,
            lifecycleReference: lifecycleReference,
            uri: uri,
            authorityRole: actingRole,
            authorityId: authorityId,
            recordedBy: msg.sender
        });
        emit DisclosureLifecycleRecorded(id, workflowKey, disclosurePolicyId, kind);
    }

    function getRulePackageLifecycleRecord(uint256 id)
        external
        view
        returns (AVADataTypes.RulePackageLifecycleRecord memory)
    {
        AVADataTypes.RulePackageLifecycleRecord memory record = lifecycleRecords[id];
        if (record.id == 0) revert AVADataTypes.UnknownReference(id);
        return record;
    }

    function getObjectMigrationReadinessRecord(uint256 id)
        external
        view
        returns (AVADataTypes.ObjectMigrationReadinessRecord memory)
    {
        AVADataTypes.ObjectMigrationReadinessRecord memory record = objectMigrationReadinessRecords[id];
        if (record.id == 0) revert AVADataTypes.UnknownReference(id);
        return record;
    }

    function getDisclosureLifecycleRecord(uint256 id)
        external
        view
        returns (AVADataTypes.DisclosureLifecycleRecord memory)
    {
        AVADataTypes.DisclosureLifecycleRecord memory record = disclosureLifecycleRecords[id];
        if (record.id == 0) revert AVADataTypes.UnknownReference(id);
        return record;
    }

    function _recordRulePackageLifecycleForPackage(
        AVADataTypes.Role actingRole,
        uint256 packageId,
        AVADataTypes.RulePackageLifecycleKind kind,
        uint256 targetPackageId,
        string calldata uri,
        bytes32 authorityId
    ) internal returns (uint256 id) {
        if (packageId == 0 || kind == AVADataTypes.RulePackageLifecycleKind.None) {
            revert AVADataTypes.EmptyValue();
        }
        AVARulePackageRegistry.RulePackage memory rulePackage = RULE_PACKAGE_REGISTRY.getRulePackageById(packageId);
        bool targetRequired = _targetRequired(kind);
        if (targetRequired && targetPackageId == 0) revert AVADataTypes.EmptyValue();
        if (!targetRequired && targetPackageId != 0) revert AVADataTypes.InvalidState(targetPackageId);
        if (targetRequired && targetPackageId == packageId) revert AVADataTypes.InvalidState(targetPackageId);

        AVARulePackageRegistry.RulePackage memory targetPackage;
        if (targetRequired) {
            targetPackage = RULE_PACKAGE_REGISTRY.getRulePackageById(targetPackageId);
            if (targetPackage.appId != rulePackage.appId) revert AVADataTypes.InvalidState(targetPackageId);
        }
        rulePackage.rulePackageLifecycleModule
            .validateRulePackageLifecycle(
                IRulePackageLifecycleModule.RulePackageLifecycleContext({
                    workflowKey: rulePackage.workflowKey,
                    modulesHash: rulePackage.modulesHash,
                    modulesIdentityHash: rulePackage.modulesIdentityHash,
                    kind: kind,
                    version: rulePackage.version,
                    compatibilityKey: rulePackage.compatibilityKey,
                    dependencyURI: rulePackage.dependencyURI,
                    deprecated: rulePackage.deprecated,
                    targetWorkflowKey: targetPackage.workflowKey,
                    targetPackageId: targetPackageId,
                    targetModulesHash: targetPackage.modulesHash,
                    targetModulesIdentityHash: targetPackage.modulesIdentityHash,
                    targetVersion: targetPackage.version,
                    targetCompatibilityKey: targetPackage.compatibilityKey,
                    authorityRole: actingRole,
                    actor: msg.sender
                })
            );

        id = nextRulePackageLifecycleRecordId++;
        lifecycleRecords[id] = AVADataTypes.RulePackageLifecycleRecord({
            id: id,
            workflowKey: rulePackage.workflowKey,
            packageId: rulePackage.packageId,
            kind: kind,
            modulesHash: rulePackage.modulesHash,
            modulesIdentityHash: rulePackage.modulesIdentityHash,
            version: rulePackage.version,
            compatibilityKey: rulePackage.compatibilityKey,
            targetWorkflowKey: targetPackage.workflowKey,
            targetPackageId: targetPackageId,
            targetModulesHash: targetPackage.modulesHash,
            targetModulesIdentityHash: targetPackage.modulesIdentityHash,
            targetVersion: targetPackage.version,
            targetCompatibilityKey: targetPackage.compatibilityKey,
            dependencyURI: rulePackage.dependencyURI,
            uri: uri,
            authorityRole: actingRole,
            authorityId: authorityId,
            recordedBy: msg.sender
        });
        emit RulePackageLifecycleRecorded(id, rulePackage.workflowKey, kind, targetPackage.workflowKey, targetPackageId);
        emit RulePackageLifecyclePackageBinding(
            id,
            rulePackage.packageId,
            targetPackageId,
            rulePackage.modulesHash,
            rulePackage.modulesIdentityHash,
            targetPackage.modulesHash,
            targetPackage.modulesIdentityHash
        );
    }

    function _requireMigrationReferences(
        AVADataTypes.RulePackageLifecycleRecord memory lifecycleRecord,
        ObjectMigrationReadinessInput calldata input
    ) internal view {
        AVADataTypes.RecognisedStateRecord memory state = STATE_READER.getRecognisedState(input.recognisedStateId);
        AVARulePackageRegistry.RulePackage memory sourcePackage =
            RULE_PACKAGE_REGISTRY.getRulePackageById(lifecycleRecord.packageId);
        if (
            state.appId != sourcePackage.appId || state.packageId != lifecycleRecord.packageId
                || state.workflowKey != lifecycleRecord.workflowKey
        ) {
            revert AVADataTypes.InvalidState(input.recognisedStateId);
        }
        AVADataTypes.EvidenceReceipt memory evidence = EVIDENCE_READER.getEvidenceReceipt(input.evidenceReceiptId);
        if (
            evidence.appId != sourcePackage.appId || evidence.packageId != lifecycleRecord.packageId
                || evidence.workflowKey != lifecycleRecord.workflowKey
                || evidence.status != AVADataTypes.EvidenceReceiptStatus.Active
        ) {
            revert AVADataTypes.InvalidState(input.evidenceReceiptId);
        }
    }

    function _targetRequired(AVADataTypes.RulePackageLifecycleKind kind) internal pure returns (bool) {
        return kind == AVADataTypes.RulePackageLifecycleKind.SupersessionReady
            || kind == AVADataTypes.RulePackageLifecycleKind.MigrationReady;
    }
}
