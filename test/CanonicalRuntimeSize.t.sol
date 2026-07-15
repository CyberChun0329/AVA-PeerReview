// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../src/canonical/AVAProductionSurface.sol";

interface CanonicalRuntimeCodeVm {
    function getDeployedCode(string calldata artifactPath) external returns (bytes memory runtimeCode);
}

contract CanonicalRuntimeSizeOptimizerSentinel {
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
        return value;
    }
}

contract CanonicalRuntimeSizeTest {
    uint256 private constant EIP170_LIMIT = 24_576;
    uint256 private constant CORE_HEADROOM_LIMIT = 22 * 1_024;
    uint256 private constant OPTIMIZED_SENTINEL_MAX = 700;
    CanonicalRuntimeCodeVm private constant VM =
        CanonicalRuntimeCodeVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function testCanonicalKernelChallengeAndLargeExtensionsRetainHeadroom() public {
        if (!_usesDeploymentOptimizer()) return;
        _assertRuntimeWithin("AVAGovernanceKernel.sol:AVAGovernanceKernel", CORE_HEADROOM_LIMIT);
        _assertRuntimeWithin(
            "AVAChallengeExtension.sol:AVAChallengeExtension", CORE_HEADROOM_LIMIT
        );
        _assertRuntimeWithin(
            "AVAStandingProvenanceExtensions.sol:AVAStandingProvenanceExtension",
            CORE_HEADROOM_LIMIT
        );
        _assertRuntimeWithin(
            "AVAValueLifecycleExtension.sol:AVAValueLifecycleExtension",
            CORE_HEADROOM_LIMIT
        );
    }

    function testCanonicalCoreAndExtensionRuntimesFitEip170() public {
        if (!_usesDeploymentOptimizer()) return;
        _assertRuntimeWithin("AVAApplicationRegistry.sol:AVAApplicationRegistry", EIP170_LIMIT);
        _assertRuntimeWithin("AVAAuthorityMatrix.sol:AVAAuthorityMatrix", EIP170_LIMIT);
        _assertRuntimeWithin("AVACoreRulePackageRegistry.sol:AVACoreRulePackageRegistry", EIP170_LIMIT);
        _assertRuntimeWithin("AVADisclosurePolicyRegistry.sol:AVADisclosurePolicyRegistry", EIP170_LIMIT);
        _assertRuntimeWithin("AVAEvidenceRegistry.sol:AVAEvidenceRegistry", EIP170_LIMIT);
        _assertRuntimeWithin("AVAGovernanceKernel.sol:AVAGovernanceKernel", EIP170_LIMIT);
        _assertRuntimeWithin("AVAIdentityRegistry.sol:AVAIdentityRegistry", EIP170_LIMIT);
        _assertRuntimeWithin("AVAWorkflowPolicyRouter.sol:AVAWorkflowPolicyRouter", EIP170_LIMIT);
        _assertRuntimeWithin(
            "AVAApprovalReceiptExtension.sol:AVAApprovalReceiptExtension", EIP170_LIMIT
        );
        _assertRuntimeWithin(
            "AVAApprovalReceiptExtension.sol:ApprovalReceiptAuthorityPolicyModule",
            EIP170_LIMIT
        );
        _assertRuntimeWithin(
            "AVAChallengeExtension.sol:AVAChallengeExtension", EIP170_LIMIT
        );
        _assertRuntimeWithin(
            "AVADownstreamRecordExtensions.sol:AVAStandingRecordExtension", EIP170_LIMIT
        );
        _assertRuntimeWithin(
            "AVADownstreamRecordExtensions.sol:AVAAllocationRecordExtension", EIP170_LIMIT
        );
        _assertRuntimeWithin(
            "AVADownstreamRecordExtensions.sol:AVAConsequenceRecordExtension", EIP170_LIMIT
        );
        _assertRuntimeWithin(
            "AVABoundedGovernanceExtensions.sol:AVARewardPriorityExtension", EIP170_LIMIT
        );
        _assertRuntimeWithin(
            "AVABoundedGovernanceExtensions.sol:AVAPenaltyRestorationExtension",
            EIP170_LIMIT
        );
        _assertRuntimeWithin(
            "AVAPrivacyProofExtension.sol:AVAPrivacyProofExtension", EIP170_LIMIT
        );
        _assertRuntimeWithin(
            "AVADisclosureReceiptExtension.sol:AVADisclosureReceiptExtension", EIP170_LIMIT
        );
        _assertRuntimeWithin(
            "AVAChallengePrivacyExtensions.sol:AVAChallengeProofUseExtension", EIP170_LIMIT
        );
        _assertRuntimeWithin(
            "AVAStandingCredentialExtensions.sol:AVAStandingComputationExtension",
            EIP170_LIMIT
        );
        _assertRuntimeWithin(
            "AVAStandingCredentialExtensions.sol:AVAStandingCredentialExtension",
            EIP170_LIMIT
        );
        _assertRuntimeWithin(
            "AVAStandingProvenanceExtensions.sol:AVAStandingProvenanceExtension",
            EIP170_LIMIT
        );
        _assertRuntimeWithin(
            "AVAStandingProvenanceExtensions.sol:AVAStandingZKProofExtension",
            EIP170_LIMIT
        );
        _assertRuntimeWithin(
            "AVAStandingProvenanceExtensions.sol:AVAStandingZKCredentialExtension",
            EIP170_LIMIT
        );
        _assertRuntimeWithin(
            "AVAStandingRevisionExtension.sol:AVAStandingRevisionExtension", EIP170_LIMIT
        );
        _assertRuntimeWithin(
            "AVASettlementReceiptExtension.sol:AVASettlementReceiptExtension",
            EIP170_LIMIT
        );
        _assertRuntimeWithin(
            "AVAValueLifecycleExtension.sol:AVAValueLifecycleExtension", EIP170_LIMIT
        );
        _assertRuntimeWithin(
            "AVAExternalOperationExtension.sol:AVAExternalOperationExtension", EIP170_LIMIT
        );
        _assertRuntimeWithin(
            "AVAExternalOperationTargetResolver.sol:AVAExternalOperationTargetResolver",
            EIP170_LIMIT
        );
        _assertRuntimeWithin(
            "AVAAuditReceiptExtension.sol:AVAAuditReceiptExtension", EIP170_LIMIT
        );
        _assertRuntimeWithin(
            "AVARulePackageLifecycleExtension.sol:AVARulePackageLifecycleExtension",
            EIP170_LIMIT
        );
        _assertRuntimeWithin(
            "AVARulePackageLifecycleExtension.sol:AVAPackageReadinessExtension",
            EIP170_LIMIT
        );
    }

    function testPeerReviewApplicationModulesFitEip170() public {
        if (!_usesDeploymentOptimizer()) return;
        _assertRuntimeWithin(
            "PeerReviewApplicationModule.sol:PeerReviewApplicationModule", EIP170_LIMIT
        );
        _assertRuntimeWithin(
            "PeerReviewDisclosurePolicyModules.sol:PeerReviewCoreDisclosurePolicyModule",
            EIP170_LIMIT
        );
        _assertRuntimeWithin(
            "PeerReviewDisclosurePolicyModules.sol:PeerReviewDisclosureReceiptPolicyModule",
            EIP170_LIMIT
        );
        _assertRuntimeWithin(
            "PeerReviewDisclosurePolicyModules.sol:PeerReviewZKProofReceiptPolicyModule",
            EIP170_LIMIT
        );
        _assertRuntimeWithin(
            "PeerReviewDisclosurePolicyModules.sol:PeerReviewAnonymousChallengeProofPolicyModule",
            EIP170_LIMIT
        );
        _assertRuntimeWithin(
            "PeerReviewPenaltyPolicyModule.sol:PeerReviewPenaltyPolicyModule", EIP170_LIMIT
        );
    }

    function _usesDeploymentOptimizer() private pure returns (bool) {
        return type(CanonicalRuntimeSizeOptimizerSentinel).runtimeCode.length <= OPTIMIZED_SENTINEL_MAX;
    }

    function _assertRuntimeWithin(string memory artifactPath, uint256 limit) private {
        bytes memory runtimeCode = VM.getDeployedCode(artifactPath);
        require(runtimeCode.length <= limit, artifactPath);
    }
}
