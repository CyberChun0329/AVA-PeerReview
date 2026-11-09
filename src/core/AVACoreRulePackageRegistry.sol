// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVAApplicationRegistry} from "../AVAApplicationRegistry.sol";
import {IAVAApplicationModule} from "../interfaces/IAVAApplicationModule.sol";
import {IRuleModuleIdentity} from "../interfaces/IRuleModuleIdentity.sol";
import {AVAAuthorityMatrix} from "./AVAAuthorityMatrix.sol";
import {AVACapabilityKeys} from "./AVACapabilityKeys.sol";
import {AVACoreTypes} from "./AVACoreTypes.sol";

contract AVACoreRulePackageRegistry {
    uint256 public constant MAX_CAPABILITIES_PER_PACKAGE = 64;
    bytes32 private constant MODULE_IDENTITY_FINGERPRINT_DOMAIN =
        keccak256("ava.core.rule-package.unique-module-fingerprint.v1");

    struct ModuleBinding {
        bytes32 capabilityKey;
        IRuleModuleIdentity module;
    }

    struct RulePackage {
        uint256 packageId;
        bytes32 appId;
        bytes32 workflowKey;
        bytes32 modulesHash;
        bytes32 modulesIdentityHash;
        bytes32 modulesIdentityFingerprint;
        uint64 version;
        bytes32 compatibilityKey;
        string uri;
        bytes32 authorityId;
        address registeredBy;
        bool active;
    }

    /// @notice Fixed-size package context for contract-to-contract hot paths.
    /// @dev Full package metadata, including URI and registrar, remains available through getRulePackageById.
    struct VerifiedPackageContext {
        uint256 packageId;
        bytes32 appId;
        bytes32 workflowKey;
        uint64 version;
        bytes32 compatibilityKey;
        bytes32 authorityId;
    }

    /// @notice Fixed-layout module set used by recognised-state formation and transition hot paths.
    /// @dev The generic capability-key reader remains available for application and future extension capabilities.
    struct WorkflowPolicyModules {
        address application;
        address verification;
        address transitionRule;
        address evidencePolicy;
        address evidenceLifecycle;
        address disclosurePolicy;
        address authorityPolicy;
        address fieldPolicy;
        address antiAbusePolicy;
    }

    /// @notice Fixed-layout module set used by challenge policy validation hot paths.
    struct ChallengePolicyModules {
        address challengePolicy;
        address disclosurePolicy;
        address authorityPolicy;
        address antiAbusePolicy;
    }

    struct PackageMetadata {
        bytes32 appId;
        bytes32 workflowKey;
        bytes32 authorityId;
        uint64 version;
        bytes32 compatibilityKey;
        string uri;
    }

    struct PackageRegistrationInput {
        bytes32 appId;
        bytes32 workflowKey;
        bytes32 roleKey;
        bytes32 authorityId;
        uint64 version;
        bytes32 compatibilityKey;
        string uri;
    }

    struct BindingCommitmentBuffer {
        address[] modules;
        bytes32[] identities;
        bytes32[] capabilities;
        address[] uniqueModules;
        bytes32[] uniqueIdentities;
        uint256 uniqueModuleCount;
    }

    struct BindingCommitments {
        bytes32 modulesHash;
        bytes32 modulesIdentityHash;
        bytes32 modulesIdentityFingerprint;
        uint256 uniqueModuleCount;
    }

    AVAApplicationRegistry public immutable APPLICATION_REGISTRY;
    AVAAuthorityMatrix public immutable AUTHORITY_MATRIX;

    mapping(uint256 => RulePackage) private rulePackages;
    mapping(uint256 => bytes32[]) private capabilityKeysByPackage;
    mapping(uint256 => mapping(bytes32 => IRuleModuleIdentity)) private moduleByPackageCapability;
    mapping(uint256 => IRuleModuleIdentity[]) private uniqueModulesByPackage;
    mapping(bytes32 => uint256) private activePackageByApplicationWorkflow;
    uint256 public nextPackageId = 1;

    event RulePackageRegistered(
        uint256 indexed packageId,
        bytes32 indexed appId,
        bytes32 indexed workflowKey,
        bytes32 modulesHash,
        address registeredBy
    );
    event RulePackageIdentityBound(
        uint256 indexed packageId,
        bytes32 modulesIdentityHash,
        uint64 version,
        bytes32 compatibilityKey,
        bytes32 authorityId
    );
    event RulePackageVerificationBound(
        uint256 indexed packageId,
        bytes32 indexed modulesHash,
        bytes32 modulesIdentityFingerprint,
        uint256 uniqueModuleCount
    );
    event RulePackageSuperseded(
        bytes32 indexed appId,
        bytes32 indexed workflowKey,
        uint256 indexed previousPackageId,
        uint256 replacementPackageId,
        address supersededBy
    );
    event RulePackageCapabilityBound(uint256 indexed packageId, bytes32 indexed capabilityKey, address indexed module);

    constructor(AVAApplicationRegistry applicationRegistry_, AVAAuthorityMatrix authorityMatrix_) {
        if (address(applicationRegistry_) == address(0) || address(authorityMatrix_) == address(0)) {
            revert AVACoreTypes.EmptyValue();
        }
        if (address(authorityMatrix_.APPLICATION_REGISTRY()) != address(applicationRegistry_)) {
            revert AVACoreTypes.InvalidState(0);
        }
        APPLICATION_REGISTRY = applicationRegistry_;
        AUTHORITY_MATRIX = authorityMatrix_;
    }

    function registerRulePackage(PackageRegistrationInput calldata input, ModuleBinding[] calldata bindings)
        external
        returns (uint256 packageId)
    {
        if (
            input.appId == bytes32(0) || input.workflowKey == bytes32(0) || input.roleKey == bytes32(0)
                || input.authorityId == bytes32(0) || input.version != 1 || input.compatibilityKey == bytes32(0)
                || activePackageByApplicationWorkflow[_workflowKey(input.appId, input.workflowKey)] != 0
        ) {
            revert AVACoreTypes.InvalidState(0);
        }
        _requireRegistrar(input.appId, input.roleKey, input.authorityId);
        packageId = _storePackage(
            PackageMetadata({
                appId: input.appId,
                workflowKey: input.workflowKey,
                authorityId: input.authorityId,
                version: input.version,
                compatibilityKey: input.compatibilityKey,
                uri: input.uri
            }),
            bindings
        );
        activePackageByApplicationWorkflow[_workflowKey(input.appId, input.workflowKey)] = packageId;
    }

    function supersedeRulePackage(
        PackageRegistrationInput calldata input,
        uint256 previousPackageId,
        ModuleBinding[] calldata bindings
    ) external returns (uint256 packageId) {
        if (input.appId == bytes32(0) || input.workflowKey == bytes32(0) || previousPackageId == 0) {
            revert AVACoreTypes.EmptyValue();
        }
        _requireRegistrar(input.appId, input.roleKey, input.authorityId);
        bytes32 pointerKey = _workflowKey(input.appId, input.workflowKey);
        if (activePackageByApplicationWorkflow[pointerKey] != previousPackageId) {
            revert AVACoreTypes.InvalidState(previousPackageId);
        }
        RulePackage storage previous = _verifiedPackage(previousPackageId);
        if (
            previous.appId != input.appId || previous.workflowKey != input.workflowKey
                || input.version != previous.version + 1 || input.compatibilityKey != previous.compatibilityKey
        ) {
            revert AVACoreTypes.InvalidState(previousPackageId);
        }
        packageId = _storePackage(
            PackageMetadata({
                appId: input.appId,
                workflowKey: input.workflowKey,
                authorityId: input.authorityId,
                version: input.version,
                compatibilityKey: input.compatibilityKey,
                uri: input.uri
            }),
            bindings
        );
        activePackageByApplicationWorkflow[pointerKey] = packageId;
        emit RulePackageSuperseded(input.appId, input.workflowKey, previousPackageId, packageId, msg.sender);
    }

    function getRulePackage(bytes32 appId, bytes32 workflowKey) external view returns (RulePackage memory) {
        return getRulePackageById(getActivePackageId(appId, workflowKey));
    }

    function getRulePackageById(uint256 packageId) public view returns (RulePackage memory rulePackage) {
        RulePackage storage stored = _verifiedPackage(packageId);
        rulePackage = stored;
    }

    function getActivePackageId(bytes32 appId, bytes32 workflowKey) public view returns (uint256 packageId) {
        packageId = activePackageByApplicationWorkflow[_workflowKey(appId, workflowKey)];
        if (packageId == 0) revert AVACoreTypes.UnknownReference(uint256(workflowKey));
    }

    function getModule(uint256 packageId, bytes32 capabilityKey) external view returns (address module) {
        _verifiedPackage(packageId);
        module = address(moduleByPackageCapability[packageId][capabilityKey]);
        if (module == address(0)) revert AVACoreTypes.UnknownReference(packageId);
    }

    function getOptionalModule(uint256 packageId, bytes32 capabilityKey) external view returns (address module) {
        _verifiedPackage(packageId);
        module = address(moduleByPackageCapability[packageId][capabilityKey]);
    }

    /// @notice Returns a caller-selected module set after one complete package identity check.
    /// @dev Missing optional capabilities are returned as address(0); required-profile checks happen at registration.
    function getVerifiedModules(uint256 packageId, bytes32[] calldata capabilityKeys)
        external
        view
        returns (RulePackage memory rulePackage, address[] memory modules)
    {
        rulePackage = getRulePackageById(packageId);
        modules = _requestedModules(packageId, capabilityKeys);
    }

    /// @notice Returns fixed-size package context and caller-selected modules after one complete identity check.
    function getVerifiedModulesCompact(uint256 packageId, bytes32[] calldata capabilityKeys)
        external
        view
        returns (VerifiedPackageContext memory context, address[] memory modules)
    {
        RulePackage storage stored = _verifiedPackage(packageId);
        context = _verifiedPackageContext(stored);
        modules = _requestedModules(packageId, capabilityKeys);
    }

    /// @notice Returns fixed-size package context after one complete identity check.
    function getVerifiedPackageContext(uint256 packageId)
        external
        view
        returns (VerifiedPackageContext memory context)
    {
        context = _verifiedPackageContext(_verifiedPackage(packageId));
    }

    /// @notice Returns the canonical recognised-state policy layout after one complete package identity check.
    function getVerifiedWorkflowPolicyModules(uint256 packageId)
        external
        view
        returns (VerifiedPackageContext memory context, WorkflowPolicyModules memory modules)
    {
        RulePackage storage stored = _verifiedPackage(packageId);
        context = _verifiedPackageContext(stored);
        modules = WorkflowPolicyModules({
            application: address(moduleByPackageCapability[packageId][AVACapabilityKeys.APPLICATION]),
            verification: address(moduleByPackageCapability[packageId][AVACapabilityKeys.VERIFICATION]),
            transitionRule: address(moduleByPackageCapability[packageId][AVACapabilityKeys.TRANSITION_RULE]),
            evidencePolicy: address(moduleByPackageCapability[packageId][AVACapabilityKeys.EVIDENCE_POLICY]),
            evidenceLifecycle: address(moduleByPackageCapability[packageId][AVACapabilityKeys.EVIDENCE_LIFECYCLE]),
            disclosurePolicy: address(moduleByPackageCapability[packageId][AVACapabilityKeys.DISCLOSURE_POLICY]),
            authorityPolicy: address(moduleByPackageCapability[packageId][AVACapabilityKeys.AUTHORITY_POLICY]),
            fieldPolicy: address(moduleByPackageCapability[packageId][AVACapabilityKeys.FIELD_POLICY]),
            antiAbusePolicy: address(moduleByPackageCapability[packageId][AVACapabilityKeys.ANTI_ABUSE])
        });
    }

    /// @notice Returns the canonical challenge policy layout after one complete package identity check.
    function getVerifiedChallengePolicyModules(uint256 packageId)
        external
        view
        returns (VerifiedPackageContext memory context, ChallengePolicyModules memory modules)
    {
        RulePackage storage stored = _verifiedPackage(packageId);
        context = _verifiedPackageContext(stored);
        modules = ChallengePolicyModules({
            challengePolicy: address(moduleByPackageCapability[packageId][AVACapabilityKeys.CHALLENGE_POLICY]),
            disclosurePolicy: address(moduleByPackageCapability[packageId][AVACapabilityKeys.DISCLOSURE_POLICY]),
            authorityPolicy: address(moduleByPackageCapability[packageId][AVACapabilityKeys.AUTHORITY_POLICY]),
            antiAbusePolicy: address(moduleByPackageCapability[packageId][AVACapabilityKeys.ANTI_ABUSE])
        });
    }

    /// @notice Resolves modules only when the expected package is the active package for the application workflow.
    function getActiveVerifiedModulesCompact(
        bytes32 appId,
        bytes32 workflowKey,
        uint256 expectedPackageId,
        bytes32[] calldata capabilityKeys
    ) external view returns (VerifiedPackageContext memory context, address[] memory modules) {
        if (activePackageByApplicationWorkflow[_workflowKey(appId, workflowKey)] != expectedPackageId) {
            revert AVACoreTypes.InvalidState(expectedPackageId);
        }
        RulePackage storage stored = _verifiedPackage(expectedPackageId);
        if (stored.appId != appId || stored.workflowKey != workflowKey) {
            revert AVACoreTypes.InvalidState(expectedPackageId);
        }
        context = _verifiedPackageContext(stored);
        modules = _requestedModules(expectedPackageId, capabilityKeys);
    }

    function getCapabilityKeys(uint256 packageId) external view returns (bytes32[] memory keys) {
        _verifiedPackage(packageId);
        return capabilityKeysByPackage[packageId];
    }

    function _storePackage(PackageMetadata memory metadata, ModuleBinding[] calldata bindings)
        private
        returns (uint256 packageId)
    {
        APPLICATION_REGISTRY.requireApplicationReference(metadata.appId);
        if (bindings.length == 0) revert AVACoreTypes.EmptyValue();
        if (bindings.length > MAX_CAPABILITIES_PER_PACKAGE) revert AVACoreTypes.InvalidState(bindings.length);
        packageId = nextPackageId++;
        BindingCommitments memory commitments = _storeBindings(packageId, bindings);
        _requireExecutableCoreProfile(packageId);
        IAVAApplicationModule applicationModule =
            IAVAApplicationModule(address(moduleByPackageCapability[packageId][AVACapabilityKeys.APPLICATION]));
        if (address(applicationModule) == address(0) || applicationModule.applicationId() != metadata.appId) {
            revert AVACoreTypes.InvalidState(packageId);
        }
        rulePackages[packageId] = RulePackage({
            packageId: packageId,
            appId: metadata.appId,
            workflowKey: metadata.workflowKey,
            modulesHash: commitments.modulesHash,
            modulesIdentityHash: commitments.modulesIdentityHash,
            modulesIdentityFingerprint: commitments.modulesIdentityFingerprint,
            version: metadata.version,
            compatibilityKey: metadata.compatibilityKey,
            uri: metadata.uri,
            authorityId: metadata.authorityId,
            registeredBy: msg.sender,
            active: true
        });
        emit RulePackageRegistered(packageId, metadata.appId, metadata.workflowKey, commitments.modulesHash, msg.sender);
        emit RulePackageIdentityBound(
            packageId,
            commitments.modulesIdentityHash,
            metadata.version,
            metadata.compatibilityKey,
            metadata.authorityId
        );
        emit RulePackageVerificationBound(
            packageId, commitments.modulesHash, commitments.modulesIdentityFingerprint, commitments.uniqueModuleCount
        );
    }

    function _storeBindings(uint256 packageId, ModuleBinding[] calldata bindings)
        private
        returns (BindingCommitments memory commitments)
    {
        BindingCommitmentBuffer memory buffer = BindingCommitmentBuffer({
            modules: new address[](bindings.length),
            identities: new bytes32[](bindings.length),
            capabilities: new bytes32[](bindings.length),
            uniqueModules: new address[](bindings.length),
            uniqueIdentities: new bytes32[](bindings.length),
            uniqueModuleCount: 0
        });
        for (uint256 i; i < bindings.length; ++i) {
            bytes32 capabilityKey = bindings[i].capabilityKey;
            IRuleModuleIdentity module = bindings[i].module;
            if (capabilityKey == bytes32(0) || address(module) == address(0) || address(module).code.length == 0) {
                revert AVACoreTypes.EmptyValue();
            }
            if (address(moduleByPackageCapability[packageId][capabilityKey]) != address(0)) {
                revert AVACoreTypes.InvalidState(packageId);
            }
            moduleByPackageCapability[packageId][capabilityKey] = module;
            capabilityKeysByPackage[packageId].push(capabilityKey);
            buffer.capabilities[i] = capabilityKey;
            buffer.modules[i] = address(module);
            uint256 uniqueIndex = _findModule(buffer.uniqueModules, buffer.uniqueModuleCount, address(module));
            if (uniqueIndex == type(uint256).max) {
                bytes32 identity = module.moduleIdentityHash();
                if (identity == bytes32(0)) revert AVACoreTypes.InvalidState(packageId);
                uniqueIndex = buffer.uniqueModuleCount++;
                buffer.uniqueModules[uniqueIndex] = address(module);
                buffer.uniqueIdentities[uniqueIndex] = identity;
                uniqueModulesByPackage[packageId].push(module);
            }
            buffer.identities[i] = buffer.uniqueIdentities[uniqueIndex];
            emit RulePackageCapabilityBound(packageId, capabilityKey, address(module));
        }
        commitments = BindingCommitments({
            modulesHash: keccak256(abi.encode(buffer.capabilities, buffer.modules)),
            modulesIdentityHash: keccak256(abi.encode(buffer.capabilities, buffer.identities)),
            modulesIdentityFingerprint: _moduleIdentityFingerprint(
                buffer.uniqueModules, buffer.uniqueIdentities, buffer.uniqueModuleCount
            ),
            uniqueModuleCount: buffer.uniqueModuleCount
        });
    }

    function _verifiedPackage(uint256 packageId) private view returns (RulePackage storage rulePackage) {
        rulePackage = rulePackages[packageId];
        if (!rulePackage.active) revert AVACoreTypes.UnknownReference(packageId);
        APPLICATION_REGISTRY.requireApplicationReference(rulePackage.appId);
        if (_currentModuleIdentityFingerprint(packageId) != rulePackage.modulesIdentityFingerprint) {
            revert AVACoreTypes.InvalidState(packageId);
        }
        IAVAApplicationModule applicationModule =
            IAVAApplicationModule(address(moduleByPackageCapability[packageId][AVACapabilityKeys.APPLICATION]));
        if (address(applicationModule) == address(0) || applicationModule.applicationId() != rulePackage.appId) {
            revert AVACoreTypes.InvalidState(packageId);
        }
    }

    function _currentModuleIdentityFingerprint(uint256 packageId) private view returns (bytes32 fingerprint) {
        IRuleModuleIdentity[] storage modules = uniqueModulesByPackage[packageId];
        uint256 count = modules.length;
        fingerprint = MODULE_IDENTITY_FINGERPRINT_DOMAIN;
        for (uint256 i; i < count; ++i) {
            IRuleModuleIdentity module = modules[i];
            bytes32 identity = module.moduleIdentityHash();
            if (identity == bytes32(0)) revert AVACoreTypes.InvalidState(packageId);
            fingerprint = keccak256(abi.encode(fingerprint, address(module), identity));
        }
        fingerprint = keccak256(abi.encode(MODULE_IDENTITY_FINGERPRINT_DOMAIN, count, fingerprint));
    }

    function _moduleIdentityFingerprint(address[] memory modules, bytes32[] memory identities, uint256 length)
        private
        pure
        returns (bytes32 fingerprint)
    {
        fingerprint = MODULE_IDENTITY_FINGERPRINT_DOMAIN;
        for (uint256 i; i < length; ++i) {
            fingerprint = keccak256(abi.encode(fingerprint, modules[i], identities[i]));
        }
        fingerprint = keccak256(abi.encode(MODULE_IDENTITY_FINGERPRINT_DOMAIN, length, fingerprint));
    }

    function _findModule(address[] memory modules, uint256 length, address module)
        private
        pure
        returns (uint256 index)
    {
        for (uint256 i; i < length; ++i) {
            if (modules[i] == module) return i;
        }
        return type(uint256).max;
    }

    function _verifiedPackageContext(RulePackage storage rulePackage)
        private
        view
        returns (VerifiedPackageContext memory context)
    {
        context = VerifiedPackageContext({
            packageId: rulePackage.packageId,
            appId: rulePackage.appId,
            workflowKey: rulePackage.workflowKey,
            version: rulePackage.version,
            compatibilityKey: rulePackage.compatibilityKey,
            authorityId: rulePackage.authorityId
        });
    }

    function _requestedModules(uint256 packageId, bytes32[] calldata capabilityKeys)
        private
        view
        returns (address[] memory modules)
    {
        modules = new address[](capabilityKeys.length);
        for (uint256 i; i < capabilityKeys.length; ++i) {
            modules[i] = address(moduleByPackageCapability[packageId][capabilityKeys[i]]);
        }
    }

    function _requireRegistrar(bytes32 appId, bytes32 roleKey, bytes32 authorityId) private view {
        AUTHORITY_MATRIX.requireAuthorisedSubject(
            msg.sender, appId, roleKey, AVACoreTypes.ACTION_REGISTER_RULE_PACKAGE, authorityId
        );
    }

    function _requireExecutableCoreProfile(uint256 packageId) private view {
        if (
            address(moduleByPackageCapability[packageId][AVACapabilityKeys.APPLICATION]) == address(0)
                || address(moduleByPackageCapability[packageId][AVACapabilityKeys.ATTRIBUTION]) == address(0)
                || address(moduleByPackageCapability[packageId][AVACapabilityKeys.VERIFICATION]) == address(0)
                || address(moduleByPackageCapability[packageId][AVACapabilityKeys.TRANSITION_RULE]) == address(0)
                || address(moduleByPackageCapability[packageId][AVACapabilityKeys.EVIDENCE_POLICY]) == address(0)
                || address(moduleByPackageCapability[packageId][AVACapabilityKeys.EVIDENCE_LIFECYCLE]) == address(0)
                || address(moduleByPackageCapability[packageId][AVACapabilityKeys.DISCLOSURE_POLICY]) == address(0)
                || address(moduleByPackageCapability[packageId][AVACapabilityKeys.AUTHORITY_POLICY]) == address(0)
                || address(moduleByPackageCapability[packageId][AVACapabilityKeys.ALLOCATION]) == address(0)
        ) revert AVACoreTypes.InvalidState(packageId);
    }

    function _workflowKey(bytes32 appId, bytes32 workflowKey) private pure returns (bytes32) {
        return keccak256(abi.encode(appId, workflowKey));
    }
}
