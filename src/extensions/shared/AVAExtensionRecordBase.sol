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
import {IAVAExtensionPolicyModule} from "./IAVAExtensionPolicyModule.sol";
import {IAVAAntiAbusePolicyModule} from "../../core/interfaces/IAVACoreRuleModules.sol";

abstract contract AVAExtensionRecordBase {
    struct ExtensionValidationInput {
        uint256 recognisedStateId;
        bytes32 roleKey;
        bytes32 authorityId;
        bytes32 subjectId;
        uint256 evidenceId;
        bytes32 capabilityKey;
        bytes32 actionKey;
        bytes32 recordTypeKey;
        bytes32 scopeKey;
        bytes32 sourceTypeKey;
        uint256 sourceRecordId;
        uint256 unsignedValue;
        uint64 validUntil;
        bytes32 payloadHash;
        bool requireActiveSubject;
        bytes32 contextHash;
    }

    struct ExtensionModules {
        AVACoreRulePackageRegistry.VerifiedPackageContext rulePackage;
        IAVAApplicationModule application;
        IAVAExtensionPolicyModule extensionPolicy;
        IAVAAntiAbusePolicyModule antiAbuse;
    }

    AVAGovernanceKernel public immutable GOVERNANCE_KERNEL;
    AVAAuthorityMatrix public immutable AUTHORITY_MATRIX;
    AVAIdentityRegistry public immutable IDENTITY_REGISTRY;
    AVACoreRulePackageRegistry public immutable RULE_PACKAGE_REGISTRY;
    AVAEvidenceRegistry public immutable EVIDENCE_REGISTRY;
    AVADisclosurePolicyRegistry public immutable DISCLOSURE_REGISTRY;

    constructor(
        AVAGovernanceKernel governanceKernel_,
        AVAAuthorityMatrix authorityMatrix_,
        AVAIdentityRegistry identityRegistry_,
        AVACoreRulePackageRegistry rulePackageRegistry_,
        AVAEvidenceRegistry evidenceRegistry_,
        AVADisclosurePolicyRegistry disclosureRegistry_
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
        GOVERNANCE_KERNEL = governanceKernel_;
        AUTHORITY_MATRIX = authorityMatrix_;
        IDENTITY_REGISTRY = identityRegistry_;
        RULE_PACKAGE_REGISTRY = rulePackageRegistry_;
        EVIDENCE_REGISTRY = evidenceRegistry_;
        DISCLOSURE_REGISTRY = disclosureRegistry_;
    }

    function _validateExtension(ExtensionValidationInput memory input)
        internal
        view
        returns (AVAGovernanceKernel.RecognisedStateReference memory state)
    {
        return _validateExtensionSubject(input, true, true);
    }

    function _validateExtensionWithState(
        ExtensionValidationInput memory input,
        AVAGovernanceKernel.RecognisedStateReference memory state
    ) internal view returns (AVAGovernanceKernel.RecognisedStateReference memory) {
        _requireExtensionValidationInput(input);
        return _validateExtensionSubjectWithState(input, state, true, true);
    }

    function _validateExtensionForRelatedSubject(ExtensionValidationInput memory input)
        internal
        view
        returns (AVAGovernanceKernel.RecognisedStateReference memory state)
    {
        return _validateExtensionSubject(input, false, true);
    }

    function _validateExtensionForRelatedSubjectWithState(
        ExtensionValidationInput memory input,
        AVAGovernanceKernel.RecognisedStateReference memory state
    ) internal view returns (AVAGovernanceKernel.RecognisedStateReference memory) {
        _requireExtensionValidationInput(input);
        return _validateExtensionSubjectWithState(input, state, false, true);
    }

    function _validateExtensionForDefensiveCloseout(ExtensionValidationInput memory input)
        internal
        view
        returns (AVAGovernanceKernel.RecognisedStateReference memory state)
    {
        return _validateExtensionSubject(input, true, false);
    }

    function _validateExtensionForDefensiveCloseoutWithState(
        ExtensionValidationInput memory input,
        AVAGovernanceKernel.RecognisedStateReference memory state
    ) internal view returns (AVAGovernanceKernel.RecognisedStateReference memory) {
        _requireExtensionValidationInput(input);
        return _validateExtensionSubjectWithState(input, state, true, false);
    }

    function _validateExtensionSubject(
        ExtensionValidationInput memory input,
        bool requireStateSubject,
        bool requireActiveEvidence
    )
        private
        view
        returns (AVAGovernanceKernel.RecognisedStateReference memory state)
    {
        _requireExtensionValidationInput(input);
        state = GOVERNANCE_KERNEL.getRecognisedStateReference(input.recognisedStateId);
        return _validateExtensionSubjectWithState(input, state, requireStateSubject, requireActiveEvidence);
    }

    function _validateExtensionSubjectWithState(
        ExtensionValidationInput memory input,
        AVAGovernanceKernel.RecognisedStateReference memory state,
        bool requireStateSubject,
        bool requireActiveEvidence
    ) private view returns (AVAGovernanceKernel.RecognisedStateReference memory) {
        if (state.id == 0 || state.id != input.recognisedStateId) {
            revert AVACoreTypes.InvalidState(input.recognisedStateId);
        }
        _validateRecordContext(input, state, requireStateSubject, requireActiveEvidence);
        return state;
    }

    function _requireExtensionValidationInput(ExtensionValidationInput memory input) private pure {
        if (
            input.recognisedStateId == 0 || input.roleKey == bytes32(0) || input.authorityId == bytes32(0)
                || input.subjectId == bytes32(0) || input.evidenceId == 0 || input.capabilityKey == bytes32(0)
                || input.actionKey == bytes32(0) || input.recordTypeKey == bytes32(0) || input.contextHash == bytes32(0)
        ) revert AVACoreTypes.EmptyValue();
    }

    function _validateRecordContext(
        ExtensionValidationInput memory input,
        AVAGovernanceKernel.RecognisedStateReference memory state,
        bool requireStateSubject,
        bool requireActiveEvidence
    ) private view {
        if (requireStateSubject && state.subjectId != input.subjectId) {
            revert AVACoreTypes.SubjectMismatch(state.subjectId, input.subjectId);
        }
        if (input.requireActiveSubject) {
            IDENTITY_REGISTRY.requireActiveSubjectReference(input.subjectId, state.appId);
        } else {
            AVAIdentityRegistry.SubjectContext memory subject = IDENTITY_REGISTRY.getSubjectContext(input.subjectId);
            if (subject.appId != state.appId) {
                revert AVACoreTypes.CrossApplicationReference(state.appId, subject.appId);
            }
        }
        AUTHORITY_MATRIX.requireAuthorisedSubject(
            msg.sender, state.appId, input.roleKey, input.actionKey, input.authorityId
        );
        ExtensionModules memory modules = _verifiedExtensionModules(state.packageId, input.capabilityKey);
        if (modules.rulePackage.appId != state.appId || modules.rulePackage.workflowKey != state.workflowKey) {
            revert AVACoreTypes.InvalidState(state.packageId);
        }
        AVAGovernanceKernel.GovernedObjectReference memory objectRecord =
            GOVERNANCE_KERNEL.getGovernedObjectReference(state.governedObjectId);
        if (
            objectRecord.appId != state.appId || objectRecord.workflowKey != state.workflowKey
                || objectRecord.packageId != state.packageId || objectRecord.subjectId != state.subjectId
                || objectRecord.evidenceReceiptId != state.evidenceReceiptId
                || objectRecord.disclosurePolicyId != state.disclosurePolicyId
        ) revert AVACoreTypes.InvalidState(state.governedObjectId);
        _requireEvidence(state.evidenceReceiptId, state, requireActiveEvidence);
        if (input.evidenceId != state.evidenceReceiptId) {
            _requireEvidence(input.evidenceId, state, requireActiveEvidence);
        }
        DISCLOSURE_REGISTRY.requireActivePolicyReference(state.disclosurePolicyId, state.appId);

        IAVAApplicationModule.DownstreamRecordContext memory applicationContext =
            IAVAApplicationModule.DownstreamRecordContext({
                appId: state.appId,
                workflowKey: state.workflowKey,
                packageId: state.packageId,
                actionKey: input.actionKey,
                roleKey: input.roleKey,
                recognisedStateId: state.id,
                governedObjectId: state.governedObjectId,
                objectTypeKey: objectRecord.objectTypeKey,
                subjectId: input.subjectId,
                evidenceReceiptId: input.evidenceId,
                recordTypeKey: input.recordTypeKey,
                authorityId: input.authorityId,
                actor: msg.sender
            });
        modules.application.validateDownstreamRecord(applicationContext);
        modules.extensionPolicy
            .validateExtensionRecord(
                IAVAExtensionPolicyModule.ExtensionPolicyContext({
                    appId: state.appId,
                    workflowKey: state.workflowKey,
                    packageId: state.packageId,
                    capabilityKey: input.capabilityKey,
                    actionKey: input.actionKey,
                    recordTypeKey: input.recordTypeKey,
                    scopeKey: input.scopeKey,
                    sourceTypeKey: input.sourceTypeKey,
                    recognisedStateId: state.id,
                    recognisedStateTransitionId: state.lastTransitionId,
                    subjectId: input.subjectId,
                    evidenceId: input.evidenceId,
                    disclosurePolicyId: state.disclosurePolicyId,
                    sourceRecordId: input.sourceRecordId,
                    unsignedValue: input.unsignedValue,
                    validUntil: input.validUntil,
                    payloadHash: input.payloadHash,
                    contextHash: input.contextHash,
                    authorityId: input.authorityId,
                    actor: msg.sender
                })
            );
        if (address(modules.antiAbuse) != address(0)) {
            modules.antiAbuse
                .validateAntiAbuse(
                    IAVAAntiAbusePolicyModule.AntiAbuseContext({
                        appId: state.appId,
                        workflowKey: state.workflowKey,
                        packageId: state.packageId,
                        actionKey: input.actionKey,
                        roleKey: input.roleKey,
                        targetId: state.id,
                        targetTypeKey: input.recordTypeKey,
                        actorSubjectId: input.authorityId,
                        targetSubjectId: input.subjectId,
                        authorityId: input.authorityId,
                        actor: msg.sender
                    })
                );
        }
    }

    function _verifiedExtensionModules(uint256 packageId, bytes32 capabilityKey)
        private
        view
        returns (ExtensionModules memory modules)
    {
        bytes32[] memory keys = new bytes32[](3);
        keys[0] = AVACapabilityKeys.APPLICATION;
        keys[1] = capabilityKey;
        keys[2] = AVACapabilityKeys.ANTI_ABUSE;
        (AVACoreRulePackageRegistry.VerifiedPackageContext memory rulePackage, address[] memory addresses) =
            RULE_PACKAGE_REGISTRY.getVerifiedModulesCompact(packageId, keys);
        if (addresses[1] == address(0)) revert AVACoreTypes.UnknownReference(packageId);
        modules = ExtensionModules({
            rulePackage: rulePackage,
            application: IAVAApplicationModule(addresses[0]),
            extensionPolicy: IAVAExtensionPolicyModule(addresses[1]),
            antiAbuse: IAVAAntiAbusePolicyModule(addresses[2])
        });
    }

    function _requireEvidence(
        uint256 evidenceId,
        AVAGovernanceKernel.RecognisedStateReference memory state,
        bool requireActiveEvidence
    ) private view {
        bytes32 appId;
        bytes32 workflowKey;
        bytes32 subjectId;
        uint256 disclosurePolicyId;
        if (requireActiveEvidence) {
            (appId, workflowKey,, subjectId, disclosurePolicyId) =
                EVIDENCE_REGISTRY.requireUsableEvidenceReferenceForPackage(evidenceId, state.packageId);
        } else {
            (appId, workflowKey,, subjectId, disclosurePolicyId) =
                EVIDENCE_REGISTRY.requireEvidenceReferenceForPackage(evidenceId, state.packageId);
        }
        if (
            appId != state.appId || workflowKey != state.workflowKey
                || subjectId != state.subjectId || disclosurePolicyId != state.disclosurePolicyId
        ) revert AVACoreTypes.InvalidState(evidenceId);
    }
}
