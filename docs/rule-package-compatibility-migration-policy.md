# Rule Package Compatibility And Migration Policy

This guide explains how to select the active package for new registrations and
how to interpret records created under an earlier package. A migration-readiness
receipt records an assessment. Moving an existing record would require a
separate mechanism.

## 1. Core Rule

On the canonical path, `(appId, workflowKey)` identifies an active pointer.
`packageId` is historical identity.

- `(appId, workflowKey)` selects the package for new object and evidence registrations.
  The same workflow key may be active independently in different applications.
- `registerRulePackage` creates the initial package and rejects an existing
  application/workflow pair.
- `supersedeRulePackage` creates a fresh `packageId`, requires the caller to
  name the current active package, requires exactly the next version and the
  same compatibility key, emits an append-only supersession event, and then
  advances that application's pointer.
- Supersession remains a trusted governance action by the authorised package
  registrar, who must name the expected active package.
  `AVACoreRulePackageRegistry` checks that ID against the active pointer.
  Approval from a module in the old package is outside the current procedure.
- Old recognised states, challenges, evidence receipts, downstream records,
  proof receipts, credentials, settlement receipts, and audit records must be
  interpreted through their stored `packageId` or through the package-bound
  source record they reference.
- A challenge recognised state formed before supersession completes filing
  through its stored historical `packageId`; filing does not silently switch
  to the workflow's newer active package.
- A new active package cannot retroactively change old records.

## 2. Compatibility Metadata

Each canonical package stores:

- `appId`
- `workflowKey`
- `modulesHash`
- `modulesIdentityHash`
- `modulesIdentityFingerprint`
- `version`
- `compatibilityKey`
- `uri`
- `authorityId`
- `registeredBy`
- `active`

`modulesHash` binds the ordered capability keys and module addresses.
`modulesIdentityHash` binds the ordered capability keys and each module's
`moduleIdentityHash()` at registration. On verified reads, the registry
recomputes `modulesIdentityFingerprint` from the distinct bound modules and
checks it against the stored value.

If a bound module reports a different identity, verified package reads revert.
Existing records keep their package IDs. Affected verified reads remain
unavailable while the mismatch persists.

This mechanism assumes modules honestly expose every behaviour-affecting
configuration. The current package model therefore does not support proxy
modules whose implementation can change behind a stable proxy identity.

`compatibilityKey` is an application-local policy label. Canonical
supersession requires it to remain unchanged. It does not execute migration,
grant authority, or override substrate gates.

`version` is package metadata. Initial registration requires version `1`, and
canonical supersession requires exactly `previous.version + 1`. It does not
rewrite old package-bound records.

`uri` is off-chain metadata. It is not code execution.

## 3. Retained Lifecycle Readiness Records

The root-level pre-separation `AVARulePackageRegistry` supports two
package-lifecycle entrypoints:

- `recordRulePackageLifecycle`
- `recordRulePackageLifecycleForPackage`

Both write `RulePackageLifecycleRecord`. They do not perform migration. These
records remain available for regression and research-trace continuity, but
they are not part of the canonical `src/core/` application integration path.

The record stores:

- source `workflowKey`
- source `packageId`
- lifecycle kind
- source `modulesHash`
- source `modulesIdentityHash`
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

`recordObjectMigrationReadiness` can then bind a specific object to an existing
`MigrationReady` lifecycle record. It stores source package, target package,
object id, optional recognised-state id, evidence receipt, boundary hash,
authority, and reason URI. It is a readiness receipt only: it does not migrate
the object, create a replacement object, or mutate any recognised state.

## 4. Package Replacement Policy

When a canonical workflow package is replaced:

1. Call `AVACoreRulePackageRegistry.supersedeRulePackage` with the same
   `(appId, workflowKey)`, the expected current package id, exactly the next
   version, the same compatibility key, and replacement capability bindings.
2. New records use the new active `packageId`.
3. Old records keep their original `packageId`.
4. External readers must inspect the record's stored `packageId`, not the
   current active package pointer, when interpreting old records.
5. Do not infer cross-application compatibility from a matching workflow or
   compatibility key. Canonical references must retain the same `appId`.

This policy intentionally keeps replacement and migration separate. The
canonical Core currently implements replacement, historical reads, and
application isolation; it does not implement migration readiness or migration
execution. The retained root-level readiness records do not migrate canonical
objects.

## 5. What A Future Migration Would Need

The current demo does not implement canonical migration execution. A future approved
migration execution path would need separate design and tests for:

- source package id;
- target package id;
- target record id and kind, or an explicitly stored object readiness record;
- authority subject;
- evidence receipt;
- reason URI;
- transition or lifecycle ledger record;
- one-way or reversible status;
- explicit no-publication, no-truth, no-reveal, and no-sanction-execution
  boundaries.

It must not be implemented as a side effect of package registration or
lifecycle readiness. The current object migration readiness record closes the
auditability gap for object/source/target binding, but remains record-only.

## 6. Current Test Evidence

Current tests cover both the canonical replacement rule and retained
pre-separation readiness behavior:

- two applications can use the same workflow key without sharing an active
  pointer;
- cross-application objects, evidence, subjects, recognised states, challenges,
  and downstream records are rejected;
- canonical package supersession does not rewrite existing recognised-state,
  credential, or proof dispatch;
- old Peer Review and test-only secondary-application states continue to use
  their historical application module and package after active-pointer
  replacement;
- initial registration cannot overwrite an existing workflow, and explicit
  supersession is versioned and append-only;
- a changed module behaviour identity makes historical package reads fail
  closed;
- double-blind review, anonymous challenge, and restoration scenarios use the
  historical package bound to their source records;
- package lifecycle readiness records bind explicit source and target packages;
- object migration readiness records bind an object, source package, target
  package, evidence receipt, authority subject, and boundary hash without
  executing migration;
- lifecycle readiness rejects invalid targets and does not execute migration;
- lifecycle validation sees module hashes and blocks incompatible packages;
- disclosure execution uses the target object's historical package after
  workflow reconfiguration;
- legacy disclosure configuration cannot override the rule-package module;
- anonymous challenge proof-use rejects a proof from the wrong package;
- package-bound evidence cannot cross recognised-state, challenge, allocation,
  or consequence contexts after workflow supersession.

This document is a public policy summary for those tested behaviors. It does
not add Solidity, ABI, storage, or test changes.
