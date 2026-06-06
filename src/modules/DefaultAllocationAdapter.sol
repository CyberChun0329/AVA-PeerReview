// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";
import {IAVAAllocationModule} from "../interfaces/IAVAAllocationModule.sol";

contract DefaultAllocationAdapter is IAVAAllocationModule {
    function validateAllocation(
        AVADataTypes.Role,
        uint256,
        AVADataTypes.AllocationKind allocationKind,
        bytes32 subjectId,
        uint256 amountOrUnits,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata,
        address
    ) external pure {
        if (
            allocationKind == AVADataTypes.AllocationKind.None || subjectId == bytes32(0) || amountOrUnits == 0
                || evidenceReceiptId == 0 || authorityId == bytes32(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
    }
}
