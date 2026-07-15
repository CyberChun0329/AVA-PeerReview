// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../src/AVADataTypes.sol";
import {AVAStateMachine} from "../src/AVAStateMachine.sol";
import {AVAChallengeWorkflow} from "../src/AVAChallengeWorkflow.sol";
import {EvidenceCommitmentRegistry} from "../src/EvidenceCommitmentRegistry.sol";
import {ValueSettlementExecutor} from "../src/ValueSettlementExecutor.sol";
import {StandingRegistry} from "../src/StandingRegistry.sol";
import {StandingCredentialRegistry} from "../src/StandingCredentialRegistry.sol";
import {StandingRevisionRegistry} from "../src/StandingRevisionRegistry.sol";
import {MockERC20} from "../src/MockERC20.sol";
import {IStandingCredentialIssuer} from "../src/interfaces/IStandingCredentialIssuer.sol";
import {AVASkeletonFixture, Actor} from "./helpers/AVASkeletonFixture.sol";

abstract contract InvariantTargetRegistry {
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

contract ChallengeLineageInvariantHandler {
    AVAStateMachine public immutable STATE_MACHINE;
    AVAChallengeWorkflow public immutable CHALLENGE_WORKFLOW;
    EvidenceCommitmentRegistry public immutable EVIDENCE_REGISTRY;
    Actor public immutable CHALLENGER_ACTOR;
    Actor public immutable EDITOR_ACTOR;
    Actor public immutable PANEL_ACTOR;
    bytes32 public immutable WORKFLOW_KEY;
    bytes32 public immutable CHALLENGER_SUBJECT;
    bytes32 public immutable EDITOR_AUTHORITY;
    bytes32 public immutable PANEL_AUTHORITY;
    uint256 public immutable RECOGNISED_STATE_ID;

    uint256[] private challengeIds;
    uint256 private evidenceNonce;
    bool public lineageViolationObserved;

    constructor(
        AVAStateMachine stateMachine,
        AVAChallengeWorkflow challengeWorkflow,
        EvidenceCommitmentRegistry evidenceRegistry,
        Actor challengerActor,
        Actor editorActor,
        Actor panelActor,
        bytes32 workflowKey,
        bytes32 challengerSubject,
        bytes32 editorAuthority,
        bytes32 panelAuthority,
        uint256 recognisedStateId
    ) {
        STATE_MACHINE = stateMachine;
        CHALLENGE_WORKFLOW = challengeWorkflow;
        EVIDENCE_REGISTRY = evidenceRegistry;
        CHALLENGER_ACTOR = challengerActor;
        EDITOR_ACTOR = editorActor;
        PANEL_ACTOR = panelActor;
        WORKFLOW_KEY = workflowKey;
        CHALLENGER_SUBJECT = challengerSubject;
        EDITOR_AUTHORITY = editorAuthority;
        PANEL_AUTHORITY = panelAuthority;
        RECOGNISED_STATE_ID = recognisedStateId;
    }

    function fileChallenge(uint256 seed) external {
        uint256 nonce = ++evidenceNonce;
        uint256 evidenceReceiptId;
        try CHALLENGER_ACTOR.registerEvidenceReceipt(
            EVIDENCE_REGISTRY,
            AVADataTypes.Role.Challenger,
            WORKFLOW_KEY,
            keccak256(abi.encode("invariant-challenge", seed, nonce)),
            "ipfs://invariant/challenge-evidence",
            "review-quality-challenge",
            0
        ) returns (
            uint256 id
        ) {
            evidenceReceiptId = id;
        } catch {
            return;
        }
        try CHALLENGER_ACTOR.fileChallenge(
            CHALLENGE_WORKFLOW,
            AVADataTypes.Role.Challenger,
            WORKFLOW_KEY,
            RECOGNISED_STATE_ID,
            CHALLENGER_SUBJECT,
            evidenceReceiptId,
            0
        ) returns (
            uint256 challengeId
        ) {
            challengeIds.push(challengeId);
        } catch {}
    }

    function screenChallenge(uint256 seed) external {
        if (challengeIds.length == 0) return;
        uint256 challengeId = challengeIds[seed % challengeIds.length];
        try EDITOR_ACTOR.screenChallenge(CHALLENGE_WORKFLOW, AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY) {}
            catch {}
    }

    function resolveChallenge(uint256 seed) external {
        if (challengeIds.length == 0) return;
        uint256 challengeId = challengeIds[seed % challengeIds.length];
        AVADataTypes.ChallengeRecord memory challenge = CHALLENGE_WORKFLOW.getChallenge(challengeId);
        if (challenge.status != AVADataTypes.ChallengeLifecycleStatus.AdmissibilityScreening) return;

        AVADataTypes.ChallengeOutcome outcome = AVADataTypes.ChallengeOutcome((seed % 4) + 1);
        AVADataTypes.RecognisedStateRecord memory beforeState = STATE_MACHINE.getRecognisedState(RECOGNISED_STATE_ID);
        AVADataTypes.RecognisedStateStatus toStatus = beforeState.status;
        if (outcome == AVADataTypes.ChallengeOutcome.Upheld) {
            toStatus = seed % 2 == 0
                ? AVADataTypes.RecognisedStateStatus.Downgraded
                : AVADataTypes.RecognisedStateStatus.Voided;
        }

        try PANEL_ACTOR.resolveChallenge(
            CHALLENGE_WORKFLOW,
            AVADataTypes.Role.Panel,
            challengeId,
            outcome,
            toStatus,
            PANEL_AUTHORITY,
            "ipfs://invariant/challenge-resolution"
        ) {
            AVADataTypes.RecognisedStateRecord memory afterState = STATE_MACHINE.getRecognisedState(RECOGNISED_STATE_ID);
            if (outcome == AVADataTypes.ChallengeOutcome.Upheld) {
                if (
                    beforeState.lastTransitionId != challenge.targetTransitionIdAtFiling
                        || afterState.lastTransitionId == beforeState.lastTransitionId
                ) {
                    lineageViolationObserved = true;
                }
            } else if (
                afterState.lastTransitionId != beforeState.lastTransitionId || afterState.status != beforeState.status
            ) {
                lineageViolationObserved = true;
            }
        } catch {}
    }

    function applyRestoration(uint256 seed) external {
        if (challengeIds.length == 0) return;
        uint256 challengeId = challengeIds[seed % challengeIds.length];
        AVADataTypes.ChallengeRecord memory challenge = CHALLENGE_WORKFLOW.getChallenge(challengeId);
        if (challenge.status != AVADataTypes.ChallengeLifecycleStatus.Resolved) return;
        AVADataTypes.ChallengeTransitionRecord memory resolution =
            CHALLENGE_WORKFLOW.getChallengeTransition(challenge.lastTransitionId);
        AVADataTypes.RecognisedStateRecord memory beforeState = STATE_MACHINE.getRecognisedState(RECOGNISED_STATE_ID);

        try PANEL_ACTOR.applyRestoration(
            CHALLENGE_WORKFLOW,
            AVADataTypes.Role.Panel,
            challengeId,
            PANEL_AUTHORITY,
            "ipfs://invariant/challenge-restoration"
        ) {
            AVADataTypes.RecognisedStateRecord memory afterState = STATE_MACHINE.getRecognisedState(RECOGNISED_STATE_ID);
            AVADataTypes.RecognisedStateStatus expectedRestorationStatus = challenge.targetStatusAtFiling
                == AVADataTypes.RecognisedStateStatus.Challengeable
                ? AVADataTypes.RecognisedStateStatus.Challengeable
                : AVADataTypes.RecognisedStateStatus.Restored;
            if (resolution.targetTransitionIdAfter != beforeState.lastTransitionId) {
                lineageViolationObserved = true;
            } else if (beforeState.status == expectedRestorationStatus) {
                if (
                    afterState.lastTransitionId != beforeState.lastTransitionId
                        || afterState.status != expectedRestorationStatus
                ) {
                    lineageViolationObserved = true;
                }
            } else {
                AVADataTypes.RecognisedStateTransitionRecord memory transition =
                    STATE_MACHINE.getRecognisedStateTransition(afterState.lastTransitionId);
                if (
                    afterState.lastTransitionId == beforeState.lastTransitionId || transition.challengeId != challengeId
                        || transition.action != AVADataTypes.Action.ApplyRestoration
                        || transition.toStatus != expectedRestorationStatus
                        || afterState.status != expectedRestorationStatus
                ) {
                    lineageViolationObserved = true;
                }
            }
        } catch {}
    }

    function closeChallenge(uint256 seed) external {
        if (challengeIds.length == 0) return;
        uint256 challengeId = challengeIds[seed % challengeIds.length];
        try PANEL_ACTOR.closeChallenge(
            CHALLENGE_WORKFLOW,
            AVADataTypes.Role.Panel,
            challengeId,
            PANEL_AUTHORITY,
            "ipfs://invariant/challenge-close"
        ) {}
            catch {}
    }

    function challengeCount() external view returns (uint256) {
        return challengeIds.length;
    }

    function challengeIdAt(uint256 index) external view returns (uint256) {
        return challengeIds[index];
    }
}

contract RecoveryInvariantHandler {
    ValueSettlementExecutor public immutable EXECUTOR;
    uint256 public immutable ORIGIN_SETTLEMENT_ID;
    uint256 public immutable PENALTY_CONSEQUENCE_ID;
    bytes32 public immutable AUTHORITY_ID;
    uint256 public obligationSuccesses;
    uint256 public terminalSuccesses;

    constructor(
        ValueSettlementExecutor executor,
        uint256 originSettlementId,
        uint256 penaltyConsequenceId,
        bytes32 authorityId
    ) {
        EXECUTOR = executor;
        ORIGIN_SETTLEMENT_ID = originSettlementId;
        PENALTY_CONSEQUENCE_ID = penaltyConsequenceId;
        AUTHORITY_ID = authorityId;
    }

    function recordRepaymentObligation() external {
        try EXECUTOR.recordRepaymentObligation(
            AVADataTypes.Role.ProtocolExecutor,
            PENALTY_CONSEQUENCE_ID,
            AUTHORITY_ID,
            "ipfs://invariant/repayment-obligation"
        ) returns (
            uint256
        ) {
            obligationSuccesses += 1;
        } catch {}
    }

    function recordTerminal(uint8 terminalKind) external {
        uint256 obligationId = EXECUTOR.repaymentObligationIdByOriginSettlementId(ORIGIN_SETTLEMENT_ID);
        if (obligationId == 0) return;
        uint8 kind = terminalKind % 4;
        if (kind == 0) {
            try EXECUTOR.recordFuturePayoutSetoff(
                AVADataTypes.Role.ProtocolExecutor, obligationId, AUTHORITY_ID, "ipfs://invariant/recovery-setoff"
            ) returns (
                uint256
            ) {
                terminalSuccesses += 1;
            } catch {}
            return;
        }
        if (kind == 1) {
            try EXECUTOR.recordWaiver(
                AVADataTypes.Role.ProtocolExecutor, obligationId, AUTHORITY_ID, "ipfs://invariant/recovery-waiver"
            ) returns (
                uint256
            ) {
                terminalSuccesses += 1;
            } catch {}
            return;
        }
        if (kind == 2) {
            try EXECUTOR.recordSatisfaction(
                AVADataTypes.Role.ProtocolExecutor, obligationId, AUTHORITY_ID, "ipfs://invariant/recovery-satisfaction"
            ) returns (
                uint256
            ) {
                terminalSuccesses += 1;
            } catch {}
            return;
        }
        try EXECUTOR.settleClawback(
            AVADataTypes.Role.ProtocolExecutor, obligationId, AUTHORITY_ID, "ipfs://invariant/recovery-clawback"
        ) returns (
            uint256
        ) {
            terminalSuccesses += 1;
        } catch {}
    }
}

contract StandingRevisionInvariantHandler {
    StandingRegistry public immutable STANDING_REGISTRY;
    StandingCredentialRegistry public immutable CREDENTIAL_REGISTRY;
    StandingRevisionRegistry public immutable REVISION_REGISTRY;
    uint256 public immutable PACKAGE_ID;
    uint256 public immutable RECOGNISED_STATE_ID;
    uint256 public immutable EVIDENCE_RECEIPT_ID;
    uint256 public immutable COMPUTATION_ID;
    uint256 public immutable CREDENTIAL_ID;
    uint256 public immutable INITIAL_REVISION;
    bytes32 public immutable SUBJECT_ID;
    bytes32 public immutable AUTHORITY_ID;
    bool public staleIssueSucceeded;

    constructor(
        StandingRegistry standingRegistry,
        StandingCredentialRegistry credentialRegistry,
        StandingRevisionRegistry revisionRegistry,
        AVADataTypes.StandingComputationRecord memory computation,
        uint256 credentialId,
        bytes32 authorityId
    ) {
        STANDING_REGISTRY = standingRegistry;
        CREDENTIAL_REGISTRY = credentialRegistry;
        REVISION_REGISTRY = revisionRegistry;
        PACKAGE_ID = computation.packageId;
        RECOGNISED_STATE_ID = computation.recognisedStateId;
        EVIDENCE_RECEIPT_ID = computation.evidenceReceiptId;
        COMPUTATION_ID = computation.id;
        CREDENTIAL_ID = credentialId;
        SUBJECT_ID = computation.subjectId;
        AUTHORITY_ID = authorityId;
        INITIAL_REVISION = revisionRegistry.currentRevision(computation.packageId, computation.subjectId);
    }

    function recordStandingUpdate(int256 deltaSeed) external {
        int256 delta = deltaSeed % 20;
        if (delta == 0) delta = 1;
        try STANDING_REGISTRY.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            RECOGNISED_STATE_ID,
            SUBJECT_ID,
            "review-procedure-weight",
            delta,
            EVIDENCE_RECEIPT_ID,
            AUTHORITY_ID,
            "ipfs://invariant/standing-update"
        ) returns (
            uint256
        ) {}
            catch {}
    }

    function attemptStaleCredentialIssue() external {
        if (REVISION_REGISTRY.currentRevision(PACKAGE_ID, SUBJECT_ID) == INITIAL_REVISION) return;
        AVADataTypes.StandingComputationRecord memory computation =
            STANDING_REGISTRY.getStandingComputationRecord(COMPUTATION_ID);
        try CREDENTIAL_REGISTRY.issueCredential(
            AVADataTypes.Role.Panel,
            IStandingCredentialIssuer.StandingCredentialInput({
                standingComputationRecordId: COMPUTATION_ID,
                categoryHash: keccak256("panel-visible-standing-category"),
                threshold: 40,
                lowerBound: 40,
                upperBound: 50,
                epoch: computation.epoch,
                expiresAt: block.timestamp + 7 days,
                computationRuleHash: computation.computationRuleHash,
                authorityId: AUTHORITY_ID,
                uri: "ipfs://invariant/stale-standing-credential"
            })
        ) returns (
            uint256
        ) {
            staleIssueSucceeded = true;
        } catch {}
    }

    function revokeCredential() external {
        try CREDENTIAL_REGISTRY.revokeCredential(
            AVADataTypes.Role.Panel, CREDENTIAL_ID, AUTHORITY_ID, "ipfs://invariant/revoke-standing-credential"
        ) {}
            catch {}
    }
}

contract AVAChallengeLineageInvariantTest is AVASkeletonFixture, InvariantTargetRegistry {
    bytes32 private constant INVARIANT_EDITOR_AUTHORITY = keccak256("invariant-editor-authority");
    bytes32 private constant INVARIANT_PANEL_AUTHORITY = keccak256("invariant-panel-authority");

    ChallengeLineageInvariantHandler private handler;
    uint256 private recognisedStateId;

    function setUp() public override {
        super.setUp();
        recognisedStateId = _createChallengeableReviewState();
        Actor editorActor = new Actor();
        Actor panelActor = new Actor();
        roleRegistry.assignRole(
            address(editorActor), AVADataTypes.Role.Editor, INVARIANT_EDITOR_AUTHORITY, "ipfs://invariant/editor"
        );
        roleRegistry.assignRole(
            address(panelActor), AVADataTypes.Role.Panel, INVARIANT_PANEL_AUTHORITY, "ipfs://invariant/panel"
        );
        handler = new ChallengeLineageInvariantHandler(
            stateMachine,
            challengeWorkflow,
            evidenceRegistry,
            challengerActor,
            editorActor,
            panelActor,
            DEFAULT_WORKFLOW,
            CHALLENGER_SUBJECT,
            INVARIANT_EDITOR_AUTHORITY,
            INVARIANT_PANEL_AUTHORITY,
            recognisedStateId
        );
        _targetContract(address(handler));
    }

    function invariantConcurrentChallengeCountAndTransitionLineageRemainConsistent() public view {
        require(!handler.lineageViolationObserved(), "stale challenge mutated recognised state");
        uint256 expectedOpenCount;
        uint256 count = handler.challengeCount();
        for (uint256 i = 0; i < count; i++) {
            AVADataTypes.ChallengeRecord memory challenge = challengeWorkflow.getChallenge(handler.challengeIdAt(i));
            if (challenge.status != AVADataTypes.ChallengeLifecycleStatus.Closed) {
                expectedOpenCount += 1;
            }
        }
        require(
            stateMachine.openChallengeCountForRecognisedState(recognisedStateId) == expectedOpenCount,
            "open challenge count drifted"
        );

        AVADataTypes.RecognisedStateRecord memory state = stateMachine.getRecognisedState(recognisedStateId);
        AVADataTypes.RecognisedStateTransitionRecord memory transition =
            stateMachine.getRecognisedStateTransition(state.lastTransitionId);
        require(transition.recognisedStateId == recognisedStateId, "last transition target mismatch");
        require(transition.toStatus == state.status, "last transition status mismatch");
        if (
            state.status == AVADataTypes.RecognisedStateStatus.Downgraded
                || state.status == AVADataTypes.RecognisedStateStatus.Voided
                || state.status == AVADataTypes.RecognisedStateStatus.Restored
        ) {
            require(transition.challengeId != 0, "high-impact state lacks challenge lineage");
            require(
                transition.action == AVADataTypes.Action.ResolveChallenge
                    || transition.action == AVADataTypes.Action.ApplyRestoration,
                "high-impact state used non-challenge transition"
            );
        }
    }
}

contract AVARecoveryInvariantTest is AVASkeletonFixture, InvariantTargetRegistry {
    bytes32 private constant INVARIANT_EXECUTOR_AUTHORITY = keccak256("invariant-executor-authority");

    RecoveryInvariantHandler private handler;
    uint256 private originSettlementId;

    function setUp() public override {
        super.setUp();
        bytes32 workflowKey = keccak256("invariant-recovery-workflow");
        MockERC20 token = _m421FundedToken(100);
        uint256 penaltyId;
        (, originSettlementId, penaltyId,) =
            _createM425BoundRecoveryPenalty(workflowKey, "invariant-recovery", token, 8);
        handler = new RecoveryInvariantHandler(
            valueSettlementExecutor, originSettlementId, penaltyId, INVARIANT_EXECUTOR_AUTHORITY
        );
        roleRegistry.assignRole(
            address(handler),
            AVADataTypes.Role.ProtocolExecutor,
            INVARIANT_EXECUTOR_AUTHORITY,
            "ipfs://invariant/executor"
        );
        _targetContract(address(handler));
    }

    function invariantRecoveryHasAtMostOneObligationAndOneTerminalSettlement() public view {
        require(handler.obligationSuccesses() <= 1, "duplicate repayment obligation succeeded");
        require(handler.terminalSuccesses() <= 1, "duplicate recovery terminal succeeded");

        uint256 obligationId = valueSettlementExecutor.repaymentObligationIdByOriginSettlementId(originSettlementId);
        if (obligationId == 0) return;
        AVADataTypes.ValueSettlementRecord memory origin =
            valueSettlementExecutor.getValueSettlement(originSettlementId);
        AVADataTypes.ValueSettlementRecord memory obligation = valueSettlementExecutor.getValueSettlement(obligationId);
        require(obligation.kind == AVADataTypes.ValueSettlementKind.RepaymentObligation, "wrong obligation kind");
        require(obligation.originSettlementId == originSettlementId, "obligation origin mismatch");
        require(obligation.amountOrUnits == origin.amountOrUnits, "obligation exceeds origin");
        require(obligation.packageId == origin.packageId, "obligation package mismatch");
        require(obligation.recognisedStateId == origin.recognisedStateId, "obligation recognised state mismatch");
        require(obligation.subjectId == origin.subjectId, "obligation subject mismatch");

        AVADataTypes.ValueSettlementStatus terminalStatus =
            valueSettlementExecutor.recoveryTerminalStatusByObligationId(obligationId);
        uint256 terminalId = valueSettlementExecutor.recoveryTerminalSettlementIdByObligationId(obligationId);
        if (terminalStatus == AVADataTypes.ValueSettlementStatus.None) {
            require(terminalId == 0, "terminal id exists without status");
            return;
        }
        require(terminalId != 0, "terminal status lacks record");
        AVADataTypes.ValueSettlementRecord memory terminal = valueSettlementExecutor.getValueSettlement(terminalId);
        require(terminal.status == terminalStatus, "terminal status mismatch");
        require(terminal.repaymentObligationId == obligationId, "terminal obligation mismatch");
        require(terminal.originSettlementId == originSettlementId, "terminal origin mismatch");
        require(terminal.amountOrUnits == origin.amountOrUnits, "terminal exceeds origin");
    }
}

contract AVAStandingRevisionInvariantTest is AVASkeletonFixture, InvariantTargetRegistry {
    bytes32 private constant INVARIANT_PANEL_AUTHORITY = keccak256("invariant-standing-panel-authority");

    StandingRevisionInvariantHandler private handler;
    uint256 private computationId;
    uint256 private credentialId;
    uint256 private initialRevision;

    function setUp() public override {
        super.setUp();
        computationId = _createM422StandingComputationRecord("invariant-standing", 42);
        credentialId = _issueM422StandingCredential(computationId, "invariant-standing", block.timestamp + 30 days);
        AVADataTypes.StandingComputationRecord memory computation =
            standingRegistry.getStandingComputationRecord(computationId);
        initialRevision = computation.standingRevision;
        handler = new StandingRevisionInvariantHandler(
            standingRegistry,
            standingCredentialRegistry,
            standingRevisionRegistry,
            computation,
            credentialId,
            INVARIANT_PANEL_AUTHORITY
        );
        roleRegistry.assignRole(
            address(handler), AVADataTypes.Role.Panel, INVARIANT_PANEL_AUTHORITY, "ipfs://invariant/standing-panel"
        );
        _targetContract(address(handler));
    }

    function invariantStandingRevisionInvalidatesOldComputationAndCredential() public view {
        AVADataTypes.StandingComputationRecord memory computation =
            standingRegistry.getStandingComputationRecord(computationId);
        uint256 currentRevision = standingRevisionRegistry.currentRevision(computation.packageId, computation.subjectId);
        if (currentRevision == initialRevision) return;

        require(!standingRegistry.isStandingComputationActive(computationId), "stale computation remains active");
        require(!standingCredentialRegistry.isCredentialActive(credentialId), "stale credential remains active");
        require(
            !standingCredentialRegistry.credentialProvesSubjectStanding(
                credentialId,
                computation.packageId,
                computation.subjectId,
                computation.vectorKey,
                keccak256("panel-visible-standing-category"),
                40
            ),
            "stale credential still proves standing"
        );
        require(!handler.staleIssueSucceeded(), "stale computation reissued credential");
    }
}
