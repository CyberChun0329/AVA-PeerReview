// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RuleModuleIdentity} from "../interfaces/IRuleModuleIdentity.sol";

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
import {IChallengeWindowRuleModule} from "../interfaces/IChallengeWindowRuleModule.sol";
import {IChallengeRateLimitModule} from "../interfaces/IChallengeRateLimitModule.sol";
import {AVAStateMachine} from "../AVAStateMachine.sol";
import {ConsequenceExecutor} from "../ConsequenceExecutor.sol";
import {StandingCredentialRegistry} from "../StandingCredentialRegistry.sol";

contract SubjectSaltAttributionModule is IAttributionModule, RuleModuleIdentity {
    function validateAttribution(AttributionContext calldata context)
        external
        pure
        returns (bytes32 attributedObjectId)
    {
        if (
            context.workflowKey == bytes32(0) || context.packageId == 0 || context.objectId == bytes32(0)
                || context.subjectId == bytes32(0) || context.evidenceReceiptId == 0 || context.actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
        return keccak256(abi.encode(context.packageId, context.action, context.objectId, context.subjectId));
    }
}

contract EvidenceThresholdVerificationModule is IVerificationModule, RuleModuleIdentity {
    uint256 public immutable minimumEvidenceReceiptId;

    constructor(uint256 minimumEvidenceReceiptId_) {
        minimumEvidenceReceiptId = minimumEvidenceReceiptId_;
    }

    function validateVerification(VerificationContext calldata context) external view {
        if (
            context.workflowKey == bytes32(0) || context.packageId == 0 || context.objectId == bytes32(0)
                || context.subjectId == bytes32(0) || context.actor == address(0)
                || context.evidenceReceiptId < minimumEvidenceReceiptId
        ) {
            revert AVADataTypes.InvalidState(context.evidenceReceiptId);
        }
    }
}

contract NoFrozenTransitionRuleModule is ITransitionRuleModule, RuleModuleIdentity {
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

contract MinimumChallengeWindowTransitionModule is
    ITransitionRuleModule,
    IChallengeWindowRuleModule,
    RuleModuleIdentity
{
    uint64 public immutable MINIMUM_DURATION;

    constructor(uint64 minimumDuration_) {
        if (minimumDuration_ == 0) revert AVADataTypes.EmptyValue();
        MINIMUM_DURATION = minimumDuration_;
    }

    function validateTransition(
        bytes32 workflowKey,
        AVADataTypes.Action,
        AVADataTypes.RecognisedStateStatus fromStatus,
        AVADataTypes.RecognisedStateStatus toStatus,
        AVADataTypes.ChallengeOutcome
    ) external pure {
        if (
            workflowKey == bytes32(0) || fromStatus == AVADataTypes.RecognisedStateStatus.None
                || toStatus == AVADataTypes.RecognisedStateStatus.None
        ) {
            revert AVADataTypes.EmptyValue();
        }
    }

    function supportsChallengeWindowRule() external pure returns (bool) {
        return true;
    }

    function validateChallengeWindowDuration(
        bytes32 workflowKey,
        uint256 recognisedStateId,
        uint64 openedAt,
        uint64 currentTime,
        address actor
    ) external view {
        if (workflowKey == bytes32(0) || recognisedStateId == 0 || currentTime == 0 || actor == address(0)) {
            revert AVADataTypes.EmptyValue();
        }
        if (uint256(currentTime) < uint256(openedAt) + uint256(MINIMUM_DURATION)) {
            revert AVADataTypes.InvalidState(recognisedStateId);
        }
    }
}

contract PanelOnlyChallengeLifecycleModule is IChallengeLifecycleModule, RuleModuleIdentity {
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

contract TypedEvidencePolicyModule is IEvidencePolicyModule, RuleModuleIdentity {
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

contract HashAnchoredAuditAdapter is IAuditAdapter, RuleModuleIdentity {
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

contract EditorialReferenceAdapter is IEditorialSystemAdapter, RuleModuleIdentity {
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

contract ProceduralEditorialAuthorityModule is IResidualEditorialAuthorityModule, RuleModuleIdentity {
    AVADataTypes.Action public immutable allowedAction;

    constructor(AVADataTypes.Action allowedAction_) {
        allowedAction = allowedAction_;
    }

    function validateResidualEditorialAuthority(ResidualEditorialAuthorityContext calldata context) external view {
        if (
            context.workflowKey == bytes32(0) || context.packageId == 0 || context.targetPackageId == 0
                || context.objectId == bytes32(0) || context.evidenceReceiptId == 0 || context.authorityId == bytes32(0)
                || context.actor == address(0) || context.decisionHash == bytes32(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
        if (context.action != allowedAction) revert AVADataTypes.InvalidState(uint256(context.action));
        if (context.actingRole != AVADataTypes.Role.Editor && context.actingRole != AVADataTypes.Role.Panel) {
            revert AVADataTypes.InvalidRole();
        }
    }
}

/// @notice Illustrative static validator for authority shapes that need no approval receipts.
/// @dev Threshold, multisig, co-signature, and conflict-exclusion policies must use
/// receipt-backed modules such as `ApprovalReceiptAuthorityModule`; they cannot
/// be represented by constructor-supplied approval counts here.
contract IllustrativeStaticAuthorityShapeModule is IResidualEditorialAuthorityModule, RuleModuleIdentity {
    enum PolicyKind {
        SingleAuthority,
        EmergencyGate
    }

    PolicyKind public immutable POLICY_KIND;
    AVADataTypes.Role public immutable REQUIRED_ROLE;
    AVADataTypes.Action public immutable REQUIRED_ACTION;
    bytes32 public immutable PRIMARY_AUTHORITY_ID;
    bool public immutable EMERGENCY_WINDOW_OPEN;

    constructor(
        PolicyKind policyKind_,
        AVADataTypes.Role requiredRole_,
        AVADataTypes.Action requiredAction_,
        bytes32 primaryAuthorityId_,
        bool emergencyWindowOpen_
    ) {
        if (requiredRole_ == AVADataTypes.Role.None || primaryAuthorityId_ == bytes32(0)) {
            revert AVADataTypes.EmptyValue();
        }
        POLICY_KIND = policyKind_;
        REQUIRED_ROLE = requiredRole_;
        REQUIRED_ACTION = requiredAction_;
        PRIMARY_AUTHORITY_ID = primaryAuthorityId_;
        EMERGENCY_WINDOW_OPEN = emergencyWindowOpen_;
    }

    function validateResidualEditorialAuthority(ResidualEditorialAuthorityContext calldata context) external view {
        if (
            context.workflowKey == bytes32(0) || context.packageId == 0 || context.targetPackageId == 0
                || context.objectId == bytes32(0) || context.evidenceReceiptId == 0 || context.authorityId == bytes32(0)
                || context.actor == address(0) || context.decisionHash == bytes32(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
        if (context.actingRole != REQUIRED_ROLE) revert AVADataTypes.InvalidRole();
        if (context.action != REQUIRED_ACTION) revert AVADataTypes.InvalidState(uint256(context.action));
        _requirePrimaryAuthority(context.authorityId);

        if (POLICY_KIND == PolicyKind.EmergencyGate) {
            if (!EMERGENCY_WINDOW_OPEN) revert AVADataTypes.InvalidState(uint256(context.action));
        }
    }

    function _requirePrimaryAuthority(bytes32 authorityId) internal view {
        if (PRIMARY_AUTHORITY_ID == bytes32(0) || authorityId != PRIMARY_AUTHORITY_ID) {
            revert AVADataTypes.InvalidState(uint256(authorityId));
        }
    }
}

contract DisciplineFieldPolicyModule is IFieldPolicyModule, RuleModuleIdentity {
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

contract SubjectRateLimitModule is IAntiAbuseModule, IChallengeRateLimitModule, RuleModuleIdentity {
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

    function supportsChallengeRateLimit() external pure returns (bool) {
        return true;
    }

    function validateChallengeFiling(
        bytes32 workflowKey,
        uint256 challengedRecognisedStateId,
        bytes32 challengerSubjectId,
        uint256 priorFilingCount,
        address actor
    ) external pure {
        if (
            workflowKey == bytes32(0) || challengedRecognisedStateId == 0 || challengerSubjectId == bytes32(0)
                || actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
        if (priorFilingCount != 0) revert AVADataTypes.InvalidState(challengedRecognisedStateId);
    }
}

contract RestrictionAwareChallengeIntakeModule is IAntiAbuseModule, IChallengeRateLimitModule, RuleModuleIdentity {
    ConsequenceExecutor public immutable CONSEQUENCE_EXECUTOR;
    AVAStateMachine public immutable STATE_MACHINE;

    constructor(ConsequenceExecutor consequenceExecutor_, AVAStateMachine stateMachine_) {
        CONSEQUENCE_EXECUTOR = consequenceExecutor_;
        STATE_MACHINE = stateMachine_;
    }

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
    }

    function supportsChallengeRateLimit() external pure returns (bool) {
        return true;
    }

    function validateChallengeFiling(
        bytes32 workflowKey,
        uint256 challengedRecognisedStateId,
        bytes32 challengerSubjectId,
        uint256,
        address actor
    ) external view {
        if (
            workflowKey == bytes32(0) || challengedRecognisedStateId == 0 || challengerSubjectId == bytes32(0)
                || actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
        AVADataTypes.RecognisedStateRecord memory state = STATE_MACHINE.getRecognisedState(challengedRecognisedStateId);
        if (state.workflowKey != workflowKey) revert AVADataTypes.InvalidState(challengedRecognisedStateId);
        if (
            CONSEQUENCE_EXECUTOR.activeEligibilityRestrictionId(
                    state.packageId, challengerSubjectId, AVADataTypes.EligibilityRestrictionKind.ChallengeIntake
                ) != 0
        ) {
            revert AVADataTypes.InvalidState(challengedRecognisedStateId);
        }
    }
}

contract CredentialGatedPanelModule is IResidualEditorialAuthorityModule, RuleModuleIdentity {
    StandingCredentialRegistry public immutable CREDENTIAL_REGISTRY;
    AVAStateMachine public immutable STATE_MACHINE;
    AVADataTypes.Action public immutable GATED_ACTION;
    bytes32 public immutable VECTOR_KEY;
    bytes32 public immutable CATEGORY_HASH;
    int256 public immutable REQUIRED_THRESHOLD;

    constructor(
        StandingCredentialRegistry credentialRegistry_,
        AVAStateMachine stateMachine_,
        AVADataTypes.Action gatedAction_,
        bytes32 vectorKey_,
        bytes32 categoryHash_,
        int256 requiredThreshold_
    ) {
        if (vectorKey_ == bytes32(0) || categoryHash_ == bytes32(0)) {
            revert AVADataTypes.EmptyValue();
        }
        CREDENTIAL_REGISTRY = credentialRegistry_;
        STATE_MACHINE = stateMachine_;
        GATED_ACTION = gatedAction_;
        VECTOR_KEY = vectorKey_;
        CATEGORY_HASH = categoryHash_;
        REQUIRED_THRESHOLD = requiredThreshold_;
    }

    function validateResidualEditorialAuthority(ResidualEditorialAuthorityContext calldata context) external view {
        if (
            context.workflowKey == bytes32(0) || context.packageId == 0 || context.targetPackageId == 0
                || context.objectId == bytes32(0) || context.evidenceReceiptId == 0 || context.authorityId == bytes32(0)
                || context.actor == address(0) || context.decisionHash == bytes32(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
        if (context.action != GATED_ACTION) return;
        if (context.actingRole != AVADataTypes.Role.Panel) revert AVADataTypes.InvalidRole();

        AVADataTypes.RecognisedStateRecord memory state = STATE_MACHINE.getRecognisedState(context.recognisedStateId);
        if (state.workflowKey != context.workflowKey) revert AVADataTypes.InvalidState(context.recognisedStateId);
        uint256 credentialId = CREDENTIAL_REGISTRY.activeStandingCredentialId(
            state.packageId, context.authorityId, VECTOR_KEY, CATEGORY_HASH
        );
        if (!CREDENTIAL_REGISTRY.credentialProvesSubjectStanding(
                credentialId, state.packageId, context.authorityId, VECTOR_KEY, CATEGORY_HASH, REQUIRED_THRESHOLD
            )) {
            revert AVADataTypes.InvalidState(context.recognisedStateId);
        }
    }
}
