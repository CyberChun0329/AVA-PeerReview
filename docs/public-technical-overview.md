# Public Technical Overview

This repository is an early technical demo of the AVA protocol. Peer review is
the first application, not the substrate itself. The implemented architecture
separates a domain-neutral AVA Core, optional reusable governance extensions,
and application modules. Peer review is the current application implementation.
A domain-neutral test fixture supplies different role, object, workflow, and
validation vocabulary to verify that the Core remains application-independent.

The contracts are implemented in Solidity for EVM-compatible chains. Base is
the intended L2 target for future deployment work, but the current repository
is a local Foundry demo and does not publish deployed Base addresses or a
production rollout configuration.

It is not a production peer-review platform. It does not decide whether a
manuscript should be accepted, rejected, prioritised, or judged meritorious.
It does not reveal identity or evidence. It does not execute sanctions or run a
production payment system.

## Core Idea

The demo treats peer review as an executable governance problem. A review,
challenge, correction, restoration, standing credential, or bounded settlement
does not become valid because a contract judges scientific truth. It becomes
governable because it is recorded through an authorised path, tied to evidence
references, scoped subjects, rule packages, and explicit status transitions.

For extension work, the design has three practical layers:

1. AVA Core, which stores generic governed objects and recognised states and
   enforces app, subject, authority, evidence, package, and transition gates;
2. optional extensions, which add challenge, standing, proof, disclosure,
   audit, settlement, or external-operation records without becoming Core;
3. application modules, which define domain vocabulary and validate concrete
   relationships for an app such as peer review.

That is why a different governance application should register an `appId`,
define an `IAVAApplicationModule`, and bind capability modules in rule
packages rather than rewrite the recognised-state substrate.

The canonical source boundary is explicit:

- `src/core/` contains domain-neutral Core contracts;
- `src/extensions/` contains optional reusable extensions;
- `src/apps/peerreview/` contains the current application vocabulary and
  validator;
- `test/helpers/SecondaryTestApp.sol` provides a test-only genericity fixture,
  not another shipped application.

Root-level contracts under `src/` retain the pre-separation research
implementation and its regression suite. They remain useful evidence, but
they are not the recommended integration surface for a new application.

The project is not token-first blockchain infrastructure. Blockchain is used
only after an AVA workflow has named the governable object: the attributed
object, the responsible role-scoped subject, the evidence receipt, the
authority condition, the disclosure state, the challenge path, and the bounded
consequence. The contract layer preserves that grammar as records and
authorised transitions. It does not create the underlying judgement.

In practical terms, an institutional peer-review rule enters this demo only
when it can be translated into:

- a role-bound object or subject;
- an evidence receipt or proof reference;
- an authority and disclosure condition;
- a challengeable recognised state or transition;
- a bounded consequence, correction, restoration, credential, settlement, or
  audit record.

## Three AVA Stages

The demo keeps AVA at three stages:

1. Attribution: who is acting, under which role-scoped subject, and with what
   authority.
2. Verification: what evidence-backed recognised state is formed, challenged,
   corrected, restored, or vested.
3. Allocation: what bounded downstream record may follow from an eligible
   recognised state.

Recognised state is the central governance object. It is not a fourth stage.

## Rule Packages

Rule packages are scoped by `(appId, workflowKey)`. Each package binds an
application module plus capability modules and receives a stable `packageId`.
An active pointer selects the package for new records, while governed objects,
evidence, recognised states, transitions, proofs, credentials, and downstream
receipts preserve the package used at creation. Replacing one application's
active package neither moves another application's pointer nor reinterprets
historical records.

Challenge is implemented as a recursive AVA workflow. A challenge has its own
governed object, evidence-backed recognised state, and independently selected
package before its lifecycle can target another recognised state. The
challenge package governs intake and decision policy; a correction or
restoration also passes the target state's historical package and the Core
transition graph.

## Privacy And Evidence

Evidence is represented by commitments, URIs, evidence-type hashes, lifecycle
status, and disclosure-policy references. The contracts check existence,
status, package identity, and policy references. They do not inspect evidence
content or judge whether evidence is scientifically true.

Disclosure and ZK surfaces are proof-use and receipt layers. They bind target
context, package, subject or subject commitment, policy, proof domain, and
nullifier. They do not reveal identity, decrypt evidence, or implement
production access control.

## Standing And Credentials

Standing is computed governance memory. It is not a token, credit, balance,
reward, public prestige score, administrative priority right, or manuscript
signal.

The repository includes standing computation statements, formula/source-set
commitments, ZK standing proof receipts, account-bound standing credentials,
and commitment-bound ZK standing credentials. The canonical ZK carrier records
both a role-scoped subject id and its commitment: it avoids exposing the full
standing history but remains role-subject-linkable rather than unlinkably
anonymous. These records make authorised standing outputs auditable while
keeping heavy calculation, private history collection, and production ZK
circuits outside the demo.

Credentials are proof carriers. They are non-transferable, expiring,
revocable, supersedable, and source-bound where relevant. They cannot create
standing, reward, priority, publication advantage, or manuscript merit by
themselves.

## Bounded Execution Records

The demo can record bounded consequences, allocation records, mock settlement
receipts, recovery records, administrative-priority artifacts, and external
operation intents. These records are designed to show how AVA Allocation can
attach downstream procedural effects without turning the contracts into a
publication, payment, queue, or sanction engine.

## Model Handoff Boundary

The on-chain records are meant to be legible inputs for later modelling work.
Recognised states, challenge transitions, standing records, proof receipts,
settlement receipts, and bounded consequences can be read as future modelling
material: states, actions, transitions, information conditions, and payoff
proxies.

The contracts do not perform that modelling. They do not estimate
probabilities, run simulations, score scientific quality, calculate social
welfare, or infer manuscript merit. Any future model should trace each variable
back to an implemented AVA record or explicitly mark it as a modelling
abstraction.

## Current Verification

The current verified demo state records:

- `forge build` passes;
- the default canonical profile passes 250 tests;
- four canonical handler-based invariant suites pass at 512 runs by 128 calls
  for recursive challenge lineage, recovery uniqueness, standing-proof
  freshness, and cross-application isolation;
- the explicit retained profile passes 637 pre-separation regression tests;
- the canonical trace script runs successfully, while second-app isolation
  remains a test-only verification surface;
- all contracts in the canonical production manifest remain below EIP-170.

## What To Read Next

- `current-implementation-summary.md`: current implemented architecture.
- `architecture.md`: detailed technical narrative.
- `interface-contract-spec.md`: module and adapter semantics.
- `module-capability-matrix.md`: what modules may and must not do.
- `rule-package-integration-guide.md`: how to add a new workflow package.
- `record-reconstruction-guide.md`: how to reconstruct governance records.
- `rule-package-compatibility-migration-policy.md`: how historical packages
  remain bound to old records.
