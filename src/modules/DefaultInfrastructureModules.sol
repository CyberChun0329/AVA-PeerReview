// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";
import {IEvidencePolicyModule} from "../interfaces/IEvidencePolicyModule.sol";
import {IAuditAdapter} from "../interfaces/IAuditAdapter.sol";
import {IEditorialSystemAdapter} from "../interfaces/IEditorialSystemAdapter.sol";
import {IResidualEditorialAuthorityModule} from "../interfaces/IResidualEditorialAuthorityModule.sol";
import {IFieldPolicyModule} from "../interfaces/IFieldPolicyModule.sol";
import {IAntiAbuseModule} from "../interfaces/IAntiAbuseModule.sol";

contract DefaultEvidencePolicyModule is IEvidencePolicyModule {
    function validateEvidencePolicy(
        bytes32 workflowKey,
        AVADataTypes.Role,
        AVADataTypes.Action,
        uint256 evidenceReceiptId,
        bytes32 evidenceTypeHash,
        address
    ) external pure {
        evidenceTypeHash;
        if (workflowKey == bytes32(0) || evidenceReceiptId == 0) {
            revert AVADataTypes.EmptyValue();
        }
    }
}

contract DefaultAuditAdapter is IAuditAdapter {
    function validateAuditRecord(
        bytes32 workflowKey,
        AVADataTypes.Role,
        AVADataTypes.Action,
        bytes32 objectId,
        uint256 evidenceReceiptId,
        bytes32 attestationHash,
        address
    ) external pure {
        if (workflowKey == bytes32(0) || objectId == bytes32(0) || evidenceReceiptId == 0 || attestationHash == bytes32(0)) {
            revert AVADataTypes.EmptyValue();
        }
    }
}

contract DefaultEditorialSystemAdapter is IEditorialSystemAdapter {
    function validateEditorialReference(
        bytes32 workflowKey,
        AVADataTypes.Role,
        AVADataTypes.Action,
        bytes32 objectId,
        string calldata externalReferenceURI,
        address
    ) external pure {
        if (workflowKey == bytes32(0) || objectId == bytes32(0) || bytes(externalReferenceURI).length == 0) {
            revert AVADataTypes.EmptyValue();
        }
    }
}

contract DefaultResidualEditorialAuthorityModule is IResidualEditorialAuthorityModule {
    function validateResidualEditorialAuthority(ResidualEditorialAuthorityContext calldata context) external pure {
        if (
            context.workflowKey == bytes32(0) || context.objectId == bytes32(0) || context.evidenceReceiptId == 0
                || context.authorityId == bytes32(0) || context.actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
        if (context.actingRole != AVADataTypes.Role.Editor && context.actingRole != AVADataTypes.Role.Panel) {
            revert AVADataTypes.InvalidRole();
        }
    }
}

contract DefaultFieldPolicyModule is IFieldPolicyModule {
    function validateFieldPolicy(
        bytes32 workflowKey,
        AVADataTypes.Role,
        AVADataTypes.Action,
        AVADataTypes.AVAStage,
        bytes32 objectId,
        uint256 evidenceReceiptId
    ) external pure {
        if (workflowKey == bytes32(0) || objectId == bytes32(0) || evidenceReceiptId == 0) {
            revert AVADataTypes.EmptyValue();
        }
    }
}

contract DefaultAntiAbuseModule is IAntiAbuseModule {
    function validateUse(
        bytes32 workflowKey,
        AVADataTypes.Role,
        AVADataTypes.Action,
        bytes32 subjectId,
        bytes32 objectId,
        address actor
    ) external pure {
        if (workflowKey == bytes32(0) || subjectId == bytes32(0) || objectId == bytes32(0) || actor == address(0)) {
            revert AVADataTypes.EmptyValue();
        }
    }
}
