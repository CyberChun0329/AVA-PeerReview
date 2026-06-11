// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../src/AVADataTypes.sol";
import {RoleIdentityRegistry} from "../src/RoleIdentityRegistry.sol";
import {AuthorityMatrix} from "../src/AuthorityMatrix.sol";
import {EvidenceCommitmentRegistry} from "../src/EvidenceCommitmentRegistry.sol";
import {DisclosurePolicyRegistry} from "../src/DisclosurePolicyRegistry.sol";
import {AVAStateMachine} from "../src/AVAStateMachine.sol";
import {
    AVARulePackageRegistry,
    IEvidenceReceiptReader,
    IRecognisedStateReader
} from "../src/AVARulePackageRegistry.sol";
import {ConsequenceExecutor} from "../src/ConsequenceExecutor.sol";
import {StandingRegistry} from "../src/StandingRegistry.sol";
import {StandingCredentialRegistry} from "../src/StandingCredentialRegistry.sol";
import {StandingFormulaRegistry} from "../src/StandingFormulaRegistry.sol";
import {AllocationExecutor} from "../src/AllocationExecutor.sol";
import {ValueSettlementExecutor} from "../src/ValueSettlementExecutor.sol";
import {DisclosureAccessExecutor} from "../src/DisclosureAccessExecutor.sol";
import {ExternalOperationRegistry} from "../src/ExternalOperationRegistry.sol";
import {AuthorityApprovalRegistry} from "../src/AuthorityApprovalRegistry.sol";
import {MockERC20} from "../src/MockERC20.sol";
import {MockPriorityToken} from "../src/MockPriorityToken.sol";
import {AttestationAuditModule} from "../src/AttestationAuditModule.sol";
import {DefaultDisclosurePolicyModule} from "../src/modules/DefaultDisclosurePolicyModule.sol";
import {DefaultAllocationAdapter} from "../src/modules/DefaultAllocationAdapter.sol";
import {DefaultAttributionModule} from "../src/modules/DefaultAttributionModule.sol";
import {DefaultVerificationModule} from "../src/modules/DefaultVerificationModule.sol";
import {DefaultTransitionRuleModule} from "../src/modules/DefaultTransitionRuleModule.sol";
import {DefaultConsequenceAdapter} from "../src/modules/DefaultConsequenceAdapter.sol";
import {DefaultStandingAdapter} from "../src/modules/DefaultStandingAdapter.sol";
import {DefaultRewardAdapter} from "../src/modules/DefaultRewardAdapter.sol";
import {DefaultPriorityAdapter} from "../src/modules/DefaultPriorityAdapter.sol";
import {DefaultPenaltyAdapter} from "../src/modules/DefaultPenaltyAdapter.sol";
import {DefaultRestorationAdapter} from "../src/modules/DefaultRestorationAdapter.sol";
import {DefaultChallengeLifecycleModule} from "../src/modules/DefaultChallengeLifecycleModule.sol";
import {
    DefaultEvidencePolicyModule,
    DefaultAuditAdapter,
    DefaultEditorialSystemAdapter,
    DefaultResidualEditorialAuthorityModule,
    DefaultFieldPolicyModule,
    DefaultAntiAbuseModule
} from "../src/modules/DefaultInfrastructureModules.sol";
import {
    DefaultValueExecutionAdapter,
    DefaultStandingComputationModule,
    DefaultRulePackageLifecycleModule,
    DefaultEvidenceLifecycleModule,
    DefaultDisclosureLifecycleModule
} from "../src/modules/DefaultFutureProofModules.sol";
import {
    DefaultDisclosureExecutionModule,
    KindRejectingDisclosureExecutionModule
} from "../src/modules/DefaultExecutionModules.sol";
import {
    ClaimEscrowRecordValueAdapter,
    VectorStandingComputationModule,
    FormulaV0StandingComputationModule,
    VersionedRulePackageLifecycleModule,
    RejectingEvidenceLifecycleModule,
    RejectingDisclosureLifecycleModule
} from "../src/modules/ExampleFutureProofModules.sol";
import {
    SubjectSaltAttributionModule,
    EvidenceThresholdVerificationModule,
    NoFrozenTransitionRuleModule,
    PanelOnlyChallengeLifecycleModule,
    TypedEvidencePolicyModule,
    HashAnchoredAuditAdapter,
    EditorialReferenceAdapter,
    ProceduralEditorialAuthorityModule,
    StructuredResidualEditorialAuthorityModule,
    DisciplineFieldPolicyModule,
    SubjectRateLimitModule,
    MinimumChallengeWindowTransitionModule
} from "../src/modules/ExampleRuleModules.sol";
import {
    VectorStandingAdapter,
    StablecoinRecordRewardAdapter,
    GenericTokenRecordRewardAdapter,
    PriorityTokenRecordAdapter,
    RentedPriorityRecordAdapter,
    ProceduralPenaltyRecordAdapter,
    PriorityReturnObligationRecordAdapter,
    RestorationProcedureRecordAdapter,
    CorrectionRestorationRecordAdapter,
    BoundedConsequenceExampleAdapter
} from "../src/modules/ExampleDownstreamAdapters.sol";
import {DoubleBlindDisclosureModule} from "../src/modules/DoubleBlindDisclosureModule.sol";
import {PanelVisibleDisclosureModule} from "../src/modules/PanelVisibleDisclosureModule.sol";
import {AnonymousChallengeDisclosureModule} from "../src/modules/AnonymousChallengeDisclosureModule.sol";
import {VoluntaryRealNameChallengeModule} from "../src/modules/VoluntaryRealNameChallengeModule.sol";
import {PostRecognitionAuthorRevealModule} from "../src/modules/PostRecognitionAuthorRevealModule.sol";
import {ZKBackedDisclosureModule} from "../src/modules/ZKBackedDisclosureModule.sol";
import {ApprovalReceiptAuthorityModule} from "../src/modules/ApprovalReceiptAuthorityModule.sol";
import {SchnorrDisclosureProofVerifier} from "../src/SchnorrDisclosureProofVerifier.sol";
import {ZKProofRegistry} from "../src/ZKProofRegistry.sol";
import {ZKStandingComputationRegistry} from "../src/ZKStandingComputationRegistry.sol";
import {ZKStandingCredentialRegistry} from "../src/ZKStandingCredentialRegistry.sol";
import {IDisclosurePolicyModule} from "../src/interfaces/IDisclosurePolicyModule.sol";
import {IZKProofVerifier} from "../src/interfaces/IZKProofVerifier.sol";
import {IAttributionModule} from "../src/interfaces/IAttributionModule.sol";
import {IVerificationModule} from "../src/interfaces/IVerificationModule.sol";
import {ITransitionRuleModule} from "../src/interfaces/ITransitionRuleModule.sol";
import {IAVAAllocationModule} from "../src/interfaces/IAVAAllocationModule.sol";
import {IAllocationAdapter} from "../src/interfaces/IAllocationAdapter.sol";
import {IConsequenceAdapter} from "../src/interfaces/IConsequenceAdapter.sol";
import {IStandingAdapter} from "../src/interfaces/IStandingAdapter.sol";
import {IRewardAdapter} from "../src/interfaces/IRewardAdapter.sol";
import {IPriorityAdapter} from "../src/interfaces/IPriorityAdapter.sol";
import {IPenaltyAdapter} from "../src/interfaces/IPenaltyAdapter.sol";
import {IRestorationAdapter} from "../src/interfaces/IRestorationAdapter.sol";
import {IChallengeLifecycleModule} from "../src/interfaces/IChallengeLifecycleModule.sol";
import {IEvidencePolicyModule} from "../src/interfaces/IEvidencePolicyModule.sol";
import {IAuditAdapter} from "../src/interfaces/IAuditAdapter.sol";
import {IEditorialSystemAdapter} from "../src/interfaces/IEditorialSystemAdapter.sol";
import {IResidualEditorialAuthorityModule} from "../src/interfaces/IResidualEditorialAuthorityModule.sol";
import {IFieldPolicyModule} from "../src/interfaces/IFieldPolicyModule.sol";
import {IAntiAbuseModule} from "../src/interfaces/IAntiAbuseModule.sol";
import {IValueExecutionAdapter} from "../src/interfaces/IValueExecutionAdapter.sol";
import {IStandingComputationModule} from "../src/interfaces/IStandingComputationModule.sol";
import {IRulePackageLifecycleModule} from "../src/interfaces/IRulePackageLifecycleModule.sol";
import {IEvidenceLifecycleModule} from "../src/interfaces/IEvidenceLifecycleModule.sol";
import {IDisclosureLifecycleModule} from "../src/interfaces/IDisclosureLifecycleModule.sol";
import {IDisclosureExecutionModule} from "../src/interfaces/IDisclosureExecutionModule.sol";
import {IStandingCredentialIssuer} from "../src/interfaces/IStandingCredentialIssuer.sol";
import {IZKStandingCredentialIssuer} from "../src/interfaces/IZKStandingCredentialIssuer.sol";
import {IStandingFormulaRegistry} from "../src/interfaces/IStandingFormulaRegistry.sol";

interface Vm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }

    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
    function warp(uint256 timestamp) external;
}

contract ReentrantSettlementToken {
    ValueSettlementExecutor public executor;
    uint256 public sourceRecordId;
    bytes32 public authorityId;
    bool public attemptedReentry;
    bool public reentrySucceeded;
    bool public reentryFailed;

    mapping(address => uint256) public balanceOf;

    function configure(ValueSettlementExecutor executor_, uint256 sourceRecordId_, bytes32 authorityId_) external {
        executor = executor_;
        sourceRecordId = sourceRecordId_;
        authorityId = authorityId_;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _move(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (!attemptedReentry && address(executor) != address(0)) {
            attemptedReentry = true;
            try executor.settleTokenTransfer(
                AVADataTypes.Role.ProtocolExecutor,
                AVADataTypes.ExecutionSourceType.AllocationRecord,
                sourceRecordId,
                authorityId,
                "ipfs://reentrant-settlement"
            ) returns (uint256) {
                reentrySucceeded = true;
            } catch {
                reentryFailed = true;
            }
        }
        _move(from, to, amount);
        return true;
    }

    function _move(address from, address to, uint256 amount) internal {
        if (balanceOf[from] < amount) revert AVADataTypes.InvalidState(amount);
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
    }
}

contract MockDisclosurePolicyModule is IDisclosurePolicyModule {
    uint256 public blockedDisclosurePolicyId;

    constructor(uint256 blockedDisclosurePolicyId_) {
        blockedDisclosurePolicyId = blockedDisclosurePolicyId_;
    }

    function validateDisclosurePolicy(uint256 disclosurePolicyId) external view {
        if (disclosurePolicyId == blockedDisclosurePolicyId) revert AVADataTypes.InvalidState(disclosurePolicyId);
    }

    function validateDisclosureForAction(
        uint256 disclosurePolicyId,
        AVADataTypes.Role,
        AVADataTypes.Action,
        AVADataTypes.AVAStage,
        bytes32,
        bytes32,
        uint256,
        bytes32
    ) external view {
        if (disclosurePolicyId == blockedDisclosurePolicyId) revert AVADataTypes.InvalidState(disclosurePolicyId);
    }
}

contract StageScopedDisclosureModule is IDisclosurePolicyModule {
    AVADataTypes.Action public blockedAction;
    AVADataTypes.AVAStage public blockedStage;
    bytes32 public blockedObjectId;

    constructor(AVADataTypes.Action blockedAction_, AVADataTypes.AVAStage blockedStage_, bytes32 blockedObjectId_) {
        blockedAction = blockedAction_;
        blockedStage = blockedStage_;
        blockedObjectId = blockedObjectId_;
    }

    function validateDisclosurePolicy(uint256 disclosurePolicyId) external pure {
        if (disclosurePolicyId == 0) revert AVADataTypes.EmptyValue();
    }

    function validateDisclosureForAction(
        uint256 disclosurePolicyId,
        AVADataTypes.Role,
        AVADataTypes.Action action,
        AVADataTypes.AVAStage stage,
        bytes32 objectId,
        bytes32,
        uint256,
        bytes32
    ) external view {
        if (disclosurePolicyId == 0) revert AVADataTypes.EmptyValue();
        if (action == blockedAction && stage == blockedStage && objectId == blockedObjectId) {
            revert AVADataTypes.InvalidState(disclosurePolicyId);
        }
    }
}

contract MockAllocationAdapter is IAVAAllocationModule {
    AVADataTypes.AllocationKind public blockedAllocationKind;

    constructor(AVADataTypes.AllocationKind blockedAllocationKind_) {
        blockedAllocationKind = blockedAllocationKind_;
    }

    function validateAllocation(
        AVADataTypes.Role,
        uint256 recognisedStateId,
        AVADataTypes.AllocationKind allocationKind,
        bytes32,
        uint256,
        uint256,
        bytes32,
        string calldata,
        address
    ) external view {
        if (allocationKind == blockedAllocationKind) revert AVADataTypes.InvalidState(recognisedStateId);
    }
}

contract MockConsequenceAdapter is IConsequenceAdapter {
    AVADataTypes.ConsequenceKind public blockedConsequenceKind;

    constructor(AVADataTypes.ConsequenceKind blockedConsequenceKind_) {
        blockedConsequenceKind = blockedConsequenceKind_;
    }

    function validateConsequence(
        AVADataTypes.Role,
        uint256 recognisedStateId,
        AVADataTypes.ConsequenceKind kind,
        bytes32,
        uint256,
        bytes32,
        string calldata,
        address
    ) external view {
        if (kind == blockedConsequenceKind) revert AVADataTypes.InvalidState(recognisedStateId);
    }
}

contract MockStandingAdapter is IStandingAdapter {
    string public blockedDimension;

    constructor(string memory blockedDimension_) {
        blockedDimension = blockedDimension_;
    }

    function validateStandingUpdate(
        AVADataTypes.Role,
        uint256 recognisedStateId,
        bytes32,
        string calldata dimension,
        int256,
        uint256,
        bytes32,
        string calldata,
        address
    ) external view {
        if (keccak256(bytes(dimension)) == keccak256(bytes(blockedDimension))) {
            revert AVADataTypes.InvalidState(recognisedStateId);
        }
    }
}

contract MockRewardAdapter is IRewardAdapter {
    uint256 public blockedAmount;

    constructor(uint256 blockedAmount_) {
        blockedAmount = blockedAmount_;
    }

    function validateRewardRecord(
        AVADataTypes.Role,
        uint256 recognisedStateId,
        bytes32,
        uint256 amountOrUnits,
        uint256,
        bytes32,
        string calldata,
        address
    ) external view {
        if (amountOrUnits == blockedAmount) revert AVADataTypes.InvalidState(recognisedStateId);
    }
}

contract MockPriorityAdapter is IPriorityAdapter {
    uint256 public blockedAmount;

    constructor(uint256 blockedAmount_) {
        blockedAmount = blockedAmount_;
    }

    function validatePriorityRecord(
        AVADataTypes.Role,
        uint256 recognisedStateId,
        bytes32,
        uint256 amountOrUnits,
        uint256,
        bytes32,
        string calldata,
        address
    ) external view {
        if (amountOrUnits == blockedAmount) revert AVADataTypes.InvalidState(recognisedStateId);
    }
}

contract MockPenaltyAdapter is IPenaltyAdapter {
    bytes32 public blockedAuthorityId;

    constructor(bytes32 blockedAuthorityId_) {
        blockedAuthorityId = blockedAuthorityId_;
    }

    function validatePenaltyRecord(
        AVADataTypes.Role,
        uint256 recognisedStateId,
        bytes32,
        uint256,
        bytes32 authorityId,
        string calldata,
        address
    ) external view {
        if (authorityId == blockedAuthorityId) revert AVADataTypes.InvalidState(recognisedStateId);
    }
}

contract MockRestorationAdapter is IRestorationAdapter {
    bytes32 public blockedAuthorityId;

    constructor(bytes32 blockedAuthorityId_) {
        blockedAuthorityId = blockedAuthorityId_;
    }

    function validateRestorationRecord(
        AVADataTypes.Role,
        uint256 recognisedStateId,
        bytes32,
        uint256,
        bytes32 authorityId,
        string calldata,
        address
    ) external view {
        if (authorityId == blockedAuthorityId) revert AVADataTypes.InvalidState(recognisedStateId);
    }
}

contract MockValueExecutionAdapter is IValueExecutionAdapter {
    bytes32 public blockedExecutionReference;
    address public blockedAsset;
    AVADataTypes.ValueExecutionMode public blockedMode;

    constructor(bytes32 blockedExecutionReference_, address blockedAsset_, AVADataTypes.ValueExecutionMode blockedMode_) {
        blockedExecutionReference = blockedExecutionReference_;
        blockedAsset = blockedAsset_;
        blockedMode = blockedMode_;
    }

    function validateValueExecution(AVADataTypes.ValueExecutionContext calldata context) external view {
        if (context.mode == AVADataTypes.ValueExecutionMode.None) {
            revert AVADataTypes.InvalidState(context.recognisedStateId);
        }
        if (
            context.executionReference == blockedExecutionReference || context.asset == blockedAsset
                || context.mode == blockedMode
        ) {
            revert AVADataTypes.InvalidState(context.recognisedStateId);
        }
    }
}

contract ModulesHashGateRulePackageLifecycleModule is IRulePackageLifecycleModule {
    bytes32 public expectedModulesHash;
    bytes32 public expectedCompatibilityKey;

    constructor(bytes32 expectedCompatibilityKey_) {
        expectedCompatibilityKey = expectedCompatibilityKey_;
    }

    function setExpectedModulesHash(bytes32 expectedModulesHash_) external {
        expectedModulesHash = expectedModulesHash_;
    }

    function validateRulePackageLifecycle(RulePackageLifecycleContext calldata context) external view {
        if (
            context.workflowKey == bytes32(0) || context.modulesHash == bytes32(0)
                || context.compatibilityKey != expectedCompatibilityKey || context.modulesHash != expectedModulesHash
                || context.version == 0 || context.deprecated || context.actor == address(0)
        ) {
            revert AVADataTypes.InvalidState(uint256(context.workflowKey));
        }
    }
}

contract TargetAwareRulePackageLifecycleModule is IRulePackageLifecycleModule {
    bytes32 public expectedTargetWorkflowKey;
    uint256 public expectedTargetPackageId;
    bytes32 public expectedTargetModulesHash;
    bytes32 public expectedTargetModulesCodeHash;
    uint64 public expectedTargetVersion;
    bytes32 public expectedTargetCompatibilityKey;

    function setExpectedTarget(
        bytes32 expectedTargetWorkflowKey_,
        uint256 expectedTargetPackageId_,
        bytes32 expectedTargetModulesHash_,
        bytes32 expectedTargetModulesCodeHash_,
        uint64 expectedTargetVersion_,
        bytes32 expectedTargetCompatibilityKey_
    ) external {
        expectedTargetWorkflowKey = expectedTargetWorkflowKey_;
        expectedTargetPackageId = expectedTargetPackageId_;
        expectedTargetModulesHash = expectedTargetModulesHash_;
        expectedTargetModulesCodeHash = expectedTargetModulesCodeHash_;
        expectedTargetVersion = expectedTargetVersion_;
        expectedTargetCompatibilityKey = expectedTargetCompatibilityKey_;
    }

    function validateRulePackageLifecycle(RulePackageLifecycleContext calldata context) external view {
        if (
            context.workflowKey == bytes32(0) || context.modulesHash == bytes32(0)
                || context.modulesCodeHash == bytes32(0) || context.version == 0 || context.compatibilityKey == bytes32(0)
                || context.deprecated || context.actor == address(0)
        ) {
            revert AVADataTypes.InvalidState(uint256(context.workflowKey));
        }
        if (context.kind == AVADataTypes.RulePackageLifecycleKind.MigrationReady) {
            if (
                context.targetWorkflowKey != expectedTargetWorkflowKey
                    || context.targetPackageId != expectedTargetPackageId
                    || context.targetModulesHash != expectedTargetModulesHash
                    || context.targetModulesCodeHash != expectedTargetModulesCodeHash
                    || context.targetVersion != expectedTargetVersion
                    || context.targetCompatibilityKey != expectedTargetCompatibilityKey
            ) {
                revert AVADataTypes.InvalidState(context.targetPackageId);
            }
        }
    }
}

contract RejectingReadyRulePackageLifecycleModule is IRulePackageLifecycleModule {
    function validateRulePackageLifecycle(RulePackageLifecycleContext calldata context) external pure {
        if (context.kind != AVADataTypes.RulePackageLifecycleKind.None) {
            revert AVADataTypes.InvalidState(uint256(context.workflowKey));
        }
    }
}

contract KindScopedEvidenceLifecycleModule is IEvidenceLifecycleModule {
    AVADataTypes.EvidenceLifecycleKind public requiredKind;

    constructor(AVADataTypes.EvidenceLifecycleKind requiredKind_) {
        requiredKind = requiredKind_;
    }

    function validateEvidenceLifecycle(
        bytes32 workflowKey,
        AVADataTypes.Action action,
        uint256 evidenceReceiptId,
        AVADataTypes.EvidenceLifecycleKind kind,
        uint256 replacementEvidenceReceiptId,
        bytes32 lifecycleReference,
        address actor
    ) external view {
        if (workflowKey == bytes32(0) || evidenceReceiptId == 0 || actor == address(0)) {
            revert AVADataTypes.EmptyValue();
        }
        if (action == AVADataTypes.Action.RecordEvidenceLifecycle) {
            if (kind != requiredKind || lifecycleReference == bytes32(0)) {
                revert AVADataTypes.InvalidState(evidenceReceiptId);
            }
            if (kind == AVADataTypes.EvidenceLifecycleKind.ReplacementReady && replacementEvidenceReceiptId == 0) {
                revert AVADataTypes.EmptyValue();
            }
        }
    }
}

contract RejectingAttributionModule is IAttributionModule {
    function validateAttribution(
        bytes32,
        AVADataTypes.Role,
        AVADataTypes.AVAStage,
        bytes32,
        bytes32,
        uint256
    ) external pure returns (bytes32) {
        revert AVADataTypes.InvalidState(0);
    }
}

contract RejectingVerificationModule is IVerificationModule {
    function validateVerification(bytes32, AVADataTypes.Role, AVADataTypes.AVAStage, bytes32, uint256) external pure {
        revert AVADataTypes.InvalidState(0);
    }
}

contract RejectingTransitionRuleModule is ITransitionRuleModule {
    function validateTransition(
        bytes32,
        AVADataTypes.Action,
        AVADataTypes.RecognisedStateStatus,
        AVADataTypes.RecognisedStateStatus,
        AVADataTypes.ChallengeOutcome
    ) external pure {
        revert AVADataTypes.InvalidState(0);
    }
}

contract RejectingChallengeLifecycleModule is IChallengeLifecycleModule {
    AVADataTypes.Action public blockedAction;

    constructor(AVADataTypes.Action blockedAction_) {
        blockedAction = blockedAction_;
    }

    function validateChallengeAction(ChallengeLifecycleContext calldata context) external view {
        if (context.action == blockedAction) revert AVADataTypes.InvalidState(uint256(context.action));
    }
}

contract PermissiveChallengeLifecycleModule is IChallengeLifecycleModule {
    function validateChallengeAction(ChallengeLifecycleContext calldata) external pure {}
}

contract RejectingEvidencePolicyModule is IEvidencePolicyModule {
    AVADataTypes.Action public blockedAction;

    constructor(AVADataTypes.Action blockedAction_) {
        blockedAction = blockedAction_;
    }

    function validateEvidencePolicy(
        bytes32,
        AVADataTypes.Role,
        AVADataTypes.Action action,
        uint256 evidenceReceiptId,
        bytes32,
        address
    ) external view {
        if (action == blockedAction) revert AVADataTypes.InvalidState(evidenceReceiptId);
    }
}

contract RejectingFieldPolicyModule is IFieldPolicyModule {
    function validateFieldPolicy(bytes32, AVADataTypes.Role, AVADataTypes.Action, AVADataTypes.AVAStage, bytes32, uint256)
        external
        pure
    {
        revert AVADataTypes.InvalidState(0);
    }
}

contract RejectingAntiAbuseModule is IAntiAbuseModule {
    AVADataTypes.Action public blockedAction;

    constructor(AVADataTypes.Action blockedAction_) {
        blockedAction = blockedAction_;
    }

    function validateUse(bytes32, AVADataTypes.Role, AVADataTypes.Action action, bytes32, bytes32, address)
        external
        view
    {
        if (action == blockedAction) revert AVADataTypes.InvalidState(uint256(action));
    }
}

contract RejectingAuditAdapter is IAuditAdapter {
    function validateAuditRecord(bytes32, AVADataTypes.Role, AVADataTypes.Action, bytes32, uint256, bytes32, address)
        external
        pure
    {
        revert AVADataTypes.InvalidState(0);
    }
}

contract RejectingEditorialSystemAdapter is IEditorialSystemAdapter {
    function validateEditorialReference(bytes32, AVADataTypes.Role, AVADataTypes.Action, bytes32, string calldata, address)
        external
        pure
    {
        revert AVADataTypes.InvalidState(0);
    }
}

contract RejectingResidualEditorialAuthorityModule is IResidualEditorialAuthorityModule {
    AVADataTypes.Action public blockedAction;

    constructor(AVADataTypes.Action blockedAction_) {
        blockedAction = blockedAction_;
    }

    function validateResidualEditorialAuthority(ResidualEditorialAuthorityContext calldata context) external view {
        if (context.action == blockedAction) revert AVADataTypes.InvalidState(uint256(context.action));
    }
}

contract Actor {
    bytes32 private constant DEFAULT_WORKFLOW = keccak256("default-review-workflow");

    function assignRole(
        RoleIdentityRegistry registry,
        address account,
        AVADataTypes.Role role,
        bytes32 subjectId,
        string calldata metadataURI
    ) external {
        registry.assignRole(account, role, subjectId, metadataURI);
    }

    function setPermission(AuthorityMatrix matrix, AVADataTypes.Role role, AVADataTypes.Action action, bool permitted)
        external
    {
        matrix.setPermission(role, action, permitted);
    }

    function registerEvidenceReceipt(
        EvidenceCommitmentRegistry registry,
        AVADataTypes.Role actingRole,
        bytes32 commitment,
        string calldata uri,
        string calldata evidenceType,
        uint256 disclosurePolicyId
    ) external returns (uint256) {
        return registry.registerEvidenceReceipt(actingRole, DEFAULT_WORKFLOW, commitment, uri, evidenceType, disclosurePolicyId);
    }

    function registerEvidenceReceipt(
        EvidenceCommitmentRegistry registry,
        AVADataTypes.Role actingRole,
        bytes32 workflowKey,
        bytes32 commitment,
        string calldata uri,
        string calldata evidenceType,
        uint256 disclosurePolicyId
    ) external returns (uint256) {
        return registry.registerEvidenceReceipt(actingRole, workflowKey, commitment, uri, evidenceType, disclosurePolicyId);
    }

    function recordEvidenceLifecycleHook(
        EvidenceCommitmentRegistry registry,
        AVADataTypes.Role actingRole,
        bytes32 workflowKey,
        uint256 evidenceReceiptId,
        AVADataTypes.EvidenceLifecycleKind kind,
        uint256 replacementEvidenceReceiptId,
        bytes32 lifecycleReference,
        string calldata uri
    ) external returns (uint256) {
        return registry.recordEvidenceLifecycleHook(
            actingRole, workflowKey, evidenceReceiptId, kind, replacementEvidenceReceiptId, lifecycleReference, uri
        );
    }

    function registerManuscript(
        AVAStateMachine stateMachine,
        AVADataTypes.Role actingRole,
        bytes32 offchainRef,
        string calldata uri
    ) external returns (uint256) {
        return stateMachine.registerManuscript(actingRole, offchainRef, uri);
    }

    function registerReviewContribution(
        AVAStateMachine stateMachine,
        AVADataTypes.Role actingRole,
        uint256 manuscriptId,
        bytes32 reviewerSubjectId,
        uint256 evidenceReceiptId,
        uint256 disclosurePolicyId
    ) external returns (uint256) {
        return stateMachine.registerReviewContribution(
            actingRole, manuscriptId, reviewerSubjectId, evidenceReceiptId, disclosurePolicyId
        );
    }

    function registerReviewContributionWithWorkflow(
        AVAStateMachine stateMachine,
        AVADataTypes.Role actingRole,
        bytes32 workflowKey,
        uint256 manuscriptId,
        bytes32 reviewerSubjectId,
        uint256 evidenceReceiptId,
        uint256 disclosurePolicyId
    ) external returns (uint256) {
        return stateMachine.registerReviewContribution(
            actingRole, workflowKey, manuscriptId, reviewerSubjectId, evidenceReceiptId, disclosurePolicyId
        );
    }

    function provisionallyRecogniseReview(
        AVAStateMachine stateMachine,
        AVADataTypes.Role actingRole,
        uint256 reviewContributionId,
        bytes32 authorityId
    ) external returns (uint256) {
        return stateMachine.provisionallyRecogniseReview(actingRole, reviewContributionId, authorityId);
    }

    function fileChallenge(
        AVAStateMachine stateMachine,
        AVADataTypes.Role actingRole,
        uint256 challengedRecognisedStateId,
        bytes32 challengerSubjectId,
        uint256 evidenceReceiptId,
        uint256 disclosurePolicyId
    ) external returns (uint256) {
        return stateMachine.fileChallenge(
            actingRole, challengedRecognisedStateId, challengerSubjectId, evidenceReceiptId, disclosurePolicyId
        );
    }

    function fileChallenge(
        AVAStateMachine stateMachine,
        AVADataTypes.Role actingRole,
        bytes32 workflowKey,
        uint256 challengedRecognisedStateId,
        bytes32 challengerSubjectId,
        uint256 evidenceReceiptId,
        uint256 disclosurePolicyId
    ) external returns (uint256) {
        return stateMachine.fileChallenge(
            actingRole, workflowKey, challengedRecognisedStateId, challengerSubjectId, evidenceReceiptId, disclosurePolicyId
        );
    }

    function resolveChallenge(
        AVAStateMachine stateMachine,
        AVADataTypes.Role actingRole,
        uint256 challengeId,
        AVADataTypes.ChallengeOutcome outcome,
        AVADataTypes.RecognisedStateStatus toStatus,
        bytes32 authorityId,
        string calldata reasonURI
    ) external {
        stateMachine.resolveChallenge(actingRole, challengeId, outcome, toStatus, authorityId, reasonURI);
    }

    function screenChallenge(
        AVAStateMachine stateMachine,
        AVADataTypes.Role actingRole,
        uint256 challengeId,
        bytes32 authorityId
    ) external {
        stateMachine.screenChallenge(actingRole, challengeId, authorityId);
    }

    function applyRestoration(
        AVAStateMachine stateMachine,
        AVADataTypes.Role actingRole,
        uint256 challengeId,
        bytes32 authorityId,
        string calldata reasonURI
    ) external {
        stateMachine.applyRestoration(actingRole, challengeId, authorityId, reasonURI);
    }

    function closeChallenge(
        AVAStateMachine stateMachine,
        AVADataTypes.Role actingRole,
        uint256 challengeId,
        bytes32 authorityId,
        string calldata reasonURI
    ) external {
        stateMachine.closeChallenge(actingRole, challengeId, authorityId, reasonURI);
    }

    function recordAnonymousChallengeProofUse(
        DisclosureAccessExecutor executor,
        AVADataTypes.Role actingRole,
        uint256 challengeId,
        uint256 disclosurePolicyId,
        uint256 proofReceiptId,
        bytes32 subjectCommitment,
        bytes32 nullifierHash,
        string calldata uri
    ) external returns (uint256) {
        return executor.recordAnonymousChallengeProofUse(
            actingRole, challengeId, disclosurePolicyId, proofReceiptId, subjectCommitment, nullifierHash, uri
        );
    }

    function recordStandingUpdate(
        StandingRegistry registry,
        AVADataTypes.Role actingRole,
        uint256 recognisedStateId,
        bytes32 subjectId,
        string calldata dimension,
        int256 delta,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256) {
        return registry.recordStandingUpdate(
            actingRole, recognisedStateId, subjectId, dimension, delta, evidenceReceiptId, authorityId, uri
        );
    }

    function recordAuthorityApproval(
        AuthorityApprovalRegistry registry,
        AVADataTypes.Role actingRole,
        AuthorityApprovalRegistry.ApprovalInput calldata input
    ) external returns (uint256) {
        return registry.recordApproval(actingRole, input);
    }

    function executeAllocation(
        AllocationExecutor executor,
        AVADataTypes.Role actingRole,
        uint256 recognisedStateId,
        AVADataTypes.AllocationKind allocationKind,
        bytes32 subjectId,
        uint256 amountOrUnits,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256) {
        return executor.executeAllocation(
            actingRole, recognisedStateId, allocationKind, subjectId, amountOrUnits, evidenceReceiptId, authorityId, uri
        );
    }

    function registerStandingInput(
        StandingRegistry registry,
        AVADataTypes.Role actingRole,
        uint256 recognisedStateId,
        bytes32 subjectId,
        string calldata dimension,
        string calldata uri
    ) external returns (uint256) {
        return registry.registerStandingInput(actingRole, recognisedStateId, subjectId, dimension, uri);
    }

    function registerConsequence(
        ConsequenceExecutor executor,
        AVADataTypes.Role actingRole,
        uint256 recognisedStateId,
        AVADataTypes.ConsequenceKind kind,
        bytes32 subjectId,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256) {
        return executor.registerConsequence(
            actingRole, recognisedStateId, kind, subjectId, evidenceReceiptId, authorityId, uri
        );
    }

    function registerStandingFormula(
        StandingFormulaRegistry registry,
        AVADataTypes.Role actingRole,
        IStandingFormulaRegistry.StandingFormulaInput calldata input
    ) external returns (uint256) {
        return registry.registerStandingFormula(actingRole, input);
    }

    function registerSourceSetCommitment(
        StandingFormulaRegistry registry,
        AVADataTypes.Role actingRole,
        IStandingFormulaRegistry.SourceSetCommitmentInput calldata input
    ) external returns (uint256) {
        return registry.registerSourceSetCommitment(actingRole, input);
    }

    function registerSourceSetCompletenessAttestation(
        StandingFormulaRegistry registry,
        AVADataTypes.Role actingRole,
        IStandingFormulaRegistry.SourceSetCompletenessAttestationInput calldata input
    ) external returns (uint256) {
        return registry.registerSourceSetCompletenessAttestation(actingRole, input);
    }

    function registerStandingComputationStatement(
        StandingFormulaRegistry registry,
        AVADataTypes.Role actingRole,
        IStandingFormulaRegistry.StandingComputationStatementInput calldata input
    ) external returns (uint256) {
        return registry.registerStandingComputationStatement(actingRole, input);
    }

    function supersedeStandingComputationStatement(
        StandingFormulaRegistry registry,
        AVADataTypes.Role actingRole,
        uint256 oldStatementId,
        IStandingFormulaRegistry.StandingComputationStatementInput calldata input
    ) external returns (uint256) {
        return registry.supersedeStandingComputationStatement(actingRole, oldStatementId, input);
    }

    function invalidateStandingComputationStatement(
        StandingFormulaRegistry registry,
        AVADataTypes.Role actingRole,
        uint256 statementId,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string calldata uri
    ) external {
        registry.invalidateStandingComputationStatement(
            actingRole, statementId, evidenceReceiptId, authorityId, uri
        );
    }

    function issueZKStandingCredential(
        ZKStandingCredentialRegistry registry,
        AVADataTypes.Role actingRole,
        IZKStandingCredentialIssuer.ZKStandingCredentialInput calldata input
    ) external returns (uint256) {
        return registry.issueCredential(actingRole, input);
    }

    function revokeZKStandingCredential(
        ZKStandingCredentialRegistry registry,
        AVADataTypes.Role actingRole,
        uint256 credentialId,
        bytes32 subjectCommitment,
        bytes32 authorityId,
        string calldata uri
    ) external {
        registry.revokeCredential(actingRole, credentialId, subjectCommitment, authorityId, uri);
    }

    function supersedeZKStandingCredential(
        ZKStandingCredentialRegistry registry,
        AVADataTypes.Role actingRole,
        uint256 credentialId,
        IZKStandingCredentialIssuer.ZKStandingCredentialInput calldata input
    ) external returns (uint256) {
        return registry.supersedeCredential(actingRole, credentialId, input);
    }

    function recordSettlementBoundZKStandingCredentialSuspension(
        ZKStandingCredentialRegistry registry,
        AVADataTypes.Role actingRole,
        uint256 credentialId,
        AVADataTypes.StandingRelevantSettlementKind kind,
        AVADataTypes.ExecutionSourceType sourceType,
        uint256 sourceRecordId,
        uint256 settlementId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256) {
        return registry.recordSettlementBoundSuspension(
            actingRole, credentialId, kind, sourceType, sourceRecordId, settlementId, authorityId, uri
        );
    }

    function recordChallengeBoundZKStandingCredentialSuspension(
        ZKStandingCredentialRegistry registry,
        AVADataTypes.Role actingRole,
        uint256 credentialId,
        uint256 challengeTransitionId,
        bytes32 authorityId,
        string calldata uri
    ) external returns (uint256) {
        return registry.recordChallengeTransitionBoundSuspension(
            actingRole, credentialId, challengeTransitionId, authorityId, uri
        );
    }
}

contract AVASkeletonTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    RoleIdentityRegistry roleRegistry;
    AuthorityMatrix authorityMatrix;
    DefaultDisclosurePolicyModule disclosurePolicyModule;
    EvidenceCommitmentRegistry evidenceRegistry;
    DisclosurePolicyRegistry disclosureRegistry;
    AVAStateMachine stateMachine;
    AVARulePackageRegistry rulePackageRegistry;
    DefaultAttributionModule attributionModule;
    DefaultVerificationModule verificationModule;
    DefaultTransitionRuleModule transitionRuleModule;
    DefaultAllocationAdapter allocationAdapter;
    DefaultConsequenceAdapter consequenceAdapter;
    DefaultStandingAdapter standingAdapter;
    DefaultRewardAdapter rewardAdapter;
    DefaultPriorityAdapter priorityAdapter;
    DefaultPenaltyAdapter penaltyAdapter;
    DefaultRestorationAdapter restorationAdapter;
    DefaultChallengeLifecycleModule challengeLifecycleModule;
    DefaultEvidencePolicyModule evidencePolicyModule;
    DefaultAuditAdapter auditAdapter;
    DefaultEditorialSystemAdapter editorialSystemAdapter;
    DefaultResidualEditorialAuthorityModule residualEditorialAuthorityModule;
    DefaultFieldPolicyModule fieldPolicyModule;
    DefaultAntiAbuseModule antiAbuseModule;
    DefaultValueExecutionAdapter valueExecutionAdapter;
    DefaultStandingComputationModule standingComputationModule;
    DefaultRulePackageLifecycleModule rulePackageLifecycleModule;
    DefaultEvidenceLifecycleModule evidenceLifecycleModule;
    DefaultDisclosureLifecycleModule disclosureLifecycleModule;
    ConsequenceExecutor consequenceExecutor;
    StandingRegistry standingRegistry;
    StandingCredentialRegistry standingCredentialRegistry;
    StandingFormulaRegistry standingFormulaRegistry;
    AllocationExecutor allocationExecutor;
    AttestationAuditModule auditModule;
    ZKProofRegistry zkProofRegistry;
    ZKStandingComputationRegistry zkStandingComputationRegistry;
    ZKStandingCredentialRegistry zkStandingCredentialRegistry;
    DefaultDisclosureExecutionModule disclosureExecutionModule;
    ValueSettlementExecutor valueSettlementExecutor;
    DisclosureAccessExecutor disclosureAccessExecutor;
    ExternalOperationRegistry externalOperationRegistry;
    AuthorityApprovalRegistry authorityApprovalRegistry;

    Actor reviewerActor;
    Actor challengerActor;
    Actor outsiderActor;

    bytes32 constant REVIEWER_SUBJECT = keccak256("reviewer-subject");
    bytes32 constant CHALLENGER_SUBJECT = keccak256("challenger-subject");
    bytes32 constant EDITOR_AUTHORITY = keccak256("editor-authority");
    bytes32 constant DEFAULT_WORKFLOW = keccak256("default-review-workflow");
    uint256 constant BN254_GROUP_ORDER =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    struct M102DoubleBlindReviewContext {
        bytes32 workflowKey;
        uint256 packageId;
        uint256 evidenceId;
        uint256 reviewContributionId;
        uint256 recognisedStateId;
        DoubleBlindDisclosureModule module;
    }

    struct M103AnonymousChallengeContext {
        bytes32 workflowKey;
        uint256 packageId;
        uint256 policyId;
        bytes32 subjectCommitment;
        uint256 recognisedStateId;
        uint256 challengeId;
        ZKBackedDisclosureModule module;
        Actor challenger;
    }

    struct M104CorrectionRestorationContext {
        bytes32 workflowKey;
        uint256 packageId;
        uint256 recognisedStateId;
        uint256 challengeId;
        uint256 challengeEvidenceId;
    }

    struct ApprovalAuthorityContext {
        bytes32 workflowKey;
        uint256 packageId;
        uint256 recognisedStateId;
        uint256 challengeId;
        uint256 challengeEvidenceId;
        bytes32 objectId;
    }

    function setUp() public {
        roleRegistry = new RoleIdentityRegistry();
        authorityMatrix = new AuthorityMatrix(roleRegistry);
        disclosureRegistry = new DisclosurePolicyRegistry(authorityMatrix);
        disclosurePolicyModule = new DefaultDisclosurePolicyModule(disclosureRegistry);
        rulePackageRegistry = new AVARulePackageRegistry(authorityMatrix, disclosureRegistry);
        evidenceRegistry = new EvidenceCommitmentRegistry(authorityMatrix, disclosurePolicyModule, rulePackageRegistry);
        authorityApprovalRegistry =
            new AuthorityApprovalRegistry(authorityMatrix, rulePackageRegistry, evidenceRegistry);
        attributionModule = new DefaultAttributionModule();
        verificationModule = new DefaultVerificationModule();
        transitionRuleModule = new DefaultTransitionRuleModule();
        allocationAdapter = new DefaultAllocationAdapter();
        consequenceAdapter = new DefaultConsequenceAdapter();
        standingAdapter = new DefaultStandingAdapter();
        rewardAdapter = new DefaultRewardAdapter();
        priorityAdapter = new DefaultPriorityAdapter();
        penaltyAdapter = new DefaultPenaltyAdapter();
        restorationAdapter = new DefaultRestorationAdapter();
        challengeLifecycleModule = new DefaultChallengeLifecycleModule();
        evidencePolicyModule = new DefaultEvidencePolicyModule();
        auditAdapter = new DefaultAuditAdapter();
        editorialSystemAdapter = new DefaultEditorialSystemAdapter();
        residualEditorialAuthorityModule = new DefaultResidualEditorialAuthorityModule();
        fieldPolicyModule = new DefaultFieldPolicyModule();
        antiAbuseModule = new DefaultAntiAbuseModule();
        valueExecutionAdapter = new DefaultValueExecutionAdapter();
        standingComputationModule = new DefaultStandingComputationModule();
        rulePackageLifecycleModule = new DefaultRulePackageLifecycleModule();
        evidenceLifecycleModule = new DefaultEvidenceLifecycleModule();
        disclosureLifecycleModule = new DefaultDisclosureLifecycleModule(disclosureRegistry);
        stateMachine =
            new AVAStateMachine(authorityMatrix, disclosurePolicyModule, rulePackageRegistry, evidenceRegistry, DEFAULT_WORKFLOW);
        consequenceExecutor = new ConsequenceExecutor(authorityMatrix, stateMachine, rulePackageRegistry, evidenceRegistry);
        standingRegistry = new StandingRegistry(authorityMatrix, stateMachine, rulePackageRegistry, evidenceRegistry);
        standingFormulaRegistry = new StandingFormulaRegistry(authorityMatrix, rulePackageRegistry, evidenceRegistry);
        allocationExecutor = new AllocationExecutor(authorityMatrix, stateMachine, rulePackageRegistry, evidenceRegistry);
        valueSettlementExecutor =
            new ValueSettlementExecutor(authorityMatrix, allocationExecutor, consequenceExecutor);
        standingCredentialRegistry = new StandingCredentialRegistry(
            authorityMatrix,
            stateMachine,
            evidenceRegistry,
            standingRegistry,
            allocationExecutor,
            consequenceExecutor,
            valueSettlementExecutor
        );
        auditModule = new AttestationAuditModule(authorityMatrix, rulePackageRegistry, evidenceRegistry, stateMachine);
        zkProofRegistry = new ZKProofRegistry(new SchnorrDisclosureProofVerifier(), rulePackageRegistry, disclosureRegistry);
        zkStandingComputationRegistry =
            new ZKStandingComputationRegistry(
                new SchnorrDisclosureProofVerifier(), rulePackageRegistry, standingFormulaRegistry
            );
        zkStandingCredentialRegistry = new ZKStandingCredentialRegistry(
            authorityMatrix, zkStandingComputationRegistry, valueSettlementExecutor, stateMachine
        );
        disclosureExecutionModule = new DefaultDisclosureExecutionModule();
        disclosureAccessExecutor = new DisclosureAccessExecutor(
            authorityMatrix,
            rulePackageRegistry,
            evidenceRegistry,
            disclosureRegistry,
            stateMachine,
            zkProofRegistry,
            disclosureExecutionModule
        );
        externalOperationRegistry = new ExternalOperationRegistry(
            authorityMatrix, stateMachine, evidenceRegistry, allocationExecutor, consequenceExecutor
        );

        reviewerActor = new Actor();
        challengerActor = new Actor();
        outsiderActor = new Actor();

        roleRegistry.assignRole(address(reviewerActor), AVADataTypes.Role.Reviewer, REVIEWER_SUBJECT, "ipfs://reviewer");
        roleRegistry.assignRole(
            address(challengerActor), AVADataTypes.Role.Challenger, CHALLENGER_SUBJECT, "ipfs://challenger"
        );
        roleRegistry.assignRole(address(this), AVADataTypes.Role.Author, keccak256("author-subject"), "ipfs://author");
        roleRegistry.assignRole(address(this), AVADataTypes.Role.Editor, EDITOR_AUTHORITY, "ipfs://editor");
        roleRegistry.assignRole(address(this), AVADataTypes.Role.Panel, keccak256("panel-authority"), "ipfs://panel");
        roleRegistry.assignRole(
            address(this), AVADataTypes.Role.ProtocolExecutor, keccak256("executor-authority"), "ipfs://executor"
        );

        authorityMatrix.setPermission(AVADataTypes.Role.Author, AVADataTypes.Action.RegisterManuscript, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Reviewer, AVADataTypes.Action.RegisterEvidence, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Challenger, AVADataTypes.Action.RegisterEvidence, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Editor, AVADataTypes.Action.RegisterDisclosurePolicy, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Editor, AVADataTypes.Action.RegisterRecognisedState, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Reviewer, AVADataTypes.Action.RegisterReviewContribution, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Editor, AVADataTypes.Action.ProvisionallyRecogniseReview, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Editor, AVADataTypes.Action.OpenChallengeWindow, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Challenger, AVADataTypes.Action.FileChallenge, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Editor, AVADataTypes.Action.ScreenChallenge, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Panel, AVADataTypes.Action.ResolveChallenge, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Panel, AVADataTypes.Action.ApplyRestoration, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Panel, AVADataTypes.Action.CloseChallenge, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Panel, AVADataTypes.Action.RegisterConsequence, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Editor, AVADataTypes.Action.RegisterStandingInput, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Panel, AVADataTypes.Action.RecordStandingUpdate, true);
        authorityMatrix.setPermission(AVADataTypes.Role.ProtocolExecutor, AVADataTypes.Action.ExecuteAllocation, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Panel, AVADataTypes.Action.RecordAttestation, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Panel, AVADataTypes.Action.TransitionRecognisedState, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Panel, AVADataTypes.Action.RegisterRulePackage, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Panel, AVADataTypes.Action.RecordDisclosureLifecycle, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Reviewer, AVADataTypes.Action.RecordEvidenceLifecycle, true);
        authorityMatrix.setPermission(AVADataTypes.Role.ProtocolExecutor, AVADataTypes.Action.ExecuteValueSettlement, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Panel, AVADataTypes.Action.RecordDisclosureExecution, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Challenger, AVADataTypes.Action.RecordDisclosureExecution, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Panel, AVADataTypes.Action.RecordExternalOperation, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Panel, AVADataTypes.Action.IssueStandingCredential, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Panel, AVADataTypes.Action.RevokeStandingCredential, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Panel, AVADataTypes.Action.SupersedeStandingCredential, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Panel, AVADataTypes.Action.RecordStandingCredentialSettlement, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Panel, AVADataTypes.Action.RegisterStandingFormula, true);
        authorityMatrix.setPermission(
            AVADataTypes.Role.Panel, AVADataTypes.Action.RegisterSourceSetCompletenessAttestation, true
        );
        authorityMatrix.setPermission(
            AVADataTypes.Role.Panel, AVADataTypes.Action.RegisterStandingComputationStatement, true
        );
        authorityMatrix.setPermission(
            AVADataTypes.Role.Panel, AVADataTypes.Action.SupersedeStandingComputationStatement, true
        );
        authorityMatrix.setPermission(
            AVADataTypes.Role.Panel, AVADataTypes.Action.InvalidateStandingComputationStatement, true
        );
        rulePackageRegistry.configureMigrationReferenceReaders(
            AVADataTypes.Role.Panel,
            IRecognisedStateReader(address(stateMachine)),
            IEvidenceReceiptReader(address(evidenceRegistry)),
            keccak256("panel-authority")
        );
        _registerDefaultRulePackage(DEFAULT_WORKFLOW, "ipfs://default-workflow");
    }

    function testSkeletonContractsDeploy() public {
        require(address(roleRegistry) != address(0), "role registry missing");
        require(address(authorityMatrix) != address(0), "authority matrix missing");
        require(address(evidenceRegistry) != address(0), "evidence registry missing");
        require(address(disclosureRegistry) != address(0), "disclosure registry missing");
        require(address(stateMachine) != address(0), "state machine missing");
        require(address(consequenceExecutor) != address(0), "consequence executor missing");
        require(address(standingRegistry) != address(0), "standing registry missing");
        require(address(standingFormulaRegistry) != address(0), "standing formula registry missing");
        require(address(allocationExecutor) != address(0), "allocation executor missing");
        require(address(auditModule) != address(0), "audit module missing");
        require(address(zkStandingComputationRegistry) != address(0), "zk standing registry missing");
        require(address(zkStandingCredentialRegistry) != address(0), "zk standing credential registry missing");
    }

    function testRulePackageRegisteredEventEmitsExpectedModulesHash() public {
        bytes32 workflowKey = keccak256("event-modules-hash-workflow");
        AVARulePackageRegistry.RulePackageModules memory modules = AVARulePackageRegistry.RulePackageModules({
            attributionModule: attributionModule,
            verificationModule: verificationModule,
            allocationModule: allocationAdapter,
            transitionRuleModule: transitionRuleModule,
            disclosureModule: disclosurePolicyModule,
            standingAdapter: standingAdapter,
            consequenceAdapter: consequenceAdapter,
            rewardAdapter: rewardAdapter,
            priorityAdapter: priorityAdapter,
            penaltyAdapter: penaltyAdapter,
            restorationAdapter: restorationAdapter,
            challengeLifecycleModule: challengeLifecycleModule,
            evidencePolicyModule: evidencePolicyModule,
            auditAdapter: auditAdapter,
            editorialSystemAdapter: editorialSystemAdapter,
                residualEditorialAuthorityModule: residualEditorialAuthorityModule,
            fieldPolicyModule: fieldPolicyModule,
            antiAbuseModule: antiAbuseModule,
                valueExecutionAdapter: valueExecutionAdapter,
                standingComputationModule: standingComputationModule,
                rulePackageLifecycleModule: rulePackageLifecycleModule,
                evidenceLifecycleModule: evidenceLifecycleModule,
                disclosureLifecycleModule: disclosureLifecycleModule,
                disclosureExecutionModule: disclosureExecutionModule,
                version: 1,
                compatibilityKey: keccak256("ava-m4-10-compatible"),
                dependencyURI: "",
                deprecated: false
        });
        bytes32 addressOnlyHash = keccak256(abi.encode(modules));
        bytes32 expectedModulesHash = rulePackageRegistry.hashModules(modules);
        bytes32 expectedModulesCodeHash = rulePackageRegistry.hashModuleCodeIdentities(modules);
        require(expectedModulesHash != addressOnlyHash, "modules hash is address-only");

        vm.recordLogs();
        rulePackageRegistry.registerRulePackage(AVADataTypes.Role.Panel, workflowKey, modules, "ipfs://event-workflow");
        AVARulePackageRegistry.RulePackage memory registeredPackage = rulePackageRegistry.getRulePackage(workflowKey);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 eventTopic = keccak256("RulePackageRegistered(bytes32,bytes32,string,address)");
        bytes32 authorityEventTopic = keccak256("RulePackageAuthorityBound(bytes32,uint256,bytes32,address)");
        bool found;
        bool foundAuthority;
        for (uint256 i = 0; i < entries.length; i++) {
            if (
                entries[i].emitter == address(rulePackageRegistry) && entries[i].topics.length == 2
                    && entries[i].topics[0] == eventTopic && entries[i].topics[1] == workflowKey
            ) {
                (bytes32 modulesHash, string memory uri, address registeredBy) =
                    abi.decode(entries[i].data, (bytes32, string, address));
                require(modulesHash == expectedModulesHash, "wrong modules hash");
                require(keccak256(bytes(uri)) == keccak256("ipfs://event-workflow"), "wrong uri");
                require(registeredBy == address(this), "wrong registeredBy");
                found = true;
            }
            if (
                entries[i].emitter == address(rulePackageRegistry) && entries[i].topics.length == 4
                    && entries[i].topics[0] == authorityEventTopic && entries[i].topics[1] == workflowKey
                    && uint256(entries[i].topics[2]) == registeredPackage.packageId
                    && entries[i].topics[3] == keccak256("panel-authority")
            ) {
                address registeredBy = abi.decode(entries[i].data, (address));
                require(registeredBy == address(this), "wrong authority registeredBy");
                foundAuthority = true;
            }
        }
        require(found, "RulePackageRegistered event missing");
        require(foundAuthority, "RulePackageAuthorityBound event missing");
        require(registeredPackage.modulesHash == expectedModulesHash, "stored modules hash wrong");
        require(registeredPackage.modulesCodeHash == expectedModulesCodeHash, "stored modules code hash wrong");
        require(registeredPackage.authorityId == keccak256("panel-authority"), "rule package authority missing");
    }

    function testRulePackageRegistrationRejectsNoCodeModuleAddress() public {
        bytes32 workflowKey = keccak256("event-no-code-module-workflow");
        AVARulePackageRegistry.RulePackageModules memory modules = _defaultRulePackageModules();
        modules.attributionModule = IAttributionModule(address(0x1234));

        try rulePackageRegistry.registerRulePackage(AVADataTypes.Role.Panel, workflowKey, modules, "ipfs://no-code-module") {
            revert("rule package accepted no-code module");
        } catch {}
    }

    function testAdminCanAssignRoleScopedSubject() public {
        AVADataTypes.RoleSubject memory subject = roleRegistry.getSubject(REVIEWER_SUBJECT);

        require(subject.account == address(reviewerActor), "wrong account");
        require(subject.role == AVADataTypes.Role.Reviewer, "wrong role");
        require(subject.active, "subject inactive");
        require(roleRegistry.hasRole(address(reviewerActor), AVADataTypes.Role.Reviewer), "role not assigned");
    }

    function testNonAdminCannotAssignRolesOrConfigureAuthority() public {
        try outsiderActor.assignRole(
            roleRegistry, address(outsiderActor), AVADataTypes.Role.Author, keccak256("bad-subject"), "ipfs://bad"
        ) {
            revert("non-admin assigned role");
        } catch {}

        try outsiderActor.setPermission(
            authorityMatrix, AVADataTypes.Role.Reviewer, AVADataTypes.Action.RegisterConsequence, true
        ) {
            revert("non-admin configured authority");
        } catch {}
    }

    function testAuthorisedRoleCanRegisterCoreObjects() public {
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("sealed-review-evidence"),
            "ipfs://encrypted-review",
            "review-service-occurrence",
            0
        );

        AVADataTypes.EvidenceReceipt memory receipt = evidenceRegistry.getEvidenceReceipt(evidenceId);
        require(receipt.commitment == keccak256("sealed-review-evidence"), "wrong evidence commitment");
        require(receipt.packageId == rulePackageRegistry.getRulePackage(DEFAULT_WORKFLOW).packageId, "wrong evidence package");
        require(receipt.registeredRole == AVADataTypes.Role.Reviewer, "wrong evidence role");
        require(receipt.registeredSubjectId == REVIEWER_SUBJECT, "wrong evidence subject");
        require(receipt.registeredBy == address(reviewerActor), "wrong evidence actor");
        uint256 policyId = disclosureRegistry.registerDisclosurePolicy(
            AVADataTypes.Role.Editor, "editor-visible-sealed-content", "ipfs://policy"
        );
        AVADataTypes.DisclosurePolicy memory policy = disclosureRegistry.getDisclosurePolicy(policyId);
        require(policy.authorityRole == AVADataTypes.Role.Editor, "wrong disclosure authority role");
        require(policy.authorityId == EDITOR_AUTHORITY, "wrong disclosure authority subject");
        uint256 manuscriptId = _registerAuthorManuscript();
        AVADataTypes.ManuscriptRecord memory manuscript = stateMachine.getManuscript(manuscriptId);
        require(manuscript.registeredRole == AVADataTypes.Role.Author, "wrong manuscript role");
        require(manuscript.registeredSubjectId == keccak256("author-subject"), "wrong manuscript subject");

        uint256 stateId = stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Attribution,
            bytes32(manuscriptId),
            manuscript.registeredSubjectId,
            evidenceId,
            policyId,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        );

        AVADataTypes.RecognisedStateRecord memory state = stateMachine.getRecognisedState(stateId);
        require(state.stage == AVADataTypes.AVAStage.Attribution, "wrong AVA stage");
        require(state.subjectId == manuscript.registeredSubjectId, "wrong recognised-state subject");
        require(state.status == AVADataTypes.RecognisedStateStatus.Registered, "wrong state status");
    }

    function testZeroDisclosurePolicyRemainsAcceptedWhereUnspecified() public {
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("zero-policy-evidence"),
            "ipfs://zero-policy-evidence",
            "review-service-occurrence",
            0
        );
        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 reviewContributionId = reviewerActor.registerReviewContribution(
            stateMachine, AVADataTypes.Role.Reviewer, manuscriptId, REVIEWER_SUBJECT, evidenceId, 0
        );
        uint256 recognisedStateId = stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            keccak256("zero-policy-state"),
            REVIEWER_SUBJECT,
            evidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        );

        AVADataTypes.EvidenceReceipt memory receipt = evidenceRegistry.getEvidenceReceipt(evidenceId);
        AVADataTypes.ReviewContributionRecord memory review = stateMachine.getReviewContribution(reviewContributionId);
        AVADataTypes.RecognisedStateRecord memory state = stateMachine.getRecognisedState(recognisedStateId);
        require(receipt.disclosurePolicyId == 0, "zero evidence policy changed");
        require(review.disclosurePolicyId == 0, "zero review policy changed");
        require(state.disclosurePolicyId == 0, "zero state policy changed");
        require(state.subjectId == REVIEWER_SUBJECT, "zero policy state lost subject");
    }

    function testReviewContributionRejectsUnknownManuscriptId() public {
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("unknown-manuscript-review-evidence"),
            "ipfs://unknown-manuscript-review-evidence",
            "review-service-occurrence",
            0
        );
        uint256 unknownManuscriptId = stateMachine.nextManuscriptId() + 100;
        uint256 nextReviewContributionId = stateMachine.nextReviewContributionId();

        try reviewerActor.registerReviewContribution(
            stateMachine, AVADataTypes.Role.Reviewer, unknownManuscriptId, REVIEWER_SUBJECT, evidenceId, 0
        ) {
            revert("review accepted unknown manuscript");
        } catch {}

        require(stateMachine.nextReviewContributionId() == nextReviewContributionId, "unknown manuscript created review");
    }

    function testEvidenceReceiptRejectsEmptyEvidenceType() public {
        uint256 nextEvidenceId = evidenceRegistry.nextEvidenceReceiptId();

        try reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("empty-evidence-type"),
            "ipfs://empty-evidence-type",
            "",
            0
        ) {
            revert("evidence accepted empty type");
        } catch {}

        require(evidenceRegistry.nextEvidenceReceiptId() == nextEvidenceId, "empty type created evidence");
    }

    function testUnknownDisclosurePolicyReferencesAreRejectedWhereSupplied() public {
        uint256 unknownPolicyId = disclosureRegistry.nextDisclosurePolicyId() + 100;
        uint256 nextEvidenceId = evidenceRegistry.nextEvidenceReceiptId();

        try reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("unknown-policy-evidence"),
            "ipfs://unknown-policy-evidence",
            "review-service-occurrence",
            unknownPolicyId
        ) {
            revert("evidence accepted unknown disclosure policy");
        } catch {}
        require(evidenceRegistry.nextEvidenceReceiptId() == nextEvidenceId, "unknown policy created evidence");

        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("known-zero-policy-evidence"),
            "ipfs://known-zero-policy-evidence",
            "review-service-occurrence",
            0
        );
        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 nextReviewContributionId = stateMachine.nextReviewContributionId();

        try reviewerActor.registerReviewContribution(
            stateMachine, AVADataTypes.Role.Reviewer, manuscriptId, REVIEWER_SUBJECT, evidenceId, unknownPolicyId
        ) {
            revert("review accepted unknown disclosure policy");
        } catch {}
        require(stateMachine.nextReviewContributionId() == nextReviewContributionId, "unknown policy created review");

        uint256 nextRecognisedStateId = stateMachine.nextRecognisedStateId();

        try stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            keccak256("unknown-policy-state"),
            REVIEWER_SUBJECT,
            evidenceId,
            unknownPolicyId,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        ) {
            revert("recognised state accepted unknown disclosure policy");
        } catch {}
        require(stateMachine.nextRecognisedStateId() == nextRecognisedStateId, "unknown policy created state");

        uint256 challengeableStateId = _createChallengeableReviewState();
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256("unknown-policy-challenge-evidence"),
            "ipfs://unknown-policy-challenge-evidence",
            "review-quality-challenge",
            0
        );
        uint256 nextChallengeId = stateMachine.nextChallengeId();

        try challengerActor.fileChallenge(
            stateMachine,
            AVADataTypes.Role.Challenger,
            challengeableStateId,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            unknownPolicyId
        ) {
            revert("challenge accepted unknown disclosure policy");
        } catch {}

        require(stateMachine.nextChallengeId() == nextChallengeId, "unknown policy created challenge");
    }

    function testAlternativeDisclosureModuleCanBeSwappedWithoutChangingRecognisedStateSubstrate() public {
        uint256 blockedPolicyId = disclosureRegistry.registerDisclosurePolicy(
            AVADataTypes.Role.Editor, "blocked-by-module", "ipfs://blocked-policy"
        );
        MockDisclosurePolicyModule mockDisclosureModule = new MockDisclosurePolicyModule(blockedPolicyId);
        AVARulePackageRegistry swappedRulePackageRegistry = new AVARulePackageRegistry(authorityMatrix, disclosureRegistry);
        swappedRulePackageRegistry.registerRulePackage(
            AVADataTypes.Role.Panel,
            DEFAULT_WORKFLOW,
            AVARulePackageRegistry.RulePackageModules({
                attributionModule: attributionModule,
                verificationModule: verificationModule,
                allocationModule: allocationAdapter,
                transitionRuleModule: transitionRuleModule,
                disclosureModule: mockDisclosureModule,
                standingAdapter: standingAdapter,
                consequenceAdapter: consequenceAdapter,
                rewardAdapter: rewardAdapter,
                priorityAdapter: priorityAdapter,
                penaltyAdapter: penaltyAdapter,
                restorationAdapter: restorationAdapter,
                challengeLifecycleModule: challengeLifecycleModule,
                evidencePolicyModule: evidencePolicyModule,
                auditAdapter: auditAdapter,
                editorialSystemAdapter: editorialSystemAdapter,
                residualEditorialAuthorityModule: residualEditorialAuthorityModule,
                fieldPolicyModule: fieldPolicyModule,
                antiAbuseModule: antiAbuseModule,
                valueExecutionAdapter: valueExecutionAdapter,
                standingComputationModule: standingComputationModule,
                rulePackageLifecycleModule: rulePackageLifecycleModule,
                evidenceLifecycleModule: evidenceLifecycleModule,
                disclosureLifecycleModule: disclosureLifecycleModule,
                disclosureExecutionModule: disclosureExecutionModule,
                version: 1,
                compatibilityKey: keccak256("ava-m4-10-compatible"),
                dependencyURI: "",
                deprecated: false
            }),
            "ipfs://swapped-disclosure-workflow"
        );
        EvidenceCommitmentRegistry swappedEvidenceRegistry =
            new EvidenceCommitmentRegistry(authorityMatrix, mockDisclosureModule, swappedRulePackageRegistry);
        AVAStateMachine swappedStateMachine =
            new AVAStateMachine(
                authorityMatrix, mockDisclosureModule, swappedRulePackageRegistry, swappedEvidenceRegistry, DEFAULT_WORKFLOW
            );

        try reviewerActor.registerEvidenceReceipt(
            swappedEvidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("blocked-policy-evidence"),
            "ipfs://blocked-policy-evidence",
            "review-service-occurrence",
            blockedPolicyId
        ) {
            revert("mock disclosure module did not block evidence");
        } catch {}

        uint256 allowedEvidenceId = reviewerActor.registerEvidenceReceipt(
            swappedEvidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("allowed-policy-evidence"),
            "ipfs://allowed-policy-evidence",
            "review-service-occurrence",
            0
        );
        uint256 manuscriptId = swappedStateMachine.registerManuscript(
            AVADataTypes.Role.Author, keccak256("swapped-manuscript"), "ipfs://m"
        );
        uint256 reviewContributionId = reviewerActor.registerReviewContribution(
            swappedStateMachine, AVADataTypes.Role.Reviewer, manuscriptId, REVIEWER_SUBJECT, allowedEvidenceId, 0
        );

        AVADataTypes.ReviewContributionRecord memory review =
            swappedStateMachine.getReviewContribution(reviewContributionId);
        require(review.status == AVADataTypes.ReviewContributionStatus.Submitted, "swapped substrate changed");
        require(review.disclosurePolicyId == 0, "swapped disclosure policy wrong");
        require(standingRegistry.nextStandingInputId() == 1, "swapped disclosure created standing");
        require(consequenceExecutor.nextConsequenceId() == 1, "swapped disclosure created consequence");
    }

    function testUnauthorisedCallerCannotRegisterGovernedObjects() public {
        try outsiderActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("outsider-evidence"),
            "ipfs://outsider",
            "challenge",
            0
        ) {
            revert("outsider registered evidence");
        } catch {}

        try outsiderActor.registerManuscript(
            stateMachine, AVADataTypes.Role.Author, keccak256("outsider-manuscript"), "ipfs://outsider-manuscript"
        ) {
            revert("outsider registered manuscript");
        } catch {}
    }

    function testRawReviewAndChallengeDoNotCreateStandingRewardOrSanction() public {
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("raw-review-receipt"),
            "ipfs://raw-review",
            "raw-review-submission",
            0
        );

        require(evidenceId == 1, "raw review receipt not registered");
        require(standingRegistry.nextStandingInputId() == 1, "standing was created from raw review");
        require(consequenceExecutor.nextConsequenceId() == 1, "consequence was created from raw review");

        roleRegistry.assignRole(
            address(this), AVADataTypes.Role.Challenger, keccak256("local-challenger"), "ipfs://local"
        );
        authorityMatrix.setPermission(AVADataTypes.Role.Challenger, AVADataTypes.Action.RegisterEvidence, true);
        uint256 challengeReceiptId = evidenceRegistry.registerEvidenceReceipt(
            AVADataTypes.Role.Challenger, keccak256("raw-challenge-receipt"), "ipfs://raw-challenge", "raw-challenge", 0
        );

        require(challengeReceiptId == 2, "raw challenge receipt not registered");
        require(standingRegistry.nextStandingInputId() == 1, "standing was created from raw challenge");
        require(consequenceExecutor.nextConsequenceId() == 1, "sanction or reward was created from raw challenge");
    }

    function testReviewReceiptCanBecomeChallengeableRecognisedStateWithoutStandingOrReward() public {
        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 disclosurePolicyId = disclosureRegistry.registerDisclosurePolicy(
            AVADataTypes.Role.Editor, "editor-visible-sealed-review", "ipfs://review-policy"
        );
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("sealed-review-bundle"),
            "ipfs://encrypted-review-bundle",
            "review-service-occurrence",
            disclosurePolicyId
        );

        uint256 reviewContributionId = reviewerActor.registerReviewContribution(
            stateMachine, AVADataTypes.Role.Reviewer, manuscriptId, REVIEWER_SUBJECT, evidenceId, disclosurePolicyId
        );
        AVADataTypes.ReviewContributionRecord memory submittedReview =
            stateMachine.getReviewContribution(reviewContributionId);
        require(submittedReview.status == AVADataTypes.ReviewContributionStatus.Submitted, "review not submitted");
        require(submittedReview.recognisedStateId == 0, "raw review created recognised state");
        require(standingRegistry.nextStandingInputId() == 1, "raw review created standing");
        require(consequenceExecutor.nextConsequenceId() == 1, "raw review created consequence");

        uint256 recognisedStateId =
            stateMachine.provisionallyRecogniseReview(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);
        AVADataTypes.RecognisedStateRecord memory provisionalState = stateMachine.getRecognisedState(recognisedStateId);
        require(
            provisionalState.stage == AVADataTypes.AVAStage.Verification, "review recognition bypassed verification"
        );
        require(
            provisionalState.status == AVADataTypes.RecognisedStateStatus.Provisional, "review state not provisional"
        );
        require(provisionalState.subjectId == REVIEWER_SUBJECT, "review state lost reviewer subject");

        stateMachine.openReviewChallengeWindow(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);
        AVADataTypes.ReviewContributionRecord memory challengeableReview =
            stateMachine.getReviewContribution(reviewContributionId);
        AVADataTypes.RecognisedStateRecord memory challengeableState =
            stateMachine.getRecognisedState(recognisedStateId);
        require(
            challengeableReview.status == AVADataTypes.ReviewContributionStatus.ChallengeWindowOpen,
            "review challenge window not open"
        );
        require(
            challengeableState.status == AVADataTypes.RecognisedStateStatus.Challengeable,
            "recognised state not challengeable"
        );
        require(challengeableState.subjectId == REVIEWER_SUBJECT, "challenge window rewrote reviewer subject");
        require(standingRegistry.nextStandingInputId() == 1, "challengeable state created standing");
        require(consequenceExecutor.nextConsequenceId() == 1, "challengeable state created consequence");
    }

    function testReviewerCannotProvisionallyRecogniseOwnReview() public {
        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("self-review-bundle"),
            "ipfs://self-review",
            "review-service-occurrence",
            0
        );
        uint256 reviewContributionId = reviewerActor.registerReviewContribution(
            stateMachine, AVADataTypes.Role.Reviewer, manuscriptId, REVIEWER_SUBJECT, evidenceId, 0
        );

        try reviewerActor.provisionallyRecogniseReview(
            stateMachine, AVADataTypes.Role.Reviewer, reviewContributionId, EDITOR_AUTHORITY
        ) {
            revert("reviewer recognised own review");
        } catch {}
    }

    function testChallengeCorrectionAndRestorationPathKeepsConsequencesBounded() public {
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256("sealed-challenge-evidence"),
            "ipfs://sealed-challenge",
            "review-quality-challenge",
            0
        );

        uint256 challengeId = challengerActor.fileChallenge(
            stateMachine, AVADataTypes.Role.Challenger, recognisedStateId, CHALLENGER_SUBJECT, challengeEvidenceId, 0
        );
        AVADataTypes.ChallengeRecord memory filedChallenge = stateMachine.getChallenge(challengeId);
        require(filedChallenge.status == AVADataTypes.ChallengeLifecycleStatus.ConcernFiled, "challenge not filed");
        require(filedChallenge.outcome == AVADataTypes.ChallengeOutcome.None, "raw challenge has outcome");
        require(filedChallenge.lastTransitionId == 0, "raw challenge created transition");
        require(consequenceExecutor.nextConsequenceId() == 1, "raw challenge created sanction");
        AVADataTypes.RecognisedStateRecord memory unchangedState = stateMachine.getRecognisedState(recognisedStateId);
        require(
            unchangedState.status == AVADataTypes.RecognisedStateStatus.Challengeable, "raw challenge mutated state"
        );

        stateMachine.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        AVADataTypes.ChallengeRecord memory screenedChallenge = stateMachine.getChallenge(challengeId);
        AVADataTypes.ChallengeTransitionRecord memory screenTransition =
            stateMachine.getChallengeTransition(screenedChallenge.lastTransitionId);
        require(
            screenedChallenge.status == AVADataTypes.ChallengeLifecycleStatus.AdmissibilityScreening,
            "challenge not screened"
        );
        require(
            screenTransition.transitionKind == AVADataTypes.ChallengeTransitionKind.AdmissibilityScreened,
            "screen transition missing"
        );
        require(screenTransition.createdAt == block.timestamp, "screen transition timestamp missing");
        require(
            screenTransition.fromStatus == AVADataTypes.RecognisedStateStatus.Challengeable, "screen from state wrong"
        );
        require(screenTransition.toStatus == AVADataTypes.RecognisedStateStatus.Challengeable, "screen mutated state");

        stateMachine.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            keccak256("panel-authority"),
            "ipfs://upheld-reason"
        );

        AVADataTypes.ChallengeRecord memory upheldChallenge = stateMachine.getChallenge(challengeId);
        AVADataTypes.RecognisedStateRecord memory correctedState = stateMachine.getRecognisedState(recognisedStateId);
        AVADataTypes.ChallengeTransitionRecord memory resolveTransition =
            stateMachine.getChallengeTransition(upheldChallenge.lastTransitionId);
        require(upheldChallenge.status == AVADataTypes.ChallengeLifecycleStatus.Resolved, "challenge not resolved");
        require(upheldChallenge.outcome == AVADataTypes.ChallengeOutcome.Upheld, "challenge not upheld");
        require(
            resolveTransition.transitionKind == AVADataTypes.ChallengeTransitionKind.OutcomeResolved,
            "resolve transition missing"
        );
        require(resolveTransition.outcome == AVADataTypes.ChallengeOutcome.Upheld, "transition outcome wrong");
        require(resolveTransition.fromStatus == AVADataTypes.RecognisedStateStatus.Challengeable, "resolve from wrong");
        require(resolveTransition.toStatus == AVADataTypes.RecognisedStateStatus.Downgraded, "resolve to wrong");
        require(resolveTransition.createdAt == block.timestamp, "resolve transition timestamp missing");
        require(correctedState.status == AVADataTypes.RecognisedStateStatus.Downgraded, "state not corrected");
        require(consequenceExecutor.nextConsequenceId() == 1, "upheld challenge auto-executed consequence");
        require(standingRegistry.nextStandingInputId() == 1, "upheld challenge auto-created standing");
    }

    function testGoodFaithRejectedChallengeCanRestoreTargetWithoutSanction() public {
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256("good-faith-challenge-evidence"),
            "ipfs://good-faith",
            "review-quality-challenge",
            0
        );
        uint256 challengeId = challengerActor.fileChallenge(
            stateMachine, AVADataTypes.Role.Challenger, recognisedStateId, CHALLENGER_SUBJECT, challengeEvidenceId, 0
        );

        stateMachine.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        stateMachine.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://good-faith-rejection"
        );
        AVADataTypes.ChallengeRecord memory resolvedChallenge = stateMachine.getChallenge(challengeId);
        require(resolvedChallenge.status == AVADataTypes.ChallengeLifecycleStatus.Resolved, "challenge not resolved");
        require(resolvedChallenge.outcome == AVADataTypes.ChallengeOutcome.RejectedGoodFaith, "wrong outcome");
        stateMachine.applyRestoration(
            AVADataTypes.Role.Panel, challengeId, keccak256("panel-authority"), "ipfs://restoration-reason"
        );

        AVADataTypes.ChallengeRecord memory challenge = stateMachine.getChallenge(challengeId);
        AVADataTypes.RecognisedStateRecord memory restoredState = stateMachine.getRecognisedState(recognisedStateId);
        AVADataTypes.ChallengeTransitionRecord memory restorationTransition =
            stateMachine.getChallengeTransition(challenge.lastTransitionId);
        require(
            challenge.status == AVADataTypes.ChallengeLifecycleStatus.RestorationApplied, "restoration not applied"
        );
        require(
            restorationTransition.transitionKind == AVADataTypes.ChallengeTransitionKind.RestorationRecorded,
            "restoration transition missing"
        );
        require(restoredState.status == AVADataTypes.RecognisedStateStatus.Restored, "target not restored");
        require(consequenceExecutor.nextConsequenceId() == 1, "good-faith rejection created sanction");
    }

    function testChallengeResolutionCannotDirectlyRestoreWithoutRestorationTransition() public {
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256("direct-restore-challenge-evidence"),
            "ipfs://direct-restore",
            "review-quality-challenge",
            0
        );
        uint256 challengeId = challengerActor.fileChallenge(
            stateMachine, AVADataTypes.Role.Challenger, recognisedStateId, CHALLENGER_SUBJECT, challengeEvidenceId, 0
        );
        stateMachine.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);

        uint256 nextChallengeTransitionId = stateMachine.nextChallengeTransitionId();
        uint256 nextRecognisedStateTransitionId = stateMachine.nextRecognisedStateTransitionId();
        try stateMachine.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Restored,
            keccak256("panel-authority"),
            "ipfs://direct-restore-resolution"
        ) {
            revert("challenge resolution directly restored state");
        } catch {}

        require(
            stateMachine.getRecognisedState(recognisedStateId).status == AVADataTypes.RecognisedStateStatus.Challengeable,
            "failed direct restoration mutated state"
        );
        require(
            stateMachine.nextChallengeTransitionId() == nextChallengeTransitionId,
            "failed direct restoration wrote challenge transition"
        );
        require(
            stateMachine.nextRecognisedStateTransitionId() == nextRecognisedStateTransitionId,
            "failed direct restoration wrote state transition"
        );
    }

    function testChallengerCannotResolveOwnChallenge() public {
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256("self-resolve-challenge"),
            "ipfs://self-resolve",
            "review-quality-challenge",
            0
        );
        uint256 challengeId = challengerActor.fileChallenge(
            stateMachine, AVADataTypes.Role.Challenger, recognisedStateId, CHALLENGER_SUBJECT, challengeEvidenceId, 0
        );
        stateMachine.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);

        try challengerActor.resolveChallenge(
            stateMachine,
            AVADataTypes.Role.Challenger,
            challengeId,
            AVADataTypes.ChallengeOutcome.MaliciousOrFabricated,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("challenger-authority"),
            "ipfs://bad-resolution"
        ) {
            revert("challenger resolved own challenge");
        } catch {}
        require(consequenceExecutor.nextConsequenceId() == 1, "unauthorised resolve created sanction");
    }

    function testResolverCannotResolveChallengeAgainstOwnRecognisedStateSubject() public {
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("resolver-subject-conflict-state"),
            "ipfs://resolver-subject-conflict-state",
            "subject-conflict-state",
            0
        );
        uint256 recognisedStateId = stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            keccak256("resolver-subject-conflict-object"),
            keccak256("panel-authority"),
            evidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Challengeable
        );
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256("resolver-subject-conflict-challenge"),
            "ipfs://resolver-subject-conflict-challenge",
            "review-quality-challenge",
            0
        );
        uint256 challengeId = challengerActor.fileChallenge(
            stateMachine, AVADataTypes.Role.Challenger, recognisedStateId, CHALLENGER_SUBJECT, challengeEvidenceId, 0
        );
        stateMachine.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);

        try stateMachine.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            keccak256("panel-authority"),
            "ipfs://resolver-subject-conflict-rejected"
        ) {
            revert("resolver resolved challenge against own state subject");
        } catch {}

        Actor distinctPanel = new Actor();
        bytes32 distinctPanelAuthority = keccak256("distinct-panel-authority");
        roleRegistry.assignRole(address(distinctPanel), AVADataTypes.Role.Panel, distinctPanelAuthority, "ipfs://distinct-panel");
        distinctPanel.resolveChallenge(
            stateMachine,
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            distinctPanelAuthority,
            "ipfs://resolver-subject-conflict-resolved"
        );
        require(
            stateMachine.getRecognisedState(recognisedStateId).status == AVADataTypes.RecognisedStateStatus.Downgraded,
            "distinct panel resolver failed"
        );
    }

    function testRawChallengeCannotTargetRawReviewSubmission() public {
        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 reviewEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("raw-review-only"),
            "ipfs://raw-review-only",
            "review-service-occurrence",
            0
        );
        uint256 reviewContributionId = reviewerActor.registerReviewContribution(
            stateMachine, AVADataTypes.Role.Reviewer, manuscriptId, REVIEWER_SUBJECT, reviewEvidenceId, 0
        );
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256("challenge-against-raw-review"),
            "ipfs://challenge-against-raw-review",
            "review-quality-challenge",
            0
        );

        try challengerActor.fileChallenge(
            stateMachine, AVADataTypes.Role.Challenger, reviewContributionId, CHALLENGER_SUBJECT, challengeEvidenceId, 0
        ) {
            revert("raw review was challengeable");
        } catch {}
    }

    function testEditorCanScreenButCannotResolveChallenge() public {
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256("editor-screen-evidence"),
            "ipfs://editor-screen",
            "review-quality-challenge",
            0
        );
        uint256 challengeId = challengerActor.fileChallenge(
            stateMachine, AVADataTypes.Role.Challenger, recognisedStateId, CHALLENGER_SUBJECT, challengeEvidenceId, 0
        );

        stateMachine.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        try stateMachine.resolveChallenge(
            AVADataTypes.Role.Editor,
            challengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            EDITOR_AUTHORITY,
            "ipfs://editor-resolution"
        ) {
            revert("editor resolved challenge");
        } catch {}
    }

    function testChallengeOutcomesRemainDistinctWithoutAutomaticConsequences() public {

        uint256 goodFaithChallengeId = _fileAndScreenChallenge("good-faith-distinct");
        stateMachine.resolveChallenge(
            AVADataTypes.Role.Panel,
            goodFaithChallengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://good-faith"
        );

        uint256 negligentChallengeId = _fileAndScreenChallenge("negligent-distinct");
        stateMachine.resolveChallenge(
            AVADataTypes.Role.Panel,
            negligentChallengeId,
            AVADataTypes.ChallengeOutcome.Negligent,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://negligent"
        );

        uint256 maliciousChallengeId = _fileAndScreenChallenge("malicious-distinct");
        stateMachine.resolveChallenge(
            AVADataTypes.Role.Panel,
            maliciousChallengeId,
            AVADataTypes.ChallengeOutcome.MaliciousOrFabricated,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://malicious"
        );

        require(
            stateMachine.getChallenge(goodFaithChallengeId).outcome == AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            "good faith collapsed"
        );
        require(
            stateMachine.getChallenge(negligentChallengeId).outcome == AVADataTypes.ChallengeOutcome.Negligent,
            "negligent collapsed"
        );
        require(
            stateMachine.getChallenge(maliciousChallengeId).outcome
                == AVADataTypes.ChallengeOutcome.MaliciousOrFabricated,
            "malicious collapsed"
        );
        require(consequenceExecutor.nextConsequenceId() == 1, "outcome auto-executed consequence");
        require(standingRegistry.nextStandingInputId() == 1, "outcome auto-created standing");
    }

    function testUnauthorisedCallerCannotRestoreOrCloseChallenge() public {
        uint256 challengeId = _fileAndScreenChallenge("restore-close-auth");
        stateMachine.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://restore-close"
        );

        try outsiderActor.applyRestoration(
            stateMachine, AVADataTypes.Role.Panel, challengeId, keccak256("outsider"), "ipfs://outsider-restore"
        ) {
            revert("outsider restored challenge");
        } catch {}

        try outsiderActor.closeChallenge(
            stateMachine, AVADataTypes.Role.Panel, challengeId, keccak256("outsider"), "ipfs://outsider-close"
        ) {
            revert("outsider closed challenge");
        } catch {}
    }

    function testAuthorisedPanelCanRecordProceduralStandingUpdateFromRecognisedState() public {
        (uint256 recognisedStateId, uint256 evidenceId) = _createDowngradedRecognisedState();

        uint256 standingUpdateId = standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            "review-procedure-weight",
            -1,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://standing-update"
        );

        AVADataTypes.StandingUpdateRecord memory update = standingRegistry.getStandingUpdate(standingUpdateId);
        require(update.recognisedStateId == recognisedStateId, "standing update target wrong");
        require(update.subjectId == REVIEWER_SUBJECT, "standing update subject wrong");
        require(update.delta == -1, "standing update delta wrong");
        require(update.authorityRole == AVADataTypes.Role.Panel, "standing authority role wrong");
        require(consequenceExecutor.nextConsequenceId() == 1, "standing update created consequence");
        require(allocationExecutor.nextAllocationExecutionId() == 1, "standing update executed allocation");
    }

    function testUnauthorisedCallerCannotRecordStandingUpdateOrExecuteAllocation() public {
        (uint256 recognisedStateId, uint256 evidenceId) = _createDowngradedRecognisedState();

        try outsiderActor.recordStandingUpdate(
            standingRegistry,
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            "review-procedure-weight",
            1,
            evidenceId,
            keccak256("outsider"),
            "ipfs://outsider-standing"
        ) {
            revert("outsider recorded standing update");
        } catch {}

        try outsiderActor.executeAllocation(
            allocationExecutor,
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            AVADataTypes.AllocationKind.OperationalAllowance,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("outsider"),
            "ipfs://outsider-allocation"
        ) {
            revert("outsider executed allocation");
        } catch {}
    }

    function testStandingAndAllocationRejectRawIdsAndProvisionalState() public {


        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("standing-raw-review"),
            "ipfs://standing-raw-review",
            "review-service-occurrence",
            0
        );
        uint256 reviewContributionId = reviewerActor.registerReviewContribution(
            stateMachine, AVADataTypes.Role.Reviewer, manuscriptId, REVIEWER_SUBJECT, evidenceId, 0
        );

        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            reviewContributionId,
            REVIEWER_SUBJECT,
            "review-procedure-weight",
            1,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://standing-from-raw-review"
        ) {
            revert("standing accepted raw review id");
        } catch {}

        uint256 provisionalStateId =
            stateMachine.provisionallyRecogniseReview(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);
        try allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            provisionalStateId,
            AVADataTypes.AllocationKind.OperationalAllowance,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://allocation-from-provisional"
        ) {
            revert("allocation accepted provisional state");
        } catch {}

        uint256 challengeableStateId = _createChallengeableReviewState();
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256("standing-raw-challenge"),
            "ipfs://standing-raw-challenge",
            "review-quality-challenge",
            0
        );
        challengerActor.fileChallenge(
            stateMachine, AVADataTypes.Role.Challenger, challengeableStateId, CHALLENGER_SUBJECT, challengeEvidenceId, 0
        );
        challengerActor.fileChallenge(
            stateMachine, AVADataTypes.Role.Challenger, challengeableStateId, CHALLENGER_SUBJECT, challengeEvidenceId, 0
        );
        uint256 rawChallengeId = challengerActor.fileChallenge(
            stateMachine, AVADataTypes.Role.Challenger, challengeableStateId, CHALLENGER_SUBJECT, challengeEvidenceId, 0
        );

        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            rawChallengeId,
            CHALLENGER_SUBJECT,
            "challenge-procedure-weight",
            -1,
            challengeEvidenceId,
            keccak256("panel-authority"),
            "ipfs://standing-from-raw-challenge"
        ) {
            revert("standing accepted raw challenge-like id");
        } catch {}

        try allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            rawChallengeId,
            AVADataTypes.AllocationKind.OperationalAllowance,
            CHALLENGER_SUBJECT,
            1,
            challengeEvidenceId,
            keccak256("executor-authority"),
            "ipfs://allocation-from-raw-challenge"
        ) {
            revert("allocation accepted raw challenge-like id");
        } catch {}
    }

    function testStandingAndAllocationRejectAllDisallowedRecognisedStateStatuses() public {

        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("disallowed-status-evidence"),
            "ipfs://disallowed-status",
            "status-boundary",
            0
        );

        _assertStandingAndAllocationRejectTarget(0, evidenceId);
        _assertStandingAndAllocationRejectTarget(
            _registerRecognisedStateForStatus(AVADataTypes.RecognisedStateStatus.Draft, evidenceId, "draft-status"),
            evidenceId
        );
        _assertStandingAndAllocationRejectTarget(
            _registerRecognisedStateForStatus(
                AVADataTypes.RecognisedStateStatus.Registered, evidenceId, "registered-status"
            ),
            evidenceId
        );
        _assertStandingAndAllocationRejectTarget(
            _registerRecognisedStateForStatus(
                AVADataTypes.RecognisedStateStatus.Provisional, evidenceId, "provisional-status"
            ),
            evidenceId
        );
        _assertStandingAndAllocationRejectTarget(
            _registerRecognisedStateForStatus(
                AVADataTypes.RecognisedStateStatus.Challengeable, evidenceId, "challengeable-status"
            ),
            evidenceId
        );
        _assertStandingAndAllocationRejectTarget(
            _registerRecognisedStateForStatus(AVADataTypes.RecognisedStateStatus.Frozen, evidenceId, "frozen-status"),
            evidenceId
        );
    }

    function testStandingAndAllocationRejectZeroRequiredFields() public {

        (uint256 standingStateId, uint256 evidenceId) = _createDowngradedRecognisedState();
        uint256 allocationStateId = _registerRecognisedStateForStatus(
            AVADataTypes.RecognisedStateStatus.Vested, evidenceId, "vested-allocation"
        );

        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            standingStateId,
            REVIEWER_SUBJECT,
            "review-procedure-weight",
            1,
            0,
            keccak256("panel-authority"),
            "ipfs://zero-evidence"
        ) {
            revert("standing accepted zero evidence");
        } catch {}

        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            standingStateId,
            REVIEWER_SUBJECT,
            "review-procedure-weight",
            1,
            evidenceId,
            bytes32(0),
            "ipfs://zero-authority"
        ) {
            revert("standing accepted zero authority");
        } catch {}

        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            standingStateId,
            bytes32(0),
            "review-procedure-weight",
            1,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://zero-subject"
        ) {
            revert("standing accepted zero subject");
        } catch {}

        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            standingStateId,
            REVIEWER_SUBJECT,
            "",
            1,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://empty-dimension"
        ) {
            revert("standing accepted empty dimension");
        } catch {}

        try allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            allocationStateId,
            AVADataTypes.AllocationKind.None,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://none-kind"
        ) {
            revert("allocation accepted none kind");
        } catch {}

        try allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            allocationStateId,
            AVADataTypes.AllocationKind.OperationalAllowance,
            bytes32(0),
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://zero-subject"
        ) {
            revert("allocation accepted zero subject");
        } catch {}

        try allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            allocationStateId,
            AVADataTypes.AllocationKind.OperationalAllowance,
            REVIEWER_SUBJECT,
            0,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://zero-units"
        ) {
            revert("allocation accepted zero units");
        } catch {}

        try allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            allocationStateId,
            AVADataTypes.AllocationKind.OperationalAllowance,
            REVIEWER_SUBJECT,
            1,
            0,
            keccak256("executor-authority"),
            "ipfs://zero-evidence"
        ) {
            revert("allocation accepted zero evidence");
        } catch {}

        try allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            allocationStateId,
            AVADataTypes.AllocationKind.OperationalAllowance,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            bytes32(0),
            "ipfs://zero-authority"
        ) {
            revert("allocation accepted zero authority");
        } catch {}
    }

    function testStandingAllocationAndConsequenceRejectUnregisteredEvidenceReferences() public {

        (uint256 standingStateId, uint256 registeredEvidenceId) = _createDowngradedRecognisedState();
        uint256 allocationStateId = _registerRecognisedStateForStatus(
            AVADataTypes.RecognisedStateStatus.Vested, registeredEvidenceId, "unregistered-evidence-allocation"
        );
        uint256 missingEvidenceId = evidenceRegistry.nextEvidenceReceiptId() + 100;

        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            standingStateId,
            REVIEWER_SUBJECT,
            "review-procedure-weight",
            1,
            missingEvidenceId,
            keccak256("panel-authority"),
            "ipfs://missing-evidence-standing"
        ) {
            revert("standing accepted unregistered evidence");
        } catch {}

        try allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            allocationStateId,
            AVADataTypes.AllocationKind.OperationalAllowance,
            REVIEWER_SUBJECT,
            1,
            missingEvidenceId,
            keccak256("executor-authority"),
            "ipfs://missing-evidence-allocation"
        ) {
            revert("allocation accepted unregistered evidence");
        } catch {}

        try consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            standingStateId,
            AVADataTypes.ConsequenceKind.AdministrativeNote,
            REVIEWER_SUBJECT,
            missingEvidenceId,
            keccak256("panel-authority"),
            "ipfs://missing-evidence-consequence"
        ) {
            revert("consequence accepted unregistered evidence");
        } catch {}

        require(standingRegistry.nextStandingUpdateId() == 1, "standing recorded missing evidence");
        require(allocationExecutor.nextAllocationExecutionId() == 1, "allocation recorded missing evidence");
        require(consequenceExecutor.nextConsequenceId() == 1, "consequence recorded missing evidence");
    }

    function testDirectRegistrationRejectsDownstreamEligibleRecognisedStates() public {
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("direct-high-state-evidence"),
            "ipfs://direct-high-state",
            "state-boundary",
            0
        );

        _assertDirectHighStatusRegistrationRejected(AVADataTypes.RecognisedStateStatus.Vested, evidenceId);
        _assertDirectHighStatusRegistrationRejected(AVADataTypes.RecognisedStateStatus.Restored, evidenceId);
        _assertDirectHighStatusRegistrationRejected(AVADataTypes.RecognisedStateStatus.Downgraded, evidenceId);
        _assertDirectHighStatusRegistrationRejected(AVADataTypes.RecognisedStateStatus.Voided, evidenceId);
        require(stateMachine.nextRecognisedStateId() == 1, "direct high-status registration created state");
    }

    function testUnsafeRecognisedStateOverloadSelectorIsAbsent() public view {
        _assertNoSelector(
            address(stateMachine), "registerRecognisedState(uint8,uint8,bytes32,uint256,uint256,bytes32,uint8)"
        );
    }

    function testTransitionGeneratedRecognisedStatesStillSupportDownstreamRecords() public {


        (uint256 downgradedStateId, uint256 evidenceId) = _createDowngradedRecognisedState();
        uint256 vestedStateId =
            _registerRecognisedStateForStatus(AVADataTypes.RecognisedStateStatus.Vested, evidenceId, "transition-vested");

        uint256 standingId = standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            downgradedStateId,
            REVIEWER_SUBJECT,
            "review-procedure-weight",
            -1,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://transition-standing"
        );
        uint256 consequenceId = consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            downgradedStateId,
            AVADataTypes.ConsequenceKind.ProcedureCorrection,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://transition-consequence"
        );
        uint256 allocationId = allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            vestedStateId,
            AVADataTypes.AllocationKind.OperationalAllowance,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://transition-allocation"
        );

        require(standingId == 1, "standing not recorded");
        require(consequenceId == 1, "consequence not recorded");
        require(allocationId == 1, "allocation not recorded");
    }

    function testRulePackageReRegistrationDoesNotRewriteExistingRecognisedStateDispatch() public {
        uint256 oldEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("package-version-evidence"),
            "ipfs://package-version-evidence",
            "package-version-basis",
            0
        );
        uint256 oldStateId = _registerRecognisedStateForStatus(
            AVADataTypes.RecognisedStateStatus.Vested, oldEvidenceId, "package-version-old-state"
        );
        uint256 oldPackageId = stateMachine.getRecognisedState(oldStateId).packageId;

        _registerRulePackageWithAdapters(
            DEFAULT_WORKFLOW,
            allocationAdapter,
            consequenceAdapter,
            new MockStandingAdapter("blocked-after-reregister"),
            rewardAdapter,
            priorityAdapter,
            penaltyAdapter,
            restorationAdapter,
            "ipfs://package-version-new-default"
        );
        uint256 newPackageId = rulePackageRegistry.getRulePackage(DEFAULT_WORKFLOW).packageId;
        require(newPackageId != oldPackageId, "workflow did not advance active package");

        uint256 newEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            keccak256("package-version-new-evidence"),
            "ipfs://package-version-new-evidence",
            "package-version-basis",
            0
        );
        uint256 newStateId = _registerRecognisedStateForStatus(
            AVADataTypes.RecognisedStateStatus.Vested, newEvidenceId, "package-version-new-state"
        );
        require(stateMachine.getRecognisedState(oldStateId).packageId == oldPackageId, "old state package changed");
        require(stateMachine.getRecognisedState(newStateId).packageId == newPackageId, "new state did not bind new package");

        uint256 standingId = standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            oldStateId,
            REVIEWER_SUBJECT,
            "blocked-after-reregister",
            1,
            oldEvidenceId,
            keccak256("panel-authority"),
            "ipfs://old-package-standing"
        );
        require(standingRegistry.getStandingUpdate(standingId).packageId == oldPackageId, "old standing package wrong");

        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            newStateId,
            REVIEWER_SUBJECT,
            "blocked-after-reregister",
            1,
            newEvidenceId,
            keccak256("panel-authority"),
            "ipfs://new-package-standing"
        ) {
            revert("new state did not dispatch through new package");
        } catch {}
    }

    function testChallengeUsesTargetRecognisedStatePackageAfterWorkflowReregistration() public {
        uint256 oldStateId = _createChallengeableReviewState();
        uint256 oldPackageId = stateMachine.getRecognisedState(oldStateId).packageId;

        _registerRulePackageWithLifecycle(
            DEFAULT_WORKFLOW,
            new RejectingChallengeLifecycleModule(AVADataTypes.Action.FileChallenge),
            "ipfs://reject-file-challenge-active-package"
        );
        uint256 newPackageId = rulePackageRegistry.getRulePackage(DEFAULT_WORKFLOW).packageId;
        require(newPackageId != oldPackageId, "active package did not change");

        uint256 oldChallengeEvidenceId = stateMachine.getRecognisedState(oldStateId).evidenceReceiptId;
        uint256 oldChallengeId = challengerActor.fileChallenge(
            stateMachine, AVADataTypes.Role.Challenger, oldStateId, CHALLENGER_SUBJECT, oldChallengeEvidenceId, 0
        );
        AVADataTypes.ChallengeRecord memory oldChallenge = stateMachine.getChallenge(oldChallengeId);
        require(oldChallenge.packageId == oldPackageId, "old challenge did not use target state package");

        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            DEFAULT_WORKFLOW,
            keccak256("target-package-challenge-evidence"),
            "ipfs://target-package-challenge",
            "review-quality-challenge",
            0
        );
        uint256 newStateId = _createChallengeableReviewState();
        uint256 nextChallengeId = stateMachine.nextChallengeId();
        try challengerActor.fileChallenge(
            stateMachine, AVADataTypes.Role.Challenger, newStateId, CHALLENGER_SUBJECT, challengeEvidenceId, 0
        ) {
            revert("new challenge ignored active target package lifecycle");
        } catch {}
        require(stateMachine.nextChallengeId() == nextChallengeId, "rejected new challenge was stored");
    }

    function testGenericTransitionRejectsCorrectionAndRestorationStatuses() public {
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("generic-transition-boundary-evidence"),
            "ipfs://generic-transition-boundary",
            "transition-boundary",
            0
        );
        uint256 registeredStateId = stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            keccak256("generic-transition-boundary-state"),
            REVIEWER_SUBJECT,
            evidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        );

        _assertGenericTransitionRejected(registeredStateId, AVADataTypes.RecognisedStateStatus.Downgraded);
        _assertGenericTransitionRejected(registeredStateId, AVADataTypes.RecognisedStateStatus.Voided);
        _assertGenericTransitionRejected(registeredStateId, AVADataTypes.RecognisedStateStatus.Restored);
        require(
            stateMachine.getRecognisedState(registeredStateId).status == AVADataTypes.RecognisedStateStatus.Registered,
            "generic rejection mutated state"
        );

        uint256 downgradedStateId = _registerRecognisedStateForStatus(
            AVADataTypes.RecognisedStateStatus.Downgraded, evidenceId, "generic-path-downgraded"
        );
        uint256 voidedStateId = _registerRecognisedStateForStatus(
            AVADataTypes.RecognisedStateStatus.Voided, evidenceId, "generic-path-voided"
        );
        uint256 restoredStateId = _registerRecognisedStateForStatus(
            AVADataTypes.RecognisedStateStatus.Restored, evidenceId, "generic-path-restored"
        );
        require(
            stateMachine.getRecognisedState(downgradedStateId).status == AVADataTypes.RecognisedStateStatus.Downgraded,
            "challenge downgrade path failed"
        );
        require(
            stateMachine.getRecognisedState(voidedStateId).status == AVADataTypes.RecognisedStateStatus.Voided,
            "challenge void path failed"
        );
        require(
            stateMachine.getRecognisedState(restoredStateId).status == AVADataTypes.RecognisedStateStatus.Restored,
            "restoration path failed"
        );
    }

    function testUnscopedEvidenceCannotEnterWorkflowReviewStateOrChallenge() public {
        roleRegistry.assignRole(address(this), AVADataTypes.Role.Reviewer, keccak256("m415-reviewer"), "ipfs://reviewer");
        uint256 legacyEvidenceId = evidenceRegistry.registerEvidenceReceipt(
            AVADataTypes.Role.Reviewer,
            keccak256("m415-unscoped-evidence"),
            "ipfs://m415-unscoped-evidence",
            "unscoped-evidence",
            0
        );
        require(
            evidenceRegistry.getEvidenceReceipt(legacyEvidenceId).workflowKey == bytes32(0),
            "legacy evidence unexpectedly scoped"
        );
        uint256 manuscriptId = _registerAuthorManuscript();

        try reviewerActor.registerReviewContribution(
            stateMachine, AVADataTypes.Role.Reviewer, manuscriptId, REVIEWER_SUBJECT, legacyEvidenceId, 0
        ) {
            revert("unscoped evidence created review contribution");
        } catch {}

        try stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            keccak256("m415-unscoped-state"),
            REVIEWER_SUBJECT,
            legacyEvidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        ) {
            revert("unscoped evidence created recognised state");
        } catch {}

        uint256 recognisedStateId = _createChallengeableReviewState();
        try challengerActor.fileChallenge(
            stateMachine,
            AVADataTypes.Role.Challenger,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            legacyEvidenceId,
            0
        ) {
            revert("unscoped evidence created challenge");
        } catch {}
    }

    function testCanonicalRoleSubjectRejectsSecondActiveAndAllowsAfterDeactivation() public {
        Actor roleActor = new Actor();
        bytes32 firstSubject = keccak256("canonical-first-reviewer");
        bytes32 secondSubject = keccak256("canonical-second-reviewer");
        roleRegistry.assignRole(address(roleActor), AVADataTypes.Role.Reviewer, firstSubject, "ipfs://first");

        try roleRegistry.assignRole(address(roleActor), AVADataTypes.Role.Reviewer, secondSubject, "ipfs://second") {
            revert("second active canonical subject assigned");
        } catch {}
        require(roleRegistry.subjectOf(address(roleActor), AVADataTypes.Role.Reviewer) == firstSubject, "canonical changed");
        require(roleRegistry.isSubjectFor(address(roleActor), AVADataTypes.Role.Reviewer, firstSubject), "first inactive");

        roleRegistry.deactivateSubject(firstSubject);
        require(!roleRegistry.hasRole(address(roleActor), AVADataTypes.Role.Reviewer), "role stayed active");
        require(
            roleRegistry.subjectOf(address(roleActor), AVADataTypes.Role.Reviewer) == bytes32(0),
            "canonical subject not cleared"
        );
        require(!roleRegistry.isSubjectFor(address(roleActor), AVADataTypes.Role.Reviewer, firstSubject), "old subject active");

        Actor otherActor = new Actor();
        try roleRegistry.assignRole(address(otherActor), AVADataTypes.Role.Reviewer, firstSubject, "ipfs://reuse") {
            revert("inactive subject id was reused");
        } catch {}

        roleRegistry.assignRole(address(roleActor), AVADataTypes.Role.Reviewer, secondSubject, "ipfs://second");
        require(roleRegistry.hasRole(address(roleActor), AVADataTypes.Role.Reviewer), "role not restored");
        require(
            roleRegistry.subjectOf(address(roleActor), AVADataTypes.Role.Reviewer) == secondSubject,
            "new canonical missing"
        );
        require(roleRegistry.isSubjectFor(address(roleActor), AVADataTypes.Role.Reviewer, secondSubject), "new subject inactive");
    }

    function testSelfClaimingPathsRejectSomeoneElsesRoleSubject() public {
        Actor secondReviewer = new Actor();
        Actor secondChallenger = new Actor();
        bytes32 secondReviewerSubject = keccak256("second-reviewer-subject");
        bytes32 secondChallengerSubject = keccak256("second-challenger-subject");
        roleRegistry.assignRole(address(secondReviewer), AVADataTypes.Role.Reviewer, secondReviewerSubject, "ipfs://r2");
        roleRegistry.assignRole(
            address(secondChallenger), AVADataTypes.Role.Challenger, secondChallengerSubject, "ipfs://c2"
        );

        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 reviewEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("subject-binding-review"),
            "ipfs://subject-binding-review",
            "review-service-occurrence",
            0
        );
        try secondReviewer.registerReviewContribution(
            stateMachine, AVADataTypes.Role.Reviewer, manuscriptId, REVIEWER_SUBJECT, reviewEvidenceId, 0
        ) {
            revert("reviewer used another reviewer subject");
        } catch {}
        require(stateMachine.nextReviewContributionId() == 1, "mismatched reviewer subject created review");

        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256("subject-binding-challenge"),
            "ipfs://subject-binding-challenge",
            "review-quality-challenge",
            0
        );
        try secondChallenger.fileChallenge(
            stateMachine, AVADataTypes.Role.Challenger, recognisedStateId, CHALLENGER_SUBJECT, challengeEvidenceId, 0
        ) {
            revert("challenger used another challenger subject");
        } catch {}
        require(stateMachine.nextChallengeId() == 1, "mismatched challenger subject created challenge");
    }

    function testDownstreamRecordsRejectUnknownOrInactiveTargetSubjects() public {
        (uint256 downgradedStateId, uint256 evidenceId) = _createDowngradedRecognisedState();
        uint256 vestedStateId =
            _registerRecognisedStateForStatus(AVADataTypes.RecognisedStateStatus.Vested, evidenceId, "subject-vested");
        bytes32 unknownSubject = keccak256("unknown-target-subject");
        bytes32 inactiveSubject = keccak256("inactive-target-subject");
        roleRegistry.assignRole(address(outsiderActor), AVADataTypes.Role.Reviewer, inactiveSubject, "ipfs://inactive");
        roleRegistry.deactivateSubject(inactiveSubject);

        uint256 nextRecognisedStateId = stateMachine.nextRecognisedStateId();
        try stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            keccak256("unknown-subject-state"),
            unknownSubject,
            evidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        ) {
            revert("recognised state accepted unknown subject");
        } catch {}
        try stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            keccak256("inactive-subject-state"),
            inactiveSubject,
            evidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        ) {
            revert("recognised state accepted inactive subject");
        } catch {}
        require(stateMachine.nextRecognisedStateId() == nextRecognisedStateId, "invalid subject created state");

        _assertDownstreamRejectsTargetSubject(downgradedStateId, vestedStateId, evidenceId, unknownSubject);
        _assertDownstreamRejectsTargetSubject(downgradedStateId, vestedStateId, evidenceId, inactiveSubject);
        require(standingRegistry.nextStandingUpdateId() == 1, "standing accepted invalid subject");
        require(allocationExecutor.nextAllocationExecutionId() == 1, "allocation accepted invalid subject");
        require(consequenceExecutor.nextConsequenceId() == 1, "consequence accepted invalid subject");
    }

    function testStandingAndConsequenceRejectActiveSubjectUnrelatedToRecognisedState() public {
        (uint256 downgradedStateId, uint256 evidenceId) = _createDowngradedRecognisedState();
        bytes32 otherReviewerSubject = keccak256("other-active-reviewer-subject");
        roleRegistry.assignRole(address(outsiderActor), AVADataTypes.Role.Reviewer, otherReviewerSubject, "ipfs://other-reviewer");
        require(
            stateMachine.getRecognisedState(downgradedStateId).subjectId == REVIEWER_SUBJECT,
            "test fixture state subject changed"
        );

        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            downgradedStateId,
            otherReviewerSubject,
            "review-procedure-weight",
            -1,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://wrong-state-subject-standing"
        ) {
            revert("standing update accepted unrelated active subject");
        } catch {}

        try consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            downgradedStateId,
            AVADataTypes.ConsequenceKind.ProcedureCorrection,
            otherReviewerSubject,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://wrong-state-subject-consequence"
        ) {
            revert("consequence accepted unrelated active subject");
        } catch {}

        try consequenceExecutor.recordPenalty(
            AVADataTypes.Role.Panel,
            downgradedStateId,
            otherReviewerSubject,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://wrong-state-subject-penalty"
        ) {
            revert("penalty consequence accepted unrelated active subject");
        } catch {}

        require(standingRegistry.nextStandingUpdateId() == 1, "standing update recorded unrelated subject");
        require(consequenceExecutor.nextConsequenceId() == 1, "consequence recorded unrelated subject");
    }

    function testAuthoritySubjectMismatchIsRejectedForAuthorityBoundActions() public {
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("authority-mismatch-evidence"),
            "ipfs://authority-mismatch",
            "authority-boundary",
            0
        );
        uint256 registeredStateId = stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            keccak256("authority-mismatch-state"),
            REVIEWER_SUBJECT,
            evidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        );
        (uint256 downgradedStateId,) = _createDowngradedRecognisedState();
        uint256 vestedStateId =
            _registerRecognisedStateForStatus(AVADataTypes.RecognisedStateStatus.Vested, evidenceId, "authority-vested");

        try stateMachine.transitionRecognisedState(
            AVADataTypes.Role.Panel,
            registeredStateId,
            AVADataTypes.RecognisedStateStatus.Vested,
            EDITOR_AUTHORITY,
            "ipfs://wrong-authority-transition"
        ) {
            revert("transition accepted mismatched authority");
        } catch {}

        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            downgradedStateId,
            REVIEWER_SUBJECT,
            "review-procedure-weight",
            1,
            evidenceId,
            EDITOR_AUTHORITY,
            "ipfs://wrong-authority-standing"
        ) {
            revert("standing accepted mismatched authority");
        } catch {}

        try allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            vestedStateId,
            AVADataTypes.AllocationKind.OperationalAllowance,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://wrong-authority-allocation"
        ) {
            revert("allocation accepted mismatched authority");
        } catch {}

        try consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            downgradedStateId,
            AVADataTypes.ConsequenceKind.AdministrativeNote,
            REVIEWER_SUBJECT,
            evidenceId,
            EDITOR_AUTHORITY,
            "ipfs://wrong-authority-consequence"
        ) {
            revert("consequence accepted mismatched authority");
        } catch {}
    }

    function testUnknownEvidenceIsRejectedBeforeReviewStateOrChallengeFormation() public {
        uint256 missingEvidenceId = evidenceRegistry.nextEvidenceReceiptId() + 100;
        uint256 manuscriptId = _registerAuthorManuscript();

        try reviewerActor.registerReviewContribution(
            stateMachine, AVADataTypes.Role.Reviewer, manuscriptId, REVIEWER_SUBJECT, missingEvidenceId, 0
        ) {
            revert("review accepted unknown evidence");
        } catch {}
        require(stateMachine.nextReviewContributionId() == 1, "unknown evidence created review");

        try stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            keccak256("unknown-evidence-state"),
            REVIEWER_SUBJECT,
            missingEvidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        ) {
            revert("recognised state accepted unknown evidence");
        } catch {}
        require(stateMachine.nextRecognisedStateId() == 1, "unknown evidence created recognised state");

        uint256 recognisedStateId = _createChallengeableReviewState();
        try challengerActor.fileChallenge(
            stateMachine, AVADataTypes.Role.Challenger, recognisedStateId, CHALLENGER_SUBJECT, missingEvidenceId, 0
        ) {
            revert("challenge accepted unknown evidence");
        } catch {}
        require(stateMachine.nextChallengeId() == 1, "unknown evidence created challenge");
    }

    function testWorkflowEvidenceCannotCrossStateOrDownstreamBoundaries() public {
        bytes32 foreignWorkflow = keccak256("foreign-evidence-workflow");
        _registerDefaultRulePackage(foreignWorkflow, "ipfs://foreign-evidence-workflow");
        uint256 foreignEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            foreignWorkflow,
            keccak256("foreign-evidence"),
            "ipfs://foreign-evidence",
            "foreign-workflow-evidence",
            0
        );
        uint256 manuscriptId = _registerAuthorManuscript();

        try reviewerActor.registerReviewContribution(
            stateMachine, AVADataTypes.Role.Reviewer, manuscriptId, REVIEWER_SUBJECT, foreignEvidenceId, 0
        ) {
            revert("review accepted foreign workflow evidence");
        } catch {}
        require(stateMachine.nextReviewContributionId() == 1, "foreign evidence created review");

        try stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            keccak256("foreign-evidence-state"),
            REVIEWER_SUBJECT,
            foreignEvidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        ) {
            revert("recognised state accepted foreign workflow evidence");
        } catch {}
        require(stateMachine.nextRecognisedStateId() == 1, "foreign evidence created recognised state");

        uint256 challengeableStateId = _createChallengeableReviewState();
        try challengerActor.fileChallenge(
            stateMachine, AVADataTypes.Role.Challenger, challengeableStateId, CHALLENGER_SUBJECT, foreignEvidenceId, 0
        ) {
            revert("challenge accepted foreign workflow evidence");
        } catch {}

        uint256 defaultEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("default-downstream-evidence"),
            "ipfs://default-downstream-evidence",
            "default-downstream-basis",
            0
        );
        uint256 vestedStateId =
            _registerRecognisedStateForStatus(AVADataTypes.RecognisedStateStatus.Vested, defaultEvidenceId, "default-vested");

        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            vestedStateId,
            REVIEWER_SUBJECT,
            "review-procedure-weight",
            1,
            foreignEvidenceId,
            keccak256("panel-authority"),
            "ipfs://foreign-standing"
        ) {
            revert("standing accepted foreign workflow evidence");
        } catch {}

        try allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            vestedStateId,
            AVADataTypes.AllocationKind.OperationalAllowance,
            REVIEWER_SUBJECT,
            1,
            foreignEvidenceId,
            keccak256("executor-authority"),
            "ipfs://foreign-allocation"
        ) {
            revert("allocation accepted foreign workflow evidence");
        } catch {}

        try consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            vestedStateId,
            AVADataTypes.ConsequenceKind.AdministrativeNote,
            REVIEWER_SUBJECT,
            foreignEvidenceId,
            keccak256("panel-authority"),
            "ipfs://foreign-consequence"
        ) {
            revert("consequence accepted foreign workflow evidence");
        } catch {}

        require(standingRegistry.nextStandingUpdateId() == 1, "foreign evidence created standing");
        require(allocationExecutor.nextAllocationExecutionId() == 1, "foreign evidence created allocation");
        require(consequenceExecutor.nextConsequenceId() == 1, "foreign evidence created consequence");
    }

    function testRecognisedStateStatusChangesWriteGenericTransitionRecords() public {
        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("transition-ledger-review"),
            "ipfs://transition-ledger-review",
            "review-service-occurrence",
            0
        );
        uint256 reviewContributionId = reviewerActor.registerReviewContribution(
            stateMachine, AVADataTypes.Role.Reviewer, manuscriptId, REVIEWER_SUBJECT, evidenceId, 0
        );

        uint256 provisionalTransitionId = stateMachine.nextRecognisedStateTransitionId();
        uint256 recognisedStateId =
            stateMachine.provisionallyRecogniseReview(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);
        _assertRecognisedStateTransition(
            provisionalTransitionId,
            recognisedStateId,
            AVADataTypes.RecognisedStateStatus.None,
            AVADataTypes.RecognisedStateStatus.Provisional,
            AVADataTypes.Action.ProvisionallyRecogniseReview,
            0
        );

        uint256 challengeWindowTransitionId = stateMachine.nextRecognisedStateTransitionId();
        stateMachine.openReviewChallengeWindow(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);
        _assertRecognisedStateTransition(
            challengeWindowTransitionId,
            recognisedStateId,
            AVADataTypes.RecognisedStateStatus.Provisional,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            AVADataTypes.Action.OpenChallengeWindow,
            0
        );

        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256("transition-ledger-challenge"),
            "ipfs://transition-ledger-challenge",
            "review-quality-challenge",
            0
        );
        uint256 challengeId = challengerActor.fileChallenge(
            stateMachine, AVADataTypes.Role.Challenger, recognisedStateId, CHALLENGER_SUBJECT, challengeEvidenceId, 0
        );
        stateMachine.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);

        uint256 resolutionTransitionId = stateMachine.nextRecognisedStateTransitionId();
        stateMachine.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            keccak256("panel-authority"),
            "ipfs://transition-ledger-resolution"
        );
        _assertRecognisedStateTransition(
            resolutionTransitionId,
            recognisedStateId,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            AVADataTypes.Action.ResolveChallenge,
            challengeId
        );

        uint256 restorationChallengeId = _fileAndScreenChallenge("transition-ledger-restoration");
        stateMachine.resolveChallenge(
            AVADataTypes.Role.Panel,
            restorationChallengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://transition-ledger-good-faith"
        );
        AVADataTypes.ChallengeRecord memory restorationChallenge = stateMachine.getChallenge(restorationChallengeId);
        uint256 restorationTransitionId = stateMachine.nextRecognisedStateTransitionId();
        stateMachine.applyRestoration(
            AVADataTypes.Role.Panel,
            restorationChallengeId,
            keccak256("panel-authority"),
            "ipfs://transition-ledger-restored"
        );
        _assertRecognisedStateTransition(
            restorationTransitionId,
            restorationChallenge.challengedRecognisedStateId,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            AVADataTypes.RecognisedStateStatus.Restored,
            AVADataTypes.Action.ApplyRestoration,
            restorationChallengeId
        );
    }

    function testLegacyStandingInputCannotBypassStepFourBoundaries() public {
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("legacy-bypass-evidence"),
            "ipfs://legacy-bypass",
            "legacy-boundary",
            0
        );
        uint256 vestedStateId =
            _registerRecognisedStateForStatus(AVADataTypes.RecognisedStateStatus.Vested, evidenceId, "legacy-vested");

        try standingRegistry.registerStandingInput(
            AVADataTypes.Role.Editor,
            vestedStateId,
            REVIEWER_SUBJECT,
            "review-procedure-weight",
            "ipfs://legacy-standing"
        ) {
            revert("legacy standing input bypassed boundary");
        } catch {}

        require(standingRegistry.nextStandingInputId() == 1, "legacy standing input was recorded");
    }

    function testAuthorisedPanelCanRegisterBoundedConsequenceFromRecognisedState() public {
        (uint256 recognisedStateId, uint256 evidenceId) = _createDowngradedRecognisedState();

        uint256 noteId = consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            AVADataTypes.ConsequenceKind.AdministrativeNote,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://bounded-note"
        );
        uint256 correctionId = consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            AVADataTypes.ConsequenceKind.ProcedureCorrection,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://bounded-correction"
        );
        uint256 restorationId = consequenceExecutor.recordRestoration(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://bounded-restoration"
        );

        AVADataTypes.ConsequenceRecord memory consequence = consequenceExecutor.getConsequence(correctionId);
        require(consequence.recognisedStateId == recognisedStateId, "consequence target wrong");
        require(consequence.kind == AVADataTypes.ConsequenceKind.ProcedureCorrection, "consequence kind wrong");
        require(consequence.subjectId == REVIEWER_SUBJECT, "consequence subject wrong");
        require(consequence.evidenceReceiptId == evidenceId, "consequence evidence wrong");
        require(consequence.authorityRole == AVADataTypes.Role.Panel, "consequence authority role wrong");
        require(consequence.authorityId == keccak256("panel-authority"), "consequence authority wrong");
        require(
            consequenceExecutor.getConsequence(noteId).kind == AVADataTypes.ConsequenceKind.AdministrativeNote,
            "note kind wrong"
        );
        require(
            consequenceExecutor.getConsequence(restorationId).kind == AVADataTypes.ConsequenceKind.RestorationRecord,
            "restoration kind wrong"
        );
        require(standingRegistry.nextStandingUpdateId() == 1, "consequence created standing");
        require(allocationExecutor.nextAllocationExecutionId() == 1, "consequence executed allocation");
    }

    function testUnauthorisedAndEditorCallersCannotRegisterBoundedConsequenceByDefault() public {
        (uint256 recognisedStateId, uint256 evidenceId) = _createDowngradedRecognisedState();

        try outsiderActor.registerConsequence(
            consequenceExecutor,
            AVADataTypes.Role.Panel,
            recognisedStateId,
            AVADataTypes.ConsequenceKind.AdministrativeNote,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("outsider"),
            "ipfs://outsider-consequence"
        ) {
            revert("outsider registered consequence");
        } catch {}

        try consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Editor,
            recognisedStateId,
            AVADataTypes.ConsequenceKind.AdministrativeNote,
            REVIEWER_SUBJECT,
            evidenceId,
            EDITOR_AUTHORITY,
            "ipfs://editor-consequence"
        ) {
            revert("editor registered consequence by default");
        } catch {}
    }

    function testBoundedConsequenceRejectsRawIdsDisallowedStatusesAndZeroFields() public {
        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("consequence-boundary-evidence"),
            "ipfs://consequence-boundary",
            "consequence-boundary",
            0
        );
        uint256 rawReviewId = reviewerActor.registerReviewContribution(
            stateMachine, AVADataTypes.Role.Reviewer, manuscriptId, REVIEWER_SUBJECT, evidenceId, 0
        );

        _assertConsequenceRejectsTarget(rawReviewId, evidenceId);

        uint256 provisionalStateId =
            stateMachine.provisionallyRecogniseReview(AVADataTypes.Role.Editor, rawReviewId, EDITOR_AUTHORITY);
        _assertConsequenceRejectsTarget(provisionalStateId, evidenceId);

        uint256 challengeableStateId = _createChallengeableReviewState();
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256("consequence-raw-challenge"),
            "ipfs://consequence-raw-challenge",
            "review-quality-challenge",
            0
        );
        challengerActor.fileChallenge(
            stateMachine, AVADataTypes.Role.Challenger, challengeableStateId, CHALLENGER_SUBJECT, challengeEvidenceId, 0
        );
        challengerActor.fileChallenge(
            stateMachine, AVADataTypes.Role.Challenger, challengeableStateId, CHALLENGER_SUBJECT, challengeEvidenceId, 0
        );
        uint256 rawChallengeId = challengerActor.fileChallenge(
            stateMachine, AVADataTypes.Role.Challenger, challengeableStateId, CHALLENGER_SUBJECT, challengeEvidenceId, 0
        );

        _assertConsequenceRejectsTarget(rawChallengeId, challengeEvidenceId);
        _assertConsequenceRejectsTarget(0, evidenceId);
        _assertConsequenceRejectsTarget(999, evidenceId);
        _assertConsequenceRejectsTarget(
            _registerRecognisedStateForStatus(
                AVADataTypes.RecognisedStateStatus.Draft, evidenceId, "consequence-draft"
            ),
            evidenceId
        );
        _assertConsequenceRejectsTarget(
            _registerRecognisedStateForStatus(
                AVADataTypes.RecognisedStateStatus.Registered, evidenceId, "consequence-registered"
            ),
            evidenceId
        );
        _assertConsequenceRejectsTarget(
            _registerRecognisedStateForStatus(
                AVADataTypes.RecognisedStateStatus.Challengeable, evidenceId, "consequence-challengeable"
            ),
            evidenceId
        );
        _assertConsequenceRejectsTarget(
            _registerRecognisedStateForStatus(
                AVADataTypes.RecognisedStateStatus.Frozen, evidenceId, "consequence-frozen"
            ),
            evidenceId
        );

        uint256 validStateId = _registerRecognisedStateForStatus(
            AVADataTypes.RecognisedStateStatus.Vested, evidenceId, "consequence-vested"
        );
        try consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            validStateId,
            AVADataTypes.ConsequenceKind.None,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://none-kind"
        ) {
            revert("consequence accepted none kind");
        } catch {}
        try consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            validStateId,
            AVADataTypes.ConsequenceKind.AdministrativeNote,
            bytes32(0),
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://zero-subject"
        ) {
            revert("consequence accepted zero subject");
        } catch {}
        try consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            validStateId,
            AVADataTypes.ConsequenceKind.AdministrativeNote,
            REVIEWER_SUBJECT,
            0,
            keccak256("panel-authority"),
            "ipfs://zero-evidence"
        ) {
            revert("consequence accepted zero evidence");
        } catch {}
        try consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            validStateId,
            AVADataTypes.ConsequenceKind.AdministrativeNote,
            REVIEWER_SUBJECT,
            evidenceId,
            bytes32(0),
            "ipfs://zero-authority"
        ) {
            revert("consequence accepted zero authority");
        } catch {}
    }

    function testProtocolExecutorCanExecuteBoundedAllocationFromRecognisedState() public {

        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("allocation-evidence"),
            "ipfs://allocation-evidence",
            "recognised-allocation-basis",
            0
        );
        uint256 recognisedStateId = stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Allocation,
            keccak256("allocation-object"),
            REVIEWER_SUBJECT,
            evidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        );
        stateMachine.transitionRecognisedState(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            AVADataTypes.RecognisedStateStatus.Vested,
            keccak256("panel-authority"),
            "ipfs://allocation-state-transition"
        );

        uint256 allocationId = allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            AVADataTypes.AllocationKind.OperationalAllowance,
            REVIEWER_SUBJECT,
            3,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://allocation"
        );

        AVADataTypes.AllocationExecutionRecord memory allocation =
            allocationExecutor.getAllocationExecution(allocationId);
        require(allocation.recognisedStateId == recognisedStateId, "allocation target wrong");
        require(allocation.allocationKind == AVADataTypes.AllocationKind.OperationalAllowance, "allocation kind wrong");
        require(allocation.amountOrUnits == 3, "allocation amount wrong");
        require(allocation.authorityRole == AVADataTypes.Role.ProtocolExecutor, "allocation role wrong");
        require(standingRegistry.nextStandingUpdateId() == 1, "allocation created standing");
        require(consequenceExecutor.nextConsequenceId() == 1, "allocation created consequence");
    }

    function testAlternativeAllocationAdapterCanBeSwappedWithoutChangingRecognisedStateSubstrate() public {

        bytes32 workflowKey = keccak256("adapter-allocation-workflow");
        _ensureWorkflowPackage(workflowKey);
        MockAllocationAdapter mockAllocationAdapter =
            new MockAllocationAdapter(AVADataTypes.AllocationKind.RestorationSupport);
        _registerRulePackageWithAdapters(
            workflowKey,
            mockAllocationAdapter,
            consequenceAdapter,
            standingAdapter,
            rewardAdapter,
            priorityAdapter,
            penaltyAdapter,
            restorationAdapter,
            "ipfs://adapter-allocation-workflow"
        );
        (uint256 recognisedStateId, uint256 evidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, "adapter-allocation-object"
        );

        uint256 allocationId = allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            AVADataTypes.AllocationKind.OperationalAllowance,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://adapter-allocation"
        );
        require(allocationExecutor.getAllocationExecution(allocationId).recognisedStateId == recognisedStateId);

        try allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            AVADataTypes.AllocationKind.RestorationSupport,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://blocked-adapter-allocation"
        ) {
            revert("mock allocation adapter did not block allocation");
        } catch {}

        AVADataTypes.RecognisedStateRecord memory state = stateMachine.getRecognisedState(recognisedStateId);
        require(state.status == AVADataTypes.RecognisedStateStatus.Vested, "adapter changed substrate");
        require(standingRegistry.nextStandingUpdateId() == 1, "adapter created standing");
        require(consequenceExecutor.nextConsequenceId() == 1, "adapter created consequence");
    }

    function testAttributionModuleRejectionBlocksRecognisedStateCreation() public {
        bytes32 blockingWorkflow = keccak256("blocking-attribution-workflow");
        RejectingAttributionModule rejectingAttribution = new RejectingAttributionModule();
        _registerRulePackageWithModules(
            blockingWorkflow,
            rejectingAttribution,
            verificationModule,
            transitionRuleModule,
            disclosurePolicyModule,
            allocationAdapter,
            consequenceAdapter,
            "ipfs://blocking-attribution"
        );
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            blockingWorkflow,
            keccak256("blocking-attribution-evidence"),
            "ipfs://blocking-attribution",
            "review-service-occurrence",
            0
        );

        try stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            blockingWorkflow,
            AVADataTypes.AVAStage.Verification,
            keccak256("blocked-attribution-object"),
            REVIEWER_SUBJECT,
            evidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        ) {
            revert("attribution rejection did not block recognised state");
        } catch {}
    }

    function testVerificationModuleRejectionBlocksRecognisedStateCreation() public {
        bytes32 blockingWorkflow = keccak256("blocking-verification-workflow");
        RejectingVerificationModule rejectingVerification = new RejectingVerificationModule();
        _registerRulePackageWithModules(
            blockingWorkflow,
            attributionModule,
            rejectingVerification,
            transitionRuleModule,
            disclosurePolicyModule,
            allocationAdapter,
            consequenceAdapter,
            "ipfs://blocking-verification"
        );
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            blockingWorkflow,
            keccak256("blocking-verification-evidence"),
            "ipfs://blocking-verification",
            "review-service-occurrence",
            0
        );

        try stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            blockingWorkflow,
            AVADataTypes.AVAStage.Verification,
            keccak256("blocked-verification-object"),
            REVIEWER_SUBJECT,
            evidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        ) {
            revert("verification rejection did not block recognised state");
        } catch {}
    }

    function testTransitionRuleRejectionBlocksStatusMovement() public {
        roleRegistry.assignRole(address(this), AVADataTypes.Role.Reviewer, keccak256("local-reviewer"), "ipfs://reviewer");
        bytes32 blockingWorkflow = keccak256("blocking-transition-workflow");
        RejectingTransitionRuleModule rejectingTransition = new RejectingTransitionRuleModule();
        _registerRulePackageWithModules(
            blockingWorkflow,
            attributionModule,
            verificationModule,
            rejectingTransition,
            disclosurePolicyModule,
            allocationAdapter,
            consequenceAdapter,
            "ipfs://blocking-transition"
        );
        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            blockingWorkflow,
            keccak256("blocking-transition-evidence"),
            "ipfs://blocking-transition",
            "review-service-occurrence",
            0
        );
        uint256 reviewContributionId = reviewerActor.registerReviewContributionWithWorkflow(
            stateMachine,
            AVADataTypes.Role.Reviewer, blockingWorkflow, manuscriptId, REVIEWER_SUBJECT, evidenceId, 0
        );
        stateMachine.provisionallyRecogniseReview(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);

        try stateMachine.openReviewChallengeWindow(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY) {
            revert("transition-rule rejection did not block status movement");
        } catch {}
    }

    function testScopedDisclosureRejectionBlocksMainTransitionAction() public {
        roleRegistry.assignRole(address(this), AVADataTypes.Role.Reviewer, keccak256("local-reviewer"), "ipfs://reviewer");
        uint256 disclosurePolicyId = disclosureRegistry.registerDisclosurePolicy(
            AVADataTypes.Role.Editor, "scoped-disclosure-blocker", "ipfs://scoped-disclosure"
        );
        bytes32 workflow = keccak256("blocking-disclosure-action-workflow");
        StageScopedDisclosureModule stageScopedDisclosure = new StageScopedDisclosureModule(
            AVADataTypes.Action.OpenChallengeWindow, AVADataTypes.AVAStage.Verification, bytes32(uint256(1))
        );
        _registerRulePackageWithModules(
            workflow,
            attributionModule,
            verificationModule,
            transitionRuleModule,
            stageScopedDisclosure,
            allocationAdapter,
            consequenceAdapter,
            "ipfs://blocking-disclosure-action"
        );
        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflow,
            keccak256("blocking-disclosure-evidence"),
            "ipfs://blocking-disclosure",
            "review-service-occurrence",
            disclosurePolicyId
        );
        uint256 reviewContributionId = reviewerActor.registerReviewContributionWithWorkflow(
            stateMachine,
            AVADataTypes.Role.Reviewer, workflow, manuscriptId, REVIEWER_SUBJECT, evidenceId, disclosurePolicyId
        );
        stateMachine.provisionallyRecogniseReview(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);

        try stateMachine.openReviewChallengeWindow(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY) {
            revert("scoped disclosure rejection did not block status movement");
        } catch {}
    }

    function testRulePackagesBindTwoAVAWorkflowsToSameRecognisedStateSubstrate() public {
        bytes32 reviewWorkflow = keccak256("review-service-ava");
        bytes32 challengeWorkflow = keccak256("challenge-integrity-ava");
        _registerDefaultRulePackage(reviewWorkflow, "ipfs://review-workflow");
        _registerDefaultRulePackage(challengeWorkflow, "ipfs://challenge-workflow");

        AVARulePackageRegistry.RulePackage memory reviewPackage = rulePackageRegistry.getRulePackage(reviewWorkflow);
        uint256 reviewStateId = _createChallengeableReviewStateThroughPackage(reviewPackage, reviewWorkflow);
        AVADataTypes.RecognisedStateRecord memory reviewState = stateMachine.getRecognisedState(reviewStateId);

        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            challengeWorkflow,
            keccak256("workflow-challenge-evidence"),
            "ipfs://workflow-challenge",
            "review-quality-challenge",
            0
        );
        AVARulePackageRegistry.RulePackage memory challengePackage =
            rulePackageRegistry.getRulePackage(challengeWorkflow);
        bytes32 challengeObject = challengePackage.attributionModule.validateAttribution(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            AVADataTypes.AVAStage.Verification,
            bytes32(reviewStateId),
            CHALLENGER_SUBJECT,
            challengeEvidenceId
        );
        challengePackage.verificationModule.validateVerification(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            AVADataTypes.AVAStage.Verification,
            challengeObject,
            challengeEvidenceId
        );
        uint256 integrityStateId = stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            challengeWorkflow,
            AVADataTypes.AVAStage.Verification,
            challengeObject,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Challengeable
        );
        uint256 challengeId = challengerActor.fileChallenge(
            stateMachine,
            AVADataTypes.Role.Challenger,
            challengeWorkflow,
            integrityStateId,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            0
        );

        AVADataTypes.RecognisedStateRecord memory integrityState = stateMachine.getRecognisedState(integrityStateId);
        AVADataTypes.ChallengeRecord memory challenge = stateMachine.getChallenge(challengeId);
        require(reviewState.id == reviewStateId, "review state missing");
        require(integrityState.id == integrityStateId, "integrity state missing");
        require(reviewState.workflowKey == reviewWorkflow, "review workflow key wrong");
        require(integrityState.workflowKey == challengeWorkflow, "integrity workflow key wrong");
        require(challenge.workflowKey == challengeWorkflow, "challenge workflow key wrong");
        require(integrityState.objectId == bytes32(reviewStateId), "challenge workflow did not target prior state");
        require(challenge.challengedRecognisedStateId == integrityStateId, "wrong target");
        require(address(reviewPackage.attributionModule) == address(attributionModule), "review package wrong");
        require(address(challengePackage.verificationModule) == address(verificationModule), "challenge package wrong");
        require(standingRegistry.nextStandingInputId() == 1, "workflow package created standing");
        require(consequenceExecutor.nextConsequenceId() == 1, "workflow package created consequence");
    }

    function testDisclosureModuleCanVaryByStageActionAndObject() public {
        bytes32 blockedObject = keccak256("blocked-disclosure-object");
        StageScopedDisclosureModule stageScopedDisclosure = new StageScopedDisclosureModule(
            AVADataTypes.Action.FileChallenge, AVADataTypes.AVAStage.Verification, blockedObject
        );
        bytes32 defaultWorkflow = keccak256("default-disclosure-workflow");
        bytes32 scopedWorkflow = keccak256("scoped-disclosure-workflow");

        _registerRulePackage(defaultWorkflow, disclosurePolicyModule, allocationAdapter, consequenceAdapter, "ipfs://d");
        _registerRulePackage(scopedWorkflow, stageScopedDisclosure, allocationAdapter, consequenceAdapter, "ipfs://s");

        AVARulePackageRegistry.RulePackage memory defaultPackage = rulePackageRegistry.getRulePackage(defaultWorkflow);
        AVARulePackageRegistry.RulePackage memory scopedPackage = rulePackageRegistry.getRulePackage(scopedWorkflow);

        defaultPackage.disclosureModule.validateDisclosureForAction(
            0,
            AVADataTypes.Role.Challenger,
            AVADataTypes.Action.FileChallenge,
            AVADataTypes.AVAStage.Verification,
            blockedObject,
            defaultWorkflow,
            defaultPackage.packageId,
            CHALLENGER_SUBJECT
        );
        scopedPackage.disclosureModule.validateDisclosureForAction(
            1,
            AVADataTypes.Role.Challenger,
            AVADataTypes.Action.ScreenChallenge,
            AVADataTypes.AVAStage.Verification,
            blockedObject,
            scopedWorkflow,
            scopedPackage.packageId,
            CHALLENGER_SUBJECT
        );

        try scopedPackage.disclosureModule.validateDisclosureForAction(
            1,
            AVADataTypes.Role.Challenger,
            AVADataTypes.Action.FileChallenge,
            AVADataTypes.AVAStage.Verification,
            blockedObject,
            scopedWorkflow,
            scopedPackage.packageId,
            CHALLENGER_SUBJECT
        ) {
            revert("stage-scoped disclosure did not block matching action");
        } catch {}
    }

    function testM481DifferentWorkflowsCanBindDifferentDisclosureScenarioModules() public {
        uint256 blindedPolicyId = _registerDisclosurePolicy("m481-double-blind-policy");
        uint256 panelPolicyId = _registerDisclosurePolicy("m481-panel-visible-policy");
        DoubleBlindDisclosureModule doubleBlindModule =
            new DoubleBlindDisclosureModule(disclosureRegistry, blindedPolicyId);
        PanelVisibleDisclosureModule panelVisibleModule =
            new PanelVisibleDisclosureModule(disclosureRegistry, panelPolicyId);
        bytes32 doubleBlindWorkflow = keccak256("m481-double-blind-workflow");
        bytes32 panelVisibleWorkflow = keccak256("m481-panel-visible-workflow");

        _registerRulePackage(
            doubleBlindWorkflow, doubleBlindModule, allocationAdapter, consequenceAdapter, "ipfs://m481-double-blind"
        );
        _registerRulePackage(
            panelVisibleWorkflow, panelVisibleModule, allocationAdapter, consequenceAdapter, "ipfs://m481-panel-visible"
        );

        require(
            address(rulePackageRegistry.getRulePackage(doubleBlindWorkflow).disclosureModule)
                == address(doubleBlindModule),
            "double-blind disclosure module not bound"
        );
        require(
            address(rulePackageRegistry.getRulePackage(panelVisibleWorkflow).disclosureModule)
                == address(panelVisibleModule),
            "panel-visible disclosure module not bound"
        );
    }

    function testM74DisclosureScenarioModulesAreRulePackageBindableAndRevealFree() public {
        uint256 doubleBlindPolicyId = _registerDisclosurePolicy("m74-double-blind-policy");
        uint256 panelPolicyId = _registerDisclosurePolicy("m74-panel-policy");
        uint256 anonymousPolicyId = _registerDisclosurePolicy("m74-anonymous-policy");
        uint256 realNamePolicyId = _registerDisclosurePolicy("m74-real-name-policy");
        uint256 authorIntentPolicyId = _registerDisclosurePolicy("m74-author-intent-policy");
        uint256 zkPolicyId = _registerDisclosurePolicy("m74-zk-policy");
        IDisclosurePolicyModule[6] memory modules = [
            IDisclosurePolicyModule(new DoubleBlindDisclosureModule(disclosureRegistry, doubleBlindPolicyId)),
            IDisclosurePolicyModule(new PanelVisibleDisclosureModule(disclosureRegistry, panelPolicyId)),
            IDisclosurePolicyModule(new AnonymousChallengeDisclosureModule(disclosureRegistry, anonymousPolicyId)),
            IDisclosurePolicyModule(new VoluntaryRealNameChallengeModule(disclosureRegistry, realNamePolicyId)),
            IDisclosurePolicyModule(new PostRecognitionAuthorRevealModule(disclosureRegistry, authorIntentPolicyId)),
            IDisclosurePolicyModule(
                new ZKBackedDisclosureModule(
                    disclosureRegistry, _newZkProofRegistry(new SchnorrDisclosureProofVerifier()), zkPolicyId
                )
            )
        ];

        for (uint256 i = 0; i < modules.length; i++) {
            bytes32 workflowKey = keccak256(abi.encode("m74-disclosure-scenario", i));
            _registerRulePackage(workflowKey, modules[i], allocationAdapter, consequenceAdapter, "ipfs://m74-scenario");
            require(
                address(rulePackageRegistry.getRulePackage(workflowKey).disclosureModule) == address(modules[i]),
                "scenario module not bound"
            );
            _assertNoSelector(address(modules[i]), "revealIdentity(uint256)");
            _assertNoSelector(address(modules[i]), "revealEvidence(uint256)");
            _assertNoSelector(address(modules[i]), "decryptEvidence(uint256)");
            _assertNoSelector(address(modules[i]), "acceptManuscript(uint256)");
            _assertNoSelector(address(modules[i]), "scoreManuscriptMerit(uint256)");
        }
    }

    function testM481DoubleBlindModuleBlocksIncompatibleDisclosureButAllowsBlindedReviewFlow() public {
        uint256 blindedPolicyId = _registerDisclosurePolicy("m481-blinded-review-policy");
        DoubleBlindDisclosureModule doubleBlindModule =
            new DoubleBlindDisclosureModule(disclosureRegistry, blindedPolicyId);
        bytes32 workflowKey = keccak256("m481-blinded-review-workflow");
        _registerRulePackage(
            workflowKey, doubleBlindModule, allocationAdapter, consequenceAdapter, "ipfs://m481-blinded-review"
        );

        try doubleBlindModule.validateDisclosureForAction(
            blindedPolicyId,
            AVADataTypes.Role.Author,
            AVADataTypes.Action.RegisterReviewContribution,
            AVADataTypes.AVAStage.Attribution,
            bytes32(uint256(1)),
            workflowKey,
            rulePackageRegistry.getRulePackage(workflowKey).packageId,
            REVIEWER_SUBJECT
        ) {
            revert("double-blind module accepted author as reviewer");
        } catch {}

        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m481-blinded-review-evidence"),
            "ipfs://m481-blinded-review",
            "double-blind-review",
            blindedPolicyId
        );
        uint256 reviewContributionId = reviewerActor.registerReviewContributionWithWorkflow(
            stateMachine, AVADataTypes.Role.Reviewer, workflowKey, manuscriptId, REVIEWER_SUBJECT, evidenceId, blindedPolicyId
        );
        uint256 recognisedStateId =
            stateMachine.provisionallyRecogniseReview(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);
        stateMachine.openReviewChallengeWindow(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);

        require(
            stateMachine.getRecognisedState(recognisedStateId).status == AVADataTypes.RecognisedStateStatus.Challengeable,
            "blinded review flow blocked"
        );
        require(standingRegistry.nextStandingInputId() == 1, "double-blind module created standing");
        require(consequenceExecutor.nextConsequenceId() == 1, "double-blind module created consequence");
    }

    function testM102DoubleBlindReviewScenarioVestsBeforeDownstreamRecords() public {
        uint256 blindedPolicyId = _registerDisclosurePolicy("m102-double-blind-policy");
        DoubleBlindDisclosureModule doubleBlindModule =
            new DoubleBlindDisclosureModule(disclosureRegistry, blindedPolicyId);
        bytes32 workflowKey = keccak256("m102-double-blind-workflow");
        _registerRulePackage(
            workflowKey, doubleBlindModule, allocationAdapter, consequenceAdapter, "ipfs://m102-double-blind"
        );
        uint256 packageId = rulePackageRegistry.getRulePackage(workflowKey).packageId;
        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m102-blinded-review-evidence"),
            "ipfs://m102-blinded-review",
            "double-blind-review",
            blindedPolicyId
        );
        uint256 reviewContributionId = reviewerActor.registerReviewContributionWithWorkflow(
            stateMachine, AVADataTypes.Role.Reviewer, workflowKey, manuscriptId, REVIEWER_SUBJECT, evidenceId, blindedPolicyId
        );
        uint256 recognisedStateId =
            stateMachine.provisionallyRecogniseReview(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);
        stateMachine.openReviewChallengeWindow(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);
        AVADataTypes.RecognisedStateRecord memory challengeableState =
            stateMachine.getRecognisedState(recognisedStateId);
        require(challengeableState.status == AVADataTypes.RecognisedStateStatus.Challengeable, "state not challengeable");
        require(challengeableState.packageId == packageId, "challengeable state package wrong");
        _assertAllDownstreamRejectTarget(recognisedStateId, evidenceId);

        uint256 transitionId = stateMachine.vestReviewRecognition(
            AVADataTypes.Role.Panel, reviewContributionId, keccak256("panel-authority"), "ipfs://m102-review-vested"
        );
        AVADataTypes.RecognisedStateRecord memory vestedState = stateMachine.getRecognisedState(recognisedStateId);
        AVADataTypes.ReviewContributionRecord memory reviewContribution =
            stateMachine.getReviewContribution(reviewContributionId);
        AVADataTypes.RecognisedStateTransitionRecord memory transition =
            stateMachine.getRecognisedStateTransition(transitionId);
        require(vestedState.status == AVADataTypes.RecognisedStateStatus.Vested, "state not vested");
        require(reviewContribution.status == AVADataTypes.ReviewContributionStatus.Vested, "review not vested");
        require(transition.packageId == packageId, "vesting transition package wrong");
        _assertRecognisedStateTransition(
            transitionId,
            recognisedStateId,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            AVADataTypes.RecognisedStateStatus.Vested,
            AVADataTypes.Action.TransitionRecognisedState,
            0
        );

        _assertM102DownstreamRecordsBindPackage(recognisedStateId, evidenceId, packageId);
        _assertNoSelector(address(doubleBlindModule), "revealIdentity(uint256)");
        _assertNoSelector(address(doubleBlindModule), "acceptManuscript(uint256)");
        _assertNoSelector(address(doubleBlindModule), "setManuscriptMerit(uint256,uint256)");
    }

    function testM102DoubleBlindReviewCannotVestWhileChallengeOpen() public {
        M102DoubleBlindReviewContext memory context =
            _createM102ChallengeableDoubleBlindReview("m102-open-challenge");
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            context.workflowKey,
            keccak256("m102-open-challenge-evidence"),
            "ipfs://m102-open-challenge",
            "review-quality-challenge",
            0
        );
        uint256 challengeId = challengerActor.fileChallenge(
            stateMachine,
            AVADataTypes.Role.Challenger,
            context.workflowKey,
            context.recognisedStateId,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            0
        );
        require(
            stateMachine.openChallengeCountForRecognisedState(context.recognisedStateId) == 1,
            "open challenge count missing"
        );

        try stateMachine.vestReviewRecognition(
            AVADataTypes.Role.Panel,
            context.reviewContributionId,
            keccak256("panel-authority"),
            "ipfs://m102-blocked-vesting"
        ) {
            revert("review vested while challenge open");
        } catch {}

        stateMachine.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        stateMachine.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://m102-good-faith-resolution"
        );
        stateMachine.closeChallenge(
            AVADataTypes.Role.Panel, challengeId, keccak256("panel-authority"), "ipfs://m102-close-challenge"
        );
        require(
            stateMachine.openChallengeCountForRecognisedState(context.recognisedStateId) == 0,
            "closed challenge still counted"
        );
        stateMachine.vestReviewRecognition(
            AVADataTypes.Role.Panel,
            context.reviewContributionId,
            keccak256("panel-authority"),
            "ipfs://m102-review-vested-after-close"
        );
        require(
            stateMachine.getRecognisedState(context.recognisedStateId).status == AVADataTypes.RecognisedStateStatus.Vested,
            "review not vested after closed challenge"
        );
        _assertNoSelector(address(context.module), "revealIdentity(uint256)");
        _assertNoSelector(address(context.module), "acceptManuscript(uint256)");
    }

    function testTimedChallengeWindowPackageRejectsEarlyVestingAndAllowsAfterDuration() public {
        bytes32 workflowKey = keccak256("timed-challenge-window-workflow");
        uint64 minimumDuration = 2 days;
        _registerRulePackageWithModules(
            workflowKey,
            attributionModule,
            verificationModule,
            new MinimumChallengeWindowTransitionModule(minimumDuration),
            disclosurePolicyModule,
            allocationAdapter,
            consequenceAdapter,
            "ipfs://timed-challenge-window"
        );

        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("timed-window-review-evidence"),
            "ipfs://timed-window-review",
            "review-service-occurrence",
            0
        );
        uint256 reviewContributionId = reviewerActor.registerReviewContributionWithWorkflow(
            stateMachine, AVADataTypes.Role.Reviewer, workflowKey, manuscriptId, REVIEWER_SUBJECT, evidenceId, 0
        );
        uint256 recognisedStateId =
            stateMachine.provisionallyRecogniseReview(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);

        vm.warp(1_000);
        stateMachine.openReviewChallengeWindow(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);
        require(
            stateMachine.getChallengeWindowOpenedAt(recognisedStateId) == uint64(block.timestamp),
            "challenge window timestamp missing"
        );

        try stateMachine.vestReviewRecognition(
            AVADataTypes.Role.Panel,
            reviewContributionId,
            keccak256("panel-authority"),
            "ipfs://timed-window-too-early"
        ) {
            revert("timed challenge-window package allowed early vesting");
        } catch {}

        vm.warp(block.timestamp + minimumDuration);
        uint256 transitionId = stateMachine.vestReviewRecognition(
            AVADataTypes.Role.Panel,
            reviewContributionId,
            keccak256("panel-authority"),
            "ipfs://timed-window-vested"
        );
        require(transitionId != 0, "timed vesting transition missing");
        require(
            stateMachine.getRecognisedState(recognisedStateId).status == AVADataTypes.RecognisedStateStatus.Vested,
            "timed review did not vest after duration"
        );
    }

    function testM481PanelVisibleModuleAllowsEditorPanelAndRejectsOrdinaryRoles() public {
        uint256 panelPolicyId = _registerDisclosurePolicy("m481-panel-visible-review-policy");
        PanelVisibleDisclosureModule panelVisibleModule =
            new PanelVisibleDisclosureModule(disclosureRegistry, panelPolicyId);
        bytes32 workflowKey = keccak256("m481-panel-visible-review-workflow");
        _registerRulePackage(
            workflowKey, panelVisibleModule, allocationAdapter, consequenceAdapter, "ipfs://m481-panel-visible-roles"
        );
        uint256 packageId = rulePackageRegistry.getRulePackage(workflowKey).packageId;

        panelVisibleModule.validateDisclosureForAction(
            panelPolicyId,
            AVADataTypes.Role.Editor,
            AVADataTypes.Action.ScreenChallenge,
            AVADataTypes.AVAStage.Verification,
            bytes32(uint256(1)),
            workflowKey,
            packageId,
            CHALLENGER_SUBJECT
        );
        panelVisibleModule.validateDisclosureForAction(
            panelPolicyId,
            AVADataTypes.Role.Panel,
            AVADataTypes.Action.ResolveChallenge,
            AVADataTypes.AVAStage.Verification,
            bytes32(uint256(1)),
            workflowKey,
            packageId,
            CHALLENGER_SUBJECT
        );
        try panelVisibleModule.validateDisclosureForAction(
            panelPolicyId,
            AVADataTypes.Role.Reviewer,
            AVADataTypes.Action.ScreenChallenge,
            AVADataTypes.AVAStage.Verification,
            bytes32(uint256(1)),
            workflowKey,
            packageId,
            CHALLENGER_SUBJECT
        ) {
            revert("panel-visible module accepted ordinary role");
        } catch {}
    }

    function testM481AnonymousChallengeModuleSupportsChallengeWithoutRevealSelectors() public {
        uint256 anonymousPolicyId = _registerDisclosurePolicy("m481-anonymous-challenge-policy");
        AnonymousChallengeDisclosureModule anonymousModule =
            new AnonymousChallengeDisclosureModule(disclosureRegistry, anonymousPolicyId);
        bytes32 workflowKey = keccak256("m481-anonymous-challenge-workflow");
        _registerRulePackage(
            workflowKey, anonymousModule, allocationAdapter, consequenceAdapter, "ipfs://m481-anonymous-challenge"
        );
        uint256 recognisedStateId =
            _createChallengeableReviewStateThroughPackage(rulePackageRegistry.getRulePackage(workflowKey), workflowKey);
        uint256 evidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            workflowKey,
            keccak256("m481-anonymous-challenge-evidence"),
            "ipfs://m481-anonymous-challenge",
            "anonymous-challenge",
            anonymousPolicyId
        );
        uint256 challengeId = challengerActor.fileChallenge(
            stateMachine,
            AVADataTypes.Role.Challenger,
            workflowKey,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            evidenceId,
            anonymousPolicyId
        );
        stateMachine.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        stateMachine.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://m481-anonymous-resolution"
        );

        require(
            stateMachine.getChallenge(challengeId).outcome == AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            "anonymous challenge flow failed"
        );
        _assertNoSelector(address(anonymousModule), "revealIdentity(uint256)");
        _assertNoSelector(address(anonymousModule), "decryptEvidence(uint256)");
    }

    function testM103AnonymousIntegrityChallengeScenarioRequiresActionBoundProofs() public {
        M103AnonymousChallengeContext memory context = _createM103FiledZkChallenge("m103-anonymous-integrity");
        bytes32 filingProofContextHash = zkProofRegistry.computeDisclosureContextHash(
            context.workflowKey,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            bytes32(context.recognisedStateId),
            AVADataTypes.Role.Challenger,
            context.policyId,
            context.subjectCommitment
        );
        uint256 filingProofReceiptId = zkProofRegistry.getProofReceiptId(filingProofContextHash);
        ZKProofRegistry.ProofReceipt memory filingProof = zkProofRegistry.getProofReceipt(filingProofReceiptId);
        try context.challenger.recordAnonymousChallengeProofUse(
            disclosureAccessExecutor,
            AVADataTypes.Role.Challenger,
            context.challengeId,
            context.policyId,
            filingProofReceiptId,
            context.subjectCommitment,
            filingProof.nullifierHash,
            "ipfs://m103-filing-proof-reuse"
        ) {
            revert("filing proof reused as anonymous proof use");
        } catch {}
        uint256 proofUseId = _recordM103AnonymousChallengeProofUse(context);
        AVADataTypes.DisclosureExecutionRecord memory proofUse =
            disclosureAccessExecutor.getDisclosureExecution(proofUseId);
        require(proofUse.packageId == context.packageId, "proof use package wrong");
        require(proofUse.targetId == context.challengeId, "proof use target wrong");
        require(proofUse.subjectCommitment == context.subjectCommitment, "proof use subject wrong");

        try stateMachine.screenChallenge(AVADataTypes.Role.Editor, context.challengeId, EDITOR_AUTHORITY) {
            revert("screen accepted without action-bound proof");
        } catch {}
        _registerM103DisclosureProof(
            context,
            AVADataTypes.Action.ScreenChallenge,
            bytes32(context.recognisedStateId),
            AVADataTypes.Role.Editor
        );
        stateMachine.screenChallenge(AVADataTypes.Role.Editor, context.challengeId, EDITOR_AUTHORITY);

        try stateMachine.resolveChallenge(
            AVADataTypes.Role.Panel,
            context.challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://m103-resolution"
        ) {
            revert("resolve accepted without action-bound proof");
        } catch {}
        _registerM103DisclosureProof(
            context,
            AVADataTypes.Action.ResolveChallenge,
            bytes32(context.recognisedStateId),
            AVADataTypes.Role.Panel
        );
        stateMachine.resolveChallenge(
            AVADataTypes.Role.Panel,
            context.challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://m103-resolution"
        );

        require(
            stateMachine.getChallenge(context.challengeId).outcome == AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            "anonymous integrity challenge not resolved"
        );
        require(standingRegistry.nextStandingUpdateId() == 1, "anonymous challenge created standing");
        require(allocationExecutor.nextAllocationExecutionId() == 1, "anonymous challenge created allocation");
        require(consequenceExecutor.nextConsequenceId() == 1, "anonymous challenge created consequence");
        _assertNoSelector(address(context.module), "revealIdentity(uint256)");
        _assertNoSelector(address(context.module), "decryptEvidence(uint256)");
        _assertNoSelector(address(zkProofRegistry), "validateScientificTruth(uint256)");
    }

    function testM104CorrectionRestorationScenarioRestoresAdverseStateWithoutErasingHistory() public {
        M104CorrectionRestorationContext memory context =
            _createM104DowngradedCorrectionState("m104-correction-restoration");
        AVADataTypes.ChallengeRecord memory correctedChallenge = stateMachine.getChallenge(context.challengeId);
        uint256 correctionChallengeTransitionId = correctedChallenge.lastTransitionId;
        uint256 restorationStateTransitionId = stateMachine.nextRecognisedStateTransitionId();

        stateMachine.applyRestoration(
            AVADataTypes.Role.Panel,
            context.challengeId,
            keccak256("panel-authority"),
            "ipfs://m104-restoration-transition"
        );

        AVADataTypes.ChallengeRecord memory restoredChallenge = stateMachine.getChallenge(context.challengeId);
        AVADataTypes.ChallengeTransitionRecord memory correctionTransition =
            stateMachine.getChallengeTransition(correctionChallengeTransitionId);
        AVADataTypes.ChallengeTransitionRecord memory restorationChallengeTransition =
            stateMachine.getChallengeTransition(restoredChallenge.lastTransitionId);
        AVADataTypes.RecognisedStateTransitionRecord memory restorationStateTransition =
            stateMachine.getRecognisedStateTransition(restorationStateTransitionId);

        require(restoredChallenge.status == AVADataTypes.ChallengeLifecycleStatus.RestorationApplied, "not restored");
        require(correctionTransition.outcome == AVADataTypes.ChallengeOutcome.Upheld, "correction history erased");
        require(correctionTransition.toStatus == AVADataTypes.RecognisedStateStatus.Downgraded, "correction target erased");
        require(
            restorationChallengeTransition.transitionKind == AVADataTypes.ChallengeTransitionKind.RestorationRecorded,
            "restoration challenge transition missing"
        );
        require(
            restorationStateTransition.fromStatus == AVADataTypes.RecognisedStateStatus.Downgraded,
            "restoration from status wrong"
        );
        require(
            restorationStateTransition.toStatus == AVADataTypes.RecognisedStateStatus.Restored,
            "restoration state transition wrong"
        );
        require(
            stateMachine.getRecognisedState(context.recognisedStateId).status == AVADataTypes.RecognisedStateStatus.Restored,
            "state not restored"
        );
        require(consequenceExecutor.nextConsequenceId() == 1, "restoration auto-created consequence");
        require(standingRegistry.nextStandingInputId() == 1, "restoration auto-created standing");
        require(allocationExecutor.nextAllocationExecutionId() == 1, "restoration auto-executed allocation");

        uint256 restorationRecordId = consequenceExecutor.recordRestoration(
            AVADataTypes.Role.Panel,
            context.recognisedStateId,
            REVIEWER_SUBJECT,
            context.challengeEvidenceId,
            keccak256("panel-authority"),
            "ipfs://m104-restoration-record"
        );
        AVADataTypes.ConsequenceRecord memory restorationRecord =
            consequenceExecutor.getConsequence(restorationRecordId);
        require(restorationRecord.packageId == context.packageId, "restoration package wrong");
        require(restorationRecord.kind == AVADataTypes.ConsequenceKind.RestorationRecord, "restoration kind wrong");
    }

    function testM105DoubleBlindVestingUsesHistoricalPackageAfterWorkflowReregistration() public {
        M102DoubleBlindReviewContext memory context = _createM102ChallengeableDoubleBlindReview("m105-double-blind");
        uint256 oldPackageId = context.packageId;

        _registerRulePackageWithModules(
            context.workflowKey,
            attributionModule,
            verificationModule,
            new RejectingTransitionRuleModule(),
            disclosurePolicyModule,
            allocationAdapter,
            consequenceAdapter,
            "ipfs://m105-double-blind-new-rejecting"
        );
        uint256 newPackageId = rulePackageRegistry.getRulePackage(context.workflowKey).packageId;
        require(newPackageId != oldPackageId, "package not replaced");

        uint256 transitionId = stateMachine.vestReviewRecognition(
            AVADataTypes.Role.Panel,
            context.reviewContributionId,
            keccak256("panel-authority"),
            "ipfs://m105-double-blind-vested"
        );
        AVADataTypes.RecognisedStateRecord memory recognisedState =
            stateMachine.getRecognisedState(context.recognisedStateId);
        AVADataTypes.RecognisedStateTransitionRecord memory transition =
            stateMachine.getRecognisedStateTransition(transitionId);

        require(recognisedState.packageId == oldPackageId, "recognised state package changed");
        require(recognisedState.status == AVADataTypes.RecognisedStateStatus.Vested, "review did not vest");
        require(transition.packageId == oldPackageId, "vesting used active package");
        _assertM102DownstreamRecordsBindPackage(context.recognisedStateId, context.evidenceId, oldPackageId);
    }

    function testM105AnonymousChallengeUsesHistoricalPackageAfterWorkflowReregistration() public {
        M103AnonymousChallengeContext memory context = _createM103FiledZkChallenge("m105-anonymous-challenge");
        uint256 oldPackageId = context.packageId;
        uint256 proofUseId = _recordM103AnonymousChallengeProofUse(context);
        _registerM103DisclosureProof(
            context,
            AVADataTypes.Action.ScreenChallenge,
            bytes32(context.recognisedStateId),
            AVADataTypes.Role.Editor
        );
        _registerM103DisclosureProof(
            context,
            AVADataTypes.Action.ResolveChallenge,
            bytes32(context.recognisedStateId),
            AVADataTypes.Role.Panel
        );

        _registerRulePackage(
            context.workflowKey,
            disclosurePolicyModule,
            allocationAdapter,
            consequenceAdapter,
            "ipfs://m105-anonymous-new-default"
        );
        uint256 newPackageId = rulePackageRegistry.getRulePackage(context.workflowKey).packageId;
        require(newPackageId != oldPackageId, "package not replaced");

        stateMachine.screenChallenge(AVADataTypes.Role.Editor, context.challengeId, EDITOR_AUTHORITY);
        stateMachine.resolveChallenge(
            AVADataTypes.Role.Panel,
            context.challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://m105-anonymous-resolution"
        );
        AVADataTypes.ChallengeRecord memory challenge = stateMachine.getChallenge(context.challengeId);
        AVADataTypes.ChallengeTransitionRecord memory transition =
            stateMachine.getChallengeTransition(challenge.lastTransitionId);
        AVADataTypes.DisclosureExecutionRecord memory proofUse =
            disclosureAccessExecutor.getDisclosureExecution(proofUseId);

        require(challenge.packageId == oldPackageId, "challenge package changed");
        require(transition.packageId == oldPackageId, "challenge used active package");
        require(proofUse.packageId == oldPackageId, "proof use package changed");
        require(challenge.outcome == AVADataTypes.ChallengeOutcome.RejectedGoodFaith, "challenge not resolved");
    }

    function testM105RestorationUsesHistoricalPackageAfterWorkflowReregistration() public {
        M104CorrectionRestorationContext memory context =
            _createM104DowngradedCorrectionState("m105-correction-restoration");
        uint256 oldPackageId = context.packageId;

        _registerRulePackageWithAdapters(
            context.workflowKey,
            allocationAdapter,
            consequenceAdapter,
            standingAdapter,
            rewardAdapter,
            priorityAdapter,
            penaltyAdapter,
            new MockRestorationAdapter(keccak256("panel-authority")),
            "ipfs://m105-restoration-new-blocking"
        );
        uint256 newPackageId = rulePackageRegistry.getRulePackage(context.workflowKey).packageId;
        require(newPackageId != oldPackageId, "package not replaced");

        uint256 transitionId = stateMachine.nextRecognisedStateTransitionId();
        stateMachine.applyRestoration(
            AVADataTypes.Role.Panel,
            context.challengeId,
            keccak256("panel-authority"),
            "ipfs://m105-restoration-transition"
        );
        AVADataTypes.RecognisedStateTransitionRecord memory transition =
            stateMachine.getRecognisedStateTransition(transitionId);
        uint256 restorationRecordId = consequenceExecutor.recordRestoration(
            AVADataTypes.Role.Panel,
            context.recognisedStateId,
            REVIEWER_SUBJECT,
            context.challengeEvidenceId,
            keccak256("panel-authority"),
            "ipfs://m105-restoration-record"
        );
        AVADataTypes.ConsequenceRecord memory restorationRecord =
            consequenceExecutor.getConsequence(restorationRecordId);

        require(transition.packageId == oldPackageId, "restoration transition used active package");
        require(restorationRecord.packageId == oldPackageId, "restoration record used active package");
        require(restorationRecord.kind == AVADataTypes.ConsequenceKind.RestorationRecord, "restoration kind wrong");
    }

    function testM481VoluntaryRealNameChallengeCannotBypassCoreGates() public {
        uint256 realNamePolicyId = _registerDisclosurePolicy("m481-real-name-challenge-policy");
        VoluntaryRealNameChallengeModule realNameModule =
            new VoluntaryRealNameChallengeModule(disclosureRegistry, realNamePolicyId);
        bytes32 workflowKey = keccak256("m481-real-name-challenge-workflow");
        _registerRulePackage(
            workflowKey, realNameModule, allocationAdapter, consequenceAdapter, "ipfs://m481-real-name-challenge"
        );
        uint256 recognisedStateId =
            _createChallengeableReviewStateThroughPackage(rulePackageRegistry.getRulePackage(workflowKey), workflowKey);
        uint256 evidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            workflowKey,
            keccak256("m481-real-name-challenge-evidence"),
            "ipfs://m481-real-name-challenge",
            "real-name-challenge",
            realNamePolicyId
        );

        try outsiderActor.fileChallenge(
            stateMachine,
            AVADataTypes.Role.Challenger,
            workflowKey,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            evidenceId,
            realNamePolicyId
        ) {
            revert("real-name module bypassed authority");
        } catch {}
        try challengerActor.fileChallenge(
            stateMachine,
            AVADataTypes.Role.Challenger,
            workflowKey,
            recognisedStateId + 999,
            CHALLENGER_SUBJECT,
            evidenceId,
            realNamePolicyId
        ) {
            revert("real-name module bypassed recognised-state target");
        } catch {}
        try challengerActor.fileChallenge(
            stateMachine,
            AVADataTypes.Role.Challenger,
            workflowKey,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            0,
            realNamePolicyId
        ) {
            revert("real-name module bypassed evidence gate");
        } catch {}

        uint256 challengeId = challengerActor.fileChallenge(
            stateMachine,
            AVADataTypes.Role.Challenger,
            workflowKey,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            evidenceId,
            realNamePolicyId
        );
        try stateMachine.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            keccak256("panel-authority"),
            "ipfs://m481-real-name-unscreened"
        ) {
            revert("real-name module bypassed challenge lifecycle");
        } catch {}
        roleRegistry.assignRole(address(challengerActor), AVADataTypes.Role.Panel, keccak256("m481-panel-challenger"), "ipfs://panel");
        stateMachine.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        try challengerActor.resolveChallenge(
            stateMachine,
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            keccak256("panel-authority"),
            "ipfs://m481-real-name-self-resolution"
        ) {
            revert("real-name module bypassed self-resolution gate");
        } catch {}
        _assertNoSelector(address(realNameModule), "validateScientificTruth(uint256)");
    }

    function testM481PostRecognitionAuthorRevealModuleIsValidationOnly() public {
        uint256 authorRevealPolicyId = _registerDisclosurePolicy("m481-author-reveal-policy");
        PostRecognitionAuthorRevealModule authorRevealModule =
            new PostRecognitionAuthorRevealModule(disclosureRegistry, authorRevealPolicyId);
        bytes32 workflowKey = keccak256("m481-author-reveal-workflow");
        _registerRulePackage(
            workflowKey, authorRevealModule, allocationAdapter, consequenceAdapter, "ipfs://m481-author-reveal"
        );
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m481-author-reveal-evidence"),
            "ipfs://m481-author-reveal",
            "post-recognition-author-reveal",
            authorRevealPolicyId
        );
        uint256 stateId = stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            keccak256("m481-author-reveal-object"),
            REVIEWER_SUBJECT,
            evidenceId,
            authorRevealPolicyId,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        );

        require(stateMachine.getRecognisedState(stateId).disclosurePolicyId == authorRevealPolicyId, "policy not recorded");
        _assertNoSelector(address(authorRevealModule), "revealIdentity(uint256)");
        _assertNoSelector(address(authorRevealModule), "acceptManuscript(uint256)");
        _assertNoSelector(address(authorRevealModule), "scoreManuscriptMerit(uint256)");
    }

    function testM484ValidProofRegistersWithMatchingSubjectCommitment() public {
        SchnorrDisclosureProofVerifier verifier = new SchnorrDisclosureProofVerifier();
        ZKProofRegistry proofRegistry = _newZkProofRegistry(verifier);
        uint256 disclosurePolicyId = _registerDisclosurePolicy("m484-valid-proof-policy");
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        bytes32 contextHash = proofRegistry.computeDisclosureContextHash(
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            keccak256("m482-object"),
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment
        );
        IZKProofVerifier.SchnorrProof memory proof = _makeSchnorrProof(contextHash, 7, 11);

        require(verifier.verify(contextHash, proof), "valid proof rejected by verifier");
        uint256 receiptId = proofRegistry.registerProof(
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            keccak256("m482-object"),
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment,
            proof
        );
        ZKProofRegistry.ProofReceipt memory receipt = proofRegistry.getProofReceipt(receiptId);

        require(receipt.packageId == rulePackageRegistry.getRulePackage(DEFAULT_WORKFLOW).packageId, "wrong proof package");
        require(receipt.contextHash == contextHash, "wrong context hash");
        require(receipt.subjectCommitment == subjectCommitment, "wrong subject commitment");
        require(receipt.nullifierHash == proofRegistry.computeNullifierHash(contextHash, subjectCommitment), "wrong nullifier");
        require(proofRegistry.getProofReceiptId(contextHash) == receiptId, "receipt not indexed");
        require(proofRegistry.getProofReceiptIdByNullifier(receipt.nullifierHash) == receiptId, "nullifier not indexed");
        require(proofRegistry.hasVerifiedProof(contextHash), "proof receipt missing");
    }

    function testM484MismatchedSubjectCommitmentIsRejected() public {
        SchnorrDisclosureProofVerifier verifier = new SchnorrDisclosureProofVerifier();
        ZKProofRegistry proofRegistry = _newZkProofRegistry(verifier);
        uint256 disclosurePolicyId = _registerDisclosurePolicy("m484-mismatched-subject-policy");
        bytes32 wrongSubjectCommitment = _subjectCommitmentForSecret(9);
        bytes32 contextHash = proofRegistry.computeDisclosureContextHash(
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            keccak256("m482-invalid-object"),
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            wrongSubjectCommitment
        );
        IZKProofVerifier.SchnorrProof memory proof = _makeSchnorrProof(contextHash, 7, 11);

        try proofRegistry.registerProof(
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            keccak256("m482-invalid-object"),
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            wrongSubjectCommitment,
            proof
        ) {
            revert("mismatched subject commitment accepted");
        } catch {}
    }

    function testM484InvalidSchnorrProofRejected() public {
        SchnorrDisclosureProofVerifier verifier = new SchnorrDisclosureProofVerifier();
        ZKProofRegistry proofRegistry = _newZkProofRegistry(verifier);
        uint256 disclosurePolicyId = _registerDisclosurePolicy("m484-invalid-proof-policy");
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        bytes32 contextHash = proofRegistry.computeDisclosureContextHash(
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            keccak256("m482-invalid-proof-object"),
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment
        );
        IZKProofVerifier.SchnorrProof memory proof = _makeSchnorrProof(contextHash, 7, 11);
        proof.response = addmod(proof.response, 1, BN254_GROUP_ORDER);

        try proofRegistry.registerProof(
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            keccak256("m482-invalid-proof-object"),
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment,
            proof
        ) {
            revert("invalid proof accepted");
        } catch {}
    }

    function testM484ProofCannotReplayAcrossWorkflowActionObjectPolicyOrSubject() public {
        SchnorrDisclosureProofVerifier verifier = new SchnorrDisclosureProofVerifier();
        ZKProofRegistry proofRegistry = _newZkProofRegistry(verifier);
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        bytes32 workflowKey = keccak256("m482-replay-workflow");
        _ensureWorkflowPackage(workflowKey);
        uint256 disclosurePolicyId = _registerDisclosurePolicy("m484-replay-policy");
        bytes32 objectId = keccak256("m482-replay-object");
        bytes32 contextHash = proofRegistry.computeDisclosureContextHash(
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment
        );
        IZKProofVerifier.SchnorrProof memory proof = _makeSchnorrProof(contextHash, 7, 11);

        proofRegistry.registerProof(
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment,
            proof
        );

        _assertZkProofCannotReplayAcrossContext(
            proofRegistry, workflowKey, objectId, disclosurePolicyId, subjectCommitment, proof
        );
    }

    function testM484DuplicateNullifierContextIsRejected() public {
        SchnorrDisclosureProofVerifier verifier = new SchnorrDisclosureProofVerifier();
        ZKProofRegistry proofRegistry = _newZkProofRegistry(verifier);
        uint256 disclosurePolicyId = _registerDisclosurePolicy("m484-duplicate-policy");
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        bytes32 workflowKey = keccak256("m484-duplicate-workflow");
        _ensureWorkflowPackage(workflowKey);
        bytes32 objectId = keccak256("m484-duplicate-object");
        bytes32 contextHash = proofRegistry.computeDisclosureContextHash(
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment
        );
        proofRegistry.registerProof(
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment,
            _makeSchnorrProof(contextHash, 7, 11)
        );

        try proofRegistry.registerProof(
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment,
            _makeSchnorrProof(contextHash, 7, 13)
        ) {
            revert("duplicate nullifier/context accepted");
        } catch {}
    }

    function testM72DisclosureProofContextIncludesPackageAfterWorkflowReregistration() public {
        SchnorrDisclosureProofVerifier verifier = new SchnorrDisclosureProofVerifier();
        ZKProofRegistry proofRegistry = _newZkProofRegistry(verifier);
        bytes32 workflowKey = keccak256("m72-package-context-workflow");
        uint256 disclosurePolicyId = _registerDisclosurePolicy("m72-package-context-policy");
        bytes32 objectId = keccak256("m72-package-context-object");
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);

        _ensureWorkflowPackage(workflowKey);
        uint256 oldPackageId = rulePackageRegistry.getRulePackage(workflowKey).packageId;
        bytes32 oldContextHash = proofRegistry.computeDisclosureContextHash(
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment
        );
        uint256 oldProofReceiptId = proofRegistry.registerProof(
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment,
            _makeSchnorrProof(oldContextHash, 7, 11)
        );

        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m72-package-context-v2");
        uint256 newPackageId = rulePackageRegistry.getRulePackage(workflowKey).packageId;
        require(newPackageId != oldPackageId, "workflow package did not change");
        bytes32 newContextHash = proofRegistry.computeDisclosureContextHash(
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment
        );
        require(oldContextHash != newContextHash, "package rotation did not change proof context");
        uint256 newProofReceiptId = proofRegistry.registerProof(
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment,
            _makeSchnorrProof(newContextHash, 7, 13)
        );

        ZKProofRegistry.ProofReceipt memory oldReceipt = proofRegistry.getProofReceipt(oldProofReceiptId);
        ZKProofRegistry.ProofReceipt memory newReceipt = proofRegistry.getProofReceipt(newProofReceiptId);
        require(oldReceipt.packageId == oldPackageId, "old proof package wrong");
        require(newReceipt.packageId == newPackageId, "new proof package wrong");
        require(oldReceipt.nullifierHash != newReceipt.nullifierHash, "package contexts shared nullifier");
        require(proofRegistry.getProofReceiptId(oldContextHash) == oldProofReceiptId, "old context index lost");
        require(proofRegistry.getProofReceiptId(newContextHash) == newProofReceiptId, "new context index missing");
    }

    function testM81ZKProofReceiptsBindVerifierAndProofDomain() public {
        SchnorrDisclosureProofVerifier verifier = new SchnorrDisclosureProofVerifier();
        ZKProofRegistry proofRegistry = _newZkProofRegistry(verifier);
        uint256 disclosurePolicyId = _registerDisclosurePolicy("m81-proof-domain-policy");
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        bytes32 objectId = keccak256("m81-proof-domain-object");
        uint256 packageId = rulePackageRegistry.getRulePackage(DEFAULT_WORKFLOW).packageId;
        bytes32 contextHash = proofRegistry.computeDisclosureContextHash(
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment
        );
        require(
            contextHash
                == proofRegistry.computeDisclosureContextHashForPackageAndProofDomain(
                    packageId,
                    verifier.proofDomain(),
                    DEFAULT_WORKFLOW,
                    AVADataTypes.AVAStage.Verification,
                    AVADataTypes.Action.FileChallenge,
                    objectId,
                    AVADataTypes.Role.Challenger,
                    disclosurePolicyId,
                    subjectCommitment
                ),
            "disclosure proof context omitted proof domain"
        );
        uint256 proofReceiptId = proofRegistry.registerProof(
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment,
            _makeSchnorrProof(contextHash, 7, 11)
        );
        ZKProofRegistry.ProofReceipt memory proofReceipt = proofRegistry.getProofReceipt(proofReceiptId);
        require(proofReceipt.verifier == address(verifier), "disclosure proof verifier not recorded");
        require(proofReceipt.proofDomainHash == verifier.proofDomain(), "disclosure proof domain not recorded");

        bytes32 standingSubjectCommitment = _subjectCommitmentForSecret(13);
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(DEFAULT_WORKFLOW, standingSubjectCommitment, "m81-standing-domain");
        (input,,,) = _bindM93StandingProofInput(input, "m81-standing-domain");
        bytes32 standingContextHash = zkStandingComputationRegistry.computeStandingComputationContextHash(input);
        require(
            standingContextHash
                == zkStandingComputationRegistry.computeStandingComputationContextHashForProofDomain(
                    input, zkStandingComputationRegistry.verifier().proofDomain()
                ),
            "standing proof context omitted proof domain"
        );
        uint256 standingReceiptId = zkStandingComputationRegistry.registerStandingProof(
            input,
            _makeSchnorrProof(standingContextHash, 13, 17)
        );
        ZKStandingComputationRegistry.StandingProofReceipt memory standingReceipt =
            zkStandingComputationRegistry.getStandingProofReceipt(standingReceiptId);
        require(
            standingReceipt.verifier == address(zkStandingComputationRegistry.verifier()),
            "standing proof verifier not recorded"
        );
        require(
            standingReceipt.proofDomainHash == zkStandingComputationRegistry.verifier().proofDomain(),
            "standing proof domain not recorded"
        );
    }

    function testM417ZKProofRegistryRequiresKnownWorkflowAndDisclosurePolicy() public {
        ZKProofRegistry proofRegistry = _newZkProofRegistry(new SchnorrDisclosureProofVerifier());
        bytes32 workflowKey = keccak256("m417-zk-workflow");
        bytes32 unknownWorkflowKey = keccak256("m417-zk-unknown-workflow");
        bytes32 objectId = keccak256("m417-zk-object");
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        uint256 disclosurePolicyId = _registerDisclosurePolicy("m417-zk-policy");
        uint256 unknownDisclosurePolicyId = disclosurePolicyId + 1000;

        bytes32 unknownWorkflowContextHash = proofRegistry.computeDisclosureContextHash(
            unknownWorkflowKey,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment
        );
        try proofRegistry.registerProof(
            unknownWorkflowKey,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment,
            _makeSchnorrProof(unknownWorkflowContextHash, 7, 11)
        ) {
            revert("proof accepted unknown workflow");
        } catch {}

        _ensureWorkflowPackage(workflowKey);
        bytes32 unknownPolicyContextHash = proofRegistry.computeDisclosureContextHash(
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            unknownDisclosurePolicyId,
            subjectCommitment
        );
        try proofRegistry.registerProof(
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            unknownDisclosurePolicyId,
            subjectCommitment,
            _makeSchnorrProof(unknownPolicyContextHash, 7, 11)
        ) {
            revert("proof accepted unknown disclosure policy");
        } catch {}

        bytes32 contextHash = proofRegistry.computeDisclosureContextHash(
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment
        );
        uint256 receiptId = proofRegistry.registerProof(
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment,
            _makeSchnorrProof(contextHash, 7, 11)
        );
        ZKProofRegistry.ProofReceipt memory receipt = proofRegistry.getProofReceipt(receiptId);
        require(receipt.contextHash == contextHash, "valid proof not recorded");
        require(receipt.packageId == rulePackageRegistry.getRulePackage(workflowKey).packageId, "valid proof package missing");

        try proofRegistry.registerProof(
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment,
            _makeSchnorrProof(contextHash, 7, 13)
        ) {
            revert("proof replay accepted");
        } catch {}
    }

    function testM484ZKBackedDisclosureModuleRequiresMatchingSubjectProofReceipt() public {
        uint256 zkPolicyId = _registerDisclosurePolicy("m482-zk-policy");
        SchnorrDisclosureProofVerifier verifier = new SchnorrDisclosureProofVerifier();
        ZKProofRegistry proofRegistry = _newZkProofRegistry(verifier);
        ZKBackedDisclosureModule zkModule = new ZKBackedDisclosureModule(disclosureRegistry, proofRegistry, zkPolicyId);
        bytes32 workflowKey = keccak256("m482-zk-module-workflow");
        _ensureWorkflowPackage(workflowKey);
        bytes32 objectId = keccak256("m482-zk-object");
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        bytes32 otherSubjectCommitment = _subjectCommitmentForSecret(9);

        try zkModule.validateDisclosureForAction(
            zkPolicyId,
            AVADataTypes.Role.Challenger,
            AVADataTypes.Action.FileChallenge,
            AVADataTypes.AVAStage.Verification,
            objectId,
            workflowKey,
            rulePackageRegistry.getRulePackage(workflowKey).packageId,
            subjectCommitment
        ) {
            revert("zk module accepted missing proof");
        } catch {}

        bytes32 contextHash = proofRegistry.computeDisclosureContextHash(
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            zkPolicyId,
            subjectCommitment
        );
        proofRegistry.registerProof(
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            zkPolicyId,
            subjectCommitment,
            _makeSchnorrProof(contextHash, 7, 11)
        );

        zkModule.validateDisclosureForAction(
            zkPolicyId,
            AVADataTypes.Role.Challenger,
            AVADataTypes.Action.FileChallenge,
            AVADataTypes.AVAStage.Verification,
            objectId,
            workflowKey,
            rulePackageRegistry.getRulePackage(workflowKey).packageId,
            subjectCommitment
        );

        try zkModule.validateDisclosureForAction(
            zkPolicyId,
            AVADataTypes.Role.Challenger,
            AVADataTypes.Action.FileChallenge,
            AVADataTypes.AVAStage.Verification,
            objectId,
            workflowKey,
            rulePackageRegistry.getRulePackage(workflowKey).packageId,
            otherSubjectCommitment
        ) {
            revert("subject A proof satisfied subject B");
        } catch {}
    }

    function testM426ZKBackedDisclosureModuleRejectsNewPackageProofForOldPackageValidation() public {
        uint256 zkPolicyId = _registerDisclosurePolicy("m426-zk-module-package-policy");
        ZKProofRegistry proofRegistry = _newZkProofRegistry(new SchnorrDisclosureProofVerifier());
        ZKBackedDisclosureModule zkModule = new ZKBackedDisclosureModule(disclosureRegistry, proofRegistry, zkPolicyId);
        bytes32 workflowKey = keccak256("m426-zk-module-package-workflow");
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);

        _registerRulePackage(workflowKey, zkModule, allocationAdapter, consequenceAdapter, "ipfs://m426-zk-module-v1");
        uint256 oldPackageId = rulePackageRegistry.getRulePackage(workflowKey).packageId;
        bytes32 oldObjectId = keccak256("m426-zk-module-old-object");
        _registerZkDisclosureProof(
            proofRegistry,
            workflowKey,
            AVADataTypes.Action.FileChallenge,
            oldObjectId,
            AVADataTypes.Role.Challenger,
            zkPolicyId,
            subjectCommitment
        );
        zkModule.validateDisclosureForAction(
            zkPolicyId,
            AVADataTypes.Role.Challenger,
            AVADataTypes.Action.FileChallenge,
            AVADataTypes.AVAStage.Verification,
            oldObjectId,
            workflowKey,
            oldPackageId,
            subjectCommitment
        );

        _registerRulePackage(workflowKey, zkModule, allocationAdapter, consequenceAdapter, "ipfs://m426-zk-module-v2");
        uint256 newPackageId = rulePackageRegistry.getRulePackage(workflowKey).packageId;
        require(newPackageId != oldPackageId, "workflow package was not replaced");
        bytes32 newObjectId = keccak256("m426-zk-module-new-object");
        _registerZkDisclosureProof(
            proofRegistry,
            workflowKey,
            AVADataTypes.Action.FileChallenge,
            newObjectId,
            AVADataTypes.Role.Challenger,
            zkPolicyId,
            subjectCommitment
        );

        try zkModule.validateDisclosureForAction(
            zkPolicyId,
            AVADataTypes.Role.Challenger,
            AVADataTypes.Action.FileChallenge,
            AVADataTypes.AVAStage.Verification,
            newObjectId,
            workflowKey,
            oldPackageId,
            subjectCommitment
        ) {
            revert("new package proof satisfied old package disclosure validation");
        } catch {}
        zkModule.validateDisclosureForAction(
            zkPolicyId,
            AVADataTypes.Role.Challenger,
            AVADataTypes.Action.FileChallenge,
            AVADataTypes.AVAStage.Verification,
            newObjectId,
            workflowKey,
            newPackageId,
            subjectCommitment
        );
    }

    function testM485ZKBackedModuleRejectsZeroAndNonZKPolicies() public {
        uint256 zkPolicyId = _registerDisclosurePolicy("m485-zk-policy");
        uint256 nonZkPolicyId = _registerDisclosurePolicy("m485-non-zk-policy");
        ZKProofRegistry proofRegistry = _newZkProofRegistry(new SchnorrDisclosureProofVerifier());
        ZKBackedDisclosureModule zkModule = new ZKBackedDisclosureModule(disclosureRegistry, proofRegistry, zkPolicyId);
        bytes32 workflowKey = keccak256("m485-zk-policy-workflow");
        _ensureWorkflowPackage(workflowKey);
        bytes32 objectId = keccak256("m485-zk-policy-object");
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);

        try zkModule.validateDisclosureForAction(
            0,
            AVADataTypes.Role.Challenger,
            AVADataTypes.Action.FileChallenge,
            AVADataTypes.AVAStage.Verification,
            objectId,
            workflowKey,
            rulePackageRegistry.getRulePackage(workflowKey).packageId,
            subjectCommitment
        ) {
            revert("zk module accepted zero policy");
        } catch {}

        try zkModule.validateDisclosureForAction(
            nonZkPolicyId,
            AVADataTypes.Role.Challenger,
            AVADataTypes.Action.FileChallenge,
            AVADataTypes.AVAStage.Verification,
            objectId,
            workflowKey,
            rulePackageRegistry.getRulePackage(workflowKey).packageId,
            subjectCommitment
        ) {
            revert("zk module accepted non-zk policy");
        } catch {}

        _registerZkDisclosureProof(
            proofRegistry,
            workflowKey,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            zkPolicyId,
            subjectCommitment
        );
        zkModule.validateDisclosureForAction(
            zkPolicyId,
            AVADataTypes.Role.Challenger,
            AVADataTypes.Action.FileChallenge,
            AVADataTypes.AVAStage.Verification,
            objectId,
            workflowKey,
            rulePackageRegistry.getRulePackage(workflowKey).packageId,
            subjectCommitment
        );
    }

    function testM485AnonymousChallengeCannotBypassZKPolicyWithZeroPolicy() public {
        _assertAnonymousZkChallengePolicyRejected(0, "m485-zero", "zk-backed challenge accepted zero policy");
    }

    function testM485AnonymousChallengeCannotBypassZKPolicyWithNonZKPolicy() public {
        uint256 nonZkPolicyId = _registerDisclosurePolicy("m485-anonymous-non-zk-policy");
        _assertAnonymousZkChallengePolicyRejected(
            nonZkPolicyId, "m485-non-zk", "zk-backed challenge accepted non-zk policy"
        );
    }

    function testM484AnonymousChallengeWorkflowUsesSubjectBoundZKBackedModuleWithoutRevealSelectors() public {
        (uint256 challengeId, ZKBackedDisclosureModule zkModule, ZKProofRegistry proofRegistry) =
            _fileSubjectBoundZkChallenge();

        require(
            stateMachine.getChallenge(challengeId).status == AVADataTypes.ChallengeLifecycleStatus.ConcernFiled,
            "zk challenge filing failed"
        );
        _assertNoSelector(address(zkModule), "revealIdentity(uint256)");
        _assertNoSelector(address(zkModule), "decryptEvidence(uint256)");
        _assertNoSelector(address(proofRegistry), "validateScientificTruth(uint256)");
        _assertNoSelector(address(proofRegistry), "acceptManuscript(uint256)");
    }

    function testAllocationAndConsequenceModulesAreReplaceableAndRecordOnly() public {

        bytes32 workflowKey = keccak256("replaceable-downstream-workflow");
        _ensureWorkflowPackage(workflowKey);
        MockAllocationAdapter mockAllocation =
            new MockAllocationAdapter(AVADataTypes.AllocationKind.RestorationSupport);
        MockConsequenceAdapter mockConsequence =
            new MockConsequenceAdapter(AVADataTypes.ConsequenceKind.ProcedureCorrection);
        _registerRulePackageWithAdapters(
            workflowKey,
            mockAllocation,
            mockConsequence,
            standingAdapter,
            rewardAdapter,
            priorityAdapter,
            penaltyAdapter,
            restorationAdapter,
            "ipfs://replaceable-downstream-workflow"
        );
        (uint256 recognisedStateId, uint256 evidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, "replaceable-modules"
        );

        uint256 allocationId = allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            AVADataTypes.AllocationKind.OperationalAllowance,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://replaceable-allocation"
        );
        uint256 consequenceId = consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            AVADataTypes.ConsequenceKind.AdministrativeNote,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://replaceable-consequence"
        );

        try allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            AVADataTypes.AllocationKind.RestorationSupport,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://blocked-allocation-module"
        ) {
            revert("replaceable allocation module did not block");
        } catch {}
        try consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            AVADataTypes.ConsequenceKind.ProcedureCorrection,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://blocked-consequence-module"
        ) {
            revert("replaceable consequence module did not block");
        } catch {}

        require(allocationExecutor.getAllocationExecution(allocationId).recognisedStateId == recognisedStateId);
        require(consequenceExecutor.getConsequence(consequenceId).recognisedStateId == recognisedStateId);
        require(standingRegistry.nextStandingUpdateId() == 1, "replaceable module created standing");
        require(consequenceExecutor.nextConsequenceId() == consequenceId + 1, "consequence executor did not record once");
    }

    function testStandingAdapterIsStandingSpecificAndDoesNotCreateReward() public {
        bytes32 workflowKey = keccak256("standing-adapter-workflow");
        _ensureWorkflowPackage(workflowKey);
        MockStandingAdapter mockStanding = new MockStandingAdapter("blocked-standing-dimension");
        _registerRulePackageWithAdapters(
            workflowKey,
            allocationAdapter,
            consequenceAdapter,
            mockStanding,
            rewardAdapter,
            priorityAdapter,
            penaltyAdapter,
            restorationAdapter,
            "ipfs://standing-adapter-workflow"
        );
        (uint256 recognisedStateId, uint256 evidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowKey, AVADataTypes.RecognisedStateStatus.Downgraded, "standing-adapter-state"
        );

        uint256 standingUpdateId = standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            "review-procedure-weight",
            1,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://standing-adapter"
        );
        require(standingRegistry.getStandingUpdate(standingUpdateId).recognisedStateId == recognisedStateId);

        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            "blocked-standing-dimension",
            1,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://blocked-standing-adapter"
        ) {
            revert("standing adapter was not invoked");
        } catch {}

        require(allocationExecutor.nextAllocationExecutionId() == 1, "standing update created reward or priority");
        require(consequenceExecutor.nextConsequenceId() == 1, "standing update created consequence");
    }

    function testRewardValueAdapterCanBeSwappedWithoutChangingRecognisedStateSubstrate() public {

        bytes32 workflowKey = keccak256("reward-adapter-workflow");
        _ensureWorkflowPackage(workflowKey);
        MockRewardAdapter mockReward = new MockRewardAdapter(7);
        _registerRulePackageWithAdapters(
            workflowKey,
            allocationAdapter,
            consequenceAdapter,
            standingAdapter,
            mockReward,
            priorityAdapter,
            penaltyAdapter,
            restorationAdapter,
            "ipfs://reward-adapter-workflow"
        );
        (uint256 recognisedStateId, uint256 evidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, "reward-adapter"
        );

        uint256 rewardRecordId = allocationExecutor.recordRewardValue(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://reward-record"
        );
        AVADataTypes.AllocationExecutionRecord memory rewardRecord =
            allocationExecutor.getAllocationExecution(rewardRecordId);
        require(rewardRecord.allocationKind == AVADataTypes.AllocationKind.RewardValueRecord, "wrong reward kind");

        try allocationExecutor.recordRewardValue(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            REVIEWER_SUBJECT,
            7,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://blocked-reward-record"
        ) {
            revert("reward adapter was not invoked");
        } catch {}

        require(
            stateMachine.getRecognisedState(recognisedStateId).status == AVADataTypes.RecognisedStateStatus.Vested,
            "reward adapter mutated recognised state"
        );
        require(standingRegistry.nextStandingUpdateId() == 1, "reward record created standing");
        require(consequenceExecutor.nextConsequenceId() == 1, "reward record created consequence");
    }

    function testPriorityAdapterCanBeSwappedWithoutPublicationAdvantage() public {

        bytes32 workflowKey = keccak256("priority-adapter-workflow");
        _ensureWorkflowPackage(workflowKey);
        MockPriorityAdapter mockPriority = new MockPriorityAdapter(9);
        _registerRulePackageWithAdapters(
            workflowKey,
            allocationAdapter,
            consequenceAdapter,
            standingAdapter,
            rewardAdapter,
            mockPriority,
            penaltyAdapter,
            restorationAdapter,
            "ipfs://priority-adapter-workflow"
        );
        (uint256 recognisedStateId, uint256 evidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, "priority-adapter"
        );

        uint256 priorityRecordId = allocationExecutor.recordAdministrativePriority(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://priority-record"
        );
        AVADataTypes.AllocationExecutionRecord memory priorityRecord =
            allocationExecutor.getAllocationExecution(priorityRecordId);
        require(
            priorityRecord.allocationKind == AVADataTypes.AllocationKind.AdministrativeQueueRecord,
            "wrong priority kind"
        );

        try allocationExecutor.recordAdministrativePriority(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            REVIEWER_SUBJECT,
            9,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://blocked-priority-record"
        ) {
            revert("priority adapter was not invoked");
        } catch {}

        _assertNoSelector(address(allocationExecutor), "grantPublicationPriority(uint256)");
        _assertNoSelector(address(allocationExecutor), "boostManuscriptScore(uint256)");
        require(standingRegistry.nextStandingUpdateId() == 1, "priority record created standing");
        require(consequenceExecutor.nextConsequenceId() == 1, "priority record created consequence");
    }

    function testPenaltyAdapterCanBeSwappedAndRemainsRecordOnly() public {
        bytes32 workflowKey = keccak256("penalty-adapter-workflow");
        _ensureWorkflowPackage(workflowKey);
        bytes32 blockedAuthority = keccak256("blocked-penalty-authority");
        MockPenaltyAdapter mockPenalty = new MockPenaltyAdapter(blockedAuthority);
        _registerRulePackageWithAdapters(
            workflowKey,
            allocationAdapter,
            consequenceAdapter,
            standingAdapter,
            rewardAdapter,
            priorityAdapter,
            mockPenalty,
            restorationAdapter,
            "ipfs://penalty-adapter-workflow"
        );
        (uint256 recognisedStateId, uint256 evidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowKey, AVADataTypes.RecognisedStateStatus.Downgraded, "penalty-adapter-state"
        );

        uint256 penaltyRecordId = consequenceExecutor.recordPenalty(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://penalty-record"
        );
        require(
            consequenceExecutor.getConsequence(penaltyRecordId).kind
                == AVADataTypes.ConsequenceKind.PenaltyRecord,
            "wrong penalty kind"
        );

        try consequenceExecutor.recordPenalty(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            evidenceId,
            blockedAuthority,
            "ipfs://blocked-penalty-record"
        ) {
            revert("penalty adapter was not invoked");
        } catch {}

        require(standingRegistry.nextStandingUpdateId() == 1, "penalty record created standing");
        require(allocationExecutor.nextAllocationExecutionId() == 1, "penalty record executed allocation");
    }

    function testRestorationAdapterCanBeSwappedAndRemainsDistinctFromReward() public {
        bytes32 workflowKey = keccak256("restoration-adapter-workflow");
        _ensureWorkflowPackage(workflowKey);
        bytes32 blockedAuthority = keccak256("blocked-restoration-authority");
        MockRestorationAdapter mockRestoration = new MockRestorationAdapter(blockedAuthority);
        _registerRulePackageWithAdapters(
            workflowKey,
            allocationAdapter,
            consequenceAdapter,
            standingAdapter,
            rewardAdapter,
            priorityAdapter,
            penaltyAdapter,
            mockRestoration,
            "ipfs://restoration-adapter-workflow"
        );
        (uint256 recognisedStateId, uint256 evidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowKey, AVADataTypes.RecognisedStateStatus.Restored, "restoration-adapter"
        );

        uint256 restorationRecordId = consequenceExecutor.recordRestoration(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://restoration-record"
        );
        require(
            consequenceExecutor.getConsequence(restorationRecordId).kind
                == AVADataTypes.ConsequenceKind.RestorationRecord,
            "wrong restoration kind"
        );

        try consequenceExecutor.recordRestoration(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            evidenceId,
            blockedAuthority,
            "ipfs://blocked-restoration-record"
        ) {
            revert("restoration adapter was not invoked");
        } catch {}

        require(allocationExecutor.nextAllocationExecutionId() == 1, "restoration record created reward");
        require(standingRegistry.nextStandingUpdateId() == 1, "restoration record created standing");
    }

    function testM49InfrastructureInterfacesHaveDefaultAndExampleModules() public {
        bytes32 evidenceTypeHash = keccak256("m49-evidence-type");
        bytes32 objectId = keccak256("m49-object");
        bytes32 subjectId = keccak256("m49-subject");
        bytes32 attestationHash = keccak256("m49-attestation");

        evidencePolicyModule.validateEvidencePolicy(
            DEFAULT_WORKFLOW, AVADataTypes.Role.Editor, AVADataTypes.Action.RegisterEvidence, 1, evidenceTypeHash, address(this)
        );
        auditAdapter.validateAuditRecord(
            DEFAULT_WORKFLOW, AVADataTypes.Role.Panel, AVADataTypes.Action.RecordAttestation, objectId, 1, attestationHash, address(this)
        );
        editorialSystemAdapter.validateEditorialReference(
            DEFAULT_WORKFLOW, AVADataTypes.Role.Editor, AVADataTypes.Action.RegisterManuscript, objectId, "ipfs://editorial-ref", address(this)
        );
        fieldPolicyModule.validateFieldPolicy(
            DEFAULT_WORKFLOW, AVADataTypes.Role.Editor, AVADataTypes.Action.RegisterRecognisedState, AVADataTypes.AVAStage.Verification, objectId, 1
        );
        antiAbuseModule.validateUse(
            DEFAULT_WORKFLOW, AVADataTypes.Role.Challenger, AVADataTypes.Action.FileChallenge, subjectId, objectId, address(this)
        );

        new TypedEvidencePolicyModule(evidenceTypeHash).validateEvidencePolicy(
            DEFAULT_WORKFLOW, AVADataTypes.Role.Editor, AVADataTypes.Action.RegisterEvidence, 1, evidenceTypeHash, address(this)
        );
        new HashAnchoredAuditAdapter().validateAuditRecord(
            DEFAULT_WORKFLOW, AVADataTypes.Role.Panel, AVADataTypes.Action.RecordAttestation, objectId, 1, attestationHash, address(this)
        );
        new EditorialReferenceAdapter().validateEditorialReference(
            DEFAULT_WORKFLOW, AVADataTypes.Role.Editor, AVADataTypes.Action.RegisterManuscript, objectId, "ipfs://editorial-ref", address(this)
        );
        new DisciplineFieldPolicyModule(AVADataTypes.AVAStage.Verification).validateFieldPolicy(
            DEFAULT_WORKFLOW, AVADataTypes.Role.Editor, AVADataTypes.Action.RegisterRecognisedState, AVADataTypes.AVAStage.Verification, objectId, 1
        );
        new SubjectRateLimitModule().validateUse(
            DEFAULT_WORKFLOW, AVADataTypes.Role.Challenger, AVADataTypes.Action.FileChallenge, subjectId, objectId, address(this)
        );
    }

    function testM49WorkflowBindsNonDefaultCentralAndInfrastructureModules() public {
        bytes32 workflowKey = keccak256("m49-non-default-workflow");
        AVARulePackageRegistry.RulePackage memory rulePackage = _registerM49NonDefaultRulePackage(workflowKey);
        bytes32 objectId = keccak256("m49-object");
        bytes32 subjectId = keccak256("m49-subject");
        bytes32 evidenceTypeHash = keccak256("m49-evidence-type");
        uint256 evidenceReceiptId = 3;

        bytes32 attributedObjectId = rulePackage.attributionModule.validateAttribution(
            workflowKey, AVADataTypes.Role.Reviewer, AVADataTypes.AVAStage.Verification, objectId, subjectId, evidenceReceiptId
        );
        require(attributedObjectId != objectId, "non-default attribution unused");
        rulePackage.verificationModule.validateVerification(
            workflowKey, AVADataTypes.Role.Editor, AVADataTypes.AVAStage.Verification, objectId, evidenceReceiptId
        );
        rulePackage.transitionRuleModule.validateTransition(
            workflowKey,
            AVADataTypes.Action.ResolveChallenge,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            AVADataTypes.ChallengeOutcome.Upheld
        );
        rulePackage.challengeLifecycleModule.validateChallengeAction(
            IChallengeLifecycleModule.ChallengeLifecycleContext({
                workflowKey: workflowKey,
                action: AVADataTypes.Action.ResolveChallenge,
                fromLifecycleStatus: AVADataTypes.ChallengeLifecycleStatus.AdmissibilityScreening,
                toLifecycleStatus: AVADataTypes.ChallengeLifecycleStatus.Resolved,
                outcome: AVADataTypes.ChallengeOutcome.Upheld,
                challengedStateStatus: AVADataTypes.RecognisedStateStatus.Challengeable,
                proposedStateStatus: AVADataTypes.RecognisedStateStatus.Downgraded,
                actor: address(this),
                filedBy: address(challengerActor)
            })
        );
        rulePackage.evidencePolicyModule.validateEvidencePolicy(
            workflowKey, AVADataTypes.Role.Editor, AVADataTypes.Action.RegisterEvidence, evidenceReceiptId, evidenceTypeHash, address(this)
        );
        rulePackage.auditAdapter.validateAuditRecord(
            workflowKey, AVADataTypes.Role.Panel, AVADataTypes.Action.RecordAttestation, objectId, evidenceReceiptId, keccak256("m49-audit"), address(this)
        );
        rulePackage.editorialSystemAdapter.validateEditorialReference(
            workflowKey, AVADataTypes.Role.Editor, AVADataTypes.Action.RegisterManuscript, objectId, "ipfs://editorial-ref", address(this)
        );
        rulePackage.fieldPolicyModule.validateFieldPolicy(
            workflowKey, AVADataTypes.Role.Editor, AVADataTypes.Action.RegisterRecognisedState, AVADataTypes.AVAStage.Verification, objectId, evidenceReceiptId
        );
        rulePackage.antiAbuseModule.validateUse(
            workflowKey, AVADataTypes.Role.Challenger, AVADataTypes.Action.FileChallenge, subjectId, objectId, address(this)
        );
    }

    function testM49DownstreamExampleAdaptersAreSwappableAndRecordOnly() public {

        bytes32 workflowKey = keccak256("m49-downstream-workflow");
        _ensureWorkflowPackage(workflowKey);

        _registerM49DownstreamWorkflow(workflowKey);
        (uint256 recognisedStateId, uint256 evidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowKey, AVADataTypes.RecognisedStateStatus.Downgraded, "m49-downstream-state"
        );

        standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            "review-vector-weight",
            2,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://m49-standing"
        );
        uint256 rewardRecordId = allocationExecutor.recordRewardValue(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://m49-stablecoin-record"
        );
        uint256 priorityRecordId = allocationExecutor.recordAdministrativePriority(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://m49-priority-token-record"
        );
        uint256 consequenceId = consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            AVADataTypes.ConsequenceKind.AdministrativeNote,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://m49-consequence"
        );
        uint256 penaltyId = consequenceExecutor.recordPenalty(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://m49-procedural-penalty-record"
        );
        uint256 restorationId = consequenceExecutor.recordRestoration(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://m49-restoration-procedure-record"
        );

        require(
            allocationExecutor.getAllocationExecution(rewardRecordId).allocationKind
                == AVADataTypes.AllocationKind.RewardValueRecord,
            "wrong stablecoin record kind"
        );
        require(
            allocationExecutor.getAllocationExecution(priorityRecordId).allocationKind
                == AVADataTypes.AllocationKind.AdministrativeQueueRecord,
            "wrong priority record kind"
        );
        require(consequenceExecutor.getConsequence(consequenceId).kind == AVADataTypes.ConsequenceKind.AdministrativeNote);
        require(consequenceExecutor.getConsequence(penaltyId).kind == AVADataTypes.ConsequenceKind.PenaltyRecord);
        require(consequenceExecutor.getConsequence(restorationId).kind == AVADataTypes.ConsequenceKind.RestorationRecord);

        require(
            stateMachine.getRecognisedState(recognisedStateId).status == AVADataTypes.RecognisedStateStatus.Downgraded,
            "downstream adapter mutated recognised state"
        );
        _assertM49SecondaryDownstreamExamples(recognisedStateId, evidenceId);
        AVARulePackageRegistry.RulePackage memory rulePackage = rulePackageRegistry.getRulePackage(workflowKey);
        _assertNoSelector(address(rulePackage.rewardAdapter), "transferStablecoin(uint256)");
        _assertNoSelector(address(new GenericTokenRecordRewardAdapter()), "transferToken(uint256)");
        _assertNoSelector(address(rulePackage.priorityAdapter), "grantPublicationPriority(uint256)");
        _assertNoSelector(address(rulePackage.priorityAdapter), "boostManuscriptScore(uint256)");
        _assertNoSelector(address(rulePackage.penaltyAdapter), "executeSanction(uint256)");
        _assertNoSelector(address(rulePackage.restorationAdapter), "mintReward(uint256)");
    }

    function testM491EvidencePolicyBlocksEvidenceRegistrationAndRecognisedStatePath() public {
        roleRegistry.assignRole(address(this), AVADataTypes.Role.Reviewer, keccak256("reviewer-this"), "ipfs://reviewer");
        bytes32 evidenceWorkflow = keccak256("m491-evidence-registration");
        _registerRulePackageWithInfrastructure(
            evidenceWorkflow,
            new RejectingEvidencePolicyModule(AVADataTypes.Action.RegisterEvidence),
            auditAdapter,
            editorialSystemAdapter,
            fieldPolicyModule,
            antiAbuseModule,
            "ipfs://m491-evidence-registration"
        );
        try evidenceRegistry.registerEvidenceReceipt(
            AVADataTypes.Role.Reviewer,
            evidenceWorkflow,
            keccak256("m491-evidence"),
            "ipfs://m491-evidence",
            "blocked-evidence-type",
            0
        ) {
            revert("evidence policy did not block evidence registration");
        } catch {}

        bytes32 recognisedWorkflow = keccak256("m491-evidence-recognised");
        _ensureWorkflowPackage(recognisedWorkflow);
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            recognisedWorkflow,
            keccak256("m491-recognised-evidence"),
            "ipfs://m491-recognised-evidence",
            "recognised-state-basis",
            0
        );
        _registerRulePackageWithInfrastructure(
            recognisedWorkflow,
            new RejectingEvidencePolicyModule(AVADataTypes.Action.RegisterRecognisedState),
            auditAdapter,
            editorialSystemAdapter,
            fieldPolicyModule,
            antiAbuseModule,
            "ipfs://m491-evidence-recognised"
        );
        try stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            recognisedWorkflow,
            AVADataTypes.AVAStage.Verification,
            keccak256("m491-recognised-object"),
            REVIEWER_SUBJECT,
            evidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        ) {
            revert("evidence policy did not block recognised-state path");
        } catch {}
    }

    function testM491FieldPolicyBlocksRecognisedStateValidation() public {
        bytes32 workflowKey = keccak256("m491-field-policy");
        _ensureWorkflowPackage(workflowKey);
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m491-field-evidence"),
            "ipfs://m491-field-evidence",
            "field-policy-basis",
            0
        );
        _registerRulePackageWithInfrastructure(
            workflowKey,
            evidencePolicyModule,
            auditAdapter,
            editorialSystemAdapter,
            new RejectingFieldPolicyModule(),
            antiAbuseModule,
            "ipfs://m491-field-policy"
        );

        try stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            keccak256("m491-field-object"),
            REVIEWER_SUBJECT,
            evidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        ) {
            revert("field policy did not block recognised-state validation");
        } catch {}
    }

    function testM491AntiAbuseBlocksReviewChallengeAndDownstreamPaths() public {
        roleRegistry.assignRole(address(this), AVADataTypes.Role.Reviewer, keccak256("reviewer-this"), "ipfs://reviewer");

        uint256 manuscriptId = stateMachine.registerManuscript(
            AVADataTypes.Role.Author, keccak256("m491-abuse-manuscript"), "ipfs://m491-abuse-manuscript"
        );
        bytes32 reviewWorkflow = keccak256("m491-abuse-review");
        _ensureWorkflowPackage(reviewWorkflow);
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            reviewWorkflow,
            keccak256("m491-abuse-evidence"),
            "ipfs://m491-abuse-evidence",
            "abuse-basis",
            0
        );

        _registerRulePackageWithInfrastructure(
            reviewWorkflow,
            evidencePolicyModule,
            auditAdapter,
            editorialSystemAdapter,
            fieldPolicyModule,
            new RejectingAntiAbuseModule(AVADataTypes.Action.RegisterReviewContribution),
            "ipfs://m491-abuse-review"
        );
        try stateMachine.registerReviewContribution(
            AVADataTypes.Role.Reviewer, reviewWorkflow, manuscriptId, REVIEWER_SUBJECT, evidenceId, 0
        ) {
            revert("anti-abuse did not block review registration");
        } catch {}

        bytes32 challengeWorkflow = keccak256("m491-abuse-challenge");
        _registerRulePackageWithInfrastructure(
            challengeWorkflow,
            evidencePolicyModule,
            auditAdapter,
            editorialSystemAdapter,
            fieldPolicyModule,
            new RejectingAntiAbuseModule(AVADataTypes.Action.FileChallenge),
            "ipfs://m491-abuse-challenge"
        );
        uint256 challengedStateId = _createChallengeableReviewStateThroughPackage(
            rulePackageRegistry.getRulePackage(challengeWorkflow), challengeWorkflow
        );
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            challengeWorkflow,
            keccak256("m491-abuse-challenge-evidence"),
            "ipfs://m491-abuse-challenge-evidence",
            "abuse-challenge-basis",
            0
        );
        try challengerActor.fileChallenge(
            stateMachine,
            AVADataTypes.Role.Challenger,
            challengeWorkflow,
            challengedStateId,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            0
        ) {
            revert("anti-abuse did not block challenge filing");
        } catch {}

        bytes32 downstreamWorkflow = keccak256("m491-abuse-downstream");
        _registerRulePackageWithInfrastructure(
            downstreamWorkflow,
            evidencePolicyModule,
            auditAdapter,
            editorialSystemAdapter,
            fieldPolicyModule,
            new RejectingAntiAbuseModule(AVADataTypes.Action.RecordStandingUpdate),
            "ipfs://m491-abuse-downstream"
        );
        uint256 downstreamEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            downstreamWorkflow,
            keccak256("m491-abuse-downstream-evidence"),
            "ipfs://m491-abuse-downstream-evidence",
            "abuse-downstream-basis",
            0
        );
        uint256 downstreamStateId = _registerRecognisedStateForWorkflowStatus(
            downstreamWorkflow, AVADataTypes.RecognisedStateStatus.Vested, downstreamEvidenceId, "m491-abuse-downstream"
        );
        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            downstreamStateId,
            REVIEWER_SUBJECT,
            "review-procedure-weight",
            1,
            downstreamEvidenceId,
            keccak256("panel-authority"),
            "ipfs://m491-standing"
        ) {
            revert("anti-abuse did not block downstream record");
        } catch {}
    }

    function testPackageSelectedSubjectRateLimitCanRejectChallengePathWithoutChangingDefaultPackage() public {
        Actor defaultChallenger = new Actor();
        bytes32 defaultChallengerSubject = bytes32(stateMachine.nextRecognisedStateId());
        roleRegistry.assignRole(
            address(defaultChallenger), AVADataTypes.Role.Challenger, defaultChallengerSubject, "ipfs://default-subject-limit"
        );
        uint256 defaultStateId = _createChallengeableReviewState();
        uint256 defaultChallengeEvidenceId = defaultChallenger.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            DEFAULT_WORKFLOW,
            keccak256("default-permissive-subject-path"),
            "ipfs://default-permissive-subject-path",
            "review-quality-challenge",
            0
        );
        uint256 defaultChallengeId = defaultChallenger.fileChallenge(
            stateMachine,
            AVADataTypes.Role.Challenger,
            DEFAULT_WORKFLOW,
            defaultStateId,
            defaultChallengerSubject,
            defaultChallengeEvidenceId,
            0
        );
        require(defaultChallengeId != 0, "default package stopped being permissive");

        bytes32 limitedWorkflow = keccak256("subject-rate-limit-workflow");
        _registerRulePackageWithInfrastructure(
            limitedWorkflow,
            evidencePolicyModule,
            auditAdapter,
            editorialSystemAdapter,
            fieldPolicyModule,
            new SubjectRateLimitModule(),
            "ipfs://subject-rate-limit-workflow"
        );
        Actor limitedChallenger = new Actor();
        bytes32 limitedChallengerSubject = bytes32(stateMachine.nextRecognisedStateId());
        roleRegistry.assignRole(
            address(limitedChallenger), AVADataTypes.Role.Challenger, limitedChallengerSubject, "ipfs://limited-subject"
        );
        uint256 limitedStateId =
            _createChallengeableReviewStateThroughPackage(rulePackageRegistry.getRulePackage(limitedWorkflow), limitedWorkflow);
        require(bytes32(limitedStateId) == limitedChallengerSubject, "rate-limit fixture subject/object mismatch");
        uint256 limitedChallengeEvidenceId = limitedChallenger.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            limitedWorkflow,
            keccak256("limited-subject-path"),
            "ipfs://limited-subject-path",
            "review-quality-challenge",
            0
        );
        uint256 nextChallengeId = stateMachine.nextChallengeId();
        try limitedChallenger.fileChallenge(
            stateMachine,
            AVADataTypes.Role.Challenger,
            limitedWorkflow,
            limitedStateId,
            limitedChallengerSubject,
            limitedChallengeEvidenceId,
            0
        ) {
            revert("subject-rate-limit workflow accepted blocked challenge path");
        } catch {}
        require(stateMachine.nextChallengeId() == nextChallengeId, "blocked anti-abuse path wrote challenge");
    }

    function testRateLimitedPackageRejectsRepeatedChallengeBySameSubject() public {
        bytes32 limitedWorkflow = keccak256("subject-repeat-rate-limit-workflow");
        _registerRulePackageWithInfrastructure(
            limitedWorkflow,
            evidencePolicyModule,
            auditAdapter,
            editorialSystemAdapter,
            fieldPolicyModule,
            new SubjectRateLimitModule(),
            "ipfs://subject-repeat-rate-limit-workflow"
        );
        uint256 recognisedStateId =
            _createChallengeableReviewStateThroughPackage(rulePackageRegistry.getRulePackage(limitedWorkflow), limitedWorkflow);
        uint256 firstEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            limitedWorkflow,
            keccak256("limited-repeat-first-challenge"),
            "ipfs://limited-repeat-first-challenge",
            "review-quality-challenge",
            0
        );
        uint256 firstChallengeId = challengerActor.fileChallenge(
            stateMachine,
            AVADataTypes.Role.Challenger,
            limitedWorkflow,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            firstEvidenceId,
            0
        );
        require(firstChallengeId != 0, "first challenge rejected by rate-limit package");

        uint256 secondEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            limitedWorkflow,
            keccak256("limited-repeat-second-challenge"),
            "ipfs://limited-repeat-second-challenge",
            "review-quality-challenge",
            0
        );
        uint256 nextChallengeId = stateMachine.nextChallengeId();
        try challengerActor.fileChallenge(
            stateMachine,
            AVADataTypes.Role.Challenger,
            limitedWorkflow,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            secondEvidenceId,
            0
        ) {
            revert("rate-limited package accepted repeated challenge by same subject");
        } catch {}
        require(stateMachine.nextChallengeId() == nextChallengeId, "blocked repeated challenge wrote state");
    }

    function testM491AuditAdapterBlocksWorkflowAttestationPath() public {
        bytes32 workflowKey = keccak256("m491-audit");
        _registerRulePackageWithInfrastructure(
            workflowKey,
            evidencePolicyModule,
            new RejectingAuditAdapter(),
            editorialSystemAdapter,
            fieldPolicyModule,
            antiAbuseModule,
            "ipfs://m491-audit"
        );
        uint256 rejectedEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m491-audit-evidence"),
            "ipfs://m491-audit-evidence",
            "workflow-attestation",
            0
        );
        try auditModule.recordAttestation(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVADataTypes.Action.RecordAttestation,
            keccak256("m491-audit-object"),
            rejectedEvidenceId,
            keccak256("m491-audit-hash"),
            keccak256("panel-authority"),
            "workflow-attestation",
            "ipfs://m491-audit"
        ) {
            revert("audit adapter did not block workflow attestation");
        } catch {}

        uint256 defaultEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("m491-default-audit-evidence"),
            "ipfs://m491-default-audit-evidence",
            "workflow-attestation",
            0
        );
        uint256 attestationId = auditModule.recordAttestation(
            AVADataTypes.Role.Panel,
            DEFAULT_WORKFLOW,
            AVADataTypes.Action.RecordAttestation,
            keccak256("m491-default-audit-object"),
            defaultEvidenceId,
            keccak256("m491-default-audit-hash"),
            keccak256("panel-authority"),
            "workflow-attestation",
            "ipfs://m491-default-audit"
        );
        AVADataTypes.AttestationRecord memory attestation = auditModule.getAttestation(attestationId);
        require(attestation.id == attestationId, "audit adapter active path failed");
        require(attestation.authorityRole == AVADataTypes.Role.Panel, "audit authority role missing");
        require(attestation.authorityId == keccak256("panel-authority"), "audit authority id missing");

        try auditModule.recordAttestation(
            AVADataTypes.Role.Panel,
            DEFAULT_WORKFLOW,
            AVADataTypes.Action.RecordAttestation,
            keccak256("m491-legacy-audit-object"),
            defaultEvidenceId,
            keccak256("m491-legacy-audit-hash"),
            "workflow-attestation",
            "ipfs://m491-legacy-audit"
        ) {
            revert("legacy audit path accepted missing authority subject");
        } catch {}
    }

    function testWorkflowAttestationRequiresBoundAuthoritySubject() public {
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("m415-audit-authority-evidence"),
            "ipfs://m415-audit-authority-evidence",
            "workflow-attestation",
            0
        );
        try auditModule.recordAttestation(
            AVADataTypes.Role.Panel,
            DEFAULT_WORKFLOW,
            AVADataTypes.Action.RecordAttestation,
            keccak256("m415-audit-authority-object"),
            evidenceId,
            keccak256("m415-audit-authority-hash"),
            EDITOR_AUTHORITY,
            "workflow-attestation",
            "ipfs://m415-audit-authority"
        ) {
            revert("audit accepted mismatched authority subject");
        } catch {}
        require(auditModule.nextAttestationId() == 1, "mismatched authority created audit record");
    }

    function testM416EvidenceAttestationUsesReceiptPackageAfterWorkflowReregistration() public {
        bytes32 workflowKey = keccak256("m416-audit-evidence");
        _registerRulePackageWithInfrastructure(
            workflowKey,
            evidencePolicyModule,
            auditAdapter,
            editorialSystemAdapter,
            fieldPolicyModule,
            antiAbuseModule,
            "ipfs://m416-audit-old"
        );
        uint256 oldPackageId = rulePackageRegistry.getRulePackage(workflowKey).packageId;
        uint256 oldEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m416-old-audit-evidence"),
            "ipfs://m416-old-audit-evidence",
            "workflow-attestation",
            0
        );

        _registerRulePackageWithInfrastructure(
            workflowKey,
            evidencePolicyModule,
            new RejectingAuditAdapter(),
            editorialSystemAdapter,
            fieldPolicyModule,
            antiAbuseModule,
            "ipfs://m416-audit-new"
        );
        uint256 newPackageId = rulePackageRegistry.getRulePackage(workflowKey).packageId;
        require(newPackageId != oldPackageId, "workflow package was not replaced");

        uint256 oldAttestationId = auditModule.recordAttestation(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVADataTypes.Action.RecordAttestation,
            bytes32(oldEvidenceId),
            oldEvidenceId,
            keccak256("m416-old-attestation"),
            keccak256("panel-authority"),
            "workflow-attestation",
            "ipfs://m416-old-attestation"
        );
        require(auditModule.getAttestation(oldAttestationId).packageId == oldPackageId, "old evidence used active package");

        uint256 newEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m416-new-audit-evidence"),
            "ipfs://m416-new-audit-evidence",
            "workflow-attestation",
            0
        );
        try auditModule.recordAttestation(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVADataTypes.Action.RecordAttestation,
            bytes32(newEvidenceId),
            newEvidenceId,
            keccak256("m416-new-attestation"),
            keccak256("panel-authority"),
            "workflow-attestation",
            "ipfs://m416-new-attestation"
        ) {
            revert("new evidence did not use new rejecting package");
        } catch {}
    }

    function testM416TargetBoundAttestationsUseTargetPackageAfterWorkflowReregistration() public {
        bytes32 workflowKey = keccak256("m416-audit-target");
        _registerRulePackageWithInfrastructure(
            workflowKey,
            evidencePolicyModule,
            auditAdapter,
            editorialSystemAdapter,
            fieldPolicyModule,
            antiAbuseModule,
            "ipfs://m416-target-old"
        );
        AVARulePackageRegistry.RulePackage memory oldPackage = rulePackageRegistry.getRulePackage(workflowKey);
        uint256 oldStateId = _createChallengeableReviewStateThroughPackage(oldPackage, workflowKey);
        uint256 oldStateTransitionId = stateMachine.nextRecognisedStateTransitionId() - 1;
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            workflowKey,
            keccak256("m416-target-challenge-evidence"),
            "ipfs://m416-target-challenge-evidence",
            "review-quality-challenge",
            0
        );
        uint256 challengeId = challengerActor.fileChallenge(
            stateMachine, AVADataTypes.Role.Challenger, workflowKey, oldStateId, CHALLENGER_SUBJECT, challengeEvidenceId, 0
        );
        stateMachine.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        uint256 oldChallengeTransitionId = stateMachine.nextChallengeTransitionId() - 1;

        _registerRulePackageWithInfrastructure(
            workflowKey,
            evidencePolicyModule,
            new RejectingAuditAdapter(),
            editorialSystemAdapter,
            fieldPolicyModule,
            antiAbuseModule,
            "ipfs://m416-target-new"
        );

        uint256 stateAuditId = auditModule.recordRecognisedStateAttestation(
            AVADataTypes.Role.Panel,
            oldStateId,
            keccak256("m416-state-audit"),
            keccak256("panel-authority"),
            "recognised-state-attestation",
            "ipfs://m416-state-audit"
        );
        require(auditModule.getAttestation(stateAuditId).packageId == oldPackage.packageId, "old state used active package");

        uint256 stateTransitionAuditId = auditModule.recordRecognisedStateTransitionAttestation(
            AVADataTypes.Role.Panel,
            oldStateTransitionId,
            keccak256("m416-state-transition-audit"),
            keccak256("panel-authority"),
            "recognised-state-transition-attestation",
            "ipfs://m416-state-transition-audit"
        );
        require(
            auditModule.getAttestation(stateTransitionAuditId).packageId == oldPackage.packageId,
            "old recognised-state transition used active package"
        );

        uint256 challengeTransitionAuditId = auditModule.recordChallengeTransitionAttestation(
            AVADataTypes.Role.Panel,
            oldChallengeTransitionId,
            keccak256("m416-challenge-transition-audit"),
            keccak256("panel-authority"),
            "challenge-transition-attestation",
            "ipfs://m416-challenge-transition-audit"
        );
        require(
            auditModule.getAttestation(challengeTransitionAuditId).packageId == oldPackage.packageId,
            "old challenge transition used active package"
        );

        AVARulePackageRegistry.RulePackage memory newPackage = rulePackageRegistry.getRulePackage(workflowKey);
        uint256 newStateId = _createChallengeableReviewStateThroughPackage(newPackage, workflowKey);
        try auditModule.recordRecognisedStateAttestation(
            AVADataTypes.Role.Panel,
            newStateId,
            keccak256("m416-new-state-audit"),
            keccak256("panel-authority"),
            "recognised-state-attestation",
            "ipfs://m416-new-state-audit"
        ) {
            revert("new state did not use new rejecting package");
        } catch {}
    }

    function testM491EditorialAdapterIsOptionalAndDoesNotCreatePublicationLogic() public {
        bytes32 workflowKey = keccak256("m491-editorial");
        _registerRulePackageWithInfrastructure(
            workflowKey,
            evidencePolicyModule,
            auditAdapter,
            new RejectingEditorialSystemAdapter(),
            fieldPolicyModule,
            antiAbuseModule,
            "ipfs://m491-editorial"
        );
        try stateMachine.registerManuscript(
            AVADataTypes.Role.Author,
            workflowKey,
            keccak256("m491-editorial-manuscript"),
            "ipfs://m491-editorial-manuscript",
            "editorial-system://submission-1"
        ) {
            revert("editorial adapter did not block external reference");
        } catch {}

        uint256 manuscriptId = stateMachine.registerManuscript(
            AVADataTypes.Role.Author,
            workflowKey,
            keccak256("m491-editorial-manuscript-no-ref"),
            "ipfs://m491-editorial-manuscript-no-ref",
            ""
        );
        require(stateMachine.getManuscript(manuscriptId).id == manuscriptId, "optional editorial reference failed");
        bytes32 unknownWorkflowKey = keccak256("m491-unknown-editorial-workflow");
        uint256 nextManuscriptId = stateMachine.nextManuscriptId();
        try stateMachine.registerManuscript(
            AVADataTypes.Role.Author,
            unknownWorkflowKey,
            keccak256("m491-unknown-editorial-manuscript"),
            "ipfs://m491-unknown-editorial-manuscript",
            ""
        ) {
            revert("workflow manuscript accepted unknown package");
        } catch {}
        require(stateMachine.nextManuscriptId() == nextManuscriptId, "unknown workflow created manuscript");
        _assertNoSelector(address(stateMachine), "acceptManuscript(uint256)");
        _assertNoSelector(address(stateMachine), "decideEditorialOutcome(uint256)");
        _assertNoSelector(address(rulePackageRegistry.getRulePackage(workflowKey).editorialSystemAdapter), "acceptManuscript(uint256)");
    }

    function testM416ResidualEditorialAuthorityModuleIsReplaceableAndProceduralOnly() public {
        bytes32 workflowKey = keccak256("m416-residual-editorial");
        _registerRulePackageWithResidualAuthority(
            workflowKey,
            new RejectingResidualEditorialAuthorityModule(AVADataTypes.Action.OpenChallengeWindow),
            "ipfs://m416-residual-editorial"
        );
        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m416-residual-review-evidence"),
            "ipfs://m416-residual-review-evidence",
            "review-service-occurrence",
            0
        );
        uint256 reviewContributionId = reviewerActor.registerReviewContributionWithWorkflow(
            stateMachine, AVADataTypes.Role.Reviewer, workflowKey, manuscriptId, REVIEWER_SUBJECT, evidenceId, 0
        );
        uint256 recognisedStateId =
            stateMachine.provisionallyRecogniseReview(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);
        try stateMachine.openReviewChallengeWindow(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY) {
            revert("residual editorial authority module did not block procedure");
        } catch {}
        require(
            stateMachine.getRecognisedState(recognisedStateId).status == AVADataTypes.RecognisedStateStatus.Provisional,
            "blocked residual action mutated state"
        );

        IResidualEditorialAuthorityModule exampleModule =
            new ProceduralEditorialAuthorityModule(AVADataTypes.Action.OpenChallengeWindow);
        exampleModule.validateResidualEditorialAuthority(
            IResidualEditorialAuthorityModule.ResidualEditorialAuthorityContext({
                workflowKey: workflowKey,
                actingRole: AVADataTypes.Role.Editor,
                action: AVADataTypes.Action.OpenChallengeWindow,
                recognisedStateId: recognisedStateId,
                objectId: bytes32(reviewContributionId),
                evidenceReceiptId: evidenceId,
                authorityId: EDITOR_AUTHORITY,
                actor: address(this)
            })
        );
        _assertNoSelector(address(exampleModule), "acceptManuscript(uint256)");
        _assertNoSelector(address(exampleModule), "rejectManuscript(uint256)");
        _assertNoSelector(address(exampleModule), "scoreManuscriptMerit(uint256)");
        _assertNoSelector(address(exampleModule), "grantPublicationPriority(uint256)");
    }

    function testM416ResidualAuthorityPolicyModulesExpressProceduralAuthorityShapes() public {
        bytes32 workflowKey = keccak256("m416-structured-residual-authority");
        bytes32 panelAuthority = keccak256("panel-authority");
        bytes32 secondPanelSigner = keccak256("second-panel-signer");
        bytes32 institutionalSigner = keccak256("institutional-cosigner");
        IResidualEditorialAuthorityModule.ResidualEditorialAuthorityContext memory context =
        IResidualEditorialAuthorityModule.ResidualEditorialAuthorityContext({
            workflowKey: workflowKey,
            actingRole: AVADataTypes.Role.Editor,
            action: AVADataTypes.Action.OpenChallengeWindow,
            recognisedStateId: 1,
            objectId: keccak256("m416-authority-object"),
            evidenceReceiptId: 1,
            authorityId: EDITOR_AUTHORITY,
            actor: address(this)
        });

        IResidualEditorialAuthorityModule singleRole = new StructuredResidualEditorialAuthorityModule(
            StructuredResidualEditorialAuthorityModule.PolicyKind.SingleRole,
            AVADataTypes.Role.Editor,
            AVADataTypes.Action.OpenChallengeWindow,
            EDITOR_AUTHORITY,
            bytes32(0),
            0,
            0,
            false
        );
        singleRole.validateResidualEditorialAuthority(context);

        context.actingRole = AVADataTypes.Role.Panel;
        context.action = AVADataTypes.Action.ResolveChallenge;
        context.authorityId = panelAuthority;
        IResidualEditorialAuthorityModule thresholdPanel = new StructuredResidualEditorialAuthorityModule(
            StructuredResidualEditorialAuthorityModule.PolicyKind.ThresholdPanel,
            AVADataTypes.Role.Panel,
            AVADataTypes.Action.ResolveChallenge,
            panelAuthority,
            bytes32(0),
            2,
            2,
            false
        );
        thresholdPanel.validateResidualEditorialAuthority(context);

        IResidualEditorialAuthorityModule underThresholdPanel = new StructuredResidualEditorialAuthorityModule(
            StructuredResidualEditorialAuthorityModule.PolicyKind.ThresholdPanel,
            AVADataTypes.Role.Panel,
            AVADataTypes.Action.ResolveChallenge,
            panelAuthority,
            bytes32(0),
            3,
            2,
            false
        );
        try underThresholdPanel.validateResidualEditorialAuthority(context) {
            revert("under-threshold panel authority passed");
        } catch {}

        IResidualEditorialAuthorityModule multisig = new StructuredResidualEditorialAuthorityModule(
            StructuredResidualEditorialAuthorityModule.PolicyKind.Multisig,
            AVADataTypes.Role.Panel,
            AVADataTypes.Action.ResolveChallenge,
            panelAuthority,
            secondPanelSigner,
            0,
            2,
            false
        );
        multisig.validateResidualEditorialAuthority(context);

        IResidualEditorialAuthorityModule institutionCosign = new StructuredResidualEditorialAuthorityModule(
            StructuredResidualEditorialAuthorityModule.PolicyKind.InstitutionalCoSignature,
            AVADataTypes.Role.Panel,
            AVADataTypes.Action.ResolveChallenge,
            panelAuthority,
            institutionalSigner,
            0,
            0,
            false
        );
        institutionCosign.validateResidualEditorialAuthority(context);

        IResidualEditorialAuthorityModule conflictExcluded = new StructuredResidualEditorialAuthorityModule(
            StructuredResidualEditorialAuthorityModule.PolicyKind.ConflictExcludedPanel,
            AVADataTypes.Role.Panel,
            AVADataTypes.Action.ResolveChallenge,
            bytes32(0),
            secondPanelSigner,
            0,
            0,
            false
        );
        conflictExcluded.validateResidualEditorialAuthority(context);
        context.authorityId = secondPanelSigner;
        try conflictExcluded.validateResidualEditorialAuthority(context) {
            revert("conflicted panel authority passed");
        } catch {}
        context.authorityId = panelAuthority;

        IResidualEditorialAuthorityModule emergencyPause = new StructuredResidualEditorialAuthorityModule(
            StructuredResidualEditorialAuthorityModule.PolicyKind.EmergencyPause,
            AVADataTypes.Role.Panel,
            AVADataTypes.Action.TransitionRecognisedState,
            panelAuthority,
            bytes32(0),
            0,
            0,
            true
        );
        context.action = AVADataTypes.Action.TransitionRecognisedState;
        emergencyPause.validateResidualEditorialAuthority(context);

        _assertNoSelector(address(thresholdPanel), "acceptManuscript(uint256)");
        _assertNoSelector(address(multisig), "setManuscriptMerit(uint256,uint256)");
        _assertNoSelector(address(institutionCosign), "revealIdentity(uint256)");
        _assertNoSelector(address(emergencyPause), "executeSanction(uint256)");
    }

    function testM416ApprovalReceiptAuthorityRequiresThresholdAndContextBoundApprovals() public {
        Actor panelA = new Actor();
        Actor panelB = new Actor();
        bytes32 panelAId = keccak256("approval-panel-a");
        bytes32 panelBId = keccak256("approval-panel-b");
        roleRegistry.assignRole(address(panelA), AVADataTypes.Role.Panel, panelAId, "ipfs://approval-panel-a");
        roleRegistry.assignRole(address(panelB), AVADataTypes.Role.Panel, panelBId, "ipfs://approval-panel-b");
        ApprovalAuthorityContext memory context = _createApprovalAuthorityContext("m416-approval-threshold", 2, bytes32(0));

        try panelA.resolveChallenge(
            stateMachine,
            AVADataTypes.Role.Panel,
            context.challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            panelAId,
            "ipfs://approval-resolve-without-receipts"
        ) {
            revert("approval-backed authority accepted zero receipts");
        } catch {}

        _recordAuthorityApproval(panelA, context, AVADataTypes.Action.ResolveChallenge, context.objectId, panelAId);
        try panelA.recordAuthorityApproval(
            authorityApprovalRegistry,
            AVADataTypes.Role.Panel,
            AuthorityApprovalRegistry.ApprovalInput({
                workflowKey: context.workflowKey,
                packageId: context.packageId,
                action: AVADataTypes.Action.ResolveChallenge,
                recognisedStateId: context.recognisedStateId,
                objectId: context.objectId,
                authorityId: panelAId,
                evidenceReceiptId: context.challengeEvidenceId,
                expiresAt: uint64(block.timestamp + 7 days),
                reasonURI: "ipfs://duplicate-authority-approval"
            })
        ) {
            revert("duplicate approval by same subject counted twice");
        } catch {}
        require(
            authorityApprovalRegistry.approvalCount(
                context.workflowKey,
                context.packageId,
                AVADataTypes.Action.ResolveChallenge,
                context.recognisedStateId,
                context.objectId
            ) == 1,
            "duplicate approval changed count"
        );

        _recordAuthorityApproval(panelB, context, AVADataTypes.Action.CloseChallenge, context.objectId, panelBId);
        try panelA.resolveChallenge(
            stateMachine,
            AVADataTypes.Role.Panel,
            context.challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            panelAId,
            "ipfs://approval-wrong-action"
        ) {
            revert("approval-backed authority replayed wrong action");
        } catch {}

        _recordAuthorityApproval(
            panelB,
            context,
            AVADataTypes.Action.ResolveChallenge,
            bytes32(uint256(context.objectId) + 1),
            panelBId
        );
        try panelA.resolveChallenge(
            stateMachine,
            AVADataTypes.Role.Panel,
            context.challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            panelAId,
            "ipfs://approval-wrong-object"
        ) {
            revert("approval-backed authority replayed wrong object");
        } catch {}

        _recordAuthorityApproval(panelB, context, AVADataTypes.Action.ResolveChallenge, context.objectId, panelBId);
        panelA.resolveChallenge(
            stateMachine,
            AVADataTypes.Role.Panel,
            context.challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            panelAId,
            "ipfs://approval-threshold-met"
        );
        require(
            stateMachine.getChallenge(context.challengeId).outcome == AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            "approval-backed challenge did not resolve"
        );
    }

    function testM416ApprovalReceiptAuthorityRejectsExpiredApprovalThreshold() public {
        Actor panelA = new Actor();
        bytes32 panelAId = keccak256("approval-expired-panel-a");
        roleRegistry.assignRole(address(panelA), AVADataTypes.Role.Panel, panelAId, "ipfs://approval-expired-a");
        ApprovalAuthorityContext memory context = _createApprovalAuthorityContext("m416-approval-expired", 1, bytes32(0));

        panelA.recordAuthorityApproval(
            authorityApprovalRegistry,
            AVADataTypes.Role.Panel,
            AuthorityApprovalRegistry.ApprovalInput({
                workflowKey: context.workflowKey,
                packageId: context.packageId,
                action: AVADataTypes.Action.ResolveChallenge,
                recognisedStateId: context.recognisedStateId,
                objectId: context.objectId,
                authorityId: panelAId,
                evidenceReceiptId: context.challengeEvidenceId,
                expiresAt: uint64(block.timestamp + 1),
                reasonURI: "ipfs://expired-authority-approval"
            })
        );
        vm.warp(block.timestamp + 2);
        require(
            authorityApprovalRegistry.approvalCount(
                context.workflowKey,
                context.packageId,
                AVADataTypes.Action.ResolveChallenge,
                context.recognisedStateId,
                context.objectId
            ) == 0,
            "expired approval still counted"
        );

        try panelA.resolveChallenge(
            stateMachine,
            AVADataTypes.Role.Panel,
            context.challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            panelAId,
            "ipfs://approval-expired-rejected"
        ) {
            revert("expired approval satisfied approval module");
        } catch {}
    }

    function testM416ApprovalReceiptAuthorityRejectsConflictExcludedSubject() public {
        Actor panelA = new Actor();
        Actor panelB = new Actor();
        bytes32 panelAId = keccak256("approval-conflict-panel-a");
        bytes32 panelBId = keccak256("approval-conflict-panel-b");
        roleRegistry.assignRole(address(panelA), AVADataTypes.Role.Panel, panelAId, "ipfs://approval-conflict-a");
        roleRegistry.assignRole(address(panelB), AVADataTypes.Role.Panel, panelBId, "ipfs://approval-conflict-b");
        ApprovalAuthorityContext memory context = _createApprovalAuthorityContext("m416-approval-conflict", 1, panelAId);

        _recordAuthorityApproval(panelA, context, AVADataTypes.Action.ResolveChallenge, context.objectId, panelAId);
        try panelA.resolveChallenge(
            stateMachine,
            AVADataTypes.Role.Panel,
            context.challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            panelAId,
            "ipfs://approval-conflict-rejected"
        ) {
            revert("conflict-excluded authority satisfied approval module");
        } catch {}

        _recordAuthorityApproval(panelB, context, AVADataTypes.Action.ResolveChallenge, context.objectId, panelBId);
        panelB.resolveChallenge(
            stateMachine,
            AVADataTypes.Role.Panel,
            context.challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            panelBId,
            "ipfs://approval-conflict-distinct-panel"
        );
    }

    function testFuzzNoConsequenceWithoutEligibleRecognisedState(uint8 statusSeed) public {
        AVADataTypes.RecognisedStateStatus status = _nonEligibleRecognisedStateStatus(statusSeed);
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            keccak256(abi.encode("fuzz-no-consequence", statusSeed)),
            "ipfs://fuzz-no-consequence",
            "fuzz-invariant-evidence",
            0
        );
        uint256 recognisedStateId;
        if (status != AVADataTypes.RecognisedStateStatus.None) {
            recognisedStateId = _registerRecognisedStateForStatus(status, evidenceId, "fuzz-no-consequence");
        }

        uint256 nextConsequenceId = consequenceExecutor.nextConsequenceId();
        _assertConsequenceRejectsTarget(recognisedStateId, evidenceId);
        require(consequenceExecutor.nextConsequenceId() == nextConsequenceId, "ineligible state wrote consequence");
    }

    function testFuzzVestingImpossibleWhileChallengeIsOpen(bytes32 seed) public {
        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            keccak256(abi.encode("fuzz-open-challenge-review", seed)),
            "ipfs://fuzz-open-challenge-review",
            "review-service-occurrence",
            0
        );
        uint256 reviewContributionId = reviewerActor.registerReviewContribution(
            stateMachine, AVADataTypes.Role.Reviewer, manuscriptId, REVIEWER_SUBJECT, evidenceId, 0
        );
        uint256 recognisedStateId =
            stateMachine.provisionallyRecogniseReview(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);
        stateMachine.openReviewChallengeWindow(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            DEFAULT_WORKFLOW,
            keccak256(abi.encode("fuzz-open-challenge", seed)),
            "ipfs://fuzz-open-challenge",
            "review-quality-challenge",
            0
        );
        challengerActor.fileChallenge(
            stateMachine, AVADataTypes.Role.Challenger, recognisedStateId, CHALLENGER_SUBJECT, challengeEvidenceId, 0
        );

        uint256 nextTransitionId = stateMachine.nextRecognisedStateTransitionId();
        try stateMachine.vestReviewRecognition(
            AVADataTypes.Role.Panel,
            reviewContributionId,
            keccak256("panel-authority"),
            "ipfs://fuzz-vesting-rejected"
        ) {
            revert("open challenge allowed vesting");
        } catch {}
        require(stateMachine.nextRecognisedStateTransitionId() == nextTransitionId, "rejected vesting wrote transition");
        require(
            stateMachine.getRecognisedState(recognisedStateId).status == AVADataTypes.RecognisedStateStatus.Challengeable,
            "open challenge changed recognised state"
        );
    }

    function testFuzzRecognisedStatePackageIdStaysPinnedAfterWorkflowReregistration(bytes32 seed) public {
        bytes32 workflowKey = keccak256(abi.encode("fuzz-package-pin", seed));
        _registerRulePackage(
            workflowKey,
            disclosurePolicyModule,
            allocationAdapter,
            consequenceAdapter,
            "ipfs://fuzz-package-pin-old"
        );
        AVARulePackageRegistry.RulePackage memory oldPackage = rulePackageRegistry.getRulePackage(workflowKey);
        uint256 firstTransitionId = stateMachine.nextRecognisedStateTransitionId();
        uint256 recognisedStateId = _createChallengeableReviewStateThroughPackage(oldPackage, workflowKey);
        uint256 storedPackageId = stateMachine.getRecognisedState(recognisedStateId).packageId;

        _registerRulePackage(
            workflowKey,
            disclosurePolicyModule,
            allocationAdapter,
            consequenceAdapter,
            "ipfs://fuzz-package-pin-new"
        );
        AVARulePackageRegistry.RulePackage memory activePackage = rulePackageRegistry.getRulePackage(workflowKey);

        require(activePackage.packageId != storedPackageId, "workflow did not reregister package");
        require(stateMachine.getRecognisedState(recognisedStateId).packageId == storedPackageId, "old state package changed");
        AVADataTypes.RecognisedStateTransitionRecord memory creationTransition =
            stateMachine.getRecognisedStateTransition(firstTransitionId);
        require(creationTransition.recognisedStateId == recognisedStateId, "creation transition not found");
        require(creationTransition.packageId == storedPackageId, "old transition package changed");
    }

    function testFuzzAtMostOneRecoveryTerminalSettlementPerSourceKey(uint8 terminalSeed) public {
        bytes32 workflowKey = keccak256(abi.encode("fuzz-terminal-settlement", terminalSeed));
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://fuzz-terminal-settlement-workflow");
        MockERC20 token = _m421FundedToken(100);
        uint256 sourceId =
            _createM421RewardSource(workflowKey, "fuzz-terminal-source", token, 8, AVADataTypes.ValueExecutionMode.Claim);

        valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://fuzz-terminal-execution"
        );
        valueSettlementExecutor.recordRepaymentObligation(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://fuzz-terminal-obligation"
        );

        AVADataTypes.ValueSettlementStatus firstTerminal =
            _recordRecoveryTerminalSettlement(sourceId, terminalSeed % 3);
        bytes32 sourceKey = keccak256(abi.encode(AVADataTypes.ExecutionSourceType.AllocationRecord, sourceId));
        uint256 terminalSettlementId = valueSettlementExecutor.recoveryTerminalSettlementIdBySourceKey(sourceKey);
        require(terminalSettlementId != 0, "terminal settlement missing");
        require(
            valueSettlementExecutor.recoveryTerminalStatusBySourceKey(sourceKey) == firstTerminal,
            "terminal status not stored"
        );

        uint256 nextSettlementId = valueSettlementExecutor.nextValueSettlementId();
        for (uint8 i = 0; i < 3; i++) {
            try this.recordRecoveryTerminalForFuzz(sourceId, i) {
                revert("second terminal settlement accepted");
            } catch {}
        }
        require(valueSettlementExecutor.nextValueSettlementId() == nextSettlementId, "second terminal settlement stored");
        require(
            valueSettlementExecutor.recoveryTerminalSettlementIdBySourceKey(sourceKey) == terminalSettlementId,
            "terminal settlement id changed"
        );
    }

    function recordRecoveryTerminalForFuzz(uint256 sourceId, uint8 terminalKind) external returns (uint256) {
        if (terminalKind % 3 == 0) {
            return valueSettlementExecutor.recordFuturePayoutSetoff(
                AVADataTypes.Role.ProtocolExecutor,
                AVADataTypes.ExecutionSourceType.AllocationRecord,
                sourceId,
                keccak256("executor-authority"),
                "ipfs://fuzz-terminal-setoff"
            );
        }
        if (terminalKind % 3 == 1) {
            return valueSettlementExecutor.recordWaiver(
                AVADataTypes.Role.ProtocolExecutor,
                AVADataTypes.ExecutionSourceType.AllocationRecord,
                sourceId,
                keccak256("executor-authority"),
                "ipfs://fuzz-terminal-waiver"
            );
        }
        return valueSettlementExecutor.recordSatisfaction(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://fuzz-terminal-satisfaction"
        );
    }

    function testM416DisclosureLifecycleReadinessIsPackageReplaceableAndRevealFree() public {
        bytes32 workflowKey = keccak256("m416-disclosure-lifecycle");
        uint256 disclosurePolicyId = _registerDisclosurePolicy("m416-disclosure-lifecycle-policy");
        _registerRulePackageWithDisclosureLifecycle(
            workflowKey, disclosureLifecycleModule, "ipfs://m416-disclosure-lifecycle-old"
        );
        uint256 oldPackageId = rulePackageRegistry.getRulePackage(workflowKey).packageId;
        uint256 readinessId = rulePackageRegistry.recordDisclosureLifecycleReadiness(
            AVADataTypes.Role.Panel,
            workflowKey,
            disclosurePolicyId,
            AVADataTypes.DisclosureLifecycleKind.PolicyBoundReady,
            keccak256("m416-disclosure-lifecycle-ref"),
            keccak256("panel-authority"),
            "ipfs://m416-disclosure-lifecycle"
        );
        AVADataTypes.DisclosureLifecycleRecord memory readiness =
            rulePackageRegistry.getDisclosureLifecycleRecord(readinessId);
        require(readiness.packageId == oldPackageId, "disclosure lifecycle used wrong package");

        _registerRulePackageWithDisclosureLifecycle(
            workflowKey,
            new RejectingDisclosureLifecycleModule(AVADataTypes.DisclosureLifecycleKind.PostRecognitionDisclosureReady),
            "ipfs://m416-disclosure-lifecycle-new"
        );
        uint256 newPackageId = rulePackageRegistry.getRulePackage(workflowKey).packageId;
        try rulePackageRegistry.recordDisclosureLifecycleReadiness(
            AVADataTypes.Role.Panel,
            workflowKey,
            disclosurePolicyId,
            AVADataTypes.DisclosureLifecycleKind.PostRecognitionDisclosureReady,
            keccak256("m416-disclosure-lifecycle-reject"),
            keccak256("panel-authority"),
            "ipfs://m416-disclosure-lifecycle-reject"
        ) {
            revert("disclosure lifecycle module did not reject replaced package path");
        } catch {}
        uint256 acceptedNewReadinessId = rulePackageRegistry.recordDisclosureLifecycleReadiness(
            AVADataTypes.Role.Panel,
            workflowKey,
            disclosurePolicyId,
            AVADataTypes.DisclosureLifecycleKind.ZKProofReceiptReady,
            keccak256("m416-disclosure-lifecycle-new-ref"),
            keccak256("panel-authority"),
            "ipfs://m416-disclosure-lifecycle-new"
        );
        require(
            rulePackageRegistry.getDisclosureLifecycleRecord(acceptedNewReadinessId).packageId == newPackageId,
            "new disclosure lifecycle did not use active package"
        );
        _assertNoSelector(address(rulePackageRegistry), "revealIdentity(uint256)");
        _assertNoSelector(address(rulePackageRegistry), "revealEvidence(uint256)");
        _assertNoSelector(address(rulePackageRegistry), "decryptEvidence(uint256)");
        _assertNoSelector(address(rulePackageRegistry.getRulePackage(workflowKey).disclosureLifecycleModule), "revealIdentity(uint256)");
    }

    function testM417DisclosureLifecycleReadinessRequiresRegisteredPolicyAtSubstrate() public {
        bytes32 workflowKey = keccak256("m417-disclosure-lifecycle");
        uint256 disclosurePolicyId = _registerDisclosurePolicy("m417-disclosure-lifecycle-policy");
        uint256 unknownDisclosurePolicyId = disclosurePolicyId + 1000;
        _registerRulePackageWithDisclosureLifecycle(
            workflowKey,
            new RejectingDisclosureLifecycleModule(AVADataTypes.DisclosureLifecycleKind.ZKProofReceiptReady),
            "ipfs://m417-disclosure-lifecycle"
        );

        try rulePackageRegistry.recordDisclosureLifecycleReadiness(
            AVADataTypes.Role.Panel,
            workflowKey,
            unknownDisclosurePolicyId,
            AVADataTypes.DisclosureLifecycleKind.PolicyBoundReady,
            keccak256("m417-disclosure-lifecycle-unknown-policy"),
            keccak256("panel-authority"),
            "ipfs://m417-disclosure-lifecycle-unknown-policy"
        ) {
            revert("disclosure lifecycle accepted unknown policy before module");
        } catch {}

        uint256 readinessId = rulePackageRegistry.recordDisclosureLifecycleReadiness(
            AVADataTypes.Role.Panel,
            workflowKey,
            disclosurePolicyId,
            AVADataTypes.DisclosureLifecycleKind.PolicyBoundReady,
            keccak256("m417-disclosure-lifecycle-registered-policy"),
            keccak256("panel-authority"),
            "ipfs://m417-disclosure-lifecycle-registered-policy"
        );
        require(
            rulePackageRegistry.getDisclosureLifecycleRecord(readinessId).disclosurePolicyId == disclosurePolicyId,
            "registered policy not recorded"
        );

        try rulePackageRegistry.recordDisclosureLifecycleReadiness(
            AVADataTypes.Role.Panel,
            workflowKey,
            disclosurePolicyId,
            AVADataTypes.DisclosureLifecycleKind.ZKProofReceiptReady,
            keccak256("m417-disclosure-lifecycle-module-reject"),
            keccak256("panel-authority"),
            "ipfs://m417-disclosure-lifecycle-module-reject"
        ) {
            revert("disclosure lifecycle module-specific rejection bypassed");
        } catch {}
    }

    function testM418RulePackageLifecycleSeesModulesHashAndBlocksIncompatiblePackage() public {
        bytes32 workflowKey = keccak256("m418-lifecycle-hash");
        bytes32 compatibilityKey = keccak256("m418-compatible");
        ModulesHashGateRulePackageLifecycleModule lifecycleModule =
            new ModulesHashGateRulePackageLifecycleModule(compatibilityKey);
        AVARulePackageRegistry.RulePackageModules memory modules = AVARulePackageRegistry.RulePackageModules({
            attributionModule: attributionModule,
            verificationModule: verificationModule,
            allocationModule: allocationAdapter,
            transitionRuleModule: transitionRuleModule,
            disclosureModule: disclosurePolicyModule,
            standingAdapter: standingAdapter,
            consequenceAdapter: consequenceAdapter,
            rewardAdapter: rewardAdapter,
            priorityAdapter: priorityAdapter,
            penaltyAdapter: penaltyAdapter,
            restorationAdapter: restorationAdapter,
            challengeLifecycleModule: challengeLifecycleModule,
            evidencePolicyModule: evidencePolicyModule,
            auditAdapter: auditAdapter,
            editorialSystemAdapter: editorialSystemAdapter,
            residualEditorialAuthorityModule: residualEditorialAuthorityModule,
            fieldPolicyModule: fieldPolicyModule,
            antiAbuseModule: antiAbuseModule,
            valueExecutionAdapter: valueExecutionAdapter,
            standingComputationModule: standingComputationModule,
            rulePackageLifecycleModule: lifecycleModule,
            evidenceLifecycleModule: evidenceLifecycleModule,
            disclosureLifecycleModule: disclosureLifecycleModule,
                disclosureExecutionModule: disclosureExecutionModule,
            version: 1,
            compatibilityKey: compatibilityKey,
            dependencyURI: "ipfs://m418-lifecycle-dependencies",
            deprecated: false
        });

        lifecycleModule.setExpectedModulesHash(keccak256("wrong-modules"));
        try rulePackageRegistry.registerRulePackage(
            AVADataTypes.Role.Panel, workflowKey, modules, "ipfs://m418-incompatible"
        ) {
            revert("incompatible lifecycle module did not reject package registration");
        } catch {}

        bytes32 modulesHash = rulePackageRegistry.hashModules(modules);
        lifecycleModule.setExpectedModulesHash(modulesHash);
        rulePackageRegistry.registerRulePackage(AVADataTypes.Role.Panel, workflowKey, modules, "ipfs://m418-compatible");
        AVARulePackageRegistry.RulePackage memory rulePackage = rulePackageRegistry.getRulePackage(workflowKey);
        require(rulePackage.modulesHash == modulesHash, "modules hash not bound to package");
    }

    function testM418PermissiveModulesCannotBypassSubstrateHardGates() public {
        bytes32 workflowKey = keccak256("m418-permissive-hard-gates");
        _registerRulePackageWithLifecycle(
            workflowKey, new PermissiveChallengeLifecycleModule(), "ipfs://m418-permissive-hard-gates"
        );
        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m418-permissive-review-evidence"),
            "ipfs://m418-permissive-review-evidence",
            "review-service-occurrence",
            0
        );
        try reviewerActor.registerReviewContributionWithWorkflow(
            stateMachine,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            manuscriptId,
            CHALLENGER_SUBJECT,
            evidenceId,
            0
        ) {
            revert("permissive package bypassed reviewer subject binding");
        } catch {}

        uint256 reviewContributionId = reviewerActor.registerReviewContributionWithWorkflow(
            stateMachine, AVADataTypes.Role.Reviewer, workflowKey, manuscriptId, REVIEWER_SUBJECT, evidenceId, 0
        );
        try stateMachine.provisionallyRecogniseReview(
            AVADataTypes.Role.Editor, reviewContributionId, keccak256("wrong-editor-authority")
        ) {
            revert("permissive package bypassed authorityId binding");
        } catch {}
        uint256 recognisedStateId =
            stateMachine.provisionallyRecogniseReview(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);
        stateMachine.openReviewChallengeWindow(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);

        try challengerActor.fileChallenge(
            stateMachine,
            AVADataTypes.Role.Challenger,
            workflowKey,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            evidenceId + 999,
            0
        ) {
            revert("permissive package bypassed evidence existence");
        } catch {}
        try stateMachine.resolveChallenge(
            AVADataTypes.Role.Panel,
            1,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Restored,
            keccak256("panel-authority"),
            "ipfs://m418-invalid-resolution"
        ) {
            revert("permissive package bypassed challenge existence");
        } catch {}
        try stateMachine.transitionRecognisedState(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            keccak256("panel-authority"),
            "ipfs://m418-generic-downgrade"
        ) {
            revert("permissive package bypassed high-impact transition gate");
        } catch {}
    }

    function testM418ActivePermissivePackageCannotRewriteTargetPackageGate() public {
        bytes32 workflowKey = keccak256("m418-package-gate");
        _registerRulePackageWithLifecycle(
            workflowKey,
            new RejectingChallengeLifecycleModule(AVADataTypes.Action.FileChallenge),
            "ipfs://m418-package-gate-rejecting"
        );
        AVARulePackageRegistry.RulePackage memory originalPackage = rulePackageRegistry.getRulePackage(workflowKey);
        uint256 recognisedStateId = _createChallengeableReviewStateThroughPackage(originalPackage, workflowKey);

        _registerRulePackageWithLifecycle(
            workflowKey, new PermissiveChallengeLifecycleModule(), "ipfs://m418-package-gate-permissive"
        );
        AVADataTypes.RecognisedStateRecord memory recognisedState = stateMachine.getRecognisedState(recognisedStateId);
        require(recognisedState.packageId == originalPackage.packageId, "target package was rewritten");
        require(
            rulePackageRegistry.getRulePackage(workflowKey).packageId != recognisedState.packageId,
            "workflow package was not replaced"
        );

        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            workflowKey,
            keccak256("m418-package-gate-challenge"),
            "ipfs://m418-package-gate-challenge",
            "review-quality-challenge",
            0
        );
        uint256 nextChallengeId = stateMachine.nextChallengeId();
        try challengerActor.fileChallenge(
            stateMachine,
            AVADataTypes.Role.Challenger,
            workflowKey,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            0
        ) {
            revert("active permissive package bypassed target package gate");
        } catch {}
        require(stateMachine.nextChallengeId() == nextChallengeId, "challenge storage mutated after package-gate reject");
    }

    function testM418RejectingModuleFailsClosedBeforeStorageChange() public {
        bytes32 workflowKey = keccak256("m418-rejecting-fail-closed");
        _registerRulePackageWithLifecycle(
            workflowKey,
            new RejectingChallengeLifecycleModule(AVADataTypes.Action.FileChallenge),
            "ipfs://m418-rejecting-fail-closed"
        );
        AVARulePackageRegistry.RulePackage memory rulePackage = rulePackageRegistry.getRulePackage(workflowKey);
        uint256 recognisedStateId = _createChallengeableReviewStateThroughPackage(rulePackage, workflowKey);
        uint256 evidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            workflowKey,
            keccak256("m418-rejecting-challenge-evidence"),
            "ipfs://m418-rejecting-challenge-evidence",
            "review-quality-challenge",
            0
        );
        uint256 nextChallengeId = stateMachine.nextChallengeId();

        try challengerActor.fileChallenge(
            stateMachine,
            AVADataTypes.Role.Challenger,
            workflowKey,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            evidenceId,
            0
        ) {
            revert("rejecting challenge lifecycle module did not fail closed");
        } catch {}
        require(stateMachine.nextChallengeId() == nextChallengeId, "challenge storage mutated after module rejection");
    }

    function testM418DisclosureAndResidualModulesCannotExposeForbiddenExecutionSelectors() public {
        _assertNoSelector(address(disclosurePolicyModule), "revealIdentity(uint256)");
        _assertNoSelector(address(disclosurePolicyModule), "revealEvidence(uint256)");
        _assertNoSelector(address(disclosurePolicyModule), "decryptEvidence(uint256)");
        _assertNoSelector(address(disclosureLifecycleModule), "revealIdentity(uint256)");
        _assertNoSelector(address(disclosureLifecycleModule), "decryptEvidence(uint256)");
        _assertNoSelector(address(residualEditorialAuthorityModule), "acceptManuscript(uint256)");
        _assertNoSelector(address(residualEditorialAuthorityModule), "rejectManuscript(uint256)");
        _assertNoSelector(address(residualEditorialAuthorityModule), "scoreManuscriptMerit(uint256)");
        _assertNoSelector(address(residualEditorialAuthorityModule), "grantPublicationPriority(uint256)");
    }

    function testM418DownstreamAdaptersRemainSeparatedAndRecordOnly() public {
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            keccak256("m418-downstream-evidence"),
            "ipfs://m418-downstream-evidence",
            "downstream-record-basis",
            0
        );
        uint256 recognisedStateId = _registerRecognisedStateForWorkflowStatus(
            DEFAULT_WORKFLOW, AVADataTypes.RecognisedStateStatus.Vested, evidenceId, "m418-downstream-state"
        );
        uint256 nextConsequenceId = consequenceExecutor.nextConsequenceId();
        uint256 rewardId = allocationExecutor.recordRewardValue(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://m418-reward-record"
        );
        uint256 priorityId = allocationExecutor.recordAdministrativePriority(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://m418-priority-record"
        );
        require(
            allocationExecutor.getAllocationExecution(rewardId).allocationKind
                == AVADataTypes.AllocationKind.RewardValueRecord,
            "reward adapter wrote wrong allocation record"
        );
        require(
            allocationExecutor.getAllocationExecution(priorityId).allocationKind
                == AVADataTypes.AllocationKind.AdministrativeQueueRecord,
            "priority adapter wrote wrong allocation record"
        );
        require(consequenceExecutor.nextConsequenceId() == nextConsequenceId, "allocation path created consequence");

        uint256 nextAllocationId = allocationExecutor.nextAllocationExecutionId();
        uint256 penaltyId = consequenceExecutor.recordPenalty(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://m418-penalty-record"
        );
        uint256 restorationId = consequenceExecutor.recordRestoration(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://m418-restoration-record"
        );
        require(
            consequenceExecutor.getConsequence(penaltyId).kind == AVADataTypes.ConsequenceKind.PenaltyRecord,
            "penalty adapter wrote wrong consequence record"
        );
        require(
            consequenceExecutor.getConsequence(restorationId).kind == AVADataTypes.ConsequenceKind.RestorationRecord,
            "restoration adapter wrote wrong consequence record"
        );
        require(allocationExecutor.nextAllocationExecutionId() == nextAllocationId, "consequence path created allocation");
    }

    function testM426GenericAllocationCannotBypassRewardOrPriorityAdapters() public {
        bytes32 workflowKey = keccak256("m426-generic-allocation-bypass");
        _registerRulePackageWithAdapters(
            workflowKey,
            allocationAdapter,
            consequenceAdapter,
            standingAdapter,
            new MockRewardAdapter(7),
            new MockPriorityAdapter(7),
            penaltyAdapter,
            restorationAdapter,
            "ipfs://m426-generic-allocation-bypass"
        );
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m426-generic-allocation-evidence"),
            "ipfs://m426-generic-allocation-evidence",
            "allocation-bypass-basis",
            0
        );
        uint256 recognisedStateId = _registerRecognisedStateForWorkflowStatus(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, evidenceId, "m426-generic-allocation-state"
        );
        uint256 nextAllocationId = allocationExecutor.nextAllocationExecutionId();

        try allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            AVADataTypes.AllocationKind.RewardValueRecord,
            REVIEWER_SUBJECT,
            7,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://m426-generic-reward-bypass"
        ) {
            revert("generic allocation bypassed reward adapter");
        } catch {}
        try allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            AVADataTypes.AllocationKind.AdministrativeQueueRecord,
            REVIEWER_SUBJECT,
            7,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://m426-generic-priority-bypass"
        ) {
            revert("generic allocation bypassed priority adapter");
        } catch {}
        require(allocationExecutor.nextAllocationExecutionId() == nextAllocationId, "generic downstream allocation stored");
    }

    function testM426GenericConsequenceCannotBypassPenaltyOrRestorationAdapters() public {
        bytes32 workflowKey = keccak256("m426-generic-consequence-bypass");
        bytes32 blockedAuthorityId = keccak256("panel-authority");
        _registerRulePackageWithAdapters(
            workflowKey,
            allocationAdapter,
            consequenceAdapter,
            standingAdapter,
            rewardAdapter,
            priorityAdapter,
            new MockPenaltyAdapter(blockedAuthorityId),
            new MockRestorationAdapter(blockedAuthorityId),
            "ipfs://m426-generic-consequence-bypass"
        );
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m426-generic-consequence-evidence"),
            "ipfs://m426-generic-consequence-evidence",
            "consequence-bypass-basis",
            0
        );
        uint256 recognisedStateId = _registerRecognisedStateForWorkflowStatus(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, evidenceId, "m426-generic-consequence-state"
        );
        uint256 nextConsequenceId = consequenceExecutor.nextConsequenceId();

        try consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            AVADataTypes.ConsequenceKind.PenaltyRecord,
            REVIEWER_SUBJECT,
            evidenceId,
            blockedAuthorityId,
            "ipfs://m426-generic-penalty-bypass"
        ) {
            revert("generic consequence bypassed penalty adapter");
        } catch {}
        try consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            AVADataTypes.ConsequenceKind.RestorationRecord,
            REVIEWER_SUBJECT,
            evidenceId,
            blockedAuthorityId,
            "ipfs://m426-generic-restoration-bypass"
        ) {
            revert("generic consequence bypassed restoration adapter");
        } catch {}
        require(consequenceExecutor.nextConsequenceId() == nextConsequenceId, "generic specialised consequence stored");
    }

    function testM418ParameterizedValueExecutionRemainsRecordOnly() public {
        bytes32 workflowKey = keccak256("m418-parameterized-value");
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            new ClaimEscrowRecordValueAdapter(),
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m4-10-compatible"),
            false,
            "ipfs://m418-parameterized-value"
        );
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m418-parameterized-value-evidence"),
            "ipfs://m418-parameterized-value-evidence",
            "value-record-basis",
            0
        );
        uint256 recognisedStateId = _registerRecognisedStateForWorkflowStatus(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, evidenceId, "m418-parameterized-value-state"
        );
        uint256 nextConsequenceId = consequenceExecutor.nextConsequenceId();
        uint256 executorBalanceBefore = address(allocationExecutor).balance;

        uint256 recordId = allocationExecutor.recordRewardValueWithExecution(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ValueExecutionContext({
                recognisedStateId: recognisedStateId,
                asset: address(0xA11CE),
                payer: address(this),
                recipientSubjectId: REVIEWER_SUBJECT,
                amount: 1,
                mode: AVADataTypes.ValueExecutionMode.Claim,
                settlementKind: AVADataTypes.ValueSettlementKind.TokenTransfer,
                executionReference: keccak256("m418-claim-record"),
                authorityId: keccak256("executor-authority"),
                evidenceReceiptId: evidenceId,
                uri: "ipfs://m418-claim-record",
                actor: address(this)
            })
        );
        AVADataTypes.AllocationExecutionRecord memory record = allocationExecutor.getAllocationExecution(recordId);
        require(record.executionMode == AVADataTypes.ValueExecutionMode.Claim, "nondefault mode not recorded");
        require(record.asset == address(0xA11CE), "asset reference not recorded");
        require(address(allocationExecutor).balance == executorBalanceBefore, "value adapter transferred value");
        require(consequenceExecutor.nextConsequenceId() == nextConsequenceId, "value adapter created consequence");
        _assertNoSelector(address(rulePackageRegistry.getRulePackage(workflowKey).valueExecutionAdapter), "transferToken(uint256)");
        _assertNoSelector(address(rulePackageRegistry.getRulePackage(workflowKey).valueExecutionAdapter), "executeQueue(uint256)");
        _assertNoSelector(address(rulePackageRegistry.getRulePackage(workflowKey).valueExecutionAdapter), "executeSanction(uint256)");
    }

    function testM419CustomModulesImplementInterfacesAndSwapWithoutSubstrateChange() public {
        bytes32 workflowKey = keccak256("m419-custom-interface-package");
        AVARulePackageRegistry.RulePackageModules memory modules = _m419CustomInterfaceModules();
        rulePackageRegistry.registerRulePackage(
            AVADataTypes.Role.Panel, workflowKey, modules, "ipfs://m419-custom-interface-package"
        );
        AVARulePackageRegistry.RulePackage memory rulePackage = rulePackageRegistry.getRulePackage(workflowKey);
        require(rulePackage.modulesHash == rulePackageRegistry.hashModules(modules), "custom modules hash mismatch");
        IAllocationAdapter allocationInterface = modules.allocationModule;
        IZKProofVerifier proofVerifier = new SchnorrDisclosureProofVerifier();
        require(address(allocationInterface) == address(modules.allocationModule), "allocation ABI mismatch");
        require(address(proofVerifier) != address(0), "zk verifier ABI missing");

        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m419-interface-evidence"),
            "ipfs://m419-interface-evidence",
            "m419-interface-evidence",
            0
        );
        uint256 recognisedStateId = stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            keccak256("m419-interface-object"),
            REVIEWER_SUBJECT,
            evidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        );
        stateMachine.transitionRecognisedState(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            AVADataTypes.RecognisedStateStatus.Vested,
            keccak256("panel-authority"),
            "ipfs://m419-interface-transition"
        );

        AVADataTypes.RecognisedStateRecord memory recognisedState = stateMachine.getRecognisedState(recognisedStateId);
        require(recognisedState.packageId == rulePackage.packageId, "substrate did not bind custom package");
        require(
            recognisedState.status == AVADataTypes.RecognisedStateStatus.Vested,
            "custom modules blocked compatible substrate path"
        );
    }

    function testM410FutureProofInterfacesHaveDefaultsAndRecordOnlyValueMode() public {
        valueExecutionAdapter.validateValueExecution(
            AVADataTypes.ValueExecutionContext({
                recognisedStateId: 1,
                asset: address(0),
                payer: address(0),
                recipientSubjectId: REVIEWER_SUBJECT,
                amount: 1,
                mode: AVADataTypes.ValueExecutionMode.RecordOnly,
                settlementKind: AVADataTypes.ValueSettlementKind.None,
                executionReference: keccak256("m410-value-record"),
                authorityId: keccak256("authority"),
                evidenceReceiptId: 1,
                uri: "ipfs://m410-value",
                actor: address(this)
            })
        );
        try valueExecutionAdapter.validateValueExecution(
            AVADataTypes.ValueExecutionContext({
                recognisedStateId: 1,
                asset: address(0),
                payer: address(0),
                recipientSubjectId: REVIEWER_SUBJECT,
                amount: 1,
                mode: AVADataTypes.ValueExecutionMode.Claim,
                settlementKind: AVADataTypes.ValueSettlementKind.TokenTransfer,
                executionReference: keccak256("m410-claim"),
                authorityId: keccak256("authority"),
                evidenceReceiptId: 1,
                uri: "ipfs://m410-claim",
                actor: address(this)
            })
        ) {
            revert("default value adapter accepted executable mode");
        } catch {}

        standingComputationModule.validateStandingComputation(
            AVADataTypes.StandingComputationContext({
                recognisedStateId: 1,
                subjectId: REVIEWER_SUBJECT,
                dimension: "review-vector-weight",
                vectorKey: keccak256("review-vector-weight"),
                currentValue: 0,
                delta: 1,
                effectiveAt: 0,
                epoch: 1,
                sourceRecordSetHash: keccak256("m410-standing-source-set"),
                computationRuleHash: _m422ComputationRuleHash(),
                reversible: true,
                fieldKey: keccak256("field"),
                evidenceReceiptId: 1,
                authorityId: keccak256("authority"),
                actor: address(this)
            })
        );
        rulePackageLifecycleModule.validateRulePackageLifecycle(
            IRulePackageLifecycleModule.RulePackageLifecycleContext({
                workflowKey: DEFAULT_WORKFLOW,
                modulesHash: keccak256("m410-default-modules"),
                modulesCodeHash: keccak256("m410-default-modules-code"),
                kind: AVADataTypes.RulePackageLifecycleKind.None,
                version: 1,
                compatibilityKey: keccak256("ava-m4-10-compatible"),
                dependencyURI: "",
                deprecated: false,
                targetWorkflowKey: bytes32(0),
                targetPackageId: 0,
                targetModulesHash: bytes32(0),
                targetModulesCodeHash: bytes32(0),
                targetVersion: 0,
                targetCompatibilityKey: bytes32(0),
                authorityRole: AVADataTypes.Role.Panel,
                actor: address(this)
            })
        );
        evidenceLifecycleModule.validateEvidenceLifecycle(
            DEFAULT_WORKFLOW,
            AVADataTypes.Action.RegisterRecognisedState,
            1,
            AVADataTypes.EvidenceLifecycleKind.None,
            0,
            bytes32(0),
            address(this)
        );
    }

    function testM410RulePackageBindsFutureProofModulesAndPreservesRetrieval() public {
        bytes32 workflowKey = keccak256("m410-future-package");
        ClaimEscrowRecordValueAdapter valueModule = new ClaimEscrowRecordValueAdapter();
        VectorStandingComputationModule standingModule = new VectorStandingComputationModule();
        VersionedRulePackageLifecycleModule lifecycleModule = new VersionedRulePackageLifecycleModule(2);
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueModule,
            standingModule,
            lifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            2,
            keccak256("ava-m4-10-compatible"),
            false,
            "ipfs://m410-future-package"
        );

        AVARulePackageRegistry.RulePackage memory rulePackage = rulePackageRegistry.getRulePackage(workflowKey);
        require(address(rulePackage.valueExecutionAdapter) == address(valueModule), "value module not bound");
        require(address(rulePackage.standingComputationModule) == address(standingModule), "standing module not bound");
        require(address(rulePackage.rulePackageLifecycleModule) == address(lifecycleModule), "lifecycle module not bound");
        require(rulePackage.version == 2, "wrong version");
        require(rulePackage.compatibilityKey == keccak256("ava-m4-10-compatible"), "wrong compatibility key");
        require(!rulePackage.deprecated, "unexpected deprecated package");

        try rulePackageLifecycleModule.validateRulePackageLifecycle(
            IRulePackageLifecycleModule.RulePackageLifecycleContext({
                workflowKey: keccak256("m410-deprecated-package"),
                modulesHash: keccak256("m410-deprecated-modules"),
                modulesCodeHash: keccak256("m410-deprecated-modules-code"),
                kind: AVADataTypes.RulePackageLifecycleKind.None,
                version: 1,
                compatibilityKey: keccak256("ava-m4-10-compatible"),
                dependencyURI: "ipfs://m410-deprecated",
                deprecated: true,
                targetWorkflowKey: bytes32(0),
                targetPackageId: 0,
                targetModulesHash: bytes32(0),
                targetModulesCodeHash: bytes32(0),
                targetVersion: 0,
                targetCompatibilityKey: bytes32(0),
                authorityRole: AVADataTypes.Role.Panel,
                actor: address(this)
            })
        ) {
            revert("deprecated package lifecycle accepted");
        } catch {}
    }

    function testM410ValueExecutionAdapterIsRecordOnlyOnRewardPath() public {

        bytes32 workflowKey = keccak256("m410-value-path");
        _ensureWorkflowPackage(workflowKey);
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m4-10-compatible"),
            false,
            "ipfs://m410-value-path"
        );
        (uint256 recognisedStateId, uint256 evidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, "m410-value-state"
        );

        uint256 rewardId = allocationExecutor.recordRewardValue(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://m410-value-record"
        );
        require(
            allocationExecutor.getAllocationExecution(rewardId).allocationKind
                == AVADataTypes.AllocationKind.RewardValueRecord,
            "wrong reward record kind"
        );
        _assertNoSelector(address(rulePackageRegistry.getRulePackage(workflowKey).valueExecutionAdapter), "transferToken(uint256)");
        _assertNoSelector(address(rulePackageRegistry.getRulePackage(workflowKey).valueExecutionAdapter), "payStablecoin(uint256)");
        _assertNoSelector(address(rulePackageRegistry.getRulePackage(workflowKey).valueExecutionAdapter), "executePayment(uint256)");
    }

    function testM410StandingComputationRejectsPublicPrestigeSingleScore() public {
        bytes32 workflowKey = keccak256("m410-standing-path");
        _ensureWorkflowPackage(workflowKey);
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m4-10-compatible"),
            false,
            "ipfs://m410-standing-path"
        );
        (uint256 recognisedStateId, uint256 evidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, "m410-standing-state"
        );

        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            "public-prestige",
            1,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://m410-public-prestige"
        ) {
            revert("standing computation accepted public prestige");
        } catch {}
        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            "single-score",
            1,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://m410-single-score"
        ) {
            revert("standing computation accepted single score");
        } catch {}
    }

    function testM410EvidenceLifecycleDefaultPassesAndRejectingModuleBlocksUse() public {
        bytes32 defaultWorkflow = keccak256("m410-evidence-default");
        _ensureWorkflowPackage(defaultWorkflow);
        _registerRulePackageWithFutureProofModules(
            defaultWorkflow,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m4-10-compatible"),
            false,
            "ipfs://m410-evidence-default"
        );
        (uint256 stateId,) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            defaultWorkflow, AVADataTypes.RecognisedStateStatus.Registered, "m410-evidence-default-state"
        );
        require(stateMachine.getRecognisedState(stateId).id == stateId, "default evidence lifecycle blocked state");

        bytes32 rejectingWorkflow = keccak256("m410-evidence-rejecting");
        _registerRulePackageWithFutureProofModules(
            rejectingWorkflow,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            new RejectingEvidenceLifecycleModule(AVADataTypes.Action.RegisterRecognisedState),
            disclosureExecutionModule,
            1,
            keccak256("ava-m4-10-compatible"),
            false,
            "ipfs://m410-evidence-rejecting"
        );
        uint256 rejectingEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            rejectingWorkflow,
            keccak256("m410-rejecting-evidence"),
            "ipfs://m410-rejecting-evidence",
            "evidence-lifecycle-basis",
            0
        );
        try stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            rejectingWorkflow,
            AVADataTypes.AVAStage.Verification,
            keccak256("m410-rejecting-object"),
            REVIEWER_SUBJECT,
            rejectingEvidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        ) {
            revert("rejecting evidence lifecycle accepted evidence use");
        } catch {}
    }

    function testM411ValueExecutionReadinessRoutesRewardPriorityPenaltyAndRestoration() public {

        bytes32 workflowKey = keccak256("m411-value-readiness");
        _ensureWorkflowPackage(workflowKey);
        bytes32 blockedReference = keccak256(bytes("ipfs://m411-blocked-priority"));
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            new MockValueExecutionAdapter(blockedReference, address(0xBEEF), AVADataTypes.ValueExecutionMode.Claim),
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m4-11-compatible"),
            false,
            "ipfs://m411-value-readiness"
        );
        (uint256 recognisedStateId, uint256 evidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, "m411-value-state"
        );

        {
            uint256 rewardId = allocationExecutor.recordRewardValue(
                AVADataTypes.Role.ProtocolExecutor,
                recognisedStateId,
                REVIEWER_SUBJECT,
                2,
                evidenceId,
                keccak256("executor-authority"),
                "ipfs://m411-reward"
            );
            uint256 priorityId = allocationExecutor.recordAdministrativePriority(
                AVADataTypes.Role.ProtocolExecutor,
                recognisedStateId,
                REVIEWER_SUBJECT,
                3,
                evidenceId,
                keccak256("executor-authority"),
                "ipfs://m411-priority"
            );
            require(
                allocationExecutor.getAllocationExecution(rewardId).executionMode
                    == AVADataTypes.ValueExecutionMode.RecordOnly,
                "reward not record-only"
            );
            AVADataTypes.AllocationExecutionRecord memory priorityRecord =
                allocationExecutor.getAllocationExecution(priorityId);
            require(
                priorityRecord.executionMode == AVADataTypes.ValueExecutionMode.RecordOnly,
                "priority not record-only"
            );
            require(
                priorityRecord.executionReference == keccak256(bytes("ipfs://m411-priority")),
                "priority ref missing"
            );
        }
        {
            uint256 penaltyId = consequenceExecutor.recordPenalty(
                AVADataTypes.Role.Panel,
                recognisedStateId,
                REVIEWER_SUBJECT,
                evidenceId,
                keccak256("panel-authority"),
                "ipfs://m411-penalty"
            );
            uint256 restorationId = consequenceExecutor.recordRestoration(
                AVADataTypes.Role.Panel,
                recognisedStateId,
                REVIEWER_SUBJECT,
                evidenceId,
                keccak256("panel-authority"),
                "ipfs://m411-restoration"
            );
            AVADataTypes.ConsequenceRecord memory penaltyRecord = consequenceExecutor.getConsequence(penaltyId);
            AVADataTypes.ConsequenceRecord memory restorationRecord = consequenceExecutor.getConsequence(restorationId);
            require(penaltyRecord.executionMode == AVADataTypes.ValueExecutionMode.RecordOnly, "penalty not record-only");
            require(
                restorationRecord.executionMode == AVADataTypes.ValueExecutionMode.RecordOnly,
                "restoration not record-only"
            );
            require(penaltyRecord.amountOrUnits == 1, "penalty readiness units missing");
            require(restorationRecord.amountOrUnits == 1, "restoration readiness units missing");
        }

        try allocationExecutor.recordAdministrativePriority(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://m411-blocked-priority"
        ) {
            revert("priority bypassed value execution adapter");
        } catch {}
        try allocationExecutor.recordRewardValue(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://m411-blocked-priority"
        ) {
            revert("reward bypassed value execution adapter");
        } catch {}
        try consequenceExecutor.recordPenalty(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://m411-blocked-priority"
        ) {
            revert("penalty bypassed value execution adapter");
        } catch {}
        try consequenceExecutor.recordRestoration(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://m411-blocked-priority"
        ) {
            revert("restoration bypassed value execution adapter");
        } catch {}

        _assertNoSelector(address(rulePackageRegistry.getRulePackage(workflowKey).valueExecutionAdapter), "transferToken(uint256)");
        _assertNoSelector(address(rulePackageRegistry.getRulePackage(workflowKey).valueExecutionAdapter), "payStablecoin(uint256)");
        _assertNoSelector(address(rulePackageRegistry.getRulePackage(workflowKey).valueExecutionAdapter), "executeQueue(uint256)");
        _assertNoSelector(address(rulePackageRegistry.getRulePackage(workflowKey).valueExecutionAdapter), "executeSanction(uint256)");
    }

    function testM411RulePackageLifecycleRecordsReadinessWithoutMigrationExecution() public {
        bytes32 workflowKey = keccak256("m411-lifecycle-source");
        bytes32 targetWorkflowKey = keccak256("m411-lifecycle-target");
        TargetAwareRulePackageLifecycleModule targetAwareLifecycleModule = new TargetAwareRulePackageLifecycleModule();
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            targetAwareLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            3,
            keccak256("ava-m4-11-compatible"),
            false,
            "ipfs://m411-lifecycle-source"
        );
        try rulePackageRegistry.recordRulePackageLifecycle(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVADataTypes.RulePackageLifecycleKind.MigrationReady,
            keccak256("m411-lifecycle-unknown-target"),
            "ipfs://m411-unknown-migration"
        ) {
            revert("migration readiness accepted unknown target");
        } catch {}
        _registerRulePackageWithFutureProofModules(
            targetWorkflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            3,
            keccak256("ava-m4-11-compatible"),
            false,
            "ipfs://m411-lifecycle-target"
        );
        AVARulePackageRegistry.RulePackage memory targetPackage = rulePackageRegistry.getRulePackage(targetWorkflowKey);
        uint256 targetPackageId = targetPackage.packageId;

        uint256 deprecationRecordId = rulePackageRegistry.recordRulePackageLifecycle(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVADataTypes.RulePackageLifecycleKind.DeprecationReady,
            bytes32(0),
            "ipfs://m411-deprecation"
        );
        targetAwareLifecycleModule.setExpectedTarget(
            targetWorkflowKey,
            targetPackageId + 1,
            targetPackage.modulesHash,
            targetPackage.modulesCodeHash,
            targetPackage.version,
            targetPackage.compatibilityKey
        );
        try rulePackageRegistry.recordRulePackageLifecycle(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVADataTypes.RulePackageLifecycleKind.MigrationReady,
            targetWorkflowKey,
            "ipfs://m411-wrong-target-context"
        ) {
            revert("migration readiness did not expose target package context");
        } catch {}
        targetAwareLifecycleModule.setExpectedTarget(
            targetWorkflowKey,
            targetPackageId,
            targetPackage.modulesHash,
            targetPackage.modulesCodeHash,
            targetPackage.version,
            targetPackage.compatibilityKey
        );
        uint256 migrationRecordId = rulePackageRegistry.recordRulePackageLifecycle(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVADataTypes.RulePackageLifecycleKind.MigrationReady,
            targetWorkflowKey,
            "ipfs://m411-migration"
        );

        AVADataTypes.RulePackageLifecycleRecord memory deprecationRecord =
            rulePackageRegistry.getRulePackageLifecycleRecord(deprecationRecordId);
        AVADataTypes.RulePackageLifecycleRecord memory migrationRecord =
            rulePackageRegistry.getRulePackageLifecycleRecord(migrationRecordId);
        require(
            deprecationRecord.kind == AVADataTypes.RulePackageLifecycleKind.DeprecationReady,
            "deprecation readiness missing"
        );
        require(deprecationRecord.targetPackageId == 0, "deprecation target package set");
        require(migrationRecord.targetWorkflowKey == targetWorkflowKey, "migration target missing");
        require(migrationRecord.targetPackageId == targetPackageId, "migration target package missing");
        require(deprecationRecord.authorityId == keccak256("panel-authority"), "deprecation authority missing");
        require(migrationRecord.authorityId == keccak256("panel-authority"), "migration authority missing");
        require(rulePackageRegistry.getRulePackage(workflowKey).active, "lifecycle record deactivated package");
        require(!rulePackageRegistry.getRulePackage(workflowKey).deprecated, "lifecycle record mutated deprecation");
        _registerRulePackageWithFutureProofModules(
            targetWorkflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            4,
            keccak256("ava-m4-11-compatible"),
            false,
            "ipfs://m411-lifecycle-target-v2"
        );
        uint256 newTargetPackageId = rulePackageRegistry.getRulePackage(targetWorkflowKey).packageId;
        require(newTargetPackageId != targetPackageId, "target package did not rotate");
        AVADataTypes.RulePackageLifecycleRecord memory migrationRecordAfterRotation =
            rulePackageRegistry.getRulePackageLifecycleRecord(migrationRecordId);
        require(migrationRecordAfterRotation.targetPackageId == targetPackageId, "migration target package drifted");

        try rulePackageRegistry.recordRulePackageLifecycle(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVADataTypes.RulePackageLifecycleKind.MigrationReady,
            bytes32(0),
            "ipfs://m411-missing-target"
        ) {
            revert("migration readiness accepted missing target");
        } catch {}
        _assertNoSelector(address(rulePackageRegistry), "executeMigration(bytes32)");
        _assertNoSelector(address(rulePackageRegistry), "migrateRulePackage(bytes32)");
    }

    function testM52RulePackageLifecycleRecordBindsExplicitSourceAndTargetPackages() public {
        bytes32 workflowKey = keccak256("m52-lifecycle-source");
        bytes32 targetWorkflowKey = keccak256("m52-lifecycle-target");
        TargetAwareRulePackageLifecycleModule targetAwareLifecycleModule = new TargetAwareRulePackageLifecycleModule();
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            targetAwareLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            5,
            keccak256("ava-m5-2-compatible"),
            false,
            "ipfs://m52-lifecycle-source"
        );
        AVARulePackageRegistry.RulePackage memory sourcePackage = rulePackageRegistry.getRulePackage(workflowKey);
        _registerRulePackageWithFutureProofModules(
            targetWorkflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            7,
            keccak256("ava-m5-2-compatible"),
            false,
            "ipfs://m52-lifecycle-target"
        );
        AVARulePackageRegistry.RulePackage memory targetPackage = rulePackageRegistry.getRulePackage(targetWorkflowKey);
        targetAwareLifecycleModule.setExpectedTarget(
            targetWorkflowKey,
            targetPackage.packageId,
            targetPackage.modulesHash,
            targetPackage.modulesCodeHash,
            targetPackage.version,
            targetPackage.compatibilityKey
        );

        uint256 lifecycleRecordId = rulePackageRegistry.recordRulePackageLifecycleForPackage(
            AVADataTypes.Role.Panel,
            sourcePackage.packageId,
            AVADataTypes.RulePackageLifecycleKind.MigrationReady,
            targetPackage.packageId,
            "ipfs://m52-explicit-migration"
        );
        AVADataTypes.RulePackageLifecycleRecord memory record =
            rulePackageRegistry.getRulePackageLifecycleRecord(lifecycleRecordId);

        require(record.workflowKey == workflowKey, "source workflow not bound");
        require(record.packageId == sourcePackage.packageId, "source package not bound");
        require(record.modulesHash == sourcePackage.modulesHash, "source modules hash not bound");
        require(record.modulesCodeHash == sourcePackage.modulesCodeHash, "source modules code hash not bound");
        require(record.version == sourcePackage.version, "source version not bound");
        require(record.compatibilityKey == sourcePackage.compatibilityKey, "source compatibility not bound");
        require(record.targetWorkflowKey == targetWorkflowKey, "target workflow not bound");
        require(record.targetPackageId == targetPackage.packageId, "target package not bound");
        require(record.targetModulesHash == targetPackage.modulesHash, "target modules hash not bound");
        require(record.targetModulesCodeHash == targetPackage.modulesCodeHash, "target modules code hash not bound");
        require(record.targetVersion == targetPackage.version, "target version not bound");
        require(record.targetCompatibilityKey == targetPackage.compatibilityKey, "target compatibility not bound");

        _registerRulePackageWithFutureProofModules(
            targetWorkflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            8,
            keccak256("ava-m5-2-compatible"),
            false,
            "ipfs://m52-lifecycle-target-v2"
        );
        AVADataTypes.RulePackageLifecycleRecord memory recordAfterTargetRotation =
            rulePackageRegistry.getRulePackageLifecycleRecord(lifecycleRecordId);
        require(recordAfterTargetRotation.targetPackageId == targetPackage.packageId, "target package drifted");
        require(recordAfterTargetRotation.targetModulesHash == targetPackage.modulesHash, "target modules hash drifted");
        require(
            recordAfterTargetRotation.targetModulesCodeHash == targetPackage.modulesCodeHash,
            "target modules code hash drifted"
        );
    }

    function testM52ObjectMigrationReadinessBindsObjectSourceTargetAuthorityAndEvidence() public {
        bytes32 workflowKey = keccak256("m52-object-migration-source");
        bytes32 targetWorkflowKey = keccak256("m52-object-migration-target");
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m5-2-compatible"),
            false,
            "ipfs://m52-object-source"
        );
        _registerRulePackageWithFutureProofModules(
            targetWorkflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m5-2-compatible"),
            false,
            "ipfs://m52-object-target"
        );
        AVARulePackageRegistry.RulePackage memory sourcePackage = rulePackageRegistry.getRulePackage(workflowKey);
        AVARulePackageRegistry.RulePackage memory targetPackage = rulePackageRegistry.getRulePackage(targetWorkflowKey);
        (uint256 recognisedStateId, uint256 evidenceId) =
            _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
                workflowKey, AVADataTypes.RecognisedStateStatus.Registered, "m52-object-migration-state"
            );
        uint256 lifecycleRecordId = rulePackageRegistry.recordRulePackageLifecycleForPackage(
            AVADataTypes.Role.Panel,
            sourcePackage.packageId,
            AVADataTypes.RulePackageLifecycleKind.MigrationReady,
            targetPackage.packageId,
            "ipfs://m52-object-package-migration"
        );
        uint256 readinessId = rulePackageRegistry.recordObjectMigrationReadiness(
            AVADataTypes.Role.Panel,
            AVARulePackageRegistry.ObjectMigrationReadinessInput({
                lifecycleRecordId: lifecycleRecordId,
                objectId: bytes32(recognisedStateId),
                recognisedStateId: recognisedStateId,
                evidenceReceiptId: evidenceId,
                boundaryHash: keccak256("m52-object-boundary"),
                authorityId: keccak256("panel-authority"),
                uri: "ipfs://m52-object-migration-readiness"
            })
        );
        AVADataTypes.ObjectMigrationReadinessRecord memory readiness =
            rulePackageRegistry.getObjectMigrationReadinessRecord(readinessId);

        require(readiness.lifecycleRecordId == lifecycleRecordId, "lifecycle record not bound");
        require(readiness.workflowKey == workflowKey, "source workflow not bound");
        require(readiness.packageId == sourcePackage.packageId, "source package not bound");
        require(readiness.targetWorkflowKey == targetWorkflowKey, "target workflow not bound");
        require(readiness.targetPackageId == targetPackage.packageId, "target package not bound");
        require(readiness.objectId == bytes32(recognisedStateId), "object not bound");
        require(readiness.recognisedStateId == recognisedStateId, "recognised state not bound");
        require(readiness.evidenceReceiptId == evidenceId, "evidence not bound");
        require(readiness.boundaryHash == keccak256("m52-object-boundary"), "boundary not bound");
        require(readiness.authorityId == keccak256("panel-authority"), "authority not bound");
        require(readiness.createdAt == block.timestamp, "object migration timestamp missing");
        require(stateMachine.getRecognisedState(recognisedStateId).packageId == sourcePackage.packageId, "readiness migrated state");

        _registerRulePackageWithFutureProofModules(
            targetWorkflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            2,
            keccak256("ava-m5-2-compatible"),
            false,
            "ipfs://m52-object-target-v2"
        );
        AVADataTypes.ObjectMigrationReadinessRecord memory afterTargetRotation =
            rulePackageRegistry.getObjectMigrationReadinessRecord(readinessId);
        require(afterTargetRotation.targetPackageId == targetPackage.packageId, "object target package drifted");

        uint256 deprecationRecordId = rulePackageRegistry.recordRulePackageLifecycleForPackage(
            AVADataTypes.Role.Panel,
            sourcePackage.packageId,
            AVADataTypes.RulePackageLifecycleKind.DeprecationReady,
            0,
            "ipfs://m52-object-deprecation"
        );
        try rulePackageRegistry.recordObjectMigrationReadiness(
            AVADataTypes.Role.Panel,
            AVARulePackageRegistry.ObjectMigrationReadinessInput({
                lifecycleRecordId: deprecationRecordId,
                objectId: bytes32(recognisedStateId),
                recognisedStateId: recognisedStateId,
                evidenceReceiptId: evidenceId,
                boundaryHash: keccak256("m52-invalid-boundary"),
                authorityId: keccak256("panel-authority"),
                uri: "ipfs://m52-invalid-object-migration"
            })
        ) {
            revert("object migration accepted non-migration lifecycle");
        } catch {}
        _assertNoSelector(address(rulePackageRegistry), "executeObjectMigration(uint256)");
    }

    function testM52ObjectMigrationReadinessRejectsWrongPackageStateAndEvidence() public {
        bytes32 workflowKey = keccak256("m52-object-migration-source-hardening");
        bytes32 targetWorkflowKey = keccak256("m52-object-migration-target-hardening");
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m5-2-compatible"),
            false,
            "ipfs://m52-object-source-hardening"
        );
        _registerRulePackageWithFutureProofModules(
            targetWorkflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m5-2-compatible"),
            false,
            "ipfs://m52-object-target-hardening"
        );
        AVARulePackageRegistry.RulePackage memory sourcePackage = rulePackageRegistry.getRulePackage(workflowKey);
        AVARulePackageRegistry.RulePackage memory targetPackage = rulePackageRegistry.getRulePackage(targetWorkflowKey);
        (uint256 sourceStateId, uint256 sourceEvidenceId) =
            _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
                workflowKey, AVADataTypes.RecognisedStateStatus.Registered, "m52-object-source-hardening"
            );
        (uint256 targetStateId, uint256 targetEvidenceId) =
            _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
                targetWorkflowKey, AVADataTypes.RecognisedStateStatus.Registered, "m52-object-target-hardening"
            );
        uint256 lifecycleRecordId = rulePackageRegistry.recordRulePackageLifecycleForPackage(
            AVADataTypes.Role.Panel,
            sourcePackage.packageId,
            AVADataTypes.RulePackageLifecycleKind.MigrationReady,
            targetPackage.packageId,
            "ipfs://m52-object-package-migration-hardening"
        );

        try rulePackageRegistry.recordObjectMigrationReadiness(
            AVADataTypes.Role.Panel,
            AVARulePackageRegistry.ObjectMigrationReadinessInput({
                lifecycleRecordId: lifecycleRecordId,
                objectId: bytes32(sourceStateId),
                recognisedStateId: targetStateId,
                evidenceReceiptId: sourceEvidenceId,
                boundaryHash: keccak256("m52-wrong-state-boundary"),
                authorityId: keccak256("panel-authority"),
                uri: "ipfs://m52-wrong-state"
            })
        ) {
            revert("object migration accepted wrong-package state");
        } catch {}

        try rulePackageRegistry.recordObjectMigrationReadiness(
            AVADataTypes.Role.Panel,
            AVARulePackageRegistry.ObjectMigrationReadinessInput({
                lifecycleRecordId: lifecycleRecordId,
                objectId: bytes32(sourceStateId),
                recognisedStateId: sourceStateId,
                evidenceReceiptId: targetEvidenceId,
                boundaryHash: keccak256("m52-wrong-evidence-boundary"),
                authorityId: keccak256("panel-authority"),
                uri: "ipfs://m52-wrong-evidence"
            })
        ) {
            revert("object migration accepted wrong-package evidence");
        } catch {}
    }

    function testM52ExplicitLifecycleUsesHistoricalSourcePackageAfterWorkflowReregistration() public {
        bytes32 workflowKey = keccak256("m52-historical-source");
        bytes32 targetWorkflowKey = keccak256("m52-historical-target");
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m5-2-compatible"),
            false,
            "ipfs://m52-historical-source-v1"
        );
        AVARulePackageRegistry.RulePackage memory oldSourcePackage = rulePackageRegistry.getRulePackage(workflowKey);
        _registerRulePackageWithFutureProofModules(
            targetWorkflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m5-2-compatible"),
            false,
            "ipfs://m52-historical-target"
        );
        AVARulePackageRegistry.RulePackage memory targetPackage = rulePackageRegistry.getRulePackage(targetWorkflowKey);

        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            new RejectingReadyRulePackageLifecycleModule(),
            evidenceLifecycleModule,
            disclosureExecutionModule,
            2,
            keccak256("ava-m5-2-compatible"),
            false,
            "ipfs://m52-historical-source-v2"
        );
        require(rulePackageRegistry.getRulePackage(workflowKey).packageId != oldSourcePackage.packageId, "source did not rotate");

        try rulePackageRegistry.recordRulePackageLifecycle(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVADataTypes.RulePackageLifecycleKind.MigrationReady,
            targetWorkflowKey,
            "ipfs://m52-active-package-rejects"
        ) {
            revert("workflow-key path did not use active source package");
        } catch {}

        uint256 lifecycleRecordId = rulePackageRegistry.recordRulePackageLifecycleForPackage(
            AVADataTypes.Role.Panel,
            oldSourcePackage.packageId,
            AVADataTypes.RulePackageLifecycleKind.MigrationReady,
            targetPackage.packageId,
            "ipfs://m52-old-package-migration"
        );
        AVADataTypes.RulePackageLifecycleRecord memory record =
            rulePackageRegistry.getRulePackageLifecycleRecord(lifecycleRecordId);
        require(record.packageId == oldSourcePackage.packageId, "old source package not used");
        require(record.modulesHash == oldSourcePackage.modulesHash, "old source modules hash not used");
        require(record.targetPackageId == targetPackage.packageId, "target package missing");
    }

    function testM52ExplicitLifecycleRejectsInvalidTargetsAndHasNoMigrationExecutor() public {
        bytes32 workflowKey = keccak256("m52-invalid-source");
        bytes32 targetWorkflowKey = keccak256("m52-invalid-target");
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m5-2-compatible"),
            false,
            "ipfs://m52-invalid-source"
        );
        _registerRulePackageWithFutureProofModules(
            targetWorkflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m5-2-compatible"),
            false,
            "ipfs://m52-invalid-target"
        );
        AVARulePackageRegistry.RulePackage memory sourcePackage = rulePackageRegistry.getRulePackage(workflowKey);
        AVARulePackageRegistry.RulePackage memory targetPackage = rulePackageRegistry.getRulePackage(targetWorkflowKey);

        try rulePackageRegistry.recordRulePackageLifecycleForPackage(
            AVADataTypes.Role.Panel,
            sourcePackage.packageId,
            AVADataTypes.RulePackageLifecycleKind.MigrationReady,
            0,
            "ipfs://m52-missing-target"
        ) {
            revert("migration accepted missing target");
        } catch {}
        try rulePackageRegistry.recordRulePackageLifecycleForPackage(
            AVADataTypes.Role.Panel,
            sourcePackage.packageId,
            AVADataTypes.RulePackageLifecycleKind.SupersessionReady,
            sourcePackage.packageId,
            "ipfs://m52-self-target"
        ) {
            revert("supersession accepted self target");
        } catch {}
        try rulePackageRegistry.recordRulePackageLifecycleForPackage(
            AVADataTypes.Role.Panel,
            sourcePackage.packageId,
            AVADataTypes.RulePackageLifecycleKind.MigrationReady,
            999999,
            "ipfs://m52-unknown-target"
        ) {
            revert("migration accepted unknown target");
        } catch {}
        try rulePackageRegistry.recordRulePackageLifecycleForPackage(
            AVADataTypes.Role.Panel,
            sourcePackage.packageId,
            AVADataTypes.RulePackageLifecycleKind.DeprecationReady,
            targetPackage.packageId,
            "ipfs://m52-deprecation-target"
        ) {
            revert("deprecation accepted target package");
        } catch {}

        uint256 supersessionRecordId = rulePackageRegistry.recordRulePackageLifecycleForPackage(
            AVADataTypes.Role.Panel,
            sourcePackage.packageId,
            AVADataTypes.RulePackageLifecycleKind.SupersessionReady,
            targetPackage.packageId,
            "ipfs://m52-supersession"
        );
        require(rulePackageRegistry.getRulePackageLifecycleRecord(supersessionRecordId).targetPackageId == targetPackage.packageId, "valid supersession missing target");
        _assertNoSelector(address(rulePackageRegistry), "executeMigration(uint256)");
        _assertNoSelector(address(rulePackageRegistry), "migrateRulePackage(uint256)");
        _assertNoSelector(address(rulePackageRegistry), "applyRulePackageMigration(uint256)");
    }

    function testM411EvidenceLifecycleHooksRecordOnlyWithoutTruthOrReveal() public {
        roleRegistry.assignRole(address(this), AVADataTypes.Role.Reviewer, keccak256("m411-reviewer"), "ipfs://reviewer");
        bytes32 workflowKey = keccak256("m411-evidence-lifecycle");
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m4-11-compatible"),
            false,
            "ipfs://m411-evidence-lifecycle"
        );
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m411-evidence"),
            "ipfs://m411-evidence",
            "m411-evidence-basis",
            0
        );
        uint256 replacementEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m411-replacement-evidence"),
            "ipfs://m411-replacement-evidence",
            "m411-evidence-replacement",
            0
        );

        uint256 lifecycleRecordId = evidenceRegistry.recordEvidenceLifecycleHook(
            AVADataTypes.Role.Reviewer,
            workflowKey,
            evidenceId,
            AVADataTypes.EvidenceLifecycleKind.ReplacementReady,
            replacementEvidenceId,
            keccak256("m411-replacement-reference"),
            "ipfs://m411-evidence-replacement"
        );
        AVADataTypes.EvidenceLifecycleRecord memory lifecycleRecord =
            evidenceRegistry.getEvidenceLifecycleRecord(lifecycleRecordId);
        require(lifecycleRecord.evidenceReceiptId == evidenceId, "evidence lifecycle target missing");
        require(lifecycleRecord.replacementEvidenceReceiptId == replacementEvidenceId, "replacement missing");
        require(lifecycleRecord.authorityId == keccak256("m411-reviewer"), "evidence lifecycle authority missing");

        bytes32 rejectingWorkflow = keccak256("m411-reject-evidence-hook");
        _registerRulePackageWithFutureProofModules(
            rejectingWorkflow,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            new RejectingEvidenceLifecycleModule(AVADataTypes.Action.RecordEvidenceLifecycle),
            disclosureExecutionModule,
            1,
            keccak256("ava-m4-11-compatible"),
            false,
            "ipfs://m411-reject-evidence-hook"
        );
        try evidenceRegistry.recordEvidenceLifecycleHook(
            AVADataTypes.Role.Reviewer,
            rejectingWorkflow,
            evidenceId,
            AVADataTypes.EvidenceLifecycleKind.RevocationReady,
            0,
            keccak256("m411-revocation-reference"),
            "ipfs://m411-revocation"
        ) {
            revert("rejecting evidence lifecycle accepted hook");
        } catch {}

        _assertNoSelector(address(evidenceRegistry), "validateScientificTruth(uint256)");
        _assertNoSelector(address(evidenceRegistry), "revealEvidence(uint256)");
        _assertNoSelector(address(evidenceRegistry), "decryptEvidence(uint256)");
    }

    function testEvidenceLifecycleHookRequiresRecordLifecyclePermission() public {
        roleRegistry.assignRole(address(this), AVADataTypes.Role.Reviewer, keccak256("m420-lifecycle-authority"), "ipfs://reviewer");
        uint256 evidenceId = evidenceRegistry.registerEvidenceReceipt(
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            keccak256("m420-lifecycle-permission-evidence"),
            "ipfs://m420-lifecycle-permission-evidence",
            "m420-lifecycle-permission-basis",
            0
        );
        authorityMatrix.setPermission(AVADataTypes.Role.Reviewer, AVADataTypes.Action.RecordEvidenceLifecycle, false);
        uint256 nextLifecycleRecordId = evidenceRegistry.nextEvidenceLifecycleRecordId();

        try evidenceRegistry.recordEvidenceLifecycleHook(
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            evidenceId,
            AVADataTypes.EvidenceLifecycleKind.ExpiryReady,
            0,
            keccak256("m420-lifecycle-permission-reference"),
            "ipfs://m420-lifecycle-permission"
        ) {
            revert("register evidence permission created lifecycle record");
        } catch {}

        require(
            evidenceRegistry.nextEvidenceLifecycleRecordId() == nextLifecycleRecordId,
            "unauthorised lifecycle record stored"
        );
    }

    function testEvidenceLifecycleModuleReceivesKindAndReplacementReference() public {
        bytes32 reviewerSubject = keccak256("m420-evidence-lifecycle-reviewer");
        roleRegistry.assignRole(address(this), AVADataTypes.Role.Reviewer, reviewerSubject, "ipfs://reviewer");
        bytes32 workflowKey = keccak256("m420-kind-scoped-evidence-lifecycle");
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            new KindScopedEvidenceLifecycleModule(AVADataTypes.EvidenceLifecycleKind.ReplacementReady),
            disclosureExecutionModule,
            1,
            keccak256("ava-m4-20-compatible"),
            false,
            "ipfs://m420-evidence-lifecycle"
        );
        uint256 evidenceId = evidenceRegistry.registerEvidenceReceipt(
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m420-evidence"),
            "ipfs://m420-evidence",
            "m420-evidence-basis",
            0
        );
        uint256 replacementEvidenceId = evidenceRegistry.registerEvidenceReceipt(
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m420-replacement-evidence"),
            "ipfs://m420-replacement-evidence",
            "m420-evidence-replacement",
            0
        );

        try evidenceRegistry.recordEvidenceLifecycleHook(
            AVADataTypes.Role.Reviewer,
            workflowKey,
            evidenceId,
            AVADataTypes.EvidenceLifecycleKind.RevocationReady,
            0,
            keccak256("m420-revocation-reference"),
            "ipfs://m420-revocation"
        ) {
            revert("evidence lifecycle module did not receive kind");
        } catch {}

        uint256 lifecycleRecordId = evidenceRegistry.recordEvidenceLifecycleHook(
            AVADataTypes.Role.Reviewer,
            workflowKey,
            evidenceId,
            AVADataTypes.EvidenceLifecycleKind.ReplacementReady,
            replacementEvidenceId,
            keccak256("m420-replacement-reference"),
            "ipfs://m420-replacement"
        );
        AVADataTypes.EvidenceLifecycleRecord memory record = evidenceRegistry.getEvidenceLifecycleRecord(lifecycleRecordId);
        require(record.kind == AVADataTypes.EvidenceLifecycleKind.ReplacementReady, "replacement kind not recorded");
        require(record.replacementEvidenceReceiptId == replacementEvidenceId, "replacement id not recorded");
        require(record.authorityId == reviewerSubject, "evidence lifecycle authority wrong");
    }

    function testEvidenceLifecycleUsesReceiptPackageAfterWorkflowReregistration() public {
        bytes32 reviewerSubject = keccak256("m415-evidence-lifecycle-reviewer");
        roleRegistry.assignRole(address(this), AVADataTypes.Role.Reviewer, reviewerSubject, "ipfs://reviewer");
        uint256 originalPackageId = rulePackageRegistry.getRulePackage(DEFAULT_WORKFLOW).packageId;
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            keccak256("m415-frozen-evidence"),
            "ipfs://m415-frozen-evidence",
            "m415-frozen-evidence-type",
            0
        );
        require(evidenceRegistry.getEvidenceReceipt(evidenceId).packageId == originalPackageId, "evidence package missing");

        _registerRulePackageWithFutureProofModules(
            DEFAULT_WORKFLOW,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            new RejectingEvidenceLifecycleModule(AVADataTypes.Action.RecordEvidenceLifecycle),
            disclosureExecutionModule,
            2,
            keccak256("ava-m4-15-compatible"),
            false,
            "ipfs://m415-rejecting-evidence-lifecycle"
        );

        uint256 lifecycleRecordId = evidenceRegistry.recordEvidenceLifecycleHook(
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            evidenceId,
            AVADataTypes.EvidenceLifecycleKind.ExpiryReady,
            0,
            keccak256("m415-frozen-evidence-expiry"),
            "ipfs://m415-frozen-evidence-expiry"
        );
        AVADataTypes.EvidenceLifecycleRecord memory lifecycleRecord =
            evidenceRegistry.getEvidenceLifecycleRecord(lifecycleRecordId);
        require(lifecycleRecord.packageId == originalPackageId, "evidence lifecycle used active package");
        require(lifecycleRecord.authorityId == reviewerSubject, "evidence lifecycle authority missing");
    }

    function testM51EvidenceReceiptLifecycleUpdatesStatusAndReplacement() public {
        uint256 evidenceId = _registerM51DefaultEvidence("m51-status-target");
        uint256 replacementEvidenceId = _registerM51DefaultEvidence("m51-status-replacement");

        AVADataTypes.EvidenceReceipt memory initialReceipt = evidenceRegistry.getEvidenceReceipt(evidenceId);
        require(initialReceipt.status == AVADataTypes.EvidenceReceiptStatus.Active, "new evidence not active");
        require(initialReceipt.lastLifecycleRecordId == 0, "new evidence has lifecycle record");
        require(initialReceipt.replacementEvidenceReceiptId == 0, "new evidence has replacement");

        uint256 lifecycleRecordId = reviewerActor.recordEvidenceLifecycleHook(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            evidenceId,
            AVADataTypes.EvidenceLifecycleKind.ReplacementReady,
            replacementEvidenceId,
            keccak256("m51-replacement-reference"),
            "ipfs://m51-replacement"
        );
        AVADataTypes.EvidenceLifecycleRecord memory lifecycleRecord =
            evidenceRegistry.getEvidenceLifecycleRecord(lifecycleRecordId);
        require(lifecycleRecord.fromStatus == AVADataTypes.EvidenceReceiptStatus.Active, "from status missing");
        require(lifecycleRecord.toStatus == AVADataTypes.EvidenceReceiptStatus.Replaced, "to status missing");
        require(lifecycleRecord.replacementEvidenceReceiptId == replacementEvidenceId, "replacement id missing");

        AVADataTypes.EvidenceReceipt memory replacedReceipt = evidenceRegistry.getEvidenceReceipt(evidenceId);
        require(replacedReceipt.status == AVADataTypes.EvidenceReceiptStatus.Replaced, "receipt not replaced");
        require(replacedReceipt.lastLifecycleRecordId == lifecycleRecordId, "last lifecycle id missing");
        require(replacedReceipt.replacementEvidenceReceiptId == replacementEvidenceId, "receipt replacement missing");
        require(
            evidenceRegistry.getEvidenceReceipt(replacementEvidenceId).status == AVADataTypes.EvidenceReceiptStatus.Active,
            "replacement not active"
        );
    }

    function testM51ReplacementLifecycleRejectsBadReferencesAndTerminalRepeat() public {
        uint256 evidenceId = _registerM51DefaultEvidence("m51-replacement-target");
        bytes32 otherWorkflow = keccak256("m51-other-workflow");
        _ensureWorkflowPackage(otherWorkflow);
        uint256 wrongWorkflowReplacement = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            otherWorkflow,
            keccak256("m51-wrong-workflow-replacement"),
            "ipfs://m51-wrong-workflow-replacement",
            "m51-evidence",
            0
        );
        roleRegistry.assignRole(
            address(this), AVADataTypes.Role.Reviewer, keccak256("m51-unscoped-registrar"), "ipfs://m51-reviewer"
        );
        uint256 unscopedReplacement = evidenceRegistry.registerEvidenceReceipt(
            AVADataTypes.Role.Reviewer,
            keccak256("m51-unscoped-replacement"),
            "ipfs://m51-unscoped-replacement",
            "m51-evidence",
            0
        );
        AVADataTypes.EvidenceReceipt memory unscopedReceipt = evidenceRegistry.getEvidenceReceipt(unscopedReplacement);
        require(unscopedReceipt.workflowKey == bytes32(0), "replacement unexpectedly scoped");
        require(unscopedReceipt.packageId == 0, "replacement unexpectedly packaged");
        uint256 inactiveReplacement = _registerM51DefaultEvidence("m51-inactive-replacement");
        _expireM51EvidenceReceipt(inactiveReplacement, "m51-inactive-replacement-expiry");

        _assertM51ReplacementLifecycleRejected(evidenceId, evidenceId, "self replacement accepted");
        _assertM51ReplacementLifecycleRejected(evidenceId, 999999, "unknown replacement accepted");
        _assertM51ReplacementLifecycleRejected(
            evidenceId, wrongWorkflowReplacement, "wrong workflow replacement accepted"
        );
        _assertM51ReplacementLifecycleRejected(evidenceId, unscopedReplacement, "unscoped replacement accepted");
        _assertM51ReplacementLifecycleRejected(evidenceId, inactiveReplacement, "inactive replacement accepted");

        _expireM51EvidenceReceipt(evidenceId, "m51-terminal-target-expiry");
        try reviewerActor.recordEvidenceLifecycleHook(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            evidenceId,
            AVADataTypes.EvidenceLifecycleKind.SupersessionReady,
            0,
            keccak256("m51-terminal-repeat"),
            "ipfs://m51-terminal-repeat"
        ) {
            revert("terminal evidence accepted second lifecycle transition");
        } catch {}
    }

    function testM51InactiveEvidenceRejectedForReviewStateAndChallengeFormation() public {
        uint256 manuscriptId = stateMachine.registerManuscript(
            AVADataTypes.Role.Author, keccak256("m51-manuscript"), "ipfs://m51-manuscript"
        );
        uint256 reviewEvidenceId = _registerM51DefaultEvidence("m51-review-expired");
        _expireM51EvidenceReceipt(reviewEvidenceId, "m51-review-expiry");

        try reviewerActor.registerReviewContribution(
            stateMachine, AVADataTypes.Role.Reviewer, manuscriptId, REVIEWER_SUBJECT, reviewEvidenceId, 0
        ) {
            revert("review contribution accepted inactive evidence");
        } catch {}

        try stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            keccak256("m51-direct-state"),
            REVIEWER_SUBJECT,
            reviewEvidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        ) {
            revert("recognised state accepted inactive evidence");
        } catch {}

        uint256 stateEvidenceId = _registerM51DefaultEvidence("m51-challengeable-state");
        uint256 challengeableStateId = _registerRecognisedStateForWorkflowStatus(
            DEFAULT_WORKFLOW,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            stateEvidenceId,
            "m51-challengeable-state"
        );
        uint256 challengeEvidenceId = _registerM51DefaultEvidence("m51-challenge-expired");
        _expireM51EvidenceReceipt(challengeEvidenceId, "m51-challenge-expiry");

        try challengerActor.fileChallenge(
            stateMachine,
            AVADataTypes.Role.Challenger,
            DEFAULT_WORKFLOW,
            challengeableStateId,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            0
        ) {
            revert("challenge accepted inactive evidence");
        } catch {}

        require(
            evidenceRegistry.getEvidenceReceipt(reviewEvidenceId).status == AVADataTypes.EvidenceReceiptStatus.Expired,
            "historical inactive evidence unreadable"
        );
    }

    function testM51InactiveEvidenceRejectedForDownstreamCredentialAuditAndExternalOperation() public {
        uint256 stateEvidenceId = _registerM51DefaultEvidence("m51-downstream-state");
        uint256 recognisedStateId = _registerRecognisedStateForWorkflowStatus(
            DEFAULT_WORKFLOW, AVADataTypes.RecognisedStateStatus.Vested, stateEvidenceId, "m51-downstream-state"
        );
        uint256 inactiveEvidenceId = _registerM51DefaultEvidence("m51-downstream-expired");
        _expireM51EvidenceReceipt(inactiveEvidenceId, "m51-downstream-expiry");

        uint256 nextStandingUpdateId = standingRegistry.nextStandingUpdateId();
        uint256 nextStandingComputationId = standingRegistry.nextStandingComputationRecordId();
        uint256 nextAllocationId = allocationExecutor.nextAllocationExecutionId();
        uint256 nextConsequenceId = consequenceExecutor.nextConsequenceId();
        _assertAllDownstreamRejectTarget(recognisedStateId, inactiveEvidenceId);
        require(standingRegistry.nextStandingUpdateId() == nextStandingUpdateId, "inactive evidence wrote standing");
        require(
            standingRegistry.nextStandingComputationRecordId() == nextStandingComputationId,
            "inactive evidence wrote standing computation"
        );
        require(allocationExecutor.nextAllocationExecutionId() == nextAllocationId, "inactive evidence wrote allocation");
        require(consequenceExecutor.nextConsequenceId() == nextConsequenceId, "inactive evidence wrote consequence");

        _assertM51InactiveEvidenceRejectedForCredentialAuditAndExternal(recognisedStateId, inactiveEvidenceId);
    }

    function testM411StandingComputationReadinessIsVectorProceduralAndBounded() public {
        bytes32 workflowKey = keccak256("m411-standing-readiness");
        _ensureWorkflowPackage(workflowKey);
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m4-11-compatible"),
            false,
            "ipfs://m411-standing-readiness"
        );
        (uint256 recognisedStateId, uint256 evidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, "m411-standing-state"
        );

        uint256 computationId = standingRegistry.recordStandingComputationReadiness(
            AVADataTypes.Role.Panel,
            AVADataTypes.StandingComputationContext({
                recognisedStateId: recognisedStateId,
                subjectId: REVIEWER_SUBJECT,
                dimension: "review-procedure-weight",
                vectorKey: keccak256("review-procedure-weight"),
                currentValue: 4,
                delta: -1,
                effectiveAt: 123,
                epoch: 1,
                sourceRecordSetHash: keccak256("m411-standing-source-set"),
                computationRuleHash: _m422ComputationRuleHash(),
                reversible: true,
                fieldKey: keccak256("verification-field"),
                evidenceReceiptId: evidenceId,
                authorityId: keccak256("panel-authority"),
                actor: address(this)
            }),
            "ipfs://m411-standing-computation"
        );
        AVADataTypes.StandingComputationRecord memory computation =
            standingRegistry.getStandingComputationRecord(computationId);
        require(computation.vectorKey == keccak256("review-procedure-weight"), "vector key missing");
        require(computation.reversible, "reversibility readiness missing");
        require(computation.currentValue == 4 && computation.delta == -1, "standing computation values missing");

        try standingRegistry.recordStandingComputationReadiness(
            AVADataTypes.Role.Panel,
            AVADataTypes.StandingComputationContext({
                recognisedStateId: recognisedStateId,
                subjectId: REVIEWER_SUBJECT,
                dimension: "single-score",
                vectorKey: keccak256("single-score"),
                currentValue: 0,
                delta: 1,
                effectiveAt: 0,
                epoch: 2,
                sourceRecordSetHash: keccak256("m411-single-score-source-set"),
                computationRuleHash: _m422ComputationRuleHash(),
                reversible: true,
                fieldKey: keccak256("verification-field"),
                evidenceReceiptId: evidenceId,
                authorityId: keccak256("panel-authority"),
                actor: address(this)
            }),
            "ipfs://m411-single-score"
        ) {
            revert("standing computation accepted single-score");
        } catch {}

        _assertNoSelector(address(standingRegistry), "setPublicPrestige(uint256,uint256)");
        _assertNoSelector(address(standingRegistry), "setReputationScore(uint256,uint256)");
    }

    function testM62FormulaV0StandingComputationModuleAcceptsBoundedOutput() public {
        bytes32 workflowKey = keccak256("m62-formula-v0-valid");
        FormulaV0StandingComputationModule formulaModule = new FormulaV0StandingComputationModule();
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            formulaModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m6-2-compatible"),
            false,
            "ipfs://m62-formula-v0-valid"
        );
        (uint256 recognisedStateId, uint256 evidenceId) = _createM421EligibleState(workflowKey, "m62-formula-valid");
        bytes32 vectorKey = formulaModule.REVIEW_RELIABILITY_VECTOR();
        uint256 computationId = standingRegistry.recordStandingComputationReadiness(
            AVADataTypes.Role.Panel,
            AVADataTypes.StandingComputationContext({
                recognisedStateId: recognisedStateId,
                subjectId: REVIEWER_SUBJECT,
                dimension: "review_reliability",
                vectorKey: vectorKey,
                currentValue: 7,
                delta: 2,
                effectiveAt: block.timestamp,
                epoch: 2,
                sourceRecordSetHash: keccak256("m62-formula-source-set"),
                computationRuleHash: formulaModule.formulaRuleHash(vectorKey),
                reversible: true,
                fieldKey: keccak256("peer-review-field"),
                evidenceReceiptId: evidenceId,
                authorityId: keccak256("panel-authority"),
                actor: address(this)
            }),
            "ipfs://m62-formula-valid"
        );
        AVADataTypes.StandingComputationRecord memory computation =
            standingRegistry.getStandingComputationRecord(computationId);
        require(computation.computationRuleHash == formulaModule.formulaRuleHash(vectorKey), "formula rule missing");
        require(computation.vectorKey == vectorKey, "formula vector missing");
        require(computation.currentValue == 7 && computation.delta == 2, "formula value missing");
    }

    function testM62FormulaV0StandingComputationModuleRejectsInvalidFormulaOutputs() public {
        bytes32 workflowKey = keccak256("m62-formula-v0-rejects");
        FormulaV0StandingComputationModule formulaModule = new FormulaV0StandingComputationModule();
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            formulaModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m6-2-compatible"),
            false,
            "ipfs://m62-formula-v0-rejects"
        );
        (uint256 recognisedStateId, uint256 evidenceId) = _createM421EligibleState(workflowKey, "m62-formula-rejects");
        bytes32 vectorKey = formulaModule.REVIEW_RELIABILITY_VECTOR();
        AVADataTypes.StandingComputationContext memory context = AVADataTypes.StandingComputationContext({
            recognisedStateId: recognisedStateId,
            subjectId: REVIEWER_SUBJECT,
            dimension: "review_reliability",
            vectorKey: vectorKey,
            currentValue: 7,
            delta: 2,
            effectiveAt: block.timestamp,
            epoch: 2,
            sourceRecordSetHash: keccak256("m62-formula-source-set"),
            computationRuleHash: formulaModule.formulaRuleHash(vectorKey),
            reversible: true,
            fieldKey: keccak256("peer-review-field"),
            evidenceReceiptId: evidenceId,
            authorityId: keccak256("panel-authority"),
            actor: address(this)
        });
        uint256 nextComputationId = standingRegistry.nextStandingComputationRecordId();

        context.computationRuleHash = keccak256("m62-wrong-rule");
        try standingRegistry.recordStandingComputationReadiness(AVADataTypes.Role.Panel, context, "ipfs://m62-wrong-rule") {
            revert("formula module accepted wrong rule hash");
        } catch {}

        context.computationRuleHash = formulaModule.formulaRuleHash(vectorKey);
        context.dimension = "single-score";
        context.vectorKey = keccak256("single-score");
        try standingRegistry.recordStandingComputationReadiness(AVADataTypes.Role.Panel, context, "ipfs://m62-single-score") {
            revert("formula module accepted single score");
        } catch {}

        context.dimension = "unrecognised_vector";
        context.vectorKey = keccak256("unrecognised_vector");
        context.computationRuleHash = formulaModule.formulaRuleHash(context.vectorKey);
        try standingRegistry.recordStandingComputationReadiness(AVADataTypes.Role.Panel, context, "ipfs://m62-unknown-vector") {
            revert("formula module accepted unknown vector");
        } catch {}

        context.dimension = "review_reliability";
        context.vectorKey = vectorKey;
        context.computationRuleHash = formulaModule.formulaRuleHash(vectorKey);
        context.currentValue = 101;
        try standingRegistry.recordStandingComputationReadiness(AVADataTypes.Role.Panel, context, "ipfs://m62-unbounded") {
            revert("formula module accepted unbounded value");
        } catch {}

        require(standingRegistry.nextStandingComputationRecordId() == nextComputationId, "invalid formula wrote record");
    }

    function testM412GenericAllocationAndConsequenceRouteThroughValueAdapter() public {

        bytes32 workflowKey = keccak256("m412-generic-routing");
        _ensureWorkflowPackage(workflowKey);
        bytes32 blockedReference = keccak256("m412-blocked-reference");
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            new MockValueExecutionAdapter(blockedReference, address(0xBAD), AVADataTypes.ValueExecutionMode.Escrow),
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m4-12-compatible"),
            false,
            "ipfs://m412-generic-routing"
        );
        (uint256 recognisedStateId, uint256 evidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, "m412-generic-state"
        );

        allocationExecutor.executeAllocationWithExecution(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.AllocationKind.OperationalAllowance,
            _valueContext(
                recognisedStateId,
                REVIEWER_SUBJECT,
                5,
                evidenceId,
                keccak256("executor-authority"),
                "ipfs://m412-generic-allocation",
                keccak256("m412-allowed-allocation"),
                address(0xCAFE),
                address(0xDAD),
                AVADataTypes.ValueExecutionMode.RecordOnly
            )
        );
        consequenceExecutor.registerConsequenceWithExecution(
            AVADataTypes.Role.Panel,
            AVADataTypes.ConsequenceKind.AdministrativeNote,
            _valueContext(
                recognisedStateId,
                REVIEWER_SUBJECT,
                1,
                evidenceId,
                keccak256("panel-authority"),
                "ipfs://m412-generic-consequence",
                keccak256("m412-allowed-consequence"),
                address(0xCAFE),
                address(0xDAD),
                AVADataTypes.ValueExecutionMode.RecordOnly
            )
        );

        try allocationExecutor.executeAllocationWithExecution(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.AllocationKind.OperationalAllowance,
            _valueContext(
                recognisedStateId,
                REVIEWER_SUBJECT,
                5,
                evidenceId,
                keccak256("executor-authority"),
                "ipfs://m412-blocked-allocation",
                blockedReference,
                address(0xCAFE),
                address(0xDAD),
                AVADataTypes.ValueExecutionMode.RecordOnly
            )
        ) {
            revert("generic allocation bypassed value adapter");
        } catch {}
        try consequenceExecutor.registerConsequenceWithExecution(
            AVADataTypes.Role.Panel,
            AVADataTypes.ConsequenceKind.AdministrativeNote,
            _valueContext(
                recognisedStateId,
                REVIEWER_SUBJECT,
                1,
                evidenceId,
                keccak256("panel-authority"),
                "ipfs://m412-blocked-consequence",
                blockedReference,
                address(0xCAFE),
                address(0xDAD),
                AVADataTypes.ValueExecutionMode.RecordOnly
            )
        ) {
            revert("generic consequence bypassed value adapter");
        } catch {}
    }

    function testM412ParameterizedPenaltyAndRestorationRecordExecutionFields() public {
        bytes32 workflowKey = keccak256("m412-consequence-parameters");
        _ensureWorkflowPackage(workflowKey);
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m4-12-compatible"),
            false,
            "ipfs://m412-consequence-parameters"
        );
        (uint256 recognisedStateId, uint256 evidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowKey, AVADataTypes.RecognisedStateStatus.Downgraded, "m412-consequence-state"
        );

        uint256 penaltyId = consequenceExecutor.recordPenaltyWithExecution(
            AVADataTypes.Role.Panel,
            _valueContext(
                recognisedStateId,
                REVIEWER_SUBJECT,
                12,
                evidenceId,
                keccak256("panel-authority"),
                "ipfs://m412-penalty",
                keccak256("m412-penalty-reference"),
                address(0xA11CE),
                address(0xB0B),
                AVADataTypes.ValueExecutionMode.RecordOnly
            )
        );
        uint256 restorationId = consequenceExecutor.recordRestorationWithExecution(
            AVADataTypes.Role.Panel,
            _valueContext(
                recognisedStateId,
                REVIEWER_SUBJECT,
                34,
                evidenceId,
                keccak256("panel-authority"),
                "ipfs://m412-restoration",
                keccak256("m412-restoration-reference"),
                address(0xA11CE),
                address(0xB0B),
                AVADataTypes.ValueExecutionMode.RecordOnly
            )
        );

        AVADataTypes.ConsequenceRecord memory penalty = consequenceExecutor.getConsequence(penaltyId);
        AVADataTypes.ConsequenceRecord memory restoration = consequenceExecutor.getConsequence(restorationId);
        require(penalty.amountOrUnits == 12, "penalty amount hardcoded");
        require(restoration.amountOrUnits == 34, "restoration amount hardcoded");
        require(penalty.executionReference == keccak256("m412-penalty-reference"), "penalty reference missing");
        require(
            restoration.executionReference == keccak256("m412-restoration-reference"),
            "restoration reference missing"
        );
        require(penalty.asset == address(0xA11CE) && penalty.payer == address(0xB0B), "penalty addresses missing");
        require(restoration.asset == address(0xA11CE) && restoration.payer == address(0xB0B), "restoration addresses missing");
    }

    function testM412DefaultValueAdapterRejectsNonRecordOnlyParameterizedModes() public {

        bytes32 workflowKey = keccak256("m412-default-mode");
        _ensureWorkflowPackage(workflowKey);
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m4-12-compatible"),
            false,
            "ipfs://m412-default-mode"
        );
        (uint256 recognisedStateId, uint256 evidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, "m412-default-state"
        );

        try allocationExecutor.recordRewardValueWithExecution(
            AVADataTypes.Role.ProtocolExecutor,
            _valueContext(
                recognisedStateId,
                REVIEWER_SUBJECT,
                1,
                evidenceId,
                keccak256("executor-authority"),
                "ipfs://m412-claim-reward",
                keccak256("m412-claim-reward"),
                address(0xA11CE),
                address(0xB0B),
                AVADataTypes.ValueExecutionMode.Claim
            )
        ) {
            revert("default value adapter accepted claim reward");
        } catch {}
        try consequenceExecutor.recordPenaltyWithExecution(
            AVADataTypes.Role.Panel,
            _valueContext(
                recognisedStateId,
                REVIEWER_SUBJECT,
                1,
                evidenceId,
                keccak256("panel-authority"),
                "ipfs://m412-escrow-penalty",
                keccak256("m412-escrow-penalty"),
                address(0xA11CE),
                address(0xB0B),
                AVADataTypes.ValueExecutionMode.Escrow
            )
        ) {
            revert("default value adapter accepted escrow penalty");
        } catch {}
    }

    function testStandingRegistryDispatchesAdaptersByRecognisedStateWorkflowKey() public {
        bytes32 workflowA = keccak256("standing-dispatch-a");
        bytes32 workflowB = keccak256("standing-dispatch-b");
        _ensureWorkflowPackage(workflowA);
        _ensureWorkflowPackage(workflowB);
        uint256 evidenceA = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowA,
            keccak256("standing-dispatch-evidence-a"),
            "ipfs://standing-dispatch-a",
            "standing-dispatch-basis",
            0
        );
        uint256 evidenceB = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowB,
            keccak256("standing-dispatch-evidence-b"),
            "ipfs://standing-dispatch-b",
            "standing-dispatch-basis",
            0
        );
        _registerRulePackageWithAdapters(
            workflowA,
            allocationAdapter,
            consequenceAdapter,
            new MockStandingAdapter("blocked-a"),
            rewardAdapter,
            priorityAdapter,
            penaltyAdapter,
            restorationAdapter,
            "ipfs://standing-dispatch-a"
        );
        _registerRulePackageWithAdapters(
            workflowB,
            allocationAdapter,
            consequenceAdapter,
            new MockStandingAdapter("blocked-b"),
            rewardAdapter,
            priorityAdapter,
            penaltyAdapter,
            restorationAdapter,
            "ipfs://standing-dispatch-b"
        );
        (uint256 stateA, uint256 currentEvidenceA) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowA, AVADataTypes.RecognisedStateStatus.Downgraded, "standing-dispatch-state-a"
        );
        (uint256 stateB, uint256 currentEvidenceB) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowB, AVADataTypes.RecognisedStateStatus.Downgraded, "standing-dispatch-state-b"
        );
        evidenceA = currentEvidenceA;
        evidenceB = currentEvidenceB;

        standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            stateA,
            REVIEWER_SUBJECT,
            "blocked-b",
            1,
            evidenceA,
            keccak256("panel-authority"),
            "ipfs://standing-a-allowed"
        );
        standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            stateB,
            REVIEWER_SUBJECT,
            "blocked-a",
            1,
            evidenceB,
            keccak256("panel-authority"),
            "ipfs://standing-b-allowed"
        );

        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            stateA,
            REVIEWER_SUBJECT,
            "blocked-a",
            1,
            evidenceA,
            keccak256("panel-authority"),
            "ipfs://standing-a-blocked"
        ) {
            revert("standing workflow A did not dispatch to adapter A");
        } catch {}
        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            stateB,
            REVIEWER_SUBJECT,
            "blocked-b",
            1,
            evidenceB,
            keccak256("panel-authority"),
            "ipfs://standing-b-blocked"
        ) {
            revert("standing workflow B did not dispatch to adapter B");
        } catch {}
    }

    function testAllocationExecutorDispatchesRewardAndPriorityAdaptersByWorkflowKey() public {

        bytes32 workflowA = keccak256("allocation-dispatch-a");
        bytes32 workflowB = keccak256("allocation-dispatch-b");
        _ensureWorkflowPackage(workflowA);
        _ensureWorkflowPackage(workflowB);
        uint256 evidenceA = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowA,
            keccak256("allocation-dispatch-evidence-a"),
            "ipfs://allocation-dispatch-a",
            "allocation-dispatch-basis",
            0
        );
        uint256 evidenceB = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowB,
            keccak256("allocation-dispatch-evidence-b"),
            "ipfs://allocation-dispatch-b",
            "allocation-dispatch-basis",
            0
        );
        _registerRulePackageWithAdapters(
            workflowA,
            allocationAdapter,
            consequenceAdapter,
            standingAdapter,
            new MockRewardAdapter(7),
            new MockPriorityAdapter(9),
            penaltyAdapter,
            restorationAdapter,
            "ipfs://allocation-dispatch-a"
        );
        _registerRulePackageWithAdapters(
            workflowB,
            allocationAdapter,
            consequenceAdapter,
            standingAdapter,
            new MockRewardAdapter(17),
            new MockPriorityAdapter(19),
            penaltyAdapter,
            restorationAdapter,
            "ipfs://allocation-dispatch-b"
        );
        (uint256 stateA, uint256 currentEvidenceA) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowA, AVADataTypes.RecognisedStateStatus.Vested, "allocation-dispatch-state-a"
        );
        (uint256 stateB, uint256 currentEvidenceB) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowB, AVADataTypes.RecognisedStateStatus.Vested, "allocation-dispatch-state-b"
        );
        evidenceA = currentEvidenceA;
        evidenceB = currentEvidenceB;

        allocationExecutor.recordRewardValue(
            AVADataTypes.Role.ProtocolExecutor,
            stateA,
            REVIEWER_SUBJECT,
            17,
            evidenceA,
            keccak256("executor-authority"),
            "ipfs://reward-a-allowed"
        );
        allocationExecutor.recordAdministrativePriority(
            AVADataTypes.Role.ProtocolExecutor,
            stateB,
            REVIEWER_SUBJECT,
            9,
            evidenceB,
            keccak256("executor-authority"),
            "ipfs://priority-b-allowed"
        );

        try allocationExecutor.recordRewardValue(
            AVADataTypes.Role.ProtocolExecutor,
            stateA,
            REVIEWER_SUBJECT,
            7,
            evidenceA,
            keccak256("executor-authority"),
            "ipfs://reward-a-blocked"
        ) {
            revert("reward workflow A did not dispatch to adapter A");
        } catch {}
        try allocationExecutor.recordAdministrativePriority(
            AVADataTypes.Role.ProtocolExecutor,
            stateB,
            REVIEWER_SUBJECT,
            19,
            evidenceB,
            keccak256("executor-authority"),
            "ipfs://priority-b-blocked"
        ) {
            revert("priority workflow B did not dispatch to adapter B");
        } catch {}
    }

    function testConsequenceExecutorDispatchesPenaltyAndRestorationAdaptersByWorkflowKey() public {
        bytes32 blockedA = keccak256("blocked-a-authority");
        bytes32 blockedB = keccak256("blocked-b-authority");
        bytes32 workflowA = keccak256("consequence-dispatch-a");
        bytes32 workflowB = keccak256("consequence-dispatch-b");
        _ensureWorkflowPackage(workflowA);
        _ensureWorkflowPackage(workflowB);
        uint256 evidenceA = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowA,
            keccak256("consequence-dispatch-evidence-a"),
            "ipfs://consequence-dispatch-a",
            "consequence-dispatch-basis",
            0
        );
        uint256 evidenceB = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowB,
            keccak256("consequence-dispatch-evidence-b"),
            "ipfs://consequence-dispatch-b",
            "consequence-dispatch-basis",
            0
        );
        _registerRulePackageWithAdapters(
            workflowA,
            allocationAdapter,
            consequenceAdapter,
            standingAdapter,
            rewardAdapter,
            priorityAdapter,
            new MockPenaltyAdapter(blockedA),
            new MockRestorationAdapter(blockedA),
            "ipfs://consequence-dispatch-a"
        );
        _registerRulePackageWithAdapters(
            workflowB,
            allocationAdapter,
            consequenceAdapter,
            standingAdapter,
            rewardAdapter,
            priorityAdapter,
            new MockPenaltyAdapter(blockedB),
            new MockRestorationAdapter(blockedB),
            "ipfs://consequence-dispatch-b"
        );
        (uint256 stateA, uint256 currentEvidenceA) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowA, AVADataTypes.RecognisedStateStatus.Downgraded, "consequence-dispatch-state-a"
        );
        (uint256 stateB, uint256 currentEvidenceB) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowB, AVADataTypes.RecognisedStateStatus.Restored, "consequence-dispatch-state-b"
        );
        evidenceA = currentEvidenceA;
        evidenceB = currentEvidenceB;

        consequenceExecutor.recordPenalty(
            AVADataTypes.Role.Panel,
            stateA,
            REVIEWER_SUBJECT,
            evidenceA,
            keccak256("panel-authority"),
            "ipfs://penalty-a-allowed"
        );
        consequenceExecutor.recordRestoration(
            AVADataTypes.Role.Panel,
            stateB,
            REVIEWER_SUBJECT,
            evidenceB,
            keccak256("panel-authority"),
            "ipfs://restoration-b-allowed"
        );

        try consequenceExecutor.recordPenalty(
            AVADataTypes.Role.Panel,
            stateA,
            REVIEWER_SUBJECT,
            evidenceA,
            blockedA,
            "ipfs://penalty-a-blocked"
        ) {
            revert("penalty workflow A did not dispatch to adapter A");
        } catch {}
        try consequenceExecutor.recordRestoration(
            AVADataTypes.Role.Panel,
            stateB,
            REVIEWER_SUBJECT,
            evidenceB,
            blockedB,
            "ipfs://restoration-b-blocked"
        ) {
            revert("restoration workflow B did not dispatch to adapter B");
        } catch {}
    }

    function testM4MultiWorkflowScenarioPreservesSharedSubstrateAndBoundaries() public {

        roleRegistry.assignRole(
            address(this), AVADataTypes.Role.Challenger, keccak256("local-challenger"), "ipfs://challenger"
        );
        Actor panelActor = new Actor();
        roleRegistry.assignRole(address(panelActor), AVADataTypes.Role.Panel, keccak256("m4-panel"), "ipfs://panel");

        bytes32 reviewWorkflow = keccak256("m4-review-workflow");
        bytes32 integrityWorkflow = keccak256("m4-integrity-workflow");
        _registerRulePackageWithAdapters(
            reviewWorkflow,
            allocationAdapter,
            consequenceAdapter,
            new MockStandingAdapter("review-blocked-standing"),
            new MockRewardAdapter(7),
            new MockPriorityAdapter(9),
            new MockPenaltyAdapter(keccak256("review-blocked-authority")),
            new MockRestorationAdapter(keccak256("review-blocked-authority")),
            "ipfs://m4-review-workflow"
        );
        _registerRulePackageWithAdapters(
            integrityWorkflow,
            allocationAdapter,
            consequenceAdapter,
            new MockStandingAdapter("integrity-blocked-standing"),
            new MockRewardAdapter(17),
            new MockPriorityAdapter(19),
            new MockPenaltyAdapter(keccak256("integrity-blocked-authority")),
            new MockRestorationAdapter(keccak256("integrity-blocked-authority")),
            "ipfs://m4-integrity-workflow"
        );

        AVARulePackageRegistry.RulePackage memory reviewPackage = rulePackageRegistry.getRulePackage(reviewWorkflow);
        uint256 reviewStateId = _createChallengeableReviewStateThroughPackage(reviewPackage, reviewWorkflow);
        AVADataTypes.RecognisedStateRecord memory reviewStateBefore = stateMachine.getRecognisedState(reviewStateId);
        require(reviewStateBefore.workflowKey == reviewWorkflow, "review state workflow wrong");

        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            integrityWorkflow,
            keccak256("m4-integrity-evidence"),
            "ipfs://m4-integrity-evidence",
            "challenge-integrity",
            0
        );
        uint256 integrityStateId = stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            integrityWorkflow,
            AVADataTypes.AVAStage.Verification,
            bytes32(reviewStateId),
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Challengeable
        );
        uint256 challengeId = challengerActor.fileChallenge(
            stateMachine,
            AVADataTypes.Role.Challenger,
            integrityWorkflow,
            integrityStateId,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            0
        );

        {
            AVADataTypes.ChallengeRecord memory challenge = stateMachine.getChallenge(challengeId);
            AVADataTypes.RecognisedStateRecord memory integrityState = stateMachine.getRecognisedState(integrityStateId);
            require(challenge.workflowKey == integrityWorkflow, "challenge workflow wrong");
            require(challenge.challengedRecognisedStateId == integrityStateId, "challenge target wrong");
            require(integrityState.workflowKey == integrityWorkflow, "integrity state workflow wrong");
            require(integrityState.objectId == bytes32(reviewStateId), "integrity state did not target review state");
            require(consequenceExecutor.nextConsequenceId() == 1, "challenge created consequence");
            require(standingRegistry.nextStandingUpdateId() == 1, "challenge created standing");
            require(allocationExecutor.nextAllocationExecutionId() == 1, "challenge created allocation");
        }

        stateMachine.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        panelActor.resolveChallenge(
            stateMachine,
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            keccak256("m4-panel"),
            "ipfs://m4-resolution"
        );
        {
            AVADataTypes.RecognisedStateRecord memory reviewStateAfter = stateMachine.getRecognisedState(reviewStateId);
            AVADataTypes.RecognisedStateRecord memory integrityStateAfter = stateMachine.getRecognisedState(integrityStateId);
            require(
                reviewStateAfter.status == AVADataTypes.RecognisedStateStatus.Challengeable, "review state was rewritten"
            );
            require(reviewStateAfter.workflowKey == reviewWorkflow, "review workflow changed");
            require(integrityStateAfter.status == AVADataTypes.RecognisedStateStatus.Downgraded, "integrity state not updated");
        }

        {
            uint256 reviewDownstreamEvidenceId = reviewerActor.registerEvidenceReceipt(
                evidenceRegistry,
                AVADataTypes.Role.Reviewer,
                reviewWorkflow,
                keccak256("m4-review-downstream-evidence"),
                "ipfs://m4-review-downstream-evidence",
                "review-downstream-basis",
                0
            );
            uint256 reviewDownstreamStateId = _registerRecognisedStateForWorkflowStatus(
                reviewWorkflow,
                AVADataTypes.RecognisedStateStatus.Downgraded,
                reviewDownstreamEvidenceId,
                "m4-review-downstream"
            );

            _assertM4DownstreamRecords(integrityStateId, challengeEvidenceId);
            _assertM4WorkflowAdapterBlocks(
                reviewDownstreamStateId,
                integrityStateId,
                reviewDownstreamEvidenceId,
                challengeEvidenceId,
                keccak256("review-blocked-authority"),
                keccak256("integrity-blocked-authority")
            );
        }

        _assertNoSelector(address(allocationExecutor), "transferToken(uint256)");
        _assertNoSelector(address(allocationExecutor), "payStablecoin(uint256)");
        _assertNoSelector(address(allocationExecutor), "executeQueue(uint256)");
        _assertNoSelector(address(consequenceExecutor), "executeSanction(uint256)");
        _assertNoSelector(address(stateMachine), "acceptManuscript(uint256)");
        _assertNoSelector(address(stateMachine), "scoreManuscriptMerit(uint256)");
    }

    function testM4EvidenceOnlyIdsCannotTriggerAnyDownstreamRecord() public {

        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("m4-evidence-only"),
            "ipfs://m4-evidence-only",
            "evidence-only",
            0
        );

        _assertAllDownstreamRejectTarget(evidenceId, evidenceId);
        require(standingRegistry.nextStandingUpdateId() == 1, "evidence-only created standing");
        require(allocationExecutor.nextAllocationExecutionId() == 1, "evidence-only created allocation");
        require(consequenceExecutor.nextConsequenceId() == 1, "evidence-only created consequence");
    }

    function testM4RestorationRecordDoesNotEraseChallengeHistoryOrMintReward() public {
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256("m4-restoration-history"),
            "ipfs://m4-restoration-history",
            "restoration-history",
            0
        );
        uint256 challengeId = challengerActor.fileChallenge(
            stateMachine, AVADataTypes.Role.Challenger, recognisedStateId, CHALLENGER_SUBJECT, challengeEvidenceId, 0
        );
        stateMachine.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        stateMachine.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://m4-good-faith"
        );
        AVADataTypes.ChallengeRecord memory resolvedChallenge = stateMachine.getChallenge(challengeId);
        uint256 resolvedTransitionId = resolvedChallenge.lastTransitionId;

        stateMachine.applyRestoration(
            AVADataTypes.Role.Panel, challengeId, keccak256("panel-authority"), "ipfs://m4-restoration-transition"
        );
        AVADataTypes.ChallengeRecord memory restoredChallenge = stateMachine.getChallenge(challengeId);
        AVADataTypes.ChallengeTransitionRecord memory resolvedTransition =
            stateMachine.getChallengeTransition(resolvedTransitionId);
        AVADataTypes.ChallengeTransitionRecord memory restorationTransition =
            stateMachine.getChallengeTransition(restoredChallenge.lastTransitionId);
        require(
            resolvedTransition.transitionKind == AVADataTypes.ChallengeTransitionKind.OutcomeResolved,
            "resolved transition erased"
        );
        require(
            restorationTransition.transitionKind == AVADataTypes.ChallengeTransitionKind.RestorationRecorded,
            "restoration transition missing"
        );
        require(restoredChallenge.lastTransitionId != resolvedTransitionId, "restoration did not add history");

        uint256 restorationRecordId = consequenceExecutor.recordRestoration(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            challengeEvidenceId,
            keccak256("panel-authority"),
            "ipfs://m4-restoration-record"
        );
        require(
            consequenceExecutor.getConsequence(restorationRecordId).kind
                == AVADataTypes.ConsequenceKind.RestorationRecord,
            "restoration consequence missing"
        );
        require(allocationExecutor.nextAllocationExecutionId() == 1, "restoration minted reward");
        require(
            stateMachine.getChallenge(challengeId).lastTransitionId == restoredChallenge.lastTransitionId,
            "restoration record erased challenge history"
        );
        _assertNoSelector(address(restorationAdapter), "mintReward(uint256)");
        _assertNoSelector(address(consequenceExecutor), "mintReward(uint256)");
    }

    function testM47WorkflowSpecificChallengeLifecycleCanRejectActionsWithoutStorageChange() public {
        roleRegistry.assignRole(address(this), AVADataTypes.Role.Challenger, keccak256("m47-challenger"), "ipfs://challenger");

        _assertLifecycleModuleRejectsScreen();
        _assertLifecycleModuleRejectsResolve();
        _assertLifecycleModuleRejectsRestoration();
        _assertLifecycleModuleRejectsClose();
    }

    function testM47PermissiveLifecycleCannotBypassNonDelegableSafetyGates() public {
        roleRegistry.assignRole(address(this), AVADataTypes.Role.Challenger, keccak256("m47-challenger"), "ipfs://challenger");
        bytes32 workflowKey = keccak256("m47-permissive-lifecycle");
        _registerRulePackageWithLifecycle(
            workflowKey, new PermissiveChallengeLifecycleModule(), "ipfs://m47-permissive-lifecycle"
        );
        AVARulePackageRegistry.RulePackage memory rulePackage = rulePackageRegistry.getRulePackage(workflowKey);
        uint256 recognisedStateId = _createChallengeableReviewStateThroughPackage(rulePackage, workflowKey);
        uint256 evidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            workflowKey,
            keccak256("m47-permissive-evidence"),
            "ipfs://m47-permissive-evidence",
            "challenge-lifecycle",
            0
        );
        uint256 challengeId = challengerActor.fileChallenge(
            stateMachine, AVADataTypes.Role.Challenger, workflowKey, recognisedStateId, CHALLENGER_SUBJECT, evidenceId, 0
        );
        stateMachine.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);

        roleRegistry.assignRole(
            address(challengerActor), AVADataTypes.Role.Panel, keccak256("m47-panel-challenger"), "ipfs://panel"
        );
        try challengerActor.resolveChallenge(
            stateMachine,
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            keccak256("m47-panel-challenger"),
            "ipfs://m47-self-resolution"
        ) {
            revert("permissive lifecycle bypassed self-resolution guard");
        } catch {}

        Actor panelActor = new Actor();
        roleRegistry.assignRole(address(panelActor), AVADataTypes.Role.Panel, keccak256("m47-panel"), "ipfs://panel");
        try panelActor.resolveChallenge(
            stateMachine,
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            keccak256("m47-panel"),
            "ipfs://m47-non-upheld-mutation"
        ) {
            revert("permissive lifecycle bypassed only-upheld mutation guard");
        } catch {}
        require(
            stateMachine.getChallenge(challengeId).status == AVADataTypes.ChallengeLifecycleStatus.AdmissibilityScreening,
            "failed mutation changed lifecycle"
        );
        panelActor.resolveChallenge(
            stateMachine,
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("m47-panel"),
            "ipfs://m47-good-faith"
        );
    }

    function testDownstreamAdaptersRejectRawReviewAndChallengeIds() public {

        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("m3-raw-review-evidence"),
            "ipfs://m3-raw-review",
            "review-service-occurrence",
            0
        );
        uint256 rawReviewId = reviewerActor.registerReviewContribution(
            stateMachine, AVADataTypes.Role.Reviewer, manuscriptId, REVIEWER_SUBJECT, evidenceId, 0
        );
        _assertSeparatedDownstreamRejectsTarget(rawReviewId, evidenceId);

        uint256 challengeableStateId = _createChallengeableReviewState();
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256("m3-raw-challenge-evidence"),
            "ipfs://m3-raw-challenge",
            "review-quality-challenge",
            0
        );
        challengerActor.fileChallenge(
            stateMachine, AVADataTypes.Role.Challenger, challengeableStateId, CHALLENGER_SUBJECT, challengeEvidenceId, 0
        );
        challengerActor.fileChallenge(
            stateMachine, AVADataTypes.Role.Challenger, challengeableStateId, CHALLENGER_SUBJECT, challengeEvidenceId, 0
        );
        uint256 rawChallengeId = challengerActor.fileChallenge(
            stateMachine, AVADataTypes.Role.Challenger, challengeableStateId, CHALLENGER_SUBJECT, challengeEvidenceId, 0
        );

        _assertSeparatedDownstreamRejectsTarget(rawChallengeId, challengeEvidenceId);
    }

    function testDownstreamAdaptersRejectDisallowedRecognisedStateStatuses() public {

        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("m3-disallowed-status-evidence"),
            "ipfs://m3-disallowed-status",
            "status-boundary",
            0
        );

        _assertSeparatedDownstreamRejectsTarget(0, evidenceId);
        _assertSeparatedDownstreamRejectsTarget(
            _registerRecognisedStateForStatus(AVADataTypes.RecognisedStateStatus.Draft, evidenceId, "m3-draft"),
            evidenceId
        );
        _assertSeparatedDownstreamRejectsTarget(
            _registerRecognisedStateForStatus(
                AVADataTypes.RecognisedStateStatus.Registered, evidenceId, "m3-registered"
            ),
            evidenceId
        );
        _assertSeparatedDownstreamRejectsTarget(
            _registerRecognisedStateForStatus(
                AVADataTypes.RecognisedStateStatus.Provisional, evidenceId, "m3-provisional"
            ),
            evidenceId
        );
        _assertSeparatedDownstreamRejectsTarget(
            _registerRecognisedStateForStatus(
                AVADataTypes.RecognisedStateStatus.Challengeable, evidenceId, "m3-challengeable"
            ),
            evidenceId
        );
        _assertSeparatedDownstreamRejectsTarget(
            _registerRecognisedStateForStatus(AVADataTypes.RecognisedStateStatus.Frozen, evidenceId, "m3-frozen"),
            evidenceId
        );
    }

    function testM421ValueSettlementTransfersMockERC20OnlyFromAuthorisedRecord() public {
        bytes32 workflowKey = keccak256("m421-token-transfer-workflow");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m421-token-transfer-workflow");
        MockERC20 token = _m421FundedToken(100);
        uint256 sourceId =
            _createM421RewardSource(workflowKey, "m421-token-transfer-source", token, 7, AVADataTypes.ValueExecutionMode.Claim);

        uint256 settlementId = valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m421-token-transfer-settlement"
        );
        AVADataTypes.ValueSettlementRecord memory settlement = valueSettlementExecutor.getValueSettlement(settlementId);
        require(settlement.kind == AVADataTypes.ValueSettlementKind.TokenTransfer, "wrong settlement kind");
        require(settlement.status == AVADataTypes.ValueSettlementStatus.Settled, "wrong settlement status");
        require(token.balanceOf(address(reviewerActor)) == 7, "mock ERC20 not transferred to subject account");

        uint256 recordOnlySourceId = _createM421RecordOnlyRewardSource(workflowKey, "m421-record-only-source");
        try valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            recordOnlySourceId,
            keccak256("executor-authority"),
            "ipfs://m421-record-only-rejected"
        ) {
            revert("record-only allocation source was settled");
        } catch {}

        uint256 unauthorisedSourceId =
            _createM421RewardSource(workflowKey, "m421-unauthorised-source", token, 3, AVADataTypes.ValueExecutionMode.Claim);
        try valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.Editor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            unauthorisedSourceId,
            EDITOR_AUTHORITY,
            "ipfs://m421-unauthorised-settlement"
        ) {
            revert("unauthorised settlement accepted");
        } catch {}
        require(token.balanceOf(address(reviewerActor)) == 7, "unauthorised settlement changed token balance");
    }

    function testM421DuplicateValueSettlementRejected() public {
        bytes32 workflowKey = keccak256("m421-duplicate-settlement-workflow");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m421-duplicate-settlement-workflow");
        MockERC20 token = _m421FundedToken(50);
        uint256 sourceId =
            _createM421RewardSource(workflowKey, "m421-duplicate-source", token, 5, AVADataTypes.ValueExecutionMode.Claim);

        valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m421-first-settlement"
        );
        try valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m421-duplicate-settlement"
        ) {
            revert("duplicate settlement accepted");
        } catch {}
    }

    function testM426ValueSettlementRejectsTokenCallbackReentrancy() public {
        bytes32 workflowKey = keccak256("m426-settlement-reentrancy-workflow");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m426-settlement-reentrancy-workflow");
        ReentrantSettlementToken token = new ReentrantSettlementToken();
        token.mint(address(this), 20);
        (uint256 recognisedStateId, uint256 evidenceId) =
            _createM421EligibleState(workflowKey, "m426-settlement-reentrancy-source");

        AVADataTypes.ValueExecutionContext memory context;
        context.recognisedStateId = recognisedStateId;
        context.asset = address(token);
        context.payer = address(this);
        context.recipientSubjectId = REVIEWER_SUBJECT;
        context.amount = 5;
        context.mode = AVADataTypes.ValueExecutionMode.Claim;
        context.settlementKind = AVADataTypes.ValueSettlementKind.TokenTransfer;
        context.executionReference = bytes32(evidenceId);
        context.authorityId = keccak256("executor-authority");
        context.evidenceReceiptId = evidenceId;
        context.uri = "ipfs://m426-reentrant-source";
        context.actor = address(this);
        uint256 sourceId =
            allocationExecutor.recordRewardValueWithExecution(AVADataTypes.Role.ProtocolExecutor, context);

        bytes32 tokenAuthorityId = keccak256("m426-reentrant-token-authority");
        roleRegistry.assignRole(
            address(token), AVADataTypes.Role.ProtocolExecutor, tokenAuthorityId, "ipfs://m426-reentrant-token"
        );
        token.configure(valueSettlementExecutor, sourceId, tokenAuthorityId);

        uint256 settlementId = valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m426-token-transfer-settlement"
        );

        require(settlementId == 1, "outer settlement should be first and only record");
        require(valueSettlementExecutor.nextValueSettlementId() == 2, "reentrant settlement created extra record");
        require(token.attemptedReentry(), "malicious token did not attempt reentry");
        require(!token.reentrySucceeded(), "reentrant settlement succeeded");
        require(token.reentryFailed(), "reentrant settlement was not rejected");
        require(token.balanceOf(address(reviewerActor)) == 5, "settlement amount changed");
    }

    function testM421EscrowClaimAndRefundStateWorks() public {
        bytes32 workflowKey = keccak256("m421-escrow-workflow");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m421-escrow-workflow");
        MockERC20 token = _m421FundedToken(100);
        uint256 claimSourceId =
            _createM421RewardSource(workflowKey, "m421-escrow-claim-source", token, 11, AVADataTypes.ValueExecutionMode.Escrow);

        valueSettlementExecutor.depositEscrow(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            claimSourceId,
            keccak256("executor-authority"),
            "ipfs://m421-escrow-deposit"
        );
        require(token.balanceOf(address(valueSettlementExecutor)) == 11, "escrow deposit not held");
        uint256 claimId = valueSettlementExecutor.claimEscrow(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            claimSourceId,
            keccak256("executor-authority"),
            "ipfs://m421-escrow-claim"
        );
        require(
            valueSettlementExecutor.getValueSettlement(claimId).status == AVADataTypes.ValueSettlementStatus.Claimed,
            "escrow claim not recorded"
        );
        require(token.balanceOf(address(reviewerActor)) == 11, "escrow claim not transferred");

        uint256 refundSourceId =
            _createM421RewardSource(workflowKey, "m421-escrow-refund-source", token, 13, AVADataTypes.ValueExecutionMode.Escrow);
        valueSettlementExecutor.depositEscrow(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            refundSourceId,
            keccak256("executor-authority"),
            "ipfs://m421-escrow-refund-deposit"
        );
        uint256 refundId = valueSettlementExecutor.refundEscrow(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            refundSourceId,
            keccak256("executor-authority"),
            "ipfs://m421-escrow-refund"
        );
        require(
            valueSettlementExecutor.getValueSettlement(refundId).status == AVADataTypes.ValueSettlementStatus.Refunded,
            "escrow refund not recorded"
        );
        require(token.balanceOf(address(valueSettlementExecutor)) == 0, "escrow balance not cleared");
    }

    function testM421PriorityTokenExecutionCannotAffectPublicationOutcome() public {
        bytes32 workflowKey = keccak256("m421-priority-token-workflow");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m421-priority-token-workflow");
        MockPriorityToken priorityToken = new MockPriorityToken();
        priorityToken.setMinter(address(valueSettlementExecutor));
        uint256 mintSourceId = _createM421PrioritySource(
            workflowKey,
            "m421-priority-mint-source",
            priorityToken,
            2,
            AVADataTypes.ValueExecutionMode.Claim,
            AVADataTypes.ValueSettlementKind.PriorityTokenMint
        );

        valueSettlementExecutor.mintPriorityToken(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            mintSourceId,
            keccak256("executor-authority"),
            "ipfs://m421-priority-mint"
        );
        require(priorityToken.balanceOf(address(reviewerActor)) == 2, "priority token not minted");

        uint256 consumeSourceId = _createM421PrioritySource(
            workflowKey,
            "m421-priority-consume-source",
            priorityToken,
            1,
            AVADataTypes.ValueExecutionMode.Claim,
            AVADataTypes.ValueSettlementKind.PriorityTokenConsume
        );
        valueSettlementExecutor.consumePriorityToken(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            consumeSourceId,
            keccak256("executor-authority"),
            "ipfs://m421-priority-consume"
        );
        require(priorityToken.balanceOf(address(reviewerActor)) == 1, "priority token not consumed");
        _assertNoSelector(address(valueSettlementExecutor), "acceptManuscript(uint256)");
        _assertNoSelector(address(valueSettlementExecutor), "rejectManuscript(uint256)");
        _assertNoSelector(address(valueSettlementExecutor), "setManuscriptMerit(uint256,uint256)");
        _assertNoSelector(address(valueSettlementExecutor), "grantPublicationPriority(uint256)");
        _assertNoSelector(address(valueSettlementExecutor), "setReviewerLeniency(uint256,uint256)");
        _assertNoSelector(address(valueSettlementExecutor), "executeQueue(uint256)");
    }

    function testM85PrioritySettlementReceiptBindsSourceContextWithoutStandingTokenSemantics() public {
        bytes32 workflowKey = keccak256("m85-priority-context-workflow");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m85-priority-context-workflow");
        MockPriorityToken priorityToken = new MockPriorityToken();
        priorityToken.setMinter(address(valueSettlementExecutor));
        uint256 sourceId = _createM421PrioritySource(
            workflowKey,
            "m85-priority-context-source",
            priorityToken,
            4,
            AVADataTypes.ValueExecutionMode.Claim,
            AVADataTypes.ValueSettlementKind.PriorityTokenMint
        );

        uint256 settlementId = valueSettlementExecutor.mintPriorityToken(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m85-priority-context-settlement"
        );

        AVADataTypes.AllocationExecutionRecord memory source = allocationExecutor.getAllocationExecution(sourceId);
        AVADataTypes.ValueSettlementRecord memory settlement = valueSettlementExecutor.getValueSettlement(settlementId);
        ValueSettlementExecutor.SettlementContextInput memory expectedInput;
        expectedInput.sourceType = AVADataTypes.ExecutionSourceType.AllocationRecord;
        expectedInput.sourceRecordId = sourceId;
        expectedInput.packageId = source.packageId;
        expectedInput.subjectId = source.subjectId;
        expectedInput.asset = source.asset;
        expectedInput.payer = source.payer;
        expectedInput.recipient = settlement.recipient;
        expectedInput.amountOrUnits = source.amountOrUnits;
        expectedInput.sourceExecutionMode = source.executionMode;
        expectedInput.sourceSettlementKind = source.settlementKind;
        expectedInput.sourceExecutionReference = source.executionReference;
        expectedInput.settlementKind = settlement.kind;
        expectedInput.status = settlement.status;
        bytes32 expectedContextHash = valueSettlementExecutor.computeSettlementContextHash(expectedInput);

        require(settlement.sourceExecutionMode == source.executionMode, "settlement source mode missing");
        require(settlement.sourceSettlementKind == source.settlementKind, "settlement source kind missing");
        require(settlement.sourceExecutionReference == source.executionReference, "settlement source reference missing");
        require(settlement.settlementContextHash == expectedContextHash, "settlement context hash mismatch");
        require(priorityToken.balanceOf(address(reviewerActor)) == 4, "priority right token not minted");
        _assertNoSelector(address(priorityToken), "mintStanding(address,uint256)");
        _assertNoSelector(address(priorityToken), "mintReputation(address,uint256)");
        _assertNoSelector(address(priorityToken), "transferStanding(address,uint256)");
        _assertNoSelector(address(priorityToken), "transferReputation(address,uint256)");
        _assertNoSelector(address(valueSettlementExecutor), "grantPublicationPriority(uint256)");
        _assertNoSelector(address(valueSettlementExecutor), "setManuscriptMerit(uint256,uint256)");
    }

    function testM425ValueSettlementRequiresSourceSettlementKind() public {
        bytes32 workflowKey = keccak256("m425-settlement-kind-workflow");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m425-settlement-kind-workflow");

        MockPriorityToken priorityToken = new MockPriorityToken();
        priorityToken.setMinter(address(valueSettlementExecutor));
        uint256 consumeSourceId = _createM421PrioritySource(
            workflowKey,
            "m425-priority-consume-source",
            priorityToken,
            3,
            AVADataTypes.ValueExecutionMode.Claim,
            AVADataTypes.ValueSettlementKind.PriorityTokenConsume
        );
        try valueSettlementExecutor.mintPriorityToken(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            consumeSourceId,
            keccak256("executor-authority"),
            "ipfs://m425-consume-source-mint"
        ) {
            revert("priority consume source minted priority token");
        } catch {}
        require(priorityToken.balanceOf(address(reviewerActor)) == 0, "mismatched priority source changed balance");

        MockERC20 token = _m421FundedToken(20);
        uint256 clawbackSourceId =
            _createM425ClawbackPenaltySource(workflowKey, "m425-clawback-source", token, 5);
        try valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.ConsequenceRecord,
            clawbackSourceId,
            keccak256("executor-authority"),
            "ipfs://m425-clawback-as-token-transfer"
        ) {
            revert("clawback source settled as token transfer");
        } catch {}
        require(token.balanceOf(address(reviewerActor)) == 0, "mismatched consequence source paid subject");

        MockERC20 clawbackToken = _m421FundedToken(12);
        (uint256 recognisedStateId, uint256 evidenceId) =
            _createM421EligibleStateForSubject(workflowKey, keccak256("author-subject"), "m425-valid-clawback");
        AVADataTypes.ValueExecutionContext memory clawbackContext = _valueContext(
            recognisedStateId,
            keccak256("author-subject"),
            4,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://m425-valid-clawback",
            bytes32(evidenceId),
            address(clawbackToken),
            address(reviewerActor),
            AVADataTypes.ValueExecutionMode.Claim
        );
        clawbackContext.settlementKind = AVADataTypes.ValueSettlementKind.ClawbackTransfer;
        uint256 validClawbackSourceId =
            consequenceExecutor.recordPenaltyWithExecution(AVADataTypes.Role.Panel, clawbackContext);
        uint256 reviewerBefore = clawbackToken.balanceOf(address(reviewerActor));
        uint256 clawbackSettlementId = valueSettlementExecutor.settleClawback(
            AVADataTypes.Role.ProtocolExecutor,
            validClawbackSourceId,
            keccak256("executor-authority"),
            "ipfs://m425-valid-clawback-settlement"
        );
        require(clawbackToken.balanceOf(address(reviewerActor)) == reviewerBefore + 4, "clawback did not repay recipient");
        require(clawbackToken.balanceOf(address(this)) == 8, "clawback did not debit subject account");
        require(
            valueSettlementExecutor.getValueSettlement(clawbackSettlementId).kind
                == AVADataTypes.ValueSettlementKind.ClawbackTransfer,
            "clawback settlement kind missing"
        );
    }

    function testM425RecoveryReceiptsRejectRecordOnlySources() public {
        bytes32 workflowKey = keccak256("m425-record-only-recovery-workflow");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m425-record-only-recovery-workflow");
        uint256 sourceId = _createM421RecordOnlyRewardSource(workflowKey, "m425-record-only-recovery-source");
        uint256 nextSettlementId = valueSettlementExecutor.nextValueSettlementId();

        try valueSettlementExecutor.recordRepaymentObligation(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m425-record-only-repayment"
        ) {
            revert("record-only source created repayment obligation");
        } catch {}
        try valueSettlementExecutor.recordFuturePayoutSetoff(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m425-record-only-setoff"
        ) {
            revert("record-only source created future setoff");
        } catch {}
        try valueSettlementExecutor.recordWaiver(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m425-record-only-waiver"
        ) {
            revert("record-only source created waiver");
        } catch {}
        try valueSettlementExecutor.recordSatisfaction(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m425-record-only-satisfaction"
        ) {
            revert("record-only source created satisfaction");
        } catch {}
        require(valueSettlementExecutor.nextValueSettlementId() == nextSettlementId, "record-only recovery receipt stored");
    }

    function testM55RecoveryTerminalStateConflictsAreRejected() public {
        bytes32 workflowKey = keccak256("m55-recovery-terminal-workflow");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m55-recovery-terminal-workflow");
        MockERC20 token = _m421FundedToken(100);
        uint256 sourceId =
            _createM421RewardSource(workflowKey, "m55-terminal-source", token, 8, AVADataTypes.ValueExecutionMode.Claim);

        valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m55-terminal-execution"
        );
        uint256 obligationId = valueSettlementExecutor.recordRepaymentObligation(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m55-terminal-obligation"
        );
        uint256 setoffId = valueSettlementExecutor.recordFuturePayoutSetoff(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m55-terminal-setoff"
        );

        bytes32 sourceKey =
            keccak256(abi.encode(AVADataTypes.ExecutionSourceType.AllocationRecord, sourceId));
        require(valueSettlementExecutor.getValueSettlement(obligationId).status == AVADataTypes.ValueSettlementStatus.ObligationRecorded, "obligation missing");
        require(valueSettlementExecutor.recoveryTerminalSettlementIdBySourceKey(sourceKey) == setoffId, "terminal settlement id missing");
        require(
            valueSettlementExecutor.recoveryTerminalStatusBySourceKey(sourceKey)
                == AVADataTypes.ValueSettlementStatus.SetoffRecorded,
            "terminal status missing"
        );

        uint256 nextSettlementId = valueSettlementExecutor.nextValueSettlementId();
        try valueSettlementExecutor.recordWaiver(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m55-conflicting-waiver"
        ) {
            revert("waiver accepted after setoff terminal");
        } catch {}
        try valueSettlementExecutor.recordSatisfaction(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m55-conflicting-satisfaction"
        ) {
            revert("satisfaction accepted after setoff terminal");
        } catch {}
        try valueSettlementExecutor.recordRepaymentObligation(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m55-conflicting-obligation"
        ) {
            revert("repayment obligation accepted after recovery terminal");
        } catch {}
        require(valueSettlementExecutor.nextValueSettlementId() == nextSettlementId, "conflicting recovery receipt stored");
    }

    function testM55EscrowTerminalConflictsRejectRefundAndOpenRecovery() public {
        bytes32 workflowKey = keccak256("m55-escrow-terminal-workflow");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m55-escrow-terminal-workflow");
        MockERC20 token = _m421FundedToken(100);
        uint256 sourceId =
            _createM421RewardSource(workflowKey, "m55-escrow-source", token, 11, AVADataTypes.ValueExecutionMode.Escrow);

        valueSettlementExecutor.depositEscrow(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m55-escrow-deposit"
        );
        uint256 nextSettlementId = valueSettlementExecutor.nextValueSettlementId();
        try valueSettlementExecutor.recordFuturePayoutSetoff(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m55-open-escrow-setoff"
        ) {
            revert("open escrow accepted recovery terminal");
        } catch {}
        require(valueSettlementExecutor.nextValueSettlementId() == nextSettlementId, "open escrow recovery receipt stored");

        valueSettlementExecutor.claimEscrow(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m55-escrow-claim"
        );
        try valueSettlementExecutor.refundEscrow(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m55-escrow-refund-after-claim"
        ) {
            revert("refund accepted after escrow claim");
        } catch {}

        uint256 refundSourceId =
            _createM421RewardSource(workflowKey, "m55-refunded-source", token, 5, AVADataTypes.ValueExecutionMode.Escrow);
        valueSettlementExecutor.depositEscrow(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            refundSourceId,
            keccak256("executor-authority"),
            "ipfs://m55-refund-deposit"
        );
        valueSettlementExecutor.refundEscrow(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            refundSourceId,
            keccak256("executor-authority"),
            "ipfs://m55-refund-terminal"
        );
        nextSettlementId = valueSettlementExecutor.nextValueSettlementId();
        try valueSettlementExecutor.recordSatisfaction(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            refundSourceId,
            keccak256("executor-authority"),
            "ipfs://m55-refunded-satisfaction"
        ) {
            revert("refunded escrow accepted recovery terminal");
        } catch {}
        require(valueSettlementExecutor.nextValueSettlementId() == nextSettlementId, "refunded escrow recovery receipt stored");
    }

    function testM421PrivacyAccessGrantRevocationAndDisclosureIntentAreRecordOnly() public {
        uint256 policyId = _registerDisclosurePolicy("m421-access-policy");
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            keccak256("m421-access-evidence"),
            "ipfs://m421-access-evidence",
            "privacy-access-reference",
            policyId
        );
        uint256 grantId = disclosureAccessExecutor.recordAccessGrant(
            AVADataTypes.Role.Panel,
            DEFAULT_WORKFLOW,
            AVADataTypes.DisclosureTargetKind.EvidenceReceipt,
            evidenceId,
            policyId,
            REVIEWER_SUBJECT,
            block.timestamp + 1 days,
            keccak256("panel-authority"),
            "ipfs://m421-access-grant"
        );
        require(
            disclosureAccessExecutor.getDisclosureExecution(grantId).kind
                == AVADataTypes.DisclosureExecutionKind.AccessGrant,
            "access grant not recorded"
        );
        uint256 revocationId = disclosureAccessExecutor.recordAccessRevocation(
            AVADataTypes.Role.Panel, grantId, keccak256("panel-authority"), "ipfs://m421-access-revocation"
        );
        require(
            disclosureAccessExecutor.getDisclosureExecution(grantId).status
                == AVADataTypes.DisclosureExecutionStatus.Revoked,
            "grant not marked revoked"
        );
        require(
            disclosureAccessExecutor.getDisclosureExecution(revocationId).kind
                == AVADataTypes.DisclosureExecutionKind.AccessRevocation,
            "revocation not recorded"
        );
        uint256 intentId = disclosureAccessExecutor.recordVoluntaryDisclosureIntent(
            AVADataTypes.Role.Panel,
            DEFAULT_WORKFLOW,
            AVADataTypes.DisclosureTargetKind.EvidenceReceipt,
            evidenceId,
            policyId,
            keccak256("panel-authority"),
            "ipfs://m421-voluntary-intent"
        );
        require(
            disclosureAccessExecutor.getDisclosureExecution(intentId).kind
                == AVADataTypes.DisclosureExecutionKind.VoluntaryDisclosureIntent,
            "voluntary intent not recorded"
        );

        bytes32 rejectingWorkflow = keccak256("m421-rejecting-disclosure-workflow");
        KindRejectingDisclosureExecutionModule rejectingModule =
            new KindRejectingDisclosureExecutionModule(AVADataTypes.DisclosureExecutionKind.AccessGrant);
        _registerM421ExecutionWorkflowWithDisclosureExecution(
            rejectingWorkflow, rejectingModule, "ipfs://m421-rejecting-disclosure-workflow"
        );
        uint256 rejectingPolicyId = _registerDisclosurePolicy("m421-rejecting-access-policy");
        uint256 rejectingEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            rejectingWorkflow,
            keccak256("m421-rejecting-access-evidence"),
            "ipfs://m421-rejecting-access-evidence",
            "privacy-access-reference",
            rejectingPolicyId
        );
        try disclosureAccessExecutor.recordAccessGrant(
            AVADataTypes.Role.Panel,
            rejectingWorkflow,
            AVADataTypes.DisclosureTargetKind.EvidenceReceipt,
            rejectingEvidenceId,
            rejectingPolicyId,
            REVIEWER_SUBJECT,
            block.timestamp + 1 days,
            keccak256("panel-authority"),
            "ipfs://m421-rejected-access-grant"
        ) {
            revert("workflow-specific disclosure execution module was bypassed");
        } catch {}
        disclosureAccessExecutor.recordVoluntaryDisclosureIntent(
            AVADataTypes.Role.Panel,
            rejectingWorkflow,
            AVADataTypes.DisclosureTargetKind.EvidenceReceipt,
            rejectingEvidenceId,
            rejectingPolicyId,
            keccak256("panel-authority"),
            "ipfs://m421-rejecting-workflow-voluntary-intent"
        );
        _assertNoSelector(address(disclosureAccessExecutor), "revealIdentity(uint256)");
        _assertNoSelector(address(disclosureAccessExecutor), "revealEvidence(uint256)");
        _assertNoSelector(address(disclosureAccessExecutor), "decryptEvidence(uint256)");
    }

    function testM53AccessGrantExpiryPreventsLateRevocationAndLinksClosureRecords() public {
        uint256 policyId = _registerDisclosurePolicy("m53-access-expiry-policy");
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            keccak256("m53-access-expiry-evidence"),
            "ipfs://m53-access-expiry-evidence",
            "privacy-access-reference",
            policyId
        );
        uint256 grantExpiry = block.timestamp + 1 days;
        uint256 grantId = disclosureAccessExecutor.recordAccessGrant(
            AVADataTypes.Role.Panel,
            DEFAULT_WORKFLOW,
            AVADataTypes.DisclosureTargetKind.EvidenceReceipt,
            evidenceId,
            policyId,
            REVIEWER_SUBJECT,
            grantExpiry,
            keccak256("panel-authority"),
            "ipfs://m53-access-grant"
        );

        try disclosureAccessExecutor.recordAccessExpiry(
            AVADataTypes.Role.Panel, grantId, keccak256("panel-authority"), "ipfs://m53-too-early-expiry"
        ) {
            revert("access expiry accepted before expiry time");
        } catch {}

        vm.warp(grantExpiry + 1);
        try disclosureAccessExecutor.recordAccessRevocation(
            AVADataTypes.Role.Panel, grantId, keccak256("panel-authority"), "ipfs://m53-late-revocation"
        ) {
            revert("late revocation accepted instead of explicit expiry");
        } catch {}

        uint256 expiryRecordId = disclosureAccessExecutor.recordAccessExpiry(
            AVADataTypes.Role.Panel, grantId, keccak256("panel-authority"), "ipfs://m53-access-expiry"
        );
        AVADataTypes.DisclosureExecutionRecord memory grant = disclosureAccessExecutor.getDisclosureExecution(grantId);
        AVADataTypes.DisclosureExecutionRecord memory expiry =
            disclosureAccessExecutor.getDisclosureExecution(expiryRecordId);
        require(grant.status == AVADataTypes.DisclosureExecutionStatus.Expired, "grant not marked expired");
        require(expiry.kind == AVADataTypes.DisclosureExecutionKind.ExpiryExecuted, "expiry record kind wrong");
        require(expiry.status == AVADataTypes.DisclosureExecutionStatus.Expired, "expiry record status wrong");
        require(expiry.sourceDisclosureExecutionId == grantId, "expiry not linked to grant");
    }

    function testM73AccessGrantSupersessionClosesGrantAndRejectsDuplicateClosure() public {
        uint256 policyId = _registerDisclosurePolicy("m73-access-supersession-policy");
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            keccak256("m73-access-supersession-evidence"),
            "ipfs://m73-access-supersession-evidence",
            "privacy-access-reference",
            policyId
        );
        uint256 grantId = disclosureAccessExecutor.recordAccessGrant(
            AVADataTypes.Role.Panel,
            DEFAULT_WORKFLOW,
            AVADataTypes.DisclosureTargetKind.EvidenceReceipt,
            evidenceId,
            policyId,
            REVIEWER_SUBJECT,
            block.timestamp + 1 days,
            keccak256("panel-authority"),
            "ipfs://m73-access-grant"
        );

        uint256 supersessionId = disclosureAccessExecutor.recordAccessSupersession(
            AVADataTypes.Role.Panel, grantId, keccak256("panel-authority"), "ipfs://m73-access-supersession"
        );
        AVADataTypes.DisclosureExecutionRecord memory grant = disclosureAccessExecutor.getDisclosureExecution(grantId);
        AVADataTypes.DisclosureExecutionRecord memory supersession =
            disclosureAccessExecutor.getDisclosureExecution(supersessionId);
        require(grant.status == AVADataTypes.DisclosureExecutionStatus.Superseded, "grant not superseded");
        require(
            supersession.kind == AVADataTypes.DisclosureExecutionKind.SupersessionExecuted,
            "supersession kind wrong"
        );
        require(
            supersession.status == AVADataTypes.DisclosureExecutionStatus.Superseded,
            "supersession status wrong"
        );
        require(supersession.sourceDisclosureExecutionId == grantId, "supersession not linked to grant");
        require(supersession.packageId == grant.packageId, "supersession package drifted");

        try disclosureAccessExecutor.recordAccessRevocation(
            AVADataTypes.Role.Panel, grantId, keccak256("panel-authority"), "ipfs://m73-revoke-superseded-grant"
        ) {
            revert("revocation accepted superseded grant");
        } catch {}
        try disclosureAccessExecutor.recordAccessSupersession(
            AVADataTypes.Role.Panel, grantId, keccak256("panel-authority"), "ipfs://m73-duplicate-supersession"
        ) {
            revert("duplicate supersession accepted");
        } catch {}
    }

    function testM53AccessRevocationLinksClosedGrantAndRejectsInvalidExpiry() public {
        uint256 policyId = _registerDisclosurePolicy("m53-revocation-policy");
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            keccak256("m53-revocation-evidence"),
            "ipfs://m53-revocation-evidence",
            "privacy-access-reference",
            policyId
        );
        try disclosureAccessExecutor.recordAccessGrant(
            AVADataTypes.Role.Panel,
            DEFAULT_WORKFLOW,
            AVADataTypes.DisclosureTargetKind.EvidenceReceipt,
            evidenceId,
            policyId,
            REVIEWER_SUBJECT,
            block.timestamp,
            keccak256("panel-authority"),
            "ipfs://m53-zero-duration-grant"
        ) {
            revert("access grant accepted non-future expiry");
        } catch {}

        uint256 grantId = disclosureAccessExecutor.recordAccessGrant(
            AVADataTypes.Role.Panel,
            DEFAULT_WORKFLOW,
            AVADataTypes.DisclosureTargetKind.EvidenceReceipt,
            evidenceId,
            policyId,
            REVIEWER_SUBJECT,
            block.timestamp + 1 days,
            keccak256("panel-authority"),
            "ipfs://m53-revocable-grant"
        );
        uint256 revocationId = disclosureAccessExecutor.recordAccessRevocation(
            AVADataTypes.Role.Panel, grantId, keccak256("panel-authority"), "ipfs://m53-revocation"
        );
        AVADataTypes.DisclosureExecutionRecord memory revocation =
            disclosureAccessExecutor.getDisclosureExecution(revocationId);
        require(revocation.sourceDisclosureExecutionId == grantId, "revocation not linked to grant");
        require(
            disclosureAccessExecutor.getDisclosureExecution(grantId).status
                == AVADataTypes.DisclosureExecutionStatus.Revoked,
            "grant not revoked"
        );
        try disclosureAccessExecutor.recordAccessExpiry(
            AVADataTypes.Role.Panel, grantId, keccak256("panel-authority"), "ipfs://m53-expire-revoked"
        ) {
            revert("revoked grant accepted expiry");
        } catch {}
    }

    function testM53DisclosureLifecycleExecutionStoresExpiryAndSupersessionStatuses() public {
        uint256 policyId = _registerDisclosurePolicy("m53-policy-lifecycle");
        uint256 expiryRecordId = disclosureAccessExecutor.recordDisclosureLifecycleExecution(
            AVADataTypes.Role.Panel,
            DEFAULT_WORKFLOW,
            AVADataTypes.DisclosureExecutionKind.ExpiryExecuted,
            AVADataTypes.DisclosureTargetKind.DisclosurePolicy,
            policyId,
            policyId,
            keccak256("panel-authority"),
            "ipfs://m53-policy-expiry"
        );
        uint256 supersessionRecordId = disclosureAccessExecutor.recordDisclosureLifecycleExecution(
            AVADataTypes.Role.Panel,
            DEFAULT_WORKFLOW,
            AVADataTypes.DisclosureExecutionKind.SupersessionExecuted,
            AVADataTypes.DisclosureTargetKind.DisclosurePolicy,
            policyId,
            policyId,
            keccak256("panel-authority"),
            "ipfs://m53-policy-supersession"
        );

        require(
            disclosureAccessExecutor.getDisclosureExecution(expiryRecordId).status
                == AVADataTypes.DisclosureExecutionStatus.Expired,
            "policy expiry status missing"
        );
        require(
            disclosureAccessExecutor.getDisclosureExecution(supersessionRecordId).status
                == AVADataTypes.DisclosureExecutionStatus.Superseded,
            "policy supersession status missing"
        );
        _assertNoSelector(address(disclosureAccessExecutor), "enforceAccess(uint256)");
        _assertNoSelector(address(disclosureAccessExecutor), "revealIdentity(uint256)");
        _assertNoSelector(address(disclosureAccessExecutor), "decryptEvidence(uint256)");
    }

    function testM426DisclosureExecutionUsesTargetPackageAfterWorkflowReconfiguration() public {
        bytes32 workflowKey = keccak256("m426-disclosure-execution-package");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m426-disclosure-execution-v1");
        uint256 policyId = _registerDisclosurePolicy("m426-disclosure-execution-policy");
        uint256 oldEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m426-old-disclosure-evidence"),
            "ipfs://m426-old-disclosure-evidence",
            "disclosure-execution-package-basis",
            policyId
        );
        uint256 oldPackageId = evidenceRegistry.getEvidenceReceipt(oldEvidenceId).packageId;

        KindRejectingDisclosureExecutionModule rejectingModule =
            new KindRejectingDisclosureExecutionModule(AVADataTypes.DisclosureExecutionKind.AccessGrant);
        _registerM421ExecutionWorkflowWithDisclosureExecution(
            workflowKey, rejectingModule, "ipfs://m426-disclosure-execution-v2"
        );
        uint256 newEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m426-new-disclosure-evidence"),
            "ipfs://m426-new-disclosure-evidence",
            "disclosure-execution-package-basis",
            policyId
        );

        uint256 oldGrantId = disclosureAccessExecutor.recordAccessGrant(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVADataTypes.DisclosureTargetKind.EvidenceReceipt,
            oldEvidenceId,
            policyId,
            REVIEWER_SUBJECT,
            block.timestamp + 1 days,
            keccak256("panel-authority"),
            "ipfs://m426-old-access-grant"
        );
        require(disclosureAccessExecutor.getDisclosureExecution(oldGrantId).packageId == oldPackageId, "old package not used");

        try disclosureAccessExecutor.recordAccessGrant(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVADataTypes.DisclosureTargetKind.EvidenceReceipt,
            newEvidenceId,
            policyId,
            REVIEWER_SUBJECT,
            block.timestamp + 1 days,
            keccak256("panel-authority"),
            "ipfs://m426-new-access-grant"
        ) {
            revert("new package disclosure execution module was not used");
        } catch {}
    }

    function testM426LegacyDisclosureExecutionConfigurationCannotOverrideRulePackageModule() public {
        bytes32 workflowKey = keccak256("m426-legacy-disclosure-config");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m426-legacy-disclosure-config");
        KindRejectingDisclosureExecutionModule rejectingModule =
            new KindRejectingDisclosureExecutionModule(AVADataTypes.DisclosureExecutionKind.AccessGrant);
        address packageModule = address(disclosureAccessExecutor.getWorkflowExecutionModule(workflowKey));

        try disclosureAccessExecutor.configureWorkflowExecutionModule(
            AVADataTypes.Role.Panel, workflowKey, rejectingModule, keccak256("panel-authority")
        ) {
            revert("legacy disclosure execution config mutated package module");
        } catch {}

        require(
            address(disclosureAccessExecutor.getWorkflowExecutionModule(workflowKey)) == packageModule,
            "legacy config changed package-bound module"
        );
    }

    function testM421AnonymousChallengeProofUseRejectsNullifierReplay() public {
        uint256 policyId = _registerDisclosurePolicy("m421-anonymous-policy");
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        roleRegistry.assignRole(
            address(this), AVADataTypes.Role.Challenger, subjectCommitment, "ipfs://m421-anonymous-challenger"
        );
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 evidenceId = evidenceRegistry.registerEvidenceReceipt(
            AVADataTypes.Role.Challenger,
            DEFAULT_WORKFLOW,
            keccak256("m421-anonymous-evidence"),
            "ipfs://m421-anonymous-evidence",
            "anonymous-challenge-proof",
            policyId
        );
        uint256 challengeId = stateMachine.fileChallenge(
            AVADataTypes.Role.Challenger, DEFAULT_WORKFLOW, recognisedStateId, subjectCommitment, evidenceId, policyId
        );
        bytes32 contextHash = zkProofRegistry.computeDisclosureContextHash(
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.RecordDisclosureExecution,
            bytes32(challengeId),
            AVADataTypes.Role.Challenger,
            policyId,
            subjectCommitment
        );
        uint256 proofReceiptId = zkProofRegistry.registerProof(
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.RecordDisclosureExecution,
            bytes32(challengeId),
            AVADataTypes.Role.Challenger,
            policyId,
            subjectCommitment,
            _makeSchnorrProof(contextHash, 7, 11)
        );
        ZKProofRegistry.ProofReceipt memory receipt = zkProofRegistry.getProofReceipt(proofReceiptId);
        uint256 useId = disclosureAccessExecutor.recordAnonymousChallengeProofUse(
            AVADataTypes.Role.Challenger,
            challengeId,
            policyId,
            proofReceiptId,
            subjectCommitment,
            receipt.nullifierHash,
            "ipfs://m421-anonymous-proof-use"
        );
        require(
            disclosureAccessExecutor.getDisclosureExecution(useId).kind
                == AVADataTypes.DisclosureExecutionKind.AnonymousChallengeUse,
            "anonymous proof use not recorded"
        );
        try disclosureAccessExecutor.recordAnonymousChallengeProofUse(
            AVADataTypes.Role.Challenger,
            challengeId,
            policyId,
            proofReceiptId,
            subjectCommitment,
            receipt.nullifierHash,
            "ipfs://m421-anonymous-proof-replay"
        ) {
            revert("anonymous challenge nullifier replay accepted");
        } catch {}
    }

    function testM83AnonymousProofUseRecordStoresProofContextVerifierAndDomain() public {
        uint256 policyId = _registerDisclosurePolicy("m83-anonymous-proof-use-policy");
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        roleRegistry.assignRole(
            address(this), AVADataTypes.Role.Challenger, subjectCommitment, "ipfs://m83-anonymous-challenger"
        );
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 evidenceId = evidenceRegistry.registerEvidenceReceipt(
            AVADataTypes.Role.Challenger,
            DEFAULT_WORKFLOW,
            keccak256("m83-anonymous-proof-use-evidence"),
            "ipfs://m83-anonymous-proof-use-evidence",
            "anonymous-challenge-proof",
            policyId
        );
        uint256 challengeId = stateMachine.fileChallenge(
            AVADataTypes.Role.Challenger, DEFAULT_WORKFLOW, recognisedStateId, subjectCommitment, evidenceId, policyId
        );
        bytes32 contextHash = zkProofRegistry.computeDisclosureContextHash(
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.RecordDisclosureExecution,
            bytes32(challengeId),
            AVADataTypes.Role.Challenger,
            policyId,
            subjectCommitment
        );
        uint256 proofReceiptId = zkProofRegistry.registerProof(
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.RecordDisclosureExecution,
            bytes32(challengeId),
            AVADataTypes.Role.Challenger,
            policyId,
            subjectCommitment,
            _makeSchnorrProof(contextHash, 7, 11)
        );
        ZKProofRegistry.ProofReceipt memory proofReceipt = zkProofRegistry.getProofReceipt(proofReceiptId);
        uint256 useId = disclosureAccessExecutor.recordAnonymousChallengeProofUse(
            AVADataTypes.Role.Challenger,
            challengeId,
            policyId,
            proofReceiptId,
            subjectCommitment,
            proofReceipt.nullifierHash,
            "ipfs://m83-anonymous-proof-use"
        );
        AVADataTypes.DisclosureExecutionRecord memory useRecord =
            disclosureAccessExecutor.getDisclosureExecution(useId);
        require(useRecord.proofReceiptId == proofReceiptId, "proof receipt id missing");
        require(useRecord.proofContextHash == proofReceipt.contextHash, "proof context missing");
        require(useRecord.proofVerifier == proofReceipt.verifier, "proof verifier missing");
        require(useRecord.proofDomainHash == proofReceipt.proofDomainHash, "proof domain missing");
    }

    function testM426AnonymousChallengeProofUseRejectsNewPackageProofForOldChallenge() public {
        uint256 policyId = _registerDisclosurePolicy("m426-anonymous-package-policy");
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        roleRegistry.assignRole(
            address(this), AVADataTypes.Role.Challenger, subjectCommitment, "ipfs://m426-package-challenger"
        );
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 evidenceId = evidenceRegistry.registerEvidenceReceipt(
            AVADataTypes.Role.Challenger,
            DEFAULT_WORKFLOW,
            keccak256("m426-anonymous-package-evidence"),
            "ipfs://m426-anonymous-package-evidence",
            "anonymous-challenge-proof",
            policyId
        );
        uint256 challengeId = stateMachine.fileChallenge(
            AVADataTypes.Role.Challenger, DEFAULT_WORKFLOW, recognisedStateId, subjectCommitment, evidenceId, policyId
        );
        uint256 oldChallengePackageId = stateMachine.getChallenge(challengeId).packageId;

        _registerM421ExecutionWorkflow(DEFAULT_WORKFLOW, "ipfs://m426-anonymous-package-v2");
        uint256 activePackageId = rulePackageRegistry.getRulePackage(DEFAULT_WORKFLOW).packageId;
        require(activePackageId != oldChallengePackageId, "workflow package was not replaced");

        bytes32 contextHash = zkProofRegistry.computeDisclosureContextHash(
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.RecordDisclosureExecution,
            bytes32(challengeId),
            AVADataTypes.Role.Challenger,
            policyId,
            subjectCommitment
        );
        uint256 proofReceiptId = zkProofRegistry.registerProof(
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.RecordDisclosureExecution,
            bytes32(challengeId),
            AVADataTypes.Role.Challenger,
            policyId,
            subjectCommitment,
            _makeSchnorrProof(contextHash, 7, 11)
        );
        ZKProofRegistry.ProofReceipt memory receipt = zkProofRegistry.getProofReceipt(proofReceiptId);
        require(receipt.packageId == activePackageId, "proof did not bind active package");

        try disclosureAccessExecutor.recordAnonymousChallengeProofUse(
            AVADataTypes.Role.Challenger,
            challengeId,
            policyId,
            proofReceiptId,
            subjectCommitment,
            receipt.nullifierHash,
            "ipfs://m426-cross-package-proof-use"
        ) {
            revert("anonymous challenge proof use accepted proof from replaced package");
        } catch {}
    }

    function testM426AnonymousChallengeProofUseCanRegisterOldPackageProofAfterWorkflowReregistration() public {
        uint256 policyId = _registerDisclosurePolicy("m426-old-package-proof-policy");
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        roleRegistry.assignRole(
            address(this), AVADataTypes.Role.Challenger, subjectCommitment, "ipfs://m426-old-package-challenger"
        );
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 evidenceId = evidenceRegistry.registerEvidenceReceipt(
            AVADataTypes.Role.Challenger,
            DEFAULT_WORKFLOW,
            keccak256("m426-old-package-proof-evidence"),
            "ipfs://m426-old-package-proof-evidence",
            "anonymous-challenge-proof",
            policyId
        );
        uint256 challengeId = stateMachine.fileChallenge(
            AVADataTypes.Role.Challenger, DEFAULT_WORKFLOW, recognisedStateId, subjectCommitment, evidenceId, policyId
        );
        uint256 oldChallengePackageId = stateMachine.getChallenge(challengeId).packageId;

        _registerM421ExecutionWorkflow(DEFAULT_WORKFLOW, "ipfs://m426-old-package-proof-v2");
        require(
            rulePackageRegistry.getRulePackage(DEFAULT_WORKFLOW).packageId != oldChallengePackageId,
            "workflow package was not replaced"
        );

        bytes32 oldContextHash = zkProofRegistry.computeDisclosureContextHashForPackage(
            oldChallengePackageId,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.RecordDisclosureExecution,
            bytes32(challengeId),
            AVADataTypes.Role.Challenger,
            policyId,
            subjectCommitment
        );
        try zkProofRegistry.registerProofForPackage(
            oldChallengePackageId,
            keccak256("wrong-workflow"),
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.RecordDisclosureExecution,
            bytes32(challengeId),
            AVADataTypes.Role.Challenger,
            policyId,
            subjectCommitment,
            _makeSchnorrProof(oldContextHash, 7, 13)
        ) {
            revert("package-bound proof accepted wrong workflow");
        } catch {}
        uint256 proofReceiptId = zkProofRegistry.registerProofForPackage(
            oldChallengePackageId,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.RecordDisclosureExecution,
            bytes32(challengeId),
            AVADataTypes.Role.Challenger,
            policyId,
            subjectCommitment,
            _makeSchnorrProof(oldContextHash, 7, 11)
        );
        ZKProofRegistry.ProofReceipt memory receipt = zkProofRegistry.getProofReceipt(proofReceiptId);
        require(receipt.packageId == oldChallengePackageId, "proof did not bind old package");

        uint256 useId = disclosureAccessExecutor.recordAnonymousChallengeProofUse(
            AVADataTypes.Role.Challenger,
            challengeId,
            policyId,
            proofReceiptId,
            subjectCommitment,
            receipt.nullifierHash,
            "ipfs://m426-old-package-proof-use"
        );
        AVADataTypes.DisclosureExecutionRecord memory useRecord =
            disclosureAccessExecutor.getDisclosureExecution(useId);
        require(useRecord.packageId == oldChallengePackageId, "proof use did not bind old package");
        require(useRecord.proofContextHash == oldContextHash, "old proof context missing");
    }

    function testM426AnonymousChallengeProofUseRequiresTargetBoundProofContext() public {
        uint256 policyId = _registerDisclosurePolicy("m426-anonymous-context-policy");
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        roleRegistry.assignRole(
            address(this), AVADataTypes.Role.Challenger, subjectCommitment, "ipfs://m426-anonymous-challenger"
        );
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 evidenceId = evidenceRegistry.registerEvidenceReceipt(
            AVADataTypes.Role.Challenger,
            DEFAULT_WORKFLOW,
            keccak256("m426-anonymous-context-evidence"),
            "ipfs://m426-anonymous-context-evidence",
            "anonymous-challenge-proof",
            policyId
        );
        uint256 challengeId = stateMachine.fileChallenge(
            AVADataTypes.Role.Challenger, DEFAULT_WORKFLOW, recognisedStateId, subjectCommitment, evidenceId, policyId
        );
        bytes32 wrongObjectId = bytes32(challengeId + 100);
        bytes32 wrongContextHash = zkProofRegistry.computeDisclosureContextHash(
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.RecordDisclosureExecution,
            wrongObjectId,
            AVADataTypes.Role.Challenger,
            policyId,
            subjectCommitment
        );
        uint256 proofReceiptId = zkProofRegistry.registerProof(
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.RecordDisclosureExecution,
            wrongObjectId,
            AVADataTypes.Role.Challenger,
            policyId,
            subjectCommitment,
            _makeSchnorrProof(wrongContextHash, 7, 11)
        );
        ZKProofRegistry.ProofReceipt memory receipt = zkProofRegistry.getProofReceipt(proofReceiptId);

        try disclosureAccessExecutor.recordAnonymousChallengeProofUse(
            AVADataTypes.Role.Challenger,
            challengeId,
            policyId,
            proofReceiptId,
            subjectCommitment,
            receipt.nullifierHash,
            "ipfs://m426-wrong-context-proof-use"
        ) {
            revert("anonymous challenge proof use accepted wrong proof context");
        } catch {}
    }

    function testM426AnonymousChallengeProofUseRequiresChallengeSubjectMatch() public {
        uint256 policyId = _registerDisclosurePolicy("m426-anonymous-subject-policy");
        bytes32 originalSubject = _subjectCommitmentForSecret(7);
        bytes32 otherSubject = _subjectCommitmentForSecret(9);
        roleRegistry.assignRole(
            address(this), AVADataTypes.Role.Challenger, originalSubject, "ipfs://m426-original-anonymous-challenger"
        );
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 evidenceId = evidenceRegistry.registerEvidenceReceipt(
            AVADataTypes.Role.Challenger,
            DEFAULT_WORKFLOW,
            keccak256("m426-anonymous-subject-evidence"),
            "ipfs://m426-anonymous-subject-evidence",
            "anonymous-challenge-proof",
            policyId
        );
        uint256 challengeId = stateMachine.fileChallenge(
            AVADataTypes.Role.Challenger, DEFAULT_WORKFLOW, recognisedStateId, originalSubject, evidenceId, policyId
        );
        roleRegistry.deactivateSubject(originalSubject);
        roleRegistry.assignRole(
            address(this), AVADataTypes.Role.Challenger, otherSubject, "ipfs://m426-other-anonymous-challenger"
        );
        bytes32 contextHash = zkProofRegistry.computeDisclosureContextHash(
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.RecordDisclosureExecution,
            bytes32(challengeId),
            AVADataTypes.Role.Challenger,
            policyId,
            otherSubject
        );
        uint256 proofReceiptId = zkProofRegistry.registerProof(
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.RecordDisclosureExecution,
            bytes32(challengeId),
            AVADataTypes.Role.Challenger,
            policyId,
            otherSubject,
            _makeSchnorrProof(contextHash, 9, 11)
        );
        ZKProofRegistry.ProofReceipt memory receipt = zkProofRegistry.getProofReceipt(proofReceiptId);

        try disclosureAccessExecutor.recordAnonymousChallengeProofUse(
            AVADataTypes.Role.Challenger,
            challengeId,
            policyId,
            proofReceiptId,
            otherSubject,
            receipt.nullifierHash,
            "ipfs://m426-wrong-subject-proof-use"
        ) {
            revert("anonymous challenge proof use accepted non-challenger subject");
        } catch {}
    }

    function testM421ExternalOperationIntentRecordsCannotExecutePublicationDecisions() public {
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            keccak256("m421-external-operation-evidence"),
            "ipfs://m421-external-operation-evidence",
            "external-operation-reference",
            0
        );
        uint256 recognisedStateId = _registerRecognisedStateForWorkflowStatus(
            DEFAULT_WORKFLOW, AVADataTypes.RecognisedStateStatus.Vested, evidenceId, "m421-external-operation-state"
        );
        uint256 operationId = externalOperationRegistry.requestOperation(
            AVADataTypes.Role.Panel,
            DEFAULT_WORKFLOW,
            AVADataTypes.ExternalOperationKind.EditorialSyncIntent,
            AVADataTypes.ExternalOperationTargetKind.RecognisedState,
            recognisedStateId,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://m421-external-operation"
        );
        require(
            externalOperationRegistry.getExternalOperation(operationId).status
                == AVADataTypes.ExternalOperationStatus.Requested,
            "external operation request not recorded"
        );
        uint256 acknowledgementId = externalOperationRegistry.acknowledgeOperation(
            AVADataTypes.Role.Panel, operationId, keccak256("panel-authority"), "ipfs://m421-external-ack"
        );
        AVADataTypes.ExternalOperationRecord memory acknowledgement =
            externalOperationRegistry.getExternalOperation(acknowledgementId);
        require(
            acknowledgement.status == AVADataTypes.ExternalOperationStatus.Acknowledged,
            "external operation acknowledgement not recorded"
        );
        require(acknowledgement.sourceOperationId == operationId, "terminal receipt missing source operation");
        require(
            externalOperationRegistry.terminalReceiptIdByOperation(operationId) == acknowledgementId,
            "terminal operation receipt not linked"
        );
        try externalOperationRegistry.cancelOperation(
            AVADataTypes.Role.Panel, operationId, keccak256("panel-authority"), "ipfs://m421-external-cancel-again"
        ) {
            revert("external operation terminal status changed twice");
        } catch {}
        _assertNoSelector(address(externalOperationRegistry), "acceptManuscript(uint256)");
        _assertNoSelector(address(externalOperationRegistry), "rejectManuscript(uint256)");
        _assertNoSelector(address(externalOperationRegistry), "setManuscriptMerit(uint256,uint256)");
        _assertNoSelector(address(externalOperationRegistry), "grantPublicationPriority(uint256)");
        _assertNoSelector(address(externalOperationRegistry), "executeQueue(uint256)");
    }

    function testM56ExternalOperationTargetsAllBoundRecordTypes() public {
        bytes32 workflowKey = keccak256("m56-target-bound-workflow");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m56-target-bound-workflow");
        MockERC20 token = _m421FundedToken(100);
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m56-target-evidence"),
            "ipfs://m56-target-evidence",
            "external-operation-reference",
            0
        );
        uint256 recognisedStateId = _registerRecognisedStateForWorkflowStatus(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, evidenceId, "m56-target-state"
        );

        AVARulePackageRegistry.RulePackage memory rulePackage = rulePackageRegistry.getRulePackage(workflowKey);
        uint256 challengeStateId = _createChallengeableReviewStateThroughPackage(rulePackage, workflowKey);
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            workflowKey,
            keccak256("m56-target-challenge-evidence"),
            "ipfs://m56-target-challenge-evidence",
            "external-operation-challenge-reference",
            0
        );
        uint256 challengeId = challengerActor.fileChallenge(
            stateMachine,
            AVADataTypes.Role.Challenger,
            workflowKey,
            challengeStateId,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            0
        );
        uint256 allocationId =
            _createM421RewardSource(workflowKey, "m56-target-allocation", token, 3, AVADataTypes.ValueExecutionMode.Claim);
        uint256 consequenceId = consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            AVADataTypes.ConsequenceKind.AdministrativeNote,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://m56-target-consequence"
        );

        _assertM56OperationTarget(
            workflowKey,
            AVADataTypes.ExternalOperationTargetKind.RecognisedState,
            recognisedStateId,
            evidenceId
        );
        _assertM56OperationTarget(workflowKey, AVADataTypes.ExternalOperationTargetKind.Challenge, challengeId, challengeEvidenceId);
        _assertM56OperationTarget(workflowKey, AVADataTypes.ExternalOperationTargetKind.EvidenceReceipt, evidenceId, evidenceId);
        _assertM56OperationTarget(workflowKey, AVADataTypes.ExternalOperationTargetKind.AllocationRecord, allocationId, evidenceId);
        _assertM56OperationTarget(workflowKey, AVADataTypes.ExternalOperationTargetKind.ConsequenceRecord, consequenceId, evidenceId);
    }

    function testM56ExternalOperationRejectsWrongWorkflowAndTerminalConflict() public {
        bytes32 workflowKey = keccak256("m56-terminal-workflow");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m56-terminal-workflow");
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m56-terminal-evidence"),
            "ipfs://m56-terminal-evidence",
            "external-operation-reference",
            0
        );
        uint256 recognisedStateId = _registerRecognisedStateForWorkflowStatus(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, evidenceId, "m56-terminal-state"
        );

        try externalOperationRegistry.requestOperation(
            AVADataTypes.Role.Panel,
            DEFAULT_WORKFLOW,
            AVADataTypes.ExternalOperationKind.QueueAdjustmentIntent,
            AVADataTypes.ExternalOperationTargetKind.RecognisedState,
            recognisedStateId,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://m56-wrong-workflow"
        ) {
            revert("external operation accepted wrong workflow target");
        } catch {}

        uint256 operationId = externalOperationRegistry.requestOperation(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVADataTypes.ExternalOperationKind.QueueAdjustmentIntent,
            AVADataTypes.ExternalOperationTargetKind.RecognisedState,
            recognisedStateId,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://m56-terminal-request"
        );
        uint256 cancelId = externalOperationRegistry.cancelOperation(
            AVADataTypes.Role.Panel, operationId, keccak256("panel-authority"), "ipfs://m56-terminal-cancel"
        );
        AVADataTypes.ExternalOperationRecord memory cancellation = externalOperationRegistry.getExternalOperation(cancelId);
        require(cancellation.sourceOperationId == operationId, "cancel receipt not linked");
        require(cancellation.status == AVADataTypes.ExternalOperationStatus.Cancelled, "cancel status missing");
        try externalOperationRegistry.supersedeOperation(
            AVADataTypes.Role.Panel, operationId, keccak256("panel-authority"), "ipfs://m56-terminal-supersede"
        ) {
            revert("external operation terminal receipt changed twice");
        } catch {}
    }

    function testM84ExternalOperationReceiptsRecordStableOperationContext() public {
        bytes32 workflowKey = keccak256("m84-operation-context-workflow");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m84-operation-context-workflow");
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m84-operation-context-evidence"),
            "ipfs://m84-operation-context-evidence",
            "external-operation-reference",
            0
        );
        uint256 recognisedStateId = _registerRecognisedStateForWorkflowStatus(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, evidenceId, "m84-operation-context-state"
        );

        uint256 operationId = externalOperationRegistry.requestOperation(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVADataTypes.ExternalOperationKind.QueueAdjustmentIntent,
            AVADataTypes.ExternalOperationTargetKind.RecognisedState,
            recognisedStateId,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://m84-operation-context-request"
        );
        AVADataTypes.ExternalOperationRecord memory operation = externalOperationRegistry.getExternalOperation(operationId);
        bytes32 expectedContextHash = externalOperationRegistry.computeOperationContextHash(
            workflowKey,
            operation.packageId,
            AVADataTypes.ExternalOperationKind.QueueAdjustmentIntent,
            AVADataTypes.ExternalOperationTargetKind.RecognisedState,
            recognisedStateId,
            evidenceId
        );
        require(operation.operationContextHash == expectedContextHash, "operation context hash mismatch");

        uint256 acknowledgementId = externalOperationRegistry.acknowledgeOperation(
            AVADataTypes.Role.Panel, operationId, keccak256("panel-authority"), "ipfs://m84-operation-context-ack"
        );
        AVADataTypes.ExternalOperationRecord memory acknowledgement =
            externalOperationRegistry.getExternalOperation(acknowledgementId);
        require(acknowledgement.sourceOperationId == operationId, "ack source missing");
        require(acknowledgement.operationContextHash == operation.operationContextHash, "ack context changed");
        require(acknowledgement.packageId == operation.packageId, "ack package changed");
        require(acknowledgement.targetId == operation.targetId, "ack target changed");
        require(acknowledgement.evidenceReceiptId == operation.evidenceReceiptId, "ack evidence changed");
    }

    function _assertM56OperationTarget(
        bytes32 workflowKey,
        AVADataTypes.ExternalOperationTargetKind targetKind,
        uint256 targetId,
        uint256 evidenceId
    ) internal {
        uint256 operationId = externalOperationRegistry.requestOperation(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVADataTypes.ExternalOperationKind.QueueAdjustmentIntent,
            targetKind,
            targetId,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://m56-target-operation"
        );
        AVADataTypes.ExternalOperationRecord memory operation = externalOperationRegistry.getExternalOperation(operationId);
        require(operation.workflowKey == workflowKey, "operation workflow mismatch");
        require(operation.sourceOperationId == 0, "request has source operation");
        require(operation.status == AVADataTypes.ExternalOperationStatus.Requested, "operation not requested");
        require(operation.targetKind == targetKind, "operation target kind mismatch");
        require(operation.targetId == targetId, "operation target id mismatch");
        require(operation.evidenceReceiptId == evidenceId, "operation evidence mismatch");
        require(operation.packageId != 0, "operation package missing");
    }

    function testM422StandingCredentialIssuesFromAuthorisedComputationRecord() public {
        uint256 computationId = _createM422StandingComputationRecord("m422-issue", 42);
        uint256 credentialId = _issueM422StandingCredential(computationId, "m422-issued", block.timestamp + 7 days);
        AVADataTypes.StandingCredentialRecord memory credential =
            standingCredentialRegistry.getStandingCredential(credentialId);

        require(credential.subjectId == REVIEWER_SUBJECT, "credential subject mismatch");
        require(credential.packageId == standingRegistry.getStandingComputationRecord(computationId).packageId, "package mismatch");
        require(credential.standingComputationRecordId == computationId, "computation source mismatch");
        require(credential.categoryHash == _m422CategoryHash(), "category mismatch");
        require(credential.threshold == 40 && credential.lowerBound == 40 && credential.upperBound == 50, "range mismatch");
        require(credential.holder == address(reviewerActor), "credential holder mismatch");
        _assertNoSelector(address(standingCredentialRegistry), "ownerOf(uint256)");
        _assertNoSelector(address(standingCredentialRegistry), "balanceOf(address)");
        require(standingCredentialRegistry.isCredentialActive(credentialId), "credential not active");
    }

    function testM422StandingCredentialRejectsUnknownInactiveAndRawSources() public {
        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            keccak256("m422-raw-review-evidence"),
            "ipfs://m422-raw-review-evidence",
            "review-service-occurrence",
            0
        );
        uint256 rawReviewId = reviewerActor.registerReviewContribution(
            stateMachine, AVADataTypes.Role.Reviewer, manuscriptId, REVIEWER_SUBJECT, evidenceId, 0
        );
        _assertM422CannotIssueFromSource(rawReviewId, "raw review issued credential");
        _assertM422CannotIssueFromSource(evidenceId, "raw evidence issued credential");

        uint256 challengedStateId = _createChallengeableReviewState();
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            DEFAULT_WORKFLOW,
            keccak256("m422-raw-challenge-evidence"),
            "ipfs://m422-raw-challenge-evidence",
            "review-quality-challenge",
            0
        );
        uint256 rawChallengeId = challengerActor.fileChallenge(
            stateMachine,
            AVADataTypes.Role.Challenger,
            DEFAULT_WORKFLOW,
            challengedStateId,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            0
        );
        _assertM422CannotIssueFromSource(rawChallengeId, "raw challenge issued credential");

        (uint256 unknownSubjectStateId, uint256 unknownSubjectEvidenceId) =
            _createM421EligibleState(DEFAULT_WORKFLOW, "m422-unknown-subject");
        AVADataTypes.StandingComputationContext memory unknownSubjectContext;
        unknownSubjectContext.recognisedStateId = unknownSubjectStateId;
        unknownSubjectContext.subjectId = keccak256("m422-unknown-standing-subject");
        unknownSubjectContext.dimension = "review-procedure-weight";
        unknownSubjectContext.vectorKey = _m422VectorKey();
        unknownSubjectContext.currentValue = 42;
        unknownSubjectContext.delta = 0;
        unknownSubjectContext.effectiveAt = block.timestamp;
        unknownSubjectContext.epoch = standingRegistry.nextStandingComputationRecordId();
        unknownSubjectContext.sourceRecordSetHash =
            keccak256(abi.encode("m422-unknown-subject", unknownSubjectStateId, unknownSubjectEvidenceId));
        unknownSubjectContext.computationRuleHash = _m422ComputationRuleHash();
        unknownSubjectContext.reversible = true;
        unknownSubjectContext.fieldKey = keccak256("review-service-field");
        unknownSubjectContext.evidenceReceiptId = unknownSubjectEvidenceId;
        unknownSubjectContext.authorityId = keccak256("panel-authority");
        unknownSubjectContext.actor = address(this);
        try standingRegistry.recordStandingComputationReadiness(
            AVADataTypes.Role.Panel, unknownSubjectContext, "ipfs://m422-unknown-subject-standing-computation"
        ) {
            revert("unknown subject produced credential source");
        } catch {}

        uint256 computationId = _createM422StandingComputationRecord("m422-inactive", 42);
        roleRegistry.deactivateSubject(REVIEWER_SUBJECT);
        _assertM422CannotIssueFromSource(computationId, "inactive subject issued credential");
    }

    function testM422ExpiredRevokedAndSupersededCredentialsCannotProve() public {
        uint256 expiringComputationId = _createM422StandingComputationRecord("m422-expiring", 42);
        uint256 expiringCredentialId =
            _issueM422StandingCredential(expiringComputationId, "m422-expiring", block.timestamp + 1);
        require(_m422CredentialProves(expiringCredentialId, 40), "fresh credential should prove");
        vm.warp(block.timestamp + 2);
        require(!standingCredentialRegistry.isCredentialActive(expiringCredentialId), "expired credential active");
        require(!_m422CredentialProves(expiringCredentialId, 40), "expired credential proved");

        uint256 revokedComputationId = _createM422StandingComputationRecord("m422-revoked", 42);
        uint256 revokedCredentialId =
            _issueM422StandingCredential(revokedComputationId, "m422-revoked", block.timestamp + 7 days);
        standingCredentialRegistry.revokeCredential(
            AVADataTypes.Role.Panel,
            revokedCredentialId,
            keccak256("panel-authority"),
            "ipfs://m422-revoke"
        );
        require(!_m422CredentialProves(revokedCredentialId, 40), "revoked credential proved");

        uint256 oldComputationId = _createM422StandingComputationRecord("m422-old", 42);
        uint256 oldCredentialId = _issueM422StandingCredential(oldComputationId, "m422-old", block.timestamp + 7 days);
        uint256 newComputationId = _createM422StandingComputationRecord("m422-new", 45);
        uint256 newCredentialId = standingCredentialRegistry.supersedeCredential(
            AVADataTypes.Role.Panel,
            oldCredentialId,
            _m422CredentialInputForComputation(newComputationId, block.timestamp + 7 days, "ipfs://m422-superseded")
        );
        require(!_m422CredentialProves(oldCredentialId, 40), "superseded credential proved");
        require(_m422CredentialProves(newCredentialId, 40), "replacement credential did not prove");
        require(
            standingCredentialRegistry.getStandingCredential(oldCredentialId).status
                == AVADataTypes.StandingCredentialStatus.Superseded,
            "old credential not superseded"
        );
    }

    function testM422StandingCredentialIsNonTransferableAndDoesNotCreateBenefits() public {
        uint256 computationId = _createM422StandingComputationRecord("m422-non-transferable", 42);
        uint256 nextStandingUpdateId = standingRegistry.nextStandingUpdateId();
        uint256 nextAllocationId = allocationExecutor.nextAllocationExecutionId();
        uint256 nextConsequenceId = consequenceExecutor.nextConsequenceId();
        uint256 credentialId =
            _issueM422StandingCredential(computationId, "m422-non-transferable", block.timestamp + 7 days);

        try standingCredentialRegistry.transferFrom(address(reviewerActor), address(this), credentialId) {
            revert("standing credential transfer accepted");
        } catch {}
        try standingCredentialRegistry.safeTransferFrom(address(reviewerActor), address(this), credentialId) {
            revert("standing credential safe transfer accepted");
        } catch {}
        try standingCredentialRegistry.approve(address(this), credentialId) {
            revert("standing credential approval accepted");
        } catch {}
        try standingCredentialRegistry.setApprovalForAll(address(this), true) {
            revert("standing credential operator approval accepted");
        } catch {}

        require(
            standingCredentialRegistry.getStandingCredential(credentialId).holder == address(reviewerActor),
            "holder changed"
        );
        require(standingCredentialRegistry.getApproved(credentialId) == address(0), "approval exists");
        require(!standingCredentialRegistry.isApprovedForAll(address(reviewerActor), address(this)), "operator approved");
        require(standingRegistry.nextStandingUpdateId() == nextStandingUpdateId, "credential created standing update");
        require(allocationExecutor.nextAllocationExecutionId() == nextAllocationId, "credential created allocation");
        require(consequenceExecutor.nextConsequenceId() == nextConsequenceId, "credential created consequence");

        _assertNoSelector(address(standingCredentialRegistry), "mintReward(uint256)");
        _assertNoSelector(address(standingCredentialRegistry), "transferPayment(uint256)");
        _assertNoSelector(address(standingCredentialRegistry), "mintPriorityToken(uint256)");
        _assertNoSelector(address(standingCredentialRegistry), "grantPublicationPriority(uint256)");
        _assertNoSelector(address(standingCredentialRegistry), "acceptManuscript(uint256)");
        _assertNoSelector(address(standingCredentialRegistry), "rejectManuscript(uint256)");
        _assertNoSelector(address(standingCredentialRegistry), "setManuscriptMerit(uint256,uint256)");
        _assertNoSelector(address(standingCredentialRegistry), "ownerOf(uint256)");
        _assertNoSelector(address(standingCredentialRegistry), "balanceOf(address)");
    }

    function testM422StandingCredentialProvesThresholdAndCategoryWithoutRecomputingHistory() public {
        uint256 computationId = _createM422StandingComputationRecord("m422-proof", 42);
        uint256 nextComputationId = standingRegistry.nextStandingComputationRecordId();
        uint256 credentialId = _issueM422StandingCredential(computationId, "m422-proof", block.timestamp + 7 days);

        require(_m422CredentialProves(credentialId, 40), "credential did not prove threshold");
        require(!_m422CredentialProves(credentialId, 43), "credential proved above standing value");
        require(
            !standingCredentialRegistry.credentialProves(
                credentialId,
                REVIEWER_SUBJECT,
                _m422VectorKey(),
                keccak256("wrong-category"),
                40
            ),
            "credential proved wrong category"
        );
        require(standingRegistry.nextStandingComputationRecordId() == nextComputationId, "proof recomputed standing");
    }

    function testM422StandingCredentialProvesPackageBoundSubjectStandingWithoutOwnerDisclosure() public {
        uint256 computationId = _createM422StandingComputationRecord("m422-hidden-subject-proof", 42);
        uint256 credentialId =
            _issueM422StandingCredential(computationId, "m422-hidden-subject-proof", block.timestamp + 7 days);
        AVADataTypes.StandingComputationRecord memory computation =
            standingRegistry.getStandingComputationRecord(computationId);

        require(
            standingCredentialRegistry.credentialProvesSubjectStanding(
                credentialId,
                computation.packageId,
                REVIEWER_SUBJECT,
                _m422VectorKey(),
                _m422CategoryHash(),
                40
            ),
            "package-bound subject standing proof failed"
        );
        require(
            !standingCredentialRegistry.credentialProvesSubjectStanding(
                credentialId,
                computation.packageId + 1,
                REVIEWER_SUBJECT,
                _m422VectorKey(),
                _m422CategoryHash(),
                40
            ),
            "credential proved wrong package"
        );
        require(
            !standingCredentialRegistry.credentialProvesSubjectStanding(
                credentialId,
                computation.packageId,
                CHALLENGER_SUBJECT,
                _m422VectorKey(),
                _m422CategoryHash(),
                40
            ),
            "credential proved wrong subject"
        );
        require(
            standingCredentialRegistry.getStandingCredential(credentialId).holder == address(reviewerActor),
            "holder reference changed"
        );
    }

    function testM63CredentialProofRequiresMatchingPackageSubjectVectorAndCategory() public {
        uint256 computationId = _createM422StandingComputationRecord("m63-proof-surface", 42);
        uint256 credentialId =
            _issueM422StandingCredential(computationId, "m63-proof-surface", block.timestamp + 7 days);
        AVADataTypes.StandingComputationRecord memory computation =
            standingRegistry.getStandingComputationRecord(computationId);

        require(
            standingCredentialRegistry.credentialProvesSubjectStanding(
                credentialId,
                computation.packageId,
                REVIEWER_SUBJECT,
                _m422VectorKey(),
                _m422CategoryHash(),
                40
            ),
            "valid package-bound proof failed"
        );
        require(
            !standingCredentialRegistry.credentialProvesSubjectStanding(
                credentialId,
                computation.packageId + 1,
                REVIEWER_SUBJECT,
                _m422VectorKey(),
                _m422CategoryHash(),
                40
            ),
            "credential proved wrong package"
        );
        require(
            !standingCredentialRegistry.credentialProvesSubjectStanding(
                credentialId,
                computation.packageId,
                CHALLENGER_SUBJECT,
                _m422VectorKey(),
                _m422CategoryHash(),
                40
            ),
            "credential proved wrong subject"
        );
        require(
            !standingCredentialRegistry.credentialProvesSubjectStanding(
                credentialId,
                computation.packageId,
                REVIEWER_SUBJECT,
                keccak256("m63-wrong-vector"),
                _m422CategoryHash(),
                40
            ),
            "credential proved wrong vector"
        );
        require(
            !standingCredentialRegistry.credentialProvesSubjectStanding(
                credentialId,
                computation.packageId,
                REVIEWER_SUBJECT,
                _m422VectorKey(),
                keccak256("m63-wrong-category"),
                40
            ),
            "credential proved wrong category"
        );
        require(
            !standingCredentialRegistry.credentialProvesSubjectStanding(
                credentialId,
                computation.packageId,
                REVIEWER_SUBJECT,
                _m422VectorKey(),
                _m422CategoryHash(),
                43
            ),
            "credential proved above standing value"
        );
        require(
            !standingCredentialRegistry.credentialProvesSubjectStanding(
                credentialId,
                computation.packageId,
                REVIEWER_SUBJECT,
                _m422VectorKey(),
                _m422CategoryHash(),
                39
            ),
            "credential proved outside lower range"
        );
    }

    function testM63StandingCredentialSupersedeRequiresSamePackageCategoryAndNewerEpoch() public {
        uint256 packageOldComputationId = _createM422StandingComputationRecord("m63-package-old", 42);
        uint256 packageOldCredentialId =
            _issueM422StandingCredential(packageOldComputationId, "m63-package-old", block.timestamp + 7 days);
        bytes32 foreignWorkflowKey = keccak256("m63-foreign-standing-credential-workflow");
        _registerM421ExecutionWorkflow(foreignWorkflowKey, "ipfs://m63-foreign-standing-credential-workflow");
        uint256 foreignComputationId = _createM423StandingComputationRecord(foreignWorkflowKey, "m63-package-new", 45);
        _assertM63CannotSupersedeStandingCredential(
            packageOldCredentialId,
            _m422CredentialInputForComputation(
                foreignComputationId, block.timestamp + 7 days, "ipfs://m63-cross-package-replacement"
            ),
            "cross-package credential supersession accepted"
        );

        uint256 categoryOldComputationId = _createM422StandingComputationRecord("m63-category-old", 42);
        uint256 categoryOldCredentialId =
            _issueM422StandingCredential(categoryOldComputationId, "m63-category-old", block.timestamp + 7 days);
        uint256 categoryNewComputationId = _createM422StandingComputationRecord("m63-category-new", 45);
        IStandingCredentialIssuer.StandingCredentialInput memory categoryReplacement =
            _m422CredentialInputForComputation(
                categoryNewComputationId, block.timestamp + 7 days, "ipfs://m63-wrong-category-replacement"
            );
        categoryReplacement.categoryHash = keccak256("m63-wrong-category");
        _assertM63CannotSupersedeStandingCredential(
            categoryOldCredentialId, categoryReplacement, "cross-category credential supersession accepted"
        );

        uint256 epochOldComputationId = _createM422StandingComputationRecord("m63-epoch-old", 42);
        uint256 epochOldCredentialId =
            _issueM422StandingCredential(epochOldComputationId, "m63-epoch-old", block.timestamp + 7 days);
        _assertM63CannotSupersedeStandingCredential(
            epochOldCredentialId,
            _m422CredentialInputForComputation(
                epochOldComputationId, block.timestamp + 7 days, "ipfs://m63-same-epoch-replacement"
            ),
            "non-increasing epoch credential supersession accepted"
        );

        uint256 validOldComputationId = _createM422StandingComputationRecord("m63-valid-old", 42);
        uint256 validOldCredentialId =
            _issueM422StandingCredential(validOldComputationId, "m63-valid-old", block.timestamp + 7 days);
        uint256 validNewComputationId = _createM422StandingComputationRecord("m63-valid-new", 45);
        uint256 validNewCredentialId = standingCredentialRegistry.supersedeCredential(
            AVADataTypes.Role.Panel,
            validOldCredentialId,
            _m422CredentialInputForComputation(
                validNewComputationId, block.timestamp + 7 days, "ipfs://m63-valid-replacement"
            )
        );
        require(validNewCredentialId != 0, "valid replacement missing");
        require(!standingCredentialRegistry.isCredentialActive(validOldCredentialId), "valid supersession left old active");
    }

    function testM63UnrelatedSettlementCannotSuspendCredentialUseSurface() public {
        bytes32 workflowKey = keccak256("m63-settlement-use-surface");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m63-settlement-use-surface");
        uint256 computationId = _createM423StandingComputationRecord(workflowKey, "m63-settlement-credential", 42);
        uint256 credentialId = standingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m422CredentialInputForComputation(computationId, block.timestamp + 7 days, "ipfs://m63-settlement-credential")
        );

        MockERC20 token = _m421FundedToken(100);
        uint256 sourceId =
            _createM421RewardSource(workflowKey, "m63-bound-source", token, 6, AVADataTypes.ValueExecutionMode.Claim);
        uint256 settlementId = valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m63-bound-settlement"
        );
        uint256 otherSourceId =
            _createM421RewardSource(workflowKey, "m63-other-source", token, 4, AVADataTypes.ValueExecutionMode.Claim);
        uint256 otherSettlementId = valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            otherSourceId,
            keccak256("executor-authority"),
            "ipfs://m63-other-settlement"
        );
        _assertM424InvalidSettlementDoesNotSuspend(
            credentialId,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            otherSettlementId,
            "wrong settlement source suspended credential"
        );

        (uint256 authorSourceId, uint256 authorSettlementId) =
            _createM425AuthorRewardSettlement(workflowKey, "m63-author-source", token, 2);
        _assertM424InvalidSettlementDoesNotSuspend(
            credentialId,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            authorSourceId,
            authorSettlementId,
            "wrong settlement subject suspended credential"
        );

        standingCredentialRegistry.recordStandingRelevantSettlement(
            AVADataTypes.Role.Panel,
            credentialId,
            AVADataTypes.StandingRelevantSettlementKind.RewardExecution,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            settlementId,
            keccak256("panel-authority"),
            "ipfs://m63-valid-impact"
        );
        require(!standingCredentialRegistry.isCredentialActive(credentialId), "valid settlement did not suspend");
        require(!_m422CredentialProves(credentialId, 40), "valid settlement left proof active");
    }

    function testM65ZKStandingProofRegistersPackageBoundStandingReceipt() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(DEFAULT_WORKFLOW, subjectCommitment, "m65-valid-proof");
        uint256 statementId;
        (input,,, statementId) = _bindM93StandingProofInput(input, "m65-valid-proof");
        bytes32 contextHash = zkStandingComputationRegistry.computeStandingComputationContextHash(input);
        uint256 receiptId = zkStandingComputationRegistry.registerStandingProof(
            input,
            _makeSchnorrProof(contextHash, 7, 11)
        );
        ZKStandingComputationRegistry.StandingProofReceipt memory receipt =
            zkStandingComputationRegistry.getStandingProofReceipt(receiptId);
        uint256 packageId = rulePackageRegistry.getRulePackage(DEFAULT_WORKFLOW).packageId;

        require(receipt.packageId == packageId, "standing proof package missing");
        require(receipt.standingComputationStatementId == statementId, "standing proof statement missing");
        require(receipt.contextHash == contextHash, "standing proof context missing");
        require(receipt.subjectCommitment == subjectCommitment, "standing proof subject missing");
        require(receipt.vectorKey == input.vectorKey, "standing proof vector missing");
        require(receipt.categoryHash == input.categoryHash, "standing proof category missing");
        require(receipt.sourceRecordSetRoot == input.sourceRecordSetRoot, "standing proof source root missing");
        require(receipt.computationRuleHash == input.computationRuleHash, "standing proof rule missing");
        require(
            receipt.nullifierHash == zkStandingComputationRegistry.computeNullifierHash(contextHash, subjectCommitment),
            "standing proof nullifier missing"
        );
        require(
            zkStandingComputationRegistry.standingProofSupportsCredential(
                receiptId,
                packageId,
                subjectCommitment,
                input.vectorKey,
                input.categoryHash,
                40
            ),
            "standing proof did not support valid credential surface"
        );
        require(
            !zkStandingComputationRegistry.standingProofSupportsCredential(
                receiptId,
                packageId + 1,
                subjectCommitment,
                input.vectorKey,
                input.categoryHash,
                40
            ),
            "standing proof supported wrong package"
        );
        require(
            !zkStandingComputationRegistry.standingProofSupportsCredential(
                receiptId,
                packageId,
                _subjectCommitmentForSecret(9),
                input.vectorKey,
                input.categoryHash,
                40
            ),
            "standing proof supported wrong subject"
        );
        require(
            !zkStandingComputationRegistry.standingProofSupportsCredential(
                receiptId,
                packageId,
                subjectCommitment,
                keccak256("m65-wrong-vector"),
                input.categoryHash,
                40
            ),
            "standing proof supported wrong vector"
        );
        require(
            !zkStandingComputationRegistry.standingProofSupportsCredential(
                receiptId,
                packageId,
                subjectCommitment,
                input.vectorKey,
                keccak256("m65-wrong-category"),
                40
            ),
            "standing proof supported wrong category"
        );
        require(
            !zkStandingComputationRegistry.standingProofSupportsCredential(
                receiptId,
                packageId,
                subjectCommitment,
                input.vectorKey,
                input.categoryHash,
                43
            ),
            "standing proof supported above standing value"
        );
        require(
            !zkStandingComputationRegistry.standingProofSupportsCredential(
                receiptId,
                packageId,
                subjectCommitment,
                input.vectorKey,
                input.categoryHash,
                39
            ),
            "standing proof supported outside lower range"
        );
        _assertNoSelector(address(zkStandingComputationRegistry), "revealIdentity(uint256)");
        _assertNoSelector(address(zkStandingComputationRegistry), "revealEvidence(uint256)");
        _assertNoSelector(address(zkStandingComputationRegistry), "decryptEvidence(uint256)");
        _assertNoSelector(address(zkStandingComputationRegistry), "acceptManuscript(uint256)");
        _assertNoSelector(address(zkStandingComputationRegistry), "setManuscriptMerit(uint256,uint256)");
        _assertNoSelector(address(zkStandingComputationRegistry), "mintReward(uint256)");
        _assertNoSelector(address(zkStandingComputationRegistry), "mintPriorityToken(uint256)");
        _assertNoSelector(address(zkStandingComputationRegistry), "transferStanding(uint256)");
    }

    function testM65ZKStandingProofRejectsReplayAndBadSubjectBinding() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(DEFAULT_WORKFLOW, subjectCommitment, "m65-replay");
        (input,,,) = _bindM93StandingProofInput(input, "m65-replay");
        bytes32 contextHash = zkStandingComputationRegistry.computeStandingComputationContextHash(input);
        IZKProofVerifier.SchnorrProof memory proof = _makeSchnorrProof(contextHash, 7, 11);

        zkStandingComputationRegistry.registerStandingProof(input, proof);
        uint256 nextReceiptId = zkStandingComputationRegistry.nextStandingProofReceiptId();
        _assertM65CannotRegisterStandingProof(input, proof, "standing proof replay accepted");
        require(zkStandingComputationRegistry.nextStandingProofReceiptId() == nextReceiptId, "replay wrote proof receipt");

        ZKStandingComputationRegistry.StandingProofInput memory wrongSubjectInput =
            _m65StandingProofInput(DEFAULT_WORKFLOW, _subjectCommitmentForSecret(9), "m65-wrong-subject");
        bytes32 wrongSubjectContext =
            zkStandingComputationRegistry.computeStandingComputationContextHash(wrongSubjectInput);
        _assertM65CannotRegisterStandingProof(
            wrongSubjectInput,
            _makeSchnorrProof(wrongSubjectContext, 7, 13),
            "standing proof accepted mismatched subject commitment"
        );
    }

    function testM65ZKStandingProofCannotCrossPackageAfterWorkflowReregistration() public {
        bytes32 workflowKey = keccak256("m65-reregistered-workflow");
        _ensureWorkflowPackage(workflowKey);
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(workflowKey, subjectCommitment, "m65-package-binding");
        uint256 oldStatementId;
        (input,,, oldStatementId) = _bindM93StandingProofInput(input, "m65-package-binding-old");
        bytes32 oldContextHash = zkStandingComputationRegistry.computeStandingComputationContextHash(input);
        uint256 oldPackageId = rulePackageRegistry.getRulePackage(workflowKey).packageId;

        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m65-reregistered-workflow");
        uint256 newPackageId = rulePackageRegistry.getRulePackage(workflowKey).packageId;
        require(newPackageId != oldPackageId, "workflow package did not change");
        require(
            zkStandingComputationRegistry.computeStandingComputationContextHash(input) == oldContextHash,
            "active workflow rewrote old statement context"
        );
        ZKStandingComputationRegistry.StandingProofInput memory newPackageInput =
            _m65StandingProofInput(workflowKey, subjectCommitment, "m65-package-binding");
        uint256 newStatementId;
        (newPackageInput,,, newStatementId) = _bindM93StandingProofInput(newPackageInput, "m65-package-binding-new");
        bytes32 newContextHash = zkStandingComputationRegistry.computeStandingComputationContextHash(newPackageInput);
        require(newContextHash != oldContextHash, "standing proof context omitted statement package");
        ZKStandingComputationRegistry.StandingProofInput memory mixedPackageInput = newPackageInput;
        mixedPackageInput.standingComputationStatementId = oldStatementId;
        _assertM65CannotRegisterStandingProof(
            mixedPackageInput,
            _makeSchnorrProof(zkStandingComputationRegistry.computeStandingComputationContextHash(mixedPackageInput), 7, 13),
            "new package proof accepted old computation statement"
        );
        newPackageInput.standingComputationStatementId = newStatementId;
        uint256 receiptId = zkStandingComputationRegistry.registerStandingProof(
            newPackageInput,
            _makeSchnorrProof(newContextHash, 7, 13)
        );
        require(
            zkStandingComputationRegistry.getStandingProofReceipt(receiptId).packageId == newPackageId,
            "standing proof used stale package"
        );
        require(
            zkStandingComputationRegistry.getStandingProofReceipt(receiptId).standingComputationStatementId
                == newStatementId,
            "standing proof used stale statement"
        );
    }

    function testM65ZKStandingProofRejectsEmptyOrOutOfRangeContext() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(DEFAULT_WORKFLOW, subjectCommitment, "m65-invalid-context");
        (input,,,) = _bindM93StandingProofInput(input, "m65-invalid-context");
        bytes32 contextHash = zkStandingComputationRegistry.computeStandingComputationContextHash(input);

        ZKStandingComputationRegistry.StandingProofInput memory zeroWorkflow = input;
        zeroWorkflow.workflowKey = bytes32(0);
        _assertM65CannotRegisterStandingProof(
            zeroWorkflow,
            _makeSchnorrProof(contextHash, 7, 11),
            "zero workflow standing proof accepted"
        );
        ZKStandingComputationRegistry.StandingProofInput memory unknownWorkflow = input;
        unknownWorkflow.workflowKey = keccak256("m65-unknown-workflow");
        _assertM65CannotRegisterStandingProof(
            unknownWorkflow,
            _makeSchnorrProof(contextHash, 7, 11),
            "unknown workflow standing proof accepted"
        );

        ZKStandingComputationRegistry.StandingProofInput memory zeroSourceRoot = input;
        zeroSourceRoot.sourceRecordSetRoot = bytes32(0);
        _assertM65CannotRegisterStandingProof(
            zeroSourceRoot,
            _makeSchnorrProof(contextHash, 7, 11),
            "zero source root standing proof accepted"
        );

        ZKStandingComputationRegistry.StandingProofInput memory badRange = input;
        badRange.threshold = 60;
        _assertM65CannotRegisterStandingProof(
            badRange,
            _makeSchnorrProof(contextHash, 7, 11),
            "out-of-range standing proof accepted"
        );
    }

    function testM68ZKStandingProofRequiresRegisteredFormulaAndSourceSetCommitment() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(DEFAULT_WORKFLOW, subjectCommitment, "m68-required-source-set");
        bytes32 contextHash = zkStandingComputationRegistry.computeStandingComputationContextHash(input);
        IZKProofVerifier.SchnorrProof memory proof = _makeSchnorrProof(contextHash, 7, 11);

        _assertM65CannotRegisterStandingProof(input, proof, "unregistered formula/source set accepted");

        uint256 formulaId = _registerM68Formula(input, "m68-required-source-set");
        _assertM65CannotRegisterStandingProof(input, proof, "formula without source set accepted");

        uint256 evidenceId = _registerM68SourceSetEvidence(input.workflowKey, "m68-required-source-set");
        uint256 sourceSetCommitmentId =
            _registerM68SourceSetCommitment(formulaId, input, evidenceId, "m68-required-source-set");
        IStandingFormulaRegistry.SourceSetCommitmentRecord memory commitment =
            standingFormulaRegistry.getSourceSetCommitment(sourceSetCommitmentId);
        require(commitment.sourceRecordSetRoot == input.sourceRecordSetRoot, "source root not recorded");
        require(commitment.computationRuleHash == input.computationRuleHash, "rule hash not recorded");
        require(
            standingFormulaRegistry.proofInputMatchesRegisteredCommitment(
                input.workflowKey,
                input.subjectCommitment,
                input.vectorKey,
                input.categoryHash,
                input.epoch,
                input.sourceRecordSetRoot,
                input.computationRuleHash,
                address(zkStandingComputationRegistry.verifier())
            ),
            "registered proof input not matched"
        );

        _assertM65CannotRegisterStandingProof(input, proof, "source set without computation statement accepted");
        input.outputCommitmentHash = keccak256(abi.encode("m68-required-source-set", subjectCommitment, "standing-output"));
        uint256 attestationId =
            _registerM92SourceSetCompletenessAttestation(sourceSetCommitmentId, evidenceId, "m68-required-source-set");
        IStandingFormulaRegistry.StandingComputationStatementInput memory statementInput =
            _m91ComputationStatementInput(
                sourceSetCommitmentId, attestationId, input, evidenceId, "m68-required-source-set"
            );
        input.standingComputationStatementId =
            standingFormulaRegistry.registerStandingComputationStatement(AVADataTypes.Role.Panel, statementInput);
        contextHash = zkStandingComputationRegistry.computeStandingComputationContextHash(input);
        uint256 receiptId = zkStandingComputationRegistry.registerStandingProof(
            input,
            _makeSchnorrProof(contextHash, 7, 11)
        );
        require(receiptId != 0, "registered source set proof rejected");
    }

    function testM68SourceSetCommitmentLookupCanUseHistoricalPackageAfterWorkflowReregistration() public {
        bytes32 workflowKey = keccak256("m68-source-set-historical-package");
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m6-8-compatible"),
            false,
            "ipfs://m68-source-set-historical-v1"
        );
        AVARulePackageRegistry.RulePackage memory oldPackage = rulePackageRegistry.getRulePackage(workflowKey);
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(workflowKey, subjectCommitment, "m68-source-set-historical");
        uint256 formulaId = _registerM68Formula(input, "m68-source-set-historical");
        uint256 evidenceId = _registerM68SourceSetEvidence(input.workflowKey, "m68-source-set-historical");
        uint256 sourceSetCommitmentId =
            _registerM68SourceSetCommitment(formulaId, input, evidenceId, "m68-source-set-historical");

        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            2,
            keccak256("ava-m6-8-compatible"),
            false,
            "ipfs://m68-source-set-historical-v2"
        );
        require(
            rulePackageRegistry.getRulePackage(workflowKey).packageId != oldPackage.packageId,
            "workflow package did not rotate"
        );
        require(
            standingFormulaRegistry.getSourceSetCommitmentIdForProofInput(
                workflowKey,
                input.subjectCommitment,
                input.vectorKey,
                input.categoryHash,
                input.epoch,
                input.sourceRecordSetRoot,
                input.computationRuleHash,
                address(zkStandingComputationRegistry.verifier())
            ) == 0,
            "active lookup unexpectedly returned old package commitment"
        );
        require(
            standingFormulaRegistry.getSourceSetCommitmentIdForPackageProofInput(
                oldPackage.packageId,
                workflowKey,
                input.subjectCommitment,
                input.vectorKey,
                input.categoryHash,
                input.epoch,
                input.sourceRecordSetRoot,
                input.computationRuleHash,
                address(zkStandingComputationRegistry.verifier())
            ) == sourceSetCommitmentId,
            "package-bound source-set proof lookup missed historical commitment"
        );
    }

    function testM82StandingProofReceiptBindsExactFormulaAndSourceSetCommitment() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(DEFAULT_WORKFLOW, subjectCommitment, "m82-proof-chain");
        uint256 formulaId;
        uint256 sourceSetCommitmentId;
        uint256 statementId;
        (input, formulaId, sourceSetCommitmentId, statementId) =
            _bindM93StandingProofInput(input, "m82-proof-chain");
        IStandingFormulaRegistry.StandingFormulaRecord memory formula = standingFormulaRegistry.getStandingFormula(formulaId);
        IStandingFormulaRegistry.SourceSetCommitmentRecord memory commitment =
            standingFormulaRegistry.getSourceSetCommitment(sourceSetCommitmentId);
        require(
            standingFormulaRegistry.getSourceSetCommitmentIdForProofInput(
                input.workflowKey,
                input.subjectCommitment,
                input.vectorKey,
                input.categoryHash,
                input.epoch,
                input.sourceRecordSetRoot,
                input.computationRuleHash,
                address(zkStandingComputationRegistry.verifier())
            ) == sourceSetCommitmentId,
            "source-set proof lookup not exact"
        );

        bytes32 contextHash = zkStandingComputationRegistry.computeStandingComputationContextHash(input);
        uint256 receiptId = zkStandingComputationRegistry.registerStandingProof(
            input,
            _makeSchnorrProof(contextHash, 7, 11)
        );
        ZKStandingComputationRegistry.StandingProofReceipt memory receipt =
            zkStandingComputationRegistry.getStandingProofReceipt(receiptId);

        require(receipt.formulaId == formulaId, "standing proof formula id missing");
        require(receipt.sourceSetCommitmentId == sourceSetCommitmentId, "standing proof source-set id missing");
        require(receipt.standingComputationStatementId == statementId, "standing proof statement id missing");
        require(receipt.formulaVersion == formula.formulaVersion, "standing proof formula version missing");
        require(receipt.sourceSetPolicyHash == formula.sourceSetPolicyHash, "standing proof source policy missing");
        require(receipt.sourceSetPolicyHash == commitment.sourceSetPolicyHash, "standing proof source policy mismatch");
        require(receipt.outputCommitmentHash == input.outputCommitmentHash, "standing proof output commitment missing");
    }

    function testM91StandingComputationStatementRegistersAuthorisedComputationOutput() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(DEFAULT_WORKFLOW, subjectCommitment, "m91-statement");
        (uint256 formulaId, uint256 sourceSetCommitmentId) =
            _registerM68FormulaAndSourceSet(input, "m91-statement");
        uint256 evidenceId = _registerM68SourceSetEvidence(input.workflowKey, "m91-statement-evidence");
        uint256 attestationId =
            _registerM92SourceSetCompletenessAttestation(sourceSetCommitmentId, evidenceId, "m91-statement");
        IStandingFormulaRegistry.StandingComputationStatementInput memory statementInput =
            _m91ComputationStatementInput(sourceSetCommitmentId, attestationId, input, evidenceId, "m91-statement");

        uint256 statementId =
            standingFormulaRegistry.registerStandingComputationStatement(AVADataTypes.Role.Panel, statementInput);
        IStandingFormulaRegistry.StandingComputationStatementRecord memory statement =
            standingFormulaRegistry.getStandingComputationStatement(statementId);
        IStandingFormulaRegistry.StandingFormulaRecord memory formula = standingFormulaRegistry.getStandingFormula(formulaId);

        require(statement.sourceSetCommitmentId == sourceSetCommitmentId, "statement source-set missing");
        require(statement.sourceSetCompletenessAttestationId == attestationId, "statement attestation missing");
        require(statement.formulaId == formulaId, "statement formula missing");
        require(statement.workflowKey == input.workflowKey, "statement workflow missing");
        require(statement.packageId == formula.packageId, "statement package missing");
        require(statement.subjectCommitment == input.subjectCommitment, "statement subject missing");
        require(statement.vectorKey == input.vectorKey, "statement vector missing");
        require(statement.categoryHash == input.categoryHash, "statement category missing");
        require(statement.outputCommitmentHash == statementInput.outputCommitmentHash, "statement output missing");
        require(statement.proofDomainHash == statementInput.proofDomainHash, "statement proof domain missing");
        require(statement.status == AVADataTypes.StandingComputationStatus.Active, "statement not active");
        require(standingFormulaRegistry.isStandingComputationStatementActive(statementId), "statement active helper false");
    }

    function testM91StandingComputationStatementRejectsMismatchedFieldsAndUnauthorisedCaller() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(DEFAULT_WORKFLOW, subjectCommitment, "m91-reject");
        (, uint256 sourceSetCommitmentId) = _registerM68FormulaAndSourceSet(input, "m91-reject");
        uint256 evidenceId = _registerM68SourceSetEvidence(input.workflowKey, "m91-reject-evidence");
        uint256 attestationId =
            _registerM92SourceSetCompletenessAttestation(sourceSetCommitmentId, evidenceId, "m91-reject");
        IStandingFormulaRegistry.StandingComputationStatementInput memory statementInput =
            _m91ComputationStatementInput(sourceSetCommitmentId, attestationId, input, evidenceId, "m91-reject");

        try outsiderActor.registerStandingComputationStatement(
            standingFormulaRegistry, AVADataTypes.Role.Panel, statementInput
        ) {
            revert("unauthorised computation statement registered");
        } catch {}

        IStandingFormulaRegistry.StandingComputationStatementInput memory wrongSubject = statementInput;
        wrongSubject.subjectCommitment = _subjectCommitmentForSecret(9);
        _assertM91CannotRegisterComputationStatement(wrongSubject, "wrong subject computation statement registered");

        IStandingFormulaRegistry.StandingComputationStatementInput memory zeroOutput = statementInput;
        zeroOutput.outputCommitmentHash = bytes32(0);
        _assertM91CannotRegisterComputationStatement(zeroOutput, "zero output computation statement registered");

        bytes32 workflowKey = keccak256("m91-wrong-package-workflow");
        _ensureWorkflowPackage(workflowKey);
        ZKStandingComputationRegistry.StandingProofInput memory oldInput =
            _m65StandingProofInput(workflowKey, subjectCommitment, "m91-old-package-statement");
        (, uint256 oldSourceSetCommitmentId) = _registerM68FormulaAndSourceSet(oldInput, "m91-old-package-statement");
        uint256 oldAttestationEvidenceId =
            _registerM68SourceSetEvidence(workflowKey, "m91-old-package-attestation-evidence");
        uint256 oldAttestationId = _registerM92SourceSetCompletenessAttestation(
            oldSourceSetCommitmentId, oldAttestationEvidenceId, "m91-old-package-statement"
        );
        uint256 oldPackageId = rulePackageRegistry.getRulePackage(workflowKey).packageId;
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m91-new-package-statement");
        uint256 newEvidenceId = _registerM68SourceSetEvidence(workflowKey, "m91-new-package-statement-evidence");
        require(evidenceRegistry.getEvidenceReceipt(newEvidenceId).packageId != oldPackageId, "package did not change");
        IStandingFormulaRegistry.StandingComputationStatementInput memory wrongEvidence =
            _m91ComputationStatementInput(
                oldSourceSetCommitmentId, oldAttestationId, oldInput, newEvidenceId, "m91-wrong-evidence"
            );
        _assertM91CannotRegisterComputationStatement(wrongEvidence, "new package evidence registered old statement");
    }

    function testM91ComputationStatementDoesNotCreateProofCredentialOrBenefits() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(DEFAULT_WORKFLOW, subjectCommitment, "m91-record-only");
        (, uint256 sourceSetCommitmentId) = _registerM68FormulaAndSourceSet(input, "m91-record-only");
        uint256 evidenceId = _registerM68SourceSetEvidence(input.workflowKey, "m91-record-only-evidence");
        uint256 attestationId =
            _registerM92SourceSetCompletenessAttestation(sourceSetCommitmentId, evidenceId, "m91-record-only");
        IStandingFormulaRegistry.StandingComputationStatementInput memory statementInput =
            _m91ComputationStatementInput(sourceSetCommitmentId, attestationId, input, evidenceId, "m91-record-only");
        uint256 nextProofReceiptId = zkStandingComputationRegistry.nextStandingProofReceiptId();
        uint256 nextCredentialId = zkStandingCredentialRegistry.nextCredentialId();

        standingFormulaRegistry.registerStandingComputationStatement(AVADataTypes.Role.Panel, statementInput);

        require(zkStandingComputationRegistry.nextStandingProofReceiptId() == nextProofReceiptId, "statement wrote proof");
        require(zkStandingCredentialRegistry.nextCredentialId() == nextCredentialId, "statement issued credential");
        _assertNoSelector(address(standingFormulaRegistry), "mintReward(uint256)");
        _assertNoSelector(address(standingFormulaRegistry), "mintPriorityToken(uint256)");
        _assertNoSelector(address(standingFormulaRegistry), "acceptManuscript(uint256)");
        _assertNoSelector(address(standingFormulaRegistry), "setManuscriptMerit(uint256,uint256)");
        _assertNoSelector(address(standingFormulaRegistry), "revealIdentity(uint256)");
        _assertNoSelector(address(standingFormulaRegistry), "revealEvidence(uint256)");
        _assertNoSelector(address(standingFormulaRegistry), "decryptEvidence(uint256)");
    }

    function testM92SourceSetCompletenessAttestationRecordsPolicyAndEvidence() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(DEFAULT_WORKFLOW, subjectCommitment, "m92-attestation");
        (uint256 formulaId, uint256 sourceSetCommitmentId) =
            _registerM68FormulaAndSourceSet(input, "m92-attestation");
        uint256 evidenceId = _registerM68SourceSetEvidence(input.workflowKey, "m92-attestation-evidence");
        IStandingFormulaRegistry.SourceSetCompletenessAttestationInput memory attestationInput =
            _m92SourceSetCompletenessAttestationInput(sourceSetCommitmentId, evidenceId, "m92-attestation");

        uint256 attestationId = standingFormulaRegistry.registerSourceSetCompletenessAttestation(
            AVADataTypes.Role.Panel, attestationInput
        );
        IStandingFormulaRegistry.SourceSetCompletenessAttestationRecord memory attestation =
            standingFormulaRegistry.getSourceSetCompletenessAttestation(attestationId);
        IStandingFormulaRegistry.StandingFormulaRecord memory formula = standingFormulaRegistry.getStandingFormula(formulaId);

        require(attestation.sourceSetCommitmentId == sourceSetCommitmentId, "attestation source-set missing");
        require(attestation.formulaId == formulaId, "attestation formula missing");
        require(attestation.workflowKey == input.workflowKey, "attestation workflow missing");
        require(attestation.packageId == formula.packageId, "attestation package missing");
        require(attestation.subjectCommitment == input.subjectCommitment, "attestation subject missing");
        require(attestation.vectorKey == input.vectorKey, "attestation vector missing");
        require(attestation.categoryHash == input.categoryHash, "attestation category missing");
        require(attestation.sourceRecordSetRoot == input.sourceRecordSetRoot, "attestation source root missing");
        require(attestation.computationRuleHash == input.computationRuleHash, "attestation rule missing");
        require(attestation.includedRecordClassesHash != bytes32(0), "attestation classes missing");
        require(attestation.exclusionPolicyHash != bytes32(0), "attestation exclusion missing");
        require(attestation.evidenceReceiptId == evidenceId, "attestation evidence missing");
        require(attestation.completenessAttestationHash == attestationInput.completenessAttestationHash, "attestation hash missing");
        require(standingFormulaRegistry.isSourceSetCompletenessAttestationActive(attestationId), "attestation not active");
    }

    function testM92SourceSetCompletenessAttestationRejectsUnknownWrongPackageAndZeroFields() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(DEFAULT_WORKFLOW, subjectCommitment, "m92-reject");
        (, uint256 sourceSetCommitmentId) = _registerM68FormulaAndSourceSet(input, "m92-reject");
        uint256 evidenceId = _registerM68SourceSetEvidence(input.workflowKey, "m92-reject-evidence");
        IStandingFormulaRegistry.SourceSetCompletenessAttestationInput memory attestationInput =
            _m92SourceSetCompletenessAttestationInput(sourceSetCommitmentId, evidenceId, "m92-reject");

        IStandingFormulaRegistry.SourceSetCompletenessAttestationInput memory unknownSourceSet = attestationInput;
        unknownSourceSet.sourceSetCommitmentId = 999_999;
        _assertM92CannotRegisterSourceSetCompletenessAttestation(unknownSourceSet, "unknown source-set attestation registered");

        IStandingFormulaRegistry.SourceSetCompletenessAttestationInput memory zeroClasses = attestationInput;
        zeroClasses.includedRecordClassesHash = bytes32(0);
        _assertM92CannotRegisterSourceSetCompletenessAttestation(zeroClasses, "zero included classes registered");

        IStandingFormulaRegistry.SourceSetCompletenessAttestationInput memory zeroExclusion = attestationInput;
        zeroExclusion.exclusionPolicyHash = bytes32(0);
        _assertM92CannotRegisterSourceSetCompletenessAttestation(zeroExclusion, "zero exclusion policy registered");

        IStandingFormulaRegistry.SourceSetCompletenessAttestationInput memory zeroEvidence = attestationInput;
        zeroEvidence.evidenceReceiptId = 0;
        _assertM92CannotRegisterSourceSetCompletenessAttestation(zeroEvidence, "zero attestation evidence registered");

        IStandingFormulaRegistry.SourceSetCompletenessAttestationInput memory wrongHash = attestationInput;
        wrongHash.completenessAttestationHash = keccak256("m92-wrong-completeness");
        _assertM92CannotRegisterSourceSetCompletenessAttestation(wrongHash, "wrong completeness hash registered");

        IStandingFormulaRegistry.SourceSetCompletenessAttestationInput memory wrongAuthority = attestationInput;
        wrongAuthority.authorityId = keccak256("wrong-panel-authority");
        _assertM92CannotRegisterSourceSetCompletenessAttestation(wrongAuthority, "wrong authority registered");

        bytes32 workflowKey = keccak256("m92-wrong-package-workflow");
        _ensureWorkflowPackage(workflowKey);
        ZKStandingComputationRegistry.StandingProofInput memory oldInput =
            _m65StandingProofInput(workflowKey, subjectCommitment, "m92-old-package-attestation");
        (, uint256 oldSourceSetCommitmentId) = _registerM68FormulaAndSourceSet(oldInput, "m92-old-package-attestation");
        uint256 oldPackageId = rulePackageRegistry.getRulePackage(workflowKey).packageId;
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m92-new-package-attestation");
        uint256 newPackageEvidence = _registerM68SourceSetEvidence(workflowKey, "m92-new-package-attestation-evidence");
        require(evidenceRegistry.getEvidenceReceipt(newPackageEvidence).packageId != oldPackageId, "package did not change");
        IStandingFormulaRegistry.SourceSetCompletenessAttestationInput memory wrongPackage =
            _m92SourceSetCompletenessAttestationInput(
                oldSourceSetCommitmentId, newPackageEvidence, "m92-wrong-package-attestation"
            );
        _assertM92CannotRegisterSourceSetCompletenessAttestation(wrongPackage, "new package attestation evidence registered");
    }

    function testM92ComputationStatementRequiresMatchingCompletenessAttestation() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(DEFAULT_WORKFLOW, subjectCommitment, "m92-statement-binding");
        (, uint256 sourceSetCommitmentId) = _registerM68FormulaAndSourceSet(input, "m92-statement-binding");
        uint256 evidenceId = _registerM68SourceSetEvidence(input.workflowKey, "m92-statement-binding-evidence");
        IStandingFormulaRegistry.StandingComputationStatementInput memory missingAttestation =
            _m91ComputationStatementInput(sourceSetCommitmentId, 0, input, evidenceId, "m92-missing-attestation");
        _assertM91CannotRegisterComputationStatement(missingAttestation, "statement without attestation registered");

        ZKStandingComputationRegistry.StandingProofInput memory otherInput =
            _m65StandingProofInput(DEFAULT_WORKFLOW, subjectCommitment, "m92-other-source-set");
        (, uint256 otherSourceSetCommitmentId) = _registerM68FormulaAndSourceSet(otherInput, "m92-other-source-set");
        uint256 otherEvidenceId = _registerM68SourceSetEvidence(input.workflowKey, "m92-other-attestation-evidence");
        uint256 otherAttestationId =
            _registerM92SourceSetCompletenessAttestation(otherSourceSetCommitmentId, otherEvidenceId, "m92-other-attestation");
        IStandingFormulaRegistry.StandingComputationStatementInput memory wrongAttestation =
            _m91ComputationStatementInput(
                sourceSetCommitmentId, otherAttestationId, input, evidenceId, "m92-wrong-attestation"
            );
        _assertM91CannotRegisterComputationStatement(wrongAttestation, "mismatched attestation registered statement");

        uint256 attestationId =
            _registerM92SourceSetCompletenessAttestation(sourceSetCommitmentId, evidenceId, "m92-statement-binding");
        IStandingFormulaRegistry.StandingComputationStatementInput memory validStatement =
            _m91ComputationStatementInput(sourceSetCommitmentId, attestationId, input, evidenceId, "m92-valid-statement");
        uint256 statementId =
            standingFormulaRegistry.registerStandingComputationStatement(AVADataTypes.Role.Panel, validStatement);
        require(
            standingFormulaRegistry.getStandingComputationStatement(statementId).sourceSetCompletenessAttestationId
                == attestationId,
            "valid statement did not bind attestation"
        );
    }

    function testM92SourceSetCompletenessAttestationDoesNotCreateProofCredentialOrBenefits() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(DEFAULT_WORKFLOW, subjectCommitment, "m92-record-only");
        (, uint256 sourceSetCommitmentId) = _registerM68FormulaAndSourceSet(input, "m92-record-only");
        uint256 evidenceId = _registerM68SourceSetEvidence(input.workflowKey, "m92-record-only-evidence");
        IStandingFormulaRegistry.SourceSetCompletenessAttestationInput memory attestationInput =
            _m92SourceSetCompletenessAttestationInput(sourceSetCommitmentId, evidenceId, "m92-record-only");
        uint256 nextStatementId = standingFormulaRegistry.nextStandingComputationStatementId();
        uint256 nextProofReceiptId = zkStandingComputationRegistry.nextStandingProofReceiptId();
        uint256 nextCredentialId = zkStandingCredentialRegistry.nextCredentialId();

        standingFormulaRegistry.registerSourceSetCompletenessAttestation(AVADataTypes.Role.Panel, attestationInput);

        require(standingFormulaRegistry.nextStandingComputationStatementId() == nextStatementId, "attestation wrote statement");
        require(zkStandingComputationRegistry.nextStandingProofReceiptId() == nextProofReceiptId, "attestation wrote proof");
        require(zkStandingCredentialRegistry.nextCredentialId() == nextCredentialId, "attestation issued credential");
        _assertNoSelector(address(standingFormulaRegistry), "mintReward(uint256)");
        _assertNoSelector(address(standingFormulaRegistry), "mintPriorityToken(uint256)");
        _assertNoSelector(address(standingFormulaRegistry), "executePayment(uint256)");
        _assertNoSelector(address(standingFormulaRegistry), "executeSanction(uint256)");
        _assertNoSelector(address(standingFormulaRegistry), "acceptManuscript(uint256)");
        _assertNoSelector(address(standingFormulaRegistry), "setManuscriptMerit(uint256,uint256)");
        _assertNoSelector(address(standingFormulaRegistry), "revealIdentity(uint256)");
        _assertNoSelector(address(standingFormulaRegistry), "decryptEvidence(uint256)");
    }

    function testM94ZKStandingCredentialRecordsComputationStatementBinding() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        uint256 proofReceiptId = _createM66StandingProofReceipt(DEFAULT_WORKFLOW, subjectCommitment, "m94-binding");
        ZKStandingComputationRegistry.StandingProofReceipt memory proofReceipt =
            zkStandingComputationRegistry.getStandingProofReceipt(proofReceiptId);
        uint256 packageId = rulePackageRegistry.getRulePackage(DEFAULT_WORKFLOW).packageId;
        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory input =
            _m66CredentialInput(proofReceiptId, packageId, subjectCommitment, "m94-binding");

        uint256 credentialId = zkStandingCredentialRegistry.issueCredential(AVADataTypes.Role.Panel, input);
        IZKStandingCredentialIssuer.ZKStandingCredentialRecord memory credential =
            zkStandingCredentialRegistry.getCredential(credentialId);

        require(proofReceipt.standingComputationStatementId != 0, "proof receipt missing statement");
        require(
            credential.standingComputationStatementId == proofReceipt.standingComputationStatementId,
            "credential statement binding missing"
        );
        require(
            zkStandingComputationRegistry.standingProofSupportsCredential(
                proofReceiptId,
                packageId,
                subjectCommitment,
                proofReceipt.vectorKey,
                proofReceipt.categoryHash,
                input.threshold
            ),
            "statement-bound proof did not support credential"
        );
    }

    function testM95SupersededComputationStatementStopsOldCredentialProof() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        uint256 proofReceiptId = _createM66StandingProofReceipt(DEFAULT_WORKFLOW, subjectCommitment, "m95-supersede-old");
        ZKStandingComputationRegistry.StandingProofReceipt memory proofReceipt =
            zkStandingComputationRegistry.getStandingProofReceipt(proofReceiptId);
        uint256 packageId = rulePackageRegistry.getRulePackage(DEFAULT_WORKFLOW).packageId;
        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory credentialInput =
            _m66CredentialInput(proofReceiptId, packageId, subjectCommitment, "m95-supersede-old");
        uint256 credentialId = zkStandingCredentialRegistry.issueCredential(AVADataTypes.Role.Panel, credentialInput);
        require(_m95ZkCredentialProves(credentialId, packageId, subjectCommitment, 40), "old credential not active first");

        ZKStandingComputationRegistry.StandingProofInput memory newProofInput =
            _m65StandingProofInput(DEFAULT_WORKFLOW, subjectCommitment, "m95-supersede-new");
        newProofInput.epoch = proofReceipt.epoch + 1;
        newProofInput.sourceRecordSetRoot =
            keccak256(abi.encode("m95-supersede-new", subjectCommitment, newProofInput.epoch, "source-record-set-root"));
        IStandingFormulaRegistry.StandingComputationStatementInput memory newStatementInput =
            _m95PreparedStatementInput(newProofInput, "m95-supersede-new");
        uint256 newStatementId = standingFormulaRegistry.supersedeStandingComputationStatement(
            AVADataTypes.Role.Panel, proofReceipt.standingComputationStatementId, newStatementInput
        );
        IStandingFormulaRegistry.StandingComputationStatementRecord memory oldStatement =
            standingFormulaRegistry.getStandingComputationStatement(proofReceipt.standingComputationStatementId);
        require(oldStatement.status == AVADataTypes.StandingComputationStatus.Superseded, "old statement not superseded");
        require(oldStatement.supersededBy == newStatementId, "old statement successor missing");

        require(
            !zkStandingComputationRegistry.standingProofSupportsCredential(
                proofReceiptId,
                packageId,
                subjectCommitment,
                proofReceipt.vectorKey,
                proofReceipt.categoryHash,
                40
            ),
            "superseded statement still supports proof"
        );
        require(!_m95ZkCredentialProves(credentialId, packageId, subjectCommitment, 40), "old credential still proved");
        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory staleIssue =
            _m66CredentialInput(proofReceiptId, packageId, subjectCommitment, "m95-stale-issue");
        _assertM66CannotIssueCredential(staleIssue, "superseded statement issued new credential");

        _assertM95CanIssueFromReplacementStatement(newProofInput, newStatementId, packageId, subjectCommitment);
    }

    function testM95InvalidatedComputationStatementStopsOldCredentialProof() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        uint256 proofReceiptId = _createM66StandingProofReceipt(DEFAULT_WORKFLOW, subjectCommitment, "m95-invalidate");
        ZKStandingComputationRegistry.StandingProofReceipt memory proofReceipt =
            zkStandingComputationRegistry.getStandingProofReceipt(proofReceiptId);
        uint256 packageId = rulePackageRegistry.getRulePackage(DEFAULT_WORKFLOW).packageId;
        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory credentialInput =
            _m66CredentialInput(proofReceiptId, packageId, subjectCommitment, "m95-invalidate");
        uint256 credentialId = zkStandingCredentialRegistry.issueCredential(AVADataTypes.Role.Panel, credentialInput);
        require(_m95ZkCredentialProves(credentialId, packageId, subjectCommitment, 40), "credential not active first");

        uint256 invalidationEvidenceId =
            _registerM68SourceSetEvidence(DEFAULT_WORKFLOW, "m95-invalidation-evidence");
        standingFormulaRegistry.invalidateStandingComputationStatement(
            AVADataTypes.Role.Panel,
            proofReceipt.standingComputationStatementId,
            invalidationEvidenceId,
            keccak256("panel-authority"),
            "ipfs://m95-invalidation"
        );
        IStandingFormulaRegistry.StandingComputationStatementRecord memory statement =
            standingFormulaRegistry.getStandingComputationStatement(proofReceipt.standingComputationStatementId);
        require(statement.status == AVADataTypes.StandingComputationStatus.Invalidated, "statement not invalidated");
        require(
            statement.invalidatedByEvidenceReceiptId == invalidationEvidenceId,
            "statement invalidation evidence missing"
        );
        require(
            !zkStandingComputationRegistry.standingProofSupportsCredential(
                proofReceiptId,
                packageId,
                subjectCommitment,
                proofReceipt.vectorKey,
                proofReceipt.categoryHash,
                40
            ),
            "invalidated statement still supports proof"
        );
        require(!_m95ZkCredentialProves(credentialId, packageId, subjectCommitment, 40), "invalidated credential still proved");
        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory staleIssue =
            _m66CredentialInput(proofReceiptId, packageId, subjectCommitment, "m95-invalidated-issue");
        _assertM66CannotIssueCredential(staleIssue, "invalidated statement issued new credential");
    }

    function testM68StandingFormulaRegistryRejectsUnauthorisedWrongPackageEvidenceAndWrongVerifier() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(DEFAULT_WORKFLOW, subjectCommitment, "m68-boundary");
        IStandingFormulaRegistry.StandingFormulaInput memory formulaInput =
            _m68FormulaInput(input.workflowKey, input.vectorKey, input.computationRuleHash, "m68-unauthorised");
        try outsiderActor.registerStandingFormula(standingFormulaRegistry, AVADataTypes.Role.Panel, formulaInput) {
            revert("unauthorised standing formula registered");
        } catch {}

        IStandingFormulaRegistry.StandingFormulaInput memory wrongVerifierFormula =
            _m68FormulaInput(input.workflowKey, input.vectorKey, input.computationRuleHash, "m68-wrong-verifier");
        wrongVerifierFormula.verifier = address(new SchnorrDisclosureProofVerifier());
        uint256 wrongVerifierFormulaId =
            standingFormulaRegistry.registerStandingFormula(AVADataTypes.Role.Panel, wrongVerifierFormula);
        uint256 evidenceId = _registerM68SourceSetEvidence(input.workflowKey, "m68-wrong-verifier");
        _registerM68SourceSetCommitment(wrongVerifierFormulaId, input, evidenceId, "m68-wrong-verifier");
        bytes32 contextHash = zkStandingComputationRegistry.computeStandingComputationContextHash(input);
        _assertM65CannotRegisterStandingProof(
            input,
            _makeSchnorrProof(contextHash, 7, 11),
            "standing proof accepted formula with wrong verifier"
        );

        bytes32 workflowKey = keccak256("m68-wrong-package-evidence");
        _ensureWorkflowPackage(workflowKey);
        ZKStandingComputationRegistry.StandingProofInput memory oldPackageInput =
            _m65StandingProofInput(workflowKey, subjectCommitment, "m68-old-package-source");
        uint256 oldFormulaId = _registerM68Formula(oldPackageInput, "m68-old-package-source");
        uint256 oldPackageId = rulePackageRegistry.getRulePackage(workflowKey).packageId;
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m68-new-package");
        require(rulePackageRegistry.getRulePackage(workflowKey).packageId != oldPackageId, "package did not change");
        uint256 newPackageEvidence = _registerM68SourceSetEvidence(workflowKey, "m68-new-package-evidence");
        try standingFormulaRegistry.registerSourceSetCommitment(
            AVADataTypes.Role.Panel,
            _m68SourceSetCommitmentInput(oldFormulaId, oldPackageInput, newPackageEvidence, "m68-wrong-package")
        ) {
            revert("wrong package evidence accepted for old standing formula");
        } catch {}
    }

    function testM68StandingRegistryRejectsNewPackageEvidenceForOldRecognisedState() public {
        bytes32 workflowKey = keccak256("m68-standing-registry-package-evidence");
        _ensureWorkflowPackage(workflowKey);
        uint256 oldEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m68-old-standing-evidence"),
            "ipfs://m68-old-standing-evidence",
            "m68-standing-evidence",
            0
        );
        uint256 recognisedStateId = _registerRecognisedStateForWorkflowStatus(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, oldEvidenceId, "m68-old-standing-state"
        );
        uint256 oldPackageId = stateMachine.getRecognisedState(recognisedStateId).packageId;
        uint256 computationId = standingRegistry.recordStandingComputationReadiness(
            AVADataTypes.Role.Panel,
            _m68StandingComputationContext(recognisedStateId, oldEvidenceId, "m68-old-standing-computation", 1),
            "ipfs://m68-old-standing-computation"
        );

        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m68-standing-registry-new-package");
        uint256 newEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m68-new-standing-evidence"),
            "ipfs://m68-new-standing-evidence",
            "m68-standing-evidence",
            0
        );
        require(evidenceRegistry.getEvidenceReceipt(newEvidenceId).packageId != oldPackageId, "package did not change");

        _assertM68StandingUpdateRejectsWrongPackageEvidence(
            recognisedStateId, newEvidenceId, "standing update accepted new-package evidence"
        );
        _assertM68StandingComputationRejectsWrongPackageEvidence(
            recognisedStateId, newEvidenceId, "standing computation accepted new-package evidence"
        );
        _assertM68StandingInvalidationRejectsWrongPackageEvidence(
            computationId, newEvidenceId, "standing invalidation accepted new-package evidence"
        );
    }

    function testM68PackageEvidenceCannotCrossStateChallengeAllocationOrConsequenceAfterReregistration() public {
        bytes32 workflowKey = keccak256("m68-substrate-package-evidence");
        _ensureWorkflowPackage(workflowKey);
        uint256 oldEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m68-substrate-old-evidence"),
            "ipfs://m68-substrate-old-evidence",
            "m68-substrate-evidence",
            0
        );
        uint256 vestedStateId = _registerRecognisedStateForWorkflowStatus(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, oldEvidenceId, "m68-substrate-old-vested"
        );
        uint256 challengeableStateId = _registerRecognisedStateForWorkflowStatus(
            workflowKey, AVADataTypes.RecognisedStateStatus.Challengeable, oldEvidenceId, "m68-substrate-old-challengeable"
        );

        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m68-substrate-new-package");
        uint256 newEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m68-substrate-new-evidence"),
            "ipfs://m68-substrate-new-evidence",
            "m68-substrate-evidence",
            0
        );

        _assertM68StateRejectsWrongPackageEvidence(
            workflowKey, oldEvidenceId, "old-package evidence entered new-package recognised state"
        );
        _assertM68ChallengeRejectsWrongPackageEvidence(
            workflowKey, challengeableStateId, newEvidenceId, "new-package evidence entered old-package challenge"
        );
        _assertM68AllocationRejectsWrongPackageEvidence(
            vestedStateId, newEvidenceId, "new-package evidence entered old-package allocation"
        );
        _assertM68ConsequenceRejectsWrongPackageEvidence(
            vestedStateId, newEvidenceId, "new-package evidence entered old-package consequence"
        );
        _assertM68ExternalOperationRejectsWrongPackageEvidence(
            workflowKey, vestedStateId, newEvidenceId, "new-package evidence entered old-package external operation"
        );
    }

    function testM66ZKStandingCredentialIssuesFromProofReceiptWithoutAccountOwner() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        uint256 proofReceiptId = _createM66StandingProofReceipt(DEFAULT_WORKFLOW, subjectCommitment, "m66-issue");
        uint256 packageId = rulePackageRegistry.getRulePackage(DEFAULT_WORKFLOW).packageId;
        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory input =
            _m66CredentialInput(proofReceiptId, packageId, subjectCommitment, "m66-issue");

        uint256 credentialId = zkStandingCredentialRegistry.issueCredential(AVADataTypes.Role.Panel, input);
        IZKStandingCredentialIssuer.ZKStandingCredentialRecord memory credential =
            zkStandingCredentialRegistry.getCredential(credentialId);

        require(credential.standingProofReceiptId == proofReceiptId, "proof receipt missing");
        require(credential.packageId == packageId, "credential package missing");
        require(credential.subjectCommitment == subjectCommitment, "credential subject commitment missing");
        require(credential.credentialCommitment == input.credentialCommitment, "credential commitment missing");
        require(credential.credentialNullifierHash == input.credentialNullifierHash, "credential nullifier missing");
        require(credential.vectorKey == input.vectorKey, "credential vector missing");
        require(credential.categoryHash == input.categoryHash, "credential category missing");
        require(credential.status == AVADataTypes.StandingCredentialStatus.Active, "credential not active");
        require(
            zkStandingCredentialRegistry.credentialProves(
                credentialId,
                packageId,
                subjectCommitment,
                input.vectorKey,
                input.categoryHash,
                40
            ),
            "credential did not prove threshold"
        );

        _assertNoSelector(address(zkStandingCredentialRegistry), "ownerOf(uint256)");
        _assertNoSelector(address(zkStandingCredentialRegistry), "balanceOf(address)");
        _assertNoSelector(address(zkStandingCredentialRegistry), "transferFrom(address,address,uint256)");
        _assertNoSelector(address(zkStandingCredentialRegistry), "approve(address,uint256)");
        _assertNoSelector(address(zkStandingCredentialRegistry), "setApprovalForAll(address,bool)");
        _assertNoSelector(address(zkStandingCredentialRegistry), "mintReward(uint256)");
        _assertNoSelector(address(zkStandingCredentialRegistry), "mintPriorityToken(uint256)");
        _assertNoSelector(address(zkStandingCredentialRegistry), "acceptManuscript(uint256)");
        _assertNoSelector(address(zkStandingCredentialRegistry), "setManuscriptMerit(uint256,uint256)");
        _assertNoSelector(address(zkStandingCredentialRegistry), "revealIdentity(uint256)");
        _assertNoSelector(address(zkStandingCredentialRegistry), "revealEvidence(uint256)");
        _assertNoSelector(address(zkStandingCredentialRegistry), "decryptEvidence(uint256)");
    }

    function testM66ZKStandingCredentialRejectsWrongProofBindings() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        uint256 proofReceiptId = _createM66StandingProofReceipt(DEFAULT_WORKFLOW, subjectCommitment, "m66-binding");
        uint256 packageId = rulePackageRegistry.getRulePackage(DEFAULT_WORKFLOW).packageId;
        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory input =
            _m66CredentialInput(proofReceiptId, packageId, subjectCommitment, "m66-binding");

        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory unknownReceipt = input;
        unknownReceipt.standingProofReceiptId = proofReceiptId + 1000;
        _assertM66CannotIssueCredential(unknownReceipt, "unknown proof receipt issued credential");

        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory wrongPackage = input;
        wrongPackage.packageId = packageId + 1;
        _assertM66CannotIssueCredential(wrongPackage, "wrong package issued credential");

        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory wrongSubject = input;
        wrongSubject.subjectCommitment = _subjectCommitmentForSecret(9);
        _assertM66CannotIssueCredential(wrongSubject, "wrong subject commitment issued credential");

        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory wrongVector = input;
        wrongVector.vectorKey = keccak256("m66-wrong-vector");
        _assertM66CannotIssueCredential(wrongVector, "wrong vector issued credential");

        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory wrongCategory = input;
        wrongCategory.categoryHash = keccak256("m66-wrong-category");
        _assertM66CannotIssueCredential(wrongCategory, "wrong category issued credential");

        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory badThreshold = input;
        badThreshold.threshold = 43;
        _assertM66CannotIssueCredential(badThreshold, "threshold above proof value issued credential");

        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory wrongEpoch = input;
        wrongEpoch.epoch = input.epoch + 1;
        _assertM66CannotIssueCredential(wrongEpoch, "wrong epoch issued credential");

        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory wrongSourceRoot = input;
        wrongSourceRoot.sourceRecordSetRoot = keccak256("m66-wrong-source-root");
        _assertM66CannotIssueCredential(wrongSourceRoot, "wrong source root issued credential");

        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory wrongRule = input;
        wrongRule.computationRuleHash = keccak256("m66-wrong-rule");
        _assertM66CannotIssueCredential(wrongRule, "wrong computation rule issued credential");
    }

    function testM66ZKStandingCredentialRejectsDuplicateCommitmentAndNullifier() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        uint256 proofReceiptId = _createM66StandingProofReceipt(DEFAULT_WORKFLOW, subjectCommitment, "m66-duplicate");
        uint256 packageId = rulePackageRegistry.getRulePackage(DEFAULT_WORKFLOW).packageId;
        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory input =
            _m66CredentialInput(proofReceiptId, packageId, subjectCommitment, "m66-duplicate");

        uint256 credentialId = zkStandingCredentialRegistry.issueCredential(AVADataTypes.Role.Panel, input);
        require(credentialId != 0, "valid credential not issued");
        _assertM66CannotIssueCredential(input, "duplicate credential nullifier issued credential");

        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory duplicateCommitment =
            _m66CredentialInput(proofReceiptId, packageId, subjectCommitment, "m66-duplicate-commitment");
        duplicateCommitment.credentialCommitment = input.credentialCommitment;
        _assertM66CannotIssueCredential(duplicateCommitment, "duplicate credential commitment issued credential");
    }

    function testM66ZKStandingCredentialProofUseRejectsNullifierReplay() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        string memory seed = "m66-use-active";
        uint256 activeCredentialId =
            _issueM66ZKStandingCredential(DEFAULT_WORKFLOW, subjectCommitment, seed, 1, block.timestamp + 7 days);
        IZKStandingCredentialIssuer.ZKStandingCredentialRecord memory credential =
            zkStandingCredentialRegistry.getCredential(activeCredentialId);
        bytes32 targetContext = keccak256("m66-target-context");

        uint256 useRecordId = _recordM66CredentialUseWithSecret(
            activeCredentialId,
            40,
            targetContext,
            _m66CredentialSecret(seed),
            19
        );
        IZKStandingCredentialIssuer.ZKStandingCredentialUseRecord memory useRecord =
            zkStandingCredentialRegistry.getCredentialUseRecord(useRecordId);
        require(useRecord.credentialId == activeCredentialId, "credential use target missing");
        require(useRecord.targetContextHash == targetContext, "target context missing");
        require(useRecord.vectorKey == credential.vectorKey, "use vector missing");
        _assertM66CannotRecordCredentialUseWithSecret(
            activeCredentialId,
            40,
            targetContext,
            _m66CredentialSecret(seed),
            "proof-use nullifier replay accepted"
        );
    }

    function testM66ZKStandingCredentialUseRequiresCredentialHolderProof() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        string memory seed = "m66-use-holder-proof";
        uint256 credentialId =
            _issueM66ZKStandingCredential(DEFAULT_WORKFLOW, subjectCommitment, seed, 1, block.timestamp + 7 days);
        bytes32 targetContext = keccak256("m66-holder-proof-target");

        _assertM66CannotRecordCredentialUseWithSecret(
            credentialId,
            40,
            targetContext,
            _m66CredentialSecret("m66-wrong-holder"),
            "credential use accepted wrong holder proof"
        );

        uint256 useRecordId = _recordM66CredentialUseWithSecret(
            credentialId,
            40,
            targetContext,
            _m66CredentialSecret(seed),
            31
        );
        require(zkStandingCredentialRegistry.getCredentialUseRecord(useRecordId).credentialId == credentialId, "use missing");
    }

    function testM66RevokedCredentialCannotProve() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        uint256 packageId = rulePackageRegistry.getRulePackage(DEFAULT_WORKFLOW).packageId;
        uint256 revokedId =
            _issueM66ZKStandingCredential(DEFAULT_WORKFLOW, subjectCommitment, "m66-revoke", 1, block.timestamp + 7 days);
        IZKStandingCredentialIssuer.ZKStandingCredentialRecord memory credential =
            zkStandingCredentialRegistry.getCredential(revokedId);
        zkStandingCredentialRegistry.revokeCredential(
            AVADataTypes.Role.Panel,
            revokedId,
            subjectCommitment,
            keccak256("panel-authority"),
            "ipfs://m66-revoke"
        );
        credential = zkStandingCredentialRegistry.getCredential(revokedId);
        require(credential.statusReference == keccak256(bytes("ipfs://m66-revoke")), "revoke reference missing");
        require(keccak256(bytes(credential.statusURI)) == keccak256(bytes("ipfs://m66-revoke")), "revoke uri missing");
        require(!zkStandingCredentialRegistry.isCredentialActive(revokedId), "revoked credential active");
        require(
            !zkStandingCredentialRegistry.credentialProves(
                revokedId, packageId, subjectCommitment, credential.vectorKey, credential.categoryHash, 40
            ),
            "revoked credential proved"
        );
    }

    function testM66SupersededCredentialCannotProve() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        uint256 packageId = rulePackageRegistry.getRulePackage(DEFAULT_WORKFLOW).packageId;
        uint256 supersededId =
            _issueM66ZKStandingCredential(DEFAULT_WORKFLOW, subjectCommitment, "m66-old", 1, block.timestamp + 7 days);
        uint256 supersedingProofId =
            _createM66StandingProofReceipt(DEFAULT_WORKFLOW, subjectCommitment, "m66-new", 2);
        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory supersedingInput =
            _m66CredentialInput(supersedingProofId, packageId, subjectCommitment, "m66-new");
        uint256 newCredentialId = zkStandingCredentialRegistry.supersedeCredential(
            AVADataTypes.Role.Panel,
            supersededId,
            supersedingInput
        );
        require(newCredentialId != 0, "superseding credential missing");
        IZKStandingCredentialIssuer.ZKStandingCredentialRecord memory oldCredential =
            zkStandingCredentialRegistry.getCredential(supersededId);
        require(oldCredential.statusReference == bytes32(newCredentialId), "supersession reference missing");
        require(!zkStandingCredentialRegistry.isCredentialActive(supersededId), "superseded credential active");
    }

    function testM66SuspendedAndExpiredCredentialsCannotProve() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        Actor zkSubjectActor = new Actor();
        roleRegistry.assignRole(
            address(zkSubjectActor),
            AVADataTypes.Role.Challenger,
            subjectCommitment,
            "ipfs://m66-zk-subject"
        );
        _registerM421ExecutionWorkflow(DEFAULT_WORKFLOW, "ipfs://m66-source-bound-suspension-workflow");
        uint256 suspendedId =
            _issueM66ZKStandingCredential(DEFAULT_WORKFLOW, subjectCommitment, "m66-suspend", 1, block.timestamp + 7 days);
        _assertNoSelector(
            address(zkStandingCredentialRegistry),
            "suspendCredential(uint8,uint256,uint256,bytes32,bytes32,bytes32,string)"
        );
        require(zkStandingCredentialRegistry.isCredentialActive(suspendedId), "credential inactive before source suspension");

        MockERC20 token = _m421FundedToken(20);
        uint256 sourceId = _createM69RewardSource(
            DEFAULT_WORKFLOW, subjectCommitment, "m66-source-bound-suspension", token, 5, AVADataTypes.ValueExecutionMode.Claim
        );
        uint256 settlementId = valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m66-source-bound-settlement"
        );
        uint256 suspensionRecordId = zkStandingCredentialRegistry.recordSettlementBoundSuspension(
            AVADataTypes.Role.Panel,
            suspendedId,
            AVADataTypes.StandingRelevantSettlementKind.RewardExecution,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            settlementId,
            keccak256("panel-authority"),
            "ipfs://m66-source-bound-suspension"
        );
        IZKStandingCredentialIssuer.ZKStandingCredentialRecord memory suspendedCredential =
            zkStandingCredentialRegistry.getCredential(suspendedId);
        require(
            suspendedCredential.statusReference == bytes32(suspensionRecordId),
            "suspension reference missing"
        );
        require(
            keccak256(bytes(suspendedCredential.statusURI)) == keccak256(bytes("ipfs://m66-source-bound-suspension")),
            "suspension uri missing"
        );
        require(!zkStandingCredentialRegistry.isCredentialActive(suspendedId), "suspended credential active");

        uint256 expiringId =
            _issueM66ZKStandingCredential(DEFAULT_WORKFLOW, subjectCommitment, "m66-expire", 2, block.timestamp + 1);
        vm.warp(block.timestamp + 2);
        require(!zkStandingCredentialRegistry.isCredentialActive(expiringId), "expired credential active");
    }

    function testM66UnauthorisedCallerCannotManageZKStandingCredential() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        uint256 packageId = rulePackageRegistry.getRulePackage(DEFAULT_WORKFLOW).packageId;
        uint256 proofReceiptId = _createM66StandingProofReceipt(DEFAULT_WORKFLOW, subjectCommitment, "m66-unauthorised");
        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory input =
            _m66CredentialInput(proofReceiptId, packageId, subjectCommitment, "m66-unauthorised");

        try outsiderActor.issueZKStandingCredential(zkStandingCredentialRegistry, AVADataTypes.Role.Panel, input) {
            revert("unauthorised actor issued zk standing credential");
        } catch {}

        uint256 credentialId = zkStandingCredentialRegistry.issueCredential(AVADataTypes.Role.Panel, input);
        try outsiderActor.revokeZKStandingCredential(
            zkStandingCredentialRegistry,
            AVADataTypes.Role.Panel,
            credentialId,
            subjectCommitment,
            keccak256("panel-authority"),
            "ipfs://m66-bad-revoke"
        ) {
            revert("unauthorised actor revoked zk standing credential");
        } catch {}

        uint256 replacementProofId =
            _createM66StandingProofReceipt(DEFAULT_WORKFLOW, subjectCommitment, "m66-unauthorised-replacement", 2);
        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory replacement =
            _m66CredentialInput(replacementProofId, packageId, subjectCommitment, "m66-unauthorised-replacement");
        try outsiderActor.supersedeZKStandingCredential(
            zkStandingCredentialRegistry,
            AVADataTypes.Role.Panel,
            credentialId,
            replacement
        ) {
            revert("unauthorised actor superseded zk standing credential");
        } catch {}

        _assertNoSelector(
            address(zkStandingCredentialRegistry),
            "suspendCredential(uint8,uint256,uint256,bytes32,bytes32,bytes32,string)"
        );
        require(zkStandingCredentialRegistry.isCredentialActive(credentialId), "unauthorised action changed credential");
    }

    function testM69ZKStandingCredentialSettlementBoundSuspensionRequiresRealSourcePackageAndSubject() public {
        bytes32 workflowKey = keccak256("m69-zk-settlement-workflow");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m69-zk-settlement-workflow");
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        Actor zkSubjectActor = new Actor();
        roleRegistry.assignRole(
            address(zkSubjectActor),
            AVADataTypes.Role.Challenger,
            subjectCommitment,
            "ipfs://m69-zk-subject"
        );
        uint256 credentialId =
            _issueM66ZKStandingCredential(workflowKey, subjectCommitment, "m69-zk-settlement", 1, block.timestamp + 7 days);

        MockERC20 token = _m421FundedToken(100);
        uint256 sourceId = _createM69RewardSource(
            workflowKey, subjectCommitment, "m69-zk-bound-source", token, 9, AVADataTypes.ValueExecutionMode.Claim
        );
        uint256 settlementId = valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m69-zk-bound-settlement"
        );

        _assertM69SettlementSuspensionRejectsInvalidBindings(
            credentialId, workflowKey, subjectCommitment, token, sourceId, settlementId
        );

        uint256 suspensionId = zkStandingCredentialRegistry.recordSettlementBoundSuspension(
            AVADataTypes.Role.Panel,
            credentialId,
            AVADataTypes.StandingRelevantSettlementKind.RewardExecution,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            settlementId,
            keccak256("panel-authority"),
            "ipfs://m69-zk-valid-settlement-suspension"
        );
        IZKStandingCredentialIssuer.ZKStandingCredentialSuspensionRecord memory suspension =
            zkStandingCredentialRegistry.getCredentialSuspensionRecord(suspensionId);
        require(
            suspension.sourceKind == IZKStandingCredentialIssuer.ZKStandingCredentialSuspensionSourceKind.ValueSettlement,
            "wrong suspension source kind"
        );
        require(suspension.credentialId == credentialId, "credential not recorded");
        require(suspension.sourceRecordId == sourceId, "source not recorded");
        require(suspension.settlementId == settlementId, "settlement not recorded");
        require(suspension.subjectCommitment == subjectCommitment, "subject not recorded");
        require(!zkStandingCredentialRegistry.isCredentialActive(credentialId), "valid source-bound suspension not active");
    }

    function testM69ZKStandingCredentialChallengeBoundSuspensionRejectsGoodFaithAndAcceptsMaliciousRecord() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        Actor zkChallengerActor = new Actor();
        roleRegistry.assignRole(
            address(zkChallengerActor),
            AVADataTypes.Role.Challenger,
            subjectCommitment,
            "ipfs://m69-zk-challenger"
        );
        uint256 credentialId =
            _issueM66ZKStandingCredential(DEFAULT_WORKFLOW, subjectCommitment, "m69-zk-challenge", 1, block.timestamp + 7 days);

        uint256 goodFaithTransitionId = _createM69ChallengeResolutionTransition(
            zkChallengerActor,
            subjectCommitment,
            "m69-good-faith",
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith
        );
        _assertM69InvalidChallengeBoundSuspensionDoesNotDisable(
            credentialId, goodFaithTransitionId, "good-faith rejected challenge suspended zk credential"
        );

        uint256 maliciousTransitionId = _createM69ChallengeResolutionTransition(
            zkChallengerActor,
            subjectCommitment,
            "m69-malicious",
            AVADataTypes.ChallengeOutcome.MaliciousOrFabricated
        );
        uint256 nextConsequenceId = consequenceExecutor.nextConsequenceId();
        uint256 nextStandingInputId = standingRegistry.nextStandingInputId();
        uint256 suspensionId = zkStandingCredentialRegistry.recordChallengeTransitionBoundSuspension(
            AVADataTypes.Role.Panel,
            credentialId,
            maliciousTransitionId,
            keccak256("panel-authority"),
            "ipfs://m69-malicious-source-bound-suspension"
        );
        IZKStandingCredentialIssuer.ZKStandingCredentialSuspensionRecord memory suspension =
            zkStandingCredentialRegistry.getCredentialSuspensionRecord(suspensionId);
        require(
            suspension.sourceKind == IZKStandingCredentialIssuer.ZKStandingCredentialSuspensionSourceKind.ChallengeTransition,
            "wrong challenge suspension source kind"
        );
        require(suspension.challengeTransitionId == maliciousTransitionId, "challenge transition not recorded");
        require(
            suspension.challengeOutcome == AVADataTypes.ChallengeOutcome.MaliciousOrFabricated,
            "malicious outcome missing"
        );
        require(!zkStandingCredentialRegistry.isCredentialActive(credentialId), "malicious suspension not applied");
        require(consequenceExecutor.nextConsequenceId() == nextConsequenceId, "challenge suspension executed sanction");
        require(standingRegistry.nextStandingInputId() == nextStandingInputId, "challenge suspension updated standing");
        _assertNoSelector(address(zkStandingCredentialRegistry), "executeSanction(uint256)");
        _assertNoSelector(address(zkStandingCredentialRegistry), "mintReward(uint256)");
        _assertNoSelector(address(zkStandingCredentialRegistry), "mintPriorityToken(uint256)");
        _assertNoSelector(address(zkStandingCredentialRegistry), "acceptManuscript(uint256)");
        _assertNoSelector(address(zkStandingCredentialRegistry), "setManuscriptMerit(uint256,uint256)");
    }

    function testM423StandingRelevantSettlementSuspendsOldCredentialUntilRecomputed() public {
        bytes32 workflowKey = keccak256("m423-standing-settlement-workflow");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m423-standing-settlement-workflow");
        uint256 computationId = _createM423StandingComputationRecord(workflowKey, "m423-settlement-old", 42);
        uint256 credentialId =
            standingCredentialRegistry.issueCredential(
                AVADataTypes.Role.Panel,
                _m422CredentialInputForComputation(computationId, block.timestamp + 7 days, "ipfs://m423-old-credential")
            );
        require(_m422CredentialProves(credentialId, 40), "fresh credential did not prove");

        MockERC20 token = _m421FundedToken(100);
        uint256 sourceId =
            _createM421RewardSource(workflowKey, "m423-standing-settlement-source", token, 9, AVADataTypes.ValueExecutionMode.Claim);
        uint256 settlementId = valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m423-reward-execution"
        );
        uint256 settlementRecordId = standingCredentialRegistry.recordStandingRelevantSettlement(
            AVADataTypes.Role.Panel,
            credentialId,
            AVADataTypes.StandingRelevantSettlementKind.RewardExecution,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            settlementId,
            keccak256("panel-authority"),
            "ipfs://m423-standing-impact"
        );
        AVADataTypes.StandingCredentialSettlementRecord memory settlementImpact =
            standingCredentialRegistry.getStandingCredentialSettlement(settlementRecordId);
        require(settlementImpact.kind == AVADataTypes.StandingRelevantSettlementKind.RewardExecution, "wrong impact kind");
        require(settlementImpact.sourceRecordId == sourceId, "source not recorded");
        require(settlementImpact.settlementId == settlementId, "settlement not recorded");
        require(!standingCredentialRegistry.isCredentialActive(credentialId), "settlement credential still active");
        require(!_m422CredentialProves(credentialId, 40), "settlement credential still proved");
        require(
            standingCredentialRegistry.getStandingCredential(credentialId).status
                == AVADataTypes.StandingCredentialStatus.Suspended,
            "credential not suspended"
        );

        uint256 recomputedId = _createM423StandingComputationRecord(workflowKey, "m423-settlement-new", 45);
        uint256 refreshedCredentialId =
            standingCredentialRegistry.issueCredential(
                AVADataTypes.Role.Panel,
                _m422CredentialInputForComputation(recomputedId, block.timestamp + 7 days, "ipfs://m423-refreshed-credential")
            );
        require(_m422CredentialProves(refreshedCredentialId, 40), "refreshed credential did not prove");
    }

    function testM424StandingRelevantSettlementRequiresRealBoundSettlementRecord() public {
        bytes32 workflowKey = keccak256("m424-settlement-binding-workflow");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m424-settlement-binding-workflow");
        uint256 computationId = _createM423StandingComputationRecord(workflowKey, "m424-binding-credential", 42);
        uint256 credentialId = standingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m422CredentialInputForComputation(computationId, block.timestamp + 7 days, "ipfs://m424-binding-credential")
        );

        MockERC20 token = _m421FundedToken(100);
        uint256 sourceId =
            _createM421RewardSource(workflowKey, "m424-bound-source", token, 9, AVADataTypes.ValueExecutionMode.Claim);
        uint256 settlementId = valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m424-bound-settlement"
        );
        _assertM424InvalidSettlementDoesNotSuspend(
            credentialId,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            settlementId + 1000,
            "unknown settlement suspended credential"
        );

        uint256 otherSourceId =
            _createM421RewardSource(workflowKey, "m424-other-source", token, 3, AVADataTypes.ValueExecutionMode.Claim);
        uint256 otherSettlementId = valueSettlementExecutor.recordRepaymentObligation(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            otherSourceId,
            keccak256("executor-authority"),
            "ipfs://m424-wrong-source-settlement"
        );
        _assertM424InvalidSettlementDoesNotSuspend(
            credentialId,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            otherSettlementId,
            "wrong source settlement suspended credential"
        );

        bytes32 foreignWorkflowKey = keccak256("m424-foreign-workflow");
        _registerM421ExecutionWorkflow(foreignWorkflowKey, "ipfs://m424-foreign-workflow");
        uint256 foreignSourceId = _createM421RewardSource(
            foreignWorkflowKey,
            "m424-foreign-source",
            token,
            4,
            AVADataTypes.ValueExecutionMode.Claim
        );
        uint256 foreignSettlementId = valueSettlementExecutor.recordRepaymentObligation(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            foreignSourceId,
            keccak256("executor-authority"),
            "ipfs://m424-wrong-package-settlement"
        );
        _assertM424InvalidSettlementDoesNotSuspend(
            credentialId,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            foreignSettlementId,
            "wrong package settlement suspended credential"
        );

        (uint256 authorSourceId, uint256 authorSettlementId) =
            _createM425AuthorRewardSettlement(workflowKey, "m424-author-source", token, 2);
        _assertM424InvalidSettlementDoesNotSuspend(
            credentialId,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            authorSourceId,
            authorSettlementId,
            "wrong subject settlement suspended credential"
        );

        uint256 impactId = standingCredentialRegistry.recordStandingRelevantSettlement(
            AVADataTypes.Role.Panel,
            credentialId,
            AVADataTypes.StandingRelevantSettlementKind.RewardExecution,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            settlementId,
            keccak256("panel-authority"),
            "ipfs://m424-valid-impact"
        );
        require(standingCredentialRegistry.getStandingCredentialSettlement(impactId).settlementId == settlementId, "valid settlement missing");
        require(!standingCredentialRegistry.isCredentialActive(credentialId), "valid settlement did not suspend");
    }

    function testM425StandingRelevantSettlementKindMustMatchValueSettlementKind() public {
        bytes32 workflowKey = keccak256("m425-standing-kind-workflow");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m425-standing-kind-workflow");
        uint256 computationId = _createM423StandingComputationRecord(workflowKey, "m425-standing-kind", 42);
        uint256 credentialId = standingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m422CredentialInputForComputation(computationId, block.timestamp + 7 days, "ipfs://m425-standing-kind")
        );

        MockERC20 token = _m421FundedToken(100);
        uint256 sourceId =
            _createM421RewardSource(workflowKey, "m425-standing-kind-source", token, 6, AVADataTypes.ValueExecutionMode.Claim);
        uint256 settlementId = valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m425-token-settlement"
        );

        try standingCredentialRegistry.recordStandingRelevantSettlement(
            AVADataTypes.Role.Panel,
            credentialId,
            AVADataTypes.StandingRelevantSettlementKind.Waiver,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            settlementId,
            keccak256("panel-authority"),
            "ipfs://m425-wrong-standing-kind"
        ) {
            revert("standing settlement accepted mismatched kind");
        } catch {}
        require(standingCredentialRegistry.isCredentialActive(credentialId), "mismatched standing kind suspended credential");

        uint256 impactId = standingCredentialRegistry.recordStandingRelevantSettlement(
            AVADataTypes.Role.Panel,
            credentialId,
            AVADataTypes.StandingRelevantSettlementKind.RewardExecution,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            settlementId,
            keccak256("panel-authority"),
            "ipfs://m425-valid-standing-kind"
        );
        require(standingCredentialRegistry.getStandingCredentialSettlement(impactId).settlementId == settlementId, "valid standing kind rejected");
    }

    function testM54StandingComputationRecordsProvenanceAndCredentialRequiresMatch() public {
        uint256 computationId = _createM422StandingComputationRecord("m54-provenance", 42);
        AVADataTypes.StandingComputationRecord memory computation =
            standingRegistry.getStandingComputationRecord(computationId);
        require(computation.status == AVADataTypes.StandingComputationStatus.Active, "computation not active");
        require(computation.epoch == 1, "epoch missing");
        require(computation.sourceRecordSetHash != bytes32(0), "source set hash missing");
        require(computation.computationRuleHash == _m422ComputationRuleHash(), "rule hash missing");

        IStandingCredentialIssuer.StandingCredentialInput memory wrongEpoch =
            _m422CredentialInputForComputation(computationId, block.timestamp + 7 days, "ipfs://m54-wrong-epoch");
        wrongEpoch.epoch = wrongEpoch.epoch + 1;
        try standingCredentialRegistry.issueCredential(AVADataTypes.Role.Panel, wrongEpoch) {
            revert("credential accepted mismatched computation epoch");
        } catch {}

        IStandingCredentialIssuer.StandingCredentialInput memory wrongRule =
            _m422CredentialInputForComputation(computationId, block.timestamp + 7 days, "ipfs://m54-wrong-rule");
        wrongRule.computationRuleHash = keccak256("m54-wrong-standing-rule");
        try standingCredentialRegistry.issueCredential(AVADataTypes.Role.Panel, wrongRule) {
            revert("credential accepted mismatched computation rule");
        } catch {}

        uint256 credentialId = standingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m422CredentialInputForComputation(computationId, block.timestamp + 7 days, "ipfs://m54-valid-credential")
        );
        require(_m422CredentialProves(credentialId, 40), "valid credential did not prove");
    }

    function testM54SupersededStandingComputationStopsOldCredentialProof() public {
        uint256 oldComputationId = _createM422StandingComputationRecord("m54-old-computation", 42);
        uint256 oldCredentialId = standingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m422CredentialInputForComputation(oldComputationId, block.timestamp + 7 days, "ipfs://m54-old-credential")
        );
        require(_m422CredentialProves(oldCredentialId, 40), "old credential did not prove before supersession");

        AVADataTypes.StandingComputationContext memory replacementContext =
            _m54ReplacementComputationContext(oldComputationId, "m54-new-computation", 45, 2);
        uint256 newComputationId = standingRegistry.supersedeStandingComputationReadiness(
            AVADataTypes.Role.Panel,
            oldComputationId,
            replacementContext,
            "ipfs://m54-new-computation"
        );
        AVADataTypes.StandingComputationRecord memory oldComputation =
            standingRegistry.getStandingComputationRecord(oldComputationId);
        require(oldComputation.status == AVADataTypes.StandingComputationStatus.Superseded, "old computation not superseded");
        require(oldComputation.supersededBy == newComputationId, "superseding computation missing");
        require(!standingCredentialRegistry.isCredentialActive(oldCredentialId), "old credential still active");
        require(!_m422CredentialProves(oldCredentialId, 40), "old credential still proved after computation supersession");

        uint256 newCredentialId = standingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m422CredentialInputForComputation(newComputationId, block.timestamp + 7 days, "ipfs://m54-new-credential")
        );
        require(_m422CredentialProves(newCredentialId, 40), "new credential did not prove");
    }

    function testM54InvalidatedStandingComputationStopsCredentialProof() public {
        uint256 computationId = _createM422StandingComputationRecord("m54-invalidated", 42);
        uint256 credentialId = standingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m422CredentialInputForComputation(computationId, block.timestamp + 7 days, "ipfs://m54-invalidated-credential")
        );
        AVADataTypes.StandingComputationRecord memory computation =
            standingRegistry.getStandingComputationRecord(computationId);
        uint256 invalidationId = standingRegistry.invalidateStandingComputation(
            AVADataTypes.Role.Panel,
            computationId,
            computation.evidenceReceiptId,
            keccak256("panel-authority"),
            "ipfs://m54-invalidation"
        );
        AVADataTypes.StandingComputationRecord memory invalidated =
            standingRegistry.getStandingComputationRecord(computationId);
        require(invalidated.status == AVADataTypes.StandingComputationStatus.Invalidated, "computation not invalidated");
        require(invalidated.invalidatedByEvidenceReceiptId == computation.evidenceReceiptId, "invalidation evidence missing");
        require(invalidationId == computationId, "invalidation target not returned");
        require(!standingCredentialRegistry.isCredentialActive(credentialId), "credential still active after invalidation");
        require(!_m422CredentialProves(credentialId, 40), "credential still proved after invalidation");
    }

    function testM423RepaymentSetoffWaiverAndSatisfactionKeepLosslessHistory() public {
        bytes32 workflowKey = keccak256("m423-recovery-history-workflow");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m423-recovery-history-workflow");
        MockERC20 token = _m421FundedToken(100);
        MockERC20 unrelatedToken = new MockERC20("Unrelated Asset", "UNA");
        unrelatedToken.mint(address(reviewerActor), 23);
        uint256 sourceId =
            _createM421RewardSource(workflowKey, "m423-recovery-source", token, 8, AVADataTypes.ValueExecutionMode.Claim);

        uint256 executionId = valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m423-reward-execution"
        );
        uint256 obligationId = valueSettlementExecutor.recordRepaymentObligation(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m423-repayment-obligation"
        );
        uint256 setoffSourceId =
            _createM421RewardSource(workflowKey, "m423-setoff-source", token, 3, AVADataTypes.ValueExecutionMode.Claim);
        uint256 setoffId = valueSettlementExecutor.recordFuturePayoutSetoff(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            setoffSourceId,
            keccak256("executor-authority"),
            "ipfs://m423-future-setoff"
        );
        uint256 waiverSourceId =
            _createM421RewardSource(workflowKey, "m423-waiver-source", token, 2, AVADataTypes.ValueExecutionMode.Claim);
        uint256 waiverId = valueSettlementExecutor.recordWaiver(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            waiverSourceId,
            keccak256("executor-authority"),
            "ipfs://m423-waiver"
        );
        uint256 satisfactionId = valueSettlementExecutor.recordSatisfaction(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m423-satisfaction"
        );

        require(valueSettlementExecutor.getValueSettlement(executionId).kind == AVADataTypes.ValueSettlementKind.TokenTransfer, "execution missing");
        require(
            valueSettlementExecutor.getValueSettlement(obligationId).kind
                == AVADataTypes.ValueSettlementKind.RepaymentObligation,
            "obligation missing"
        );
        require(
            valueSettlementExecutor.getValueSettlement(setoffId).status == AVADataTypes.ValueSettlementStatus.SetoffRecorded,
            "setoff missing"
        );
        require(valueSettlementExecutor.getValueSettlement(waiverId).status == AVADataTypes.ValueSettlementStatus.Waived, "waiver missing");
        require(
            valueSettlementExecutor.getValueSettlement(satisfactionId).status
                == AVADataTypes.ValueSettlementStatus.Satisfied,
            "satisfaction missing"
        );
        require(valueSettlementExecutor.getValueSettlement(obligationId).sourceRecordId == sourceId, "obligation unbound");
        require(token.balanceOf(address(reviewerActor)) == 8, "recovery receipts moved source reward");
        require(unrelatedToken.balanceOf(address(reviewerActor)) == 23, "recovery seized unrelated wallet asset");
    }

    function testM423PenaltyChainSeparatesValueStandingAndEligibilityEffects() public {
        bytes32 authorSubject = keccak256("author-subject");
        (uint256 fraudStateId, uint256 fraudChallengeId, uint256 fraudEvidenceId) = _createResolvedChallengeForSubject(
            authorSubject,
            "m423-fraud-upheld",
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded
        );
        uint256 fraudPenaltyId = consequenceExecutor.recordPenalty(
            AVADataTypes.Role.Panel,
            fraudStateId,
            authorSubject,
            fraudEvidenceId,
            keccak256("panel-authority"),
            "ipfs://m423-fraud-penalty"
        );
        uint256 fraudInputId = consequenceExecutor.recordStandingPenaltyInput(
            AVADataTypes.Role.Panel,
            fraudPenaltyId,
            fraudChallengeId,
            AVADataTypes.StandingPenaltyKind.AcademicFraud,
            "author-integrity-standing",
            -50,
            fraudEvidenceId,
            keccak256("panel-authority"),
            "ipfs://m423-fraud-standing-input"
        );

        (uint256 reviewStateId, uint256 reviewChallengeId, uint256 reviewEvidenceId) = _createResolvedChallengeForSubject(
            REVIEWER_SUBJECT,
            "m423-irresponsible-review-upheld",
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded
        );
        uint256 reviewPenaltyId = consequenceExecutor.recordPenalty(
            AVADataTypes.Role.Panel,
            reviewStateId,
            REVIEWER_SUBJECT,
            reviewEvidenceId,
            keccak256("panel-authority"),
            "ipfs://m423-irresponsible-review-penalty"
        );
        uint256 reviewInputId = consequenceExecutor.recordStandingPenaltyInput(
            AVADataTypes.Role.Panel,
            reviewPenaltyId,
            reviewChallengeId,
            AVADataTypes.StandingPenaltyKind.IrresponsibleReview,
            "review-procedure-weight",
            -8,
            reviewEvidenceId,
            keccak256("panel-authority"),
            "ipfs://m423-review-standing-input"
        );

        (uint256 maliciousPenaltyId, uint256 maliciousEvidenceId) =
            _createM423PenaltyConsequence(CHALLENGER_SUBJECT, "m423-malicious-challenge");
        uint256 maliciousChallengeId = _fileAndScreenChallenge("m423-malicious-challenge");
        stateMachine.resolveChallenge(
            AVADataTypes.Role.Panel,
            maliciousChallengeId,
            AVADataTypes.ChallengeOutcome.MaliciousOrFabricated,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://m423-malicious"
        );
        uint256 maliciousInputId = consequenceExecutor.recordStandingPenaltyInput(
            AVADataTypes.Role.Panel,
            maliciousPenaltyId,
            maliciousChallengeId,
            AVADataTypes.StandingPenaltyKind.MaliciousOrFabricatedChallenge,
            "challenge-integrity-standing",
            -30,
            maliciousEvidenceId,
            keccak256("panel-authority"),
            "ipfs://m423-malicious-standing-input"
        );
        uint256 restrictionId = consequenceExecutor.recordEligibilityRestriction(
            AVADataTypes.Role.Panel,
            maliciousPenaltyId,
            maliciousChallengeId,
            AVADataTypes.EligibilityRestrictionKind.ChallengeIntake,
            block.timestamp + 14 days,
            maliciousEvidenceId,
            keccak256("panel-authority"),
            "ipfs://m423-challenge-intake-restriction"
        );

        uint256 goodFaithChallengeId = _fileAndScreenChallenge("m423-good-faith-protected");
        stateMachine.resolveChallenge(
            AVADataTypes.Role.Panel,
            goodFaithChallengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://m423-good-faith"
        );
        try consequenceExecutor.recordStandingPenaltyInput(
            AVADataTypes.Role.Panel,
            maliciousPenaltyId,
            goodFaithChallengeId,
            AVADataTypes.StandingPenaltyKind.MaliciousOrFabricatedChallenge,
            "challenge-integrity-standing",
            -30,
            maliciousEvidenceId,
            keccak256("panel-authority"),
            "ipfs://m423-good-faith-rejected"
        ) {
            revert("good-faith failed challenge created misconduct standing input");
        } catch {}

        _assertM423PenaltyChainRecords(
            fraudInputId, reviewInputId, maliciousInputId, restrictionId
        );
    }

    function testStandingPenaltyInputRequiresCompatibleChallengeLinkage() public {
        (uint256 penaltyId, uint256 evidenceId) =
            _createM423PenaltyConsequence(REVIEWER_SUBJECT, "p1-penalty-linkage");

        try consequenceExecutor.recordStandingPenaltyInput(
            AVADataTypes.Role.Panel,
            penaltyId,
            0,
            AVADataTypes.StandingPenaltyKind.AcademicFraud,
            "review-procedure-weight",
            -5,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://p1-zero-challenge"
        ) {
            revert("standing penalty accepted zero challenge id");
        } catch {}

        uint256 goodFaithChallengeId = _fileAndScreenChallenge("p1-good-faith-linkage");
        stateMachine.resolveChallenge(
            AVADataTypes.Role.Panel,
            goodFaithChallengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://p1-good-faith-linkage"
        );
        try consequenceExecutor.recordStandingPenaltyInput(
            AVADataTypes.Role.Panel,
            penaltyId,
            goodFaithChallengeId,
            AVADataTypes.StandingPenaltyKind.AcademicFraud,
            "review-procedure-weight",
            -5,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://p1-good-faith-penalty"
        ) {
            revert("good-faith failed challenge created misconduct standing input");
        } catch {}

        (, uint256 unrelatedUpheldChallengeId,) = _createResolvedChallengeForSubject(
            REVIEWER_SUBJECT,
            "p1-unrelated-upheld-linkage",
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded
        );
        try consequenceExecutor.recordStandingPenaltyInput(
            AVADataTypes.Role.Panel,
            penaltyId,
            unrelatedUpheldChallengeId,
            AVADataTypes.StandingPenaltyKind.IrresponsibleReview,
            "review-procedure-weight",
            -5,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://p1-unrelated-upheld-penalty"
        ) {
            revert("standing penalty accepted unrelated upheld challenge");
        } catch {}

        (uint256 challengerPenaltyId, uint256 challengerEvidenceId) =
            _createM423PenaltyConsequence(CHALLENGER_SUBJECT, "p1-challenger-penalty");
        uint256 maliciousChallengeId = _fileAndScreenChallenge("p1-malicious-linkage");
        stateMachine.resolveChallenge(
            AVADataTypes.Role.Panel,
            maliciousChallengeId,
            AVADataTypes.ChallengeOutcome.MaliciousOrFabricated,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://p1-malicious-linkage"
        );
        try consequenceExecutor.recordStandingPenaltyInput(
            AVADataTypes.Role.Panel,
            challengerPenaltyId,
            maliciousChallengeId,
            AVADataTypes.StandingPenaltyKind.NegligentChallenge,
            "challenge-integrity-standing",
            -5,
            challengerEvidenceId,
            keccak256("panel-authority"),
            "ipfs://p1-wrong-outcome-penalty"
        ) {
            revert("negligent penalty accepted malicious outcome");
        } catch {}

        uint256 negligentChallengeId = _fileAndScreenChallenge("p1-negligent-linkage");
        stateMachine.resolveChallenge(
            AVADataTypes.Role.Panel,
            negligentChallengeId,
            AVADataTypes.ChallengeOutcome.Negligent,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://p1-negligent-linkage"
        );
        uint256 negligentInputId = consequenceExecutor.recordStandingPenaltyInput(
            AVADataTypes.Role.Panel,
            challengerPenaltyId,
            negligentChallengeId,
            AVADataTypes.StandingPenaltyKind.NegligentChallenge,
            "challenge-integrity-standing",
            -5,
            challengerEvidenceId,
            keccak256("panel-authority"),
            "ipfs://p1-negligent-penalty"
        );
        require(
            consequenceExecutor.getStandingPenaltyInput(negligentInputId).challengeOutcome
                == AVADataTypes.ChallengeOutcome.Negligent,
            "negligent outcome not recorded"
        );

        (uint256 authorPenaltyId, uint256 authorEvidenceId) =
            _createM423PenaltyConsequence(keccak256("author-subject"), "p1-wrong-challenger-subject");
        try consequenceExecutor.recordStandingPenaltyInput(
            AVADataTypes.Role.Panel,
            authorPenaltyId,
            maliciousChallengeId,
            AVADataTypes.StandingPenaltyKind.MaliciousOrFabricatedChallenge,
            "author-integrity-standing",
            -5,
            authorEvidenceId,
            keccak256("panel-authority"),
            "ipfs://p1-wrong-challenger-subject"
        ) {
            revert("malicious challenge penalty accepted wrong challenger subject");
        } catch {}
    }

    function testNoPublicationDecisionOrManuscriptMeritSelectorsExist() public {
        _assertNoSelector(address(stateMachine), "acceptManuscript(uint256)");
        _assertNoSelector(address(stateMachine), "rejectManuscript(uint256)");
        _assertNoSelector(address(stateMachine), "setManuscriptMerit(uint256,uint256)");
        _assertNoSelector(address(stateMachine), "increaseAcceptanceProbability(uint256)");
        _assertNoSelector(address(stateMachine), "scoreManuscriptMerit(uint256)");
        _assertNoSelector(address(stateMachine), "validateScientificTruth(uint256)");
        _assertNoSelector(address(stateMachine), "executeQueue(uint256)");
        _assertNoSelector(address(stateMachine), "setReviewerLeniency(uint256,uint256)");
        _assertNoSelector(address(consequenceExecutor), "grantPublicationPriority(uint256)");
        _assertNoSelector(address(consequenceExecutor), "executeSanction(uint256)");
        _assertNoSelector(address(consequenceExecutor), "mintReward(uint256)");
        _assertNoSelector(address(consequenceExecutor), "transferPayment(uint256)");
        _assertNoSelector(address(consequenceExecutor), "payStablecoin(uint256)");
        _assertNoSelector(address(consequenceExecutor), "transferToken(uint256)");
        _assertNoSelector(address(consequenceExecutor), "executeQueue(uint256)");
        _assertNoSelector(address(consequenceExecutor), "grantServiceEntitlement(uint256)");
        _assertNoSelector(address(consequenceExecutor), "boostManuscriptScore(uint256)");
        _assertNoSelector(address(standingRegistry), "setPublicPrestige(uint256,uint256)");
        _assertNoSelector(address(standingRegistry), "grantServiceEntitlement(uint256)");
        _assertNoSelector(address(standingRegistry), "mintReward(uint256)");
        _assertNoSelector(address(standingRegistry), "transferToken(uint256)");
        _assertNoSelector(address(standingRegistry), "boostManuscriptScore(uint256)");
        _assertNoSelector(address(allocationExecutor), "grantPublicationPriority(uint256)");
        _assertNoSelector(address(allocationExecutor), "boostManuscriptScore(uint256)");
        _assertNoSelector(address(allocationExecutor), "increaseAcceptanceProbability(uint256)");
        _assertNoSelector(address(allocationExecutor), "setReviewerLeniency(uint256,uint256)");
        _assertNoSelector(address(stateMachine), "revealIdentity(uint256)");
        _assertNoSelector(address(stateMachine), "revealEvidence(uint256)");
        _assertNoSelector(address(disclosureRegistry), "revealIdentity(uint256)");
        _assertNoSelector(address(disclosureRegistry), "revealEvidence(uint256)");
        _assertNoSelector(address(disclosureRegistry), "decryptEvidence(uint256)");
        _assertNoSelector(address(evidenceRegistry), "decryptEvidence(uint256)");
        _assertNoSelector(address(evidenceRegistry), "discloseReviewerIdentity(uint256)");
        _assertNoSelector(address(evidenceRegistry), "revealIdentity(uint256)");
        _assertNoSelector(address(allocationExecutor), "transferToken(uint256)");
        _assertNoSelector(address(allocationExecutor), "payStablecoin(uint256)");
        _assertNoSelector(address(allocationExecutor), "transferStablecoin(uint256)");
        _assertNoSelector(address(allocationExecutor), "executeQueue(uint256)");
        _assertNoSelector(address(disclosurePolicyModule), "revealIdentity(uint256)");
        _assertNoSelector(address(disclosurePolicyModule), "decryptEvidence(uint256)");
        _assertNoSelector(address(disclosurePolicyModule), "discloseReviewerIdentity(uint256)");
        _assertNoSelector(address(allocationAdapter), "transferPayment(uint256)");
        _assertNoSelector(address(allocationAdapter), "grantPublicationPriority(uint256)");
        _assertNoSelector(address(allocationAdapter), "executeQueue(uint256)");
        _assertNoSelector(address(rulePackageRegistry), "acceptManuscript(uint256)");
        _assertNoSelector(address(rulePackageRegistry), "validateScientificTruth(uint256)");
        _assertNoSelector(address(attributionModule), "revealIdentity(uint256)");
        _assertNoSelector(address(verificationModule), "scoreManuscriptMerit(uint256)");
        _assertNoSelector(address(verificationModule), "validateScientificTruth(uint256)");
        _assertNoSelector(address(transitionRuleModule), "decideAcceptance(uint256)");
        _assertNoSelector(address(consequenceAdapter), "executeSanction(uint256)");
        _assertNoSelector(address(consequenceAdapter), "transferPayment(uint256)");
        _assertNoSelector(address(consequenceAdapter), "mintReward(uint256)");
        _assertNoSelector(address(rewardAdapter), "transferStablecoin(uint256)");
        _assertNoSelector(address(rewardAdapter), "transferToken(uint256)");
        _assertNoSelector(address(rewardAdapter), "payStablecoin(uint256)");
        _assertNoSelector(address(priorityAdapter), "grantPublicationPriority(uint256)");
        _assertNoSelector(address(priorityAdapter), "boostManuscriptScore(uint256)");
        _assertNoSelector(address(priorityAdapter), "setReviewerLeniency(uint256,uint256)");
        _assertNoSelector(address(priorityAdapter), "executeQueue(uint256)");
        _assertNoSelector(address(penaltyAdapter), "executeSanction(uint256)");
        _assertNoSelector(address(penaltyAdapter), "transferToken(uint256)");
        _assertNoSelector(address(restorationAdapter), "mintReward(uint256)");
        _assertNoSelector(address(restorationAdapter), "transferStablecoin(uint256)");
        _assertNoSelector(address(valueSettlementExecutor), "acceptManuscript(uint256)");
        _assertNoSelector(address(valueSettlementExecutor), "rejectManuscript(uint256)");
        _assertNoSelector(address(valueSettlementExecutor), "setManuscriptMerit(uint256,uint256)");
        _assertNoSelector(address(valueSettlementExecutor), "grantPublicationPriority(uint256)");
        _assertNoSelector(address(valueSettlementExecutor), "setReviewerLeniency(uint256,uint256)");
        _assertNoSelector(address(valueSettlementExecutor), "executeQueue(uint256)");
        _assertNoSelector(address(disclosureAccessExecutor), "revealIdentity(uint256)");
        _assertNoSelector(address(disclosureAccessExecutor), "revealEvidence(uint256)");
        _assertNoSelector(address(disclosureAccessExecutor), "decryptEvidence(uint256)");
        _assertNoSelector(address(externalOperationRegistry), "acceptManuscript(uint256)");
        _assertNoSelector(address(externalOperationRegistry), "rejectManuscript(uint256)");
        _assertNoSelector(address(externalOperationRegistry), "setManuscriptMerit(uint256,uint256)");
        _assertNoSelector(address(externalOperationRegistry), "grantPublicationPriority(uint256)");
        _assertNoSelector(address(externalOperationRegistry), "executeQueue(uint256)");
        _assertNoSelector(address(standingCredentialRegistry), "mintReward(uint256)");
        _assertNoSelector(address(standingCredentialRegistry), "transferPayment(uint256)");
        _assertNoSelector(address(standingCredentialRegistry), "mintPriorityToken(uint256)");
        _assertNoSelector(address(standingCredentialRegistry), "grantPublicationPriority(uint256)");
        _assertNoSelector(address(standingCredentialRegistry), "acceptManuscript(uint256)");
        _assertNoSelector(address(standingCredentialRegistry), "rejectManuscript(uint256)");
        _assertNoSelector(address(standingCredentialRegistry), "setManuscriptMerit(uint256,uint256)");
    }

    function _registerAuthorManuscript() internal returns (uint256) {
        return
            stateMachine.registerManuscript(AVADataTypes.Role.Author, keccak256("manuscript-ref"), "ipfs://manuscript");
    }

    function _registerDisclosurePolicy(string memory label) internal returns (uint256) {
        return disclosureRegistry.registerDisclosurePolicy(AVADataTypes.Role.Editor, label, string.concat("ipfs://", label));
    }

    function _createChallengeableReviewState() internal returns (uint256) {
        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("review-for-challenge"),
            "ipfs://review-for-challenge",
            "review-service-occurrence",
            0
        );
        uint256 reviewContributionId = reviewerActor.registerReviewContribution(
            stateMachine, AVADataTypes.Role.Reviewer, manuscriptId, REVIEWER_SUBJECT, evidenceId, 0
        );
        uint256 recognisedStateId =
            stateMachine.provisionallyRecogniseReview(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);
        stateMachine.openReviewChallengeWindow(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);
        return recognisedStateId;
    }

    function _fileAndScreenChallenge(string memory seed) internal returns (uint256) {
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256(bytes(seed)),
            string.concat("ipfs://", seed),
            "review-quality-challenge",
            0
        );
        uint256 challengeId = challengerActor.fileChallenge(
            stateMachine, AVADataTypes.Role.Challenger, recognisedStateId, CHALLENGER_SUBJECT, challengeEvidenceId, 0
        );
        stateMachine.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        return challengeId;
    }

    function _createM69ChallengeResolutionTransition(
        Actor actor,
        bytes32 challengerSubjectId,
        string memory seed,
        AVADataTypes.ChallengeOutcome outcome
    ) internal returns (uint256 transitionId) {
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 challengeEvidenceId = actor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256(bytes(seed)),
            string.concat("ipfs://", seed, "-challenge-evidence"),
            "review-quality-challenge",
            0
        );
        uint256 challengeId = actor.fileChallenge(
            stateMachine, AVADataTypes.Role.Challenger, recognisedStateId, challengerSubjectId, challengeEvidenceId, 0
        );
        stateMachine.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        stateMachine.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            outcome,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            string.concat("ipfs://", seed, "-resolution")
        );
        transitionId = stateMachine.getChallenge(challengeId).lastTransitionId;
    }

    function _createDowngradedRecognisedState() internal returns (uint256 recognisedStateId, uint256 evidenceId) {
        recognisedStateId = _createChallengeableReviewState();
        evidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256("standing-downgrade-evidence"),
            "ipfs://standing-downgrade",
            "review-quality-challenge",
            0
        );
        uint256 challengeId = challengerActor.fileChallenge(
            stateMachine, AVADataTypes.Role.Challenger, recognisedStateId, CHALLENGER_SUBJECT, evidenceId, 0
        );
        stateMachine.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        stateMachine.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            keccak256("panel-authority"),
            "ipfs://standing-basis"
        );
    }

    function _registerRecognisedStateForStatus(
        AVADataTypes.RecognisedStateStatus status,
        uint256 evidenceId,
        string memory seed
    ) internal returns (uint256) {
        return _registerRecognisedStateForWorkflowStatus(DEFAULT_WORKFLOW, status, evidenceId, seed);
    }

    function _registerM51DefaultEvidence(string memory seed) internal returns (uint256) {
        return reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            keccak256(bytes(seed)),
            string.concat("ipfs://", seed, "-evidence"),
            "m51-evidence",
            0
        );
    }

    function _expireM51EvidenceReceipt(uint256 evidenceReceiptId, string memory seed) internal returns (uint256) {
        return reviewerActor.recordEvidenceLifecycleHook(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            evidenceReceiptId,
            AVADataTypes.EvidenceLifecycleKind.ExpiryReady,
            0,
            keccak256(bytes(seed)),
            string.concat("ipfs://", seed)
        );
    }

    function _assertM51ReplacementLifecycleRejected(
        uint256 evidenceReceiptId,
        uint256 replacementEvidenceReceiptId,
        string memory message
    ) internal {
        try reviewerActor.recordEvidenceLifecycleHook(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            evidenceReceiptId,
            AVADataTypes.EvidenceLifecycleKind.ReplacementReady,
            replacementEvidenceReceiptId,
            keccak256(abi.encodePacked(message)),
            "ipfs://m51-rejected-replacement"
        ) {
            revert(message);
        } catch {}
    }

    function _assertM51InactiveEvidenceRejectedForCredentialAuditAndExternal(
        uint256 recognisedStateId,
        uint256 inactiveEvidenceId
    ) internal {
        uint256 computationEvidenceId = _registerM51DefaultEvidence("m51-credential-computation");
        uint256 computationId = standingRegistry.recordStandingComputationReadiness(
            AVADataTypes.Role.Panel,
            AVADataTypes.StandingComputationContext({
                recognisedStateId: recognisedStateId,
                subjectId: REVIEWER_SUBJECT,
                dimension: "review-procedure-weight",
                vectorKey: _m422VectorKey(),
                currentValue: 45,
                delta: 0,
                effectiveAt: block.timestamp,
                epoch: 1,
                sourceRecordSetHash: keccak256("m51-standing-source-set"),
                computationRuleHash: _m422ComputationRuleHash(),
                reversible: true,
                fieldKey: keccak256("verification-field"),
                evidenceReceiptId: computationEvidenceId,
                authorityId: keccak256("panel-authority"),
                actor: address(this)
            }),
            "ipfs://m51-standing-computation"
        );
        _expireM51EvidenceReceipt(computationEvidenceId, "m51-credential-computation-expiry");
        uint256 nextCredentialId = standingCredentialRegistry.nextStandingCredentialId();
        try standingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m422CredentialInputForComputation(computationId, block.timestamp + 7 days, "ipfs://m51-credential")
        ) {
            revert("credential issued from inactive evidence");
        } catch {}
        require(standingCredentialRegistry.nextStandingCredentialId() == nextCredentialId, "inactive evidence wrote credential");

        uint256 nextAttestationId = auditModule.nextAttestationId();
        try auditModule.recordAttestation(
            AVADataTypes.Role.Panel,
            DEFAULT_WORKFLOW,
            AVADataTypes.Action.RecordAttestation,
            keccak256("m51-attestation-object"),
            inactiveEvidenceId,
            keccak256("m51-attestation-hash"),
            keccak256("panel-authority"),
            "workflow-attestation",
            "ipfs://m51-attestation"
        ) {
            revert("attestation accepted inactive evidence");
        } catch {}
        require(auditModule.nextAttestationId() == nextAttestationId, "inactive evidence wrote attestation");

        uint256 nextExternalOperationId = externalOperationRegistry.nextExternalOperationId();
        try externalOperationRegistry.requestOperation(
            AVADataTypes.Role.Panel,
            DEFAULT_WORKFLOW,
            AVADataTypes.ExternalOperationKind.QueueAdjustmentIntent,
            AVADataTypes.ExternalOperationTargetKind.RecognisedState,
            recognisedStateId,
            inactiveEvidenceId,
            keccak256("panel-authority"),
            "ipfs://m51-external-operation"
        ) {
            revert("external operation accepted inactive evidence");
        } catch {}
        require(
            externalOperationRegistry.nextExternalOperationId() == nextExternalOperationId,
            "inactive evidence wrote external operation"
        );
    }

    function _registerRecognisedStateForWorkflowStatus(
        bytes32 workflowKey,
        AVADataTypes.RecognisedStateStatus status,
        uint256 evidenceId,
        string memory seed
    ) internal returns (uint256) {
        return _registerRecognisedStateForWorkflowStatusWithSubject(workflowKey, REVIEWER_SUBJECT, status, evidenceId, seed);
    }

    function _registerRecognisedStateForWorkflowStatusWithSubject(
        bytes32 workflowKey,
        bytes32 subjectId,
        AVADataTypes.RecognisedStateStatus status,
        uint256 evidenceId,
        string memory seed
    ) internal returns (uint256) {
        AVADataTypes.RecognisedStateStatus initialStatus = status == AVADataTypes.RecognisedStateStatus.Vested
            ? AVADataTypes.RecognisedStateStatus.Registered
            : status;
        if (
            status == AVADataTypes.RecognisedStateStatus.Downgraded
                || status == AVADataTypes.RecognisedStateStatus.Voided
                || status == AVADataTypes.RecognisedStateStatus.Restored
        ) {
            initialStatus = AVADataTypes.RecognisedStateStatus.Challengeable;
        }
        uint256 recognisedStateId = stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            keccak256(bytes(seed)),
            subjectId,
            evidenceId,
            0,
            EDITOR_AUTHORITY,
            initialStatus
        );
        if (status == AVADataTypes.RecognisedStateStatus.Vested) {
            stateMachine.transitionRecognisedState(
                AVADataTypes.Role.Panel, recognisedStateId, status, keccak256("panel-authority"), "ipfs://test-transition"
            );
        } else if (
            status == AVADataTypes.RecognisedStateStatus.Downgraded
                || status == AVADataTypes.RecognisedStateStatus.Voided
        ) {
            uint256 challengeId = challengerActor.fileChallenge(
                stateMachine, AVADataTypes.Role.Challenger, workflowKey, recognisedStateId, CHALLENGER_SUBJECT, evidenceId, 0
            );
            stateMachine.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
            stateMachine.resolveChallenge(
                AVADataTypes.Role.Panel,
                challengeId,
                AVADataTypes.ChallengeOutcome.Upheld,
                status,
                keccak256("panel-authority"),
                string.concat("ipfs://", seed, "-challenge-resolution")
            );
        } else if (status == AVADataTypes.RecognisedStateStatus.Restored) {
            uint256 challengeId = challengerActor.fileChallenge(
                stateMachine, AVADataTypes.Role.Challenger, workflowKey, recognisedStateId, CHALLENGER_SUBJECT, evidenceId, 0
            );
            stateMachine.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
            stateMachine.resolveChallenge(
                AVADataTypes.Role.Panel,
                challengeId,
                AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
                AVADataTypes.RecognisedStateStatus.Challengeable,
                keccak256("panel-authority"),
                string.concat("ipfs://", seed, "-good-faith-resolution")
            );
            stateMachine.applyRestoration(
                AVADataTypes.Role.Panel, challengeId, keccak256("panel-authority"), string.concat("ipfs://", seed, "-restoration")
            );
        }
        return recognisedStateId;
    }

    function _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
        bytes32 workflowKey,
        AVADataTypes.RecognisedStateStatus status,
        string memory seed
    ) internal returns (uint256 recognisedStateId, uint256 evidenceId) {
        evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256(abi.encodePacked(seed, "-evidence")),
            string.concat("ipfs://", seed, "-evidence"),
            "workflow-bound-evidence",
            0
        );
        recognisedStateId = _registerRecognisedStateForWorkflowStatus(workflowKey, status, evidenceId, seed);
    }

    function _isDownstreamEligibleStatus(AVADataTypes.RecognisedStateStatus status) internal pure returns (bool) {
        return status == AVADataTypes.RecognisedStateStatus.Vested || status == AVADataTypes.RecognisedStateStatus.Restored
            || status == AVADataTypes.RecognisedStateStatus.Downgraded
            || status == AVADataTypes.RecognisedStateStatus.Voided;
    }

    function _valueContext(
        uint256 recognisedStateId,
        bytes32 subjectId,
        uint256 amountOrUnits,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string memory uri,
        bytes32 executionReference,
        address asset,
        address payer,
        AVADataTypes.ValueExecutionMode mode
    ) internal view returns (AVADataTypes.ValueExecutionContext memory) {
        return AVADataTypes.ValueExecutionContext({
            recognisedStateId: recognisedStateId,
            asset: asset,
            payer: payer,
            recipientSubjectId: subjectId,
            amount: amountOrUnits,
            mode: mode,
            settlementKind: _defaultSettlementKindForMode(mode),
            executionReference: executionReference,
            authorityId: authorityId,
            evidenceReceiptId: evidenceReceiptId,
            uri: uri,
            actor: address(this)
        });
    }

    function _registerM421ExecutionWorkflow(bytes32 workflowKey, string memory uri) internal {
        _registerM421ExecutionWorkflowWithDisclosureExecution(workflowKey, disclosureExecutionModule, uri);
    }

    function _registerM421ExecutionWorkflowWithDisclosureExecution(
        bytes32 workflowKey,
        IDisclosureExecutionModule executionModule,
        string memory uri
    ) internal {
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            new ClaimEscrowRecordValueAdapter(),
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            executionModule,
            1,
            keccak256("ava-m4-21-compatible"),
            false,
            uri
        );
    }

    function _m421FundedToken(uint256 amount) internal returns (MockERC20 token) {
        token = new MockERC20("Mock Stablecoin", "MST");
        token.mint(address(this), amount);
        token.approve(address(valueSettlementExecutor), amount);
    }

    function _createM421RewardSource(
        bytes32 workflowKey,
        string memory seed,
        MockERC20 token,
        uint256 amount,
        AVADataTypes.ValueExecutionMode mode
    ) internal returns (uint256 recordId) {
        (uint256 recognisedStateId, uint256 evidenceId) = _createM421EligibleState(workflowKey, seed);
        AVADataTypes.ValueExecutionContext memory context;
        context.recognisedStateId = recognisedStateId;
        context.asset = address(token);
        context.payer = address(this);
        context.recipientSubjectId = REVIEWER_SUBJECT;
        context.amount = amount;
        context.mode = mode;
        context.settlementKind = _defaultSettlementKindForMode(mode);
        context.executionReference = bytes32(evidenceId);
        context.authorityId = keccak256("executor-authority");
        context.evidenceReceiptId = evidenceId;
        context.uri = "ipfs://m421-reward-source";
        context.actor = address(this);
        recordId = allocationExecutor.recordRewardValueWithExecution(
            AVADataTypes.Role.ProtocolExecutor,
            context
        );
    }

    function _createM69RewardSource(
        bytes32 workflowKey,
        bytes32 recipientSubjectId,
        string memory seed,
        MockERC20 token,
        uint256 amount,
        AVADataTypes.ValueExecutionMode mode
    ) internal returns (uint256 recordId) {
        (uint256 recognisedStateId, uint256 evidenceId) = _createM421EligibleState(workflowKey, seed);
        AVADataTypes.ValueExecutionContext memory context;
        context.recognisedStateId = recognisedStateId;
        context.asset = address(token);
        context.payer = address(this);
        context.recipientSubjectId = recipientSubjectId;
        context.amount = amount;
        context.mode = mode;
        context.settlementKind = _defaultSettlementKindForMode(mode);
        context.executionReference = bytes32(evidenceId);
        context.authorityId = keccak256("executor-authority");
        context.evidenceReceiptId = evidenceId;
        context.uri = string.concat("ipfs://", seed, "-reward-source");
        context.actor = address(this);
        recordId = allocationExecutor.recordRewardValueWithExecution(AVADataTypes.Role.ProtocolExecutor, context);
    }

    function _createM425AuthorRewardSettlement(
        bytes32 workflowKey,
        string memory seed,
        MockERC20 token,
        uint256 amount
    ) internal returns (uint256 recordId, uint256 settlementId) {
        (uint256 recognisedStateId, uint256 evidenceId) = _createM421EligibleState(workflowKey, seed);
        AVADataTypes.ValueExecutionContext memory context;
        context.recognisedStateId = recognisedStateId;
        context.asset = address(token);
        context.payer = address(this);
        context.recipientSubjectId = keccak256("author-subject");
        context.amount = amount;
        context.mode = AVADataTypes.ValueExecutionMode.Claim;
        context.settlementKind = AVADataTypes.ValueSettlementKind.TokenTransfer;
        context.executionReference = bytes32(evidenceId);
        context.authorityId = keccak256("executor-authority");
        context.evidenceReceiptId = evidenceId;
        context.uri = string.concat("ipfs://", seed, "-source");
        context.actor = address(this);
        recordId = allocationExecutor.recordRewardValueWithExecution(AVADataTypes.Role.ProtocolExecutor, context);
        settlementId = valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            recordId,
            keccak256("executor-authority"),
            string.concat("ipfs://", seed, "-settlement")
        );
    }

    function _createM421RecordOnlyRewardSource(bytes32 workflowKey, string memory seed) internal returns (uint256 recordId) {
        (uint256 recognisedStateId, uint256 evidenceId) = _createM421EligibleState(workflowKey, seed);
        recordId = allocationExecutor.recordRewardValue(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("executor-authority"),
            string.concat("ipfs://", seed, "-record-only")
        );
    }

    function _createM421PrioritySource(
        bytes32 workflowKey,
        string memory seed,
        MockPriorityToken priorityToken,
        uint256 amount,
        AVADataTypes.ValueExecutionMode mode,
        AVADataTypes.ValueSettlementKind settlementKind
    ) internal returns (uint256 recordId) {
        (uint256 recognisedStateId, uint256 evidenceId) = _createM421EligibleState(workflowKey, seed);
        AVADataTypes.ValueExecutionContext memory context;
        context.recognisedStateId = recognisedStateId;
        context.asset = address(priorityToken);
        context.payer = address(this);
        context.recipientSubjectId = REVIEWER_SUBJECT;
        context.amount = amount;
        context.mode = mode;
        context.settlementKind = settlementKind;
        context.executionReference = bytes32(evidenceId);
        context.authorityId = keccak256("executor-authority");
        context.evidenceReceiptId = evidenceId;
        context.uri = "ipfs://m421-priority-source";
        context.actor = address(this);
        recordId = allocationExecutor.recordAdministrativePriorityWithExecution(
            AVADataTypes.Role.ProtocolExecutor,
            context
        );
    }

    function _defaultSettlementKindForMode(AVADataTypes.ValueExecutionMode mode)
        internal
        pure
        returns (AVADataTypes.ValueSettlementKind)
    {
        if (mode == AVADataTypes.ValueExecutionMode.RecordOnly) return AVADataTypes.ValueSettlementKind.None;
        if (mode == AVADataTypes.ValueExecutionMode.Claim) return AVADataTypes.ValueSettlementKind.TokenTransfer;
        if (mode == AVADataTypes.ValueExecutionMode.Escrow) return AVADataTypes.ValueSettlementKind.EscrowDeposit;
        return AVADataTypes.ValueSettlementKind.None;
    }

    function _createM421EligibleState(bytes32 workflowKey, string memory seed)
        internal
        returns (uint256 recognisedStateId, uint256 evidenceId)
    {
        return _createM421EligibleStateForSubject(workflowKey, REVIEWER_SUBJECT, seed);
    }

    function _createM421EligibleStateForSubject(bytes32 workflowKey, bytes32 subjectId, string memory seed)
        internal
        returns (uint256 recognisedStateId, uint256 evidenceId)
    {
        evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256(bytes(seed)),
            string.concat("ipfs://", seed, "-evidence"),
            "m421-execution-reference",
            0
        );
        recognisedStateId = _registerRecognisedStateForWorkflowStatusWithSubject(
            workflowKey, subjectId, AVADataTypes.RecognisedStateStatus.Vested, evidenceId, seed
        );
    }

    function _createResolvedChallengeForSubject(
        bytes32 subjectId,
        string memory seed,
        AVADataTypes.ChallengeOutcome outcome,
        AVADataTypes.RecognisedStateStatus toStatus
    ) internal returns (uint256 recognisedStateId, uint256 challengeId, uint256 evidenceId) {
        evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            keccak256(bytes(string.concat(seed, "-state-evidence"))),
            string.concat("ipfs://", seed, "-state-evidence"),
            "challenge-linked-penalty-state",
            0
        );
        recognisedStateId = stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            keccak256(bytes(string.concat(seed, "-state"))),
            subjectId,
            evidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Challengeable
        );
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            DEFAULT_WORKFLOW,
            keccak256(bytes(string.concat(seed, "-challenge-evidence"))),
            string.concat("ipfs://", seed, "-challenge-evidence"),
            "challenge-linked-penalty-outcome",
            0
        );
        challengeId = challengerActor.fileChallenge(
            stateMachine, AVADataTypes.Role.Challenger, recognisedStateId, CHALLENGER_SUBJECT, challengeEvidenceId, 0
        );
        stateMachine.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        stateMachine.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            outcome,
            toStatus,
            keccak256("panel-authority"),
            string.concat("ipfs://", seed, "-resolution")
        );
    }

    function _createM422StandingComputationRecord(string memory seed, int256 currentValue)
        internal
        returns (uint256 computationId)
    {
        (uint256 recognisedStateId, uint256 evidenceId) = _createM421EligibleState(DEFAULT_WORKFLOW, seed);
        AVADataTypes.StandingComputationContext memory context;
        context.recognisedStateId = recognisedStateId;
        context.subjectId = REVIEWER_SUBJECT;
        context.dimension = "review-procedure-weight";
        context.vectorKey = _m422VectorKey();
        context.currentValue = currentValue;
        context.delta = 0;
        context.effectiveAt = block.timestamp;
        context.epoch = standingRegistry.nextStandingComputationRecordId();
        context.sourceRecordSetHash = keccak256(abi.encode(seed, recognisedStateId, evidenceId, REVIEWER_SUBJECT));
        context.computationRuleHash = _m422ComputationRuleHash();
        context.reversible = true;
        context.fieldKey = keccak256("review-service-field");
        context.evidenceReceiptId = evidenceId;
        context.authorityId = keccak256("panel-authority");
        context.actor = address(this);
        computationId = standingRegistry.recordStandingComputationReadiness(
            AVADataTypes.Role.Panel, context, string.concat("ipfs://", seed, "-standing-computation")
        );
    }

    function _createM423StandingComputationRecord(bytes32 workflowKey, string memory seed, int256 currentValue)
        internal
        returns (uint256 computationId)
    {
        (uint256 recognisedStateId, uint256 evidenceId) = _createM421EligibleState(workflowKey, seed);
        AVADataTypes.StandingComputationContext memory context;
        context.recognisedStateId = recognisedStateId;
        context.subjectId = REVIEWER_SUBJECT;
        context.dimension = "review-procedure-weight";
        context.vectorKey = _m422VectorKey();
        context.currentValue = currentValue;
        context.delta = 0;
        context.effectiveAt = block.timestamp;
        context.epoch = standingRegistry.nextStandingComputationRecordId();
        context.sourceRecordSetHash = keccak256(abi.encode(seed, recognisedStateId, evidenceId, REVIEWER_SUBJECT));
        context.computationRuleHash = _m422ComputationRuleHash();
        context.reversible = true;
        context.fieldKey = keccak256("review-service-field");
        context.evidenceReceiptId = evidenceId;
        context.authorityId = keccak256("panel-authority");
        context.actor = address(this);
        computationId = standingRegistry.recordStandingComputationReadiness(
            AVADataTypes.Role.Panel, context, string.concat("ipfs://", seed, "-standing-computation")
        );
    }

    function _createM423PenaltyConsequence(bytes32 subjectId, string memory seed)
        internal
        returns (uint256 penaltyId, uint256 evidenceId)
    {
        (uint256 recognisedStateId, uint256 stateEvidenceId) =
            _createM421EligibleStateForSubject(DEFAULT_WORKFLOW, subjectId, seed);
        evidenceId = stateEvidenceId;
        penaltyId = consequenceExecutor.recordPenalty(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            subjectId,
            evidenceId,
            keccak256("panel-authority"),
            string.concat("ipfs://", seed, "-penalty")
        );
    }

    function _createM425ClawbackPenaltySource(
        bytes32 workflowKey,
        string memory seed,
        MockERC20 token,
        uint256 amount
    ) internal returns (uint256 penaltyId) {
        (uint256 recognisedStateId, uint256 evidenceId) = _createM421EligibleState(workflowKey, seed);
        penaltyId = consequenceExecutor.recordPenaltyWithExecution(
            AVADataTypes.Role.Panel,
            AVADataTypes.ValueExecutionContext({
                recognisedStateId: recognisedStateId,
                asset: address(token),
                payer: address(this),
                recipientSubjectId: REVIEWER_SUBJECT,
                amount: amount,
                mode: AVADataTypes.ValueExecutionMode.Claim,
                settlementKind: AVADataTypes.ValueSettlementKind.ClawbackTransfer,
                executionReference: bytes32(evidenceId),
                authorityId: keccak256("panel-authority"),
                evidenceReceiptId: evidenceId,
                uri: string.concat("ipfs://", seed, "-clawback"),
                actor: address(this)
            })
        );
    }

    function _assertM423PenaltyChainRecords(
        uint256 fraudInputId,
        uint256 reviewInputId,
        uint256 maliciousInputId,
        uint256 restrictionId
    ) internal view {
        AVADataTypes.StandingPenaltyInputRecord memory fraudInput =
            consequenceExecutor.getStandingPenaltyInput(fraudInputId);
        AVADataTypes.StandingPenaltyInputRecord memory reviewInput =
            consequenceExecutor.getStandingPenaltyInput(reviewInputId);
        AVADataTypes.StandingPenaltyInputRecord memory maliciousInput =
            consequenceExecutor.getStandingPenaltyInput(maliciousInputId);
        require(fraudInput.penaltyKind == AVADataTypes.StandingPenaltyKind.AcademicFraud, "fraud kind collapsed");
        require(reviewInput.penaltyKind == AVADataTypes.StandingPenaltyKind.IrresponsibleReview, "review kind collapsed");
        require(
            maliciousInput.penaltyKind == AVADataTypes.StandingPenaltyKind.MaliciousOrFabricatedChallenge,
            "malicious kind collapsed"
        );
        require(fraudInput.delta < reviewInput.delta && reviewInput.delta > maliciousInput.delta, "penalty severities collapsed");
        require(
            consequenceExecutor.getEligibilityRestriction(restrictionId).restrictionKind
                == AVADataTypes.EligibilityRestrictionKind.ChallengeIntake,
            "eligibility restriction missing"
        );
        require(standingRegistry.nextStandingUpdateId() == 1, "penalty directly updated standing");
        require(allocationExecutor.nextAllocationExecutionId() == 1, "penalty directly executed allocation");
        _assertNoSelector(address(consequenceExecutor), "acceptManuscript(uint256)");
        _assertNoSelector(address(valueSettlementExecutor), "setManuscriptMerit(uint256,uint256)");
    }

    function _assertM424InvalidSettlementDoesNotSuspend(
        uint256 credentialId,
        AVADataTypes.ExecutionSourceType sourceType,
        uint256 sourceRecordId,
        uint256 settlementId,
        string memory message
    ) internal {
        try standingCredentialRegistry.recordStandingRelevantSettlement(
            AVADataTypes.Role.Panel,
            credentialId,
            AVADataTypes.StandingRelevantSettlementKind.RewardExecution,
            sourceType,
            sourceRecordId,
            settlementId,
            keccak256("panel-authority"),
            "ipfs://m424-invalid-impact"
        ) {
            revert(message);
        } catch {}
        require(standingCredentialRegistry.isCredentialActive(credentialId), "invalid settlement suspended credential");
        require(_m422CredentialProves(credentialId, 40), "invalid settlement disabled proof");
    }

    function _assertM69InvalidSettlementBoundSuspensionDoesNotDisable(
        uint256 credentialId,
        AVADataTypes.StandingRelevantSettlementKind kind,
        AVADataTypes.ExecutionSourceType sourceType,
        uint256 sourceRecordId,
        uint256 settlementId,
        string memory message
    ) internal {
        try zkStandingCredentialRegistry.recordSettlementBoundSuspension(
            AVADataTypes.Role.Panel,
            credentialId,
            kind,
            sourceType,
            sourceRecordId,
            settlementId,
            keccak256("panel-authority"),
            "ipfs://m69-invalid-settlement-suspension"
        ) {
            revert(message);
        } catch {}
        require(zkStandingCredentialRegistry.isCredentialActive(credentialId), "invalid settlement disabled zk credential");
    }

    function _assertM69SettlementSuspensionRejectsInvalidBindings(
        uint256 credentialId,
        bytes32 workflowKey,
        bytes32 subjectCommitment,
        MockERC20 token,
        uint256 sourceId,
        uint256 settlementId
    ) internal {
        _assertM69InvalidSettlementBoundSuspensionDoesNotDisable(
            credentialId,
            AVADataTypes.StandingRelevantSettlementKind.RewardExecution,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            settlementId + 1000,
            "unknown settlement suspended zk credential"
        );

        uint256 otherSourceId = _createM69RewardSource(
            workflowKey, subjectCommitment, "m69-zk-other-source", token, 3, AVADataTypes.ValueExecutionMode.Claim
        );
        uint256 otherSettlementId = valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            otherSourceId,
            keccak256("executor-authority"),
            "ipfs://m69-zk-other-settlement"
        );
        _assertM69InvalidSettlementBoundSuspensionDoesNotDisable(
            credentialId,
            AVADataTypes.StandingRelevantSettlementKind.RewardExecution,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            otherSettlementId,
            "wrong source settlement suspended zk credential"
        );

        bytes32 otherSubject = _subjectCommitmentForSecret(9);
        Actor otherSubjectActor = new Actor();
        roleRegistry.assignRole(
            address(otherSubjectActor), AVADataTypes.Role.Challenger, otherSubject, "ipfs://m69-zk-other-subject"
        );
        uint256 otherSubjectSourceId = _createM69RewardSource(
            workflowKey, otherSubject, "m69-zk-other-subject-source", token, 4, AVADataTypes.ValueExecutionMode.Claim
        );
        uint256 otherSubjectSettlementId = valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            otherSubjectSourceId,
            keccak256("executor-authority"),
            "ipfs://m69-zk-other-subject-settlement"
        );
        _assertM69InvalidSettlementBoundSuspensionDoesNotDisable(
            credentialId,
            AVADataTypes.StandingRelevantSettlementKind.RewardExecution,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            otherSubjectSourceId,
            otherSubjectSettlementId,
            "wrong subject settlement suspended zk credential"
        );

        bytes32 foreignWorkflow = keccak256("m69-zk-foreign-workflow");
        _registerM421ExecutionWorkflow(foreignWorkflow, "ipfs://m69-zk-foreign-workflow");
        uint256 foreignSourceId = _createM69RewardSource(
            foreignWorkflow, subjectCommitment, "m69-zk-foreign-source", token, 2, AVADataTypes.ValueExecutionMode.Claim
        );
        uint256 foreignSettlementId = valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            foreignSourceId,
            keccak256("executor-authority"),
            "ipfs://m69-zk-foreign-settlement"
        );
        _assertM69InvalidSettlementBoundSuspensionDoesNotDisable(
            credentialId,
            AVADataTypes.StandingRelevantSettlementKind.RewardExecution,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            foreignSourceId,
            foreignSettlementId,
            "wrong package settlement suspended zk credential"
        );
    }

    function _assertM69InvalidChallengeBoundSuspensionDoesNotDisable(
        uint256 credentialId,
        uint256 challengeTransitionId,
        string memory message
    ) internal {
        try zkStandingCredentialRegistry.recordChallengeTransitionBoundSuspension(
            AVADataTypes.Role.Panel,
            credentialId,
            challengeTransitionId,
            keccak256("panel-authority"),
            "ipfs://m69-invalid-challenge-suspension"
        ) {
            revert(message);
        } catch {}
        require(zkStandingCredentialRegistry.isCredentialActive(credentialId), "invalid challenge disabled zk credential");
    }

    function _assertM63CannotSupersedeStandingCredential(
        uint256 credentialId,
        IStandingCredentialIssuer.StandingCredentialInput memory input,
        string memory message
    ) internal {
        try standingCredentialRegistry.supersedeCredential(AVADataTypes.Role.Panel, credentialId, input) {
            revert(message);
        } catch {}
        require(standingCredentialRegistry.isCredentialActive(credentialId), "rejected supersession disabled credential");
    }

    function _issueM422StandingCredential(uint256 computationId, string memory seed, uint256 expiresAt)
        internal
        returns (uint256 credentialId)
    {
        credentialId = standingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m422CredentialInputForComputation(computationId, expiresAt, string.concat("ipfs://", seed, "-standing-credential"))
        );
    }

    function _assertM422CannotIssueFromSource(uint256 sourceId, string memory message) internal {
        try standingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m422CredentialInput(sourceId, 1, block.timestamp + 7 days, "ipfs://m422-rejected-credential")
        ) {
            revert(message);
        } catch {}
    }

    function _m422CredentialInput(
        uint256 computationId,
        uint256 epoch,
        uint256 expiresAt,
        string memory uri
    ) internal pure returns (IStandingCredentialIssuer.StandingCredentialInput memory input) {
        input = IStandingCredentialIssuer.StandingCredentialInput({
            standingComputationRecordId: computationId,
            categoryHash: keccak256("panel-visible-standing-category"),
            threshold: 40,
            lowerBound: 40,
            upperBound: 50,
            epoch: epoch,
            expiresAt: expiresAt,
            computationRuleHash: _m422ComputationRuleHash(),
            authorityId: keccak256("panel-authority"),
            uri: uri
        });
    }

    function _m422CredentialInputForComputation(
        uint256 computationId,
        uint256 expiresAt,
        string memory uri
    ) internal view returns (IStandingCredentialIssuer.StandingCredentialInput memory input) {
        AVADataTypes.StandingComputationRecord memory computation =
            standingRegistry.getStandingComputationRecord(computationId);
        input = _m422CredentialInput(computationId, computation.epoch, expiresAt, uri);
    }

    function _m54ReplacementComputationContext(
        uint256 oldComputationId,
        string memory seed,
        int256 currentValue,
        uint256 epoch
    ) internal view returns (AVADataTypes.StandingComputationContext memory context) {
        AVADataTypes.StandingComputationRecord memory oldComputation =
            standingRegistry.getStandingComputationRecord(oldComputationId);
        context.recognisedStateId = oldComputation.recognisedStateId;
        context.subjectId = oldComputation.subjectId;
        context.dimension = oldComputation.dimension;
        context.vectorKey = oldComputation.vectorKey;
        context.currentValue = currentValue;
        context.delta = currentValue - oldComputation.currentValue;
        context.effectiveAt = block.timestamp + 1;
        context.reversible = oldComputation.reversible;
        context.fieldKey = oldComputation.fieldKey;
        context.evidenceReceiptId = oldComputation.evidenceReceiptId;
        context.authorityId = keccak256("panel-authority");
        context.actor = address(this);
        context.epoch = epoch;
        context.sourceRecordSetHash = keccak256(abi.encode(seed, oldComputationId, oldComputation.sourceRecordSetHash));
        context.computationRuleHash = oldComputation.computationRuleHash;
    }

    function _m422ComputationRuleHash() internal pure returns (bytes32) {
        return keccak256("m422-standing-computation-rule-v1");
    }

    function _m422CredentialProves(uint256 credentialId, int256 threshold) internal view returns (bool) {
        return standingCredentialRegistry.credentialProves(
            credentialId, REVIEWER_SUBJECT, _m422VectorKey(), _m422CategoryHash(), threshold
        );
    }

    function _m65StandingProofInput(bytes32 workflowKey, bytes32 subjectCommitment, string memory seed)
        internal
        pure
        returns (ZKStandingComputationRegistry.StandingProofInput memory input)
    {
        input = ZKStandingComputationRegistry.StandingProofInput({
            standingComputationStatementId: 0,
            workflowKey: workflowKey,
            subjectCommitment: subjectCommitment,
            vectorKey: _m422VectorKey(),
            categoryHash: _m422CategoryHash(),
            threshold: 40,
            lowerBound: 40,
            upperBound: 50,
            epoch: 1,
            sourceRecordSetRoot: keccak256(abi.encode(seed, subjectCommitment, "source-record-set-root")),
            computationRuleHash: _m422ComputationRuleHash(),
            outputCommitmentHash: bytes32(0)
        });
    }

    function _assertM65CannotRegisterStandingProof(
        ZKStandingComputationRegistry.StandingProofInput memory input,
        IZKProofVerifier.SchnorrProof memory proof,
        string memory message
    ) internal {
        try zkStandingComputationRegistry.registerStandingProof(input, proof) {
            revert(message);
        } catch {}
    }

    function _bindM93StandingProofInput(
        ZKStandingComputationRegistry.StandingProofInput memory input,
        string memory seed
    )
        internal
        returns (
            ZKStandingComputationRegistry.StandingProofInput memory proofInput,
            uint256 formulaId,
            uint256 sourceSetCommitmentId,
            uint256 statementId
        )
    {
        proofInput = input;
        if (proofInput.outputCommitmentHash == bytes32(0)) {
            proofInput.outputCommitmentHash = keccak256(abi.encode(seed, proofInput.subjectCommitment, "standing-output"));
        }
        (formulaId, sourceSetCommitmentId) = _registerM68FormulaAndSourceSet(proofInput, seed);
        uint256 statementEvidenceId = _registerM68SourceSetEvidence(proofInput.workflowKey, string.concat(seed, "-statement"));
        uint256 attestationId =
            _registerM92SourceSetCompletenessAttestation(sourceSetCommitmentId, statementEvidenceId, seed);
        IStandingFormulaRegistry.StandingComputationStatementInput memory statementInput =
            _m91ComputationStatementInput(sourceSetCommitmentId, attestationId, proofInput, statementEvidenceId, seed);
        statementId = standingFormulaRegistry.registerStandingComputationStatement(AVADataTypes.Role.Panel, statementInput);
        proofInput.standingComputationStatementId = statementId;
    }

    function _m95PreparedStatementInput(
        ZKStandingComputationRegistry.StandingProofInput memory proofInput,
        string memory seed
    ) internal returns (IStandingFormulaRegistry.StandingComputationStatementInput memory statementInput) {
        if (proofInput.outputCommitmentHash == bytes32(0)) {
            proofInput.outputCommitmentHash = keccak256(abi.encode(seed, proofInput.subjectCommitment, "standing-output"));
        }
        (, uint256 sourceSetCommitmentId) = _registerM68FormulaAndSourceSet(proofInput, seed);
        uint256 statementEvidenceId = _registerM68SourceSetEvidence(proofInput.workflowKey, string.concat(seed, "-statement"));
        uint256 attestationId =
            _registerM92SourceSetCompletenessAttestation(sourceSetCommitmentId, statementEvidenceId, seed);
        statementInput =
            _m91ComputationStatementInput(sourceSetCommitmentId, attestationId, proofInput, statementEvidenceId, seed);
    }

    function _m95ZkCredentialProves(
        uint256 credentialId,
        uint256 packageId,
        bytes32 subjectCommitment,
        int256 threshold
    ) internal view returns (bool) {
        return zkStandingCredentialRegistry.credentialProves(
            credentialId, packageId, subjectCommitment, _m422VectorKey(), _m422CategoryHash(), threshold
        );
    }

    function _assertM95CanIssueFromReplacementStatement(
        ZKStandingComputationRegistry.StandingProofInput memory proofInput,
        uint256 statementId,
        uint256 packageId,
        bytes32 subjectCommitment
    ) internal {
        proofInput.standingComputationStatementId = statementId;
        bytes32 contextHash = zkStandingComputationRegistry.computeStandingComputationContextHash(proofInput);
        uint256 proofReceiptId = zkStandingComputationRegistry.registerStandingProof(
            proofInput,
            _makeSchnorrProof(contextHash, 7, 19)
        );
        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory credentialInput =
            _m66CredentialInput(proofReceiptId, packageId, subjectCommitment, "m95-supersede-new");
        uint256 credentialId = zkStandingCredentialRegistry.issueCredential(AVADataTypes.Role.Panel, credentialInput);
        require(_m95ZkCredentialProves(credentialId, packageId, subjectCommitment, 40), "new credential not active");
    }

    function _m68FormulaInput(
        bytes32 workflowKey,
        bytes32 vectorKey,
        bytes32 computationRuleHash,
        string memory seed
    ) internal view returns (IStandingFormulaRegistry.StandingFormulaInput memory input) {
        input = IStandingFormulaRegistry.StandingFormulaInput({
            workflowKey: workflowKey,
            vectorKey: vectorKey,
            formulaVersion: uint64((uint256(keccak256(abi.encode(seed, "formula-version"))) % 1_000_000) + 1),
            computationRuleHash: computationRuleHash,
            sourceSetPolicyHash: keccak256(abi.encode(seed, "source-set-policy")),
            decayPolicyHash: keccak256(abi.encode(seed, "decay-policy")),
            capPolicyHash: keccak256(abi.encode(seed, "cap-policy")),
            restorationPolicyHash: keccak256(abi.encode(seed, "restoration-policy")),
            verifier: address(zkStandingComputationRegistry.verifier()),
            authorityId: keccak256("panel-authority"),
            uri: string.concat("ipfs://", seed, "-standing-formula")
        });
    }

    function _registerM68Formula(
        ZKStandingComputationRegistry.StandingProofInput memory input,
        string memory seed
    ) internal returns (uint256 formulaId) {
        formulaId = standingFormulaRegistry.registerStandingFormula(
            AVADataTypes.Role.Panel,
            _m68FormulaInput(input.workflowKey, input.vectorKey, input.computationRuleHash, seed)
        );
    }

    function _registerM68SourceSetEvidence(bytes32 workflowKey, string memory seed)
        internal
        returns (uint256 evidenceId)
    {
        evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256(abi.encode(seed, "standing-source-set-evidence")),
            string.concat("ipfs://", seed, "-standing-source-set-evidence"),
            "standing-source-set-attestation",
            0
        );
    }

    function _m68SourceSetCommitmentInput(
        uint256 formulaId,
        ZKStandingComputationRegistry.StandingProofInput memory input,
        uint256 evidenceReceiptId,
        string memory seed
    ) internal pure returns (IStandingFormulaRegistry.SourceSetCommitmentInput memory sourceInput) {
        sourceInput = IStandingFormulaRegistry.SourceSetCommitmentInput({
            formulaId: formulaId,
            subjectCommitment: input.subjectCommitment,
            categoryHash: input.categoryHash,
            epoch: input.epoch,
            sourceRecordSetRoot: input.sourceRecordSetRoot,
            evidenceReceiptId: evidenceReceiptId,
            completenessAttestationHash: keccak256(abi.encode(seed, "completeness-attestation")),
            authorityId: keccak256("panel-authority"),
            uri: string.concat("ipfs://", seed, "-standing-source-set")
        });
    }

    function _registerM68SourceSetCommitment(
        uint256 formulaId,
        ZKStandingComputationRegistry.StandingProofInput memory input,
        uint256 evidenceReceiptId,
        string memory seed
    ) internal returns (uint256 sourceSetCommitmentId) {
        sourceSetCommitmentId = standingFormulaRegistry.registerSourceSetCommitment(
            AVADataTypes.Role.Panel,
            _m68SourceSetCommitmentInput(formulaId, input, evidenceReceiptId, seed)
        );
    }

    function _registerM68FormulaAndSourceSet(
        ZKStandingComputationRegistry.StandingProofInput memory input,
        string memory seed
    ) internal returns (uint256 formulaId, uint256 sourceSetCommitmentId) {
        formulaId = _registerM68Formula(input, seed);
        uint256 evidenceReceiptId = _registerM68SourceSetEvidence(input.workflowKey, seed);
        sourceSetCommitmentId = _registerM68SourceSetCommitment(formulaId, input, evidenceReceiptId, seed);
    }

    function _m92SourceSetCompletenessAttestationInput(
        uint256 sourceSetCommitmentId,
        uint256 evidenceReceiptId,
        string memory seed
    ) internal view returns (IStandingFormulaRegistry.SourceSetCompletenessAttestationInput memory attestationInput) {
        IStandingFormulaRegistry.SourceSetCommitmentRecord memory commitment =
            standingFormulaRegistry.getSourceSetCommitment(sourceSetCommitmentId);
        attestationInput = IStandingFormulaRegistry.SourceSetCompletenessAttestationInput({
            sourceSetCommitmentId: sourceSetCommitmentId,
            includedRecordClassesHash: keccak256(abi.encode(seed, "included-record-classes")),
            exclusionPolicyHash: keccak256(abi.encode(seed, "exclusion-policy")),
            evidenceReceiptId: evidenceReceiptId,
            completenessAttestationHash: commitment.completenessAttestationHash,
            authorityId: keccak256("panel-authority"),
            uri: string.concat("ipfs://", seed, "-source-set-completeness")
        });
    }

    function _registerM92SourceSetCompletenessAttestation(
        uint256 sourceSetCommitmentId,
        uint256 evidenceReceiptId,
        string memory seed
    ) internal returns (uint256 attestationId) {
        attestationId = standingFormulaRegistry.registerSourceSetCompletenessAttestation(
            AVADataTypes.Role.Panel,
            _m92SourceSetCompletenessAttestationInput(sourceSetCommitmentId, evidenceReceiptId, seed)
        );
    }

    function _assertM92CannotRegisterSourceSetCompletenessAttestation(
        IStandingFormulaRegistry.SourceSetCompletenessAttestationInput memory input,
        string memory message
    ) internal {
        uint256 nextAttestationId = standingFormulaRegistry.nextSourceSetCompletenessAttestationId();
        try standingFormulaRegistry.registerSourceSetCompletenessAttestation(AVADataTypes.Role.Panel, input) {
            revert(message);
        } catch {}
        require(
            standingFormulaRegistry.nextSourceSetCompletenessAttestationId() == nextAttestationId,
            "invalid source-set attestation wrote record"
        );
    }

    function _m91ComputationStatementInput(
        uint256 sourceSetCommitmentId,
        uint256 sourceSetCompletenessAttestationId,
        ZKStandingComputationRegistry.StandingProofInput memory input,
        uint256 evidenceReceiptId,
        string memory seed
    ) internal view returns (IStandingFormulaRegistry.StandingComputationStatementInput memory statementInput) {
        statementInput = IStandingFormulaRegistry.StandingComputationStatementInput({
            sourceSetCommitmentId: sourceSetCommitmentId,
            sourceSetCompletenessAttestationId: sourceSetCompletenessAttestationId,
            workflowKey: input.workflowKey,
            subjectCommitment: input.subjectCommitment,
            vectorKey: input.vectorKey,
            categoryHash: input.categoryHash,
            threshold: input.threshold,
            lowerBound: input.lowerBound,
            upperBound: input.upperBound,
            epoch: input.epoch,
            sourceRecordSetRoot: input.sourceRecordSetRoot,
            computationRuleHash: input.computationRuleHash,
            outputCommitmentHash: input.outputCommitmentHash == bytes32(0)
                ? keccak256(abi.encode(seed, input.subjectCommitment, "standing-output"))
                : input.outputCommitmentHash,
            proofDomainHash: zkStandingComputationRegistry.verifier().proofDomain(),
            evidenceReceiptId: evidenceReceiptId,
            authorityId: keccak256("panel-authority"),
            uri: string.concat("ipfs://", seed, "-standing-computation-statement")
        });
    }

    function _assertM91CannotRegisterComputationStatement(
        IStandingFormulaRegistry.StandingComputationStatementInput memory input,
        string memory message
    ) internal {
        uint256 nextStatementId = standingFormulaRegistry.nextStandingComputationStatementId();
        try standingFormulaRegistry.registerStandingComputationStatement(AVADataTypes.Role.Panel, input) {
            revert(message);
        } catch {}
        require(
            standingFormulaRegistry.nextStandingComputationStatementId() == nextStatementId,
            "invalid computation statement wrote record"
        );
    }

    function _m68StandingComputationContext(
        uint256 recognisedStateId,
        uint256 evidenceReceiptId,
        string memory seed,
        uint256 epoch
    ) internal view returns (AVADataTypes.StandingComputationContext memory context) {
        context.recognisedStateId = recognisedStateId;
        context.subjectId = REVIEWER_SUBJECT;
        context.dimension = "review-procedure-weight";
        context.vectorKey = _m422VectorKey();
        context.currentValue = 42;
        context.delta = 0;
        context.effectiveAt = block.timestamp;
        context.epoch = epoch;
        context.sourceRecordSetHash = keccak256(abi.encode(seed, recognisedStateId, evidenceReceiptId, REVIEWER_SUBJECT));
        context.computationRuleHash = _m422ComputationRuleHash();
        context.reversible = true;
        context.fieldKey = keccak256("review-service-field");
        context.evidenceReceiptId = evidenceReceiptId;
        context.authorityId = keccak256("panel-authority");
        context.actor = address(this);
    }

    function _assertM68StandingUpdateRejectsWrongPackageEvidence(
        uint256 recognisedStateId,
        uint256 evidenceReceiptId,
        string memory message
    ) internal {
        uint256 nextUpdateId = standingRegistry.nextStandingUpdateId();
        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            "review-procedure-weight",
            1,
            evidenceReceiptId,
            keccak256("panel-authority"),
            "ipfs://m68-wrong-package-standing-update"
        ) {
            revert(message);
        } catch {}
        require(standingRegistry.nextStandingUpdateId() == nextUpdateId, "wrong-package evidence wrote standing update");
    }

    function _assertM68StandingComputationRejectsWrongPackageEvidence(
        uint256 recognisedStateId,
        uint256 evidenceReceiptId,
        string memory message
    ) internal {
        uint256 nextComputationId = standingRegistry.nextStandingComputationRecordId();
        try standingRegistry.recordStandingComputationReadiness(
            AVADataTypes.Role.Panel,
            _m68StandingComputationContext(recognisedStateId, evidenceReceiptId, "m68-wrong-package-computation", 2),
            "ipfs://m68-wrong-package-standing-computation"
        ) {
            revert(message);
        } catch {}
        require(
            standingRegistry.nextStandingComputationRecordId() == nextComputationId,
            "wrong-package evidence wrote standing computation"
        );
    }

    function _assertM68StandingInvalidationRejectsWrongPackageEvidence(
        uint256 computationId,
        uint256 evidenceReceiptId,
        string memory message
    ) internal {
        try standingRegistry.invalidateStandingComputation(
            AVADataTypes.Role.Panel,
            computationId,
            evidenceReceiptId,
            keccak256("panel-authority"),
            "ipfs://m68-wrong-package-standing-invalidation"
        ) {
            revert(message);
        } catch {}
        require(
            standingRegistry.getStandingComputationRecord(computationId).status
                == AVADataTypes.StandingComputationStatus.Active,
            "wrong-package evidence invalidated standing computation"
        );
    }

    function _assertM68StateRejectsWrongPackageEvidence(
        bytes32 workflowKey,
        uint256 evidenceReceiptId,
        string memory message
    ) internal {
        uint256 nextRecognisedStateId = stateMachine.nextRecognisedStateId();
        try stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            keccak256("m68-new-package-state-with-old-evidence"),
            REVIEWER_SUBJECT,
            evidenceReceiptId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        ) {
            revert(message);
        } catch {}
        require(stateMachine.nextRecognisedStateId() == nextRecognisedStateId, "wrong-package evidence wrote state");
    }

    function _assertM68ChallengeRejectsWrongPackageEvidence(
        bytes32 workflowKey,
        uint256 challengedRecognisedStateId,
        uint256 evidenceReceiptId,
        string memory message
    ) internal {
        uint256 nextChallengeId = stateMachine.nextChallengeId();
        try challengerActor.fileChallenge(
            stateMachine,
            AVADataTypes.Role.Challenger,
            workflowKey,
            challengedRecognisedStateId,
            CHALLENGER_SUBJECT,
            evidenceReceiptId,
            0
        ) {
            revert(message);
        } catch {}
        require(stateMachine.nextChallengeId() == nextChallengeId, "wrong-package evidence wrote challenge");
    }

    function _assertM68AllocationRejectsWrongPackageEvidence(
        uint256 recognisedStateId,
        uint256 evidenceReceiptId,
        string memory message
    ) internal {
        uint256 nextAllocationId = allocationExecutor.nextAllocationExecutionId();
        try allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            AVADataTypes.AllocationKind.OperationalAllowance,
            REVIEWER_SUBJECT,
            1,
            evidenceReceiptId,
            keccak256("executor-authority"),
            "ipfs://m68-wrong-package-allocation"
        ) {
            revert(message);
        } catch {}
        require(allocationExecutor.nextAllocationExecutionId() == nextAllocationId, "wrong-package evidence wrote allocation");
    }

    function _assertM68ConsequenceRejectsWrongPackageEvidence(
        uint256 recognisedStateId,
        uint256 evidenceReceiptId,
        string memory message
    ) internal {
        uint256 nextConsequenceId = consequenceExecutor.nextConsequenceId();
        try consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            AVADataTypes.ConsequenceKind.AdministrativeNote,
            REVIEWER_SUBJECT,
            evidenceReceiptId,
            keccak256("panel-authority"),
            "ipfs://m68-wrong-package-consequence"
        ) {
            revert(message);
        } catch {}
        require(consequenceExecutor.nextConsequenceId() == nextConsequenceId, "wrong-package evidence wrote consequence");
    }

    function _assertM68ExternalOperationRejectsWrongPackageEvidence(
        bytes32 workflowKey,
        uint256 recognisedStateId,
        uint256 evidenceReceiptId,
        string memory message
    ) internal {
        uint256 nextExternalOperationId = externalOperationRegistry.nextExternalOperationId();
        try externalOperationRegistry.requestOperation(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVADataTypes.ExternalOperationKind.QueueAdjustmentIntent,
            AVADataTypes.ExternalOperationTargetKind.RecognisedState,
            recognisedStateId,
            evidenceReceiptId,
            keccak256("panel-authority"),
            "ipfs://m68-wrong-package-external-operation"
        ) {
            revert(message);
        } catch {}
        require(
            externalOperationRegistry.nextExternalOperationId() == nextExternalOperationId,
            "wrong-package evidence wrote external operation"
        );
    }

    function _createM66StandingProofReceipt(bytes32 workflowKey, bytes32 subjectCommitment, string memory seed)
        internal
        returns (uint256 proofReceiptId)
    {
        proofReceiptId = _createM66StandingProofReceipt(workflowKey, subjectCommitment, seed, 1);
    }

    function _createM66StandingProofReceipt(
        bytes32 workflowKey,
        bytes32 subjectCommitment,
        string memory seed,
        uint256 epoch
    )
        internal
        returns (uint256 proofReceiptId)
    {
        ZKStandingComputationRegistry.StandingProofInput memory proofInput =
            _m65StandingProofInput(workflowKey, subjectCommitment, seed);
        proofInput.epoch = epoch;
        proofInput.sourceRecordSetRoot = keccak256(abi.encode(seed, subjectCommitment, epoch, "source-record-set-root"));
        (proofInput,,,) = _bindM93StandingProofInput(proofInput, seed);
        bytes32 contextHash = zkStandingComputationRegistry.computeStandingComputationContextHash(proofInput);
        proofReceiptId = zkStandingComputationRegistry.registerStandingProof(
            proofInput,
            _makeSchnorrProof(contextHash, 7, 11)
        );
    }

    function _m66CredentialInput(
        uint256 proofReceiptId,
        uint256 packageId,
        bytes32 subjectCommitment,
        string memory seed
    ) internal view returns (IZKStandingCredentialIssuer.ZKStandingCredentialInput memory input) {
        ZKStandingComputationRegistry.StandingProofReceipt memory proofReceipt =
            zkStandingComputationRegistry.getStandingProofReceipt(proofReceiptId);
        input = IZKStandingCredentialIssuer.ZKStandingCredentialInput({
            standingProofReceiptId: proofReceiptId,
            packageId: packageId,
            subjectCommitment: subjectCommitment,
            credentialCommitment: _subjectCommitmentForSecret(_m66CredentialSecret(seed)),
            credentialNullifierHash: keccak256(abi.encode(seed, subjectCommitment, "credential-nullifier")),
            vectorKey: proofReceipt.vectorKey,
            categoryHash: proofReceipt.categoryHash,
            threshold: 40,
            lowerBound: proofReceipt.lowerBound,
            upperBound: proofReceipt.upperBound,
            epoch: proofReceipt.epoch,
            sourceRecordSetRoot: proofReceipt.sourceRecordSetRoot,
            computationRuleHash: proofReceipt.computationRuleHash,
            expiresAt: block.timestamp + 7 days,
            authorityId: keccak256("panel-authority"),
            uri: string.concat("ipfs://", seed, "-zk-standing-credential")
        });
    }

    function _m66CredentialSecret(string memory seed) internal pure returns (uint256) {
        return (uint256(keccak256(abi.encode(seed, "credential-secret"))) % 1000) + 17;
    }

    function _issueM66ZKStandingCredential(
        bytes32 workflowKey,
        bytes32 subjectCommitment,
        string memory seed,
        uint256 epoch,
        uint256 expiresAt
    ) internal returns (uint256 credentialId) {
        uint256 proofReceiptId = _createM66StandingProofReceipt(workflowKey, subjectCommitment, seed, epoch);
        uint256 packageId = rulePackageRegistry.getRulePackage(workflowKey).packageId;
        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory input =
            _m66CredentialInput(proofReceiptId, packageId, subjectCommitment, seed);
        input.expiresAt = expiresAt;
        credentialId = zkStandingCredentialRegistry.issueCredential(AVADataTypes.Role.Panel, input);
    }

    function _assertM66CannotIssueCredential(
        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory input,
        string memory message
    ) internal {
        try zkStandingCredentialRegistry.issueCredential(AVADataTypes.Role.Panel, input) {
            revert(message);
        } catch {}
    }

    function _recordM66CredentialUseWithSecret(
        uint256 credentialId,
        int256 requiredThreshold,
        bytes32 targetContext,
        uint256 credentialSecret,
        uint256 nonce
    ) internal returns (uint256 useRecordId) {
        IZKStandingCredentialIssuer.ZKStandingCredentialUseInput memory input =
            _m66CredentialUseInput(credentialId, requiredThreshold, targetContext);
        bytes32 useContext = _m66CredentialUseContext(input);
        useRecordId =
            zkStandingCredentialRegistry.recordCredentialUse(input, _makeSchnorrProof(useContext, credentialSecret, nonce));
    }

    function _assertM66CannotRecordCredentialUseWithSecret(
        uint256 credentialId,
        int256 requiredThreshold,
        bytes32 targetContext,
        uint256 credentialSecret,
        string memory message
    ) internal {
        IZKStandingCredentialIssuer.ZKStandingCredentialUseInput memory input =
            _m66CredentialUseInput(credentialId, requiredThreshold, targetContext);
        bytes32 useContext = _m66CredentialUseContext(input);
        try zkStandingCredentialRegistry.recordCredentialUse(input, _makeSchnorrProof(useContext, credentialSecret, 29)) {
            revert(message);
        } catch {}
    }

    function _m66CredentialUseInput(
        uint256 credentialId,
        int256 requiredThreshold,
        bytes32 targetContext
    ) internal view returns (IZKStandingCredentialIssuer.ZKStandingCredentialUseInput memory input) {
        IZKStandingCredentialIssuer.ZKStandingCredentialRecord memory credential =
            zkStandingCredentialRegistry.getCredential(credentialId);
        bytes32 useContext = zkStandingCredentialRegistry.computeCredentialUseContextHash(
            credentialId,
            credential.packageId,
            credential.subjectCommitment,
            credential.vectorKey,
            credential.categoryHash,
            requiredThreshold,
            targetContext
        );
        input = IZKStandingCredentialIssuer.ZKStandingCredentialUseInput({
            credentialId: credentialId,
            packageId: credential.packageId,
            subjectCommitment: credential.subjectCommitment,
            vectorKey: credential.vectorKey,
            categoryHash: credential.categoryHash,
            requiredThreshold: requiredThreshold,
            targetContextHash: targetContext,
            proofUseNullifierHash: zkStandingCredentialRegistry.computeCredentialUseNullifierHash(
                useContext, credential.credentialCommitment
            )
        });
    }

    function _m66CredentialUseContext(IZKStandingCredentialIssuer.ZKStandingCredentialUseInput memory input)
        internal
        view
        returns (bytes32)
    {
        return zkStandingCredentialRegistry.computeCredentialUseContextHash(
            input.credentialId,
            input.packageId,
            input.subjectCommitment,
            input.vectorKey,
            input.categoryHash,
            input.requiredThreshold,
            input.targetContextHash
        );
    }

    function _m422VectorKey() internal pure returns (bytes32) {
        return keccak256("review-procedure-weight");
    }

    function _m422CategoryHash() internal pure returns (bytes32) {
        return keccak256("panel-visible-standing-category");
    }

    function _m422RuleHash() internal pure returns (bytes32) {
        return keccak256("m422-standing-computation-rule-v1");
    }

    function _nonEligibleRecognisedStateStatus(uint8 statusSeed)
        internal
        pure
        returns (AVADataTypes.RecognisedStateStatus)
    {
        uint8 index = statusSeed % 6;
        if (index == 0) return AVADataTypes.RecognisedStateStatus.None;
        if (index == 1) return AVADataTypes.RecognisedStateStatus.Draft;
        if (index == 2) return AVADataTypes.RecognisedStateStatus.Registered;
        if (index == 3) return AVADataTypes.RecognisedStateStatus.Provisional;
        if (index == 4) return AVADataTypes.RecognisedStateStatus.Challengeable;
        return AVADataTypes.RecognisedStateStatus.Frozen;
    }

    function _recordRecoveryTerminalSettlement(uint256 sourceId, uint8 terminalKind)
        internal
        returns (AVADataTypes.ValueSettlementStatus)
    {
        if (terminalKind % 3 == 0) {
            valueSettlementExecutor.recordFuturePayoutSetoff(
                AVADataTypes.Role.ProtocolExecutor,
                AVADataTypes.ExecutionSourceType.AllocationRecord,
                sourceId,
                keccak256("executor-authority"),
                "ipfs://fuzz-terminal-setoff"
            );
            return AVADataTypes.ValueSettlementStatus.SetoffRecorded;
        }
        if (terminalKind % 3 == 1) {
            valueSettlementExecutor.recordWaiver(
                AVADataTypes.Role.ProtocolExecutor,
                AVADataTypes.ExecutionSourceType.AllocationRecord,
                sourceId,
                keccak256("executor-authority"),
                "ipfs://fuzz-terminal-waiver"
            );
            return AVADataTypes.ValueSettlementStatus.Waived;
        }
        valueSettlementExecutor.recordSatisfaction(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://fuzz-terminal-satisfaction"
        );
        return AVADataTypes.ValueSettlementStatus.Satisfied;
    }

    function _assertStandingAndAllocationRejectTarget(uint256 recognisedStateId, uint256 evidenceId) internal {
        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            "review-procedure-weight",
            1,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://standing-rejected"
        ) {
            revert("standing accepted disallowed status");
        } catch {}

        try allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            AVADataTypes.AllocationKind.OperationalAllowance,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://allocation-rejected"
        ) {
            revert("allocation accepted disallowed status");
        } catch {}
    }

    function _assertConsequenceRejectsTarget(uint256 recognisedStateId, uint256 evidenceId) internal {
        try consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            AVADataTypes.ConsequenceKind.AdministrativeNote,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://consequence-rejected"
        ) {
            revert("consequence accepted disallowed target");
        } catch {}
    }

    function _assertDirectHighStatusRegistrationRejected(
        AVADataTypes.RecognisedStateStatus status,
        uint256 evidenceId
    ) internal {
        try stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            keccak256(abi.encodePacked("direct-high-status", status)),
            REVIEWER_SUBJECT,
            evidenceId,
            0,
            EDITOR_AUTHORITY,
            status
        ) {
            revert("direct high-status registration succeeded");
        } catch {}
    }

    function _assertGenericTransitionRejected(
        uint256 recognisedStateId,
        AVADataTypes.RecognisedStateStatus toStatus
    ) internal {
        uint256 nextTransitionId = stateMachine.nextRecognisedStateTransitionId();
        try stateMachine.transitionRecognisedState(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            toStatus,
            keccak256("panel-authority"),
            "ipfs://generic-transition-rejected"
        ) {
            revert("generic transition accepted restricted status");
        } catch {}
        require(stateMachine.nextRecognisedStateTransitionId() == nextTransitionId, "rejected transition wrote ledger");
    }

    function _assertDownstreamRejectsTargetSubject(
        uint256 standingStateId,
        uint256 allocationStateId,
        uint256 evidenceId,
        bytes32 subjectId
    ) internal {
        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            standingStateId,
            subjectId,
            "review-procedure-weight",
            1,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://invalid-target-standing"
        ) {
            revert("standing accepted invalid target subject");
        } catch {}

        try allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            allocationStateId,
            AVADataTypes.AllocationKind.OperationalAllowance,
            subjectId,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://invalid-target-allocation"
        ) {
            revert("allocation accepted invalid target subject");
        } catch {}

        try consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            standingStateId,
            AVADataTypes.ConsequenceKind.AdministrativeNote,
            subjectId,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://invalid-target-consequence"
        ) {
            revert("consequence accepted invalid target subject");
        } catch {}
    }

    function _assertRecognisedStateTransition(
        uint256 transitionId,
        uint256 recognisedStateId,
        AVADataTypes.RecognisedStateStatus fromStatus,
        AVADataTypes.RecognisedStateStatus toStatus,
        AVADataTypes.Action action,
        uint256 challengeId
    ) internal view {
        AVADataTypes.RecognisedStateTransitionRecord memory transition =
            stateMachine.getRecognisedStateTransition(transitionId);
        require(transition.recognisedStateId == recognisedStateId, "transition state wrong");
        require(transition.fromStatus == fromStatus, "transition from wrong");
        require(transition.toStatus == toStatus, "transition to wrong");
        require(transition.action == action, "transition action wrong");
        require(transition.challengeId == challengeId, "transition challenge wrong");
        require(transition.createdAt != 0, "transition timestamp missing");
    }

    function _assertSeparatedDownstreamRejectsTarget(uint256 recognisedStateId, uint256 evidenceId) internal {
        try allocationExecutor.recordRewardValue(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://reward-rejected"
        ) {
            revert("reward accepted disallowed target");
        } catch {}

        try allocationExecutor.recordAdministrativePriority(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://priority-rejected"
        ) {
            revert("priority accepted disallowed target");
        } catch {}

        try consequenceExecutor.recordPenalty(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://penalty-rejected"
        ) {
            revert("penalty accepted disallowed target");
        } catch {}

        try consequenceExecutor.recordRestoration(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://restoration-rejected"
        ) {
            revert("restoration accepted disallowed target");
        } catch {}
    }

    function _assertAllDownstreamRejectTarget(uint256 recognisedStateId, uint256 evidenceId) internal {
        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            "review-procedure-weight",
            1,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://standing-rejected"
        ) {
            revert("standing accepted disallowed target");
        } catch {}

        try standingRegistry.recordStandingComputationReadiness(
            AVADataTypes.Role.Panel,
            AVADataTypes.StandingComputationContext({
                recognisedStateId: recognisedStateId,
                subjectId: REVIEWER_SUBJECT,
                dimension: "review-procedure-weight",
                vectorKey: keccak256("review-procedure-weight"),
                currentValue: 0,
                delta: 1,
                effectiveAt: 0,
                epoch: 1,
                sourceRecordSetHash: keccak256("disallowed-standing-source-set"),
                computationRuleHash: _m422ComputationRuleHash(),
                reversible: true,
                fieldKey: keccak256("verification-field"),
                evidenceReceiptId: evidenceId,
                authorityId: keccak256("panel-authority"),
                actor: address(this)
            }),
            "ipfs://standing-computation-rejected"
        ) {
            revert("standing computation accepted disallowed target");
        } catch {}

        try allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            AVADataTypes.AllocationKind.OperationalAllowance,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://allocation-rejected"
        ) {
            revert("allocation accepted disallowed target");
        } catch {}

        try consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            AVADataTypes.ConsequenceKind.AdministrativeNote,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://consequence-rejected"
        ) {
            revert("consequence accepted disallowed target");
        } catch {}

        _assertSeparatedDownstreamRejectsTarget(recognisedStateId, evidenceId);
    }

    function _assertM4DownstreamRecords(uint256 reviewStateId, uint256 evidenceId) internal {
        bytes32 subjectId = stateMachine.getRecognisedState(reviewStateId).subjectId;
        uint256 standingId = standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            reviewStateId,
            subjectId,
            "review-procedure-weight",
            -1,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://m4-standing"
        );
        uint256 rewardId = allocationExecutor.recordRewardValue(
            AVADataTypes.Role.ProtocolExecutor,
            reviewStateId,
            subjectId,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://m4-reward"
        );
        uint256 priorityId = allocationExecutor.recordAdministrativePriority(
            AVADataTypes.Role.ProtocolExecutor,
            reviewStateId,
            subjectId,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://m4-priority"
        );
        uint256 penaltyId = consequenceExecutor.recordPenalty(
            AVADataTypes.Role.Panel,
            reviewStateId,
            subjectId,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://m4-penalty"
        );
        uint256 restorationId = consequenceExecutor.recordRestoration(
            AVADataTypes.Role.Panel,
            reviewStateId,
            subjectId,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://m4-restoration"
        );

        require(standingRegistry.getStandingUpdate(standingId).recognisedStateId == reviewStateId, "standing target");
        require(
            allocationExecutor.getAllocationExecution(rewardId).allocationKind
                == AVADataTypes.AllocationKind.RewardValueRecord,
            "reward kind"
        );
        require(
            allocationExecutor.getAllocationExecution(priorityId).allocationKind
                == AVADataTypes.AllocationKind.AdministrativeQueueRecord,
            "priority kind"
        );
        require(
            consequenceExecutor.getConsequence(penaltyId).kind == AVADataTypes.ConsequenceKind.PenaltyRecord,
            "penalty kind"
        );
        require(
            consequenceExecutor.getConsequence(restorationId).kind
                == AVADataTypes.ConsequenceKind.RestorationRecord,
            "restoration kind"
        );
    }

    function _createM102ChallengeableDoubleBlindReview(string memory seed)
        internal
        returns (M102DoubleBlindReviewContext memory context)
    {
        uint256 policyId = _registerDisclosurePolicy(string.concat(seed, "-policy"));
        context.module = new DoubleBlindDisclosureModule(disclosureRegistry, policyId);
        context.workflowKey = keccak256(bytes(string.concat(seed, "-workflow")));
        _registerRulePackage(
            context.workflowKey, context.module, allocationAdapter, consequenceAdapter, string.concat("ipfs://", seed)
        );
        context.packageId = rulePackageRegistry.getRulePackage(context.workflowKey).packageId;
        uint256 manuscriptId = _registerAuthorManuscript();
        context.evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            context.workflowKey,
            keccak256(bytes(string.concat(seed, "-review-evidence"))),
            string.concat("ipfs://", seed, "-review"),
            "double-blind-review",
            policyId
        );
        context.reviewContributionId = reviewerActor.registerReviewContributionWithWorkflow(
            stateMachine,
            AVADataTypes.Role.Reviewer,
            context.workflowKey,
            manuscriptId,
            REVIEWER_SUBJECT,
            context.evidenceId,
            policyId
        );
        context.recognisedStateId = stateMachine.provisionallyRecogniseReview(
            AVADataTypes.Role.Editor, context.reviewContributionId, EDITOR_AUTHORITY
        );
        stateMachine.openReviewChallengeWindow(
            AVADataTypes.Role.Editor, context.reviewContributionId, EDITOR_AUTHORITY
        );
    }

    function _assertM102DownstreamRecordsBindPackage(uint256 recognisedStateId, uint256 evidenceId, uint256 packageId)
        internal
    {
        uint256 standingId = standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            "review-procedure-weight",
            1,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://m102-standing"
        );
        uint256 allocationId = allocationExecutor.executeAllocation(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            AVADataTypes.AllocationKind.OperationalAllowance,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://m102-allocation"
        );
        uint256 consequenceId = consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            AVADataTypes.ConsequenceKind.AdministrativeNote,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://m102-consequence"
        );

        require(standingRegistry.getStandingUpdate(standingId).packageId == packageId, "standing package wrong");
        require(allocationExecutor.getAllocationExecution(allocationId).packageId == packageId, "allocation package wrong");
        require(consequenceExecutor.getConsequence(consequenceId).packageId == packageId, "consequence package wrong");
    }

    function _createM103FiledZkChallenge(string memory seed)
        internal
        returns (M103AnonymousChallengeContext memory context)
    {
        context.policyId = _registerDisclosurePolicy(string.concat(seed, "-policy"));
        context.subjectCommitment = _subjectCommitmentForSecret(7);
        context.challenger = new Actor();
        roleRegistry.assignRole(
            address(context.challenger),
            AVADataTypes.Role.Challenger,
            context.subjectCommitment,
            string.concat("ipfs://", seed, "-challenger")
        );
        context.workflowKey = keccak256(bytes(string.concat(seed, "-workflow")));
        context.module = new ZKBackedDisclosureModule(disclosureRegistry, zkProofRegistry, context.policyId);
        _registerRulePackage(
            context.workflowKey, context.module, allocationAdapter, consequenceAdapter, string.concat("ipfs://", seed)
        );
        context.packageId = rulePackageRegistry.getRulePackage(context.workflowKey).packageId;

        uint256 evidenceId = context.challenger.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            context.workflowKey,
            keccak256(bytes(string.concat(seed, "-evidence"))),
            string.concat("ipfs://", seed, "-evidence"),
            "anonymous-integrity-challenge",
            context.policyId
        );
        bytes32 targetObjectId = keccak256(bytes(string.concat(seed, "-target")));
        _registerM103DisclosureProof(
            context, AVADataTypes.Action.RegisterRecognisedState, targetObjectId, AVADataTypes.Role.Editor
        );
        context.recognisedStateId = stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            context.workflowKey,
            AVADataTypes.AVAStage.Verification,
            targetObjectId,
            context.subjectCommitment,
            evidenceId,
            context.policyId,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Challengeable
        );
        _registerM103DisclosureProof(
            context,
            AVADataTypes.Action.FileChallenge,
            bytes32(context.recognisedStateId),
            AVADataTypes.Role.Challenger
        );
        context.challengeId = context.challenger.fileChallenge(
            stateMachine,
            AVADataTypes.Role.Challenger,
            context.workflowKey,
            context.recognisedStateId,
            context.subjectCommitment,
            evidenceId,
            context.policyId
        );
    }

    function _recordM103AnonymousChallengeProofUse(M103AnonymousChallengeContext memory context)
        internal
        returns (uint256 proofUseId)
    {
        uint256 proofReceiptId = _registerM103DisclosureProof(
            context,
            AVADataTypes.Action.RecordDisclosureExecution,
            bytes32(context.challengeId),
            AVADataTypes.Role.Challenger
        );
        ZKProofRegistry.ProofReceipt memory proofReceipt = zkProofRegistry.getProofReceipt(proofReceiptId);
        proofUseId = context.challenger.recordAnonymousChallengeProofUse(
            disclosureAccessExecutor,
            AVADataTypes.Role.Challenger,
            context.challengeId,
            context.policyId,
            proofReceiptId,
            context.subjectCommitment,
            proofReceipt.nullifierHash,
            "ipfs://m103-anonymous-proof-use"
        );
    }

    function _registerM103DisclosureProof(
        M103AnonymousChallengeContext memory context,
        AVADataTypes.Action action,
        bytes32 objectId,
        AVADataTypes.Role actingRole
    ) internal returns (uint256 proofReceiptId) {
        bytes32 contextHash = zkProofRegistry.computeDisclosureContextHash(
            context.workflowKey,
            AVADataTypes.AVAStage.Verification,
            action,
            objectId,
            actingRole,
            context.policyId,
            context.subjectCommitment
        );
        proofReceiptId = zkProofRegistry.registerProof(
            context.workflowKey,
            AVADataTypes.AVAStage.Verification,
            action,
            objectId,
            actingRole,
            context.policyId,
            context.subjectCommitment,
            _makeSchnorrProof(contextHash, 7, 11)
        );
    }

    function _createM104DowngradedCorrectionState(string memory seed)
        internal
        returns (M104CorrectionRestorationContext memory context)
    {
        context.workflowKey = keccak256(bytes(string.concat(seed, "-workflow")));
        _registerRulePackageWithAdapters(
            context.workflowKey,
            allocationAdapter,
            consequenceAdapter,
            standingAdapter,
            rewardAdapter,
            priorityAdapter,
            penaltyAdapter,
            new CorrectionRestorationRecordAdapter(),
            string.concat("ipfs://", seed)
        );
        context.packageId = rulePackageRegistry.getRulePackage(context.workflowKey).packageId;
        uint256 reviewEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            context.workflowKey,
            keccak256(bytes(string.concat(seed, "-review-evidence"))),
            string.concat("ipfs://", seed, "-review"),
            "correction-restoration-review",
            0
        );
        context.recognisedStateId = stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            context.workflowKey,
            AVADataTypes.AVAStage.Verification,
            keccak256(bytes(string.concat(seed, "-review-state"))),
            REVIEWER_SUBJECT,
            reviewEvidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Challengeable
        );
        context.challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            context.workflowKey,
            keccak256(bytes(string.concat(seed, "-challenge-evidence"))),
            string.concat("ipfs://", seed, "-challenge"),
            "correction-restoration-challenge",
            0
        );
        context.challengeId = challengerActor.fileChallenge(
            stateMachine,
            AVADataTypes.Role.Challenger,
            context.workflowKey,
            context.recognisedStateId,
            CHALLENGER_SUBJECT,
            context.challengeEvidenceId,
            0
        );
        stateMachine.screenChallenge(AVADataTypes.Role.Editor, context.challengeId, EDITOR_AUTHORITY);
        stateMachine.resolveChallenge(
            AVADataTypes.Role.Panel,
            context.challengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            keccak256("panel-authority"),
            string.concat("ipfs://", seed, "-correction")
        );
    }

    function _assertM4WorkflowAdapterBlocks(
        uint256 reviewStateId,
        uint256 integrityStateId,
        uint256 reviewEvidenceId,
        uint256 integrityEvidenceId,
        bytes32 reviewBlockedAuthority,
        bytes32 integrityBlockedAuthority
    ) internal {
        try standingRegistry.recordStandingUpdate(
            AVADataTypes.Role.Panel,
            reviewStateId,
            REVIEWER_SUBJECT,
            "review-blocked-standing",
            1,
            reviewEvidenceId,
            keccak256("panel-authority"),
            "ipfs://blocked-standing"
        ) {
            revert("review standing adapter not used");
        } catch {}
        try allocationExecutor.recordRewardValue(
            AVADataTypes.Role.ProtocolExecutor,
            integrityStateId,
            CHALLENGER_SUBJECT,
            17,
            integrityEvidenceId,
            keccak256("executor-authority"),
            "ipfs://blocked-integrity-reward"
        ) {
            revert("integrity reward adapter not used");
        } catch {}
        try allocationExecutor.recordAdministrativePriority(
            AVADataTypes.Role.ProtocolExecutor,
            integrityStateId,
            CHALLENGER_SUBJECT,
            19,
            integrityEvidenceId,
            keccak256("executor-authority"),
            "ipfs://blocked-integrity-priority"
        ) {
            revert("integrity priority adapter not used");
        } catch {}
        try consequenceExecutor.recordPenalty(
            AVADataTypes.Role.Panel,
            reviewStateId,
            REVIEWER_SUBJECT,
            reviewEvidenceId,
            reviewBlockedAuthority,
            "ipfs://blocked-review-penalty"
        ) {
            revert("review penalty adapter not used");
        } catch {}
        try consequenceExecutor.recordRestoration(
            AVADataTypes.Role.Panel,
            integrityStateId,
            CHALLENGER_SUBJECT,
            integrityEvidenceId,
            integrityBlockedAuthority,
            "ipfs://blocked-integrity-restoration"
        ) {
            revert("integrity restoration adapter not used");
        } catch {}
    }

    function _assertLifecycleModuleRejectsScreen() internal {
        bytes32 workflowKey = keccak256("m47-reject-screen");
        uint256 challengeId = _fileChallengeForLifecycleWorkflow(workflowKey, AVADataTypes.Action.ScreenChallenge);
        try stateMachine.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY) {
            revert("challenge lifecycle did not reject screen");
        } catch {}
        require(
            stateMachine.getChallenge(challengeId).status == AVADataTypes.ChallengeLifecycleStatus.ConcernFiled,
            "rejected screen changed state"
        );
    }

    function _assertLifecycleModuleRejectsResolve() internal {
        bytes32 workflowKey = keccak256("m47-reject-resolve");
        uint256 challengeId = _fileChallengeForLifecycleWorkflow(workflowKey, AVADataTypes.Action.ResolveChallenge);
        stateMachine.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        try stateMachine.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            keccak256("panel-authority"),
            "ipfs://m47-rejected-resolve"
        ) {
            revert("challenge lifecycle did not reject resolve");
        } catch {}
        require(
            stateMachine.getChallenge(challengeId).status == AVADataTypes.ChallengeLifecycleStatus.AdmissibilityScreening,
            "rejected resolve changed state"
        );
    }

    function _assertLifecycleModuleRejectsRestoration() internal {
        bytes32 workflowKey = keccak256("m47-reject-restoration");
        uint256 challengeId = _fileChallengeForLifecycleWorkflow(workflowKey, AVADataTypes.Action.ApplyRestoration);
        stateMachine.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        stateMachine.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://m47-good-faith"
        );
        AVADataTypes.ChallengeRecord memory resolvedChallenge = stateMachine.getChallenge(challengeId);
        try stateMachine.applyRestoration(
            AVADataTypes.Role.Panel, challengeId, keccak256("panel-authority"), "ipfs://m47-rejected-restoration"
        ) {
            revert("challenge lifecycle did not reject restoration");
        } catch {}
        require(
            stateMachine.getChallenge(challengeId).lastTransitionId == resolvedChallenge.lastTransitionId,
            "rejected restoration changed history"
        );
    }

    function _assertLifecycleModuleRejectsClose() internal {
        bytes32 workflowKey = keccak256("m47-reject-close");
        uint256 challengeId = _fileChallengeForLifecycleWorkflow(workflowKey, AVADataTypes.Action.CloseChallenge);
        stateMachine.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        stateMachine.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.Negligent,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://m47-negligent"
        );
        AVADataTypes.ChallengeRecord memory resolvedChallenge = stateMachine.getChallenge(challengeId);
        try stateMachine.closeChallenge(
            AVADataTypes.Role.Panel, challengeId, keccak256("panel-authority"), "ipfs://m47-rejected-close"
        ) {
            revert("challenge lifecycle did not reject close");
        } catch {}
        require(
            stateMachine.getChallenge(challengeId).lastTransitionId == resolvedChallenge.lastTransitionId,
            "rejected close changed history"
        );
    }

    function _fileChallengeForLifecycleWorkflow(bytes32 workflowKey, AVADataTypes.Action blockedAction)
        internal
        returns (uint256 challengeId)
    {
        _registerRulePackageWithLifecycle(
            workflowKey, new RejectingChallengeLifecycleModule(blockedAction), "ipfs://m47-lifecycle"
        );
        AVARulePackageRegistry.RulePackage memory rulePackage = rulePackageRegistry.getRulePackage(workflowKey);
        uint256 recognisedStateId = _createChallengeableReviewStateThroughPackage(rulePackage, workflowKey);
        uint256 evidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            workflowKey,
            keccak256(abi.encodePacked(workflowKey, blockedAction)),
            "ipfs://m47-lifecycle-evidence",
            "challenge-lifecycle",
            0
        );
        challengeId = challengerActor.fileChallenge(
            stateMachine, AVADataTypes.Role.Challenger, workflowKey, recognisedStateId, CHALLENGER_SUBJECT, evidenceId, 0
        );
    }

    function _registerDefaultRulePackage(bytes32 workflowKey, string memory uri) internal {
        _registerRulePackage(workflowKey, disclosurePolicyModule, allocationAdapter, consequenceAdapter, uri);
    }

    function _ensureWorkflowPackage(bytes32 workflowKey) internal {
        try rulePackageRegistry.getRulePackage(workflowKey) returns (AVARulePackageRegistry.RulePackage memory) {}
        catch {
            _registerDefaultRulePackage(workflowKey, "ipfs://test-workflow-evidence-primer");
        }
    }

    function _m419CustomInterfaceModules() internal returns (AVARulePackageRegistry.RulePackageModules memory) {
        return AVARulePackageRegistry.RulePackageModules({
            attributionModule: new SubjectSaltAttributionModule(),
            verificationModule: new EvidenceThresholdVerificationModule(1),
            allocationModule: allocationAdapter,
            transitionRuleModule: new NoFrozenTransitionRuleModule(),
            disclosureModule: disclosurePolicyModule,
            standingAdapter: new VectorStandingAdapter(),
            consequenceAdapter: new BoundedConsequenceExampleAdapter(),
            rewardAdapter: new StablecoinRecordRewardAdapter(),
            priorityAdapter: new PriorityTokenRecordAdapter(),
            penaltyAdapter: new ProceduralPenaltyRecordAdapter(),
            restorationAdapter: new RestorationProcedureRecordAdapter(),
            challengeLifecycleModule: new PanelOnlyChallengeLifecycleModule(),
            evidencePolicyModule: new TypedEvidencePolicyModule(keccak256("m419-interface-evidence")),
            auditAdapter: new HashAnchoredAuditAdapter(),
            editorialSystemAdapter: new EditorialReferenceAdapter(),
            residualEditorialAuthorityModule: residualEditorialAuthorityModule,
            fieldPolicyModule: new DisciplineFieldPolicyModule(AVADataTypes.AVAStage.Verification),
            antiAbuseModule: new SubjectRateLimitModule(),
            valueExecutionAdapter: new ClaimEscrowRecordValueAdapter(),
            standingComputationModule: new VectorStandingComputationModule(),
            rulePackageLifecycleModule: new VersionedRulePackageLifecycleModule(1),
            evidenceLifecycleModule: evidenceLifecycleModule,
            disclosureLifecycleModule: disclosureLifecycleModule,
                disclosureExecutionModule: disclosureExecutionModule,
            version: 1,
            compatibilityKey: keccak256("ava-m4-19-compatible"),
            dependencyURI: "ipfs://m419-interface-contracts",
            deprecated: false
        });
    }

    function _defaultRulePackageModules() internal view returns (AVARulePackageRegistry.RulePackageModules memory) {
        return AVARulePackageRegistry.RulePackageModules({
            attributionModule: attributionModule,
            verificationModule: verificationModule,
            allocationModule: allocationAdapter,
            transitionRuleModule: transitionRuleModule,
            disclosureModule: disclosurePolicyModule,
            standingAdapter: standingAdapter,
            consequenceAdapter: consequenceAdapter,
            rewardAdapter: rewardAdapter,
            priorityAdapter: priorityAdapter,
            penaltyAdapter: penaltyAdapter,
            restorationAdapter: restorationAdapter,
            challengeLifecycleModule: challengeLifecycleModule,
            evidencePolicyModule: evidencePolicyModule,
            auditAdapter: auditAdapter,
            editorialSystemAdapter: editorialSystemAdapter,
            residualEditorialAuthorityModule: residualEditorialAuthorityModule,
            fieldPolicyModule: fieldPolicyModule,
            antiAbuseModule: antiAbuseModule,
            valueExecutionAdapter: valueExecutionAdapter,
            standingComputationModule: standingComputationModule,
            rulePackageLifecycleModule: rulePackageLifecycleModule,
            evidenceLifecycleModule: evidenceLifecycleModule,
            disclosureLifecycleModule: disclosureLifecycleModule,
                disclosureExecutionModule: disclosureExecutionModule,
            version: 1,
            compatibilityKey: keccak256("ava-default-compatible"),
            dependencyURI: "",
            deprecated: false
        });
    }

    function _registerRulePackage(
        bytes32 workflowKey,
        IDisclosurePolicyModule disclosureModule,
        IAVAAllocationModule allocationModule,
        IConsequenceAdapter consequenceModule,
        string memory uri
    ) internal {
        rulePackageRegistry.registerRulePackage(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVARulePackageRegistry.RulePackageModules({
                attributionModule: attributionModule,
                verificationModule: verificationModule,
                allocationModule: allocationModule,
                transitionRuleModule: transitionRuleModule,
                disclosureModule: disclosureModule,
                standingAdapter: standingAdapter,
                consequenceAdapter: consequenceModule,
                rewardAdapter: rewardAdapter,
                priorityAdapter: priorityAdapter,
                penaltyAdapter: penaltyAdapter,
                restorationAdapter: restorationAdapter,
                challengeLifecycleModule: challengeLifecycleModule,
                evidencePolicyModule: evidencePolicyModule,
                auditAdapter: auditAdapter,
                editorialSystemAdapter: editorialSystemAdapter,
                residualEditorialAuthorityModule: residualEditorialAuthorityModule,
                fieldPolicyModule: fieldPolicyModule,
                antiAbuseModule: antiAbuseModule,
                valueExecutionAdapter: valueExecutionAdapter,
                standingComputationModule: standingComputationModule,
                rulePackageLifecycleModule: rulePackageLifecycleModule,
                evidenceLifecycleModule: evidenceLifecycleModule,
                disclosureLifecycleModule: disclosureLifecycleModule,
                disclosureExecutionModule: disclosureExecutionModule,
                version: 1,
                compatibilityKey: keccak256("ava-m4-10-compatible"),
                dependencyURI: "",
                deprecated: false
            }),
            uri
        );
    }

    function _registerRulePackageWithModules(
        bytes32 workflowKey,
        IAttributionModule attribution,
        IVerificationModule verification,
        ITransitionRuleModule transition,
        IDisclosurePolicyModule disclosureModule,
        IAVAAllocationModule allocationModule,
        IConsequenceAdapter consequenceModule,
        string memory uri
    ) internal {
        rulePackageRegistry.registerRulePackage(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVARulePackageRegistry.RulePackageModules({
                attributionModule: attribution,
                verificationModule: verification,
                allocationModule: allocationModule,
                transitionRuleModule: transition,
                disclosureModule: disclosureModule,
                standingAdapter: standingAdapter,
                consequenceAdapter: consequenceModule,
                rewardAdapter: rewardAdapter,
                priorityAdapter: priorityAdapter,
                penaltyAdapter: penaltyAdapter,
                restorationAdapter: restorationAdapter,
                challengeLifecycleModule: challengeLifecycleModule,
                evidencePolicyModule: evidencePolicyModule,
                auditAdapter: auditAdapter,
                editorialSystemAdapter: editorialSystemAdapter,
                residualEditorialAuthorityModule: residualEditorialAuthorityModule,
                fieldPolicyModule: fieldPolicyModule,
                antiAbuseModule: antiAbuseModule,
                valueExecutionAdapter: valueExecutionAdapter,
                standingComputationModule: standingComputationModule,
                rulePackageLifecycleModule: rulePackageLifecycleModule,
                evidenceLifecycleModule: evidenceLifecycleModule,
                disclosureLifecycleModule: disclosureLifecycleModule,
                disclosureExecutionModule: disclosureExecutionModule,
                version: 1,
                compatibilityKey: keccak256("ava-m4-10-compatible"),
                dependencyURI: "",
                deprecated: false
            }),
            uri
        );
    }

    function _registerRulePackageWithAdapters(
        bytes32 workflowKey,
        IAVAAllocationModule allocationModule,
        IConsequenceAdapter consequenceModule,
        IStandingAdapter standingModule,
        IRewardAdapter rewardModule,
        IPriorityAdapter priorityModule,
        IPenaltyAdapter penaltyModule,
        IRestorationAdapter restorationModule,
        string memory uri
    ) internal {
        rulePackageRegistry.registerRulePackage(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVARulePackageRegistry.RulePackageModules({
                attributionModule: attributionModule,
                verificationModule: verificationModule,
                allocationModule: allocationModule,
                transitionRuleModule: transitionRuleModule,
                disclosureModule: disclosurePolicyModule,
                standingAdapter: standingModule,
                consequenceAdapter: consequenceModule,
                rewardAdapter: rewardModule,
                priorityAdapter: priorityModule,
                penaltyAdapter: penaltyModule,
                restorationAdapter: restorationModule,
                challengeLifecycleModule: challengeLifecycleModule,
                evidencePolicyModule: evidencePolicyModule,
                auditAdapter: auditAdapter,
                editorialSystemAdapter: editorialSystemAdapter,
                residualEditorialAuthorityModule: residualEditorialAuthorityModule,
                fieldPolicyModule: fieldPolicyModule,
                antiAbuseModule: antiAbuseModule,
                valueExecutionAdapter: valueExecutionAdapter,
                standingComputationModule: standingComputationModule,
                rulePackageLifecycleModule: rulePackageLifecycleModule,
                evidenceLifecycleModule: evidenceLifecycleModule,
                disclosureLifecycleModule: disclosureLifecycleModule,
                disclosureExecutionModule: disclosureExecutionModule,
                version: 1,
                compatibilityKey: keccak256("ava-m4-10-compatible"),
                dependencyURI: "",
                deprecated: false
            }),
            uri
        );
    }

    function _registerRulePackageWithLifecycle(
        bytes32 workflowKey,
        IChallengeLifecycleModule lifecycleModule,
        string memory uri
    ) internal {
        rulePackageRegistry.registerRulePackage(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVARulePackageRegistry.RulePackageModules({
                attributionModule: attributionModule,
                verificationModule: verificationModule,
                allocationModule: allocationAdapter,
                transitionRuleModule: transitionRuleModule,
                disclosureModule: disclosurePolicyModule,
                standingAdapter: standingAdapter,
                consequenceAdapter: consequenceAdapter,
                rewardAdapter: rewardAdapter,
                priorityAdapter: priorityAdapter,
                penaltyAdapter: penaltyAdapter,
                restorationAdapter: restorationAdapter,
                challengeLifecycleModule: lifecycleModule,
                evidencePolicyModule: evidencePolicyModule,
                auditAdapter: auditAdapter,
                editorialSystemAdapter: editorialSystemAdapter,
                residualEditorialAuthorityModule: residualEditorialAuthorityModule,
                fieldPolicyModule: fieldPolicyModule,
                antiAbuseModule: antiAbuseModule,
                valueExecutionAdapter: valueExecutionAdapter,
                standingComputationModule: standingComputationModule,
                rulePackageLifecycleModule: rulePackageLifecycleModule,
                evidenceLifecycleModule: evidenceLifecycleModule,
                disclosureLifecycleModule: disclosureLifecycleModule,
                disclosureExecutionModule: disclosureExecutionModule,
                version: 1,
                compatibilityKey: keccak256("ava-m4-10-compatible"),
                dependencyURI: "",
                deprecated: false
            }),
            uri
        );
    }

    function _registerRulePackageWithInfrastructure(
        bytes32 workflowKey,
        IEvidencePolicyModule evidenceModule,
        IAuditAdapter auditModule_,
        IEditorialSystemAdapter editorialModule,
        IFieldPolicyModule fieldModule,
        IAntiAbuseModule abuseModule,
        string memory uri
    ) internal {
        rulePackageRegistry.registerRulePackage(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVARulePackageRegistry.RulePackageModules({
                attributionModule: attributionModule,
                verificationModule: verificationModule,
                allocationModule: allocationAdapter,
                transitionRuleModule: transitionRuleModule,
                disclosureModule: disclosurePolicyModule,
                standingAdapter: standingAdapter,
                consequenceAdapter: consequenceAdapter,
                rewardAdapter: rewardAdapter,
                priorityAdapter: priorityAdapter,
                penaltyAdapter: penaltyAdapter,
                restorationAdapter: restorationAdapter,
                challengeLifecycleModule: challengeLifecycleModule,
                evidencePolicyModule: evidenceModule,
                auditAdapter: auditModule_,
                editorialSystemAdapter: editorialModule,
                residualEditorialAuthorityModule: residualEditorialAuthorityModule,
                fieldPolicyModule: fieldModule,
                antiAbuseModule: abuseModule,
                valueExecutionAdapter: valueExecutionAdapter,
                standingComputationModule: standingComputationModule,
                rulePackageLifecycleModule: rulePackageLifecycleModule,
                evidenceLifecycleModule: evidenceLifecycleModule,
                disclosureLifecycleModule: disclosureLifecycleModule,
                disclosureExecutionModule: disclosureExecutionModule,
                version: 1,
                compatibilityKey: keccak256("ava-m4-10-compatible"),
                dependencyURI: "",
                deprecated: false
            }),
            uri
        );
    }

    function _registerRulePackageWithResidualAuthority(
        bytes32 workflowKey,
        IResidualEditorialAuthorityModule residualModule,
        string memory uri
    ) internal {
        rulePackageRegistry.registerRulePackage(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVARulePackageRegistry.RulePackageModules({
                attributionModule: attributionModule,
                verificationModule: verificationModule,
                allocationModule: allocationAdapter,
                transitionRuleModule: transitionRuleModule,
                disclosureModule: disclosurePolicyModule,
                standingAdapter: standingAdapter,
                consequenceAdapter: consequenceAdapter,
                rewardAdapter: rewardAdapter,
                priorityAdapter: priorityAdapter,
                penaltyAdapter: penaltyAdapter,
                restorationAdapter: restorationAdapter,
                challengeLifecycleModule: challengeLifecycleModule,
                evidencePolicyModule: evidencePolicyModule,
                auditAdapter: auditAdapter,
                editorialSystemAdapter: editorialSystemAdapter,
                residualEditorialAuthorityModule: residualModule,
                fieldPolicyModule: fieldPolicyModule,
                antiAbuseModule: antiAbuseModule,
                valueExecutionAdapter: valueExecutionAdapter,
                standingComputationModule: standingComputationModule,
                rulePackageLifecycleModule: rulePackageLifecycleModule,
                evidenceLifecycleModule: evidenceLifecycleModule,
                disclosureLifecycleModule: disclosureLifecycleModule,
                disclosureExecutionModule: disclosureExecutionModule,
                version: 1,
                compatibilityKey: keccak256("ava-m4-16-compatible"),
                dependencyURI: "",
                deprecated: false
            }),
            uri
        );
    }

    function _registerRulePackageWithDisclosureLifecycle(
        bytes32 workflowKey,
        IDisclosureLifecycleModule disclosureLifecycle,
        string memory uri
    ) internal {
        rulePackageRegistry.registerRulePackage(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVARulePackageRegistry.RulePackageModules({
                attributionModule: attributionModule,
                verificationModule: verificationModule,
                allocationModule: allocationAdapter,
                transitionRuleModule: transitionRuleModule,
                disclosureModule: disclosurePolicyModule,
                standingAdapter: standingAdapter,
                consequenceAdapter: consequenceAdapter,
                rewardAdapter: rewardAdapter,
                priorityAdapter: priorityAdapter,
                penaltyAdapter: penaltyAdapter,
                restorationAdapter: restorationAdapter,
                challengeLifecycleModule: challengeLifecycleModule,
                evidencePolicyModule: evidencePolicyModule,
                auditAdapter: auditAdapter,
                editorialSystemAdapter: editorialSystemAdapter,
                residualEditorialAuthorityModule: residualEditorialAuthorityModule,
                fieldPolicyModule: fieldPolicyModule,
                antiAbuseModule: antiAbuseModule,
                valueExecutionAdapter: valueExecutionAdapter,
                standingComputationModule: standingComputationModule,
                rulePackageLifecycleModule: rulePackageLifecycleModule,
                evidenceLifecycleModule: evidenceLifecycleModule,
                disclosureLifecycleModule: disclosureLifecycle,
                disclosureExecutionModule: disclosureExecutionModule,
                version: 1,
                compatibilityKey: keccak256("ava-m4-16-compatible"),
                dependencyURI: "",
                deprecated: false
            }),
            uri
        );
    }

    function _registerRulePackageWithFutureProofModules(
        bytes32 workflowKey,
        IValueExecutionAdapter valueModule,
        IStandingComputationModule standingComputation,
        IRulePackageLifecycleModule lifecycleModule,
        IEvidenceLifecycleModule evidenceLifecycle,
        IDisclosureExecutionModule executionModule,
        uint64 version,
        bytes32 compatibilityKey,
        bool deprecated,
        string memory uri
    ) internal {
        rulePackageRegistry.registerRulePackage(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVARulePackageRegistry.RulePackageModules({
                attributionModule: attributionModule,
                verificationModule: verificationModule,
                allocationModule: allocationAdapter,
                transitionRuleModule: transitionRuleModule,
                disclosureModule: disclosurePolicyModule,
                standingAdapter: standingAdapter,
                consequenceAdapter: consequenceAdapter,
                rewardAdapter: rewardAdapter,
                priorityAdapter: priorityAdapter,
                penaltyAdapter: penaltyAdapter,
                restorationAdapter: restorationAdapter,
                challengeLifecycleModule: challengeLifecycleModule,
                evidencePolicyModule: evidencePolicyModule,
                auditAdapter: auditAdapter,
                editorialSystemAdapter: editorialSystemAdapter,
                residualEditorialAuthorityModule: residualEditorialAuthorityModule,
                fieldPolicyModule: fieldPolicyModule,
                antiAbuseModule: antiAbuseModule,
                valueExecutionAdapter: valueModule,
                standingComputationModule: standingComputation,
                rulePackageLifecycleModule: lifecycleModule,
                evidenceLifecycleModule: evidenceLifecycle,
                disclosureLifecycleModule: disclosureLifecycleModule,
                disclosureExecutionModule: executionModule,
                version: version,
                compatibilityKey: compatibilityKey,
                dependencyURI: "ipfs://m4-10-dependencies",
                deprecated: deprecated
            }),
            uri
        );
    }

    function _registerM49NonDefaultRulePackage(bytes32 workflowKey)
        internal
        returns (AVARulePackageRegistry.RulePackage memory rulePackage)
    {
        rulePackageRegistry.registerRulePackage(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVARulePackageRegistry.RulePackageModules({
                attributionModule: new SubjectSaltAttributionModule(),
                verificationModule: new EvidenceThresholdVerificationModule(2),
                allocationModule: allocationAdapter,
                transitionRuleModule: new NoFrozenTransitionRuleModule(),
                disclosureModule: disclosurePolicyModule,
                standingAdapter: standingAdapter,
                consequenceAdapter: consequenceAdapter,
                rewardAdapter: rewardAdapter,
                priorityAdapter: priorityAdapter,
                penaltyAdapter: penaltyAdapter,
                restorationAdapter: restorationAdapter,
                challengeLifecycleModule: new PanelOnlyChallengeLifecycleModule(),
                evidencePolicyModule: new TypedEvidencePolicyModule(keccak256("m49-evidence-type")),
                auditAdapter: new HashAnchoredAuditAdapter(),
                editorialSystemAdapter: new EditorialReferenceAdapter(),
                residualEditorialAuthorityModule: residualEditorialAuthorityModule,
                fieldPolicyModule: new DisciplineFieldPolicyModule(AVADataTypes.AVAStage.Verification),
                antiAbuseModule: new SubjectRateLimitModule(),
                valueExecutionAdapter: new ClaimEscrowRecordValueAdapter(),
                standingComputationModule: new VectorStandingComputationModule(),
                rulePackageLifecycleModule: new VersionedRulePackageLifecycleModule(1),
                evidenceLifecycleModule: evidenceLifecycleModule,
                disclosureLifecycleModule: disclosureLifecycleModule,
                disclosureExecutionModule: disclosureExecutionModule,
                version: 1,
                compatibilityKey: keccak256("ava-m4-10-compatible"),
                dependencyURI: "ipfs://m4-10-dependencies",
                deprecated: false
            }),
            "ipfs://m49-non-default-workflow"
        );
        return rulePackageRegistry.getRulePackage(workflowKey);
    }

    function _registerM49DownstreamWorkflow(bytes32 workflowKey) internal {
        _registerRulePackageWithAdapters(
            workflowKey,
            allocationAdapter,
            new BoundedConsequenceExampleAdapter(),
            new VectorStandingAdapter(),
            new StablecoinRecordRewardAdapter(),
            new PriorityTokenRecordAdapter(),
            new ProceduralPenaltyRecordAdapter(),
            new RestorationProcedureRecordAdapter(),
            "ipfs://m49-downstream-workflow"
        );
    }

    function _assertM49SecondaryDownstreamExamples(uint256 recognisedStateId, uint256 evidenceId) internal {
        new GenericTokenRecordRewardAdapter().validateRewardRecord(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://m49-generic-token-record",
            address(this)
        );
        new RentedPriorityRecordAdapter().validatePriorityRecord(
            AVADataTypes.Role.ProtocolExecutor,
            recognisedStateId,
            REVIEWER_SUBJECT,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://m49-rented-priority-record",
            address(this)
        );
        new PriorityReturnObligationRecordAdapter().validatePenaltyRecord(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://m49-priority-return-obligation-record",
            address(this)
        );
        new CorrectionRestorationRecordAdapter().validateRestorationRecord(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://m49-correction-restoration",
            address(this)
        );
    }

    function _createApprovalAuthorityContext(string memory seed, uint8 threshold, bytes32 excludedAuthorityId)
        internal
        returns (ApprovalAuthorityContext memory context)
    {
        context.workflowKey = keccak256(bytes(seed));
        context.packageId = rulePackageRegistry.nextRulePackageId();
        _registerRulePackageWithResidualAuthority(
            context.workflowKey,
            new ApprovalReceiptAuthorityModule(
                authorityApprovalRegistry,
                context.packageId,
                AVADataTypes.Role.Panel,
                AVADataTypes.Action.ResolveChallenge,
                threshold,
                excludedAuthorityId
            ),
            string.concat("ipfs://", seed)
        );
        AVARulePackageRegistry.RulePackage memory rulePackage = rulePackageRegistry.getRulePackage(context.workflowKey);
        require(rulePackage.packageId == context.packageId, "approval package id changed");
        context.recognisedStateId = _createChallengeableReviewStateThroughPackage(rulePackage, context.workflowKey);
        context.objectId = bytes32(context.recognisedStateId);
        context.challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            context.workflowKey,
            keccak256(abi.encode(seed, "approval-challenge-evidence")),
            string.concat("ipfs://", seed, "-challenge-evidence"),
            "review-quality-challenge",
            0
        );
        context.challengeId = challengerActor.fileChallenge(
            stateMachine,
            AVADataTypes.Role.Challenger,
            context.workflowKey,
            context.recognisedStateId,
            CHALLENGER_SUBJECT,
            context.challengeEvidenceId,
            0
        );
        stateMachine.screenChallenge(AVADataTypes.Role.Editor, context.challengeId, EDITOR_AUTHORITY);
    }

    function _recordAuthorityApproval(
        Actor actor,
        ApprovalAuthorityContext memory context,
        AVADataTypes.Action action,
        bytes32 objectId,
        bytes32 authorityId
    ) internal returns (uint256) {
        return actor.recordAuthorityApproval(
            authorityApprovalRegistry,
            AVADataTypes.Role.Panel,
            AuthorityApprovalRegistry.ApprovalInput({
                workflowKey: context.workflowKey,
                packageId: context.packageId,
                action: action,
                recognisedStateId: context.recognisedStateId,
                objectId: objectId,
                authorityId: authorityId,
                evidenceReceiptId: context.challengeEvidenceId,
                expiresAt: uint64(block.timestamp + 7 days),
                reasonURI: "ipfs://authority-approval"
            })
        );
    }

    function _createChallengeableReviewStateThroughPackage(
        AVARulePackageRegistry.RulePackage memory rulePackage,
        bytes32 workflowKey
    ) internal returns (uint256 recognisedStateId) {
        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("packaged-review-evidence"),
            "ipfs://packaged-review",
            "review-service-occurrence",
            0
        );
        bytes32 attributedObject = rulePackage.attributionModule.validateAttribution(
            workflowKey,
            AVADataTypes.Role.Reviewer,
            AVADataTypes.AVAStage.Attribution,
            bytes32(manuscriptId),
            REVIEWER_SUBJECT,
            evidenceId
        );
        rulePackage.verificationModule.validateVerification(
            workflowKey,
            AVADataTypes.Role.Reviewer,
            AVADataTypes.AVAStage.Verification,
            attributedObject,
            evidenceId
        );
        uint256 reviewContributionId = reviewerActor.registerReviewContributionWithWorkflow(
            stateMachine, AVADataTypes.Role.Reviewer, workflowKey, manuscriptId, REVIEWER_SUBJECT, evidenceId, 0
        );
        recognisedStateId =
            stateMachine.provisionallyRecogniseReview(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);
        rulePackage.transitionRuleModule.validateTransition(
            workflowKey,
            AVADataTypes.Action.OpenChallengeWindow,
            AVADataTypes.RecognisedStateStatus.Provisional,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            AVADataTypes.ChallengeOutcome.None
        );
        stateMachine.openReviewChallengeWindow(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);
    }

    function _makeSchnorrProof(bytes32 contextHash, uint256 secret, uint256 nonce)
        internal
        view
        returns (IZKProofVerifier.SchnorrProof memory proof)
    {
        IZKProofVerifier.G1Point memory publicKey = _bn254Mul(secret);
        IZKProofVerifier.G1Point memory commitment = _bn254Mul(nonce);
        uint256 challenge = uint256(
            keccak256(
                abi.encodePacked(
                    keccak256("AVA_SCHNORR_DISCLOSURE_V1"),
                    contextHash,
                    publicKey.x,
                    publicKey.y,
                    commitment.x,
                    commitment.y
                )
            )
        ) % BN254_GROUP_ORDER;
        uint256 response = addmod(nonce, mulmod(challenge, secret, BN254_GROUP_ORDER), BN254_GROUP_ORDER);
        proof = IZKProofVerifier.SchnorrProof({publicKey: publicKey, commitment: commitment, response: response});
    }

    function _newZkProofRegistry(IZKProofVerifier verifier) internal returns (ZKProofRegistry) {
        return new ZKProofRegistry(verifier, rulePackageRegistry, disclosureRegistry);
    }

    function _registerZkDisclosureProof(
        ZKProofRegistry proofRegistry,
        bytes32 workflowKey,
        AVADataTypes.Action action,
        bytes32 objectId,
        AVADataTypes.Role actingRole,
        uint256 disclosurePolicyId,
        bytes32 subjectCommitment
    ) internal {
        bytes32 contextHash = proofRegistry.computeDisclosureContextHash(
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            action,
            objectId,
            actingRole,
            disclosurePolicyId,
            subjectCommitment
        );
        proofRegistry.registerProof(
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            action,
            objectId,
            actingRole,
            disclosurePolicyId,
            subjectCommitment,
            _makeSchnorrProof(contextHash, 7, 11)
        );
    }

    function _assertProofCannotRegisterForContext(
        ZKProofRegistry proofRegistry,
        bytes32 workflowKey,
        AVADataTypes.Action action,
        bytes32 objectId,
        AVADataTypes.Role actingRole,
        uint256 disclosurePolicyId,
        bytes32 subjectCommitment,
        IZKProofVerifier.SchnorrProof memory proof,
        string memory message
    ) internal {
        try proofRegistry.registerProof(
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            action,
            objectId,
            actingRole,
            disclosurePolicyId,
            subjectCommitment,
            proof
        ) {
            revert(message);
        } catch {}
    }

    function _assertZkProofCannotReplayAcrossContext(
        ZKProofRegistry proofRegistry,
        bytes32 workflowKey,
        bytes32 objectId,
        uint256 disclosurePolicyId,
        bytes32 subjectCommitment,
        IZKProofVerifier.SchnorrProof memory proof
    ) internal {
        bytes32 replayContextHash = proofRegistry.computeDisclosureContextHash(
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.ResolveChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment
        );
        require(!proofRegistry.hasVerifiedProof(replayContextHash), "proof replayed across action");
        _assertProofCannotRegisterForContext(
            proofRegistry,
            workflowKey,
            AVADataTypes.Action.ResolveChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment,
            proof,
            "proof accepted for wrong context"
        );

        bytes32 otherWorkflowKey = keccak256("m482-replay-other-workflow");
        _ensureWorkflowPackage(otherWorkflowKey);
        _assertProofCannotRegisterForContext(
            proofRegistry,
            otherWorkflowKey,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment,
            proof,
            "proof accepted for wrong workflow"
        );
        _assertProofCannotRegisterForContext(
            proofRegistry,
            workflowKey,
            AVADataTypes.Action.FileChallenge,
            keccak256("m482-replay-other-object"),
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment,
            proof,
            "proof accepted for wrong object"
        );

        uint256 otherDisclosurePolicyId = _registerDisclosurePolicy("m484-replay-other-policy");
        _assertProofCannotRegisterForContext(
            proofRegistry,
            workflowKey,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            otherDisclosurePolicyId,
            subjectCommitment,
            proof,
            "proof accepted for wrong policy"
        );
        _assertProofCannotRegisterForContext(
            proofRegistry,
            workflowKey,
            AVADataTypes.Action.FileChallenge,
            objectId,
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            _subjectCommitmentForSecret(9),
            proof,
            "proof accepted for wrong subject"
        );
    }

    function _assertAnonymousZkChallengePolicyRejected(uint256 challengedPolicyId, string memory seed, string memory message)
        internal
    {
        uint256 zkPolicyId = _registerDisclosurePolicy(string.concat(seed, "-zk-policy"));
        Actor zkChallengerActor = new Actor();
        bytes32 zkChallengerSubject = _subjectCommitmentForSecret(7);
        bytes32 workflowKey = keccak256(bytes(string.concat(seed, "-workflow")));
        roleRegistry.assignRole(
            address(zkChallengerActor), AVADataTypes.Role.Challenger, zkChallengerSubject, "ipfs://m485-zk-challenger"
        );
        _registerRulePackage(
            workflowKey,
            new ZKBackedDisclosureModule(
                disclosureRegistry, _newZkProofRegistry(new SchnorrDisclosureProofVerifier()), zkPolicyId
            ),
            allocationAdapter,
            consequenceAdapter,
            "ipfs://m485-zk"
        );
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 evidenceId = zkChallengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256(bytes(string.concat(seed, "-evidence"))),
            string.concat("ipfs://", seed),
            "anonymous-zk-challenge",
            challengedPolicyId
        );

        _assertActorCannotFileChallenge(
            zkChallengerActor, workflowKey, recognisedStateId, zkChallengerSubject, evidenceId, challengedPolicyId, message
        );
    }

    function _assertActorCannotFileChallenge(
        Actor actor,
        bytes32 workflowKey,
        uint256 recognisedStateId,
        bytes32 subjectId,
        uint256 evidenceId,
        uint256 disclosurePolicyId,
        string memory message
    ) internal {
        try actor.fileChallenge(
            stateMachine,
            AVADataTypes.Role.Challenger,
            workflowKey,
            recognisedStateId,
            subjectId,
            evidenceId,
            disclosurePolicyId
        ) {
            revert(message);
        } catch {}
    }

    function _fileSubjectBoundZkChallenge()
        internal
        returns (uint256 challengeId, ZKBackedDisclosureModule zkModule, ZKProofRegistry proofRegistry)
    {
        uint256 zkPolicyId = _registerDisclosurePolicy("m482-anonymous-zk-policy");
        proofRegistry = _newZkProofRegistry(new SchnorrDisclosureProofVerifier());
        zkModule = new ZKBackedDisclosureModule(disclosureRegistry, proofRegistry, zkPolicyId);
        Actor zkChallengerActor = new Actor();
        bytes32 zkChallengerSubject = _subjectCommitmentForSecret(7);
        roleRegistry.assignRole(
            address(zkChallengerActor), AVADataTypes.Role.Challenger, zkChallengerSubject, "ipfs://zk-challenger"
        );
        bytes32 workflowKey = keccak256("m482-anonymous-zk-workflow");
        _registerRulePackage(workflowKey, zkModule, allocationAdapter, consequenceAdapter, "ipfs://m482-zk");
        uint256 evidenceId = zkChallengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            workflowKey,
            keccak256("m482-zk-challenge-evidence"),
            "ipfs://m482-zk-challenge",
            "anonymous-zk-challenge",
            zkPolicyId
        );
        bytes32 targetObjectId = keccak256("m482-zk-target-state");
        _registerZkDisclosureProof(
            proofRegistry,
            workflowKey,
            AVADataTypes.Action.RegisterRecognisedState,
            targetObjectId,
            AVADataTypes.Role.Editor,
            zkPolicyId,
            zkChallengerSubject
        );
        uint256 recognisedStateId = stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            targetObjectId,
            zkChallengerSubject,
            evidenceId,
            zkPolicyId,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Challengeable
        );
        _registerZkDisclosureProof(
            proofRegistry,
            workflowKey,
            AVADataTypes.Action.FileChallenge,
            bytes32(recognisedStateId),
            AVADataTypes.Role.Challenger,
            zkPolicyId,
            zkChallengerSubject
        );
        challengeId = zkChallengerActor.fileChallenge(
            stateMachine,
            AVADataTypes.Role.Challenger,
            workflowKey,
            recognisedStateId,
            zkChallengerSubject,
            evidenceId,
            zkPolicyId
        );
    }

    function _subjectCommitmentForSecret(uint256 secret) internal view returns (bytes32) {
        IZKProofVerifier.G1Point memory publicKey = _bn254Mul(secret);
        return keccak256(abi.encode(publicKey.x, publicKey.y));
    }

    function _bn254Mul(uint256 scalar) internal view returns (IZKProofVerifier.G1Point memory point) {
        uint256[3] memory input = [uint256(1), uint256(2), scalar];
        uint256[2] memory output;
        bool ok;
        assembly {
            ok := staticcall(gas(), 7, input, 0x60, output, 0x40)
        }
        require(ok, "bn254 mul failed");
        point = IZKProofVerifier.G1Point({x: output[0], y: output[1]});
    }

    function _assertNoSelector(address target, string memory signature) internal view {
        (bool ok,) = target.staticcall(abi.encodeWithSelector(bytes4(keccak256(bytes(signature))), uint256(1)));
        require(!ok, signature);
    }
}
