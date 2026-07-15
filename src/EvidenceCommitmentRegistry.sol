// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "./AVADataTypes.sol";
import {AuthorityMatrix} from "./AuthorityMatrix.sol";
import {AVARulePackageRegistry} from "./AVARulePackageRegistry.sol";
import {DisclosurePolicyRegistry} from "./DisclosurePolicyRegistry.sol";
import {IDisclosurePolicyModule} from "./interfaces/IDisclosurePolicyModule.sol";

contract EvidenceCommitmentRegistry {
    struct EvidenceRegistrationInput {
        AVADataTypes.Role actingRole;
        bytes32 appId;
        bytes32 workflowKey;
        bytes32 commitment;
        string uri;
        string evidenceType;
        uint256 disclosurePolicyId;
    }

    AuthorityMatrix public immutable authorityMatrix;
    IDisclosurePolicyModule public immutable disclosurePolicyModule;
    DisclosurePolicyRegistry public immutable disclosureRegistry;
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
        DisclosurePolicyRegistry disclosureRegistry_,
        AVARulePackageRegistry rulePackageRegistry_
    ) {
        if (address(disclosureRegistry_) == address(0)) {
            revert AVADataTypes.EmptyValue();
        }
        authorityMatrix = authorityMatrix_;
        disclosurePolicyModule = disclosurePolicyModule_;
        disclosureRegistry = disclosureRegistry_;
        rulePackageRegistry = rulePackageRegistry_;
    }

    function registerEvidenceReceipt(
        AVADataTypes.Role actingRole,
        bytes32 commitment,
        string calldata uri,
        string calldata evidenceType,
        uint256 disclosurePolicyId
    ) external returns (uint256 id) {
        return _registerEvidenceReceipt(
            EvidenceRegistrationInput({
                actingRole: actingRole,
                appId: bytes32(0),
                workflowKey: bytes32(0),
                commitment: commitment,
                uri: uri,
                evidenceType: evidenceType,
                disclosurePolicyId: disclosurePolicyId
            })
        );
    }

    function registerEvidenceReceipt(
        AVADataTypes.Role actingRole,
        bytes32 appId,
        bytes32 workflowKey,
        bytes32 commitment,
        string calldata uri,
        string calldata evidenceType,
        uint256 disclosurePolicyId
    ) external returns (uint256 id) {
        return _registerEvidenceReceipt(
            EvidenceRegistrationInput({
                actingRole: actingRole,
                appId: appId,
                workflowKey: workflowKey,
                commitment: commitment,
                uri: uri,
                evidenceType: evidenceType,
                disclosurePolicyId: disclosurePolicyId
            })
        );
    }

    function _registerEvidenceReceipt(EvidenceRegistrationInput memory input) internal returns (uint256 id) {
        bytes32 registeredSubjectId = authorityMatrix.requireAuthorisedCanonicalSubject(
            msg.sender, input.actingRole, AVADataTypes.Action.RegisterEvidence
        );
        if (input.commitment == bytes32(0) || bytes(input.evidenceType).length == 0) {
            revert AVADataTypes.EmptyValue();
        }
        _requireDisclosurePolicyIfSpecified(input.appId, input.disclosurePolicyId);
        bytes32 evidenceTypeHash = keccak256(bytes(input.evidenceType));
        uint256 packageId;
        if (input.workflowKey != bytes32(0)) {
            if (input.appId == bytes32(0)) revert AVADataTypes.EmptyValue();
            AVARulePackageRegistry.RulePackage memory rulePackage =
                rulePackageRegistry.getRulePackage(input.appId, input.workflowKey);
            packageId = rulePackage.packageId;
            rulePackage.evidencePolicyModule
                .validateEvidencePolicy(
                    input.workflowKey,
                    input.actingRole,
                    AVADataTypes.Action.RegisterEvidence,
                    nextEvidenceReceiptId,
                    evidenceTypeHash,
                    msg.sender
                );
            rulePackage.evidenceLifecycleModule
                .validateEvidenceLifecycle(
                    input.workflowKey,
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
            appId: input.appId,
            workflowKey: input.workflowKey,
            packageId: packageId,
            commitment: input.commitment,
            evidenceTypeHash: evidenceTypeHash,
            uri: input.uri,
            evidenceType: input.evidenceType,
            disclosurePolicyId: input.disclosurePolicyId,
            registeredRole: input.actingRole,
            registeredSubjectId: registeredSubjectId,
            registeredBy: msg.sender,
            status: AVADataTypes.EvidenceReceiptStatus.Active,
            lastLifecycleRecordId: 0,
            replacementEvidenceReceiptId: 0
        });

        emit EvidenceReceiptRegistered(
            id, input.commitment, input.disclosurePolicyId, input.uri, input.evidenceType, msg.sender
        );
    }

    function getEvidenceReceipt(uint256 id) external view returns (AVADataTypes.EvidenceReceipt memory) {
        AVADataTypes.EvidenceReceipt memory receipt = evidenceReceipts[id];
        if (receipt.id == 0) revert AVADataTypes.UnknownReference(id);
        return receipt;
    }

    function requireUsableEvidenceReceipt(uint256 id, bytes32 appId, bytes32 workflowKey)
        external
        view
        returns (AVADataTypes.EvidenceReceipt memory)
    {
        AVADataTypes.EvidenceReceipt memory receipt = evidenceReceipts[id];
        _requireUsableEvidenceReceipt(receipt, id, appId, workflowKey);
        return receipt;
    }

    function requireUsableEvidenceReceiptForPackage(uint256 id, uint256 packageId)
        external
        view
        returns (AVADataTypes.EvidenceReceipt memory)
    {
        AVADataTypes.EvidenceReceipt memory receipt = evidenceReceipts[id];
        if (receipt.id == 0) revert AVADataTypes.UnknownReference(id);
        if (
            packageId == 0 || receipt.packageId != packageId
                || receipt.status != AVADataTypes.EvidenceReceiptStatus.Active
        ) {
            revert AVADataTypes.InvalidState(id);
        }
        return receipt;
    }

    function requireUsableEvidenceReferenceForPackage(uint256 id, uint256 packageId)
        external
        view
        returns (
            bytes32 appId,
            bytes32 workflowKey,
            uint256 receiptPackageId,
            bytes32 registeredSubjectId,
            uint256 disclosurePolicyId
        )
    {
        AVADataTypes.EvidenceReceipt memory receipt = evidenceReceipts[id];
        if (receipt.id == 0) revert AVADataTypes.UnknownReference(id);
        if (
            packageId == 0 || receipt.packageId != packageId
                || receipt.status != AVADataTypes.EvidenceReceiptStatus.Active
        ) {
            revert AVADataTypes.InvalidState(id);
        }
        return (
            receipt.appId,
            receipt.workflowKey,
            receipt.packageId,
            receipt.registeredSubjectId,
            receipt.disclosurePolicyId
        );
    }

    function requireEvidenceReferenceForPackage(uint256 id, uint256 packageId)
        external
        view
        returns (
            bytes32 appId,
            bytes32 workflowKey,
            uint256 receiptPackageId,
            bytes32 registeredSubjectId,
            uint256 disclosurePolicyId
        )
    {
        AVADataTypes.EvidenceReceipt memory receipt = evidenceReceipts[id];
        if (receipt.id == 0) revert AVADataTypes.UnknownReference(id);
        if (packageId == 0 || receipt.packageId != packageId) revert AVADataTypes.InvalidState(id);
        return (
            receipt.appId,
            receipt.workflowKey,
            receipt.packageId,
            receipt.registeredSubjectId,
            receipt.disclosurePolicyId
        );
    }

    function recordEvidenceLifecycleHook(
        AVADataTypes.Role actingRole,
        bytes32 appId,
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
            appId == bytes32(0) || workflowKey == bytes32(0) || evidenceReceiptId == 0
                || kind == AVADataTypes.EvidenceLifecycleKind.None || lifecycleReference == bytes32(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
        AVADataTypes.EvidenceReceipt memory receipt = evidenceReceipts[evidenceReceiptId];
        if (receipt.id == 0) {
            revert AVADataTypes.UnknownReference(evidenceReceiptId);
        }
        if (receipt.appId != appId || receipt.workflowKey != workflowKey || receipt.packageId == 0) {
            revert AVADataTypes.InvalidState(evidenceReceiptId);
        }
        if (receipt.status != AVADataTypes.EvidenceReceiptStatus.Active) {
            revert AVADataTypes.InvalidState(evidenceReceiptId);
        }
        _requireEvidenceLifecycleAuthority(receipt, actingRole, authorityId);
        AVADataTypes.EvidenceReceiptStatus toStatus = _statusForLifecycleKind(kind);
        if (kind == AVADataTypes.EvidenceLifecycleKind.ReplacementReady && replacementEvidenceReceiptId == 0) {
            revert AVADataTypes.EmptyValue();
        }
        if (kind != AVADataTypes.EvidenceLifecycleKind.ReplacementReady && replacementEvidenceReceiptId != 0) {
            revert AVADataTypes.InvalidState(replacementEvidenceReceiptId);
        }
        if (kind == AVADataTypes.EvidenceLifecycleKind.ReplacementReady) {
            _requireReplacementEvidence(receipt, replacementEvidenceReceiptId, appId, workflowKey);
        }

        AVARulePackageRegistry.RulePackage memory rulePackage =
            rulePackageRegistry.getRulePackageById(receipt.packageId);
        if (rulePackage.appId != appId || rulePackage.workflowKey != workflowKey) {
            revert AVADataTypes.InvalidState(receipt.packageId);
        }
        rulePackage.evidenceLifecycleModule
            .validateEvidenceLifecycle(
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

    function _requireDisclosurePolicyIfSpecified(bytes32 appId, uint256 disclosurePolicyId) internal view {
        disclosurePolicyModule.validateDisclosurePolicy(disclosurePolicyId);
        if (disclosurePolicyId != 0 && disclosureRegistry.getDisclosurePolicy(disclosurePolicyId).appId != appId) {
            revert AVADataTypes.InvalidState(disclosurePolicyId);
        }
    }

    function _requireUsableEvidenceReceipt(
        AVADataTypes.EvidenceReceipt memory receipt,
        uint256 id,
        bytes32 appId,
        bytes32 workflowKey
    ) internal pure {
        if (receipt.id == 0) revert AVADataTypes.UnknownReference(id);
        if (
            appId == bytes32(0) || workflowKey == bytes32(0) || receipt.appId != appId
                || receipt.workflowKey != workflowKey || receipt.packageId == 0
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
        bytes32 appId,
        bytes32 workflowKey
    ) internal view {
        if (replacementEvidenceReceiptId == receipt.id) {
            revert AVADataTypes.InvalidState(replacementEvidenceReceiptId);
        }
        AVADataTypes.EvidenceReceipt memory replacement = evidenceReceipts[replacementEvidenceReceiptId];
        _requireUsableEvidenceReceipt(replacement, replacementEvidenceReceiptId, appId, workflowKey);
        if (
            replacement.packageId != receipt.packageId || replacement.registeredSubjectId != receipt.registeredSubjectId
                || replacement.disclosurePolicyId != receipt.disclosurePolicyId
        ) {
            revert AVADataTypes.InvalidState(replacementEvidenceReceiptId);
        }
    }

    function _requireEvidenceLifecycleAuthority(
        AVADataTypes.EvidenceReceipt memory receipt,
        AVADataTypes.Role actingRole,
        bytes32 authorityId
    ) internal view {
        bool selfManaged = authorityId == receipt.registeredSubjectId;
        bool crossSubjectAuthority =
            actingRole == AVADataTypes.Role.Panel || actingRole == AVADataTypes.Role.Institution;
        if (!selfManaged && !crossSubjectAuthority) {
            revert AVADataTypes.NotAuthorised(msg.sender, AVADataTypes.Action.RecordEvidenceLifecycle);
        }
    }
}
