// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "./AVADataTypes.sol";
import {AVAStateMachine} from "./AVAStateMachine.sol";
import {AVAChallengeWorkflow} from "./AVAChallengeWorkflow.sol";
import {AuthorityMatrix} from "./AuthorityMatrix.sol";
import {ValueSettlementExecutor} from "./ValueSettlementExecutor.sol";
import {ZKStandingComputationRegistry} from "./ZKStandingComputationRegistry.sol";
import {IZKStandingCredentialIssuer} from "./interfaces/IZKStandingCredentialIssuer.sol";
import {IZKProofVerifier} from "./interfaces/IZKProofVerifier.sol";
import {StandingRevisionRegistry} from "./StandingRevisionRegistry.sol";
import {AVARulePackageRegistry} from "./AVARulePackageRegistry.sol";
import {IStandingFormulaRegistry} from "./interfaces/IStandingFormulaRegistry.sol";

contract ZKStandingCredentialRegistry is IZKStandingCredentialIssuer {
    uint256 public constant MAX_CREDENTIAL_VALIDITY = 365 days;
    bytes32 public constant STANDING_CREDENTIAL_USE_CONTEXT_DOMAIN =
        keccak256("AVA_ZK_STANDING_CREDENTIAL_USE_CONTEXT_V1");
    bytes32 public constant STANDING_CREDENTIAL_USE_NULLIFIER_DOMAIN =
        keccak256("AVA_ZK_STANDING_CREDENTIAL_USE_NULLIFIER_V1");

    struct SuspensionDraft {
        ZKStandingCredentialSuspensionSourceKind sourceKind;
        AVADataTypes.StandingRelevantSettlementKind standingKind;
        AVADataTypes.ExecutionSourceType settlementSourceType;
        uint256 sourceRecordId;
        uint256 settlementId;
        uint256 challengeTransitionId;
        AVADataTypes.ChallengeOutcome challengeOutcome;
    }

    struct SettlementSuspensionRequest {
        AVADataTypes.StandingRelevantSettlementKind kind;
        AVADataTypes.ExecutionSourceType sourceType;
        uint256 sourceRecordId;
        uint256 settlementId;
        bytes32 authorityId;
    }

    AuthorityMatrix public immutable authorityMatrix;
    ZKStandingComputationRegistry public immutable zkStandingComputationRegistry;
    ValueSettlementExecutor public immutable valueSettlementExecutor;
    AVAStateMachine public immutable stateMachine;
    AVAChallengeWorkflow public immutable challengeWorkflow;
    StandingRevisionRegistry public immutable standingRevisionRegistry;

    uint256 public nextCredentialId = 1;
    uint256 public nextCredentialUseRecordId = 1;
    uint256 public nextCredentialSuspensionRecordId = 1;

    mapping(uint256 => ZKStandingCredentialRecord) private credentials;
    mapping(uint256 => ZKStandingCredentialUseRecord) private credentialUseRecords;
    mapping(uint256 => ZKStandingCredentialSuspensionRecord) private credentialSuspensionRecords;
    mapping(bytes32 => uint256) private credentialIdByCommitment;
    mapping(bytes32 => uint256) private credentialIdByNullifier;
    mapping(bytes32 => uint256) private useRecordIdByNullifier;

    event ZKStandingCredentialIssued(
        uint256 indexed id,
        uint256 indexed standingProofReceiptId,
        bytes32 indexed subjectCommitment,
        uint256 packageId,
        bytes32 credentialCommitment,
        bytes32 vectorKey,
        bytes32 categoryHash,
        uint256 expiresAt
    );
    event ZKStandingCredentialRevoked(uint256 indexed id, bytes32 indexed subjectCommitment, bytes32 authorityId);
    event ZKStandingCredentialSuperseded(
        uint256 indexed id, uint256 indexed supersededBy, bytes32 indexed subjectCommitment, bytes32 authorityId
    );
    event ZKStandingCredentialSuspended(
        uint256 indexed id, bytes32 indexed subjectCommitment, bytes32 indexed suspensionReference, bytes32 authorityId
    );
    event ZKStandingCredentialSourceBoundSuspensionRecorded(
        uint256 indexed id,
        uint256 indexed credentialId,
        ZKStandingCredentialSuspensionSourceKind indexed sourceKind,
        uint256 packageId,
        bytes32 subjectCommitment
    );
    event ZKStandingCredentialUsed(
        uint256 indexed id,
        uint256 indexed credentialId,
        bytes32 indexed proofUseNullifierHash,
        bytes32 targetContextHash
    );

    constructor(
        AuthorityMatrix authorityMatrix_,
        ZKStandingComputationRegistry zkStandingComputationRegistry_,
        ValueSettlementExecutor valueSettlementExecutor_,
        AVAStateMachine stateMachine_,
        AVAChallengeWorkflow challengeWorkflow_,
        StandingRevisionRegistry standingRevisionRegistry_
    ) {
        if (
            address(authorityMatrix_) == address(0) || address(zkStandingComputationRegistry_) == address(0)
                || address(valueSettlementExecutor_) == address(0) || address(stateMachine_) == address(0)
                || address(challengeWorkflow_) == address(0) || address(standingRevisionRegistry_) == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
        authorityMatrix = authorityMatrix_;
        zkStandingComputationRegistry = zkStandingComputationRegistry_;
        valueSettlementExecutor = valueSettlementExecutor_;
        stateMachine = stateMachine_;
        challengeWorkflow = challengeWorkflow_;
        standingRevisionRegistry = standingRevisionRegistry_;
    }

    function issueCredential(AVADataTypes.Role actingRole, ZKStandingCredentialInput calldata input)
        external
        returns (uint256 id)
    {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.IssueStandingCredential, input.authorityId
        );
        id = _issueCredential(actingRole, input, AVADataTypes.Action.IssueStandingCredential);
    }

    function revokeCredential(
        AVADataTypes.Role actingRole,
        uint256 credentialId,
        bytes32 subjectCommitment,
        bytes32 authorityId,
        string calldata uri
    ) external {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.RevokeStandingCredential, authorityId
        );
        ZKStandingCredentialRecord storage credential = credentials[credentialId];
        _requireActiveCredential(credential, credentialId);
        if (credential.subjectCommitment != subjectCommitment || bytes(uri).length == 0) {
            revert AVADataTypes.InvalidState(credentialId);
        }
        credential.status = AVADataTypes.StandingCredentialStatus.Revoked;
        credential.statusReference = keccak256(bytes(uri));
        credential.statusURI = uri;
        emit ZKStandingCredentialRevoked(credentialId, subjectCommitment, authorityId);
    }

    function supersedeCredential(
        AVADataTypes.Role actingRole,
        uint256 credentialId,
        ZKStandingCredentialInput calldata input
    ) external returns (uint256 id) {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.SupersedeStandingCredential, input.authorityId
        );
        ZKStandingCredentialRecord storage oldCredential = credentials[credentialId];
        _requireActiveCredential(oldCredential, credentialId);
        id = _issueCredential(actingRole, input, AVADataTypes.Action.SupersedeStandingCredential);
        ZKStandingCredentialRecord memory newCredential = credentials[id];
        if (
            newCredential.packageId != oldCredential.packageId
                || newCredential.subjectCommitment != oldCredential.subjectCommitment
                || newCredential.vectorKey != oldCredential.vectorKey
                || newCredential.categoryHash != oldCredential.categoryHash
                || newCredential.epoch <= oldCredential.epoch
        ) {
            revert AVADataTypes.InvalidState(credentialId);
        }
        oldCredential.status = AVADataTypes.StandingCredentialStatus.Superseded;
        oldCredential.supersededBy = id;
        oldCredential.statusReference = bytes32(id);
        oldCredential.statusURI = input.uri;
        emit ZKStandingCredentialSuperseded(credentialId, id, input.subjectCommitment, input.authorityId);
    }

    function recordSettlementBoundSuspension(
        AVADataTypes.Role actingRole,
        uint256 credentialId,
        AVADataTypes.StandingRelevantSettlementKind kind,
        AVADataTypes.ExecutionSourceType sourceType,
        uint256 sourceRecordId,
        uint256 settlementId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.RecordStandingCredentialSettlement, authorityId
        );
        SettlementSuspensionRequest memory request;
        request.kind = kind;
        request.sourceType = sourceType;
        request.sourceRecordId = sourceRecordId;
        request.settlementId = settlementId;
        request.authorityId = authorityId;
        id = _recordSettlementBoundSuspension(actingRole, credentialId, request, uri);
    }

    function recordChallengeTransitionBoundSuspension(
        AVADataTypes.Role actingRole,
        uint256 credentialId,
        uint256 challengeTransitionId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.RecordStandingCredentialSettlement, authorityId
        );
        if (challengeTransitionId == 0 || authorityId == bytes32(0) || bytes(uri).length == 0) {
            revert AVADataTypes.EmptyValue();
        }
        ZKStandingCredentialRecord storage credential = credentials[credentialId];
        _requireActiveCredential(credential, credentialId);
        AVADataTypes.ChallengeTransitionRecord memory transition =
            challengeWorkflow.getChallengeTransition(challengeTransitionId);
        AVADataTypes.ChallengeRecord memory challenge = challengeWorkflow.getChallenge(transition.challengeId);
        if (
            transition.transitionKind != AVADataTypes.ChallengeTransitionKind.OutcomeResolved
                || transition.packageId != credential.packageId || transition.outcome != challenge.outcome
                || challenge.challengerSubjectId != credential.subjectCommitment
                || (transition.outcome != AVADataTypes.ChallengeOutcome.Negligent
                    && transition.outcome != AVADataTypes.ChallengeOutcome.MaliciousOrFabricated)
        ) {
            revert AVADataTypes.InvalidState(credentialId);
        }
        id = _recordSourceBoundSuspension(
            credential,
            actingRole,
            authorityId,
            uri,
            SuspensionDraft({
                sourceKind: ZKStandingCredentialSuspensionSourceKind.ChallengeTransition,
                standingKind: AVADataTypes.StandingRelevantSettlementKind.StandingPenaltyInput,
                settlementSourceType: AVADataTypes.ExecutionSourceType.None,
                sourceRecordId: 0,
                settlementId: 0,
                challengeTransitionId: challengeTransitionId,
                challengeOutcome: transition.outcome
            })
        );
    }

    function credentialProves(
        uint256 credentialId,
        uint256 packageId,
        bytes32 subjectCommitment,
        bytes32 vectorKey,
        bytes32 categoryHash,
        int256 requiredThreshold
    ) public view returns (bool) {
        ZKStandingCredentialRecord memory credential = credentials[credentialId];
        if (!_isActiveCredential(credential)) return false;
        if (!_isSubjectLifecycleCompatible(subjectCommitment)) return false;
        if (!zkStandingComputationRegistry.standingProofSupportsCredential(
                credential.standingProofReceiptId,
                packageId,
                subjectCommitment,
                vectorKey,
                categoryHash,
                requiredThreshold
            )) {
            return false;
        }
        return credential.packageId == packageId && credential.subjectCommitment == subjectCommitment
            && credential.standingRevision
                == standingRevisionRegistry.currentRevision(credential.packageId, credential.subjectCommitment)
            && credential.vectorKey == vectorKey && credential.categoryHash == categoryHash
            && credential.threshold >= requiredThreshold && requiredThreshold >= credential.lowerBound
            && requiredThreshold <= credential.upperBound;
    }

    function recordCredentialUse(
        ZKStandingCredentialUseInput calldata input,
        IZKProofVerifier.SchnorrProof calldata proof
    ) external returns (uint256 id) {
        ZKStandingCredentialRecord memory credential = credentials[input.credentialId];
        bytes32 useContextHash = computeCredentialUseContextHash(
            input.credentialId,
            input.packageId,
            input.subjectCommitment,
            input.vectorKey,
            input.categoryHash,
            input.requiredThreshold,
            input.targetContextHash,
            input.beneficiary
        );
        if (
            useContextHash == bytes32(0) || input.proofUseNullifierHash == bytes32(0)
                || input.beneficiary != msg.sender
                || useRecordIdByNullifier[input.proofUseNullifierHash] != 0
                || input.proofUseNullifierHash
                    != computeCredentialUseNullifierHash(useContextHash, credential.credentialCommitment)
                || computeCredentialCommitment(proof.publicKey) != credential.credentialCommitment
                || !zkStandingComputationRegistry.verifier().verify(useContextHash, proof)
                || !credentialProves(
                    input.credentialId,
                    input.packageId,
                    input.subjectCommitment,
                    input.vectorKey,
                    input.categoryHash,
                    input.requiredThreshold
                )
        ) {
            revert AVADataTypes.InvalidState(input.credentialId);
        }
        id = nextCredentialUseRecordId++;
        credentialUseRecords[id] = ZKStandingCredentialUseRecord({
            id: id,
            credentialId: input.credentialId,
            packageId: input.packageId,
            subjectCommitment: input.subjectCommitment,
            vectorKey: input.vectorKey,
            categoryHash: input.categoryHash,
            requiredThreshold: input.requiredThreshold,
            targetContextHash: input.targetContextHash,
            proofUseNullifierHash: input.proofUseNullifierHash,
            usedBy: msg.sender
        });
        useRecordIdByNullifier[input.proofUseNullifierHash] = id;
        emit ZKStandingCredentialUsed(id, input.credentialId, input.proofUseNullifierHash, input.targetContextHash);
    }

    function computeCredentialCommitment(IZKProofVerifier.G1Point calldata publicKey) public pure returns (bytes32) {
        return keccak256(abi.encode(publicKey.x, publicKey.y));
    }

    function computeCredentialUseContextHash(
        uint256 credentialId,
        uint256 packageId,
        bytes32 subjectCommitment,
        bytes32 vectorKey,
        bytes32 categoryHash,
        int256 requiredThreshold,
        bytes32 targetContextHash,
        address beneficiary
    ) public view returns (bytes32) {
        if (
            credentialId == 0 || packageId == 0 || subjectCommitment == bytes32(0) || vectorKey == bytes32(0)
                || categoryHash == bytes32(0) || targetContextHash == bytes32(0) || beneficiary == address(0)
        ) {
            return bytes32(0);
        }
        return keccak256(
            abi.encode(
                STANDING_CREDENTIAL_USE_CONTEXT_DOMAIN,
                keccak256(
                    abi.encode(block.chainid, address(this), address(zkStandingComputationRegistry.verifier()))
                ),
                credentialId,
                packageId,
                subjectCommitment,
                vectorKey,
                categoryHash,
                requiredThreshold,
                targetContextHash,
                beneficiary
            )
        );
    }

    function computeCredentialUseNullifierHash(bytes32 useContextHash, bytes32 credentialCommitment)
        public
        pure
        returns (bytes32)
    {
        if (useContextHash == bytes32(0) || credentialCommitment == bytes32(0)) return bytes32(0);
        return keccak256(abi.encode(STANDING_CREDENTIAL_USE_NULLIFIER_DOMAIN, useContextHash, credentialCommitment));
    }

    function getCredential(uint256 id) external view returns (ZKStandingCredentialRecord memory) {
        ZKStandingCredentialRecord memory credential = credentials[id];
        if (credential.id == 0) revert AVADataTypes.UnknownReference(id);
        return credential;
    }

    function getCredentialUseRecord(uint256 id) external view returns (ZKStandingCredentialUseRecord memory) {
        ZKStandingCredentialUseRecord memory record = credentialUseRecords[id];
        if (record.id == 0) revert AVADataTypes.UnknownReference(id);
        return record;
    }

    function getCredentialSuspensionRecord(uint256 id)
        external
        view
        returns (ZKStandingCredentialSuspensionRecord memory)
    {
        ZKStandingCredentialSuspensionRecord memory record = credentialSuspensionRecords[id];
        if (record.id == 0) revert AVADataTypes.UnknownReference(id);
        return record;
    }

    function _issueCredential(
        AVADataTypes.Role actingRole,
        ZKStandingCredentialInput calldata input,
        AVADataTypes.Action action
    ) internal returns (uint256 id) {
        if (
            input.standingProofReceiptId == 0 || input.packageId == 0 || input.subjectCommitment == bytes32(0)
                || input.credentialCommitment == bytes32(0) || input.credentialNullifierHash == bytes32(0)
                || input.vectorKey == bytes32(0) || input.categoryHash == bytes32(0) || input.epoch == 0
                || input.sourceRecordSetRoot == bytes32(0) || input.computationRuleHash == bytes32(0)
                || input.expiresAt <= block.timestamp || input.authorityId == bytes32(0) || bytes(input.uri).length == 0
                || input.expiresAt > block.timestamp + MAX_CREDENTIAL_VALIDITY
                || input.lowerBound > input.upperBound || input.threshold < input.lowerBound
                || input.threshold > input.upperBound || credentialIdByCommitment[input.credentialCommitment] != 0
                || credentialIdByNullifier[input.credentialNullifierHash] != 0
        ) {
            revert AVADataTypes.EmptyValue();
        }

        ZKStandingComputationRegistry.StandingProofReceipt memory proofReceipt =
            zkStandingComputationRegistry.getStandingProofReceipt(input.standingProofReceiptId);
        if (
            !_isSubjectLifecycleCompatible(input.subjectCommitment) || proofReceipt.packageId != input.packageId
                || proofReceipt.subjectCommitment != input.subjectCommitment
                || proofReceipt.standingRevision
                    != standingRevisionRegistry.currentRevision(input.packageId, input.subjectCommitment)
                || proofReceipt.vectorKey != input.vectorKey || proofReceipt.categoryHash != input.categoryHash
                || proofReceipt.epoch != input.epoch || proofReceipt.sourceRecordSetRoot != input.sourceRecordSetRoot
                || proofReceipt.computationRuleHash != input.computationRuleHash
                || proofReceipt.lowerBound != input.lowerBound || proofReceipt.upperBound != input.upperBound
                || !zkStandingComputationRegistry.standingProofSupportsCredential(
                    input.standingProofReceiptId,
                    input.packageId,
                    input.subjectCommitment,
                    input.vectorKey,
                    input.categoryHash,
                    input.threshold
                )
        ) {
            revert AVADataTypes.InvalidState(input.standingProofReceiptId);
        }
        _validateCredentialEvidenceLifecycle(proofReceipt, action);

        id = nextCredentialId++;
        credentials[id] = ZKStandingCredentialRecord({
            id: id,
            standingProofReceiptId: input.standingProofReceiptId,
            standingComputationStatementId: proofReceipt.standingComputationStatementId,
            workflowKey: proofReceipt.workflowKey,
            packageId: input.packageId,
            standingRevision: proofReceipt.standingRevision,
            subjectCommitment: input.subjectCommitment,
            credentialCommitment: input.credentialCommitment,
            credentialNullifierHash: input.credentialNullifierHash,
            vectorKey: input.vectorKey,
            categoryHash: input.categoryHash,
            threshold: input.threshold,
            lowerBound: input.lowerBound,
            upperBound: input.upperBound,
            epoch: input.epoch,
            sourceRecordSetRoot: input.sourceRecordSetRoot,
            computationRuleHash: input.computationRuleHash,
            issuedAt: block.timestamp,
            expiresAt: input.expiresAt,
            authorityRole: actingRole,
            authorityId: input.authorityId,
            status: AVADataTypes.StandingCredentialStatus.Active,
            supersededBy: 0,
            statusReference: bytes32(0),
            statusURI: "",
            uri: input.uri,
            issuedBy: msg.sender
        });
        credentialIdByCommitment[input.credentialCommitment] = id;
        credentialIdByNullifier[input.credentialNullifierHash] = id;
        emit ZKStandingCredentialIssued(
            id,
            input.standingProofReceiptId,
            input.subjectCommitment,
            input.packageId,
            input.credentialCommitment,
            input.vectorKey,
            input.categoryHash,
            input.expiresAt
        );
    }

    function _validateCredentialEvidenceLifecycle(
        ZKStandingComputationRegistry.StandingProofReceipt memory proofReceipt,
        AVADataTypes.Action action
    ) internal view {
        AVARulePackageRegistry.RulePackage memory rulePackage = zkStandingComputationRegistry.rulePackageRegistry()
            .getRulePackageById(proofReceipt.packageId);
        if (rulePackage.workflowKey != proofReceipt.workflowKey) {
            revert AVADataTypes.InvalidState(proofReceipt.packageId);
        }
        IStandingFormulaRegistry formulaRegistry = zkStandingComputationRegistry.standingFormulaRegistry();
        IStandingFormulaRegistry.StandingComputationStatementRecord memory statement =
            formulaRegistry.getStandingComputationStatement(proofReceipt.standingComputationStatementId);
        IStandingFormulaRegistry.SourceSetCommitmentRecord memory commitment =
            formulaRegistry.getSourceSetCommitment(statement.sourceSetCommitmentId);
        IStandingFormulaRegistry.SourceSetCompletenessAttestationRecord memory attestation =
            formulaRegistry.getSourceSetCompletenessAttestation(statement.sourceSetCompletenessAttestationId);
        if (
            statement.packageId != proofReceipt.packageId || commitment.packageId != proofReceipt.packageId
                || attestation.packageId != proofReceipt.packageId
        ) {
            revert AVADataTypes.InvalidState(proofReceipt.standingComputationStatementId);
        }
        _validateCredentialEvidenceReceipt(rulePackage, commitment.evidenceReceiptId, action);
        if (attestation.evidenceReceiptId != commitment.evidenceReceiptId) {
            _validateCredentialEvidenceReceipt(rulePackage, attestation.evidenceReceiptId, action);
        }
        if (
            statement.evidenceReceiptId != commitment.evidenceReceiptId
                && statement.evidenceReceiptId != attestation.evidenceReceiptId
        ) {
            _validateCredentialEvidenceReceipt(rulePackage, statement.evidenceReceiptId, action);
        }
    }

    function _validateCredentialEvidenceReceipt(
        AVARulePackageRegistry.RulePackage memory rulePackage,
        uint256 evidenceReceiptId,
        AVADataTypes.Action action
    ) internal view {
        rulePackage.evidenceLifecycleModule
            .validateEvidenceLifecycle(
                rulePackage.workflowKey,
                action,
                evidenceReceiptId,
                AVADataTypes.EvidenceLifecycleKind.None,
                0,
                bytes32(0),
                msg.sender
            );
    }

    function _requireActiveCredential(ZKStandingCredentialRecord storage credential, uint256 credentialId)
        internal
        view
    {
        if (credential.id == 0) revert AVADataTypes.UnknownReference(credentialId);
        if (!_isActiveCredential(credential)) revert AVADataTypes.InvalidState(credentialId);
    }

    function _isActiveCredential(ZKStandingCredentialRecord memory credential) internal view returns (bool) {
        return credential.id != 0 && credential.status == AVADataTypes.StandingCredentialStatus.Active
            && block.timestamp < credential.expiresAt;
    }

    function _isSubjectLifecycleCompatible(bytes32 subjectCommitment) internal view returns (bool) {
        try authorityMatrix.roleRegistry().getSubject(subjectCommitment) returns (
            AVADataTypes.RoleSubject memory subject
        ) {
            return subject.active;
        } catch {
            return true;
        }
    }

    function _recordSettlementBoundSuspension(
        AVADataTypes.Role actingRole,
        uint256 credentialId,
        SettlementSuspensionRequest memory request,
        string calldata uri
    ) internal returns (uint256 id) {
        if (
            request.kind == AVADataTypes.StandingRelevantSettlementKind.None
                || request.sourceType == AVADataTypes.ExecutionSourceType.None || request.sourceRecordId == 0
                || request.settlementId == 0 || request.authorityId == bytes32(0) || bytes(uri).length == 0
        ) {
            revert AVADataTypes.EmptyValue();
        }
        ZKStandingCredentialRecord storage credential = credentials[credentialId];
        _requireActiveCredential(credential, credentialId);
        AVADataTypes.ValueSettlementRecord memory settlement =
            valueSettlementExecutor.getValueSettlement(request.settlementId);
        if (
            settlement.sourceType != request.sourceType || settlement.sourceRecordId != request.sourceRecordId
                || settlement.packageId != credential.packageId || settlement.subjectId != credential.subjectCommitment
                || !_standingSettlementKindMatches(request.kind, settlement.kind)
        ) {
            revert AVADataTypes.InvalidState(credentialId);
        }
        id = _recordSourceBoundSuspension(
            credential,
            actingRole,
            request.authorityId,
            uri,
            SuspensionDraft({
                sourceKind: ZKStandingCredentialSuspensionSourceKind.ValueSettlement,
                standingKind: request.kind,
                settlementSourceType: request.sourceType,
                sourceRecordId: request.sourceRecordId,
                settlementId: request.settlementId,
                challengeTransitionId: 0,
                challengeOutcome: AVADataTypes.ChallengeOutcome.None
            })
        );
    }

    function _recordSourceBoundSuspension(
        ZKStandingCredentialRecord storage credential,
        AVADataTypes.Role actingRole,
        bytes32 authorityId,
        string calldata uri,
        SuspensionDraft memory draft
    ) internal returns (uint256 id) {
        id = nextCredentialSuspensionRecordId++;
        credentialSuspensionRecords[id] = ZKStandingCredentialSuspensionRecord({
            id: id,
            credentialId: credential.id,
            sourceKind: draft.sourceKind,
            packageId: credential.packageId,
            subjectCommitment: credential.subjectCommitment,
            standingKind: draft.standingKind,
            settlementSourceType: draft.settlementSourceType,
            sourceRecordId: draft.sourceRecordId,
            settlementId: draft.settlementId,
            challengeTransitionId: draft.challengeTransitionId,
            challengeOutcome: draft.challengeOutcome,
            authorityRole: actingRole,
            authorityId: authorityId,
            uri: uri,
            recordedBy: msg.sender
        });
        credential.status = AVADataTypes.StandingCredentialStatus.Suspended;
        credential.statusReference = bytes32(id);
        credential.statusURI = uri;
        emit ZKStandingCredentialSourceBoundSuspensionRecorded(
            id, credential.id, draft.sourceKind, credential.packageId, credential.subjectCommitment
        );
        emit ZKStandingCredentialSuspended(credential.id, credential.subjectCommitment, bytes32(id), authorityId);
    }

    function _standingSettlementKindMatches(
        AVADataTypes.StandingRelevantSettlementKind standingKind,
        AVADataTypes.ValueSettlementKind settlementKind
    ) internal pure returns (bool) {
        if (standingKind == AVADataTypes.StandingRelevantSettlementKind.RewardExecution) {
            return settlementKind == AVADataTypes.ValueSettlementKind.TokenTransfer
                || settlementKind == AVADataTypes.ValueSettlementKind.EscrowClaim;
        }
        if (standingKind == AVADataTypes.StandingRelevantSettlementKind.RepaymentObligation) {
            return settlementKind == AVADataTypes.ValueSettlementKind.RepaymentObligation;
        }
        if (standingKind == AVADataTypes.StandingRelevantSettlementKind.FuturePayoutSetoff) {
            return settlementKind == AVADataTypes.ValueSettlementKind.FuturePayoutSetoff;
        }
        if (standingKind == AVADataTypes.StandingRelevantSettlementKind.Waiver) {
            return settlementKind == AVADataTypes.ValueSettlementKind.Waiver;
        }
        if (standingKind == AVADataTypes.StandingRelevantSettlementKind.Satisfaction) {
            return settlementKind == AVADataTypes.ValueSettlementKind.Satisfaction;
        }
        return false;
    }
}
