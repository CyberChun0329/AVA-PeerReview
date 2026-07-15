// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVACoreTypes} from "../../core/AVACoreTypes.sol";
import {AVACoreRulePackageRegistry} from "../../core/AVACoreRulePackageRegistry.sol";
import {AVAGovernanceKernel} from "../../core/AVAGovernanceKernel.sol";
import {AVAIdentityRegistry} from "../../core/AVAIdentityRegistry.sol";
import {IAVAPostTransitionHook} from "../../core/interfaces/IAVAPostTransitionHook.sol";
import {RuleModuleIdentity} from "../../interfaces/IRuleModuleIdentity.sol";
import {IAVAStandingRevision} from "./IAVAStandingRevision.sol";

contract AVAStandingRevisionExtension is IAVAPostTransitionHook, IAVAStandingRevision, RuleModuleIdentity {
    AVAGovernanceKernel public immutable GOVERNANCE_KERNEL;
    address public immutable ADMIN;

    mapping(bytes32 => uint256) private revisions;
    mapping(uint256 => mapping(address => bool)) public revisionWriterByPackage;
    mapping(uint256 => bool) public revisionUseStartedByPackage;
    bytes32 private writerSetHash;
    /// @notice Aggregate observability flag; writer sealing is enforced per package.
    bool public revisionUseStarted;

    event StandingRevisionAdvanced(
        bytes32 indexed appId,
        uint256 indexed packageId,
        bytes32 indexed subjectId,
        uint256 revision,
        uint256 recognisedStateId,
        uint256 transitionId,
        AVACoreTypes.RecognisedStateStatus status
    );
    event StandingRevisionWriterBound(
        uint256 indexed packageId, address indexed writer, bytes32 writerSetHash, address indexed boundBy
    );
    event StandingRevisionAdvancedFromRecord(
        bytes32 indexed appId,
        uint256 indexed packageId,
        bytes32 indexed subjectId,
        uint256 revision,
        bytes32 sourceTypeKey,
        uint256 sourceRecordId,
        address writer
    );

    constructor(AVAGovernanceKernel governanceKernel_) {
        if (address(governanceKernel_) == address(0)) revert AVACoreTypes.EmptyValue();
        GOVERNANCE_KERNEL = governanceKernel_;
        ADMIN = msg.sender;
    }

    function bindRevisionWriter(uint256 packageId, address writer) external {
        if (msg.sender != ADMIN) revert AVACoreTypes.NotAdmin(msg.sender);
        if (
            packageId == 0 || writer == address(0) || writer.code.length == 0
                || revisionWriterByPackage[packageId][writer] || revisionUseStartedByPackage[packageId]
        ) {
            revert AVACoreTypes.InvalidState(0);
        }
        GOVERNANCE_KERNEL.RULE_PACKAGE_REGISTRY().getVerifiedPackageContext(packageId);
        revisionWriterByPackage[packageId][writer] = true;
        writerSetHash = keccak256(abi.encode(writerSetHash, packageId, writer));
        emit StandingRevisionWriterBound(packageId, writer, writerSetHash, msg.sender);
    }

    function onRecognisedStateTransition(TransitionContext calldata context) external {
        if (msg.sender != address(GOVERNANCE_KERNEL)) {
            revert AVACoreTypes.NotAuthorised(msg.sender, AVACoreTypes.ACTION_TRANSITION_RECOGNISED_STATE);
        }
        if (!_isStandingRelevant(context.toStatus) && context.kind != AVACoreTypes.TransitionKind.Restoration) return;
        revisionUseStarted = true;
        revisionUseStartedByPackage[context.packageId] = true;
        bytes32 revisionKey = _revisionKey(context.packageId, context.subjectId);
        uint256 revision = ++revisions[revisionKey];
        emit StandingRevisionAdvanced(
            context.appId,
            context.packageId,
            context.subjectId,
            revision,
            context.recognisedStateId,
            context.transitionId,
            context.toStatus
        );
    }

    function currentRevision(uint256 packageId, bytes32 subjectId) external view returns (uint256) {
        if (packageId == 0 || subjectId == bytes32(0)) revert AVACoreTypes.EmptyValue();
        return revisions[_revisionKey(packageId, subjectId)];
    }

    function advanceRevision(
        bytes32 appId,
        uint256 packageId,
        bytes32 subjectId,
        bytes32 sourceTypeKey,
        uint256 sourceRecordId
    ) external returns (uint256 revision) {
        if (
            !revisionWriterByPackage[packageId][msg.sender] || appId == bytes32(0) || packageId == 0
                || subjectId == bytes32(0) || sourceTypeKey == bytes32(0) || sourceRecordId == 0
        ) {
            revert AVACoreTypes.NotAuthorised(msg.sender, AVACoreTypes.ACTION_RECORD_STANDING_UPDATE);
        }
        AVACoreRulePackageRegistry.VerifiedPackageContext memory rulePackage =
            GOVERNANCE_KERNEL.RULE_PACKAGE_REGISTRY().getVerifiedPackageContext(packageId);
        if (rulePackage.appId != appId) {
            revert AVACoreTypes.CrossApplicationReference(rulePackage.appId, appId);
        }
        AVAIdentityRegistry.SubjectContext memory subject =
            GOVERNANCE_KERNEL.IDENTITY_REGISTRY().getSubjectContext(subjectId);
        if (subject.appId != appId) revert AVACoreTypes.CrossApplicationReference(appId, subject.appId);
        revisionUseStarted = true;
        revisionUseStartedByPackage[packageId] = true;
        revision = ++revisions[_revisionKey(packageId, subjectId)];
        emit StandingRevisionAdvancedFromRecord(
            appId, packageId, subjectId, revision, sourceTypeKey, sourceRecordId, msg.sender
        );
    }

    function _revisionKey(uint256 packageId, bytes32 subjectId) internal pure returns (bytes32) {
        return keccak256(abi.encode(packageId, subjectId));
    }

    function _isStandingRelevant(AVACoreTypes.RecognisedStateStatus status) internal pure returns (bool) {
        return status == AVACoreTypes.RecognisedStateStatus.Vested
            || status == AVACoreTypes.RecognisedStateStatus.Downgraded
            || status == AVACoreTypes.RecognisedStateStatus.Voided
            || status == AVACoreTypes.RecognisedStateStatus.Restored;
    }

    function _moduleConfigurationHash() internal view override returns (bytes32) {
        return keccak256(abi.encode(address(GOVERNANCE_KERNEL)));
    }
}
