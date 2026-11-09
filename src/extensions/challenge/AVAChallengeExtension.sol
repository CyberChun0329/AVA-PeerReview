// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVAAuthorityMatrix} from "../../core/AVAAuthorityMatrix.sol";
import {AVACoreTypes} from "../../core/AVACoreTypes.sol";
import {AVACoreRulePackageRegistry} from "../../core/AVACoreRulePackageRegistry.sol";
import {AVACoreTransitionRules} from "../../core/AVACoreTransitionRules.sol";
import {AVAEvidenceRegistry} from "../../core/AVAEvidenceRegistry.sol";
import {AVAGovernanceKernel} from "../../core/AVAGovernanceKernel.sol";
import {AVAIdentityRegistry} from "../../core/AVAIdentityRegistry.sol";
import {AVAWorkflowPolicyRouter} from "../../core/AVAWorkflowPolicyRouter.sol";
import {IAVATransitionGuard} from "../../core/interfaces/IAVATransitionGuard.sol";
import {RuleModuleIdentity} from "../../interfaces/IRuleModuleIdentity.sol";

contract AVAChallengeExtension is IAVATransitionGuard, RuleModuleIdentity {
    enum ChallengeStatus {
        None,
        ConcernFiled,
        AdmissibilityScreening,
        Resolved,
        RestorationAvailable,
        Closed
    }

    enum ChallengeOutcome {
        None,
        Upheld,
        RejectedGoodFaith,
        Negligent,
        MaliciousOrFabricated
    }

    enum ChallengeTransitionKind {
        None,
        Filing,
        Screening,
        Resolution,
        RestorationAvailability,
        Restoration,
        Closure
    }

    struct ChallengeFilingInput {
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        uint256 challengeRecognisedStateId;
        uint256 challengedRecognisedStateId;
        bytes32 roleKey;
        bytes32 reasonHash;
        string reasonURI;
    }

    struct ChallengeResolutionInput {
        uint256 challengeId;
        bytes32 roleKey;
        bytes32 authorityId;
        ChallengeOutcome outcome;
        AVACoreTypes.RecognisedStateStatus correctionStatus;
        bytes32 reasonHash;
        string reasonURI;
    }

    struct ChallengeRecord {
        uint256 id;
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        uint256 targetPackageId;
        uint256 challengeGovernedObjectId;
        uint256 challengeRecognisedStateId;
        uint256 challengedRecognisedStateId;
        bytes32 challengerSubjectId;
        uint256 evidenceReceiptId;
        uint256 disclosurePolicyId;
        AVACoreTypes.RecognisedStateStatus targetStatusAtFiling;
        uint256 targetTransitionIdAtFiling;
        uint256 targetTransitionIdAfterResolution;
        uint256 challengeStateTransitionIdAtFiling;
        uint256 challengeStateTransitionIdAfterResolution;
        ChallengeStatus status;
        ChallengeOutcome outcome;
        uint256 lastTransitionId;
        address filedBy;
        uint64 filedAt;
    }

    struct ChallengeTransitionRecord {
        uint256 id;
        uint256 challengeId;
        bytes32 appId;
        uint256 packageId;
        uint256 targetPackageId;
        uint256 challengeRecognisedStateId;
        uint256 challengedRecognisedStateId;
        ChallengeTransitionKind kind;
        ChallengeStatus fromStatus;
        ChallengeStatus toStatus;
        ChallengeOutcome outcome;
        uint256 challengeStateTransitionIdBefore;
        uint256 challengeStateTransitionIdAfter;
        uint256 targetTransitionIdBefore;
        uint256 targetTransitionIdAfter;
        uint256 evidenceReceiptId;
        bytes32 authorityId;
        bytes32 reasonHash;
        string reasonURI;
        address createdBy;
        uint64 createdAt;
    }

    struct TransitionWriteInput {
        ChallengeTransitionKind kind;
        ChallengeStatus fromStatus;
        ChallengeStatus toStatus;
        ChallengeOutcome outcome;
        uint256 challengeStateTransitionIdBefore;
        uint256 challengeStateTransitionIdAfter;
        uint256 targetTransitionIdBefore;
        uint256 targetTransitionIdAfter;
        bytes32 authorityId;
        bytes32 reasonHash;
        string reasonURI;
        address actor;
    }

    struct StoredPolicyInput {
        bytes32 actionKey;
        bytes32 roleKey;
        bytes32 authorityId;
        ChallengeOutcome outcome;
        bytes32 reasonHash;
    }

    AVAGovernanceKernel public immutable GOVERNANCE_KERNEL;
    AVAAuthorityMatrix public immutable AUTHORITY_MATRIX;
    AVAIdentityRegistry public immutable IDENTITY_REGISTRY;
    AVACoreRulePackageRegistry public immutable RULE_PACKAGE_REGISTRY;
    AVAEvidenceRegistry public immutable EVIDENCE_REGISTRY;
    AVAWorkflowPolicyRouter public immutable POLICY_ROUTER;

    mapping(uint256 => ChallengeRecord) private challenges;
    mapping(uint256 => ChallengeTransitionRecord) private transitions;
    mapping(uint256 => uint256) public openChallengeCountByRecognisedState;
    mapping(uint256 => uint256) public challengeIdByRecognisedState;
    mapping(uint256 => bool) private decisionBoundChallengeState;
    mapping(uint256 => bool) private decisionVestingInProgress;
    mapping(bytes32 => bool) private filingKeyUsed;
    uint256 public nextChallengeId = 1;
    uint256 public nextTransitionId = 1;
    uint256 private lifecycleEntered;

    event ChallengeFiled(
        uint256 indexed challengeId,
        bytes32 indexed appId,
        uint256 indexed challengedRecognisedStateId,
        uint256 challengeRecognisedStateId,
        uint256 packageId,
        uint256 targetPackageId,
        bytes32 challengerSubjectId,
        uint256 evidenceReceiptId,
        address filedBy
    );
    event ChallengeTransitionRecorded(
        uint256 indexed transitionId,
        uint256 indexed challengeId,
        ChallengeTransitionKind indexed kind,
        ChallengeStatus fromStatus,
        ChallengeStatus toStatus,
        ChallengeOutcome outcome,
        uint256 targetTransitionIdAfter,
        bytes32 authorityId,
        address createdBy
    );

    constructor(
        AVAGovernanceKernel governanceKernel_,
        AVAAuthorityMatrix authorityMatrix_,
        AVAIdentityRegistry identityRegistry_,
        AVACoreRulePackageRegistry rulePackageRegistry_,
        AVAEvidenceRegistry evidenceRegistry_
    ) {
        if (
            address(governanceKernel_) == address(0) || address(authorityMatrix_) == address(0)
                || address(identityRegistry_) == address(0) || address(rulePackageRegistry_) == address(0)
                || address(evidenceRegistry_) == address(0)
        ) {
            revert AVACoreTypes.EmptyValue();
        }
        if (
            address(governanceKernel_.AUTHORITY_MATRIX()) != address(authorityMatrix_)
                || address(governanceKernel_.IDENTITY_REGISTRY()) != address(identityRegistry_)
                || address(governanceKernel_.RULE_PACKAGE_REGISTRY()) != address(rulePackageRegistry_)
                || address(governanceKernel_.EVIDENCE_REGISTRY()) != address(evidenceRegistry_)
        ) {
            revert AVACoreTypes.InvalidState(0);
        }
        GOVERNANCE_KERNEL = governanceKernel_;
        AUTHORITY_MATRIX = authorityMatrix_;
        IDENTITY_REGISTRY = identityRegistry_;
        RULE_PACKAGE_REGISTRY = rulePackageRegistry_;
        EVIDENCE_REGISTRY = evidenceRegistry_;
        POLICY_ROUTER = governanceKernel_.POLICY_ROUTER();
    }

    modifier nonReentrantLifecycle() {
        _enterLifecycle();
        _;
        _exitLifecycle();
    }

    function _enterLifecycle() private {
        if (lifecycleEntered != 0) revert AVACoreTypes.InvalidState(0);
        lifecycleEntered = 1;
    }

    function _exitLifecycle() private {
        lifecycleEntered = 0;
    }

    function fileChallenge(ChallengeFilingInput calldata input)
        external
        nonReentrantLifecycle
        returns (uint256 challengeId)
    {
        if (
            input.appId == bytes32(0) || input.workflowKey == bytes32(0) || input.packageId == 0
                || input.challengeRecognisedStateId == 0 || input.challengedRecognisedStateId == 0
                || input.roleKey == bytes32(0) || input.reasonHash == bytes32(0)
        ) {
            revert AVACoreTypes.EmptyValue();
        }
        (
            AVAGovernanceKernel.RecognisedStateReference memory challengeState,
            AVAGovernanceKernel.GovernedObjectReference memory challengeObject,
            AVAGovernanceKernel.RecognisedStateReference memory target
        ) = _validateChallengeFiling(input);
        bytes32 filingKey =
            _filingKey(input.appId, input.challengedRecognisedStateId, target.lastTransitionId, msg.sender);
        if (filingKeyUsed[filingKey] || challengeIdByRecognisedState[challengeState.id] != 0) {
            revert AVACoreTypes.InvalidState(input.challengedRecognisedStateId);
        }
        filingKeyUsed[filingKey] = true;

        challengeId = nextChallengeId++;
        ChallengeRecord storage challenge = challenges[challengeId];
        challenge.id = challengeId;
        challenge.appId = input.appId;
        challenge.workflowKey = input.workflowKey;
        challenge.packageId = input.packageId;
        challenge.targetPackageId = target.packageId;
        challenge.challengeGovernedObjectId = challengeObject.id;
        challenge.challengeRecognisedStateId = challengeState.id;
        challenge.challengedRecognisedStateId = input.challengedRecognisedStateId;
        challenge.challengerSubjectId = challengeState.subjectId;
        challenge.evidenceReceiptId = challengeState.evidenceReceiptId;
        challenge.disclosurePolicyId = challengeState.disclosurePolicyId;
        challenge.targetStatusAtFiling = target.status;
        challenge.targetTransitionIdAtFiling = target.lastTransitionId;
        challenge.status = ChallengeStatus.ConcernFiled;
        challenge.filedBy = msg.sender;
        challenge.filedAt = uint64(block.timestamp);
        challengeIdByRecognisedState[challengeState.id] = challengeId;
        decisionBoundChallengeState[challengeState.id] = true;
        uint256 challengeStateTransitionId = _requestChallengeFilingTransition(challenge, challengeState, target, input);
        challenge.challengeStateTransitionIdAtFiling = challengeStateTransitionId;
        challenge.challengeStateTransitionIdAfterResolution = challengeStateTransitionId;
        openChallengeCountByRecognisedState[input.challengedRecognisedStateId]++;
        TransitionWriteInput memory writeInput;
        writeInput.kind = ChallengeTransitionKind.Filing;
        writeInput.fromStatus = ChallengeStatus.None;
        writeInput.toStatus = ChallengeStatus.ConcernFiled;
        writeInput.outcome = ChallengeOutcome.None;
        writeInput.challengeStateTransitionIdBefore = challengeState.lastTransitionId;
        writeInput.challengeStateTransitionIdAfter = challengeStateTransitionId;
        writeInput.targetTransitionIdBefore = target.lastTransitionId;
        writeInput.targetTransitionIdAfter = target.lastTransitionId;
        writeInput.authorityId = challengeState.subjectId;
        writeInput.reasonHash = input.reasonHash;
        writeInput.reasonURI = input.reasonURI;
        writeInput.actor = msg.sender;
        challenge.lastTransitionId = _recordTransition(challenge, writeInput);
        emit ChallengeFiled(
            challengeId,
            input.appId,
            input.challengedRecognisedStateId,
            input.challengeRecognisedStateId,
            input.packageId,
            target.packageId,
            challengeState.subjectId,
            challengeState.evidenceReceiptId,
            msg.sender
        );
    }

    function screenChallenge(uint256 challengeId, bytes32 roleKey, bytes32 authorityId)
        external
        nonReentrantLifecycle
        returns (uint256 transitionId)
    {
        ChallengeRecord storage challenge = _challengeStorage(challengeId);
        if (challenge.status != ChallengeStatus.ConcernFiled) revert AVACoreTypes.InvalidState(challengeId);
        _requireStoredChallengeEvidence(challenge);
        bytes32 screeningReasonHash = keccak256(abi.encode("challenge-screening", challengeId));
        _validateStoredChallengeAction(
            challenge,
            StoredPolicyInput({
                actionKey: AVACoreTypes.ACTION_SCREEN_CHALLENGE,
                roleKey: roleKey,
                authorityId: authorityId,
                outcome: ChallengeOutcome.None,
                reasonHash: screeningReasonHash
            })
        );
        ChallengeStatus fromStatus = challenge.status;
        challenge.status = ChallengeStatus.AdmissibilityScreening;
        TransitionWriteInput memory writeInput;
        writeInput.kind = ChallengeTransitionKind.Screening;
        writeInput.fromStatus = fromStatus;
        writeInput.toStatus = challenge.status;
        writeInput.outcome = ChallengeOutcome.None;
        writeInput.challengeStateTransitionIdBefore = challenge.challengeStateTransitionIdAfterResolution;
        writeInput.challengeStateTransitionIdAfter = challenge.challengeStateTransitionIdAfterResolution;
        writeInput.targetTransitionIdBefore = challenge.targetTransitionIdAtFiling;
        writeInput.targetTransitionIdAfter = challenge.targetTransitionIdAtFiling;
        writeInput.authorityId = authorityId;
        writeInput.reasonHash = screeningReasonHash;
        writeInput.actor = msg.sender;
        transitionId = _recordTransition(challenge, writeInput);
        challenge.lastTransitionId = transitionId;
    }

    function resolveChallenge(ChallengeResolutionInput calldata input)
        external
        nonReentrantLifecycle
        returns (uint256 transitionId)
    {
        ChallengeRecord storage challenge = _challengeStorage(input.challengeId);
        if (
            challenge.status != ChallengeStatus.AdmissibilityScreening || input.outcome == ChallengeOutcome.None
                || input.reasonHash == bytes32(0)
        ) {
            revert AVACoreTypes.InvalidState(input.challengeId);
        }
        _requireStoredChallengeEvidence(challenge);
        (AVAGovernanceKernel.RecognisedStateReference memory target, bytes32 decisionHash) =
            _validateStoredChallengeAction(
                challenge,
                StoredPolicyInput({
                    actionKey: AVACoreTypes.ACTION_RESOLVE_CHALLENGE,
                    roleKey: input.roleKey,
                    authorityId: input.authorityId,
                    outcome: input.outcome,
                    reasonHash: input.reasonHash
                })
            );
        uint256 transitionIdBefore = target.lastTransitionId;
        uint256 transitionIdAfter = transitionIdBefore;
        if (input.outcome == ChallengeOutcome.Upheld) {
            if (
                transitionIdBefore != challenge.targetTransitionIdAtFiling
                    || (input.correctionStatus != AVACoreTypes.RecognisedStateStatus.Downgraded
                        && input.correctionStatus != AVACoreTypes.RecognisedStateStatus.Voided)
            ) {
                revert AVACoreTypes.InvalidState(input.challengeId);
            }
            transitionIdAfter = GOVERNANCE_KERNEL.requestSourceBoundTransition(
                AVAGovernanceKernel.SourceBoundTransitionInput({
                    recognisedStateId: challenge.challengedRecognisedStateId,
                    expectedTransitionId: transitionIdBefore,
                    decisionPackageId: challenge.packageId,
                    sourceRecordId: challenge.id,
                    decisionEvidenceReceiptId: challenge.evidenceReceiptId,
                    disclosureTargetId: challenge.challengedRecognisedStateId,
                    roleKey: input.roleKey,
                    authorityId: input.authorityId,
                    actionKey: AVACoreTypes.ACTION_RESOLVE_CHALLENGE,
                    decisionHash: decisionHash,
                    toStatus: input.correctionStatus,
                    kind: AVACoreTypes.TransitionKind.ChallengeCorrection,
                    reasonHash: input.reasonHash,
                    reasonURI: input.reasonURI
                })
            );
            challenge.challengeStateTransitionIdAfterResolution =
                _requestChallengeVesting(challenge, input, decisionHash);
        } else if (input.correctionStatus != target.status) {
            revert AVACoreTypes.InvalidState(input.challengeId);
        }

        ChallengeStatus fromStatus = challenge.status;
        challenge.status = ChallengeStatus.Resolved;
        challenge.outcome = input.outcome;
        challenge.targetTransitionIdAfterResolution = transitionIdAfter;
        TransitionWriteInput memory writeInput;
        writeInput.kind = ChallengeTransitionKind.Resolution;
        writeInput.fromStatus = fromStatus;
        writeInput.toStatus = challenge.status;
        writeInput.outcome = input.outcome;
        writeInput.challengeStateTransitionIdBefore = challenge.challengeStateTransitionIdAtFiling;
        writeInput.challengeStateTransitionIdAfter = challenge.challengeStateTransitionIdAfterResolution;
        writeInput.targetTransitionIdBefore = transitionIdBefore;
        writeInput.targetTransitionIdAfter = transitionIdAfter;
        writeInput.authorityId = input.authorityId;
        writeInput.reasonHash = input.reasonHash;
        writeInput.reasonURI = input.reasonURI;
        writeInput.actor = msg.sender;
        transitionId = _recordTransition(challenge, writeInput);
        challenge.lastTransitionId = transitionId;
    }

    function _requestChallengeVesting(
        ChallengeRecord storage challenge,
        ChallengeResolutionInput calldata input,
        bytes32 decisionHash
    ) private returns (uint256 transitionId) {
        AVAGovernanceKernel.RecognisedStateReference memory challengeState =
            GOVERNANCE_KERNEL.getRecognisedStateReference(challenge.challengeRecognisedStateId);
        if (
            challengeState.status != AVACoreTypes.RecognisedStateStatus.Challengeable
                || challengeState.lastTransitionId != challenge.challengeStateTransitionIdAtFiling
                || challengeState.packageId != challenge.packageId
                || challengeState.subjectId != challenge.challengerSubjectId
        ) revert AVACoreTypes.InvalidState(challenge.id);
        decisionVestingInProgress[challengeState.id] = true;
        transitionId = GOVERNANCE_KERNEL.requestSourceBoundTransition(
            AVAGovernanceKernel.SourceBoundTransitionInput({
                recognisedStateId: challengeState.id,
                expectedTransitionId: challengeState.lastTransitionId,
                decisionPackageId: challenge.packageId,
                sourceRecordId: challenge.id,
                decisionEvidenceReceiptId: challenge.evidenceReceiptId,
                disclosureTargetId: challenge.challengedRecognisedStateId,
                roleKey: input.roleKey,
                authorityId: input.authorityId,
                actionKey: AVACoreTypes.ACTION_RESOLVE_CHALLENGE,
                decisionHash: decisionHash,
                toStatus: AVACoreTypes.RecognisedStateStatus.Vested,
                kind: AVACoreTypes.TransitionKind.Vesting,
                reasonHash: input.reasonHash,
                reasonURI: input.reasonURI
            })
        );
        decisionVestingInProgress[challengeState.id] = false;
    }

    function recordRestorationAvailability(
        uint256 challengeId,
        bytes32 roleKey,
        bytes32 authorityId,
        bytes32 reasonHash,
        string calldata reasonURI
    ) external nonReentrantLifecycle returns (uint256 transitionId) {
        ChallengeRecord storage challenge = _challengeStorage(challengeId);
        if (
            challenge.status != ChallengeStatus.Resolved || !_isRestorableOutcome(challenge.outcome)
                || reasonHash == bytes32(0)
        ) {
            revert AVACoreTypes.InvalidState(challengeId);
        }
        _requireStoredChallengeEvidence(challenge);
        (AVAGovernanceKernel.RecognisedStateReference memory target,) = _validateStoredChallengeAction(
            challenge,
            StoredPolicyInput({
                actionKey: AVACoreTypes.ACTION_APPLY_RESTORATION,
                roleKey: roleKey,
                authorityId: authorityId,
                outcome: challenge.outcome,
                reasonHash: reasonHash
            })
        );
        uint256 targetTransitionId = target.lastTransitionId;
        if (targetTransitionId != challenge.targetTransitionIdAfterResolution) {
            revert AVACoreTypes.InvalidState(challengeId);
        }
        ChallengeStatus fromStatus = challenge.status;
        challenge.status = ChallengeStatus.RestorationAvailable;
        TransitionWriteInput memory writeInput;
        writeInput.kind = ChallengeTransitionKind.RestorationAvailability;
        writeInput.fromStatus = fromStatus;
        writeInput.toStatus = challenge.status;
        writeInput.outcome = challenge.outcome;
        writeInput.challengeStateTransitionIdBefore = challenge.challengeStateTransitionIdAfterResolution;
        writeInput.challengeStateTransitionIdAfter = challenge.challengeStateTransitionIdAfterResolution;
        writeInput.targetTransitionIdBefore = targetTransitionId;
        writeInput.targetTransitionIdAfter = targetTransitionId;
        writeInput.authorityId = authorityId;
        writeInput.reasonHash = reasonHash;
        writeInput.reasonURI = reasonURI;
        writeInput.actor = msg.sender;
        transitionId = _recordTransition(challenge, writeInput);
        challenge.lastTransitionId = transitionId;
    }

    function applyRestoration(
        uint256 challengeId,
        bytes32 roleKey,
        bytes32 authorityId,
        bytes32 reasonHash,
        string calldata reasonURI
    ) external nonReentrantLifecycle returns (uint256 transitionId) {
        ChallengeRecord storage challenge = _challengeStorage(challengeId);
        if (
            challenge.status != ChallengeStatus.RestorationAvailable || !_isRestorableOutcome(challenge.outcome)
                || reasonHash == bytes32(0)
        ) {
            revert AVACoreTypes.InvalidState(challengeId);
        }
        _requireStoredChallengeEvidence(challenge);
        (AVAGovernanceKernel.RecognisedStateReference memory target, bytes32 decisionHash) =
            _validateStoredChallengeAction(
                challenge,
                StoredPolicyInput({
                    actionKey: AVACoreTypes.ACTION_APPLY_RESTORATION,
                    roleKey: roleKey,
                    authorityId: authorityId,
                    outcome: challenge.outcome,
                    reasonHash: reasonHash
                })
            );
        if (target.lastTransitionId != challenge.targetTransitionIdAfterResolution) {
            revert AVACoreTypes.InvalidState(challengeId);
        }
        AVACoreTypes.RecognisedStateStatus restorationStatus = _restorationStatus(challenge.targetStatusAtFiling);
        _requireRestorationLineage(challenge, target);
        uint256 restorationTransitionId = target.lastTransitionId;
        if (target.status != restorationStatus) {
            restorationTransitionId = _requestRestorationTransition(
                challenge, target, roleKey, authorityId, restorationStatus, reasonHash, reasonURI, decisionHash
            );
        }
        ChallengeStatus fromStatus = challenge.status;
        challenge.status = ChallengeStatus.Closed;
        TransitionWriteInput memory writeInput;
        writeInput.kind = ChallengeTransitionKind.Restoration;
        writeInput.fromStatus = fromStatus;
        writeInput.toStatus = challenge.status;
        writeInput.outcome = challenge.outcome;
        writeInput.challengeStateTransitionIdBefore = challenge.challengeStateTransitionIdAfterResolution;
        writeInput.challengeStateTransitionIdAfter = challenge.challengeStateTransitionIdAfterResolution;
        writeInput.targetTransitionIdBefore = target.lastTransitionId;
        writeInput.targetTransitionIdAfter = restorationTransitionId;
        writeInput.authorityId = authorityId;
        writeInput.reasonHash = reasonHash;
        writeInput.reasonURI = reasonURI;
        writeInput.actor = msg.sender;
        transitionId = _recordTransition(challenge, writeInput);
        challenge.lastTransitionId = transitionId;
        _decrementOpenChallenge(challenge);
    }

    function closeChallenge(
        uint256 challengeId,
        bytes32 roleKey,
        bytes32 authorityId,
        bytes32 reasonHash,
        string calldata reasonURI
    ) external nonReentrantLifecycle returns (uint256 transitionId) {
        ChallengeRecord storage challenge = _challengeStorage(challengeId);
        bool preResolutionClose = challenge.status == ChallengeStatus.ConcernFiled
            || challenge.status == ChallengeStatus.AdmissibilityScreening;
        bool postResolutionClose =
            challenge.status == ChallengeStatus.Resolved || challenge.status == ChallengeStatus.RestorationAvailable;
        if (
            (!preResolutionClose && !postResolutionClose)
                || (preResolutionClose && challenge.outcome != ChallengeOutcome.None) || reasonHash == bytes32(0)
        ) {
            revert AVACoreTypes.InvalidState(challengeId);
        }
        (AVAGovernanceKernel.RecognisedStateReference memory target,) = _validateStoredChallengeAction(
            challenge,
            StoredPolicyInput({
                actionKey: AVACoreTypes.ACTION_CLOSE_CHALLENGE,
                roleKey: roleKey,
                authorityId: authorityId,
                outcome: challenge.outcome,
                reasonHash: reasonHash
            })
        );
        transitionId = _recordClosure(challenge, target.lastTransitionId, authorityId, reasonHash, reasonURI);
        _decrementOpenChallenge(challenge);
    }

    function getChallenge(uint256 id) external view returns (ChallengeRecord memory challenge) {
        challenge = challenges[id];
        if (challenge.id == 0) revert AVACoreTypes.UnknownReference(id);
    }

    function getChallengeTransition(uint256 id) external view returns (ChallengeTransitionRecord memory transition) {
        transition = transitions[id];
        if (transition.id == 0) revert AVACoreTypes.UnknownReference(id);
    }

    function validateTransition(
        uint256 packageId,
        uint256 recognisedStateId,
        AVACoreTypes.RecognisedStateStatus,
        AVACoreTypes.RecognisedStateStatus toStatus,
        AVACoreTypes.TransitionKind
    ) external view {
        AVAGovernanceKernel.RecognisedStateReference memory state =
            GOVERNANCE_KERNEL.getRecognisedStateReference(recognisedStateId);
        if (state.packageId != packageId) revert AVACoreTypes.InvalidState(recognisedStateId);
        if (
            toStatus == AVACoreTypes.RecognisedStateStatus.Vested
                && (openChallengeCountByRecognisedState[recognisedStateId] != 0
                    || (decisionBoundChallengeState[recognisedStateId]
                        && !decisionVestingInProgress[recognisedStateId]))
        ) {
            revert AVACoreTypes.InvalidState(recognisedStateId);
        }
    }

    function _validateChallengeFiling(ChallengeFilingInput calldata input)
        private
        view
        returns (
            AVAGovernanceKernel.RecognisedStateReference memory challengeState,
            AVAGovernanceKernel.GovernedObjectReference memory challengeObject,
            AVAGovernanceKernel.RecognisedStateReference memory target
        )
    {
        challengeState = GOVERNANCE_KERNEL.getRecognisedStateReference(input.challengeRecognisedStateId);
        target = GOVERNANCE_KERNEL.getRecognisedStateReference(input.challengedRecognisedStateId);
        challengeObject = GOVERNANCE_KERNEL.getGovernedObjectReference(challengeState.governedObjectId);
        if (
            challengeState.id == target.id || challengeState.appId != input.appId
                || challengeState.workflowKey != input.workflowKey || challengeState.packageId != input.packageId
                || challengeState.stage != AVACoreTypes.Stage.Verification
                || challengeState.status != AVACoreTypes.RecognisedStateStatus.Registered || target.appId != input.appId
                || !AVACoreTransitionRules.isChallengeTarget(target.status)
                || challengeObject.id == target.governedObjectId
                || challengeObject.parentObjectId != target.governedObjectId
                || challengeObject.appId != challengeState.appId
                || challengeObject.packageId != challengeState.packageId
                || challengeObject.subjectId != challengeState.subjectId
                || challengeObject.evidenceReceiptId != challengeState.evidenceReceiptId
                || challengeObject.disclosurePolicyId != challengeState.disclosurePolicyId
        ) revert AVACoreTypes.InvalidState(input.challengeRecognisedStateId);

        _requireAuthority(input.appId, input.roleKey, AVACoreTypes.ACTION_FILE_CHALLENGE, challengeState.subjectId);
        AVACoreRulePackageRegistry.VerifiedPackageContext memory challengePackage =
            RULE_PACKAGE_REGISTRY.getVerifiedPackageContext(input.packageId);
        if (target.packageId != challengeState.packageId) {
            AVACoreRulePackageRegistry.VerifiedPackageContext memory targetPackage =
                RULE_PACKAGE_REGISTRY.getVerifiedPackageContext(target.packageId);
            if (
                targetPackage.appId != input.appId || challengePackage.compatibilityKey != targetPackage.compatibilityKey
                    || GOVERNANCE_KERNEL.sourceBoundTransitionRequesterByPackage(target.packageId) != address(this)
                    || address(GOVERNANCE_KERNEL.transitionGuardByPackage(target.packageId)) != address(this)
            ) revert AVACoreTypes.InvalidState(input.packageId);
        }
        if (
            challengePackage.appId != input.appId || challengePackage.workflowKey != input.workflowKey
                || GOVERNANCE_KERNEL.sourceBoundTransitionRequesterByPackage(challengeState.packageId) != address(this)
                || address(GOVERNANCE_KERNEL.transitionGuardByPackage(challengeState.packageId)) != address(this)
        ) revert AVACoreTypes.InvalidState(input.packageId);
        _requireChallengeEvidence(challengeState);
        if (IDENTITY_REGISTRY.getSubjectContext(target.subjectId).account == msg.sender) {
            revert AVACoreTypes.NotAuthorised(msg.sender, AVACoreTypes.ACTION_FILE_CHALLENGE);
        }
        _validateFilingPolicies(input, challengeState, challengeObject, target);
    }

    function _requestChallengeFilingTransition(
        ChallengeRecord storage challenge,
        AVAGovernanceKernel.RecognisedStateReference memory challengeState,
        AVAGovernanceKernel.RecognisedStateReference memory target,
        ChallengeFilingInput calldata input
    ) private returns (uint256) {
        bytes32 decisionHash = keccak256(
            abi.encode(
                keccak256("ava.extension.challenge.filing-decision.v1"),
                challenge.id,
                challengeState.id,
                challengeState.lastTransitionId,
                target.id,
                target.lastTransitionId,
                challenge.packageId,
                target.packageId,
                input.reasonHash
            )
        );
        return GOVERNANCE_KERNEL.requestSourceBoundTransition(
            AVAGovernanceKernel.SourceBoundTransitionInput({
                recognisedStateId: challengeState.id,
                expectedTransitionId: challengeState.lastTransitionId,
                decisionPackageId: challenge.packageId,
                sourceRecordId: challenge.id,
                decisionEvidenceReceiptId: challengeState.evidenceReceiptId,
                disclosureTargetId: target.id,
                roleKey: input.roleKey,
                authorityId: challengeState.subjectId,
                actionKey: AVACoreTypes.ACTION_FILE_CHALLENGE,
                decisionHash: decisionHash,
                toStatus: AVACoreTypes.RecognisedStateStatus.Challengeable,
                kind: AVACoreTypes.TransitionKind.Generic,
                reasonHash: input.reasonHash,
                reasonURI: input.reasonURI
            })
        );
    }

    function _validateFilingPolicies(
        ChallengeFilingInput calldata input,
        AVAGovernanceKernel.RecognisedStateReference memory challengeState,
        AVAGovernanceKernel.GovernedObjectReference memory challengeObject,
        AVAGovernanceKernel.RecognisedStateReference memory target
    ) internal view {
        POLICY_ROUTER.validateChallengePolicies(
            AVAWorkflowPolicyRouter.ChallengePolicyInput({
                appId: input.appId,
                workflowKey: input.workflowKey,
                packageId: input.packageId,
                actionKey: AVACoreTypes.ACTION_FILE_CHALLENGE,
                roleKey: input.roleKey,
                stage: AVACoreTypes.Stage.Verification,
                objectTypeKey: challengeObject.objectTypeKey,
                challengeId: 0,
                recognisedStateId: target.id,
                actorSubjectId: challengeState.subjectId,
                targetSubjectId: target.subjectId,
                outcomeKey: bytes32(0),
                targetStatus: target.status,
                evidenceId: challengeState.evidenceReceiptId,
                disclosurePolicyId: challengeState.disclosurePolicyId,
                authorityId: challengeState.subjectId,
                decisionHash: bytes32(0),
                actor: msg.sender,
                validateDisclosure: false,
                validateAuthority: false
            })
        );
        if (target.packageId != input.packageId) {
            bytes32 targetObjectType = GOVERNANCE_KERNEL.getGovernedObjectReference(target.governedObjectId).objectTypeKey;
            POLICY_ROUTER.validateChallengePolicies(
                AVAWorkflowPolicyRouter.ChallengePolicyInput({
                    appId: target.appId,
                    workflowKey: target.workflowKey,
                    packageId: target.packageId,
                    actionKey: AVACoreTypes.ACTION_FILE_CHALLENGE,
                    roleKey: input.roleKey,
                    stage: target.stage,
                    objectTypeKey: targetObjectType,
                    challengeId: 0,
                    recognisedStateId: target.id,
                    actorSubjectId: challengeState.subjectId,
                    targetSubjectId: target.subjectId,
                    outcomeKey: bytes32(0),
                    targetStatus: target.status,
                    evidenceId: 0,
                    disclosurePolicyId: 0,
                    authorityId: challengeState.subjectId,
                    decisionHash: bytes32(0),
                    actor: msg.sender,
                    validateDisclosure: false,
                    validateAuthority: false
                })
            );
        }
    }

    function _validateStoredChallengeAction(ChallengeRecord storage challenge, StoredPolicyInput memory input)
        private
        view
        returns (AVAGovernanceKernel.RecognisedStateReference memory target, bytes32 decisionHash)
    {
        _requireAuthority(challenge.appId, input.roleKey, input.actionKey, input.authorityId);
        target = GOVERNANCE_KERNEL.getRecognisedStateReference(challenge.challengedRecognisedStateId);
        if (
            IDENTITY_REGISTRY.getSubjectContext(challenge.challengerSubjectId).account == msg.sender
                || IDENTITY_REGISTRY.getSubjectContext(target.subjectId).account == msg.sender
        ) revert AVACoreTypes.NotAuthorised(msg.sender, input.actionKey);
        bytes32 objectTypeKey = GOVERNANCE_KERNEL.getGovernedObjectReference(target.governedObjectId).objectTypeKey;
        decisionHash = _decisionHash(
            challenge.id,
            input.actionKey,
            target.lastTransitionId,
            input.outcome,
            input.reasonHash,
            challenge.packageId,
            challenge.targetPackageId
        );
        POLICY_ROUTER.validateChallengePolicies(
            AVAWorkflowPolicyRouter.ChallengePolicyInput({
                appId: challenge.appId,
                workflowKey: challenge.workflowKey,
                packageId: challenge.packageId,
                actionKey: input.actionKey,
                roleKey: input.roleKey,
                stage: target.stage,
                objectTypeKey: objectTypeKey,
                challengeId: challenge.id,
                recognisedStateId: target.id,
                actorSubjectId: input.authorityId,
                targetSubjectId: target.subjectId,
                outcomeKey: bytes32(uint256(uint8(input.outcome))),
                targetStatus: target.status,
                evidenceId: challenge.evidenceReceiptId,
                disclosurePolicyId: challenge.disclosurePolicyId,
                authorityId: input.authorityId,
                decisionHash: decisionHash,
                actor: msg.sender,
                validateDisclosure: false,
                validateAuthority: true
            })
        );
        if (challenge.targetPackageId != challenge.packageId) {
            POLICY_ROUTER.validateChallengePolicies(
                AVAWorkflowPolicyRouter.ChallengePolicyInput({
                    appId: target.appId,
                    workflowKey: target.workflowKey,
                    packageId: challenge.targetPackageId,
                    actionKey: input.actionKey,
                    roleKey: input.roleKey,
                    stage: target.stage,
                    objectTypeKey: objectTypeKey,
                    challengeId: challenge.id,
                    recognisedStateId: target.id,
                    actorSubjectId: input.authorityId,
                    targetSubjectId: target.subjectId,
                    outcomeKey: bytes32(uint256(uint8(input.outcome))),
                    targetStatus: target.status,
                    evidenceId: 0,
                    disclosurePolicyId: 0,
                    authorityId: input.authorityId,
                    decisionHash: decisionHash,
                    actor: msg.sender,
                    validateDisclosure: false,
                    validateAuthority: true
                })
            );
        }
    }

    function _decisionHash(
        uint256 challengeId,
        bytes32 actionKey,
        uint256 targetTransitionId,
        ChallengeOutcome outcome,
        bytes32 reasonHash,
        uint256 packageId,
        uint256 targetPackageId
    ) private pure returns (bytes32) {
        return keccak256(
            abi.encode(challengeId, actionKey, targetTransitionId, outcome, reasonHash, packageId, targetPackageId)
        );
    }

    function _requireChallengeEvidence(AVAGovernanceKernel.RecognisedStateReference memory challengeState)
        internal
        view
    {
        (
            bytes32 evidenceAppId,
            bytes32 evidenceWorkflowKey,
            ,
            bytes32 evidenceSubjectId,
            uint256 evidenceDisclosurePolicyId
        ) = EVIDENCE_REGISTRY.requireUsableEvidenceReferenceForPackage(
            challengeState.evidenceReceiptId, challengeState.packageId
        );
        if (
            evidenceAppId != challengeState.appId || evidenceWorkflowKey != challengeState.workflowKey
                || evidenceSubjectId != challengeState.subjectId
                || evidenceDisclosurePolicyId != challengeState.disclosurePolicyId
        ) {
            revert AVACoreTypes.InvalidState(challengeState.evidenceReceiptId);
        }
    }

    function _requireStoredChallengeEvidence(ChallengeRecord storage challenge) internal view {
        (
            bytes32 evidenceAppId,
            bytes32 evidenceWorkflowKey,
            ,
            bytes32 evidenceSubjectId,
            uint256 evidenceDisclosurePolicyId
        ) = EVIDENCE_REGISTRY.requireUsableEvidenceReferenceForPackage(challenge.evidenceReceiptId, challenge.packageId);
        if (
            evidenceAppId != challenge.appId || evidenceWorkflowKey != challenge.workflowKey
                || evidenceSubjectId != challenge.challengerSubjectId
                || evidenceDisclosurePolicyId != challenge.disclosurePolicyId
        ) {
            revert AVACoreTypes.InvalidState(challenge.evidenceReceiptId);
        }
    }

    function _requireAuthority(bytes32 appId, bytes32 roleKey, bytes32 actionKey, bytes32 authorityId) internal view {
        bytes32 callerAuthorityId =
            AUTHORITY_MATRIX.requireAuthorisedCanonicalSubject(msg.sender, appId, roleKey, actionKey);
        if (callerAuthorityId != authorityId) {
            revert AVACoreTypes.SubjectMismatch(callerAuthorityId, authorityId);
        }
    }

    function _recordTransition(ChallengeRecord storage challenge, TransitionWriteInput memory input)
        internal
        returns (uint256 transitionId)
    {
        transitionId = nextTransitionId++;
        ChallengeTransitionRecord storage record = transitions[transitionId];
        record.id = transitionId;
        record.challengeId = challenge.id;
        record.appId = challenge.appId;
        record.packageId = challenge.packageId;
        record.targetPackageId = challenge.targetPackageId;
        record.challengeRecognisedStateId = challenge.challengeRecognisedStateId;
        record.challengedRecognisedStateId = challenge.challengedRecognisedStateId;
        record.kind = input.kind;
        record.fromStatus = input.fromStatus;
        record.toStatus = input.toStatus;
        record.outcome = input.outcome;
        record.challengeStateTransitionIdBefore = input.challengeStateTransitionIdBefore;
        record.challengeStateTransitionIdAfter = input.challengeStateTransitionIdAfter;
        record.targetTransitionIdBefore = input.targetTransitionIdBefore;
        record.targetTransitionIdAfter = input.targetTransitionIdAfter;
        record.evidenceReceiptId = challenge.evidenceReceiptId;
        record.authorityId = input.authorityId;
        record.reasonHash = input.reasonHash;
        if (bytes(input.reasonURI).length != 0) record.reasonURI = input.reasonURI;
        record.createdBy = input.actor;
        record.createdAt = uint64(block.timestamp);
        emit ChallengeTransitionRecorded(
            transitionId,
            challenge.id,
            input.kind,
            input.fromStatus,
            input.toStatus,
            input.outcome,
            input.targetTransitionIdAfter,
            input.authorityId,
            input.actor
        );
    }

    function _recordClosure(
        ChallengeRecord storage challenge,
        uint256 targetTransitionId,
        bytes32 authorityId,
        bytes32 reasonHash,
        string calldata reasonURI
    ) private returns (uint256 transitionId) {
        ChallengeStatus fromStatus = challenge.status;
        challenge.status = ChallengeStatus.Closed;
        TransitionWriteInput memory writeInput;
        writeInput.kind = ChallengeTransitionKind.Closure;
        writeInput.fromStatus = fromStatus;
        writeInput.toStatus = challenge.status;
        writeInput.outcome = challenge.outcome;
        writeInput.challengeStateTransitionIdBefore = challenge.challengeStateTransitionIdAfterResolution;
        writeInput.challengeStateTransitionIdAfter = challenge.challengeStateTransitionIdAfterResolution;
        writeInput.targetTransitionIdBefore = targetTransitionId;
        writeInput.targetTransitionIdAfter = targetTransitionId;
        writeInput.authorityId = authorityId;
        writeInput.reasonHash = reasonHash;
        writeInput.reasonURI = reasonURI;
        writeInput.actor = msg.sender;
        transitionId = _recordTransition(challenge, writeInput);
        challenge.lastTransitionId = transitionId;
    }

    function _requestRestorationTransition(
        ChallengeRecord storage challenge,
        AVAGovernanceKernel.RecognisedStateReference memory target,
        bytes32 roleKey,
        bytes32 authorityId,
        AVACoreTypes.RecognisedStateStatus restorationStatus,
        bytes32 reasonHash,
        string calldata reasonURI,
        bytes32 decisionHash
    ) private returns (uint256) {
        return GOVERNANCE_KERNEL.requestSourceBoundTransition(
            AVAGovernanceKernel.SourceBoundTransitionInput({
                recognisedStateId: challenge.challengedRecognisedStateId,
                expectedTransitionId: target.lastTransitionId,
                decisionPackageId: challenge.packageId,
                sourceRecordId: challenge.id,
                decisionEvidenceReceiptId: challenge.evidenceReceiptId,
                disclosureTargetId: challenge.challengedRecognisedStateId,
                roleKey: roleKey,
                authorityId: authorityId,
                actionKey: AVACoreTypes.ACTION_APPLY_RESTORATION,
                decisionHash: decisionHash,
                toStatus: restorationStatus,
                kind: AVACoreTypes.TransitionKind.Restoration,
                reasonHash: reasonHash,
                reasonURI: reasonURI
            })
        );
    }

    function _decrementOpenChallenge(ChallengeRecord storage challenge) internal {
        uint256 openCount = openChallengeCountByRecognisedState[challenge.challengedRecognisedStateId];
        if (openCount == 0) revert AVACoreTypes.InvalidState(challenge.id);
        openChallengeCountByRecognisedState[challenge.challengedRecognisedStateId] = openCount - 1;
    }

    function _challengeStorage(uint256 id) internal view returns (ChallengeRecord storage challenge) {
        challenge = challenges[id];
        if (challenge.id == 0) revert AVACoreTypes.UnknownReference(id);
    }

    function _isRestorableOutcome(ChallengeOutcome outcome) private pure returns (bool) {
        return outcome == ChallengeOutcome.Upheld || outcome == ChallengeOutcome.RejectedGoodFaith
            || outcome == ChallengeOutcome.MaliciousOrFabricated;
    }

    function _restorationStatus(AVACoreTypes.RecognisedStateStatus targetStatusAtFiling)
        private
        pure
        returns (AVACoreTypes.RecognisedStateStatus)
    {
        if (targetStatusAtFiling == AVACoreTypes.RecognisedStateStatus.Challengeable) {
            return AVACoreTypes.RecognisedStateStatus.Challengeable;
        }
        if (
            targetStatusAtFiling == AVACoreTypes.RecognisedStateStatus.Vested
                || targetStatusAtFiling == AVACoreTypes.RecognisedStateStatus.Restored
        ) {
            return AVACoreTypes.RecognisedStateStatus.Restored;
        }
        revert AVACoreTypes.InvalidState(uint256(targetStatusAtFiling));
    }

    function _requireRestorationLineage(
        ChallengeRecord storage challenge,
        AVAGovernanceKernel.RecognisedStateReference memory target
    ) private view {
        if (challenge.outcome == ChallengeOutcome.Upheld) {
            if (
                target.status != AVACoreTypes.RecognisedStateStatus.Downgraded
                    && target.status != AVACoreTypes.RecognisedStateStatus.Voided
            ) {
                revert AVACoreTypes.InvalidState(challenge.id);
            }
            return;
        }
        if (
            target.lastTransitionId != challenge.targetTransitionIdAtFiling
                || challenge.targetTransitionIdAfterResolution != challenge.targetTransitionIdAtFiling
                || target.status != challenge.targetStatusAtFiling
        ) {
            revert AVACoreTypes.InvalidState(challenge.id);
        }
    }

    function _moduleConfigurationHash() internal view override returns (bytes32) {
        return keccak256(
            abi.encode(
                address(GOVERNANCE_KERNEL),
                address(AUTHORITY_MATRIX),
                address(IDENTITY_REGISTRY),
                address(RULE_PACKAGE_REGISTRY),
                address(EVIDENCE_REGISTRY)
            )
        );
    }

    function _filingKey(bytes32 appId, uint256 recognisedStateId, uint256 transitionId, address challengerAccount)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(appId, recognisedStateId, transitionId, challengerAccount));
    }
}
