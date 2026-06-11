// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";
import {AuthorityApprovalRegistry} from "../AuthorityApprovalRegistry.sol";
import {IResidualEditorialAuthorityModule} from "../interfaces/IResidualEditorialAuthorityModule.sol";

contract ApprovalReceiptAuthorityModule is IResidualEditorialAuthorityModule {
    AuthorityApprovalRegistry public immutable APPROVAL_REGISTRY;
    uint256 public immutable PACKAGE_ID;
    AVADataTypes.Role public immutable REQUIRED_ROLE;
    AVADataTypes.Action public immutable REQUIRED_ACTION;
    uint8 public immutable REQUIRED_THRESHOLD;
    bytes32 public immutable EXCLUDED_AUTHORITY_ID;

    constructor(
        AuthorityApprovalRegistry approvalRegistry_,
        uint256 packageId_,
        AVADataTypes.Role requiredRole_,
        AVADataTypes.Action requiredAction_,
        uint8 requiredThreshold_,
        bytes32 excludedAuthorityId_
    ) {
        if (packageId_ == 0 || requiredRole_ == AVADataTypes.Role.None || requiredThreshold_ == 0) {
            revert AVADataTypes.EmptyValue();
        }
        APPROVAL_REGISTRY = approvalRegistry_;
        PACKAGE_ID = packageId_;
        REQUIRED_ROLE = requiredRole_;
        REQUIRED_ACTION = requiredAction_;
        REQUIRED_THRESHOLD = requiredThreshold_;
        EXCLUDED_AUTHORITY_ID = excludedAuthorityId_;
    }

    function validateResidualEditorialAuthority(ResidualEditorialAuthorityContext calldata context) external view {
        if (context.action != REQUIRED_ACTION) return;
        if (
            context.workflowKey == bytes32(0) || context.recognisedStateId == 0 || context.objectId == bytes32(0)
                || context.evidenceReceiptId == 0 || context.authorityId == bytes32(0) || context.actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
        if (context.actingRole != REQUIRED_ROLE) revert AVADataTypes.InvalidRole();
        if (EXCLUDED_AUTHORITY_ID != bytes32(0) && context.authorityId == EXCLUDED_AUTHORITY_ID) {
            revert AVADataTypes.InvalidState(uint256(context.authorityId));
        }
        if (
            !APPROVAL_REGISTRY.hasActiveApproval(
                context.workflowKey, PACKAGE_ID, context.action, context.recognisedStateId, context.objectId, context.authorityId
            )
        ) {
            revert AVADataTypes.InvalidState(context.recognisedStateId);
        }
        uint256 count = APPROVAL_REGISTRY.approvalCount(
            context.workflowKey, PACKAGE_ID, context.action, context.recognisedStateId, context.objectId
        );
        if (count < REQUIRED_THRESHOLD) revert AVADataTypes.InvalidState(context.recognisedStateId);
    }
}
