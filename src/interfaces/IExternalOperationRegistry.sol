// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";

interface IExternalOperationRegistry {
    function requestOperation(
        AVADataTypes.Role actingRole,
        bytes32 workflowKey,
        AVADataTypes.ExternalOperationKind kind,
        AVADataTypes.ExternalOperationTargetKind targetKind,
        uint256 targetId,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata referenceURI
    ) external returns (uint256 id);

    function getExternalOperation(uint256 id) external view returns (AVADataTypes.ExternalOperationRecord memory);
}
