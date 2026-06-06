// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";

interface IDisclosurePolicyModule {
    function validateDisclosurePolicy(uint256 disclosurePolicyId) external view;

    /// @notice Validator-only disclosure policy seam.
    /// @dev Success means no policy veto only. It must not reveal/decrypt
    /// evidence or identity and must not implement production ACL.
    function validateDisclosureForAction(
        uint256 disclosurePolicyId,
        AVADataTypes.Role actingRole,
        AVADataTypes.Action action,
        AVADataTypes.AVAStage stage,
        bytes32 objectId,
        bytes32 workflowKey,
        uint256 packageId,
        bytes32 subjectCommitment
    ) external view;
}
