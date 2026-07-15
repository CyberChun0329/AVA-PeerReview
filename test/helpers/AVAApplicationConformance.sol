// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVACapabilityKeys} from "../../src/core/AVACapabilityKeys.sol";
import {AVACoreRulePackageRegistry} from "../../src/core/AVACoreRulePackageRegistry.sol";
import {AVAGovernanceKernel} from "../../src/core/AVAGovernanceKernel.sol";
import {IAVAApplicationModule} from "../../src/interfaces/IAVAApplicationModule.sol";

/// @notice Reusable test assertions for applications integrating with the canonical AVA Core.
/// @dev This test-only library verifies package dispatch, application identity, historical state pinning,
///      and fail-closed rejection without adding an application-specific production dependency.
library AVAApplicationConformance {
    function assertVerifiedPackage(
        AVACoreRulePackageRegistry registry,
        uint256 packageId,
        bytes32 expectedAppId,
        bytes32 expectedWorkflowKey
    ) internal view {
        bytes32[] memory requiredCapabilities = _requiredCoreCapabilities();
        (AVACoreRulePackageRegistry.VerifiedPackageContext memory context, address[] memory modules) =
            registry.getVerifiedModulesCompact(packageId, requiredCapabilities);
        require(context.packageId == packageId, "conformance: wrong package id");
        require(context.appId == expectedAppId, "conformance: wrong application");
        require(context.workflowKey == expectedWorkflowKey, "conformance: wrong workflow");
        require(context.version != 0 && context.compatibilityKey != bytes32(0), "conformance: incomplete metadata");
        for (uint256 i; i < modules.length; ++i) {
            require(modules[i] != address(0), "conformance: missing core capability");
        }
        require(
            IAVAApplicationModule(modules[0]).applicationId() == expectedAppId,
            "conformance: application module mismatch"
        );
    }

    function assertHistoricalStateBinding(
        AVAGovernanceKernel kernel,
        uint256 recognisedStateId,
        bytes32 expectedAppId,
        bytes32 expectedWorkflowKey,
        uint256 expectedPackageId
    ) internal view {
        AVAGovernanceKernel.RecognisedStateReference memory state =
            kernel.getRecognisedStateReference(recognisedStateId);
        require(state.appId == expectedAppId, "conformance: state application drift");
        require(state.workflowKey == expectedWorkflowKey, "conformance: state workflow drift");
        require(state.packageId == expectedPackageId, "conformance: historical package drift");
    }

    function assertRejectedCall(address target, bytes memory callData) internal {
        (bool success,) = target.call(callData);
        require(!success, "conformance: invalid integration call succeeded");
    }

    function _requiredCoreCapabilities() private pure returns (bytes32[] memory keys) {
        keys = new bytes32[](9);
        keys[0] = AVACapabilityKeys.APPLICATION;
        keys[1] = AVACapabilityKeys.ATTRIBUTION;
        keys[2] = AVACapabilityKeys.VERIFICATION;
        keys[3] = AVACapabilityKeys.TRANSITION_RULE;
        keys[4] = AVACapabilityKeys.EVIDENCE_POLICY;
        keys[5] = AVACapabilityKeys.EVIDENCE_LIFECYCLE;
        keys[6] = AVACapabilityKeys.DISCLOSURE_POLICY;
        keys[7] = AVACapabilityKeys.AUTHORITY_POLICY;
        keys[8] = AVACapabilityKeys.ALLOCATION;
    }
}
