# AVA Peer Review Solidity Demo

[![CI](https://github.com/CyberChun0329/AVA-PeerReview/actions/workflows/ci.yml/badge.svg)](https://github.com/CyberChun0329/AVA-PeerReview/actions/workflows/ci.yml)

This research demo is an early sample of the AVA protocol, with peer review as
its first application. It shows how an authorised actor can record a review
contribution, recognise it for a specified use, and preserve later challenges
and corrections.

The contracts separate a shared AVA Core, optional governance extensions, and
the Peer Review application. Foundry tests run a second application fixture
against the same Core with different roles, objects, and rules. The demo runs
locally in Foundry. Its Solidity targets the EVM, with Base as the intended L2
for future deployment.

## What This Demo Shows

The demo keeps AVA at three stages only:

- Attribution
- Verification
- Allocation

The central governance object is the recognised state. A recognised state is a
recorded procedural status over an object such as a review contribution. It is
not a fourth AVA stage.

The contracts demonstrate:

- application namespaces that isolate roles, objects, packages, evidence, and
  recognised states;
- role-scoped subjects and authority checks;
- evidence receipts as commitments or off-chain references;
- disclosure policies and proof-use receipts without reveal or decryption;
- rule packages that select modules for each application's workflows;
- challenge, correction, and restoration as authorised transitions over
  recognised states;
- standing updates, recorded computations, and credentials that prove a
  standing condition without publishing the full history;
- ZK proof receipts and standing credentials linked to role-scoped subjects;
- bounded consequence, allocation, value-settlement, recovery, and external
  operation records;
- stable package IDs that keep old records tied to the rules used at creation.

Core and extensions call the application module selected by the record's rule
package. The module can reject a proposal. The calling contract checks who may
act and writes the record.

## What This Demo Does Not Do

The repository intentionally does not implement:

- manuscript acceptance, rejection, merit scoring, or publication decisions;
- reviewer leniency, acceptance probability, or publication priority;
- scientific truth adjudication;
- identity reveal, evidence reveal, decryption, or production access control;
- sanction execution;
- production ZK circuits;
- real payment, stablecoin, queue, or platform integrations;
- standing or reputation tokens, credits, balances, or transferable assets.

Standing is governance memory computed for a role. The administrative priority
tokens used in tests represent a separate queue or service right.

## Repository Layout

- `src/core/`: canonical domain-neutral AVA Core.
- `src/extensions/`: optional reusable governance extensions.
- `src/apps/peerreview/`: the peer-review application vocabulary and module.
- `src/canonical/AVAProductionSurface.sol`: contracts included in the default
  build and runtime size check.
- `src/AVAApplicationRegistry.sol` and the shared interfaces
  `IAVAApplicationModule`, `IRuleModuleIdentity`, and `IZKProofVerifier`:
  shared contracts and interfaces included in the default build.
- other root-level contracts in `src/`: retained pre-separation research and
  regression implementation. Run it with the `retained` profile.
- `test/`: Foundry tests for the implemented governance kernel, including a
  domain-neutral second-application isolation fixture.
- `script/`: Local demo script.
- `scripts/ava_compatibility.py`: Standard-library compatibility checks for
  canonical ABI drift, application import direction, and rule-package
  manifests.
- `generated/`: Reproducible transition, scenario, ABI, and canonical package
  artifacts. The package manifest describes a deterministic local script run,
  not a production deployment.
- `docs/`: Public technical documentation for the demo.

The [documentation index](docs/README.md) lists the relevant guide for each task.

## Build And Test

Install Foundry, then run:

```bash
forge build
forge test
```

The default profile builds and tests the current Core, extensions, and Peer
Review application. See the [verification summary](docs/current-implementation-summary.md#verification)
for test counts and invariant settings.

The pre-separation implementation remains available as an explicit regression
profile:

```bash
FOUNDRY_PROFILE=retained forge test
```

The public repository includes a GitHub Actions workflow that runs build,
canonical and retained tests, runtime-size checks, ABI drift checks,
rule-package manifest reconstruction, and Core/Application import-boundary
checks on pushes to `main` and on pull requests.

The compatibility checks can also be run locally:

```bash
python3 -m unittest scripts/tests/test_ava_compatibility.py
python3 scripts/ava_compatibility.py abi --check
python3 scripts/ava_compatibility.py boundaries
forge script script/AVACanonicalPackageManifest.s.sol:AVACanonicalPackageManifest --sig "run()" --offline
python3 scripts/ava_compatibility.py package --manifest generated/canonical-rule-package-manifest.json
```

To run the Peer Review scenarios:

```bash
forge script script/AVACanonicalTrace.s.sol:AVACanonicalTrace --sig "runTrace()" --offline
```

`script/AVADemoScenario.s.sol` remains available only through the retained
profile for pre-separation regression work.

## License

This repository is released under the MIT License. See `LICENSE`.

## Security

This is unaudited research code. Do not deploy it for production peer review,
payments, sanctions, identity management, disclosure, or publication workflows.
See `SECURITY.md`.
