// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVAApplicationRegistry} from "../src/AVAApplicationRegistry.sol";
import {DefaultApplicationModule} from "../src/modules/DefaultApplicationModule.sol";
import {AVARulePackageRegistry} from "../src/AVARulePackageRegistry.sol";
import {AVADataTypes} from "../src/AVADataTypes.sol";
import "./helpers/AVASkeletonFixture.sol";

contract M14ApplicationNamespaceTest {
    function testM142AdminRegistersImmutableApplicationNamespace() public {
        AVAApplicationRegistry registry = new AVAApplicationRegistry();
        bytes32 appId = keccak256("peer-review-app");
        bytes32 identityHash = keccak256("peer-review-application-identity-v1");
        bytes32 authorityId = keccak256("peer-review-application-authority");

        registry.registerApplication(appId, identityHash, authorityId, "ipfs://peer-review-application");

        AVAApplicationRegistry.ApplicationRecord memory record = registry.getApplication(appId);
        require(record.appId == appId, "application id missing");
        require(record.applicationIdentityHash == identityHash, "application identity missing");
        require(record.authorityId == authorityId, "application authority missing");
        require(record.registeredBy == address(this), "application registrar missing");

        try registry.registerApplication(
            appId, keccak256("replacement-identity"), authorityId, "ipfs://replacement-application"
        ) {
            revert("application namespace was overwritten");
        } catch {}

        require(
            registry.getApplication(appId).applicationIdentityHash == identityHash,
            "application identity changed after duplicate registration"
        );
    }

    function testM142ApplicationModuleIdentityIsBoundToAppId() public {
        bytes32 peerReviewAppId = keccak256("peer-review-app");
        bytes32 secondaryAppId = keccak256("secondary-test-app-app");
        DefaultApplicationModule peerReviewModule = new DefaultApplicationModule(peerReviewAppId);
        DefaultApplicationModule secondaryModule = new DefaultApplicationModule(secondaryAppId);

        require(peerReviewModule.applicationId() == peerReviewAppId, "peer review app id missing");
        require(secondaryModule.applicationId() == secondaryAppId, "secondary test application app id missing");
        require(
            peerReviewModule.moduleIdentityHash() != secondaryModule.moduleIdentityHash(),
            "application module identity ignored app id"
        );
    }
}

contract M14RulePackageNamespaceTest is AVASkeletonFixture {
    function testM142SameWorkflowKeyIsIsolatedByApplication() public {
        bytes32 secondaryAppId = keccak256("secondary-test-app-app");
        applicationRegistry.registerApplication(
            secondaryAppId,
            keccak256("secondary-test-app-application-identity-v1"),
            keccak256("secondary-test-app-application-authority"),
            "ipfs://secondary-test-app-application"
        );

        AVARulePackageRegistry.RulePackageModules memory modules = _defaultRulePackageModules();
        modules.applicationModule = new DefaultApplicationModule(secondaryAppId);
        uint256 secondaryPackageId = rulePackageRegistry.registerRulePackage(
            AVADataTypes.Role.Panel,
            secondaryAppId,
            DEFAULT_WORKFLOW,
            modules,
            "ipfs://secondary-test-app-default-workflow"
        );

        uint256 peerReviewPackageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW).packageId;
        require(peerReviewPackageId != secondaryPackageId, "applications shared package identity");
        require(
            rulePackageRegistry.getActivePackageId(PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW) == peerReviewPackageId,
            "peer review active package changed"
        );
        require(
            rulePackageRegistry.getActivePackageId(secondaryAppId, DEFAULT_WORKFLOW) == secondaryPackageId,
            "secondary test application active package missing"
        );
    }

    function testM142ApplicationModuleCannotBeReusedAcrossApplicationNamespaces() public {
        bytes32 secondaryAppId = _registerSecondaryApplication("module-mismatch");
        AVARulePackageRegistry.RulePackageModules memory modules = _defaultRulePackageModules();
        uint256 nextPackageId = rulePackageRegistry.nextRulePackageId();

        try rulePackageRegistry.registerRulePackage(
            AVADataTypes.Role.Panel,
            secondaryAppId,
            keccak256("secondary-module-mismatch-workflow"),
            modules,
            "ipfs://secondary-module-mismatch"
        ) {
            revert("peer application module registered for secondary app");
        } catch {}

        require(rulePackageRegistry.nextRulePackageId() == nextPackageId, "module mismatch wrote package");
    }

    function testM142PeerPackageSupersessionDoesNotMoveSecondaryPointerOrRewriteHistory() public {
        bytes32 secondaryAppId = _registerSecondaryApplication("historical-isolation");
        AVARulePackageRegistry.RulePackageModules memory secondaryModules = _defaultRulePackageModules();
        secondaryModules.applicationModule = new DefaultApplicationModule(secondaryAppId);
        uint256 secondaryPackageId = rulePackageRegistry.registerRulePackage(
            AVADataTypes.Role.Panel,
            secondaryAppId,
            DEFAULT_WORKFLOW,
            secondaryModules,
            "ipfs://secondary-historical-isolation"
        );
        uint256 oldPeerPackageId = rulePackageRegistry.getActivePackageId(PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW);

        AVARulePackageRegistry.RulePackageModules memory peerModules = _defaultRulePackageModules();
        peerModules.version = 2;
        uint256 newPeerPackageId = rulePackageRegistry.supersedeRulePackage(
            AVADataTypes.Role.Panel,
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            oldPeerPackageId,
            peerModules,
            "ipfs://peer-review-v2"
        );

        require(newPeerPackageId != oldPeerPackageId, "peer package did not advance");
        require(
            rulePackageRegistry.getActivePackageId(secondaryAppId, DEFAULT_WORKFLOW) == secondaryPackageId,
            "peer supersession moved secondary pointer"
        );
        require(
            rulePackageRegistry.getRulePackageById(oldPeerPackageId).appId == PEER_REVIEW_APP_ID,
            "old peer package history changed"
        );
        require(
            rulePackageRegistry.getActivePackageId(PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW) == newPeerPackageId,
            "peer active pointer did not advance"
        );
    }

    function _registerSecondaryApplication(string memory seed) internal returns (bytes32 appId) {
        appId = keccak256(abi.encode("secondary-test-app-app", seed));
        applicationRegistry.registerApplication(
            appId,
            keccak256(abi.encode("secondary-test-app-application-identity-v1", seed)),
            keccak256(abi.encode("secondary-test-app-application-authority", seed)),
            string.concat("ipfs://secondary-test-app-", seed)
        );
    }
}

contract M14ApplicationIsolationTest is AVASkeletonFixture {
    bytes32 private constant SECONDARY_APP_ID = keccak256("secondary-test-app-app");
    bytes32 private constant SECONDARY_REVIEWER_SUBJECT = keccak256("secondary-test-app-reviewer-subject");
    bytes32 private constant SECONDARY_CHALLENGER_SUBJECT = keccak256("secondary-test-app-challenger-subject");

    Actor private secondaryReviewer;
    Actor private secondaryChallenger;

    function setUp() public override {
        super.setUp();
        applicationRegistry.registerApplication(
            SECONDARY_APP_ID,
            keccak256("secondary-test-app-application-identity-v1"),
            keccak256("secondary-test-app-application-authority"),
            "ipfs://secondary-test-app-application"
        );
        AVARulePackageRegistry.RulePackageModules memory modules = _defaultRulePackageModules();
        modules.applicationModule = new DefaultApplicationModule(SECONDARY_APP_ID);
        rulePackageRegistry.registerRulePackage(
            AVADataTypes.Role.Panel,
            SECONDARY_APP_ID,
            DEFAULT_WORKFLOW,
            modules,
            "ipfs://secondary-test-app-default-workflow"
        );

        secondaryReviewer = new Actor();
        secondaryChallenger = new Actor();
        roleRegistry.assignRole(
            address(secondaryReviewer),
            AVADataTypes.Role.Reviewer,
            SECONDARY_REVIEWER_SUBJECT,
            "ipfs://secondary-test-app-reviewer"
        );
        roleRegistry.assignRole(
            address(secondaryChallenger),
            AVADataTypes.Role.Challenger,
            SECONDARY_CHALLENGER_SUBJECT,
            "ipfs://secondary-test-app-challenger"
        );
    }

    function testM142UnknownApplicationCannotRegisterRulePackage() public {
        bytes32 unknownAppId = keccak256("unknown-app");
        AVARulePackageRegistry.RulePackageModules memory modules = _defaultRulePackageModules();
        modules.applicationModule = new DefaultApplicationModule(unknownAppId);
        uint256 nextPackageId = rulePackageRegistry.nextRulePackageId();

        try rulePackageRegistry.registerRulePackage(
            AVADataTypes.Role.Panel,
            unknownAppId,
            keccak256("unknown-app-workflow"),
            modules,
            "ipfs://unknown-app-workflow"
        ) {
            revert("unknown application registered package");
        } catch {}

        require(rulePackageRegistry.nextRulePackageId() == nextPackageId, "unknown app wrote package");
    }

    function testM142EvidencePolicyAndRecognisedStateRejectCrossApplicationReferences() public {
        uint256 peerPolicyId = _registerDisclosurePolicy("m142-peer-policy");
        uint256 secondaryPolicyId = _registerSecondaryPolicy("m142-secondary-policy");
        uint256 peerEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("m142-peer-evidence"),
            "ipfs://m142-peer-evidence",
            "m142-evidence",
            peerPolicyId
        );
        uint256 secondaryEvidenceId = _registerSecondaryEvidence(secondaryPolicyId, "m142-secondary-evidence");

        try secondaryReviewer.registerEvidenceReceiptForApplication(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            SECONDARY_APP_ID,
            DEFAULT_WORKFLOW,
            keccak256("m142-secondary-with-peer-policy"),
            "ipfs://m142-secondary-with-peer-policy",
            "m142-evidence",
            peerPolicyId
        ) {
            revert("cross-application disclosure policy accepted");
        } catch {}

        _assertRecognisedStateRejectsApplicationEvidence(
            PEER_REVIEW_APP_ID, secondaryEvidenceId, peerPolicyId, "peer state accepted secondary evidence"
        );
        _assertRecognisedStateRejectsApplicationEvidence(
            SECONDARY_APP_ID, peerEvidenceId, secondaryPolicyId, "secondary state accepted peer evidence"
        );

        uint256 secondaryStateId =
            _registerSecondaryState(secondaryEvidenceId, secondaryPolicyId, "m142-valid-secondary-state");
        AVADataTypes.RecognisedStateRecord memory state = stateMachine.getRecognisedState(secondaryStateId);
        require(state.appId == SECONDARY_APP_ID, "recognised state app missing");
        require(
            rulePackageRegistry.getRulePackageById(state.packageId).appId == SECONDARY_APP_ID,
            "recognised state package crossed app"
        );
    }

    function testM142ChallengeCannotCrossApplicationBoundary() public {
        uint256 peerPolicyId = _registerDisclosurePolicy("m142-peer-challenge-policy");
        uint256 secondaryPolicyId = _registerSecondaryPolicy("m142-secondary-challenge-policy");
        uint256 secondaryEvidenceId = _registerSecondaryEvidence(secondaryPolicyId, "m142-secondary-target-evidence");
        uint256 secondaryStateId =
            _registerSecondaryVestedState(secondaryEvidenceId, secondaryPolicyId, "m142-secondary-challenge-target");
        uint256 peerChallengeEvidenceId = secondaryChallenger.registerEvidenceReceiptForApplication(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            keccak256("m142-peer-challenge-evidence"),
            "ipfs://m142-peer-challenge-evidence",
            "m142-challenge",
            peerPolicyId
        );

        try secondaryChallenger.fileChallengeForApplication(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            secondaryStateId,
            SECONDARY_CHALLENGER_SUBJECT,
            peerChallengeEvidenceId,
            peerPolicyId
        ) {
            revert("cross-application challenge accepted");
        } catch {}

        uint256 secondaryChallengeEvidenceId = secondaryChallenger.registerEvidenceReceiptForApplication(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            SECONDARY_APP_ID,
            DEFAULT_WORKFLOW,
            keccak256("m142-secondary-challenge-evidence"),
            "ipfs://m142-secondary-challenge-evidence",
            "m142-challenge",
            secondaryPolicyId
        );
        uint256 challengeId = secondaryChallenger.fileChallengeForApplication(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            SECONDARY_APP_ID,
            DEFAULT_WORKFLOW,
            secondaryStateId,
            SECONDARY_CHALLENGER_SUBJECT,
            secondaryChallengeEvidenceId,
            secondaryPolicyId
        );
        AVADataTypes.ChallengeRecord memory challenge = challengeWorkflow.getChallenge(challengeId);
        require(challenge.appId == SECONDARY_APP_ID, "challenge app missing");
        require(
            challenge.targetPackageId == stateMachine.getRecognisedState(secondaryStateId).packageId,
            "target package lost"
        );
    }

    function testM142DisclosureProofContextAndNullifierAreApplicationBound() public {
        uint256 peerPolicyId = _registerDisclosurePolicy("m142-peer-proof-policy");
        uint256 secondaryPolicyId = _registerSecondaryPolicy("m142-secondary-proof-policy");
        bytes32 objectId = keccak256("m142-shared-proof-object");
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        bytes32 peerContext = _disclosureProofContext(PEER_REVIEW_APP_ID, objectId, peerPolicyId, subjectCommitment);
        bytes32 secondaryContext =
            _disclosureProofContext(SECONDARY_APP_ID, objectId, secondaryPolicyId, subjectCommitment);
        require(peerContext != secondaryContext, "applications shared proof context");

        uint256 peerReceiptId =
            _registerApplicationBoundProof(PEER_REVIEW_APP_ID, objectId, peerPolicyId, subjectCommitment, 11);
        uint256 secondaryReceiptId =
            _registerApplicationBoundProof(SECONDARY_APP_ID, objectId, secondaryPolicyId, subjectCommitment, 13);

        ZKProofRegistry.ProofReceipt memory peerReceipt = zkProofRegistry.getProofReceipt(peerReceiptId);
        ZKProofRegistry.ProofReceipt memory secondaryReceipt = zkProofRegistry.getProofReceipt(secondaryReceiptId);
        require(peerReceipt.appId == PEER_REVIEW_APP_ID, "peer proof app missing");
        require(secondaryReceipt.appId == SECONDARY_APP_ID, "secondary proof app missing");
        require(peerReceipt.nullifierHash != secondaryReceipt.nullifierHash, "applications shared proof nullifier");

        _assertCrossApplicationProofPolicyRejected(objectId, peerPolicyId, subjectCommitment);
    }

    function testM142DownstreamAuditAndExternalOperationRemainPinnedToTargetApplication() public {
        uint256 peerPolicyId = _registerDisclosurePolicy("m142-peer-downstream-policy");
        uint256 secondaryPolicyId = _registerSecondaryPolicy("m142-secondary-downstream-policy");
        uint256 peerEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("m142-peer-downstream-evidence"),
            "ipfs://m142-peer-downstream-evidence",
            "m142-downstream",
            peerPolicyId
        );
        uint256 secondaryEvidenceId =
            _registerSecondaryEvidence(secondaryPolicyId, "m142-secondary-downstream-evidence");
        uint256 secondaryStateId =
            _registerSecondaryVestedState(secondaryEvidenceId, secondaryPolicyId, "m142-secondary-downstream-state");

        uint256 nextStandingId = standingRegistry.nextStandingUpdateId();
        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            secondaryStateId,
            EDITOR_AUTHORITY,
            "m142-procedural-weight",
            1,
            peerEvidenceId,
            keccak256("panel-authority"),
            "ipfs://m142-cross-app-standing"
        ) {
            revert("cross-application standing evidence accepted");
        } catch {}
        require(standingRegistry.nextStandingUpdateId() == nextStandingId, "cross-app standing wrote record");

        uint256 attestationId = auditModule.recordRecognisedStateAttestation(
            AVADataTypes.Role.Panel,
            secondaryStateId,
            keccak256("m142-secondary-attestation"),
            keccak256("panel-authority"),
            "m142-secondary-attestation",
            "ipfs://m142-secondary-attestation"
        );
        require(
            auditModule.getAttestation(attestationId).packageId
                == stateMachine.getRecognisedState(secondaryStateId).packageId,
            "audit did not retain secondary package"
        );

        try externalOperationRegistry.requestOperation(
            AVADataTypes.Role.Panel,
            DEFAULT_WORKFLOW,
            AVADataTypes.ExternalOperationKind.InvestigationIntent,
            AVADataTypes.ExternalOperationTargetKind.RecognisedState,
            secondaryStateId,
            peerEvidenceId,
            keccak256("panel-authority"),
            "ipfs://m142-cross-app-operation"
        ) {
            revert("cross-application operation evidence accepted");
        } catch {}
        uint256 operationId = externalOperationRegistry.requestOperation(
            AVADataTypes.Role.Panel,
            DEFAULT_WORKFLOW,
            AVADataTypes.ExternalOperationKind.InvestigationIntent,
            AVADataTypes.ExternalOperationTargetKind.RecognisedState,
            secondaryStateId,
            secondaryEvidenceId,
            keccak256("panel-authority"),
            "ipfs://m142-secondary-operation"
        );
        require(
            externalOperationRegistry.getExternalOperation(operationId).packageId
                == stateMachine.getRecognisedState(secondaryStateId).packageId,
            "external operation did not retain secondary package"
        );
    }

    function _registerSecondaryPolicy(string memory seed) internal returns (uint256) {
        return disclosureRegistry.registerDisclosurePolicy(
            AVADataTypes.Role.Editor, SECONDARY_APP_ID, seed, string.concat("ipfs://", seed)
        );
    }

    function _registerSecondaryEvidence(uint256 policyId, string memory seed) internal returns (uint256) {
        return secondaryReviewer.registerEvidenceReceiptForApplication(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            SECONDARY_APP_ID,
            DEFAULT_WORKFLOW,
            keccak256(bytes(seed)),
            string.concat("ipfs://", seed),
            "m142-evidence",
            policyId
        );
    }

    function _registerSecondaryState(uint256 evidenceId, uint256 policyId, string memory seed)
        internal
        returns (uint256)
    {
        return stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            SECONDARY_APP_ID,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            keccak256(bytes(seed)),
            EDITOR_AUTHORITY,
            evidenceId,
            policyId,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        );
    }

    function _registerSecondaryVestedState(uint256 evidenceId, uint256 policyId, string memory seed)
        internal
        returns (uint256 stateId)
    {
        stateId = _registerSecondaryState(evidenceId, policyId, seed);
        stateMachine.transitionRecognisedState(
            AVADataTypes.Role.Panel,
            stateId,
            AVADataTypes.RecognisedStateStatus.Vested,
            keccak256("panel-authority"),
            string.concat("ipfs://", seed, "-vested")
        );
    }

    function _assertRecognisedStateRejectsApplicationEvidence(
        bytes32 appId,
        uint256 evidenceId,
        uint256 policyId,
        string memory message
    ) internal {
        try stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            appId,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            keccak256(bytes(message)),
            EDITOR_AUTHORITY,
            evidenceId,
            policyId,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        ) {
            revert(message);
        } catch {}
    }

    function _disclosureProofContext(bytes32 appId, bytes32 objectId, uint256 policyId, bytes32 subjectCommitment)
        internal
        view
        returns (bytes32)
    {
        return zkProofRegistry.computeDisclosureContextHash(
            appId,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            policyId,
            subjectCommitment
        );
    }

    function _registerApplicationBoundProof(
        bytes32 appId,
        bytes32 objectId,
        uint256 policyId,
        bytes32 subjectCommitment,
        uint256 nonce
    ) internal returns (uint256) {
        bytes32 contextHash = _disclosureProofContext(appId, objectId, policyId, subjectCommitment);
        return zkProofRegistry.registerProof(
            appId,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            policyId,
            subjectCommitment,
            _makeSchnorrProof(contextHash, 7, nonce)
        );
    }

    function _assertCrossApplicationProofPolicyRejected(
        bytes32 objectId,
        uint256 peerPolicyId,
        bytes32 subjectCommitment
    ) internal {
        bytes32 contextHash = _disclosureProofContext(SECONDARY_APP_ID, objectId, peerPolicyId, subjectCommitment);
        try zkProofRegistry.registerProof(
            SECONDARY_APP_ID,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            peerPolicyId,
            subjectCommitment,
            _makeSchnorrProof(contextHash, 7, 17)
        ) {
            revert("cross-application proof policy accepted");
        } catch {}
    }
}
