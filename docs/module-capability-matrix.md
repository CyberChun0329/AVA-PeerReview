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

## Canonical Multi-Application Capability Map

The canonical source tree separates capability ownership as follows:

| Owner | Canonical contracts | Replaceable surface |
| --- | --- | --- |
| AVA Core | `AVAApplicationRegistry`, `AVAIdentityRegistry`, `AVAAuthorityMatrix`, `AVACoreRulePackageRegistry`, `AVADisclosurePolicyRegistry`, `AVAEvidenceRegistry`, `AVAWorkflowPolicyRouter`, `AVAGovernanceKernel` | Core storage and hard gates are not replaceable; package-selected policy modules may only validate or veto. |
| Reusable extensions | `AVAChallengeExtension`, standing/downstream extensions, privacy/disclosure/audit/settlement/external-operation extensions | An app may omit an extension or bind a capability module. Absence fails closed and cannot weaken Core. |
| Application | `PeerReviewApplicationModule` | Role, object, relationship, and downstream action vocabulary. The application module is validator-only. |
| Genericity test fixture | `test/helpers/SecondaryTestApp.sol` | Exercises a second namespace and different vocabulary without becoming production source. |

All canonical records are scoped by `appId`. Rule packages are addressed by
`(appId, workflowKey)` and receive immutable `packageId` values. Core imports
no application source. Peer Review and the test-only secondary application can
therefore reuse one workflow key without sharing subjects, evidence, packages,
objects, states, or downstream records.

The matrices below retain the larger pre-separation interface catalogue for
compatibility and research traceability. New applications should use the
canonical capability-key bindings in `AVACoreRulePackageRegistry`.
The registry accepts at most 64 capability bindings per package. It stores an
immutable ordered capability layout and bounds every later full-package
revalidation. A module shared by several capability keys contributes once to
the runtime identity fingerprint, while every capability binding remains
independently addressable and replaceable in a successor package.

### Canonical Package Dispatch

| Capability | Canonical interface | Dispatch owner | Nondelegable boundary |
| --- | --- | --- | --- |
| Application vocabulary | `IAVAApplicationModule` | kernel, evidence registry, router, and extensions | app namespace, object/state ids, subject and authority binding remain substrate-owned; parent app/package compatibility is checked before the module receives parent workflow/package/type/subject context; transition context includes action and source-record identity so an app can reject lifecycle bypasses |
| Attribution | `IAVAAttributionModule` | governed-object registration | cannot create a recognised state or grant authority |
| Verification | `IAVAVerificationModule` | `AVAWorkflowPolicyRouter.validateFormation` | cannot judge truth or bypass formation status rules |
| Transition rule | `IAVATransitionRuleModule` | `AVAWorkflowPolicyRouter.validateTransition` | cannot widen `AVACoreTransitionRules` |
| Evidence policy/lifecycle | `IAVAEvidencePolicyModule`, `IAVAEvidenceLifecycleModule` | evidence registration and router | existence, app/workflow/package/subject/policy binding and active-state checks remain in Core |
| Disclosure policy | `IAVADisclosurePolicyModule` | evidence registration and router | reference validation only; no reveal, decrypt, or production ACL |
| Challenge policy | `IAVAChallengePolicyModule` | `AVAChallengeExtension` through router | challenge must already be its own governed object and recognised state; raw filing cannot mutate target |
| Authority policy | `IAVAAuthorityPolicyModule` | router | `AVAAuthorityMatrix` role/action/canonical-subject gate always runs first |
| Field and anti-abuse | `IAVAFieldPolicyModule`, `IAVAAntiAbusePolicyModule` | router | veto only; cannot write Core or create punishment |
| Standing, Allocation, consequence | `IAVAStandingPolicyModule`, `IAVAAllocationPolicyModule`, `IAVAConsequencePolicyModule` | dedicated downstream extensions | eligible current state/evidence/package and active subject checks remain substrate-owned |
| Optional extension policy | `IAVAExtensionPolicyModule` | proof, disclosure, audit, settlement, external-operation, governance extensions | capability absence fails closed; module cannot own extension storage or call external systems |

## Substrate-Owned Capabilities

The canonical substrate owns and records:

- application namespaces through `AVAApplicationRegistry`;
- app-scoped canonical subjects and authority through `AVAIdentityRegistry`
  and `AVAAuthorityMatrix`;
- generic governed objects, recognised states, and transition records through
  `AVAGovernanceKernel`;
- app/workflow/package capability bindings through
  `AVACoreRulePackageRegistry`;
- nonzero, re-verifiable behaviour identity for every package-bound module;
- app-scoped disclosure-policy references through
  `AVADisclosurePolicyRegistry`;
- app/workflow/package/subject-bound evidence and evidence-lifecycle records
  through `AVAEvidenceRegistry`;
- optional challenge, standing, allocation, consequence, credential, proof,
  disclosure, audit, settlement, and external-operation records through their
  dedicated `src/extensions/` contracts.

The retained pre-separation substrate additionally owns and records:

- role/action authority checks through `AuthorityMatrix`;
- role-scoped subject binding through `RoleIdentityRegistry`;
- immutable rule-package identity through `AVARulePackageRegistry.packageId`,
  `modulesHash`, and `modulesIdentityHash`;
- evidence receipt storage, workflow/type references, package binding, and
  active/inactive lifecycle status through `EvidenceCommitmentRegistry`;
- manuscript, review contribution, recognised-state, review challenge-window,
  and generic recognised-state transition storage through `AVAStateMachine`;
- challenge and challenge-transition storage through `AVAChallengeWorkflow`;
- downstream standing, allocation, consequence, and audit record storage
  through their dedicated registries;
- standing credential proof-carrier storage through
  `StandingCredentialRegistry`;
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

For state-derived extension records, the nondelegable evidence gate compares
application, workflow, package, subject, and disclosure policy against the
source recognised state. An alternate receipt with a different policy cannot
be relabelled under the state's policy by a permissive module.

Standing-revision record writers are package-scoped. The revision extension
revalidates the package application and subject application on every write; a
writer authorised for one package cannot invalidate another package's
credential surface.

The canonical Peer Review application binds misconduct vocabulary to its object
model. Review-contribution states accept irresponsible-review findings;
challenge states accept negligent or malicious/fabricated-challenge findings.
Academic-fraud findings remain unavailable until an author/manuscript
recognised-state workflow explicitly defines that target in a future package.

## Historical Appendix: Retained Interface Taxonomy

The AVA technical framework separates interfaces into three layers. Only the
first layer maps directly to AVA's macro stages.

### Layer A: AVA Core Stage Interfaces

| AVA stage | Interface | Called by | Current limit |
| --- | --- | --- | --- |
| Attribution | `IAttributionModule` | `AVAWorkflowValidator`, called by the state machine and challenge workflow | Validates attributed object only; not truth, reward, or publication effect |
| Verification | `IVerificationModule` | `AVAWorkflowValidator`, called by the state machine and challenge workflow | Validates references and workflow predicates; not scientific truth or manuscript merit |
| Allocation | `IAVAAllocationModule` / `IAllocationAdapter` | `AllocationExecutor.executeAllocation` | Validates bounded AVA Allocation record fields; not token/payment/queue execution or publication priority |

### Layer B: Recognised-State Governance Support

These interfaces support recognised-state governance. Transition, challenge,
correction, disclosure, residual editorial authority, evidence policy,
evidence lifecycle, audit, field policy, and anti-abuse validation are not new
AVA stages.

| Support function | Interface | Called by | Current limit |
| --- | --- | --- | --- |
| Transition rule | `ITransitionRuleModule` | `AVAStateMachine` generic and challenge-requested recognised-state transitions | Cannot own state storage or allow substrate-forbidden high-impact paths; target mutations use the target state's fixed package |
| Challenge-window timing | `IChallengeWindowRuleModule` | `AVAStateMachine.vestReviewRecognition` when the selected transition module declares `supportsChallengeWindowRule()` | Optional additional duration veto above the immutable nonzero substrate minimum; declared validator reverts are vetoes; no scheduler, oracle, expiry executor, or automatic challenge closure |
| Challenge lifecycle | `IChallengeLifecycleModule` | `AVAChallengeWorkflow` file/screen/resolve/restore/close | Lifecycle admissibility under the challenge package only; substrate derives restoration target from filing status and enforces subject/account filing caps; no sanction, standing update, allocation, or direct status mutation |
| Disclosure policy | `IDisclosurePolicyModule` | Evidence registry and state/challenge paths | Policy/reference compatibility only; no reveal/decrypt/ACL |
| Disclosure lifecycle | `IDisclosureLifecycleModule` | `recordDisclosureLifecycleReadiness` | Readiness record only; no reveal/decrypt/ACL/identity disclosure |
| Disclosure execution | `IDisclosureExecutionModule` | `DisclosureAccessExecutor` using target `packageId` | Access grant/revoke/expiry/supersession, lifecycle, proof-use, and voluntary-intent receipt validation only; no reveal/decrypt/ACL engine |
| Residual editorial authority | `IResidualEditorialAuthorityModule` plus `AuthorityApprovalRegistry` for receipt-backed examples | `AVAStateMachine` recognised-state paths and `AVAChallengeWorkflow` decision paths | Decision-hash-bound procedural authority validation only; recursive challenge resolution, restoration, and close validate both challenge and target packages, and the hash binds both lifecycle versions. Current examples cover a single action, a static single authority or emergency gate, receipt-backed m-of-n approval with optional conflict exclusion, and a standing-credential gate. Generic multisig and cross-role institutional co-signature are not current implementations; no acceptance, rejection, merit, or publication priority. |
| Evidence policy | `IEvidencePolicyModule` | Evidence registration and evidence-backed state/challenge paths | Workflow/type/reference compatibility only; no truth validation |
| Evidence lifecycle | `IEvidenceLifecycleModule` | Evidence registration, formation, governed transitions, challenge actions, standing/allocation/consequence creation, standing formula/source-set/statement records, ZK standing proof and credential issuance, audit and external-operation writes, non-refund value settlement, evidence lifecycle hook | Action-scoped lifecycle validation only; pinned receipts are rechecked against their historical workflow/package before later effectful transition or downstream use. A source-bound upheld correction may preserve inactive target evidence while challenge evidence remains active. Proof, credential, audit, external-operation, and non-refund settlement paths also revalidate historical package module identity; substrate binds self-management or panel/institution cross-subject authority and rejects self-supersession or replacement across workflow/package/subject/policy/type; no delete/reveal/truth adjudication. |
| Audit adapter | `IAuditAdapter` | `AttestationAuditModule` workflow-aware and target-bound attestation paths | Historical package and evidence-lifecycle validation precede attestation reference/hash validation; substrate storage records explicit target kind and action, and the generic path is evidence-receipt-bound |
| Field policy | `IFieldPolicyModule` | `AVAStateMachine` recognised-state validation | Field/venue admissibility only; cannot replace authority/evidence/status gates |
| Anti-abuse | `IAntiAbuseModule` / optional `IChallengeRateLimitModule` | Review, challenge, standing, allocation, consequence paths | Veto only; the default module remains permissive but cannot bypass the substrate's one-open-challenge-per-subject/target rule or one-filing-per-subject/target-version rule; selected packages can reject repetition across later target versions or active eligibility restrictions; `RestrictionAwareChallengeIntakeModule` can veto challenge intake while a package-bound restriction is active; declared validator reverts are vetoes; no sanction execution, standing update, or state write |

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
| Standing computation | `IStandingComputationModule` | Standing-computation readiness paths; example `FormulaV0StandingComputationModule` | Vector/dimension readiness binds the current package/subject standing revision plus epoch, source-record-set hash, computation-rule hash, and active/superseded/invalidated status; no public score or asset-like standing |
| Standing credential | `IStandingCredentialIssuer` | `StandingCredentialRegistry` | Non-transferable proof carrier over an active, current-revision computation only; not standing itself, reputation, reward, priority token, or asset |
| Reward record | `IRewardAdapter` | `AllocationExecutor.recordRewardValue*` | Record validation only; no transfer or publication effect |
| Priority record | `IPriorityAdapter` | `AllocationExecutor.recordAdministrativePriority*` | Administrative queue/service right only; no publication priority or reviewer leniency |
| Consequence record | `IConsequenceAdapter` | `ConsequenceExecutor.registerConsequence*` | Bounded administrative/procedural record only |
| Penalty record | `IPenaltyAdapter` | `ConsequenceExecutor.recordPenalty*` | Penalty record validation only; no sanction execution or direct standing update |
| Restoration record | `IRestorationAdapter` | `ConsequenceExecutor.recordRestoration*` | Repair record only; no silent overwrite or reward mint |
| Value execution readiness | `IValueExecutionAdapter` | Allocation, reward, priority, consequence, penalty, restoration record paths | Readiness validation only; settlement executor consumes authorised sources separately |
| Value settlement | `IValueSettlementExecutor` | `ValueSettlementExecutor` | Source-bound settlement receipts include source execution context and settlement context hash only. Record-only setoff/waiver/satisfaction and reward freeze/void remain defensive closeouts over immutable historical references; vest/restore, obligation creation, settlement, and clawback require active references. No standing/reputation/publication/sanction engine. |
| External operation | `IExternalOperationRegistry` | `ExternalOperationRegistry` | Requests and acknowledgements revalidate the target package and evidence lifecycle; cancellation/supersession remain defensive closeouts; receipts carry operation context hash and terminal receipts link to their source request; no external platform operation |
| Rule-package lifecycle | `IRulePackageLifecycleModule` | Rule-package registration, lifecycle readiness, and object migration readiness receipts | Compatibility/readiness only; object readiness is record-only; no migration executor or retroactive package rewrite |
| ZK proof verification | `IZKProofVerifier` | `ZKProofRegistry` | Package-aware, context-bound verification receipt only; default registration binds the active package, while explicit package-bound registration supports historical targets after workflow supersession; no identity reveal or authority grant |
| Standing formula/source-set/statement | `IStandingFormulaRegistry` | `StandingFormulaRegistry` | Historical-package and action-scoped evidence-lifecycle validation precedes package-bound formula metadata, source-set commitment, completeness-attestation, and computation-statement records; no standing computation, source-history traversal, production ZK circuit, reveal, standing update, or credential issuance |
| ZK standing computation proof | `IZKProofVerifier` | `ZKStandingComputationRegistry` | Historical package identity and `RegisterStandingProof` evidence-lifecycle validation precede a package-bound, subject-commitment-bound receipt with exact registered formula/source-set/statement, verifier/proof-domain, revision, and nullifier binding. The canonical extension pins direct-verifier runtime codehash and proof domain and fails closed on drift; mutable proxy verifier identities are not claimed. No production ZK circuit, reveal, standing update, or credential issuance. |
| ZK standing credential | `IZKStandingCredentialIssuer` | `ZKStandingCredentialRegistry` | The retained registry is commitment-only; the canonical `AVAStandingZKCredentialExtension` instead binds both role-scoped `subjectId` and subject commitment and is therefore role-subject-linkable rather than unlinkably anonymous. Both remain proof carriers: proof-use records require a verifier proof bound to the credential commitment, and neither exposes an owner balance, transfer, approval, reward, priority token, reveal, publication, or manuscript effect. |

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

- Called by: `AVAWorkflowValidator` for state-machine recognised-state/review
  formation and challenge-workflow challenge formation.
- May validate: attributed object reference and role-scoped subject/object
  relation.
- May veto: yes.
- Must not do: grant authority, write state, judge truth, or reveal identity.
- Nondelegable gates: caller authority, subject binding, usable active
  evidence/workflow, and package identity.

**Verification, `IVerificationModule`**

- Called by: `AVAWorkflowValidator` for state-machine recognised-state/review
  formation and challenge-workflow challenge formation.
- May validate: reference sufficiency and workflow-specific verification
  predicates.
- May veto: yes.
- Must not do: score manuscript merit, decide scientific truth, or
  accept/reject manuscripts.
- Nondelegable gates: usable active evidence/workflow, recognised-state status
  gates, and package identity.

**Transition rule, `ITransitionRuleModule`**

- Called by: `AVAStateMachine` for generic transitions and for restricted
  challenge-driven correction/restoration requests from the one-time-bound
  `AVAChallengeWorkflow`.
- May validate: workflow-specific transition admissibility.
- May veto: yes.
- Must not do: mutate status directly or allow substrate-forbidden
  high-impact paths.
- Nondelegable gates: generic transition only `Registered -> Vested`;
  challenge paths only for `Downgraded`, `Voided`, or `Restored` as the
  substrate allows.
- Optional extension: `IChallengeWindowRuleModule` can veto vesting before a
  package-configured duration has elapsed after the module declares
  `supportsChallengeWindowRule()`. It can only extend the deployment's
  immutable substrate minimum. It cannot close challenges, schedule execution,
  or replace open-challenge-count blocking.

**Disclosure policy, `IDisclosurePolicyModule`**

- Called by: evidence registry and state/challenge paths.
- May validate: policy reference and action compatibility.
- May veto: yes.
- Must not do: reveal/decrypt evidence or identity, or implement ACL.
- Nondelegable gates: policy existence where required and no on-chain
  confidential content.

**Challenge lifecycle, `IChallengeLifecycleModule`**

- Called by: `AVAChallengeWorkflow` file/screen/resolve/restore/close paths.
- May validate: lifecycle admissibility and action sequencing.
- May veto: yes.
- Must not do: sanction, mutate recognised state directly, or erase history.
- Nondelegable gates: an existing target in `Challengeable`, `Vested`, or
  `Restored`; subject-level self-resolution rejection; decision-hash and
  authority binding; outcome mutation rules; causal restoration; and both
  challenge-specific and generic transition ledgers.

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

- Called by: `AVAStateMachine` recognised-state paths and
  `AVAChallengeWorkflow` challenge-governance paths.
- May validate: procedural residual authority predicates. Current examples
  cover a single allowed action, a static single authority or emergency gate,
  receipt-backed m-of-n approval with optional conflict exclusion, and a
  standing-credential gate. Generic multisig and cross-role institutional
  co-signature require separate future validator modules and are not claimed
  by the current examples.
- May veto: yes.
- Must not do: create acceptance, rejection, merit, reveal, sanction, reward,
  payment, or publication priority logic.
- Nondelegable gates: `authorityId` binding, recognised-state storage, and
  transition ledger.
- Receipt-backed example: `AuthorityApprovalRegistry` records package/action/
  object/authority-subject approval receipts with evidence and expiry;
  `ApprovalReceiptAuthorityModule` checks m-of-n active receipts and optional
  subject-aware conflict exclusion; an excluded subject neither executes the
  decision nor contributes to the threshold.
- Canonical receipt bound: `AVAApprovalReceiptExtension` retains append-only
  receipts but counts at most 64 unique authority subjects per decision;
  expired reissues update the authority's latest counted receipt without
  growing the traversal set.

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
  challenger subject path after the module declares
  `supportsChallengeRateLimit()` and can reject repeated challenge filing. The
  bundled `SubjectRateLimitModule` uses that count as a permanent per-path
  cap; it is an example policy, not a universal challenge-right rule.
- Nondelegable challenge floor: one open challenge per subject/target and one
  filing per subject/target transition version, independent of package choice.
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
  superseded, invalidated, or stale-revision computations cannot support active
  proof.

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
  before active proof use, including equality with the current package/subject
  revision in `StandingRevisionRegistry`. Anonymous subject commitments use the
  same freshness check; an authorised, evidence-backed commitment-revision
  receipt can advance their revision without creating an identity link.

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
- Nondelegable gates: active or historical package identity, distinct
  formula/source-set/completeness/statement authority actions, action-scoped
  evidence-lifecycle validation, usable package-bound evidence receipts,
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
- Nondelegable gates: historical package identity, `RegisterStandingProof`
  evidence-lifecycle validation, subject commitment,
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
  responsible recognised-state subject, and evidence gates. The current demo
  does not use this path for implicit cross-subject consequences.

**Penalty adapter, `IPenaltyAdapter`**

- Called by: `ConsequenceExecutor.recordPenalty*`.
- May validate: penalty-record fields, including value recovery metadata,
  standing penalty input, and eligibility / screening consequence.
- May veto: yes.
- Must not do: execute sanction, punitive asset deduction, token transfer,
  direct standing update, or deletion of reward history.
- Nondelegable gates: consequence storage only; no sanction execution selector;
  target-side subject binding follows the source recognised state's responsible
  subject. The explicit challenger-finding path requires a negligent or
  malicious/fabricated challenge outcome and binds the challenge package,
  challenge evidence, and recorded challenger subject. Standing penalty input
  is consumed only by later standing computation. Finding kinds are bound to
  the responsible subject's role, and the same challenge/subject/dimension
  cannot produce a second standing input through another consequence record.

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
  source `modulesHash` / `modulesIdentityHash`, lifecycle kind, `version`,
  `compatibilityKey`, dependency metadata, deprecation flag, and target
  `packageId` plus target module/version metadata when required.
- May veto: yes.
- Must not do: migrate old states, mutate packages retroactively, or write
  records outside registry.
- Nondelegable gates: initial registration is distinct from explicit
  compare-and-set supersession; each package gets a new `packageId`, the
  version increases, and old states keep their old `packageId`; no-code module
  addresses and behaviour-identity drift are rejected; migration/supersession
  readiness binds explicit source and target package metadata; object migration
  readiness binds the object, source recognised state, evidence, authority, and
  boundary hash to an existing `MigrationReady` record; configured
  state/evidence readers require those references to belong to the source
  workflow/package; source package lifecycle module validates readiness.

**Evidence lifecycle, `IEvidenceLifecycleModule`**

- Called by: evidence registration, evidence-backed formation and transitions,
  standing/allocation/consequence creation, non-refund value settlement, and
  the evidence lifecycle hook.
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
  chain, and one terminal recovery conclusion per origin. Active recovery
  requires a completed, matching origin transfer or escrow claim, a linked
  misconduct consequence, one full repayment obligation, and one terminal
  clawback/setoff/waiver/satisfaction record. Settlement and standing-revision
  state is written before an external mock-asset call; a revert rolls the whole
  transaction back.

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
  evidence receipt usable-active workflow check, historical package identity,
  action-scoped evidence-lifecycle validation for requests/acknowledgements,
  defensive cancellation/supersession after package drift, operation context binding, and
  one terminal receipt per requested operation. Challenge-side negligent or
  malicious/fabricated consequence targets resolve through their recorded
  challenge package rather than the target recognised state's package.

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
but unrelated or mismatched settlement sources cannot suspend a credential. The
active credential index identifies one canonical active carrier for each
package/subject/vector/category key. A second direct issuance is rejected while
that carrier remains active; explicit supersession is required. Older credential
records remain inspectable by id but cannot prove after they cease to be the
canonical carrier.

Standing-computation records carry explicit provenance and freshness state:
epoch, source-record-set hash, computation-rule hash, and
`Active` / `Superseded` / `Invalidated` status. Credentials can prove only while
their source computation remains active. Ordinary proof also requires an active
role-scoped subject and active computation evidence. ZK proof re-checks active
source-set, completeness-attestation, and statement evidence.

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

The default canonical profile currently passes 250 tests. Its four
handler-based invariant suites pass at 512 runs by 128 calls. The explicit
retained profile passes 637 regression tests. These profiles are intentionally
separate so retained interface coverage cannot be mistaken for canonical
application/Core integration evidence.

ZK standing tests cover Formula V0 standing-computation examples, standing
credential proof/use-surface hardening, ZK standing computation proof receipts,
commitment-bound ZK standing credentials, formula/source-set commitment
registry gates, source-bound credential suspension, wrong
package/subject/source rejection, rejected-good-faith challenge protection,
malicious/fabricated challenge-transition suspension records, and forbidden
selector boundaries.
