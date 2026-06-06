// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "./AVADataTypes.sol";
import {AuthorityMatrix} from "./AuthorityMatrix.sol";
import {DisclosurePolicyRegistry} from "./DisclosurePolicyRegistry.sol";
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

contract AVARulePackageRegistry {
    struct RulePackage {
        uint256 packageId;
        bytes32 workflowKey;
        bytes32 modulesHash;
        bytes32 modulesCodeHash;
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
    DisclosurePolicyRegistry public immutable disclosureRegistry;

    mapping(uint256 => RulePackage) private rulePackagesById;
    mapping(bytes32 => uint256) private activePackageIdByWorkflowKey;
    mapping(uint256 => AVADataTypes.RulePackageLifecycleRecord) private lifecycleRecords;
    mapping(uint256 => AVADataTypes.DisclosureLifecycleRecord) private disclosureLifecycleRecords;
    uint256 public nextRulePackageId = 1;
    uint256 public nextRulePackageLifecycleRecordId = 1;
    uint256 public nextDisclosureLifecycleRecordId = 1;

    event RulePackageRegistered(bytes32 indexed workflowKey, bytes32 modulesHash, string uri, address registeredBy);
    event RulePackageVersionRegistered(
        bytes32 indexed workflowKey,
        uint256 indexed packageId,
        bytes32 modulesHash,
        bytes32 modulesCodeHash,
        uint64 version,
        bytes32 compatibilityKey,
        address registeredBy
    );
    event RulePackageChallengeLifecycleBound(
        bytes32 indexed workflowKey,
        uint256 indexed packageId,
        address indexed challengeLifecycleModule,
        bytes32 modulesHash
    );
    event RulePackageAuthorityBound(
        bytes32 indexed workflowKey, uint256 indexed packageId, bytes32 indexed authorityId, address registeredBy
    );
    event RulePackageLifecycleRecorded(
        uint256 indexed id,
        bytes32 indexed workflowKey,
        AVADataTypes.RulePackageLifecycleKind indexed kind,
        bytes32 targetWorkflowKey,
        uint256 targetPackageId
    );
    event RulePackageLifecyclePackageBinding(
        uint256 indexed id,
        uint256 indexed packageId,
        uint256 indexed targetPackageId,
        bytes32 modulesHash,
        bytes32 modulesCodeHash,
        bytes32 targetModulesHash,
        bytes32 targetModulesCodeHash
    );
    event DisclosureLifecycleRecorded(
        uint256 indexed id,
        bytes32 indexed workflowKey,
        uint256 indexed disclosurePolicyId,
        AVADataTypes.DisclosureLifecycleKind kind
    );

    constructor(AuthorityMatrix authorityMatrix_, DisclosurePolicyRegistry disclosureRegistry_) {
        authorityMatrix = authorityMatrix_;
        disclosureRegistry = disclosureRegistry_;
    }

    function registerRulePackage(
        AVADataTypes.Role actingRole,
        bytes32 workflowKey,
        RulePackageModules calldata modules,
        string calldata uri
    ) external {
        bytes32 authorityId = authorityMatrix.requireAuthorisedCanonicalSubject(
            msg.sender, actingRole, AVADataTypes.Action.RegisterRulePackage
        );
        if (
            workflowKey == bytes32(0) || address(modules.attributionModule) == address(0)
                || address(modules.verificationModule) == address(0) || address(modules.allocationModule) == address(0)
                || address(modules.transitionRuleModule) == address(0) || address(modules.disclosureModule) == address(0)
                || address(modules.standingAdapter) == address(0) || address(modules.consequenceAdapter) == address(0)
                || address(modules.rewardAdapter) == address(0) || address(modules.priorityAdapter) == address(0)
                || address(modules.penaltyAdapter) == address(0) || address(modules.restorationAdapter) == address(0)
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
        bytes32 modulesCodeHash = _hashModuleCodeIdentities(modules);
        bytes32 modulesHash = _hashModules(modules, modulesCodeHash);
        modules.rulePackageLifecycleModule.validateRulePackageLifecycle(
            IRulePackageLifecycleModule.RulePackageLifecycleContext({
                workflowKey: workflowKey,
                modulesHash: modulesHash,
                modulesCodeHash: modulesCodeHash,
                kind: AVADataTypes.RulePackageLifecycleKind.None,
                version: modules.version,
                compatibilityKey: modules.compatibilityKey,
                dependencyURI: modules.dependencyURI,
                deprecated: modules.deprecated,
                targetWorkflowKey: bytes32(0),
                targetPackageId: 0,
                targetModulesHash: bytes32(0),
                targetModulesCodeHash: bytes32(0),
                targetVersion: 0,
                targetCompatibilityKey: bytes32(0),
                authorityRole: actingRole,
                actor: msg.sender
            })
        );

        uint256 packageId = nextRulePackageId++;
        rulePackagesById[packageId] = RulePackage({
            packageId: packageId,
            workflowKey: workflowKey,
            modulesHash: modulesHash,
            modulesCodeHash: modulesCodeHash,
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
        activePackageIdByWorkflowKey[workflowKey] = packageId;

        emit RulePackageRegistered(workflowKey, modulesHash, uri, msg.sender);
        emit RulePackageVersionRegistered(
            workflowKey, packageId, modulesHash, modulesCodeHash, modules.version, modules.compatibilityKey, msg.sender
        );
        emit RulePackageChallengeLifecycleBound(
            workflowKey, packageId, address(modules.challengeLifecycleModule), modulesHash
        );
        emit RulePackageAuthorityBound(workflowKey, packageId, authorityId, msg.sender);
    }

    function recordRulePackageLifecycle(
        AVADataTypes.Role actingRole,
        bytes32 workflowKey,
        AVADataTypes.RulePackageLifecycleKind kind,
        bytes32 targetWorkflowKey,
        string calldata uri
    ) external returns (uint256 id) {
        bytes32 authorityId = authorityMatrix.requireAuthorisedCanonicalSubject(
            msg.sender, actingRole, AVADataTypes.Action.RegisterRulePackage
        );
        if (workflowKey == bytes32(0) || kind == AVADataTypes.RulePackageLifecycleKind.None) {
            revert AVADataTypes.EmptyValue();
        }
        uint256 packageId = getActivePackageId(workflowKey);
        bool targetRequired = kind == AVADataTypes.RulePackageLifecycleKind.SupersessionReady
            || kind == AVADataTypes.RulePackageLifecycleKind.MigrationReady;
        uint256 targetPackageId;
        if (targetRequired) {
            if (targetWorkflowKey == bytes32(0)) revert AVADataTypes.EmptyValue();
            targetPackageId = getActivePackageId(targetWorkflowKey);
        } else if (targetWorkflowKey != bytes32(0)) {
            revert AVADataTypes.InvalidState(uint256(targetWorkflowKey));
        }
        id = _recordRulePackageLifecycleForPackage(actingRole, packageId, kind, targetPackageId, uri, authorityId);
    }

    function recordRulePackageLifecycleForPackage(
        AVADataTypes.Role actingRole,
        uint256 packageId,
        AVADataTypes.RulePackageLifecycleKind kind,
        uint256 targetPackageId,
        string calldata uri
    ) external returns (uint256 id) {
        bytes32 authorityId = authorityMatrix.requireAuthorisedCanonicalSubject(
            msg.sender, actingRole, AVADataTypes.Action.RegisterRulePackage
        );
        id = _recordRulePackageLifecycleForPackage(actingRole, packageId, kind, targetPackageId, uri, authorityId);
    }

    function _recordRulePackageLifecycleForPackage(
        AVADataTypes.Role actingRole,
        uint256 packageId,
        AVADataTypes.RulePackageLifecycleKind kind,
        uint256 targetPackageId,
        string calldata uri,
        bytes32 authorityId
    ) internal returns (uint256 id) {
        if (packageId == 0 || kind == AVADataTypes.RulePackageLifecycleKind.None) {
            revert AVADataTypes.EmptyValue();
        }
        RulePackage memory rulePackage = getRulePackageById(packageId);
        bool targetRequired = kind == AVADataTypes.RulePackageLifecycleKind.SupersessionReady
            || kind == AVADataTypes.RulePackageLifecycleKind.MigrationReady;
        if (targetRequired && targetPackageId == 0) revert AVADataTypes.EmptyValue();
        if (!targetRequired && targetPackageId != 0) revert AVADataTypes.InvalidState(targetPackageId);
        if (targetRequired && targetPackageId == packageId) revert AVADataTypes.InvalidState(targetPackageId);

        RulePackage memory targetPackage;
        if (targetRequired) {
            targetPackage = getRulePackageById(targetPackageId);
        }
        rulePackage.rulePackageLifecycleModule.validateRulePackageLifecycle(
            IRulePackageLifecycleModule.RulePackageLifecycleContext({
                workflowKey: rulePackage.workflowKey,
                modulesHash: rulePackage.modulesHash,
                modulesCodeHash: rulePackage.modulesCodeHash,
                kind: kind,
                version: rulePackage.version,
                compatibilityKey: rulePackage.compatibilityKey,
                dependencyURI: rulePackage.dependencyURI,
                deprecated: rulePackage.deprecated,
                targetWorkflowKey: targetPackage.workflowKey,
                targetPackageId: targetPackageId,
                targetModulesHash: targetPackage.modulesHash,
                targetModulesCodeHash: targetPackage.modulesCodeHash,
                targetVersion: targetPackage.version,
                targetCompatibilityKey: targetPackage.compatibilityKey,
                authorityRole: actingRole,
                actor: msg.sender
            })
        );

        id = nextRulePackageLifecycleRecordId++;
        lifecycleRecords[id] = AVADataTypes.RulePackageLifecycleRecord({
            id: id,
            workflowKey: rulePackage.workflowKey,
            packageId: rulePackage.packageId,
            kind: kind,
            modulesHash: rulePackage.modulesHash,
            modulesCodeHash: rulePackage.modulesCodeHash,
            version: rulePackage.version,
            compatibilityKey: rulePackage.compatibilityKey,
            targetWorkflowKey: targetPackage.workflowKey,
            targetPackageId: targetPackageId,
            targetModulesHash: targetPackage.modulesHash,
            targetModulesCodeHash: targetPackage.modulesCodeHash,
            targetVersion: targetPackage.version,
            targetCompatibilityKey: targetPackage.compatibilityKey,
            dependencyURI: rulePackage.dependencyURI,
            uri: uri,
            authorityRole: actingRole,
            authorityId: authorityId,
            recordedBy: msg.sender
        });

        emit RulePackageLifecycleRecorded(id, rulePackage.workflowKey, kind, targetPackage.workflowKey, targetPackageId);
        emit RulePackageLifecyclePackageBinding(
            id,
            rulePackage.packageId,
            targetPackageId,
            rulePackage.modulesHash,
            rulePackage.modulesCodeHash,
            targetPackage.modulesHash,
            targetPackage.modulesCodeHash
        );
    }

    function recordDisclosureLifecycleReadiness(
        AVADataTypes.Role actingRole,
        bytes32 workflowKey,
        uint256 disclosurePolicyId,
        AVADataTypes.DisclosureLifecycleKind kind,
        bytes32 lifecycleReference,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256 id) {
        authorityMatrix.requireAuthorisedSubject(
            msg.sender, actingRole, AVADataTypes.Action.RecordDisclosureLifecycle, authorityId
        );
        if (
            workflowKey == bytes32(0) || disclosurePolicyId == 0 || kind == AVADataTypes.DisclosureLifecycleKind.None
                || lifecycleReference == bytes32(0) || authorityId == bytes32(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
        disclosureRegistry.getDisclosurePolicy(disclosurePolicyId);
        RulePackage memory rulePackage = getRulePackage(workflowKey);
        rulePackage.disclosureLifecycleModule.validateDisclosureLifecycle(
            workflowKey,
            AVADataTypes.Action.RecordDisclosureLifecycle,
            disclosurePolicyId,
            kind,
            lifecycleReference,
            msg.sender
        );

        id = nextDisclosureLifecycleRecordId++;
        disclosureLifecycleRecords[id] = AVADataTypes.DisclosureLifecycleRecord({
            id: id,
            workflowKey: workflowKey,
            packageId: rulePackage.packageId,
            disclosurePolicyId: disclosurePolicyId,
            kind: kind,
            lifecycleReference: lifecycleReference,
            uri: uri,
            authorityRole: actingRole,
            authorityId: authorityId,
            recordedBy: msg.sender
        });

        emit DisclosureLifecycleRecorded(id, workflowKey, disclosurePolicyId, kind);
    }

    function getRulePackage(bytes32 workflowKey) public view returns (RulePackage memory) {
        return getRulePackageById(getActivePackageId(workflowKey));
    }

    function getRulePackageById(uint256 packageId) public view returns (RulePackage memory) {
        RulePackage memory rulePackage = rulePackagesById[packageId];
        if (!rulePackage.active) revert AVADataTypes.UnknownReference(packageId);
        if (_hashStoredModuleCodeIdentities(rulePackage) != rulePackage.modulesCodeHash) {
            revert AVADataTypes.InvalidState(packageId);
        }
        return rulePackage;
    }

    function getActivePackageId(bytes32 workflowKey) public view returns (uint256) {
        uint256 packageId = activePackageIdByWorkflowKey[workflowKey];
        if (packageId == 0) revert AVADataTypes.UnknownReference(uint256(workflowKey));
        return packageId;
    }

    function getRulePackageLifecycleRecord(uint256 id)
        external
        view
        returns (AVADataTypes.RulePackageLifecycleRecord memory)
    {
        AVADataTypes.RulePackageLifecycleRecord memory record = lifecycleRecords[id];
        if (record.id == 0) revert AVADataTypes.UnknownReference(id);
        return record;
    }

    function getDisclosureLifecycleRecord(uint256 id)
        external
        view
        returns (AVADataTypes.DisclosureLifecycleRecord memory)
    {
        AVADataTypes.DisclosureLifecycleRecord memory record = disclosureLifecycleRecords[id];
        if (record.id == 0) revert AVADataTypes.UnknownReference(id);
        return record;
    }

    function hashModules(RulePackageModules calldata modules) external view returns (bytes32) {
        return _hashModules(modules, _hashModuleCodeIdentities(modules));
    }

    function hashModuleCodeIdentities(RulePackageModules calldata modules) external view returns (bytes32) {
        return _hashModuleCodeIdentities(modules);
    }

    function _hashModules(RulePackageModules calldata modules, bytes32 modulesCodeHash) internal pure returns (bytes32) {
        return keccak256(abi.encode(modules, modulesCodeHash));
    }

    function _hashModuleCodeIdentities(RulePackageModules calldata modules) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                _hashCoreModuleCodeIdentities(modules),
                _hashGovernanceModuleCodeIdentities(modules),
                _hashFutureModuleCodeIdentities(modules)
            )
        );
    }

    function _hashStoredModuleCodeIdentities(RulePackage memory rulePackage) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                _hashStoredCoreModuleCodeIdentities(rulePackage),
                _hashStoredGovernanceModuleCodeIdentities(rulePackage),
                _hashStoredFutureModuleCodeIdentities(rulePackage)
            )
        );
    }

    function _hashCoreModuleCodeIdentities(RulePackageModules calldata modules) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                _moduleCodeHash(address(modules.attributionModule)),
                _moduleCodeHash(address(modules.verificationModule)),
                _moduleCodeHash(address(modules.allocationModule)),
                _moduleCodeHash(address(modules.transitionRuleModule)),
                _moduleCodeHash(address(modules.disclosureModule)),
                _moduleCodeHash(address(modules.standingAdapter)),
                _moduleCodeHash(address(modules.consequenceAdapter)),
                _moduleCodeHash(address(modules.rewardAdapter))
            )
        );
    }

    function _hashGovernanceModuleCodeIdentities(RulePackageModules calldata modules) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                _moduleCodeHash(address(modules.priorityAdapter)),
                _moduleCodeHash(address(modules.penaltyAdapter)),
                _moduleCodeHash(address(modules.restorationAdapter)),
                _moduleCodeHash(address(modules.challengeLifecycleModule)),
                _moduleCodeHash(address(modules.evidencePolicyModule)),
                _moduleCodeHash(address(modules.auditAdapter)),
                _moduleCodeHash(address(modules.editorialSystemAdapter)),
                _moduleCodeHash(address(modules.residualEditorialAuthorityModule))
            )
        );
    }

    function _hashFutureModuleCodeIdentities(RulePackageModules calldata modules) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                _moduleCodeHash(address(modules.fieldPolicyModule)),
                _moduleCodeHash(address(modules.antiAbuseModule)),
                _moduleCodeHash(address(modules.valueExecutionAdapter)),
                _moduleCodeHash(address(modules.standingComputationModule)),
                _moduleCodeHash(address(modules.rulePackageLifecycleModule)),
                _moduleCodeHash(address(modules.evidenceLifecycleModule)),
                _moduleCodeHash(address(modules.disclosureLifecycleModule)),
                _moduleCodeHash(address(modules.disclosureExecutionModule))
            )
        );
    }

    function _hashStoredCoreModuleCodeIdentities(RulePackage memory rulePackage) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                _moduleCodeHash(address(rulePackage.attributionModule)),
                _moduleCodeHash(address(rulePackage.verificationModule)),
                _moduleCodeHash(address(rulePackage.allocationModule)),
                _moduleCodeHash(address(rulePackage.transitionRuleModule)),
                _moduleCodeHash(address(rulePackage.disclosureModule)),
                _moduleCodeHash(address(rulePackage.standingAdapter)),
                _moduleCodeHash(address(rulePackage.consequenceAdapter)),
                _moduleCodeHash(address(rulePackage.rewardAdapter))
            )
        );
    }

    function _hashStoredGovernanceModuleCodeIdentities(RulePackage memory rulePackage) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                _moduleCodeHash(address(rulePackage.priorityAdapter)),
                _moduleCodeHash(address(rulePackage.penaltyAdapter)),
                _moduleCodeHash(address(rulePackage.restorationAdapter)),
                _moduleCodeHash(address(rulePackage.challengeLifecycleModule)),
                _moduleCodeHash(address(rulePackage.evidencePolicyModule)),
                _moduleCodeHash(address(rulePackage.auditAdapter)),
                _moduleCodeHash(address(rulePackage.editorialSystemAdapter)),
                _moduleCodeHash(address(rulePackage.residualEditorialAuthorityModule))
            )
        );
    }

    function _hashStoredFutureModuleCodeIdentities(RulePackage memory rulePackage) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                _moduleCodeHash(address(rulePackage.fieldPolicyModule)),
                _moduleCodeHash(address(rulePackage.antiAbuseModule)),
                _moduleCodeHash(address(rulePackage.valueExecutionAdapter)),
                _moduleCodeHash(address(rulePackage.standingComputationModule)),
                _moduleCodeHash(address(rulePackage.rulePackageLifecycleModule)),
                _moduleCodeHash(address(rulePackage.evidenceLifecycleModule)),
                _moduleCodeHash(address(rulePackage.disclosureLifecycleModule)),
                _moduleCodeHash(address(rulePackage.disclosureExecutionModule))
            )
        );
    }

    function _moduleCodeHash(address module) internal view returns (bytes32 codeHash) {
        if (module.code.length == 0) revert AVADataTypes.EmptyValue();
        codeHash = module.codehash;
    }
}
