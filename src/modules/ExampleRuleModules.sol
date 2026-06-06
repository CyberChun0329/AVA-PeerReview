// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";
import {IAttributionModule} from "../interfaces/IAttributionModule.sol";
import {IVerificationModule} from "../interfaces/IVerificationModule.sol";
import {ITransitionRuleModule} from "../interfaces/ITransitionRuleModule.sol";
import {IChallengeLifecycleModule} from "../interfaces/IChallengeLifecycleModule.sol";
import {IEvidencePolicyModule} from "../interfaces/IEvidencePolicyModule.sol";
import {IAuditAdapter} from "../interfaces/IAuditAdapter.sol";
import {IEditorialSystemAdapter} from "../interfaces/IEditorialSystemAdapter.sol";
import {IResidualEditorialAuthorityModule} from "../interfaces/IResidualEditorialAuthorityModule.sol";
import {IFieldPolicyModule} from "../interfaces/IFieldPolicyModule.sol";
import {IAntiAbuseModule} from "../interfaces/IAntiAbuseModule.sol";

contract SubjectSaltAttributionModule is IAttributionModule {
    function validateAttribution(
        bytes32 workflowKey,
        AVADataTypes.Role,
        AVADataTypes.AVAStage,
        bytes32 objectId,
        bytes32 subjectId,
        uint256 evidenceReceiptId
    ) external pure returns (bytes32 attributedObjectId) {
        if (workflowKey == bytes32(0) || objectId == bytes32(0) || subjectId == bytes32(0) || evidenceReceiptId == 0) {
            revert AVADataTypes.EmptyValue();
        }
        return keccak256(abi.encode(workflowKey, objectId, subjectId));
    }
}

contract EvidenceThresholdVerificationModule is IVerificationModule {
    uint256 public immutable minimumEvidenceReceiptId;

    constructor(uint256 minimumEvidenceReceiptId_) {
        minimumEvidenceReceiptId = minimumEvidenceReceiptId_;
    }

    function validateVerification(
        bytes32 workflowKey,
        AVADataTypes.Role,
        AVADataTypes.AVAStage,
        bytes32 objectId,
        uint256 evidenceReceiptId
    ) external view {
        if (workflowKey == bytes32(0) || objectId == bytes32(0) || evidenceReceiptId < minimumEvidenceReceiptId) {
            revert AVADataTypes.InvalidState(evidenceReceiptId);
        }
    }
}

contract NoFrozenTransitionRuleModule is ITransitionRuleModule {
    function validateTransition(
        bytes32 workflowKey,
        AVADataTypes.Action,
        AVADataTypes.RecognisedStateStatus fromStatus,
        AVADataTypes.RecognisedStateStatus toStatus,
        AVADataTypes.ChallengeOutcome
    ) external pure {
        if (workflowKey == bytes32(0) || fromStatus == AVADataTypes.RecognisedStateStatus.None) {
            revert AVADataTypes.EmptyValue();
        }
        if (toStatus == AVADataTypes.RecognisedStateStatus.Frozen) revert AVADataTypes.InvalidState(uint256(toStatus));
    }
}

contract PanelOnlyChallengeLifecycleModule is IChallengeLifecycleModule {
    function validateChallengeAction(ChallengeLifecycleContext calldata context) external pure {
        if (context.workflowKey == bytes32(0)) revert AVADataTypes.EmptyValue();
        if (
            context.action == AVADataTypes.Action.ResolveChallenge
                || context.action == AVADataTypes.Action.ApplyRestoration
                || context.action == AVADataTypes.Action.CloseChallenge
        ) {
            if (context.actor == context.filedBy) revert AVADataTypes.InvalidState(uint256(context.action));
        }
    }
}

contract TypedEvidencePolicyModule is IEvidencePolicyModule {
    bytes32 public immutable requiredEvidenceTypeHash;

    constructor(bytes32 requiredEvidenceTypeHash_) {
        if (requiredEvidenceTypeHash_ == bytes32(0)) revert AVADataTypes.EmptyValue();
        requiredEvidenceTypeHash = requiredEvidenceTypeHash_;
    }

    function validateEvidencePolicy(
        bytes32 workflowKey,
        AVADataTypes.Role,
        AVADataTypes.Action,
        uint256 evidenceReceiptId,
        bytes32 evidenceTypeHash,
        address
    ) external view {
        if (workflowKey == bytes32(0) || evidenceReceiptId == 0) revert AVADataTypes.EmptyValue();
        if (evidenceTypeHash != bytes32(0) && evidenceTypeHash != requiredEvidenceTypeHash) {
            revert AVADataTypes.InvalidState(evidenceReceiptId);
        }
    }
}

contract HashAnchoredAuditAdapter is IAuditAdapter {
    function validateAuditRecord(
        bytes32 workflowKey,
        AVADataTypes.Role,
        AVADataTypes.Action,
        bytes32 objectId,
        uint256 evidenceReceiptId,
        bytes32 attestationHash,
        address actor
    ) external pure {
        if (
            workflowKey == bytes32(0) || objectId == bytes32(0) || evidenceReceiptId == 0
                || attestationHash == bytes32(0) || actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
    }
}

contract EditorialReferenceAdapter is IEditorialSystemAdapter {
    function validateEditorialReference(
        bytes32 workflowKey,
        AVADataTypes.Role actingRole,
        AVADataTypes.Action,
        bytes32 objectId,
        string calldata externalReferenceURI,
        address actor
    ) external pure {
        if (workflowKey == bytes32(0) || objectId == bytes32(0) || actor == address(0)) {
            revert AVADataTypes.EmptyValue();
        }
        if (actingRole != AVADataTypes.Role.Editor && actingRole != AVADataTypes.Role.Panel) {
            revert AVADataTypes.InvalidRole();
        }
        if (bytes(externalReferenceURI).length == 0) revert AVADataTypes.EmptyValue();
    }
}

contract ProceduralEditorialAuthorityModule is IResidualEditorialAuthorityModule {
    AVADataTypes.Action public immutable allowedAction;

    constructor(AVADataTypes.Action allowedAction_) {
        allowedAction = allowedAction_;
    }

    function validateResidualEditorialAuthority(ResidualEditorialAuthorityContext calldata context) external view {
        if (
            context.workflowKey == bytes32(0) || context.objectId == bytes32(0) || context.evidenceReceiptId == 0
                || context.authorityId == bytes32(0) || context.actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
        if (context.action != allowedAction) revert AVADataTypes.InvalidState(uint256(context.action));
        if (context.actingRole != AVADataTypes.Role.Editor && context.actingRole != AVADataTypes.Role.Panel) {
            revert AVADataTypes.InvalidRole();
        }
    }
}

contract StructuredResidualEditorialAuthorityModule is IResidualEditorialAuthorityModule {
    enum PolicyKind {
        SingleRole,
        ThresholdPanel,
        Multisig,
        InstitutionalCoSignature,
        ConflictExcludedPanel,
        EmergencyPause
    }

    PolicyKind public immutable POLICY_KIND;
    AVADataTypes.Role public immutable REQUIRED_ROLE;
    AVADataTypes.Action public immutable REQUIRED_ACTION;
    bytes32 public immutable PRIMARY_AUTHORITY_ID;
    bytes32 public immutable SUPPORTING_AUTHORITY_ID;
    uint8 public immutable REQUIRED_THRESHOLD;
    uint8 public immutable OBSERVED_APPROVAL_COUNT;
    bool public immutable EMERGENCY_WINDOW_OPEN;

    constructor(
        PolicyKind policyKind_,
        AVADataTypes.Role requiredRole_,
        AVADataTypes.Action requiredAction_,
        bytes32 primaryAuthorityId_,
        bytes32 supportingAuthorityId_,
        uint8 requiredThreshold_,
        uint8 observedApprovalCount_,
        bool emergencyWindowOpen_
    ) {
        POLICY_KIND = policyKind_;
        REQUIRED_ROLE = requiredRole_;
        REQUIRED_ACTION = requiredAction_;
        PRIMARY_AUTHORITY_ID = primaryAuthorityId_;
        SUPPORTING_AUTHORITY_ID = supportingAuthorityId_;
        REQUIRED_THRESHOLD = requiredThreshold_;
        OBSERVED_APPROVAL_COUNT = observedApprovalCount_;
        EMERGENCY_WINDOW_OPEN = emergencyWindowOpen_;
    }

    function validateResidualEditorialAuthority(ResidualEditorialAuthorityContext calldata context) external view {
        if (
            context.workflowKey == bytes32(0) || context.objectId == bytes32(0) || context.evidenceReceiptId == 0
                || context.authorityId == bytes32(0) || context.actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
        if (context.actingRole != REQUIRED_ROLE) revert AVADataTypes.InvalidRole();
        if (context.action != REQUIRED_ACTION) revert AVADataTypes.InvalidState(uint256(context.action));

        if (POLICY_KIND == PolicyKind.SingleRole) {
            _requirePrimaryAuthority(context.authorityId);
            return;
        }
        if (POLICY_KIND == PolicyKind.ThresholdPanel) {
            _requirePrimaryAuthority(context.authorityId);
            if (
                context.actingRole != AVADataTypes.Role.Panel || REQUIRED_THRESHOLD == 0
                    || OBSERVED_APPROVAL_COUNT < REQUIRED_THRESHOLD
            ) {
                revert AVADataTypes.InvalidState(uint256(context.action));
            }
            return;
        }
        if (POLICY_KIND == PolicyKind.Multisig) {
            _requirePrimaryAuthority(context.authorityId);
            if (SUPPORTING_AUTHORITY_ID == bytes32(0) || OBSERVED_APPROVAL_COUNT < 2) {
                revert AVADataTypes.InvalidState(uint256(context.action));
            }
            return;
        }
        if (POLICY_KIND == PolicyKind.InstitutionalCoSignature) {
            _requirePrimaryAuthority(context.authorityId);
            if (SUPPORTING_AUTHORITY_ID == bytes32(0)) revert AVADataTypes.EmptyValue();
            return;
        }
        if (POLICY_KIND == PolicyKind.ConflictExcludedPanel) {
            if (
                context.actingRole != AVADataTypes.Role.Panel || SUPPORTING_AUTHORITY_ID == bytes32(0)
                    || context.authorityId == SUPPORTING_AUTHORITY_ID
            ) {
                revert AVADataTypes.InvalidState(uint256(context.action));
            }
            return;
        }
        if (POLICY_KIND == PolicyKind.EmergencyPause) {
            _requirePrimaryAuthority(context.authorityId);
            if (!EMERGENCY_WINDOW_OPEN) revert AVADataTypes.InvalidState(uint256(context.action));
            return;
        }
    }

    function _requirePrimaryAuthority(bytes32 authorityId) internal view {
        if (PRIMARY_AUTHORITY_ID == bytes32(0) || authorityId != PRIMARY_AUTHORITY_ID) {
            revert AVADataTypes.InvalidState(uint256(authorityId));
        }
    }
}

contract DisciplineFieldPolicyModule is IFieldPolicyModule {
    AVADataTypes.AVAStage public immutable requiredStage;

    constructor(AVADataTypes.AVAStage requiredStage_) {
        requiredStage = requiredStage_;
    }

    function validateFieldPolicy(
        bytes32 workflowKey,
        AVADataTypes.Role,
        AVADataTypes.Action,
        AVADataTypes.AVAStage stage,
        bytes32 objectId,
        uint256 evidenceReceiptId
    ) external view {
        if (workflowKey == bytes32(0) || objectId == bytes32(0) || evidenceReceiptId == 0) {
            revert AVADataTypes.EmptyValue();
        }
        if (stage != requiredStage) revert AVADataTypes.InvalidState(uint256(stage));
    }
}

contract SubjectRateLimitModule is IAntiAbuseModule {
    function validateUse(
        bytes32 workflowKey,
        AVADataTypes.Role,
        AVADataTypes.Action,
        bytes32 subjectId,
        bytes32 objectId,
        address actor
    ) external pure {
        if (workflowKey == bytes32(0) || subjectId == bytes32(0) || objectId == bytes32(0) || actor == address(0)) {
            revert AVADataTypes.EmptyValue();
        }
        if (subjectId == objectId) revert AVADataTypes.InvalidState(uint256(subjectId));
    }
}
