// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RuleModuleIdentity} from "../interfaces/IRuleModuleIdentity.sol";

import {AVADataTypes} from "../AVADataTypes.sol";
import {IStandingAdapter} from "../interfaces/IStandingAdapter.sol";

contract DefaultStandingAdapter is IStandingAdapter, RuleModuleIdentity {
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
        bytes32 dimensionHash = keccak256(bytes(dimension));
        if (dimensionHash == keccak256("public-prestige") || dimensionHash == keccak256("single-score")) {
            revert AVADataTypes.InvalidState(0);
        }
    }
}
