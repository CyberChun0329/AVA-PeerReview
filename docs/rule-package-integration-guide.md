# Rule Package Integration Guide

Status: current integration guide

Date: 2026-07-12

This guide explains how to add an application and its workflow rule packages to
the current Solidity demo without rewriting the recognised-state substrate. It
is for application authors, module authors, and reviewers who need a practical
integration checklist.

The guide describes the implemented contract surface. It does not authorise a
production release, model or simulation layer, publication logic, identity
reveal, evidence reveal, production ZK, production token/payment integration,
real queue execution, sanction execution, or deployment.

## 1. Canonical Integration Boundary

A canonical rule package is a capability-keyed set of validator modules and
optional extension policies registered under `(appId, workflowKey)` in
`AVACoreRulePackageRegistry`. Registration creates a stable `packageId`.

The same `workflowKey` may be used by different applications without collision.
Each application/workflow pair has its own active pointer. That pointer may
later advance to a newer package, but old records remain bound to the package
identity recorded at creation time. Package authors must treat the historical
`packageId` as immutable context.

Rule packages may validate or veto. They must not:

- grant authority;
- mutate substrate storage directly;
- bypass role-scoped subject binding;
- reinterpret substrate-owned ids;
- execute reward, payment, queue, sanction, reveal, or publication effects;
- decide scientific truth, manuscript merit, acceptance, rejection, or reviewer
  leniency.

The canonical ownership boundary is:

- `src/core/` owns application namespaces, role-scoped subjects, authority,
  package identity, evidence and disclosure-policy references, governed
  objects, recognised states, and the generic transition ledger;
- `src/extensions/` owns optional challenge, standing, credential, proof,
  disclosure, audit, settlement, and external-operation records;
- `src/apps/` owns application vocabulary and validator-only relationship
  rules.

`AVAGovernanceKernel` owns canonical recognised-state storage.
`AVAChallengeExtension` owns challenge storage and can request only the
restricted high-impact transitions exposed by the kernel. Core and reusable
extensions import no application vocabulary.
`AVAWorkflowPolicyRouter` is the stateless dispatch seam for formation,
transition, and challenge policy. It reads the record's fixed package and calls
the selected modules; it does not own records or mutation authority.

## 2. Canonical Application And Package Workflow

1. Register an application namespace.
   - Choose a stable, nonzero `appId` and application identity hash.
   - `AVAApplicationRegistry` is append-only; registration does not install
     roles, permissions, or workflow packages.
2. Define application vocabulary.
   - Keep role keys, action routing, object-type keys, and parent/child
     relationships in the application directory.
   - Implement `IAVAApplicationModule` as a validator-only module.
   - For governed objects with a parent, use the parent workflow, package,
     object type, and subject supplied in `GovernedObjectContext`. Core already
     requires the same application and a compatible package; the app module may
     narrow that relationship but must not assume a weaker parent check.
3. Assign app-scoped subjects and permissions.
   - Use `AVAIdentityRegistry` for canonical subjects scoped by
     `(account, appId, roleKey)`.
   - Use `AVAAuthorityMatrix` for `(appId, roleKey, actionKey)` permissions.
4. Choose a `workflowKey`.
   - Use a stable value for the governance workflow being represented.
   - Do not use `bytes32(0)`.
5. Build capability bindings.
   - Supply `ModuleBinding[]` entries keyed by `AVACapabilityKeys`.
   - Every binding must have a unique, nonzero capability key and a deployed
     module that implements `IRuleModuleIdentity`.
   - `moduleIdentityHash()` must be nonzero and must commit to all
     behaviour-affecting immutable configuration. A zero identity is rejected.
   - Every package must bind `APPLICATION` to an application module whose
     `applicationId()` equals the package `appId`.
   - Bind only the Core and optional extension capabilities the workflow uses;
     an absent optional capability fails closed when that extension is called.
     The canonical trace packages bind 12 capabilities used by those scenarios;
     broader standing and recovery invariant fixtures add their own extension
     capabilities instead of charging every workflow for the full catalogue.
6. Set package metadata.
   - Initial `version` must be `1`.
   - `compatibilityKey` must be nonzero.
   - `uri` may point to off-chain package metadata; it is not executable code.
7. Register the first package through
   `AVACoreRulePackageRegistry.registerRulePackage`.
   - The caller must hold the supplied active authority subject and have
     `ACTION_REGISTER_RULE_PACKAGE` permission in the same application.
   - The registry records a fresh `packageId`, immutable capability-layout
     `modulesHash`, per-capability `modulesIdentityHash`, unique-module
     `modulesIdentityFingerprint`, `appId`, `workflowKey`, version,
     compatibility key, authority subject, URI, and registrant.
   - If the workflow already exists, use `supersedeRulePackage` with the
     expected active package id, the same compatibility key, and exactly the
     next version. Initial registration is not an overwrite path.
8. Bind package-local transition infrastructure before first recognised-state
   use when the workflow needs it.
   - The kernel admin can bind one high-impact transition requester, transition
     guard, and post-transition hook per package before recognised-state use
     begins.
   - These bindings are package-specific, identity-pinned, and cannot be
     replaced after use begins.
9. Add tests before relying on the package.
   - Test package registration.
   - Test cross-application rejection for objects, evidence, subjects, packages,
     recognised states, and optional extension records.
   - Test historical package binding after superseding the same
     `(appId, workflowKey)`.
   - Test each custom module's rejection path.
   - Test that a permissive custom module cannot bypass substrate hard gates.
   - Test forbidden selector and terminology boundaries.

For a challenge workflow, repeat this process with its own `workflowKey` and
package. Register the challenge as a governed object, form its recognised
state, and then file the challenge lifecycle against the target recognised
state. Do not call `AVAChallengeExtension` with an ungoverned accusation or
reuse the target package merely for convenience. A later correction must pass
both the challenge decision package and the target state's historical package.

## 3. Canonical Capability Map

Canonical packages use capability keys rather than a fixed all-fields struct.
The current keys are:

| Capability family | Keys | Ownership |
| --- | --- | --- |
| Application and AVA stages | `APPLICATION`, `ATTRIBUTION`, `VERIFICATION`, `ALLOCATION` | Application vocabulary plus replaceable Attribution, Verification, and Allocation validators |
| Recognised-state support | `TRANSITION_RULE`, `EVIDENCE_POLICY`, `EVIDENCE_LIFECYCLE`, `DISCLOSURE_POLICY`, `CHALLENGE_POLICY`, `AUTHORITY_POLICY`, `FIELD_POLICY`, `ANTI_ABUSE` | Veto-only governance support; not additional AVA stages |
| Standing and bounded downstream records | `STANDING`, `STANDING_PROVENANCE`, `STANDING_COMPUTATION`, `STANDING_CREDENTIAL`, `STANDING_ZK_PROOF`, `STANDING_ZK_CREDENTIAL`, `ALLOCATION`, `CONSEQUENCE`, `REWARD`, `PRIORITY`, `PENALTY`, `RESTORATION`, `VALUE_EXECUTION` | Procedural memory, proof-carrier, bounded record, and record-only value lifecycle validation |
| Optional receipt surfaces | `PRIVACY_PROOF`, `DISCLOSURE_RECEIPT`, `AUDIT_RECEIPT`, `SETTLEMENT_RECEIPT`, `EXTERNAL_OPERATION`, `PACKAGE_LIFECYCLE`, `AUTHORITY_APPROVAL` | Context-bound receipts; no reveal, truth adjudication, real payment, or external execution |

The package registry pins both module addresses and each module's reported
identity. Historical reads recompute both aggregate hashes and fail closed if a
bound module's identity changes.
Canonical evidence registration, governed-object registration, shared extension
validation, downstream-record validation, and approval recording resolve their
required modules in one bounded batch. Each of those dispatch seams therefore
performs one aggregate identity revalidation per operation, without introducing
an unchecked package read or a cross-transaction cache.

## 4. Retained Pre-Separation RulePackageModules Map

The root-level `AVARulePackageRegistry` and its fixed `RulePackageModules`
struct remain in the repository for regression and research-trace continuity.
They are not the recommended integration surface for a new application. The
table below documents that retained surface.

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

## 5. Retained Registry Invariants

`AVARulePackageRegistry.registerRulePackage` currently enforces:

- caller has `Action.RegisterRulePackage` authority;
- `workflowKey` is nonzero;
- initial registration rejects an existing active workflow;
- all module and adapter fields are nonzero;
- module addresses have deployed code and expose a nonzero,
  re-verifiable `moduleIdentityHash()`;
- `version` is nonzero;
- `compatibilityKey` is nonzero;
- `deprecated` is false;
- package lifecycle module accepts the registration context;
- a fresh `packageId` is assigned;
- `activePackageIdByWorkflowKey[workflowKey]` points to the new package;
- the package stores `modulesHash`, `modulesIdentityHash`, `version`,
  `compatibilityKey`, `dependencyURI`, `uri`, `authorityId`, `registeredBy`,
  and active status.

Events expose both compatibility metadata and audit-visible bindings:

- `RulePackageRegistered`
- `RulePackageVersionRegistered`
- `RulePackageChallengeLifecycleBound`
- `RulePackageAuthorityBound`

`supersedeRulePackage` additionally requires the supplied current package id to
match the active pointer and the replacement version to be greater than the
current version. It emits `RulePackageSuperseded` and stores an append-only
supersession record. `getRulePackageById` recomputes `modulesIdentityHash` and
fails closed if a module's reported behaviour identity has changed.

## 6. Historical Package Binding

On the canonical path, an explicit supersession for the same
`(appId, workflowKey)` creates a new package and advances only that pair's
active pointer. It requires the expected current package id, the next sequential
version, and the same compatibility key. It does not rewrite old records or
cross into another application namespace.

Canonical records dispatch from their stored `packageId`. The application
module, evidence policy, transition rule, and optional extension policy are
therefore resolved from the historical package, not from the current active
pointer. Multi-application tests exercise this rule after package supersession
for application objects, recognised-state transitions, and standing proof
contexts.

The retained pre-separation registry follows the corresponding historical
binding rule described below.

An explicit supersession for the same `workflowKey` creates a new package and
updates the active package pointer. It must name the expected current package,
use a higher version, and write a supersession record. It does not rewrite old
records.

Package authors should expect old records to keep using their stored package
identity:

- recognised states dispatch through the package stored on the recognised
  state;
- challenge formation, lifecycle, disclosure, evidence, and decision authority
  dispatch through the challenge's package; any recognised-state mutation
  still dispatches through the target state's historical package and
  transition rule;
- evidence-backed paths reject cross-package evidence where the source and
  target packages do not match;
- downstream standing, allocation, consequence, reward, priority, penalty,
  restoration, and settlement-readiness paths use the target recognised state's
  package;
- ZK proof and standing credential contexts bind package identity and
  subject/commitment context.

If a workflow needs migration, supersession, or deprecation, record explicit
rule-package lifecycle readiness. Do not silently rewrite old state.

## 7. Required Tests For A New Package

Every new rule package should add or reuse tests covering:

1. Registration
   - authorised caller can register the package;
   - unauthorised caller is rejected;
   - zero module, no-code module, zero version, zero compatibility key, and
     deprecated package are rejected.
2. Application and historical binding
   - the same `workflowKey` can be used independently by two `appId` values;
   - cross-application object, evidence, subject, package, state, and extension
     references are rejected;
   - superseding the same `(appId, workflowKey)` does not change old recognised-state
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

### Reusable Compatibility Checks

The repository provides compatibility checks that do not add on-chain state or
runtime branches:

```bash
python3 -m unittest scripts/tests/test_ava_compatibility.py
python3 scripts/ava_compatibility.py abi --check
python3 scripts/ava_compatibility.py boundaries
forge script script/AVACanonicalPackageManifest.s.sol:AVACanonicalPackageManifest --sig "run()" --offline
python3 scripts/ava_compatibility.py package --manifest generated/canonical-rule-package-manifest.json
```

The ABI gate compares the canonical production surface with
`generated/canonical-abi-manifest.json`. An intentional ABI change therefore
requires explicit baseline regeneration and review. The import gate rejects
Core or reusable extension imports from `src/apps/`. The package checker
validates nonzero package identity, bounded and unique capabilities, declared
required capabilities, and explicit compatibility or supersession
relationships. `test/helpers/AVAApplicationConformance.sol` supplies reusable
assertions for verified package context, application-module identity,
historical state pinning, and fail-closed calls. The generated canonical
package manifest records a deterministic local run; it is not a production
deployment record.

## 8. Module Author Checklist

Before submitting a package:

- identify which fields are custom and which use defaults;
- state the package's `appId`, `workflowKey`, `version`, and
  `compatibilityKey`;
- state whether any scenario module is double-blind, anonymous challenge,
  panel-visible, voluntary real-name, field-specific, or anti-abuse-specific;
- list the substrate gates each custom module relies on instead of duplicating;
- include tests for custom reverts and permissive-module non-bypass;
- include a historical package-binding test when the module affects a path
  that later records `packageId`;
- implement `moduleIdentityHash()` through `RuleModuleIdentity` and include
  every behaviour-affecting configuration value; do not use an upgradeable
  proxy whose implementation can change behind a stable package identity;
- avoid storage mutation inside validator modules;
- avoid selectors or terminology that imply publication, truth adjudication,
  reveal, sanction execution, or standing/reputation asset behavior.

## 9. External Reader Checklist

To reconstruct which package governed a record:

- start from the record's own `packageId` when present;
- otherwise follow the target recognised state, challenge target, evidence
  receipt, settlement source, or proof context identified by that record;
- use `AVACoreRulePackageRegistry.getRulePackageById(packageId)` for canonical
  historical package metadata;
- use `getActivePackageId(appId, workflowKey)` only for new canonical workflow
  actions, not for interpreting old records;
- for canonical packages, compare `modulesHash`, `modulesIdentityHash`, and
  `modulesIdentityFingerprint` when auditing package identity; retained
  pre-separation packages expose the first two commitments;
- treat lifecycle readiness records as explicit metadata records, not migration
  execution.

## 10. What Not To Implement In A Rule Package

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
