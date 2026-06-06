// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";

interface IValueSettlementExecutor {
    function getValueSettlement(uint256 id) external view returns (AVADataTypes.ValueSettlementRecord memory);

    function settleTokenTransfer(
        AVADataTypes.Role actingRole,
        AVADataTypes.ExecutionSourceType sourceType,
        uint256 sourceRecordId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id);

    function recordRepaymentObligation(
        AVADataTypes.Role actingRole,
        AVADataTypes.ExecutionSourceType sourceType,
        uint256 sourceRecordId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id);

    function recordFuturePayoutSetoff(
        AVADataTypes.Role actingRole,
        AVADataTypes.ExecutionSourceType sourceType,
        uint256 sourceRecordId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id);

    function recordWaiver(
        AVADataTypes.Role actingRole,
        AVADataTypes.ExecutionSourceType sourceType,
        uint256 sourceRecordId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id);

    function recordSatisfaction(
        AVADataTypes.Role actingRole,
        AVADataTypes.ExecutionSourceType sourceType,
        uint256 sourceRecordId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id);
}
