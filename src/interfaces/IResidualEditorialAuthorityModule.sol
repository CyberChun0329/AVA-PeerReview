// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";

interface IResidualEditorialAuthorityModule {
    struct ResidualEditorialAuthorityContext {
        bytes32 workflowKey;
        AVADataTypes.Role actingRole;
        AVADataTypes.Action action;
        uint256 recognisedStateId;
        bytes32 objectId;
        uint256 evidenceReceiptId;
        bytes32 authorityId;
        address actor;
    }

    /// @notice Validator-only residual procedural authority seam.
    /// @dev Success means no procedural veto only. It must not create
    /// manuscript acceptance, rejection, merit, or publication effects.
    function validateResidualEditorialAuthority(ResidualEditorialAuthorityContext calldata context) external view;
}
