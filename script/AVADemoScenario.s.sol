// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../src/AVADataTypes.sol";
import {AVAApplicationRegistry} from "../src/AVAApplicationRegistry.sol";
import {RoleIdentityRegistry} from "../src/RoleIdentityRegistry.sol";
import {AuthorityMatrix} from "../src/AuthorityMatrix.sol";
import {EvidenceCommitmentRegistry} from "../src/EvidenceCommitmentRegistry.sol";
import {DisclosurePolicyRegistry} from "../src/DisclosurePolicyRegistry.sol";
import {AVAStateMachine} from "../src/AVAStateMachine.sol";
import {AVAChallengeWorkflow} from "../src/AVAChallengeWorkflow.sol";
import {AVAWorkflowValidator} from "../src/AVAWorkflowValidator.sol";
import {RulePackageIdentityVerifier} from "../src/RulePackageIdentityVerifier.sol";
import {
    AVARulePackageRegistry,
    IEvidenceReceiptReader,
    IRecognisedStateReader
} from "../src/AVARulePackageRegistry.sol";
import {AVARulePackageLifecycleRegistry} from "../src/AVARulePackageLifecycleRegistry.sol";
import {ConsequenceExecutor} from "../src/ConsequenceExecutor.sol";
import {StandingRegistry} from "../src/StandingRegistry.sol";
import {StandingRevisionRegistry} from "../src/StandingRevisionRegistry.sol";
import {AllocationExecutor} from "../src/AllocationExecutor.sol";
import {AttestationAuditModule} from "../src/AttestationAuditModule.sol";
import {DefaultDisclosurePolicyModule} from "../src/modules/DefaultDisclosurePolicyModule.sol";
import {DefaultApplicationModule} from "../src/modules/DefaultApplicationModule.sol";
import {DefaultAttributionModule} from "../src/modules/DefaultAttributionModule.sol";
import {DefaultVerificationModule} from "../src/modules/DefaultVerificationModule.sol";
import {DefaultTransitionRuleModule} from "../src/modules/DefaultTransitionRuleModule.sol";
import {DefaultAllocationAdapter} from "../src/modules/DefaultAllocationAdapter.sol";
import {DefaultConsequenceAdapter} from "../src/modules/DefaultConsequenceAdapter.sol";
import {DefaultStandingAdapter} from "../src/modules/DefaultStandingAdapter.sol";
import {DefaultRewardAdapter} from "../src/modules/DefaultRewardAdapter.sol";
import {DefaultPriorityAdapter} from "../src/modules/DefaultPriorityAdapter.sol";
import {DefaultPenaltyAdapter} from "../src/modules/DefaultPenaltyAdapter.sol";
import {DefaultRestorationAdapter} from "../src/modules/DefaultRestorationAdapter.sol";
import {DefaultChallengeLifecycleModule} from "../src/modules/DefaultChallengeLifecycleModule.sol";
import {
    DefaultEvidencePolicyModule,
    DefaultAuditAdapter,
    DefaultEditorialSystemAdapter,
    DefaultResidualEditorialAuthorityModule,
    DefaultFieldPolicyModule,
    DefaultAntiAbuseModule
} from "../src/modules/DefaultInfrastructureModules.sol";
import {
    DefaultValueExecutionAdapter,
    DefaultStandingComputationModule,
    DefaultRulePackageLifecycleModule,
    DefaultEvidenceLifecycleModule,
    DefaultDisclosureLifecycleModule
} from "../src/modules/DefaultFutureProofModules.sol";
import {DefaultDisclosureExecutionModule} from "../src/modules/DefaultExecutionModules.sol";

interface IAVAScriptVm {
    function warp(uint256 timestamp) external;
}

contract DemoActor {
    bytes32 private constant PEER_REVIEW_APP_ID = keccak256("peer-review-app");
    bytes32 private constant DEFAULT_WORKFLOW = keccak256("demo-review-workflow");

    function registerEvidenceReceipt(
        EvidenceCommitmentRegistry registry,
        AVADataTypes.Role actingRole,
        bytes32 commitment,
        string calldata uri,
        string calldata evidenceType,
        uint256 disclosurePolicyId
    ) external returns (uint256) {
        return registry.registerEvidenceReceipt(
            actingRole, PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW, commitment, uri, evidenceType, disclosurePolicyId
        );
    }

    function registerManuscript(
        AVAStateMachine stateMachine,
        AVADataTypes.Role actingRole,
        bytes32 offchainRef,
        string calldata uri
    ) external returns (uint256) {
        return stateMachine.registerManuscript(actingRole, PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW, offchainRef, uri, "");
    }

    function registerDisclosurePolicy(
        DisclosurePolicyRegistry registry,
        AVADataTypes.Role actingRole,
        string calldata label,
        string calldata uri
    ) external returns (uint256) {
        return registry.registerDisclosurePolicy(actingRole, PEER_REVIEW_APP_ID, label, uri);
    }

    function registerReviewContribution(
        AVAStateMachine stateMachine,
        AVADataTypes.Role actingRole,
        uint256 manuscriptId,
        bytes32 reviewerSubjectId,
        uint256 evidenceReceiptId,
        uint256 disclosurePolicyId
    ) external returns (uint256) {
        return stateMachine.registerReviewContribution(
            actingRole,
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            manuscriptId,
            reviewerSubjectId,
            evidenceReceiptId,
            disclosurePolicyId
        );
    }

    function provisionallyRecogniseReview(
        AVAStateMachine stateMachine,
        AVADataTypes.Role actingRole,
        uint256 reviewContributionId,
        bytes32 authorityId
    ) external returns (uint256) {
        return stateMachine.provisionallyRecogniseReview(actingRole, reviewContributionId, authorityId);
    }

    function openReviewChallengeWindow(
        AVAStateMachine stateMachine,
        AVADataTypes.Role actingRole,
        uint256 reviewContributionId,
        bytes32 authorityId
    ) external {
        stateMachine.openReviewChallengeWindow(actingRole, reviewContributionId, authorityId);
    }

    function fileChallenge(
        AVAChallengeWorkflow challengeWorkflow,
        AVADataTypes.Role actingRole,
        uint256 challengedRecognisedStateId,
        bytes32 challengerSubjectId,
        uint256 evidenceReceiptId,
        uint256 disclosurePolicyId
    ) external returns (uint256) {
        return challengeWorkflow.fileChallenge(
            actingRole,
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            challengedRecognisedStateId,
            challengerSubjectId,
            evidenceReceiptId,
            disclosurePolicyId
        );
    }

    function screenChallenge(
        AVAChallengeWorkflow challengeWorkflow,
        AVADataTypes.Role actingRole,
        uint256 challengeId,
        bytes32 authorityId
    ) external {
        challengeWorkflow.screenChallenge(actingRole, challengeId, authorityId);
    }

    function resolveChallenge(
        AVAChallengeWorkflow challengeWorkflow,
        AVADataTypes.Role actingRole,
        uint256 challengeId,
        AVADataTypes.ChallengeOutcome outcome,
        AVADataTypes.RecognisedStateStatus toStatus,
        bytes32 authorityId,
        string calldata reasonURI
    ) external {
        challengeWorkflow.resolveChallenge(actingRole, challengeId, outcome, toStatus, authorityId, reasonURI);
    }

    function recordStandingUpdate(
        StandingRegistry registry,
        AVADataTypes.Role actingRole,
        uint256 recognisedStateId,
        bytes32 subjectId,
        string calldata dimension,
        int256 delta,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256) {
        return registry.recordStandingUpdate(
            actingRole, recognisedStateId, subjectId, dimension, delta, evidenceReceiptId, authorityId, uri
        );
    }

    function registerConsequence(
        ConsequenceExecutor executor,
        AVADataTypes.Role actingRole,
        uint256 recognisedStateId,
        AVADataTypes.ConsequenceKind kind,
        bytes32 subjectId,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256) {
        return executor.registerConsequence(
            actingRole, recognisedStateId, kind, subjectId, evidenceReceiptId, authorityId, uri
        );
    }

    function registerRecognisedState(
        AVAStateMachine stateMachine,
        AVADataTypes.Role actingRole,
        bytes32 workflowKey,
        AVADataTypes.AVAStage stage,
        bytes32 objectId,
        bytes32 subjectId,
        uint256 evidenceReceiptId,
        uint256 disclosurePolicyId,
        bytes32 authorityId,
        AVADataTypes.RecognisedStateStatus status
    ) external returns (uint256) {
        return stateMachine.registerRecognisedState(
            actingRole,
            PEER_REVIEW_APP_ID,
            workflowKey,
            stage,
            objectId,
            subjectId,
            evidenceReceiptId,
            disclosurePolicyId,
            authorityId,
            status
        );
    }

    function transitionRecognisedState(
        AVAStateMachine stateMachine,
        AVADataTypes.Role actingRole,
        uint256 recognisedStateId,
        AVADataTypes.RecognisedStateStatus toStatus,
        bytes32 authorityId,
        string calldata reasonURI
    ) external returns (uint256) {
        return stateMachine.transitionRecognisedState(actingRole, recognisedStateId, toStatus, authorityId, reasonURI);
    }

    function vestReviewRecognition(
        AVAStateMachine stateMachine,
        AVADataTypes.Role actingRole,
        uint256 reviewContributionId,
        bytes32 authorityId,
        string calldata reasonURI
    ) external returns (uint256) {
        return stateMachine.vestReviewRecognition(actingRole, reviewContributionId, authorityId, reasonURI);
    }

    function applyRestoration(
        AVAChallengeWorkflow challengeWorkflow,
        AVADataTypes.Role actingRole,
        uint256 challengeId,
        bytes32 authorityId,
        string calldata reasonURI
    ) external {
        challengeWorkflow.applyRestoration(actingRole, challengeId, authorityId, reasonURI);
    }

    function closeChallenge(
        AVAChallengeWorkflow challengeWorkflow,
        AVADataTypes.Role actingRole,
        uint256 challengeId,
        bytes32 authorityId,
        string calldata reasonURI
    ) external {
        challengeWorkflow.closeChallenge(actingRole, challengeId, authorityId, reasonURI);
    }

    function executeAllocation(
        AllocationExecutor executor,
        AVADataTypes.Role actingRole,
        uint256 recognisedStateId,
        AVADataTypes.AllocationKind allocationKind,
        bytes32 subjectId,
        uint256 amountOrUnits,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256) {
        return executor.executeAllocation(
            actingRole, recognisedStateId, allocationKind, subjectId, amountOrUnits, evidenceReceiptId, authorityId, uri
        );
    }

    function recordPenalty(
        ConsequenceExecutor executor,
        AVADataTypes.Role actingRole,
        uint256 recognisedStateId,
        uint256 challengeId,
        AVADataTypes.GovernanceFindingKind findingKind,
        bytes32 subjectId,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256) {
        return executor.recordPenalty(
            actingRole,
            AVADataTypes.PenaltyConsequenceContext({
                challengeId: challengeId, findingKind: findingKind, originSettlementId: 0
            }),
            AVADataTypes.ValueExecutionContext({
                recognisedStateId: recognisedStateId,
                asset: address(0),
                payer: address(0),
                recipientSubjectId: subjectId,
                amount: 1,
                mode: AVADataTypes.ValueExecutionMode.RecordOnly,
                settlementKind: AVADataTypes.ValueSettlementKind.None,
                executionReference: keccak256(bytes(uri)),
                authorityId: authorityId,
                evidenceReceiptId: evidenceReceiptId,
                uri: uri,
                actor: address(this)
            })
        );
    }

    function recordStandingPenaltyInput(
        ConsequenceExecutor executor,
        AVADataTypes.Role actingRole,
        uint256 penaltyConsequenceId,
        string calldata dimension,
        int256 delta,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256) {
        return executor.recordStandingPenaltyInput(
            actingRole, penaltyConsequenceId, dimension, delta, evidenceReceiptId, authorityId, uri
        );
    }

    function recordEligibilityRestriction(
        ConsequenceExecutor executor,
        AVADataTypes.Role actingRole,
        uint256 penaltyConsequenceId,
        AVADataTypes.EligibilityRestrictionKind restrictionKind,
        uint256 expiresAt,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256) {
        return executor.recordEligibilityRestriction(
            actingRole, penaltyConsequenceId, restrictionKind, expiresAt, evidenceReceiptId, authorityId, uri
        );
    }

    function recordAttestation(
        AttestationAuditModule module,
        AttestationAuditModule.AttestationContext calldata context,
        string calldata attestationType,
        string calldata uri
    ) external returns (uint256) {
        return module.recordAttestation(
            context.actingRole,
            context.workflowKey,
            context.action,
            context.objectId,
            context.evidenceReceiptId,
            context.attestationHash,
            context.authorityId,
            attestationType,
            uri
        );
    }

    function registerRulePackage(
        AVARulePackageRegistry registry,
        AVADataTypes.Role actingRole,
        bytes32 workflowKey,
        AVARulePackageRegistry.RulePackageModules calldata modules,
        string calldata uri
    ) external {
        registry.registerRulePackage(actingRole, PEER_REVIEW_APP_ID, workflowKey, modules, uri);
    }
}

contract AVADemoScenario {
    IAVAScriptVm internal constant SCRIPT_VM = IAVAScriptVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    bytes32 private constant AUTHOR_SUBJECT = keccak256("demo-author");
    bytes32 private constant REVIEWER_SUBJECT = keccak256("demo-reviewer");
    bytes32 private constant CHALLENGER_SUBJECT = keccak256("demo-challenger");
    bytes32 private constant EDITOR_SUBJECT = keccak256("demo-editor");
    bytes32 private constant PANEL_SUBJECT = keccak256("demo-panel");
    bytes32 private constant EXECUTOR_SUBJECT = keccak256("demo-executor");
    bytes32 private constant EDITOR_AUTHORITY = keccak256("demo-editor-authority");
    bytes32 private constant PANEL_AUTHORITY = keccak256("demo-panel-authority");
    bytes32 private constant EXECUTOR_AUTHORITY = keccak256("demo-executor-authority");
    bytes32 private constant PEER_REVIEW_APP_ID = keccak256("peer-review-app");
    bytes32 private constant DEFAULT_WORKFLOW = keccak256("demo-review-workflow");

    RoleIdentityRegistry public roleRegistry;
    AuthorityMatrix public authorityMatrix;
    AVAApplicationRegistry public applicationRegistry;
    DefaultApplicationModule public applicationModule;
    DefaultDisclosurePolicyModule public disclosurePolicyModule;
    EvidenceCommitmentRegistry public evidenceRegistry;
    DisclosurePolicyRegistry public disclosureRegistry;
    AVAStateMachine public stateMachine;
    AVAChallengeWorkflow public challengeWorkflow;
    AVAWorkflowValidator public workflowValidator;
    AVARulePackageRegistry public rulePackageRegistry;
    AVARulePackageLifecycleRegistry public rulePackageLifecycleRegistry;
    DefaultAttributionModule public attributionModule;
    DefaultVerificationModule public verificationModule;
    DefaultTransitionRuleModule public transitionRuleModule;
    DefaultAllocationAdapter public allocationAdapter;
    DefaultConsequenceAdapter public consequenceAdapter;
    DefaultStandingAdapter public standingAdapter;
    DefaultRewardAdapter public rewardAdapter;
    DefaultPriorityAdapter public priorityAdapter;
    DefaultPenaltyAdapter public penaltyAdapter;
    DefaultRestorationAdapter public restorationAdapter;
    DefaultChallengeLifecycleModule public challengeLifecycleModule;
    DefaultEvidencePolicyModule public evidencePolicyModule;
    DefaultAuditAdapter public auditAdapter;
    DefaultEditorialSystemAdapter public editorialSystemAdapter;
    DefaultResidualEditorialAuthorityModule public residualEditorialAuthorityModule;
    DefaultFieldPolicyModule public fieldPolicyModule;
    DefaultAntiAbuseModule public antiAbuseModule;
    DefaultValueExecutionAdapter public valueExecutionAdapter;
    DefaultStandingComputationModule public standingComputationModule;
    DefaultRulePackageLifecycleModule public rulePackageLifecycleModule;
    DefaultEvidenceLifecycleModule public evidenceLifecycleModule;
    DefaultDisclosureLifecycleModule public disclosureLifecycleModule;
    DefaultDisclosureExecutionModule public disclosureExecutionModule;
    ConsequenceExecutor public consequenceExecutor;
    StandingRegistry public standingRegistry;
    StandingRevisionRegistry public standingRevisionRegistry;
    AllocationExecutor public allocationExecutor;
    AttestationAuditModule public auditModule;
    DemoActor public demoActor;
    DemoActor public editorDemoActor;
    DemoActor public challengerDemoActor;
    DemoActor public panelDemoActor;

    event DemoCompleted(
        uint256 manuscriptId,
        uint256 reviewContributionId,
        uint256 challengeId,
        uint256 consequenceId,
        uint256 standingUpdateId,
        uint256 allocationExecutionId
    );

    function _advancePastMinimumChallengeWindow() internal {
        SCRIPT_VM.warp(block.timestamp + stateMachine.minimumChallengeWindowDuration());
    }

    function run()
        external
        returns (
            uint256 manuscriptId,
            uint256 recognisedStateId,
            uint256 challengeId,
            uint256 consequenceId,
            uint256 standingUpdateId,
            uint256 allocationExecutionId
        )
    {
        _deployAndConfigure();

        uint256 disclosurePolicyId = editorDemoActor.registerDisclosurePolicy(
            disclosureRegistry,
            AVADataTypes.Role.Editor,
            "editor-visible-sealed-review",
            "ipfs://demo/disclosure-policy"
        );
        uint256 reviewEvidenceId = demoActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("demo-sealed-review"),
            "ipfs://demo/encrypted-review",
            "review-service-occurrence",
            disclosurePolicyId
        );

        manuscriptId = demoActor.registerManuscript(
            stateMachine, AVADataTypes.Role.Author, keccak256("demo-manuscript"), "ipfs://demo/manuscript"
        );
        uint256 reviewContributionId = demoActor.registerReviewContribution(
            stateMachine,
            AVADataTypes.Role.Reviewer,
            manuscriptId,
            REVIEWER_SUBJECT,
            reviewEvidenceId,
            disclosurePolicyId
        );
        _assertNoAutomaticOutputs();

        recognisedStateId = editorDemoActor.provisionallyRecogniseReview(
            stateMachine, AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY
        );
        editorDemoActor.openReviewChallengeWindow(
            stateMachine, AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY
        );

        uint256 challengeEvidenceId = challengerDemoActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256("demo-sealed-challenge"),
            "ipfs://demo/encrypted-challenge",
            "review-quality-challenge",
            disclosurePolicyId
        );
        challengeId = challengerDemoActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            disclosurePolicyId
        );
        _assertNoAutomaticOutputs();

        editorDemoActor.screenChallenge(challengeWorkflow, AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        panelDemoActor.resolveChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            PANEL_AUTHORITY,
            "ipfs://demo/upheld-reason"
        );

        consequenceId = panelDemoActor.registerConsequence(
            consequenceExecutor,
            AVADataTypes.Role.Panel,
            recognisedStateId,
            AVADataTypes.ConsequenceKind.ProcedureCorrection,
            REVIEWER_SUBJECT,
            challengeEvidenceId,
            PANEL_AUTHORITY,
            "ipfs://demo/bounded-consequence"
        );
        standingUpdateId = panelDemoActor.recordStandingUpdate(
            standingRegistry,
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            "review-procedure-weight",
            -1,
            challengeEvidenceId,
            PANEL_AUTHORITY,
            "ipfs://demo/standing-update"
        );

        allocationExecutionId = _executeAllocation(disclosurePolicyId);
        panelDemoActor.recordAttestation(
            auditModule,
            AttestationAuditModule.AttestationContext({
                actingRole: AVADataTypes.Role.Panel,
                workflowKey: DEFAULT_WORKFLOW,
                targetKind: AVADataTypes.AttestationTargetKind.EvidenceReceipt,
                action: AVADataTypes.Action.RecordAttestation,
                objectId: bytes32(challengeEvidenceId),
                evidenceReceiptId: challengeEvidenceId,
                attestationHash: keccak256("demo-transition-audit"),
                authorityId: PANEL_AUTHORITY
            }),
            "demo-transition-audit",
            "ipfs://demo/audit"
        );

        emit DemoCompleted(
            manuscriptId, reviewContributionId, challengeId, consequenceId, standingUpdateId, allocationExecutionId
        );
    }

    function _deployAndConfigure() internal {
        roleRegistry = new RoleIdentityRegistry();
        authorityMatrix = new AuthorityMatrix(roleRegistry);
        applicationRegistry = new AVAApplicationRegistry();
        applicationRegistry.registerApplication(
            PEER_REVIEW_APP_ID,
            keccak256("peer-review-application-identity-v1"),
            keccak256("peer-review-application-authority"),
            "ipfs://peer-review-application"
        );
        applicationModule = new DefaultApplicationModule(PEER_REVIEW_APP_ID);
        disclosureRegistry = new DisclosurePolicyRegistry(authorityMatrix, applicationRegistry);
        disclosurePolicyModule = new DefaultDisclosurePolicyModule(disclosureRegistry);
        rulePackageRegistry =
            new AVARulePackageRegistry(authorityMatrix, applicationRegistry, new RulePackageIdentityVerifier());
        evidenceRegistry = new EvidenceCommitmentRegistry(
            authorityMatrix, disclosurePolicyModule, disclosureRegistry, rulePackageRegistry
        );
        attributionModule = new DefaultAttributionModule();
        verificationModule = new DefaultVerificationModule();
        transitionRuleModule = new DefaultTransitionRuleModule();
        workflowValidator = new AVAWorkflowValidator(rulePackageRegistry, evidenceRegistry, disclosureRegistry);
        standingRevisionRegistry = new StandingRevisionRegistry(authorityMatrix, rulePackageRegistry, evidenceRegistry);
        stateMachine = new AVAStateMachine(
            authorityMatrix, rulePackageRegistry, workflowValidator, standingRevisionRegistry, 1 days
        );
        challengeWorkflow = new AVAChallengeWorkflow(
            authorityMatrix, rulePackageRegistry, workflowValidator, stateMachine, standingRevisionRegistry
        );
        stateMachine.bindChallengeWorkflow(address(challengeWorkflow));
        rulePackageLifecycleRegistry = new AVARulePackageLifecycleRegistry(
            authorityMatrix,
            rulePackageRegistry,
            disclosureRegistry,
            IRecognisedStateReader(address(stateMachine)),
            IEvidenceReceiptReader(address(evidenceRegistry))
        );
        allocationAdapter = new DefaultAllocationAdapter();
        consequenceAdapter = new DefaultConsequenceAdapter();
        standingAdapter = new DefaultStandingAdapter();
        rewardAdapter = new DefaultRewardAdapter();
        priorityAdapter = new DefaultPriorityAdapter();
        penaltyAdapter = new DefaultPenaltyAdapter(100, 30 days);
        restorationAdapter = new DefaultRestorationAdapter();
        challengeLifecycleModule = new DefaultChallengeLifecycleModule();
        evidencePolicyModule = new DefaultEvidencePolicyModule();
        auditAdapter = new DefaultAuditAdapter();
        editorialSystemAdapter = new DefaultEditorialSystemAdapter();
        residualEditorialAuthorityModule = new DefaultResidualEditorialAuthorityModule();
        fieldPolicyModule = new DefaultFieldPolicyModule();
        antiAbuseModule = new DefaultAntiAbuseModule();
        valueExecutionAdapter = new DefaultValueExecutionAdapter();
        standingComputationModule = new DefaultStandingComputationModule();
        rulePackageLifecycleModule = new DefaultRulePackageLifecycleModule();
        evidenceLifecycleModule = new DefaultEvidenceLifecycleModule();
        disclosureLifecycleModule = new DefaultDisclosureLifecycleModule(disclosureRegistry);
        disclosureExecutionModule = new DefaultDisclosureExecutionModule();
        consequenceExecutor = new ConsequenceExecutor(
            authorityMatrix,
            stateMachine,
            challengeWorkflow,
            rulePackageRegistry,
            evidenceRegistry,
            standingRevisionRegistry
        );
        standingRegistry = new StandingRegistry(
            authorityMatrix, stateMachine, rulePackageRegistry, evidenceRegistry, standingRevisionRegistry
        );
        standingRevisionRegistry.bindWriter(StandingRevisionRegistry.WriterKind.StateMachine, address(stateMachine));
        standingRevisionRegistry.bindWriter(
            StandingRevisionRegistry.WriterKind.ChallengeWorkflow, address(challengeWorkflow)
        );
        standingRevisionRegistry.bindWriter(
            StandingRevisionRegistry.WriterKind.StandingRegistry, address(standingRegistry)
        );
        standingRevisionRegistry.bindWriter(
            StandingRevisionRegistry.WriterKind.ConsequenceExecutor, address(consequenceExecutor)
        );
        allocationExecutor =
            new AllocationExecutor(authorityMatrix, stateMachine, rulePackageRegistry, evidenceRegistry);
        auditModule = new AttestationAuditModule(
            authorityMatrix, rulePackageRegistry, evidenceRegistry, stateMachine, challengeWorkflow
        );
        demoActor = new DemoActor();
        editorDemoActor = new DemoActor();
        challengerDemoActor = new DemoActor();
        panelDemoActor = new DemoActor();

        _assignRoles();
        _setPermissions();
        _registerRulePackage();
    }

    function _assignRoles() internal {
        roleRegistry.assignRole(address(demoActor), AVADataTypes.Role.Author, AUTHOR_SUBJECT, "ipfs://demo/author");
        roleRegistry.assignRole(
            address(demoActor), AVADataTypes.Role.Reviewer, REVIEWER_SUBJECT, "ipfs://demo/reviewer"
        );
        roleRegistry.assignRole(
            address(challengerDemoActor), AVADataTypes.Role.Challenger, CHALLENGER_SUBJECT, "ipfs://demo/challenger"
        );
        roleRegistry.assignRole(
            address(editorDemoActor), AVADataTypes.Role.Editor, EDITOR_AUTHORITY, "ipfs://demo/editor"
        );
        roleRegistry.assignRole(address(panelDemoActor), AVADataTypes.Role.Panel, PANEL_AUTHORITY, "ipfs://demo/panel");
        roleRegistry.assignRole(
            address(demoActor), AVADataTypes.Role.ProtocolExecutor, EXECUTOR_AUTHORITY, "ipfs://demo/executor"
        );
    }

    function _setPermissions() internal {
        authorityMatrix.setPermission(AVADataTypes.Role.Author, AVADataTypes.Action.RegisterManuscript, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Reviewer, AVADataTypes.Action.RegisterEvidence, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Challenger, AVADataTypes.Action.RegisterEvidence, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Editor, AVADataTypes.Action.RegisterEvidence, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Editor, AVADataTypes.Action.RegisterDisclosurePolicy, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Editor, AVADataTypes.Action.RegisterRecognisedState, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Reviewer, AVADataTypes.Action.RegisterReviewContribution, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Editor, AVADataTypes.Action.ProvisionallyRecogniseReview, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Editor, AVADataTypes.Action.OpenChallengeWindow, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Challenger, AVADataTypes.Action.FileChallenge, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Editor, AVADataTypes.Action.ScreenChallenge, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Panel, AVADataTypes.Action.ResolveChallenge, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Panel, AVADataTypes.Action.RegisterConsequence, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Panel, AVADataTypes.Action.RecordStandingUpdate, true);
        authorityMatrix.setPermission(AVADataTypes.Role.ProtocolExecutor, AVADataTypes.Action.ExecuteAllocation, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Panel, AVADataTypes.Action.RecordAttestation, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Panel, AVADataTypes.Action.TransitionRecognisedState, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Panel, AVADataTypes.Action.RegisterRulePackage, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Panel, AVADataTypes.Action.RecordDisclosureLifecycle, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Reviewer, AVADataTypes.Action.RecordEvidenceLifecycle, true);
    }

    function _registerRulePackage() internal {
        AVARulePackageRegistry.RulePackageModules memory modules = _demoRulePackageModules();
        panelDemoActor.registerRulePackage(
            rulePackageRegistry, AVADataTypes.Role.Panel, DEFAULT_WORKFLOW, modules, "ipfs://demo/default-rule-package"
        );
    }

    function _demoRulePackageModules()
        internal
        view
        returns (AVARulePackageRegistry.RulePackageModules memory modules)
    {
        modules.applicationModule = applicationModule;
        modules.attributionModule = attributionModule;
        modules.verificationModule = verificationModule;
        modules.allocationModule = allocationAdapter;
        modules.transitionRuleModule = transitionRuleModule;
        modules.disclosureModule = disclosurePolicyModule;
        modules.standingAdapter = standingAdapter;
        modules.consequenceAdapter = consequenceAdapter;
        modules.rewardAdapter = rewardAdapter;
        modules.priorityAdapter = priorityAdapter;
        modules.penaltyAdapter = penaltyAdapter;
        modules.restorationAdapter = restorationAdapter;
        modules.challengeLifecycleModule = challengeLifecycleModule;
        modules.evidencePolicyModule = evidencePolicyModule;
        modules.auditAdapter = auditAdapter;
        modules.editorialSystemAdapter = editorialSystemAdapter;
        modules.residualEditorialAuthorityModule = residualEditorialAuthorityModule;
        modules.fieldPolicyModule = fieldPolicyModule;
        modules.antiAbuseModule = antiAbuseModule;
        modules.valueExecutionAdapter = valueExecutionAdapter;
        modules.standingComputationModule = standingComputationModule;
        modules.rulePackageLifecycleModule = rulePackageLifecycleModule;
        modules.evidenceLifecycleModule = evidenceLifecycleModule;
        modules.disclosureLifecycleModule = disclosureLifecycleModule;
        modules.disclosureExecutionModule = disclosureExecutionModule;
        modules.version = 1;
        modules.compatibilityKey = keccak256("ava-m4-10-compatible");
        modules.dependencyURI = "";
    }

    function _executeAllocation(uint256 disclosurePolicyId) internal returns (uint256 allocationExecutionId) {
        uint256 allocationEvidenceId = editorDemoActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Editor,
            keccak256("demo-allocation-evidence"),
            "ipfs://demo/allocation-evidence",
            "allocation-basis",
            disclosurePolicyId
        );
        uint256 allocationStateId = editorDemoActor.registerRecognisedState(
            stateMachine,
            AVADataTypes.Role.Editor,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Allocation,
            keccak256("demo-allocation-object"),
            REVIEWER_SUBJECT,
            allocationEvidenceId,
            disclosurePolicyId,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        );
        panelDemoActor.transitionRecognisedState(
            stateMachine,
            AVADataTypes.Role.Panel,
            allocationStateId,
            AVADataTypes.RecognisedStateStatus.Vested,
            PANEL_AUTHORITY,
            "ipfs://demo/allocation-state-transition"
        );

        allocationExecutionId = demoActor.executeAllocation(
            allocationExecutor,
            AVADataTypes.Role.ProtocolExecutor,
            allocationStateId,
            AVADataTypes.AllocationKind.OperationalAllowance,
            REVIEWER_SUBJECT,
            1,
            allocationEvidenceId,
            EXECUTOR_AUTHORITY,
            "ipfs://demo/allocation-execution"
        );
    }

    function _assertNoAutomaticOutputs() internal view {
        require(standingRegistry.nextStandingUpdateId() == 1, "unexpected standing update");
        require(consequenceExecutor.nextConsequenceId() == 1, "unexpected consequence");
        require(allocationExecutor.nextAllocationExecutionId() == 1, "unexpected allocation");
    }
}
