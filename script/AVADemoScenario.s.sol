// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../src/AVADataTypes.sol";
import {RoleIdentityRegistry} from "../src/RoleIdentityRegistry.sol";
import {AuthorityMatrix} from "../src/AuthorityMatrix.sol";
import {EvidenceCommitmentRegistry} from "../src/EvidenceCommitmentRegistry.sol";
import {DisclosurePolicyRegistry} from "../src/DisclosurePolicyRegistry.sol";
import {AVAStateMachine} from "../src/AVAStateMachine.sol";
import {
    AVARulePackageRegistry,
    IEvidenceReceiptReader,
    IRecognisedStateReader
} from "../src/AVARulePackageRegistry.sol";
import {ConsequenceExecutor} from "../src/ConsequenceExecutor.sol";
import {StandingRegistry} from "../src/StandingRegistry.sol";
import {AllocationExecutor} from "../src/AllocationExecutor.sol";
import {AttestationAuditModule} from "../src/AttestationAuditModule.sol";
import {DefaultDisclosurePolicyModule} from "../src/modules/DefaultDisclosurePolicyModule.sol";
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

contract DemoActor {
    bytes32 private constant DEFAULT_WORKFLOW = keccak256("demo-review-workflow");

    function registerEvidenceReceipt(
        EvidenceCommitmentRegistry registry,
        AVADataTypes.Role actingRole,
        bytes32 commitment,
        string calldata uri,
        string calldata evidenceType,
        uint256 disclosurePolicyId
    ) external returns (uint256) {
        return registry.registerEvidenceReceipt(actingRole, DEFAULT_WORKFLOW, commitment, uri, evidenceType, disclosurePolicyId);
    }

    function registerManuscript(
        AVAStateMachine stateMachine,
        AVADataTypes.Role actingRole,
        bytes32 offchainRef,
        string calldata uri
    ) external returns (uint256) {
        return stateMachine.registerManuscript(actingRole, offchainRef, uri);
    }

    function registerDisclosurePolicy(
        DisclosurePolicyRegistry registry,
        AVADataTypes.Role actingRole,
        string calldata label,
        string calldata uri
    ) external returns (uint256) {
        return registry.registerDisclosurePolicy(actingRole, label, uri);
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
            actingRole, manuscriptId, reviewerSubjectId, evidenceReceiptId, disclosurePolicyId
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
        AVAStateMachine stateMachine,
        AVADataTypes.Role actingRole,
        uint256 challengedRecognisedStateId,
        bytes32 challengerSubjectId,
        uint256 evidenceReceiptId,
        uint256 disclosurePolicyId
    ) external returns (uint256) {
        return stateMachine.fileChallenge(
            actingRole, challengedRecognisedStateId, challengerSubjectId, evidenceReceiptId, disclosurePolicyId
        );
    }

    function screenChallenge(
        AVAStateMachine stateMachine,
        AVADataTypes.Role actingRole,
        uint256 challengeId,
        bytes32 authorityId
    ) external {
        stateMachine.screenChallenge(actingRole, challengeId, authorityId);
    }

    function resolveChallenge(
        AVAStateMachine stateMachine,
        AVADataTypes.Role actingRole,
        uint256 challengeId,
        AVADataTypes.ChallengeOutcome outcome,
        AVADataTypes.RecognisedStateStatus toStatus,
        bytes32 authorityId,
        string calldata reasonURI
    ) external {
        stateMachine.resolveChallenge(actingRole, challengeId, outcome, toStatus, authorityId, reasonURI);
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
            actingRole, workflowKey, stage, objectId, subjectId, evidenceReceiptId, disclosurePolicyId, authorityId, status
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

    function recordAttestation(
        AttestationAuditModule module,
        AVADataTypes.Role actingRole,
        bytes32 workflowKey,
        AVADataTypes.Action action,
        bytes32 objectId,
        uint256 evidenceReceiptId,
        bytes32 attestationHash,
        bytes32 authorityId,
        string calldata attestationType,
        string calldata uri
    ) external returns (uint256) {
        return module.recordAttestation(
            actingRole, workflowKey, action, objectId, evidenceReceiptId, attestationHash, authorityId, attestationType, uri
        );
    }

    function registerRulePackage(
        AVARulePackageRegistry registry,
        AVADataTypes.Role actingRole,
        bytes32 workflowKey,
        AVARulePackageRegistry.RulePackageModules calldata modules,
        string calldata uri
    ) external {
        registry.registerRulePackage(actingRole, workflowKey, modules, uri);
    }

    function configureMigrationReferenceReaders(
        AVARulePackageRegistry registry,
        AVADataTypes.Role actingRole,
        IRecognisedStateReader stateReader,
        IEvidenceReceiptReader evidenceReader,
        bytes32 authorityId
    ) external {
        registry.configureMigrationReferenceReaders(actingRole, stateReader, evidenceReader, authorityId);
    }
}

contract AVADemoScenario {
    bytes32 private constant AUTHOR_SUBJECT = keccak256("demo-author");
    bytes32 private constant REVIEWER_SUBJECT = keccak256("demo-reviewer");
    bytes32 private constant CHALLENGER_SUBJECT = keccak256("demo-challenger");
    bytes32 private constant EDITOR_SUBJECT = keccak256("demo-editor");
    bytes32 private constant PANEL_SUBJECT = keccak256("demo-panel");
    bytes32 private constant EXECUTOR_SUBJECT = keccak256("demo-executor");
    bytes32 private constant EDITOR_AUTHORITY = keccak256("demo-editor-authority");
    bytes32 private constant PANEL_AUTHORITY = keccak256("demo-panel-authority");
    bytes32 private constant EXECUTOR_AUTHORITY = keccak256("demo-executor-authority");
    bytes32 private constant DEFAULT_WORKFLOW = keccak256("demo-review-workflow");

    RoleIdentityRegistry public roleRegistry;
    AuthorityMatrix public authorityMatrix;
    DefaultDisclosurePolicyModule public disclosurePolicyModule;
    EvidenceCommitmentRegistry public evidenceRegistry;
    DisclosurePolicyRegistry public disclosureRegistry;
    AVAStateMachine public stateMachine;
    AVARulePackageRegistry public rulePackageRegistry;
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
    AllocationExecutor public allocationExecutor;
    AttestationAuditModule public auditModule;
    DemoActor public demoActor;
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

        uint256 disclosurePolicyId = demoActor.registerDisclosurePolicy(
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

        recognisedStateId = demoActor.provisionallyRecogniseReview(
            stateMachine, AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY
        );
        demoActor.openReviewChallengeWindow(stateMachine, AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);

        uint256 challengeEvidenceId = challengerDemoActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256("demo-sealed-challenge"),
            "ipfs://demo/encrypted-challenge",
            "review-quality-challenge",
            disclosurePolicyId
        );
        challengeId = challengerDemoActor.fileChallenge(
            stateMachine,
            AVADataTypes.Role.Challenger,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            disclosurePolicyId
        );
        _assertNoAutomaticOutputs();

        demoActor.screenChallenge(stateMachine, AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        panelDemoActor.resolveChallenge(
            stateMachine,
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
            AVADataTypes.Role.Panel,
            DEFAULT_WORKFLOW,
            AVADataTypes.Action.RecordAttestation,
            bytes32(challengeId),
            challengeEvidenceId,
            keccak256("demo-transition-audit"),
            PANEL_AUTHORITY,
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
        disclosureRegistry = new DisclosurePolicyRegistry(authorityMatrix);
        disclosurePolicyModule = new DefaultDisclosurePolicyModule(disclosureRegistry);
        rulePackageRegistry = new AVARulePackageRegistry(authorityMatrix, disclosureRegistry);
        evidenceRegistry = new EvidenceCommitmentRegistry(authorityMatrix, disclosurePolicyModule, rulePackageRegistry);
        attributionModule = new DefaultAttributionModule();
        verificationModule = new DefaultVerificationModule();
        transitionRuleModule = new DefaultTransitionRuleModule();
        stateMachine =
            new AVAStateMachine(authorityMatrix, disclosurePolicyModule, rulePackageRegistry, evidenceRegistry, DEFAULT_WORKFLOW);
        allocationAdapter = new DefaultAllocationAdapter();
        consequenceAdapter = new DefaultConsequenceAdapter();
        standingAdapter = new DefaultStandingAdapter();
        rewardAdapter = new DefaultRewardAdapter();
        priorityAdapter = new DefaultPriorityAdapter();
        penaltyAdapter = new DefaultPenaltyAdapter();
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
        consequenceExecutor = new ConsequenceExecutor(authorityMatrix, stateMachine, rulePackageRegistry, evidenceRegistry);
        standingRegistry = new StandingRegistry(authorityMatrix, stateMachine, rulePackageRegistry, evidenceRegistry);
        allocationExecutor = new AllocationExecutor(authorityMatrix, stateMachine, rulePackageRegistry, evidenceRegistry);
        auditModule = new AttestationAuditModule(authorityMatrix, rulePackageRegistry, evidenceRegistry, stateMachine);
        demoActor = new DemoActor();
        challengerDemoActor = new DemoActor();
        panelDemoActor = new DemoActor();

        _assignRoles();
        _setPermissions();
        panelDemoActor.configureMigrationReferenceReaders(
            rulePackageRegistry,
            AVADataTypes.Role.Panel,
            IRecognisedStateReader(address(stateMachine)),
            IEvidenceReceiptReader(address(evidenceRegistry)),
            PANEL_AUTHORITY
        );
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
        roleRegistry.assignRole(address(demoActor), AVADataTypes.Role.Editor, EDITOR_AUTHORITY, "ipfs://demo/editor");
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
        panelDemoActor.registerRulePackage(
            rulePackageRegistry,
            AVADataTypes.Role.Panel,
            DEFAULT_WORKFLOW,
            AVARulePackageRegistry.RulePackageModules({
                attributionModule: attributionModule,
                verificationModule: verificationModule,
                allocationModule: allocationAdapter,
                transitionRuleModule: transitionRuleModule,
                disclosureModule: disclosurePolicyModule,
                standingAdapter: standingAdapter,
                consequenceAdapter: consequenceAdapter,
                rewardAdapter: rewardAdapter,
                priorityAdapter: priorityAdapter,
                penaltyAdapter: penaltyAdapter,
                restorationAdapter: restorationAdapter,
                challengeLifecycleModule: challengeLifecycleModule,
                evidencePolicyModule: evidencePolicyModule,
                auditAdapter: auditAdapter,
                editorialSystemAdapter: editorialSystemAdapter,
                residualEditorialAuthorityModule: residualEditorialAuthorityModule,
                fieldPolicyModule: fieldPolicyModule,
                antiAbuseModule: antiAbuseModule,
                valueExecutionAdapter: valueExecutionAdapter,
                standingComputationModule: standingComputationModule,
                rulePackageLifecycleModule: rulePackageLifecycleModule,
                evidenceLifecycleModule: evidenceLifecycleModule,
                disclosureLifecycleModule: disclosureLifecycleModule,
                disclosureExecutionModule: disclosureExecutionModule,
                version: 1,
                compatibilityKey: keccak256("ava-m4-10-compatible"),
                dependencyURI: "",
                deprecated: false
            }),
            "ipfs://demo/default-rule-package"
        );
    }

    function _executeAllocation(uint256 disclosurePolicyId) internal returns (uint256 allocationExecutionId) {
        uint256 allocationEvidenceId = demoActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Editor,
            keccak256("demo-allocation-evidence"),
            "ipfs://demo/allocation-evidence",
            "allocation-basis",
            disclosurePolicyId
        );
        uint256 allocationStateId = demoActor.registerRecognisedState(
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
        require(standingRegistry.nextStandingInputId() == 1, "unexpected standing input");
        require(standingRegistry.nextStandingUpdateId() == 1, "unexpected standing update");
        require(consequenceExecutor.nextConsequenceId() == 1, "unexpected consequence");
        require(allocationExecutor.nextAllocationExecutionId() == 1, "unexpected allocation");
    }
}
