# Integration Handoff Pack

Status: current integration handoff

Date: 2026-06-06

This pack is the practical entrypoint for another developer, reviewer, or paper
assistant who needs to understand the implemented AVA-PeerReview Solidity demo
from the public technical documents.

It does not introduce a new module, workflow, model, simulation, publication
layer, production privacy system, payment system, sanction system, or
deployment plan.

## Read Order

Read these current documents first:

1. `public-technical-overview.md`
   - public purpose, AVA boundary, and paper-facing project orientation;
2. `current-implementation-summary.md`
   - implemented contract map, flow, boundaries, and verification status;
3. `architecture.md`
   - main technical narrative and module taxonomy;
4. `interface-contract-spec.md`
   - interface semantics and module obligations;
5. `module-capability-matrix.md`
   - allowed, forbidden, and fail-closed behavior by module family;
6. `rule-package-integration-guide.md`
   - package-author workflow and required tests;
7. `record-reconstruction-guide.md`
   - external reader map for events, getters, ids, hashes, and source records;
8. `rule-package-compatibility-migration-policy.md`
   - active workflow package vs historical package identity policy;
9. `TERMINOLOGY.md`
   - standing/reputation, priority, publication, reveal, and sanction
     terminology boundary.

The files above are the current source of truth for public readers.

## Module Author Checklist

Before adding or replacing a module:

1. Identify the module family.
   - Core AVA stage: attribution, verification, or allocation.
   - Recognised-state governance support: transition, challenge, disclosure,
     evidence, audit, field, anti-abuse, residual authority.
   - Downstream consequence, execution, or proof support: standing, reward,
     priority, penalty, restoration, settlement, external operation, standing
     credential, or ZK proof.
2. Confirm the module is validation or adapter logic only.
   - It must not write recognised states directly.
   - It must not bypass authority, subject, evidence, package, target, status,
     nullifier, settlement-source, or terminal-state gates owned by the
     substrate.
3. Register it through a rule package when workflow-specific behavior is
   needed.
   - Existing recognised states remain bound to their historical `packageId`.
   - Re-registering a `workflowKey` only changes the active package for future
     records.
4. Add tests for:
   - package registration;
   - module rejection fail-closed behavior;
   - permissive module cannot bypass substrate hard gates;
   - historical package binding after workflow re-registration;
   - forbidden selector absence.
5. Keep AVA at three stages only.
   - Transition, challenge, disclosure, standing, reward, penalty,
     restoration, settlement, and credentials are not new AVA stages.

## External Reader Checklist

When reconstructing a governance path from chain data:

1. Start from the target record id and record family.
2. Read the record through the concrete contract getter.
3. Follow `packageId`, `workflowKey`, target id/kind, subject id, authority id,
   evidence receipt id, disclosure policy id, source record id, context hash,
   nullifier, and lifecycle status fields.
4. Use events as append-only anchors, not as substitutes for getter state.
5. Resolve rule-package metadata by `packageId`, not only by active
   `workflowKey`.
6. Treat lifecycle/readiness records as explicit metadata unless a separate
   substrate function performs a bounded state change.
7. Do not infer manuscript merit, scientific truth, confidential content,
   identity, or publication outcomes from these records.

## Scenario Package Checklist

When creating a new scenario workflow:

1. Define the workflow key and rule-package modules.
2. Define required disclosure policy and evidence policy references.
3. Define which recognised-state statuses can support downstream records.
4. Define the challenge lifecycle module and correction/restoration path.
5. Define whether standing, reward, priority, penalty, restoration, value
   settlement, external operation, standing credential, or ZK proof support is
   needed.
6. Keep all downstream paths bound to recognised states and package identity.
7. Add a scenario test proving:
   - the happy path works;
   - invalid evidence/subject/authority/package/status is rejected;
   - workflow re-registration does not rewrite old records;
   - raw review, raw challenge, and raw evidence ids cannot create downstream
     effects;
   - forbidden selectors remain absent.

## Current Runtime Evidence

The current baseline demo script demonstrates:

- manuscript intake;
- review contribution intake;
- evidence receipt and disclosure policy references;
- provisional recognised state;
- challenge filing, screening, and panel resolution;
- recognised-state status change;
- bounded consequence record;
- standing update record;
- allocation execution record;
- attestation/audit record.

The broader test suite covers additional proof, disclosure, credential,
settlement, recovery, external-operation, and package-reconfiguration surfaces.

Current verification expectation:

- `forge build` passes;
- `forge test` passes with 239 tests;
- the baseline demo script runs with `--offline` in this environment.

## Hard Boundaries

The demo must not add or infer:

- manuscript acceptance, rejection, merit scoring, acceptance probability,
  reviewer leniency, editorial decision, or publication advantage;
- scientific truth adjudication;
- identity or evidence reveal/decrypt;
- production access-control or production ZK infrastructure;
- sanction execution;
- production payment, stablecoin, token transfer, or real queue execution;
- standing/reputation as token, credit, balance, transferable asset,
  consumable asset, slashable asset, reward, public prestige, priority artifact,
  or manuscript merit.

Administrative priority tokens are a separate bounded queue/service-right demo
artifact. They are not standing or reputation.

## Handoff Rule

If a future task cannot be implemented by adding or replacing a module,
adapter, scenario package, test, or reader-facing document, treat it as a
substrate-change proposal and require a separate design/audit step before code
changes.
