# Interface Contract Specification

This reference describes the inputs, checks, and limits of replaceable
modules in the local Solidity demo. The
[package integration guide](rule-package-integration-guide.md) shows how to
register those modules and test them together.

## How To Use This Spec

Start with the canonical interfaces below for a new application. The detailed
entries later in this file also cover the earlier implementation for regression
and compatibility work.

| Need | Section |
| --- | --- |
| Shared validator semantics | `Global Contract` |
| Re-verifiable module behaviour identity | `IRuleModuleIdentity` |
| Current AVA stage interfaces | `IAVAAttributionModule`, `IAVAVerificationModule`, `IAVAAllocationPolicyModule` |
| Earlier stage interfaces | `IAttributionModule`, `IVerificationModule`, `IAllocationAdapter` / `IAVAAllocationModule` |
| Recognised-state support | transition, challenge, disclosure, evidence, audit, field, anti-abuse, residual authority |
| Downstream / proof / execution support | standing, credentials, reward, priority, consequence, penalty, restoration, settlement, external operation, package lifecycle, ZK |
| Forbidden boundary check | each interface's `Must not do` clause |

## Canonical Multi-Application Interface Surface

New applications integrate through the domain-neutral contracts under
`src/core/`, `src/extensions/`, and `src/apps/`.

| Interface family | Responsibility |
| --- | --- |
| `IAVAApplicationModule` | Declares one immutable `applicationId()` and validates app-specific governed objects, state formation, transitions, evidence, and downstream vocabulary. It is validator-only and owns no Core storage. |
| `IAVACoreRuleModules` | Defines package-selected Attribution, Verification, transition, evidence, disclosure, challenge, authority, field, anti-abuse, standing, Allocation, and consequence policy contexts over generic ids and keys. `AVAWorkflowPolicyRouter` dispatches the formation, transition, and challenge-policy subsets without owning storage. |
| `IAVATransitionGuard` | Lets a package-bound extension veto a transition, but never widen Core's nondelegable transition graph. |
| `IAVAPostTransitionHook` | Receives an already-authorised transition after Core state is written; a revert rolls back atomically. The hook cannot decide transition legality. |
| `IAVAExtensionPolicyModule` | Validates optional proof, disclosure, audit, settlement, and external-operation records with app, workflow, package, state-version, subject, evidence, source, scope, payload, expiry, and authority context. |
| `IAVAStandingComputationPolicyModule`, `IAVAStandingCredentialPolicyModule` | Validate an authorised standing output or proof carrier. They do not compute truth, mint assets, or turn standing into a balance. |
| `IAVADownstreamRecordSource`, `IAVASettlementReceiptSource` | Narrow read interfaces for immutable source-bound receipt chains. Consumers must require the returned id to equal the queried id. |

The canonical `AVAStandingZKCredentialExtension` stores both the role-scoped
`subjectId` and a subject commitment. Its issuance key and supersession lineage
bind both values. This reduces disclosure of standing history but remains
role-subject-linkable; it is not an unlinkable-anonymity claim. The retained
commitment-only interface documented later has a different subject namespace.

`IAVAApplicationModule.GovernedObjectContext` includes the proposed object's
application, workflow, package, role, type, parent id, subject, evidence,
disclosure policy, authority, and actor. When a parent exists, Core also passes
the parent's workflow, package, object type, and responsible subject. Before
the module runs, Core requires the parent to share the application and package
compatibility key. The module may narrow that relationship but cannot widen
it. In the current Peer Review app, a review contribution requires a
same-workflow manuscript parent, while a challenge may use a different but
compatible workflow/package.

Canonical active-package lookup is keyed by `(appId, workflowKey)`. Every
historical object, evidence receipt, recognised state, transition, challenge,
credential, proof, or downstream receipt uses its stored `packageId`.
Capability absence fails closed. A package may bind at most 64 capabilities, so
every full-package unique-module identity revalidation has a fixed upper bound.

Contracts can load fixed-size references for routine validation.
`getActiveVerifiedModulesCompact` looks up the active package and verifies
every distinct module in it. `getVerifiedModulesCompact` performs the same
check for a stored `packageId`. `SubjectContext`,
`GovernedObjectReference`, `RecognisedStateReference`, and
`RecognisedStateTransitionReference` omit dynamic metadata or provenance fields
that policy calls do not consume. Use the full getters to reconstruct records
and their metadata. The compact package readers recheck module identity on
each call. Callers still perform the applicable authority, subject, evidence,
disclosure, and transition checks.

Challenge is recursive on this surface. A challenge begins as a governed object
and recognised state under its own workflow/package. `AVAChallengeExtension`
then records lifecycle transitions against a target recognised state. The
challenge package validates intake and decision context; a target mutation must
also pass the target state's historical package and `AVACoreTransitionRules`.
No module can turn a raw challenge into a target mutation or downstream effect.
`RecognisedStateTransitionContext` includes the substrate `actionKey` and
`sourceRecordId`. The Peer Review application accepts a challenge-state
`Registered -> Challengeable` transition only for `FileChallenge` with a
nonzero lifecycle source, and accepts challenge-state vesting only for a
source-bound resolution. Granting generic-transition permission alone therefore
cannot create an unfiled downstream-eligible challenge state.

The detailed interface catalogue below also documents the retained root-level
pre-separation implementation. Those interfaces remain regression evidence,
but a new application should not add domain vocabulary to Core or extend the
root-level Peer Review state machine.

## Global Contract

Rule-package validators can accept or reject the supplied context. The
calling contract grants no additional permission on success.

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
- `modulesHash`, `modulesIdentityHash`, `modulesIdentityFingerprint`, and
  `compatibilityKey` are package identity or compatibility inputs. They are not
  module-owned authority and cannot override substrate checks.
- Evidence ids and disclosure-policy ids are references. Modules do not inspect
  confidential content or judge truth.

Every rule-package module implements `IRuleModuleIdentity`. Registration keeps
the immutable capability layout in `modulesHash` and the per-capability audit
mapping in `modulesIdentityHash`. A package read recomputes
`modulesIdentityFingerprint` across every unique module in the full package and
fails closed if runtime code or declared immutable configuration no longer
matches. A module shared by several capability keys is therefore checked once,
without reducing the set of capabilities or modules covered. This demo does not
support proxy modules whose behaviour identity cannot be stably re-verified.
Registration also rejects a zero `moduleIdentityHash`; a module cannot enter a
package by declining to provide a re-verifiable identity.

When a canonical extension derives a record from a recognised state, any
alternate evidence receipt must match that state's application, workflow,
package, responsible subject, and disclosure policy. Evidence existence or
same-package membership alone is not sufficient.

The narrow execution-layer interfaces are not rule-package validator modules.
They consume already-authorised allocation, consequence, evidence, challenge,
recognised-state, or disclosure records and write settlement/access/external-
operation receipts. They must not decide manuscript quality, publication
outcome, scientific truth, standing, or reputation.

The standing credential issuer, standing-relevant settlement impact,
append-only recovery receipt, standing-penalty, and eligibility-restriction
surfaces are also not rule-package validator modules. They are not token,
reward, payment, or publication surfaces.

The canonical standing-revision extension authorises record writers per
`packageId` before revision use begins. `advanceRevision` revalidates both the
package's application and the subject's application. A writer bound to one
package has no cross-package or cross-application revision authority.

## Historical Appendix: Retained Research Taxonomy

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

## Retained Interface Contracts

The detailed contracts below describe the root-level pre-separation interface
catalogue. They preserve research and regression compatibility. A new canonical
application should first use `IAVAApplicationModule`, the interfaces in
`src/core/interfaces/IAVACoreRuleModules.sol`, and
`IAVAExtensionPolicyModule`; it should not add app vocabulary to Core merely to
reuse one of the retained names below.

### Shared Rule-Module Identity

### `IRuleModuleIdentity`

Function: `moduleIdentityHash() returns (bytes32)`

Output: a deterministic hash over the module runtime code hash and all
behaviour-affecting immutable configuration, including dependency addresses,
thresholds, durations, policy ids, or other constructor-bound rules where
applicable.

Success semantics: the registry can re-verify the module behaviour identity
captured by an immutable package. It is not an authority, compatibility, or
truth claim.

Must not do: hide mutable behaviour behind an unchanged identity, grant
authority, or mutate substrate records.

### Layer A: AVA Core Stage Interfaces

### `IAttributionModule`

Function:
`validateAttribution(AttributionContext context) returns (bytes32 attributedObjectId)`

Inputs:
- `workflowKey`, `packageId`: workflow and stable package identity.
- `actingRole`: caller role already supplied to the substrate path.
- `action`: substrate action being validated.
- `stage`: AVA stage for the proposed recognised-state object.
- `objectId`: path-scoped object reference; the module must not reinterpret it
  as another substrate object type.
- `subjectId`: role-scoped subject connected to the attributed object.
- `evidenceReceiptId`: evidence receipt reference already expected by the path.
- `disclosurePolicyId`: policy reference attached to the path.
- `actor`: current caller.

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

Function: `validateVerification(VerificationContext context)`

Inputs: `workflowKey`, stable `packageId`, `actingRole`, `action`, `stage`,
path-scoped `objectId`, role-scoped `subjectId`, `evidenceReceiptId`,
`disclosurePolicyId`, and `actor`.

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
- Before: target recognised state and its fixed package identity are
  substrate-owned. A challenge may use a different decision package, but it
  cannot substitute that package's transition rule for the target package's
  rule.
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
- Before: `AVARulePackageLifecycleRegistry.recordDisclosureLifecycleReadiness` checks
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
- Before: the challenge workflow/package, target workflow/package, attributed
  challenge object, subject binding, evidence existence, and authority checks
  are substrate-owned. Filing targets are limited to `Challengeable`, `Vested`,
  or `Restored` recognised states. Both challenger subject and filing account
  are capped at one open challenge per target and one filing per target
  transition version, so canonical subject rotation cannot reset the cap.
- Decision conflict: resolution and restoration reject both subject-id and
  account-level conflicts with the challenger and responsible target subject,
  including an actor attempting the decision through another role.
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
  workflow/package-bound. A subject may manage its own receipt; cross-subject
  lifecycle changes require a panel or institution authority. Replacement
  receipts must remain active and match workflow, historical package,
  responsible subject, disclosure policy, and evidence type. A receipt cannot
  supersede itself.
- After: substrate may record an evidence lifecycle record and update the
  receipt to a terminal non-active status.
- Later use: review-window, vesting, generic transition, challenge
  screening/resolution, and restoration paths recheck that the pinned receipt
  is still active and bound to the original workflow/package before writing
  their next record. A source-bound upheld correction is the safety-reducing
  exception: target evidence may already be inactive, while challenge evidence
  must remain active. The historical package's evidence-lifecycle module is
  called again for the current action.

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
  usable active evidence/workflow, object reference, and nonzero hash/type. The
  generic entry is fixed to target kind `EvidenceReceipt` and requires
  `objectId == bytes32(evidenceReceiptId)`. Target-specific entries resolve
  recognised states or transition records and derive their package and action
  from those records.
- After: substrate writes the attestation record with explicit `targetKind` and
  `action` provenance.

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

Inputs: `workflowKey`, decision `packageId`, target `targetPackageId`,
`actingRole`, `action`, `recognisedStateId`, `challengeId`, path-scoped
`objectId`, `evidenceReceiptId`, `authorityId`, canonical `decisionHash`, and
`actor`.

Output: none.

Success semantics: no procedural-authority veto only.

Current example modules include `ProceduralEditorialAuthorityModule` for a
single allowed action and `IllustrativeStaticAuthorityShapeModule` for a
single authority or emergency gate. Static constructor values do not simulate
approval counts. The receipt-backed example pairs `AuthorityApprovalRegistry` with
`ApprovalReceiptAuthorityModule`: panel subjects record package/action/object
approval receipts, and the residual authority module checks m-of-n active
receipts for the exact package/action/object/role/decision hash plus optional
conflict exclusion. Distinct canonical authority subjects are counted once;
an excluded subject cannot execute the decision or contribute to its threshold,
and future or unknown target ids cannot be pre-approved. For a recursive
challenge, the authority package may be the challenge package or the linked
target-state package; the receipt key uses that authority package while the
evidence reference must still match the challenge package. A `CloseChallenge`
receipt may be recorded for filed or screened challenges after evidence becomes
terminal, but only for the exact challenge target and close decision hash.
Resolution, restoration, and close validate the challenge package and target
package independently. The canonical decision hash binds the current challenge
lifecycle status, latest challenge-transition id, and target recognised-state
transition id, preventing an approval from replaying after either lifecycle
advances.
Generic multisig and cross-role institutional co-signature are not implemented
by these examples; they would require separate receipt-backed validators.
The canonical `AVAApprovalReceiptExtension` keeps receipts append-only while
counting at most 64 unique authority subjects per decision. Reissuing an expired
approval updates that authority's latest receipt without extending the set that
`approvalCount` traverses; policy thresholds above the same bound are rejected.
`approvalCount` remains the complete audit getter. Authority-policy evaluation
uses `hasApprovalThreshold`, which applies the same package, target-version,
subject-activity, and evidence-lifecycle checks but returns as soon as the
required number of distinct active approvals is reached. No approval count is
cached across transactions.
These examples express
authority predicates only; they do not mutate substrate state or execute
publication, reveal, sanction, reward, or payment effects.

Allowed failure: revert for incompatible procedural authority context.

Must not do: create acceptance/rejection/merit/publication selectors, grant
authority, mutate records, or override authorityId binding.

Gates:
- Before: substrate has already checked `authorityId` against the caller for
  authority-bearing paths and resolved decision and target package identities.
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
This module hook is additive: the substrate independently prevents two
simultaneously open challenges for the same challenger subject and target and
prevents that subject from filing again against the same target transition
version, including through another challenge package.

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
`authorityId`, and `actor`. The stored computation also binds the current
package/subject `standingRevision` supplied by `StandingRevisionRegistry`.

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
checks. Its stored standing revision must also equal the current package/subject
revision; a stale computation cannot issue a new credential under a later
revision. The credential must not be transferable, approvable, consumable,
stakeable, or treated as standing itself. It is not reputation, not a reward,
not an administrative-priority artifact, not a public-prestige NFT, and not a
balance.
The substrate limits ordinary and ZK credential validity to 365 days from
issuance. A package module may impose a shorter duration but cannot authorise a
longer carrier.
An ordinary computation stops being active when its role-scoped subject is
deactivated or its source evidence receipt becomes non-active; credentials
derived from it then fail closed without deleting history.
A ZK credential whose subject commitment is already a known role-scoped subject
also fails closed after that subject is deactivated. An unknown commitment
remains an anonymous proof subject and is not treated as a public identity.
When governance memory for such an anonymous commitment changes, an authorised
panel can call `StandingRevisionRegistry.recordStandingCommitmentRevision` with
the historical workflow/package, active pinned evidence, canonical
`authorityId`, and an off-chain reason reference. The append-only receipt
advances the same package/commitment revision used by ZK proof and credential
checks. It does not link the commitment to an account, compute standing, or
issue a credential.

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
receipt id, computation-rule hash, and authority subject.
`credentialProvesSubjectStanding` requires the stable `packageId` and uses only
the role-scoped subject identifier or subject commitment; it does not require
the holder account or public identity in the proof call. It fails closed for a
wrong package, subject, vector, category, threshold, or range. No
package-unbound ordinary credential proof selector is exposed.
`activeStandingCredentialId` is a bounded lookup for validator
modules that need the current active credential for a package/subject/vector
and category. The index identifies the single canonical active carrier for
that key. A second direct issuance is rejected while the indexed credential is
active; replacement must use the explicit supersession path. A revoked,
expired, suspended, stale-revision, or otherwise inactive carrier may be
replaced by a new authorised direct issuance. Older credential ids remain
inspectable through explicit id lookup but cannot prove once they are no longer
canonical. The lookup returns zero if no matching credential
exists or if the indexed credential is expired, revoked, superseded, suspended,
backed by an inactive computation, or bound to a stale standing revision.
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
  standing-computation readiness record over an allowed recognised state and
  the current package/subject standing revision.
- During: `StandingCredentialRegistry` checks `IssueStandingCredential`,
  `RevokeStandingCredential`, or `SupersedeStandingCredential` authority with a
  bound authority subject; validates source computation, target recognised
  state, stable package identity, evidence receipt workflow, active role-scoped
  subject, expiry, and threshold/range metadata. Issuance and supersession also
  invoke the historical package's evidence-lifecycle module for every distinct
  evidence receipt supporting the computation.
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
- `ConsequenceBoundaryValidator` applies the non-replaceable execution-shape,
  finding-subject, role, outcome, and eligibility compatibility rules before
  any package-selected consequence or penalty adapter can approve the record.
  `ConsequenceExecutor` deploys and binds this pure validator itself; rule
  packages cannot replace it.
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
- Subject boundary: target-side penalty and eligibility records inherit the
  source recognised-state subject. The only explicit cross-subject form is a
  challenge-linked negligent or malicious/fabricated challenger finding; it
  binds the challenge package, challenge evidence, and recorded challenger
  subject. It is not a generic cross-subject sanction path.
- After: substrate writes a `ConsequenceKind.PenaltyRecord` only.

### Consequence penalty input / eligibility records

Functions:

```solidity
recordStandingPenaltyInput(
    Role actingRole,
    uint256 penaltyConsequenceId,
    string dimension,
    int256 delta,
    uint256 evidenceReceiptId,
    bytes32 authorityId,
    string uri
)
recordEligibilityRestriction(
    Role actingRole,
    uint256 penaltyConsequenceId,
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
```

Success semantics: append a record tied to an existing
`ConsequenceKind.PenaltyRecord`. Standing penalty input records are negative
inputs for later standing computation only. Eligibility restrictions are
separate bounded procedural records. Standing penalty input requires a nonzero
challenge id with a compatible outcome. `AcademicFraud` and
`IrresponsibleReview` require an upheld challenge linked to the target
recognised state and its current correction transition. Because the correction
is already an authorised safety-reducing decision, its target finding and
derived standing/eligibility inputs may preserve the corrected state's
historical evidence and subject references after deactivation. This exception
does not authorise reward, allocation, restoration, settlement, or value
execution. `NegligentChallenge` and `MaliciousOrFabricatedChallenge`
require the corresponding challenge-abuse outcome and challenger subject.
`RejectedGoodFaith` challenges cannot become misconduct standing-penalty or
eligibility-restriction records. Challenge-intake eligibility restrictions
must be linked to a negligent or malicious/fabricated challenge outcome for the
restricted challenger subject. The package-bound
`activeEligibilityRestrictionId` lookup returns zero after expiry or when no
matching active restriction exists. The
current demo has no early-lift function; a restriction remains active until
`expiresAt` unless a later version adds an explicit restriction-supersession or
restriction-lift record.
Penalty source uniqueness is substrate-owned: the same challenge finding,
subject, state, package, and origin settlement cannot be duplicated by changing
metadata. Finding kinds are role- and outcome-bound, so a reviewer finding
cannot be relabelled as academic fraud and an author finding cannot be
relabelled as irresponsible review. The canonical Peer Review module enforces
this through object vocabulary: review-contribution states accept only the
irresponsible-review finding, while challenge states accept only negligent or
malicious/fabricated-challenge findings. The canonical app currently forms no
author/manuscript recognised state, so `AcademicFraud` has no valid canonical
penalty target; a future author workflow must add that mapping in a new app
module/package rather than reuse a reviewer state. For standing effects, the same challenge,
subject, package, and dimension can be written once even if another consequence
record is attempted; each eligibility-restriction kind remains unique per
recorded penalty consequence. Later URI, delta, duration, evidence, or authority
variants do not create another effect record.

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
preserves the original execution and appends a causal chain: completed origin
token transfer or escrow claim, compatible linked penalty consequence, one full
repayment obligation, then exactly one clawback, setoff, waiver, or satisfaction
terminal receipt. The stored receipt also carries the source execution mode,
source settlement kind, source execution reference, `originSettlementId`,
`penaltyConsequenceId`, `repaymentObligationId`, and
`settlementContextHash` for auditability.

Allowed failure: revert for unknown source records, record-only sources on
active execution or recovery paths, wrong execution mode, wrong settlement kind,
duplicate final settlement, missing authority, unknown subject, missing
amount/reference, missing asset/payer where active execution needs them, or
non-authorised caller. Recovery also rejects an unpaid or mismatched origin,
duplicate obligation, partial or excess amount, wrong package/subject/asset/
payer, terminal receipt without an obligation, or duplicate terminal result.

Must not do: create allocation/consequence/standing records, compute
reputation, decide publication, grant manuscript advantage, reveal evidence,
directly seize unrelated wallet assets, delete prior reward history, or execute
sanctions. Priority tokens are administrative-priority artifacts only; they are
not standing, reputation, scholarly conduct, or manuscript merit.

Gates:
- Before: allocation or consequence source records already exist and carry
  package id, evidence id, subject id, execution mode, settlement kind, and
  authority metadata.
- During: `ValueSettlementExecutor` performs its own role/action authority gate,
  checks the requested
  settlement kind against the stored source kind, rejects duplicate final
  settlement on active execution paths, revalidates the current source state
  and source evidence before a new allocation settlement, revalidates the
  source package's module identity, and invokes its evidence-lifecycle module
  with `ExecuteValueSettlement`. It rejects recovery receipts on open or
  refunded escrow paths, revalidates penalty evidence before creating a
  repayment obligation, and records source-bound recovery receipts only from
  completed eligible origins bound to the same recognised state. Escrow refund deliberately remains a closeout
  path when evidence or module identity later becomes non-active, or when the
  intended recipient subject is later deactivated; the refund still returns
  the existing deposit only to the original payer. Clawback
  revalidates package identity and evidence lifecycle before moving the mock
  asset; record-only setoff, waiver, and satisfaction remain available to close
  an existing obligation after its historical subject or evidence becomes
  inactive. Canonical reward `Freeze` and `Void` records use the same defensive
  historical-reference rule. Reward `Vest` and `Restore`, new settlements,
  repayment-obligation creation, and clawback remain effectful and require
  active subject and evidence references. Settlement and standing-revision state is written
  before any external mock token or priority-token call; reentrancy is rejected
  and an external revert rolls back the transaction. Repayment obligation is
  non-terminal; clawback, setoff, waiver, and satisfaction are mutually
  exclusive terminal recovery receipts for an obligation. Only clawback moves
  the configured mock asset. `computeSettlementContextHash` is a read-only audit
  helper over the source record, recognised state, source execution fields,
  recipient, settlement kind, and settlement status. The retained executor uses
  the `AVA_VALUE_SETTLEMENT_CONTEXT_V2` domain after adding recognised-state
  lineage to the commitment.

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

Allowed failure: revert for unknown target, wrong workflow, unknown or
misbound evidence receipt, missing authority, empty reference, unsupported kind/status, or
non-authorised caller. Requests and acknowledgements also revert when the
historical package identity no longer revalidates or its evidence-lifecycle
module rejects `RecordExternalOperation`.

Must not do: accept/reject manuscripts, score merit, execute publication
priority, adjust real queues, transfer value, reveal identity/evidence, or
execute sanctions.

Gates:
- Before: target recognised-state/challenge/evidence/allocation/consequence
  record exists and matches the workflow; evidence receipt exists and matches
  the workflow; caller has `RecordExternalOperation` authority.
- Lifecycle: requests and acknowledgements require active evidence, revalidate
  the target's historical package, and call its evidence-lifecycle module.
  Cancellation and supersession retain the original workflow/package/evidence
  binding but remain defensive closeouts after package drift or evidence
  termination; they cannot acknowledge or execute an external operation.
- Package routing: ordinary recognised-state/consequence targets use the target
  state's package. A negligent or malicious/fabricated challenger consequence
  instead requires its linked challenge target, challenge package, challenge
  evidence, and challenger subject to match.
- After: only the requested/acknowledged/cancelled/superseded receipt is stored.
  `computeOperationContextHash` is a read-only audit helper; it does not execute
  or schedule an external operation.

### `IRulePackageLifecycleModule`

Function: `validateRulePackageLifecycle(RulePackageLifecycleContext context)`

Inputs: `workflowKey`, source `modulesHash`, source `modulesIdentityHash`, `kind`,
`version`, `compatibilityKey`, `dependencyURI`, `deprecated`,
`targetWorkflowKey`, `targetPackageId`, `targetModulesHash`,
`targetModulesIdentityHash`, `targetVersion`, `targetCompatibilityKey`,
`authorityRole`, and `actor`. `modulesHash` includes both module
addresses/configuration and the registered aggregate behaviour identity; the
separate `modulesIdentityHash` exposes the re-verifiable module-identity
aggregate directly.

Output: none.

Success semantics: package-lifecycle veto only; not authority grant and not
migration execution. `AVARulePackageLifecycleRegistry` owns lifecycle and
readiness records. Object-level migration readiness is a separate record-only
receipt bound to an existing `MigrationReady` lifecycle record. The registry's
constructor immutably binds `AuthorityMatrix`, `AVARulePackageRegistry`,
`DisclosurePolicyRegistry`, the recognised-state reader, and the evidence
reader. It requires the named recognised state and evidence receipt to belong
to the lifecycle record's source workflow/package before storing readiness and
revalidates both the source and target package identities at use time.
There is no runtime migration-reader configuration entry point.

Allowed failure: revert for incompatible module composition, unsupported
version, wrong compatibility key, deprecated package, missing target package
context, or incompatible target package context.

Must not do: mutate existing packages, rewrite old recognised states, migrate
state, or override rule-package authority.

Gates:
- Before: `AVARulePackageRegistry` checks caller authority, nonzero module
  addresses, nonzero deployed module code, nonzero version/compatibility key,
  computes `modulesIdentityHash`, computes `modulesHash`, and resolves known target
  package metadata for migration/supersession readiness records. The workflow-key
  path resolves the currently active package; the package-bound path accepts an
  explicit source `packageId` and target `packageId`.
- Registration lifecycle: `registerRulePackage` is initial registration only.
  `supersedeRulePackage` is an explicit compare-and-set replacement that must
  name the current active package and use a strictly greater version. It writes
  an append-only supersession record and advances the active pointer only for
  new objects.
- After: registry assigns a new immutable `packageId`, stores package metadata,
  stores source and target module hash / identity-hash / version /
  compatibility metadata on readiness records, rechecks the stored aggregate
  module behaviour identity on package reads, points `workflowKey` to the new
  active package only after valid supersession, and may store object-level
  migration readiness receipts without moving the object.

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
receipt, authority subject, URI, and the current package/subject standing
revision. Statements can be superseded by a matching
newer-epoch statement or invalidated with package-bound evidence. Superseded or
invalidated statements, and statements whose standing revision is no longer
current, cannot support active standing proof or credential use. The same is
true when evidence bound to the source-set commitment, completeness attestation,
or computation statement becomes expired, revoked, superseded, or replaced.

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
Source-set commitments use the distinct
`RegisterStandingSourceSetCommitment` action; source-set, completeness, normal
statement, and superseding-statement writes also revalidate the historical
package identity and invoke its evidence-lifecycle module with their exact
action.

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
not already been registered. Registration revalidates the statement's
historical package identity and invokes its evidence-lifecycle module with
`RegisterStandingProof` for each distinct source-set, completeness-attestation,
and statement evidence receipt. The proof context includes the statement's current
standing revision. The receipt stores formula id, source-set
commitment id, standing-computation statement id, output commitment, formula
version, source-set policy hash, standing revision, verifier address, and
proof-domain hash. The canonical `AVAStandingZKProofExtension` also captures
the verifier runtime codehash and proof-domain hash at deployment. A later
runtime or proof-domain change rejects new registrations and makes existing
proof receipts unusable. This detects direct-contract drift; mutable proxy
implementations are not claimed as supported verifier identities.

Allowed failure: revert for unknown workflow package, zero subject/vector/
category/source root/rule/epoch fields, invalid threshold/range/value shape,
missing formula/source-set commitment, verifier mismatch, subject-commitment
mismatch, missing or inactive computation statement, output commitment mismatch,
verifier rejection, verifier runtime/domain drift, or context/nullifier replay.

Must not do: reveal identity or evidence, compute complete historical standing,
issue standing credentials directly, create standing/reputation, mint token or
reward, transfer value, execute sanction, or affect publication.

Credential boundary: `standingProofSupportsCredential` is a read-only gate for
future privacy-preserving credential issuance. It checks package, subject
commitment, vector, category, threshold, and range against a stored proof
receipt and also requires the referenced computation statement to remain
active and its standing revision to remain current. It does not create or
transfer any credential by itself.

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
    bytes32 targetContextHash,
    address beneficiary
)
```
- `computeCredentialUseNullifierHash(bytes32 useContextHash, bytes32 credentialCommitment)`
- `getCredential(uint256 id)`
- `getCredentialUseRecord(uint256 id)`
- `getCredentialSuspensionRecord(uint256 id)`

Loose credential suspension is not exposed. Standing-relevant ZK credential
suspension must use one of the source-bound paths.

Inputs bind a ZK standing proof receipt to package id, subject commitment,
credential commitment, credential nullifier, vector/category, threshold/range,
epoch, source-record-set root, computation-rule hash, source computation
statement id, expiry, authority, and the source proof's standing revision.

Namespace note: on this retained surface, `subjectCommitment` is treated as the same
pseudonymous subject identifier used by the source record. It is not a
real-name identity and it is not an account owner field. This differs from the
canonical extension described above, which stores a role-scoped `subjectId`
alongside the commitment.

Success semantics: records a commitment-bound standing credential proof carrier
only when the caller has `IssueStandingCredential` authority and the supplied
fields match the source ZK standing proof receipt and its active computation
statement. Issuance and supersession revalidate the historical package and call
its evidence-lifecycle module for each distinct receipt in the statement's
evidence chain. Credential use records are target/nullifier/beneficiary-bound,
require the beneficiary to submit the transaction, require a verifier proof
whose public key matches the stored credential commitment, and reject replay.
ZK proof and credential-use contexts also bind the chain id, registry
deployment, and verifier deployment. Retained proof registries pin verifier
runtime codehash and proof domain; direct drift disables active lookups while
historical receipts remain readable. Mutable proxy verifier behavior is not
supported. Credentials can be revoked, superseded, or suspended by authorised
roles. Active proof use also requires the credential revision to equal the
current package/subject revision. Source-bound suspension paths additionally write an append-only
`ZKStandingCredentialSuspensionRecord`
before marking a credential suspended. Settlement-bound suspension requires the
referenced value-settlement record to match the credential package,
subject commitment, source record, source type, and standing-relevant
settlement kind. Challenge-transition-bound suspension requires an
outcome-resolution transition for the same package and challenger subject
commitment, and accepts negligent or malicious/fabricated outcomes while
rejecting rejected-good-faith outcomes.

An expired or stale-revision ZK credential remains unusable, but it can be
explicitly superseded while it still owns its canonical slot. The replacement
must come from a currently usable proof receipt for the same package, subject
commitment, vector, and category with a later epoch; the old record retains its
`supersededBy` lineage. Inactivity therefore cannot reactivate an old proof and
cannot permanently lock future credential issuance.

The ZK registry intentionally exposes no local-status-only
`isCredentialActive` selector. Consumers that need a current standing signal
must call the package-bound `credentialProves` function or record a target-bound
credential-use receipt. Those paths re-check carrier status, subject lifecycle,
the referenced ZK standing proof receipt, computation statement, and current
standing revision. `getCredential` remains available for historical carrier
inspection, but its stored status alone is not a standing proof.

Allowed failure: revert for unknown proof receipt, wrong package, wrong subject
commitment, wrong vector/category, invalid threshold/range, mismatched epoch,
source root, rule hash, or inactive computation statement, duplicate credential
commitment or nullifier, expired input, unauthorised authority, inactive
credential, invalid historical package identity, evidence-lifecycle veto,
mismatched proof-use credential commitment, invalid proof-use
context/nullifier, or proof-use nullifier replay. Source-bound suspension also
reverts for unknown or
mismatched settlement ids, wrong package, wrong subject commitment, wrong
source, wrong settlement kind, unknown challenge transition id, non-resolution
transition, or good-faith rejected challenge outcome.

Must not do: store an owner account, expose `ownerOf`, `balanceOf`, transfer,
approval, reward, priority-token, standing-token, reputation-token, reveal,
decrypt, publication, sanction-execution, standing-update, payment, or
manuscript-merit surfaces.
