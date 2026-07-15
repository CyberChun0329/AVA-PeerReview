// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./helpers/AVASkeletonFixture.sol";

contract AVASkeletonModulesAuthority01ATest is AVASkeletonFixture {
    function testAllocationAndConsequenceModulesAreReplaceableAndRecordOnly() public {
        bytes32 workflowKey = keccak256("replaceable-downstream-workflow");
        _ensureWorkflowPackage(workflowKey);
        MockAllocationAdapter mockAllocation = new MockAllocationAdapter(AVADataTypes.AllocationKind.RestorationSupport);
        MockConsequenceAdapter mockConsequence =
            new MockConsequenceAdapter(AVADataTypes.ConsequenceKind.ProcedureCorrection);
        _registerRulePackageWithAdapters(
            workflowKey,
            mockAllocation,
            mockConsequence,
            standingAdapter,
            rewardAdapter,
            priorityAdapter,
            penaltyAdapter,
            restorationAdapter,
            "ipfs://replaceable-downstream-workflow"
        );
        (uint256 recognisedStateId, uint256 evidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, "replaceable-modules"
        );

        uint256 allocationId = allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            AVADataTypes.AllocationKind.OperationalAllowance,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://replaceable-allocation"
        );
        uint256 consequenceId = consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            AVADataTypes.ConsequenceKind.AdministrativeNote,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://replaceable-consequence"
        );

        try allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            AVADataTypes.AllocationKind.RestorationSupport,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://blocked-allocation-module"
        ) {
            revert("replaceable allocation module did not block");
        } catch {}
        try consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            AVADataTypes.ConsequenceKind.ProcedureCorrection,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://blocked-consequence-module"
        ) {
            revert("replaceable consequence module did not block");
        } catch {}

        require(allocationExecutor.getAllocationExecution(allocationId).recognisedStateId == recognisedStateId);
        require(consequenceExecutor.getConsequence(consequenceId).recognisedStateId == recognisedStateId);
        require(standingRegistry.nextStandingUpdateId() == 1, "replaceable module created standing");
        require(
            consequenceExecutor.nextConsequenceId() == consequenceId + 1, "consequence executor did not record once"
        );
    }

    function testStandingAdapterIsStandingSpecificAndDoesNotCreateReward() public {
        bytes32 workflowKey = keccak256("standing-adapter-workflow");
        _ensureWorkflowPackage(workflowKey);
        MockStandingAdapter mockStanding = new MockStandingAdapter("blocked-standing-dimension");
        _registerRulePackageWithAdapters(
            workflowKey,
            allocationAdapter,
            consequenceAdapter,
            mockStanding,
            rewardAdapter,
            priorityAdapter,
            penaltyAdapter,
            restorationAdapter,
            "ipfs://standing-adapter-workflow"
        );
        (uint256 recognisedStateId, uint256 evidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowKey, AVADataTypes.RecognisedStateStatus.Downgraded, "standing-adapter-state"
        );

        uint256 standingUpdateId = standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            "review-procedure-weight",
            1,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://standing-adapter"
        );
        require(standingRegistry.getStandingUpdate(standingUpdateId).recognisedStateId == recognisedStateId);

        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            "blocked-standing-dimension",
            1,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://blocked-standing-adapter"
        ) {
            revert("standing adapter was not invoked");
        } catch {}

        require(allocationExecutor.nextAllocationExecutionId() == 1, "standing update created reward or priority");
        require(consequenceExecutor.nextConsequenceId() == 1, "standing update created consequence");
    }

    function testRewardValueAdapterCanBeSwappedWithoutChangingRecognisedStateSubstrate() public {
        bytes32 workflowKey = keccak256("reward-adapter-workflow");
        _ensureWorkflowPackage(workflowKey);
        MockRewardAdapter mockReward = new MockRewardAdapter(7);
        _registerRulePackageWithAdapters(
            workflowKey,
            allocationAdapter,
            consequenceAdapter,
            standingAdapter,
            mockReward,
            priorityAdapter,
            penaltyAdapter,
            restorationAdapter,
            "ipfs://reward-adapter-workflow"
        );
        (uint256 recognisedStateId, uint256 evidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, "reward-adapter"
        );

        uint256 rewardRecordId = allocationExecutor.recordRewardValue(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://reward-record"
        );
        AVADataTypes.AllocationExecutionRecord memory rewardRecord =
            allocationExecutor.getAllocationExecution(rewardRecordId);
        require(rewardRecord.allocationKind == AVADataTypes.AllocationKind.RewardValueRecord, "wrong reward kind");

        try allocationExecutor.recordRewardValue(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            REVIEWER_SUBJECT,
            7,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://blocked-reward-record"
        ) {
            revert("reward adapter was not invoked");
        } catch {}

        require(
            stateMachine.getRecognisedState(recognisedStateId).status == AVADataTypes.RecognisedStateStatus.Vested,
            "reward adapter mutated recognised state"
        );
        require(standingRegistry.nextStandingUpdateId() == 1, "reward record created standing");
        require(consequenceExecutor.nextConsequenceId() == 1, "reward record created consequence");
    }
}

contract AVASkeletonModulesAuthority01BTest is AVASkeletonFixture {
    function testPriorityAdapterCanBeSwappedWithoutPublicationAdvantage() public {
        bytes32 workflowKey = keccak256("priority-adapter-workflow");
        _ensureWorkflowPackage(workflowKey);
        MockPriorityAdapter mockPriority = new MockPriorityAdapter(9);
        _registerRulePackageWithAdapters(
            workflowKey,
            allocationAdapter,
            consequenceAdapter,
            standingAdapter,
            rewardAdapter,
            mockPriority,
            penaltyAdapter,
            restorationAdapter,
            "ipfs://priority-adapter-workflow"
        );
        (uint256 recognisedStateId, uint256 evidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, "priority-adapter"
        );

        uint256 priorityRecordId = allocationExecutor.recordAdministrativePriority(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://priority-record"
        );
        AVADataTypes.AllocationExecutionRecord memory priorityRecord =
            allocationExecutor.getAllocationExecution(priorityRecordId);
        require(
            priorityRecord.allocationKind == AVADataTypes.AllocationKind.AdministrativeQueueRecord,
            "wrong priority kind"
        );

        try allocationExecutor.recordAdministrativePriority(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            REVIEWER_SUBJECT,
            9,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://blocked-priority-record"
        ) {
            revert("priority adapter was not invoked");
        } catch {}

        _assertNoSelector(address(allocationExecutor), "grantPublicationPriority(uint256)");
        _assertNoSelector(address(allocationExecutor), "boostManuscriptScore(uint256)");
        require(standingRegistry.nextStandingUpdateId() == 1, "priority record created standing");
        require(consequenceExecutor.nextConsequenceId() == 1, "priority record created consequence");
    }

    function testPenaltyAdapterCanBeSwappedAndRemainsRecordOnly() public {
        bytes32 workflowKey = keccak256("penalty-adapter-workflow");
        _ensureWorkflowPackage(workflowKey);
        bytes32 blockedAuthority = keccak256("blocked-penalty-authority");
        MockPenaltyAdapter mockPenalty = new MockPenaltyAdapter(blockedAuthority);
        _registerRulePackageWithAdapters(
            workflowKey,
            allocationAdapter,
            consequenceAdapter,
            standingAdapter,
            rewardAdapter,
            priorityAdapter,
            mockPenalty,
            restorationAdapter,
            "ipfs://penalty-adapter-workflow"
        );
        (uint256 recognisedStateId, uint256 challengeId, uint256 evidenceId) = _createResolvedChallengeForWorkflowSubject(
            workflowKey,
            REVIEWER_SUBJECT,
            "penalty-adapter-state",
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded
        );

        uint256 penaltyRecordId = _recordPenaltyForChallenge(
            recognisedStateId,
            challengeId,
            AVADataTypes.GovernanceFindingKind.IrresponsibleReview,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://penalty-record"
        );
        require(
            consequenceExecutor.getConsequence(penaltyRecordId).kind == AVADataTypes.ConsequenceKind.PenaltyRecord,
            "wrong penalty kind"
        );

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
                blockedAuthority,
                "ipfs://blocked-penalty-record",
                keccak256("blocked-penalty-record"),
                address(0),
                address(0),
                AVADataTypes.ValueExecutionMode.RecordOnly
            )
        ) {
            revert("penalty adapter was not invoked");
        } catch {}

        require(standingRegistry.nextStandingUpdateId() == 1, "penalty record created standing");
        require(allocationExecutor.nextAllocationExecutionId() == 1, "penalty record executed allocation");
    }

    function testRestorationAdapterCanBeSwappedAndRemainsDistinctFromReward() public {
        bytes32 workflowKey = keccak256("restoration-adapter-workflow");
        _ensureWorkflowPackage(workflowKey);
        bytes32 blockedAuthority = keccak256("blocked-restoration-authority");
        MockRestorationAdapter mockRestoration = new MockRestorationAdapter(blockedAuthority);
        _registerRulePackageWithAdapters(
            workflowKey,
            allocationAdapter,
            consequenceAdapter,
            standingAdapter,
            rewardAdapter,
            priorityAdapter,
            penaltyAdapter,
            mockRestoration,
            "ipfs://restoration-adapter-workflow"
        );
        (uint256 recognisedStateId, uint256 evidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowKey, AVADataTypes.RecognisedStateStatus.Restored, "restoration-adapter"
        );

        uint256 restorationRecordId = consequenceExecutor.recordRestoration(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://restoration-record"
        );
        require(
            consequenceExecutor.getConsequence(restorationRecordId).kind
                == AVADataTypes.ConsequenceKind.RestorationRecord,
            "wrong restoration kind"
        );

        try consequenceExecutor.recordRestoration(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            evidenceId,
            blockedAuthority,
            "ipfs://blocked-restoration-record"
        ) {
            revert("restoration adapter was not invoked");
        } catch {}

        require(allocationExecutor.nextAllocationExecutionId() == 1, "restoration record created reward");
        require(standingRegistry.nextStandingUpdateId() == 1, "restoration record created standing");
    }
}

contract AVASkeletonModulesAuthority02ATest is AVASkeletonFixture {
    function testM49InfrastructureInterfacesHaveDefaultAndExampleModules() public {
        bytes32 evidenceTypeHash = keccak256("m49-evidence-type");
        bytes32 objectId = keccak256("m49-object");
        bytes32 subjectId = keccak256("m49-subject");
        bytes32 attestationHash = keccak256("m49-attestation");

        evidencePolicyModule.validateEvidencePolicy(
            DEFAULT_WORKFLOW,
            AVADataTypes.Role.Editor,
            AVADataTypes.Action.RegisterEvidence,
            1,
            evidenceTypeHash,
            address(this)
        );
        auditAdapter.validateAuditRecord(
            DEFAULT_WORKFLOW,
            AVADataTypes.Role.Panel,
            AVADataTypes.Action.RecordAttestation,
            objectId,
            1,
            attestationHash,
            address(this)
        );
        editorialSystemAdapter.validateEditorialReference(
            DEFAULT_WORKFLOW,
            AVADataTypes.Role.Editor,
            AVADataTypes.Action.RegisterManuscript,
            objectId,
            "ipfs://editorial-ref",
            address(this)
        );
        fieldPolicyModule.validateFieldPolicy(
            DEFAULT_WORKFLOW,
            AVADataTypes.Role.Editor,
            AVADataTypes.Action.RegisterRecognisedState,
            AVADataTypes.AVAStage.Verification,
            objectId,
            1
        );
        antiAbuseModule.validateUse(
            DEFAULT_WORKFLOW,
            AVADataTypes.Role.Challenger,
            AVADataTypes.Action.FileChallenge,
            subjectId,
            objectId,
            address(this)
        );

        new TypedEvidencePolicyModule(evidenceTypeHash)
            .validateEvidencePolicy(
                DEFAULT_WORKFLOW,
                AVADataTypes.Role.Editor,
                AVADataTypes.Action.RegisterEvidence,
                1,
                evidenceTypeHash,
                address(this)
            );
        new HashAnchoredAuditAdapter()
            .validateAuditRecord(
                DEFAULT_WORKFLOW,
                AVADataTypes.Role.Panel,
                AVADataTypes.Action.RecordAttestation,
                objectId,
                1,
                attestationHash,
                address(this)
            );
        new EditorialReferenceAdapter()
            .validateEditorialReference(
                DEFAULT_WORKFLOW,
                AVADataTypes.Role.Editor,
                AVADataTypes.Action.RegisterManuscript,
                objectId,
                "ipfs://editorial-ref",
                address(this)
            );
        new DisciplineFieldPolicyModule(AVADataTypes.AVAStage.Verification)
            .validateFieldPolicy(
                DEFAULT_WORKFLOW,
                AVADataTypes.Role.Editor,
                AVADataTypes.Action.RegisterRecognisedState,
                AVADataTypes.AVAStage.Verification,
                objectId,
                1
            );
        new SubjectRateLimitModule()
            .validateUse(
                DEFAULT_WORKFLOW,
                AVADataTypes.Role.Challenger,
                AVADataTypes.Action.FileChallenge,
                subjectId,
                objectId,
                address(this)
            );
    }

    function testM49WorkflowBindsNonDefaultCentralAndInfrastructureModules() public {
        bytes32 workflowKey = keccak256("m49-non-default-workflow");
        AVARulePackageRegistry.RulePackage memory rulePackage = _registerM49NonDefaultRulePackage(workflowKey);
        bytes32 objectId = keccak256("m49-object");
        bytes32 subjectId = keccak256("m49-subject");
        bytes32 evidenceTypeHash = keccak256("m49-evidence-type");
        uint256 evidenceReceiptId = 3;

        bytes32 attributedObjectId = rulePackage.attributionModule
            .validateAttribution(
                IAttributionModule.AttributionContext({
                    workflowKey: workflowKey,
                    packageId: rulePackage.packageId,
                    actingRole: AVADataTypes.Role.Reviewer,
                    action: AVADataTypes.Action.RegisterRecognisedState,
                    stage: AVADataTypes.AVAStage.Verification,
                    objectId: objectId,
                    subjectId: subjectId,
                    evidenceReceiptId: evidenceReceiptId,
                    disclosurePolicyId: 0,
                    actor: address(this)
                })
            );
        require(attributedObjectId != objectId, "non-default attribution unused");
        rulePackage.verificationModule
            .validateVerification(
                IVerificationModule.VerificationContext({
                    workflowKey: workflowKey,
                    packageId: rulePackage.packageId,
                    actingRole: AVADataTypes.Role.Editor,
                    action: AVADataTypes.Action.RegisterRecognisedState,
                    stage: AVADataTypes.AVAStage.Verification,
                    objectId: attributedObjectId,
                    subjectId: subjectId,
                    evidenceReceiptId: evidenceReceiptId,
                    disclosurePolicyId: 0,
                    actor: address(this)
                })
            );
        rulePackage.transitionRuleModule
            .validateTransition(
                workflowKey,
                AVADataTypes.Action.ResolveChallenge,
                AVADataTypes.RecognisedStateStatus.Challengeable,
                AVADataTypes.RecognisedStateStatus.Downgraded,
                AVADataTypes.ChallengeOutcome.Upheld
            );
        rulePackage.challengeLifecycleModule
                .validateChallengeAction(
                IChallengeLifecycleModule.ChallengeLifecycleContext({
                    workflowKey: workflowKey,
                    action: AVADataTypes.Action.ResolveChallenge,
                    fromLifecycleStatus: AVADataTypes.ChallengeLifecycleStatus.AdmissibilityScreening,
                    toLifecycleStatus: AVADataTypes.ChallengeLifecycleStatus.Resolved,
                    outcome: AVADataTypes.ChallengeOutcome.Upheld,
                    challengedStateStatus: AVADataTypes.RecognisedStateStatus.Challengeable,
                    proposedStateStatus: AVADataTypes.RecognisedStateStatus.Downgraded,
                    actor: address(this),
                    filedBy: address(challengerActor)
                })
            );
        rulePackage.evidencePolicyModule
            .validateEvidencePolicy(
                workflowKey,
                AVADataTypes.Role.Editor,
                AVADataTypes.Action.RegisterEvidence,
                evidenceReceiptId,
                evidenceTypeHash,
                address(this)
            );
        rulePackage.auditAdapter
            .validateAuditRecord(
                workflowKey,
                AVADataTypes.Role.Panel,
                AVADataTypes.Action.RecordAttestation,
                objectId,
                evidenceReceiptId,
                keccak256("m49-audit"),
                address(this)
            );
        rulePackage.editorialSystemAdapter
            .validateEditorialReference(
                workflowKey,
                AVADataTypes.Role.Editor,
                AVADataTypes.Action.RegisterManuscript,
                objectId,
                "ipfs://editorial-ref",
                address(this)
            );
        rulePackage.fieldPolicyModule
            .validateFieldPolicy(
                workflowKey,
                AVADataTypes.Role.Editor,
                AVADataTypes.Action.RegisterRecognisedState,
                AVADataTypes.AVAStage.Verification,
                objectId,
                evidenceReceiptId
            );
        rulePackage.antiAbuseModule
            .validateUse(
                workflowKey,
                AVADataTypes.Role.Challenger,
                AVADataTypes.Action.FileChallenge,
                subjectId,
                objectId,
                address(this)
            );
    }

    function testM49DownstreamExampleAdaptersAreSwappableAndRecordOnly() public {
        bytes32 workflowKey = keccak256("m49-downstream-workflow");
        _ensureWorkflowPackage(workflowKey);

        _registerM49DownstreamWorkflow(workflowKey);
        (uint256 recognisedStateId, uint256 evidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowKey, AVADataTypes.RecognisedStateStatus.Downgraded, "m49-downstream-state"
        );
        (uint256 positiveStateId, uint256 positiveEvidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, "m49-positive-downstream-state"
        );

        standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            "review-vector-weight",
            2,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://m49-standing"
        );
        uint256 rewardRecordId = allocationExecutor.recordRewardValue(
            AVADataTypes.Role.ProtocolExecutor,
            positiveStateId,
            REVIEWER_SUBJECT,
            1,
            positiveEvidenceId,
            keccak256("executor-authority"),
            "ipfs://m49-stablecoin-record"
        );
        uint256 priorityRecordId = allocationExecutor.recordAdministrativePriority(
            AVADataTypes.Role.ProtocolExecutor,
            positiveStateId,
            REVIEWER_SUBJECT,
            1,
            positiveEvidenceId,
            keccak256("executor-authority"),
            "ipfs://m49-priority-token-record"
        );
        uint256 consequenceId = consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            AVADataTypes.ConsequenceKind.AdministrativeNote,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://m49-consequence"
        );
        (uint256 penaltyStateId, uint256 penaltyChallengeId, uint256 penaltyEvidenceId) = _createResolvedChallengeForWorkflowSubject(
            workflowKey,
            REVIEWER_SUBJECT,
            "m49-procedural-penalty",
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
            "ipfs://m49-procedural-penalty-record"
        );
        uint256 restorationId = consequenceExecutor.recordRestoration(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://m49-restoration-procedure-record"
        );

        require(
            allocationExecutor.getAllocationExecution(rewardRecordId).allocationKind
                == AVADataTypes.AllocationKind.RewardValueRecord,
            "wrong stablecoin record kind"
        );
        require(
            allocationExecutor.getAllocationExecution(priorityRecordId).allocationKind
                == AVADataTypes.AllocationKind.AdministrativeQueueRecord,
            "wrong priority record kind"
        );
        require(
            consequenceExecutor.getConsequence(consequenceId).kind == AVADataTypes.ConsequenceKind.AdministrativeNote
        );
        require(consequenceExecutor.getConsequence(penaltyId).kind == AVADataTypes.ConsequenceKind.PenaltyRecord);
        require(
            consequenceExecutor.getConsequence(restorationId).kind == AVADataTypes.ConsequenceKind.RestorationRecord
        );

        require(
            stateMachine.getRecognisedState(recognisedStateId).status == AVADataTypes.RecognisedStateStatus.Downgraded,
            "downstream adapter mutated recognised state"
        );
        require(
            stateMachine.getRecognisedState(positiveStateId).status == AVADataTypes.RecognisedStateStatus.Vested,
            "positive adapter mutated recognised state"
        );
        _assertM49SecondaryDownstreamExamples(positiveStateId, positiveEvidenceId);
        _assertM49DownstreamSelectorBoundaries(workflowKey);
    }
}

contract AVASkeletonModulesAuthority02BTest is AVASkeletonFixture {
    function testM491EvidencePolicyBlocksEvidenceRegistrationAndRecognisedStatePath() public {
        roleRegistry.assignRole(
            address(this), AVADataTypes.Role.Reviewer, keccak256("reviewer-this"), "ipfs://reviewer"
        );
        bytes32 evidenceWorkflow = keccak256("m491-evidence-registration");
        _registerRulePackageWithInfrastructure(
            evidenceWorkflow,
            new RejectingEvidencePolicyModule(AVADataTypes.Action.RegisterEvidence),
            auditAdapter,
            editorialSystemAdapter,
            fieldPolicyModule,
            antiAbuseModule,
            "ipfs://m491-evidence-registration"
        );
        try evidenceRegistry.registerEvidenceReceipt(
            AVADataTypes.Role.Reviewer,
            PEER_REVIEW_APP_ID, evidenceWorkflow,
            keccak256("m491-evidence"),
            "ipfs://m491-evidence",
            "blocked-evidence-type",
            0
        ) {
            revert("evidence policy did not block evidence registration");
        } catch {}

        bytes32 recognisedWorkflow = keccak256("m491-evidence-recognised");
        _ensureWorkflowPackage(recognisedWorkflow);
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            recognisedWorkflow,
            keccak256("m491-recognised-evidence"),
            "ipfs://m491-recognised-evidence",
            "recognised-state-basis",
            0
        );
        _registerRulePackageWithInfrastructure(
            recognisedWorkflow,
            new RejectingEvidencePolicyModule(AVADataTypes.Action.RegisterRecognisedState),
            auditAdapter,
            editorialSystemAdapter,
            fieldPolicyModule,
            antiAbuseModule,
            "ipfs://m491-evidence-recognised"
        );
        try stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            PEER_REVIEW_APP_ID,
            recognisedWorkflow,
            AVADataTypes.AVAStage.Verification,
            keccak256("m491-recognised-object"),
            REVIEWER_SUBJECT,
            evidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        ) {
            revert("evidence policy did not block recognised-state path");
        } catch {}
    }

    function testM491FieldPolicyBlocksRecognisedStateValidation() public {
        bytes32 workflowKey = keccak256("m491-field-policy");
        _ensureWorkflowPackage(workflowKey);
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m491-field-evidence"),
            "ipfs://m491-field-evidence",
            "field-policy-basis",
            0
        );
        _registerRulePackageWithInfrastructure(
            workflowKey,
            evidencePolicyModule,
            auditAdapter,
            editorialSystemAdapter,
            new RejectingFieldPolicyModule(),
            antiAbuseModule,
            "ipfs://m491-field-policy"
        );

        try stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            PEER_REVIEW_APP_ID,
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            keccak256("m491-field-object"),
            REVIEWER_SUBJECT,
            evidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        ) {
            revert("field policy did not block recognised-state validation");
        } catch {}
    }

    function testM491AntiAbuseBlocksReviewChallengeAndDownstreamPaths() public {
        roleRegistry.assignRole(
            address(this), AVADataTypes.Role.Reviewer, keccak256("reviewer-this"), "ipfs://reviewer"
        );

        uint256 manuscriptId = stateMachine.registerManuscript(
            AVADataTypes.Role.Author,
            PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW,
            keccak256("m491-abuse-manuscript"),
            "ipfs://m491-abuse-manuscript",
            ""
        );
        bytes32 reviewWorkflow = keccak256("m491-abuse-review");
        _ensureWorkflowPackage(reviewWorkflow);
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            reviewWorkflow,
            keccak256("m491-abuse-evidence"),
            "ipfs://m491-abuse-evidence",
            "abuse-basis",
            0
        );

        _registerRulePackageWithInfrastructure(
            reviewWorkflow,
            evidencePolicyModule,
            auditAdapter,
            editorialSystemAdapter,
            fieldPolicyModule,
            new RejectingAntiAbuseModule(AVADataTypes.Action.RegisterReviewContribution),
            "ipfs://m491-abuse-review"
        );
        try stateMachine.registerReviewContribution(
            AVADataTypes.Role.Reviewer, PEER_REVIEW_APP_ID, reviewWorkflow, manuscriptId, REVIEWER_SUBJECT, evidenceId, 0
        ) {
            revert("anti-abuse did not block review registration");
        } catch {}

        bytes32 challengeWorkflowKey = keccak256("m491-abuse-challenge");
        _registerRulePackageWithInfrastructure(
            challengeWorkflowKey,
            evidencePolicyModule,
            auditAdapter,
            editorialSystemAdapter,
            fieldPolicyModule,
            new RejectingAntiAbuseModule(AVADataTypes.Action.FileChallenge),
            "ipfs://m491-abuse-challenge"
        );
        uint256 challengedStateId = _createChallengeableReviewStateThroughPackage(
            rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, challengeWorkflowKey), challengeWorkflowKey
        );
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            challengeWorkflowKey,
            keccak256("m491-abuse-challenge-evidence"),
            "ipfs://m491-abuse-challenge-evidence",
            "abuse-challenge-basis",
            0
        );
        try challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            challengeWorkflowKey,
            challengedStateId,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            0
        ) {
            revert("anti-abuse did not block challenge filing");
        } catch {}

        bytes32 downstreamWorkflow = keccak256("m491-abuse-downstream");
        _registerRulePackageWithInfrastructure(
            downstreamWorkflow,
            evidencePolicyModule,
            auditAdapter,
            editorialSystemAdapter,
            fieldPolicyModule,
            new RejectingAntiAbuseModule(AVADataTypes.Action.RecordStandingUpdate),
            "ipfs://m491-abuse-downstream"
        );
        uint256 downstreamEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            downstreamWorkflow,
            keccak256("m491-abuse-downstream-evidence"),
            "ipfs://m491-abuse-downstream-evidence",
            "abuse-downstream-basis",
            0
        );
        uint256 downstreamStateId = _registerRecognisedStateForWorkflowStatus(
            downstreamWorkflow, AVADataTypes.RecognisedStateStatus.Vested, downstreamEvidenceId, "m491-abuse-downstream"
        );
        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            downstreamStateId,
            REVIEWER_SUBJECT,
            "review-procedure-weight",
            1,
            downstreamEvidenceId,
            keccak256("panel-authority"),
            "ipfs://m491-standing"
        ) {
            revert("anti-abuse did not block downstream record");
        } catch {}
    }
}

contract AVASkeletonModulesAuthority03ATest is AVASkeletonFixture {
    function testPackageSelectedSubjectRateLimitCanRejectChallengePathWithoutChangingDefaultPackage() public {
        Actor defaultChallenger = new Actor();
        bytes32 defaultChallengerSubject = bytes32(stateMachine.nextRecognisedStateId());
        roleRegistry.assignRole(
            address(defaultChallenger),
            AVADataTypes.Role.Challenger,
            defaultChallengerSubject,
            "ipfs://default-subject-limit"
        );
        uint256 defaultStateId = _createChallengeableReviewState();
        uint256 defaultChallengeEvidenceId = defaultChallenger.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            DEFAULT_WORKFLOW,
            keccak256("default-permissive-subject-path"),
            "ipfs://default-permissive-subject-path",
            "review-quality-challenge",
            0
        );
        uint256 defaultChallengeId = defaultChallenger.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            DEFAULT_WORKFLOW,
            defaultStateId,
            defaultChallengerSubject,
            defaultChallengeEvidenceId,
            0
        );
        require(defaultChallengeId != 0, "default package stopped being permissive");

        bytes32 limitedWorkflow = keccak256("subject-rate-limit-workflow");
        _registerRulePackageWithInfrastructure(
            limitedWorkflow,
            evidencePolicyModule,
            auditAdapter,
            editorialSystemAdapter,
            fieldPolicyModule,
            new SubjectRateLimitModule(),
            "ipfs://subject-rate-limit-workflow"
        );
        Actor limitedChallenger = new Actor();
        bytes32 limitedChallengerSubject = bytes32(stateMachine.nextRecognisedStateId());
        roleRegistry.assignRole(
            address(limitedChallenger), AVADataTypes.Role.Challenger, limitedChallengerSubject, "ipfs://limited-subject"
        );
        uint256 limitedStateId = _createChallengeableReviewStateThroughPackage(
            rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, limitedWorkflow), limitedWorkflow
        );
        require(bytes32(limitedStateId) == limitedChallengerSubject, "rate-limit fixture subject/object mismatch");
        uint256 limitedChallengeEvidenceId = limitedChallenger.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            limitedWorkflow,
            keccak256("limited-subject-path"),
            "ipfs://limited-subject-path",
            "review-quality-challenge",
            0
        );
        uint256 nextChallengeId = challengeWorkflow.nextChallengeId();
        try limitedChallenger.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            limitedWorkflow,
            limitedStateId,
            limitedChallengerSubject,
            limitedChallengeEvidenceId,
            0
        ) {
            revert("subject-rate-limit workflow accepted blocked challenge path");
        } catch {}
        require(challengeWorkflow.nextChallengeId() == nextChallengeId, "blocked anti-abuse path wrote challenge");
    }

    function testRateLimitedPackageRejectsRepeatedChallengeBySameSubject() public {
        bytes32 limitedWorkflow = keccak256("subject-repeat-rate-limit-workflow");
        _registerRulePackageWithInfrastructure(
            limitedWorkflow,
            evidencePolicyModule,
            auditAdapter,
            editorialSystemAdapter,
            fieldPolicyModule,
            new SubjectRateLimitModule(),
            "ipfs://subject-repeat-rate-limit-workflow"
        );
        uint256 recognisedStateId = _createChallengeableReviewStateThroughPackage(
            rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, limitedWorkflow), limitedWorkflow
        );
        uint256 firstEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            limitedWorkflow,
            keccak256("limited-repeat-first-challenge"),
            "ipfs://limited-repeat-first-challenge",
            "review-quality-challenge",
            0
        );
        uint256 firstChallengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            limitedWorkflow,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            firstEvidenceId,
            0
        );
        require(firstChallengeId != 0, "first challenge rejected by rate-limit package");

        uint256 secondEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            limitedWorkflow,
            keccak256("limited-repeat-second-challenge"),
            "ipfs://limited-repeat-second-challenge",
            "review-quality-challenge",
            0
        );
        uint256 nextChallengeId = challengeWorkflow.nextChallengeId();
        try challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            limitedWorkflow,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            secondEvidenceId,
            0
        ) {
            revert("rate-limited package accepted repeated challenge by same subject");
        } catch {}
        require(challengeWorkflow.nextChallengeId() == nextChallengeId, "blocked repeated challenge wrote state");
    }

    function testSupportedBareRevertingChallengeRateLimitHookRejectsChallengeFiling() public {
        bytes32 workflowKey = keccak256("bare-revert-rate-limit-workflow");
        _registerRulePackageWithInfrastructure(
            workflowKey,
            evidencePolicyModule,
            auditAdapter,
            editorialSystemAdapter,
            fieldPolicyModule,
            new BareRevertingChallengeRateLimitModule(),
            "ipfs://bare-revert-rate-limit-workflow"
        );
        uint256 recognisedStateId =
            _createChallengeableReviewStateThroughPackage(rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey), workflowKey);
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            workflowKey,
            keccak256("bare-revert-rate-limit-challenge"),
            "ipfs://bare-revert-rate-limit-challenge",
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
            challengeEvidenceId,
            0
        ) {
            revert("bare-reverting supported challenge-rate hook was swallowed");
        } catch {}
        require(challengeWorkflow.nextChallengeId() == nextChallengeId, "bare-revert rate-limit veto wrote challenge");
    }
}

contract AVASkeletonModulesAuthority03BTest is AVASkeletonFixture {
    function testM491AuditAdapterBlocksWorkflowAttestationPath() public {
        bytes32 workflowKey = keccak256("m491-audit");
        _registerRulePackageWithInfrastructure(
            workflowKey,
            evidencePolicyModule,
            new RejectingAuditAdapter(),
            editorialSystemAdapter,
            fieldPolicyModule,
            antiAbuseModule,
            "ipfs://m491-audit"
        );
        uint256 rejectedEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m491-audit-evidence"),
            "ipfs://m491-audit-evidence",
            "workflow-attestation",
            0
        );
        try auditModule.recordAttestation(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVADataTypes.Action.RecordAttestation,
            bytes32(rejectedEvidenceId),
            rejectedEvidenceId,
            keccak256("m491-audit-hash"),
            keccak256("panel-authority"),
            "workflow-attestation",
            "ipfs://m491-audit"
        ) {
            revert("audit adapter did not block workflow attestation");
        } catch {}

        uint256 defaultEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("m491-default-audit-evidence"),
            "ipfs://m491-default-audit-evidence",
            "workflow-attestation",
            0
        );
        uint256 attestationId = auditModule.recordAttestation(
            AVADataTypes.Role.Panel,
            DEFAULT_WORKFLOW,
            AVADataTypes.Action.RecordAttestation,
            bytes32(defaultEvidenceId),
            defaultEvidenceId,
            keccak256("m491-default-audit-hash"),
            keccak256("panel-authority"),
            "workflow-attestation",
            "ipfs://m491-default-audit"
        );
        AVADataTypes.AttestationRecord memory attestation = auditModule.getAttestation(attestationId);
        require(attestation.id == attestationId, "audit adapter active path failed");
        require(
            attestation.targetKind == AVADataTypes.AttestationTargetKind.EvidenceReceipt, "audit target kind missing"
        );
        require(attestation.action == AVADataTypes.Action.RecordAttestation, "audit action missing");
        require(attestation.authorityRole == AVADataTypes.Role.Panel, "audit authority role missing");
        require(attestation.authorityId == keccak256("panel-authority"), "audit authority id missing");

        (bool legacyOk,) = address(auditModule)
            .call(
                abi.encodeWithSignature(
                    "recordAttestation(uint8,bytes32,uint8,bytes32,uint256,bytes32,string,string)",
                    AVADataTypes.Role.Panel,
                    DEFAULT_WORKFLOW,
                    AVADataTypes.Action.RecordAttestation,
                    keccak256("m491-removed-audit-object"),
                    defaultEvidenceId,
                    keccak256("m491-removed-audit-hash"),
                    "workflow-attestation",
                    "ipfs://m491-removed-audit"
                )
            );
        require(!legacyOk, "removed low-constraint audit entrypoint remained callable");
    }

    function testWorkflowAttestationRequiresBoundAuthoritySubject() public {
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("m415-audit-authority-evidence"),
            "ipfs://m415-audit-authority-evidence",
            "workflow-attestation",
            0
        );
        try auditModule.recordAttestation(
            AVADataTypes.Role.Panel,
            DEFAULT_WORKFLOW,
            AVADataTypes.Action.RecordAttestation,
            bytes32(evidenceId),
            evidenceId,
            keccak256("m415-audit-authority-hash"),
            EDITOR_AUTHORITY,
            "workflow-attestation",
            "ipfs://m415-audit-authority"
        ) {
            revert("audit accepted mismatched authority subject");
        } catch {}
        require(auditModule.nextAttestationId() == 1, "mismatched authority created audit record");
    }

    function testM416EvidenceAttestationUsesReceiptPackageAfterWorkflowReregistration() public {
        bytes32 workflowKey = keccak256("m416-audit-evidence");
        _registerRulePackageWithInfrastructure(
            workflowKey,
            evidencePolicyModule,
            auditAdapter,
            editorialSystemAdapter,
            fieldPolicyModule,
            antiAbuseModule,
            "ipfs://m416-audit-old"
        );
        uint256 oldPackageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).packageId;
        uint256 oldEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m416-old-audit-evidence"),
            "ipfs://m416-old-audit-evidence",
            "workflow-attestation",
            0
        );

        _registerRulePackageWithInfrastructure(
            workflowKey,
            evidencePolicyModule,
            new RejectingAuditAdapter(),
            editorialSystemAdapter,
            fieldPolicyModule,
            antiAbuseModule,
            "ipfs://m416-audit-new"
        );
        uint256 newPackageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).packageId;
        require(newPackageId != oldPackageId, "workflow package was not replaced");

        uint256 oldAttestationId = auditModule.recordAttestation(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVADataTypes.Action.RecordAttestation,
            bytes32(oldEvidenceId),
            oldEvidenceId,
            keccak256("m416-old-attestation"),
            keccak256("panel-authority"),
            "workflow-attestation",
            "ipfs://m416-old-attestation"
        );
        require(
            auditModule.getAttestation(oldAttestationId).packageId == oldPackageId, "old evidence used active package"
        );

        uint256 newEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m416-new-audit-evidence"),
            "ipfs://m416-new-audit-evidence",
            "workflow-attestation",
            0
        );
        try auditModule.recordAttestation(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVADataTypes.Action.RecordAttestation,
            bytes32(newEvidenceId),
            newEvidenceId,
            keccak256("m416-new-attestation"),
            keccak256("panel-authority"),
            "workflow-attestation",
            "ipfs://m416-new-attestation"
        ) {
            revert("new evidence did not use new rejecting package");
        } catch {}
    }
}

contract AVASkeletonModulesAuthority04ATest is AVASkeletonFixture {
    function testM416TargetBoundAttestationsUseTargetPackageAfterWorkflowReregistration() public {
        bytes32 workflowKey = keccak256("m416-audit-target");
        _registerRulePackageWithInfrastructure(
            workflowKey,
            evidencePolicyModule,
            auditAdapter,
            editorialSystemAdapter,
            fieldPolicyModule,
            antiAbuseModule,
            "ipfs://m416-target-old"
        );
        AVARulePackageRegistry.RulePackage memory oldPackage = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey);
        uint256 oldStateId = _createChallengeableReviewStateThroughPackage(oldPackage, workflowKey);
        uint256 oldStateTransitionId = stateMachine.nextRecognisedStateTransitionId() - 1;
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            workflowKey,
            keccak256("m416-target-challenge-evidence"),
            "ipfs://m416-target-challenge-evidence",
            "review-quality-challenge",
            0
        );
        uint256 challengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            workflowKey,
            oldStateId,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            0
        );
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        uint256 oldChallengeTransitionId = challengeWorkflow.nextChallengeTransitionId() - 1;

        _registerRulePackageWithInfrastructure(
            workflowKey,
            evidencePolicyModule,
            new RejectingAuditAdapter(),
            editorialSystemAdapter,
            fieldPolicyModule,
            antiAbuseModule,
            "ipfs://m416-target-new"
        );

        _assertRecognisedStateAttestation(
            auditModule.recordRecognisedStateAttestation(
                AVADataTypes.Role.Panel,
                oldStateId,
                keccak256("m416-state-audit"),
                keccak256("panel-authority"),
                "recognised-state-attestation",
                "ipfs://m416-state-audit"
            ),
            oldPackage.packageId
        );
        _assertRecognisedStateTransitionAttestation(
            auditModule.recordRecognisedStateTransitionAttestation(
                AVADataTypes.Role.Panel,
                oldStateTransitionId,
                keccak256("m416-state-transition-audit"),
                keccak256("panel-authority"),
                "recognised-state-transition-attestation",
                "ipfs://m416-state-transition-audit"
            ),
            oldStateTransitionId,
            oldPackage.packageId
        );
        _assertChallengeTransitionAttestation(
            auditModule.recordChallengeTransitionAttestation(
                AVADataTypes.Role.Panel,
                oldChallengeTransitionId,
                keccak256("m416-challenge-transition-audit"),
                keccak256("panel-authority"),
                "challenge-transition-attestation",
                "ipfs://m416-challenge-transition-audit"
            ),
            oldPackage.packageId
        );

        AVARulePackageRegistry.RulePackage memory newPackage = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey);
        uint256 newStateId = _createChallengeableReviewStateThroughPackage(newPackage, workflowKey);
        try auditModule.recordRecognisedStateAttestation(
            AVADataTypes.Role.Panel,
            newStateId,
            keccak256("m416-new-state-audit"),
            keccak256("panel-authority"),
            "recognised-state-attestation",
            "ipfs://m416-new-state-audit"
        ) {
            revert("new state did not use new rejecting package");
        } catch {}
    }

    function _assertRecognisedStateAttestation(uint256 attestationId, uint256 packageId) internal view {
        AVADataTypes.AttestationRecord memory attestation = auditModule.getAttestation(attestationId);
        require(attestation.packageId == packageId, "old state used active package");
        require(
            attestation.targetKind == AVADataTypes.AttestationTargetKind.RecognisedState,
            "recognised-state attestation target missing"
        );
        require(attestation.action == AVADataTypes.Action.RecordAttestation, "recognised-state action missing");
    }

    function _assertRecognisedStateTransitionAttestation(uint256 attestationId, uint256 transitionId, uint256 packageId)
        internal
        view
    {
        AVADataTypes.AttestationRecord memory attestation = auditModule.getAttestation(attestationId);
        require(attestation.packageId == packageId, "old recognised-state transition used active package");
        require(
            attestation.targetKind == AVADataTypes.AttestationTargetKind.RecognisedStateTransition,
            "recognised-state transition target missing"
        );
        require(
            attestation.action == stateMachine.getRecognisedStateTransition(transitionId).action,
            "recognised-state transition action missing"
        );
    }

    function _assertChallengeTransitionAttestation(uint256 attestationId, uint256 packageId) internal view {
        AVADataTypes.AttestationRecord memory attestation = auditModule.getAttestation(attestationId);
        require(attestation.packageId == packageId, "old challenge transition used active package");
        require(
            attestation.targetKind == AVADataTypes.AttestationTargetKind.ChallengeTransition,
            "challenge transition target missing"
        );
        require(attestation.action == AVADataTypes.Action.ScreenChallenge, "challenge transition action missing");
    }

    function testM491EditorialAdapterIsOptionalAndDoesNotCreatePublicationLogic() public {
        bytes32 workflowKey = keccak256("m491-editorial");
        _registerRulePackageWithInfrastructure(
            workflowKey,
            evidencePolicyModule,
            auditAdapter,
            new RejectingEditorialSystemAdapter(),
            fieldPolicyModule,
            antiAbuseModule,
            "ipfs://m491-editorial"
        );
        try stateMachine.registerManuscript(
            AVADataTypes.Role.Author,
            PEER_REVIEW_APP_ID, workflowKey,
            keccak256("m491-editorial-manuscript"),
            "ipfs://m491-editorial-manuscript",
            "editorial-system://submission-1"
        ) {
            revert("editorial adapter did not block external reference");
        } catch {}

        uint256 manuscriptId = stateMachine.registerManuscript(
            AVADataTypes.Role.Author,
            PEER_REVIEW_APP_ID, workflowKey,
            keccak256("m491-editorial-manuscript-no-ref"),
            "ipfs://m491-editorial-manuscript-no-ref",
            ""
        );
        require(stateMachine.getManuscript(manuscriptId).id == manuscriptId, "optional editorial reference failed");
        bytes32 unknownWorkflowKey = keccak256("m491-unknown-editorial-workflow");
        uint256 nextManuscriptId = stateMachine.nextManuscriptId();
        try stateMachine.registerManuscript(
            AVADataTypes.Role.Author,
            PEER_REVIEW_APP_ID, unknownWorkflowKey,
            keccak256("m491-unknown-editorial-manuscript"),
            "ipfs://m491-unknown-editorial-manuscript",
            ""
        ) {
            revert("workflow manuscript accepted unknown package");
        } catch {}
        require(stateMachine.nextManuscriptId() == nextManuscriptId, "unknown workflow created manuscript");
        _assertNoSelector(address(stateMachine), "acceptManuscript(uint256)");
        _assertNoSelector(address(stateMachine), "decideEditorialOutcome(uint256)");
        _assertNoSelector(
            address(rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).editorialSystemAdapter), "acceptManuscript(uint256)"
        );
    }

    function testM416ResidualEditorialAuthorityModuleIsReplaceableAndProceduralOnly() public {
        bytes32 workflowKey = keccak256("m416-residual-editorial");
        _registerRulePackageWithResidualAuthority(
            workflowKey,
            new RejectingResidualEditorialAuthorityModule(AVADataTypes.Action.OpenChallengeWindow),
            "ipfs://m416-residual-editorial"
        );
        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m416-residual-review-evidence"),
            "ipfs://m416-residual-review-evidence",
            "review-service-occurrence",
            0
        );
        uint256 reviewContributionId = reviewerActor.registerReviewContributionWithWorkflow(
            stateMachine, AVADataTypes.Role.Reviewer, workflowKey, manuscriptId, REVIEWER_SUBJECT, evidenceId, 0
        );
        uint256 recognisedStateId =
            stateMachine.provisionallyRecogniseReview(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);
        try stateMachine.openReviewChallengeWindow(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY) {
            revert("residual editorial authority module did not block procedure");
        } catch {}
        require(
            stateMachine.getRecognisedState(recognisedStateId).status == AVADataTypes.RecognisedStateStatus.Provisional,
            "blocked residual action mutated state"
        );

        IResidualEditorialAuthorityModule exampleModule =
            new ProceduralEditorialAuthorityModule(AVADataTypes.Action.OpenChallengeWindow);
        exampleModule.validateResidualEditorialAuthority(
            IResidualEditorialAuthorityModule.ResidualEditorialAuthorityContext({
                workflowKey: workflowKey,
                packageId: rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).packageId,
                targetPackageId: rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).packageId,
                actingRole: AVADataTypes.Role.Editor,
                action: AVADataTypes.Action.OpenChallengeWindow,
                recognisedStateId: recognisedStateId,
                challengeId: 0,
                objectId: bytes32(reviewContributionId),
                evidenceReceiptId: evidenceId,
                authorityId: EDITOR_AUTHORITY,
                decisionHash: keccak256("m416-open-window-decision"),
                actor: address(this)
            })
        );
        _assertNoSelector(address(exampleModule), "acceptManuscript(uint256)");
        _assertNoSelector(address(exampleModule), "rejectManuscript(uint256)");
        _assertNoSelector(address(exampleModule), "scoreManuscriptMerit(uint256)");
        _assertNoSelector(address(exampleModule), "grantPublicationPriority(uint256)");
    }
}

contract AVASkeletonModulesAuthority04BTest is AVASkeletonFixture {
    function testM416IllustrativeStaticAuthorityCannotSimulateApprovalThresholds() public {
        bytes32 workflowKey = keccak256("m416-illustrative-static-authority");
        IResidualEditorialAuthorityModule.ResidualEditorialAuthorityContext memory context =
            IResidualEditorialAuthorityModule.ResidualEditorialAuthorityContext({
                workflowKey: workflowKey,
                packageId: 1,
                targetPackageId: 1,
                actingRole: AVADataTypes.Role.Editor,
                action: AVADataTypes.Action.OpenChallengeWindow,
                recognisedStateId: 1,
                challengeId: 0,
                objectId: keccak256("m416-authority-object"),
                evidenceReceiptId: 1,
                authorityId: EDITOR_AUTHORITY,
                decisionHash: keccak256("m416-structured-decision"),
                actor: address(this)
            });

        IResidualEditorialAuthorityModule singleAuthority = new IllustrativeStaticAuthorityShapeModule(
            IllustrativeStaticAuthorityShapeModule.PolicyKind.SingleAuthority,
            AVADataTypes.Role.Editor,
            AVADataTypes.Action.OpenChallengeWindow,
            EDITOR_AUTHORITY,
            false
        );
        singleAuthority.validateResidualEditorialAuthority(context);

        IResidualEditorialAuthorityModule closedEmergencyGate = new IllustrativeStaticAuthorityShapeModule(
            IllustrativeStaticAuthorityShapeModule.PolicyKind.EmergencyGate,
            AVADataTypes.Role.Panel,
            AVADataTypes.Action.TransitionRecognisedState,
            keccak256("panel-authority"),
            false
        );
        context.actingRole = AVADataTypes.Role.Panel;
        context.action = AVADataTypes.Action.TransitionRecognisedState;
        context.authorityId = keccak256("panel-authority");
        try closedEmergencyGate.validateResidualEditorialAuthority(context) {
            revert("closed emergency gate accepted action");
        } catch {}

        _assertNoSelector(address(singleAuthority), "OBSERVED_APPROVAL_COUNT()");
        _assertNoSelector(address(singleAuthority), "REQUIRED_THRESHOLD()");
        _assertNoSelector(address(singleAuthority), "SUPPORTING_AUTHORITY_ID()");
        _assertNoSelector(address(singleAuthority), "acceptManuscript(uint256)");
        _assertNoSelector(address(singleAuthority), "setManuscriptMerit(uint256,uint256)");
        _assertNoSelector(address(singleAuthority), "executeSanction(uint256)");
    }

    function testM416ApprovalReceiptAuthorityRequiresThresholdAndContextBoundApprovals() public {
        Actor panelA = new Actor();
        Actor panelB = new Actor();
        bytes32 panelAId = keccak256("approval-panel-a");
        bytes32 panelBId = keccak256("approval-panel-b");
        roleRegistry.assignRole(address(panelA), AVADataTypes.Role.Panel, panelAId, "ipfs://approval-panel-a");
        roleRegistry.assignRole(address(panelB), AVADataTypes.Role.Panel, panelBId, "ipfs://approval-panel-b");
        ApprovalAuthorityContext memory context =
            _createApprovalAuthorityContext("m416-approval-threshold", 2, bytes32(0));

        try panelA.resolveChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Panel,
            context.challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            panelAId,
            "ipfs://approval-resolve-without-receipts"
        ) {
            revert("approval-backed authority accepted zero receipts");
        } catch {}

        _recordAuthorityApproval(panelA, context, AVADataTypes.Action.ResolveChallenge, context.objectId, panelAId);
        try panelA.recordAuthorityApproval(
            authorityApprovalRegistry,
            AVADataTypes.Role.Panel,
            _authorityApprovalInput(
                context,
                AVADataTypes.Action.ResolveChallenge,
                context.objectId,
                panelAId,
                uint64(block.timestamp + 7 days),
                "ipfs://duplicate-authority-approval"
            )
        ) {
            revert("duplicate approval by same subject counted twice");
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
                _approvalDecisionHash(context, AVADataTypes.Action.ResolveChallenge)
            ) == 1,
            "duplicate approval changed count"
        );

        AuthorityApprovalRegistry.ApprovalInput memory futureLifecycleApproval = _authorityApprovalInput(
            context,
            AVADataTypes.Action.ApplyRestoration,
            context.objectId,
            panelBId,
            uint64(block.timestamp + 7 days),
            "ipfs://future-lifecycle-approval"
        );
        try panelB.recordAuthorityApproval(
            authorityApprovalRegistry, AVADataTypes.Role.Panel, futureLifecycleApproval
        ) {
            revert("future lifecycle approval was accepted");
        } catch {}
        try panelA.resolveChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Panel,
            context.challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            panelAId,
            "ipfs://approval-wrong-action"
        ) {
            revert("approval-backed authority replayed wrong action");
        } catch {}

        AuthorityApprovalRegistry.ApprovalInput memory wrongObjectApproval = _authorityApprovalInput(
            context,
            AVADataTypes.Action.ResolveChallenge,
            bytes32(uint256(context.objectId) + 1),
            panelBId,
            uint64(block.timestamp + 7 days),
            "ipfs://wrong-object-approval"
        );
        try panelB.recordAuthorityApproval(authorityApprovalRegistry, AVADataTypes.Role.Panel, wrongObjectApproval) {
            revert("wrong target object approval was accepted");
        } catch {}
        try panelA.resolveChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Panel,
            context.challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            panelAId,
            "ipfs://approval-wrong-object"
        ) {
            revert("approval-backed authority replayed wrong object");
        } catch {}

        _recordAuthorityApproval(panelB, context, AVADataTypes.Action.ResolveChallenge, context.objectId, panelBId);
        panelA.resolveChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Panel,
            context.challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            panelAId,
            "ipfs://approval-resolution"
        );
        require(
            challengeWorkflow.getChallenge(context.challengeId).outcome
                == AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            "approval-backed challenge did not resolve"
        );
    }

    function testM416ApprovalReceiptAuthorityRejectsExpiredApprovalThreshold() public {
        Actor panelA = new Actor();
        bytes32 panelAId = keccak256("approval-expired-panel-a");
        roleRegistry.assignRole(address(panelA), AVADataTypes.Role.Panel, panelAId, "ipfs://approval-expired-a");
        ApprovalAuthorityContext memory context =
            _createApprovalAuthorityContext("m416-approval-expired", 1, bytes32(0));

        panelA.recordAuthorityApproval(
            authorityApprovalRegistry,
            AVADataTypes.Role.Panel,
            _authorityApprovalInput(
                context,
                AVADataTypes.Action.ResolveChallenge,
                context.objectId,
                panelAId,
                uint64(block.timestamp + 1),
                "ipfs://expired-authority-approval"
            )
        );
        vm.warp(block.timestamp + 2);
        require(
            authorityApprovalRegistry.approvalCount(
                context.workflowKey,
                context.packageId,
                AVADataTypes.Action.ResolveChallenge,
                AVADataTypes.Role.Panel,
                context.recognisedStateId,
                context.challengeId,
                context.objectId,
                _approvalDecisionHash(context, AVADataTypes.Action.ResolveChallenge)
            ) == 0,
            "expired approval still counted"
        );

        try panelA.resolveChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Panel,
            context.challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            panelAId,
            "ipfs://approval-expired-rejected"
        ) {
            revert("expired approval satisfied approval module");
        } catch {}
    }
}

contract AVASkeletonModulesAuthority05ATest is AVASkeletonFixture {
    function testM416ExpiredAuthorityApprovalCanBeRenewedWithoutDuplicateCount() public {
        Actor panelA = new Actor();
        bytes32 panelAId = keccak256("approval-renew-panel-a");
        roleRegistry.assignRole(address(panelA), AVADataTypes.Role.Panel, panelAId, "ipfs://approval-renew-a");
        ApprovalAuthorityContext memory context = _createApprovalAuthorityContext("m416-approval-renew", 1, bytes32(0));

        uint256 expiredApprovalId = panelA.recordAuthorityApproval(
            authorityApprovalRegistry,
            AVADataTypes.Role.Panel,
            _authorityApprovalInput(
                context,
                AVADataTypes.Action.ResolveChallenge,
                context.objectId,
                panelAId,
                uint64(block.timestamp + 1),
                "ipfs://approval-renew-expiring"
            )
        );
        vm.warp(block.timestamp + 2);
        require(
            !authorityApprovalRegistry.hasActiveApproval(
                context.workflowKey,
                context.packageId,
                AVADataTypes.Action.ResolveChallenge,
                AVADataTypes.Role.Panel,
                context.recognisedStateId,
                context.challengeId,
                context.objectId,
                _approvalDecisionHash(context, AVADataTypes.Action.ResolveChallenge),
                panelAId
            ),
            "expired approval remained active"
        );
        require(
            authorityApprovalRegistry.approvalCount(
                context.workflowKey,
                context.packageId,
                AVADataTypes.Action.ResolveChallenge,
                AVADataTypes.Role.Panel,
                context.recognisedStateId,
                context.challengeId,
                context.objectId,
                _approvalDecisionHash(context, AVADataTypes.Action.ResolveChallenge)
            ) == 0,
            "expired approval counted before renewal"
        );

        uint256 renewedApprovalId = panelA.recordAuthorityApproval(
            authorityApprovalRegistry,
            AVADataTypes.Role.Panel,
            _authorityApprovalInput(
                context,
                AVADataTypes.Action.ResolveChallenge,
                context.objectId,
                panelAId,
                uint64(block.timestamp + 7 days),
                "ipfs://approval-renew-active"
            )
        );
        require(renewedApprovalId != expiredApprovalId, "renewal reused receipt id");
        require(
            authorityApprovalRegistry.approvalCount(
                context.workflowKey,
                context.packageId,
                AVADataTypes.Action.ResolveChallenge,
                AVADataTypes.Role.Panel,
                context.recognisedStateId,
                context.challengeId,
                context.objectId,
                _approvalDecisionHash(context, AVADataTypes.Action.ResolveChallenge)
            ) == 1,
            "renewed approval double-counted or missing"
        );

        try panelA.recordAuthorityApproval(
            authorityApprovalRegistry,
            AVADataTypes.Role.Panel,
            _authorityApprovalInput(
                context,
                AVADataTypes.Action.ResolveChallenge,
                context.objectId,
                panelAId,
                uint64(block.timestamp + 8 days),
                "ipfs://approval-renew-duplicate-active"
            )
        ) {
            revert("active renewed approval accepted duplicate");
        } catch {}

        panelA.resolveChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Panel,
            context.challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            panelAId,
            "ipfs://approval-resolution"
        );
    }

    function testM416ApprovalReceiptAuthorityRejectsConflictExcludedSubject() public {
        Actor panelA = new Actor();
        Actor panelB = new Actor();
        bytes32 panelAId = keccak256("approval-conflict-panel-a");
        bytes32 panelBId = keccak256("approval-conflict-panel-b");
        roleRegistry.assignRole(address(panelA), AVADataTypes.Role.Panel, panelAId, "ipfs://approval-conflict-a");
        roleRegistry.assignRole(address(panelB), AVADataTypes.Role.Panel, panelBId, "ipfs://approval-conflict-b");
        ApprovalAuthorityContext memory context = _createApprovalAuthorityContext("m416-approval-conflict", 1, panelAId);

        _recordAuthorityApproval(panelA, context, AVADataTypes.Action.ResolveChallenge, context.objectId, panelAId);
        try panelA.resolveChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Panel,
            context.challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            panelAId,
            "ipfs://approval-conflict-rejected"
        ) {
            revert("conflict-excluded authority satisfied approval module");
        } catch {}

        _recordAuthorityApproval(panelB, context, AVADataTypes.Action.ResolveChallenge, context.objectId, panelBId);
        panelB.resolveChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Panel,
            context.challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            panelBId,
            "ipfs://approval-resolution"
        );
    }

    function testApprovalThresholdDoesNotCountConflictExcludedSubject() public {
        Actor excludedPanel = new Actor();
        Actor panelB = new Actor();
        Actor panelC = new Actor();
        bytes32 excludedPanelId = keccak256("approval-threshold-excluded-panel");
        bytes32 panelBId = keccak256("approval-threshold-panel-b");
        bytes32 panelCId = keccak256("approval-threshold-panel-c");
        roleRegistry.assignRole(
            address(excludedPanel), AVADataTypes.Role.Panel, excludedPanelId, "ipfs://approval-threshold-excluded"
        );
        roleRegistry.assignRole(address(panelB), AVADataTypes.Role.Panel, panelBId, "ipfs://approval-threshold-b");
        roleRegistry.assignRole(address(panelC), AVADataTypes.Role.Panel, panelCId, "ipfs://approval-threshold-c");
        ApprovalAuthorityContext memory context =
            _createApprovalAuthorityContext("approval-threshold-conflict-exclusion", 2, excludedPanelId);

        _recordAuthorityApproval(
            excludedPanel, context, AVADataTypes.Action.ResolveChallenge, context.objectId, excludedPanelId
        );
        _recordAuthorityApproval(panelB, context, AVADataTypes.Action.ResolveChallenge, context.objectId, panelBId);
        try panelB.resolveChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Panel,
            context.challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            panelBId,
            "ipfs://approval-resolution"
        ) {
            revert("conflict-excluded approval counted toward threshold");
        } catch {}

        _recordAuthorityApproval(panelC, context, AVADataTypes.Action.ResolveChallenge, context.objectId, panelCId);
        panelB.resolveChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Panel,
            context.challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            panelBId,
            "ipfs://approval-resolution"
        );
    }

    function testDecisionBoundApprovalRejectsFutureTargetsAndCannotReplayOutcomeOrReason() public {
        Actor panelA = new Actor();
        bytes32 panelAId = keccak256("decision-bound-panel-a");
        roleRegistry.assignRole(address(panelA), AVADataTypes.Role.Panel, panelAId, "ipfs://decision-bound-panel-a");
        ApprovalAuthorityContext memory context =
            _createApprovalAuthorityContext("decision-bound-approval", 1, bytes32(0));

        AuthorityApprovalRegistry.ApprovalInput memory futureChallenge = _authorityApprovalInput(
            context,
            AVADataTypes.Action.ResolveChallenge,
            context.objectId,
            panelAId,
            uint64(block.timestamp + 7 days),
            "ipfs://future-challenge-approval"
        );
        futureChallenge.challengeId = context.challengeId + 10_000;
        try panelA.recordAuthorityApproval(authorityApprovalRegistry, AVADataTypes.Role.Panel, futureChallenge) {
            revert("future challenge approval was accepted");
        } catch {}

        AuthorityApprovalRegistry.ApprovalInput memory futureState = _authorityApprovalInput(
            context,
            AVADataTypes.Action.ResolveChallenge,
            context.objectId,
            panelAId,
            uint64(block.timestamp + 7 days),
            "ipfs://future-state-approval"
        );
        futureState.recognisedStateId = stateMachine.nextRecognisedStateId() + 10_000;
        try panelA.recordAuthorityApproval(authorityApprovalRegistry, AVADataTypes.Role.Panel, futureState) {
            revert("future recognised-state approval was accepted");
        } catch {}

        _recordAuthorityApproval(panelA, context, AVADataTypes.Action.ResolveChallenge, context.objectId, panelAId);
        try panelA.resolveChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Panel,
            context.challengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            panelAId,
            "ipfs://approval-resolution"
        ) {
            revert("approval replayed across challenge outcome");
        } catch {}
        try panelA.resolveChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Panel,
            context.challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            panelAId,
            "ipfs://different-resolution-reason"
        ) {
            revert("approval replayed across resolution reason");
        } catch {}
        panelA.resolveChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Panel,
            context.challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            panelAId,
            "ipfs://approval-resolution"
        );
    }
}

contract AVASkeletonModulesAuthority05BTest is AVASkeletonFixture {
    function testFuzzNoConsequenceWithoutEligibleRecognisedState(uint8 statusSeed) public {
        AVADataTypes.RecognisedStateStatus status = _nonEligibleRecognisedStateStatus(statusSeed);
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            keccak256(abi.encode("fuzz-no-consequence", statusSeed)),
            "ipfs://fuzz-no-consequence",
            "fuzz-invariant-evidence",
            0
        );
        uint256 recognisedStateId;
        if (status != AVADataTypes.RecognisedStateStatus.None) {
            recognisedStateId = _registerRecognisedStateForStatus(status, evidenceId, "fuzz-no-consequence");
        }

        uint256 nextConsequenceId = consequenceExecutor.nextConsequenceId();
        _assertConsequenceRejectsTarget(recognisedStateId, evidenceId);
        require(consequenceExecutor.nextConsequenceId() == nextConsequenceId, "ineligible state wrote consequence");
    }

    function testFuzzVestingImpossibleWhileChallengeIsOpen(bytes32 seed) public {
        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            keccak256(abi.encode("fuzz-open-challenge-review", seed)),
            "ipfs://fuzz-open-challenge-review",
            "review-service-occurrence",
            0
        );
        uint256 reviewContributionId = reviewerActor.registerReviewContribution(
            stateMachine, AVADataTypes.Role.Reviewer, manuscriptId, REVIEWER_SUBJECT, evidenceId, 0
        );
        uint256 recognisedStateId =
            stateMachine.provisionallyRecogniseReview(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);
        stateMachine.openReviewChallengeWindow(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            DEFAULT_WORKFLOW,
            keccak256(abi.encode("fuzz-open-challenge", seed)),
            "ipfs://fuzz-open-challenge",
            "review-quality-challenge",
            0
        );
        challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            0
        );

        uint256 nextTransitionId = stateMachine.nextRecognisedStateTransitionId();
        try stateMachine.vestReviewRecognition(
            AVADataTypes.Role.Panel, reviewContributionId, keccak256("panel-authority"), "ipfs://fuzz-vesting-rejected"
        ) {
            revert("open challenge allowed vesting");
        } catch {}
        require(stateMachine.nextRecognisedStateTransitionId() == nextTransitionId, "rejected vesting wrote transition");
        require(
            stateMachine.getRecognisedState(recognisedStateId).status
                == AVADataTypes.RecognisedStateStatus.Challengeable,
            "open challenge changed recognised state"
        );
    }

    function testFuzzRecognisedStatePackageIdStaysPinnedAfterWorkflowReregistration(bytes32 seed) public {
        bytes32 workflowKey = keccak256(abi.encode("fuzz-package-pin", seed));
        _registerRulePackage(
            workflowKey, disclosurePolicyModule, allocationAdapter, consequenceAdapter, "ipfs://fuzz-package-pin-old"
        );
        AVARulePackageRegistry.RulePackage memory oldPackage = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey);
        uint256 firstTransitionId = stateMachine.nextRecognisedStateTransitionId();
        uint256 recognisedStateId = _createChallengeableReviewStateThroughPackage(oldPackage, workflowKey);
        uint256 storedPackageId = stateMachine.getRecognisedState(recognisedStateId).packageId;

        _registerRulePackage(
            workflowKey, disclosurePolicyModule, allocationAdapter, consequenceAdapter, "ipfs://fuzz-package-pin-new"
        );
        AVARulePackageRegistry.RulePackage memory activePackage = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey);

        require(activePackage.packageId != storedPackageId, "workflow did not reregister package");
        require(
            stateMachine.getRecognisedState(recognisedStateId).packageId == storedPackageId, "old state package changed"
        );
        AVADataTypes.RecognisedStateTransitionRecord memory creationTransition =
            stateMachine.getRecognisedStateTransition(firstTransitionId);
        require(creationTransition.recognisedStateId == recognisedStateId, "creation transition not found");
        require(creationTransition.packageId == storedPackageId, "old transition package changed");
    }
}

contract AVASkeletonModulesAuthority06ATest is AVASkeletonFixture {
    function testFuzzAtMostOneRecoveryTerminalSettlementPerSourceKey(uint8 terminalSeed) public {
        bytes32 workflowKey = keccak256(abi.encode("fuzz-terminal-settlement", terminalSeed));
        MockERC20 token = _m421FundedToken(100);
        (,, uint256 penaltyId,) = _createM425BoundRecoveryPenalty(workflowKey, "fuzz-terminal-source", token, 8);
        uint256 obligationId = valueSettlementExecutor.recordRepaymentObligation(
            AVADataTypes.Role.ProtocolExecutor,
            penaltyId,
            keccak256("executor-authority"),
            "ipfs://fuzz-terminal-obligation"
        );

        AVADataTypes.ValueSettlementStatus firstTerminal =
            _recordRecoveryTerminalSettlement(obligationId, terminalSeed % 4);
        uint256 terminalSettlementId = valueSettlementExecutor.recoveryTerminalSettlementIdByObligationId(obligationId);
        require(terminalSettlementId != 0, "terminal settlement missing");
        require(
            valueSettlementExecutor.recoveryTerminalStatusByObligationId(obligationId) == firstTerminal,
            "terminal status not stored"
        );

        uint256 nextSettlementId = valueSettlementExecutor.nextValueSettlementId();
        for (uint8 i = 0; i < 4; i++) {
            try this.recordRecoveryTerminalForFuzz(obligationId, i) {
                revert("second terminal settlement accepted");
            } catch {}
        }
        require(
            valueSettlementExecutor.nextValueSettlementId() == nextSettlementId, "second terminal settlement stored"
        );
        require(
            valueSettlementExecutor.recoveryTerminalSettlementIdByObligationId(obligationId) == terminalSettlementId,
            "terminal settlement id changed"
        );
        uint256 expectedSubjectBalance = terminalSeed % 4 == 3 ? 0 : 8;
        require(token.balanceOf(address(reviewerActor)) == expectedSubjectBalance, "recovery exceeded origin amount");
    }

    function testFuzzOpenChallengeCountMatchesFiledMinusClosed(uint8 challengeCountSeed) public {
        uint256 challengeCount = uint256(challengeCountSeed % 4) + 1;
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256[] memory challengeIds = new uint256[](challengeCount);

        for (uint256 i = 0; i < challengeCount; i++) {
            Actor challenger = new Actor();
            bytes32 challengerSubjectId = keccak256(abi.encode("post-audit-open-count-subject", i));
            roleRegistry.assignRole(
                address(challenger),
                AVADataTypes.Role.Challenger,
                challengerSubjectId,
                "ipfs://post-audit-open-count-challenger"
            );
            uint256 evidenceId = challenger.registerEvidenceReceipt(
                evidenceRegistry,
                AVADataTypes.Role.Challenger,
                DEFAULT_WORKFLOW,
                keccak256(abi.encode("post-audit-open-count", i)),
                "ipfs://post-audit-open-count-evidence",
                "open-count-challenge",
                0
            );
            challengeIds[i] = challenger.fileChallenge(
                challengeWorkflow,
                AVADataTypes.Role.Challenger,
                DEFAULT_WORKFLOW,
                recognisedStateId,
                challengerSubjectId,
                evidenceId,
                0
            );
        }
        require(
            stateMachine.openChallengeCountForRecognisedState(recognisedStateId) == challengeCount,
            "filed challenge count drifted"
        );

        for (uint256 i = 0; i < challengeCount; i++) {
            challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeIds[i], EDITOR_AUTHORITY);
            challengeWorkflow.resolveChallenge(
                AVADataTypes.Role.Panel,
                challengeIds[i],
                AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
                AVADataTypes.RecognisedStateStatus.Challengeable,
                keccak256("panel-authority"),
                "ipfs://post-audit-open-count-resolution"
            );
            challengeWorkflow.closeChallenge(
                AVADataTypes.Role.Panel,
                challengeIds[i],
                keccak256("panel-authority"),
                "ipfs://post-audit-open-count-closure"
            );
            require(
                stateMachine.openChallengeCountForRecognisedState(recognisedStateId) == challengeCount - i - 1,
                "closed challenge count drifted"
            );
        }
    }

    function testFuzzStaleCredentialNeverProvesAfterRevisionEvent(uint8 eventSeed) public {
        bytes32 workflowKey = keccak256(abi.encode("post-audit-stale-credential", eventSeed));
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://post-audit-stale-credential-workflow");
        (uint256 recognisedStateId, uint256 evidenceId) =
            _createM421EligibleState(workflowKey, "post-audit-stale-credential-state");
        MockERC20 token = _m421FundedToken(20);
        uint256 rewardSourceId = allocationExecutor.recordRewardValueWithExecution(
            AVADataTypes.Role.ProtocolExecutor,
            _valueContext(
                recognisedStateId,
                REVIEWER_SUBJECT,
                5,
                evidenceId,
                keccak256("executor-authority"),
                "ipfs://post-audit-stale-credential-source",
                keccak256("post-audit-stale-credential-source"),
                address(token),
                address(this),
                AVADataTypes.ValueExecutionMode.Claim
            )
        );
        uint256 computationId = _recordStandingComputationForState(
            recognisedStateId, evidenceId, "post-audit-stale-credential-computation", 42
        );
        uint256 credentialId =
            _issueM422StandingCredential(computationId, "post-audit-stale-credential", block.timestamp + 7 days);

        if (eventSeed % 3 == 0) {
            standingRegistry.recordStandingUpdate(
                AVADataTypes.Role.Panel,
                recognisedStateId,
                REVIEWER_SUBJECT,
                "review-procedure-weight",
                1,
                evidenceId,
                keccak256("panel-authority"),
                "ipfs://post-audit-stale-standing-update"
            );
        } else if (eventSeed % 3 == 1) {
            valueSettlementExecutor.settleTokenTransfer(
                AVADataTypes.Role.ProtocolExecutor,
                AVADataTypes.ExecutionSourceType.AllocationRecord,
                rewardSourceId,
                keccak256("executor-authority"),
                "ipfs://post-audit-stale-reward-settlement"
            );
        } else {
            uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
                evidenceRegistry,
                AVADataTypes.Role.Challenger,
                workflowKey,
                keccak256("post-audit-stale-challenge-evidence"),
                "ipfs://post-audit-stale-challenge-evidence",
                "stale-credential-challenge",
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
            challengeWorkflow.resolveChallenge(
                AVADataTypes.Role.Panel,
                challengeId,
                AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
                AVADataTypes.RecognisedStateStatus.Vested,
                keccak256("panel-authority"),
                "ipfs://post-audit-stale-challenge-resolution"
            );
        }

        require(!_m422CredentialProves(credentialId, 40), "stale credential remained a valid proof");
        require(!standingRegistry.isStandingComputationActive(computationId), "stale computation remained active");
    }
}
