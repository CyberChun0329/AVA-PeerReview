// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library AVADataTypes {
    enum Role {
        None,
        Author,
        Reviewer,
        Editor,
        Challenger,
        Institution,
        Panel,
        ProtocolExecutor
    }

    enum AVAStage {
        Attribution,
        Verification,
        Allocation
    }

    enum Action {
        RegisterManuscript,
        RegisterEvidence,
        RegisterDisclosurePolicy,
        RegisterRecognisedState,
        RegisterReviewContribution,
        ProvisionallyRecogniseReview,
        OpenChallengeWindow,
        FileChallenge,
        ScreenChallenge,
        ResolveChallenge,
        ApplyRestoration,
        CloseChallenge,
        RegisterConsequence,
        RegisterStandingInput,
        RecordStandingUpdate,
        ExecuteAllocation,
        RecordAttestation,
        TransitionRecognisedState,
        RegisterRulePackage,
        RecordDisclosureLifecycle,
        RecordEvidenceLifecycle,
        ExecuteValueSettlement,
        RecordDisclosureExecution,
        RecordExternalOperation,
        IssueStandingCredential,
        RevokeStandingCredential,
        SupersedeStandingCredential,
        RecordStandingCredentialSettlement,
        RegisterStandingFormula,
        RegisterSourceSetCompletenessAttestation,
        RegisterStandingComputationStatement,
        SupersedeStandingComputationStatement,
        InvalidateStandingComputationStatement
    }

    enum RecognisedStateStatus {
        None,
        Draft,
        Registered,
        Provisional,
        Challengeable,
        Vested,
        Frozen,
        Downgraded,
        Voided,
        Restored
    }

    enum ConsequenceKind {
        None,
        AdministrativeNote,
        ProcedureCorrection,
        RestorationRecord,
        PenaltyRecord
    }

    enum ReviewContributionStatus {
        None,
        Submitted,
        ProvisionalRecognised,
        ChallengeWindowOpen,
        Vested
    }

    enum ChallengeLifecycleStatus {
        None,
        ConcernFiled,
        AdmissibilityScreening,
        Resolved,
        RestorationApplied,
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
        AdmissibilityScreened,
        OutcomeResolved,
        RestorationRecorded,
        Closed
    }

    enum AllocationKind {
        None,
        OperationalAllowance,
        ProtocolSupportUnit,
        RestorationSupport,
        RewardValueRecord,
        AdministrativeQueueRecord
    }

    enum ValueExecutionMode {
        None,
        RecordOnly,
        Claim,
        Escrow
    }

    enum RulePackageLifecycleKind {
        None,
        DeprecationReady,
        SupersessionReady,
        MigrationReady
    }

    enum EvidenceLifecycleKind {
        None,
        ExpiryReady,
        RevocationReady,
        SupersessionReady,
        ReplacementReady
    }

    enum EvidenceReceiptStatus {
        None,
        Active,
        Expired,
        Revoked,
        Superseded,
        Replaced
    }

    enum DisclosureLifecycleKind {
        None,
        PolicyBoundReady,
        RoleScopedAccessReady,
        PostRecognitionDisclosureReady,
        ZKProofReceiptReady
    }

    enum ExecutionSourceType {
        None,
        AllocationRecord,
        ConsequenceRecord
    }

    enum ValueSettlementKind {
        None,
        TokenTransfer,
        EscrowDeposit,
        EscrowClaim,
        EscrowRefund,
        PriorityTokenMint,
        PriorityTokenConsume,
        ClawbackTransfer,
        RepaymentObligation,
        FuturePayoutSetoff,
        Waiver,
        Satisfaction
    }

    enum ValueSettlementStatus {
        None,
        Settled,
        Deposited,
        Claimed,
        Refunded,
        ObligationRecorded,
        SetoffRecorded,
        Waived,
        Satisfied
    }

    enum DisclosureExecutionKind {
        None,
        AccessGrant,
        AccessRevocation,
        ExpiryExecuted,
        SupersessionExecuted,
        VoluntaryDisclosureIntent,
        AnonymousChallengeUse
    }

    enum DisclosureExecutionStatus {
        None,
        Recorded,
        Revoked,
        Superseded,
        Expired
    }

    enum DisclosureTargetKind {
        None,
        EvidenceReceipt,
        RecognisedState,
        Challenge,
        Workflow,
        DisclosurePolicy
    }

    enum ExternalOperationKind {
        None,
        QueueAdjustmentIntent,
        FreezeIntent,
        InvestigationIntent,
        BillingIntent,
        EditorialSyncIntent
    }

    enum ExternalOperationStatus {
        None,
        Requested,
        Acknowledged,
        Cancelled,
        Superseded
    }

    enum ExternalOperationTargetKind {
        None,
        RecognisedState,
        Challenge,
        EvidenceReceipt,
        AllocationRecord,
        ConsequenceRecord
    }

    enum StandingCredentialStatus {
        None,
        Active,
        Revoked,
        Superseded,
        Suspended
    }

    enum StandingComputationStatus {
        None,
        Active,
        Superseded,
        Invalidated
    }

    enum StandingRelevantSettlementKind {
        None,
        RewardExecution,
        StateVoided,
        StateDowngraded,
        Restoration,
        StandingPenaltyInput,
        RepaymentObligation,
        FuturePayoutSetoff,
        Waiver,
        Satisfaction,
        CredentialSuspension,
        EligibilityRestoration
    }

    enum StandingPenaltyKind {
        None,
        AcademicFraud,
        IrresponsibleReview,
        NegligentChallenge,
        MaliciousOrFabricatedChallenge
    }

    enum EligibilityRestrictionKind {
        None,
        ReviewEligibility,
        ChallengeIntake,
        PanelEligibility,
        PriorityUse,
        RestorationCost
    }

    struct RoleSubject {
        address account;
        Role role;
        bytes32 subjectId;
        string metadataURI;
        bool active;
    }

    struct EvidenceReceipt {
        uint256 id;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 commitment;
        bytes32 evidenceTypeHash;
        string uri;
        string evidenceType;
        uint256 disclosurePolicyId;
        Role registeredRole;
        bytes32 registeredSubjectId;
        address registeredBy;
        EvidenceReceiptStatus status;
        uint256 lastLifecycleRecordId;
        uint256 replacementEvidenceReceiptId;
    }

    struct DisclosurePolicy {
        uint256 id;
        string label;
        string uri;
        Role authorityRole;
        bytes32 authorityId;
        address registeredBy;
        bool active;
    }

    struct ManuscriptRecord {
        uint256 id;
        bytes32 offchainRef;
        string uri;
        Role registeredRole;
        bytes32 registeredSubjectId;
        address registeredBy;
    }

    struct RecognisedStateRecord {
        uint256 id;
        bytes32 workflowKey;
        uint256 packageId;
        AVAStage stage;
        bytes32 objectId;
        bytes32 subjectId;
        uint256 evidenceReceiptId;
        uint256 disclosurePolicyId;
        bytes32 authorityId;
        RecognisedStateStatus status;
        address registeredBy;
    }

    struct ReviewContributionRecord {
        uint256 id;
        bytes32 workflowKey;
        uint256 packageId;
        uint256 manuscriptId;
        bytes32 reviewerSubjectId;
        uint256 evidenceReceiptId;
        uint256 disclosurePolicyId;
        uint256 recognisedStateId;
        ReviewContributionStatus status;
        address registeredBy;
    }

    struct ChallengeRecord {
        uint256 id;
        bytes32 workflowKey;
        uint256 packageId;
        uint256 challengedRecognisedStateId;
        bytes32 challengerSubjectId;
        uint256 evidenceReceiptId;
        uint256 disclosurePolicyId;
        ChallengeLifecycleStatus status;
        ChallengeOutcome outcome;
        uint256 lastTransitionId;
        address filedBy;
    }

    struct ChallengeTransitionRecord {
        uint256 id;
        bytes32 workflowKey;
        uint256 packageId;
        uint256 challengeId;
        uint256 challengedRecognisedStateId;
        RecognisedStateStatus fromStatus;
        RecognisedStateStatus toStatus;
        ChallengeTransitionKind transitionKind;
        ChallengeOutcome outcome;
        uint256 evidenceReceiptId;
        Role authorityRole;
        bytes32 authorityId;
        string reasonURI;
        uint256 createdAt;
        address createdBy;
    }

    struct RecognisedStateTransitionRecord {
        uint256 id;
        uint256 recognisedStateId;
        uint256 packageId;
        RecognisedStateStatus fromStatus;
        RecognisedStateStatus toStatus;
        Action action;
        uint256 challengeId;
        uint256 evidenceReceiptId;
        Role authorityRole;
        bytes32 authorityId;
        string reasonURI;
        uint256 createdAt;
        address createdBy;
    }

    struct ConsequenceRecord {
        uint256 id;
        uint256 recognisedStateId;
        uint256 packageId;
        ConsequenceKind kind;
        bytes32 subjectId;
        address asset;
        address payer;
        uint256 amountOrUnits;
        ValueExecutionMode executionMode;
        ValueSettlementKind settlementKind;
        bytes32 executionReference;
        uint256 evidenceReceiptId;
        Role authorityRole;
        bytes32 authorityId;
        string uri;
        address registeredBy;
    }

    struct StandingInputRecord {
        uint256 id;
        uint256 recognisedStateId;
        bytes32 subjectId;
        string dimension;
        string uri;
        address registeredBy;
    }

    struct StandingUpdateRecord {
        uint256 id;
        uint256 recognisedStateId;
        uint256 packageId;
        bytes32 subjectId;
        string dimension;
        int256 delta;
        uint256 evidenceReceiptId;
        Role authorityRole;
        bytes32 authorityId;
        string uri;
        address recordedBy;
    }

    struct StandingComputationRecord {
        uint256 id;
        uint256 recognisedStateId;
        uint256 packageId;
        bytes32 subjectId;
        string dimension;
        bytes32 vectorKey;
        int256 currentValue;
        int256 delta;
        uint256 effectiveAt;
        uint256 epoch;
        bytes32 sourceRecordSetHash;
        bytes32 computationRuleHash;
        bool reversible;
        bytes32 fieldKey;
        uint256 evidenceReceiptId;
        bytes32 authorityId;
        StandingComputationStatus status;
        uint256 supersededBy;
        uint256 invalidatedByEvidenceReceiptId;
        string uri;
        address recordedBy;
    }

    struct StandingCredentialRecord {
        uint256 id;
        uint256 standingComputationRecordId;
        uint256 recognisedStateId;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 subjectId;
        address holder;
        string dimension;
        bytes32 vectorKey;
        bytes32 categoryHash;
        int256 standingValue;
        int256 threshold;
        int256 lowerBound;
        int256 upperBound;
        uint256 epoch;
        uint256 issuedAt;
        uint256 expiresAt;
        bytes32 computationRuleHash;
        uint256 evidenceReceiptId;
        Role authorityRole;
        bytes32 authorityId;
        StandingCredentialStatus status;
        uint256 supersededBy;
        string uri;
        address issuedBy;
    }

    struct StandingCredentialSettlementRecord {
        uint256 id;
        uint256 credentialId;
        bytes32 subjectId;
        uint256 packageId;
        StandingRelevantSettlementKind kind;
        ExecutionSourceType sourceType;
        uint256 sourceRecordId;
        uint256 settlementId;
        Role authorityRole;
        bytes32 authorityId;
        string uri;
        address recordedBy;
    }

    struct AllocationExecutionRecord {
        uint256 id;
        uint256 recognisedStateId;
        uint256 packageId;
        AllocationKind allocationKind;
        bytes32 subjectId;
        address asset;
        address payer;
        uint256 amountOrUnits;
        ValueExecutionMode executionMode;
        ValueSettlementKind settlementKind;
        bytes32 executionReference;
        uint256 evidenceReceiptId;
        Role authorityRole;
        bytes32 authorityId;
        string uri;
        address executedBy;
    }

    struct ValueExecutionContext {
        uint256 recognisedStateId;
        address asset;
        address payer;
        bytes32 recipientSubjectId;
        uint256 amount;
        ValueExecutionMode mode;
        ValueSettlementKind settlementKind;
        bytes32 executionReference;
        bytes32 authorityId;
        uint256 evidenceReceiptId;
        string uri;
        address actor;
    }

    struct StandingComputationContext {
        uint256 recognisedStateId;
        bytes32 subjectId;
        string dimension;
        bytes32 vectorKey;
        int256 currentValue;
        int256 delta;
        uint256 effectiveAt;
        uint256 epoch;
        bytes32 sourceRecordSetHash;
        bytes32 computationRuleHash;
        bool reversible;
        bytes32 fieldKey;
        uint256 evidenceReceiptId;
        bytes32 authorityId;
        address actor;
    }

    struct RulePackageLifecycleRecord {
        uint256 id;
        bytes32 workflowKey;
        uint256 packageId;
        RulePackageLifecycleKind kind;
        bytes32 modulesHash;
        bytes32 modulesCodeHash;
        uint64 version;
        bytes32 compatibilityKey;
        bytes32 targetWorkflowKey;
        uint256 targetPackageId;
        bytes32 targetModulesHash;
        bytes32 targetModulesCodeHash;
        uint64 targetVersion;
        bytes32 targetCompatibilityKey;
        string dependencyURI;
        string uri;
        Role authorityRole;
        bytes32 authorityId;
        address recordedBy;
    }

    struct ObjectMigrationReadinessRecord {
        uint256 id;
        uint256 lifecycleRecordId;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 targetWorkflowKey;
        uint256 targetPackageId;
        bytes32 objectId;
        uint256 recognisedStateId;
        uint256 evidenceReceiptId;
        bytes32 boundaryHash;
        Role authorityRole;
        bytes32 authorityId;
        string uri;
        uint256 createdAt;
        address recordedBy;
    }

    struct EvidenceLifecycleRecord {
        uint256 id;
        bytes32 workflowKey;
        uint256 packageId;
        uint256 evidenceReceiptId;
        EvidenceLifecycleKind kind;
        uint256 replacementEvidenceReceiptId;
        EvidenceReceiptStatus fromStatus;
        EvidenceReceiptStatus toStatus;
        bytes32 lifecycleReference;
        string uri;
        Role authorityRole;
        bytes32 authorityId;
        address recordedBy;
    }

    struct DisclosureLifecycleRecord {
        uint256 id;
        bytes32 workflowKey;
        uint256 packageId;
        uint256 disclosurePolicyId;
        DisclosureLifecycleKind kind;
        bytes32 lifecycleReference;
        string uri;
        Role authorityRole;
        bytes32 authorityId;
        address recordedBy;
    }

    struct ValueSettlementRecord {
        uint256 id;
        ExecutionSourceType sourceType;
        uint256 sourceRecordId;
        uint256 packageId;
        ValueSettlementKind kind;
        ValueSettlementStatus status;
        address asset;
        address payer;
        address recipient;
        bytes32 subjectId;
        uint256 amountOrUnits;
        ValueExecutionMode sourceExecutionMode;
        ValueSettlementKind sourceSettlementKind;
        bytes32 sourceExecutionReference;
        bytes32 settlementContextHash;
        Role authorityRole;
        bytes32 authorityId;
        string uri;
        address executedBy;
    }

    struct StandingPenaltyInputRecord {
        uint256 id;
        uint256 penaltyConsequenceId;
        uint256 challengeId;
        StandingPenaltyKind penaltyKind;
        ChallengeOutcome challengeOutcome;
        bytes32 subjectId;
        string dimension;
        int256 delta;
        uint256 evidenceReceiptId;
        Role authorityRole;
        bytes32 authorityId;
        string uri;
        address recordedBy;
    }

    struct EligibilityRestrictionRecord {
        uint256 id;
        uint256 penaltyConsequenceId;
        uint256 challengeId;
        EligibilityRestrictionKind restrictionKind;
        ChallengeOutcome challengeOutcome;
        bytes32 subjectId;
        uint256 expiresAt;
        uint256 evidenceReceiptId;
        Role authorityRole;
        bytes32 authorityId;
        string uri;
        address recordedBy;
    }

    struct DisclosureExecutionRecord {
        uint256 id;
        bytes32 workflowKey;
        uint256 packageId;
        DisclosureExecutionKind kind;
        DisclosureExecutionStatus status;
        DisclosureTargetKind targetKind;
        uint256 targetId;
        uint256 disclosurePolicyId;
        bytes32 subjectId;
        bytes32 subjectCommitment;
        bytes32 nullifierHash;
        uint256 proofReceiptId;
        bytes32 proofContextHash;
        address proofVerifier;
        bytes32 proofDomainHash;
        uint256 sourceDisclosureExecutionId;
        uint256 expiresAt;
        Role authorityRole;
        bytes32 authorityId;
        string uri;
        address recordedBy;
    }

    struct ExternalOperationRecord {
        uint256 id;
        uint256 sourceOperationId;
        bytes32 workflowKey;
        uint256 packageId;
        ExternalOperationKind kind;
        ExternalOperationStatus status;
        ExternalOperationTargetKind targetKind;
        uint256 targetId;
        uint256 evidenceReceiptId;
        bytes32 operationContextHash;
        Role authorityRole;
        bytes32 authorityId;
        string referenceURI;
        address recordedBy;
    }

    struct AttestationRecord {
        uint256 id;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 objectId;
        uint256 evidenceReceiptId;
        bytes32 attestationHash;
        Role authorityRole;
        bytes32 authorityId;
        string attestationType;
        string uri;
        address recordedBy;
    }

    error NotAdmin(address caller);
    error NotAuthorised(address caller, Action action);
    error InvalidRole();
    error UnknownSubject(bytes32 subjectId);
    error EmptyValue();
    error UnknownReference(uint256 id);
    error InvalidState(uint256 id);
}
