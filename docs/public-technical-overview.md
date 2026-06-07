# Public Technical Overview

This repository is a peer review technical demo and early sample of the AVA
protocol. It demonstrates how AVA-style governance can be represented on chain
through records, authorised transitions, rule packages, proof receipts, and
bounded downstream effects.

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

The design separates three things:

1. the AVA substrate, which stores records and enforces hard gates;
2. functional interfaces, which define what a package may validate;
3. scenario modules and adapters, which implement those interfaces for a
   concrete workflow such as double-blind review or anonymous challenge.

That is why future workflows should usually add or swap modules inside a rule
package rather than rewrite the recognised-state substrate.

The project is not token-first blockchain infrastructure. Blockchain is used
here only after AVA has named a governable object: the attributed object, the
responsible role-scoped subject, the evidence receipt, the authority condition,
the disclosure state, the challenge path, and the bounded consequence. The
contract layer preserves that grammar as records and authorised transitions; it
does not create the underlying judgement.

Put more concretely, an institutional peer-review rule enters this demo only
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

Rule packages let different peer-review workflows bind different validator
modules and downstream adapters without rewriting the recognised-state
substrate. A workflow key points to the currently active package, but each
record stores the `packageId` it was created under. This prevents new packages
from retroactively changing old recognised states.

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
and commitment-bound ZK standing credentials. These records make authorised
standing outputs auditable while keeping heavy calculation, private history
collection, and production ZK circuits outside the demo.

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
settlement receipts, and bounded consequences can be read as future
state/action/transition/information/payoff-proxy material.

The contracts do not perform that modelling. They do not estimate
probabilities, run simulations, score scientific quality, calculate social
welfare, or infer manuscript merit. Any future model should trace each variable
back to an implemented AVA record or explicitly mark it as a modelling
abstraction.

## Current Verification

The current verified demo state records:

- `forge build` passes;
- `forge test` passes with 221 tests;
- the baseline demo script runs with `--offline` in the local Foundry
  environment used for verification.

## What To Read Next

- `current-implementation-summary.md`: current implemented architecture.
- `architecture.md`: detailed technical narrative.
- `interface-contract-spec.md`: module and adapter semantics.
- `module-capability-matrix.md`: what modules may and must not do.
- `rule-package-integration-guide.md`: how to add a new workflow package.
- `record-reconstruction-guide.md`: how to reconstruct governance records.
- `rule-package-compatibility-migration-policy.md`: how historical packages
  remain bound to old records.
