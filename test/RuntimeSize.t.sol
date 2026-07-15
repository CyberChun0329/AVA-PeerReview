// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface VmRuntimeCode {
    function getDeployedCode(string calldata artifactPath) external returns (bytes memory runtimeCode);
}

contract RuntimeSizeOptimizerSentinel {
    function foldedBuildMarker(uint256 value) external pure returns (uint256) {
        value += 1;
        value += 2;
        value += 3;
        value += 4;
        value += 5;
        value += 6;
        value += 7;
        value += 8;
        value += 9;
        value += 10;
        value += 11;
        value += 12;
        value += 13;
        value += 14;
        value += 15;
        value += 16;
        value += 17;
        value += 18;
        value += 19;
        value += 20;
        value += 21;
        value += 22;
        value += 23;
        value += 24;
        value += 25;
        value += 26;
        value += 27;
        value += 28;
        value += 29;
        value += 30;
        value += 31;
        value += 32;
        return value;
    }
}

contract RuntimeSizeTest {
    uint256 private constant EIP170_RUNTIME_LIMIT = 24_576;
    uint256 private constant STATE_CORE_HEADROOM_LIMIT = 22 * 1_024;
    uint256 private constant RULE_PACKAGE_REGISTRY_HEADROOM_LIMIT = 20 * 1_024;
    uint256 private constant LIFECYCLE_REGISTRY_HEADROOM_LIMIT = 18 * 1_024;
    uint256 private constant CONSEQUENCE_EXECUTOR_HEADROOM_LIMIT = EIP170_RUNTIME_LIMIT - 1_536;
    uint256 private constant OPTIMIZED_SENTINEL_MAX = 700;
    VmRuntimeCode private constant VM = VmRuntimeCode(address(uint160(uint256(keccak256("hevm cheat code")))));

    function testStateCoreAndChallengeWorkflowRetainHeadroom() public {
        if (!_usesDeploymentOptimizer()) return;
        _assertRuntimeWithin("src/AVAStateMachine.sol:AVAStateMachine", STATE_CORE_HEADROOM_LIMIT);
        _assertRuntimeWithin("src/AVAChallengeWorkflow.sol:AVAChallengeWorkflow", STATE_CORE_HEADROOM_LIMIT);
        _assertRuntimeWithin("src/core/AVAGovernanceKernel.sol:AVAGovernanceKernel", STATE_CORE_HEADROOM_LIMIT);
    }

    function testRulePackageRegistriesRetainHeadroom() public {
        if (!_usesDeploymentOptimizer()) return;
        _assertRuntimeWithin(
            "src/AVARulePackageRegistry.sol:AVARulePackageRegistry", RULE_PACKAGE_REGISTRY_HEADROOM_LIMIT
        );
        _assertRuntimeWithin(
            "src/AVARulePackageLifecycleRegistry.sol:AVARulePackageLifecycleRegistry", LIFECYCLE_REGISTRY_HEADROOM_LIMIT
        );
    }

    function testConsequenceExecutorRetainsPreFreezeHeadroom() public {
        if (!_usesDeploymentOptimizer()) return;
        _assertRuntimeWithin("src/ConsequenceExecutor.sol:ConsequenceExecutor", CONSEQUENCE_EXECUTOR_HEADROOM_LIMIT);
    }

    function testAllProductionContractRuntimesFitEip170() public {
        if (!_usesDeploymentOptimizer()) return;
        _assertRuntimeWithinEip170("src/AVAApplicationRegistry.sol:AVAApplicationRegistry");
        _assertRuntimeWithinEip170("src/AVAChallengeWorkflow.sol:AVAChallengeWorkflow");
        _assertRuntimeWithinEip170("src/AVARulePackageRegistry.sol:AVARulePackageRegistry");
        _assertRuntimeWithinEip170("src/AVARulePackageLifecycleRegistry.sol:AVARulePackageLifecycleRegistry");
        _assertRuntimeWithinEip170("src/AVAStateMachine.sol:AVAStateMachine");
        _assertRuntimeWithinEip170("src/AVAWorkflowValidator.sol:AVAWorkflowValidator");
        _assertRuntimeWithinEip170("src/core/AVAAuthorityMatrix.sol:AVAAuthorityMatrix");
        _assertRuntimeWithinEip170("src/core/AVADisclosurePolicyRegistry.sol:AVADisclosurePolicyRegistry");
        _assertRuntimeWithinEip170("src/core/AVAEvidenceRegistry.sol:AVAEvidenceRegistry");
        _assertRuntimeWithinEip170("src/core/AVAGovernanceKernel.sol:AVAGovernanceKernel");
        _assertRuntimeWithinEip170("src/core/AVAIdentityRegistry.sol:AVAIdentityRegistry");
        _assertRuntimeWithinEip170("src/extensions/challenge/AVAChallengeExtension.sol:AVAChallengeExtension");
        _assertRuntimeWithinEip170(
            "src/extensions/downstream/AVADownstreamRecordExtensions.sol:AVAStandingRecordExtension"
        );
        _assertRuntimeWithinEip170(
            "src/extensions/downstream/AVADownstreamRecordExtensions.sol:AVAAllocationRecordExtension"
        );
        _assertRuntimeWithinEip170(
            "src/extensions/downstream/AVADownstreamRecordExtensions.sol:AVAConsequenceRecordExtension"
        );
        _assertRuntimeWithinEip170(
            "src/extensions/standing/AVAStandingRevisionExtension.sol:AVAStandingRevisionExtension"
        );
        _assertRuntimeWithinEip170(
            "src/extensions/standing/AVAStandingCredentialExtensions.sol:AVAStandingComputationExtension"
        );
        _assertRuntimeWithinEip170(
            "src/extensions/standing/AVAStandingCredentialExtensions.sol:AVAStandingCredentialExtension"
        );
        _assertRuntimeWithinEip170("src/extensions/privacy/AVAPrivacyProofExtension.sol:AVAPrivacyProofExtension");
        _assertRuntimeWithinEip170(
            "src/extensions/privacy/AVADisclosureReceiptExtension.sol:AVADisclosureReceiptExtension"
        );
        _assertRuntimeWithinEip170("src/extensions/audit/AVAAuditReceiptExtension.sol:AVAAuditReceiptExtension");
        _assertRuntimeWithinEip170(
            "src/extensions/settlement/AVASettlementReceiptExtension.sol:AVASettlementReceiptExtension"
        );
        _assertRuntimeWithinEip170(
            "src/extensions/external/AVAExternalOperationExtension.sol:AVAExternalOperationExtension"
        );
        _assertRuntimeWithinEip170("src/AllocationExecutor.sol:AllocationExecutor");
        _assertRuntimeWithinEip170("src/AttestationAuditModule.sol:AttestationAuditModule");
        _assertRuntimeWithinEip170("src/AuthorityApprovalRegistry.sol:AuthorityApprovalRegistry");
        _assertRuntimeWithinEip170("src/AuthorityMatrix.sol:AuthorityMatrix");
        _assertRuntimeWithinEip170("src/ConsequenceExecutor.sol:ConsequenceExecutor");
        _assertRuntimeWithinEip170("src/ConsequenceBoundaryValidator.sol:ConsequenceBoundaryValidator");
        _assertRuntimeWithinEip170("src/DisclosureAccessExecutor.sol:DisclosureAccessExecutor");
        _assertRuntimeWithinEip170("src/DisclosurePolicyRegistry.sol:DisclosurePolicyRegistry");
        _assertRuntimeWithinEip170("src/EvidenceCommitmentRegistry.sol:EvidenceCommitmentRegistry");
        _assertRuntimeWithinEip170("src/ExternalOperationRegistry.sol:ExternalOperationRegistry");
        _assertRuntimeWithinEip170("src/MockERC20.sol:MockERC20");
        _assertRuntimeWithinEip170("src/MockPriorityToken.sol:MockPriorityToken");
        _assertRuntimeWithinEip170("src/RoleIdentityRegistry.sol:RoleIdentityRegistry");
        _assertRuntimeWithinEip170("src/RulePackageIdentityVerifier.sol:RulePackageIdentityVerifier");
        _assertRuntimeWithinEip170("src/SchnorrDisclosureProofVerifier.sol:SchnorrDisclosureProofVerifier");
        _assertRuntimeWithinEip170("src/StandingCredentialRegistry.sol:StandingCredentialRegistry");
        _assertRuntimeWithinEip170("src/StandingFormulaRegistry.sol:StandingFormulaRegistry");
        _assertRuntimeWithinEip170("src/StandingRegistry.sol:StandingRegistry");
        _assertRuntimeWithinEip170("src/StandingRevisionRegistry.sol:StandingRevisionRegistry");
        _assertRuntimeWithinEip170("src/ValueSettlementExecutor.sol:ValueSettlementExecutor");
        _assertRuntimeWithinEip170("src/ZKProofRegistry.sol:ZKProofRegistry");
        _assertRuntimeWithinEip170("src/ZKStandingComputationRegistry.sol:ZKStandingComputationRegistry");
        _assertRuntimeWithinEip170("src/ZKStandingCredentialRegistry.sol:ZKStandingCredentialRegistry");
        _assertRuntimeWithinEip170(
            "src/modules/AnonymousChallengeDisclosureModule.sol:AnonymousChallengeDisclosureModule"
        );
        _assertRuntimeWithinEip170("src/modules/ApprovalReceiptAuthorityModule.sol:ApprovalReceiptAuthorityModule");
        _assertRuntimeWithinEip170("src/modules/DefaultAllocationAdapter.sol:DefaultAllocationAdapter");
        _assertRuntimeWithinEip170("src/modules/DefaultApplicationModule.sol:DefaultApplicationModule");
        _assertRuntimeWithinEip170("src/modules/DefaultAttributionModule.sol:DefaultAttributionModule");
        _assertRuntimeWithinEip170("src/modules/DefaultChallengeLifecycleModule.sol:DefaultChallengeLifecycleModule");
        _assertRuntimeWithinEip170("src/modules/DefaultConsequenceAdapter.sol:DefaultConsequenceAdapter");
        _assertRuntimeWithinEip170("src/modules/DefaultDisclosurePolicyModule.sol:DefaultDisclosurePolicyModule");
        _assertRuntimeWithinEip170("src/modules/DefaultExecutionModules.sol:DefaultDisclosureExecutionModule");
        _assertRuntimeWithinEip170("src/modules/DefaultExecutionModules.sol:KindRejectingDisclosureExecutionModule");
        _assertRuntimeWithinEip170("src/modules/DefaultFutureProofModules.sol:DefaultDisclosureLifecycleModule");
        _assertRuntimeWithinEip170("src/modules/DefaultFutureProofModules.sol:DefaultEvidenceLifecycleModule");
        _assertRuntimeWithinEip170("src/modules/DefaultFutureProofModules.sol:DefaultRulePackageLifecycleModule");
        _assertRuntimeWithinEip170("src/modules/DefaultFutureProofModules.sol:DefaultStandingComputationModule");
        _assertRuntimeWithinEip170("src/modules/DefaultFutureProofModules.sol:DefaultValueExecutionAdapter");
        _assertRuntimeWithinEip170("src/modules/DefaultFutureProofModules.sol:MockERC20RecoveryValueExecutionAdapter");
        _assertRuntimeWithinEip170("src/modules/DefaultInfrastructureModules.sol:DefaultAntiAbuseModule");
        _assertRuntimeWithinEip170("src/modules/DefaultInfrastructureModules.sol:DefaultAuditAdapter");
        _assertRuntimeWithinEip170("src/modules/DefaultInfrastructureModules.sol:DefaultEditorialSystemAdapter");
        _assertRuntimeWithinEip170("src/modules/DefaultInfrastructureModules.sol:DefaultEvidencePolicyModule");
        _assertRuntimeWithinEip170("src/modules/DefaultInfrastructureModules.sol:DefaultFieldPolicyModule");
        _assertRuntimeWithinEip170(
            "src/modules/DefaultInfrastructureModules.sol:DefaultResidualEditorialAuthorityModule"
        );
        _assertRuntimeWithinEip170("src/modules/DefaultPenaltyAdapter.sol:DefaultPenaltyAdapter");
        _assertRuntimeWithinEip170("src/modules/DefaultPriorityAdapter.sol:DefaultPriorityAdapter");
        _assertRuntimeWithinEip170("src/modules/DefaultRestorationAdapter.sol:DefaultRestorationAdapter");
        _assertRuntimeWithinEip170("src/modules/DefaultRewardAdapter.sol:DefaultRewardAdapter");
        _assertRuntimeWithinEip170("src/modules/DefaultStandingAdapter.sol:DefaultStandingAdapter");
        _assertRuntimeWithinEip170("src/modules/DefaultTransitionRuleModule.sol:DefaultTransitionRuleModule");
        _assertRuntimeWithinEip170("src/modules/DefaultVerificationModule.sol:DefaultVerificationModule");
        _assertRuntimeWithinEip170("src/modules/DoubleBlindDisclosureModule.sol:DoubleBlindDisclosureModule");
        _assertRuntimeWithinEip170("src/modules/ExampleDownstreamAdapters.sol:BoundedConsequenceExampleAdapter");
        _assertRuntimeWithinEip170("src/modules/ExampleDownstreamAdapters.sol:CorrectionRestorationRecordAdapter");
        _assertRuntimeWithinEip170("src/modules/ExampleDownstreamAdapters.sol:GenericTokenRecordRewardAdapter");
        _assertRuntimeWithinEip170("src/modules/ExampleDownstreamAdapters.sol:PriorityReturnObligationRecordAdapter");
        _assertRuntimeWithinEip170("src/modules/ExampleDownstreamAdapters.sol:PriorityTokenRecordAdapter");
        _assertRuntimeWithinEip170("src/modules/ExampleDownstreamAdapters.sol:ProceduralPenaltyRecordAdapter");
        _assertRuntimeWithinEip170("src/modules/ExampleDownstreamAdapters.sol:RentedPriorityRecordAdapter");
        _assertRuntimeWithinEip170("src/modules/ExampleDownstreamAdapters.sol:RestorationProcedureRecordAdapter");
        _assertRuntimeWithinEip170("src/modules/ExampleDownstreamAdapters.sol:StablecoinRecordRewardAdapter");
        _assertRuntimeWithinEip170("src/modules/ExampleDownstreamAdapters.sol:VectorStandingAdapter");
        _assertRuntimeWithinEip170("src/modules/ExampleFutureProofModules.sol:ClaimEscrowRecordValueAdapter");
        _assertRuntimeWithinEip170("src/modules/ExampleFutureProofModules.sol:FormulaV0StandingComputationModule");
        _assertRuntimeWithinEip170("src/modules/ExampleFutureProofModules.sol:RejectingDisclosureLifecycleModule");
        _assertRuntimeWithinEip170("src/modules/ExampleFutureProofModules.sol:RejectingEvidenceLifecycleModule");
        _assertRuntimeWithinEip170("src/modules/ExampleFutureProofModules.sol:VectorStandingComputationModule");
        _assertRuntimeWithinEip170("src/modules/ExampleFutureProofModules.sol:VersionedRulePackageLifecycleModule");
        _assertRuntimeWithinEip170("src/modules/ExampleRuleModules.sol:CredentialGatedPanelModule");
        _assertRuntimeWithinEip170("src/modules/ExampleRuleModules.sol:DisciplineFieldPolicyModule");
        _assertRuntimeWithinEip170("src/modules/ExampleRuleModules.sol:EditorialReferenceAdapter");
        _assertRuntimeWithinEip170("src/modules/ExampleRuleModules.sol:EvidenceThresholdVerificationModule");
        _assertRuntimeWithinEip170("src/modules/ExampleRuleModules.sol:HashAnchoredAuditAdapter");
        _assertRuntimeWithinEip170("src/modules/ExampleRuleModules.sol:MinimumChallengeWindowTransitionModule");
        _assertRuntimeWithinEip170("src/modules/ExampleRuleModules.sol:NoFrozenTransitionRuleModule");
        _assertRuntimeWithinEip170("src/modules/ExampleRuleModules.sol:PanelOnlyChallengeLifecycleModule");
        _assertRuntimeWithinEip170("src/modules/ExampleRuleModules.sol:ProceduralEditorialAuthorityModule");
        _assertRuntimeWithinEip170("src/modules/ExampleRuleModules.sol:RestrictionAwareChallengeIntakeModule");
        _assertRuntimeWithinEip170("src/modules/ExampleRuleModules.sol:IllustrativeStaticAuthorityShapeModule");
        _assertRuntimeWithinEip170("src/modules/ExampleRuleModules.sol:SubjectRateLimitModule");
        _assertRuntimeWithinEip170("src/modules/ExampleRuleModules.sol:SubjectSaltAttributionModule");
        _assertRuntimeWithinEip170("src/modules/ExampleRuleModules.sol:TypedEvidencePolicyModule");
        _assertRuntimeWithinEip170("src/modules/PanelVisibleDisclosureModule.sol:PanelVisibleDisclosureModule");
        _assertRuntimeWithinEip170(
            "src/modules/PostRecognitionAuthorRevealModule.sol:PostRecognitionAuthorRevealModule"
        );
        _assertRuntimeWithinEip170("src/modules/VoluntaryRealNameChallengeModule.sol:VoluntaryRealNameChallengeModule");
        _assertRuntimeWithinEip170("src/modules/ZKBackedDisclosureModule.sol:ZKBackedDisclosureModule");
        _assertRuntimeWithinEip170("src/apps/peerreview/PeerReviewApplicationModule.sol:PeerReviewApplicationModule");
    }

    function _assertRuntimeWithinEip170(string memory artifactPath) internal {
        _assertRuntimeWithin(artifactPath, EIP170_RUNTIME_LIMIT);
    }

    function _usesDeploymentOptimizer() internal pure returns (bool) {
        // `forge coverage` deliberately disables the deployment optimizer.
        return type(RuntimeSizeOptimizerSentinel).runtimeCode.length <= OPTIMIZED_SENTINEL_MAX;
    }

    function _assertRuntimeWithin(string memory artifactPath, uint256 limit) internal {
        bytes memory runtimeCode = VM.getDeployedCode(artifactPath);
        require(runtimeCode.length <= limit, artifactPath);
    }
}
