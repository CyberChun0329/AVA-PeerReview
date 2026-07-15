// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";
import {IRuleModuleIdentity} from "./IRuleModuleIdentity.sol";

interface IAttributionModule is IRuleModuleIdentity {
    struct AttributionContext {
        bytes32 workflowKey;
        uint256 packageId;
        AVADataTypes.Role actingRole;
        AVADataTypes.Action action;
        AVADataTypes.AVAStage stage;
        bytes32 objectId;
        bytes32 subjectId;
        uint256 evidenceReceiptId;
        uint256 disclosurePolicyId;
        address actor;
    }

    /// @notice Validator-only attribution seam.
    /// @dev Success means no veto. Returned object id is a deterministic
    /// governance reference, not a truth finding, authority grant, or merit score.
    function validateAttribution(AttributionContext calldata context)
        external
        view
        returns (bytes32 attributedObjectId);
}
