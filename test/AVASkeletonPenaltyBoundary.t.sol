// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./helpers/AVASkeletonFixture.sol";

contract AVASkeletonPenaltyBoundary01ATest is AVASkeletonFixture {
    function testM423RepaymentSetoffWaiverAndSatisfactionKeepLosslessHistory() public {
        bytes32 workflowKey = keccak256("m423-recovery-history-workflow");
        MockERC20 token = _m421FundedToken(100);
        MockERC20 unrelatedToken = new MockERC20("Unrelated Asset", "UNA");
        unrelatedToken.mint(address(reviewerActor), 23);
        (, uint256 executionId, uint256 penaltyId,) =
            _createM425BoundRecoveryPenalty(workflowKey, "m423-recovery-source", token, 8);
        uint256 obligationId = valueSettlementExecutor.recordRepaymentObligation(
            AVADataTypes.Role.ProtocolExecutor,
            penaltyId,
            keccak256("executor-authority"),
            "ipfs://m423-repayment-obligation"
        );
        (,, uint256 setoffPenaltyId,) =
            _createM425BoundRecoveryPenalty(workflowKey, "m423-setoff-source", token, 3);
        uint256 setoffObligationId = valueSettlementExecutor.recordRepaymentObligation(
            AVADataTypes.Role.ProtocolExecutor,
            setoffPenaltyId,
            keccak256("executor-authority"),
            "ipfs://m423-setoff-obligation"
        );
        uint256 setoffId = valueSettlementExecutor.recordFuturePayoutSetoff(
            AVADataTypes.Role.ProtocolExecutor,
            setoffObligationId,
            keccak256("executor-authority"),
            "ipfs://m423-future-setoff"
        );
        (,, uint256 waiverPenaltyId,) =
            _createM425BoundRecoveryPenalty(workflowKey, "m423-waiver-source", token, 2);
        uint256 waiverObligationId = valueSettlementExecutor.recordRepaymentObligation(
            AVADataTypes.Role.ProtocolExecutor,
            waiverPenaltyId,
            keccak256("executor-authority"),
            "ipfs://m423-waiver-obligation"
        );
        uint256 waiverId = valueSettlementExecutor.recordWaiver(
            AVADataTypes.Role.ProtocolExecutor,
            waiverObligationId,
            keccak256("executor-authority"),
            "ipfs://m423-waiver"
        );
        (,, uint256 satisfactionPenaltyId,) =
            _createM425BoundRecoveryPenalty(workflowKey, "m423-satisfaction-source", token, 4);
        uint256 satisfactionObligationId = valueSettlementExecutor.recordRepaymentObligation(
            AVADataTypes.Role.ProtocolExecutor,
            satisfactionPenaltyId,
            keccak256("executor-authority"),
            "ipfs://m423-satisfaction-obligation"
        );
        uint256 satisfactionId = valueSettlementExecutor.recordSatisfaction(
            AVADataTypes.Role.ProtocolExecutor,
            satisfactionObligationId,
            keccak256("executor-authority"),
            "ipfs://m423-satisfaction"
        );

        _assertM423RecoveryHistory(
            token,
            unrelatedToken,
            executionId,
            obligationId,
            penaltyId,
            setoffId,
            waiverId,
            satisfactionId
        );
    }

    function _assertM423RecoveryHistory(
        MockERC20 token,
        MockERC20 unrelatedToken,
        uint256 executionId,
        uint256 obligationId,
        uint256 penaltyId,
        uint256 setoffId,
        uint256 waiverId,
        uint256 satisfactionId
    ) internal view {
        require(
            valueSettlementExecutor.getValueSettlement(executionId).kind
                == AVADataTypes.ValueSettlementKind.TokenTransfer,
            "execution missing"
        );
        require(
            valueSettlementExecutor.getValueSettlement(obligationId).kind
                == AVADataTypes.ValueSettlementKind.RepaymentObligation,
            "obligation missing"
        );
        require(
            valueSettlementExecutor.getValueSettlement(setoffId).status
                == AVADataTypes.ValueSettlementStatus.SetoffRecorded,
            "setoff missing"
        );
        require(
            valueSettlementExecutor.getValueSettlement(waiverId).status == AVADataTypes.ValueSettlementStatus.Waived,
            "waiver missing"
        );
        require(
            valueSettlementExecutor.getValueSettlement(satisfactionId).status
                == AVADataTypes.ValueSettlementStatus.Satisfied,
            "satisfaction missing"
        );
        AVADataTypes.ValueSettlementRecord memory obligation = valueSettlementExecutor.getValueSettlement(obligationId);
        require(obligation.originSettlementId == executionId, "obligation origin unbound");
        require(obligation.penaltyConsequenceId == penaltyId, "obligation penalty unbound");
        require(token.balanceOf(address(reviewerActor)) == 17, "record-only recovery receipts moved reward value");
        require(unrelatedToken.balanceOf(address(reviewerActor)) == 23, "recovery seized unrelated wallet asset");
    }

    function testM423PenaltyChainSeparatesValueStandingAndEligibilityEffects() public {
        Actor authorActor = new Actor();
        bytes32 authorSubject = keccak256("m423-independent-author-subject");
        roleRegistry.assignRole(
            address(authorActor), AVADataTypes.Role.Author, authorSubject, "ipfs://m423-independent-author"
        );
        (uint256 fraudStateId, uint256 fraudChallengeId, uint256 fraudEvidenceId) = _createResolvedChallengeForSubject(
            authorSubject,
            "m423-fraud-upheld",
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded
        );
        uint256 fraudPenaltyId = _recordPenaltyForChallenge(
            fraudStateId,
            fraudChallengeId,
            AVADataTypes.GovernanceFindingKind.AcademicFraud,
            authorSubject,
            fraudEvidenceId,
            keccak256("panel-authority"),
            "ipfs://m423-fraud-penalty"
        );
        uint256 fraudInputId = consequenceExecutor.recordStandingPenaltyInput(
            AVADataTypes.Role.Panel,
            fraudPenaltyId,
            "author-integrity-standing",
            -50,
            fraudEvidenceId,
            keccak256("panel-authority"),
            "ipfs://m423-fraud-standing-input"
        );

        (uint256 reviewStateId, uint256 reviewChallengeId, uint256 reviewEvidenceId) = _createResolvedChallengeForSubject(
            REVIEWER_SUBJECT,
            "m423-irresponsible-review-upheld",
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded
        );
        uint256 reviewPenaltyId = _recordPenaltyForChallenge(
            reviewStateId,
            reviewChallengeId,
            AVADataTypes.GovernanceFindingKind.IrresponsibleReview,
            REVIEWER_SUBJECT,
            reviewEvidenceId,
            keccak256("panel-authority"),
            "ipfs://m423-irresponsible-review-penalty"
        );
        uint256 reviewInputId = consequenceExecutor.recordStandingPenaltyInput(
            AVADataTypes.Role.Panel,
            reviewPenaltyId,
            "review-procedure-weight",
            -8,
            reviewEvidenceId,
            keccak256("panel-authority"),
            "ipfs://m423-review-standing-input"
        );

        uint256 maliciousChallengeId = _fileAndScreenChallenge("m423-malicious-challenge");
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            maliciousChallengeId,
            AVADataTypes.ChallengeOutcome.MaliciousOrFabricated,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://m423-malicious"
        );
        AVADataTypes.ChallengeRecord memory maliciousChallenge =
            challengeWorkflow.getChallenge(maliciousChallengeId);
        uint256 maliciousEvidenceId = maliciousChallenge.evidenceReceiptId;
        uint256 maliciousPenaltyId = _recordPenaltyForChallenge(
            maliciousChallenge.challengedRecognisedStateId,
            maliciousChallengeId,
            AVADataTypes.GovernanceFindingKind.MaliciousOrFabricatedChallenge,
            CHALLENGER_SUBJECT,
            maliciousEvidenceId,
            keccak256("panel-authority"),
            "ipfs://m423-malicious-challenge-penalty"
        );
        uint256 maliciousInputId = consequenceExecutor.recordStandingPenaltyInput(
            AVADataTypes.Role.Panel,
            maliciousPenaltyId,
            "challenge-integrity-standing",
            -30,
            maliciousEvidenceId,
            keccak256("panel-authority"),
            "ipfs://m423-malicious-standing-input"
        );
        uint256 restrictionId = consequenceExecutor.recordEligibilityRestriction(
            AVADataTypes.Role.Panel,
            maliciousPenaltyId,
            AVADataTypes.EligibilityRestrictionKind.ChallengeIntake,
            block.timestamp + 14 days,
            maliciousEvidenceId,
            keccak256("panel-authority"),
            "ipfs://m423-challenge-intake-restriction"
        );

        uint256 goodFaithChallengeId = _fileAndScreenChallenge("m423-good-faith-protected");
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            goodFaithChallengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://m423-good-faith"
        );
        AVADataTypes.ChallengeRecord memory goodFaithChallenge = challengeWorkflow.getChallenge(goodFaithChallengeId);
        try consequenceExecutor.recordPenalty(
            AVADataTypes.Role.Panel,
            AVADataTypes.PenaltyConsequenceContext({
                challengeId: goodFaithChallengeId,
                findingKind: AVADataTypes.GovernanceFindingKind.MaliciousOrFabricatedChallenge,
                originSettlementId: 0
            }),
            _valueContext(
                goodFaithChallenge.challengedRecognisedStateId,
                CHALLENGER_SUBJECT,
                1,
                goodFaithChallenge.evidenceReceiptId,
                keccak256("panel-authority"),
                "ipfs://m423-good-faith-rejected",
                keccak256("m423-good-faith-rejected"),
                address(0),
                address(0),
                AVADataTypes.ValueExecutionMode.RecordOnly
            )
        ) {
            revert("good-faith failed challenge created misconduct penalty");
        } catch {}

        _assertM423PenaltyChainRecords(
            fraudInputId, reviewInputId, maliciousInputId, restrictionId
        );
    }

    function testM121RestrictionAwareChallengeIntakeUsesActiveEligibilityRestriction() public {
        bytes32 workflowKey = keccak256("m121-restriction-aware-workflow");
        _registerRulePackageWithInfrastructure(
            workflowKey,
            evidencePolicyModule,
            auditAdapter,
            editorialSystemAdapter,
            fieldPolicyModule,
            new RestrictionAwareChallengeIntakeModule(consequenceExecutor, stateMachine),
            "ipfs://m121-restriction-aware-workflow"
        );

        uint256 restrictionId =
            _m121CreateChallengeIntakeRestriction(workflowKey, block.timestamp + 2 days, "m121-active-restriction");
        uint256 packageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).packageId;
        require(
            consequenceExecutor.activeEligibilityRestrictionId(
                packageId, CHALLENGER_SUBJECT, AVADataTypes.EligibilityRestrictionKind.ChallengeIntake
            ) == restrictionId,
            "active restriction not indexed"
        );

        _m121AssertChallengeFilingRejected(workflowKey, "m121-blocked-challenge");

        vm.warp(block.timestamp + 3 days);
        require(
            consequenceExecutor.activeEligibilityRestrictionId(
                packageId, CHALLENGER_SUBJECT, AVADataTypes.EligibilityRestrictionKind.ChallengeIntake
            ) == 0,
            "expired restriction remained active"
        );
        uint256 allowedChallengeId = _m121FileChallengeForWorkflow(workflowKey, "m121-expired-restriction-challenge");
        require(allowedChallengeId != 0, "expired restriction still blocked challenge");
    }
}
contract AVASkeletonPenaltyBoundary01BTest is AVASkeletonFixture {
    function testM121RejectedGoodFaithCannotCreateChallengeIntakeRestriction() public {
        uint256 challengeId = _fileAndScreenChallenge("m121-good-faith-restriction");
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://m121-good-faith-restriction"
        );
        AVADataTypes.ChallengeRecord memory challenge = challengeWorkflow.getChallenge(challengeId);
        uint256 nextConsequenceId = consequenceExecutor.nextConsequenceId();
        uint256 nextRestrictionId = consequenceExecutor.nextEligibilityRestrictionId();
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
                "ipfs://m121-good-faith-restriction",
                keccak256("m121-good-faith-restriction"),
                address(0),
                address(0),
                AVADataTypes.ValueExecutionMode.RecordOnly
            )
        ) {
            revert("good-faith failed challenge created misconduct penalty");
        } catch {}
        require(consequenceExecutor.nextConsequenceId() == nextConsequenceId, "good-faith penalty wrote record");
        require(consequenceExecutor.nextEligibilityRestrictionId() == nextRestrictionId, "good-faith restriction wrote record");
    }

    function testM121CredentialGatedPanelModuleUsesActiveStandingCredential() public {
        bytes32 workflowKey = keccak256("m121-credential-gated-workflow");
        _registerRulePackageWithResidualAuthority(
            workflowKey,
            new CredentialGatedPanelModule(
                standingCredentialRegistry,
                stateMachine,
                AVADataTypes.Action.ResolveChallenge,
                _m422VectorKey(),
                _m422CategoryHash(),
                40
            ),
            "ipfs://m121-credential-gated-workflow"
        );
        uint256 computationId = _createM121StandingComputationRecord(
            workflowKey, keccak256("panel-authority"), "m121-panel-standing", 45, _m422VectorKey()
        );
        standingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m422CredentialInputForComputation(computationId, block.timestamp + 7 days, "ipfs://m121-panel-credential")
        );

        uint256 challengedStateId = _createChallengeableReviewStateForWorkflow(workflowKey, "m121-gated-challenge");
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            workflowKey,
            keccak256("m121-gated-challenge-evidence"),
            "ipfs://m121-gated-challenge-evidence",
            "review-quality-challenge",
            0
        );
        uint256 challengeId = challengerActor.fileChallenge(
            challengeWorkflow,  AVADataTypes.Role.Challenger, workflowKey, challengedStateId, CHALLENGER_SUBJECT, challengeEvidenceId, 0
        );
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);

        uint256 nextStandingUpdateId = standingRegistry.nextStandingUpdateId();
        uint256 nextAllocationId = allocationExecutor.nextAllocationExecutionId();
        uint256 nextConsequenceId = consequenceExecutor.nextConsequenceId();
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://m121-gated-resolution"
        );
        require(
            challengeWorkflow.getChallenge(challengeId).outcome == AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            "credential-gated resolution failed"
        );
        require(standingRegistry.nextStandingUpdateId() == nextStandingUpdateId, "credential gate created standing update");
        require(allocationExecutor.nextAllocationExecutionId() == nextAllocationId, "credential gate created allocation");
        require(consequenceExecutor.nextConsequenceId() == nextConsequenceId, "credential gate created consequence");
    }

    function testM121CredentialGatedPanelRejectsMissingWrongPackageSubjectAndVector() public {
        (
            bytes32 workflowKey,
            CredentialGatedPanelModule module,
            IResidualEditorialAuthorityModule.ResidualEditorialAuthorityContext memory context
        ) = _m121CredentialGateFixture("m121-credential-binding", 45);
        _assertM121CredentialGateRejects(module, context, "missing credential accepted");

        uint256 wrongPackageComputationId = _createM121StandingComputationRecord(
            DEFAULT_WORKFLOW, keccak256("panel-authority"), "m121-wrong-package-credential", 48, _m422VectorKey()
        );
        standingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m422CredentialInputForComputation(
                wrongPackageComputationId, block.timestamp + 7 days, "ipfs://m121-wrong-package-credential"
            )
        );
        _assertM121CredentialGateRejects(module, context, "wrong package credential accepted");

        uint256 wrongSubjectComputationId =
            _createM121StandingComputationRecord(workflowKey, REVIEWER_SUBJECT, "m121-wrong-subject-credential", 48, _m422VectorKey());
        standingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m422CredentialInputForComputation(
                wrongSubjectComputationId, block.timestamp + 7 days, "ipfs://m121-wrong-subject-credential"
            )
        );
        _assertM121CredentialGateRejects(module, context, "wrong subject credential accepted");

        uint256 wrongVectorComputationId = _createM121StandingComputationRecord(
            workflowKey, keccak256("panel-authority"), "m121-wrong-vector-credential", 48, keccak256("m121-wrong-vector")
        );
        standingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m422CredentialInputForComputation(
                wrongVectorComputationId, block.timestamp + 7 days, "ipfs://m121-wrong-vector-credential"
            )
        );
        _assertM121CredentialGateRejects(module, context, "wrong vector credential accepted");
    }
}

contract AVASkeletonPenaltyBoundary02ATest is AVASkeletonFixture {
    function testM121CredentialGatedPanelRejectsSupersededRevokedAndExpiredCredentials() public {
        (
            bytes32 workflowKey,
            CredentialGatedPanelModule module,
            IResidualEditorialAuthorityModule.ResidualEditorialAuthorityContext memory context
        ) = _m121CredentialGateFixture("m121-credential-status", 45);
        uint256 oldComputationId = _createM121StandingComputationRecord(
            workflowKey, keccak256("panel-authority"), "m121-superseded-old", 48, _m422VectorKey()
        );
        uint256 oldCredentialId = standingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m422CredentialInputForComputation(oldComputationId, block.timestamp + 7 days, "ipfs://m121-superseded-old")
        );
        module.validateResidualEditorialAuthority(context);
        uint256 lowerReplacementComputationId = _createM121StandingComputationRecord(
            workflowKey, keccak256("panel-authority"), "m121-superseded-new", 42, _m422VectorKey()
        );
        standingCredentialRegistry.supersedeCredential(
            AVADataTypes.Role.Panel,
            oldCredentialId,
            _m422CredentialInputForComputation(
                lowerReplacementComputationId, block.timestamp + 7 days, "ipfs://m121-superseded-new"
            )
        );
        _assertM121CredentialGateRejects(module, context, "superseded stronger credential was reused");

        uint256 revokedComputationId = _createM121StandingComputationRecord(
            workflowKey, keccak256("panel-authority"), "m121-revoked-credential", 48, _m422VectorKey()
        );
        uint256 revokedCredentialId = standingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m422CredentialInputForComputation(revokedComputationId, block.timestamp + 7 days, "ipfs://m121-revoked-credential")
        );
        standingCredentialRegistry.revokeCredential(
            AVADataTypes.Role.Panel, revokedCredentialId, keccak256("panel-authority"), "ipfs://m121-revoke"
        );
        _assertM121CredentialGateRejects(module, context, "revoked credential accepted");

        uint256 expiringComputationId = _createM121StandingComputationRecord(
            workflowKey, keccak256("panel-authority"), "m121-expiring-credential", 48, _m422VectorKey()
        );
        standingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m422CredentialInputForComputation(expiringComputationId, block.timestamp + 1, "ipfs://m121-expiring-credential")
        );
        module.validateResidualEditorialAuthority(context);
        vm.warp(block.timestamp + 2);
        _assertM121CredentialGateRejects(module, context, "expired credential accepted");
    }

    function testM121CredentialGatedPanelRejectsSuspendedCredential() public {
        (
            bytes32 workflowKey,
            CredentialGatedPanelModule module,
            IResidualEditorialAuthorityModule.ResidualEditorialAuthorityContext memory context
        ) = _m121CredentialGateFixture("m121-credential-suspended", 45);
        uint256 suspendedComputationId = _createM121StandingComputationRecord(
            workflowKey, keccak256("panel-authority"), "m121-suspended-credential", 48, _m422VectorKey()
        );
        uint256 suspendedCredentialId = standingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m422CredentialInputForComputation(
                suspendedComputationId, block.timestamp + 7 days, "ipfs://m121-suspended-credential"
            )
        );
        _suspendM121CredentialBySettlement(workflowKey, suspendedCredentialId, "m121-suspended");
        _assertM121CredentialGateRejects(module, context, "suspended credential accepted");
    }

    function testM123AdministrativePriorityTokenConsumptionCannotCreateManuscriptOrPublicationPath() public {
        bytes32 workflowKey = keccak256("m123-priority-boundary-workflow");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m123-priority-boundary-workflow");
        MockPriorityToken priorityToken = new MockPriorityToken();
        priorityToken.setMinter(address(valueSettlementExecutor));

        uint256 nextManuscriptId = stateMachine.nextManuscriptId();
        uint256 mintSourceId = _createM421PrioritySource(
            workflowKey,
            "m123-priority-mint-source",
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
            "ipfs://m123-priority-mint"
        );

        uint256 consumeSourceId = _createM421PrioritySource(
            workflowKey,
            "m123-priority-consume-source",
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
            "ipfs://m123-priority-consume"
        );

        require(stateMachine.nextManuscriptId() == nextManuscriptId, "priority token path touched manuscript ids");
        require(priorityToken.balanceOf(address(reviewerActor)) == 1, "priority token balance wrong");
        _assertNoSelector(address(valueSettlementExecutor), "grantPublicationPriority(uint256)");
        _assertNoSelector(address(valueSettlementExecutor), "acceptManuscript(uint256)");
        _assertNoSelector(address(valueSettlementExecutor), "setManuscriptMerit(uint256,uint256)");
    }
}
contract AVASkeletonPenaltyBoundary02BTest is AVASkeletonFixture {
    function testM123RawReviewIdCannotTriggerStandingAllocationConsequenceOrSettlement() public {
        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            keccak256("m123-raw-review-evidence"),
            "ipfs://m123-raw-review-evidence",
            "m123-boundary-review",
            0
        );
        uint256 reviewContributionId = reviewerActor.registerReviewContribution(
            stateMachine, AVADataTypes.Role.Reviewer, manuscriptId, REVIEWER_SUBJECT, evidenceId, 0
        );

        uint256 nextStandingUpdateId = standingRegistry.nextStandingUpdateId();
        uint256 nextComputationId = standingRegistry.nextStandingComputationRecordId();
        uint256 nextAllocationId = allocationExecutor.nextAllocationExecutionId();
        uint256 nextConsequenceId = consequenceExecutor.nextConsequenceId();
        uint256 nextSettlementId = valueSettlementExecutor.nextValueSettlementId();

        _assertAllDownstreamRejectTarget(reviewContributionId, evidenceId);

        require(standingRegistry.nextStandingUpdateId() == nextStandingUpdateId, "raw review created standing update");
        require(standingRegistry.nextStandingComputationRecordId() == nextComputationId, "raw review created computation");
        require(allocationExecutor.nextAllocationExecutionId() == nextAllocationId, "raw review created allocation");
        require(consequenceExecutor.nextConsequenceId() == nextConsequenceId, "raw review created consequence");
        require(valueSettlementExecutor.nextValueSettlementId() == nextSettlementId, "raw review created settlement");
    }

    function testM123DisclosureProofUseStoresContextAndNullifierOnlyWithoutRevealSelectors() public {
        uint256 policyId = _registerDisclosurePolicy("m123-anonymous-proof-use-policy");
        bytes32 subjectCommitment = _subjectCommitmentForSecret(31);
        roleRegistry.assignRole(
            address(this), AVADataTypes.Role.Challenger, subjectCommitment, "ipfs://m123-anonymous-challenger"
        );
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 evidenceId = evidenceRegistry.registerEvidenceReceipt(
            AVADataTypes.Role.Challenger,
            PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW,
            keccak256("m123-anonymous-proof-use-evidence"),
            "ipfs://m123-anonymous-proof-use-evidence",
            "anonymous-challenge-proof",
            policyId
        );
        uint256 challengeId = challengeWorkflow.fileChallenge(
            AVADataTypes.Role.Challenger, PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW, recognisedStateId, subjectCommitment, evidenceId, policyId
        );
        bytes32 contextHash = zkProofRegistry.computeDisclosureContextHash(
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.RecordDisclosureExecution,
            bytes32(challengeId),
            AVADataTypes.Role.Challenger,
            policyId,
            subjectCommitment
        );
        uint256 proofReceiptId = zkProofRegistry.registerProof(
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.RecordDisclosureExecution,
            bytes32(challengeId),
            AVADataTypes.Role.Challenger,
            policyId,
            subjectCommitment,
            _makeSchnorrProof(contextHash, 31, 17)
        );
        ZKProofRegistry.ProofReceipt memory proofReceipt = zkProofRegistry.getProofReceipt(proofReceiptId);
        uint256 useId = disclosureAccessExecutor.recordAnonymousChallengeProofUse(
            AVADataTypes.Role.Challenger,
            challengeId,
            policyId,
            proofReceiptId,
            subjectCommitment,
            proofReceipt.nullifierHash,
            "ipfs://m123-anonymous-proof-use"
        );
        AVADataTypes.DisclosureExecutionRecord memory useRecord =
            disclosureAccessExecutor.getDisclosureExecution(useId);

        require(useRecord.kind == AVADataTypes.DisclosureExecutionKind.AnonymousChallengeUse, "wrong proof-use kind");
        require(useRecord.proofReceiptId == proofReceiptId, "proof receipt missing");
        require(useRecord.proofContextHash == proofReceipt.contextHash, "proof context missing");
        require(useRecord.nullifierHash == proofReceipt.nullifierHash, "nullifier missing");
        _assertNoSelector(address(disclosureAccessExecutor), "revealIdentity(uint256)");
        _assertNoSelector(address(disclosureAccessExecutor), "decryptEvidence(uint256)");
    }

    function testM123DirectHighImpactRecognisedStateRegistrationIsExecutableBoundaryClaim() public {
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            keccak256("m123-direct-high-status-evidence"),
            "ipfs://m123-direct-high-status-evidence",
            "m123-boundary-state",
            0
        );
        uint256 nextRecognisedStateId = stateMachine.nextRecognisedStateId();
        uint256 nextTransitionId = stateMachine.nextRecognisedStateTransitionId();

        _assertDirectHighStatusRegistrationRejected(AVADataTypes.RecognisedStateStatus.Vested, evidenceId);
        _assertDirectHighStatusRegistrationRejected(AVADataTypes.RecognisedStateStatus.Downgraded, evidenceId);
        _assertDirectHighStatusRegistrationRejected(AVADataTypes.RecognisedStateStatus.Voided, evidenceId);
        _assertDirectHighStatusRegistrationRejected(AVADataTypes.RecognisedStateStatus.Restored, evidenceId);

        require(stateMachine.nextRecognisedStateId() == nextRecognisedStateId, "direct high-status registration wrote state");
        require(stateMachine.nextRecognisedStateTransitionId() == nextTransitionId, "direct high-status wrote transition");
    }
}

contract AVASkeletonPenaltyBoundary03ATest is AVASkeletonFixture {
    function testM123ForbiddenSelectorBoundaryClaimsRemainExecutable() public {
        testNoPublicationDecisionOrManuscriptMeritSelectorsExist();
        _assertNoSelector(address(disclosureAccessExecutor), "revealEvidence(uint256)");
        _assertNoSelector(address(valueSettlementExecutor), "executeSanction(uint256)");
        _assertNoSelector(address(standingCredentialRegistry), "mintStanding(address,uint256)");
        _assertNoSelector(address(standingCredentialRegistry), "mintReputation(address,uint256)");
    }

    function testStandingPenaltyInputRequiresCompatibleChallengeLinkage() public {
        uint256 goodFaithChallengeId = _fileAndScreenChallenge("p1-good-faith-linkage");
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            goodFaithChallengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://p1-good-faith-linkage"
        );
        AVADataTypes.ChallengeRecord memory goodFaith = challengeWorkflow.getChallenge(goodFaithChallengeId);
        try consequenceExecutor.recordPenalty(
            AVADataTypes.Role.Panel,
            AVADataTypes.PenaltyConsequenceContext({
                challengeId: goodFaithChallengeId,
                findingKind: AVADataTypes.GovernanceFindingKind.MaliciousOrFabricatedChallenge,
                originSettlementId: 0
            }),
            _valueContext(
                goodFaith.challengedRecognisedStateId,
                CHALLENGER_SUBJECT,
                1,
                goodFaith.evidenceReceiptId,
                keccak256("panel-authority"),
                "ipfs://p1-good-faith-penalty",
                keccak256("p1-good-faith-penalty"),
                address(0),
                address(0),
                AVADataTypes.ValueExecutionMode.RecordOnly
            )
        ) {
            revert("good-faith failed challenge created misconduct consequence");
        } catch {}

        uint256 maliciousChallengeId = _fileAndScreenChallenge("p1-malicious-linkage");
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            maliciousChallengeId,
            AVADataTypes.ChallengeOutcome.MaliciousOrFabricated,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://p1-malicious-linkage"
        );
        AVADataTypes.ChallengeRecord memory malicious = challengeWorkflow.getChallenge(maliciousChallengeId);
        try consequenceExecutor.recordPenalty(
            AVADataTypes.Role.Panel,
            AVADataTypes.PenaltyConsequenceContext({
                challengeId: maliciousChallengeId,
                findingKind: AVADataTypes.GovernanceFindingKind.NegligentChallenge,
                originSettlementId: 0
            }),
            _valueContext(
                malicious.challengedRecognisedStateId,
                CHALLENGER_SUBJECT,
                1,
                malicious.evidenceReceiptId,
                keccak256("panel-authority"),
                "ipfs://p1-wrong-outcome-penalty",
                keccak256("p1-wrong-outcome-penalty"),
                address(0),
                address(0),
                AVADataTypes.ValueExecutionMode.RecordOnly
            )
        ) {
            revert("negligent finding accepted malicious outcome");
        } catch {}

        uint256 maliciousPenaltyId = _recordPenaltyForChallenge(
            malicious.challengedRecognisedStateId,
            maliciousChallengeId,
            AVADataTypes.GovernanceFindingKind.MaliciousOrFabricatedChallenge,
            CHALLENGER_SUBJECT,
            malicious.evidenceReceiptId,
            keccak256("panel-authority"),
            "ipfs://p1-malicious-penalty"
        );
        uint256 maliciousInputId = consequenceExecutor.recordStandingPenaltyInput(
            AVADataTypes.Role.Panel,
            maliciousPenaltyId,
            "challenge-integrity-standing",
            -5,
            malicious.evidenceReceiptId,
            keccak256("panel-authority"),
            "ipfs://p1-malicious-standing-input"
        );
        AVADataTypes.StandingPenaltyInputRecord memory maliciousInput =
            consequenceExecutor.getStandingPenaltyInput(maliciousInputId);
        require(maliciousInput.challengeId == maliciousChallengeId, "challenge link not inherited");
        require(
            maliciousInput.findingKind == AVADataTypes.GovernanceFindingKind.MaliciousOrFabricatedChallenge,
            "finding link not inherited"
        );

        uint256 negligentChallengeId = _fileAndScreenChallenge("p1-negligent-linkage");
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            negligentChallengeId,
            AVADataTypes.ChallengeOutcome.Negligent,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://p1-negligent-linkage"
        );
        AVADataTypes.ChallengeRecord memory negligent = challengeWorkflow.getChallenge(negligentChallengeId);
        uint256 negligentPenaltyId = _recordPenaltyForChallenge(
            negligent.challengedRecognisedStateId,
            negligentChallengeId,
            AVADataTypes.GovernanceFindingKind.NegligentChallenge,
            CHALLENGER_SUBJECT,
            negligent.evidenceReceiptId,
            keccak256("panel-authority"),
            "ipfs://p1-negligent-penalty"
        );
        uint256 negligentInputId = consequenceExecutor.recordStandingPenaltyInput(
            AVADataTypes.Role.Panel,
            negligentPenaltyId,
            "challenge-integrity-standing",
            -5,
            negligent.evidenceReceiptId,
            keccak256("panel-authority"),
            "ipfs://p1-negligent-penalty"
        );
        require(
            consequenceExecutor.getStandingPenaltyInput(negligentInputId).challengeOutcome
                == AVADataTypes.ChallengeOutcome.Negligent,
            "negligent outcome not recorded"
        );

        try consequenceExecutor.recordPenalty(
            AVADataTypes.Role.Panel,
            AVADataTypes.PenaltyConsequenceContext({
                challengeId: maliciousChallengeId,
                findingKind: AVADataTypes.GovernanceFindingKind.MaliciousOrFabricatedChallenge,
                originSettlementId: 0
            }),
            _valueContext(
                malicious.challengedRecognisedStateId,
                keccak256("author-subject"),
                1,
                malicious.evidenceReceiptId,
                keccak256("panel-authority"),
                "ipfs://p1-wrong-challenger-subject",
                keccak256("p1-wrong-challenger-subject"),
                address(0),
                address(0),
                AVADataTypes.ValueExecutionMode.RecordOnly
            )
        ) {
            revert("malicious finding accepted wrong challenger subject");
        } catch {}
    }

    function testNoPublicationDecisionOrManuscriptMeritSelectorsExist() public {
        _assertNoSelector(address(stateMachine), "acceptManuscript(uint256)");
        _assertNoSelector(address(stateMachine), "rejectManuscript(uint256)");
        _assertNoSelector(address(stateMachine), "setManuscriptMerit(uint256,uint256)");
        _assertNoSelector(address(stateMachine), "increaseAcceptanceProbability(uint256)");
        _assertNoSelector(address(stateMachine), "scoreManuscriptMerit(uint256)");
        _assertNoSelector(address(stateMachine), "validateScientificTruth(uint256)");
        _assertNoSelector(address(stateMachine), "executeQueue(uint256)");
        _assertNoSelector(address(stateMachine), "setReviewerLeniency(uint256,uint256)");
        _assertNoSelector(address(consequenceExecutor), "grantPublicationPriority(uint256)");
        _assertNoSelector(address(consequenceExecutor), "executeSanction(uint256)");
        _assertNoSelector(address(consequenceExecutor), "mintReward(uint256)");
        _assertNoSelector(address(consequenceExecutor), "transferPayment(uint256)");
        _assertNoSelector(address(consequenceExecutor), "payStablecoin(uint256)");
        _assertNoSelector(address(consequenceExecutor), "transferToken(uint256)");
        _assertNoSelector(address(consequenceExecutor), "executeQueue(uint256)");
        _assertNoSelector(address(consequenceExecutor), "grantServiceEntitlement(uint256)");
        _assertNoSelector(address(consequenceExecutor), "boostManuscriptScore(uint256)");
        _assertNoSelector(address(standingRegistry), "setPublicPrestige(uint256,uint256)");
        _assertNoSelector(address(standingRegistry), "grantServiceEntitlement(uint256)");
        _assertNoSelector(address(standingRegistry), "mintReward(uint256)");
        _assertNoSelector(address(standingRegistry), "transferToken(uint256)");
        _assertNoSelector(address(standingRegistry), "boostManuscriptScore(uint256)");
        _assertNoSelector(address(allocationExecutor), "grantPublicationPriority(uint256)");
        _assertNoSelector(address(allocationExecutor), "boostManuscriptScore(uint256)");
        _assertNoSelector(address(allocationExecutor), "increaseAcceptanceProbability(uint256)");
        _assertNoSelector(address(allocationExecutor), "setReviewerLeniency(uint256,uint256)");
        _assertNoSelector(address(stateMachine), "revealIdentity(uint256)");
        _assertNoSelector(address(stateMachine), "revealEvidence(uint256)");
        _assertNoSelector(address(disclosureRegistry), "revealIdentity(uint256)");
        _assertNoSelector(address(disclosureRegistry), "revealEvidence(uint256)");
        _assertNoSelector(address(disclosureRegistry), "decryptEvidence(uint256)");
        _assertNoSelector(address(evidenceRegistry), "decryptEvidence(uint256)");
        _assertNoSelector(address(evidenceRegistry), "discloseReviewerIdentity(uint256)");
        _assertNoSelector(address(evidenceRegistry), "revealIdentity(uint256)");
        _assertNoSelector(address(allocationExecutor), "transferToken(uint256)");
        _assertNoSelector(address(allocationExecutor), "payStablecoin(uint256)");
        _assertNoSelector(address(allocationExecutor), "transferStablecoin(uint256)");
        _assertNoSelector(address(allocationExecutor), "executeQueue(uint256)");
        _assertNoSelector(address(disclosurePolicyModule), "revealIdentity(uint256)");
        _assertNoSelector(address(disclosurePolicyModule), "decryptEvidence(uint256)");
        _assertNoSelector(address(disclosurePolicyModule), "discloseReviewerIdentity(uint256)");
        _assertNoSelector(address(allocationAdapter), "transferPayment(uint256)");
        _assertNoSelector(address(allocationAdapter), "grantPublicationPriority(uint256)");
        _assertNoSelector(address(allocationAdapter), "executeQueue(uint256)");
        _assertNoSelector(address(rulePackageRegistry), "acceptManuscript(uint256)");
        _assertNoSelector(address(rulePackageRegistry), "validateScientificTruth(uint256)");
        _assertNoSelector(address(attributionModule), "revealIdentity(uint256)");
        _assertNoSelector(address(verificationModule), "scoreManuscriptMerit(uint256)");
        _assertNoSelector(address(verificationModule), "validateScientificTruth(uint256)");
        _assertNoSelector(address(transitionRuleModule), "decideAcceptance(uint256)");
        _assertNoSelector(address(consequenceAdapter), "executeSanction(uint256)");
        _assertNoSelector(address(consequenceAdapter), "transferPayment(uint256)");
        _assertNoSelector(address(consequenceAdapter), "mintReward(uint256)");
        _assertNoSelector(address(rewardAdapter), "transferStablecoin(uint256)");
        _assertNoSelector(address(rewardAdapter), "transferToken(uint256)");
        _assertNoSelector(address(rewardAdapter), "payStablecoin(uint256)");
        _assertNoSelector(address(priorityAdapter), "grantPublicationPriority(uint256)");
        _assertNoSelector(address(priorityAdapter), "boostManuscriptScore(uint256)");
        _assertNoSelector(address(priorityAdapter), "setReviewerLeniency(uint256,uint256)");
        _assertNoSelector(address(priorityAdapter), "executeQueue(uint256)");
        _assertNoSelector(address(penaltyAdapter), "executeSanction(uint256)");
        _assertNoSelector(address(penaltyAdapter), "transferToken(uint256)");
        _assertNoSelector(address(restorationAdapter), "mintReward(uint256)");
        _assertNoSelector(address(restorationAdapter), "transferStablecoin(uint256)");
        _assertNoSelector(address(valueSettlementExecutor), "acceptManuscript(uint256)");
        _assertNoSelector(address(valueSettlementExecutor), "rejectManuscript(uint256)");
        _assertNoSelector(address(valueSettlementExecutor), "setManuscriptMerit(uint256,uint256)");
        _assertNoSelector(address(valueSettlementExecutor), "grantPublicationPriority(uint256)");
        _assertNoSelector(address(valueSettlementExecutor), "setReviewerLeniency(uint256,uint256)");
        _assertNoSelector(address(valueSettlementExecutor), "executeQueue(uint256)");
        _assertNoSelector(address(disclosureAccessExecutor), "revealIdentity(uint256)");
        _assertNoSelector(address(disclosureAccessExecutor), "revealEvidence(uint256)");
        _assertNoSelector(address(disclosureAccessExecutor), "decryptEvidence(uint256)");
        _assertNoSelector(address(externalOperationRegistry), "acceptManuscript(uint256)");
        _assertNoSelector(address(externalOperationRegistry), "rejectManuscript(uint256)");
        _assertNoSelector(address(externalOperationRegistry), "setManuscriptMerit(uint256,uint256)");
        _assertNoSelector(address(externalOperationRegistry), "grantPublicationPriority(uint256)");
        _assertNoSelector(address(externalOperationRegistry), "executeQueue(uint256)");
        _assertNoSelector(address(standingCredentialRegistry), "mintReward(uint256)");
        _assertNoSelector(address(standingCredentialRegistry), "transferPayment(uint256)");
        _assertNoSelector(address(standingCredentialRegistry), "mintPriorityToken(uint256)");
        _assertNoSelector(address(standingCredentialRegistry), "grantPublicationPriority(uint256)");
        _assertNoSelector(address(standingCredentialRegistry), "acceptManuscript(uint256)");
        _assertNoSelector(address(standingCredentialRegistry), "rejectManuscript(uint256)");
        _assertNoSelector(address(standingCredentialRegistry), "setManuscriptMerit(uint256,uint256)");
    }
}
