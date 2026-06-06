// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";

interface IAttributionModule {
    /// @notice Validator-only attribution seam.
    /// @dev Success means no veto. Returned object id is a deterministic
    /// governance reference, not a truth finding, authority grant, or merit score.
    function validateAttribution(
        bytes32 workflowKey,
        AVADataTypes.Role actingRole,
        AVADataTypes.AVAStage stage,
        bytes32 objectId,
        bytes32 subjectId,
        uint256 evidenceReceiptId
    ) external view returns (bytes32 attributedObjectId);
}
