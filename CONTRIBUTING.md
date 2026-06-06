# Contributing

This repository is a peer review technical demo and early sample of the AVA
protocol. Contributions should preserve the demo's role as an executable
governance kernel, not turn it into a production peer-review platform.

## Contribution Principles

- Preserve AVA's three stages: Attribution, Verification, and Allocation.
- Treat recognised state as the governance object, not as a fourth stage.
- Prefer new modules, adapters, tests, or documentation over substrate rewrites.
- Keep old records bound to their historical `packageId`.
- Keep authority, subject, evidence, target, context, nullifier, and settlement
  source checks at the substrate boundary.
- Keep standing and reputation as governance memory, not assets.

## Allowed Extension Shape

Future extensions should normally add or replace:

- rule packages;
- validator modules;
- downstream adapters;
- proof or disclosure modules;
- bounded record paths;
- tests and reconstruction documentation.

If a change requires rewriting the recognised-state substrate, explain why a
module or adapter cannot express the requirement first.

## Forbidden Contributions

Do not add:

- manuscript acceptance, rejection, merit scoring, or publication decisions;
- reviewer leniency or acceptance probability logic;
- identity reveal, evidence reveal, or decryption logic;
- production disclosure access control;
- sanction execution;
- production ZK circuits;
- real payment, stablecoin, queue, or platform integrations;
- standing tokens, reputation tokens, credits, balances, slashing, or
  transferable standing assets.

Administrative priority artifacts are separate bounded queue or service-right
demo records. They must not be described as standing, reputation, credit, or
manuscript advantage.

## Tests

For Solidity changes, run:

```bash
forge build
forge test
```

New rule packages or modules should include tests for:

- package registration;
- historical package binding after workflow re-registration;
- module rejection and fail-closed behaviour;
- substrate hard gates that permissive modules cannot bypass;
- forbidden selector and terminology boundaries.

## Documentation

Public-facing documentation should describe this project as a peer review
technical demo and early sample of the AVA protocol. Historical milestone notes
or development-stage records should not be used as public reader-facing
documentation. Current public facts should be documented through the README,
architecture, interface, capability, reconstruction, scenario, terminology, and
handoff documents.
