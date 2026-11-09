// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAVAApplicationModule} from "../../interfaces/IAVAApplicationModule.sol";
import {AVAAuthorityMatrix} from "../../core/AVAAuthorityMatrix.sol";
import {AVACapabilityKeys} from "../../core/AVACapabilityKeys.sol";
import {AVACoreTypes} from "../../core/AVACoreTypes.sol";
import {AVACoreRulePackageRegistry} from "../../core/AVACoreRulePackageRegistry.sol";
import {AVAEvidenceRegistry} from "../../core/AVAEvidenceRegistry.sol";
import {AVAGovernanceKernel} from "../../core/AVAGovernanceKernel.sol";
import {AVAIdentityRegistry} from "../../core/AVAIdentityRegistry.sol";
import {
    IAVAStandingPolicyModule,
    IAVAAllocationPolicyModule,
    IAVAConsequencePolicyModule,
    IAVAAntiAbusePolicyModule
} from "../../core/interfaces/IAVACoreRuleModules.sol";
import {IAVAStandingRevision} from "../standing/IAVAStandingRevision.sol";
import {IAVADownstreamRecordSource} from "./IAVADownstreamRecordSource.sol";

abstract contract AVADownstreamRecordBase {
    enum RecordClass {
        Standing,
        Allocation,
        Consequence
    }

    struct ValidationInput {
        uint256 recognisedStateId;
        bytes32 roleKey;
        bytes32 authorityId;
        bytes32 subjectId;
        uint256 evidenceId;
        bytes32 recordTypeKey;
        bytes32 actionKey;
        RecordClass recordClass;
        int256 signedValue;
        uint256 unsignedValue;
    }

    struct RecordModules {
        AVACoreRulePackageRegistry.VerifiedPackageContext rulePackage;
        IAVAApplicationModule application;
        IAVAAntiAbusePolicyModule antiAbuse;
        address recordPolicy;
    }

    AVAGovernanceKernel public immutable GOVERNANCE_KERNEL;
    AVAAuthorityMatrix public immutable AUTHORITY_MATRIX;
    AVAIdentityRegistry public immutable IDENTITY_REGISTRY;
    AVACoreRulePackageRegistry public immutable RULE_PACKAGE_REGISTRY;
    AVAEvidenceRegistry public immutable EVIDENCE_REGISTRY;

    constructor(
        AVAGovernanceKernel governanceKernel_,
        AVAAuthorityMatrix authorityMatrix_,
        AVAIdentityRegistry identityRegistry_,
        AVACoreRulePackageRegistry rulePackageRegistry_,
        AVAEvidenceRegistry evidenceRegistry_
    ) {
        if (
            address(governanceKernel_) == address(0) || address(authorityMatrix_) == address(0)
                || address(identityRegistry_) == address(0) || address(rulePackageRegistry_) == address(0)
                || address(evidenceRegistry_) == address(0)
        ) {
            revert AVACoreTypes.EmptyValue();
        }
        if (
            address(governanceKernel_.AUTHORITY_MATRIX()) != address(authorityMatrix_)
                || address(governanceKernel_.IDENTITY_REGISTRY()) != address(identityRegistry_)
                || address(governanceKernel_.RULE_PACKAGE_REGISTRY()) != address(rulePackageRegistry_)
                || address(governanceKernel_.EVIDENCE_REGISTRY()) != address(evidenceRegistry_)
                || address(authorityMatrix_.IDENTITY_REGISTRY()) != address(identityRegistry_)
        ) {
            revert AVACoreTypes.InvalidState(0);
        }
        GOVERNANCE_KERNEL = governanceKernel_;
        AUTHORITY_MATRIX = authorityMatrix_;
        IDENTITY_REGISTRY = identityRegistry_;
        RULE_PACKAGE_REGISTRY = rulePackageRegistry_;
        EVIDENCE_REGISTRY = evidenceRegistry_;
    }

    function _validateRecord(ValidationInput memory input)
        internal
        view
        returns (AVAGovernanceKernel.RecognisedStateReference memory state)
    {
        if (
            input.recognisedStateId == 0 || input.roleKey == bytes32(0) || input.authorityId == bytes32(0)
                || input.subjectId == bytes32(0) || input.evidenceId == 0 || input.recordTypeKey == bytes32(0)
                || input.actionKey == bytes32(0)
        ) {
            revert AVACoreTypes.EmptyValue();
        }
        state = GOVERNANCE_KERNEL.getRecognisedStateReference(input.recognisedStateId);
        if (state.subjectId != input.subjectId) {
            revert AVACoreTypes.SubjectMismatch(state.subjectId, input.subjectId);
        }
        IDENTITY_REGISTRY.requireActiveSubjectReference(input.subjectId, state.appId);
        AUTHORITY_MATRIX.requireAuthorisedSubject(
            msg.sender, state.appId, input.roleKey, input.actionKey, input.authorityId
        );
        RecordModules memory modules = _verifiedRecordModules(state.packageId, input.recordClass);
        if (modules.rulePackage.appId != state.appId || modules.rulePackage.workflowKey != state.workflowKey) {
            revert AVACoreTypes.InvalidState(state.packageId);
        }
        bytes32 objectTypeKey = GOVERNANCE_KERNEL.getGovernedObjectReference(state.governedObjectId).objectTypeKey;
        _requireEvidence(state.evidenceReceiptId, state);
        if (input.evidenceId != state.evidenceReceiptId) _requireEvidence(input.evidenceId, state);
        _requireAllowedStatus(input.recordClass, state.status);
        IAVAApplicationModule.DownstreamRecordContext memory context = IAVAApplicationModule.DownstreamRecordContext({
            appId: state.appId,
            workflowKey: state.workflowKey,
            packageId: state.packageId,
            actionKey: input.actionKey,
            roleKey: input.roleKey,
            recognisedStateId: state.id,
            governedObjectId: state.governedObjectId,
            objectTypeKey: objectTypeKey,
            subjectId: input.subjectId,
            evidenceReceiptId: input.evidenceId,
            recordTypeKey: input.recordTypeKey,
            authorityId: input.authorityId,
            actor: msg.sender
        });
        modules.application.validateDownstreamRecord(context);
        if (address(modules.antiAbuse) != address(0)) {
            modules.antiAbuse
                .validateAntiAbuse(
                    IAVAAntiAbusePolicyModule.AntiAbuseContext({
                        appId: state.appId,
                        workflowKey: state.workflowKey,
                        packageId: state.packageId,
                        actionKey: input.actionKey,
                        roleKey: input.roleKey,
                        targetId: state.id,
                        targetTypeKey: input.recordTypeKey,
                        actorSubjectId: input.authorityId,
                        targetSubjectId: input.subjectId,
                        authorityId: input.authorityId,
                        actor: msg.sender
                    })
                );
        }
        _validateRecordPolicy(modules.recordPolicy, input, context);
    }

    function _validateRecordPolicy(
        address recordPolicy,
        ValidationInput memory input,
        IAVAApplicationModule.DownstreamRecordContext memory context
    ) private view {
        if (input.recordClass == RecordClass.Standing) {
            IAVAStandingPolicyModule(recordPolicy)
                .validateStanding(
                    IAVAStandingPolicyModule.StandingPolicyContext({record: context, delta: input.signedValue})
                );
            return;
        }
        if (input.recordClass == RecordClass.Allocation) {
            IAVAAllocationPolicyModule(recordPolicy)
                .validateAllocation(
                    IAVAAllocationPolicyModule.AllocationPolicyContext({record: context, units: input.unsignedValue})
                );
            return;
        }
        IAVAConsequencePolicyModule(recordPolicy).validateConsequence(context);
    }

    function _verifiedRecordModules(uint256 packageId, RecordClass recordClass)
        private
        view
        returns (RecordModules memory modules)
    {
        bytes32[] memory keys = new bytes32[](3);
        keys[0] = AVACapabilityKeys.APPLICATION;
        keys[1] = AVACapabilityKeys.ANTI_ABUSE;
        keys[2] = _recordCapabilityKey(recordClass);
        (AVACoreRulePackageRegistry.VerifiedPackageContext memory rulePackage, address[] memory addresses) =
            RULE_PACKAGE_REGISTRY.getVerifiedModulesCompact(packageId, keys);
        if (addresses[2] == address(0)) revert AVACoreTypes.UnknownReference(packageId);
        modules = RecordModules({
            rulePackage: rulePackage,
            application: IAVAApplicationModule(addresses[0]),
            antiAbuse: IAVAAntiAbusePolicyModule(addresses[1]),
            recordPolicy: addresses[2]
        });
    }

    function _recordCapabilityKey(RecordClass recordClass) private pure returns (bytes32) {
        if (recordClass == RecordClass.Standing) return AVACapabilityKeys.STANDING;
        if (recordClass == RecordClass.Allocation) return AVACapabilityKeys.ALLOCATION;
        return AVACapabilityKeys.CONSEQUENCE;
    }

    function _requireEvidence(uint256 evidenceId, AVAGovernanceKernel.RecognisedStateReference memory state)
        private
        view
    {
        (bytes32 appId, bytes32 workflowKey,, bytes32 subjectId, uint256 disclosurePolicyId) =
            EVIDENCE_REGISTRY.requireUsableEvidenceReferenceForPackage(evidenceId, state.packageId);
        if (
            appId != state.appId || workflowKey != state.workflowKey
                || subjectId != state.subjectId || disclosurePolicyId != state.disclosurePolicyId
        ) {
            revert AVACoreTypes.InvalidState(evidenceId);
        }
    }

    function _requireAllowedStatus(RecordClass recordClass, AVACoreTypes.RecognisedStateStatus status) private pure {
        if (recordClass == RecordClass.Allocation) {
            if (
                status != AVACoreTypes.RecognisedStateStatus.Vested
                    && status != AVACoreTypes.RecognisedStateStatus.Restored
            ) {
                revert AVACoreTypes.InvalidState(uint256(status));
            }
            return;
        }
        if (
            status != AVACoreTypes.RecognisedStateStatus.Vested && status != AVACoreTypes.RecognisedStateStatus.Restored
                && status != AVACoreTypes.RecognisedStateStatus.Downgraded
                && status != AVACoreTypes.RecognisedStateStatus.Voided
        ) {
            revert AVACoreTypes.InvalidState(uint256(status));
        }
    }
}

contract AVAStandingRecordExtension is AVADownstreamRecordBase {
    int256 public constant MAX_ABSOLUTE_DELTA = 1_000_000;
    bytes32 private constant STANDING_UPDATE_SOURCE = keccak256("ava.standing-update-record.v1");
    IAVAStandingRevision public immutable REVISION_REGISTRY;

    struct StandingInput {
        uint256 recognisedStateId;
        bytes32 roleKey;
        bytes32 authorityId;
        bytes32 subjectId;
        uint256 evidenceId;
        bytes32 dimensionKey;
        int256 delta;
        bytes32 reasonHash;
        string uri;
    }

    struct StandingUpdateRecord {
        uint256 id;
        uint256 recognisedStateId;
        uint256 recognisedStateTransitionId;
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 subjectId;
        uint256 evidenceId;
        bytes32 dimensionKey;
        int256 delta;
        bytes32 authorityId;
        bytes32 reasonHash;
        string uri;
        address registeredBy;
        uint64 registeredAt;
    }

    mapping(uint256 => StandingUpdateRecord) private standingUpdates;
    mapping(bytes32 => uint256) private standingUpdateIdByStateVersionDimension;
    uint256 public nextStandingUpdateId = 1;

    event StandingUpdateRecorded(
        uint256 indexed id,
        uint256 indexed recognisedStateId,
        bytes32 indexed subjectId,
        uint256 packageId,
        bytes32 dimensionKey,
        int256 delta,
        address registeredBy
    );

    constructor(
        AVAGovernanceKernel governanceKernel_,
        AVAAuthorityMatrix authorityMatrix_,
        AVAIdentityRegistry identityRegistry_,
        AVACoreRulePackageRegistry rulePackageRegistry_,
        AVAEvidenceRegistry evidenceRegistry_,
        IAVAStandingRevision revisionRegistry_
    )
        AVADownstreamRecordBase(
            governanceKernel_, authorityMatrix_, identityRegistry_, rulePackageRegistry_, evidenceRegistry_
        )
    {
        if (address(revisionRegistry_) != address(0) && address(revisionRegistry_).code.length == 0) {
            revert AVACoreTypes.EmptyValue();
        }
        if (
            address(revisionRegistry_) != address(0)
                && address(revisionRegistry_.GOVERNANCE_KERNEL()) != address(governanceKernel_)
        ) revert AVACoreTypes.InvalidState(0);
        REVISION_REGISTRY = revisionRegistry_;
    }

    function recordStandingUpdate(StandingInput calldata input) external returns (uint256 id) {
        if (
            input.delta == 0 || input.delta > MAX_ABSOLUTE_DELTA || input.delta < -MAX_ABSOLUTE_DELTA
                || input.reasonHash == bytes32(0)
        ) {
            revert AVACoreTypes.EmptyValue();
        }
        AVAGovernanceKernel.RecognisedStateReference memory state = _validateRecord(
            ValidationInput({
                recognisedStateId: input.recognisedStateId,
                roleKey: input.roleKey,
                authorityId: input.authorityId,
                subjectId: input.subjectId,
                evidenceId: input.evidenceId,
                recordTypeKey: input.dimensionKey,
                actionKey: AVACoreTypes.ACTION_RECORD_STANDING_UPDATE,
                recordClass: RecordClass.Standing,
                signedValue: input.delta,
                unsignedValue: 0
            })
        );
        bytes32 inputKey = keccak256(
            abi.encode(state.packageId, state.id, state.lastTransitionId, input.subjectId, input.dimensionKey)
        );
        if (standingUpdateIdByStateVersionDimension[inputKey] != 0) {
            revert AVACoreTypes.InvalidState(standingUpdateIdByStateVersionDimension[inputKey]);
        }
        id = nextStandingUpdateId++;
        standingUpdates[id] = StandingUpdateRecord({
            id: id,
            recognisedStateId: state.id,
            recognisedStateTransitionId: state.lastTransitionId,
            appId: state.appId,
            workflowKey: state.workflowKey,
            packageId: state.packageId,
            subjectId: input.subjectId,
            evidenceId: input.evidenceId,
            dimensionKey: input.dimensionKey,
            delta: input.delta,
            authorityId: input.authorityId,
            reasonHash: input.reasonHash,
            uri: input.uri,
            registeredBy: msg.sender,
            registeredAt: uint64(block.timestamp)
        });
        standingUpdateIdByStateVersionDimension[inputKey] = id;
        if (address(REVISION_REGISTRY) != address(0)) {
            REVISION_REGISTRY.advanceRevision(state.appId, state.packageId, state.subjectId, STANDING_UPDATE_SOURCE, id);
        }
        emit StandingUpdateRecorded(
            id, state.id, input.subjectId, state.packageId, input.dimensionKey, input.delta, msg.sender
        );
    }

    function getStandingUpdate(uint256 id) external view returns (StandingUpdateRecord memory record) {
        record = standingUpdates[id];
        if (record.id == 0) revert AVACoreTypes.UnknownReference(id);
    }
}

contract AVAAllocationRecordExtension is AVADownstreamRecordBase {
    uint256 public constant MAX_ALLOCATION_UNITS = 1_000_000;
    bytes32 public constant SOURCE_TYPE_KEY = keccak256("ava.extension.allocation-record-source.v1");

    struct AllocationInput {
        uint256 recognisedStateId;
        bytes32 roleKey;
        bytes32 authorityId;
        bytes32 subjectId;
        uint256 evidenceId;
        bytes32 allocationKindKey;
        uint256 units;
        bytes32 reasonHash;
        string uri;
    }

    struct AllocationRecord {
        uint256 id;
        uint256 recognisedStateId;
        uint256 recognisedStateTransitionId;
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 subjectId;
        uint256 evidenceId;
        bytes32 allocationKindKey;
        uint256 units;
        bytes32 authorityId;
        bytes32 reasonHash;
        string uri;
        address registeredBy;
        uint64 registeredAt;
    }

    mapping(uint256 => AllocationRecord) private allocations;
    uint256 public nextAllocationId = 1;

    event AllocationRecorded(
        uint256 indexed id,
        uint256 indexed recognisedStateId,
        bytes32 indexed subjectId,
        uint256 packageId,
        bytes32 allocationKindKey,
        uint256 units,
        address registeredBy
    );

    constructor(
        AVAGovernanceKernel governanceKernel_,
        AVAAuthorityMatrix authorityMatrix_,
        AVAIdentityRegistry identityRegistry_,
        AVACoreRulePackageRegistry rulePackageRegistry_,
        AVAEvidenceRegistry evidenceRegistry_
    )
        AVADownstreamRecordBase(
            governanceKernel_, authorityMatrix_, identityRegistry_, rulePackageRegistry_, evidenceRegistry_
        )
    {}

    function recordAllocation(AllocationInput calldata input) external returns (uint256 id) {
        if (input.units == 0 || input.units > MAX_ALLOCATION_UNITS || input.reasonHash == bytes32(0)) {
            revert AVACoreTypes.EmptyValue();
        }
        AVAGovernanceKernel.RecognisedStateReference memory state = _validateRecord(
            ValidationInput({
                recognisedStateId: input.recognisedStateId,
                roleKey: input.roleKey,
                authorityId: input.authorityId,
                subjectId: input.subjectId,
                evidenceId: input.evidenceId,
                recordTypeKey: input.allocationKindKey,
                actionKey: AVACoreTypes.ACTION_RECORD_ALLOCATION,
                recordClass: RecordClass.Allocation,
                signedValue: 0,
                unsignedValue: input.units
            })
        );
        id = nextAllocationId++;
        allocations[id] = AllocationRecord({
            id: id,
            recognisedStateId: state.id,
            recognisedStateTransitionId: state.lastTransitionId,
            appId: state.appId,
            workflowKey: state.workflowKey,
            packageId: state.packageId,
            subjectId: input.subjectId,
            evidenceId: input.evidenceId,
            allocationKindKey: input.allocationKindKey,
            units: input.units,
            authorityId: input.authorityId,
            reasonHash: input.reasonHash,
            uri: input.uri,
            registeredBy: msg.sender,
            registeredAt: uint64(block.timestamp)
        });
        emit AllocationRecorded(
            id, state.id, input.subjectId, state.packageId, input.allocationKindKey, input.units, msg.sender
        );
    }

    function getAllocation(uint256 id) external view returns (AllocationRecord memory record) {
        record = allocations[id];
        if (record.id == 0) revert AVACoreTypes.UnknownReference(id);
    }

    function getDownstreamSource(uint256 id)
        external
        view
        returns (IAVADownstreamRecordSource.DownstreamSourceContext memory context)
    {
        AllocationRecord memory record = allocations[id];
        if (record.id == 0) revert AVACoreTypes.UnknownReference(id);
        context = IAVADownstreamRecordSource.DownstreamSourceContext({
            id: record.id,
            sourceTypeKey: SOURCE_TYPE_KEY,
            recognisedStateId: record.recognisedStateId,
            recognisedStateTransitionId: record.recognisedStateTransitionId,
            appId: record.appId,
            workflowKey: record.workflowKey,
            packageId: record.packageId,
            subjectId: record.subjectId,
            evidenceId: record.evidenceId,
            recordTypeKey: record.allocationKindKey,
            units: record.units
        });
    }
}

contract AVAConsequenceRecordExtension is AVADownstreamRecordBase {
    bytes32 public constant SOURCE_TYPE_KEY = keccak256("ava.extension.consequence-record-source.v1");

    struct ConsequenceInput {
        uint256 recognisedStateId;
        bytes32 roleKey;
        bytes32 authorityId;
        bytes32 subjectId;
        uint256 evidenceId;
        bytes32 consequenceKindKey;
        bytes32 reasonHash;
        string uri;
    }

    struct ConsequenceRecord {
        uint256 id;
        uint256 recognisedStateId;
        uint256 recognisedStateTransitionId;
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 subjectId;
        uint256 evidenceId;
        bytes32 consequenceKindKey;
        bytes32 authorityId;
        bytes32 reasonHash;
        string uri;
        address registeredBy;
        uint64 registeredAt;
    }

    mapping(uint256 => ConsequenceRecord) private consequences;
    uint256 public nextConsequenceId = 1;

    event ConsequenceRecorded(
        uint256 indexed id,
        uint256 indexed recognisedStateId,
        bytes32 indexed subjectId,
        uint256 packageId,
        bytes32 consequenceKindKey,
        address registeredBy
    );

    constructor(
        AVAGovernanceKernel governanceKernel_,
        AVAAuthorityMatrix authorityMatrix_,
        AVAIdentityRegistry identityRegistry_,
        AVACoreRulePackageRegistry rulePackageRegistry_,
        AVAEvidenceRegistry evidenceRegistry_
    )
        AVADownstreamRecordBase(
            governanceKernel_, authorityMatrix_, identityRegistry_, rulePackageRegistry_, evidenceRegistry_
        )
    {}

    function recordConsequence(ConsequenceInput calldata input) external returns (uint256 id) {
        if (input.reasonHash == bytes32(0)) revert AVACoreTypes.EmptyValue();
        AVAGovernanceKernel.RecognisedStateReference memory state = _validateRecord(
            ValidationInput({
                recognisedStateId: input.recognisedStateId,
                roleKey: input.roleKey,
                authorityId: input.authorityId,
                subjectId: input.subjectId,
                evidenceId: input.evidenceId,
                recordTypeKey: input.consequenceKindKey,
                actionKey: AVACoreTypes.ACTION_RECORD_CONSEQUENCE,
                recordClass: RecordClass.Consequence,
                signedValue: 0,
                unsignedValue: 0
            })
        );
        id = nextConsequenceId++;
        consequences[id] = ConsequenceRecord({
            id: id,
            recognisedStateId: state.id,
            recognisedStateTransitionId: state.lastTransitionId,
            appId: state.appId,
            workflowKey: state.workflowKey,
            packageId: state.packageId,
            subjectId: input.subjectId,
            evidenceId: input.evidenceId,
            consequenceKindKey: input.consequenceKindKey,
            authorityId: input.authorityId,
            reasonHash: input.reasonHash,
            uri: input.uri,
            registeredBy: msg.sender,
            registeredAt: uint64(block.timestamp)
        });
        emit ConsequenceRecorded(id, state.id, input.subjectId, state.packageId, input.consequenceKindKey, msg.sender);
    }

    function getConsequence(uint256 id) external view returns (ConsequenceRecord memory record) {
        record = consequences[id];
        if (record.id == 0) revert AVACoreTypes.UnknownReference(id);
    }

    function getDownstreamSource(uint256 id)
        external
        view
        returns (IAVADownstreamRecordSource.DownstreamSourceContext memory context)
    {
        ConsequenceRecord memory record = consequences[id];
        if (record.id == 0) revert AVACoreTypes.UnknownReference(id);
        context = IAVADownstreamRecordSource.DownstreamSourceContext({
            id: record.id,
            sourceTypeKey: SOURCE_TYPE_KEY,
            recognisedStateId: record.recognisedStateId,
            recognisedStateTransitionId: record.recognisedStateTransitionId,
            appId: record.appId,
            workflowKey: record.workflowKey,
            packageId: record.packageId,
            subjectId: record.subjectId,
            evidenceId: record.evidenceId,
            recordTypeKey: record.consequenceKindKey,
            units: 0
        });
    }
}
