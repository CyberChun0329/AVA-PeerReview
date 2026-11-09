// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRuleModuleIdentity, RuleModuleIdentity} from "../../interfaces/IRuleModuleIdentity.sol";
import {AVAAuthorityMatrix} from "../../core/AVAAuthorityMatrix.sol";
import {AVACapabilityKeys} from "../../core/AVACapabilityKeys.sol";
import {AVACoreRulePackageRegistry} from "../../core/AVACoreRulePackageRegistry.sol";
import {AVACoreTypes} from "../../core/AVACoreTypes.sol";
import {AVAEvidenceRegistry} from "../../core/AVAEvidenceRegistry.sol";
import {AVAGovernanceKernel} from "../../core/AVAGovernanceKernel.sol";
import {AVAIdentityRegistry} from "../../core/AVAIdentityRegistry.sol";
import {IAVAAuthorityPolicyModule} from "../../core/interfaces/IAVACoreRuleModules.sol";
import {AVAChallengeExtension} from "../challenge/AVAChallengeExtension.sol";

interface IAVAApprovalPolicyModule is IRuleModuleIdentity {
    struct ApprovalContext {
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 targetKindKey;
        uint256 targetId;
        uint256 targetVersionId;
        bytes32 targetSubjectId;
        bytes32 actionKey;
        bytes32 decisionHash;
        bytes32 approvalRoleKey;
        bytes32 authorityId;
        uint256 evidenceId;
        uint64 validUntil;
        bytes32 reasonHash;
        address actor;
    }

    function validateApproval(ApprovalContext calldata context) external view;
}

contract DefaultAVAApprovalPolicyModule is IAVAApprovalPolicyModule, RuleModuleIdentity {
    function validateApproval(ApprovalContext calldata) external pure {}
}

contract AVAApprovalReceiptExtension {
    uint256 public constant MAX_APPROVERS_PER_DECISION = 64;

    enum ApprovalTargetKind {
        None,
        RecognisedState,
        Challenge
    }

    struct ApprovalInput {
        uint256 packageId;
        ApprovalTargetKind targetKind;
        uint256 targetId;
        uint256 expectedTargetVersionId;
        bytes32 actionKey;
        bytes32 decisionHash;
        bytes32 approvalRoleKey;
        bytes32 authorityId;
        uint256 evidenceId;
        uint64 validUntil;
        bytes32 reasonHash;
        string uri;
    }

    struct ApprovalReceipt {
        uint256 id;
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        ApprovalTargetKind targetKind;
        uint256 targetId;
        uint256 targetVersionId;
        bytes32 targetSubjectId;
        bytes32 actionKey;
        bytes32 decisionHash;
        bytes32 approvalRoleKey;
        bytes32 authorityId;
        uint256 evidenceId;
        uint64 validUntil;
        bytes32 reasonHash;
        string uri;
        address recordedBy;
        uint64 recordedAt;
    }

    struct TargetContext {
        bytes32 appId;
        bytes32 workflowKey;
        bytes32 targetSubjectId;
        bytes32 challengerSubjectId;
        uint256 versionId;
    }

    struct ApprovalTargetVersion {
        uint256 versionId;
        bool packageMatches;
    }

    AVAAuthorityMatrix public immutable AUTHORITY_MATRIX;
    AVAIdentityRegistry public immutable IDENTITY_REGISTRY;
    AVACoreRulePackageRegistry public immutable RULE_PACKAGE_REGISTRY;
    AVAEvidenceRegistry public immutable EVIDENCE_REGISTRY;
    AVAGovernanceKernel public immutable GOVERNANCE_KERNEL;
    AVAChallengeExtension public immutable CHALLENGE_EXTENSION;

    mapping(uint256 => ApprovalReceipt) private approvalReceipts;
    mapping(bytes32 => bytes32[]) private approvalAuthoritiesByDecision;
    mapping(bytes32 => uint256) public approvalIdByAuthorityDecision;
    uint256 public nextApprovalReceiptId = 1;

    event ApprovalReceiptRecorded(
        uint256 indexed approvalReceiptId,
        bytes32 indexed appId,
        uint256 indexed packageId,
        ApprovalTargetKind targetKind,
        uint256 targetId,
        bytes32 decisionHash,
        bytes32 approvalRoleKey,
        bytes32 authorityId,
        address recordedBy
    );

    constructor(
        AVAAuthorityMatrix authorityMatrix_,
        AVAIdentityRegistry identityRegistry_,
        AVACoreRulePackageRegistry rulePackageRegistry_,
        AVAEvidenceRegistry evidenceRegistry_,
        AVAGovernanceKernel governanceKernel_,
        AVAChallengeExtension challengeExtension_
    ) {
        if (
            address(authorityMatrix_) == address(0) || address(identityRegistry_) == address(0)
                || address(rulePackageRegistry_) == address(0) || address(evidenceRegistry_) == address(0)
                || address(governanceKernel_) == address(0) || address(challengeExtension_) == address(0)
        ) revert AVACoreTypes.EmptyValue();
        if (
            address(authorityMatrix_.IDENTITY_REGISTRY()) != address(identityRegistry_)
                || address(rulePackageRegistry_.AUTHORITY_MATRIX()) != address(authorityMatrix_)
                || address(governanceKernel_.AUTHORITY_MATRIX()) != address(authorityMatrix_)
                || address(governanceKernel_.IDENTITY_REGISTRY()) != address(identityRegistry_)
                || address(governanceKernel_.RULE_PACKAGE_REGISTRY()) != address(rulePackageRegistry_)
                || address(governanceKernel_.EVIDENCE_REGISTRY()) != address(evidenceRegistry_)
                || address(challengeExtension_.GOVERNANCE_KERNEL()) != address(governanceKernel_)
        ) revert AVACoreTypes.InvalidState(0);
        AUTHORITY_MATRIX = authorityMatrix_;
        IDENTITY_REGISTRY = identityRegistry_;
        RULE_PACKAGE_REGISTRY = rulePackageRegistry_;
        EVIDENCE_REGISTRY = evidenceRegistry_;
        GOVERNANCE_KERNEL = governanceKernel_;
        CHALLENGE_EXTENSION = challengeExtension_;
    }

    function recordApproval(ApprovalInput calldata input) external returns (uint256 approvalReceiptId) {
        if (
            input.packageId == 0 || input.targetKind == ApprovalTargetKind.None || input.targetId == 0
                || input.expectedTargetVersionId == 0 || input.actionKey == bytes32(0)
                || input.decisionHash == bytes32(0) || input.approvalRoleKey == bytes32(0)
                || input.authorityId == bytes32(0) || input.evidenceId == 0 || input.validUntil <= block.timestamp
                || input.reasonHash == bytes32(0)
        ) revert AVACoreTypes.EmptyValue();

        (
            AVACoreRulePackageRegistry.VerifiedPackageContext memory rulePackage,
            IAVAApprovalPolicyModule approvalPolicy
        ) = _verifiedApprovalPackage(input.packageId);
        TargetContext memory target = _targetContext(input, rulePackage);
        AUTHORITY_MATRIX.requireAuthorisedSubject(
            msg.sender,
            target.appId,
            input.approvalRoleKey,
            AVACoreTypes.ACTION_RECORD_APPROVAL_RECEIPT,
            input.authorityId
        );
        _requireApprovalEvidence(input, target);
        _requireNonConflictedApprover(input.authorityId, target);
        approvalPolicy.validateApproval(
            IAVAApprovalPolicyModule.ApprovalContext({
                appId: target.appId,
                workflowKey: target.workflowKey,
                packageId: input.packageId,
                targetKindKey: bytes32(uint256(uint8(input.targetKind))),
                targetId: input.targetId,
                targetVersionId: target.versionId,
                targetSubjectId: target.targetSubjectId,
                actionKey: input.actionKey,
                decisionHash: input.decisionHash,
                approvalRoleKey: input.approvalRoleKey,
                authorityId: input.authorityId,
                evidenceId: input.evidenceId,
                validUntil: input.validUntil,
                reasonHash: input.reasonHash,
                actor: msg.sender
            })
        );

        bytes32 decisionKey = _decisionKey(
            input.packageId,
            input.targetKind,
            input.targetId,
            input.actionKey,
            input.decisionHash,
            input.approvalRoleKey
        );
        bytes32 authorityDecisionKey = keccak256(abi.encode(decisionKey, input.authorityId));
        uint256 existingApprovalId = approvalIdByAuthorityDecision[authorityDecisionKey];
        if (existingApprovalId != 0 && _isApprovalActive(approvalReceipts[existingApprovalId])) {
            revert AVACoreTypes.InvalidState(existingApprovalId);
        }
        if (existingApprovalId == 0) {
            bytes32[] storage authorities = approvalAuthoritiesByDecision[decisionKey];
            if (authorities.length >= MAX_APPROVERS_PER_DECISION) {
                revert AVACoreTypes.InvalidState(authorities.length);
            }
            authorities.push(input.authorityId);
        }
        approvalReceiptId = nextApprovalReceiptId++;
        approvalReceipts[approvalReceiptId] = ApprovalReceipt({
            id: approvalReceiptId,
            appId: target.appId,
            workflowKey: target.workflowKey,
            packageId: input.packageId,
            targetKind: input.targetKind,
            targetId: input.targetId,
            targetVersionId: target.versionId,
            targetSubjectId: target.targetSubjectId,
            actionKey: input.actionKey,
            decisionHash: input.decisionHash,
            approvalRoleKey: input.approvalRoleKey,
            authorityId: input.authorityId,
            evidenceId: input.evidenceId,
            validUntil: input.validUntil,
            reasonHash: input.reasonHash,
            uri: input.uri,
            recordedBy: msg.sender,
            recordedAt: uint64(block.timestamp)
        });
        approvalIdByAuthorityDecision[authorityDecisionKey] = approvalReceiptId;
        emit ApprovalReceiptRecorded(
            approvalReceiptId,
            target.appId,
            input.packageId,
            input.targetKind,
            input.targetId,
            input.decisionHash,
            input.approvalRoleKey,
            input.authorityId,
            msg.sender
        );
    }

    function _verifiedApprovalPackage(uint256 packageId)
        private
        view
        returns (
            AVACoreRulePackageRegistry.VerifiedPackageContext memory rulePackage,
            IAVAApprovalPolicyModule approvalPolicy
        )
    {
        bytes32[] memory keys = new bytes32[](1);
        keys[0] = AVACapabilityKeys.AUTHORITY_APPROVAL;
        address[] memory addresses;
        (rulePackage, addresses) = RULE_PACKAGE_REGISTRY.getVerifiedModulesCompact(packageId, keys);
        if (addresses[0] == address(0)) revert AVACoreTypes.UnknownReference(packageId);
        approvalPolicy = IAVAApprovalPolicyModule(addresses[0]);
    }

    function approvalCount(
        uint256 packageId,
        ApprovalTargetKind targetKind,
        uint256 targetId,
        bytes32 actionKey,
        bytes32 decisionHash,
        bytes32 approvalRoleKey
    ) public view returns (uint256 count) {
        RULE_PACKAGE_REGISTRY.getVerifiedPackageContext(packageId);
        bytes32 decisionKey = _decisionKey(packageId, targetKind, targetId, actionKey, decisionHash, approvalRoleKey);
        bytes32[] storage authorities = approvalAuthoritiesByDecision[decisionKey];
        if (authorities.length == 0) return 0;
        ApprovalTargetVersion memory target = _approvalTargetVersion(targetKind, targetId, packageId);
        for (uint256 i; i < authorities.length; ++i) {
            uint256 approvalId = approvalIdByAuthorityDecision[keccak256(abi.encode(decisionKey, authorities[i]))];
            if (_isApprovalActive(approvalReceipts[approvalId], target)) ++count;
        }
    }

    /// @notice Returns as soon as the requested number of currently active approvals is reached.
    /// @dev This preserves dynamic expiry, subject, evidence, and target-version checks without caching counts.
    function hasApprovalThreshold(
        uint256 packageId,
        ApprovalTargetKind targetKind,
        uint256 targetId,
        bytes32 actionKey,
        bytes32 decisionHash,
        bytes32 approvalRoleKey,
        uint256 requiredApprovals
    ) public view returns (bool) {
        if (requiredApprovals == 0 || requiredApprovals > MAX_APPROVERS_PER_DECISION) {
            revert AVACoreTypes.InvalidState(requiredApprovals);
        }
        RULE_PACKAGE_REGISTRY.getVerifiedPackageContext(packageId);
        bytes32 decisionKey = _decisionKey(packageId, targetKind, targetId, actionKey, decisionHash, approvalRoleKey);
        bytes32[] storage authorities = approvalAuthoritiesByDecision[decisionKey];
        if (authorities.length == 0) return false;
        ApprovalTargetVersion memory target = _approvalTargetVersion(targetKind, targetId, packageId);
        uint256 activeApprovals;
        for (uint256 i; i < authorities.length; ++i) {
            uint256 approvalId = approvalIdByAuthorityDecision[keccak256(abi.encode(decisionKey, authorities[i]))];
            if (_isApprovalActive(approvalReceipts[approvalId], target) && ++activeApprovals == requiredApprovals) {
                return true;
            }
        }
        return false;
    }

    function approvalAuthorityCount(
        uint256 packageId,
        ApprovalTargetKind targetKind,
        uint256 targetId,
        bytes32 actionKey,
        bytes32 decisionHash,
        bytes32 approvalRoleKey
    ) external view returns (uint256) {
        RULE_PACKAGE_REGISTRY.getVerifiedPackageContext(packageId);
        bytes32 decisionKey = _decisionKey(packageId, targetKind, targetId, actionKey, decisionHash, approvalRoleKey);
        return approvalAuthoritiesByDecision[decisionKey].length;
    }

    function hasActiveApproval(
        uint256 packageId,
        ApprovalTargetKind targetKind,
        uint256 targetId,
        bytes32 actionKey,
        bytes32 decisionHash,
        bytes32 approvalRoleKey,
        bytes32 authorityId
    ) external view returns (bool) {
        RULE_PACKAGE_REGISTRY.getVerifiedPackageContext(packageId);
        bytes32 decisionKey = _decisionKey(packageId, targetKind, targetId, actionKey, decisionHash, approvalRoleKey);
        uint256 id = approvalIdByAuthorityDecision[keccak256(abi.encode(decisionKey, authorityId))];
        return id != 0 && _isApprovalActive(approvalReceipts[id]);
    }

    function getApprovalReceipt(uint256 approvalReceiptId) external view returns (ApprovalReceipt memory receipt) {
        receipt = approvalReceipts[approvalReceiptId];
        if (receipt.id == 0) revert AVACoreTypes.UnknownReference(approvalReceiptId);
    }

    function _targetContext(
        ApprovalInput calldata input,
        AVACoreRulePackageRegistry.VerifiedPackageContext memory rulePackage
    ) private view returns (TargetContext memory target) {
        if (input.targetKind == ApprovalTargetKind.RecognisedState) {
            AVACoreTypes.RecognisedStateRecord memory state = GOVERNANCE_KERNEL.getRecognisedState(input.targetId);
            if (state.packageId != input.packageId || state.lastTransitionId != input.expectedTargetVersionId) {
                revert AVACoreTypes.InvalidState(input.targetId);
            }
            target = TargetContext({
                appId: state.appId,
                workflowKey: state.workflowKey,
                targetSubjectId: state.subjectId,
                challengerSubjectId: bytes32(0),
                versionId: state.lastTransitionId
            });
        } else {
            AVAChallengeExtension.ChallengeRecord memory challenge = CHALLENGE_EXTENSION.getChallenge(input.targetId);
            if (
                (input.packageId != challenge.packageId && input.packageId != challenge.targetPackageId)
                    || challenge.lastTransitionId != input.expectedTargetVersionId
            ) revert AVACoreTypes.InvalidState(input.targetId);
            AVACoreTypes.RecognisedStateRecord memory state =
                GOVERNANCE_KERNEL.getRecognisedState(challenge.challengedRecognisedStateId);
            target = TargetContext({
                appId: challenge.appId,
                workflowKey: rulePackage.workflowKey,
                targetSubjectId: state.subjectId,
                challengerSubjectId: challenge.challengerSubjectId,
                versionId: challenge.lastTransitionId
            });
        }
        if (target.appId != rulePackage.appId || target.workflowKey != rulePackage.workflowKey) {
            revert AVACoreTypes.InvalidState(input.packageId);
        }
    }

    function _requireApprovalEvidence(ApprovalInput calldata input, TargetContext memory target) private view {
        (bytes32 appId, bytes32 workflowKey,, bytes32 subjectId,) =
            EVIDENCE_REGISTRY.requireUsableEvidenceReferenceForPackage(input.evidenceId, input.packageId);
        if (
            appId != target.appId || workflowKey != target.workflowKey || subjectId != input.authorityId
        ) revert AVACoreTypes.InvalidState(input.evidenceId);
    }

    function _requireNonConflictedApprover(bytes32 authorityId, TargetContext memory target) private view {
        AVAIdentityRegistry.SubjectContext memory authority = IDENTITY_REGISTRY.getSubjectContext(authorityId);
        AVAIdentityRegistry.SubjectContext memory targetSubject =
            IDENTITY_REGISTRY.getSubjectContext(target.targetSubjectId);
        if (authority.account == targetSubject.account) revert AVACoreTypes.InvalidState(uint256(authorityId));
        if (target.challengerSubjectId != bytes32(0)) {
            AVAIdentityRegistry.SubjectContext memory challenger =
                IDENTITY_REGISTRY.getSubjectContext(target.challengerSubjectId);
            if (authority.account == challenger.account) revert AVACoreTypes.InvalidState(uint256(authorityId));
        }
    }

    function _isApprovalActive(ApprovalReceipt storage receipt) private view returns (bool) {
        if (receipt.id == 0 || receipt.validUntil <= block.timestamp) return false;
        return _isApprovalActive(
            receipt, _approvalTargetVersion(receipt.targetKind, receipt.targetId, receipt.packageId)
        );
    }

    function _isApprovalActive(ApprovalReceipt storage receipt, ApprovalTargetVersion memory target)
        private
        view
        returns (bool)
    {
        if (receipt.id == 0 || receipt.validUntil <= block.timestamp || !target.packageMatches) return false;
        AVAIdentityRegistry.SubjectContext memory authority;
        try IDENTITY_REGISTRY.getSubjectContext(receipt.authorityId) returns (
            AVAIdentityRegistry.SubjectContext memory subject
        ) {
            authority = subject;
        } catch {
            return false;
        }
        if (
            !authority.active || authority.appId != receipt.appId || authority.roleKey != receipt.approvalRoleKey
                || authority.account != receipt.recordedBy
                || IDENTITY_REGISTRY.subjectOf(authority.account, receipt.appId, receipt.approvalRoleKey)
                    != receipt.authorityId
        ) return false;
        AVAEvidenceRegistry.EvidenceReference memory evidence =
            EVIDENCE_REGISTRY.getEvidenceReference(receipt.evidenceId);
        if (
            evidence.status != AVACoreTypes.EvidenceStatus.Active || evidence.appId != receipt.appId
                || evidence.workflowKey != receipt.workflowKey || evidence.packageId != receipt.packageId
                || evidence.subjectId != receipt.authorityId
        ) return false;
        return target.versionId == receipt.targetVersionId;
    }

    function _approvalTargetVersion(ApprovalTargetKind targetKind, uint256 targetId, uint256 packageId)
        private
        view
        returns (ApprovalTargetVersion memory target)
    {
        if (targetKind == ApprovalTargetKind.RecognisedState) {
            AVAGovernanceKernel.RecognisedStateReference memory state =
                GOVERNANCE_KERNEL.getRecognisedStateReference(targetId);
            target.versionId = state.lastTransitionId;
            target.packageMatches = state.packageId == packageId;
            return target;
        }
        AVAChallengeExtension.ChallengeRecord memory challenge = CHALLENGE_EXTENSION.getChallenge(targetId);
        target.versionId = challenge.lastTransitionId;
        target.packageMatches = packageId == challenge.packageId || packageId == challenge.targetPackageId;
    }

    function _decisionKey(
        uint256 packageId,
        ApprovalTargetKind targetKind,
        uint256 targetId,
        bytes32 actionKey,
        bytes32 decisionHash,
        bytes32 approvalRoleKey
    ) private pure returns (bytes32) {
        return keccak256(abi.encode(packageId, targetKind, targetId, actionKey, decisionHash, approvalRoleKey));
    }
}

contract ApprovalReceiptAuthorityPolicyModule is IAVAAuthorityPolicyModule, RuleModuleIdentity {
    AVAApprovalReceiptExtension public immutable APPROVAL_REGISTRY;
    bytes32 public immutable REQUIRED_APPROVAL_ROLE_KEY;
    bytes32 public immutable REQUIRED_ACTION_KEY;
    AVAApprovalReceiptExtension.ApprovalTargetKind public immutable TARGET_KIND;
    uint256 public immutable REQUIRED_APPROVALS;

    constructor(
        AVAApprovalReceiptExtension approvalRegistry_,
        bytes32 requiredApprovalRoleKey_,
        bytes32 requiredActionKey_,
        AVAApprovalReceiptExtension.ApprovalTargetKind targetKind_,
        uint256 requiredApprovals_
    ) {
        if (
            address(approvalRegistry_) == address(0) || requiredApprovalRoleKey_ == bytes32(0)
                || requiredActionKey_ == bytes32(0)
                || targetKind_ == AVAApprovalReceiptExtension.ApprovalTargetKind.None || requiredApprovals_ == 0
                || requiredApprovals_ > approvalRegistry_.MAX_APPROVERS_PER_DECISION()
        ) revert AVACoreTypes.EmptyValue();
        APPROVAL_REGISTRY = approvalRegistry_;
        REQUIRED_APPROVAL_ROLE_KEY = requiredApprovalRoleKey_;
        REQUIRED_ACTION_KEY = requiredActionKey_;
        TARGET_KIND = targetKind_;
        REQUIRED_APPROVALS = requiredApprovals_;
    }

    function validateAuthority(AuthorityContext calldata context) external view {
        if (context.actionKey != REQUIRED_ACTION_KEY) return;
        if (!APPROVAL_REGISTRY.hasApprovalThreshold(
                context.packageId,
                TARGET_KIND,
                context.targetId,
                context.actionKey,
                context.decisionHash,
                REQUIRED_APPROVAL_ROLE_KEY,
                REQUIRED_APPROVALS
            )) revert AVACoreTypes.InvalidState(context.targetId);
    }

    function _moduleConfigurationHash() internal view override returns (bytes32) {
        return keccak256(
            abi.encode(
                address(APPROVAL_REGISTRY),
                REQUIRED_APPROVAL_ROLE_KEY,
                REQUIRED_ACTION_KEY,
                TARGET_KIND,
                REQUIRED_APPROVALS
            )
        );
    }
}
