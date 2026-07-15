// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library AVACoreTypes {
    bytes32 internal constant ACTION_REGISTER_GOVERNED_OBJECT = keccak256("ava.core.register-governed-object.v1");
    bytes32 internal constant ACTION_FORM_RECOGNISED_STATE = keccak256("ava.core.form-recognised-state.v1");
    bytes32 internal constant ACTION_TRANSITION_RECOGNISED_STATE = keccak256("ava.core.transition-recognised-state.v1");
    bytes32 internal constant ACTION_VEST_RECOGNISED_STATE = keccak256("ava.core.vest-recognised-state.v1");
    bytes32 internal constant ACTION_FILE_CHALLENGE = keccak256("ava.extension.challenge.file.v1");
    bytes32 internal constant ACTION_SCREEN_CHALLENGE = keccak256("ava.extension.challenge.screen.v1");
    bytes32 internal constant ACTION_RESOLVE_CHALLENGE = keccak256("ava.extension.challenge.resolve.v1");
    bytes32 internal constant ACTION_APPLY_RESTORATION = keccak256("ava.extension.challenge.apply-restoration.v1");
    bytes32 internal constant ACTION_CLOSE_CHALLENGE = keccak256("ava.extension.challenge.close.v1");
    bytes32 internal constant ACTION_REGISTER_DISCLOSURE_POLICY = keccak256("ava.core.register-disclosure-policy.v1");
    bytes32 internal constant ACTION_REGISTER_EVIDENCE = keccak256("ava.core.register-evidence.v1");
    bytes32 internal constant ACTION_RECORD_EVIDENCE_LIFECYCLE = keccak256("ava.core.record-evidence-lifecycle.v1");
    bytes32 internal constant ACTION_RECORD_STANDING_UPDATE = keccak256("ava.extension.standing.record-update.v1");
    bytes32 internal constant ACTION_RECORD_ALLOCATION = keccak256("ava.extension.allocation.record.v1");
    bytes32 internal constant ACTION_RECORD_CONSEQUENCE = keccak256("ava.extension.consequence.record.v1");
    bytes32 internal constant ACTION_REGISTER_RULE_PACKAGE = keccak256("ava.core.register-rule-package.v1");
    bytes32 internal constant ACTION_RECORD_STANDING_COMPUTATION =
        keccak256("ava.extension.standing.record-computation.v1");
    bytes32 internal constant ACTION_ISSUE_STANDING_CREDENTIAL =
        keccak256("ava.extension.standing.issue-credential.v1");
    bytes32 internal constant ACTION_REVOKE_STANDING_CREDENTIAL =
        keccak256("ava.extension.standing.revoke-credential.v1");
    bytes32 internal constant ACTION_SUPERSEDE_STANDING_CREDENTIAL =
        keccak256("ava.extension.standing.supersede-credential.v1");
    bytes32 internal constant ACTION_RECORD_PRIVACY_PROOF = keccak256("ava.extension.privacy.record-proof.v1");
    bytes32 internal constant ACTION_RECORD_DISCLOSURE_RECEIPT =
        keccak256("ava.extension.disclosure.record-receipt.v1");
    bytes32 internal constant ACTION_RECORD_AUDIT_RECEIPT = keccak256("ava.extension.audit.record-receipt.v1");
    bytes32 internal constant ACTION_RECORD_SETTLEMENT_RECEIPT =
        keccak256("ava.extension.settlement.record-receipt.v1");
    bytes32 internal constant ACTION_RECORD_EXTERNAL_OPERATION =
        keccak256("ava.extension.external-operation.record.v1");
    bytes32 internal constant ACTION_RECORD_EXTERNAL_OPERATION_OUTCOME =
        keccak256("ava.extension.external-operation.record-outcome.v1");
    bytes32 internal constant ACTION_RECORD_PACKAGE_LIFECYCLE =
        keccak256("ava.extension.package-lifecycle.record.v1");
    bytes32 internal constant ACTION_RECORD_APPROVAL_RECEIPT =
        keccak256("ava.extension.authority.record-approval.v1");
    bytes32 internal constant ACTION_RECORD_OBJECT_MIGRATION_READINESS =
        keccak256("ava.extension.package-lifecycle.object-migration-readiness.v1");
    bytes32 internal constant ACTION_RECORD_DISCLOSURE_LIFECYCLE_READINESS =
        keccak256("ava.extension.package-lifecycle.disclosure-readiness.v1");
    bytes32 internal constant ACTION_RECORD_REWARD = keccak256("ava.extension.reward.record.v1");
    bytes32 internal constant ACTION_RECORD_ADMINISTRATIVE_PRIORITY =
        keccak256("ava.extension.administrative-priority.record.v1");
    bytes32 internal constant ACTION_RECORD_PENALTY = keccak256("ava.extension.penalty.record.v1");
    bytes32 internal constant ACTION_RECORD_STANDING_PENALTY_INPUT =
        keccak256("ava.extension.penalty.record-standing-input.v1");
    bytes32 internal constant ACTION_RECORD_ELIGIBILITY_RESTRICTION =
        keccak256("ava.extension.penalty.record-eligibility-restriction.v1");
    bytes32 internal constant ACTION_RECORD_RESTORATION = keccak256("ava.extension.restoration.record.v1");
    bytes32 internal constant ACTION_RECORD_REWARD_LIFECYCLE =
        keccak256("ava.extension.value.record-reward-lifecycle.v1");
    bytes32 internal constant ACTION_RECORD_VALUE_SETTLEMENT =
        keccak256("ava.extension.value.record-settlement.v1");
    bytes32 internal constant ACTION_RECORD_REPAYMENT_OBLIGATION =
        keccak256("ava.extension.value.record-repayment-obligation.v1");
    bytes32 internal constant ACTION_RECORD_RECOVERY_OUTCOME =
        keccak256("ava.extension.value.record-recovery-outcome.v1");
    bytes32 internal constant ACTION_REGISTER_STANDING_FORMULA =
        keccak256("ava.extension.standing.register-formula.v1");
    bytes32 internal constant ACTION_REGISTER_STANDING_SOURCE_SET =
        keccak256("ava.extension.standing.register-source-set.v1");
    bytes32 internal constant ACTION_ATTEST_STANDING_SOURCE_SET =
        keccak256("ava.extension.standing.attest-source-set.v1");
    bytes32 internal constant ACTION_RECORD_STANDING_COMPUTATION_STATEMENT =
        keccak256("ava.extension.standing.record-computation-statement.v1");
    bytes32 internal constant ACTION_SUPERSEDE_STANDING_COMPUTATION_STATEMENT =
        keccak256("ava.extension.standing.supersede-computation-statement.v1");
    bytes32 internal constant ACTION_INVALIDATE_STANDING_COMPUTATION_STATEMENT =
        keccak256("ava.extension.standing.invalidate-computation-statement.v1");
    bytes32 internal constant ACTION_RECORD_STANDING_ZK_PROOF =
        keccak256("ava.extension.standing.record-zk-proof.v1");
    bytes32 internal constant ACTION_ISSUE_STANDING_ZK_CREDENTIAL =
        keccak256("ava.extension.standing.issue-zk-credential.v1");
    bytes32 internal constant ACTION_REVOKE_STANDING_ZK_CREDENTIAL =
        keccak256("ava.extension.standing.revoke-zk-credential.v1");
    bytes32 internal constant ACTION_SUPERSEDE_STANDING_ZK_CREDENTIAL =
        keccak256("ava.extension.standing.supersede-zk-credential.v1");
    bytes32 internal constant ACTION_USE_STANDING_ZK_CREDENTIAL =
        keccak256("ava.extension.standing.use-zk-credential.v1");

    enum Stage {
        None,
        Attribution,
        Verification,
        Allocation
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

    enum TransitionKind {
        None,
        InitialFormation,
        Generic,
        Vesting,
        ChallengeCorrection,
        Restoration
    }

    enum EvidenceStatus {
        None,
        Active,
        Revoked,
        Expired,
        Superseded
    }

    enum EvidenceLifecycleKind {
        None,
        Revoke,
        Expire,
        Supersede
    }

    struct DisclosurePolicyRecord {
        uint256 id;
        bytes32 appId;
        bytes32 policyKey;
        string label;
        string uri;
        bytes32 authorityId;
        address registeredBy;
        uint64 registeredAt;
        bool active;
    }

    struct EvidenceRecord {
        uint256 id;
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 commitment;
        bytes32 evidenceTypeHash;
        bytes32 subjectId;
        uint256 disclosurePolicyId;
        bytes32 authorityId;
        string uri;
        address registeredBy;
        EvidenceStatus status;
        uint256 lastLifecycleRecordId;
        uint256 replacementEvidenceId;
        uint64 registeredAt;
    }

    struct EvidenceLifecycleRecord {
        uint256 id;
        uint256 evidenceId;
        bytes32 appId;
        uint256 packageId;
        EvidenceLifecycleKind kind;
        EvidenceStatus fromStatus;
        EvidenceStatus toStatus;
        uint256 replacementEvidenceId;
        bytes32 authorityId;
        bytes32 reasonHash;
        string uri;
        address createdBy;
        uint64 createdAt;
    }

    struct SubjectRecord {
        bytes32 subjectId;
        bytes32 appId;
        bytes32 roleKey;
        address account;
        string uri;
        bool active;
        uint64 assignedAt;
        uint64 deactivatedAt;
    }

    struct GovernedObjectRecord {
        uint256 id;
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 objectTypeKey;
        bytes32 objectCommitment;
        uint256 parentObjectId;
        bytes32 subjectId;
        uint256 evidenceReceiptId;
        uint256 disclosurePolicyId;
        bytes32 metadataHash;
        string uri;
        bytes32 authorityId;
        address registeredBy;
        uint64 registeredAt;
    }

    struct RecognisedStateRecord {
        uint256 id;
        uint256 governedObjectId;
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        Stage stage;
        RecognisedStateStatus status;
        bytes32 subjectId;
        uint256 evidenceReceiptId;
        uint256 disclosurePolicyId;
        bytes32 authorityId;
        uint256 lastTransitionId;
        address createdBy;
        uint64 createdAt;
    }

    struct RecognisedStateTransitionRecord {
        uint256 id;
        uint256 recognisedStateId;
        uint256 governedObjectId;
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        uint256 decisionPackageId;
        uint256 sourceRecordId;
        RecognisedStateStatus fromStatus;
        RecognisedStateStatus toStatus;
        TransitionKind kind;
        uint256 evidenceReceiptId;
        uint256 decisionEvidenceReceiptId;
        bytes32 authorityId;
        bytes32 reasonHash;
        string reasonURI;
        address createdBy;
        uint64 createdAt;
    }

    error EmptyValue();
    error NotAdmin(address caller);
    error UnknownApplication(bytes32 appId);
    error UnknownReference(uint256 id);
    error InvalidState(uint256 id);
    error NotAuthorised(address caller, bytes32 actionKey);
    error SubjectMismatch(bytes32 expected, bytes32 supplied);
    error CrossApplicationReference(bytes32 expectedAppId, bytes32 suppliedAppId);
}
