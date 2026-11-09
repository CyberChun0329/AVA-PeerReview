# Terminology

This glossary defines the terms used by the contracts and guides.

## AVA Stages

AVA has three stages only:

- Attribution
- Verification
- Allocation

Challenge and disclosure govern how recognised states are formed and used.
Standing, reward, penalty, settlement, and credential records support bounded
uses of those states. Restoration records an authorised recovery.

## Recognised State

A recognised state is the governance object operated on by the contracts. It is
a package-bound record over a target object, evidence reference, disclosure
policy, authority, and procedural status.

Recognised state is not scientific truth. It is not manuscript merit. It is
not publication acceptance or rejection.

## Rule Package

A rule package selects the modules for an application's workflow. An
authorised registrar uses `supersedeRulePackage` to select a new version for
new object and evidence registrations. Existing records keep their original
`packageId`.

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

A standing credential attests to an authorised standing computation. It can
prove a threshold, range, or category for a particular subject and rule package.

It is non-transferable, revocable, supersedable, and expiring. It is not
standing itself and not a reputation asset.

The ZK credential uses commitments and nullifiers to avoid publishing the full
standing history. The current implementation records a role-scoped subject ID,
so uses can be linked to that subject.

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
