// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVAApplicationRegistry} from "../src/AVAApplicationRegistry.sol";
import {M14PermissiveApplicationModule} from "./helpers/M14ApplicationFixture.sol";
import {IAVAApplicationModule} from "../src/interfaces/IAVAApplicationModule.sol";
import {RuleModuleIdentity} from "../src/interfaces/IRuleModuleIdentity.sol";
import {IZKProofVerifier} from "../src/interfaces/IZKProofVerifier.sol";
import {AVAAuthorityMatrix} from "../src/core/AVAAuthorityMatrix.sol";
import {AVACoreTypes} from "../src/core/AVACoreTypes.sol";
import {AVACoreRulePackageRegistry} from "../src/core/AVACoreRulePackageRegistry.sol";
import {AVADisclosurePolicyRegistry} from "../src/core/AVADisclosurePolicyRegistry.sol";
import {AVAEvidenceRegistry} from "../src/core/AVAEvidenceRegistry.sol";
import {AVAGovernanceKernel} from "../src/core/AVAGovernanceKernel.sol";
import {AVAIdentityRegistry} from "../src/core/AVAIdentityRegistry.sol";
import {AVAWorkflowPolicyRouter} from "../src/core/AVAWorkflowPolicyRouter.sol";
import {
    AVAStandingRecordExtension,
    AVAAllocationRecordExtension,
    AVAConsequenceRecordExtension
} from "../src/extensions/downstream/AVADownstreamRecordExtensions.sol";
import {
    AVAStandingComputationExtension,
    AVAStandingCredentialExtension
} from "../src/extensions/standing/AVAStandingCredentialExtensions.sol";
import {
    AVAStandingProvenanceExtension,
    AVAStandingZKProofExtension,
    AVAStandingZKCredentialExtension
} from "../src/extensions/standing/AVAStandingProvenanceExtensions.sol";
import {AVAStandingRevisionExtension} from "../src/extensions/standing/AVAStandingRevisionExtension.sol";
import {AVAExtensionRecordBase} from "../src/extensions/shared/AVAExtensionRecordBase.sol";
import {IAVAExtensionPolicyModule} from "../src/extensions/shared/IAVAExtensionPolicyModule.sol";
import {AVAPrivacyProofExtension} from "../src/extensions/privacy/AVAPrivacyProofExtension.sol";
import {AVADisclosureReceiptExtension} from "../src/extensions/privacy/AVADisclosureReceiptExtension.sol";
import {AVAAuditReceiptExtension} from "../src/extensions/audit/AVAAuditReceiptExtension.sol";
import {IAVADownstreamRecordSource} from "../src/extensions/downstream/IAVADownstreamRecordSource.sol";
import {AVASettlementReceiptExtension} from "../src/extensions/settlement/AVASettlementReceiptExtension.sol";
import {IAVASettlementReceiptSource} from "../src/extensions/settlement/IAVASettlementReceiptSource.sol";
import {AVAExternalOperationExtension} from "../src/extensions/external/AVAExternalOperationExtension.sol";
import {
    AVAExternalOperationTargetKind,
    AVAExternalOperationTargetResolver
} from "../src/extensions/external/AVAExternalOperationTargetResolver.sol";
import {AVAChallengeExtension} from "../src/extensions/challenge/AVAChallengeExtension.sol";
import "./helpers/M14CorePackageFixture.sol";

interface M14StandingVm {
    function warp(uint256 timestamp) external;

    function chainId(uint256 newChainId) external;

    function etch(address target, bytes calldata code) external;

    function expectCall(address callee, bytes calldata data, uint64 count) external;
}

contract M14ExtensionValidationHarness is AVAExtensionRecordBase {
    constructor(
        AVAGovernanceKernel governanceKernel_,
        AVAAuthorityMatrix authorityMatrix_,
        AVAIdentityRegistry identityRegistry_,
        AVACoreRulePackageRegistry rulePackageRegistry_,
        AVAEvidenceRegistry evidenceRegistry_,
        AVADisclosurePolicyRegistry disclosureRegistry_
    )
        AVAExtensionRecordBase(
            governanceKernel_,
            authorityMatrix_,
            identityRegistry_,
            rulePackageRegistry_,
            evidenceRegistry_,
            disclosureRegistry_
        )
    {}

    function validate(ExtensionValidationInput calldata input)
        external
        view
        returns (AVAGovernanceKernel.RecognisedStateReference memory)
    {
        return _validateExtension(input);
    }
}

contract M14AlwaysValidProofVerifier is IZKProofVerifier {
    bytes32 private constant PROOF_DOMAIN = keccak256("m14.optional-extension-proof-domain");

    function verify(bytes32 contextHash, SchnorrProof calldata) external pure returns (bool) {
        return contextHash != bytes32(0);
    }

    function proofDomain() external pure returns (bytes32) {
        return PROOF_DOMAIN;
    }
}

contract M14BoundedSettlementPolicyModule is IAVAExtensionPolicyModule, RuleModuleIdentity {
    uint256 public immutable MAX_UNITS;

    constructor(uint256 maxUnits) {
        MAX_UNITS = maxUnits;
    }

    function validateExtensionRecord(ExtensionPolicyContext calldata context) external view {
        if (
            context.capabilityKey != AVACapabilityKeys.SETTLEMENT_RECEIPT || context.scopeKey == bytes32(0)
                || context.sourceTypeKey == bytes32(0) || context.payloadHash == bytes32(0)
                || context.unsignedValue > MAX_UNITS
        ) revert AVACoreTypes.InvalidState(context.sourceRecordId);
    }

    function _moduleConfigurationHash() internal view override returns (bytes32) {
        return keccak256(abi.encode(MAX_UNITS));
    }
}

contract M14StandingZKCredentialUsePolicyModule is IAVAExtensionPolicyModule, RuleModuleIdentity {
    bytes32 public constant USE_ACTION = keccak256("ava.extension.standing.use-zk-credential.v1");
    bytes32 public constant BLOCKED_TARGET_ACTION = keccak256("m14.blocked-standing-zk-use-action");

    function validateExtensionRecord(ExtensionPolicyContext calldata context) external pure {
        if (context.actionKey == USE_ACTION && context.scopeKey == BLOCKED_TARGET_ACTION) {
            revert AVACoreTypes.InvalidState(context.sourceRecordId);
        }
    }
}

contract M14StandingHighImpactRequester is RuleModuleIdentity {
    function request(AVAGovernanceKernel kernel, AVAGovernanceKernel.SourceBoundTransitionInput calldata input)
        external
        returns (uint256)
    {
        return kernel.requestSourceBoundTransition(input);
    }
}

contract M14AliasedDownstreamSource is IAVADownstreamRecordSource {
    AVAGovernanceKernel public immutable GOVERNANCE_KERNEL;
    DownstreamSourceContext private source;

    constructor(AVAGovernanceKernel governanceKernel_, DownstreamSourceContext memory source_) {
        GOVERNANCE_KERNEL = governanceKernel_;
        source = source_;
    }

    function getDownstreamSource(uint256) external view returns (DownstreamSourceContext memory) {
        return source;
    }
}

contract M14AliasedSettlementSource is IAVASettlementReceiptSource {
    AVAGovernanceKernel public immutable GOVERNANCE_KERNEL;
    SettlementSourceContext private source;

    constructor(AVAGovernanceKernel governanceKernel_, SettlementSourceContext memory source_) {
        GOVERNANCE_KERNEL = governanceKernel_;
        source = source_;
    }

    function getSettlementSource(uint256) external view returns (SettlementSourceContext memory) {
        return source;
    }
}

contract M14StandingActor {
    function registerPolicy(
        AVADisclosurePolicyRegistry registry,
        bytes32 appId,
        bytes32 roleKey,
        bytes32 authorityId,
        bytes32 policyKey
    ) external returns (uint256) {
        return registry.registerPolicy(
            appId, roleKey, authorityId, policyKey, "m14-standing-policy", "ipfs://m14-standing-policy"
        );
    }

    function registerEvidence(
        AVAEvidenceRegistry registry,
        bytes32 appId,
        bytes32 workflowKey,
        uint256 packageId,
        bytes32 roleKey,
        bytes32 subjectId,
        uint256 disclosurePolicyId,
        bytes32 commitment
    ) external returns (uint256) {
        return registry.registerEvidence(
            AVAEvidenceRegistry.EvidenceRegistrationInput({
                appId: appId,
                workflowKey: workflowKey,
                packageId: packageId,
                roleKey: roleKey,
                subjectId: subjectId,
                commitment: commitment,
                evidenceTypeHash: keccak256("m14-standing-evidence-type"),
                disclosurePolicyId: disclosurePolicyId,
                authorityId: subjectId,
                uri: "ipfs://m14-standing-evidence"
            })
        );
    }

    function recordEvidenceLifecycle(
        AVAEvidenceRegistry registry,
        uint256 evidenceId,
        bytes32 roleKey,
        bytes32 authorityId,
        AVACoreTypes.EvidenceLifecycleKind kind
    ) external returns (uint256) {
        return registry.recordEvidenceLifecycle(
            evidenceId,
            roleKey,
            authorityId,
            kind,
            0,
            keccak256("m14-standing-evidence-lifecycle"),
            "ipfs://m14-standing-evidence-lifecycle"
        );
    }

    function registerObject(AVAGovernanceKernel kernel, AVAGovernanceKernel.GovernedObjectInput calldata input)
        external
        returns (uint256)
    {
        return kernel.registerGovernedObject(input);
    }

    function formState(AVAGovernanceKernel kernel, AVAGovernanceKernel.RecognisedStateFormationInput calldata input)
        external
        returns (uint256)
    {
        return kernel.formRecognisedState(input);
    }

    function vestState(AVAGovernanceKernel kernel, AVAGovernanceKernel.RecognisedStateTransitionInput calldata input)
        external
        returns (uint256)
    {
        return kernel.vestRecognisedState(input);
    }

    function recordStanding(
        AVAStandingRecordExtension extension,
        AVAStandingRecordExtension.StandingInput calldata input
    ) external returns (uint256) {
        return extension.recordStandingUpdate(input);
    }

    function recordAllocation(
        AVAAllocationRecordExtension extension,
        AVAAllocationRecordExtension.AllocationInput calldata input
    ) external returns (uint256) {
        return extension.recordAllocation(input);
    }

    function recordConsequence(
        AVAConsequenceRecordExtension extension,
        AVAConsequenceRecordExtension.ConsequenceInput calldata input
    ) external returns (uint256) {
        return extension.recordConsequence(input);
    }

    function recordComputation(
        AVAStandingComputationExtension extension,
        AVAStandingComputationExtension.ComputationInput calldata input
    ) external returns (uint256) {
        return extension.recordComputation(input);
    }

    function issueCredential(
        AVAStandingCredentialExtension extension,
        AVAStandingCredentialExtension.CredentialInput calldata input
    ) external returns (uint256) {
        return extension.issueCredential(input);
    }

    function supersedeCredential(
        AVAStandingCredentialExtension extension,
        uint256 credentialId,
        AVAStandingCredentialExtension.CredentialInput calldata input
    ) external returns (uint256) {
        return extension.supersedeCredential(credentialId, input);
    }

    function revokeCredential(
        AVAStandingCredentialExtension extension,
        uint256 credentialId,
        bytes32 roleKey,
        bytes32 authorityId
    ) external {
        extension.revokeCredential(credentialId, roleKey, authorityId);
    }

    function registerPrivacyProof(
        AVAPrivacyProofExtension extension,
        AVAPrivacyProofExtension.ProofInput calldata input
    ) external returns (uint256) {
        return extension.registerProof(input);
    }

    function recordDisclosure(
        AVADisclosureReceiptExtension extension,
        AVADisclosureReceiptExtension.DisclosureInput calldata input
    ) external returns (uint256) {
        return extension.recordDisclosure(input);
    }

    function recordAudit(AVAAuditReceiptExtension extension, AVAAuditReceiptExtension.AuditInput calldata input)
        external
        returns (uint256)
    {
        return extension.recordAudit(input);
    }

    function recordSettlement(
        AVASettlementReceiptExtension extension,
        AVASettlementReceiptExtension.SettlementInput calldata input
    ) external returns (uint256) {
        return extension.recordSettlement(input);
    }

    function requestOperation(
        AVAExternalOperationExtension extension,
        AVAExternalOperationExtension.OperationInput calldata input
    ) external returns (uint256) {
        return extension.requestOperation(input);
    }

    function requestTargetOperation(
        AVAExternalOperationExtension extension,
        AVAExternalOperationExtension.TargetOperationInput calldata input
    ) external returns (uint256) {
        return extension.requestTargetOperation(input);
    }

    function recordOperationOutcome(
        AVAExternalOperationExtension extension,
        uint256 operationId,
        AVAExternalOperationExtension.OperationStatus status,
        bytes32 roleKey,
        bytes32 authorityId,
        bytes32 outcomeHash
    ) external returns (uint256) {
        return extension.recordOutcome(
            operationId, status, roleKey, authorityId, outcomeHash, "ipfs://m14-operation-outcome"
        );
    }

    function registerStandingFormula(
        AVAStandingProvenanceExtension extension,
        AVAStandingProvenanceExtension.FormulaInput calldata input
    ) external returns (uint256) {
        return extension.registerFormula(input);
    }

    function registerStandingSourceSet(
        AVAStandingProvenanceExtension extension,
        AVAStandingProvenanceExtension.SourceSetInput calldata input
    ) external returns (uint256) {
        return extension.registerSourceSet(input);
    }

    function attestStandingSourceSet(
        AVAStandingProvenanceExtension extension,
        AVAStandingProvenanceExtension.CompletenessInput calldata input
    ) external returns (uint256) {
        return extension.recordCompletenessAttestation(input);
    }

    function recordStandingStatement(
        AVAStandingProvenanceExtension extension,
        AVAStandingProvenanceExtension.StatementInput calldata input
    ) external returns (uint256) {
        return extension.recordComputationStatement(input);
    }

    function registerStandingZKProof(
        AVAStandingZKProofExtension extension,
        AVAStandingZKProofExtension.ProofInput calldata input
    ) external returns (uint256) {
        return extension.registerProof(input);
    }

    function issueStandingZKCredential(
        AVAStandingZKCredentialExtension extension,
        AVAStandingZKCredentialExtension.CredentialInput calldata input
    ) external returns (uint256) {
        return extension.issueCredential(input);
    }

    function supersedeStandingZKCredential(
        AVAStandingZKCredentialExtension extension,
        uint256 credentialId,
        AVAStandingZKCredentialExtension.CredentialInput calldata input
    ) external returns (uint256) {
        return extension.supersedeCredential(credentialId, input);
    }

    function useStandingZKCredential(
        AVAStandingZKCredentialExtension extension,
        AVAStandingZKCredentialExtension.CredentialUseInput calldata input,
        IZKProofVerifier.SchnorrProof calldata proof
    ) external returns (uint256) {
        return extension.recordCredentialUse(input, proof);
    }
}

contract M14StandingCredentialTest is M14CorePackageFixture {
    M14StandingVm private constant vm = M14StandingVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    bytes32 private constant APP_A = keccak256("m14.standing.app-a");
    bytes32 private constant APP_B = keccak256("m14.standing.app-b");
    bytes32 private constant WORKFLOW = keccak256("m14.standing.workflow");
    bytes32 private constant COMPATIBILITY = keccak256("m14.standing.compatibility");
    bytes32 private constant PACKAGE_ROLE = keccak256("m14.standing.package-role");
    bytes32 private constant SUBJECT_ROLE = keccak256("m14.standing.subject-role");
    bytes32 private constant PANEL_ROLE = keccak256("m14.standing.panel-role");
    bytes32 private constant OBJECT_TYPE = keccak256("m14.standing.object-type");
    bytes32 private constant VECTOR = keccak256("m14.standing.vector");
    bytes32 private constant CATEGORY_A = keccak256("m14.standing.category-a");
    bytes32 private constant CATEGORY_B = keccak256("m14.standing.category-b");
    bytes32 private constant SUBJECT_A = keccak256("m14.standing.subject-a");
    bytes32 private constant SUBJECT_B = keccak256("m14.standing.subject-b");
    bytes32 private constant PANEL_A = keccak256("m14.standing.panel-a");
    bytes32 private constant PANEL_B = keccak256("m14.standing.panel-b");
    bytes32 private constant PACKAGE_SUBJECT_A = keccak256("m14.standing.package-subject-a");
    bytes32 private constant PACKAGE_SUBJECT_B = keccak256("m14.standing.package-subject-b");

    AVAApplicationRegistry private applicationRegistry;
    AVAIdentityRegistry private identityRegistry;
    AVAAuthorityMatrix private authorityMatrix;
    AVACoreRulePackageRegistry private packageRegistry;
    AVADisclosurePolicyRegistry private disclosureRegistry;
    AVAEvidenceRegistry private evidenceRegistry;
    AVAGovernanceKernel private kernel;
    AVAStandingRevisionExtension private revisionRegistry;
    AVAStandingRecordExtension private standingRegistry;
    AVAAllocationRecordExtension private allocationRegistry;
    AVAConsequenceRecordExtension private consequenceRegistry;
    AVAStandingComputationExtension private computationRegistry;
    AVAStandingCredentialExtension private credentialRegistry;
    AVAPrivacyProofExtension private privacyProofRegistry;
    AVADisclosureReceiptExtension private disclosureReceiptRegistry;
    AVAAuditReceiptExtension private auditRegistry;
    AVASettlementReceiptExtension private settlementRegistry;
    AVAExternalOperationExtension private externalOperationRegistry;
    M14StandingHighImpactRequester private highImpactRequester;
    M14AlwaysValidProofVerifier private standingProofVerifier;
    AVAStandingProvenanceExtension private provenanceRegistry;
    AVAStandingZKProofExtension private standingZKProofRegistry;
    AVAStandingZKCredentialExtension private standingZKCredentialRegistry;

    M14StandingActor private subjectActorA;
    M14StandingActor private subjectActorB;
    M14StandingActor private panelActorA;
    M14StandingActor private panelActorB;

    uint256 private packageA;
    uint256 private packageB;
    uint256 private policyA;
    uint256 private policyB;
    uint256 private evidenceA;
    uint256 private evidenceB;
    uint256 private stateA;
    uint256 private stateB;

    function setUp() public {
        applicationRegistry = new AVAApplicationRegistry();
        applicationRegistry.registerApplication(
            APP_A, keccak256("m14-standing-app-a-identity"), keccak256("m14-standing-app-a-authority"), "ipfs://app-a"
        );
        applicationRegistry.registerApplication(
            APP_B, keccak256("m14-standing-app-b-identity"), keccak256("m14-standing-app-b-authority"), "ipfs://app-b"
        );
        identityRegistry = new AVAIdentityRegistry(applicationRegistry);
        authorityMatrix = new AVAAuthorityMatrix(applicationRegistry, identityRegistry);
        identityRegistry.assignSubject(address(this), APP_A, PACKAGE_ROLE, PACKAGE_SUBJECT_A, "ipfs://package-a");
        identityRegistry.assignSubject(address(this), APP_B, PACKAGE_ROLE, PACKAGE_SUBJECT_B, "ipfs://package-b");
        authorityMatrix.setPermission(APP_A, PACKAGE_ROLE, AVACoreTypes.ACTION_REGISTER_RULE_PACKAGE, true);
        authorityMatrix.setPermission(APP_B, PACKAGE_ROLE, AVACoreTypes.ACTION_REGISTER_RULE_PACKAGE, true);
        packageRegistry = new AVACoreRulePackageRegistry(applicationRegistry, authorityMatrix);
        packageA = packageRegistry.registerRulePackage(
            _corePackageInput(APP_A, WORKFLOW, PACKAGE_ROLE, PACKAGE_SUBJECT_A, 1, COMPATIBILITY, "ipfs://package-a"),
            _optionalExtensionBindings(new M14PermissiveApplicationModule(APP_A))
        );
        packageB = packageRegistry.registerRulePackage(
            _corePackageInput(APP_B, WORKFLOW, PACKAGE_ROLE, PACKAGE_SUBJECT_B, 1, COMPATIBILITY, "ipfs://package-b"),
            _coreBindings(new M14PermissiveApplicationModule(APP_B))
        );

        disclosureRegistry = new AVADisclosurePolicyRegistry(applicationRegistry, authorityMatrix);
        evidenceRegistry =
            new AVAEvidenceRegistry(authorityMatrix, identityRegistry, packageRegistry, disclosureRegistry);
        kernel = new AVAGovernanceKernel(
            authorityMatrix,
            identityRegistry,
            packageRegistry,
            evidenceRegistry,
            disclosureRegistry,
            new AVAWorkflowPolicyRouter(packageRegistry, evidenceRegistry, disclosureRegistry)
        );
        highImpactRequester = new M14StandingHighImpactRequester();
        kernel.bindSourceBoundTransitionRequester(packageA, address(highImpactRequester));
        revisionRegistry = new AVAStandingRevisionExtension(kernel);
        standingRegistry = new AVAStandingRecordExtension(
            kernel, authorityMatrix, identityRegistry, packageRegistry, evidenceRegistry, revisionRegistry
        );
        allocationRegistry = new AVAAllocationRecordExtension(
            kernel, authorityMatrix, identityRegistry, packageRegistry, evidenceRegistry
        );
        consequenceRegistry = new AVAConsequenceRecordExtension(
            kernel, authorityMatrix, identityRegistry, packageRegistry, evidenceRegistry
        );
        revisionRegistry.bindRevisionWriter(packageA, address(standingRegistry));
        revisionRegistry.bindRevisionWriter(packageB, address(standingRegistry));
        kernel.bindPostTransitionHook(packageA, address(revisionRegistry));
        kernel.bindPostTransitionHook(packageB, address(revisionRegistry));
        computationRegistry = new AVAStandingComputationExtension(
            kernel, authorityMatrix, identityRegistry, packageRegistry, evidenceRegistry, revisionRegistry
        );
        credentialRegistry = new AVAStandingCredentialExtension(
            authorityMatrix, identityRegistry, packageRegistry, evidenceRegistry, revisionRegistry, computationRegistry
        );
        standingProofVerifier = new M14AlwaysValidProofVerifier();
        provenanceRegistry = new AVAStandingProvenanceExtension(
            kernel,
            authorityMatrix,
            identityRegistry,
            packageRegistry,
            evidenceRegistry,
            disclosureRegistry,
            revisionRegistry
        );
        standingZKProofRegistry = new AVAStandingZKProofExtension(
            authorityMatrix,
            identityRegistry,
            packageRegistry,
            evidenceRegistry,
            revisionRegistry,
            provenanceRegistry,
            standingProofVerifier
        );
        standingZKCredentialRegistry = new AVAStandingZKCredentialExtension(
            authorityMatrix,
            identityRegistry,
            packageRegistry,
            evidenceRegistry,
            revisionRegistry,
            provenanceRegistry,
            standingZKProofRegistry,
            standingProofVerifier
        );
        privacyProofRegistry = new AVAPrivacyProofExtension(
            kernel,
            authorityMatrix,
            identityRegistry,
            packageRegistry,
            evidenceRegistry,
            disclosureRegistry,
            new M14AlwaysValidProofVerifier()
        );
        disclosureReceiptRegistry = new AVADisclosureReceiptExtension(
            kernel,
            authorityMatrix,
            identityRegistry,
            packageRegistry,
            evidenceRegistry,
            disclosureRegistry,
            privacyProofRegistry
        );
        auditRegistry = new AVAAuditReceiptExtension(
            kernel, authorityMatrix, identityRegistry, packageRegistry, evidenceRegistry, disclosureRegistry, address(0)
        );
        settlementRegistry = new AVASettlementReceiptExtension(
            kernel,
            authorityMatrix,
            identityRegistry,
            packageRegistry,
            evidenceRegistry,
            disclosureRegistry,
            IAVADownstreamRecordSource(address(allocationRegistry)),
            IAVADownstreamRecordSource(address(consequenceRegistry))
        );
        externalOperationRegistry = new AVAExternalOperationExtension(
            kernel,
            authorityMatrix,
            identityRegistry,
            packageRegistry,
            evidenceRegistry,
            disclosureRegistry,
            new AVAExternalOperationTargetResolver(
                kernel,
                evidenceRegistry,
                AVAChallengeExtension(address(0)),
                IAVADownstreamRecordSource(address(allocationRegistry)),
                IAVADownstreamRecordSource(address(consequenceRegistry)),
                IAVASettlementReceiptSource(address(settlementRegistry))
            )
        );

        subjectActorA = new M14StandingActor();
        subjectActorB = new M14StandingActor();
        panelActorA = new M14StandingActor();
        panelActorB = new M14StandingActor();
        identityRegistry.assignSubject(address(subjectActorA), APP_A, SUBJECT_ROLE, SUBJECT_A, "ipfs://subject-a");
        identityRegistry.assignSubject(address(subjectActorB), APP_B, SUBJECT_ROLE, SUBJECT_B, "ipfs://subject-b");
        identityRegistry.assignSubject(address(panelActorA), APP_A, PANEL_ROLE, PANEL_A, "ipfs://panel-a");
        identityRegistry.assignSubject(address(panelActorB), APP_B, PANEL_ROLE, PANEL_B, "ipfs://panel-b");
        _grantPermissions(APP_A);
        _grantPermissions(APP_B);

        policyA = panelActorA.registerPolicy(disclosureRegistry, APP_A, PANEL_ROLE, PANEL_A, keccak256("policy-a"));
        policyB = panelActorB.registerPolicy(disclosureRegistry, APP_B, PANEL_ROLE, PANEL_B, keccak256("policy-b"));
        evidenceA = subjectActorA.registerEvidence(
            evidenceRegistry, APP_A, WORKFLOW, packageA, SUBJECT_ROLE, SUBJECT_A, policyA, keccak256("evidence-a")
        );
        evidenceB = subjectActorB.registerEvidence(
            evidenceRegistry, APP_B, WORKFLOW, packageB, SUBJECT_ROLE, SUBJECT_B, policyB, keccak256("evidence-b")
        );
        stateA = _createVestedState(APP_A, packageA, SUBJECT_A, PANEL_A, policyA, evidenceA, subjectActorA, panelActorA);
        stateB = _createVestedState(APP_B, packageB, SUBJECT_B, PANEL_B, policyB, evidenceB, subjectActorB, panelActorB);
    }

    function testM145AuthorisedComputationIssuesPackageBoundThresholdCredential() public {
        uint256 standingBefore = standingRegistry.nextStandingUpdateId();
        uint256 computationId = _recordComputationA(CATEGORY_A, evidenceA);
        uint256 credentialId = _issueA(computationId, block.timestamp + 7 days);

        require(
            credentialRegistry.credentialProves(packageA, credentialId, SUBJECT_A, VECTOR, CATEGORY_A, 50),
            "valid standing proof rejected"
        );
        require(
            !credentialRegistry.credentialProves(packageA, credentialId, SUBJECT_A, VECTOR, CATEGORY_A, 51),
            "credential proved unsupported threshold"
        );
        AVAStandingCredentialExtension.CredentialRecord memory credential =
            credentialRegistry.getCredential(credentialId);
        require(
            credential.packageId == packageA && credential.subjectId == SUBJECT_A
                && credential.computationId == computationId,
            "credential provenance missing"
        );
        require(standingRegistry.nextStandingUpdateId() == standingBefore, "credential created standing update");
    }

    function testPerformanceSharedExtensionValidationRevalidatesPackageIdentityOnce() public {
        M14ExtensionValidationHarness harness = new M14ExtensionValidationHarness(
            kernel, authorityMatrix, identityRegistry, packageRegistry, evidenceRegistry, disclosureRegistry
        );
        authorityMatrix.setPermission(APP_A, PACKAGE_ROLE, AVACoreTypes.ACTION_RECORD_AUDIT_RECEIPT, true);
        address applicationModule = packageRegistry.getModule(packageA, AVACapabilityKeys.APPLICATION);
        vm.expectCall(applicationModule, abi.encodeCall(RuleModuleIdentity.moduleIdentityHash, ()), 1);
        harness.validate(
            AVAExtensionRecordBase.ExtensionValidationInput({
                recognisedStateId: stateA,
                roleKey: PACKAGE_ROLE,
                authorityId: PACKAGE_SUBJECT_A,
                subjectId: SUBJECT_A,
                evidenceId: evidenceA,
                capabilityKey: AVACapabilityKeys.AUDIT_RECEIPT,
                actionKey: AVACoreTypes.ACTION_RECORD_AUDIT_RECEIPT,
                recordTypeKey: keccak256("performance-extension-record"),
                scopeKey: bytes32(0),
                sourceTypeKey: bytes32(0),
                sourceRecordId: 0,
                unsignedValue: 0,
                validUntil: 0,
                payloadHash: bytes32(0),
                requireActiveSubject: true,
                contextHash: keccak256("performance-extension-context")
            })
        );
    }

    function testPerformancePrivacyProofReusesLoadedRecognisedState() public {
        bytes32 proofScope = keccak256("performance-loaded-state-proof");
        vm.expectCall(address(kernel), abi.encodeCall(AVAGovernanceKernel.getRecognisedStateReference, (stateA)), 1);
        panelActorA.registerPrivacyProof(
            privacyProofRegistry, _proofInput(stateA, SUBJECT_A, PANEL_A, evidenceA, proofScope)
        );
    }

    function testPerformanceDisclosureReceiptReusesLoadedRecognisedState() public {
        vm.expectCall(address(kernel), abi.encodeCall(AVAGovernanceKernel.getRecognisedStateReference, (stateA)), 1);
        panelActorA.recordDisclosure(
            disclosureReceiptRegistry,
            AVADisclosureReceiptExtension.DisclosureInput({
                recognisedStateId: stateA,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: evidenceA,
                kind: AVADisclosureReceiptExtension.DisclosureReceiptKind.AccessGrant,
                scopeKey: keccak256("performance-loaded-state-disclosure"),
                proofReceiptId: 0,
                relatedReceiptId: 0,
                expiresAt: uint64(block.timestamp + 1 days),
                reasonHash: keccak256("performance-loaded-state-disclosure"),
                uri: "ipfs://performance-loaded-state-disclosure"
            })
        );
    }

    function testPerformanceStandingComputationRevalidatesPackageIdentityOnce() public {
        address applicationModule = packageRegistry.getModule(packageA, AVACapabilityKeys.APPLICATION);
        vm.expectCall(applicationModule, abi.encodeCall(RuleModuleIdentity.moduleIdentityHash, ()), 1);
        _recordComputationA(CATEGORY_A, evidenceA);
    }

    function testPerformanceStandingCredentialUsesOneSourceAndOnePolicyPackageValidation() public {
        uint256 computationId = _recordComputationA(CATEGORY_A, evidenceA);
        address applicationModule = packageRegistry.getModule(packageA, AVACapabilityKeys.APPLICATION);
        vm.expectCall(applicationModule, abi.encodeCall(RuleModuleIdentity.moduleIdentityHash, ()), 2);
        _issueA(computationId, block.timestamp + 7 days);
    }

    function testStandingCredentialValidityIsBounded() public {
        uint256 computationId = _recordComputationA(CATEGORY_A, evidenceA);
        AVAStandingCredentialExtension.CredentialInput memory input =
            _credentialInput(computationId, PANEL_A, block.timestamp + 365 days + 1);
        try panelActorA.issueCredential(credentialRegistry, input) {
            revert("overlong standing credential was issued");
        } catch {}
    }

    function testPerformanceStandingZKProofUsesOneSourceAndOnePolicyPackageValidation() public {
        (uint256 statementId,, IZKProofVerifier.SchnorrProof memory proof) =
            _recordStandingProvenanceStatement(evidenceA);
        address applicationModule = packageRegistry.getModule(packageA, AVACapabilityKeys.APPLICATION);
        vm.expectCall(applicationModule, abi.encodeCall(RuleModuleIdentity.moduleIdentityHash, ()), 2);
        panelActorA.registerStandingZKProof(
            standingZKProofRegistry,
            AVAStandingZKProofExtension.ProofInput({
                statementId: statementId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                proof: proof,
                uri: "ipfs://performance-single-package-standing-zk-proof"
            })
        );
    }

    function testStandingZKProofContextIsBoundToRegistryDeployment() public {
        (uint256 statementId,, IZKProofVerifier.SchnorrProof memory proof) =
            _recordStandingProvenanceStatement(evidenceA);
        AVAStandingZKProofExtension secondRegistry = new AVAStandingZKProofExtension(
            authorityMatrix,
            identityRegistry,
            packageRegistry,
            evidenceRegistry,
            revisionRegistry,
            provenanceRegistry,
            standingProofVerifier
        );
        AVAStandingZKProofExtension.ProofInput memory input = AVAStandingZKProofExtension.ProofInput({
            statementId: statementId,
            roleKey: PANEL_ROLE,
            authorityId: PANEL_A,
            proof: proof,
            uri: "ipfs://deployment-bound-standing-proof"
        });
        uint256 firstId = panelActorA.registerStandingZKProof(standingZKProofRegistry, input);
        uint256 secondId = panelActorA.registerStandingZKProof(secondRegistry, input);

        require(
            standingZKProofRegistry.getProofReceipt(firstId).contextHash
                != secondRegistry.getProofReceipt(secondId).contextHash,
            "standing proof context crossed registry deployment"
        );
    }

    function testStandingZKCredentialValidityIsBounded() public {
        (uint256 statementId,, IZKProofVerifier.SchnorrProof memory proof) =
            _recordStandingProvenanceStatement(evidenceA);
        uint256 proofReceiptId = panelActorA.registerStandingZKProof(
            standingZKProofRegistry,
            AVAStandingZKProofExtension.ProofInput({
                statementId: statementId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                proof: proof,
                uri: "ipfs://bounded-standing-zk-proof"
            })
        );
        AVAStandingZKCredentialExtension.CredentialInput memory input = AVAStandingZKCredentialExtension.CredentialInput({
            proofReceiptId: proofReceiptId,
            roleKey: PANEL_ROLE,
            authorityId: PANEL_A,
            credentialCommitment: keccak256("overlong-standing-zk-credential"),
            expiresAt: uint64(block.timestamp + 365 days + 1),
            uri: "ipfs://overlong-standing-zk-credential"
        });
        try panelActorA.issueStandingZKCredential(standingZKCredentialRegistry, input) {
            revert("overlong standing ZK credential was issued");
        } catch {}
    }

    function testPerformanceStandingZKCredentialUsesSourceChecksAndOnePolicyPackageValidation() public {
        (uint256 statementId,, IZKProofVerifier.SchnorrProof memory proof) =
            _recordStandingProvenanceStatement(evidenceA);
        uint256 proofReceiptId = panelActorA.registerStandingZKProof(
            standingZKProofRegistry,
            AVAStandingZKProofExtension.ProofInput({
                statementId: statementId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                proof: proof,
                uri: "ipfs://performance-standing-zk-credential-proof"
            })
        );
        address applicationModule = packageRegistry.getModule(packageA, AVACapabilityKeys.APPLICATION);
        vm.expectCall(applicationModule, abi.encodeCall(RuleModuleIdentity.moduleIdentityHash, ()), 3);
        panelActorA.issueStandingZKCredential(
            standingZKCredentialRegistry,
            AVAStandingZKCredentialExtension.CredentialInput({
                proofReceiptId: proofReceiptId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                credentialCommitment: keccak256("performance-standing-zk-credential"),
                expiresAt: uint64(block.timestamp + 7 days),
                uri: "ipfs://performance-standing-zk-credential"
            })
        );
    }

    function testPerformanceStandingFormulaRevalidatesPackageIdentityOnce() public {
        address applicationModule = packageRegistry.getModule(packageA, AVACapabilityKeys.APPLICATION);
        vm.expectCall(applicationModule, abi.encodeCall(RuleModuleIdentity.moduleIdentityHash, ()), 1);
        panelActorA.registerStandingFormula(
            provenanceRegistry,
            AVAStandingProvenanceExtension.FormulaInput({
                appId: APP_A,
                workflowKey: WORKFLOW,
                packageId: packageA,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                vectorKey: VECTOR,
                formulaVersion: 1,
                computationRuleHash: keccak256("performance-standing-formula-rule"),
                sourceSetPolicyHash: keccak256("performance-standing-formula-source-policy"),
                decayPolicyHash: keccak256("performance-standing-formula-decay-policy"),
                capPolicyHash: keccak256("performance-standing-formula-cap-policy"),
                restorationPolicyHash: keccak256("performance-standing-formula-restoration-policy"),
                verifier: address(standingProofVerifier),
                proofDomainHash: standingProofVerifier.proofDomain(),
                uri: "ipfs://performance-standing-formula"
            })
        );
    }

    function testPerformanceAuditReceiptRevalidatesPackageIdentityOnce() public {
        address applicationModule = packageRegistry.getModule(packageA, AVACapabilityKeys.APPLICATION);
        vm.expectCall(applicationModule, abi.encodeCall(RuleModuleIdentity.moduleIdentityHash, ()), 1);
        panelActorA.recordAudit(
            auditRegistry,
            AVAAuditReceiptExtension.AuditInput({
                targetKind: AVAAuditReceiptExtension.AuditTargetKind.RecognisedState,
                targetId: stateA,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: evidenceA,
                auditTypeKey: keccak256("performance-single-package-audit"),
                attestationHash: keccak256("performance-single-package-audit-attestation"),
                reasonHash: keccak256("performance-single-package-audit-reason"),
                uri: "ipfs://performance-single-package-audit"
            })
        );
    }

    function testPerformanceExternalOperationRevalidatesPackageIdentityOnce() public {
        address applicationModule = packageRegistry.getModule(packageA, AVACapabilityKeys.APPLICATION);
        vm.expectCall(applicationModule, abi.encodeCall(RuleModuleIdentity.moduleIdentityHash, ()), 1);
        panelActorA.requestTargetOperation(
            externalOperationRegistry,
            AVAExternalOperationExtension.TargetOperationInput({
                targetKind: AVAExternalOperationTargetKind.RecognisedState,
                targetId: stateA,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                operationKey: keccak256("performance-external-operation"),
                payloadHash: keccak256("performance-external-operation-payload"),
                uri: "ipfs://performance-external-operation"
            })
        );
    }

    function testM145CredentialCannotCrossApplicationOrPackageContext() public {
        uint256 computationId = _recordComputationA(CATEGORY_A, evidenceA);
        uint256 credentialId = _issueA(computationId, block.timestamp + 7 days);
        require(
            !credentialRegistry.credentialProves(packageB, credentialId, SUBJECT_A, VECTOR, CATEGORY_A, 50),
            "credential crossed package"
        );
        require(
            !credentialRegistry.credentialProves(packageA, credentialId, SUBJECT_B, VECTOR, CATEGORY_A, 50),
            "credential crossed subject"
        );

        AVAStandingComputationExtension.ComputationInput memory wrongEvidence =
            _computationInput(stateA, SUBJECT_A, PANEL_A, evidenceB, CATEGORY_A);
        try panelActorA.recordComputation(computationRegistry, wrongEvidence) {
            revert("cross-app evidence accepted");
        } catch {}
    }

    function testM147PackageSupersessionDoesNotRewriteHistoricalCredentialOrProofContext() public {
        uint256 computationId = _recordComputationA(CATEGORY_A, evidenceA);
        uint256 credentialId = _issueA(computationId, block.timestamp + 7 days);
        bytes32 scopeKey = keccak256("m147-historical-proof-scope");
        uint256 proofReceiptId = panelActorA.registerPrivacyProof(
            privacyProofRegistry, _proofInput(stateA, SUBJECT_A, PANEL_A, evidenceA, scopeKey)
        );

        uint256 replacementPackageId = packageRegistry.supersedeRulePackage(
            _corePackageInput(
                APP_A, WORKFLOW, PACKAGE_ROLE, PACKAGE_SUBJECT_A, 2, COMPATIBILITY, "ipfs://m147-package-a-v2"
            ),
            packageA,
            _optionalExtensionBindings(new M14PermissiveApplicationModule(APP_A))
        );

        require(credentialRegistry.isCredentialActive(credentialId), "historical credential became inactive");
        require(
            credentialRegistry.credentialProves(packageA, credentialId, SUBJECT_A, VECTOR, CATEGORY_A, 50),
            "historical package credential stopped proving"
        );
        require(
            !credentialRegistry.credentialProves(replacementPackageId, credentialId, SUBJECT_A, VECTOR, CATEGORY_A, 50),
            "historical credential moved to replacement package"
        );
        require(privacyProofRegistry.isProofUsable(proofReceiptId), "historical proof became unusable");
        require(
            privacyProofRegistry.proofMatches(proofReceiptId, packageA, stateA, SUBJECT_A, evidenceA, scopeKey),
            "historical package proof stopped matching"
        );
        require(
            !privacyProofRegistry.proofMatches(
                proofReceiptId, replacementPackageId, stateA, SUBJECT_A, evidenceA, scopeKey
            ),
            "historical proof moved to replacement package"
        );
    }

    function testM145UnknownOrInactiveSubjectCannotBackCredential() public {
        AVAStandingComputationExtension.ComputationInput memory unknownSubject =
            _computationInput(stateA, keccak256("unknown-subject"), PANEL_A, evidenceA, CATEGORY_A);
        try panelActorA.recordComputation(computationRegistry, unknownSubject) {
            revert("unknown subject computation accepted");
        } catch {}

        uint256 computationId = _recordComputationA(CATEGORY_A, evidenceA);
        identityRegistry.deactivateSubject(SUBJECT_A);
        try panelActorA.issueCredential(
            credentialRegistry, _credentialInput(computationId, PANEL_A, block.timestamp + 7 days)
        ) {
            revert("inactive subject credential issued");
        } catch {}
    }

    function testM145RawOrUnknownReferencesCannotFormStandingComputation() public {
        AVAStandingComputationExtension.ComputationInput memory rawReference =
            _computationInput(type(uint128).max, SUBJECT_A, PANEL_A, evidenceA, CATEGORY_A);
        try panelActorA.recordComputation(computationRegistry, rawReference) {
            revert("raw reference accepted as recognised state");
        } catch {}
        rawReference = _computationInput(stateA, SUBJECT_A, PANEL_A, type(uint128).max, CATEGORY_A);
        try panelActorA.recordComputation(computationRegistry, rawReference) {
            revert("raw reference accepted as evidence");
        } catch {}
    }

    function testM145ExpiredRevokedAndSupersededCredentialsCannotProve() public {
        uint256 computationId = _recordComputationA(CATEGORY_A, evidenceA);
        uint256 expiringCredentialId = _issueA(computationId, block.timestamp + 1);
        vm.warp(block.timestamp + 2);
        require(!credentialRegistry.isCredentialActive(expiringCredentialId), "expired credential remained active");

        uint256 replacementComputationId = _recordComputationA(CATEGORY_A, evidenceA);
        uint256 revokedCredentialId = panelActorA.supersedeCredential(
            credentialRegistry,
            expiringCredentialId,
            _credentialInput(replacementComputationId, PANEL_A, block.timestamp + 7 days)
        );
        panelActorA.revokeCredential(credentialRegistry, revokedCredentialId, PANEL_ROLE, PANEL_A);
        require(!credentialRegistry.isCredentialActive(revokedCredentialId), "revoked credential remained active");

        try panelActorA.supersedeCredential(
            credentialRegistry,
            revokedCredentialId,
            _credentialInput(replacementComputationId, PANEL_A, block.timestamp + 7 days)
        ) {
            revert("revoked credential was superseded");
        } catch {}
        uint256 activeCredentialId = _issueA(replacementComputationId, block.timestamp + 7 days);
        uint256 latestComputationId = _recordComputationA(CATEGORY_A, evidenceA);
        uint256 latestCredentialId = panelActorA.supersedeCredential(
            credentialRegistry,
            activeCredentialId,
            _credentialInput(latestComputationId, PANEL_A, block.timestamp + 7 days)
        );
        require(!credentialRegistry.isCredentialActive(activeCredentialId), "superseded credential reactivated");
        require(credentialRegistry.isCredentialActive(latestCredentialId), "replacement credential inactive");
    }

    function testM145StandingRevisionInvalidatesComputationAndCredential() public {
        uint256 computationId = _recordComputationA(CATEGORY_A, evidenceA);
        uint256 credentialId = _issueA(computationId, block.timestamp + 7 days);
        uint256 revisionBefore = revisionRegistry.currentRevision(packageA, SUBJECT_A);
        panelActorA.recordStanding(
            standingRegistry,
            AVAStandingRecordExtension.StandingInput({
                recognisedStateId: stateA,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: evidenceA,
                dimensionKey: VECTOR,
                delta: 1,
                reasonHash: keccak256("m14-standing-update"),
                uri: "ipfs://m14-standing-update"
            })
        );
        require(
            revisionRegistry.currentRevision(packageA, SUBJECT_A) == revisionBefore + 1,
            "standing revision not advanced"
        );
        require(!computationRegistry.isComputationCurrent(computationId), "stale computation remained current");
        require(!credentialRegistry.isCredentialActive(credentialId), "stale credential remained active");
        try panelActorA.issueCredential(
            credentialRegistry, _credentialInput(computationId, PANEL_A, block.timestamp + 7 days)
        ) {
            revert("stale computation issued credential");
        } catch {}
    }

    function testM145DuplicateStandingInputForSameStateVersionAndDimensionIsRejected() public {
        AVAStandingRecordExtension.StandingInput memory input = AVAStandingRecordExtension.StandingInput({
            recognisedStateId: stateA,
            roleKey: PANEL_ROLE,
            authorityId: PANEL_A,
            subjectId: SUBJECT_A,
            evidenceId: evidenceA,
            dimensionKey: VECTOR,
            delta: 1,
            reasonHash: keccak256("m14-standing-duplicate"),
            uri: "ipfs://m14-standing-duplicate"
        });
        panelActorA.recordStanding(standingRegistry, input);
        uint256 revisionAfterFirstRecord = revisionRegistry.currentRevision(packageA, SUBJECT_A);
        try panelActorA.recordStanding(standingRegistry, input) {
            revert("duplicate standing input accepted");
        } catch {}
        require(
            revisionRegistry.currentRevision(packageA, SUBJECT_A) == revisionAfterFirstRecord,
            "duplicate standing input advanced revision"
        );
    }

    function testM145EvidenceRevocationInvalidatesCredential() public {
        uint256 computationId = _recordComputationA(CATEGORY_A, evidenceA);
        uint256 credentialId = _issueA(computationId, block.timestamp + 7 days);
        panelActorA.recordEvidenceLifecycle(
            evidenceRegistry, evidenceA, PANEL_ROLE, PANEL_A, AVACoreTypes.EvidenceLifecycleKind.Revoke
        );
        require(!computationRegistry.isComputationCurrent(computationId), "revoked evidence left computation current");
        require(!credentialRegistry.isCredentialActive(credentialId), "revoked evidence left credential active");
    }

    function testM145AlternateEvidenceCannotBypassPinnedStateEvidenceLifecycle() public {
        uint256 alternateEvidenceId = subjectActorA.registerEvidence(
            evidenceRegistry,
            APP_A,
            WORKFLOW,
            packageA,
            SUBJECT_ROLE,
            SUBJECT_A,
            policyA,
            keccak256("alternate-standing-evidence")
        );
        uint256 computationId = _recordComputationA(CATEGORY_A, alternateEvidenceId);
        uint256 credentialId = _issueA(computationId, block.timestamp + 7 days);
        panelActorA.recordEvidenceLifecycle(
            evidenceRegistry, evidenceA, PANEL_ROLE, PANEL_A, AVACoreTypes.EvidenceLifecycleKind.Revoke
        );

        require(
            !computationRegistry.isComputationCurrent(computationId),
            "alternate evidence bypassed pinned state evidence lifecycle"
        );
        require(
            !credentialRegistry.isCredentialActive(credentialId), "credential ignored pinned state evidence lifecycle"
        );
        try panelActorA.recordStanding(
            standingRegistry,
            AVAStandingRecordExtension.StandingInput({
                recognisedStateId: stateA,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: alternateEvidenceId,
                dimensionKey: VECTOR,
                delta: 1,
                reasonHash: keccak256("alternate-evidence-standing-update"),
                uri: "ipfs://alternate-evidence-standing-update"
            })
        ) {
            revert("alternate evidence bypassed pinned state evidence for downstream record");
        } catch {}
        try panelActorA.recordAllocation(
            allocationRegistry,
            AVAAllocationRecordExtension.AllocationInput({
                recognisedStateId: stateA,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: alternateEvidenceId,
                allocationKindKey: keccak256("alternate-evidence-allocation"),
                units: 1,
                reasonHash: keccak256("alternate-evidence-allocation"),
                uri: "ipfs://alternate-evidence-allocation"
            })
        ) {
            revert("alternate evidence bypassed pinned state evidence for allocation");
        } catch {}
        try panelActorA.recordConsequence(
            consequenceRegistry,
            AVAConsequenceRecordExtension.ConsequenceInput({
                recognisedStateId: stateA,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: alternateEvidenceId,
                consequenceKindKey: keccak256("alternate-evidence-consequence"),
                reasonHash: keccak256("alternate-evidence-consequence"),
                uri: "ipfs://alternate-evidence-consequence"
            })
        ) {
            revert("alternate evidence bypassed pinned state evidence for consequence");
        } catch {}
    }

    function testM145StateDerivedRecordsRejectEvidenceFromDifferentDisclosurePolicy() public {
        uint256 mismatchedEvidenceId = _registerMismatchedPolicyEvidenceA("downstream");

        try panelActorA.recordStanding(
            standingRegistry,
            AVAStandingRecordExtension.StandingInput({
                recognisedStateId: stateA,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: mismatchedEvidenceId,
                dimensionKey: VECTOR,
                delta: 1,
                reasonHash: keccak256("mismatched-policy-standing"),
                uri: "ipfs://mismatched-policy-standing"
            })
        ) {
            revert("standing accepted evidence under another disclosure policy");
        } catch {}
        try panelActorA.recordAllocation(
            allocationRegistry,
            AVAAllocationRecordExtension.AllocationInput({
                recognisedStateId: stateA,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: mismatchedEvidenceId,
                allocationKindKey: keccak256("mismatched-policy-allocation"),
                units: 1,
                reasonHash: keccak256("mismatched-policy-allocation"),
                uri: "ipfs://mismatched-policy-allocation"
            })
        ) {
            revert("allocation accepted evidence under another disclosure policy");
        } catch {}
        try panelActorA.recordConsequence(
            consequenceRegistry,
            AVAConsequenceRecordExtension.ConsequenceInput({
                recognisedStateId: stateA,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: mismatchedEvidenceId,
                consequenceKindKey: keccak256("mismatched-policy-consequence"),
                reasonHash: keccak256("mismatched-policy-consequence"),
                uri: "ipfs://mismatched-policy-consequence"
            })
        ) {
            revert("consequence accepted evidence under another disclosure policy");
        } catch {}
    }

    function testM145StandingComputationRejectsEvidenceFromDifferentDisclosurePolicy() public {
        uint256 mismatchedEvidenceId = _registerMismatchedPolicyEvidenceA("computation");

        try panelActorA.recordComputation(
            computationRegistry, _computationInput(stateA, SUBJECT_A, PANEL_A, mismatchedEvidenceId, CATEGORY_A)
        ) {
            revert("standing computation accepted evidence under another disclosure policy");
        } catch {}
    }

    function testM145PrivacyProofRejectsEvidenceFromDifferentDisclosurePolicy() public {
        uint256 mismatchedEvidenceId = _registerMismatchedPolicyEvidenceA("privacy-proof");

        try panelActorA.registerPrivacyProof(
            privacyProofRegistry,
            _proofInput(stateA, SUBJECT_A, PANEL_A, mismatchedEvidenceId, keccak256("mismatched-policy-proof"))
        ) {
            revert("privacy proof accepted evidence under another disclosure policy");
        } catch {}
    }

    function testM145SupersessionCannotOverwriteAnotherActiveCredentialKey() public {
        uint256 categoryAComputation = _recordComputationA(CATEGORY_A, evidenceA);
        uint256 categoryACredential = _issueA(categoryAComputation, block.timestamp + 7 days);
        uint256 categoryBComputation = _recordComputationA(CATEGORY_B, evidenceA);
        uint256 categoryBCredential = _issueA(categoryBComputation, block.timestamp + 7 days);

        try panelActorA.supersedeCredential(
            credentialRegistry,
            categoryACredential,
            _credentialInput(categoryBComputation, PANEL_A, block.timestamp + 7 days)
        ) {
            revert("supersession overwrote another active credential key");
        } catch {}
        require(credentialRegistry.isCredentialActive(categoryBCredential), "existing active credential displaced");
    }

    function testM145CredentialExposesNoTransferRewardPriorityOrPublicationWrites() public {
        uint256 computationId = _recordComputationA(CATEGORY_A, evidenceA);
        uint256 credentialId = _issueA(computationId, block.timestamp + 7 days);
        (bool transferSuccess,) = address(credentialRegistry)
            .call(
                abi.encodeWithSignature(
                    "transferFrom(address,address,uint256)", address(this), address(1), credentialId
                )
            );
        (bool approveSuccess,) = address(credentialRegistry)
            .call(abi.encodeWithSignature("approve(address,uint256)", address(1), credentialId));
        (bool rewardSuccess,) =
            address(credentialRegistry).call(abi.encodeWithSignature("mintReward(bytes32,uint256)", SUBJECT_A, 1));
        (bool prioritySuccess,) = address(credentialRegistry)
            .call(abi.encodeWithSignature("mintPriorityToken(bytes32,uint256)", SUBJECT_A, 1));
        (bool publicationSuccess,) =
            address(credentialRegistry).call(abi.encodeWithSignature("acceptManuscript(uint256)", 1));
        require(
            !transferSuccess && !approveSuccess && !rewardSuccess && !prioritySuccess && !publicationSuccess,
            "credential exposed forbidden write surface"
        );
    }

    function testM145SecondApplicationUsesSameStandingExtensionsWithoutCoreChange() public {
        uint256 computationId = panelActorB.recordComputation(
            computationRegistry, _computationInput(stateB, SUBJECT_B, PANEL_B, evidenceB, CATEGORY_B)
        );
        uint256 credentialId = panelActorB.issueCredential(
            credentialRegistry, _credentialInput(computationId, PANEL_B, block.timestamp + 7 days)
        );
        require(
            credentialRegistry.credentialProves(packageB, credentialId, SUBJECT_B, VECTOR, CATEGORY_B, 50),
            "second app credential proof failed"
        );
    }

    function testM145PrivacyProofAndAnonymousUseAreContextBoundAndReplaySafe() public {
        bytes32 scopeKey = keccak256("m14-anonymous-proof-use");
        uint256 proofReceiptId = panelActorA.registerPrivacyProof(
            privacyProofRegistry, _proofInput(stateA, SUBJECT_A, PANEL_A, evidenceA, scopeKey)
        );
        require(
            privacyProofRegistry.proofMatches(proofReceiptId, packageA, stateA, SUBJECT_A, evidenceA, scopeKey),
            "valid proof receipt did not match"
        );
        require(
            !privacyProofRegistry.proofMatches(proofReceiptId, packageB, stateA, SUBJECT_A, evidenceA, scopeKey),
            "proof crossed package"
        );
        try panelActorA.registerPrivacyProof(
            privacyProofRegistry, _proofInput(stateA, SUBJECT_A, PANEL_A, evidenceA, scopeKey)
        ) {
            revert("duplicate proof context accepted");
        } catch {}

        uint256 useReceiptId = panelActorA.recordDisclosure(
            disclosureReceiptRegistry,
            AVADisclosureReceiptExtension.DisclosureInput({
                recognisedStateId: stateA,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: evidenceA,
                kind: AVADisclosureReceiptExtension.DisclosureReceiptKind.AnonymousProofUse,
                scopeKey: scopeKey,
                proofReceiptId: proofReceiptId,
                relatedReceiptId: 0,
                expiresAt: 0,
                reasonHash: keccak256("m14-anonymous-proof-use"),
                uri: "ipfs://m14-anonymous-proof-use"
            })
        );
        require(
            disclosureReceiptRegistry.getDisclosureReceipt(useReceiptId).proofReceiptId == proofReceiptId,
            "proof use provenance missing"
        );
        try panelActorA.recordDisclosure(
            disclosureReceiptRegistry,
            AVADisclosureReceiptExtension.DisclosureInput({
                recognisedStateId: stateA,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: evidenceA,
                kind: AVADisclosureReceiptExtension.DisclosureReceiptKind.AnonymousProofUse,
                scopeKey: scopeKey,
                proofReceiptId: proofReceiptId,
                relatedReceiptId: 0,
                expiresAt: 0,
                reasonHash: keccak256("m14-anonymous-proof-replay"),
                uri: "ipfs://m14-anonymous-proof-replay"
            })
        ) {
            revert("proof use replay accepted");
        } catch {}
    }

    function testM145OptionalCapabilityAbsenceFailsClosedForSecondApplication() public {
        uint256 nextProofReceiptIdBefore = privacyProofRegistry.nextProofReceiptId();
        try panelActorB.registerPrivacyProof(
            privacyProofRegistry, _proofInput(stateB, SUBJECT_B, PANEL_B, evidenceB, keccak256("m14-app-b-proof"))
        ) {
            revert("package without privacy capability accepted proof");
        } catch {}
        require(
            privacyProofRegistry.nextProofReceiptId() == nextProofReceiptIdBefore,
            "missing capability wrote proof receipt"
        );
    }

    function testM145DisclosureGrantRevocationIsExplicitAndRecordOnly() public {
        bytes32 scopeKey = keccak256("m14-panel-visible-scope");
        uint256 grantId = panelActorA.recordDisclosure(
            disclosureReceiptRegistry,
            AVADisclosureReceiptExtension.DisclosureInput({
                recognisedStateId: stateA,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: evidenceA,
                kind: AVADisclosureReceiptExtension.DisclosureReceiptKind.AccessGrant,
                scopeKey: scopeKey,
                proofReceiptId: 0,
                relatedReceiptId: 0,
                expiresAt: uint64(block.timestamp + 7 days),
                reasonHash: keccak256("m14-access-grant"),
                uri: "ipfs://m14-access-grant"
            })
        );
        require(disclosureReceiptRegistry.isAccessGrantActive(grantId), "new grant inactive");
        uint256 revokeId = panelActorA.recordDisclosure(
            disclosureReceiptRegistry,
            AVADisclosureReceiptExtension.DisclosureInput({
                recognisedStateId: stateA,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: evidenceA,
                kind: AVADisclosureReceiptExtension.DisclosureReceiptKind.AccessRevoke,
                scopeKey: scopeKey,
                proofReceiptId: 0,
                relatedReceiptId: grantId,
                expiresAt: 0,
                reasonHash: keccak256("m14-access-revoke"),
                uri: "ipfs://m14-access-revoke"
            })
        );
        require(!disclosureReceiptRegistry.isAccessGrantActive(grantId), "revoked grant remained active");
        require(
            disclosureReceiptRegistry.getDisclosureReceipt(grantId).closedByReceiptId == revokeId,
            "grant closure lineage missing"
        );
    }

    function testParityDisclosureGrantSeparatesProtectedSubjectFromAccessRecipient() public {
        bytes32 scopeKey = keccak256("m14-panel-recipient-scope");
        uint256 grantId = panelActorA.recordDisclosure(
            disclosureReceiptRegistry,
            AVADisclosureReceiptExtension.DisclosureInput({
                recognisedStateId: stateA,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: PANEL_A,
                evidenceId: evidenceA,
                kind: AVADisclosureReceiptExtension.DisclosureReceiptKind.AccessGrant,
                scopeKey: scopeKey,
                proofReceiptId: 0,
                relatedReceiptId: 0,
                expiresAt: uint64(block.timestamp + 7 days),
                reasonHash: keccak256("m14-panel-recipient-grant"),
                uri: "ipfs://m14-panel-recipient-grant"
            })
        );
        AVADisclosureReceiptExtension.DisclosureReceipt memory grant =
            disclosureReceiptRegistry.getDisclosureReceipt(grantId);
        require(grant.subjectId == PANEL_A, "access recipient missing");
        require(grant.targetSubjectId == SUBJECT_A, "protected subject missing");
        require(disclosureReceiptRegistry.isAccessGrantActive(grantId), "recipient-bound grant inactive");

        bool crossAppAccepted;
        try panelActorA.recordDisclosure(
            disclosureReceiptRegistry,
            AVADisclosureReceiptExtension.DisclosureInput({
                recognisedStateId: stateA,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: PANEL_B,
                evidenceId: evidenceA,
                kind: AVADisclosureReceiptExtension.DisclosureReceiptKind.AccessGrant,
                scopeKey: keccak256("m14-cross-app-recipient-scope"),
                proofReceiptId: 0,
                relatedReceiptId: 0,
                expiresAt: uint64(block.timestamp + 7 days),
                reasonHash: keccak256("m14-cross-app-recipient-grant"),
                uri: "ipfs://m14-cross-app-recipient-grant"
            })
        ) returns (
            uint256
        ) {
            crossAppAccepted = true;
        } catch {}
        require(!crossAppAccepted, "cross-application access recipient accepted");
    }

    function testParityDisclosureExpiryAndSupersessionAreExplicitClosureReceipts() public {
        bytes32 expiryScope = keccak256("m14-explicit-expiry-scope");
        uint256 expiringGrantId = panelActorA.recordDisclosure(
            disclosureReceiptRegistry,
            AVADisclosureReceiptExtension.DisclosureInput({
                recognisedStateId: stateA,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: PANEL_A,
                evidenceId: evidenceA,
                kind: AVADisclosureReceiptExtension.DisclosureReceiptKind.AccessGrant,
                scopeKey: expiryScope,
                proofReceiptId: 0,
                relatedReceiptId: 0,
                expiresAt: uint64(block.timestamp + 1),
                reasonHash: keccak256("m14-expiring-grant"),
                uri: "ipfs://m14-expiring-grant"
            })
        );
        vm.warp(block.timestamp + 2);
        uint256 expiryId = panelActorA.recordDisclosure(
            disclosureReceiptRegistry,
            AVADisclosureReceiptExtension.DisclosureInput({
                recognisedStateId: stateA,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: PANEL_A,
                evidenceId: evidenceA,
                kind: AVADisclosureReceiptExtension.DisclosureReceiptKind.AccessExpire,
                scopeKey: expiryScope,
                proofReceiptId: 0,
                relatedReceiptId: expiringGrantId,
                expiresAt: 0,
                reasonHash: keccak256("m14-explicit-expiry"),
                uri: "ipfs://m14-explicit-expiry"
            })
        );
        require(
            disclosureReceiptRegistry.getDisclosureReceipt(expiringGrantId).closedByReceiptId == expiryId,
            "expiry closure lineage missing"
        );

        bytes32 supersedeScope = keccak256("m14-explicit-supersede-scope");
        uint256 supersededGrantId = panelActorA.recordDisclosure(
            disclosureReceiptRegistry,
            AVADisclosureReceiptExtension.DisclosureInput({
                recognisedStateId: stateA,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: PANEL_A,
                evidenceId: evidenceA,
                kind: AVADisclosureReceiptExtension.DisclosureReceiptKind.AccessGrant,
                scopeKey: supersedeScope,
                proofReceiptId: 0,
                relatedReceiptId: 0,
                expiresAt: uint64(block.timestamp + 7 days),
                reasonHash: keccak256("m14-superseded-grant"),
                uri: "ipfs://m14-superseded-grant"
            })
        );
        uint256 supersessionId = panelActorA.recordDisclosure(
            disclosureReceiptRegistry,
            AVADisclosureReceiptExtension.DisclosureInput({
                recognisedStateId: stateA,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: PANEL_A,
                evidenceId: evidenceA,
                kind: AVADisclosureReceiptExtension.DisclosureReceiptKind.AccessSupersede,
                scopeKey: supersedeScope,
                proofReceiptId: 0,
                relatedReceiptId: supersededGrantId,
                expiresAt: 0,
                reasonHash: keccak256("m14-explicit-supersession"),
                uri: "ipfs://m14-explicit-supersession"
            })
        );
        require(
            disclosureReceiptRegistry.getDisclosureReceipt(supersededGrantId).closedByReceiptId == supersessionId,
            "supersession closure lineage missing"
        );
        require(!disclosureReceiptRegistry.isAccessGrantActive(supersededGrantId), "superseded grant active");
    }

    function testM145VoluntaryDisclosureIntentRequiresResponsibleSubjectSelfClaim() public {
        AVADisclosureReceiptExtension.DisclosureInput memory input = AVADisclosureReceiptExtension.DisclosureInput({
            recognisedStateId: stateA,
            roleKey: PANEL_ROLE,
            authorityId: PANEL_A,
            subjectId: SUBJECT_A,
            evidenceId: evidenceA,
            kind: AVADisclosureReceiptExtension.DisclosureReceiptKind.VoluntaryIntent,
            scopeKey: keccak256("m14-voluntary-disclosure-scope"),
            proofReceiptId: 0,
            relatedReceiptId: 0,
            expiresAt: 0,
            reasonHash: keccak256("m14-voluntary-disclosure-intent"),
            uri: "ipfs://m14-voluntary-disclosure-intent"
        });
        try panelActorA.recordDisclosure(disclosureReceiptRegistry, input) {
            revert("third party recorded voluntary disclosure intent");
        } catch {}

        authorityMatrix.setPermission(APP_A, SUBJECT_ROLE, AVACoreTypes.ACTION_RECORD_DISCLOSURE_RECEIPT, true);
        input.roleKey = SUBJECT_ROLE;
        input.authorityId = SUBJECT_A;
        uint256 receiptId = subjectActorA.recordDisclosure(disclosureReceiptRegistry, input);
        require(
            disclosureReceiptRegistry.getDisclosureReceipt(receiptId).recordedBy == address(subjectActorA),
            "responsible subject self-claim missing"
        );
    }

    function testM145DisclosureGrantFailsClosedAfterPinnedEvidenceRevocation() public {
        uint256 grantId = panelActorA.recordDisclosure(
            disclosureReceiptRegistry,
            AVADisclosureReceiptExtension.DisclosureInput({
                recognisedStateId: stateA,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: evidenceA,
                kind: AVADisclosureReceiptExtension.DisclosureReceiptKind.AccessGrant,
                scopeKey: keccak256("m14-revoked-evidence-grant"),
                proofReceiptId: 0,
                relatedReceiptId: 0,
                expiresAt: uint64(block.timestamp + 7 days),
                reasonHash: keccak256("m14-revoked-evidence-grant"),
                uri: "ipfs://m14-revoked-evidence-grant"
            })
        );
        panelActorA.recordEvidenceLifecycle(
            evidenceRegistry, evidenceA, PANEL_ROLE, PANEL_A, AVACoreTypes.EvidenceLifecycleKind.Revoke
        );
        require(!disclosureReceiptRegistry.isAccessGrantActive(grantId), "grant ignored pinned evidence revocation");
    }

    function testM145AuditReceiptBindsStableStateTransitionAndRejectsCrossAppTarget() public {
        uint256 transitionId = kernel.getRecognisedState(stateA).lastTransitionId;
        uint256 auditId = panelActorA.recordAudit(
            auditRegistry,
            AVAAuditReceiptExtension.AuditInput({
                targetKind: AVAAuditReceiptExtension.AuditTargetKind.RecognisedStateTransition,
                targetId: transitionId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: evidenceA,
                auditTypeKey: keccak256("m14-transition-audit"),
                attestationHash: keccak256("m14-transition-attestation"),
                reasonHash: keccak256("m14-transition-audit-reason"),
                uri: "ipfs://m14-transition-audit"
            })
        );
        AVAAuditReceiptExtension.AuditReceipt memory receipt = auditRegistry.getAuditReceipt(auditId);
        require(
            receipt.packageId == packageA
                && receipt.targetKind == AVAAuditReceiptExtension.AuditTargetKind.RecognisedStateTransition
                && receipt.targetId == transitionId,
            "audit target provenance missing"
        );
        try panelActorA.recordAudit(
            auditRegistry,
            AVAAuditReceiptExtension.AuditInput({
                targetKind: AVAAuditReceiptExtension.AuditTargetKind.RecognisedStateTransition,
                targetId: kernel.getRecognisedState(stateB).lastTransitionId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: evidenceA,
                auditTypeKey: keccak256("m14-cross-app-audit"),
                attestationHash: keccak256("m14-cross-app-attestation"),
                reasonHash: keccak256("m14-cross-app-audit-reason"),
                uri: "ipfs://m14-cross-app-audit"
            })
        ) {
            revert("cross-app transition audit accepted");
        } catch {}
    }

    function testM145AuditCanPreserveHistoryAfterResponsibleSubjectDeactivation() public {
        uint256 transitionId = kernel.getRecognisedState(stateA).lastTransitionId;
        identityRegistry.deactivateSubject(SUBJECT_A);
        uint256 auditId = panelActorA.recordAudit(
            auditRegistry,
            AVAAuditReceiptExtension.AuditInput({
                targetKind: AVAAuditReceiptExtension.AuditTargetKind.RecognisedStateTransition,
                targetId: transitionId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: evidenceA,
                auditTypeKey: keccak256("m14-historical-subject-audit"),
                attestationHash: keccak256("m14-historical-subject-attestation"),
                reasonHash: keccak256("m14-historical-subject-reason"),
                uri: "ipfs://m14-historical-subject-audit"
            })
        );
        require(auditRegistry.getAuditReceipt(auditId).subjectId == SUBJECT_A, "historical subject audit missing");
    }

    function testParityAuditReceiptsSupportEvidenceStateAndStateTransitionTargets() public {
        uint256 evidenceAuditId = panelActorA.recordAudit(
            auditRegistry,
            AVAAuditReceiptExtension.AuditInput({
                targetKind: AVAAuditReceiptExtension.AuditTargetKind.EvidenceReceipt,
                targetId: evidenceA,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: evidenceA,
                auditTypeKey: keccak256("m14-evidence-audit"),
                attestationHash: keccak256("m14-evidence-attestation"),
                reasonHash: keccak256("m14-evidence-audit-reason"),
                uri: "ipfs://m14-evidence-audit"
            })
        );
        uint256 stateAuditId = panelActorA.recordAudit(
            auditRegistry,
            AVAAuditReceiptExtension.AuditInput({
                targetKind: AVAAuditReceiptExtension.AuditTargetKind.RecognisedState,
                targetId: stateA,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: evidenceA,
                auditTypeKey: keccak256("m14-state-audit"),
                attestationHash: keccak256("m14-state-attestation"),
                reasonHash: keccak256("m14-state-audit-reason"),
                uri: "ipfs://m14-state-audit"
            })
        );
        uint256 transitionId = kernel.getRecognisedState(stateA).lastTransitionId;
        uint256 transitionAuditId = panelActorA.recordAudit(
            auditRegistry,
            AVAAuditReceiptExtension.AuditInput({
                targetKind: AVAAuditReceiptExtension.AuditTargetKind.RecognisedStateTransition,
                targetId: transitionId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: evidenceA,
                auditTypeKey: keccak256("m14-state-transition-audit"),
                attestationHash: keccak256("m14-state-transition-attestation"),
                reasonHash: keccak256("m14-state-transition-audit-reason"),
                uri: "ipfs://m14-state-transition-audit"
            })
        );
        require(
            auditRegistry.getAuditReceipt(evidenceAuditId).targetKind
                == AVAAuditReceiptExtension.AuditTargetKind.EvidenceReceipt,
            "evidence audit target missing"
        );
        require(
            auditRegistry.getAuditReceipt(stateAuditId).targetKind
                == AVAAuditReceiptExtension.AuditTargetKind.RecognisedState,
            "state audit target missing"
        );
        require(
            auditRegistry.getAuditReceipt(stateAuditId).recognisedStateTransitionId == transitionId,
            "state audit target version missing"
        );
        require(
            auditRegistry.getAuditReceipt(transitionAuditId).targetId == transitionId,
            "state transition audit target missing"
        );
    }

    function testM145SettlementAndExternalOperationAreSourceBoundRecordOnlyReceipts() public {
        uint256 allocationId = panelActorA.recordAllocation(
            allocationRegistry,
            AVAAllocationRecordExtension.AllocationInput({
                recognisedStateId: stateA,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: evidenceA,
                allocationKindKey: keccak256("m14-bounded-administrative-right"),
                units: 2,
                reasonHash: keccak256("m14-bounded-administrative-right"),
                uri: "ipfs://m14-bounded-administrative-right"
            })
        );
        AVASettlementReceiptExtension.SettlementInput memory settlementInput =
            AVASettlementReceiptExtension.SettlementInput({
                sourceRegistry: address(allocationRegistry),
                sourceRecordId: allocationId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: evidenceA,
                settlementKindKey: keccak256("m14-record-only-settlement"),
                units: 2,
                referenceHash: keccak256("m14-record-only-reference"),
                uri: "ipfs://m14-record-only-settlement"
            });
        uint256 settlementId = panelActorA.recordSettlement(settlementRegistry, settlementInput);
        require(
            settlementRegistry.getSettlement(settlementId).sourceRecordId == allocationId, "settlement source missing"
        );
        try panelActorA.recordSettlement(settlementRegistry, settlementInput) {
            revert("duplicate source settlement accepted");
        } catch {}

        uint256 operationId = panelActorA.requestOperation(
            externalOperationRegistry,
            AVAExternalOperationExtension.OperationInput({
                settlementId: settlementId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: evidenceA,
                operationKey: keccak256("m14-record-only-external-operation"),
                payloadHash: keccak256("m14-record-only-payload"),
                uri: "ipfs://m14-record-only-external-operation"
            })
        );
        uint256 terminalId = panelActorA.recordOperationOutcome(
            externalOperationRegistry,
            operationId,
            AVAExternalOperationExtension.OperationStatus.Cancelled,
            PANEL_ROLE,
            PANEL_A,
            keccak256("m14-operation-cancelled")
        );
        require(
            externalOperationRegistry.terminalReceiptIdByOperation(operationId) == terminalId,
            "operation terminal lineage missing"
        );
        try panelActorA.recordOperationOutcome(
            externalOperationRegistry,
            operationId,
            AVAExternalOperationExtension.OperationStatus.Acknowledged,
            PANEL_ROLE,
            PANEL_A,
            keccak256("m14-duplicate-operation-terminal")
        ) {
            revert("duplicate terminal operation receipt accepted");
        } catch {}
    }

    function testM145SettlementRejectsReaderThatAliasesQueriedSourceId() public {
        AVACoreTypes.RecognisedStateRecord memory state = kernel.getRecognisedState(stateA);
        M14AliasedDownstreamSource aliasedSource = new M14AliasedDownstreamSource(
            kernel,
            IAVADownstreamRecordSource.DownstreamSourceContext({
                id: 2,
                sourceTypeKey: keccak256("m14-aliased-downstream-source"),
                recognisedStateId: stateA,
                recognisedStateTransitionId: state.lastTransitionId,
                appId: APP_A,
                workflowKey: WORKFLOW,
                packageId: packageA,
                subjectId: SUBJECT_A,
                evidenceId: evidenceA,
                recordTypeKey: keccak256("m14-aliased-allocation"),
                units: 1
            })
        );
        AVASettlementReceiptExtension aliasedSettlementRegistry = new AVASettlementReceiptExtension(
            kernel,
            authorityMatrix,
            identityRegistry,
            packageRegistry,
            evidenceRegistry,
            disclosureRegistry,
            aliasedSource,
            IAVADownstreamRecordSource(address(consequenceRegistry))
        );

        try panelActorA.recordSettlement(
            aliasedSettlementRegistry,
            AVASettlementReceiptExtension.SettlementInput({
                sourceRegistry: address(aliasedSource),
                sourceRecordId: 1,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: evidenceA,
                settlementKindKey: keccak256("m14-aliased-settlement"),
                units: 1,
                referenceHash: keccak256("m14-aliased-settlement-reference"),
                uri: "ipfs://m14-aliased-settlement"
            })
        ) {
            revert("aliased downstream source id accepted");
        } catch {}
    }

    function testM145ExternalOperationRejectsReaderThatAliasesQueriedSettlementId() public {
        AVACoreTypes.RecognisedStateRecord memory state = kernel.getRecognisedState(stateA);
        M14AliasedSettlementSource aliasedSource = new M14AliasedSettlementSource(
            kernel,
            IAVASettlementReceiptSource.SettlementSourceContext({
                id: 2,
                recognisedStateId: stateA,
                recognisedStateTransitionId: state.lastTransitionId,
                appId: APP_A,
                workflowKey: WORKFLOW,
                packageId: packageA,
                subjectId: SUBJECT_A,
                evidenceId: evidenceA,
                sourceRegistry: address(allocationRegistry),
                sourceTypeKey: keccak256("m14-aliased-settlement-source"),
                sourceRecordId: 1,
                settlementKindKey: keccak256("m14-aliased-settlement-kind"),
                units: 1,
                referenceHash: keccak256("m14-aliased-settlement-reference")
            })
        );
        AVAExternalOperationExtension aliasedOperationRegistry = new AVAExternalOperationExtension(
            kernel,
            authorityMatrix,
            identityRegistry,
            packageRegistry,
            evidenceRegistry,
            disclosureRegistry,
            new AVAExternalOperationTargetResolver(
                kernel,
                evidenceRegistry,
                AVAChallengeExtension(address(0)),
                IAVADownstreamRecordSource(address(0)),
                IAVADownstreamRecordSource(address(0)),
                aliasedSource
            )
        );

        try panelActorA.requestOperation(
            aliasedOperationRegistry,
            AVAExternalOperationExtension.OperationInput({
                settlementId: 1,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: evidenceA,
                operationKey: keccak256("m14-aliased-external-operation"),
                payloadHash: keccak256("m14-aliased-external-operation-payload"),
                uri: "ipfs://m14-aliased-external-operation"
            })
        ) {
            revert("aliased settlement source id accepted");
        } catch {}
    }

    function testM145AcknowledgementRequiresLiveSourceButCancellationRemainsAvailable() public {
        uint256 allocationId = panelActorA.recordAllocation(
            allocationRegistry,
            AVAAllocationRecordExtension.AllocationInput({
                recognisedStateId: stateA,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: evidenceA,
                allocationKindKey: keccak256("m14-operation-lifecycle-allocation"),
                units: 1,
                reasonHash: keccak256("m14-operation-lifecycle-allocation"),
                uri: "ipfs://m14-operation-lifecycle-allocation"
            })
        );
        uint256 settlementId = panelActorA.recordSettlement(
            settlementRegistry,
            AVASettlementReceiptExtension.SettlementInput({
                sourceRegistry: address(allocationRegistry),
                sourceRecordId: allocationId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: evidenceA,
                settlementKindKey: keccak256("m14-operation-lifecycle-settlement"),
                units: 1,
                referenceHash: keccak256("m14-operation-lifecycle-reference"),
                uri: "ipfs://m14-operation-lifecycle-settlement"
            })
        );
        uint256 operationId = panelActorA.requestOperation(
            externalOperationRegistry,
            AVAExternalOperationExtension.OperationInput({
                settlementId: settlementId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: evidenceA,
                operationKey: keccak256("m14-operation-lifecycle"),
                payloadHash: keccak256("m14-operation-lifecycle-payload"),
                uri: "ipfs://m14-operation-lifecycle"
            })
        );
        panelActorA.recordEvidenceLifecycle(
            evidenceRegistry, evidenceA, PANEL_ROLE, PANEL_A, AVACoreTypes.EvidenceLifecycleKind.Revoke
        );
        try panelActorA.recordOperationOutcome(
            externalOperationRegistry,
            operationId,
            AVAExternalOperationExtension.OperationStatus.Acknowledged,
            PANEL_ROLE,
            PANEL_A,
            keccak256("m14-stale-operation-acknowledgement")
        ) {
            revert("stale operation was acknowledged");
        } catch {}
        uint256 cancellationId = panelActorA.recordOperationOutcome(
            externalOperationRegistry,
            operationId,
            AVAExternalOperationExtension.OperationStatus.Cancelled,
            PANEL_ROLE,
            PANEL_A,
            keccak256("m14-stale-operation-cancellation")
        );
        require(cancellationId != 0, "stale operation could not be safely cancelled");
    }

    function testParityExternalOperationCancellationSurvivesLaterStateTransition() public {
        uint256 allocationId = panelActorA.recordAllocation(
            allocationRegistry,
            AVAAllocationRecordExtension.AllocationInput({
                recognisedStateId: stateA,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: evidenceA,
                allocationKindKey: keccak256("m14-transition-stale-operation-allocation"),
                units: 1,
                reasonHash: keccak256("m14-transition-stale-operation-allocation"),
                uri: "ipfs://m14-transition-stale-operation-allocation"
            })
        );
        uint256 operationId = panelActorA.requestTargetOperation(
            externalOperationRegistry,
            AVAExternalOperationExtension.TargetOperationInput({
                targetKind: AVAExternalOperationTargetKind.AllocationRecord,
                targetId: allocationId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                operationKey: keccak256("m14-transition-stale-operation"),
                payloadHash: keccak256("m14-transition-stale-operation-payload"),
                uri: "ipfs://m14-transition-stale-operation"
            })
        );
        uint256 settlementId = panelActorA.recordSettlement(
            settlementRegistry,
            AVASettlementReceiptExtension.SettlementInput({
                sourceRegistry: address(allocationRegistry),
                sourceRecordId: allocationId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: evidenceA,
                settlementKindKey: keccak256("m14-transition-stale-operation-settlement"),
                units: 1,
                referenceHash: keccak256("m14-transition-stale-operation-settlement"),
                uri: "ipfs://m14-transition-stale-operation-settlement"
            })
        );
        uint256 settlementOperationId = panelActorA.requestOperation(
            externalOperationRegistry,
            AVAExternalOperationExtension.OperationInput({
                settlementId: settlementId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: evidenceA,
                operationKey: keccak256("m14-transition-stale-settlement-operation"),
                payloadHash: keccak256("m14-transition-stale-settlement-operation-payload"),
                uri: "ipfs://m14-transition-stale-settlement-operation"
            })
        );

        authorityMatrix.setPermission(APP_A, PANEL_ROLE, AVACoreTypes.ACTION_RESOLVE_CHALLENGE, true);
        AVACoreTypes.RecognisedStateRecord memory state = kernel.getRecognisedState(stateA);
        highImpactRequester.request(
            kernel,
            AVAGovernanceKernel.SourceBoundTransitionInput({
                recognisedStateId: stateA,
                expectedTransitionId: state.lastTransitionId,
                decisionPackageId: packageA,
                sourceRecordId: 1,
                decisionEvidenceReceiptId: evidenceA,
                disclosureTargetId: stateA,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                actionKey: AVACoreTypes.ACTION_RESOLVE_CHALLENGE,
                decisionHash: keccak256("m14-transition-stale-operation-decision"),
                toStatus: AVACoreTypes.RecognisedStateStatus.Downgraded,
                kind: AVACoreTypes.TransitionKind.ChallengeCorrection,
                reasonHash: keccak256("m14-transition-stale-operation-correction"),
                reasonURI: "ipfs://m14-transition-stale-operation-correction"
            })
        );

        _assertTransitionStaleOperationCanOnlyClose(operationId, "allocation");
        _assertTransitionStaleOperationCanOnlyClose(settlementOperationId, "settlement");
    }

    function testParityExternalOperationCancellationSurvivesPackageIdentityDrift() public {
        uint256 allocationId = panelActorA.recordAllocation(
            allocationRegistry,
            AVAAllocationRecordExtension.AllocationInput({
                recognisedStateId: stateA,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: evidenceA,
                allocationKindKey: keccak256("m14-package-drift-operation-allocation"),
                units: 1,
                reasonHash: keccak256("m14-package-drift-operation-allocation"),
                uri: "ipfs://m14-package-drift-operation-allocation"
            })
        );
        uint256 operationId = panelActorA.requestTargetOperation(
            externalOperationRegistry,
            AVAExternalOperationExtension.TargetOperationInput({
                targetKind: AVAExternalOperationTargetKind.AllocationRecord,
                targetId: allocationId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                operationKey: keccak256("m14-package-drift-operation"),
                payloadHash: keccak256("m14-package-drift-operation-payload"),
                uri: "ipfs://m14-package-drift-operation"
            })
        );

        address externalOperationModule = packageRegistry.getModule(packageA, AVACapabilityKeys.EXTERNAL_OPERATION);
        M14StandingZKCredentialUsePolicyModule replacement = new M14StandingZKCredentialUsePolicyModule();
        vm.etch(externalOperationModule, address(replacement).code);

        _assertTransitionStaleOperationCanOnlyClose(operationId, "package-drift");
    }

    function _assertTransitionStaleOperationCanOnlyClose(uint256 operationId, string memory source) private {
        try panelActorA.recordOperationOutcome(
            externalOperationRegistry,
            operationId,
            AVAExternalOperationExtension.OperationStatus.Acknowledged,
            PANEL_ROLE,
            PANEL_A,
            keccak256(abi.encode(source, "m14-transition-stale-operation-acknowledgement"))
        ) {
            revert("state-transition-stale operation was acknowledged");
        } catch {}
        uint256 cancellationId = panelActorA.recordOperationOutcome(
            externalOperationRegistry,
            operationId,
            AVAExternalOperationExtension.OperationStatus.Cancelled,
            PANEL_ROLE,
            PANEL_A,
            keccak256(abi.encode(source, "m14-transition-stale-operation-cancellation"))
        );
        require(cancellationId != 0, "state-transition-stale operation could not be cancelled");
    }

    function testParityExternalOperationsSupportStateEvidenceAllocationAndConsequenceTargets() public {
        uint256 allocationId = panelActorA.recordAllocation(
            allocationRegistry,
            AVAAllocationRecordExtension.AllocationInput({
                recognisedStateId: stateA,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: evidenceA,
                allocationKindKey: keccak256("m14-operation-allocation-target"),
                units: 1,
                reasonHash: keccak256("m14-operation-allocation-target"),
                uri: "ipfs://m14-operation-allocation-target"
            })
        );
        uint256 consequenceId = panelActorA.recordConsequence(
            consequenceRegistry,
            AVAConsequenceRecordExtension.ConsequenceInput({
                recognisedStateId: stateA,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: evidenceA,
                consequenceKindKey: keccak256("m14-operation-consequence-target"),
                reasonHash: keccak256("m14-operation-consequence-target"),
                uri: "ipfs://m14-operation-consequence-target"
            })
        );
        AVAExternalOperationTargetKind[4] memory kinds = [
            AVAExternalOperationTargetKind.RecognisedState,
            AVAExternalOperationTargetKind.EvidenceReceipt,
            AVAExternalOperationTargetKind.AllocationRecord,
            AVAExternalOperationTargetKind.ConsequenceRecord
        ];
        uint256[4] memory targetIds = [stateA, evidenceA, allocationId, consequenceId];
        for (uint256 i; i < kinds.length; ++i) {
            uint256 operationId = panelActorA.requestTargetOperation(
                externalOperationRegistry,
                AVAExternalOperationExtension.TargetOperationInput({
                    targetKind: kinds[i],
                    targetId: targetIds[i],
                    roleKey: PANEL_ROLE,
                    authorityId: PANEL_A,
                    operationKey: keccak256(abi.encode("m14-target-operation", i)),
                    payloadHash: keccak256(abi.encode("m14-target-operation-payload", i)),
                    uri: "ipfs://m14-target-operation"
                })
            );
            AVAExternalOperationExtension.OperationReceipt memory operation =
                externalOperationRegistry.getOperation(operationId);
            require(operation.targetKind == kinds[i], "operation target kind missing");
            require(operation.targetId == targetIds[i], "operation target id missing");
            require(operation.packageId == packageA, "operation target package missing");
        }
    }

    function testM145NewOptionalExtensionsExposeNoRevealPaymentOrPublicationSelectors() public {
        (bool revealSuccess,) =
            address(disclosureReceiptRegistry).call(abi.encodeWithSignature("revealIdentity(uint256)", 1));
        (bool decryptSuccess,) =
            address(disclosureReceiptRegistry).call(abi.encodeWithSignature("decryptEvidence(uint256)", 1));
        (bool paymentSuccess,) = address(settlementRegistry)
            .call(abi.encodeWithSignature("transferValue(address,address,uint256)", address(this), address(1), 1));
        (bool executeSuccess,) =
            address(externalOperationRegistry).call(abi.encodeWithSignature("executeOperation(uint256)", 1));
        (bool publicationSuccess,) =
            address(auditRegistry).call(abi.encodeWithSignature("acceptManuscript(uint256)", 1));
        require(
            !revealSuccess && !decryptSuccess && !paymentSuccess && !executeSuccess && !publicationSuccess,
            "optional extension exposed forbidden execution selector"
        );
    }

    function testM145OptionalExtensionsRejectCrossApplicationReferences() public {
        try panelActorB.registerPrivacyProof(
            privacyProofRegistry, _proofInput(stateA, SUBJECT_B, PANEL_B, evidenceB, keccak256("m14-cross-app-proof"))
        ) {
            revert("cross-app proof accepted");
        } catch {}
        try panelActorB.recordAudit(
            auditRegistry,
            AVAAuditReceiptExtension.AuditInput({
                targetKind: AVAAuditReceiptExtension.AuditTargetKind.RecognisedStateTransition,
                targetId: kernel.getRecognisedState(stateA).lastTransitionId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_B,
                subjectId: SUBJECT_B,
                evidenceId: evidenceB,
                auditTypeKey: keccak256("m14-cross-app-audit-reference"),
                attestationHash: keccak256("m14-cross-app-audit-attestation"),
                reasonHash: keccak256("m14-cross-app-audit-reason"),
                uri: "ipfs://m14-cross-app-audit-reference"
            })
        ) {
            revert("cross-app audit accepted");
        } catch {}

        uint256 allocationId = panelActorA.recordAllocation(
            allocationRegistry,
            AVAAllocationRecordExtension.AllocationInput({
                recognisedStateId: stateA,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: evidenceA,
                allocationKindKey: keccak256("m14-cross-app-allocation-source"),
                units: 1,
                reasonHash: keccak256("m14-cross-app-allocation-source"),
                uri: "ipfs://m14-cross-app-allocation-source"
            })
        );
        try panelActorB.recordSettlement(
            settlementRegistry,
            AVASettlementReceiptExtension.SettlementInput({
                sourceRegistry: address(allocationRegistry),
                sourceRecordId: allocationId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_B,
                subjectId: SUBJECT_B,
                evidenceId: evidenceB,
                settlementKindKey: keccak256("m14-cross-app-settlement"),
                units: 1,
                referenceHash: keccak256("m14-cross-app-settlement-reference"),
                uri: "ipfs://m14-cross-app-settlement"
            })
        ) {
            revert("cross-app settlement accepted");
        } catch {}
    }

    function testM145SettlementPolicyReceivesSourceTypeScopePayloadAndUnits() public {
        uint256 allocationId = panelActorA.recordAllocation(
            allocationRegistry,
            AVAAllocationRecordExtension.AllocationInput({
                recognisedStateId: stateA,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: evidenceA,
                allocationKindKey: keccak256("m14-policy-bounded-allocation"),
                units: 3,
                reasonHash: keccak256("m14-policy-bounded-allocation"),
                uri: "ipfs://m14-policy-bounded-allocation"
            })
        );
        uint256 nextSettlementIdBefore = settlementRegistry.nextSettlementId();
        try panelActorA.recordSettlement(
            settlementRegistry,
            AVASettlementReceiptExtension.SettlementInput({
                sourceRegistry: address(allocationRegistry),
                sourceRecordId: allocationId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: evidenceA,
                settlementKindKey: keccak256("m14-policy-bounded-settlement"),
                units: 3,
                referenceHash: keccak256("m14-policy-bounded-reference"),
                uri: "ipfs://m14-policy-bounded-settlement"
            })
        ) {
            revert("settlement policy did not receive bounded fields");
        } catch {}
        require(settlementRegistry.nextSettlementId() == nextSettlementIdBefore, "rejected settlement wrote storage");
    }

    function testParityStandingFormulaZKProofAndCommitmentCredentialPreserveProvenanceAndRevision() public {
        IZKProofVerifier.SchnorrProof memory proof = _standingProof();
        bytes32 subjectCommitment = keccak256(abi.encode(proof.publicKey.x, proof.publicKey.y));
        uint256 formulaId = panelActorA.registerStandingFormula(
            provenanceRegistry,
            AVAStandingProvenanceExtension.FormulaInput({
                appId: APP_A,
                workflowKey: WORKFLOW,
                packageId: packageA,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                vectorKey: VECTOR,
                formulaVersion: 1,
                computationRuleHash: keccak256("m14-zk-computation-rule"),
                sourceSetPolicyHash: keccak256("m14-zk-source-policy"),
                decayPolicyHash: keccak256("m14-zk-decay-policy"),
                capPolicyHash: keccak256("m14-zk-cap-policy"),
                restorationPolicyHash: keccak256("m14-zk-restoration-policy"),
                verifier: address(standingProofVerifier),
                proofDomainHash: standingProofVerifier.proofDomain(),
                uri: "ipfs://m14-zk-standing-formula"
            })
        );
        uint256 sourceSetId = panelActorA.registerStandingSourceSet(
            provenanceRegistry,
            AVAStandingProvenanceExtension.SourceSetInput({
                formulaId: formulaId,
                recognisedStateId: stateA,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                subjectCommitment: subjectCommitment,
                categoryHash: CATEGORY_A,
                epoch: 1,
                sourceRecordSetRoot: keccak256("m14-zk-source-root"),
                evidenceId: evidenceA,
                completenessCommitment: keccak256("m14-zk-completeness-commitment"),
                uri: "ipfs://m14-zk-standing-source-set"
            })
        );
        uint256 attestationId = panelActorA.attestStandingSourceSet(
            provenanceRegistry,
            AVAStandingProvenanceExtension.CompletenessInput({
                sourceSetId: sourceSetId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                evidenceId: evidenceA,
                includedRecordClassesHash: keccak256("m14-zk-included-record-classes"),
                exclusionPolicyHash: keccak256("m14-zk-exclusion-policy"),
                attestationHash: keccak256("m14-zk-completeness-attestation"),
                uri: "ipfs://m14-zk-completeness-attestation"
            })
        );
        uint256 statementId = panelActorA.recordStandingStatement(
            provenanceRegistry,
            AVAStandingProvenanceExtension.StatementInput({
                sourceSetId: sourceSetId,
                completenessAttestationId: attestationId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                evidenceId: evidenceA,
                threshold: 50,
                lowerBound: 40,
                upperBound: 100,
                outputCommitment: keccak256("m14-zk-standing-output"),
                uri: "ipfs://m14-zk-standing-statement"
            })
        );
        uint256 proofReceiptId = panelActorA.registerStandingZKProof(
            standingZKProofRegistry,
            AVAStandingZKProofExtension.ProofInput({
                statementId: statementId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                proof: proof,
                uri: "ipfs://m14-zk-standing-proof"
            })
        );
        uint256 credentialId = panelActorA.issueStandingZKCredential(
            standingZKCredentialRegistry,
            AVAStandingZKCredentialExtension.CredentialInput({
                proofReceiptId: proofReceiptId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                credentialCommitment: keccak256("m14-zk-standing-credential"),
                expiresAt: uint64(block.timestamp + 7 days),
                uri: "ipfs://m14-zk-standing-credential"
            })
        );

        require(
            standingZKProofRegistry.proofSupports(proofReceiptId, packageA, subjectCommitment, VECTOR, CATEGORY_A, 50),
            "standing proof provenance rejected"
        );
        require(
            !standingZKProofRegistry.proofSupports(proofReceiptId, packageB, subjectCommitment, VECTOR, CATEGORY_A, 50),
            "standing proof crossed package"
        );
        require(
            standingZKCredentialRegistry.credentialProves(
                credentialId, packageA, subjectCommitment, VECTOR, CATEGORY_A, 50
            ),
            "standing credential proof rejected"
        );
        require(
            !standingZKCredentialRegistry.credentialProves(
                credentialId, packageB, subjectCommitment, VECTOR, CATEGORY_A, 50
            ),
            "standing credential crossed package"
        );

        AVAStandingZKCredentialExtension.CredentialUseInput memory useInput =
            AVAStandingZKCredentialExtension.CredentialUseInput({
                credentialId: credentialId,
                packageId: packageA,
                beneficiary: address(panelActorA),
                subjectCommitment: subjectCommitment,
                vectorKey: VECTOR,
                categoryHash: CATEGORY_A,
                minimumThreshold: 50,
                targetContextHash: keccak256("m14-zk-standing-target-context"),
                actionKey: keccak256("m14-zk-standing-proof-use"),
                uri: "ipfs://m14-zk-standing-proof-use"
            });
        bool copiedUseAccepted;
        try panelActorB.useStandingZKCredential(standingZKCredentialRegistry, useInput, proof) returns (uint256) {
            copiedUseAccepted = true;
        } catch {}
        require(!copiedUseAccepted, "copied standing credential use front-ran beneficiary");
        panelActorA.useStandingZKCredential(standingZKCredentialRegistry, useInput, proof);
        try panelActorA.useStandingZKCredential(standingZKCredentialRegistry, useInput, proof) {
            revert("standing credential proof-use replay accepted");
        } catch {}

        useInput.targetContextHash = keccak256("m14-blocked-zk-standing-target-context");
        useInput.actionKey = keccak256("m14.blocked-standing-zk-use-action");
        bool blockedUseAccepted;
        try panelActorA.useStandingZKCredential(standingZKCredentialRegistry, useInput, proof) returns (uint256) {
            blockedUseAccepted = true;
        } catch {}
        require(!blockedUseAccepted, "standing ZK credential use bypassed package policy");

        panelActorA.recordStanding(
            standingRegistry,
            AVAStandingRecordExtension.StandingInput({
                recognisedStateId: stateA,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: evidenceA,
                dimensionKey: VECTOR,
                delta: 1,
                reasonHash: keccak256("m14-zk-standing-revision"),
                uri: "ipfs://m14-zk-standing-revision"
            })
        );
        require(!standingZKProofRegistry.isProofUsable(proofReceiptId), "stale standing proof remained usable");
        require(
            !standingZKCredentialRegistry.isCredentialActive(credentialId), "stale standing credential remained active"
        );

        (bool transferSuccess,) = address(standingZKCredentialRegistry)
            .call(
                abi.encodeWithSignature(
                    "transferFrom(address,address,uint256)", address(this), address(1), credentialId
                )
            );
        (bool approveSuccess,) = address(standingZKCredentialRegistry)
            .call(abi.encodeWithSignature("approve(address,uint256)", address(1), credentialId));
        require(!transferSuccess && !approveSuccess, "standing credential exposed transfer or approval");
    }

    function testParityCompletenessEvidenceRevocationInvalidatesStatementProofAndCredential() public {
        uint256 completenessEvidenceId = subjectActorA.registerEvidence(
            evidenceRegistry,
            APP_A,
            WORKFLOW,
            packageA,
            SUBJECT_ROLE,
            SUBJECT_A,
            policyA,
            keccak256("m14-zk-completeness-evidence")
        );
        (uint256 statementId, bytes32 subjectCommitment, IZKProofVerifier.SchnorrProof memory proof) =
            _recordStandingProvenanceStatement(completenessEvidenceId);
        uint256 proofReceiptId = panelActorA.registerStandingZKProof(
            standingZKProofRegistry,
            AVAStandingZKProofExtension.ProofInput({
                statementId: statementId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                proof: proof,
                uri: "ipfs://m14-zk-completeness-proof"
            })
        );
        uint256 credentialId = panelActorA.issueStandingZKCredential(
            standingZKCredentialRegistry,
            AVAStandingZKCredentialExtension.CredentialInput({
                proofReceiptId: proofReceiptId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                credentialCommitment: keccak256("m14-zk-completeness-credential"),
                expiresAt: uint64(block.timestamp + 7 days),
                uri: "ipfs://m14-zk-completeness-credential"
            })
        );
        require(
            standingZKCredentialRegistry.credentialProves(
                credentialId, packageA, subjectCommitment, VECTOR, CATEGORY_A, 50
            ),
            "credential inactive before completeness evidence revocation"
        );

        panelActorA.recordEvidenceLifecycle(
            evidenceRegistry, completenessEvidenceId, PANEL_ROLE, PANEL_A, AVACoreTypes.EvidenceLifecycleKind.Revoke
        );
        require(
            !provenanceRegistry.isComputationStatementActive(statementId),
            "revoked completeness evidence left statement active"
        );
        require(
            !standingZKProofRegistry.isProofUsable(proofReceiptId), "revoked completeness evidence left proof active"
        );
        require(
            !standingZKCredentialRegistry.isCredentialActive(credentialId),
            "revoked completeness evidence left credential active"
        );
    }

    function testParityExpiredStandingZKCredentialCanBeExplicitlySuperseded() public {
        (uint256 firstStatementId, bytes32 subjectCommitment, IZKProofVerifier.SchnorrProof memory proof) =
            _recordStandingProvenanceStatementForEpoch(evidenceA, 1, 1);
        uint256 firstProofReceiptId = panelActorA.registerStandingZKProof(
            standingZKProofRegistry,
            AVAStandingZKProofExtension.ProofInput({
                statementId: firstStatementId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                proof: proof,
                uri: "ipfs://m14-zk-expiring-proof"
            })
        );
        uint256 credentialId = panelActorA.issueStandingZKCredential(
            standingZKCredentialRegistry,
            AVAStandingZKCredentialExtension.CredentialInput({
                proofReceiptId: firstProofReceiptId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                credentialCommitment: keccak256("m14-zk-expiring-credential"),
                expiresAt: uint64(block.timestamp + 1),
                uri: "ipfs://m14-zk-expiring-credential"
            })
        );

        vm.warp(block.timestamp + 2);
        require(!standingZKCredentialRegistry.isCredentialActive(credentialId), "expired credential remained active");

        (
            uint256 replacementStatementId,
            bytes32 replacementCommitment,
            IZKProofVerifier.SchnorrProof memory replacementProof
        ) = _recordStandingProvenanceStatementForEpoch(evidenceA, 2, 2);
        require(replacementCommitment == subjectCommitment, "replacement changed canonical subject commitment");
        uint256 replacementProofReceiptId = panelActorA.registerStandingZKProof(
            standingZKProofRegistry,
            AVAStandingZKProofExtension.ProofInput({
                statementId: replacementStatementId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                proof: replacementProof,
                uri: "ipfs://m14-zk-replacement-proof"
            })
        );
        uint256 replacementCredentialId = panelActorA.supersedeStandingZKCredential(
            standingZKCredentialRegistry,
            credentialId,
            AVAStandingZKCredentialExtension.CredentialInput({
                proofReceiptId: replacementProofReceiptId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                credentialCommitment: keccak256("m14-zk-replacement-credential"),
                expiresAt: uint64(block.timestamp + 7 days),
                uri: "ipfs://m14-zk-replacement-credential"
            })
        );

        AVAStandingZKCredentialExtension.CredentialRecord memory previous =
            standingZKCredentialRegistry.getCredential(credentialId);
        require(previous.supersededBy == replacementCredentialId, "replacement lineage missing");
        require(standingZKCredentialRegistry.isCredentialActive(replacementCredentialId), "replacement inactive");
        require(
            standingZKCredentialRegistry.credentialProves(
                replacementCredentialId, packageA, subjectCommitment, VECTOR, CATEGORY_A, 50
            ),
            "replacement credential did not prove"
        );
    }

    function testParityStandingZKCredentialCannotSupersedeAcrossSubjectsSharingCommitment() public {
        bytes32 subjectC = keccak256("m14.standing.subject-c");
        M14StandingActor subjectActorC = new M14StandingActor();
        identityRegistry.assignSubject(address(subjectActorC), APP_A, SUBJECT_ROLE, subjectC, "ipfs://subject-c");
        uint256 evidenceC = subjectActorC.registerEvidence(
            evidenceRegistry, APP_A, WORKFLOW, packageA, SUBJECT_ROLE, subjectC, policyA, keccak256("evidence-c")
        );
        uint256 stateC =
            _createVestedState(APP_A, packageA, subjectC, PANEL_A, policyA, evidenceC, subjectActorC, panelActorA);

        (uint256 firstStatementId, bytes32 sharedCommitment, IZKProofVerifier.SchnorrProof memory firstProof) =
            _recordStandingProvenanceStatementForSubject(stateA, SUBJECT_A, evidenceA, evidenceA, 1, 1);
        uint256 firstProofReceiptId = panelActorA.registerStandingZKProof(
            standingZKProofRegistry,
            AVAStandingZKProofExtension.ProofInput({
                statementId: firstStatementId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                proof: firstProof,
                uri: "ipfs://m14-zk-cross-subject-first-proof"
            })
        );
        uint256 credentialId = panelActorA.issueStandingZKCredential(
            standingZKCredentialRegistry,
            AVAStandingZKCredentialExtension.CredentialInput({
                proofReceiptId: firstProofReceiptId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                credentialCommitment: keccak256("m14-zk-cross-subject-first-credential"),
                expiresAt: uint64(block.timestamp + 7 days),
                uri: "ipfs://m14-zk-cross-subject-first-credential"
            })
        );

        (
            uint256 replacementStatementId,
            bytes32 replacementCommitment,
            IZKProofVerifier.SchnorrProof memory replacementProof
        ) = _recordStandingProvenanceStatementForSubject(stateC, subjectC, evidenceC, evidenceC, 2, 2);
        require(replacementCommitment == sharedCommitment, "test did not reuse the subject commitment");
        uint256 replacementProofReceiptId = panelActorA.registerStandingZKProof(
            standingZKProofRegistry,
            AVAStandingZKProofExtension.ProofInput({
                statementId: replacementStatementId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                proof: replacementProof,
                uri: "ipfs://m14-zk-cross-subject-replacement-proof"
            })
        );

        bool crossSubjectSupersessionAccepted;
        try panelActorA.supersedeStandingZKCredential(
            standingZKCredentialRegistry,
            credentialId,
            AVAStandingZKCredentialExtension.CredentialInput({
                proofReceiptId: replacementProofReceiptId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                credentialCommitment: keccak256("m14-zk-cross-subject-replacement-credential"),
                expiresAt: uint64(block.timestamp + 7 days),
                uri: "ipfs://m14-zk-cross-subject-replacement-credential"
            })
        ) returns (
            uint256
        ) {
            crossSubjectSupersessionAccepted = true;
        } catch {}

        require(!crossSubjectSupersessionAccepted, "credential lineage crossed role-scoped subjects");
        require(standingZKCredentialRegistry.isCredentialActive(credentialId), "original credential was displaced");
    }

    function testParityRevisionStaleStandingZKCredentialCanBeExplicitlySuperseded() public {
        (uint256 firstStatementId, bytes32 subjectCommitment, IZKProofVerifier.SchnorrProof memory proof) =
            _recordStandingProvenanceStatementForEpoch(evidenceA, 1, 1);
        uint256 firstProofReceiptId = panelActorA.registerStandingZKProof(
            standingZKProofRegistry,
            AVAStandingZKProofExtension.ProofInput({
                statementId: firstStatementId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                proof: proof,
                uri: "ipfs://m14-zk-revision-proof"
            })
        );
        uint256 credentialId = panelActorA.issueStandingZKCredential(
            standingZKCredentialRegistry,
            AVAStandingZKCredentialExtension.CredentialInput({
                proofReceiptId: firstProofReceiptId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                credentialCommitment: keccak256("m14-zk-revision-credential"),
                expiresAt: uint64(block.timestamp + 7 days),
                uri: "ipfs://m14-zk-revision-credential"
            })
        );

        panelActorA.recordStanding(
            standingRegistry,
            AVAStandingRecordExtension.StandingInput({
                recognisedStateId: stateA,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: SUBJECT_A,
                evidenceId: evidenceA,
                dimensionKey: VECTOR,
                delta: 1,
                reasonHash: keccak256("m14-zk-revision-supersession"),
                uri: "ipfs://m14-zk-revision-supersession"
            })
        );
        require(!standingZKCredentialRegistry.isCredentialActive(credentialId), "stale credential remained active");

        (
            uint256 replacementStatementId,
            bytes32 replacementCommitment,
            IZKProofVerifier.SchnorrProof memory replacementProof
        ) = _recordStandingProvenanceStatementForEpoch(evidenceA, 2, 2);
        require(replacementCommitment == subjectCommitment, "replacement changed canonical subject commitment");
        uint256 replacementProofReceiptId = panelActorA.registerStandingZKProof(
            standingZKProofRegistry,
            AVAStandingZKProofExtension.ProofInput({
                statementId: replacementStatementId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                proof: replacementProof,
                uri: "ipfs://m14-zk-revision-replacement-proof"
            })
        );
        uint256 replacementCredentialId = panelActorA.supersedeStandingZKCredential(
            standingZKCredentialRegistry,
            credentialId,
            AVAStandingZKCredentialExtension.CredentialInput({
                proofReceiptId: replacementProofReceiptId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                credentialCommitment: keccak256("m14-zk-revision-replacement-credential"),
                expiresAt: uint64(block.timestamp + 7 days),
                uri: "ipfs://m14-zk-revision-replacement-credential"
            })
        );

        require(!standingZKCredentialRegistry.isCredentialActive(credentialId), "old credential reactivated");
        require(standingZKCredentialRegistry.isCredentialActive(replacementCredentialId), "replacement inactive");
        require(
            standingZKCredentialRegistry.credentialProves(
                replacementCredentialId, packageA, subjectCommitment, VECTOR, CATEGORY_A, 50
            ),
            "replacement credential did not prove"
        );
    }

    function _grantPermissions(bytes32 appId) private {
        authorityMatrix.setPermission(appId, PANEL_ROLE, AVACoreTypes.ACTION_REGISTER_DISCLOSURE_POLICY, true);
        authorityMatrix.setPermission(appId, SUBJECT_ROLE, AVACoreTypes.ACTION_REGISTER_EVIDENCE, true);
        authorityMatrix.setPermission(appId, SUBJECT_ROLE, AVACoreTypes.ACTION_REGISTER_GOVERNED_OBJECT, true);
        authorityMatrix.setPermission(appId, PANEL_ROLE, AVACoreTypes.ACTION_FORM_RECOGNISED_STATE, true);
        authorityMatrix.setPermission(appId, PANEL_ROLE, AVACoreTypes.ACTION_VEST_RECOGNISED_STATE, true);
        authorityMatrix.setPermission(appId, PANEL_ROLE, AVACoreTypes.ACTION_RECORD_EVIDENCE_LIFECYCLE, true);
        authorityMatrix.setPermission(appId, PANEL_ROLE, AVACoreTypes.ACTION_RECORD_STANDING_UPDATE, true);
        authorityMatrix.setPermission(appId, PANEL_ROLE, AVACoreTypes.ACTION_RECORD_ALLOCATION, true);
        authorityMatrix.setPermission(appId, PANEL_ROLE, AVACoreTypes.ACTION_RECORD_CONSEQUENCE, true);
        authorityMatrix.setPermission(appId, PANEL_ROLE, AVACoreTypes.ACTION_RECORD_STANDING_COMPUTATION, true);
        authorityMatrix.setPermission(appId, PANEL_ROLE, AVACoreTypes.ACTION_ISSUE_STANDING_CREDENTIAL, true);
        authorityMatrix.setPermission(appId, PANEL_ROLE, AVACoreTypes.ACTION_REVOKE_STANDING_CREDENTIAL, true);
        authorityMatrix.setPermission(appId, PANEL_ROLE, AVACoreTypes.ACTION_SUPERSEDE_STANDING_CREDENTIAL, true);
        authorityMatrix.setPermission(appId, PANEL_ROLE, AVACoreTypes.ACTION_RECORD_PRIVACY_PROOF, true);
        authorityMatrix.setPermission(appId, PANEL_ROLE, AVACoreTypes.ACTION_RECORD_DISCLOSURE_RECEIPT, true);
        authorityMatrix.setPermission(appId, PANEL_ROLE, AVACoreTypes.ACTION_RECORD_AUDIT_RECEIPT, true);
        authorityMatrix.setPermission(appId, PANEL_ROLE, AVACoreTypes.ACTION_RECORD_SETTLEMENT_RECEIPT, true);
        authorityMatrix.setPermission(appId, PANEL_ROLE, AVACoreTypes.ACTION_RECORD_EXTERNAL_OPERATION, true);
        authorityMatrix.setPermission(appId, PANEL_ROLE, AVACoreTypes.ACTION_RECORD_EXTERNAL_OPERATION_OUTCOME, true);
        authorityMatrix.setPermission(appId, PANEL_ROLE, AVACoreTypes.ACTION_REGISTER_STANDING_FORMULA, true);
        authorityMatrix.setPermission(appId, PANEL_ROLE, AVACoreTypes.ACTION_REGISTER_STANDING_SOURCE_SET, true);
        authorityMatrix.setPermission(appId, PANEL_ROLE, AVACoreTypes.ACTION_ATTEST_STANDING_SOURCE_SET, true);
        authorityMatrix.setPermission(
            appId, PANEL_ROLE, AVACoreTypes.ACTION_RECORD_STANDING_COMPUTATION_STATEMENT, true
        );
        authorityMatrix.setPermission(
            appId, PANEL_ROLE, AVACoreTypes.ACTION_SUPERSEDE_STANDING_COMPUTATION_STATEMENT, true
        );
        authorityMatrix.setPermission(
            appId, PANEL_ROLE, AVACoreTypes.ACTION_INVALIDATE_STANDING_COMPUTATION_STATEMENT, true
        );
        authorityMatrix.setPermission(appId, PANEL_ROLE, AVACoreTypes.ACTION_RECORD_STANDING_ZK_PROOF, true);
        authorityMatrix.setPermission(appId, PANEL_ROLE, AVACoreTypes.ACTION_ISSUE_STANDING_ZK_CREDENTIAL, true);
        authorityMatrix.setPermission(appId, PANEL_ROLE, AVACoreTypes.ACTION_REVOKE_STANDING_ZK_CREDENTIAL, true);
        authorityMatrix.setPermission(appId, PANEL_ROLE, AVACoreTypes.ACTION_SUPERSEDE_STANDING_ZK_CREDENTIAL, true);
    }

    function _optionalExtensionBindings(IAVAApplicationModule applicationModule)
        private
        returns (AVACoreRulePackageRegistry.ModuleBinding[] memory bindings)
    {
        AVACoreRulePackageRegistry.ModuleBinding[] memory coreBindings = _coreBindings(applicationModule);
        bindings = new AVACoreRulePackageRegistry.ModuleBinding[](coreBindings.length + 8);
        address defaultExtensionPolicy = address(coreBindings[12].module);
        for (uint256 i; i < coreBindings.length; ++i) {
            bindings[i] = coreBindings[i];
        }
        bindings[coreBindings.length] = _coreBinding(AVACapabilityKeys.PRIVACY_PROOF, defaultExtensionPolicy);
        bindings[coreBindings.length + 1] = _coreBinding(AVACapabilityKeys.DISCLOSURE_RECEIPT, defaultExtensionPolicy);
        bindings[coreBindings.length + 2] = _coreBinding(AVACapabilityKeys.AUDIT_RECEIPT, defaultExtensionPolicy);
        bindings[coreBindings.length + 3] =
            _coreBinding(AVACapabilityKeys.SETTLEMENT_RECEIPT, address(new M14BoundedSettlementPolicyModule(2)));
        bindings[coreBindings.length + 4] = _coreBinding(AVACapabilityKeys.EXTERNAL_OPERATION, defaultExtensionPolicy);
        bindings[coreBindings.length + 5] = _coreBinding(AVACapabilityKeys.STANDING_PROVENANCE, defaultExtensionPolicy);
        bindings[coreBindings.length + 6] = _coreBinding(AVACapabilityKeys.STANDING_ZK_PROOF, defaultExtensionPolicy);
        bindings[coreBindings.length + 7] = _coreBinding(
            AVACapabilityKeys.STANDING_ZK_CREDENTIAL, address(new M14StandingZKCredentialUsePolicyModule())
        );
    }

    function _createVestedState(
        bytes32 appId,
        uint256 packageId,
        bytes32 subjectId,
        bytes32 panelSubjectId,
        uint256 disclosurePolicyId,
        uint256 evidenceId,
        M14StandingActor subjectActor,
        M14StandingActor panelActor
    ) private returns (uint256 stateId) {
        uint256 objectId = subjectActor.registerObject(
            kernel,
            AVAGovernanceKernel.GovernedObjectInput({
                appId: appId,
                workflowKey: WORKFLOW,
                packageId: packageId,
                roleKey: SUBJECT_ROLE,
                objectTypeKey: OBJECT_TYPE,
                objectCommitment: keccak256(abi.encode("m14-standing-object", appId, subjectId)),
                parentObjectId: 0,
                subjectId: subjectId,
                evidenceReceiptId: evidenceId,
                disclosurePolicyId: disclosurePolicyId,
                metadataHash: keccak256(abi.encode("m14-standing-metadata", appId, subjectId)),
                authorityId: subjectId,
                uri: "ipfs://m14-standing-object"
            })
        );
        stateId = panelActor.formState(
            kernel,
            AVAGovernanceKernel.RecognisedStateFormationInput({
                governedObjectId: objectId,
                roleKey: PANEL_ROLE,
                authorityId: panelSubjectId,
                stage: AVACoreTypes.Stage.Verification,
                status: AVACoreTypes.RecognisedStateStatus.Challengeable,
                reasonHash: keccak256("m14-standing-state"),
                reasonURI: "ipfs://m14-standing-state"
            })
        );
        panelActor.vestState(
            kernel,
            AVAGovernanceKernel.RecognisedStateTransitionInput({
                recognisedStateId: stateId,
                roleKey: PANEL_ROLE,
                authorityId: panelSubjectId,
                toStatus: AVACoreTypes.RecognisedStateStatus.Vested,
                reasonHash: keccak256("m14-standing-vest"),
                reasonURI: "ipfs://m14-standing-vest"
            })
        );
    }

    function _recordComputationA(bytes32 categoryHash, uint256 evidenceId) private returns (uint256) {
        return panelActorA.recordComputation(
            computationRegistry, _computationInput(stateA, SUBJECT_A, PANEL_A, evidenceId, categoryHash)
        );
    }

    function _registerMismatchedPolicyEvidenceA(string memory suffix) private returns (uint256 evidenceId) {
        uint256 alternatePolicyId = panelActorA.registerPolicy(
            disclosureRegistry,
            APP_A,
            PANEL_ROLE,
            PANEL_A,
            keccak256(abi.encode("m14-standing-alternate-policy", suffix))
        );
        evidenceId = subjectActorA.registerEvidence(
            evidenceRegistry,
            APP_A,
            WORKFLOW,
            packageA,
            SUBJECT_ROLE,
            SUBJECT_A,
            alternatePolicyId,
            keccak256(abi.encode("m14-standing-mismatched-policy-evidence", suffix))
        );
    }

    function _issueA(uint256 computationId, uint256 expiresAt) private returns (uint256) {
        return panelActorA.issueCredential(credentialRegistry, _credentialInput(computationId, PANEL_A, expiresAt));
    }

    function _computationInput(
        uint256 recognisedStateId,
        bytes32 subjectId,
        bytes32 authorityId,
        uint256 evidenceId,
        bytes32 categoryHash
    ) private pure returns (AVAStandingComputationExtension.ComputationInput memory) {
        return AVAStandingComputationExtension.ComputationInput({
            recognisedStateId: recognisedStateId,
            roleKey: PANEL_ROLE,
            authorityId: authorityId,
            subjectId: subjectId,
            evidenceId: evidenceId,
            vectorKey: VECTOR,
            categoryHash: categoryHash,
            lowerBound: 50,
            upperBound: 100,
            thresholdSetHash: keccak256("m14-standing-threshold-set"),
            computationRuleHash: keccak256("m14-standing-computation-rule"),
            sourceSetCommitment: keccak256("m14-standing-source-set"),
            outputCommitment: keccak256(abi.encode(recognisedStateId, subjectId, evidenceId, categoryHash)),
            epoch: 1,
            uri: "ipfs://m14-standing-computation"
        });
    }

    function _credentialInput(uint256 computationId, bytes32 authorityId, uint256 expiresAt)
        private
        pure
        returns (AVAStandingCredentialExtension.CredentialInput memory)
    {
        return AVAStandingCredentialExtension.CredentialInput({
            computationId: computationId,
            roleKey: PANEL_ROLE,
            authorityId: authorityId,
            expiresAt: uint64(expiresAt),
            uri: "ipfs://m14-standing-credential"
        });
    }

    function _proofInput(
        uint256 recognisedStateId,
        bytes32 subjectId,
        bytes32 authorityId,
        uint256 evidenceId,
        bytes32 scopeKey
    ) private pure returns (AVAPrivacyProofExtension.ProofInput memory input) {
        IZKProofVerifier.G1Point memory publicKey = IZKProofVerifier.G1Point({x: 1, y: 2});
        input = AVAPrivacyProofExtension.ProofInput({
            recognisedStateId: recognisedStateId,
            roleKey: PANEL_ROLE,
            authorityId: authorityId,
            subjectId: subjectId,
            evidenceId: evidenceId,
            scopeKey: scopeKey,
            subjectCommitment: keccak256(abi.encode(publicKey.x, publicKey.y)),
            proof: IZKProofVerifier.SchnorrProof({
                publicKey: publicKey, commitment: IZKProofVerifier.G1Point({x: 3, y: 4}), response: 5
            }),
            uri: "ipfs://m14-privacy-proof"
        });
    }

    function _standingProof() private pure returns (IZKProofVerifier.SchnorrProof memory proof) {
        proof = IZKProofVerifier.SchnorrProof({
            publicKey: IZKProofVerifier.G1Point({x: 101, y: 202}),
            commitment: IZKProofVerifier.G1Point({x: 303, y: 404}),
            response: 505
        });
    }

    function _recordStandingProvenanceStatement(uint256 completenessEvidenceId)
        private
        returns (uint256 statementId, bytes32 subjectCommitment, IZKProofVerifier.SchnorrProof memory proof)
    {
        return _recordStandingProvenanceStatementForEpoch(completenessEvidenceId, 1, 1);
    }

    function _recordStandingProvenanceStatementForEpoch(
        uint256 completenessEvidenceId,
        uint64 formulaVersion,
        uint256 epoch
    ) private returns (uint256 statementId, bytes32 subjectCommitment, IZKProofVerifier.SchnorrProof memory proof) {
        return _recordStandingProvenanceStatementForSubject(
            stateA, SUBJECT_A, evidenceA, completenessEvidenceId, formulaVersion, epoch
        );
    }

    function _recordStandingProvenanceStatementForSubject(
        uint256 recognisedStateId,
        bytes32 subjectId,
        uint256 subjectEvidenceId,
        uint256 completenessEvidenceId,
        uint64 formulaVersion,
        uint256 epoch
    ) private returns (uint256 statementId, bytes32 subjectCommitment, IZKProofVerifier.SchnorrProof memory proof) {
        proof = _standingProof();
        subjectCommitment = keccak256(abi.encode(proof.publicKey.x, proof.publicKey.y));
        uint256 formulaId = panelActorA.registerStandingFormula(
            provenanceRegistry,
            AVAStandingProvenanceExtension.FormulaInput({
                appId: APP_A,
                workflowKey: WORKFLOW,
                packageId: packageA,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                vectorKey: VECTOR,
                formulaVersion: formulaVersion,
                computationRuleHash: keccak256(abi.encode("m14-zk-completeness-rule", formulaVersion)),
                sourceSetPolicyHash: keccak256(abi.encode("m14-zk-completeness-source-policy", formulaVersion)),
                decayPolicyHash: keccak256(abi.encode("m14-zk-completeness-decay", formulaVersion)),
                capPolicyHash: keccak256(abi.encode("m14-zk-completeness-cap", formulaVersion)),
                restorationPolicyHash: keccak256(abi.encode("m14-zk-completeness-restoration", formulaVersion)),
                verifier: address(standingProofVerifier),
                proofDomainHash: standingProofVerifier.proofDomain(),
                uri: "ipfs://m14-zk-completeness-formula"
            })
        );
        uint256 sourceSetId = panelActorA.registerStandingSourceSet(
            provenanceRegistry,
            AVAStandingProvenanceExtension.SourceSetInput({
                formulaId: formulaId,
                recognisedStateId: recognisedStateId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                subjectId: subjectId,
                subjectCommitment: subjectCommitment,
                categoryHash: CATEGORY_A,
                epoch: epoch,
                sourceRecordSetRoot: keccak256(abi.encode("m14-zk-completeness-source-root", subjectId, epoch)),
                evidenceId: subjectEvidenceId,
                completenessCommitment: keccak256(abi.encode("m14-zk-completeness-input", subjectId, epoch)),
                uri: "ipfs://m14-zk-completeness-source-set"
            })
        );
        uint256 attestationId = panelActorA.attestStandingSourceSet(
            provenanceRegistry,
            AVAStandingProvenanceExtension.CompletenessInput({
                sourceSetId: sourceSetId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                evidenceId: completenessEvidenceId,
                includedRecordClassesHash: keccak256(abi.encode("m14-zk-completeness-record-classes", epoch)),
                exclusionPolicyHash: keccak256(abi.encode("m14-zk-completeness-exclusion", epoch)),
                attestationHash: keccak256(abi.encode("m14-zk-completeness-hash", epoch)),
                uri: "ipfs://m14-zk-completeness-attestation"
            })
        );
        statementId = panelActorA.recordStandingStatement(
            provenanceRegistry,
            AVAStandingProvenanceExtension.StatementInput({
                sourceSetId: sourceSetId,
                completenessAttestationId: attestationId,
                roleKey: PANEL_ROLE,
                authorityId: PANEL_A,
                evidenceId: subjectEvidenceId,
                threshold: 50,
                lowerBound: 40,
                upperBound: 100,
                outputCommitment: keccak256(abi.encode("m14-zk-completeness-output", subjectId, epoch)),
                uri: "ipfs://m14-zk-completeness-statement"
            })
        );
    }
}
