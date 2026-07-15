// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./helpers/AVASkeletonFixture.sol";

contract AVASkeletonChallengeDisclosure01ATest is AVASkeletonFixture {
    function testChallengeWorkflowCanDifferFromTargetRecognisedStatePackage() public {
        bytes32 reviewWorkflow = keccak256("review-service-ava");
        bytes32 challengeWorkflowKey = keccak256("challenge-integrity-ava");
        _registerDefaultRulePackage(reviewWorkflow, "ipfs://review-workflow");
        _registerDefaultRulePackage(challengeWorkflowKey, "ipfs://challenge-workflow");

        AVARulePackageRegistry.RulePackage memory reviewPackage = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, reviewWorkflow);
        uint256 reviewStateId = _createChallengeableReviewStateThroughPackage(reviewPackage, reviewWorkflow);
        AVADataTypes.RecognisedStateRecord memory reviewState = stateMachine.getRecognisedState(reviewStateId);

        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            challengeWorkflowKey,
            keccak256("workflow-challenge-evidence"),
            "ipfs://workflow-challenge",
            "review-quality-challenge",
            0
        );
        AVARulePackageRegistry.RulePackage memory challengePackage =
            rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, challengeWorkflowKey);
        uint256 challengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            challengeWorkflowKey,
            reviewStateId,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            0
        );

        AVADataTypes.ChallengeRecord memory challenge = challengeWorkflow.getChallenge(challengeId);
        require(reviewState.id == reviewStateId, "review state missing");
        require(reviewState.workflowKey == reviewWorkflow, "review workflow key wrong");
        require(challenge.workflowKey == challengeWorkflowKey, "challenge workflow key wrong");
        require(challenge.packageId == challengePackage.packageId, "challenge package wrong");
        require(challenge.targetWorkflowKey == reviewWorkflow, "target workflow key wrong");
        require(challenge.targetPackageId == reviewPackage.packageId, "target package wrong");
        require(challenge.attributedObjectId != bytes32(0), "challenge attribution missing");
        require(challenge.challengedRecognisedStateId == reviewStateId, "wrong target");
        require(address(reviewPackage.attributionModule) == address(attributionModule), "review package wrong");
        require(address(challengePackage.verificationModule) == address(verificationModule), "challenge package wrong");
        require(standingRegistry.nextStandingUpdateId() == 1, "workflow package created standing update");
        require(consequenceExecutor.nextConsequenceId() == 1, "workflow package created consequence");
    }

    function testDisclosureModuleCanVaryByStageActionAndObject() public {
        bytes32 blockedObject = keccak256("blocked-disclosure-object");
        StageScopedDisclosureModule stageScopedDisclosure = new StageScopedDisclosureModule(
            AVADataTypes.Action.FileChallenge, AVADataTypes.AVAStage.Verification, blockedObject
        );
        bytes32 defaultWorkflow = keccak256("default-disclosure-workflow");
        bytes32 scopedWorkflow = keccak256("scoped-disclosure-workflow");

        _registerRulePackage(defaultWorkflow, disclosurePolicyModule, allocationAdapter, consequenceAdapter, "ipfs://d");
        _registerRulePackage(scopedWorkflow, stageScopedDisclosure, allocationAdapter, consequenceAdapter, "ipfs://s");

        AVARulePackageRegistry.RulePackage memory defaultPackage = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, defaultWorkflow);
        AVARulePackageRegistry.RulePackage memory scopedPackage = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, scopedWorkflow);

        defaultPackage.disclosureModule.validateDisclosureForAction(
            0,
            AVADataTypes.Role.Challenger,
            AVADataTypes.Action.FileChallenge,
            AVADataTypes.AVAStage.Verification,
            blockedObject,
            defaultWorkflow,
            defaultPackage.packageId,
            CHALLENGER_SUBJECT
        );
        scopedPackage.disclosureModule.validateDisclosureForAction(
            1,
            AVADataTypes.Role.Challenger,
            AVADataTypes.Action.ScreenChallenge,
            AVADataTypes.AVAStage.Verification,
            blockedObject,
            scopedWorkflow,
            scopedPackage.packageId,
            CHALLENGER_SUBJECT
        );

        try scopedPackage.disclosureModule.validateDisclosureForAction(
            1,
            AVADataTypes.Role.Challenger,
            AVADataTypes.Action.FileChallenge,
            AVADataTypes.AVAStage.Verification,
            blockedObject,
            scopedWorkflow,
            scopedPackage.packageId,
            CHALLENGER_SUBJECT
        ) {
            revert("stage-scoped disclosure did not block matching action");
        } catch {}
    }

    function testM481DifferentWorkflowsCanBindDifferentDisclosureScenarioModules() public {
        uint256 blindedPolicyId = _registerDisclosurePolicy("m481-double-blind-policy");
        uint256 panelPolicyId = _registerDisclosurePolicy("m481-panel-visible-policy");
        DoubleBlindDisclosureModule doubleBlindModule =
            new DoubleBlindDisclosureModule(disclosureRegistry, blindedPolicyId);
        PanelVisibleDisclosureModule panelVisibleModule =
            new PanelVisibleDisclosureModule(disclosureRegistry, panelPolicyId);
        bytes32 doubleBlindWorkflow = keccak256("m481-double-blind-workflow");
        bytes32 panelVisibleWorkflow = keccak256("m481-panel-visible-workflow");

        _registerRulePackage(
            doubleBlindWorkflow, doubleBlindModule, allocationAdapter, consequenceAdapter, "ipfs://m481-double-blind"
        );
        _registerRulePackage(
            panelVisibleWorkflow, panelVisibleModule, allocationAdapter, consequenceAdapter, "ipfs://m481-panel-visible"
        );

        require(
            address(rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, doubleBlindWorkflow).disclosureModule)
                == address(doubleBlindModule),
            "double-blind disclosure module not bound"
        );
        require(
            address(rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, panelVisibleWorkflow).disclosureModule)
                == address(panelVisibleModule),
            "panel-visible disclosure module not bound"
        );
    }
}
contract AVASkeletonChallengeDisclosure01BTest is AVASkeletonFixture {
    function testM74DisclosureScenarioModulesAreRulePackageBindableAndRevealFree() public {
        uint256 doubleBlindPolicyId = _registerDisclosurePolicy("m74-double-blind-policy");
        uint256 panelPolicyId = _registerDisclosurePolicy("m74-panel-policy");
        uint256 anonymousPolicyId = _registerDisclosurePolicy("m74-anonymous-policy");
        uint256 realNamePolicyId = _registerDisclosurePolicy("m74-real-name-policy");
        uint256 authorIntentPolicyId = _registerDisclosurePolicy("m74-author-intent-policy");
        uint256 zkPolicyId = _registerDisclosurePolicy("m74-zk-policy");
        IDisclosurePolicyModule[6] memory modules = [
            IDisclosurePolicyModule(new DoubleBlindDisclosureModule(disclosureRegistry, doubleBlindPolicyId)),
            IDisclosurePolicyModule(new PanelVisibleDisclosureModule(disclosureRegistry, panelPolicyId)),
            IDisclosurePolicyModule(new AnonymousChallengeDisclosureModule(disclosureRegistry, anonymousPolicyId)),
            IDisclosurePolicyModule(new VoluntaryRealNameChallengeModule(disclosureRegistry, realNamePolicyId)),
            IDisclosurePolicyModule(new PostRecognitionAuthorRevealModule(disclosureRegistry, authorIntentPolicyId)),
            IDisclosurePolicyModule(
                new ZKBackedDisclosureModule(
                    disclosureRegistry, _newZkProofRegistry(new SchnorrDisclosureProofVerifier()), zkPolicyId
                )
            )
        ];

        for (uint256 i = 0; i < modules.length; i++) {
            bytes32 workflowKey = keccak256(abi.encode("m74-disclosure-scenario", i));
            _registerRulePackage(workflowKey, modules[i], allocationAdapter, consequenceAdapter, "ipfs://m74-scenario");
            require(
                address(rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).disclosureModule) == address(modules[i]),
                "scenario module not bound"
            );
            _assertNoSelector(address(modules[i]), "revealIdentity(uint256)");
            _assertNoSelector(address(modules[i]), "revealEvidence(uint256)");
            _assertNoSelector(address(modules[i]), "decryptEvidence(uint256)");
            _assertNoSelector(address(modules[i]), "acceptManuscript(uint256)");
            _assertNoSelector(address(modules[i]), "scoreManuscriptMerit(uint256)");
        }
    }

    function testM481DoubleBlindModuleBlocksIncompatibleDisclosureButAllowsBlindedReviewFlow() public {
        uint256 blindedPolicyId = _registerDisclosurePolicy("m481-blinded-review-policy");
        DoubleBlindDisclosureModule doubleBlindModule =
            new DoubleBlindDisclosureModule(disclosureRegistry, blindedPolicyId);
        bytes32 workflowKey = keccak256("m481-blinded-review-workflow");
        _registerRulePackage(
            workflowKey, doubleBlindModule, allocationAdapter, consequenceAdapter, "ipfs://m481-blinded-review"
        );

        try doubleBlindModule.validateDisclosureForAction(
            blindedPolicyId,
            AVADataTypes.Role.Author,
            AVADataTypes.Action.RegisterReviewContribution,
            AVADataTypes.AVAStage.Attribution,
            bytes32(uint256(1)),
            workflowKey,
            rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).packageId,
            REVIEWER_SUBJECT
        ) {
            revert("double-blind module accepted author as reviewer");
        } catch {}

        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m481-blinded-review-evidence"),
            "ipfs://m481-blinded-review",
            "double-blind-review",
            blindedPolicyId
        );
        uint256 reviewContributionId = reviewerActor.registerReviewContributionWithWorkflow(
            stateMachine, AVADataTypes.Role.Reviewer, workflowKey, manuscriptId, REVIEWER_SUBJECT, evidenceId, blindedPolicyId
        );
        uint256 recognisedStateId =
            stateMachine.provisionallyRecogniseReview(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);
        stateMachine.openReviewChallengeWindow(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);

        require(
            stateMachine.getRecognisedState(recognisedStateId).status == AVADataTypes.RecognisedStateStatus.Challengeable,
            "blinded review flow blocked"
        );
        require(standingRegistry.nextStandingUpdateId() == 1, "double-blind module created standing update");
        require(consequenceExecutor.nextConsequenceId() == 1, "double-blind module created consequence");
    }

    function testM102DoubleBlindReviewScenarioVestsBeforeDownstreamRecords() public {
        uint256 blindedPolicyId = _registerDisclosurePolicy("m102-double-blind-policy");
        DoubleBlindDisclosureModule doubleBlindModule =
            new DoubleBlindDisclosureModule(disclosureRegistry, blindedPolicyId);
        bytes32 workflowKey = keccak256("m102-double-blind-workflow");
        _registerRulePackage(
            workflowKey, doubleBlindModule, allocationAdapter, consequenceAdapter, "ipfs://m102-double-blind"
        );
        uint256 packageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).packageId;
        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m102-blinded-review-evidence"),
            "ipfs://m102-blinded-review",
            "double-blind-review",
            blindedPolicyId
        );
        uint256 reviewContributionId = reviewerActor.registerReviewContributionWithWorkflow(
            stateMachine, AVADataTypes.Role.Reviewer, workflowKey, manuscriptId, REVIEWER_SUBJECT, evidenceId, blindedPolicyId
        );
        uint256 recognisedStateId =
            stateMachine.provisionallyRecogniseReview(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);
        stateMachine.openReviewChallengeWindow(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);
        AVADataTypes.RecognisedStateRecord memory challengeableState =
            stateMachine.getRecognisedState(recognisedStateId);
        require(challengeableState.status == AVADataTypes.RecognisedStateStatus.Challengeable, "state not challengeable");
        require(challengeableState.packageId == packageId, "challengeable state package wrong");
        _assertAllDownstreamRejectTarget(recognisedStateId, evidenceId);

        vm.warp(
            uint256(stateMachine.getChallengeWindowOpenedAt(recognisedStateId))
                + stateMachine.minimumChallengeWindowDuration()
        );
        uint256 transitionId = stateMachine.vestReviewRecognition(
            AVADataTypes.Role.Panel, reviewContributionId, keccak256("panel-authority"), "ipfs://m102-review-vested"
        );
        AVADataTypes.RecognisedStateRecord memory vestedState = stateMachine.getRecognisedState(recognisedStateId);
        AVADataTypes.ReviewContributionRecord memory reviewContribution =
            stateMachine.getReviewContribution(reviewContributionId);
        AVADataTypes.RecognisedStateTransitionRecord memory transition =
            stateMachine.getRecognisedStateTransition(transitionId);
        require(vestedState.status == AVADataTypes.RecognisedStateStatus.Vested, "state not vested");
        require(reviewContribution.status == AVADataTypes.ReviewContributionStatus.Vested, "review not vested");
        require(transition.packageId == packageId, "vesting transition package wrong");
        _assertRecognisedStateTransition(
            transitionId,
            recognisedStateId,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            AVADataTypes.RecognisedStateStatus.Vested,
            AVADataTypes.Action.TransitionRecognisedState,
            0
        );

        _assertM102DownstreamRecordsBindPackage(recognisedStateId, evidenceId, packageId);
        _assertNoSelector(address(doubleBlindModule), "revealIdentity(uint256)");
        _assertNoSelector(address(doubleBlindModule), "acceptManuscript(uint256)");
        _assertNoSelector(address(doubleBlindModule), "setManuscriptMerit(uint256,uint256)");
    }
}

contract AVASkeletonChallengeDisclosure02ATest is AVASkeletonFixture {
    function testSubstrateMinimumChallengeWindowBlocksImmediateVesting() public {
        M102DoubleBlindReviewContext memory context =
            _createM102ChallengeableDoubleBlindReview("substrate-minimum-window");
        uint256 openedAt = stateMachine.getChallengeWindowOpenedAt(context.recognisedStateId);

        try stateMachine.vestReviewRecognition(
            AVADataTypes.Role.Panel,
            context.reviewContributionId,
            keccak256("panel-authority"),
            "ipfs://substrate-window-too-early"
        ) {
            revert("substrate allowed immediate challenge-window vesting");
        } catch {}
        require(
            stateMachine.getRecognisedState(context.recognisedStateId).status
                == AVADataTypes.RecognisedStateStatus.Challengeable,
            "rejected immediate vesting mutated state"
        );

        vm.warp(openedAt + 1 days);
        stateMachine.vestReviewRecognition(
            AVADataTypes.Role.Panel,
            context.reviewContributionId,
            keccak256("panel-authority"),
            "ipfs://substrate-window-complete"
        );
        require(
            stateMachine.getRecognisedState(context.recognisedStateId).status
                == AVADataTypes.RecognisedStateStatus.Vested,
            "review did not vest after substrate minimum"
        );
    }

    function testSubstrateRejectsConcurrentAndRepeatedChallengeFromSameSubjectAndTargetVersion() public {
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 firstEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256("first-concurrent-challenge"),
            "ipfs://first-concurrent-challenge",
            "review-quality-challenge",
            0
        );
        uint256 firstChallengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            firstEvidenceId,
            0
        );
        uint256 secondEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256("second-concurrent-challenge"),
            "ipfs://second-concurrent-challenge",
            "review-quality-challenge",
            0
        );

        try challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            secondEvidenceId,
            0
        ) {
            revert("substrate accepted concurrent duplicate challenge");
        } catch {}
        require(
            stateMachine.openChallengeCountForRecognisedState(recognisedStateId) == 1,
            "rejected concurrent challenge changed open count"
        );

        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, firstChallengeId, EDITOR_AUTHORITY);
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            firstChallengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://first-concurrent-challenge-resolution"
        );
        challengeWorkflow.closeChallenge(
            AVADataTypes.Role.Panel,
            firstChallengeId,
            keccak256("panel-authority"),
            "ipfs://first-concurrent-challenge-close"
        );
        uint256 nextChallengeId = challengeWorkflow.nextChallengeId();
        try challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            secondEvidenceId,
            0
        ) {
            revert("substrate accepted repeated challenge against unchanged target version");
        } catch {}
        require(challengeWorkflow.nextChallengeId() == nextChallengeId, "rejected repeated challenge wrote state");
        require(
            stateMachine.openChallengeCountForRecognisedState(recognisedStateId) == 0,
            "rejected repeated challenge changed open count"
        );
    }

    function testM102DoubleBlindReviewCannotVestWhileChallengeOpen() public {
        M102DoubleBlindReviewContext memory context =
            _createM102ChallengeableDoubleBlindReview("m102-open-challenge");
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            context.workflowKey,
            keccak256("m102-open-challenge-evidence"),
            "ipfs://m102-open-challenge",
            "review-quality-challenge",
            0
        );
        uint256 challengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            context.workflowKey,
            context.recognisedStateId,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            0
        );
        require(
            stateMachine.openChallengeCountForRecognisedState(context.recognisedStateId) == 1,
            "open challenge count missing"
        );

        try stateMachine.vestReviewRecognition(
            AVADataTypes.Role.Panel,
            context.reviewContributionId,
            keccak256("panel-authority"),
            "ipfs://m102-blocked-vesting"
        ) {
            revert("review vested while challenge open");
        } catch {}

        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://m102-good-faith-resolution"
        );
        challengeWorkflow.closeChallenge(
            AVADataTypes.Role.Panel, challengeId, keccak256("panel-authority"), "ipfs://m102-close-challenge"
        );
        require(
            stateMachine.openChallengeCountForRecognisedState(context.recognisedStateId) == 0,
            "closed challenge still counted"
        );
        vm.warp(
            uint256(stateMachine.getChallengeWindowOpenedAt(context.recognisedStateId))
                + stateMachine.minimumChallengeWindowDuration()
        );
        stateMachine.vestReviewRecognition(
            AVADataTypes.Role.Panel,
            context.reviewContributionId,
            keccak256("panel-authority"),
            "ipfs://m102-review-vested-after-close"
        );
        require(
            stateMachine.getRecognisedState(context.recognisedStateId).status == AVADataTypes.RecognisedStateStatus.Vested,
            "review not vested after closed challenge"
        );
        _assertNoSelector(address(context.module), "revealIdentity(uint256)");
        _assertNoSelector(address(context.module), "acceptManuscript(uint256)");
    }

    function testTimedChallengeWindowPackageRejectsEarlyVestingAndAllowsAfterDuration() public {
        bytes32 workflowKey = keccak256("timed-challenge-window-workflow");
        uint64 minimumDuration = 2 days;
        _registerRulePackageWithModules(
            workflowKey,
            attributionModule,
            verificationModule,
            new MinimumChallengeWindowTransitionModule(minimumDuration),
            disclosurePolicyModule,
            allocationAdapter,
            consequenceAdapter,
            "ipfs://timed-challenge-window"
        );

        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("timed-window-review-evidence"),
            "ipfs://timed-window-review",
            "review-service-occurrence",
            0
        );
        uint256 reviewContributionId = reviewerActor.registerReviewContributionWithWorkflow(
            stateMachine, AVADataTypes.Role.Reviewer, workflowKey, manuscriptId, REVIEWER_SUBJECT, evidenceId, 0
        );
        uint256 recognisedStateId =
            stateMachine.provisionallyRecogniseReview(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);

        vm.warp(1_000);
        stateMachine.openReviewChallengeWindow(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);
        require(
            stateMachine.getChallengeWindowOpenedAt(recognisedStateId) == uint64(block.timestamp),
            "challenge window timestamp missing"
        );

        try stateMachine.vestReviewRecognition(
            AVADataTypes.Role.Panel,
            reviewContributionId,
            keccak256("panel-authority"),
            "ipfs://timed-window-too-early"
        ) {
            revert("timed challenge-window package allowed early vesting");
        } catch {}

        vm.warp(block.timestamp + minimumDuration);
        uint256 transitionId = stateMachine.vestReviewRecognition(
            AVADataTypes.Role.Panel,
            reviewContributionId,
            keccak256("panel-authority"),
            "ipfs://timed-window-vested"
        );
        require(transitionId != 0, "timed vesting transition missing");
        require(
            stateMachine.getRecognisedState(recognisedStateId).status == AVADataTypes.RecognisedStateStatus.Vested,
            "timed review did not vest after duration"
        );
    }

    function testSupportedBareRevertingChallengeWindowHookRejectsVesting() public {
        bytes32 workflowKey = keccak256("bare-revert-challenge-window-workflow");
        _registerRulePackageWithModules(
            workflowKey,
            attributionModule,
            verificationModule,
            new BareRevertingChallengeWindowTransitionModule(),
            disclosurePolicyModule,
            allocationAdapter,
            consequenceAdapter,
            "ipfs://bare-revert-challenge-window"
        );

        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("bare-revert-window-review-evidence"),
            "ipfs://bare-revert-window-review",
            "review-service-occurrence",
            0
        );
        uint256 reviewContributionId = reviewerActor.registerReviewContributionWithWorkflow(
            stateMachine, AVADataTypes.Role.Reviewer, workflowKey, manuscriptId, REVIEWER_SUBJECT, evidenceId, 0
        );
        uint256 recognisedStateId =
            stateMachine.provisionallyRecogniseReview(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);
        stateMachine.openReviewChallengeWindow(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);

        uint256 nextTransitionId = stateMachine.nextRecognisedStateTransitionId();
        try stateMachine.vestReviewRecognition(
            AVADataTypes.Role.Panel,
            reviewContributionId,
            keccak256("panel-authority"),
            "ipfs://bare-revert-window-vest"
        ) {
            revert("bare-reverting supported challenge-window hook was swallowed");
        } catch {}
        require(stateMachine.nextRecognisedStateTransitionId() == nextTransitionId, "bare-revert veto wrote transition");
        require(
            stateMachine.getRecognisedState(recognisedStateId).status == AVADataTypes.RecognisedStateStatus.Challengeable,
            "bare-revert veto mutated recognised state"
        );
    }
}
contract AVASkeletonChallengeDisclosure02BTest is AVASkeletonFixture {
    function testM481PanelVisibleModuleAllowsEditorPanelAndRejectsOrdinaryRoles() public {
        uint256 panelPolicyId = _registerDisclosurePolicy("m481-panel-visible-review-policy");
        PanelVisibleDisclosureModule panelVisibleModule =
            new PanelVisibleDisclosureModule(disclosureRegistry, panelPolicyId);
        bytes32 workflowKey = keccak256("m481-panel-visible-review-workflow");
        _registerRulePackage(
            workflowKey, panelVisibleModule, allocationAdapter, consequenceAdapter, "ipfs://m481-panel-visible-roles"
        );
        uint256 packageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).packageId;

        panelVisibleModule.validateDisclosureForAction(
            panelPolicyId,
            AVADataTypes.Role.Editor,
            AVADataTypes.Action.ScreenChallenge,
            AVADataTypes.AVAStage.Verification,
            bytes32(uint256(1)),
            workflowKey,
            packageId,
            CHALLENGER_SUBJECT
        );
        panelVisibleModule.validateDisclosureForAction(
            panelPolicyId,
            AVADataTypes.Role.Panel,
            AVADataTypes.Action.ResolveChallenge,
            AVADataTypes.AVAStage.Verification,
            bytes32(uint256(1)),
            workflowKey,
            packageId,
            CHALLENGER_SUBJECT
        );
        try panelVisibleModule.validateDisclosureForAction(
            panelPolicyId,
            AVADataTypes.Role.Reviewer,
            AVADataTypes.Action.ScreenChallenge,
            AVADataTypes.AVAStage.Verification,
            bytes32(uint256(1)),
            workflowKey,
            packageId,
            CHALLENGER_SUBJECT
        ) {
            revert("panel-visible module accepted ordinary role");
        } catch {}
    }

    function testM481AnonymousChallengeModuleSupportsChallengeWithoutRevealSelectors() public {
        uint256 anonymousPolicyId = _registerDisclosurePolicy("m481-anonymous-challenge-policy");
        AnonymousChallengeDisclosureModule anonymousModule =
            new AnonymousChallengeDisclosureModule(disclosureRegistry, anonymousPolicyId);
        bytes32 workflowKey = keccak256("m481-anonymous-challenge-workflow");
        _registerRulePackage(
            workflowKey, anonymousModule, allocationAdapter, consequenceAdapter, "ipfs://m481-anonymous-challenge"
        );
        uint256 recognisedStateId =
            _createChallengeableReviewStateThroughPackage(rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey), workflowKey);
        uint256 evidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            workflowKey,
            keccak256("m481-anonymous-challenge-evidence"),
            "ipfs://m481-anonymous-challenge",
            "anonymous-challenge",
            anonymousPolicyId
        );
        uint256 challengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            workflowKey,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            evidenceId,
            anonymousPolicyId
        );
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://m481-anonymous-resolution"
        );

        require(
            challengeWorkflow.getChallenge(challengeId).outcome == AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            "anonymous challenge flow failed"
        );
        _assertNoSelector(address(anonymousModule), "revealIdentity(uint256)");
        _assertNoSelector(address(anonymousModule), "decryptEvidence(uint256)");
    }

    function testM103AnonymousIntegrityChallengeScenarioRequiresActionBoundProofs() public {
        M103AnonymousChallengeContext memory context = _createM103FiledZkChallenge("m103-anonymous-integrity");
        bytes32 filingProofContextHash = zkProofRegistry.computeDisclosureContextHash(
            PEER_REVIEW_APP_ID,
            context.workflowKey,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            bytes32(context.recognisedStateId),
            AVADataTypes.Role.Challenger,
            context.policyId,
            context.subjectCommitment
        );
        uint256 filingProofReceiptId = zkProofRegistry.getProofReceiptId(filingProofContextHash);
        ZKProofRegistry.ProofReceipt memory filingProof = zkProofRegistry.getProofReceipt(filingProofReceiptId);
        try context.challenger.recordAnonymousChallengeProofUse(
            disclosureAccessExecutor,
            AVADataTypes.Role.Challenger,
            context.challengeId,
            context.policyId,
            filingProofReceiptId,
            context.subjectCommitment,
            filingProof.nullifierHash,
            "ipfs://m103-filing-proof-reuse"
        ) {
            revert("filing proof reused as anonymous proof use");
        } catch {}
        uint256 proofUseId = _recordM103AnonymousChallengeProofUse(context);
        AVADataTypes.DisclosureExecutionRecord memory proofUse =
            disclosureAccessExecutor.getDisclosureExecution(proofUseId);
        require(proofUse.packageId == context.packageId, "proof use package wrong");
        require(proofUse.targetId == context.challengeId, "proof use target wrong");
        require(proofUse.subjectCommitment == context.subjectCommitment, "proof use subject wrong");

        try challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, context.challengeId, EDITOR_AUTHORITY) {
            revert("screen accepted without action-bound proof");
        } catch {}
        _registerM103DisclosureProof(
            context,
            AVADataTypes.Action.ScreenChallenge,
            bytes32(context.recognisedStateId),
            AVADataTypes.Role.Editor
        );
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, context.challengeId, EDITOR_AUTHORITY);

        try challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            context.challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://m103-resolution"
        ) {
            revert("resolve accepted without action-bound proof");
        } catch {}
        _registerM103DisclosureProof(
            context,
            AVADataTypes.Action.ResolveChallenge,
            bytes32(context.recognisedStateId),
            AVADataTypes.Role.Panel
        );
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            context.challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://m103-resolution"
        );

        require(
            challengeWorkflow.getChallenge(context.challengeId).outcome == AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            "anonymous integrity challenge not resolved"
        );
        require(standingRegistry.nextStandingUpdateId() == 1, "anonymous challenge created standing");
        require(allocationExecutor.nextAllocationExecutionId() == 1, "anonymous challenge created allocation");
        require(consequenceExecutor.nextConsequenceId() == 1, "anonymous challenge created consequence");
        _assertNoSelector(address(context.module), "revealIdentity(uint256)");
        _assertNoSelector(address(context.module), "decryptEvidence(uint256)");
        _assertNoSelector(address(zkProofRegistry), "validateScientificTruth(uint256)");
    }
}

contract AVASkeletonChallengeDisclosure03ATest is AVASkeletonFixture {
    function testM104CorrectionRestorationScenarioRestoresAdverseStateWithoutErasingHistory() public {
        M104CorrectionRestorationContext memory context =
            _createM104DowngradedCorrectionState("m104-correction-restoration");
        AVADataTypes.ChallengeRecord memory correctedChallenge = challengeWorkflow.getChallenge(context.challengeId);
        uint256 correctionChallengeTransitionId = correctedChallenge.lastTransitionId;
        uint256 restorationStateTransitionId = stateMachine.nextRecognisedStateTransitionId();

        challengeWorkflow.applyRestoration(
            AVADataTypes.Role.Panel,
            context.challengeId,
            keccak256("panel-authority"),
            "ipfs://m104-restoration-transition"
        );

        AVADataTypes.ChallengeRecord memory restoredChallenge = challengeWorkflow.getChallenge(context.challengeId);
        AVADataTypes.ChallengeTransitionRecord memory correctionTransition =
            challengeWorkflow.getChallengeTransition(correctionChallengeTransitionId);
        AVADataTypes.ChallengeTransitionRecord memory restorationChallengeTransition =
            challengeWorkflow.getChallengeTransition(restoredChallenge.lastTransitionId);
        AVADataTypes.RecognisedStateTransitionRecord memory restorationStateTransition =
            stateMachine.getRecognisedStateTransition(restorationStateTransitionId);

        require(restoredChallenge.status == AVADataTypes.ChallengeLifecycleStatus.RestorationApplied, "not restored");
        require(correctionTransition.outcome == AVADataTypes.ChallengeOutcome.Upheld, "correction history erased");
        require(correctionTransition.toStatus == AVADataTypes.RecognisedStateStatus.Downgraded, "correction target erased");
        require(
            restorationChallengeTransition.transitionKind == AVADataTypes.ChallengeTransitionKind.RestorationRecorded,
            "restoration challenge transition missing"
        );
        require(
            restorationStateTransition.fromStatus == AVADataTypes.RecognisedStateStatus.Downgraded,
            "restoration from status wrong"
        );
        require(
            restorationStateTransition.toStatus == AVADataTypes.RecognisedStateStatus.Restored,
            "restoration state transition wrong"
        );
        require(
            stateMachine.getRecognisedState(context.recognisedStateId).status == AVADataTypes.RecognisedStateStatus.Restored,
            "state not restored"
        );
        require(consequenceExecutor.nextConsequenceId() == 1, "restoration auto-created consequence");
        require(standingRegistry.nextStandingUpdateId() == 1, "restoration auto-created standing update");
        require(allocationExecutor.nextAllocationExecutionId() == 1, "restoration auto-executed allocation");

        uint256 restorationRecordId = consequenceExecutor.recordRestoration(
            AVADataTypes.Role.Panel,
            context.recognisedStateId,
            REVIEWER_SUBJECT,
            context.challengeEvidenceId,
            keccak256("panel-authority"),
            "ipfs://m104-restoration-record"
        );
        AVADataTypes.ConsequenceRecord memory restorationRecord =
            consequenceExecutor.getConsequence(restorationRecordId);
        require(restorationRecord.packageId == context.packageId, "restoration package wrong");
        require(restorationRecord.kind == AVADataTypes.ConsequenceKind.RestorationRecord, "restoration kind wrong");
    }

    function testM105DoubleBlindVestingUsesHistoricalPackageAfterWorkflowReregistration() public {
        M102DoubleBlindReviewContext memory context = _createM102ChallengeableDoubleBlindReview("m105-double-blind");
        uint256 oldPackageId = context.packageId;

        _registerRulePackageWithModules(
            context.workflowKey,
            attributionModule,
            verificationModule,
            new RejectingTransitionRuleModule(),
            disclosurePolicyModule,
            allocationAdapter,
            consequenceAdapter,
            "ipfs://m105-double-blind-new-rejecting"
        );
        uint256 newPackageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, context.workflowKey).packageId;
        require(newPackageId != oldPackageId, "package not replaced");

        vm.warp(
            uint256(stateMachine.getChallengeWindowOpenedAt(context.recognisedStateId))
                + stateMachine.minimumChallengeWindowDuration()
        );
        uint256 transitionId = stateMachine.vestReviewRecognition(
            AVADataTypes.Role.Panel,
            context.reviewContributionId,
            keccak256("panel-authority"),
            "ipfs://m105-double-blind-vested"
        );
        AVADataTypes.RecognisedStateRecord memory recognisedState =
            stateMachine.getRecognisedState(context.recognisedStateId);
        AVADataTypes.RecognisedStateTransitionRecord memory transition =
            stateMachine.getRecognisedStateTransition(transitionId);

        require(recognisedState.packageId == oldPackageId, "recognised state package changed");
        require(recognisedState.status == AVADataTypes.RecognisedStateStatus.Vested, "review did not vest");
        require(transition.packageId == oldPackageId, "vesting used active package");
        _assertM102DownstreamRecordsBindPackage(context.recognisedStateId, context.evidenceId, oldPackageId);
    }

    function testM105AnonymousChallengeUsesHistoricalPackageAfterWorkflowReregistration() public {
        M103AnonymousChallengeContext memory context = _createM103FiledZkChallenge("m105-anonymous-challenge");
        uint256 oldPackageId = context.packageId;
        uint256 proofUseId = _recordM103AnonymousChallengeProofUse(context);
        _registerM103DisclosureProof(
            context,
            AVADataTypes.Action.ScreenChallenge,
            bytes32(context.recognisedStateId),
            AVADataTypes.Role.Editor
        );
        _registerM103DisclosureProof(
            context,
            AVADataTypes.Action.ResolveChallenge,
            bytes32(context.recognisedStateId),
            AVADataTypes.Role.Panel
        );

        _registerRulePackage(
            context.workflowKey,
            disclosurePolicyModule,
            allocationAdapter,
            consequenceAdapter,
            "ipfs://m105-anonymous-new-default"
        );
        uint256 newPackageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, context.workflowKey).packageId;
        require(newPackageId != oldPackageId, "package not replaced");

        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, context.challengeId, EDITOR_AUTHORITY);
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            context.challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://m105-anonymous-resolution"
        );
        AVADataTypes.ChallengeRecord memory challenge = challengeWorkflow.getChallenge(context.challengeId);
        AVADataTypes.ChallengeTransitionRecord memory transition =
            challengeWorkflow.getChallengeTransition(challenge.lastTransitionId);
        AVADataTypes.DisclosureExecutionRecord memory proofUse =
            disclosureAccessExecutor.getDisclosureExecution(proofUseId);

        require(challenge.packageId == oldPackageId, "challenge package changed");
        require(transition.packageId == oldPackageId, "challenge used active package");
        require(proofUse.packageId == oldPackageId, "proof use package changed");
        require(challenge.outcome == AVADataTypes.ChallengeOutcome.RejectedGoodFaith, "challenge not resolved");
    }
}
contract AVASkeletonChallengeDisclosure03BTest is AVASkeletonFixture {
    function testM105RestorationUsesHistoricalPackageAfterWorkflowReregistration() public {
        M104CorrectionRestorationContext memory context =
            _createM104DowngradedCorrectionState("m105-correction-restoration");
        uint256 oldPackageId = context.packageId;

        _registerRulePackageWithAdapters(
            context.workflowKey,
            allocationAdapter,
            consequenceAdapter,
            standingAdapter,
            rewardAdapter,
            priorityAdapter,
            penaltyAdapter,
            new MockRestorationAdapter(keccak256("panel-authority")),
            "ipfs://m105-restoration-new-blocking"
        );
        uint256 newPackageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, context.workflowKey).packageId;
        require(newPackageId != oldPackageId, "package not replaced");

        uint256 transitionId = stateMachine.nextRecognisedStateTransitionId();
        challengeWorkflow.applyRestoration(
            AVADataTypes.Role.Panel,
            context.challengeId,
            keccak256("panel-authority"),
            "ipfs://m105-restoration-transition"
        );
        AVADataTypes.RecognisedStateTransitionRecord memory transition =
            stateMachine.getRecognisedStateTransition(transitionId);
        uint256 restorationRecordId = consequenceExecutor.recordRestoration(
            AVADataTypes.Role.Panel,
            context.recognisedStateId,
            REVIEWER_SUBJECT,
            context.challengeEvidenceId,
            keccak256("panel-authority"),
            "ipfs://m105-restoration-record"
        );
        AVADataTypes.ConsequenceRecord memory restorationRecord =
            consequenceExecutor.getConsequence(restorationRecordId);

        require(transition.packageId == oldPackageId, "restoration transition used active package");
        require(restorationRecord.packageId == oldPackageId, "restoration record used active package");
        require(restorationRecord.kind == AVADataTypes.ConsequenceKind.RestorationRecord, "restoration kind wrong");
    }

    function testM481VoluntaryRealNameChallengeCannotBypassCoreGates() public {
        uint256 realNamePolicyId = _registerDisclosurePolicy("m481-real-name-challenge-policy");
        VoluntaryRealNameChallengeModule realNameModule =
            new VoluntaryRealNameChallengeModule(disclosureRegistry, realNamePolicyId);
        bytes32 workflowKey = keccak256("m481-real-name-challenge-workflow");
        _registerRulePackage(
            workflowKey, realNameModule, allocationAdapter, consequenceAdapter, "ipfs://m481-real-name-challenge"
        );
        uint256 recognisedStateId =
            _createChallengeableReviewStateThroughPackage(rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey), workflowKey);
        uint256 evidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            workflowKey,
            keccak256("m481-real-name-challenge-evidence"),
            "ipfs://m481-real-name-challenge",
            "real-name-challenge",
            realNamePolicyId
        );

        try outsiderActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            workflowKey,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            evidenceId,
            realNamePolicyId
        ) {
            revert("real-name module bypassed authority");
        } catch {}
        try challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            workflowKey,
            recognisedStateId + 999,
            CHALLENGER_SUBJECT,
            evidenceId,
            realNamePolicyId
        ) {
            revert("real-name module bypassed recognised-state target");
        } catch {}
        try challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            workflowKey,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            0,
            realNamePolicyId
        ) {
            revert("real-name module bypassed evidence gate");
        } catch {}

        uint256 challengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            workflowKey,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            evidenceId,
            realNamePolicyId
        );
        try challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            keccak256("panel-authority"),
            "ipfs://m481-real-name-unscreened"
        ) {
            revert("real-name module bypassed challenge lifecycle");
        } catch {}
        roleRegistry.assignRole(address(challengerActor), AVADataTypes.Role.Panel, keccak256("m481-panel-challenger"), "ipfs://panel");
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        try challengerActor.resolveChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            keccak256("panel-authority"),
            "ipfs://m481-real-name-self-resolution"
        ) {
            revert("real-name module bypassed self-resolution gate");
        } catch {}
        _assertNoSelector(address(realNameModule), "validateScientificTruth(uint256)");
    }

    function testM481PostRecognitionAuthorRevealModuleIsValidationOnly() public {
        uint256 authorRevealPolicyId = _registerDisclosurePolicy("m481-author-reveal-policy");
        PostRecognitionAuthorRevealModule authorRevealModule =
            new PostRecognitionAuthorRevealModule(disclosureRegistry, authorRevealPolicyId);
        bytes32 workflowKey = keccak256("m481-author-reveal-workflow");
        _registerRulePackage(
            workflowKey, authorRevealModule, allocationAdapter, consequenceAdapter, "ipfs://m481-author-reveal"
        );
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m481-author-reveal-evidence"),
            "ipfs://m481-author-reveal",
            "post-recognition-author-reveal",
            authorRevealPolicyId
        );
        uint256 stateId = stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            PEER_REVIEW_APP_ID,
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            keccak256("m481-author-reveal-object"),
            REVIEWER_SUBJECT,
            evidenceId,
            authorRevealPolicyId,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        );

        require(stateMachine.getRecognisedState(stateId).disclosurePolicyId == authorRevealPolicyId, "policy not recorded");
        _assertNoSelector(address(authorRevealModule), "revealIdentity(uint256)");
        _assertNoSelector(address(authorRevealModule), "acceptManuscript(uint256)");
        _assertNoSelector(address(authorRevealModule), "scoreManuscriptMerit(uint256)");
    }
}

contract AVASkeletonChallengeDisclosure04ATest is AVASkeletonFixture {
    function testM484ValidProofRegistersWithMatchingSubjectCommitment() public {
        SchnorrDisclosureProofVerifier verifier = new SchnorrDisclosureProofVerifier();
        ZKProofRegistry proofRegistry = _newZkProofRegistry(verifier);
        uint256 disclosurePolicyId = _registerDisclosurePolicy("m484-valid-proof-policy");
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        bytes32 contextHash = proofRegistry.computeDisclosureContextHash(
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            keccak256("m482-object"),
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment
        );
        IZKProofVerifier.SchnorrProof memory proof = _makeSchnorrProof(contextHash, 7, 11);

        require(verifier.verify(contextHash, proof), "valid proof rejected by verifier");
        uint256 receiptId = proofRegistry.registerProof(
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            keccak256("m482-object"),
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment,
            proof
        );
        ZKProofRegistry.ProofReceipt memory receipt = proofRegistry.getProofReceipt(receiptId);

        require(receipt.packageId == rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW).packageId, "wrong proof package");
        require(receipt.contextHash == contextHash, "wrong context hash");
        require(receipt.subjectCommitment == subjectCommitment, "wrong subject commitment");
        require(receipt.nullifierHash == proofRegistry.computeNullifierHash(contextHash, subjectCommitment), "wrong nullifier");
        require(proofRegistry.getProofReceiptId(contextHash) == receiptId, "receipt not indexed");
        require(proofRegistry.getProofReceiptIdByNullifier(receipt.nullifierHash) == receiptId, "nullifier not indexed");
        require(proofRegistry.hasVerifiedProof(contextHash), "proof receipt missing");
    }

    function testM484MismatchedSubjectCommitmentIsRejected() public {
        SchnorrDisclosureProofVerifier verifier = new SchnorrDisclosureProofVerifier();
        ZKProofRegistry proofRegistry = _newZkProofRegistry(verifier);
        uint256 disclosurePolicyId = _registerDisclosurePolicy("m484-mismatched-subject-policy");
        bytes32 wrongSubjectCommitment = _subjectCommitmentForSecret(9);
        bytes32 contextHash = proofRegistry.computeDisclosureContextHash(
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            keccak256("m482-invalid-object"),
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            wrongSubjectCommitment
        );
        IZKProofVerifier.SchnorrProof memory proof = _makeSchnorrProof(contextHash, 7, 11);

        try proofRegistry.registerProof(
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            keccak256("m482-invalid-object"),
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            wrongSubjectCommitment,
            proof
        ) {
            revert("mismatched subject commitment accepted");
        } catch {}
    }

    function testM484InvalidSchnorrProofRejected() public {
        SchnorrDisclosureProofVerifier verifier = new SchnorrDisclosureProofVerifier();
        ZKProofRegistry proofRegistry = _newZkProofRegistry(verifier);
        uint256 disclosurePolicyId = _registerDisclosurePolicy("m484-invalid-proof-policy");
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        bytes32 contextHash = proofRegistry.computeDisclosureContextHash(
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            keccak256("m482-invalid-proof-object"),
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment
        );
        IZKProofVerifier.SchnorrProof memory proof = _makeSchnorrProof(contextHash, 7, 11);
        proof.response = addmod(proof.response, 1, BN254_GROUP_ORDER);

        try proofRegistry.registerProof(
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            keccak256("m482-invalid-proof-object"),
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment,
            proof
        ) {
            revert("invalid proof accepted");
        } catch {}
    }
}
contract AVASkeletonChallengeDisclosure04BTest is AVASkeletonFixture {
    function testM484ProofCannotReplayAcrossWorkflowActionObjectPolicyOrSubject() public {
        SchnorrDisclosureProofVerifier verifier = new SchnorrDisclosureProofVerifier();
        ZKProofRegistry proofRegistry = _newZkProofRegistry(verifier);
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        bytes32 workflowKey = keccak256("m482-replay-workflow");
        _ensureWorkflowPackage(workflowKey);
        uint256 disclosurePolicyId = _registerDisclosurePolicy("m484-replay-policy");
        bytes32 objectId = keccak256("m482-replay-object");
        bytes32 contextHash = proofRegistry.computeDisclosureContextHash(
            PEER_REVIEW_APP_ID,
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment
        );
        IZKProofVerifier.SchnorrProof memory proof = _makeSchnorrProof(contextHash, 7, 11);

        proofRegistry.registerProof(
            PEER_REVIEW_APP_ID,
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment,
            proof
        );

        _assertZkProofCannotReplayAcrossContext(
            proofRegistry, workflowKey, objectId, disclosurePolicyId, subjectCommitment, proof
        );
    }

    function testM484DuplicateNullifierContextIsRejected() public {
        SchnorrDisclosureProofVerifier verifier = new SchnorrDisclosureProofVerifier();
        ZKProofRegistry proofRegistry = _newZkProofRegistry(verifier);
        uint256 disclosurePolicyId = _registerDisclosurePolicy("m484-duplicate-policy");
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        bytes32 workflowKey = keccak256("m484-duplicate-workflow");
        _ensureWorkflowPackage(workflowKey);
        bytes32 objectId = keccak256("m484-duplicate-object");
        bytes32 contextHash = proofRegistry.computeDisclosureContextHash(
            PEER_REVIEW_APP_ID,
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment
        );
        proofRegistry.registerProof(
            PEER_REVIEW_APP_ID,
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment,
            _makeSchnorrProof(contextHash, 7, 11)
        );

        try proofRegistry.registerProof(
            PEER_REVIEW_APP_ID,
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment,
            _makeSchnorrProof(contextHash, 7, 13)
        ) {
            revert("duplicate nullifier/context accepted");
        } catch {}
    }

    function testM72DisclosureProofContextIncludesPackageAfterWorkflowReregistration() public {
        SchnorrDisclosureProofVerifier verifier = new SchnorrDisclosureProofVerifier();
        ZKProofRegistry proofRegistry = _newZkProofRegistry(verifier);
        bytes32 workflowKey = keccak256("m72-package-context-workflow");
        uint256 disclosurePolicyId = _registerDisclosurePolicy("m72-package-context-policy");
        bytes32 objectId = keccak256("m72-package-context-object");
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);

        _ensureWorkflowPackage(workflowKey);
        uint256 oldPackageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).packageId;
        bytes32 oldContextHash = proofRegistry.computeDisclosureContextHash(
            PEER_REVIEW_APP_ID,
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment
        );
        uint256 oldProofReceiptId = proofRegistry.nextProofReceiptId();
        _registerZkDisclosureProof(
            proofRegistry,
            workflowKey,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment
        );

        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m72-package-context-v2");
        uint256 newPackageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).packageId;
        require(newPackageId != oldPackageId, "workflow package did not change");
        bytes32 newContextHash = proofRegistry.computeDisclosureContextHash(
            PEER_REVIEW_APP_ID,
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment
        );
        require(oldContextHash != newContextHash, "package rotation did not change proof context");
        uint256 newProofReceiptId = proofRegistry.nextProofReceiptId();
        _registerZkDisclosureProof(
            proofRegistry,
            workflowKey,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment
        );

        ZKProofRegistry.ProofReceipt memory oldReceipt = proofRegistry.getProofReceipt(oldProofReceiptId);
        ZKProofRegistry.ProofReceipt memory newReceipt = proofRegistry.getProofReceipt(newProofReceiptId);
        require(oldReceipt.packageId == oldPackageId, "old proof package wrong");
        require(newReceipt.packageId == newPackageId, "new proof package wrong");
        require(oldReceipt.nullifierHash != newReceipt.nullifierHash, "package contexts shared nullifier");
        require(proofRegistry.getProofReceiptId(oldContextHash) == oldProofReceiptId, "old context index lost");
        require(proofRegistry.getProofReceiptId(newContextHash) == newProofReceiptId, "new context index missing");
    }
}

contract AVASkeletonChallengeDisclosure05ATest is AVASkeletonFixture {
    function testM81ZKProofReceiptsBindVerifierAndProofDomain() public {
        SchnorrDisclosureProofVerifier verifier = new SchnorrDisclosureProofVerifier();
        ZKProofRegistry proofRegistry = _newZkProofRegistry(verifier);
        uint256 disclosurePolicyId = _registerDisclosurePolicy("m81-proof-domain-policy");
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        bytes32 objectId = keccak256("m81-proof-domain-object");
        uint256 packageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW).packageId;
        bytes32 contextHash = proofRegistry.computeDisclosureContextHash(
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment
        );
        require(
            contextHash
                == proofRegistry.computeDisclosureContextHashForPackageAndProofDomain(
                    packageId,
                    verifier.proofDomain(),
                    PEER_REVIEW_APP_ID,
                    DEFAULT_WORKFLOW,
                    AVADataTypes.AVAStage.Verification,
                    AVADataTypes.Action.FileChallenge,
                    objectId,
                    AVADataTypes.Role.Challenger,
                    disclosurePolicyId,
                    subjectCommitment
                ),
            "disclosure proof context omitted proof domain"
        );
        uint256 proofReceiptId = proofRegistry.registerProof(
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment,
            _makeSchnorrProof(contextHash, 7, 11)
        );
        ZKProofRegistry.ProofReceipt memory proofReceipt = proofRegistry.getProofReceipt(proofReceiptId);
        require(proofReceipt.verifier == address(verifier), "disclosure proof verifier not recorded");
        require(proofReceipt.proofDomainHash == verifier.proofDomain(), "disclosure proof domain not recorded");

        bytes32 standingSubjectCommitment = _subjectCommitmentForSecret(13);
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(DEFAULT_WORKFLOW, standingSubjectCommitment, "m81-standing-domain");
        (input,,,) = _bindM93StandingProofInput(input, "m81-standing-domain");
        bytes32 standingContextHash = zkStandingComputationRegistry.computeStandingComputationContextHash(input);
        require(
            standingContextHash
                == zkStandingComputationRegistry.computeStandingComputationContextHashForProofDomain(
                    input, zkStandingComputationRegistry.verifier().proofDomain()
                ),
            "standing proof context omitted proof domain"
        );
        uint256 standingReceiptId = zkStandingComputationRegistry.registerStandingProof(
            input,
            _makeSchnorrProof(standingContextHash, 13, 17)
        );
        ZKStandingComputationRegistry.StandingProofReceipt memory standingReceipt =
            zkStandingComputationRegistry.getStandingProofReceipt(standingReceiptId);
        require(
            standingReceipt.verifier == address(zkStandingComputationRegistry.verifier()),
            "standing proof verifier not recorded"
        );
        require(
            standingReceipt.proofDomainHash == zkStandingComputationRegistry.verifier().proofDomain(),
            "standing proof domain not recorded"
        );
    }

    function testM417ZKProofRegistryRequiresKnownWorkflowAndDisclosurePolicy() public {
        ZKProofRegistry proofRegistry = _newZkProofRegistry(new SchnorrDisclosureProofVerifier());
        bytes32 workflowKey = keccak256("m417-zk-workflow");
        bytes32 objectId = keccak256("m417-zk-object");
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        uint256 disclosurePolicyId = _registerDisclosurePolicy("m417-zk-policy");

        {
            bytes32 unknownWorkflowKey = keccak256("m417-zk-unknown-workflow");
            bytes32 unknownWorkflowContextHash = proofRegistry.computeDisclosureContextHash(
                PEER_REVIEW_APP_ID,
                unknownWorkflowKey,
                AVADataTypes.AVAStage.Verification,
                AVADataTypes.Action.FileChallenge,
                objectId,
                AVADataTypes.Role.Challenger,
                disclosurePolicyId,
                subjectCommitment
            );
            _assertProofCannotRegisterForContext(
                proofRegistry,
                unknownWorkflowKey,
                AVADataTypes.Action.FileChallenge,
                objectId,
                AVADataTypes.Role.Challenger,
                disclosurePolicyId,
                subjectCommitment,
                _makeSchnorrProof(unknownWorkflowContextHash, 7, 11),
                "proof accepted unknown workflow"
            );
        }

        _ensureWorkflowPackage(workflowKey);
        {
            uint256 unknownDisclosurePolicyId = disclosurePolicyId + 1000;
            bytes32 unknownPolicyContextHash = proofRegistry.computeDisclosureContextHash(
                PEER_REVIEW_APP_ID,
                workflowKey,
                AVADataTypes.AVAStage.Verification,
                AVADataTypes.Action.FileChallenge,
                objectId,
                AVADataTypes.Role.Challenger,
                unknownDisclosurePolicyId,
                subjectCommitment
            );
            _assertProofCannotRegisterForContext(
                proofRegistry,
                workflowKey,
                AVADataTypes.Action.FileChallenge,
                objectId,
                AVADataTypes.Role.Challenger,
                unknownDisclosurePolicyId,
                subjectCommitment,
                _makeSchnorrProof(unknownPolicyContextHash, 7, 11),
                "proof accepted unknown disclosure policy"
            );
        }

        bytes32 contextHash = proofRegistry.computeDisclosureContextHash(
            PEER_REVIEW_APP_ID,
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment
        );
        uint256 receiptId = proofRegistry.registerProof(
            PEER_REVIEW_APP_ID,
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment,
            _makeSchnorrProof(contextHash, 7, 11)
        );
        ZKProofRegistry.ProofReceipt memory receipt = proofRegistry.getProofReceipt(receiptId);
        require(receipt.contextHash == contextHash, "valid proof not recorded");
        require(receipt.packageId == rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).packageId, "valid proof package missing");

        _assertProofCannotRegisterForContext(
            proofRegistry,
            workflowKey,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment,
            _makeSchnorrProof(contextHash, 7, 13),
            "proof replay accepted"
        );
    }

    function testM484ZKBackedDisclosureModuleRequiresMatchingSubjectProofReceipt() public {
        uint256 zkPolicyId = _registerDisclosurePolicy("m482-zk-policy");
        SchnorrDisclosureProofVerifier verifier = new SchnorrDisclosureProofVerifier();
        ZKProofRegistry proofRegistry = _newZkProofRegistry(verifier);
        ZKBackedDisclosureModule zkModule = new ZKBackedDisclosureModule(disclosureRegistry, proofRegistry, zkPolicyId);
        bytes32 workflowKey = keccak256("m482-zk-module-workflow");
        _ensureWorkflowPackage(workflowKey);
        bytes32 objectId = keccak256("m482-zk-object");
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        bytes32 otherSubjectCommitment = _subjectCommitmentForSecret(9);

        try zkModule.validateDisclosureForAction(
            zkPolicyId,
            AVADataTypes.Role.Challenger,
            AVADataTypes.Action.FileChallenge,
            AVADataTypes.AVAStage.Verification,
            objectId,
            workflowKey,
            rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).packageId,
            subjectCommitment
        ) {
            revert("zk module accepted missing proof");
        } catch {}

        _registerZkDisclosureProof(
            proofRegistry,
            workflowKey,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            zkPolicyId,
            subjectCommitment
        );

        zkModule.validateDisclosureForAction(
            zkPolicyId,
            AVADataTypes.Role.Challenger,
            AVADataTypes.Action.FileChallenge,
            AVADataTypes.AVAStage.Verification,
            objectId,
            workflowKey,
            rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).packageId,
            subjectCommitment
        );

        try zkModule.validateDisclosureForAction(
            zkPolicyId,
            AVADataTypes.Role.Challenger,
            AVADataTypes.Action.FileChallenge,
            AVADataTypes.AVAStage.Verification,
            objectId,
            workflowKey,
            rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).packageId,
            otherSubjectCommitment
        ) {
            revert("subject A proof satisfied subject B");
        } catch {}
    }
}
contract AVASkeletonChallengeDisclosure05BTest is AVASkeletonFixture {
    function testM426ZKBackedDisclosureModuleRejectsNewPackageProofForOldPackageValidation() public {
        uint256 zkPolicyId = _registerDisclosurePolicy("m426-zk-module-package-policy");
        ZKProofRegistry proofRegistry = _newZkProofRegistry(new SchnorrDisclosureProofVerifier());
        ZKBackedDisclosureModule zkModule = new ZKBackedDisclosureModule(disclosureRegistry, proofRegistry, zkPolicyId);
        bytes32 workflowKey = keccak256("m426-zk-module-package-workflow");
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);

        _registerRulePackage(workflowKey, zkModule, allocationAdapter, consequenceAdapter, "ipfs://m426-zk-module-v1");
        uint256 oldPackageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).packageId;
        bytes32 oldObjectId = keccak256("m426-zk-module-old-object");
        _registerZkDisclosureProof(
            proofRegistry,
            workflowKey,
            AVADataTypes.Action.FileChallenge,
            oldObjectId,
            AVADataTypes.Role.Challenger,
            zkPolicyId,
            subjectCommitment
        );
        zkModule.validateDisclosureForAction(
            zkPolicyId,
            AVADataTypes.Role.Challenger,
            AVADataTypes.Action.FileChallenge,
            AVADataTypes.AVAStage.Verification,
            oldObjectId,
            workflowKey,
            oldPackageId,
            subjectCommitment
        );

        _registerRulePackage(workflowKey, zkModule, allocationAdapter, consequenceAdapter, "ipfs://m426-zk-module-v2");
        uint256 newPackageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).packageId;
        require(newPackageId != oldPackageId, "workflow package was not replaced");
        bytes32 newObjectId = keccak256("m426-zk-module-new-object");
        _registerZkDisclosureProof(
            proofRegistry,
            workflowKey,
            AVADataTypes.Action.FileChallenge,
            newObjectId,
            AVADataTypes.Role.Challenger,
            zkPolicyId,
            subjectCommitment
        );

        try zkModule.validateDisclosureForAction(
            zkPolicyId,
            AVADataTypes.Role.Challenger,
            AVADataTypes.Action.FileChallenge,
            AVADataTypes.AVAStage.Verification,
            newObjectId,
            workflowKey,
            oldPackageId,
            subjectCommitment
        ) {
            revert("new package proof satisfied old package disclosure validation");
        } catch {}
        zkModule.validateDisclosureForAction(
            zkPolicyId,
            AVADataTypes.Role.Challenger,
            AVADataTypes.Action.FileChallenge,
            AVADataTypes.AVAStage.Verification,
            newObjectId,
            workflowKey,
            newPackageId,
            subjectCommitment
        );
    }

    function testM485ZKBackedModuleRejectsZeroAndNonZKPolicies() public {
        uint256 zkPolicyId = _registerDisclosurePolicy("m485-zk-policy");
        uint256 nonZkPolicyId = _registerDisclosurePolicy("m485-non-zk-policy");
        ZKProofRegistry proofRegistry = _newZkProofRegistry(new SchnorrDisclosureProofVerifier());
        ZKBackedDisclosureModule zkModule = new ZKBackedDisclosureModule(disclosureRegistry, proofRegistry, zkPolicyId);
        bytes32 workflowKey = keccak256("m485-zk-policy-workflow");
        _ensureWorkflowPackage(workflowKey);
        bytes32 objectId = keccak256("m485-zk-policy-object");
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);

        try zkModule.validateDisclosureForAction(
            0,
            AVADataTypes.Role.Challenger,
            AVADataTypes.Action.FileChallenge,
            AVADataTypes.AVAStage.Verification,
            objectId,
            workflowKey,
            rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).packageId,
            subjectCommitment
        ) {
            revert("zk module accepted zero policy");
        } catch {}

        try zkModule.validateDisclosureForAction(
            nonZkPolicyId,
            AVADataTypes.Role.Challenger,
            AVADataTypes.Action.FileChallenge,
            AVADataTypes.AVAStage.Verification,
            objectId,
            workflowKey,
            rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).packageId,
            subjectCommitment
        ) {
            revert("zk module accepted non-zk policy");
        } catch {}

        _registerZkDisclosureProof(
            proofRegistry,
            workflowKey,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            zkPolicyId,
            subjectCommitment
        );
        zkModule.validateDisclosureForAction(
            zkPolicyId,
            AVADataTypes.Role.Challenger,
            AVADataTypes.Action.FileChallenge,
            AVADataTypes.AVAStage.Verification,
            objectId,
            workflowKey,
            rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).packageId,
            subjectCommitment
        );
    }

    function testM485AnonymousChallengeCannotBypassZKPolicyWithZeroPolicy() public {
        _assertAnonymousZkChallengePolicyRejected(0, "m485-zero", "zk-backed challenge accepted zero policy");
    }
}

contract AVASkeletonChallengeDisclosure06ATest is AVASkeletonFixture {
    function testM485AnonymousChallengeCannotBypassZKPolicyWithNonZKPolicy() public {
        uint256 nonZkPolicyId = _registerDisclosurePolicy("m485-anonymous-non-zk-policy");
        _assertAnonymousZkChallengePolicyRejected(
            nonZkPolicyId, "m485-non-zk", "zk-backed challenge accepted non-zk policy"
        );
    }

    function testM484AnonymousChallengeWorkflowUsesSubjectBoundZKBackedModuleWithoutRevealSelectors() public {
        (uint256 challengeId, ZKBackedDisclosureModule zkModule, ZKProofRegistry proofRegistry) =
            _fileSubjectBoundZkChallenge();

        require(
            challengeWorkflow.getChallenge(challengeId).status == AVADataTypes.ChallengeLifecycleStatus.ConcernFiled,
            "zk challenge filing failed"
        );
        _assertNoSelector(address(zkModule), "revealIdentity(uint256)");
        _assertNoSelector(address(zkModule), "decryptEvidence(uint256)");
        _assertNoSelector(address(proofRegistry), "validateScientificTruth(uint256)");
        _assertNoSelector(address(proofRegistry), "acceptManuscript(uint256)");
    }
}
