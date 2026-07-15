// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "./AVADataTypes.sol";
import {AVASubstrateTransitionRules} from "./AVASubstrateTransitionRules.sol";
import {AuthorityMatrix} from "./AuthorityMatrix.sol";
import {AVARulePackageRegistry} from "./AVARulePackageRegistry.sol";
import {AVAWorkflowValidator} from "./AVAWorkflowValidator.sol";
import {StandingRevisionRegistry} from "./StandingRevisionRegistry.sol";
import {IResidualEditorialAuthorityModule} from "./interfaces/IResidualEditorialAuthorityModule.sol";
import {IChallengeWindowRuleModule} from "./interfaces/IChallengeWindowRuleModule.sol";

contract AVAStateMachine {
    bytes32 public constant AUTHORITY_DECISION_DOMAIN = keccak256("AVA_AUTHORITY_DECISION_V1");

    struct ChallengeStateTransitionInput {
        uint256 recognisedStateId;
        uint256 challengeId;
        uint256 decisionPackageId;
        uint256 evidenceReceiptId;
        AVADataTypes.Action action;
        AVADataTypes.ChallengeOutcome outcome;
        AVADataTypes.RecognisedStateStatus targetStatusAtFiling;
        AVADataTypes.RecognisedStateStatus toStatus;
        AVADataTypes.Role authorityRole;
        bytes32 authorityId;
        string reasonURI;
        address actor;
    }

    struct RecognisedStateFormationInput {
        AVADataTypes.Role actingRole;
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        AVADataTypes.AVAStage stage;
        bytes32 objectId;
        bytes32 subjectId;
        uint256 evidenceReceiptId;
        uint256 disclosurePolicyId;
        bytes32 authorityId;
        AVADataTypes.RecognisedStateStatus status;
        AVADataTypes.Action action;
    }

    AuthorityMatrix public immutable authorityMatrix;
    AVARulePackageRegistry public immutable rulePackageRegistry;
    AVAWorkflowValidator public immutable workflowValidator;
    StandingRevisionRegistry public immutable standingRevisionRegistry;
    uint64 public immutable minimumChallengeWindowDuration;
    address public challengeWorkflow;
    uint256 public nextManuscriptId = 1;
    uint256 public nextRecognisedStateId = 1;
    uint256 public nextReviewContributionId = 1;
    uint256 public nextRecognisedStateTransitionId = 1;

    mapping(uint256 => AVADataTypes.ManuscriptRecord) private manuscripts;
    mapping(uint256 => AVADataTypes.RecognisedStateRecord) private recognisedStates;
    mapping(uint256 => AVADataTypes.ReviewContributionRecord) private reviewContributions;
    mapping(uint256 => AVADataTypes.RecognisedStateTransitionRecord) private recognisedStateTransitions;
    mapping(uint256 => uint256) private openChallengeCountsByRecognisedState;
    mapping(uint256 => uint64) private challengeWindowOpenedAtByRecognisedState;

    event ManuscriptRegistered(uint256 indexed id, bytes32 indexed offchainRef, string uri, address registeredBy);
    event RecognisedStateRegistered(
        uint256 indexed id,
        AVADataTypes.AVAStage indexed stage,
        bytes32 indexed objectId,
        bytes32 subjectId,
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
    event ChallengeWorkflowBound(address indexed challengeWorkflow);
    event RecognisedStateTransitionRecorded(
        uint256 indexed id,
        uint256 indexed recognisedStateId,
        AVADataTypes.RecognisedStateStatus fromStatus,
        AVADataTypes.RecognisedStateStatus toStatus,
        AVADataTypes.Action action
    );

    constructor(
        AuthorityMatrix authorityMatrix_,
        AVARulePackageRegistry rulePackageRegistry_,
        AVAWorkflowValidator workflowValidator_,
        StandingRevisionRegistry standingRevisionRegistry_,
        uint64 minimumChallengeWindowDuration_
    ) {
        if (address(standingRevisionRegistry_) == address(0) || minimumChallengeWindowDuration_ == 0) {
            revert AVADataTypes.EmptyValue();
        }
        authorityMatrix = authorityMatrix_;
        rulePackageRegistry = rulePackageRegistry_;
        workflowValidator = workflowValidator_;
        standingRevisionRegistry = standingRevisionRegistry_;
        minimumChallengeWindowDuration = minimumChallengeWindowDuration_;
    }

    function bindChallengeWorkflow(address challengeWorkflow_) external {
        if (msg.sender != authorityMatrix.admin()) revert AVADataTypes.NotAdmin(msg.sender);
        if (challengeWorkflow_ == address(0) || challengeWorkflow_.code.length == 0 || challengeWorkflow != address(0))
        {
            revert AVADataTypes.InvalidState(uint256(uint160(challengeWorkflow_)));
        }
        challengeWorkflow = challengeWorkflow_;
        emit ChallengeWorkflowBound(challengeWorkflow_);
    }

    function registerOpenChallenge(uint256 recognisedStateId) external {
        _requireChallengeWorkflow();
        AVADataTypes.RecognisedStateRecord storage state = recognisedStates[recognisedStateId];
        if (state.id == 0) revert AVADataTypes.UnknownReference(recognisedStateId);
        if (!_isChallengeTargetStatus(state.status)) {
            revert AVADataTypes.InvalidState(recognisedStateId);
        }
        openChallengeCountsByRecognisedState[recognisedStateId] += 1;
    }

    function _isChallengeTargetStatus(AVADataTypes.RecognisedStateStatus status) internal pure returns (bool) {
        return AVASubstrateTransitionRules.isChallengeTarget(status);
    }

    function closeOpenChallenge(uint256 recognisedStateId) external {
        _requireChallengeWorkflow();
        uint256 count = openChallengeCountsByRecognisedState[recognisedStateId];
        if (count == 0) revert AVADataTypes.InvalidState(recognisedStateId);
        openChallengeCountsByRecognisedState[recognisedStateId] = count - 1;
    }

    function applyChallengeStateTransition(ChallengeStateTransitionInput calldata input)
        external
        returns (uint256 transitionId)
    {
        _requireChallengeWorkflow();
        if (
            input.challengeId == 0 || input.decisionPackageId == 0 || input.evidenceReceiptId == 0
                || input.authorityId == bytes32(0) || input.actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }

        AVADataTypes.RecognisedStateRecord storage state = recognisedStates[input.recognisedStateId];
        if (state.id == 0) revert AVADataTypes.UnknownReference(input.recognisedStateId);
        AVADataTypes.RecognisedStateStatus fromStatus = state.status;

        if (input.action == AVADataTypes.Action.ResolveChallenge) {
            if (!AVASubstrateTransitionRules.isChallengeCorrection(fromStatus, input.toStatus, input.outcome)) {
                revert AVADataTypes.InvalidState(input.challengeId);
            }
        } else if (input.action == AVADataTypes.Action.ApplyRestoration) {
            if (!AVASubstrateTransitionRules.isRestorationTransition(
                    input.outcome, fromStatus, input.toStatus, input.targetStatusAtFiling
                )) {
                revert AVADataTypes.InvalidState(input.challengeId);
            }
        } else {
            revert AVADataTypes.InvalidState(uint256(input.action));
        }

        AVARulePackageRegistry.RulePackage memory rulePackage =
            _verifiedRulePackage(state.appId, state.workflowKey, state.packageId);
        if (
            input.action == AVADataTypes.Action.ResolveChallenge
                && input.outcome == AVADataTypes.ChallengeOutcome.Upheld
        ) {
            _validateHistoricalPinnedEvidence(rulePackage, input.action, state.evidenceReceiptId, input.actor);
        } else {
            _validatePinnedEvidence(rulePackage, input.action, state.evidenceReceiptId, input.actor);
        }
        _validateTransitionRule(rulePackage, input.action, fromStatus, input.toStatus, input.outcome);
        transitionId = _recordRecognisedStateTransition(
            input.recognisedStateId,
            state.packageId,
            fromStatus,
            input.toStatus,
            input.action,
            input.challengeId,
            input.evidenceReceiptId,
            input.authorityRole,
            input.authorityId,
            input.reasonURI
        );
        recognisedStateTransitions[transitionId].decisionPackageId = input.decisionPackageId;
        recognisedStateTransitions[transitionId].createdBy = input.actor;
        state.status = input.toStatus;
        _advanceStandingRevisionForTransition(state, transitionId);
    }

    function _requireChallengeWorkflow() internal view {
        if (msg.sender != challengeWorkflow || challengeWorkflow == address(0)) {
            revert AVADataTypes.NotAuthorised(msg.sender, AVADataTypes.Action.ResolveChallenge);
        }
    }

    function registerManuscript(
        AVADataTypes.Role actingRole,
        bytes32 appId,
        bytes32 workflowKey,
        bytes32 offchainRef,
        string calldata uri,
        string calldata externalReferenceURI
    ) public returns (uint256 id) {
        bytes32 registeredSubjectId = authorityMatrix.requireAuthorisedCanonicalSubject(
            msg.sender, actingRole, AVADataTypes.Action.RegisterManuscript
        );
        if (appId == bytes32(0) || workflowKey == bytes32(0) || offchainRef == bytes32(0)) {
            revert AVADataTypes.EmptyValue();
        }
        AVARulePackageRegistry.RulePackage memory rulePackage = rulePackageRegistry.getRulePackage(appId, workflowKey);
        if (bytes(externalReferenceURI).length != 0) {
            rulePackage.editorialSystemAdapter
                .validateEditorialReference(
                    workflowKey,
                    actingRole,
                    AVADataTypes.Action.RegisterManuscript,
                    offchainRef,
                    externalReferenceURI,
                    msg.sender
                );
        }
        return _registerManuscript(
            actingRole, appId, workflowKey, rulePackage.packageId, registeredSubjectId, offchainRef, uri
        );
    }

    function _registerManuscript(
        AVADataTypes.Role registeredRole,
        bytes32 appId,
        bytes32 workflowKey,
        uint256 packageId,
        bytes32 registeredSubjectId,
        bytes32 offchainRef,
        string calldata uri
    ) internal returns (uint256 id) {
        if (offchainRef == bytes32(0)) revert AVADataTypes.EmptyValue();
        id = nextManuscriptId++;
        AVADataTypes.ManuscriptRecord storage manuscript = manuscripts[id];
        manuscript.id = id;
        manuscript.appId = appId;
        manuscript.workflowKey = workflowKey;
        manuscript.packageId = packageId;
        manuscript.offchainRef = offchainRef;
        manuscript.uri = uri;
        manuscript.registeredRole = registeredRole;
        manuscript.registeredSubjectId = registeredSubjectId;
        manuscript.registeredBy = msg.sender;

        emit ManuscriptRegistered(id, offchainRef, uri, msg.sender);
    }

    function registerRecognisedState(
        AVADataTypes.Role actingRole,
        bytes32 appId,
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
        AVAWorkflowValidator.WorkflowValidationResult memory validation = workflowValidator.validateActivePackage(
            AVAWorkflowValidator.WorkflowValidationContext({
                appId: appId,
                workflowKey: workflowKey,
                actingRole: actingRole,
                action: AVADataTypes.Action.RegisterRecognisedState,
                stage: stage,
                objectId: objectId,
                subjectId: subjectId,
                evidenceReceiptId: evidenceReceiptId,
                disclosurePolicyId: disclosurePolicyId,
                actor: msg.sender
            })
        );

        id = _storeRecognisedState(
            RecognisedStateFormationInput({
                actingRole: actingRole,
                appId: appId,
                workflowKey: workflowKey,
                packageId: validation.packageId,
                stage: stage,
                objectId: validation.attributedObjectId,
                subjectId: subjectId,
                evidenceReceiptId: evidenceReceiptId,
                disclosurePolicyId: disclosurePolicyId,
                authorityId: authorityId,
                status: status,
                action: AVADataTypes.Action.RegisterRecognisedState
            })
        );
        _validateResidualEditorialAuthority(
            validation.residualEditorialAuthorityModule,
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
        bytes32 appId,
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
        AVADataTypes.ManuscriptRecord memory manuscript = manuscripts[manuscriptId];
        if (manuscript.id == 0) revert AVADataTypes.UnknownReference(manuscriptId);
        if (manuscript.appId != appId) {
            revert AVADataTypes.InvalidState(manuscriptId);
        }
        AVAWorkflowValidator.WorkflowValidationResult memory validation = workflowValidator.validateActivePackage(
            AVAWorkflowValidator.WorkflowValidationContext({
                appId: appId,
                workflowKey: workflowKey,
                actingRole: actingRole,
                action: AVADataTypes.Action.RegisterReviewContribution,
                stage: AVADataTypes.AVAStage.Attribution,
                objectId: bytes32(manuscriptId),
                subjectId: reviewerSubjectId,
                evidenceReceiptId: evidenceReceiptId,
                disclosurePolicyId: disclosurePolicyId,
                actor: msg.sender
            })
        );

        id = nextReviewContributionId++;
        reviewContributions[id] = AVADataTypes.ReviewContributionRecord({
            id: id,
            appId: appId,
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
            RecognisedStateFormationInput({
                actingRole: actingRole,
                appId: reviewContribution.appId,
                workflowKey: reviewContribution.workflowKey,
                packageId: reviewContribution.packageId,
                stage: AVADataTypes.AVAStage.Verification,
                objectId: bytes32(reviewContributionId),
                subjectId: reviewContribution.reviewerSubjectId,
                evidenceReceiptId: reviewContribution.evidenceReceiptId,
                disclosurePolicyId: reviewContribution.disclosurePolicyId,
                authorityId: authorityId,
                status: AVADataTypes.RecognisedStateStatus.Provisional,
                action: AVADataTypes.Action.ProvisionallyRecogniseReview
            })
        );
        reviewContribution.recognisedStateId = recognisedStateId;
        reviewContribution.status = AVADataTypes.ReviewContributionStatus.ProvisionalRecognised;

        emit ReviewProvisionallyRecognised(reviewContributionId, recognisedStateId);
    }

    function openReviewChallengeWindow(AVADataTypes.Role actingRole, uint256 reviewContributionId, bytes32 authorityId)
        external
    {
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
        AVARulePackageRegistry.RulePackage memory rulePackage = _verifiedRulePackage(
            reviewContribution.appId, reviewContribution.workflowKey, reviewContribution.packageId
        );
        _validatePinnedEvidence(
            rulePackage, AVADataTypes.Action.OpenChallengeWindow, reviewContribution.evidenceReceiptId, msg.sender
        );
        _validateTransitionRule(
            rulePackage,
            AVADataTypes.Action.OpenChallengeWindow,
            recognisedStates[recognisedStateId].status,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            AVADataTypes.ChallengeOutcome.None
        );
        _validateDisclosureForAction(
            rulePackage,
            reviewContribution.disclosurePolicyId,
            actingRole,
            AVADataTypes.Action.OpenChallengeWindow,
            AVADataTypes.AVAStage.Verification,
            bytes32(reviewContributionId),
            reviewContribution.reviewerSubjectId
        );
        _validateResidualEditorialAuthority(
            rulePackage.residualEditorialAuthorityModule,
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
        challengeWindowOpenedAtByRecognisedState[recognisedStateId] = uint64(block.timestamp);

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
        _requireMinimumChallengeWindowElapsed(reviewContribution.recognisedStateId);
        AVARulePackageRegistry.RulePackage memory rulePackage = _verifiedRulePackage(
            reviewContribution.appId, reviewContribution.workflowKey, reviewContribution.packageId
        );
        _validatePinnedEvidence(
            rulePackage, AVADataTypes.Action.TransitionRecognisedState, reviewContribution.evidenceReceiptId, msg.sender
        );
        _validateTransitionRule(
            rulePackage,
            AVADataTypes.Action.TransitionRecognisedState,
            fromStatus,
            AVADataTypes.RecognisedStateStatus.Vested,
            AVADataTypes.ChallengeOutcome.None
        );
        _validateChallengeWindowDurationIfConfigured(
            rulePackage,
            reviewContribution.recognisedStateId,
            challengeWindowOpenedAtByRecognisedState[reviewContribution.recognisedStateId]
        );
        _validateDisclosureForAction(
            rulePackage,
            reviewContribution.disclosurePolicyId,
            actingRole,
            AVADataTypes.Action.TransitionRecognisedState,
            AVADataTypes.AVAStage.Verification,
            bytes32(reviewContributionId),
            reviewContribution.reviewerSubjectId
        );
        _validateResidualEditorialAuthority(
            rulePackage.residualEditorialAuthorityModule,
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
        _advanceStandingRevisionForTransition(recognisedStates[reviewContribution.recognisedStateId], transitionId);
        reviewContribution.status = AVADataTypes.ReviewContributionStatus.Vested;

        emit ReviewRecognitionVested(reviewContributionId, reviewContribution.recognisedStateId, transitionId);
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

    function getChallengeWindowOpenedAt(uint256 recognisedStateId) external view returns (uint64) {
        if (recognisedStates[recognisedStateId].id == 0) revert AVADataTypes.UnknownReference(recognisedStateId);
        return challengeWindowOpenedAtByRecognisedState[recognisedStateId];
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
        AVARulePackageRegistry.RulePackage memory rulePackage =
            _verifiedRulePackage(recognisedState.appId, recognisedState.workflowKey, recognisedState.packageId);
        _validatePinnedEvidence(
            rulePackage, AVADataTypes.Action.TransitionRecognisedState, recognisedState.evidenceReceiptId, msg.sender
        );
        _validateTransitionRule(
            rulePackage,
            AVADataTypes.Action.TransitionRecognisedState,
            fromStatus,
            toStatus,
            AVADataTypes.ChallengeOutcome.None
        );
        _validateResidualEditorialAuthority(
            rulePackage.residualEditorialAuthorityModule,
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
        AVADataTypes.RecognisedStateTransitionRecord storage transition = recognisedStateTransitions[transitionId];
        transition.id = transitionId;
        transition.recognisedStateId = recognisedStateId;
        transition.packageId = recognisedState.packageId;
        transition.decisionPackageId = recognisedState.packageId;
        transition.fromStatus = fromStatus;
        transition.toStatus = toStatus;
        transition.action = AVADataTypes.Action.TransitionRecognisedState;
        transition.evidenceReceiptId = recognisedState.evidenceReceiptId;
        transition.authorityRole = actingRole;
        transition.authorityId = authorityId;
        transition.reasonURI = reasonURI;
        transition.createdAt = block.timestamp;
        transition.createdBy = msg.sender;
        emit RecognisedStateTransitionRecorded(
            transitionId, recognisedStateId, fromStatus, toStatus, AVADataTypes.Action.TransitionRecognisedState
        );
        recognisedState.lastTransitionId = transitionId;
        recognisedState.status = toStatus;
        _advanceStandingRevisionForTransition(recognisedState, transitionId);
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

    function _registerRecognisedState(RecognisedStateFormationInput memory input) internal returns (uint256 id) {
        AVAWorkflowValidator.WorkflowValidationResult memory validation = workflowValidator.validatePackage(
            AVAWorkflowValidator.WorkflowValidationContext({
                appId: input.appId,
                workflowKey: input.workflowKey,
                actingRole: input.actingRole,
                action: input.action,
                stage: input.stage,
                objectId: input.objectId,
                subjectId: input.subjectId,
                evidenceReceiptId: input.evidenceReceiptId,
                disclosurePolicyId: input.disclosurePolicyId,
                actor: msg.sender
            }),
            input.packageId
        );
        input.packageId = validation.packageId;
        input.objectId = validation.attributedObjectId;
        id = _storeRecognisedState(input);
        _validateResidualEditorialAuthority(
            validation.residualEditorialAuthorityModule,
            input.workflowKey,
            validation.packageId,
            input.actingRole,
            input.action,
            id,
            validation.attributedObjectId,
            input.evidenceReceiptId,
            input.authorityId
        );
    }

    function _validateDisclosureForAction(
        AVARulePackageRegistry.RulePackage memory rulePackage,
        uint256 disclosurePolicyId,
        AVADataTypes.Role actingRole,
        AVADataTypes.Action action,
        AVADataTypes.AVAStage stage,
        bytes32 objectId,
        bytes32 subjectCommitment
    ) internal view {
        rulePackage.disclosureModule
            .validateDisclosureForAction(
                disclosurePolicyId,
                actingRole,
                action,
                stage,
                objectId,
                rulePackage.workflowKey,
                rulePackage.packageId,
                subjectCommitment
            );
    }

    function _validateTransitionRule(
        AVARulePackageRegistry.RulePackage memory rulePackage,
        AVADataTypes.Action action,
        AVADataTypes.RecognisedStateStatus fromStatus,
        AVADataTypes.RecognisedStateStatus toStatus,
        AVADataTypes.ChallengeOutcome outcome
    ) internal view {
        rulePackage.transitionRuleModule
            .validateTransition(rulePackage.workflowKey, action, fromStatus, toStatus, outcome);
    }

    function _validatePinnedEvidence(
        AVARulePackageRegistry.RulePackage memory rulePackage,
        AVADataTypes.Action action,
        uint256 evidenceReceiptId,
        address actor
    ) internal view {
        workflowValidator.requireUsablePinnedEvidenceReceipt(
            rulePackage.appId, rulePackage.workflowKey, rulePackage.packageId, evidenceReceiptId
        );
        rulePackage.evidenceLifecycleModule
            .validateEvidenceLifecycle(
                rulePackage.workflowKey,
                action,
                evidenceReceiptId,
                AVADataTypes.EvidenceLifecycleKind.None,
                0,
                bytes32(0),
                actor
            );
    }

    function _validateHistoricalPinnedEvidence(
        AVARulePackageRegistry.RulePackage memory rulePackage,
        AVADataTypes.Action action,
        uint256 evidenceReceiptId,
        address actor
    ) internal view {
        workflowValidator.requirePinnedEvidenceReceipt(
            rulePackage.appId, rulePackage.workflowKey, rulePackage.packageId, evidenceReceiptId
        );
        rulePackage.evidenceLifecycleModule
            .validateEvidenceLifecycle(
                rulePackage.workflowKey,
                action,
                evidenceReceiptId,
                AVADataTypes.EvidenceLifecycleKind.None,
                0,
                bytes32(0),
                actor
            );
    }

    function _validateChallengeWindowDurationIfConfigured(
        AVARulePackageRegistry.RulePackage memory rulePackage,
        uint256 recognisedStateId,
        uint64 openedAt
    ) internal view {
        if (!_supportsChallengeWindowRule(address(rulePackage.transitionRuleModule))) return;
        (bool success, bytes memory result) = address(rulePackage.transitionRuleModule)
            .staticcall(
                abi.encodeWithSelector(
                    IChallengeWindowRuleModule.validateChallengeWindowDuration.selector,
                    rulePackage.workflowKey,
                    recognisedStateId,
                    openedAt,
                    uint64(block.timestamp),
                    msg.sender
                )
            );
        _handleRequiredModuleResult(success, result);
    }

    function _requireMinimumChallengeWindowElapsed(uint256 recognisedStateId) internal view {
        uint64 openedAt = challengeWindowOpenedAtByRecognisedState[recognisedStateId];
        if (openedAt == 0 || block.timestamp < uint256(openedAt) + minimumChallengeWindowDuration) {
            revert AVADataTypes.InvalidState(recognisedStateId);
        }
    }

    function _supportsChallengeWindowRule(address module) internal view returns (bool) {
        (bool success, bytes memory result) =
            module.staticcall(abi.encodeWithSelector(IChallengeWindowRuleModule.supportsChallengeWindowRule.selector));
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

    function _validateResidualEditorialAuthority(
        IResidualEditorialAuthorityModule residualEditorialAuthorityModule,
        bytes32 workflowKey,
        uint256 packageId,
        AVADataTypes.Role actingRole,
        AVADataTypes.Action action,
        uint256 recognisedStateId,
        bytes32 objectId,
        uint256 evidenceReceiptId,
        bytes32 authorityId
    ) internal view {
        residualEditorialAuthorityModule.validateResidualEditorialAuthority(
            IResidualEditorialAuthorityModule.ResidualEditorialAuthorityContext({
                workflowKey: workflowKey,
                packageId: packageId,
                targetPackageId: packageId,
                actingRole: actingRole,
                action: action,
                recognisedStateId: recognisedStateId,
                challengeId: 0,
                objectId: objectId,
                evidenceReceiptId: evidenceReceiptId,
                authorityId: authorityId,
                decisionHash: keccak256(
                    abi.encode(
                        AUTHORITY_DECISION_DOMAIN, packageId, action, recognisedStateId, objectId, evidenceReceiptId
                    )
                ),
                actor: msg.sender
            })
        );
    }

    function _verifiedRulePackage(bytes32 appId, bytes32 workflowKey, uint256 packageId)
        internal
        view
        returns (AVARulePackageRegistry.RulePackage memory rulePackage)
    {
        rulePackage = rulePackageRegistry.getRulePackageById(packageId);
        if (rulePackage.appId != appId || rulePackage.workflowKey != workflowKey) {
            revert AVADataTypes.InvalidState(packageId);
        }
    }

    function _requireExternallyRegistrableStatus(AVADataTypes.RecognisedStateStatus status) internal pure {
        AVASubstrateTransitionRules.requireExternallyRegistrableStatus(status);
    }

    function _requireGenericTransitionStatus(
        AVADataTypes.RecognisedStateStatus fromStatus,
        AVADataTypes.RecognisedStateStatus toStatus
    ) internal pure {
        AVASubstrateTransitionRules.requireGenericTransition(fromStatus, toStatus);
    }

    function _storeRecognisedState(RecognisedStateFormationInput memory input) internal returns (uint256 id) {
        id = nextRecognisedStateId++;
        recognisedStates[id] = AVADataTypes.RecognisedStateRecord({
            id: id,
            appId: input.appId,
            workflowKey: input.workflowKey,
            packageId: input.packageId,
            stage: input.stage,
            objectId: input.objectId,
            subjectId: input.subjectId,
            evidenceReceiptId: input.evidenceReceiptId,
            disclosurePolicyId: input.disclosurePolicyId,
            authorityId: input.authorityId,
            status: input.status,
            lastTransitionId: 0,
            registeredBy: msg.sender
        });

        emit RecognisedStateRegistered(
            id,
            input.stage,
            input.objectId,
            input.subjectId,
            input.evidenceReceiptId,
            input.disclosurePolicyId,
            input.authorityId,
            input.status,
            msg.sender
        );
        uint256 transitionId = nextRecognisedStateTransitionId++;
        AVADataTypes.RecognisedStateTransitionRecord storage transition = recognisedStateTransitions[transitionId];
        transition.id = transitionId;
        transition.recognisedStateId = id;
        transition.packageId = input.packageId;
        transition.decisionPackageId = input.packageId;
        transition.fromStatus = AVADataTypes.RecognisedStateStatus.None;
        transition.toStatus = input.status;
        transition.action = input.action;
        transition.evidenceReceiptId = input.evidenceReceiptId;
        transition.authorityRole = input.actingRole;
        transition.authorityId = input.authorityId;
        transition.createdAt = block.timestamp;
        transition.createdBy = msg.sender;
        recognisedStates[id].lastTransitionId = transitionId;
        emit RecognisedStateTransitionRecorded(
            transitionId, id, AVADataTypes.RecognisedStateStatus.None, input.status, input.action
        );
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
            decisionPackageId: packageId,
            fromStatus: fromStatus,
            toStatus: toStatus,
            action: action,
            challengeId: challengeId,
            evidenceReceiptId: evidenceReceiptId,
            authorityRole: authorityRole,
            authorityId: authorityId,
            reasonURI: reasonURI,
            createdAt: block.timestamp,
            createdBy: msg.sender
        });
        recognisedStates[recognisedStateId].lastTransitionId = id;
        emit RecognisedStateTransitionRecorded(id, recognisedStateId, fromStatus, toStatus, action);
    }

    function _advanceStandingRevisionForTransition(
        AVADataTypes.RecognisedStateRecord storage recognisedState,
        uint256 transitionId
    ) internal {
        AVADataTypes.RecognisedStateStatus status = recognisedState.status;
        if (
            status == AVADataTypes.RecognisedStateStatus.Vested
                || status == AVADataTypes.RecognisedStateStatus.Downgraded
                || status == AVADataTypes.RecognisedStateStatus.Voided
                || status == AVADataTypes.RecognisedStateStatus.Restored
        ) {
            standingRevisionRegistry.advanceRevision(
                recognisedState.packageId,
                recognisedState.subjectId,
                AVADataTypes.StandingRevisionReason.RecognisedStateTransition,
                transitionId
            );
        }
    }
}
