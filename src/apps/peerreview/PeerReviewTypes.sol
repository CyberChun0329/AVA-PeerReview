// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library PeerReviewTypes {
    bytes32 internal constant APP_ID = keccak256("peer-review-app");

    bytes32 internal constant ROLE_AUTHOR = keccak256("ava.peer-review.role.author.v1");
    bytes32 internal constant ROLE_REVIEWER = keccak256("ava.peer-review.role.reviewer.v1");
    bytes32 internal constant ROLE_EDITOR = keccak256("ava.peer-review.role.editor.v1");
    bytes32 internal constant ROLE_CHALLENGER = keccak256("ava.peer-review.role.challenger.v1");
    bytes32 internal constant ROLE_INSTITUTION = keccak256("ava.peer-review.role.institution.v1");
    bytes32 internal constant ROLE_PANEL = keccak256("ava.peer-review.role.panel.v1");
    bytes32 internal constant ROLE_PROTOCOL_EXECUTOR = keccak256("ava.peer-review.role.protocol-executor.v1");

    bytes32 internal constant OBJECT_MANUSCRIPT = keccak256("ava.peer-review.object.manuscript.v1");
    bytes32 internal constant OBJECT_REVIEW_CONTRIBUTION = keccak256("ava.peer-review.object.review-contribution.v1");
    bytes32 internal constant OBJECT_CHALLENGE = keccak256("ava.peer-review.object.challenge.v1");

    bytes32 internal constant FINDING_ACADEMIC_FRAUD = keccak256("ava.peer-review.finding.academic-fraud.v1");
    bytes32 internal constant FINDING_IRRESPONSIBLE_REVIEW =
        keccak256("ava.peer-review.finding.irresponsible-review.v1");
    bytes32 internal constant FINDING_NEGLIGENT_CHALLENGE = keccak256("ava.peer-review.finding.negligent-challenge.v1");
    bytes32 internal constant FINDING_MALICIOUS_OR_FABRICATED_CHALLENGE =
        keccak256("ava.peer-review.finding.malicious-or-fabricated-challenge.v1");

    bytes32 internal constant RESTRICTION_REVIEW_ELIGIBILITY =
        keccak256("ava.peer-review.restriction.review-eligibility.v1");
    bytes32 internal constant RESTRICTION_CHALLENGE_INTAKE =
        keccak256("ava.peer-review.restriction.challenge-intake.v1");
    bytes32 internal constant RESTRICTION_PANEL_ELIGIBILITY =
        keccak256("ava.peer-review.restriction.panel-eligibility.v1");
}
