# Security Policy

This repository is a research demo and early sample of the AVA protocol in a
peer-review setting. It is not a production system and has not received a
production security audit.

## Supported Scope

Report issues in the implemented contracts, such as:

- authorisation bypasses;
- package identity or historical-record rewrite issues;
- replay or context-binding failures;
- standing credentials that remain usable after they should expire or be
  invalidated;
- disclosure proof-use or nullifier failures;
- settlement reentrancy or duplicate finalisation;
- a path that introduces publication decisions, reveals confidential content,
  executes a sanction, or makes standing transferable.

## Out Of Scope

This repository does not implement and does not claim to secure:

- production journal workflows;
- manuscript acceptance, rejection, or merit decisions;
- production ZK circuits;
- identity reveal, evidence decryption, or production access control;
- real payment, stablecoin, queue, or external-platform execution;
- sanction execution;
- production deployment infrastructure.

## Demo Settlement Assumptions

The value-settlement tests use local mock tokens to demonstrate source-bound
receipt handling, duplicate-finalisation rejection, and reentrancy protection.
They are not a production token-integration claim. Non-standard ERC20 tokens,
fee-on-transfer tokens, callback-heavy tokens, bridged assets, stablecoin
issuer controls, and production payment rails require a separate integration
review before use.

## Governance Trust Boundaries

An authorised registrar can supersede an application's active package. The
registry checks the expected active package and the next version. Existing
records retain the original `packageId`. The procedure trusts the registrar
to select suitable new modules and requires no vote from the old package.

`AVAChallengeExtension` limits a filing account to one challenge per version
of a target state and bars conflicting accounts from screening or deciding
the challenge. The default optional anti-abuse validator adds no checks.
Workflows can select additional checks in their rule packages.

## Reporting

If this repository is hosted publicly, please report security issues through
the repository's GitHub security advisory flow or by opening a clear issue when
the issue is not sensitive.

Please include:

- the affected contract or interface;
- the relevant function or record path;
- a short reproduction or test outline;
- why the issue crosses a stated boundary.

Do not submit reports that ask the contracts to implement production peer
review, publication decisions, reveal/decrypt paths, sanction execution, or
real payment infrastructure. Those features are intentionally out of scope.
