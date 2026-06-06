// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";
import {IPenaltyAdapter} from "../interfaces/IPenaltyAdapter.sol";

contract DefaultPenaltyAdapter is IPenaltyAdapter {
    function validatePenaltyRecord(
        AVADataTypes.Role,
        uint256,
        bytes32 subjectId,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata,
        address
    ) external pure {
        if (subjectId == bytes32(0) || evidenceReceiptId == 0 || authorityId == bytes32(0)) {
            revert AVADataTypes.EmptyValue();
        }
    }
}
