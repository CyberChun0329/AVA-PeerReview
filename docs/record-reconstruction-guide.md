# Record Reconstruction Guide

Status: current reconstruction guide

Date: 2026-06-06

This guide explains how an external reader can reconstruct the current
AVA-PeerReview demo's governance path from emitted ids, getters, and stored
record fields. It is an integration document for indexers, demo readers, and
future module authors.

It does not add an indexer, database export, analytics model, publication
workflow, truth engine, reveal/decrypt path, sanction execution, production
payment, production queue execution, or deployment workflow.

## 1. Reader Rule

Use the record's stored identity first.

- If a record stores `packageId`, interpret it with
  `AVARulePackageRegistry.getRulePackageById(packageId)`.
- Use `getActivePackageId(workflowKey)` only for new workflow actions, not for
  interpreting old records.
- If a record does not store `packageId`, follow its source record or target
  record until a package-bound record is reached.
- Treat lifecycle and readiness records as explicit metadata records. They do
  not execute migration, reveal identity, judge truth, or rewrite state.

Minimum reconstruction packet:

- record id and record family;
- stored `packageId`, or source path to a package-bound record;
- `workflowKey` when the record is workflow-scoped;
- role-scoped `subjectId` or subject commitment;
- `authorityId` where an authority-bearing role acted;
- `evidenceReceiptId` or proof receipt id where the path is evidence-backed;
- source record id and source kind for downstream records;
- status, lifecycle kind, transition kind, outcome, context hash, or nullifier
  where the record type uses one.

## 2. Paper And Model Handoff Rule

The reconstruction path is also the paper-facing handoff path. A future model,
simulation, or analytical appendix should not invent strategic variables
directly from intuition. It should first ask which implemented AVA record
supports the variable.

| Future analytical object | Read from current demo |
| --- | --- |
| State variable | Recognised-state status, challenge lifecycle status, evidence lifecycle status, credential status, settlement status, or external-operation status. |
| Action | Authorised function call plus acting role, role-scoped subject, authority id, action enum, and package id. |
| Transition | Generic recognised-state transition, challenge transition, evidence lifecycle record, disclosure execution record, settlement receipt, or lifecycle readiness record. |
| Information condition | Evidence receipt, disclosure policy, proof receipt, subject commitment, context hash, nullifier, or audit attestation. |
| Bounded consequence or payoff proxy | Standing update input, standing computation record, credential proof surface, allocation record, consequence record, recovery record, administrative-priority artifact, settlement receipt, or eligibility record. |
| Translation loss or off-chain condition | URI, reason reference, evidence pointer, dependency URI, source-set commitment, formula hash, or policy hash. |

For state/action enumeration, the generated
`generated/recognised-state-transition-matrix.csv` artifact provides the
current recognised-state transition admissibility matrix. The checked-in CSV is
hash-pinned, and test coverage compares each row with row-level kernel
execution. It should be treated as a paper/model handoff aid, not as a
separate source of governance authority.

For scenario-level handoff, `script/AVACanonicalTrace.s.sol` executes four
canonical traces and returns the current deterministic output. The checked-in
`generated/canonical-scenario-traces.json` file is maintained as the repository
artifact; the script does not rewrite it automatically. The traces use
implemented record names such as `review_registered`, `challenge_upheld`,
`standing_penalty_input_recorded`,
`eligibility_restricted`, and `restoration_applied`. They do not assign
probabilities, estimate payoffs, decide truth, execute sanctions, or describe
publication outcomes.

For translation-loss boundaries, read `translation-loss-audit.md` before
treating a contract record as a paper or model variable. That document marks
which concepts are encoded directly, approximated by commitments or receipts,
reserved for human judgement, parameterised by modules, or excluded by design.

The contracts do not calculate payoffs, probabilities, truth, quality, or
manuscript merit. If a future model uses a variable that cannot be traced to an
implemented record or to an explicitly marked off-chain abstraction, that
variable is outside the current Solidity demo.

## 3. Core Governance Records

| Record family | Contract | Event anchor | Getter | Reconstruction fields |
| --- | --- | --- | --- | --- |
| Role subject | `RoleIdentityRegistry` | `RoleAssigned`, `RoleDeactivated` | `getSubject(subjectId)`, `subjectOf(account, role)`, `hasRole(account, role)` | `subjectId`, account, role, active/canonical state |
| Permission | `AuthorityMatrix` | `PermissionSet` | `isPermitted(role, action)` | role/action permission |
| Disclosure policy | `DisclosurePolicyRegistry` | `DisclosurePolicyRegistered` | `getDisclosurePolicy(id)` | policy id, label, authority role/id, active flag |
| Evidence receipt | `EvidenceCommitmentRegistry` | `EvidenceReceiptRegistered` | `getEvidenceReceipt(id)` | `workflowKey`, `packageId`, commitment, type hash, disclosure policy, subject, status |
| Evidence lifecycle | `EvidenceCommitmentRegistry` | `EvidenceLifecycleRecorded` | `getEvidenceLifecycleRecord(id)` | evidence id, lifecycle kind, from/to status, replacement reference, authority |
| Rule package | `AVARulePackageRegistry` | `RulePackageRegistered`, `RulePackageVersionRegistered`, `RulePackageChallengeLifecycleBound`, `RulePackageAuthorityBound` | `getRulePackageById(packageId)`, `getActivePackageId(workflowKey)` | `packageId`, `workflowKey`, module addresses, `modulesHash`, `modulesCodeHash`, version, compatibility key |
| Rule package lifecycle | `AVARulePackageRegistry` | `RulePackageLifecycleRecorded`, `RulePackageLifecyclePackageBinding` | `getRulePackageLifecycleRecord(id)` | source package, target package, modules hashes, version/compatibility, lifecycle kind |
| Object migration readiness | `AVARulePackageRegistry` | `ObjectMigrationReadinessRecorded` | `getObjectMigrationReadinessRecord(id)` | lifecycle record, source package, target package, object id, source-package recognised state, source-package evidence, boundary hash, authority, `createdAt`, recorder |
| Disclosure lifecycle | `AVARulePackageRegistry` | `DisclosureLifecycleRecorded` | `getDisclosureLifecycleRecord(id)` | workflow, `packageId`, policy id, lifecycle kind, authority |

The legacy `RulePackageRegistered` event remains intentionally compact.
Indexers that need the complete immutable package binding should combine it
with `RulePackageVersionRegistered`, `RulePackageChallengeLifecycleBound`, and
`RulePackageAuthorityBound`, then verify the stored package through
`getRulePackageById(packageId)`.

## 4. AVA State-Machine Records

| Record family | Contract | Event anchor | Getter | Reconstruction fields |
| --- | --- | --- | --- | --- |
| Manuscript reference | `AVAStateMachine` | `ManuscriptRegistered` | `getManuscript(id)` | off-chain reference, role subject, registeredBy |
| Recognised state | `AVAStateMachine` | `RecognisedStateRegistered` | `getRecognisedState(id)` | `workflowKey`, `packageId`, AVA stage, object id, responsible `subjectId`, evidence id, disclosure policy, authority, status |
| Review contribution | `AVAStateMachine` | `ReviewContributionRegistered`, `ReviewProvisionallyRecognised`, `ReviewChallengeWindowOpened`, `ReviewRecognitionVested` | `getReviewContribution(id)` | manuscript id, reviewer subject, evidence id, disclosure policy, linked recognised state, status |
| Challenge | `AVAStateMachine` | `ChallengeFiled`, `ChallengeScreened`, `ChallengeResolved`, `ChallengeClosed`, `RestorationApplied` | `getChallenge(id)` | challenged recognised state, challenger subject, evidence id, lifecycle status, outcome, last transition |
| Challenge transition | `AVAStateMachine` | `ChallengeTransitionRecorded` | `getChallengeTransition(id)` | challenge id, target recognised state, from/to status, transition kind, outcome, evidence, authority, `createdAt`, `createdBy` |
| Recognised-state transition | `AVAStateMachine` | `RecognisedStateTransitionRecorded` | `getRecognisedStateTransition(id)` | recognised state id, package, from/to status, action, challenge id if any, evidence, authority, `createdAt`, `createdBy` |

Reader path:

1. Start at a recognised state or challenge id.
2. Read the stored `packageId`.
3. Read the generic recognised-state transition ledger for status changes.
4. For challenge-derived changes, read both the challenge transition and the
   generic recognised-state transition.
5. Do not infer truth, publication merit, sanction, or reward from raw review
   or raw challenge records.

## 5. Downstream Allocation And Consequence Records

| Record family | Contract | Event anchor | Getter | Reconstruction fields |
| --- | --- | --- | --- | --- |
| Standing update | `StandingRegistry` | `StandingUpdateRecorded` | `getStandingUpdate(id)` | recognised state, package, subject, dimension, delta, evidence, authority |
| Standing computation | `StandingRegistry` | `StandingComputationRecorded`, `StandingComputationSuperseded`, `StandingComputationInvalidated` | `getStandingComputationRecord(id)` | recognised state, package, subject, vector, epoch, source-set hash, rule hash, status |
| Standing credential | `StandingCredentialRegistry` | `StandingCredentialIssued`, `StandingCredentialRevoked`, `StandingCredentialSuperseded` | `getStandingCredential(id)` | computation source, recognised state, package, subject, holder, threshold/range/category, expiry, status |
| Standing credential settlement impact | `StandingCredentialRegistry` | `StandingCredentialSettlementRecorded` | `getStandingCredentialSettlement(id)` | credential id, package, subject, source type/id, settlement id, authority |
| Allocation execution | `AllocationExecutor` | `AllocationExecuted` | `getAllocationExecution(id)` | recognised state, package, allocation kind, subject, value-readiness metadata, evidence, authority |
| Consequence | `ConsequenceExecutor` | `ConsequenceRegistered` | `getConsequence(id)` | recognised state, package, consequence kind, subject, value-readiness metadata, evidence, authority |
| Standing penalty input | `ConsequenceExecutor` | `StandingPenaltyInputRecorded` | `getStandingPenaltyInput(id)` | penalty consequence, challenge id, outcome, subject, dimension, delta, evidence, authority |
| Eligibility restriction | `ConsequenceExecutor` | `EligibilityRestrictionRecorded` | `getEligibilityRestriction(id)` | penalty consequence, challenge id, outcome, subject, expiry, evidence, authority |

The consequence and penalty subject should be reconstructed as the responsible
subject of the source recognised state. The current demo does not encode
implicit cross-subject consequence records.

Downstream records should be interpreted through their source recognised state
and stored `packageId`. Raw review ids, raw challenge ids, raw evidence ids,
unknown ids, and unsupported recognised-state statuses are not downstream
sources.

Standing and reputation remain governance memory. They are not assets,
balances, rewards, administrative priority rights, or manuscript signals.

## 6. Proof, Disclosure, Settlement, And External Operation Records

| Record family | Contract | Event anchor | Getter | Reconstruction fields |
| --- | --- | --- | --- | --- |
| Disclosure proof receipt | `ZKProofRegistry` | `ZKProofVerified` | `getProofReceipt(id)`, `getProofReceiptId(contextHash)`, `getProofReceiptIdByNullifier(nullifierHash)` | package, verifier, proof domain, context, subject commitment, nullifier |
| ZK standing proof receipt | `ZKStandingComputationRegistry` | `ZKStandingComputationProofRecorded` | `getStandingProofReceipt(id)`, `getStandingProofReceiptId(contextHash)`, `getStandingProofReceiptIdByNullifier(nullifierHash)` | workflow, package, formula/source-set/statement ids, verifier, context, subject commitment, vector/category/range |
| ZK standing credential | `ZKStandingCredentialRegistry` | `ZKStandingCredentialIssued`, `ZKStandingCredentialRevoked`, `ZKStandingCredentialSuperseded`, `ZKStandingCredentialSuspended` | `getCredential(id)` | standing proof receipt, statement id, package, subject commitment, credential commitment/nullifier, vector/category/range, expiry, status |
| ZK standing credential use | `ZKStandingCredentialRegistry` | `ZKStandingCredentialUsed` | `getCredentialUseRecord(id)` | credential id, package, subject commitment, vector/category, required threshold, target context, proof-use nullifier |
| ZK standing credential suspension | `ZKStandingCredentialRegistry` | `ZKStandingCredentialSourceBoundSuspensionRecorded` | `getCredentialSuspensionRecord(id)` | credential id, source kind, package, subject commitment, settlement/challenge source, authority |
| Disclosure execution | `DisclosureAccessExecutor` | `DisclosureExecutionRecorded` | `getDisclosureExecution(id)`, `disclosureExecutionIdByNullifier(nullifier)` | target kind/id, package, policy, subject/commitment, nullifier, proof receipt, source execution, status, expiry |
| Value settlement | `ValueSettlementExecutor` | `ValueSettlementRecorded` | `getValueSettlement(id)`, `latestSettlementIdBySourceKey(sourceKey)`, `settlementStatusBySourceKey(sourceKey)` | source type/id, package, settlement kind/status, asset/payer/recipient, subject, context hash, authority |
| External operation | `ExternalOperationRegistry` | `ExternalOperationRecorded` | `getExternalOperation(id)`, `terminalReceiptIdByOperation(id)` | source operation, workflow, package, target kind/id, evidence, operation context, status |
| Attestation | `AttestationAuditModule` | `AttestationRecorded` | `getAttestation(id)` | workflow, package, object id, evidence, attestation hash/type, authority |

Proof and disclosure readers should use context hashes and nullifier hashes as
anti-replay anchors. They should still inspect the target object, package,
policy, subject or commitment, action, and source record before treating a
receipt as relevant.

## 7. Standing Formula And Source-Set Records

| Record family | Contract | Event anchor | Getter | Reconstruction fields |
| --- | --- | --- | --- | --- |
| Standing formula | `StandingFormulaRegistry` | `StandingFormulaRegistered` | `getStandingFormula(id)` | workflow, package, vector, formula version, rule/source-set/decay/cap/restoration hashes, verifier |
| Source-set commitment | `StandingFormulaRegistry` | `SourceSetCommitmentRegistered` | `getSourceSetCommitment(id)`, `getSourceSetCommitmentIdForProofInput(...)` | formula, package, subject commitment, category, epoch, source root, evidence, completeness hash |
| Source-set completeness attestation | `StandingFormulaRegistry` | `SourceSetCompletenessAttestationRegistered` | `getSourceSetCompletenessAttestation(id)` | source-set commitment, formula, package, included classes, exclusion policy, evidence, completeness hash, active flag |
| Standing computation statement | `StandingFormulaRegistry` | `StandingComputationStatementRegistered`, `StandingComputationStatementSuperseded`, `StandingComputationStatementInvalidated` | `getStandingComputationStatement(id)`, `getStandingComputationStatementId(...)` | source-set commitment, completeness attestation, formula, package, subject commitment, vector/category/range, output commitment, verifier, status |

These records support privacy-preserving standing computation handoff. They do
not calculate standing on chain, reveal identity, traverse full history,
produce a reward, or issue a credential by themselves.

## 8. Reconstruction Status

No Solidity, ABI, storage, or event changes are required for this guide.

The audit found that current major record families expose:

- a stable record id;
- a getter or public mapping for lookup;
- an event carrying at least the emitted id or enough source key to follow up
  through getters;
- package identity on package-bound records, or a clear source path to a
  package-bound record;
- subject, authority, evidence, status, context, source, or nullifier fields
  where the record type requires them.

The gap this guide closes is documentation: external readers need a single map
for reconstructing records across state-machine, downstream, proof/disclosure,
settlement, standing formula, and audit surfaces.
