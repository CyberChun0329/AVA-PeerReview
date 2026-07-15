// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "./AVADataTypes.sol";
import {AuthorityMatrix} from "./AuthorityMatrix.sol";
import {AVARulePackageRegistry} from "./AVARulePackageRegistry.sol";
import {EvidenceCommitmentRegistry} from "./EvidenceCommitmentRegistry.sol";

interface IApprovalRecognisedStateReader {
    function getRecognisedState(uint256 id) external view returns (AVADataTypes.RecognisedStateRecord memory);
}

interface IApprovalChallengeReader {
    function getChallenge(uint256 id) external view returns (AVADataTypes.ChallengeRecord memory);
}

contract AuthorityApprovalRegistry {
    struct ApprovalReceipt {
        uint256 id;
        bytes32 workflowKey;
        uint256 packageId;
        AVADataTypes.Action action;
        uint256 recognisedStateId;
        uint256 challengeId;
        bytes32 objectId;
        AVADataTypes.Role authorityRole;
        bytes32 authorityId;
        bytes32 decisionHash;
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
        uint256 challengeId;
        bytes32 objectId;
        bytes32 authorityId;
        bytes32 decisionHash;
        uint256 evidenceReceiptId;
        uint64 expiresAt;
        string reasonURI;
    }

    AuthorityMatrix public immutable AUTHORITY_MATRIX;
    AVARulePackageRegistry public immutable RULE_PACKAGE_REGISTRY;
    EvidenceCommitmentRegistry public immutable EVIDENCE_REGISTRY;
    IApprovalRecognisedStateReader public recognisedStateReader;
    IApprovalChallengeReader public challengeReader;
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
        uint256 challengeId,
        bytes32 objectId,
        bytes32 authorityId,
        bytes32 decisionHash,
        uint64 expiresAt
    );
    event ApprovalTargetReadersBound(address indexed recognisedStateReader, address indexed challengeReader);

    constructor(
        AuthorityMatrix authorityMatrix_,
        AVARulePackageRegistry rulePackageRegistry_,
        EvidenceCommitmentRegistry evidenceRegistry_
    ) {
        AUTHORITY_MATRIX = authorityMatrix_;
        RULE_PACKAGE_REGISTRY = rulePackageRegistry_;
        EVIDENCE_REGISTRY = evidenceRegistry_;
    }

    function bindTargetReaders(
        IApprovalRecognisedStateReader recognisedStateReader_,
        IApprovalChallengeReader challengeReader_
    ) external {
        if (msg.sender != AUTHORITY_MATRIX.admin()) {
            revert AVADataTypes.NotAdmin(msg.sender);
        }
        if (
            address(recognisedStateReader_) == address(0) || address(challengeReader_) == address(0)
                || address(recognisedStateReader_).code.length == 0 || address(challengeReader_).code.length == 0
                || address(recognisedStateReader) != address(0) || address(challengeReader) != address(0)
        ) {
            revert AVADataTypes.InvalidState(0);
        }
        recognisedStateReader = recognisedStateReader_;
        challengeReader = challengeReader_;
        emit ApprovalTargetReadersBound(address(recognisedStateReader_), address(challengeReader_));
    }

    function recordApproval(AVADataTypes.Role actingRole, ApprovalInput calldata input) external returns (uint256 id) {
        AUTHORITY_MATRIX.requireAuthorisedSubject(msg.sender, actingRole, input.action, input.authorityId);
        if (
            input.workflowKey == bytes32(0) || input.packageId == 0 || input.recognisedStateId == 0
                || input.objectId == bytes32(0) || input.authorityId == bytes32(0) || input.evidenceReceiptId == 0
                || input.decisionHash == bytes32(0) || input.expiresAt <= block.timestamp
        ) {
            revert AVADataTypes.EmptyValue();
        }

        _requireValidApprovalEvidence(input);

        if (
            _isChallengeAuthorityAction(input.action)
                && !_isConflictFreeChallengeAuthority(
                    input.authorityId,
                    challengeReader.getChallenge(input.challengeId),
                    recognisedStateReader.getRecognisedState(input.recognisedStateId)
                )
        ) {
            revert AVADataTypes.NotAuthorised(msg.sender, input.action);
        }

        bytes32 approvalKey = computeApprovalKey(
            input.workflowKey,
            input.packageId,
            input.action,
            actingRole,
            input.recognisedStateId,
            input.challengeId,
            input.objectId,
            input.decisionHash
        );
        uint256 existingApprovalId = approvalReceiptByContextAndAuthority[approvalKey][input.authorityId];
        if (existingApprovalId != 0 && approvalReceipts[existingApprovalId].expiresAt > block.timestamp) {
            revert AVADataTypes.InvalidState(uint256(input.authorityId));
        }

        id = nextApprovalReceiptId++;
        approvalReceipts[id] = ApprovalReceipt({
            id: id,
            workflowKey: input.workflowKey,
            packageId: input.packageId,
            action: input.action,
            recognisedStateId: input.recognisedStateId,
            challengeId: input.challengeId,
            objectId: input.objectId,
            authorityRole: actingRole,
            authorityId: input.authorityId,
            decisionHash: input.decisionHash,
            evidenceReceiptId: input.evidenceReceiptId,
            expiresAt: input.expiresAt,
            reasonURI: input.reasonURI,
            approvedBy: msg.sender
        });
        approvalReceiptByContextAndAuthority[approvalKey][input.authorityId] = id;
        if (existingApprovalId == 0) {
            approvalAuthoritiesByContext[approvalKey].push(input.authorityId);
        }

        emit AuthorityApprovalRecorded(
            id,
            input.workflowKey,
            input.packageId,
            input.action,
            input.recognisedStateId,
            input.challengeId,
            input.objectId,
            input.authorityId,
            input.decisionHash,
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
        AVADataTypes.Role requiredRole,
        uint256 recognisedStateId,
        uint256 challengeId,
        bytes32 objectId,
        bytes32 decisionHash
    ) external view returns (uint256) {
        bytes32 approvalKey = computeApprovalKey(
            workflowKey, packageId, action, requiredRole, recognisedStateId, challengeId, objectId, decisionHash
        );
        bytes32[] storage authorities = approvalAuthoritiesByContext[approvalKey];
        uint256 count;
        for (uint256 i = 0; i < authorities.length; i++) {
            uint256 approvalId = approvalReceiptByContextAndAuthority[approvalKey][authorities[i]];
            ApprovalReceipt storage receipt = approvalReceipts[approvalId];
            if (
                receipt.expiresAt > block.timestamp && _isCurrentRoleSubject(authorities[i], requiredRole)
                    && _isConflictFreeApproval(authorities[i], action, recognisedStateId, challengeId)
            ) {
                count++;
            }
        }
        return count;
    }

    function hasActiveApproval(
        bytes32 workflowKey,
        uint256 packageId,
        AVADataTypes.Action action,
        AVADataTypes.Role requiredRole,
        uint256 recognisedStateId,
        uint256 challengeId,
        bytes32 objectId,
        bytes32 decisionHash,
        bytes32 authorityId
    ) external view returns (bool) {
        uint256 approvalId = approvalReceiptByContextAndAuthority[
            computeApprovalKey(
                workflowKey, packageId, action, requiredRole, recognisedStateId, challengeId, objectId, decisionHash
            )
        ][authorityId];
        if (approvalId == 0) return false;
        return approvalReceipts[approvalId].expiresAt > block.timestamp
            && _isCurrentRoleSubject(authorityId, requiredRole)
            && _isConflictFreeApproval(authorityId, action, recognisedStateId, challengeId);
    }

    function computeApprovalKey(
        bytes32 workflowKey,
        uint256 packageId,
        AVADataTypes.Action action,
        AVADataTypes.Role requiredRole,
        uint256 recognisedStateId,
        uint256 challengeId,
        bytes32 objectId,
        bytes32 decisionHash
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                workflowKey, packageId, action, requiredRole, recognisedStateId, challengeId, objectId, decisionHash
            )
        );
    }

    function _requireValidApprovalEvidence(ApprovalInput calldata input) internal view {
        AVARulePackageRegistry.RulePackage memory rulePackage =
            RULE_PACKAGE_REGISTRY.getRulePackageById(input.packageId);
        if (rulePackage.workflowKey != input.workflowKey) revert AVADataTypes.InvalidState(input.packageId);
        (bytes32 evidenceWorkflowKey, uint256 evidencePackageId) = _validateTarget(input);
        AVADataTypes.EvidenceReceipt memory evidenceReceipt =
            EVIDENCE_REGISTRY.getEvidenceReceipt(input.evidenceReceiptId);
        if (evidenceReceipt.workflowKey != evidenceWorkflowKey || evidenceReceipt.packageId != evidencePackageId) {
            revert AVADataTypes.InvalidState(input.evidenceReceiptId);
        }
        if (
            input.action != AVADataTypes.Action.CloseChallenge
                && evidenceReceipt.status != AVADataTypes.EvidenceReceiptStatus.Active
        ) {
            revert AVADataTypes.InvalidState(input.evidenceReceiptId);
        }
    }

    function _validateTarget(ApprovalInput calldata input)
        internal
        view
        returns (bytes32 evidenceWorkflowKey, uint256 evidencePackageId)
    {
        if (address(recognisedStateReader) == address(0) || address(challengeReader) == address(0)) {
            revert AVADataTypes.InvalidState(0);
        }
        AVADataTypes.RecognisedStateRecord memory state =
            recognisedStateReader.getRecognisedState(input.recognisedStateId);
        if (_isChallengeAuthorityAction(input.action)) {
            if (input.challengeId == 0) revert AVADataTypes.EmptyValue();
            AVADataTypes.ChallengeRecord memory challenge = challengeReader.getChallenge(input.challengeId);
            bool challengePackageAuthority =
                challenge.workflowKey == input.workflowKey && challenge.packageId == input.packageId;
            bool targetPackageAuthority = state.workflowKey == input.workflowKey && state.packageId == input.packageId;
            if (
                challenge.challengedRecognisedStateId != input.recognisedStateId
                    || (!challengePackageAuthority && !targetPackageAuthority)
                    || challenge.targetWorkflowKey != state.workflowKey || challenge.targetPackageId != state.packageId
                    || challenge.attributedObjectId != input.objectId
                    || challenge.evidenceReceiptId != input.evidenceReceiptId
                    || !_isLifecycleEligible(input.action, challenge.status)
            ) {
                revert AVADataTypes.InvalidState(input.challengeId);
            }
            return (challenge.workflowKey, challenge.packageId);
        }
        if (
            input.challengeId != 0 || state.workflowKey != input.workflowKey || state.packageId != input.packageId
                || state.objectId != input.objectId
        ) {
            revert AVADataTypes.InvalidState(input.recognisedStateId);
        }
        return (input.workflowKey, input.packageId);
    }

    function _isCurrentRoleSubject(bytes32 authorityId, AVADataTypes.Role requiredRole) internal view returns (bool) {
        AVADataTypes.RoleSubject memory subject = AUTHORITY_MATRIX.roleRegistry().getSubject(authorityId);
        return subject.active && subject.role == requiredRole
            && AUTHORITY_MATRIX.roleRegistry().subjectOf(subject.account, requiredRole) == authorityId;
    }

    function _isConflictFreeApproval(
        bytes32 authorityId,
        AVADataTypes.Action action,
        uint256 recognisedStateId,
        uint256 challengeId
    ) internal view returns (bool) {
        if (!_isChallengeAuthorityAction(action)) return true;
        if (challengeId == 0 || recognisedStateId == 0) return false;
        return _isConflictFreeChallengeAuthority(
            authorityId,
            challengeReader.getChallenge(challengeId),
            recognisedStateReader.getRecognisedState(recognisedStateId)
        );
    }

    function _isConflictFreeChallengeAuthority(
        bytes32 authorityId,
        AVADataTypes.ChallengeRecord memory challenge,
        AVADataTypes.RecognisedStateRecord memory state
    ) internal view returns (bool) {
        AVADataTypes.RoleSubject memory authoritySubject = AUTHORITY_MATRIX.roleRegistry().getSubject(authorityId);
        AVADataTypes.RoleSubject memory challengerSubject =
            AUTHORITY_MATRIX.roleRegistry().getSubject(challenge.challengerSubjectId);
        AVADataTypes.RoleSubject memory targetSubject = AUTHORITY_MATRIX.roleRegistry().getSubject(state.subjectId);
        return authorityId != challenge.challengerSubjectId && authorityId != state.subjectId
            && authoritySubject.account != challenge.filedBy && authoritySubject.account != challengerSubject.account
            && authoritySubject.account != targetSubject.account;
    }

    function _isChallengeAuthorityAction(AVADataTypes.Action action) internal pure returns (bool) {
        return action == AVADataTypes.Action.ScreenChallenge || action == AVADataTypes.Action.ResolveChallenge
            || action == AVADataTypes.Action.ApplyRestoration || action == AVADataTypes.Action.CloseChallenge;
    }

    function _isLifecycleEligible(AVADataTypes.Action action, AVADataTypes.ChallengeLifecycleStatus status)
        internal
        pure
        returns (bool)
    {
        if (action == AVADataTypes.Action.ScreenChallenge) {
            return status == AVADataTypes.ChallengeLifecycleStatus.ConcernFiled;
        }
        if (action == AVADataTypes.Action.ResolveChallenge) {
            return status == AVADataTypes.ChallengeLifecycleStatus.AdmissibilityScreening;
        }
        if (action == AVADataTypes.Action.ApplyRestoration) {
            return status == AVADataTypes.ChallengeLifecycleStatus.Resolved;
        }
        return status == AVADataTypes.ChallengeLifecycleStatus.ConcernFiled
            || status == AVADataTypes.ChallengeLifecycleStatus.AdmissibilityScreening
            || status == AVADataTypes.ChallengeLifecycleStatus.Resolved
            || status == AVADataTypes.ChallengeLifecycleStatus.RestorationApplied;
    }
}
