# Current Implementation Summary

This document summarises the current implemented AVA Peer Review Solidity demo
for external readers. It is a public technical summary, not an internal
development log.

The repository is an early sample of the AVA protocol applied to peer-review
governance. It demonstrates how AVA-style governance can be expressed through
role-scoped subjects, evidence references, recognised states, authorised
transitions, rule packages, proof receipts, and bounded downstream records.

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
execution in the test suite. It is for paper figures and future state/action
extraction only; the Solidity contracts remain the source of transition
authority.

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

- canonical role-scoped subjects;
- role/action authority checks;
- workflow rule packages with stable package identity;
- evidence receipts with workflow, package, type, policy, and lifecycle
  references;
- disclosure policy records;
- manuscript references as off-chain pointers;
- review contribution records;
- recognised-state records with a responsible role-scoped subject;
- generic recognised-state transition ledger;
- challenge records and challenge transition ledger;
- explicit correction and restoration paths;
- bounded consequence, penalty, restoration, reward-value, administrative
  priority, and allocation records;
- standing update and standing computation records;
- non-transferable standing credential records;
- formula/source-set/computation statement records for privacy-preserving
  standing computation;
- ZK standing proof receipts and commitment-bound standing credential proof
  carriers;
- disclosure proof-use and access/lifecycle receipts;
- value settlement and recovery receipts over authorised source records;
- external operation intent and terminal receipts;
- workflow-aware and target-bound audit receipts.

## Package Identity

Workflow keys are active pointers. Package ids are historical identities.

When a workflow package is re-registered, new records use the new active
package. Old recognised states, challenges, evidence receipts, proof receipts,
standing records, settlement records, and downstream records keep the package
identity that was recorded when they were created.

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

The current example modules also show governance memory as a later validation
input. An eligibility-restriction record can veto later challenge intake in a
selected workflow, and an active standing credential can gate a panel action
without becoming standing itself, a reward, or a publication signal.

## Privacy And Standing

Standing and reputation are computed governance memory, not assets.

The demo supports standing computation statements and credential proof carriers
so a subject can later prove a threshold, range, or category without exposing a
full history in every interaction. Commitment-bound ZK standing credentials
avoid storing an owner account and rely on subject commitments, credential
commitments, proof-use nullifiers, and source computation binding.

The contracts record proof receipts and proof-use events. They do not implement
production ZK circuits or reveal private identity.

## Downstream Effects

Downstream records remain bounded and procedural.

Administrative priority artifacts are queue/service-right examples only. They
are not standing, reputation, scholarly credit, reviewer leniency, manuscript
advantage, or publication priority.

Penalty and recovery records are split by function: value recovery, standing
penalty input, eligibility restriction, and restoration are separate record
families. Good-faith failed challenges are not treated as misconduct.

Challenge-window timing and repeated challenge filing are package-selectable
veto surfaces. The default package remains a permissive baseline; timed or
rate-limited packages can reject early vesting or repeated challenge filing
without adding production scheduling or sanction execution. The example
`SubjectRateLimitModule` is intentionally conservative: for a selected package,
it means one filing per challenger subject against the same recognised state.
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
conflict exclusion without taking over state storage.

## Verification

Current verification:

- `forge build` passes.
- `forge test` passes with 263 tests.
- The baseline demo script runs locally with:

```bash
forge script script/AVADemoScenario.s.sol:AVADemoScenario --sig "run()" --offline
```

The script demonstrates the core manuscript, review, recognised-state,
challenge, consequence, standing update, allocation, and audit path. More
advanced standing credential, ZK standing, disclosure proof-use, settlement,
and recovery surfaces are covered by tests and documentation rather than
compressed into the baseline script.

## Best Next Documents

- `architecture.md`: whole-system technical architecture.
- `interface-contract-spec.md`: interface-level obligations.
- `module-capability-matrix.md`: allowed and forbidden module behavior.
- `state-machines.md`: state and lifecycle paths.
- `record-reconstruction-guide.md`: how to reconstruct records from emitted
  ids, events, getters, and source records.
- `rule-package-integration-guide.md`: how to add a workflow package.
- `TERMINOLOGY.md`: public terminology boundary.
