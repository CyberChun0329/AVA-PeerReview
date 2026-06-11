# AVA Peer Review Solidity Demo

[![CI](https://github.com/CyberChun0329/AVA-PeerReview/actions/workflows/ci.yml/badge.svg)](https://github.com/CyberChun0329/AVA-PeerReview/actions/workflows/ci.yml)

This repository is an early technical demo of the AVA protocol for peer
review. It demonstrates an executable governance kernel for AVA-style peer
review using Solidity and Foundry. The contracts are written for
EVM-compatible chains. Base is the intended L2 target for future deployment
work.

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

- `src/`: Solidity contracts, interfaces, and example modules.
- `test/`: Foundry tests for the implemented governance kernel.
- `script/`: Local demo script.
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

The current verification state records `239` passing tests.

The public repository includes a GitHub Actions workflow that runs `forge
build` and `forge test` on pushes to `main` and on pull requests.

The baseline demo script is:

```bash
forge script script/AVADemoScenario.s.sol:AVADemoScenario --sig "run()" --offline
```

## License

This repository is released under the MIT License. See `LICENSE`.

## Security

This is unaudited research code. Do not deploy it for production peer review,
payments, sanctions, identity management, disclosure, or publication workflows.
See `SECURITY.md`.
