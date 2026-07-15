// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./helpers/AVASkeletonFixture.sol";
import {AVARulePackageLifecycleRegistry} from "../src/AVARulePackageLifecycleRegistry.sol";

contract AVASkeletonLifecycle01AAATest is AVASkeletonFixture {
    function testM416DisclosureLifecycleReadinessIsPackageReplaceableAndRevealFree() public {
        bytes32 workflowKey = keccak256("m416-disclosure-lifecycle");
        uint256 disclosurePolicyId = _registerDisclosurePolicy("m416-disclosure-lifecycle-policy");
        _registerRulePackageWithDisclosureLifecycle(
            workflowKey, disclosureLifecycleModule, "ipfs://m416-disclosure-lifecycle-old"
        );
        uint256 oldPackageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).packageId;
        uint256 readinessId = rulePackageLifecycleRegistry.recordDisclosureLifecycleReadiness(
            AVADataTypes.Role.Panel,
            PEER_REVIEW_APP_ID, workflowKey,
            disclosurePolicyId,
            AVADataTypes.DisclosureLifecycleKind.PolicyBoundReady,
            keccak256("m416-disclosure-lifecycle-ref"),
            keccak256("panel-authority"),
            "ipfs://m416-disclosure-lifecycle"
        );
        AVADataTypes.DisclosureLifecycleRecord memory readiness =
            rulePackageLifecycleRegistry.getDisclosureLifecycleRecord(readinessId);
        require(readiness.packageId == oldPackageId, "disclosure lifecycle used wrong package");

        _registerRulePackageWithDisclosureLifecycle(
            workflowKey,
            new RejectingDisclosureLifecycleModule(AVADataTypes.DisclosureLifecycleKind.PostRecognitionDisclosureReady),
            "ipfs://m416-disclosure-lifecycle-new"
        );
        uint256 newPackageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).packageId;
        try rulePackageLifecycleRegistry.recordDisclosureLifecycleReadiness(
            AVADataTypes.Role.Panel,
            PEER_REVIEW_APP_ID, workflowKey,
            disclosurePolicyId,
            AVADataTypes.DisclosureLifecycleKind.PostRecognitionDisclosureReady,
            keccak256("m416-disclosure-lifecycle-reject"),
            keccak256("panel-authority"),
            "ipfs://m416-disclosure-lifecycle-reject"
        ) {
            revert("disclosure lifecycle module did not reject replaced package path");
        } catch {}
        uint256 acceptedNewReadinessId = rulePackageLifecycleRegistry.recordDisclosureLifecycleReadiness(
            AVADataTypes.Role.Panel,
            PEER_REVIEW_APP_ID, workflowKey,
            disclosurePolicyId,
            AVADataTypes.DisclosureLifecycleKind.ZKProofReceiptReady,
            keccak256("m416-disclosure-lifecycle-new-ref"),
            keccak256("panel-authority"),
            "ipfs://m416-disclosure-lifecycle-new"
        );
        require(
            rulePackageLifecycleRegistry.getDisclosureLifecycleRecord(acceptedNewReadinessId).packageId == newPackageId,
            "new disclosure lifecycle did not use active package"
        );
        _assertNoSelector(address(rulePackageRegistry), "revealIdentity(uint256)");
        _assertNoSelector(address(rulePackageRegistry), "revealEvidence(uint256)");
        _assertNoSelector(address(rulePackageRegistry), "decryptEvidence(uint256)");
        _assertNoSelector(
            address(rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).disclosureLifecycleModule),
            "revealIdentity(uint256)"
        );
    }
}

contract AVASkeletonLifecycle01AABTest is AVASkeletonFixture {
    function testM417DisclosureLifecycleReadinessRequiresRegisteredPolicyAtSubstrate() public {
        bytes32 workflowKey = keccak256("m417-disclosure-lifecycle");
        uint256 disclosurePolicyId = _registerDisclosurePolicy("m417-disclosure-lifecycle-policy");
        uint256 unknownDisclosurePolicyId = disclosurePolicyId + 1000;
        _registerRulePackageWithDisclosureLifecycle(
            workflowKey,
            new RejectingDisclosureLifecycleModule(AVADataTypes.DisclosureLifecycleKind.ZKProofReceiptReady),
            "ipfs://m417-disclosure-lifecycle"
        );

        try rulePackageLifecycleRegistry.recordDisclosureLifecycleReadiness(
            AVADataTypes.Role.Panel,
            PEER_REVIEW_APP_ID, workflowKey,
            unknownDisclosurePolicyId,
            AVADataTypes.DisclosureLifecycleKind.PolicyBoundReady,
            keccak256("m417-disclosure-lifecycle-unknown-policy"),
            keccak256("panel-authority"),
            "ipfs://m417-disclosure-lifecycle-unknown-policy"
        ) {
            revert("disclosure lifecycle accepted unknown policy before module");
        } catch {}

        uint256 readinessId = rulePackageLifecycleRegistry.recordDisclosureLifecycleReadiness(
            AVADataTypes.Role.Panel,
            PEER_REVIEW_APP_ID, workflowKey,
            disclosurePolicyId,
            AVADataTypes.DisclosureLifecycleKind.PolicyBoundReady,
            keccak256("m417-disclosure-lifecycle-registered-policy"),
            keccak256("panel-authority"),
            "ipfs://m417-disclosure-lifecycle-registered-policy"
        );
        require(
            rulePackageLifecycleRegistry.getDisclosureLifecycleRecord(readinessId).disclosurePolicyId
                == disclosurePolicyId,
            "registered policy not recorded"
        );

        try rulePackageLifecycleRegistry.recordDisclosureLifecycleReadiness(
            AVADataTypes.Role.Panel,
            PEER_REVIEW_APP_ID, workflowKey,
            disclosurePolicyId,
            AVADataTypes.DisclosureLifecycleKind.ZKProofReceiptReady,
            keccak256("m417-disclosure-lifecycle-module-reject"),
            keccak256("panel-authority"),
            "ipfs://m417-disclosure-lifecycle-module-reject"
        ) {
            revert("disclosure lifecycle module-specific rejection bypassed");
        } catch {}
    }
}

contract AVASkeletonLifecycle01ABATest is AVASkeletonFixture {
    function testM418RulePackageLifecycleSeesModulesHashAndBlocksIncompatiblePackage() public {
        bytes32 workflowKey = keccak256("m418-lifecycle-hash");
        bytes32 compatibilityKey = keccak256("m418-compatible");
        ModulesHashGateRulePackageLifecycleModule lifecycleModule =
            new ModulesHashGateRulePackageLifecycleModule(compatibilityKey);
        AVARulePackageRegistry.RulePackageModules memory modules = AVARulePackageRegistry.RulePackageModules({
            applicationModule: applicationModule,
            attributionModule: attributionModule,
            verificationModule: verificationModule,
            allocationModule: allocationAdapter,
            transitionRuleModule: transitionRuleModule,
            disclosureModule: disclosurePolicyModule,
            standingAdapter: standingAdapter,
            consequenceAdapter: consequenceAdapter,
            rewardAdapter: rewardAdapter,
            priorityAdapter: priorityAdapter,
            penaltyAdapter: penaltyAdapter,
            restorationAdapter: restorationAdapter,
            challengeLifecycleModule: challengeLifecycleModule,
            evidencePolicyModule: evidencePolicyModule,
            auditAdapter: auditAdapter,
            editorialSystemAdapter: editorialSystemAdapter,
            residualEditorialAuthorityModule: residualEditorialAuthorityModule,
            fieldPolicyModule: fieldPolicyModule,
            antiAbuseModule: antiAbuseModule,
            valueExecutionAdapter: valueExecutionAdapter,
            standingComputationModule: standingComputationModule,
            rulePackageLifecycleModule: lifecycleModule,
            evidenceLifecycleModule: evidenceLifecycleModule,
            disclosureLifecycleModule: disclosureLifecycleModule,
            disclosureExecutionModule: disclosureExecutionModule,
            version: 1,
            compatibilityKey: compatibilityKey,
            dependencyURI: "ipfs://m418-lifecycle-dependencies",
            deprecated: false
        });

        modules.compatibilityKey = keccak256("m418-incompatible");
        try rulePackageRegistry.registerRulePackage(
            AVADataTypes.Role.Panel, PEER_REVIEW_APP_ID, workflowKey, modules, "ipfs://m418-incompatible"
        ) {
            revert("incompatible lifecycle module did not reject package registration");
        } catch {}

        modules.compatibilityKey = compatibilityKey;
        bytes32 modulesHash = rulePackageRegistry.hashModules(modules);
        rulePackageRegistry.registerRulePackage(AVADataTypes.Role.Panel, PEER_REVIEW_APP_ID, workflowKey, modules, "ipfs://m418-compatible");
        AVARulePackageRegistry.RulePackage memory rulePackage = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey);
        require(rulePackage.modulesHash == modulesHash, "modules hash not bound to package");
        require(rulePackage.modulesIdentityHash != bytes32(0), "module identity hash not bound");
    }
}

contract AVASkeletonLifecycle01BAATest is AVASkeletonFixture {
    function testM418PermissiveModulesCannotBypassSubstrateHardGates() public {
        bytes32 workflowKey = keccak256("m418-permissive-hard-gates");
        _registerRulePackageWithLifecycle(
            workflowKey, new PermissiveChallengeLifecycleModule(), "ipfs://m418-permissive-hard-gates"
        );
        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m418-permissive-review-evidence"),
            "ipfs://m418-permissive-review-evidence",
            "review-service-occurrence",
            0
        );
        try reviewerActor.registerReviewContributionWithWorkflow(
            stateMachine, AVADataTypes.Role.Reviewer, workflowKey, manuscriptId, CHALLENGER_SUBJECT, evidenceId, 0
        ) {
            revert("permissive package bypassed reviewer subject binding");
        } catch {}

        uint256 reviewContributionId = reviewerActor.registerReviewContributionWithWorkflow(
            stateMachine, AVADataTypes.Role.Reviewer, workflowKey, manuscriptId, REVIEWER_SUBJECT, evidenceId, 0
        );
        try stateMachine.provisionallyRecogniseReview(
            AVADataTypes.Role.Editor, reviewContributionId, keccak256("wrong-editor-authority")
        ) {
            revert("permissive package bypassed authorityId binding");
        } catch {}
        uint256 recognisedStateId =
            stateMachine.provisionallyRecogniseReview(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);
        stateMachine.openReviewChallengeWindow(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);

        try challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            workflowKey,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            evidenceId + 999,
            0
        ) {
            revert("permissive package bypassed evidence existence");
        } catch {}
        try challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            1,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Restored,
            keccak256("panel-authority"),
            "ipfs://m418-invalid-resolution"
        ) {
            revert("permissive package bypassed challenge existence");
        } catch {}
        try stateMachine.transitionRecognisedState(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            keccak256("panel-authority"),
            "ipfs://m418-generic-downgrade"
        ) {
            revert("permissive package bypassed high-impact transition gate");
        } catch {}
    }
}

contract AVASkeletonLifecycle01BABTest is AVASkeletonFixture {
    function testM418ActivePermissivePackageCannotRewriteTargetPackageGate() public {
        bytes32 workflowKey = keccak256("m418-package-gate");
        _registerRulePackageWithModules(
            workflowKey,
            attributionModule,
            verificationModule,
            new ActionRejectingTransitionRuleModule(AVADataTypes.Action.ResolveChallenge),
            disclosurePolicyModule,
            allocationAdapter,
            consequenceAdapter,
            "ipfs://m418-package-gate-rejecting"
        );
        AVARulePackageRegistry.RulePackage memory originalPackage = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey);
        uint256 recognisedStateId = _createChallengeableReviewStateThroughPackage(originalPackage, workflowKey);

        _registerDefaultRulePackage(workflowKey, "ipfs://m418-package-gate-permissive");
        AVADataTypes.RecognisedStateRecord memory recognisedState = stateMachine.getRecognisedState(recognisedStateId);
        require(recognisedState.packageId == originalPackage.packageId, "target package was rewritten");
        require(
            rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).packageId != recognisedState.packageId,
            "workflow package was not replaced"
        );

        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            workflowKey,
            keccak256("m418-package-gate-challenge"),
            "ipfs://m418-package-gate-challenge",
            "review-quality-challenge",
            0
        );
        uint256 challengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            workflowKey,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            0
        );
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        try challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            keccak256("panel-authority"),
            "ipfs://m418-target-package-veto"
        ) {
            revert("active permissive package bypassed target transition rule");
        } catch {}
        require(
            stateMachine.getRecognisedState(recognisedStateId).status
                == AVADataTypes.RecognisedStateStatus.Challengeable,
            "target state changed after historical package veto"
        );
    }
}

contract AVASkeletonLifecycle01BBATest is AVASkeletonFixture {
    function testM418RejectingModuleFailsClosedBeforeStorageChange() public {
        bytes32 workflowKey = keccak256("m418-rejecting-fail-closed");
        _registerRulePackageWithLifecycle(
            workflowKey,
            new RejectingChallengeLifecycleModule(AVADataTypes.Action.FileChallenge),
            "ipfs://m418-rejecting-fail-closed"
        );
        AVARulePackageRegistry.RulePackage memory rulePackage = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey);
        uint256 recognisedStateId = _createChallengeableReviewStateThroughPackage(rulePackage, workflowKey);
        uint256 evidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            workflowKey,
            keccak256("m418-rejecting-challenge-evidence"),
            "ipfs://m418-rejecting-challenge-evidence",
            "review-quality-challenge",
            0
        );
        uint256 nextChallengeId = challengeWorkflow.nextChallengeId();

        try challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            workflowKey,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            evidenceId,
            0
        ) {
            revert("rejecting challenge lifecycle module did not fail closed");
        } catch {}
        require(
            challengeWorkflow.nextChallengeId() == nextChallengeId, "challenge storage mutated after module rejection"
        );
    }
}

contract AVASkeletonLifecycle02AAATest is AVASkeletonFixture {
    function testM418DisclosureAndResidualModulesCannotExposeForbiddenExecutionSelectors() public {
        _assertNoSelector(address(disclosurePolicyModule), "revealIdentity(uint256)");
        _assertNoSelector(address(disclosurePolicyModule), "revealEvidence(uint256)");
        _assertNoSelector(address(disclosurePolicyModule), "decryptEvidence(uint256)");
        _assertNoSelector(address(disclosureLifecycleModule), "revealIdentity(uint256)");
        _assertNoSelector(address(disclosureLifecycleModule), "decryptEvidence(uint256)");
        _assertNoSelector(address(residualEditorialAuthorityModule), "acceptManuscript(uint256)");
        _assertNoSelector(address(residualEditorialAuthorityModule), "rejectManuscript(uint256)");
        _assertNoSelector(address(residualEditorialAuthorityModule), "scoreManuscriptMerit(uint256)");
        _assertNoSelector(address(residualEditorialAuthorityModule), "grantPublicationPriority(uint256)");
    }
}

contract AVASkeletonLifecycle02AABTest is AVASkeletonFixture {
    struct M418DownstreamContext {
        uint256 evidenceId;
        uint256 recognisedStateId;
        uint256 nextConsequenceId;
        uint256 nextAllocationId;
    }

    function testM418DownstreamAdaptersRemainSeparatedAndRecordOnly() public {
        M418DownstreamContext memory context = _prepareM418DownstreamContext();
        _assertM418AllocationRecords(context);
        _assertM418ConsequenceRecords(context);
    }

    function _prepareM418DownstreamContext() internal returns (M418DownstreamContext memory context) {
        context.evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            keccak256("m418-downstream-evidence"),
            "ipfs://m418-downstream-evidence",
            "downstream-record-basis",
            0
        );
        context.recognisedStateId = _registerRecognisedStateForWorkflowStatus(
            DEFAULT_WORKFLOW, AVADataTypes.RecognisedStateStatus.Vested, context.evidenceId, "m418-downstream-state"
        );
        context.nextConsequenceId = consequenceExecutor.nextConsequenceId();
    }

    function _assertM418AllocationRecords(M418DownstreamContext memory context) internal {
        uint256 rewardId = allocationExecutor.recordRewardValue(
            AVADataTypes.Role.ProtocolExecutor,
            context.recognisedStateId,
            REVIEWER_SUBJECT,
            1,
            context.evidenceId,
            keccak256("executor-authority"),
            "ipfs://m418-reward-record"
        );
        uint256 priorityId = allocationExecutor.recordAdministrativePriority(
            AVADataTypes.Role.ProtocolExecutor,
            context.recognisedStateId,
            REVIEWER_SUBJECT,
            1,
            context.evidenceId,
            keccak256("executor-authority"),
            "ipfs://m418-priority-record"
        );
        require(
            allocationExecutor.getAllocationExecution(rewardId).allocationKind
                == AVADataTypes.AllocationKind.RewardValueRecord,
            "reward adapter wrote wrong allocation record"
        );
        require(
            allocationExecutor.getAllocationExecution(priorityId).allocationKind
                == AVADataTypes.AllocationKind.AdministrativeQueueRecord,
            "priority adapter wrote wrong allocation record"
        );
        require(
            consequenceExecutor.nextConsequenceId() == context.nextConsequenceId, "allocation path created consequence"
        );
        context.nextAllocationId = allocationExecutor.nextAllocationExecutionId();
    }

    function _assertM418ConsequenceRecords(M418DownstreamContext memory context) internal {
        (uint256 penaltyStateId, uint256 penaltyChallengeId, uint256 penaltyEvidenceId) = _createResolvedChallengeForSubject(
            REVIEWER_SUBJECT,
            "m418-penalty-record",
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded
        );
        uint256 penaltyId = _recordPenaltyForChallenge(
            penaltyStateId,
            penaltyChallengeId,
            AVADataTypes.GovernanceFindingKind.IrresponsibleReview,
            REVIEWER_SUBJECT,
            penaltyEvidenceId,
            keccak256("panel-authority"),
            "ipfs://m418-penalty-record"
        );
        uint256 restorationId = consequenceExecutor.recordRestoration(
            AVADataTypes.Role.Panel,
            context.recognisedStateId,
            REVIEWER_SUBJECT,
            context.evidenceId,
            keccak256("panel-authority"),
            "ipfs://m418-restoration-record"
        );
        require(
            consequenceExecutor.getConsequence(penaltyId).kind == AVADataTypes.ConsequenceKind.PenaltyRecord,
            "penalty adapter wrote wrong consequence record"
        );
        require(
            consequenceExecutor.getConsequence(restorationId).kind == AVADataTypes.ConsequenceKind.RestorationRecord,
            "restoration adapter wrote wrong consequence record"
        );
        require(
            allocationExecutor.nextAllocationExecutionId() == context.nextAllocationId,
            "consequence path created allocation"
        );
    }
}

contract AVASkeletonLifecycle02ABATest is AVASkeletonFixture {
    function testM426GenericAllocationCannotBypassRewardOrPriorityAdapters() public {
        bytes32 workflowKey = keccak256("m426-generic-allocation-bypass");
        _registerRulePackageWithAdapters(
            workflowKey,
            allocationAdapter,
            consequenceAdapter,
            standingAdapter,
            new MockRewardAdapter(7),
            new MockPriorityAdapter(7),
            penaltyAdapter,
            restorationAdapter,
            "ipfs://m426-generic-allocation-bypass"
        );
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m426-generic-allocation-evidence"),
            "ipfs://m426-generic-allocation-evidence",
            "allocation-bypass-basis",
            0
        );
        uint256 recognisedStateId = _registerRecognisedStateForWorkflowStatus(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, evidenceId, "m426-generic-allocation-state"
        );
        uint256 nextAllocationId = allocationExecutor.nextAllocationExecutionId();

        try allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            AVADataTypes.AllocationKind.RewardValueRecord,
            REVIEWER_SUBJECT,
            7,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://m426-generic-reward-bypass"
        ) {
            revert("generic allocation bypassed reward adapter");
        } catch {}
        try allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            AVADataTypes.AllocationKind.AdministrativeQueueRecord,
            REVIEWER_SUBJECT,
            7,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://m426-generic-priority-bypass"
        ) {
            revert("generic allocation bypassed priority adapter");
        } catch {}
        require(
            allocationExecutor.nextAllocationExecutionId() == nextAllocationId, "generic downstream allocation stored"
        );
    }
}

contract AVASkeletonLifecycle02BAATest is AVASkeletonFixture {
    function testM426GenericConsequenceCannotBypassPenaltyOrRestorationAdapters() public {
        bytes32 workflowKey = keccak256("m426-generic-consequence-bypass");
        bytes32 blockedAuthorityId = keccak256("panel-authority");
        _registerRulePackageWithAdapters(
            workflowKey,
            allocationAdapter,
            consequenceAdapter,
            standingAdapter,
            rewardAdapter,
            priorityAdapter,
            new MockPenaltyAdapter(blockedAuthorityId),
            new MockRestorationAdapter(blockedAuthorityId),
            "ipfs://m426-generic-consequence-bypass"
        );
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m426-generic-consequence-evidence"),
            "ipfs://m426-generic-consequence-evidence",
            "consequence-bypass-basis",
            0
        );
        uint256 recognisedStateId = _registerRecognisedStateForWorkflowStatus(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, evidenceId, "m426-generic-consequence-state"
        );
        uint256 nextConsequenceId = consequenceExecutor.nextConsequenceId();

        try consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            AVADataTypes.ConsequenceKind.PenaltyRecord,
            REVIEWER_SUBJECT,
            evidenceId,
            blockedAuthorityId,
            "ipfs://m426-generic-penalty-bypass"
        ) {
            revert("generic consequence bypassed penalty adapter");
        } catch {}
        try consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            AVADataTypes.ConsequenceKind.RestorationRecord,
            REVIEWER_SUBJECT,
            evidenceId,
            blockedAuthorityId,
            "ipfs://m426-generic-restoration-bypass"
        ) {
            revert("generic consequence bypassed restoration adapter");
        } catch {}
        require(consequenceExecutor.nextConsequenceId() == nextConsequenceId, "generic specialised consequence stored");
    }
}

contract AVASkeletonLifecycle02BABTest is AVASkeletonFixture {
    function testM418ParameterizedValueExecutionRemainsRecordOnly() public {
        bytes32 workflowKey = keccak256("m418-parameterized-value");
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            new ClaimEscrowRecordValueAdapter(),
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m4-10-compatible"),
            false,
            "ipfs://m418-parameterized-value"
        );
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m418-parameterized-value-evidence"),
            "ipfs://m418-parameterized-value-evidence",
            "value-record-basis",
            0
        );
        uint256 recognisedStateId = _registerRecognisedStateForWorkflowStatus(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, evidenceId, "m418-parameterized-value-state"
        );
        uint256 nextConsequenceId = consequenceExecutor.nextConsequenceId();
        uint256 executorBalanceBefore = address(allocationExecutor).balance;

        uint256 recordId = allocationExecutor.recordRewardValueWithExecution(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ValueExecutionContext({
                recognisedStateId: recognisedStateId,
                asset: address(0xA11CE),
                payer: address(this),
                recipientSubjectId: REVIEWER_SUBJECT,
                amount: 1,
                mode: AVADataTypes.ValueExecutionMode.Claim,
                settlementKind: AVADataTypes.ValueSettlementKind.TokenTransfer,
                executionReference: keccak256("m418-claim-record"),
                authorityId: keccak256("executor-authority"),
                evidenceReceiptId: evidenceId,
                uri: "ipfs://m418-claim-record",
                actor: address(this)
            })
        );
        AVADataTypes.AllocationExecutionRecord memory record = allocationExecutor.getAllocationExecution(recordId);
        require(record.executionMode == AVADataTypes.ValueExecutionMode.Claim, "nondefault mode not recorded");
        require(record.asset == address(0xA11CE), "asset reference not recorded");
        require(address(allocationExecutor).balance == executorBalanceBefore, "value adapter transferred value");
        require(consequenceExecutor.nextConsequenceId() == nextConsequenceId, "value adapter created consequence");
        _assertNoSelector(
            address(rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).valueExecutionAdapter), "transferToken(uint256)"
        );
        _assertNoSelector(
            address(rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).valueExecutionAdapter), "executeQueue(uint256)"
        );
        _assertNoSelector(
            address(rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).valueExecutionAdapter), "executeSanction(uint256)"
        );
    }
}

contract AVASkeletonLifecycle02BBATest is AVASkeletonFixture {
    function testM419CustomModulesImplementInterfacesAndSwapWithoutSubstrateChange() public {
        bytes32 workflowKey = keccak256("m419-custom-interface-package");
        AVARulePackageRegistry.RulePackageModules memory modules = _m419CustomInterfaceModules();
        rulePackageRegistry.registerRulePackage(
            AVADataTypes.Role.Panel, PEER_REVIEW_APP_ID, workflowKey, modules, "ipfs://m419-custom-interface-package"
        );
        AVARulePackageRegistry.RulePackage memory rulePackage = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey);
        require(rulePackage.modulesHash == rulePackageRegistry.hashModules(modules), "custom modules hash mismatch");
        IAllocationAdapter allocationInterface = modules.allocationModule;
        IZKProofVerifier proofVerifier = new SchnorrDisclosureProofVerifier();
        require(address(allocationInterface) == address(modules.allocationModule), "allocation ABI mismatch");
        require(address(proofVerifier) != address(0), "zk verifier ABI missing");

        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m419-interface-evidence"),
            "ipfs://m419-interface-evidence",
            "m419-interface-evidence",
            0
        );
        uint256 recognisedStateId = stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            PEER_REVIEW_APP_ID,
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            keccak256("m419-interface-object"),
            REVIEWER_SUBJECT,
            evidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        );
        stateMachine.transitionRecognisedState(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            AVADataTypes.RecognisedStateStatus.Vested,
            keccak256("panel-authority"),
            "ipfs://m419-interface-transition"
        );

        AVADataTypes.RecognisedStateRecord memory recognisedState = stateMachine.getRecognisedState(recognisedStateId);
        require(recognisedState.packageId == rulePackage.packageId, "substrate did not bind custom package");
        require(
            recognisedState.status == AVADataTypes.RecognisedStateStatus.Vested,
            "custom modules blocked compatible substrate path"
        );
    }
}

contract AVASkeletonLifecycle03AAATest is AVASkeletonFixture {
    function testM410FutureProofInterfacesHaveDefaultsAndRecordOnlyValueMode() public {
        valueExecutionAdapter.validateValueExecution(
            AVADataTypes.ValueExecutionContext({
                recognisedStateId: 1,
                asset: address(0),
                payer: address(0),
                recipientSubjectId: REVIEWER_SUBJECT,
                amount: 1,
                mode: AVADataTypes.ValueExecutionMode.RecordOnly,
                settlementKind: AVADataTypes.ValueSettlementKind.None,
                executionReference: keccak256("m410-value-record"),
                authorityId: keccak256("authority"),
                evidenceReceiptId: 1,
                uri: "ipfs://m410-value",
                actor: address(this)
            })
        );
        try valueExecutionAdapter.validateValueExecution(
            AVADataTypes.ValueExecutionContext({
                recognisedStateId: 1,
                asset: address(0),
                payer: address(0),
                recipientSubjectId: REVIEWER_SUBJECT,
                amount: 1,
                mode: AVADataTypes.ValueExecutionMode.Claim,
                settlementKind: AVADataTypes.ValueSettlementKind.TokenTransfer,
                executionReference: keccak256("m410-claim"),
                authorityId: keccak256("authority"),
                evidenceReceiptId: 1,
                uri: "ipfs://m410-claim",
                actor: address(this)
            })
        ) {
            revert("default value adapter accepted executable mode");
        } catch {}

        standingComputationModule.validateStandingComputation(
            AVADataTypes.StandingComputationContext({
                recognisedStateId: 1,
                subjectId: REVIEWER_SUBJECT,
                dimension: "review-vector-weight",
                vectorKey: keccak256("review-vector-weight"),
                currentValue: 0,
                delta: 1,
                effectiveAt: 0,
                epoch: 1,
                sourceRecordSetHash: keccak256("m410-standing-source-set"),
                computationRuleHash: _m422ComputationRuleHash(),
                reversible: true,
                fieldKey: keccak256("field"),
                evidenceReceiptId: 1,
                authorityId: keccak256("authority"),
                actor: address(this)
            })
        );
        rulePackageLifecycleModule.validateRulePackageLifecycle(
            IRulePackageLifecycleModule.RulePackageLifecycleContext({
                workflowKey: DEFAULT_WORKFLOW,
                modulesHash: keccak256("m410-default-modules"),
                modulesIdentityHash: keccak256("m410-default-modules-code"),
                kind: AVADataTypes.RulePackageLifecycleKind.None,
                version: 1,
                compatibilityKey: keccak256("ava-m4-10-compatible"),
                dependencyURI: "",
                deprecated: false,
                targetWorkflowKey: bytes32(0),
                targetPackageId: 0,
                targetModulesHash: bytes32(0),
                targetModulesIdentityHash: bytes32(0),
                targetVersion: 0,
                targetCompatibilityKey: bytes32(0),
                authorityRole: AVADataTypes.Role.Panel,
                actor: address(this)
            })
        );
        evidenceLifecycleModule.validateEvidenceLifecycle(
            DEFAULT_WORKFLOW,
            AVADataTypes.Action.RegisterRecognisedState,
            1,
            AVADataTypes.EvidenceLifecycleKind.None,
            0,
            bytes32(0),
            address(this)
        );
    }
}

contract AVASkeletonLifecycle03AABTest is AVASkeletonFixture {
    function testM410RulePackageBindsFutureProofModulesAndPreservesRetrieval() public {
        bytes32 workflowKey = keccak256("m410-future-package");
        ClaimEscrowRecordValueAdapter valueModule = new ClaimEscrowRecordValueAdapter();
        VectorStandingComputationModule standingModule = new VectorStandingComputationModule();
        VersionedRulePackageLifecycleModule lifecycleModule = new VersionedRulePackageLifecycleModule(2);
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueModule,
            standingModule,
            lifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            2,
            keccak256("ava-m4-10-compatible"),
            false,
            "ipfs://m410-future-package"
        );

        AVARulePackageRegistry.RulePackage memory rulePackage = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey);
        require(address(rulePackage.valueExecutionAdapter) == address(valueModule), "value module not bound");
        require(address(rulePackage.standingComputationModule) == address(standingModule), "standing module not bound");
        require(
            address(rulePackage.rulePackageLifecycleModule) == address(lifecycleModule), "lifecycle module not bound"
        );
        require(rulePackage.version == 2, "wrong version");
        require(rulePackage.compatibilityKey == keccak256("ava-m4-10-compatible"), "wrong compatibility key");
        require(!rulePackage.deprecated, "unexpected deprecated package");

        try rulePackageLifecycleModule.validateRulePackageLifecycle(
            IRulePackageLifecycleModule.RulePackageLifecycleContext({
                workflowKey: keccak256("m410-deprecated-package"),
                modulesHash: keccak256("m410-deprecated-modules"),
                modulesIdentityHash: keccak256("m410-deprecated-modules-code"),
                kind: AVADataTypes.RulePackageLifecycleKind.None,
                version: 1,
                compatibilityKey: keccak256("ava-m4-10-compatible"),
                dependencyURI: "ipfs://m410-deprecated",
                deprecated: true,
                targetWorkflowKey: bytes32(0),
                targetPackageId: 0,
                targetModulesHash: bytes32(0),
                targetModulesIdentityHash: bytes32(0),
                targetVersion: 0,
                targetCompatibilityKey: bytes32(0),
                authorityRole: AVADataTypes.Role.Panel,
                actor: address(this)
            })
        ) {
            revert("deprecated package lifecycle accepted");
        } catch {}
    }
}

contract AVASkeletonLifecycle03ABATest is AVASkeletonFixture {
    function testM410ValueExecutionAdapterIsRecordOnlyOnRewardPath() public {
        bytes32 workflowKey = keccak256("m410-value-path");
        _ensureWorkflowPackage(workflowKey);
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m4-10-compatible"),
            false,
            "ipfs://m410-value-path"
        );
        (uint256 recognisedStateId, uint256 evidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, "m410-value-state"
        );

        uint256 rewardId = allocationExecutor.recordRewardValue(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://m410-value-record"
        );
        require(
            allocationExecutor.getAllocationExecution(rewardId).allocationKind
                == AVADataTypes.AllocationKind.RewardValueRecord,
            "wrong reward record kind"
        );
        _assertNoSelector(
            address(rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).valueExecutionAdapter), "transferToken(uint256)"
        );
        _assertNoSelector(
            address(rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).valueExecutionAdapter), "payStablecoin(uint256)"
        );
        _assertNoSelector(
            address(rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).valueExecutionAdapter), "executePayment(uint256)"
        );
    }
}

contract AVASkeletonLifecycle03BAATest is AVASkeletonFixture {
    function testM410StandingComputationRejectsPublicPrestigeSingleScore() public {
        bytes32 workflowKey = keccak256("m410-standing-path");
        _ensureWorkflowPackage(workflowKey);
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m4-10-compatible"),
            false,
            "ipfs://m410-standing-path"
        );
        (uint256 recognisedStateId, uint256 evidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, "m410-standing-state"
        );

        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            "public-prestige",
            1,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://m410-public-prestige"
        ) {
            revert("standing computation accepted public prestige");
        } catch {}
        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            "single-score",
            1,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://m410-single-score"
        ) {
            revert("standing computation accepted single score");
        } catch {}
    }
}

contract AVASkeletonLifecycle03BABTest is AVASkeletonFixture {
    function testM410EvidenceLifecycleDefaultPassesAndRejectingModuleBlocksUse() public {
        bytes32 defaultWorkflow = keccak256("m410-evidence-default");
        _ensureWorkflowPackage(defaultWorkflow);
        _registerRulePackageWithFutureProofModules(
            defaultWorkflow,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m4-10-compatible"),
            false,
            "ipfs://m410-evidence-default"
        );
        (uint256 stateId,) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            defaultWorkflow, AVADataTypes.RecognisedStateStatus.Registered, "m410-evidence-default-state"
        );
        require(stateMachine.getRecognisedState(stateId).id == stateId, "default evidence lifecycle blocked state");

        bytes32 rejectingWorkflow = keccak256("m410-evidence-rejecting");
        _registerRulePackageWithFutureProofModules(
            rejectingWorkflow,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            new RejectingEvidenceLifecycleModule(AVADataTypes.Action.RegisterRecognisedState),
            disclosureExecutionModule,
            1,
            keccak256("ava-m4-10-compatible"),
            false,
            "ipfs://m410-evidence-rejecting"
        );
        uint256 rejectingEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            rejectingWorkflow,
            keccak256("m410-rejecting-evidence"),
            "ipfs://m410-rejecting-evidence",
            "evidence-lifecycle-basis",
            0
        );
        try stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            PEER_REVIEW_APP_ID,
            rejectingWorkflow,
            AVADataTypes.AVAStage.Verification,
            keccak256("m410-rejecting-object"),
            REVIEWER_SUBJECT,
            rejectingEvidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        ) {
            revert("rejecting evidence lifecycle accepted evidence use");
        } catch {}
    }
}

contract AVASkeletonLifecycle03BBATest is AVASkeletonFixture {
    struct M411ValueReadinessContext {
        bytes32 workflowKey;
        bytes32 blockedReference;
        uint256 recognisedStateId;
        uint256 evidenceId;
        uint256 penaltyStateId;
        uint256 penaltyChallengeId;
        uint256 penaltyEvidenceId;
    }

    function testM411ValueExecutionReadinessRoutesRewardPriorityPenaltyAndRestoration() public {
        M411ValueReadinessContext memory context = _prepareM411ValueReadinessContext();
        _assertM411AllocationRecords(context);
        _assertM411ConsequenceRecords(context);
        _assertM411BlockedRecords(context);

        address adapter = address(rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, context.workflowKey).valueExecutionAdapter);
        _assertNoSelector(adapter, "transferToken(uint256)");
        _assertNoSelector(adapter, "payStablecoin(uint256)");
        _assertNoSelector(adapter, "executeQueue(uint256)");
        _assertNoSelector(adapter, "executeSanction(uint256)");
    }

    function _prepareM411ValueReadinessContext() internal returns (M411ValueReadinessContext memory context) {
        context.workflowKey = keccak256("m411-value-readiness");
        _ensureWorkflowPackage(context.workflowKey);
        context.blockedReference = keccak256(bytes("ipfs://m411-blocked-priority"));
        _registerRulePackageWithFutureProofModules(
            context.workflowKey,
            new MockValueExecutionAdapter(
                context.blockedReference, address(0xBEEF), AVADataTypes.ValueExecutionMode.Claim
            ),
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m4-11-compatible"),
            false,
            "ipfs://m411-value-readiness"
        );
        (context.recognisedStateId, context.evidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            context.workflowKey, AVADataTypes.RecognisedStateStatus.Vested, "m411-value-state"
        );
        (context.penaltyStateId, context.penaltyChallengeId, context.penaltyEvidenceId) =
            _createResolvedChallengeForWorkflowSubject(
                context.workflowKey,
                REVIEWER_SUBJECT,
                "m411-value-penalty",
                AVADataTypes.ChallengeOutcome.Upheld,
                AVADataTypes.RecognisedStateStatus.Downgraded
            );
    }

    function _assertM411AllocationRecords(M411ValueReadinessContext memory context) internal {
        uint256 rewardId = allocationExecutor.recordRewardValue(
            AVADataTypes.Role.ProtocolExecutor,
            context.recognisedStateId,
            REVIEWER_SUBJECT,
            2,
            context.evidenceId,
            keccak256("executor-authority"),
            "ipfs://m411-reward"
        );
        uint256 priorityId = allocationExecutor.recordAdministrativePriority(
            AVADataTypes.Role.ProtocolExecutor,
            context.recognisedStateId,
            REVIEWER_SUBJECT,
            3,
            context.evidenceId,
            keccak256("executor-authority"),
            "ipfs://m411-priority"
        );
        require(
            allocationExecutor.getAllocationExecution(rewardId).executionMode
                == AVADataTypes.ValueExecutionMode.RecordOnly,
            "reward not record-only"
        );
        AVADataTypes.AllocationExecutionRecord memory priorityRecord =
            allocationExecutor.getAllocationExecution(priorityId);
        require(priorityRecord.executionMode == AVADataTypes.ValueExecutionMode.RecordOnly, "priority not record-only");
        require(priorityRecord.executionReference == keccak256(bytes("ipfs://m411-priority")), "priority ref missing");
    }

    function _assertM411ConsequenceRecords(M411ValueReadinessContext memory context) internal {
        uint256 penaltyId = _recordPenaltyForChallenge(
            context.penaltyStateId,
            context.penaltyChallengeId,
            AVADataTypes.GovernanceFindingKind.IrresponsibleReview,
            REVIEWER_SUBJECT,
            context.penaltyEvidenceId,
            keccak256("panel-authority"),
            "ipfs://m411-penalty"
        );
        uint256 restorationId = consequenceExecutor.recordRestoration(
            AVADataTypes.Role.Panel,
            context.recognisedStateId,
            REVIEWER_SUBJECT,
            context.evidenceId,
            keccak256("panel-authority"),
            "ipfs://m411-restoration"
        );
        AVADataTypes.ConsequenceRecord memory penaltyRecord = consequenceExecutor.getConsequence(penaltyId);
        AVADataTypes.ConsequenceRecord memory restorationRecord = consequenceExecutor.getConsequence(restorationId);
        require(penaltyRecord.executionMode == AVADataTypes.ValueExecutionMode.RecordOnly, "penalty not record-only");
        require(
            restorationRecord.executionMode == AVADataTypes.ValueExecutionMode.RecordOnly, "restoration not record-only"
        );
        require(penaltyRecord.amountOrUnits == 1, "penalty readiness units missing");
        require(restorationRecord.amountOrUnits == 1, "restoration readiness units missing");
    }

    function _assertM411BlockedRecords(M411ValueReadinessContext memory context) internal {
        try allocationExecutor.recordAdministrativePriority(
            AVADataTypes.Role.ProtocolExecutor,
            context.recognisedStateId,
            REVIEWER_SUBJECT,
            1,
            context.evidenceId,
            keccak256("executor-authority"),
            "ipfs://m411-blocked-priority"
        ) {
            revert("priority bypassed value execution adapter");
        } catch {}
        try allocationExecutor.recordRewardValue(
            AVADataTypes.Role.ProtocolExecutor,
            context.recognisedStateId,
            REVIEWER_SUBJECT,
            1,
            context.evidenceId,
            keccak256("executor-authority"),
            "ipfs://m411-blocked-priority"
        ) {
            revert("reward bypassed value execution adapter");
        } catch {}
        _assertPenaltyValueAdapterRejects(
            context.penaltyStateId, context.penaltyChallengeId, context.penaltyEvidenceId, context.blockedReference
        );
        try consequenceExecutor.recordRestoration(
            AVADataTypes.Role.Panel,
            context.recognisedStateId,
            REVIEWER_SUBJECT,
            context.evidenceId,
            keccak256("panel-authority"),
            "ipfs://m411-blocked-priority"
        ) {
            revert("restoration bypassed value execution adapter");
        } catch {}
    }
}

contract AVASkeletonLifecycle04AAATest is AVASkeletonFixture {
    function testM411RulePackageLifecycleRecordsReadinessWithoutMigrationExecution() public {
        bytes32 workflowKey = keccak256("m411-lifecycle-source");
        bytes32 targetWorkflowKey = keccak256("m411-lifecycle-target");
        _registerRulePackageWithFutureProofModules(
            targetWorkflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            3,
            keccak256("ava-m4-11-compatible"),
            false,
            "ipfs://m411-lifecycle-target"
        );
        AVARulePackageRegistry.RulePackage memory targetPackage = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, targetWorkflowKey);
        uint256 targetPackageId = targetPackage.packageId;
        TargetAwareRulePackageLifecycleModule targetAwareLifecycleModule = new TargetAwareRulePackageLifecycleModule(
            targetWorkflowKey,
            targetPackageId,
            targetPackage.modulesHash,
            targetPackage.modulesIdentityHash,
            targetPackage.version,
            targetPackage.compatibilityKey
        );
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            targetAwareLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            3,
            keccak256("ava-m4-11-compatible"),
            false,
            "ipfs://m411-lifecycle-source"
        );
        try rulePackageLifecycleRegistry.recordRulePackageLifecycle(
            AVADataTypes.Role.Panel,
            PEER_REVIEW_APP_ID, workflowKey,
            AVADataTypes.RulePackageLifecycleKind.MigrationReady,
            keccak256("m411-lifecycle-unknown-target"),
            "ipfs://m411-unknown-migration"
        ) {
            revert("migration readiness accepted unknown target");
        } catch {}
        bytes32 wrongTargetWorkflowKey = keccak256("m411-lifecycle-wrong-target");
        _registerRulePackageWithFutureProofModules(
            wrongTargetWorkflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            3,
            keccak256("ava-m4-11-compatible"),
            false,
            "ipfs://m411-lifecycle-wrong-target"
        );

        uint256 deprecationRecordId = rulePackageLifecycleRegistry.recordRulePackageLifecycle(
            AVADataTypes.Role.Panel,
            PEER_REVIEW_APP_ID, workflowKey,
            AVADataTypes.RulePackageLifecycleKind.DeprecationReady,
            bytes32(0),
            "ipfs://m411-deprecation"
        );
        try rulePackageLifecycleRegistry.recordRulePackageLifecycle(
            AVADataTypes.Role.Panel,
            PEER_REVIEW_APP_ID, workflowKey,
            AVADataTypes.RulePackageLifecycleKind.MigrationReady,
            wrongTargetWorkflowKey,
            "ipfs://m411-wrong-target-context"
        ) {
            revert("migration readiness did not expose target package context");
        } catch {}
        uint256 migrationRecordId = rulePackageLifecycleRegistry.recordRulePackageLifecycle(
            AVADataTypes.Role.Panel,
            PEER_REVIEW_APP_ID, workflowKey,
            AVADataTypes.RulePackageLifecycleKind.MigrationReady,
            targetWorkflowKey,
            "ipfs://m411-migration"
        );

        AVADataTypes.RulePackageLifecycleRecord memory deprecationRecord =
            rulePackageLifecycleRegistry.getRulePackageLifecycleRecord(deprecationRecordId);
        AVADataTypes.RulePackageLifecycleRecord memory migrationRecord =
            rulePackageLifecycleRegistry.getRulePackageLifecycleRecord(migrationRecordId);
        require(
            deprecationRecord.kind == AVADataTypes.RulePackageLifecycleKind.DeprecationReady,
            "deprecation readiness missing"
        );
        require(deprecationRecord.targetPackageId == 0, "deprecation target package set");
        require(migrationRecord.targetWorkflowKey == targetWorkflowKey, "migration target missing");
        require(migrationRecord.targetPackageId == targetPackageId, "migration target package missing");
        require(deprecationRecord.authorityId == keccak256("panel-authority"), "deprecation authority missing");
        require(migrationRecord.authorityId == keccak256("panel-authority"), "migration authority missing");
        require(rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).active, "lifecycle record deactivated package");
        require(!rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).deprecated, "lifecycle record mutated deprecation");
        _registerRulePackageWithFutureProofModules(
            targetWorkflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            4,
            keccak256("ava-m4-11-compatible"),
            false,
            "ipfs://m411-lifecycle-target-v2"
        );
        uint256 newTargetPackageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, targetWorkflowKey).packageId;
        require(newTargetPackageId != targetPackageId, "target package did not rotate");
        AVADataTypes.RulePackageLifecycleRecord memory migrationRecordAfterRotation =
            rulePackageLifecycleRegistry.getRulePackageLifecycleRecord(migrationRecordId);
        require(migrationRecordAfterRotation.targetPackageId == targetPackageId, "migration target package drifted");

        try rulePackageLifecycleRegistry.recordRulePackageLifecycle(
            AVADataTypes.Role.Panel,
            PEER_REVIEW_APP_ID, workflowKey,
            AVADataTypes.RulePackageLifecycleKind.MigrationReady,
            bytes32(0),
            "ipfs://m411-missing-target"
        ) {
            revert("migration readiness accepted missing target");
        } catch {}
        _assertNoSelector(address(rulePackageRegistry), "executeMigration(bytes32)");
        _assertNoSelector(address(rulePackageRegistry), "migrateRulePackage(bytes32)");
    }
}

contract AVASkeletonLifecycle04AABTest is AVASkeletonFixture {
    function testM52RulePackageLifecycleRecordBindsExplicitSourceAndTargetPackages() public {
        bytes32 workflowKey = keccak256("m52-lifecycle-source");
        bytes32 targetWorkflowKey = keccak256("m52-lifecycle-target");
        _registerRulePackageWithFutureProofModules(
            targetWorkflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            7,
            keccak256("ava-m5-2-compatible"),
            false,
            "ipfs://m52-lifecycle-target"
        );
        AVARulePackageRegistry.RulePackage memory targetPackage = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, targetWorkflowKey);
        TargetAwareRulePackageLifecycleModule targetAwareLifecycleModule = new TargetAwareRulePackageLifecycleModule(
            targetWorkflowKey,
            targetPackage.packageId,
            targetPackage.modulesHash,
            targetPackage.modulesIdentityHash,
            targetPackage.version,
            targetPackage.compatibilityKey
        );
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            targetAwareLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            5,
            keccak256("ava-m5-2-compatible"),
            false,
            "ipfs://m52-lifecycle-source"
        );
        AVARulePackageRegistry.RulePackage memory sourcePackage = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey);

        uint256 lifecycleRecordId = rulePackageLifecycleRegistry.recordRulePackageLifecycleForPackage(
            AVADataTypes.Role.Panel,
            sourcePackage.packageId,
            AVADataTypes.RulePackageLifecycleKind.MigrationReady,
            targetPackage.packageId,
            "ipfs://m52-explicit-migration"
        );
        AVADataTypes.RulePackageLifecycleRecord memory record =
            rulePackageLifecycleRegistry.getRulePackageLifecycleRecord(lifecycleRecordId);

        require(record.workflowKey == workflowKey, "source workflow not bound");
        require(record.packageId == sourcePackage.packageId, "source package not bound");
        require(record.modulesHash == sourcePackage.modulesHash, "source modules hash not bound");
        require(record.modulesIdentityHash == sourcePackage.modulesIdentityHash, "source modules code hash not bound");
        require(record.version == sourcePackage.version, "source version not bound");
        require(record.compatibilityKey == sourcePackage.compatibilityKey, "source compatibility not bound");
        require(record.targetWorkflowKey == targetWorkflowKey, "target workflow not bound");
        require(record.targetPackageId == targetPackage.packageId, "target package not bound");
        require(record.targetModulesHash == targetPackage.modulesHash, "target modules hash not bound");
        require(
            record.targetModulesIdentityHash == targetPackage.modulesIdentityHash, "target modules code hash not bound"
        );
        require(record.targetVersion == targetPackage.version, "target version not bound");
        require(record.targetCompatibilityKey == targetPackage.compatibilityKey, "target compatibility not bound");

        _registerRulePackageWithFutureProofModules(
            targetWorkflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            8,
            keccak256("ava-m5-2-compatible"),
            false,
            "ipfs://m52-lifecycle-target-v2"
        );
        AVADataTypes.RulePackageLifecycleRecord memory recordAfterTargetRotation =
            rulePackageLifecycleRegistry.getRulePackageLifecycleRecord(lifecycleRecordId);
        require(recordAfterTargetRotation.targetPackageId == targetPackage.packageId, "target package drifted");
        require(recordAfterTargetRotation.targetModulesHash == targetPackage.modulesHash, "target modules hash drifted");
        require(
            recordAfterTargetRotation.targetModulesIdentityHash == targetPackage.modulesIdentityHash,
            "target modules code hash drifted"
        );
    }
}

contract AVASkeletonLifecycle04ABATest is AVASkeletonFixture {
    struct M52ObjectMigrationContext {
        bytes32 workflowKey;
        bytes32 targetWorkflowKey;
        uint256 sourcePackageId;
        uint256 targetPackageId;
        uint256 recognisedStateId;
        uint256 evidenceId;
        uint256 lifecycleRecordId;
        uint256 readinessId;
    }

    function testM52ObjectMigrationReadinessBindsObjectSourceTargetAuthorityAndEvidence() public {
        M52ObjectMigrationContext memory context = _prepareM52ObjectMigrationContext();
        _assertM52ObjectMigrationRecord(context);
        _assertM52ObjectMigrationTargetRemainsPinned(context);
        _assertM52DeprecationCannotCreateObjectMigration(context);
        _assertNoSelector(address(rulePackageRegistry), "executeObjectMigration(uint256)");
    }

    function _prepareM52ObjectMigrationContext() internal returns (M52ObjectMigrationContext memory context) {
        context.workflowKey = keccak256("m52-object-migration-source");
        context.targetWorkflowKey = keccak256("m52-object-migration-target");
        _registerRulePackageWithFutureProofModules(
            context.workflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m5-2-compatible"),
            false,
            "ipfs://m52-object-source"
        );
        _registerRulePackageWithFutureProofModules(
            context.targetWorkflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m5-2-compatible"),
            false,
            "ipfs://m52-object-target"
        );
        context.sourcePackageId = rulePackageRegistry.getActivePackageId(PEER_REVIEW_APP_ID, context.workflowKey);
        context.targetPackageId = rulePackageRegistry.getActivePackageId(PEER_REVIEW_APP_ID, context.targetWorkflowKey);
        (context.recognisedStateId, context.evidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            context.workflowKey, AVADataTypes.RecognisedStateStatus.Registered, "m52-object-migration-state"
        );
        context.lifecycleRecordId = rulePackageLifecycleRegistry.recordRulePackageLifecycleForPackage(
            AVADataTypes.Role.Panel,
            context.sourcePackageId,
            AVADataTypes.RulePackageLifecycleKind.MigrationReady,
            context.targetPackageId,
            "ipfs://m52-object-package-migration"
        );
        context.readinessId = rulePackageLifecycleRegistry.recordObjectMigrationReadiness(
            AVADataTypes.Role.Panel,
            AVARulePackageLifecycleRegistry.ObjectMigrationReadinessInput({
                lifecycleRecordId: context.lifecycleRecordId,
                objectId: bytes32(context.recognisedStateId),
                recognisedStateId: context.recognisedStateId,
                evidenceReceiptId: context.evidenceId,
                boundaryHash: keccak256("m52-object-boundary"),
                authorityId: keccak256("panel-authority"),
                uri: "ipfs://m52-object-migration-readiness"
            })
        );
    }

    function _assertM52ObjectMigrationRecord(M52ObjectMigrationContext memory context) internal view {
        AVADataTypes.ObjectMigrationReadinessRecord memory readiness =
            rulePackageLifecycleRegistry.getObjectMigrationReadinessRecord(context.readinessId);

        require(readiness.lifecycleRecordId == context.lifecycleRecordId, "lifecycle record not bound");
        require(readiness.workflowKey == context.workflowKey, "source workflow not bound");
        require(readiness.packageId == context.sourcePackageId, "source package not bound");
        require(readiness.targetWorkflowKey == context.targetWorkflowKey, "target workflow not bound");
        require(readiness.targetPackageId == context.targetPackageId, "target package not bound");
        require(readiness.objectId == bytes32(context.recognisedStateId), "object not bound");
        require(readiness.recognisedStateId == context.recognisedStateId, "recognised state not bound");
        require(readiness.evidenceReceiptId == context.evidenceId, "evidence not bound");
        require(readiness.boundaryHash == keccak256("m52-object-boundary"), "boundary not bound");
        require(readiness.authorityId == keccak256("panel-authority"), "authority not bound");
        require(readiness.createdAt == block.timestamp, "object migration timestamp missing");
        require(
            stateMachine.getRecognisedState(context.recognisedStateId).packageId == context.sourcePackageId,
            "readiness migrated state"
        );
    }

    function _assertM52ObjectMigrationTargetRemainsPinned(M52ObjectMigrationContext memory context) internal {
        _registerRulePackageWithFutureProofModules(
            context.targetWorkflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            2,
            keccak256("ava-m5-2-compatible"),
            false,
            "ipfs://m52-object-target-v2"
        );
        AVADataTypes.ObjectMigrationReadinessRecord memory afterTargetRotation =
            rulePackageLifecycleRegistry.getObjectMigrationReadinessRecord(context.readinessId);
        require(afterTargetRotation.targetPackageId == context.targetPackageId, "object target package drifted");
    }

    function _assertM52DeprecationCannotCreateObjectMigration(M52ObjectMigrationContext memory context) internal {
        uint256 deprecationRecordId = rulePackageLifecycleRegistry.recordRulePackageLifecycleForPackage(
            AVADataTypes.Role.Panel,
            context.sourcePackageId,
            AVADataTypes.RulePackageLifecycleKind.DeprecationReady,
            0,
            "ipfs://m52-object-deprecation"
        );
        try rulePackageLifecycleRegistry.recordObjectMigrationReadiness(
            AVADataTypes.Role.Panel,
            AVARulePackageLifecycleRegistry.ObjectMigrationReadinessInput({
                lifecycleRecordId: deprecationRecordId,
                objectId: bytes32(context.recognisedStateId),
                recognisedStateId: context.recognisedStateId,
                evidenceReceiptId: context.evidenceId,
                boundaryHash: keccak256("m52-invalid-boundary"),
                authorityId: keccak256("panel-authority"),
                uri: "ipfs://m52-invalid-object-migration"
            })
        ) {
            revert("object migration accepted non-migration lifecycle");
        } catch {}
    }
}

contract AVASkeletonLifecycle04BAATest is AVASkeletonFixture {
    function testM52ObjectMigrationReadinessRejectsWrongPackageStateAndEvidence() public {
        bytes32 workflowKey = keccak256("m52-object-migration-source-hardening");
        bytes32 targetWorkflowKey = keccak256("m52-object-migration-target-hardening");
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m5-2-compatible"),
            false,
            "ipfs://m52-object-source-hardening"
        );
        _registerRulePackageWithFutureProofModules(
            targetWorkflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m5-2-compatible"),
            false,
            "ipfs://m52-object-target-hardening"
        );
        AVARulePackageRegistry.RulePackage memory sourcePackage = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey);
        AVARulePackageRegistry.RulePackage memory targetPackage = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, targetWorkflowKey);
        (uint256 sourceStateId, uint256 sourceEvidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowKey, AVADataTypes.RecognisedStateStatus.Registered, "m52-object-source-hardening"
        );
        (uint256 targetStateId, uint256 targetEvidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            targetWorkflowKey, AVADataTypes.RecognisedStateStatus.Registered, "m52-object-target-hardening"
        );
        uint256 lifecycleRecordId = rulePackageLifecycleRegistry.recordRulePackageLifecycleForPackage(
            AVADataTypes.Role.Panel,
            sourcePackage.packageId,
            AVADataTypes.RulePackageLifecycleKind.MigrationReady,
            targetPackage.packageId,
            "ipfs://m52-object-package-migration-hardening"
        );

        try rulePackageLifecycleRegistry.recordObjectMigrationReadiness(
            AVADataTypes.Role.Panel,
            AVARulePackageLifecycleRegistry.ObjectMigrationReadinessInput({
                lifecycleRecordId: lifecycleRecordId,
                objectId: bytes32(sourceStateId),
                recognisedStateId: targetStateId,
                evidenceReceiptId: sourceEvidenceId,
                boundaryHash: keccak256("m52-wrong-state-boundary"),
                authorityId: keccak256("panel-authority"),
                uri: "ipfs://m52-wrong-state"
            })
        ) {
            revert("object migration accepted wrong-package state");
        } catch {}

        try rulePackageLifecycleRegistry.recordObjectMigrationReadiness(
            AVADataTypes.Role.Panel,
            AVARulePackageLifecycleRegistry.ObjectMigrationReadinessInput({
                lifecycleRecordId: lifecycleRecordId,
                objectId: bytes32(sourceStateId),
                recognisedStateId: sourceStateId,
                evidenceReceiptId: targetEvidenceId,
                boundaryHash: keccak256("m52-wrong-evidence-boundary"),
                authorityId: keccak256("panel-authority"),
                uri: "ipfs://m52-wrong-evidence"
            })
        ) {
            revert("object migration accepted wrong-package evidence");
        } catch {}
    }
}

contract AVASkeletonLifecycle04BABTest is AVASkeletonFixture {
    function testM52ExplicitLifecycleUsesHistoricalSourcePackageAfterWorkflowReregistration() public {
        bytes32 workflowKey = keccak256("m52-historical-source");
        bytes32 targetWorkflowKey = keccak256("m52-historical-target");
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m5-2-compatible"),
            false,
            "ipfs://m52-historical-source-v1"
        );
        AVARulePackageRegistry.RulePackage memory oldSourcePackage = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey);
        _registerRulePackageWithFutureProofModules(
            targetWorkflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m5-2-compatible"),
            false,
            "ipfs://m52-historical-target"
        );
        AVARulePackageRegistry.RulePackage memory targetPackage = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, targetWorkflowKey);

        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            new RejectingReadyRulePackageLifecycleModule(),
            evidenceLifecycleModule,
            disclosureExecutionModule,
            2,
            keccak256("ava-m5-2-compatible"),
            false,
            "ipfs://m52-historical-source-v2"
        );
        require(
            rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).packageId != oldSourcePackage.packageId,
            "source did not rotate"
        );

        try rulePackageLifecycleRegistry.recordRulePackageLifecycle(
            AVADataTypes.Role.Panel,
            PEER_REVIEW_APP_ID, workflowKey,
            AVADataTypes.RulePackageLifecycleKind.MigrationReady,
            targetWorkflowKey,
            "ipfs://m52-active-package-rejects"
        ) {
            revert("workflow-key path did not use active source package");
        } catch {}

        uint256 lifecycleRecordId = rulePackageLifecycleRegistry.recordRulePackageLifecycleForPackage(
            AVADataTypes.Role.Panel,
            oldSourcePackage.packageId,
            AVADataTypes.RulePackageLifecycleKind.MigrationReady,
            targetPackage.packageId,
            "ipfs://m52-old-package-migration"
        );
        AVADataTypes.RulePackageLifecycleRecord memory record =
            rulePackageLifecycleRegistry.getRulePackageLifecycleRecord(lifecycleRecordId);
        require(record.packageId == oldSourcePackage.packageId, "old source package not used");
        require(record.modulesHash == oldSourcePackage.modulesHash, "old source modules hash not used");
        require(record.targetPackageId == targetPackage.packageId, "target package missing");
    }
}

contract AVASkeletonLifecycle04BBATest is AVASkeletonFixture {
    function testM52ExplicitLifecycleRejectsInvalidTargetsAndHasNoMigrationExecutor() public {
        bytes32 workflowKey = keccak256("m52-invalid-source");
        bytes32 targetWorkflowKey = keccak256("m52-invalid-target");
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m5-2-compatible"),
            false,
            "ipfs://m52-invalid-source"
        );
        _registerRulePackageWithFutureProofModules(
            targetWorkflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m5-2-compatible"),
            false,
            "ipfs://m52-invalid-target"
        );
        AVARulePackageRegistry.RulePackage memory sourcePackage = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey);
        AVARulePackageRegistry.RulePackage memory targetPackage = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, targetWorkflowKey);

        try rulePackageLifecycleRegistry.recordRulePackageLifecycleForPackage(
            AVADataTypes.Role.Panel,
            sourcePackage.packageId,
            AVADataTypes.RulePackageLifecycleKind.MigrationReady,
            0,
            "ipfs://m52-missing-target"
        ) {
            revert("migration accepted missing target");
        } catch {}
        try rulePackageLifecycleRegistry.recordRulePackageLifecycleForPackage(
            AVADataTypes.Role.Panel,
            sourcePackage.packageId,
            AVADataTypes.RulePackageLifecycleKind.SupersessionReady,
            sourcePackage.packageId,
            "ipfs://m52-self-target"
        ) {
            revert("supersession accepted self target");
        } catch {}
        try rulePackageLifecycleRegistry.recordRulePackageLifecycleForPackage(
            AVADataTypes.Role.Panel,
            sourcePackage.packageId,
            AVADataTypes.RulePackageLifecycleKind.MigrationReady,
            999999,
            "ipfs://m52-unknown-target"
        ) {
            revert("migration accepted unknown target");
        } catch {}
        try rulePackageLifecycleRegistry.recordRulePackageLifecycleForPackage(
            AVADataTypes.Role.Panel,
            sourcePackage.packageId,
            AVADataTypes.RulePackageLifecycleKind.DeprecationReady,
            targetPackage.packageId,
            "ipfs://m52-deprecation-target"
        ) {
            revert("deprecation accepted target package");
        } catch {}

        uint256 supersessionRecordId = rulePackageLifecycleRegistry.recordRulePackageLifecycleForPackage(
            AVADataTypes.Role.Panel,
            sourcePackage.packageId,
            AVADataTypes.RulePackageLifecycleKind.SupersessionReady,
            targetPackage.packageId,
            "ipfs://m52-supersession"
        );
        require(
            rulePackageLifecycleRegistry.getRulePackageLifecycleRecord(supersessionRecordId).targetPackageId
                == targetPackage.packageId,
            "valid supersession missing target"
        );
        _assertNoSelector(address(rulePackageRegistry), "executeMigration(uint256)");
        _assertNoSelector(address(rulePackageRegistry), "migrateRulePackage(uint256)");
        _assertNoSelector(address(rulePackageRegistry), "applyRulePackageMigration(uint256)");
    }
}

contract AVASkeletonLifecycle05AAATest is AVASkeletonFixture {
    function testM411EvidenceLifecycleHooksRecordOnlyWithoutTruthOrReveal() public {
        roleRegistry.assignRole(
            address(this), AVADataTypes.Role.Reviewer, keccak256("m411-reviewer"), "ipfs://reviewer"
        );
        bytes32 workflowKey = keccak256("m411-evidence-lifecycle");
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m4-11-compatible"),
            false,
            "ipfs://m411-evidence-lifecycle"
        );
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m411-evidence"),
            "ipfs://m411-evidence",
            "m411-evidence-basis",
            0
        );
        uint256 replacementEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m411-replacement-evidence"),
            "ipfs://m411-replacement-evidence",
            "m411-evidence-replacement",
            0
        );

        uint256 lifecycleRecordId = reviewerActor.recordEvidenceLifecycleHook(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            evidenceId,
            AVADataTypes.EvidenceLifecycleKind.ReplacementReady,
            replacementEvidenceId,
            keccak256("m411-replacement-reference"),
            "ipfs://m411-evidence-replacement"
        );
        AVADataTypes.EvidenceLifecycleRecord memory lifecycleRecord =
            evidenceRegistry.getEvidenceLifecycleRecord(lifecycleRecordId);
        require(lifecycleRecord.evidenceReceiptId == evidenceId, "evidence lifecycle target missing");
        require(lifecycleRecord.replacementEvidenceReceiptId == replacementEvidenceId, "replacement missing");
        require(lifecycleRecord.authorityId == REVIEWER_SUBJECT, "evidence lifecycle authority missing");

        bytes32 rejectingWorkflow = keccak256("m411-reject-evidence-hook");
        _registerRulePackageWithFutureProofModules(
            rejectingWorkflow,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            new RejectingEvidenceLifecycleModule(AVADataTypes.Action.RecordEvidenceLifecycle),
            disclosureExecutionModule,
            1,
            keccak256("ava-m4-11-compatible"),
            false,
            "ipfs://m411-reject-evidence-hook"
        );
        try evidenceRegistry.recordEvidenceLifecycleHook(
            AVADataTypes.Role.Reviewer,
            PEER_REVIEW_APP_ID, rejectingWorkflow,
            evidenceId,
            AVADataTypes.EvidenceLifecycleKind.RevocationReady,
            0,
            keccak256("m411-revocation-reference"),
            "ipfs://m411-revocation"
        ) {
            revert("rejecting evidence lifecycle accepted hook");
        } catch {}

        _assertNoSelector(address(evidenceRegistry), "validateScientificTruth(uint256)");
        _assertNoSelector(address(evidenceRegistry), "revealEvidence(uint256)");
        _assertNoSelector(address(evidenceRegistry), "decryptEvidence(uint256)");
    }
}

contract AVASkeletonLifecycle05AABTest is AVASkeletonFixture {
    function testEvidenceLifecycleHookRequiresRecordLifecyclePermission() public {
        roleRegistry.assignRole(
            address(this), AVADataTypes.Role.Reviewer, keccak256("m420-lifecycle-authority"), "ipfs://reviewer"
        );
        uint256 evidenceId = evidenceRegistry.registerEvidenceReceipt(
            AVADataTypes.Role.Reviewer,
            PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW,
            keccak256("m420-lifecycle-permission-evidence"),
            "ipfs://m420-lifecycle-permission-evidence",
            "m420-lifecycle-permission-basis",
            0
        );
        authorityMatrix.setPermission(AVADataTypes.Role.Reviewer, AVADataTypes.Action.RecordEvidenceLifecycle, false);
        uint256 nextLifecycleRecordId = evidenceRegistry.nextEvidenceLifecycleRecordId();

        try evidenceRegistry.recordEvidenceLifecycleHook(
            AVADataTypes.Role.Reviewer,
            PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW,
            evidenceId,
            AVADataTypes.EvidenceLifecycleKind.ExpiryReady,
            0,
            keccak256("m420-lifecycle-permission-reference"),
            "ipfs://m420-lifecycle-permission"
        ) {
            revert("register evidence permission created lifecycle record");
        } catch {}

        require(
            evidenceRegistry.nextEvidenceLifecycleRecordId() == nextLifecycleRecordId,
            "unauthorised lifecycle record stored"
        );
    }
}

contract AVASkeletonLifecycle05AACTest is AVASkeletonFixture {
    function testAuthorisedPanelCanGovernAnotherSubjectsEvidenceLifecycle() public {
        authorityMatrix.setPermission(AVADataTypes.Role.Panel, AVADataTypes.Action.RecordEvidenceLifecycle, true);
        uint256 evidenceId = _registerM51DefaultEvidence("panel-governed-lifecycle-target");

        uint256 lifecycleRecordId = evidenceRegistry.recordEvidenceLifecycleHook(
            AVADataTypes.Role.Panel,
            PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW,
            evidenceId,
            AVADataTypes.EvidenceLifecycleKind.ExpiryReady,
            0,
            keccak256("panel-governed-lifecycle-expiry"),
            "ipfs://panel-governed-lifecycle-expiry"
        );

        AVADataTypes.EvidenceLifecycleRecord memory record =
            evidenceRegistry.getEvidenceLifecycleRecord(lifecycleRecordId);
        require(record.authorityId == keccak256("panel-authority"), "panel authority was not recorded");
        require(
            evidenceRegistry.getEvidenceReceipt(evidenceId).status == AVADataTypes.EvidenceReceiptStatus.Expired,
            "authorised panel lifecycle did not update evidence"
        );
    }

    function testPeerReviewerCannotMutateAnotherReviewersEvidenceLifecycle() public {
        bytes32 secondReviewerSubject = keccak256("second-reviewer-subject");
        roleRegistry.assignRole(
            address(outsiderActor), AVADataTypes.Role.Reviewer, secondReviewerSubject, "ipfs://second-reviewer"
        );
        uint256 evidenceId = _registerM51DefaultEvidence("peer-lifecycle-target");

        try outsiderActor.recordEvidenceLifecycleHook(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            evidenceId,
            AVADataTypes.EvidenceLifecycleKind.ExpiryReady,
            0,
            keccak256("peer-lifecycle-expiry"),
            "ipfs://peer-lifecycle-expiry"
        ) {
            revert("peer reviewer mutated another reviewer evidence");
        } catch {}
        require(
            evidenceRegistry.getEvidenceReceipt(evidenceId).status == AVADataTypes.EvidenceReceiptStatus.Active,
            "rejected peer lifecycle mutation changed evidence"
        );
    }

    function testReplacementEvidenceMustBelongToSameResponsibleSubject() public {
        bytes32 secondReviewerSubject = keccak256("replacement-second-reviewer-subject");
        roleRegistry.assignRole(
            address(outsiderActor), AVADataTypes.Role.Reviewer, secondReviewerSubject, "ipfs://replacement-reviewer"
        );
        uint256 evidenceId = _registerM51DefaultEvidence("subject-bound-replacement-target");
        uint256 replacementEvidenceId = outsiderActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            keccak256("other-subject-replacement"),
            "ipfs://other-subject-replacement",
            "m51-evidence",
            0
        );

        try reviewerActor.recordEvidenceLifecycleHook(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            evidenceId,
            AVADataTypes.EvidenceLifecycleKind.ReplacementReady,
            replacementEvidenceId,
            keccak256("other-subject-replacement-reference"),
            "ipfs://other-subject-replacement-reference"
        ) {
            revert("replacement evidence crossed responsible subjects");
        } catch {}
    }

    function testReplacementEvidenceCannotCrossHistoricalPackageBoundary() public {
        uint256 evidenceId = _registerM51DefaultEvidence("historical-package-replacement-target");
        uint256 originalPackageId = evidenceRegistry.getEvidenceReceipt(evidenceId).packageId;
        _registerRulePackageWithFutureProofModules(
            DEFAULT_WORKFLOW,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            2,
            keccak256("historical-package-replacement-compatible"),
            false,
            "ipfs://historical-package-replacement-v2"
        );
        uint256 replacementEvidenceId = _registerM51DefaultEvidence("new-package-replacement");
        require(
            evidenceRegistry.getEvidenceReceipt(replacementEvidenceId).packageId != originalPackageId,
            "test replacement did not use new package"
        );

        try reviewerActor.recordEvidenceLifecycleHook(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            evidenceId,
            AVADataTypes.EvidenceLifecycleKind.ReplacementReady,
            replacementEvidenceId,
            keccak256("cross-package-replacement-reference"),
            "ipfs://cross-package-replacement-reference"
        ) {
            revert("replacement evidence crossed package boundary");
        } catch {}
    }
}

contract AVASkeletonLifecycle05ABATest is AVASkeletonFixture {
    function testEvidenceLifecycleModuleReceivesKindAndReplacementReference() public {
        bytes32 reviewerSubject = keccak256("m420-evidence-lifecycle-reviewer");
        roleRegistry.assignRole(address(this), AVADataTypes.Role.Reviewer, reviewerSubject, "ipfs://reviewer");
        bytes32 workflowKey = keccak256("m420-kind-scoped-evidence-lifecycle");
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            new KindScopedEvidenceLifecycleModule(AVADataTypes.EvidenceLifecycleKind.ReplacementReady),
            disclosureExecutionModule,
            1,
            keccak256("ava-m4-20-compatible"),
            false,
            "ipfs://m420-evidence-lifecycle"
        );
        uint256 evidenceId = evidenceRegistry.registerEvidenceReceipt(
            AVADataTypes.Role.Reviewer,
            PEER_REVIEW_APP_ID, workflowKey,
            keccak256("m420-evidence"),
            "ipfs://m420-evidence",
            "m420-evidence-basis",
            0
        );
        uint256 replacementEvidenceId = evidenceRegistry.registerEvidenceReceipt(
            AVADataTypes.Role.Reviewer,
            PEER_REVIEW_APP_ID, workflowKey,
            keccak256("m420-replacement-evidence"),
            "ipfs://m420-replacement-evidence",
            "m420-evidence-replacement",
            0
        );

        try evidenceRegistry.recordEvidenceLifecycleHook(
            AVADataTypes.Role.Reviewer,
            PEER_REVIEW_APP_ID, workflowKey,
            evidenceId,
            AVADataTypes.EvidenceLifecycleKind.RevocationReady,
            0,
            keccak256("m420-revocation-reference"),
            "ipfs://m420-revocation"
        ) {
            revert("evidence lifecycle module did not receive kind");
        } catch {}

        uint256 lifecycleRecordId = evidenceRegistry.recordEvidenceLifecycleHook(
            AVADataTypes.Role.Reviewer,
            PEER_REVIEW_APP_ID, workflowKey,
            evidenceId,
            AVADataTypes.EvidenceLifecycleKind.ReplacementReady,
            replacementEvidenceId,
            keccak256("m420-replacement-reference"),
            "ipfs://m420-replacement"
        );
        AVADataTypes.EvidenceLifecycleRecord memory record =
            evidenceRegistry.getEvidenceLifecycleRecord(lifecycleRecordId);
        require(record.kind == AVADataTypes.EvidenceLifecycleKind.ReplacementReady, "replacement kind not recorded");
        require(record.replacementEvidenceReceiptId == replacementEvidenceId, "replacement id not recorded");
        require(record.authorityId == reviewerSubject, "evidence lifecycle authority wrong");
    }
}

contract AVASkeletonLifecycle05BAATest is AVASkeletonFixture {
    function testEvidenceLifecycleUsesReceiptPackageAfterWorkflowReregistration() public {
        bytes32 reviewerSubject = keccak256("m415-evidence-lifecycle-reviewer");
        roleRegistry.assignRole(address(this), AVADataTypes.Role.Reviewer, reviewerSubject, "ipfs://reviewer");
        uint256 originalPackageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW).packageId;
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            keccak256("m415-frozen-evidence"),
            "ipfs://m415-frozen-evidence",
            "m415-frozen-evidence-type",
            0
        );
        require(
            evidenceRegistry.getEvidenceReceipt(evidenceId).packageId == originalPackageId, "evidence package missing"
        );

        _registerRulePackageWithFutureProofModules(
            DEFAULT_WORKFLOW,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            new RejectingEvidenceLifecycleModule(AVADataTypes.Action.RecordEvidenceLifecycle),
            disclosureExecutionModule,
            2,
            keccak256("ava-m4-15-compatible"),
            false,
            "ipfs://m415-rejecting-evidence-lifecycle"
        );

        uint256 lifecycleRecordId = reviewerActor.recordEvidenceLifecycleHook(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            evidenceId,
            AVADataTypes.EvidenceLifecycleKind.ExpiryReady,
            0,
            keccak256("m415-frozen-evidence-expiry"),
            "ipfs://m415-frozen-evidence-expiry"
        );
        AVADataTypes.EvidenceLifecycleRecord memory lifecycleRecord =
            evidenceRegistry.getEvidenceLifecycleRecord(lifecycleRecordId);
        require(lifecycleRecord.packageId == originalPackageId, "evidence lifecycle used active package");
        require(lifecycleRecord.authorityId == REVIEWER_SUBJECT, "evidence lifecycle authority missing");
    }
}

contract AVASkeletonLifecycle05BABTest is AVASkeletonFixture {
    function testM51EvidenceReceiptLifecycleUpdatesStatusAndReplacement() public {
        uint256 evidenceId = _registerM51DefaultEvidence("m51-status-target");
        uint256 replacementEvidenceId = _registerM51DefaultEvidence("m51-status-replacement");

        AVADataTypes.EvidenceReceipt memory initialReceipt = evidenceRegistry.getEvidenceReceipt(evidenceId);
        require(initialReceipt.status == AVADataTypes.EvidenceReceiptStatus.Active, "new evidence not active");
        require(initialReceipt.lastLifecycleRecordId == 0, "new evidence has lifecycle record");
        require(initialReceipt.replacementEvidenceReceiptId == 0, "new evidence has replacement");

        uint256 lifecycleRecordId = reviewerActor.recordEvidenceLifecycleHook(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            evidenceId,
            AVADataTypes.EvidenceLifecycleKind.ReplacementReady,
            replacementEvidenceId,
            keccak256("m51-replacement-reference"),
            "ipfs://m51-replacement"
        );
        AVADataTypes.EvidenceLifecycleRecord memory lifecycleRecord =
            evidenceRegistry.getEvidenceLifecycleRecord(lifecycleRecordId);
        require(lifecycleRecord.fromStatus == AVADataTypes.EvidenceReceiptStatus.Active, "from status missing");
        require(lifecycleRecord.toStatus == AVADataTypes.EvidenceReceiptStatus.Replaced, "to status missing");
        require(lifecycleRecord.replacementEvidenceReceiptId == replacementEvidenceId, "replacement id missing");

        AVADataTypes.EvidenceReceipt memory replacedReceipt = evidenceRegistry.getEvidenceReceipt(evidenceId);
        require(replacedReceipt.status == AVADataTypes.EvidenceReceiptStatus.Replaced, "receipt not replaced");
        require(replacedReceipt.lastLifecycleRecordId == lifecycleRecordId, "last lifecycle id missing");
        require(replacedReceipt.replacementEvidenceReceiptId == replacementEvidenceId, "receipt replacement missing");
        require(
            evidenceRegistry.getEvidenceReceipt(replacementEvidenceId).status
                == AVADataTypes.EvidenceReceiptStatus.Active,
            "replacement not active"
        );
    }
}

contract AVASkeletonLifecycle05BBATest is AVASkeletonFixture {
    function testM51ReplacementLifecycleRejectsBadReferencesAndTerminalRepeat() public {
        uint256 evidenceId = _registerM51DefaultEvidence("m51-replacement-target");
        bytes32 otherWorkflow = keccak256("m51-other-workflow");
        _ensureWorkflowPackage(otherWorkflow);
        uint256 wrongWorkflowReplacement = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            otherWorkflow,
            keccak256("m51-wrong-workflow-replacement"),
            "ipfs://m51-wrong-workflow-replacement",
            "m51-evidence",
            0
        );
        roleRegistry.assignRole(
            address(this), AVADataTypes.Role.Reviewer, keccak256("m51-unscoped-registrar"), "ipfs://m51-reviewer"
        );
        uint256 unscopedReplacement = evidenceRegistry.registerEvidenceReceipt(
            AVADataTypes.Role.Reviewer,
            keccak256("m51-unscoped-replacement"),
            "ipfs://m51-unscoped-replacement",
            "m51-evidence",
            0
        );
        AVADataTypes.EvidenceReceipt memory unscopedReceipt = evidenceRegistry.getEvidenceReceipt(unscopedReplacement);
        require(unscopedReceipt.workflowKey == bytes32(0), "replacement unexpectedly scoped");
        require(unscopedReceipt.packageId == 0, "replacement unexpectedly packaged");
        uint256 inactiveReplacement = _registerM51DefaultEvidence("m51-inactive-replacement");
        _expireM51EvidenceReceipt(inactiveReplacement, "m51-inactive-replacement-expiry");

        _assertM51ReplacementLifecycleRejected(evidenceId, evidenceId, "self replacement accepted");
        _assertM51ReplacementLifecycleRejected(evidenceId, 999999, "unknown replacement accepted");
        _assertM51ReplacementLifecycleRejected(
            evidenceId, wrongWorkflowReplacement, "wrong workflow replacement accepted"
        );
        _assertM51ReplacementLifecycleRejected(evidenceId, unscopedReplacement, "unscoped replacement accepted");
        _assertM51ReplacementLifecycleRejected(evidenceId, inactiveReplacement, "inactive replacement accepted");

        _expireM51EvidenceReceipt(evidenceId, "m51-terminal-target-expiry");
        try reviewerActor.recordEvidenceLifecycleHook(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            evidenceId,
            AVADataTypes.EvidenceLifecycleKind.SupersessionReady,
            0,
            keccak256("m51-terminal-repeat"),
            "ipfs://m51-terminal-repeat"
        ) {
            revert("terminal evidence accepted second lifecycle transition");
        } catch {}
    }
}

contract AVASkeletonLifecycle06AAATest is AVASkeletonFixture {
    function testM51InactiveEvidenceRejectedForReviewStateAndChallengeFormation() public {
        uint256 manuscriptId = stateMachine.registerManuscript(
            AVADataTypes.Role.Author, PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW, keccak256("m51-manuscript"), "ipfs://m51-manuscript", ""
        );
        uint256 reviewEvidenceId = _registerM51DefaultEvidence("m51-review-expired");
        _expireM51EvidenceReceipt(reviewEvidenceId, "m51-review-expiry");

        try reviewerActor.registerReviewContribution(
            stateMachine, AVADataTypes.Role.Reviewer, manuscriptId, REVIEWER_SUBJECT, reviewEvidenceId, 0
        ) {
            revert("review contribution accepted inactive evidence");
        } catch {}

        try stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            keccak256("m51-direct-state"),
            REVIEWER_SUBJECT,
            reviewEvidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        ) {
            revert("recognised state accepted inactive evidence");
        } catch {}

        uint256 stateEvidenceId = _registerM51DefaultEvidence("m51-challengeable-state");
        uint256 challengeableStateId = _registerRecognisedStateForWorkflowStatus(
            DEFAULT_WORKFLOW,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            stateEvidenceId,
            "m51-challengeable-state"
        );
        uint256 challengeEvidenceId = _registerM51DefaultEvidence("m51-challenge-expired");
        _expireM51EvidenceReceipt(challengeEvidenceId, "m51-challenge-expiry");

        try challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            DEFAULT_WORKFLOW,
            challengeableStateId,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            0
        ) {
            revert("challenge accepted inactive evidence");
        } catch {}

        require(
            evidenceRegistry.getEvidenceReceipt(reviewEvidenceId).status == AVADataTypes.EvidenceReceiptStatus.Expired,
            "historical inactive evidence unreadable"
        );
    }
}

contract AVASkeletonLifecycle06AABTest is AVASkeletonFixture {
    function testM51InactiveEvidenceRejectedForDownstreamCredentialAuditAndExternalOperation() public {
        uint256 stateEvidenceId = _registerM51DefaultEvidence("m51-downstream-state");
        uint256 recognisedStateId = _registerRecognisedStateForWorkflowStatus(
            DEFAULT_WORKFLOW, AVADataTypes.RecognisedStateStatus.Vested, stateEvidenceId, "m51-downstream-state"
        );
        uint256 inactiveEvidenceId = _registerM51DefaultEvidence("m51-downstream-expired");
        _expireM51EvidenceReceipt(inactiveEvidenceId, "m51-downstream-expiry");

        uint256 nextStandingUpdateId = standingRegistry.nextStandingUpdateId();
        uint256 nextStandingComputationId = standingRegistry.nextStandingComputationRecordId();
        uint256 nextAllocationId = allocationExecutor.nextAllocationExecutionId();
        uint256 nextConsequenceId = consequenceExecutor.nextConsequenceId();
        _assertAllDownstreamRejectTarget(recognisedStateId, inactiveEvidenceId);
        require(standingRegistry.nextStandingUpdateId() == nextStandingUpdateId, "inactive evidence wrote standing");
        require(
            standingRegistry.nextStandingComputationRecordId() == nextStandingComputationId,
            "inactive evidence wrote standing computation"
        );
        require(
            allocationExecutor.nextAllocationExecutionId() == nextAllocationId, "inactive evidence wrote allocation"
        );
        require(consequenceExecutor.nextConsequenceId() == nextConsequenceId, "inactive evidence wrote consequence");

        _assertM51InactiveEvidenceRejectedForCredentialAuditAndExternal(recognisedStateId, inactiveEvidenceId);
    }
}

contract AVASkeletonLifecycle06ABATest is AVASkeletonFixture {
    function testM411StandingComputationReadinessIsVectorProceduralAndBounded() public {
        bytes32 workflowKey = keccak256("m411-standing-readiness");
        _ensureWorkflowPackage(workflowKey);
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m4-11-compatible"),
            false,
            "ipfs://m411-standing-readiness"
        );
        (uint256 recognisedStateId, uint256 evidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, "m411-standing-state"
        );

        uint256 computationId = standingRegistry.recordStandingComputationReadiness(
            AVADataTypes.Role.Panel,
            AVADataTypes.StandingComputationContext({
                recognisedStateId: recognisedStateId,
                subjectId: REVIEWER_SUBJECT,
                dimension: "review-procedure-weight",
                vectorKey: keccak256("review-procedure-weight"),
                currentValue: 4,
                delta: -1,
                effectiveAt: 123,
                epoch: 1,
                sourceRecordSetHash: keccak256("m411-standing-source-set"),
                computationRuleHash: _m422ComputationRuleHash(),
                reversible: true,
                fieldKey: keccak256("verification-field"),
                evidenceReceiptId: evidenceId,
                authorityId: keccak256("panel-authority"),
                actor: address(this)
            }),
            "ipfs://m411-standing-computation"
        );
        AVADataTypes.StandingComputationRecord memory computation =
            standingRegistry.getStandingComputationRecord(computationId);
        require(computation.vectorKey == keccak256("review-procedure-weight"), "vector key missing");
        require(computation.reversible, "reversibility readiness missing");
        require(computation.currentValue == 4 && computation.delta == -1, "standing computation values missing");

        try standingRegistry.recordStandingComputationReadiness(
            AVADataTypes.Role.Panel,
            AVADataTypes.StandingComputationContext({
                recognisedStateId: recognisedStateId,
                subjectId: REVIEWER_SUBJECT,
                dimension: "single-score",
                vectorKey: keccak256("single-score"),
                currentValue: 0,
                delta: 1,
                effectiveAt: 0,
                epoch: 2,
                sourceRecordSetHash: keccak256("m411-single-score-source-set"),
                computationRuleHash: _m422ComputationRuleHash(),
                reversible: true,
                fieldKey: keccak256("verification-field"),
                evidenceReceiptId: evidenceId,
                authorityId: keccak256("panel-authority"),
                actor: address(this)
            }),
            "ipfs://m411-single-score"
        ) {
            revert("standing computation accepted single-score");
        } catch {}

        _assertNoSelector(address(standingRegistry), "setPublicPrestige(uint256,uint256)");
        _assertNoSelector(address(standingRegistry), "setReputationScore(uint256,uint256)");
    }
}

contract AVASkeletonLifecycle06BAATest is AVASkeletonFixture {
    function testM62FormulaV0StandingComputationModuleAcceptsBoundedOutput() public {
        bytes32 workflowKey = keccak256("m62-formula-v0-valid");
        FormulaV0StandingComputationModule formulaModule = new FormulaV0StandingComputationModule();
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            formulaModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m6-2-compatible"),
            false,
            "ipfs://m62-formula-v0-valid"
        );
        (uint256 recognisedStateId, uint256 evidenceId) = _createM421EligibleState(workflowKey, "m62-formula-valid");
        bytes32 vectorKey = formulaModule.REVIEW_RELIABILITY_VECTOR();
        uint256 computationId = standingRegistry.recordStandingComputationReadiness(
            AVADataTypes.Role.Panel,
            AVADataTypes.StandingComputationContext({
                recognisedStateId: recognisedStateId,
                subjectId: REVIEWER_SUBJECT,
                dimension: "review_reliability",
                vectorKey: vectorKey,
                currentValue: 7,
                delta: 2,
                effectiveAt: block.timestamp,
                epoch: 2,
                sourceRecordSetHash: keccak256("m62-formula-source-set"),
                computationRuleHash: formulaModule.formulaRuleHash(vectorKey),
                reversible: true,
                fieldKey: keccak256("peer-review-field"),
                evidenceReceiptId: evidenceId,
                authorityId: keccak256("panel-authority"),
                actor: address(this)
            }),
            "ipfs://m62-formula-valid"
        );
        AVADataTypes.StandingComputationRecord memory computation =
            standingRegistry.getStandingComputationRecord(computationId);
        require(computation.computationRuleHash == formulaModule.formulaRuleHash(vectorKey), "formula rule missing");
        require(computation.vectorKey == vectorKey, "formula vector missing");
        require(computation.currentValue == 7 && computation.delta == 2, "formula value missing");
    }
}

contract AVASkeletonLifecycle06BABTest is AVASkeletonFixture {
    function testM62FormulaV0StandingComputationModuleRejectsInvalidFormulaOutputs() public {
        bytes32 workflowKey = keccak256("m62-formula-v0-rejects");
        FormulaV0StandingComputationModule formulaModule = new FormulaV0StandingComputationModule();
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            formulaModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m6-2-compatible"),
            false,
            "ipfs://m62-formula-v0-rejects"
        );
        (uint256 recognisedStateId, uint256 evidenceId) = _createM421EligibleState(workflowKey, "m62-formula-rejects");
        bytes32 vectorKey = formulaModule.REVIEW_RELIABILITY_VECTOR();
        AVADataTypes.StandingComputationContext memory context = AVADataTypes.StandingComputationContext({
            recognisedStateId: recognisedStateId,
            subjectId: REVIEWER_SUBJECT,
            dimension: "review_reliability",
            vectorKey: vectorKey,
            currentValue: 7,
            delta: 2,
            effectiveAt: block.timestamp,
            epoch: 2,
            sourceRecordSetHash: keccak256("m62-formula-source-set"),
            computationRuleHash: formulaModule.formulaRuleHash(vectorKey),
            reversible: true,
            fieldKey: keccak256("peer-review-field"),
            evidenceReceiptId: evidenceId,
            authorityId: keccak256("panel-authority"),
            actor: address(this)
        });
        uint256 nextComputationId = standingRegistry.nextStandingComputationRecordId();

        context.computationRuleHash = keccak256("m62-wrong-rule");
        try standingRegistry.recordStandingComputationReadiness(
            AVADataTypes.Role.Panel, context, "ipfs://m62-wrong-rule"
        ) {
            revert("formula module accepted wrong rule hash");
        } catch {}

        context.computationRuleHash = formulaModule.formulaRuleHash(vectorKey);
        context.dimension = "single-score";
        context.vectorKey = keccak256("single-score");
        try standingRegistry.recordStandingComputationReadiness(
            AVADataTypes.Role.Panel, context, "ipfs://m62-single-score"
        ) {
            revert("formula module accepted single score");
        } catch {}

        context.dimension = "unrecognised_vector";
        context.vectorKey = keccak256("unrecognised_vector");
        context.computationRuleHash = formulaModule.formulaRuleHash(context.vectorKey);
        try standingRegistry.recordStandingComputationReadiness(
            AVADataTypes.Role.Panel, context, "ipfs://m62-unknown-vector"
        ) {
            revert("formula module accepted unknown vector");
        } catch {}

        context.dimension = "review_reliability";
        context.vectorKey = vectorKey;
        context.computationRuleHash = formulaModule.formulaRuleHash(vectorKey);
        context.currentValue = 101;
        try standingRegistry.recordStandingComputationReadiness(
            AVADataTypes.Role.Panel, context, "ipfs://m62-unbounded"
        ) {
            revert("formula module accepted unbounded value");
        } catch {}

        require(standingRegistry.nextStandingComputationRecordId() == nextComputationId, "invalid formula wrote record");
    }
}

contract AVASkeletonLifecycle06BBATest is AVASkeletonFixture {
    function testM412GenericAllocationAndConsequenceRouteThroughValueAdapter() public {
        bytes32 workflowKey = keccak256("m412-generic-routing");
        _ensureWorkflowPackage(workflowKey);
        bytes32 blockedReference = keccak256("m412-blocked-reference");
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            new MockValueExecutionAdapter(blockedReference, address(0xBAD), AVADataTypes.ValueExecutionMode.Escrow),
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m4-12-compatible"),
            false,
            "ipfs://m412-generic-routing"
        );
        (uint256 recognisedStateId, uint256 evidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, "m412-generic-state"
        );

        allocationExecutor.executeAllocationWithExecution(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.AllocationKind.OperationalAllowance,
            _valueContext(
                recognisedStateId,
                REVIEWER_SUBJECT,
                5,
                evidenceId,
                keccak256("executor-authority"),
                "ipfs://m412-generic-allocation",
                keccak256("m412-allowed-allocation"),
                address(0xCAFE),
                address(0xDAD),
                AVADataTypes.ValueExecutionMode.RecordOnly
            )
        );
        consequenceExecutor.registerConsequenceWithExecution(
            AVADataTypes.Role.Panel,
            AVADataTypes.ConsequenceKind.AdministrativeNote,
            _valueContext(
                recognisedStateId,
                REVIEWER_SUBJECT,
                1,
                evidenceId,
                keccak256("panel-authority"),
                "ipfs://m412-generic-consequence",
                keccak256("m412-allowed-consequence"),
                address(0xCAFE),
                address(0xDAD),
                AVADataTypes.ValueExecutionMode.RecordOnly
            )
        );

        try allocationExecutor.executeAllocationWithExecution(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.AllocationKind.OperationalAllowance,
            _valueContext(
                recognisedStateId,
                REVIEWER_SUBJECT,
                5,
                evidenceId,
                keccak256("executor-authority"),
                "ipfs://m412-blocked-allocation",
                blockedReference,
                address(0xCAFE),
                address(0xDAD),
                AVADataTypes.ValueExecutionMode.RecordOnly
            )
        ) {
            revert("generic allocation bypassed value adapter");
        } catch {}
        try consequenceExecutor.registerConsequenceWithExecution(
            AVADataTypes.Role.Panel,
            AVADataTypes.ConsequenceKind.AdministrativeNote,
            _valueContext(
                recognisedStateId,
                REVIEWER_SUBJECT,
                1,
                evidenceId,
                keccak256("panel-authority"),
                "ipfs://m412-blocked-consequence",
                blockedReference,
                address(0xCAFE),
                address(0xDAD),
                AVADataTypes.ValueExecutionMode.RecordOnly
            )
        ) {
            revert("generic consequence bypassed value adapter");
        } catch {}
    }
}
