// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAVAApplicationModule} from "../../interfaces/IAVAApplicationModule.sol";
import {RuleModuleIdentity} from "../../interfaces/IRuleModuleIdentity.sol";
import {
    IAVAAttributionModule,
    IAVAVerificationModule,
    IAVATransitionRuleModule,
    IAVAEvidencePolicyModule,
    IAVAEvidenceLifecycleModule,
    IAVADisclosurePolicyModule,
    IAVAChallengePolicyModule,
    IAVAAuthorityPolicyModule,
    IAVAStandingPolicyModule,
    IAVAAllocationPolicyModule,
    IAVAConsequencePolicyModule,
    IAVAFieldPolicyModule,
    IAVAAntiAbusePolicyModule
} from "../interfaces/IAVACoreRuleModules.sol";

/// @notice Shared stateless implementation for the default core policy capabilities.
/// @dev Capability keys remain independently bound and replaceable in each rule package.
contract DefaultAVACorePolicyBundle is
    IAVAAttributionModule,
    IAVAVerificationModule,
    IAVATransitionRuleModule,
    IAVAEvidencePolicyModule,
    IAVAEvidenceLifecycleModule,
    IAVADisclosurePolicyModule,
    IAVAChallengePolicyModule,
    IAVAAuthorityPolicyModule,
    IAVAStandingPolicyModule,
    IAVAAllocationPolicyModule,
    IAVAConsequencePolicyModule,
    IAVAFieldPolicyModule,
    IAVAAntiAbusePolicyModule,
    RuleModuleIdentity
{
    function validateAttribution(IAVAApplicationModule.GovernedObjectContext calldata) external pure {}

    function validateVerification(IAVAApplicationModule.RecognisedStateFormationContext calldata) external pure {}

    function validateTransition(IAVAApplicationModule.RecognisedStateTransitionContext calldata) external pure {}

    function validateEvidence(IAVAApplicationModule.EvidenceContext calldata) external pure {}

    function validateEvidenceUse(IAVAApplicationModule.EvidenceUseContext calldata)
        external
        pure
        override(IAVAEvidencePolicyModule, IAVAEvidenceLifecycleModule)
    {}

    function validateEvidenceLifecycle(EvidenceLifecycleContext calldata) external pure {}

    function validateDisclosure(DisclosureContext calldata) external pure {}

    function validateChallenge(ChallengeContext calldata) external pure {}

    function validateAuthority(AuthorityContext calldata) external pure {}

    function validateStanding(StandingPolicyContext calldata) external pure {}

    function validateAllocation(AllocationPolicyContext calldata) external pure {}

    function validateConsequence(IAVAApplicationModule.DownstreamRecordContext calldata) external pure {}

    function validateFieldPolicy(FieldPolicyContext calldata) external pure {}

    function validateAntiAbuse(AntiAbuseContext calldata) external pure {}
}

contract DefaultCoreAttributionModule is IAVAAttributionModule, RuleModuleIdentity {
    function validateAttribution(IAVAApplicationModule.GovernedObjectContext calldata) external pure {}
}

contract DefaultCoreVerificationModule is IAVAVerificationModule, RuleModuleIdentity {
    function validateVerification(IAVAApplicationModule.RecognisedStateFormationContext calldata) external pure {}
}

contract DefaultCoreTransitionRuleModule is IAVATransitionRuleModule, RuleModuleIdentity {
    function validateTransition(IAVAApplicationModule.RecognisedStateTransitionContext calldata) external pure {}
}

contract DefaultCoreEvidencePolicyModule is IAVAEvidencePolicyModule, RuleModuleIdentity {
    function validateEvidence(IAVAApplicationModule.EvidenceContext calldata) external pure {}

    function validateEvidenceUse(IAVAApplicationModule.EvidenceUseContext calldata) external pure {}
}

contract DefaultCoreEvidenceLifecycleModule is IAVAEvidenceLifecycleModule, RuleModuleIdentity {
    function validateEvidenceLifecycle(EvidenceLifecycleContext calldata) external pure {}

    function validateEvidenceUse(IAVAApplicationModule.EvidenceUseContext calldata) external pure {}
}

contract DefaultCoreDisclosurePolicyModule is IAVADisclosurePolicyModule, RuleModuleIdentity {
    function validateDisclosure(DisclosureContext calldata) external pure {}
}

contract DefaultCoreChallengePolicyModule is IAVAChallengePolicyModule, RuleModuleIdentity {
    function validateChallenge(ChallengeContext calldata) external pure {}
}

contract DefaultCoreAuthorityPolicyModule is IAVAAuthorityPolicyModule, RuleModuleIdentity {
    function validateAuthority(AuthorityContext calldata) external pure {}
}

contract DefaultCoreStandingPolicyModule is IAVAStandingPolicyModule, RuleModuleIdentity {
    function validateStanding(StandingPolicyContext calldata) external pure {}
}

contract DefaultCoreAllocationPolicyModule is IAVAAllocationPolicyModule, RuleModuleIdentity {
    function validateAllocation(AllocationPolicyContext calldata) external pure {}
}

contract DefaultCoreConsequencePolicyModule is IAVAConsequencePolicyModule, RuleModuleIdentity {
    function validateConsequence(IAVAApplicationModule.DownstreamRecordContext calldata) external pure {}
}
