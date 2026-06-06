// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";
import {IStandingAdapter} from "../interfaces/IStandingAdapter.sol";
import {IRewardAdapter} from "../interfaces/IRewardAdapter.sol";
import {IPriorityAdapter} from "../interfaces/IPriorityAdapter.sol";
import {IPenaltyAdapter} from "../interfaces/IPenaltyAdapter.sol";
import {IRestorationAdapter} from "../interfaces/IRestorationAdapter.sol";
import {IConsequenceAdapter} from "../interfaces/IConsequenceAdapter.sol";

contract VectorStandingAdapter is IStandingAdapter {
    function validateStandingUpdate(
        AVADataTypes.Role,
        uint256 recognisedStateId,
        bytes32 subjectId,
        string calldata dimension,
        int256,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata,
        address actor
    ) external pure {
        if (
            recognisedStateId == 0 || subjectId == bytes32(0) || bytes(dimension).length == 0
                || evidenceReceiptId == 0 || authorityId == bytes32(0) || actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
        if (keccak256(bytes(dimension)) == keccak256("public-prestige")) {
            revert AVADataTypes.InvalidState(recognisedStateId);
        }
    }
}

contract StablecoinRecordRewardAdapter is IRewardAdapter {
    function validateRewardRecord(
        AVADataTypes.Role,
        uint256 recognisedStateId,
        bytes32 subjectId,
        uint256 amountOrUnits,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri,
        address actor
    ) external pure {
        _requireRecordFields(recognisedStateId, subjectId, amountOrUnits, evidenceReceiptId, authorityId, uri, actor);
        if (keccak256(bytes(uri)) == keccak256("transfer")) revert AVADataTypes.InvalidState(recognisedStateId);
    }

    function _requireRecordFields(
        uint256 recognisedStateId,
        bytes32 subjectId,
        uint256 amountOrUnits,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri,
        address actor
    ) internal pure {
        if (
            recognisedStateId == 0 || subjectId == bytes32(0) || amountOrUnits == 0 || evidenceReceiptId == 0
                || authorityId == bytes32(0) || bytes(uri).length == 0 || actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
    }
}

contract GenericTokenRecordRewardAdapter is IRewardAdapter {
    function validateRewardRecord(
        AVADataTypes.Role,
        uint256 recognisedStateId,
        bytes32 subjectId,
        uint256 amountOrUnits,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri,
        address actor
    ) external pure {
        if (
            recognisedStateId == 0 || subjectId == bytes32(0) || amountOrUnits == 0 || evidenceReceiptId == 0
                || authorityId == bytes32(0) || bytes(uri).length == 0 || actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
    }
}

contract PriorityTokenRecordAdapter is IPriorityAdapter {
    function validatePriorityRecord(
        AVADataTypes.Role,
        uint256 recognisedStateId,
        bytes32 subjectId,
        uint256 amountOrUnits,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri,
        address actor
    ) external pure {
        if (
            recognisedStateId == 0 || subjectId == bytes32(0) || amountOrUnits == 0 || evidenceReceiptId == 0
                || authorityId == bytes32(0) || bytes(uri).length == 0 || actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
        if (keccak256(bytes(uri)) == keccak256("publication-priority")) {
            revert AVADataTypes.InvalidState(recognisedStateId);
        }
    }
}

contract RentedPriorityRecordAdapter is IPriorityAdapter {
    function validatePriorityRecord(
        AVADataTypes.Role,
        uint256 recognisedStateId,
        bytes32 subjectId,
        uint256 amountOrUnits,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri,
        address actor
    ) external pure {
        if (
            recognisedStateId == 0 || subjectId == bytes32(0) || amountOrUnits == 0 || evidenceReceiptId == 0
                || authorityId == bytes32(0) || bytes(uri).length == 0 || actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
    }
}

contract ProceduralPenaltyRecordAdapter is IPenaltyAdapter {
    function validatePenaltyRecord(
        AVADataTypes.Role,
        uint256 recognisedStateId,
        bytes32 subjectId,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri,
        address actor
    ) external pure {
        if (
            recognisedStateId == 0 || subjectId == bytes32(0) || evidenceReceiptId == 0 || authorityId == bytes32(0)
                || bytes(uri).length == 0 || actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
    }
}

contract PriorityReturnObligationRecordAdapter is IPenaltyAdapter {
    function validatePenaltyRecord(
        AVADataTypes.Role,
        uint256 recognisedStateId,
        bytes32 subjectId,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri,
        address actor
    ) external pure {
        if (
            recognisedStateId == 0 || subjectId == bytes32(0) || evidenceReceiptId == 0 || authorityId == bytes32(0)
                || bytes(uri).length == 0 || actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
    }
}

contract RestorationProcedureRecordAdapter is IRestorationAdapter {
    function validateRestorationRecord(
        AVADataTypes.Role,
        uint256 recognisedStateId,
        bytes32 subjectId,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri,
        address actor
    ) external pure {
        if (
            recognisedStateId == 0 || subjectId == bytes32(0) || evidenceReceiptId == 0 || authorityId == bytes32(0)
                || bytes(uri).length == 0 || actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
    }
}

contract CorrectionRestorationRecordAdapter is IRestorationAdapter {
    function validateRestorationRecord(
        AVADataTypes.Role,
        uint256 recognisedStateId,
        bytes32 subjectId,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri,
        address actor
    ) external pure {
        if (
            recognisedStateId == 0 || subjectId == bytes32(0) || evidenceReceiptId == 0 || authorityId == bytes32(0)
                || bytes(uri).length == 0 || actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
    }
}

contract BoundedConsequenceExampleAdapter is IConsequenceAdapter {
    function validateConsequence(
        AVADataTypes.Role,
        uint256 recognisedStateId,
        AVADataTypes.ConsequenceKind kind,
        bytes32 subjectId,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri,
        address actor
    ) external pure {
        if (
            recognisedStateId == 0 || kind == AVADataTypes.ConsequenceKind.None || subjectId == bytes32(0)
                || evidenceReceiptId == 0 || authorityId == bytes32(0) || bytes(uri).length == 0
                || actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
    }
}
