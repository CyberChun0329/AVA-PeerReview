// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "./AVADataTypes.sol";
import {AVARulePackageRegistry} from "./AVARulePackageRegistry.sol";
import {EvidenceCommitmentRegistry} from "./EvidenceCommitmentRegistry.sol";
import {DisclosurePolicyRegistry} from "./DisclosurePolicyRegistry.sol";
import {IAttributionModule} from "./interfaces/IAttributionModule.sol";
import {IVerificationModule} from "./interfaces/IVerificationModule.sol";
import {IChallengeLifecycleModule} from "./interfaces/IChallengeLifecycleModule.sol";
import {IAntiAbuseModule} from "./interfaces/IAntiAbuseModule.sol";
import {IResidualEditorialAuthorityModule} from "./interfaces/IResidualEditorialAuthorityModule.sol";

/// @notice Shared, read-only rule-package validation for AVA workflow objects.
contract AVAWorkflowValidator {
    struct WorkflowValidationContext {
        bytes32 appId;
        bytes32 workflowKey;
        AVADataTypes.Role actingRole;
        AVADataTypes.Action action;
        AVADataTypes.AVAStage stage;
        bytes32 objectId;
        bytes32 subjectId;
        uint256 evidenceReceiptId;
        uint256 disclosurePolicyId;
        address actor;
    }

    struct WorkflowValidationResult {
        bytes32 attributedObjectId;
        uint256 packageId;
        IChallengeLifecycleModule challengeLifecycleModule;
        IAntiAbuseModule antiAbuseModule;
        IResidualEditorialAuthorityModule residualEditorialAuthorityModule;
    }

    AVARulePackageRegistry public immutable RULE_PACKAGE_REGISTRY;
    EvidenceCommitmentRegistry public immutable EVIDENCE_REGISTRY;
    DisclosurePolicyRegistry public immutable DISCLOSURE_REGISTRY;

    constructor(
        AVARulePackageRegistry rulePackageRegistry_,
        EvidenceCommitmentRegistry evidenceRegistry_,
        DisclosurePolicyRegistry disclosureRegistry_
    ) {
        if (address(disclosureRegistry_) == address(0)) {
            revert AVADataTypes.EmptyValue();
        }
        RULE_PACKAGE_REGISTRY = rulePackageRegistry_;
        EVIDENCE_REGISTRY = evidenceRegistry_;
        DISCLOSURE_REGISTRY = disclosureRegistry_;
    }

    function validateActivePackage(WorkflowValidationContext calldata context)
        external
        view
        returns (WorkflowValidationResult memory result)
    {
        AVARulePackageRegistry.RulePackage memory rulePackage =
            RULE_PACKAGE_REGISTRY.getRulePackage(context.appId, context.workflowKey);
        return _validate(context, rulePackage);
    }

    function validatePackage(WorkflowValidationContext calldata context, uint256 packageId)
        external
        view
        returns (WorkflowValidationResult memory result)
    {
        AVARulePackageRegistry.RulePackage memory rulePackage = RULE_PACKAGE_REGISTRY.getRulePackageById(packageId);
        if (rulePackage.appId != context.appId || rulePackage.workflowKey != context.workflowKey) {
            revert AVADataTypes.InvalidState(packageId);
        }
        return _validate(context, rulePackage);
    }

    function requireCompatibleRulePackages(
        bytes32 challengeWorkflowKey,
        uint256 challengePackageId,
        bytes32 targetWorkflowKey,
        uint256 targetPackageId
    ) external view {
        AVARulePackageRegistry.RulePackage memory challengePackage =
            RULE_PACKAGE_REGISTRY.getRulePackageById(challengePackageId);
        AVARulePackageRegistry.RulePackage memory targetPackage =
            RULE_PACKAGE_REGISTRY.getRulePackageById(targetPackageId);
        if (
            challengePackage.workflowKey != challengeWorkflowKey || targetPackage.workflowKey != targetWorkflowKey
                || challengePackage.appId != targetPackage.appId
                || challengePackage.compatibilityKey != targetPackage.compatibilityKey
        ) {
            revert AVADataTypes.InvalidState(targetPackageId);
        }
    }

    function validateTargetResidualAuthority(
        bytes32 challengeWorkflowKey,
        uint256 challengePackageId,
        IResidualEditorialAuthorityModule.ResidualEditorialAuthorityContext calldata context
    ) external view {
        AVARulePackageRegistry.RulePackage memory
            challengePackage = RULE_PACKAGE_REGISTRY.getRulePackageById(challengePackageId);
        AVARulePackageRegistry.RulePackage memory targetPackage =
            RULE_PACKAGE_REGISTRY.getRulePackageById(context.packageId);
        if (
            challengePackage.workflowKey != challengeWorkflowKey || targetPackage.workflowKey != context.workflowKey
                || challengePackage.appId != targetPackage.appId
                || challengePackage.compatibilityKey != targetPackage.compatibilityKey
        ) {
            revert AVADataTypes.InvalidState(context.packageId);
        }
        targetPackage.residualEditorialAuthorityModule.validateResidualEditorialAuthority(context);
    }

    function requireUsablePinnedEvidenceReceipt(
        bytes32 appId,
        bytes32 workflowKey,
        uint256 packageId,
        uint256 evidenceReceiptId
    ) external view {
        AVADataTypes.EvidenceReceipt memory receipt =
            EVIDENCE_REGISTRY.requireUsableEvidenceReceipt(evidenceReceiptId, appId, workflowKey);
        if (receipt.packageId != packageId) revert AVADataTypes.InvalidState(evidenceReceiptId);
    }

    function requirePinnedEvidenceReceipt(
        bytes32 appId,
        bytes32 workflowKey,
        uint256 packageId,
        uint256 evidenceReceiptId
    ) external view {
        AVADataTypes.EvidenceReceipt memory receipt = EVIDENCE_REGISTRY.getEvidenceReceipt(evidenceReceiptId);
        if (receipt.appId != appId || receipt.workflowKey != workflowKey || receipt.packageId != packageId) {
            revert AVADataTypes.InvalidState(evidenceReceiptId);
        }
    }

    function _validate(
        WorkflowValidationContext calldata context,
        AVARulePackageRegistry.RulePackage memory rulePackage
    ) internal view returns (WorkflowValidationResult memory result) {
        if (context.actor == address(0)) revert AVADataTypes.EmptyValue();
        if (rulePackage.appId != context.appId) revert AVADataTypes.InvalidState(rulePackage.packageId);

        if (context.disclosurePolicyId != 0) {
            AVADataTypes.DisclosurePolicy memory policy =
                DISCLOSURE_REGISTRY.getDisclosurePolicy(context.disclosurePolicyId);
            if (policy.appId != context.appId) revert AVADataTypes.InvalidState(context.disclosurePolicyId);
        }

        bytes32 evidenceTypeHash;
        if (context.evidenceReceiptId != 0) {
            AVADataTypes.EvidenceReceipt memory receipt = EVIDENCE_REGISTRY.requireUsableEvidenceReceipt(
                context.evidenceReceiptId, context.appId, context.workflowKey
            );
            if (receipt.packageId != rulePackage.packageId) {
                revert AVADataTypes.InvalidState(context.evidenceReceiptId);
            }
            evidenceTypeHash = receipt.evidenceTypeHash;
        }

        rulePackage.disclosureModule
            .validateDisclosureForAction(
                context.disclosurePolicyId,
                context.actingRole,
                context.action,
                context.stage,
                context.objectId,
                context.workflowKey,
                rulePackage.packageId,
                context.subjectId
            );
        result.attributedObjectId = rulePackage.attributionModule
            .validateAttribution(
                IAttributionModule.AttributionContext({
                    workflowKey: context.workflowKey,
                    packageId: rulePackage.packageId,
                    actingRole: context.actingRole,
                    action: context.action,
                    stage: context.stage,
                    objectId: context.objectId,
                    subjectId: context.subjectId,
                    evidenceReceiptId: context.evidenceReceiptId,
                    disclosurePolicyId: context.disclosurePolicyId,
                    actor: context.actor
                })
            );
        rulePackage.verificationModule
            .validateVerification(
                IVerificationModule.VerificationContext({
                    workflowKey: context.workflowKey,
                    packageId: rulePackage.packageId,
                    actingRole: context.actingRole,
                    action: context.action,
                    stage: context.stage,
                    objectId: result.attributedObjectId,
                    subjectId: context.subjectId,
                    evidenceReceiptId: context.evidenceReceiptId,
                    disclosurePolicyId: context.disclosurePolicyId,
                    actor: context.actor
                })
            );
        rulePackage.evidencePolicyModule
                .validateEvidencePolicy(
                context.workflowKey,
                context.actingRole,
                context.action,
                context.evidenceReceiptId,
                evidenceTypeHash,
                context.actor
            );
        rulePackage.evidenceLifecycleModule
            .validateEvidenceLifecycle(
                context.workflowKey,
                context.action,
                context.evidenceReceiptId,
                AVADataTypes.EvidenceLifecycleKind.None,
                0,
                bytes32(0),
                context.actor
            );
        rulePackage.fieldPolicyModule
            .validateFieldPolicy(
                context.workflowKey,
                context.actingRole,
                context.action,
                context.stage,
                result.attributedObjectId,
                context.evidenceReceiptId
            );
        rulePackage.antiAbuseModule
            .validateUse(
                context.workflowKey,
                context.actingRole,
                context.action,
                context.subjectId,
                result.attributedObjectId,
                context.actor
            );
        result.packageId = rulePackage.packageId;
        result.challengeLifecycleModule = rulePackage.challengeLifecycleModule;
        result.antiAbuseModule = rulePackage.antiAbuseModule;
        result.residualEditorialAuthorityModule = rulePackage.residualEditorialAuthorityModule;
    }
}
