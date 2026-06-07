# AVA Peer Review Documentation Map

This directory contains the public technical documentation for the AVA Peer
Review Solidity demo. The repository is a peer review technical demo and an
early sample of the AVA protocol, not a production peer-review platform,
manuscript decision engine, disclosure-reveal system, payment system, or
sanction engine.

The current implementation is a Base-compatible EVM/Solidity demo. Base is the
intended L2 target for future deployment work, but this repository does not
claim a live Base deployment, deployed addresses, or production deployment
hardening.

Internal development logs are not part of this public documentation map. They
may remain on the local machine for traceability, but they should not be
published as reader-facing protocol documentation.

## How To Read These Documents

The public documentation should be read as a technical companion to the AVA
peer-review research programme, not as a replacement for the paper. The
research framework supplies the conceptual vocabulary: Attribution,
Verification, Allocation, role-scoped subjects, evidence receipts, disclosure
state, recognised state, authorised transition, bounded consequence, and
standing as procedural governance memory.

The implementation documents supply the technical facts. They describe the
contracts, records, rule packages, modules, proof receipts, and tests that
exist in this repository. If a research note or manuscript draft uses broader
theory language, treat it as background unless the implemented contract
surface, tests, or current public docs also support the claim.

The central reading rule is:

```text
AVA recognised-state grammar -> Solidity substrate -> functional interface -> scenario module/adaptor -> package-bound record
```

This project is therefore not token-first blockchain infrastructure. It is a
recognised-state governance substrate that uses smart contracts to preserve
authorised records and transitions after the governed object, evidence,
authority, disclosure state, and bounded consequence have been specified.

## Read First

1. `public-technical-overview.md`
   - Short public overview for readers who need the project purpose and
     boundary before reading contract-level details.
2. `architecture.md`
   - Main technical architecture narrative.
   - Best single document for understanding the demo as one whole system.
3. `current-implementation-summary.md`
   - Short current implementation summary and verification status.
   - Best handoff document for another chat or reviewer.
4. `interface-contract-spec.md`
   - Interface-level contract semantics.
   - Best reference when adding or replacing a module.
5. `module-capability-matrix.md`
   - What each module/adapter family may do and must not do.
   - Best reference for boundary checks.
6. `rule-package-integration-guide.md`
   - Package-author checklist for adding a workflow package without rewriting
     the substrate.
7. `rule-package-compatibility-migration-policy.md`
   - Current policy for active workflow package replacement, historical package
     identity, compatibility metadata, and non-executing lifecycle readiness
     records.
8. `record-reconstruction-guide.md`
   - External reader map for reconstructing package-bound governance records
     from events, getters, ids, sources, and context hashes.
9. `demo-scenarios.md`
   - Demo scenario descriptions and script-level expectations.
10. `state-machines.md`
    - Implemented state-machine and lifecycle paths.
11. `TERMINOLOGY.md`
    - Public glossary for AVA stages, recognised state, standing, credentials,
      priority artifacts, disclosure proof-use, and bounded consequences.

## Support Document

- `integration-handoff-pack.md`
  - Practical read order and checklists for module authors, external readers,
    and scenario package authors.

## Boundary Reminder

The current demo keeps AVA at three stages only: Attribution, Verification,
and Allocation. Recognised state is the governance object, not a fourth stage.
Standing/reputation is governance memory, not a token, credit, balance, reward,
priority artifact, public prestige, or manuscript merit. Disclosure and ZK
paths are record/proof surfaces only; they do not reveal identity, decrypt
evidence, implement production ACL, judge scientific truth, execute sanctions,
or decide publication outcomes.
