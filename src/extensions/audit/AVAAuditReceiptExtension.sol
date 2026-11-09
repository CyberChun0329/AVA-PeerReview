// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAVAApplicationModule} from "../../interfaces/IAVAApplicationModule.sol";
import {AVAAuthorityMatrix} from "../../core/AVAAuthorityMatrix.sol";
import {AVACapabilityKeys} from "../../core/AVACapabilityKeys.sol";
import {AVACoreRulePackageRegistry} from "../../core/AVACoreRulePackageRegistry.sol";
import {AVACoreTypes} from "../../core/AVACoreTypes.sol";
import {AVADisclosurePolicyRegistry} from "../../core/AVADisclosurePolicyRegistry.sol";
import {AVAEvidenceRegistry} from "../../core/AVAEvidenceRegistry.sol";
import {AVAGovernanceKernel} from "../../core/AVAGovernanceKernel.sol";
import {AVAIdentityRegistry} from "../../core/AVAIdentityRegistry.sol";
import {AVAChallengeExtension} from "../challenge/AVAChallengeExtension.sol";
import {IAVAExtensionPolicyModule} from "../shared/IAVAExtensionPolicyModule.sol";
import {IAVAAntiAbusePolicyModule} from "../../core/interfaces/IAVACoreRuleModules.sol";

contract AVAAuditReceiptExtension {
    enum AuditTargetKind {
        None,
        EvidenceReceipt,
        RecognisedState,
        RecognisedStateTransition,
        ChallengeTransition
    }

    struct AuditInput {
        AuditTargetKind targetKind;
        uint256 targetId;
        bytes32 roleKey;
        bytes32 authorityId;
        bytes32 subjectId;
        uint256 evidenceId;
        bytes32 auditTypeKey;
        bytes32 attestationHash;
        bytes32 reasonHash;
        string uri;
    }

    struct AuditReceipt {
        uint256 id;
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        AuditTargetKind targetKind;
        uint256 targetId;
        uint256 recognisedStateId;
        uint256 recognisedStateTransitionId;
        uint256 sourceRecordId;
        bytes32 subjectId;
        uint256 evidenceId;
        bytes32 auditTypeKey;
        bytes32 attestationHash;
        bytes32 contextHash;
        bytes32 reasonHash;
        string uri;
        bytes32 authorityId;
        address recordedBy;
        uint64 recordedAt;
    }

    struct TargetContext {
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        uint256 recognisedStateId;
        uint256 recognisedStateTransitionId;
        uint256 sourceRecordId;
        bytes32 subjectId;
        uint256 evidenceId;
        uint256 disclosurePolicyId;
        bytes32 sourceTypeKey;
    }

    struct AuditModules {
        AVACoreRulePackageRegistry.VerifiedPackageContext rulePackage;
        IAVAApplicationModule application;
        IAVAExtensionPolicyModule auditPolicy;
        IAVAAntiAbusePolicyModule antiAbuse;
    }

    bytes32 public constant AUDIT_CONTEXT_DOMAIN = keccak256("ava.extension.audit-receipt.context.v2");
    bytes32 public constant EVIDENCE_SOURCE_TYPE = keccak256("ava.core.evidence-receipt-source.v1");
    bytes32 public constant STATE_SOURCE_TYPE = keccak256("ava.core.recognised-state-source.v1");
    bytes32 public constant TRANSITION_SOURCE_TYPE = keccak256("ava.core.recognised-state-transition-source.v1");
    bytes32 public constant CHALLENGE_TRANSITION_SOURCE_TYPE =
        keccak256("ava.extension.challenge-transition-source.v1");

    AVAGovernanceKernel public immutable GOVERNANCE_KERNEL;
    AVAAuthorityMatrix public immutable AUTHORITY_MATRIX;
    AVAIdentityRegistry public immutable IDENTITY_REGISTRY;
    AVACoreRulePackageRegistry public immutable RULE_PACKAGE_REGISTRY;
    AVAEvidenceRegistry public immutable EVIDENCE_REGISTRY;
    AVADisclosurePolicyRegistry public immutable DISCLOSURE_REGISTRY;
    AVAChallengeExtension public immutable CHALLENGE_EXTENSION;

    mapping(uint256 => AuditReceipt) private auditReceipts;
    mapping(bytes32 => uint256) public auditReceiptIdByContextHash;
    uint256 public nextAuditReceiptId = 1;

    event AuditReceiptRecorded(
        uint256 indexed auditReceiptId,
        bytes32 indexed appId,
        AuditTargetKind indexed targetKind,
        uint256 packageId,
        uint256 targetId,
        bytes32 auditTypeKey,
        bytes32 contextHash,
        address recordedBy
    );

    constructor(
        AVAGovernanceKernel governanceKernel_,
        AVAAuthorityMatrix authorityMatrix_,
        AVAIdentityRegistry identityRegistry_,
        AVACoreRulePackageRegistry rulePackageRegistry_,
        AVAEvidenceRegistry evidenceRegistry_,
        AVADisclosurePolicyRegistry disclosureRegistry_,
        address challengeExtension_
    ) {
        if (
            address(governanceKernel_) == address(0) || address(authorityMatrix_) == address(0)
                || address(identityRegistry_) == address(0) || address(rulePackageRegistry_) == address(0)
                || address(evidenceRegistry_) == address(0) || address(disclosureRegistry_) == address(0)
        ) revert AVACoreTypes.EmptyValue();
        if (
            address(governanceKernel_.AUTHORITY_MATRIX()) != address(authorityMatrix_)
                || address(governanceKernel_.IDENTITY_REGISTRY()) != address(identityRegistry_)
                || address(governanceKernel_.RULE_PACKAGE_REGISTRY()) != address(rulePackageRegistry_)
                || address(governanceKernel_.EVIDENCE_REGISTRY()) != address(evidenceRegistry_)
                || address(governanceKernel_.DISCLOSURE_REGISTRY()) != address(disclosureRegistry_)
        ) revert AVACoreTypes.InvalidState(0);
        if (challengeExtension_ != address(0)) {
            if (
                challengeExtension_.code.length == 0
                    || address(AVAChallengeExtension(challengeExtension_).GOVERNANCE_KERNEL())
                        != address(governanceKernel_)
                    || address(AVAChallengeExtension(challengeExtension_).RULE_PACKAGE_REGISTRY())
                        != address(rulePackageRegistry_)
            ) revert AVACoreTypes.InvalidState(0);
        }
        GOVERNANCE_KERNEL = governanceKernel_;
        AUTHORITY_MATRIX = authorityMatrix_;
        IDENTITY_REGISTRY = identityRegistry_;
        RULE_PACKAGE_REGISTRY = rulePackageRegistry_;
        EVIDENCE_REGISTRY = evidenceRegistry_;
        DISCLOSURE_REGISTRY = disclosureRegistry_;
        CHALLENGE_EXTENSION = AVAChallengeExtension(challengeExtension_);
    }

    function recordAudit(AuditInput calldata input) external returns (uint256 id) {
        if (
            input.targetKind == AuditTargetKind.None || input.targetId == 0 || input.roleKey == bytes32(0)
                || input.authorityId == bytes32(0) || input.subjectId == bytes32(0) || input.evidenceId == 0
                || input.auditTypeKey == bytes32(0) || input.attestationHash == bytes32(0)
                || input.reasonHash == bytes32(0)
        ) revert AVACoreTypes.EmptyValue();
        TargetContext memory target = _resolveTarget(input.targetKind, input.targetId);
        AuditModules memory modules = _verifiedAuditModules(target.packageId);
        if (modules.rulePackage.appId != target.appId || modules.rulePackage.workflowKey != target.workflowKey) {
            revert AVACoreTypes.InvalidState(target.packageId);
        }
        if (input.subjectId != target.subjectId || input.evidenceId != target.evidenceId) {
            revert AVACoreTypes.SubjectMismatch(target.subjectId, input.subjectId);
        }
        _validateTargetReferences(target, input);
        bytes32 contextHash = _auditContext(input, target);
        if (auditReceiptIdByContextHash[contextHash] != 0) {
            revert AVACoreTypes.InvalidState(auditReceiptIdByContextHash[contextHash]);
        }
        _validateApplication(target, input, modules.application);
        _validateAntiAbuse(target, input, modules.antiAbuse);
        _validatePolicy(target, input, contextHash, modules.auditPolicy);
        id = nextAuditReceiptId++;
        _storeAuditReceipt(id, input, target, contextHash);
        auditReceiptIdByContextHash[contextHash] = id;
        emit AuditReceiptRecorded(
            id,
            target.appId,
            input.targetKind,
            target.packageId,
            input.targetId,
            input.auditTypeKey,
            contextHash,
            msg.sender
        );
    }

    function getAuditReceipt(uint256 id) external view returns (AuditReceipt memory receipt) {
        receipt = auditReceipts[id];
        if (receipt.id == 0) revert AVACoreTypes.UnknownReference(id);
    }

    function _resolveTarget(AuditTargetKind kind, uint256 targetId) private view returns (TargetContext memory target) {
        if (kind == AuditTargetKind.EvidenceReceipt) return _evidenceTarget(targetId);
        if (kind == AuditTargetKind.RecognisedState) return _stateTarget(targetId);
        if (kind == AuditTargetKind.RecognisedStateTransition) return _stateTransitionTarget(targetId);
        if (kind == AuditTargetKind.ChallengeTransition) return _challengeTransitionTarget(targetId);
        revert AVACoreTypes.InvalidState(targetId);
    }

    function _evidenceTarget(uint256 evidenceId) private view returns (TargetContext memory target) {
        AVAEvidenceRegistry.EvidenceReference memory evidence = EVIDENCE_REGISTRY.getEvidenceReference(evidenceId);
        target.appId = evidence.appId;
        target.workflowKey = evidence.workflowKey;
        target.packageId = evidence.packageId;
        target.subjectId = evidence.subjectId;
        target.evidenceId = evidence.id;
        target.disclosurePolicyId = evidence.disclosurePolicyId;
        target.sourceRecordId = evidence.id;
        target.sourceTypeKey = EVIDENCE_SOURCE_TYPE;
    }

    function _stateTarget(uint256 stateId) private view returns (TargetContext memory target) {
        AVAGovernanceKernel.RecognisedStateReference memory state =
            GOVERNANCE_KERNEL.getRecognisedStateReference(stateId);
        target.appId = state.appId;
        target.workflowKey = state.workflowKey;
        target.packageId = state.packageId;
        target.recognisedStateId = state.id;
        target.recognisedStateTransitionId = state.lastTransitionId;
        target.subjectId = state.subjectId;
        target.evidenceId = state.evidenceReceiptId;
        target.disclosurePolicyId = state.disclosurePolicyId;
        target.sourceRecordId = state.id;
        target.sourceTypeKey = STATE_SOURCE_TYPE;
    }

    function _stateTransitionTarget(uint256 transitionId) private view returns (TargetContext memory target) {
        AVAGovernanceKernel.RecognisedStateTransitionReference memory transition =
            GOVERNANCE_KERNEL.getRecognisedStateTransitionReference(transitionId);
        AVAGovernanceKernel.RecognisedStateReference memory state =
            GOVERNANCE_KERNEL.getRecognisedStateReference(transition.recognisedStateId);
        target.appId = transition.appId;
        target.packageId = transition.decisionPackageId == 0 ? transition.packageId : transition.decisionPackageId;
        target.recognisedStateId = state.id;
        target.recognisedStateTransitionId = transition.id;
        AVAEvidenceRegistry.EvidenceReference memory decisionEvidence =
            EVIDENCE_REGISTRY.getEvidenceReference(transition.decisionEvidenceReceiptId);
        target.workflowKey = decisionEvidence.workflowKey;
        target.subjectId = decisionEvidence.subjectId;
        target.evidenceId = decisionEvidence.id;
        target.disclosurePolicyId = decisionEvidence.disclosurePolicyId;
        target.sourceRecordId = transition.id;
        target.sourceTypeKey = TRANSITION_SOURCE_TYPE;
        if (
            state.appId != transition.appId || decisionEvidence.appId != transition.appId
                || decisionEvidence.packageId != target.packageId
        ) {
            revert AVACoreTypes.InvalidState(transitionId);
        }
    }

    function _challengeTransitionTarget(uint256 transitionId) private view returns (TargetContext memory target) {
        if (address(CHALLENGE_EXTENSION) == address(0)) revert AVACoreTypes.InvalidState(transitionId);
        AVAChallengeExtension.ChallengeTransitionRecord memory transition =
            CHALLENGE_EXTENSION.getChallengeTransition(transitionId);
        AVAChallengeExtension.ChallengeRecord memory challenge =
            CHALLENGE_EXTENSION.getChallenge(transition.challengeId);
        AVAGovernanceKernel.RecognisedStateReference memory state =
            GOVERNANCE_KERNEL.getRecognisedStateReference(challenge.challengeRecognisedStateId);
        if (
            challenge.id != transition.challengeId || challenge.packageId != transition.packageId
                || transition.challengeRecognisedStateId != state.id || state.packageId != challenge.packageId
                || state.subjectId != challenge.challengerSubjectId
                || state.evidenceReceiptId != challenge.evidenceReceiptId
                || state.disclosurePolicyId != challenge.disclosurePolicyId || transition.appId != challenge.appId
                || state.appId != challenge.appId
        ) revert AVACoreTypes.InvalidState(transitionId);
        target.appId = challenge.appId;
        target.workflowKey = challenge.workflowKey;
        target.packageId = transition.packageId;
        target.recognisedStateId = state.id;
        target.recognisedStateTransitionId = transition.challengeStateTransitionIdAfter;
        target.sourceRecordId = transition.id;
        target.subjectId = challenge.challengerSubjectId;
        target.evidenceId = transition.evidenceReceiptId;
        target.disclosurePolicyId = challenge.disclosurePolicyId;
        target.sourceTypeKey = CHALLENGE_TRANSITION_SOURCE_TYPE;
    }

    function _validateTargetReferences(TargetContext memory target, AuditInput calldata input) private view {
        AVAIdentityRegistry.SubjectContext memory subject = IDENTITY_REGISTRY.getSubjectContext(target.subjectId);
        if (subject.appId != target.appId) {
            revert AVACoreTypes.CrossApplicationReference(target.appId, subject.appId);
        }
        AUTHORITY_MATRIX.requireAuthorisedSubject(
            msg.sender, target.appId, input.roleKey, AVACoreTypes.ACTION_RECORD_AUDIT_RECEIPT, input.authorityId
        );
        (bytes32 appId, bytes32 workflowKey,,, uint256 disclosurePolicyId) =
            EVIDENCE_REGISTRY.requireUsableEvidenceReferenceForPackage(target.evidenceId, target.packageId);
        if (
            appId != target.appId || workflowKey != target.workflowKey
                || disclosurePolicyId != target.disclosurePolicyId
        ) revert AVACoreTypes.InvalidState(target.evidenceId);
        DISCLOSURE_REGISTRY.requireActivePolicyReference(target.disclosurePolicyId, target.appId);
    }

    function _validateApplication(
        TargetContext memory target,
        AuditInput calldata input,
        IAVAApplicationModule application
    ) private view {
        if (target.recognisedStateId == 0) return;
        AVAGovernanceKernel.RecognisedStateReference memory state =
            GOVERNANCE_KERNEL.getRecognisedStateReference(target.recognisedStateId);
        AVAGovernanceKernel.GovernedObjectReference memory objectRecord =
            GOVERNANCE_KERNEL.getGovernedObjectReference(state.governedObjectId);
        application.validateDownstreamRecord(
            IAVAApplicationModule.DownstreamRecordContext({
                appId: target.appId,
                workflowKey: target.workflowKey,
                packageId: target.packageId,
                actionKey: AVACoreTypes.ACTION_RECORD_AUDIT_RECEIPT,
                roleKey: input.roleKey,
                recognisedStateId: state.id,
                governedObjectId: state.governedObjectId,
                objectTypeKey: objectRecord.objectTypeKey,
                subjectId: target.subjectId,
                evidenceReceiptId: target.evidenceId,
                recordTypeKey: input.auditTypeKey,
                authorityId: input.authorityId,
                actor: msg.sender
            })
        );
    }

    function _validatePolicy(
        TargetContext memory target,
        AuditInput calldata input,
        bytes32 contextHash,
        IAVAExtensionPolicyModule auditPolicy
    ) private view {
        auditPolicy.validateExtensionRecord(
            IAVAExtensionPolicyModule.ExtensionPolicyContext({
                appId: target.appId,
                workflowKey: target.workflowKey,
                packageId: target.packageId,
                capabilityKey: AVACapabilityKeys.AUDIT_RECEIPT,
                actionKey: AVACoreTypes.ACTION_RECORD_AUDIT_RECEIPT,
                recordTypeKey: input.auditTypeKey,
                scopeKey: bytes32(uint256(input.targetKind)),
                sourceTypeKey: target.sourceTypeKey,
                recognisedStateId: target.recognisedStateId,
                recognisedStateTransitionId: target.recognisedStateTransitionId,
                subjectId: target.subjectId,
                evidenceId: target.evidenceId,
                disclosurePolicyId: target.disclosurePolicyId,
                sourceRecordId: target.sourceRecordId,
                unsignedValue: input.targetId,
                validUntil: 0,
                payloadHash: input.attestationHash,
                contextHash: contextHash,
                authorityId: input.authorityId,
                actor: msg.sender
            })
        );
    }

    function _validateAntiAbuse(
        TargetContext memory target,
        AuditInput calldata input,
        IAVAAntiAbusePolicyModule antiAbuse
    ) private view {
        if (address(antiAbuse) == address(0)) return;
        antiAbuse.validateAntiAbuse(
            IAVAAntiAbusePolicyModule.AntiAbuseContext({
                appId: target.appId,
                workflowKey: target.workflowKey,
                packageId: target.packageId,
                actionKey: AVACoreTypes.ACTION_RECORD_AUDIT_RECEIPT,
                roleKey: input.roleKey,
                targetId: input.targetId,
                targetTypeKey: target.sourceTypeKey,
                actorSubjectId: input.authorityId,
                targetSubjectId: target.subjectId,
                authorityId: input.authorityId,
                actor: msg.sender
            })
        );
    }

    function _verifiedAuditModules(uint256 packageId) private view returns (AuditModules memory modules) {
        bytes32[] memory keys = new bytes32[](3);
        keys[0] = AVACapabilityKeys.APPLICATION;
        keys[1] = AVACapabilityKeys.AUDIT_RECEIPT;
        keys[2] = AVACapabilityKeys.ANTI_ABUSE;
        (AVACoreRulePackageRegistry.VerifiedPackageContext memory rulePackage, address[] memory addresses) =
            RULE_PACKAGE_REGISTRY.getVerifiedModulesCompact(packageId, keys);
        if (addresses[1] == address(0)) revert AVACoreTypes.UnknownReference(packageId);
        modules = AuditModules({
            rulePackage: rulePackage,
            application: IAVAApplicationModule(addresses[0]),
            auditPolicy: IAVAExtensionPolicyModule(addresses[1]),
            antiAbuse: IAVAAntiAbusePolicyModule(addresses[2])
        });
    }

    function _auditContext(AuditInput calldata input, TargetContext memory target) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                AUDIT_CONTEXT_DOMAIN,
                target.appId,
                target.workflowKey,
                target.packageId,
                input.targetKind,
                input.targetId,
                target.recognisedStateId,
                target.recognisedStateTransitionId,
                target.sourceRecordId,
                input.subjectId,
                input.evidenceId,
                input.auditTypeKey,
                input.attestationHash
            )
        );
    }

    function _storeAuditReceipt(uint256 id, AuditInput calldata input, TargetContext memory target, bytes32 contextHash)
        private
    {
        AuditReceipt storage receipt = auditReceipts[id];
        receipt.id = id;
        receipt.appId = target.appId;
        receipt.workflowKey = target.workflowKey;
        receipt.packageId = target.packageId;
        receipt.targetKind = input.targetKind;
        receipt.targetId = input.targetId;
        receipt.recognisedStateId = target.recognisedStateId;
        receipt.recognisedStateTransitionId = target.recognisedStateTransitionId;
        receipt.sourceRecordId = target.sourceRecordId;
        receipt.subjectId = target.subjectId;
        receipt.evidenceId = target.evidenceId;
        receipt.auditTypeKey = input.auditTypeKey;
        receipt.attestationHash = input.attestationHash;
        receipt.contextHash = contextHash;
        receipt.reasonHash = input.reasonHash;
        receipt.uri = input.uri;
        receipt.authorityId = input.authorityId;
        receipt.recordedBy = msg.sender;
        receipt.recordedAt = uint64(block.timestamp);
    }
}
