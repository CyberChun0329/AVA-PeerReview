// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVAApplicationRegistry} from "../src/AVAApplicationRegistry.sol";
import {IRuleModuleIdentity} from "../src/interfaces/IRuleModuleIdentity.sol";
import {AVAAuthorityMatrix} from "../src/core/AVAAuthorityMatrix.sol";
import {AVACoreRulePackageRegistry} from "../src/core/AVACoreRulePackageRegistry.sol";
import {AVACoreTypes} from "../src/core/AVACoreTypes.sol";
import {AVADisclosurePolicyRegistry} from "../src/core/AVADisclosurePolicyRegistry.sol";
import {AVAEvidenceRegistry} from "../src/core/AVAEvidenceRegistry.sol";
import {AVAGovernanceKernel} from "../src/core/AVAGovernanceKernel.sol";
import {AVAIdentityRegistry} from "../src/core/AVAIdentityRegistry.sol";
import {AVAWorkflowPolicyRouter} from "../src/core/AVAWorkflowPolicyRouter.sol";
import {PeerReviewTypes} from "../src/apps/peerreview/PeerReviewTypes.sol";
import {PeerReviewApplicationModule} from "../src/apps/peerreview/PeerReviewApplicationModule.sol";
import {SecondaryTestAppTypes} from "./helpers/SecondaryTestApp.sol";
import {SecondaryTestApplicationModule} from "./helpers/SecondaryTestApp.sol";
import {AVAAllocationRecordExtension} from "../src/extensions/downstream/AVADownstreamRecordExtensions.sol";
import "./helpers/M14CorePackageFixture.sol";

abstract contract M14InvariantTargetRegistry {
    struct FuzzSelector {
        address addr;
        bytes4[] selectors;
    }

    struct FuzzArtifactSelector {
        string artifact;
        bytes4[] selectors;
    }

    struct FuzzInterface {
        address addr;
        string[] artifacts;
    }

    address[] private invariantTargets;

    function _targetContract(address target) internal {
        invariantTargets.push(target);
    }

    function targetContracts() public view returns (address[] memory) {
        return invariantTargets;
    }

    function excludeContracts() public pure returns (address[] memory values) {}
    function targetSenders() public pure returns (address[] memory values) {}
    function excludeSenders() public pure returns (address[] memory values) {}
    function targetSelectors() public pure returns (FuzzSelector[] memory values) {}
    function excludeSelectors() public pure returns (FuzzSelector[] memory values) {}
    function targetArtifactSelectors() public pure returns (FuzzArtifactSelector[] memory values) {}
    function targetArtifacts() public pure returns (string[] memory values) {}
    function excludeArtifacts() public pure returns (string[] memory values) {}
    function targetInterfaces() public pure returns (FuzzInterface[] memory values) {}
}

contract AVAApplicationInvariantActor {
    function registerPolicy(AVADisclosurePolicyRegistry registry, bytes32 appId, bytes32 roleKey, bytes32 authorityId)
        external
        returns (uint256)
    {
        return registry.registerPolicy(
            appId,
            roleKey,
            authorityId,
            keccak256(abi.encode("m14-invariant-policy", appId)),
            "m14-invariant-policy",
            "ipfs://m14-invariant-policy"
        );
    }

    function registerEvidence(
        AVAEvidenceRegistry registry,
        AVAEvidenceRegistry.EvidenceRegistrationInput calldata input
    ) external returns (uint256) {
        return registry.registerEvidence(input);
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

    function recordAllocation(
        AVAAllocationRecordExtension extension,
        AVAAllocationRecordExtension.AllocationInput calldata input
    ) external returns (uint256) {
        return extension.recordAllocation(input);
    }
}

contract AVAApplicationInvariantHandler {
    bytes32 private constant PACKAGE_ROLE = keccak256("m14.invariant.package-role");
    bytes32 private constant PEER_ROTATION_AUTHORITY = keccak256("m14.invariant.peer-rotation-authority");
    bytes32 private constant SECONDARY_ROTATION_AUTHORITY = keccak256("m14.invariant.secondary-rotation-authority");

    AVACoreRulePackageRegistry public immutable PACKAGE_REGISTRY;
    AVAGovernanceKernel public immutable KERNEL;
    AVAAllocationRecordExtension public immutable ALLOCATION_EXTENSION;
    AVAApplicationInvariantActor public immutable PEER_EXECUTOR;
    AVAApplicationInvariantActor public immutable SECONDARY_SUBJECT_ACTOR;
    AVAApplicationInvariantActor public immutable SECONDARY_PANEL;
    bytes32 public immutable WORKFLOW_KEY;
    uint256 public immutable PEER_ORIGINAL_PACKAGE_ID;
    uint256 public immutable SECONDARY_ORIGINAL_PACKAGE_ID;
    uint256 public immutable PEER_STATE_ID;
    uint256 public immutable SECONDARY_STATE_ID;
    bytes32 public immutable PEER_SUBJECT;
    bytes32 public immutable SECONDARY_SUBJECT;
    bytes32 public immutable PEER_EXECUTOR_AUTHORITY;
    bytes32 public immutable SECONDARY_PANEL_AUTHORITY;
    uint256 public immutable PEER_EVIDENCE_ID;
    uint256 private nonce;

    bool public crossApplicationWriteObserved;

    struct HandlerConfig {
        AVACoreRulePackageRegistry packageRegistry;
        AVAGovernanceKernel kernel;
        AVAAllocationRecordExtension allocationExtension;
        AVAApplicationInvariantActor peerExecutor;
        AVAApplicationInvariantActor secondarySubjectActor;
        AVAApplicationInvariantActor secondaryPanel;
        bytes32 workflowKey;
        uint256 peerPackageId;
        uint256 secondaryPackageId;
        uint256 peerStateId;
        uint256 secondaryStateId;
        bytes32 peerSubject;
        bytes32 secondarySubject;
        bytes32 peerExecutorAuthority;
        bytes32 secondaryPanelAuthority;
        uint256 peerEvidenceId;
    }

    constructor(HandlerConfig memory config) {
        PACKAGE_REGISTRY = config.packageRegistry;
        KERNEL = config.kernel;
        ALLOCATION_EXTENSION = config.allocationExtension;
        PEER_EXECUTOR = config.peerExecutor;
        SECONDARY_SUBJECT_ACTOR = config.secondarySubjectActor;
        SECONDARY_PANEL = config.secondaryPanel;
        WORKFLOW_KEY = config.workflowKey;
        PEER_ORIGINAL_PACKAGE_ID = config.peerPackageId;
        SECONDARY_ORIGINAL_PACKAGE_ID = config.secondaryPackageId;
        PEER_STATE_ID = config.peerStateId;
        SECONDARY_STATE_ID = config.secondaryStateId;
        PEER_SUBJECT = config.peerSubject;
        SECONDARY_SUBJECT = config.secondarySubject;
        PEER_EXECUTOR_AUTHORITY = config.peerExecutorAuthority;
        SECONDARY_PANEL_AUTHORITY = config.secondaryPanelAuthority;
        PEER_EVIDENCE_ID = config.peerEvidenceId;
    }

    function supersedePeerPackage(uint256 seed) external {
        _supersede(PeerReviewTypes.APP_ID, PEER_ROTATION_AUTHORITY, seed);
    }

    function supersedeSecondaryPackage(uint256 seed) external {
        _supersede(SecondaryTestAppTypes.APP_ID, SECONDARY_ROTATION_AUTHORITY, seed);
    }

    function attemptCrossApplicationObject(uint256 seed) external {
        uint256 activeSecondaryPackage = PACKAGE_REGISTRY.getActivePackageId(SecondaryTestAppTypes.APP_ID, WORKFLOW_KEY);
        try SECONDARY_SUBJECT_ACTOR.registerObject(
            KERNEL,
            AVAGovernanceKernel.GovernedObjectInput({
                appId: SecondaryTestAppTypes.APP_ID,
                workflowKey: WORKFLOW_KEY,
                packageId: activeSecondaryPackage,
                roleKey: SecondaryTestAppTypes.ROLE_SUBMITTER,
                objectTypeKey: SecondaryTestAppTypes.OBJECT_ROOT,
                objectCommitment: keccak256(abi.encode("m14-cross-app-object", seed, ++nonce)),
                parentObjectId: 0,
                subjectId: SECONDARY_SUBJECT,
                evidenceReceiptId: PEER_EVIDENCE_ID,
                disclosurePolicyId: 0,
                metadataHash: keccak256(abi.encode("m14-cross-app-metadata", seed, nonce)),
                authorityId: SECONDARY_SUBJECT,
                uri: "ipfs://m14-cross-app-object"
            })
        ) {
            crossApplicationWriteObserved = true;
        } catch {}
    }

    function attemptCrossApplicationTransition(uint256 seed) external {
        AVACoreTypes.RecognisedStateStatus toStatus =
            seed % 2 == 0 ? AVACoreTypes.RecognisedStateStatus.Registered : AVACoreTypes.RecognisedStateStatus.Frozen;
        try SECONDARY_PANEL.transitionState(
            KERNEL,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: PEER_STATE_ID,
                roleKey: SecondaryTestAppTypes.ROLE_PANEL,
                authorityId: SECONDARY_PANEL_AUTHORITY,
                toStatus: toStatus,
                reasonHash: keccak256(abi.encode("m14-cross-app-transition", seed)),
                reasonURI: "ipfs://m14-cross-app-transition"
            })
        ) {
            crossApplicationWriteObserved = true;
        } catch {}
    }

    function attemptCrossApplicationAllocation(uint256 seed) external {
        try PEER_EXECUTOR.recordAllocation(
            ALLOCATION_EXTENSION,
            AVAAllocationRecordExtension.AllocationInput({
                recognisedStateId: SECONDARY_STATE_ID,
                roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                authorityId: PEER_EXECUTOR_AUTHORITY,
                subjectId: PEER_SUBJECT,
                evidenceId: PEER_EVIDENCE_ID,
                allocationKindKey: keccak256(abi.encode("m14-cross-app-allocation", seed)),
                units: (seed % 10) + 1,
                reasonHash: keccak256(abi.encode("m14-cross-app-allocation-reason", seed)),
                uri: "ipfs://m14-cross-app-allocation"
            })
        ) {
            crossApplicationWriteObserved = true;
        } catch {}
    }

    function _supersede(bytes32 appId, bytes32 authorityId, uint256 seed) private {
        uint256 previousPackageId = PACKAGE_REGISTRY.getActivePackageId(appId, WORKFLOW_KEY);
        AVACoreRulePackageRegistry.RulePackage memory previous = PACKAGE_REGISTRY.getRulePackageById(previousPackageId);
        bytes32[] memory capabilityKeys = PACKAGE_REGISTRY.getCapabilityKeys(previousPackageId);
        AVACoreRulePackageRegistry.ModuleBinding[] memory bindings =
            new AVACoreRulePackageRegistry.ModuleBinding[](capabilityKeys.length);
        for (uint256 i; i < capabilityKeys.length; ++i) {
            bindings[i] = AVACoreRulePackageRegistry.ModuleBinding({
                capabilityKey: capabilityKeys[i],
                module: IRuleModuleIdentity(PACKAGE_REGISTRY.getModule(previousPackageId, capabilityKeys[i]))
            });
        }
        try PACKAGE_REGISTRY.supersedeRulePackage(
            AVACoreRulePackageRegistry.PackageRegistrationInput({
                appId: appId,
                workflowKey: WORKFLOW_KEY,
                roleKey: PACKAGE_ROLE,
                authorityId: authorityId,
                version: previous.version + 1,
                compatibilityKey: previous.compatibilityKey,
                uri: seed % 2 == 0 ? "ipfs://m14-invariant-package-even" : "ipfs://m14-invariant-package-odd"
            }),
            previousPackageId,
            bindings
        ) {}
            catch {}
    }
}

contract AVAApplicationInvariantTest is M14CorePackageFixture, M14InvariantTargetRegistry {
    bytes32 private constant WORKFLOW = keccak256("m14.invariant.shared-workflow");
    bytes32 private constant COMPATIBILITY = keccak256("m14.invariant.compatibility");
    bytes32 private constant PACKAGE_ROLE = keccak256("m14.invariant.package-role");
    bytes32 private constant PEER_PACKAGE_AUTHORITY = keccak256("m14.invariant.peer-package-authority");
    bytes32 private constant SECONDARY_PACKAGE_AUTHORITY = keccak256("m14.invariant.secondary-package-authority");
    bytes32 private constant PEER_ROTATION_AUTHORITY = keccak256("m14.invariant.peer-rotation-authority");
    bytes32 private constant SECONDARY_ROTATION_AUTHORITY = keccak256("m14.invariant.secondary-rotation-authority");
    bytes32 private constant PEER_SUBJECT = keccak256("m14.invariant.peer-subject");
    bytes32 private constant SECONDARY_SUBJECT = keccak256("m14.invariant.secondary-subject");
    bytes32 private constant PEER_EDITOR = keccak256("m14.invariant.peer-editor");
    bytes32 private constant SECONDARY_REVIEWER = keccak256("m14.invariant.secondary-reviewer");
    bytes32 private constant PEER_PANEL = keccak256("m14.invariant.peer-panel");
    bytes32 private constant SECONDARY_PANEL = keccak256("m14.invariant.secondary-panel");
    bytes32 private constant PEER_EXECUTOR = keccak256("m14.invariant.peer-executor");

    AVAApplicationRegistry private applicationRegistry;
    AVAIdentityRegistry private identityRegistry;
    AVAAuthorityMatrix private authorityMatrix;
    AVACoreRulePackageRegistry private packageRegistry;
    AVADisclosurePolicyRegistry private disclosureRegistry;
    AVAEvidenceRegistry private evidenceRegistry;
    AVAGovernanceKernel private kernel;
    AVAAllocationRecordExtension private allocationExtension;
    AVAApplicationInvariantHandler private handler;

    uint256 private peerOriginalPackageId;
    uint256 private secondaryOriginalPackageId;
    uint256 private peerStateId;
    uint256 private secondaryStateId;

    AVAApplicationInvariantActor private peerSubjectActor;
    AVAApplicationInvariantActor private secondarySubjectActor;
    AVAApplicationInvariantActor private peerEditorActor;
    AVAApplicationInvariantActor private secondaryReviewerActor;
    AVAApplicationInvariantActor private peerPanelActor;
    AVAApplicationInvariantActor private secondaryPanelActor;
    AVAApplicationInvariantActor private peerExecutorActor;

    function setUp() public {
        _deployCore();
        _deployActors();
        _grantPermissions();
        uint256 peerEvidenceId;
        (peerStateId, peerEvidenceId) = _createPeerState();
        (secondaryStateId,) = _createSecondaryState();
        handler = new AVAApplicationInvariantHandler(_handlerConfig(peerEvidenceId));
        identityRegistry.assignSubject(
            address(handler),
            PeerReviewTypes.APP_ID,
            PACKAGE_ROLE,
            PEER_ROTATION_AUTHORITY,
            "ipfs://m14-invariant-peer-package-authority"
        );
        identityRegistry.assignSubject(
            address(handler),
            SecondaryTestAppTypes.APP_ID,
            PACKAGE_ROLE,
            SECONDARY_ROTATION_AUTHORITY,
            "ipfs://m14-invariant-secondary-package-authority"
        );
        _targetContract(address(handler));
    }

    function _handlerConfig(uint256 peerEvidenceId)
        private
        view
        returns (AVAApplicationInvariantHandler.HandlerConfig memory config)
    {
        config = AVAApplicationInvariantHandler.HandlerConfig({
            packageRegistry: packageRegistry,
            kernel: kernel,
            allocationExtension: allocationExtension,
            peerExecutor: peerExecutorActor,
            secondarySubjectActor: secondarySubjectActor,
            secondaryPanel: secondaryPanelActor,
            workflowKey: WORKFLOW,
            peerPackageId: peerOriginalPackageId,
            secondaryPackageId: secondaryOriginalPackageId,
            peerStateId: peerStateId,
            secondaryStateId: secondaryStateId,
            peerSubject: PEER_SUBJECT,
            secondarySubject: SECONDARY_SUBJECT,
            peerExecutorAuthority: PEER_EXECUTOR,
            secondaryPanelAuthority: SECONDARY_PANEL,
            peerEvidenceId: peerEvidenceId
        });
    }

    function invariantApplicationPointersAndHistoricalStatesRemainIsolated() public view {
        require(!handler.crossApplicationWriteObserved(), "cross-application write succeeded");
        AVACoreTypes.RecognisedStateRecord memory peerState = kernel.getRecognisedState(peerStateId);
        AVACoreTypes.RecognisedStateRecord memory secondaryState = kernel.getRecognisedState(secondaryStateId);
        require(
            peerState.appId == PeerReviewTypes.APP_ID && peerState.packageId == peerOriginalPackageId,
            "peer historical state moved"
        );
        require(
            secondaryState.appId == SecondaryTestAppTypes.APP_ID
                && secondaryState.packageId == secondaryOriginalPackageId,
            "secondary historical state moved"
        );
        uint256 peerActivePackage = packageRegistry.getActivePackageId(PeerReviewTypes.APP_ID, WORKFLOW);
        uint256 secondaryActivePackage = packageRegistry.getActivePackageId(SecondaryTestAppTypes.APP_ID, WORKFLOW);
        AVACoreRulePackageRegistry.RulePackage memory peerPackage =
            packageRegistry.getRulePackageById(peerActivePackage);
        AVACoreRulePackageRegistry.RulePackage memory secondaryPackage =
            packageRegistry.getRulePackageById(secondaryActivePackage);
        require(peerPackage.appId == PeerReviewTypes.APP_ID, "peer pointer crossed application");
        require(secondaryPackage.appId == SecondaryTestAppTypes.APP_ID, "secondary pointer crossed application");
        require(peerActivePackage != secondaryActivePackage, "applications shared an active package id");
    }

    function _deployCore() private {
        applicationRegistry = new AVAApplicationRegistry();
        applicationRegistry.registerApplication(
            PeerReviewTypes.APP_ID,
            keccak256("m14-invariant-peer-app"),
            keccak256("m14-invariant-peer-app-authority"),
            "ipfs://m14-invariant-peer-app"
        );
        applicationRegistry.registerApplication(
            SecondaryTestAppTypes.APP_ID,
            keccak256("m14-invariant-secondary-app"),
            keccak256("m14-invariant-secondary-app-authority"),
            "ipfs://m14-invariant-secondary-app"
        );
        identityRegistry = new AVAIdentityRegistry(applicationRegistry);
        authorityMatrix = new AVAAuthorityMatrix(applicationRegistry, identityRegistry);
        identityRegistry.assignSubject(
            address(this),
            PeerReviewTypes.APP_ID,
            PACKAGE_ROLE,
            PEER_PACKAGE_AUTHORITY,
            "ipfs://m14-invariant-peer-package"
        );
        identityRegistry.assignSubject(
            address(this),
            SecondaryTestAppTypes.APP_ID,
            PACKAGE_ROLE,
            SECONDARY_PACKAGE_AUTHORITY,
            "ipfs://m14-invariant-secondary-package"
        );
        authorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PACKAGE_ROLE, AVACoreTypes.ACTION_REGISTER_RULE_PACKAGE, true
        );
        authorityMatrix.setPermission(
            SecondaryTestAppTypes.APP_ID, PACKAGE_ROLE, AVACoreTypes.ACTION_REGISTER_RULE_PACKAGE, true
        );
        packageRegistry = new AVACoreRulePackageRegistry(applicationRegistry, authorityMatrix);
        peerOriginalPackageId = packageRegistry.registerRulePackage(
            _corePackageInput(
                PeerReviewTypes.APP_ID,
                WORKFLOW,
                PACKAGE_ROLE,
                PEER_PACKAGE_AUTHORITY,
                1,
                COMPATIBILITY,
                "ipfs://m14-invariant-peer-package"
            ),
            _coreBindings(new PeerReviewApplicationModule())
        );
        secondaryOriginalPackageId = packageRegistry.registerRulePackage(
            _corePackageInput(
                SecondaryTestAppTypes.APP_ID,
                WORKFLOW,
                PACKAGE_ROLE,
                SECONDARY_PACKAGE_AUTHORITY,
                1,
                COMPATIBILITY,
                "ipfs://m14-invariant-secondary-package"
            ),
            _coreBindings(new SecondaryTestApplicationModule())
        );
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
        allocationExtension = new AVAAllocationRecordExtension(
            kernel, authorityMatrix, identityRegistry, packageRegistry, evidenceRegistry
        );
    }

    function _deployActors() private {
        peerSubjectActor = new AVAApplicationInvariantActor();
        secondarySubjectActor = new AVAApplicationInvariantActor();
        peerEditorActor = new AVAApplicationInvariantActor();
        secondaryReviewerActor = new AVAApplicationInvariantActor();
        peerPanelActor = new AVAApplicationInvariantActor();
        secondaryPanelActor = new AVAApplicationInvariantActor();
        peerExecutorActor = new AVAApplicationInvariantActor();
        _assign(peerSubjectActor, PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_REVIEWER, PEER_SUBJECT);
        _assign(
            secondarySubjectActor, SecondaryTestAppTypes.APP_ID, SecondaryTestAppTypes.ROLE_SUBMITTER, SECONDARY_SUBJECT
        );
        _assign(peerEditorActor, PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_EDITOR, PEER_EDITOR);
        _assign(
            secondaryReviewerActor,
            SecondaryTestAppTypes.APP_ID,
            SecondaryTestAppTypes.ROLE_VERIFIER,
            SECONDARY_REVIEWER
        );
        _assign(peerPanelActor, PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PANEL, PEER_PANEL);
        _assign(secondaryPanelActor, SecondaryTestAppTypes.APP_ID, SecondaryTestAppTypes.ROLE_PANEL, SECONDARY_PANEL);
        _assign(peerExecutorActor, PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR, PEER_EXECUTOR);
    }

    function _assign(AVAApplicationInvariantActor actor, bytes32 appId, bytes32 roleKey, bytes32 subjectId) private {
        identityRegistry.assignSubject(address(actor), appId, roleKey, subjectId, "ipfs://m14-invariant-subject");
    }

    function _grantPermissions() private {
        _permit(PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_REVIEWER, AVACoreTypes.ACTION_REGISTER_EVIDENCE);
        _permit(PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_REVIEWER, AVACoreTypes.ACTION_REGISTER_GOVERNED_OBJECT);
        _permit(PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_EDITOR, AVACoreTypes.ACTION_REGISTER_DISCLOSURE_POLICY);
        _permit(PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_EDITOR, AVACoreTypes.ACTION_FORM_RECOGNISED_STATE);
        _permit(PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_EDITOR, AVACoreTypes.ACTION_TRANSITION_RECOGNISED_STATE);
        _permit(PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_VEST_RECOGNISED_STATE);
        _permit(PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR, AVACoreTypes.ACTION_RECORD_ALLOCATION);
        _permit(
            SecondaryTestAppTypes.APP_ID, SecondaryTestAppTypes.ROLE_SUBMITTER, AVACoreTypes.ACTION_REGISTER_EVIDENCE
        );
        _permit(
            SecondaryTestAppTypes.APP_ID,
            SecondaryTestAppTypes.ROLE_SUBMITTER,
            AVACoreTypes.ACTION_REGISTER_GOVERNED_OBJECT
        );
        _permit(
            SecondaryTestAppTypes.APP_ID,
            SecondaryTestAppTypes.ROLE_VERIFIER,
            AVACoreTypes.ACTION_REGISTER_DISCLOSURE_POLICY
        );
        _permit(
            SecondaryTestAppTypes.APP_ID, SecondaryTestAppTypes.ROLE_VERIFIER, AVACoreTypes.ACTION_FORM_RECOGNISED_STATE
        );
        _permit(
            SecondaryTestAppTypes.APP_ID,
            SecondaryTestAppTypes.ROLE_VERIFIER,
            AVACoreTypes.ACTION_TRANSITION_RECOGNISED_STATE
        );
        _permit(
            SecondaryTestAppTypes.APP_ID, SecondaryTestAppTypes.ROLE_PANEL, AVACoreTypes.ACTION_VEST_RECOGNISED_STATE
        );
    }

    function _permit(bytes32 appId, bytes32 roleKey, bytes32 actionKey) private {
        authorityMatrix.setPermission(appId, roleKey, actionKey, true);
    }

    function _createPeerState() private returns (uint256 stateId, uint256 evidenceId) {
        uint256 policyId = peerEditorActor.registerPolicy(
            disclosureRegistry, PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_EDITOR, PEER_EDITOR
        );
        evidenceId = _registerEvidence(
            peerSubjectActor,
            PeerReviewTypes.APP_ID,
            peerOriginalPackageId,
            PeerReviewTypes.ROLE_REVIEWER,
            PEER_SUBJECT,
            policyId
        );
        uint256 objectId = peerSubjectActor.registerObject(
            kernel,
            AVAGovernanceKernel.GovernedObjectInput({
                appId: PeerReviewTypes.APP_ID,
                workflowKey: WORKFLOW,
                packageId: peerOriginalPackageId,
                roleKey: PeerReviewTypes.ROLE_REVIEWER,
                objectTypeKey: PeerReviewTypes.OBJECT_REVIEW_CONTRIBUTION,
                objectCommitment: keccak256("m14-invariant-peer-review"),
                parentObjectId: _createPeerManuscript(policyId),
                subjectId: PEER_SUBJECT,
                evidenceReceiptId: evidenceId,
                disclosurePolicyId: policyId,
                metadataHash: keccak256("m14-invariant-peer-review-metadata"),
                authorityId: PEER_SUBJECT,
                uri: "ipfs://m14-invariant-peer-review"
            })
        );
        stateId = _formChallengeableAndVest(
            peerEditorActor,
            peerPanelActor,
            objectId,
            PeerReviewTypes.ROLE_EDITOR,
            PEER_EDITOR,
            PeerReviewTypes.ROLE_PANEL,
            PEER_PANEL
        );
    }

    function _createPeerManuscript(uint256 policyId) private returns (uint256 manuscriptId) {
        AVAApplicationInvariantActor authorActor = new AVAApplicationInvariantActor();
        bytes32 authorSubject = keccak256("m14.invariant.peer-author");
        identityRegistry.assignSubject(
            address(authorActor), PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_AUTHOR, authorSubject, "ipfs://author"
        );
        _permit(PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_AUTHOR, AVACoreTypes.ACTION_REGISTER_EVIDENCE);
        _permit(PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_AUTHOR, AVACoreTypes.ACTION_REGISTER_GOVERNED_OBJECT);
        uint256 evidenceId = _registerEvidence(
            authorActor,
            PeerReviewTypes.APP_ID,
            peerOriginalPackageId,
            PeerReviewTypes.ROLE_AUTHOR,
            authorSubject,
            policyId
        );
        manuscriptId = authorActor.registerObject(
            kernel,
            AVAGovernanceKernel.GovernedObjectInput({
                appId: PeerReviewTypes.APP_ID,
                workflowKey: WORKFLOW,
                packageId: peerOriginalPackageId,
                roleKey: PeerReviewTypes.ROLE_AUTHOR,
                objectTypeKey: PeerReviewTypes.OBJECT_MANUSCRIPT,
                objectCommitment: keccak256("m14-invariant-manuscript"),
                parentObjectId: 0,
                subjectId: authorSubject,
                evidenceReceiptId: evidenceId,
                disclosurePolicyId: policyId,
                metadataHash: keccak256("m14-invariant-manuscript-metadata"),
                authorityId: authorSubject,
                uri: "ipfs://m14-invariant-manuscript"
            })
        );
    }

    function _createSecondaryState() private returns (uint256 stateId, uint256 evidenceId) {
        uint256 policyId = secondaryReviewerActor.registerPolicy(
            disclosureRegistry, SecondaryTestAppTypes.APP_ID, SecondaryTestAppTypes.ROLE_VERIFIER, SECONDARY_REVIEWER
        );
        uint256 rootEvidenceId = _registerEvidence(
            secondarySubjectActor,
            SecondaryTestAppTypes.APP_ID,
            secondaryOriginalPackageId,
            SecondaryTestAppTypes.ROLE_SUBMITTER,
            SECONDARY_SUBJECT,
            policyId
        );
        uint256 rootId = secondarySubjectActor.registerObject(
            kernel,
            AVAGovernanceKernel.GovernedObjectInput({
                appId: SecondaryTestAppTypes.APP_ID,
                workflowKey: WORKFLOW,
                packageId: secondaryOriginalPackageId,
                roleKey: SecondaryTestAppTypes.ROLE_SUBMITTER,
                objectTypeKey: SecondaryTestAppTypes.OBJECT_ROOT,
                objectCommitment: keccak256("m14-invariant-root"),
                parentObjectId: 0,
                subjectId: SECONDARY_SUBJECT,
                evidenceReceiptId: rootEvidenceId,
                disclosurePolicyId: policyId,
                metadataHash: keccak256("m14-invariant-root-metadata"),
                authorityId: SECONDARY_SUBJECT,
                uri: "ipfs://m14-invariant-root"
            })
        );
        evidenceId = _registerEvidence(
            secondarySubjectActor,
            SecondaryTestAppTypes.APP_ID,
            secondaryOriginalPackageId,
            SecondaryTestAppTypes.ROLE_SUBMITTER,
            SECONDARY_SUBJECT,
            policyId
        );
        uint256 submissionId = secondarySubjectActor.registerObject(
            kernel,
            AVAGovernanceKernel.GovernedObjectInput({
                appId: SecondaryTestAppTypes.APP_ID,
                workflowKey: WORKFLOW,
                packageId: secondaryOriginalPackageId,
                roleKey: SecondaryTestAppTypes.ROLE_SUBMITTER,
                objectTypeKey: SecondaryTestAppTypes.OBJECT_SUBMISSION,
                objectCommitment: keccak256("m14-invariant-submission"),
                parentObjectId: rootId,
                subjectId: SECONDARY_SUBJECT,
                evidenceReceiptId: evidenceId,
                disclosurePolicyId: policyId,
                metadataHash: keccak256("m14-invariant-submission-metadata"),
                authorityId: SECONDARY_SUBJECT,
                uri: "ipfs://m14-invariant-submission"
            })
        );
        stateId = _formChallengeableAndVest(
            secondaryReviewerActor,
            secondaryPanelActor,
            submissionId,
            SecondaryTestAppTypes.ROLE_VERIFIER,
            SECONDARY_REVIEWER,
            SecondaryTestAppTypes.ROLE_PANEL,
            SECONDARY_PANEL
        );
    }

    function _registerEvidence(
        AVAApplicationInvariantActor actor,
        bytes32 appId,
        uint256 packageId,
        bytes32 roleKey,
        bytes32 subjectId,
        uint256 policyId
    ) private returns (uint256) {
        return actor.registerEvidence(
            evidenceRegistry,
            AVAEvidenceRegistry.EvidenceRegistrationInput({
                appId: appId,
                workflowKey: WORKFLOW,
                packageId: packageId,
                roleKey: roleKey,
                subjectId: subjectId,
                commitment: keccak256(
                    abi.encode("m14-invariant-evidence", appId, subjectId, evidenceRegistry.nextEvidenceId())
                ),
                evidenceTypeHash: keccak256("m14-invariant-evidence-type"),
                disclosurePolicyId: policyId,
                authorityId: subjectId,
                uri: "ipfs://m14-invariant-evidence"
            })
        );
    }

    function _formChallengeableAndVest(
        AVAApplicationInvariantActor formationActor,
        AVAApplicationInvariantActor panelActor,
        uint256 objectId,
        bytes32 formationRole,
        bytes32 formationAuthority,
        bytes32 panelRole,
        bytes32 panelAuthority
    ) private returns (uint256 stateId) {
        stateId = formationActor.formState(
            kernel,
            AVAGovernanceKernel.RecognisedStateFormationInput({
                governedObjectId: objectId,
                roleKey: formationRole,
                authorityId: formationAuthority,
                stage: AVACoreTypes.Stage.Verification,
                status: AVACoreTypes.RecognisedStateStatus.Provisional,
                reasonHash: keccak256(abi.encode("m14-invariant-formation", objectId)),
                reasonURI: "ipfs://m14-invariant-formation"
            })
        );
        formationActor.transitionState(
            kernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: formationRole,
                authorityId: formationAuthority,
                toStatus: AVACoreTypes.RecognisedStateStatus.Challengeable,
                reasonHash: keccak256(abi.encode("m14-invariant-challengeable", objectId)),
                reasonURI: "ipfs://m14-invariant-challengeable"
            })
        );
        panelActor.vestState(
            kernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: panelRole,
                authorityId: panelAuthority,
                toStatus: AVACoreTypes.RecognisedStateStatus.Vested,
                reasonHash: keccak256(abi.encode("m14-invariant-vest", objectId)),
                reasonURI: "ipfs://m14-invariant-vest"
            })
        );
    }
}
