// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAVAApplicationModule} from "../interfaces/IAVAApplicationModule.sol";
import {AVAAuthorityMatrix} from "./AVAAuthorityMatrix.sol";
import {AVACapabilityKeys} from "./AVACapabilityKeys.sol";
import {AVACoreTypes} from "./AVACoreTypes.sol";
import {AVACoreRulePackageRegistry} from "./AVACoreRulePackageRegistry.sol";
import {AVACoreTransitionRules} from "./AVACoreTransitionRules.sol";
import {AVADisclosurePolicyRegistry} from "./AVADisclosurePolicyRegistry.sol";
import {AVAEvidenceRegistry} from "./AVAEvidenceRegistry.sol";
import {AVAIdentityRegistry} from "./AVAIdentityRegistry.sol";
import {AVAWorkflowPolicyRouter} from "./AVAWorkflowPolicyRouter.sol";
import {IAVATransitionGuard} from "./interfaces/IAVATransitionGuard.sol";
import {IAVAPostTransitionHook} from "./interfaces/IAVAPostTransitionHook.sol";
import {IRuleModuleIdentity} from "../interfaces/IRuleModuleIdentity.sol";
import {
    IAVAAttributionModule,
    IAVAFieldPolicyModule,
    IAVAAntiAbusePolicyModule
} from "./interfaces/IAVACoreRuleModules.sol";

contract AVAGovernanceKernel {
    struct SourceBoundTransitionInput {
        uint256 recognisedStateId;
        uint256 expectedTransitionId;
        uint256 decisionPackageId;
        uint256 sourceRecordId;
        uint256 decisionEvidenceReceiptId;
        uint256 disclosureTargetId;
        bytes32 roleKey;
        bytes32 authorityId;
        bytes32 actionKey;
        bytes32 decisionHash;
        AVACoreTypes.RecognisedStateStatus toStatus;
        AVACoreTypes.TransitionKind kind;
        bytes32 reasonHash;
        string reasonURI;
    }

    struct GovernedObjectInput {
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 roleKey;
        bytes32 objectTypeKey;
        bytes32 objectCommitment;
        uint256 parentObjectId;
        bytes32 subjectId;
        uint256 evidenceReceiptId;
        uint256 disclosurePolicyId;
        bytes32 metadataHash;
        bytes32 authorityId;
        string uri;
    }

    /// @notice Fixed-size governed-object context for extension and policy hot paths.
    struct GovernedObjectReference {
        uint256 id;
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 objectTypeKey;
        bytes32 subjectId;
        uint256 parentObjectId;
        uint256 evidenceReceiptId;
        uint256 disclosurePolicyId;
    }

    /// @notice Fixed-size recognised-state context for extension hot paths.
    /// @dev Full authority and provenance metadata remains available through getRecognisedState.
    struct RecognisedStateReference {
        uint256 id;
        uint256 governedObjectId;
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        AVACoreTypes.Stage stage;
        AVACoreTypes.RecognisedStateStatus status;
        bytes32 subjectId;
        uint256 evidenceReceiptId;
        uint256 disclosurePolicyId;
        uint256 lastTransitionId;
    }

    /// @notice Fixed-size transition context without URI, actor, or timestamp audit metadata.
    struct RecognisedStateTransitionReference {
        uint256 id;
        uint256 recognisedStateId;
        uint256 governedObjectId;
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        uint256 decisionPackageId;
        uint256 sourceRecordId;
        AVACoreTypes.RecognisedStateStatus fromStatus;
        AVACoreTypes.RecognisedStateStatus toStatus;
        AVACoreTypes.TransitionKind kind;
        uint256 evidenceReceiptId;
        uint256 decisionEvidenceReceiptId;
        bytes32 authorityId;
        bytes32 reasonHash;
    }

    struct RecognisedStateFormationInput {
        uint256 governedObjectId;
        bytes32 roleKey;
        bytes32 authorityId;
        AVACoreTypes.Stage stage;
        AVACoreTypes.RecognisedStateStatus status;
        bytes32 reasonHash;
        string reasonURI;
    }

    struct RecognisedStateTransitionInput {
        uint256 recognisedStateId;
        bytes32 roleKey;
        bytes32 authorityId;
        AVACoreTypes.RecognisedStateStatus toStatus;
        bytes32 reasonHash;
        string reasonURI;
    }

    struct TransitionWriteInput {
        AVACoreTypes.RecognisedStateStatus fromStatus;
        AVACoreTypes.RecognisedStateStatus toStatus;
        AVACoreTypes.TransitionKind kind;
        uint256 decisionPackageId;
        uint256 sourceRecordId;
        uint256 decisionEvidenceReceiptId;
        bytes32 authorityId;
        address actor;
        bytes32 reasonHash;
        string reasonURI;
    }

    struct ParentObjectContext {
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 objectTypeKey;
        bytes32 subjectId;
    }

    struct GovernedObjectModules {
        AVACoreRulePackageRegistry.VerifiedPackageContext rulePackage;
        IAVAApplicationModule application;
        IAVAAttributionModule attribution;
        IAVAFieldPolicyModule fieldPolicy;
        IAVAAntiAbusePolicyModule antiAbuse;
    }

    AVAAuthorityMatrix public immutable AUTHORITY_MATRIX;
    AVAIdentityRegistry public immutable IDENTITY_REGISTRY;
    AVACoreRulePackageRegistry public immutable RULE_PACKAGE_REGISTRY;
    AVAEvidenceRegistry public immutable EVIDENCE_REGISTRY;
    AVADisclosurePolicyRegistry public immutable DISCLOSURE_REGISTRY;
    AVAWorkflowPolicyRouter public immutable POLICY_ROUTER;
    address public immutable ADMIN;
    mapping(uint256 => address) public sourceBoundTransitionRequesterByPackage;
    mapping(uint256 => IAVATransitionGuard) public transitionGuardByPackage;
    mapping(uint256 => IAVAPostTransitionHook) public postTransitionHookByPackage;
    mapping(uint256 => bytes32) public sourceBoundTransitionRequesterIdentityByPackage;
    mapping(uint256 => bytes32) public transitionGuardIdentityByPackage;
    mapping(uint256 => bytes32) public postTransitionHookIdentityByPackage;
    mapping(uint256 => bool) public recognisedStateUseStartedByPackage;
    uint256 private transitionEntered;

    mapping(uint256 => AVACoreTypes.GovernedObjectRecord) private governedObjects;
    mapping(bytes32 => uint256) private governedObjectIdByApplicationCommitment;
    mapping(uint256 => AVACoreTypes.RecognisedStateRecord) private recognisedStates;
    mapping(bytes32 => uint256) private recognisedStateIdByObjectStage;
    mapping(uint256 => AVACoreTypes.RecognisedStateTransitionRecord) private transitions;

    uint256 public nextGovernedObjectId = 1;
    uint256 public nextRecognisedStateId = 1;
    uint256 public nextTransitionId = 1;

    event GovernedObjectRegistered(
        uint256 indexed id,
        bytes32 indexed appId,
        bytes32 indexed objectTypeKey,
        bytes32 objectCommitment,
        uint256 parentObjectId,
        bytes32 subjectId,
        uint256 packageId,
        bytes32 authorityId,
        address registeredBy
    );
    event RecognisedStateFormed(
        uint256 indexed id,
        uint256 indexed governedObjectId,
        bytes32 indexed appId,
        uint256 packageId,
        AVACoreTypes.Stage stage,
        AVACoreTypes.RecognisedStateStatus status,
        uint256 transitionId,
        address createdBy
    );
    event RecognisedStateTransitioned(
        uint256 indexed transitionId,
        uint256 indexed recognisedStateId,
        bytes32 indexed appId,
        AVACoreTypes.RecognisedStateStatus fromStatus,
        AVACoreTypes.RecognisedStateStatus toStatus,
        AVACoreTypes.TransitionKind kind,
        uint256 packageId,
        bytes32 authorityId,
        address createdBy
    );
    event SourceBoundTransitionRequesterBound(
        uint256 indexed packageId, address indexed requester, address indexed boundBy
    );
    event TransitionGuardBound(uint256 indexed packageId, address indexed guard, address indexed boundBy);
    event PostTransitionHookBound(uint256 indexed packageId, address indexed hook, address indexed boundBy);
    event RecognisedStateTransitionSourceBound(
        uint256 indexed transitionId, uint256 indexed decisionPackageId, uint256 indexed sourceRecordId
    );

    constructor(
        AVAAuthorityMatrix authorityMatrix_,
        AVAIdentityRegistry identityRegistry_,
        AVACoreRulePackageRegistry rulePackageRegistry_,
        AVAEvidenceRegistry evidenceRegistry_,
        AVADisclosurePolicyRegistry disclosureRegistry_,
        AVAWorkflowPolicyRouter policyRouter_
    ) {
        if (
            address(authorityMatrix_) == address(0) || address(identityRegistry_) == address(0)
                || address(rulePackageRegistry_) == address(0) || address(evidenceRegistry_) == address(0)
                || address(disclosureRegistry_) == address(0) || address(policyRouter_) == address(0)
        ) {
            revert AVACoreTypes.EmptyValue();
        }
        if (
            address(authorityMatrix_.IDENTITY_REGISTRY()) != address(identityRegistry_)
                || address(authorityMatrix_.APPLICATION_REGISTRY())
                    != address(rulePackageRegistry_.APPLICATION_REGISTRY())
                || address(identityRegistry_.APPLICATION_REGISTRY())
                    != address(rulePackageRegistry_.APPLICATION_REGISTRY())
                || address(disclosureRegistry_.APPLICATION_REGISTRY())
                    != address(rulePackageRegistry_.APPLICATION_REGISTRY())
                || address(rulePackageRegistry_.AUTHORITY_MATRIX()) != address(authorityMatrix_)
                || address(disclosureRegistry_.AUTHORITY_MATRIX()) != address(authorityMatrix_)
                || address(evidenceRegistry_.RULE_PACKAGE_REGISTRY()) != address(rulePackageRegistry_)
                || address(evidenceRegistry_.DISCLOSURE_REGISTRY()) != address(disclosureRegistry_)
                || address(policyRouter_.RULE_PACKAGE_REGISTRY()) != address(rulePackageRegistry_)
                || address(policyRouter_.EVIDENCE_REGISTRY()) != address(evidenceRegistry_)
                || address(policyRouter_.DISCLOSURE_REGISTRY()) != address(disclosureRegistry_)
        ) {
            revert AVACoreTypes.InvalidState(0);
        }
        AUTHORITY_MATRIX = authorityMatrix_;
        IDENTITY_REGISTRY = identityRegistry_;
        RULE_PACKAGE_REGISTRY = rulePackageRegistry_;
        EVIDENCE_REGISTRY = evidenceRegistry_;
        DISCLOSURE_REGISTRY = disclosureRegistry_;
        POLICY_ROUTER = policyRouter_;
        ADMIN = msg.sender;
    }

    function bindSourceBoundTransitionRequester(uint256 packageId, address requester) external {
        if (msg.sender != ADMIN) revert AVACoreTypes.NotAdmin(msg.sender);
        if (
            packageId == 0 || requester == address(0) || requester.code.length == 0
                || sourceBoundTransitionRequesterByPackage[packageId] != address(0)
                || recognisedStateUseStartedByPackage[packageId]
        ) {
            revert AVACoreTypes.InvalidState(packageId);
        }
        RULE_PACKAGE_REGISTRY.getVerifiedPackageContext(packageId);
        sourceBoundTransitionRequesterIdentityByPackage[packageId] = _moduleIdentity(requester);
        sourceBoundTransitionRequesterByPackage[packageId] = requester;
        emit SourceBoundTransitionRequesterBound(packageId, requester, msg.sender);
    }

    function bindTransitionGuard(uint256 packageId, address guard) external {
        if (msg.sender != ADMIN) revert AVACoreTypes.NotAdmin(msg.sender);
        if (
            packageId == 0 || guard == address(0) || guard.code.length == 0
                || address(transitionGuardByPackage[packageId]) != address(0)
                || recognisedStateUseStartedByPackage[packageId]
        ) {
            revert AVACoreTypes.InvalidState(packageId);
        }
        RULE_PACKAGE_REGISTRY.getVerifiedPackageContext(packageId);
        transitionGuardIdentityByPackage[packageId] = _moduleIdentity(guard);
        transitionGuardByPackage[packageId] = IAVATransitionGuard(guard);
        emit TransitionGuardBound(packageId, guard, msg.sender);
    }

    function bindPostTransitionHook(uint256 packageId, address hook) external {
        if (msg.sender != ADMIN) revert AVACoreTypes.NotAdmin(msg.sender);
        if (
            packageId == 0 || hook == address(0) || hook.code.length == 0
                || address(postTransitionHookByPackage[packageId]) != address(0)
                || recognisedStateUseStartedByPackage[packageId]
        ) {
            revert AVACoreTypes.InvalidState(packageId);
        }
        RULE_PACKAGE_REGISTRY.getVerifiedPackageContext(packageId);
        postTransitionHookIdentityByPackage[packageId] = _moduleIdentity(hook);
        postTransitionHookByPackage[packageId] = IAVAPostTransitionHook(hook);
        emit PostTransitionHookBound(packageId, hook, msg.sender);
    }

    modifier nonReentrantTransition() {
        if (transitionEntered != 0) revert AVACoreTypes.InvalidState(0);
        transitionEntered = 1;
        _;
        transitionEntered = 0;
    }

    function registerGovernedObject(GovernedObjectInput calldata input) external returns (uint256 id) {
        _requireObjectInput(input);
        {
            bytes32 callerAuthorityId = AUTHORITY_MATRIX.requireAuthorisedCanonicalSubject(
                msg.sender, input.appId, input.roleKey, AVACoreTypes.ACTION_REGISTER_GOVERNED_OBJECT
            );
            if (callerAuthorityId != input.authorityId) {
                revert AVACoreTypes.SubjectMismatch(callerAuthorityId, input.authorityId);
            }
        }

        GovernedObjectModules memory modules = _verifiedGovernedObjectModules(input);

        {
            IDENTITY_REGISTRY.requireActiveSubjectReference(input.subjectId, input.appId);
            (
                bytes32 evidenceAppId,
                bytes32 evidenceWorkflowKey,,
                bytes32 evidenceSubjectId,
                uint256 evidenceDisclosurePolicyId
            ) = EVIDENCE_REGISTRY.requireUsableEvidenceReferenceForPackage(input.evidenceReceiptId, input.packageId);
            if (
                evidenceAppId != input.appId || evidenceWorkflowKey != input.workflowKey
                    || evidenceSubjectId != input.subjectId || evidenceDisclosurePolicyId != input.disclosurePolicyId
            ) {
                revert AVACoreTypes.InvalidState(input.evidenceReceiptId);
            }
        }
        DISCLOSURE_REGISTRY.requireActivePolicyReference(input.disclosurePolicyId, input.appId);

        ParentObjectContext memory parent =
            _parentObjectContext(input.parentObjectId, input.appId, modules.rulePackage.compatibilityKey);

        bytes32 objectKey = _objectKey(input.appId, input.objectCommitment);
        if (governedObjectIdByApplicationCommitment[objectKey] != 0) {
            revert AVACoreTypes.InvalidState(governedObjectIdByApplicationCommitment[objectKey]);
        }

        _validateGovernedObjectModules(
            modules,
            IAVAApplicationModule.GovernedObjectContext({
                appId: input.appId,
                workflowKey: input.workflowKey,
                packageId: input.packageId,
                roleKey: input.roleKey,
                objectTypeKey: input.objectTypeKey,
                objectCommitment: input.objectCommitment,
                parentObjectId: input.parentObjectId,
                parentObjectTypeKey: parent.objectTypeKey,
                parentWorkflowKey: parent.workflowKey,
                parentPackageId: parent.packageId,
                parentSubjectId: parent.subjectId,
                subjectId: input.subjectId,
                evidenceReceiptId: input.evidenceReceiptId,
                disclosurePolicyId: input.disclosurePolicyId,
                metadataHash: input.metadataHash,
                authorityId: input.authorityId,
                actor: msg.sender
            })
        );

        id = nextGovernedObjectId++;
        governedObjects[id] = AVACoreTypes.GovernedObjectRecord({
            id: id,
            appId: input.appId,
            workflowKey: input.workflowKey,
            packageId: input.packageId,
            objectTypeKey: input.objectTypeKey,
            objectCommitment: input.objectCommitment,
            parentObjectId: input.parentObjectId,
            subjectId: input.subjectId,
            evidenceReceiptId: input.evidenceReceiptId,
            disclosurePolicyId: input.disclosurePolicyId,
            metadataHash: input.metadataHash,
            uri: input.uri,
            authorityId: input.authorityId,
            registeredBy: msg.sender,
            registeredAt: uint64(block.timestamp)
        });
        governedObjectIdByApplicationCommitment[objectKey] = id;
        emit GovernedObjectRegistered(
            id,
            input.appId,
            input.objectTypeKey,
            input.objectCommitment,
            input.parentObjectId,
            input.subjectId,
            input.packageId,
            input.authorityId,
            msg.sender
        );
    }

    function formRecognisedState(RecognisedStateFormationInput calldata input)
        external
        nonReentrantTransition
        returns (uint256 id)
    {
        if (
            input.roleKey == bytes32(0) || input.authorityId == bytes32(0) || input.stage == AVACoreTypes.Stage.None
                || input.reasonHash == bytes32(0) || !AVACoreTransitionRules.isInitialStatus(input.status)
        ) {
            revert AVACoreTypes.EmptyValue();
        }
        GovernedObjectReference memory objectRecord = _governedObjectReference(input.governedObjectId);
        _requireAuthority(
            objectRecord.appId, input.roleKey, AVACoreTypes.ACTION_FORM_RECOGNISED_STATE, input.authorityId
        );
        _requireObjectSubject(objectRecord);
        _requireObjectEvidence(objectRecord);

        bytes32 stateKey = keccak256(abi.encode(input.governedObjectId, input.stage));
        if (recognisedStateIdByObjectStage[stateKey] != 0) {
            revert AVACoreTypes.InvalidState(recognisedStateIdByObjectStage[stateKey]);
        }
        POLICY_ROUTER.validateFormation(
            AVAWorkflowPolicyRouter.FormationPolicyInput({
                context: IAVAApplicationModule.RecognisedStateFormationContext({
                    appId: objectRecord.appId,
                    workflowKey: objectRecord.workflowKey,
                    packageId: objectRecord.packageId,
                    roleKey: input.roleKey,
                    governedObjectId: objectRecord.id,
                    objectTypeKey: objectRecord.objectTypeKey,
                    subjectId: objectRecord.subjectId,
                    stage: input.stage,
                    status: input.status,
                    authorityId: input.authorityId,
                    actor: msg.sender
                }),
                evidenceId: objectRecord.evidenceReceiptId,
                disclosurePolicyId: objectRecord.disclosurePolicyId,
                reasonHash: input.reasonHash
            })
        );

        recognisedStateUseStartedByPackage[objectRecord.packageId] = true;
        id = nextRecognisedStateId++;
        recognisedStates[id] = AVACoreTypes.RecognisedStateRecord({
            id: id,
            governedObjectId: objectRecord.id,
            appId: objectRecord.appId,
            workflowKey: objectRecord.workflowKey,
            packageId: objectRecord.packageId,
            stage: input.stage,
            status: input.status,
            subjectId: objectRecord.subjectId,
            evidenceReceiptId: objectRecord.evidenceReceiptId,
            disclosurePolicyId: objectRecord.disclosurePolicyId,
            authorityId: input.authorityId,
            lastTransitionId: 0,
            createdBy: msg.sender,
            createdAt: uint64(block.timestamp)
        });
        recognisedStateIdByObjectStage[stateKey] = id;
        uint256 transitionId = _writeTransition(
            recognisedStates[id],
            TransitionWriteInput({
                fromStatus: AVACoreTypes.RecognisedStateStatus.None,
                toStatus: input.status,
                kind: AVACoreTypes.TransitionKind.InitialFormation,
                decisionPackageId: objectRecord.packageId,
                sourceRecordId: 0,
                decisionEvidenceReceiptId: objectRecord.evidenceReceiptId,
                authorityId: input.authorityId,
                actor: msg.sender,
                reasonHash: input.reasonHash,
                reasonURI: input.reasonURI
            })
        );
        emit RecognisedStateFormed(
            id,
            objectRecord.id,
            objectRecord.appId,
            objectRecord.packageId,
            input.stage,
            input.status,
            transitionId,
            msg.sender
        );
    }

    function transitionRecognisedState(RecognisedStateTransitionInput calldata input)
        external
        nonReentrantTransition
        returns (uint256 transitionId)
    {
        AVACoreTypes.RecognisedStateRecord storage state = _recognisedStateStorage(input.recognisedStateId);
        if (!AVACoreTransitionRules.isGenericTransition(state.status, input.toStatus)) {
            revert AVACoreTypes.InvalidState(input.recognisedStateId);
        }
        transitionId = _transition(
            state, input, AVACoreTypes.ACTION_TRANSITION_RECOGNISED_STATE, AVACoreTypes.TransitionKind.Generic
        );
    }

    function vestRecognisedState(RecognisedStateTransitionInput calldata input)
        external
        nonReentrantTransition
        returns (uint256 transitionId)
    {
        AVACoreTypes.RecognisedStateRecord storage state = _recognisedStateStorage(input.recognisedStateId);
        if (
            input.toStatus != AVACoreTypes.RecognisedStateStatus.Vested
                || !AVACoreTransitionRules.isVestingSource(state.status)
        ) {
            revert AVACoreTypes.InvalidState(input.recognisedStateId);
        }
        transitionId =
            _transition(state, input, AVACoreTypes.ACTION_VEST_RECOGNISED_STATE, AVACoreTypes.TransitionKind.Vesting);
    }

    function requestSourceBoundTransition(SourceBoundTransitionInput calldata input)
        external
        nonReentrantTransition
        returns (uint256 transitionId)
    {
        AVACoreTypes.RecognisedStateRecord storage state = _recognisedStateStorage(input.recognisedStateId);
        if (msg.sender != sourceBoundTransitionRequesterByPackage[state.packageId]) {
            revert AVACoreTypes.NotAuthorised(msg.sender, AVACoreTypes.ACTION_TRANSITION_RECOGNISED_STATE);
        }
        _requireStableModule(msg.sender, sourceBoundTransitionRequesterIdentityByPackage[state.packageId]);
        if (
            input.expectedTransitionId == 0 || state.lastTransitionId != input.expectedTransitionId
                || input.decisionPackageId == 0 || input.sourceRecordId == 0 || input.decisionEvidenceReceiptId == 0
                || input.roleKey == bytes32(0) || input.authorityId == bytes32(0) || input.actionKey == bytes32(0)
                || input.decisionHash == bytes32(0) || input.reasonHash == bytes32(0)
                || !AVACoreTransitionRules.isSourceBoundTransition(state.status, input.toStatus, input.kind)
                || (input.kind == AVACoreTypes.TransitionKind.ChallengeCorrection
                    && input.actionKey != AVACoreTypes.ACTION_RESOLVE_CHALLENGE)
                || (input.kind == AVACoreTypes.TransitionKind.Restoration
                    && input.actionKey != AVACoreTypes.ACTION_APPLY_RESTORATION)
        ) {
            revert AVACoreTypes.InvalidState(input.recognisedStateId);
        }
        AVAIdentityRegistry.SubjectContext memory authoritySubject =
            IDENTITY_REGISTRY.requireActiveSubjectContext(input.authorityId, state.appId);
        if (authoritySubject.roleKey != input.roleKey) {
            revert AVACoreTypes.SubjectMismatch(authoritySubject.subjectId, input.authorityId);
        }
        bytes32 authorityAction = input.actionKey;
        if (!AUTHORITY_MATRIX.isAuthorised(authoritySubject.account, state.appId, input.roleKey, authorityAction)) {
            revert AVACoreTypes.NotAuthorised(authoritySubject.account, authorityAction);
        }

        GovernedObjectReference memory objectRecord = _governedObjectReference(state.governedObjectId);
        if (input.kind == AVACoreTypes.TransitionKind.ChallengeCorrection) {
            _requireObjectSubjectReference(objectRecord);
            _requireObjectEvidenceReference(objectRecord);
        } else {
            _requireObjectSubject(objectRecord);
            _requireObjectEvidence(objectRecord);
        }
        AVACoreTypes.RecognisedStateStatus fromStatus = state.status;
        _validateTransitionGuard(state, input.toStatus, input.kind);
        POLICY_ROUTER.validateTransition(
            AVAWorkflowPolicyRouter.TransitionPolicyInput({
                context: IAVAApplicationModule.RecognisedStateTransitionContext({
                    appId: state.appId,
                    workflowKey: state.workflowKey,
                    packageId: state.packageId,
                    roleKey: input.roleKey,
                    recognisedStateId: state.id,
                    governedObjectId: state.governedObjectId,
                    objectTypeKey: objectRecord.objectTypeKey,
                    subjectId: state.subjectId,
                    stage: state.stage,
                    fromStatus: fromStatus,
                    toStatus: input.toStatus,
                    transitionKind: input.kind,
                    actionKey: authorityAction,
                    sourceRecordId: input.sourceRecordId,
                    authorityId: input.authorityId,
                    actor: authoritySubject.account
                }),
                actionKey: authorityAction,
                evidenceId: state.evidenceReceiptId,
                disclosurePolicyId: state.disclosurePolicyId,
                targetVersionId: input.expectedTransitionId,
                decisionPackageId: input.decisionPackageId,
                decisionEvidenceId: input.decisionEvidenceReceiptId,
                sourceRecordId: input.sourceRecordId,
                disclosureTargetId: input.disclosureTargetId,
                reasonHash: input.reasonHash,
                decisionHash: input.decisionHash,
                allowInactiveEvidence: input.kind == AVACoreTypes.TransitionKind.ChallengeCorrection
            })
        );
        state.status = input.toStatus;
        state.authorityId = input.authorityId;
        transitionId = _writeTransition(
            state,
            TransitionWriteInput({
                fromStatus: fromStatus,
                toStatus: input.toStatus,
                kind: input.kind,
                decisionPackageId: input.decisionPackageId,
                sourceRecordId: input.sourceRecordId,
                decisionEvidenceReceiptId: input.decisionEvidenceReceiptId,
                authorityId: input.authorityId,
                actor: authoritySubject.account,
                reasonHash: input.reasonHash,
                reasonURI: input.reasonURI
            })
        );
    }

    function getGovernedObject(uint256 id) external view returns (AVACoreTypes.GovernedObjectRecord memory) {
        return _governedObject(id);
    }

    function getGovernedObjectReference(uint256 id) external view returns (GovernedObjectReference memory objectRef) {
        objectRef = _governedObjectReference(id);
    }

    function getGovernedObjectId(bytes32 appId, bytes32 objectCommitment) external view returns (uint256 id) {
        id = governedObjectIdByApplicationCommitment[_objectKey(appId, objectCommitment)];
        if (id == 0) revert AVACoreTypes.UnknownReference(uint256(objectCommitment));
    }

    function getRecognisedState(uint256 id) external view returns (AVACoreTypes.RecognisedStateRecord memory) {
        AVACoreTypes.RecognisedStateRecord memory state = recognisedStates[id];
        if (state.id == 0) revert AVACoreTypes.UnknownReference(id);
        return state;
    }

    function getRecognisedStateReference(uint256 id)
        external
        view
        returns (RecognisedStateReference memory stateRef)
    {
        AVACoreTypes.RecognisedStateRecord storage state = _recognisedStateStorage(id);
        stateRef = RecognisedStateReference({
            id: state.id,
            governedObjectId: state.governedObjectId,
            appId: state.appId,
            workflowKey: state.workflowKey,
            packageId: state.packageId,
            stage: state.stage,
            status: state.status,
            subjectId: state.subjectId,
            evidenceReceiptId: state.evidenceReceiptId,
            disclosurePolicyId: state.disclosurePolicyId,
            lastTransitionId: state.lastTransitionId
        });
    }

    function getRecognisedStateTransition(uint256 id)
        external
        view
        returns (AVACoreTypes.RecognisedStateTransitionRecord memory)
    {
        AVACoreTypes.RecognisedStateTransitionRecord memory transitionRecord = transitions[id];
        if (transitionRecord.id == 0) revert AVACoreTypes.UnknownReference(id);
        return transitionRecord;
    }

    function getRecognisedStateTransitionReference(uint256 id)
        external
        view
        returns (RecognisedStateTransitionReference memory transitionRef)
    {
        AVACoreTypes.RecognisedStateTransitionRecord storage transitionRecord = transitions[id];
        if (transitionRecord.id == 0) revert AVACoreTypes.UnknownReference(id);
        transitionRef = RecognisedStateTransitionReference({
            id: transitionRecord.id,
            recognisedStateId: transitionRecord.recognisedStateId,
            governedObjectId: transitionRecord.governedObjectId,
            appId: transitionRecord.appId,
            workflowKey: transitionRecord.workflowKey,
            packageId: transitionRecord.packageId,
            decisionPackageId: transitionRecord.decisionPackageId,
            sourceRecordId: transitionRecord.sourceRecordId,
            fromStatus: transitionRecord.fromStatus,
            toStatus: transitionRecord.toStatus,
            kind: transitionRecord.kind,
            evidenceReceiptId: transitionRecord.evidenceReceiptId,
            decisionEvidenceReceiptId: transitionRecord.decisionEvidenceReceiptId,
            authorityId: transitionRecord.authorityId,
            reasonHash: transitionRecord.reasonHash
        });
    }

    function _transition(
        AVACoreTypes.RecognisedStateRecord storage state,
        RecognisedStateTransitionInput calldata input,
        bytes32 actionKey,
        AVACoreTypes.TransitionKind kind
    ) internal returns (uint256 transitionId) {
        if (input.roleKey == bytes32(0) || input.authorityId == bytes32(0) || input.reasonHash == bytes32(0)) {
            revert AVACoreTypes.EmptyValue();
        }
        _requireAuthority(state.appId, input.roleKey, actionKey, input.authorityId);
        GovernedObjectReference memory objectRecord = _governedObjectReference(state.governedObjectId);
        _requireObjectSubject(objectRecord);
        _requireObjectEvidence(objectRecord);

        AVACoreTypes.RecognisedStateStatus fromStatus = state.status;
        _validateTransitionGuard(state, input.toStatus, kind);
        POLICY_ROUTER.validateTransition(
            AVAWorkflowPolicyRouter.TransitionPolicyInput({
                context: IAVAApplicationModule.RecognisedStateTransitionContext({
                    appId: state.appId,
                    workflowKey: state.workflowKey,
                    packageId: state.packageId,
                    roleKey: input.roleKey,
                    recognisedStateId: state.id,
                    governedObjectId: state.governedObjectId,
                    objectTypeKey: objectRecord.objectTypeKey,
                    subjectId: state.subjectId,
                    stage: state.stage,
                    fromStatus: fromStatus,
                    toStatus: input.toStatus,
                    transitionKind: kind,
                    actionKey: actionKey,
                    sourceRecordId: 0,
                    authorityId: input.authorityId,
                    actor: msg.sender
                }),
                actionKey: actionKey,
                evidenceId: state.evidenceReceiptId,
                disclosurePolicyId: state.disclosurePolicyId,
                targetVersionId: state.lastTransitionId,
                decisionPackageId: state.packageId,
                decisionEvidenceId: state.evidenceReceiptId,
                sourceRecordId: 0,
                disclosureTargetId: 0,
                reasonHash: input.reasonHash,
                decisionHash: bytes32(0),
                allowInactiveEvidence: false
            })
        );

        state.status = input.toStatus;
        state.authorityId = input.authorityId;
        transitionId = _writeTransition(
            state,
            TransitionWriteInput({
                fromStatus: fromStatus,
                toStatus: input.toStatus,
                kind: kind,
                decisionPackageId: state.packageId,
                sourceRecordId: 0,
                decisionEvidenceReceiptId: state.evidenceReceiptId,
                authorityId: input.authorityId,
                actor: msg.sender,
                reasonHash: input.reasonHash,
                reasonURI: input.reasonURI
            })
        );
    }

    function _writeTransition(AVACoreTypes.RecognisedStateRecord storage state, TransitionWriteInput memory input)
        internal
        returns (uint256 transitionId)
    {
        transitionId = nextTransitionId++;
        transitions[transitionId] = AVACoreTypes.RecognisedStateTransitionRecord({
            id: transitionId,
            recognisedStateId: state.id,
            governedObjectId: state.governedObjectId,
            appId: state.appId,
            workflowKey: state.workflowKey,
            packageId: state.packageId,
            decisionPackageId: input.decisionPackageId,
            sourceRecordId: input.sourceRecordId,
            fromStatus: input.fromStatus,
            toStatus: input.toStatus,
            kind: input.kind,
            evidenceReceiptId: state.evidenceReceiptId,
            decisionEvidenceReceiptId: input.decisionEvidenceReceiptId,
            authorityId: input.authorityId,
            reasonHash: input.reasonHash,
            reasonURI: input.reasonURI,
            createdBy: input.actor,
            createdAt: uint64(block.timestamp)
        });
        state.lastTransitionId = transitionId;
        _emitRecognisedStateTransition(transitions[transitionId]);
        emit RecognisedStateTransitionSourceBound(transitionId, input.decisionPackageId, input.sourceRecordId);
        _callPostTransitionHook(state, transitions[transitionId]);
    }

    function _emitRecognisedStateTransition(AVACoreTypes.RecognisedStateTransitionRecord storage transitionRecord)
        internal
    {
        emit RecognisedStateTransitioned(
            transitionRecord.id,
            transitionRecord.recognisedStateId,
            transitionRecord.appId,
            transitionRecord.fromStatus,
            transitionRecord.toStatus,
            transitionRecord.kind,
            transitionRecord.packageId,
            transitionRecord.authorityId,
            transitionRecord.createdBy
        );
    }

    function _callPostTransitionHook(
        AVACoreTypes.RecognisedStateRecord storage state,
        AVACoreTypes.RecognisedStateTransitionRecord storage transitionRecord
    ) internal {
        IAVAPostTransitionHook hook = postTransitionHookByPackage[state.packageId];
        if (address(hook) == address(0)) return;
        _requireStableModule(address(hook), postTransitionHookIdentityByPackage[state.packageId]);
        hook.onRecognisedStateTransition(
            IAVAPostTransitionHook.TransitionContext({
                appId: state.appId,
                workflowKey: state.workflowKey,
                packageId: state.packageId,
                governedObjectId: state.governedObjectId,
                recognisedStateId: state.id,
                transitionId: transitionRecord.id,
                subjectId: state.subjectId,
                fromStatus: transitionRecord.fromStatus,
                toStatus: transitionRecord.toStatus,
                kind: transitionRecord.kind
            })
        );
    }

    function _requireObjectInput(GovernedObjectInput calldata input) internal pure {
        if (
            input.appId == bytes32(0) || input.workflowKey == bytes32(0) || input.packageId == 0
                || input.roleKey == bytes32(0) || input.objectTypeKey == bytes32(0)
                || input.objectCommitment == bytes32(0) || input.subjectId == bytes32(0) || input.evidenceReceiptId == 0
                || input.disclosurePolicyId == 0 || input.metadataHash == bytes32(0) || input.authorityId == bytes32(0)
        ) {
            revert AVACoreTypes.EmptyValue();
        }
    }

    function _requireAuthority(bytes32 appId, bytes32 roleKey, bytes32 actionKey, bytes32 authorityId) internal view {
        bytes32 callerAuthorityId =
            AUTHORITY_MATRIX.requireAuthorisedCanonicalSubject(msg.sender, appId, roleKey, actionKey);
        if (callerAuthorityId != authorityId) revert AVACoreTypes.SubjectMismatch(callerAuthorityId, authorityId);
    }

    function _validateGovernedObjectModules(
        GovernedObjectModules memory modules,
        IAVAApplicationModule.GovernedObjectContext memory context
    ) internal view {
        modules.application.validateGovernedObject(context);
        modules.attribution.validateAttribution(context);
        if (address(modules.fieldPolicy) != address(0)) {
            modules.fieldPolicy
                .validateFieldPolicy(
                    IAVAFieldPolicyModule.FieldPolicyContext({
                        appId: context.appId,
                        workflowKey: context.workflowKey,
                        packageId: context.packageId,
                        actionKey: AVACoreTypes.ACTION_REGISTER_GOVERNED_OBJECT,
                        roleKey: context.roleKey,
                        stage: AVACoreTypes.Stage.Attribution,
                        targetId: uint256(context.objectCommitment),
                        objectTypeKey: context.objectTypeKey,
                        subjectId: context.subjectId,
                        evidenceId: context.evidenceReceiptId,
                        authorityId: context.authorityId,
                        actor: context.actor
                    })
                );
        }
        if (address(modules.antiAbuse) != address(0)) {
            modules.antiAbuse
                .validateAntiAbuse(
                    IAVAAntiAbusePolicyModule.AntiAbuseContext({
                        appId: context.appId,
                        workflowKey: context.workflowKey,
                        packageId: context.packageId,
                        actionKey: AVACoreTypes.ACTION_REGISTER_GOVERNED_OBJECT,
                        roleKey: context.roleKey,
                        targetId: uint256(context.objectCommitment),
                        targetTypeKey: context.objectTypeKey,
                        actorSubjectId: context.authorityId,
                        targetSubjectId: context.subjectId,
                        authorityId: context.authorityId,
                        actor: context.actor
                    })
                );
        }
    }

    function _verifiedGovernedObjectModules(GovernedObjectInput calldata input)
        private
        view
        returns (GovernedObjectModules memory modules)
    {
        bytes32[] memory keys = new bytes32[](4);
        keys[0] = AVACapabilityKeys.APPLICATION;
        keys[1] = AVACapabilityKeys.ATTRIBUTION;
        keys[2] = AVACapabilityKeys.FIELD_POLICY;
        keys[3] = AVACapabilityKeys.ANTI_ABUSE;
        (AVACoreRulePackageRegistry.VerifiedPackageContext memory rulePackage, address[] memory addresses) =
            RULE_PACKAGE_REGISTRY.getActiveVerifiedModulesCompact(
                input.appId, input.workflowKey, input.packageId, keys
            );
        modules = GovernedObjectModules({
            rulePackage: rulePackage,
            application: IAVAApplicationModule(addresses[0]),
            attribution: IAVAAttributionModule(addresses[1]),
            fieldPolicy: IAVAFieldPolicyModule(addresses[2]),
            antiAbuse: IAVAAntiAbusePolicyModule(addresses[3])
        });
    }

    function _requireObjectEvidence(GovernedObjectReference memory objectRecord) internal view {
        (
            bytes32 evidenceAppId,
            bytes32 evidenceWorkflowKey,,
            bytes32 evidenceSubjectId,
            uint256 evidenceDisclosurePolicyId
        ) = EVIDENCE_REGISTRY.requireUsableEvidenceReferenceForPackage(
            objectRecord.evidenceReceiptId, objectRecord.packageId
        );
        _validateObjectEvidenceReference(
            objectRecord, evidenceAppId, evidenceWorkflowKey, evidenceSubjectId, evidenceDisclosurePolicyId
        );
    }

    function _requireObjectEvidenceReference(GovernedObjectReference memory objectRecord) internal view {
        (
            bytes32 evidenceAppId,
            bytes32 evidenceWorkflowKey,,
            bytes32 evidenceSubjectId,
            uint256 evidenceDisclosurePolicyId
        ) = EVIDENCE_REGISTRY.requireEvidenceReferenceForPackage(objectRecord.evidenceReceiptId, objectRecord.packageId);
        _validateObjectEvidenceReference(
            objectRecord, evidenceAppId, evidenceWorkflowKey, evidenceSubjectId, evidenceDisclosurePolicyId
        );
    }

    function _validateObjectEvidenceReference(
        GovernedObjectReference memory objectRecord,
        bytes32 evidenceAppId,
        bytes32 evidenceWorkflowKey,
        bytes32 evidenceSubjectId,
        uint256 evidenceDisclosurePolicyId
    ) internal pure {
        if (
            evidenceAppId != objectRecord.appId || evidenceWorkflowKey != objectRecord.workflowKey
                || evidenceSubjectId != objectRecord.subjectId
                || evidenceDisclosurePolicyId != objectRecord.disclosurePolicyId
        ) {
            revert AVACoreTypes.InvalidState(objectRecord.evidenceReceiptId);
        }
    }

    function _requireObjectSubject(GovernedObjectReference memory objectRecord) internal view {
        IDENTITY_REGISTRY.requireActiveSubjectReference(objectRecord.subjectId, objectRecord.appId);
    }

    function _requireObjectSubjectReference(GovernedObjectReference memory objectRecord) internal view {
        AVAIdentityRegistry.SubjectContext memory subject = IDENTITY_REGISTRY.getSubjectContext(objectRecord.subjectId);
        if (subject.appId != objectRecord.appId) {
            revert AVACoreTypes.CrossApplicationReference(objectRecord.appId, subject.appId);
        }
    }

    function _validateTransitionGuard(
        AVACoreTypes.RecognisedStateRecord storage state,
        AVACoreTypes.RecognisedStateStatus toStatus,
        AVACoreTypes.TransitionKind kind
    ) internal view {
        IAVATransitionGuard guard = transitionGuardByPackage[state.packageId];
        if (address(guard) == address(0)) return;
        _requireStableModule(address(guard), transitionGuardIdentityByPackage[state.packageId]);
        guard.validateTransition(state.packageId, state.id, state.status, toStatus, kind);
    }

    function _moduleIdentity(address module) private view returns (bytes32 identityHash) {
        identityHash = IRuleModuleIdentity(module).moduleIdentityHash();
        if (identityHash == bytes32(0)) revert AVACoreTypes.InvalidState(0);
    }

    function _requireStableModule(address module, bytes32 expectedIdentityHash) private view {
        if (expectedIdentityHash == bytes32(0) || _moduleIdentity(module) != expectedIdentityHash) {
            revert AVACoreTypes.InvalidState(0);
        }
    }

    function _governedObject(uint256 id) internal view returns (AVACoreTypes.GovernedObjectRecord memory objectRecord) {
        AVACoreTypes.GovernedObjectRecord storage stored = _governedObjectStorage(id);
        objectRecord = stored;
    }

    function _governedObjectReference(uint256 id)
        internal
        view
        returns (GovernedObjectReference memory objectRef)
    {
        AVACoreTypes.GovernedObjectRecord storage objectRecord = _governedObjectStorage(id);
        objectRef = GovernedObjectReference({
            id: objectRecord.id,
            appId: objectRecord.appId,
            workflowKey: objectRecord.workflowKey,
            packageId: objectRecord.packageId,
            objectTypeKey: objectRecord.objectTypeKey,
            subjectId: objectRecord.subjectId,
            parentObjectId: objectRecord.parentObjectId,
            evidenceReceiptId: objectRecord.evidenceReceiptId,
            disclosurePolicyId: objectRecord.disclosurePolicyId
        });
    }

    function _governedObjectStorage(uint256 id)
        internal
        view
        returns (AVACoreTypes.GovernedObjectRecord storage objectRecord)
    {
        objectRecord = governedObjects[id];
        if (objectRecord.id == 0) revert AVACoreTypes.UnknownReference(id);
    }

    function _recognisedStateStorage(uint256 id)
        internal
        view
        returns (AVACoreTypes.RecognisedStateRecord storage state)
    {
        state = recognisedStates[id];
        if (state.id == 0) revert AVACoreTypes.UnknownReference(id);
    }

    function _objectKey(bytes32 appId, bytes32 objectCommitment) internal pure returns (bytes32) {
        if (appId == bytes32(0) || objectCommitment == bytes32(0)) revert AVACoreTypes.EmptyValue();
        return keccak256(abi.encode(appId, objectCommitment));
    }

    function _parentObjectContext(uint256 parentObjectId, bytes32 appId, bytes32 compatibilityKey)
        private
        view
        returns (ParentObjectContext memory context)
    {
        if (parentObjectId == 0) return context;
        GovernedObjectReference memory parent = _governedObjectReference(parentObjectId);
        if (parent.appId != appId) revert AVACoreTypes.CrossApplicationReference(appId, parent.appId);
        AVACoreRulePackageRegistry.VerifiedPackageContext memory parentPackage =
            RULE_PACKAGE_REGISTRY.getVerifiedPackageContext(parent.packageId);
        if (
            parentPackage.appId != parent.appId || parentPackage.workflowKey != parent.workflowKey
                || parentPackage.compatibilityKey != compatibilityKey
        ) revert AVACoreTypes.InvalidState(parentObjectId);
        context = ParentObjectContext({
            workflowKey: parent.workflowKey,
            packageId: parent.packageId,
            objectTypeKey: parent.objectTypeKey,
            subjectId: parent.subjectId
        });
    }
}
