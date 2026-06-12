# Translation-Loss Audit

Status: current paper/model handoff aid

Date: 2026-06-12

This document explains what the current AVA Peer Review Solidity demo encodes
directly, what it represents through bounded records, and what it deliberately
leaves outside the contracts.

The purpose is not to turn the demo into a model, simulation, truth engine, or
production peer-review platform. The purpose is to make translation loss
visible: when a research-framework idea moves into Solidity, the reader should
be able to see which part became an executable record and which part remains an
off-chain judgement, policy choice, or later modelling variable.

## Reader Rule

Use implemented records before inventing analytical variables.

If a paper figure, model state, game action, payoff proxy, or institutional
condition cannot be traced to an implemented record, getter, event, context
hash, proof receipt, URI, or explicit off-chain abstraction, it is outside the
current demo.

The core implementation remains:

```text
Attribution -> Verification -> Allocation
```

Recognised state is the governed object around those stages. It is not a
fourth AVA stage.

## Translation Categories

| Category | Meaning in this demo | Current implementation evidence | Boundary |
| --- | --- | --- | --- |
| Precisely encoded | The contract stores the relevant governance fact as a typed record, transition, status, id, enum, event, or getter. | Role-scoped subjects in `RoleIdentityRegistry`; package identity in `AVARulePackageRegistry`; evidence receipts in `EvidenceCommitmentRegistry`; recognised states and transitions in `AVAStateMachine`; challenge transitions and outcomes in `AVAStateMachine`; standing, allocation, consequence, proof-use, settlement, recovery, and credential records in their dedicated registries. | These facts are executable substrate facts, not scientific truth or editorial merit. |
| Approximated | The contract stores a commitment, hash, URI, type hash, formula hash, policy hash, source-set commitment, or proof receipt rather than the underlying full content. | Evidence `commitment`, `uri`, `evidenceTypeHash`, and `disclosurePolicyId`; standing computation `formulaHash`, `sourceSetCommitmentId`, and output hashes; ZK proof receipts and proof-use nullifiers; canonical trace JSON; transition matrix CSV. | Solidity checks existence, binding, package identity, subject context, and replay rules where implemented; it does not inspect evidence content or verify scientific quality. |
| Human-reserved | The framework concept is intentionally not decided by the smart contracts. | Forbidden-selector tests and boundary docs assert absence of manuscript acceptance, rejection, merit scoring, publication priority, truth adjudication, reveal/decrypt, and sanction execution. | These remain institutional, editorial, legal, scientific, or future model-layer matters. |
| Parameterised | The substrate exposes an interface or module slot so a workflow package can choose a rule without rewriting the core recognised-state storage. | Rule-package modules for attribution, verification, allocation, transition rules, challenge lifecycle, disclosure policy/lifecycle/execution, evidence policy/lifecycle, audit, field policy, anti-abuse, residual authority, standing, reward, priority, penalty, restoration, value execution, external operation, and ZK verification. | Modules validate or route bounded records. They must not bypass non-delegable substrate gates, mutate historical records, reveal identity, decide truth, or add publication logic. |
| Excluded | The concept is deliberately out of scope for this demo. | No production disclosure reveal/decryption, production ACL, real sanction execution, live payment/queue integration, production bridge, manuscript decision engine, model, simulation, or deployment workflow. | A later project may integrate these as external systems or adapters, but the current demo records only bounded receipts and intents. |
| New governance object | The Solidity demo introduces a record object that helps translate institutional rules into executable grammar. | Recognised state; recognised-state transition; challenge transition; evidence lifecycle record; disclosure lifecycle/execution record; standing computation statement; standing credential; anonymous proof-use receipt; settlement receipt; recovery receipt; external-operation receipt; migration readiness record. | These objects are paper-facing trace anchors. They are not claims that peer review has been automated. |

## Precisely Encoded Surface

The following concepts are encoded as typed substrate facts:

- Role-scoped subject identity:
  `RoleIdentityRegistry` binds each active account/role pair to one canonical
  subject. Contracts use `subjectId` rather than treating an account as the
  research identity.
- Authority:
  `AuthorityMatrix` remains the non-delegable role/action/subject gate.
  Residual authority modules can validate additional policy conditions, but
  they do not own state storage or mutate records.
- Package identity:
  `AVARulePackageRegistry` gives each workflow package a stable `packageId`,
  `modulesHash`, version, compatibility key, and module bundle. Historical
  records bind to package identity rather than being reinterpreted through the
  latest active workflow pointer.
- Evidence reference:
  `EvidenceCommitmentRegistry` stores package-bound evidence receipts and
  lifecycle records. Downstream records validate receipt existence and package
  compatibility where the target record requires evidence.
- Recognised state:
  `AVAStateMachine` stores the object, AVA stage, responsible subject,
  evidence, disclosure policy, authority, package id, and recognised-state
  status. Higher-impact statuses arise through authorised transition paths.
- Challenge/correction/restoration:
  Challenges target recognised states. Lifecycle status and outcome are
  separated. Resolution and restoration write transition records and preserve
  history.
- Standing, allocation, consequence, settlement, recovery, credential, and
  proof-use records:
  Each downstream family has its own record layer and package-bound context.
  These layers do not merge standing into rewards, priority rights, penalties,
  or settlement.

## Approximated Surface

The demo uses bounded references where the underlying fact is too large,
confidential, probabilistic, or human-governed for direct on-chain evaluation.

Examples:

- Evidence content is represented by commitments, URIs, type hashes, and
  disclosure-policy references.
- Standing computation is represented by authorised computation statements,
  formula hashes, source-set commitments, output hashes, vector keys, category
  hashes, thresholds, and credential records.
- ZK and anonymous disclosure paths store proof receipts, context hashes,
  verifier/domain bindings, and nullifiers.
- Canonical trace export stores paper-facing record names and ids, not a
  strategy model or payoff calculation.

This is intentional. The contracts check record existence, authority, subject
binding, package binding, type/policy compatibility, and replay boundaries
where implemented. They do not decide whether a paper is true, important,
publishable, or scientifically meritorious.

## Human-Reserved Surface

The following remain outside the contracts:

- manuscript acceptance or rejection;
- manuscript merit or quality scoring;
- scientific truth adjudication;
- editorial legitimacy;
- real-world identity reveal;
- evidence decryption;
- production disclosure access control;
- sanction execution;
- production payment or queue execution;
- statistical or game-theoretic model estimation.

When the demo records an upheld challenge, an adverse consequence record, a
standing penalty input, or a recovery receipt, it records the authorised
governance object. It does not execute punishment or declare scientific truth.

## Parameterised Surface

Workflow-specific judgement is deliberately parameterised behind modules and
adapters. Current rule packages can bind different implementations for:

- attribution validation;
- verification validation;
- allocation validation or routing;
- transition admissibility;
- challenge lifecycle;
- disclosure policy, lifecycle, and proof-use;
- evidence policy and lifecycle;
- audit adapters;
- field policy;
- anti-abuse and rate limits;
- residual authority;
- standing computation and credential issuance;
- reward, priority, consequence, penalty, restoration, value execution, and
  external-operation adapters;
- ZK proof verification.

The module boundary is not permission to override the substrate. Core storage,
package identity, recognised-state status transitions, subject binding,
evidence existence, authority checks, and no-publication/no-truth/no-reveal
boundaries remain substrate-level constraints.

## Excluded Surface

The demo intentionally does not implement:

- real identity reveal or evidence decryption;
- production ZK circuits or production disclosure ACL;
- real payment, escrow, bridge, or queue-service integration;
- sanction execution;
- manuscript decision logic;
- a publication-priority mechanism;
- a standing or reputation token;
- a model, simulation, or payoff estimator.

Administrative priority artifacts are separate bounded allocation artifacts.
They are not standing, reputation, manuscript merit, or publication priority.

Standing and reputation remain governance memory. They are not tokens, credits,
balances, rewards, public prestige, priority rights, or tradeable assets.

## Model And Paper Use

For future model extraction, use the current implementation as a record map:

- State variables should come from recognised-state status, challenge status,
  evidence lifecycle status, disclosure lifecycle/execution status,
  credential status, settlement status, recovery status, and external-operation
  status.
- Actions should come from authorised calls with acting role, subject,
  authority, action enum, package id, and target object.
- Transitions should come from recognised-state transition records, challenge
  transition records, lifecycle records, settlement records, recovery records,
  and explicit readiness records.
- Information conditions should come from evidence receipts, proof receipts,
  disclosure policies, subject commitments, nullifiers, and context hashes.
- Payoff proxies, if used later, should be explicitly labelled as model-layer
  abstractions over standing updates, credentials, allocation records,
  consequence records, priority artifacts, recovery receipts, or settlement
  receipts. The contracts themselves do not calculate payoffs.

The generated transition matrix and canonical scenario traces are therefore
handoff aids:

- `generated/recognised-state-transition-matrix.csv`
- `generated/canonical-scenario-traces.json`

They help a paper or future model enumerate implemented states and actions.
They are not separate sources of governance authority.
