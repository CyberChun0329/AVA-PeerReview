// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVACoreTypes} from "../core/AVACoreTypes.sol";
import {IRuleModuleIdentity} from "./IRuleModuleIdentity.sol";

/// @notice Stable application namespace exposed by a package-bound application module.
interface IAVAApplicationModule is IRuleModuleIdentity {
    struct GovernedObjectContext {
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 roleKey;
        bytes32 objectTypeKey;
        bytes32 objectCommitment;
        uint256 parentObjectId;
        bytes32 parentObjectTypeKey;
        bytes32 parentWorkflowKey;
        uint256 parentPackageId;
        bytes32 parentSubjectId;
        bytes32 subjectId;
        uint256 evidenceReceiptId;
        uint256 disclosurePolicyId;
        bytes32 metadataHash;
        bytes32 authorityId;
        address actor;
    }

    struct RecognisedStateFormationContext {
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 roleKey;
        uint256 governedObjectId;
        bytes32 objectTypeKey;
        bytes32 subjectId;
        AVACoreTypes.Stage stage;
        AVACoreTypes.RecognisedStateStatus status;
        bytes32 authorityId;
        address actor;
    }

    struct RecognisedStateTransitionContext {
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 roleKey;
        uint256 recognisedStateId;
        uint256 governedObjectId;
        bytes32 objectTypeKey;
        bytes32 subjectId;
        AVACoreTypes.Stage stage;
        AVACoreTypes.RecognisedStateStatus fromStatus;
        AVACoreTypes.RecognisedStateStatus toStatus;
        AVACoreTypes.TransitionKind transitionKind;
        bytes32 actionKey;
        uint256 sourceRecordId;
        bytes32 authorityId;
        address actor;
    }

    struct EvidenceContext {
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 roleKey;
        bytes32 subjectId;
        bytes32 evidenceTypeHash;
        uint256 disclosurePolicyId;
        bytes32 authorityId;
        address actor;
    }

    struct EvidenceUseContext {
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 actionKey;
        bytes32 roleKey;
        AVACoreTypes.Stage stage;
        uint256 targetId;
        bytes32 objectTypeKey;
        bytes32 subjectId;
        uint256 evidenceId;
        bytes32 evidenceTypeHash;
        uint256 disclosurePolicyId;
        AVACoreTypes.EvidenceStatus evidenceStatus;
        bytes32 authorityId;
        address actor;
    }

    struct DownstreamRecordContext {
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 actionKey;
        bytes32 roleKey;
        uint256 recognisedStateId;
        uint256 governedObjectId;
        bytes32 objectTypeKey;
        bytes32 subjectId;
        uint256 evidenceReceiptId;
        bytes32 recordTypeKey;
        bytes32 authorityId;
        address actor;
    }

    function applicationId() external view returns (bytes32);

    function validateGovernedObject(GovernedObjectContext calldata context) external view;

    function validateRecognisedStateFormation(RecognisedStateFormationContext calldata context) external view;

    function validateRecognisedStateTransition(RecognisedStateTransitionContext calldata context) external view;

    function validateEvidence(EvidenceContext calldata context) external view;

    function validateDownstreamRecord(DownstreamRecordContext calldata context) external view;
}
