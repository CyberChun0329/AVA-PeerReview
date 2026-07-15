// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVASkeletonFixture, MutableIdentityAntiAbuseModule} from "./helpers/AVASkeletonFixture.sol";
import {AVADataTypes} from "../src/AVADataTypes.sol";
import {AVARulePackageRegistry} from "../src/AVARulePackageRegistry.sol";
import {MockERC20} from "../src/MockERC20.sol";
import {IValueExecutionAdapter} from "../src/interfaces/IValueExecutionAdapter.sol";
import {
    ClaimEscrowRecordValueAdapter,
    RejectingEvidenceLifecycleModule
} from "../src/modules/ExampleFutureProofModules.sol";
import {MockERC20RecoveryValueExecutionAdapter} from "../src/modules/DefaultFutureProofModules.sol";

contract AVASecurityEvidenceUseClosureTest is AVASkeletonFixture {
    function testPackageEvidenceLifecycleCanVetoStandingUpdate() public {
        bytes32 workflowKey = keccak256("security-evidence-lifecycle-standing");
        _registerWorkflowWithEvidenceLifecycle(
            workflowKey,
            new RejectingEvidenceLifecycleModule(AVADataTypes.Action.RecordStandingUpdate),
            valueExecutionAdapter
        );
        (uint256 recognisedStateId, uint256 evidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, "security-evidence-lifecycle-standing"
        );

        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            "review-quality",
            1,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://security-evidence-lifecycle-standing"
        ) {
            revert("package evidence lifecycle standing veto was bypassed");
        } catch Error(string memory reason) {
            require(
                keccak256(bytes(reason)) != keccak256("package evidence lifecycle standing veto was bypassed"), reason
            );
        } catch {}
    }

    function testPackageEvidenceLifecycleCanVetoAllocationUse() public {
        bytes32 workflowKey = keccak256("security-evidence-lifecycle-allocation");
        _registerWorkflowWithEvidenceLifecycle(
            workflowKey,
            new RejectingEvidenceLifecycleModule(AVADataTypes.Action.ExecuteAllocation),
            valueExecutionAdapter
        );
        (uint256 recognisedStateId, uint256 evidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, "security-evidence-lifecycle-allocation"
        );

        try allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            AVADataTypes.AllocationKind.OperationalAllowance,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://security-evidence-lifecycle-allocation"
        ) {
            revert("package evidence lifecycle allocation veto was bypassed");
        } catch Error(string memory reason) {
            require(
                keccak256(bytes(reason)) != keccak256("package evidence lifecycle allocation veto was bypassed"), reason
            );
        } catch {}
    }

    function testPackageEvidenceLifecycleCanVetoConsequenceUse() public {
        bytes32 workflowKey = keccak256("security-evidence-lifecycle-consequence");
        _registerWorkflowWithEvidenceLifecycle(
            workflowKey,
            new RejectingEvidenceLifecycleModule(AVADataTypes.Action.RegisterConsequence),
            valueExecutionAdapter
        );
        (uint256 recognisedStateId, uint256 evidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, "security-evidence-lifecycle-consequence"
        );

        try consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            AVADataTypes.ConsequenceKind.AdministrativeNote,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://security-evidence-lifecycle-consequence"
        ) {
            revert("package evidence lifecycle consequence veto was bypassed");
        } catch Error(string memory reason) {
            require(
                keccak256(bytes(reason)) != keccak256("package evidence lifecycle consequence veto was bypassed"),
                reason
            );
        } catch {}
    }

    function testPackageEvidenceLifecycleCanVetoValueSettlementUse() public {
        bytes32 workflowKey = keccak256("security-evidence-lifecycle-settlement");
        _registerWorkflowWithEvidenceLifecycle(
            workflowKey,
            new RejectingEvidenceLifecycleModule(AVADataTypes.Action.ExecuteValueSettlement),
            new ClaimEscrowRecordValueAdapter()
        );
        MockERC20 token = _m421FundedToken(100);
        uint256 sourceId = _createM421RewardSource(
            workflowKey, "security-evidence-lifecycle-settlement", token, 9, AVADataTypes.ValueExecutionMode.Claim
        );

        try valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://security-evidence-lifecycle-settlement"
        ) {
            revert("package evidence lifecycle settlement veto was bypassed");
        } catch Error(string memory reason) {
            require(
                keccak256(bytes(reason)) != keccak256("package evidence lifecycle settlement veto was bypassed"), reason
            );
        } catch {}
    }

    function testValueSettlementFailsClosedAfterPackageIdentityDrift() public {
        bytes32 workflowKey = keccak256("security-settlement-package-identity-drift");
        MutableIdentityAntiAbuseModule mutableModule =
            new MutableIdentityAntiAbuseModule(AVADataTypes.Action.FileChallenge);
        AVARulePackageRegistry.RulePackageModules memory modules = _defaultRulePackageModules();
        modules.antiAbuseModule = mutableModule;
        modules.valueExecutionAdapter = new ClaimEscrowRecordValueAdapter();
        modules.compatibilityKey = keccak256("ava-m4-21-compatible");
        uint256 packageId = rulePackageRegistry.registerRulePackage(
            AVADataTypes.Role.Panel, PEER_REVIEW_APP_ID, workflowKey, modules, "ipfs://security-settlement-package-identity-drift"
        );
        MockERC20 token = _m421FundedToken(100);
        uint256 sourceId = _createM421RewardSource(
            workflowKey, "security-settlement-package-identity-drift", token, 9, AVADataTypes.ValueExecutionMode.Claim
        );

        mutableModule.setBlockedAction(AVADataTypes.Action.ResolveChallenge);
        try rulePackageRegistry.getRulePackageById(packageId) {
            revert("package identity drift was not detected");
        } catch {}

        try valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://security-settlement-package-identity-drift"
        ) {
            revert("settlement executed from an identity-invalid package");
        } catch Error(string memory reason) {
            require(
                keccak256(bytes(reason)) != keccak256("settlement executed from an identity-invalid package"), reason
            );
        } catch {}
    }

    function testEscrowRefundRemainsAvailableAfterPackageIdentityDrift() public {
        bytes32 workflowKey = keccak256("security-refund-package-identity-drift");
        MutableIdentityAntiAbuseModule mutableModule =
            new MutableIdentityAntiAbuseModule(AVADataTypes.Action.FileChallenge);
        AVARulePackageRegistry.RulePackageModules memory modules = _defaultRulePackageModules();
        modules.antiAbuseModule = mutableModule;
        modules.valueExecutionAdapter = new ClaimEscrowRecordValueAdapter();
        modules.compatibilityKey = keccak256("ava-m4-21-compatible");
        rulePackageRegistry.registerRulePackage(
            AVADataTypes.Role.Panel, PEER_REVIEW_APP_ID, workflowKey, modules, "ipfs://security-refund-package-identity-drift"
        );
        MockERC20 token = _m421FundedToken(100);
        uint256 sourceId = _createM421RewardSource(
            workflowKey, "security-refund-package-identity-drift", token, 9, AVADataTypes.ValueExecutionMode.Escrow
        );
        valueSettlementExecutor.depositEscrow(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://security-refund-package-identity-drift-deposit"
        );

        mutableModule.setBlockedAction(AVADataTypes.Action.ResolveChallenge);
        uint256 refundId = valueSettlementExecutor.refundEscrow(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://security-refund-package-identity-drift-refund"
        );

        require(refundId != 0, "escrow refund missing");
        require(token.balanceOf(address(this)) == 100, "escrow refund did not return payer funds");
    }

    function testClawbackFailsClosedAfterPackageIdentityDrift() public {
        bytes32 workflowKey = keccak256("security-clawback-package-identity-drift");
        MockERC20 token = _m421FundedToken(100);
        MutableIdentityAntiAbuseModule mutableModule =
            new MutableIdentityAntiAbuseModule(AVADataTypes.Action.RecordAttestation);
        AVARulePackageRegistry.RulePackageModules memory modules = _defaultRulePackageModules();
        modules.antiAbuseModule = mutableModule;
        modules.valueExecutionAdapter = new MockERC20RecoveryValueExecutionAdapter(address(token));
        modules.compatibilityKey = keccak256("ava-post-audit-recovery-compatible");
        rulePackageRegistry.registerRulePackage(
            AVADataTypes.Role.Panel, PEER_REVIEW_APP_ID, workflowKey, modules, "ipfs://security-clawback-package-identity-drift"
        );
        uint256 originSourceId = _createM421RewardSource(
            workflowKey, "security-clawback-package-identity-drift", token, 9, AVADataTypes.ValueExecutionMode.Claim
        );
        uint256 originSettlementId = valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            originSourceId,
            keccak256("executor-authority"),
            "ipfs://security-clawback-origin-settlement"
        );
        reviewerActor.approveToken(token, address(valueSettlementExecutor), 9);
        uint256 challengeId =
            _fileAndResolveM425OriginChallenge(workflowKey, originSourceId, "security-clawback-package-identity-drift");
        uint256 penaltyId = _recordM425ActivePenalty(
            originSourceId, originSettlementId, challengeId, token, 9, "security-clawback-package-identity-drift"
        );
        uint256 obligationId = valueSettlementExecutor.recordRepaymentObligation(
            AVADataTypes.Role.ProtocolExecutor,
            penaltyId,
            keccak256("executor-authority"),
            "ipfs://security-clawback-obligation"
        );

        mutableModule.setBlockedAction(AVADataTypes.Action.ResolveChallenge);
        try valueSettlementExecutor.settleClawback(
            AVADataTypes.Role.ProtocolExecutor,
            obligationId,
            keccak256("executor-authority"),
            "ipfs://security-clawback-after-identity-drift"
        ) {
            revert("clawback executed from an identity-invalid package");
        } catch Error(string memory reason) {
            require(keccak256(bytes(reason)) != keccak256("clawback executed from an identity-invalid package"), reason);
        } catch {}

        uint256 waiverId = valueSettlementExecutor.recordWaiver(
            AVADataTypes.Role.ProtocolExecutor,
            obligationId,
            keccak256("executor-authority"),
            "ipfs://security-clawback-record-only-closeout"
        );
        require(waiverId != 0, "record-only recovery closeout missing");
    }

    function _registerWorkflowWithEvidenceLifecycle(
        bytes32 workflowKey,
        RejectingEvidenceLifecycleModule lifecycleModule,
        IValueExecutionAdapter valueModule
    ) internal {
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueModule,
            standingComputationModule,
            rulePackageLifecycleModule,
            lifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m4-21-compatible"),
            false,
            "ipfs://security-evidence-lifecycle-workflow"
        );
    }
}
