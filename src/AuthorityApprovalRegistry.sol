// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "./AVADataTypes.sol";
import {AuthorityMatrix} from "./AuthorityMatrix.sol";
import {AVARulePackageRegistry} from "./AVARulePackageRegistry.sol";
import {EvidenceCommitmentRegistry} from "./EvidenceCommitmentRegistry.sol";

contract AuthorityApprovalRegistry {
    struct ApprovalReceipt {
        uint256 id;
        bytes32 workflowKey;
        uint256 packageId;
        AVADataTypes.Action action;
        uint256 recognisedStateId;
        bytes32 objectId;
        AVADataTypes.Role authorityRole;
        bytes32 authorityId;
        uint256 evidenceReceiptId;
        uint64 expiresAt;
        string reasonURI;
        address approvedBy;
    }

    struct ApprovalInput {
        bytes32 workflowKey;
        uint256 packageId;
        AVADataTypes.Action action;
        uint256 recognisedStateId;
        bytes32 objectId;
        bytes32 authorityId;
        uint256 evidenceReceiptId;
        uint64 expiresAt;
        string reasonURI;
    }

    AuthorityMatrix public immutable AUTHORITY_MATRIX;
    AVARulePackageRegistry public immutable RULE_PACKAGE_REGISTRY;
    EvidenceCommitmentRegistry public immutable EVIDENCE_REGISTRY;
    uint256 public nextApprovalReceiptId = 1;

    mapping(uint256 => ApprovalReceipt) private approvalReceipts;
    mapping(bytes32 => bytes32[]) private approvalAuthoritiesByContext;
    mapping(bytes32 => mapping(bytes32 => uint256)) private approvalReceiptByContextAndAuthority;

    event AuthorityApprovalRecorded(
        uint256 indexed id,
        bytes32 indexed workflowKey,
        uint256 indexed packageId,
        AVADataTypes.Action action,
        uint256 recognisedStateId,
        bytes32 objectId,
        bytes32 authorityId,
        uint64 expiresAt
    );

    constructor(
        AuthorityMatrix authorityMatrix_,
        AVARulePackageRegistry rulePackageRegistry_,
        EvidenceCommitmentRegistry evidenceRegistry_
    ) {
        AUTHORITY_MATRIX = authorityMatrix_;
        RULE_PACKAGE_REGISTRY = rulePackageRegistry_;
        EVIDENCE_REGISTRY = evidenceRegistry_;
    }

    function recordApproval(
        AVADataTypes.Role actingRole,
        ApprovalInput calldata input
    ) external returns (uint256 id) {
        AUTHORITY_MATRIX.requireAuthorisedSubject(msg.sender, actingRole, input.action, input.authorityId);
        if (
            input.workflowKey == bytes32(0) || input.packageId == 0 || input.recognisedStateId == 0
                || input.objectId == bytes32(0) || input.authorityId == bytes32(0) || input.evidenceReceiptId == 0
                || input.expiresAt <= block.timestamp
        ) {
            revert AVADataTypes.EmptyValue();
        }

        AVARulePackageRegistry.RulePackage memory rulePackage = RULE_PACKAGE_REGISTRY.getRulePackageById(input.packageId);
        if (rulePackage.workflowKey != input.workflowKey) revert AVADataTypes.InvalidState(input.packageId);
        AVADataTypes.EvidenceReceipt memory evidenceReceipt = EVIDENCE_REGISTRY.getEvidenceReceipt(input.evidenceReceiptId);
        if (evidenceReceipt.workflowKey != input.workflowKey || evidenceReceipt.packageId != input.packageId) {
            revert AVADataTypes.InvalidState(input.evidenceReceiptId);
        }
        if (evidenceReceipt.status != AVADataTypes.EvidenceReceiptStatus.Active) {
            revert AVADataTypes.InvalidState(input.evidenceReceiptId);
        }

        bytes32 approvalKey =
            computeApprovalKey(input.workflowKey, input.packageId, input.action, input.recognisedStateId, input.objectId);
        if (approvalReceiptByContextAndAuthority[approvalKey][input.authorityId] != 0) {
            revert AVADataTypes.InvalidState(uint256(input.authorityId));
        }

        id = nextApprovalReceiptId++;
        approvalReceipts[id] = ApprovalReceipt({
            id: id,
            workflowKey: input.workflowKey,
            packageId: input.packageId,
            action: input.action,
            recognisedStateId: input.recognisedStateId,
            objectId: input.objectId,
            authorityRole: actingRole,
            authorityId: input.authorityId,
            evidenceReceiptId: input.evidenceReceiptId,
            expiresAt: input.expiresAt,
            reasonURI: input.reasonURI,
            approvedBy: msg.sender
        });
        approvalReceiptByContextAndAuthority[approvalKey][input.authorityId] = id;
        approvalAuthoritiesByContext[approvalKey].push(input.authorityId);

        emit AuthorityApprovalRecorded(
            id,
            input.workflowKey,
            input.packageId,
            input.action,
            input.recognisedStateId,
            input.objectId,
            input.authorityId,
            input.expiresAt
        );
    }

    function getApprovalReceipt(uint256 id) external view returns (ApprovalReceipt memory) {
        ApprovalReceipt memory receipt = approvalReceipts[id];
        if (receipt.id == 0) revert AVADataTypes.UnknownReference(id);
        return receipt;
    }

    function approvalCount(
        bytes32 workflowKey,
        uint256 packageId,
        AVADataTypes.Action action,
        uint256 recognisedStateId,
        bytes32 objectId
    ) external view returns (uint256) {
        bytes32 approvalKey = computeApprovalKey(workflowKey, packageId, action, recognisedStateId, objectId);
        bytes32[] storage authorities = approvalAuthoritiesByContext[approvalKey];
        uint256 count;
        for (uint256 i = 0; i < authorities.length; i++) {
            uint256 approvalId = approvalReceiptByContextAndAuthority[approvalKey][authorities[i]];
            if (approvalReceipts[approvalId].expiresAt > block.timestamp) {
                count++;
            }
        }
        return count;
    }

    function hasActiveApproval(
        bytes32 workflowKey,
        uint256 packageId,
        AVADataTypes.Action action,
        uint256 recognisedStateId,
        bytes32 objectId,
        bytes32 authorityId
    ) external view returns (bool) {
        uint256 approvalId = approvalReceiptByContextAndAuthority[
            computeApprovalKey(workflowKey, packageId, action, recognisedStateId, objectId)
        ][authorityId];
        if (approvalId == 0) return false;
        return approvalReceipts[approvalId].expiresAt > block.timestamp;
    }

    function computeApprovalKey(
        bytes32 workflowKey,
        uint256 packageId,
        AVADataTypes.Action action,
        uint256 recognisedStateId,
        bytes32 objectId
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(workflowKey, packageId, action, recognisedStateId, objectId));
    }
}
