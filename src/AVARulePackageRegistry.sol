// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "./AVADataTypes.sol";
import {AVAApplicationRegistry} from "./AVAApplicationRegistry.sol";
import {AuthorityMatrix} from "./AuthorityMatrix.sol";
import {IAttributionModule} from "./interfaces/IAttributionModule.sol";
import {IVerificationModule} from "./interfaces/IVerificationModule.sol";
import {IAVAAllocationModule} from "./interfaces/IAVAAllocationModule.sol";
import {ITransitionRuleModule} from "./interfaces/ITransitionRuleModule.sol";
import {IDisclosurePolicyModule} from "./interfaces/IDisclosurePolicyModule.sol";
import {IConsequenceAdapter} from "./interfaces/IConsequenceAdapter.sol";
import {IStandingAdapter} from "./interfaces/IStandingAdapter.sol";
import {IRewardAdapter} from "./interfaces/IRewardAdapter.sol";
import {IPriorityAdapter} from "./interfaces/IPriorityAdapter.sol";
import {IPenaltyAdapter} from "./interfaces/IPenaltyAdapter.sol";
import {IRestorationAdapter} from "./interfaces/IRestorationAdapter.sol";
import {IChallengeLifecycleModule} from "./interfaces/IChallengeLifecycleModule.sol";
import {IEvidencePolicyModule} from "./interfaces/IEvidencePolicyModule.sol";
import {IAuditAdapter} from "./interfaces/IAuditAdapter.sol";
import {IEditorialSystemAdapter} from "./interfaces/IEditorialSystemAdapter.sol";
import {IResidualEditorialAuthorityModule} from "./interfaces/IResidualEditorialAuthorityModule.sol";
import {IFieldPolicyModule} from "./interfaces/IFieldPolicyModule.sol";
import {IAntiAbuseModule} from "./interfaces/IAntiAbuseModule.sol";
import {IValueExecutionAdapter} from "./interfaces/IValueExecutionAdapter.sol";
import {IStandingComputationModule} from "./interfaces/IStandingComputationModule.sol";
import {IRulePackageLifecycleModule} from "./interfaces/IRulePackageLifecycleModule.sol";
import {IEvidenceLifecycleModule} from "./interfaces/IEvidenceLifecycleModule.sol";
import {IDisclosureLifecycleModule} from "./interfaces/IDisclosureLifecycleModule.sol";
import {IDisclosureExecutionModule} from "./interfaces/IDisclosureExecutionModule.sol";
import {IAVAApplicationModule} from "./interfaces/IAVAApplicationModule.sol";
import {RulePackageIdentityVerifier} from "./RulePackageIdentityVerifier.sol";

interface IRecognisedStateReader {
    function getRecognisedState(uint256 id) external view returns (AVADataTypes.RecognisedStateRecord memory);
}

interface IEvidenceReceiptReader {
    function getEvidenceReceipt(uint256 id) external view returns (AVADataTypes.EvidenceReceipt memory);
}

contract AVARulePackageRegistry {
    struct RulePackage {
        uint256 packageId;
        bytes32 appId;
        bytes32 workflowKey;
        bytes32 modulesHash;
        bytes32 modulesIdentityHash;
        IAVAApplicationModule applicationModule;
        IAttributionModule attributionModule;
        IVerificationModule verificationModule;
        IAVAAllocationModule allocationModule;
        ITransitionRuleModule transitionRuleModule;
        IDisclosurePolicyModule disclosureModule;
        IStandingAdapter standingAdapter;
        IConsequenceAdapter consequenceAdapter;
        IRewardAdapter rewardAdapter;
        IPriorityAdapter priorityAdapter;
        IPenaltyAdapter penaltyAdapter;
        IRestorationAdapter restorationAdapter;
        IChallengeLifecycleModule challengeLifecycleModule;
        IEvidencePolicyModule evidencePolicyModule;
        IAuditAdapter auditAdapter;
        IEditorialSystemAdapter editorialSystemAdapter;
        IResidualEditorialAuthorityModule residualEditorialAuthorityModule;
        IFieldPolicyModule fieldPolicyModule;
        IAntiAbuseModule antiAbuseModule;
        IValueExecutionAdapter valueExecutionAdapter;
        IStandingComputationModule standingComputationModule;
        IRulePackageLifecycleModule rulePackageLifecycleModule;
        IEvidenceLifecycleModule evidenceLifecycleModule;
        IDisclosureLifecycleModule disclosureLifecycleModule;
        IDisclosureExecutionModule disclosureExecutionModule;
        uint64 version;
        bytes32 compatibilityKey;
        string dependencyURI;
        bool deprecated;
        string uri;
        bytes32 authorityId;
        address registeredBy;
        bool active;
    }

    struct RulePackageModules {
        IAVAApplicationModule applicationModule;
        IAttributionModule attributionModule;
        IVerificationModule verificationModule;
        IAVAAllocationModule allocationModule;
        ITransitionRuleModule transitionRuleModule;
        IDisclosurePolicyModule disclosureModule;
        IStandingAdapter standingAdapter;
        IConsequenceAdapter consequenceAdapter;
        IRewardAdapter rewardAdapter;
        IPriorityAdapter priorityAdapter;
        IPenaltyAdapter penaltyAdapter;
        IRestorationAdapter restorationAdapter;
        IChallengeLifecycleModule challengeLifecycleModule;
        IEvidencePolicyModule evidencePolicyModule;
        IAuditAdapter auditAdapter;
        IEditorialSystemAdapter editorialSystemAdapter;
        IResidualEditorialAuthorityModule residualEditorialAuthorityModule;
        IFieldPolicyModule fieldPolicyModule;
        IAntiAbuseModule antiAbuseModule;
        IValueExecutionAdapter valueExecutionAdapter;
        IStandingComputationModule standingComputationModule;
        IRulePackageLifecycleModule rulePackageLifecycleModule;
        IEvidenceLifecycleModule evidenceLifecycleModule;
        IDisclosureLifecycleModule disclosureLifecycleModule;
        IDisclosureExecutionModule disclosureExecutionModule;
        uint64 version;
        bytes32 compatibilityKey;
        string dependencyURI;
        bool deprecated;
    }

    AuthorityMatrix public immutable authorityMatrix;
    AVAApplicationRegistry public immutable applicationRegistry;
    RulePackageIdentityVerifier public immutable identityVerifier;

    mapping(uint256 => RulePackage) private rulePackagesById;
    mapping(bytes32 => uint256) private activePackageIdByApplicationWorkflow;
    mapping(uint256 => AVADataTypes.RulePackageSupersessionRecord) private supersessionRecords;
    uint256 public nextRulePackageId = 1;
    uint256 public nextSupersessionRecordId = 1;

    event RulePackageRegistered(
        bytes32 indexed appId, bytes32 indexed workflowKey, bytes32 modulesHash, string uri, address registeredBy
    );
    event RulePackageVersionRegistered(
        bytes32 indexed appId,
        bytes32 indexed workflowKey,
        uint256 indexed packageId,
        bytes32 modulesHash,
        bytes32 modulesIdentityHash,
        uint64 version,
        bytes32 compatibilityKey,
        address registeredBy
    );
    event RulePackageChallengeLifecycleBound(
        bytes32 indexed appId,
        bytes32 indexed workflowKey,
        uint256 indexed packageId,
        address challengeLifecycleModule,
        bytes32 modulesHash
    );
    event RulePackageAuthorityBound(
        bytes32 indexed appId,
        bytes32 indexed workflowKey,
        uint256 indexed packageId,
        bytes32 authorityId,
        address registeredBy
    );
    event RulePackageSuperseded(
        uint256 indexed id,
        bytes32 indexed appId,
        bytes32 indexed workflowKey,
        uint256 previousPackageId,
        uint256 newPackageId,
        uint64 previousVersion,
        uint64 newVersion
    );

    constructor(
        AuthorityMatrix authorityMatrix_,
        AVAApplicationRegistry applicationRegistry_,
        RulePackageIdentityVerifier identityVerifier_
    ) {
        if (address(applicationRegistry_) == address(0) || address(identityVerifier_) == address(0)) {
            revert AVADataTypes.EmptyValue();
        }
        authorityMatrix = authorityMatrix_;
        applicationRegistry = applicationRegistry_;
        identityVerifier = identityVerifier_;
    }

    function registerRulePackage(
        AVADataTypes.Role actingRole,
        bytes32 appId,
        bytes32 workflowKey,
        RulePackageModules calldata modules,
        string calldata uri
    ) external returns (uint256 packageId) {
        bytes32 authorityId = authorityMatrix.requireAuthorisedCanonicalSubject(
            msg.sender, actingRole, AVADataTypes.Action.RegisterRulePackage
        );
        bytes32 activeKey = _applicationWorkflowKey(appId, workflowKey);
        if (activePackageIdByApplicationWorkflow[activeKey] != 0) {
            revert AVADataTypes.InvalidState(activePackageIdByApplicationWorkflow[activeKey]);
        }
        return _registerRulePackage(actingRole, appId, workflowKey, modules, uri, authorityId);
    }

    function supersedeRulePackage(
        AVADataTypes.Role actingRole,
        bytes32 appId,
        bytes32 workflowKey,
        uint256 expectedCurrentPackageId,
        RulePackageModules calldata modules,
        string calldata uri
    ) external returns (uint256 packageId) {
        bytes32 authorityId = authorityMatrix.requireAuthorisedCanonicalSubject(
            msg.sender, actingRole, AVADataTypes.Action.RegisterRulePackage
        );
        bytes32 activeKey = _applicationWorkflowKey(appId, workflowKey);
        uint256 currentPackageId = activePackageIdByApplicationWorkflow[activeKey];
        if (currentPackageId == 0) revert AVADataTypes.UnknownReference(uint256(workflowKey));
        if (currentPackageId != expectedCurrentPackageId) {
            revert AVADataTypes.InvalidState(expectedCurrentPackageId);
        }
        RulePackage memory currentPackage = getRulePackageById(currentPackageId);
        if (modules.version <= currentPackage.version) revert AVADataTypes.InvalidState(modules.version);

        packageId = _registerRulePackage(actingRole, appId, workflowKey, modules, uri, authorityId);
        uint256 supersessionId = nextSupersessionRecordId++;
        supersessionRecords[supersessionId] = AVADataTypes.RulePackageSupersessionRecord({
            id: supersessionId,
            appId: appId,
            workflowKey: workflowKey,
            previousPackageId: currentPackageId,
            newPackageId: packageId,
            previousVersion: currentPackage.version,
            newVersion: modules.version,
            compatibilityKey: modules.compatibilityKey,
            authorityId: authorityId,
            createdAt: block.timestamp,
            createdBy: msg.sender
        });
        emit RulePackageSuperseded(
            supersessionId, appId, workflowKey, currentPackageId, packageId, currentPackage.version, modules.version
        );
    }

    function _registerRulePackage(
        AVADataTypes.Role actingRole,
        bytes32 appId,
        bytes32 workflowKey,
        RulePackageModules calldata modules,
        string calldata uri,
        bytes32 authorityId
    ) internal returns (uint256 packageId) {
        applicationRegistry.getApplication(appId);
        if (
            appId == bytes32(0) || workflowKey == bytes32(0) || address(modules.applicationModule) == address(0)
                || modules.applicationModule.applicationId() != appId
                || address(modules.attributionModule) == address(0) || address(modules.verificationModule) == address(0)
                || address(modules.allocationModule) == address(0)
                || address(modules.transitionRuleModule) == address(0)
                || address(modules.disclosureModule) == address(0) || address(modules.standingAdapter) == address(0)
                || address(modules.consequenceAdapter) == address(0) || address(modules.rewardAdapter) == address(0)
                || address(modules.priorityAdapter) == address(0) || address(modules.penaltyAdapter) == address(0)
                || address(modules.restorationAdapter) == address(0)
                || address(modules.challengeLifecycleModule) == address(0)
                || address(modules.evidencePolicyModule) == address(0) || address(modules.auditAdapter) == address(0)
                || address(modules.editorialSystemAdapter) == address(0)
                || address(modules.residualEditorialAuthorityModule) == address(0)
                || address(modules.fieldPolicyModule) == address(0) || address(modules.antiAbuseModule) == address(0)
                || address(modules.valueExecutionAdapter) == address(0)
                || address(modules.standingComputationModule) == address(0)
                || address(modules.rulePackageLifecycleModule) == address(0)
                || address(modules.evidenceLifecycleModule) == address(0)
                || address(modules.disclosureLifecycleModule) == address(0)
                || address(modules.disclosureExecutionModule) == address(0) || modules.version == 0
                || modules.compatibilityKey == bytes32(0) || modules.deprecated
        ) {
            revert AVADataTypes.EmptyValue();
        }
        bytes32 modulesIdentityHash = _hashModuleIdentities(modules);
        bytes32 modulesHash = _hashModules(modules, modulesIdentityHash);
        modules.rulePackageLifecycleModule
            .validateRulePackageLifecycle(
                IRulePackageLifecycleModule.RulePackageLifecycleContext({
                    workflowKey: workflowKey,
                    modulesHash: modulesHash,
                    modulesIdentityHash: modulesIdentityHash,
                    kind: AVADataTypes.RulePackageLifecycleKind.None,
                    version: modules.version,
                    compatibilityKey: modules.compatibilityKey,
                    dependencyURI: modules.dependencyURI,
                    deprecated: modules.deprecated,
                    targetWorkflowKey: bytes32(0),
                    targetPackageId: 0,
                    targetModulesHash: bytes32(0),
                    targetModulesIdentityHash: bytes32(0),
                    targetVersion: 0,
                    targetCompatibilityKey: bytes32(0),
                    authorityRole: actingRole,
                    actor: msg.sender
                })
            );

        packageId = nextRulePackageId++;
        rulePackagesById[packageId] = RulePackage({
            packageId: packageId,
            appId: appId,
            workflowKey: workflowKey,
            modulesHash: modulesHash,
            modulesIdentityHash: modulesIdentityHash,
            applicationModule: modules.applicationModule,
            attributionModule: modules.attributionModule,
            verificationModule: modules.verificationModule,
            allocationModule: modules.allocationModule,
            transitionRuleModule: modules.transitionRuleModule,
            disclosureModule: modules.disclosureModule,
            standingAdapter: modules.standingAdapter,
            consequenceAdapter: modules.consequenceAdapter,
            rewardAdapter: modules.rewardAdapter,
            priorityAdapter: modules.priorityAdapter,
            penaltyAdapter: modules.penaltyAdapter,
            restorationAdapter: modules.restorationAdapter,
            challengeLifecycleModule: modules.challengeLifecycleModule,
            evidencePolicyModule: modules.evidencePolicyModule,
            auditAdapter: modules.auditAdapter,
            editorialSystemAdapter: modules.editorialSystemAdapter,
            residualEditorialAuthorityModule: modules.residualEditorialAuthorityModule,
            fieldPolicyModule: modules.fieldPolicyModule,
            antiAbuseModule: modules.antiAbuseModule,
            valueExecutionAdapter: modules.valueExecutionAdapter,
            standingComputationModule: modules.standingComputationModule,
            rulePackageLifecycleModule: modules.rulePackageLifecycleModule,
            evidenceLifecycleModule: modules.evidenceLifecycleModule,
            disclosureLifecycleModule: modules.disclosureLifecycleModule,
            disclosureExecutionModule: modules.disclosureExecutionModule,
            version: modules.version,
            compatibilityKey: modules.compatibilityKey,
            dependencyURI: modules.dependencyURI,
            deprecated: modules.deprecated,
            uri: uri,
            authorityId: authorityId,
            registeredBy: msg.sender,
            active: true
        });
        activePackageIdByApplicationWorkflow[_applicationWorkflowKey(appId, workflowKey)] = packageId;

        emit RulePackageRegistered(appId, workflowKey, modulesHash, uri, msg.sender);
        emit RulePackageVersionRegistered(
            appId,
            workflowKey,
            packageId,
            modulesHash,
            modulesIdentityHash,
            modules.version,
            modules.compatibilityKey,
            msg.sender
        );
        emit RulePackageChallengeLifecycleBound(
            appId, workflowKey, packageId, address(modules.challengeLifecycleModule), modulesHash
        );
        emit RulePackageAuthorityBound(appId, workflowKey, packageId, authorityId, msg.sender);
    }

    function getRulePackage(bytes32 appId, bytes32 workflowKey) public view returns (RulePackage memory) {
        return getRulePackageById(getActivePackageId(appId, workflowKey));
    }

    function getRulePackageById(uint256 packageId) public view returns (RulePackage memory) {
        RulePackage memory rulePackage = rulePackagesById[packageId];
        if (!rulePackage.active) revert AVADataTypes.UnknownReference(packageId);
        applicationRegistry.getApplication(rulePackage.appId);
        if (rulePackage.applicationModule.applicationId() != rulePackage.appId) {
            revert AVADataTypes.InvalidState(packageId);
        }
        if (_hashStoredModuleIdentities(rulePackage) != rulePackage.modulesIdentityHash) {
            revert AVADataTypes.InvalidState(packageId);
        }
        return rulePackage;
    }

    function getActivePackageId(bytes32 appId, bytes32 workflowKey) public view returns (uint256) {
        uint256 packageId = activePackageIdByApplicationWorkflow[_applicationWorkflowKey(appId, workflowKey)];
        if (packageId == 0) revert AVADataTypes.UnknownReference(uint256(workflowKey));
        return packageId;
    }

    function _applicationWorkflowKey(bytes32 appId, bytes32 workflowKey) internal pure returns (bytes32) {
        if (appId == bytes32(0) || workflowKey == bytes32(0)) revert AVADataTypes.EmptyValue();
        return keccak256(abi.encode(appId, workflowKey));
    }

    function getRulePackageSupersessionRecord(uint256 id)
        external
        view
        returns (AVADataTypes.RulePackageSupersessionRecord memory)
    {
        AVADataTypes.RulePackageSupersessionRecord memory record = supersessionRecords[id];
        if (record.id == 0) revert AVADataTypes.UnknownReference(id);
        return record;
    }

    function hashModules(RulePackageModules calldata modules) external view returns (bytes32) {
        return _hashModules(modules, _hashModuleIdentities(modules));
    }

    function hashModuleIdentities(RulePackageModules calldata modules) external view returns (bytes32) {
        return _hashModuleIdentities(modules);
    }

    function _hashModules(RulePackageModules calldata modules, bytes32 modulesIdentityHash)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(modules, modulesIdentityHash));
    }

    function _hashModuleIdentities(RulePackageModules calldata modules) internal view returns (bytes32) {
        return identityVerifier.hashModuleIdentities(_moduleAddresses(modules));
    }

    function _hashStoredModuleIdentities(RulePackage memory rulePackage) internal view returns (bytes32) {
        return identityVerifier.hashModuleIdentities(_storedModuleAddresses(rulePackage));
    }

    function _moduleAddresses(RulePackageModules calldata modules) internal pure returns (address[] memory values) {
        values = new address[](25);
        values[0] = address(modules.applicationModule);
        values[1] = address(modules.attributionModule);
        values[2] = address(modules.verificationModule);
        values[3] = address(modules.allocationModule);
        values[4] = address(modules.transitionRuleModule);
        values[5] = address(modules.disclosureModule);
        values[6] = address(modules.standingAdapter);
        values[7] = address(modules.consequenceAdapter);
        values[8] = address(modules.rewardAdapter);
        values[9] = address(modules.priorityAdapter);
        values[10] = address(modules.penaltyAdapter);
        values[11] = address(modules.restorationAdapter);
        values[12] = address(modules.challengeLifecycleModule);
        values[13] = address(modules.evidencePolicyModule);
        values[14] = address(modules.auditAdapter);
        values[15] = address(modules.editorialSystemAdapter);
        values[16] = address(modules.residualEditorialAuthorityModule);
        values[17] = address(modules.fieldPolicyModule);
        values[18] = address(modules.antiAbuseModule);
        values[19] = address(modules.valueExecutionAdapter);
        values[20] = address(modules.standingComputationModule);
        values[21] = address(modules.rulePackageLifecycleModule);
        values[22] = address(modules.evidenceLifecycleModule);
        values[23] = address(modules.disclosureLifecycleModule);
        values[24] = address(modules.disclosureExecutionModule);
    }

    function _storedModuleAddresses(RulePackage memory modules) internal pure returns (address[] memory values) {
        values = new address[](25);
        values[0] = address(modules.applicationModule);
        values[1] = address(modules.attributionModule);
        values[2] = address(modules.verificationModule);
        values[3] = address(modules.allocationModule);
        values[4] = address(modules.transitionRuleModule);
        values[5] = address(modules.disclosureModule);
        values[6] = address(modules.standingAdapter);
        values[7] = address(modules.consequenceAdapter);
        values[8] = address(modules.rewardAdapter);
        values[9] = address(modules.priorityAdapter);
        values[10] = address(modules.penaltyAdapter);
        values[11] = address(modules.restorationAdapter);
        values[12] = address(modules.challengeLifecycleModule);
        values[13] = address(modules.evidencePolicyModule);
        values[14] = address(modules.auditAdapter);
        values[15] = address(modules.editorialSystemAdapter);
        values[16] = address(modules.residualEditorialAuthorityModule);
        values[17] = address(modules.fieldPolicyModule);
        values[18] = address(modules.antiAbuseModule);
        values[19] = address(modules.valueExecutionAdapter);
        values[20] = address(modules.standingComputationModule);
        values[21] = address(modules.rulePackageLifecycleModule);
        values[22] = address(modules.evidenceLifecycleModule);
        values[23] = address(modules.disclosureLifecycleModule);
        values[24] = address(modules.disclosureExecutionModule);
    }
}
