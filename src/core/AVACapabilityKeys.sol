// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library AVACapabilityKeys {
    bytes32 internal constant APPLICATION = keccak256("ava.capability.application.v1");
    bytes32 internal constant ATTRIBUTION = keccak256("ava.capability.attribution.v1");
    bytes32 internal constant VERIFICATION = keccak256("ava.capability.verification.v1");
    bytes32 internal constant TRANSITION_RULE = keccak256("ava.capability.transition-rule.v1");
    bytes32 internal constant EVIDENCE_POLICY = keccak256("ava.capability.evidence-policy.v1");
    bytes32 internal constant EVIDENCE_LIFECYCLE = keccak256("ava.capability.evidence-lifecycle.v1");
    bytes32 internal constant DISCLOSURE_POLICY = keccak256("ava.capability.disclosure-policy.v1");
    bytes32 internal constant CHALLENGE_POLICY = keccak256("ava.capability.challenge-policy.v1");
    bytes32 internal constant AUTHORITY_POLICY = keccak256("ava.capability.authority-policy.v1");
    bytes32 internal constant STANDING = keccak256("ava.capability.standing.v1");
    bytes32 internal constant STANDING_COMPUTATION = keccak256("ava.capability.standing-computation.v1");
    bytes32 internal constant STANDING_CREDENTIAL = keccak256("ava.capability.standing-credential.v1");
    bytes32 internal constant ALLOCATION = keccak256("ava.capability.allocation.v1");
    bytes32 internal constant CONSEQUENCE = keccak256("ava.capability.consequence.v1");
    bytes32 internal constant PRIVACY_PROOF = keccak256("ava.capability.privacy-proof.v1");
    bytes32 internal constant DISCLOSURE_RECEIPT = keccak256("ava.capability.disclosure-receipt.v1");
    bytes32 internal constant AUDIT_RECEIPT = keccak256("ava.capability.audit-receipt.v1");
    bytes32 internal constant SETTLEMENT_RECEIPT = keccak256("ava.capability.settlement-receipt.v1");
    bytes32 internal constant EXTERNAL_OPERATION = keccak256("ava.capability.external-operation.v1");
    bytes32 internal constant PACKAGE_LIFECYCLE = keccak256("ava.capability.package-lifecycle.v1");
    bytes32 internal constant AUTHORITY_APPROVAL = keccak256("ava.capability.authority-approval.v1");
    bytes32 internal constant REWARD = keccak256("ava.capability.reward.v1");
    bytes32 internal constant PRIORITY = keccak256("ava.capability.administrative-priority.v1");
    bytes32 internal constant PENALTY = keccak256("ava.capability.penalty.v1");
    bytes32 internal constant RESTORATION = keccak256("ava.capability.restoration.v1");
    bytes32 internal constant VALUE_EXECUTION = keccak256("ava.capability.value-execution.v1");
    bytes32 internal constant STANDING_PROVENANCE = keccak256("ava.capability.standing-provenance.v1");
    bytes32 internal constant STANDING_ZK_PROOF = keccak256("ava.capability.standing-zk-proof.v1");
    bytes32 internal constant STANDING_ZK_CREDENTIAL = keccak256("ava.capability.standing-zk-credential.v1");
    bytes32 internal constant FIELD_POLICY = keccak256("ava.capability.field-policy.v1");
    bytes32 internal constant ANTI_ABUSE = keccak256("ava.capability.anti-abuse.v1");
}
