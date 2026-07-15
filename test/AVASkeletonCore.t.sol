// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./helpers/AVASkeletonFixture.sol";

contract AVASkeletonCore01ATest is AVASkeletonFixture {
    function testSkeletonContractsDeploy() public {
        require(address(roleRegistry) != address(0), "role registry missing");
        require(address(authorityMatrix) != address(0), "authority matrix missing");
        require(address(evidenceRegistry) != address(0), "evidence registry missing");
        require(address(disclosureRegistry) != address(0), "disclosure registry missing");
        require(address(stateMachine) != address(0), "state machine missing");
        require(address(consequenceExecutor) != address(0), "consequence executor missing");
        require(address(standingRegistry) != address(0), "standing registry missing");
        require(address(standingFormulaRegistry) != address(0), "standing formula registry missing");
        require(address(allocationExecutor) != address(0), "allocation executor missing");
        require(address(auditModule) != address(0), "audit module missing");
        require(address(zkStandingComputationRegistry) != address(0), "zk standing registry missing");
        require(address(zkStandingCredentialRegistry) != address(0), "zk standing credential registry missing");
    }

    function testRulePackageRegisteredEventEmitsExpectedModulesHash() public {
        bytes32 workflowKey = keccak256("event-modules-hash-workflow");
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
            rulePackageLifecycleModule: rulePackageLifecycleModule,
            evidenceLifecycleModule: evidenceLifecycleModule,
            disclosureLifecycleModule: disclosureLifecycleModule,
            disclosureExecutionModule: disclosureExecutionModule,
            version: 1,
            compatibilityKey: keccak256("ava-m4-10-compatible"),
            dependencyURI: "",
            deprecated: false
        });
        bytes32 addressOnlyHash = keccak256(abi.encode(modules));
        bytes32 expectedModulesHash = rulePackageRegistry.hashModules(modules);
        bytes32 expectedModulesIdentityHash = rulePackageRegistry.hashModuleIdentities(modules);
        require(expectedModulesHash != addressOnlyHash, "modules hash is address-only");

        vm.recordLogs();
        rulePackageRegistry.registerRulePackage(AVADataTypes.Role.Panel, PEER_REVIEW_APP_ID, workflowKey, modules, "ipfs://event-workflow");
        AVARulePackageRegistry.RulePackage memory registeredPackage = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 eventTopic = keccak256("RulePackageRegistered(bytes32,bytes32,bytes32,string,address)");
        bytes32 authorityEventTopic =
            keccak256("RulePackageAuthorityBound(bytes32,bytes32,uint256,bytes32,address)");
        bool found;
        bool foundAuthority;
        for (uint256 i = 0; i < entries.length; i++) {
            if (
                entries[i].emitter == address(rulePackageRegistry) && entries[i].topics.length == 3
                    && entries[i].topics[0] == eventTopic && entries[i].topics[1] == PEER_REVIEW_APP_ID
                    && entries[i].topics[2] == workflowKey
            ) {
                (bytes32 modulesHash, string memory uri, address registeredBy) =
                    abi.decode(entries[i].data, (bytes32, string, address));
                require(modulesHash == expectedModulesHash, "wrong modules hash");
                require(keccak256(bytes(uri)) == keccak256("ipfs://event-workflow"), "wrong uri");
                require(registeredBy == address(this), "wrong registeredBy");
                found = true;
            }
            if (
                entries[i].emitter == address(rulePackageRegistry) && entries[i].topics.length == 4
                    && entries[i].topics[0] == authorityEventTopic && entries[i].topics[1] == PEER_REVIEW_APP_ID
                    && entries[i].topics[2] == workflowKey
                    && uint256(entries[i].topics[3]) == registeredPackage.packageId
            ) {
                (bytes32 authorityId, address registeredBy) = abi.decode(entries[i].data, (bytes32, address));
                require(authorityId == keccak256("panel-authority"), "wrong authority id");
                require(registeredBy == address(this), "wrong authority registeredBy");
                foundAuthority = true;
            }
        }
        require(found, "RulePackageRegistered event missing");
        require(foundAuthority, "RulePackageAuthorityBound event missing");
        require(registeredPackage.modulesHash == expectedModulesHash, "stored modules hash wrong");
        require(registeredPackage.modulesIdentityHash == expectedModulesIdentityHash, "stored modules code hash wrong");
        require(registeredPackage.authorityId == keccak256("panel-authority"), "rule package authority missing");
    }

    function testRulePackageRegistrationRejectsNoCodeModuleAddress() public {
        bytes32 workflowKey = keccak256("event-no-code-module-workflow");
        AVARulePackageRegistry.RulePackageModules memory modules = _defaultRulePackageModules();
        modules.attributionModule = IAttributionModule(address(0x1234));

        try rulePackageRegistry.registerRulePackage(
            AVADataTypes.Role.Panel, PEER_REVIEW_APP_ID, workflowKey, modules, "ipfs://no-code-module"
        ) {
            revert("rule package accepted no-code module");
        } catch {}
    }
}

contract AVASkeletonCore01BTest is AVASkeletonFixture {
    function testRulePackageIdentityFailsClosedWhenBehaviorConfigurationChanges() public {
        bytes32 workflowKey = keccak256("mutable-module-identity-workflow");
        MutableIdentityAntiAbuseModule mutableModule =
            new MutableIdentityAntiAbuseModule(AVADataTypes.Action.FileChallenge);
        AVARulePackageRegistry.RulePackageModules memory modules = _defaultRulePackageModules();
        modules.antiAbuseModule = mutableModule;

        uint256 packageId = rulePackageRegistry.registerRulePackage(
            AVADataTypes.Role.Panel, PEER_REVIEW_APP_ID, workflowKey, modules, "ipfs://mutable-module-v1"
        );
        rulePackageRegistry.getRulePackageById(packageId);

        mutableModule.setBlockedAction(AVADataTypes.Action.ResolveChallenge);
        try rulePackageRegistry.getRulePackageById(packageId) {
            revert("changed module behavior retained historical package validity");
        } catch {}
    }

    function testRulePackageSupersessionIsExplicitVersionedAndAppendOnly() public {
        bytes32 workflowKey = keccak256("explicit-package-supersession-workflow");
        AVARulePackageRegistry.RulePackageModules memory modules = _defaultRulePackageModules();
        uint256 firstPackageId = rulePackageRegistry.registerRulePackage(
            AVADataTypes.Role.Panel, PEER_REVIEW_APP_ID, workflowKey, modules, "ipfs://explicit-package-v1"
        );

        try rulePackageRegistry.registerRulePackage(
            AVADataTypes.Role.Panel, PEER_REVIEW_APP_ID, workflowKey, modules, "ipfs://implicit-overwrite"
        ) {
            revert("initial registration overwrote active package");
        } catch {}
        try rulePackageRegistry.supersedeRulePackage(
            AVADataTypes.Role.Panel, PEER_REVIEW_APP_ID, workflowKey, firstPackageId, modules, "ipfs://same-version"
        ) {
            revert("supersession accepted non-increasing version");
        } catch {}

        modules.version = 2;
        try rulePackageRegistry.supersedeRulePackage(
            AVADataTypes.Role.Panel, PEER_REVIEW_APP_ID, workflowKey, firstPackageId + 1, modules, "ipfs://wrong-incumbent"
        ) {
            revert("supersession accepted stale incumbent package id");
        } catch {}
        uint256 secondPackageId = rulePackageRegistry.supersedeRulePackage(
            AVADataTypes.Role.Panel, PEER_REVIEW_APP_ID, workflowKey, firstPackageId, modules, "ipfs://explicit-package-v2"
        );

        require(rulePackageRegistry.getActivePackageId(PEER_REVIEW_APP_ID, workflowKey) == secondPackageId, "active pointer not advanced");
        require(rulePackageRegistry.getRulePackageById(firstPackageId).version == 1, "historical package changed");
        require(rulePackageRegistry.getRulePackageById(secondPackageId).version == 2, "new package version missing");
        uint256 supersessionId = rulePackageRegistry.nextSupersessionRecordId() - 1;
        AVADataTypes.RulePackageSupersessionRecord memory record =
            rulePackageRegistry.getRulePackageSupersessionRecord(supersessionId);
        require(record.previousPackageId == firstPackageId, "supersession source missing");
        require(record.newPackageId == secondPackageId, "supersession target missing");
        require(record.previousVersion == 1 && record.newVersion == 2, "supersession versions missing");
    }

    function testAdminCanAssignRoleScopedSubject() public {
        AVADataTypes.RoleSubject memory subject = roleRegistry.getSubject(REVIEWER_SUBJECT);

        require(subject.account == address(reviewerActor), "wrong account");
        require(subject.role == AVADataTypes.Role.Reviewer, "wrong role");
        require(subject.active, "subject inactive");
        require(roleRegistry.hasRole(address(reviewerActor), AVADataTypes.Role.Reviewer), "role not assigned");
    }
}

contract AVASkeletonCore02ATest is AVASkeletonFixture {
    function testNonAdminCannotAssignRolesOrConfigureAuthority() public {
        try outsiderActor.assignRole(
            roleRegistry, address(outsiderActor), AVADataTypes.Role.Author, keccak256("bad-subject"), "ipfs://bad"
        ) {
            revert("non-admin assigned role");
        } catch {}

        try outsiderActor.setPermission(
            authorityMatrix, AVADataTypes.Role.Reviewer, AVADataTypes.Action.RegisterConsequence, true
        ) {
            revert("non-admin configured authority");
        } catch {}
    }

    function testAuthorisedRoleCanRegisterCoreObjects() public {
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("sealed-review-evidence"),
            "ipfs://encrypted-review",
            "review-service-occurrence",
            0
        );

        AVADataTypes.EvidenceReceipt memory receipt = evidenceRegistry.getEvidenceReceipt(evidenceId);
        require(receipt.commitment == keccak256("sealed-review-evidence"), "wrong evidence commitment");
        require(
            receipt.packageId == rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW).packageId,
            "wrong evidence package"
        );
        require(receipt.registeredRole == AVADataTypes.Role.Reviewer, "wrong evidence role");
        require(receipt.registeredSubjectId == REVIEWER_SUBJECT, "wrong evidence subject");
        require(receipt.registeredBy == address(reviewerActor), "wrong evidence actor");
        uint256 policyId = disclosureRegistry.registerDisclosurePolicy(
            AVADataTypes.Role.Editor, PEER_REVIEW_APP_ID, "editor-visible-sealed-content", "ipfs://policy"
        );
        AVADataTypes.DisclosurePolicy memory policy = disclosureRegistry.getDisclosurePolicy(policyId);
        require(policy.authorityRole == AVADataTypes.Role.Editor, "wrong disclosure authority role");
        require(policy.authorityId == EDITOR_AUTHORITY, "wrong disclosure authority subject");
        uint256 manuscriptId = _registerAuthorManuscript();
        AVADataTypes.ManuscriptRecord memory manuscript = stateMachine.getManuscript(manuscriptId);
        require(manuscript.registeredRole == AVADataTypes.Role.Author, "wrong manuscript role");
        require(manuscript.registeredSubjectId == keccak256("author-subject"), "wrong manuscript subject");

        uint256 stateId = stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Attribution,
            bytes32(manuscriptId),
            manuscript.registeredSubjectId,
            evidenceId,
            policyId,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        );

        AVADataTypes.RecognisedStateRecord memory state = stateMachine.getRecognisedState(stateId);
        require(state.stage == AVADataTypes.AVAStage.Attribution, "wrong AVA stage");
        require(state.subjectId == manuscript.registeredSubjectId, "wrong recognised-state subject");
        require(state.status == AVADataTypes.RecognisedStateStatus.Registered, "wrong state status");
    }

    function testZeroDisclosurePolicyRemainsAcceptedWhereUnspecified() public {
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("zero-policy-evidence"),
            "ipfs://zero-policy-evidence",
            "review-service-occurrence",
            0
        );
        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 reviewContributionId = reviewerActor.registerReviewContribution(
            stateMachine, AVADataTypes.Role.Reviewer, manuscriptId, REVIEWER_SUBJECT, evidenceId, 0
        );
        uint256 recognisedStateId = stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            keccak256("zero-policy-state"),
            REVIEWER_SUBJECT,
            evidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        );

        AVADataTypes.EvidenceReceipt memory receipt = evidenceRegistry.getEvidenceReceipt(evidenceId);
        AVADataTypes.ReviewContributionRecord memory review = stateMachine.getReviewContribution(reviewContributionId);
        AVADataTypes.RecognisedStateRecord memory state = stateMachine.getRecognisedState(recognisedStateId);
        require(receipt.disclosurePolicyId == 0, "zero evidence policy changed");
        require(review.disclosurePolicyId == 0, "zero review policy changed");
        require(state.disclosurePolicyId == 0, "zero state policy changed");
        require(state.subjectId == REVIEWER_SUBJECT, "zero policy state lost subject");
    }
}

contract AVASkeletonCore02BTest is AVASkeletonFixture {
    function testReviewContributionRejectsUnknownManuscriptId() public {
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("unknown-manuscript-review-evidence"),
            "ipfs://unknown-manuscript-review-evidence",
            "review-service-occurrence",
            0
        );
        uint256 unknownManuscriptId = stateMachine.nextManuscriptId() + 100;
        uint256 nextReviewContributionId = stateMachine.nextReviewContributionId();

        try reviewerActor.registerReviewContribution(
            stateMachine, AVADataTypes.Role.Reviewer, unknownManuscriptId, REVIEWER_SUBJECT, evidenceId, 0
        ) {
            revert("review accepted unknown manuscript");
        } catch {}

        require(
            stateMachine.nextReviewContributionId() == nextReviewContributionId, "unknown manuscript created review"
        );
    }

    function testEvidenceReceiptRejectsEmptyEvidenceType() public {
        uint256 nextEvidenceId = evidenceRegistry.nextEvidenceReceiptId();

        try reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("empty-evidence-type"),
            "ipfs://empty-evidence-type",
            "",
            0
        ) {
            revert("evidence accepted empty type");
        } catch {}

        require(evidenceRegistry.nextEvidenceReceiptId() == nextEvidenceId, "empty type created evidence");
    }

    function testUnknownDisclosurePolicyReferencesAreRejectedWhereSupplied() public {
        uint256 unknownPolicyId = disclosureRegistry.nextDisclosurePolicyId() + 100;
        uint256 nextEvidenceId = evidenceRegistry.nextEvidenceReceiptId();

        try reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("unknown-policy-evidence"),
            "ipfs://unknown-policy-evidence",
            "review-service-occurrence",
            unknownPolicyId
        ) {
            revert("evidence accepted unknown disclosure policy");
        } catch {}
        require(evidenceRegistry.nextEvidenceReceiptId() == nextEvidenceId, "unknown policy created evidence");

        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("known-zero-policy-evidence"),
            "ipfs://known-zero-policy-evidence",
            "review-service-occurrence",
            0
        );
        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 nextReviewContributionId = stateMachine.nextReviewContributionId();

        try reviewerActor.registerReviewContribution(
            stateMachine, AVADataTypes.Role.Reviewer, manuscriptId, REVIEWER_SUBJECT, evidenceId, unknownPolicyId
        ) {
            revert("review accepted unknown disclosure policy");
        } catch {}
        require(stateMachine.nextReviewContributionId() == nextReviewContributionId, "unknown policy created review");

        uint256 nextRecognisedStateId = stateMachine.nextRecognisedStateId();

        try stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            keccak256("unknown-policy-state"),
            REVIEWER_SUBJECT,
            evidenceId,
            unknownPolicyId,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        ) {
            revert("recognised state accepted unknown disclosure policy");
        } catch {}
        require(stateMachine.nextRecognisedStateId() == nextRecognisedStateId, "unknown policy created state");

        uint256 challengeableStateId = _createChallengeableReviewState();
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256("unknown-policy-challenge-evidence"),
            "ipfs://unknown-policy-challenge-evidence",
            "review-quality-challenge",
            0
        );
        uint256 nextChallengeId = challengeWorkflow.nextChallengeId();

        try challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            challengeableStateId,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            unknownPolicyId
        ) {
            revert("challenge accepted unknown disclosure policy");
        } catch {}

        require(challengeWorkflow.nextChallengeId() == nextChallengeId, "unknown policy created challenge");
    }
}

contract AVASkeletonCore03ATest is AVASkeletonFixture {
    function testAlternativeDisclosureModuleCanBeSwappedWithoutChangingRecognisedStateSubstrate() public {
        uint256 blockedPolicyId = disclosureRegistry.registerDisclosurePolicy(
            AVADataTypes.Role.Editor, PEER_REVIEW_APP_ID, "blocked-by-module", "ipfs://blocked-policy"
        );
        MockDisclosurePolicyModule mockDisclosureModule = new MockDisclosurePolicyModule(blockedPolicyId);
        AVARulePackageRegistry swappedRulePackageRegistry =
            new AVARulePackageRegistry(authorityMatrix, applicationRegistry, new RulePackageIdentityVerifier());
        swappedRulePackageRegistry.registerRulePackage(
            AVADataTypes.Role.Panel,
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            AVARulePackageRegistry.RulePackageModules({
                applicationModule: applicationModule,
                attributionModule: attributionModule,
                verificationModule: verificationModule,
                allocationModule: allocationAdapter,
                transitionRuleModule: transitionRuleModule,
                disclosureModule: mockDisclosureModule,
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
                rulePackageLifecycleModule: rulePackageLifecycleModule,
                evidenceLifecycleModule: evidenceLifecycleModule,
                disclosureLifecycleModule: disclosureLifecycleModule,
                disclosureExecutionModule: disclosureExecutionModule,
                version: 1,
                compatibilityKey: keccak256("ava-m4-10-compatible"),
                dependencyURI: "",
                deprecated: false
            }),
            "ipfs://swapped-disclosure-workflow"
        );
        EvidenceCommitmentRegistry swappedEvidenceRegistry =
            new EvidenceCommitmentRegistry(
                authorityMatrix, mockDisclosureModule, disclosureRegistry, swappedRulePackageRegistry
            );
        AVAWorkflowValidator swappedWorkflowValidator =
            new AVAWorkflowValidator(swappedRulePackageRegistry, swappedEvidenceRegistry, disclosureRegistry);
        AVAStateMachine swappedStateMachine = new AVAStateMachine(
            authorityMatrix, swappedRulePackageRegistry, swappedWorkflowValidator, standingRevisionRegistry, 1 days
        );

        try reviewerActor.registerEvidenceReceipt(
            swappedEvidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("blocked-policy-evidence"),
            "ipfs://blocked-policy-evidence",
            "review-service-occurrence",
            blockedPolicyId
        ) {
            revert("mock disclosure module did not block evidence");
        } catch {}

        uint256 allowedEvidenceId = reviewerActor.registerEvidenceReceipt(
            swappedEvidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("allowed-policy-evidence"),
            "ipfs://allowed-policy-evidence",
            "review-service-occurrence",
            0
        );
        uint256 manuscriptId = swappedStateMachine.registerManuscript(
            AVADataTypes.Role.Author,
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            keccak256("swapped-manuscript"),
            "ipfs://m",
            ""
        );
        uint256 reviewContributionId = reviewerActor.registerReviewContribution(
            swappedStateMachine, AVADataTypes.Role.Reviewer, manuscriptId, REVIEWER_SUBJECT, allowedEvidenceId, 0
        );

        AVADataTypes.ReviewContributionRecord memory review =
            swappedStateMachine.getReviewContribution(reviewContributionId);
        require(review.status == AVADataTypes.ReviewContributionStatus.Submitted, "swapped substrate changed");
        require(review.disclosurePolicyId == 0, "swapped disclosure policy wrong");
        require(standingRegistry.nextStandingUpdateId() == 1, "swapped disclosure created standing update");
        require(consequenceExecutor.nextConsequenceId() == 1, "swapped disclosure created consequence");
    }

    function testUnauthorisedCallerCannotRegisterGovernedObjects() public {
        try outsiderActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("outsider-evidence"),
            "ipfs://outsider",
            "challenge",
            0
        ) {
            revert("outsider registered evidence");
        } catch {}

        try outsiderActor.registerManuscript(
            stateMachine, AVADataTypes.Role.Author, keccak256("outsider-manuscript"), "ipfs://outsider-manuscript"
        ) {
            revert("outsider registered manuscript");
        } catch {}
    }

    function testRawReviewAndChallengeDoNotCreateStandingRewardOrSanction() public {
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("raw-review-receipt"),
            "ipfs://raw-review",
            "raw-review-submission",
            0
        );

        require(evidenceId == 1, "raw review receipt not registered");
        require(standingRegistry.nextStandingUpdateId() == 1, "standing update was created from raw review");
        require(consequenceExecutor.nextConsequenceId() == 1, "consequence was created from raw review");

        roleRegistry.assignRole(
            address(this), AVADataTypes.Role.Challenger, keccak256("local-challenger"), "ipfs://local"
        );
        authorityMatrix.setPermission(AVADataTypes.Role.Challenger, AVADataTypes.Action.RegisterEvidence, true);
        uint256 challengeReceiptId = evidenceRegistry.registerEvidenceReceipt(
            AVADataTypes.Role.Challenger, keccak256("raw-challenge-receipt"), "ipfs://raw-challenge", "raw-challenge", 0
        );

        require(challengeReceiptId == 2, "raw challenge receipt not registered");
        require(standingRegistry.nextStandingUpdateId() == 1, "standing update was created from raw challenge");
        require(consequenceExecutor.nextConsequenceId() == 1, "sanction or reward was created from raw challenge");
    }
}

contract AVASkeletonCore03BTest is AVASkeletonFixture {
    function testReviewReceiptCanBecomeChallengeableRecognisedStateWithoutStandingOrReward() public {
        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 disclosurePolicyId = disclosureRegistry.registerDisclosurePolicy(
            AVADataTypes.Role.Editor, PEER_REVIEW_APP_ID, "editor-visible-sealed-review", "ipfs://review-policy"
        );
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("sealed-review-bundle"),
            "ipfs://encrypted-review-bundle",
            "review-service-occurrence",
            disclosurePolicyId
        );

        uint256 reviewContributionId = reviewerActor.registerReviewContribution(
            stateMachine, AVADataTypes.Role.Reviewer, manuscriptId, REVIEWER_SUBJECT, evidenceId, disclosurePolicyId
        );
        AVADataTypes.ReviewContributionRecord memory submittedReview =
            stateMachine.getReviewContribution(reviewContributionId);
        require(submittedReview.status == AVADataTypes.ReviewContributionStatus.Submitted, "review not submitted");
        require(submittedReview.recognisedStateId == 0, "raw review created recognised state");
        require(standingRegistry.nextStandingUpdateId() == 1, "raw review created standing update");
        require(consequenceExecutor.nextConsequenceId() == 1, "raw review created consequence");

        uint256 recognisedStateId =
            stateMachine.provisionallyRecogniseReview(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);
        AVADataTypes.RecognisedStateRecord memory provisionalState = stateMachine.getRecognisedState(recognisedStateId);
        require(
            provisionalState.stage == AVADataTypes.AVAStage.Verification, "review recognition bypassed verification"
        );
        require(
            provisionalState.status == AVADataTypes.RecognisedStateStatus.Provisional, "review state not provisional"
        );
        require(provisionalState.subjectId == REVIEWER_SUBJECT, "review state lost reviewer subject");

        stateMachine.openReviewChallengeWindow(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);
        AVADataTypes.ReviewContributionRecord memory challengeableReview =
            stateMachine.getReviewContribution(reviewContributionId);
        AVADataTypes.RecognisedStateRecord memory challengeableState =
            stateMachine.getRecognisedState(recognisedStateId);
        require(
            challengeableReview.status == AVADataTypes.ReviewContributionStatus.ChallengeWindowOpen,
            "review challenge window not open"
        );
        require(
            challengeableState.status == AVADataTypes.RecognisedStateStatus.Challengeable,
            "recognised state not challengeable"
        );
        require(challengeableState.subjectId == REVIEWER_SUBJECT, "challenge window rewrote reviewer subject");
        require(standingRegistry.nextStandingUpdateId() == 1, "challengeable state created standing update");
        require(consequenceExecutor.nextConsequenceId() == 1, "challengeable state created consequence");
    }

    function testReviewerCannotProvisionallyRecogniseOwnReview() public {
        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("self-review-bundle"),
            "ipfs://self-review",
            "review-service-occurrence",
            0
        );
        uint256 reviewContributionId = reviewerActor.registerReviewContribution(
            stateMachine, AVADataTypes.Role.Reviewer, manuscriptId, REVIEWER_SUBJECT, evidenceId, 0
        );

        try reviewerActor.provisionallyRecogniseReview(
            stateMachine, AVADataTypes.Role.Reviewer, reviewContributionId, EDITOR_AUTHORITY
        ) {
            revert("reviewer recognised own review");
        } catch {}
    }

    function testChallengeCorrectionAndRestorationPathKeepsConsequencesBounded() public {
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256("sealed-challenge-evidence"),
            "ipfs://sealed-challenge",
            "review-quality-challenge",
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
        AVADataTypes.ChallengeRecord memory filedChallenge = challengeWorkflow.getChallenge(challengeId);
        require(filedChallenge.status == AVADataTypes.ChallengeLifecycleStatus.ConcernFiled, "challenge not filed");
        require(filedChallenge.outcome == AVADataTypes.ChallengeOutcome.None, "raw challenge has outcome");
        require(filedChallenge.lastTransitionId == 0, "raw challenge created transition");
        require(consequenceExecutor.nextConsequenceId() == 1, "raw challenge created sanction");
        AVADataTypes.RecognisedStateRecord memory unchangedState = stateMachine.getRecognisedState(recognisedStateId);
        require(
            unchangedState.status == AVADataTypes.RecognisedStateStatus.Challengeable, "raw challenge mutated state"
        );

        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        AVADataTypes.ChallengeRecord memory screenedChallenge = challengeWorkflow.getChallenge(challengeId);
        AVADataTypes.ChallengeTransitionRecord memory screenTransition =
            challengeWorkflow.getChallengeTransition(screenedChallenge.lastTransitionId);
        require(
            screenedChallenge.status == AVADataTypes.ChallengeLifecycleStatus.AdmissibilityScreening,
            "challenge not screened"
        );
        require(
            screenTransition.transitionKind == AVADataTypes.ChallengeTransitionKind.AdmissibilityScreened,
            "screen transition missing"
        );
        require(screenTransition.createdAt == block.timestamp, "screen transition timestamp missing");
        require(
            screenTransition.fromStatus == AVADataTypes.RecognisedStateStatus.Challengeable, "screen from state wrong"
        );
        require(screenTransition.toStatus == AVADataTypes.RecognisedStateStatus.Challengeable, "screen mutated state");

        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            keccak256("panel-authority"),
            "ipfs://upheld-reason"
        );

        AVADataTypes.ChallengeRecord memory upheldChallenge = challengeWorkflow.getChallenge(challengeId);
        AVADataTypes.RecognisedStateRecord memory correctedState = stateMachine.getRecognisedState(recognisedStateId);
        AVADataTypes.ChallengeTransitionRecord memory resolveTransition =
            challengeWorkflow.getChallengeTransition(upheldChallenge.lastTransitionId);
        require(upheldChallenge.status == AVADataTypes.ChallengeLifecycleStatus.Resolved, "challenge not resolved");
        require(upheldChallenge.outcome == AVADataTypes.ChallengeOutcome.Upheld, "challenge not upheld");
        require(
            resolveTransition.transitionKind == AVADataTypes.ChallengeTransitionKind.OutcomeResolved,
            "resolve transition missing"
        );
        require(resolveTransition.outcome == AVADataTypes.ChallengeOutcome.Upheld, "transition outcome wrong");
        require(resolveTransition.fromStatus == AVADataTypes.RecognisedStateStatus.Challengeable, "resolve from wrong");
        require(resolveTransition.toStatus == AVADataTypes.RecognisedStateStatus.Downgraded, "resolve to wrong");
        require(resolveTransition.createdAt == block.timestamp, "resolve transition timestamp missing");
        require(correctedState.status == AVADataTypes.RecognisedStateStatus.Downgraded, "state not corrected");
        require(consequenceExecutor.nextConsequenceId() == 1, "upheld challenge auto-executed consequence");
        require(standingRegistry.nextStandingUpdateId() == 1, "upheld challenge auto-created standing update");
    }
}

contract AVASkeletonCore04ATest is AVASkeletonFixture {
    function testGoodFaithRejectedChallengeCanRestoreTargetWithoutSanction() public {
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256("good-faith-challenge-evidence"),
            "ipfs://good-faith",
            "review-quality-challenge",
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
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://good-faith-rejection"
        );
        AVADataTypes.ChallengeRecord memory resolvedChallenge = challengeWorkflow.getChallenge(challengeId);
        require(resolvedChallenge.status == AVADataTypes.ChallengeLifecycleStatus.Resolved, "challenge not resolved");
        require(resolvedChallenge.outcome == AVADataTypes.ChallengeOutcome.RejectedGoodFaith, "wrong outcome");
        challengeWorkflow.applyRestoration(
            AVADataTypes.Role.Panel, challengeId, keccak256("panel-authority"), "ipfs://restoration-reason"
        );

        AVADataTypes.ChallengeRecord memory challenge = challengeWorkflow.getChallenge(challengeId);
        AVADataTypes.RecognisedStateRecord memory restoredState = stateMachine.getRecognisedState(recognisedStateId);
        AVADataTypes.ChallengeTransitionRecord memory restorationTransition =
            challengeWorkflow.getChallengeTransition(challenge.lastTransitionId);
        require(challenge.status == AVADataTypes.ChallengeLifecycleStatus.RestorationApplied, "restoration not applied");
        require(
            restorationTransition.transitionKind == AVADataTypes.ChallengeTransitionKind.RestorationRecorded,
            "restoration transition missing"
        );
        require(
            restoredState.status == AVADataTypes.RecognisedStateStatus.Challengeable,
            "restoration changed challengeable target status"
        );
        require(
            restorationTransition.fromStatus == AVADataTypes.RecognisedStateStatus.Challengeable
                && restorationTransition.toStatus == AVADataTypes.RecognisedStateStatus.Challengeable,
            "restoration did not preserve challengeable target"
        );
        require(consequenceExecutor.nextConsequenceId() == 1, "good-faith rejection created sanction");
    }

    function testChallengeResolutionCannotDirectlyRestoreWithoutRestorationTransition() public {
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256("direct-restore-challenge-evidence"),
            "ipfs://direct-restore",
            "review-quality-challenge",
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

        uint256 nextChallengeTransitionId = challengeWorkflow.nextChallengeTransitionId();
        uint256 nextRecognisedStateTransitionId = stateMachine.nextRecognisedStateTransitionId();
        try challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Restored,
            keccak256("panel-authority"),
            "ipfs://direct-restore-resolution"
        ) {
            revert("challenge resolution directly restored state");
        } catch {}

        require(
            stateMachine.getRecognisedState(recognisedStateId).status
                == AVADataTypes.RecognisedStateStatus.Challengeable,
            "failed direct restoration mutated state"
        );
        require(
            challengeWorkflow.nextChallengeTransitionId() == nextChallengeTransitionId,
            "failed direct restoration wrote challenge transition"
        );
        require(
            stateMachine.nextRecognisedStateTransitionId() == nextRecognisedStateTransitionId,
            "failed direct restoration wrote state transition"
        );
    }

    function testChallengerCannotResolveOwnChallenge() public {
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256("self-resolve-challenge"),
            "ipfs://self-resolve",
            "review-quality-challenge",
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

        try challengerActor.resolveChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            challengeId,
            AVADataTypes.ChallengeOutcome.MaliciousOrFabricated,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("challenger-authority"),
            "ipfs://bad-resolution"
        ) {
            revert("challenger resolved own challenge");
        } catch {}
        require(consequenceExecutor.nextConsequenceId() == 1, "unauthorised resolve created sanction");
    }
}

contract AVASkeletonCore04BTest is AVASkeletonFixture {
    function testResolverCannotUseCrossRolePanelSubjectAgainstOwnReviewState() public {
        uint256 recognisedStateId = _createChallengeableReviewState();
        bytes32 reviewerPanelSubject = keccak256("reviewer-cross-role-panel-subject");
        roleRegistry.assignRole(
            address(reviewerActor),
            AVADataTypes.Role.Panel,
            reviewerPanelSubject,
            "ipfs://reviewer-cross-role-panel"
        );
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256("cross-role-conflict-evidence"),
            "ipfs://cross-role-conflict-evidence",
            "review-quality-challenge",
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

        try reviewerActor.resolveChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            reviewerPanelSubject,
            "ipfs://cross-role-self-resolution"
        ) {
            revert("target account resolved its own recognised state");
        } catch {}
        require(
            stateMachine.getRecognisedState(recognisedStateId).status
                == AVADataTypes.RecognisedStateStatus.Challengeable,
            "rejected cross-role resolution mutated state"
        );
    }

    function testChallengerCannotApplyRestorationThroughOwnPanelRole() public {
        uint256 recognisedStateId = _createChallengeableReviewState();
        bytes32 challengerPanelSubject = keccak256("challenger-panel-subject");
        roleRegistry.assignRole(
            address(challengerActor),
            AVADataTypes.Role.Panel,
            challengerPanelSubject,
            "ipfs://challenger-panel"
        );
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256("challenger-restoration-evidence"),
            "ipfs://challenger-restoration-evidence",
            "review-quality-challenge",
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
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            keccak256("panel-authority"),
            "ipfs://independent-panel-resolution"
        );

        try challengerActor.applyRestoration(
            challengeWorkflow,
            AVADataTypes.Role.Panel,
            challengeId,
            challengerPanelSubject,
            "ipfs://challenger-self-restoration"
        ) {
            revert("challenger restored its own challenge outcome");
        } catch {}
        require(
            stateMachine.getRecognisedState(recognisedStateId).status
                == AVADataTypes.RecognisedStateStatus.Downgraded,
            "rejected challenger restoration mutated state"
        );
    }

    function testResolverCannotResolveChallengeAgainstOwnRecognisedStateSubject() public {
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("resolver-subject-conflict-state"),
            "ipfs://resolver-subject-conflict-state",
            "subject-conflict-state",
            0
        );
        uint256 recognisedStateId = stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            keccak256("resolver-subject-conflict-object"),
            keccak256("panel-authority"),
            evidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Challengeable
        );
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256("resolver-subject-conflict-challenge"),
            "ipfs://resolver-subject-conflict-challenge",
            "review-quality-challenge",
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
        Actor distinctEditor = new Actor();
        bytes32 distinctEditorAuthority = keccak256("resolver-conflict-distinct-editor");
        roleRegistry.assignRole(
            address(distinctEditor), AVADataTypes.Role.Editor, distinctEditorAuthority, "ipfs://distinct-editor"
        );
        distinctEditor.screenChallenge(
            challengeWorkflow, AVADataTypes.Role.Editor, challengeId, distinctEditorAuthority
        );

        try challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            keccak256("panel-authority"),
            "ipfs://resolver-subject-conflict-rejected"
        ) {
            revert("resolver resolved challenge against own state subject");
        } catch {}

        Actor distinctPanel = new Actor();
        bytes32 distinctPanelAuthority = keccak256("distinct-panel-authority");
        roleRegistry.assignRole(
            address(distinctPanel), AVADataTypes.Role.Panel, distinctPanelAuthority, "ipfs://distinct-panel"
        );
        distinctPanel.resolveChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            distinctPanelAuthority,
            "ipfs://resolver-subject-conflict-resolved"
        );
        require(
            stateMachine.getRecognisedState(recognisedStateId).status == AVADataTypes.RecognisedStateStatus.Downgraded,
            "distinct panel resolver failed"
        );
    }

    function testRawChallengeCannotTargetRawReviewSubmission() public {
        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 reviewEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("raw-review-only"),
            "ipfs://raw-review-only",
            "review-service-occurrence",
            0
        );
        uint256 reviewContributionId = reviewerActor.registerReviewContribution(
            stateMachine, AVADataTypes.Role.Reviewer, manuscriptId, REVIEWER_SUBJECT, reviewEvidenceId, 0
        );
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256("challenge-against-raw-review"),
            "ipfs://challenge-against-raw-review",
            "review-quality-challenge",
            0
        );

        try challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            reviewContributionId,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            0
        ) {
            revert("raw review was challengeable");
        } catch {}
    }

    function testEditorCanScreenButCannotResolveChallenge() public {
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256("editor-screen-evidence"),
            "ipfs://editor-screen",
            "review-quality-challenge",
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
        try challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Editor,
            challengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            EDITOR_AUTHORITY,
            "ipfs://editor-resolution"
        ) {
            revert("editor resolved challenge");
        } catch {}
    }
}

contract AVASkeletonCore05ATest is AVASkeletonFixture {
    function testChallengeOutcomesRemainDistinctWithoutAutomaticConsequences() public {
        uint256 goodFaithChallengeId = _fileAndScreenChallenge("good-faith-distinct");
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            goodFaithChallengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://good-faith"
        );

        uint256 negligentChallengeId = _fileAndScreenChallenge("negligent-distinct");
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            negligentChallengeId,
            AVADataTypes.ChallengeOutcome.Negligent,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://negligent"
        );

        uint256 maliciousChallengeId = _fileAndScreenChallenge("malicious-distinct");
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            maliciousChallengeId,
            AVADataTypes.ChallengeOutcome.MaliciousOrFabricated,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://malicious"
        );

        require(
            challengeWorkflow.getChallenge(goodFaithChallengeId).outcome
                == AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            "good faith collapsed"
        );
        require(
            challengeWorkflow.getChallenge(negligentChallengeId).outcome == AVADataTypes.ChallengeOutcome.Negligent,
            "negligent collapsed"
        );
        require(
            challengeWorkflow.getChallenge(maliciousChallengeId).outcome
                == AVADataTypes.ChallengeOutcome.MaliciousOrFabricated,
            "malicious collapsed"
        );
        require(consequenceExecutor.nextConsequenceId() == 1, "outcome auto-executed consequence");
        require(standingRegistry.nextStandingUpdateId() == 1, "outcome auto-created standing update");
    }

    function testUnauthorisedCallerCannotRestoreOrCloseChallenge() public {
        uint256 challengeId = _fileAndScreenChallenge("restore-close-auth");
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://restore-close"
        );

        try outsiderActor.applyRestoration(
            challengeWorkflow, AVADataTypes.Role.Panel, challengeId, keccak256("outsider"), "ipfs://outsider-restore"
        ) {
            revert("outsider restored challenge");
        } catch {}

        try outsiderActor.closeChallenge(
            challengeWorkflow, AVADataTypes.Role.Panel, challengeId, keccak256("outsider"), "ipfs://outsider-close"
        ) {
            revert("outsider closed challenge");
        } catch {}
    }

    function testAuthorisedPanelCanRecordProceduralStandingUpdateFromRecognisedState() public {
        (uint256 recognisedStateId, uint256 evidenceId) = _createDowngradedRecognisedState();

        uint256 standingUpdateId = standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            "review-procedure-weight",
            -1,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://standing-update"
        );

        AVADataTypes.StandingUpdateRecord memory update = standingRegistry.getStandingUpdate(standingUpdateId);
        require(update.recognisedStateId == recognisedStateId, "standing update target wrong");
        require(update.subjectId == REVIEWER_SUBJECT, "standing update subject wrong");
        require(update.delta == -1, "standing update delta wrong");
        require(update.authorityRole == AVADataTypes.Role.Panel, "standing authority role wrong");
        require(consequenceExecutor.nextConsequenceId() == 1, "standing update created consequence");
        require(allocationExecutor.nextAllocationExecutionId() == 1, "standing update executed allocation");
    }
}

contract AVASkeletonCore05BTest is AVASkeletonFixture {
    function testUnauthorisedCallerCannotRecordStandingUpdateOrExecuteAllocation() public {
        (uint256 recognisedStateId, uint256 evidenceId) = _createDowngradedRecognisedState();

        try outsiderActor.recordStandingUpdate(
            standingRegistry,
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            "review-procedure-weight",
            1,
            evidenceId,
            keccak256("outsider"),
            "ipfs://outsider-standing"
        ) {
            revert("outsider recorded standing update");
        } catch {}

        try outsiderActor.executeAllocation(
            allocationExecutor,
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            AVADataTypes.AllocationKind.OperationalAllowance,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("outsider"),
            "ipfs://outsider-allocation"
        ) {
            revert("outsider executed allocation");
        } catch {}
    }

    function testStandingAndAllocationRejectRawIdsAndProvisionalState() public {
        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("standing-raw-review"),
            "ipfs://standing-raw-review",
            "review-service-occurrence",
            0
        );
        uint256 reviewContributionId = reviewerActor.registerReviewContribution(
            stateMachine, AVADataTypes.Role.Reviewer, manuscriptId, REVIEWER_SUBJECT, evidenceId, 0
        );

        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            reviewContributionId,
            REVIEWER_SUBJECT,
            "review-procedure-weight",
            1,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://standing-from-raw-review"
        ) {
            revert("standing accepted raw review id");
        } catch {}

        uint256 provisionalStateId =
            stateMachine.provisionallyRecogniseReview(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);
        try allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            provisionalStateId,
            AVADataTypes.AllocationKind.OperationalAllowance,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://allocation-from-provisional"
        ) {
            revert("allocation accepted provisional state");
        } catch {}

        uint256 challengeableStateId = _createChallengeableReviewState();
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256("standing-raw-challenge"),
            "ipfs://standing-raw-challenge",
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

        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            rawChallengeId,
            CHALLENGER_SUBJECT,
            "challenge-procedure-weight",
            -1,
            challengeEvidenceId,
            keccak256("panel-authority"),
            "ipfs://standing-from-raw-challenge"
        ) {
            revert("standing accepted raw challenge-like id");
        } catch {}

        try allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            rawChallengeId,
            AVADataTypes.AllocationKind.OperationalAllowance,
            CHALLENGER_SUBJECT,
            1,
            challengeEvidenceId,
            keccak256("executor-authority"),
            "ipfs://allocation-from-raw-challenge"
        ) {
            revert("allocation accepted raw challenge-like id");
        } catch {}
    }

    function testStandingAndAllocationRejectAllDisallowedRecognisedStateStatuses() public {
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("disallowed-status-evidence"),
            "ipfs://disallowed-status",
            "status-boundary",
            0
        );

        _assertStandingAndAllocationRejectTarget(0, evidenceId);
        _assertStandingAndAllocationRejectTarget(
            _registerRecognisedStateForStatus(AVADataTypes.RecognisedStateStatus.Draft, evidenceId, "draft-status"),
            evidenceId
        );
        _assertStandingAndAllocationRejectTarget(
            _registerRecognisedStateForStatus(
                AVADataTypes.RecognisedStateStatus.Registered, evidenceId, "registered-status"
            ),
            evidenceId
        );
        _assertStandingAndAllocationRejectTarget(
            _registerRecognisedStateForStatus(
                AVADataTypes.RecognisedStateStatus.Provisional, evidenceId, "provisional-status"
            ),
            evidenceId
        );
        _assertStandingAndAllocationRejectTarget(
            _registerRecognisedStateForStatus(
                AVADataTypes.RecognisedStateStatus.Challengeable, evidenceId, "challengeable-status"
            ),
            evidenceId
        );
        _assertStandingAndAllocationRejectTarget(
            _registerRecognisedStateForStatus(AVADataTypes.RecognisedStateStatus.Frozen, evidenceId, "frozen-status"),
            evidenceId
        );
    }
}

contract AVASkeletonCore06ATest is AVASkeletonFixture {
    function testStandingAndAllocationRejectZeroRequiredFields() public {
        (uint256 standingStateId, uint256 evidenceId) = _createDowngradedRecognisedState();
        uint256 allocationStateId = _registerRecognisedStateForStatus(
            AVADataTypes.RecognisedStateStatus.Vested, evidenceId, "vested-allocation"
        );

        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            standingStateId,
            REVIEWER_SUBJECT,
            "review-procedure-weight",
            1,
            0,
            keccak256("panel-authority"),
            "ipfs://zero-evidence"
        ) {
            revert("standing accepted zero evidence");
        } catch {}

        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            standingStateId,
            REVIEWER_SUBJECT,
            "review-procedure-weight",
            1,
            evidenceId,
            bytes32(0),
            "ipfs://zero-authority"
        ) {
            revert("standing accepted zero authority");
        } catch {}

        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            standingStateId,
            bytes32(0),
            "review-procedure-weight",
            1,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://zero-subject"
        ) {
            revert("standing accepted zero subject");
        } catch {}

        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            standingStateId,
            REVIEWER_SUBJECT,
            "",
            1,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://empty-dimension"
        ) {
            revert("standing accepted empty dimension");
        } catch {}

        try allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            allocationStateId,
            AVADataTypes.AllocationKind.None,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://none-kind"
        ) {
            revert("allocation accepted none kind");
        } catch {}

        try allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            allocationStateId,
            AVADataTypes.AllocationKind.OperationalAllowance,
            bytes32(0),
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://zero-subject"
        ) {
            revert("allocation accepted zero subject");
        } catch {}

        try allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            allocationStateId,
            AVADataTypes.AllocationKind.OperationalAllowance,
            REVIEWER_SUBJECT,
            0,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://zero-units"
        ) {
            revert("allocation accepted zero units");
        } catch {}

        try allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            allocationStateId,
            AVADataTypes.AllocationKind.OperationalAllowance,
            REVIEWER_SUBJECT,
            1,
            0,
            keccak256("executor-authority"),
            "ipfs://zero-evidence"
        ) {
            revert("allocation accepted zero evidence");
        } catch {}

        try allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            allocationStateId,
            AVADataTypes.AllocationKind.OperationalAllowance,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            bytes32(0),
            "ipfs://zero-authority"
        ) {
            revert("allocation accepted zero authority");
        } catch {}
    }

    function testStandingAllocationAndConsequenceRejectUnregisteredEvidenceReferences() public {
        (uint256 standingStateId, uint256 registeredEvidenceId) = _createDowngradedRecognisedState();
        uint256 allocationStateId = _registerRecognisedStateForStatus(
            AVADataTypes.RecognisedStateStatus.Vested, registeredEvidenceId, "unregistered-evidence-allocation"
        );
        uint256 missingEvidenceId = evidenceRegistry.nextEvidenceReceiptId() + 100;

        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            standingStateId,
            REVIEWER_SUBJECT,
            "review-procedure-weight",
            1,
            missingEvidenceId,
            keccak256("panel-authority"),
            "ipfs://missing-evidence-standing"
        ) {
            revert("standing accepted unregistered evidence");
        } catch {}

        try allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            allocationStateId,
            AVADataTypes.AllocationKind.OperationalAllowance,
            REVIEWER_SUBJECT,
            1,
            missingEvidenceId,
            keccak256("executor-authority"),
            "ipfs://missing-evidence-allocation"
        ) {
            revert("allocation accepted unregistered evidence");
        } catch {}

        try consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            standingStateId,
            AVADataTypes.ConsequenceKind.AdministrativeNote,
            REVIEWER_SUBJECT,
            missingEvidenceId,
            keccak256("panel-authority"),
            "ipfs://missing-evidence-consequence"
        ) {
            revert("consequence accepted unregistered evidence");
        } catch {}

        require(standingRegistry.nextStandingUpdateId() == 1, "standing recorded missing evidence");
        require(allocationExecutor.nextAllocationExecutionId() == 1, "allocation recorded missing evidence");
        require(consequenceExecutor.nextConsequenceId() == 1, "consequence recorded missing evidence");
    }

    function testDirectRegistrationRejectsDownstreamEligibleRecognisedStates() public {
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("direct-high-state-evidence"),
            "ipfs://direct-high-state",
            "state-boundary",
            0
        );

        _assertDirectHighStatusRegistrationRejected(AVADataTypes.RecognisedStateStatus.Vested, evidenceId);
        _assertDirectHighStatusRegistrationRejected(AVADataTypes.RecognisedStateStatus.Restored, evidenceId);
        _assertDirectHighStatusRegistrationRejected(AVADataTypes.RecognisedStateStatus.Downgraded, evidenceId);
        _assertDirectHighStatusRegistrationRejected(AVADataTypes.RecognisedStateStatus.Voided, evidenceId);
        require(stateMachine.nextRecognisedStateId() == 1, "direct high-status registration created state");
    }
}

contract AVASkeletonCore06BTest is AVASkeletonFixture {
    function testUnsafeRecognisedStateOverloadSelectorIsAbsent() public view {
        _assertNoSelector(
            address(stateMachine), "registerRecognisedState(uint8,uint8,bytes32,uint256,uint256,bytes32,uint8)"
        );
    }

    function testTransitionGeneratedRecognisedStatesStillSupportDownstreamRecords() public {
        (uint256 downgradedStateId, uint256 evidenceId) = _createDowngradedRecognisedState();
        uint256 vestedStateId = _registerRecognisedStateForStatus(
            AVADataTypes.RecognisedStateStatus.Vested, evidenceId, "transition-vested"
        );

        uint256 standingId = standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            downgradedStateId,
            REVIEWER_SUBJECT,
            "review-procedure-weight",
            -1,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://transition-standing"
        );
        uint256 consequenceId = consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            downgradedStateId,
            AVADataTypes.ConsequenceKind.ProcedureCorrection,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://transition-consequence"
        );
        uint256 allocationId = allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            vestedStateId,
            AVADataTypes.AllocationKind.OperationalAllowance,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://transition-allocation"
        );

        require(standingId == 1, "standing not recorded");
        require(consequenceId == 1, "consequence not recorded");
        require(allocationId == 1, "allocation not recorded");
    }

    function testRulePackageReRegistrationDoesNotRewriteExistingRecognisedStateDispatch() public {
        uint256 oldEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("package-version-evidence"),
            "ipfs://package-version-evidence",
            "package-version-basis",
            0
        );
        uint256 oldStateId = _registerRecognisedStateForStatus(
            AVADataTypes.RecognisedStateStatus.Vested, oldEvidenceId, "package-version-old-state"
        );
        uint256 oldPackageId = stateMachine.getRecognisedState(oldStateId).packageId;

        _registerRulePackageWithAdapters(
            DEFAULT_WORKFLOW,
            allocationAdapter,
            consequenceAdapter,
            new MockStandingAdapter("blocked-after-reregister"),
            rewardAdapter,
            priorityAdapter,
            penaltyAdapter,
            restorationAdapter,
            "ipfs://package-version-new-default"
        );
        uint256 newPackageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW).packageId;
        require(newPackageId != oldPackageId, "workflow did not advance active package");

        uint256 newEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            keccak256("package-version-new-evidence"),
            "ipfs://package-version-new-evidence",
            "package-version-basis",
            0
        );
        uint256 newStateId = _registerRecognisedStateForStatus(
            AVADataTypes.RecognisedStateStatus.Vested, newEvidenceId, "package-version-new-state"
        );
        require(stateMachine.getRecognisedState(oldStateId).packageId == oldPackageId, "old state package changed");
        require(
            stateMachine.getRecognisedState(newStateId).packageId == newPackageId, "new state did not bind new package"
        );

        uint256 standingId = standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            oldStateId,
            REVIEWER_SUBJECT,
            "blocked-after-reregister",
            1,
            oldEvidenceId,
            keccak256("panel-authority"),
            "ipfs://old-package-standing"
        );
        require(standingRegistry.getStandingUpdate(standingId).packageId == oldPackageId, "old standing package wrong");

        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            newStateId,
            REVIEWER_SUBJECT,
            "blocked-after-reregister",
            1,
            newEvidenceId,
            keccak256("panel-authority"),
            "ipfs://new-package-standing"
        ) {
            revert("new state did not dispatch through new package");
        } catch {}
    }
}

contract AVASkeletonCore07ATest is AVASkeletonFixture {
    function testChallengeAndTargetPackagesRemainIndependentlyPinnedAfterReregistration() public {
        uint256 oldStateId = _createChallengeableReviewState();
        uint256 oldPackageId = stateMachine.getRecognisedState(oldStateId).packageId;

        bytes32 challengeWorkflowKey = keccak256("independent-challenge-package");
        _registerDefaultRulePackage(challengeWorkflowKey, "ipfs://independent-challenge-package");
        uint256 challengePackageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, challengeWorkflowKey).packageId;

        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            challengeWorkflowKey,
            keccak256("target-package-challenge-evidence"),
            "ipfs://target-package-challenge",
            "review-quality-challenge",
            0
        );
        uint256 challengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            challengeWorkflowKey,
            oldStateId,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            0
        );
        AVADataTypes.ChallengeRecord memory challenge = challengeWorkflow.getChallenge(challengeId);
        require(challenge.packageId == challengePackageId, "challenge package not pinned");
        require(challenge.targetPackageId == oldPackageId, "target package not pinned");

        _registerDefaultRulePackage(challengeWorkflowKey, "ipfs://independent-challenge-package-v2");
        require(
            challengeWorkflow.getChallenge(challengeId).packageId == challengePackageId,
            "challenge package changed retroactively"
        );
        require(
            challengeWorkflow.getChallenge(challengeId).targetPackageId == oldPackageId,
            "target package changed retroactively"
        );

        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            keccak256("panel-authority"),
            "ipfs://independent-package-resolution"
        );
        AVADataTypes.ChallengeRecord memory resolvedChallenge = challengeWorkflow.getChallenge(challengeId);
        AVADataTypes.ChallengeTransitionRecord memory challengeTransition =
            challengeWorkflow.getChallengeTransition(resolvedChallenge.lastTransitionId);
        AVADataTypes.RecognisedStateTransitionRecord memory stateTransition =
            stateMachine.getRecognisedStateTransition(stateMachine.nextRecognisedStateTransitionId() - 1);
        require(challengeTransition.packageId == challengePackageId, "challenge transition package wrong");
        require(challengeTransition.targetPackageId == oldPackageId, "challenge transition target package wrong");
        require(stateTransition.packageId == oldPackageId, "state transition target package wrong");
        require(stateTransition.decisionPackageId == challengePackageId, "state transition decision package wrong");
    }

    function testPostAuditChallengerPenaltyEffectsUseIndependentChallengePackageAndEvidence() public {
        uint256 challengedStateId = _createChallengeableReviewState();
        AVADataTypes.RecognisedStateRecord memory challengedState = stateMachine.getRecognisedState(challengedStateId);

        bytes32 challengeWorkflowKey = keccak256("post-audit-challenger-effect-package");
        _registerDefaultRulePackage(challengeWorkflowKey, "ipfs://post-audit-challenger-effect-package");
        uint256 challengePackageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, challengeWorkflowKey).packageId;
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            challengeWorkflowKey,
            keccak256("post-audit-challenger-effect-evidence"),
            "ipfs://post-audit-challenger-effect-evidence",
            "challenge-integrity-evidence",
            0
        );
        uint256 challengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            challengeWorkflowKey,
            challengedStateId,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            0
        );
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.MaliciousOrFabricated,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://post-audit-challenger-effect-resolution"
        );

        try consequenceExecutor.recordPenalty(
            AVADataTypes.Role.Panel,
            AVADataTypes.PenaltyConsequenceContext({
                challengeId: challengeId,
                findingKind: AVADataTypes.GovernanceFindingKind.MaliciousOrFabricatedChallenge,
                originSettlementId: 0
            }),
            _valueContext(
                challengedStateId,
                CHALLENGER_SUBJECT,
                1,
                challengedState.evidenceReceiptId,
                keccak256("panel-authority"),
                "ipfs://post-audit-wrong-target-evidence",
                keccak256("post-audit-wrong-target-evidence"),
                address(0),
                address(0),
                AVADataTypes.ValueExecutionMode.RecordOnly
            )
        ) {
            revert("challenger penalty accepted target-package evidence");
        } catch {}

        uint256 penaltyId = _recordPenaltyForChallenge(
            challengedStateId,
            challengeId,
            AVADataTypes.GovernanceFindingKind.MaliciousOrFabricatedChallenge,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            keccak256("panel-authority"),
            "ipfs://post-audit-challenger-effect-penalty"
        );
        AVADataTypes.ConsequenceRecord memory penalty = consequenceExecutor.getConsequence(penaltyId);
        require(penalty.packageId == challengePackageId, "challenger penalty package wrong");
        require(penalty.decisionPackageId == challengePackageId, "challenger decision package wrong");

        uint256 challengeRevisionBefore =
            standingRevisionRegistry.currentRevision(challengePackageId, CHALLENGER_SUBJECT);
        uint256 targetRevisionBefore =
            standingRevisionRegistry.currentRevision(challengedState.packageId, CHALLENGER_SUBJECT);
        uint256 standingPenaltyId = consequenceExecutor.recordStandingPenaltyInput(
            AVADataTypes.Role.Panel,
            penaltyId,
            "challenge-integrity-standing",
            -5,
            challengeEvidenceId,
            keccak256("panel-authority"),
            "ipfs://post-audit-challenger-effect-standing"
        );
        require(
            consequenceExecutor.getStandingPenaltyInput(standingPenaltyId).packageId == challengePackageId,
            "standing penalty package wrong"
        );
        require(
            standingRevisionRegistry.currentRevision(challengePackageId, CHALLENGER_SUBJECT)
                == challengeRevisionBefore + 1,
            "challenge package revision not advanced"
        );
        require(
            standingRevisionRegistry.currentRevision(challengedState.packageId, CHALLENGER_SUBJECT)
                == targetRevisionBefore,
            "target package challenger revision changed"
        );

        uint256 restrictionId = consequenceExecutor.recordEligibilityRestriction(
            AVADataTypes.Role.Panel,
            penaltyId,
            AVADataTypes.EligibilityRestrictionKind.ChallengeIntake,
            block.timestamp + 1 days,
            challengeEvidenceId,
            keccak256("panel-authority"),
            "ipfs://post-audit-challenger-effect-restriction"
        );
        require(
            consequenceExecutor.getEligibilityRestriction(restrictionId).packageId == challengePackageId,
            "eligibility restriction package wrong"
        );
        require(
            standingRevisionRegistry.currentRevision(challengePackageId, CHALLENGER_SUBJECT)
                == challengeRevisionBefore + 2,
            "eligibility revision not advanced"
        );

        uint256 operationId = externalOperationRegistry.requestOperation(
            AVADataTypes.Role.Panel,
            challengeWorkflowKey,
            AVADataTypes.ExternalOperationKind.InvestigationIntent,
            AVADataTypes.ExternalOperationTargetKind.ConsequenceRecord,
            penaltyId,
            challengeEvidenceId,
            keccak256("panel-authority"),
            "ipfs://post-audit-challenger-effect-operation"
        );
        AVADataTypes.ExternalOperationRecord memory operation =
            externalOperationRegistry.getExternalOperation(operationId);
        require(operation.packageId == challengePackageId, "challenger consequence operation package wrong");
        require(operation.workflowKey == challengeWorkflowKey, "challenger consequence operation workflow wrong");
    }

    function testPostAuditChallengerPenaltyCanFollowMaliciousChallengeAgainstVestedState() public {
        (uint256 recognisedStateId,) = _createM421EligibleState(DEFAULT_WORKFLOW, "post-audit-vested-challenge-target");
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            DEFAULT_WORKFLOW,
            keccak256("post-audit-vested-challenge-evidence"),
            "ipfs://post-audit-vested-challenge-evidence",
            "challenge-integrity-evidence",
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
            AVADataTypes.ChallengeOutcome.MaliciousOrFabricated,
            AVADataTypes.RecognisedStateStatus.Vested,
            keccak256("panel-authority"),
            "ipfs://post-audit-vested-challenge-resolution"
        );

        uint256 penaltyId = _recordPenaltyForChallenge(
            recognisedStateId,
            challengeId,
            AVADataTypes.GovernanceFindingKind.MaliciousOrFabricatedChallenge,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            keccak256("panel-authority"),
            "ipfs://post-audit-vested-challenge-penalty"
        );
        AVADataTypes.ConsequenceRecord memory penalty = consequenceExecutor.getConsequence(penaltyId);
        require(penalty.challengeId == challengeId, "vested-target challenge link missing");
        require(
            penalty.challengeOutcome == AVADataTypes.ChallengeOutcome.MaliciousOrFabricated,
            "vested-target challenge outcome missing"
        );
        require(
            stateMachine.getRecognisedState(recognisedStateId).status == AVADataTypes.RecognisedStateStatus.Vested,
            "malicious challenge mutated vested target"
        );
    }
}

contract AVASkeletonCore07BTest is AVASkeletonFixture {
    function testPostAuditChallengeDrivenStateTransitionAuditUsesDecisionPackage() public {
        uint256 challengedStateId = _createChallengeableReviewState();
        uint256 targetPackageId = stateMachine.getRecognisedState(challengedStateId).packageId;
        bytes32 challengeWorkflowKey = keccak256("post-audit-transition-audit-decision-package");
        _registerDefaultRulePackage(challengeWorkflowKey, "ipfs://post-audit-transition-audit-decision-package");
        uint256 decisionPackageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, challengeWorkflowKey).packageId;
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            challengeWorkflowKey,
            keccak256("post-audit-transition-audit-evidence"),
            "ipfs://post-audit-transition-audit-evidence",
            "challenge-transition-audit-evidence",
            0
        );
        uint256 challengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            challengeWorkflowKey,
            challengedStateId,
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
            "ipfs://post-audit-transition-audit-resolution"
        );
        uint256 stateTransitionId = stateMachine.nextRecognisedStateTransitionId() - 1;
        AVADataTypes.RecognisedStateTransitionRecord memory transition =
            stateMachine.getRecognisedStateTransition(stateTransitionId);
        require(transition.packageId == targetPackageId, "target package not retained");
        require(transition.decisionPackageId == decisionPackageId, "decision package not retained");

        uint256 attestationId = auditModule.recordRecognisedStateTransitionAttestation(
            AVADataTypes.Role.Panel,
            stateTransitionId,
            keccak256("post-audit-transition-audit-attestation"),
            keccak256("panel-authority"),
            "recognised-state-transition-attestation",
            "ipfs://post-audit-transition-audit-attestation"
        );
        AVADataTypes.AttestationRecord memory attestation = auditModule.getAttestation(attestationId);
        require(attestation.packageId == decisionPackageId, "transition audit did not use decision package");
        require(attestation.evidenceReceiptId == challengeEvidenceId, "transition audit evidence changed");
    }

    function testPostAuditStaleChallengeRestorationCannotOverwriteLaterStateMutation() public {
        (uint256 recognisedStateId,) = _createM421EligibleState(DEFAULT_WORKFLOW, "post-audit-stale-restoration-target");
        (Actor secondChallenger, bytes32 secondChallengerSubject) =
            _newChallengerActor("post-audit-stale-restoration-second");
        uint256 firstEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            DEFAULT_WORKFLOW,
            keccak256("post-audit-stale-restoration-first-evidence"),
            "ipfs://post-audit-stale-restoration-first-evidence",
            "challenge-integrity-evidence",
            0
        );
        uint256 secondEvidenceId = secondChallenger.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            DEFAULT_WORKFLOW,
            keccak256("post-audit-stale-restoration-second-evidence"),
            "ipfs://post-audit-stale-restoration-second-evidence",
            "challenge-integrity-evidence",
            0
        );
        uint256 firstChallengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            DEFAULT_WORKFLOW,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            firstEvidenceId,
            0
        );
        uint256 secondChallengeId = secondChallenger.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            DEFAULT_WORKFLOW,
            recognisedStateId,
            secondChallengerSubject,
            secondEvidenceId,
            0
        );
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, firstChallengeId, EDITOR_AUTHORITY);
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, secondChallengeId, EDITOR_AUTHORITY);
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            firstChallengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Vested,
            keccak256("panel-authority"),
            "ipfs://post-audit-stale-restoration-first-resolution"
        );
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            secondChallengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Voided,
            keccak256("panel-authority"),
            "ipfs://post-audit-stale-restoration-second-resolution"
        );

        try challengeWorkflow.applyRestoration(
            AVADataTypes.Role.Panel,
            firstChallengeId,
            keccak256("panel-authority"),
            "ipfs://post-audit-stale-restoration-attempt"
        ) {
            revert("stale challenge restoration overwrote later state mutation");
        } catch {}
        require(
            stateMachine.getRecognisedState(recognisedStateId).status == AVADataTypes.RecognisedStateStatus.Voided,
            "stale restoration changed target state"
        );
    }

    function testPostAuditConcurrentUpheldChallengeCannotReverseVoidedState() public {
        (uint256 recognisedStateId,) = _createM421EligibleState(DEFAULT_WORKFLOW, "post-audit-concurrent-upheld-target");
        (Actor secondChallenger, bytes32 secondChallengerSubject) =
            _newChallengerActor("post-audit-concurrent-upheld-second");
        uint256 firstEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            DEFAULT_WORKFLOW,
            keccak256("post-audit-concurrent-upheld-first-evidence"),
            "ipfs://post-audit-concurrent-upheld-first-evidence",
            "challenge-integrity-evidence",
            0
        );
        uint256 secondEvidenceId = secondChallenger.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            DEFAULT_WORKFLOW,
            keccak256("post-audit-concurrent-upheld-second-evidence"),
            "ipfs://post-audit-concurrent-upheld-second-evidence",
            "challenge-integrity-evidence",
            0
        );
        uint256 firstChallengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            DEFAULT_WORKFLOW,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            firstEvidenceId,
            0
        );
        uint256 secondChallengeId = secondChallenger.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            DEFAULT_WORKFLOW,
            recognisedStateId,
            secondChallengerSubject,
            secondEvidenceId,
            0
        );
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, firstChallengeId, EDITOR_AUTHORITY);
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, secondChallengeId, EDITOR_AUTHORITY);
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            firstChallengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Voided,
            keccak256("panel-authority"),
            "ipfs://post-audit-concurrent-upheld-first-resolution"
        );

        try challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            secondChallengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            keccak256("panel-authority"),
            "ipfs://post-audit-concurrent-upheld-second-resolution"
        ) {
            revert("later upheld challenge reversed voided state");
        } catch {}
        require(
            stateMachine.getRecognisedState(recognisedStateId).status == AVADataTypes.RecognisedStateStatus.Voided,
            "concurrent challenge reversed voided state"
        );
        require(
            challengeWorkflow.getChallenge(secondChallengeId).status
                == AVADataTypes.ChallengeLifecycleStatus.AdmissibilityScreening,
            "rejected concurrent resolution changed lifecycle"
        );
    }
}

contract AVASkeletonCore08ATest is AVASkeletonFixture {
    function testGenericTransitionRejectsCorrectionAndRestorationStatuses() public {
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("generic-transition-boundary-evidence"),
            "ipfs://generic-transition-boundary",
            "transition-boundary",
            0
        );
        uint256 registeredStateId = stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            keccak256("generic-transition-boundary-state"),
            REVIEWER_SUBJECT,
            evidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        );

        _assertGenericTransitionRejected(registeredStateId, AVADataTypes.RecognisedStateStatus.Downgraded);
        _assertGenericTransitionRejected(registeredStateId, AVADataTypes.RecognisedStateStatus.Voided);
        _assertGenericTransitionRejected(registeredStateId, AVADataTypes.RecognisedStateStatus.Restored);
        require(
            stateMachine.getRecognisedState(registeredStateId).status == AVADataTypes.RecognisedStateStatus.Registered,
            "generic rejection mutated state"
        );

        uint256 downgradedStateId = _registerRecognisedStateForStatus(
            AVADataTypes.RecognisedStateStatus.Downgraded, evidenceId, "generic-path-downgraded"
        );
        uint256 voidedStateId = _registerRecognisedStateForStatus(
            AVADataTypes.RecognisedStateStatus.Voided, evidenceId, "generic-path-voided"
        );
        uint256 restoredStateId = _registerRecognisedStateForStatus(
            AVADataTypes.RecognisedStateStatus.Restored, evidenceId, "generic-path-restored"
        );
        require(
            stateMachine.getRecognisedState(downgradedStateId).status == AVADataTypes.RecognisedStateStatus.Downgraded,
            "challenge downgrade path failed"
        );
        require(
            stateMachine.getRecognisedState(voidedStateId).status == AVADataTypes.RecognisedStateStatus.Voided,
            "challenge void path failed"
        );
        require(
            stateMachine.getRecognisedState(restoredStateId).status == AVADataTypes.RecognisedStateStatus.Restored,
            "restoration path failed"
        );
    }

    function testUnscopedEvidenceCannotEnterWorkflowReviewStateOrChallenge() public {
        roleRegistry.assignRole(
            address(this), AVADataTypes.Role.Reviewer, keccak256("m415-reviewer"), "ipfs://reviewer"
        );
        uint256 legacyEvidenceId = evidenceRegistry.registerEvidenceReceipt(
            AVADataTypes.Role.Reviewer,
            keccak256("m415-unscoped-evidence"),
            "ipfs://m415-unscoped-evidence",
            "unscoped-evidence",
            0
        );
        require(
            evidenceRegistry.getEvidenceReceipt(legacyEvidenceId).workflowKey == bytes32(0),
            "legacy evidence unexpectedly scoped"
        );
        uint256 manuscriptId = _registerAuthorManuscript();

        try reviewerActor.registerReviewContribution(
            stateMachine, AVADataTypes.Role.Reviewer, manuscriptId, REVIEWER_SUBJECT, legacyEvidenceId, 0
        ) {
            revert("unscoped evidence created review contribution");
        } catch {}

        try stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            keccak256("m415-unscoped-state"),
            REVIEWER_SUBJECT,
            legacyEvidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        ) {
            revert("unscoped evidence created recognised state");
        } catch {}

        uint256 recognisedStateId = _createChallengeableReviewState();
        try challengerActor.fileChallenge(
            challengeWorkflow, AVADataTypes.Role.Challenger, recognisedStateId, CHALLENGER_SUBJECT, legacyEvidenceId, 0
        ) {
            revert("unscoped evidence created challenge");
        } catch {}
    }

    function testCanonicalRoleSubjectRejectsSecondActiveAndAllowsAfterDeactivation() public {
        Actor roleActor = new Actor();
        bytes32 firstSubject = keccak256("canonical-first-reviewer");
        bytes32 secondSubject = keccak256("canonical-second-reviewer");
        roleRegistry.assignRole(address(roleActor), AVADataTypes.Role.Reviewer, firstSubject, "ipfs://first");

        try roleRegistry.assignRole(address(roleActor), AVADataTypes.Role.Reviewer, secondSubject, "ipfs://second") {
            revert("second active canonical subject assigned");
        } catch {}
        require(
            roleRegistry.subjectOf(address(roleActor), AVADataTypes.Role.Reviewer) == firstSubject, "canonical changed"
        );
        require(
            roleRegistry.isSubjectFor(address(roleActor), AVADataTypes.Role.Reviewer, firstSubject), "first inactive"
        );

        roleRegistry.deactivateSubject(firstSubject);
        require(!roleRegistry.hasRole(address(roleActor), AVADataTypes.Role.Reviewer), "role stayed active");
        require(
            roleRegistry.subjectOf(address(roleActor), AVADataTypes.Role.Reviewer) == bytes32(0),
            "canonical subject not cleared"
        );
        require(
            !roleRegistry.isSubjectFor(address(roleActor), AVADataTypes.Role.Reviewer, firstSubject),
            "old subject active"
        );

        Actor otherActor = new Actor();
        try roleRegistry.assignRole(address(otherActor), AVADataTypes.Role.Reviewer, firstSubject, "ipfs://reuse") {
            revert("inactive subject id was reused");
        } catch {}

        roleRegistry.assignRole(address(roleActor), AVADataTypes.Role.Reviewer, secondSubject, "ipfs://second");
        require(roleRegistry.hasRole(address(roleActor), AVADataTypes.Role.Reviewer), "role not restored");
        require(
            roleRegistry.subjectOf(address(roleActor), AVADataTypes.Role.Reviewer) == secondSubject,
            "new canonical missing"
        );
        require(
            roleRegistry.isSubjectFor(address(roleActor), AVADataTypes.Role.Reviewer, secondSubject),
            "new subject inactive"
        );
    }
}

contract AVASkeletonCore08BTest is AVASkeletonFixture {
    function testSelfClaimingPathsRejectSomeoneElsesRoleSubject() public {
        Actor secondReviewer = new Actor();
        Actor secondChallenger = new Actor();
        bytes32 secondReviewerSubject = keccak256("second-reviewer-subject");
        bytes32 secondChallengerSubject = keccak256("second-challenger-subject");
        roleRegistry.assignRole(address(secondReviewer), AVADataTypes.Role.Reviewer, secondReviewerSubject, "ipfs://r2");
        roleRegistry.assignRole(
            address(secondChallenger), AVADataTypes.Role.Challenger, secondChallengerSubject, "ipfs://c2"
        );

        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 reviewEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("subject-binding-review"),
            "ipfs://subject-binding-review",
            "review-service-occurrence",
            0
        );
        try secondReviewer.registerReviewContribution(
            stateMachine, AVADataTypes.Role.Reviewer, manuscriptId, REVIEWER_SUBJECT, reviewEvidenceId, 0
        ) {
            revert("reviewer used another reviewer subject");
        } catch {}
        require(stateMachine.nextReviewContributionId() == 1, "mismatched reviewer subject created review");

        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256("subject-binding-challenge"),
            "ipfs://subject-binding-challenge",
            "review-quality-challenge",
            0
        );
        try secondChallenger.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            0
        ) {
            revert("challenger used another challenger subject");
        } catch {}
        require(challengeWorkflow.nextChallengeId() == 1, "mismatched challenger subject created challenge");
    }

    function testDownstreamRecordsRejectUnknownOrInactiveTargetSubjects() public {
        (uint256 downgradedStateId, uint256 evidenceId) = _createDowngradedRecognisedState();
        uint256 vestedStateId =
            _registerRecognisedStateForStatus(AVADataTypes.RecognisedStateStatus.Vested, evidenceId, "subject-vested");
        bytes32 unknownSubject = keccak256("unknown-target-subject");
        bytes32 inactiveSubject = keccak256("inactive-target-subject");
        roleRegistry.assignRole(address(outsiderActor), AVADataTypes.Role.Reviewer, inactiveSubject, "ipfs://inactive");
        roleRegistry.deactivateSubject(inactiveSubject);

        uint256 nextRecognisedStateId = stateMachine.nextRecognisedStateId();
        try stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            keccak256("unknown-subject-state"),
            unknownSubject,
            evidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        ) {
            revert("recognised state accepted unknown subject");
        } catch {}
        try stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            keccak256("inactive-subject-state"),
            inactiveSubject,
            evidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        ) {
            revert("recognised state accepted inactive subject");
        } catch {}
        require(stateMachine.nextRecognisedStateId() == nextRecognisedStateId, "invalid subject created state");

        _assertDownstreamRejectsTargetSubject(downgradedStateId, vestedStateId, evidenceId, unknownSubject);
        _assertDownstreamRejectsTargetSubject(downgradedStateId, vestedStateId, evidenceId, inactiveSubject);
        require(standingRegistry.nextStandingUpdateId() == 1, "standing accepted invalid subject");
        require(allocationExecutor.nextAllocationExecutionId() == 1, "allocation accepted invalid subject");
        require(consequenceExecutor.nextConsequenceId() == 1, "consequence accepted invalid subject");
    }

    function testStandingAndConsequenceRejectActiveSubjectUnrelatedToRecognisedState() public {
        (uint256 downgradedStateId, uint256 challengeId, uint256 evidenceId) = _createResolvedChallengeForSubject(
            REVIEWER_SUBJECT,
            "wrong-state-subject",
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded
        );
        bytes32 otherReviewerSubject = keccak256("other-active-reviewer-subject");
        roleRegistry.assignRole(
            address(outsiderActor), AVADataTypes.Role.Reviewer, otherReviewerSubject, "ipfs://other-reviewer"
        );
        require(
            stateMachine.getRecognisedState(downgradedStateId).subjectId == REVIEWER_SUBJECT,
            "test fixture state subject changed"
        );

        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            downgradedStateId,
            otherReviewerSubject,
            "review-procedure-weight",
            -1,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://wrong-state-subject-standing"
        ) {
            revert("standing update accepted unrelated active subject");
        } catch {}

        try consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            downgradedStateId,
            AVADataTypes.ConsequenceKind.ProcedureCorrection,
            otherReviewerSubject,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://wrong-state-subject-consequence"
        ) {
            revert("consequence accepted unrelated active subject");
        } catch {}

        try consequenceExecutor.recordPenalty(
            AVADataTypes.Role.Panel,
            AVADataTypes.PenaltyConsequenceContext({
                challengeId: challengeId,
                findingKind: AVADataTypes.GovernanceFindingKind.AcademicFraud,
                originSettlementId: 0
            }),
            _valueContext(
                downgradedStateId,
                otherReviewerSubject,
                1,
                evidenceId,
                keccak256("panel-authority"),
                "ipfs://wrong-state-subject-penalty",
                keccak256("wrong-state-subject-penalty"),
                address(0),
                address(0),
                AVADataTypes.ValueExecutionMode.RecordOnly
            )
        ) {
            revert("penalty consequence accepted unrelated active subject");
        } catch {}

        require(standingRegistry.nextStandingUpdateId() == 1, "standing update recorded unrelated subject");
        require(consequenceExecutor.nextConsequenceId() == 1, "consequence recorded unrelated subject");
    }
}

contract AVASkeletonCore09ATest is AVASkeletonFixture {
    function testAuthoritySubjectMismatchIsRejectedForAuthorityBoundActions() public {
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("authority-mismatch-evidence"),
            "ipfs://authority-mismatch",
            "authority-boundary",
            0
        );
        uint256 registeredStateId = stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            keccak256("authority-mismatch-state"),
            REVIEWER_SUBJECT,
            evidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        );
        (uint256 downgradedStateId,) = _createDowngradedRecognisedState();
        uint256 vestedStateId = _registerRecognisedStateForStatus(
            AVADataTypes.RecognisedStateStatus.Vested, evidenceId, "authority-vested"
        );

        try stateMachine.transitionRecognisedState(
            AVADataTypes.Role.Panel,
            registeredStateId,
            AVADataTypes.RecognisedStateStatus.Vested,
            EDITOR_AUTHORITY,
            "ipfs://wrong-authority-transition"
        ) {
            revert("transition accepted mismatched authority");
        } catch {}

        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            downgradedStateId,
            REVIEWER_SUBJECT,
            "review-procedure-weight",
            1,
            evidenceId,
            EDITOR_AUTHORITY,
            "ipfs://wrong-authority-standing"
        ) {
            revert("standing accepted mismatched authority");
        } catch {}

        try allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            vestedStateId,
            AVADataTypes.AllocationKind.OperationalAllowance,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://wrong-authority-allocation"
        ) {
            revert("allocation accepted mismatched authority");
        } catch {}

        try consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            downgradedStateId,
            AVADataTypes.ConsequenceKind.AdministrativeNote,
            REVIEWER_SUBJECT,
            evidenceId,
            EDITOR_AUTHORITY,
            "ipfs://wrong-authority-consequence"
        ) {
            revert("consequence accepted mismatched authority");
        } catch {}
    }

    function testUnknownEvidenceIsRejectedBeforeReviewStateOrChallengeFormation() public {
        uint256 missingEvidenceId = evidenceRegistry.nextEvidenceReceiptId() + 100;
        uint256 manuscriptId = _registerAuthorManuscript();

        try reviewerActor.registerReviewContribution(
            stateMachine, AVADataTypes.Role.Reviewer, manuscriptId, REVIEWER_SUBJECT, missingEvidenceId, 0
        ) {
            revert("review accepted unknown evidence");
        } catch {}
        require(stateMachine.nextReviewContributionId() == 1, "unknown evidence created review");

        try stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            keccak256("unknown-evidence-state"),
            REVIEWER_SUBJECT,
            missingEvidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        ) {
            revert("recognised state accepted unknown evidence");
        } catch {}
        require(stateMachine.nextRecognisedStateId() == 1, "unknown evidence created recognised state");

        uint256 recognisedStateId = _createChallengeableReviewState();
        try challengerActor.fileChallenge(
            challengeWorkflow, AVADataTypes.Role.Challenger, recognisedStateId, CHALLENGER_SUBJECT, missingEvidenceId, 0
        ) {
            revert("challenge accepted unknown evidence");
        } catch {}
        require(challengeWorkflow.nextChallengeId() == 1, "unknown evidence created challenge");
    }

    function testWorkflowEvidenceCannotCrossStateOrDownstreamBoundaries() public {
        bytes32 foreignWorkflow = keccak256("foreign-evidence-workflow");
        _registerDefaultRulePackage(foreignWorkflow, "ipfs://foreign-evidence-workflow");
        uint256 foreignEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            foreignWorkflow,
            keccak256("foreign-evidence"),
            "ipfs://foreign-evidence",
            "foreign-workflow-evidence",
            0
        );
        uint256 manuscriptId = _registerAuthorManuscript();

        try reviewerActor.registerReviewContribution(
            stateMachine, AVADataTypes.Role.Reviewer, manuscriptId, REVIEWER_SUBJECT, foreignEvidenceId, 0
        ) {
            revert("review accepted foreign workflow evidence");
        } catch {}
        require(stateMachine.nextReviewContributionId() == 1, "foreign evidence created review");

        try stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            keccak256("foreign-evidence-state"),
            REVIEWER_SUBJECT,
            foreignEvidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        ) {
            revert("recognised state accepted foreign workflow evidence");
        } catch {}
        require(stateMachine.nextRecognisedStateId() == 1, "foreign evidence created recognised state");

        uint256 challengeableStateId = _createChallengeableReviewState();
        try challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            challengeableStateId,
            CHALLENGER_SUBJECT,
            foreignEvidenceId,
            0
        ) {
            revert("challenge accepted foreign workflow evidence");
        } catch {}

        uint256 defaultEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("default-downstream-evidence"),
            "ipfs://default-downstream-evidence",
            "default-downstream-basis",
            0
        );
        uint256 vestedStateId = _registerRecognisedStateForStatus(
            AVADataTypes.RecognisedStateStatus.Vested, defaultEvidenceId, "default-vested"
        );

        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            vestedStateId,
            REVIEWER_SUBJECT,
            "review-procedure-weight",
            1,
            foreignEvidenceId,
            keccak256("panel-authority"),
            "ipfs://foreign-standing"
        ) {
            revert("standing accepted foreign workflow evidence");
        } catch {}

        try allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            vestedStateId,
            AVADataTypes.AllocationKind.OperationalAllowance,
            REVIEWER_SUBJECT,
            1,
            foreignEvidenceId,
            keccak256("executor-authority"),
            "ipfs://foreign-allocation"
        ) {
            revert("allocation accepted foreign workflow evidence");
        } catch {}

        try consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            vestedStateId,
            AVADataTypes.ConsequenceKind.AdministrativeNote,
            REVIEWER_SUBJECT,
            foreignEvidenceId,
            keccak256("panel-authority"),
            "ipfs://foreign-consequence"
        ) {
            revert("consequence accepted foreign workflow evidence");
        } catch {}

        require(standingRegistry.nextStandingUpdateId() == 1, "foreign evidence created standing");
        require(allocationExecutor.nextAllocationExecutionId() == 1, "foreign evidence created allocation");
        require(consequenceExecutor.nextConsequenceId() == 1, "foreign evidence created consequence");
    }
}

contract AVASkeletonCore09BTest is AVASkeletonFixture {
    function testRecognisedStateStatusChangesWriteGenericTransitionRecords() public {
        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("transition-ledger-review"),
            "ipfs://transition-ledger-review",
            "review-service-occurrence",
            0
        );
        uint256 reviewContributionId = reviewerActor.registerReviewContribution(
            stateMachine, AVADataTypes.Role.Reviewer, manuscriptId, REVIEWER_SUBJECT, evidenceId, 0
        );

        uint256 provisionalTransitionId = stateMachine.nextRecognisedStateTransitionId();
        uint256 recognisedStateId =
            stateMachine.provisionallyRecogniseReview(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);
        _assertRecognisedStateTransition(
            provisionalTransitionId,
            recognisedStateId,
            AVADataTypes.RecognisedStateStatus.None,
            AVADataTypes.RecognisedStateStatus.Provisional,
            AVADataTypes.Action.ProvisionallyRecogniseReview,
            0
        );

        uint256 challengeWindowTransitionId = stateMachine.nextRecognisedStateTransitionId();
        stateMachine.openReviewChallengeWindow(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);
        _assertRecognisedStateTransition(
            challengeWindowTransitionId,
            recognisedStateId,
            AVADataTypes.RecognisedStateStatus.Provisional,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            AVADataTypes.Action.OpenChallengeWindow,
            0
        );

        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256("transition-ledger-challenge"),
            "ipfs://transition-ledger-challenge",
            "review-quality-challenge",
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

        uint256 resolutionTransitionId = stateMachine.nextRecognisedStateTransitionId();
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            keccak256("panel-authority"),
            "ipfs://transition-ledger-resolution"
        );
        _assertRecognisedStateTransition(
            resolutionTransitionId,
            recognisedStateId,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            AVADataTypes.Action.ResolveChallenge,
            challengeId
        );

        uint256 restorationEvidenceId = _registerM51DefaultEvidence("transition-ledger-restoration-target");
        uint256 restorationRecognisedStateId = _registerRecognisedStateForStatus(
            AVADataTypes.RecognisedStateStatus.Vested,
            restorationEvidenceId,
            "transition-ledger-restoration-target"
        );
        uint256 restorationChallengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256("transition-ledger-restoration-challenge"),
            "ipfs://transition-ledger-restoration-challenge",
            "review-quality-challenge",
            0
        );
        uint256 restorationChallengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            restorationRecognisedStateId,
            CHALLENGER_SUBJECT,
            restorationChallengeEvidenceId,
            0
        );
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, restorationChallengeId, EDITOR_AUTHORITY);
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            restorationChallengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Vested,
            keccak256("panel-authority"),
            "ipfs://transition-ledger-good-faith"
        );
        AVADataTypes.ChallengeRecord memory restorationChallenge =
            challengeWorkflow.getChallenge(restorationChallengeId);
        uint256 restorationTransitionId = stateMachine.nextRecognisedStateTransitionId();
        challengeWorkflow.applyRestoration(
            AVADataTypes.Role.Panel,
            restorationChallengeId,
            keccak256("panel-authority"),
            "ipfs://transition-ledger-restored"
        );
        _assertRecognisedStateTransition(
            restorationTransitionId,
            restorationChallenge.challengedRecognisedStateId,
            AVADataTypes.RecognisedStateStatus.Vested,
            AVADataTypes.RecognisedStateStatus.Restored,
            AVADataTypes.Action.ApplyRestoration,
            restorationChallengeId
        );
    }

    function testRemovedStandingInputEntrypointCannotBeCalled() public {
        (bool ok,) = address(standingRegistry)
            .call(
                abi.encodeWithSignature(
                    "registerStandingInput(uint8,uint256,bytes32,string,string)",
                    AVADataTypes.Role.Editor,
                    uint256(1),
                    REVIEWER_SUBJECT,
                    "review-procedure-weight",
                    "ipfs://removed-standing-input"
                )
            );
        require(!ok, "removed standing input entrypoint remained callable");
    }

    function testAuthorisedPanelCanRegisterBoundedConsequenceFromRecognisedState() public {
        (uint256 recognisedStateId, uint256 evidenceId) = _createDowngradedRecognisedState();

        uint256 noteId = consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            AVADataTypes.ConsequenceKind.AdministrativeNote,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://bounded-note"
        );
        uint256 correctionId = consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            AVADataTypes.ConsequenceKind.ProcedureCorrection,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://bounded-correction"
        );
        uint256 restorationId = consequenceExecutor.recordRestoration(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://bounded-restoration"
        );

        AVADataTypes.ConsequenceRecord memory consequence = consequenceExecutor.getConsequence(correctionId);
        require(consequence.recognisedStateId == recognisedStateId, "consequence target wrong");
        require(consequence.kind == AVADataTypes.ConsequenceKind.ProcedureCorrection, "consequence kind wrong");
        require(consequence.subjectId == REVIEWER_SUBJECT, "consequence subject wrong");
        require(consequence.evidenceReceiptId == evidenceId, "consequence evidence wrong");
        require(consequence.authorityRole == AVADataTypes.Role.Panel, "consequence authority role wrong");
        require(consequence.authorityId == keccak256("panel-authority"), "consequence authority wrong");
        require(
            consequenceExecutor.getConsequence(noteId).kind == AVADataTypes.ConsequenceKind.AdministrativeNote,
            "note kind wrong"
        );
        require(
            consequenceExecutor.getConsequence(restorationId).kind == AVADataTypes.ConsequenceKind.RestorationRecord,
            "restoration kind wrong"
        );
        require(standingRegistry.nextStandingUpdateId() == 1, "consequence created standing");
        require(allocationExecutor.nextAllocationExecutionId() == 1, "consequence executed allocation");
    }
}

contract AVASkeletonCore10ATest is AVASkeletonFixture {
    function testUnauthorisedAndEditorCallersCannotRegisterBoundedConsequenceByDefault() public {
        (uint256 recognisedStateId, uint256 evidenceId) = _createDowngradedRecognisedState();

        try outsiderActor.registerConsequence(
            consequenceExecutor,
            AVADataTypes.Role.Panel,
            recognisedStateId,
            AVADataTypes.ConsequenceKind.AdministrativeNote,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("outsider"),
            "ipfs://outsider-consequence"
        ) {
            revert("outsider registered consequence");
        } catch {}

        try consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Editor,
            recognisedStateId,
            AVADataTypes.ConsequenceKind.AdministrativeNote,
            REVIEWER_SUBJECT,
            evidenceId,
            EDITOR_AUTHORITY,
            "ipfs://editor-consequence"
        ) {
            revert("editor registered consequence by default");
        } catch {}
    }

    function testBoundedConsequenceRejectsRawIdsDisallowedStatusesAndZeroFields() public {
        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("consequence-boundary-evidence"),
            "ipfs://consequence-boundary",
            "consequence-boundary",
            0
        );
        uint256 rawReviewId = reviewerActor.registerReviewContribution(
            stateMachine, AVADataTypes.Role.Reviewer, manuscriptId, REVIEWER_SUBJECT, evidenceId, 0
        );

        _assertConsequenceRejectsTarget(rawReviewId, evidenceId);

        uint256 provisionalStateId =
            stateMachine.provisionallyRecogniseReview(AVADataTypes.Role.Editor, rawReviewId, EDITOR_AUTHORITY);
        _assertConsequenceRejectsTarget(provisionalStateId, evidenceId);

        uint256 challengeableStateId = _createChallengeableReviewState();
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256("consequence-raw-challenge"),
            "ipfs://consequence-raw-challenge",
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

        _assertConsequenceRejectsTarget(rawChallengeId, challengeEvidenceId);
        _assertConsequenceRejectsTarget(0, evidenceId);
        _assertConsequenceRejectsTarget(999, evidenceId);
        _assertConsequenceRejectsTarget(
            _registerRecognisedStateForStatus(
                AVADataTypes.RecognisedStateStatus.Draft, evidenceId, "consequence-draft"
            ),
            evidenceId
        );
        _assertConsequenceRejectsTarget(
            _registerRecognisedStateForStatus(
                AVADataTypes.RecognisedStateStatus.Registered, evidenceId, "consequence-registered"
            ),
            evidenceId
        );
        _assertConsequenceRejectsTarget(
            _registerRecognisedStateForStatus(
                AVADataTypes.RecognisedStateStatus.Challengeable, evidenceId, "consequence-challengeable"
            ),
            evidenceId
        );
        _assertConsequenceRejectsTarget(
            _registerRecognisedStateForStatus(
                AVADataTypes.RecognisedStateStatus.Frozen, evidenceId, "consequence-frozen"
            ),
            evidenceId
        );

        uint256 validStateId = _registerRecognisedStateForStatus(
            AVADataTypes.RecognisedStateStatus.Vested, evidenceId, "consequence-vested"
        );
        try consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            validStateId,
            AVADataTypes.ConsequenceKind.None,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://none-kind"
        ) {
            revert("consequence accepted none kind");
        } catch {}
        try consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            validStateId,
            AVADataTypes.ConsequenceKind.AdministrativeNote,
            bytes32(0),
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://zero-subject"
        ) {
            revert("consequence accepted zero subject");
        } catch {}
        try consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            validStateId,
            AVADataTypes.ConsequenceKind.AdministrativeNote,
            REVIEWER_SUBJECT,
            0,
            keccak256("panel-authority"),
            "ipfs://zero-evidence"
        ) {
            revert("consequence accepted zero evidence");
        } catch {}
        try consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            validStateId,
            AVADataTypes.ConsequenceKind.AdministrativeNote,
            REVIEWER_SUBJECT,
            evidenceId,
            bytes32(0),
            "ipfs://zero-authority"
        ) {
            revert("consequence accepted zero authority");
        } catch {}
    }

    function testProtocolExecutorCanExecuteBoundedAllocationFromRecognisedState() public {
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("allocation-evidence"),
            "ipfs://allocation-evidence",
            "recognised-allocation-basis",
            0
        );
        uint256 recognisedStateId = stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Allocation,
            keccak256("allocation-object"),
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
            "ipfs://allocation-state-transition"
        );

        uint256 allocationId = allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            AVADataTypes.AllocationKind.OperationalAllowance,
            REVIEWER_SUBJECT,
            3,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://allocation"
        );

        AVADataTypes.AllocationExecutionRecord memory allocation =
            allocationExecutor.getAllocationExecution(allocationId);
        require(allocation.recognisedStateId == recognisedStateId, "allocation target wrong");
        require(allocation.allocationKind == AVADataTypes.AllocationKind.OperationalAllowance, "allocation kind wrong");
        require(allocation.amountOrUnits == 3, "allocation amount wrong");
        require(allocation.authorityRole == AVADataTypes.Role.ProtocolExecutor, "allocation role wrong");
        require(standingRegistry.nextStandingUpdateId() == 1, "allocation created standing");
        require(consequenceExecutor.nextConsequenceId() == 1, "allocation created consequence");
    }
}

contract AVASkeletonCore10BTest is AVASkeletonFixture {
    function testAlternativeAllocationAdapterCanBeSwappedWithoutChangingRecognisedStateSubstrate() public {
        bytes32 workflowKey = keccak256("adapter-allocation-workflow");
        _ensureWorkflowPackage(workflowKey);
        MockAllocationAdapter mockAllocationAdapter =
            new MockAllocationAdapter(AVADataTypes.AllocationKind.RestorationSupport);
        _registerRulePackageWithAdapters(
            workflowKey,
            mockAllocationAdapter,
            consequenceAdapter,
            standingAdapter,
            rewardAdapter,
            priorityAdapter,
            penaltyAdapter,
            restorationAdapter,
            "ipfs://adapter-allocation-workflow"
        );
        (uint256 recognisedStateId, uint256 evidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, "adapter-allocation-object"
        );

        uint256 allocationId = allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            AVADataTypes.AllocationKind.OperationalAllowance,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://adapter-allocation"
        );
        require(allocationExecutor.getAllocationExecution(allocationId).recognisedStateId == recognisedStateId);

        try allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            AVADataTypes.AllocationKind.RestorationSupport,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://blocked-adapter-allocation"
        ) {
            revert("mock allocation adapter did not block allocation");
        } catch {}

        AVADataTypes.RecognisedStateRecord memory state = stateMachine.getRecognisedState(recognisedStateId);
        require(state.status == AVADataTypes.RecognisedStateStatus.Vested, "adapter changed substrate");
        require(standingRegistry.nextStandingUpdateId() == 1, "adapter created standing");
        require(consequenceExecutor.nextConsequenceId() == 1, "adapter created consequence");
    }

    function testAttributionModuleRejectionBlocksRecognisedStateCreation() public {
        bytes32 blockingWorkflow = keccak256("blocking-attribution-workflow");
        RejectingAttributionModule rejectingAttribution = new RejectingAttributionModule();
        _registerRulePackageWithModules(
            blockingWorkflow,
            rejectingAttribution,
            verificationModule,
            transitionRuleModule,
            disclosurePolicyModule,
            allocationAdapter,
            consequenceAdapter,
            "ipfs://blocking-attribution"
        );
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            blockingWorkflow,
            keccak256("blocking-attribution-evidence"),
            "ipfs://blocking-attribution",
            "review-service-occurrence",
            0
        );

        try stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            PEER_REVIEW_APP_ID,
            blockingWorkflow,
            AVADataTypes.AVAStage.Verification,
            keccak256("blocked-attribution-object"),
            REVIEWER_SUBJECT,
            evidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        ) {
            revert("attribution rejection did not block recognised state");
        } catch {}
    }

    function testVerificationModuleRejectionBlocksRecognisedStateCreation() public {
        bytes32 blockingWorkflow = keccak256("blocking-verification-workflow");
        RejectingVerificationModule rejectingVerification = new RejectingVerificationModule();
        _registerRulePackageWithModules(
            blockingWorkflow,
            attributionModule,
            rejectingVerification,
            transitionRuleModule,
            disclosurePolicyModule,
            allocationAdapter,
            consequenceAdapter,
            "ipfs://blocking-verification"
        );
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            blockingWorkflow,
            keccak256("blocking-verification-evidence"),
            "ipfs://blocking-verification",
            "review-service-occurrence",
            0
        );

        try stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            PEER_REVIEW_APP_ID,
            blockingWorkflow,
            AVADataTypes.AVAStage.Verification,
            keccak256("blocked-verification-object"),
            REVIEWER_SUBJECT,
            evidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        ) {
            revert("verification rejection did not block recognised state");
        } catch {}
    }
}

contract AVASkeletonCore11ATest is AVASkeletonFixture {
    function testTransitionRuleRejectionBlocksStatusMovement() public {
        roleRegistry.assignRole(
            address(this), AVADataTypes.Role.Reviewer, keccak256("local-reviewer"), "ipfs://reviewer"
        );
        bytes32 blockingWorkflow = keccak256("blocking-transition-workflow");
        RejectingTransitionRuleModule rejectingTransition = new RejectingTransitionRuleModule();
        _registerRulePackageWithModules(
            blockingWorkflow,
            attributionModule,
            verificationModule,
            rejectingTransition,
            disclosurePolicyModule,
            allocationAdapter,
            consequenceAdapter,
            "ipfs://blocking-transition"
        );
        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            blockingWorkflow,
            keccak256("blocking-transition-evidence"),
            "ipfs://blocking-transition",
            "review-service-occurrence",
            0
        );
        uint256 reviewContributionId = reviewerActor.registerReviewContributionWithWorkflow(
            stateMachine, AVADataTypes.Role.Reviewer, blockingWorkflow, manuscriptId, REVIEWER_SUBJECT, evidenceId, 0
        );
        stateMachine.provisionallyRecogniseReview(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);

        try stateMachine.openReviewChallengeWindow(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY) {
            revert("transition-rule rejection did not block status movement");
        } catch {}
    }

    function testScopedDisclosureRejectionBlocksMainTransitionAction() public {
        roleRegistry.assignRole(
            address(this), AVADataTypes.Role.Reviewer, keccak256("local-reviewer"), "ipfs://reviewer"
        );
        uint256 disclosurePolicyId = disclosureRegistry.registerDisclosurePolicy(
            AVADataTypes.Role.Editor, PEER_REVIEW_APP_ID, "scoped-disclosure-blocker", "ipfs://scoped-disclosure"
        );
        bytes32 workflow = keccak256("blocking-disclosure-action-workflow");
        StageScopedDisclosureModule stageScopedDisclosure = new StageScopedDisclosureModule(
            AVADataTypes.Action.OpenChallengeWindow, AVADataTypes.AVAStage.Verification, bytes32(uint256(1))
        );
        _registerRulePackageWithModules(
            workflow,
            attributionModule,
            verificationModule,
            transitionRuleModule,
            stageScopedDisclosure,
            allocationAdapter,
            consequenceAdapter,
            "ipfs://blocking-disclosure-action"
        );
        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflow,
            keccak256("blocking-disclosure-evidence"),
            "ipfs://blocking-disclosure",
            "review-service-occurrence",
            disclosurePolicyId
        );
        uint256 reviewContributionId = reviewerActor.registerReviewContributionWithWorkflow(
            stateMachine,
            AVADataTypes.Role.Reviewer,
            workflow,
            manuscriptId,
            REVIEWER_SUBJECT,
            evidenceId,
            disclosurePolicyId
        );
        stateMachine.provisionallyRecogniseReview(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);

        try stateMachine.openReviewChallengeWindow(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY) {
            revert("scoped disclosure rejection did not block status movement");
        } catch {}
    }
}
