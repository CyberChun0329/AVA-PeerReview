// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../src/AVADataTypes.sol";
import {AVAChallengeWorkflow} from "../src/AVAChallengeWorkflow.sol";
import {AuthorityApprovalRegistry} from "../src/AuthorityApprovalRegistry.sol";
import {IZKStandingCredentialIssuer} from "../src/interfaces/IZKStandingCredentialIssuer.sol";
import {AVASkeletonFixture, Actor} from "./helpers/AVASkeletonFixture.sol";

contract AVASecurityApprovalClosureTest is AVASkeletonFixture {
    string internal constant CONFLICT_RESOLUTION_URI = "ipfs://security-conflict-resolution";

    function testChallengerControlledPanelApprovalCannotCountTowardChallengeDecision() public {
        bytes32 challengerPanelId = keccak256("security-challenger-panel");
        roleRegistry.assignRole(
            address(challengerActor),
            AVADataTypes.Role.Panel,
            challengerPanelId,
            "ipfs://security-challenger-panel"
        );
        Actor independentPanel = new Actor();
        bytes32 independentPanelId = keccak256("security-independent-panel");
        roleRegistry.assignRole(
            address(independentPanel),
            AVADataTypes.Role.Panel,
            independentPanelId,
            "ipfs://security-independent-panel"
        );

        ApprovalAuthorityContext memory context =
            _createApprovalAuthorityContext("security-conflicted-threshold", 2, bytes32(0));
        AuthorityApprovalRegistry.ApprovalInput memory conflictedApproval =
            _upheldApprovalInput(context, challengerPanelId, "ipfs://security-conflicted-approval");
        try challengerActor.recordAuthorityApproval(
            authorityApprovalRegistry, AVADataTypes.Role.Panel, conflictedApproval
        ) {
            revert("challenger-controlled panel approval was accepted");
        } catch {}

        AuthorityApprovalRegistry.ApprovalInput memory independentApproval =
            _upheldApprovalInput(context, independentPanelId, "ipfs://security-independent-approval");
        independentPanel.recordAuthorityApproval(
            authorityApprovalRegistry, AVADataTypes.Role.Panel, independentApproval
        );
        try independentPanel.resolveChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Panel,
            context.challengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            independentPanelId,
            CONFLICT_RESOLUTION_URI
        ) {
            revert("one independent approval satisfied a two-panel threshold");
        } catch {}
        require(
            stateMachine.getRecognisedState(context.recognisedStateId).status
                == AVADataTypes.RecognisedStateStatus.Challengeable,
            "conflicted threshold mutated the target state"
        );
    }

    function testTargetControlledPanelApprovalCannotCountTowardChallengeDecision() public {
        bytes32 targetPanelId = keccak256("security-target-panel");
        roleRegistry.assignRole(
            address(reviewerActor), AVADataTypes.Role.Panel, targetPanelId, "ipfs://security-target-panel"
        );
        ApprovalAuthorityContext memory context =
            _createApprovalAuthorityContext("security-target-conflicted-threshold", 1, bytes32(0));
        AuthorityApprovalRegistry.ApprovalInput memory conflictedApproval =
            _upheldApprovalInput(context, targetPanelId, "ipfs://security-target-conflicted-approval");

        try reviewerActor.recordAuthorityApproval(
            authorityApprovalRegistry, AVADataTypes.Role.Panel, conflictedApproval
        ) {
            revert("target-controlled panel approval was accepted");
        } catch {}
        require(
            authorityApprovalRegistry.approvalCount(
                context.workflowKey,
                context.packageId,
                AVADataTypes.Action.ResolveChallenge,
                AVADataTypes.Role.Panel,
                context.recognisedStateId,
                context.challengeId,
                context.objectId,
                conflictedApproval.decisionHash
            ) == 0,
            "target-controlled approval counted toward threshold"
        );
    }

    function _upheldApprovalInput(
        ApprovalAuthorityContext memory context,
        bytes32 authorityId,
        string memory receiptURI
    ) internal view returns (AuthorityApprovalRegistry.ApprovalInput memory input) {
        input = _authorityApprovalInput(
            context,
            AVADataTypes.Action.ResolveChallenge,
            context.objectId,
            authorityId,
            uint64(block.timestamp + 7 days),
            receiptURI
        );
        AVADataTypes.ChallengeRecord memory challenge = challengeWorkflow.getChallenge(context.challengeId);
        AVADataTypes.RecognisedStateRecord memory state =
            stateMachine.getRecognisedState(context.recognisedStateId);
        input.decisionHash = _computeChallengeDecisionHash(
            AVAChallengeWorkflow.ChallengeDecisionContext({
                challengeId: context.challengeId,
                challengePackageId: context.packageId,
                targetPackageId: challenge.targetPackageId,
                action: AVADataTypes.Action.ResolveChallenge,
                lifecycleStatus: challenge.status,
                challengeTransitionId: challenge.lastTransitionId,
                fromStatus: state.status,
                toStatus: AVADataTypes.RecognisedStateStatus.Downgraded,
                outcome: AVADataTypes.ChallengeOutcome.Upheld,
                evidenceReceiptId: context.challengeEvidenceId,
                targetTransitionId: state.lastTransitionId,
                reasonHash: keccak256(bytes(CONFLICT_RESOLUTION_URI))
            })
        );
    }
}

contract AVASecurityChallengeConflictClosureTest is AVASkeletonFixture {
    function testChallengerCannotScreenOwnChallengeThroughEditorRole() public {
        bytes32 challengerEditorId = keccak256("security-challenger-editor");
        roleRegistry.assignRole(
            address(challengerActor),
            AVADataTypes.Role.Editor,
            challengerEditorId,
            "ipfs://security-challenger-editor"
        );
        uint256 challengeId = _fileSecurityChallenge("security-challenger-self-screen");

        try challengerActor.screenChallenge(
            challengeWorkflow, AVADataTypes.Role.Editor, challengeId, challengerEditorId
        ) {
            revert("challenger screened own challenge through editor role");
        } catch {}
        require(
            challengeWorkflow.getChallenge(challengeId).status
                == AVADataTypes.ChallengeLifecycleStatus.ConcernFiled,
            "conflicted screening changed challenge lifecycle"
        );
    }

    function testTargetAccountCannotScreenChallengeThroughEditorRole() public {
        bytes32 targetEditorId = keccak256("security-target-editor");
        roleRegistry.assignRole(
            address(reviewerActor), AVADataTypes.Role.Editor, targetEditorId, "ipfs://security-target-editor"
        );
        uint256 challengeId = _fileSecurityChallenge("security-target-self-screen");

        try reviewerActor.screenChallenge(
            challengeWorkflow, AVADataTypes.Role.Editor, challengeId, targetEditorId
        ) {
            revert("target account screened challenge through editor role");
        } catch {}
        require(
            challengeWorkflow.getChallenge(challengeId).status
                == AVADataTypes.ChallengeLifecycleStatus.ConcernFiled,
            "target-conflicted screening changed challenge lifecycle"
        );
    }

    function testChallengerCannotCloseOwnResolvedChallengeThroughPanelRole() public {
        bytes32 challengerPanelId = keccak256("security-challenger-close-panel");
        roleRegistry.assignRole(
            address(challengerActor),
            AVADataTypes.Role.Panel,
            challengerPanelId,
            "ipfs://security-challenger-close-panel"
        );
        uint256 challengeId = _fileSecurityChallenge("security-challenger-self-close");
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://security-independent-resolution"
        );

        try challengerActor.closeChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Panel,
            challengeId,
            challengerPanelId,
            "ipfs://security-conflicted-close"
        ) {
            revert("challenger closed own challenge through panel role");
        } catch {}
        AVADataTypes.ChallengeRecord memory challenge = challengeWorkflow.getChallenge(challengeId);
        require(
            challenge.status == AVADataTypes.ChallengeLifecycleStatus.Resolved,
            "conflicted close changed challenge lifecycle"
        );
        require(
            stateMachine.openChallengeCountForRecognisedState(challenge.challengedRecognisedStateId) == 1,
            "conflicted close released open challenge count"
        );
    }

    function _fileSecurityChallenge(string memory seed) internal returns (uint256 challengeId) {
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 evidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256(bytes(seed)),
            string.concat("ipfs://", seed),
            "review-quality-challenge",
            0
        );
        challengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            evidenceId,
            0
        );
    }
}

contract AVASecurityZKCredentialClosureTest is AVASkeletonFixture {
    function testKnownDeactivatedSubjectCannotUseZKStandingCredential() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        Actor subjectActor = new Actor();
        roleRegistry.assignRole(
            address(subjectActor),
            AVADataTypes.Role.Reviewer,
            subjectCommitment,
            "ipfs://security-zk-standing-subject"
        );
        string memory seed = "security-zk-subject-deactivation";
        uint256 credentialId = _issueM66ZKStandingCredential(
            DEFAULT_WORKFLOW, subjectCommitment, seed, 1, block.timestamp + 7 days
        );
        uint256 packageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW).packageId;
        IZKStandingCredentialIssuer.ZKStandingCredentialRecord memory credential =
            zkStandingCredentialRegistry.getCredential(credentialId);
        require(
            zkStandingCredentialRegistry.credentialProves(
                credentialId,
                packageId,
                subjectCommitment,
                credential.vectorKey,
                credential.categoryHash,
                40
            ),
            "active known subject could not prove credential"
        );

        roleRegistry.deactivateSubject(subjectCommitment);
        require(
            !zkStandingCredentialRegistry.credentialProves(
                credentialId,
                packageId,
                subjectCommitment,
                credential.vectorKey,
                credential.categoryHash,
                40
            ),
            "deactivated known subject retained ZK standing proof"
        );
        _assertM66CannotRecordCredentialUseWithSecret(
            credentialId,
            40,
            keccak256("security-deactivated-zk-use"),
            _m66CredentialSecret(seed),
            "deactivated known subject recorded ZK credential use"
        );
    }
}

contract AVASecurityPenaltyClosureTest is AVASkeletonFixture {
    function testReviewerFindingCannotBeRelabelledAsAcademicFraud() public {
        (uint256 stateId, uint256 challengeId, uint256 evidenceId) = _createResolvedChallengeForSubject(
            REVIEWER_SUBJECT,
            "security-reviewer-finding-role",
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded
        );
        _recordPenaltyForChallenge(
            stateId,
            challengeId,
            AVADataTypes.GovernanceFindingKind.IrresponsibleReview,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://security-reviewer-finding"
        );

        try consequenceExecutor.recordPenalty(
            AVADataTypes.Role.Panel,
            AVADataTypes.PenaltyConsequenceContext({
                challengeId: challengeId,
                findingKind: AVADataTypes.GovernanceFindingKind.AcademicFraud,
                originSettlementId: 0
            }),
            _valueContext(
                stateId,
                REVIEWER_SUBJECT,
                1,
                evidenceId,
                keccak256("panel-authority"),
                "ipfs://security-reviewer-relabeled-fraud",
                keccak256("security-reviewer-relabeled-fraud"),
                address(0),
                address(0),
                AVADataTypes.ValueExecutionMode.RecordOnly
            )
        ) {
            revert("reviewer finding was relabelled as academic fraud");
        } catch {}
    }

    function testAuthorFindingCannotBeRelabelledAsIrresponsibleReview() public {
        Actor authorActor = new Actor();
        bytes32 authorSubject = keccak256("security-author-finding-subject");
        roleRegistry.assignRole(
            address(authorActor),
            AVADataTypes.Role.Author,
            authorSubject,
            "ipfs://security-author-finding-subject"
        );
        (uint256 stateId, uint256 challengeId, uint256 evidenceId) = _createResolvedChallengeForSubject(
            authorSubject,
            "security-author-finding-role",
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded
        );
        uint256 fraudPenaltyId = _recordPenaltyForChallenge(
            stateId,
            challengeId,
            AVADataTypes.GovernanceFindingKind.AcademicFraud,
            authorSubject,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://security-author-fraud-finding"
        );
        require(fraudPenaltyId != 0, "valid author fraud finding was rejected");

        try consequenceExecutor.recordPenalty(
            AVADataTypes.Role.Panel,
            AVADataTypes.PenaltyConsequenceContext({
                challengeId: challengeId,
                findingKind: AVADataTypes.GovernanceFindingKind.IrresponsibleReview,
                originSettlementId: 0
            }),
            _valueContext(
                stateId,
                authorSubject,
                1,
                evidenceId,
                keccak256("panel-authority"),
                "ipfs://security-author-relabeled-review",
                keccak256("security-author-relabeled-review"),
                address(0),
                address(0),
                AVADataTypes.ValueExecutionMode.RecordOnly
            )
        ) {
            revert("author finding was relabelled as irresponsible review");
        } catch {}
    }
}

contract AVASecurityChallengeGriefingClosureTest is AVASkeletonFixture {
    function testRejectedChallengeRestorationCannotUpgradeChallengeableState() public {
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 challengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            _registerChallengeEvidence("security-challengeable-restoration"),
            0
        );
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://security-challengeable-restoration-resolution"
        );

        uint256 targetTransitionIdBefore = stateMachine.getRecognisedState(recognisedStateId).lastTransitionId;
        challengeWorkflow.applyRestoration(
            AVADataTypes.Role.Panel,
            challengeId,
            keccak256("panel-authority"),
            "ipfs://security-challengeable-restoration-record"
        );

        AVADataTypes.RecognisedStateRecord memory state = stateMachine.getRecognisedState(recognisedStateId);
        AVADataTypes.ChallengeRecord memory challenge = challengeWorkflow.getChallenge(challengeId);
        AVADataTypes.ChallengeTransitionRecord memory restoration =
            challengeWorkflow.getChallengeTransition(challenge.lastTransitionId);
        require(
            state.status == AVADataTypes.RecognisedStateStatus.Challengeable,
            "restoration upgraded challengeable state"
        );
        require(state.lastTransitionId == targetTransitionIdBefore, "record-only restoration mutated target ledger");
        require(
            restoration.fromStatus == AVADataTypes.RecognisedStateStatus.Challengeable
                && restoration.toStatus == AVADataTypes.RecognisedStateStatus.Challengeable,
            "restoration record did not preserve filing status"
        );
    }

    function testDefaultPackageRejectsRepeatedChallengeAgainstSameTargetVersion() public {
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 firstEvidenceId = _registerChallengeEvidence("security-first-version-challenge");
        uint256 firstChallengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            firstEvidenceId,
            0
        );
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, firstChallengeId, EDITOR_AUTHORITY);
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            firstChallengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://security-first-version-resolution"
        );
        challengeWorkflow.closeChallenge(
            AVADataTypes.Role.Panel,
            firstChallengeId,
            keccak256("panel-authority"),
            "ipfs://security-first-version-close"
        );

        uint256 secondEvidenceId = _registerChallengeEvidence("security-second-version-challenge");
        uint256 nextChallengeId = challengeWorkflow.nextChallengeId();
        try challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            secondEvidenceId,
            0
        ) {
            revert("default package accepted repeated challenge against unchanged target version");
        } catch {}
        require(challengeWorkflow.nextChallengeId() == nextChallengeId, "rejected repeat wrote challenge record");
        require(
            stateMachine.openChallengeCountForRecognisedState(recognisedStateId) == 0,
            "rejected repeat changed open challenge count"
        );
    }

    function testSubjectRotationCannotBypassOpenChallengeCapForSameAccount() public {
        uint256 recognisedStateId = _createChallengeableReviewState();
        challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            _registerChallengeEvidence("security-rotation-open-first"),
            0
        );
        bytes32 rotatedSubjectId = _rotateChallengerSubject("security-rotation-open-subject");

        uint256 nextChallengeId = challengeWorkflow.nextChallengeId();
        try challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            recognisedStateId,
            rotatedSubjectId,
            _registerChallengeEvidence("security-rotation-open-second"),
            0
        ) {
            revert("subject rotation bypassed account open-challenge cap");
        } catch {}
        require(challengeWorkflow.nextChallengeId() == nextChallengeId, "rejected rotation wrote challenge");
        require(
            stateMachine.openChallengeCountForRecognisedState(recognisedStateId) == 1,
            "rejected rotation changed open challenge count"
        );
    }

    function testSubjectRotationCannotRefileUnchangedTargetVersionForSameAccount() public {
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 challengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            _registerChallengeEvidence("security-rotation-version-first"),
            0
        );
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://security-rotation-version-resolution"
        );
        challengeWorkflow.closeChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            keccak256("panel-authority"),
            "ipfs://security-rotation-version-close"
        );
        bytes32 rotatedSubjectId = _rotateChallengerSubject("security-rotation-version-subject");

        uint256 nextChallengeId = challengeWorkflow.nextChallengeId();
        try challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            recognisedStateId,
            rotatedSubjectId,
            _registerChallengeEvidence("security-rotation-version-second"),
            0
        ) {
            revert("subject rotation bypassed account target-version cap");
        } catch {}
        require(challengeWorkflow.nextChallengeId() == nextChallengeId, "rejected rotation wrote challenge");
    }

    function testSameAccountCanChallengeAfterExplicitTargetVersionChangeAndSubjectRotation() public {
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 firstEvidenceId = _registerChallengeEvidence("security-versioned-first-challenge");
        uint256 firstChallengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            firstEvidenceId,
            0
        );
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, firstChallengeId, EDITOR_AUTHORITY);
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            firstChallengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            keccak256("panel-authority"),
            "ipfs://security-versioned-correction"
        );
        challengeWorkflow.applyRestoration(
            AVADataTypes.Role.Panel,
            firstChallengeId,
            keccak256("panel-authority"),
            "ipfs://security-versioned-restoration"
        );
        challengeWorkflow.closeChallenge(
            AVADataTypes.Role.Panel,
            firstChallengeId,
            keccak256("panel-authority"),
            "ipfs://security-versioned-close"
        );
        bytes32 rotatedSubjectId = _rotateChallengerSubject("security-versioned-rotated-subject");

        uint256 secondChallengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            recognisedStateId,
            rotatedSubjectId,
            _registerChallengeEvidence("security-versioned-second-challenge"),
            0
        );
        require(secondChallengeId != 0, "new target version rejected a fresh challenge");
        require(
            challengeWorkflow.getChallenge(secondChallengeId).targetStatusAtFiling
                == AVADataTypes.RecognisedStateStatus.Challengeable,
            "fresh challenge did not bind restored challengeable version"
        );
    }

    function testAlternateChallengePackageCannotBypassTargetVersionFilingCap() public {
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 firstChallengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            _registerChallengeEvidence("security-cross-package-first"),
            0
        );
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, firstChallengeId, EDITOR_AUTHORITY);
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            firstChallengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://security-cross-package-resolution"
        );
        challengeWorkflow.closeChallenge(
            AVADataTypes.Role.Panel,
            firstChallengeId,
            keccak256("panel-authority"),
            "ipfs://security-cross-package-close"
        );

        bytes32 alternateWorkflow = keccak256("security-alternate-challenge-workflow");
        _registerRulePackage(
            alternateWorkflow,
            disclosurePolicyModule,
            allocationAdapter,
            consequenceAdapter,
            "ipfs://security-alternate-challenge-package"
        );
        uint256 alternateEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            alternateWorkflow,
            keccak256("security-cross-package-second"),
            "ipfs://security-cross-package-second",
            "review-quality-challenge",
            0
        );

        try challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            alternateWorkflow,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            alternateEvidenceId,
            0
        ) {
            revert("alternate challenge package bypassed target-version filing cap");
        } catch {}
        require(
            stateMachine.openChallengeCountForRecognisedState(recognisedStateId) == 0,
            "cross-package repeat changed open challenge count"
        );
    }

    function _registerChallengeEvidence(string memory seed) internal returns (uint256) {
        return challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256(bytes(seed)),
            string.concat("ipfs://", seed),
            "review-quality-challenge",
            0
        );
    }

    function _rotateChallengerSubject(string memory seed) internal returns (bytes32 rotatedSubjectId) {
        roleRegistry.deactivateSubject(CHALLENGER_SUBJECT);
        rotatedSubjectId = keccak256(bytes(seed));
        roleRegistry.assignRole(
            address(challengerActor),
            AVADataTypes.Role.Challenger,
            rotatedSubjectId,
            string.concat("ipfs://", seed)
        );
    }
}

contract AVASecurityPinnedEvidenceLifecycleTest is AVASkeletonFixture {
    function testOpenChallengeWindowRejectsInactivePinnedReviewEvidence() public {
        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("security-review-transition-evidence"),
            "ipfs://security-review-transition-evidence",
            "review-service-occurrence",
            0
        );
        uint256 reviewContributionId = reviewerActor.registerReviewContributionWithWorkflow(
            stateMachine,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            manuscriptId,
            REVIEWER_SUBJECT,
            evidenceId,
            0
        );
        uint256 recognisedStateId =
            stateMachine.provisionallyRecogniseReview(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);
        uint256 transitionIdBefore = stateMachine.getRecognisedState(recognisedStateId).lastTransitionId;
        _revokeEvidenceAsPanel(evidenceId, "security-review-transition-revoked");

        try stateMachine.openReviewChallengeWindow(
            AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY
        ) {
            revert("inactive review evidence allowed challenge-window transition");
        } catch {}
        AVADataTypes.RecognisedStateRecord memory state = stateMachine.getRecognisedState(recognisedStateId);
        require(state.status == AVADataTypes.RecognisedStateStatus.Provisional, "rejected transition changed state");
        require(state.lastTransitionId == transitionIdBefore, "rejected transition wrote target ledger");
    }

    function testGenericTransitionRejectsInactivePinnedEvidence() public {
        uint256 evidenceId = _registerM51DefaultEvidence("security-generic-transition");
        uint256 recognisedStateId = stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            keccak256("security-generic-transition-object"),
            REVIEWER_SUBJECT,
            evidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        );
        uint256 transitionIdBefore = stateMachine.getRecognisedState(recognisedStateId).lastTransitionId;
        _revokeEvidenceAsPanel(evidenceId, "security-generic-transition-revoked");

        try stateMachine.transitionRecognisedState(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            AVADataTypes.RecognisedStateStatus.Vested,
            keccak256("panel-authority"),
            "ipfs://security-generic-transition"
        ) {
            revert("inactive evidence allowed generic state transition");
        } catch {}
        AVADataTypes.RecognisedStateRecord memory state = stateMachine.getRecognisedState(recognisedStateId);
        require(state.status == AVADataTypes.RecognisedStateStatus.Registered, "rejected transition changed state");
        require(state.lastTransitionId == transitionIdBefore, "rejected transition wrote target ledger");
    }

    function testReviewVestingRejectsEvidenceRevokedAfterWindowOpened() public {
        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("security-review-vesting-evidence"),
            "ipfs://security-review-vesting-evidence",
            "review-service-occurrence",
            0
        );
        uint256 reviewContributionId = reviewerActor.registerReviewContributionWithWorkflow(
            stateMachine,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            manuscriptId,
            REVIEWER_SUBJECT,
            evidenceId,
            0
        );
        uint256 recognisedStateId =
            stateMachine.provisionallyRecogniseReview(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);
        stateMachine.openReviewChallengeWindow(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);
        uint256 transitionIdBefore = stateMachine.getRecognisedState(recognisedStateId).lastTransitionId;
        _revokeEvidenceAsPanel(evidenceId, "security-review-vesting-evidence-revoked");
        vm.warp(
            uint256(stateMachine.getChallengeWindowOpenedAt(recognisedStateId))
                + stateMachine.minimumChallengeWindowDuration()
        );

        try stateMachine.vestReviewRecognition(
            AVADataTypes.Role.Panel,
            reviewContributionId,
            keccak256("panel-authority"),
            "ipfs://security-review-vesting"
        ) {
            revert("inactive review evidence allowed vesting");
        } catch {}
        AVADataTypes.RecognisedStateRecord memory state = stateMachine.getRecognisedState(recognisedStateId);
        require(state.status == AVADataTypes.RecognisedStateStatus.Challengeable, "rejected vesting changed state");
        require(state.lastTransitionId == transitionIdBefore, "rejected vesting wrote target ledger");
    }

    function testUpheldCorrectionCanRepairStateWithInactivePinnedTargetEvidence() public {
        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 targetEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("security-correction-target-evidence"),
            "ipfs://security-correction-target-evidence",
            "review-service-occurrence",
            0
        );
        uint256 reviewContributionId = reviewerActor.registerReviewContributionWithWorkflow(
            stateMachine,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            manuscriptId,
            REVIEWER_SUBJECT,
            targetEvidenceId,
            0
        );
        uint256 recognisedStateId =
            stateMachine.provisionallyRecogniseReview(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);
        stateMachine.openReviewChallengeWindow(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);
        uint256 challengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            _registerChallengeEvidence("security-correction-challenge-evidence"),
            0
        );
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        uint256 transitionIdBefore = stateMachine.getRecognisedState(recognisedStateId).lastTransitionId;
        _revokeEvidenceAsPanel(targetEvidenceId, "security-correction-target-evidence-revoked");

        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            keccak256("panel-authority"),
            "ipfs://security-correction-resolution"
        );
        AVADataTypes.RecognisedStateRecord memory state = stateMachine.getRecognisedState(recognisedStateId);
        require(state.status == AVADataTypes.RecognisedStateStatus.Downgraded, "correction did not downgrade state");
        require(state.lastTransitionId > transitionIdBefore, "correction did not write target ledger");
        AVADataTypes.ChallengeRecord memory challenge = challengeWorkflow.getChallenge(challengeId);
        require(challenge.outcome == AVADataTypes.ChallengeOutcome.Upheld, "upheld outcome missing");
        require(challenge.status == AVADataTypes.ChallengeLifecycleStatus.Resolved, "challenge not resolved");
    }

    function testChallengeScreeningRejectsInactivePinnedChallengeEvidence() public {
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 evidenceId = _registerChallengeEvidence("security-screen-evidence");
        uint256 challengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            evidenceId,
            0
        );
        _revokeEvidenceAsPanel(evidenceId, "security-screen-evidence-revoked");

        try challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY) {
            revert("inactive challenge evidence allowed screening");
        } catch {}
        require(
            challengeWorkflow.getChallenge(challengeId).status
                == AVADataTypes.ChallengeLifecycleStatus.ConcernFiled,
            "rejected screening changed challenge"
        );
    }

    function testChallengeResolutionRejectsEvidenceRevokedAfterScreening() public {
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 evidenceId = _registerChallengeEvidence("security-resolution-evidence");
        uint256 challengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            evidenceId,
            0
        );
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        _revokeEvidenceAsPanel(evidenceId, "security-resolution-evidence-revoked");

        try challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://security-resolution-evidence"
        ) {
            revert("inactive challenge evidence allowed resolution");
        } catch {}
        require(
            challengeWorkflow.getChallenge(challengeId).status
                == AVADataTypes.ChallengeLifecycleStatus.AdmissibilityScreening,
            "rejected resolution changed challenge"
        );
    }

    function testRestorationRejectsEvidenceRevokedAfterResolution() public {
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 evidenceId = _registerChallengeEvidence("security-restoration-evidence");
        uint256 challengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            evidenceId,
            0
        );
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://security-restoration-evidence-resolution"
        );
        _revokeEvidenceAsPanel(evidenceId, "security-restoration-evidence-revoked");

        try challengeWorkflow.applyRestoration(
            AVADataTypes.Role.Panel,
            challengeId,
            keccak256("panel-authority"),
            "ipfs://security-restoration-evidence"
        ) {
            revert("inactive challenge evidence allowed restoration");
        } catch {}
        require(
            challengeWorkflow.getChallenge(challengeId).status == AVADataTypes.ChallengeLifecycleStatus.Resolved,
            "rejected restoration changed challenge"
        );
    }

    function _registerChallengeEvidence(string memory seed) internal returns (uint256) {
        return challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256(bytes(seed)),
            string.concat("ipfs://", seed),
            "review-quality-challenge",
            0
        );
    }

    function _revokeEvidenceAsPanel(uint256 evidenceId, string memory seed) internal {
        authorityMatrix.setPermission(AVADataTypes.Role.Panel, AVADataTypes.Action.RecordEvidenceLifecycle, true);
        evidenceRegistry.recordEvidenceLifecycleHook(
            AVADataTypes.Role.Panel,
            PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW,
            evidenceId,
            AVADataTypes.EvidenceLifecycleKind.RevocationReady,
            0,
            keccak256(bytes(seed)),
            string.concat("ipfs://", seed)
        );
    }
}
