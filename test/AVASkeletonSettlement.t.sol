// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./helpers/AVASkeletonFixture.sol";

contract AVASkeletonSettlement01ATest is AVASkeletonFixture {
    function testM412ParameterizedPenaltyAndRestorationRecordExecutionFields() public {
        bytes32 workflowKey = keccak256("m412-consequence-parameters");
        _ensureWorkflowPackage(workflowKey);
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m4-12-compatible"),
            false,
            "ipfs://m412-consequence-parameters"
        );
        (uint256 recognisedStateId, uint256 challengeId, uint256 evidenceId) = _createResolvedChallengeForWorkflowSubject(
            workflowKey,
            REVIEWER_SUBJECT,
            "m412-consequence-state",
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded
        );

        uint256 penaltyId = consequenceExecutor.recordPenalty(
            AVADataTypes.Role.Panel,
            AVADataTypes.PenaltyConsequenceContext({
                challengeId: challengeId,
                findingKind: AVADataTypes.GovernanceFindingKind.IrresponsibleReview,
                originSettlementId: 0
            }),
            _valueContext(
                recognisedStateId,
                REVIEWER_SUBJECT,
                12,
                evidenceId,
                keccak256("panel-authority"),
                "ipfs://m412-penalty",
                keccak256("m412-penalty-reference"),
                address(0xA11CE),
                address(0xB0B),
                AVADataTypes.ValueExecutionMode.RecordOnly
            )
        );
        uint256 restorationId = consequenceExecutor.recordRestorationWithExecution(
            AVADataTypes.Role.Panel,
            _valueContext(
                recognisedStateId,
                REVIEWER_SUBJECT,
                34,
                evidenceId,
                keccak256("panel-authority"),
                "ipfs://m412-restoration",
                keccak256("m412-restoration-reference"),
                address(0xA11CE),
                address(0xB0B),
                AVADataTypes.ValueExecutionMode.RecordOnly
            )
        );

        AVADataTypes.ConsequenceRecord memory penalty = consequenceExecutor.getConsequence(penaltyId);
        AVADataTypes.ConsequenceRecord memory restoration = consequenceExecutor.getConsequence(restorationId);
        require(penalty.amountOrUnits == 12, "penalty amount hardcoded");
        require(restoration.amountOrUnits == 34, "restoration amount hardcoded");
        require(penalty.executionReference == keccak256("m412-penalty-reference"), "penalty reference missing");
        require(
            restoration.executionReference == keccak256("m412-restoration-reference"), "restoration reference missing"
        );
        require(penalty.asset == address(0xA11CE) && penalty.payer == address(0xB0B), "penalty addresses missing");
        require(
            restoration.asset == address(0xA11CE) && restoration.payer == address(0xB0B),
            "restoration addresses missing"
        );
    }

    function testM412DefaultValueAdapterRejectsNonRecordOnlyParameterizedModes() public {
        bytes32 workflowKey = keccak256("m412-default-mode");
        _ensureWorkflowPackage(workflowKey);
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m4-12-compatible"),
            false,
            "ipfs://m412-default-mode"
        );
        (uint256 recognisedStateId, uint256 challengeId, uint256 evidenceId) = _createResolvedChallengeForWorkflowSubject(
            workflowKey,
            REVIEWER_SUBJECT,
            "m412-default-state",
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded
        );

        try allocationExecutor.recordRewardValueWithExecution(
            AVADataTypes.Role.ProtocolExecutor,
            _valueContext(
                recognisedStateId,
                REVIEWER_SUBJECT,
                1,
                evidenceId,
                keccak256("executor-authority"),
                "ipfs://m412-claim-reward",
                keccak256("m412-claim-reward"),
                address(0xA11CE),
                address(0xB0B),
                AVADataTypes.ValueExecutionMode.Claim
            )
        ) {
            revert("default value adapter accepted claim reward");
        } catch {}
        try consequenceExecutor.recordPenalty(
            AVADataTypes.Role.Panel,
            AVADataTypes.PenaltyConsequenceContext({
                challengeId: challengeId,
                findingKind: AVADataTypes.GovernanceFindingKind.IrresponsibleReview,
                originSettlementId: 0
            }),
            _valueContext(
                recognisedStateId,
                REVIEWER_SUBJECT,
                1,
                evidenceId,
                keccak256("panel-authority"),
                "ipfs://m412-escrow-penalty",
                keccak256("m412-escrow-penalty"),
                address(0xA11CE),
                address(0xB0B),
                AVADataTypes.ValueExecutionMode.Escrow
            )
        ) {
            revert("default value adapter accepted escrow penalty");
        } catch {}
    }

    function testStandingRegistryDispatchesAdaptersByRecognisedStateWorkflowKey() public {
        bytes32 workflowA = keccak256("standing-dispatch-a");
        bytes32 workflowB = keccak256("standing-dispatch-b");
        _ensureWorkflowPackage(workflowA);
        _ensureWorkflowPackage(workflowB);
        uint256 evidenceA = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowA,
            keccak256("standing-dispatch-evidence-a"),
            "ipfs://standing-dispatch-a",
            "standing-dispatch-basis",
            0
        );
        uint256 evidenceB = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowB,
            keccak256("standing-dispatch-evidence-b"),
            "ipfs://standing-dispatch-b",
            "standing-dispatch-basis",
            0
        );
        _registerRulePackageWithAdapters(
            workflowA,
            allocationAdapter,
            consequenceAdapter,
            new MockStandingAdapter("blocked-a"),
            rewardAdapter,
            priorityAdapter,
            penaltyAdapter,
            restorationAdapter,
            "ipfs://standing-dispatch-a"
        );
        _registerRulePackageWithAdapters(
            workflowB,
            allocationAdapter,
            consequenceAdapter,
            new MockStandingAdapter("blocked-b"),
            rewardAdapter,
            priorityAdapter,
            penaltyAdapter,
            restorationAdapter,
            "ipfs://standing-dispatch-b"
        );
        (uint256 stateA, uint256 currentEvidenceA) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowA, AVADataTypes.RecognisedStateStatus.Downgraded, "standing-dispatch-state-a"
        );
        (uint256 stateB, uint256 currentEvidenceB) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowB, AVADataTypes.RecognisedStateStatus.Downgraded, "standing-dispatch-state-b"
        );
        evidenceA = currentEvidenceA;
        evidenceB = currentEvidenceB;

        standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            stateA,
            REVIEWER_SUBJECT,
            "blocked-b",
            1,
            evidenceA,
            keccak256("panel-authority"),
            "ipfs://standing-a-allowed"
        );
        standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            stateB,
            REVIEWER_SUBJECT,
            "blocked-a",
            1,
            evidenceB,
            keccak256("panel-authority"),
            "ipfs://standing-b-allowed"
        );

        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            stateA,
            REVIEWER_SUBJECT,
            "blocked-a",
            1,
            evidenceA,
            keccak256("panel-authority"),
            "ipfs://standing-a-blocked"
        ) {
            revert("standing workflow A did not dispatch to adapter A");
        } catch {}
        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            stateB,
            REVIEWER_SUBJECT,
            "blocked-b",
            1,
            evidenceB,
            keccak256("panel-authority"),
            "ipfs://standing-b-blocked"
        ) {
            revert("standing workflow B did not dispatch to adapter B");
        } catch {}
    }
}

contract AVASkeletonSettlement01BTest is AVASkeletonFixture {
    function testAllocationExecutorDispatchesRewardAndPriorityAdaptersByWorkflowKey() public {
        bytes32 workflowA = keccak256("allocation-dispatch-a");
        bytes32 workflowB = keccak256("allocation-dispatch-b");
        _ensureWorkflowPackage(workflowA);
        _ensureWorkflowPackage(workflowB);
        uint256 evidenceA = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowA,
            keccak256("allocation-dispatch-evidence-a"),
            "ipfs://allocation-dispatch-a",
            "allocation-dispatch-basis",
            0
        );
        uint256 evidenceB = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowB,
            keccak256("allocation-dispatch-evidence-b"),
            "ipfs://allocation-dispatch-b",
            "allocation-dispatch-basis",
            0
        );
        _registerRulePackageWithAdapters(
            workflowA,
            allocationAdapter,
            consequenceAdapter,
            standingAdapter,
            new MockRewardAdapter(7),
            new MockPriorityAdapter(9),
            penaltyAdapter,
            restorationAdapter,
            "ipfs://allocation-dispatch-a"
        );
        _registerRulePackageWithAdapters(
            workflowB,
            allocationAdapter,
            consequenceAdapter,
            standingAdapter,
            new MockRewardAdapter(17),
            new MockPriorityAdapter(19),
            penaltyAdapter,
            restorationAdapter,
            "ipfs://allocation-dispatch-b"
        );
        (uint256 stateA, uint256 currentEvidenceA) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowA, AVADataTypes.RecognisedStateStatus.Vested, "allocation-dispatch-state-a"
        );
        (uint256 stateB, uint256 currentEvidenceB) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowB, AVADataTypes.RecognisedStateStatus.Vested, "allocation-dispatch-state-b"
        );
        evidenceA = currentEvidenceA;
        evidenceB = currentEvidenceB;

        allocationExecutor.recordRewardValue(
            AVADataTypes.Role.ProtocolExecutor,
            stateA,
            REVIEWER_SUBJECT,
            17,
            evidenceA,
            keccak256("executor-authority"),
            "ipfs://reward-a-allowed"
        );
        allocationExecutor.recordAdministrativePriority(
            AVADataTypes.Role.ProtocolExecutor,
            stateB,
            REVIEWER_SUBJECT,
            9,
            evidenceB,
            keccak256("executor-authority"),
            "ipfs://priority-b-allowed"
        );

        try allocationExecutor.recordRewardValue(
            AVADataTypes.Role.ProtocolExecutor,
            stateA,
            REVIEWER_SUBJECT,
            7,
            evidenceA,
            keccak256("executor-authority"),
            "ipfs://reward-a-blocked"
        ) {
            revert("reward workflow A did not dispatch to adapter A");
        } catch {}
        try allocationExecutor.recordAdministrativePriority(
            AVADataTypes.Role.ProtocolExecutor,
            stateB,
            REVIEWER_SUBJECT,
            19,
            evidenceB,
            keccak256("executor-authority"),
            "ipfs://priority-b-blocked"
        ) {
            revert("priority workflow B did not dispatch to adapter B");
        } catch {}
    }

    function testConsequenceExecutorDispatchesPenaltyAndRestorationAdaptersByWorkflowKey() public {
        bytes32 blockedA = keccak256("blocked-a-authority");
        bytes32 blockedB = keccak256("blocked-b-authority");
        bytes32 workflowA = keccak256("consequence-dispatch-a");
        bytes32 workflowB = keccak256("consequence-dispatch-b");
        _ensureWorkflowPackage(workflowA);
        _ensureWorkflowPackage(workflowB);
        uint256 evidenceA = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowA,
            keccak256("consequence-dispatch-evidence-a"),
            "ipfs://consequence-dispatch-a",
            "consequence-dispatch-basis",
            0
        );
        uint256 evidenceB = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowB,
            keccak256("consequence-dispatch-evidence-b"),
            "ipfs://consequence-dispatch-b",
            "consequence-dispatch-basis",
            0
        );
        _registerRulePackageWithAdapters(
            workflowA,
            allocationAdapter,
            consequenceAdapter,
            standingAdapter,
            rewardAdapter,
            priorityAdapter,
            new MockPenaltyAdapter(blockedA),
            new MockRestorationAdapter(blockedA),
            "ipfs://consequence-dispatch-a"
        );
        _registerRulePackageWithAdapters(
            workflowB,
            allocationAdapter,
            consequenceAdapter,
            standingAdapter,
            rewardAdapter,
            priorityAdapter,
            new MockPenaltyAdapter(blockedB),
            new MockRestorationAdapter(blockedB),
            "ipfs://consequence-dispatch-b"
        );
        (uint256 stateA, uint256 challengeA, uint256 currentEvidenceA) = _createResolvedChallengeForWorkflowSubject(
            workflowA,
            REVIEWER_SUBJECT,
            "consequence-dispatch-state-a",
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded
        );
        (uint256 stateB, uint256 currentEvidenceB) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowB, AVADataTypes.RecognisedStateStatus.Restored, "consequence-dispatch-state-b"
        );
        evidenceA = currentEvidenceA;
        evidenceB = currentEvidenceB;

        _recordPenaltyForChallenge(
            stateA,
            challengeA,
            AVADataTypes.GovernanceFindingKind.IrresponsibleReview,
            REVIEWER_SUBJECT,
            evidenceA,
            keccak256("panel-authority"),
            "ipfs://penalty-a-allowed"
        );
        consequenceExecutor.recordRestoration(
            AVADataTypes.Role.Panel,
            stateB,
            REVIEWER_SUBJECT,
            evidenceB,
            keccak256("panel-authority"),
            "ipfs://restoration-b-allowed"
        );

        _assertPenaltyAdapterRejects(stateA, challengeA, evidenceA, blockedA);
        try consequenceExecutor.recordRestoration(
            AVADataTypes.Role.Panel, stateB, REVIEWER_SUBJECT, evidenceB, blockedB, "ipfs://restoration-b-blocked"
        ) {
            revert("restoration workflow B did not dispatch to adapter B");
        } catch {}
    }

    function testM4MultiWorkflowScenarioPreservesSharedSubstrateAndBoundaries() public {
        roleRegistry.assignRole(
            address(this), AVADataTypes.Role.Challenger, keccak256("local-challenger"), "ipfs://challenger"
        );
        Actor panelActor = new Actor();
        roleRegistry.assignRole(address(panelActor), AVADataTypes.Role.Panel, keccak256("m4-panel"), "ipfs://panel");

        bytes32 reviewWorkflow = keccak256("m4-review-workflow");
        bytes32 integrityWorkflow = keccak256("m4-integrity-workflow");
        _registerRulePackageWithAdapters(
            reviewWorkflow,
            allocationAdapter,
            consequenceAdapter,
            new MockStandingAdapter("review-blocked-standing"),
            new MockRewardAdapter(7),
            new MockPriorityAdapter(9),
            new MockPenaltyAdapter(keccak256("review-blocked-authority")),
            new MockRestorationAdapter(keccak256("review-blocked-authority")),
            "ipfs://m4-review-workflow"
        );
        _registerRulePackageWithAdapters(
            integrityWorkflow,
            allocationAdapter,
            consequenceAdapter,
            new MockStandingAdapter("integrity-blocked-standing"),
            new MockRewardAdapter(17),
            new MockPriorityAdapter(19),
            new MockPenaltyAdapter(keccak256("integrity-blocked-authority")),
            new MockRestorationAdapter(keccak256("integrity-blocked-authority")),
            "ipfs://m4-integrity-workflow"
        );

        AVARulePackageRegistry.RulePackage memory reviewPackage = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, reviewWorkflow);
        uint256 reviewStateId = _createChallengeableReviewStateThroughPackage(reviewPackage, reviewWorkflow);
        AVADataTypes.RecognisedStateRecord memory reviewStateBefore = stateMachine.getRecognisedState(reviewStateId);
        require(reviewStateBefore.workflowKey == reviewWorkflow, "review state workflow wrong");

        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            integrityWorkflow,
            keccak256("m4-integrity-evidence"),
            "ipfs://m4-integrity-evidence",
            "challenge-integrity",
            0
        );
        uint256 integrityStateId = stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            PEER_REVIEW_APP_ID,
            integrityWorkflow,
            AVADataTypes.AVAStage.Verification,
            bytes32(reviewStateId),
            REVIEWER_SUBJECT,
            challengeEvidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Challengeable
        );
        uint256 challengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            integrityWorkflow,
            integrityStateId,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            0
        );

        {
            AVADataTypes.ChallengeRecord memory challenge = challengeWorkflow.getChallenge(challengeId);
            AVADataTypes.RecognisedStateRecord memory integrityState = stateMachine.getRecognisedState(integrityStateId);
            require(challenge.workflowKey == integrityWorkflow, "challenge workflow wrong");
            require(challenge.challengedRecognisedStateId == integrityStateId, "challenge target wrong");
            require(integrityState.workflowKey == integrityWorkflow, "integrity state workflow wrong");
            require(integrityState.objectId == bytes32(reviewStateId), "integrity state did not target review state");
            require(consequenceExecutor.nextConsequenceId() == 1, "challenge created consequence");
            require(standingRegistry.nextStandingUpdateId() == 1, "challenge created standing");
            require(allocationExecutor.nextAllocationExecutionId() == 1, "challenge created allocation");
        }

        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        panelActor.resolveChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            keccak256("m4-panel"),
            "ipfs://m4-resolution"
        );
        {
            AVADataTypes.RecognisedStateRecord memory reviewStateAfter = stateMachine.getRecognisedState(reviewStateId);
            AVADataTypes.RecognisedStateRecord memory integrityStateAfter =
                stateMachine.getRecognisedState(integrityStateId);
            require(
                reviewStateAfter.status == AVADataTypes.RecognisedStateStatus.Challengeable,
                "review state was rewritten"
            );
            require(reviewStateAfter.workflowKey == reviewWorkflow, "review workflow changed");
            require(
                integrityStateAfter.status == AVADataTypes.RecognisedStateStatus.Downgraded,
                "integrity state not updated"
            );
        }

        {
            uint256 reviewDownstreamEvidenceId = reviewerActor.registerEvidenceReceipt(
                evidenceRegistry,
                AVADataTypes.Role.Reviewer,
                reviewWorkflow,
                keccak256("m4-review-downstream-evidence"),
                "ipfs://m4-review-downstream-evidence",
                "review-downstream-basis",
                0
            );
            uint256 reviewDownstreamStateId = _registerRecognisedStateForWorkflowStatus(
                reviewWorkflow,
                AVADataTypes.RecognisedStateStatus.Downgraded,
                reviewDownstreamEvidenceId,
                "m4-review-downstream"
            );
            uint256 integrityPositiveEvidenceId = reviewerActor.registerEvidenceReceipt(
                evidenceRegistry,
                AVADataTypes.Role.Reviewer,
                integrityWorkflow,
                keccak256("m4-integrity-positive-evidence"),
                "ipfs://m4-integrity-positive-evidence",
                "integrity-positive-basis",
                0
            );
            uint256 integrityPositiveStateId = _registerRecognisedStateForWorkflowStatus(
                integrityWorkflow,
                AVADataTypes.RecognisedStateStatus.Vested,
                integrityPositiveEvidenceId,
                "m4-integrity-positive"
            );

            _assertM4DownstreamRecords(
                integrityStateId, challengeEvidenceId, integrityPositiveStateId, integrityPositiveEvidenceId
            );
            _assertM4WorkflowAdapterBlocks(
                reviewDownstreamStateId,
                integrityStateId,
                reviewDownstreamEvidenceId,
                challengeEvidenceId,
                keccak256("review-blocked-authority"),
                keccak256("integrity-blocked-authority")
            );
        }

        _assertNoSelector(address(allocationExecutor), "transferToken(uint256)");
        _assertNoSelector(address(allocationExecutor), "payStablecoin(uint256)");
        _assertNoSelector(address(allocationExecutor), "executeQueue(uint256)");
        _assertNoSelector(address(consequenceExecutor), "executeSanction(uint256)");
        _assertNoSelector(address(stateMachine), "acceptManuscript(uint256)");
        _assertNoSelector(address(stateMachine), "scoreManuscriptMerit(uint256)");
    }
}

contract AVASkeletonSettlement02ATest is AVASkeletonFixture {
    function testM4EvidenceOnlyIdsCannotTriggerAnyDownstreamRecord() public {
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("m4-evidence-only"),
            "ipfs://m4-evidence-only",
            "evidence-only",
            0
        );

        _assertAllDownstreamRejectTarget(evidenceId, evidenceId);
        require(standingRegistry.nextStandingUpdateId() == 1, "evidence-only created standing");
        require(allocationExecutor.nextAllocationExecutionId() == 1, "evidence-only created allocation");
        require(consequenceExecutor.nextConsequenceId() == 1, "evidence-only created consequence");
    }

    function testM4RestorationRecordDoesNotEraseChallengeHistoryOrMintReward() public {
        uint256 targetEvidenceId = _registerM51DefaultEvidence("m4-restoration-target");
        uint256 recognisedStateId = _registerRecognisedStateForStatus(
            AVADataTypes.RecognisedStateStatus.Vested, targetEvidenceId, "m4-restoration-target"
        );
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256("m4-restoration-history"),
            "ipfs://m4-restoration-history",
            "restoration-history",
            0
        );
        uint256 challengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            0
        );
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Vested,
            keccak256("panel-authority"),
            "ipfs://m4-good-faith"
        );
        AVADataTypes.ChallengeRecord memory resolvedChallenge = challengeWorkflow.getChallenge(challengeId);
        uint256 resolvedTransitionId = resolvedChallenge.lastTransitionId;

        challengeWorkflow.applyRestoration(
            AVADataTypes.Role.Panel, challengeId, keccak256("panel-authority"), "ipfs://m4-restoration-transition"
        );
        AVADataTypes.ChallengeRecord memory restoredChallenge = challengeWorkflow.getChallenge(challengeId);
        AVADataTypes.ChallengeTransitionRecord memory resolvedTransition =
            challengeWorkflow.getChallengeTransition(resolvedTransitionId);
        AVADataTypes.ChallengeTransitionRecord memory restorationTransition =
            challengeWorkflow.getChallengeTransition(restoredChallenge.lastTransitionId);
        require(
            resolvedTransition.transitionKind == AVADataTypes.ChallengeTransitionKind.OutcomeResolved,
            "resolved transition erased"
        );
        require(
            restorationTransition.transitionKind == AVADataTypes.ChallengeTransitionKind.RestorationRecorded,
            "restoration transition missing"
        );
        require(restoredChallenge.lastTransitionId != resolvedTransitionId, "restoration did not add history");

        uint256 restorationRecordId = consequenceExecutor.recordRestoration(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            challengeEvidenceId,
            keccak256("panel-authority"),
            "ipfs://m4-restoration-record"
        );
        require(
            consequenceExecutor.getConsequence(restorationRecordId).kind
                == AVADataTypes.ConsequenceKind.RestorationRecord,
            "restoration consequence missing"
        );
        require(allocationExecutor.nextAllocationExecutionId() == 1, "restoration minted reward");
        require(
            challengeWorkflow.getChallenge(challengeId).lastTransitionId == restoredChallenge.lastTransitionId,
            "restoration record erased challenge history"
        );
        _assertNoSelector(address(restorationAdapter), "mintReward(uint256)");
        _assertNoSelector(address(consequenceExecutor), "mintReward(uint256)");
    }

    function testM47WorkflowSpecificChallengeLifecycleCanRejectActionsWithoutStorageChange() public {
        roleRegistry.assignRole(
            address(this), AVADataTypes.Role.Challenger, keccak256("m47-challenger"), "ipfs://challenger"
        );

        _assertLifecycleModuleRejectsScreen();
        _assertLifecycleModuleRejectsResolve();
        _assertLifecycleModuleRejectsRestoration();
        _assertLifecycleModuleRejectsClose();
    }
}

contract AVASkeletonSettlement02BTest is AVASkeletonFixture {
    function testM47PermissiveLifecycleCannotBypassNonDelegableSafetyGates() public {
        roleRegistry.assignRole(
            address(this), AVADataTypes.Role.Challenger, keccak256("m47-challenger"), "ipfs://challenger"
        );
        bytes32 workflowKey = keccak256("m47-permissive-lifecycle");
        _registerRulePackageWithLifecycle(
            workflowKey, new PermissiveChallengeLifecycleModule(), "ipfs://m47-permissive-lifecycle"
        );
        AVARulePackageRegistry.RulePackage memory rulePackage = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey);
        uint256 recognisedStateId = _createChallengeableReviewStateThroughPackage(rulePackage, workflowKey);
        uint256 evidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            workflowKey,
            keccak256("m47-permissive-evidence"),
            "ipfs://m47-permissive-evidence",
            "challenge-lifecycle",
            0
        );
        uint256 challengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            workflowKey,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            evidenceId,
            0
        );
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);

        roleRegistry.assignRole(
            address(challengerActor), AVADataTypes.Role.Panel, keccak256("m47-panel-challenger"), "ipfs://panel"
        );
        try challengerActor.resolveChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            keccak256("m47-panel-challenger"),
            "ipfs://m47-self-resolution"
        ) {
            revert("permissive lifecycle bypassed self-resolution guard");
        } catch {}

        Actor panelActor = new Actor();
        roleRegistry.assignRole(address(panelActor), AVADataTypes.Role.Panel, keccak256("m47-panel"), "ipfs://panel");
        try panelActor.resolveChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            keccak256("m47-panel"),
            "ipfs://m47-non-upheld-mutation"
        ) {
            revert("permissive lifecycle bypassed only-upheld mutation guard");
        } catch {}
        require(
            challengeWorkflow.getChallenge(challengeId).status
                == AVADataTypes.ChallengeLifecycleStatus.AdmissibilityScreening,
            "failed mutation changed lifecycle"
        );
        panelActor.resolveChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("m47-panel"),
            "ipfs://m47-good-faith"
        );
    }

    function testDownstreamAdaptersRejectRawReviewAndChallengeIds() public {
        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("m3-raw-review-evidence"),
            "ipfs://m3-raw-review",
            "review-service-occurrence",
            0
        );
        uint256 rawReviewId = reviewerActor.registerReviewContribution(
            stateMachine, AVADataTypes.Role.Reviewer, manuscriptId, REVIEWER_SUBJECT, evidenceId, 0
        );
        _assertSeparatedDownstreamRejectsTarget(rawReviewId, evidenceId);

        uint256 challengeableStateId = _createChallengeableReviewState();
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256("m3-raw-challenge-evidence"),
            "ipfs://m3-raw-challenge",
            "review-quality-challenge",
            0
        );
        challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            challengeableStateId,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            0
        );
        challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            _createChallengeableReviewState(),
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            0
        );
        uint256 rawChallengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            _createChallengeableReviewState(),
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            0
        );

        _assertSeparatedDownstreamRejectsTarget(rawChallengeId, challengeEvidenceId);
    }

    function testDownstreamAdaptersRejectDisallowedRecognisedStateStatuses() public {
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("m3-disallowed-status-evidence"),
            "ipfs://m3-disallowed-status",
            "status-boundary",
            0
        );

        _assertSeparatedDownstreamRejectsTarget(0, evidenceId);
        _assertSeparatedDownstreamRejectsTarget(
            _registerRecognisedStateForStatus(AVADataTypes.RecognisedStateStatus.Draft, evidenceId, "m3-draft"),
            evidenceId
        );
        _assertSeparatedDownstreamRejectsTarget(
            _registerRecognisedStateForStatus(
                AVADataTypes.RecognisedStateStatus.Registered, evidenceId, "m3-registered"
            ),
            evidenceId
        );
        _assertSeparatedDownstreamRejectsTarget(
            _registerRecognisedStateForStatus(
                AVADataTypes.RecognisedStateStatus.Provisional, evidenceId, "m3-provisional"
            ),
            evidenceId
        );
        _assertSeparatedDownstreamRejectsTarget(
            _registerRecognisedStateForStatus(
                AVADataTypes.RecognisedStateStatus.Challengeable, evidenceId, "m3-challengeable"
            ),
            evidenceId
        );
        _assertSeparatedDownstreamRejectsTarget(
            _registerRecognisedStateForStatus(AVADataTypes.RecognisedStateStatus.Frozen, evidenceId, "m3-frozen"),
            evidenceId
        );
    }
}

contract AVASkeletonSettlement03ATest is AVASkeletonFixture {
    function testM421ValueSettlementTransfersMockERC20OnlyFromAuthorisedRecord() public {
        bytes32 workflowKey = keccak256("m421-token-transfer-workflow");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m421-token-transfer-workflow");
        MockERC20 token = _m421FundedToken(100);
        uint256 sourceId = _createM421RewardSource(
            workflowKey, "m421-token-transfer-source", token, 7, AVADataTypes.ValueExecutionMode.Claim
        );

        uint256 settlementId = valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m421-token-transfer-settlement"
        );
        AVADataTypes.ValueSettlementRecord memory settlement = valueSettlementExecutor.getValueSettlement(settlementId);
        require(settlement.kind == AVADataTypes.ValueSettlementKind.TokenTransfer, "wrong settlement kind");
        require(settlement.status == AVADataTypes.ValueSettlementStatus.Settled, "wrong settlement status");
        require(token.balanceOf(address(reviewerActor)) == 7, "mock ERC20 not transferred to subject account");

        uint256 recordOnlySourceId = _createM421RecordOnlyRewardSource(workflowKey, "m421-record-only-source");
        try valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            recordOnlySourceId,
            keccak256("executor-authority"),
            "ipfs://m421-record-only-rejected"
        ) {
            revert("record-only allocation source was settled");
        } catch {}

        uint256 unauthorisedSourceId = _createM421RewardSource(
            workflowKey, "m421-unauthorised-source", token, 3, AVADataTypes.ValueExecutionMode.Claim
        );
        try valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.Editor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            unauthorisedSourceId,
            EDITOR_AUTHORITY,
            "ipfs://m421-unauthorised-settlement"
        ) {
            revert("unauthorised settlement accepted");
        } catch {}
        require(token.balanceOf(address(reviewerActor)) == 7, "unauthorised settlement changed token balance");
    }

    function testM421DuplicateValueSettlementRejected() public {
        bytes32 workflowKey = keccak256("m421-duplicate-settlement-workflow");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m421-duplicate-settlement-workflow");
        MockERC20 token = _m421FundedToken(50);
        uint256 sourceId = _createM421RewardSource(
            workflowKey, "m421-duplicate-source", token, 5, AVADataTypes.ValueExecutionMode.Claim
        );

        valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m421-first-settlement"
        );
        try valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m421-duplicate-settlement"
        ) {
            revert("duplicate settlement accepted");
        } catch {}
    }

    function testM426ValueSettlementRejectsTokenCallbackReentrancy() public {
        bytes32 workflowKey = keccak256("m426-settlement-reentrancy-workflow");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m426-settlement-reentrancy-workflow");
        ReentrantSettlementToken token = new ReentrantSettlementToken();
        token.mint(address(this), 20);
        (uint256 recognisedStateId, uint256 evidenceId) =
            _createM421EligibleState(workflowKey, "m426-settlement-reentrancy-source");

        AVADataTypes.ValueExecutionContext memory context;
        context.recognisedStateId = recognisedStateId;
        context.asset = address(token);
        context.payer = address(this);
        context.recipientSubjectId = REVIEWER_SUBJECT;
        context.amount = 5;
        context.mode = AVADataTypes.ValueExecutionMode.Claim;
        context.settlementKind = AVADataTypes.ValueSettlementKind.TokenTransfer;
        context.executionReference = bytes32(evidenceId);
        context.authorityId = keccak256("executor-authority");
        context.evidenceReceiptId = evidenceId;
        context.uri = "ipfs://m426-reentrant-source";
        context.actor = address(this);
        uint256 sourceId =
            allocationExecutor.recordRewardValueWithExecution(AVADataTypes.Role.ProtocolExecutor, context);

        bytes32 tokenAuthorityId = keccak256("m426-reentrant-token-authority");
        roleRegistry.assignRole(
            address(token), AVADataTypes.Role.ProtocolExecutor, tokenAuthorityId, "ipfs://m426-reentrant-token"
        );
        uint256 packageId = stateMachine.getRecognisedState(recognisedStateId).packageId;
        uint256 revisionBefore = standingRevisionRegistry.currentRevision(packageId, REVIEWER_SUBJECT);
        token.configure(valueSettlementExecutor, sourceId, packageId, REVIEWER_SUBJECT, tokenAuthorityId);

        uint256 settlementId = valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m426-token-transfer-settlement"
        );

        require(settlementId == 1, "outer settlement should be first and only record");
        require(valueSettlementExecutor.nextValueSettlementId() == 2, "reentrant settlement created extra record");
        require(token.attemptedReentry(), "malicious token did not attempt reentry");
        require(!token.reentrySucceeded(), "reentrant settlement succeeded");
        require(token.reentryFailed(), "reentrant settlement was not rejected");
        require(
            token.sourceStatusObservedDuringCallback() == AVADataTypes.ValueSettlementStatus.Settled,
            "settlement state was not written before token callback"
        );
        require(
            token.standingRevisionObservedDuringCallback() == revisionBefore + 1,
            "standing revision was not advanced before token callback"
        );
        require(token.balanceOf(address(reviewerActor)) == 5, "settlement amount changed");
    }
}

contract AVASkeletonSettlement03BTest is AVASkeletonFixture {
    function testM421EscrowClaimAndRefundStateWorks() public {
        bytes32 workflowKey = keccak256("m421-escrow-workflow");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m421-escrow-workflow");
        MockERC20 token = _m421FundedToken(100);
        uint256 claimSourceId = _createM421RewardSource(
            workflowKey, "m421-escrow-claim-source", token, 11, AVADataTypes.ValueExecutionMode.Escrow
        );

        valueSettlementExecutor.depositEscrow(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            claimSourceId,
            keccak256("executor-authority"),
            "ipfs://m421-escrow-deposit"
        );
        require(token.balanceOf(address(valueSettlementExecutor)) == 11, "escrow deposit not held");
        uint256 claimId = valueSettlementExecutor.claimEscrow(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            claimSourceId,
            keccak256("executor-authority"),
            "ipfs://m421-escrow-claim"
        );
        require(
            valueSettlementExecutor.getValueSettlement(claimId).status == AVADataTypes.ValueSettlementStatus.Claimed,
            "escrow claim not recorded"
        );
        require(token.balanceOf(address(reviewerActor)) == 11, "escrow claim not transferred");

        uint256 refundSourceId = _createM421RewardSource(
            workflowKey, "m421-escrow-refund-source", token, 13, AVADataTypes.ValueExecutionMode.Escrow
        );
        valueSettlementExecutor.depositEscrow(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            refundSourceId,
            keccak256("executor-authority"),
            "ipfs://m421-escrow-refund-deposit"
        );
        uint256 refundId = valueSettlementExecutor.refundEscrow(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            refundSourceId,
            keccak256("executor-authority"),
            "ipfs://m421-escrow-refund"
        );
        require(
            valueSettlementExecutor.getValueSettlement(refundId).status == AVADataTypes.ValueSettlementStatus.Refunded,
            "escrow refund not recorded"
        );
        require(token.balanceOf(address(valueSettlementExecutor)) == 0, "escrow balance not cleared");
    }

    function testM421PriorityTokenExecutionCannotAffectPublicationOutcome() public {
        bytes32 workflowKey = keccak256("m421-priority-token-workflow");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m421-priority-token-workflow");
        MockPriorityToken priorityToken = new MockPriorityToken();
        priorityToken.setMinter(address(valueSettlementExecutor));
        uint256 mintSourceId = _createM421PrioritySource(
            workflowKey,
            "m421-priority-mint-source",
            priorityToken,
            2,
            AVADataTypes.ValueExecutionMode.Claim,
            AVADataTypes.ValueSettlementKind.PriorityTokenMint
        );

        valueSettlementExecutor.mintPriorityToken(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            mintSourceId,
            keccak256("executor-authority"),
            "ipfs://m421-priority-mint"
        );
        require(priorityToken.balanceOf(address(reviewerActor)) == 2, "priority token not minted");

        uint256 consumeSourceId = _createM421PrioritySource(
            workflowKey,
            "m421-priority-consume-source",
            priorityToken,
            1,
            AVADataTypes.ValueExecutionMode.Claim,
            AVADataTypes.ValueSettlementKind.PriorityTokenConsume
        );
        valueSettlementExecutor.consumePriorityToken(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            consumeSourceId,
            keccak256("executor-authority"),
            "ipfs://m421-priority-consume"
        );
        require(priorityToken.balanceOf(address(reviewerActor)) == 1, "priority token not consumed");
        _assertNoSelector(address(valueSettlementExecutor), "acceptManuscript(uint256)");
        _assertNoSelector(address(valueSettlementExecutor), "rejectManuscript(uint256)");
        _assertNoSelector(address(valueSettlementExecutor), "setManuscriptMerit(uint256,uint256)");
        _assertNoSelector(address(valueSettlementExecutor), "grantPublicationPriority(uint256)");
        _assertNoSelector(address(valueSettlementExecutor), "setReviewerLeniency(uint256,uint256)");
        _assertNoSelector(address(valueSettlementExecutor), "executeQueue(uint256)");
    }

    function testM85PrioritySettlementReceiptBindsSourceContextWithoutStandingTokenSemantics() public {
        bytes32 workflowKey = keccak256("m85-priority-context-workflow");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m85-priority-context-workflow");
        MockPriorityToken priorityToken = new MockPriorityToken();
        priorityToken.setMinter(address(valueSettlementExecutor));
        uint256 sourceId = _createM421PrioritySource(
            workflowKey,
            "m85-priority-context-source",
            priorityToken,
            4,
            AVADataTypes.ValueExecutionMode.Claim,
            AVADataTypes.ValueSettlementKind.PriorityTokenMint
        );

        uint256 settlementId = valueSettlementExecutor.mintPriorityToken(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m85-priority-context-settlement"
        );

        AVADataTypes.AllocationExecutionRecord memory source = allocationExecutor.getAllocationExecution(sourceId);
        AVADataTypes.ValueSettlementRecord memory settlement = valueSettlementExecutor.getValueSettlement(settlementId);
        ValueSettlementExecutor.SettlementContextInput memory expectedInput;
        expectedInput.sourceType = AVADataTypes.ExecutionSourceType.AllocationRecord;
        expectedInput.sourceRecordId = sourceId;
        expectedInput.recognisedStateId = source.recognisedStateId;
        expectedInput.packageId = source.packageId;
        expectedInput.subjectId = source.subjectId;
        expectedInput.asset = source.asset;
        expectedInput.payer = source.payer;
        expectedInput.recipient = settlement.recipient;
        expectedInput.amountOrUnits = source.amountOrUnits;
        expectedInput.sourceExecutionMode = source.executionMode;
        expectedInput.sourceSettlementKind = source.settlementKind;
        expectedInput.sourceExecutionReference = source.executionReference;
        expectedInput.settlementKind = settlement.kind;
        expectedInput.status = settlement.status;
        bytes32 expectedContextHash = valueSettlementExecutor.computeSettlementContextHash(expectedInput);
        expectedInput.recognisedStateId = source.recognisedStateId + 1;
        bytes32 otherStateContextHash = valueSettlementExecutor.computeSettlementContextHash(expectedInput);

        require(
            valueSettlementExecutor.VALUE_SETTLEMENT_CONTEXT_DOMAIN() == keccak256("AVA_VALUE_SETTLEMENT_CONTEXT_V2"),
            "settlement context domain not versioned"
        );
        require(settlement.recognisedStateId == source.recognisedStateId, "settlement recognised state missing");
        require(settlement.sourceExecutionMode == source.executionMode, "settlement source mode missing");
        require(settlement.sourceSettlementKind == source.settlementKind, "settlement source kind missing");
        require(settlement.sourceExecutionReference == source.executionReference, "settlement source reference missing");
        require(settlement.settlementContextHash == expectedContextHash, "settlement context hash mismatch");
        require(otherStateContextHash != expectedContextHash, "settlement context not state bound");
        require(priorityToken.balanceOf(address(reviewerActor)) == 4, "priority right token not minted");
        _assertNoSelector(address(priorityToken), "mintStanding(address,uint256)");
        _assertNoSelector(address(priorityToken), "mintReputation(address,uint256)");
        _assertNoSelector(address(priorityToken), "transferStanding(address,uint256)");
        _assertNoSelector(address(priorityToken), "transferReputation(address,uint256)");
        _assertNoSelector(address(valueSettlementExecutor), "grantPublicationPriority(uint256)");
        _assertNoSelector(address(valueSettlementExecutor), "setManuscriptMerit(uint256,uint256)");
    }
}

contract AVASkeletonSettlement04ATest is AVASkeletonFixture {
    function testM425ValueSettlementRequiresSourceSettlementKind() public {
        bytes32 workflowKey = keccak256("m425-settlement-kind-workflow");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m425-settlement-kind-workflow");

        MockPriorityToken priorityToken = new MockPriorityToken();
        priorityToken.setMinter(address(valueSettlementExecutor));
        uint256 consumeSourceId = _createM421PrioritySource(
            workflowKey,
            "m425-priority-consume-source",
            priorityToken,
            3,
            AVADataTypes.ValueExecutionMode.Claim,
            AVADataTypes.ValueSettlementKind.PriorityTokenConsume
        );
        try valueSettlementExecutor.mintPriorityToken(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            consumeSourceId,
            keccak256("executor-authority"),
            "ipfs://m425-consume-source-mint"
        ) {
            revert("priority consume source minted priority token");
        } catch {}
        require(priorityToken.balanceOf(address(reviewerActor)) == 0, "mismatched priority source changed balance");

        MockERC20 token = _m421FundedToken(20);
        (,, uint256 penaltyId,) = _createM425BoundRecoveryPenalty(workflowKey, "m425-clawback-source", token, 5);
        try valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.ConsequenceRecord,
            penaltyId,
            keccak256("executor-authority"),
            "ipfs://m425-clawback-as-token-transfer"
        ) {
            revert("clawback source settled as token transfer");
        } catch {}
        require(token.balanceOf(address(reviewerActor)) == 5, "origin reward not settled");

        uint256 obligationId = valueSettlementExecutor.recordRepaymentObligation(
            AVADataTypes.Role.ProtocolExecutor,
            penaltyId,
            keccak256("executor-authority"),
            "ipfs://m425-valid-clawback-obligation"
        );
        uint256 clawbackSettlementId = valueSettlementExecutor.settleClawback(
            AVADataTypes.Role.ProtocolExecutor,
            obligationId,
            keccak256("executor-authority"),
            "ipfs://m425-valid-clawback-settlement"
        );
        require(token.balanceOf(address(reviewerActor)) == 0, "clawback did not debit subject account");
        require(token.balanceOf(address(this)) == 20, "clawback did not return original asset");
        require(
            valueSettlementExecutor.getValueSettlement(clawbackSettlementId).kind
                == AVADataTypes.ValueSettlementKind.ClawbackTransfer,
            "clawback settlement kind missing"
        );
    }

    function testPostAuditRecoveryPenaltyRequiresCompletedExactlyMatchingOriginSettlement() public {
        bytes32 workflowKey = keccak256("post-audit-origin-match-workflow");
        MockERC20 token = _m421FundedToken(30);
        _registerM425RecoveryWorkflow(workflowKey, token, "post-audit-origin-match");
        _assertUnsettledOriginCannotCreateRecoveryPenalty(workflowKey, token);

        uint256 originSourceId = _createM421RewardSource(
            workflowKey, "post-audit-origin-match-source", token, 7, AVADataTypes.ValueExecutionMode.Claim
        );
        AVADataTypes.AllocationExecutionRecord memory origin = allocationExecutor.getAllocationExecution(originSourceId);
        uint256 originSettlementId = valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            originSourceId,
            keccak256("executor-authority"),
            "ipfs://post-audit-origin-settlement"
        );
        uint256 challengeId = _fileAndResolveM425OriginChallenge(workflowKey, originSourceId, "post-audit-origin-match");
        AVADataTypes.ValueExecutionContext memory overRecoveryContext = _valueContext(
            origin.recognisedStateId,
            REVIEWER_SUBJECT,
            8,
            origin.evidenceReceiptId,
            keccak256("panel-authority"),
            "ipfs://post-audit-over-recovery",
            keccak256("post-audit-over-recovery"),
            address(token),
            address(this),
            AVADataTypes.ValueExecutionMode.Claim
        );
        overRecoveryContext.settlementKind = AVADataTypes.ValueSettlementKind.ClawbackTransfer;
        try consequenceExecutor.recordPenalty(
            AVADataTypes.Role.Panel,
            AVADataTypes.PenaltyConsequenceContext({
                challengeId: challengeId,
                findingKind: AVADataTypes.GovernanceFindingKind.IrresponsibleReview,
                originSettlementId: originSettlementId
            }),
            overRecoveryContext
        ) {
            revert("mismatched recovery amount accepted");
        } catch {}

        uint256 penaltyId = _recordM425ActivePenalty(
            originSourceId, originSettlementId, challengeId, token, 7, "post-audit-origin-match"
        );
        AVADataTypes.ConsequenceRecord memory penalty = consequenceExecutor.getConsequence(penaltyId);
        require(penalty.originSettlementId == originSettlementId, "penalty origin not stored");
        require(penalty.amountOrUnits == 7, "penalty amount drifted from origin");
    }

    function testRecoveryPenaltyRejectsOriginSettlementFromDifferentRecognisedState() public {
        bytes32 workflowKey = keccak256("recovery-origin-state-lineage-workflow");
        MockERC20 token = _m421FundedToken(30);
        _registerM425RecoveryWorkflow(workflowKey, token, "recovery-origin-state-lineage");

        uint256 originSourceId = _createM421RewardSource(
            workflowKey, "recovery-origin-state-lineage-origin", token, 7, AVADataTypes.ValueExecutionMode.Claim
        );
        uint256 originSettlementId = valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            originSourceId,
            keccak256("executor-authority"),
            "ipfs://recovery-origin-state-lineage-origin-settlement"
        );

        uint256 unrelatedSourceId = _createM421RewardSource(
            workflowKey, "recovery-origin-state-lineage-unrelated", token, 7, AVADataTypes.ValueExecutionMode.Claim
        );
        uint256 challengeId = _fileAndResolveM425OriginChallenge(
            workflowKey, unrelatedSourceId, "recovery-origin-state-lineage-unrelated"
        );

        bool accepted;
        try this.recordCrossStateRecoveryPenalty(unrelatedSourceId, originSettlementId, challengeId, token, 7) returns (
            uint256
        ) {
            accepted = true;
        } catch {}
        require(!accepted, "recovery penalty accepted origin from different recognised state");
    }

    function recordCrossStateRecoveryPenalty(
        uint256 sourceId,
        uint256 originSettlementId,
        uint256 challengeId,
        MockERC20 token,
        uint256 amount
    ) external returns (uint256 penaltyId) {
        penaltyId = _recordM425ActivePenalty(
            sourceId, originSettlementId, challengeId, token, amount, "recovery-origin-state-lineage-cross-state"
        );
    }

    function _assertUnsettledOriginCannotCreateRecoveryPenalty(bytes32 workflowKey, MockERC20 token) internal {
        uint256 sourceId = _createM421RewardSource(
            workflowKey, "post-audit-unsettled-origin-source", token, 7, AVADataTypes.ValueExecutionMode.Claim
        );
        uint256 challengeId = _fileAndResolveM425OriginChallenge(workflowKey, sourceId, "post-audit-unsettled-origin");
        AVADataTypes.AllocationExecutionRecord memory source = allocationExecutor.getAllocationExecution(sourceId);
        AVADataTypes.ValueExecutionContext memory recoveryContext = _valueContext(
            source.recognisedStateId,
            REVIEWER_SUBJECT,
            7,
            source.evidenceReceiptId,
            keccak256("panel-authority"),
            "ipfs://post-audit-unsettled-origin",
            keccak256("post-audit-unsettled-origin"),
            address(token),
            address(this),
            AVADataTypes.ValueExecutionMode.Claim
        );
        recoveryContext.settlementKind = AVADataTypes.ValueSettlementKind.ClawbackTransfer;
        try consequenceExecutor.recordPenalty(
            AVADataTypes.Role.Panel,
            AVADataTypes.PenaltyConsequenceContext({
                challengeId: challengeId,
                findingKind: AVADataTypes.GovernanceFindingKind.IrresponsibleReview,
                originSettlementId: valueSettlementExecutor.nextValueSettlementId()
            }),
            recoveryContext
        ) {
            revert("unsettled origin created active recovery penalty");
        } catch {}
    }

    function testPostAuditClawbackWritesTerminalStateBeforeTokenCallbackAndRejectsReentry() public {
        bytes32 workflowKey = keccak256("post-audit-clawback-reentrancy-workflow");
        ReentrantSettlementToken token = new ReentrantSettlementToken();
        token.mint(address(this), 20);
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            new MockERC20RecoveryValueExecutionAdapter(address(token)),
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("post-audit-clawback-reentrancy-compatible"),
            false,
            "ipfs://post-audit-clawback-reentrancy-workflow"
        );
        (uint256 recognisedStateId, uint256 evidenceId) =
            _createM421EligibleState(workflowKey, "post-audit-clawback-reentrancy-state");
        uint256 originSourceId = allocationExecutor.recordRewardValueWithExecution(
            AVADataTypes.Role.ProtocolExecutor,
            _valueContext(
                recognisedStateId,
                REVIEWER_SUBJECT,
                6,
                evidenceId,
                keccak256("executor-authority"),
                "ipfs://post-audit-clawback-reentrancy-origin",
                keccak256("post-audit-clawback-reentrancy-origin"),
                address(token),
                address(this),
                AVADataTypes.ValueExecutionMode.Claim
            )
        );
        uint256 originSettlementId = valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            originSourceId,
            keccak256("executor-authority"),
            "ipfs://post-audit-clawback-reentrancy-origin-settlement"
        );
        uint256 challengeId =
            _fileAndResolveM425OriginChallenge(workflowKey, originSourceId, "post-audit-clawback-reentrancy");
        AVADataTypes.ValueExecutionContext memory recoveryContext = _valueContext(
            recognisedStateId,
            REVIEWER_SUBJECT,
            6,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://post-audit-clawback-reentrancy-penalty",
            keccak256("post-audit-clawback-reentrancy-penalty"),
            address(token),
            address(this),
            AVADataTypes.ValueExecutionMode.Claim
        );
        recoveryContext.settlementKind = AVADataTypes.ValueSettlementKind.ClawbackTransfer;
        uint256 penaltyId = consequenceExecutor.recordPenalty(
            AVADataTypes.Role.Panel,
            AVADataTypes.PenaltyConsequenceContext({
                challengeId: challengeId,
                findingKind: AVADataTypes.GovernanceFindingKind.IrresponsibleReview,
                originSettlementId: originSettlementId
            }),
            recoveryContext
        );
        uint256 obligationId = valueSettlementExecutor.recordRepaymentObligation(
            AVADataTypes.Role.ProtocolExecutor,
            penaltyId,
            keccak256("executor-authority"),
            "ipfs://post-audit-clawback-reentrancy-obligation"
        );
        bytes32 tokenAuthorityId = keccak256("post-audit-clawback-reentrant-token-authority");
        roleRegistry.assignRole(
            address(token),
            AVADataTypes.Role.ProtocolExecutor,
            tokenAuthorityId,
            "ipfs://post-audit-clawback-reentrant-token"
        );
        token.configureRecovery(valueSettlementExecutor, obligationId, tokenAuthorityId);

        uint256 settlementId = valueSettlementExecutor.settleClawback(
            AVADataTypes.Role.ProtocolExecutor,
            obligationId,
            keccak256("executor-authority"),
            "ipfs://post-audit-clawback-reentrancy-settlement"
        );

        require(token.attemptedReentry(), "clawback token did not attempt reentry");
        require(!token.reentrySucceeded() && token.reentryFailed(), "clawback reentry was not rejected");
        require(
            token.recoveryStatusObservedDuringCallback() == AVADataTypes.ValueSettlementStatus.Settled,
            "terminal recovery state was not written before token callback"
        );
        require(
            valueSettlementExecutor.recoveryTerminalSettlementIdByObligationId(obligationId) == settlementId,
            "clawback terminal settlement not linked"
        );
    }
}

contract AVASkeletonSettlement04BTest is AVASkeletonFixture {
    function testPostAuditRawStandingUpdateSkipsComputationModuleRejectsDuplicateAndAdvancesRevision() public {
        bytes32 workflowKey = keccak256("post-audit-raw-standing-workflow");
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            new RejectingStandingComputationModule(),
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("post-audit-raw-standing-compatible"),
            false,
            "ipfs://post-audit-raw-standing-workflow"
        );
        (uint256 recognisedStateId, uint256 evidenceId) =
            _createM421EligibleState(workflowKey, "post-audit-raw-standing-state");
        uint256 packageId = stateMachine.getRecognisedState(recognisedStateId).packageId;
        uint256 revisionBefore = standingRevisionRegistry.currentRevision(packageId, REVIEWER_SUBJECT);

        uint256 standingUpdateId = standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            "review-procedure-weight",
            3,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://post-audit-raw-standing-update"
        );
        require(standingUpdateId != 0, "raw standing update was routed through computation module");
        require(
            standingRevisionRegistry.currentRevision(packageId, REVIEWER_SUBJECT) == revisionBefore + 1,
            "standing update did not advance revision"
        );

        uint256 nextUpdateId = standingRegistry.nextStandingUpdateId();
        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            "review-procedure-weight",
            3,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://post-audit-raw-standing-update"
        ) {
            revert("duplicate standing update accepted");
        } catch {}
        require(standingRegistry.nextStandingUpdateId() == nextUpdateId, "duplicate standing update wrote record");

        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            "review-procedure-weight",
            2,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://post-audit-standing-update-metadata-variant"
        ) {
            revert("standing update source accepted changed delta or metadata");
        } catch {}
        require(
            standingRegistry.nextStandingUpdateId() == nextUpdateId, "standing update metadata variant wrote record"
        );

        AVADataTypes.StandingComputationContext memory context =
            _m68StandingComputationContext(recognisedStateId, evidenceId, "post-audit-rejected-computation", 1);
        try standingRegistry.recordStandingComputationReadiness(
            AVADataTypes.Role.Panel, context, "ipfs://post-audit-rejected-computation"
        ) {
            revert("rejecting computation module was bypassed by computation readiness");
        } catch {}
    }

    function testPostAuditPenaltyEffectsAreBoundedDeduplicatedAndRevisionTracked() public {
        uint256 challengeId = _m121ResolveMaliciousChallenge(DEFAULT_WORKFLOW, "post-audit-penalty-effects");
        AVADataTypes.ChallengeRecord memory challenge = challengeWorkflow.getChallenge(challengeId);
        uint256 penaltyId = _recordPenaltyForChallenge(
            challenge.challengedRecognisedStateId,
            challengeId,
            AVADataTypes.GovernanceFindingKind.MaliciousOrFabricatedChallenge,
            CHALLENGER_SUBJECT,
            challenge.evidenceReceiptId,
            keccak256("panel-authority"),
            "ipfs://post-audit-penalty-effects"
        );
        uint256 packageId = consequenceExecutor.getConsequence(penaltyId).packageId;
        uint256 revisionBefore = standingRevisionRegistry.currentRevision(packageId, CHALLENGER_SUBJECT);

        uint256 nextPenaltyId = consequenceExecutor.nextConsequenceId();
        string memory duplicatePenaltyURI = "ipfs://post-audit-duplicate-penalty-source";
        try consequenceExecutor.recordPenalty(
            AVADataTypes.Role.Panel,
            AVADataTypes.PenaltyConsequenceContext({
                challengeId: challengeId,
                findingKind: AVADataTypes.GovernanceFindingKind.MaliciousOrFabricatedChallenge,
                originSettlementId: 0
            }),
            _valueContext(
                challenge.challengedRecognisedStateId,
                CHALLENGER_SUBJECT,
                1,
                challenge.evidenceReceiptId,
                keccak256("panel-authority"),
                duplicatePenaltyURI,
                keccak256(bytes(duplicatePenaltyURI)),
                address(0),
                address(0),
                AVADataTypes.ValueExecutionMode.RecordOnly
            )
        ) {
            revert("duplicate penalty source accepted with changed metadata");
        } catch {}
        require(consequenceExecutor.nextConsequenceId() == nextPenaltyId, "duplicate penalty source wrote record");

        try consequenceExecutor.recordStandingPenaltyInput(
            AVADataTypes.Role.Panel,
            penaltyId,
            "challenge-integrity-standing",
            -101,
            challenge.evidenceReceiptId,
            keccak256("panel-authority"),
            "ipfs://post-audit-over-bound-standing-penalty"
        ) {
            revert("out-of-bound standing penalty accepted");
        } catch {}
        uint256 inputId = consequenceExecutor.recordStandingPenaltyInput(
            AVADataTypes.Role.Panel,
            penaltyId,
            "challenge-integrity-standing",
            -100,
            challenge.evidenceReceiptId,
            keccak256("panel-authority"),
            "ipfs://post-audit-bounded-standing-penalty"
        );
        require(
            standingRevisionRegistry.currentRevision(packageId, CHALLENGER_SUBJECT) == revisionBefore + 1,
            "standing penalty did not advance revision"
        );
        try consequenceExecutor.recordStandingPenaltyInput(
            AVADataTypes.Role.Panel,
            penaltyId,
            "challenge-integrity-standing",
            -100,
            challenge.evidenceReceiptId,
            keccak256("panel-authority"),
            "ipfs://post-audit-bounded-standing-penalty"
        ) {
            revert("duplicate standing penalty accepted");
        } catch {}
        uint256 nextStandingPenaltyInputId = consequenceExecutor.nextStandingPenaltyInputId();
        try consequenceExecutor.recordStandingPenaltyInput(
            AVADataTypes.Role.Panel,
            penaltyId,
            "challenge-integrity-standing",
            -99,
            challenge.evidenceReceiptId,
            keccak256("panel-authority"),
            "ipfs://post-audit-standing-penalty-metadata-variant"
        ) {
            revert("standing penalty source accepted changed delta or metadata");
        } catch {}
        require(
            consequenceExecutor.nextStandingPenaltyInputId() == nextStandingPenaltyInputId,
            "standing penalty metadata variant wrote record"
        );
        require(consequenceExecutor.getStandingPenaltyInput(inputId).packageId == packageId, "penalty package missing");

        try consequenceExecutor.recordEligibilityRestriction(
            AVADataTypes.Role.Panel,
            penaltyId,
            AVADataTypes.EligibilityRestrictionKind.ReviewEligibility,
            block.timestamp + 1 days,
            challenge.evidenceReceiptId,
            keccak256("panel-authority"),
            "ipfs://post-audit-disabled-restriction-kind"
        ) {
            revert("disabled restriction kind accepted by default adapter");
        } catch {}
        try consequenceExecutor.recordEligibilityRestriction(
            AVADataTypes.Role.Panel,
            penaltyId,
            AVADataTypes.EligibilityRestrictionKind.ChallengeIntake,
            block.timestamp + 31 days,
            challenge.evidenceReceiptId,
            keccak256("panel-authority"),
            "ipfs://post-audit-overlong-restriction"
        ) {
            revert("overlong eligibility restriction accepted");
        } catch {}
        uint256 restrictionId = consequenceExecutor.recordEligibilityRestriction(
            AVADataTypes.Role.Panel,
            penaltyId,
            AVADataTypes.EligibilityRestrictionKind.ChallengeIntake,
            block.timestamp + 30 days,
            challenge.evidenceReceiptId,
            keccak256("panel-authority"),
            "ipfs://post-audit-bounded-restriction"
        );
        require(
            standingRevisionRegistry.currentRevision(packageId, CHALLENGER_SUBJECT) == revisionBefore + 2,
            "eligibility restriction did not advance revision"
        );
        require(
            consequenceExecutor.getEligibilityRestriction(restrictionId).packageId == packageId,
            "restriction package missing"
        );
        uint256 nextEligibilityRestrictionId = consequenceExecutor.nextEligibilityRestrictionId();
        try consequenceExecutor.recordEligibilityRestriction(
            AVADataTypes.Role.Panel,
            penaltyId,
            AVADataTypes.EligibilityRestrictionKind.ChallengeIntake,
            block.timestamp + 29 days,
            challenge.evidenceReceiptId,
            keccak256("panel-authority"),
            "ipfs://post-audit-restriction-metadata-variant"
        ) {
            revert("eligibility restriction source accepted changed duration or metadata");
        } catch {}
        require(
            consequenceExecutor.nextEligibilityRestrictionId() == nextEligibilityRestrictionId,
            "eligibility restriction metadata variant wrote record"
        );
    }

    function testPostAuditChallengeResolutionInvalidatesOldComputationAndCredentialByRevision() public {
        (uint256 recognisedStateId, uint256 evidenceId) =
            _createM421EligibleState(DEFAULT_WORKFLOW, "post-audit-challenge-revision-state");
        uint256 computationId =
            _recordStandingComputationForState(recognisedStateId, evidenceId, "post-audit-challenge-revision-old", 42);
        uint256 credentialId =
            _issueM422StandingCredential(computationId, "post-audit-challenge-revision-old", block.timestamp + 7 days);
        AVADataTypes.RecognisedStateRecord memory state = stateMachine.getRecognisedState(recognisedStateId);
        uint256 targetRevisionBefore = standingRevisionRegistry.currentRevision(state.packageId, REVIEWER_SUBJECT);
        uint256 challengerRevisionBefore = standingRevisionRegistry.currentRevision(state.packageId, CHALLENGER_SUBJECT);

        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            DEFAULT_WORKFLOW,
            keccak256("post-audit-challenge-revision-evidence"),
            "ipfs://post-audit-challenge-revision-evidence",
            "standing-revision-challenge",
            0
        );
        uint256 challengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            DEFAULT_WORKFLOW,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            0
        );
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Vested,
            keccak256("panel-authority"),
            "ipfs://post-audit-challenge-revision-resolution"
        );

        require(
            standingRevisionRegistry.currentRevision(state.packageId, REVIEWER_SUBJECT) == targetRevisionBefore + 1,
            "challenge resolution did not advance target revision"
        );
        require(
            standingRevisionRegistry.currentRevision(state.packageId, CHALLENGER_SUBJECT)
                == challengerRevisionBefore + 1,
            "challenge resolution did not advance challenger revision"
        );
        require(!_m422CredentialProves(credentialId, 40), "old credential survived challenge revision");
        require(
            !standingRegistry.isStandingComputationActive(computationId), "old computation survived challenge revision"
        );
        try standingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m422CredentialInputForComputation(
                computationId, block.timestamp + 7 days, "ipfs://post-audit-stale-computation-reissue"
            )
        ) {
            revert("stale computation issued a credential");
        } catch {}

        uint256 refreshedComputationId =
            _recordStandingComputationForState(recognisedStateId, evidenceId, "post-audit-challenge-revision-new", 45);
        uint256 refreshedCredentialId = _issueM422StandingCredential(
            refreshedComputationId, "post-audit-challenge-revision-new", block.timestamp + 7 days
        );
        require(_m422CredentialProves(refreshedCredentialId, 40), "current revision credential did not prove");
    }

    function testUpheldChallengeAdvancesTargetStandingRevisionExactlyOnce() public {
        (uint256 recognisedStateId,) = _createM421EligibleState(DEFAULT_WORKFLOW, "p3-upheld-single-target-revision");
        AVADataTypes.RecognisedStateRecord memory state = stateMachine.getRecognisedState(recognisedStateId);
        uint256 targetRevisionBefore = standingRevisionRegistry.currentRevision(state.packageId, REVIEWER_SUBJECT);
        uint256 challengerRevisionBefore = standingRevisionRegistry.currentRevision(state.packageId, CHALLENGER_SUBJECT);

        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            DEFAULT_WORKFLOW,
            keccak256("p3-upheld-single-target-revision-evidence"),
            "ipfs://p3-upheld-single-target-revision-evidence",
            "standing-revision-challenge",
            0
        );
        uint256 challengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            DEFAULT_WORKFLOW,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            0
        );
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            keccak256("panel-authority"),
            "ipfs://p3-upheld-single-target-revision-resolution"
        );

        require(
            standingRevisionRegistry.currentRevision(state.packageId, REVIEWER_SUBJECT) == targetRevisionBefore + 1,
            "upheld correction advanced target revision more than once"
        );
        require(
            standingRevisionRegistry.currentRevision(state.packageId, CHALLENGER_SUBJECT)
                == challengerRevisionBefore + 1,
            "upheld resolution did not advance challenger revision"
        );
    }
}

contract AVASkeletonSettlement05ATest is AVASkeletonFixture {
    function testPostAuditRewardSettlementAutomaticallyInvalidatesOldCredentialRevision() public {
        bytes32 workflowKey = keccak256("post-audit-settlement-revision-workflow");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://post-audit-settlement-revision-workflow");
        (uint256 recognisedStateId, uint256 evidenceId) =
            _createM421EligibleState(workflowKey, "post-audit-settlement-revision-state");
        MockERC20 token = _m421FundedToken(20);
        uint256 sourceId = allocationExecutor.recordRewardValueWithExecution(
            AVADataTypes.Role.ProtocolExecutor,
            _valueContext(
                recognisedStateId,
                REVIEWER_SUBJECT,
                5,
                evidenceId,
                keccak256("executor-authority"),
                "ipfs://post-audit-settlement-revision-source",
                keccak256("post-audit-settlement-revision-source"),
                address(token),
                address(this),
                AVADataTypes.ValueExecutionMode.Claim
            )
        );
        uint256 computationId =
            _recordStandingComputationForState(recognisedStateId, evidenceId, "post-audit-settlement-revision-old", 42);
        uint256 credentialId =
            _issueM422StandingCredential(computationId, "post-audit-settlement-revision-old", block.timestamp + 7 days);
        uint256 packageId = stateMachine.getRecognisedState(recognisedStateId).packageId;
        uint256 revisionBefore = standingRevisionRegistry.currentRevision(packageId, REVIEWER_SUBJECT);
        valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://post-audit-settlement-revision"
        );
        require(
            standingRevisionRegistry.currentRevision(packageId, REVIEWER_SUBJECT) == revisionBefore + 1,
            "reward settlement did not advance revision"
        );
        require(!_m422CredentialProves(credentialId, 40), "old credential survived reward settlement revision");
        require(!standingRegistry.isStandingComputationActive(computationId), "old computation survived settlement");
    }

    function testPostAuditZKStandingProofAndCredentialBindCurrentRevision() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        Actor zkSubjectActor = new Actor();
        roleRegistry.assignRole(
            address(zkSubjectActor),
            AVADataTypes.Role.Reviewer,
            subjectCommitment,
            "ipfs://post-audit-zk-standing-subject"
        );
        (uint256 recognisedStateId, uint256 evidenceId) = _createM421EligibleStateForSubject(
            DEFAULT_WORKFLOW, subjectCommitment, "post-audit-zk-standing-revision-state"
        );
        uint256 packageId = stateMachine.getRecognisedState(recognisedStateId).packageId;
        uint256 proofReceiptId =
            _createM66StandingProofReceipt(DEFAULT_WORKFLOW, subjectCommitment, "post-audit-zk-standing-revision-old");
        uint256 credentialId = zkStandingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m66CredentialInput(proofReceiptId, packageId, subjectCommitment, "post-audit-zk-standing-revision-old")
        );
        require(
            zkStandingCredentialRegistry.credentialProves(
                credentialId, packageId, subjectCommitment, _m422VectorKey(), _m422CategoryHash(), 40
            ),
            "fresh zk standing credential did not prove"
        );
        uint256 revisionBefore = standingRevisionRegistry.currentRevision(packageId, subjectCommitment);
        standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            subjectCommitment,
            "review-procedure-weight",
            1,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://post-audit-zk-standing-revision-update"
        );
        require(
            standingRevisionRegistry.currentRevision(packageId, subjectCommitment) == revisionBefore + 1,
            "zk subject standing update did not advance revision"
        );
        require(
            !zkStandingCredentialRegistry.credentialProves(
                credentialId, packageId, subjectCommitment, _m422VectorKey(), _m422CategoryHash(), 40
            ),
            "stale zk credential survived revision"
        );
        try zkStandingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m66CredentialInput(proofReceiptId, packageId, subjectCommitment, "post-audit-zk-standing-stale-reissue")
        ) {
            revert("stale zk proof issued a new credential");
        } catch {}

        uint256 refreshedProofReceiptId = _createM66StandingProofReceipt(
            DEFAULT_WORKFLOW, subjectCommitment, "post-audit-zk-standing-revision-new", 2
        );
        uint256 refreshedCredentialId = zkStandingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m66CredentialInput(
                refreshedProofReceiptId, packageId, subjectCommitment, "post-audit-zk-standing-revision-new"
            )
        );
        require(
            zkStandingCredentialRegistry.credentialProves(
                refreshedCredentialId, packageId, subjectCommitment, _m422VectorKey(), _m422CategoryHash(), 40
            ),
            "refreshed zk standing credential did not prove"
        );
    }

    function testM425RecoveryReceiptsRejectRecordOnlySources() public {
        bytes32 workflowKey = keccak256("m425-record-only-recovery-workflow");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m425-record-only-recovery-workflow");
        (uint256 stateId, uint256 challengeId, uint256 evidenceId) = _createResolvedChallengeForWorkflowSubject(
            workflowKey,
            REVIEWER_SUBJECT,
            "m425-record-only-recovery-source",
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded
        );
        uint256 penaltyId = _recordPenaltyForChallenge(
            stateId,
            challengeId,
            AVADataTypes.GovernanceFindingKind.IrresponsibleReview,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://m425-record-only-penalty"
        );
        uint256 nextSettlementId = valueSettlementExecutor.nextValueSettlementId();

        try valueSettlementExecutor.recordRepaymentObligation(
            AVADataTypes.Role.ProtocolExecutor,
            penaltyId,
            keccak256("executor-authority"),
            "ipfs://m425-record-only-repayment"
        ) {
            revert("record-only source created repayment obligation");
        } catch {}
        try valueSettlementExecutor.recordFuturePayoutSetoff(
            AVADataTypes.Role.ProtocolExecutor,
            penaltyId,
            keccak256("executor-authority"),
            "ipfs://m425-record-only-setoff"
        ) {
            revert("record-only source created future setoff");
        } catch {}
        try valueSettlementExecutor.recordWaiver(
            AVADataTypes.Role.ProtocolExecutor,
            penaltyId,
            keccak256("executor-authority"),
            "ipfs://m425-record-only-waiver"
        ) {
            revert("record-only source created waiver");
        } catch {}
        try valueSettlementExecutor.recordSatisfaction(
            AVADataTypes.Role.ProtocolExecutor,
            penaltyId,
            keccak256("executor-authority"),
            "ipfs://m425-record-only-satisfaction"
        ) {
            revert("record-only source created satisfaction");
        } catch {}
        require(
            valueSettlementExecutor.nextValueSettlementId() == nextSettlementId, "record-only recovery receipt stored"
        );
    }
}

contract AVASkeletonSettlement05BTest is AVASkeletonFixture {
    function testM55RecoveryTerminalStateConflictsAreRejected() public {
        bytes32 workflowKey = keccak256("m55-recovery-terminal-workflow");
        MockERC20 token = _m421FundedToken(100);
        (,, uint256 penaltyId,) = _createM425BoundRecoveryPenalty(workflowKey, "m55-terminal-source", token, 8);
        uint256 obligationId = valueSettlementExecutor.recordRepaymentObligation(
            AVADataTypes.Role.ProtocolExecutor,
            penaltyId,
            keccak256("executor-authority"),
            "ipfs://m55-terminal-obligation"
        );
        uint256 setoffId = valueSettlementExecutor.recordFuturePayoutSetoff(
            AVADataTypes.Role.ProtocolExecutor,
            obligationId,
            keccak256("executor-authority"),
            "ipfs://m55-terminal-setoff"
        );

        require(
            valueSettlementExecutor.getValueSettlement(obligationId).status
                == AVADataTypes.ValueSettlementStatus.ObligationRecorded,
            "obligation missing"
        );
        require(
            valueSettlementExecutor.recoveryTerminalSettlementIdByObligationId(obligationId) == setoffId,
            "terminal settlement id missing"
        );
        require(
            valueSettlementExecutor.recoveryTerminalStatusByObligationId(obligationId)
                == AVADataTypes.ValueSettlementStatus.SetoffRecorded,
            "terminal status missing"
        );

        uint256 nextSettlementId = valueSettlementExecutor.nextValueSettlementId();
        try valueSettlementExecutor.recordWaiver(
            AVADataTypes.Role.ProtocolExecutor,
            obligationId,
            keccak256("executor-authority"),
            "ipfs://m55-conflicting-waiver"
        ) {
            revert("waiver accepted after setoff terminal");
        } catch {}
        try valueSettlementExecutor.recordSatisfaction(
            AVADataTypes.Role.ProtocolExecutor,
            obligationId,
            keccak256("executor-authority"),
            "ipfs://m55-conflicting-satisfaction"
        ) {
            revert("satisfaction accepted after setoff terminal");
        } catch {}
        try valueSettlementExecutor.recordRepaymentObligation(
            AVADataTypes.Role.ProtocolExecutor,
            penaltyId,
            keccak256("executor-authority"),
            "ipfs://m55-conflicting-obligation"
        ) {
            revert("repayment obligation accepted after recovery terminal");
        } catch {}
        require(
            valueSettlementExecutor.nextValueSettlementId() == nextSettlementId, "conflicting recovery receipt stored"
        );
    }

    function testM55EscrowTerminalConflictsRejectRefundAndOpenRecovery() public {
        bytes32 workflowKey = keccak256("m55-escrow-terminal-workflow");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m55-escrow-terminal-workflow");
        MockERC20 token = _m421FundedToken(100);
        uint256 sourceId = _createM421RewardSource(
            workflowKey, "m55-escrow-source", token, 11, AVADataTypes.ValueExecutionMode.Escrow
        );

        valueSettlementExecutor.depositEscrow(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m55-escrow-deposit"
        );
        uint256 nextSettlementId = valueSettlementExecutor.nextValueSettlementId();
        try valueSettlementExecutor.recordFuturePayoutSetoff(
            AVADataTypes.Role.ProtocolExecutor,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m55-open-escrow-setoff"
        ) {
            revert("open escrow accepted recovery terminal");
        } catch {}
        require(
            valueSettlementExecutor.nextValueSettlementId() == nextSettlementId, "open escrow recovery receipt stored"
        );

        valueSettlementExecutor.claimEscrow(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m55-escrow-claim"
        );
        try valueSettlementExecutor.refundEscrow(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m55-escrow-refund-after-claim"
        ) {
            revert("refund accepted after escrow claim");
        } catch {}

        uint256 refundSourceId = _createM421RewardSource(
            workflowKey, "m55-refunded-source", token, 5, AVADataTypes.ValueExecutionMode.Escrow
        );
        valueSettlementExecutor.depositEscrow(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            refundSourceId,
            keccak256("executor-authority"),
            "ipfs://m55-refund-deposit"
        );
        valueSettlementExecutor.refundEscrow(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            refundSourceId,
            keccak256("executor-authority"),
            "ipfs://m55-refund-terminal"
        );
        nextSettlementId = valueSettlementExecutor.nextValueSettlementId();
        try valueSettlementExecutor.recordSatisfaction(
            AVADataTypes.Role.ProtocolExecutor,
            refundSourceId,
            keccak256("executor-authority"),
            "ipfs://m55-refunded-satisfaction"
        ) {
            revert("refunded escrow accepted recovery terminal");
        } catch {}
        require(
            valueSettlementExecutor.nextValueSettlementId() == nextSettlementId,
            "refunded escrow recovery receipt stored"
        );
    }
}
