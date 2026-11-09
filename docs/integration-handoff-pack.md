# Integration Checks

Use this checklist when adding an application, replacing a rule package, or
checking whether an existing record can support a later action. The
[documentation index](README.md) lists the guides by task.

## Add An Application Or Package

Follow the [integration guide](rule-package-integration-guide.md) to register
the application, assign roles, and select modules. Then test these outcomes:

- The authorised actor can complete the workflow under the intended package.
- A reference from another application, an unauthorised actor, or evidence
  that has been revoked cannot authorise a new action.
- A custom policy can reject a proposal. An accepting policy cannot override
  the checks Core or the extension owns.
- Supersession changes the package for new object and evidence registrations.
  Later actions on an existing record still follow its original `packageId`.
- A submitted review or accusation cannot by itself create standing, an
  allocation, or another consequence.

For a challenge workflow, exercise both the challenge's own package and the
target state's historical package. Include a case where a proposed correction
fails because the target has changed since filing. The
[state machine guide](state-machines.md) explains the transition records.

## Inspect An Existing Record

Start with the record's type, contract, and ID. Read its fields through the
getter, then follow its source records and stored `packageId`. Events help
locate a record and order changes. Use the current status before relying on
a permission or credential. The [reconstruction guide](record-reconstruction-guide.md)
lists the fields, getters, and events to follow for each record type.

## Reproduce The Demo

The [demo scenarios](demo-scenarios.md) show what to expect from the local
trace, including vesting, correction, and restoration. The
[verification summary](current-implementation-summary.md#verification)
reports the results of the broader suite. See the
[translation-loss audit](translation-loss-audit.md) before citing a record
as evidence for a research claim.
