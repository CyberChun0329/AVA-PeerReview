// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVAAuthorityMatrix} from "../../core/AVAAuthorityMatrix.sol";
import {AVACapabilityKeys} from "../../core/AVACapabilityKeys.sol";
import {AVACoreRulePackageRegistry} from "../../core/AVACoreRulePackageRegistry.sol";
import {AVACoreTypes} from "../../core/AVACoreTypes.sol";
import {AVADisclosurePolicyRegistry} from "../../core/AVADisclosurePolicyRegistry.sol";
import {AVAEvidenceRegistry} from "../../core/AVAEvidenceRegistry.sol";
import {AVAGovernanceKernel} from "../../core/AVAGovernanceKernel.sol";
import {AVAIdentityRegistry} from "../../core/AVAIdentityRegistry.sol";
import {AVAPrivacyProofExtension} from "./AVAPrivacyProofExtension.sol";
import {AVAExtensionRecordBase} from "../shared/AVAExtensionRecordBase.sol";

contract AVADisclosureReceiptExtension is AVAExtensionRecordBase {
    enum DisclosureReceiptKind {
        None,
        AccessGrant,
        AccessRevoke,
        VoluntaryIntent,
        AnonymousProofUse,
        AccessExpire,
        AccessSupersede
    }

    struct DisclosureInput {
        uint256 recognisedStateId;
        bytes32 roleKey;
        bytes32 authorityId;
        bytes32 subjectId;
        uint256 evidenceId;
        DisclosureReceiptKind kind;
        bytes32 scopeKey;
        uint256 proofReceiptId;
        uint256 relatedReceiptId;
        uint64 expiresAt;
        bytes32 reasonHash;
        string uri;
    }

    struct DisclosureReceipt {
        uint256 id;
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        uint256 recognisedStateId;
        uint256 recognisedStateTransitionId;
        bytes32 targetSubjectId;
        bytes32 subjectId;
        uint256 evidenceId;
        uint256 disclosurePolicyId;
        DisclosureReceiptKind kind;
        bytes32 scopeKey;
        uint256 proofReceiptId;
        uint256 relatedReceiptId;
        uint256 closedByReceiptId;
        uint64 expiresAt;
        bytes32 reasonHash;
        string uri;
        bytes32 authorityId;
        address recordedBy;
        uint64 recordedAt;
    }

    bytes32 public constant DISCLOSURE_CONTEXT_DOMAIN = keccak256("ava.extension.disclosure-receipt.context.v1");
    AVAPrivacyProofExtension public immutable PROOF_REGISTRY;

    mapping(uint256 => DisclosureReceipt) private receipts;
    mapping(bytes32 => uint256) public activeGrantIdByScope;
    mapping(uint256 => uint256) public proofUseReceiptIdByProofReceipt;
    uint256 public nextDisclosureReceiptId = 1;

    event DisclosureReceiptRecorded(
        uint256 indexed receiptId,
        bytes32 indexed appId,
        bytes32 indexed subjectId,
        uint256 packageId,
        uint256 recognisedStateId,
        DisclosureReceiptKind kind,
        bytes32 scopeKey,
        uint256 sourceReceiptId,
        address recordedBy
    );

    constructor(
        AVAGovernanceKernel governanceKernel_,
        AVAAuthorityMatrix authorityMatrix_,
        AVAIdentityRegistry identityRegistry_,
        AVACoreRulePackageRegistry rulePackageRegistry_,
        AVAEvidenceRegistry evidenceRegistry_,
        AVADisclosurePolicyRegistry disclosureRegistry_,
        AVAPrivacyProofExtension proofRegistry_
    )
        AVAExtensionRecordBase(
            governanceKernel_,
            authorityMatrix_,
            identityRegistry_,
            rulePackageRegistry_,
            evidenceRegistry_,
            disclosureRegistry_
        )
    {
        if (address(proofRegistry_) == address(0) || address(proofRegistry_).code.length == 0) {
            revert AVACoreTypes.EmptyValue();
        }
        if (address(proofRegistry_.GOVERNANCE_KERNEL()) != address(governanceKernel_)) {
            revert AVACoreTypes.InvalidState(0);
        }
        PROOF_REGISTRY = proofRegistry_;
    }

    function recordDisclosure(DisclosureInput calldata input) external returns (uint256 receiptId) {
        if (input.kind == DisclosureReceiptKind.None || input.scopeKey == bytes32(0) || input.reasonHash == bytes32(0)) revert AVACoreTypes.EmptyValue();
        AVAGovernanceKernel.RecognisedStateReference memory state =
            GOVERNANCE_KERNEL.getRecognisedStateReference(input.recognisedStateId);
        _requireKindShape(input, state);
        uint256 sourceReceiptId =
            input.kind == DisclosureReceiptKind.AnonymousProofUse ? input.proofReceiptId : input.relatedReceiptId;
        bytes32 contextHash = _contextHash(input, state, sourceReceiptId);
        _validateExtensionForRelatedSubjectWithState(
            ExtensionValidationInput({
                recognisedStateId: input.recognisedStateId,
                roleKey: input.roleKey,
                authorityId: input.authorityId,
                subjectId: input.subjectId,
                evidenceId: input.evidenceId,
                capabilityKey: AVACapabilityKeys.DISCLOSURE_RECEIPT,
                actionKey: AVACoreTypes.ACTION_RECORD_DISCLOSURE_RECEIPT,
                recordTypeKey: _recordTypeKey(input.kind),
                scopeKey: input.scopeKey,
                sourceTypeKey: input.kind == DisclosureReceiptKind.AnonymousProofUse
                    ? PROOF_REGISTRY.PROOF_RECORD_TYPE()
                    : bytes32(0),
                sourceRecordId: sourceReceiptId,
                unsignedValue: 0,
                validUntil: input.expiresAt,
                payloadHash: input.reasonHash,
                requireActiveSubject: true,
                contextHash: contextHash
            }),
            state
        );

        receiptId = nextDisclosureReceiptId++;
        receipts[receiptId] = DisclosureReceipt({
            id: receiptId,
            appId: state.appId,
            workflowKey: state.workflowKey,
            packageId: state.packageId,
            recognisedStateId: state.id,
            recognisedStateTransitionId: state.lastTransitionId,
            targetSubjectId: state.subjectId,
            subjectId: input.subjectId,
            evidenceId: input.evidenceId,
            disclosurePolicyId: state.disclosurePolicyId,
            kind: input.kind,
            scopeKey: input.scopeKey,
            proofReceiptId: input.proofReceiptId,
            relatedReceiptId: input.relatedReceiptId,
            closedByReceiptId: 0,
            expiresAt: input.expiresAt,
            reasonHash: input.reasonHash,
            uri: input.uri,
            authorityId: input.authorityId,
            recordedBy: msg.sender,
            recordedAt: uint64(block.timestamp)
        });
        _applyLifecycle(input, state, receiptId);
        emit DisclosureReceiptRecorded(
            receiptId,
            state.appId,
            input.subjectId,
            state.packageId,
            state.id,
            input.kind,
            input.scopeKey,
            sourceReceiptId,
            msg.sender
        );
    }

    function getDisclosureReceipt(uint256 receiptId) external view returns (DisclosureReceipt memory receipt) {
        receipt = receipts[receiptId];
        if (receipt.id == 0) revert AVACoreTypes.UnknownReference(receiptId);
    }

    function isAccessGrantActive(uint256 receiptId) external view returns (bool) {
        DisclosureReceipt storage receipt = receipts[receiptId];
        if (
            receipt.id == 0 || receipt.kind != DisclosureReceiptKind.AccessGrant || receipt.closedByReceiptId != 0
                || receipt.expiresAt <= block.timestamp
        ) return false;
        return activeGrantIdByScope[_grantKey(receipt)] == receipt.id && _isGrantContextCurrent(receipt);
    }

    function _requireKindShape(
        DisclosureInput calldata input,
        AVAGovernanceKernel.RecognisedStateReference memory state
    )
        private
        view
    {
        if (input.kind == DisclosureReceiptKind.AccessGrant) {
            if (input.proofReceiptId != 0 || input.relatedReceiptId != 0 || input.expiresAt <= block.timestamp) {
                revert AVACoreTypes.InvalidState(input.recognisedStateId);
            }
            bytes32 key = _grantKey(state.packageId, state.id, input.subjectId, input.scopeKey);
            uint256 activeGrantId = activeGrantIdByScope[key];
            if (activeGrantId != 0 && _grantStillOpen(activeGrantId)) {
                revert AVACoreTypes.InvalidState(activeGrantId);
            }
            return;
        }
        if (
            input.kind == DisclosureReceiptKind.AccessRevoke || input.kind == DisclosureReceiptKind.AccessExpire
                || input.kind == DisclosureReceiptKind.AccessSupersede
        ) {
            if (input.proofReceiptId != 0 || input.relatedReceiptId == 0 || input.expiresAt != 0) {
                revert AVACoreTypes.InvalidState(input.relatedReceiptId);
            }
            DisclosureReceipt storage grant = receipts[input.relatedReceiptId];
            if (
                !_grantUnclosed(input.relatedReceiptId) || grant.packageId != state.packageId
                    || grant.recognisedStateId != state.id || grant.subjectId != input.subjectId
                    || grant.targetSubjectId != state.subjectId || grant.evidenceId != input.evidenceId
                    || grant.scopeKey != input.scopeKey
            ) revert AVACoreTypes.InvalidState(input.relatedReceiptId);
            if (input.kind == DisclosureReceiptKind.AccessExpire) {
                if (grant.expiresAt > block.timestamp) revert AVACoreTypes.InvalidState(input.relatedReceiptId);
            } else if (grant.expiresAt <= block.timestamp) {
                revert AVACoreTypes.InvalidState(input.relatedReceiptId);
            }
            return;
        }
        if (input.kind == DisclosureReceiptKind.VoluntaryIntent) {
            if (
                input.proofReceiptId != 0 || input.relatedReceiptId != 0 || input.expiresAt != 0
                    || input.authorityId != input.subjectId
            ) {
                revert AVACoreTypes.InvalidState(input.recognisedStateId);
            }
            return;
        }
        if (
            input.proofReceiptId == 0 || input.relatedReceiptId != 0 || input.expiresAt != 0
                || proofUseReceiptIdByProofReceipt[input.proofReceiptId] != 0
                || !PROOF_REGISTRY.proofMatches(
                    input.proofReceiptId, state.packageId, state.id, input.subjectId, input.evidenceId, input.scopeKey
                )
        ) revert AVACoreTypes.InvalidState(input.proofReceiptId);
    }

    function _applyLifecycle(
        DisclosureInput calldata input,
        AVAGovernanceKernel.RecognisedStateReference memory state,
        uint256 receiptId
    ) private {
        if (input.kind == DisclosureReceiptKind.AccessGrant) {
            activeGrantIdByScope[_grantKey(state.packageId, state.id, input.subjectId, input.scopeKey)] = receiptId;
            return;
        }
        if (
            input.kind == DisclosureReceiptKind.AccessRevoke || input.kind == DisclosureReceiptKind.AccessExpire
                || input.kind == DisclosureReceiptKind.AccessSupersede
        ) {
            receipts[input.relatedReceiptId].closedByReceiptId = receiptId;
            delete activeGrantIdByScope[_grantKey(receipts[input.relatedReceiptId])];
            return;
        }
        if (input.kind == DisclosureReceiptKind.AnonymousProofUse) {
            proofUseReceiptIdByProofReceipt[input.proofReceiptId] = receiptId;
        }
    }

    function _grantStillOpen(uint256 receiptId) private view returns (bool) {
        DisclosureReceipt storage grant = receipts[receiptId];
        return _grantUnclosed(receiptId) && grant.expiresAt > block.timestamp;
    }

    function _grantUnclosed(uint256 receiptId) private view returns (bool) {
        DisclosureReceipt storage grant = receipts[receiptId];
        return grant.id != 0 && grant.kind == DisclosureReceiptKind.AccessGrant && grant.closedByReceiptId == 0;
    }

    function _grantKey(DisclosureReceipt storage receipt) private view returns (bytes32) {
        return _grantKey(receipt.packageId, receipt.recognisedStateId, receipt.subjectId, receipt.scopeKey);
    }

    function _grantKey(uint256 packageId, uint256 recognisedStateId, bytes32 subjectId, bytes32 scopeKey)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(packageId, recognisedStateId, subjectId, scopeKey));
    }

    function _recordTypeKey(DisclosureReceiptKind kind) private pure returns (bytes32) {
        return keccak256(abi.encode("ava.extension.disclosure-receipt.kind.v1", kind));
    }

    function _isGrantContextCurrent(DisclosureReceipt storage receipt) private view returns (bool) {
        AVAGovernanceKernel.RecognisedStateReference memory state;
        try GOVERNANCE_KERNEL.getRecognisedStateReference(receipt.recognisedStateId) returns (
            AVAGovernanceKernel.RecognisedStateReference memory currentState
        ) {
            state = currentState;
            if (
                state.appId != receipt.appId || state.workflowKey != receipt.workflowKey
                    || state.packageId != receipt.packageId || state.subjectId != receipt.targetSubjectId
                    || state.lastTransitionId != receipt.recognisedStateTransitionId
                    || state.disclosurePolicyId != receipt.disclosurePolicyId
            ) return false;
        } catch {
            return false;
        }
        try IDENTITY_REGISTRY.getSubjectContext(receipt.subjectId) returns (
            AVAIdentityRegistry.SubjectContext memory subject
        ) {
            if (!subject.active || subject.appId != receipt.appId) return false;
        } catch {
            return false;
        }
        if (!_evidenceUsable(state.evidenceReceiptId, receipt) || !_evidenceUsable(receipt.evidenceId, receipt)) {
            return false;
        }
        try DISCLOSURE_REGISTRY.requireActivePolicyReference(receipt.disclosurePolicyId, receipt.appId) {}
        catch {
            return false;
        }
        try RULE_PACKAGE_REGISTRY.getVerifiedPackageContext(receipt.packageId) returns (
            AVACoreRulePackageRegistry.VerifiedPackageContext memory rulePackage
        ) {
            return rulePackage.appId == receipt.appId && rulePackage.workflowKey == receipt.workflowKey;
        } catch {
            return false;
        }
    }

    function _evidenceUsable(uint256 evidenceId, DisclosureReceipt storage receipt) private view returns (bool) {
        try EVIDENCE_REGISTRY.requireUsableEvidenceReferenceForPackage(evidenceId, receipt.packageId) returns (
            bytes32 appId, bytes32 workflowKey, uint256, bytes32 subjectId, uint256 disclosurePolicyId
        ) {
            return appId == receipt.appId && workflowKey == receipt.workflowKey
                && subjectId == receipt.targetSubjectId && disclosurePolicyId == receipt.disclosurePolicyId;
        } catch {
            return false;
        }
    }

    function _contextHash(
        DisclosureInput calldata input,
        AVAGovernanceKernel.RecognisedStateReference memory state,
        uint256 sourceReceiptId
    ) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                DISCLOSURE_CONTEXT_DOMAIN,
                state.appId,
                state.workflowKey,
                state.packageId,
                state.id,
                state.lastTransitionId,
                input.subjectId,
                input.evidenceId,
                state.disclosurePolicyId,
                input.kind,
                input.scopeKey,
                sourceReceiptId,
                input.expiresAt
            )
        );
    }
}
