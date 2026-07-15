// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVACoreTypes} from "../AVACoreTypes.sol";
import {IAVAApplicationModule} from "../../interfaces/IAVAApplicationModule.sol";
import {IRuleModuleIdentity} from "../../interfaces/IRuleModuleIdentity.sol";

interface IAVAAttributionModule is IRuleModuleIdentity {
    function validateAttribution(IAVAApplicationModule.GovernedObjectContext calldata context) external view;
}

interface IAVAVerificationModule is IRuleModuleIdentity {
    function validateVerification(IAVAApplicationModule.RecognisedStateFormationContext calldata context)
        external
        view;
}

interface IAVATransitionRuleModule is IRuleModuleIdentity {
    function validateTransition(IAVAApplicationModule.RecognisedStateTransitionContext calldata context)
        external
        view;
}

interface IAVAEvidencePolicyModule is IRuleModuleIdentity {
    function validateEvidence(IAVAApplicationModule.EvidenceContext calldata context) external view;

    function validateEvidenceUse(IAVAApplicationModule.EvidenceUseContext calldata context) external view;
}

interface IAVAEvidenceLifecycleModule is IRuleModuleIdentity {
    struct EvidenceLifecycleContext {
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        uint256 evidenceId;
        bytes32 evidenceTypeHash;
        bytes32 subjectId;
        uint256 disclosurePolicyId;
        AVACoreTypes.EvidenceStatus fromStatus;
        AVACoreTypes.EvidenceStatus toStatus;
        AVACoreTypes.EvidenceLifecycleKind kind;
        uint256 replacementEvidenceId;
        bytes32 roleKey;
        bytes32 authorityId;
        bytes32 reasonHash;
        address actor;
    }

    function validateEvidenceLifecycle(EvidenceLifecycleContext calldata context) external view;

    function validateEvidenceUse(IAVAApplicationModule.EvidenceUseContext calldata context) external view;
}

interface IAVADisclosurePolicyModule is IRuleModuleIdentity {
    struct DisclosureContext {
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 actionKey;
        bytes32 roleKey;
        AVACoreTypes.Stage stage;
        bytes32 objectTypeKey;
        bytes32 subjectId;
        uint256 disclosurePolicyId;
        uint256 targetId;
        uint256 evidenceId;
        bytes32 evidenceTypeHash;
        bytes32 authorityId;
        address actor;
    }

    function validateDisclosure(DisclosureContext calldata context) external view;
}

interface IAVAChallengePolicyModule is IRuleModuleIdentity {
    struct ChallengeContext {
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 actionKey;
        bytes32 roleKey;
        uint256 challengeId;
        uint256 recognisedStateId;
        bytes32 actorSubjectId;
        bytes32 targetSubjectId;
        bytes32 outcomeKey;
        AVACoreTypes.RecognisedStateStatus targetStatus;
        bytes32 authorityId;
        address actor;
    }

    function validateChallenge(ChallengeContext calldata context) external view;
}

interface IAVAAuthorityPolicyModule is IRuleModuleIdentity {
    struct AuthorityContext {
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 actionKey;
        bytes32 roleKey;
        AVACoreTypes.Stage stage;
        bytes32 objectTypeKey;
        uint256 targetId;
        bytes32 targetSubjectId;
        bytes32 authorityId;
        bytes32 decisionHash;
        address actor;
    }

    function validateAuthority(AuthorityContext calldata context) external view;
}

interface IAVAStandingPolicyModule is IRuleModuleIdentity {
    struct StandingPolicyContext {
        IAVAApplicationModule.DownstreamRecordContext record;
        int256 delta;
    }

    function validateStanding(StandingPolicyContext calldata context) external view;
}

interface IAVAAllocationPolicyModule is IRuleModuleIdentity {
    struct AllocationPolicyContext {
        IAVAApplicationModule.DownstreamRecordContext record;
        uint256 units;
    }

    function validateAllocation(AllocationPolicyContext calldata context) external view;
}

interface IAVAConsequencePolicyModule is IRuleModuleIdentity {
    function validateConsequence(IAVAApplicationModule.DownstreamRecordContext calldata context) external view;
}

interface IAVAFieldPolicyModule is IRuleModuleIdentity {
    struct FieldPolicyContext {
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 actionKey;
        bytes32 roleKey;
        AVACoreTypes.Stage stage;
        uint256 targetId;
        bytes32 objectTypeKey;
        bytes32 subjectId;
        uint256 evidenceId;
        bytes32 authorityId;
        address actor;
    }

    function validateFieldPolicy(FieldPolicyContext calldata context) external view;
}

interface IAVAAntiAbusePolicyModule is IRuleModuleIdentity {
    struct AntiAbuseContext {
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 actionKey;
        bytes32 roleKey;
        uint256 targetId;
        bytes32 targetTypeKey;
        bytes32 actorSubjectId;
        bytes32 targetSubjectId;
        bytes32 authorityId;
        address actor;
    }

    function validateAntiAbuse(AntiAbuseContext calldata context) external view;
}
