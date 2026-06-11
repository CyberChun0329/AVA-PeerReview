# Module Capability Matrix

This document records the current module capability and conflict model
for the implemented Solidity demo. It describes the code that exists now; it
does not authorise a production release, model, simulation, publication logic,
production token/payment integration, publication-queue execution, sanction
execution, identity reveal, evidence reveal, decrypt, production ZK, or ACL
work.

The capability model is written for the current Base-compatible EVM/Solidity
demo. It documents local Foundry contracts and tests, not deployed Base
addresses or production chain operations.

For per-interface input/output and semantic preconditions, see
`docs/interface-contract-spec.md`.

For the module-author workflow and rule-package test checklist, see
`docs/rule-package-integration-guide.md`.

## Substrate-Owned Capabilities

The substrate owns and records:

- role/action authority checks through `AuthorityMatrix`;
- role-scoped subject binding through `RoleIdentityRegistry`;
- immutable rule-package identity through `AVARulePackageRegistry.packageId`,
  `modulesHash`, and `modulesCodeHash`;
- evidence receipt storage, workflow/type references, package binding, and
  active/inactive lifecycle status through `EvidenceCommitmentRegistry`;
- recognised-state, review contribution, challenge, challenge-transition, and
  recognised-state transition storage through `AVAStateMachine`;
- downstream standing, allocation, consequence, and audit record storage
  through their dedicated registries.
- standing credential proof-carrier storage through
  `StandingCredentialRegistry`.
- settlement, disclosure-execution, and external-operation receipt storage
  through the execution-layer registries.

Rule-package modules and adapters are validator-only seams. They may validate
or veto a proposed transition/readiness/record. They must not grant authority,
mutate substrate storage, execute reward/payment/sanction/publication/reveal,
or reinterpret substrate-owned ids.

Conflict semantics are AND / fail closed: every applicable substrate gate and
every applicable package module must accept before the substrate writes a
record or status transition. Any revert rejects the entire operation and no
later module can override it.

Nondelegable substrate gates have priority over modules. A module cannot
permit forbidden high-impact transitions, unknown or non-active evidence,
unknown or inactive subjects, raw-id downstream records, wrong package
identity, publication merit, or publication effect.

## Interface Taxonomy

The AVA technical framework separates interfaces into three layers. Only the
first layer maps directly to AVA's macro stages.

### Layer A: AVA Core Stage Interfaces

| AVA stage | Interface | Called by | Current limit |
| --- | --- | --- | --- |
| Attribution | `IAttributionModule` | `AVAStateMachine` recognised-state/review/challenge formation | Validates attributed object only; not truth, reward, or publication effect |
| Verification | `IVerificationModule` | `AVAStateMachine` recognised-state/review/challenge formation | Validates references and workflow predicates; not scientific truth or manuscript merit |
| Allocation | `IAVAAllocationModule` / `IAllocationAdapter` | `AllocationExecutor.executeAllocation` | Validates bounded AVA Allocation record fields; not token/payment/queue execution or publication priority |

### Layer B: Recognised-State Governance Support

These interfaces support recognised-state governance. Transition, challenge,
correction, disclosure, residual editorial authority, evidence policy,
evidence lifecycle, audit, field policy, and anti-abuse validation are not new
AVA stages.

| Support function | Interface | Called by | Current limit |
| --- | --- | --- | --- |
| Transition rule | `ITransitionRuleModule` | `AVAStateMachine` transition, challenge, restoration, close paths | Cannot own state storage or allow substrate-forbidden high-impact paths |
| Challenge-window timing | `IChallengeWindowRuleModule` | `AVAStateMachine.vestReviewRecognition` when the selected transition module supports it | Optional minimum-duration veto only; no scheduler, oracle, expiry executor, or automatic challenge closure |
| Challenge lifecycle | `IChallengeLifecycleModule` | `AVAStateMachine` file/screen/resolve/restore/close | Lifecycle admissibility only; no sanction, standing update, allocation, or direct status mutation |
| Disclosure policy | `IDisclosurePolicyModule` | Evidence registry and state/challenge paths | Policy/reference compatibility only; no reveal/decrypt/ACL |
| Disclosure lifecycle | `IDisclosureLifecycleModule` | `recordDisclosureLifecycleReadiness` | Readiness record only; no reveal/decrypt/ACL/identity disclosure |
| Disclosure execution | `IDisclosureExecutionModule` | `DisclosureAccessExecutor` using target `packageId` | Access grant/revoke/expiry/supersession, lifecycle, proof-use, and voluntary-intent receipt validation only; no reveal/decrypt/ACL engine |
| Residual editorial authority | `IResidualEditorialAuthorityModule` plus `AuthorityApprovalRegistry` for receipt-backed examples | `AVAStateMachine` recognised-state and challenge-governance paths | Procedural authority validation only, including example single-role, threshold-panel, multisig, institutional-co-signature, conflict-excluded-panel, emergency-pause, and approval-receipt validator formats; no acceptance, rejection, merit, or publication priority |
| Evidence policy | `IEvidencePolicyModule` | Evidence registration and evidence-backed state/challenge paths | Workflow/type/reference compatibility only; no truth validation |
| Evidence lifecycle | `IEvidenceLifecycleModule` | Evidence registration, evidence use, evidence lifecycle hook | Status-bound lifecycle validation only; no delete/reveal/truth adjudication |
| Audit adapter | `IAuditAdapter` | `AttestationAuditModule` workflow-aware and target-bound attestation paths | Attestation reference/hash validation only; audit storage remains substrate-owned |
| Field policy | `IFieldPolicyModule` | `AVAStateMachine` recognised-state validation | Field/venue admissibility only; cannot replace authority/evidence/status gates |
| Anti-abuse | `IAntiAbuseModule` / optional `IChallengeRateLimitModule` | Review, challenge, standing, allocation, consequence paths | Veto only; default package remains permissive; selected packages can reject repeated challenge filing; no sanction execution, standing update, or state write |

`IEditorialSystemAdapter` remains an optional manuscript metadata-reference
bridge outside the AVA core-stage / recognised-state support / downstream
taxonomy. It cannot create publication, acceptance, rejection, merit, or
priority logic.

### Layer C: Downstream Consequence / Execution / Proof Support

These interfaces live at or after the Allocation edge. Standing, reward,
priority, penalty, restoration, value settlement, standing credential, external
operation, rule-package lifecycle, and ZK proof verification are not AVA core
stages.

| Downstream function | Interface | Called by / implemented by | Current limit |
| --- | --- | --- | --- |
| Standing update | `IStandingAdapter` | `StandingRegistry.recordStandingUpdate` | Procedural governance memory only; not reward, public prestige, balance, or manuscript merit |
| Standing computation | `IStandingComputationModule` | Standing update and standing-computation readiness paths; example `FormulaV0StandingComputationModule` | Vector/dimension readiness with epoch, source-record-set hash, computation-rule hash, and active/superseded/invalidated status only; Formula V0 validates bounded reversible output for four demo vectors; no public score or asset-like standing |
| Standing credential | `IStandingCredentialIssuer` | `StandingCredentialRegistry` | Non-transferable proof carrier over an active computation only; not standing itself, reputation, reward, priority token, or asset |
| Reward record | `IRewardAdapter` | `AllocationExecutor.recordRewardValue*` | Record validation only; no transfer or publication effect |
| Priority record | `IPriorityAdapter` | `AllocationExecutor.recordAdministrativePriority*` | Administrative queue/service right only; no publication priority or reviewer leniency |
| Consequence record | `IConsequenceAdapter` | `ConsequenceExecutor.registerConsequence*` | Bounded administrative/procedural record only |
| Penalty record | `IPenaltyAdapter` | `ConsequenceExecutor.recordPenalty*` | Penalty record validation only; no sanction execution or direct standing update |
| Restoration record | `IRestorationAdapter` | `ConsequenceExecutor.recordRestoration*` | Repair record only; no silent overwrite or reward mint |
| Value execution readiness | `IValueExecutionAdapter` | Allocation, reward, priority, consequence, penalty, restoration record paths | Readiness validation only; settlement executor consumes authorised sources separately |
| Value settlement | `IValueSettlementExecutor` | `ValueSettlementExecutor` | Source-bound settlement receipts include source execution context and settlement context hash only; no standing/reputation/publication/sanction engine |
| External operation | `IExternalOperationRegistry` | `ExternalOperationRegistry` | Intent/status receipts carry operation context hash; terminal receipts link to their source request; no external platform operation |
| Rule-package lifecycle | `IRulePackageLifecycleModule` | Rule-package registration, lifecycle readiness, and object migration readiness receipts | Compatibility/readiness only; object readiness is record-only; no migration executor or retroactive package rewrite |
| ZK proof verification | `IZKProofVerifier` | `ZKProofRegistry` | Package-aware, context-bound verification receipt only; default registration binds the active package, while explicit package-bound registration supports historical targets after workflow re-registration; no identity reveal or authority grant |
| Standing formula/source-set/statement | `IStandingFormulaRegistry` | `StandingFormulaRegistry` | Package-bound formula metadata, source-set commitment, source-set completeness attestation, and authorised computation-statement records with source-set evidence, statement evidence, completeness hash, output commitment, authority, and status only; no standing computation, source-history traversal, production ZK circuit, reveal, standing update, or credential issuance |
| ZK standing computation proof | `IZKProofVerifier` | `ZKStandingComputationRegistry` | Package-bound, subject-commitment-bound standing proof receipt with exact registered formula/source-set commitment id, active source-set completeness attestation, active computation statement id, output commitment, formula version, source-set policy hash, source-record-set root, computation-rule hash, verifier/proof-domain binding, and nullifier replay protection only; no production ZK circuit, reveal, standing update, or credential issuance |
| ZK standing credential | `IZKStandingCredentialIssuer` | `ZKStandingCredentialRegistry` | Commitment-bound proof carrier from a ZK standing proof receipt; proof-use records require a verifier proof bound to the credential commitment; no owner account, balance, transfer, approval, reward, priority token, reveal, publication, or manuscript effect |

The standing formula/source-set registry is the chain-side trust boundary for
privacy-preserving standing computation. It lets a workflow bind a formula
version, source-set policy, source-record-set root, verifier, evidence receipt,
and completeness attestation before a ZK standing proof receipt is accepted. It
does not calculate standing, traverse history, prove completeness by itself, or
issue credentials.

## Conflict Matrix

Read this section as a set of per-family conflict cards. Every family below
uses the same conflict rule: **all applicable substrate gates and modules must
accept; any veto fails closed before storage mutation.**

### Core Stage And State-Governance Validators

**Attribution, `IAttributionModule`**

- Called by: `AVAStateMachine` recognised-state/review/challenge formation.
- May validate: attributed object reference and role-scoped subject/object
  relation.
- May veto: yes.
- Must not do: grant authority, write state, judge truth, or reveal identity.
- Nondelegable gates: caller authority, subject binding, usable active
  evidence/workflow, and package identity.

**Verification, `IVerificationModule`**

- Called by: `AVAStateMachine` recognised-state/review/challenge formation.
- May validate: reference sufficiency and workflow-specific verification
  predicates.
- May veto: yes.
- Must not do: score manuscript merit, decide scientific truth, or
  accept/reject manuscripts.
- Nondelegable gates: usable active evidence/workflow, recognised-state status
  gates, and package identity.

**Transition rule, `ITransitionRuleModule`**

- Called by: `AVAStateMachine` transition, challenge, restoration, and close
  paths.
- May validate: workflow-specific transition admissibility.
- May veto: yes.
- Must not do: mutate status directly or allow substrate-forbidden
  high-impact paths.
- Nondelegable gates: generic transition only `Registered -> Vested`;
  challenge paths only for `Downgraded`, `Voided`, or `Restored` as the
  substrate allows.
- Optional extension: `IChallengeWindowRuleModule` can veto vesting before a
  package-configured challenge-window duration has elapsed. It cannot close
  challenges, schedule execution, or replace open-challenge-count blocking.

**Disclosure policy, `IDisclosurePolicyModule`**

- Called by: evidence registry and state/challenge paths.
- May validate: policy reference and action compatibility.
- May veto: yes.
- Must not do: reveal/decrypt evidence or identity, or implement ACL.
- Nondelegable gates: policy existence where required and no on-chain
  confidential content.

**Challenge lifecycle, `IChallengeLifecycleModule`**

- Called by: `AVAStateMachine` file/screen/resolve/restore/close paths.
- May validate: lifecycle admissibility and action sequencing.
- May veto: yes.
- Must not do: sanction, mutate recognised state directly, or erase history.
- Nondelegable gates: existing challengeable recognised state, self-resolution
  rejection, outcome mutation rules, and transition ledger.

**Evidence policy, `IEvidencePolicyModule`**

- Called by: evidence registration and evidence-backed state/challenge paths.
- May validate: workflow evidence type/reference compatibility.
- May veto: yes.
- Must not do: validate truth, reveal content, or create evidence.
- Nondelegable gates: evidence receipt storage belongs to
  `EvidenceCommitmentRegistry`; unknown, cross-workflow, or non-active
  evidence is rejected before new governed records.

**Audit adapter, `IAuditAdapter`**

- Called by: `AttestationAuditModule` workflow-aware and target-bound
  attestation paths.
- May validate: attestation reference and hash shape.
- May veto: yes.
- Must not do: create authoritative audit records outside substrate, reveal
  evidence, or adjudicate truth.
- Nondelegable gates: authority-subject binding, usable active
  evidence/workflow, and target package identity.

**Optional editorial metadata bridge, `IEditorialSystemAdapter`**

- Called by: optional manuscript external-reference path.
- May validate: external editorial reference metadata.
- May veto: yes.
- Must not do: decide acceptance/rejection, score merit, alter manuscript
  status, or become an AVA stage.
- Nondelegable gates: manuscript storage and author authority remain
  substrate-owned.

**Residual editorial authority, `IResidualEditorialAuthorityModule`**

- Called by: `AVAStateMachine` recognised-state and challenge-governance
  paths.
- May validate: procedural residual authority predicates, including
  single-role, threshold-panel, multisig, institutional co-signature,
  conflict-excluded-panel, emergency-pause, and approval-receipt validator
  formats.
- May veto: yes.
- Must not do: create acceptance, rejection, merit, reveal, sanction, reward,
  payment, or publication priority logic.
- Nondelegable gates: `authorityId` binding, recognised-state storage, and
  transition ledger.
- Receipt-backed example: `AuthorityApprovalRegistry` records package/action/
  object/authority-subject approval receipts with evidence and expiry;
  `ApprovalReceiptAuthorityModule` checks m-of-n active receipts and optional
  subject-aware conflict exclusion.

**Field policy, `IFieldPolicyModule`**

- Called by: `AVAStateMachine` recognised-state validation.
- May validate: field/discipline admissibility.
- May veto: yes.
- Must not do: override authority/evidence/status gates or judge scientific
  truth.
- Nondelegable gates: authority, evidence, package, and transition gates remain
  substrate-owned.

**Anti-abuse, `IAntiAbuseModule` / `IChallengeRateLimitModule`**

- Called by: review, challenge, standing, allocation, and consequence paths.
- May validate: abuse/rate-limit predicates. The default package remains a
  permissive baseline; package-selected modules can veto configured
  subject/object/action paths. The optional challenge-rate-limit hook receives
  the prior filing count for the same package / challenged recognised state /
  challenger subject path and can reject repeated challenge filing.
- May veto: yes.
- Must not do: sanction, apply punitive asset deduction, update standing, or
  block by writing state.
- Nondelegable gates: no sanction execution; records are written only by
  substrate registries.

### Standing And Credential Families

**Standing adapter, `IStandingAdapter`**

- Called by: `StandingRegistry.recordStandingUpdate`.
- May validate: standing update fields and dimension.
- May veto: yes.
- Must not do: calculate aggregate reputation, publish prestige, grant service
  entitlements, or mint/transfer/consume anything from standing or reputation
  records.
- Nondelegable gates: allowed recognised-state status, known subject, usable
  active evidence/workflow, and `authorityId` binding.

**Standing computation, `IStandingComputationModule`**

- Called by: standing update and standing-computation readiness paths.
- May validate: vector/dimension readiness plus epoch, source-record-set hash,
  computation-rule hash, and bounded Formula V0 output when that example
  module is selected.
- May veto: yes.
- Must not do: collapse standing into public score, manuscript merit, reward,
  administrative-priority artifact, transferable NFT, or consumable balance.
- Nondelegable gates: same standing substrate gates; standing-computation
  records are inputs to credential issuance only when separately authorised;
  superseded or invalidated computations cannot support active proof.

**Standing credential issuer, `IStandingCredentialIssuer`**

- Called by: `StandingCredentialRegistry`.
- May validate: active proof carrier over an authorised active
  standing-computation record.
- May veto: yes.
- Must not do: mint reward, create standing/reputation,
  transfer/approve/trade/stake/consume a credential, grant priority, or affect
  manuscripts.
- Nondelegable gates: source standing-computation record, recognised-state
  package identity, active subject, usable active evidence/workflow,
  `authorityId` binding, expiry, revocation, supersession, active source
  computation, and standing-relevant settlement invalidation/supersession
  before active proof use.

**Standing formula/source-set/statement, `IStandingFormulaRegistry`**

- Called by: `StandingFormulaRegistry`.
- May validate: formula metadata, source-set policy hash, source-record-set
  root, source evidence receipt, completeness attestation hash, output
  commitment, verifier reference, authority subject, and
  active/superseded/invalidated computation statement status.
- May veto: yes.
- Must not do: compute standing, prove completeness by itself, traverse full
  source history, reveal identity/evidence, issue credential, create
  standing/reputation, mint reward/priority, or affect manuscripts.
- Nondelegable gates: active workflow package, formula/source-set/completeness
  and statement authority, usable package-bound evidence receipts,
  package-bound formula key, package-bound source-set proof key, matching
  active completeness attestation, and active statement binding.

**ZK standing computation proof, `ZKStandingComputationRegistry`**

- Called by: future privacy-preserving credential issuance gates.
- May validate: package-bound standing proof context over subject commitment,
  vector/category/range, exact registered formula/source-set commitment,
  active computation statement, output commitment, formula version,
  source-set policy hash, source-record-set root, computation-rule hash,
  verifier/proof-domain binding, and nullifier.
- May veto: yes.
- Must not do: reveal identity/evidence, compute full history on chain, issue
  standing credential directly, create standing/reputation, mint
  reward/priority, or affect manuscripts.
- Nondelegable gates: active workflow package existence, subject commitment,
  active statement match, registered formula/source-set commitment match,
  verifier result and proof domain, context/package binding, source root,
  output commitment, rule hash, and nullifier replay guard.

**ZK standing credential issuer, `IZKStandingCredentialIssuer`**

- Called by: `ZKStandingCredentialRegistry`.
- May validate: commitment-bound credential issuance, status, proof-backed
  proof-use records, and source-bound settlement/challenge-transition
  suspension records from ZK standing proof receipts.
- May veto: yes.
- Must not do: store owner account, expose balance/transfer/approval surfaces,
  reveal identity/evidence, compute standing, mint reward/priority, execute
  sanction, update standing directly, or affect manuscripts.
- Nondelegable gates: ZK standing proof receipt, package/subject/vector/
  category/range/epoch/root/rule binding, `authorityId` binding, expiry,
  revocation, supersession, suspension, issuance nullifier, proof-use verifier
  proof, proof-use context/nullifier, source-bound value-settlement record
  matching against the same pseudonymous role-scoped subject commitment, and
  negligent/malicious challenge-transition outcome binding.

### Allocation, Consequence, And Execution-Readiness Families

**Allocation module, `IAVAAllocationModule`**

- Called by: `AllocationExecutor.executeAllocation`.
- May validate: bounded AVA Allocation record fields.
- May veto: yes.
- Must not do: execute queue/payment/token or create publication priority.
- Nondelegable gates: allowed recognised state, known subject, usable active
  evidence/workflow, and `authorityId` binding.

**Reward adapter, `IRewardAdapter`**

- Called by: `AllocationExecutor.recordRewardValue*`.
- May validate: reward-value record fields.
- May veto: yes.
- Must not do: transfer value, mint token, create consequence, or affect
  manuscripts.
- Nondelegable gates: allocation storage only; no token/payment code; no
  publication selectors.

**Priority adapter, `IPriorityAdapter`**

- Called by: `AllocationExecutor.recordAdministrativePriority*`.
- May validate: administrative-priority record fields.
- May veto: yes.
- Must not do: grant publication priority or reviewer leniency.
- Nondelegable gates: allocation storage only; publication-priority selectors
  are absent.

**Consequence adapter, `IConsequenceAdapter`**

- Called by: `ConsequenceExecutor.registerConsequence*`.
- May validate: bounded administrative consequence fields.
- May veto: yes.
- Must not do: execute sanction, standing update, allocation, or reward.
- Nondelegable gates: consequence storage only; allowed recognised state,
  responsible recognised-state subject, and evidence gates.

**Penalty adapter, `IPenaltyAdapter`**

- Called by: `ConsequenceExecutor.recordPenalty*`.
- May validate: penalty-record fields, including value recovery metadata,
  standing penalty input, and eligibility / screening consequence.
- May veto: yes.
- Must not do: execute sanction, punitive asset deduction, token transfer,
  direct standing update, or deletion of reward history.
- Nondelegable gates: consequence storage only; no sanction execution selector;
  standing penalty input is consumed only by later standing computation.

**Restoration adapter, `IRestorationAdapter`**

- Called by: `ConsequenceExecutor.recordRestoration*`.
- May validate: restoration-record fields.
- May veto: yes.
- Must not do: mint reward or erase challenge/correction history.
- Nondelegable gates: restoration is explicit transition or record; history
  remains stored.

**Value execution adapter, `IValueExecutionAdapter`**

- Called by: allocation, reward, priority, consequence, penalty, and
  restoration record paths.
- May validate: parameterized record-readiness fields, including
  asset/payer/mode/reference, reward execution readiness, and lossless recovery
  readiness such as repayment obligation, future setoff, waiver, satisfaction,
  and restoration.
- May veto: yes.
- Must not do: transfer token/stablecoin, execute queue, execute
  sanction/payment, delete history, or update standing directly.
- Nondelegable gates: record paths only; a separate settlement executor may
  consume stored authorised records.

### Package, Evidence, And Disclosure Lifecycle Families

**Rule-package lifecycle, `IRulePackageLifecycleModule`**

- Called by: rule-package registration, package-bound lifecycle readiness, and
  object migration readiness receipt recording.
- May validate: `workflowKey`, source `packageId`, address-and-code-bound
  source `modulesHash` / `modulesCodeHash`, lifecycle kind, `version`,
  `compatibilityKey`, dependency metadata, deprecation flag, and target
  `packageId` plus target module/version metadata when required.
- May veto: yes.
- Must not do: migrate old states, mutate packages retroactively, or write
  records outside registry.
- Nondelegable gates: new `packageId` per registration; old states keep old
  `packageId`; no-code module addresses rejected; migration/supersession
  readiness binds explicit source and target package metadata; object migration
  readiness binds the object, source recognised state, evidence, authority, and
  boundary hash to an existing `MigrationReady` record; configured
  state/evidence readers require those references to belong to the source
  workflow/package; source package lifecycle module validates readiness.

**Evidence lifecycle, `IEvidenceLifecycleModule`**

- Called by: evidence registration, evidence use, and evidence lifecycle hook.
- May validate: expiry/revocation/supersession/replacement lifecycle status
  with lifecycle kind and replacement receipt reference.
- May veto: yes.
- Must not do: delete/reveal evidence or judge truth.
- Nondelegable gates: evidence receipt existence/workflow/package/status owned
  by evidence registry; terminal non-active receipts cannot form new governed
  records.

**Disclosure lifecycle, `IDisclosureLifecycleModule`**

- Called by: `recordDisclosureLifecycleReadiness`.
- May validate: disclosure readiness kind/reference.
- May veto: yes.
- Must not do: reveal/decrypt/ACL/identity disclosure.
- Nondelegable gates: disclosure policy existence is checked by registry before
  module validation.

## Execution Layer

These contracts are not rule-package validator modules. They consume existing
authorised records and write execution receipts. They remain inside the
no-publication-advantage and no-truth-engine boundary.

**`ValueSettlementExecutor`**

- Consumes: existing allocation or consequence records carrying
  `ValueExecutionMode`, `ValueSettlementKind`, asset, payer, subject, evidence,
  package, and authority metadata.
- May do: mock ERC20 transfer, escrow deposit/claim/refund,
  administrative-priority-token mint/consume, repayment obligation, future
  setoff, waiver, satisfaction, and clawback-transfer settlement receipts.
- Must not do: create standing/reputation, decide manuscript merit, grant
  publication priority, execute sanctions, reveal content, directly seize
  unrelated wallet assets, delete source records, bypass source records, or
  turn record-only records into recovery receipts.
- Guard: `ExecuteValueSettlement` authority, known subject, executable source,
  settlement-kind binding, duplicate-final-state guard, source-bound recovery
  reference, and one terminal recovery conclusion per source.

**`DisclosureAccessExecutor` plus `IDisclosureExecutionModule`**

- Consumes: evidence, recognised-state, challenge, workflow, or
  disclosure-policy targets.
- May do: access grant plus grant-closure revocation/expiry/supersession
  receipts, target-level lifecycle execution receipts, voluntary disclosure
  intents, and anonymous challenge proof-use receipts.
- Must not do: reveal/decrypt evidence or identity, implement production ACL,
  mutate recognised states, update standing, or affect publication.
- Guard: `RecordDisclosureExecution` authority, target/policy existence, target
  package disclosure-execution module validation, grant closure status checks,
  source-grant link for grant closures, package-aware proof context, and
  nullifier replay guard.

**`ExternalOperationRegistry`**

- Consumes: recognised-state, challenge, evidence, allocation, or consequence
  targets.
- May do: external operation intent and acknowledgement/cancellation/
  supersession receipts with operation context hash and `sourceOperationId` on
  terminal receipts.
- Must not do: execute queue changes, billing, editorial decisions,
  acceptance/rejection, publication priority, payment, or sanctions.
- Guard: `RecordExternalOperation` authority, target workflow check, supplied
  evidence receipt usable-active workflow check, operation context binding, and
  one terminal receipt per requested operation.

Standing and reputation remain computed governance memory over recognised-state
history, standing update records, and challenge/correction/restoration records.
They are not tokens, credit balances, transferable assets, or consumable rights.
Standing credentials are separate non-transferable, expiring,
revocable/supersedable proof carriers over authorised standing-computation
records. Administrative priority tokens are separate bounded allocation
artifacts for queue/service access demos only; they are not standing,
reputation, or scholarly conduct.

Penalty / recovery is separated into value recovery, standing penalty input, and
eligibility / screening consequence. Value recovery may record forfeiture,
repayment obligation, future payout setoff, priority-token return obligation,
escrow refund, waiver, satisfaction, or clawback-transfer receipt. Standing
penalty input is not a token deduction or balance change; it is read by the next
standing computation.

Reward and penalty reversal must be lossless. Grant, execution, freeze, void,
repayment obligation, setoff, waiver, satisfaction, reversal, and restoration
records are appended rather than deleted on the implemented recovery paths, but
setoff, waiver, and satisfaction are mutually exclusive terminal recovery
receipts for a source.
Standing credential proof checks are package-, subject-, vector-, category-,
threshold-, and range-bound. Standing-relevant settlement impact records suspend
active standing credentials before those credentials can be used as proof again,
but unrelated or mismatched settlement sources cannot suspend a credential.

Standing-computation records carry explicit provenance and freshness state:
epoch, source-record-set hash, computation-rule hash, and
`Active` / `Superseded` / `Invalidated` status. Credentials can prove only while
their source computation remains active.

## Current Verification

Current tests cover permissive modules failing to bypass substrate gates,
rejecting modules failing closed before storage mutation, module selector
absence for reveal/publication functions, separated downstream adapter record
families, parameterized value-readiness records remaining record-only, and
incompatible rule-package lifecycle rejection through address-and-code-bound
`modulesHash` plus `compatibilityKey`.

Execution-layer tests cover authorised mock-token settlement, duplicate
settlement rejection, escrow claim/refund, administrative-priority-token
mint/consume without publication selectors, privacy access grant/revocation,
anonymous proof-use recording, and external operation intents that cannot
execute publication decisions.

Standing credential tests cover issuance from authorised computation records,
raw-source rejection, active-subject checks, expiry, revocation, supersession,
non-transferability, absent reward/payment/priority/publication selectors, and
threshold/category proof without recomputing history. The package-bound subject
proof path does not require the holder account in the proof call.

Recovery and penalty tests cover standing-relevant settlement suspension,
append-only repayment/setoff/waiver/satisfaction receipts, single terminal
recovery conclusion per source, source-bound recovery without unrelated-wallet
seizure, and distinct fraud, irresponsible-review, malicious-challenge, and
good-faith failed-challenge treatment without direct standing updates.

ZK standing tests cover Formula V0 standing-computation examples, standing
credential proof/use-surface hardening, ZK standing computation proof receipts,
commitment-bound ZK standing credentials, formula/source-set commitment
registry gates, source-bound credential suspension, wrong
package/subject/source rejection, rejected-good-faith challenge protection,
malicious/fabricated challenge-transition suspension records, and forbidden
selector boundaries.
