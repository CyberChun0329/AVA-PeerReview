// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVAApplicationRegistry} from "../src/AVAApplicationRegistry.sol";
import {IAVAApplicationModule} from "../src/interfaces/IAVAApplicationModule.sol";
import {RuleModuleIdentity} from "../src/interfaces/IRuleModuleIdentity.sol";
import {AVAAuthorityMatrix} from "../src/core/AVAAuthorityMatrix.sol";
import {AVACapabilityKeys} from "../src/core/AVACapabilityKeys.sol";
import {AVACoreRulePackageRegistry} from "../src/core/AVACoreRulePackageRegistry.sol";
import {AVACoreTypes} from "../src/core/AVACoreTypes.sol";
import {AVADisclosurePolicyRegistry} from "../src/core/AVADisclosurePolicyRegistry.sol";
import {AVAEvidenceRegistry} from "../src/core/AVAEvidenceRegistry.sol";
import {AVAGovernanceKernel} from "../src/core/AVAGovernanceKernel.sol";
import {AVAIdentityRegistry} from "../src/core/AVAIdentityRegistry.sol";
import {AVAWorkflowPolicyRouter} from "../src/core/AVAWorkflowPolicyRouter.sol";
import {IAVAAuthorityPolicyModule} from "../src/core/interfaces/IAVACoreRuleModules.sol";
import {AVAChallengeExtension} from "../src/extensions/challenge/AVAChallengeExtension.sol";
import {
    AVAApprovalReceiptExtension,
    ApprovalReceiptAuthorityPolicyModule,
    DefaultAVAApprovalPolicyModule
} from "../src/extensions/authority/AVAApprovalReceiptExtension.sol";
import {
    AVARulePackageLifecycleExtension,
    AVAPackageReadinessExtension,
    DefaultAVAPackageLifecyclePolicyModule
} from "../src/extensions/package/AVARulePackageLifecycleExtension.sol";
import "./helpers/M14CorePackageFixture.sol";

interface M14AuthorityParityVm {
    function prank(address sender) external;

    function warp(uint256 timestamp) external;

    function expectCall(address callee, bytes calldata data, uint64 count) external;
}

library M14AuthorityParityTypes {
    bytes32 internal constant APP_ID = keccak256("ava.test.authority-parity.app.v1");
    bytes32 internal constant WORKFLOW = keccak256("ava.test.authority-parity.workflow.v1");
    bytes32 internal constant PACKAGE_ROLE = keccak256("ava.test.authority-parity.package-role.v1");
    bytes32 internal constant SUBMITTER_ROLE = keccak256("ava.test.authority-parity.submitter-role.v1");
    bytes32 internal constant VERIFIER_ROLE = keccak256("ava.test.authority-parity.verifier-role.v1");
    bytes32 internal constant PANEL_ROLE = keccak256("ava.test.authority-parity.panel-role.v1");
    bytes32 internal constant OBJECT_TYPE = keccak256("ava.test.authority-parity.object.v1");
}

contract M14AuthorityParityApplicationModule is IAVAApplicationModule, RuleModuleIdentity {
    bytes32 private identityVersion;

    function setIdentityVersion(bytes32 identityVersion_) external {
        identityVersion = identityVersion_;
    }

    function applicationId() external pure returns (bytes32) {
        return M14AuthorityParityTypes.APP_ID;
    }

    function validateGovernedObject(GovernedObjectContext calldata context) external pure {
        if (
            context.appId != M14AuthorityParityTypes.APP_ID || context.roleKey != M14AuthorityParityTypes.SUBMITTER_ROLE
                || context.objectTypeKey != M14AuthorityParityTypes.OBJECT_TYPE || context.parentObjectId != 0
                || context.subjectId != context.authorityId
        ) revert AVACoreTypes.InvalidState(context.packageId);
    }

    function validateRecognisedStateFormation(RecognisedStateFormationContext calldata context) external pure {
        if (
            context.appId != M14AuthorityParityTypes.APP_ID || context.roleKey != M14AuthorityParityTypes.VERIFIER_ROLE
                || context.objectTypeKey != M14AuthorityParityTypes.OBJECT_TYPE
                || context.stage != AVACoreTypes.Stage.Verification
                || context.status != AVACoreTypes.RecognisedStateStatus.Provisional
        ) revert AVACoreTypes.InvalidState(context.governedObjectId);
    }

    function validateRecognisedStateTransition(RecognisedStateTransitionContext calldata) external pure {}

    function validateEvidence(EvidenceContext calldata context) external pure {
        if (context.appId != M14AuthorityParityTypes.APP_ID || context.subjectId != context.authorityId) {
            revert AVACoreTypes.InvalidState(context.packageId);
        }
    }

    function validateDownstreamRecord(DownstreamRecordContext calldata) external pure {}

    function _moduleConfigurationHash() internal view override returns (bytes32) {
        return keccak256(abi.encode(M14AuthorityParityTypes.APP_ID, identityVersion));
    }
}

contract M14MutablePackageIdentityModule is RuleModuleIdentity {
    bytes32 private identityVersion;

    function setIdentityVersion(bytes32 identityVersion_) external {
        identityVersion = identityVersion_;
    }

    function _moduleConfigurationHash() internal view override returns (bytes32) {
        return identityVersion;
    }
}

contract M14AuthorityParityTest is M14CorePackageFixture {
    M14AuthorityParityVm private constant VM =
        M14AuthorityParityVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant PACKAGE_SUBJECT = keccak256("m14.authority-parity.package-subject");
    bytes32 private constant TARGET_SUBJECT = keccak256("m14.authority-parity.target-subject");
    bytes32 private constant VERIFIER_SUBJECT = keccak256("m14.authority-parity.verifier-subject");
    bytes32 private constant APPROVER_ONE_SUBJECT = keccak256("m14.authority-parity.approver-one");
    bytes32 private constant APPROVER_TWO_SUBJECT = keccak256("m14.authority-parity.approver-two");
    bytes32 private constant APPROVER_THREE_SUBJECT = keccak256("m14.authority-parity.approver-three");
    bytes32 private constant TARGET_PANEL_SUBJECT = keccak256("m14.authority-parity.target-panel-subject");
    bytes32 private constant COMPATIBILITY_KEY = keccak256("m14.authority-parity.compatibility");

    address private constant TARGET_ACCOUNT = address(0xA11CE);
    address private constant VERIFIER_ACCOUNT = address(0xB0B);
    address private constant APPROVER_ONE = address(0xCAFE01);
    address private constant APPROVER_TWO = address(0xCAFE02);
    address private constant APPROVER_THREE = address(0xCAFE03);

    AVAIdentityRegistry private identityRegistry;
    AVAAuthorityMatrix private authorityMatrix;
    AVACoreRulePackageRegistry private packageRegistry;
    AVADisclosurePolicyRegistry private disclosureRegistry;
    AVAEvidenceRegistry private evidenceRegistry;
    AVAGovernanceKernel private kernel;
    AVAChallengeExtension private challengeExtension;
    AVAApprovalReceiptExtension private approvalRegistry;
    ApprovalReceiptAuthorityPolicyModule private thresholdModule;
    M14AuthorityParityApplicationModule private applicationModule;
    DefaultAVAApprovalPolicyModule private approvalPolicy;
    DefaultAVAPackageLifecyclePolicyModule private lifecyclePolicy;
    AVARulePackageLifecycleExtension private lifecycleExtension;
    AVAPackageReadinessExtension private readinessExtension;
    uint256 private packageId;
    uint256 private policyId;
    uint256 private recognisedStateId;
    uint256 private targetEvidenceId;
    uint256 private approverOneEvidenceId;
    uint256 private approverTwoEvidenceId;

    function setUp() public {
        AVAApplicationRegistry applicationRegistry = new AVAApplicationRegistry();
        applicationModule = new M14AuthorityParityApplicationModule();
        applicationRegistry.registerApplication(
            M14AuthorityParityTypes.APP_ID,
            applicationModule.moduleIdentityHash(),
            PACKAGE_SUBJECT,
            "ipfs://m14-authority-parity-app"
        );
        identityRegistry = new AVAIdentityRegistry(applicationRegistry);
        authorityMatrix = new AVAAuthorityMatrix(applicationRegistry, identityRegistry);
        packageRegistry = new AVACoreRulePackageRegistry(applicationRegistry, authorityMatrix);
        disclosureRegistry = new AVADisclosurePolicyRegistry(applicationRegistry, authorityMatrix);
        evidenceRegistry =
            new AVAEvidenceRegistry(authorityMatrix, identityRegistry, packageRegistry, disclosureRegistry);
        kernel = new AVAGovernanceKernel(
            authorityMatrix,
            identityRegistry,
            packageRegistry,
            evidenceRegistry,
            disclosureRegistry,
            new AVAWorkflowPolicyRouter(packageRegistry, evidenceRegistry, disclosureRegistry)
        );
        challengeExtension =
            new AVAChallengeExtension(kernel, authorityMatrix, identityRegistry, packageRegistry, evidenceRegistry);
        approvalRegistry = new AVAApprovalReceiptExtension(
            authorityMatrix, identityRegistry, packageRegistry, evidenceRegistry, kernel, challengeExtension
        );
        thresholdModule = new ApprovalReceiptAuthorityPolicyModule(
            approvalRegistry,
            M14AuthorityParityTypes.PANEL_ROLE,
            AVACoreTypes.ACTION_TRANSITION_RECOGNISED_STATE,
            AVAApprovalReceiptExtension.ApprovalTargetKind.RecognisedState,
            2
        );

        _assignSubjects();
        _setPermissions();
        approvalPolicy = new DefaultAVAApprovalPolicyModule();
        lifecyclePolicy = new DefaultAVAPackageLifecyclePolicyModule();
        packageId = packageRegistry.registerRulePackage(
            _corePackageInput(
                M14AuthorityParityTypes.APP_ID,
                M14AuthorityParityTypes.WORKFLOW,
                M14AuthorityParityTypes.PACKAGE_ROLE,
                PACKAGE_SUBJECT,
                1,
                COMPATIBILITY_KEY,
                "ipfs://m14-authority-parity-package"
            ),
            _authorityBindings(
                _coreBindings(applicationModule),
                address(thresholdModule),
                address(approvalPolicy),
                address(lifecyclePolicy)
            )
        );
        lifecycleExtension = new AVARulePackageLifecycleExtension(authorityMatrix, packageRegistry);
        readinessExtension = new AVAPackageReadinessExtension(
            authorityMatrix,
            identityRegistry,
            packageRegistry,
            evidenceRegistry,
            disclosureRegistry,
            kernel,
            lifecycleExtension
        );
        policyId = disclosureRegistry.registerPolicy(
            M14AuthorityParityTypes.APP_ID,
            M14AuthorityParityTypes.PACKAGE_ROLE,
            PACKAGE_SUBJECT,
            keccak256("m14-authority-parity-policy"),
            "authority parity",
            "ipfs://m14-authority-parity-policy"
        );
        recognisedStateId = _createRecognisedState();
        approverOneEvidenceId = _registerEvidence(APPROVER_ONE, APPROVER_ONE_SUBJECT, "approver-one");
        approverTwoEvidenceId = _registerEvidence(APPROVER_TWO, APPROVER_TWO_SUBJECT, "approver-two");
    }

    function testParityApprovalReceiptsAreTargetDecisionRoleAndPackageBound() public {
        AVACoreTypes.RecognisedStateRecord memory state = kernel.getRecognisedState(recognisedStateId);
        bytes32 decisionHash = keccak256("m14-authority-parity-decision");
        _recordApproval(APPROVER_ONE, APPROVER_ONE_SUBJECT, approverOneEvidenceId, state.lastTransitionId, decisionHash);

        IAVAAuthorityPolicyModule.AuthorityContext memory context = IAVAAuthorityPolicyModule.AuthorityContext({
            appId: M14AuthorityParityTypes.APP_ID,
            workflowKey: M14AuthorityParityTypes.WORKFLOW,
            packageId: packageId,
            actionKey: AVACoreTypes.ACTION_TRANSITION_RECOGNISED_STATE,
            roleKey: M14AuthorityParityTypes.PANEL_ROLE,
            stage: AVACoreTypes.Stage.Verification,
            objectTypeKey: M14AuthorityParityTypes.OBJECT_TYPE,
            targetId: recognisedStateId,
            targetSubjectId: TARGET_SUBJECT,
            authorityId: APPROVER_ONE_SUBJECT,
            decisionHash: decisionHash,
            actor: APPROVER_ONE
        });
        (bool oneApprovalOk,) = address(thresholdModule)
            .staticcall(abi.encodeCall(ApprovalReceiptAuthorityPolicyModule.validateAuthority, (context)));
        require(!oneApprovalOk, "threshold passed with one approval");

        _recordApproval(APPROVER_TWO, APPROVER_TWO_SUBJECT, approverTwoEvidenceId, state.lastTransitionId, decisionHash);
        thresholdModule.validateAuthority(context);
        require(
            approvalRegistry.approvalCount(
                packageId,
                AVAApprovalReceiptExtension.ApprovalTargetKind.RecognisedState,
                recognisedStateId,
                AVACoreTypes.ACTION_TRANSITION_RECOGNISED_STATE,
                decisionHash,
                M14AuthorityParityTypes.PANEL_ROLE
            ) == 2,
            "wrong approval count"
        );
    }

    function testPerformanceAuthorityThresholdStopsAfterRequiredActiveApprovals() public {
        identityRegistry.assignSubject(
            APPROVER_THREE,
            M14AuthorityParityTypes.APP_ID,
            M14AuthorityParityTypes.PANEL_ROLE,
            APPROVER_THREE_SUBJECT,
            "ipfs://m14-authority-parity-approver-three"
        );
        uint256 approverThreeEvidenceId = _registerEvidence(APPROVER_THREE, APPROVER_THREE_SUBJECT, "approver-three");
        AVACoreTypes.RecognisedStateRecord memory state = kernel.getRecognisedState(recognisedStateId);
        bytes32 decisionHash = keccak256("performance-authority-threshold-decision");
        _recordApproval(APPROVER_ONE, APPROVER_ONE_SUBJECT, approverOneEvidenceId, state.lastTransitionId, decisionHash);
        _recordApproval(APPROVER_TWO, APPROVER_TWO_SUBJECT, approverTwoEvidenceId, state.lastTransitionId, decisionHash);
        _recordApproval(
            APPROVER_THREE, APPROVER_THREE_SUBJECT, approverThreeEvidenceId, state.lastTransitionId, decisionHash
        );
        VM.expectCall(
            address(kernel),
            abi.encodeCall(AVAGovernanceKernel.getRecognisedStateReference, (recognisedStateId)),
            1
        );
        VM.expectCall(address(kernel), abi.encodeCall(AVAGovernanceKernel.getRecognisedState, (recognisedStateId)), 0);
        VM.expectCall(
            address(evidenceRegistry),
            abi.encodeCall(AVAEvidenceRegistry.getEvidenceReference, (approverOneEvidenceId)),
            1
        );
        VM.expectCall(
            address(evidenceRegistry),
            abi.encodeCall(AVAEvidenceRegistry.getEvidenceReference, (approverTwoEvidenceId)),
            1
        );
        VM.expectCall(
            address(evidenceRegistry), abi.encodeCall(AVAEvidenceRegistry.getEvidence, (approverOneEvidenceId)), 0
        );
        VM.expectCall(
            address(evidenceRegistry), abi.encodeCall(AVAEvidenceRegistry.getEvidence, (approverTwoEvidenceId)), 0
        );
        VM.expectCall(
            address(identityRegistry), abi.encodeCall(AVAIdentityRegistry.getSubject, (APPROVER_THREE_SUBJECT)), 0
        );
        thresholdModule.validateAuthority(
            IAVAAuthorityPolicyModule.AuthorityContext({
                appId: M14AuthorityParityTypes.APP_ID,
                workflowKey: M14AuthorityParityTypes.WORKFLOW,
                packageId: packageId,
                actionKey: AVACoreTypes.ACTION_TRANSITION_RECOGNISED_STATE,
                roleKey: M14AuthorityParityTypes.PANEL_ROLE,
                stage: AVACoreTypes.Stage.Verification,
                objectTypeKey: M14AuthorityParityTypes.OBJECT_TYPE,
                targetId: recognisedStateId,
                targetSubjectId: TARGET_SUBJECT,
                authorityId: APPROVER_ONE_SUBJECT,
                decisionHash: decisionHash,
                actor: APPROVER_ONE
            })
        );
    }

    function testPerformanceApprovalRecordingRevalidatesPackageIdentityOnce() public {
        AVACoreTypes.RecognisedStateRecord memory state = kernel.getRecognisedState(recognisedStateId);
        VM.expectCall(address(applicationModule), abi.encodeCall(RuleModuleIdentity.moduleIdentityHash, ()), 1);
        _recordApproval(
            APPROVER_ONE,
            APPROVER_ONE_SUBJECT,
            approverOneEvidenceId,
            state.lastTransitionId,
            keccak256("performance-approval-recording-decision")
        );
    }

    function testHasActiveApprovalFailsClosedAfterPackageIdentityDrift() public {
        AVACoreTypes.RecognisedStateRecord memory state = kernel.getRecognisedState(recognisedStateId);
        bytes32 decisionHash = keccak256("m14-active-approval-package-identity-drift");
        _recordApproval(APPROVER_ONE, APPROVER_ONE_SUBJECT, approverOneEvidenceId, state.lastTransitionId, decisionHash);
        require(
            approvalRegistry.hasActiveApproval(
                packageId,
                AVAApprovalReceiptExtension.ApprovalTargetKind.RecognisedState,
                recognisedStateId,
                AVACoreTypes.ACTION_TRANSITION_RECOGNISED_STATE,
                decisionHash,
                M14AuthorityParityTypes.PANEL_ROLE,
                APPROVER_ONE_SUBJECT
            ),
            "active approval missing before package drift"
        );

        applicationModule.setIdentityVersion(keccak256("m14-authority-parity-identity-v2"));
        bool querySucceeded;
        try approvalRegistry.hasActiveApproval(
            packageId,
            AVAApprovalReceiptExtension.ApprovalTargetKind.RecognisedState,
            recognisedStateId,
            AVACoreTypes.ACTION_TRANSITION_RECOGNISED_STATE,
            decisionHash,
            M14AuthorityParityTypes.PANEL_ROLE,
            APPROVER_ONE_SUBJECT
        ) returns (bool) {
            querySucceeded = true;
        } catch {}

        require(!querySucceeded, "active approval query ignored package identity drift");
    }

    function testPerformanceCanonicalAuthorityResolvesSubjectOnce() public {
        VM.expectCall(
            address(identityRegistry),
            abi.encodeCall(
                AVAIdentityRegistry.subjectOf,
                (
                    TARGET_ACCOUNT,
                    M14AuthorityParityTypes.APP_ID,
                    M14AuthorityParityTypes.SUBMITTER_ROLE
                )
            ),
            1
        );
        bytes32 subjectId = authorityMatrix.requireAuthorisedCanonicalSubject(
            TARGET_ACCOUNT,
            M14AuthorityParityTypes.APP_ID,
            M14AuthorityParityTypes.SUBMITTER_ROLE,
            AVACoreTypes.ACTION_REGISTER_GOVERNED_OBJECT
        );
        require(subjectId == TARGET_SUBJECT, "wrong canonical authority subject");
    }

    function testParityApprovalRejectsTargetAccountAndStaleTargetVersion() public {
        uint256 targetPanelEvidenceId = _registerEvidence(TARGET_ACCOUNT, TARGET_PANEL_SUBJECT, "target-panel");
        AVACoreTypes.RecognisedStateRecord memory state = kernel.getRecognisedState(recognisedStateId);
        AVAApprovalReceiptExtension.ApprovalInput memory input = _approvalInput(
            TARGET_PANEL_SUBJECT,
            targetPanelEvidenceId,
            state.lastTransitionId,
            keccak256("m14-authority-conflicted-decision")
        );
        VM.prank(TARGET_ACCOUNT);
        (bool conflictedOk,) =
            address(approvalRegistry).call(abi.encodeCall(AVAApprovalReceiptExtension.recordApproval, (input)));
        require(!conflictedOk, "target account approval accepted");

        input.authorityId = APPROVER_ONE_SUBJECT;
        input.evidenceId = approverOneEvidenceId;
        input.expectedTargetVersionId = state.lastTransitionId + 1;
        VM.prank(APPROVER_ONE);
        (bool staleOk,) =
            address(approvalRegistry).call(abi.encodeCall(AVAApprovalReceiptExtension.recordApproval, (input)));
        require(!staleOk, "future target version approval accepted");
    }

    function testParityApprovalStopsCountingAfterAuthoritySubjectDeactivation() public {
        AVACoreTypes.RecognisedStateRecord memory state = kernel.getRecognisedState(recognisedStateId);
        bytes32 decisionHash = keccak256("m14-authority-deactivated-approval");
        _recordApproval(APPROVER_ONE, APPROVER_ONE_SUBJECT, approverOneEvidenceId, state.lastTransitionId, decisionHash);
        require(
            approvalRegistry.approvalCount(
                packageId,
                AVAApprovalReceiptExtension.ApprovalTargetKind.RecognisedState,
                recognisedStateId,
                AVACoreTypes.ACTION_TRANSITION_RECOGNISED_STATE,
                decisionHash,
                M14AuthorityParityTypes.PANEL_ROLE
            ) == 1,
            "active authority approval missing"
        );

        identityRegistry.deactivateSubject(APPROVER_ONE_SUBJECT);

        require(
            approvalRegistry.approvalCount(
                packageId,
                AVAApprovalReceiptExtension.ApprovalTargetKind.RecognisedState,
                recognisedStateId,
                AVACoreTypes.ACTION_TRANSITION_RECOGNISED_STATE,
                decisionHash,
                M14AuthorityParityTypes.PANEL_ROLE
            ) == 0,
            "deactivated authority approval remained active"
        );
    }

    function testParityExpiredApprovalCanBeReissuedAppendOnly() public {
        AVACoreTypes.RecognisedStateRecord memory state = kernel.getRecognisedState(recognisedStateId);
        bytes32 decisionHash = keccak256("m14-authority-reissued-approval");
        AVAApprovalReceiptExtension.ApprovalInput memory input =
            _approvalInput(APPROVER_ONE_SUBJECT, approverOneEvidenceId, state.lastTransitionId, decisionHash);
        input.validUntil = uint64(block.timestamp + 1);
        VM.prank(APPROVER_ONE);
        uint256 firstId = approvalRegistry.recordApproval(input);

        VM.warp(block.timestamp + 2);
        input.validUntil = uint64(block.timestamp + 1 days);
        input.reasonHash = keccak256("m14-authority-reissued-approval-second");
        VM.prank(APPROVER_ONE);
        uint256 secondId = approvalRegistry.recordApproval(input);

        require(secondId > firstId, "reissued approval did not append");
        require(
            approvalRegistry.approvalCount(
                packageId,
                AVAApprovalReceiptExtension.ApprovalTargetKind.RecognisedState,
                recognisedStateId,
                AVACoreTypes.ACTION_TRANSITION_RECOGNISED_STATE,
                decisionHash,
                M14AuthorityParityTypes.PANEL_ROLE
            ) == 1,
            "reissued approval counted incorrectly"
        );
    }

    function testParityExpiredApprovalReissueKeepsOneBoundedAuthoritySlot() public {
        AVACoreTypes.RecognisedStateRecord memory state = kernel.getRecognisedState(recognisedStateId);
        bytes32 decisionHash = keccak256("m14-authority-bounded-reissue");
        AVAApprovalReceiptExtension.ApprovalInput memory input =
            _approvalInput(APPROVER_ONE_SUBJECT, approverOneEvidenceId, state.lastTransitionId, decisionHash);
        input.validUntil = uint64(block.timestamp + 1);
        VM.prank(APPROVER_ONE);
        approvalRegistry.recordApproval(input);

        VM.warp(block.timestamp + 2);
        input.validUntil = uint64(block.timestamp + 1 days);
        input.reasonHash = keccak256("m14-authority-bounded-reissue-second");
        VM.prank(APPROVER_ONE);
        approvalRegistry.recordApproval(input);

        require(
            approvalRegistry.approvalAuthorityCount(
                packageId,
                AVAApprovalReceiptExtension.ApprovalTargetKind.RecognisedState,
                recognisedStateId,
                AVACoreTypes.ACTION_TRANSITION_RECOGNISED_STATE,
                decisionHash,
                M14AuthorityParityTypes.PANEL_ROLE
            ) == 1,
            "reissue expanded approval traversal set"
        );
    }

    function testParityAuthorityPolicyRejectsThresholdAboveBoundedApproverSet() public {
        bool accepted;
        try new ApprovalReceiptAuthorityPolicyModule(
            approvalRegistry,
            M14AuthorityParityTypes.PANEL_ROLE,
            AVACoreTypes.ACTION_TRANSITION_RECOGNISED_STATE,
            AVAApprovalReceiptExtension.ApprovalTargetKind.RecognisedState,
            approvalRegistry.MAX_APPROVERS_PER_DECISION() + 1
        ) returns (
            ApprovalReceiptAuthorityPolicyModule
        ) {
            accepted = true;
        } catch {}
        require(!accepted, "authority policy accepted unreachable approval threshold");
    }

    function testParityApprovalRegistryRejectsSixtyFifthUniqueAuthorityBeforeReceiptWrite() public {
        AVACoreTypes.RecognisedStateRecord memory state = kernel.getRecognisedState(recognisedStateId);
        bytes32 decisionHash = keccak256("m14-authority-sixty-four-subject-bound");
        uint256 limit = approvalRegistry.MAX_APPROVERS_PER_DECISION();

        for (uint256 i; i < limit; ++i) {
            address account = address(uint160(0x100000 + i));
            bytes32 authorityId = keccak256(abi.encode("m14-authority-bounded-subject", i));
            identityRegistry.assignSubject(
                account,
                M14AuthorityParityTypes.APP_ID,
                M14AuthorityParityTypes.PANEL_ROLE,
                authorityId,
                "ipfs://m14-authority-bounded-subject"
            );
            VM.prank(account);
            uint256 evidenceId = evidenceRegistry.registerEvidence(
                AVAEvidenceRegistry.EvidenceRegistrationInput({
                    appId: M14AuthorityParityTypes.APP_ID,
                    workflowKey: M14AuthorityParityTypes.WORKFLOW,
                    packageId: packageId,
                    roleKey: M14AuthorityParityTypes.PANEL_ROLE,
                    subjectId: authorityId,
                    commitment: keccak256(abi.encode("m14-authority-bounded-evidence", i)),
                    evidenceTypeHash: keccak256("m14-authority-parity-evidence-type"),
                    disclosurePolicyId: policyId,
                    authorityId: authorityId,
                    uri: "ipfs://m14-authority-bounded-evidence"
                })
            );
            VM.prank(account);
            approvalRegistry.recordApproval(
                _approvalInput(authorityId, evidenceId, state.lastTransitionId, decisionHash)
            );
        }

        address overflowAccount = address(uint160(0x200000));
        bytes32 overflowAuthorityId = keccak256("m14-authority-overflow-subject");
        identityRegistry.assignSubject(
            overflowAccount,
            M14AuthorityParityTypes.APP_ID,
            M14AuthorityParityTypes.PANEL_ROLE,
            overflowAuthorityId,
            "ipfs://m14-authority-overflow-subject"
        );
        VM.prank(overflowAccount);
        uint256 overflowEvidenceId = evidenceRegistry.registerEvidence(
            AVAEvidenceRegistry.EvidenceRegistrationInput({
                appId: M14AuthorityParityTypes.APP_ID,
                workflowKey: M14AuthorityParityTypes.WORKFLOW,
                packageId: packageId,
                roleKey: M14AuthorityParityTypes.PANEL_ROLE,
                subjectId: overflowAuthorityId,
                commitment: keccak256("m14-authority-overflow-evidence"),
                evidenceTypeHash: keccak256("m14-authority-parity-evidence-type"),
                disclosurePolicyId: policyId,
                authorityId: overflowAuthorityId,
                uri: "ipfs://m14-authority-overflow-evidence"
            })
        );
        bool overflowAccepted;
        VM.prank(overflowAccount);
        try approvalRegistry.recordApproval(
            _approvalInput(overflowAuthorityId, overflowEvidenceId, state.lastTransitionId, decisionHash)
        ) returns (
            uint256
        ) {
            overflowAccepted = true;
        } catch {}

        require(!overflowAccepted, "sixty-fifth unique authority was accepted");
        require(
            approvalRegistry.approvalAuthorityCount(
                packageId,
                AVAApprovalReceiptExtension.ApprovalTargetKind.RecognisedState,
                recognisedStateId,
                AVACoreTypes.ACTION_TRANSITION_RECOGNISED_STATE,
                decisionHash,
                M14AuthorityParityTypes.PANEL_ROLE
            ) == limit,
            "bounded authority set changed after rejection"
        );
        require(approvalRegistry.nextApprovalReceiptId() == limit + 1, "rejected authority consumed receipt id");
    }

    function testParityPackageReadinessBindsSourceStateTargetPackageEvidenceAndPolicy() public {
        uint256 packageV2 = packageRegistry.supersedeRulePackage(
            _corePackageInput(
                M14AuthorityParityTypes.APP_ID,
                M14AuthorityParityTypes.WORKFLOW,
                M14AuthorityParityTypes.PACKAGE_ROLE,
                PACKAGE_SUBJECT,
                2,
                COMPATIBILITY_KEY,
                "ipfs://m14-authority-parity-package-v2"
            ),
            packageId,
            _authorityBindings(
                _coreBindings(applicationModule),
                address(thresholdModule),
                address(approvalPolicy),
                address(lifecyclePolicy)
            )
        );
        uint256 lifecycleId = lifecycleExtension.recordPackageLifecycle(
            AVARulePackageLifecycleExtension.PackageLifecycleInput({
                sourcePackageId: packageId,
                targetPackageId: packageV2,
                roleKey: M14AuthorityParityTypes.PACKAGE_ROLE,
                authorityId: PACKAGE_SUBJECT,
                kind: AVARulePackageLifecycleExtension.PackageLifecycleKind.MigrationReady,
                reasonHash: keccak256("m14-package-migration-ready"),
                uri: "ipfs://m14-package-migration-ready"
            })
        );
        uint256 objectReadinessId = readinessExtension.recordObjectMigrationReadiness(
            AVAPackageReadinessExtension.ObjectMigrationReadinessInput({
                lifecycleRecordId: lifecycleId,
                recognisedStateId: recognisedStateId,
                targetPackageId: packageV2,
                roleKey: M14AuthorityParityTypes.PACKAGE_ROLE,
                authorityId: PACKAGE_SUBJECT,
                evidenceId: targetEvidenceId,
                reasonHash: keccak256("m14-object-migration-ready"),
                uri: "ipfs://m14-object-migration-ready"
            })
        );
        AVAPackageReadinessExtension.ObjectMigrationReadinessRecord memory objectRecord =
            readinessExtension.getObjectMigrationReadinessRecord(objectReadinessId);
        require(objectRecord.sourcePackageId == packageId, "wrong readiness source");
        require(objectRecord.targetPackageId == packageV2, "wrong readiness target");
        require(objectRecord.recognisedStateId == recognisedStateId, "wrong readiness state");

        uint256 disclosureReadinessId = readinessExtension.recordDisclosureLifecycleReadiness(
            AVAPackageReadinessExtension.DisclosureLifecycleReadinessInput({
                packageId: packageId,
                disclosurePolicyId: policyId,
                subjectId: TARGET_SUBJECT,
                evidenceId: targetEvidenceId,
                lifecycleKindKey: keccak256("m14-disclosure-readiness"),
                roleKey: M14AuthorityParityTypes.PACKAGE_ROLE,
                authorityId: PACKAGE_SUBJECT,
                reasonHash: keccak256("m14-disclosure-ready"),
                uri: "ipfs://m14-disclosure-ready"
            })
        );
        AVAPackageReadinessExtension.DisclosureLifecycleReadinessRecord memory disclosureRecord =
            readinessExtension.getDisclosureLifecycleReadinessRecord(disclosureReadinessId);
        require(disclosureRecord.packageId == packageId, "wrong disclosure package");
        require(disclosureRecord.disclosurePolicyId == policyId, "wrong disclosure policy");
        require(disclosureRecord.evidenceId == targetEvidenceId, "wrong disclosure evidence");
    }

    function testObjectMigrationReadinessRejectsTargetPackageIdentityDrift() public {
        M14MutablePackageIdentityModule mutableTargetModule = new M14MutablePackageIdentityModule();
        AVACoreRulePackageRegistry.ModuleBinding[] memory bindings = _authorityBindings(
            _coreBindings(applicationModule),
            address(thresholdModule),
            address(approvalPolicy),
            address(lifecyclePolicy)
        );
        for (uint256 i; i < bindings.length; ++i) {
            if (bindings[i].capabilityKey == AVACapabilityKeys.STANDING_COMPUTATION) {
                bindings[i] = _coreBinding(AVACapabilityKeys.STANDING_COMPUTATION, address(mutableTargetModule));
                break;
            }
        }
        uint256 packageV2 = packageRegistry.supersedeRulePackage(
            _corePackageInput(
                M14AuthorityParityTypes.APP_ID,
                M14AuthorityParityTypes.WORKFLOW,
                M14AuthorityParityTypes.PACKAGE_ROLE,
                PACKAGE_SUBJECT,
                2,
                COMPATIBILITY_KEY,
                "ipfs://m14-authority-parity-drifting-package-v2"
            ),
            packageId,
            bindings
        );
        uint256 lifecycleId = lifecycleExtension.recordPackageLifecycle(
            AVARulePackageLifecycleExtension.PackageLifecycleInput({
                sourcePackageId: packageId,
                targetPackageId: packageV2,
                roleKey: M14AuthorityParityTypes.PACKAGE_ROLE,
                authorityId: PACKAGE_SUBJECT,
                kind: AVARulePackageLifecycleExtension.PackageLifecycleKind.MigrationReady,
                reasonHash: keccak256("m14-target-package-before-identity-drift"),
                uri: "ipfs://m14-target-package-before-identity-drift"
            })
        );

        mutableTargetModule.setIdentityVersion(keccak256("m14-target-package-after-identity-drift"));

        bool accepted;
        try readinessExtension.recordObjectMigrationReadiness(
            AVAPackageReadinessExtension.ObjectMigrationReadinessInput({
                lifecycleRecordId: lifecycleId,
                recognisedStateId: recognisedStateId,
                targetPackageId: packageV2,
                roleKey: M14AuthorityParityTypes.PACKAGE_ROLE,
                authorityId: PACKAGE_SUBJECT,
                evidenceId: targetEvidenceId,
                reasonHash: keccak256("m14-object-migration-to-invalid-target"),
                uri: "ipfs://m14-object-migration-to-invalid-target"
            })
        ) returns (
            uint256
        ) {
            accepted = true;
        } catch {}

        require(!accepted, "migration readiness accepted identity-drifted target package");
    }

    function testPerformanceDisclosureReadinessRevalidatesPackageOnce() public {
        VM.expectCall(address(applicationModule), abi.encodeCall(RuleModuleIdentity.moduleIdentityHash, ()), 1);
        uint256 recordId = readinessExtension.recordDisclosureLifecycleReadiness(
            AVAPackageReadinessExtension.DisclosureLifecycleReadinessInput({
                packageId: packageId,
                disclosurePolicyId: policyId,
                subjectId: TARGET_SUBJECT,
                evidenceId: targetEvidenceId,
                lifecycleKindKey: keccak256("performance-disclosure-readiness"),
                roleKey: M14AuthorityParityTypes.PACKAGE_ROLE,
                authorityId: PACKAGE_SUBJECT,
                reasonHash: keccak256("performance-disclosure-readiness"),
                uri: "ipfs://performance-disclosure-readiness"
            })
        );
        require(readinessExtension.getDisclosureLifecycleReadinessRecord(recordId).packageId == packageId, "package changed");
    }

    function _assignSubjects() private {
        identityRegistry.assignSubject(
            address(this),
            M14AuthorityParityTypes.APP_ID,
            M14AuthorityParityTypes.PACKAGE_ROLE,
            PACKAGE_SUBJECT,
            "ipfs://package-subject"
        );
        identityRegistry.assignSubject(
            TARGET_ACCOUNT,
            M14AuthorityParityTypes.APP_ID,
            M14AuthorityParityTypes.SUBMITTER_ROLE,
            TARGET_SUBJECT,
            "ipfs://target-subject"
        );
        identityRegistry.assignSubject(
            TARGET_ACCOUNT,
            M14AuthorityParityTypes.APP_ID,
            M14AuthorityParityTypes.PANEL_ROLE,
            TARGET_PANEL_SUBJECT,
            "ipfs://target-panel-subject"
        );
        identityRegistry.assignSubject(
            VERIFIER_ACCOUNT,
            M14AuthorityParityTypes.APP_ID,
            M14AuthorityParityTypes.VERIFIER_ROLE,
            VERIFIER_SUBJECT,
            "ipfs://verifier-subject"
        );
        identityRegistry.assignSubject(
            APPROVER_ONE,
            M14AuthorityParityTypes.APP_ID,
            M14AuthorityParityTypes.PANEL_ROLE,
            APPROVER_ONE_SUBJECT,
            "ipfs://approver-one"
        );
        identityRegistry.assignSubject(
            APPROVER_TWO,
            M14AuthorityParityTypes.APP_ID,
            M14AuthorityParityTypes.PANEL_ROLE,
            APPROVER_TWO_SUBJECT,
            "ipfs://approver-two"
        );
    }

    function _setPermissions() private {
        authorityMatrix.setPermission(
            M14AuthorityParityTypes.APP_ID,
            M14AuthorityParityTypes.PACKAGE_ROLE,
            AVACoreTypes.ACTION_REGISTER_RULE_PACKAGE,
            true
        );
        authorityMatrix.setPermission(
            M14AuthorityParityTypes.APP_ID,
            M14AuthorityParityTypes.PACKAGE_ROLE,
            AVACoreTypes.ACTION_REGISTER_DISCLOSURE_POLICY,
            true
        );
        authorityMatrix.setPermission(
            M14AuthorityParityTypes.APP_ID,
            M14AuthorityParityTypes.PACKAGE_ROLE,
            AVACoreTypes.ACTION_RECORD_PACKAGE_LIFECYCLE,
            true
        );
        authorityMatrix.setPermission(
            M14AuthorityParityTypes.APP_ID,
            M14AuthorityParityTypes.PACKAGE_ROLE,
            AVACoreTypes.ACTION_RECORD_OBJECT_MIGRATION_READINESS,
            true
        );
        authorityMatrix.setPermission(
            M14AuthorityParityTypes.APP_ID,
            M14AuthorityParityTypes.PACKAGE_ROLE,
            AVACoreTypes.ACTION_RECORD_DISCLOSURE_LIFECYCLE_READINESS,
            true
        );
        authorityMatrix.setPermission(
            M14AuthorityParityTypes.APP_ID,
            M14AuthorityParityTypes.SUBMITTER_ROLE,
            AVACoreTypes.ACTION_REGISTER_EVIDENCE,
            true
        );
        authorityMatrix.setPermission(
            M14AuthorityParityTypes.APP_ID,
            M14AuthorityParityTypes.SUBMITTER_ROLE,
            AVACoreTypes.ACTION_REGISTER_GOVERNED_OBJECT,
            true
        );
        authorityMatrix.setPermission(
            M14AuthorityParityTypes.APP_ID,
            M14AuthorityParityTypes.VERIFIER_ROLE,
            AVACoreTypes.ACTION_FORM_RECOGNISED_STATE,
            true
        );
        authorityMatrix.setPermission(
            M14AuthorityParityTypes.APP_ID,
            M14AuthorityParityTypes.PANEL_ROLE,
            AVACoreTypes.ACTION_REGISTER_EVIDENCE,
            true
        );
        authorityMatrix.setPermission(
            M14AuthorityParityTypes.APP_ID,
            M14AuthorityParityTypes.PANEL_ROLE,
            AVACoreTypes.ACTION_RECORD_APPROVAL_RECEIPT,
            true
        );
    }

    function _createRecognisedState() private returns (uint256 stateId) {
        targetEvidenceId = _registerEvidence(TARGET_ACCOUNT, TARGET_SUBJECT, "target");
        VM.prank(TARGET_ACCOUNT);
        uint256 objectId = kernel.registerGovernedObject(
            AVAGovernanceKernel.GovernedObjectInput({
                appId: M14AuthorityParityTypes.APP_ID,
                workflowKey: M14AuthorityParityTypes.WORKFLOW,
                packageId: packageId,
                roleKey: M14AuthorityParityTypes.SUBMITTER_ROLE,
                objectTypeKey: M14AuthorityParityTypes.OBJECT_TYPE,
                objectCommitment: keccak256("m14-authority-parity-object"),
                parentObjectId: 0,
                subjectId: TARGET_SUBJECT,
                evidenceReceiptId: targetEvidenceId,
                disclosurePolicyId: policyId,
                metadataHash: keccak256("m14-authority-parity-object-metadata"),
                uri: "ipfs://m14-authority-parity-object",
                authorityId: TARGET_SUBJECT
            })
        );
        VM.prank(VERIFIER_ACCOUNT);
        stateId = kernel.formRecognisedState(
            AVAGovernanceKernel.RecognisedStateFormationInput({
                governedObjectId: objectId,
                roleKey: M14AuthorityParityTypes.VERIFIER_ROLE,
                stage: AVACoreTypes.Stage.Verification,
                status: AVACoreTypes.RecognisedStateStatus.Provisional,
                authorityId: VERIFIER_SUBJECT,
                reasonHash: keccak256("m14-authority-parity-formation"),
                reasonURI: "ipfs://m14-authority-parity-formation"
            })
        );
    }

    function _registerEvidence(address account, bytes32 subjectId, string memory suffix)
        private
        returns (uint256 evidenceId)
    {
        bytes32 roleKey = account == TARGET_ACCOUNT && subjectId == TARGET_SUBJECT
            ? M14AuthorityParityTypes.SUBMITTER_ROLE
            : M14AuthorityParityTypes.PANEL_ROLE;
        VM.prank(account);
        evidenceId = evidenceRegistry.registerEvidence(
            AVAEvidenceRegistry.EvidenceRegistrationInput({
                appId: M14AuthorityParityTypes.APP_ID,
                workflowKey: M14AuthorityParityTypes.WORKFLOW,
                packageId: packageId,
                roleKey: roleKey,
                subjectId: subjectId,
                commitment: keccak256(bytes(string.concat("m14-authority-parity-evidence-", suffix))),
                evidenceTypeHash: keccak256("m14-authority-parity-evidence-type"),
                disclosurePolicyId: policyId,
                authorityId: subjectId,
                uri: string.concat("ipfs://m14-authority-parity-evidence-", suffix)
            })
        );
    }

    function _recordApproval(
        address approver,
        bytes32 authorityId,
        uint256 evidenceId,
        uint256 expectedVersion,
        bytes32 decisionHash
    ) private {
        AVAApprovalReceiptExtension.ApprovalInput memory input =
            _approvalInput(authorityId, evidenceId, expectedVersion, decisionHash);
        VM.prank(approver);
        approvalRegistry.recordApproval(input);
    }

    function _approvalInput(bytes32 authorityId, uint256 evidenceId, uint256 expectedVersion, bytes32 decisionHash)
        private
        view
        returns (AVAApprovalReceiptExtension.ApprovalInput memory input)
    {
        input = AVAApprovalReceiptExtension.ApprovalInput({
            packageId: packageId,
            targetKind: AVAApprovalReceiptExtension.ApprovalTargetKind.RecognisedState,
            targetId: recognisedStateId,
            expectedTargetVersionId: expectedVersion,
            actionKey: AVACoreTypes.ACTION_TRANSITION_RECOGNISED_STATE,
            decisionHash: decisionHash,
            approvalRoleKey: M14AuthorityParityTypes.PANEL_ROLE,
            authorityId: authorityId,
            evidenceId: evidenceId,
            validUntil: uint64(block.timestamp + 1 days),
            reasonHash: keccak256("m14-authority-parity-approval"),
            uri: "ipfs://m14-authority-parity-approval"
        });
    }

    function _authorityBindings(
        AVACoreRulePackageRegistry.ModuleBinding[] memory base,
        address authorityModule,
        address approvalModule,
        address lifecycleModule
    ) private pure returns (AVACoreRulePackageRegistry.ModuleBinding[] memory bindings) {
        bindings = new AVACoreRulePackageRegistry.ModuleBinding[](base.length + 2);
        for (uint256 i; i < base.length; ++i) {
            bindings[i] = base[i].capabilityKey == AVACapabilityKeys.AUTHORITY_POLICY
                ? _coreBinding(AVACapabilityKeys.AUTHORITY_POLICY, authorityModule)
                : base[i];
        }
        bindings[base.length] = _coreBinding(AVACapabilityKeys.AUTHORITY_APPROVAL, approvalModule);
        bindings[base.length + 1] = _coreBinding(AVACapabilityKeys.PACKAGE_LIFECYCLE, lifecycleModule);
    }
}
