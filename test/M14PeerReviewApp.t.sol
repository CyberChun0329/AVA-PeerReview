// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVACoreRulePackageRegistry} from "../src/core/AVACoreRulePackageRegistry.sol";
import {AVACoreTypes} from "../src/core/AVACoreTypes.sol";
import {AVACapabilityKeys} from "../src/core/AVACapabilityKeys.sol";
import {AVAAuthorityMatrix} from "../src/core/AVAAuthorityMatrix.sol";
import {AVADisclosurePolicyRegistry} from "../src/core/AVADisclosurePolicyRegistry.sol";
import {AVAEvidenceRegistry} from "../src/core/AVAEvidenceRegistry.sol";
import {AVAGovernanceKernel} from "../src/core/AVAGovernanceKernel.sol";
import {AVAIdentityRegistry} from "../src/core/AVAIdentityRegistry.sol";
import {AVAWorkflowPolicyRouter} from "../src/core/AVAWorkflowPolicyRouter.sol";
import {IAVATransitionGuard} from "../src/core/interfaces/IAVATransitionGuard.sol";
import {IAVAPostTransitionHook} from "../src/core/interfaces/IAVAPostTransitionHook.sol";
import {IAVAStandingRevision} from "../src/extensions/standing/IAVAStandingRevision.sol";
import {AVAStandingRevisionExtension} from "../src/extensions/standing/AVAStandingRevisionExtension.sol";
import {IZKProofVerifier} from "../src/interfaces/IZKProofVerifier.sol";
import {
    AVAStandingComputationExtension,
    AVAStandingCredentialExtension
} from "../src/extensions/standing/AVAStandingCredentialExtensions.sol";
import {
    AVAStandingProvenanceExtension,
    AVAStandingZKProofExtension,
    AVAStandingZKCredentialExtension
} from "../src/extensions/standing/AVAStandingProvenanceExtensions.sol";
import {PeerReviewTypes} from "../src/apps/peerreview/PeerReviewTypes.sol";
import {PeerReviewApplicationModule} from "../src/apps/peerreview/PeerReviewApplicationModule.sol";
import {PeerReviewPenaltyPolicyModule} from "../src/apps/peerreview/PeerReviewPenaltyPolicyModule.sol";
import {
    PeerReviewCoreDisclosurePolicyModule,
    PeerReviewDisclosureReceiptPolicyModule,
    PeerReviewZKProofReceiptPolicyModule,
    PeerReviewAnonymousChallengeProofPolicyModule
} from "../src/apps/peerreview/PeerReviewDisclosurePolicyModules.sol";
import {IAVAApplicationModule} from "../src/interfaces/IAVAApplicationModule.sol";
import {IRuleModuleIdentity, RuleModuleIdentity} from "../src/interfaces/IRuleModuleIdentity.sol";
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
} from "../src/core/interfaces/IAVACoreRuleModules.sol";
import {AVAChallengeExtension} from "../src/extensions/challenge/AVAChallengeExtension.sol";
import {AVAAuditReceiptExtension} from "../src/extensions/audit/AVAAuditReceiptExtension.sol";
import {
    AVAStandingRecordExtension,
    AVAAllocationRecordExtension,
    AVAConsequenceRecordExtension
} from "../src/extensions/downstream/AVADownstreamRecordExtensions.sol";
import {IAVADownstreamRecordSource} from "../src/extensions/downstream/IAVADownstreamRecordSource.sol";
import {
    AVARewardPriorityExtension,
    AVAPenaltyRestorationExtension
} from "../src/extensions/governance/AVABoundedGovernanceExtensions.sol";
import {AVAValueLifecycleExtension} from "../src/extensions/settlement/AVAValueLifecycleExtension.sol";
import {IAVASettlementReceiptSource} from "../src/extensions/settlement/IAVASettlementReceiptSource.sol";
import {AVAExternalOperationExtension} from "../src/extensions/external/AVAExternalOperationExtension.sol";
import {
    AVAExternalOperationTargetKind,
    AVAExternalOperationTargetResolver
} from "../src/extensions/external/AVAExternalOperationTargetResolver.sol";
import {AVAPrivacyProofExtension} from "../src/extensions/privacy/AVAPrivacyProofExtension.sol";
import {AVADisclosureReceiptExtension} from "../src/extensions/privacy/AVADisclosureReceiptExtension.sol";
import {AVAChallengeProofUseExtension} from "../src/extensions/privacy/AVAChallengePrivacyExtensions.sol";
import {M14ApplicationFixture} from "./helpers/M14ApplicationFixture.sol";
import "./helpers/M14CorePackageFixture.sol";

interface M14PerformanceVm {
    function expectCall(address callee, bytes calldata data, uint64 count) external;
    function etch(address target, bytes calldata newRuntimeBytecode) external;
}

contract M14PeerReviewActor {
    function registerPolicy(
        AVADisclosurePolicyRegistry policyRegistry,
        bytes32 roleKey,
        bytes32 authorityId,
        bytes32 policyKey
    ) external returns (uint256) {
        return policyRegistry.registerPolicy(
            PeerReviewTypes.APP_ID,
            roleKey,
            authorityId,
            policyKey,
            "m14-peer-review-policy",
            "ipfs://m14-peer-review-policy"
        );
    }

    function registerEvidence(
        AVAEvidenceRegistry evidenceRegistry,
        bytes32 workflowKey,
        uint256 packageId,
        bytes32 roleKey,
        bytes32 subjectId,
        bytes32 commitment,
        uint256 disclosurePolicyId
    ) external returns (uint256) {
        return evidenceRegistry.registerEvidence(
            AVAEvidenceRegistry.EvidenceRegistrationInput({
                appId: PeerReviewTypes.APP_ID,
                workflowKey: workflowKey,
                packageId: packageId,
                roleKey: roleKey,
                subjectId: subjectId,
                commitment: commitment,
                evidenceTypeHash: keccak256("m14-peer-review-evidence-type"),
                disclosurePolicyId: disclosurePolicyId,
                authorityId: subjectId,
                uri: "ipfs://m14-peer-review-evidence"
            })
        );
    }

    function registerTypedEvidence(
        AVAEvidenceRegistry evidenceRegistry,
        bytes32 workflowKey,
        uint256 packageId,
        bytes32 roleKey,
        bytes32 subjectId,
        bytes32 commitment,
        bytes32 evidenceTypeHash,
        uint256 disclosurePolicyId
    ) external returns (uint256) {
        return evidenceRegistry.registerEvidence(
            AVAEvidenceRegistry.EvidenceRegistrationInput({
                appId: PeerReviewTypes.APP_ID,
                workflowKey: workflowKey,
                packageId: packageId,
                roleKey: roleKey,
                subjectId: subjectId,
                commitment: commitment,
                evidenceTypeHash: evidenceTypeHash,
                disclosurePolicyId: disclosurePolicyId,
                authorityId: subjectId,
                uri: "ipfs://m14-peer-review-typed-evidence"
            })
        );
    }

    function recordEvidenceLifecycle(
        AVAEvidenceRegistry evidenceRegistry,
        uint256 evidenceId,
        bytes32 roleKey,
        bytes32 authorityId,
        AVACoreTypes.EvidenceLifecycleKind kind,
        bytes32 reasonHash
    ) external returns (uint256) {
        return evidenceRegistry.recordEvidenceLifecycle(
            evidenceId, roleKey, authorityId, kind, 0, reasonHash, "ipfs://m14-evidence-lifecycle"
        );
    }

    function supersedeEvidence(
        AVAEvidenceRegistry evidenceRegistry,
        uint256 evidenceId,
        uint256 replacementEvidenceId,
        bytes32 roleKey,
        bytes32 authorityId,
        bytes32 reasonHash
    ) external returns (uint256) {
        return evidenceRegistry.recordEvidenceLifecycle(
            evidenceId,
            roleKey,
            authorityId,
            AVACoreTypes.EvidenceLifecycleKind.Supersede,
            replacementEvidenceId,
            reasonHash,
            "ipfs://m14-evidence-supersession"
        );
    }

    function registerObject(AVAGovernanceKernel kernel, AVAGovernanceKernel.GovernedObjectInput calldata input)
        external
        returns (uint256)
    {
        return kernel.registerGovernedObject(input);
    }

    function formState(AVAGovernanceKernel kernel, AVAGovernanceKernel.RecognisedStateFormationInput calldata input)
        external
        returns (uint256)
    {
        return kernel.formRecognisedState(input);
    }

    function transitionState(
        AVAGovernanceKernel kernel,
        AVAGovernanceKernel.RecognisedStateTransitionInput calldata input
    ) external returns (uint256) {
        return kernel.transitionRecognisedState(input);
    }

    function vestState(AVAGovernanceKernel kernel, AVAGovernanceKernel.RecognisedStateTransitionInput calldata input)
        external
        returns (uint256)
    {
        return kernel.vestRecognisedState(input);
    }

    function fileChallenge(
        AVAChallengeExtension challengeExtension,
        AVAChallengeExtension.ChallengeFilingInput calldata input
    ) external returns (uint256) {
        return challengeExtension.fileChallenge(input);
    }

    function screenChallenge(
        AVAChallengeExtension challengeExtension,
        uint256 challengeId,
        bytes32 roleKey,
        bytes32 authorityId
    ) external returns (uint256) {
        return challengeExtension.screenChallenge(challengeId, roleKey, authorityId);
    }

    function resolveChallenge(
        AVAChallengeExtension challengeExtension,
        AVAChallengeExtension.ChallengeResolutionInput calldata input
    ) external returns (uint256) {
        return challengeExtension.resolveChallenge(input);
    }

    function restoreChallenge(
        AVAChallengeExtension challengeExtension,
        uint256 challengeId,
        bytes32 roleKey,
        bytes32 authorityId,
        bytes32 reasonHash,
        string calldata reasonURI
    ) external returns (uint256) {
        return challengeExtension.applyRestoration(challengeId, roleKey, authorityId, reasonHash, reasonURI);
    }

    function makeRestorationAvailable(
        AVAChallengeExtension challengeExtension,
        uint256 challengeId,
        bytes32 roleKey,
        bytes32 authorityId,
        bytes32 reasonHash,
        string calldata reasonURI
    ) external returns (uint256) {
        return challengeExtension.recordRestorationAvailability(
            challengeId, roleKey, authorityId, reasonHash, reasonURI
        );
    }

    function closeChallenge(
        AVAChallengeExtension challengeExtension,
        uint256 challengeId,
        bytes32 roleKey,
        bytes32 authorityId,
        bytes32 reasonHash,
        string calldata reasonURI
    ) external returns (uint256) {
        return challengeExtension.closeChallenge(challengeId, roleKey, authorityId, reasonHash, reasonURI);
    }

    function recordStanding(
        AVAStandingRecordExtension extension,
        AVAStandingRecordExtension.StandingInput calldata input
    ) external returns (uint256) {
        return extension.recordStandingUpdate(input);
    }

    function recordStandingComputation(
        AVAStandingComputationExtension extension,
        AVAStandingComputationExtension.ComputationInput calldata input
    ) external returns (uint256) {
        return extension.recordComputation(input);
    }

    function issueStandingCredential(
        AVAStandingCredentialExtension extension,
        AVAStandingCredentialExtension.CredentialInput calldata input
    ) external returns (uint256) {
        return extension.issueCredential(input);
    }

    function registerStandingFormula(
        AVAStandingProvenanceExtension extension,
        AVAStandingProvenanceExtension.FormulaInput calldata input
    ) external returns (uint256) {
        return extension.registerFormula(input);
    }

    function registerStandingSourceSet(
        AVAStandingProvenanceExtension extension,
        AVAStandingProvenanceExtension.SourceSetInput calldata input
    ) external returns (uint256) {
        return extension.registerSourceSet(input);
    }

    function attestStandingSourceSet(
        AVAStandingProvenanceExtension extension,
        AVAStandingProvenanceExtension.CompletenessInput calldata input
    ) external returns (uint256) {
        return extension.recordCompletenessAttestation(input);
    }

    function recordStandingStatement(
        AVAStandingProvenanceExtension extension,
        AVAStandingProvenanceExtension.StatementInput calldata input
    ) external returns (uint256) {
        return extension.recordComputationStatement(input);
    }

    function registerStandingZKProof(
        AVAStandingZKProofExtension extension,
        AVAStandingZKProofExtension.ProofInput calldata input
    ) external returns (uint256) {
        return extension.registerProof(input);
    }

    function issueStandingZKCredential(
        AVAStandingZKCredentialExtension extension,
        AVAStandingZKCredentialExtension.CredentialInput calldata input
    ) external returns (uint256) {
        return extension.issueCredential(input);
    }

    function requestExternalOperation(
        AVAExternalOperationExtension extension,
        AVAExternalOperationExtension.OperationInput calldata input
    ) external returns (uint256) {
        return extension.requestOperation(input);
    }

    function requestTargetExternalOperation(
        AVAExternalOperationExtension extension,
        AVAExternalOperationExtension.TargetOperationInput calldata input
    ) external returns (uint256) {
        return extension.requestTargetOperation(input);
    }

    function recordExternalOperationOutcome(
        AVAExternalOperationExtension extension,
        uint256 operationId,
        AVAExternalOperationExtension.OperationStatus status,
        bytes32 roleKey,
        bytes32 authorityId,
        bytes32 outcomeHash
    ) external returns (uint256) {
        return extension.recordOutcome(
            operationId, status, roleKey, authorityId, outcomeHash, "ipfs://parity-external-operation-outcome"
        );
    }

    function registerChallengePrivacyProof(
        AVAPrivacyProofExtension extension,
        AVAPrivacyProofExtension.ChallengeProofInput calldata input
    ) external returns (uint256) {
        return extension.registerChallengeProof(input);
    }

    function recordChallengeProofUse(
        AVAChallengeProofUseExtension extension,
        AVAChallengeProofUseExtension.ProofUseInput calldata input
    ) external returns (uint256) {
        return extension.recordProofUse(input);
    }

    function recordDisclosure(
        AVADisclosureReceiptExtension extension,
        AVADisclosureReceiptExtension.DisclosureInput calldata input
    ) external returns (uint256) {
        return extension.recordDisclosure(input);
    }

    function recordAllocation(
        AVAAllocationRecordExtension extension,
        AVAAllocationRecordExtension.AllocationInput calldata input
    ) external returns (uint256) {
        return extension.recordAllocation(input);
    }

    function recordConsequence(
        AVAConsequenceRecordExtension extension,
        AVAConsequenceRecordExtension.ConsequenceInput calldata input
    ) external returns (uint256) {
        return extension.recordConsequence(input);
    }

    function recordReward(
        AVARewardPriorityExtension extension,
        AVARewardPriorityExtension.RewardPriorityInput calldata input
    ) external returns (uint256) {
        return extension.recordReward(input);
    }

    function recordAdministrativePriority(
        AVARewardPriorityExtension extension,
        AVARewardPriorityExtension.RewardPriorityInput calldata input
    ) external returns (uint256) {
        return extension.recordAdministrativePriority(input);
    }

    function recordPenalty(
        AVAPenaltyRestorationExtension extension,
        AVAPenaltyRestorationExtension.PenaltyInput calldata input
    ) external returns (uint256) {
        return extension.recordPenalty(input);
    }

    function recordStandingPenaltyInput(
        AVAPenaltyRestorationExtension extension,
        AVAPenaltyRestorationExtension.StandingPenaltyInput calldata input
    ) external returns (uint256) {
        return extension.recordStandingPenaltyInput(input);
    }

    function recordEligibilityRestriction(
        AVAPenaltyRestorationExtension extension,
        AVAPenaltyRestorationExtension.EligibilityRestrictionInput calldata input
    ) external returns (uint256) {
        return extension.recordEligibilityRestriction(input);
    }

    function recordRestoration(
        AVAPenaltyRestorationExtension extension,
        AVAPenaltyRestorationExtension.RestorationInput calldata input
    ) external returns (uint256) {
        return extension.recordRestoration(input);
    }

    function recordRewardLifecycle(
        AVAValueLifecycleExtension extension,
        AVAValueLifecycleExtension.RewardLifecycleInput calldata input
    ) external returns (uint256) {
        return extension.recordRewardLifecycle(input);
    }

    function recordValueSettlement(
        AVAValueLifecycleExtension extension,
        AVAValueLifecycleExtension.ValueSettlementInput calldata input
    ) external returns (uint256) {
        return extension.recordValueSettlement(input);
    }

    function recordRepaymentObligation(
        AVAValueLifecycleExtension extension,
        AVAValueLifecycleExtension.RepaymentObligationInput calldata input
    ) external returns (uint256) {
        return extension.recordRepaymentObligation(input);
    }

    function recordRecoveryOutcome(
        AVAValueLifecycleExtension extension,
        AVAValueLifecycleExtension.RecoveryOutcomeInput calldata input
    ) external returns (uint256) {
        return extension.recordRecoveryOutcome(input);
    }

    function recordAudit(AVAAuditReceiptExtension extension, AVAAuditReceiptExtension.AuditInput calldata input)
        external
        returns (uint256)
    {
        return extension.recordAudit(input);
    }
}

contract M14UncheckedHighImpactRequester is RuleModuleIdentity {
    function request(AVAGovernanceKernel kernel, AVAGovernanceKernel.SourceBoundTransitionInput calldata input)
        external
        returns (uint256)
    {
        return kernel.requestSourceBoundTransition(input);
    }
}

contract M14MutableBoundExtension is IAVATransitionGuard, IAVAPostTransitionHook {
    bytes32 private identityHash = keccak256("m14.bound-extension.v1");

    function setIdentityHash(bytes32 identityHash_) external {
        identityHash = identityHash_;
    }

    function moduleIdentityHash() external view returns (bytes32) {
        return identityHash;
    }

    function validateTransition(
        uint256,
        uint256,
        AVACoreTypes.RecognisedStateStatus,
        AVACoreTypes.RecognisedStateStatus,
        AVACoreTypes.TransitionKind
    ) external pure {}

    function onRecognisedStateTransition(TransitionContext calldata) external pure {}

    function request(AVAGovernanceKernel kernel, AVAGovernanceKernel.SourceBoundTransitionInput calldata input)
        external
        returns (uint256)
    {
        return kernel.requestSourceBoundTransition(input);
    }
}

contract M14RejectingFieldPolicyModule is IAVAFieldPolicyModule, RuleModuleIdentity {
    bytes32 public immutable REJECTED_ACTION;

    constructor(bytes32 rejectedAction) {
        REJECTED_ACTION = rejectedAction;
    }

    function validateFieldPolicy(FieldPolicyContext calldata context) external view {
        if (context.actionKey == REJECTED_ACTION) revert AVACoreTypes.InvalidState(context.targetId);
    }

    function _moduleConfigurationHash() internal view override returns (bytes32) {
        return REJECTED_ACTION;
    }
}

contract M14RejectingAntiAbusePolicyModule is IAVAAntiAbusePolicyModule, RuleModuleIdentity {
    bytes32 public immutable REJECTED_ACTION;

    constructor(bytes32 rejectedAction) {
        REJECTED_ACTION = rejectedAction;
    }

    function validateAntiAbuse(AntiAbuseContext calldata context) external view {
        if (context.actionKey == REJECTED_ACTION) revert AVACoreTypes.InvalidState(context.targetId);
    }

    function _moduleConfigurationHash() internal view override returns (bytes32) {
        return REJECTED_ACTION;
    }
}

contract M14PeerReviewAlwaysValidVerifier is IZKProofVerifier {
    bytes32 private constant DOMAIN = keccak256("m14.peer-review-standing-zk-domain.v1");

    function verify(bytes32 contextHash, SchnorrProof calldata) external pure returns (bool) {
        return contextHash != bytes32(0);
    }

    function proofDomain() external pure returns (bytes32) {
        return DOMAIN;
    }
}

contract M14PeerReviewSettlementSource is IAVASettlementReceiptSource {
    AVAGovernanceKernel public immutable GOVERNANCE_KERNEL;
    SettlementSourceContext private source;

    constructor(AVAGovernanceKernel governanceKernel_, SettlementSourceContext memory source_) {
        GOVERNANCE_KERNEL = governanceKernel_;
        source = source_;
    }

    function getSettlementSource(uint256 settlementId) external view returns (SettlementSourceContext memory) {
        if (settlementId != source.id) revert AVACoreTypes.UnknownReference(settlementId);
        return source;
    }
}

contract M14ReentrantChallengeHook is IAVAPostTransitionHook, RuleModuleIdentity {
    AVAChallengeExtension public immutable CHALLENGE_EXTENSION;
    bytes32 public immutable AUTHORITY_ID;
    uint256 public challengeId;
    bool public reentrySucceeded;

    constructor(AVAChallengeExtension challengeExtension, bytes32 authorityId) {
        CHALLENGE_EXTENSION = challengeExtension;
        AUTHORITY_ID = authorityId;
    }

    function setChallengeId(uint256 challengeId_) external {
        challengeId = challengeId_;
    }

    function onRecognisedStateTransition(TransitionContext calldata context) external {
        if (challengeId == 0 || context.kind != AVACoreTypes.TransitionKind.ChallengeCorrection) return;
        try CHALLENGE_EXTENSION.resolveChallenge(
            AVAChallengeExtension.ChallengeResolutionInput({
                challengeId: challengeId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: AUTHORITY_ID,
                outcome: AVAChallengeExtension.ChallengeOutcome.RejectedGoodFaith,
                correctionStatus: context.toStatus,
                reasonHash: keccak256("m145-reentrant-resolution"),
                reasonURI: "ipfs://m145-reentrant-resolution"
            })
        ) {
            reentrySucceeded = true;
        } catch {}
    }

    function _moduleConfigurationHash() internal view override returns (bytes32) {
        return keccak256(abi.encode(address(CHALLENGE_EXTENSION), AUTHORITY_ID));
    }
}

contract M14RejectingCoreRuleModule is
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
    RuleModuleIdentity
{
    function validateAttribution(IAVAApplicationModule.GovernedObjectContext calldata) external pure {
        _reject();
    }

    function validateVerification(IAVAApplicationModule.RecognisedStateFormationContext calldata) external pure {
        _reject();
    }

    function validateTransition(IAVAApplicationModule.RecognisedStateTransitionContext calldata) external pure {
        _reject();
    }

    function validateEvidence(IAVAApplicationModule.EvidenceContext calldata) external pure {
        _reject();
    }

    function validateEvidenceUse(IAVAApplicationModule.EvidenceUseContext calldata)
        external
        pure
        override(IAVAEvidencePolicyModule, IAVAEvidenceLifecycleModule)
    {
        _reject();
    }

    function validateEvidenceLifecycle(EvidenceLifecycleContext calldata) external pure {
        _reject();
    }

    function validateDisclosure(DisclosureContext calldata) external pure {
        _reject();
    }

    function validateChallenge(ChallengeContext calldata) external pure {
        _reject();
    }

    function validateAuthority(AuthorityContext calldata) external pure {
        _reject();
    }

    function validateStanding(StandingPolicyContext calldata) external pure {
        _reject();
    }

    function validateAllocation(AllocationPolicyContext calldata) external pure {
        _reject();
    }

    function validateConsequence(IAVAApplicationModule.DownstreamRecordContext calldata) external pure {
        _reject();
    }

    function _reject() private pure {
        revert AVACoreTypes.InvalidState(type(uint256).max);
    }
}

contract M14BoundedAllocationPolicyModule is IAVAAllocationPolicyModule, RuleModuleIdentity {
    uint256 public immutable MAX_UNITS;

    constructor(uint256 maxUnits) {
        MAX_UNITS = maxUnits;
    }

    function validateAllocation(AllocationPolicyContext calldata context) external view {
        if (context.units == 0 || context.units > MAX_UNITS) {
            revert AVACoreTypes.InvalidState(context.record.recognisedStateId);
        }
    }

    function _moduleConfigurationHash() internal view override returns (bytes32) {
        return keccak256(abi.encode(MAX_UNITS));
    }
}

contract M14ActionRejectingDisclosurePolicyModule is IAVADisclosurePolicyModule, RuleModuleIdentity {
    bytes32 public immutable REJECTED_ACTION;

    constructor(bytes32 rejectedAction) {
        REJECTED_ACTION = rejectedAction;
    }

    function validateDisclosure(DisclosureContext calldata context) external view {
        if (context.actionKey == REJECTED_ACTION) revert AVACoreTypes.InvalidState(context.targetId);
    }

    function _moduleConfigurationHash() internal view override returns (bytes32) {
        return REJECTED_ACTION;
    }
}

contract M14ActionRejectingAuthorityPolicyModule is IAVAAuthorityPolicyModule, RuleModuleIdentity {
    bytes32 public immutable REJECTED_ACTION;

    constructor(bytes32 rejectedAction) {
        REJECTED_ACTION = rejectedAction;
    }

    function validateAuthority(AuthorityContext calldata context) external view {
        if (context.actionKey == REJECTED_ACTION) revert AVACoreTypes.InvalidState(context.targetId);
    }

    function _moduleConfigurationHash() internal view override returns (bytes32) {
        return REJECTED_ACTION;
    }
}

contract M14ExpectedAuthorityTargetPolicyModule is IAVAAuthorityPolicyModule, RuleModuleIdentity {
    bytes32 public immutable REQUIRED_ACTION;
    uint256 public immutable EXPECTED_TARGET_ID;

    constructor(bytes32 requiredAction, uint256 expectedTargetId) {
        REQUIRED_ACTION = requiredAction;
        EXPECTED_TARGET_ID = expectedTargetId;
    }

    function validateAuthority(AuthorityContext calldata context) external view {
        if (context.actionKey == REQUIRED_ACTION && context.targetId != EXPECTED_TARGET_ID) {
            revert AVACoreTypes.InvalidState(context.targetId);
        }
    }

    function _moduleConfigurationHash() internal view override returns (bytes32) {
        return keccak256(abi.encode(REQUIRED_ACTION, EXPECTED_TARGET_ID));
    }
}

contract M14ActionRejectingEvidencePolicyModule is IAVAEvidencePolicyModule, RuleModuleIdentity {
    bytes32 public immutable REJECTED_ACTION;

    constructor(bytes32 rejectedAction) {
        REJECTED_ACTION = rejectedAction;
    }

    function validateEvidence(IAVAApplicationModule.EvidenceContext calldata) external pure {}

    function validateEvidenceUse(IAVAApplicationModule.EvidenceUseContext calldata context) external view {
        if (context.actionKey == REJECTED_ACTION) revert AVACoreTypes.InvalidState(context.targetId);
    }

    function _moduleConfigurationHash() internal view override returns (bytes32) {
        return REJECTED_ACTION;
    }
}

contract M14ActionRejectingEvidenceLifecycleModule is IAVAEvidenceLifecycleModule, RuleModuleIdentity {
    bytes32 public immutable REJECTED_ACTION;

    constructor(bytes32 rejectedAction) {
        REJECTED_ACTION = rejectedAction;
    }

    function validateEvidenceLifecycle(EvidenceLifecycleContext calldata) external pure {}

    function validateEvidenceUse(IAVAApplicationModule.EvidenceUseContext calldata context) external view {
        if (context.actionKey == REJECTED_ACTION) revert AVACoreTypes.InvalidState(context.targetId);
    }

    function _moduleConfigurationHash() internal view override returns (bytes32) {
        return REJECTED_ACTION;
    }
}

contract M14PeerReviewAppTest is M14ApplicationFixture, M14CorePackageFixture {
    M14PerformanceVm private constant PERFORMANCE_VM =
        M14PerformanceVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct StandingZKFixture {
        AVAStandingZKProofExtension proofExtension;
        AVAStandingZKCredentialExtension credentialExtension;
        uint256 statementId;
        IZKProofVerifier.SchnorrProof proof;
    }

    struct AnonymousChallengeFixture {
        M14PeerReviewActor challenger;
        AVAPrivacyProofExtension proofExtension;
        uint256 challengePackageId;
        uint256 evidenceId;
        bytes32 subjectId;
        IZKProofVerifier.SchnorrProof proof;
    }

    struct ValueLifecycleScenario {
        M14PeerReviewActor protocolActor;
        bytes32 protocolSubject;
        uint256 rewardId;
        uint256 restorableRewardId;
        uint256 stateId;
        uint256 settlementId;
    }

    struct CrossStateRecoveryScenario {
        M14PeerReviewActor protocolActor;
        bytes32 protocolSubject;
        AVAPenaltyRestorationExtension penaltyExtension;
        AVAValueLifecycleExtension lifecycleExtension;
        uint256 originStateId;
        uint256 originEvidenceId;
        uint256 originSettlementId;
    }

    bytes32 private constant WORKFLOW = keccak256("m14.peer-review.workflow");
    bytes32 private constant CHALLENGE_WORKFLOW = keccak256("m14.peer-review.challenge-workflow");
    bytes32 private constant M14_AUTHOR_SUBJECT = keccak256("m14.peer-review.author-subject");
    bytes32 private constant M14_REVIEWER_SUBJECT = keccak256("m14.peer-review.reviewer-subject");
    bytes32 private constant M14_EDITOR_SUBJECT = keccak256("m14.peer-review.editor-subject");
    bytes32 private constant M14_PANEL_SUBJECT = keccak256("m14.peer-review.panel-subject");
    bytes32 private constant M14_CHALLENGER_SUBJECT = keccak256("m14.peer-review.challenger-subject");
    bytes32 private constant PACKAGE_ROLE = keccak256("m14.peer-review.package-role");
    bytes32 private constant PACKAGE_SUBJECT = keccak256("m14.peer-review.package-subject");
    bytes32 private constant PACKAGE_COMPATIBILITY = keccak256("m14.peer-review.compatibility");

    AVAIdentityRegistry private coreIdentityRegistry;
    AVAAuthorityMatrix private coreAuthorityMatrix;
    AVADisclosurePolicyRegistry private coreDisclosureRegistry;
    AVAEvidenceRegistry private coreEvidenceRegistry;
    AVACoreRulePackageRegistry private corePackageRegistry;
    AVAGovernanceKernel private governanceKernel;
    PeerReviewApplicationModule private peerReviewModule;
    AVAChallengeExtension private challengeExtension;
    AVAAuditReceiptExtension private auditExtension;
    M14PeerReviewActor private authorActor;
    M14PeerReviewActor private reviewerActorV2;
    M14PeerReviewActor private editorActorV2;
    M14PeerReviewActor private panelActorV2;
    M14PeerReviewActor private challengerActorV2;
    uint256 private policyId;
    uint256 private packageId;

    function setUp() public override {
        super.setUp();
        coreIdentityRegistry = new AVAIdentityRegistry(applicationRegistry);
        coreAuthorityMatrix = new AVAAuthorityMatrix(applicationRegistry, coreIdentityRegistry);
        coreIdentityRegistry.assignSubject(
            address(this), PeerReviewTypes.APP_ID, PACKAGE_ROLE, PACKAGE_SUBJECT, "ipfs://m14-peer-package-subject"
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PACKAGE_ROLE, AVACoreTypes.ACTION_REGISTER_RULE_PACKAGE, true
        );
        corePackageRegistry = new AVACoreRulePackageRegistry(applicationRegistry, coreAuthorityMatrix);
        peerReviewModule = new PeerReviewApplicationModule();
        packageId = corePackageRegistry.registerRulePackage(
            _corePackageInput(
                PeerReviewTypes.APP_ID,
                WORKFLOW,
                PACKAGE_ROLE,
                PACKAGE_SUBJECT,
                1,
                PACKAGE_COMPATIBILITY,
                "ipfs://m14-peer-review-package"
            ),
            _peerReviewBindings(peerReviewModule)
        );
        coreDisclosureRegistry = new AVADisclosurePolicyRegistry(applicationRegistry, coreAuthorityMatrix);
        coreEvidenceRegistry = new AVAEvidenceRegistry(
            coreAuthorityMatrix, coreIdentityRegistry, corePackageRegistry, coreDisclosureRegistry
        );
        governanceKernel = new AVAGovernanceKernel(
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            coreDisclosureRegistry,
            new AVAWorkflowPolicyRouter(corePackageRegistry, coreEvidenceRegistry, coreDisclosureRegistry)
        );

        authorActor = new M14PeerReviewActor();
        reviewerActorV2 = new M14PeerReviewActor();
        editorActorV2 = new M14PeerReviewActor();
        panelActorV2 = new M14PeerReviewActor();
        challengerActorV2 = new M14PeerReviewActor();
        coreIdentityRegistry.assignSubject(
            address(authorActor),
            PeerReviewTypes.APP_ID,
            PeerReviewTypes.ROLE_AUTHOR,
            M14_AUTHOR_SUBJECT,
            "ipfs://m14-author"
        );
        coreIdentityRegistry.assignSubject(
            address(reviewerActorV2),
            PeerReviewTypes.APP_ID,
            PeerReviewTypes.ROLE_REVIEWER,
            M14_REVIEWER_SUBJECT,
            "ipfs://m14-reviewer"
        );
        coreIdentityRegistry.assignSubject(
            address(editorActorV2),
            PeerReviewTypes.APP_ID,
            PeerReviewTypes.ROLE_EDITOR,
            M14_EDITOR_SUBJECT,
            "ipfs://m14-editor"
        );
        coreIdentityRegistry.assignSubject(
            address(panelActorV2),
            PeerReviewTypes.APP_ID,
            PeerReviewTypes.ROLE_PANEL,
            M14_PANEL_SUBJECT,
            "ipfs://m14-panel"
        );
        coreIdentityRegistry.assignSubject(
            address(challengerActorV2),
            PeerReviewTypes.APP_ID,
            PeerReviewTypes.ROLE_CHALLENGER,
            M14_CHALLENGER_SUBJECT,
            "ipfs://m14-challenger"
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_AUTHOR, AVACoreTypes.ACTION_REGISTER_GOVERNED_OBJECT, true
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_REVIEWER, AVACoreTypes.ACTION_REGISTER_GOVERNED_OBJECT, true
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_CHALLENGER, AVACoreTypes.ACTION_REGISTER_GOVERNED_OBJECT, true
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_EDITOR, AVACoreTypes.ACTION_FORM_RECOGNISED_STATE, true
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_CHALLENGER, AVACoreTypes.ACTION_FORM_RECOGNISED_STATE, true
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_EDITOR, AVACoreTypes.ACTION_TRANSITION_RECOGNISED_STATE, true
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_VEST_RECOGNISED_STATE, true
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_CHALLENGER, AVACoreTypes.ACTION_FILE_CHALLENGE, true
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_EDITOR, AVACoreTypes.ACTION_SCREEN_CHALLENGE, true
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_RESOLVE_CHALLENGE, true
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_APPLY_RESTORATION, true
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_CLOSE_CHALLENGE, true
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_EDITOR, AVACoreTypes.ACTION_REGISTER_DISCLOSURE_POLICY, true
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_AUTHOR, AVACoreTypes.ACTION_REGISTER_EVIDENCE, true
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_REVIEWER, AVACoreTypes.ACTION_REGISTER_EVIDENCE, true
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_CHALLENGER, AVACoreTypes.ACTION_REGISTER_EVIDENCE, true
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_RECORD_EVIDENCE_LIFECYCLE, true
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_RECORD_AUDIT_RECEIPT, true
        );
        policyId = editorActorV2.registerPolicy(
            coreDisclosureRegistry, PeerReviewTypes.ROLE_EDITOR, M14_EDITOR_SUBJECT, keccak256("m14-peer-review-policy")
        );
        challengeExtension = new AVAChallengeExtension(
            governanceKernel, coreAuthorityMatrix, coreIdentityRegistry, corePackageRegistry, coreEvidenceRegistry
        );
        auditExtension = new AVAAuditReceiptExtension(
            governanceKernel,
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            coreDisclosureRegistry,
            address(challengeExtension)
        );
        governanceKernel.bindSourceBoundTransitionRequester(packageId, address(challengeExtension));
        governanceKernel.bindTransitionGuard(packageId, address(challengeExtension));
    }

    function testM144PeerReviewFlowRunsThroughGenericCore() public {
        (uint256 manuscriptObjectId, uint256 reviewObjectId) = _registerManuscriptAndReview();
        require(
            governanceKernel.getGovernedObject(reviewObjectId).parentObjectId == manuscriptObjectId,
            "review parent missing"
        );

        uint256 stateId = editorActorV2.formState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateFormationInput({
                governedObjectId: reviewObjectId,
                roleKey: PeerReviewTypes.ROLE_EDITOR,
                authorityId: M14_EDITOR_SUBJECT,
                stage: AVACoreTypes.Stage.Verification,
                status: AVACoreTypes.RecognisedStateStatus.Provisional,
                reasonHash: keccak256("m14-provisional-review"),
                reasonURI: "ipfs://m14-provisional-review"
            })
        );
        editorActorV2.transitionState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_EDITOR,
                authorityId: M14_EDITOR_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Challengeable,
                reasonHash: keccak256("m14-review-challengeable"),
                reasonURI: "ipfs://m14-review-challengeable"
            })
        );
        uint256 vestingTransitionId = panelActorV2.vestState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Vested,
                reasonHash: keccak256("m14-review-vested"),
                reasonURI: "ipfs://m14-review-vested"
            })
        );

        AVACoreTypes.RecognisedStateRecord memory state = governanceKernel.getRecognisedState(stateId);
        require(state.status == AVACoreTypes.RecognisedStateStatus.Vested, "review did not vest");
        require(state.subjectId == M14_REVIEWER_SUBJECT, "reviewer subject missing");
        require(state.packageId == packageId, "peer review package missing");
        require(state.lastTransitionId == vestingTransitionId, "vesting lineage missing");
    }

    function testParityAuditReceiptSupportsChallengeTransitionTarget() public {
        uint256 stateId = _createM14ChallengeableReviewState();
        uint256 challengeId = _fileChallenge(stateId, "parity-challenge-transition-audit");
        uint256 challengeTransitionId = editorActorV2.screenChallenge(
            challengeExtension, challengeId, PeerReviewTypes.ROLE_EDITOR, M14_EDITOR_SUBJECT
        );
        AVAChallengeExtension.ChallengeRecord memory challenge = challengeExtension.getChallenge(challengeId);
        uint256 auditId = panelActorV2.recordAudit(
            auditExtension,
            AVAAuditReceiptExtension.AuditInput({
                targetKind: AVAAuditReceiptExtension.AuditTargetKind.ChallengeTransition,
                targetId: challengeTransitionId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                subjectId: M14_CHALLENGER_SUBJECT,
                evidenceId: challenge.evidenceReceiptId,
                auditTypeKey: keccak256("m14-challenge-transition-audit"),
                attestationHash: keccak256("m14-challenge-transition-attestation"),
                reasonHash: keccak256("m14-challenge-transition-audit-reason"),
                uri: "ipfs://m14-challenge-transition-audit"
            })
        );
        AVAAuditReceiptExtension.AuditReceipt memory receipt = auditExtension.getAuditReceipt(auditId);
        require(
            receipt.targetKind == AVAAuditReceiptExtension.AuditTargetKind.ChallengeTransition
                && receipt.targetId == challengeTransitionId && receipt.packageId == challenge.packageId,
            "challenge transition audit binding missing"
        );
        require(
            receipt.recognisedStateId == challenge.challengeRecognisedStateId,
            "challenge transition audit bound to target review state"
        );
        require(receipt.subjectId == challenge.challengerSubjectId, "challenge transition audit lost challenger");
    }

    function testParityPeerReviewApplicationDistinguishesReviewAndChallengeParentWorkflows() public view {
        IAVAApplicationModule.GovernedObjectContext memory context = IAVAApplicationModule.GovernedObjectContext({
            appId: PeerReviewTypes.APP_ID,
            workflowKey: WORKFLOW,
            packageId: packageId,
            roleKey: PeerReviewTypes.ROLE_REVIEWER,
            objectTypeKey: PeerReviewTypes.OBJECT_REVIEW_CONTRIBUTION,
            objectCommitment: keccak256("parity-parent-workflow-review"),
            parentObjectId: 1,
            parentObjectTypeKey: PeerReviewTypes.OBJECT_MANUSCRIPT,
            parentWorkflowKey: CHALLENGE_WORKFLOW,
            parentPackageId: packageId,
            parentSubjectId: M14_AUTHOR_SUBJECT,
            subjectId: M14_REVIEWER_SUBJECT,
            evidenceReceiptId: 1,
            disclosurePolicyId: policyId,
            metadataHash: keccak256("parity-parent-workflow-review-metadata"),
            authorityId: M14_REVIEWER_SUBJECT,
            actor: address(reviewerActorV2)
        });
        try peerReviewModule.validateGovernedObject(context) {
            revert("review accepted manuscript parent from another workflow");
        } catch {}

        context.workflowKey = CHALLENGE_WORKFLOW;
        context.roleKey = PeerReviewTypes.ROLE_CHALLENGER;
        context.objectTypeKey = PeerReviewTypes.OBJECT_CHALLENGE;
        context.parentObjectTypeKey = PeerReviewTypes.OBJECT_REVIEW_CONTRIBUTION;
        context.parentWorkflowKey = WORKFLOW;
        context.subjectId = M14_CHALLENGER_SUBJECT;
        context.authorityId = M14_CHALLENGER_SUBJECT;
        context.actor = address(challengerActorV2);
        peerReviewModule.validateGovernedObject(context);
    }

    function testParityOptionalFieldPolicyCanRejectObjectAndFormationWithoutCoreChange() public {
        _activateCapabilityModule(
            AVACapabilityKeys.FIELD_POLICY,
            IRuleModuleIdentity(
                address(new M14RejectingFieldPolicyModule(AVACoreTypes.ACTION_REGISTER_GOVERNED_OBJECT))
            )
        );
        uint256 nextObjectIdBefore = governanceKernel.nextGovernedObjectId();
        bool accepted;
        try this.exposedRegisterManuscriptAndReview() returns (uint256, uint256) {
            accepted = true;
        } catch {}
        require(!accepted, "rejecting field policy allowed governed object");
        require(governanceKernel.nextGovernedObjectId() == nextObjectIdBefore, "rejected field policy wrote object");

        _activateCapabilityModule(
            AVACapabilityKeys.FIELD_POLICY,
            IRuleModuleIdentity(address(new M14RejectingFieldPolicyModule(AVACoreTypes.ACTION_FORM_RECOGNISED_STATE)))
        );
        (, uint256 reviewObjectId) = _registerManuscriptAndReview();
        uint256 nextStateIdBefore = governanceKernel.nextRecognisedStateId();
        accepted = false;
        try editorActorV2.formState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateFormationInput({
                governedObjectId: reviewObjectId,
                roleKey: PeerReviewTypes.ROLE_EDITOR,
                authorityId: M14_EDITOR_SUBJECT,
                stage: AVACoreTypes.Stage.Verification,
                status: AVACoreTypes.RecognisedStateStatus.Provisional,
                reasonHash: keccak256("parity-field-policy-rejected-formation"),
                reasonURI: "ipfs://parity-field-policy-rejected-formation"
            })
        ) returns (
            uint256
        ) {
            accepted = true;
        } catch {}
        require(!accepted, "rejecting field policy allowed recognised-state formation");
        require(
            governanceKernel.nextRecognisedStateId() == nextStateIdBefore, "rejected formation wrote recognised state"
        );
    }

    function testParityOptionalAntiAbusePolicyCanRejectChallengeAndDownstreamWithoutCoreChange() public {
        _activateCapabilityModule(
            AVACapabilityKeys.ANTI_ABUSE,
            IRuleModuleIdentity(address(new M14RejectingAntiAbusePolicyModule(AVACoreTypes.ACTION_FILE_CHALLENGE)))
        );
        uint256 stateId = _createM14ChallengeableReviewState();
        uint256 nextChallengeIdBefore = challengeExtension.nextChallengeId();
        bool accepted;
        try this.exposedFileChallenge(stateId, "parity-rejecting-anti-abuse") returns (uint256) {
            accepted = true;
        } catch {}
        require(!accepted, "rejecting anti-abuse policy allowed challenge");
        require(
            challengeExtension.nextChallengeId() == nextChallengeIdBefore, "rejected anti-abuse policy wrote challenge"
        );
    }

    function testParityOptionalAntiAbusePolicyCanRejectDownstreamRecordWithoutStorageChange() public {
        _activateCapabilityModule(
            AVACapabilityKeys.ANTI_ABUSE,
            IRuleModuleIdentity(
                address(new M14RejectingAntiAbusePolicyModule(AVACoreTypes.ACTION_RECORD_STANDING_UPDATE))
            )
        );
        uint256 stateId = _createM14ChallengeableReviewState();
        panelActorV2.vestState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Vested,
                reasonHash: keccak256("parity-anti-abuse-standing-vest"),
                reasonURI: "ipfs://parity-anti-abuse-standing-vest"
            })
        );
        (AVAStandingRecordExtension standingExtension,,) = _deployDownstreamExtensions();
        _authoriseDownstreamExtensions();
        uint256 nextStandingIdBefore = standingExtension.nextStandingUpdateId();
        bool accepted;
        try panelActorV2.recordStanding(
            standingExtension,
            AVAStandingRecordExtension.StandingInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                subjectId: M14_REVIEWER_SUBJECT,
                evidenceId: governanceKernel.getRecognisedState(stateId).evidenceReceiptId,
                dimensionKey: keccak256("parity-anti-abuse-standing"),
                delta: 1,
                reasonHash: keccak256("parity-anti-abuse-standing"),
                uri: "ipfs://parity-anti-abuse-standing"
            })
        ) returns (
            uint256
        ) {
            accepted = true;
        } catch {}
        require(!accepted, "rejecting anti-abuse policy allowed downstream record");
        require(
            standingExtension.nextStandingUpdateId() == nextStandingIdBefore,
            "rejected anti-abuse policy wrote downstream record"
        );
    }

    function testParityOptionalAntiAbusePolicyCanRejectAuditWithoutStorageChange() public {
        _activateCapabilityModule(
            AVACapabilityKeys.ANTI_ABUSE,
            IRuleModuleIdentity(
                address(new M14RejectingAntiAbusePolicyModule(AVACoreTypes.ACTION_RECORD_AUDIT_RECEIPT))
            )
        );
        uint256 stateId = _createM14ChallengeableReviewState();
        AVACoreTypes.RecognisedStateRecord memory state = governanceKernel.getRecognisedState(stateId);
        uint256 nextAuditIdBefore = auditExtension.nextAuditReceiptId();
        bool accepted;
        try panelActorV2.recordAudit(
            auditExtension,
            AVAAuditReceiptExtension.AuditInput({
                targetKind: AVAAuditReceiptExtension.AuditTargetKind.RecognisedState,
                targetId: stateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                subjectId: M14_REVIEWER_SUBJECT,
                evidenceId: state.evidenceReceiptId,
                auditTypeKey: keccak256("parity-anti-abuse-audit"),
                attestationHash: keccak256("parity-anti-abuse-attestation"),
                reasonHash: keccak256("parity-anti-abuse-audit-reason"),
                uri: "ipfs://parity-anti-abuse-audit"
            })
        ) returns (
            uint256
        ) {
            accepted = true;
        } catch {}
        require(!accepted, "rejecting anti-abuse policy allowed audit");
        require(auditExtension.nextAuditReceiptId() == nextAuditIdBefore, "rejected anti-abuse policy wrote audit");
    }

    function testParityStandingComputationCannotBypassPeerReviewApplicationRolePolicy() public {
        AVAStandingRevisionExtension revisionExtension = new AVAStandingRevisionExtension(governanceKernel);
        governanceKernel.bindPostTransitionHook(packageId, address(revisionExtension));
        uint256 stateId = _createM14ChallengeableReviewState();
        panelActorV2.vestState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Vested,
                reasonHash: keccak256("parity-app-policy-standing-vest"),
                reasonURI: "ipfs://parity-app-policy-standing-vest"
            })
        );
        AVAStandingComputationExtension computationExtension = new AVAStandingComputationExtension(
            governanceKernel,
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            revisionExtension
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_EDITOR, AVACoreTypes.ACTION_RECORD_STANDING_COMPUTATION, true
        );
        bool accepted;
        try editorActorV2.recordStandingComputation(
            computationExtension, _standingComputationInput(stateId, PeerReviewTypes.ROLE_EDITOR, M14_EDITOR_SUBJECT)
        ) returns (
            uint256
        ) {
            accepted = true;
        } catch {}
        require(!accepted, "standing computation bypassed application role policy");
        require(computationExtension.nextComputationId() == 1, "rejected computation wrote storage");
    }

    function testParityStandingComputationCannotBypassOptionalAntiAbusePolicy() public {
        _activateCapabilityModule(
            AVACapabilityKeys.ANTI_ABUSE,
            IRuleModuleIdentity(
                address(new M14RejectingAntiAbusePolicyModule(AVACoreTypes.ACTION_RECORD_STANDING_COMPUTATION))
            )
        );
        AVAStandingRevisionExtension revisionExtension = new AVAStandingRevisionExtension(governanceKernel);
        governanceKernel.bindPostTransitionHook(packageId, address(revisionExtension));
        uint256 stateId = _createM14ChallengeableReviewState();
        panelActorV2.vestState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Vested,
                reasonHash: keccak256("parity-anti-abuse-computation-vest"),
                reasonURI: "ipfs://parity-anti-abuse-computation-vest"
            })
        );
        AVAStandingComputationExtension computationExtension = new AVAStandingComputationExtension(
            governanceKernel,
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            revisionExtension
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_RECORD_STANDING_COMPUTATION, true
        );
        bool accepted;
        try panelActorV2.recordStandingComputation(
            computationExtension, _standingComputationInput(stateId, PeerReviewTypes.ROLE_PANEL, M14_PANEL_SUBJECT)
        ) returns (
            uint256
        ) {
            accepted = true;
        } catch {}
        require(!accepted, "standing computation bypassed anti-abuse policy");
        require(computationExtension.nextComputationId() == 1, "rejected computation wrote storage");
    }

    function testParityStandingCredentialCannotBypassPeerReviewApplicationRolePolicy() public {
        (AVAStandingCredentialExtension credentialExtension, uint256 computationId) = _standingCredentialFixture();
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_EDITOR, AVACoreTypes.ACTION_ISSUE_STANDING_CREDENTIAL, true
        );
        bool accepted;
        try editorActorV2.issueStandingCredential(
            credentialExtension,
            AVAStandingCredentialExtension.CredentialInput({
                computationId: computationId,
                roleKey: PeerReviewTypes.ROLE_EDITOR,
                authorityId: M14_EDITOR_SUBJECT,
                expiresAt: uint64(block.timestamp + 7 days),
                uri: "ipfs://parity-app-policy-standing-credential"
            })
        ) returns (
            uint256
        ) {
            accepted = true;
        } catch {}
        require(!accepted, "standing credential bypassed application role policy");
        require(credentialExtension.nextCredentialId() == 1, "rejected credential wrote storage");
    }

    function testParityStandingCredentialCannotBypassOptionalAntiAbusePolicy() public {
        _activateCapabilityModule(
            AVACapabilityKeys.ANTI_ABUSE,
            IRuleModuleIdentity(
                address(new M14RejectingAntiAbusePolicyModule(AVACoreTypes.ACTION_ISSUE_STANDING_CREDENTIAL))
            )
        );
        (AVAStandingCredentialExtension credentialExtension, uint256 computationId) = _standingCredentialFixture();
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_ISSUE_STANDING_CREDENTIAL, true
        );
        bool accepted;
        try panelActorV2.issueStandingCredential(
            credentialExtension,
            AVAStandingCredentialExtension.CredentialInput({
                computationId: computationId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                expiresAt: uint64(block.timestamp + 7 days),
                uri: "ipfs://parity-anti-abuse-standing-credential"
            })
        ) returns (
            uint256
        ) {
            accepted = true;
        } catch {}
        require(!accepted, "standing credential bypassed anti-abuse policy");
        require(credentialExtension.nextCredentialId() == 1, "rejected credential wrote storage");
    }

    function testParityStandingZKProofCannotBypassPeerReviewApplicationRolePolicy() public {
        StandingZKFixture memory fixture = _standingZKFixture();
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_EDITOR, AVACoreTypes.ACTION_RECORD_STANDING_ZK_PROOF, true
        );
        bool accepted;
        try editorActorV2.registerStandingZKProof(
            fixture.proofExtension,
            AVAStandingZKProofExtension.ProofInput({
                statementId: fixture.statementId,
                roleKey: PeerReviewTypes.ROLE_EDITOR,
                authorityId: M14_EDITOR_SUBJECT,
                proof: fixture.proof,
                uri: "ipfs://parity-app-policy-standing-zk-proof"
            })
        ) returns (
            uint256
        ) {
            accepted = true;
        } catch {}
        require(!accepted, "standing ZK proof bypassed application role policy");
        require(fixture.proofExtension.nextProofReceiptId() == 1, "rejected ZK proof wrote storage");
    }

    function testParityStandingFormulaCannotBypassOptionalAntiAbusePolicy() public {
        _activateCapabilityModule(
            AVACapabilityKeys.ANTI_ABUSE,
            IRuleModuleIdentity(
                address(new M14RejectingAntiAbusePolicyModule(AVACoreTypes.ACTION_REGISTER_STANDING_FORMULA))
            )
        );
        AVAStandingRevisionExtension revisionExtension = new AVAStandingRevisionExtension(governanceKernel);
        M14PeerReviewAlwaysValidVerifier verifier = new M14PeerReviewAlwaysValidVerifier();
        AVAStandingProvenanceExtension provenanceExtension = new AVAStandingProvenanceExtension(
            governanceKernel,
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            coreDisclosureRegistry,
            revisionExtension
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_REGISTER_STANDING_FORMULA, true
        );
        bool accepted;
        try panelActorV2.registerStandingFormula(
            provenanceExtension,
            AVAStandingProvenanceExtension.FormulaInput({
                appId: PeerReviewTypes.APP_ID,
                workflowKey: WORKFLOW,
                packageId: packageId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                vectorKey: keccak256("parity-rejected-standing-formula-vector"),
                formulaVersion: 1,
                computationRuleHash: keccak256("parity-rejected-standing-formula-rule"),
                sourceSetPolicyHash: keccak256("parity-rejected-standing-formula-source"),
                decayPolicyHash: keccak256("parity-rejected-standing-formula-decay"),
                capPolicyHash: keccak256("parity-rejected-standing-formula-cap"),
                restorationPolicyHash: keccak256("parity-rejected-standing-formula-restoration"),
                verifier: address(verifier),
                proofDomainHash: verifier.proofDomain(),
                uri: "ipfs://parity-rejected-standing-formula"
            })
        ) returns (
            uint256
        ) {
            accepted = true;
        } catch {}
        require(!accepted, "standing formula bypassed anti-abuse policy");
        require(provenanceExtension.nextFormulaId() == 1, "rejected formula wrote storage");
    }

    function testParityStandingZKProofCannotBypassOptionalAntiAbusePolicy() public {
        _activateCapabilityModule(
            AVACapabilityKeys.ANTI_ABUSE,
            IRuleModuleIdentity(
                address(new M14RejectingAntiAbusePolicyModule(AVACoreTypes.ACTION_RECORD_STANDING_ZK_PROOF))
            )
        );
        StandingZKFixture memory fixture = _standingZKFixture();
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_RECORD_STANDING_ZK_PROOF, true
        );
        bool accepted;
        try panelActorV2.registerStandingZKProof(
            fixture.proofExtension,
            AVAStandingZKProofExtension.ProofInput({
                statementId: fixture.statementId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                proof: fixture.proof,
                uri: "ipfs://parity-anti-abuse-standing-zk-proof"
            })
        ) returns (
            uint256
        ) {
            accepted = true;
        } catch {}
        require(!accepted, "standing ZK proof bypassed anti-abuse policy");
        require(fixture.proofExtension.nextProofReceiptId() == 1, "rejected ZK proof wrote storage");
    }

    function testStandingZKProofFailsClosedWhenVerifierRuntimeChanges() public {
        StandingZKFixture memory fixture = _standingZKFixture();
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_RECORD_STANDING_ZK_PROOF, true
        );
        uint256 proofReceiptId = panelActorV2.registerStandingZKProof(
            fixture.proofExtension,
            AVAStandingZKProofExtension.ProofInput({
                statementId: fixture.statementId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                proof: fixture.proof,
                uri: "ipfs://standing-zk-proof-before-verifier-drift"
            })
        );
        require(fixture.proofExtension.isProofUsable(proofReceiptId), "fresh proof unusable");

        PERFORMANCE_VM.etch(address(fixture.proofExtension.VERIFIER()), hex"00");

        require(!fixture.proofExtension.isProofUsable(proofReceiptId), "verifier drift left proof usable");
        try panelActorV2.registerStandingZKProof(
            fixture.proofExtension,
            AVAStandingZKProofExtension.ProofInput({
                statementId: fixture.statementId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                proof: fixture.proof,
                uri: "ipfs://standing-zk-proof-after-verifier-drift"
            })
        ) {
            revert("verifier drift accepted new proof");
        } catch {}
        require(fixture.proofExtension.nextProofReceiptId() == 2, "verifier drift wrote proof receipt");
    }

    function testParityStandingZKCredentialCannotBypassPeerReviewApplicationRolePolicy() public {
        StandingZKFixture memory fixture = _standingZKFixture();
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_RECORD_STANDING_ZK_PROOF, true
        );
        uint256 proofReceiptId = panelActorV2.registerStandingZKProof(
            fixture.proofExtension,
            AVAStandingZKProofExtension.ProofInput({
                statementId: fixture.statementId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                proof: fixture.proof,
                uri: "ipfs://parity-standing-zk-proof"
            })
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_EDITOR, AVACoreTypes.ACTION_ISSUE_STANDING_ZK_CREDENTIAL, true
        );
        bool accepted;
        try editorActorV2.issueStandingZKCredential(
            fixture.credentialExtension,
            AVAStandingZKCredentialExtension.CredentialInput({
                proofReceiptId: proofReceiptId,
                roleKey: PeerReviewTypes.ROLE_EDITOR,
                authorityId: M14_EDITOR_SUBJECT,
                credentialCommitment: keccak256("parity-app-policy-standing-zk-credential"),
                expiresAt: uint64(block.timestamp + 7 days),
                uri: "ipfs://parity-app-policy-standing-zk-credential"
            })
        ) returns (
            uint256
        ) {
            accepted = true;
        } catch {}
        require(!accepted, "standing ZK credential bypassed application role policy");
        require(fixture.credentialExtension.nextCredentialId() == 1, "rejected ZK credential wrote storage");
    }

    function exposedRegisterManuscriptAndReview() external returns (uint256, uint256) {
        return _registerManuscriptAndReview();
    }

    function exposedFileChallenge(uint256 stateId, string calldata seed) external returns (uint256) {
        return _fileChallenge(stateId, seed);
    }

    function testM144PeerReviewCannotVestBeforeChallengeableState() public {
        (, uint256 reviewObjectId) = _registerManuscriptAndReview();
        uint256 stateId = editorActorV2.formState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateFormationInput({
                governedObjectId: reviewObjectId,
                roleKey: PeerReviewTypes.ROLE_EDITOR,
                authorityId: M14_EDITOR_SUBJECT,
                stage: AVACoreTypes.Stage.Verification,
                status: AVACoreTypes.RecognisedStateStatus.Provisional,
                reasonHash: keccak256("m144-pre-challengeable-provisional"),
                reasonURI: "ipfs://m144-pre-challengeable-provisional"
            })
        );
        uint256 nextTransitionIdBefore = governanceKernel.nextTransitionId();
        try panelActorV2.vestState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Vested,
                reasonHash: keccak256("m144-premature-vest"),
                reasonURI: "ipfs://m144-premature-vest"
            })
        ) {
            revert("peer review vested before challengeable state");
        } catch {}
        require(governanceKernel.nextTransitionId() == nextTransitionIdBefore, "premature vest wrote transition");
        require(
            governanceKernel.getRecognisedState(stateId).status == AVACoreTypes.RecognisedStateStatus.Provisional,
            "premature vest changed state"
        );
    }

    function testM144UnfiledChallengeStateCannotUseGenericTransitionEvenWhenPermissionIsGranted() public {
        uint256 targetStateId = _createM14ChallengeableReviewState();
        uint256 challengeEvidenceId = _registerChallengeEvidence("m144-unfiled-generic-transition");
        uint256 challengeStateId = _createChallengeRecognisedState(
            challengerActorV2,
            M14_CHALLENGER_SUBJECT,
            WORKFLOW,
            packageId,
            targetStateId,
            challengeEvidenceId,
            "m144-unfiled-generic-transition"
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID,
            PeerReviewTypes.ROLE_CHALLENGER,
            AVACoreTypes.ACTION_TRANSITION_RECOGNISED_STATE,
            true
        );
        uint256 nextTransitionIdBefore = governanceKernel.nextTransitionId();
        uint256 nextChallengeIdBefore = challengeExtension.nextChallengeId();
        bool accepted;
        try challengerActorV2.transitionState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: challengeStateId,
                roleKey: PeerReviewTypes.ROLE_CHALLENGER,
                authorityId: M14_CHALLENGER_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Challengeable,
                reasonHash: keccak256("m144-unfiled-generic-transition"),
                reasonURI: "ipfs://m144-unfiled-generic-transition"
            })
        ) returns (
            uint256
        ) {
            accepted = true;
        } catch {}

        require(!accepted, "unfiled challenge used generic transition");
        require(governanceKernel.nextTransitionId() == nextTransitionIdBefore, "unfiled challenge wrote transition");
        require(
            challengeExtension.nextChallengeId() == nextChallengeIdBefore, "unfiled challenge wrote lifecycle record"
        );
        require(
            governanceKernel.getRecognisedState(challengeStateId).status
                == AVACoreTypes.RecognisedStateStatus.Registered,
            "unfiled challenge changed status"
        );
        require(
            challengeExtension.openChallengeCountByRecognisedState(targetStateId) == 0,
            "unfiled challenge changed open count"
        );
    }

    function testM144PeerReviewModuleRejectsWrongRoleAndParentRelationship() public {
        uint256 manuscriptEvidenceId = _registerAuthorEvidence("m14-module-parent");
        uint256 manuscriptObjectId = authorActor.registerObject(
            governanceKernel,
            _objectInput(
                PeerReviewTypes.ROLE_AUTHOR,
                PeerReviewTypes.OBJECT_MANUSCRIPT,
                keccak256("m14-module-parent"),
                0,
                M14_AUTHOR_SUBJECT,
                manuscriptEvidenceId
            )
        );
        uint256 authorEvidenceId = _registerAuthorEvidence("m14-author-wrong-role");
        AVAGovernanceKernel.GovernedObjectInput memory wrongRole = _objectInput(
            PeerReviewTypes.ROLE_AUTHOR,
            PeerReviewTypes.OBJECT_REVIEW_CONTRIBUTION,
            keccak256("m14-wrong-role-review"),
            manuscriptObjectId,
            M14_AUTHOR_SUBJECT,
            authorEvidenceId
        );
        try authorActor.registerObject(governanceKernel, wrongRole) {
            revert("author role registered review contribution");
        } catch {}

        uint256 reviewEvidenceId = _registerReviewerEvidence("m14-review-without-parent");
        AVAGovernanceKernel.GovernedObjectInput memory missingParent = _objectInput(
            PeerReviewTypes.ROLE_REVIEWER,
            PeerReviewTypes.OBJECT_REVIEW_CONTRIBUTION,
            keccak256("m14-review-without-parent"),
            0,
            M14_REVIEWER_SUBJECT,
            reviewEvidenceId
        );
        try reviewerActorV2.registerObject(governanceKernel, missingParent) {
            revert("review without manuscript parent accepted");
        } catch {}
    }

    function testM144HistoricalPeerReviewObjectsRemainPinnedAfterPackageSupersession() public {
        (, uint256 oldReviewObjectId) = _registerManuscriptAndReview();
        uint256 oldPackageId = packageId;
        uint256 replacementPackageId = _supersedePackage("ipfs://m14-peer-review-package-v2");

        require(governanceKernel.getGovernedObject(oldReviewObjectId).packageId == oldPackageId, "old object rewritten");
        require(
            corePackageRegistry.getActivePackageId(PeerReviewTypes.APP_ID, WORKFLOW) == replacementPackageId,
            "new package not active"
        );

        packageId = replacementPackageId;
        uint256 evidenceId = _registerReviewerEvidence("m14-new-package-review");
        AVAGovernanceKernel.GovernedObjectInput memory newReview = _objectInput(
            PeerReviewTypes.ROLE_REVIEWER,
            PeerReviewTypes.OBJECT_REVIEW_CONTRIBUTION,
            keccak256("m14-new-package-review"),
            governanceKernel.getGovernedObject(oldReviewObjectId).parentObjectId,
            M14_REVIEWER_SUBJECT,
            evidenceId
        );
        newReview.packageId = replacementPackageId;
        uint256 newReviewObjectId = reviewerActorV2.registerObject(governanceKernel, newReview);
        require(
            governanceKernel.getGovernedObject(newReviewObjectId).packageId == replacementPackageId,
            "new object did not use active package"
        );
    }

    function testHistoricalChallengeStateCanFileAfterWorkflowPackageSupersession() public {
        uint256 targetStateId = _createM14ChallengeableReviewState();
        uint256 historicalPackageId = packageId;
        uint256 challengeEvidenceId = _registerChallengeEvidence("historical-challenge-before-supersession");
        uint256 challengeStateId = _createChallengeRecognisedState(
            challengerActorV2,
            M14_CHALLENGER_SUBJECT,
            WORKFLOW,
            historicalPackageId,
            targetStateId,
            challengeEvidenceId,
            "historical-challenge-before-supersession"
        );
        uint256 replacementPackageId = _supersedePackage("ipfs://m14-peer-review-package-after-challenge-state");

        uint256 challengeId = challengerActorV2.fileChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeFilingInput({
                appId: PeerReviewTypes.APP_ID,
                workflowKey: WORKFLOW,
                packageId: historicalPackageId,
                challengeRecognisedStateId: challengeStateId,
                challengedRecognisedStateId: targetStateId,
                roleKey: PeerReviewTypes.ROLE_CHALLENGER,
                reasonHash: keccak256("historical-challenge-after-supersession"),
                reasonURI: "ipfs://historical-challenge-after-supersession"
            })
        );

        require(
            corePackageRegistry.getActivePackageId(PeerReviewTypes.APP_ID, WORKFLOW) == replacementPackageId,
            "replacement package not active"
        );
        require(challengeExtension.getChallenge(challengeId).packageId == historicalPackageId, "challenge repinned");
        require(
            governanceKernel.getRecognisedState(challengeStateId).packageId == historicalPackageId,
            "challenge state repinned"
        );
    }

    function testM144GenericCoreExposesNoPeerReviewWriteSelectors() public {
        (bool manuscriptSuccess,) = address(governanceKernel)
            .call(abi.encodeWithSignature("registerManuscript(bytes32,string)", bytes32(uint256(1)), "ipfs://invalid"));
        (bool reviewSuccess,) = address(governanceKernel)
            .call(
                abi.encodeWithSignature(
                    "registerReviewContribution(uint256,bytes32,uint256)", 1, M14_REVIEWER_SUBJECT, 1
                )
            );
        require(!manuscriptSuccess && !reviewSuccess, "generic Core exposed Peer Review selector");
    }

    function testM144ChallengeCorrectionAndRestorationOperateOnGenericRecognisedState() public {
        uint256 stateId = _createM14ChallengeableReviewState();
        AVACoreTypes.RecognisedStateRecord memory beforeState = governanceKernel.getRecognisedState(stateId);
        uint256 challengeEvidenceId = challengerActorV2.registerEvidence(
            coreEvidenceRegistry,
            WORKFLOW,
            packageId,
            PeerReviewTypes.ROLE_CHALLENGER,
            M14_CHALLENGER_SUBJECT,
            keccak256("m14-peer-review-challenge-evidence"),
            policyId
        );
        uint256 challengeStateId = _createChallengeRecognisedState(
            challengerActorV2,
            M14_CHALLENGER_SUBJECT,
            WORKFLOW,
            packageId,
            stateId,
            challengeEvidenceId,
            "m14-file-challenge"
        );
        uint256 challengeId = challengerActorV2.fileChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeFilingInput({
                appId: PeerReviewTypes.APP_ID,
                workflowKey: WORKFLOW,
                packageId: packageId,
                challengeRecognisedStateId: challengeStateId,
                challengedRecognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_CHALLENGER,
                reasonHash: keccak256("m14-file-challenge"),
                reasonURI: "ipfs://m14-file-challenge"
            })
        );
        require(
            governanceKernel.getRecognisedState(stateId).lastTransitionId == beforeState.lastTransitionId,
            "raw challenge mutated target state"
        );

        editorActorV2.screenChallenge(challengeExtension, challengeId, PeerReviewTypes.ROLE_EDITOR, M14_EDITOR_SUBJECT);
        panelActorV2.resolveChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeResolutionInput({
                challengeId: challengeId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                outcome: AVAChallengeExtension.ChallengeOutcome.Upheld,
                correctionStatus: AVACoreTypes.RecognisedStateStatus.Downgraded,
                reasonHash: keccak256("m14-upheld-challenge"),
                reasonURI: "ipfs://m14-upheld-challenge"
            })
        );
        AVACoreTypes.RecognisedStateRecord memory corrected = governanceKernel.getRecognisedState(stateId);
        require(corrected.status == AVACoreTypes.RecognisedStateStatus.Downgraded, "upheld correction missing");
        require(corrected.lastTransitionId != beforeState.lastTransitionId, "correction ledger missing");

        panelActorV2.makeRestorationAvailable(
            challengeExtension,
            challengeId,
            PeerReviewTypes.ROLE_PANEL,
            M14_PANEL_SUBJECT,
            keccak256("m14-restoration-available"),
            "ipfs://m14-restoration-available"
        );
        require(
            challengeExtension.getChallenge(challengeId).status
                == AVAChallengeExtension.ChallengeStatus.RestorationAvailable,
            "restoration availability missing"
        );
        panelActorV2.restoreChallenge(
            challengeExtension,
            challengeId,
            PeerReviewTypes.ROLE_PANEL,
            M14_PANEL_SUBJECT,
            keccak256("m14-restoration"),
            "ipfs://m14-restoration"
        );
        AVACoreTypes.RecognisedStateRecord memory restored = governanceKernel.getRecognisedState(stateId);
        require(
            restored.status == AVACoreTypes.RecognisedStateStatus.Challengeable,
            "challengeable lineage did not restore to challengeable"
        );
        require(restored.lastTransitionId != corrected.lastTransitionId, "restoration overwrote history");
        require(
            challengeExtension.getChallenge(challengeId).status == AVAChallengeExtension.ChallengeStatus.Closed,
            "applied restoration did not close challenge"
        );
        require(challengeExtension.openChallengeCountByRecognisedState(stateId) == 0, "restoration left challenge open");
    }

    function testCanonicalUpheldChallengeVestsItsOwnRecognisedStateWithExplicitLineage() public {
        uint256 targetStateId = _createM14ChallengeableReviewState();
        uint256 challengeId = _fileChallenge(targetStateId, "canonical-recursive-lineage");
        AVAChallengeExtension.ChallengeRecord memory filed = challengeExtension.getChallenge(challengeId);
        AVACoreTypes.RecognisedStateRecord memory filedChallengeState =
            governanceKernel.getRecognisedState(filed.challengeRecognisedStateId);
        AVAChallengeExtension.ChallengeTransitionRecord memory filingTransition =
            challengeExtension.getChallengeTransition(filed.lastTransitionId);

        require(
            filed.challengeGovernedObjectId == filedChallengeState.governedObjectId, "challenge object lineage missing"
        );
        require(filed.packageId == filedChallengeState.packageId, "challenge package lineage missing");
        require(filed.evidenceReceiptId == filedChallengeState.evidenceReceiptId, "challenge evidence lineage missing");
        require(
            filedChallengeState.status == AVACoreTypes.RecognisedStateStatus.Challengeable,
            "filed challenge state not challengeable"
        );
        require(
            filingTransition.challengeRecognisedStateId == filed.challengeRecognisedStateId,
            "challenge transition lost own recognised state"
        );
        require(
            filingTransition.challengeStateTransitionIdAfter == filed.challengeStateTransitionIdAtFiling,
            "challenge transition lost filing state version"
        );

        AVAGovernanceKernel.RecognisedStateTransitionInput memory directVesting =
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: filed.challengeRecognisedStateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Vested,
                reasonHash: keccak256("canonical-direct-challenge-vesting"),
                reasonURI: "ipfs://canonical-direct-challenge-vesting"
            });
        try panelActorV2.vestState(governanceKernel, directVesting) {
            revert("decision-bound challenge state vested outside challenge resolution");
        } catch {}

        editorActorV2.screenChallenge(challengeExtension, challengeId, PeerReviewTypes.ROLE_EDITOR, M14_EDITOR_SUBJECT);
        uint256 resolutionTransitionId = panelActorV2.resolveChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeResolutionInput({
                challengeId: challengeId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                outcome: AVAChallengeExtension.ChallengeOutcome.Upheld,
                correctionStatus: AVACoreTypes.RecognisedStateStatus.Downgraded,
                reasonHash: keccak256("canonical-recursive-lineage-resolution"),
                reasonURI: "ipfs://canonical-recursive-lineage-resolution"
            })
        );
        AVAChallengeExtension.ChallengeRecord memory resolved = challengeExtension.getChallenge(challengeId);
        AVACoreTypes.RecognisedStateRecord memory resolvedChallengeState =
            governanceKernel.getRecognisedState(resolved.challengeRecognisedStateId);
        AVAChallengeExtension.ChallengeTransitionRecord memory resolutionTransition =
            challengeExtension.getChallengeTransition(resolutionTransitionId);
        AVACoreTypes.RecognisedStateTransitionRecord memory challengeStateTransition =
            governanceKernel.getRecognisedStateTransition(resolvedChallengeState.lastTransitionId);

        require(
            resolvedChallengeState.status == AVACoreTypes.RecognisedStateStatus.Vested,
            "upheld challenge did not vest own recognised state"
        );
        require(
            resolutionTransition.challengeStateTransitionIdBefore == filed.challengeStateTransitionIdAtFiling,
            "resolution lost prior challenge state version"
        );
        require(
            resolutionTransition.challengeStateTransitionIdAfter == resolvedChallengeState.lastTransitionId,
            "resolution lost vested challenge state version"
        );
        require(
            challengeStateTransition.sourceRecordId == challengeId
                && challengeStateTransition.decisionPackageId == resolved.packageId,
            "challenge-state vesting lost decision source"
        );
    }

    function testCanonicalSuccessfulChallengeDownstreamRecordsUseChallengeState() public {
        uint256 targetStateId = _createM14ChallengeableReviewState();
        uint256 challengeId = _fileChallenge(targetStateId, "canonical-challenge-downstream");
        editorActorV2.screenChallenge(challengeExtension, challengeId, PeerReviewTypes.ROLE_EDITOR, M14_EDITOR_SUBJECT);
        panelActorV2.resolveChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeResolutionInput({
                challengeId: challengeId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                outcome: AVAChallengeExtension.ChallengeOutcome.Upheld,
                correctionStatus: AVACoreTypes.RecognisedStateStatus.Downgraded,
                reasonHash: keccak256("canonical-challenge-downstream-resolution"),
                reasonURI: "ipfs://canonical-challenge-downstream-resolution"
            })
        );
        AVAChallengeExtension.ChallengeRecord memory challenge = challengeExtension.getChallenge(challengeId);
        AVACoreTypes.RecognisedStateRecord memory challengeState =
            governanceKernel.getRecognisedState(challenge.challengeRecognisedStateId);
        (AVAStandingRecordExtension standingExtension, AVAAllocationRecordExtension allocationExtension,) =
            _deployDownstreamExtensions();
        _authoriseDownstreamExtensions();
        M14PeerReviewActor protocolActor = new M14PeerReviewActor();
        bytes32 protocolSubject = keccak256("canonical-challenge-downstream-executor");
        coreIdentityRegistry.assignSubject(
            address(protocolActor),
            PeerReviewTypes.APP_ID,
            PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
            protocolSubject,
            "ipfs://canonical-challenge-downstream-executor"
        );

        uint256 standingId = panelActorV2.recordStanding(
            standingExtension,
            AVAStandingRecordExtension.StandingInput({
                recognisedStateId: challengeState.id,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                subjectId: M14_CHALLENGER_SUBJECT,
                evidenceId: challengeState.evidenceReceiptId,
                dimensionKey: keccak256("canonical-challenge-procedural-standing"),
                delta: 1,
                reasonHash: keccak256("canonical-challenge-standing-record"),
                uri: "ipfs://canonical-challenge-standing-record"
            })
        );
        uint256 allocationId = protocolActor.recordAllocation(
            allocationExtension,
            AVAAllocationRecordExtension.AllocationInput({
                recognisedStateId: challengeState.id,
                roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                authorityId: protocolSubject,
                subjectId: M14_CHALLENGER_SUBJECT,
                evidenceId: challengeState.evidenceReceiptId,
                allocationKindKey: keccak256("canonical-challenge-bounded-allocation"),
                units: 1,
                reasonHash: keccak256("canonical-challenge-allocation-record"),
                uri: "ipfs://canonical-challenge-allocation-record"
            })
        );

        require(
            standingExtension.getStandingUpdate(standingId).recognisedStateId == challengeState.id,
            "standing used challenged review state"
        );
        require(
            allocationExtension.getAllocation(allocationId).recognisedStateId == challengeState.id,
            "allocation used challenged review state"
        );
        require(
            standingExtension.getStandingUpdate(standingId).subjectId == M14_CHALLENGER_SUBJECT
                && allocationExtension.getAllocation(allocationId).subjectId == M14_CHALLENGER_SUBJECT,
            "challenge downstream subject attribution missing"
        );
    }

    function testCanonicalChallengeCanRecursivelyTargetPriorChallengeRecognisedState() public {
        uint256 reviewStateId = _createM14ChallengeableReviewState();
        uint256 firstChallengeId = _fileChallenge(reviewStateId, "canonical-first-level-challenge");
        AVAChallengeExtension.ChallengeRecord memory firstChallenge = challengeExtension.getChallenge(firstChallengeId);
        AVACoreTypes.RecognisedStateRecord memory firstChallengeState =
            governanceKernel.getRecognisedState(firstChallenge.challengeRecognisedStateId);

        M14PeerReviewActor secondChallenger = new M14PeerReviewActor();
        bytes32 secondChallengerSubject = keccak256("canonical-second-level-challenger");
        coreIdentityRegistry.assignSubject(
            address(secondChallenger),
            PeerReviewTypes.APP_ID,
            PeerReviewTypes.ROLE_CHALLENGER,
            secondChallengerSubject,
            "ipfs://canonical-second-level-challenger"
        );
        uint256 secondEvidenceId = secondChallenger.registerEvidence(
            coreEvidenceRegistry,
            WORKFLOW,
            packageId,
            PeerReviewTypes.ROLE_CHALLENGER,
            secondChallengerSubject,
            keccak256("canonical-second-level-challenge-evidence"),
            policyId
        );
        uint256 secondChallengeStateId = _createChallengeRecognisedState(
            secondChallenger,
            secondChallengerSubject,
            WORKFLOW,
            packageId,
            firstChallengeState.id,
            secondEvidenceId,
            "canonical-second-level-challenge"
        );
        uint256 secondChallengeId = secondChallenger.fileChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeFilingInput({
                appId: PeerReviewTypes.APP_ID,
                workflowKey: WORKFLOW,
                packageId: packageId,
                challengeRecognisedStateId: secondChallengeStateId,
                challengedRecognisedStateId: firstChallengeState.id,
                roleKey: PeerReviewTypes.ROLE_CHALLENGER,
                reasonHash: keccak256("canonical-second-level-challenge"),
                reasonURI: "ipfs://canonical-second-level-challenge"
            })
        );
        AVAChallengeExtension.ChallengeRecord memory secondChallenge =
            challengeExtension.getChallenge(secondChallengeId);
        AVACoreTypes.GovernedObjectRecord memory secondChallengeObject =
            governanceKernel.getGovernedObject(secondChallenge.challengeGovernedObjectId);

        require(
            secondChallenge.challengedRecognisedStateId == firstChallengeState.id,
            "nested challenge lost challenge-state target"
        );
        require(
            secondChallengeObject.parentObjectId == firstChallengeState.governedObjectId,
            "nested challenge lost governed-object parent"
        );
        require(
            challengeExtension.openChallengeCountByRecognisedState(firstChallengeState.id) == 1,
            "nested challenge did not open target lifecycle"
        );
        require(
            governanceKernel.getRecognisedState(secondChallenge.challengeRecognisedStateId).status
                == AVACoreTypes.RecognisedStateStatus.Challengeable,
            "nested challenge did not enter challengeable state"
        );
    }

    function testCanonicalChallengeObjectDispatchesItsOwnPackageAttribution() public {
        uint256 targetStateId = _createM14ChallengeableReviewState();
        AVACoreRulePackageRegistry.ModuleBinding[] memory bindings = _peerReviewBindings(peerReviewModule);
        _replaceCapability(
            bindings, AVACapabilityKeys.ATTRIBUTION, IRuleModuleIdentity(address(new M14RejectingCoreRuleModule()))
        );
        uint256 challengePackageId = _registerIndependentChallengePackage(bindings);
        uint256 evidenceId = challengerActorV2.registerEvidence(
            coreEvidenceRegistry,
            CHALLENGE_WORKFLOW,
            challengePackageId,
            PeerReviewTypes.ROLE_CHALLENGER,
            M14_CHALLENGER_SUBJECT,
            keccak256("canonical-challenge-attribution-evidence"),
            policyId
        );
        uint256 nextObjectIdBefore = governanceKernel.nextGovernedObjectId();
        AVACoreTypes.RecognisedStateRecord memory target = governanceKernel.getRecognisedState(targetStateId);
        try challengerActorV2.registerObject(
            governanceKernel,
            AVAGovernanceKernel.GovernedObjectInput({
                appId: PeerReviewTypes.APP_ID,
                workflowKey: CHALLENGE_WORKFLOW,
                packageId: challengePackageId,
                roleKey: PeerReviewTypes.ROLE_CHALLENGER,
                objectTypeKey: PeerReviewTypes.OBJECT_CHALLENGE,
                objectCommitment: keccak256("canonical-challenge-attribution-object"),
                parentObjectId: target.governedObjectId,
                subjectId: M14_CHALLENGER_SUBJECT,
                evidenceReceiptId: evidenceId,
                disclosurePolicyId: policyId,
                metadataHash: keccak256("canonical-challenge-attribution-metadata"),
                authorityId: M14_CHALLENGER_SUBJECT,
                uri: "ipfs://canonical-challenge-attribution-object"
            })
        ) {
            revert("challenge object bypassed challenge-package attribution");
        } catch {}
        require(governanceKernel.nextGovernedObjectId() == nextObjectIdBefore, "rejected challenge object was stored");
    }

    function testCanonicalChallengeStateDispatchesItsOwnPackageVerification() public {
        uint256 targetStateId = _createM14ChallengeableReviewState();
        AVACoreRulePackageRegistry.ModuleBinding[] memory bindings = _peerReviewBindings(peerReviewModule);
        _replaceCapability(
            bindings, AVACapabilityKeys.VERIFICATION, IRuleModuleIdentity(address(new M14RejectingCoreRuleModule()))
        );
        uint256 challengePackageId = _registerIndependentChallengePackage(bindings);
        uint256 evidenceId = challengerActorV2.registerEvidence(
            coreEvidenceRegistry,
            CHALLENGE_WORKFLOW,
            challengePackageId,
            PeerReviewTypes.ROLE_CHALLENGER,
            M14_CHALLENGER_SUBJECT,
            keccak256("canonical-challenge-verification-evidence"),
            policyId
        );
        AVACoreTypes.RecognisedStateRecord memory target = governanceKernel.getRecognisedState(targetStateId);
        uint256 challengeObjectId = challengerActorV2.registerObject(
            governanceKernel,
            AVAGovernanceKernel.GovernedObjectInput({
                appId: PeerReviewTypes.APP_ID,
                workflowKey: CHALLENGE_WORKFLOW,
                packageId: challengePackageId,
                roleKey: PeerReviewTypes.ROLE_CHALLENGER,
                objectTypeKey: PeerReviewTypes.OBJECT_CHALLENGE,
                objectCommitment: keccak256("canonical-challenge-verification-object"),
                parentObjectId: target.governedObjectId,
                subjectId: M14_CHALLENGER_SUBJECT,
                evidenceReceiptId: evidenceId,
                disclosurePolicyId: policyId,
                metadataHash: keccak256("canonical-challenge-verification-metadata"),
                authorityId: M14_CHALLENGER_SUBJECT,
                uri: "ipfs://canonical-challenge-verification-object"
            })
        );
        uint256 nextStateIdBefore = governanceKernel.nextRecognisedStateId();
        try challengerActorV2.formState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateFormationInput({
                governedObjectId: challengeObjectId,
                roleKey: PeerReviewTypes.ROLE_CHALLENGER,
                authorityId: M14_CHALLENGER_SUBJECT,
                stage: AVACoreTypes.Stage.Verification,
                status: AVACoreTypes.RecognisedStateStatus.Registered,
                reasonHash: keccak256("canonical-challenge-verification-state"),
                reasonURI: "ipfs://canonical-challenge-verification-state"
            })
        ) {
            revert("challenge state bypassed challenge-package verification");
        } catch {}
        require(governanceKernel.nextRecognisedStateId() == nextStateIdBefore, "rejected challenge state was stored");
    }

    function testCanonicalChallengeDecisionUsesChallengeIdForAuthorityPolicyAcrossStateTransitions() public {
        uint256 expectedChallengeId = challengeExtension.nextChallengeId();
        IRuleModuleIdentity authorityModule = IRuleModuleIdentity(
            address(
                new M14ExpectedAuthorityTargetPolicyModule(AVACoreTypes.ACTION_RESOLVE_CHALLENGE, expectedChallengeId)
            )
        );
        _activateCapabilityModule(AVACapabilityKeys.AUTHORITY_POLICY, authorityModule);
        uint256 targetStateId = _createM14ChallengeableReviewState();

        AVACoreRulePackageRegistry.ModuleBinding[] memory challengeBindings = _peerReviewBindings(peerReviewModule);
        _replaceCapability(challengeBindings, AVACapabilityKeys.AUTHORITY_POLICY, authorityModule);
        uint256 challengePackageId = _registerIndependentChallengePackage(challengeBindings);
        uint256 evidenceId = challengerActorV2.registerEvidence(
            coreEvidenceRegistry,
            CHALLENGE_WORKFLOW,
            challengePackageId,
            PeerReviewTypes.ROLE_CHALLENGER,
            M14_CHALLENGER_SUBJECT,
            keccak256("canonical-authority-target-challenge-evidence"),
            policyId
        );
        uint256 challengeStateId = _createChallengeRecognisedState(
            challengerActorV2,
            M14_CHALLENGER_SUBJECT,
            CHALLENGE_WORKFLOW,
            challengePackageId,
            targetStateId,
            evidenceId,
            "canonical-authority-target-challenge"
        );
        uint256 challengeId = challengerActorV2.fileChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeFilingInput({
                appId: PeerReviewTypes.APP_ID,
                workflowKey: CHALLENGE_WORKFLOW,
                packageId: challengePackageId,
                challengeRecognisedStateId: challengeStateId,
                challengedRecognisedStateId: targetStateId,
                roleKey: PeerReviewTypes.ROLE_CHALLENGER,
                reasonHash: keccak256("canonical-authority-target-challenge"),
                reasonURI: "ipfs://canonical-authority-target-challenge"
            })
        );
        require(challengeId == expectedChallengeId, "unexpected challenge id");
        editorActorV2.screenChallenge(challengeExtension, challengeId, PeerReviewTypes.ROLE_EDITOR, M14_EDITOR_SUBJECT);
        panelActorV2.resolveChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeResolutionInput({
                challengeId: challengeId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                outcome: AVAChallengeExtension.ChallengeOutcome.Upheld,
                correctionStatus: AVACoreTypes.RecognisedStateStatus.Downgraded,
                reasonHash: keccak256("canonical-authority-target-resolution"),
                reasonURI: "ipfs://canonical-authority-target-resolution"
            })
        );
        require(
            governanceKernel.getRecognisedState(targetStateId).status == AVACoreTypes.RecognisedStateStatus.Downgraded,
            "authority-target-bound correction missing"
        );
        require(
            governanceKernel.getRecognisedState(challengeStateId).status == AVACoreTypes.RecognisedStateStatus.Vested,
            "authority-target-bound challenge vesting missing"
        );
    }

    function testCanonicalDoubleBlindScenarioIsPackageAndPolicyBound() public {
        PeerReviewCoreDisclosurePolicyModule module = new PeerReviewCoreDisclosurePolicyModule(
            PeerReviewCoreDisclosurePolicyModule.Scenario.DoubleBlindReview, policyId
        );
        _activateCapabilityModule(AVACapabilityKeys.DISCLOSURE_POLICY, IRuleModuleIdentity(address(module)));
        uint256 incompatiblePolicyId = editorActorV2.registerPolicy(
            coreDisclosureRegistry,
            PeerReviewTypes.ROLE_EDITOR,
            M14_EDITOR_SUBJECT,
            keccak256("canonical-incompatible-double-blind-policy")
        );
        uint256 nextEvidenceIdBefore = coreEvidenceRegistry.nextEvidenceId();
        try reviewerActorV2.registerEvidence(
            coreEvidenceRegistry,
            WORKFLOW,
            packageId,
            PeerReviewTypes.ROLE_REVIEWER,
            M14_REVIEWER_SUBJECT,
            keccak256("canonical-incompatible-double-blind-evidence"),
            incompatiblePolicyId
        ) {
            revert("double-blind package accepted incompatible disclosure policy");
        } catch {}
        require(coreEvidenceRegistry.nextEvidenceId() == nextEvidenceIdBefore, "rejected evidence was stored");

        uint256 stateId = _createM14ChallengeableReviewState();
        panelActorV2.vestState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Vested,
                reasonHash: keccak256("canonical-double-blind-vest"),
                reasonURI: "ipfs://canonical-double-blind-vest"
            })
        );
        require(
            governanceKernel.getRecognisedState(stateId).status == AVACoreTypes.RecognisedStateStatus.Vested,
            "double-blind policy blocked legal recognised-state flow"
        );
    }

    function testCanonicalPanelScopedReviewPackageRejectsChallengeIntakeRole() public {
        PeerReviewCoreDisclosurePolicyModule module = new PeerReviewCoreDisclosurePolicyModule(
            PeerReviewCoreDisclosurePolicyModule.Scenario.PanelScopedReview, policyId
        );
        _activateCapabilityModule(AVACapabilityKeys.DISCLOSURE_POLICY, IRuleModuleIdentity(address(module)));
        uint256 stateId = _createM14ChallengeableReviewState();
        uint256 nextEvidenceIdBefore = coreEvidenceRegistry.nextEvidenceId();
        try challengerActorV2.registerEvidence(
            coreEvidenceRegistry,
            WORKFLOW,
            packageId,
            PeerReviewTypes.ROLE_CHALLENGER,
            M14_CHALLENGER_SUBJECT,
            keccak256("canonical-panel-scoped-challenge-evidence"),
            policyId
        ) {
            revert("panel-scoped review package accepted challenge intake evidence");
        } catch {}
        require(coreEvidenceRegistry.nextEvidenceId() == nextEvidenceIdBefore, "rejected challenge evidence was stored");
        require(
            governanceKernel.getRecognisedState(stateId).status == AVACoreTypes.RecognisedStateStatus.Challengeable,
            "panel-scoped review flow did not reach challengeable state"
        );
    }

    function testCanonicalVoluntaryIdentityChallengePolicyIsReferenceOnly() public {
        PeerReviewCoreDisclosurePolicyModule module = new PeerReviewCoreDisclosurePolicyModule(
            PeerReviewCoreDisclosurePolicyModule.Scenario.VoluntaryIdentityChallenge, policyId
        );
        AVACoreRulePackageRegistry.ModuleBinding[] memory bindings = _peerReviewBindings(peerReviewModule);
        _replaceCapability(bindings, AVACapabilityKeys.DISCLOSURE_POLICY, IRuleModuleIdentity(address(module)));
        uint256 challengePackageId = _registerIndependentChallengePackage(bindings);
        uint256 targetStateId = _createM14ChallengeableReviewState();
        uint256 evidenceId = challengerActorV2.registerEvidence(
            coreEvidenceRegistry,
            CHALLENGE_WORKFLOW,
            challengePackageId,
            PeerReviewTypes.ROLE_CHALLENGER,
            M14_CHALLENGER_SUBJECT,
            keccak256("canonical-voluntary-identity-challenge-evidence"),
            policyId
        );
        uint256 challengeStateId = _createChallengeRecognisedState(
            challengerActorV2,
            M14_CHALLENGER_SUBJECT,
            CHALLENGE_WORKFLOW,
            challengePackageId,
            targetStateId,
            evidenceId,
            "canonical-voluntary-identity-challenge"
        );
        uint256 challengeId = challengerActorV2.fileChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeFilingInput({
                appId: PeerReviewTypes.APP_ID,
                workflowKey: CHALLENGE_WORKFLOW,
                packageId: challengePackageId,
                challengeRecognisedStateId: challengeStateId,
                challengedRecognisedStateId: targetStateId,
                roleKey: PeerReviewTypes.ROLE_CHALLENGER,
                reasonHash: keccak256("canonical-voluntary-identity-challenge"),
                reasonURI: "ipfs://canonical-voluntary-identity-challenge"
            })
        );
        AVAChallengeExtension.ChallengeRecord memory challenge = challengeExtension.getChallenge(challengeId);
        require(challenge.packageId == challengePackageId, "voluntary-identity package not pinned");
        require(challenge.challengerSubjectId == M14_CHALLENGER_SUBJECT, "role-scoped subject not retained");
        (bool revealIdentitySelector,) =
            address(challengeExtension).call(abi.encodeWithSignature("revealIdentity(uint256)", challengeId));
        require(!revealIdentitySelector, "voluntary-identity policy exposed reveal selector");
    }

    function testCanonicalPostRecognitionAccessPolicyRequiresVestedOrRestoredState() public {
        PeerReviewDisclosureReceiptPolicyModule module = new PeerReviewDisclosureReceiptPolicyModule(
            governanceKernel, PeerReviewDisclosureReceiptPolicyModule.Scenario.PostRecognitionAccess, policyId
        );
        _activateCapabilityModule(AVACapabilityKeys.DISCLOSURE_RECEIPT, IRuleModuleIdentity(address(module)));
        uint256 stateId = _createM14ChallengeableReviewState();
        AVACoreTypes.RecognisedStateRecord memory state = governanceKernel.getRecognisedState(stateId);
        AVADisclosureReceiptExtension receiptExtension = _deployDisclosureReceiptExtension();
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_RECORD_DISCLOSURE_RECEIPT, true
        );
        AVADisclosureReceiptExtension.DisclosureInput memory input = AVADisclosureReceiptExtension.DisclosureInput({
            recognisedStateId: stateId,
            roleKey: PeerReviewTypes.ROLE_PANEL,
            authorityId: M14_PANEL_SUBJECT,
            subjectId: M14_CHALLENGER_SUBJECT,
            evidenceId: state.evidenceReceiptId,
            kind: AVADisclosureReceiptExtension.DisclosureReceiptKind.AccessGrant,
            scopeKey: keccak256("canonical-post-recognition-access"),
            proofReceiptId: 0,
            relatedReceiptId: 0,
            expiresAt: uint64(block.timestamp + 1 days),
            reasonHash: keccak256("canonical-post-recognition-access"),
            uri: "ipfs://canonical-post-recognition-access"
        });
        uint256 nextReceiptIdBefore = receiptExtension.nextDisclosureReceiptId();
        try panelActorV2.recordDisclosure(receiptExtension, input) {
            revert("post-recognition access was recorded before recognition vested");
        } catch {}
        require(receiptExtension.nextDisclosureReceiptId() == nextReceiptIdBefore, "rejected access receipt was stored");

        panelActorV2.vestState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Vested,
                reasonHash: keccak256("canonical-post-recognition-vest"),
                reasonURI: "ipfs://canonical-post-recognition-vest"
            })
        );
        uint256 receiptId = panelActorV2.recordDisclosure(receiptExtension, input);
        require(receiptExtension.isAccessGrantActive(receiptId), "post-recognition access receipt inactive");
    }

    function testCanonicalVoluntaryIdentityIntentRequiresSelfAuthorisedSubject() public {
        PeerReviewDisclosureReceiptPolicyModule module = new PeerReviewDisclosureReceiptPolicyModule(
            governanceKernel, PeerReviewDisclosureReceiptPolicyModule.Scenario.VoluntaryIdentityIntent, policyId
        );
        _activateCapabilityModule(AVACapabilityKeys.DISCLOSURE_RECEIPT, IRuleModuleIdentity(address(module)));
        uint256 stateId = _createM14ChallengeableReviewState();
        AVACoreTypes.RecognisedStateRecord memory state = governanceKernel.getRecognisedState(stateId);
        AVADisclosureReceiptExtension receiptExtension = _deployDisclosureReceiptExtension();
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_REVIEWER, AVACoreTypes.ACTION_RECORD_DISCLOSURE_RECEIPT, true
        );
        uint256 receiptId = reviewerActorV2.recordDisclosure(
            receiptExtension,
            AVADisclosureReceiptExtension.DisclosureInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_REVIEWER,
                authorityId: M14_REVIEWER_SUBJECT,
                subjectId: M14_REVIEWER_SUBJECT,
                evidenceId: state.evidenceReceiptId,
                kind: AVADisclosureReceiptExtension.DisclosureReceiptKind.VoluntaryIntent,
                scopeKey: keccak256("canonical-voluntary-identity-intent"),
                proofReceiptId: 0,
                relatedReceiptId: 0,
                expiresAt: 0,
                reasonHash: keccak256("canonical-voluntary-identity-intent"),
                uri: "ipfs://canonical-voluntary-identity-intent"
            })
        );
        AVADisclosureReceiptExtension.DisclosureReceipt memory receipt =
            receiptExtension.getDisclosureReceipt(receiptId);
        require(receipt.subjectId == M14_REVIEWER_SUBJECT, "voluntary intent lost role-scoped subject");
        require(
            receipt.kind == AVADisclosureReceiptExtension.DisclosureReceiptKind.VoluntaryIntent, "wrong intent kind"
        );
    }

    function testM144RejectedGoodFaithCanExplicitlyRestoreUnchangedVestedLineage() public {
        _assertRecordOnlyVestedRestoration(
            AVAChallengeExtension.ChallengeOutcome.RejectedGoodFaith, "m144-good-faith-restoration"
        );
    }

    function testM144MaliciousFindingCanExplicitlyRestoreUnchangedVestedLineage() public {
        _assertRecordOnlyVestedRestoration(
            AVAChallengeExtension.ChallengeOutcome.MaliciousOrFabricated, "m144-malicious-restoration"
        );
    }

    function testM144NegligentOutcomeCannotEnterRestorationPath() public {
        uint256 stateId = _createM14ChallengeableReviewState();
        uint256 challengeId = _fileChallenge(stateId, "m144-negligent-no-restoration");
        editorActorV2.screenChallenge(challengeExtension, challengeId, PeerReviewTypes.ROLE_EDITOR, M14_EDITOR_SUBJECT);
        panelActorV2.resolveChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeResolutionInput({
                challengeId: challengeId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                outcome: AVAChallengeExtension.ChallengeOutcome.Negligent,
                correctionStatus: AVACoreTypes.RecognisedStateStatus.Challengeable,
                reasonHash: keccak256("m144-negligent-no-restoration"),
                reasonURI: "ipfs://m144-negligent-no-restoration"
            })
        );
        try panelActorV2.makeRestorationAvailable(
            challengeExtension,
            challengeId,
            PeerReviewTypes.ROLE_PANEL,
            M14_PANEL_SUBJECT,
            keccak256("m144-negligent-restoration-attempt"),
            "ipfs://m144-negligent-restoration-attempt"
        ) {
            revert("negligent outcome entered restoration path");
        } catch {}
    }

    function testM144RejectedGoodFaithChallengeIsRecordOnlyAndDistinct() public {
        uint256 stateId = _createM14ChallengeableReviewState();
        uint256 transitionIdBefore = governanceKernel.getRecognisedState(stateId).lastTransitionId;
        uint256 challengeId = _fileChallenge(stateId, "m14-good-faith-challenge");
        editorActorV2.screenChallenge(challengeExtension, challengeId, PeerReviewTypes.ROLE_EDITOR, M14_EDITOR_SUBJECT);
        panelActorV2.resolveChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeResolutionInput({
                challengeId: challengeId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                outcome: AVAChallengeExtension.ChallengeOutcome.RejectedGoodFaith,
                correctionStatus: AVACoreTypes.RecognisedStateStatus.Challengeable,
                reasonHash: keccak256("m14-good-faith-resolution"),
                reasonURI: "ipfs://m14-good-faith-resolution"
            })
        );
        require(
            governanceKernel.getRecognisedState(stateId).lastTransitionId == transitionIdBefore,
            "good-faith rejection mutated target"
        );
        require(
            challengeExtension.getChallenge(challengeId).outcome
                == AVAChallengeExtension.ChallengeOutcome.RejectedGoodFaith,
            "good-faith outcome collapsed"
        );
    }

    function testM144HighImpactRequesterBindingIsPackageScopedAndImmutable() public {
        AVAChallengeExtension replacement = new AVAChallengeExtension(
            governanceKernel, coreAuthorityMatrix, coreIdentityRegistry, corePackageRegistry, coreEvidenceRegistry
        );
        try governanceKernel.bindSourceBoundTransitionRequester(packageId, address(replacement)) {
            revert("package requester binding was overwritten");
        } catch {}
        require(
            governanceKernel.sourceBoundTransitionRequesterByPackage(packageId) == address(challengeExtension),
            "package requester binding changed"
        );
    }

    function testM144OpenChallengeBlocksVestingUntilAuthorisedClosure() public {
        uint256 stateId = _createM14ChallengeableReviewState();
        uint256 challengeId = _fileChallenge(stateId, "m14-open-challenge-vesting");
        AVAGovernanceKernel.RecognisedStateTransitionInput memory vestingInput =
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Vested,
                reasonHash: keccak256("m14-vest-after-close"),
                reasonURI: "ipfs://m14-vest-after-close"
            });
        try panelActorV2.vestState(governanceKernel, vestingInput) {
            revert("open challenge did not block vesting");
        } catch {}

        editorActorV2.screenChallenge(challengeExtension, challengeId, PeerReviewTypes.ROLE_EDITOR, M14_EDITOR_SUBJECT);
        panelActorV2.resolveChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeResolutionInput({
                challengeId: challengeId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                outcome: AVAChallengeExtension.ChallengeOutcome.RejectedGoodFaith,
                correctionStatus: AVACoreTypes.RecognisedStateStatus.Challengeable,
                reasonHash: keccak256("m14-closeable-resolution"),
                reasonURI: "ipfs://m14-closeable-resolution"
            })
        );
        panelActorV2.closeChallenge(
            challengeExtension,
            challengeId,
            PeerReviewTypes.ROLE_PANEL,
            M14_PANEL_SUBJECT,
            keccak256("m14-authorised-close"),
            "ipfs://m14-authorised-close"
        );
        panelActorV2.vestState(governanceKernel, vestingInput);
        require(
            governanceKernel.getRecognisedState(stateId).status == AVACoreTypes.RecognisedStateStatus.Vested,
            "vesting did not resume after closure"
        );
    }

    function testM144AuthorisedPreResolutionClosureIsRecordOnlyAndReleasesOpenCount() public {
        uint256 stateId = _createM14ChallengeableReviewState();
        uint256 targetTransitionIdBefore = governanceKernel.getRecognisedState(stateId).lastTransitionId;
        uint256 challengeId = _fileChallenge(stateId, "m144-pre-resolution-close");
        panelActorV2.closeChallenge(
            challengeExtension,
            challengeId,
            PeerReviewTypes.ROLE_PANEL,
            M14_PANEL_SUBJECT,
            keccak256("m144-pre-resolution-close"),
            "ipfs://m144-pre-resolution-close"
        );
        AVAChallengeExtension.ChallengeRecord memory challenge = challengeExtension.getChallenge(challengeId);
        require(challenge.status == AVAChallengeExtension.ChallengeStatus.Closed, "pre-resolution close missing");
        require(
            challenge.outcome == AVAChallengeExtension.ChallengeOutcome.None, "pre-resolution close invented outcome"
        );
        require(challengeExtension.openChallengeCountByRecognisedState(stateId) == 0, "open count not released");
        require(
            governanceKernel.getRecognisedState(stateId).lastTransitionId == targetTransitionIdBefore,
            "pre-resolution close mutated target"
        );
    }

    function testM144SameAccountCannotRepeatChallengeForSameTargetVersion() public {
        uint256 stateId = _createM14ChallengeableReviewState();
        _fileChallenge(stateId, "m14-first-filing");
        uint256 secondEvidenceId = challengerActorV2.registerEvidence(
            coreEvidenceRegistry,
            WORKFLOW,
            packageId,
            PeerReviewTypes.ROLE_CHALLENGER,
            M14_CHALLENGER_SUBJECT,
            keccak256("m14-second-filing"),
            policyId
        );
        uint256 secondChallengeStateId = _createChallengeRecognisedState(
            challengerActorV2,
            M14_CHALLENGER_SUBJECT,
            WORKFLOW,
            packageId,
            stateId,
            secondEvidenceId,
            "m14-second-filing"
        );
        try challengerActorV2.fileChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeFilingInput({
                appId: PeerReviewTypes.APP_ID,
                workflowKey: WORKFLOW,
                packageId: packageId,
                challengeRecognisedStateId: secondChallengeStateId,
                challengedRecognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_CHALLENGER,
                reasonHash: keccak256("m14-second-filing"),
                reasonURI: "ipfs://m14-second-filing"
            })
        ) {
            revert("same account repeated challenge against unchanged target version");
        } catch {}
    }

    function testM144TargetAndChallengerCannotUseSecondRoleForScreeningOrResolution() public {
        uint256 stateId = _createM14ChallengeableReviewState();
        uint256 challengeId = _fileChallenge(stateId, "m14-conflict-challenge");
        bytes32 targetEditorSubject = keccak256("m14-target-editor-subject");
        coreIdentityRegistry.assignSubject(
            address(reviewerActorV2),
            PeerReviewTypes.APP_ID,
            PeerReviewTypes.ROLE_EDITOR,
            targetEditorSubject,
            "ipfs://m14-target-editor"
        );
        try reviewerActorV2.screenChallenge(
            challengeExtension, challengeId, PeerReviewTypes.ROLE_EDITOR, targetEditorSubject
        ) {
            revert("target account screened own challenge");
        } catch {}
        editorActorV2.screenChallenge(challengeExtension, challengeId, PeerReviewTypes.ROLE_EDITOR, M14_EDITOR_SUBJECT);

        bytes32 challengerPanelSubject = keccak256("m14-challenger-panel-subject");
        coreIdentityRegistry.assignSubject(
            address(challengerActorV2),
            PeerReviewTypes.APP_ID,
            PeerReviewTypes.ROLE_PANEL,
            challengerPanelSubject,
            "ipfs://m14-challenger-panel"
        );
        try challengerActorV2.resolveChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeResolutionInput({
                challengeId: challengeId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: challengerPanelSubject,
                outcome: AVAChallengeExtension.ChallengeOutcome.RejectedGoodFaith,
                correctionStatus: AVACoreTypes.RecognisedStateStatus.Challengeable,
                reasonHash: keccak256("m14-self-resolution"),
                reasonURI: "ipfs://m14-self-resolution"
            })
        ) {
            revert("challenger account resolved own challenge");
        } catch {}
    }

    function testM144CoreRechecksAuthorityPermissionForBoundHighImpactRequester() public {
        uint256 replacementPackageId = _supersedePackage("ipfs://m14-high-impact-permission-package");
        packageId = replacementPackageId;
        M14UncheckedHighImpactRequester requester = new M14UncheckedHighImpactRequester();
        governanceKernel.bindSourceBoundTransitionRequester(replacementPackageId, address(requester));
        uint256 stateId = _createM14ChallengeableReviewState();
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_RESOLVE_CHALLENGE, false
        );
        AVACoreTypes.RecognisedStateRecord memory state = governanceKernel.getRecognisedState(stateId);

        try requester.request(
            governanceKernel,
            AVAGovernanceKernel.SourceBoundTransitionInput({
                recognisedStateId: stateId,
                expectedTransitionId: state.lastTransitionId,
                decisionPackageId: packageId,
                sourceRecordId: 1,
                decisionEvidenceReceiptId: state.evidenceReceiptId,
                disclosureTargetId: stateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                actionKey: AVACoreTypes.ACTION_RESOLVE_CHALLENGE,
                decisionHash: keccak256("m14-unauthorised-high-impact-decision"),
                toStatus: AVACoreTypes.RecognisedStateStatus.Downgraded,
                kind: AVACoreTypes.TransitionKind.ChallengeCorrection,
                reasonHash: keccak256("m14-unauthorised-high-impact"),
                reasonURI: "ipfs://m14-unauthorised-high-impact"
            })
        ) {
            revert("bound requester bypassed disabled authority permission");
        } catch {}
    }

    function testM144NegligentChallengeOutcomeIsDistinctAndRecordOnly() public {
        _assertRecordOnlyChallengeOutcome(AVAChallengeExtension.ChallengeOutcome.Negligent, "m14-negligent-challenge");
    }

    function testM144MaliciousChallengeOutcomeIsDistinctAndRecordOnly() public {
        _assertRecordOnlyChallengeOutcome(
            AVAChallengeExtension.ChallengeOutcome.MaliciousOrFabricated, "m14-malicious-challenge"
        );
    }

    function testM147RevokedChallengeEvidenceBlocksScreeningButAllowsAuthorisedClose() public {
        uint256 stateId = _createM14ChallengeableReviewState();
        uint256 challengeId = _fileChallenge(stateId, "m147-revoke-before-screening");
        uint256 challengeEvidenceId = challengeExtension.getChallenge(challengeId).evidenceReceiptId;
        panelActorV2.recordEvidenceLifecycle(
            coreEvidenceRegistry,
            challengeEvidenceId,
            PeerReviewTypes.ROLE_PANEL,
            M14_PANEL_SUBJECT,
            AVACoreTypes.EvidenceLifecycleKind.Revoke,
            keccak256("m147-revoke-before-screening")
        );

        try editorActorV2.screenChallenge(
            challengeExtension, challengeId, PeerReviewTypes.ROLE_EDITOR, M14_EDITOR_SUBJECT
        ) {
            revert("revoked challenge evidence allowed screening");
        } catch {}
        require(
            challengeExtension.getChallenge(challengeId).status == AVAChallengeExtension.ChallengeStatus.ConcernFiled,
            "failed screening changed challenge lifecycle"
        );

        panelActorV2.closeChallenge(
            challengeExtension,
            challengeId,
            PeerReviewTypes.ROLE_PANEL,
            M14_PANEL_SUBJECT,
            keccak256("m147-close-revoked-filing"),
            "ipfs://m147-close-revoked-filing"
        );
        require(
            challengeExtension.getChallenge(challengeId).status == AVAChallengeExtension.ChallengeStatus.Closed,
            "authorised defensive close failed"
        );
        require(challengeExtension.openChallengeCountByRecognisedState(stateId) == 0, "open count not released");
    }

    function testM147RevokedChallengeEvidenceBlocksResolutionButAllowsAuthorisedClose() public {
        uint256 stateId = _createM14ChallengeableReviewState();
        uint256 challengeId = _fileChallenge(stateId, "m147-revoke-before-resolution");
        editorActorV2.screenChallenge(challengeExtension, challengeId, PeerReviewTypes.ROLE_EDITOR, M14_EDITOR_SUBJECT);
        uint256 challengeEvidenceId = challengeExtension.getChallenge(challengeId).evidenceReceiptId;
        panelActorV2.recordEvidenceLifecycle(
            coreEvidenceRegistry,
            challengeEvidenceId,
            PeerReviewTypes.ROLE_PANEL,
            M14_PANEL_SUBJECT,
            AVACoreTypes.EvidenceLifecycleKind.Revoke,
            keccak256("m147-revoke-before-resolution")
        );

        try panelActorV2.resolveChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeResolutionInput({
                challengeId: challengeId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                outcome: AVAChallengeExtension.ChallengeOutcome.Upheld,
                correctionStatus: AVACoreTypes.RecognisedStateStatus.Downgraded,
                reasonHash: keccak256("m147-revoked-resolution"),
                reasonURI: "ipfs://m147-revoked-resolution"
            })
        ) {
            revert("revoked challenge evidence allowed resolution");
        } catch {}
        require(
            challengeExtension.getChallenge(challengeId).status
                == AVAChallengeExtension.ChallengeStatus.AdmissibilityScreening,
            "failed resolution changed challenge lifecycle"
        );
        require(
            governanceKernel.getRecognisedState(stateId).status == AVACoreTypes.RecognisedStateStatus.Challengeable,
            "failed resolution changed target state"
        );

        panelActorV2.closeChallenge(
            challengeExtension,
            challengeId,
            PeerReviewTypes.ROLE_PANEL,
            M14_PANEL_SUBJECT,
            keccak256("m147-close-revoked-screening"),
            "ipfs://m147-close-revoked-screening"
        );
        require(challengeExtension.openChallengeCountByRecognisedState(stateId) == 0, "open count not released");
    }

    function testM147RevokedChallengeEvidenceBlocksRestorationButAllowsAuthorisedClose() public {
        uint256 stateId = _createM14ChallengeableReviewState();
        uint256 challengeId = _fileChallenge(stateId, "m147-revoke-before-restoration");
        editorActorV2.screenChallenge(challengeExtension, challengeId, PeerReviewTypes.ROLE_EDITOR, M14_EDITOR_SUBJECT);
        panelActorV2.resolveChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeResolutionInput({
                challengeId: challengeId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                outcome: AVAChallengeExtension.ChallengeOutcome.Upheld,
                correctionStatus: AVACoreTypes.RecognisedStateStatus.Downgraded,
                reasonHash: keccak256("m147-upheld-before-revocation"),
                reasonURI: "ipfs://m147-upheld-before-revocation"
            })
        );
        uint256 challengeEvidenceId = challengeExtension.getChallenge(challengeId).evidenceReceiptId;
        panelActorV2.recordEvidenceLifecycle(
            coreEvidenceRegistry,
            challengeEvidenceId,
            PeerReviewTypes.ROLE_PANEL,
            M14_PANEL_SUBJECT,
            AVACoreTypes.EvidenceLifecycleKind.Revoke,
            keccak256("m147-revoke-before-restoration")
        );

        try panelActorV2.makeRestorationAvailable(
            challengeExtension,
            challengeId,
            PeerReviewTypes.ROLE_PANEL,
            M14_PANEL_SUBJECT,
            keccak256("m147-restoration-with-revoked-evidence"),
            "ipfs://m147-restoration-with-revoked-evidence"
        ) {
            revert("revoked challenge evidence allowed restoration readiness");
        } catch {}
        require(
            challengeExtension.getChallenge(challengeId).status == AVAChallengeExtension.ChallengeStatus.Resolved,
            "failed restoration readiness changed lifecycle"
        );
        require(
            governanceKernel.getRecognisedState(stateId).status == AVACoreTypes.RecognisedStateStatus.Downgraded,
            "failed restoration readiness changed target state"
        );

        panelActorV2.closeChallenge(
            challengeExtension,
            challengeId,
            PeerReviewTypes.ROLE_PANEL,
            M14_PANEL_SUBJECT,
            keccak256("m147-close-revoked-resolution"),
            "ipfs://m147-close-revoked-resolution"
        );
        require(challengeExtension.openChallengeCountByRecognisedState(stateId) == 0, "open count not released");
    }

    function testM147RevokedChallengeEvidenceBlocksRestorationApplication() public {
        uint256 stateId = _createM14ChallengeableReviewState();
        uint256 challengeId = _fileChallenge(stateId, "m147-revoke-before-restoration-application");
        editorActorV2.screenChallenge(challengeExtension, challengeId, PeerReviewTypes.ROLE_EDITOR, M14_EDITOR_SUBJECT);
        panelActorV2.resolveChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeResolutionInput({
                challengeId: challengeId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                outcome: AVAChallengeExtension.ChallengeOutcome.Upheld,
                correctionStatus: AVACoreTypes.RecognisedStateStatus.Downgraded,
                reasonHash: keccak256("m147-upheld-before-restoration-application"),
                reasonURI: "ipfs://m147-upheld-before-restoration-application"
            })
        );
        panelActorV2.makeRestorationAvailable(
            challengeExtension,
            challengeId,
            PeerReviewTypes.ROLE_PANEL,
            M14_PANEL_SUBJECT,
            keccak256("m147-restoration-ready-before-revocation"),
            "ipfs://m147-restoration-ready-before-revocation"
        );
        uint256 challengeEvidenceId = challengeExtension.getChallenge(challengeId).evidenceReceiptId;
        panelActorV2.recordEvidenceLifecycle(
            coreEvidenceRegistry,
            challengeEvidenceId,
            PeerReviewTypes.ROLE_PANEL,
            M14_PANEL_SUBJECT,
            AVACoreTypes.EvidenceLifecycleKind.Revoke,
            keccak256("m147-revoke-before-restoration-application")
        );

        try panelActorV2.restoreChallenge(
            challengeExtension,
            challengeId,
            PeerReviewTypes.ROLE_PANEL,
            M14_PANEL_SUBJECT,
            keccak256("m147-apply-with-revoked-evidence"),
            "ipfs://m147-apply-with-revoked-evidence"
        ) {
            revert("revoked challenge evidence allowed restoration application");
        } catch {}
        require(
            challengeExtension.getChallenge(challengeId).status
                == AVAChallengeExtension.ChallengeStatus.RestorationAvailable,
            "failed restoration application changed lifecycle"
        );
        require(
            governanceKernel.getRecognisedState(stateId).status == AVACoreTypes.RecognisedStateStatus.Downgraded,
            "failed restoration application changed target state"
        );

        panelActorV2.closeChallenge(
            challengeExtension,
            challengeId,
            PeerReviewTypes.ROLE_PANEL,
            M14_PANEL_SUBJECT,
            keccak256("m147-close-revoked-restoration"),
            "ipfs://m147-close-revoked-restoration"
        );
        require(challengeExtension.openChallengeCountByRecognisedState(stateId) == 0, "open count not released");
    }

    function testM144UpheldCorrectionCanDowngradeStateWithRevokedTargetEvidence() public {
        uint256 stateId = _createM14ChallengeableReviewState();
        uint256 targetEvidenceId = governanceKernel.getRecognisedState(stateId).evidenceReceiptId;
        panelActorV2.recordEvidenceLifecycle(
            coreEvidenceRegistry,
            targetEvidenceId,
            PeerReviewTypes.ROLE_PANEL,
            M14_PANEL_SUBJECT,
            AVACoreTypes.EvidenceLifecycleKind.Revoke,
            keccak256("m14-revoked-target-evidence")
        );
        uint256 challengeId = _fileChallenge(stateId, "m14-revoked-evidence-challenge");
        editorActorV2.screenChallenge(challengeExtension, challengeId, PeerReviewTypes.ROLE_EDITOR, M14_EDITOR_SUBJECT);
        panelActorV2.resolveChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeResolutionInput({
                challengeId: challengeId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                outcome: AVAChallengeExtension.ChallengeOutcome.Upheld,
                correctionStatus: AVACoreTypes.RecognisedStateStatus.Downgraded,
                reasonHash: keccak256("m14-correct-revoked-evidence-state"),
                reasonURI: "ipfs://m14-correct-revoked-evidence-state"
            })
        );
        require(
            governanceKernel.getRecognisedState(stateId).status == AVACoreTypes.RecognisedStateStatus.Downgraded,
            "revoked target evidence blocked safety-reducing correction"
        );
        panelActorV2.makeRestorationAvailable(
            challengeExtension,
            challengeId,
            PeerReviewTypes.ROLE_PANEL,
            M14_PANEL_SUBJECT,
            keccak256("m14-revoked-evidence-restoration-ready"),
            "ipfs://m14-revoked-evidence-restoration-ready"
        );
        try panelActorV2.restoreChallenge(
            challengeExtension,
            challengeId,
            PeerReviewTypes.ROLE_PANEL,
            M14_PANEL_SUBJECT,
            keccak256("m14-revoked-evidence-restoration"),
            "ipfs://m14-revoked-evidence-restoration"
        ) {
            revert("inactive evidence restored recognised state");
        } catch {}
        require(
            governanceKernel.getRecognisedState(stateId).status == AVACoreTypes.RecognisedStateStatus.Downgraded,
            "failed restoration changed corrected state"
        );
    }

    function testUpheldFindingAndStandingPenaltyCanReferenceRevokedTargetEvidence() public {
        AVAStandingRevisionExtension revisionExtension = new AVAStandingRevisionExtension(governanceKernel);
        AVAPenaltyRestorationExtension penaltyExtension = new AVAPenaltyRestorationExtension(
            governanceKernel,
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            coreDisclosureRegistry,
            challengeExtension,
            revisionExtension
        );
        revisionExtension.bindRevisionWriter(packageId, address(penaltyExtension));
        _authorisePenaltyExtension();

        uint256 stateId = _createM14ChallengeableReviewState();
        uint256 targetEvidenceId = governanceKernel.getRecognisedState(stateId).evidenceReceiptId;
        panelActorV2.recordEvidenceLifecycle(
            coreEvidenceRegistry,
            targetEvidenceId,
            PeerReviewTypes.ROLE_PANEL,
            M14_PANEL_SUBJECT,
            AVACoreTypes.EvidenceLifecycleKind.Revoke,
            keccak256("upheld-finding-revoked-target-evidence")
        );
        uint256 challengeId = _fileChallenge(stateId, "upheld-finding-revoked-target-evidence");
        editorActorV2.screenChallenge(challengeExtension, challengeId, PeerReviewTypes.ROLE_EDITOR, M14_EDITOR_SUBJECT);
        uint256 resolutionTransitionId = panelActorV2.resolveChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeResolutionInput({
                challengeId: challengeId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                outcome: AVAChallengeExtension.ChallengeOutcome.Upheld,
                correctionStatus: AVACoreTypes.RecognisedStateStatus.Downgraded,
                reasonHash: keccak256("upheld-finding-revoked-target-resolution"),
                reasonURI: "ipfs://upheld-finding-revoked-target-resolution"
            })
        );

        uint256 penaltyId = panelActorV2.recordPenalty(
            penaltyExtension,
            AVAPenaltyRestorationExtension.PenaltyInput({
                challengeTransitionId: resolutionTransitionId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                findingKey: PeerReviewTypes.FINDING_IRRESPONSIBLE_REVIEW,
                reasonHash: keccak256("upheld-finding-revoked-target-penalty"),
                uri: "ipfs://upheld-finding-revoked-target-penalty"
            })
        );
        uint256 standingPenaltyId = panelActorV2.recordStandingPenaltyInput(
            penaltyExtension,
            AVAPenaltyRestorationExtension.StandingPenaltyInput({
                penaltyId: penaltyId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                dimensionKey: keccak256("peer-review.procedural-care"),
                delta: -1,
                reasonHash: keccak256("upheld-finding-revoked-target-standing-input"),
                uri: "ipfs://upheld-finding-revoked-target-standing-input"
            })
        );

        require(penaltyExtension.getPenalty(penaltyId).evidenceId == targetEvidenceId, "finding lost evidence");
        require(
            penaltyExtension.getStandingPenaltyInput(standingPenaltyId).penaltyId == penaltyId,
            "standing input lost finding"
        );
    }

    function testM144UpheldCorrectionCanDowngradeStateAfterResponsibleSubjectDeactivation() public {
        uint256 stateId = _createM14ChallengeableReviewState();
        uint256 challengeId = _fileChallenge(stateId, "m144-inactive-target-correction");
        coreIdentityRegistry.deactivateSubject(M14_REVIEWER_SUBJECT);
        editorActorV2.screenChallenge(challengeExtension, challengeId, PeerReviewTypes.ROLE_EDITOR, M14_EDITOR_SUBJECT);
        panelActorV2.resolveChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeResolutionInput({
                challengeId: challengeId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                outcome: AVAChallengeExtension.ChallengeOutcome.Upheld,
                correctionStatus: AVACoreTypes.RecognisedStateStatus.Downgraded,
                reasonHash: keccak256("m144-inactive-target-correction"),
                reasonURI: "ipfs://m144-inactive-target-correction"
            })
        );
        require(
            governanceKernel.getRecognisedState(stateId).status == AVACoreTypes.RecognisedStateStatus.Downgraded,
            "inactive responsible subject blocked correction"
        );
    }

    function testM144ExtensionBindingsRejectAddressesWithoutRuntimeCode() public {
        uint256 replacementPackageId = _supersedePackage("ipfs://m14-binding-code-package");
        try governanceKernel.bindSourceBoundTransitionRequester(replacementPackageId, address(1)) {
            revert("requester binding accepted address without code");
        } catch {}
        try governanceKernel.bindTransitionGuard(replacementPackageId, address(2)) {
            revert("guard binding accepted address without code");
        } catch {}
    }

    function testM145BoundTransitionGuardIdentityDriftFailsClosed() public {
        packageId = _supersedePackage("ipfs://m145-mutable-guard-package");
        M14MutableBoundExtension mutableExtension = new M14MutableBoundExtension();
        governanceKernel.bindTransitionGuard(packageId, address(mutableExtension));
        (, uint256 reviewObjectId) = _registerManuscriptAndReview();
        uint256 stateId = editorActorV2.formState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateFormationInput({
                governedObjectId: reviewObjectId,
                roleKey: PeerReviewTypes.ROLE_EDITOR,
                authorityId: M14_EDITOR_SUBJECT,
                stage: AVACoreTypes.Stage.Verification,
                status: AVACoreTypes.RecognisedStateStatus.Provisional,
                reasonHash: keccak256("m145-mutable-guard-formation"),
                reasonURI: "ipfs://m145-mutable-guard-formation"
            })
        );
        mutableExtension.setIdentityHash(keccak256("m14.bound-extension.changed"));
        uint256 nextTransitionIdBefore = governanceKernel.nextTransitionId();
        try editorActorV2.transitionState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_EDITOR,
                authorityId: M14_EDITOR_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Challengeable,
                reasonHash: keccak256("m145-mutable-guard-transition"),
                reasonURI: "ipfs://m145-mutable-guard-transition"
            })
        ) {
            revert("changed transition guard identity remained active");
        } catch {}
        require(governanceKernel.nextTransitionId() == nextTransitionIdBefore, "identity drift wrote transition");
    }

    function testM145BoundPostTransitionHookIdentityDriftFailsClosed() public {
        packageId = _supersedePackage("ipfs://m145-mutable-hook-package");
        M14MutableBoundExtension mutableExtension = new M14MutableBoundExtension();
        governanceKernel.bindPostTransitionHook(packageId, address(mutableExtension));
        (, uint256 reviewObjectId) = _registerManuscriptAndReview();
        mutableExtension.setIdentityHash(keccak256("m14.bound-extension.changed"));
        uint256 nextStateIdBefore = governanceKernel.nextRecognisedStateId();
        try editorActorV2.formState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateFormationInput({
                governedObjectId: reviewObjectId,
                roleKey: PeerReviewTypes.ROLE_EDITOR,
                authorityId: M14_EDITOR_SUBJECT,
                stage: AVACoreTypes.Stage.Verification,
                status: AVACoreTypes.RecognisedStateStatus.Provisional,
                reasonHash: keccak256("m145-mutable-hook-formation"),
                reasonURI: "ipfs://m145-mutable-hook-formation"
            })
        ) {
            revert("changed post-transition hook identity remained active");
        } catch {}
        require(governanceKernel.nextRecognisedStateId() == nextStateIdBefore, "identity drift formed state");
    }

    function testM145BoundHighImpactRequesterIdentityDriftFailsClosed() public {
        packageId = _supersedePackage("ipfs://m145-mutable-requester-package");
        M14MutableBoundExtension mutableExtension = new M14MutableBoundExtension();
        governanceKernel.bindSourceBoundTransitionRequester(packageId, address(mutableExtension));
        governanceKernel.bindTransitionGuard(packageId, address(challengeExtension));
        uint256 stateId = _createM14ChallengeableReviewState();
        AVACoreTypes.RecognisedStateRecord memory state = governanceKernel.getRecognisedState(stateId);
        uint256 expectedTransitionId = state.lastTransitionId;
        mutableExtension.setIdentityHash(keccak256("m14.bound-extension.changed"));
        try mutableExtension.request(
            governanceKernel,
            AVAGovernanceKernel.SourceBoundTransitionInput({
                recognisedStateId: stateId,
                expectedTransitionId: expectedTransitionId,
                decisionPackageId: packageId,
                sourceRecordId: 1,
                decisionEvidenceReceiptId: state.evidenceReceiptId,
                disclosureTargetId: stateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                actionKey: AVACoreTypes.ACTION_RESOLVE_CHALLENGE,
                decisionHash: keccak256("m145-mutable-requester-decision"),
                toStatus: AVACoreTypes.RecognisedStateStatus.Downgraded,
                kind: AVACoreTypes.TransitionKind.ChallengeCorrection,
                reasonHash: keccak256("m145-mutable-requester-transition"),
                reasonURI: "ipfs://m145-mutable-requester-transition"
            })
        ) {
            revert("changed high-impact requester identity remained active");
        } catch {}
        require(
            governanceKernel.getRecognisedState(stateId).lastTransitionId == expectedTransitionId,
            "identity drift changed state"
        );
    }

    function testM145ChallengeLifecycleRejectsPostTransitionHookReentrancy() public {
        packageId = _supersedePackage("ipfs://m145-reentrant-hook-package");
        bytes32 hookPanelSubject = keccak256("m145-reentrant-hook-panel");
        M14ReentrantChallengeHook reentrantHook = new M14ReentrantChallengeHook(challengeExtension, hookPanelSubject);
        coreIdentityRegistry.assignSubject(
            address(reentrantHook),
            PeerReviewTypes.APP_ID,
            PeerReviewTypes.ROLE_PANEL,
            hookPanelSubject,
            "ipfs://m145-reentrant-hook-panel"
        );
        governanceKernel.bindSourceBoundTransitionRequester(packageId, address(challengeExtension));
        governanceKernel.bindTransitionGuard(packageId, address(challengeExtension));
        governanceKernel.bindPostTransitionHook(packageId, address(reentrantHook));
        uint256 stateId = _createM14ChallengeableReviewState();
        uint256 challengeId = _fileChallenge(stateId, "m145-reentrant-challenge");
        editorActorV2.screenChallenge(challengeExtension, challengeId, PeerReviewTypes.ROLE_EDITOR, M14_EDITOR_SUBJECT);
        reentrantHook.setChallengeId(challengeId);
        uint256 nextChallengeTransitionIdBefore = challengeExtension.nextTransitionId();
        panelActorV2.resolveChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeResolutionInput({
                challengeId: challengeId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                outcome: AVAChallengeExtension.ChallengeOutcome.Upheld,
                correctionStatus: AVACoreTypes.RecognisedStateStatus.Downgraded,
                reasonHash: keccak256("m145-outer-resolution"),
                reasonURI: "ipfs://m145-outer-resolution"
            })
        );
        require(!reentrantHook.reentrySucceeded(), "post-transition hook reentered challenge resolution");
        require(
            challengeExtension.nextTransitionId() == nextChallengeTransitionIdBefore + 1,
            "reentrant resolution wrote duplicate transition"
        );
        require(
            challengeExtension.getChallenge(challengeId).outcome == AVAChallengeExtension.ChallengeOutcome.Upheld,
            "reentrant hook replaced authorised outcome"
        );
    }

    function testM145StandingAllocationAndConsequenceAreSeparateRecordOnlyExtensions() public {
        uint256 stateId = _createM14ChallengeableReviewState();
        panelActorV2.vestState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Vested,
                reasonHash: keccak256("m145-downstream-vest"),
                reasonURI: "ipfs://m145-downstream-vest"
            })
        );
        uint256 stateTransitionId = governanceKernel.getRecognisedState(stateId).lastTransitionId;
        uint256 stateEvidenceId = governanceKernel.getRecognisedState(stateId).evidenceReceiptId;
        AVAStandingRecordExtension standingExtension = new AVAStandingRecordExtension(
            governanceKernel,
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            IAVAStandingRevision(address(0))
        );
        AVAAllocationRecordExtension allocationExtension = new AVAAllocationRecordExtension(
            governanceKernel, coreAuthorityMatrix, coreIdentityRegistry, corePackageRegistry, coreEvidenceRegistry
        );
        AVAConsequenceRecordExtension consequenceExtension = new AVAConsequenceRecordExtension(
            governanceKernel, coreAuthorityMatrix, coreIdentityRegistry, corePackageRegistry, coreEvidenceRegistry
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_RECORD_STANDING_UPDATE, true
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_RECORD_CONSEQUENCE, true
        );
        bytes32 protocolSubject = keccak256("m145-protocol-subject");
        M14PeerReviewActor protocolActor = new M14PeerReviewActor();
        coreIdentityRegistry.assignSubject(
            address(protocolActor),
            PeerReviewTypes.APP_ID,
            PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
            protocolSubject,
            "ipfs://m145-protocol"
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR, AVACoreTypes.ACTION_RECORD_ALLOCATION, true
        );

        uint256 standingId = panelActorV2.recordStanding(
            standingExtension,
            AVAStandingRecordExtension.StandingInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                subjectId: M14_REVIEWER_SUBJECT,
                evidenceId: stateEvidenceId,
                dimensionKey: keccak256("m145-procedural-reliability"),
                delta: 1,
                reasonHash: keccak256("m145-standing-record"),
                uri: "ipfs://m145-standing-record"
            })
        );
        uint256 allocationId = protocolActor.recordAllocation(
            allocationExtension,
            AVAAllocationRecordExtension.AllocationInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                authorityId: protocolSubject,
                subjectId: M14_REVIEWER_SUBJECT,
                evidenceId: stateEvidenceId,
                allocationKindKey: keccak256("m145-administrative-service-right"),
                units: 1,
                reasonHash: keccak256("m145-allocation-record"),
                uri: "ipfs://m145-allocation-record"
            })
        );
        uint256 consequenceId = panelActorV2.recordConsequence(
            consequenceExtension,
            AVAConsequenceRecordExtension.ConsequenceInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                subjectId: M14_REVIEWER_SUBJECT,
                evidenceId: stateEvidenceId,
                consequenceKindKey: keccak256("m145-administrative-note"),
                reasonHash: keccak256("m145-consequence-record"),
                uri: "ipfs://m145-consequence-record"
            })
        );

        require(standingId != 0 && allocationId != 0 && consequenceId != 0, "downstream record missing");
        require(standingExtension.getStandingUpdate(standingId).packageId == packageId, "standing package missing");
        require(allocationExtension.getAllocation(allocationId).packageId == packageId, "allocation package missing");
        require(
            consequenceExtension.getConsequence(consequenceId).packageId == packageId, "consequence package missing"
        );
        require(
            governanceKernel.getRecognisedState(stateId).lastTransitionId == stateTransitionId,
            "downstream record mutated recognised state"
        );
    }

    function testM145DownstreamExtensionsRejectUnsupportedStateUnknownStateWrongSubjectAndWrongRole() public {
        uint256 stateId = _createM14ChallengeableReviewState();
        (AVAStandingRecordExtension standingExtension,,) = _deployDownstreamExtensions();
        _authoriseDownstreamExtensions();
        uint256 evidenceId = governanceKernel.getRecognisedState(stateId).evidenceReceiptId;
        AVAStandingRecordExtension.StandingInput memory input = AVAStandingRecordExtension.StandingInput({
            recognisedStateId: stateId,
            roleKey: PeerReviewTypes.ROLE_PANEL,
            authorityId: M14_PANEL_SUBJECT,
            subjectId: M14_REVIEWER_SUBJECT,
            evidenceId: evidenceId,
            dimensionKey: keccak256("m145-boundary-dimension"),
            delta: 1,
            reasonHash: keccak256("m145-boundary-standing"),
            uri: "ipfs://m145-boundary-standing"
        });

        try panelActorV2.recordStanding(standingExtension, input) {
            revert("challengeable state created standing record");
        } catch {}
        input.recognisedStateId = governanceKernel.nextRecognisedStateId() + 100;
        try panelActorV2.recordStanding(standingExtension, input) {
            revert("unknown state created standing record");
        } catch {}

        panelActorV2.vestState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Vested,
                reasonHash: keccak256("m145-boundary-vest"),
                reasonURI: "ipfs://m145-boundary-vest"
            })
        );
        input.recognisedStateId = stateId;
        input.subjectId = M14_AUTHOR_SUBJECT;
        try panelActorV2.recordStanding(standingExtension, input) {
            revert("unrelated subject created standing record");
        } catch {}
        input.subjectId = M14_REVIEWER_SUBJECT;
        input.roleKey = PeerReviewTypes.ROLE_REVIEWER;
        input.authorityId = M14_REVIEWER_SUBJECT;
        try reviewerActorV2.recordStanding(standingExtension, input) {
            revert("unauthorised role created standing record");
        } catch {}
        input.roleKey = PeerReviewTypes.ROLE_PANEL;
        input.authorityId = M14_PANEL_SUBJECT;
        input.evidenceId = type(uint256).max;
        try panelActorV2.recordStanding(standingExtension, input) {
            revert("unknown evidence created standing record");
        } catch {}
    }

    function testM145AllocationRejectsDowngradedState() public {
        uint256 stateId = _createM14ChallengeableReviewState();
        (, AVAAllocationRecordExtension allocationExtension,) = _deployDownstreamExtensions();
        _authoriseDownstreamExtensions();
        uint256 evidenceId = governanceKernel.getRecognisedState(stateId).evidenceReceiptId;
        uint256 challengeId = _fileChallenge(stateId, "m145-allocation-downgrade");
        editorActorV2.screenChallenge(challengeExtension, challengeId, PeerReviewTypes.ROLE_EDITOR, M14_EDITOR_SUBJECT);
        panelActorV2.resolveChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeResolutionInput({
                challengeId: challengeId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                outcome: AVAChallengeExtension.ChallengeOutcome.Upheld,
                correctionStatus: AVACoreTypes.RecognisedStateStatus.Downgraded,
                reasonHash: keccak256("m145-allocation-downgrade"),
                reasonURI: "ipfs://m145-allocation-downgrade"
            })
        );
        AVAAllocationRecordExtension.AllocationInput memory input = AVAAllocationRecordExtension.AllocationInput({
            recognisedStateId: stateId,
            roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
            authorityId: keccak256("m145-protocol-subject-negative"),
            subjectId: M14_REVIEWER_SUBJECT,
            evidenceId: evidenceId,
            allocationKindKey: keccak256("m145-forbidden-positive-allocation"),
            units: 1,
            reasonHash: keccak256("m145-forbidden-positive-allocation"),
            uri: "ipfs://m145-forbidden-positive-allocation"
        });
        M14PeerReviewActor protocolActor = new M14PeerReviewActor();
        coreIdentityRegistry.assignSubject(
            address(protocolActor),
            PeerReviewTypes.APP_ID,
            PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
            input.authorityId,
            "ipfs://m145-protocol-negative"
        );
        try protocolActor.recordAllocation(allocationExtension, input) {
            revert("downgraded state created positive allocation");
        } catch {}
    }

    function testM145DownstreamExtensionsRejectInactiveEvidence() public {
        uint256 stateId = _createM14ChallengeableReviewState();
        (
            AVAStandingRecordExtension standingExtension,
            AVAAllocationRecordExtension allocationExtension,
            AVAConsequenceRecordExtension consequenceExtension
        ) = _deployDownstreamExtensions();
        _authoriseDownstreamExtensions();
        panelActorV2.vestState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Vested,
                reasonHash: keccak256("m145-inactive-evidence-vest"),
                reasonURI: "ipfs://m145-inactive-evidence-vest"
            })
        );
        uint256 evidenceId = governanceKernel.getRecognisedState(stateId).evidenceReceiptId;
        panelActorV2.recordEvidenceLifecycle(
            coreEvidenceRegistry,
            evidenceId,
            PeerReviewTypes.ROLE_PANEL,
            M14_PANEL_SUBJECT,
            AVACoreTypes.EvidenceLifecycleKind.Revoke,
            keccak256("m145-revoke-downstream-evidence")
        );
        bytes32 protocolSubject = keccak256("m145-protocol-subject-inactive-evidence");
        M14PeerReviewActor protocolActor = new M14PeerReviewActor();
        coreIdentityRegistry.assignSubject(
            address(protocolActor),
            PeerReviewTypes.APP_ID,
            PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
            protocolSubject,
            "ipfs://m145-protocol-inactive-evidence"
        );
        AVAAllocationRecordExtension.AllocationInput memory allocationInput =
            AVAAllocationRecordExtension.AllocationInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                authorityId: protocolSubject,
                subjectId: M14_REVIEWER_SUBJECT,
                evidenceId: evidenceId,
                allocationKindKey: keccak256("m145-inactive-evidence-allocation"),
                units: 1,
                reasonHash: keccak256("m145-inactive-evidence-allocation"),
                uri: "ipfs://m145-inactive-evidence-allocation"
            });
        try protocolActor.recordAllocation(allocationExtension, allocationInput) {
            revert("inactive evidence created allocation record");
        } catch {}
        AVAStandingRecordExtension.StandingInput memory standingInput = AVAStandingRecordExtension.StandingInput({
            recognisedStateId: stateId,
            roleKey: PeerReviewTypes.ROLE_PANEL,
            authorityId: M14_PANEL_SUBJECT,
            subjectId: M14_REVIEWER_SUBJECT,
            evidenceId: evidenceId,
            dimensionKey: keccak256("m145-inactive-evidence-standing"),
            delta: 1,
            reasonHash: keccak256("m145-inactive-evidence-standing"),
            uri: "ipfs://m145-inactive-evidence-standing"
        });
        try panelActorV2.recordStanding(standingExtension, standingInput) {
            revert("inactive evidence created standing record");
        } catch {}
        AVAConsequenceRecordExtension.ConsequenceInput memory consequenceInput =
            AVAConsequenceRecordExtension.ConsequenceInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                subjectId: M14_REVIEWER_SUBJECT,
                evidenceId: evidenceId,
                consequenceKindKey: keccak256("m145-inactive-evidence-consequence"),
                reasonHash: keccak256("m145-inactive-evidence-consequence"),
                uri: "ipfs://m145-inactive-evidence-consequence"
            });
        try panelActorV2.recordConsequence(consequenceExtension, consequenceInput) {
            revert("inactive evidence created consequence record");
        } catch {}
    }

    function testM145AttributionCapabilityCanRejectObjectWithoutStorageChange() public {
        _activateRejectingCapability(AVACapabilityKeys.ATTRIBUTION);
        uint256 evidenceId = _registerAuthorEvidence("m145-reject-attribution-evidence");
        uint256 nextObjectIdBefore = governanceKernel.nextGovernedObjectId();
        try authorActor.registerObject(
            governanceKernel,
            _objectInput(
                PeerReviewTypes.ROLE_AUTHOR,
                PeerReviewTypes.OBJECT_MANUSCRIPT,
                keccak256("m145-reject-attribution-object"),
                0,
                M14_AUTHOR_SUBJECT,
                evidenceId
            )
        ) {
            revert("rejecting attribution module allowed object");
        } catch {}
        require(governanceKernel.nextGovernedObjectId() == nextObjectIdBefore, "rejected object changed storage");
    }

    function testM145VerificationCapabilityCanRejectFormationWithoutStorageChange() public {
        _activateRejectingCapability(AVACapabilityKeys.VERIFICATION);
        (, uint256 reviewObjectId) = _registerManuscriptAndReview();
        uint256 nextStateIdBefore = governanceKernel.nextRecognisedStateId();
        try editorActorV2.formState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateFormationInput({
                governedObjectId: reviewObjectId,
                roleKey: PeerReviewTypes.ROLE_EDITOR,
                authorityId: M14_EDITOR_SUBJECT,
                stage: AVACoreTypes.Stage.Verification,
                status: AVACoreTypes.RecognisedStateStatus.Provisional,
                reasonHash: keccak256("m145-reject-verification"),
                reasonURI: "ipfs://m145-reject-verification"
            })
        ) {
            revert("rejecting verification module allowed formation");
        } catch {}
        require(governanceKernel.nextRecognisedStateId() == nextStateIdBefore, "rejected formation changed storage");
    }

    function testM145TransitionCapabilityCanRejectStatusChangeWithoutStorageChange() public {
        _activateRejectingCapability(AVACapabilityKeys.TRANSITION_RULE);
        (, uint256 reviewObjectId) = _registerManuscriptAndReview();
        uint256 stateId = editorActorV2.formState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateFormationInput({
                governedObjectId: reviewObjectId,
                roleKey: PeerReviewTypes.ROLE_EDITOR,
                authorityId: M14_EDITOR_SUBJECT,
                stage: AVACoreTypes.Stage.Verification,
                status: AVACoreTypes.RecognisedStateStatus.Provisional,
                reasonHash: keccak256("m145-reject-transition-formation"),
                reasonURI: "ipfs://m145-reject-transition-formation"
            })
        );
        uint256 nextTransitionIdBefore = governanceKernel.nextTransitionId();
        try editorActorV2.transitionState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_EDITOR,
                authorityId: M14_EDITOR_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Challengeable,
                reasonHash: keccak256("m145-reject-transition"),
                reasonURI: "ipfs://m145-reject-transition"
            })
        ) {
            revert("rejecting transition module allowed status change");
        } catch {}
        require(governanceKernel.nextTransitionId() == nextTransitionIdBefore, "rejected transition wrote ledger");
        require(
            governanceKernel.getRecognisedState(stateId).status == AVACoreTypes.RecognisedStateStatus.Provisional,
            "rejected transition changed status"
        );
    }

    function testM145EvidenceAndDisclosureCapabilitiesCanRejectWithoutStorageChange() public {
        _assertEvidenceCapabilityRejects(AVACapabilityKeys.EVIDENCE_POLICY);
    }

    function testPerformanceEvidenceRegistrationRevalidatesPackageIdentityOnce() public {
        PERFORMANCE_VM.expectCall(
            address(peerReviewModule), abi.encodeCall(IRuleModuleIdentity.moduleIdentityHash, ()), 1
        );
        authorActor.registerEvidence(
            coreEvidenceRegistry,
            WORKFLOW,
            packageId,
            PeerReviewTypes.ROLE_AUTHOR,
            M14_AUTHOR_SUBJECT,
            keccak256("performance-single-package-verification-evidence"),
            policyId
        );
    }

    function testPerformanceGovernedObjectRegistrationRevalidatesPackageIdentityOnce() public {
        uint256 evidenceId = _registerAuthorEvidence("performance-object-evidence");
        PERFORMANCE_VM.expectCall(
            address(peerReviewModule), abi.encodeCall(IRuleModuleIdentity.moduleIdentityHash, ()), 1
        );
        authorActor.registerObject(
            governanceKernel,
            _objectInput(
                PeerReviewTypes.ROLE_AUTHOR,
                PeerReviewTypes.OBJECT_MANUSCRIPT,
                keccak256("performance-single-package-verification-object"),
                0,
                M14_AUTHOR_SUBJECT,
                evidenceId
            )
        );
    }

    function testPerformanceRecognisedStateFormationRevalidatesPackageIdentityOnce() public {
        (, uint256 reviewObjectId) = _registerManuscriptAndReview();
        PERFORMANCE_VM.expectCall(
            address(peerReviewModule), abi.encodeCall(IRuleModuleIdentity.moduleIdentityHash, ()), 1
        );
        uint256 gasBefore = gasleft();
        editorActorV2.formState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateFormationInput({
                governedObjectId: reviewObjectId,
                roleKey: PeerReviewTypes.ROLE_EDITOR,
                authorityId: M14_EDITOR_SUBJECT,
                stage: AVACoreTypes.Stage.Verification,
                status: AVACoreTypes.RecognisedStateStatus.Provisional,
                reasonHash: keccak256("performance-single-package-formation"),
                reasonURI: "ipfs://performance-single-package-formation"
            })
        );
        require(gasBefore - gasleft() < 825_000, "formation copied full governed object");
    }

    function testPerformanceGenericTransitionRevalidatesPackageIdentityOnce() public {
        (, uint256 reviewObjectId) = _registerManuscriptAndReview();
        uint256 stateId = editorActorV2.formState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateFormationInput({
                governedObjectId: reviewObjectId,
                roleKey: PeerReviewTypes.ROLE_EDITOR,
                authorityId: M14_EDITOR_SUBJECT,
                stage: AVACoreTypes.Stage.Verification,
                status: AVACoreTypes.RecognisedStateStatus.Provisional,
                reasonHash: keccak256("performance-transition-formation"),
                reasonURI: "ipfs://performance-transition-formation"
            })
        );
        PERFORMANCE_VM.expectCall(
            address(peerReviewModule), abi.encodeCall(IRuleModuleIdentity.moduleIdentityHash, ()), 1
        );
        uint256 gasBefore = gasleft();
        editorActorV2.transitionState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_EDITOR,
                authorityId: M14_EDITOR_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Challengeable,
                reasonHash: keccak256("performance-single-package-transition"),
                reasonURI: "ipfs://performance-single-package-transition"
            })
        );
        require(gasBefore - gasleft() < 496_000, "generic transition copied full governed object");
    }

    function testPerformanceSourceBoundTransitionRevalidatesSharedPackageIdentityOnce() public {
        packageId = _supersedePackage("ipfs://performance-source-bound-package");
        M14UncheckedHighImpactRequester requester = new M14UncheckedHighImpactRequester();
        governanceKernel.bindSourceBoundTransitionRequester(packageId, address(requester));
        uint256 stateId = _createM14ChallengeableReviewState();
        AVACoreTypes.RecognisedStateRecord memory state = governanceKernel.getRecognisedState(stateId);

        PERFORMANCE_VM.expectCall(
            address(peerReviewModule), abi.encodeCall(IRuleModuleIdentity.moduleIdentityHash, ()), 1
        );
        uint256 gasBefore = gasleft();
        requester.request(
            governanceKernel,
            AVAGovernanceKernel.SourceBoundTransitionInput({
                recognisedStateId: stateId,
                expectedTransitionId: state.lastTransitionId,
                decisionPackageId: packageId,
                sourceRecordId: 1,
                decisionEvidenceReceiptId: state.evidenceReceiptId,
                disclosureTargetId: stateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                actionKey: AVACoreTypes.ACTION_RESOLVE_CHALLENGE,
                decisionHash: keccak256("performance-source-bound-decision"),
                toStatus: AVACoreTypes.RecognisedStateStatus.Downgraded,
                kind: AVACoreTypes.TransitionKind.ChallengeCorrection,
                reasonHash: keccak256("performance-source-bound-transition"),
                reasonURI: "ipfs://performance-source-bound-transition"
            })
        );
        require(gasBefore - gasleft() < 528_000, "source-bound transition copied full governed object");
    }

    function testPerformanceCanonicalPackageSharesStatelessDefaultCorePolicyBundle() public view {
        address bundle = corePackageRegistry.getModule(packageId, AVACapabilityKeys.ATTRIBUTION);
        require(
            bundle == corePackageRegistry.getModule(packageId, AVACapabilityKeys.VERIFICATION), "verification split"
        );
        require(
            bundle == corePackageRegistry.getModule(packageId, AVACapabilityKeys.TRANSITION_RULE), "transition split"
        );
        require(
            bundle == corePackageRegistry.getModule(packageId, AVACapabilityKeys.EVIDENCE_POLICY),
            "evidence policy split"
        );
        require(
            bundle == corePackageRegistry.getModule(packageId, AVACapabilityKeys.EVIDENCE_LIFECYCLE),
            "evidence lifecycle split"
        );
        require(
            bundle == corePackageRegistry.getModule(packageId, AVACapabilityKeys.DISCLOSURE_POLICY), "disclosure split"
        );
        require(
            bundle == corePackageRegistry.getModule(packageId, AVACapabilityKeys.CHALLENGE_POLICY), "challenge split"
        );
        require(
            bundle == corePackageRegistry.getModule(packageId, AVACapabilityKeys.AUTHORITY_POLICY), "authority split"
        );
        require(bundle == corePackageRegistry.getModule(packageId, AVACapabilityKeys.STANDING), "standing split");
        require(bundle == corePackageRegistry.getModule(packageId, AVACapabilityKeys.ALLOCATION), "allocation split");
        require(bundle == corePackageRegistry.getModule(packageId, AVACapabilityKeys.CONSEQUENCE), "consequence split");
        require(bundle == corePackageRegistry.getModule(packageId, AVACapabilityKeys.FIELD_POLICY), "field split");
        require(bundle == corePackageRegistry.getModule(packageId, AVACapabilityKeys.ANTI_ABUSE), "anti-abuse split");
    }

    function testPerformanceCanonicalPackageSharesStatelessDefaultExtensionPolicyBundle() public view {
        address bundle = corePackageRegistry.getModule(packageId, AVACapabilityKeys.STANDING_COMPUTATION);
        require(
            bundle == corePackageRegistry.getModule(packageId, AVACapabilityKeys.STANDING_CREDENTIAL),
            "standing credential split"
        );
        require(bundle == corePackageRegistry.getModule(packageId, AVACapabilityKeys.REWARD), "reward split");
        require(bundle == corePackageRegistry.getModule(packageId, AVACapabilityKeys.PRIORITY), "priority split");
        require(bundle == corePackageRegistry.getModule(packageId, AVACapabilityKeys.RESTORATION), "restoration split");
        require(
            bundle == corePackageRegistry.getModule(packageId, AVACapabilityKeys.VALUE_EXECUTION),
            "value execution split"
        );
        require(
            bundle == corePackageRegistry.getModule(packageId, AVACapabilityKeys.AUDIT_RECEIPT), "audit receipt split"
        );
        require(
            bundle == corePackageRegistry.getModule(packageId, AVACapabilityKeys.STANDING_PROVENANCE),
            "standing provenance split"
        );
        require(
            bundle == corePackageRegistry.getModule(packageId, AVACapabilityKeys.STANDING_ZK_PROOF),
            "standing ZK proof split"
        );
        require(
            bundle == corePackageRegistry.getModule(packageId, AVACapabilityKeys.STANDING_ZK_CREDENTIAL),
            "standing ZK credential split"
        );
        require(
            bundle == corePackageRegistry.getModule(packageId, AVACapabilityKeys.EXTERNAL_OPERATION),
            "external operation split"
        );
        require(
            bundle == corePackageRegistry.getModule(packageId, AVACapabilityKeys.PRIVACY_PROOF), "privacy proof split"
        );
        require(
            bundle == corePackageRegistry.getModule(packageId, AVACapabilityKeys.DISCLOSURE_RECEIPT),
            "disclosure receipt split"
        );
        require(
            bundle != corePackageRegistry.getModule(packageId, AVACapabilityKeys.PENALTY),
            "peer-review penalty policy was collapsed into permissive defaults"
        );
    }

    function testPerformanceDownstreamRecordRevalidatesPackageIdentityOnce() public {
        uint256 stateId = _createM14ChallengeableReviewState();
        panelActorV2.vestState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Vested,
                reasonHash: keccak256("performance-downstream-vest"),
                reasonURI: "ipfs://performance-downstream-vest"
            })
        );
        (AVAStandingRecordExtension standingExtension,,) = _deployDownstreamExtensions();
        _authoriseDownstreamExtensions();
        PERFORMANCE_VM.expectCall(
            address(peerReviewModule), abi.encodeCall(IRuleModuleIdentity.moduleIdentityHash, ()), 1
        );
        panelActorV2.recordStanding(
            standingExtension,
            AVAStandingRecordExtension.StandingInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                subjectId: M14_REVIEWER_SUBJECT,
                evidenceId: governanceKernel.getRecognisedState(stateId).evidenceReceiptId,
                dimensionKey: keccak256("performance-downstream-dimension"),
                delta: 1,
                reasonHash: keccak256("performance-downstream-standing"),
                uri: "ipfs://performance-downstream-standing"
            })
        );
    }

    function testM145DisclosureCapabilityCanRejectEvidenceWithoutStorageChange() public {
        _assertEvidenceCapabilityRejects(AVACapabilityKeys.DISCLOSURE_POLICY);
    }

    function testM145EvidenceLifecycleCapabilityCanRejectWithoutStorageChange() public {
        _activateRejectingCapability(AVACapabilityKeys.EVIDENCE_LIFECYCLE);
        uint256 evidenceId = _registerAuthorEvidence("m145-reject-evidence-lifecycle");
        uint256 nextLifecycleIdBefore = coreEvidenceRegistry.nextLifecycleRecordId();
        try panelActorV2.recordEvidenceLifecycle(
            coreEvidenceRegistry,
            evidenceId,
            PeerReviewTypes.ROLE_PANEL,
            M14_PANEL_SUBJECT,
            AVACoreTypes.EvidenceLifecycleKind.Revoke,
            keccak256("m145-reject-evidence-lifecycle")
        ) {
            revert("rejecting evidence lifecycle module allowed mutation");
        } catch {}
        require(
            coreEvidenceRegistry.nextLifecycleRecordId() == nextLifecycleIdBefore,
            "rejected evidence lifecycle wrote record"
        );
        require(
            coreEvidenceRegistry.getEvidence(evidenceId).status == AVACoreTypes.EvidenceStatus.Active,
            "rejected evidence lifecycle changed status"
        );
    }

    function testM145EvidenceSupersessionRejectsDifferentEvidenceType() public {
        uint256 originalEvidenceId = authorActor.registerTypedEvidence(
            coreEvidenceRegistry,
            WORKFLOW,
            packageId,
            PeerReviewTypes.ROLE_AUTHOR,
            M14_AUTHOR_SUBJECT,
            keccak256("m145-original-typed-evidence"),
            keccak256("m145.evidence-type.original"),
            policyId
        );
        uint256 replacementEvidenceId = authorActor.registerTypedEvidence(
            coreEvidenceRegistry,
            WORKFLOW,
            packageId,
            PeerReviewTypes.ROLE_AUTHOR,
            M14_AUTHOR_SUBJECT,
            keccak256("m145-replacement-typed-evidence"),
            keccak256("m145.evidence-type.different"),
            policyId
        );
        uint256 nextLifecycleIdBefore = coreEvidenceRegistry.nextLifecycleRecordId();
        try panelActorV2.supersedeEvidence(
            coreEvidenceRegistry,
            originalEvidenceId,
            replacementEvidenceId,
            PeerReviewTypes.ROLE_PANEL,
            M14_PANEL_SUBJECT,
            keccak256("m145-cross-type-supersession")
        ) {
            revert("different evidence type superseded original receipt");
        } catch {}
        require(
            coreEvidenceRegistry.nextLifecycleRecordId() == nextLifecycleIdBefore,
            "cross-type supersession wrote lifecycle"
        );
        require(
            coreEvidenceRegistry.getEvidence(originalEvidenceId).status == AVACoreTypes.EvidenceStatus.Active,
            "cross-type supersession changed evidence"
        );
    }

    function testEvidenceCannotSupersedeItself() public {
        uint256 evidenceId = _registerAuthorEvidence("self-supersession-evidence");
        uint256 nextLifecycleIdBefore = coreEvidenceRegistry.nextLifecycleRecordId();

        try panelActorV2.supersedeEvidence(
            coreEvidenceRegistry,
            evidenceId,
            evidenceId,
            PeerReviewTypes.ROLE_PANEL,
            M14_PANEL_SUBJECT,
            keccak256("self-supersession")
        ) {
            revert("evidence superseded itself");
        } catch {}

        require(
            coreEvidenceRegistry.nextLifecycleRecordId() == nextLifecycleIdBefore, "self-supersession wrote lifecycle"
        );
        AVACoreTypes.EvidenceRecord memory evidence = coreEvidenceRegistry.getEvidence(evidenceId);
        require(evidence.status == AVACoreTypes.EvidenceStatus.Active, "self-supersession changed status");
        require(evidence.replacementEvidenceId == 0, "self-supersession wrote replacement");
    }

    function testM145ChallengeCapabilityCanRejectFilingWithoutStorageChange() public {
        _activateRejectingCapability(AVACapabilityKeys.CHALLENGE_POLICY);
        uint256 stateId = _createM14ChallengeableReviewState();
        uint256 challengeEvidenceId = _registerChallengeEvidence("m145-reject-challenge-evidence");
        uint256 challengeStateId = _createChallengeRecognisedState(
            challengerActorV2,
            M14_CHALLENGER_SUBJECT,
            WORKFLOW,
            packageId,
            stateId,
            challengeEvidenceId,
            "m145-reject-challenge"
        );
        uint256 nextChallengeIdBefore = challengeExtension.nextChallengeId();
        try challengerActorV2.fileChallenge(
            challengeExtension, _challengeInput(stateId, challengeStateId, "m145-reject-challenge")
        ) {
            revert("rejecting challenge module allowed filing");
        } catch {}
        require(challengeExtension.nextChallengeId() == nextChallengeIdBefore, "rejected challenge changed storage");
        require(challengeExtension.openChallengeCountByRecognisedState(stateId) == 0, "rejected challenge opened");
    }

    function testCanonicalChallengeCannotReuseTargetRecognisedStateAsChallengeObject() public {
        uint256 stateId = _createM14ChallengeableReviewState();
        uint256 challengeEvidenceId = _registerChallengeEvidence("canonical-recursive-challenge-evidence");
        uint256 nextChallengeIdBefore = challengeExtension.nextChallengeId();
        try challengerActorV2.fileChallenge(
            challengeExtension, _challengeInput(stateId, challengeEvidenceId, "canonical-recursive-challenge")
        ) {
            revert("raw target state was accepted as its own challenge workflow state");
        } catch {}
        require(
            challengeExtension.nextChallengeId() == nextChallengeIdBefore, "invalid recursive filing wrote challenge"
        );
        require(challengeExtension.openChallengeCountByRecognisedState(stateId) == 0, "invalid recursive filing opened");
    }

    function testM145AuthorityCapabilityCanRejectScreeningWithoutStorageChange() public {
        _activateCapabilityModule(
            AVACapabilityKeys.AUTHORITY_POLICY,
            IRuleModuleIdentity(
                address(new M14ActionRejectingAuthorityPolicyModule(AVACoreTypes.ACTION_SCREEN_CHALLENGE))
            )
        );
        uint256 stateId = _createM14ChallengeableReviewState();
        uint256 challengeId = _fileChallenge(stateId, "m145-reject-authority");
        uint256 nextTransitionIdBefore = challengeExtension.nextTransitionId();
        try editorActorV2.screenChallenge(
            challengeExtension, challengeId, PeerReviewTypes.ROLE_EDITOR, M14_EDITOR_SUBJECT
        ) {
            revert("rejecting authority module allowed screening");
        } catch {}
        require(challengeExtension.nextTransitionId() == nextTransitionIdBefore, "rejected screening wrote transition");
        require(
            challengeExtension.getChallenge(challengeId).status == AVAChallengeExtension.ChallengeStatus.ConcernFiled,
            "rejected screening changed lifecycle"
        );
    }

    function testCanonicalFormationDispatchesDisclosurePolicyWithoutStorageChange() public {
        _activateCapabilityModule(
            AVACapabilityKeys.DISCLOSURE_POLICY,
            IRuleModuleIdentity(
                address(new M14ActionRejectingDisclosurePolicyModule(AVACoreTypes.ACTION_FORM_RECOGNISED_STATE))
            )
        );
        (, uint256 reviewObjectId) = _registerManuscriptAndReview();
        uint256 nextStateIdBefore = governanceKernel.nextRecognisedStateId();
        try editorActorV2.formState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateFormationInput({
                governedObjectId: reviewObjectId,
                roleKey: PeerReviewTypes.ROLE_EDITOR,
                authorityId: M14_EDITOR_SUBJECT,
                stage: AVACoreTypes.Stage.Verification,
                status: AVACoreTypes.RecognisedStateStatus.Provisional,
                reasonHash: keccak256("canonical-formation-disclosure-rejection"),
                reasonURI: "ipfs://canonical-formation-disclosure-rejection"
            })
        ) {
            revert("formation bypassed package disclosure policy");
        } catch {}
        require(governanceKernel.nextRecognisedStateId() == nextStateIdBefore, "rejected formation wrote state");
    }

    function testCanonicalGenericTransitionDispatchesDisclosurePolicyWithoutMutation() public {
        _activateCapabilityModule(
            AVACapabilityKeys.DISCLOSURE_POLICY,
            IRuleModuleIdentity(
                address(new M14ActionRejectingDisclosurePolicyModule(AVACoreTypes.ACTION_TRANSITION_RECOGNISED_STATE))
            )
        );
        (, uint256 reviewObjectId) = _registerManuscriptAndReview();
        uint256 stateId = editorActorV2.formState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateFormationInput({
                governedObjectId: reviewObjectId,
                roleKey: PeerReviewTypes.ROLE_EDITOR,
                authorityId: M14_EDITOR_SUBJECT,
                stage: AVACoreTypes.Stage.Verification,
                status: AVACoreTypes.RecognisedStateStatus.Provisional,
                reasonHash: keccak256("canonical-transition-disclosure-state"),
                reasonURI: "ipfs://canonical-transition-disclosure-state"
            })
        );
        uint256 transitionIdBefore = governanceKernel.getRecognisedState(stateId).lastTransitionId;
        try editorActorV2.transitionState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_EDITOR,
                authorityId: M14_EDITOR_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Challengeable,
                reasonHash: keccak256("canonical-transition-disclosure-rejection"),
                reasonURI: "ipfs://canonical-transition-disclosure-rejection"
            })
        ) {
            revert("transition bypassed package disclosure policy");
        } catch {}
        AVACoreTypes.RecognisedStateRecord memory state = governanceKernel.getRecognisedState(stateId);
        require(state.status == AVACoreTypes.RecognisedStateStatus.Provisional, "rejected transition mutated status");
        require(state.lastTransitionId == transitionIdBefore, "rejected transition wrote ledger");
    }

    function testCanonicalVestingDispatchesAuthorityPolicyWithoutMutation() public {
        _activateCapabilityModule(
            AVACapabilityKeys.AUTHORITY_POLICY,
            IRuleModuleIdentity(
                address(new M14ActionRejectingAuthorityPolicyModule(AVACoreTypes.ACTION_VEST_RECOGNISED_STATE))
            )
        );
        uint256 stateId = _createM14ChallengeableReviewState();
        uint256 transitionIdBefore = governanceKernel.getRecognisedState(stateId).lastTransitionId;
        try panelActorV2.vestState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Vested,
                reasonHash: keccak256("canonical-vesting-authority-rejection"),
                reasonURI: "ipfs://canonical-vesting-authority-rejection"
            })
        ) {
            revert("vesting bypassed package authority policy");
        } catch {}
        AVACoreTypes.RecognisedStateRecord memory state = governanceKernel.getRecognisedState(stateId);
        require(state.status == AVACoreTypes.RecognisedStateStatus.Challengeable, "rejected vesting mutated status");
        require(state.lastTransitionId == transitionIdBefore, "rejected vesting wrote ledger");
    }

    function testCanonicalFormationDispatchesEvidenceUsePolicyWithoutStorageChange() public {
        _activateCapabilityModule(
            AVACapabilityKeys.EVIDENCE_POLICY,
            IRuleModuleIdentity(
                address(new M14ActionRejectingEvidencePolicyModule(AVACoreTypes.ACTION_FORM_RECOGNISED_STATE))
            )
        );
        (, uint256 reviewObjectId) = _registerManuscriptAndReview();
        uint256 nextStateIdBefore = governanceKernel.nextRecognisedStateId();
        try editorActorV2.formState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateFormationInput({
                governedObjectId: reviewObjectId,
                roleKey: PeerReviewTypes.ROLE_EDITOR,
                authorityId: M14_EDITOR_SUBJECT,
                stage: AVACoreTypes.Stage.Verification,
                status: AVACoreTypes.RecognisedStateStatus.Provisional,
                reasonHash: keccak256("canonical-formation-evidence-use-rejection"),
                reasonURI: "ipfs://canonical-formation-evidence-use-rejection"
            })
        ) {
            revert("formation bypassed package evidence-use policy");
        } catch {}
        require(governanceKernel.nextRecognisedStateId() == nextStateIdBefore, "evidence rejection wrote state");
    }

    function testCanonicalTransitionDispatchesEvidenceLifecycleUseWithoutMutation() public {
        _activateCapabilityModule(
            AVACapabilityKeys.EVIDENCE_LIFECYCLE,
            IRuleModuleIdentity(
                address(new M14ActionRejectingEvidenceLifecycleModule(AVACoreTypes.ACTION_TRANSITION_RECOGNISED_STATE))
            )
        );
        (, uint256 reviewObjectId) = _registerManuscriptAndReview();
        uint256 stateId = editorActorV2.formState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateFormationInput({
                governedObjectId: reviewObjectId,
                roleKey: PeerReviewTypes.ROLE_EDITOR,
                authorityId: M14_EDITOR_SUBJECT,
                stage: AVACoreTypes.Stage.Verification,
                status: AVACoreTypes.RecognisedStateStatus.Provisional,
                reasonHash: keccak256("canonical-transition-evidence-lifecycle-state"),
                reasonURI: "ipfs://canonical-transition-evidence-lifecycle-state"
            })
        );
        uint256 transitionIdBefore = governanceKernel.getRecognisedState(stateId).lastTransitionId;
        try editorActorV2.transitionState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_EDITOR,
                authorityId: M14_EDITOR_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Challengeable,
                reasonHash: keccak256("canonical-transition-evidence-lifecycle-rejection"),
                reasonURI: "ipfs://canonical-transition-evidence-lifecycle-rejection"
            })
        ) {
            revert("transition bypassed evidence lifecycle use policy");
        } catch {}
        AVACoreTypes.RecognisedStateRecord memory state = governanceKernel.getRecognisedState(stateId);
        require(state.status == AVACoreTypes.RecognisedStateStatus.Provisional, "evidence rejection mutated state");
        require(state.lastTransitionId == transitionIdBefore, "evidence rejection wrote transition");
    }

    function testM145IndependentChallengePackagePreservesTargetPackageAndTransitionLineage() public {
        uint256 stateId = _createM14ChallengeableReviewState();
        uint256 targetPackageId = packageId;
        uint256 challengePackageId = _registerIndependentChallengePackage(_peerReviewBindings(peerReviewModule));
        uint256 challengeEvidenceId = challengerActorV2.registerEvidence(
            coreEvidenceRegistry,
            CHALLENGE_WORKFLOW,
            challengePackageId,
            PeerReviewTypes.ROLE_CHALLENGER,
            M14_CHALLENGER_SUBJECT,
            keccak256("m145-independent-challenge-evidence"),
            policyId
        );
        uint256 challengeStateId = _createChallengeRecognisedState(
            challengerActorV2,
            M14_CHALLENGER_SUBJECT,
            CHALLENGE_WORKFLOW,
            challengePackageId,
            stateId,
            challengeEvidenceId,
            "m145-independent-challenge"
        );
        uint256 challengeId = challengerActorV2.fileChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeFilingInput({
                appId: PeerReviewTypes.APP_ID,
                workflowKey: CHALLENGE_WORKFLOW,
                packageId: challengePackageId,
                challengeRecognisedStateId: challengeStateId,
                challengedRecognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_CHALLENGER,
                reasonHash: keccak256("m145-independent-challenge"),
                reasonURI: "ipfs://m145-independent-challenge"
            })
        );
        AVAChallengeExtension.ChallengeRecord memory challenge = challengeExtension.getChallenge(challengeId);
        require(challenge.packageId == challengePackageId, "challenge package not pinned");
        require(challenge.targetPackageId == targetPackageId, "target package not pinned");
        require(
            governanceKernel.getRecognisedState(stateId).packageId == targetPackageId,
            "challenge rewrote target package"
        );
        editorActorV2.screenChallenge(challengeExtension, challengeId, PeerReviewTypes.ROLE_EDITOR, M14_EDITOR_SUBJECT);
        panelActorV2.resolveChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeResolutionInput({
                challengeId: challengeId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                outcome: AVAChallengeExtension.ChallengeOutcome.Upheld,
                correctionStatus: AVACoreTypes.RecognisedStateStatus.Downgraded,
                reasonHash: keccak256("m145-independent-challenge-resolution"),
                reasonURI: "ipfs://m145-independent-challenge-resolution"
            })
        );
        AVACoreTypes.RecognisedStateTransitionRecord memory correction = governanceKernel.getRecognisedStateTransition(
            governanceKernel.getRecognisedState(stateId).lastTransitionId
        );
        require(correction.packageId == targetPackageId, "transition lost target package");
        require(correction.decisionPackageId == challengePackageId, "transition lost decision package");
        require(correction.sourceRecordId == challengeId, "transition lost challenge source");
        require(
            correction.evidenceReceiptId == governanceKernel.getRecognisedState(stateId).evidenceReceiptId,
            "transition lost target evidence"
        );
        require(correction.decisionEvidenceReceiptId == challengeEvidenceId, "transition lost decision evidence");

        uint256 auditId = panelActorV2.recordAudit(
            auditExtension,
            AVAAuditReceiptExtension.AuditInput({
                targetKind: AVAAuditReceiptExtension.AuditTargetKind.RecognisedStateTransition,
                targetId: correction.id,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                subjectId: M14_CHALLENGER_SUBJECT,
                evidenceId: challengeEvidenceId,
                auditTypeKey: keccak256("m145-independent-correction-audit"),
                attestationHash: keccak256("m145-independent-correction-attestation"),
                reasonHash: keccak256("m145-independent-correction-audit-reason"),
                uri: "ipfs://m145-independent-correction-audit"
            })
        );
        AVAAuditReceiptExtension.AuditReceipt memory audit = auditExtension.getAuditReceipt(auditId);
        require(audit.packageId == challengePackageId, "transition audit lost decision package");
        require(audit.targetId == correction.id, "transition audit lost transition target");
        require(audit.sourceRecordId == correction.id, "transition audit source is not the transition");
    }

    function testM145PermissiveChallengePackageCannotBypassTargetChallengePolicy() public {
        _activateRejectingCapability(AVACapabilityKeys.CHALLENGE_POLICY);
        uint256 stateId = _createM14ChallengeableReviewState();
        uint256 challengePackageId = _registerIndependentChallengePackage(_coreBindings(peerReviewModule));
        uint256 challengeEvidenceId = challengerActorV2.registerEvidence(
            coreEvidenceRegistry,
            CHALLENGE_WORKFLOW,
            challengePackageId,
            PeerReviewTypes.ROLE_CHALLENGER,
            M14_CHALLENGER_SUBJECT,
            keccak256("m145-target-challenge-policy-evidence"),
            policyId
        );
        uint256 challengeStateId = _createChallengeRecognisedState(
            challengerActorV2,
            M14_CHALLENGER_SUBJECT,
            CHALLENGE_WORKFLOW,
            challengePackageId,
            stateId,
            challengeEvidenceId,
            "m145-target-challenge-policy"
        );
        uint256 nextChallengeIdBefore = challengeExtension.nextChallengeId();
        try challengerActorV2.fileChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeFilingInput({
                appId: PeerReviewTypes.APP_ID,
                workflowKey: CHALLENGE_WORKFLOW,
                packageId: challengePackageId,
                challengeRecognisedStateId: challengeStateId,
                challengedRecognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_CHALLENGER,
                reasonHash: keccak256("m145-target-challenge-policy"),
                reasonURI: "ipfs://m145-target-challenge-policy"
            })
        ) {
            revert("challenge package bypassed target challenge policy");
        } catch {}
        require(challengeExtension.nextChallengeId() == nextChallengeIdBefore, "target rejection wrote challenge");
    }

    function testM145PermissiveChallengePackageCannotBypassTargetAuthorityPolicy() public {
        _activateCapabilityModule(
            AVACapabilityKeys.AUTHORITY_POLICY,
            IRuleModuleIdentity(
                address(new M14ActionRejectingAuthorityPolicyModule(AVACoreTypes.ACTION_SCREEN_CHALLENGE))
            )
        );
        uint256 stateId = _createM14ChallengeableReviewState();
        uint256 challengePackageId = _registerIndependentChallengePackage(_coreBindings(peerReviewModule));
        uint256 challengeEvidenceId = challengerActorV2.registerEvidence(
            coreEvidenceRegistry,
            CHALLENGE_WORKFLOW,
            challengePackageId,
            PeerReviewTypes.ROLE_CHALLENGER,
            M14_CHALLENGER_SUBJECT,
            keccak256("m145-target-authority-policy-evidence"),
            policyId
        );
        uint256 challengeStateId = _createChallengeRecognisedState(
            challengerActorV2,
            M14_CHALLENGER_SUBJECT,
            CHALLENGE_WORKFLOW,
            challengePackageId,
            stateId,
            challengeEvidenceId,
            "m145-target-authority-policy"
        );
        uint256 challengeId = challengerActorV2.fileChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeFilingInput({
                appId: PeerReviewTypes.APP_ID,
                workflowKey: CHALLENGE_WORKFLOW,
                packageId: challengePackageId,
                challengeRecognisedStateId: challengeStateId,
                challengedRecognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_CHALLENGER,
                reasonHash: keccak256("m145-target-authority-policy"),
                reasonURI: "ipfs://m145-target-authority-policy"
            })
        );
        uint256 nextTransitionIdBefore = challengeExtension.nextTransitionId();
        try editorActorV2.screenChallenge(
            challengeExtension, challengeId, PeerReviewTypes.ROLE_EDITOR, M14_EDITOR_SUBJECT
        ) {
            revert("challenge package bypassed target authority policy");
        } catch {}
        require(
            challengeExtension.nextTransitionId() == nextTransitionIdBefore,
            "target authority rejection wrote transition"
        );
        require(
            challengeExtension.getChallenge(challengeId).status == AVAChallengeExtension.ChallengeStatus.ConcernFiled,
            "target authority rejection changed lifecycle"
        );
    }

    function testM145ChallengeFilingRejectsTargetPackageWithoutBoundChallengeSafety() public {
        packageId = _supersedePackage("ipfs://m145-unbound-target-package");
        uint256 stateId = _createM14ChallengeableReviewState();
        uint256 challengePackageId = _registerIndependentChallengePackage(_coreBindings(peerReviewModule));
        uint256 challengeEvidenceId = challengerActorV2.registerEvidence(
            coreEvidenceRegistry,
            CHALLENGE_WORKFLOW,
            challengePackageId,
            PeerReviewTypes.ROLE_CHALLENGER,
            M14_CHALLENGER_SUBJECT,
            keccak256("m145-unbound-target-evidence"),
            policyId
        );
        uint256 challengeStateId = _createChallengeRecognisedState(
            challengerActorV2,
            M14_CHALLENGER_SUBJECT,
            CHALLENGE_WORKFLOW,
            challengePackageId,
            stateId,
            challengeEvidenceId,
            "m145-unbound-target"
        );
        uint256 nextChallengeIdBefore = challengeExtension.nextChallengeId();
        try challengerActorV2.fileChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeFilingInput({
                appId: PeerReviewTypes.APP_ID,
                workflowKey: CHALLENGE_WORKFLOW,
                packageId: challengePackageId,
                challengeRecognisedStateId: challengeStateId,
                challengedRecognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_CHALLENGER,
                reasonHash: keccak256("m145-unbound-target"),
                reasonURI: "ipfs://m145-unbound-target"
            })
        ) {
            revert("challenge filed against package without challenge safety bindings");
        } catch {}
        require(challengeExtension.nextChallengeId() == nextChallengeIdBefore, "unbound target wrote challenge");
    }

    function testM145StandingCapabilityCanRejectRecordWithoutStorageChange() public {
        _assertDownstreamCapabilityRejects(AVACapabilityKeys.STANDING);
    }

    function testM145AllocationCapabilityCanRejectRecordWithoutStorageChange() public {
        _assertDownstreamCapabilityRejects(AVACapabilityKeys.ALLOCATION);
    }

    function testM145AllocationCapabilityReceivesUnitsAndCanNarrowCoreBound() public {
        _activateCapabilityModule(
            AVACapabilityKeys.ALLOCATION, IRuleModuleIdentity(address(new M14BoundedAllocationPolicyModule(1)))
        );
        uint256 stateId = _createM14ChallengeableReviewState();
        panelActorV2.vestState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Vested,
                reasonHash: keccak256("m145-bounded-allocation-vest"),
                reasonURI: "ipfs://m145-bounded-allocation-vest"
            })
        );
        (, AVAAllocationRecordExtension allocationExtension,) = _deployDownstreamExtensions();
        _authoriseDownstreamExtensions();
        bytes32 executorSubject = keccak256("m145-bounded-allocation-executor");
        M14PeerReviewActor executorActor = new M14PeerReviewActor();
        coreIdentityRegistry.assignSubject(
            address(executorActor),
            PeerReviewTypes.APP_ID,
            PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
            executorSubject,
            "ipfs://m145-bounded-allocation-executor"
        );
        AVAAllocationRecordExtension.AllocationInput memory input = AVAAllocationRecordExtension.AllocationInput({
            recognisedStateId: stateId,
            roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
            authorityId: executorSubject,
            subjectId: M14_REVIEWER_SUBJECT,
            evidenceId: governanceKernel.getRecognisedState(stateId).evidenceReceiptId,
            allocationKindKey: keccak256("m145-bounded-allocation"),
            units: 2,
            reasonHash: keccak256("m145-bounded-allocation"),
            uri: "ipfs://m145-bounded-allocation"
        });
        uint256 nextAllocationIdBefore = allocationExtension.nextAllocationId();
        try executorActor.recordAllocation(allocationExtension, input) {
            revert("allocation policy did not receive units");
        } catch {}
        require(
            allocationExtension.nextAllocationId() == nextAllocationIdBefore, "narrowed allocation policy wrote record"
        );
        input.units = 1;
        uint256 allocationId = executorActor.recordAllocation(allocationExtension, input);
        require(allocationExtension.getAllocation(allocationId).units == 1, "bounded allocation not recorded");
    }

    function testM145ConsequenceCapabilityCanRejectRecordWithoutStorageChange() public {
        _assertDownstreamCapabilityRejects(AVACapabilityKeys.CONSEQUENCE);
    }

    function testParityRewardAndAdministrativePriorityRemainDistinctAllocationEdgeRecords() public {
        uint256 stateId = _createM14ChallengeableReviewState();
        panelActorV2.vestState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Vested,
                reasonHash: keccak256("parity-reward-priority-vest"),
                reasonURI: "ipfs://parity-reward-priority-vest"
            })
        );
        (, AVAAllocationRecordExtension allocationExtension,) = _deployDownstreamExtensions();
        M14PeerReviewActor protocolActor = new M14PeerReviewActor();
        bytes32 protocolSubject = keccak256("parity-reward-priority-protocol-subject");
        coreIdentityRegistry.assignSubject(
            address(protocolActor),
            PeerReviewTypes.APP_ID,
            PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
            protocolSubject,
            "ipfs://parity-reward-priority-protocol-subject"
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR, AVACoreTypes.ACTION_RECORD_ALLOCATION, true
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR, AVACoreTypes.ACTION_RECORD_REWARD, true
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID,
            PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
            AVACoreTypes.ACTION_RECORD_ADMINISTRATIVE_PRIORITY,
            true
        );
        AVACoreTypes.RecognisedStateRecord memory state = governanceKernel.getRecognisedState(stateId);
        uint256 allocationId = protocolActor.recordAllocation(
            allocationExtension,
            AVAAllocationRecordExtension.AllocationInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                authorityId: protocolSubject,
                subjectId: M14_REVIEWER_SUBJECT,
                evidenceId: state.evidenceReceiptId,
                allocationKindKey: keccak256("parity-bounded-allocation"),
                units: 4,
                reasonHash: keccak256("parity-bounded-allocation"),
                uri: "ipfs://parity-bounded-allocation"
            })
        );
        AVARewardPriorityExtension extension = new AVARewardPriorityExtension(
            governanceKernel,
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            coreDisclosureRegistry,
            IAVADownstreamRecordSource(address(allocationExtension))
        );
        AVARewardPriorityExtension.RewardPriorityInput memory input = AVARewardPriorityExtension.RewardPriorityInput({
            allocationId: allocationId,
            roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
            authorityId: protocolSubject,
            subjectId: M14_REVIEWER_SUBJECT,
            evidenceId: state.evidenceReceiptId,
            kindKey: keccak256("parity-reward-value"),
            units: 4,
            reasonHash: keccak256("parity-reward-value"),
            uri: "ipfs://parity-reward-value"
        });
        uint256 rewardId = protocolActor.recordReward(extension, input);
        input.kindKey = keccak256("parity-administrative-priority-right");
        input.reasonHash = keccak256("parity-administrative-priority-right");
        input.uri = "ipfs://parity-administrative-priority-right";
        uint256 priorityId = protocolActor.recordAdministrativePriority(extension, input);

        AVARewardPriorityExtension.RewardRecord memory reward = extension.getReward(rewardId);
        AVARewardPriorityExtension.PriorityRecord memory priority = extension.getPriority(priorityId);
        require(reward.allocationId == allocationId && priority.allocationId == allocationId, "source not bound");
        require(reward.packageId == state.packageId && priority.packageId == state.packageId, "package not bound");
        require(reward.kindKey != priority.kindKey, "reward and priority collapsed");
        require(reward.units == 4 && priority.units == 4, "units changed");
    }

    function testParityPenaltyStandingRestrictionAndRestorationAreSeparatedAndGoodFaithSafe() public {
        AVAStandingRevisionExtension revisionExtension = new AVAStandingRevisionExtension(governanceKernel);
        AVAPenaltyRestorationExtension extension = new AVAPenaltyRestorationExtension(
            governanceKernel,
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            coreDisclosureRegistry,
            challengeExtension,
            revisionExtension
        );
        revisionExtension.bindRevisionWriter(packageId, address(extension));
        governanceKernel.bindPostTransitionHook(packageId, address(revisionExtension));
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_RECORD_PENALTY, true
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_RECORD_STANDING_PENALTY_INPUT, true
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_RECORD_ELIGIBILITY_RESTRICTION, true
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_RECORD_RESTORATION, true
        );

        uint256 stateId = _createM14ChallengeableReviewState();
        uint256 challengeId = _fileChallenge(stateId, "parity-upheld-challenge");
        editorActorV2.screenChallenge(challengeExtension, challengeId, PeerReviewTypes.ROLE_EDITOR, M14_EDITOR_SUBJECT);
        uint256 resolutionTransitionId = panelActorV2.resolveChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeResolutionInput({
                challengeId: challengeId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                outcome: AVAChallengeExtension.ChallengeOutcome.Upheld,
                correctionStatus: AVACoreTypes.RecognisedStateStatus.Downgraded,
                reasonHash: keccak256("parity-upheld-resolution"),
                reasonURI: "ipfs://parity-upheld-resolution"
            })
        );
        uint256 penaltyId = panelActorV2.recordPenalty(
            extension,
            AVAPenaltyRestorationExtension.PenaltyInput({
                challengeTransitionId: resolutionTransitionId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                findingKey: PeerReviewTypes.FINDING_IRRESPONSIBLE_REVIEW,
                reasonHash: keccak256("parity-penalty"),
                uri: "ipfs://parity-penalty"
            })
        );
        uint256 revisionAfterResolution = revisionExtension.currentRevision(packageId, M14_REVIEWER_SUBJECT);
        uint256 standingPenaltyId = panelActorV2.recordStandingPenaltyInput(
            extension,
            AVAPenaltyRestorationExtension.StandingPenaltyInput({
                penaltyId: penaltyId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                dimensionKey: keccak256("peer-review.procedural-care"),
                delta: -2,
                reasonHash: keccak256("parity-standing-penalty"),
                uri: "ipfs://parity-standing-penalty"
            })
        );
        uint256 restrictionId = panelActorV2.recordEligibilityRestriction(
            extension,
            AVAPenaltyRestorationExtension.EligibilityRestrictionInput({
                penaltyId: penaltyId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                restrictionKey: PeerReviewTypes.RESTRICTION_REVIEW_ELIGIBILITY,
                expiresAt: uint64(block.timestamp + 7 days),
                reasonHash: keccak256("parity-eligibility-restriction"),
                uri: "ipfs://parity-eligibility-restriction"
            })
        );
        require(
            revisionExtension.currentRevision(packageId, M14_REVIEWER_SUBJECT) == revisionAfterResolution + 2,
            "standing-relevant records did not advance revision"
        );
        require(extension.getStandingPenaltyInput(standingPenaltyId).penaltyId == penaltyId, "penalty input unbound");
        require(extension.getEligibilityRestriction(restrictionId).penaltyId == penaltyId, "restriction unbound");

        panelActorV2.makeRestorationAvailable(
            challengeExtension,
            challengeId,
            PeerReviewTypes.ROLE_PANEL,
            M14_PANEL_SUBJECT,
            keccak256("parity-restoration-ready"),
            "ipfs://parity-restoration-ready"
        );
        uint256 restorationTransitionId = panelActorV2.restoreChallenge(
            challengeExtension,
            challengeId,
            PeerReviewTypes.ROLE_PANEL,
            M14_PANEL_SUBJECT,
            keccak256("parity-restoration"),
            "ipfs://parity-restoration"
        );
        uint256 restorationId = panelActorV2.recordRestoration(
            extension,
            AVAPenaltyRestorationExtension.RestorationInput({
                challengeTransitionId: restorationTransitionId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                reasonHash: keccak256("parity-restoration-record"),
                uri: "ipfs://parity-restoration-record"
            })
        );
        require(extension.getRestoration(restorationId).challengeId == challengeId, "restoration unbound");

        uint256 goodFaithChallengeId = _fileChallenge(stateId, "parity-good-faith-challenge");
        editorActorV2.screenChallenge(
            challengeExtension, goodFaithChallengeId, PeerReviewTypes.ROLE_EDITOR, M14_EDITOR_SUBJECT
        );
        uint256 goodFaithTransitionId = panelActorV2.resolveChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeResolutionInput({
                challengeId: goodFaithChallengeId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                outcome: AVAChallengeExtension.ChallengeOutcome.RejectedGoodFaith,
                correctionStatus: AVACoreTypes.RecognisedStateStatus.Challengeable,
                reasonHash: keccak256("parity-good-faith-resolution"),
                reasonURI: "ipfs://parity-good-faith-resolution"
            })
        );
        AVAPenaltyRestorationExtension.PenaltyInput memory goodFaithPenalty = AVAPenaltyRestorationExtension.PenaltyInput({
            challengeTransitionId: goodFaithTransitionId,
            roleKey: PeerReviewTypes.ROLE_PANEL,
            authorityId: M14_PANEL_SUBJECT,
            findingKey: keccak256("peer-review.good-faith-failure"),
            reasonHash: keccak256("parity-good-faith-penalty"),
            uri: "ipfs://parity-good-faith-penalty"
        });
        try panelActorV2.recordPenalty(extension, goodFaithPenalty) {
            revert("good-faith challenge created misconduct penalty");
        } catch {}
    }

    function testPerformancePenaltyRevalidatesDecisionPackageOnce() public {
        AVAStandingRevisionExtension revisionExtension = new AVAStandingRevisionExtension(governanceKernel);
        AVAPenaltyRestorationExtension extension = new AVAPenaltyRestorationExtension(
            governanceKernel,
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            coreDisclosureRegistry,
            challengeExtension,
            revisionExtension
        );
        revisionExtension.bindRevisionWriter(packageId, address(extension));
        governanceKernel.bindPostTransitionHook(packageId, address(revisionExtension));
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_RECORD_PENALTY, true
        );

        uint256 stateId = _createM14ChallengeableReviewState();
        uint256 challengeId = _fileChallenge(stateId, "performance-penalty-package-validation");
        editorActorV2.screenChallenge(challengeExtension, challengeId, PeerReviewTypes.ROLE_EDITOR, M14_EDITOR_SUBJECT);
        uint256 resolutionTransitionId = panelActorV2.resolveChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeResolutionInput({
                challengeId: challengeId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                outcome: AVAChallengeExtension.ChallengeOutcome.Upheld,
                correctionStatus: AVACoreTypes.RecognisedStateStatus.Downgraded,
                reasonHash: keccak256("performance-penalty-resolution"),
                reasonURI: "ipfs://performance-penalty-resolution"
            })
        );

        PERFORMANCE_VM.expectCall(
            address(peerReviewModule), abi.encodeCall(RuleModuleIdentity.moduleIdentityHash, ()), 1
        );
        uint256 penaltyId = panelActorV2.recordPenalty(
            extension,
            AVAPenaltyRestorationExtension.PenaltyInput({
                challengeTransitionId: resolutionTransitionId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                findingKey: PeerReviewTypes.FINDING_IRRESPONSIBLE_REVIEW,
                reasonHash: keccak256("performance-penalty-record"),
                uri: "ipfs://performance-penalty-record"
            })
        );
        require(extension.getPenalty(penaltyId).challengeId == challengeId, "penalty source changed");
    }

    function testTargetPenaltyCannotDeriveStandingOrEligibilityAfterRestoration() public {
        AVAStandingRevisionExtension revisionExtension = new AVAStandingRevisionExtension(governanceKernel);
        AVAPenaltyRestorationExtension extension = new AVAPenaltyRestorationExtension(
            governanceKernel,
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            coreDisclosureRegistry,
            challengeExtension,
            revisionExtension
        );
        revisionExtension.bindRevisionWriter(packageId, address(extension));
        governanceKernel.bindPostTransitionHook(packageId, address(revisionExtension));
        _authorisePenaltyExtension();

        uint256 stateId = _createM14ChallengeableReviewState();
        uint256 challengeId = _fileChallenge(stateId, "stale-target-penalty");
        editorActorV2.screenChallenge(challengeExtension, challengeId, PeerReviewTypes.ROLE_EDITOR, M14_EDITOR_SUBJECT);
        uint256 resolutionTransitionId = panelActorV2.resolveChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeResolutionInput({
                challengeId: challengeId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                outcome: AVAChallengeExtension.ChallengeOutcome.Upheld,
                correctionStatus: AVACoreTypes.RecognisedStateStatus.Downgraded,
                reasonHash: keccak256("stale-target-penalty-resolution"),
                reasonURI: "ipfs://stale-target-penalty-resolution"
            })
        );
        uint256 penaltyId = panelActorV2.recordPenalty(
            extension,
            AVAPenaltyRestorationExtension.PenaltyInput({
                challengeTransitionId: resolutionTransitionId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                findingKey: PeerReviewTypes.FINDING_IRRESPONSIBLE_REVIEW,
                reasonHash: keccak256("stale-target-penalty-record"),
                uri: "ipfs://stale-target-penalty-record"
            })
        );
        panelActorV2.makeRestorationAvailable(
            challengeExtension,
            challengeId,
            PeerReviewTypes.ROLE_PANEL,
            M14_PANEL_SUBJECT,
            keccak256("stale-target-penalty-restoration-available"),
            "ipfs://stale-target-penalty-restoration-available"
        );
        panelActorV2.restoreChallenge(
            challengeExtension,
            challengeId,
            PeerReviewTypes.ROLE_PANEL,
            M14_PANEL_SUBJECT,
            keccak256("stale-target-penalty-restored"),
            "ipfs://stale-target-penalty-restored"
        );

        bool standingAccepted;
        try panelActorV2.recordStandingPenaltyInput(
            extension,
            AVAPenaltyRestorationExtension.StandingPenaltyInput({
                penaltyId: penaltyId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                dimensionKey: keccak256("stale-target-penalty-standing"),
                delta: -1,
                reasonHash: keccak256("stale-target-penalty-standing"),
                uri: "ipfs://stale-target-penalty-standing"
            })
        ) returns (
            uint256
        ) {
            standingAccepted = true;
        } catch {}

        bool restrictionAccepted;
        try panelActorV2.recordEligibilityRestriction(
            extension,
            AVAPenaltyRestorationExtension.EligibilityRestrictionInput({
                penaltyId: penaltyId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                restrictionKey: PeerReviewTypes.RESTRICTION_REVIEW_ELIGIBILITY,
                expiresAt: uint64(block.timestamp + 7 days),
                reasonHash: keccak256("stale-target-penalty-restriction"),
                uri: "ipfs://stale-target-penalty-restriction"
            })
        ) returns (
            uint256
        ) {
            restrictionAccepted = true;
        } catch {}

        require(!standingAccepted, "restored target accepted stale standing penalty input");
        require(!restrictionAccepted, "restored target accepted stale eligibility restriction");
    }

    function testParityPeerReviewPenaltyRejectsOutcomeFindingMismatchAndUnboundedEffects() public {
        AVAStandingRevisionExtension revisionExtension = new AVAStandingRevisionExtension(governanceKernel);
        AVAPenaltyRestorationExtension extension = new AVAPenaltyRestorationExtension(
            governanceKernel,
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            coreDisclosureRegistry,
            challengeExtension,
            revisionExtension
        );
        revisionExtension.bindRevisionWriter(packageId, address(extension));
        governanceKernel.bindPostTransitionHook(packageId, address(revisionExtension));
        _authorisePenaltyExtension();

        uint256 stateId = _createM14ChallengeableReviewState();
        uint256 challengeId = _fileChallenge(stateId, "parity-penalty-policy");
        editorActorV2.screenChallenge(challengeExtension, challengeId, PeerReviewTypes.ROLE_EDITOR, M14_EDITOR_SUBJECT);
        uint256 resolutionTransitionId = panelActorV2.resolveChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeResolutionInput({
                challengeId: challengeId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                outcome: AVAChallengeExtension.ChallengeOutcome.Upheld,
                correctionStatus: AVACoreTypes.RecognisedStateStatus.Downgraded,
                reasonHash: keccak256("parity-penalty-policy-resolution"),
                reasonURI: "ipfs://parity-penalty-policy-resolution"
            })
        );
        uint256 nextPenaltyIdBefore = extension.nextPenaltyId();
        bool accepted;
        try panelActorV2.recordPenalty(
            extension,
            AVAPenaltyRestorationExtension.PenaltyInput({
                challengeTransitionId: resolutionTransitionId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                findingKey: PeerReviewTypes.FINDING_ACADEMIC_FRAUD,
                reasonHash: keccak256("parity-review-cannot-be-academic-fraud"),
                uri: "ipfs://parity-review-cannot-be-academic-fraud"
            })
        ) returns (
            uint256
        ) {
            accepted = true;
        } catch {}
        require(!accepted, "review target accepted author academic-fraud finding");
        require(extension.nextPenaltyId() == nextPenaltyIdBefore, "wrong-role finding wrote penalty");

        accepted = false;
        try panelActorV2.recordPenalty(
            extension,
            AVAPenaltyRestorationExtension.PenaltyInput({
                challengeTransitionId: resolutionTransitionId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                findingKey: PeerReviewTypes.FINDING_MALICIOUS_OR_FABRICATED_CHALLENGE,
                reasonHash: keccak256("parity-mismatched-upheld-finding"),
                uri: "ipfs://parity-mismatched-upheld-finding"
            })
        ) returns (
            uint256
        ) {
            accepted = true;
        } catch {}
        require(!accepted, "upheld target challenge accepted challenger misconduct finding");
        require(extension.nextPenaltyId() == nextPenaltyIdBefore, "mismatched finding wrote penalty");

        uint256 penaltyId = panelActorV2.recordPenalty(
            extension,
            AVAPenaltyRestorationExtension.PenaltyInput({
                challengeTransitionId: resolutionTransitionId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                findingKey: PeerReviewTypes.FINDING_IRRESPONSIBLE_REVIEW,
                reasonHash: keccak256("parity-valid-review-finding"),
                uri: "ipfs://parity-valid-review-finding"
            })
        );
        accepted = false;
        try panelActorV2.recordStandingPenaltyInput(
            extension,
            AVAPenaltyRestorationExtension.StandingPenaltyInput({
                penaltyId: penaltyId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                dimensionKey: keccak256("parity-unbounded-standing-delta"),
                delta: -1_000_001,
                reasonHash: keccak256("parity-unbounded-standing-delta"),
                uri: "ipfs://parity-unbounded-standing-delta"
            })
        ) returns (
            uint256
        ) {
            accepted = true;
        } catch {}
        require(!accepted, "unbounded standing penalty delta accepted");

        accepted = false;
        try panelActorV2.recordEligibilityRestriction(
            extension,
            AVAPenaltyRestorationExtension.EligibilityRestrictionInput({
                penaltyId: penaltyId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                restrictionKey: PeerReviewTypes.RESTRICTION_REVIEW_ELIGIBILITY,
                expiresAt: uint64(block.timestamp + 366 days),
                reasonHash: keccak256("parity-unbounded-restriction"),
                uri: "ipfs://parity-unbounded-restriction"
            })
        ) returns (
            uint256
        ) {
            accepted = true;
        } catch {}
        require(!accepted, "unbounded eligibility restriction accepted");
    }

    function testParityRecursiveChallengeTargetCannotUseReviewFinding() public {
        AVAStandingRevisionExtension revisionExtension = new AVAStandingRevisionExtension(governanceKernel);
        AVAPenaltyRestorationExtension extension = new AVAPenaltyRestorationExtension(
            governanceKernel,
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            coreDisclosureRegistry,
            challengeExtension,
            revisionExtension
        );
        revisionExtension.bindRevisionWriter(packageId, address(extension));
        governanceKernel.bindPostTransitionHook(packageId, address(revisionExtension));
        _authorisePenaltyExtension();

        uint256 reviewStateId = _createM14ChallengeableReviewState();
        uint256 firstChallengeId = _fileChallenge(reviewStateId, "parity-recursive-finding-first");
        uint256 firstChallengeStateId = challengeExtension.getChallenge(firstChallengeId).challengeRecognisedStateId;
        M14PeerReviewActor secondChallenger = new M14PeerReviewActor();
        bytes32 secondChallengerSubject = keccak256("parity-recursive-finding-second-subject");
        coreIdentityRegistry.assignSubject(
            address(secondChallenger),
            PeerReviewTypes.APP_ID,
            PeerReviewTypes.ROLE_CHALLENGER,
            secondChallengerSubject,
            "ipfs://parity-recursive-finding-second-subject"
        );
        uint256 secondEvidenceId = secondChallenger.registerEvidence(
            coreEvidenceRegistry,
            WORKFLOW,
            packageId,
            PeerReviewTypes.ROLE_CHALLENGER,
            secondChallengerSubject,
            keccak256("parity-recursive-finding-second-evidence"),
            policyId
        );
        uint256 secondChallengeStateId = _createChallengeRecognisedState(
            secondChallenger,
            secondChallengerSubject,
            WORKFLOW,
            packageId,
            firstChallengeStateId,
            secondEvidenceId,
            "parity-recursive-finding-second"
        );
        uint256 recursiveChallengeId = secondChallenger.fileChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeFilingInput({
                appId: PeerReviewTypes.APP_ID,
                workflowKey: WORKFLOW,
                packageId: packageId,
                challengeRecognisedStateId: secondChallengeStateId,
                challengedRecognisedStateId: firstChallengeStateId,
                roleKey: PeerReviewTypes.ROLE_CHALLENGER,
                reasonHash: keccak256("parity-recursive-finding-second"),
                reasonURI: "ipfs://parity-recursive-finding-second"
            })
        );
        editorActorV2.screenChallenge(
            challengeExtension, recursiveChallengeId, PeerReviewTypes.ROLE_EDITOR, M14_EDITOR_SUBJECT
        );
        uint256 resolutionTransitionId = panelActorV2.resolveChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeResolutionInput({
                challengeId: recursiveChallengeId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                outcome: AVAChallengeExtension.ChallengeOutcome.Upheld,
                correctionStatus: AVACoreTypes.RecognisedStateStatus.Downgraded,
                reasonHash: keccak256("parity-recursive-finding-resolution"),
                reasonURI: "ipfs://parity-recursive-finding-resolution"
            })
        );

        uint256 nextPenaltyIdBefore = extension.nextPenaltyId();
        bool accepted;
        try panelActorV2.recordPenalty(
            extension,
            AVAPenaltyRestorationExtension.PenaltyInput({
                challengeTransitionId: resolutionTransitionId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                findingKey: PeerReviewTypes.FINDING_IRRESPONSIBLE_REVIEW,
                reasonHash: keccak256("parity-recursive-cannot-be-review-finding"),
                uri: "ipfs://parity-recursive-cannot-be-review-finding"
            })
        ) returns (
            uint256
        ) {
            accepted = true;
        } catch {}
        require(!accepted, "challenge target accepted reviewer finding");
        require(extension.nextPenaltyId() == nextPenaltyIdBefore, "wrong-object finding wrote penalty");
    }

    function testParityResolvedChallengeCanCreatePenaltyAfterAuthorisedClosure() public {
        AVAStandingRevisionExtension revisionExtension = new AVAStandingRevisionExtension(governanceKernel);
        AVAPenaltyRestorationExtension extension = new AVAPenaltyRestorationExtension(
            governanceKernel,
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            coreDisclosureRegistry,
            challengeExtension,
            revisionExtension
        );
        revisionExtension.bindRevisionWriter(packageId, address(extension));
        _authorisePenaltyExtension();

        uint256 stateId = _createM14ChallengeableReviewState();
        uint256 challengeId = _fileChallenge(stateId, "parity-closed-malicious-challenge");
        editorActorV2.screenChallenge(challengeExtension, challengeId, PeerReviewTypes.ROLE_EDITOR, M14_EDITOR_SUBJECT);
        uint256 resolutionTransitionId = panelActorV2.resolveChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeResolutionInput({
                challengeId: challengeId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                outcome: AVAChallengeExtension.ChallengeOutcome.MaliciousOrFabricated,
                correctionStatus: AVACoreTypes.RecognisedStateStatus.Challengeable,
                reasonHash: keccak256("parity-closed-malicious-resolution"),
                reasonURI: "ipfs://parity-closed-malicious-resolution"
            })
        );
        panelActorV2.closeChallenge(
            challengeExtension,
            challengeId,
            PeerReviewTypes.ROLE_PANEL,
            M14_PANEL_SUBJECT,
            keccak256("parity-closed-malicious-closure"),
            "ipfs://parity-closed-malicious-closure"
        );

        uint256 penaltyId = panelActorV2.recordPenalty(
            extension,
            AVAPenaltyRestorationExtension.PenaltyInput({
                challengeTransitionId: resolutionTransitionId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                findingKey: PeerReviewTypes.FINDING_MALICIOUS_OR_FABRICATED_CHALLENGE,
                reasonHash: keccak256("parity-closed-malicious-penalty"),
                uri: "ipfs://parity-closed-malicious-penalty"
            })
        );
        AVAPenaltyRestorationExtension.PenaltyRecord memory penalty = extension.getPenalty(penaltyId);
        AVAChallengeExtension.ChallengeRecord memory challenge = challengeExtension.getChallenge(challengeId);
        require(penalty.challengeId == challengeId, "closed challenge penalty lost source");
        require(penalty.subjectId == M14_CHALLENGER_SUBJECT, "closed challenge penalty targeted wrong subject");
        require(
            penalty.recognisedStateId == challenge.challengeRecognisedStateId,
            "challenger misconduct penalty bound to target review state"
        );
        require(penalty.packageId == challenge.packageId, "challenger misconduct penalty lost challenge package");
        require(
            penalty.targetPackageId == challenge.targetPackageId,
            "challenger misconduct penalty lost challenged package reference"
        );
    }

    function testChallengerMisconductPenaltySurvivesUnrelatedTargetTransition() public {
        AVAStandingRevisionExtension revisionExtension = new AVAStandingRevisionExtension(governanceKernel);
        AVAPenaltyRestorationExtension extension = new AVAPenaltyRestorationExtension(
            governanceKernel,
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            coreDisclosureRegistry,
            challengeExtension,
            revisionExtension
        );
        revisionExtension.bindRevisionWriter(packageId, address(extension));
        _authorisePenaltyExtension();

        uint256 targetStateId = _createM14ChallengeableReviewState();
        uint256 challengeId = _fileChallenge(targetStateId, "challenger-penalty-after-target-transition");
        editorActorV2.screenChallenge(challengeExtension, challengeId, PeerReviewTypes.ROLE_EDITOR, M14_EDITOR_SUBJECT);
        uint256 resolutionTransitionId = panelActorV2.resolveChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeResolutionInput({
                challengeId: challengeId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                outcome: AVAChallengeExtension.ChallengeOutcome.MaliciousOrFabricated,
                correctionStatus: AVACoreTypes.RecognisedStateStatus.Challengeable,
                reasonHash: keccak256("challenger-penalty-resolution"),
                reasonURI: "ipfs://challenger-penalty-resolution"
            })
        );
        panelActorV2.closeChallenge(
            challengeExtension,
            challengeId,
            PeerReviewTypes.ROLE_PANEL,
            M14_PANEL_SUBJECT,
            keccak256("challenger-penalty-close"),
            "ipfs://challenger-penalty-close"
        );
        panelActorV2.vestState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: targetStateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Vested,
                reasonHash: keccak256("unrelated-target-vesting"),
                reasonURI: "ipfs://unrelated-target-vesting"
            })
        );

        uint256 penaltyId = panelActorV2.recordPenalty(
            extension,
            AVAPenaltyRestorationExtension.PenaltyInput({
                challengeTransitionId: resolutionTransitionId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                findingKey: PeerReviewTypes.FINDING_MALICIOUS_OR_FABRICATED_CHALLENGE,
                reasonHash: keccak256("challenger-penalty-after-target-transition"),
                uri: "ipfs://challenger-penalty-after-target-transition"
            })
        );

        AVAPenaltyRestorationExtension.PenaltyRecord memory penalty = extension.getPenalty(penaltyId);
        require(penalty.subjectId == M14_CHALLENGER_SUBJECT, "penalty targeted review subject");
        require(
            penalty.recognisedStateId == challengeExtension.getChallenge(challengeId).challengeRecognisedStateId,
            "penalty lost challenge-state lineage"
        );
        uint256 standingPenaltyId = panelActorV2.recordStandingPenaltyInput(
            extension,
            AVAPenaltyRestorationExtension.StandingPenaltyInput({
                penaltyId: penaltyId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                dimensionKey: keccak256("challenger-misconduct-procedural-care"),
                delta: -1,
                reasonHash: keccak256("challenger-misconduct-standing-input"),
                uri: "ipfs://challenger-misconduct-standing-input"
            })
        );
        require(
            extension.getStandingPenaltyInput(standingPenaltyId).penaltyId == penaltyId,
            "challenger-misconduct standing lineage was rejected"
        );
    }

    function testParityPenaltyCannotBypassOptionalAntiAbusePolicy() public {
        _activateCapabilityModule(
            AVACapabilityKeys.ANTI_ABUSE,
            IRuleModuleIdentity(address(new M14RejectingAntiAbusePolicyModule(AVACoreTypes.ACTION_RECORD_PENALTY)))
        );
        AVAStandingRevisionExtension revisionExtension = new AVAStandingRevisionExtension(governanceKernel);
        AVAPenaltyRestorationExtension penaltyExtension = new AVAPenaltyRestorationExtension(
            governanceKernel,
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            coreDisclosureRegistry,
            challengeExtension,
            revisionExtension
        );
        uint256 stateId = _createM14ChallengeableReviewState();
        uint256 challengeId = _fileChallenge(stateId, "parity-anti-abuse-penalty");
        editorActorV2.screenChallenge(challengeExtension, challengeId, PeerReviewTypes.ROLE_EDITOR, M14_EDITOR_SUBJECT);
        uint256 resolutionTransitionId = panelActorV2.resolveChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeResolutionInput({
                challengeId: challengeId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                outcome: AVAChallengeExtension.ChallengeOutcome.Upheld,
                correctionStatus: AVACoreTypes.RecognisedStateStatus.Downgraded,
                reasonHash: keccak256("parity-anti-abuse-penalty-resolution"),
                reasonURI: "ipfs://parity-anti-abuse-penalty-resolution"
            })
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_RECORD_PENALTY, true
        );
        bool accepted;
        try panelActorV2.recordPenalty(
            penaltyExtension,
            AVAPenaltyRestorationExtension.PenaltyInput({
                challengeTransitionId: resolutionTransitionId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                findingKey: PeerReviewTypes.FINDING_IRRESPONSIBLE_REVIEW,
                reasonHash: keccak256("parity-anti-abuse-penalty-record"),
                uri: "ipfs://parity-anti-abuse-penalty-record"
            })
        ) returns (
            uint256
        ) {
            accepted = true;
        } catch {}
        require(!accepted, "penalty bypassed anti-abuse policy");
        require(penaltyExtension.nextPenaltyId() == 1, "rejected penalty wrote storage");
    }

    function testParityExternalOperationCancellationCannotBypassApplicationRolePolicy() public {
        uint256 stateId = _createM14ChallengeableReviewState();
        AVACoreTypes.RecognisedStateRecord memory state = governanceKernel.getRecognisedState(stateId);
        M14PeerReviewSettlementSource settlementSource = new M14PeerReviewSettlementSource(
            governanceKernel,
            IAVASettlementReceiptSource.SettlementSourceContext({
                id: 1,
                recognisedStateId: state.id,
                recognisedStateTransitionId: state.lastTransitionId,
                appId: state.appId,
                workflowKey: state.workflowKey,
                packageId: state.packageId,
                subjectId: state.subjectId,
                evidenceId: state.evidenceReceiptId,
                sourceRegistry: address(this),
                sourceTypeKey: keccak256("parity-settlement-source"),
                sourceRecordId: 1,
                settlementKindKey: keccak256("parity-settlement-kind"),
                units: 1,
                referenceHash: keccak256("parity-settlement-reference")
            })
        );
        AVAExternalOperationExtension operationExtension = new AVAExternalOperationExtension(
            governanceKernel,
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            coreDisclosureRegistry,
            new AVAExternalOperationTargetResolver(
                governanceKernel,
                coreEvidenceRegistry,
                challengeExtension,
                IAVADownstreamRecordSource(address(0)),
                IAVADownstreamRecordSource(address(0)),
                settlementSource
            )
        );
        M14PeerReviewActor protocolActor = new M14PeerReviewActor();
        bytes32 protocolSubject = keccak256("parity-external-operation-protocol-subject");
        coreIdentityRegistry.assignSubject(
            address(protocolActor),
            PeerReviewTypes.APP_ID,
            PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
            protocolSubject,
            "ipfs://parity-external-operation-protocol-subject"
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID,
            PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
            AVACoreTypes.ACTION_RECORD_EXTERNAL_OPERATION,
            true
        );
        uint256 operationId = protocolActor.requestExternalOperation(
            operationExtension,
            AVAExternalOperationExtension.OperationInput({
                settlementId: 1,
                roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                authorityId: protocolSubject,
                subjectId: state.subjectId,
                evidenceId: state.evidenceReceiptId,
                operationKey: keccak256("parity-external-operation"),
                payloadHash: keccak256("parity-external-operation-payload"),
                uri: "ipfs://parity-external-operation"
            })
        );
        uint256 challengeId = _fileChallenge(stateId, "parity-external-operation-challenge-target");
        uint256 challengeOperationId = protocolActor.requestTargetExternalOperation(
            operationExtension,
            AVAExternalOperationExtension.TargetOperationInput({
                targetKind: AVAExternalOperationTargetKind.Challenge,
                targetId: challengeId,
                roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                authorityId: protocolSubject,
                operationKey: keccak256("parity-challenge-operation"),
                payloadHash: keccak256("parity-challenge-operation-payload"),
                uri: "ipfs://parity-challenge-operation"
            })
        );
        AVAExternalOperationExtension.OperationReceipt memory challengeOperation =
            operationExtension.getOperation(challengeOperationId);
        require(challengeOperation.targetKind == AVAExternalOperationTargetKind.Challenge, "challenge target missing");
        require(challengeOperation.targetId == challengeId, "challenge target id missing");
        require(challengeOperation.subjectId == M14_CHALLENGER_SUBJECT, "challenge subject missing");
        AVAChallengeExtension.ChallengeRecord memory challenge = challengeExtension.getChallenge(challengeId);
        require(
            challengeOperation.recognisedStateId == challenge.challengeRecognisedStateId,
            "challenge operation bound to target review state"
        );
        require(challengeOperation.packageId == challenge.packageId, "challenge operation lost challenge package");
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID,
            PeerReviewTypes.ROLE_EDITOR,
            AVACoreTypes.ACTION_RECORD_EXTERNAL_OPERATION_OUTCOME,
            true
        );
        bool accepted;
        try editorActorV2.recordExternalOperationOutcome(
            operationExtension,
            operationId,
            AVAExternalOperationExtension.OperationStatus.Cancelled,
            PeerReviewTypes.ROLE_EDITOR,
            M14_EDITOR_SUBJECT,
            keccak256("parity-external-operation-cancelled")
        ) returns (
            uint256
        ) {
            accepted = true;
        } catch {}
        require(!accepted, "external operation cancellation bypassed application role policy");
        require(operationExtension.terminalReceiptIdByOperation(operationId) == 0, "rejected outcome became terminal");
    }

    function testParityAnonymousChallengeProofIsPackageTargetAndNullifierBound() public {
        uint256 stateId = _createM14ChallengeableReviewState();
        AnonymousChallengeFixture memory fixture = _anonymousChallengeFixture(stateId);
        uint256 challengeStateId = _createChallengeRecognisedState(
            fixture.challenger,
            fixture.subjectId,
            CHALLENGE_WORKFLOW,
            fixture.challengePackageId,
            stateId,
            fixture.evidenceId,
            "parity-anonymous-challenge"
        );
        AVAChallengeExtension.ChallengeFilingInput memory filingInput = AVAChallengeExtension.ChallengeFilingInput({
            appId: PeerReviewTypes.APP_ID,
            workflowKey: CHALLENGE_WORKFLOW,
            packageId: fixture.challengePackageId,
            challengeRecognisedStateId: challengeStateId,
            challengedRecognisedStateId: stateId,
            roleKey: PeerReviewTypes.ROLE_CHALLENGER,
            reasonHash: keccak256("parity-anonymous-challenge"),
            reasonURI: "ipfs://parity-anonymous-challenge"
        });
        bool filedWithoutProof;
        try fixture.challenger.fileChallenge(challengeExtension, filingInput) returns (uint256) {
            filedWithoutProof = true;
        } catch {}
        require(!filedWithoutProof, "anonymous challenge filed without proof receipt");

        uint256 proofReceiptId = fixture.challenger
            .registerChallengePrivacyProof(
                fixture.proofExtension,
                AVAPrivacyProofExtension.ChallengeProofInput({
                    packageId: fixture.challengePackageId,
                    recognisedStateId: stateId,
                    roleKey: PeerReviewTypes.ROLE_CHALLENGER,
                    authorityId: fixture.subjectId,
                    evidenceId: fixture.evidenceId,
                    disclosurePolicyId: policyId,
                    proof: fixture.proof,
                    uri: "ipfs://parity-anonymous-challenge-proof"
                })
            );
        uint256 unrelatedEvidenceId = fixture.challenger
            .registerEvidence(
                coreEvidenceRegistry,
                CHALLENGE_WORKFLOW,
                fixture.challengePackageId,
                PeerReviewTypes.ROLE_CHALLENGER,
                fixture.subjectId,
                keccak256("parity-unrelated-anonymous-challenge-evidence"),
                policyId
            );
        uint256 unrelatedChallengeStateId = _createChallengeRecognisedState(
            fixture.challenger,
            fixture.subjectId,
            CHALLENGE_WORKFLOW,
            fixture.challengePackageId,
            stateId,
            unrelatedEvidenceId,
            "parity-unrelated-anonymous-challenge"
        );
        filingInput.challengeRecognisedStateId = unrelatedChallengeStateId;
        bool filedWithUnrelatedEvidence;
        try fixture.challenger.fileChallenge(challengeExtension, filingInput) returns (uint256) {
            filedWithUnrelatedEvidence = true;
        } catch {}
        require(!filedWithUnrelatedEvidence, "challenge proof authorised unrelated evidence");
        filingInput.challengeRecognisedStateId = challengeStateId;
        uint256 challengeId = fixture.challenger.fileChallenge(challengeExtension, filingInput);
        _assertAnonymousChallengeProofUse(fixture, challengeId, proofReceiptId);
    }

    function testPerformanceAnonymousChallengeProofValidatesEachPackageOnce() public {
        uint256 stateId = _createM14ChallengeableReviewState();
        AnonymousChallengeFixture memory fixture = _anonymousChallengeFixture(stateId);
        PERFORMANCE_VM.expectCall(
            address(peerReviewModule), abi.encodeCall(IRuleModuleIdentity.moduleIdentityHash, ()), 2
        );
        fixture.challenger
            .registerChallengePrivacyProof(
                fixture.proofExtension,
                AVAPrivacyProofExtension.ChallengeProofInput({
                    packageId: fixture.challengePackageId,
                    recognisedStateId: stateId,
                    roleKey: PeerReviewTypes.ROLE_CHALLENGER,
                    authorityId: fixture.subjectId,
                    evidenceId: fixture.evidenceId,
                    disclosurePolicyId: policyId,
                    proof: fixture.proof,
                    uri: "ipfs://performance-anonymous-challenge-proof"
                })
            );
    }

    function testPerformanceChallengeProofUseKeepsSourceChecksAndOnePolicyPackageValidation() public {
        uint256 stateId = _createM14ChallengeableReviewState();
        AnonymousChallengeFixture memory fixture = _anonymousChallengeFixture(stateId);
        uint256 challengeStateId = _createChallengeRecognisedState(
            fixture.challenger,
            fixture.subjectId,
            CHALLENGE_WORKFLOW,
            fixture.challengePackageId,
            stateId,
            fixture.evidenceId,
            "performance-challenge-proof-use"
        );
        uint256 proofReceiptId = fixture.challenger
            .registerChallengePrivacyProof(
                fixture.proofExtension,
                AVAPrivacyProofExtension.ChallengeProofInput({
                    packageId: fixture.challengePackageId,
                    recognisedStateId: stateId,
                    roleKey: PeerReviewTypes.ROLE_CHALLENGER,
                    authorityId: fixture.subjectId,
                    evidenceId: fixture.evidenceId,
                    disclosurePolicyId: policyId,
                    proof: fixture.proof,
                    uri: "ipfs://performance-challenge-proof-use-proof"
                })
            );
        uint256 challengeId = fixture.challenger
            .fileChallenge(
                challengeExtension,
                AVAChallengeExtension.ChallengeFilingInput({
                    appId: PeerReviewTypes.APP_ID,
                    workflowKey: CHALLENGE_WORKFLOW,
                    packageId: fixture.challengePackageId,
                    challengeRecognisedStateId: challengeStateId,
                    challengedRecognisedStateId: stateId,
                    roleKey: PeerReviewTypes.ROLE_CHALLENGER,
                    reasonHash: keccak256("performance-challenge-proof-use"),
                    reasonURI: "ipfs://performance-challenge-proof-use"
                })
            );
        AVAChallengeProofUseExtension proofUseExtension = new AVAChallengeProofUseExtension(
            governanceKernel,
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            challengeExtension,
            fixture.proofExtension
        );
        PERFORMANCE_VM.expectCall(
            address(peerReviewModule), abi.encodeCall(IRuleModuleIdentity.moduleIdentityHash, ()), 3
        );
        fixture.challenger
            .recordChallengeProofUse(
                proofUseExtension,
                AVAChallengeProofUseExtension.ProofUseInput({
                    challengeId: challengeId,
                    proofReceiptId: proofReceiptId,
                    roleKey: PeerReviewTypes.ROLE_CHALLENGER,
                    authorityId: fixture.subjectId,
                    reasonHash: keccak256("performance-challenge-proof-use-record"),
                    uri: "ipfs://performance-challenge-proof-use-record"
                })
            );
    }

    function testParityRewardSettlementAndRecoveryLifecycleIsLosslessRecordOnlyAndRevisionTracked() public {
        AVAStandingRevisionExtension revisionExtension = new AVAStandingRevisionExtension(governanceKernel);
        (, AVAAllocationRecordExtension allocationExtension,) = _deployDownstreamExtensions();
        AVARewardPriorityExtension rewardExtension = new AVARewardPriorityExtension(
            governanceKernel,
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            coreDisclosureRegistry,
            IAVADownstreamRecordSource(address(allocationExtension))
        );
        AVAPenaltyRestorationExtension penaltyExtension = new AVAPenaltyRestorationExtension(
            governanceKernel,
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            coreDisclosureRegistry,
            challengeExtension,
            revisionExtension
        );
        AVAValueLifecycleExtension lifecycleExtension = new AVAValueLifecycleExtension(
            governanceKernel,
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            coreDisclosureRegistry,
            rewardExtension,
            penaltyExtension,
            revisionExtension
        );
        revisionExtension.bindRevisionWriter(packageId, address(penaltyExtension));
        revisionExtension.bindRevisionWriter(packageId, address(lifecycleExtension));
        governanceKernel.bindPostTransitionHook(packageId, address(revisionExtension));

        M14PeerReviewActor protocolActor = new M14PeerReviewActor();
        bytes32 protocolSubject = keccak256("parity-value-lifecycle-protocol-subject");
        coreIdentityRegistry.assignSubject(
            address(protocolActor),
            PeerReviewTypes.APP_ID,
            PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
            protocolSubject,
            "ipfs://parity-value-lifecycle-protocol-subject"
        );
        _authoriseValueLifecycle(protocolSubject);

        uint256 stateId = _createM14ChallengeableReviewState();
        panelActorV2.vestState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Vested,
                reasonHash: keccak256("parity-value-lifecycle-vest"),
                reasonURI: "ipfs://parity-value-lifecycle-vest"
            })
        );
        uint256 rewardId;
        uint256 restorableRewardId;
        {
            AVACoreTypes.RecognisedStateRecord memory state = governanceKernel.getRecognisedState(stateId);
            uint256 allocationId = protocolActor.recordAllocation(
                allocationExtension,
                AVAAllocationRecordExtension.AllocationInput({
                    recognisedStateId: stateId,
                    roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                    authorityId: protocolSubject,
                    subjectId: M14_REVIEWER_SUBJECT,
                    evidenceId: state.evidenceReceiptId,
                    allocationKindKey: keccak256("parity-reward-allocation"),
                    units: 6,
                    reasonHash: keccak256("parity-reward-allocation"),
                    uri: "ipfs://parity-reward-allocation"
                })
            );
            rewardId = protocolActor.recordReward(
                rewardExtension,
                AVARewardPriorityExtension.RewardPriorityInput({
                    allocationId: allocationId,
                    roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                    authorityId: protocolSubject,
                    subjectId: M14_REVIEWER_SUBJECT,
                    evidenceId: state.evidenceReceiptId,
                    kindKey: keccak256("parity-reward-grant"),
                    units: 6,
                    reasonHash: keccak256("parity-reward-grant"),
                    uri: "ipfs://parity-reward-grant"
                })
            );
            restorableRewardId = _recordRestorableReward(
                allocationExtension, rewardExtension, protocolActor, protocolSubject, stateId, state.evidenceReceiptId
            );
        }
        {
            uint256 revisionBefore = revisionExtension.currentRevision(packageId, M14_REVIEWER_SUBJECT);
            protocolActor.recordRewardLifecycle(
                lifecycleExtension,
                AVAValueLifecycleExtension.RewardLifecycleInput({
                    rewardId: rewardId,
                    roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                    authorityId: protocolSubject,
                    kind: AVAValueLifecycleExtension.RewardLifecycleKind.Freeze,
                    reasonHash: keccak256("parity-reward-freeze"),
                    uri: "ipfs://parity-reward-freeze"
                })
            );
            require(
                revisionExtension.currentRevision(packageId, M14_REVIEWER_SUBJECT) == revisionBefore + 1,
                "reward freeze did not advance revision"
            );
        }
        {
            uint256 revisionBefore = revisionExtension.currentRevision(packageId, M14_REVIEWER_SUBJECT);
            protocolActor.recordRewardLifecycle(
                lifecycleExtension,
                AVAValueLifecycleExtension.RewardLifecycleInput({
                    rewardId: rewardId,
                    roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                    authorityId: protocolSubject,
                    kind: AVAValueLifecycleExtension.RewardLifecycleKind.Vest,
                    reasonHash: keccak256("parity-reward-lifecycle-vest"),
                    uri: "ipfs://parity-reward-lifecycle-vest"
                })
            );
            require(
                revisionExtension.currentRevision(packageId, M14_REVIEWER_SUBJECT) == revisionBefore + 1,
                "reward vesting did not advance revision"
            );
        }
        uint256 settlementId;
        {
            uint256 revisionBefore = revisionExtension.currentRevision(packageId, M14_REVIEWER_SUBJECT);
            settlementId = protocolActor.recordValueSettlement(
                lifecycleExtension,
                AVAValueLifecycleExtension.ValueSettlementInput({
                    sourceKind: AVAValueLifecycleExtension.ValueSourceKind.Reward,
                    sourceId: rewardId,
                    roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                    authorityId: protocolSubject,
                    settlementKindKey: keccak256("parity-record-only-reward-settlement"),
                    units: 6,
                    referenceHash: keccak256("parity-reward-settlement-reference"),
                    uri: "ipfs://parity-reward-settlement"
                })
            );
            require(
                revisionExtension.currentRevision(packageId, M14_REVIEWER_SUBJECT) == revisionBefore + 1,
                "reward settlement did not advance revision"
            );
        }

        ValueLifecycleScenario memory scenario;
        scenario.protocolActor = protocolActor;
        scenario.protocolSubject = protocolSubject;
        scenario.rewardId = rewardId;
        scenario.restorableRewardId = restorableRewardId;
        scenario.stateId = stateId;
        scenario.settlementId = settlementId;
        _completeParityRecovery(revisionExtension, penaltyExtension, lifecycleExtension, scenario);
    }

    function testRepaymentObligationRejectsPenaltyFromDifferentRecognisedState() public {
        CrossStateRecoveryScenario memory scenario = _crossStateRecoveryScenario();
        uint256 penaltyStateId = _createM14ChallengeableReviewStateUsingEvidence(
            scenario.originStateId, scenario.originEvidenceId, "cross-state-recovery-target"
        );
        uint256 challengeId = _fileChallenge(penaltyStateId, "cross-state-recovery-challenge");
        editorActorV2.screenChallenge(challengeExtension, challengeId, PeerReviewTypes.ROLE_EDITOR, M14_EDITOR_SUBJECT);
        uint256 resolutionTransitionId = panelActorV2.resolveChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeResolutionInput({
                challengeId: challengeId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                outcome: AVAChallengeExtension.ChallengeOutcome.Upheld,
                correctionStatus: AVACoreTypes.RecognisedStateStatus.Downgraded,
                reasonHash: keccak256("cross-state-recovery-resolution"),
                reasonURI: "ipfs://cross-state-recovery-resolution"
            })
        );
        uint256 penaltyId = panelActorV2.recordPenalty(
            scenario.penaltyExtension,
            AVAPenaltyRestorationExtension.PenaltyInput({
                challengeTransitionId: resolutionTransitionId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                findingKey: PeerReviewTypes.FINDING_IRRESPONSIBLE_REVIEW,
                reasonHash: keccak256("cross-state-recovery-penalty"),
                uri: "ipfs://cross-state-recovery-penalty"
            })
        );

        bool accepted;
        try scenario.protocolActor
            .recordRepaymentObligation(
                scenario.lifecycleExtension,
                AVAValueLifecycleExtension.RepaymentObligationInput({
                    originSettlementId: scenario.originSettlementId,
                    penaltyId: penaltyId,
                    roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                    authorityId: scenario.protocolSubject,
                    units: 2,
                    reasonHash: keccak256("cross-state-recovery-obligation"),
                    uri: "ipfs://cross-state-recovery-obligation"
                })
            ) returns (
            uint256
        ) {
            accepted = true;
        } catch {}

        require(!accepted, "repayment obligation combined different recognised states");
    }

    function testRewardContainmentRemainsAvailableAfterEvidenceRevocation() public {
        AVAStandingRevisionExtension revisionExtension = new AVAStandingRevisionExtension(governanceKernel);
        (, AVAAllocationRecordExtension allocationExtension,) = _deployDownstreamExtensions();
        AVARewardPriorityExtension rewardExtension = new AVARewardPriorityExtension(
            governanceKernel,
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            coreDisclosureRegistry,
            IAVADownstreamRecordSource(address(allocationExtension))
        );
        AVAPenaltyRestorationExtension penaltyExtension = new AVAPenaltyRestorationExtension(
            governanceKernel,
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            coreDisclosureRegistry,
            challengeExtension,
            revisionExtension
        );
        AVAValueLifecycleExtension lifecycleExtension = new AVAValueLifecycleExtension(
            governanceKernel,
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            coreDisclosureRegistry,
            rewardExtension,
            penaltyExtension,
            revisionExtension
        );
        revisionExtension.bindRevisionWriter(packageId, address(lifecycleExtension));
        governanceKernel.bindPostTransitionHook(packageId, address(revisionExtension));

        M14PeerReviewActor protocolActor = new M14PeerReviewActor();
        bytes32 protocolSubject = keccak256("containment-protocol-subject");
        coreIdentityRegistry.assignSubject(
            address(protocolActor),
            PeerReviewTypes.APP_ID,
            PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
            protocolSubject,
            "ipfs://containment-protocol-subject"
        );
        _authoriseValueLifecycle(protocolSubject);
        uint256 stateId = _createM14ChallengeableReviewState();
        panelActorV2.vestState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Vested,
                reasonHash: keccak256("containment-state-vest"),
                reasonURI: "ipfs://containment-state-vest"
            })
        );
        uint256 evidenceId = governanceKernel.getRecognisedState(stateId).evidenceReceiptId;
        uint256 frozenRewardId = _recordRestorableReward(
            allocationExtension, rewardExtension, protocolActor, protocolSubject, stateId, evidenceId
        );
        uint256 voidedRewardId = _recordRestorableReward(
            allocationExtension, rewardExtension, protocolActor, protocolSubject, stateId, evidenceId
        );
        panelActorV2.recordEvidenceLifecycle(
            coreEvidenceRegistry,
            evidenceId,
            PeerReviewTypes.ROLE_PANEL,
            M14_PANEL_SUBJECT,
            AVACoreTypes.EvidenceLifecycleKind.Revoke,
            keccak256("containment-evidence-revocation")
        );

        protocolActor.recordRewardLifecycle(
            lifecycleExtension,
            AVAValueLifecycleExtension.RewardLifecycleInput({
                rewardId: frozenRewardId,
                roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                authorityId: protocolSubject,
                kind: AVAValueLifecycleExtension.RewardLifecycleKind.Freeze,
                reasonHash: keccak256("containment-freeze"),
                uri: "ipfs://containment-freeze"
            })
        );
        protocolActor.recordRewardLifecycle(
            lifecycleExtension,
            AVAValueLifecycleExtension.RewardLifecycleInput({
                rewardId: voidedRewardId,
                roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                authorityId: protocolSubject,
                kind: AVAValueLifecycleExtension.RewardLifecycleKind.Void,
                reasonHash: keccak256("containment-void"),
                uri: "ipfs://containment-void"
            })
        );
        try protocolActor.recordRewardLifecycle(
            lifecycleExtension,
            AVAValueLifecycleExtension.RewardLifecycleInput({
                rewardId: frozenRewardId,
                roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                authorityId: protocolSubject,
                kind: AVAValueLifecycleExtension.RewardLifecycleKind.Vest,
                reasonHash: keccak256("containment-vest-rejected"),
                uri: "ipfs://containment-vest-rejected"
            })
        ) {
            revert("revoked evidence allowed reward vesting");
        } catch {}

        require(
            lifecycleExtension.rewardLifecycleStatus(frozenRewardId)
                == AVAValueLifecycleExtension.RewardLifecycleStatus.Frozen,
            "reward was not frozen"
        );
        require(
            lifecycleExtension.rewardLifecycleStatus(voidedRewardId)
                == AVAValueLifecycleExtension.RewardLifecycleStatus.Voided,
            "reward was not voided"
        );
    }

    function testRecordOnlyRecoveryCloseoutSurvivesInactiveHistoricalReferences() public {
        AVAStandingRevisionExtension revisionExtension = new AVAStandingRevisionExtension(governanceKernel);
        (, AVAAllocationRecordExtension allocationExtension,) = _deployDownstreamExtensions();
        AVARewardPriorityExtension rewardExtension = new AVARewardPriorityExtension(
            governanceKernel,
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            coreDisclosureRegistry,
            IAVADownstreamRecordSource(address(allocationExtension))
        );
        AVAPenaltyRestorationExtension penaltyExtension = new AVAPenaltyRestorationExtension(
            governanceKernel,
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            coreDisclosureRegistry,
            challengeExtension,
            revisionExtension
        );
        AVAValueLifecycleExtension lifecycleExtension = new AVAValueLifecycleExtension(
            governanceKernel,
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            coreDisclosureRegistry,
            rewardExtension,
            penaltyExtension,
            revisionExtension
        );
        revisionExtension.bindRevisionWriter(packageId, address(penaltyExtension));
        revisionExtension.bindRevisionWriter(packageId, address(lifecycleExtension));
        governanceKernel.bindPostTransitionHook(packageId, address(revisionExtension));
        _authorisePenaltyExtension();

        M14PeerReviewActor protocolActor = new M14PeerReviewActor();
        bytes32 protocolSubject = keccak256("defensive-closeout-protocol-subject");
        coreIdentityRegistry.assignSubject(
            address(protocolActor),
            PeerReviewTypes.APP_ID,
            PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
            protocolSubject,
            "ipfs://defensive-closeout-protocol-subject"
        );
        _authoriseValueLifecycle(protocolSubject);
        uint256 stateId = _createM14ChallengeableReviewState();
        panelActorV2.vestState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Vested,
                reasonHash: keccak256("defensive-closeout-state-vest"),
                reasonURI: "ipfs://defensive-closeout-state-vest"
            })
        );
        uint256 evidenceId = governanceKernel.getRecognisedState(stateId).evidenceReceiptId;
        uint256 rewardId = _recordRestorableReward(
            allocationExtension, rewardExtension, protocolActor, protocolSubject, stateId, evidenceId
        );
        protocolActor.recordRewardLifecycle(
            lifecycleExtension,
            AVAValueLifecycleExtension.RewardLifecycleInput({
                rewardId: rewardId,
                roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                authorityId: protocolSubject,
                kind: AVAValueLifecycleExtension.RewardLifecycleKind.Vest,
                reasonHash: keccak256("defensive-closeout-reward-vest"),
                uri: "ipfs://defensive-closeout-reward-vest"
            })
        );
        uint256 settlementId = protocolActor.recordValueSettlement(
            lifecycleExtension,
            AVAValueLifecycleExtension.ValueSettlementInput({
                sourceKind: AVAValueLifecycleExtension.ValueSourceKind.Reward,
                sourceId: rewardId,
                roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                authorityId: protocolSubject,
                settlementKindKey: keccak256("defensive-closeout-settlement"),
                units: 2,
                referenceHash: keccak256("defensive-closeout-settlement"),
                uri: "ipfs://defensive-closeout-settlement"
            })
        );

        uint256 challengeId = _fileChallenge(stateId, "defensive-closeout-challenge");
        editorActorV2.screenChallenge(challengeExtension, challengeId, PeerReviewTypes.ROLE_EDITOR, M14_EDITOR_SUBJECT);
        uint256 resolutionTransitionId = panelActorV2.resolveChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeResolutionInput({
                challengeId: challengeId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                outcome: AVAChallengeExtension.ChallengeOutcome.Upheld,
                correctionStatus: AVACoreTypes.RecognisedStateStatus.Downgraded,
                reasonHash: keccak256("defensive-closeout-resolution"),
                reasonURI: "ipfs://defensive-closeout-resolution"
            })
        );
        uint256 penaltyId = panelActorV2.recordPenalty(
            penaltyExtension,
            AVAPenaltyRestorationExtension.PenaltyInput({
                challengeTransitionId: resolutionTransitionId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                findingKey: PeerReviewTypes.FINDING_IRRESPONSIBLE_REVIEW,
                reasonHash: keccak256("defensive-closeout-penalty"),
                uri: "ipfs://defensive-closeout-penalty"
            })
        );
        uint256 obligationId = protocolActor.recordRepaymentObligation(
            lifecycleExtension,
            AVAValueLifecycleExtension.RepaymentObligationInput({
                originSettlementId: settlementId,
                penaltyId: penaltyId,
                roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                authorityId: protocolSubject,
                units: 2,
                reasonHash: keccak256("defensive-closeout-obligation"),
                uri: "ipfs://defensive-closeout-obligation"
            })
        );
        panelActorV2.recordEvidenceLifecycle(
            coreEvidenceRegistry,
            evidenceId,
            PeerReviewTypes.ROLE_PANEL,
            M14_PANEL_SUBJECT,
            AVACoreTypes.EvidenceLifecycleKind.Revoke,
            keccak256("defensive-closeout-evidence-revocation")
        );
        coreIdentityRegistry.deactivateSubject(M14_REVIEWER_SUBJECT);

        AVAValueLifecycleExtension.RecoveryOutcomeInput memory clawbackInput =
            AVAValueLifecycleExtension.RecoveryOutcomeInput({
                obligationId: obligationId,
                roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                authorityId: protocolSubject,
                outcome: AVAValueLifecycleExtension.RecoveryOutcome.Clawback,
                referenceHash: keccak256("defensive-closeout-clawback"),
                uri: "ipfs://defensive-closeout-clawback"
            });
        try protocolActor.recordRecoveryOutcome(lifecycleExtension, clawbackInput) {
            revert("inactive references allowed effectful clawback");
        } catch {}
        uint256 outcomeId = protocolActor.recordRecoveryOutcome(
            lifecycleExtension,
            AVAValueLifecycleExtension.RecoveryOutcomeInput({
                obligationId: obligationId,
                roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                authorityId: protocolSubject,
                outcome: AVAValueLifecycleExtension.RecoveryOutcome.Waiver,
                referenceHash: keccak256("defensive-closeout-waiver"),
                uri: "ipfs://defensive-closeout-waiver"
            })
        );

        require(
            lifecycleExtension.getRecoveryOutcome(outcomeId).outcome
                == AVAValueLifecycleExtension.RecoveryOutcome.Waiver,
            "record-only closeout missing"
        );
        require(lifecycleExtension.recoveryOutcomeIdByObligation(obligationId) == outcomeId, "terminal not recorded");
    }

    function _recordRestorableReward(
        AVAAllocationRecordExtension allocationExtension,
        AVARewardPriorityExtension rewardExtension,
        M14PeerReviewActor protocolActor,
        bytes32 protocolSubject,
        uint256 stateId,
        uint256 evidenceId
    ) private returns (uint256 rewardId) {
        uint256 allocationId = protocolActor.recordAllocation(
            allocationExtension,
            AVAAllocationRecordExtension.AllocationInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                authorityId: protocolSubject,
                subjectId: M14_REVIEWER_SUBJECT,
                evidenceId: evidenceId,
                allocationKindKey: keccak256("parity-restorable-reward-allocation"),
                units: 2,
                reasonHash: keccak256("parity-restorable-reward-allocation"),
                uri: "ipfs://parity-restorable-reward-allocation"
            })
        );
        rewardId = protocolActor.recordReward(
            rewardExtension,
            AVARewardPriorityExtension.RewardPriorityInput({
                allocationId: allocationId,
                roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                authorityId: protocolSubject,
                subjectId: M14_REVIEWER_SUBJECT,
                evidenceId: evidenceId,
                kindKey: keccak256("parity-restorable-reward-grant"),
                units: 2,
                reasonHash: keccak256("parity-restorable-reward-grant"),
                uri: "ipfs://parity-restorable-reward-grant"
            })
        );
    }

    function _crossStateRecoveryScenario() private returns (CrossStateRecoveryScenario memory scenario) {
        AVAStandingRevisionExtension revisionExtension = new AVAStandingRevisionExtension(governanceKernel);
        (, AVAAllocationRecordExtension allocationExtension,) = _deployDownstreamExtensions();
        AVARewardPriorityExtension rewardExtension = new AVARewardPriorityExtension(
            governanceKernel,
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            coreDisclosureRegistry,
            IAVADownstreamRecordSource(address(allocationExtension))
        );
        scenario.penaltyExtension = new AVAPenaltyRestorationExtension(
            governanceKernel,
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            coreDisclosureRegistry,
            challengeExtension,
            revisionExtension
        );
        scenario.lifecycleExtension = new AVAValueLifecycleExtension(
            governanceKernel,
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            coreDisclosureRegistry,
            rewardExtension,
            scenario.penaltyExtension,
            revisionExtension
        );
        revisionExtension.bindRevisionWriter(packageId, address(scenario.penaltyExtension));
        revisionExtension.bindRevisionWriter(packageId, address(scenario.lifecycleExtension));
        governanceKernel.bindPostTransitionHook(packageId, address(revisionExtension));
        _authorisePenaltyExtension();

        scenario.protocolActor = new M14PeerReviewActor();
        scenario.protocolSubject = keccak256("cross-state-recovery-protocol-subject");
        coreIdentityRegistry.assignSubject(
            address(scenario.protocolActor),
            PeerReviewTypes.APP_ID,
            PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
            scenario.protocolSubject,
            "ipfs://cross-state-recovery-protocol-subject"
        );
        _authoriseValueLifecycle(scenario.protocolSubject);
        scenario.originStateId = _createM14ChallengeableReviewState();
        panelActorV2.vestState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: scenario.originStateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Vested,
                reasonHash: keccak256("cross-state-recovery-origin-vest"),
                reasonURI: "ipfs://cross-state-recovery-origin-vest"
            })
        );
        scenario.originEvidenceId = governanceKernel.getRecognisedState(scenario.originStateId).evidenceReceiptId;
        uint256 rewardId = _recordRestorableReward(
            allocationExtension,
            rewardExtension,
            scenario.protocolActor,
            scenario.protocolSubject,
            scenario.originStateId,
            scenario.originEvidenceId
        );
        scenario.protocolActor
            .recordRewardLifecycle(
                scenario.lifecycleExtension,
                AVAValueLifecycleExtension.RewardLifecycleInput({
                    rewardId: rewardId,
                    roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                    authorityId: scenario.protocolSubject,
                    kind: AVAValueLifecycleExtension.RewardLifecycleKind.Vest,
                    reasonHash: keccak256("cross-state-recovery-reward-vest"),
                    uri: "ipfs://cross-state-recovery-reward-vest"
                })
            );
        scenario.originSettlementId = scenario.protocolActor
            .recordValueSettlement(
                scenario.lifecycleExtension,
                AVAValueLifecycleExtension.ValueSettlementInput({
                    sourceKind: AVAValueLifecycleExtension.ValueSourceKind.Reward,
                    sourceId: rewardId,
                    roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                    authorityId: scenario.protocolSubject,
                    settlementKindKey: keccak256("cross-state-recovery-origin-settlement"),
                    units: 2,
                    referenceHash: keccak256("cross-state-recovery-origin-settlement"),
                    uri: "ipfs://cross-state-recovery-origin-settlement"
                })
            );
    }

    function _createM14ChallengeableReviewStateUsingEvidence(
        uint256 sourceStateId,
        uint256 evidenceId,
        string memory seed
    ) private returns (uint256 stateId) {
        AVACoreTypes.RecognisedStateRecord memory sourceState = governanceKernel.getRecognisedState(sourceStateId);
        AVACoreTypes.GovernedObjectRecord memory sourceObject =
            governanceKernel.getGovernedObject(sourceState.governedObjectId);
        uint256 reviewObjectId = reviewerActorV2.registerObject(
            governanceKernel,
            _objectInput(
                PeerReviewTypes.ROLE_REVIEWER,
                PeerReviewTypes.OBJECT_REVIEW_CONTRIBUTION,
                keccak256(bytes(seed)),
                sourceObject.parentObjectId,
                M14_REVIEWER_SUBJECT,
                evidenceId
            )
        );
        stateId = editorActorV2.formState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateFormationInput({
                governedObjectId: reviewObjectId,
                roleKey: PeerReviewTypes.ROLE_EDITOR,
                authorityId: M14_EDITOR_SUBJECT,
                stage: AVACoreTypes.Stage.Verification,
                status: AVACoreTypes.RecognisedStateStatus.Provisional,
                reasonHash: keccak256(abi.encode(seed, "provisional")),
                reasonURI: "ipfs://cross-state-recovery-provisional"
            })
        );
        editorActorV2.transitionState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_EDITOR,
                authorityId: M14_EDITOR_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Challengeable,
                reasonHash: keccak256(abi.encode(seed, "challengeable")),
                reasonURI: "ipfs://cross-state-recovery-challengeable"
            })
        );
    }

    function _completeParityRecovery(
        AVAStandingRevisionExtension revisionExtension,
        AVAPenaltyRestorationExtension penaltyExtension,
        AVAValueLifecycleExtension lifecycleExtension,
        ValueLifecycleScenario memory scenario
    ) private {
        uint256 challengeId = _fileChallenge(scenario.stateId, "parity-recovery-challenge");
        editorActorV2.screenChallenge(challengeExtension, challengeId, PeerReviewTypes.ROLE_EDITOR, M14_EDITOR_SUBJECT);
        uint256 resolutionTransitionId = panelActorV2.resolveChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeResolutionInput({
                challengeId: challengeId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                outcome: AVAChallengeExtension.ChallengeOutcome.Upheld,
                correctionStatus: AVACoreTypes.RecognisedStateStatus.Downgraded,
                reasonHash: keccak256("parity-recovery-resolution"),
                reasonURI: "ipfs://parity-recovery-resolution"
            })
        );
        scenario.protocolActor
            .recordRewardLifecycle(
                lifecycleExtension,
                AVAValueLifecycleExtension.RewardLifecycleInput({
                    rewardId: scenario.rewardId,
                    roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                    authorityId: scenario.protocolSubject,
                    kind: AVAValueLifecycleExtension.RewardLifecycleKind.Void,
                    reasonHash: keccak256("parity-post-correction-reward-void"),
                    uri: "ipfs://parity-post-correction-reward-void"
                })
            );
        require(
            lifecycleExtension.rewardLifecycleStatus(scenario.rewardId)
                == AVAValueLifecycleExtension.RewardLifecycleStatus.Voided,
            "post-correction reward was not voided"
        );
        scenario.protocolActor
            .recordRewardLifecycle(
                lifecycleExtension,
                AVAValueLifecycleExtension.RewardLifecycleInput({
                    rewardId: scenario.restorableRewardId,
                    roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                    authorityId: scenario.protocolSubject,
                    kind: AVAValueLifecycleExtension.RewardLifecycleKind.Void,
                    reasonHash: keccak256("parity-unsettled-reward-void"),
                    uri: "ipfs://parity-unsettled-reward-void"
                })
            );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_RECORD_PENALTY, true
        );
        uint256 penaltyId = panelActorV2.recordPenalty(
            penaltyExtension,
            AVAPenaltyRestorationExtension.PenaltyInput({
                challengeTransitionId: resolutionTransitionId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                findingKey: PeerReviewTypes.FINDING_IRRESPONSIBLE_REVIEW,
                reasonHash: keccak256("parity-recovery-penalty"),
                uri: "ipfs://parity-recovery-penalty"
            })
        );
        uint256 revisionBeforeObligation = revisionExtension.currentRevision(packageId, M14_REVIEWER_SUBJECT);
        uint256 obligationId = scenario.protocolActor
            .recordRepaymentObligation(
                lifecycleExtension,
                AVAValueLifecycleExtension.RepaymentObligationInput({
                    originSettlementId: scenario.settlementId,
                    penaltyId: penaltyId,
                    roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                    authorityId: scenario.protocolSubject,
                    units: 6,
                    reasonHash: keccak256("parity-repayment-obligation"),
                    uri: "ipfs://parity-repayment-obligation"
                })
            );
        require(
            revisionExtension.currentRevision(packageId, M14_REVIEWER_SUBJECT) == revisionBeforeObligation + 1,
            "repayment obligation did not advance revision"
        );
        uint256 revisionBeforeRecovery = revisionExtension.currentRevision(packageId, M14_REVIEWER_SUBJECT);
        uint256 outcomeId = scenario.protocolActor
            .recordRecoveryOutcome(
                lifecycleExtension,
                AVAValueLifecycleExtension.RecoveryOutcomeInput({
                    obligationId: obligationId,
                    roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                    authorityId: scenario.protocolSubject,
                    outcome: AVAValueLifecycleExtension.RecoveryOutcome.Waiver,
                    referenceHash: keccak256("parity-recovery-waiver"),
                    uri: "ipfs://parity-recovery-waiver"
                })
            );
        require(lifecycleExtension.getRecoveryOutcome(outcomeId).obligationId == obligationId, "outcome unbound");
        require(
            revisionExtension.currentRevision(packageId, M14_REVIEWER_SUBJECT) == revisionBeforeRecovery + 1,
            "recovery outcome did not advance revision"
        );
        panelActorV2.makeRestorationAvailable(
            challengeExtension,
            challengeId,
            PeerReviewTypes.ROLE_PANEL,
            M14_PANEL_SUBJECT,
            keccak256("parity-reward-restoration-available"),
            "ipfs://parity-reward-restoration-available"
        );
        panelActorV2.restoreChallenge(
            challengeExtension,
            challengeId,
            PeerReviewTypes.ROLE_PANEL,
            M14_PANEL_SUBJECT,
            keccak256("parity-reward-restoration"),
            "ipfs://parity-reward-restoration"
        );
        scenario.protocolActor
            .recordRewardLifecycle(
                lifecycleExtension,
                AVAValueLifecycleExtension.RewardLifecycleInput({
                    rewardId: scenario.restorableRewardId,
                    roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                    authorityId: scenario.protocolSubject,
                    kind: AVAValueLifecycleExtension.RewardLifecycleKind.Restore,
                    reasonHash: keccak256("parity-unsettled-reward-restore"),
                    uri: "ipfs://parity-unsettled-reward-restore"
                })
            );
        uint256 restoredSettlementId = scenario.protocolActor
            .recordValueSettlement(
                lifecycleExtension,
                AVAValueLifecycleExtension.ValueSettlementInput({
                    sourceKind: AVAValueLifecycleExtension.ValueSourceKind.Reward,
                    sourceId: scenario.restorableRewardId,
                    roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                    authorityId: scenario.protocolSubject,
                    settlementKindKey: keccak256("parity-restored-reward-settlement"),
                    units: 2,
                    referenceHash: keccak256("parity-restored-reward-settlement"),
                    uri: "ipfs://parity-restored-reward-settlement"
                })
            );
        require(
            lifecycleExtension.getValueSettlement(restoredSettlementId).sourceId == scenario.restorableRewardId,
            "restored reward settlement lost source"
        );
        AVAValueLifecycleExtension.RecoveryOutcomeInput memory duplicate =
            AVAValueLifecycleExtension.RecoveryOutcomeInput({
                obligationId: obligationId,
                roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                authorityId: scenario.protocolSubject,
                outcome: AVAValueLifecycleExtension.RecoveryOutcome.Satisfaction,
                referenceHash: keccak256("parity-duplicate-recovery"),
                uri: "ipfs://parity-duplicate-recovery"
            });
        try scenario.protocolActor.recordRecoveryOutcome(lifecycleExtension, duplicate) {
            revert("duplicate recovery terminal accepted");
        } catch {}
    }

    function _authoriseValueLifecycle(bytes32) private {
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR, AVACoreTypes.ACTION_RECORD_ALLOCATION, true
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR, AVACoreTypes.ACTION_RECORD_REWARD, true
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID,
            PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
            AVACoreTypes.ACTION_RECORD_REWARD_LIFECYCLE,
            true
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID,
            PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
            AVACoreTypes.ACTION_RECORD_VALUE_SETTLEMENT,
            true
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID,
            PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
            AVACoreTypes.ACTION_RECORD_REPAYMENT_OBLIGATION,
            true
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID,
            PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
            AVACoreTypes.ACTION_RECORD_RECOVERY_OUTCOME,
            true
        );
    }

    function _deployDownstreamExtensions()
        internal
        returns (
            AVAStandingRecordExtension standingExtension,
            AVAAllocationRecordExtension allocationExtension,
            AVAConsequenceRecordExtension consequenceExtension
        )
    {
        standingExtension = new AVAStandingRecordExtension(
            governanceKernel,
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            IAVAStandingRevision(address(0))
        );
        allocationExtension = new AVAAllocationRecordExtension(
            governanceKernel, coreAuthorityMatrix, coreIdentityRegistry, corePackageRegistry, coreEvidenceRegistry
        );
        consequenceExtension = new AVAConsequenceRecordExtension(
            governanceKernel, coreAuthorityMatrix, coreIdentityRegistry, corePackageRegistry, coreEvidenceRegistry
        );
    }

    function _deployDisclosureReceiptExtension() internal returns (AVADisclosureReceiptExtension extension) {
        AVAPrivacyProofExtension proofExtension = new AVAPrivacyProofExtension(
            governanceKernel,
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            coreDisclosureRegistry,
            new M14PeerReviewAlwaysValidVerifier()
        );
        extension = new AVADisclosureReceiptExtension(
            governanceKernel,
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            coreDisclosureRegistry,
            proofExtension
        );
    }

    function _supersedePackage(string memory uri) internal returns (uint256 replacementPackageId) {
        replacementPackageId = corePackageRegistry.supersedeRulePackage(
            _corePackageInput(
                PeerReviewTypes.APP_ID, WORKFLOW, PACKAGE_ROLE, PACKAGE_SUBJECT, 2, PACKAGE_COMPATIBILITY, uri
            ),
            packageId,
            _peerReviewBindings(peerReviewModule)
        );
    }

    function _activateRejectingCapability(bytes32 capabilityKey) internal {
        _activateCapabilityModule(capabilityKey, IRuleModuleIdentity(address(new M14RejectingCoreRuleModule())));
    }

    function _activateCapabilityModule(bytes32 capabilityKey, IRuleModuleIdentity module) internal {
        AVACoreRulePackageRegistry.ModuleBinding[] memory bindings = _peerReviewBindings(peerReviewModule);
        AVACoreRulePackageRegistry.RulePackage memory previousPackage =
            corePackageRegistry.getRulePackageById(packageId);
        _replaceCapability(bindings, capabilityKey, module);
        packageId = corePackageRegistry.supersedeRulePackage(
            _corePackageInput(
                PeerReviewTypes.APP_ID,
                WORKFLOW,
                PACKAGE_ROLE,
                PACKAGE_SUBJECT,
                previousPackage.version + 1,
                PACKAGE_COMPATIBILITY,
                "ipfs://m145-rejecting-capability-package"
            ),
            packageId,
            bindings
        );
        governanceKernel.bindSourceBoundTransitionRequester(packageId, address(challengeExtension));
        governanceKernel.bindTransitionGuard(packageId, address(challengeExtension));
    }

    function _replaceCapability(
        AVACoreRulePackageRegistry.ModuleBinding[] memory bindings,
        bytes32 capabilityKey,
        IRuleModuleIdentity module
    ) internal pure {
        for (uint256 i; i < bindings.length; ++i) {
            if (bindings[i].capabilityKey == capabilityKey) {
                bindings[i].module = module;
                return;
            }
        }
        revert("unknown capability test key");
    }

    function _registerIndependentChallengePackage(AVACoreRulePackageRegistry.ModuleBinding[] memory bindings)
        internal
        returns (uint256 challengePackageId)
    {
        challengePackageId = corePackageRegistry.registerRulePackage(
            _corePackageInput(
                PeerReviewTypes.APP_ID,
                CHALLENGE_WORKFLOW,
                PACKAGE_ROLE,
                PACKAGE_SUBJECT,
                1,
                PACKAGE_COMPATIBILITY,
                "ipfs://m145-independent-challenge-package"
            ),
            bindings
        );
        governanceKernel.bindSourceBoundTransitionRequester(challengePackageId, address(challengeExtension));
        governanceKernel.bindTransitionGuard(challengePackageId, address(challengeExtension));
    }

    function _peerReviewBindings(IAVAApplicationModule applicationModule)
        internal
        returns (AVACoreRulePackageRegistry.ModuleBinding[] memory bindings)
    {
        AVACoreRulePackageRegistry.ModuleBinding[] memory coreBindings = _coreBindings(applicationModule);
        bindings = new AVACoreRulePackageRegistry.ModuleBinding[](coreBindings.length + 9);
        IRuleModuleIdentity penaltyPolicy = IRuleModuleIdentity(address(new PeerReviewPenaltyPolicyModule()));
        address defaultCorePolicy = address(coreBindings[1].module);
        address defaultExtensionPolicy = address(coreBindings[12].module);
        for (uint256 i; i < coreBindings.length; ++i) {
            bindings[i] = coreBindings[i];
            if (bindings[i].capabilityKey == AVACapabilityKeys.PENALTY) bindings[i].module = penaltyPolicy;
        }
        bindings[coreBindings.length] = _coreBinding(AVACapabilityKeys.AUDIT_RECEIPT, defaultExtensionPolicy);
        bindings[coreBindings.length + 1] = _coreBinding(AVACapabilityKeys.FIELD_POLICY, defaultCorePolicy);
        bindings[coreBindings.length + 2] = _coreBinding(AVACapabilityKeys.ANTI_ABUSE, defaultCorePolicy);
        bindings[coreBindings.length + 3] = _coreBinding(AVACapabilityKeys.STANDING_PROVENANCE, defaultExtensionPolicy);
        bindings[coreBindings.length + 4] = _coreBinding(AVACapabilityKeys.STANDING_ZK_PROOF, defaultExtensionPolicy);
        bindings[coreBindings.length + 5] =
            _coreBinding(AVACapabilityKeys.STANDING_ZK_CREDENTIAL, defaultExtensionPolicy);
        bindings[coreBindings.length + 6] = _coreBinding(AVACapabilityKeys.EXTERNAL_OPERATION, defaultExtensionPolicy);
        bindings[coreBindings.length + 7] = _coreBinding(AVACapabilityKeys.PRIVACY_PROOF, defaultExtensionPolicy);
        bindings[coreBindings.length + 8] = _coreBinding(AVACapabilityKeys.DISCLOSURE_RECEIPT, defaultExtensionPolicy);
    }

    function _challengeProofBindings(
        PeerReviewAnonymousChallengeProofPolicyModule disclosureModule,
        PeerReviewZKProofReceiptPolicyModule proofPolicyModule
    ) private returns (AVACoreRulePackageRegistry.ModuleBinding[] memory bindings) {
        bindings = _peerReviewBindings(peerReviewModule);
        _replaceCapability(
            bindings, AVACapabilityKeys.DISCLOSURE_POLICY, IRuleModuleIdentity(address(disclosureModule))
        );
        _replaceCapability(bindings, AVACapabilityKeys.PRIVACY_PROOF, IRuleModuleIdentity(address(proofPolicyModule)));
    }

    function _assertEvidenceCapabilityRejects(bytes32 capabilityKey) internal {
        _activateRejectingCapability(capabilityKey);
        uint256 nextEvidenceIdBefore = coreEvidenceRegistry.nextEvidenceId();
        try authorActor.registerEvidence(
            coreEvidenceRegistry,
            WORKFLOW,
            packageId,
            PeerReviewTypes.ROLE_AUTHOR,
            M14_AUTHOR_SUBJECT,
            keccak256(abi.encode(capabilityKey, "m145-rejected-evidence")),
            policyId
        ) {
            revert("rejecting evidence-path module allowed receipt");
        } catch {}
        require(coreEvidenceRegistry.nextEvidenceId() == nextEvidenceIdBefore, "rejected evidence changed storage");
    }

    function _assertDownstreamCapabilityRejects(bytes32 capabilityKey) internal {
        _activateRejectingCapability(capabilityKey);
        uint256 stateId = _createM14ChallengeableReviewState();
        panelActorV2.vestState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Vested,
                reasonHash: keccak256("m145-reject-downstream-vest"),
                reasonURI: "ipfs://m145-reject-downstream-vest"
            })
        );
        (
            AVAStandingRecordExtension standingExtension,
            AVAAllocationRecordExtension allocationExtension,
            AVAConsequenceRecordExtension consequenceExtension
        ) = _deployDownstreamExtensions();
        _authoriseDownstreamExtensions();
        uint256 evidenceId = governanceKernel.getRecognisedState(stateId).evidenceReceiptId;
        if (capabilityKey == AVACapabilityKeys.STANDING) {
            uint256 nextStandingIdBefore = standingExtension.nextStandingUpdateId();
            try panelActorV2.recordStanding(
                standingExtension,
                AVAStandingRecordExtension.StandingInput({
                    recognisedStateId: stateId,
                    roleKey: PeerReviewTypes.ROLE_PANEL,
                    authorityId: M14_PANEL_SUBJECT,
                    subjectId: M14_REVIEWER_SUBJECT,
                    evidenceId: evidenceId,
                    dimensionKey: keccak256("m145-reject-standing"),
                    delta: 1,
                    reasonHash: keccak256("m145-reject-standing"),
                    uri: "ipfs://m145-reject-standing"
                })
            ) {
                revert("rejecting standing module allowed record");
            } catch {}
            require(
                standingExtension.nextStandingUpdateId() == nextStandingIdBefore, "rejected standing changed storage"
            );
            return;
        }
        if (capabilityKey == AVACapabilityKeys.ALLOCATION) {
            bytes32 executorSubject = keccak256("m145-reject-allocation-executor");
            M14PeerReviewActor executorActor = new M14PeerReviewActor();
            coreIdentityRegistry.assignSubject(
                address(executorActor),
                PeerReviewTypes.APP_ID,
                PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                executorSubject,
                "ipfs://m145-reject-allocation-executor"
            );
            uint256 nextAllocationIdBefore = allocationExtension.nextAllocationId();
            try executorActor.recordAllocation(
                allocationExtension,
                AVAAllocationRecordExtension.AllocationInput({
                    recognisedStateId: stateId,
                    roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                    authorityId: executorSubject,
                    subjectId: M14_REVIEWER_SUBJECT,
                    evidenceId: evidenceId,
                    allocationKindKey: keccak256("m145-reject-allocation"),
                    units: 1,
                    reasonHash: keccak256("m145-reject-allocation"),
                    uri: "ipfs://m145-reject-allocation"
                })
            ) {
                revert("rejecting allocation module allowed record");
            } catch {}
            require(
                allocationExtension.nextAllocationId() == nextAllocationIdBefore, "rejected allocation changed storage"
            );
            return;
        }
        uint256 nextConsequenceIdBefore = consequenceExtension.nextConsequenceId();
        try panelActorV2.recordConsequence(
            consequenceExtension,
            AVAConsequenceRecordExtension.ConsequenceInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                subjectId: M14_REVIEWER_SUBJECT,
                evidenceId: evidenceId,
                consequenceKindKey: keccak256("m145-reject-consequence"),
                reasonHash: keccak256("m145-reject-consequence"),
                uri: "ipfs://m145-reject-consequence"
            })
        ) {
            revert("rejecting consequence module allowed record");
        } catch {}
        require(
            consequenceExtension.nextConsequenceId() == nextConsequenceIdBefore, "rejected consequence changed storage"
        );
    }

    function _registerChallengeEvidence(string memory seed) internal returns (uint256) {
        return challengerActorV2.registerEvidence(
            coreEvidenceRegistry,
            WORKFLOW,
            packageId,
            PeerReviewTypes.ROLE_CHALLENGER,
            M14_CHALLENGER_SUBJECT,
            keccak256(bytes(seed)),
            policyId
        );
    }

    function _challengeInput(uint256 stateId, uint256 challengeStateId, string memory seed)
        internal
        view
        returns (AVAChallengeExtension.ChallengeFilingInput memory)
    {
        return AVAChallengeExtension.ChallengeFilingInput({
            appId: PeerReviewTypes.APP_ID,
            workflowKey: WORKFLOW,
            packageId: packageId,
            challengeRecognisedStateId: challengeStateId,
            challengedRecognisedStateId: stateId,
            roleKey: PeerReviewTypes.ROLE_CHALLENGER,
            reasonHash: keccak256(bytes(seed)),
            reasonURI: "ipfs://m145-rejecting-challenge"
        });
    }

    function _createChallengeRecognisedState(
        M14PeerReviewActor challenger,
        bytes32 challengerSubjectId,
        bytes32 workflowKey,
        uint256 challengePackageId,
        uint256 targetStateId,
        uint256 evidenceId,
        string memory seed
    ) internal returns (uint256 challengeStateId) {
        AVACoreTypes.RecognisedStateRecord memory target = governanceKernel.getRecognisedState(targetStateId);
        uint256 challengeObjectId = challenger.registerObject(
            governanceKernel,
            AVAGovernanceKernel.GovernedObjectInput({
                appId: PeerReviewTypes.APP_ID,
                workflowKey: workflowKey,
                packageId: challengePackageId,
                roleKey: PeerReviewTypes.ROLE_CHALLENGER,
                objectTypeKey: PeerReviewTypes.OBJECT_CHALLENGE,
                objectCommitment: keccak256(abi.encode("canonical-challenge-object", targetStateId, evidenceId, seed)),
                parentObjectId: target.governedObjectId,
                subjectId: challengerSubjectId,
                evidenceReceiptId: evidenceId,
                disclosurePolicyId: policyId,
                metadataHash: keccak256(abi.encode("canonical-challenge-metadata", seed)),
                authorityId: challengerSubjectId,
                uri: "ipfs://canonical-challenge-object"
            })
        );
        challengeStateId = challenger.formState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateFormationInput({
                governedObjectId: challengeObjectId,
                roleKey: PeerReviewTypes.ROLE_CHALLENGER,
                authorityId: challengerSubjectId,
                stage: AVACoreTypes.Stage.Verification,
                status: AVACoreTypes.RecognisedStateStatus.Registered,
                reasonHash: keccak256(abi.encode("canonical-challenge-formation", seed)),
                reasonURI: "ipfs://canonical-challenge-formation"
            })
        );
    }

    function _authoriseDownstreamExtensions() internal {
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_RECORD_STANDING_UPDATE, true
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_RECORD_CONSEQUENCE, true
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR, AVACoreTypes.ACTION_RECORD_ALLOCATION, true
        );
    }

    function _standingComputationInput(uint256 stateId, bytes32 roleKey, bytes32 authorityId)
        internal
        view
        returns (AVAStandingComputationExtension.ComputationInput memory input)
    {
        input = AVAStandingComputationExtension.ComputationInput({
            recognisedStateId: stateId,
            roleKey: roleKey,
            authorityId: authorityId,
            subjectId: M14_REVIEWER_SUBJECT,
            evidenceId: governanceKernel.getRecognisedState(stateId).evidenceReceiptId,
            vectorKey: keccak256("parity-standing-vector"),
            categoryHash: keccak256("parity-standing-category"),
            lowerBound: 1,
            upperBound: 100,
            thresholdSetHash: keccak256("parity-standing-thresholds"),
            computationRuleHash: keccak256("parity-standing-rule"),
            sourceSetCommitment: keccak256("parity-standing-sources"),
            outputCommitment: keccak256("parity-standing-output"),
            epoch: 1,
            uri: "ipfs://parity-standing-computation"
        });
    }

    function _standingCredentialFixture()
        internal
        returns (AVAStandingCredentialExtension credentialExtension, uint256 computationId)
    {
        AVAStandingRevisionExtension revisionExtension = new AVAStandingRevisionExtension(governanceKernel);
        governanceKernel.bindPostTransitionHook(packageId, address(revisionExtension));
        uint256 stateId = _createM14ChallengeableReviewState();
        panelActorV2.vestState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Vested,
                reasonHash: keccak256("parity-standing-credential-vest"),
                reasonURI: "ipfs://parity-standing-credential-vest"
            })
        );
        AVAStandingComputationExtension computationExtension = new AVAStandingComputationExtension(
            governanceKernel,
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            revisionExtension
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_RECORD_STANDING_COMPUTATION, true
        );
        computationId = panelActorV2.recordStandingComputation(
            computationExtension, _standingComputationInput(stateId, PeerReviewTypes.ROLE_PANEL, M14_PANEL_SUBJECT)
        );
        credentialExtension = new AVAStandingCredentialExtension(
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            revisionExtension,
            computationExtension
        );
    }

    function _standingZKFixture() internal returns (StandingZKFixture memory fixture) {
        AVAStandingRevisionExtension revisionExtension = new AVAStandingRevisionExtension(governanceKernel);
        governanceKernel.bindPostTransitionHook(packageId, address(revisionExtension));
        uint256 stateId = _createM14ChallengeableReviewState();
        panelActorV2.vestState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Vested,
                reasonHash: keccak256("parity-standing-zk-vest"),
                reasonURI: "ipfs://parity-standing-zk-vest"
            })
        );
        _authoriseStandingProvenance();
        M14PeerReviewAlwaysValidVerifier verifier = new M14PeerReviewAlwaysValidVerifier();
        AVAStandingProvenanceExtension provenanceExtension = new AVAStandingProvenanceExtension(
            governanceKernel,
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            coreDisclosureRegistry,
            revisionExtension
        );
        fixture.proofExtension = new AVAStandingZKProofExtension(
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            revisionExtension,
            provenanceExtension,
            verifier
        );
        fixture.credentialExtension = new AVAStandingZKCredentialExtension(
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            revisionExtension,
            provenanceExtension,
            fixture.proofExtension,
            verifier
        );
        fixture.proof = IZKProofVerifier.SchnorrProof({
            publicKey: IZKProofVerifier.G1Point({x: 1, y: 2}),
            commitment: IZKProofVerifier.G1Point({x: 3, y: 4}),
            response: 5
        });
        fixture.statementId = _recordStandingZKStatement(
            provenanceExtension,
            verifier,
            stateId,
            keccak256(abi.encode(fixture.proof.publicKey.x, fixture.proof.publicKey.y))
        );
    }

    function _anonymousChallengeFixture(uint256) internal returns (AnonymousChallengeFixture memory fixture) {
        M14PeerReviewAlwaysValidVerifier verifier = new M14PeerReviewAlwaysValidVerifier();
        fixture.proofExtension = new AVAPrivacyProofExtension(
            governanceKernel,
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            coreDisclosureRegistry,
            verifier
        );
        PeerReviewAnonymousChallengeProofPolicyModule disclosureModule =
            new PeerReviewAnonymousChallengeProofPolicyModule(fixture.proofExtension, policyId);
        PeerReviewZKProofReceiptPolicyModule proofPolicyModule =
            new PeerReviewZKProofReceiptPolicyModule(governanceKernel, policyId);
        fixture.challengePackageId =
            _registerIndependentChallengePackage(_challengeProofBindings(disclosureModule, proofPolicyModule));
        fixture.proof = IZKProofVerifier.SchnorrProof({
            publicKey: IZKProofVerifier.G1Point({x: 11, y: 12}),
            commitment: IZKProofVerifier.G1Point({x: 13, y: 14}),
            response: 15
        });
        fixture.subjectId = keccak256(abi.encode(fixture.proof.publicKey.x, fixture.proof.publicKey.y));
        fixture.challenger = new M14PeerReviewActor();
        coreIdentityRegistry.assignSubject(
            address(fixture.challenger),
            PeerReviewTypes.APP_ID,
            PeerReviewTypes.ROLE_CHALLENGER,
            fixture.subjectId,
            "ipfs://parity-anonymous-challenger"
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_CHALLENGER, AVACoreTypes.ACTION_RECORD_PRIVACY_PROOF, true
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_CHALLENGER, AVACoreTypes.ACTION_RECORD_DISCLOSURE_RECEIPT, true
        );
        fixture.evidenceId = fixture.challenger
            .registerEvidence(
                coreEvidenceRegistry,
                CHALLENGE_WORKFLOW,
                fixture.challengePackageId,
                PeerReviewTypes.ROLE_CHALLENGER,
                fixture.subjectId,
                keccak256("parity-anonymous-challenge-evidence"),
                policyId
            );
    }

    function _assertAnonymousChallengeProofUse(
        AnonymousChallengeFixture memory fixture,
        uint256 challengeId,
        uint256 proofReceiptId
    ) private {
        AVAChallengeProofUseExtension proofUseExtension = new AVAChallengeProofUseExtension(
            governanceKernel,
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            challengeExtension,
            fixture.proofExtension
        );
        AVAChallengeProofUseExtension.ProofUseInput memory proofUseInput = AVAChallengeProofUseExtension.ProofUseInput({
            challengeId: challengeId,
            proofReceiptId: proofReceiptId,
            roleKey: PeerReviewTypes.ROLE_CHALLENGER,
            authorityId: fixture.subjectId,
            reasonHash: keccak256("parity-anonymous-challenge-proof-use"),
            uri: "ipfs://parity-anonymous-challenge-proof-use"
        });
        uint256 proofUseId = fixture.challenger.recordChallengeProofUse(proofUseExtension, proofUseInput);
        AVAChallengeProofUseExtension.ProofUseRecord memory useRecord = proofUseExtension.getProofUseRecord(proofUseId);
        require(useRecord.challengeId == challengeId, "proof use challenge binding missing");
        require(useRecord.proofReceiptId == proofReceiptId, "proof use receipt binding missing");
        require(useRecord.subjectId == fixture.subjectId, "proof use subject commitment missing");
        bool replayed;
        try fixture.challenger.recordChallengeProofUse(proofUseExtension, proofUseInput) returns (uint256) {
            replayed = true;
        } catch {}
        require(!replayed, "anonymous challenge proof-use nullifier replay accepted");
    }

    function _recordStandingZKStatement(
        AVAStandingProvenanceExtension provenanceExtension,
        IZKProofVerifier verifier,
        uint256 stateId,
        bytes32 subjectCommitment
    ) private returns (uint256 statementId) {
        AVACoreTypes.RecognisedStateRecord memory state = governanceKernel.getRecognisedState(stateId);
        uint256 formulaId = panelActorV2.registerStandingFormula(
            provenanceExtension,
            AVAStandingProvenanceExtension.FormulaInput({
                appId: PeerReviewTypes.APP_ID,
                workflowKey: WORKFLOW,
                packageId: packageId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                vectorKey: keccak256("parity-standing-zk-vector"),
                formulaVersion: 1,
                computationRuleHash: keccak256("parity-standing-zk-rule"),
                sourceSetPolicyHash: keccak256("parity-standing-zk-source-policy"),
                decayPolicyHash: keccak256("parity-standing-zk-decay"),
                capPolicyHash: keccak256("parity-standing-zk-cap"),
                restorationPolicyHash: keccak256("parity-standing-zk-restoration"),
                verifier: address(verifier),
                proofDomainHash: verifier.proofDomain(),
                uri: "ipfs://parity-standing-zk-formula"
            })
        );
        uint256 sourceSetId = panelActorV2.registerStandingSourceSet(
            provenanceExtension,
            AVAStandingProvenanceExtension.SourceSetInput({
                formulaId: formulaId,
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                subjectId: M14_REVIEWER_SUBJECT,
                subjectCommitment: subjectCommitment,
                categoryHash: keccak256("parity-standing-zk-category"),
                epoch: 1,
                sourceRecordSetRoot: keccak256("parity-standing-zk-source-root"),
                evidenceId: state.evidenceReceiptId,
                completenessCommitment: keccak256("parity-standing-zk-completeness"),
                uri: "ipfs://parity-standing-zk-source-set"
            })
        );
        uint256 completenessId = panelActorV2.attestStandingSourceSet(
            provenanceExtension,
            AVAStandingProvenanceExtension.CompletenessInput({
                sourceSetId: sourceSetId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                evidenceId: state.evidenceReceiptId,
                includedRecordClassesHash: keccak256("parity-standing-zk-record-classes"),
                exclusionPolicyHash: keccak256("parity-standing-zk-exclusion"),
                attestationHash: keccak256("parity-standing-zk-attestation"),
                uri: "ipfs://parity-standing-zk-attestation"
            })
        );
        statementId = panelActorV2.recordStandingStatement(
            provenanceExtension,
            AVAStandingProvenanceExtension.StatementInput({
                sourceSetId: sourceSetId,
                completenessAttestationId: completenessId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                evidenceId: state.evidenceReceiptId,
                threshold: 50,
                lowerBound: 40,
                upperBound: 100,
                outputCommitment: keccak256("parity-standing-zk-output"),
                uri: "ipfs://parity-standing-zk-statement"
            })
        );
    }

    function _authoriseStandingProvenance() private {
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_REGISTER_STANDING_FORMULA, true
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_REGISTER_STANDING_SOURCE_SET, true
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_ATTEST_STANDING_SOURCE_SET, true
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID,
            PeerReviewTypes.ROLE_PANEL,
            AVACoreTypes.ACTION_RECORD_STANDING_COMPUTATION_STATEMENT,
            true
        );
    }

    function _authorisePenaltyExtension() internal {
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_RECORD_PENALTY, true
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_RECORD_STANDING_PENALTY_INPUT, true
        );
        coreAuthorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_RECORD_ELIGIBILITY_RESTRICTION, true
        );
    }

    function _createM14ChallengeableReviewState() internal returns (uint256 stateId) {
        (, uint256 reviewObjectId) = _registerManuscriptAndReview();
        stateId = editorActorV2.formState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateFormationInput({
                governedObjectId: reviewObjectId,
                roleKey: PeerReviewTypes.ROLE_EDITOR,
                authorityId: M14_EDITOR_SUBJECT,
                stage: AVACoreTypes.Stage.Verification,
                status: AVACoreTypes.RecognisedStateStatus.Provisional,
                reasonHash: keccak256("m14-provisional-for-challenge"),
                reasonURI: "ipfs://m14-provisional-for-challenge"
            })
        );
        editorActorV2.transitionState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_EDITOR,
                authorityId: M14_EDITOR_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Challengeable,
                reasonHash: keccak256("m14-challengeable-for-challenge"),
                reasonURI: "ipfs://m14-challengeable-for-challenge"
            })
        );
    }

    function _fileChallenge(uint256 stateId, string memory seed) internal returns (uint256) {
        uint256 challengeEvidenceId = challengerActorV2.registerEvidence(
            coreEvidenceRegistry,
            WORKFLOW,
            packageId,
            PeerReviewTypes.ROLE_CHALLENGER,
            M14_CHALLENGER_SUBJECT,
            keccak256(bytes(seed)),
            policyId
        );
        uint256 challengeStateId = _createChallengeRecognisedState(
            challengerActorV2, M14_CHALLENGER_SUBJECT, WORKFLOW, packageId, stateId, challengeEvidenceId, seed
        );
        return challengerActorV2.fileChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeFilingInput({
                appId: PeerReviewTypes.APP_ID,
                workflowKey: WORKFLOW,
                packageId: packageId,
                challengeRecognisedStateId: challengeStateId,
                challengedRecognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_CHALLENGER,
                reasonHash: keccak256(bytes(seed)),
                reasonURI: "ipfs://m14-challenge"
            })
        );
    }

    function _assertRecordOnlyChallengeOutcome(AVAChallengeExtension.ChallengeOutcome outcome, string memory seed)
        internal
    {
        uint256 stateId = _createM14ChallengeableReviewState();
        uint256 transitionIdBefore = governanceKernel.getRecognisedState(stateId).lastTransitionId;
        uint256 challengeId = _fileChallenge(stateId, seed);
        editorActorV2.screenChallenge(challengeExtension, challengeId, PeerReviewTypes.ROLE_EDITOR, M14_EDITOR_SUBJECT);
        panelActorV2.resolveChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeResolutionInput({
                challengeId: challengeId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                outcome: outcome,
                correctionStatus: AVACoreTypes.RecognisedStateStatus.Challengeable,
                reasonHash: keccak256(bytes(seed)),
                reasonURI: "ipfs://m14-record-only-outcome"
            })
        );
        require(
            governanceKernel.getRecognisedState(stateId).lastTransitionId == transitionIdBefore,
            "record-only outcome mutated recognised state"
        );
        require(challengeExtension.getChallenge(challengeId).outcome == outcome, "challenge outcome collapsed");
    }

    function _assertRecordOnlyVestedRestoration(AVAChallengeExtension.ChallengeOutcome outcome, string memory seed)
        internal
    {
        uint256 stateId = _createM14ChallengeableReviewState();
        panelActorV2.vestState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Vested,
                reasonHash: keccak256(abi.encode(seed, "vest")),
                reasonURI: "ipfs://m144-record-only-restoration-vest"
            })
        );
        uint256 transitionIdAtFiling = governanceKernel.getRecognisedState(stateId).lastTransitionId;
        uint256 challengeId = _fileChallenge(stateId, seed);
        editorActorV2.screenChallenge(challengeExtension, challengeId, PeerReviewTypes.ROLE_EDITOR, M14_EDITOR_SUBJECT);
        panelActorV2.resolveChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeResolutionInput({
                challengeId: challengeId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: M14_PANEL_SUBJECT,
                outcome: outcome,
                correctionStatus: AVACoreTypes.RecognisedStateStatus.Vested,
                reasonHash: keccak256(abi.encode(seed, "resolution")),
                reasonURI: "ipfs://m144-record-only-restoration-resolution"
            })
        );
        require(
            governanceKernel.getRecognisedState(stateId).lastTransitionId == transitionIdAtFiling,
            "record-only outcome mutated vested state"
        );
        panelActorV2.makeRestorationAvailable(
            challengeExtension,
            challengeId,
            PeerReviewTypes.ROLE_PANEL,
            M14_PANEL_SUBJECT,
            keccak256(abi.encode(seed, "available")),
            "ipfs://m144-record-only-restoration-available"
        );
        panelActorV2.restoreChallenge(
            challengeExtension,
            challengeId,
            PeerReviewTypes.ROLE_PANEL,
            M14_PANEL_SUBJECT,
            keccak256(abi.encode(seed, "restore")),
            "ipfs://m144-record-only-restoration"
        );
        AVACoreTypes.RecognisedStateRecord memory restored = governanceKernel.getRecognisedState(stateId);
        require(restored.status == AVACoreTypes.RecognisedStateStatus.Restored, "vested state not restored");
        require(restored.lastTransitionId != transitionIdAtFiling, "explicit restoration transition missing");
        require(
            challengeExtension.getChallenge(challengeId).status == AVAChallengeExtension.ChallengeStatus.Closed,
            "explicit restoration did not close challenge"
        );
    }

    function _registerManuscriptAndReview() internal returns (uint256 manuscriptObjectId, uint256 reviewObjectId) {
        uint256 authorEvidenceId = _registerAuthorEvidence("m14-manuscript-evidence");
        manuscriptObjectId = authorActor.registerObject(
            governanceKernel,
            _objectInput(
                PeerReviewTypes.ROLE_AUTHOR,
                PeerReviewTypes.OBJECT_MANUSCRIPT,
                keccak256("m14-manuscript-object"),
                0,
                M14_AUTHOR_SUBJECT,
                authorEvidenceId
            )
        );
        uint256 reviewEvidenceId = _registerReviewerEvidence("m14-review-evidence");
        reviewObjectId = reviewerActorV2.registerObject(
            governanceKernel,
            _objectInput(
                PeerReviewTypes.ROLE_REVIEWER,
                PeerReviewTypes.OBJECT_REVIEW_CONTRIBUTION,
                keccak256("m14-review-object"),
                manuscriptObjectId,
                M14_REVIEWER_SUBJECT,
                reviewEvidenceId
            )
        );
    }

    function _registerAuthorEvidence(string memory seed) internal returns (uint256) {
        return authorActor.registerEvidence(
            coreEvidenceRegistry,
            WORKFLOW,
            packageId,
            PeerReviewTypes.ROLE_AUTHOR,
            M14_AUTHOR_SUBJECT,
            keccak256(bytes(seed)),
            policyId
        );
    }

    function _registerReviewerEvidence(string memory seed) internal returns (uint256) {
        return reviewerActorV2.registerEvidence(
            coreEvidenceRegistry,
            WORKFLOW,
            packageId,
            PeerReviewTypes.ROLE_REVIEWER,
            M14_REVIEWER_SUBJECT,
            keccak256(bytes(seed)),
            policyId
        );
    }

    function _objectInput(
        bytes32 roleKey,
        bytes32 objectTypeKey,
        bytes32 objectCommitment,
        uint256 parentObjectId,
        bytes32 subjectId,
        uint256 evidenceReceiptId
    ) internal view returns (AVAGovernanceKernel.GovernedObjectInput memory input) {
        input = AVAGovernanceKernel.GovernedObjectInput({
                appId: PeerReviewTypes.APP_ID,
                workflowKey: WORKFLOW,
                packageId: packageId,
                roleKey: roleKey,
                objectTypeKey: objectTypeKey,
                objectCommitment: objectCommitment,
                parentObjectId: parentObjectId,
                subjectId: subjectId,
                evidenceReceiptId: evidenceReceiptId,
                disclosurePolicyId: policyId,
                metadataHash: keccak256(abi.encode(objectTypeKey, objectCommitment)),
                authorityId: subjectId,
                uri: "ipfs://m14-peer-review-object"
            });
    }
}
