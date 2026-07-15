// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAVAApplicationModule} from "../interfaces/IAVAApplicationModule.sol";
import {AVACoreRulePackageRegistry} from "./AVACoreRulePackageRegistry.sol";
import {AVACoreTypes} from "./AVACoreTypes.sol";
import {AVADisclosurePolicyRegistry} from "./AVADisclosurePolicyRegistry.sol";
import {AVAEvidenceRegistry} from "./AVAEvidenceRegistry.sol";
import {
    IAVAVerificationModule,
    IAVATransitionRuleModule,
    IAVAEvidencePolicyModule,
    IAVAEvidenceLifecycleModule,
    IAVADisclosurePolicyModule,
    IAVAChallengePolicyModule,
    IAVAAuthorityPolicyModule,
    IAVAFieldPolicyModule,
    IAVAAntiAbusePolicyModule
} from "./interfaces/IAVACoreRuleModules.sol";

/// @notice Stateless dispatcher for package-bound recognised-state policies.
/// @dev The governance kernel retains all reference checks, hard transition rules, storage, and mutation authority.
contract AVAWorkflowPolicyRouter {
    bytes32 public constant FORMATION_DECISION_DOMAIN = keccak256("ava.core.formation-decision.v1");
    bytes32 public constant TRANSITION_DECISION_DOMAIN = keccak256("ava.core.transition-decision.v1");

    struct FormationPolicyInput {
        IAVAApplicationModule.RecognisedStateFormationContext context;
        uint256 evidenceId;
        uint256 disclosurePolicyId;
        bytes32 reasonHash;
    }

    struct TransitionPolicyInput {
        IAVAApplicationModule.RecognisedStateTransitionContext context;
        bytes32 actionKey;
        uint256 evidenceId;
        uint256 disclosurePolicyId;
        uint256 targetVersionId;
        uint256 decisionPackageId;
        uint256 decisionEvidenceId;
        uint256 sourceRecordId;
        uint256 disclosureTargetId;
        bytes32 reasonHash;
        bytes32 decisionHash;
        bool allowInactiveEvidence;
    }

    struct WorkflowModules {
        AVACoreRulePackageRegistry.VerifiedPackageContext rulePackage;
        IAVAApplicationModule application;
        IAVAVerificationModule verification;
        IAVATransitionRuleModule transitionRule;
        IAVAEvidencePolicyModule evidencePolicy;
        IAVAEvidenceLifecycleModule evidenceLifecycle;
        IAVADisclosurePolicyModule disclosurePolicy;
        IAVAAuthorityPolicyModule authorityPolicy;
        IAVAFieldPolicyModule fieldPolicy;
        IAVAAntiAbusePolicyModule antiAbusePolicy;
    }

    struct ChallengePolicyInput {
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 actionKey;
        bytes32 roleKey;
        AVACoreTypes.Stage stage;
        bytes32 objectTypeKey;
        uint256 challengeId;
        uint256 recognisedStateId;
        bytes32 actorSubjectId;
        bytes32 targetSubjectId;
        bytes32 outcomeKey;
        AVACoreTypes.RecognisedStateStatus targetStatus;
        uint256 evidenceId;
        uint256 disclosurePolicyId;
        bytes32 authorityId;
        bytes32 decisionHash;
        address actor;
        bool validateDisclosure;
        bool validateAuthority;
    }

    struct ChallengeModules {
        IAVAChallengePolicyModule challengePolicy;
        IAVADisclosurePolicyModule disclosurePolicy;
        IAVAAuthorityPolicyModule authorityPolicy;
        IAVAAntiAbusePolicyModule antiAbusePolicy;
    }

    AVACoreRulePackageRegistry public immutable RULE_PACKAGE_REGISTRY;
    AVAEvidenceRegistry public immutable EVIDENCE_REGISTRY;
    AVADisclosurePolicyRegistry public immutable DISCLOSURE_REGISTRY;

    constructor(
        AVACoreRulePackageRegistry rulePackageRegistry_,
        AVAEvidenceRegistry evidenceRegistry_,
        AVADisclosurePolicyRegistry disclosureRegistry_
    ) {
        if (
            address(rulePackageRegistry_) == address(0) || address(evidenceRegistry_) == address(0)
                || address(disclosureRegistry_) == address(0)
        ) revert AVACoreTypes.EmptyValue();
        if (
            address(evidenceRegistry_.RULE_PACKAGE_REGISTRY()) != address(rulePackageRegistry_)
                || address(evidenceRegistry_.DISCLOSURE_REGISTRY()) != address(disclosureRegistry_)
        ) revert AVACoreTypes.InvalidState(0);
        RULE_PACKAGE_REGISTRY = rulePackageRegistry_;
        EVIDENCE_REGISTRY = evidenceRegistry_;
        DISCLOSURE_REGISTRY = disclosureRegistry_;
    }

    function validateFormation(FormationPolicyInput calldata input) external view {
        WorkflowModules memory modules =
            _loadModules(input.context.packageId, input.context.appId, input.context.workflowKey);
        AVAEvidenceRegistry.EvidenceReference memory evidence = _requireEvidence(
            input.context.appId,
            input.context.workflowKey,
            input.context.packageId,
            input.context.subjectId,
            input.evidenceId,
            input.disclosurePolicyId,
            false
        );
        modules.application.validateRecognisedStateFormation(input.context);
        modules.verification.validateVerification(input.context);

        IAVAApplicationModule.EvidenceUseContext memory evidenceUse = _formationEvidenceUse(input, evidence);
        modules.evidencePolicy.validateEvidenceUse(evidenceUse);
        modules.evidenceLifecycle.validateEvidenceUse(evidenceUse);
        modules.disclosurePolicy.validateDisclosure(_formationDisclosure(input, evidence));
        modules.authorityPolicy
            .validateAuthority(
                IAVAAuthorityPolicyModule.AuthorityContext({
                    appId: input.context.appId,
                    workflowKey: input.context.workflowKey,
                    packageId: input.context.packageId,
                    actionKey: AVACoreTypes.ACTION_FORM_RECOGNISED_STATE,
                    roleKey: input.context.roleKey,
                    stage: input.context.stage,
                    objectTypeKey: input.context.objectTypeKey,
                    targetId: input.context.governedObjectId,
                    targetSubjectId: input.context.subjectId,
                    authorityId: input.context.authorityId,
                    decisionHash: _formationDecisionHash(input),
                    actor: input.context.actor
                })
            );
        _validateOptionalFormationPolicies(modules, input);
    }

    function validateTransition(TransitionPolicyInput calldata input) external view {
        WorkflowModules memory modules =
            _loadModules(input.context.packageId, input.context.appId, input.context.workflowKey);
        AVAEvidenceRegistry.EvidenceReference memory evidence = _requireEvidence(
            input.context.appId,
            input.context.workflowKey,
            input.context.packageId,
            input.context.subjectId,
            input.evidenceId,
            input.disclosurePolicyId,
            input.allowInactiveEvidence
        );
        _requireDecisionEvidence(input, modules.rulePackage);
        modules.application.validateRecognisedStateTransition(input.context);
        modules.transitionRule.validateTransition(input.context);

        IAVAApplicationModule.EvidenceUseContext memory evidenceUse = _transitionEvidenceUse(input, evidence);
        modules.evidencePolicy.validateEvidenceUse(evidenceUse);
        modules.evidenceLifecycle.validateEvidenceUse(evidenceUse);
        modules.disclosurePolicy.validateDisclosure(_transitionDisclosure(input, evidence));
        bytes32 decisionHash = input.decisionHash == bytes32(0) ? _transitionDecisionHash(input) : input.decisionHash;
        modules.authorityPolicy
            .validateAuthority(
                IAVAAuthorityPolicyModule.AuthorityContext({
                    appId: input.context.appId,
                    workflowKey: input.context.workflowKey,
                    packageId: input.context.packageId,
                    actionKey: input.actionKey,
                    roleKey: input.context.roleKey,
                    stage: input.context.stage,
                    objectTypeKey: input.context.objectTypeKey,
                    targetId: input.sourceRecordId == 0 ? input.context.recognisedStateId : input.sourceRecordId,
                    targetSubjectId: input.context.subjectId,
                    authorityId: input.context.authorityId,
                    decisionHash: decisionHash,
                    actor: input.context.actor
                })
            );
        _validateOptionalTransitionPolicies(modules, input);
    }

    function computeFormationDecisionHash(FormationPolicyInput calldata input) external pure returns (bytes32) {
        return _formationDecisionHash(input);
    }

    function computeTransitionDecisionHash(TransitionPolicyInput calldata input) external pure returns (bytes32) {
        return input.decisionHash == bytes32(0) ? _transitionDecisionHash(input) : input.decisionHash;
    }

    function validateChallengePolicies(ChallengePolicyInput calldata input) external view {
        ChallengeModules memory modules = _loadChallengeModules(input.packageId, input.appId, input.workflowKey);
        modules.challengePolicy
            .validateChallenge(
                IAVAChallengePolicyModule.ChallengeContext({
                    appId: input.appId,
                    workflowKey: input.workflowKey,
                    packageId: input.packageId,
                    actionKey: input.actionKey,
                    roleKey: input.roleKey,
                    challengeId: input.challengeId,
                    recognisedStateId: input.recognisedStateId,
                    actorSubjectId: input.actorSubjectId,
                    targetSubjectId: input.targetSubjectId,
                    outcomeKey: input.outcomeKey,
                    targetStatus: input.targetStatus,
                    authorityId: input.authorityId,
                    actor: input.actor
                })
            );
        if (input.validateDisclosure) _validateChallengeDisclosure(modules.disclosurePolicy, input);
        if (input.validateAuthority) {
            if (input.decisionHash == bytes32(0)) revert AVACoreTypes.EmptyValue();
            modules.authorityPolicy
                .validateAuthority(
                    IAVAAuthorityPolicyModule.AuthorityContext({
                        appId: input.appId,
                        workflowKey: input.workflowKey,
                        packageId: input.packageId,
                        actionKey: input.actionKey,
                        roleKey: input.roleKey,
                        stage: input.stage,
                        objectTypeKey: input.objectTypeKey,
                        targetId: input.challengeId == 0 ? input.recognisedStateId : input.challengeId,
                        targetSubjectId: input.targetSubjectId,
                        authorityId: input.authorityId,
                        decisionHash: input.decisionHash,
                        actor: input.actor
                    })
                );
        }
        if (address(modules.antiAbusePolicy) != address(0)) {
            modules.antiAbusePolicy
                .validateAntiAbuse(
                    IAVAAntiAbusePolicyModule.AntiAbuseContext({
                        appId: input.appId,
                        workflowKey: input.workflowKey,
                        packageId: input.packageId,
                        actionKey: input.actionKey,
                        roleKey: input.roleKey,
                        targetId: input.challengeId == 0 ? input.recognisedStateId : input.challengeId,
                        targetTypeKey: input.objectTypeKey,
                        actorSubjectId: input.actorSubjectId,
                        targetSubjectId: input.targetSubjectId,
                        authorityId: input.authorityId,
                        actor: input.actor
                    })
                );
        }
    }

    function _loadModules(uint256 packageId, bytes32 appId, bytes32 workflowKey)
        private
        view
        returns (WorkflowModules memory modules)
    {
        (
            AVACoreRulePackageRegistry.VerifiedPackageContext memory packageContext,
            AVACoreRulePackageRegistry.WorkflowPolicyModules memory addresses
        ) = RULE_PACKAGE_REGISTRY.getVerifiedWorkflowPolicyModules(packageId);
        if (packageContext.appId != appId || packageContext.workflowKey != workflowKey) {
            revert AVACoreTypes.InvalidState(packageId);
        }
        modules = WorkflowModules({
            rulePackage: packageContext,
            application: IAVAApplicationModule(addresses.application),
            verification: IAVAVerificationModule(addresses.verification),
            transitionRule: IAVATransitionRuleModule(addresses.transitionRule),
            evidencePolicy: IAVAEvidencePolicyModule(addresses.evidencePolicy),
            evidenceLifecycle: IAVAEvidenceLifecycleModule(addresses.evidenceLifecycle),
            disclosurePolicy: IAVADisclosurePolicyModule(addresses.disclosurePolicy),
            authorityPolicy: IAVAAuthorityPolicyModule(addresses.authorityPolicy),
            fieldPolicy: IAVAFieldPolicyModule(addresses.fieldPolicy),
            antiAbusePolicy: IAVAAntiAbusePolicyModule(addresses.antiAbusePolicy)
        });
    }

    function _requireDecisionEvidence(
        TransitionPolicyInput calldata input,
        AVACoreRulePackageRegistry.VerifiedPackageContext memory targetPackage
    ) private view {
        if (input.decisionPackageId == 0 || input.decisionEvidenceId == 0) {
            revert AVACoreTypes.EmptyValue();
        }
        AVACoreRulePackageRegistry.VerifiedPackageContext memory decisionPackage = targetPackage;
        if (input.decisionPackageId != targetPackage.packageId) {
            decisionPackage = RULE_PACKAGE_REGISTRY.getVerifiedPackageContext(input.decisionPackageId);
        }
        if (
            decisionPackage.packageId != input.decisionPackageId || decisionPackage.appId != targetPackage.appId
                || decisionPackage.compatibilityKey != targetPackage.compatibilityKey
        ) revert AVACoreTypes.InvalidState(input.decisionPackageId);

        if (
            input.decisionPackageId == targetPackage.packageId && input.decisionEvidenceId == input.evidenceId
                && !input.allowInactiveEvidence
        ) return;

        (bytes32 evidenceAppId, bytes32 evidenceWorkflowKey, uint256 evidencePackageId,,) = EVIDENCE_REGISTRY.requireUsableEvidenceReferenceForPackage(
            input.decisionEvidenceId, input.decisionPackageId
        );
        if (
            evidenceAppId != decisionPackage.appId || evidenceWorkflowKey != decisionPackage.workflowKey
                || evidencePackageId != decisionPackage.packageId
        ) revert AVACoreTypes.InvalidState(input.decisionEvidenceId);
    }

    function _loadChallengeModules(uint256 packageId, bytes32 appId, bytes32 workflowKey)
        private
        view
        returns (ChallengeModules memory modules)
    {
        (
            AVACoreRulePackageRegistry.VerifiedPackageContext memory packageContext,
            AVACoreRulePackageRegistry.ChallengePolicyModules memory addresses
        ) = RULE_PACKAGE_REGISTRY.getVerifiedChallengePolicyModules(packageId);
        if (
            packageContext.appId != appId || packageContext.workflowKey != workflowKey
                || addresses.challengePolicy == address(0) || addresses.disclosurePolicy == address(0)
                || addresses.authorityPolicy == address(0)
        ) revert AVACoreTypes.InvalidState(packageId);
        modules = ChallengeModules({
            challengePolicy: IAVAChallengePolicyModule(addresses.challengePolicy),
            disclosurePolicy: IAVADisclosurePolicyModule(addresses.disclosurePolicy),
            authorityPolicy: IAVAAuthorityPolicyModule(addresses.authorityPolicy),
            antiAbusePolicy: IAVAAntiAbusePolicyModule(addresses.antiAbusePolicy)
        });
    }

    function _validateChallengeDisclosure(
        IAVADisclosurePolicyModule disclosurePolicy,
        ChallengePolicyInput calldata input
    ) private view {
        AVAEvidenceRegistry.EvidenceReference memory evidence = EVIDENCE_REGISTRY.getEvidenceReference(input.evidenceId);
        if (
            evidence.appId != input.appId || evidence.workflowKey != input.workflowKey
                || evidence.packageId != input.packageId || evidence.subjectId != input.actorSubjectId
                || evidence.disclosurePolicyId != input.disclosurePolicyId
        ) revert AVACoreTypes.InvalidState(input.evidenceId);
        disclosurePolicy.validateDisclosure(
            IAVADisclosurePolicyModule.DisclosureContext({
                appId: input.appId,
                workflowKey: input.workflowKey,
                packageId: input.packageId,
                actionKey: input.actionKey,
                roleKey: input.roleKey,
                stage: input.stage,
                objectTypeKey: input.objectTypeKey,
                subjectId: input.actorSubjectId,
                disclosurePolicyId: input.disclosurePolicyId,
                targetId: input.recognisedStateId,
                evidenceId: input.evidenceId,
                evidenceTypeHash: evidence.evidenceTypeHash,
                authorityId: input.authorityId,
                actor: input.actor
            })
        );
    }

    function _requireEvidence(
        bytes32 appId,
        bytes32 workflowKey,
        uint256 packageId,
        bytes32 subjectId,
        uint256 evidenceId,
        uint256 disclosurePolicyId,
        bool allowInactiveEvidence
    ) private view returns (AVAEvidenceRegistry.EvidenceReference memory evidence) {
        evidence = EVIDENCE_REGISTRY.getEvidenceReference(evidenceId);
        if (
            (!allowInactiveEvidence && evidence.status != AVACoreTypes.EvidenceStatus.Active) || evidence.appId != appId
                || evidence.workflowKey != workflowKey || evidence.packageId != packageId
                || evidence.subjectId != subjectId || evidence.disclosurePolicyId != disclosurePolicyId
        ) revert AVACoreTypes.InvalidState(evidenceId);
        DISCLOSURE_REGISTRY.requireActivePolicyReference(disclosurePolicyId, appId);
    }

    function _formationEvidenceUse(
        FormationPolicyInput calldata input,
        AVAEvidenceRegistry.EvidenceReference memory evidence
    ) private pure returns (IAVAApplicationModule.EvidenceUseContext memory) {
        return IAVAApplicationModule.EvidenceUseContext({
            appId: input.context.appId,
            workflowKey: input.context.workflowKey,
            packageId: input.context.packageId,
            actionKey: AVACoreTypes.ACTION_FORM_RECOGNISED_STATE,
            roleKey: input.context.roleKey,
            stage: input.context.stage,
            targetId: input.context.governedObjectId,
            objectTypeKey: input.context.objectTypeKey,
            subjectId: input.context.subjectId,
            evidenceId: input.evidenceId,
            evidenceTypeHash: evidence.evidenceTypeHash,
            disclosurePolicyId: input.disclosurePolicyId,
            evidenceStatus: evidence.status,
            authorityId: input.context.authorityId,
            actor: input.context.actor
        });
    }

    function _transitionEvidenceUse(
        TransitionPolicyInput calldata input,
        AVAEvidenceRegistry.EvidenceReference memory evidence
    ) private pure returns (IAVAApplicationModule.EvidenceUseContext memory) {
        return IAVAApplicationModule.EvidenceUseContext({
            appId: input.context.appId,
            workflowKey: input.context.workflowKey,
            packageId: input.context.packageId,
            actionKey: input.actionKey,
            roleKey: input.context.roleKey,
            stage: input.context.stage,
            targetId: input.disclosureTargetId == 0 ? input.context.recognisedStateId : input.disclosureTargetId,
            objectTypeKey: input.context.objectTypeKey,
            subjectId: input.context.subjectId,
            evidenceId: input.evidenceId,
            evidenceTypeHash: evidence.evidenceTypeHash,
            disclosurePolicyId: input.disclosurePolicyId,
            evidenceStatus: evidence.status,
            authorityId: input.context.authorityId,
            actor: input.context.actor
        });
    }

    function _formationDisclosure(
        FormationPolicyInput calldata input,
        AVAEvidenceRegistry.EvidenceReference memory evidence
    ) private pure returns (IAVADisclosurePolicyModule.DisclosureContext memory) {
        return IAVADisclosurePolicyModule.DisclosureContext({
            appId: input.context.appId,
            workflowKey: input.context.workflowKey,
            packageId: input.context.packageId,
            actionKey: AVACoreTypes.ACTION_FORM_RECOGNISED_STATE,
            roleKey: input.context.roleKey,
            stage: input.context.stage,
            objectTypeKey: input.context.objectTypeKey,
            subjectId: input.context.subjectId,
            disclosurePolicyId: input.disclosurePolicyId,
            targetId: input.context.governedObjectId,
            evidenceId: input.evidenceId,
            evidenceTypeHash: evidence.evidenceTypeHash,
            authorityId: input.context.authorityId,
            actor: input.context.actor
        });
    }

    function _transitionDisclosure(
        TransitionPolicyInput calldata input,
        AVAEvidenceRegistry.EvidenceReference memory evidence
    ) private pure returns (IAVADisclosurePolicyModule.DisclosureContext memory) {
        return IAVADisclosurePolicyModule.DisclosureContext({
            appId: input.context.appId,
            workflowKey: input.context.workflowKey,
            packageId: input.context.packageId,
            actionKey: input.actionKey,
            roleKey: input.context.roleKey,
            stage: input.context.stage,
            objectTypeKey: input.context.objectTypeKey,
            subjectId: input.context.subjectId,
            disclosurePolicyId: input.disclosurePolicyId,
            targetId: input.disclosureTargetId == 0 ? input.context.recognisedStateId : input.disclosureTargetId,
            evidenceId: input.evidenceId,
            evidenceTypeHash: evidence.evidenceTypeHash,
            authorityId: input.context.authorityId,
            actor: input.context.actor
        });
    }

    function _validateOptionalFormationPolicies(WorkflowModules memory modules, FormationPolicyInput calldata input)
        private
        view
    {
        if (address(modules.fieldPolicy) != address(0)) {
            modules.fieldPolicy
                .validateFieldPolicy(
                    IAVAFieldPolicyModule.FieldPolicyContext({
                        appId: input.context.appId,
                        workflowKey: input.context.workflowKey,
                        packageId: input.context.packageId,
                        actionKey: AVACoreTypes.ACTION_FORM_RECOGNISED_STATE,
                        roleKey: input.context.roleKey,
                        stage: input.context.stage,
                        targetId: input.context.governedObjectId,
                        objectTypeKey: input.context.objectTypeKey,
                        subjectId: input.context.subjectId,
                        evidenceId: input.evidenceId,
                        authorityId: input.context.authorityId,
                        actor: input.context.actor
                    })
                );
        }
        if (address(modules.antiAbusePolicy) != address(0)) {
            modules.antiAbusePolicy
                .validateAntiAbuse(
                    IAVAAntiAbusePolicyModule.AntiAbuseContext({
                        appId: input.context.appId,
                        workflowKey: input.context.workflowKey,
                        packageId: input.context.packageId,
                        actionKey: AVACoreTypes.ACTION_FORM_RECOGNISED_STATE,
                        roleKey: input.context.roleKey,
                        targetId: input.context.governedObjectId,
                        targetTypeKey: input.context.objectTypeKey,
                        actorSubjectId: input.context.authorityId,
                        targetSubjectId: input.context.subjectId,
                        authorityId: input.context.authorityId,
                        actor: input.context.actor
                    })
                );
        }
    }

    function _validateOptionalTransitionPolicies(WorkflowModules memory modules, TransitionPolicyInput calldata input)
        private
        view
    {
        bytes32 actionKey = input.actionKey;
        if (address(modules.fieldPolicy) != address(0)) {
            modules.fieldPolicy
                .validateFieldPolicy(
                    IAVAFieldPolicyModule.FieldPolicyContext({
                        appId: input.context.appId,
                        workflowKey: input.context.workflowKey,
                        packageId: input.context.packageId,
                        actionKey: actionKey,
                        roleKey: input.context.roleKey,
                        stage: input.context.stage,
                        targetId: input.context.recognisedStateId,
                        objectTypeKey: input.context.objectTypeKey,
                        subjectId: input.context.subjectId,
                        evidenceId: input.evidenceId,
                        authorityId: input.context.authorityId,
                        actor: input.context.actor
                    })
                );
        }
        if (address(modules.antiAbusePolicy) != address(0)) {
            modules.antiAbusePolicy
                .validateAntiAbuse(
                    IAVAAntiAbusePolicyModule.AntiAbuseContext({
                        appId: input.context.appId,
                        workflowKey: input.context.workflowKey,
                        packageId: input.context.packageId,
                        actionKey: actionKey,
                        roleKey: input.context.roleKey,
                        targetId: input.context.recognisedStateId,
                        targetTypeKey: input.context.objectTypeKey,
                        actorSubjectId: input.context.authorityId,
                        targetSubjectId: input.context.subjectId,
                        authorityId: input.context.authorityId,
                        actor: input.context.actor
                    })
                );
        }
    }

    function _formationDecisionHash(FormationPolicyInput calldata input) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                FORMATION_DECISION_DOMAIN,
                input.context.appId,
                input.context.workflowKey,
                input.context.packageId,
                input.context.roleKey,
                input.context.governedObjectId,
                input.context.objectTypeKey,
                input.context.subjectId,
                input.context.stage,
                input.context.status,
                input.evidenceId,
                input.disclosurePolicyId,
                input.context.authorityId,
                input.reasonHash
            )
        );
    }

    function _transitionDecisionHash(TransitionPolicyInput calldata input) private pure returns (bytes32) {
        bytes32 targetHash = keccak256(
            abi.encode(
                input.context.appId,
                input.context.workflowKey,
                input.context.packageId,
                input.actionKey,
                input.context.roleKey,
                input.context.recognisedStateId,
                input.context.governedObjectId,
                input.context.objectTypeKey,
                input.context.subjectId,
                input.context.stage,
                input.context.fromStatus,
                input.context.toStatus,
                input.context.transitionKind
            )
        );
        bytes32 sourceHash = keccak256(
            abi.encode(
                input.targetVersionId,
                input.decisionPackageId,
                input.decisionEvidenceId,
                input.sourceRecordId,
                input.disclosureTargetId,
                input.evidenceId,
                input.disclosurePolicyId,
                input.context.authorityId,
                input.reasonHash
            )
        );
        return keccak256(abi.encode(TRANSITION_DECISION_DOMAIN, targetHash, sourceHash));
    }
}
