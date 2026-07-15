# Current Implementation Summary

This document summarises the current implemented AVA Peer Review Solidity demo
for external readers. It is a public technical summary, not an internal
development log.

The repository is an early sample of the AVA protocol with peer review as its
first application. The current canonical implementation separates a domain-
neutral AVA Core, optional reusable extensions, and application modules. Peer
review is the only application implementation under `src/apps/`. A test-only,
domain-neutral secondary application verifies that app-specific roles, objects,
and modules can be replaced without editing Core contracts.

It is designed as a Base-compatible EVM/Solidity demo. The current
implementation remains a local Foundry project, not a live Base deployment.

The implementation is organised so future workflow development usually requires
choosing or writing modules behind existing interfaces, then binding those
modules into a rule package. The recognised-state substrate remains the common
execution grammar.

For readers using this repository alongside the paper, the important point is
that the Solidity code is not the source of peer-review truth or editorial
legitimacy. It is an executable representation of a narrower AVA grammar:
role-bound objects, evidence receipts, authority conditions, disclosure states,
challengeable recognised states, authorised transitions, and bounded
downstream records.

The current records can later support model extraction because they identify
the actor, target object, evidence receipt, governing package, status
transition, and bounded consequence. The demo itself does not run a model or
simulation.

The repository also includes a deterministic transition-admissibility artifact
at `generated/recognised-state-transition-matrix.csv`, hash-pinned by
`script/AVATransitionMatrix.s.sol` and checked row by row against kernel
execution in the test suite. The current artifact contains 330 enum-derived
cases and has hash
`0x9cba1aa4d1a8141ded47fb76ad2a2f2d96a4a83608a76bbf29e1bbe48e73dd97`.
It is for paper figures and future state/action extraction only; the Solidity
contracts remain the source of transition authority.

The test suite also includes a small boundary-claim surface with named
tests for paper-facing claims: administrative priority token execution cannot
touch manuscript records or publication selectors; raw review ids cannot
trigger standing, allocation, consequence, or settlement effects; disclosure
and ZK proof-use store context and nullifier receipts rather than reveal
payloads; direct high-impact recognised-state creation is rejected; and
forbidden publication, reveal, sanction, standing-token, and reputation-token
selectors remain absent.

`script/AVACanonicalTrace.s.sol` executes four canonical scenario traces and
returns JSON through `runTrace()`. The checked-in
`generated/canonical-scenario-traces.json` file is the current deterministic
output for model/paper handoff. It is a trace artifact, not a model,
simulator, sanction engine, or publication workflow.

`docs/translation-loss-audit.md` explains which research-framework concepts
are precisely encoded, approximated through bounded records, reserved for
human judgement, parameterised through modules, or excluded from the current
demo. It is the paper-facing guide for avoiding overclaiming when interpreting
the Solidity records.

## Canonical Source Layout

- `src/core/` owns application namespaces, canonical subjects, app-scoped
  authority, package identity, evidence/disclosure references, generic
  governed objects, recognised states, and the transition ledger.
- `src/extensions/` owns optional challenge, standing, credential, privacy,
  disclosure, audit, settlement, and external-operation records.
- `src/apps/peerreview/` owns peer-review vocabulary and relationship rules.

Core imports no application source. `test/helpers/SecondaryTestApp.sol` is a
test fixture for cross-application isolation, not a second shipped app. The
canonical manifest also imports the domain-neutral
`src/AVAApplicationRegistry.sol` and the shared `IAVAApplicationModule`,
`IRuleModuleIdentity`, and `IZKProofVerifier` interfaces from their current
root-level locations. Other root-level pre-separation contracts are retained
for regression and research-trace continuity, but they are not the recommended
integration surface for another application.

## Current Boundary

The demo implements AVA as:

- Attribution
- Verification
- Allocation

Recognised state is the governance object that these stages operate around. It
is not an additional stage.

The contracts do not implement:

- manuscript acceptance or rejection;
- manuscript merit scoring;
- scientific truth adjudication;
- identity or evidence reveal;
- production disclosure access control;
- sanction execution;
- production payment, stablecoin, or queue integration;
- standing or reputation tokens;
- public reputation prestige;
- publication priority.

## Implemented System

The current demo includes:

- immutable application namespaces and cross-application isolation;
- generic governed objects and a domain-neutral recognised-state kernel;
- parent-object checks that keep parent and child in one application and require
  compatible historical packages; the application module also receives the
  parent's workflow, package, object type, and responsible subject;
- a Peer Review application module plus a domain-neutral second-app test
  fixture;
- canonical role-scoped subjects;
- role/action authority checks;
- workflow rule packages with stable package identity;
- package registration that rejects missing or zero module behaviour identity;
- a package-bound `AVAWorkflowPolicyRouter` for verification, transition,
  evidence, disclosure, challenge, authority, field, and anti-abuse policy;
- evidence receipts with workflow, package, type, policy, and lifecycle
  references;
- state-derived records that require any selected evidence receipt to match the
  source state's application, workflow, package, subject, and disclosure
  policy, in addition to remaining active;
- disclosure policy records;
- manuscript references as off-chain pointers;
- review contribution records;
- recognised-state records with a responsible role-scoped subject;
- generic recognised-state transition ledger;
- target-version lineage through recognised-state `lastTransitionId`, filing
  transition snapshots, and before/after ids on challenge transitions;
- a reusable `AVAChallengeExtension` whose challenge object first becomes its
  own evidence-backed recognised state under an independently selected
  challenge package;
- challenge lifecycle and challenge-transition records that remain separate
  from the generic recognised-state transition ledger;
- immutable rule-package capability layout through `modulesHash`, an
  audit-oriented capability identity map through `modulesIdentityHash`, and
  full-package runtime revalidation through `modulesIdentityFingerprint`, plus
  explicit versioned supersession;
- explicit correction and restoration paths;
- bounded consequence, penalty, restoration, reward-value, administrative
  priority, and allocation records;
- standing update and standing computation records;
- append-only package/subject standing revision watermarks;
- package-scoped standing-revision writers whose writes revalidate both the
  package application and the subject application;
- non-transferable standing credential records;
- formula/source-set/computation statement records for privacy-preserving
  standing computation;
- ZK standing proof receipts and role-subject-linkable, commitment-bound
  standing credential proof carriers;
- disclosure proof-use and access/lifecycle receipts;
- value settlement and recovery receipts over authorised source records;
- external operation intent and terminal receipts;
- workflow-aware and target-bound audit receipts.

## Package Identity

Workflow keys are active pointers. Package ids are historical identities.

When a workflow package is superseded, new records use the new active package.
In the current ABI this is explicit: initial
registration rejects an existing workflow key, while `supersedeRulePackage`
names the expected current package and requires a higher version. Old
recognised states, challenges, evidence receipts, proof receipts, standing
records, settlement records, and downstream records keep the package identity
that was recorded when they were created.

This prevents new workflow modules from retroactively rewriting old governance
records.

The extension chain is:

```text
stable substrate -> interface family -> scenario module/adaptor -> package-bound record
```

The double-blind review, anonymous challenge, correction/restoration,
panel-visible audit, standing credential, disclosure proof-use, and bounded
settlement surfaces all use this pattern. They differ in module or adapter
selection, not in a rewrite of the recognised-state substrate.

A challenge may select a package independent of the target recognised state.
Challenge evidence, lifecycle, disclosure, and decision authority use the
challenge package. Any recognised-state mutation still uses the target state's
historical package and transition rule. The generic transition ledger stores
both package identities, and decision audit receipts follow the decision
package.
Decision hashes also bind the target recognised-state transition id. An upheld
challenge cannot correct a later state version, and restoration must follow the
same challenge's recorded correction or unchanged filing/resolution lineage.
The filing status also bounds the restoration target: `Challengeable` can only
return to `Challengeable`, while a target filed at `Vested` or `Restored` may
use the explicit `Restored` recovery status. Challenge filing caps bind both
the role-scoped subject and filing account, so subject rotation cannot reset an
open-target or target-version limit.

Challenger-side records use the challenge's own governance lineage. A
negligent or malicious/fabricated challenge finding, a challenge-transition
audit, and a challenge-target external-operation request bind the challenge
recognised state, challenge package, challenger subject, and challenge
evidence. Target-side upheld findings remain bound to the challenged
recognised state and the correction transition that currently defines it.
They may preserve the target's historical evidence and subject references
after a safety-reducing correction even when those references are inactive.
Challenger-side findings remain bound to active challenge evidence, and a
later unrelated target transition does not invalidate an immutable negligent
or malicious/fabricated challenger finding. Where a cross-workflow reference is needed, the target
package remains an explicit secondary field rather than replacing the record's
governing challenge package.
Pinned review, recognised-state, and challenge evidence is rechecked before
later governed transitions. On the canonical path, effectful transitions
require active receipts bound to the historical app/workflow/package, subject,
and disclosure policy; the evidence-lifecycle module validates lifecycle
changes. An upheld safety-reducing correction may retain an inactive target
evidence reference, but the challenge evidence and authorised decision lineage
must remain valid.
The retained pre-separation path also exposes action-scoped evidence-use
validation. Neither path evaluates evidence content or truth. Challenge
screening, resolution, restoration readiness, and restoration application fail
closed after challenge evidence becomes inactive, while authorised closeout
remains available.
The same historical-package and action-scoped lifecycle boundary covers
standing source sets, completeness attestations, computation statements, ZK
standing proof receipts, ordinary and ZK credential issuance, audit receipts,
and external-operation requests or acknowledgements. Module-identity drift
blocks new writes and makes existing standing proof surfaces fail closed. The
canonical standing ZK proof extension also pins its verifier runtime codehash
and proof-domain hash, so verifier drift blocks registration and invalidates
proof usability.
External-operation requests and acknowledgements also require the source
recognised-state transition to remain current. Cancellation and supersession
remain defensive closeout paths after later state transition, evidence
termination, or package-identity drift. When package identity remains valid,
those closeouts still pass application and anti-abuse policy; after identity
drift they retain substrate authority and immutable historical target,
subject, and evidence checks but cannot execute an external operation.
The value lifecycle applies the same distinction narrowly: reward freeze/void
and record-only setoff/waiver/satisfaction may close already-created records
after subject or evidence deactivation, while vest/restore, new settlement or
obligation creation, and clawback continue to require active references.

The current example modules also show governance memory as a later validation
input. An eligibility-restriction record can veto later challenge intake in a
selected workflow, and an active standing credential can gate a panel action
without becoming standing itself, a reward, or a publication signal.

## Privacy And Standing

Standing and reputation are computed governance memory, not assets.

The demo supports standing computation statements and credential proof carriers
so a subject can later prove a threshold, range, or category without exposing a
full history in every interaction. Canonical ZK standing credentials avoid an
owner/transfer surface and rely on role-scoped subject ids, subject commitments,
credential commitments, proof-use nullifiers, and source computation binding.
Because both subject id and commitment are recorded, this is role-subject-linkable
pseudonymity, not unlinkable anonymity.
Proof and credential-use contexts are deployment-domain bound: they include the
chain id, registry deployment, and verifier deployment. Credential-use contexts
also name a beneficiary, and copied calldata cannot consume that beneficiary's
nullifier from another caller. Ordinary and ZK credentials have a substrate
maximum validity period of 365 days; package policy can only narrow it.
ZK registries also pin verifier runtime codehash and proof domain, so direct
verifier drift disables active proof use while preserving historical receipts.
The ordinary standing credential proof API is also package-bound; its former
package-unbound selector is absent.

The contracts record proof receipts and proof-use events. They do not implement
production ZK circuits or reveal private identity.

Standing computations and credentials also bind the current package/subject
revision. Recognised-state transitions, challenge resolutions, standing and
eligibility records, and relevant reward/recovery settlements advance that
append-only watermark. A computation or credential from an earlier revision
cannot become an active proof again. An upheld challenge mutation advances the
target revision through its recognised-state transition exactly once; the
resolution layer does not repeat the same target update. For an anonymous
subject commitment, an
authorised panel can record an evidence-backed, historical-package-bound
commitment revision. The receipt advances freshness without linking an account,
computing standing, or issuing a credential.

Record-driven revision writers are authorised per package before the revision
surface is first used for that package. First use seals only that package's
writer set, so a later package can still initialise its own writers without
changing historical module identity. A writer authorised for one package cannot
advance a different package or another application's subject revision.

## Downstream Effects

Downstream records remain bounded and procedural.

Administrative priority artifacts are queue/service-right examples only. They
are not standing, reputation, scholarly credit, reviewer leniency, manuscript
advantage, or publication priority.

Penalty and recovery records are split by function: value recovery, standing
penalty input, eligibility restriction, and restoration are separate record
families. Good-faith failed challenges are not treated as misconduct.
`ConsequenceExecutor` binds a non-replaceable `ConsequenceBoundaryValidator`
for execution-shape, finding-subject, role, outcome, and eligibility
compatibility checks before package-selected adapters run.

Active mock recovery is source-bound to a completed token-transfer or
escrow-claim settlement, a compatible challenge-linked penalty, one repayment
obligation, and one terminal outcome. A new obligation also requires the linked
penalty evidence to remain active. Settlement state and standing revision are
written before any external mock-asset call, with transaction rollback and a
reentrancy guard preserving atomicity.

Challenge-window timing has a substrate floor: each deployment fixes a nonzero
minimum duration, and review recognition cannot vest earlier. The substrate
also permits only one open challenge for a given challenger subject and target,
and only one filing by that subject against the same target transition version.
Package-selected timing and rate-limit modules may impose stricter vetoes across
later target versions. The default anti-abuse module remains a permissive module
baseline; the example `SubjectRateLimitModule` is intentionally conservative:
for a selected package, it means one filing per challenger subject against the
same recognised state.
`RestrictionAwareChallengeIntakeModule` is another validator-only example: it
reads active, package-bound eligibility restrictions and rejects later
challenge filing by the restricted subject while the restriction is unexpired.

Standing credentials can also be used as validator inputs. The example
`CredentialGatedPanelModule` checks for an active, package-bound credential
over the acting panel subject, vector, category, and threshold before allowing
a configured panel action. It does not issue credentials, update standing,
execute penalties, reveal identity, or create publication effects.

Residual authority can also be receipt-backed. `AuthorityApprovalRegistry`
stores package/action/object-bound approval receipts, and
`ApprovalReceiptAuthorityModule` checks m-of-n active receipts plus optional
conflict exclusion without taking over state storage. A conflict-excluded
authority subject can neither screen, resolve, restore, or close the case nor
contribute to its approval threshold. Conflict checks compare both role-scoped
subject ids and their controlling accounts against the challenger and
responsible target subject. Recursive challenges may require one approval under
the challenge package and another under the target package; both remain bound
to the challenge evidence and exact decision hash. That hash binds the current
challenge lifecycle status, latest challenge-transition id, and target-state
transition id. Resolution, restoration, and close therefore require fresh,
independent approval under both packages before any transition or open-count
release. Pre-resolution close
approval remains available after challenge evidence becomes terminal as an
administrative deadlock escape, not a truth or misconduct decision.

Audit records persist an explicit target kind and attested action. The generic
entry can attest only its own evidence receipt id; recognised-state,
recognised-state-transition, and challenge-transition paths derive target and
package provenance from the referenced record. A recognised-state audit also
stores the state's current transition id, so the receipt identifies the
audited state version rather than only the state id. External-operation
cancellation and supersession remain available after pinned evidence becomes
terminal, while acknowledgement continues to require active evidence. Escrow
refund remains available after recipient-subject deactivation because it
returns an existing deposit to its original payer.

## Verification

Current verification:

- `forge build` passes.
- the default canonical `forge test` profile passes 250 tests;
- four canonical handler-based invariant suites pass at 512 runs by 128 calls
  for recursive challenge lineage/open counts, recovery uniqueness, standing
  stale-proof invalidation, and cross-application package/reference isolation;
- `FOUNDRY_PROFILE=retained forge test` passes 637 pre-separation regression
  tests;
- the canonical production runtime-size gate passes; `AVAGovernanceKernel` is
  21,976 bytes and `AVAChallengeExtension` is 21,753 bytes, and every contract
  in `src/canonical/AVAProductionSurface.sol` remains below EIP-170;
- focused namespace tests verify cross-application package, evidence, object,
  state, challenge, proof, and downstream-record isolation; the test-only
  secondary application is not exposed through a public script;
- the canonical trace runs with:

```bash
forge script script/AVACanonicalTrace.s.sol:AVACanonicalTrace --sig "runTrace()" --offline
```

The trace demonstrates review-object formation and vesting, a recursive
challenge with its own object/state/package, source-bound correction, bounded
downstream records, a record-only malicious/fabricated outcome, and explicit
restoration lineage. More advanced standing credential, ZK standing,
disclosure proof-use, settlement, and recovery surfaces are covered by tests
and documentation rather than compressed into the trace.

The older `AVADemoScenario` remains available only under the retained profile;
it is regression evidence, not the canonical architecture demonstration.

## Best Next Documents

- `architecture.md`: whole-system technical architecture.
- `interface-contract-spec.md`: interface-level obligations.
- `module-capability-matrix.md`: allowed and forbidden module behavior.
- `state-machines.md`: state and lifecycle paths.
- `record-reconstruction-guide.md`: how to reconstruct records from emitted
  ids, events, getters, and source records.
- `rule-package-integration-guide.md`: how to add a workflow package.
- `TERMINOLOGY.md`: public terminology boundary.
