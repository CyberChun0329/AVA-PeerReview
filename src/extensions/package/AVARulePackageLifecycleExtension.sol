// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRuleModuleIdentity, RuleModuleIdentity} from "../../interfaces/IRuleModuleIdentity.sol";
import {AVAAuthorityMatrix} from "../../core/AVAAuthorityMatrix.sol";
import {AVACapabilityKeys} from "../../core/AVACapabilityKeys.sol";
import {AVACoreRulePackageRegistry} from "../../core/AVACoreRulePackageRegistry.sol";
import {AVACoreTypes} from "../../core/AVACoreTypes.sol";
import {AVADisclosurePolicyRegistry} from "../../core/AVADisclosurePolicyRegistry.sol";
import {AVAEvidenceRegistry} from "../../core/AVAEvidenceRegistry.sol";
import {AVAGovernanceKernel} from "../../core/AVAGovernanceKernel.sol";
import {AVAIdentityRegistry} from "../../core/AVAIdentityRegistry.sol";

interface IAVAPackageLifecyclePolicyModule is IRuleModuleIdentity {
    struct PackageLifecycleContext {
        bytes32 appId;
        bytes32 workflowKey;
        uint256 sourcePackageId;
        uint256 targetPackageId;
        bytes32 compatibilityKey;
        uint64 sourceVersion;
        uint64 targetVersion;
        bytes32 lifecycleKindKey;
        bytes32 roleKey;
        bytes32 authorityId;
        bytes32 reasonHash;
        address actor;
    }

    function validatePackageLifecycle(PackageLifecycleContext calldata context) external view;

    struct ObjectMigrationReadinessContext {
        bytes32 appId;
        bytes32 workflowKey;
        uint256 sourcePackageId;
        uint256 targetPackageId;
        uint256 lifecycleRecordId;
        uint256 recognisedStateId;
        uint256 recognisedStateTransitionId;
        bytes32 subjectId;
        uint256 evidenceId;
        bytes32 roleKey;
        bytes32 authorityId;
        bytes32 reasonHash;
        address actor;
    }

    struct DisclosureLifecycleReadinessContext {
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        uint256 disclosurePolicyId;
        bytes32 subjectId;
        uint256 evidenceId;
        bytes32 lifecycleKindKey;
        bytes32 roleKey;
        bytes32 authorityId;
        bytes32 reasonHash;
        address actor;
    }

    function validateObjectMigrationReadiness(ObjectMigrationReadinessContext calldata context) external view;

    function validateDisclosureLifecycleReadiness(DisclosureLifecycleReadinessContext calldata context) external view;
}

contract DefaultAVAPackageLifecyclePolicyModule is IAVAPackageLifecyclePolicyModule, RuleModuleIdentity {
    function validatePackageLifecycle(PackageLifecycleContext calldata) external pure {}

    function validateObjectMigrationReadiness(ObjectMigrationReadinessContext calldata) external pure {}

    function validateDisclosureLifecycleReadiness(DisclosureLifecycleReadinessContext calldata) external pure {}
}

contract AVARulePackageLifecycleExtension {
    enum PackageLifecycleKind {
        None,
        Deprecated,
        Superseded,
        MigrationReady
    }

    struct PackageLifecycleInput {
        uint256 sourcePackageId;
        uint256 targetPackageId;
        bytes32 roleKey;
        bytes32 authorityId;
        PackageLifecycleKind kind;
        bytes32 reasonHash;
        string uri;
    }

    struct PackageLifecycleRecord {
        uint256 id;
        bytes32 appId;
        bytes32 workflowKey;
        uint256 sourcePackageId;
        uint256 targetPackageId;
        bytes32 compatibilityKey;
        uint64 sourceVersion;
        uint64 targetVersion;
        PackageLifecycleKind kind;
        bytes32 authorityId;
        bytes32 reasonHash;
        string uri;
        address recordedBy;
        uint64 recordedAt;
    }

    AVAAuthorityMatrix public immutable AUTHORITY_MATRIX;
    AVACoreRulePackageRegistry public immutable RULE_PACKAGE_REGISTRY;

    mapping(uint256 => PackageLifecycleRecord) private lifecycleRecords;
    mapping(bytes32 => uint256) public lifecycleRecordIdByContext;
    uint256 public nextLifecycleRecordId = 1;

    event PackageLifecycleRecorded(
        uint256 indexed recordId,
        bytes32 indexed appId,
        bytes32 indexed workflowKey,
        uint256 sourcePackageId,
        uint256 targetPackageId,
        PackageLifecycleKind kind,
        bytes32 authorityId,
        address recordedBy
    );

    constructor(AVAAuthorityMatrix authorityMatrix_, AVACoreRulePackageRegistry rulePackageRegistry_) {
        if (address(authorityMatrix_) == address(0) || address(rulePackageRegistry_) == address(0)) {
            revert AVACoreTypes.EmptyValue();
        }
        if (address(rulePackageRegistry_.AUTHORITY_MATRIX()) != address(authorityMatrix_)) {
            revert AVACoreTypes.InvalidState(0);
        }
        AUTHORITY_MATRIX = authorityMatrix_;
        RULE_PACKAGE_REGISTRY = rulePackageRegistry_;
    }

    function recordPackageLifecycle(PackageLifecycleInput calldata input) external returns (uint256 recordId) {
        if (
            input.sourcePackageId == 0 || input.roleKey == bytes32(0) || input.authorityId == bytes32(0)
                || input.kind == PackageLifecycleKind.None || input.reasonHash == bytes32(0)
        ) revert AVACoreTypes.EmptyValue();

        bytes32[] memory capabilityKeys = new bytes32[](1);
        capabilityKeys[0] = AVACapabilityKeys.PACKAGE_LIFECYCLE;
        AVACoreRulePackageRegistry.VerifiedPackageContext memory source;
        address[] memory sourceModules;
        (source, sourceModules) =
            RULE_PACKAGE_REGISTRY.getVerifiedModulesCompact(input.sourcePackageId, capabilityKeys);
        if (sourceModules[0] == address(0)) revert AVACoreTypes.UnknownReference(input.sourcePackageId);
        AVACoreRulePackageRegistry.VerifiedPackageContext memory target;
        if (input.kind == PackageLifecycleKind.Deprecated) {
            if (input.targetPackageId != 0) revert AVACoreTypes.InvalidState(input.targetPackageId);
        } else {
            if (input.targetPackageId == 0) revert AVACoreTypes.EmptyValue();
            target = RULE_PACKAGE_REGISTRY.getVerifiedPackageContext(input.targetPackageId);
            if (
                target.appId != source.appId || target.workflowKey != source.workflowKey
                    || target.compatibilityKey != source.compatibilityKey || target.version <= source.version
            ) revert AVACoreTypes.InvalidState(input.targetPackageId);
        }

        AUTHORITY_MATRIX.requireAuthorisedSubject(
            msg.sender,
            source.appId,
            input.roleKey,
            AVACoreTypes.ACTION_RECORD_PACKAGE_LIFECYCLE,
            input.authorityId
        );
        IAVAPackageLifecyclePolicyModule(sourceModules[0]).validatePackageLifecycle(
            IAVAPackageLifecyclePolicyModule.PackageLifecycleContext({
                appId: source.appId,
                workflowKey: source.workflowKey,
                sourcePackageId: source.packageId,
                targetPackageId: target.packageId,
                compatibilityKey: source.compatibilityKey,
                sourceVersion: source.version,
                targetVersion: target.version,
                lifecycleKindKey: bytes32(uint256(uint8(input.kind))),
                roleKey: input.roleKey,
                authorityId: input.authorityId,
                reasonHash: input.reasonHash,
                actor: msg.sender
            })
        );

        bytes32 contextKey = keccak256(abi.encode(source.packageId, target.packageId, input.kind));
        if (lifecycleRecordIdByContext[contextKey] != 0) {
            revert AVACoreTypes.InvalidState(lifecycleRecordIdByContext[contextKey]);
        }
        recordId = nextLifecycleRecordId++;
        lifecycleRecords[recordId] = PackageLifecycleRecord({
            id: recordId,
            appId: source.appId,
            workflowKey: source.workflowKey,
            sourcePackageId: source.packageId,
            targetPackageId: target.packageId,
            compatibilityKey: source.compatibilityKey,
            sourceVersion: source.version,
            targetVersion: target.version,
            kind: input.kind,
            authorityId: input.authorityId,
            reasonHash: input.reasonHash,
            uri: input.uri,
            recordedBy: msg.sender,
            recordedAt: uint64(block.timestamp)
        });
        lifecycleRecordIdByContext[contextKey] = recordId;
        emit PackageLifecycleRecorded(
            recordId,
            source.appId,
            source.workflowKey,
            source.packageId,
            target.packageId,
            input.kind,
            input.authorityId,
            msg.sender
        );
    }

    function getPackageLifecycleRecord(uint256 recordId)
        external
        view
        returns (PackageLifecycleRecord memory record)
    {
        record = lifecycleRecords[recordId];
        if (record.id == 0) revert AVACoreTypes.UnknownReference(recordId);
    }
}

contract AVAPackageReadinessExtension {
    struct ObjectMigrationReadinessInput {
        uint256 lifecycleRecordId;
        uint256 recognisedStateId;
        uint256 targetPackageId;
        bytes32 roleKey;
        bytes32 authorityId;
        uint256 evidenceId;
        bytes32 reasonHash;
        string uri;
    }

    struct ObjectMigrationReadinessRecord {
        uint256 id;
        bytes32 appId;
        bytes32 workflowKey;
        uint256 sourcePackageId;
        uint256 targetPackageId;
        uint256 lifecycleRecordId;
        uint256 recognisedStateId;
        uint256 recognisedStateTransitionId;
        bytes32 subjectId;
        uint256 evidenceId;
        bytes32 authorityId;
        bytes32 reasonHash;
        string uri;
        address recordedBy;
        uint64 recordedAt;
    }

    struct DisclosureLifecycleReadinessInput {
        uint256 packageId;
        uint256 disclosurePolicyId;
        bytes32 subjectId;
        uint256 evidenceId;
        bytes32 lifecycleKindKey;
        bytes32 roleKey;
        bytes32 authorityId;
        bytes32 reasonHash;
        string uri;
    }

    struct DisclosureLifecycleReadinessRecord {
        uint256 id;
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        uint256 disclosurePolicyId;
        bytes32 subjectId;
        uint256 evidenceId;
        bytes32 lifecycleKindKey;
        bytes32 authorityId;
        bytes32 reasonHash;
        string uri;
        address recordedBy;
        uint64 recordedAt;
    }

    AVAAuthorityMatrix public immutable AUTHORITY_MATRIX;
    AVAIdentityRegistry public immutable IDENTITY_REGISTRY;
    AVACoreRulePackageRegistry public immutable RULE_PACKAGE_REGISTRY;
    AVAEvidenceRegistry public immutable EVIDENCE_REGISTRY;
    AVADisclosurePolicyRegistry public immutable DISCLOSURE_REGISTRY;
    AVAGovernanceKernel public immutable GOVERNANCE_KERNEL;
    AVARulePackageLifecycleExtension public immutable LIFECYCLE_EXTENSION;

    mapping(uint256 => ObjectMigrationReadinessRecord) private objectMigrationRecords;
    mapping(uint256 => DisclosureLifecycleReadinessRecord) private disclosureReadinessRecords;
    mapping(bytes32 => uint256) public objectMigrationRecordIdByContext;
    mapping(bytes32 => uint256) public disclosureReadinessRecordIdByContext;
    uint256 public nextObjectMigrationReadinessRecordId = 1;
    uint256 public nextDisclosureLifecycleReadinessRecordId = 1;

    event ObjectMigrationReadinessRecorded(
        uint256 indexed recordId,
        uint256 indexed recognisedStateId,
        uint256 indexed sourcePackageId,
        uint256 targetPackageId,
        uint256 lifecycleRecordId,
        address recordedBy
    );
    event DisclosureLifecycleReadinessRecorded(
        uint256 indexed recordId,
        bytes32 indexed appId,
        uint256 indexed packageId,
        uint256 disclosurePolicyId,
        bytes32 subjectId,
        bytes32 lifecycleKindKey,
        address recordedBy
    );

    constructor(
        AVAAuthorityMatrix authorityMatrix_,
        AVAIdentityRegistry identityRegistry_,
        AVACoreRulePackageRegistry rulePackageRegistry_,
        AVAEvidenceRegistry evidenceRegistry_,
        AVADisclosurePolicyRegistry disclosureRegistry_,
        AVAGovernanceKernel governanceKernel_,
        AVARulePackageLifecycleExtension lifecycleExtension_
    ) {
        if (
            address(authorityMatrix_) == address(0) || address(identityRegistry_) == address(0)
                || address(rulePackageRegistry_) == address(0) || address(evidenceRegistry_) == address(0)
                || address(disclosureRegistry_) == address(0) || address(governanceKernel_) == address(0)
                || address(lifecycleExtension_) == address(0)
        ) revert AVACoreTypes.EmptyValue();
        if (
            address(authorityMatrix_.IDENTITY_REGISTRY()) != address(identityRegistry_)
                || address(rulePackageRegistry_.AUTHORITY_MATRIX()) != address(authorityMatrix_)
                || address(governanceKernel_.AUTHORITY_MATRIX()) != address(authorityMatrix_)
                || address(governanceKernel_.IDENTITY_REGISTRY()) != address(identityRegistry_)
                || address(governanceKernel_.RULE_PACKAGE_REGISTRY()) != address(rulePackageRegistry_)
                || address(governanceKernel_.EVIDENCE_REGISTRY()) != address(evidenceRegistry_)
                || address(governanceKernel_.DISCLOSURE_REGISTRY()) != address(disclosureRegistry_)
                || address(lifecycleExtension_.RULE_PACKAGE_REGISTRY()) != address(rulePackageRegistry_)
        ) revert AVACoreTypes.InvalidState(0);
        AUTHORITY_MATRIX = authorityMatrix_;
        IDENTITY_REGISTRY = identityRegistry_;
        RULE_PACKAGE_REGISTRY = rulePackageRegistry_;
        EVIDENCE_REGISTRY = evidenceRegistry_;
        DISCLOSURE_REGISTRY = disclosureRegistry_;
        GOVERNANCE_KERNEL = governanceKernel_;
        LIFECYCLE_EXTENSION = lifecycleExtension_;
    }

    function recordObjectMigrationReadiness(ObjectMigrationReadinessInput calldata input)
        external
        returns (uint256 recordId)
    {
        if (
            input.lifecycleRecordId == 0 || input.recognisedStateId == 0 || input.targetPackageId == 0
                || input.roleKey == bytes32(0) || input.authorityId == bytes32(0) || input.evidenceId == 0
                || input.reasonHash == bytes32(0)
        ) revert AVACoreTypes.EmptyValue();
        AVARulePackageLifecycleExtension.PackageLifecycleRecord memory lifecycle =
            LIFECYCLE_EXTENSION.getPackageLifecycleRecord(input.lifecycleRecordId);
        AVACoreTypes.RecognisedStateRecord memory state = GOVERNANCE_KERNEL.getRecognisedState(input.recognisedStateId);
        if (
            lifecycle.kind != AVARulePackageLifecycleExtension.PackageLifecycleKind.MigrationReady
                || lifecycle.sourcePackageId != state.packageId || lifecycle.targetPackageId != input.targetPackageId
                || lifecycle.appId != state.appId || lifecycle.workflowKey != state.workflowKey
        ) revert AVACoreTypes.InvalidState(input.lifecycleRecordId);
        AVACoreRulePackageRegistry.VerifiedPackageContext memory target =
            RULE_PACKAGE_REGISTRY.getVerifiedPackageContext(input.targetPackageId);
        if (
            target.appId != state.appId || target.workflowKey != state.workflowKey
                || target.compatibilityKey != lifecycle.compatibilityKey || target.version != lifecycle.targetVersion
                || target.version <= lifecycle.sourceVersion
        ) revert AVACoreTypes.InvalidState(input.targetPackageId);
        _requireAuthority(
            state.appId,
            input.roleKey,
            AVACoreTypes.ACTION_RECORD_OBJECT_MIGRATION_READINESS,
            input.authorityId
        );
        _requireEvidence(input.evidenceId, state.appId, state.workflowKey, state.packageId, state.subjectId, 0);
        IAVAPackageLifecyclePolicyModule(
            RULE_PACKAGE_REGISTRY.getModule(state.packageId, AVACapabilityKeys.PACKAGE_LIFECYCLE)
        ).validateObjectMigrationReadiness(
            IAVAPackageLifecyclePolicyModule.ObjectMigrationReadinessContext({
                appId: state.appId,
                workflowKey: state.workflowKey,
                sourcePackageId: state.packageId,
                targetPackageId: input.targetPackageId,
                lifecycleRecordId: input.lifecycleRecordId,
                recognisedStateId: state.id,
                recognisedStateTransitionId: state.lastTransitionId,
                subjectId: state.subjectId,
                evidenceId: input.evidenceId,
                roleKey: input.roleKey,
                authorityId: input.authorityId,
                reasonHash: input.reasonHash,
                actor: msg.sender
            })
        );
        bytes32 contextKey = keccak256(abi.encode(state.id, state.lastTransitionId, input.targetPackageId));
        if (objectMigrationRecordIdByContext[contextKey] != 0) {
            revert AVACoreTypes.InvalidState(objectMigrationRecordIdByContext[contextKey]);
        }
        recordId = nextObjectMigrationReadinessRecordId++;
        objectMigrationRecords[recordId] = ObjectMigrationReadinessRecord({
            id: recordId,
            appId: state.appId,
            workflowKey: state.workflowKey,
            sourcePackageId: state.packageId,
            targetPackageId: input.targetPackageId,
            lifecycleRecordId: input.lifecycleRecordId,
            recognisedStateId: state.id,
            recognisedStateTransitionId: state.lastTransitionId,
            subjectId: state.subjectId,
            evidenceId: input.evidenceId,
            authorityId: input.authorityId,
            reasonHash: input.reasonHash,
            uri: input.uri,
            recordedBy: msg.sender,
            recordedAt: uint64(block.timestamp)
        });
        objectMigrationRecordIdByContext[contextKey] = recordId;
        emit ObjectMigrationReadinessRecorded(
            recordId, state.id, state.packageId, input.targetPackageId, input.lifecycleRecordId, msg.sender
        );
    }

    function recordDisclosureLifecycleReadiness(DisclosureLifecycleReadinessInput calldata input)
        external
        returns (uint256 recordId)
    {
        if (
            input.packageId == 0 || input.disclosurePolicyId == 0 || input.subjectId == bytes32(0)
                || input.evidenceId == 0 || input.lifecycleKindKey == bytes32(0) || input.roleKey == bytes32(0)
                || input.authorityId == bytes32(0) || input.reasonHash == bytes32(0)
        ) revert AVACoreTypes.EmptyValue();
        bytes32[] memory capabilityKeys = new bytes32[](1);
        capabilityKeys[0] = AVACapabilityKeys.PACKAGE_LIFECYCLE;
        AVACoreRulePackageRegistry.VerifiedPackageContext memory rulePackage;
        address[] memory modules;
        (rulePackage, modules) = RULE_PACKAGE_REGISTRY.getVerifiedModulesCompact(input.packageId, capabilityKeys);
        if (modules[0] == address(0)) revert AVACoreTypes.UnknownReference(input.packageId);
        IDENTITY_REGISTRY.requireActiveSubjectReference(input.subjectId, rulePackage.appId);
        DISCLOSURE_REGISTRY.requireActivePolicyReference(input.disclosurePolicyId, rulePackage.appId);
        _requireEvidence(
            input.evidenceId,
            rulePackage.appId,
            rulePackage.workflowKey,
            rulePackage.packageId,
            input.subjectId,
            input.disclosurePolicyId
        );
        _requireAuthority(
            rulePackage.appId,
            input.roleKey,
            AVACoreTypes.ACTION_RECORD_DISCLOSURE_LIFECYCLE_READINESS,
            input.authorityId
        );
        IAVAPackageLifecyclePolicyModule(modules[0]).validateDisclosureLifecycleReadiness(
            IAVAPackageLifecyclePolicyModule.DisclosureLifecycleReadinessContext({
                appId: rulePackage.appId,
                workflowKey: rulePackage.workflowKey,
                packageId: rulePackage.packageId,
                disclosurePolicyId: input.disclosurePolicyId,
                subjectId: input.subjectId,
                evidenceId: input.evidenceId,
                lifecycleKindKey: input.lifecycleKindKey,
                roleKey: input.roleKey,
                authorityId: input.authorityId,
                reasonHash: input.reasonHash,
                actor: msg.sender
            })
        );
        bytes32 contextKey = keccak256(
            abi.encode(
                rulePackage.packageId,
                input.disclosurePolicyId,
                input.subjectId,
                input.evidenceId,
                input.lifecycleKindKey
            )
        );
        if (disclosureReadinessRecordIdByContext[contextKey] != 0) {
            revert AVACoreTypes.InvalidState(disclosureReadinessRecordIdByContext[contextKey]);
        }
        recordId = nextDisclosureLifecycleReadinessRecordId++;
        disclosureReadinessRecords[recordId] = DisclosureLifecycleReadinessRecord({
            id: recordId,
            appId: rulePackage.appId,
            workflowKey: rulePackage.workflowKey,
            packageId: rulePackage.packageId,
            disclosurePolicyId: input.disclosurePolicyId,
            subjectId: input.subjectId,
            evidenceId: input.evidenceId,
            lifecycleKindKey: input.lifecycleKindKey,
            authorityId: input.authorityId,
            reasonHash: input.reasonHash,
            uri: input.uri,
            recordedBy: msg.sender,
            recordedAt: uint64(block.timestamp)
        });
        disclosureReadinessRecordIdByContext[contextKey] = recordId;
        emit DisclosureLifecycleReadinessRecorded(
            recordId,
            rulePackage.appId,
            rulePackage.packageId,
            input.disclosurePolicyId,
            input.subjectId,
            input.lifecycleKindKey,
            msg.sender
        );
    }

    function getObjectMigrationReadinessRecord(uint256 recordId)
        external
        view
        returns (ObjectMigrationReadinessRecord memory record)
    {
        record = objectMigrationRecords[recordId];
        if (record.id == 0) revert AVACoreTypes.UnknownReference(recordId);
    }

    function getDisclosureLifecycleReadinessRecord(uint256 recordId)
        external
        view
        returns (DisclosureLifecycleReadinessRecord memory record)
    {
        record = disclosureReadinessRecords[recordId];
        if (record.id == 0) revert AVACoreTypes.UnknownReference(recordId);
    }

    function _requireAuthority(bytes32 appId, bytes32 roleKey, bytes32 actionKey, bytes32 authorityId)
        private
        view
    {
        AUTHORITY_MATRIX.requireAuthorisedSubject(msg.sender, appId, roleKey, actionKey, authorityId);
    }

    function _requireEvidence(
        uint256 evidenceId,
        bytes32 appId,
        bytes32 workflowKey,
        uint256 packageId,
        bytes32 subjectId,
        uint256 disclosurePolicyId
    ) private view {
        (bytes32 evidenceAppId, bytes32 evidenceWorkflowKey,, bytes32 evidenceSubjectId, uint256 evidencePolicyId) =
            EVIDENCE_REGISTRY.requireUsableEvidenceReferenceForPackage(evidenceId, packageId);
        if (
            evidenceAppId != appId || evidenceWorkflowKey != workflowKey || evidenceSubjectId != subjectId
                || (disclosurePolicyId != 0 && evidencePolicyId != disclosurePolicyId)
        ) revert AVACoreTypes.InvalidState(evidenceId);
    }
}
