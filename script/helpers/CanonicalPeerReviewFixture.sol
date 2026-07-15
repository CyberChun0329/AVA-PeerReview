// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVAApplicationRegistry} from "../../src/AVAApplicationRegistry.sol";
import {IAVAApplicationModule} from "../../src/interfaces/IAVAApplicationModule.sol";
import {IRuleModuleIdentity} from "../../src/interfaces/IRuleModuleIdentity.sol";
import {AVAAuthorityMatrix} from "../../src/core/AVAAuthorityMatrix.sol";
import {AVACapabilityKeys} from "../../src/core/AVACapabilityKeys.sol";
import {AVACoreRulePackageRegistry} from "../../src/core/AVACoreRulePackageRegistry.sol";
import {AVACoreTypes} from "../../src/core/AVACoreTypes.sol";
import {AVADisclosurePolicyRegistry} from "../../src/core/AVADisclosurePolicyRegistry.sol";
import {AVAEvidenceRegistry} from "../../src/core/AVAEvidenceRegistry.sol";
import {AVAGovernanceKernel} from "../../src/core/AVAGovernanceKernel.sol";
import {AVAIdentityRegistry} from "../../src/core/AVAIdentityRegistry.sol";
import {AVAWorkflowPolicyRouter} from "../../src/core/AVAWorkflowPolicyRouter.sol";
import {
    DefaultAVACorePolicyBundle
} from "../../src/core/modules/DefaultAVACoreRuleModules.sol";
import {
    AVARewardPriorityExtension,
    AVAPenaltyRestorationExtension
} from "../../src/extensions/governance/AVABoundedGovernanceExtensions.sol";
import {AVAValueLifecycleExtension} from "../../src/extensions/settlement/AVAValueLifecycleExtension.sol";
import {AVAChallengeExtension} from "../../src/extensions/challenge/AVAChallengeExtension.sol";
import {IAVAStandingRevision} from "../../src/extensions/standing/IAVAStandingRevision.sol";
import {AVAStandingRevisionExtension} from "../../src/extensions/standing/AVAStandingRevisionExtension.sol";
import {
    AVAStandingComputationExtension,
    AVAStandingCredentialExtension
} from "../../src/extensions/standing/AVAStandingCredentialExtensions.sol";
import {
    AVAStandingRecordExtension,
    AVAAllocationRecordExtension,
    AVAConsequenceRecordExtension
} from "../../src/extensions/downstream/AVADownstreamRecordExtensions.sol";
import {PeerReviewApplicationModule} from "../../src/apps/peerreview/PeerReviewApplicationModule.sol";
import {PeerReviewTypes} from "../../src/apps/peerreview/PeerReviewTypes.sol";

contract CanonicalPeerReviewActor {
    function registerRulePackage(
        AVACoreRulePackageRegistry registry,
        AVACoreRulePackageRegistry.PackageRegistrationInput calldata input,
        AVACoreRulePackageRegistry.ModuleBinding[] calldata bindings
    ) external returns (uint256) {
        return registry.registerRulePackage(input, bindings);
    }

    function registerPolicy(
        AVADisclosurePolicyRegistry registry,
        bytes32 roleKey,
        bytes32 authorityId,
        bytes32 policyKey
    ) external returns (uint256) {
        return registry.registerPolicy(
            PeerReviewTypes.APP_ID,
            roleKey,
            authorityId,
            policyKey,
            "canonical-peer-review-policy",
            "ipfs://canonical-peer-review-policy"
        );
    }

    function registerEvidence(
        AVAEvidenceRegistry registry,
        bytes32 workflowKey,
        uint256 packageId,
        bytes32 roleKey,
        bytes32 subjectId,
        bytes32 commitment,
        uint256 disclosurePolicyId
    ) external returns (uint256) {
        return registry.registerEvidence(
            AVAEvidenceRegistry.EvidenceRegistrationInput({
                appId: PeerReviewTypes.APP_ID,
                workflowKey: workflowKey,
                packageId: packageId,
                roleKey: roleKey,
                subjectId: subjectId,
                commitment: commitment,
                evidenceTypeHash: keccak256("canonical-peer-review-evidence-type.v1"),
                disclosurePolicyId: disclosurePolicyId,
                authorityId: subjectId,
                uri: "ipfs://canonical-peer-review-evidence"
            })
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

    function fileChallenge(AVAChallengeExtension extension, AVAChallengeExtension.ChallengeFilingInput calldata input)
        external
        returns (uint256)
    {
        return extension.fileChallenge(input);
    }

    function screenChallenge(AVAChallengeExtension extension, uint256 challengeId, bytes32 authorityId)
        external
        returns (uint256)
    {
        return extension.screenChallenge(challengeId, PeerReviewTypes.ROLE_EDITOR, authorityId);
    }

    function resolveChallenge(
        AVAChallengeExtension extension,
        AVAChallengeExtension.ChallengeResolutionInput calldata input
    ) external returns (uint256) {
        return extension.resolveChallenge(input);
    }

    function recordRestorationAvailability(
        AVAChallengeExtension extension,
        uint256 challengeId,
        bytes32 authorityId,
        bytes32 reasonHash
    ) external returns (uint256) {
        return extension.recordRestorationAvailability(
            challengeId,
            PeerReviewTypes.ROLE_PANEL,
            authorityId,
            reasonHash,
            "ipfs://canonical-restoration-availability"
        );
    }

    function applyRestoration(
        AVAChallengeExtension extension,
        uint256 challengeId,
        bytes32 authorityId,
        bytes32 reasonHash
    ) external returns (uint256) {
        return extension.applyRestoration(
            challengeId, PeerReviewTypes.ROLE_PANEL, authorityId, reasonHash, "ipfs://canonical-restoration"
        );
    }

    function closeChallenge(
        AVAChallengeExtension extension,
        uint256 challengeId,
        bytes32 authorityId,
        bytes32 reasonHash
    ) external returns (uint256) {
        return extension.closeChallenge(
            challengeId, PeerReviewTypes.ROLE_PANEL, authorityId, reasonHash, "ipfs://canonical-challenge-close"
        );
    }

    function recordStanding(
        AVAStandingRecordExtension extension,
        AVAStandingRecordExtension.StandingInput calldata input
    ) external returns (uint256) {
        return extension.recordStandingUpdate(input);
    }

    function recordConsequence(
        AVAConsequenceRecordExtension extension,
        AVAConsequenceRecordExtension.ConsequenceInput calldata input
    ) external returns (uint256) {
        return extension.recordConsequence(input);
    }

    function recordAllocation(
        AVAAllocationRecordExtension extension,
        AVAAllocationRecordExtension.AllocationInput calldata input
    ) external returns (uint256) {
        return extension.recordAllocation(input);
    }

    function recordReward(
        AVARewardPriorityExtension extension,
        AVARewardPriorityExtension.RewardPriorityInput calldata input
    ) external returns (uint256) {
        return extension.recordReward(input);
    }

    function recordPenalty(
        AVAPenaltyRestorationExtension extension,
        AVAPenaltyRestorationExtension.PenaltyInput calldata input
    ) external returns (uint256) {
        return extension.recordPenalty(input);
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
}

abstract contract CanonicalPeerReviewFixture {
    bytes32 internal constant REVIEW_WORKFLOW = keccak256("canonical.peer-review.review-workflow.v1");
    bytes32 internal constant CHALLENGE_WORKFLOW = keccak256("canonical.peer-review.challenge-workflow.v1");
    bytes32 internal constant PACKAGE_ROLE = keccak256("canonical.peer-review.package-role.v1");
    bytes32 internal constant PACKAGE_SUBJECT = keccak256("canonical.peer-review.package-subject.v1");
    bytes32 internal constant PACKAGE_COMPATIBILITY = keccak256("canonical.peer-review.compatibility.v1");
    bytes32 internal constant AUTHOR_SUBJECT = keccak256("canonical.peer-review.author-subject.v1");
    bytes32 internal constant REVIEWER_SUBJECT = keccak256("canonical.peer-review.reviewer-subject.v1");
    bytes32 internal constant EDITOR_SUBJECT = keccak256("canonical.peer-review.editor-subject.v1");
    bytes32 internal constant PANEL_SUBJECT = keccak256("canonical.peer-review.panel-subject.v1");
    bytes32 internal constant CHALLENGER_SUBJECT = keccak256("canonical.peer-review.challenger-subject.v1");

    struct ReviewPath {
        uint256 manuscriptObjectId;
        uint256 reviewObjectId;
        uint256 reviewEvidenceId;
        uint256 recognisedStateId;
    }

    struct ChallengePath {
        uint256 challengeObjectId;
        uint256 challengeRecognisedStateId;
        uint256 challengeEvidenceId;
        uint256 challengeId;
    }

    AVAApplicationRegistry internal applicationRegistry;
    AVAIdentityRegistry internal identityRegistry;
    AVAAuthorityMatrix internal authorityMatrix;
    AVACoreRulePackageRegistry internal packageRegistry;
    AVADisclosurePolicyRegistry internal disclosureRegistry;
    AVAEvidenceRegistry internal evidenceRegistry;
    AVAWorkflowPolicyRouter internal policyRouter;
    AVAGovernanceKernel internal governanceKernel;
    AVAChallengeExtension internal challengeExtension;
    AVAStandingRevisionExtension internal revisionExtension;
    AVAStandingRecordExtension internal standingExtension;
    AVAAllocationRecordExtension internal allocationExtension;
    AVAConsequenceRecordExtension internal consequenceExtension;

    CanonicalPeerReviewActor internal authorActor;
    CanonicalPeerReviewActor internal reviewerActor;
    CanonicalPeerReviewActor internal editorActor;
    CanonicalPeerReviewActor internal panelActor;
    CanonicalPeerReviewActor internal challengerActor;
    CanonicalPeerReviewActor internal packageActor;

    uint256 internal reviewPackageId;
    uint256 internal challengePackageId;
    uint256 internal disclosurePolicyId;

    function _deployCanonicalPeerReview() internal {
        _deployCanonicalPeerReview(false);
    }

    function _deployCanonicalPeerReviewWithRevision() internal {
        _deployCanonicalPeerReview(true);
    }

    function _deployCanonicalPeerReview(bool withRevision) private {
        applicationRegistry = new AVAApplicationRegistry();
        applicationRegistry.registerApplication(
            PeerReviewTypes.APP_ID,
            keccak256("canonical.peer-review.application.v1"),
            keccak256("canonical.peer-review.application-authority.v1"),
            "ipfs://canonical-peer-review-application"
        );
        identityRegistry = new AVAIdentityRegistry(applicationRegistry);
        authorityMatrix = new AVAAuthorityMatrix(applicationRegistry, identityRegistry);
        packageActor = new CanonicalPeerReviewActor();
        identityRegistry.assignSubject(
            address(packageActor),
            PeerReviewTypes.APP_ID,
            PACKAGE_ROLE,
            PACKAGE_SUBJECT,
            "ipfs://canonical-package-subject"
        );
        authorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PACKAGE_ROLE, AVACoreTypes.ACTION_REGISTER_RULE_PACKAGE, true
        );
        packageRegistry = new AVACoreRulePackageRegistry(applicationRegistry, authorityMatrix);
        PeerReviewApplicationModule applicationModule = new PeerReviewApplicationModule();
        AVACoreRulePackageRegistry.ModuleBinding[] memory bindings = _canonicalBindings(applicationModule);
        reviewPackageId = packageActor.registerRulePackage(
            packageRegistry, _packageInput(REVIEW_WORKFLOW, "ipfs://canonical-review-package"), bindings
        );
        challengePackageId = packageActor.registerRulePackage(
            packageRegistry, _packageInput(CHALLENGE_WORKFLOW, "ipfs://canonical-challenge-package"), bindings
        );

        disclosureRegistry = new AVADisclosurePolicyRegistry(applicationRegistry, authorityMatrix);
        evidenceRegistry =
            new AVAEvidenceRegistry(authorityMatrix, identityRegistry, packageRegistry, disclosureRegistry);
        policyRouter = new AVAWorkflowPolicyRouter(packageRegistry, evidenceRegistry, disclosureRegistry);
        governanceKernel = new AVAGovernanceKernel(
            authorityMatrix, identityRegistry, packageRegistry, evidenceRegistry, disclosureRegistry, policyRouter
        );
        challengeExtension = new AVAChallengeExtension(
            governanceKernel, authorityMatrix, identityRegistry, packageRegistry, evidenceRegistry
        );
        if (withRevision) revisionExtension = new AVAStandingRevisionExtension(governanceKernel);
        standingExtension = new AVAStandingRecordExtension(
            governanceKernel,
            authorityMatrix,
            identityRegistry,
            packageRegistry,
            evidenceRegistry,
            withRevision ? IAVAStandingRevision(address(revisionExtension)) : IAVAStandingRevision(address(0))
        );
        allocationExtension = new AVAAllocationRecordExtension(
            governanceKernel, authorityMatrix, identityRegistry, packageRegistry, evidenceRegistry
        );
        consequenceExtension = new AVAConsequenceRecordExtension(
            governanceKernel, authorityMatrix, identityRegistry, packageRegistry, evidenceRegistry
        );
        if (withRevision) {
            revisionExtension.bindRevisionWriter(reviewPackageId, address(standingExtension));
            revisionExtension.bindRevisionWriter(challengePackageId, address(standingExtension));
        }
        governanceKernel.bindSourceBoundTransitionRequester(reviewPackageId, address(challengeExtension));
        governanceKernel.bindTransitionGuard(reviewPackageId, address(challengeExtension));
        governanceKernel.bindSourceBoundTransitionRequester(challengePackageId, address(challengeExtension));
        governanceKernel.bindTransitionGuard(challengePackageId, address(challengeExtension));

        _deployActorsAndSubjects();
        _grantPermissions();
        disclosurePolicyId = editorActor.registerPolicy(
            disclosureRegistry,
            PeerReviewTypes.ROLE_EDITOR,
            EDITOR_SUBJECT,
            keccak256("canonical.peer-review.disclosure-policy.v1")
        );
    }

    function _finalizeRevisionHooks() internal {
        governanceKernel.bindPostTransitionHook(reviewPackageId, address(revisionExtension));
        governanceKernel.bindPostTransitionHook(challengePackageId, address(revisionExtension));
    }

    function _deployActorsAndSubjects() private {
        authorActor = new CanonicalPeerReviewActor();
        reviewerActor = new CanonicalPeerReviewActor();
        editorActor = new CanonicalPeerReviewActor();
        panelActor = new CanonicalPeerReviewActor();
        challengerActor = new CanonicalPeerReviewActor();
        _assign(authorActor, PeerReviewTypes.ROLE_AUTHOR, AUTHOR_SUBJECT);
        _assign(reviewerActor, PeerReviewTypes.ROLE_REVIEWER, REVIEWER_SUBJECT);
        _assign(editorActor, PeerReviewTypes.ROLE_EDITOR, EDITOR_SUBJECT);
        _assign(panelActor, PeerReviewTypes.ROLE_PANEL, PANEL_SUBJECT);
        _assign(challengerActor, PeerReviewTypes.ROLE_CHALLENGER, CHALLENGER_SUBJECT);
    }

    function _assign(CanonicalPeerReviewActor actor, bytes32 roleKey, bytes32 subjectId) private {
        identityRegistry.assignSubject(
            address(actor), PeerReviewTypes.APP_ID, roleKey, subjectId, "ipfs://canonical-role-subject"
        );
    }

    function _grantPermissions() private {
        _permit(PeerReviewTypes.ROLE_AUTHOR, AVACoreTypes.ACTION_REGISTER_EVIDENCE);
        _permit(PeerReviewTypes.ROLE_AUTHOR, AVACoreTypes.ACTION_REGISTER_GOVERNED_OBJECT);
        _permit(PeerReviewTypes.ROLE_REVIEWER, AVACoreTypes.ACTION_REGISTER_EVIDENCE);
        _permit(PeerReviewTypes.ROLE_REVIEWER, AVACoreTypes.ACTION_REGISTER_GOVERNED_OBJECT);
        _permit(PeerReviewTypes.ROLE_CHALLENGER, AVACoreTypes.ACTION_REGISTER_EVIDENCE);
        _permit(PeerReviewTypes.ROLE_CHALLENGER, AVACoreTypes.ACTION_REGISTER_GOVERNED_OBJECT);
        _permit(PeerReviewTypes.ROLE_CHALLENGER, AVACoreTypes.ACTION_FORM_RECOGNISED_STATE);
        _permit(PeerReviewTypes.ROLE_CHALLENGER, AVACoreTypes.ACTION_FILE_CHALLENGE);
        _permit(PeerReviewTypes.ROLE_EDITOR, AVACoreTypes.ACTION_REGISTER_DISCLOSURE_POLICY);
        _permit(PeerReviewTypes.ROLE_EDITOR, AVACoreTypes.ACTION_FORM_RECOGNISED_STATE);
        _permit(PeerReviewTypes.ROLE_EDITOR, AVACoreTypes.ACTION_TRANSITION_RECOGNISED_STATE);
        _permit(PeerReviewTypes.ROLE_EDITOR, AVACoreTypes.ACTION_SCREEN_CHALLENGE);
        _permit(PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_VEST_RECOGNISED_STATE);
        _permit(PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_RESOLVE_CHALLENGE);
        _permit(PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_APPLY_RESTORATION);
        _permit(PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_CLOSE_CHALLENGE);
        _permit(PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_RECORD_STANDING_UPDATE);
        _permit(PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_RECORD_CONSEQUENCE);
        _permit(PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_RECORD_STANDING_COMPUTATION);
        _permit(PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_ISSUE_STANDING_CREDENTIAL);
    }

    function _permit(bytes32 roleKey, bytes32 actionKey) private {
        authorityMatrix.setPermission(PeerReviewTypes.APP_ID, roleKey, actionKey, true);
    }

    function _createReviewPath(string memory seed, bool vest) internal returns (ReviewPath memory path) {
        uint256 authorEvidenceId = authorActor.registerEvidence(
            evidenceRegistry,
            REVIEW_WORKFLOW,
            reviewPackageId,
            PeerReviewTypes.ROLE_AUTHOR,
            AUTHOR_SUBJECT,
            keccak256(abi.encode(seed, "author-evidence")),
            disclosurePolicyId
        );
        path.manuscriptObjectId = authorActor.registerObject(
            governanceKernel,
            AVAGovernanceKernel.GovernedObjectInput({
                appId: PeerReviewTypes.APP_ID,
                workflowKey: REVIEW_WORKFLOW,
                packageId: reviewPackageId,
                roleKey: PeerReviewTypes.ROLE_AUTHOR,
                objectTypeKey: PeerReviewTypes.OBJECT_MANUSCRIPT,
                objectCommitment: keccak256(abi.encode(seed, "manuscript")),
                parentObjectId: 0,
                subjectId: AUTHOR_SUBJECT,
                evidenceReceiptId: authorEvidenceId,
                disclosurePolicyId: disclosurePolicyId,
                metadataHash: keccak256(abi.encode(seed, "manuscript-metadata")),
                authorityId: AUTHOR_SUBJECT,
                uri: "ipfs://canonical-manuscript"
            })
        );
        path.reviewEvidenceId = reviewerActor.registerEvidence(
            evidenceRegistry,
            REVIEW_WORKFLOW,
            reviewPackageId,
            PeerReviewTypes.ROLE_REVIEWER,
            REVIEWER_SUBJECT,
            keccak256(abi.encode(seed, "review-evidence")),
            disclosurePolicyId
        );
        path.reviewObjectId = reviewerActor.registerObject(
            governanceKernel,
            AVAGovernanceKernel.GovernedObjectInput({
                appId: PeerReviewTypes.APP_ID,
                workflowKey: REVIEW_WORKFLOW,
                packageId: reviewPackageId,
                roleKey: PeerReviewTypes.ROLE_REVIEWER,
                objectTypeKey: PeerReviewTypes.OBJECT_REVIEW_CONTRIBUTION,
                objectCommitment: keccak256(abi.encode(seed, "review")),
                parentObjectId: path.manuscriptObjectId,
                subjectId: REVIEWER_SUBJECT,
                evidenceReceiptId: path.reviewEvidenceId,
                disclosurePolicyId: disclosurePolicyId,
                metadataHash: keccak256(abi.encode(seed, "review-metadata")),
                authorityId: REVIEWER_SUBJECT,
                uri: "ipfs://canonical-review"
            })
        );
        path.recognisedStateId = editorActor.formState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateFormationInput({
                governedObjectId: path.reviewObjectId,
                roleKey: PeerReviewTypes.ROLE_EDITOR,
                authorityId: EDITOR_SUBJECT,
                stage: AVACoreTypes.Stage.Verification,
                status: AVACoreTypes.RecognisedStateStatus.Provisional,
                reasonHash: keccak256(abi.encode(seed, "review-provisional")),
                reasonURI: "ipfs://canonical-review-provisional"
            })
        );
        editorActor.transitionState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: path.recognisedStateId,
                roleKey: PeerReviewTypes.ROLE_EDITOR,
                authorityId: EDITOR_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Challengeable,
                reasonHash: keccak256(abi.encode(seed, "review-challengeable")),
                reasonURI: "ipfs://canonical-review-challengeable"
            })
        );
        if (vest) _vestState(path.recognisedStateId, seed);
    }

    function _vestState(uint256 recognisedStateId, string memory seed) internal returns (uint256 transitionId) {
        transitionId = panelActor.vestState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: recognisedStateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: PANEL_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Vested,
                reasonHash: keccak256(abi.encode(seed, "vest")),
                reasonURI: "ipfs://canonical-vesting"
            })
        );
    }

    function _createChallengePath(uint256 targetStateId, string memory seed)
        internal
        returns (ChallengePath memory path)
    {
        return _createChallengePathFor(challengerActor, CHALLENGER_SUBJECT, targetStateId, seed);
    }

    function _createChallengePathFor(
        CanonicalPeerReviewActor filingActor,
        bytes32 challengerSubjectId,
        uint256 targetStateId,
        string memory seed
    ) internal returns (ChallengePath memory path) {
        AVACoreTypes.RecognisedStateRecord memory target = governanceKernel.getRecognisedState(targetStateId);
        path.challengeEvidenceId = filingActor.registerEvidence(
            evidenceRegistry,
            CHALLENGE_WORKFLOW,
            challengePackageId,
            PeerReviewTypes.ROLE_CHALLENGER,
            challengerSubjectId,
            keccak256(abi.encode(seed, "challenge-evidence")),
            disclosurePolicyId
        );
        path.challengeObjectId = filingActor.registerObject(
            governanceKernel,
            AVAGovernanceKernel.GovernedObjectInput({
                appId: PeerReviewTypes.APP_ID,
                workflowKey: CHALLENGE_WORKFLOW,
                packageId: challengePackageId,
                roleKey: PeerReviewTypes.ROLE_CHALLENGER,
                objectTypeKey: PeerReviewTypes.OBJECT_CHALLENGE,
                objectCommitment: keccak256(abi.encode(seed, "challenge")),
                parentObjectId: target.governedObjectId,
                subjectId: challengerSubjectId,
                evidenceReceiptId: path.challengeEvidenceId,
                disclosurePolicyId: disclosurePolicyId,
                metadataHash: keccak256(abi.encode(seed, "challenge-metadata")),
                authorityId: challengerSubjectId,
                uri: "ipfs://canonical-challenge"
            })
        );
        path.challengeRecognisedStateId = filingActor.formState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateFormationInput({
                governedObjectId: path.challengeObjectId,
                roleKey: PeerReviewTypes.ROLE_CHALLENGER,
                authorityId: challengerSubjectId,
                stage: AVACoreTypes.Stage.Verification,
                status: AVACoreTypes.RecognisedStateStatus.Registered,
                reasonHash: keccak256(abi.encode(seed, "challenge-registered")),
                reasonURI: "ipfs://canonical-challenge-registered"
            })
        );
        path.challengeId = filingActor.fileChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeFilingInput({
                appId: PeerReviewTypes.APP_ID,
                workflowKey: CHALLENGE_WORKFLOW,
                packageId: challengePackageId,
                challengeRecognisedStateId: path.challengeRecognisedStateId,
                challengedRecognisedStateId: targetStateId,
                roleKey: PeerReviewTypes.ROLE_CHALLENGER,
                reasonHash: keccak256(abi.encode(seed, "challenge-filed")),
                reasonURI: "ipfs://canonical-challenge-filed"
            })
        );
    }

    function _screenAndResolve(
        ChallengePath memory path,
        AVAChallengeExtension.ChallengeOutcome outcome,
        AVACoreTypes.RecognisedStateStatus correctionStatus,
        string memory seed
    ) internal returns (uint256 resolutionTransitionId) {
        editorActor.screenChallenge(challengeExtension, path.challengeId, EDITOR_SUBJECT);
        resolutionTransitionId = panelActor.resolveChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeResolutionInput({
                challengeId: path.challengeId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: PANEL_SUBJECT,
                outcome: outcome,
                correctionStatus: correctionStatus,
                reasonHash: keccak256(abi.encode(seed, "challenge-resolution")),
                reasonURI: "ipfs://canonical-challenge-resolution"
            })
        );
    }

    function _packageInput(bytes32 workflowKey, string memory uri)
        private
        pure
        returns (AVACoreRulePackageRegistry.PackageRegistrationInput memory)
    {
        return AVACoreRulePackageRegistry.PackageRegistrationInput({
            appId: PeerReviewTypes.APP_ID,
            workflowKey: workflowKey,
            roleKey: PACKAGE_ROLE,
            authorityId: PACKAGE_SUBJECT,
            version: 1,
            compatibilityKey: PACKAGE_COMPATIBILITY,
            uri: uri
        });
    }

    function _canonicalBindings(IAVAApplicationModule applicationModule)
        internal
        virtual
        returns (AVACoreRulePackageRegistry.ModuleBinding[] memory bindings)
    {
        bindings = new AVACoreRulePackageRegistry.ModuleBinding[](12);
        address defaultCorePolicy = address(new DefaultAVACorePolicyBundle());
        bindings[0] = _binding(AVACapabilityKeys.APPLICATION, address(applicationModule));
        bindings[1] = _binding(AVACapabilityKeys.ATTRIBUTION, defaultCorePolicy);
        bindings[2] = _binding(AVACapabilityKeys.VERIFICATION, defaultCorePolicy);
        bindings[3] = _binding(AVACapabilityKeys.TRANSITION_RULE, defaultCorePolicy);
        bindings[4] = _binding(AVACapabilityKeys.EVIDENCE_POLICY, defaultCorePolicy);
        bindings[5] = _binding(AVACapabilityKeys.DISCLOSURE_POLICY, defaultCorePolicy);
        bindings[6] = _binding(AVACapabilityKeys.CHALLENGE_POLICY, defaultCorePolicy);
        bindings[7] = _binding(AVACapabilityKeys.AUTHORITY_POLICY, defaultCorePolicy);
        bindings[8] = _binding(AVACapabilityKeys.STANDING, defaultCorePolicy);
        bindings[9] = _binding(AVACapabilityKeys.ALLOCATION, defaultCorePolicy);
        bindings[10] = _binding(AVACapabilityKeys.CONSEQUENCE, defaultCorePolicy);
        bindings[11] = _binding(AVACapabilityKeys.EVIDENCE_LIFECYCLE, defaultCorePolicy);
    }

    function _binding(bytes32 capabilityKey, address module)
        internal
        pure
        returns (AVACoreRulePackageRegistry.ModuleBinding memory)
    {
        return AVACoreRulePackageRegistry.ModuleBinding({
            capabilityKey: capabilityKey, module: IRuleModuleIdentity(module)
        });
    }
}
