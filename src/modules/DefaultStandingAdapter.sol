// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";
import {IStandingAdapter} from "../interfaces/IStandingAdapter.sol";

contract DefaultStandingAdapter is IStandingAdapter {
    function validateStandingUpdate(
        AVADataTypes.Role,
        uint256,
        bytes32 subjectId,
        string calldata dimension,
        int256,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata,
        address
    ) external pure {
        if (subjectId == bytes32(0) || bytes(dimension).length == 0 || evidenceReceiptId == 0 || authorityId == bytes32(0)) {
            revert AVADataTypes.EmptyValue();
        }
    }
}
