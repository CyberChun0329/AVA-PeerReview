// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVACoreRulePackageRegistry} from "../src/core/AVACoreRulePackageRegistry.sol";
import {AVACoreTypes} from "../src/core/AVACoreTypes.sol";
import {AVAAuthorityMatrix} from "../src/core/AVAAuthorityMatrix.sol";
import {AVADisclosurePolicyRegistry} from "../src/core/AVADisclosurePolicyRegistry.sol";
import {AVAEvidenceRegistry} from "../src/core/AVAEvidenceRegistry.sol";
import {AVAGovernanceKernel} from "../src/core/AVAGovernanceKernel.sol";
import {AVAIdentityRegistry} from "../src/core/AVAIdentityRegistry.sol";
import {AVAWorkflowPolicyRouter} from "../src/core/AVAWorkflowPolicyRouter.sol";
import {IAVAApplicationModule} from "../src/interfaces/IAVAApplicationModule.sol";
import {PeerReviewTypes} from "../src/apps/peerreview/PeerReviewTypes.sol";
import {PeerReviewApplicationModule} from "../src/apps/peerreview/PeerReviewApplicationModule.sol";
import {SecondaryTestAppTypes} from "./helpers/SecondaryTestApp.sol";
import {SecondaryTestApplicationModule} from "./helpers/SecondaryTestApp.sol";
import {AVAChallengeExtension} from "../src/extensions/challenge/AVAChallengeExtension.sol";
import {AVAAllocationRecordExtension} from "../src/extensions/downstream/AVADownstreamRecordExtensions.sol";
import {M14ApplicationFixture} from "./helpers/M14ApplicationFixture.sol";
import {AVAApplicationConformance} from "./helpers/AVAApplicationConformance.sol";
import "./helpers/M14CorePackageFixture.sol";

contract M14MultiAppActor {
    function registerPolicy(
        AVADisclosurePolicyRegistry registry,
        bytes32 appId,
        bytes32 roleKey,
        bytes32 authorityId,
        bytes32 policyKey
    ) external returns (uint256) {
        return registry.registerPolicy(appId, roleKey, authorityId, policyKey, "m14-policy", "ipfs://m14-policy");
    }

    function registerEvidence(
        AVAEvidenceRegistry registry,
        bytes32 appId,
        bytes32 workflowKey,
        uint256 packageId,
        bytes32 roleKey,
        bytes32 subjectId,
        bytes32 commitment,
        uint256 disclosurePolicyId
    ) external returns (uint256) {
        return registry.registerEvidence(
            AVAEvidenceRegistry.EvidenceRegistrationInput({
                appId: appId,
                workflowKey: workflowKey,
                packageId: packageId,
                roleKey: roleKey,
                subjectId: subjectId,
                commitment: commitment,
                evidenceTypeHash: keccak256("m14-multi-app-evidence"),
                disclosurePolicyId: disclosurePolicyId,
                authorityId: subjectId,
                uri: "ipfs://m14-multi-app-evidence"
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

    function screenChallenge(AVAChallengeExtension extension, uint256 challengeId, bytes32 roleKey, bytes32 authorityId)
        external
        returns (uint256)
    {
        return extension.screenChallenge(challengeId, roleKey, authorityId);
    }

    function resolveChallenge(
        AVAChallengeExtension extension,
        AVAChallengeExtension.ChallengeResolutionInput calldata input
    ) external returns (uint256) {
        return extension.resolveChallenge(input);
    }

    function closeChallenge(
        AVAChallengeExtension extension,
        uint256 challengeId,
        bytes32 roleKey,
        bytes32 authorityId,
        bytes32 reasonHash
    ) external returns (uint256) {
        return extension.closeChallenge(
            challengeId, roleKey, authorityId, reasonHash, "ipfs://m14-multi-app-challenge-close"
        );
    }

    function recordAllocation(
        AVAAllocationRecordExtension extension,
        AVAAllocationRecordExtension.AllocationInput calldata input
    ) external returns (uint256) {
        return extension.recordAllocation(input);
    }
}

contract M14MultiAppTest is M14ApplicationFixture, M14CorePackageFixture {
    bytes32 private constant SHARED_WORKFLOW = keccak256("m14.shared.workflow");

    bytes32 private constant PEER_AUTHOR = keccak256("m14.multi.peer.author");
    bytes32 private constant PEER_REVIEWER = keccak256("m14.multi.peer.reviewer");
    bytes32 private constant PEER_EDITOR = keccak256("m14.multi.peer.editor");
    bytes32 private constant PEER_PANEL = keccak256("m14.multi.peer.panel");
    bytes32 private constant PEER_EXECUTOR = keccak256("m14.multi.peer.executor");

    bytes32 private constant SECONDARY_CONTRIBUTOR = keccak256("m14.multi.secondary.contributor");
    bytes32 private constant SECONDARY_CHALLENGER = keccak256("m14.multi.secondary.challenger");
    bytes32 private constant SECONDARY_REVIEWER = keccak256("m14.multi.secondary.reviewer");
    bytes32 private constant SECONDARY_PANEL = keccak256("m14.multi.secondary.panel");
    bytes32 private constant SECONDARY_EXECUTOR = keccak256("m14.multi.secondary.executor");
    bytes32 private constant PACKAGE_ROLE = keccak256("m14.multi.package-role");
    bytes32 private constant PEER_PACKAGE_SUBJECT = keccak256("m14.multi.peer-package-subject");
    bytes32 private constant SECONDARY_PACKAGE_SUBJECT = keccak256("m14.multi.secondary-package-subject");
    bytes32 private constant PACKAGE_COMPATIBILITY = keccak256("m14.multi.compatibility");

    AVAIdentityRegistry private identityRegistryV2;
    AVAAuthorityMatrix private authorityMatrixV2;
    AVADisclosurePolicyRegistry private disclosureRegistryV2;
    AVAEvidenceRegistry private evidenceRegistryV2;
    AVACoreRulePackageRegistry private corePackageRegistry;
    AVAGovernanceKernel private kernel;
    AVAChallengeExtension private challengeExtension;
    AVAAllocationRecordExtension private allocationExtension;
    PeerReviewApplicationModule private peerModule;
    SecondaryTestApplicationModule private secondaryModule;

    M14MultiAppActor private peerAuthorActor;
    M14MultiAppActor private peerReviewerActor;
    M14MultiAppActor private peerEditorActor;
    M14MultiAppActor private peerPanelActor;
    M14MultiAppActor private peerExecutorActor;
    M14MultiAppActor private secondaryContributorActor;
    M14MultiAppActor private secondaryChallengerActor;
    M14MultiAppActor private secondaryReviewerActor;
    M14MultiAppActor private secondaryPanelActor;
    M14MultiAppActor private secondaryExecutorActor;

    uint256 private peerPackageId;
    uint256 private secondaryPackageId;
    uint256 private peerPolicyId;
    uint256 private secondaryPolicyId;

    function setUp() public override {
        super.setUp();
        applicationRegistry.registerApplication(
            SecondaryTestAppTypes.APP_ID,
            keccak256("m14.secondary-dao-app-identity"),
            keccak256("m14.secondary-dao-app-authority"),
            "ipfs://m14-secondary-dao-app"
        );
        peerModule = new PeerReviewApplicationModule();
        secondaryModule = new SecondaryTestApplicationModule();
        identityRegistryV2 = new AVAIdentityRegistry(applicationRegistry);
        authorityMatrixV2 = new AVAAuthorityMatrix(applicationRegistry, identityRegistryV2);
        identityRegistryV2.assignSubject(
            address(this), PeerReviewTypes.APP_ID, PACKAGE_ROLE, PEER_PACKAGE_SUBJECT, "ipfs://m14-peer-package-subject"
        );
        identityRegistryV2.assignSubject(
            address(this),
            SecondaryTestAppTypes.APP_ID,
            PACKAGE_ROLE,
            SECONDARY_PACKAGE_SUBJECT,
            "ipfs://m14-secondary-package-subject"
        );
        authorityMatrixV2.setPermission(
            PeerReviewTypes.APP_ID, PACKAGE_ROLE, AVACoreTypes.ACTION_REGISTER_RULE_PACKAGE, true
        );
        authorityMatrixV2.setPermission(
            SecondaryTestAppTypes.APP_ID, PACKAGE_ROLE, AVACoreTypes.ACTION_REGISTER_RULE_PACKAGE, true
        );
        corePackageRegistry = new AVACoreRulePackageRegistry(applicationRegistry, authorityMatrixV2);
        peerPackageId = corePackageRegistry.registerRulePackage(
            _corePackageInput(
                PeerReviewTypes.APP_ID,
                SHARED_WORKFLOW,
                PACKAGE_ROLE,
                PEER_PACKAGE_SUBJECT,
                1,
                PACKAGE_COMPATIBILITY,
                "ipfs://m14-peer-multi-app-package"
            ),
            _coreBindings(peerModule)
        );
        secondaryPackageId = corePackageRegistry.registerRulePackage(
            _corePackageInput(
                SecondaryTestAppTypes.APP_ID,
                SHARED_WORKFLOW,
                PACKAGE_ROLE,
                SECONDARY_PACKAGE_SUBJECT,
                1,
                PACKAGE_COMPATIBILITY,
                "ipfs://m14-secondary-multi-app-package"
            ),
            _coreBindings(secondaryModule)
        );
        disclosureRegistryV2 = new AVADisclosurePolicyRegistry(applicationRegistry, authorityMatrixV2);
        evidenceRegistryV2 =
            new AVAEvidenceRegistry(authorityMatrixV2, identityRegistryV2, corePackageRegistry, disclosureRegistryV2);
        kernel = new AVAGovernanceKernel(
            authorityMatrixV2,
            identityRegistryV2,
            corePackageRegistry,
            evidenceRegistryV2,
            disclosureRegistryV2,
            new AVAWorkflowPolicyRouter(corePackageRegistry, evidenceRegistryV2, disclosureRegistryV2)
        );
        challengeExtension = new AVAChallengeExtension(
            kernel, authorityMatrixV2, identityRegistryV2, corePackageRegistry, evidenceRegistryV2
        );
        allocationExtension = new AVAAllocationRecordExtension(
            kernel, authorityMatrixV2, identityRegistryV2, corePackageRegistry, evidenceRegistryV2
        );
        kernel.bindSourceBoundTransitionRequester(peerPackageId, address(challengeExtension));
        kernel.bindTransitionGuard(peerPackageId, address(challengeExtension));
        kernel.bindSourceBoundTransitionRequester(secondaryPackageId, address(challengeExtension));
        kernel.bindTransitionGuard(secondaryPackageId, address(challengeExtension));

        _deployActorsAndSubjects();
        _grantPermissions();
        peerPolicyId = peerEditorActor.registerPolicy(
            disclosureRegistryV2,
            PeerReviewTypes.APP_ID,
            PeerReviewTypes.ROLE_EDITOR,
            PEER_EDITOR,
            keccak256("m14-peer-policy")
        );
        secondaryPolicyId = secondaryReviewerActor.registerPolicy(
            disclosureRegistryV2,
            SecondaryTestAppTypes.APP_ID,
            SecondaryTestAppTypes.ROLE_VERIFIER,
            SECONDARY_REVIEWER,
            keccak256("m14-secondary-policy")
        );
    }

    function testM146PeerReviewAndSecondaryTestAppUseOneCoreWithIndependentVocabulary() public {
        (uint256 peerStateId,) = _createPeerReviewState("m146-dual-peer");
        (uint256 secondaryStateId,) = _createSecondarySubmissionState("m146-dual-secondary", secondaryPackageId);
        AVAApplicationConformance.assertVerifiedPackage(
            corePackageRegistry, peerPackageId, PeerReviewTypes.APP_ID, SHARED_WORKFLOW
        );
        AVAApplicationConformance.assertVerifiedPackage(
            corePackageRegistry, secondaryPackageId, SecondaryTestAppTypes.APP_ID, SHARED_WORKFLOW
        );
        AVAApplicationConformance.assertHistoricalStateBinding(
            kernel, peerStateId, PeerReviewTypes.APP_ID, SHARED_WORKFLOW, peerPackageId
        );
        AVAApplicationConformance.assertHistoricalStateBinding(
            kernel, secondaryStateId, SecondaryTestAppTypes.APP_ID, SHARED_WORKFLOW, secondaryPackageId
        );
        _vestPeerState(peerStateId, "m146-peer-vest");
        _vestSecondaryState(secondaryStateId, "m146-secondary-vest");

        AVACoreTypes.RecognisedStateRecord memory peerState = kernel.getRecognisedState(peerStateId);
        AVACoreTypes.RecognisedStateRecord memory secondaryState = kernel.getRecognisedState(secondaryStateId);
        require(peerState.appId == PeerReviewTypes.APP_ID && peerState.packageId == peerPackageId, "peer state wrong");
        require(
            secondaryState.appId == SecondaryTestAppTypes.APP_ID && secondaryState.packageId == secondaryPackageId,
            "secondary state wrong"
        );
        require(peerState.workflowKey == secondaryState.workflowKey, "shared workflow key not exercised");
        require(peerState.status == AVACoreTypes.RecognisedStateStatus.Vested, "peer state not vested");
        require(secondaryState.status == AVACoreTypes.RecognisedStateStatus.Vested, "secondary state not vested");
    }

    function testM146SecondaryTestAppChallengeResolutionAndBoundedAllocationRunThroughReusableExtensions() public {
        (uint256 stateId, uint256 stateEvidenceId) =
            _createSecondarySubmissionState("m146-secondary-flow", secondaryPackageId);
        uint256 challengeEvidenceId = _registerEvidence(
            secondaryChallengerActor,
            SecondaryTestAppTypes.APP_ID,
            secondaryPackageId,
            SecondaryTestAppTypes.ROLE_SUBMITTER,
            SECONDARY_CHALLENGER,
            secondaryPolicyId,
            keccak256("m146-secondary-challenge-evidence")
        );
        uint256 challengeStateId =
            _createSecondaryChallengeState(stateId, challengeEvidenceId, "m146-secondary-challenge");
        uint256 challengeId = secondaryChallengerActor.fileChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeFilingInput({
                appId: SecondaryTestAppTypes.APP_ID,
                workflowKey: SHARED_WORKFLOW,
                packageId: secondaryPackageId,
                challengeRecognisedStateId: challengeStateId,
                challengedRecognisedStateId: stateId,
                roleKey: SecondaryTestAppTypes.ROLE_SUBMITTER,
                reasonHash: keccak256("m146-secondary-challenge"),
                reasonURI: "ipfs://m146-secondary-challenge"
            })
        );
        secondaryReviewerActor.screenChallenge(
            challengeExtension, challengeId, SecondaryTestAppTypes.ROLE_VERIFIER, SECONDARY_REVIEWER
        );
        secondaryPanelActor.resolveChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeResolutionInput({
                challengeId: challengeId,
                roleKey: SecondaryTestAppTypes.ROLE_PANEL,
                authorityId: SECONDARY_PANEL,
                outcome: AVAChallengeExtension.ChallengeOutcome.RejectedGoodFaith,
                correctionStatus: AVACoreTypes.RecognisedStateStatus.Challengeable,
                reasonHash: keccak256("m146-secondary-resolution"),
                reasonURI: "ipfs://m146-secondary-resolution"
            })
        );
        secondaryPanelActor.closeChallenge(
            challengeExtension,
            challengeId,
            SecondaryTestAppTypes.ROLE_PANEL,
            SECONDARY_PANEL,
            keccak256("m146-secondary-close")
        );
        _vestSecondaryState(stateId, "m146-secondary-post-challenge-vest");
        uint256 transitionBefore = kernel.getRecognisedState(stateId).lastTransitionId;
        uint256 allocationId = secondaryExecutorActor.recordAllocation(
            allocationExtension,
            AVAAllocationRecordExtension.AllocationInput({
                recognisedStateId: stateId,
                roleKey: SecondaryTestAppTypes.ROLE_PROTOCOL_EXECUTOR,
                authorityId: SECONDARY_EXECUTOR,
                subjectId: SECONDARY_CONTRIBUTOR,
                evidenceId: stateEvidenceId,
                allocationKindKey: keccak256("m146-bounded-service-allocation"),
                units: 1,
                reasonHash: keccak256("m146-bounded-service-allocation"),
                uri: "ipfs://m146-bounded-service-allocation"
            })
        );

        require(challengeId != 0 && allocationId != 0, "secondary extension records missing");
        require(
            allocationExtension.getAllocation(allocationId).packageId == secondaryPackageId,
            "secondary allocation package missing"
        );
        require(
            kernel.getRecognisedState(stateId).lastTransitionId == transitionBefore,
            "allocation record mutated recognised state"
        );
    }

    function testM146CrossApplicationObjectEvidenceChallengeAndDownstreamAttemptsFail() public {
        (uint256 peerStateId, uint256 peerEvidenceId) = _createPeerReviewState("m146-cross-peer");
        (uint256 secondaryStateId, uint256 secondaryEvidenceId) =
            _createSecondarySubmissionState("m146-cross-secondary", secondaryPackageId);
        _vestSecondaryState(secondaryStateId, "m146-cross-secondary-vest");

        AVAGovernanceKernel.GovernedObjectInput memory crossObject = _objectInput(
            SecondaryTestAppTypes.APP_ID,
            secondaryPackageId,
            SecondaryTestAppTypes.ROLE_SUBMITTER,
            SecondaryTestAppTypes.OBJECT_ROOT,
            SECONDARY_CONTRIBUTOR,
            peerEvidenceId,
            secondaryPolicyId,
            0,
            keccak256("m146-cross-object")
        );
        try secondaryContributorActor.registerObject(kernel, crossObject) {
            revert("secondary object consumed peer evidence");
        } catch {}

        try secondaryChallengerActor.fileChallenge(
            challengeExtension,
            AVAChallengeExtension.ChallengeFilingInput({
                appId: SecondaryTestAppTypes.APP_ID,
                workflowKey: SHARED_WORKFLOW,
                packageId: secondaryPackageId,
                challengeRecognisedStateId: peerStateId,
                challengedRecognisedStateId: peerStateId,
                roleKey: SecondaryTestAppTypes.ROLE_SUBMITTER,
                reasonHash: keccak256("m146-cross-challenge"),
                reasonURI: "ipfs://m146-cross-challenge"
            })
        ) {
            revert("secondary challenge consumed peer state");
        } catch {}

        AVAAllocationRecordExtension.AllocationInput memory crossAllocation =
            AVAAllocationRecordExtension.AllocationInput({
                recognisedStateId: secondaryStateId,
                roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                authorityId: PEER_EXECUTOR,
                subjectId: PEER_REVIEWER,
                evidenceId: peerEvidenceId,
                allocationKindKey: keccak256("m146-cross-allocation"),
                units: 1,
                reasonHash: keccak256("m146-cross-allocation"),
                uri: "ipfs://m146-cross-allocation"
            });
        try peerExecutorActor.recordAllocation(allocationExtension, crossAllocation) {
            revert("peer authority consumed secondary state");
        } catch {}
    }

    function testM146SecondaryPackageSupersessionDoesNotMovePeerPointerOrRewriteOldState() public {
        (uint256 oldSecondaryStateId,) = _createSecondarySubmissionState("m146-old-secondary", secondaryPackageId);
        uint256 peerPointerBefore = corePackageRegistry.getActivePackageId(PeerReviewTypes.APP_ID, SHARED_WORKFLOW);
        uint256 replacementPackageId = corePackageRegistry.supersedeRulePackage(
            _corePackageInput(
                SecondaryTestAppTypes.APP_ID,
                SHARED_WORKFLOW,
                PACKAGE_ROLE,
                SECONDARY_PACKAGE_SUBJECT,
                2,
                PACKAGE_COMPATIBILITY,
                "ipfs://m146-secondary-package-v2"
            ),
            secondaryPackageId,
            _coreBindings(secondaryModule)
        );
        kernel.bindSourceBoundTransitionRequester(replacementPackageId, address(challengeExtension));
        kernel.bindTransitionGuard(replacementPackageId, address(challengeExtension));
        require(
            corePackageRegistry.getActivePackageId(PeerReviewTypes.APP_ID, SHARED_WORKFLOW) == peerPointerBefore,
            "secondary supersession moved peer pointer"
        );
        require(
            kernel.getRecognisedState(oldSecondaryStateId).packageId == secondaryPackageId,
            "secondary supersession rewrote old state"
        );
        AVAApplicationConformance.assertHistoricalStateBinding(
            kernel, oldSecondaryStateId, SecondaryTestAppTypes.APP_ID, SHARED_WORKFLOW, secondaryPackageId
        );
        _vestSecondaryState(oldSecondaryStateId, "m146-old-secondary-historical-package-vest");
        require(
            kernel.getRecognisedState(oldSecondaryStateId).status == AVACoreTypes.RecognisedStateStatus.Vested,
            "old secondary state stopped dispatching through historical package"
        );

        (uint256 newSecondaryStateId, uint256 newStateEvidenceId) =
            _createSecondarySubmissionState("m146-new-secondary", replacementPackageId);
        AVACoreTypes.EvidenceRecord memory evidence = evidenceRegistryV2.getEvidence(newStateEvidenceId);
        require(evidence.packageId == replacementPackageId, "new secondary evidence did not use replacement package");
        require(
            kernel.getRecognisedState(newSecondaryStateId).packageId == replacementPackageId,
            "new secondary state did not use replacement package"
        );
        AVAApplicationConformance.assertHistoricalStateBinding(
            kernel, newSecondaryStateId, SecondaryTestAppTypes.APP_ID, SHARED_WORKFLOW, replacementPackageId
        );
    }

    function testApplicationConformanceKitRejectsCrossApplicationPackageUse() public {
        bytes memory crossApplicationEvidenceCall = abi.encodeCall(
            M14MultiAppActor.registerEvidence,
            (
                evidenceRegistryV2,
                SecondaryTestAppTypes.APP_ID,
                SHARED_WORKFLOW,
                peerPackageId,
                SecondaryTestAppTypes.ROLE_SUBMITTER,
                SECONDARY_CONTRIBUTOR,
                keccak256("conformance-cross-application-evidence"),
                secondaryPolicyId
            )
        );
        AVAApplicationConformance.assertRejectedCall(address(secondaryContributorActor), crossApplicationEvidenceCall);
    }

    function testM146SecondaryModuleRejectsPeerVocabularyAndInvalidChildParent() public {
        uint256 rootId = _registerSecondaryRoot("m146-secondary-module-root", secondaryPackageId);
        uint256 childEvidenceId = _registerEvidence(
            secondaryContributorActor,
            SecondaryTestAppTypes.APP_ID,
            secondaryPackageId,
            SecondaryTestAppTypes.ROLE_SUBMITTER,
            SECONDARY_CONTRIBUTOR,
            secondaryPolicyId,
            keccak256("m146-child-evidence")
        );
        uint256 childId = secondaryContributorActor.registerObject(
            kernel,
            _secondaryObjectInput(
                secondaryPackageId, SecondaryTestAppTypes.OBJECT_CHILD, childEvidenceId, rootId, keccak256("m146-child")
            )
        );
        uint256 nestedEvidenceId = _registerEvidence(
            secondaryContributorActor,
            SecondaryTestAppTypes.APP_ID,
            secondaryPackageId,
            SecondaryTestAppTypes.ROLE_SUBMITTER,
            SECONDARY_CONTRIBUTOR,
            secondaryPolicyId,
            keccak256("m146-nested-child-evidence")
        );
        try secondaryContributorActor.registerObject(
            kernel,
            _secondaryObjectInput(
                secondaryPackageId,
                SecondaryTestAppTypes.OBJECT_CHILD,
                nestedEvidenceId,
                childId,
                keccak256("m146-nested-child")
            )
        ) {
            revert("child accepted child parent");
        } catch {}

        uint256 peerVocabularyEvidenceId = _registerEvidence(
            secondaryContributorActor,
            SecondaryTestAppTypes.APP_ID,
            secondaryPackageId,
            SecondaryTestAppTypes.ROLE_SUBMITTER,
            SECONDARY_CONTRIBUTOR,
            secondaryPolicyId,
            keccak256("m146-peer-vocabulary-evidence")
        );
        try secondaryContributorActor.registerObject(
            kernel,
            _secondaryObjectInput(
                secondaryPackageId,
                PeerReviewTypes.OBJECT_MANUSCRIPT,
                peerVocabularyEvidenceId,
                0,
                keccak256("m146-peer-vocabulary-object")
            )
        ) {
            revert("secondary module accepted peer-review object vocabulary");
        } catch {}
    }

    function testM146SecondaryTestAppCannotVestBeforeChallengeableState() public {
        uint256 rootId = _registerSecondaryRoot("m146-premature-secondary-vest", secondaryPackageId);
        (uint256 submissionId,) =
            _registerSecondarySubmission("m146-premature-secondary-vest", secondaryPackageId, rootId);
        uint256 stateId = secondaryReviewerActor.formState(
            kernel,
            AVAGovernanceKernel.RecognisedStateFormationInput({
                governedObjectId: submissionId,
                roleKey: SecondaryTestAppTypes.ROLE_VERIFIER,
                authorityId: SECONDARY_REVIEWER,
                stage: AVACoreTypes.Stage.Verification,
                status: AVACoreTypes.RecognisedStateStatus.Provisional,
                reasonHash: keccak256("m146-premature-secondary-vest-formation"),
                reasonURI: "ipfs://m146-premature-secondary-vest-formation"
            })
        );
        uint256 nextTransitionIdBefore = kernel.nextTransitionId();
        try secondaryPanelActor.vestState(
            kernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: SecondaryTestAppTypes.ROLE_PANEL,
                authorityId: SECONDARY_PANEL,
                toStatus: AVACoreTypes.RecognisedStateStatus.Vested,
                reasonHash: keccak256("m146-premature-secondary-vest"),
                reasonURI: "ipfs://m146-premature-secondary-vest"
            })
        ) {
            revert("secondary submission vested before challengeable state");
        } catch {}
        require(kernel.nextTransitionId() == nextTransitionIdBefore, "premature secondary vest wrote transition");
    }

    function testM146ApplicationModulesRouteOptionalExtensionActionsToExplicitRoles() public view {
        peerModule.validateDownstreamRecord(
            _downstreamContext(
                PeerReviewTypes.APP_ID,
                PeerReviewTypes.OBJECT_REVIEW_CONTRIBUTION,
                PeerReviewTypes.ROLE_REVIEWER,
                AVACoreTypes.ACTION_RECORD_PRIVACY_PROOF
            )
        );
        peerModule.validateDownstreamRecord(
            _downstreamContext(
                PeerReviewTypes.APP_ID,
                PeerReviewTypes.OBJECT_REVIEW_CONTRIBUTION,
                PeerReviewTypes.ROLE_PANEL,
                AVACoreTypes.ACTION_RECORD_AUDIT_RECEIPT
            )
        );
        peerModule.validateDownstreamRecord(
            _downstreamContext(
                PeerReviewTypes.APP_ID,
                PeerReviewTypes.OBJECT_REVIEW_CONTRIBUTION,
                PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                AVACoreTypes.ACTION_RECORD_SETTLEMENT_RECEIPT
            )
        );
        secondaryModule.validateDownstreamRecord(
            _downstreamContext(
                SecondaryTestAppTypes.APP_ID,
                SecondaryTestAppTypes.OBJECT_SUBMISSION,
                SecondaryTestAppTypes.ROLE_SUBMITTER,
                AVACoreTypes.ACTION_RECORD_DISCLOSURE_RECEIPT
            )
        );
        secondaryModule.validateDownstreamRecord(
            _downstreamContext(
                SecondaryTestAppTypes.APP_ID,
                SecondaryTestAppTypes.OBJECT_SUBMISSION,
                SecondaryTestAppTypes.ROLE_PANEL,
                AVACoreTypes.ACTION_RECORD_AUDIT_RECEIPT
            )
        );
        secondaryModule.validateDownstreamRecord(
            _downstreamContext(
                SecondaryTestAppTypes.APP_ID,
                SecondaryTestAppTypes.OBJECT_SUBMISSION,
                SecondaryTestAppTypes.ROLE_PROTOCOL_EXECUTOR,
                AVACoreTypes.ACTION_RECORD_EXTERNAL_OPERATION
            )
        );
    }

    function testM146ApplicationModulesRejectWrongRolesForOptionalExtensionActions() public {
        try peerModule.validateDownstreamRecord(
            _downstreamContext(
                PeerReviewTypes.APP_ID,
                PeerReviewTypes.OBJECT_REVIEW_CONTRIBUTION,
                PeerReviewTypes.ROLE_AUTHOR,
                AVACoreTypes.ACTION_RECORD_PRIVACY_PROOF
            )
        ) {
            revert("peer author routed to privacy proof");
        } catch {}
        try peerModule.validateDownstreamRecord(
            _downstreamContext(
                PeerReviewTypes.APP_ID,
                PeerReviewTypes.OBJECT_REVIEW_CONTRIBUTION,
                PeerReviewTypes.ROLE_PANEL,
                AVACoreTypes.ACTION_RECORD_SETTLEMENT_RECEIPT
            )
        ) {
            revert("peer panel routed to settlement receipt");
        } catch {}
        try secondaryModule.validateDownstreamRecord(
            _downstreamContext(
                SecondaryTestAppTypes.APP_ID,
                SecondaryTestAppTypes.OBJECT_SUBMISSION,
                SecondaryTestAppTypes.ROLE_VERIFIER,
                AVACoreTypes.ACTION_RECORD_DISCLOSURE_RECEIPT
            )
        ) {
            revert("secondary reviewer routed to disclosure receipt");
        } catch {}
    }

    function _downstreamContext(bytes32 appId, bytes32 objectTypeKey, bytes32 roleKey, bytes32 actionKey)
        internal
        pure
        returns (IAVAApplicationModule.DownstreamRecordContext memory context)
    {
        context = IAVAApplicationModule.DownstreamRecordContext({
            appId: appId,
            workflowKey: SHARED_WORKFLOW,
            packageId: 1,
            actionKey: actionKey,
            roleKey: roleKey,
            recognisedStateId: 1,
            governedObjectId: 1,
            objectTypeKey: objectTypeKey,
            subjectId: bytes32(uint256(1)),
            evidenceReceiptId: 1,
            recordTypeKey: keccak256("m14-optional-extension-record"),
            authorityId: bytes32(uint256(2)),
            actor: address(1)
        });
    }

    function _deployActorsAndSubjects() internal {
        peerAuthorActor = new M14MultiAppActor();
        peerReviewerActor = new M14MultiAppActor();
        peerEditorActor = new M14MultiAppActor();
        peerPanelActor = new M14MultiAppActor();
        peerExecutorActor = new M14MultiAppActor();
        secondaryContributorActor = new M14MultiAppActor();
        secondaryChallengerActor = new M14MultiAppActor();
        secondaryReviewerActor = new M14MultiAppActor();
        secondaryPanelActor = new M14MultiAppActor();
        secondaryExecutorActor = new M14MultiAppActor();

        _assign(peerAuthorActor, PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_AUTHOR, PEER_AUTHOR);
        _assign(peerReviewerActor, PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_REVIEWER, PEER_REVIEWER);
        _assign(peerEditorActor, PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_EDITOR, PEER_EDITOR);
        _assign(peerPanelActor, PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PANEL, PEER_PANEL);
        _assign(peerExecutorActor, PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR, PEER_EXECUTOR);
        _assign(
            secondaryContributorActor,
            SecondaryTestAppTypes.APP_ID,
            SecondaryTestAppTypes.ROLE_SUBMITTER,
            SECONDARY_CONTRIBUTOR
        );
        _assign(
            secondaryChallengerActor,
            SecondaryTestAppTypes.APP_ID,
            SecondaryTestAppTypes.ROLE_SUBMITTER,
            SECONDARY_CHALLENGER
        );
        _assign(
            secondaryReviewerActor,
            SecondaryTestAppTypes.APP_ID,
            SecondaryTestAppTypes.ROLE_VERIFIER,
            SECONDARY_REVIEWER
        );
        _assign(secondaryPanelActor, SecondaryTestAppTypes.APP_ID, SecondaryTestAppTypes.ROLE_PANEL, SECONDARY_PANEL);
        _assign(
            secondaryExecutorActor,
            SecondaryTestAppTypes.APP_ID,
            SecondaryTestAppTypes.ROLE_PROTOCOL_EXECUTOR,
            SECONDARY_EXECUTOR
        );
    }

    function _assign(M14MultiAppActor actor, bytes32 appId, bytes32 roleKey, bytes32 subjectId) internal {
        identityRegistryV2.assignSubject(address(actor), appId, roleKey, subjectId, "ipfs://m14-subject");
    }

    function _grantPermissions() internal {
        _permit(PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_AUTHOR, AVACoreTypes.ACTION_REGISTER_GOVERNED_OBJECT);
        _permit(PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_AUTHOR, AVACoreTypes.ACTION_REGISTER_EVIDENCE);
        _permit(PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_REVIEWER, AVACoreTypes.ACTION_REGISTER_GOVERNED_OBJECT);
        _permit(PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_REVIEWER, AVACoreTypes.ACTION_REGISTER_EVIDENCE);
        _permit(PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_EDITOR, AVACoreTypes.ACTION_REGISTER_DISCLOSURE_POLICY);
        _permit(PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_EDITOR, AVACoreTypes.ACTION_FORM_RECOGNISED_STATE);
        _permit(PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_EDITOR, AVACoreTypes.ACTION_TRANSITION_RECOGNISED_STATE);
        _permit(PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_VEST_RECOGNISED_STATE);

        _permit(
            SecondaryTestAppTypes.APP_ID,
            SecondaryTestAppTypes.ROLE_SUBMITTER,
            AVACoreTypes.ACTION_REGISTER_GOVERNED_OBJECT
        );
        _permit(
            SecondaryTestAppTypes.APP_ID, SecondaryTestAppTypes.ROLE_SUBMITTER, AVACoreTypes.ACTION_REGISTER_EVIDENCE
        );
        _permit(SecondaryTestAppTypes.APP_ID, SecondaryTestAppTypes.ROLE_SUBMITTER, AVACoreTypes.ACTION_FILE_CHALLENGE);
        _permit(
            SecondaryTestAppTypes.APP_ID,
            SecondaryTestAppTypes.ROLE_SUBMITTER,
            AVACoreTypes.ACTION_FORM_RECOGNISED_STATE
        );
        _permit(
            SecondaryTestAppTypes.APP_ID,
            SecondaryTestAppTypes.ROLE_VERIFIER,
            AVACoreTypes.ACTION_REGISTER_DISCLOSURE_POLICY
        );
        _permit(
            SecondaryTestAppTypes.APP_ID, SecondaryTestAppTypes.ROLE_VERIFIER, AVACoreTypes.ACTION_FORM_RECOGNISED_STATE
        );
        _permit(
            SecondaryTestAppTypes.APP_ID,
            SecondaryTestAppTypes.ROLE_VERIFIER,
            AVACoreTypes.ACTION_TRANSITION_RECOGNISED_STATE
        );
        _permit(SecondaryTestAppTypes.APP_ID, SecondaryTestAppTypes.ROLE_VERIFIER, AVACoreTypes.ACTION_SCREEN_CHALLENGE);
        _permit(SecondaryTestAppTypes.APP_ID, SecondaryTestAppTypes.ROLE_PANEL, AVACoreTypes.ACTION_RESOLVE_CHALLENGE);
        _permit(SecondaryTestAppTypes.APP_ID, SecondaryTestAppTypes.ROLE_PANEL, AVACoreTypes.ACTION_CLOSE_CHALLENGE);
        _permit(
            SecondaryTestAppTypes.APP_ID, SecondaryTestAppTypes.ROLE_PANEL, AVACoreTypes.ACTION_VEST_RECOGNISED_STATE
        );
        _permit(
            SecondaryTestAppTypes.APP_ID,
            SecondaryTestAppTypes.ROLE_PROTOCOL_EXECUTOR,
            AVACoreTypes.ACTION_RECORD_ALLOCATION
        );
    }

    function _permit(bytes32 appId, bytes32 roleKey, bytes32 actionKey) internal {
        authorityMatrixV2.setPermission(appId, roleKey, actionKey, true);
    }

    function _createPeerReviewState(string memory seed) internal returns (uint256 stateId, uint256 reviewEvidenceId) {
        uint256 manuscriptId = _registerPeerManuscript(seed);
        uint256 reviewId;
        (reviewId, reviewEvidenceId) = _registerPeerReview(seed, manuscriptId);
        stateId = _formAndChallengeable(peerEditorActor, reviewId, PeerReviewTypes.ROLE_EDITOR, PEER_EDITOR, seed);
    }

    function _registerPeerManuscript(string memory seed) internal returns (uint256 manuscriptId) {
        uint256 manuscriptEvidenceId = _registerEvidence(
            peerAuthorActor,
            PeerReviewTypes.APP_ID,
            peerPackageId,
            PeerReviewTypes.ROLE_AUTHOR,
            PEER_AUTHOR,
            peerPolicyId,
            keccak256(abi.encode(seed, "manuscript-evidence"))
        );
        manuscriptId = peerAuthorActor.registerObject(
            kernel,
            _peerObjectInput(
                PeerReviewTypes.ROLE_AUTHOR,
                PeerReviewTypes.OBJECT_MANUSCRIPT,
                PEER_AUTHOR,
                manuscriptEvidenceId,
                0,
                keccak256(abi.encode(seed, "manuscript"))
            )
        );
    }

    function _registerPeerReview(string memory seed, uint256 manuscriptId)
        internal
        returns (uint256 reviewId, uint256 reviewEvidenceId)
    {
        reviewEvidenceId = _registerEvidence(
            peerReviewerActor,
            PeerReviewTypes.APP_ID,
            peerPackageId,
            PeerReviewTypes.ROLE_REVIEWER,
            PEER_REVIEWER,
            peerPolicyId,
            keccak256(abi.encode(seed, "review-evidence"))
        );
        reviewId = peerReviewerActor.registerObject(
            kernel,
            _peerObjectInput(
                PeerReviewTypes.ROLE_REVIEWER,
                PeerReviewTypes.OBJECT_REVIEW_CONTRIBUTION,
                PEER_REVIEWER,
                reviewEvidenceId,
                manuscriptId,
                keccak256(abi.encode(seed, "review"))
            )
        );
    }

    function _createSecondarySubmissionState(string memory seed, uint256 packageId)
        internal
        returns (uint256 stateId, uint256 submissionEvidenceId)
    {
        uint256 rootId = _registerSecondaryRoot(seed, packageId);
        uint256 submissionId;
        (submissionId, submissionEvidenceId) = _registerSecondarySubmission(seed, packageId, rootId);
        stateId = _formAndChallengeable(
            secondaryReviewerActor, submissionId, SecondaryTestAppTypes.ROLE_VERIFIER, SECONDARY_REVIEWER, seed
        );
    }

    function _createSecondaryChallengeState(uint256 targetStateId, uint256 evidenceId, string memory seed)
        internal
        returns (uint256 challengeStateId)
    {
        AVACoreTypes.RecognisedStateRecord memory target = kernel.getRecognisedState(targetStateId);
        AVAGovernanceKernel.GovernedObjectInput memory objectInput;
        objectInput.appId = SecondaryTestAppTypes.APP_ID;
        objectInput.workflowKey = SHARED_WORKFLOW;
        objectInput.packageId = secondaryPackageId;
        objectInput.roleKey = SecondaryTestAppTypes.ROLE_SUBMITTER;
        objectInput.objectTypeKey = SecondaryTestAppTypes.OBJECT_CHALLENGE;
        objectInput.objectCommitment = keccak256(abi.encode("m146-secondary-challenge-object", targetStateId, seed));
        objectInput.parentObjectId = target.governedObjectId;
        objectInput.subjectId = SECONDARY_CHALLENGER;
        objectInput.evidenceReceiptId = evidenceId;
        objectInput.disclosurePolicyId = secondaryPolicyId;
        objectInput.metadataHash = keccak256(abi.encode("m146-secondary-challenge-metadata", seed));
        objectInput.authorityId = SECONDARY_CHALLENGER;
        objectInput.uri = "ipfs://m146-secondary-challenge-object";
        uint256 challengeObjectId = secondaryChallengerActor.registerObject(kernel, objectInput);
        challengeStateId = secondaryChallengerActor.formState(
            kernel,
            AVAGovernanceKernel.RecognisedStateFormationInput({
                governedObjectId: challengeObjectId,
                roleKey: SecondaryTestAppTypes.ROLE_SUBMITTER,
                authorityId: SECONDARY_CHALLENGER,
                stage: AVACoreTypes.Stage.Verification,
                status: AVACoreTypes.RecognisedStateStatus.Registered,
                reasonHash: keccak256(abi.encode("m146-secondary-challenge-formation", seed)),
                reasonURI: "ipfs://m146-secondary-challenge-formation"
            })
        );
    }

    function _registerSecondaryRoot(string memory seed, uint256 packageId) internal returns (uint256 rootId) {
        uint256 rootEvidenceId = _registerEvidence(
            secondaryContributorActor,
            SecondaryTestAppTypes.APP_ID,
            packageId,
            SecondaryTestAppTypes.ROLE_SUBMITTER,
            SECONDARY_CONTRIBUTOR,
            secondaryPolicyId,
            keccak256(abi.encode(seed, "root-evidence"))
        );
        rootId = secondaryContributorActor.registerObject(
            kernel,
            _secondaryObjectInput(
                packageId, SecondaryTestAppTypes.OBJECT_ROOT, rootEvidenceId, 0, keccak256(abi.encode(seed, "root"))
            )
        );
    }

    function _registerSecondarySubmission(string memory seed, uint256 packageId, uint256 rootId)
        internal
        returns (uint256 submissionId, uint256 submissionEvidenceId)
    {
        submissionEvidenceId = _registerEvidence(
            secondaryContributorActor,
            SecondaryTestAppTypes.APP_ID,
            packageId,
            SecondaryTestAppTypes.ROLE_SUBMITTER,
            SECONDARY_CONTRIBUTOR,
            secondaryPolicyId,
            keccak256(abi.encode(seed, "submission-evidence"))
        );
        submissionId = secondaryContributorActor.registerObject(
            kernel,
            _secondaryObjectInput(
                packageId,
                SecondaryTestAppTypes.OBJECT_SUBMISSION,
                submissionEvidenceId,
                rootId,
                keccak256(abi.encode(seed, "submission"))
            )
        );
    }

    function _formAndChallengeable(
        M14MultiAppActor actor,
        uint256 objectId,
        bytes32 roleKey,
        bytes32 authorityId,
        string memory seed
    ) internal returns (uint256 stateId) {
        stateId = actor.formState(
            kernel,
            AVAGovernanceKernel.RecognisedStateFormationInput({
                governedObjectId: objectId,
                roleKey: roleKey,
                authorityId: authorityId,
                stage: AVACoreTypes.Stage.Verification,
                status: AVACoreTypes.RecognisedStateStatus.Provisional,
                reasonHash: keccak256(abi.encode(seed, "provisional")),
                reasonURI: "ipfs://m14-provisional"
            })
        );
        actor.transitionState(
            kernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: roleKey,
                authorityId: authorityId,
                toStatus: AVACoreTypes.RecognisedStateStatus.Challengeable,
                reasonHash: keccak256(abi.encode(seed, "challengeable")),
                reasonURI: "ipfs://m14-challengeable"
            })
        );
    }

    function _vestPeerState(uint256 stateId, string memory seed) internal {
        _vest(peerPanelActor, stateId, PeerReviewTypes.ROLE_PANEL, PEER_PANEL, seed);
    }

    function _vestSecondaryState(uint256 stateId, string memory seed) internal {
        _vest(secondaryPanelActor, stateId, SecondaryTestAppTypes.ROLE_PANEL, SECONDARY_PANEL, seed);
    }

    function _vest(M14MultiAppActor actor, uint256 stateId, bytes32 roleKey, bytes32 authorityId, string memory seed)
        internal
    {
        actor.vestState(
            kernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: roleKey,
                authorityId: authorityId,
                toStatus: AVACoreTypes.RecognisedStateStatus.Vested,
                reasonHash: keccak256(bytes(seed)),
                reasonURI: "ipfs://m14-vest"
            })
        );
    }

    function _registerEvidence(
        M14MultiAppActor actor,
        bytes32 appId,
        uint256 packageId,
        bytes32 roleKey,
        bytes32 subjectId,
        uint256 policyId,
        bytes32 commitment
    ) internal returns (uint256) {
        return actor.registerEvidence(
            evidenceRegistryV2, appId, SHARED_WORKFLOW, packageId, roleKey, subjectId, commitment, policyId
        );
    }

    function _objectInput(
        bytes32 appId,
        uint256 packageId,
        bytes32 roleKey,
        bytes32 objectTypeKey,
        bytes32 subjectId,
        uint256 evidenceId,
        uint256 policyId,
        uint256 parentObjectId,
        bytes32 objectCommitment
    ) internal pure returns (AVAGovernanceKernel.GovernedObjectInput memory) {
        return AVAGovernanceKernel.GovernedObjectInput({
            appId: appId,
            workflowKey: SHARED_WORKFLOW,
            packageId: packageId,
            roleKey: roleKey,
            objectTypeKey: objectTypeKey,
            objectCommitment: objectCommitment,
            parentObjectId: parentObjectId,
            subjectId: subjectId,
            evidenceReceiptId: evidenceId,
            disclosurePolicyId: policyId,
            metadataHash: keccak256(abi.encode(appId, objectTypeKey, objectCommitment)),
            authorityId: subjectId,
            uri: "ipfs://m14-multi-app-object"
        });
    }

    function _peerObjectInput(
        bytes32 roleKey,
        bytes32 objectTypeKey,
        bytes32 subjectId,
        uint256 evidenceId,
        uint256 parentObjectId,
        bytes32 objectCommitment
    ) internal view returns (AVAGovernanceKernel.GovernedObjectInput memory) {
        return _objectInput(
            PeerReviewTypes.APP_ID,
            peerPackageId,
            roleKey,
            objectTypeKey,
            subjectId,
            evidenceId,
            peerPolicyId,
            parentObjectId,
            objectCommitment
        );
    }

    function _secondaryObjectInput(
        uint256 packageId,
        bytes32 objectTypeKey,
        uint256 evidenceId,
        uint256 parentObjectId,
        bytes32 objectCommitment
    ) internal view returns (AVAGovernanceKernel.GovernedObjectInput memory) {
        return _objectInput(
            SecondaryTestAppTypes.APP_ID,
            packageId,
            SecondaryTestAppTypes.ROLE_SUBMITTER,
            objectTypeKey,
            SECONDARY_CONTRIBUTOR,
            evidenceId,
            secondaryPolicyId,
            parentObjectId,
            objectCommitment
        );
    }
}
