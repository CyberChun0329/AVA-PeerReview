# AVA Peer Review Solidity Demo

[![CI](https://github.com/CyberChun0329/AVA-PeerReview/actions/workflows/ci.yml/badge.svg)](https://github.com/CyberChun0329/AVA-PeerReview/actions/workflows/ci.yml)

This repository is an early technical demo of the AVA protocol, with peer
review as its first application. It now separates a domain-neutral AVA Core
from optional governance extensions and application-specific modules. Peer
review is the only application implementation under `src/apps/`. A
domain-neutral, test-only secondary application proves that another governance
domain can use the same deployed Core without editing Core contracts. The
contracts are written for EVM-compatible chains. Base is the intended L2 target
for future deployment work.

The project is not a production peer-review platform, journal system,
manuscript decision engine, payment system, disclosure-reveal system, or
scientific-truth engine. It is a research demo that shows how peer-review
governance objects can be represented as authorised records, transitions,
proof receipts, and bounded downstream consequences.

The repository does not include live Base deployment configuration, deployed
addresses, production hardening, or a network-specific rollout plan. Its
current chain scope is Base-compatible Solidity, not production Base
deployment.

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
- rule packages that bind workflow keys to replaceable modules and adapters;
- challenge, correction, and restoration as authorised transitions over
  recognised states;
- standing updates, standing computation statements, and standing credentials
  as governance-memory proof surfaces;
- ZK standing proof receipts and commitment-bound standing credentials as
  privacy-preserving proof carriers;
- bounded consequence, allocation, value-settlement, recovery, and external
  operation records;
- stable package identity so old records are not rewritten when a workflow key
  is re-registered.

The canonical architecture has three source layers:

- `src/core/`: domain-neutral AVA identity, authority, package, evidence,
  disclosure-policy, governed-object, recognised-state, and transition logic;
- `src/extensions/`: optional challenge, standing, proof, disclosure, audit,
  settlement, and external-operation record layers;
- `src/apps/`: replaceable application vocabulary and validator modules.

Core and extension entry points invoke `PeerReviewApplicationModule` through
package-bound validator dispatch. Application modules validate domain
vocabulary; they do not own Core storage, forward calls, or substitute a
spoofed actor identity. `test/helpers/SecondaryTestApp.sol` exercises the same
seam as a test fixture and is not a shipped application.

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

Standing and reputation are treated as computed governance memory. They are not
tokens, rewards, credits, balances, administrative priority rights, public
prestige, or manuscript merit. Administrative priority tokens used in tests are
separate bounded queue or service-right artifacts.

## Repository Layout

- `src/core/`: canonical domain-neutral AVA Core.
- `src/extensions/`: optional reusable governance extensions.
- `src/apps/peerreview/`: the peer-review application vocabulary and module.
- `src/canonical/AVAProductionSurface.sol`: import manifest for the canonical
  production contract surface used by the default build and size gate.
- `src/AVAApplicationRegistry.sol` and the shared interfaces
  `IAVAApplicationModule`, `IRuleModuleIdentity`, and `IZKProofVerifier`:
  domain-neutral canonical surfaces that remain physically under `src/`.
- other root-level contracts in `src/`: retained pre-separation research and
  regression implementation, compiled only through the explicit `retained`
  profile; new applications should integrate through the canonical Core and
  extension directories above.
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

Start with:

1. `docs/public-technical-overview.md`
2. `docs/architecture.md`
3. `docs/current-implementation-summary.md`
4. `docs/interface-contract-spec.md`
5. `docs/module-capability-matrix.md`
6. `docs/rule-package-integration-guide.md`
7. `docs/record-reconstruction-guide.md`
8. `docs/rule-package-compatibility-migration-policy.md`

## Build And Test

Install Foundry, then run:

```bash
forge build
forge test
```

The default profile builds and tests the canonical production surface. Its
current verification state records `250` passing tests. Four canonical
handler-based invariant suites also pass at 512 runs by 128 calls for recursive
challenge lineage, standing-proof freshness, recovery uniqueness, and
cross-application isolation.

The pre-separation implementation remains available as an explicit regression
profile:

```bash
FOUNDRY_PROFILE=retained forge test
```

That retained profile currently records `637` passing tests. It is historical
regression evidence, not the recommended application integration surface.

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

Cross-application isolation is verified by focused namespace, package,
evidence, state, challenge, proof, and downstream-record tests. The repository
does not ship or script a second application. The canonical runtime trace is:

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
