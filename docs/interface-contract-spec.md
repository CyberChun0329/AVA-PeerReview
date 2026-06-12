# Interface Contract Specification

This specification defines the semantic contract for every replaceable
module and adapter interface in the current Solidity demo. It is an
implementation-facing compatibility document, not a roadmap and not an
approval to start a production release, model, simulation, publication logic,
production token/payment, publication-queue execution, sanction execution,
identity reveal, real reveal/decrypt, production ZK, or ACL.

The interfaces are specified for a Base-compatible EVM/Solidity substrate.
They describe the current local Foundry implementation and its module
compatibility rules; they do not describe a live Base deployment or production
deployment policy.

For the package-author workflow, `RulePackageModules` field map,
historical-package binding rules, and package test checklist, see
`docs/rule-package-integration-guide.md`.

## How To Use This Spec

This document is intentionally detailed. Use it as a compatibility contract,
not as the first narrative introduction to the project.

- If you need the whole-system story, read `docs/architecture.md` first.
- If you are adding a workflow package, start with
  `docs/rule-package-integration-guide.md`, then return here for the exact
  interface contract.
- If you are checking whether a module may do something, read the relevant
  interface section and the "Must not do" / "Gates" clauses together.
- If you are reconstructing a record after execution, use
  `docs/record-reconstruction-guide.md`; this file explains what each module
  is allowed to validate before a record is written.

Quick index:

| Need | Section |
| --- | --- |
| Shared validator semantics | `Global Contract` |
| AVA core stage interfaces | `IAttributionModule`, `IVerificationModule`, `IAllocationAdapter` / `IAVAAllocationModule` |
| Recognised-state support | transition, challenge, disclosure, evidence, audit, field, anti-abuse, residual authority |
| Downstream / proof / execution support | standing, credentials, reward, priority, consequence, penalty, restoration, settlement, external operation, package lifecycle, ZK |
| Forbidden boundary check | each interface's `Must not do` clause |

## Global Contract

All rule-package modules and adapters are validator-only seams.

- A successful `validate... external view` call means **no veto only**.
- Success never grants authority, never proves scientific truth, never decides
  manuscript merit, never creates publication effect, and never creates reward
  entitlement.
- Revert means veto, incompatible package/context, or invalid reference.
- Modules must not mutate substrate storage, grant authority, execute payment,
  transfer token, execute sanction, decide publication, reveal identity,
  reveal/decrypt evidence, or reinterpret substrate-owned identifiers.
- `subjectId` means role-scoped subject by default.
- `authorityId` means authority-bearing role-scoped subject and must not be
  treated as the same field as ordinary `subjectId`.
- `objectId` is interpreted by the calling substrate path. A module must not
  reinterpret it as another substrate object type.
- `workflowKey` selects the active or target rule-package context. Where the
  substrate dispatches by stored `packageId`, modules must treat that package
  identity as fixed for the call.
- `modulesHash`, `modulesCodeHash`, and `compatibilityKey` are package
  compatibility inputs. They are not module-owned authority and cannot override
  substrate checks.
- Evidence ids and disclosure-policy ids are references. Modules do not inspect
  confidential content or judge truth.

The narrow execution-layer interfaces are not rule-package validator modules.
They consume already-authorised allocation, consequence, evidence, challenge,
recognised-state, or disclosure records and write settlement/access/external-
operation receipts. They must not decide manuscript quality, publication
outcome, scientific truth, standing, or reputation.

The standing credential issuer, standing-relevant settlement impact,
append-only recovery receipt, standing-penalty, and eligibility-restriction
surfaces are also not rule-package validator modules. They are not token,
reward, payment, or publication surfaces.

## Interface Taxonomy

The technical framework reads the current interfaces through three layers. Only
Layer A corresponds directly to the AVA macro stages:

### Layer A: AVA Core Stage Interfaces

- Attribution: `IAttributionModule`.
- Verification: `IVerificationModule`.
- Allocation: `IAVAAllocationModule` / `IAllocationAdapter`.

Allocation is AVA's third stage. It validates what bounded consequence type may
attach to a recognised state. It is not the same thing as standing, reward,
priority, penalty, restoration, value settlement, or standing credential
issuance.

### Layer B: Recognised-State Governance Support

- `ITransitionRuleModule`
- `IChallengeLifecycleModule`
- `IDisclosurePolicyModule`
- `IDisclosureLifecycleModule`
- `IDisclosureExecutionModule`
- `IResidualEditorialAuthorityModule`
- `IEvidencePolicyModule`
- `IEvidenceLifecycleModule`
- `IAuditAdapter`
- `IFieldPolicyModule`
- `IAntiAbuseModule`

These interfaces support recognised-state governance. They are not additional
AVA stages, and they must not turn challenge, correction, disclosure,
restoration, audit, field policy, or anti-abuse validation into a fourth or
fifth AVA stage.

`IEditorialSystemAdapter` remains an optional metadata-reference bridge for
workflow-aware manuscript pointers. It is not one of the AVA core stage
interfaces, not an Allocation-edge downstream interface, and not publication
logic.

### Layer C: Downstream Consequence / Execution / Proof Support

- `IStandingAdapter`
- `IStandingComputationModule`
- `IStandingCredentialIssuer`
- `IRewardAdapter`
- `IPriorityAdapter`
- `IConsequenceAdapter`
- `IPenaltyAdapter`
- `IRestorationAdapter`
- `IValueExecutionAdapter`
- `IValueSettlementExecutor`
- `IExternalOperationRegistry`
- `IRulePackageLifecycleModule`
- `IZKProofVerifier`

These interfaces sit downstream of the Allocation edge or support proof,
settlement, package-readiness, and external-operation receipts. Standing and
reputation remain computed governance memory and procedural weight. They are
not tokens, rewards, balances, priority tokens, public prestige, manuscript
merit, or publication signals.

## Interface Contracts

### Layer A: AVA Core Stage Interfaces

### `IAttributionModule`

Function: `validateAttribution(...) returns (bytes32 attributedObjectId)`

Inputs:
- `workflowKey`: AVA workflow package key for this validation.
- `actingRole`: caller role already supplied to the substrate path.
- `stage`: AVA stage for the proposed recognised-state object.
- `objectId`: path-scoped object reference; the module must not reinterpret it
  as another substrate object type.
- `subjectId`: role-scoped subject connected to the attributed object.
- `evidenceReceiptId`: evidence receipt reference already expected by the path.

Output:
- `attributedObjectId`: deterministic governance object reference used by the
  substrate record. It is not truth finding and not merit scoring.

Success semantics: no attribution veto only.

Allowed failure: revert for invalid, incompatible, unsupported, or
insufficient references.

Must not do: grant authority, mutate records, reveal identity, judge truth,
or create publication/reward/consequence effects.

Assumptions and gates:
- Before: caller authority, subject binding, usable active evidence/workflow,
  and package lookup are substrate responsibilities.
- After: verification, evidence policy, field policy, anti-abuse, residual
  authority, storage, and transition ledger may still run.

### `IVerificationModule`

Function: `validateVerification(...)`

Inputs: `workflowKey`, `actingRole`, `stage`, path-scoped `objectId`, and
`evidenceReceiptId`.

Output: none.

Success semantics: no verification veto only; not truth validation, quality
judgment, manuscript merit, or publication decision.

Allowed failure: revert for invalid reference, insufficient evidence reference,
or workflow incompatibility.

Must not do: mutate substrate, score merit, accept/reject manuscript, reveal
content, execute reward/payment/sanction.

Gates:
- Before: usable active evidence reference and package identity have been
  checked by substrate where the path requires evidence.
- After: evidence policy, lifecycle, field policy, anti-abuse, residual
  authority, and storage may still veto.

### `IAllocationAdapter` / `IAVAAllocationModule`

Function: `validateAllocation(...)`

Inputs: `actingRole`, `recognisedStateId`, `allocationKind`, target
`subjectId`, `amountOrUnits`, `evidenceReceiptId`, `authorityId`, `uri`, and
`actor`.

Output: none.

Success semantics: no allocation veto only. `IAVAAllocationModule` is the
workflow-facing alias of this allocation adapter contract.

Allowed failure: revert for invalid allocation kind, target, amount, evidence,
or authority context.

Must not do: transfer token/stablecoin, execute queue, grant publication
priority, affect merit, or write allocation records.

Gates:
- Before: allowed recognised-state status, target subject, evidence workflow,
  authorityId binding, anti-abuse, and value-readiness checks run.
- After: substrate records only the allocation execution record.

### Layer B: Recognised-State Governance Support

### `ITransitionRuleModule`

Function: `validateTransition(...)`

Inputs:
- `workflowKey`: workflow context.
- `action`: substrate action causing the proposed status relation.
- `fromStatus`, `toStatus`: proposed recognised-state status relation.
- `outcome`: challenge outcome when the transition is challenge-derived.

Output: none.

Success semantics: no transition-rule veto only. It cannot create a transition.

Allowed failure: revert for disallowed workflow transition.

Must not do: mutate status, write transition record, permit substrate-forbidden
high-impact paths, or override challenge outcome rules.

Gates:
- Before: target recognised state and package identity are substrate-owned.
- After: substrate hard gates still control generic transition limits,
  challenge mutation rules, restoration rules, and transition-ledger writes.

### `IChallengeWindowRuleModule`

Functions: `supportsChallengeWindowRule()`,
`validateChallengeWindowDuration(...)`

Inputs: `workflowKey`, `recognisedStateId`, challenge-window `openedAt`,
current chain time, and actor.

Success semantics: optional transition-rule extension for packages that want a
minimum challenge-window duration before review recognition can vest. The
substrate calls the duration validator only when `supportsChallengeWindowRule()`
returns true; a declared validator revert, including a bare revert, is a veto.

Must not do: schedule execution, close challenges automatically, decide truth,
mutate state, or bypass the open-challenge count.

### `IDisclosurePolicyModule`

Functions:
- `validateDisclosurePolicy(uint256 disclosurePolicyId)`
- `validateDisclosureForAction(...)`

Inputs:
- `disclosurePolicyId`: off-chain policy reference; `0` is allowed only where
  the substrate path treats disclosure as unspecified.
- `actingRole`, `action`, `stage`, `objectId`, `workflowKey`, `packageId`:
  call context. `packageId` is the stable rule-package identity attached to
  the target object or path being validated; modules must not substitute the
  workflow key's current active package for historical targets.
- `subjectCommitment`: subject-scoped commitment/reference for disclosure
  checks; not a reveal instruction.

Output: none.

Success semantics: no disclosure-policy veto only.

Allowed failure: revert for missing, incompatible, or unsupported policy.

Must not do: reveal identity, reveal/decrypt evidence, implement production
ACL, mutate records, or decide publication.

Gates:
- Before: path-owned authority/evidence/package checks run where applicable.
- After: attribution, verification, evidence policy, lifecycle, and storage
  gates may still run.

### `IDisclosureLifecycleModule`

Function: `validateDisclosureLifecycle(...)`

Inputs: `workflowKey`, `action`, registered `disclosurePolicyId`,
`DisclosureLifecycleKind kind`, `lifecycleReference`, and `actor`.

Output: none.

Success semantics: no readiness veto only. It records no reveal by itself.

Allowed failure: revert for incompatible readiness kind/reference/policy.

Must not do: reveal/decrypt identity or evidence, implement ACL, or mutate
policy/readiness storage.

Gates:
- Before: `AVARulePackageRegistry.recordDisclosureLifecycleReadiness` checks
  role authority, nonzero fields, active workflow package, and disclosure
  policy existence.
- After: substrate writes only a disclosure lifecycle readiness record.

### `IChallengeLifecycleModule`

Function: `validateChallengeAction(ChallengeLifecycleContext context)`

Inputs:
- `workflowKey`, `action`: challenge workflow context.
- `fromLifecycleStatus`, `toLifecycleStatus`: proposed challenge lifecycle
  movement.
- `outcome`: proposed or current challenge outcome.
- `challengedStateStatus`, `proposedStateStatus`: recognised-state status
  relation for the challenge action.
- `actor`: current caller.
- `filedBy`: original challenger account.

Output: none.

Success semantics: no challenge-lifecycle veto only.

Allowed failure: revert for inadmissible lifecycle movement or package rule.

Must not do: mutate challenge or recognised-state records, sanction anyone,
update standing, allocate value, reveal identity, or erase history.

Gates:
- Before: target recognised state, package identity, subject binding, evidence
  existence, and authority checks are substrate-owned.
- After: transition rule, residual authority, challenge transition record,
  recognised-state transition record, and mutation rules may still veto.

### `IEvidencePolicyModule`

Function: `validateEvidencePolicy(...)`

Inputs: `workflowKey`, `actingRole`, `action`, `evidenceReceiptId`,
`evidenceTypeHash`, and `actor`.

Output: none.

Success semantics: no evidence-policy veto only.

Allowed failure: revert for unsupported workflow/action/type/reference.

Must not do: inspect evidence content, validate truth, reveal content, create
or mutate evidence receipts.

Gates:
- Before: evidence registration or usable active evidence/workflow checks are
  handled by `EvidenceCommitmentRegistry` / consuming substrate paths.
- After: evidence lifecycle, attribution/verification, field, anti-abuse, and
  storage gates may still run.

### `IEvidenceLifecycleModule`

Function: `validateEvidenceLifecycle(...)`

Inputs: `workflowKey`, `action`, `evidenceReceiptId`, `kind`,
`replacementEvidenceReceiptId`, `lifecycleReference`, and `actor`.

Output: none.

Success semantics: no evidence-lifecycle veto only.

Allowed failure: revert for incompatible lifecycle kind, replacement
reference, lifecycle reference, or action.

Must not do: delete, reveal, decrypt, judge, or adjudicate evidence.

Gates:
- Before: `recordEvidenceLifecycleHook` requires independent
  `RecordEvidenceLifecycle` authority; target evidence must be active and
  workflow/package-bound; replacement receipt existence, active status, and
  workflow/package binding are substrate checks where replacement is supplied.
- After: substrate may record an evidence lifecycle record and update the
  receipt to a terminal non-active status.

### `IAuditAdapter`

Function: `validateAuditRecord(...)`

Inputs: `workflowKey`, `actingRole`, `action`, path-scoped `objectId`,
`evidenceReceiptId`, `attestationHash`, and `actor`.

Output: none.

Success semantics: no audit veto only. It is not an attestation write.

Allowed failure: revert for invalid audit reference or hash.

Must not do: write authoritative audit records outside the audit module, reveal
evidence, grant authority, or judge truth.

Gates:
- Before: `AttestationAuditModule` checks authorityId binding, target package,
  usable active evidence/workflow, object reference, and nonzero hash/type.
- After: substrate writes the attestation record.

### `IEditorialSystemAdapter`

This is an optional external-reference bridge for manuscript metadata. It is
not an AVA core stage interface, not an allocation/consequence interface, and
not publication logic.

Function: `validateEditorialReference(...)`

Inputs: `workflowKey`, `actingRole`, `action`, manuscript/path `objectId`,
`externalReferenceURI`, and `actor`.

Output: none.

Success semantics: no metadata-reference veto only.

Allowed failure: revert for invalid external reference or role/context.

Must not do: accept/reject manuscripts, score merit, alter manuscript storage,
or create publication logic.

Gates:
- Before: manuscript author authority and object reference are substrate-owned;
  the workflow-aware overload requires a known active workflow package before
  optional external-reference validation.
- After: manuscript storage remains substrate-owned.

### `IResidualEditorialAuthorityModule`

Function: `validateResidualEditorialAuthority(ResidualEditorialAuthorityContext context)`

Inputs: `workflowKey`, `actingRole`, `action`, `recognisedStateId`, path-scoped
`objectId`, `evidenceReceiptId`, `authorityId`, and `actor`.

Output: none.

Success semantics: no procedural-authority veto only.

Current example modules include `ProceduralEditorialAuthorityModule` for a
single allowed action and `StructuredResidualEditorialAuthorityModule` for
validator-only single-role, threshold-panel, multisig,
institutional-co-signature, conflict-excluded-panel, and emergency-pause
formats. The receipt-backed example pairs `AuthorityApprovalRegistry` with
`ApprovalReceiptAuthorityModule`: panel subjects record package/action/object
approval receipts, and the residual authority module checks m-of-n active
receipts plus optional conflict exclusion. These examples express authority
predicates only; they do not mutate substrate state or execute publication,
reveal, sanction, reward, or payment effects.

Allowed failure: revert for incompatible procedural authority context.

Must not do: create acceptance/rejection/merit/publication selectors, grant
authority, mutate records, or override authorityId binding.

Gates:
- Before: substrate has already checked `authorityId` against the caller for
  authority-bearing paths and resolved target package.
- After: transition/storage gates still run.

### `IFieldPolicyModule`

Function: `validateFieldPolicy(...)`

Inputs: `workflowKey`, `actingRole`, `action`, `stage`, path-scoped `objectId`,
and `evidenceReceiptId`.

Output: none.

Success semantics: no field-policy veto only.

Allowed failure: revert for field/stage/action incompatibility.

Must not do: judge scientific truth, rewrite object ids, or override
authority/evidence/status gates.

Gates:
- Before: evidence and package checks have run for evidence-backed paths.
- After: anti-abuse, residual authority, and storage may still veto.

### `IAntiAbuseModule`

Function: `validateUse(...)`

Inputs: `workflowKey`, `actingRole`, `action`, role-scoped `subjectId`,
path-scoped `objectId`, and `actor`.

Output: none.

Success semantics: no anti-abuse veto only.

Allowed failure: revert for rate-limit, abuse, incompatible subject/object, or
unsupported context.

Must not do: sanction, apply punitive asset deduction, update standing, mutate
records, reveal identity, or write counters in the current demo interface.

### `IChallengeRateLimitModule`

Functions: `supportsChallengeRateLimit()`, `validateChallengeFiling(...)`

Inputs: `workflowKey`, challenged recognised-state id, challenger subject,
prior filing count for the same package / challenged state / challenger subject
path, and actor.

Success semantics: optional anti-abuse extension for packages that want to veto
repeated challenge filing by the same role-scoped subject against the same
recognised state. The substrate calls the filing validator only when
`supportsChallengeRateLimit()` returns true; a declared validator revert,
including a bare revert, is a veto. The bundled example treats any prior filing
on the same package / recognised state / challenger subject path as enough to
reject the next one; other packages may bind a different module.

Must not do: execute sanctions, update standing, block good-faith challenge
resolution, or create public consequences.

Gates:
- Before: subject and evidence/package checks are substrate-owned.
- After: substrate writes or aborts the requested record/transition.

### Layer C: Downstream Consequence / Execution / Proof Support

### `IStandingAdapter`

Function: `validateStandingUpdate(...)`

Inputs: `actingRole`, `recognisedStateId`, target `subjectId`, `dimension`,
`delta`, `evidenceReceiptId`, `authorityId`, `uri`, and `actor`.

Output: none.

Success semantics: no standing-update veto only; not reputation application.
The substrate requires the target subject to match the source recognised
state's responsible subject.

Allowed failure: revert for invalid dimension, target, evidence, authority, or
workflow policy.

Must not do: calculate aggregate reputation, publish prestige, grant service
entitlements, mint/transfer/consume anything from standing or reputation
records, affect manuscripts, or write standing records.

Gates:
- Before: allowed recognised-state status, known active subject, authorityId
  binding, and usable active evidence/workflow are substrate checks.
- After: substrate records only the standing update/readiness record.

### `IStandingComputationModule`

Function: `validateStandingComputation(StandingComputationContext context)`

Inputs: `recognisedStateId`, `subjectId`, `dimension`, `vectorKey`,
`currentValue`, `delta`, `effectiveAt`, `reversible`, `fieldKey`,
`epoch`, `sourceRecordSetHash`, `computationRuleHash`, `evidenceReceiptId`,
`authorityId`, and `actor`.

Output: none.

Success semantics: no vector-computation veto only; not aggregate score
application.

Allowed failure: revert for invalid vector/dimension/provenance fields or
forbidden public-score semantics.

Current Formula V0 example: `FormulaV0StandingComputationModule` validates the
four demo vectors (`review_reliability`, `challenge_integrity`,
`correction_responsiveness`, and `procedural_participation`), requires the
dimension hash to match `vectorKey`, requires the Formula V0 computation-rule
hash, requires reversible bounded output, and rejects missing provenance fields.
It does not compute complete historical standing or apply standing.

Must not do: create public prestige, single-score reputation, manuscript merit,
asset-like standing/reputation object, reward-bearing credential, transferable
credential, administrative-priority artifact, or storage mutation.

Gates:
- Before: standing substrate checks recognised-state status, subject, evidence,
  and authority references.
- After: standing adapter or substrate record write may still run.

Credential boundary: an authorised active standing-computation record may later
be used by `StandingCredentialRegistry` to issue a non-transferable and expiring
proof carrier. The credential must match the source computation's epoch and
computation-rule hash, and the source computation must remain active for proof
checks. The credential must not be transferable, approvable, consumable,
stakeable, or treated as standing itself. It is not reputation, not a reward,
not an administrative-priority artifact, not a public-prestige NFT, and not a
balance.

### `IStandingCredentialIssuer`

Functions:

```solidity
issueCredential(Role actingRole, StandingCredentialInput input)
revokeCredential(Role actingRole, uint256 credentialId, bytes32 authorityId, string uri)
supersedeCredential(Role actingRole, uint256 credentialId, StandingCredentialInput input)
recordStandingRelevantSettlement(
    Role actingRole,
    uint256 credentialId,
    StandingRelevantSettlementKind kind,
    ExecutionSourceType sourceType,
    uint256 sourceRecordId,
    uint256 settlementId,
    bytes32 authorityId,
    string uri
)
credentialProves(
    uint256 credentialId,
    bytes32 subjectId,
    bytes32 vectorKey,
    bytes32 categoryHash,
    int256 requiredThreshold
)
credentialProvesSubjectStanding(
    uint256 credentialId,
    uint256 packageId,
    bytes32 subjectId,
    bytes32 vectorKey,
    bytes32 categoryHash,
    int256 requiredThreshold
)
activeStandingCredentialId(
    uint256 packageId,
    bytes32 subjectId,
    bytes32 vectorKey,
    bytes32 categoryHash
)
getStandingCredential(uint256 id)
getStandingCredentialSettlement(uint256 id)
```

Inputs include the source active standing-computation record id, category hash,
threshold/range, epoch, expiry, computation-rule hash, authority subject, and
off-chain URI.

Success semantics: `issueCredential` records a proof carrier that binds the
source active standing computation, recognised state, workflow key, stable
`packageId`, role-scoped subject, holder account, dimension/vector/category,
standing value, threshold/range, epoch, issue time, expiry time, evidence
receipt id, computation-rule hash, and authority subject. `credentialProves`
returns true only for an active, unexpired, non-revoked, non-superseded
credential whose source computation remains active and that matches the
requested subject, vector, category, and threshold.
`credentialProvesSubjectStanding` adds a stable `packageId` check and uses only
the role-scoped subject identifier or subject commitment; it does not require
the holder account or public identity in the proof call. Both proof helpers
fail closed for wrong package, subject, vector, category, threshold, or range
requests. `activeStandingCredentialId` is a bounded lookup for validator
modules that need the current active credential for a package/subject/vector
and category. The active index is latest-issued-wins for that key: older
credential ids remain inspectable through explicit id lookup, but validator
gates that use the active index follow the most recent indexed credential and
fail closed when it is unusable. It returns zero if no matching credential
exists or if the indexed credential is expired, revoked, superseded, suspended,
or backed by an inactive computation.
`supersedeCredential` requires the replacement credential to stay within the
same stable `packageId`, subject, dimension/vector, category, and computation
rule, and to use a strictly higher epoch.
`recordStandingRelevantSettlement` records an authorised settlement impact,
validates that the source allocation or consequence record is bound to the
credential's subject and stable `packageId`, validates that the referenced
value-settlement record exists and matches the same source, subject, package
identity, and settlement-impact kind, and suspends the credential so it cannot
be used as active proof until a fresh standing computation issues a new
credential. Unknown, unrelated, wrong-subject, wrong-package, or wrong-kind
settlement references fail without suspending the credential.

Allowed failure: revert for unknown standing-computation records, raw review,
raw challenge, or raw evidence ids used as source ids, inactive or unknown
subjects, invalid range/threshold/epoch/expiry/category/rule metadata,
authority-subject mismatch, package/evidence mismatch, empty URI, unknown
credential id, invalid revocation/supersession target, unknown or mismatched
settlement source, empty settlement reference, or non-active credential
settlement target.

Must not do: compute standing from scratch, create standing or reputation,
create reward, mint administrative priority, transfer/approve/trade/stake or
consume the credential, transfer payment, execute sanction, reveal identity or
evidence, affect reviewer leniency, affect manuscript merit, or decide
publication.

Gates:
- Before: `StandingRegistry` has already recorded an authorised
  standing-computation readiness record over an allowed recognised state.
- During: `StandingCredentialRegistry` checks `IssueStandingCredential`,
  `RevokeStandingCredential`, or `SupersedeStandingCredential` authority with a
  bound authority subject; validates source computation, target recognised
  state, stable package identity, evidence receipt workflow, active role-scoped
  subject, expiry, and threshold/range metadata.
- After: only the credential record or credential-settlement record changes.
  Transfer and approval functions revert, `getApproved` returns no approval,
  and `isApprovedForAll` returns false.

### `IRewardAdapter`

Function: `validateRewardRecord(...)`

Inputs: `actingRole`, `recognisedStateId`, target `subjectId`,
`amountOrUnits`, `evidenceReceiptId`, `authorityId`, `uri`, and `actor`.

Output: none.

Success semantics: no reward-record veto only; not entitlement or transfer.

Allowed failure: revert for invalid record context.

Must not do: transfer value, mint token, affect manuscripts, or write records.

Gates:
- Before: allocation substrate and value-readiness gates run.
- After: substrate writes an `AllocationKind.RewardValueRecord` only.

### `IPriorityAdapter`

Function: `validatePriorityRecord(...)`

Inputs: `actingRole`, `recognisedStateId`, target `subjectId`,
`amountOrUnits`, `evidenceReceiptId`, `authorityId`, `uri`, and `actor`.

Output: none.

Success semantics: no administrative-priority record veto only.

Allowed failure: revert for invalid priority-readiness context.

Must not do: grant publication priority, reviewer leniency, acceptance
probability, queue execution, or manuscript advantage.

Gates:
- Before: allocation substrate and value-readiness gates run.
- After: substrate writes an `AllocationKind.AdministrativeQueueRecord` only.

### `IConsequenceAdapter`

Function: `validateConsequence(...)`

Inputs: `actingRole`, `recognisedStateId`, `ConsequenceKind kind`, target
`subjectId`, `evidenceReceiptId`, `authorityId`, `uri`, and `actor`.

Output: none.

Success semantics: no consequence-record veto only.

Allowed failure: revert for invalid bounded administrative consequence
context.

Must not do: execute sanction, update standing, execute allocation, create
reward, affect publication, or write records.

Gates:
- Before: allowed recognised-state status, responsible recognised-state
  subject, evidence, authority, anti-abuse, and value-readiness checks run.
- Subject boundary: the named consequence subject must match the responsible
  subject recorded on the source recognised state in this demo. A future
  cross-subject consequence needs a separate explicit record design.
- After: substrate writes only the bounded consequence record.

### `IPenaltyAdapter`

Function: `validatePenaltyRecord(...)`

Inputs: `actingRole`, `recognisedStateId`, target `subjectId`,
`evidenceReceiptId`, `authorityId`, `uri`, and `actor`.

Output: none.

Success semantics: no penalty-record veto only; not sanction execution. Penalty
records should be interpreted as one or more of: value recovery metadata,
standing penalty input, and eligibility / screening consequence. These are
distinct effects and should not be collapsed into one punitive token action.

Allowed failure: revert for invalid penalty record context.

Must not do: apply punitive asset deduction, transfer, sanction, directly update
standing, delete reward history, or mutate records. Value recovery is handled by
source-bound recovery / settlement records; standing penalty is handled by the
next standing computation.

Gates:
- Before: consequence substrate and value-readiness gates run.
- Subject boundary: penalty and eligibility records inherit the source
  consequence's recognised-state subject binding; they are not a generic
  cross-subject sanction path.
- After: substrate writes a `ConsequenceKind.PenaltyRecord` only.

### Consequence penalty input / eligibility records

Functions:

```solidity
recordStandingPenaltyInput(
    Role actingRole,
    uint256 penaltyConsequenceId,
    uint256 challengeId,
    StandingPenaltyKind penaltyKind,
    string dimension,
    int256 delta,
    uint256 evidenceReceiptId,
    bytes32 authorityId,
    string uri
)
recordEligibilityRestriction(
    Role actingRole,
    uint256 penaltyConsequenceId,
    uint256 challengeId,
    EligibilityRestrictionKind restrictionKind,
    uint256 expiresAt,
    uint256 evidenceReceiptId,
    bytes32 authorityId,
    string uri
)
getStandingPenaltyInput(uint256 id)
getEligibilityRestriction(uint256 id)
activeEligibilityRestrictionId(
    uint256 packageId,
    bytes32 subjectId,
    EligibilityRestrictionKind restrictionKind
)
hasActiveEligibilityRestriction(
    uint256 packageId,
    bytes32 subjectId,
    EligibilityRestrictionKind restrictionKind
)
```

Success semantics: append a record tied to an existing
`ConsequenceKind.PenaltyRecord`. Standing penalty input records are negative
inputs for later standing computation only. Eligibility restrictions are
separate bounded procedural records. Standing penalty input requires a nonzero
challenge id with a compatible outcome. `AcademicFraud` and
`IrresponsibleReview` require an upheld challenge linked to the target
recognised state. `NegligentChallenge` and `MaliciousOrFabricatedChallenge`
require the corresponding challenge-abuse outcome and challenger subject.
`RejectedGoodFaith` challenges cannot become misconduct standing-penalty or
eligibility-restriction records. Challenge-intake eligibility restrictions
must be linked to a negligent or malicious/fabricated challenge outcome for the
restricted challenger subject. The active lookup helpers are package-bound and
return zero after expiry or when no matching active restriction exists. The
current demo has no early-lift function; a restriction remains active until
`expiresAt` unless a later version adds an explicit restriction-supersession or
restriction-lift record.

Must not do: update standing directly, transfer value, execute sanction, erase
reward history, create public reputation score, create token balance, or affect
publication.

### `IRestorationAdapter`

Function: `validateRestorationRecord(...)`

Inputs: `actingRole`, `recognisedStateId`, target `subjectId`,
`evidenceReceiptId`, `authorityId`, `uri`, and `actor`.

Output: none.

Success semantics: no restoration-record veto only.

Allowed failure: revert for invalid restoration record context.

Must not do: silently overwrite status, erase history, mint reward, or mutate
records.

Gates:
- Before: restoration transition/history or consequence substrate checks run.
- After: substrate writes only the restoration consequence record.

### `IValueExecutionAdapter`

Function: `validateValueExecution(ValueExecutionContext context)`

Inputs: `recognisedStateId`, `asset`, `payer`, `recipientSubjectId`, `amount`,
`mode`, `settlementKind`, `executionReference`, `authorityId`,
`evidenceReceiptId`, `uri`, and `actor`.

Output: none.

Success semantics: no value-readiness veto only. The same context should be
able to describe reward execution readiness and lossless recovery readiness,
including forfeiture, repayment obligation, future payout setoff, waiver,
satisfaction, restoration, and source-bound clawback-transfer reference.

Allowed failure: revert for unsupported mode, invalid reference, or
incompatible package policy.

Must not do: transfer token/stablecoin, execute queue, execute sanction,
create payment, delete history, directly update standing, or write records. In allocation and consequence record paths,
`asset`, `payer`, `amount`, `mode`, `settlementKind`, and
`executionReference` are readiness fields only. The separate
`ValueSettlementExecutor` may later consume an already-stored authorised record;
the adapter itself remains validator-only.

Gates:
- Before: downstream substrate checks recognised state, subject, authority,
  evidence, and package identity.
- After: domain-specific allocation/reward/priority/consequence/penalty/
  restoration adapter and substrate record write may still run.

### `IValueSettlementExecutor`

Functions include token transfer settlement, escrow deposit/claim/refund,
priority-token mint/consume, repayment-obligation / future-setoff / waiver /
satisfaction receipts, and source-bound clawback-transfer settlement over
existing allocation or consequence records.

Inputs include the source type, source record id, acting role, authority id,
and settlement URI.

Success semantics: a settlement receipt is written and the mock asset operation
is executed only for a source record that already passed recognised-state,
evidence, package, subject, authority, and value-readiness gates. Recovery
settlements must preserve the original grant / execution record and append the
recovery, setoff, waiver, satisfaction, reversal, or restoration receipt. The
stored receipt also carries the source execution mode, source settlement kind,
source execution reference, and `settlementContextHash` for auditability.

Allowed failure: revert for unknown source records, record-only sources on
active execution or recovery paths, wrong execution mode, wrong settlement kind,
duplicate final settlement, missing authority, unknown subject, missing
amount/reference, missing asset/payer where active execution needs them, or
non-authorised caller.

Must not do: create allocation/consequence/standing records, compute
reputation, decide publication, grant manuscript advantage, reveal evidence,
directly seize unrelated wallet assets, delete prior reward history, or execute
sanctions. Priority tokens are administrative-priority artifacts only; they are
not standing, reputation, scholarly conduct, or manuscript merit.

Gates:
- Before: allocation or consequence source records already exist and carry
  package id, evidence id, subject id, execution mode, settlement kind, and
  authority metadata.
- During: `ValueSettlementExecutor` performs its own role/action authority gate
  before calling token/priority external contracts, checks the requested
  settlement kind against the stored source kind, rejects duplicate final
  settlement on active execution paths, rejects recovery receipts on open or
  refunded escrow paths, and records source-bound recovery receipts only from
  active value-settlement sources. Repayment obligation is non-terminal; future
  setoff, waiver, and satisfaction are mutually exclusive terminal recovery
  receipts for a source. `computeSettlementContextHash` is a read-only audit
  helper over the source record, source execution fields, recipient, settlement
  kind, and settlement status.

### `IDisclosureExecutionModule`

Function: `validateDisclosureExecution(DisclosureExecutionContext context)`.

Inputs include workflow key, disclosure execution kind, target kind/id,
disclosure policy id, subject id or subject commitment/nullifier for anonymous
proof use, proof receipt id, and actor.

Success semantics: no disclosure-execution veto only. The module does not
grant access by itself; `DisclosureAccessExecutor` writes access grant,
revocation, expiry, supersession, lifecycle-execution, voluntary-intent, or
anonymous-proof-use records.

Allowed failure: revert for incompatible workflow, target, disclosure-policy,
subject, proof, or lifecycle kind.

Must not do: reveal identity, reveal/decrypt evidence, implement production
ACL, judge truth, alter recognised states, update standing, execute payment, or
affect publication.

Gates:
- Before: `DisclosureAccessExecutor` validates authority, target existence,
  target workflow, disclosure policy existence, proof receipt/nullifier where
  relevant, grant closure status where relevant, and the target package's
  `IDisclosureExecutionModule` binding. Re-registering a workflow key does not
  retroactively change the disclosure execution module used for already-recorded
  targets.
- After: only a disclosure execution receipt is recorded. Access-grant
  revocation, expiry, and supersession closure receipts carry
  `sourceDisclosureExecutionId` for the grant they close; expiry uses the
  `Expired` status and supersession uses the `Superseded` status. Generic
  lifecycle receipts remain target-level readiness/execution records and do not
  close a grant. Anonymous challenge proof-use receipts additionally store the
  referenced proof receipt's proof context hash, verifier, and proof-domain
  hash. These records do not enforce production access.

### `IExternalOperationRegistry`

Functions record external operation intents and status receipts:
`requestOperation`, `acknowledgeOperation`, `cancelOperation`, and
`supersedeOperation`.

Inputs include workflow key, operation kind, target kind/id, evidence receipt
id, authority id, and reference URI.

Success semantics: an operation receipt is recorded. The contract does not
integrate with or command any external platform. Each requested operation can
have at most one terminal status receipt, tracked by
`terminalReceiptIdByOperation`; terminal receipts also carry `sourceOperationId`
so the receipt itself remains linked to its request. Every operation receipt
also carries `operationContextHash`, which binds workflow key, package id,
operation kind, target kind/id, and evidence receipt id.

Allowed failure: revert for unknown target, wrong workflow, unknown evidence
receipt, missing authority, empty reference, unsupported kind/status, or
non-authorised caller.

Must not do: accept/reject manuscripts, score merit, execute publication
priority, adjust real queues, transfer value, reveal identity/evidence, or
execute sanctions.

Gates:
- Before: target recognised-state/challenge/evidence/allocation/consequence
  record exists and matches the workflow; evidence receipt exists and matches
  the workflow; caller has `RecordExternalOperation` authority.
- After: only the requested/acknowledged/cancelled/superseded receipt is stored.
  `computeOperationContextHash` is a read-only audit helper; it does not execute
  or schedule an external operation.

### `IRulePackageLifecycleModule`

Function: `validateRulePackageLifecycle(RulePackageLifecycleContext context)`

Inputs: `workflowKey`, source `modulesHash`, source `modulesCodeHash`, `kind`,
`version`, `compatibilityKey`, `dependencyURI`, `deprecated`,
`targetWorkflowKey`, `targetPackageId`, `targetModulesHash`,
`targetModulesCodeHash`, `targetVersion`, `targetCompatibilityKey`,
`authorityRole`, and `actor`. `modulesHash` includes both module
addresses/configuration and the registered module `extcodehash` aggregate; the
separate `modulesCodeHash` exposes the code-identity aggregate directly.

Output: none.

Success semantics: package-lifecycle veto only; not authority grant and not
migration execution. Object-level migration readiness, when recorded through
`AVARulePackageRegistry.recordObjectMigrationReadiness`, is a separate
record-only receipt bound to an existing `MigrationReady` lifecycle record.
The registry uses configured state/evidence readers to require that the named
recognised state and evidence receipt belong to the lifecycle record's source
workflow/package before the readiness receipt is stored.
Those readers are configured once through `configureMigrationReferenceReaders`
by an authority subject with rule-package registration permission.

Allowed failure: revert for incompatible module composition, unsupported
version, wrong compatibility key, deprecated package, missing target package
context, or incompatible target package context.

Must not do: mutate existing packages, rewrite old recognised states, migrate
state, or override rule-package authority.

Gates:
- Before: `AVARulePackageRegistry` checks caller authority, nonzero module
  addresses, nonzero deployed module code, nonzero version/compatibility key,
  computes `modulesCodeHash`, computes `modulesHash`, and resolves known target
  package metadata for migration/supersession readiness records. The workflow-key
  path resolves the currently active package; the package-bound path accepts an
  explicit source `packageId` and target `packageId`.
- After: registry assigns a new immutable `packageId`, stores package metadata,
  stores source and target module hash / code-hash / version / compatibility
  metadata on readiness records, rechecks stored module code identity on package
  reads, points `workflowKey` to the new active package, and may store
  object-level migration readiness receipts without moving the object.

### `IZKProofVerifier`

Function: `verify(bytes32 contextHash, SchnorrProof proof) returns (bool)`

Inputs:
- `contextHash`: substrate-built proof context hash.
- `proof.publicKey`, `proof.commitment`, `proof.response`: verifier-specific
  proof fields.

Output:
- `bool`: cryptographic verification result for the provided context/proof.

Success semantics: `true` means the proof verifies for the context under this
verifier. It does not reveal identity, grant authority, create membership
status, validate evidence truth, or prove manuscript merit.

Allowed failure: return `false` or revert for unsupported/malformed proof.

Must not do: reveal/decrypt identity or evidence, mutate substrate storage,
register proof receipts, or grant access.

Gates:
- Before: `ZKProofRegistry` checks workflow package existence, disclosure
  policy existence, nonzero context/nullifier/commitment, and replay.
- After: `ZKProofRegistry` stores a proof receipt with the active package id and
  package-aware context/nullifier bindings, verifier address, and proof-domain
  hash only if the verifier returns `true`.
  Target-package validation uses `computeDisclosureContextHashForPackage` so a
  proof for a new active package cannot satisfy an old target, and an old proof
  cannot satisfy a new target.
- Historical target note: `registerProofForPackage` may be used when a proof
  receipt must be created for an immutable package id after the workflow's
  active package pointer has moved. The package id must exist and must belong
  to the supplied workflow key. This does not change storage semantics or allow
  a new package proof to satisfy an old package target.

### `IStandingFormulaRegistry`

Functions:

```solidity
registerStandingFormula(Role actingRole, StandingFormulaInput input)
registerSourceSetCommitment(Role actingRole, SourceSetCommitmentInput input)
registerSourceSetCompletenessAttestation(
    Role actingRole,
    SourceSetCompletenessAttestationInput input
)
registerStandingComputationStatement(
    Role actingRole,
    StandingComputationStatementInput input
)
supersedeStandingComputationStatement(
    Role actingRole,
    uint256 oldStatementId,
    StandingComputationStatementInput input
)
invalidateStandingComputationStatement(
    Role actingRole,
    uint256 statementId,
    uint256 evidenceReceiptId,
    bytes32 authorityId,
    string uri
)
proofInputMatchesRegisteredCommitment(
    bytes32 workflowKey,
    bytes32 subjectCommitment,
    bytes32 vectorKey,
    bytes32 categoryHash,
    uint256 epoch,
    bytes32 sourceRecordSetRoot,
    bytes32 computationRuleHash,
    address verifier
)
getSourceSetCommitmentIdForPackageProofInput(
    uint256 packageId,
    bytes32 workflowKey,
    bytes32 subjectCommitment,
    bytes32 vectorKey,
    bytes32 categoryHash,
    uint256 epoch,
    bytes32 sourceRecordSetRoot,
    bytes32 computationRuleHash,
    address verifier
)
isSourceSetCompletenessAttestationActive(uint256 id)
isStandingComputationStatementActive(uint256 id)
getStandingFormula(uint256 id)
getSourceSetCommitment(uint256 id)
getSourceSetCompletenessAttestation(uint256 id)
getStandingComputationStatement(uint256 id)
```

Formula inputs bind workflow key, active package id, vector key, formula
version, computation-rule hash, source-set policy hash, decay/cap/restoration
policy hashes, verifier reference, authority id, metadata URI, registered actor,
and authority role.

Source-set commitment inputs bind formula id, workflow key and package id
inherited from the formula, subject commitment, vector key, category hash,
epoch, source-record-set root, computation-rule hash, source-set policy hash,
source-set evidence receipt, completeness attestation hash, authority id,
metadata URI, registered actor, and authority role.

Source-set completeness attestation inputs bind a source-set commitment to an
included-record-classes hash, exclusion-policy hash, package-bound evidence
receipt, completeness attestation hash, authority subject, and URI. The
attestation must match the source-set commitment and is an audit record, not a
proof that the private source set is actually complete.

Standing computation statement inputs bind the authorised off-chain computation
output to an active source-set commitment and active completeness attestation:
workflow/package, subject commitment, vector/category/range, epoch, source root,
computation-rule hash, output commitment, verifier/proof-domain, evidence
receipt, authority subject, and URI. Statements can be superseded by a matching
newer-epoch statement or invalidated with package-bound evidence. Superseded or
invalidated statements cannot support active standing proof or credential use.

Trust-boundary semantics: this interface is the chain-side registry for an
off-chain or future-ZK standing computation result. It makes formula identity,
source-set policy, source-record-set root, verifier choice, completeness
attestation, and output commitment auditable before a ZK standing proof receipt
can be accepted, but it is not itself a calculator, indexer, completeness
prover, or credential issuer.

Success semantics: records audit-visible standing formula metadata, source-set
commitments, completeness attestations, and computation statements only when
the caller has the corresponding authority and all evidence receipts are usable
receipts for the same workflow package as the formula/source-set/statement.

Allowed failure: revert for unauthorised caller, unknown workflow package,
zero vector/formula/rule/policy/verifier/authority/URI fields, duplicate
formula key, unknown formula id, inactive formula, unknown or wrong-package
source-set or statement evidence receipt, zero subject/category/epoch/source
root/completeness/output fields, duplicate source-set proof key, mismatched or
inactive completeness attestation, stale statement, same/lower-epoch
supersession, or invalidation without package-bound evidence.

Must not do: compute standing, traverse full history on chain, prove source-set
completeness by itself, reveal identity/evidence, issue credentials, create
standing/reputation, mint reward or priority artifacts, transfer value, execute
sanction, or affect publication.

### `ZKStandingComputationRegistry`

Functions:
- `registerStandingProof(StandingProofInput input, SchnorrProof proof)`
- `computeStandingComputationContextHash(StandingProofInput input)`
- `computeNullifierHash(bytes32 contextHash, bytes32 subjectCommitment)`
- `standingProofSupportsCredential(uint256 receiptId, uint256 packageId, bytes32 subjectCommitment, bytes32 vectorKey, bytes32 categoryHash, int256 requiredThreshold)`
- `getStandingProofReceipt(uint256 id)`

Inputs bind the active workflow package, subject commitment, vector/category,
standing value, threshold/range, epoch, source-record-set root, computation
rule hash, verifier proof domain, output commitment, and an exact active
computation statement over a registered formula/source-set commitment.

Success semantics: records a standing-specific proof receipt only when the
context is nonzero, the active workflow package exists, the proof public key
matches the subject commitment, the verifier accepts the package-bound context,
the input matches a registered source-set commitment and active computation
statement whose formula binds the same verifier, and the context/nullifier has
not already been registered. The receipt stores formula id, source-set
commitment id, standing-computation statement id, output commitment, formula
version, source-set policy hash, verifier address, and proof-domain hash.

Allowed failure: revert for unknown workflow package, zero subject/vector/
category/source root/rule/epoch fields, invalid threshold/range/value shape,
missing formula/source-set commitment, verifier mismatch, subject-commitment
mismatch, missing or inactive computation statement, output commitment mismatch,
verifier rejection, or context/nullifier replay.

Must not do: reveal identity or evidence, compute complete historical standing,
issue standing credentials directly, create standing/reputation, mint token or
reward, transfer value, execute sanction, or affect publication.

Credential boundary: `standingProofSupportsCredential` is a read-only gate for
future privacy-preserving credential issuance. It checks package, subject
commitment, vector, category, threshold, and range against a stored proof
receipt and also requires the referenced computation statement to remain
active. It does not create or transfer any credential by itself.

### `IZKStandingCredentialIssuer`

Functions:

```solidity
issueCredential(Role actingRole, ZKStandingCredentialInput input)
revokeCredential(
    Role actingRole,
    uint256 credentialId,
    bytes32 subjectCommitment,
    bytes32 authorityId,
    string uri
)
supersedeCredential(Role actingRole, uint256 credentialId, ZKStandingCredentialInput input)
recordSettlementBoundSuspension(
    Role actingRole,
    uint256 credentialId,
    StandingRelevantSettlementKind kind,
    ExecutionSourceType sourceType,
    uint256 sourceRecordId,
    uint256 settlementId,
    bytes32 authorityId,
    string uri
)
recordChallengeTransitionBoundSuspension(
    Role actingRole,
    uint256 credentialId,
    uint256 challengeTransitionId,
    bytes32 authorityId,
    string uri
)
credentialProves(
    uint256 credentialId,
    uint256 packageId,
    bytes32 subjectCommitment,
    bytes32 vectorKey,
    bytes32 categoryHash,
    int256 requiredThreshold
)
recordCredentialUse(ZKStandingCredentialUseInput input, SchnorrProof proof)
computeCredentialCommitment(G1Point publicKey)
computeCredentialUseContextHash(
    uint256 credentialId,
    uint256 packageId,
    bytes32 subjectCommitment,
    bytes32 vectorKey,
    bytes32 categoryHash,
    int256 requiredThreshold,
    bytes32 targetContextHash
)
```
- `computeCredentialUseNullifierHash(bytes32 useContextHash, bytes32 credentialCommitment)`
- `isCredentialActive(uint256 credentialId)`
- `getCredential(uint256 id)`
- `getCredentialUseRecord(uint256 id)`
- `getCredentialSuspensionRecord(uint256 id)`

Loose credential suspension is not exposed. Standing-relevant ZK credential
suspension must use one of the source-bound paths.

Inputs bind a ZK standing proof receipt to package id, subject commitment,
credential commitment, credential nullifier, vector/category, threshold/range,
epoch, source-record-set root, computation-rule hash, source computation
statement id, expiry, and authority.

Namespace note: when a ZK standing credential is suspended by a source-bound
value settlement or challenge-transition record, the credential's
`subjectCommitment` is treated as the same pseudonymous role-scoped subject
identifier used by the source record. It is not a real-name identity and it is
not an account owner field.

Success semantics: records a commitment-bound standing credential proof carrier
only when the caller has `IssueStandingCredential` authority and the supplied
fields match the source ZK standing proof receipt and its active computation
statement. Credential use records are target/nullifier-bound, require a verifier
proof whose public key matches the stored credential commitment, and reject
replay. Credentials can be revoked, superseded, or suspended by authorised
roles. Source-bound suspension paths additionally write an append-only
`ZKStandingCredentialSuspensionRecord`
before marking a credential suspended. Settlement-bound suspension requires the
referenced value-settlement record to match the credential package,
subject commitment, source record, source type, and standing-relevant
settlement kind. Challenge-transition-bound suspension requires an
outcome-resolution transition for the same package and challenger subject
commitment, and accepts negligent or malicious/fabricated outcomes while
rejecting rejected-good-faith outcomes.

`isCredentialActive` is intentionally only a local carrier-status helper:
it checks whether the credential has not expired and has not been revoked,
superseded, or suspended. It is not a sufficient standing proof by itself.
Consumers that need a current standing signal must call `credentialProves` or
record a target-bound credential-use receipt, because those paths also re-check
the referenced ZK standing proof receipt and computation statement.

Allowed failure: revert for unknown proof receipt, wrong package, wrong subject
commitment, wrong vector/category, invalid threshold/range, mismatched epoch,
source root, rule hash, or inactive computation statement, duplicate credential
commitment or nullifier, expired input, unauthorised authority, inactive
credential, mismatched proof-use credential commitment, invalid proof-use
context/nullifier, or proof-use nullifier replay. Source-bound suspension also
reverts for unknown or
mismatched settlement ids, wrong package, wrong subject commitment, wrong
source, wrong settlement kind, unknown challenge transition id, non-resolution
transition, or good-faith rejected challenge outcome.

Must not do: store an owner account, expose `ownerOf`, `balanceOf`, transfer,
approval, reward, priority-token, standing-token, reputation-token, reveal,
decrypt, publication, sanction-execution, standing-update, payment, or
manuscript-merit surfaces.
