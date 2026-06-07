# AVA Peer Review Technical Architecture

This document describes the public technical architecture of the AVA Peer
Review Solidity demo. The project is an early sample of the AVA protocol
applied to peer-review governance. It is not a full journal platform, a
manuscript decision engine, a scientific-truth engine, a disclosure-reveal
system, a payment system, or a sanction engine.

The demo shows how peer-review governance can be represented as role-scoped
subjects, evidence-backed records, authorised transitions, rule packages,
privacy-preserving proof receipts, and bounded downstream records.

The implementation is written as a Base-compatible EVM/Solidity contract demo.
Base is the intended L2 target for future deployment work. The current
repository remains a local Foundry demo: it does not include deployed Base
addresses, production deployment hardening, chain-specific governance rollout,
or live network configuration.

## 1. Architecture Boundary

AVA is represented through three macro stages:

- Attribution: who acts, under which role-scoped subject, and with what
  authority.
- Verification: which evidence-backed governance object becomes a recognised
  state, and how it can be challenged, corrected, restored, or vested.
- Allocation: which bounded downstream record may follow from an eligible
  recognised state.

Recognised state is the central governance object. It is not a fourth AVA
stage. Challenge, correction, restoration, disclosure, standing, reward,
priority, penalty, value settlement, and credentials are support or downstream
surfaces around recognised states; they are not additional AVA stages.

The contracts do not decide manuscript acceptance, rejection, manuscript merit,
scientific truth, reviewer leniency, or publication priority.

## 2. From Governance Grammar To Records

The research-facing AVA grammar asks what has become governable before a
technical system records or executes anything. The Solidity demo translates
that grammar into a small set of chain-readable objects:

| Governance question | Contract representation |
| --- | --- |
| What object is being attributed? | Manuscript pointer, review contribution, recognised-state object id, challenge target, or external-operation target. |
| Who is responsible or authorised? | Role-scoped `subjectId`, `authorityId`, role/action permission, and caller binding. |
| What evidence was received? | Evidence receipt id, commitment, URI, evidence type hash, workflow key, package id, and lifecycle status. |
| What disclosure condition applies? | Disclosure policy id, disclosure module validation, proof-use receipt, access/lifecycle receipt, subject commitment, and nullifier where relevant. |
| What governance state exists? | `RecognisedStateRecord` plus generic recognised-state transition ledger. |
| How can it be challenged or repaired? | Challenge record, challenge transition record, outcome, correction/restoration path, and preserved history. |
| What bounded consequence can follow? | Standing input, standing computation, credential, allocation, consequence, penalty, restoration, settlement, external-operation, or audit record, all tied to an eligible source. |

This is the rule-to-executable bridge. A prose institutional rule must be
translated into an object, subject, evidence receipt, authority condition,
disclosure condition, recognised state, transition condition, and bounded
consequence before it can become a module check or substrate record.

The bridge also defines the model boundary. These records can later be read as
state/action/transition/information/payoff-proxy material for modelling. The
Solidity demo itself does not run a model, simulation, probability estimate,
truth engine, or manuscript-merit calculation.

## 3. System Layers

The demo has four practical layers.

### Substrate Layer

The substrate owns records, ids, subject binding, authority gates, package
identity, evidence references, recognised-state storage, transition ledgers,
challenge records, downstream records, proof receipts, settlement receipts, and
audit receipts.

Core substrate contracts:

- `RoleIdentityRegistry`
- `AuthorityMatrix`
- `EvidenceCommitmentRegistry`
- `DisclosurePolicyRegistry`
- `AVARulePackageRegistry`
- `AVAStateMachine`
- `StandingRegistry`
- `AllocationExecutor`
- `ConsequenceExecutor`
- `AttestationAuditModule`

The substrate is the part future work should not casually rewrite. It provides
the stable grammar: subjects, authority, evidence, package identity,
recognised states, transitions, challenges, downstream record ids, proof
receipts, settlement receipts, and audit receipts.

### Rule-Package Layer

Rule packages bind a `workflowKey` to validator modules and adapters. Each
registration creates a stable `packageId`. New records use the currently active
package for a workflow key, but old records keep the package identity recorded
when they were created.

This prevents future workflow reconfiguration from retroactively changing old
recognised states, challenges, proof receipts, standing records, settlement
records, or downstream consequences.

This is the main extension pattern:

```text
AVA substrate -> functional interface -> scenario-selected module
```

For example, the substrate calls `IAttributionModule` when a workflow object is
formed. A default package may use `DefaultAttributionModule`; a pseudonymous
review package may use `SubjectSaltAttributionModule`. The caller still goes
through the same substrate entrypoint, authority check, subject binding,
evidence check, package binding, and record ledger.

The same pattern applies across the rest of the rule package:

- `IVerificationModule` can be backed by default reference validation or an
  evidence-threshold module.
- `IDisclosurePolicyModule` can be backed by double-blind, panel-visible,
  anonymous challenge, voluntary real-name, post-recognition author-reveal, or
  ZK-backed disclosure modules.
- `IChallengeLifecycleModule` can use the default lifecycle or a panel-only
  lifecycle rule.
- `IStandingAdapter`, `IStandingComputationModule`, and credential issuers can
  vary standing vectors and proof surfaces without turning standing into a
  token or public prestige score.
- `IRewardAdapter`, `IPriorityAdapter`, `IPenaltyAdapter`,
  `IRestorationAdapter`, and `IValueExecutionAdapter` can vary downstream
  record readiness while keeping actual records source-bound and bounded.

Modules validate or veto. They do not grant authority, mutate substrate storage
directly, reinterpret ids, reveal identity, execute sanctions, decide
publication, or judge scientific truth. The substrate writes the records only
after the relevant substrate gates and module checks all pass.

### Privacy And Proof Layer

Privacy-related contracts record proof-use and disclosure receipts. They bind
context, package identity, target object, subject or subject commitment,
policy, verifier, proof domain, and nullifier where relevant.

These contracts do not reveal identity, decrypt evidence, implement production
access control, or prove scientific truth.

Key contracts:

- `ZKProofRegistry`
- `DisclosureAccessExecutor`
- `StandingFormulaRegistry`
- `ZKStandingComputationRegistry`
- `ZKStandingCredentialRegistry`
- `StandingCredentialRegistry`

### Downstream Record And Execution Layer

Downstream contracts can record bounded consequences, allocation records,
standing update inputs, standing computation statements, standing credentials,
administrative-priority artifacts, mock settlement receipts, recovery records,
and external-operation intents.

These records are audit surfaces. They are not publication effects, real
payments, sanction execution, or reputation tokens.

Key contracts:

- `AllocationExecutor`
- `ConsequenceExecutor`
- `ValueSettlementExecutor`
- `ExternalOperationRegistry`
- `StandingRegistry`
- `StandingCredentialRegistry`

## 4. Contract Map

| Contract | Public role |
| --- | --- |
| `RoleIdentityRegistry` | Stores canonical role-scoped subjects and active/inactive subject state. |
| `AuthorityMatrix` | Stores role/action permissions and enforces authority-subject binding. |
| `EvidenceCommitmentRegistry` | Stores evidence receipts as commitments, URIs, workflow/type references, package identity, disclosure policy references, and lifecycle status. |
| `DisclosurePolicyRegistry` | Stores disclosure policy metadata and active policy references. |
| `AVARulePackageRegistry` | Registers workflow packages, module/adaptor bindings, compatibility metadata, lifecycle readiness records, and active-package pointers. |
| `AVAStateMachine` | Stores manuscripts, review contributions, recognised states, challenge records, challenge transitions, and generic recognised-state transitions. |
| `StandingRegistry` | Records standing update inputs and standing computation records as governance memory, not assets. |
| `StandingCredentialRegistry` | Issues non-transferable, expiring, revocable/supersedable proof carriers from authorised standing-computation records. |
| `StandingFormulaRegistry` | Records formula metadata, source-set commitments, completeness attestations, and computation statements for privacy-preserving standing computation. |
| `ZKStandingComputationRegistry` | Records package-bound standing proof receipts from registered formula/source-set/computation statement inputs. |
| `ZKStandingCredentialRegistry` | Records commitment-bound standing credential proof carriers and target-bound proof-use receipts. |
| `AllocationExecutor` | Records bounded allocation, reward-value, and administrative-priority records for eligible recognised states. |
| `ConsequenceExecutor` | Records bounded consequence, penalty, restoration, recovery, and eligibility records. |
| `ValueSettlementExecutor` | Consumes authorised allocation/consequence source records and writes mock settlement receipts. |
| `DisclosureAccessExecutor` | Records disclosure access, closure, lifecycle, voluntary-intent, and anonymous proof-use receipts. |
| `ExternalOperationRegistry` | Records external-operation intents and terminal receipts without executing external platform actions. |
| `AttestationAuditModule` | Records workflow-aware and target-bound attestation receipts. |

## 5. Core Governance Flow

A typical peer-review path looks like this:

1. Assign role-scoped subjects for author, reviewer, editor, challenger, panel,
   institution, and protocol executor roles.
2. Register an active workflow package and its validator/adaptor modules.
3. Register disclosure policy references and evidence receipts.
4. Register a manuscript pointer as off-chain metadata.
5. Register a review contribution with reviewer subject and evidence receipt.
6. Provisionally recognise the review contribution as a recognised state.
7. Open a challenge window.
8. File, screen, resolve, restore, or close challenges through authorised
   transition paths.
9. Record generic recognised-state transitions whenever recognised-state status
   changes.
10. Record bounded downstream consequences, standing update inputs, allocation
    records, audit receipts, proof-use receipts, or settlement receipts only
    when the source recognised state and evidence references are eligible.

Raw review ids, raw challenge ids, raw evidence ids, unknown ids, inactive
subjects, unsupported statuses, and cross-package or cross-workflow references
cannot directly create downstream standing, allocation, consequence,
credential, settlement, or publication effects.

## 6. Module Taxonomy

The interface taxonomy has three layers.

### AVA Core Stage Interfaces

- `IAttributionModule`
- `IVerificationModule`
- `IAVAAllocationModule`
- `IAllocationAdapter`

These correspond to AVA's Attribution, Verification, and Allocation stages.

### Recognised-State Governance Support

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
- `IEditorialSystemAdapter`

These modules validate governance context, policy references, lifecycle
readiness, residual procedural authority, and admissibility. They cannot own
substrate storage or create publication, reveal, payment, sanction, standing,
or truth effects.

### Downstream Consequence / Execution / Proof Support

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
- `IStandingFormulaRegistry`
- `IZKStandingCredentialIssuer`

These interfaces support records or proof carriers at or after the Allocation
edge. They are not new AVA stages.

## 7. Evidence And Disclosure

Evidence receipts are references and commitments. They record:

- workflow key and package identity;
- commitment and URI;
- evidence type label and evidence type hash;
- disclosure policy reference;
- registering subject and actor;
- lifecycle status.

Evidence checks enforce existence, workflow/package compatibility, usable
status, and policy reference integrity. They do not inspect evidence content,
judge truth, or reveal confidential material.

Disclosure execution records are access/proof-use/intent/lifecycle receipts.
They can record that a disclosure-related action was authorised and bound to a
target context. They do not perform real reveal, real decryption, or production
access control.

## 8. Challenge, Correction, And Restoration

Challenge and correction operate over recognised states, not raw accusations.

- Filing a challenge creates a challenge record only.
- Screening moves the challenge lifecycle forward but does not decide truth or
  wrongdoing.
- Resolution is panel-authorised and rejects self-resolution by the challenger.
- Outcomes distinguish upheld challenge, rejected good-faith challenge,
  negligent challenge, and malicious or fabricated challenge.
- Only outcome-appropriate authorised transitions can mutate the underlying
  recognised state.
- Restoration is explicit and record-preserving; it is not a silent overwrite.

Raw challenges cannot directly create standing updates, sanctions, allocations,
rewards, payments, public consequences, or publication effects.

## 9. Standing And Credentials

Standing and reputation are computed governance memory over recognised-state
history, standing update records, challenge/correction/restoration records,
standing computation records, and related proof receipts.

Standing is:

- role-scoped;
- vector or dimension based;
- procedural weight;
- challengeable, correctable, and restorable through records;
- not a token, credit, balance, reward, public prestige score, priority token,
  transferable asset, or manuscript-merit signal.

Standing credentials are proof carriers. They can help a subject prove a
threshold, range, category, or panel-visible standing signal without exposing a
full history or recomputing everything in an ordinary interaction.

Credentials are non-transferable, expiring, revocable, supersedable, and
source-bound where relevant. A stale, revoked, superseded, suspended, or expired
credential cannot serve as an active proof.

## 10. Value, Priority, Penalty, And Recovery

The demo includes record and mock-settlement surfaces for downstream
administrative effects. These surfaces remain bounded.

- Reward/value records are records or mock settlement sources, not production
  payment guarantees.
- Administrative priority tokens are separate queue/service-right artifacts,
  not standing, reputation, publication priority, or reviewer leniency.
- Penalty records separate value recovery, standing penalty input, and
  eligibility or screening restriction.
- Good-faith failed challenges are not misconduct penalties.
- Recovery and restoration records are append-only; they do not delete prior
  history.

No contract executes sanctions or creates manuscript advantage.

## 11. Audit And Reconstruction

The demo is designed to be reconstructed from ids, events, getters, hashes, and
source records. Public readers should reconstruct records by stored `packageId`
and source record rather than by the current active workflow package alone.

Use:

- `record-reconstruction-guide.md` for event/getter reading;
- `rule-package-compatibility-migration-policy.md` for package replacement
  rules;
- `interface-contract-spec.md` and `module-capability-matrix.md` for module
  boundaries.

## 12. Verification

The current verified state is:

- `forge build` passes.
- `forge test` passes with 221 tests.
- The baseline demo script runs locally with:

```bash
forge script script/AVADemoScenario.s.sol:AVADemoScenario --sig "run()" --offline
```

Foundry may emit non-blocking lint-style notes. Those notes do not change the
current ABI, storage semantics, or verification result.

## 13. What Remains Outside This Demo

The following are intentionally not implemented:

- manuscript acceptance, rejection, merit scoring, or publication decisions;
- scientific truth adjudication;
- identity reveal, evidence reveal, real decryption, or production ACL;
- production ZK circuits;
- production token, stablecoin, payment, or queue integration;
- sanction execution;
- full peer-review platform workflows;
- mathematical model or simulation logic inside Solidity;
- production deployment hardening.
