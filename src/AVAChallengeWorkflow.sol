// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "./AVADataTypes.sol";
import {AVASubstrateTransitionRules} from "./AVASubstrateTransitionRules.sol";
import {AuthorityMatrix} from "./AuthorityMatrix.sol";
import {AVARulePackageRegistry} from "./AVARulePackageRegistry.sol";
import {AVAWorkflowValidator} from "./AVAWorkflowValidator.sol";
import {AVAStateMachine} from "./AVAStateMachine.sol";
import {StandingRevisionRegistry} from "./StandingRevisionRegistry.sol";
import {IChallengeLifecycleModule} from "./interfaces/IChallengeLifecycleModule.sol";
import {IChallengeRateLimitModule} from "./interfaces/IChallengeRateLimitModule.sol";
import {IResidualEditorialAuthorityModule} from "./interfaces/IResidualEditorialAuthorityModule.sol";
import {IAntiAbuseModule} from "./interfaces/IAntiAbuseModule.sol";

/// @notice Challenge, correction, and restoration workflow over recognised states.
contract AVAChallengeWorkflow {
    bytes32 private constant CHALLENGE_DECISION_DOMAIN = keccak256("AVA_CHALLENGE_DECISION_V2");

    struct ResolutionInput {
        AVADataTypes.Role actingRole;
        AVADataTypes.ChallengeOutcome outcome;
        AVADataTypes.RecognisedStateStatus toStatus;
        bytes32 authorityId;
        string reasonURI;
        address actor;
    }

    struct ChallengeTransitionInput {
        AVADataTypes.ChallengeTransitionKind transitionKind;
        AVADataTypes.ChallengeOutcome outcome;
        uint256 targetTransitionIdBefore;
        uint256 targetTransitionIdAfter;
        AVADataTypes.RecognisedStateStatus fromStatus;
        AVADataTypes.RecognisedStateStatus toStatus;
        AVADataTypes.Role authorityRole;
        bytes32 authorityId;
        string reasonURI;
    }

    struct ChallengeDecisionContext {
        uint256 challengeId;
        uint256 challengePackageId;
        uint256 targetPackageId;
        AVADataTypes.Action action;
        AVADataTypes.ChallengeLifecycleStatus lifecycleStatus;
        uint256 challengeTransitionId;
        AVADataTypes.RecognisedStateStatus fromStatus;
        AVADataTypes.RecognisedStateStatus toStatus;
        AVADataTypes.ChallengeOutcome outcome;
        uint256 evidenceReceiptId;
        uint256 targetTransitionId;
        bytes32 reasonHash;
    }

    AuthorityMatrix public immutable AUTHORITY_MATRIX;
    AVARulePackageRegistry public immutable RULE_PACKAGE_REGISTRY;
    AVAWorkflowValidator public immutable WORKFLOW_VALIDATOR;
    AVAStateMachine public immutable STATE_MACHINE;
    StandingRevisionRegistry public immutable STANDING_REVISION_REGISTRY;

    uint256 public nextChallengeId = 1;
    uint256 public nextChallengeTransitionId = 1;

    mapping(uint256 => AVADataTypes.ChallengeRecord) private challenges;
    mapping(uint256 => AVADataTypes.ChallengeTransitionRecord) private challengeTransitions;
    mapping(bytes32 => uint256) private challengeFilingCountsBySubjectTarget;
    mapping(bytes32 => uint256) private openChallengeIdBySubjectTarget;
    mapping(bytes32 => uint256) private challengeIdBySubjectTargetVersion;
    mapping(bytes32 => uint256) private openChallengeIdByAccountTarget;
    mapping(bytes32 => uint256) private challengeIdByAccountTargetVersion;

    event ChallengeFiled(
        uint256 indexed id,
        uint256 indexed challengedRecognisedStateId,
        bytes32 indexed challengerSubjectId,
        uint256 evidenceReceiptId,
        uint256 disclosurePolicyId,
        address filedBy
    );
    event ChallengeScreened(uint256 indexed challengeId);
    event ChallengeResolved(
        uint256 indexed challengeId, AVADataTypes.ChallengeOutcome outcome, uint256 indexed transitionId
    );
    event ChallengeTransitionRecorded(
        uint256 indexed id,
        uint256 indexed challengeId,
        uint256 indexed challengedRecognisedStateId,
        AVADataTypes.ChallengeTransitionKind transitionKind,
        AVADataTypes.ChallengeOutcome outcome
    );
    event RestorationApplied(
        uint256 indexed challengeId, uint256 indexed challengedRecognisedStateId, uint256 indexed transitionId
    );
    event ChallengeClosed(uint256 indexed challengeId, uint256 indexed transitionId);

    constructor(
        AuthorityMatrix authorityMatrix_,
        AVARulePackageRegistry rulePackageRegistry_,
        AVAWorkflowValidator workflowValidator_,
        AVAStateMachine stateMachine_,
        StandingRevisionRegistry standingRevisionRegistry_
    ) {
        if (address(standingRevisionRegistry_) == address(0)) {
            revert AVADataTypes.EmptyValue();
        }
        AUTHORITY_MATRIX = authorityMatrix_;
        RULE_PACKAGE_REGISTRY = rulePackageRegistry_;
        WORKFLOW_VALIDATOR = workflowValidator_;
        STATE_MACHINE = stateMachine_;
        STANDING_REVISION_REGISTRY = standingRevisionRegistry_;
    }

    function fileChallenge(
        AVADataTypes.Role actingRole,
        bytes32 appId,
        bytes32 workflowKey,
        uint256 challengedRecognisedStateId,
        bytes32 challengerSubjectId,
        uint256 evidenceReceiptId,
        uint256 disclosurePolicyId
    ) public returns (uint256 id) {
        AUTHORITY_MATRIX.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.FileChallenge, challengerSubjectId
        );
        AVADataTypes.RecognisedStateRecord memory challengedState =
            STATE_MACHINE.getRecognisedState(challengedRecognisedStateId);
        if (!_isChallengeTargetStatus(challengedState.status)) {
            revert AVADataTypes.InvalidState(challengedRecognisedStateId);
        }
        if (challengerSubjectId == bytes32(0) || evidenceReceiptId == 0) {
            revert AVADataTypes.EmptyValue();
        }

        AVAWorkflowValidator.WorkflowValidationResult memory validation = WORKFLOW_VALIDATOR.validateActivePackage(
            AVAWorkflowValidator.WorkflowValidationContext({
                appId: appId,
                workflowKey: workflowKey,
                actingRole: actingRole,
                action: AVADataTypes.Action.FileChallenge,
                stage: AVADataTypes.AVAStage.Verification,
                objectId: bytes32(challengedRecognisedStateId),
                subjectId: challengerSubjectId,
                evidenceReceiptId: evidenceReceiptId,
                disclosurePolicyId: disclosurePolicyId,
                actor: msg.sender
            })
        );
        WORKFLOW_VALIDATOR.requireCompatibleRulePackages(
            workflowKey, validation.packageId, challengedState.workflowKey, challengedState.packageId
        );
        _validateChallengeLifecycle(
            validation.challengeLifecycleModule,
            IChallengeLifecycleModule.ChallengeLifecycleContext({
                workflowKey: workflowKey,
                action: AVADataTypes.Action.FileChallenge,
                fromLifecycleStatus: AVADataTypes.ChallengeLifecycleStatus.None,
                toLifecycleStatus: AVADataTypes.ChallengeLifecycleStatus.ConcernFiled,
                outcome: AVADataTypes.ChallengeOutcome.None,
                challengedStateStatus: challengedState.status,
                proposedStateStatus: challengedState.status,
                actor: msg.sender,
                filedBy: msg.sender
            })
        );
        bytes32 filingKey =
            keccak256(abi.encode(validation.packageId, challengedRecognisedStateId, challengerSubjectId));
        _requireChallengeFilingAvailable(
            challengedRecognisedStateId, challengedState.lastTransitionId, challengerSubjectId, msg.sender
        );
        _validateChallengeFilingIfConfigured(
            validation.antiAbuseModule,
            workflowKey,
            challengedRecognisedStateId,
            challengerSubjectId,
            challengeFilingCountsBySubjectTarget[filingKey]
        );

        id = nextChallengeId++;
        challenges[id] = AVADataTypes.ChallengeRecord({
            id: id,
            appId: appId,
            workflowKey: workflowKey,
            packageId: validation.packageId,
            targetWorkflowKey: challengedState.workflowKey,
            targetPackageId: challengedState.packageId,
            challengedRecognisedStateId: challengedRecognisedStateId,
            attributedObjectId: validation.attributedObjectId,
            challengerSubjectId: challengerSubjectId,
            evidenceReceiptId: evidenceReceiptId,
            disclosurePolicyId: disclosurePolicyId,
            targetStatusAtFiling: challengedState.status,
            targetTransitionIdAtFiling: challengedState.lastTransitionId,
            status: AVADataTypes.ChallengeLifecycleStatus.ConcernFiled,
            outcome: AVADataTypes.ChallengeOutcome.None,
            lastTransitionId: 0,
            filedBy: msg.sender
        });
        STATE_MACHINE.registerOpenChallenge(challengedRecognisedStateId);
        challengeFilingCountsBySubjectTarget[filingKey] += 1;
        _recordChallengeFilingCaps(
            challengedRecognisedStateId, challengedState.lastTransitionId, challengerSubjectId, msg.sender, id
        );

        emit ChallengeFiled(
            id, challengedRecognisedStateId, challengerSubjectId, evidenceReceiptId, disclosurePolicyId, msg.sender
        );
    }

    function _isChallengeTargetStatus(AVADataTypes.RecognisedStateStatus status) internal pure returns (bool) {
        return AVASubstrateTransitionRules.isChallengeTarget(status);
    }

    function screenChallenge(AVADataTypes.Role actingRole, uint256 challengeId, bytes32 authorityId) external {
        AUTHORITY_MATRIX.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.ScreenChallenge, authorityId
        );
        AVADataTypes.ChallengeRecord storage challenge = challenges[challengeId];
        if (challenge.id == 0) revert AVADataTypes.UnknownReference(challengeId);
        if (challenge.status != AVADataTypes.ChallengeLifecycleStatus.ConcernFiled) {
            revert AVADataTypes.InvalidState(challengeId);
        }
        if (authorityId == bytes32(0)) revert AVADataTypes.EmptyValue();

        AVADataTypes.RecognisedStateRecord memory challengedState =
            STATE_MACHINE.getRecognisedState(challenge.challengedRecognisedStateId);
        _requireNoDecisionConflict(
            msg.sender, authorityId, challenge, challengedState, AVADataTypes.Action.ScreenChallenge
        );
        AVADataTypes.RecognisedStateStatus currentStatus = challengedState.status;
        AVARulePackageRegistry.RulePackage memory rulePackage = _verifiedChallengePackage(challenge);
        _validatePinnedChallengeEvidence(rulePackage, challenge, AVADataTypes.Action.ScreenChallenge, msg.sender);
        _validateDisclosure(rulePackage, challenge, actingRole, AVADataTypes.Action.ScreenChallenge);
        _validateChallengeLifecycle(
            rulePackage.challengeLifecycleModule,
            IChallengeLifecycleModule.ChallengeLifecycleContext({
                workflowKey: challenge.workflowKey,
                action: AVADataTypes.Action.ScreenChallenge,
                fromLifecycleStatus: challenge.status,
                toLifecycleStatus: AVADataTypes.ChallengeLifecycleStatus.AdmissibilityScreening,
                outcome: AVADataTypes.ChallengeOutcome.None,
                challengedStateStatus: currentStatus,
                proposedStateStatus: currentStatus,
                actor: msg.sender,
                filedBy: challenge.filedBy
            })
        );
        _validateResidualAuthority(
            rulePackage.residualEditorialAuthorityModule,
            challenge,
            actingRole,
            AVADataTypes.Action.ScreenChallenge,
            authorityId,
            _decisionHashForChallenge(
                challenge,
                AVADataTypes.Action.ScreenChallenge,
                currentStatus,
                currentStatus,
                AVADataTypes.ChallengeOutcome.None,
                challengedState.lastTransitionId,
                bytes32(0)
            )
        );

        challenge.status = AVADataTypes.ChallengeLifecycleStatus.AdmissibilityScreening;
        challenge.lastTransitionId = _recordChallengeTransition(
            challenge,
            ChallengeTransitionInput({
                transitionKind: AVADataTypes.ChallengeTransitionKind.AdmissibilityScreened,
                outcome: AVADataTypes.ChallengeOutcome.None,
                targetTransitionIdBefore: challengedState.lastTransitionId,
                targetTransitionIdAfter: challengedState.lastTransitionId,
                fromStatus: currentStatus,
                toStatus: currentStatus,
                authorityRole: actingRole,
                authorityId: authorityId,
                reasonURI: ""
            })
        );
        emit ChallengeScreened(challengeId);
    }

    function resolveChallenge(
        AVADataTypes.Role actingRole,
        uint256 challengeId,
        AVADataTypes.ChallengeOutcome outcome,
        AVADataTypes.RecognisedStateStatus toStatus,
        bytes32 authorityId,
        string calldata reasonURI
    ) external {
        _resolveChallenge(
            challengeId,
            ResolutionInput({
                actingRole: actingRole,
                outcome: outcome,
                toStatus: toStatus,
                authorityId: authorityId,
                reasonURI: reasonURI,
                actor: msg.sender
            })
        );
    }

    function _resolveChallenge(uint256 challengeId, ResolutionInput memory input) internal {
        AUTHORITY_MATRIX.requireAuthorisedSubject(
            input.actor, input.actingRole, AVADataTypes.Action.ResolveChallenge, input.authorityId
        );
        AVADataTypes.ChallengeRecord storage challenge = challenges[challengeId];
        if (challenge.id == 0) revert AVADataTypes.UnknownReference(challengeId);
        if (challenge.status != AVADataTypes.ChallengeLifecycleStatus.AdmissibilityScreening) {
            revert AVADataTypes.InvalidState(challengeId);
        }
        AVADataTypes.RecognisedStateRecord memory challengedState =
            STATE_MACHINE.getRecognisedState(challenge.challengedRecognisedStateId);
        _requireNoDecisionConflict(
            input.actor, input.authorityId, challenge, challengedState, AVADataTypes.Action.ResolveChallenge
        );
        if (!_isResolutionOutcome(input.outcome)) revert AVADataTypes.InvalidState(challengeId);

        bool mutatesState = input.outcome == AVADataTypes.ChallengeOutcome.Upheld;
        if (mutatesState) {
            if (!AVASubstrateTransitionRules.isChallengeCorrection(
                    challengedState.status, input.toStatus, input.outcome
                )) {
                revert AVADataTypes.InvalidState(challengeId);
            }
        } else if (input.toStatus != challengedState.status) {
            revert AVADataTypes.InvalidState(challengeId);
        }

        AVARulePackageRegistry.RulePackage memory rulePackage = _verifiedChallengePackage(challenge);
        _validatePinnedChallengeEvidence(rulePackage, challenge, AVADataTypes.Action.ResolveChallenge, input.actor);
        _validateResolutionModules(rulePackage, challenge, challengedState, input);

        uint256 targetTransitionIdBefore = challengedState.lastTransitionId;
        uint256 targetTransitionIdAfter = targetTransitionIdBefore;
        if (mutatesState) {
            if (targetTransitionIdBefore != challenge.targetTransitionIdAtFiling) {
                revert AVADataTypes.InvalidState(challengeId);
            }
            targetTransitionIdAfter = STATE_MACHINE.applyChallengeStateTransition(
                AVAStateMachine.ChallengeStateTransitionInput({
                    recognisedStateId: challenge.challengedRecognisedStateId,
                    challengeId: challenge.id,
                    decisionPackageId: challenge.packageId,
                    evidenceReceiptId: challenge.evidenceReceiptId,
                    action: AVADataTypes.Action.ResolveChallenge,
                    outcome: input.outcome,
                    targetStatusAtFiling: challenge.targetStatusAtFiling,
                    toStatus: input.toStatus,
                    authorityRole: input.actingRole,
                    authorityId: input.authorityId,
                    reasonURI: input.reasonURI,
                    actor: input.actor
                })
            );
        }
        uint256 transitionId = _recordChallengeTransition(
            challenge,
            ChallengeTransitionInput({
                transitionKind: AVADataTypes.ChallengeTransitionKind.OutcomeResolved,
                outcome: input.outcome,
                targetTransitionIdBefore: targetTransitionIdBefore,
                targetTransitionIdAfter: targetTransitionIdAfter,
                fromStatus: challengedState.status,
                toStatus: input.toStatus,
                authorityRole: input.actingRole,
                authorityId: input.authorityId,
                reasonURI: input.reasonURI
            })
        );
        challenge.status = AVADataTypes.ChallengeLifecycleStatus.Resolved;
        challenge.outcome = input.outcome;
        challenge.lastTransitionId = transitionId;
        _advanceChallengeResolutionRevisions(challenge, challengedState, transitionId, mutatesState);
        emit ChallengeResolved(challengeId, input.outcome, transitionId);
    }

    function applyRestoration(
        AVADataTypes.Role actingRole,
        uint256 challengeId,
        bytes32 authorityId,
        string calldata reasonURI
    ) external {
        AUTHORITY_MATRIX.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.ApplyRestoration, authorityId
        );
        AVADataTypes.ChallengeRecord storage challenge = challenges[challengeId];
        if (challenge.id == 0) revert AVADataTypes.UnknownReference(challengeId);
        if (challenge.status != AVADataTypes.ChallengeLifecycleStatus.Resolved) {
            revert AVADataTypes.InvalidState(challengeId);
        }
        AVADataTypes.RecognisedStateRecord memory state =
            STATE_MACHINE.getRecognisedState(challenge.challengedRecognisedStateId);
        _requireNoDecisionConflict(msg.sender, authorityId, challenge, state, AVADataTypes.Action.ApplyRestoration);
        AVADataTypes.ChallengeTransitionRecord storage resolutionTransition =
            challengeTransitions[challenge.lastTransitionId];
        if (
            resolutionTransition.id == 0
                || resolutionTransition.transitionKind != AVADataTypes.ChallengeTransitionKind.OutcomeResolved
                || resolutionTransition.outcome != challenge.outcome || resolutionTransition.toStatus != state.status
                || resolutionTransition.targetTransitionIdAfter != state.lastTransitionId
        ) {
            revert AVADataTypes.InvalidState(challengeId);
        }
        _requireRestorationLineage(challenge, resolutionTransition, state);
        AVADataTypes.RecognisedStateStatus restorationTarget =
            AVASubstrateTransitionRules.restorationTargetStatus(challenge.targetStatusAtFiling);
        if (!AVASubstrateTransitionRules.isRestorationTransition(
                challenge.outcome, state.status, restorationTarget, challenge.targetStatusAtFiling
            )) {
            revert AVADataTypes.InvalidState(challengeId);
        }

        AVARulePackageRegistry.RulePackage memory rulePackage = _verifiedChallengePackage(challenge);
        _validatePinnedChallengeEvidence(rulePackage, challenge, AVADataTypes.Action.ApplyRestoration, msg.sender);
        _validateDisclosure(rulePackage, challenge, actingRole, AVADataTypes.Action.ApplyRestoration);
        _validateChallengeLifecycle(
            rulePackage.challengeLifecycleModule,
            IChallengeLifecycleModule.ChallengeLifecycleContext({
                workflowKey: challenge.workflowKey,
                action: AVADataTypes.Action.ApplyRestoration,
                fromLifecycleStatus: challenge.status,
                toLifecycleStatus: AVADataTypes.ChallengeLifecycleStatus.RestorationApplied,
                outcome: challenge.outcome,
                challengedStateStatus: state.status,
                proposedStateStatus: restorationTarget,
                actor: msg.sender,
                filedBy: challenge.filedBy
            })
        );
        _validateRestorationAuthority(
            rulePackage.residualEditorialAuthorityModule,
            challenge,
            state,
            restorationTarget,
            actingRole,
            authorityId,
            reasonURI
        );

        uint256 transitionId =
            _writeRestorationTransition(challenge, state, restorationTarget, actingRole, authorityId, reasonURI);
        challenge.status = AVADataTypes.ChallengeLifecycleStatus.RestorationApplied;
        challenge.lastTransitionId = transitionId;
        emit RestorationApplied(challengeId, challenge.challengedRecognisedStateId, transitionId);
    }

    function _writeRestorationTransition(
        AVADataTypes.ChallengeRecord storage challenge,
        AVADataTypes.RecognisedStateRecord memory state,
        AVADataTypes.RecognisedStateStatus restorationTarget,
        AVADataTypes.Role actingRole,
        bytes32 authorityId,
        string calldata reasonURI
    ) internal returns (uint256 transitionId) {
        uint256 targetTransitionIdAfter = state.lastTransitionId;
        if (state.status != restorationTarget) {
            targetTransitionIdAfter = STATE_MACHINE.applyChallengeStateTransition(
                AVAStateMachine.ChallengeStateTransitionInput({
                    recognisedStateId: challenge.challengedRecognisedStateId,
                    challengeId: challenge.id,
                    decisionPackageId: challenge.packageId,
                    evidenceReceiptId: challenge.evidenceReceiptId,
                    action: AVADataTypes.Action.ApplyRestoration,
                    outcome: challenge.outcome,
                    targetStatusAtFiling: challenge.targetStatusAtFiling,
                    toStatus: restorationTarget,
                    authorityRole: actingRole,
                    authorityId: authorityId,
                    reasonURI: reasonURI,
                    actor: msg.sender
                })
            );
        }
        transitionId = _recordChallengeTransition(
            challenge,
            ChallengeTransitionInput({
                transitionKind: AVADataTypes.ChallengeTransitionKind.RestorationRecorded,
                outcome: challenge.outcome,
                targetTransitionIdBefore: state.lastTransitionId,
                targetTransitionIdAfter: targetTransitionIdAfter,
                fromStatus: state.status,
                toStatus: restorationTarget,
                authorityRole: actingRole,
                authorityId: authorityId,
                reasonURI: reasonURI
            })
        );
    }

    function closeChallenge(
        AVADataTypes.Role actingRole,
        uint256 challengeId,
        bytes32 authorityId,
        string calldata reasonURI
    ) external {
        AUTHORITY_MATRIX.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.CloseChallenge, authorityId
        );
        AVADataTypes.ChallengeRecord storage challenge = challenges[challengeId];
        if (challenge.id == 0) revert AVADataTypes.UnknownReference(challengeId);
        bool preResolutionClose = challenge.status == AVADataTypes.ChallengeLifecycleStatus.ConcernFiled
            || challenge.status == AVADataTypes.ChallengeLifecycleStatus.AdmissibilityScreening;
        bool postResolutionClose = challenge.status == AVADataTypes.ChallengeLifecycleStatus.Resolved
            || challenge.status == AVADataTypes.ChallengeLifecycleStatus.RestorationApplied;
        if (
            (!preResolutionClose && !postResolutionClose)
                || (preResolutionClose && challenge.outcome != AVADataTypes.ChallengeOutcome.None)
        ) {
            revert AVADataTypes.InvalidState(challengeId);
        }
        AVADataTypes.RecognisedStateRecord memory challengedState =
            STATE_MACHINE.getRecognisedState(challenge.challengedRecognisedStateId);
        _requireNoDecisionConflict(
            msg.sender, authorityId, challenge, challengedState, AVADataTypes.Action.CloseChallenge
        );
        AVADataTypes.RecognisedStateStatus currentStatus = challengedState.status;
        AVARulePackageRegistry.RulePackage memory rulePackage = _verifiedChallengePackage(challenge);
        _validateDisclosure(rulePackage, challenge, actingRole, AVADataTypes.Action.CloseChallenge);
        _validateChallengeLifecycle(
            rulePackage.challengeLifecycleModule,
            IChallengeLifecycleModule.ChallengeLifecycleContext({
                workflowKey: challenge.workflowKey,
                action: AVADataTypes.Action.CloseChallenge,
                fromLifecycleStatus: challenge.status,
                toLifecycleStatus: AVADataTypes.ChallengeLifecycleStatus.Closed,
                outcome: challenge.outcome,
                challengedStateStatus: currentStatus,
                proposedStateStatus: currentStatus,
                actor: msg.sender,
                filedBy: challenge.filedBy
            })
        );
        _validateCloseAuthority(
            rulePackage.residualEditorialAuthorityModule, challenge, challengedState, actingRole, authorityId, reasonURI
        );

        uint256 transitionId = _recordChallengeTransition(
            challenge,
            ChallengeTransitionInput({
                transitionKind: AVADataTypes.ChallengeTransitionKind.Closed,
                outcome: challenge.outcome,
                targetTransitionIdBefore: challengedState.lastTransitionId,
                targetTransitionIdAfter: challengedState.lastTransitionId,
                fromStatus: currentStatus,
                toStatus: currentStatus,
                authorityRole: actingRole,
                authorityId: authorityId,
                reasonURI: reasonURI
            })
        );
        STATE_MACHINE.closeOpenChallenge(challenge.challengedRecognisedStateId);
        _releaseOpenChallengeCaps(challenge, challengeId);
        challenge.status = AVADataTypes.ChallengeLifecycleStatus.Closed;
        challenge.lastTransitionId = transitionId;
        emit ChallengeClosed(challengeId, transitionId);
    }

    function getChallenge(uint256 id) external view returns (AVADataTypes.ChallengeRecord memory) {
        AVADataTypes.ChallengeRecord memory challenge = challenges[id];
        if (challenge.id == 0) revert AVADataTypes.UnknownReference(id);
        return challenge;
    }

    function getChallengeTransition(uint256 id) external view returns (AVADataTypes.ChallengeTransitionRecord memory) {
        AVADataTypes.ChallengeTransitionRecord memory transition = challengeTransitions[id];
        if (transition.id == 0) revert AVADataTypes.UnknownReference(id);
        return transition;
    }

    function _decisionHashForChallenge(
        AVADataTypes.ChallengeRecord storage challenge,
        AVADataTypes.Action action,
        AVADataTypes.RecognisedStateStatus fromStatus,
        AVADataTypes.RecognisedStateStatus toStatus,
        AVADataTypes.ChallengeOutcome outcome,
        uint256 targetTransitionId,
        bytes32 reasonHash
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                CHALLENGE_DECISION_DOMAIN,
                ChallengeDecisionContext({
                    challengeId: challenge.id,
                    challengePackageId: challenge.packageId,
                    targetPackageId: challenge.targetPackageId,
                    action: action,
                    lifecycleStatus: challenge.status,
                    challengeTransitionId: challenge.lastTransitionId,
                    fromStatus: fromStatus,
                    toStatus: toStatus,
                    outcome: outcome,
                    evidenceReceiptId: challenge.evidenceReceiptId,
                    targetTransitionId: targetTransitionId,
                    reasonHash: reasonHash
                })
            )
        );
    }

    function _recordChallengeTransition(
        AVADataTypes.ChallengeRecord memory challenge,
        ChallengeTransitionInput memory input
    ) internal returns (uint256 id) {
        id = nextChallengeTransitionId++;
        challengeTransitions[id] = AVADataTypes.ChallengeTransitionRecord({
            id: id,
            workflowKey: challenge.workflowKey,
            packageId: challenge.packageId,
            targetPackageId: challenge.targetPackageId,
            challengeId: challenge.id,
            challengedRecognisedStateId: challenge.challengedRecognisedStateId,
            targetTransitionIdBefore: input.targetTransitionIdBefore,
            targetTransitionIdAfter: input.targetTransitionIdAfter,
            fromStatus: input.fromStatus,
            toStatus: input.toStatus,
            transitionKind: input.transitionKind,
            outcome: input.outcome,
            evidenceReceiptId: challenge.evidenceReceiptId,
            authorityRole: input.authorityRole,
            authorityId: input.authorityId,
            reasonURI: input.reasonURI,
            createdAt: block.timestamp,
            createdBy: msg.sender
        });
        emit ChallengeTransitionRecorded(
            id, challenge.id, challenge.challengedRecognisedStateId, input.transitionKind, input.outcome
        );
    }

    function _advanceChallengeResolutionRevisions(
        AVADataTypes.ChallengeRecord storage challenge,
        AVADataTypes.RecognisedStateRecord memory challengedState,
        uint256 transitionId,
        bool targetRevisionAdvancedByStateTransition
    ) internal {
        if (!targetRevisionAdvancedByStateTransition) {
            STANDING_REVISION_REGISTRY.advanceRevision(
                challenge.targetPackageId,
                challengedState.subjectId,
                AVADataTypes.StandingRevisionReason.ChallengeResolution,
                transitionId
            );
        }
        if (
            challenge.packageId != challenge.targetPackageId
                || challenge.challengerSubjectId != challengedState.subjectId
        ) {
            STANDING_REVISION_REGISTRY.advanceRevision(
                challenge.packageId,
                challenge.challengerSubjectId,
                AVADataTypes.StandingRevisionReason.ChallengeResolution,
                transitionId
            );
        }
    }

    function _verifiedChallengePackage(AVADataTypes.ChallengeRecord storage challenge)
        internal
        view
        returns (AVARulePackageRegistry.RulePackage memory rulePackage)
    {
        rulePackage = RULE_PACKAGE_REGISTRY.getRulePackageById(challenge.packageId);
        if (rulePackage.appId != challenge.appId || rulePackage.workflowKey != challenge.workflowKey) {
            revert AVADataTypes.InvalidState(challenge.packageId);
        }
    }

    function _validateDisclosure(
        AVARulePackageRegistry.RulePackage memory rulePackage,
        AVADataTypes.ChallengeRecord storage challenge,
        AVADataTypes.Role actingRole,
        AVADataTypes.Action action
    ) internal view {
        rulePackage.disclosureModule
            .validateDisclosureForAction(
                challenge.disclosurePolicyId,
                actingRole,
                action,
                AVADataTypes.AVAStage.Verification,
                bytes32(challenge.challengedRecognisedStateId),
                challenge.workflowKey,
                challenge.packageId,
                challenge.challengerSubjectId
            );
    }

    function _validatePinnedChallengeEvidence(
        AVARulePackageRegistry.RulePackage memory rulePackage,
        AVADataTypes.ChallengeRecord storage challenge,
        AVADataTypes.Action action,
        address actor
    ) internal view {
        WORKFLOW_VALIDATOR.requireUsablePinnedEvidenceReceipt(
            challenge.appId, challenge.workflowKey, challenge.packageId, challenge.evidenceReceiptId
        );
        rulePackage.evidenceLifecycleModule
            .validateEvidenceLifecycle(
                challenge.workflowKey,
                action,
                challenge.evidenceReceiptId,
                AVADataTypes.EvidenceLifecycleKind.None,
                0,
                bytes32(0),
                actor
            );
    }

    function _validateResolutionModules(
        AVARulePackageRegistry.RulePackage memory rulePackage,
        AVADataTypes.ChallengeRecord storage challenge,
        AVADataTypes.RecognisedStateRecord memory challengedState,
        ResolutionInput memory input
    ) internal view {
        _validateDisclosure(rulePackage, challenge, input.actingRole, AVADataTypes.Action.ResolveChallenge);
        _validateChallengeLifecycle(
            rulePackage.challengeLifecycleModule,
            IChallengeLifecycleModule.ChallengeLifecycleContext({
                workflowKey: challenge.workflowKey,
                action: AVADataTypes.Action.ResolveChallenge,
                fromLifecycleStatus: challenge.status,
                toLifecycleStatus: AVADataTypes.ChallengeLifecycleStatus.Resolved,
                outcome: input.outcome,
                challengedStateStatus: challengedState.status,
                proposedStateStatus: input.toStatus,
                actor: input.actor,
                filedBy: challenge.filedBy
            })
        );
        bytes32 decisionHash = _decisionHashForChallenge(
            challenge,
            AVADataTypes.Action.ResolveChallenge,
            challengedState.status,
            input.toStatus,
            input.outcome,
            challengedState.lastTransitionId,
            keccak256(bytes(input.reasonURI))
        );
        _validateBothResidualAuthorities(
            rulePackage.residualEditorialAuthorityModule,
            challenge,
            input.actingRole,
            AVADataTypes.Action.ResolveChallenge,
            input.authorityId,
            decisionHash
        );
    }

    function _validateChallengeLifecycle(
        IChallengeLifecycleModule challengeLifecycleModule,
        IChallengeLifecycleModule.ChallengeLifecycleContext memory context
    ) internal view {
        challengeLifecycleModule.validateChallengeAction(context);
    }

    function _validateResidualAuthority(
        IResidualEditorialAuthorityModule residualEditorialAuthorityModule,
        AVADataTypes.ChallengeRecord storage challenge,
        AVADataTypes.Role actingRole,
        AVADataTypes.Action action,
        bytes32 authorityId,
        bytes32 decisionHash
    ) internal view {
        residualEditorialAuthorityModule.validateResidualEditorialAuthority(
            IResidualEditorialAuthorityModule.ResidualEditorialAuthorityContext({
                workflowKey: challenge.workflowKey,
                packageId: challenge.packageId,
                targetPackageId: challenge.targetPackageId,
                actingRole: actingRole,
                action: action,
                recognisedStateId: challenge.challengedRecognisedStateId,
                challengeId: challenge.id,
                objectId: challenge.attributedObjectId,
                evidenceReceiptId: challenge.evidenceReceiptId,
                authorityId: authorityId,
                decisionHash: decisionHash,
                actor: msg.sender
            })
        );
    }

    function _validateBothResidualAuthorities(
        IResidualEditorialAuthorityModule residualEditorialAuthorityModule,
        AVADataTypes.ChallengeRecord storage challenge,
        AVADataTypes.Role actingRole,
        AVADataTypes.Action action,
        bytes32 authorityId,
        bytes32 decisionHash
    ) internal view {
        _validateResidualAuthority(
            residualEditorialAuthorityModule, challenge, actingRole, action, authorityId, decisionHash
        );
        _validateTargetResidualAuthority(challenge, actingRole, action, authorityId, decisionHash);
    }

    function _validateRestorationAuthority(
        IResidualEditorialAuthorityModule residualEditorialAuthorityModule,
        AVADataTypes.ChallengeRecord storage challenge,
        AVADataTypes.RecognisedStateRecord memory state,
        AVADataTypes.RecognisedStateStatus restorationTarget,
        AVADataTypes.Role actingRole,
        bytes32 authorityId,
        string calldata reasonURI
    ) internal view {
        bytes32 decisionHash = _decisionHashForChallenge(
            challenge,
            AVADataTypes.Action.ApplyRestoration,
            state.status,
            restorationTarget,
            challenge.outcome,
            state.lastTransitionId,
            keccak256(bytes(reasonURI))
        );
        _validateBothResidualAuthorities(
            residualEditorialAuthorityModule,
            challenge,
            actingRole,
            AVADataTypes.Action.ApplyRestoration,
            authorityId,
            decisionHash
        );
    }

    function _validateTargetResidualAuthority(
        AVADataTypes.ChallengeRecord storage challenge,
        AVADataTypes.Role actingRole,
        AVADataTypes.Action action,
        bytes32 authorityId,
        bytes32 decisionHash
    ) internal view {
        WORKFLOW_VALIDATOR.validateTargetResidualAuthority(
            challenge.workflowKey,
            challenge.packageId,
            IResidualEditorialAuthorityModule.ResidualEditorialAuthorityContext({
                workflowKey: challenge.targetWorkflowKey,
                packageId: challenge.targetPackageId,
                targetPackageId: challenge.packageId,
                actingRole: actingRole,
                action: action,
                recognisedStateId: challenge.challengedRecognisedStateId,
                challengeId: challenge.id,
                objectId: challenge.attributedObjectId,
                evidenceReceiptId: challenge.evidenceReceiptId,
                authorityId: authorityId,
                decisionHash: decisionHash,
                actor: msg.sender
            })
        );
    }

    function _validateCloseAuthority(
        IResidualEditorialAuthorityModule residualEditorialAuthorityModule,
        AVADataTypes.ChallengeRecord storage challenge,
        AVADataTypes.RecognisedStateRecord memory state,
        AVADataTypes.Role actingRole,
        bytes32 authorityId,
        string calldata reasonURI
    ) internal view {
        bytes32 decisionHash = _decisionHashForChallenge(
            challenge,
            AVADataTypes.Action.CloseChallenge,
            state.status,
            state.status,
            challenge.outcome,
            state.lastTransitionId,
            keccak256(bytes(reasonURI))
        );
        _validateBothResidualAuthorities(
            residualEditorialAuthorityModule,
            challenge,
            actingRole,
            AVADataTypes.Action.CloseChallenge,
            authorityId,
            decisionHash
        );
    }

    function _validateChallengeFilingIfConfigured(
        IAntiAbuseModule antiAbuseModule,
        bytes32 workflowKey,
        uint256 challengedRecognisedStateId,
        bytes32 challengerSubjectId,
        uint256 priorFilingCount
    ) internal view {
        if (!_supportsChallengeRateLimit(address(antiAbuseModule))) return;
        (bool success, bytes memory result) = address(antiAbuseModule)
            .staticcall(
                abi.encodeWithSelector(
                    IChallengeRateLimitModule.validateChallengeFiling.selector,
                    workflowKey,
                    challengedRecognisedStateId,
                    challengerSubjectId,
                    priorFilingCount,
                    msg.sender
                )
            );
        _handleRequiredModuleResult(success, result);
    }

    function _requireChallengeFilingAvailable(
        uint256 recognisedStateId,
        uint256 targetTransitionId,
        bytes32 challengerSubjectId,
        address challengerAccount
    ) internal view {
        uint256 existingChallengeId = openChallengeIdBySubjectTarget[
            keccak256(abi.encode(recognisedStateId, challengerSubjectId))
        ];
        if (existingChallengeId != 0) revert AVADataTypes.InvalidState(existingChallengeId);
        existingChallengeId = challengeIdBySubjectTargetVersion[
            keccak256(abi.encode(recognisedStateId, challengerSubjectId, targetTransitionId))
        ];
        if (existingChallengeId != 0) revert AVADataTypes.InvalidState(existingChallengeId);
        existingChallengeId =
            openChallengeIdByAccountTarget[keccak256(abi.encode(recognisedStateId, challengerAccount))];
        if (existingChallengeId != 0) revert AVADataTypes.InvalidState(existingChallengeId);
        existingChallengeId = challengeIdByAccountTargetVersion[
            keccak256(abi.encode(recognisedStateId, challengerAccount, targetTransitionId))
        ];
        if (existingChallengeId != 0) revert AVADataTypes.InvalidState(existingChallengeId);
    }

    function _recordChallengeFilingCaps(
        uint256 recognisedStateId,
        uint256 targetTransitionId,
        bytes32 challengerSubjectId,
        address challengerAccount,
        uint256 challengeId
    ) internal {
        openChallengeIdBySubjectTarget[keccak256(abi.encode(recognisedStateId, challengerSubjectId))] = challengeId;
        challengeIdBySubjectTargetVersion[
            keccak256(abi.encode(recognisedStateId, challengerSubjectId, targetTransitionId))
        ] = challengeId;
        openChallengeIdByAccountTarget[keccak256(abi.encode(recognisedStateId, challengerAccount))] = challengeId;
        challengeIdByAccountTargetVersion[
            keccak256(abi.encode(recognisedStateId, challengerAccount, targetTransitionId))
        ] = challengeId;
    }

    function _releaseOpenChallengeCaps(AVADataTypes.ChallengeRecord storage challenge, uint256 challengeId) internal {
        bytes32 subjectKey = keccak256(abi.encode(challenge.challengedRecognisedStateId, challenge.challengerSubjectId));
        bytes32 accountKey = keccak256(abi.encode(challenge.challengedRecognisedStateId, challenge.filedBy));
        if (
            openChallengeIdBySubjectTarget[subjectKey] != challengeId
                || openChallengeIdByAccountTarget[accountKey] != challengeId
        ) {
            revert AVADataTypes.InvalidState(challengeId);
        }
        delete openChallengeIdBySubjectTarget[subjectKey];
        delete openChallengeIdByAccountTarget[accountKey];
    }

    function _supportsChallengeRateLimit(address module) internal view returns (bool) {
        (bool success, bytes memory result) =
            module.staticcall(abi.encodeWithSelector(IChallengeRateLimitModule.supportsChallengeRateLimit.selector));
        if (!success || result.length != 32) return false;
        return abi.decode(result, (bool));
    }

    function _handleRequiredModuleResult(bool success, bytes memory result) internal pure {
        if (success) return;
        if (result.length == 0) revert AVADataTypes.InvalidState(0);
        assembly ("memory-safe") {
            revert(add(result, 32), mload(result))
        }
    }

    function _isResolutionOutcome(AVADataTypes.ChallengeOutcome outcome) internal pure returns (bool) {
        return outcome == AVADataTypes.ChallengeOutcome.Upheld
            || outcome == AVADataTypes.ChallengeOutcome.RejectedGoodFaith
            || outcome == AVADataTypes.ChallengeOutcome.Negligent
            || outcome == AVADataTypes.ChallengeOutcome.MaliciousOrFabricated;
    }

    function _requireNoDecisionConflict(
        address actor,
        bytes32 authorityId,
        AVADataTypes.ChallengeRecord storage challenge,
        AVADataTypes.RecognisedStateRecord memory challengedState,
        AVADataTypes.Action action
    ) internal view {
        address challengerAccount = AUTHORITY_MATRIX.roleRegistry().getSubject(challenge.challengerSubjectId).account;
        address targetAccount = AUTHORITY_MATRIX.roleRegistry().getSubject(challengedState.subjectId).account;
        if (
            actor == challenge.filedBy || actor == challengerAccount || actor == targetAccount
                || authorityId == challenge.challengerSubjectId || authorityId == challengedState.subjectId
        ) {
            revert AVADataTypes.NotAuthorised(actor, action);
        }
    }

    function _requireRestorationLineage(
        AVADataTypes.ChallengeRecord storage challenge,
        AVADataTypes.ChallengeTransitionRecord storage resolutionTransition,
        AVADataTypes.RecognisedStateRecord memory state
    ) internal view {
        if (challenge.outcome == AVADataTypes.ChallengeOutcome.Upheld) {
            AVADataTypes.RecognisedStateTransitionRecord memory correctionTransition =
                STATE_MACHINE.getRecognisedStateTransition(resolutionTransition.targetTransitionIdAfter);
            if (
                resolutionTransition.targetTransitionIdBefore != challenge.targetTransitionIdAtFiling
                    || correctionTransition.challengeId != challenge.id
                    || correctionTransition.action != AVADataTypes.Action.ResolveChallenge
                    || correctionTransition.toStatus != state.status
            ) {
                revert AVADataTypes.InvalidState(challenge.id);
            }
            return;
        }
        if (
            challenge.outcome == AVADataTypes.ChallengeOutcome.RejectedGoodFaith
                || challenge.outcome == AVADataTypes.ChallengeOutcome.MaliciousOrFabricated
        ) {
            if (
                resolutionTransition.targetTransitionIdBefore != challenge.targetTransitionIdAtFiling
                    || resolutionTransition.targetTransitionIdAfter != challenge.targetTransitionIdAtFiling
                    || state.status != challenge.targetStatusAtFiling
            ) {
                revert AVADataTypes.InvalidState(challenge.id);
            }
        }
    }
}
