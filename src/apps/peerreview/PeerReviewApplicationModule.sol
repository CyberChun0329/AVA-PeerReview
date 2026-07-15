// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVACoreTypes} from "../../core/AVACoreTypes.sol";
import {IAVAApplicationModule} from "../../interfaces/IAVAApplicationModule.sol";
import {RuleModuleIdentity} from "../../interfaces/IRuleModuleIdentity.sol";
import {PeerReviewTypes} from "./PeerReviewTypes.sol";

contract PeerReviewApplicationModule is IAVAApplicationModule, RuleModuleIdentity {
    function applicationId() external pure returns (bytes32) {
        return PeerReviewTypes.APP_ID;
    }

    function validateGovernedObject(GovernedObjectContext calldata context) external pure {
        if (context.appId != PeerReviewTypes.APP_ID || context.subjectId != context.authorityId) {
            revert AVACoreTypes.InvalidState(context.packageId);
        }
        if (context.objectTypeKey == PeerReviewTypes.OBJECT_MANUSCRIPT) {
            if (
                context.roleKey != PeerReviewTypes.ROLE_AUTHOR || context.parentObjectId != 0
                    || context.parentObjectTypeKey != bytes32(0) || context.parentWorkflowKey != bytes32(0)
                    || context.parentPackageId != 0 || context.parentSubjectId != bytes32(0)
            ) {
                revert AVACoreTypes.InvalidState(context.parentObjectId);
            }
            return;
        }
        if (context.objectTypeKey == PeerReviewTypes.OBJECT_REVIEW_CONTRIBUTION) {
            if (
                context.roleKey != PeerReviewTypes.ROLE_REVIEWER || context.parentObjectId == 0
                    || context.parentObjectTypeKey != PeerReviewTypes.OBJECT_MANUSCRIPT
                    || context.parentWorkflowKey != context.workflowKey || context.parentPackageId == 0
                    || context.parentSubjectId == bytes32(0)
            ) {
                revert AVACoreTypes.InvalidState(context.parentObjectId);
            }
            return;
        }
        if (context.objectTypeKey == PeerReviewTypes.OBJECT_CHALLENGE) {
            if (
                context.roleKey != PeerReviewTypes.ROLE_CHALLENGER || context.parentObjectId == 0
                    || (context.parentObjectTypeKey != PeerReviewTypes.OBJECT_REVIEW_CONTRIBUTION
                        && context.parentObjectTypeKey != PeerReviewTypes.OBJECT_CHALLENGE)
                    || context.parentWorkflowKey == bytes32(0) || context.parentPackageId == 0
                    || context.parentSubjectId == bytes32(0)
            ) {
                revert AVACoreTypes.InvalidState(context.parentObjectId);
            }
            return;
        }
        revert AVACoreTypes.InvalidState(context.packageId);
    }

    function validateRecognisedStateFormation(RecognisedStateFormationContext calldata context) external pure {
        if (context.appId != PeerReviewTypes.APP_ID || context.stage != AVACoreTypes.Stage.Verification) {
            revert AVACoreTypes.InvalidState(context.governedObjectId);
        }
        if (context.objectTypeKey == PeerReviewTypes.OBJECT_REVIEW_CONTRIBUTION) {
            if (
                context.roleKey != PeerReviewTypes.ROLE_EDITOR
                    || (context.status != AVACoreTypes.RecognisedStateStatus.Registered
                        && context.status != AVACoreTypes.RecognisedStateStatus.Provisional)
            ) revert AVACoreTypes.InvalidState(context.governedObjectId);
            return;
        }
        if (
            context.objectTypeKey != PeerReviewTypes.OBJECT_CHALLENGE
                || context.roleKey != PeerReviewTypes.ROLE_CHALLENGER
                || context.status != AVACoreTypes.RecognisedStateStatus.Registered
        ) revert AVACoreTypes.InvalidState(context.governedObjectId);
    }

    function validateRecognisedStateTransition(RecognisedStateTransitionContext calldata context) external pure {
        if (context.appId != PeerReviewTypes.APP_ID) {
            revert AVACoreTypes.InvalidState(context.recognisedStateId);
        }
        if (context.objectTypeKey == PeerReviewTypes.OBJECT_CHALLENGE) {
            _validateChallengeTransition(context);
            return;
        }
        if (context.objectTypeKey != PeerReviewTypes.OBJECT_REVIEW_CONTRIBUTION) {
            revert AVACoreTypes.InvalidState(context.recognisedStateId);
        }
        if (context.transitionKind == AVACoreTypes.TransitionKind.Generic) {
            if (context.roleKey != PeerReviewTypes.ROLE_EDITOR) {
                revert AVACoreTypes.InvalidState(context.recognisedStateId);
            }
            return;
        }
        if (context.transitionKind == AVACoreTypes.TransitionKind.Vesting) {
            if (
                context.roleKey != PeerReviewTypes.ROLE_PANEL
                    || context.fromStatus != AVACoreTypes.RecognisedStateStatus.Challengeable
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
            if (context.roleKey != PeerReviewTypes.ROLE_PANEL) {
                revert AVACoreTypes.InvalidState(context.recognisedStateId);
            }
            return;
        }
        revert AVACoreTypes.InvalidState(context.recognisedStateId);
    }

    function _validateChallengeTransition(RecognisedStateTransitionContext calldata context) private pure {
        if (context.transitionKind == AVACoreTypes.TransitionKind.Generic) {
            if (
                context.roleKey != PeerReviewTypes.ROLE_CHALLENGER
                    || context.fromStatus != AVACoreTypes.RecognisedStateStatus.Registered
                    || context.toStatus != AVACoreTypes.RecognisedStateStatus.Challengeable
                    || context.actionKey != AVACoreTypes.ACTION_FILE_CHALLENGE || context.sourceRecordId == 0
            ) revert AVACoreTypes.InvalidState(context.recognisedStateId);
            return;
        }
        if (context.transitionKind == AVACoreTypes.TransitionKind.Vesting) {
            if (
                context.roleKey != PeerReviewTypes.ROLE_PANEL
                    || context.fromStatus != AVACoreTypes.RecognisedStateStatus.Challengeable
                    || context.toStatus != AVACoreTypes.RecognisedStateStatus.Vested
                    || context.actionKey != AVACoreTypes.ACTION_RESOLVE_CHALLENGE || context.sourceRecordId == 0
            ) revert AVACoreTypes.InvalidState(context.recognisedStateId);
            return;
        }
        if (context.transitionKind == AVACoreTypes.TransitionKind.ChallengeCorrection) {
            if (
                context.roleKey != PeerReviewTypes.ROLE_PANEL
                    || context.actionKey != AVACoreTypes.ACTION_RESOLVE_CHALLENGE || context.sourceRecordId == 0
            ) revert AVACoreTypes.InvalidState(context.recognisedStateId);
            return;
        }
        if (context.transitionKind == AVACoreTypes.TransitionKind.Restoration) {
            if (
                context.roleKey != PeerReviewTypes.ROLE_PANEL
                    || context.actionKey != AVACoreTypes.ACTION_APPLY_RESTORATION || context.sourceRecordId == 0
            ) revert AVACoreTypes.InvalidState(context.recognisedStateId);
            return;
        }
        revert AVACoreTypes.InvalidState(context.recognisedStateId);
    }

    function validateEvidence(EvidenceContext calldata context) external pure {
        if (
            context.appId != PeerReviewTypes.APP_ID || context.subjectId != context.authorityId
                || (context.roleKey != PeerReviewTypes.ROLE_AUTHOR
                    && context.roleKey != PeerReviewTypes.ROLE_REVIEWER
                    && context.roleKey != PeerReviewTypes.ROLE_CHALLENGER)
        ) {
            revert AVACoreTypes.InvalidState(context.packageId);
        }
    }

    function validateDownstreamRecord(DownstreamRecordContext calldata context) external pure {
        if (
            context.appId != PeerReviewTypes.APP_ID
                || (context.objectTypeKey != PeerReviewTypes.OBJECT_REVIEW_CONTRIBUTION
                    && context.objectTypeKey != PeerReviewTypes.OBJECT_CHALLENGE) || context.recordTypeKey == bytes32(0)
        ) {
            revert AVACoreTypes.InvalidState(context.recognisedStateId);
        }
        if (context.actionKey == AVACoreTypes.ACTION_RECORD_PENALTY) {
            _validatePenaltyFinding(context.objectTypeKey, context.recordTypeKey, context.recognisedStateId);
        }
        if (
            context.actionKey == AVACoreTypes.ACTION_RECORD_STANDING_UPDATE
                || context.actionKey == AVACoreTypes.ACTION_RECORD_STANDING_COMPUTATION
                || context.actionKey == AVACoreTypes.ACTION_ISSUE_STANDING_CREDENTIAL
                || context.actionKey == AVACoreTypes.ACTION_REVOKE_STANDING_CREDENTIAL
                || context.actionKey == AVACoreTypes.ACTION_SUPERSEDE_STANDING_CREDENTIAL
                || context.actionKey == AVACoreTypes.ACTION_REGISTER_STANDING_SOURCE_SET
                || context.actionKey == AVACoreTypes.ACTION_ATTEST_STANDING_SOURCE_SET
                || context.actionKey == AVACoreTypes.ACTION_RECORD_STANDING_COMPUTATION_STATEMENT
                || context.actionKey == AVACoreTypes.ACTION_SUPERSEDE_STANDING_COMPUTATION_STATEMENT
                || context.actionKey == AVACoreTypes.ACTION_INVALIDATE_STANDING_COMPUTATION_STATEMENT
                || context.actionKey == AVACoreTypes.ACTION_RECORD_STANDING_ZK_PROOF
                || context.actionKey == AVACoreTypes.ACTION_ISSUE_STANDING_ZK_CREDENTIAL
                || context.actionKey == AVACoreTypes.ACTION_REVOKE_STANDING_ZK_CREDENTIAL
                || context.actionKey == AVACoreTypes.ACTION_SUPERSEDE_STANDING_ZK_CREDENTIAL
        ) {
            if (context.roleKey != PeerReviewTypes.ROLE_PANEL) {
                revert AVACoreTypes.InvalidState(context.recognisedStateId);
            }
            return;
        }
        if (context.actionKey == AVACoreTypes.ACTION_RECORD_ALLOCATION) {
            if (context.roleKey != PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR) {
                revert AVACoreTypes.InvalidState(context.recognisedStateId);
            }
            return;
        }
        if (context.actionKey == AVACoreTypes.ACTION_RECORD_CONSEQUENCE) {
            if (context.roleKey != PeerReviewTypes.ROLE_PANEL) {
                revert AVACoreTypes.InvalidState(context.recognisedStateId);
            }
            return;
        }
        if (
            context.actionKey == AVACoreTypes.ACTION_RECORD_PRIVACY_PROOF
                || context.actionKey == AVACoreTypes.ACTION_RECORD_DISCLOSURE_RECEIPT
        ) {
            if (
                context.roleKey != PeerReviewTypes.ROLE_REVIEWER && context.roleKey != PeerReviewTypes.ROLE_CHALLENGER
                    && context.roleKey != PeerReviewTypes.ROLE_PANEL
            ) {
                revert AVACoreTypes.InvalidState(context.recognisedStateId);
            }
            return;
        }
        if (context.actionKey == AVACoreTypes.ACTION_RECORD_AUDIT_RECEIPT) {
            if (context.roleKey != PeerReviewTypes.ROLE_PANEL) {
                revert AVACoreTypes.InvalidState(context.recognisedStateId);
            }
            return;
        }
        if (
            context.actionKey == AVACoreTypes.ACTION_RECORD_SETTLEMENT_RECEIPT
                || context.actionKey == AVACoreTypes.ACTION_RECORD_EXTERNAL_OPERATION
                || context.actionKey == AVACoreTypes.ACTION_RECORD_EXTERNAL_OPERATION_OUTCOME
                || context.actionKey == AVACoreTypes.ACTION_RECORD_REWARD
                || context.actionKey == AVACoreTypes.ACTION_RECORD_ADMINISTRATIVE_PRIORITY
                || context.actionKey == AVACoreTypes.ACTION_RECORD_REWARD_LIFECYCLE
                || context.actionKey == AVACoreTypes.ACTION_RECORD_VALUE_SETTLEMENT
                || context.actionKey == AVACoreTypes.ACTION_RECORD_REPAYMENT_OBLIGATION
                || context.actionKey == AVACoreTypes.ACTION_RECORD_RECOVERY_OUTCOME
        ) {
            if (context.roleKey != PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR) {
                revert AVACoreTypes.InvalidState(context.recognisedStateId);
            }
            return;
        }
        if (
            context.actionKey == AVACoreTypes.ACTION_RECORD_PENALTY
                || context.actionKey == AVACoreTypes.ACTION_RECORD_STANDING_PENALTY_INPUT
                || context.actionKey == AVACoreTypes.ACTION_RECORD_ELIGIBILITY_RESTRICTION
                || context.actionKey == AVACoreTypes.ACTION_RECORD_RESTORATION
        ) {
            if (context.roleKey != PeerReviewTypes.ROLE_PANEL) {
                revert AVACoreTypes.InvalidState(context.recognisedStateId);
            }
            return;
        }
        revert AVACoreTypes.InvalidState(context.recognisedStateId);
    }

    function _validatePenaltyFinding(bytes32 objectTypeKey, bytes32 findingKey, uint256 recognisedStateId)
        private
        pure
    {
        if (objectTypeKey == PeerReviewTypes.OBJECT_REVIEW_CONTRIBUTION) {
            if (findingKey != PeerReviewTypes.FINDING_IRRESPONSIBLE_REVIEW) {
                revert AVACoreTypes.InvalidState(recognisedStateId);
            }
            return;
        }
        if (
            findingKey != PeerReviewTypes.FINDING_NEGLIGENT_CHALLENGE
                && findingKey != PeerReviewTypes.FINDING_MALICIOUS_OR_FABRICATED_CHALLENGE
        ) revert AVACoreTypes.InvalidState(recognisedStateId);
    }

    function _moduleConfigurationHash() internal pure override returns (bytes32) {
        return PeerReviewTypes.APP_ID;
    }
}
