// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAVAApplicationModule} from "../interfaces/IAVAApplicationModule.sol";
import {AVAAuthorityMatrix} from "./AVAAuthorityMatrix.sol";
import {AVACapabilityKeys} from "./AVACapabilityKeys.sol";
import {AVACoreTypes} from "./AVACoreTypes.sol";
import {AVACoreRulePackageRegistry} from "./AVACoreRulePackageRegistry.sol";
import {AVADisclosurePolicyRegistry} from "./AVADisclosurePolicyRegistry.sol";
import {AVAIdentityRegistry} from "./AVAIdentityRegistry.sol";
import {
    IAVAEvidencePolicyModule,
    IAVAEvidenceLifecycleModule,
    IAVADisclosurePolicyModule
} from "./interfaces/IAVACoreRuleModules.sol";

contract AVAEvidenceRegistry {
    struct EvidenceRegistrationInput {
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 roleKey;
        bytes32 subjectId;
        bytes32 commitment;
        bytes32 evidenceTypeHash;
        uint256 disclosurePolicyId;
        bytes32 authorityId;
        string uri;
    }

    struct EvidenceRegistrationModules {
        IAVAApplicationModule application;
        IAVAEvidencePolicyModule evidencePolicy;
        IAVADisclosurePolicyModule disclosurePolicy;
    }

    /// @notice Fixed-size evidence context for contract-to-contract validation paths.
    /// @dev Full metadata, including URI and registrar, remains available through getEvidence.
    struct EvidenceReference {
        uint256 id;
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 commitment;
        bytes32 evidenceTypeHash;
        bytes32 subjectId;
        uint256 disclosurePolicyId;
        bytes32 authorityId;
        AVACoreTypes.EvidenceStatus status;
        uint256 lastLifecycleRecordId;
        uint256 replacementEvidenceId;
    }

    AVAAuthorityMatrix public immutable AUTHORITY_MATRIX;
    AVAIdentityRegistry public immutable IDENTITY_REGISTRY;
    AVACoreRulePackageRegistry public immutable RULE_PACKAGE_REGISTRY;
    AVADisclosurePolicyRegistry public immutable DISCLOSURE_REGISTRY;

    mapping(uint256 => AVACoreTypes.EvidenceRecord) private evidenceRecords;
    mapping(uint256 => AVACoreTypes.EvidenceLifecycleRecord) private lifecycleRecords;
    uint256 public nextEvidenceId = 1;
    uint256 public nextLifecycleRecordId = 1;

    event EvidenceRegistered(
        uint256 indexed evidenceId,
        bytes32 indexed appId,
        uint256 indexed packageId,
        bytes32 subjectId,
        bytes32 commitment,
        bytes32 evidenceTypeHash,
        address registeredBy
    );
    event EvidenceLifecycleRecorded(
        uint256 indexed lifecycleRecordId,
        uint256 indexed evidenceId,
        AVACoreTypes.EvidenceLifecycleKind indexed kind,
        AVACoreTypes.EvidenceStatus toStatus,
        bytes32 authorityId,
        address createdBy
    );

    constructor(
        AVAAuthorityMatrix authorityMatrix_,
        AVAIdentityRegistry identityRegistry_,
        AVACoreRulePackageRegistry rulePackageRegistry_,
        AVADisclosurePolicyRegistry disclosureRegistry_
    ) {
        if (
            address(authorityMatrix_) == address(0) || address(identityRegistry_) == address(0)
                || address(rulePackageRegistry_) == address(0) || address(disclosureRegistry_) == address(0)
        ) {
            revert AVACoreTypes.EmptyValue();
        }
        if (
            address(authorityMatrix_.IDENTITY_REGISTRY()) != address(identityRegistry_)
                || address(authorityMatrix_.APPLICATION_REGISTRY())
                    != address(rulePackageRegistry_.APPLICATION_REGISTRY())
                || address(rulePackageRegistry_.AUTHORITY_MATRIX()) != address(authorityMatrix_)
                || address(disclosureRegistry_.AUTHORITY_MATRIX()) != address(authorityMatrix_)
        ) {
            revert AVACoreTypes.InvalidState(0);
        }
        AUTHORITY_MATRIX = authorityMatrix_;
        IDENTITY_REGISTRY = identityRegistry_;
        RULE_PACKAGE_REGISTRY = rulePackageRegistry_;
        DISCLOSURE_REGISTRY = disclosureRegistry_;
    }

    function registerEvidence(EvidenceRegistrationInput calldata input) external returns (uint256 evidenceId) {
        if (
            input.appId == bytes32(0) || input.workflowKey == bytes32(0) || input.packageId == 0
                || input.roleKey == bytes32(0) || input.subjectId == bytes32(0) || input.commitment == bytes32(0)
                || input.evidenceTypeHash == bytes32(0) || input.disclosurePolicyId == 0
                || input.authorityId == bytes32(0)
        ) {
            revert AVACoreTypes.EmptyValue();
        }
        bytes32 callerAuthorityId = AUTHORITY_MATRIX.requireAuthorisedCanonicalSubject(
            msg.sender, input.appId, input.roleKey, AVACoreTypes.ACTION_REGISTER_EVIDENCE
        );
        if (callerAuthorityId != input.authorityId) {
            revert AVACoreTypes.SubjectMismatch(callerAuthorityId, input.authorityId);
        }
        IDENTITY_REGISTRY.requireActiveSubjectReference(input.subjectId, input.appId);
        DISCLOSURE_REGISTRY.requireActivePolicyReference(input.disclosurePolicyId, input.appId);
        EvidenceRegistrationModules memory modules = _verifiedRegistrationModules(input);
        IAVAApplicationModule.EvidenceContext memory context = IAVAApplicationModule.EvidenceContext({
            appId: input.appId,
            workflowKey: input.workflowKey,
            packageId: input.packageId,
            roleKey: input.roleKey,
            subjectId: input.subjectId,
            evidenceTypeHash: input.evidenceTypeHash,
            disclosurePolicyId: input.disclosurePolicyId,
            authorityId: input.authorityId,
            actor: msg.sender
        });
        modules.application.validateEvidence(context);
        modules.evidencePolicy.validateEvidence(context);
        modules.disclosurePolicy
            .validateDisclosure(
                IAVADisclosurePolicyModule.DisclosureContext({
                    appId: input.appId,
                    workflowKey: input.workflowKey,
                    packageId: input.packageId,
                    actionKey: AVACoreTypes.ACTION_REGISTER_EVIDENCE,
                    roleKey: input.roleKey,
                    stage: AVACoreTypes.Stage.Attribution,
                    objectTypeKey: bytes32(0),
                    subjectId: input.subjectId,
                    disclosurePolicyId: input.disclosurePolicyId,
                    targetId: 0,
                    evidenceId: 0,
                    evidenceTypeHash: input.evidenceTypeHash,
                    authorityId: input.authorityId,
                    actor: msg.sender
                })
            );

        evidenceId = nextEvidenceId++;
        evidenceRecords[evidenceId] = AVACoreTypes.EvidenceRecord({
            id: evidenceId,
            appId: input.appId,
            workflowKey: input.workflowKey,
            packageId: input.packageId,
            commitment: input.commitment,
            evidenceTypeHash: input.evidenceTypeHash,
            subjectId: input.subjectId,
            disclosurePolicyId: input.disclosurePolicyId,
            authorityId: input.authorityId,
            uri: input.uri,
            registeredBy: msg.sender,
            status: AVACoreTypes.EvidenceStatus.Active,
            lastLifecycleRecordId: 0,
            replacementEvidenceId: 0,
            registeredAt: uint64(block.timestamp)
        });
        emit EvidenceRegistered(
            evidenceId,
            input.appId,
            input.packageId,
            input.subjectId,
            input.commitment,
            input.evidenceTypeHash,
            msg.sender
        );
    }

    function _verifiedRegistrationModules(EvidenceRegistrationInput calldata input)
        private
        view
        returns (EvidenceRegistrationModules memory modules)
    {
        bytes32[] memory keys = new bytes32[](3);
        keys[0] = AVACapabilityKeys.APPLICATION;
        keys[1] = AVACapabilityKeys.EVIDENCE_POLICY;
        keys[2] = AVACapabilityKeys.DISCLOSURE_POLICY;
        (, address[] memory addresses) = RULE_PACKAGE_REGISTRY.getActiveVerifiedModulesCompact(
            input.appId, input.workflowKey, input.packageId, keys
        );
        modules = EvidenceRegistrationModules({
            application: IAVAApplicationModule(addresses[0]),
            evidencePolicy: IAVAEvidencePolicyModule(addresses[1]),
            disclosurePolicy: IAVADisclosurePolicyModule(addresses[2])
        });
    }

    function recordEvidenceLifecycle(
        uint256 evidenceId,
        bytes32 roleKey,
        bytes32 authorityId,
        AVACoreTypes.EvidenceLifecycleKind kind,
        uint256 replacementEvidenceId,
        bytes32 reasonHash,
        string calldata uri
    ) external returns (uint256 lifecycleRecordId) {
        AVACoreTypes.EvidenceRecord storage evidence = _evidenceStorage(evidenceId);
        if (
            roleKey == bytes32(0) || authorityId == bytes32(0) || kind == AVACoreTypes.EvidenceLifecycleKind.None
                || reasonHash == bytes32(0) || evidence.status != AVACoreTypes.EvidenceStatus.Active
        ) {
            revert AVACoreTypes.InvalidState(evidenceId);
        }
        bytes32 callerAuthorityId = AUTHORITY_MATRIX.requireAuthorisedCanonicalSubject(
            msg.sender, evidence.appId, roleKey, AVACoreTypes.ACTION_RECORD_EVIDENCE_LIFECYCLE
        );
        if (callerAuthorityId != authorityId) {
            revert AVACoreTypes.SubjectMismatch(callerAuthorityId, authorityId);
        }
        AVACoreTypes.EvidenceStatus toStatus = _statusForLifecycleKind(kind);
        if (kind == AVACoreTypes.EvidenceLifecycleKind.Supersede) {
            _requireCompatibleReplacement(evidence, replacementEvidenceId);
        } else if (replacementEvidenceId != 0) {
            revert AVACoreTypes.InvalidState(replacementEvidenceId);
        }
        IAVAEvidenceLifecycleModule(
                RULE_PACKAGE_REGISTRY.getModule(evidence.packageId, AVACapabilityKeys.EVIDENCE_LIFECYCLE)
            )
            .validateEvidenceLifecycle(
                IAVAEvidenceLifecycleModule.EvidenceLifecycleContext({
                    appId: evidence.appId,
                    workflowKey: evidence.workflowKey,
                    packageId: evidence.packageId,
                    evidenceId: evidence.id,
                    evidenceTypeHash: evidence.evidenceTypeHash,
                    subjectId: evidence.subjectId,
                    disclosurePolicyId: evidence.disclosurePolicyId,
                    fromStatus: evidence.status,
                    toStatus: toStatus,
                    kind: kind,
                    replacementEvidenceId: replacementEvidenceId,
                    roleKey: roleKey,
                    authorityId: authorityId,
                    reasonHash: reasonHash,
                    actor: msg.sender
                })
            );

        lifecycleRecordId = nextLifecycleRecordId++;
        lifecycleRecords[lifecycleRecordId] = AVACoreTypes.EvidenceLifecycleRecord({
            id: lifecycleRecordId,
            evidenceId: evidenceId,
            appId: evidence.appId,
            packageId: evidence.packageId,
            kind: kind,
            fromStatus: evidence.status,
            toStatus: toStatus,
            replacementEvidenceId: replacementEvidenceId,
            authorityId: authorityId,
            reasonHash: reasonHash,
            uri: uri,
            createdBy: msg.sender,
            createdAt: uint64(block.timestamp)
        });
        evidence.status = toStatus;
        evidence.lastLifecycleRecordId = lifecycleRecordId;
        evidence.replacementEvidenceId = replacementEvidenceId;
        emit EvidenceLifecycleRecorded(lifecycleRecordId, evidenceId, kind, toStatus, authorityId, msg.sender);
    }

    function getEvidence(uint256 evidenceId) external view returns (AVACoreTypes.EvidenceRecord memory) {
        AVACoreTypes.EvidenceRecord memory evidence = evidenceRecords[evidenceId];
        if (evidence.id == 0) revert AVACoreTypes.UnknownReference(evidenceId);
        return evidence;
    }

    function getEvidenceReference(uint256 evidenceId) external view returns (EvidenceReference memory evidenceRef) {
        AVACoreTypes.EvidenceRecord storage evidence = _evidenceStorage(evidenceId);
        evidenceRef = EvidenceReference({
            id: evidence.id,
            appId: evidence.appId,
            workflowKey: evidence.workflowKey,
            packageId: evidence.packageId,
            commitment: evidence.commitment,
            evidenceTypeHash: evidence.evidenceTypeHash,
            subjectId: evidence.subjectId,
            disclosurePolicyId: evidence.disclosurePolicyId,
            authorityId: evidence.authorityId,
            status: evidence.status,
            lastLifecycleRecordId: evidence.lastLifecycleRecordId,
            replacementEvidenceId: evidence.replacementEvidenceId
        });
    }

    function getEvidenceLifecycleRecord(uint256 lifecycleRecordId)
        external
        view
        returns (AVACoreTypes.EvidenceLifecycleRecord memory)
    {
        AVACoreTypes.EvidenceLifecycleRecord memory record = lifecycleRecords[lifecycleRecordId];
        if (record.id == 0) revert AVACoreTypes.UnknownReference(lifecycleRecordId);
        return record;
    }

    function requireUsableEvidenceReferenceForPackage(uint256 evidenceId, uint256 packageId)
        external
        view
        returns (
            bytes32 appId,
            bytes32 workflowKey,
            uint256 receiptPackageId,
            bytes32 subjectId,
            uint256 disclosurePolicyId
        )
    {
        AVACoreTypes.EvidenceRecord storage evidence = evidenceRecords[evidenceId];
        if (
            evidence.id == 0 || packageId == 0 || evidence.packageId != packageId
                || evidence.status != AVACoreTypes.EvidenceStatus.Active
        ) {
            revert AVACoreTypes.InvalidState(evidenceId);
        }
        return
            (evidence.appId, evidence.workflowKey, evidence.packageId, evidence.subjectId, evidence.disclosurePolicyId);
    }

    function requireEvidenceReferenceForPackage(uint256 evidenceId, uint256 packageId)
        external
        view
        returns (
            bytes32 appId,
            bytes32 workflowKey,
            uint256 receiptPackageId,
            bytes32 subjectId,
            uint256 disclosurePolicyId
        )
    {
        AVACoreTypes.EvidenceRecord storage evidence = evidenceRecords[evidenceId];
        if (evidence.id == 0 || packageId == 0 || evidence.packageId != packageId) {
            revert AVACoreTypes.InvalidState(evidenceId);
        }
        return
            (evidence.appId, evidence.workflowKey, evidence.packageId, evidence.subjectId, evidence.disclosurePolicyId);
    }

    function _evidenceStorage(uint256 evidenceId) internal view returns (AVACoreTypes.EvidenceRecord storage evidence) {
        evidence = evidenceRecords[evidenceId];
        if (evidence.id == 0) revert AVACoreTypes.UnknownReference(evidenceId);
    }

    function _requireCompatibleReplacement(AVACoreTypes.EvidenceRecord storage evidence, uint256 replacementEvidenceId)
        internal
        view
    {
        if (replacementEvidenceId == evidence.id) revert AVACoreTypes.InvalidState(replacementEvidenceId);
        AVACoreTypes.EvidenceRecord memory replacement = evidenceRecords[replacementEvidenceId];
        if (
            replacement.id == 0 || replacement.status != AVACoreTypes.EvidenceStatus.Active
                || replacement.packageId != evidence.packageId || replacement.appId != evidence.appId
                || replacement.subjectId != evidence.subjectId
                || replacement.disclosurePolicyId != evidence.disclosurePolicyId
                || replacement.evidenceTypeHash != evidence.evidenceTypeHash
        ) {
            revert AVACoreTypes.InvalidState(replacementEvidenceId);
        }
    }

    function _statusForLifecycleKind(AVACoreTypes.EvidenceLifecycleKind kind)
        internal
        pure
        returns (AVACoreTypes.EvidenceStatus)
    {
        if (kind == AVACoreTypes.EvidenceLifecycleKind.Revoke) return AVACoreTypes.EvidenceStatus.Revoked;
        if (kind == AVACoreTypes.EvidenceLifecycleKind.Expire) return AVACoreTypes.EvidenceStatus.Expired;
        if (kind == AVACoreTypes.EvidenceLifecycleKind.Supersede) return AVACoreTypes.EvidenceStatus.Superseded;
        revert AVACoreTypes.EmptyValue();
    }
}
