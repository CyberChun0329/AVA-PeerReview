// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVAApplicationRegistry} from "../src/AVAApplicationRegistry.sol";
import {M14PermissiveApplicationModule} from "./helpers/M14ApplicationFixture.sol";
import {IRuleModuleIdentity} from "../src/interfaces/IRuleModuleIdentity.sol";
import {AVAAuthorityMatrix} from "../src/core/AVAAuthorityMatrix.sol";
import {AVACapabilityKeys} from "../src/core/AVACapabilityKeys.sol";
import {AVACoreRulePackageRegistry} from "../src/core/AVACoreRulePackageRegistry.sol";
import {AVACoreTypes} from "../src/core/AVACoreTypes.sol";
import {AVAIdentityRegistry} from "../src/core/AVAIdentityRegistry.sol";
import {
    DefaultCoreAttributionModule,
    DefaultCoreVerificationModule,
    DefaultCoreTransitionRuleModule,
    DefaultCoreEvidencePolicyModule,
    DefaultCoreEvidenceLifecycleModule,
    DefaultCoreDisclosurePolicyModule,
    DefaultCoreChallengePolicyModule,
    DefaultCoreAuthorityPolicyModule,
    DefaultCoreStandingPolicyModule,
    DefaultCoreAllocationPolicyModule,
    DefaultCoreConsequencePolicyModule
} from "../src/core/modules/DefaultAVACoreRuleModules.sol";
import {
    DefaultStandingComputationPolicyModule,
    DefaultStandingCredentialPolicyModule
} from "../src/extensions/standing/DefaultStandingCredentialModules.sol";

contract M14MutableCapabilityModule is IRuleModuleIdentity {
    bytes32 public identityHash = keccak256("m14.mutable-capability.v1");

    function setIdentityHash(bytes32 identityHash_) external {
        identityHash = identityHash_;
    }

    function moduleIdentityHash() external view returns (bytes32) {
        return identityHash;
    }
}

interface M14CapabilityVm {
    function expectCall(address callee, bytes calldata data, uint64 count) external;
}

contract M14CoreCapabilitiesTest {
    bytes32 private constant APP_ID = keccak256("m14.capability.app");
    bytes32 private constant SECOND_APP_ID = keccak256("m14.capability.second-app");
    bytes32 private constant WORKFLOW = keccak256("m14.capability.workflow");
    bytes32 private constant PACKAGE_ROLE = keccak256("m14.capability.package-role");
    bytes32 private constant PACKAGE_SUBJECT = keccak256("m14.capability.package-subject");
    bytes32 private constant SECOND_PACKAGE_SUBJECT = keccak256("m14.capability.second-package-subject");
    bytes32 private constant COMPATIBILITY = keccak256("m14.capability.compatibility");
    bytes32 private constant CUSTOM_CAPABILITY = keccak256("m14.capability.custom-extension.v1");
    M14CapabilityVm private constant VM = M14CapabilityVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    AVAApplicationRegistry private applicationRegistry;
    AVAIdentityRegistry private identityRegistry;
    AVAAuthorityMatrix private authorityMatrix;
    AVACoreRulePackageRegistry private packageRegistry;

    function setUp() public {
        applicationRegistry = new AVAApplicationRegistry();
        applicationRegistry.registerApplication(
            APP_ID, keccak256("m14.capability.app-identity"), PACKAGE_SUBJECT, "ipfs://m14-capability-app"
        );
        applicationRegistry.registerApplication(
            SECOND_APP_ID,
            keccak256("m14.capability.second-app-identity"),
            SECOND_PACKAGE_SUBJECT,
            "ipfs://m14-capability-second-app"
        );
        identityRegistry = new AVAIdentityRegistry(applicationRegistry);
        authorityMatrix = new AVAAuthorityMatrix(applicationRegistry, identityRegistry);
        identityRegistry.assignSubject(address(this), APP_ID, PACKAGE_ROLE, PACKAGE_SUBJECT, "ipfs://package-subject");
        identityRegistry.assignSubject(
            address(this), SECOND_APP_ID, PACKAGE_ROLE, SECOND_PACKAGE_SUBJECT, "ipfs://second-package-subject"
        );
        authorityMatrix.setPermission(APP_ID, PACKAGE_ROLE, AVACoreTypes.ACTION_REGISTER_RULE_PACKAGE, true);
        authorityMatrix.setPermission(SECOND_APP_ID, PACKAGE_ROLE, AVACoreTypes.ACTION_REGISTER_RULE_PACKAGE, true);
        packageRegistry = new AVACoreRulePackageRegistry(applicationRegistry, authorityMatrix);
    }

    function testM145CapabilityKeyPackageAcceptsFutureExtensionWithoutRegistryStructChange() public {
        AVACoreRulePackageRegistry.ModuleBinding[] memory bindings = _bindings(APP_ID, true, address(0));
        uint256 packageId = _register(APP_ID, PACKAGE_SUBJECT, bindings);

        require(
            packageRegistry.getModule(packageId, CUSTOM_CAPABILITY) == address(bindings[14].module),
            "custom capability missing"
        );
        require(packageRegistry.getCapabilityKeys(packageId).length == 15, "capability list truncated");
    }

    function testCanonicalRulePackageRejectsMissingExecutableCoreCapability() public {
        AVACoreRulePackageRegistry.ModuleBinding[] memory complete = _bindings(APP_ID, false, address(0));
        AVACoreRulePackageRegistry.ModuleBinding[] memory incomplete =
            new AVACoreRulePackageRegistry.ModuleBinding[](complete.length - 1);
        uint256 cursor;
        for (uint256 i; i < complete.length; ++i) {
            if (complete[i].capabilityKey == AVACapabilityKeys.ALLOCATION) continue;
            incomplete[cursor++] = complete[i];
        }
        require(cursor == incomplete.length, "test package did not remove one capability");

        try packageRegistry.registerRulePackage(
            _packageInput(APP_ID, PACKAGE_SUBJECT, 1, "ipfs://missing-allocation-capability"), incomplete
        ) {
            revert("package without complete A/V/A profile became active");
        } catch {}
    }

    function testCanonicalRulePackageRejectsMoreThanSixtyFourCapabilitiesBeforeMutation() public {
        AVACoreRulePackageRegistry.ModuleBinding[] memory bindings = _expandedBindings(65);
        bool accepted;
        try packageRegistry.registerRulePackage(
            _packageInput(APP_ID, PACKAGE_SUBJECT, 1, "ipfs://too-many-capabilities"), bindings
        ) returns (
            uint256
        ) {
            accepted = true;
        } catch {}

        require(!accepted, "package with 65 capabilities was accepted");
        require(packageRegistry.nextPackageId() == 1, "rejected package consumed package id");
    }

    function testCanonicalRulePackageAcceptsDeclaredCapabilityLimit() public {
        require(packageRegistry.MAX_CAPABILITIES_PER_PACKAGE() == 64, "unexpected capability limit");
        uint256 packageId = _register(APP_ID, PACKAGE_SUBJECT, _expandedBindings(64));
        require(packageRegistry.getCapabilityKeys(packageId).length == 64, "bounded capability list truncated");
    }

    function testM145CapabilityIdentityDriftFailsClosed() public {
        M14MutableCapabilityModule mutableModule = new M14MutableCapabilityModule();
        AVACoreRulePackageRegistry.ModuleBinding[] memory bindings = _bindings(APP_ID, true, address(mutableModule));
        uint256 packageId = _register(APP_ID, PACKAGE_SUBJECT, bindings);
        packageRegistry.getRulePackageById(packageId);
        mutableModule.setIdentityHash(keccak256("m14.changed-capability-identity"));

        try packageRegistry.getRulePackageById(packageId) {
            revert("package read accepted changed module identity");
        } catch {}
    }

    function testFixedPolicyReadersFailClosedOnUnrequestedCapabilityIdentityDrift() public {
        M14MutableCapabilityModule mutableModule = new M14MutableCapabilityModule();
        uint256 packageId = _register(APP_ID, PACKAGE_SUBJECT, _bindings(APP_ID, true, address(mutableModule)));
        packageRegistry.getVerifiedWorkflowPolicyModules(packageId);
        packageRegistry.getVerifiedChallengePolicyModules(packageId);
        mutableModule.setIdentityHash(keccak256("m14.changed-unrequested-capability-identity"));

        try packageRegistry.getVerifiedWorkflowPolicyModules(packageId) {
            revert("fixed workflow reader ignored unrelated capability identity drift");
        } catch {}
        try packageRegistry.getVerifiedChallengePolicyModules(packageId) {
            revert("fixed challenge reader ignored unrelated capability identity drift");
        } catch {}
    }

    function testPerformancePackageVerificationChecksSharedModuleIdentityOnce() public {
        AVACoreRulePackageRegistry.ModuleBinding[] memory bindings = _expandedBindings(64);
        address sharedModule = address(bindings[0].module);
        uint256 packageId = _register(APP_ID, PACKAGE_SUBJECT, bindings);

        VM.expectCall(sharedModule, abi.encodeCall(IRuleModuleIdentity.moduleIdentityHash, ()), 1);
        packageRegistry.getVerifiedPackageContext(packageId);
    }

    function testM145SameWorkflowAndSupersessionRemainApplicationScopedAndHistorical() public {
        uint256 firstPackageId = _register(APP_ID, PACKAGE_SUBJECT, _bindings(APP_ID, false, address(0)));
        uint256 secondAppPackageId =
            _register(SECOND_APP_ID, SECOND_PACKAGE_SUBJECT, _bindings(SECOND_APP_ID, false, address(0)));
        AVACoreRulePackageRegistry.PackageRegistrationInput memory input =
            _packageInput(APP_ID, PACKAGE_SUBJECT, 2, "ipfs://m14-capability-v2");
        uint256 replacementPackageId =
            packageRegistry.supersedeRulePackage(input, firstPackageId, _bindings(APP_ID, false, address(0)));

        require(packageRegistry.getActivePackageId(APP_ID, WORKFLOW) == replacementPackageId, "pointer not moved");
        require(
            packageRegistry.getActivePackageId(SECOND_APP_ID, WORKFLOW) == secondAppPackageId,
            "second app pointer moved"
        );
        require(packageRegistry.getRulePackageById(firstPackageId).version == 1, "history rewritten");
    }

    function _register(bytes32 appId, bytes32 authorityId, AVACoreRulePackageRegistry.ModuleBinding[] memory bindings)
        internal
        returns (uint256)
    {
        return
            packageRegistry.registerRulePackage(
                _packageInput(appId, authorityId, 1, "ipfs://m14-capability-v1"), bindings
            );
    }

    function _packageInput(bytes32 appId, bytes32 authorityId, uint64 version, string memory uri)
        internal
        pure
        returns (AVACoreRulePackageRegistry.PackageRegistrationInput memory)
    {
        return AVACoreRulePackageRegistry.PackageRegistrationInput({
            appId: appId,
            workflowKey: WORKFLOW,
            roleKey: PACKAGE_ROLE,
            authorityId: authorityId,
            version: version,
            compatibilityKey: COMPATIBILITY,
            uri: uri
        });
    }

    function _bindings(bytes32 appId, bool includeCustom, address customModule)
        internal
        returns (AVACoreRulePackageRegistry.ModuleBinding[] memory bindings)
    {
        bindings = new AVACoreRulePackageRegistry.ModuleBinding[](includeCustom ? 15 : 14);
        bindings[0] = _binding(AVACapabilityKeys.APPLICATION, address(new M14PermissiveApplicationModule(appId)));
        bindings[1] = _binding(AVACapabilityKeys.ATTRIBUTION, address(new DefaultCoreAttributionModule()));
        bindings[2] = _binding(AVACapabilityKeys.VERIFICATION, address(new DefaultCoreVerificationModule()));
        bindings[3] = _binding(AVACapabilityKeys.TRANSITION_RULE, address(new DefaultCoreTransitionRuleModule()));
        bindings[4] = _binding(AVACapabilityKeys.EVIDENCE_POLICY, address(new DefaultCoreEvidencePolicyModule()));
        bindings[5] = _binding(AVACapabilityKeys.DISCLOSURE_POLICY, address(new DefaultCoreDisclosurePolicyModule()));
        bindings[6] = _binding(AVACapabilityKeys.CHALLENGE_POLICY, address(new DefaultCoreChallengePolicyModule()));
        bindings[7] = _binding(AVACapabilityKeys.AUTHORITY_POLICY, address(new DefaultCoreAuthorityPolicyModule()));
        bindings[8] = _binding(AVACapabilityKeys.STANDING, address(new DefaultCoreStandingPolicyModule()));
        bindings[9] = _binding(AVACapabilityKeys.ALLOCATION, address(new DefaultCoreAllocationPolicyModule()));
        bindings[10] = _binding(AVACapabilityKeys.CONSEQUENCE, address(new DefaultCoreConsequencePolicyModule()));
        bindings[11] = _binding(AVACapabilityKeys.EVIDENCE_LIFECYCLE, address(new DefaultCoreEvidenceLifecycleModule()));
        bindings[12] =
            _binding(AVACapabilityKeys.STANDING_COMPUTATION, address(new DefaultStandingComputationPolicyModule()));
        bindings[13] =
            _binding(AVACapabilityKeys.STANDING_CREDENTIAL, address(new DefaultStandingCredentialPolicyModule()));
        if (includeCustom) {
            if (customModule == address(0)) customModule = address(new M14MutableCapabilityModule());
            bindings[14] = _binding(CUSTOM_CAPABILITY, customModule);
        }
    }

    function _binding(bytes32 capabilityKey, address module)
        internal
        pure
        returns (AVACoreRulePackageRegistry.ModuleBinding memory)
    {
        return AVACoreRulePackageRegistry.ModuleBinding({
            capabilityKey: capabilityKey, module: IRuleModuleIdentity(module)
        });
    }

    function _expandedBindings(uint256 length)
        private
        returns (AVACoreRulePackageRegistry.ModuleBinding[] memory bindings)
    {
        AVACoreRulePackageRegistry.ModuleBinding[] memory base = _bindings(APP_ID, false, address(0));
        require(length >= base.length, "expanded package shorter than core profile");
        bindings = new AVACoreRulePackageRegistry.ModuleBinding[](length);
        for (uint256 i; i < base.length; ++i) {
            bindings[i] = base[i];
        }
        for (uint256 i = base.length; i < length; ++i) {
            bindings[i] = _binding(keccak256(abi.encode("m14.capability.extra", i)), address(base[0].module));
        }
    }
}
