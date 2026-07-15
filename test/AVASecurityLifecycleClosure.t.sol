// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVAChallengeWorkflow} from "../src/AVAChallengeWorkflow.sol";
import "./helpers/AVASkeletonFixture.sol";

contract AVASecurityChallengePackageBindingTest is AVASkeletonFixture {
    function testRecursiveChallengeAcceptsIndependentChallengeAndTargetPackageApprovals() public {
        bytes32 targetWorkflow = keccak256("security-recursive-approval-target");
        uint256 targetPackageId = rulePackageRegistry.nextRulePackageId();
        _registerRulePackageWithResidualAuthority(
            targetWorkflow,
            new ApprovalReceiptAuthorityModule(
                authorityApprovalRegistry,
                targetPackageId,
                AVADataTypes.Role.Panel,
                AVADataTypes.Action.ResolveChallenge,
                1,
                bytes32(0)
            ),
            "ipfs://security-recursive-approval-target"
        );
        bytes32 challengeWorkflowKey = keccak256("security-recursive-approval-challenge");
        uint256 challengePackageId = rulePackageRegistry.nextRulePackageId();
        _registerRulePackageWithResidualAuthority(
            challengeWorkflowKey,
            new ApprovalReceiptAuthorityModule(
                authorityApprovalRegistry,
                challengePackageId,
                AVADataTypes.Role.Panel,
                AVADataTypes.Action.ResolveChallenge,
                1,
                bytes32(0)
            ),
            "ipfs://security-recursive-approval-challenge"
        );

        AVARulePackageRegistry.RulePackage memory targetPackage = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, targetWorkflow);
        uint256 recognisedStateId = _createChallengeableReviewStateThroughPackage(targetPackage, targetWorkflow);
        uint256 evidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            challengeWorkflowKey,
            keccak256("security-recursive-approval-evidence"),
            "ipfs://security-recursive-approval-evidence",
            "review-quality-challenge",
            0
        );
        uint256 challengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            challengeWorkflowKey,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            evidenceId,
            0
        );
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);

        string memory reasonURI = "ipfs://security-recursive-approval-resolution";
        AVADataTypes.ChallengeRecord memory challenge = challengeWorkflow.getChallenge(challengeId);
        AVADataTypes.RecognisedStateRecord memory state = stateMachine.getRecognisedState(recognisedStateId);
        bytes32 decisionHash = _computeChallengeDecisionHash(
            AVAChallengeWorkflow.ChallengeDecisionContext({
                challengeId: challengeId,
                challengePackageId: challengePackageId,
                targetPackageId: targetPackageId,
                action: AVADataTypes.Action.ResolveChallenge,
                lifecycleStatus: challenge.status,
                challengeTransitionId: challenge.lastTransitionId,
                fromStatus: state.status,
                toStatus: AVADataTypes.RecognisedStateStatus.Downgraded,
                outcome: AVADataTypes.ChallengeOutcome.Upheld,
                evidenceReceiptId: evidenceId,
                targetTransitionId: state.lastTransitionId,
                reasonHash: keccak256(bytes(reasonURI))
            })
        );
        _recordRecursiveChallengeApproval(
            targetWorkflow,
            targetPackageId,
            recognisedStateId,
            challenge,
            evidenceId,
            decisionHash,
            AVADataTypes.Action.ResolveChallenge,
            "ipfs://security-recursive-target-approval"
        );
        _recordRecursiveChallengeApproval(
            challengeWorkflowKey,
            challengePackageId,
            recognisedStateId,
            challenge,
            evidenceId,
            decisionHash,
            AVADataTypes.Action.ResolveChallenge,
            "ipfs://security-recursive-challenge-approval"
        );

        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            keccak256("panel-authority"),
            reasonURI
        );
        require(
            stateMachine.getRecognisedState(recognisedStateId).status == AVADataTypes.RecognisedStateStatus.Downgraded,
            "recursive approvals did not authorise target correction"
        );
    }

    function _recordRecursiveChallengeApproval(
        bytes32 authorityWorkflowKey,
        uint256 authorityPackageId,
        uint256 recognisedStateId,
        AVADataTypes.ChallengeRecord memory challenge,
        uint256 evidenceId,
        bytes32 decisionHash,
        AVADataTypes.Action action,
        string memory reasonURI
    ) internal {
        authorityApprovalRegistry.recordApproval(
            AVADataTypes.Role.Panel,
            AuthorityApprovalRegistry.ApprovalInput({
                workflowKey: authorityWorkflowKey,
                packageId: authorityPackageId,
                action: action,
                recognisedStateId: recognisedStateId,
                challengeId: challenge.id,
                objectId: challenge.attributedObjectId,
                authorityId: keccak256("panel-authority"),
                decisionHash: decisionHash,
                evidenceReceiptId: evidenceId,
                expiresAt: uint64(block.timestamp + 7 days),
                reasonURI: reasonURI
            })
        );
    }

    function testRecursiveChallengeCloseRequiresIndependentChallengeAndTargetPackageApprovals() public {
        bytes32 targetWorkflow = keccak256("security-recursive-close-target");
        uint256 targetPackageId = rulePackageRegistry.nextRulePackageId();
        _registerRulePackageWithResidualAuthority(
            targetWorkflow,
            new ApprovalReceiptAuthorityModule(
                authorityApprovalRegistry,
                targetPackageId,
                AVADataTypes.Role.Panel,
                AVADataTypes.Action.CloseChallenge,
                1,
                bytes32(0)
            ),
            "ipfs://security-recursive-close-target"
        );
        bytes32 challengeWorkflowKey = keccak256("security-recursive-close-challenge");
        uint256 challengePackageId = rulePackageRegistry.nextRulePackageId();
        _registerRulePackageWithResidualAuthority(
            challengeWorkflowKey,
            new ApprovalReceiptAuthorityModule(
                authorityApprovalRegistry,
                challengePackageId,
                AVADataTypes.Role.Panel,
                AVADataTypes.Action.CloseChallenge,
                1,
                bytes32(0)
            ),
            "ipfs://security-recursive-close-challenge"
        );

        AVARulePackageRegistry.RulePackage memory targetPackage = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, targetWorkflow);
        uint256 recognisedStateId = _createChallengeableReviewStateThroughPackage(targetPackage, targetWorkflow);
        uint256 evidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            challengeWorkflowKey,
            keccak256("security-recursive-close-evidence"),
            "ipfs://security-recursive-close-evidence",
            "review-quality-challenge",
            0
        );
        uint256 challengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            challengeWorkflowKey,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            evidenceId,
            0
        );
        string memory reasonURI = "ipfs://security-recursive-close-reason";
        AVADataTypes.ChallengeRecord memory challenge = challengeWorkflow.getChallenge(challengeId);
        AVADataTypes.RecognisedStateRecord memory state = stateMachine.getRecognisedState(recognisedStateId);
        bytes32 decisionHash = _computeChallengeDecisionHash(
            AVAChallengeWorkflow.ChallengeDecisionContext({
                challengeId: challengeId,
                challengePackageId: challengePackageId,
                targetPackageId: targetPackageId,
                action: AVADataTypes.Action.CloseChallenge,
                lifecycleStatus: challenge.status,
                challengeTransitionId: challenge.lastTransitionId,
                fromStatus: state.status,
                toStatus: state.status,
                outcome: AVADataTypes.ChallengeOutcome.None,
                evidenceReceiptId: evidenceId,
                targetTransitionId: state.lastTransitionId,
                reasonHash: keccak256(bytes(reasonURI))
            })
        );
        _recordRecursiveChallengeApproval(
            targetWorkflow,
            targetPackageId,
            recognisedStateId,
            challenge,
            evidenceId,
            decisionHash,
            AVADataTypes.Action.CloseChallenge,
            "ipfs://security-recursive-close-target-approval"
        );
        _recordRecursiveChallengeApproval(
            challengeWorkflowKey,
            challengePackageId,
            recognisedStateId,
            challenge,
            evidenceId,
            decisionHash,
            AVADataTypes.Action.CloseChallenge,
            "ipfs://security-recursive-close-challenge-approval"
        );

        challengeWorkflow.closeChallenge(
            AVADataTypes.Role.Panel, challengeId, keccak256("panel-authority"), reasonURI
        );
        require(
            challengeWorkflow.getChallenge(challengeId).status == AVADataTypes.ChallengeLifecycleStatus.Closed,
            "dual-package approvals did not close challenge"
        );
        require(
            stateMachine.openChallengeCountForRecognisedState(recognisedStateId) == 0,
            "dual-package close did not release open challenge count"
        );
    }

    function testChallengeFilingRejectsIncompatibleTargetPackage() public {
        bytes32 targetWorkflow = keccak256("security-compatible-target-workflow");
        bytes32 challengeWorkflowKey = keccak256("security-incompatible-challenge-workflow");
        _registerRulePackageWithFutureProofModules(
            targetWorkflow,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("security-target-compatibility"),
            false,
            "ipfs://security-compatible-target"
        );
        _registerRulePackageWithFutureProofModules(
            challengeWorkflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("security-other-compatibility"),
            false,
            "ipfs://security-incompatible-challenge"
        );

        AVARulePackageRegistry.RulePackage memory targetPackage = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, targetWorkflow);
        uint256 recognisedStateId = _createChallengeableReviewStateThroughPackage(targetPackage, targetWorkflow);
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            challengeWorkflowKey,
            keccak256("security-incompatible-challenge-evidence"),
            "ipfs://security-incompatible-challenge-evidence",
            "review-quality-challenge",
            0
        );
        uint256 nextChallengeId = challengeWorkflow.nextChallengeId();

        try challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            challengeWorkflowKey,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            0
        ) {
            revert("incompatible challenge package was filed");
        } catch {}

        require(challengeWorkflow.nextChallengeId() == nextChallengeId, "incompatible filing wrote challenge");
        require(
            stateMachine.openChallengeCountForRecognisedState(recognisedStateId) == 0,
            "incompatible filing occupied open challenge count"
        );
    }

    function testTargetResidualAuthorityCannotBeBypassedByPermissiveChallengePackage() public {
        bytes32 targetWorkflow = keccak256("security-strict-target-workflow");
        bytes32 challengeWorkflowKey = keccak256("security-permissive-challenge-workflow");
        _registerRulePackageWithResidualAuthority(
            targetWorkflow,
            new RejectingResidualEditorialAuthorityModule(AVADataTypes.Action.ResolveChallenge),
            "ipfs://security-strict-target"
        );
        _registerRulePackageWithResidualAuthority(
            challengeWorkflowKey, residualEditorialAuthorityModule, "ipfs://security-permissive-challenge"
        );

        AVARulePackageRegistry.RulePackage memory targetPackage = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, targetWorkflow);
        uint256 recognisedStateId = _createChallengeableReviewStateThroughPackage(targetPackage, targetWorkflow);
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            challengeWorkflowKey,
            keccak256("security-permissive-challenge-evidence"),
            "ipfs://security-permissive-challenge-evidence",
            "review-quality-challenge",
            0
        );
        uint256 challengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            challengeWorkflowKey,
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
            "ipfs://security-target-authority-must-veto"
        ) {
            revert("permissive challenge package bypassed target decision authority");
        } catch {}

        require(
            stateMachine.getRecognisedState(recognisedStateId).status
                == AVADataTypes.RecognisedStateStatus.Challengeable,
            "target state changed after target authority veto"
        );
    }

    function testTargetCloseAuthorityCannotBeBypassedByPermissiveChallengePackage() public {
        bytes32 targetWorkflow = keccak256("security-strict-close-target-workflow");
        bytes32 challengeWorkflowKey = keccak256("security-permissive-close-challenge-workflow");
        _registerRulePackageWithResidualAuthority(
            targetWorkflow,
            new RejectingResidualEditorialAuthorityModule(AVADataTypes.Action.CloseChallenge),
            "ipfs://security-strict-close-target"
        );
        _registerRulePackageWithResidualAuthority(
            challengeWorkflowKey, residualEditorialAuthorityModule, "ipfs://security-permissive-close-challenge"
        );

        AVARulePackageRegistry.RulePackage memory targetPackage = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, targetWorkflow);
        uint256 recognisedStateId = _createChallengeableReviewStateThroughPackage(targetPackage, targetWorkflow);
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            challengeWorkflowKey,
            keccak256("security-permissive-close-challenge-evidence"),
            "ipfs://security-permissive-close-challenge-evidence",
            "review-quality-challenge",
            0
        );
        uint256 challengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            challengeWorkflowKey,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            0
        );

        try challengeWorkflow.closeChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            keccak256("panel-authority"),
            "ipfs://security-target-close-authority-must-veto"
        ) {
            revert("permissive challenge package bypassed target close authority");
        } catch {}

        require(
            challengeWorkflow.getChallenge(challengeId).status
                == AVADataTypes.ChallengeLifecycleStatus.ConcernFiled,
            "challenge closed after target authority veto"
        );
        require(
            stateMachine.openChallengeCountForRecognisedState(recognisedStateId) == 1,
            "target close veto released open challenge count"
        );
    }
}

contract AVASecurityRecognisedStateEvidenceTest is AVASkeletonFixture {
    function testRevokedRecognisedStateEvidenceInvalidatesStandingComputationAndCredential() public {
        (uint256 recognisedStateId, uint256 sourceEvidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            DEFAULT_WORKFLOW, AVADataTypes.RecognisedStateStatus.Vested, "security-state-proof-source"
        );
        uint256 computationEvidenceId = _registerM51DefaultEvidence("security-state-proof-computation");
        uint256 computationId =
            _recordStandingComputationForState(recognisedStateId, computationEvidenceId, "security-state-proof", 42);
        uint256 credentialId =
            _issueM422StandingCredential(computationId, "security-state-proof", block.timestamp + 7 days);
        require(standingRegistry.isStandingComputationActive(computationId), "computation not active before revocation");
        require(_m422CredentialProves(credentialId, 40), "credential not active before revocation");

        _revokeStateEvidence(sourceEvidenceId, "security-state-proof-source");

        require(
            !standingRegistry.isStandingComputationActive(computationId),
            "revoked recognised-state evidence kept computation active"
        );
        require(!_m422CredentialProves(credentialId, 40), "revoked recognised-state evidence kept credential usable");
    }

    function testRevokedRecognisedStateEvidenceRejectsBoundedConsequence() public {
        (uint256 recognisedStateId, uint256 sourceEvidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            DEFAULT_WORKFLOW, AVADataTypes.RecognisedStateStatus.Vested, "security-revoked-state-consequence"
        );
        uint256 downstreamEvidenceId = _registerM51DefaultEvidence("security-active-consequence-evidence");
        _revokeStateEvidence(sourceEvidenceId, "security-revoked-state-consequence");

        try consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            AVADataTypes.ConsequenceKind.AdministrativeNote,
            REVIEWER_SUBJECT,
            downstreamEvidenceId,
            keccak256("panel-authority"),
            "ipfs://security-revoked-state-consequence"
        ) {
            revert("revoked recognised-state evidence allowed bounded consequence");
        } catch {}
        require(consequenceExecutor.nextConsequenceId() == 1, "rejected consequence wrote storage");
    }

    function testRevokedRecognisedStateEvidenceRejectsAllocation() public {
        (uint256 recognisedStateId, uint256 sourceEvidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            DEFAULT_WORKFLOW, AVADataTypes.RecognisedStateStatus.Vested, "security-revoked-state-allocation"
        );
        uint256 downstreamEvidenceId = _registerM51DefaultEvidence("security-active-allocation-evidence");
        _revokeStateEvidence(sourceEvidenceId, "security-revoked-state-allocation");

        try allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            AVADataTypes.AllocationKind.OperationalAllowance,
            REVIEWER_SUBJECT,
            1,
            downstreamEvidenceId,
            keccak256("executor-authority"),
            "ipfs://security-revoked-state-allocation"
        ) {
            revert("revoked recognised-state evidence allowed allocation");
        } catch {}
        require(allocationExecutor.nextAllocationExecutionId() == 1, "rejected allocation wrote storage");
    }

    function testRevokedRecognisedStateEvidenceRejectsStandingUpdate() public {
        (uint256 recognisedStateId, uint256 sourceEvidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            DEFAULT_WORKFLOW, AVADataTypes.RecognisedStateStatus.Vested, "security-revoked-state-standing"
        );
        uint256 downstreamEvidenceId = _registerM51DefaultEvidence("security-active-standing-evidence");
        _revokeStateEvidence(sourceEvidenceId, "security-revoked-state-standing");

        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            "procedural-weight",
            1,
            downstreamEvidenceId,
            keccak256("panel-authority"),
            "ipfs://security-revoked-state-standing"
        ) {
            revert("revoked recognised-state evidence allowed standing update");
        } catch {}
        require(standingRegistry.nextStandingUpdateId() == 1, "rejected standing update wrote storage");
    }

    function _revokeStateEvidence(uint256 evidenceId, string memory seed) internal {
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

contract AVASecurityPositiveAllocationStatusTest is AVASkeletonFixture {
    function testDowngradedRecognisedStateCannotCreateAdministrativePriorityRecord() public {
        (uint256 recognisedStateId, uint256 evidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            DEFAULT_WORKFLOW, AVADataTypes.RecognisedStateStatus.Downgraded, "security-downgraded-priority"
        );

        try allocationExecutor.recordAdministrativePriority(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://security-downgraded-priority"
        ) {
            revert("downgraded recognised state created administrative priority record");
        } catch {}
        require(allocationExecutor.nextAllocationExecutionId() == 1, "rejected priority wrote storage");
    }

    function testVoidedRecognisedStateCannotCreateRewardRecord() public {
        (uint256 recognisedStateId, uint256 evidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            DEFAULT_WORKFLOW, AVADataTypes.RecognisedStateStatus.Voided, "security-voided-reward"
        );

        try allocationExecutor.recordRewardValue(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://security-voided-reward"
        ) {
            revert("voided recognised state created reward record");
        } catch {}
        require(allocationExecutor.nextAllocationExecutionId() == 1, "rejected reward wrote storage");
    }
}

contract AVASecuritySettlementSourceLifecycleTest is AVASkeletonFixture {
    function testRevokedPenaltySourceEvidenceCannotCreateRepaymentObligation() public {
        bytes32 workflowKey = keccak256("security-recovery-source-evidence");
        MockERC20 token = _m421FundedToken(100);
        (,, uint256 penaltyId,) = _createM425BoundRecoveryPenalty(workflowKey, "security-recovery-source", token, 9);
        uint256 penaltyEvidenceId = consequenceExecutor.getConsequence(penaltyId).evidenceReceiptId;
        _revokeWorkflowEvidence(workflowKey, penaltyEvidenceId, "security-recovery-source-revoked");
        uint256 nextSettlementId = valueSettlementExecutor.nextValueSettlementId();

        try valueSettlementExecutor.recordRepaymentObligation(
            AVADataTypes.Role.ProtocolExecutor,
            penaltyId,
            keccak256("executor-authority"),
            "ipfs://security-recovery-source-rejected"
        ) {
            revert("revoked penalty evidence started repayment obligation");
        } catch {}

        require(
            valueSettlementExecutor.nextValueSettlementId() == nextSettlementId, "rejected recovery wrote obligation"
        );
    }

    function testEscrowRefundRemainsAvailableAfterSourceEvidenceRevocation() public {
        bytes32 workflowKey = keccak256("security-escrow-refund-after-revocation");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://security-escrow-refund-workflow");
        MockERC20 token = _m421FundedToken(100);
        uint256 sourceId = _createM421RewardSource(
            workflowKey, "security-escrow-refund-source", token, 9, AVADataTypes.ValueExecutionMode.Escrow
        );
        valueSettlementExecutor.depositEscrow(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://security-escrow-deposit"
        );
        uint256 sourceEvidenceId = allocationExecutor.getAllocationExecution(sourceId).evidenceReceiptId;
        _revokeWorkflowEvidence(workflowKey, sourceEvidenceId, "security-escrow-source-revoked");

        uint256 refundId = valueSettlementExecutor.refundEscrow(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://security-escrow-refund"
        );

        require(refundId != 0, "escrow refund missing");
        require(token.balanceOf(address(this)) == 100, "escrow refund did not return payer funds");
    }

    function testEscrowRefundRemainsAvailableAfterRecipientSubjectDeactivation() public {
        bytes32 workflowKey = keccak256("security-escrow-refund-after-subject-deactivation");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://security-escrow-refund-subject-workflow");
        MockERC20 token = _m421FundedToken(100);
        uint256 sourceId = _createM421RewardSource(
            workflowKey, "security-escrow-refund-subject-source", token, 9, AVADataTypes.ValueExecutionMode.Escrow
        );
        valueSettlementExecutor.depositEscrow(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://security-escrow-subject-deposit"
        );
        roleRegistry.deactivateSubject(REVIEWER_SUBJECT);

        uint256 refundId = valueSettlementExecutor.refundEscrow(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://security-escrow-subject-refund"
        );

        require(refundId != 0, "escrow refund missing");
        require(token.balanceOf(address(this)) == 100, "escrow refund did not return payer funds");
        require(token.balanceOf(address(valueSettlementExecutor)) == 0, "executor retained refunded escrow");
        require(!roleRegistry.getSubject(REVIEWER_SUBJECT).active, "refund reactivated subject");
    }

    function testRewardSourceCannotSettleAfterRecognisedStateIsVoided() public {
        bytes32 workflowKey = keccak256("security-settlement-voided-state");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://security-settlement-voided-workflow");
        MockERC20 token = _m421FundedToken(100);
        uint256 sourceId = _createM421RewardSource(
            workflowKey, "security-settlement-before-void", token, 9, AVADataTypes.ValueExecutionMode.Claim
        );
        uint256 recognisedStateId = allocationExecutor.getAllocationExecution(sourceId).recognisedStateId;
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            workflowKey,
            keccak256("security-settlement-void-challenge"),
            "ipfs://security-settlement-void-challenge",
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
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Voided,
            keccak256("panel-authority"),
            "ipfs://security-settlement-void-resolution"
        );

        try valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://security-settlement-post-void"
        ) {
            revert("voided recognised-state reward source settled token transfer");
        } catch {}
        require(token.balanceOf(address(reviewerActor)) == 0, "post-void settlement moved token");
        require(valueSettlementExecutor.nextValueSettlementId() == 1, "post-void settlement wrote receipt");
    }

    function testRevokedAllocationSourceEvidenceCannotSettleTokenTransfer() public {
        bytes32 workflowKey = keccak256("security-settlement-source-evidence");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://security-settlement-source-workflow");
        MockERC20 token = _m421FundedToken(100);
        (uint256 recognisedStateId,) = _createM421EligibleState(workflowKey, "security-settlement-state");
        uint256 sourceEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("security-settlement-source-evidence"),
            "ipfs://security-settlement-source-evidence",
            "reward-execution-source",
            0
        );
        AVADataTypes.ValueExecutionContext memory context = AVADataTypes.ValueExecutionContext({
            recognisedStateId: recognisedStateId,
            asset: address(token),
            payer: address(this),
            recipientSubjectId: REVIEWER_SUBJECT,
            amount: 7,
            mode: AVADataTypes.ValueExecutionMode.Claim,
            settlementKind: AVADataTypes.ValueSettlementKind.TokenTransfer,
            executionReference: bytes32(sourceEvidenceId),
            authorityId: keccak256("executor-authority"),
            evidenceReceiptId: sourceEvidenceId,
            uri: "ipfs://security-settlement-source",
            actor: address(this)
        });
        uint256 sourceId =
            allocationExecutor.recordRewardValueWithExecution(AVADataTypes.Role.ProtocolExecutor, context);
        _revokeWorkflowEvidence(workflowKey, sourceEvidenceId, "security-settlement-source-revoked");

        try valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://security-settlement-rejected"
        ) {
            revert("revoked allocation source evidence settled token transfer");
        } catch {}
        require(token.balanceOf(address(reviewerActor)) == 0, "rejected settlement moved token");
        require(valueSettlementExecutor.nextValueSettlementId() == 1, "rejected settlement wrote receipt");
    }

    function _revokeWorkflowEvidence(bytes32 workflowKey, uint256 evidenceId, string memory seed) internal {
        authorityMatrix.setPermission(AVADataTypes.Role.Panel, AVADataTypes.Action.RecordEvidenceLifecycle, true);
        evidenceRegistry.recordEvidenceLifecycleHook(
            AVADataTypes.Role.Panel,
            PEER_REVIEW_APP_ID, workflowKey,
            evidenceId,
            AVADataTypes.EvidenceLifecycleKind.RevocationReady,
            0,
            keccak256(bytes(seed)),
            string.concat("ipfs://", seed)
        );
    }
}

contract AVASecurityPreResolutionChallengeClosureTest is AVASkeletonFixture {
    function testCloseApprovalCannotReplayAcrossChallengeLifecycleVersion() public {
        bytes32 workflowKey = keccak256("security-close-lifecycle-version");
        uint256 packageId = rulePackageRegistry.nextRulePackageId();
        _registerRulePackageWithResidualAuthority(
            workflowKey,
            new ApprovalReceiptAuthorityModule(
                authorityApprovalRegistry,
                packageId,
                AVADataTypes.Role.Panel,
                AVADataTypes.Action.CloseChallenge,
                1,
                bytes32(0)
            ),
            "ipfs://security-close-lifecycle-version"
        );
        AVARulePackageRegistry.RulePackage memory rulePackage = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey);
        uint256 recognisedStateId = _createChallengeableReviewStateThroughPackage(rulePackage, workflowKey);
        uint256 evidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            workflowKey,
            keccak256("security-close-lifecycle-version-evidence"),
            "ipfs://security-close-lifecycle-version-evidence",
            "review-quality-challenge",
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

        string memory reasonURI = "ipfs://security-close-lifecycle-version-reason";
        AVADataTypes.ChallengeRecord memory challenge = challengeWorkflow.getChallenge(challengeId);
        AVADataTypes.RecognisedStateRecord memory state = stateMachine.getRecognisedState(recognisedStateId);
        bytes32 filedDecisionHash = _computeChallengeDecisionHash(
            AVAChallengeWorkflow.ChallengeDecisionContext({
                challengeId: challengeId,
                challengePackageId: challenge.packageId,
                targetPackageId: challenge.targetPackageId,
                action: AVADataTypes.Action.CloseChallenge,
                lifecycleStatus: challenge.status,
                challengeTransitionId: challenge.lastTransitionId,
                fromStatus: state.status,
                toStatus: state.status,
                outcome: AVADataTypes.ChallengeOutcome.None,
                evidenceReceiptId: evidenceId,
                targetTransitionId: state.lastTransitionId,
                reasonHash: keccak256(bytes(reasonURI))
            })
        );
        authorityApprovalRegistry.recordApproval(
            AVADataTypes.Role.Panel,
            AuthorityApprovalRegistry.ApprovalInput({
                workflowKey: workflowKey,
                packageId: packageId,
                action: AVADataTypes.Action.CloseChallenge,
                recognisedStateId: recognisedStateId,
                challengeId: challengeId,
                objectId: challenge.attributedObjectId,
                authorityId: keccak256("panel-authority"),
                decisionHash: filedDecisionHash,
                evidenceReceiptId: evidenceId,
                expiresAt: uint64(block.timestamp + 7 days),
                reasonURI: "ipfs://security-close-lifecycle-version-approval"
            })
        );

        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        try challengeWorkflow.closeChallenge(
            AVADataTypes.Role.Panel, challengeId, keccak256("panel-authority"), reasonURI
        ) {
            revert("filed lifecycle approval closed screened challenge");
        } catch {}

        require(
            challengeWorkflow.getChallenge(challengeId).status
                == AVADataTypes.ChallengeLifecycleStatus.AdmissibilityScreening,
            "stale close approval changed challenge lifecycle"
        );
        require(
            stateMachine.openChallengeCountForRecognisedState(recognisedStateId) == 1,
            "stale close approval released open challenge count"
        );

        challenge = challengeWorkflow.getChallenge(challengeId);
        bytes32 screenedDecisionHash = _computeChallengeDecisionHash(
            AVAChallengeWorkflow.ChallengeDecisionContext({
                challengeId: challengeId,
                challengePackageId: challenge.packageId,
                targetPackageId: challenge.targetPackageId,
                action: AVADataTypes.Action.CloseChallenge,
                lifecycleStatus: challenge.status,
                challengeTransitionId: challenge.lastTransitionId,
                fromStatus: state.status,
                toStatus: state.status,
                outcome: AVADataTypes.ChallengeOutcome.None,
                evidenceReceiptId: evidenceId,
                targetTransitionId: state.lastTransitionId,
                reasonHash: keccak256(bytes(reasonURI))
            })
        );
        authorityApprovalRegistry.recordApproval(
            AVADataTypes.Role.Panel,
            AuthorityApprovalRegistry.ApprovalInput({
                workflowKey: workflowKey,
                packageId: packageId,
                action: AVADataTypes.Action.CloseChallenge,
                recognisedStateId: recognisedStateId,
                challengeId: challengeId,
                objectId: challenge.attributedObjectId,
                authorityId: keccak256("panel-authority"),
                decisionHash: screenedDecisionHash,
                evidenceReceiptId: evidenceId,
                expiresAt: uint64(block.timestamp + 7 days),
                reasonURI: "ipfs://security-close-screened-version-approval"
            })
        );
        challengeWorkflow.closeChallenge(
            AVADataTypes.Role.Panel, challengeId, keccak256("panel-authority"), reasonURI
        );
        require(
            challengeWorkflow.getChallenge(challengeId).status == AVADataTypes.ChallengeLifecycleStatus.Closed,
            "fresh screened approval did not close challenge"
        );
        require(
            stateMachine.openChallengeCountForRecognisedState(recognisedStateId) == 0,
            "fresh screened approval did not release open challenge count"
        );
    }

    function testApprovalBackedPanelCanCloseFiledChallengeAfterEvidenceRevocation() public {
        bytes32 workflowKey = keccak256("security-approval-backed-pre-resolution-close");
        uint256 packageId = rulePackageRegistry.nextRulePackageId();
        _registerRulePackageWithResidualAuthority(
            workflowKey,
            new ApprovalReceiptAuthorityModule(
                authorityApprovalRegistry,
                packageId,
                AVADataTypes.Role.Panel,
                AVADataTypes.Action.CloseChallenge,
                1,
                bytes32(0)
            ),
            "ipfs://security-approval-backed-pre-resolution-close"
        );
        AVARulePackageRegistry.RulePackage memory rulePackage = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey);
        uint256 recognisedStateId = _createChallengeableReviewStateThroughPackage(rulePackage, workflowKey);
        uint256 evidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            workflowKey,
            keccak256("security-approval-backed-pre-resolution-close-evidence"),
            "ipfs://security-approval-backed-pre-resolution-close-evidence",
            "review-quality-challenge",
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
        _revokeChallengeEvidenceForWorkflow(
            workflowKey, evidenceId, "security-approval-backed-pre-resolution-close-revoked"
        );

        string memory reasonURI = "ipfs://security-approval-backed-administrative-close";
        AVADataTypes.ChallengeRecord memory challenge = challengeWorkflow.getChallenge(challengeId);
        AVADataTypes.RecognisedStateRecord memory state = stateMachine.getRecognisedState(recognisedStateId);
        bytes32 decisionHash = _computeChallengeDecisionHash(
            AVAChallengeWorkflow.ChallengeDecisionContext({
                challengeId: challengeId,
                challengePackageId: challenge.packageId,
                targetPackageId: challenge.targetPackageId,
                action: AVADataTypes.Action.CloseChallenge,
                lifecycleStatus: challenge.status,
                challengeTransitionId: challenge.lastTransitionId,
                fromStatus: state.status,
                toStatus: state.status,
                outcome: AVADataTypes.ChallengeOutcome.None,
                evidenceReceiptId: evidenceId,
                targetTransitionId: state.lastTransitionId,
                reasonHash: keccak256(bytes(reasonURI))
            })
        );
        authorityApprovalRegistry.recordApproval(
            AVADataTypes.Role.Panel,
            AuthorityApprovalRegistry.ApprovalInput({
                workflowKey: workflowKey,
                packageId: packageId,
                action: AVADataTypes.Action.CloseChallenge,
                recognisedStateId: recognisedStateId,
                challengeId: challengeId,
                objectId: challenge.attributedObjectId,
                authorityId: keccak256("panel-authority"),
                decisionHash: decisionHash,
                evidenceReceiptId: evidenceId,
                expiresAt: uint64(block.timestamp + 7 days),
                reasonURI: "ipfs://security-approval-backed-close-approval"
            })
        );

        challengeWorkflow.closeChallenge(AVADataTypes.Role.Panel, challengeId, keccak256("panel-authority"), reasonURI);

        require(
            challengeWorkflow.getChallenge(challengeId).status == AVADataTypes.ChallengeLifecycleStatus.Closed,
            "approval-backed administrative close failed"
        );
        require(stateMachine.openChallengeCountForRecognisedState(recognisedStateId) == 0, "open count not released");
    }

    function testAuthorisedPanelCanCloseScreenedChallengeAfterEvidenceRevocation() public {
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 evidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256("security-screened-close"),
            "ipfs://security-screened-close",
            "review-quality-challenge",
            0
        );
        uint256 challengeId = challengerActor.fileChallenge(
            challengeWorkflow, AVADataTypes.Role.Challenger, recognisedStateId, CHALLENGER_SUBJECT, evidenceId, 0
        );
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        _revokeChallengeEvidence(evidenceId, "security-screened-close-revoked");

        challengeWorkflow.closeChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            keccak256("panel-authority"),
            "ipfs://security-screened-administrative-close"
        );

        AVADataTypes.ChallengeRecord memory challenge = challengeWorkflow.getChallenge(challengeId);
        require(challenge.status == AVADataTypes.ChallengeLifecycleStatus.Closed, "screened challenge not closed");
        require(challenge.outcome == AVADataTypes.ChallengeOutcome.None, "screened close created outcome");
        require(stateMachine.openChallengeCountForRecognisedState(recognisedStateId) == 0, "screened cap not released");
    }

    function testAuthorisedPanelCanCloseFiledChallengeAfterEvidenceRevocation() public {
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 evidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256("security-pre-resolution-close"),
            "ipfs://security-pre-resolution-close",
            "review-quality-challenge",
            0
        );
        uint256 challengeId = challengerActor.fileChallenge(
            challengeWorkflow, AVADataTypes.Role.Challenger, recognisedStateId, CHALLENGER_SUBJECT, evidenceId, 0
        );
        AVADataTypes.RecognisedStateRecord memory stateBefore = stateMachine.getRecognisedState(recognisedStateId);
        _revokeChallengeEvidence(evidenceId, "security-pre-resolution-close-revoked");

        challengeWorkflow.closeChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            keccak256("panel-authority"),
            "ipfs://security-pre-resolution-administrative-close"
        );

        AVADataTypes.ChallengeRecord memory challenge = challengeWorkflow.getChallenge(challengeId);
        AVADataTypes.ChallengeTransitionRecord memory transition =
            challengeWorkflow.getChallengeTransition(challenge.lastTransitionId);
        AVADataTypes.RecognisedStateRecord memory stateAfter = stateMachine.getRecognisedState(recognisedStateId);
        require(challenge.status == AVADataTypes.ChallengeLifecycleStatus.Closed, "challenge not closed");
        require(challenge.outcome == AVADataTypes.ChallengeOutcome.None, "administrative close created outcome");
        require(
            transition.transitionKind == AVADataTypes.ChallengeTransitionKind.Closed,
            "administrative close transition missing"
        );
        require(transition.outcome == AVADataTypes.ChallengeOutcome.None, "close transition created outcome");
        require(stateAfter.status == stateBefore.status, "administrative close changed recognised state");
        require(stateAfter.lastTransitionId == stateBefore.lastTransitionId, "administrative close wrote state ledger");
        require(stateMachine.openChallengeCountForRecognisedState(recognisedStateId) == 0, "open count not released");
    }

    function _revokeChallengeEvidence(uint256 evidenceId, string memory seed) internal {
        _revokeChallengeEvidenceForWorkflow(DEFAULT_WORKFLOW, evidenceId, seed);
    }

    function _revokeChallengeEvidenceForWorkflow(bytes32 workflowKey, uint256 evidenceId, string memory seed) internal {
        authorityMatrix.setPermission(AVADataTypes.Role.Panel, AVADataTypes.Action.RecordEvidenceLifecycle, true);
        evidenceRegistry.recordEvidenceLifecycleHook(
            AVADataTypes.Role.Panel,
            PEER_REVIEW_APP_ID, workflowKey,
            evidenceId,
            AVADataTypes.EvidenceLifecycleKind.RevocationReady,
            0,
            keccak256(bytes(seed)),
            string.concat("ipfs://", seed)
        );
    }
}

contract AVASecurityCanonicalStandingCredentialTest is AVASkeletonFixture {
    function testRevokedCanonicalCredentialCanBeReissuedWithoutReactivatingOldCarrier() public {
        uint256 computationId = _createM422StandingComputationRecord("security-reissue-credential", 42);
        uint256 firstCredentialId =
            _issueM422StandingCredential(computationId, "security-reissue-first", block.timestamp + 7 days);
        standingCredentialRegistry.revokeCredential(
            AVADataTypes.Role.Panel, firstCredentialId, keccak256("panel-authority"), "ipfs://security-reissue-revoke"
        );

        uint256 replacementId =
            _issueM422StandingCredential(computationId, "security-reissue-replacement", block.timestamp + 7 days);
        AVADataTypes.StandingCredentialRecord memory replacement =
            standingCredentialRegistry.getStandingCredential(replacementId);
        require(!_m422CredentialProves(firstCredentialId, 40), "revoked old credential proved");
        require(_m422CredentialProves(replacementId, 40), "replacement credential did not prove");
        require(
            standingCredentialRegistry.activeStandingCredentialId(
                replacement.packageId, replacement.subjectId, replacement.vectorKey, replacement.categoryHash
            ) == replacementId,
            "replacement is not canonical"
        );
    }

    function testSecondDirectCredentialIssueForActiveKeyRequiresSupersession() public {
        uint256 computationId = _createM422StandingComputationRecord("security-canonical-credential", 42);
        uint256 firstCredentialId =
            _issueM422StandingCredential(computationId, "security-canonical-first", block.timestamp + 7 days);
        uint256 nextCredentialId = standingCredentialRegistry.nextStandingCredentialId();

        try standingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m422CredentialInputForComputation(
                computationId, block.timestamp + 7 days, "ipfs://security-canonical-duplicate"
            )
        ) {
            revert("second direct credential issuance bypassed supersession");
        } catch {}

        AVADataTypes.StandingCredentialRecord memory first =
            standingCredentialRegistry.getStandingCredential(firstCredentialId);
        require(first.status == AVADataTypes.StandingCredentialStatus.Active, "first credential changed");
        require(_m422CredentialProves(firstCredentialId, 40), "canonical credential stopped proving");
        require(
            standingCredentialRegistry.nextStandingCredentialId() == nextCredentialId,
            "rejected duplicate issuance wrote storage"
        );
    }
}
