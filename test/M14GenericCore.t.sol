// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVAApplicationRegistry} from "../src/AVAApplicationRegistry.sol";
import {AVAIdentityRegistry} from "../src/core/AVAIdentityRegistry.sol";
import {AVAAuthorityMatrix} from "../src/core/AVAAuthorityMatrix.sol";
import {AVACoreTypes} from "../src/core/AVACoreTypes.sol";
import {AVAGovernanceKernel} from "../src/core/AVAGovernanceKernel.sol";
import {AVADisclosurePolicyRegistry} from "../src/core/AVADisclosurePolicyRegistry.sol";
import {AVAEvidenceRegistry} from "../src/core/AVAEvidenceRegistry.sol";
import {AVACoreRulePackageRegistry} from "../src/core/AVACoreRulePackageRegistry.sol";
import {AVAWorkflowPolicyRouter} from "../src/core/AVAWorkflowPolicyRouter.sol";
import {IAVAApplicationModule} from "../src/interfaces/IAVAApplicationModule.sol";
import {IRuleModuleIdentity, RuleModuleIdentity} from "../src/interfaces/IRuleModuleIdentity.sol";
import {AVAStandingRevisionExtension} from "../src/extensions/standing/AVAStandingRevisionExtension.sol";
import {IAVAStandingRevision} from "../src/extensions/standing/IAVAStandingRevision.sol";
import {AVAStandingRecordExtension} from "../src/extensions/downstream/AVADownstreamRecordExtensions.sol";
import {M14ApplicationFixture, M14PermissiveApplicationModule} from "./helpers/M14ApplicationFixture.sol";
import "./helpers/M14CorePackageFixture.sol";

contract M14GenericAuthorityActor {
    function requireAuthority(
        AVAAuthorityMatrix authorityMatrix,
        bytes32 appId,
        bytes32 roleKey,
        bytes32 actionKey,
        bytes32 authorityId
    ) external view returns (bytes32) {
        return authorityMatrix.requireAuthorisedSubject(address(this), appId, roleKey, actionKey, authorityId);
    }
}

contract M14GenericObjectActor {
    function registerPolicy(
        AVADisclosurePolicyRegistry policyRegistry,
        bytes32 appId,
        bytes32 roleKey,
        bytes32 authorityId,
        bytes32 policyKey
    ) external returns (uint256) {
        return policyRegistry.registerPolicy(
            appId, roleKey, authorityId, policyKey, "m14-generic-policy", "ipfs://m14-generic-policy"
        );
    }

    function registerEvidence(
        AVAEvidenceRegistry evidenceRegistry,
        bytes32 appId,
        bytes32 workflowKey,
        uint256 packageId,
        bytes32 roleKey,
        bytes32 subjectId,
        bytes32 commitment,
        uint256 disclosurePolicyId
    ) external returns (uint256) {
        return evidenceRegistry.registerEvidence(
            AVAEvidenceRegistry.EvidenceRegistrationInput({
                appId: appId,
                workflowKey: workflowKey,
                packageId: packageId,
                roleKey: roleKey,
                subjectId: subjectId,
                commitment: commitment,
                evidenceTypeHash: keccak256("m14-generic-evidence-type"),
                disclosurePolicyId: disclosurePolicyId,
                authorityId: subjectId,
                uri: "ipfs://m14-generic-evidence"
            })
        );
    }

    function registerObject(AVAGovernanceKernel kernel, AVAGovernanceKernel.GovernedObjectInput calldata input)
        external
        returns (uint256)
    {
        return kernel.registerGovernedObject(input);
    }

    function formState(AVAGovernanceKernel kernel, AVAGovernanceKernel.RecognisedStateFormationInput calldata input)
        external
        returns (uint256)
    {
        return kernel.formRecognisedState(input);
    }

    function transitionState(
        AVAGovernanceKernel kernel,
        AVAGovernanceKernel.RecognisedStateTransitionInput calldata input
    ) external returns (uint256) {
        return kernel.transitionRecognisedState(input);
    }

    function vestState(AVAGovernanceKernel kernel, AVAGovernanceKernel.RecognisedStateTransitionInput calldata input)
        external
        returns (uint256)
    {
        return kernel.vestRecognisedState(input);
    }

    function recordStanding(
        AVAStandingRecordExtension extension,
        AVAStandingRecordExtension.StandingInput calldata input
    ) external returns (uint256) {
        return extension.recordStandingUpdate(input);
    }
}

contract M14ZeroIdentityModule is IRuleModuleIdentity {
    function moduleIdentityHash() external pure returns (bytes32) {
        return bytes32(0);
    }
}

contract M14GenericRevisionWriter {
    function advance(
        IAVAStandingRevision revisionRegistry,
        bytes32 appId,
        uint256 packageId,
        bytes32 subjectId,
        uint256 sourceRecordId
    ) external returns (uint256) {
        return revisionRegistry.advanceRevision(
            appId, packageId, subjectId, keccak256("m14.generic-revision-writer"), sourceRecordId
        );
    }
}

contract M14TypedObjectApplicationModule is IAVAApplicationModule, RuleModuleIdentity {
    bytes32 public immutable APP_ID;
    bytes32 public immutable ALLOWED_OBJECT_TYPE;

    constructor(bytes32 appId, bytes32 allowedObjectType) {
        APP_ID = appId;
        ALLOWED_OBJECT_TYPE = allowedObjectType;
    }

    function applicationId() external view returns (bytes32) {
        return APP_ID;
    }

    function validateGovernedObject(GovernedObjectContext calldata context) external view {
        if (context.appId != APP_ID || context.objectTypeKey != ALLOWED_OBJECT_TYPE) {
            revert AVACoreTypes.InvalidState(context.packageId);
        }
    }

    function validateRecognisedStateFormation(RecognisedStateFormationContext calldata context) external view {
        if (context.appId != APP_ID || context.objectTypeKey != ALLOWED_OBJECT_TYPE) {
            revert AVACoreTypes.InvalidState(context.packageId);
        }
    }

    function validateRecognisedStateTransition(RecognisedStateTransitionContext calldata context) external view {
        if (context.appId != APP_ID || context.objectTypeKey != ALLOWED_OBJECT_TYPE) {
            revert AVACoreTypes.InvalidState(context.packageId);
        }
    }

    function validateEvidence(EvidenceContext calldata context) external view {
        if (context.appId != APP_ID) revert AVACoreTypes.InvalidState(context.packageId);
    }

    function validateDownstreamRecord(DownstreamRecordContext calldata context) external view {
        if (context.appId != APP_ID || context.objectTypeKey != ALLOWED_OBJECT_TYPE) {
            revert AVACoreTypes.InvalidState(context.packageId);
        }
    }

    function _moduleConfigurationHash() internal view override returns (bytes32) {
        return keccak256(abi.encode(APP_ID, ALLOWED_OBJECT_TYPE));
    }
}

contract M14GenericIdentityAuthorityTest {
    bytes32 private constant PEER_APP = keccak256("m14.peer-review-app");
    bytes32 private constant SECONDARY_APP = keccak256("m14.secondary-test-app-app");
    bytes32 private constant REVIEWER_ROLE = keccak256("m14.peer-review.reviewer");
    bytes32 private constant CONTRIBUTOR_ROLE = keccak256("m14.secondary-test-app.contributor");
    bytes32 private constant REGISTER_OBJECT = keccak256("ava.core.register-governed-object.v1");
    bytes32 private constant PEER_SUBJECT = keccak256("m14.peer-subject");
    bytes32 private constant SECONDARY_SUBJECT = keccak256("m14.secondary-subject");

    AVAApplicationRegistry private applicationRegistry;
    AVAIdentityRegistry private identityRegistry;
    AVAAuthorityMatrix private authorityMatrix;
    M14GenericAuthorityActor private actor;

    function setUp() public {
        applicationRegistry = new AVAApplicationRegistry();
        applicationRegistry.registerApplication(
            PEER_APP, keccak256("peer-identity"), keccak256("peer-authority"), "ipfs://peer-app"
        );
        applicationRegistry.registerApplication(
            SECONDARY_APP, keccak256("secondary-identity"), keccak256("secondary-authority"), "ipfs://secondary-app"
        );
        identityRegistry = new AVAIdentityRegistry(applicationRegistry);
        authorityMatrix = new AVAAuthorityMatrix(applicationRegistry, identityRegistry);
        actor = new M14GenericAuthorityActor();
    }

    function testM143CanonicalSubjectsAreScopedByApplicationAndRoleKey() public {
        identityRegistry.assignSubject(address(actor), PEER_APP, REVIEWER_ROLE, PEER_SUBJECT, "ipfs://peer-subject");
        identityRegistry.assignSubject(
            address(actor), SECONDARY_APP, CONTRIBUTOR_ROLE, SECONDARY_SUBJECT, "ipfs://secondary-subject"
        );

        require(
            identityRegistry.subjectOf(address(actor), PEER_APP, REVIEWER_ROLE) == PEER_SUBJECT, "peer subject missing"
        );
        require(
            identityRegistry.subjectOf(address(actor), SECONDARY_APP, CONTRIBUTOR_ROLE) == SECONDARY_SUBJECT,
            "secondary subject missing"
        );
        require(
            identityRegistry.subjectOf(address(actor), PEER_APP, CONTRIBUTOR_ROLE) == bytes32(0),
            "cross-app role alias leaked"
        );
    }

    function testM143AuthorityPermissionAndAuthorityIdCannotCrossApplication() public {
        identityRegistry.assignSubject(address(actor), PEER_APP, REVIEWER_ROLE, PEER_SUBJECT, "ipfs://peer-subject");
        identityRegistry.assignSubject(
            address(actor), SECONDARY_APP, CONTRIBUTOR_ROLE, SECONDARY_SUBJECT, "ipfs://secondary-subject"
        );
        authorityMatrix.setPermission(PEER_APP, REVIEWER_ROLE, REGISTER_OBJECT, true);

        require(
            actor.requireAuthority(authorityMatrix, PEER_APP, REVIEWER_ROLE, REGISTER_OBJECT, PEER_SUBJECT)
                == PEER_SUBJECT,
            "peer authority rejected"
        );

        try actor.requireAuthority(
            authorityMatrix, SECONDARY_APP, CONTRIBUTOR_ROLE, REGISTER_OBJECT, SECONDARY_SUBJECT
        ) {
            revert("peer permission crossed into secondary app");
        } catch {}

        try actor.requireAuthority(authorityMatrix, PEER_APP, REVIEWER_ROLE, REGISTER_OBJECT, SECONDARY_SUBJECT) {
            revert("secondary authority id crossed into peer app");
        } catch {}
    }

    function testM143AuthorityMatrixRejectsIdentityRegistryFromDifferentApplicationRegistry() public {
        AVAApplicationRegistry otherApplicationRegistry = new AVAApplicationRegistry();
        AVAIdentityRegistry otherIdentityRegistry = new AVAIdentityRegistry(otherApplicationRegistry);

        try new AVAAuthorityMatrix(applicationRegistry, otherIdentityRegistry) {
            revert("mismatched authority dependency graph accepted");
        } catch {}
    }
}

contract M14GenericObjectStateTest is M14ApplicationFixture, M14CorePackageFixture {
    bytes32 private constant SECONDARY_APP = keccak256("m14.generic.secondary-app");
    bytes32 private constant PEER_ROLE = keccak256("m14.peer.contributor-role");
    bytes32 private constant SECONDARY_ROLE = keccak256("m14.secondary.contributor-role");
    bytes32 private constant PANEL_ROLE = keccak256("m14.peer.panel-role");
    bytes32 private constant PEER_SUBJECT = keccak256("m14.generic.peer-subject");
    bytes32 private constant SECONDARY_SUBJECT = keccak256("m14.generic.secondary-subject");
    bytes32 private constant PANEL_SUBJECT = keccak256("m14.generic.panel-subject");
    bytes32 private constant SHARED_OBJECT_TYPE = keccak256("m14.shared-object-type");
    bytes32 private constant TYPED_OBJECT_TYPE = keccak256("m14.typed-object-type");
    bytes32 private constant TYPED_WORKFLOW = keccak256("m14.typed-workflow");
    bytes32 private constant PACKAGE_ROLE = keccak256("m14.core.package-role");
    bytes32 private constant PEER_PACKAGE_SUBJECT = keccak256("m14.core.peer-package-subject");
    bytes32 private constant SECONDARY_PACKAGE_SUBJECT = keccak256("m14.core.secondary-package-subject");
    bytes32 private constant COMPATIBILITY = keccak256("m14.core.compatibility");

    AVAIdentityRegistry private coreIdentityRegistry;
    AVAAuthorityMatrix private coreAuthorityMatrix;
    AVADisclosurePolicyRegistry private coreDisclosureRegistry;
    AVAEvidenceRegistry private coreEvidenceRegistry;
    AVACoreRulePackageRegistry private corePackageRegistry;
    AVAGovernanceKernel private governanceKernel;
    M14GenericObjectActor private peerActor;
    M14GenericObjectActor private secondaryActor;
    M14GenericObjectActor private panelActor;
    uint256 private peerPolicyId;
    uint256 private secondaryPolicyId;
    uint256 private peerEvidenceId;
    uint256 private secondaryEvidenceId;
    uint256 private peerPackageId;
    uint256 private secondaryPackageId;

    function setUp() public override {
        super.setUp();
        applicationRegistry.registerApplication(
            SECONDARY_APP,
            keccak256("m14.generic.secondary-identity"),
            keccak256("m14.generic.secondary-authority"),
            "ipfs://secondary"
        );
        coreIdentityRegistry = new AVAIdentityRegistry(applicationRegistry);
        coreAuthorityMatrix = new AVAAuthorityMatrix(applicationRegistry, coreIdentityRegistry);
        coreIdentityRegistry.assignSubject(
            address(this), PEER_REVIEW_APP_ID, PACKAGE_ROLE, PEER_PACKAGE_SUBJECT, "ipfs://m14-peer-package-subject"
        );
        coreIdentityRegistry.assignSubject(
            address(this),
            SECONDARY_APP,
            PACKAGE_ROLE,
            SECONDARY_PACKAGE_SUBJECT,
            "ipfs://m14-secondary-package-subject"
        );
        coreAuthorityMatrix.setPermission(
            PEER_REVIEW_APP_ID, PACKAGE_ROLE, AVACoreTypes.ACTION_REGISTER_RULE_PACKAGE, true
        );
        coreAuthorityMatrix.setPermission(SECONDARY_APP, PACKAGE_ROLE, AVACoreTypes.ACTION_REGISTER_RULE_PACKAGE, true);
        corePackageRegistry = new AVACoreRulePackageRegistry(applicationRegistry, coreAuthorityMatrix);
        peerPackageId = corePackageRegistry.registerRulePackage(
            _corePackageInput(
                PEER_REVIEW_APP_ID,
                DEFAULT_WORKFLOW,
                PACKAGE_ROLE,
                PEER_PACKAGE_SUBJECT,
                1,
                COMPATIBILITY,
                "ipfs://m14-generic-peer-package"
            ),
            _coreBindings(new M14PermissiveApplicationModule(PEER_REVIEW_APP_ID))
        );
        secondaryPackageId = corePackageRegistry.registerRulePackage(
            _corePackageInput(
                SECONDARY_APP,
                DEFAULT_WORKFLOW,
                PACKAGE_ROLE,
                SECONDARY_PACKAGE_SUBJECT,
                1,
                COMPATIBILITY,
                "ipfs://m14-generic-secondary-package"
            ),
            _coreBindings(new M14PermissiveApplicationModule(SECONDARY_APP))
        );
        coreDisclosureRegistry = new AVADisclosurePolicyRegistry(applicationRegistry, coreAuthorityMatrix);
        coreEvidenceRegistry = new AVAEvidenceRegistry(
            coreAuthorityMatrix, coreIdentityRegistry, corePackageRegistry, coreDisclosureRegistry
        );
        governanceKernel = new AVAGovernanceKernel(
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            coreDisclosureRegistry,
            new AVAWorkflowPolicyRouter(corePackageRegistry, coreEvidenceRegistry, coreDisclosureRegistry)
        );
        peerActor = new M14GenericObjectActor();
        secondaryActor = new M14GenericObjectActor();
        panelActor = new M14GenericObjectActor();

        coreIdentityRegistry.assignSubject(
            address(peerActor), PEER_REVIEW_APP_ID, PEER_ROLE, PEER_SUBJECT, "ipfs://m14-generic-peer-subject"
        );
        coreIdentityRegistry.assignSubject(
            address(secondaryActor),
            SECONDARY_APP,
            SECONDARY_ROLE,
            SECONDARY_SUBJECT,
            "ipfs://m14-generic-secondary-subject"
        );
        coreIdentityRegistry.assignSubject(
            address(panelActor), PEER_REVIEW_APP_ID, PANEL_ROLE, PANEL_SUBJECT, "ipfs://m14-generic-panel-subject"
        );

        _grantCoreActions(PEER_REVIEW_APP_ID, PEER_ROLE);
        _grantCoreActions(SECONDARY_APP, SECONDARY_ROLE);
        coreAuthorityMatrix.setPermission(
            PEER_REVIEW_APP_ID, PANEL_ROLE, AVACoreTypes.ACTION_FORM_RECOGNISED_STATE, true
        );
        coreAuthorityMatrix.setPermission(
            PEER_REVIEW_APP_ID, PANEL_ROLE, AVACoreTypes.ACTION_TRANSITION_RECOGNISED_STATE, true
        );

        peerPolicyId = peerActor.registerPolicy(
            coreDisclosureRegistry, PEER_REVIEW_APP_ID, PEER_ROLE, PEER_SUBJECT, keccak256("m14-generic-peer-policy")
        );
        secondaryPolicyId = secondaryActor.registerPolicy(
            coreDisclosureRegistry,
            SECONDARY_APP,
            SECONDARY_ROLE,
            SECONDARY_SUBJECT,
            keccak256("m14-generic-secondary-policy")
        );
        peerEvidenceId = peerActor.registerEvidence(
            coreEvidenceRegistry,
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            peerPackageId,
            PEER_ROLE,
            PEER_SUBJECT,
            keccak256("m14-generic-peer-evidence"),
            peerPolicyId
        );
        secondaryEvidenceId = secondaryActor.registerEvidence(
            coreEvidenceRegistry,
            SECONDARY_APP,
            DEFAULT_WORKFLOW,
            secondaryPackageId,
            SECONDARY_ROLE,
            SECONDARY_SUBJECT,
            keccak256("m14-generic-secondary-evidence"),
            secondaryPolicyId
        );
    }

    function testM143TwoApplicationsRegisterSameObjectCommitmentWithoutCollision() public {
        bytes32 sharedCommitment = keccak256("m14-shared-object");
        uint256 peerObjectId = peerActor.registerObject(
            governanceKernel,
            _objectInput(
                PEER_REVIEW_APP_ID,
                peerPackageId,
                PEER_ROLE,
                PEER_SUBJECT,
                peerEvidenceId,
                peerPolicyId,
                sharedCommitment,
                0
            )
        );
        uint256 secondaryObjectId = secondaryActor.registerObject(
            governanceKernel,
            _objectInput(
                SECONDARY_APP,
                secondaryPackageId,
                SECONDARY_ROLE,
                SECONDARY_SUBJECT,
                secondaryEvidenceId,
                secondaryPolicyId,
                sharedCommitment,
                0
            )
        );

        require(peerObjectId != secondaryObjectId, "object record ids collided");
        require(governanceKernel.getGovernedObject(peerObjectId).appId == PEER_REVIEW_APP_ID, "peer app missing");
        require(governanceKernel.getGovernedObject(secondaryObjectId).appId == SECONDARY_APP, "secondary app missing");
        require(
            governanceKernel.getGovernedObjectId(PEER_REVIEW_APP_ID, sharedCommitment) == peerObjectId,
            "peer lookup missing"
        );
        require(
            governanceKernel.getGovernedObjectId(SECONDARY_APP, sharedCommitment) == secondaryObjectId,
            "secondary lookup missing"
        );
    }

    function testM143ObjectRejectsCrossApplicationEvidenceParentSubjectAndAuthority() public {
        uint256 peerObjectId = _registerPeerObject(keccak256("m14-peer-parent"), 0);

        _expectObjectRegistrationFailure(
            secondaryActor,
            _objectInput(
                SECONDARY_APP,
                secondaryPackageId,
                SECONDARY_ROLE,
                SECONDARY_SUBJECT,
                peerEvidenceId,
                secondaryPolicyId,
                keccak256("m14-cross-evidence"),
                0
            ),
            "cross-app evidence accepted"
        );
        _expectObjectRegistrationFailure(
            secondaryActor,
            _objectInput(
                SECONDARY_APP,
                secondaryPackageId,
                SECONDARY_ROLE,
                SECONDARY_SUBJECT,
                secondaryEvidenceId,
                secondaryPolicyId,
                keccak256("m14-cross-parent"),
                peerObjectId
            ),
            "cross-app parent accepted"
        );

        AVAGovernanceKernel.GovernedObjectInput memory wrongSubject = _objectInput(
            SECONDARY_APP,
            secondaryPackageId,
            SECONDARY_ROLE,
            PEER_SUBJECT,
            secondaryEvidenceId,
            secondaryPolicyId,
            keccak256("m14-cross-subject"),
            0
        );
        _expectObjectRegistrationFailure(secondaryActor, wrongSubject, "cross-app subject accepted");

        AVAGovernanceKernel.GovernedObjectInput memory wrongAuthority = _objectInput(
            SECONDARY_APP,
            secondaryPackageId,
            SECONDARY_ROLE,
            SECONDARY_SUBJECT,
            secondaryEvidenceId,
            secondaryPolicyId,
            keccak256("m14-cross-authority"),
            0
        );
        wrongAuthority.authorityId = PEER_SUBJECT;
        _expectObjectRegistrationFailure(secondaryActor, wrongAuthority, "cross-app authority accepted");
    }

    function testM143ObjectRejectsParentFromIncompatiblePackage() public {
        bytes32 incompatibleWorkflow = keccak256("m14.incompatible-parent-workflow");
        uint256 incompatiblePackageId = corePackageRegistry.registerRulePackage(
            _corePackageInput(
                PEER_REVIEW_APP_ID,
                incompatibleWorkflow,
                PACKAGE_ROLE,
                PEER_PACKAGE_SUBJECT,
                1,
                keccak256("m14.incompatible-parent-compatibility"),
                "ipfs://m14-incompatible-parent-package"
            ),
            _coreBindings(new M14PermissiveApplicationModule(PEER_REVIEW_APP_ID))
        );
        uint256 incompatibleEvidenceId = peerActor.registerEvidence(
            coreEvidenceRegistry,
            PEER_REVIEW_APP_ID,
            incompatibleWorkflow,
            incompatiblePackageId,
            PEER_ROLE,
            PEER_SUBJECT,
            keccak256("m14-incompatible-parent-evidence"),
            peerPolicyId
        );
        uint256 incompatibleParentId = peerActor.registerObject(
            governanceKernel,
            AVAGovernanceKernel.GovernedObjectInput({
                appId: PEER_REVIEW_APP_ID,
                workflowKey: incompatibleWorkflow,
                packageId: incompatiblePackageId,
                roleKey: PEER_ROLE,
                objectTypeKey: SHARED_OBJECT_TYPE,
                objectCommitment: keccak256("m14-incompatible-parent"),
                parentObjectId: 0,
                subjectId: PEER_SUBJECT,
                evidenceReceiptId: incompatibleEvidenceId,
                disclosurePolicyId: peerPolicyId,
                metadataHash: keccak256("m14-incompatible-parent-metadata"),
                authorityId: PEER_SUBJECT,
                uri: "ipfs://m14-incompatible-parent"
            })
        );

        _expectObjectRegistrationFailure(
            peerActor,
            _objectInput(
                PEER_REVIEW_APP_ID,
                peerPackageId,
                PEER_ROLE,
                PEER_SUBJECT,
                peerEvidenceId,
                peerPolicyId,
                keccak256("m14-incompatible-parent-child"),
                incompatibleParentId
            ),
            "incompatible package parent accepted"
        );
    }

    function testM143RulePackageRejectsZeroModuleIdentity() public {
        AVACoreRulePackageRegistry.ModuleBinding[] memory coreBindings =
            _coreBindings(new M14PermissiveApplicationModule(PEER_REVIEW_APP_ID));
        AVACoreRulePackageRegistry.ModuleBinding[] memory bindings =
            new AVACoreRulePackageRegistry.ModuleBinding[](coreBindings.length + 1);
        for (uint256 i; i < coreBindings.length; ++i) {
            bindings[i] = coreBindings[i];
        }
        bindings[coreBindings.length] = AVACoreRulePackageRegistry.ModuleBinding({
            capabilityKey: keccak256("m14.zero-identity-capability"),
            module: IRuleModuleIdentity(address(new M14ZeroIdentityModule()))
        });

        try corePackageRegistry.registerRulePackage(
            _corePackageInput(
                PEER_REVIEW_APP_ID,
                keccak256("m14.zero-identity-workflow"),
                PACKAGE_ROLE,
                PEER_PACKAGE_SUBJECT,
                1,
                COMPATIBILITY,
                "ipfs://m14-zero-identity-package"
            ),
            bindings
        ) {
            revert("zero module identity accepted");
        } catch {}
    }

    function testPerformanceCompactPackageReaderPreservesVerifiedContext() public view {
        bytes32[] memory capabilityKeys = new bytes32[](2);
        capabilityKeys[0] = AVACapabilityKeys.APPLICATION;
        capabilityKeys[1] = AVACapabilityKeys.TRANSITION_RULE;
        (AVACoreRulePackageRegistry.VerifiedPackageContext memory context, address[] memory modules) =
            corePackageRegistry.getVerifiedModulesCompact(peerPackageId, capabilityKeys);
        (AVACoreRulePackageRegistry.RulePackage memory fullWithModules, address[] memory fullModules) =
            corePackageRegistry.getVerifiedModules(peerPackageId, capabilityKeys);
        AVACoreRulePackageRegistry.RulePackage memory full = corePackageRegistry.getRulePackageById(peerPackageId);
        AVACoreRulePackageRegistry.VerifiedPackageContext memory contextOnly =
            corePackageRegistry.getVerifiedPackageContext(peerPackageId);

        require(context.packageId == full.packageId, "compact package id mismatch");
        require(context.appId == full.appId, "compact package app mismatch");
        require(context.workflowKey == full.workflowKey, "compact package workflow mismatch");
        require(context.version == full.version, "compact package version mismatch");
        require(context.compatibilityKey == full.compatibilityKey, "compact compatibility mismatch");
        require(context.authorityId == full.authorityId, "compact package authority mismatch");
        require(
            keccak256(abi.encode(contextOnly)) == keccak256(abi.encode(context)), "context-only package reader mismatch"
        );
        require(modules.length == capabilityKeys.length, "compact module count mismatch");
        require(modules[0] != address(0) && modules[1] != address(0), "compact verified module missing");
        require(fullWithModules.packageId == context.packageId, "full package dispatch mismatch");
        require(keccak256(abi.encode(fullModules)) == keccak256(abi.encode(modules)), "compact module mismatch");
    }

    function testPerformanceFixedWorkflowReaderPreservesGenericDispatch() public view {
        bytes32[] memory capabilityKeys = new bytes32[](9);
        capabilityKeys[0] = AVACapabilityKeys.APPLICATION;
        capabilityKeys[1] = AVACapabilityKeys.VERIFICATION;
        capabilityKeys[2] = AVACapabilityKeys.TRANSITION_RULE;
        capabilityKeys[3] = AVACapabilityKeys.EVIDENCE_POLICY;
        capabilityKeys[4] = AVACapabilityKeys.EVIDENCE_LIFECYCLE;
        capabilityKeys[5] = AVACapabilityKeys.DISCLOSURE_POLICY;
        capabilityKeys[6] = AVACapabilityKeys.AUTHORITY_POLICY;
        capabilityKeys[7] = AVACapabilityKeys.FIELD_POLICY;
        capabilityKeys[8] = AVACapabilityKeys.ANTI_ABUSE;
        (AVACoreRulePackageRegistry.VerifiedPackageContext memory genericContext, address[] memory genericModules) =
            corePackageRegistry.getVerifiedModulesCompact(peerPackageId, capabilityKeys);
        (
            AVACoreRulePackageRegistry.VerifiedPackageContext memory fixedContext,
            AVACoreRulePackageRegistry.WorkflowPolicyModules memory fixedModules
        ) = corePackageRegistry.getVerifiedWorkflowPolicyModules(peerPackageId);

        require(
            keccak256(abi.encode(fixedContext)) == keccak256(abi.encode(genericContext)), "workflow context mismatch"
        );
        require(fixedModules.application == genericModules[0], "workflow application mismatch");
        require(fixedModules.verification == genericModules[1], "workflow verification mismatch");
        require(fixedModules.transitionRule == genericModules[2], "workflow transition mismatch");
        require(fixedModules.evidencePolicy == genericModules[3], "workflow evidence policy mismatch");
        require(fixedModules.evidenceLifecycle == genericModules[4], "workflow evidence lifecycle mismatch");
        require(fixedModules.disclosurePolicy == genericModules[5], "workflow disclosure mismatch");
        require(fixedModules.authorityPolicy == genericModules[6], "workflow authority mismatch");
        require(fixedModules.fieldPolicy == genericModules[7], "workflow field mismatch");
        require(fixedModules.antiAbusePolicy == genericModules[8], "workflow anti-abuse mismatch");
    }

    function testPerformanceFixedChallengeReaderPreservesGenericDispatch() public view {
        bytes32[] memory capabilityKeys = new bytes32[](4);
        capabilityKeys[0] = AVACapabilityKeys.CHALLENGE_POLICY;
        capabilityKeys[1] = AVACapabilityKeys.DISCLOSURE_POLICY;
        capabilityKeys[2] = AVACapabilityKeys.AUTHORITY_POLICY;
        capabilityKeys[3] = AVACapabilityKeys.ANTI_ABUSE;
        (AVACoreRulePackageRegistry.VerifiedPackageContext memory genericContext, address[] memory genericModules) =
            corePackageRegistry.getVerifiedModulesCompact(peerPackageId, capabilityKeys);
        (
            AVACoreRulePackageRegistry.VerifiedPackageContext memory fixedContext,
            AVACoreRulePackageRegistry.ChallengePolicyModules memory fixedModules
        ) = corePackageRegistry.getVerifiedChallengePolicyModules(peerPackageId);

        require(
            keccak256(abi.encode(fixedContext)) == keccak256(abi.encode(genericContext)), "challenge context mismatch"
        );
        require(fixedModules.challengePolicy == genericModules[0], "challenge policy mismatch");
        require(fixedModules.disclosurePolicy == genericModules[1], "challenge disclosure mismatch");
        require(fixedModules.authorityPolicy == genericModules[2], "challenge authority mismatch");
        require(fixedModules.antiAbusePolicy == genericModules[3], "challenge anti-abuse mismatch");
    }

    function testPerformanceActiveVerifiedDispatchPreservesPackageBinding() public view {
        bytes32[] memory capabilityKeys = new bytes32[](2);
        capabilityKeys[0] = AVACapabilityKeys.APPLICATION;
        capabilityKeys[1] = AVACapabilityKeys.ATTRIBUTION;
        (AVACoreRulePackageRegistry.VerifiedPackageContext memory context, address[] memory modules) = corePackageRegistry.getActiveVerifiedModulesCompact(
            PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW, peerPackageId, capabilityKeys
        );
        uint256 activePackageId = corePackageRegistry.getActivePackageId(PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW);
        (AVACoreRulePackageRegistry.RulePackage memory full, address[] memory fullModules) =
            corePackageRegistry.getVerifiedModules(activePackageId, capabilityKeys);
        require(context.packageId == peerPackageId, "active compact package mismatch");
        require(context.appId == PEER_REVIEW_APP_ID, "active compact app mismatch");
        require(context.workflowKey == DEFAULT_WORKFLOW, "active compact workflow mismatch");
        require(modules[0] != address(0) && modules[1] != address(0), "active compact module missing");
        require(full.packageId == context.packageId, "legacy active package mismatch");
        require(keccak256(abi.encode(fullModules)) == keccak256(abi.encode(modules)), "active module mismatch");

        try corePackageRegistry.getActiveVerifiedModulesCompact(
            PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW, secondaryPackageId, capabilityKeys
        ) returns (
            AVACoreRulePackageRegistry.VerifiedPackageContext memory, address[] memory
        ) {
            revert("cross-application active package accepted");
        } catch {}
    }

    function testPerformanceCompactSubjectReaderPreservesCanonicalContext() public view {
        AVAIdentityRegistry.SubjectContext memory context =
            coreIdentityRegistry.requireActiveSubjectContext(PEER_SUBJECT, PEER_REVIEW_APP_ID);
        AVACoreTypes.SubjectRecord memory full = coreIdentityRegistry.getSubject(PEER_SUBJECT);

        require(context.subjectId == full.subjectId, "compact subject id mismatch");
        require(context.appId == full.appId, "compact subject app mismatch");
        require(context.roleKey == full.roleKey, "compact subject role mismatch");
        require(context.account == full.account, "compact subject account mismatch");
        require(context.active == full.active, "compact subject status mismatch");
        coreIdentityRegistry.requireActiveSubjectReference(PEER_SUBJECT, PEER_REVIEW_APP_ID);
    }

    function testPerformanceCompactGovernedObjectReaderPreservesCanonicalContext() public {
        uint256 objectId = _registerPeerObject(keccak256("m14-compact-object-reader"), 0);
        AVAGovernanceKernel.GovernedObjectReference memory objectRef =
            governanceKernel.getGovernedObjectReference(objectId);
        AVACoreTypes.GovernedObjectRecord memory full = governanceKernel.getGovernedObject(objectId);

        require(objectRef.id == full.id, "compact object id mismatch");
        require(objectRef.appId == full.appId, "compact object app mismatch");
        require(objectRef.workflowKey == full.workflowKey, "compact object workflow mismatch");
        require(objectRef.packageId == full.packageId, "compact object package mismatch");
        require(objectRef.objectTypeKey == full.objectTypeKey, "compact object type mismatch");
        require(objectRef.subjectId == full.subjectId, "compact object subject mismatch");
        require(objectRef.parentObjectId == full.parentObjectId, "compact object parent mismatch");
        require(objectRef.evidenceReceiptId == full.evidenceReceiptId, "compact object evidence mismatch");
        require(objectRef.disclosurePolicyId == full.disclosurePolicyId, "compact object policy mismatch");
    }

    function testM145StandingRevisionWriterCannotAdvanceAnotherPackageOrApplication() public {
        AVAStandingRevisionExtension revisionExtension = new AVAStandingRevisionExtension(governanceKernel);
        M14GenericRevisionWriter writer = new M14GenericRevisionWriter();
        revisionExtension.bindRevisionWriter(peerPackageId, address(writer));

        require(
            writer.advance(revisionExtension, PEER_REVIEW_APP_ID, peerPackageId, PEER_SUBJECT, 1) == 1,
            "package-bound revision writer rejected"
        );

        try writer.advance(revisionExtension, SECONDARY_APP, peerPackageId, PEER_SUBJECT, 2) returns (uint256) {
            revert("revision writer forged package application");
        } catch {}
        try writer.advance(revisionExtension, PEER_REVIEW_APP_ID, peerPackageId, SECONDARY_SUBJECT, 2) returns (
            uint256
        ) {
            revert("revision writer crossed subject application");
        } catch {}

        try writer.advance(revisionExtension, SECONDARY_APP, secondaryPackageId, SECONDARY_SUBJECT, 1) returns (
            uint256
        ) {
            revert("package-unbound revision writer crossed application boundary");
        } catch {}
        require(
            revisionExtension.currentRevision(secondaryPackageId, SECONDARY_SUBJECT) == 0,
            "cross-application revision was recorded"
        );
    }

    function testStandingRevisionWriterSealIsPackageScopedAndIdentityStable() public {
        AVAStandingRevisionExtension revisionExtension = new AVAStandingRevisionExtension(governanceKernel);
        M14GenericRevisionWriter peerWriter = new M14GenericRevisionWriter();
        M14GenericRevisionWriter secondaryWriter = new M14GenericRevisionWriter();
        revisionExtension.bindRevisionWriter(peerPackageId, address(peerWriter));
        bytes32 identityBefore = revisionExtension.moduleIdentityHash();

        peerWriter.advance(revisionExtension, PEER_REVIEW_APP_ID, peerPackageId, PEER_SUBJECT, 1);
        revisionExtension.bindRevisionWriter(secondaryPackageId, address(secondaryWriter));
        require(
            revisionExtension.moduleIdentityHash() == identityBefore,
            "new package writer changed historical revision module identity"
        );
        require(
            secondaryWriter.advance(revisionExtension, SECONDARY_APP, secondaryPackageId, SECONDARY_SUBJECT, 1) == 1,
            "unused package could not bind its revision writer"
        );

        try revisionExtension.bindRevisionWriter(peerPackageId, address(secondaryWriter)) {
            revert("used package accepted a late revision writer");
        } catch {}
    }

    function testM143RecognisedStateFormationAndMutationWriteGenericTransitionLedger() public {
        uint256 objectId = _registerPeerObject(keccak256("m14-state-object"), 0);
        uint256 stateId = peerActor.formState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateFormationInput({
                governedObjectId: objectId,
                roleKey: PEER_ROLE,
                authorityId: PEER_SUBJECT,
                stage: AVACoreTypes.Stage.Verification,
                status: AVACoreTypes.RecognisedStateStatus.Registered,
                reasonHash: keccak256("m14-initial-state"),
                reasonURI: "ipfs://m14-initial-state"
            })
        );
        AVACoreTypes.RecognisedStateRecord memory state = governanceKernel.getRecognisedState(stateId);
        require(state.governedObjectId == objectId, "governed object linkage missing");
        require(state.appId == PEER_REVIEW_APP_ID, "state app missing");
        require(state.lastTransitionId != 0, "initial transition missing");
        AVACoreTypes.RecognisedStateTransitionRecord memory initial =
            governanceKernel.getRecognisedStateTransition(state.lastTransitionId);
        require(initial.fromStatus == AVACoreTypes.RecognisedStateStatus.None, "initial from status wrong");
        require(initial.toStatus == AVACoreTypes.RecognisedStateStatus.Registered, "initial to status wrong");

        uint256 transitionId = peerActor.transitionState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: PEER_ROLE,
                authorityId: PEER_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Challengeable,
                reasonHash: keccak256("m14-challengeable"),
                reasonURI: "ipfs://m14-challengeable"
            })
        );
        state = governanceKernel.getRecognisedState(stateId);
        require(state.status == AVACoreTypes.RecognisedStateStatus.Challengeable, "generic transition missing");
        require(state.lastTransitionId == transitionId, "transition lineage missing");

        AVAGovernanceKernel.RecognisedStateReference memory stateRef =
            governanceKernel.getRecognisedStateReference(stateId);
        require(stateRef.id == state.id, "compact state id drift");
        require(stateRef.governedObjectId == state.governedObjectId, "compact state object drift");
        require(stateRef.appId == state.appId && stateRef.workflowKey == state.workflowKey, "compact state scope drift");
        require(stateRef.packageId == state.packageId, "compact state package drift");
        require(stateRef.stage == state.stage && stateRef.status == state.status, "compact state lifecycle drift");
        require(stateRef.subjectId == state.subjectId, "compact state subject drift");
        require(stateRef.evidenceReceiptId == state.evidenceReceiptId, "compact state evidence drift");
        require(stateRef.disclosurePolicyId == state.disclosurePolicyId, "compact state disclosure drift");
        require(stateRef.lastTransitionId == state.lastTransitionId, "compact state version drift");

        AVACoreTypes.RecognisedStateTransitionRecord memory transition =
            governanceKernel.getRecognisedStateTransition(transitionId);
        AVAGovernanceKernel.RecognisedStateTransitionReference memory transitionRef =
            governanceKernel.getRecognisedStateTransitionReference(transitionId);
        require(transitionRef.id == transition.id, "compact transition id drift");
        require(
            transitionRef.recognisedStateId == transition.recognisedStateId
                && transitionRef.governedObjectId == transition.governedObjectId,
            "compact transition target drift"
        );
        require(
            transitionRef.appId == transition.appId && transitionRef.workflowKey == transition.workflowKey
                && transitionRef.packageId == transition.packageId,
            "compact transition scope drift"
        );
        require(
            transitionRef.decisionPackageId == transition.decisionPackageId
                && transitionRef.sourceRecordId == transition.sourceRecordId,
            "compact transition source drift"
        );
        require(
            transitionRef.fromStatus == transition.fromStatus && transitionRef.toStatus == transition.toStatus
                && transitionRef.kind == transition.kind,
            "compact transition lifecycle drift"
        );
        require(
            transitionRef.evidenceReceiptId == transition.evidenceReceiptId
                && transitionRef.decisionEvidenceReceiptId == transition.decisionEvidenceReceiptId,
            "compact transition evidence drift"
        );
        require(
            transitionRef.authorityId == transition.authorityId && transitionRef.reasonHash == transition.reasonHash,
            "compact transition decision drift"
        );
    }

    function testM143HighImpactStateRequiresExplicitAuthorisedTransitionPath() public {
        uint256 objectId = _registerPeerObject(keccak256("m14-high-impact-object"), 0);
        try peerActor.formState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateFormationInput({
                governedObjectId: objectId,
                roleKey: PEER_ROLE,
                authorityId: PEER_SUBJECT,
                stage: AVACoreTypes.Stage.Verification,
                status: AVACoreTypes.RecognisedStateStatus.Vested,
                reasonHash: keccak256("m14-invalid-initial-vested"),
                reasonURI: "ipfs://m14-invalid-initial-vested"
            })
        ) {
            revert("direct vested formation accepted");
        } catch {}

        uint256 stateId = peerActor.formState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateFormationInput({
                governedObjectId: objectId,
                roleKey: PEER_ROLE,
                authorityId: PEER_SUBJECT,
                stage: AVACoreTypes.Stage.Verification,
                status: AVACoreTypes.RecognisedStateStatus.Challengeable,
                reasonHash: keccak256("m14-challengeable-state"),
                reasonURI: "ipfs://m14-challengeable-state"
            })
        );
        AVAGovernanceKernel.RecognisedStateTransitionInput memory transitionInput =
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: PEER_ROLE,
                authorityId: PEER_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Vested,
                reasonHash: keccak256("m14-vest"),
                reasonURI: "ipfs://m14-vest"
            });
        try peerActor.transitionState(governanceKernel, transitionInput) {
            revert("generic transition created vested state");
        } catch {}

        uint256 vestingTransitionId = peerActor.vestState(governanceKernel, transitionInput);
        require(
            governanceKernel.getRecognisedState(stateId).status == AVACoreTypes.RecognisedStateStatus.Vested,
            "explicit vesting failed"
        );
        require(
            governanceKernel.getRecognisedStateTransition(vestingTransitionId).kind
                == AVACoreTypes.TransitionKind.Vesting,
            "vesting transition kind missing"
        );
    }

    function testM143InactiveResponsibleSubjectBlocksFormationAndLaterTransition() public {
        uint256 firstObjectId = _registerPeerObject(keccak256("m14-inactive-subject-first"), 0);
        uint256 secondObjectId = _registerPeerObject(keccak256("m14-inactive-subject-second"), 0);
        uint256 stateId = panelActor.formState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateFormationInput({
                governedObjectId: firstObjectId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_SUBJECT,
                stage: AVACoreTypes.Stage.Verification,
                status: AVACoreTypes.RecognisedStateStatus.Registered,
                reasonHash: keccak256("m14-before-deactivation"),
                reasonURI: "ipfs://m14-before-deactivation"
            })
        );
        coreIdentityRegistry.deactivateSubject(PEER_SUBJECT);

        try panelActor.formState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateFormationInput({
                governedObjectId: secondObjectId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_SUBJECT,
                stage: AVACoreTypes.Stage.Verification,
                status: AVACoreTypes.RecognisedStateStatus.Registered,
                reasonHash: keccak256("m14-after-deactivation"),
                reasonURI: "ipfs://m14-after-deactivation"
            })
        ) {
            revert("inactive subject formed recognised state");
        } catch {}

        try panelActor.transitionState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Challengeable,
                reasonHash: keccak256("m14-inactive-transition"),
                reasonURI: "ipfs://m14-inactive-transition"
            })
        ) {
            revert("inactive subject state transitioned");
        } catch {}
    }

    function testM143KernelRejectsMismatchedAuthorityIdentityRegistry() public {
        AVAIdentityRegistry otherIdentityRegistry = new AVAIdentityRegistry(applicationRegistry);
        AVAAuthorityMatrix otherAuthorityMatrix = new AVAAuthorityMatrix(applicationRegistry, otherIdentityRegistry);

        try new AVAGovernanceKernel(
            otherAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            coreDisclosureRegistry,
            governanceKernel.POLICY_ROUTER()
        ) {
            revert("mismatched kernel dependency graph accepted");
        } catch {}
    }

    function testM143PackageBoundApplicationModuleCanVetoObjectVocabulary() public {
        uint256 typedPackageId = corePackageRegistry.registerRulePackage(
            _corePackageInput(
                PEER_REVIEW_APP_ID,
                TYPED_WORKFLOW,
                PACKAGE_ROLE,
                PEER_PACKAGE_SUBJECT,
                1,
                COMPATIBILITY,
                "ipfs://m14-typed-workflow"
            ),
            _coreBindings(new M14TypedObjectApplicationModule(PEER_REVIEW_APP_ID, TYPED_OBJECT_TYPE))
        );
        uint256 typedEvidenceId = peerActor.registerEvidence(
            coreEvidenceRegistry,
            PEER_REVIEW_APP_ID,
            TYPED_WORKFLOW,
            typedPackageId,
            PEER_ROLE,
            PEER_SUBJECT,
            keccak256("m14-typed-evidence"),
            peerPolicyId
        );
        AVAGovernanceKernel.GovernedObjectInput memory objectInput = _objectInput(
            PEER_REVIEW_APP_ID,
            typedPackageId,
            PEER_ROLE,
            PEER_SUBJECT,
            typedEvidenceId,
            peerPolicyId,
            keccak256("m14-typed-object"),
            0
        );
        objectInput.workflowKey = TYPED_WORKFLOW;

        _expectObjectRegistrationFailure(peerActor, objectInput, "application module did not veto object type");

        objectInput.objectTypeKey = TYPED_OBJECT_TYPE;
        uint256 objectId = peerActor.registerObject(governanceKernel, objectInput);
        require(governanceKernel.getGovernedObject(objectId).objectTypeKey == TYPED_OBJECT_TYPE, "typed object missing");
    }

    function testM145StandingRevisionHookIsOptionalAndAdvancesExactlyOnceOnVesting() public {
        AVAStandingRevisionExtension revisionExtension = new AVAStandingRevisionExtension(governanceKernel);
        governanceKernel.bindPostTransitionHook(peerPackageId, address(revisionExtension));

        uint256 objectId = _registerPeerObject(keccak256("m145-standing-hook-object"), 0);
        uint256 stateId = peerActor.formState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateFormationInput({
                governedObjectId: objectId,
                roleKey: PEER_ROLE,
                authorityId: PEER_SUBJECT,
                stage: AVACoreTypes.Stage.Verification,
                status: AVACoreTypes.RecognisedStateStatus.Challengeable,
                reasonHash: keccak256("m145-standing-hook-formation"),
                reasonURI: "ipfs://m145-standing-hook-formation"
            })
        );
        require(
            revisionExtension.currentRevision(peerPackageId, PEER_SUBJECT) == 0,
            "initial formation advanced standing revision"
        );
        peerActor.vestState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: PEER_ROLE,
                authorityId: PEER_SUBJECT,
                toStatus: AVACoreTypes.RecognisedStateStatus.Vested,
                reasonHash: keccak256("m145-standing-hook-vesting"),
                reasonURI: "ipfs://m145-standing-hook-vesting"
            })
        );
        require(
            revisionExtension.currentRevision(peerPackageId, PEER_SUBJECT) == 1,
            "vesting did not advance standing revision exactly once"
        );

        uint256 secondaryObjectId = secondaryActor.registerObject(
            governanceKernel,
            _objectInput(
                SECONDARY_APP,
                secondaryPackageId,
                SECONDARY_ROLE,
                SECONDARY_SUBJECT,
                secondaryEvidenceId,
                secondaryPolicyId,
                keccak256("m145-no-hook-object"),
                0
            )
        );
        secondaryActor.formState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateFormationInput({
                governedObjectId: secondaryObjectId,
                roleKey: SECONDARY_ROLE,
                authorityId: SECONDARY_SUBJECT,
                stage: AVACoreTypes.Stage.Verification,
                status: AVACoreTypes.RecognisedStateStatus.Registered,
                reasonHash: keccak256("m145-no-hook-formation"),
                reasonURI: "ipfs://m145-no-hook-formation"
            })
        );
        require(
            revisionExtension.currentRevision(secondaryPackageId, SECONDARY_SUBJECT) == 0,
            "unbound package wrote standing revision"
        );
    }

    function testM145StandingUpdateAdvancesSamePackageSubjectRevision() public {
        AVAStandingRevisionExtension revisionExtension = new AVAStandingRevisionExtension(governanceKernel);
        AVAStandingRecordExtension standingExtension = new AVAStandingRecordExtension(
            governanceKernel,
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            revisionExtension
        );
        revisionExtension.bindRevisionWriter(peerPackageId, address(standingExtension));
        governanceKernel.bindPostTransitionHook(peerPackageId, address(revisionExtension));
        coreAuthorityMatrix.setPermission(
            PEER_REVIEW_APP_ID, PEER_ROLE, AVACoreTypes.ACTION_RECORD_STANDING_UPDATE, true
        );
        uint256 stateId = _formAndVest(
            peerActor,
            _registerPeerObject(keccak256("m145-revisioned-standing-object"), 0),
            PEER_ROLE,
            PEER_SUBJECT,
            "m145-revisioned-standing"
        );
        require(revisionExtension.currentRevision(peerPackageId, PEER_SUBJECT) == 1, "vesting revision missing");
        uint256 standingId = peerActor.recordStanding(
            standingExtension,
            AVAStandingRecordExtension.StandingInput({
                recognisedStateId: stateId,
                roleKey: PEER_ROLE,
                authorityId: PEER_SUBJECT,
                subjectId: PEER_SUBJECT,
                evidenceId: peerEvidenceId,
                dimensionKey: keccak256("m145-revisioned-standing-dimension"),
                delta: 1,
                reasonHash: keccak256("m145-revisioned-standing-update"),
                uri: "ipfs://m145-revisioned-standing-update"
            })
        );
        require(standingId != 0, "standing update missing");
        require(
            revisionExtension.currentRevision(peerPackageId, PEER_SUBJECT) == 2,
            "standing update did not advance revision"
        );
    }

    function testM145ExtensionBindingsCannotBeAddedAfterPackageFormsRecognisedState() public {
        uint256 packageId = peerPackageId;
        uint256 objectId = _registerPeerObject(keccak256("m145-late-binding-object"), 0);
        peerActor.formState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateFormationInput({
                governedObjectId: objectId,
                roleKey: PEER_ROLE,
                authorityId: PEER_SUBJECT,
                stage: AVACoreTypes.Stage.Verification,
                status: AVACoreTypes.RecognisedStateStatus.Registered,
                reasonHash: keccak256("m145-late-binding-state"),
                reasonURI: "ipfs://m145-late-binding-state"
            })
        );
        AVAStandingRevisionExtension extension = new AVAStandingRevisionExtension(governanceKernel);

        try governanceKernel.bindPostTransitionHook(packageId, address(extension)) {
            revert("late post-transition hook binding changed historical package behavior");
        } catch {}
        try governanceKernel.bindTransitionGuard(packageId, address(extension)) {
            revert("late transition guard binding changed historical package behavior");
        } catch {}
        try governanceKernel.bindSourceBoundTransitionRequester(packageId, address(extension)) {
            revert("late requester binding changed historical package behavior");
        } catch {}
    }

    function testM145DownstreamExtensionCannotConsumeCrossApplicationStateEvidenceSubjectOrAuthority() public {
        coreAuthorityMatrix.setPermission(
            PEER_REVIEW_APP_ID, PEER_ROLE, AVACoreTypes.ACTION_RECORD_STANDING_UPDATE, true
        );
        coreAuthorityMatrix.setPermission(
            SECONDARY_APP, SECONDARY_ROLE, AVACoreTypes.ACTION_RECORD_STANDING_UPDATE, true
        );
        AVAStandingRecordExtension extension = new AVAStandingRecordExtension(
            governanceKernel,
            coreAuthorityMatrix,
            coreIdentityRegistry,
            corePackageRegistry,
            coreEvidenceRegistry,
            IAVAStandingRevision(address(0))
        );
        uint256 peerStateId = _formAndVest(
            peerActor,
            _registerPeerObject(keccak256("m145-cross-app-peer-object"), 0),
            PEER_ROLE,
            PEER_SUBJECT,
            "m145-cross-app-peer"
        );
        uint256 secondaryObjectId = secondaryActor.registerObject(
            governanceKernel,
            _objectInput(
                SECONDARY_APP,
                secondaryPackageId,
                SECONDARY_ROLE,
                SECONDARY_SUBJECT,
                secondaryEvidenceId,
                secondaryPolicyId,
                keccak256("m145-cross-app-secondary-object"),
                0
            )
        );
        uint256 secondaryStateId = _formAndVest(
            secondaryActor, secondaryObjectId, SECONDARY_ROLE, SECONDARY_SUBJECT, "m145-cross-app-secondary"
        );

        AVAStandingRecordExtension.StandingInput memory input = AVAStandingRecordExtension.StandingInput({
            recognisedStateId: peerStateId,
            roleKey: PEER_ROLE,
            authorityId: PEER_SUBJECT,
            subjectId: PEER_SUBJECT,
            evidenceId: peerEvidenceId,
            dimensionKey: keccak256("m145-cross-app-standing"),
            delta: 1,
            reasonHash: keccak256("m145-cross-app-standing"),
            uri: "ipfs://m145-cross-app-standing"
        });
        require(peerActor.recordStanding(extension, input) != 0, "same-app standing record failed");

        input.recognisedStateId = secondaryStateId;
        try peerActor.recordStanding(extension, input) {
            revert("peer authority consumed secondary state");
        } catch {}
        input.recognisedStateId = peerStateId;
        input.evidenceId = secondaryEvidenceId;
        try peerActor.recordStanding(extension, input) {
            revert("secondary evidence consumed peer state");
        } catch {}
        input.recognisedStateId = peerStateId;
        input.roleKey = SECONDARY_ROLE;
        input.authorityId = SECONDARY_SUBJECT;
        input.subjectId = SECONDARY_SUBJECT;
        input.evidenceId = secondaryEvidenceId;
        try secondaryActor.recordStanding(extension, input) {
            revert("secondary subject consumed peer state");
        } catch {}
    }

    function _formAndVest(
        M14GenericObjectActor actor,
        uint256 objectId,
        bytes32 roleKey,
        bytes32 subjectId,
        string memory seed
    ) internal returns (uint256 stateId) {
        stateId = actor.formState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateFormationInput({
                governedObjectId: objectId,
                roleKey: roleKey,
                authorityId: subjectId,
                stage: AVACoreTypes.Stage.Verification,
                status: AVACoreTypes.RecognisedStateStatus.Challengeable,
                reasonHash: keccak256(bytes(seed)),
                reasonURI: "ipfs://m145-cross-app-formation"
            })
        );
        actor.vestState(
            governanceKernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: roleKey,
                authorityId: subjectId,
                toStatus: AVACoreTypes.RecognisedStateStatus.Vested,
                reasonHash: keccak256(abi.encode(seed, "vest")),
                reasonURI: "ipfs://m145-cross-app-vest"
            })
        );
    }

    function _grantCoreActions(bytes32 appId, bytes32 roleKey) internal {
        coreAuthorityMatrix.setPermission(appId, roleKey, AVACoreTypes.ACTION_REGISTER_GOVERNED_OBJECT, true);
        coreAuthorityMatrix.setPermission(appId, roleKey, AVACoreTypes.ACTION_FORM_RECOGNISED_STATE, true);
        coreAuthorityMatrix.setPermission(appId, roleKey, AVACoreTypes.ACTION_TRANSITION_RECOGNISED_STATE, true);
        coreAuthorityMatrix.setPermission(appId, roleKey, AVACoreTypes.ACTION_VEST_RECOGNISED_STATE, true);
        coreAuthorityMatrix.setPermission(appId, roleKey, AVACoreTypes.ACTION_REGISTER_DISCLOSURE_POLICY, true);
        coreAuthorityMatrix.setPermission(appId, roleKey, AVACoreTypes.ACTION_REGISTER_EVIDENCE, true);
    }

    function _registerPeerObject(bytes32 commitment, uint256 parentObjectId) internal returns (uint256) {
        return peerActor.registerObject(
            governanceKernel,
            _objectInput(
                PEER_REVIEW_APP_ID,
                peerPackageId,
                PEER_ROLE,
                PEER_SUBJECT,
                peerEvidenceId,
                peerPolicyId,
                commitment,
                parentObjectId
            )
        );
    }

    function _objectInput(
        bytes32 appId,
        uint256 packageId,
        bytes32 roleKey,
        bytes32 subjectId,
        uint256 evidenceReceiptId,
        uint256 disclosurePolicyId,
        bytes32 commitment,
        uint256 parentObjectId
    ) internal pure returns (AVAGovernanceKernel.GovernedObjectInput memory input) {
        input = AVAGovernanceKernel.GovernedObjectInput({
            appId: appId,
            workflowKey: DEFAULT_WORKFLOW,
            packageId: packageId,
            roleKey: roleKey,
            objectTypeKey: SHARED_OBJECT_TYPE,
            objectCommitment: commitment,
            parentObjectId: parentObjectId,
            subjectId: subjectId,
            evidenceReceiptId: evidenceReceiptId,
            disclosurePolicyId: disclosurePolicyId,
            metadataHash: keccak256(abi.encode(appId, commitment)),
            authorityId: subjectId,
            uri: "ipfs://m14-generic-object"
        });
    }

    function _expectObjectRegistrationFailure(
        M14GenericObjectActor actor,
        AVAGovernanceKernel.GovernedObjectInput memory input,
        string memory message
    ) internal {
        try actor.registerObject(governanceKernel, input) {
            revert(message);
        } catch {}
    }
}
