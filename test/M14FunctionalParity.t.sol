// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVAApplicationRegistry} from "../src/AVAApplicationRegistry.sol";
import {AVAAuthorityMatrix} from "../src/core/AVAAuthorityMatrix.sol";
import {AVACapabilityKeys} from "../src/core/AVACapabilityKeys.sol";
import {AVACoreRulePackageRegistry} from "../src/core/AVACoreRulePackageRegistry.sol";
import {AVACoreTypes} from "../src/core/AVACoreTypes.sol";
import {AVAIdentityRegistry} from "../src/core/AVAIdentityRegistry.sol";
import {RuleModuleIdentity} from "../src/interfaces/IRuleModuleIdentity.sol";
import {PeerReviewApplicationModule} from "../src/apps/peerreview/PeerReviewApplicationModule.sol";
import {PeerReviewTypes} from "../src/apps/peerreview/PeerReviewTypes.sol";
import {
    AVARulePackageLifecycleExtension,
    DefaultAVAPackageLifecyclePolicyModule
} from "../src/extensions/package/AVARulePackageLifecycleExtension.sol";
import "./helpers/M14CorePackageFixture.sol";

interface M14FunctionalParityVm {
    function expectCall(address callee, bytes calldata data, uint64 count) external;
}

contract M14FunctionalParityTest is M14CorePackageFixture {
    bytes32 private constant WORKFLOW = keccak256("m14.parity.workflow");
    bytes32 private constant PACKAGE_ROLE = keccak256("m14.parity.package-role");
    bytes32 private constant PACKAGE_SUBJECT = keccak256("m14.parity.package-subject");
    bytes32 private constant COMPATIBILITY_KEY = keccak256("m14.parity.compatibility");
    M14FunctionalParityVm private constant VM =
        M14FunctionalParityVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    AVAApplicationRegistry private applicationRegistry;
    AVAIdentityRegistry private identityRegistry;
    AVAAuthorityMatrix private authorityMatrix;
    AVACoreRulePackageRegistry private packageRegistry;
    AVARulePackageLifecycleExtension private lifecycleExtension;
    PeerReviewApplicationModule private applicationModule;
    uint256 private packageV1;
    uint256 private packageV2;

    function setUp() public {
        applicationRegistry = new AVAApplicationRegistry();
        applicationModule = new PeerReviewApplicationModule();
        applicationRegistry.registerApplication(
            PeerReviewTypes.APP_ID,
            applicationModule.moduleIdentityHash(),
            PACKAGE_SUBJECT,
            "ipfs://m14-parity-app"
        );
        identityRegistry = new AVAIdentityRegistry(applicationRegistry);
        authorityMatrix = new AVAAuthorityMatrix(applicationRegistry, identityRegistry);
        identityRegistry.assignSubject(
            address(this),
            PeerReviewTypes.APP_ID,
            PACKAGE_ROLE,
            PACKAGE_SUBJECT,
            "ipfs://m14-parity-package-authority"
        );
        authorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PACKAGE_ROLE, AVACoreTypes.ACTION_REGISTER_RULE_PACKAGE, true
        );
        authorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PACKAGE_ROLE, AVACoreTypes.ACTION_RECORD_PACKAGE_LIFECYCLE, true
        );
        packageRegistry = new AVACoreRulePackageRegistry(applicationRegistry, authorityMatrix);

        DefaultAVAPackageLifecyclePolicyModule lifecycleModule =
            new DefaultAVAPackageLifecyclePolicyModule();
        packageV1 = packageRegistry.registerRulePackage(
            _corePackageInput(
                PeerReviewTypes.APP_ID,
                WORKFLOW,
                PACKAGE_ROLE,
                PACKAGE_SUBJECT,
                1,
                COMPATIBILITY_KEY,
                "ipfs://m14-parity-package-v1"
            ),
            _withLifecycleBinding(_coreBindings(applicationModule), address(lifecycleModule))
        );
        packageV2 = packageRegistry.supersedeRulePackage(
            _corePackageInput(
                PeerReviewTypes.APP_ID,
                WORKFLOW,
                PACKAGE_ROLE,
                PACKAGE_SUBJECT,
                2,
                COMPATIBILITY_KEY,
                "ipfs://m14-parity-package-v2"
            ),
            packageV1,
            _withLifecycleBinding(_coreBindings(applicationModule), address(lifecycleModule))
        );
        lifecycleExtension = new AVARulePackageLifecycleExtension(authorityMatrix, packageRegistry);
    }

    function testParityPackageLifecycleIsExplicitPackageBoundAndAppendOnly() public {
        uint256 recordId = lifecycleExtension.recordPackageLifecycle(
            AVARulePackageLifecycleExtension.PackageLifecycleInput({
                sourcePackageId: packageV1,
                targetPackageId: packageV2,
                roleKey: PACKAGE_ROLE,
                authorityId: PACKAGE_SUBJECT,
                kind: AVARulePackageLifecycleExtension.PackageLifecycleKind.MigrationReady,
                reasonHash: keccak256("m14-parity-migration-ready"),
                uri: "ipfs://m14-parity-migration-ready"
            })
        );

        AVARulePackageLifecycleExtension.PackageLifecycleRecord memory record =
            lifecycleExtension.getPackageLifecycleRecord(recordId);
        require(record.sourcePackageId == packageV1, "wrong source package");
        require(record.targetPackageId == packageV2, "wrong target package");
        require(record.appId == PeerReviewTypes.APP_ID, "wrong app");
        require(record.workflowKey == WORKFLOW, "wrong workflow");
        require(
            record.kind == AVARulePackageLifecycleExtension.PackageLifecycleKind.MigrationReady,
            "wrong lifecycle kind"
        );
        require(packageRegistry.getActivePackageId(PeerReviewTypes.APP_ID, WORKFLOW) == packageV2, "pointer changed");
        require(packageRegistry.getRulePackageById(packageV1).packageId == packageV1, "history lost");
    }

    function testParityPackageLifecycleRejectsIncompatibleOrDuplicateRecord() public {
        AVARulePackageLifecycleExtension.PackageLifecycleInput memory input =
            AVARulePackageLifecycleExtension.PackageLifecycleInput({
                sourcePackageId: packageV1,
                targetPackageId: packageV2,
                roleKey: PACKAGE_ROLE,
                authorityId: PACKAGE_SUBJECT,
                kind: AVARulePackageLifecycleExtension.PackageLifecycleKind.MigrationReady,
                reasonHash: keccak256("m14-parity-migration-ready"),
                uri: "ipfs://m14-parity-migration-ready"
            });
        lifecycleExtension.recordPackageLifecycle(input);
        (bool duplicateOk,) = address(lifecycleExtension).call(
            abi.encodeCall(AVARulePackageLifecycleExtension.recordPackageLifecycle, (input))
        );
        require(!duplicateOk, "duplicate lifecycle record accepted");

        input.targetPackageId = packageV1;
        input.kind = AVARulePackageLifecycleExtension.PackageLifecycleKind.Superseded;
        (bool reverseOk,) = address(lifecycleExtension).call(
            abi.encodeCall(AVARulePackageLifecycleExtension.recordPackageLifecycle, (input))
        );
        require(!reverseOk, "reverse package lifecycle accepted");
    }

    function testPerformancePackageLifecycleValidatesEachPackageOnce() public {
        VM.expectCall(address(applicationModule), abi.encodeCall(RuleModuleIdentity.moduleIdentityHash, ()), 2);
        uint256 recordId = lifecycleExtension.recordPackageLifecycle(
            AVARulePackageLifecycleExtension.PackageLifecycleInput({
                sourcePackageId: packageV1,
                targetPackageId: packageV2,
                roleKey: PACKAGE_ROLE,
                authorityId: PACKAGE_SUBJECT,
                kind: AVARulePackageLifecycleExtension.PackageLifecycleKind.MigrationReady,
                reasonHash: keccak256("performance-package-lifecycle"),
                uri: "ipfs://performance-package-lifecycle"
            })
        );
        require(lifecycleExtension.getPackageLifecycleRecord(recordId).targetPackageId == packageV2, "target changed");
    }

    function _withLifecycleBinding(
        AVACoreRulePackageRegistry.ModuleBinding[] memory base,
        address lifecycleModule
    ) private pure returns (AVACoreRulePackageRegistry.ModuleBinding[] memory bindings) {
        bindings = new AVACoreRulePackageRegistry.ModuleBinding[](base.length + 1);
        for (uint256 i; i < base.length; ++i) bindings[i] = base[i];
        bindings[base.length] = _coreBinding(AVACapabilityKeys.PACKAGE_LIFECYCLE, lifecycleModule);
    }
}
