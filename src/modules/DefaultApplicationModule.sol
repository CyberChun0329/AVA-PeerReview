// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";
import {AVACoreTypes} from "../core/AVACoreTypes.sol";
import {IAVAApplicationModule} from "../interfaces/IAVAApplicationModule.sol";
import {RuleModuleIdentity} from "../interfaces/IRuleModuleIdentity.sol";

/// @notice Permissive domain-neutral application validator used by the base demo package.
contract DefaultApplicationModule is IAVAApplicationModule, RuleModuleIdentity {
    bytes32 public immutable APP_ID;

    constructor(bytes32 appId_) {
        if (appId_ == bytes32(0)) revert AVADataTypes.EmptyValue();
        APP_ID = appId_;
    }

    function applicationId() external view returns (bytes32) {
        return APP_ID;
    }

    function validateGovernedObject(GovernedObjectContext calldata context) external view {
        if (
            context.appId != APP_ID || context.workflowKey == bytes32(0) || context.packageId == 0
                || context.roleKey == bytes32(0) || context.objectTypeKey == bytes32(0)
                || context.objectCommitment == bytes32(0) || context.subjectId == bytes32(0)
                || context.evidenceReceiptId == 0 || context.disclosurePolicyId == 0
                || context.metadataHash == bytes32(0) || context.authorityId == bytes32(0)
                || context.actor == address(0)
        ) {
            revert AVACoreTypes.EmptyValue();
        }
    }

    function validateRecognisedStateFormation(RecognisedStateFormationContext calldata context) external view {
        if (
            context.appId != APP_ID || context.workflowKey == bytes32(0) || context.packageId == 0
                || context.roleKey == bytes32(0) || context.governedObjectId == 0 || context.objectTypeKey == bytes32(0)
                || context.subjectId == bytes32(0) || context.stage == AVACoreTypes.Stage.None
                || context.status == AVACoreTypes.RecognisedStateStatus.None || context.authorityId == bytes32(0)
                || context.actor == address(0)
        ) {
            revert AVACoreTypes.EmptyValue();
        }
    }

    function validateRecognisedStateTransition(RecognisedStateTransitionContext calldata context) external view {
        if (
            context.appId != APP_ID || context.workflowKey == bytes32(0) || context.packageId == 0
                || context.roleKey == bytes32(0) || context.recognisedStateId == 0 || context.governedObjectId == 0
                || context.objectTypeKey == bytes32(0) || context.subjectId == bytes32(0)
                || context.fromStatus == AVACoreTypes.RecognisedStateStatus.None
                || context.toStatus == AVACoreTypes.RecognisedStateStatus.None
                || context.transitionKind == AVACoreTypes.TransitionKind.None || context.authorityId == bytes32(0)
                || context.actor == address(0)
        ) {
            revert AVACoreTypes.EmptyValue();
        }
    }

    function validateEvidence(EvidenceContext calldata context) external view {
        if (
            context.appId != APP_ID || context.workflowKey == bytes32(0) || context.packageId == 0
                || context.roleKey == bytes32(0) || context.subjectId == bytes32(0)
                || context.evidenceTypeHash == bytes32(0) || context.disclosurePolicyId == 0
                || context.authorityId == bytes32(0) || context.actor == address(0)
        ) {
            revert AVACoreTypes.EmptyValue();
        }
    }

    function validateDownstreamRecord(DownstreamRecordContext calldata context) external view {
        if (
            context.appId != APP_ID || context.workflowKey == bytes32(0) || context.packageId == 0
                || context.actionKey == bytes32(0) || context.roleKey == bytes32(0)
                || context.recognisedStateId == 0 || context.governedObjectId == 0
                || context.objectTypeKey == bytes32(0) || context.subjectId == bytes32(0)
                || context.evidenceReceiptId == 0 || context.recordTypeKey == bytes32(0)
                || context.authorityId == bytes32(0) || context.actor == address(0)
        ) {
            revert AVACoreTypes.EmptyValue();
        }
    }

    function _moduleConfigurationHash() internal view override returns (bytes32) {
        return APP_ID;
    }
}
