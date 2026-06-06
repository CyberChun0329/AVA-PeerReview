// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "./AVADataTypes.sol";
import {AuthorityMatrix} from "./AuthorityMatrix.sol";
import {AVARulePackageRegistry} from "./AVARulePackageRegistry.sol";
import {EvidenceCommitmentRegistry} from "./EvidenceCommitmentRegistry.sol";
import {IDisclosurePolicyModule} from "./interfaces/IDisclosurePolicyModule.sol";
import {IChallengeLifecycleModule} from "./interfaces/IChallengeLifecycleModule.sol";
import {IResidualEditorialAuthorityModule} from "./interfaces/IResidualEditorialAuthorityModule.sol";

contract AVAStateMachine {
    struct ModuleValidationContext {
        bytes32 workflowKey;
        AVADataTypes.Role actingRole;
        AVADataTypes.Action action;
        AVADataTypes.AVAStage stage;
        bytes32 objectId;
        bytes32 subjectId;
        uint256 evidenceReceiptId;
        uint256 disclosurePolicyId;
    }

    struct ModuleValidationResult {
        bytes32 attributedObjectId;
        uint256 packageId;
    }

    AuthorityMatrix public immutable authorityMatrix;
    IDisclosurePolicyModule public immutable disclosurePolicyModule;
    AVARulePackageRegistry public immutable rulePackageRegistry;
    EvidenceCommitmentRegistry public immutable evidenceRegistry;
    bytes32 public immutable defaultWorkflowKey;
    uint256 public nextManuscriptId = 1;
    uint256 public nextRecognisedStateId = 1;
    uint256 public nextReviewContributionId = 1;
    uint256 public nextChallengeId = 1;
    uint256 public nextChallengeTransitionId = 1;
    uint256 public nextRecognisedStateTransitionId = 1;

    mapping(uint256 => AVADataTypes.ManuscriptRecord) private manuscripts;
    mapping(uint256 => AVADataTypes.RecognisedStateRecord) private recognisedStates;
    mapping(uint256 => AVADataTypes.ReviewContributionRecord) private reviewContributions;
    mapping(uint256 => AVADataTypes.ChallengeRecord) private challenges;
    mapping(uint256 => AVADataTypes.ChallengeTransitionRecord) private challengeTransitions;
    mapping(uint256 => AVADataTypes.RecognisedStateTransitionRecord) private recognisedStateTransitions;
    mapping(uint256 => uint256) private openChallengeCountsByRecognisedState;

    event ManuscriptRegistered(uint256 indexed id, bytes32 indexed offchainRef, string uri, address registeredBy);
    event RecognisedStateRegistered(
        uint256 indexed id,
        AVADataTypes.AVAStage indexed stage,
        bytes32 indexed objectId,
        uint256 evidenceReceiptId,
        uint256 disclosurePolicyId,
        bytes32 authorityId,
        AVADataTypes.RecognisedStateStatus status,
        address registeredBy
    );
    event ReviewContributionRegistered(
        uint256 indexed id,
        uint256 indexed manuscriptId,
        bytes32 indexed reviewerSubjectId,
        uint256 evidenceReceiptId,
        uint256 disclosurePolicyId,
        address registeredBy
    );
    event ReviewProvisionallyRecognised(uint256 indexed reviewContributionId, uint256 indexed recognisedStateId);
    event ReviewChallengeWindowOpened(uint256 indexed reviewContributionId, uint256 indexed recognisedStateId);
    event ReviewRecognitionVested(
        uint256 indexed reviewContributionId, uint256 indexed recognisedStateId, uint256 indexed transitionId
    );
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
    event RecognisedStateTransitionRecorded(
        uint256 indexed id,
        uint256 indexed recognisedStateId,
        AVADataTypes.RecognisedStateStatus fromStatus,
        AVADataTypes.RecognisedStateStatus toStatus,
        AVADataTypes.Action action
    );

    constructor(
        AuthorityMatrix authorityMatrix_,
        IDisclosurePolicyModule disclosurePolicyModule_,
        AVARulePackageRegistry rulePackageRegistry_,
        EvidenceCommitmentRegistry evidenceRegistry_,
        bytes32 defaultWorkflowKey_
    ) {
        if (defaultWorkflowKey_ == bytes32(0)) revert AVADataTypes.EmptyValue();
        authorityMatrix = authorityMatrix_;
        disclosurePolicyModule = disclosurePolicyModule_;
        rulePackageRegistry = rulePackageRegistry_;
        evidenceRegistry = evidenceRegistry_;
        defaultWorkflowKey = defaultWorkflowKey_;
    }

    function registerManuscript(AVADataTypes.Role actingRole, bytes32 offchainRef, string calldata uri)
        external
        returns (uint256 id)
    {
        bytes32 registeredSubjectId = authorityMatrix.requireAuthorisedCanonicalSubject(
            msg.sender, actingRole, AVADataTypes.Action.RegisterManuscript
        );
        return _registerManuscript(actingRole, registeredSubjectId, offchainRef, uri);
    }

    function registerManuscript(
        AVADataTypes.Role actingRole,
        bytes32 workflowKey,
        bytes32 offchainRef,
        string calldata uri,
        string calldata externalReferenceURI
    ) public returns (uint256 id) {
        bytes32 registeredSubjectId = authorityMatrix.requireAuthorisedCanonicalSubject(
            msg.sender, actingRole, AVADataTypes.Action.RegisterManuscript
        );
        if (offchainRef == bytes32(0)) revert AVADataTypes.EmptyValue();
        if (workflowKey != bytes32(0)) {
            AVARulePackageRegistry.RulePackage memory rulePackage = rulePackageRegistry.getRulePackage(workflowKey);
            if (bytes(externalReferenceURI).length != 0) {
                rulePackage.editorialSystemAdapter.validateEditorialReference(
                    workflowKey,
                    actingRole,
                    AVADataTypes.Action.RegisterManuscript,
                    offchainRef,
                    externalReferenceURI,
                    msg.sender
                );
            }
        }
        return _registerManuscript(actingRole, registeredSubjectId, offchainRef, uri);
    }

    function _registerManuscript(
        AVADataTypes.Role registeredRole,
        bytes32 registeredSubjectId,
        bytes32 offchainRef,
        string calldata uri
    ) internal returns (uint256 id) {
        if (offchainRef == bytes32(0)) revert AVADataTypes.EmptyValue();
        id = nextManuscriptId++;
        manuscripts[id] = AVADataTypes.ManuscriptRecord({
            id: id,
            offchainRef: offchainRef,
            uri: uri,
            registeredRole: registeredRole,
            registeredSubjectId: registeredSubjectId,
            registeredBy: msg.sender
        });

        emit ManuscriptRegistered(id, offchainRef, uri, msg.sender);
    }

    function registerRecognisedState(
        AVADataTypes.Role actingRole,
        AVADataTypes.AVAStage stage,
        bytes32 objectId,
        uint256 evidenceReceiptId,
        uint256 disclosurePolicyId,
        bytes32 authorityId,
        AVADataTypes.RecognisedStateStatus status
    ) external returns (uint256 id) {
        return registerRecognisedState(
            actingRole, defaultWorkflowKey, stage, objectId, authorityId, evidenceReceiptId, disclosurePolicyId, authorityId, status
        );
    }

    function registerRecognisedState(
        AVADataTypes.Role actingRole,
        bytes32 workflowKey,
        AVADataTypes.AVAStage stage,
        bytes32 objectId,
        bytes32 subjectId,
        uint256 evidenceReceiptId,
        uint256 disclosurePolicyId,
        bytes32 authorityId,
        AVADataTypes.RecognisedStateStatus status
    ) public returns (uint256 id) {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.RegisterRecognisedState, authorityId
        );
        if (objectId == bytes32(0) || subjectId == bytes32(0) || evidenceReceiptId == 0 || authorityId == bytes32(0)) {
            revert AVADataTypes.EmptyValue();
        }
        if (status == AVADataTypes.RecognisedStateStatus.None) revert AVADataTypes.EmptyValue();
        authorityMatrix.requireKnownActiveSubject(subjectId);
        _requireExternallyRegistrableStatus(status);
        ModuleValidationResult memory validation = _validateRecognisedStateModules(
            ModuleValidationContext({
                workflowKey: workflowKey,
                actingRole: actingRole,
                action: AVADataTypes.Action.RegisterRecognisedState,
                stage: stage,
                objectId: objectId,
                subjectId: subjectId,
                evidenceReceiptId: evidenceReceiptId,
                disclosurePolicyId: disclosurePolicyId
            })
        );

        id = _storeRecognisedState(
            actingRole,
            workflowKey,
            validation.packageId,
            stage,
            validation.attributedObjectId,
            evidenceReceiptId,
            disclosurePolicyId,
            authorityId,
            status,
            AVADataTypes.Action.RegisterRecognisedState
        );
        _validateResidualEditorialAuthority(
            workflowKey,
            validation.packageId,
            actingRole,
            AVADataTypes.Action.RegisterRecognisedState,
            id,
            validation.attributedObjectId,
            evidenceReceiptId,
            authorityId
        );
    }

    function registerReviewContribution(
        AVADataTypes.Role actingRole,
        uint256 manuscriptId,
        bytes32 reviewerSubjectId,
        uint256 evidenceReceiptId,
        uint256 disclosurePolicyId
    ) external returns (uint256 id) {
        return registerReviewContribution(
            actingRole, defaultWorkflowKey, manuscriptId, reviewerSubjectId, evidenceReceiptId, disclosurePolicyId
        );
    }

    function registerReviewContribution(
        AVADataTypes.Role actingRole,
        bytes32 workflowKey,
        uint256 manuscriptId,
        bytes32 reviewerSubjectId,
        uint256 evidenceReceiptId,
        uint256 disclosurePolicyId
    ) public returns (uint256 id) {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.RegisterReviewContribution, reviewerSubjectId
        );
        if (manuscriptId == 0 || reviewerSubjectId == bytes32(0) || evidenceReceiptId == 0) {
            revert AVADataTypes.EmptyValue();
        }
        if (manuscripts[manuscriptId].id == 0) revert AVADataTypes.UnknownReference(manuscriptId);
        ModuleValidationResult memory validation = _validateRecognisedStateModules(
            ModuleValidationContext({
                workflowKey: workflowKey,
                actingRole: actingRole,
                action: AVADataTypes.Action.RegisterReviewContribution,
                stage: AVADataTypes.AVAStage.Attribution,
                objectId: bytes32(manuscriptId),
                subjectId: reviewerSubjectId,
                evidenceReceiptId: evidenceReceiptId,
                disclosurePolicyId: disclosurePolicyId
            })
        );

        id = nextReviewContributionId++;
        reviewContributions[id] = AVADataTypes.ReviewContributionRecord({
            id: id,
            workflowKey: workflowKey,
            packageId: validation.packageId,
            manuscriptId: manuscriptId,
            reviewerSubjectId: reviewerSubjectId,
            evidenceReceiptId: evidenceReceiptId,
            disclosurePolicyId: disclosurePolicyId,
            recognisedStateId: 0,
            status: AVADataTypes.ReviewContributionStatus.Submitted,
            registeredBy: msg.sender
        });

        emit ReviewContributionRegistered(
            id, manuscriptId, reviewerSubjectId, evidenceReceiptId, disclosurePolicyId, msg.sender
        );
    }

    function provisionallyRecogniseReview(
        AVADataTypes.Role actingRole,
        uint256 reviewContributionId,
        bytes32 authorityId
    ) external returns (uint256 recognisedStateId) {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.ProvisionallyRecogniseReview, authorityId
        );
        AVADataTypes.ReviewContributionRecord storage reviewContribution = reviewContributions[reviewContributionId];
        if (reviewContribution.id == 0) revert AVADataTypes.UnknownReference(reviewContributionId);
        if (reviewContribution.status != AVADataTypes.ReviewContributionStatus.Submitted) {
            revert AVADataTypes.InvalidState(reviewContributionId);
        }
        if (authorityId == bytes32(0)) revert AVADataTypes.EmptyValue();

        recognisedStateId = _registerRecognisedState(
            actingRole,
            reviewContribution.workflowKey,
            reviewContribution.packageId,
            AVADataTypes.AVAStage.Verification,
            bytes32(reviewContributionId),
            reviewContribution.reviewerSubjectId,
            reviewContribution.evidenceReceiptId,
            reviewContribution.disclosurePolicyId,
            authorityId,
            AVADataTypes.RecognisedStateStatus.Provisional
        );
        _validateResidualEditorialAuthority(
            reviewContribution.workflowKey,
            reviewContribution.packageId,
            actingRole,
            AVADataTypes.Action.ProvisionallyRecogniseReview,
            recognisedStateId,
            bytes32(reviewContributionId),
            reviewContribution.evidenceReceiptId,
            authorityId
        );
        reviewContribution.recognisedStateId = recognisedStateId;
        reviewContribution.status = AVADataTypes.ReviewContributionStatus.ProvisionalRecognised;

        emit ReviewProvisionallyRecognised(reviewContributionId, recognisedStateId);
    }

    function openReviewChallengeWindow(
        AVADataTypes.Role actingRole,
        uint256 reviewContributionId,
        bytes32 authorityId
    ) external {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.OpenChallengeWindow, authorityId
        );
        AVADataTypes.ReviewContributionRecord storage reviewContribution = reviewContributions[reviewContributionId];
        if (reviewContribution.id == 0) revert AVADataTypes.UnknownReference(reviewContributionId);
        if (reviewContribution.status != AVADataTypes.ReviewContributionStatus.ProvisionalRecognised) {
            revert AVADataTypes.InvalidState(reviewContributionId);
        }
        if (authorityId == bytes32(0)) revert AVADataTypes.EmptyValue();

        uint256 recognisedStateId = reviewContribution.recognisedStateId;
        _validateTransitionRule(
            reviewContribution.workflowKey,
            reviewContribution.packageId,
            AVADataTypes.Action.OpenChallengeWindow,
            recognisedStates[recognisedStateId].status,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            AVADataTypes.ChallengeOutcome.None
        );
        _validateDisclosureForAction(
            reviewContribution.workflowKey,
            reviewContribution.packageId,
            reviewContribution.disclosurePolicyId,
            actingRole,
            AVADataTypes.Action.OpenChallengeWindow,
            AVADataTypes.AVAStage.Verification,
            bytes32(reviewContributionId),
            reviewContribution.reviewerSubjectId
        );
        _validateResidualEditorialAuthority(
            reviewContribution.workflowKey,
            reviewContribution.packageId,
            actingRole,
            AVADataTypes.Action.OpenChallengeWindow,
            recognisedStateId,
            bytes32(reviewContributionId),
            reviewContribution.evidenceReceiptId,
            authorityId
        );
        _recordRecognisedStateTransition(
            recognisedStateId,
            reviewContribution.packageId,
            recognisedStates[recognisedStateId].status,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            AVADataTypes.Action.OpenChallengeWindow,
            0,
            reviewContribution.evidenceReceiptId,
            actingRole,
            authorityId,
            ""
        );
        recognisedStates[recognisedStateId].status = AVADataTypes.RecognisedStateStatus.Challengeable;
        reviewContribution.status = AVADataTypes.ReviewContributionStatus.ChallengeWindowOpen;

        emit ReviewChallengeWindowOpened(reviewContributionId, recognisedStateId);
    }

    function vestReviewRecognition(
        AVADataTypes.Role actingRole,
        uint256 reviewContributionId,
        bytes32 authorityId,
        string calldata reasonURI
    ) external returns (uint256 transitionId) {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.TransitionRecognisedState, authorityId
        );
        AVADataTypes.ReviewContributionRecord storage reviewContribution = reviewContributions[reviewContributionId];
        if (reviewContribution.id == 0) revert AVADataTypes.UnknownReference(reviewContributionId);
        if (reviewContribution.status != AVADataTypes.ReviewContributionStatus.ChallengeWindowOpen) {
            revert AVADataTypes.InvalidState(reviewContributionId);
        }
        if (authorityId == bytes32(0)) revert AVADataTypes.EmptyValue();

        AVADataTypes.RecognisedStateStatus fromStatus = recognisedStates[reviewContribution.recognisedStateId].status;
        if (fromStatus != AVADataTypes.RecognisedStateStatus.Challengeable) {
            revert AVADataTypes.InvalidState(reviewContribution.recognisedStateId);
        }
        if (openChallengeCountsByRecognisedState[reviewContribution.recognisedStateId] != 0) {
            revert AVADataTypes.InvalidState(reviewContribution.recognisedStateId);
        }
        _validateTransitionRule(
            reviewContribution.workflowKey,
            reviewContribution.packageId,
            AVADataTypes.Action.TransitionRecognisedState,
            fromStatus,
            AVADataTypes.RecognisedStateStatus.Vested,
            AVADataTypes.ChallengeOutcome.None
        );
        _validateDisclosureForAction(
            reviewContribution.workflowKey,
            reviewContribution.packageId,
            reviewContribution.disclosurePolicyId,
            actingRole,
            AVADataTypes.Action.TransitionRecognisedState,
            AVADataTypes.AVAStage.Verification,
            bytes32(reviewContributionId),
            reviewContribution.reviewerSubjectId
        );
        _validateResidualEditorialAuthority(
            reviewContribution.workflowKey,
            reviewContribution.packageId,
            actingRole,
            AVADataTypes.Action.TransitionRecognisedState,
            reviewContribution.recognisedStateId,
            bytes32(reviewContributionId),
            reviewContribution.evidenceReceiptId,
            authorityId
        );
        transitionId =
            _recordReviewVestingTransition(reviewContribution, fromStatus, actingRole, authorityId, reasonURI);
        recognisedStates[reviewContribution.recognisedStateId].status = AVADataTypes.RecognisedStateStatus.Vested;
        reviewContribution.status = AVADataTypes.ReviewContributionStatus.Vested;

        emit ReviewRecognitionVested(reviewContributionId, reviewContribution.recognisedStateId, transitionId);
    }

    // Challenge handling is part of the substrate and remains limited to
    // authorised transitions over recognised states. It does not execute
    // sanctions, rewards, standing updates, allocation, or disclosure reveal.
    function fileChallenge(
        AVADataTypes.Role actingRole,
        uint256 challengedRecognisedStateId,
        bytes32 challengerSubjectId,
        uint256 evidenceReceiptId,
        uint256 disclosurePolicyId
    ) external returns (uint256 id) {
        return fileChallenge(
            actingRole, defaultWorkflowKey, challengedRecognisedStateId, challengerSubjectId, evidenceReceiptId, disclosurePolicyId
        );
    }

    function fileChallenge(
        AVADataTypes.Role actingRole,
        bytes32 workflowKey,
        uint256 challengedRecognisedStateId,
        bytes32 challengerSubjectId,
        uint256 evidenceReceiptId,
        uint256 disclosurePolicyId
    ) public returns (uint256 id) {
        authorityMatrix.requireAuthorisedSubject(msg.sender, actingRole, AVADataTypes.Action.FileChallenge, challengerSubjectId);
        AVADataTypes.RecognisedStateRecord memory challengedState = recognisedStates[challengedRecognisedStateId];
        if (challengedState.id == 0) revert AVADataTypes.UnknownReference(challengedRecognisedStateId);
        if (workflowKey != challengedState.workflowKey) revert AVADataTypes.InvalidState(challengedRecognisedStateId);
        if (challengedState.status != AVADataTypes.RecognisedStateStatus.Challengeable) {
            revert AVADataTypes.InvalidState(challengedRecognisedStateId);
        }
        if (challengerSubjectId == bytes32(0) || evidenceReceiptId == 0) revert AVADataTypes.EmptyValue();
        ModuleValidationResult memory validation = _validateRecognisedStateModulesWithPackage(
            ModuleValidationContext({
                workflowKey: workflowKey,
                actingRole: actingRole,
                action: AVADataTypes.Action.FileChallenge,
                stage: AVADataTypes.AVAStage.Verification,
                objectId: bytes32(challengedRecognisedStateId),
                subjectId: challengerSubjectId,
                evidenceReceiptId: evidenceReceiptId,
                disclosurePolicyId: disclosurePolicyId
            }),
            challengedState.packageId
        );
        _validateChallengeLifecycle(
            validation.packageId,
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

        id = nextChallengeId++;
        challenges[id] = AVADataTypes.ChallengeRecord({
            id: id,
            workflowKey: workflowKey,
            packageId: validation.packageId,
            challengedRecognisedStateId: challengedRecognisedStateId,
            challengerSubjectId: challengerSubjectId,
            evidenceReceiptId: evidenceReceiptId,
            disclosurePolicyId: disclosurePolicyId,
            status: AVADataTypes.ChallengeLifecycleStatus.ConcernFiled,
            outcome: AVADataTypes.ChallengeOutcome.None,
            lastTransitionId: 0,
            filedBy: msg.sender
        });
        openChallengeCountsByRecognisedState[challengedRecognisedStateId] += 1;

        emit ChallengeFiled(
            id, challengedRecognisedStateId, challengerSubjectId, evidenceReceiptId, disclosurePolicyId, msg.sender
        );
    }

    function screenChallenge(AVADataTypes.Role actingRole, uint256 challengeId, bytes32 authorityId) external {
        authorityMatrix.requireAuthorisedSubject(msg.sender, actingRole, AVADataTypes.Action.ScreenChallenge, authorityId);
        AVADataTypes.ChallengeRecord storage challenge = challenges[challengeId];
        if (challenge.id == 0) revert AVADataTypes.UnknownReference(challengeId);
        if (challenge.status != AVADataTypes.ChallengeLifecycleStatus.ConcernFiled) {
            revert AVADataTypes.InvalidState(challengeId);
        }
        if (authorityId == bytes32(0)) revert AVADataTypes.EmptyValue();

        AVADataTypes.RecognisedStateStatus currentStatus = recognisedStates[challenge.challengedRecognisedStateId].status;
        _validateTransitionRule(
            challenge.workflowKey,
            challenge.packageId,
            AVADataTypes.Action.ScreenChallenge,
            currentStatus,
            currentStatus,
            AVADataTypes.ChallengeOutcome.None
        );
        _validateDisclosureForAction(
            challenge.workflowKey,
            challenge.packageId,
            challenge.disclosurePolicyId,
            actingRole,
            AVADataTypes.Action.ScreenChallenge,
            AVADataTypes.AVAStage.Verification,
            bytes32(challenge.challengedRecognisedStateId),
            challenge.challengerSubjectId
        );
        _validateChallengeLifecycle(
            challenge.packageId,
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
        _validateResidualEditorialAuthority(
            challenge.workflowKey,
            challenge.packageId,
            actingRole,
            AVADataTypes.Action.ScreenChallenge,
            challenge.challengedRecognisedStateId,
            bytes32(challenge.challengedRecognisedStateId),
            challenge.evidenceReceiptId,
            authorityId
        );
        challenge.status = AVADataTypes.ChallengeLifecycleStatus.AdmissibilityScreening;
        challenge.lastTransitionId = _recordChallengeTransition(
            challenge,
            AVADataTypes.ChallengeTransitionKind.AdmissibilityScreened,
            AVADataTypes.ChallengeOutcome.None,
            currentStatus,
            currentStatus,
            actingRole,
            authorityId,
            ""
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
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.ResolveChallenge, authorityId
        );
        AVADataTypes.ChallengeRecord storage challenge = challenges[challengeId];
        if (challenge.id == 0) revert AVADataTypes.UnknownReference(challengeId);
        if (challenge.status != AVADataTypes.ChallengeLifecycleStatus.AdmissibilityScreening) {
            revert AVADataTypes.InvalidState(challengeId);
        }
        if (msg.sender == challenge.filedBy) {
            revert AVADataTypes.NotAuthorised(msg.sender, AVADataTypes.Action.ResolveChallenge);
        }
        if (
            outcome != AVADataTypes.ChallengeOutcome.Upheld
                && outcome != AVADataTypes.ChallengeOutcome.RejectedGoodFaith
                && outcome != AVADataTypes.ChallengeOutcome.Negligent
                && outcome != AVADataTypes.ChallengeOutcome.MaliciousOrFabricated
        ) {
            revert AVADataTypes.InvalidState(challengeId);
        }

        _validateResidualEditorialAuthority(
            challenge.workflowKey,
            challenge.packageId,
            actingRole,
            AVADataTypes.Action.ResolveChallenge,
            challenge.challengedRecognisedStateId,
            bytes32(challenge.challengedRecognisedStateId),
            challenge.evidenceReceiptId,
            authorityId
        );
        uint256 transitionId = _recordResolutionTransitionAndMutateIfNeeded(
            challenge, outcome, toStatus, actingRole, authorityId, reasonURI
        );
        challenge.status = AVADataTypes.ChallengeLifecycleStatus.Resolved;
        challenge.outcome = outcome;
        challenge.lastTransitionId = transitionId;

        emit ChallengeResolved(challengeId, outcome, transitionId);
    }

    function applyRestoration(
        AVADataTypes.Role actingRole,
        uint256 challengeId,
        bytes32 authorityId,
        string calldata reasonURI
    ) external {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.ApplyRestoration, authorityId
        );
        AVADataTypes.ChallengeRecord storage challenge = challenges[challengeId];
        if (challenge.id == 0) revert AVADataTypes.UnknownReference(challengeId);
        if (challenge.status != AVADataTypes.ChallengeLifecycleStatus.Resolved) {
            revert AVADataTypes.InvalidState(challengeId);
        }

        AVADataTypes.RecognisedStateRecord storage challengedState =
            recognisedStates[challenge.challengedRecognisedStateId];
        if (!_canApplyRestoration(challenge.outcome, challengedState.status)) {
            revert AVADataTypes.InvalidState(challengeId);
        }
        _validateTransitionRule(
            challenge.workflowKey,
            challenge.packageId,
            AVADataTypes.Action.ApplyRestoration,
            challengedState.status,
            AVADataTypes.RecognisedStateStatus.Restored,
            challenge.outcome
        );
        _validateDisclosureForAction(
            challenge.workflowKey,
            challenge.packageId,
            challenge.disclosurePolicyId,
            actingRole,
            AVADataTypes.Action.ApplyRestoration,
            AVADataTypes.AVAStage.Verification,
            bytes32(challenge.challengedRecognisedStateId),
            challenge.challengerSubjectId
        );
        _validateChallengeLifecycle(
            challenge.packageId,
            IChallengeLifecycleModule.ChallengeLifecycleContext({
                workflowKey: challenge.workflowKey,
                action: AVADataTypes.Action.ApplyRestoration,
                fromLifecycleStatus: challenge.status,
                toLifecycleStatus: AVADataTypes.ChallengeLifecycleStatus.RestorationAvailable,
                outcome: challenge.outcome,
                challengedStateStatus: challengedState.status,
                proposedStateStatus: AVADataTypes.RecognisedStateStatus.Restored,
                actor: msg.sender,
                filedBy: challenge.filedBy
            })
        );
        _validateResidualEditorialAuthority(
            challenge.workflowKey,
            challenge.packageId,
            actingRole,
            AVADataTypes.Action.ApplyRestoration,
            challenge.challengedRecognisedStateId,
            bytes32(challenge.challengedRecognisedStateId),
            challenge.evidenceReceiptId,
            authorityId
        );
        uint256 transitionId = _recordChallengeTransition(
            challenge,
            AVADataTypes.ChallengeTransitionKind.RestorationRecorded,
            challenge.outcome,
            challengedState.status,
            AVADataTypes.RecognisedStateStatus.Restored,
            actingRole,
            authorityId,
            reasonURI
        );
        _recordRecognisedStateTransition(
            challenge.challengedRecognisedStateId,
            challenge.packageId,
            challengedState.status,
            AVADataTypes.RecognisedStateStatus.Restored,
            AVADataTypes.Action.ApplyRestoration,
            challenge.id,
            challenge.evidenceReceiptId,
            actingRole,
            authorityId,
            reasonURI
        );
        challengedState.status = AVADataTypes.RecognisedStateStatus.Restored;
        challenge.status = AVADataTypes.ChallengeLifecycleStatus.RestorationAvailable;
        challenge.lastTransitionId = transitionId;

        emit RestorationApplied(challengeId, challenge.challengedRecognisedStateId, transitionId);
    }

    function closeChallenge(
        AVADataTypes.Role actingRole,
        uint256 challengeId,
        bytes32 authorityId,
        string calldata reasonURI
    ) external {
        authorityMatrix.requireAuthorisedSubject(msg.sender, actingRole, AVADataTypes.Action.CloseChallenge, authorityId);
        AVADataTypes.ChallengeRecord storage challenge = challenges[challengeId];
        if (challenge.id == 0) revert AVADataTypes.UnknownReference(challengeId);
        if (
            challenge.status != AVADataTypes.ChallengeLifecycleStatus.Resolved
                && challenge.status != AVADataTypes.ChallengeLifecycleStatus.RestorationAvailable
        ) {
            revert AVADataTypes.InvalidState(challengeId);
        }

        AVADataTypes.RecognisedStateStatus currentStatus =
        recognisedStates[challenge.challengedRecognisedStateId].status;
        _validateTransitionRule(
            challenge.workflowKey,
            challenge.packageId,
            AVADataTypes.Action.CloseChallenge,
            currentStatus,
            currentStatus,
            challenge.outcome
        );
        _validateDisclosureForAction(
            challenge.workflowKey,
            challenge.packageId,
            challenge.disclosurePolicyId,
            actingRole,
            AVADataTypes.Action.CloseChallenge,
            AVADataTypes.AVAStage.Verification,
            bytes32(challenge.challengedRecognisedStateId),
            challenge.challengerSubjectId
        );
        _validateChallengeLifecycle(
            challenge.packageId,
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
        _validateResidualEditorialAuthority(
            challenge.workflowKey,
            challenge.packageId,
            actingRole,
            AVADataTypes.Action.CloseChallenge,
            challenge.challengedRecognisedStateId,
            bytes32(challenge.challengedRecognisedStateId),
            challenge.evidenceReceiptId,
            authorityId
        );
        uint256 transitionId = _recordChallengeTransition(
            challenge,
            AVADataTypes.ChallengeTransitionKind.Closed,
            challenge.outcome,
            currentStatus,
            currentStatus,
            actingRole,
            authorityId,
            reasonURI
        );
        uint256 openChallengeCount = openChallengeCountsByRecognisedState[challenge.challengedRecognisedStateId];
        if (openChallengeCount == 0) revert AVADataTypes.InvalidState(challenge.challengedRecognisedStateId);
        openChallengeCountsByRecognisedState[challenge.challengedRecognisedStateId] = openChallengeCount - 1;
        challenge.status = AVADataTypes.ChallengeLifecycleStatus.Closed;
        challenge.lastTransitionId = transitionId;

        emit ChallengeClosed(challengeId, transitionId);
    }

    function getManuscript(uint256 id) external view returns (AVADataTypes.ManuscriptRecord memory) {
        AVADataTypes.ManuscriptRecord memory manuscript = manuscripts[id];
        if (manuscript.id == 0) revert AVADataTypes.UnknownReference(id);
        return manuscript;
    }

    function getRecognisedState(uint256 id) external view returns (AVADataTypes.RecognisedStateRecord memory) {
        AVADataTypes.RecognisedStateRecord memory state = recognisedStates[id];
        if (state.id == 0) revert AVADataTypes.UnknownReference(id);
        return state;
    }

    function getReviewContribution(uint256 id) external view returns (AVADataTypes.ReviewContributionRecord memory) {
        AVADataTypes.ReviewContributionRecord memory reviewContribution = reviewContributions[id];
        if (reviewContribution.id == 0) revert AVADataTypes.UnknownReference(id);
        return reviewContribution;
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

    function getRecognisedStateTransition(uint256 id)
        external
        view
        returns (AVADataTypes.RecognisedStateTransitionRecord memory)
    {
        AVADataTypes.RecognisedStateTransitionRecord memory transition = recognisedStateTransitions[id];
        if (transition.id == 0) revert AVADataTypes.UnknownReference(id);
        return transition;
    }

    function openChallengeCountForRecognisedState(uint256 recognisedStateId) external view returns (uint256) {
        if (recognisedStates[recognisedStateId].id == 0) revert AVADataTypes.UnknownReference(recognisedStateId);
        return openChallengeCountsByRecognisedState[recognisedStateId];
    }

    function transitionRecognisedState(
        AVADataTypes.Role actingRole,
        uint256 recognisedStateId,
        AVADataTypes.RecognisedStateStatus toStatus,
        bytes32 authorityId,
        string calldata reasonURI
    ) external returns (uint256 transitionId) {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.TransitionRecognisedState, authorityId
        );
        AVADataTypes.RecognisedStateRecord storage recognisedState = recognisedStates[recognisedStateId];
        if (recognisedState.id == 0) revert AVADataTypes.UnknownReference(recognisedStateId);
        if (toStatus == AVADataTypes.RecognisedStateStatus.None) revert AVADataTypes.EmptyValue();
        AVADataTypes.RecognisedStateStatus fromStatus = recognisedState.status;
        _requireGenericTransitionStatus(fromStatus, toStatus);
        _validateTransitionRule(
            recognisedState.workflowKey,
            recognisedState.packageId,
            AVADataTypes.Action.TransitionRecognisedState,
            fromStatus,
            toStatus,
            AVADataTypes.ChallengeOutcome.None
        );
        _validateResidualEditorialAuthority(
            recognisedState.workflowKey,
            recognisedState.packageId,
            actingRole,
            AVADataTypes.Action.TransitionRecognisedState,
            recognisedStateId,
            recognisedState.objectId,
            recognisedState.evidenceReceiptId,
            authorityId
        );
        transitionId = nextRecognisedStateTransitionId++;
        AVADataTypes.RecognisedStateTransitionRecord storage transition =
            recognisedStateTransitions[transitionId];
        transition.id = transitionId;
        transition.recognisedStateId = recognisedStateId;
        transition.packageId = recognisedState.packageId;
        transition.fromStatus = fromStatus;
        transition.toStatus = toStatus;
        transition.action = AVADataTypes.Action.TransitionRecognisedState;
        transition.evidenceReceiptId = recognisedState.evidenceReceiptId;
        transition.authorityRole = actingRole;
        transition.authorityId = authorityId;
        transition.reasonURI = reasonURI;
        transition.createdBy = msg.sender;
        emit RecognisedStateTransitionRecorded(
            transitionId, recognisedStateId, fromStatus, toStatus, AVADataTypes.Action.TransitionRecognisedState
        );
        recognisedState.status = toStatus;
    }

    function _recordChallengeTransition(
        AVADataTypes.ChallengeRecord memory challenge,
        AVADataTypes.ChallengeTransitionKind transitionKind,
        AVADataTypes.ChallengeOutcome outcome,
        AVADataTypes.RecognisedStateStatus fromStatus,
        AVADataTypes.RecognisedStateStatus toStatus,
        AVADataTypes.Role authorityRole,
        bytes32 authorityId,
        string memory reasonURI
    ) internal returns (uint256 id) {
        id = nextChallengeTransitionId++;
        AVADataTypes.ChallengeTransitionRecord storage transition = challengeTransitions[id];
        transition.id = id;
        transition.workflowKey = challenge.workflowKey;
        transition.packageId = challenge.packageId;
        transition.challengeId = challenge.id;
        transition.challengedRecognisedStateId = challenge.challengedRecognisedStateId;
        transition.fromStatus = fromStatus;
        transition.toStatus = toStatus;
        transition.transitionKind = transitionKind;
        transition.outcome = outcome;
        transition.evidenceReceiptId = challenge.evidenceReceiptId;
        transition.authorityRole = authorityRole;
        transition.authorityId = authorityId;
        transition.reasonURI = reasonURI;
        transition.createdBy = msg.sender;

        emit ChallengeTransitionRecorded(
            id, challenge.id, challenge.challengedRecognisedStateId, transitionKind, outcome
        );
    }

    function _recordResolutionTransitionAndMutateIfNeeded(
        AVADataTypes.ChallengeRecord storage challenge,
        AVADataTypes.ChallengeOutcome outcome,
        AVADataTypes.RecognisedStateStatus toStatus,
        AVADataTypes.Role authorityRole,
        bytes32 authorityId,
        string calldata reasonURI
    ) internal returns (uint256 transitionId) {
        AVADataTypes.RecognisedStateRecord storage challengedState =
            recognisedStates[challenge.challengedRecognisedStateId];
        (AVADataTypes.RecognisedStateStatus fromStatus, bool mutatesState) =
            _validateResolution(challenge, outcome, toStatus, authorityRole);

        transitionId = _recordChallengeTransition(
            challenge,
            AVADataTypes.ChallengeTransitionKind.OutcomeResolved,
            outcome,
            fromStatus,
            toStatus,
            authorityRole,
            authorityId,
            reasonURI
        );

        if (mutatesState) {
            _recordResolutionRecognisedStateTransition(challenge, fromStatus, toStatus, authorityRole, authorityId, reasonURI);
            challengedState.status = toStatus;
        }
    }

    function _recordResolutionRecognisedStateTransition(
        AVADataTypes.ChallengeRecord storage challenge,
        AVADataTypes.RecognisedStateStatus fromStatus,
        AVADataTypes.RecognisedStateStatus toStatus,
        AVADataTypes.Role authorityRole,
        bytes32 authorityId,
        string calldata reasonURI
    ) internal {
        _recordRecognisedStateTransition(
            challenge.challengedRecognisedStateId,
            challenge.packageId,
            fromStatus,
            toStatus,
            AVADataTypes.Action.ResolveChallenge,
            challenge.id,
            challenge.evidenceReceiptId,
            authorityRole,
            authorityId,
            reasonURI
        );
    }

    function _recordReviewVestingTransition(
        AVADataTypes.ReviewContributionRecord storage reviewContribution,
        AVADataTypes.RecognisedStateStatus fromStatus,
        AVADataTypes.Role authorityRole,
        bytes32 authorityId,
        string calldata reasonURI
    ) internal returns (uint256 transitionId) {
        transitionId = _recordRecognisedStateTransition(
            reviewContribution.recognisedStateId,
            reviewContribution.packageId,
            fromStatus,
            AVADataTypes.RecognisedStateStatus.Vested,
            AVADataTypes.Action.TransitionRecognisedState,
            0,
            reviewContribution.evidenceReceiptId,
            authorityRole,
            authorityId,
            reasonURI
        );
    }

    function _canApplyRestoration(
        AVADataTypes.ChallengeOutcome outcome,
        AVADataTypes.RecognisedStateStatus status
    ) internal pure returns (bool) {
        if (
            outcome == AVADataTypes.ChallengeOutcome.RejectedGoodFaith
                || outcome == AVADataTypes.ChallengeOutcome.MaliciousOrFabricated
        ) {
            return true;
        }
        return outcome == AVADataTypes.ChallengeOutcome.Upheld
            && (
                status == AVADataTypes.RecognisedStateStatus.Downgraded
                    || status == AVADataTypes.RecognisedStateStatus.Voided
            );
    }

    function _validateResolution(
        AVADataTypes.ChallengeRecord storage challenge,
        AVADataTypes.ChallengeOutcome outcome,
        AVADataTypes.RecognisedStateStatus toStatus,
        AVADataTypes.Role authorityRole
    ) internal view returns (AVADataTypes.RecognisedStateStatus fromStatus, bool mutatesState) {
        fromStatus = recognisedStates[challenge.challengedRecognisedStateId].status;
        mutatesState = outcome == AVADataTypes.ChallengeOutcome.Upheld;

        if (mutatesState) {
            if (
                toStatus != AVADataTypes.RecognisedStateStatus.Downgraded
                    && toStatus != AVADataTypes.RecognisedStateStatus.Voided
            ) {
                revert AVADataTypes.InvalidState(challenge.id);
            }
        } else if (toStatus != fromStatus) {
            revert AVADataTypes.InvalidState(challenge.id);
        }

        _validateTransitionRule(
            challenge.workflowKey, challenge.packageId, AVADataTypes.Action.ResolveChallenge, fromStatus, toStatus, outcome
        );
        _validateDisclosureForAction(
            challenge.workflowKey,
            challenge.packageId,
            challenge.disclosurePolicyId,
            authorityRole,
            AVADataTypes.Action.ResolveChallenge,
            AVADataTypes.AVAStage.Verification,
            bytes32(challenge.challengedRecognisedStateId),
            challenge.challengerSubjectId
        );
        _validateChallengeLifecycle(
            challenge.packageId,
            IChallengeLifecycleModule.ChallengeLifecycleContext({
                workflowKey: challenge.workflowKey,
                action: AVADataTypes.Action.ResolveChallenge,
                fromLifecycleStatus: challenge.status,
                toLifecycleStatus: AVADataTypes.ChallengeLifecycleStatus.Resolved,
                outcome: outcome,
                challengedStateStatus: fromStatus,
                proposedStateStatus: toStatus,
                actor: msg.sender,
                filedBy: challenge.filedBy
            })
        );
    }

    function _registerRecognisedState(
        AVADataTypes.Role actingRole,
        bytes32 workflowKey,
        uint256 packageId,
        AVADataTypes.AVAStage stage,
        bytes32 objectId,
        bytes32 subjectId,
        uint256 evidenceReceiptId,
        uint256 disclosurePolicyId,
        bytes32 authorityId,
        AVADataTypes.RecognisedStateStatus status
    ) internal returns (uint256 id) {
        ModuleValidationResult memory validation = _validateRecognisedStateModulesWithPackage(
            ModuleValidationContext({
                workflowKey: workflowKey,
                actingRole: actingRole,
                action: AVADataTypes.Action.ProvisionallyRecogniseReview,
                stage: stage,
                objectId: objectId,
                subjectId: subjectId,
                evidenceReceiptId: evidenceReceiptId,
                disclosurePolicyId: disclosurePolicyId
            }),
            packageId
        );
        id = _storeRecognisedState(
            actingRole,
            workflowKey,
            validation.packageId,
            stage,
            validation.attributedObjectId,
            evidenceReceiptId,
            disclosurePolicyId,
            authorityId,
            status,
            AVADataTypes.Action.ProvisionallyRecogniseReview
        );
    }

    function _requireDisclosurePolicyIfSpecified(uint256 disclosurePolicyId) internal view {
        disclosurePolicyModule.validateDisclosurePolicy(disclosurePolicyId);
    }

    function _validateRecognisedStateModules(ModuleValidationContext memory context)
        internal
        view
        returns (ModuleValidationResult memory result)
    {
        AVARulePackageRegistry.RulePackage memory rulePackage = rulePackageRegistry.getRulePackage(context.workflowKey);
        return _validateRecognisedStateModules(context, rulePackage);
    }

    function _validateRecognisedStateModulesWithPackage(
        ModuleValidationContext memory context,
        uint256 packageId
    ) internal view returns (ModuleValidationResult memory result)
    {
        AVARulePackageRegistry.RulePackage memory rulePackage = rulePackageRegistry.getRulePackageById(packageId);
        if (rulePackage.workflowKey != context.workflowKey) revert AVADataTypes.InvalidState(packageId);
        return _validateRecognisedStateModules(context, rulePackage);
    }

    function _validateRecognisedStateModules(
        ModuleValidationContext memory context,
        AVARulePackageRegistry.RulePackage memory rulePackage
    ) internal view returns (ModuleValidationResult memory result)
    {
        bytes32 evidenceTypeHash;
        if (context.evidenceReceiptId != 0) {
            AVADataTypes.EvidenceReceipt memory receipt =
                evidenceRegistry.requireUsableEvidenceReceipt(context.evidenceReceiptId, context.workflowKey);
            if (receipt.packageId != rulePackage.packageId) revert AVADataTypes.InvalidState(context.evidenceReceiptId);
            evidenceTypeHash = receipt.evidenceTypeHash;
        }
        rulePackage.disclosureModule.validateDisclosureForAction(
            context.disclosurePolicyId,
            context.actingRole,
            context.action,
            context.stage,
            context.objectId,
            context.workflowKey,
            rulePackage.packageId,
            context.subjectId
        );
        result.attributedObjectId = rulePackage.attributionModule.validateAttribution(
            context.workflowKey,
            context.actingRole,
            context.stage,
            context.objectId,
            context.subjectId,
            context.evidenceReceiptId
        );
        rulePackage.verificationModule.validateVerification(
            context.workflowKey, context.actingRole, context.stage, result.attributedObjectId, context.evidenceReceiptId
        );
        rulePackage.evidencePolicyModule.validateEvidencePolicy(
            context.workflowKey,
            context.actingRole,
            context.action,
            context.evidenceReceiptId,
            evidenceTypeHash,
            msg.sender
        );
        rulePackage.evidenceLifecycleModule.validateEvidenceLifecycle(
            context.workflowKey,
            context.action,
            context.evidenceReceiptId,
            AVADataTypes.EvidenceLifecycleKind.None,
            0,
            bytes32(0),
            msg.sender
        );
        rulePackage.fieldPolicyModule.validateFieldPolicy(
            context.workflowKey,
            context.actingRole,
            context.action,
            context.stage,
            result.attributedObjectId,
            context.evidenceReceiptId
        );
        rulePackage.antiAbuseModule.validateUse(
            context.workflowKey, context.actingRole, context.action, context.subjectId, result.attributedObjectId, msg.sender
        );
        result.packageId = rulePackage.packageId;
    }

    function _validateDisclosureForAction(
        bytes32 workflowKey,
        uint256 packageId,
        uint256 disclosurePolicyId,
        AVADataTypes.Role actingRole,
        AVADataTypes.Action action,
        AVADataTypes.AVAStage stage,
        bytes32 objectId,
        bytes32 subjectCommitment
    ) internal view {
        AVARulePackageRegistry.RulePackage memory rulePackage = rulePackageRegistry.getRulePackageById(packageId);
        if (rulePackage.workflowKey != workflowKey) revert AVADataTypes.InvalidState(packageId);
        rulePackage.disclosureModule.validateDisclosureForAction(
            disclosurePolicyId, actingRole, action, stage, objectId, workflowKey, packageId, subjectCommitment
        );
    }

    function _validateTransitionRule(
        bytes32 workflowKey,
        uint256 packageId,
        AVADataTypes.Action action,
        AVADataTypes.RecognisedStateStatus fromStatus,
        AVADataTypes.RecognisedStateStatus toStatus,
        AVADataTypes.ChallengeOutcome outcome
    ) internal view {
        AVARulePackageRegistry.RulePackage memory rulePackage = rulePackageRegistry.getRulePackageById(packageId);
        if (rulePackage.workflowKey != workflowKey) revert AVADataTypes.InvalidState(packageId);
        rulePackage.transitionRuleModule.validateTransition(workflowKey, action, fromStatus, toStatus, outcome);
    }

    function _validateChallengeLifecycle(
        uint256 packageId,
        IChallengeLifecycleModule.ChallengeLifecycleContext memory context
    )
        internal
        view
    {
        AVARulePackageRegistry.RulePackage memory rulePackage = rulePackageRegistry.getRulePackageById(packageId);
        if (rulePackage.workflowKey != context.workflowKey) revert AVADataTypes.InvalidState(packageId);
        rulePackage.challengeLifecycleModule.validateChallengeAction(context);
    }

    function _validateResidualEditorialAuthority(
        bytes32 workflowKey,
        uint256 packageId,
        AVADataTypes.Role actingRole,
        AVADataTypes.Action action,
        uint256 recognisedStateId,
        bytes32 objectId,
        uint256 evidenceReceiptId,
        bytes32 authorityId
    ) internal view {
        AVARulePackageRegistry.RulePackage memory rulePackage = rulePackageRegistry.getRulePackageById(packageId);
        if (rulePackage.workflowKey != workflowKey) revert AVADataTypes.InvalidState(packageId);
        rulePackage.residualEditorialAuthorityModule.validateResidualEditorialAuthority(
            IResidualEditorialAuthorityModule.ResidualEditorialAuthorityContext({
                workflowKey: workflowKey,
                actingRole: actingRole,
                action: action,
                recognisedStateId: recognisedStateId,
                objectId: objectId,
                evidenceReceiptId: evidenceReceiptId,
                authorityId: authorityId,
                actor: msg.sender
            })
        );
    }

    function _requireExternallyRegistrableStatus(AVADataTypes.RecognisedStateStatus status) internal pure {
        if (
            status == AVADataTypes.RecognisedStateStatus.Vested || status == AVADataTypes.RecognisedStateStatus.Restored
                || status == AVADataTypes.RecognisedStateStatus.Downgraded
                || status == AVADataTypes.RecognisedStateStatus.Voided
        ) {
            revert AVADataTypes.InvalidState(uint256(status));
        }
    }

    function _requireGenericTransitionStatus(
        AVADataTypes.RecognisedStateStatus fromStatus,
        AVADataTypes.RecognisedStateStatus toStatus
    ) internal pure {
        if (fromStatus != AVADataTypes.RecognisedStateStatus.Registered) {
            revert AVADataTypes.InvalidState(uint256(fromStatus));
        }
        if (toStatus != AVADataTypes.RecognisedStateStatus.Vested) {
            revert AVADataTypes.InvalidState(uint256(toStatus));
        }
    }

    function _storeRecognisedState(
        AVADataTypes.Role actingRole,
        bytes32 workflowKey,
        uint256 packageId,
        AVADataTypes.AVAStage stage,
        bytes32 attributedObjectId,
        uint256 evidenceReceiptId,
        uint256 disclosurePolicyId,
        bytes32 authorityId,
        AVADataTypes.RecognisedStateStatus status,
        AVADataTypes.Action action
    ) internal returns (uint256 id) {
        id = nextRecognisedStateId++;
        recognisedStates[id] = AVADataTypes.RecognisedStateRecord({
            id: id,
            workflowKey: workflowKey,
            packageId: packageId,
            stage: stage,
            objectId: attributedObjectId,
            evidenceReceiptId: evidenceReceiptId,
            disclosurePolicyId: disclosurePolicyId,
            authorityId: authorityId,
            status: status,
            registeredBy: msg.sender
        });

        emit RecognisedStateRegistered(
            id, stage, attributedObjectId, evidenceReceiptId, disclosurePolicyId, authorityId, status, msg.sender
        );
        uint256 transitionId = nextRecognisedStateTransitionId++;
        AVADataTypes.RecognisedStateTransitionRecord storage transition = recognisedStateTransitions[transitionId];
        transition.id = transitionId;
        transition.recognisedStateId = id;
        transition.packageId = packageId;
        transition.fromStatus = AVADataTypes.RecognisedStateStatus.None;
        transition.toStatus = status;
        transition.action = action;
        transition.evidenceReceiptId = evidenceReceiptId;
        transition.authorityRole = actingRole;
        transition.authorityId = authorityId;
        transition.createdBy = msg.sender;
        emit RecognisedStateTransitionRecorded(transitionId, id, AVADataTypes.RecognisedStateStatus.None, status, action);
    }

    function _recordRecognisedStateTransition(
        uint256 recognisedStateId,
        uint256 packageId,
        AVADataTypes.RecognisedStateStatus fromStatus,
        AVADataTypes.RecognisedStateStatus toStatus,
        AVADataTypes.Action action,
        uint256 challengeId,
        uint256 evidenceReceiptId,
        AVADataTypes.Role authorityRole,
        bytes32 authorityId,
        string memory reasonURI
    ) internal returns (uint256 id) {
        id = nextRecognisedStateTransitionId++;
        recognisedStateTransitions[id] = AVADataTypes.RecognisedStateTransitionRecord({
            id: id,
            recognisedStateId: recognisedStateId,
            packageId: packageId,
            fromStatus: fromStatus,
            toStatus: toStatus,
            action: action,
            challengeId: challengeId,
            evidenceReceiptId: evidenceReceiptId,
            authorityRole: authorityRole,
            authorityId: authorityId,
            reasonURI: reasonURI,
            createdBy: msg.sender
        });
        emit RecognisedStateTransitionRecorded(id, recognisedStateId, fromStatus, toStatus, action);
    }

}
