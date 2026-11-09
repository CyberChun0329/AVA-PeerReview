# Public Technical Overview

The AVA demo follows a review contribution from submission to an authorised,
challengeable decision about how the contribution may be used. Peer review is
the first application. The Solidity contracts run locally in Foundry and
target the EVM. Base is the intended L2 for future deployment.

## Core Idea

An authorised editor can recognise a review contribution for a specified use.
The contract records the subject, evidence reference, disclosure policy, rule
package, and status. Later actors can inspect that history, challenge the
recognised state, and record an authorised correction. The institution still
judges the underlying evidence and the merits of a manuscript.

Three layers divide the work:

1. AVA Core, which stores generic governed objects and recognised states and
   checks the application, subject, authority, evidence, package, and transition;
2. optional extensions, which add challenge, standing, proof, disclosure,
   audit, settlement, or external-operation records;
3. application modules, which define domain-specific roles, object types, and
   relationships, such as which review can refer to which manuscript.

An application registers an `appId`, implements `IAVAApplicationModule`, and
chooses its policies in rule packages. A second application fixture exercises
this process against the same Core with different roles, objects, and workflows.

The canonical source boundary is explicit:

- `src/core/` contains domain-neutral Core contracts;
- `src/extensions/` contains optional reusable extensions;
- `src/apps/peerreview/` contains the current application vocabulary and
  validator;
- `test/helpers/SecondaryTestApp.sol` is the second application fixture.

The [architecture guide](architecture.md#canonical-source-boundary) identifies
the shared files included in the default build and the earlier implementation
kept for regression testing.

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
The active package governs new object and evidence registration. Later actions
on an existing record use its stored `packageId`, even if the workflow has a
new active package. Each application updates its own active package separately.

A challenge is itself an AVA workflow. It has its own object, evidence-backed
recognised state, and package. That package governs intake and decision policy.
Any correction or restoration must also satisfy the target state's historical
package and the Core transition rules.

## Privacy And Evidence

Evidence is represented by commitments, URIs, evidence-type hashes, lifecycle
status, and disclosure-policy references. The contracts check existence,
status, package identity, and policy references. They do not inspect evidence
content or judge whether evidence is scientifically true.

The disclosure and ZK contracts record where a proof may be used. A receipt
binds the target, package, subject or subject commitment, policy, verifier
context, and a nullifier that prevents replay. Confidential material stays off
chain.

## Standing And Credentials

Standing is computed governance memory. It is not a token, credit, balance,
reward, public prestige score, administrative priority right, or manuscript
signal.

The repository includes standing computation statements, formula/source-set
commitments, ZK standing proof receipts, account-bound standing credentials,
and commitment-bound ZK standing credentials. The canonical ZK carrier records
both a role-scoped subject ID and its commitment. A verifier can check the
recorded output without seeing the full standing history. Uses can still be
linked to the role-scoped subject. Computation, private history collection, and
production ZK circuits sit outside the demo.

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

## Using Records In A Model

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

## Verification

The [verification summary](current-implementation-summary.md#verification)
lists the Foundry results, runtime size checks, and command for running the
scenarios locally.

## What To Read Next

- `current-implementation-summary.md`: current implemented architecture.
- `architecture.md`: detailed technical narrative.
- `interface-contract-spec.md`: module and adapter semantics.
- `module-capability-matrix.md`: what modules may and must not do.
- `rule-package-integration-guide.md`: how to add a new workflow package.
- `record-reconstruction-guide.md`: how to reconstruct governance records.
- `rule-package-compatibility-migration-policy.md`: how historical packages
  remain bound to old records.
