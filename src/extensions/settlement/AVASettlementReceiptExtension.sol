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
import {IAVADownstreamRecordSource} from "../downstream/IAVADownstreamRecordSource.sol";
import {AVAExtensionRecordBase} from "../shared/AVAExtensionRecordBase.sol";
import {IAVASettlementReceiptSource} from "./IAVASettlementReceiptSource.sol";

contract AVASettlementReceiptExtension is AVAExtensionRecordBase {
    bytes32 public constant SETTLEMENT_CONTEXT_DOMAIN = keccak256("ava.extension.settlement-receipt.context.v1");

    struct SettlementInput {
        address sourceRegistry;
        uint256 sourceRecordId;
        bytes32 roleKey;
        bytes32 authorityId;
        bytes32 subjectId;
        uint256 evidenceId;
        bytes32 settlementKindKey;
        uint256 units;
        bytes32 referenceHash;
        string uri;
    }

    struct SettlementReceipt {
        uint256 id;
        uint256 recognisedStateId;
        uint256 recognisedStateTransitionId;
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 subjectId;
        uint256 evidenceId;
        address sourceRegistry;
        bytes32 sourceTypeKey;
        uint256 sourceRecordId;
        bytes32 settlementKindKey;
        uint256 units;
        bytes32 referenceHash;
        bytes32 contextHash;
        string uri;
        bytes32 authorityId;
        address recordedBy;
        uint64 recordedAt;
    }

    IAVADownstreamRecordSource public immutable ALLOCATION_SOURCE;
    IAVADownstreamRecordSource public immutable CONSEQUENCE_SOURCE;

    mapping(uint256 => SettlementReceipt) private settlements;
    mapping(bytes32 => uint256) public settlementIdBySource;
    uint256 public nextSettlementId = 1;

    event SettlementReceiptRecorded(
        uint256 indexed settlementId,
        bytes32 indexed appId,
        bytes32 indexed subjectId,
        uint256 packageId,
        address sourceRegistry,
        uint256 sourceRecordId,
        bytes32 settlementKindKey,
        uint256 units,
        address recordedBy
    );

    constructor(
        AVAGovernanceKernel governanceKernel_,
        AVAAuthorityMatrix authorityMatrix_,
        AVAIdentityRegistry identityRegistry_,
        AVACoreRulePackageRegistry rulePackageRegistry_,
        AVAEvidenceRegistry evidenceRegistry_,
        AVADisclosurePolicyRegistry disclosureRegistry_,
        IAVADownstreamRecordSource allocationSource_,
        IAVADownstreamRecordSource consequenceSource_
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
        if (
            address(allocationSource_) == address(0) || address(consequenceSource_) == address(0)
                || address(allocationSource_).code.length == 0 || address(consequenceSource_).code.length == 0
                || address(allocationSource_) == address(consequenceSource_)
        ) revert AVACoreTypes.EmptyValue();
        if (
            address(allocationSource_.GOVERNANCE_KERNEL()) != address(governanceKernel_)
                || address(consequenceSource_.GOVERNANCE_KERNEL()) != address(governanceKernel_)
        ) revert AVACoreTypes.InvalidState(0);
        ALLOCATION_SOURCE = allocationSource_;
        CONSEQUENCE_SOURCE = consequenceSource_;
    }

    function recordSettlement(SettlementInput calldata input) external returns (uint256 settlementId) {
        if (
            input.sourceRegistry == address(0) || input.sourceRecordId == 0 || input.settlementKindKey == bytes32(0)
                || input.referenceHash == bytes32(0)
        ) revert AVACoreTypes.EmptyValue();
        bool allocationSource = input.sourceRegistry == address(ALLOCATION_SOURCE);
        if (!allocationSource && input.sourceRegistry != address(CONSEQUENCE_SOURCE)) {
            revert AVACoreTypes.InvalidState(input.sourceRecordId);
        }
        IAVADownstreamRecordSource.DownstreamSourceContext memory source =
            IAVADownstreamRecordSource(input.sourceRegistry).getDownstreamSource(input.sourceRecordId);
        if (
            source.id != input.sourceRecordId || source.subjectId != input.subjectId
                || source.evidenceId != input.evidenceId
                || (allocationSource && (input.units == 0 || input.units != source.units))
                || (!allocationSource && input.units != 0)
        ) revert AVACoreTypes.InvalidState(input.sourceRecordId);
        AVACoreTypes.RecognisedStateRecord memory state = GOVERNANCE_KERNEL.getRecognisedState(source.recognisedStateId);
        if (
            state.appId != source.appId || state.workflowKey != source.workflowKey
                || state.packageId != source.packageId || state.subjectId != source.subjectId
                || state.lastTransitionId != source.recognisedStateTransitionId
        ) revert AVACoreTypes.InvalidState(source.recognisedStateId);
        bytes32 sourceKey = keccak256(abi.encode(input.sourceRegistry, input.sourceRecordId));
        if (settlementIdBySource[sourceKey] != 0) {
            revert AVACoreTypes.InvalidState(settlementIdBySource[sourceKey]);
        }
        bytes32 contextHash = _contextHash(input, source);
        _validateExtension(
            ExtensionValidationInput({
                recognisedStateId: state.id,
                roleKey: input.roleKey,
                authorityId: input.authorityId,
                subjectId: input.subjectId,
                evidenceId: input.evidenceId,
                capabilityKey: AVACapabilityKeys.SETTLEMENT_RECEIPT,
                actionKey: AVACoreTypes.ACTION_RECORD_SETTLEMENT_RECEIPT,
                recordTypeKey: input.settlementKindKey,
                scopeKey: input.settlementKindKey,
                sourceTypeKey: source.sourceTypeKey,
                sourceRecordId: input.sourceRecordId,
                unsignedValue: input.units,
                validUntil: 0,
                payloadHash: input.referenceHash,
                requireActiveSubject: true,
                contextHash: contextHash
            })
        );

        settlementId = nextSettlementId++;
        settlements[settlementId] = SettlementReceipt({
            id: settlementId,
            recognisedStateId: source.recognisedStateId,
            recognisedStateTransitionId: source.recognisedStateTransitionId,
            appId: source.appId,
            workflowKey: source.workflowKey,
            packageId: source.packageId,
            subjectId: source.subjectId,
            evidenceId: source.evidenceId,
            sourceRegistry: input.sourceRegistry,
            sourceTypeKey: source.sourceTypeKey,
            sourceRecordId: source.id,
            settlementKindKey: input.settlementKindKey,
            units: input.units,
            referenceHash: input.referenceHash,
            contextHash: contextHash,
            uri: input.uri,
            authorityId: input.authorityId,
            recordedBy: msg.sender,
            recordedAt: uint64(block.timestamp)
        });
        settlementIdBySource[sourceKey] = settlementId;
        emit SettlementReceiptRecorded(
            settlementId,
            source.appId,
            source.subjectId,
            source.packageId,
            input.sourceRegistry,
            source.id,
            input.settlementKindKey,
            input.units,
            msg.sender
        );
    }

    function getSettlement(uint256 settlementId) external view returns (SettlementReceipt memory receipt) {
        receipt = settlements[settlementId];
        if (receipt.id == 0) revert AVACoreTypes.UnknownReference(settlementId);
    }

    function getSettlementSource(uint256 settlementId)
        external
        view
        returns (IAVASettlementReceiptSource.SettlementSourceContext memory context)
    {
        SettlementReceipt memory receipt = settlements[settlementId];
        if (receipt.id == 0) revert AVACoreTypes.UnknownReference(settlementId);
        context = IAVASettlementReceiptSource.SettlementSourceContext({
            id: receipt.id,
            recognisedStateId: receipt.recognisedStateId,
            recognisedStateTransitionId: receipt.recognisedStateTransitionId,
            appId: receipt.appId,
            workflowKey: receipt.workflowKey,
            packageId: receipt.packageId,
            subjectId: receipt.subjectId,
            evidenceId: receipt.evidenceId,
            sourceRegistry: receipt.sourceRegistry,
            sourceTypeKey: receipt.sourceTypeKey,
            sourceRecordId: receipt.sourceRecordId,
            settlementKindKey: receipt.settlementKindKey,
            units: receipt.units,
            referenceHash: receipt.referenceHash
        });
    }

    function _contextHash(
        SettlementInput calldata input,
        IAVADownstreamRecordSource.DownstreamSourceContext memory source
    ) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                SETTLEMENT_CONTEXT_DOMAIN,
                source.appId,
                source.workflowKey,
                source.packageId,
                source.recognisedStateId,
                source.recognisedStateTransitionId,
                source.subjectId,
                source.evidenceId,
                input.sourceRegistry,
                source.sourceTypeKey,
                source.id,
                input.settlementKindKey,
                input.units,
                input.referenceHash
            )
        );
    }
}
