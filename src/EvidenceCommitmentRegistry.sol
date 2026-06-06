// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "./AVADataTypes.sol";
import {AuthorityMatrix} from "./AuthorityMatrix.sol";
import {AVARulePackageRegistry} from "./AVARulePackageRegistry.sol";
import {IDisclosurePolicyModule} from "./interfaces/IDisclosurePolicyModule.sol";

contract EvidenceCommitmentRegistry {
    AuthorityMatrix public immutable authorityMatrix;
    IDisclosurePolicyModule public immutable disclosurePolicyModule;
    AVARulePackageRegistry public immutable rulePackageRegistry;
    uint256 public nextEvidenceReceiptId = 1;
    uint256 public nextEvidenceLifecycleRecordId = 1;

    mapping(uint256 => AVADataTypes.EvidenceReceipt) private evidenceReceipts;
    mapping(uint256 => AVADataTypes.EvidenceLifecycleRecord) private evidenceLifecycleRecords;

    event EvidenceReceiptRegistered(
        uint256 indexed id,
        bytes32 indexed commitment,
        uint256 indexed disclosurePolicyId,
        string uri,
        string evidenceType,
        address registeredBy
    );
    event EvidenceLifecycleRecorded(
        uint256 indexed id,
        bytes32 indexed workflowKey,
        uint256 indexed evidenceReceiptId,
        AVADataTypes.EvidenceLifecycleKind kind
    );

    constructor(
        AuthorityMatrix authorityMatrix_,
        IDisclosurePolicyModule disclosurePolicyModule_,
        AVARulePackageRegistry rulePackageRegistry_
    ) {
        authorityMatrix = authorityMatrix_;
        disclosurePolicyModule = disclosurePolicyModule_;
        rulePackageRegistry = rulePackageRegistry_;
    }

    function registerEvidenceReceipt(
        AVADataTypes.Role actingRole,
        bytes32 commitment,
        string calldata uri,
        string calldata evidenceType,
        uint256 disclosurePolicyId
    ) external returns (uint256 id) {
        return _registerEvidenceReceipt(actingRole, bytes32(0), commitment, uri, evidenceType, disclosurePolicyId);
    }

    function registerEvidenceReceipt(
        AVADataTypes.Role actingRole,
        bytes32 workflowKey,
        bytes32 commitment,
        string calldata uri,
        string calldata evidenceType,
        uint256 disclosurePolicyId
    ) external returns (uint256 id) {
        return _registerEvidenceReceipt(actingRole, workflowKey, commitment, uri, evidenceType, disclosurePolicyId);
    }

    function _registerEvidenceReceipt(
        AVADataTypes.Role actingRole,
        bytes32 workflowKey,
        bytes32 commitment,
        string calldata uri,
        string calldata evidenceType,
        uint256 disclosurePolicyId
    ) internal returns (uint256 id) {
        bytes32 registeredSubjectId =
            authorityMatrix.requireAuthorisedCanonicalSubject(msg.sender, actingRole, AVADataTypes.Action.RegisterEvidence);
        if (commitment == bytes32(0)) revert AVADataTypes.EmptyValue();
        if (bytes(evidenceType).length == 0) revert AVADataTypes.EmptyValue();
        _requireDisclosurePolicyIfSpecified(disclosurePolicyId);
        bytes32 evidenceTypeHash = keccak256(bytes(evidenceType));
        uint256 packageId;
        if (workflowKey != bytes32(0)) {
            AVARulePackageRegistry.RulePackage memory rulePackage = rulePackageRegistry.getRulePackage(workflowKey);
            packageId = rulePackage.packageId;
            rulePackage.evidencePolicyModule.validateEvidencePolicy(
                workflowKey,
                actingRole,
                AVADataTypes.Action.RegisterEvidence,
                nextEvidenceReceiptId,
                evidenceTypeHash,
                msg.sender
            );
            rulePackage.evidenceLifecycleModule.validateEvidenceLifecycle(
                workflowKey,
                AVADataTypes.Action.RegisterEvidence,
                nextEvidenceReceiptId,
                AVADataTypes.EvidenceLifecycleKind.None,
                0,
                bytes32(0),
                msg.sender
            );
        }

        id = nextEvidenceReceiptId++;
        evidenceReceipts[id] = AVADataTypes.EvidenceReceipt({
            id: id,
            workflowKey: workflowKey,
            packageId: packageId,
            commitment: commitment,
            evidenceTypeHash: evidenceTypeHash,
            uri: uri,
            evidenceType: evidenceType,
            disclosurePolicyId: disclosurePolicyId,
            registeredRole: actingRole,
            registeredSubjectId: registeredSubjectId,
            registeredBy: msg.sender,
            status: AVADataTypes.EvidenceReceiptStatus.Active,
            lastLifecycleRecordId: 0,
            replacementEvidenceReceiptId: 0
        });

        emit EvidenceReceiptRegistered(id, commitment, disclosurePolicyId, uri, evidenceType, msg.sender);
    }

    function getEvidenceReceipt(uint256 id) external view returns (AVADataTypes.EvidenceReceipt memory) {
        AVADataTypes.EvidenceReceipt memory receipt = evidenceReceipts[id];
        if (receipt.id == 0) revert AVADataTypes.UnknownReference(id);
        return receipt;
    }

    function requireUsableEvidenceReceipt(uint256 id, bytes32 workflowKey)
        external
        view
        returns (AVADataTypes.EvidenceReceipt memory)
    {
        AVADataTypes.EvidenceReceipt memory receipt = evidenceReceipts[id];
        _requireUsableEvidenceReceipt(receipt, id, workflowKey);
        return receipt;
    }

    function recordEvidenceLifecycleHook(
        AVADataTypes.Role actingRole,
        bytes32 workflowKey,
        uint256 evidenceReceiptId,
        AVADataTypes.EvidenceLifecycleKind kind,
        uint256 replacementEvidenceReceiptId,
        bytes32 lifecycleReference,
        string calldata uri
    ) external returns (uint256 id) {
        bytes32 authorityId = authorityMatrix.requireAuthorisedCanonicalSubject(
            msg.sender, actingRole, AVADataTypes.Action.RecordEvidenceLifecycle
        );
        if (
            workflowKey == bytes32(0) || evidenceReceiptId == 0 || kind == AVADataTypes.EvidenceLifecycleKind.None
                || lifecycleReference == bytes32(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
        AVADataTypes.EvidenceReceipt memory receipt = evidenceReceipts[evidenceReceiptId];
        if (receipt.id == 0) {
            revert AVADataTypes.UnknownReference(evidenceReceiptId);
        }
        if (receipt.workflowKey != workflowKey || receipt.packageId == 0) {
            revert AVADataTypes.InvalidState(evidenceReceiptId);
        }
        if (receipt.status != AVADataTypes.EvidenceReceiptStatus.Active) {
            revert AVADataTypes.InvalidState(evidenceReceiptId);
        }
        AVADataTypes.EvidenceReceiptStatus toStatus = _statusForLifecycleKind(kind);
        if (kind == AVADataTypes.EvidenceLifecycleKind.ReplacementReady && replacementEvidenceReceiptId == 0) {
            revert AVADataTypes.EmptyValue();
        }
        if (kind != AVADataTypes.EvidenceLifecycleKind.ReplacementReady && replacementEvidenceReceiptId != 0) {
            revert AVADataTypes.InvalidState(replacementEvidenceReceiptId);
        }
        if (kind == AVADataTypes.EvidenceLifecycleKind.ReplacementReady) {
            _requireReplacementEvidence(receipt, replacementEvidenceReceiptId, workflowKey);
        }

        AVARulePackageRegistry.RulePackage memory rulePackage = rulePackageRegistry.getRulePackageById(receipt.packageId);
        if (rulePackage.workflowKey != workflowKey) revert AVADataTypes.InvalidState(receipt.packageId);
        rulePackage.evidenceLifecycleModule.validateEvidenceLifecycle(
            workflowKey,
            AVADataTypes.Action.RecordEvidenceLifecycle,
            evidenceReceiptId,
            kind,
            replacementEvidenceReceiptId,
            lifecycleReference,
            msg.sender
        );

        id = nextEvidenceLifecycleRecordId++;
        evidenceLifecycleRecords[id] = AVADataTypes.EvidenceLifecycleRecord({
            id: id,
            workflowKey: workflowKey,
            packageId: rulePackage.packageId,
            evidenceReceiptId: evidenceReceiptId,
            kind: kind,
            replacementEvidenceReceiptId: replacementEvidenceReceiptId,
            fromStatus: receipt.status,
            toStatus: toStatus,
            lifecycleReference: lifecycleReference,
            uri: uri,
            authorityRole: actingRole,
            authorityId: authorityId,
            recordedBy: msg.sender
        });

        AVADataTypes.EvidenceReceipt storage storedReceipt = evidenceReceipts[evidenceReceiptId];
        storedReceipt.status = toStatus;
        storedReceipt.lastLifecycleRecordId = id;
        storedReceipt.replacementEvidenceReceiptId = replacementEvidenceReceiptId;

        emit EvidenceLifecycleRecorded(id, workflowKey, evidenceReceiptId, kind);
    }

    function getEvidenceLifecycleRecord(uint256 id)
        external
        view
        returns (AVADataTypes.EvidenceLifecycleRecord memory)
    {
        AVADataTypes.EvidenceLifecycleRecord memory record = evidenceLifecycleRecords[id];
        if (record.id == 0) revert AVADataTypes.UnknownReference(id);
        return record;
    }

    function _requireDisclosurePolicyIfSpecified(uint256 disclosurePolicyId) internal view {
        disclosurePolicyModule.validateDisclosurePolicy(disclosurePolicyId);
    }

    function _requireUsableEvidenceReceipt(
        AVADataTypes.EvidenceReceipt memory receipt,
        uint256 id,
        bytes32 workflowKey
    ) internal pure {
        if (receipt.id == 0) revert AVADataTypes.UnknownReference(id);
        if (
            workflowKey == bytes32(0) || receipt.workflowKey != workflowKey || receipt.packageId == 0
                || receipt.status != AVADataTypes.EvidenceReceiptStatus.Active
        ) {
            revert AVADataTypes.InvalidState(id);
        }
    }

    function _statusForLifecycleKind(AVADataTypes.EvidenceLifecycleKind kind)
        internal
        pure
        returns (AVADataTypes.EvidenceReceiptStatus)
    {
        if (kind == AVADataTypes.EvidenceLifecycleKind.ExpiryReady) {
            return AVADataTypes.EvidenceReceiptStatus.Expired;
        }
        if (kind == AVADataTypes.EvidenceLifecycleKind.RevocationReady) {
            return AVADataTypes.EvidenceReceiptStatus.Revoked;
        }
        if (kind == AVADataTypes.EvidenceLifecycleKind.SupersessionReady) {
            return AVADataTypes.EvidenceReceiptStatus.Superseded;
        }
        if (kind == AVADataTypes.EvidenceLifecycleKind.ReplacementReady) {
            return AVADataTypes.EvidenceReceiptStatus.Replaced;
        }
        revert AVADataTypes.EmptyValue();
    }

    function _requireReplacementEvidence(
        AVADataTypes.EvidenceReceipt memory receipt,
        uint256 replacementEvidenceReceiptId,
        bytes32 workflowKey
    ) internal view {
        if (replacementEvidenceReceiptId == receipt.id) {
            revert AVADataTypes.InvalidState(replacementEvidenceReceiptId);
        }
        AVADataTypes.EvidenceReceipt memory replacement = evidenceReceipts[replacementEvidenceReceiptId];
        _requireUsableEvidenceReceipt(replacement, replacementEvidenceReceiptId, workflowKey);
        if (replacement.disclosurePolicyId != receipt.disclosurePolicyId) {
            revert AVADataTypes.InvalidState(replacementEvidenceReceiptId);
        }
    }
}
