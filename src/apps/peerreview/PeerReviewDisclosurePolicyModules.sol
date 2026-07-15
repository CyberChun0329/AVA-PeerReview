// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVACoreTypes} from "../../core/AVACoreTypes.sol";
import {AVACapabilityKeys} from "../../core/AVACapabilityKeys.sol";
import {AVAGovernanceKernel} from "../../core/AVAGovernanceKernel.sol";
import {IAVADisclosurePolicyModule} from "../../core/interfaces/IAVACoreRuleModules.sol";
import {AVADisclosureReceiptExtension} from "../../extensions/privacy/AVADisclosureReceiptExtension.sol";
import {AVAPrivacyProofExtension} from "../../extensions/privacy/AVAPrivacyProofExtension.sol";
import {ChallengeProofDisclosurePolicyModule} from "../../extensions/privacy/AVAChallengePrivacyExtensions.sol";
import {IAVAExtensionPolicyModule} from "../../extensions/shared/IAVAExtensionPolicyModule.sol";
import {RuleModuleIdentity} from "../../interfaces/IRuleModuleIdentity.sol";
import {PeerReviewTypes} from "./PeerReviewTypes.sol";

/// @notice Peer Review disclosure-policy shapes for package-bound Core actions.
/// @dev These validators constrain references and roles only. They never reveal or decrypt content.
contract PeerReviewCoreDisclosurePolicyModule is IAVADisclosurePolicyModule, RuleModuleIdentity {
    enum Scenario {
        None,
        DoubleBlindReview,
        PanelScopedReview,
        VoluntaryIdentityChallenge
    }

    Scenario public immutable SCENARIO;
    uint256 public immutable DISCLOSURE_POLICY_ID;

    constructor(Scenario scenario, uint256 disclosurePolicyId) {
        if (scenario == Scenario.None || disclosurePolicyId == 0) revert AVACoreTypes.EmptyValue();
        SCENARIO = scenario;
        DISCLOSURE_POLICY_ID = disclosurePolicyId;
    }

    function validateDisclosure(DisclosureContext calldata context) external view {
        if (
            context.appId != PeerReviewTypes.APP_ID || context.disclosurePolicyId != DISCLOSURE_POLICY_ID
        ) revert AVACoreTypes.InvalidState(context.disclosurePolicyId);
        _requireStage(context);
        if (SCENARIO == Scenario.DoubleBlindReview) {
            _validateDoubleBlind(context);
            return;
        }
        if (SCENARIO == Scenario.PanelScopedReview) {
            _validatePanelScoped(context);
            return;
        }
        _validateVoluntaryIdentityChallenge(context);
    }

    function _requireStage(DisclosureContext calldata context) private pure {
        if (context.actionKey == AVACoreTypes.ACTION_REGISTER_EVIDENCE) {
            if (context.stage != AVACoreTypes.Stage.Attribution) {
                revert AVACoreTypes.InvalidState(context.targetId);
            }
            return;
        }
        if (context.stage != AVACoreTypes.Stage.Verification) {
            revert AVACoreTypes.InvalidState(context.targetId);
        }
    }

    function _validateDoubleBlind(DisclosureContext calldata context) private pure {
        if (context.actionKey == AVACoreTypes.ACTION_REGISTER_EVIDENCE) {
            if (
                context.roleKey != PeerReviewTypes.ROLE_AUTHOR
                    && context.roleKey != PeerReviewTypes.ROLE_REVIEWER
                    && context.roleKey != PeerReviewTypes.ROLE_CHALLENGER
            ) revert AVACoreTypes.InvalidState(context.targetId);
            return;
        }
        _validateStateAction(context, true);
    }

    function _validatePanelScoped(DisclosureContext calldata context) private pure {
        if (context.actionKey == AVACoreTypes.ACTION_REGISTER_EVIDENCE) {
            if (
                context.roleKey != PeerReviewTypes.ROLE_AUTHOR
                    && context.roleKey != PeerReviewTypes.ROLE_REVIEWER
            ) revert AVACoreTypes.InvalidState(context.targetId);
            return;
        }
        if (
            context.objectTypeKey != PeerReviewTypes.OBJECT_REVIEW_CONTRIBUTION
                || (context.roleKey != PeerReviewTypes.ROLE_EDITOR && context.roleKey != PeerReviewTypes.ROLE_PANEL)
        ) revert AVACoreTypes.InvalidState(context.targetId);
    }

    function _validateVoluntaryIdentityChallenge(DisclosureContext calldata context) private pure {
        if (context.actionKey == AVACoreTypes.ACTION_REGISTER_EVIDENCE) {
            if (context.roleKey != PeerReviewTypes.ROLE_CHALLENGER) {
                revert AVACoreTypes.InvalidState(context.targetId);
            }
            return;
        }
        if (context.objectTypeKey != PeerReviewTypes.OBJECT_CHALLENGE) {
            revert AVACoreTypes.InvalidState(context.targetId);
        }
        if (
            context.actionKey == AVACoreTypes.ACTION_FORM_RECOGNISED_STATE
                || context.actionKey == AVACoreTypes.ACTION_FILE_CHALLENGE
                || context.actionKey == AVACoreTypes.ACTION_TRANSITION_RECOGNISED_STATE
        ) {
            if (context.roleKey != PeerReviewTypes.ROLE_CHALLENGER) {
                revert AVACoreTypes.InvalidState(context.targetId);
            }
            return;
        }
        if (
            context.actionKey == AVACoreTypes.ACTION_RESOLVE_CHALLENGE
                || context.actionKey == AVACoreTypes.ACTION_APPLY_RESTORATION
                || context.actionKey == AVACoreTypes.ACTION_VEST_RECOGNISED_STATE
        ) {
            if (context.roleKey != PeerReviewTypes.ROLE_PANEL) {
                revert AVACoreTypes.InvalidState(context.targetId);
            }
            return;
        }
        revert AVACoreTypes.InvalidState(context.targetId);
    }

    function _validateStateAction(DisclosureContext calldata context, bool allowChallenge) private pure {
        if (
            context.objectTypeKey != PeerReviewTypes.OBJECT_REVIEW_CONTRIBUTION
                && (!allowChallenge || context.objectTypeKey != PeerReviewTypes.OBJECT_CHALLENGE)
        ) revert AVACoreTypes.InvalidState(context.targetId);
        if (context.actionKey == AVACoreTypes.ACTION_FORM_RECOGNISED_STATE) {
            bytes32 requiredRole = context.objectTypeKey == PeerReviewTypes.OBJECT_CHALLENGE
                ? PeerReviewTypes.ROLE_CHALLENGER
                : PeerReviewTypes.ROLE_EDITOR;
            if (context.roleKey != requiredRole) revert AVACoreTypes.InvalidState(context.targetId);
            return;
        }
        if (
            context.actionKey == AVACoreTypes.ACTION_TRANSITION_RECOGNISED_STATE
                || context.actionKey == AVACoreTypes.ACTION_FILE_CHALLENGE
        ) {
            bytes32 requiredRole = context.objectTypeKey == PeerReviewTypes.OBJECT_CHALLENGE
                ? PeerReviewTypes.ROLE_CHALLENGER
                : PeerReviewTypes.ROLE_EDITOR;
            if (context.roleKey != requiredRole) revert AVACoreTypes.InvalidState(context.targetId);
            return;
        }
        if (
            context.actionKey == AVACoreTypes.ACTION_VEST_RECOGNISED_STATE
                || context.actionKey == AVACoreTypes.ACTION_RESOLVE_CHALLENGE
                || context.actionKey == AVACoreTypes.ACTION_APPLY_RESTORATION
        ) {
            if (context.roleKey != PeerReviewTypes.ROLE_PANEL) {
                revert AVACoreTypes.InvalidState(context.targetId);
            }
            return;
        }
        revert AVACoreTypes.InvalidState(context.targetId);
    }

    function _moduleConfigurationHash() internal view override returns (bytes32) {
        return keccak256(abi.encode(SCENARIO, DISCLOSURE_POLICY_ID));
    }
}

/// @notice App policy for disclosure lifecycle receipts; the receipt is not a reveal or access-control engine.
contract PeerReviewDisclosureReceiptPolicyModule is IAVAExtensionPolicyModule, RuleModuleIdentity {
    enum Scenario {
        None,
        PostRecognitionAccess,
        VoluntaryIdentityIntent
    }

    AVAGovernanceKernel public immutable GOVERNANCE_KERNEL;
    Scenario public immutable SCENARIO;
    uint256 public immutable DISCLOSURE_POLICY_ID;

    constructor(AVAGovernanceKernel governanceKernel, Scenario scenario, uint256 disclosurePolicyId) {
        if (address(governanceKernel) == address(0) || scenario == Scenario.None || disclosurePolicyId == 0) {
            revert AVACoreTypes.EmptyValue();
        }
        GOVERNANCE_KERNEL = governanceKernel;
        SCENARIO = scenario;
        DISCLOSURE_POLICY_ID = disclosurePolicyId;
    }

    function validateExtensionRecord(ExtensionPolicyContext calldata context) external view {
        if (
            context.appId != PeerReviewTypes.APP_ID || context.capabilityKey != AVACapabilityKeys.DISCLOSURE_RECEIPT
                || context.actionKey != AVACoreTypes.ACTION_RECORD_DISCLOSURE_RECEIPT
                || context.disclosurePolicyId != DISCLOSURE_POLICY_ID
        ) revert AVACoreTypes.InvalidState(context.recognisedStateId);
        AVACoreTypes.RecognisedStateRecord memory state = _requireCurrentState(context);
        AVACoreTypes.SubjectRecord memory authority =
            GOVERNANCE_KERNEL.IDENTITY_REGISTRY().getSubject(context.authorityId);
        if (!authority.active || authority.appId != context.appId || authority.account != context.actor) {
            revert AVACoreTypes.InvalidState(context.recognisedStateId);
        }
        if (SCENARIO == Scenario.PostRecognitionAccess) {
            if (
                authority.roleKey != PeerReviewTypes.ROLE_PANEL
                    || (state.status != AVACoreTypes.RecognisedStateStatus.Vested
                        && state.status != AVACoreTypes.RecognisedStateStatus.Restored)
                    || !_isAccessRecord(context.recordTypeKey)
            ) revert AVACoreTypes.InvalidState(context.recognisedStateId);
            return;
        }
        if (
            context.recordTypeKey != _recordType(AVADisclosureReceiptExtension.DisclosureReceiptKind.VoluntaryIntent)
                || context.authorityId != context.subjectId
                || (authority.roleKey != PeerReviewTypes.ROLE_AUTHOR
                    && authority.roleKey != PeerReviewTypes.ROLE_REVIEWER
                    && authority.roleKey != PeerReviewTypes.ROLE_CHALLENGER)
        ) revert AVACoreTypes.InvalidState(context.recognisedStateId);
    }

    function _requireCurrentState(ExtensionPolicyContext calldata context)
        private
        view
        returns (AVACoreTypes.RecognisedStateRecord memory state)
    {
        state = GOVERNANCE_KERNEL.getRecognisedState(context.recognisedStateId);
        if (
            state.appId != context.appId || state.workflowKey != context.workflowKey
                || state.packageId != context.packageId || state.lastTransitionId != context.recognisedStateTransitionId
                || state.disclosurePolicyId != context.disclosurePolicyId
        ) revert AVACoreTypes.InvalidState(context.recognisedStateId);
    }

    function _isAccessRecord(bytes32 recordTypeKey) private pure returns (bool) {
        return recordTypeKey == _recordType(AVADisclosureReceiptExtension.DisclosureReceiptKind.AccessGrant)
            || recordTypeKey == _recordType(AVADisclosureReceiptExtension.DisclosureReceiptKind.AccessRevoke)
            || recordTypeKey == _recordType(AVADisclosureReceiptExtension.DisclosureReceiptKind.AccessExpire)
            || recordTypeKey == _recordType(AVADisclosureReceiptExtension.DisclosureReceiptKind.AccessSupersede);
    }

    function _recordType(AVADisclosureReceiptExtension.DisclosureReceiptKind kind) private pure returns (bytes32) {
        return keccak256(abi.encode("ava.extension.disclosure-receipt.kind.v1", kind));
    }

    function _moduleConfigurationHash() internal view override returns (bytes32) {
        return keccak256(abi.encode(address(GOVERNANCE_KERNEL), SCENARIO, DISCLOSURE_POLICY_ID));
    }
}

/// @notice Peer Review policy for context-bound proof receipts. Proof validity remains the verifier's responsibility.
contract PeerReviewZKProofReceiptPolicyModule is IAVAExtensionPolicyModule, RuleModuleIdentity {
    bytes32 private constant PROOF_RECORD_TYPE = keccak256("ava.extension.privacy-proof.record.v1");

    AVAGovernanceKernel public immutable GOVERNANCE_KERNEL;
    uint256 public immutable DISCLOSURE_POLICY_ID;

    constructor(AVAGovernanceKernel governanceKernel, uint256 disclosurePolicyId) {
        if (address(governanceKernel) == address(0) || disclosurePolicyId == 0) {
            revert AVACoreTypes.EmptyValue();
        }
        GOVERNANCE_KERNEL = governanceKernel;
        DISCLOSURE_POLICY_ID = disclosurePolicyId;
    }

    function validateExtensionRecord(ExtensionPolicyContext calldata context) external view {
        if (
            context.appId != PeerReviewTypes.APP_ID || context.capabilityKey != AVACapabilityKeys.PRIVACY_PROOF
                || context.actionKey != AVACoreTypes.ACTION_RECORD_PRIVACY_PROOF
                || context.recordTypeKey != PROOF_RECORD_TYPE || context.disclosurePolicyId != DISCLOSURE_POLICY_ID
                || context.scopeKey == bytes32(0) || context.payloadHash == bytes32(0)
                || context.contextHash == bytes32(0)
        ) revert AVACoreTypes.InvalidState(context.recognisedStateId);
        AVACoreTypes.RecognisedStateRecord memory state =
            GOVERNANCE_KERNEL.getRecognisedState(context.recognisedStateId);
        if (
            state.appId != context.appId || state.lastTransitionId != context.recognisedStateTransitionId
        ) revert AVACoreTypes.InvalidState(context.recognisedStateId);
        AVACoreTypes.SubjectRecord memory authority =
            GOVERNANCE_KERNEL.IDENTITY_REGISTRY().getSubject(context.authorityId);
        if (
            !authority.active || authority.appId != context.appId || authority.account != context.actor
                || (authority.roleKey != PeerReviewTypes.ROLE_REVIEWER
                    && authority.roleKey != PeerReviewTypes.ROLE_CHALLENGER
                    && authority.roleKey != PeerReviewTypes.ROLE_PANEL)
                || (authority.roleKey != PeerReviewTypes.ROLE_PANEL && context.authorityId != context.subjectId)
        ) revert AVACoreTypes.InvalidState(context.recognisedStateId);
    }

    function _moduleConfigurationHash() internal view override returns (bytes32) {
        return keccak256(abi.encode(address(GOVERNANCE_KERNEL), DISCLOSURE_POLICY_ID));
    }
}

/// @notice Peer Review configuration of the reusable anonymous challenge proof gate.
contract PeerReviewAnonymousChallengeProofPolicyModule is ChallengeProofDisclosurePolicyModule {
    constructor(AVAPrivacyProofExtension proofRegistry, uint256 disclosurePolicyId)
        ChallengeProofDisclosurePolicyModule(proofRegistry, disclosurePolicyId, PeerReviewTypes.ROLE_CHALLENGER)
    {}
}
