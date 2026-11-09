// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVACapabilityKeys} from "../../core/AVACapabilityKeys.sol";
import {AVAAuthorityMatrix} from "../../core/AVAAuthorityMatrix.sol";
import {AVACoreRulePackageRegistry} from "../../core/AVACoreRulePackageRegistry.sol";
import {AVACoreTypes} from "../../core/AVACoreTypes.sol";
import {AVADisclosurePolicyRegistry} from "../../core/AVADisclosurePolicyRegistry.sol";
import {AVAEvidenceRegistry} from "../../core/AVAEvidenceRegistry.sol";
import {AVAGovernanceKernel} from "../../core/AVAGovernanceKernel.sol";
import {AVAIdentityRegistry} from "../../core/AVAIdentityRegistry.sol";
import {IAVAApplicationModule} from "../../interfaces/IAVAApplicationModule.sol";
import {IAVAAntiAbusePolicyModule} from "../../core/interfaces/IAVACoreRuleModules.sol";
import {AVAExtensionRecordBase} from "../shared/AVAExtensionRecordBase.sol";
import {IAVAExtensionPolicyModule} from "../shared/IAVAExtensionPolicyModule.sol";
import {
    AVAExternalOperationTargetKind,
    IAVAExternalOperationTargetResolver
} from "./AVAExternalOperationTargetResolver.sol";

contract AVAExternalOperationExtension is AVAExtensionRecordBase {
    enum OperationStatus {
        None,
        Requested,
        Acknowledged,
        Cancelled,
        Superseded
    }

    struct OperationInput {
        uint256 settlementId;
        bytes32 roleKey;
        bytes32 authorityId;
        bytes32 subjectId;
        uint256 evidenceId;
        bytes32 operationKey;
        bytes32 payloadHash;
        string uri;
    }

    struct TargetOperationInput {
        AVAExternalOperationTargetKind targetKind;
        uint256 targetId;
        bytes32 roleKey;
        bytes32 authorityId;
        bytes32 operationKey;
        bytes32 payloadHash;
        string uri;
    }

    struct PolicyValidationInput {
        AVAExternalOperationTargetKind targetKind;
        uint256 targetId;
        bytes32 roleKey;
        bytes32 authorityId;
        bytes32 actionKey;
        bytes32 operationKey;
        bytes32 payloadHash;
        bytes32 contextHash;
        bool requireActiveReferences;
    }

    struct OperationModules {
        AVACoreRulePackageRegistry.VerifiedPackageContext rulePackage;
        IAVAApplicationModule application;
        IAVAExtensionPolicyModule externalOperation;
        IAVAAntiAbusePolicyModule antiAbuse;
    }

    struct OperationReceipt {
        uint256 id;
        uint256 sourceOperationId;
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        uint256 recognisedStateId;
        uint256 recognisedStateTransitionId;
        AVAExternalOperationTargetKind targetKind;
        uint256 targetId;
        uint256 targetVersionId;
        bytes32 sourceTypeKey;
        bytes32 subjectId;
        uint256 evidenceId;
        uint256 settlementId;
        bytes32 operationKey;
        OperationStatus status;
        bytes32 payloadHash;
        bytes32 contextHash;
        string uri;
        bytes32 authorityId;
        address recordedBy;
        uint64 recordedAt;
    }

    bytes32 public constant OPERATION_CONTEXT_DOMAIN = keccak256("ava.extension.external-operation.context.v2");
    bytes32 public constant OPERATION_REQUEST_SOURCE_TYPE =
        keccak256("ava.extension.external-operation-request-source.v1");

    IAVAExternalOperationTargetResolver public immutable TARGET_RESOLVER;

    mapping(uint256 => OperationReceipt) private operations;
    mapping(bytes32 => uint256) public requestedOperationIdBySource;
    mapping(uint256 => uint256) public terminalReceiptIdByOperation;
    uint256 public nextOperationReceiptId = 1;

    event ExternalOperationReceiptRecorded(
        uint256 indexed receiptId,
        bytes32 indexed appId,
        uint256 indexed targetId,
        AVAExternalOperationTargetKind targetKind,
        uint256 packageId,
        bytes32 operationKey,
        OperationStatus status,
        uint256 sourceOperationId,
        address recordedBy
    );

    constructor(
        AVAGovernanceKernel governanceKernel_,
        AVAAuthorityMatrix authorityMatrix_,
        AVAIdentityRegistry identityRegistry_,
        AVACoreRulePackageRegistry rulePackageRegistry_,
        AVAEvidenceRegistry evidenceRegistry_,
        AVADisclosurePolicyRegistry disclosureRegistry_,
        IAVAExternalOperationTargetResolver targetResolver_
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
        if (address(targetResolver_) == address(0) || address(targetResolver_).code.length == 0) {
            revert AVACoreTypes.EmptyValue();
        }
        if (address(targetResolver_.GOVERNANCE_KERNEL()) != address(governanceKernel_)) {
            revert AVACoreTypes.InvalidState(0);
        }
        TARGET_RESOLVER = targetResolver_;
    }

    function requestOperation(OperationInput calldata input) external returns (uint256 receiptId) {
        IAVAExternalOperationTargetResolver.TargetContext memory target =
            TARGET_RESOLVER.resolveTarget(AVAExternalOperationTargetKind.SettlementReceipt, input.settlementId);
        if (target.subjectId != input.subjectId || target.evidenceId != input.evidenceId) {
            revert AVACoreTypes.InvalidState(input.settlementId);
        }
        receiptId = _requestTarget(
            target,
            TargetOperationInput({
                targetKind: AVAExternalOperationTargetKind.SettlementReceipt,
                targetId: input.settlementId,
                roleKey: input.roleKey,
                authorityId: input.authorityId,
                operationKey: input.operationKey,
                payloadHash: input.payloadHash,
                uri: input.uri
            })
        );
    }

    function requestTargetOperation(TargetOperationInput calldata input) external returns (uint256 receiptId) {
        IAVAExternalOperationTargetResolver.TargetContext memory target =
            TARGET_RESOLVER.resolveTarget(input.targetKind, input.targetId);
        receiptId = _requestTarget(target, input);
    }

    function recordOutcome(
        uint256 operationId,
        OperationStatus status,
        bytes32 roleKey,
        bytes32 authorityId,
        bytes32 outcomeHash,
        string calldata uri
    ) external returns (uint256 receiptId) {
        OperationReceipt memory request = operations[operationId];
        if (
            request.id == 0 || request.status != OperationStatus.Requested
                || (status != OperationStatus.Acknowledged
                    && status != OperationStatus.Cancelled
                    && status != OperationStatus.Superseded) || outcomeHash == bytes32(0)
                || terminalReceiptIdByOperation[operationId] != 0
        ) revert AVACoreTypes.InvalidState(operationId);
        AUTHORITY_MATRIX.requireAuthorisedSubject(
            msg.sender, request.appId, roleKey, AVACoreTypes.ACTION_RECORD_EXTERNAL_OPERATION_OUTCOME, authorityId
        );
        IAVAExternalOperationTargetResolver.TargetContext memory target =
            TARGET_RESOLVER.resolveTarget(request.targetKind, request.targetId);
        _requireSameTarget(request, target, status == OperationStatus.Acknowledged);
        bytes32 contextHash = _outcomeContextHash(request, status, outcomeHash);
        PolicyValidationInput memory validation;
        validation.targetKind = request.targetKind;
        validation.targetId = request.targetId;
        validation.roleKey = roleKey;
        validation.authorityId = authorityId;
        validation.actionKey = AVACoreTypes.ACTION_RECORD_EXTERNAL_OPERATION_OUTCOME;
        validation.operationKey = request.operationKey;
        validation.payloadHash = outcomeHash;
        validation.contextHash = contextHash;
        validation.requireActiveReferences = status == OperationStatus.Acknowledged;
        if (validation.requireActiveReferences) {
            _validateTargetPolicies(target, validation);
        } else {
            (bool packageStable, OperationModules memory modules) = _tryVerifiedOperationModules(request.packageId);
            if (packageStable) {
                _validateTargetPolicies(target, validation, modules);
            } else {
                _validateDefensiveCloseout(target);
            }
        }
        OperationReceipt memory outcome = request;
        outcome.id = 0;
        outcome.sourceOperationId = request.id;
        outcome.status = status;
        outcome.payloadHash = outcomeHash;
        outcome.contextHash = contextHash;
        outcome.uri = uri;
        outcome.authorityId = authorityId;
        outcome.recordedBy = msg.sender;
        outcome.recordedAt = uint64(block.timestamp);
        receiptId = _storeOperation(outcome);
        terminalReceiptIdByOperation[operationId] = receiptId;
    }

    function getOperation(uint256 receiptId) external view returns (OperationReceipt memory receipt) {
        receipt = operations[receiptId];
        if (receipt.id == 0) revert AVACoreTypes.UnknownReference(receiptId);
    }

    function _requestTarget(
        IAVAExternalOperationTargetResolver.TargetContext memory target,
        TargetOperationInput memory input
    ) private returns (uint256 receiptId) {
        if (
            input.targetKind == AVAExternalOperationTargetKind.None || input.targetId == 0
                || input.roleKey == bytes32(0) || input.authorityId == bytes32(0) || input.operationKey == bytes32(0)
                || input.payloadHash == bytes32(0)
        ) revert AVACoreTypes.EmptyValue();
        AUTHORITY_MATRIX.requireAuthorisedSubject(
            msg.sender, target.appId, input.roleKey, AVACoreTypes.ACTION_RECORD_EXTERNAL_OPERATION, input.authorityId
        );
        bytes32 sourceKey = keccak256(
            abi.encode(target.packageId, input.targetKind, input.targetId, target.targetVersionId, input.operationKey)
        );
        if (requestedOperationIdBySource[sourceKey] != 0) {
            revert AVACoreTypes.InvalidState(requestedOperationIdBySource[sourceKey]);
        }
        bytes32 contextHash = _requestContextHash(target, input);
        PolicyValidationInput memory validation;
        validation.targetKind = input.targetKind;
        validation.targetId = input.targetId;
        validation.roleKey = input.roleKey;
        validation.authorityId = input.authorityId;
        validation.actionKey = AVACoreTypes.ACTION_RECORD_EXTERNAL_OPERATION;
        validation.operationKey = input.operationKey;
        validation.payloadHash = input.payloadHash;
        validation.contextHash = contextHash;
        validation.requireActiveReferences = true;
        _validateTargetPolicies(target, validation);
        receiptId = _storeOperation(
            OperationReceipt({
                id: 0,
                sourceOperationId: 0,
                appId: target.appId,
                workflowKey: target.workflowKey,
                packageId: target.packageId,
                recognisedStateId: target.recognisedStateId,
                recognisedStateTransitionId: target.recognisedStateTransitionId,
                targetKind: input.targetKind,
                targetId: input.targetId,
                targetVersionId: target.targetVersionId,
                sourceTypeKey: target.sourceTypeKey,
                subjectId: target.subjectId,
                evidenceId: target.evidenceId,
                settlementId: input.targetKind == AVAExternalOperationTargetKind.SettlementReceipt ? input.targetId : 0,
                operationKey: input.operationKey,
                status: OperationStatus.Requested,
                payloadHash: input.payloadHash,
                contextHash: contextHash,
                uri: input.uri,
                authorityId: input.authorityId,
                recordedBy: msg.sender,
                recordedAt: uint64(block.timestamp)
            })
        );
        requestedOperationIdBySource[sourceKey] = receiptId;
    }

    function _validateTargetPolicies(
        IAVAExternalOperationTargetResolver.TargetContext memory target,
        PolicyValidationInput memory input
    ) private view {
        _validateTargetPolicies(target, input, _verifiedOperationModules(target.packageId));
    }

    function _validateTargetPolicies(
        IAVAExternalOperationTargetResolver.TargetContext memory target,
        PolicyValidationInput memory input,
        OperationModules memory modules
    ) private view {
        if (modules.rulePackage.appId != target.appId || modules.rulePackage.workflowKey != target.workflowKey) {
            revert AVACoreTypes.InvalidState(target.packageId);
        }
        if (input.requireActiveReferences && target.recognisedStateId != 0) {
            AVACoreTypes.RecognisedStateRecord memory state =
                GOVERNANCE_KERNEL.getRecognisedState(target.recognisedStateId);
            if (state.appId != target.appId || state.lastTransitionId != target.recognisedStateTransitionId) {
                revert AVACoreTypes.InvalidState(target.recognisedStateId);
            }
        }
        _requireTargetSubject(target, input.requireActiveReferences);
        uint256 disclosurePolicyId = _requireTargetEvidence(target, input.requireActiveReferences);
        if (target.recognisedStateId != 0) {
            _validateApplication(
                target, input.roleKey, input.authorityId, input.actionKey, input.operationKey, modules.application
            );
        }
        if (address(modules.externalOperation) == address(0)) {
            revert AVACoreTypes.UnknownReference(target.packageId);
        }
        modules.externalOperation
            .validateExtensionRecord(
                IAVAExtensionPolicyModule.ExtensionPolicyContext({
                    appId: target.appId,
                    workflowKey: target.workflowKey,
                    packageId: target.packageId,
                    capabilityKey: AVACapabilityKeys.EXTERNAL_OPERATION,
                    actionKey: input.actionKey,
                    recordTypeKey: input.operationKey,
                    scopeKey: bytes32(uint256(uint8(input.targetKind))),
                    sourceTypeKey: target.sourceTypeKey,
                    recognisedStateId: target.recognisedStateId,
                    recognisedStateTransitionId: target.recognisedStateTransitionId,
                    subjectId: target.subjectId,
                    evidenceId: target.evidenceId,
                    disclosurePolicyId: disclosurePolicyId,
                    sourceRecordId: target.sourceRecordId,
                    unsignedValue: target.units,
                    validUntil: 0,
                    payloadHash: input.payloadHash,
                    contextHash: input.contextHash,
                    authorityId: input.authorityId,
                    actor: msg.sender
                })
            );
        _validateAntiAbuse(
            target,
            input.targetKind,
            input.targetId,
            input.roleKey,
            input.authorityId,
            input.actionKey,
            modules.antiAbuse
        );
    }

    function _validateApplication(
        IAVAExternalOperationTargetResolver.TargetContext memory target,
        bytes32 roleKey,
        bytes32 authorityId,
        bytes32 actionKey,
        bytes32 operationKey,
        IAVAApplicationModule application
    ) private view {
        AVACoreTypes.RecognisedStateRecord memory state = GOVERNANCE_KERNEL.getRecognisedState(target.recognisedStateId);
        AVAGovernanceKernel.GovernedObjectReference memory objectRecord =
            GOVERNANCE_KERNEL.getGovernedObjectReference(state.governedObjectId);
        if (state.appId != target.appId) revert AVACoreTypes.InvalidState(target.recognisedStateId);
        application.validateDownstreamRecord(
            IAVAApplicationModule.DownstreamRecordContext({
                appId: target.appId,
                workflowKey: target.workflowKey,
                packageId: target.packageId,
                actionKey: actionKey,
                roleKey: roleKey,
                recognisedStateId: state.id,
                governedObjectId: state.governedObjectId,
                objectTypeKey: objectRecord.objectTypeKey,
                subjectId: target.subjectId,
                evidenceReceiptId: target.evidenceId,
                recordTypeKey: operationKey,
                authorityId: authorityId,
                actor: msg.sender
            })
        );
    }

    function _validateDefensiveCloseout(IAVAExternalOperationTargetResolver.TargetContext memory target) private view {
        _requireTargetSubject(target, false);
        _requireTargetEvidence(target, false);
    }

    function _validateAntiAbuse(
        IAVAExternalOperationTargetResolver.TargetContext memory target,
        AVAExternalOperationTargetKind targetKind,
        uint256 targetId,
        bytes32 roleKey,
        bytes32 authorityId,
        bytes32 actionKey,
        IAVAAntiAbusePolicyModule antiAbuse
    ) private view {
        if (address(antiAbuse) == address(0)) return;
        antiAbuse.validateAntiAbuse(
            IAVAAntiAbusePolicyModule.AntiAbuseContext({
                appId: target.appId,
                workflowKey: target.workflowKey,
                packageId: target.packageId,
                actionKey: actionKey,
                roleKey: roleKey,
                targetId: targetId,
                targetTypeKey: bytes32(uint256(uint8(targetKind))),
                actorSubjectId: authorityId,
                targetSubjectId: target.subjectId,
                authorityId: authorityId,
                actor: msg.sender
            })
        );
    }

    function _verifiedOperationModules(uint256 packageId) private view returns (OperationModules memory modules) {
        bytes32[] memory keys = _operationModuleKeys();
        (AVACoreRulePackageRegistry.VerifiedPackageContext memory rulePackage, address[] memory addresses) =
            RULE_PACKAGE_REGISTRY.getVerifiedModulesCompact(packageId, keys);
        modules = _operationModules(rulePackage, addresses);
    }

    function _tryVerifiedOperationModules(uint256 packageId)
        private
        view
        returns (bool packageStable, OperationModules memory modules)
    {
        bytes32[] memory keys = _operationModuleKeys();
        try RULE_PACKAGE_REGISTRY.getVerifiedModulesCompact(packageId, keys) returns (
            AVACoreRulePackageRegistry.VerifiedPackageContext memory rulePackage, address[] memory addresses
        ) {
            return (true, _operationModules(rulePackage, addresses));
        } catch {
            return (false, modules);
        }
    }

    function _operationModuleKeys() private pure returns (bytes32[] memory keys) {
        keys = new bytes32[](3);
        keys[0] = AVACapabilityKeys.APPLICATION;
        keys[1] = AVACapabilityKeys.EXTERNAL_OPERATION;
        keys[2] = AVACapabilityKeys.ANTI_ABUSE;
    }

    function _operationModules(
        AVACoreRulePackageRegistry.VerifiedPackageContext memory rulePackage,
        address[] memory addresses
    )
        private
        pure
        returns (OperationModules memory modules)
    {
        modules = OperationModules({
            rulePackage: rulePackage,
            application: IAVAApplicationModule(addresses[0]),
            externalOperation: IAVAExtensionPolicyModule(addresses[1]),
            antiAbuse: IAVAAntiAbusePolicyModule(addresses[2])
        });
    }

    function _requireTargetSubject(IAVAExternalOperationTargetResolver.TargetContext memory target, bool requireActive)
        private
        view
    {
        if (requireActive) {
            IDENTITY_REGISTRY.requireActiveSubjectReference(target.subjectId, target.appId);
            return;
        }
        AVAIdentityRegistry.SubjectContext memory subject = IDENTITY_REGISTRY.getSubjectContext(target.subjectId);
        if (subject.appId != target.appId) {
            revert AVACoreTypes.CrossApplicationReference(target.appId, subject.appId);
        }
    }

    function _requireTargetEvidence(IAVAExternalOperationTargetResolver.TargetContext memory target, bool requireActive)
        private
        view
        returns (uint256 disclosurePolicyId)
    {
        bytes32 appId;
        bytes32 workflowKey;
        bytes32 subjectId;
        if (requireActive) {
            (appId, workflowKey,, subjectId, disclosurePolicyId) =
                EVIDENCE_REGISTRY.requireUsableEvidenceReferenceForPackage(target.evidenceId, target.packageId);
        } else {
            (appId, workflowKey,, subjectId, disclosurePolicyId) =
                EVIDENCE_REGISTRY.requireEvidenceReferenceForPackage(target.evidenceId, target.packageId);
        }
        if (
            appId != target.appId || workflowKey != target.workflowKey || subjectId != target.subjectId
        ) revert AVACoreTypes.InvalidState(target.evidenceId);
        DISCLOSURE_REGISTRY.requireActivePolicyReference(disclosurePolicyId, target.appId);
    }

    function _requireSameTarget(
        OperationReceipt memory request,
        IAVAExternalOperationTargetResolver.TargetContext memory current,
        bool requireCurrentVersion
    ) private pure {
        if (
            current.appId != request.appId || current.workflowKey != request.workflowKey
                || current.packageId != request.packageId || current.recognisedStateId != request.recognisedStateId
                || current.subjectId != request.subjectId || current.evidenceId != request.evidenceId
                || current.sourceTypeKey != request.sourceTypeKey || current.sourceRecordId != request.targetId
                || (requireCurrentVersion
                    && (current.targetVersionId != request.targetVersionId
                        || current.recognisedStateTransitionId != request.recognisedStateTransitionId))
        ) {
            revert AVACoreTypes.InvalidState(request.id);
        }
    }

    function _storeOperation(OperationReceipt memory receipt) private returns (uint256 receiptId) {
        receiptId = nextOperationReceiptId++;
        receipt.id = receiptId;
        operations[receiptId] = receipt;
        emit ExternalOperationReceiptRecorded(
            receiptId,
            receipt.appId,
            receipt.targetId,
            receipt.targetKind,
            receipt.packageId,
            receipt.operationKey,
            receipt.status,
            receipt.sourceOperationId,
            msg.sender
        );
    }

    function _requestContextHash(
        IAVAExternalOperationTargetResolver.TargetContext memory target,
        TargetOperationInput memory input
    ) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                OPERATION_CONTEXT_DOMAIN,
                target.appId,
                target.workflowKey,
                target.packageId,
                input.targetKind,
                input.targetId,
                target.targetVersionId,
                target.recognisedStateId,
                target.recognisedStateTransitionId,
                target.subjectId,
                target.evidenceId,
                input.operationKey,
                OperationStatus.Requested,
                input.payloadHash
            )
        );
    }

    function _outcomeContextHash(OperationReceipt memory request, OperationStatus status, bytes32 outcomeHash)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                OPERATION_CONTEXT_DOMAIN,
                request.appId,
                request.workflowKey,
                request.packageId,
                request.targetKind,
                request.targetId,
                request.targetVersionId,
                request.id,
                request.contextHash,
                status,
                outcomeHash
            )
        );
    }
}
