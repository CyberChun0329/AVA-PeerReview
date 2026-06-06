# Rule Package Compatibility And Migration Policy

Status: current implementation policy

Date: 2026-06-06

This policy explains how the current AVA-PeerReview Solidity demo treats rule
package replacement, compatibility metadata, supersession readiness, and
migration readiness.

It is a current implementation policy, not approval to implement automatic
migration, state rewrite, model, simulation, publication logic, reveal/decrypt,
payment, sanction execution, queue execution, production ZK, ACL, or production
deployment.

## 1. Core Rule

`workflowKey` is an active pointer. `packageId` is historical identity.

- `workflowKey` selects the current package for new workflow actions.
- `registerRulePackage` always creates a fresh `packageId`.
- Re-registering the same `workflowKey` updates the active package pointer.
- Old recognised states, challenges, evidence receipts, downstream records,
  proof receipts, credentials, settlement receipts, and audit records must be
  interpreted through their stored `packageId` or through the package-bound
  source record they reference.
- A new active package cannot retroactively change old records.

## 2. Compatibility Metadata

Each package stores:

- `modulesHash`
- `modulesCodeHash`
- `version`
- `compatibilityKey`
- `dependencyURI`
- `deprecated`
- `authorityId`
- `registeredBy`

`modulesHash` represents module address/configuration data plus module-code
identity. `modulesCodeHash` is the aggregate code-identity hash. The registry
rechecks stored module-code identity when `getRulePackageById(packageId)` is
called.

`compatibilityKey` is a policy label. It does not execute migration, grant
authority, or override substrate gates.

`version` is package metadata. It can be used by a lifecycle module to reject
incompatible packages, but it does not rewrite old package-bound records.

`dependencyURI` is off-chain metadata. It is not code execution.

`deprecated` cannot be true at package registration in the current registry.
Any future deprecation policy must be an explicit lifecycle record or a future
approved change, not silent mutation of old records.

## 3. Lifecycle Readiness Records

`AVARulePackageRegistry` supports two lifecycle entrypoints:

- `recordRulePackageLifecycle`
- `recordRulePackageLifecycleForPackage`

Both write `RulePackageLifecycleRecord`. They do not perform migration.

The record stores:

- source `workflowKey`
- source `packageId`
- lifecycle kind
- source `modulesHash`
- source `modulesCodeHash`
- source `version`
- source `compatibilityKey`
- target `workflowKey` and `targetPackageId` when required
- target module hashes, version, and compatibility key when required
- dependency URI, reason URI, authority role/id, and recorder

`SupersessionReady` and `MigrationReady` require an explicit target package.
The target package cannot be zero and cannot be the same package.

Lifecycle module validation is a veto-only compatibility check. It does not
change active package pointers, move records, mutate recognised states, or
rewrite downstream history.

## 4. Package Replacement Policy

When a workflow package is replaced:

1. Register the new package under the same `workflowKey`.
2. New records use the new active `packageId`.
3. Old records keep their original `packageId`.
4. If compatibility or migration readiness needs to be recorded, write an
   explicit lifecycle readiness record.
5. External readers must inspect the record's stored `packageId`, not the
   current active package pointer, when interpreting old records.

This policy intentionally keeps replacement and migration separate.

## 5. What A Future Migration Would Need

The current demo does not implement migration execution. A future approved
migration path would need separate design and tests for:

- source package id;
- target package id;
- target record id and kind;
- authority subject;
- evidence receipt;
- reason URI;
- transition or lifecycle ledger record;
- one-way or reversible status;
- explicit no-publication, no-truth, no-reveal, and no-sanction-execution
  boundaries.

It must not be implemented as a side effect of package registration or
lifecycle readiness.

## 6. Current Test Evidence

Current tests already cover the policy shape:

- package re-registration does not rewrite existing recognised-state dispatch;
- double-blind review, anonymous challenge, and restoration scenarios use the
  historical package bound to their source records;
- package lifecycle readiness records bind explicit source and target packages;
- lifecycle readiness rejects invalid targets and does not execute migration;
- lifecycle validation sees module hashes and blocks incompatible packages;
- disclosure execution uses the target object's historical package after
  workflow reconfiguration;
- legacy disclosure configuration cannot override the rule-package module;
- anonymous challenge proof-use rejects a proof from the wrong package;
- package-bound evidence cannot cross recognised-state, challenge, allocation,
  or consequence contexts after workflow re-registration.

This document is a public policy summary for those tested behaviors. It does
not add Solidity, ABI, storage, or test changes.
