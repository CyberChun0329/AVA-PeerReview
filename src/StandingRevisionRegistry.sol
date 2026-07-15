// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "./AVADataTypes.sol";
import {AuthorityMatrix} from "./AuthorityMatrix.sol";
import {AVARulePackageRegistry} from "./AVARulePackageRegistry.sol";
import {EvidenceCommitmentRegistry} from "./EvidenceCommitmentRegistry.sol";

/// @notice Append-only revision watermarks for package-bound, role-scoped standing history.
/// @dev A revision signals changed governance memory. It does not compute standing or create value.
contract StandingRevisionRegistry {
    enum WriterKind {
        None,
        StateMachine,
        ChallengeWorkflow,
        StandingRegistry,
        ConsequenceExecutor,
        ValueSettlementExecutor
    }

    struct StandingCommitmentRevisionInput {
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 subjectCommitment;
        uint256 evidenceReceiptId;
        bytes32 authorityId;
        string uri;
    }

    struct StandingCommitmentRevisionRecord {
        uint256 id;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 subjectCommitment;
        uint256 previousRevision;
        uint256 revision;
        uint256 evidenceReceiptId;
        AVADataTypes.Role authorityRole;
        bytes32 authorityId;
        string uri;
        address recordedBy;
    }

    address public immutable admin;
    AuthorityMatrix public immutable authorityMatrix;
    AVARulePackageRegistry public immutable rulePackageRegistry;
    EvidenceCommitmentRegistry public immutable evidenceRegistry;
    uint256 public nextStandingRevisionRecordId = 1;
    uint256 public nextStandingCommitmentRevisionRecordId = 1;

    mapping(WriterKind => address) public writerForKind;
    mapping(address => WriterKind) public writerKindOf;
    mapping(uint256 => mapping(bytes32 => uint256)) private revisions;
    mapping(uint256 => AVADataTypes.StandingRevisionRecord) private revisionRecords;
    mapping(uint256 => StandingCommitmentRevisionRecord) private commitmentRevisionRecords;
    mapping(bytes32 => uint256) private commitmentRevisionRecordIdByEvidenceKey;

    event StandingRevisionWriterBound(WriterKind indexed kind, address indexed writer);
    event StandingRevisionAdvanced(
        uint256 indexed id,
        uint256 indexed packageId,
        bytes32 indexed subjectId,
        uint256 revision,
        AVADataTypes.StandingRevisionReason reason,
        uint256 sourceRecordId
    );
    event StandingCommitmentRevisionRecorded(
        uint256 indexed id,
        uint256 indexed packageId,
        bytes32 indexed subjectCommitment,
        uint256 previousRevision,
        uint256 revision,
        uint256 evidenceReceiptId
    );

    constructor(
        AuthorityMatrix authorityMatrix_,
        AVARulePackageRegistry rulePackageRegistry_,
        EvidenceCommitmentRegistry evidenceRegistry_
    ) {
        if (
            address(authorityMatrix_) == address(0) || address(rulePackageRegistry_) == address(0)
                || address(evidenceRegistry_) == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
        admin = msg.sender;
        authorityMatrix = authorityMatrix_;
        rulePackageRegistry = rulePackageRegistry_;
        evidenceRegistry = evidenceRegistry_;
    }

    function bindWriter(WriterKind kind, address writer) external {
        if (msg.sender != admin) revert AVADataTypes.NotAdmin(msg.sender);
        if (
            kind == WriterKind.None || writer == address(0) || writer.code.length == 0
                || writerForKind[kind] != address(0) || writerKindOf[writer] != WriterKind.None
        ) {
            revert AVADataTypes.InvalidState(uint256(kind));
        }
        writerForKind[kind] = writer;
        writerKindOf[writer] = kind;
        emit StandingRevisionWriterBound(kind, writer);
    }

    function advanceRevision(
        uint256 packageId,
        bytes32 subjectId,
        AVADataTypes.StandingRevisionReason reason,
        uint256 sourceRecordId
    ) external returns (uint256 revision, uint256 recordId) {
        WriterKind writerKind = writerKindOf[msg.sender];
        if (!_reasonAllowed(writerKind, reason)) {
            revert AVADataTypes.NotAuthorised(msg.sender, AVADataTypes.Action.RecordStandingUpdate);
        }
        if (packageId == 0 || subjectId == bytes32(0) || sourceRecordId == 0) {
            revert AVADataTypes.EmptyValue();
        }

        return _advanceRevision(packageId, subjectId, reason, sourceRecordId, msg.sender);
    }

    function recordStandingCommitmentRevision(
        AVADataTypes.Role actingRole,
        StandingCommitmentRevisionInput calldata input
    ) external returns (uint256 recordId, uint256 revision) {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.RecordStandingCommitmentRevision, input.authorityId
        );
        if (
            input.workflowKey == bytes32(0) || input.packageId == 0 || input.subjectCommitment == bytes32(0)
                || input.evidenceReceiptId == 0 || input.authorityId == bytes32(0) || bytes(input.uri).length == 0
        ) {
            revert AVADataTypes.EmptyValue();
        }
        if (authorityMatrix.roleRegistry().isKnownActiveSubject(input.subjectCommitment)) {
            revert AVADataTypes.InvalidState(uint256(input.subjectCommitment));
        }
        AVARulePackageRegistry.RulePackage memory rulePackage = rulePackageRegistry.getRulePackageById(input.packageId);
        if (rulePackage.workflowKey != input.workflowKey) revert AVADataTypes.InvalidState(input.packageId);
        AVADataTypes.EvidenceReceipt memory evidence = evidenceRegistry.requireUsableEvidenceReceipt(
            input.evidenceReceiptId, rulePackage.appId, input.workflowKey
        );
        if (evidence.packageId != input.packageId) revert AVADataTypes.InvalidState(input.evidenceReceiptId);
        rulePackage.evidenceLifecycleModule
            .validateEvidenceLifecycle(
                input.workflowKey,
                AVADataTypes.Action.RecordStandingCommitmentRevision,
                input.evidenceReceiptId,
                AVADataTypes.EvidenceLifecycleKind.None,
                0,
                bytes32(0),
                msg.sender
            );

        bytes32 evidenceKey = keccak256(abi.encode(input.packageId, input.subjectCommitment, input.evidenceReceiptId));
        uint256 existingRecordId = commitmentRevisionRecordIdByEvidenceKey[evidenceKey];
        if (existingRecordId != 0) revert AVADataTypes.InvalidState(existingRecordId);

        uint256 previousRevision = revisions[input.packageId][input.subjectCommitment];
        recordId = nextStandingCommitmentRevisionRecordId++;
        (revision,) = _advanceRevision(
            input.packageId,
            input.subjectCommitment,
            AVADataTypes.StandingRevisionReason.CommitmentRevision,
            recordId,
            msg.sender
        );
        commitmentRevisionRecords[recordId] = StandingCommitmentRevisionRecord({
            id: recordId,
            workflowKey: input.workflowKey,
            packageId: input.packageId,
            subjectCommitment: input.subjectCommitment,
            previousRevision: previousRevision,
            revision: revision,
            evidenceReceiptId: input.evidenceReceiptId,
            authorityRole: actingRole,
            authorityId: input.authorityId,
            uri: input.uri,
            recordedBy: msg.sender
        });
        commitmentRevisionRecordIdByEvidenceKey[evidenceKey] = recordId;
        emit StandingCommitmentRevisionRecorded(
            recordId, input.packageId, input.subjectCommitment, previousRevision, revision, input.evidenceReceiptId
        );
    }

    function currentRevision(uint256 packageId, bytes32 subjectId) external view returns (uint256) {
        return revisions[packageId][subjectId];
    }

    function getStandingRevisionRecord(uint256 id) external view returns (AVADataTypes.StandingRevisionRecord memory) {
        AVADataTypes.StandingRevisionRecord memory record = revisionRecords[id];
        if (record.id == 0) revert AVADataTypes.UnknownReference(id);
        return record;
    }

    function getStandingCommitmentRevisionRecord(uint256 id)
        external
        view
        returns (StandingCommitmentRevisionRecord memory)
    {
        StandingCommitmentRevisionRecord memory record = commitmentRevisionRecords[id];
        if (record.id == 0) revert AVADataTypes.UnknownReference(id);
        return record;
    }

    function _advanceRevision(
        uint256 packageId,
        bytes32 subjectId,
        AVADataTypes.StandingRevisionReason reason,
        uint256 sourceRecordId,
        address recordedBy
    ) internal returns (uint256 revision, uint256 recordId) {
        revision = revisions[packageId][subjectId] + 1;
        revisions[packageId][subjectId] = revision;
        recordId = nextStandingRevisionRecordId++;
        revisionRecords[recordId] = AVADataTypes.StandingRevisionRecord({
            id: recordId,
            packageId: packageId,
            subjectId: subjectId,
            revision: revision,
            reason: reason,
            sourceRecordId: sourceRecordId,
            recordedBy: recordedBy
        });
        emit StandingRevisionAdvanced(recordId, packageId, subjectId, revision, reason, sourceRecordId);
    }

    function _reasonAllowed(WriterKind writerKind, AVADataTypes.StandingRevisionReason reason)
        internal
        pure
        returns (bool)
    {
        if (writerKind == WriterKind.StateMachine) {
            return reason == AVADataTypes.StandingRevisionReason.RecognisedStateTransition;
        }
        if (writerKind == WriterKind.ChallengeWorkflow) {
            return reason == AVADataTypes.StandingRevisionReason.ChallengeResolution;
        }
        if (writerKind == WriterKind.StandingRegistry) {
            return reason == AVADataTypes.StandingRevisionReason.StandingUpdate;
        }
        if (writerKind == WriterKind.ConsequenceExecutor) {
            return reason == AVADataTypes.StandingRevisionReason.StandingPenalty
                || reason == AVADataTypes.StandingRevisionReason.EligibilityRestriction;
        }
        if (writerKind == WriterKind.ValueSettlementExecutor) {
            return reason == AVADataTypes.StandingRevisionReason.RewardSettlement
                || reason == AVADataTypes.StandingRevisionReason.RecoverySettlement;
        }
        return false;
    }
}
