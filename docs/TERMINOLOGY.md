# Terminology

This file fixes the public vocabulary for the AVA Peer Review Solidity demo.
It is meant to prevent common misreadings when the repository is used as an
early technical sample of the AVA protocol.

## AVA Stages

AVA has three stages only:

- Attribution
- Verification
- Allocation

Challenge, disclosure, standing, restoration, reward, penalty, settlement, and
credential support are not additional AVA stages. They are governance support
or downstream record surfaces around recognised states.

## Recognised State

A recognised state is the governance object operated on by the contracts. It is
a package-bound record over a target object, evidence reference, disclosure
policy, authority, and procedural status.

Recognised state is not scientific truth. It is not manuscript merit. It is
not publication acceptance or rejection.

## Rule Package

A rule package binds a workflow key to validator modules and downstream
adapters. Re-registering a workflow key creates a new package identity for
future actions. Old recognised states and downstream records remain bound to
their historical `packageId`.

## Challenge, Correction, And Restoration

A challenge is a procedural concern filed against an existing challengeable
recognised state. Raw challenge filing does not sanction anyone and does not
create standing, reward, allocation, or publication effects.

Correction means an authorised adverse transition, such as downgrade or void,
after a challenge outcome. Correction is not punishment by default.

Restoration means an explicit authorised transition that records procedural
recovery after an adverse recognised-state status. It is not deletion,
forgiveness, reward, or silent overwrite.

## Standing And Reputation

Standing and reputation are computed governance memory over recognised-state
history, standing update records, computation statements, challenge outcomes,
correction/restoration records, and related settlement impacts.

Standing and reputation are not:

- tokens;
- credits;
- balances;
- transferable assets;
- consumable rights;
- public prestige scores;
- rewards;
- administrative priority rights;
- manuscript merit;
- publication signals.

Do not use names such as `StandingToken`, `ReputationToken`, `CreditToken`,
`standingBalance`, `reputationBalance`, `mintReputation`, or
`transferStanding`.

## Standing Credential

A standing credential is a proof carrier for an authorised standing-computation
output. It may express a threshold, range, category, vector, epoch, package,
subject, and expiry.

It is non-transferable, revocable, supersedable, and expiring. It is not
standing itself and not a reputation asset.

The ZK standing credential lane uses commitments and nullifiers rather than an
owner account. It supports privacy-preserving standing proof use without
revealing the underlying identity or complete standing history.

## Administrative Priority Token

An administrative priority token is a separate bounded queue or service-right
artifact used in mock settlement tests. It is not standing, reputation, credit,
manuscript merit, or publication priority.

## Disclosure Proof Use

Disclosure proof use records that a proof was used for a target context. It
does not reveal identity, decrypt evidence, or implement production access
control.

## Bounded Consequence

A bounded consequence is an administrative or procedural record tied to an
allowed recognised state, evidence reference, authority, and subject. It does
not execute sanctions and does not decide manuscript outcomes.
