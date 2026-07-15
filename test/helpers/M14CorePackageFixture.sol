// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAVAApplicationModule} from "../../src/interfaces/IAVAApplicationModule.sol";
import {IRuleModuleIdentity} from "../../src/interfaces/IRuleModuleIdentity.sol";
import {AVACapabilityKeys} from "../../src/core/AVACapabilityKeys.sol";
import {AVACoreRulePackageRegistry} from "../../src/core/AVACoreRulePackageRegistry.sol";
import {DefaultAVACorePolicyBundle} from "../../src/core/modules/DefaultAVACoreRuleModules.sol";
import {DefaultAVAExtensionPolicyModule} from "../../src/extensions/shared/DefaultAVAExtensionPolicyModule.sol";

abstract contract M14CorePackageFixture {
    function _coreBindings(IAVAApplicationModule applicationModule)
        internal
        returns (AVACoreRulePackageRegistry.ModuleBinding[] memory bindings)
    {
        bindings = new AVACoreRulePackageRegistry.ModuleBinding[](19);
        address defaultCorePolicy = address(new DefaultAVACorePolicyBundle());
        address defaultExtensionPolicy = address(new DefaultAVAExtensionPolicyModule());
        bindings[0] = _coreBinding(AVACapabilityKeys.APPLICATION, address(applicationModule));
        bindings[1] = _coreBinding(AVACapabilityKeys.ATTRIBUTION, defaultCorePolicy);
        bindings[2] = _coreBinding(AVACapabilityKeys.VERIFICATION, defaultCorePolicy);
        bindings[3] = _coreBinding(AVACapabilityKeys.TRANSITION_RULE, defaultCorePolicy);
        bindings[4] = _coreBinding(AVACapabilityKeys.EVIDENCE_POLICY, defaultCorePolicy);
        bindings[5] = _coreBinding(AVACapabilityKeys.DISCLOSURE_POLICY, defaultCorePolicy);
        bindings[6] = _coreBinding(AVACapabilityKeys.CHALLENGE_POLICY, defaultCorePolicy);
        bindings[7] = _coreBinding(AVACapabilityKeys.AUTHORITY_POLICY, defaultCorePolicy);
        bindings[8] = _coreBinding(AVACapabilityKeys.STANDING, defaultCorePolicy);
        bindings[9] = _coreBinding(AVACapabilityKeys.ALLOCATION, defaultCorePolicy);
        bindings[10] = _coreBinding(AVACapabilityKeys.CONSEQUENCE, defaultCorePolicy);
        bindings[11] = _coreBinding(AVACapabilityKeys.EVIDENCE_LIFECYCLE, defaultCorePolicy);
        bindings[12] = _coreBinding(AVACapabilityKeys.STANDING_COMPUTATION, defaultExtensionPolicy);
        bindings[13] = _coreBinding(AVACapabilityKeys.STANDING_CREDENTIAL, defaultExtensionPolicy);
        bindings[14] = _coreBinding(AVACapabilityKeys.REWARD, defaultExtensionPolicy);
        bindings[15] = _coreBinding(AVACapabilityKeys.PRIORITY, defaultExtensionPolicy);
        bindings[16] = _coreBinding(AVACapabilityKeys.PENALTY, defaultExtensionPolicy);
        bindings[17] = _coreBinding(AVACapabilityKeys.RESTORATION, defaultExtensionPolicy);
        bindings[18] = _coreBinding(AVACapabilityKeys.VALUE_EXECUTION, defaultExtensionPolicy);
    }

    function _corePackageInput(
        bytes32 appId,
        bytes32 workflowKey,
        bytes32 roleKey,
        bytes32 authorityId,
        uint64 version,
        bytes32 compatibilityKey,
        string memory uri
    ) internal pure returns (AVACoreRulePackageRegistry.PackageRegistrationInput memory) {
        return AVACoreRulePackageRegistry.PackageRegistrationInput({
            appId: appId,
            workflowKey: workflowKey,
            roleKey: roleKey,
            authorityId: authorityId,
            version: version,
            compatibilityKey: compatibilityKey,
            uri: uri
        });
    }

    function _coreBinding(bytes32 capabilityKey, address module)
        internal
        pure
        returns (AVACoreRulePackageRegistry.ModuleBinding memory)
    {
        return AVACoreRulePackageRegistry.ModuleBinding({
            capabilityKey: capabilityKey, module: IRuleModuleIdentity(module)
        });
    }
}
