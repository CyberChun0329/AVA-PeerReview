// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";
import {IConsequenceAdapter} from "../interfaces/IConsequenceAdapter.sol";

contract DefaultConsequenceAdapter is IConsequenceAdapter {
    function validateConsequence(
        AVADataTypes.Role,
        uint256,
        AVADataTypes.ConsequenceKind kind,
        bytes32 subjectId,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata,
        address
    ) external pure {
        if (
            kind == AVADataTypes.ConsequenceKind.None || subjectId == bytes32(0) || evidenceReceiptId == 0
                || authorityId == bytes32(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
    }
}
