// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "./AVADataTypes.sol";
import {AuthorityMatrix} from "./AuthorityMatrix.sol";
import {AVAStateMachine} from "./AVAStateMachine.sol";
import {AVAChallengeWorkflow} from "./AVAChallengeWorkflow.sol";
import {AVARulePackageRegistry} from "./AVARulePackageRegistry.sol";
import {EvidenceCommitmentRegistry} from "./EvidenceCommitmentRegistry.sol";
import {StandingRevisionRegistry} from "./StandingRevisionRegistry.sol";
import {ConsequenceBoundaryValidator} from "./ConsequenceBoundaryValidator.sol";

interface IValueSettlementReader {
    function getValueSettlement(uint256 id) external view returns (AVADataTypes.ValueSettlementRecord memory);
}

contract ConsequenceExecutor {
    address private immutable admin;
    AuthorityMatrix private immutable authorityMatrix;
    AVAStateMachine private immutable stateMachine;
    AVAChallengeWorkflow private immutable challengeWorkflow;
    AVARulePackageRegistry private immutable rulePackageRegistry;
    EvidenceCommitmentRegistry private immutable evidenceRegistry;
    StandingRevisionRegistry private immutable standingRevisionRegistry;
    ConsequenceBoundaryValidator private boundaryValidator;
    IValueSettlementReader private valueSettlementReader;
    uint256 public nextConsequenceId = 1;
    uint256 public nextStandingPenaltyInputId = 1;
    uint256 public nextEligibilityRestrictionId = 1;

    mapping(uint256 => AVADataTypes.ConsequenceRecord) private consequences;
    mapping(uint256 => AVADataTypes.StandingPenaltyInputRecord) private standingPenaltyInputs;
    mapping(uint256 => AVADataTypes.EligibilityRestrictionRecord) private eligibilityRestrictions;
    mapping(bytes32 => uint256) private activeEligibilityRestrictionIdBySubjectKind;
    mapping(bytes32 => uint256) private standingPenaltyInputIdByHash;
    mapping(bytes32 => uint256) private eligibilityRestrictionIdByHash;
    mapping(bytes32 => uint256) private penaltyConsequenceIdBySourceHash;

    event ConsequenceRegistered(
        uint256 indexed id,
        uint256 indexed recognisedStateId,
        AVADataTypes.ConsequenceKind indexed kind,
        bytes32 subjectId,
        uint256 evidenceReceiptId,
        AVADataTypes.Role authorityRole,
        bytes32 authorityId,
        string uri,
        address registeredBy
    );
    event StandingPenaltyInputRecorded(
        uint256 indexed id,
        uint256 indexed penaltyConsequenceId,
        AVADataTypes.GovernanceFindingKind indexed findingKind,
        bytes32 subjectId,
        int256 delta
    );
    event EligibilityRestrictionRecorded(
        uint256 indexed id,
        uint256 indexed penaltyConsequenceId,
        AVADataTypes.EligibilityRestrictionKind indexed restrictionKind,
        bytes32 subjectId
    );
    event ValueSettlementReaderBound(address indexed reader);
    event PenaltyConsequenceBound(
        uint256 indexed consequenceId,
        uint256 indexed challengeId,
        AVADataTypes.GovernanceFindingKind indexed findingKind,
        uint256 decisionPackageId,
        uint256 originSettlementId
    );

    constructor(
        AuthorityMatrix authorityMatrix_,
        AVAStateMachine stateMachine_,
        AVAChallengeWorkflow challengeWorkflow_,
        AVARulePackageRegistry rulePackageRegistry_,
        EvidenceCommitmentRegistry evidenceRegistry_,
        StandingRevisionRegistry standingRevisionRegistry_
    ) {
        if (address(standingRevisionRegistry_) == address(0)) {
            revert AVADataTypes.EmptyValue();
        }
        admin = msg.sender;
        authorityMatrix = authorityMatrix_;
        stateMachine = stateMachine_;
        challengeWorkflow = challengeWorkflow_;
        rulePackageRegistry = rulePackageRegistry_;
        evidenceRegistry = evidenceRegistry_;
        standingRevisionRegistry = standingRevisionRegistry_;
        boundaryValidator = new ConsequenceBoundaryValidator();
    }

    function bindValueSettlementReader(IValueSettlementReader reader) external {
        if (msg.sender != admin) revert AVADataTypes.NotAdmin(msg.sender);
        if (address(valueSettlementReader) != address(0)) revert AVADataTypes.InvalidState(0);
        if (address(reader) == address(0) || address(reader).code.length == 0) revert AVADataTypes.EmptyValue();
        valueSettlementReader = reader;
        emit ValueSettlementReaderBound(address(reader));
    }

    function registerConsequence(
        AVADataTypes.Role actingRole,
        uint256 recognisedStateId,
        AVADataTypes.ConsequenceKind kind,
        bytes32 subjectId,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        return _registerConsequenceWithExecution(
            actingRole,
            kind,
            _defaultValueExecutionContext(recognisedStateId, subjectId, 1, evidenceReceiptId, authorityId, uri)
        );
    }

    function registerConsequenceWithExecution(
        AVADataTypes.Role actingRole,
        AVADataTypes.ConsequenceKind kind,
        AVADataTypes.ValueExecutionContext calldata executionContext
    ) external returns (uint256 id) {
        return _registerConsequenceWithExecution(actingRole, kind, executionContext);
    }

    function recordPenalty(
        AVADataTypes.Role actingRole,
        AVADataTypes.PenaltyConsequenceContext calldata penaltyContext,
        AVADataTypes.ValueExecutionContext calldata executionContext
    ) external returns (uint256 id) {
        return _recordPenalty(actingRole, penaltyContext, executionContext);
    }

    function recordRestoration(
        AVADataTypes.Role actingRole,
        uint256 recognisedStateId,
        bytes32 subjectId,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        return _recordRestorationWithExecution(
            actingRole,
            _defaultValueExecutionContext(recognisedStateId, subjectId, 1, evidenceReceiptId, authorityId, uri)
        );
    }

    function recordRestorationWithExecution(
        AVADataTypes.Role actingRole,
        AVADataTypes.ValueExecutionContext calldata executionContext
    ) external returns (uint256 id) {
        return _recordRestorationWithExecution(actingRole, executionContext);
    }

    function getConsequence(uint256 id) external view returns (AVADataTypes.ConsequenceRecord memory) {
        AVADataTypes.ConsequenceRecord memory consequence = consequences[id];
        if (consequence.id == 0) revert AVADataTypes.UnknownReference(id);
        return consequence;
    }

    function consequenceSubstrate()
        external
        view
        returns (
            AVAStateMachine stateMachine_,
            AVARulePackageRegistry rulePackageRegistry_,
            EvidenceCommitmentRegistry evidenceRegistry_
        )
    {
        return (stateMachine, rulePackageRegistry, evidenceRegistry);
    }

    function recordStandingPenaltyInput(
        AVADataTypes.Role actingRole,
        uint256 penaltyConsequenceId,
        string calldata dimension,
        int256 delta,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.RegisterConsequence, authorityId
        );
        if (
            bytes(dimension).length == 0 || delta >= 0 || evidenceReceiptId == 0 || authorityId == bytes32(0)
                || bytes(uri).length == 0
        ) {
            revert AVADataTypes.EmptyValue();
        }
        AVADataTypes.ConsequenceRecord memory penalty = _requirePenaltyConsequence(penaltyConsequenceId);
        _requireEvidenceForPenalty(evidenceReceiptId, penalty);
        AVADataTypes.StandingPenaltyValidationContext memory validationContext =
            AVADataTypes.StandingPenaltyValidationContext({
                penaltyConsequenceId: penaltyConsequenceId,
                packageId: penalty.packageId,
                challengeId: penalty.challengeId,
                findingKind: penalty.findingKind,
                challengeOutcome: penalty.challengeOutcome,
                subjectId: penalty.subjectId,
                dimension: dimension,
                delta: delta,
                evidenceReceiptId: evidenceReceiptId,
                authorityId: authorityId,
                actor: msg.sender
            });
        rulePackageRegistry.getRulePackageById(penalty.packageId).penaltyAdapter
            .validateStandingPenaltyInput(validationContext);
        bytes32 inputHash = _hashFourWords(
            bytes32(penalty.packageId), bytes32(penalty.challengeId), penalty.subjectId, keccak256(bytes(dimension))
        );
        if (standingPenaltyInputIdByHash[inputHash] != 0) {
            revert AVADataTypes.InvalidState(standingPenaltyInputIdByHash[inputHash]);
        }

        id = nextStandingPenaltyInputId++;
        standingPenaltyInputs[id] = AVADataTypes.StandingPenaltyInputRecord({
            id: id,
            penaltyConsequenceId: penaltyConsequenceId,
            packageId: penalty.packageId,
            challengeId: penalty.challengeId,
            findingKind: penalty.findingKind,
            challengeOutcome: penalty.challengeOutcome,
            subjectId: penalty.subjectId,
            dimension: dimension,
            delta: delta,
            evidenceReceiptId: evidenceReceiptId,
            authorityRole: actingRole,
            authorityId: authorityId,
            uri: uri,
            recordedBy: msg.sender
        });
        standingPenaltyInputIdByHash[inputHash] = id;
        standingRevisionRegistry.advanceRevision(
            penalty.packageId, penalty.subjectId, AVADataTypes.StandingRevisionReason.StandingPenalty, id
        );
        emit StandingPenaltyInputRecorded(id, penaltyConsequenceId, penalty.findingKind, penalty.subjectId, delta);
    }

    function recordEligibilityRestriction(
        AVADataTypes.Role actingRole,
        uint256 penaltyConsequenceId,
        AVADataTypes.EligibilityRestrictionKind restrictionKind,
        uint256 expiresAt,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.RegisterConsequence, authorityId
        );
        if (
            restrictionKind == AVADataTypes.EligibilityRestrictionKind.None || expiresAt <= block.timestamp
                || evidenceReceiptId == 0 || authorityId == bytes32(0) || bytes(uri).length == 0
        ) {
            revert AVADataTypes.EmptyValue();
        }
        AVADataTypes.ConsequenceRecord memory penalty = _requirePenaltyConsequence(penaltyConsequenceId);
        boundaryValidator.requireCompatibleEligibilityOutcome(
            penalty.challengeOutcome, penalty.findingKind, penalty.challengeId, restrictionKind
        );
        _requireEvidenceForPenalty(evidenceReceiptId, penalty);
        AVADataTypes.EligibilityRestrictionValidationContext memory validationContext =
            AVADataTypes.EligibilityRestrictionValidationContext({
                penaltyConsequenceId: penaltyConsequenceId,
                packageId: penalty.packageId,
                challengeId: penalty.challengeId,
                findingKind: penalty.findingKind,
                challengeOutcome: penalty.challengeOutcome,
                restrictionKind: restrictionKind,
                subjectId: penalty.subjectId,
                expiresAt: expiresAt,
                evidenceReceiptId: evidenceReceiptId,
                authorityId: authorityId,
                actor: msg.sender
            });
        rulePackageRegistry.getRulePackageById(penalty.packageId).penaltyAdapter
            .validateEligibilityRestriction(validationContext);
        bytes32 inputHash = _hashThreeWords(
            bytes32(penalty.packageId), bytes32(penaltyConsequenceId), bytes32(uint256(restrictionKind))
        );
        if (eligibilityRestrictionIdByHash[inputHash] != 0) {
            revert AVADataTypes.InvalidState(eligibilityRestrictionIdByHash[inputHash]);
        }

        id = nextEligibilityRestrictionId++;
        eligibilityRestrictions[id] = AVADataTypes.EligibilityRestrictionRecord({
            id: id,
            penaltyConsequenceId: penaltyConsequenceId,
            packageId: penalty.packageId,
            challengeId: penalty.challengeId,
            findingKind: penalty.findingKind,
            restrictionKind: restrictionKind,
            challengeOutcome: penalty.challengeOutcome,
            subjectId: penalty.subjectId,
            expiresAt: expiresAt,
            evidenceReceiptId: evidenceReceiptId,
            authorityRole: actingRole,
            authorityId: authorityId,
            uri: uri,
            recordedBy: msg.sender
        });
        eligibilityRestrictionIdByHash[inputHash] = id;
        _indexActiveEligibilityRestriction(penalty.packageId, penalty.subjectId, restrictionKind, id, expiresAt);
        standingRevisionRegistry.advanceRevision(
            penalty.packageId, penalty.subjectId, AVADataTypes.StandingRevisionReason.EligibilityRestriction, id
        );
        emit EligibilityRestrictionRecorded(id, penaltyConsequenceId, restrictionKind, penalty.subjectId);
    }

    function getStandingPenaltyInput(uint256 id)
        external
        view
        returns (AVADataTypes.StandingPenaltyInputRecord memory)
    {
        AVADataTypes.StandingPenaltyInputRecord memory record = standingPenaltyInputs[id];
        if (record.id == 0) revert AVADataTypes.UnknownReference(id);
        return record;
    }

    function activeEligibilityRestrictionId(
        uint256 packageId,
        bytes32 subjectId,
        AVADataTypes.EligibilityRestrictionKind restrictionKind
    ) external view returns (uint256) {
        return _activeEligibilityRestrictionId(packageId, subjectId, restrictionKind);
    }

    function getEligibilityRestriction(uint256 id)
        external
        view
        returns (AVADataTypes.EligibilityRestrictionRecord memory)
    {
        AVADataTypes.EligibilityRestrictionRecord memory record = eligibilityRestrictions[id];
        if (record.id == 0) revert AVADataTypes.UnknownReference(id);
        return record;
    }

    function _requireAllowedRecognisedState(uint256 recognisedStateId)
        internal
        view
        returns (AVADataTypes.RecognisedStateRecord memory recognisedState)
    {
        recognisedState = stateMachine.getRecognisedState(recognisedStateId);
        AVADataTypes.RecognisedStateStatus status = recognisedState.status;
        if (
            status != AVADataTypes.RecognisedStateStatus.Vested && status != AVADataTypes.RecognisedStateStatus.Restored
                && status != AVADataTypes.RecognisedStateStatus.Downgraded
                && status != AVADataTypes.RecognisedStateStatus.Voided
        ) {
            revert AVADataTypes.InvalidState(recognisedStateId);
        }
        evidenceRegistry.requireUsableEvidenceReceiptForPackage(
            recognisedState.evidenceReceiptId, recognisedState.packageId
        );
    }

    function _recordConsequence(
        AVADataTypes.Role actingRole,
        AVADataTypes.ConsequenceKind kind,
        AVADataTypes.ValueExecutionContext memory executionContext,
        uint256 packageId,
        uint256 decisionPackageId,
        AVADataTypes.PenaltyConsequenceContext memory penaltyContext,
        AVADataTypes.ChallengeOutcome challengeOutcome
    ) internal returns (uint256 id) {
        id = nextConsequenceId++;
        consequences[id] = AVADataTypes.ConsequenceRecord({
            id: id,
            recognisedStateId: executionContext.recognisedStateId,
            packageId: packageId,
            decisionPackageId: decisionPackageId,
            kind: kind,
            challengeId: penaltyContext.challengeId,
            findingKind: penaltyContext.findingKind,
            challengeOutcome: challengeOutcome,
            originSettlementId: penaltyContext.originSettlementId,
            subjectId: executionContext.recipientSubjectId,
            asset: executionContext.asset,
            payer: executionContext.payer,
            amountOrUnits: executionContext.amount,
            executionMode: executionContext.mode,
            settlementKind: executionContext.settlementKind,
            executionReference: executionContext.executionReference,
            evidenceReceiptId: executionContext.evidenceReceiptId,
            authorityRole: actingRole,
            authorityId: executionContext.authorityId,
            uri: executionContext.uri,
            registeredBy: msg.sender
        });

        emit ConsequenceRegistered(
            id,
            executionContext.recognisedStateId,
            kind,
            executionContext.recipientSubjectId,
            executionContext.evidenceReceiptId,
            actingRole,
            executionContext.authorityId,
            executionContext.uri,
            msg.sender
        );
    }

    function _validateAntiAbuse(
        AVARulePackageRegistry.RulePackage memory rulePackage,
        bytes32 workflowKey,
        AVADataTypes.Role actingRole,
        bytes32 subjectId,
        uint256 recognisedStateId
    ) internal view {
        rulePackage.antiAbuseModule
            .validateUse(
                workflowKey,
                actingRole,
                AVADataTypes.Action.RegisterConsequence,
                subjectId,
                bytes32(recognisedStateId),
                msg.sender
            );
    }

    function _validateValueExecution(
        AVARulePackageRegistry.RulePackage memory rulePackage,
        AVADataTypes.ValueExecutionContext memory executionContext
    ) internal view {
        rulePackage.valueExecutionAdapter.validateValueExecution(executionContext);
    }

    function _defaultValueExecutionContext(
        uint256 recognisedStateId,
        bytes32 subjectId,
        uint256 amountOrUnits,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri
    ) internal view returns (AVADataTypes.ValueExecutionContext memory) {
        return AVADataTypes.ValueExecutionContext({
            recognisedStateId: recognisedStateId,
            asset: address(0),
            payer: address(0),
            recipientSubjectId: subjectId,
            amount: amountOrUnits,
            mode: AVADataTypes.ValueExecutionMode.RecordOnly,
            settlementKind: AVADataTypes.ValueSettlementKind.None,
            executionReference: keccak256(bytes(uri)),
            authorityId: authorityId,
            evidenceReceiptId: evidenceReceiptId,
            uri: uri,
            actor: msg.sender
        });
    }

    function _registerConsequenceWithExecution(
        AVADataTypes.Role actingRole,
        AVADataTypes.ConsequenceKind kind,
        AVADataTypes.ValueExecutionContext memory executionContext
    ) internal returns (uint256 id) {
        boundaryValidator.requireExecutionContext(kind, executionContext, msg.sender, true);
        AVARulePackageRegistry.RulePackage memory rulePackage =
            _prepareConsequenceExecution(actingRole, executionContext);
        rulePackage.consequenceAdapter
            .validateConsequence(
                actingRole,
                executionContext.recognisedStateId,
                kind,
                executionContext.recipientSubjectId,
                executionContext.evidenceReceiptId,
                executionContext.authorityId,
                executionContext.uri,
                msg.sender
            );
        id = _recordConsequence(
            actingRole,
            kind,
            executionContext,
            rulePackage.packageId,
            rulePackage.packageId,
            _emptyPenaltyContext(),
            AVADataTypes.ChallengeOutcome.None
        );
    }

    function _recordPenalty(
        AVADataTypes.Role actingRole,
        AVADataTypes.PenaltyConsequenceContext memory penaltyContext,
        AVADataTypes.ValueExecutionContext memory executionContext
    ) internal returns (uint256 id) {
        boundaryValidator.requireExecutionContext(
            AVADataTypes.ConsequenceKind.PenaltyRecord, executionContext, msg.sender, false
        );
        (AVARulePackageRegistry.RulePackage memory rulePackage, AVADataTypes.ChallengeRecord memory challenge) =
            _preparePenaltyExecution(actingRole, penaltyContext, executionContext);
        _requireOriginSettlement(penaltyContext.originSettlementId, executionContext, rulePackage.packageId);
        bytes32 sourceHash = _penaltyConsequenceSourceHash(
            rulePackage.packageId, challenge.packageId, challenge.outcome, penaltyContext, executionContext
        );
        uint256 existingPenaltyId = penaltyConsequenceIdBySourceHash[sourceHash];
        if (existingPenaltyId != 0) revert AVADataTypes.InvalidState(existingPenaltyId);
        rulePackage.penaltyAdapter
            .validatePenaltyRecord(
                actingRole,
                executionContext.recognisedStateId,
                penaltyContext.challengeId,
                penaltyContext.findingKind,
                challenge.outcome,
                executionContext.recipientSubjectId,
                executionContext.evidenceReceiptId,
                executionContext.authorityId,
                executionContext.uri,
                msg.sender
            );
        id = _recordConsequence(
            actingRole,
            AVADataTypes.ConsequenceKind.PenaltyRecord,
            executionContext,
            rulePackage.packageId,
            challenge.packageId,
            penaltyContext,
            challenge.outcome
        );
        penaltyConsequenceIdBySourceHash[sourceHash] = id;
        emit PenaltyConsequenceBound(
            id,
            penaltyContext.challengeId,
            penaltyContext.findingKind,
            challenge.packageId,
            penaltyContext.originSettlementId
        );
    }

    function _penaltyConsequenceSourceHash(
        uint256 packageId,
        uint256 decisionPackageId,
        AVADataTypes.ChallengeOutcome outcome,
        AVADataTypes.PenaltyConsequenceContext memory penaltyContext,
        AVADataTypes.ValueExecutionContext memory executionContext
    ) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, packageId)
            mstore(add(ptr, 0x20), decisionPackageId)
            mstore(add(ptr, 0x40), mload(executionContext))
            mstore(add(ptr, 0x60), mload(penaltyContext))
            mstore(add(ptr, 0x80), mload(add(penaltyContext, 0x20)))
            mstore(add(ptr, 0xa0), outcome)
            mstore(add(ptr, 0xc0), mload(add(executionContext, 0x60)))
            mstore(add(ptr, 0xe0), mload(add(penaltyContext, 0x40)))
            result := keccak256(ptr, 0x100)
        }
    }

    function _recordRestorationWithExecution(
        AVADataTypes.Role actingRole,
        AVADataTypes.ValueExecutionContext memory executionContext
    ) internal returns (uint256 id) {
        boundaryValidator.requireExecutionContext(
            AVADataTypes.ConsequenceKind.RestorationRecord, executionContext, msg.sender, false
        );
        AVARulePackageRegistry.RulePackage memory rulePackage =
            _prepareConsequenceExecution(actingRole, executionContext);
        rulePackage.restorationAdapter
            .validateRestorationRecord(
                actingRole,
                executionContext.recognisedStateId,
                executionContext.recipientSubjectId,
                executionContext.evidenceReceiptId,
                executionContext.authorityId,
                executionContext.uri,
                msg.sender
            );
        id = _recordConsequence(
            actingRole,
            AVADataTypes.ConsequenceKind.RestorationRecord,
            executionContext,
            rulePackage.packageId,
            rulePackage.packageId,
            _emptyPenaltyContext(),
            AVADataTypes.ChallengeOutcome.None
        );
    }

    function _emptyPenaltyContext() internal pure returns (AVADataTypes.PenaltyConsequenceContext memory context) {
        context.findingKind = AVADataTypes.GovernanceFindingKind.None;
    }

    function _prepareConsequenceExecution(
        AVADataTypes.Role actingRole,
        AVADataTypes.ValueExecutionContext memory executionContext
    ) internal view returns (AVARulePackageRegistry.RulePackage memory rulePackage) {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.RegisterConsequence, executionContext.authorityId
        );
        AVADataTypes.RecognisedStateRecord memory recognisedState =
            _requireAllowedRecognisedState(executionContext.recognisedStateId);
        authorityMatrix.requireKnownActiveSubject(executionContext.recipientSubjectId);
        _requireRecognisedStateSubject(recognisedState, executionContext.recipientSubjectId);
        evidenceRegistry.requireUsableEvidenceReceiptForPackage(
            executionContext.evidenceReceiptId, recognisedState.packageId
        );
        rulePackage = rulePackageRegistry.getRulePackageById(recognisedState.packageId);
        _validateEvidenceLifecycle(rulePackage, recognisedState.evidenceReceiptId);
        if (executionContext.evidenceReceiptId != recognisedState.evidenceReceiptId) {
            _validateEvidenceLifecycle(rulePackage, executionContext.evidenceReceiptId);
        }
        _validateAntiAbuse(
            rulePackage,
            recognisedState.workflowKey,
            actingRole,
            executionContext.recipientSubjectId,
            executionContext.recognisedStateId
        );
        _validateValueExecution(rulePackage, executionContext);
    }

    function _preparePenaltyExecution(
        AVADataTypes.Role actingRole,
        AVADataTypes.PenaltyConsequenceContext memory penaltyContext,
        AVADataTypes.ValueExecutionContext memory executionContext
    )
        internal
        view
        returns (AVARulePackageRegistry.RulePackage memory rulePackage, AVADataTypes.ChallengeRecord memory challenge)
    {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.RegisterConsequence, executionContext.authorityId
        );
        AVADataTypes.RecognisedStateRecord memory recognisedState =
            stateMachine.getRecognisedState(executionContext.recognisedStateId);
        authorityMatrix.requireKnownActiveSubject(executionContext.recipientSubjectId);
        challenge = challengeWorkflow.getChallenge(penaltyContext.challengeId);
        if (
            penaltyContext.findingKind == AVADataTypes.GovernanceFindingKind.None
                || challenge.challengedRecognisedStateId != recognisedState.id
                || challenge.targetWorkflowKey != recognisedState.workflowKey
                || challenge.targetPackageId != recognisedState.packageId
                || challenge.outcome == AVADataTypes.ChallengeOutcome.None
        ) {
            revert AVADataTypes.InvalidState(penaltyContext.challengeId);
        }
        AVADataTypes.Role subjectRole =
        authorityMatrix.roleRegistry().getSubject(executionContext.recipientSubjectId).role;
        boundaryValidator.requireCompatibleFindingSubject(
            challenge.outcome,
            challenge.id,
            challenge.challengerSubjectId,
            recognisedState.subjectId,
            penaltyContext.findingKind,
            executionContext.recipientSubjectId,
            subjectRole
        );
        bool challengerFinding = penaltyContext.findingKind == AVADataTypes.GovernanceFindingKind.NegligentChallenge
            || penaltyContext.findingKind == AVADataTypes.GovernanceFindingKind.MaliciousOrFabricatedChallenge;
        uint256 effectPackageId;
        bytes32 effectWorkflowKey;
        if (challengerFinding) {
            if (
                recognisedState.status != AVADataTypes.RecognisedStateStatus.Challengeable
                    && recognisedState.status != AVADataTypes.RecognisedStateStatus.Vested
                    && recognisedState.status != AVADataTypes.RecognisedStateStatus.Restored
            ) {
                revert AVADataTypes.InvalidState(recognisedState.id);
            }
            effectPackageId = challenge.packageId;
            effectWorkflowKey = challenge.workflowKey;
        } else {
            _requireAllowedRecognisedState(recognisedState.id);
            effectPackageId = recognisedState.packageId;
            effectWorkflowKey = recognisedState.workflowKey;
        }
        rulePackage = rulePackageRegistry.getRulePackageById(effectPackageId);
        evidenceRegistry.requireUsableEvidenceReceiptForPackage(executionContext.evidenceReceiptId, effectPackageId);
        if (!challengerFinding) {
            _validateEvidenceLifecycle(rulePackage, recognisedState.evidenceReceiptId);
        }
        if (challengerFinding || executionContext.evidenceReceiptId != recognisedState.evidenceReceiptId) {
            _validateEvidenceLifecycle(rulePackage, executionContext.evidenceReceiptId);
        }
        _validateAntiAbuse(
            rulePackage,
            effectWorkflowKey,
            actingRole,
            executionContext.recipientSubjectId,
            executionContext.recognisedStateId
        );
        _validateValueExecution(rulePackage, executionContext);
    }

    function _requirePenaltyConsequence(uint256 penaltyConsequenceId)
        internal
        view
        returns (AVADataTypes.ConsequenceRecord memory penalty)
    {
        penalty = consequences[penaltyConsequenceId];
        if (penalty.id == 0) revert AVADataTypes.UnknownReference(penaltyConsequenceId);
        if (
            penalty.kind != AVADataTypes.ConsequenceKind.PenaltyRecord
                || penalty.challengeOutcome == AVADataTypes.ChallengeOutcome.RejectedGoodFaith
        ) {
            revert AVADataTypes.InvalidState(penaltyConsequenceId);
        }
        authorityMatrix.requireKnownActiveSubject(penalty.subjectId);
    }

    function _requireOriginSettlement(
        uint256 originSettlementId,
        AVADataTypes.ValueExecutionContext memory executionContext,
        uint256 packageId
    ) internal view {
        if (executionContext.mode == AVADataTypes.ValueExecutionMode.RecordOnly) {
            if (originSettlementId != 0) revert AVADataTypes.InvalidState(originSettlementId);
            return;
        }
        if (originSettlementId == 0 || address(valueSettlementReader) == address(0)) {
            revert AVADataTypes.EmptyValue();
        }
        AVADataTypes.ValueSettlementRecord memory origin = valueSettlementReader.getValueSettlement(originSettlementId);
        bool completedTokenTransfer = origin.kind == AVADataTypes.ValueSettlementKind.TokenTransfer
            && origin.status == AVADataTypes.ValueSettlementStatus.Settled;
        bool completedEscrowClaim = origin.kind == AVADataTypes.ValueSettlementKind.EscrowClaim
            && origin.status == AVADataTypes.ValueSettlementStatus.Claimed;
        if (
            (!completedTokenTransfer && !completedEscrowClaim) || origin.packageId != packageId
                || origin.recognisedStateId != executionContext.recognisedStateId
                || origin.subjectId != executionContext.recipientSubjectId || origin.asset != executionContext.asset
                || origin.payer != executionContext.payer || origin.amountOrUnits != executionContext.amount
        ) {
            revert AVADataTypes.InvalidState(originSettlementId);
        }
    }

    function _requireRecognisedStateSubject(
        AVADataTypes.RecognisedStateRecord memory recognisedState,
        bytes32 subjectId
    ) internal pure {
        if (recognisedState.subjectId != subjectId) {
            revert AVADataTypes.InvalidState(recognisedState.id);
        }
    }

    function _requireEvidenceForPenalty(uint256 evidenceReceiptId, AVADataTypes.ConsequenceRecord memory penalty)
        internal
        view
    {
        AVARulePackageRegistry.RulePackage memory rulePackage =
            rulePackageRegistry.getRulePackageById(penalty.packageId);
        evidenceRegistry.requireUsableEvidenceReceiptForPackage(evidenceReceiptId, penalty.packageId);
        _validateEvidenceLifecycle(rulePackage, evidenceReceiptId);
    }

    function _validateEvidenceLifecycle(
        AVARulePackageRegistry.RulePackage memory rulePackage,
        uint256 evidenceReceiptId
    ) internal view {
        rulePackage.evidenceLifecycleModule
            .validateEvidenceLifecycle(
                rulePackage.workflowKey,
                AVADataTypes.Action.RegisterConsequence,
                evidenceReceiptId,
                AVADataTypes.EvidenceLifecycleKind.None,
                0,
                bytes32(0),
                msg.sender
            );
    }

    function _indexActiveEligibilityRestriction(
        uint256 packageId,
        bytes32 subjectId,
        AVADataTypes.EligibilityRestrictionKind restrictionKind,
        uint256 restrictionId,
        uint256 expiresAt
    ) internal {
        bytes32 key = _hashThreeWords(bytes32(packageId), subjectId, bytes32(uint256(restrictionKind)));
        uint256 currentId = activeEligibilityRestrictionIdBySubjectKind[key];
        if (currentId == 0) {
            activeEligibilityRestrictionIdBySubjectKind[key] = restrictionId;
            return;
        }
        AVADataTypes.EligibilityRestrictionRecord memory current = eligibilityRestrictions[currentId];
        if (current.id == 0 || current.expiresAt <= block.timestamp || expiresAt >= current.expiresAt) {
            activeEligibilityRestrictionIdBySubjectKind[key] = restrictionId;
        }
    }

    function _activeEligibilityRestrictionId(
        uint256 packageId,
        bytes32 subjectId,
        AVADataTypes.EligibilityRestrictionKind restrictionKind
    ) internal view returns (uint256) {
        if (
            packageId == 0 || subjectId == bytes32(0) || restrictionKind == AVADataTypes.EligibilityRestrictionKind.None
        ) {
            return 0;
        }
        uint256 id = activeEligibilityRestrictionIdBySubjectKind[
            _hashThreeWords(bytes32(packageId), subjectId, bytes32(uint256(restrictionKind)))
        ];
        if (id == 0) return 0;
        AVADataTypes.EligibilityRestrictionRecord memory record = eligibilityRestrictions[id];
        if (record.id == 0 || record.expiresAt <= block.timestamp) return 0;
        return id;
    }

    function _hashThreeWords(bytes32 first, bytes32 second, bytes32 third) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, first)
            mstore(add(ptr, 0x20), second)
            mstore(add(ptr, 0x40), third)
            result := keccak256(ptr, 0x60)
        }
    }

    function _hashFourWords(bytes32 first, bytes32 second, bytes32 third, bytes32 fourth)
        internal
        pure
        returns (bytes32 result)
    {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, first)
            mstore(add(ptr, 0x20), second)
            mstore(add(ptr, 0x40), third)
            mstore(add(ptr, 0x60), fourth)
            result := keccak256(ptr, 0x80)
        }
    }
}
