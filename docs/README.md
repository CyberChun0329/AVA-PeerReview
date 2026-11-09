# AVA Peer Review Documentation Map

These guides cover the local Solidity demo of AVA for peer review. Start with
the document that answers your question.

## How To Read These Documents

Use the default Foundry profile when checking the current architecture or
integrating an application. It builds Core, the reusable extensions, and the
Peer Review application. The `retained` profile also includes the earlier Peer
Review-specific contracts for regression testing.

## Read First

| To understand or change | Read |
| --- | --- |
| What the demo shows | [Technical overview](public-technical-overview.md), [terminology](TERMINOLOGY.md) |
| Which contract owns a check or record | [Architecture](architecture.md), [implemented contracts and verification](current-implementation-summary.md) |
| How to register an application or package | [Integration guide](rule-package-integration-guide.md), [module capabilities](module-capability-matrix.md), [interface reference](interface-contract-spec.md) |
| Which rules apply after a package update | [Package compatibility and migration](rule-package-compatibility-migration-policy.md) |
| How a state changes and how to inspect it | [State machines](state-machines.md), [record reconstruction](record-reconstruction-guide.md) |
| How to run or extend an example | [Demo scenarios](demo-scenarios.md), [integration checks](integration-handoff-pack.md) |
| Which research concepts the demo represents | [Translation-loss audit](translation-loss-audit.md) |

## Verification Profiles

```bash
forge build
forge test
forge script script/AVACanonicalTrace.s.sol:AVACanonicalTrace --sig "runTrace()" --offline
python3 scripts/ava_compatibility.py abi --check
python3 scripts/ava_compatibility.py boundaries
```

See the [verification summary](current-implementation-summary.md#verification)
for results and the [project README](../README.md#build-and-test) for additional
checks.
