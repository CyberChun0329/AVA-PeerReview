# Security Policy

This repository is a research demo and early sample of the AVA protocol in a
peer-review setting. It is not a production system and has not received a
production security audit.

## Supported Scope

Security reports are useful when they concern the implemented Solidity demo:

- authorisation bypasses;
- package identity or historical-record rewrite issues;
- replay or context-binding failures;
- standing/reputation boundary violations;
- disclosure proof-use or nullifier failures;
- settlement reentrancy or duplicate finalisation;
- forbidden publication, reveal, sanction, or standing-token surfaces.

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

Rule-package `workflowKey` re-registration is a trusted governance action by an
authorised package registrar. Historical records keep their stored `packageId`,
so a new active package cannot rewrite old recognised states, evidence,
challenges, credentials, settlements, or downstream records. The current demo
does not implement incumbent-package approval for active-pointer replacement.

The default anti-abuse module is intentionally permissive as a baseline demo
module. Workflows that need challenge-griefing mitigation should bind a stricter
anti-abuse or challenge-lifecycle module, such as the included subject-rate
limit example. This is not a production anti-abuse system.

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
