// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "./AVADataTypes.sol";
import {AuthorityMatrix} from "./AuthorityMatrix.sol";
import {RoleIdentityRegistry} from "./RoleIdentityRegistry.sol";
import {AVAStateMachine} from "./AVAStateMachine.sol";
import {EvidenceCommitmentRegistry} from "./EvidenceCommitmentRegistry.sol";
import {StandingRegistry} from "./StandingRegistry.sol";
import {AllocationExecutor} from "./AllocationExecutor.sol";
import {ConsequenceExecutor} from "./ConsequenceExecutor.sol";
import {IStandingCredentialIssuer} from "./interfaces/IStandingCredentialIssuer.sol";
import {IValueSettlementExecutor} from "./interfaces/IValueSettlementExecutor.sol";

contract StandingCredentialRegistry is IStandingCredentialIssuer {
    string private constant NAME = "AVA Standing Credential";
    string private constant SYMBOL = "AVASC";

    AuthorityMatrix private immutable AUTHORITY_MATRIX;
    AVAStateMachine private immutable STATE_MACHINE;
    EvidenceCommitmentRegistry private immutable EVIDENCE_REGISTRY;
    StandingRegistry private immutable STANDING_REGISTRY;
    AllocationExecutor private immutable ALLOCATION_EXECUTOR;
    ConsequenceExecutor private immutable CONSEQUENCE_EXECUTOR;
    IValueSettlementExecutor private immutable VALUE_SETTLEMENT_EXECUTOR;
    uint256 public nextStandingCredentialId = 1;
    uint256 public nextStandingCredentialSettlementId = 1;

    mapping(uint256 => AVADataTypes.StandingCredentialRecord) private standingCredentials;
    mapping(uint256 => AVADataTypes.StandingCredentialSettlementRecord) private standingCredentialSettlements;

    event StandingCredentialIssued(
        uint256 indexed id,
        uint256 indexed standingComputationRecordId,
        bytes32 indexed subjectId,
        bytes32 categoryHash,
        uint256 expiresAt
    );
    event StandingCredentialRevoked(uint256 indexed id, bytes32 authorityId, string uri);
    event StandingCredentialSuperseded(uint256 indexed id, uint256 indexed supersededBy, bytes32 authorityId, string uri);
    event StandingCredentialSettlementRecorded(
        uint256 indexed id,
        uint256 indexed credentialId,
        AVADataTypes.StandingRelevantSettlementKind indexed kind,
        uint256 sourceRecordId,
        uint256 settlementId
    );

    constructor(
        AuthorityMatrix authorityMatrix_,
        AVAStateMachine stateMachine_,
        EvidenceCommitmentRegistry evidenceRegistry_,
        StandingRegistry standingRegistry_,
        AllocationExecutor allocationExecutor_,
        ConsequenceExecutor consequenceExecutor_,
        IValueSettlementExecutor valueSettlementExecutor_
    ) {
        AUTHORITY_MATRIX = authorityMatrix_;
        STATE_MACHINE = stateMachine_;
        EVIDENCE_REGISTRY = evidenceRegistry_;
        STANDING_REGISTRY = standingRegistry_;
        ALLOCATION_EXECUTOR = allocationExecutor_;
        CONSEQUENCE_EXECUTOR = consequenceExecutor_;
        VALUE_SETTLEMENT_EXECUTOR = valueSettlementExecutor_;
    }

    function issueCredential(
        AVADataTypes.Role actingRole,
        StandingCredentialInput calldata input
    ) external returns (uint256 id) {
        AUTHORITY_MATRIX.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.IssueStandingCredential, input.authorityId
        );
        id = _issueCredential(actingRole, input);
    }

    function revokeCredential(
        AVADataTypes.Role actingRole,
        uint256 credentialId,
        bytes32 authorityId,
        string calldata uri
    ) external {
        AUTHORITY_MATRIX.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.RevokeStandingCredential, authorityId
        );
        AVADataTypes.StandingCredentialRecord storage credential = standingCredentials[credentialId];
        if (credential.id == 0) revert AVADataTypes.UnknownReference(credentialId);
        if (credential.status != AVADataTypes.StandingCredentialStatus.Active) {
            revert AVADataTypes.InvalidState(credentialId);
        }
        if (bytes(uri).length == 0) revert AVADataTypes.EmptyValue();
        credential.status = AVADataTypes.StandingCredentialStatus.Revoked;
        emit StandingCredentialRevoked(credentialId, authorityId, uri);
    }

    function supersedeCredential(
        AVADataTypes.Role actingRole,
        uint256 credentialId,
        StandingCredentialInput calldata input
    ) external returns (uint256 id) {
        AUTHORITY_MATRIX.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.SupersedeStandingCredential, input.authorityId
        );
        AVADataTypes.StandingCredentialRecord storage oldCredential = standingCredentials[credentialId];
        if (oldCredential.id == 0) revert AVADataTypes.UnknownReference(credentialId);
        if (oldCredential.status != AVADataTypes.StandingCredentialStatus.Active) {
            revert AVADataTypes.InvalidState(credentialId);
        }
        id = _issueCredential(actingRole, input);
        AVADataTypes.StandingCredentialRecord memory newCredential = standingCredentials[id];
        if (
            newCredential.packageId != oldCredential.packageId || newCredential.subjectId != oldCredential.subjectId
                || newCredential.vectorKey != oldCredential.vectorKey
                || newCredential.categoryHash != oldCredential.categoryHash
                || keccak256(bytes(newCredential.dimension)) != keccak256(bytes(oldCredential.dimension))
                || newCredential.computationRuleHash != oldCredential.computationRuleHash
                || newCredential.epoch <= oldCredential.epoch
        ) {
            revert AVADataTypes.InvalidState(credentialId);
        }
        oldCredential.status = AVADataTypes.StandingCredentialStatus.Superseded;
        oldCredential.supersededBy = id;
        emit StandingCredentialSuperseded(credentialId, id, input.authorityId, input.uri);
    }

    function recordStandingRelevantSettlement(
        AVADataTypes.Role actingRole,
        uint256 credentialId,
        AVADataTypes.StandingRelevantSettlementKind kind,
        AVADataTypes.ExecutionSourceType sourceType,
        uint256 sourceRecordId,
        uint256 settlementId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        AUTHORITY_MATRIX.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.RecordStandingCredentialSettlement, authorityId
        );
        if (
            kind == AVADataTypes.StandingRelevantSettlementKind.None
                || sourceType == AVADataTypes.ExecutionSourceType.None || sourceRecordId == 0 || settlementId == 0
                || authorityId == bytes32(0) || bytes(uri).length == 0
        ) {
            revert AVADataTypes.EmptyValue();
        }
        AVADataTypes.StandingCredentialRecord storage credential = standingCredentials[credentialId];
        if (credential.id == 0) revert AVADataTypes.UnknownReference(credentialId);
        if (credential.status != AVADataTypes.StandingCredentialStatus.Active) {
            revert AVADataTypes.InvalidState(credentialId);
        }
        _requireBoundSource(credential, sourceType, sourceRecordId);
        _requireBoundSettlement(credential, kind, sourceType, sourceRecordId, settlementId);

        id = nextStandingCredentialSettlementId++;
        standingCredentialSettlements[id] = AVADataTypes.StandingCredentialSettlementRecord({
            id: id,
            credentialId: credentialId,
            subjectId: credential.subjectId,
            packageId: credential.packageId,
            kind: kind,
            sourceType: sourceType,
            sourceRecordId: sourceRecordId,
            settlementId: settlementId,
            authorityRole: actingRole,
            authorityId: authorityId,
            uri: uri,
            recordedBy: msg.sender
        });
        credential.status = AVADataTypes.StandingCredentialStatus.Suspended;
        emit StandingCredentialSettlementRecorded(id, credentialId, kind, sourceRecordId, settlementId);
    }

    function getStandingCredential(uint256 id) external view returns (AVADataTypes.StandingCredentialRecord memory) {
        AVADataTypes.StandingCredentialRecord memory credential = standingCredentials[id];
        if (credential.id == 0) revert AVADataTypes.UnknownReference(id);
        return credential;
    }

    function getStandingCredentialSettlement(uint256 id)
        external
        view
        returns (AVADataTypes.StandingCredentialSettlementRecord memory)
    {
        AVADataTypes.StandingCredentialSettlementRecord memory record = standingCredentialSettlements[id];
        if (record.id == 0) revert AVADataTypes.UnknownReference(id);
        return record;
    }

    function credentialProves(
        uint256 credentialId,
        bytes32 subjectId,
        bytes32 vectorKey,
        bytes32 categoryHash,
        int256 requiredThreshold
    ) external view returns (bool) {
        AVADataTypes.StandingCredentialRecord memory credential = standingCredentials[credentialId];
        if (credential.id == 0) return false;
        if (!_isActiveCredential(credential)) return false;
        return credential.subjectId == subjectId && credential.vectorKey == vectorKey
            && credential.categoryHash == categoryHash && credential.standingValue >= requiredThreshold
            && requiredThreshold >= credential.lowerBound && requiredThreshold <= credential.upperBound;
    }

    function credentialProvesSubjectStanding(
        uint256 credentialId,
        uint256 packageId,
        bytes32 subjectId,
        bytes32 vectorKey,
        bytes32 categoryHash,
        int256 requiredThreshold
    ) external view returns (bool) {
        AVADataTypes.StandingCredentialRecord memory credential = standingCredentials[credentialId];
        if (credential.id == 0) return false;
        if (!_isActiveCredential(credential)) return false;
        return credential.packageId == packageId && credential.subjectId == subjectId
            && credential.vectorKey == vectorKey && credential.categoryHash == categoryHash
            && credential.standingValue >= requiredThreshold && requiredThreshold >= credential.lowerBound
            && requiredThreshold <= credential.upperBound;
    }

    function isCredentialActive(uint256 credentialId) external view returns (bool) {
        AVADataTypes.StandingCredentialRecord memory credential = standingCredentials[credentialId];
        if (credential.id == 0) return false;
        return _isActiveCredential(credential);
    }

    function authorityMatrix() external view returns (AuthorityMatrix) {
        return AUTHORITY_MATRIX;
    }

    function stateMachine() external view returns (AVAStateMachine) {
        return STATE_MACHINE;
    }

    function evidenceRegistry() external view returns (EvidenceCommitmentRegistry) {
        return EVIDENCE_REGISTRY;
    }

    function standingRegistry() external view returns (StandingRegistry) {
        return STANDING_REGISTRY;
    }

    function valueSettlementExecutor() external view returns (IValueSettlementExecutor) {
        return VALUE_SETTLEMENT_EXECUTOR;
    }

    function name() external pure returns (string memory) {
        return NAME;
    }

    function symbol() external pure returns (string memory) {
        return SYMBOL;
    }

    function tokenURI(uint256 credentialId) external view returns (string memory) {
        AVADataTypes.StandingCredentialRecord memory credential = standingCredentials[credentialId];
        if (credential.id == 0) revert AVADataTypes.UnknownReference(credentialId);
        return credential.uri;
    }

    function transferFrom(address, address, uint256 credentialId) external pure {
        revert AVADataTypes.InvalidState(credentialId);
    }

    function safeTransferFrom(address, address, uint256 credentialId) external pure {
        revert AVADataTypes.InvalidState(credentialId);
    }

    function safeTransferFrom(address, address, uint256 credentialId, bytes calldata) external pure {
        revert AVADataTypes.InvalidState(credentialId);
    }

    function approve(address, uint256 credentialId) external pure {
        revert AVADataTypes.InvalidState(credentialId);
    }

    function setApprovalForAll(address, bool) external pure {
        revert AVADataTypes.InvalidState(0);
    }

    function getApproved(uint256 credentialId) external view returns (address) {
        if (standingCredentials[credentialId].id == 0) revert AVADataTypes.UnknownReference(credentialId);
        return address(0);
    }

    function isApprovedForAll(address, address) external pure returns (bool) {
        return false;
    }

    function _issueCredential(
        AVADataTypes.Role actingRole,
        StandingCredentialInput calldata input
    ) internal returns (uint256 id) {
        if (
            input.standingComputationRecordId == 0 || input.categoryHash == bytes32(0) || input.epoch == 0
                || input.expiresAt <= block.timestamp || input.computationRuleHash == bytes32(0)
                || input.authorityId == bytes32(0) || bytes(input.uri).length == 0 || input.lowerBound > input.upperBound
                || input.threshold < input.lowerBound || input.threshold > input.upperBound
        ) {
            revert AVADataTypes.EmptyValue();
        }
        AVADataTypes.StandingComputationRecord memory computation =
            STANDING_REGISTRY.getStandingComputationRecord(input.standingComputationRecordId);
        if (
            computation.status != AVADataTypes.StandingComputationStatus.Active || input.epoch != computation.epoch
                || input.computationRuleHash != computation.computationRuleHash
        ) {
            revert AVADataTypes.InvalidState(input.standingComputationRecordId);
        }
        if (
            computation.currentValue < input.threshold || computation.currentValue < input.lowerBound
                || computation.currentValue > input.upperBound
        ) {
            revert AVADataTypes.InvalidState(input.standingComputationRecordId);
        }
        AUTHORITY_MATRIX.requireKnownActiveSubject(computation.subjectId);
        AVADataTypes.RecognisedStateRecord memory recognisedState =
            STATE_MACHINE.getRecognisedState(computation.recognisedStateId);
        if (recognisedState.packageId != computation.packageId) {
            revert AVADataTypes.InvalidState(computation.recognisedStateId);
        }
        AVADataTypes.EvidenceReceipt memory evidence =
            EVIDENCE_REGISTRY.requireUsableEvidenceReceipt(computation.evidenceReceiptId, recognisedState.workflowKey);
        if (evidence.packageId != recognisedState.packageId) revert AVADataTypes.InvalidState(computation.evidenceReceiptId);

        RoleIdentityRegistry roleRegistry = AUTHORITY_MATRIX.roleRegistry();
        AVADataTypes.RoleSubject memory subject = roleRegistry.getSubject(computation.subjectId);
        if (!subject.active || subject.account == address(0)) revert AVADataTypes.UnknownSubject(computation.subjectId);

        id = nextStandingCredentialId++;
        standingCredentials[id] = AVADataTypes.StandingCredentialRecord({
            id: id,
            standingComputationRecordId: input.standingComputationRecordId,
            recognisedStateId: computation.recognisedStateId,
            workflowKey: recognisedState.workflowKey,
            packageId: computation.packageId,
            subjectId: computation.subjectId,
            holder: subject.account,
            dimension: computation.dimension,
            vectorKey: computation.vectorKey,
            categoryHash: input.categoryHash,
            standingValue: computation.currentValue,
            threshold: input.threshold,
            lowerBound: input.lowerBound,
            upperBound: input.upperBound,
            epoch: input.epoch,
            issuedAt: block.timestamp,
            expiresAt: input.expiresAt,
            computationRuleHash: input.computationRuleHash,
            evidenceReceiptId: computation.evidenceReceiptId,
            authorityRole: actingRole,
            authorityId: input.authorityId,
            status: AVADataTypes.StandingCredentialStatus.Active,
            supersededBy: 0,
            uri: input.uri,
            issuedBy: msg.sender
        });
        emit StandingCredentialIssued(
            id, input.standingComputationRecordId, computation.subjectId, input.categoryHash, input.expiresAt
        );
    }

    function _isActiveCredential(AVADataTypes.StandingCredentialRecord memory credential) internal view returns (bool) {
        return credential.status == AVADataTypes.StandingCredentialStatus.Active && block.timestamp < credential.expiresAt
            && STANDING_REGISTRY.isStandingComputationActive(credential.standingComputationRecordId);
    }

    function _requireBoundSource(
        AVADataTypes.StandingCredentialRecord storage credential,
        AVADataTypes.ExecutionSourceType sourceType,
        uint256 sourceRecordId
    ) internal view {
        bytes32 sourceSubjectId;
        uint256 sourcePackageId;
        if (sourceType == AVADataTypes.ExecutionSourceType.AllocationRecord) {
            AVADataTypes.AllocationExecutionRecord memory allocation =
                ALLOCATION_EXECUTOR.getAllocationExecution(sourceRecordId);
            sourceSubjectId = allocation.subjectId;
            sourcePackageId = allocation.packageId;
        } else if (sourceType == AVADataTypes.ExecutionSourceType.ConsequenceRecord) {
            AVADataTypes.ConsequenceRecord memory consequence = CONSEQUENCE_EXECUTOR.getConsequence(sourceRecordId);
            sourceSubjectId = consequence.subjectId;
            sourcePackageId = consequence.packageId;
        } else {
            revert AVADataTypes.InvalidState(uint256(sourceType));
        }
        if (sourceSubjectId != credential.subjectId || sourcePackageId != credential.packageId) {
            revert AVADataTypes.InvalidState(sourceRecordId);
        }
    }

    function _requireBoundSettlement(
        AVADataTypes.StandingCredentialRecord storage credential,
        AVADataTypes.StandingRelevantSettlementKind kind,
        AVADataTypes.ExecutionSourceType sourceType,
        uint256 sourceRecordId,
        uint256 settlementId
    ) internal view {
        AVADataTypes.ValueSettlementRecord memory settlement =
            VALUE_SETTLEMENT_EXECUTOR.getValueSettlement(settlementId);
        if (
            settlement.sourceType != sourceType || settlement.sourceRecordId != sourceRecordId
                || settlement.subjectId != credential.subjectId || settlement.packageId != credential.packageId
        ) {
            revert AVADataTypes.InvalidState(settlementId);
        }
        if (!_standingSettlementKindMatches(kind, settlement.kind)) {
            revert AVADataTypes.InvalidState(settlementId);
        }
    }

    function _standingSettlementKindMatches(
        AVADataTypes.StandingRelevantSettlementKind kind,
        AVADataTypes.ValueSettlementKind settlementKind
    ) internal pure returns (bool) {
        if (kind == AVADataTypes.StandingRelevantSettlementKind.RewardExecution) {
            return settlementKind == AVADataTypes.ValueSettlementKind.TokenTransfer
                || settlementKind == AVADataTypes.ValueSettlementKind.EscrowClaim;
        }
        if (kind == AVADataTypes.StandingRelevantSettlementKind.RepaymentObligation) {
            return settlementKind == AVADataTypes.ValueSettlementKind.RepaymentObligation;
        }
        if (kind == AVADataTypes.StandingRelevantSettlementKind.FuturePayoutSetoff) {
            return settlementKind == AVADataTypes.ValueSettlementKind.FuturePayoutSetoff;
        }
        if (kind == AVADataTypes.StandingRelevantSettlementKind.Waiver) {
            return settlementKind == AVADataTypes.ValueSettlementKind.Waiver;
        }
        if (kind == AVADataTypes.StandingRelevantSettlementKind.Satisfaction) {
            return settlementKind == AVADataTypes.ValueSettlementKind.Satisfaction;
        }
        return false;
    }
}
