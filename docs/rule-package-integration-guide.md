# Rule Package Integration Guide

Status: current integration guide

Date: 2026-06-06

This guide explains how to add a new AVA workflow rule package to the current
Solidity demo without rewriting the recognised-state substrate. It is for
module authors and reviewers who need a practical integration checklist.

The guide describes the implemented contract surface. It does not authorise a
production release, model or simulation layer, publication logic, identity
reveal, evidence reveal, production ZK, production token/payment integration,
real queue execution, sanction execution, or deployment.

## 1. Integration Boundary

A rule package is a set of validator modules and downstream adapters registered
under one `workflowKey`. Registration creates a new stable `packageId`.

The active `workflowKey` may later point to a newer package, but old records
remain bound to the package identity recorded at creation time. Future package
authors must treat that historical `packageId` as immutable context.

Rule packages may validate or veto. They must not:

- grant authority;
- mutate substrate storage directly;
- bypass role-scoped subject binding;
- reinterpret substrate-owned ids;
- execute reward, payment, queue, sanction, reveal, or publication effects;
- decide scientific truth, manuscript merit, acceptance, rejection, or reviewer
  leniency.

The substrate remains the owner of authority, subject identity, evidence
receipt storage, recognised-state storage, transition ledgers, challenge
records, downstream records, proof receipts, settlement receipts, and external
operation receipts.

## 2. Minimal Package Author Workflow

1. Choose a `workflowKey`.
   - Use a stable value for the governance workflow being represented.
   - Do not use `bytes32(0)`.
2. Choose module and adapter contracts.
   - Every `RulePackageModules` field must be nonzero.
   - Every module address must have deployed code.
   - Use default modules for seams your package does not customize.
3. Set package metadata.
   - `version` must be nonzero.
   - `compatibilityKey` must be nonzero.
   - `dependencyURI` should point to off-chain package metadata.
   - `deprecated` must be false at registration.
4. Register the package through `AVARulePackageRegistry.registerRulePackage`.
   - Caller must have `RegisterRulePackage` authority.
   - The registry records a fresh `packageId`, `modulesHash`,
     `modulesCodeHash`, version, compatibility key, authority subject, URI,
     and registrant.
5. Add tests before relying on the package.
   - Test package registration.
   - Test historical package binding after re-registering the same
     `workflowKey`.
   - Test each custom module's rejection path.
   - Test that a permissive custom module cannot bypass substrate hard gates.
   - Test forbidden selector and terminology boundaries.

## 3. RulePackageModules Field Map

The technical framework separates module fields into three layers. Only Layer A
maps directly to AVA's three macro stages.

### Layer A: AVA Core Stage Interfaces

| Field | Interface | Meaning |
| --- | --- | --- |
| `attributionModule` | `IAttributionModule` | Attribution-stage object/subject validation. |
| `verificationModule` | `IVerificationModule` | Verification-stage reference validation. It is not scientific truth. |
| `allocationModule` | `IAVAAllocationModule` | Allocation-stage bounded allocation validation. It is not payment or publication priority. |

### Layer B: Recognised-State Governance Support

These fields support recognised-state governance. They are not new AVA stages.

| Field | Interface | Meaning |
| --- | --- | --- |
| `transitionRuleModule` | `ITransitionRuleModule` | Validates admissible status transitions; substrate writes transition records. |
| `disclosureModule` | `IDisclosurePolicyModule` | Validates disclosure-policy compatibility; no reveal, decrypt, or ACL engine. |
| `challengeLifecycleModule` | `IChallengeLifecycleModule` | Validates challenge filing, screening, resolution, restoration, and closure sequencing. |
| `evidencePolicyModule` | `IEvidencePolicyModule` | Validates evidence workflow/type/reference compatibility; no truth validation. |
| `auditAdapter` | `IAuditAdapter` | Validates attestation reference and hash shape; audit storage remains substrate-owned. |
| `editorialSystemAdapter` | `IEditorialSystemAdapter` | Optional metadata-reference bridge for manuscript pointers; not editorial decision logic. |
| `residualEditorialAuthorityModule` | `IResidualEditorialAuthorityModule` | Validates procedural residual authority; cannot decide acceptance, rejection, or merit. |
| `fieldPolicyModule` | `IFieldPolicyModule` | Validates field/discipline admissibility; cannot replace authority/evidence/status gates. |
| `antiAbuseModule` | `IAntiAbuseModule` | Veto-only abuse/rate-limit checks; no sanction execution. |
| `evidenceLifecycleModule` | `IEvidenceLifecycleModule` | Validates evidence status use and lifecycle hooks; no delete/reveal/truth judgment. |
| `disclosureLifecycleModule` | `IDisclosureLifecycleModule` | Validates disclosure-readiness records; no reveal, decrypt, ACL, or identity disclosure. |
| `disclosureExecutionModule` | `IDisclosureExecutionModule` | Validates access/proof-use/intent receipt context; execution storage remains substrate-owned. |

### Layer C: Downstream Consequence / Execution / Proof Support

These fields live at or after the Allocation edge. They are not AVA core
stages.

| Field | Interface | Meaning |
| --- | --- | --- |
| `standingAdapter` | `IStandingAdapter` | Validates procedural standing update records; standing is governance memory, not an asset. |
| `consequenceAdapter` | `IConsequenceAdapter` | Validates bounded administrative/procedural consequence records. |
| `rewardAdapter` | `IRewardAdapter` | Validates reward-value records only; no transfer or publication effect. |
| `priorityAdapter` | `IPriorityAdapter` | Validates administrative queue/service-right records only. |
| `penaltyAdapter` | `IPenaltyAdapter` | Validates penalty records; separates value recovery, standing input, and eligibility restriction. |
| `restorationAdapter` | `IRestorationAdapter` | Validates repair/restoration records; no silent overwrite or reward mint. |
| `valueExecutionAdapter` | `IValueExecutionAdapter` | Validates settlement-readiness metadata before separate source-bound settlement receipts. |
| `standingComputationModule` | `IStandingComputationModule` | Validates standing-computation readiness; no history traversal or public prestige score. |
| `rulePackageLifecycleModule` | `IRulePackageLifecycleModule` | Validates package registration and lifecycle readiness; no migration executor. |

## 4. Registration Invariants

`AVARulePackageRegistry.registerRulePackage` currently enforces:

- caller has `Action.RegisterRulePackage` authority;
- `workflowKey` is nonzero;
- all module and adapter fields are nonzero;
- module addresses have deployed code through `modulesCodeHash` checks;
- `version` is nonzero;
- `compatibilityKey` is nonzero;
- `deprecated` is false;
- package lifecycle module accepts the registration context;
- a fresh `packageId` is assigned;
- `activePackageIdByWorkflowKey[workflowKey]` points to the new package;
- the package stores `modulesHash`, `modulesCodeHash`, `version`,
  `compatibilityKey`, `dependencyURI`, `uri`, `authorityId`, `registeredBy`,
  and active status.

Events expose both compatibility metadata and audit-visible bindings:

- `RulePackageRegistered`
- `RulePackageVersionRegistered`
- `RulePackageChallengeLifecycleBound`
- `RulePackageAuthorityBound`

## 5. Historical Package Binding

A new registration for the same `workflowKey` creates a new package and updates
the active package pointer. It must not rewrite old records.

Package authors should expect old records to keep using their stored package
identity:

- recognised states dispatch through the package stored on the recognised
  state;
- challenge lifecycle paths dispatch from the challenged recognised state's
  package where the target owns the workflow context;
- evidence-backed paths reject cross-package evidence where the source and
  target packages do not match;
- downstream standing, allocation, consequence, reward, priority, penalty,
  restoration, and settlement-readiness paths use the target recognised state's
  package;
- ZK proof and standing credential contexts bind package identity and
  subject/commitment context.

If a workflow needs migration, supersession, or deprecation, record explicit
rule-package lifecycle readiness. Do not silently rewrite old state.

## 6. Required Tests For A New Package

Every new rule package should add or reuse tests covering:

1. Registration
   - authorised caller can register the package;
   - unauthorised caller is rejected;
   - zero module, no-code module, zero version, zero compatibility key, and
     deprecated package are rejected.
2. Historical binding
   - re-registering the same `workflowKey` does not change old recognised-state
     dispatch;
   - old challenge, evidence, proof, downstream, and settlement paths keep the
     historical package where applicable.
3. Module rejection
   - each custom module can veto the intended action;
   - a veto fails closed before storage mutation.
4. Permissive module hard-gate failure
   - a module that accepts everything still cannot bypass authority, subject,
     evidence, target-context, package, nullifier, settlement-source, or status
     gates.
5. Boundary scan
   - no manuscript acceptance/rejection/merit selector;
   - no truth engine;
   - no identity or evidence reveal/decrypt selector;
   - no sanction execution selector;
   - no standing/reputation asset, credit, balance, or consumable-right
     semantics.

## 7. Module Author Checklist

Before submitting a package:

- identify which fields are custom and which use defaults;
- state the package's `workflowKey`, `version`, and `compatibilityKey`;
- state whether any scenario module is double-blind, anonymous challenge,
  panel-visible, voluntary real-name, field-specific, or anti-abuse-specific;
- list the substrate gates each custom module relies on instead of duplicating;
- include tests for custom reverts and permissive-module non-bypass;
- include a historical package-binding test when the module affects a path
  that later records `packageId`;
- avoid storage mutation inside validator modules;
- avoid selectors or terminology that imply publication, truth adjudication,
  reveal, sanction execution, or standing/reputation asset behavior.

## 8. External Reader Checklist

To reconstruct which package governed a record:

- start from the record's own `packageId` when present;
- otherwise follow the target recognised state, challenge target, evidence
  receipt, settlement source, or proof context identified by that record;
- use `getRulePackageById(packageId)` for historical package metadata;
- use `getActivePackageId(workflowKey)` only for new workflow actions, not for
  interpreting old records;
- compare `modulesHash` and `modulesCodeHash` when auditing package identity;
- treat lifecycle readiness records as explicit metadata records, not migration
  execution.

## 9. What Not To Implement In A Rule Package

Do not implement:

- manuscript acceptance or rejection;
- manuscript merit scoring or acceptance probability;
- scientific truth engine;
- identity reveal or evidence reveal/decryption;
- production disclosure ACL;
- sanction execution;
- standing/reputation tokenisation, transfer, consumption, balance, or asset
  behavior;
- real payment or production stablecoin settlement;
- real queue execution or external platform operation.

If a future workflow appears to need one of these capabilities, it is outside
ordinary rule-package integration and needs a separate design approval.
