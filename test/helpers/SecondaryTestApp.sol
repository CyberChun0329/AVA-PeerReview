// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVACoreTypes} from "../../src/core/AVACoreTypes.sol";
import {IAVAApplicationModule} from "../../src/interfaces/IAVAApplicationModule.sol";
import {RuleModuleIdentity} from "../../src/interfaces/IRuleModuleIdentity.sol";

/// @notice Domain-neutral vocabulary used only to prove cross-application isolation in tests.
library SecondaryTestAppTypes {
    bytes32 internal constant APP_ID = keccak256("ava.test.secondary-application.v1");

    bytes32 internal constant ROLE_SUBMITTER = keccak256("ava.test.secondary.role.submitter.v1");
    bytes32 internal constant ROLE_VERIFIER = keccak256("ava.test.secondary.role.verifier.v1");
    bytes32 internal constant ROLE_PANEL = keccak256("ava.test.secondary.role.panel.v1");
    bytes32 internal constant ROLE_PROTOCOL_EXECUTOR = keccak256("ava.test.secondary.role.protocol-executor.v1");

    bytes32 internal constant OBJECT_ROOT = keccak256("ava.test.secondary.object.root.v1");
    bytes32 internal constant OBJECT_CHILD = keccak256("ava.test.secondary.object.child.v1");
    bytes32 internal constant OBJECT_SUBMISSION = keccak256("ava.test.secondary.object.submission.v1");
    bytes32 internal constant OBJECT_CHALLENGE = keccak256("ava.test.secondary.object.challenge.v1");
}

/// @notice Validator-only test fixture. It is not a production application module.
contract SecondaryTestApplicationModule is IAVAApplicationModule, RuleModuleIdentity {
    function applicationId() external pure returns (bytes32) {
        return SecondaryTestAppTypes.APP_ID;
    }

    function validateGovernedObject(GovernedObjectContext calldata context) external pure {
        if (
            context.appId != SecondaryTestAppTypes.APP_ID || context.roleKey != SecondaryTestAppTypes.ROLE_SUBMITTER
                || context.subjectId != context.authorityId
        ) {
            revert AVACoreTypes.InvalidState(context.packageId);
        }
        if (context.objectTypeKey == SecondaryTestAppTypes.OBJECT_ROOT) {
            if (context.parentObjectId != 0 || context.parentObjectTypeKey != bytes32(0)) {
                revert AVACoreTypes.InvalidState(context.parentObjectId);
            }
            return;
        }
        if (context.objectTypeKey == SecondaryTestAppTypes.OBJECT_CHILD) {
            if (context.parentObjectId == 0 || context.parentObjectTypeKey != SecondaryTestAppTypes.OBJECT_ROOT) {
                revert AVACoreTypes.InvalidState(context.parentObjectId);
            }
            return;
        }
        if (context.objectTypeKey == SecondaryTestAppTypes.OBJECT_SUBMISSION) {
            if (
                context.parentObjectId == 0
                    || (context.parentObjectTypeKey != SecondaryTestAppTypes.OBJECT_ROOT
                        && context.parentObjectTypeKey != SecondaryTestAppTypes.OBJECT_CHILD)
            ) {
                revert AVACoreTypes.InvalidState(context.parentObjectId);
            }
            return;
        }
        if (context.objectTypeKey == SecondaryTestAppTypes.OBJECT_CHALLENGE) {
            if (
                context.parentObjectId == 0
                    || (context.parentObjectTypeKey != SecondaryTestAppTypes.OBJECT_SUBMISSION
                        && context.parentObjectTypeKey != SecondaryTestAppTypes.OBJECT_CHALLENGE)
            ) revert AVACoreTypes.InvalidState(context.parentObjectId);
            return;
        }
        revert AVACoreTypes.InvalidState(context.packageId);
    }

    function validateRecognisedStateFormation(RecognisedStateFormationContext calldata context) external pure {
        if (context.appId != SecondaryTestAppTypes.APP_ID || context.stage != AVACoreTypes.Stage.Verification) {
            revert AVACoreTypes.InvalidState(context.governedObjectId);
        }
        if (context.objectTypeKey == SecondaryTestAppTypes.OBJECT_SUBMISSION) {
            if (
                context.roleKey != SecondaryTestAppTypes.ROLE_VERIFIER
                    || context.status != AVACoreTypes.RecognisedStateStatus.Provisional
            ) revert AVACoreTypes.InvalidState(context.governedObjectId);
            return;
        }
        if (
            context.objectTypeKey != SecondaryTestAppTypes.OBJECT_CHALLENGE
                || context.roleKey != SecondaryTestAppTypes.ROLE_SUBMITTER
                || context.status != AVACoreTypes.RecognisedStateStatus.Registered
        ) revert AVACoreTypes.InvalidState(context.governedObjectId);
    }

    function validateRecognisedStateTransition(RecognisedStateTransitionContext calldata context) external pure {
        if (context.appId != SecondaryTestAppTypes.APP_ID) {
            revert AVACoreTypes.InvalidState(context.recognisedStateId);
        }
        if (context.objectTypeKey == SecondaryTestAppTypes.OBJECT_CHALLENGE) {
            if (
                context.transitionKind == AVACoreTypes.TransitionKind.Generic
                    && context.roleKey == SecondaryTestAppTypes.ROLE_SUBMITTER
                    && context.fromStatus == AVACoreTypes.RecognisedStateStatus.Registered
                    && context.toStatus == AVACoreTypes.RecognisedStateStatus.Challengeable
            ) return;
            if (
                context.transitionKind == AVACoreTypes.TransitionKind.Vesting
                    && context.roleKey == SecondaryTestAppTypes.ROLE_PANEL
                    && context.fromStatus == AVACoreTypes.RecognisedStateStatus.Challengeable
                    && context.toStatus == AVACoreTypes.RecognisedStateStatus.Vested
            ) return;
            revert AVACoreTypes.InvalidState(context.recognisedStateId);
        }
        if (context.objectTypeKey != SecondaryTestAppTypes.OBJECT_SUBMISSION) {
            revert AVACoreTypes.InvalidState(context.recognisedStateId);
        }
        if (context.transitionKind == AVACoreTypes.TransitionKind.Generic) {
            if (context.roleKey != SecondaryTestAppTypes.ROLE_VERIFIER) {
                revert AVACoreTypes.InvalidState(context.recognisedStateId);
            }
            return;
        }
        if (context.transitionKind == AVACoreTypes.TransitionKind.Vesting) {
            if (context.roleKey != SecondaryTestAppTypes.ROLE_PANEL) {
                revert AVACoreTypes.InvalidState(context.recognisedStateId);
            }
            if (
                context.fromStatus != AVACoreTypes.RecognisedStateStatus.Challengeable
                    || context.toStatus != AVACoreTypes.RecognisedStateStatus.Vested
            ) {
                revert AVACoreTypes.InvalidState(context.recognisedStateId);
            }
            return;
        }
        if (
            context.transitionKind == AVACoreTypes.TransitionKind.ChallengeCorrection
                || context.transitionKind == AVACoreTypes.TransitionKind.Restoration
        ) {
            if (context.roleKey != SecondaryTestAppTypes.ROLE_PANEL) {
                revert AVACoreTypes.InvalidState(context.recognisedStateId);
            }
            return;
        }
        revert AVACoreTypes.InvalidState(context.recognisedStateId);
    }

    function validateEvidence(EvidenceContext calldata context) external pure {
        if (
            context.appId != SecondaryTestAppTypes.APP_ID || context.roleKey != SecondaryTestAppTypes.ROLE_SUBMITTER
                || context.subjectId != context.authorityId
        ) {
            revert AVACoreTypes.InvalidState(context.packageId);
        }
    }

    function validateDownstreamRecord(DownstreamRecordContext calldata context) external pure {
        if (
            context.appId != SecondaryTestAppTypes.APP_ID
                || (context.objectTypeKey != SecondaryTestAppTypes.OBJECT_SUBMISSION
                    && context.objectTypeKey != SecondaryTestAppTypes.OBJECT_CHALLENGE)
                || context.recordTypeKey == bytes32(0)
        ) {
            revert AVACoreTypes.InvalidState(context.recognisedStateId);
        }
        if (context.actionKey == AVACoreTypes.ACTION_RECORD_ALLOCATION) {
            if (context.roleKey != SecondaryTestAppTypes.ROLE_PROTOCOL_EXECUTOR) {
                revert AVACoreTypes.InvalidState(context.recognisedStateId);
            }
            return;
        }
        if (
            context.actionKey == AVACoreTypes.ACTION_RECORD_STANDING_UPDATE
                || context.actionKey == AVACoreTypes.ACTION_RECORD_CONSEQUENCE
        ) {
            if (context.roleKey != SecondaryTestAppTypes.ROLE_PANEL) {
                revert AVACoreTypes.InvalidState(context.recognisedStateId);
            }
            return;
        }
        if (
            context.actionKey == AVACoreTypes.ACTION_RECORD_PRIVACY_PROOF
                || context.actionKey == AVACoreTypes.ACTION_RECORD_DISCLOSURE_RECEIPT
        ) {
            if (
                context.roleKey != SecondaryTestAppTypes.ROLE_SUBMITTER
                    && context.roleKey != SecondaryTestAppTypes.ROLE_PANEL
            ) {
                revert AVACoreTypes.InvalidState(context.recognisedStateId);
            }
            return;
        }
        if (context.actionKey == AVACoreTypes.ACTION_RECORD_AUDIT_RECEIPT) {
            if (context.roleKey != SecondaryTestAppTypes.ROLE_PANEL) {
                revert AVACoreTypes.InvalidState(context.recognisedStateId);
            }
            return;
        }
        if (
            context.actionKey == AVACoreTypes.ACTION_RECORD_SETTLEMENT_RECEIPT
                || context.actionKey == AVACoreTypes.ACTION_RECORD_EXTERNAL_OPERATION
                || context.actionKey == AVACoreTypes.ACTION_RECORD_EXTERNAL_OPERATION_OUTCOME
        ) {
            if (context.roleKey != SecondaryTestAppTypes.ROLE_PROTOCOL_EXECUTOR) {
                revert AVACoreTypes.InvalidState(context.recognisedStateId);
            }
            return;
        }
        revert AVACoreTypes.InvalidState(context.recognisedStateId);
    }

    function _moduleConfigurationHash() internal pure override returns (bytes32) {
        return SecondaryTestAppTypes.APP_ID;
    }
}
