// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../../src/AVADataTypes.sol";
import {AVAApplicationRegistry} from "../../src/AVAApplicationRegistry.sol";
import {RuleModuleIdentity} from "../../src/interfaces/IRuleModuleIdentity.sol";
import {RoleIdentityRegistry} from "../../src/RoleIdentityRegistry.sol";
import {AuthorityMatrix} from "../../src/AuthorityMatrix.sol";
import {EvidenceCommitmentRegistry} from "../../src/EvidenceCommitmentRegistry.sol";
import {DisclosurePolicyRegistry} from "../../src/DisclosurePolicyRegistry.sol";
import {AVAStateMachine} from "../../src/AVAStateMachine.sol";
import {AVAChallengeWorkflow} from "../../src/AVAChallengeWorkflow.sol";
import {AVAWorkflowValidator} from "../../src/AVAWorkflowValidator.sol";
import {RulePackageIdentityVerifier} from "../../src/RulePackageIdentityVerifier.sol";
import {
    AVARulePackageRegistry,
    IEvidenceReceiptReader,
    IRecognisedStateReader
} from "../../src/AVARulePackageRegistry.sol";
import {AVARulePackageLifecycleRegistry} from "../../src/AVARulePackageLifecycleRegistry.sol";
import {ConsequenceExecutor, IValueSettlementReader} from "../../src/ConsequenceExecutor.sol";
import {StandingRegistry} from "../../src/StandingRegistry.sol";
import {StandingRevisionRegistry} from "../../src/StandingRevisionRegistry.sol";
import {StandingCredentialRegistry} from "../../src/StandingCredentialRegistry.sol";
import {StandingFormulaRegistry} from "../../src/StandingFormulaRegistry.sol";
import {AllocationExecutor} from "../../src/AllocationExecutor.sol";
import {ValueSettlementExecutor} from "../../src/ValueSettlementExecutor.sol";
import {DisclosureAccessExecutor} from "../../src/DisclosureAccessExecutor.sol";
import {ExternalOperationRegistry} from "../../src/ExternalOperationRegistry.sol";
import {
    AuthorityApprovalRegistry,
    IApprovalRecognisedStateReader,
    IApprovalChallengeReader
} from "../../src/AuthorityApprovalRegistry.sol";
import {MockERC20} from "../../src/MockERC20.sol";
import {MockPriorityToken} from "../../src/MockPriorityToken.sol";
import {AttestationAuditModule} from "../../src/AttestationAuditModule.sol";
import {DefaultDisclosurePolicyModule} from "../../src/modules/DefaultDisclosurePolicyModule.sol";
import {DefaultApplicationModule} from "../../src/modules/DefaultApplicationModule.sol";
import {DefaultAllocationAdapter} from "../../src/modules/DefaultAllocationAdapter.sol";
import {DefaultAttributionModule} from "../../src/modules/DefaultAttributionModule.sol";
import {DefaultVerificationModule} from "../../src/modules/DefaultVerificationModule.sol";
import {DefaultTransitionRuleModule} from "../../src/modules/DefaultTransitionRuleModule.sol";
import {DefaultConsequenceAdapter} from "../../src/modules/DefaultConsequenceAdapter.sol";
import {DefaultStandingAdapter} from "../../src/modules/DefaultStandingAdapter.sol";
import {DefaultRewardAdapter} from "../../src/modules/DefaultRewardAdapter.sol";
import {DefaultPriorityAdapter} from "../../src/modules/DefaultPriorityAdapter.sol";
import {DefaultPenaltyAdapter} from "../../src/modules/DefaultPenaltyAdapter.sol";
import {DefaultRestorationAdapter} from "../../src/modules/DefaultRestorationAdapter.sol";
import {DefaultChallengeLifecycleModule} from "../../src/modules/DefaultChallengeLifecycleModule.sol";
import {
    DefaultEvidencePolicyModule,
    DefaultAuditAdapter,
    DefaultEditorialSystemAdapter,
    DefaultResidualEditorialAuthorityModule,
    DefaultFieldPolicyModule,
    DefaultAntiAbuseModule
} from "../../src/modules/DefaultInfrastructureModules.sol";
import {
    DefaultValueExecutionAdapter,
    MockERC20RecoveryValueExecutionAdapter,
    DefaultStandingComputationModule,
    DefaultRulePackageLifecycleModule,
    DefaultEvidenceLifecycleModule,
    DefaultDisclosureLifecycleModule
} from "../../src/modules/DefaultFutureProofModules.sol";
import {
    DefaultDisclosureExecutionModule,
    KindRejectingDisclosureExecutionModule
} from "../../src/modules/DefaultExecutionModules.sol";
import {
    ClaimEscrowRecordValueAdapter,
    VectorStandingComputationModule,
    FormulaV0StandingComputationModule,
    VersionedRulePackageLifecycleModule,
    RejectingEvidenceLifecycleModule,
    RejectingDisclosureLifecycleModule
} from "../../src/modules/ExampleFutureProofModules.sol";
import {
    SubjectSaltAttributionModule,
    EvidenceThresholdVerificationModule,
    NoFrozenTransitionRuleModule,
    PanelOnlyChallengeLifecycleModule,
    TypedEvidencePolicyModule,
    HashAnchoredAuditAdapter,
    EditorialReferenceAdapter,
    ProceduralEditorialAuthorityModule,
    IllustrativeStaticAuthorityShapeModule,
    DisciplineFieldPolicyModule,
    SubjectRateLimitModule,
    MinimumChallengeWindowTransitionModule,
    RestrictionAwareChallengeIntakeModule,
    CredentialGatedPanelModule
} from "../../src/modules/ExampleRuleModules.sol";
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
} from "../../src/modules/ExampleDownstreamAdapters.sol";
import {DoubleBlindDisclosureModule} from "../../src/modules/DoubleBlindDisclosureModule.sol";
import {PanelVisibleDisclosureModule} from "../../src/modules/PanelVisibleDisclosureModule.sol";
import {AnonymousChallengeDisclosureModule} from "../../src/modules/AnonymousChallengeDisclosureModule.sol";
import {VoluntaryRealNameChallengeModule} from "../../src/modules/VoluntaryRealNameChallengeModule.sol";
import {PostRecognitionAuthorRevealModule} from "../../src/modules/PostRecognitionAuthorRevealModule.sol";
import {ZKBackedDisclosureModule} from "../../src/modules/ZKBackedDisclosureModule.sol";
import {ApprovalReceiptAuthorityModule} from "../../src/modules/ApprovalReceiptAuthorityModule.sol";
import {SchnorrDisclosureProofVerifier} from "../../src/SchnorrDisclosureProofVerifier.sol";
import {ZKProofRegistry} from "../../src/ZKProofRegistry.sol";
import {ZKStandingComputationRegistry} from "../../src/ZKStandingComputationRegistry.sol";
import {ZKStandingCredentialRegistry} from "../../src/ZKStandingCredentialRegistry.sol";
import {IDisclosurePolicyModule} from "../../src/interfaces/IDisclosurePolicyModule.sol";
import {IZKProofVerifier} from "../../src/interfaces/IZKProofVerifier.sol";
import {IAttributionModule} from "../../src/interfaces/IAttributionModule.sol";
import {IVerificationModule} from "../../src/interfaces/IVerificationModule.sol";
import {ITransitionRuleModule} from "../../src/interfaces/ITransitionRuleModule.sol";
import {IChallengeWindowRuleModule} from "../../src/interfaces/IChallengeWindowRuleModule.sol";
import {IAVAAllocationModule} from "../../src/interfaces/IAVAAllocationModule.sol";
import {IAllocationAdapter} from "../../src/interfaces/IAllocationAdapter.sol";
import {IConsequenceAdapter} from "../../src/interfaces/IConsequenceAdapter.sol";
import {IStandingAdapter} from "../../src/interfaces/IStandingAdapter.sol";
import {IRewardAdapter} from "../../src/interfaces/IRewardAdapter.sol";
import {IPriorityAdapter} from "../../src/interfaces/IPriorityAdapter.sol";
import {IPenaltyAdapter} from "../../src/interfaces/IPenaltyAdapter.sol";
import {IRestorationAdapter} from "../../src/interfaces/IRestorationAdapter.sol";
import {IChallengeLifecycleModule} from "../../src/interfaces/IChallengeLifecycleModule.sol";
import {IEvidencePolicyModule} from "../../src/interfaces/IEvidencePolicyModule.sol";
import {IAuditAdapter} from "../../src/interfaces/IAuditAdapter.sol";
import {IEditorialSystemAdapter} from "../../src/interfaces/IEditorialSystemAdapter.sol";
import {IResidualEditorialAuthorityModule} from "../../src/interfaces/IResidualEditorialAuthorityModule.sol";
import {IFieldPolicyModule} from "../../src/interfaces/IFieldPolicyModule.sol";
import {IAntiAbuseModule} from "../../src/interfaces/IAntiAbuseModule.sol";
import {IChallengeRateLimitModule} from "../../src/interfaces/IChallengeRateLimitModule.sol";
import {IValueExecutionAdapter} from "../../src/interfaces/IValueExecutionAdapter.sol";
import {IStandingComputationModule} from "../../src/interfaces/IStandingComputationModule.sol";
import {IRulePackageLifecycleModule} from "../../src/interfaces/IRulePackageLifecycleModule.sol";
import {IEvidenceLifecycleModule} from "../../src/interfaces/IEvidenceLifecycleModule.sol";
import {IDisclosureLifecycleModule} from "../../src/interfaces/IDisclosureLifecycleModule.sol";
import {IDisclosureExecutionModule} from "../../src/interfaces/IDisclosureExecutionModule.sol";
import {IStandingCredentialIssuer} from "../../src/interfaces/IStandingCredentialIssuer.sol";
import {IZKStandingCredentialIssuer} from "../../src/interfaces/IZKStandingCredentialIssuer.sol";
import {IStandingFormulaRegistry} from "../../src/interfaces/IStandingFormulaRegistry.sol";

interface Vm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }

    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
    function warp(uint256 timestamp) external;
    function prank(address sender) external;
    function chainId(uint256 newChainId) external;
    function etch(address target, bytes calldata code) external;
}

contract ReentrantSettlementToken {
    ValueSettlementExecutor public executor;
    uint256 public sourceRecordId;
    uint256 public repaymentObligationId;
    uint256 public packageId;
    bytes32 public subjectId;
    bytes32 public authorityId;
    bool public recoveryMode;
    bool public attemptedReentry;
    bool public reentrySucceeded;
    bool public reentryFailed;
    uint256 public standingRevisionObservedDuringCallback;
    AVADataTypes.ValueSettlementStatus public sourceStatusObservedDuringCallback;
    AVADataTypes.ValueSettlementStatus public recoveryStatusObservedDuringCallback;

    mapping(address => uint256) public balanceOf;

    function configure(
        ValueSettlementExecutor executor_,
        uint256 sourceRecordId_,
        uint256 packageId_,
        bytes32 subjectId_,
        bytes32 authorityId_
    ) external {
        executor = executor_;
        sourceRecordId = sourceRecordId_;
        packageId = packageId_;
        subjectId = subjectId_;
        authorityId = authorityId_;
    }

    function configureRecovery(ValueSettlementExecutor executor_, uint256 repaymentObligationId_, bytes32 authorityId_)
        external
    {
        executor = executor_;
        repaymentObligationId = repaymentObligationId_;
        authorityId = authorityId_;
        recoveryMode = true;
        attemptedReentry = false;
        reentrySucceeded = false;
        reentryFailed = false;
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
            if (recoveryMode) {
                recoveryStatusObservedDuringCallback =
                    executor.recoveryTerminalStatusByObligationId(repaymentObligationId);
                try executor.settleClawback(
                    AVADataTypes.Role.ProtocolExecutor, repaymentObligationId, authorityId, "ipfs://reentrant-clawback"
                ) returns (
                    uint256
                ) {
                    reentrySucceeded = true;
                } catch {
                    reentryFailed = true;
                }
            } else {
                sourceStatusObservedDuringCallback = executor.settlementStatusBySourceKey(
                    keccak256(abi.encode(AVADataTypes.ExecutionSourceType.AllocationRecord, sourceRecordId))
                );
                standingRevisionObservedDuringCallback =
                    executor.standingRevisionRegistry().currentRevision(packageId, subjectId);
                try executor.settleTokenTransfer(
                    AVADataTypes.Role.ProtocolExecutor,
                    AVADataTypes.ExecutionSourceType.AllocationRecord,
                    sourceRecordId,
                    authorityId,
                    "ipfs://reentrant-settlement"
                ) returns (
                    uint256
                ) {
                    reentrySucceeded = true;
                } catch {
                    reentryFailed = true;
                }
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

contract MockDisclosurePolicyModule is IDisclosurePolicyModule, RuleModuleIdentity {
    uint256 public immutable BLOCKED_DISCLOSURE_POLICY_ID;

    constructor(uint256 blockedDisclosurePolicyId_) {
        BLOCKED_DISCLOSURE_POLICY_ID = blockedDisclosurePolicyId_;
    }

    function validateDisclosurePolicy(uint256 disclosurePolicyId) external view {
        if (disclosurePolicyId == BLOCKED_DISCLOSURE_POLICY_ID) revert AVADataTypes.InvalidState(disclosurePolicyId);
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
        if (disclosurePolicyId == BLOCKED_DISCLOSURE_POLICY_ID) {
            revert AVADataTypes.InvalidState(disclosurePolicyId);
        }
    }
}

contract StageScopedDisclosureModule is IDisclosurePolicyModule, RuleModuleIdentity {
    AVADataTypes.Action public immutable BLOCKED_ACTION;
    AVADataTypes.AVAStage public immutable BLOCKED_STAGE;
    bytes32 public immutable BLOCKED_OBJECT_ID;

    constructor(AVADataTypes.Action blockedAction_, AVADataTypes.AVAStage blockedStage_, bytes32 blockedObjectId_) {
        BLOCKED_ACTION = blockedAction_;
        BLOCKED_STAGE = blockedStage_;
        BLOCKED_OBJECT_ID = blockedObjectId_;
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
        if (action == BLOCKED_ACTION && stage == BLOCKED_STAGE && objectId == BLOCKED_OBJECT_ID) {
            revert AVADataTypes.InvalidState(disclosurePolicyId);
        }
    }
}

contract MockAllocationAdapter is IAVAAllocationModule, RuleModuleIdentity {
    AVADataTypes.AllocationKind public immutable BLOCKED_ALLOCATION_KIND;

    constructor(AVADataTypes.AllocationKind blockedAllocationKind_) {
        BLOCKED_ALLOCATION_KIND = blockedAllocationKind_;
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
        if (allocationKind == BLOCKED_ALLOCATION_KIND) revert AVADataTypes.InvalidState(recognisedStateId);
    }
}

contract MockConsequenceAdapter is IConsequenceAdapter, RuleModuleIdentity {
    AVADataTypes.ConsequenceKind public immutable BLOCKED_CONSEQUENCE_KIND;

    constructor(AVADataTypes.ConsequenceKind blockedConsequenceKind_) {
        BLOCKED_CONSEQUENCE_KIND = blockedConsequenceKind_;
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
        if (kind == BLOCKED_CONSEQUENCE_KIND) {
            revert AVADataTypes.InvalidState(recognisedStateId);
        }
    }
}

contract MockStandingAdapter is IStandingAdapter, RuleModuleIdentity {
    bytes32 public immutable BLOCKED_DIMENSION_HASH;

    constructor(string memory blockedDimension_) {
        BLOCKED_DIMENSION_HASH = keccak256(bytes(blockedDimension_));
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
        if (keccak256(bytes(dimension)) == BLOCKED_DIMENSION_HASH) {
            revert AVADataTypes.InvalidState(recognisedStateId);
        }
    }
}

contract MockRewardAdapter is IRewardAdapter, RuleModuleIdentity {
    uint256 public immutable BLOCKED_AMOUNT;

    constructor(uint256 blockedAmount_) {
        BLOCKED_AMOUNT = blockedAmount_;
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
        if (amountOrUnits == BLOCKED_AMOUNT) revert AVADataTypes.InvalidState(recognisedStateId);
    }
}

contract MockPriorityAdapter is IPriorityAdapter, RuleModuleIdentity {
    uint256 public immutable BLOCKED_AMOUNT;

    constructor(uint256 blockedAmount_) {
        BLOCKED_AMOUNT = blockedAmount_;
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
        if (amountOrUnits == BLOCKED_AMOUNT) revert AVADataTypes.InvalidState(recognisedStateId);
    }
}

contract MockPenaltyAdapter is IPenaltyAdapter, RuleModuleIdentity {
    bytes32 public immutable BLOCKED_AUTHORITY_ID;

    constructor(bytes32 blockedAuthorityId_) {
        BLOCKED_AUTHORITY_ID = blockedAuthorityId_;
    }

    function validatePenaltyRecord(
        AVADataTypes.Role,
        uint256 recognisedStateId,
        uint256,
        AVADataTypes.GovernanceFindingKind,
        AVADataTypes.ChallengeOutcome,
        bytes32,
        uint256,
        bytes32 authorityId,
        string calldata,
        address
    ) external view {
        if (authorityId == BLOCKED_AUTHORITY_ID) revert AVADataTypes.InvalidState(recognisedStateId);
    }

    function validateStandingPenaltyInput(AVADataTypes.StandingPenaltyValidationContext calldata context)
        external
        view
    {
        if (context.authorityId == BLOCKED_AUTHORITY_ID) {
            revert AVADataTypes.InvalidState(context.penaltyConsequenceId);
        }
    }

    function validateEligibilityRestriction(AVADataTypes.EligibilityRestrictionValidationContext calldata context)
        external
        view
    {
        if (context.authorityId == BLOCKED_AUTHORITY_ID) {
            revert AVADataTypes.InvalidState(context.penaltyConsequenceId);
        }
    }
}

contract MockRestorationAdapter is IRestorationAdapter, RuleModuleIdentity {
    bytes32 public immutable BLOCKED_AUTHORITY_ID;

    constructor(bytes32 blockedAuthorityId_) {
        BLOCKED_AUTHORITY_ID = blockedAuthorityId_;
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
        if (authorityId == BLOCKED_AUTHORITY_ID) revert AVADataTypes.InvalidState(recognisedStateId);
    }
}

contract MockValueExecutionAdapter is IValueExecutionAdapter, RuleModuleIdentity {
    bytes32 public immutable BLOCKED_EXECUTION_REFERENCE;
    address public immutable BLOCKED_ASSET;
    AVADataTypes.ValueExecutionMode public immutable BLOCKED_MODE;

    constructor(
        bytes32 blockedExecutionReference_,
        address blockedAsset_,
        AVADataTypes.ValueExecutionMode blockedMode_
    ) {
        BLOCKED_EXECUTION_REFERENCE = blockedExecutionReference_;
        BLOCKED_ASSET = blockedAsset_;
        BLOCKED_MODE = blockedMode_;
    }

    function validateValueExecution(AVADataTypes.ValueExecutionContext calldata context) external view {
        if (context.mode == AVADataTypes.ValueExecutionMode.None) {
            revert AVADataTypes.InvalidState(context.recognisedStateId);
        }
        if (
            context.executionReference == BLOCKED_EXECUTION_REFERENCE || context.asset == BLOCKED_ASSET
                || context.mode == BLOCKED_MODE
        ) {
            revert AVADataTypes.InvalidState(context.recognisedStateId);
        }
    }
}

contract RejectingStandingComputationModule is IStandingComputationModule, RuleModuleIdentity {
    function validateStandingComputation(AVADataTypes.StandingComputationContext calldata context) external pure {
        revert AVADataTypes.InvalidState(context.recognisedStateId);
    }
}

contract ModulesHashGateRulePackageLifecycleModule is IRulePackageLifecycleModule, RuleModuleIdentity {
    bytes32 public immutable EXPECTED_COMPATIBILITY_KEY;

    constructor(bytes32 expectedCompatibilityKey_) {
        EXPECTED_COMPATIBILITY_KEY = expectedCompatibilityKey_;
    }

    function validateRulePackageLifecycle(RulePackageLifecycleContext calldata context) external view {
        if (
            context.workflowKey == bytes32(0) || context.modulesHash == bytes32(0)
                || context.modulesIdentityHash == bytes32(0) || context.compatibilityKey != EXPECTED_COMPATIBILITY_KEY
                || context.version == 0 || context.deprecated || context.actor == address(0)
        ) {
            revert AVADataTypes.InvalidState(uint256(context.workflowKey));
        }
    }
}

contract TargetAwareRulePackageLifecycleModule is IRulePackageLifecycleModule, RuleModuleIdentity {
    bytes32 public immutable EXPECTED_TARGET_WORKFLOW_KEY;
    uint256 public immutable EXPECTED_TARGET_PACKAGE_ID;
    bytes32 public immutable EXPECTED_TARGET_MODULES_HASH;
    bytes32 public immutable EXPECTED_TARGET_MODULES_IDENTITY_HASH;
    uint64 public immutable EXPECTED_TARGET_VERSION;
    bytes32 public immutable EXPECTED_TARGET_COMPATIBILITY_KEY;

    constructor(
        bytes32 expectedTargetWorkflowKey_,
        uint256 expectedTargetPackageId_,
        bytes32 expectedTargetModulesHash_,
        bytes32 expectedTargetModulesIdentityHash_,
        uint64 expectedTargetVersion_,
        bytes32 expectedTargetCompatibilityKey_
    ) {
        EXPECTED_TARGET_WORKFLOW_KEY = expectedTargetWorkflowKey_;
        EXPECTED_TARGET_PACKAGE_ID = expectedTargetPackageId_;
        EXPECTED_TARGET_MODULES_HASH = expectedTargetModulesHash_;
        EXPECTED_TARGET_MODULES_IDENTITY_HASH = expectedTargetModulesIdentityHash_;
        EXPECTED_TARGET_VERSION = expectedTargetVersion_;
        EXPECTED_TARGET_COMPATIBILITY_KEY = expectedTargetCompatibilityKey_;
    }

    function validateRulePackageLifecycle(RulePackageLifecycleContext calldata context) external view {
        if (
            context.workflowKey == bytes32(0) || context.modulesHash == bytes32(0)
                || context.modulesIdentityHash == bytes32(0) || context.version == 0
                || context.compatibilityKey == bytes32(0) || context.deprecated || context.actor == address(0)
        ) {
            revert AVADataTypes.InvalidState(uint256(context.workflowKey));
        }
        if (context.kind == AVADataTypes.RulePackageLifecycleKind.MigrationReady) {
            if (
                context.targetWorkflowKey != EXPECTED_TARGET_WORKFLOW_KEY
                    || context.targetPackageId != EXPECTED_TARGET_PACKAGE_ID
                    || context.targetModulesHash != EXPECTED_TARGET_MODULES_HASH
                    || context.targetModulesIdentityHash != EXPECTED_TARGET_MODULES_IDENTITY_HASH
                    || context.targetVersion != EXPECTED_TARGET_VERSION
                    || context.targetCompatibilityKey != EXPECTED_TARGET_COMPATIBILITY_KEY
            ) {
                revert AVADataTypes.InvalidState(context.targetPackageId);
            }
        }
    }
}

contract RejectingReadyRulePackageLifecycleModule is IRulePackageLifecycleModule, RuleModuleIdentity {
    function validateRulePackageLifecycle(RulePackageLifecycleContext calldata context) external pure {
        if (context.kind != AVADataTypes.RulePackageLifecycleKind.None) {
            revert AVADataTypes.InvalidState(uint256(context.workflowKey));
        }
    }
}

contract KindScopedEvidenceLifecycleModule is IEvidenceLifecycleModule, RuleModuleIdentity {
    AVADataTypes.EvidenceLifecycleKind public immutable REQUIRED_KIND;

    constructor(AVADataTypes.EvidenceLifecycleKind requiredKind_) {
        REQUIRED_KIND = requiredKind_;
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
            if (kind != REQUIRED_KIND || lifecycleReference == bytes32(0)) {
                revert AVADataTypes.InvalidState(evidenceReceiptId);
            }
            if (kind == AVADataTypes.EvidenceLifecycleKind.ReplacementReady && replacementEvidenceReceiptId == 0) {
                revert AVADataTypes.EmptyValue();
            }
        }
    }
}

contract RejectingAttributionModule is IAttributionModule, RuleModuleIdentity {
    function validateAttribution(AttributionContext calldata) external pure returns (bytes32) {
        revert AVADataTypes.InvalidState(0);
    }
}

contract RejectingVerificationModule is IVerificationModule, RuleModuleIdentity {
    function validateVerification(VerificationContext calldata) external pure {
        revert AVADataTypes.InvalidState(0);
    }
}

contract RejectingTransitionRuleModule is ITransitionRuleModule, RuleModuleIdentity {
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

contract ActionRejectingTransitionRuleModule is ITransitionRuleModule, RuleModuleIdentity {
    AVADataTypes.Action public immutable BLOCKED_ACTION;

    constructor(AVADataTypes.Action blockedAction_) {
        BLOCKED_ACTION = blockedAction_;
    }

    function validateTransition(
        bytes32 workflowKey,
        AVADataTypes.Action action,
        AVADataTypes.RecognisedStateStatus fromStatus,
        AVADataTypes.RecognisedStateStatus,
        AVADataTypes.ChallengeOutcome
    ) external view {
        if (workflowKey == bytes32(0) || fromStatus == AVADataTypes.RecognisedStateStatus.None) {
            revert AVADataTypes.EmptyValue();
        }
        if (action == BLOCKED_ACTION) revert AVADataTypes.InvalidState(uint256(action));
    }
}

contract BareRevertingChallengeWindowTransitionModule is
    ITransitionRuleModule,
    IChallengeWindowRuleModule,
    RuleModuleIdentity
{
    function validateTransition(
        bytes32 workflowKey,
        AVADataTypes.Action,
        AVADataTypes.RecognisedStateStatus fromStatus,
        AVADataTypes.RecognisedStateStatus toStatus,
        AVADataTypes.ChallengeOutcome
    ) external pure {
        if (
            workflowKey == bytes32(0) || fromStatus == AVADataTypes.RecognisedStateStatus.None
                || toStatus == AVADataTypes.RecognisedStateStatus.None
        ) {
            revert AVADataTypes.EmptyValue();
        }
    }

    function supportsChallengeWindowRule() external pure returns (bool) {
        return true;
    }

    function validateChallengeWindowDuration(bytes32, uint256, uint64, uint64, address) external pure {
        revert();
    }
}

contract RejectingChallengeLifecycleModule is IChallengeLifecycleModule, RuleModuleIdentity {
    AVADataTypes.Action public immutable BLOCKED_ACTION;

    constructor(AVADataTypes.Action blockedAction_) {
        BLOCKED_ACTION = blockedAction_;
    }

    function validateChallengeAction(ChallengeLifecycleContext calldata context) external view {
        if (context.action == BLOCKED_ACTION) revert AVADataTypes.InvalidState(uint256(context.action));
    }
}

contract PermissiveChallengeLifecycleModule is IChallengeLifecycleModule, RuleModuleIdentity {
    function validateChallengeAction(ChallengeLifecycleContext calldata) external pure {}
}

contract RejectingEvidencePolicyModule is IEvidencePolicyModule, RuleModuleIdentity {
    AVADataTypes.Action public immutable BLOCKED_ACTION;

    constructor(AVADataTypes.Action blockedAction_) {
        BLOCKED_ACTION = blockedAction_;
    }

    function validateEvidencePolicy(
        bytes32,
        AVADataTypes.Role,
        AVADataTypes.Action action,
        uint256 evidenceReceiptId,
        bytes32,
        address
    ) external view {
        if (action == BLOCKED_ACTION) revert AVADataTypes.InvalidState(evidenceReceiptId);
    }
}

contract RejectingFieldPolicyModule is IFieldPolicyModule, RuleModuleIdentity {
    function validateFieldPolicy(
        bytes32,
        AVADataTypes.Role,
        AVADataTypes.Action,
        AVADataTypes.AVAStage,
        bytes32,
        uint256
    ) external pure {
        revert AVADataTypes.InvalidState(0);
    }
}

contract RejectingAntiAbuseModule is IAntiAbuseModule, RuleModuleIdentity {
    AVADataTypes.Action public immutable BLOCKED_ACTION;

    constructor(AVADataTypes.Action blockedAction_) {
        BLOCKED_ACTION = blockedAction_;
    }

    function validateUse(bytes32, AVADataTypes.Role, AVADataTypes.Action action, bytes32, bytes32, address)
        external
        view
    {
        if (action == BLOCKED_ACTION) revert AVADataTypes.InvalidState(uint256(action));
    }
}

contract MutableIdentityAntiAbuseModule is IAntiAbuseModule, RuleModuleIdentity {
    AVADataTypes.Action public blockedAction;

    constructor(AVADataTypes.Action blockedAction_) {
        blockedAction = blockedAction_;
    }

    function setBlockedAction(AVADataTypes.Action blockedAction_) external {
        blockedAction = blockedAction_;
    }

    function validateUse(bytes32, AVADataTypes.Role, AVADataTypes.Action action, bytes32, bytes32, address)
        external
        view
    {
        if (action == blockedAction) revert AVADataTypes.InvalidState(uint256(action));
    }

    function _moduleConfigurationHash() internal view override returns (bytes32) {
        return keccak256(abi.encode(blockedAction));
    }
}

contract BareRevertingChallengeRateLimitModule is IAntiAbuseModule, IChallengeRateLimitModule, RuleModuleIdentity {
    function validateUse(
        bytes32 workflowKey,
        AVADataTypes.Role,
        AVADataTypes.Action,
        bytes32 subjectId,
        bytes32 objectId,
        address actor
    ) external pure {
        if (workflowKey == bytes32(0) || subjectId == bytes32(0) || objectId == bytes32(0) || actor == address(0)) {
            revert AVADataTypes.EmptyValue();
        }
    }

    function supportsChallengeRateLimit() external pure returns (bool) {
        return true;
    }

    function validateChallengeFiling(bytes32, uint256, bytes32, uint256, address) external pure {
        revert();
    }
}

contract RejectingAuditAdapter is IAuditAdapter, RuleModuleIdentity {
    function validateAuditRecord(bytes32, AVADataTypes.Role, AVADataTypes.Action, bytes32, uint256, bytes32, address)
        external
        pure
    {
        revert AVADataTypes.InvalidState(0);
    }
}

contract RejectingEditorialSystemAdapter is IEditorialSystemAdapter, RuleModuleIdentity {
    function validateEditorialReference(
        bytes32,
        AVADataTypes.Role,
        AVADataTypes.Action,
        bytes32,
        string calldata,
        address
    ) external pure {
        revert AVADataTypes.InvalidState(0);
    }
}

contract RejectingResidualEditorialAuthorityModule is IResidualEditorialAuthorityModule, RuleModuleIdentity {
    AVADataTypes.Action public immutable BLOCKED_ACTION;

    constructor(AVADataTypes.Action blockedAction_) {
        BLOCKED_ACTION = blockedAction_;
    }

    function validateResidualEditorialAuthority(ResidualEditorialAuthorityContext calldata context) external view {
        if (context.action == BLOCKED_ACTION) revert AVADataTypes.InvalidState(uint256(context.action));
    }
}

contract Actor {
    bytes32 private constant PEER_REVIEW_APP_ID = keccak256("peer-review-app");
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

    function approveToken(MockERC20 token, address spender, uint256 amount) external {
        token.approve(spender, amount);
    }

    function registerEvidenceReceipt(
        EvidenceCommitmentRegistry registry,
        AVADataTypes.Role actingRole,
        bytes32 commitment,
        string calldata uri,
        string calldata evidenceType,
        uint256 disclosurePolicyId
    ) external returns (uint256) {
        return registry.registerEvidenceReceipt(
            actingRole, PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW, commitment, uri, evidenceType, disclosurePolicyId
        );
    }

    function registerEvidenceReceiptForApplication(
        EvidenceCommitmentRegistry registry,
        AVADataTypes.Role actingRole,
        bytes32 appId,
        bytes32 workflowKey,
        bytes32 commitment,
        string calldata uri,
        string calldata evidenceType,
        uint256 disclosurePolicyId
    ) external returns (uint256) {
        return registry.registerEvidenceReceipt(
            actingRole, appId, workflowKey, commitment, uri, evidenceType, disclosurePolicyId
        );
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
        return registry.registerEvidenceReceipt(
            actingRole, PEER_REVIEW_APP_ID, workflowKey, commitment, uri, evidenceType, disclosurePolicyId
        );
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
            actingRole,
            PEER_REVIEW_APP_ID,
            workflowKey,
            evidenceReceiptId,
            kind,
            replacementEvidenceReceiptId,
            lifecycleReference,
            uri
        );
    }

    function registerManuscript(
        AVAStateMachine stateMachine,
        AVADataTypes.Role actingRole,
        bytes32 offchainRef,
        string calldata uri
    ) external returns (uint256) {
        return stateMachine.registerManuscript(actingRole, PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW, offchainRef, uri, "");
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
            actingRole,
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            manuscriptId,
            reviewerSubjectId,
            evidenceReceiptId,
            disclosurePolicyId
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
            actingRole,
            PEER_REVIEW_APP_ID,
            workflowKey,
            manuscriptId,
            reviewerSubjectId,
            evidenceReceiptId,
            disclosurePolicyId
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
        AVAChallengeWorkflow challengeWorkflow,
        AVADataTypes.Role actingRole,
        uint256 challengedRecognisedStateId,
        bytes32 challengerSubjectId,
        uint256 evidenceReceiptId,
        uint256 disclosurePolicyId
    ) external returns (uint256) {
        return challengeWorkflow.fileChallenge(
            actingRole,
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            challengedRecognisedStateId,
            challengerSubjectId,
            evidenceReceiptId,
            disclosurePolicyId
        );
    }

    function fileChallengeForApplication(
        AVAChallengeWorkflow challengeWorkflow,
        AVADataTypes.Role actingRole,
        bytes32 appId,
        bytes32 workflowKey,
        uint256 challengedRecognisedStateId,
        bytes32 challengerSubjectId,
        uint256 evidenceReceiptId,
        uint256 disclosurePolicyId
    ) external returns (uint256) {
        return challengeWorkflow.fileChallenge(
            actingRole,
            appId,
            workflowKey,
            challengedRecognisedStateId,
            challengerSubjectId,
            evidenceReceiptId,
            disclosurePolicyId
        );
    }

    function fileChallenge(
        AVAChallengeWorkflow challengeWorkflow,
        AVADataTypes.Role actingRole,
        bytes32 workflowKey,
        uint256 challengedRecognisedStateId,
        bytes32 challengerSubjectId,
        uint256 evidenceReceiptId,
        uint256 disclosurePolicyId
    ) external returns (uint256) {
        return challengeWorkflow.fileChallenge(
            actingRole,
            PEER_REVIEW_APP_ID,
            workflowKey,
            challengedRecognisedStateId,
            challengerSubjectId,
            evidenceReceiptId,
            disclosurePolicyId
        );
    }

    function resolveChallenge(
        AVAChallengeWorkflow challengeWorkflow,
        AVADataTypes.Role actingRole,
        uint256 challengeId,
        AVADataTypes.ChallengeOutcome outcome,
        AVADataTypes.RecognisedStateStatus toStatus,
        bytes32 authorityId,
        string calldata reasonURI
    ) external {
        challengeWorkflow.resolveChallenge(actingRole, challengeId, outcome, toStatus, authorityId, reasonURI);
    }

    function screenChallenge(
        AVAChallengeWorkflow challengeWorkflow,
        AVADataTypes.Role actingRole,
        uint256 challengeId,
        bytes32 authorityId
    ) external {
        challengeWorkflow.screenChallenge(actingRole, challengeId, authorityId);
    }

    function applyRestoration(
        AVAChallengeWorkflow challengeWorkflow,
        AVADataTypes.Role actingRole,
        uint256 challengeId,
        bytes32 authorityId,
        string calldata reasonURI
    ) external {
        challengeWorkflow.applyRestoration(actingRole, challengeId, authorityId, reasonURI);
    }

    function closeChallenge(
        AVAChallengeWorkflow challengeWorkflow,
        AVADataTypes.Role actingRole,
        uint256 challengeId,
        bytes32 authorityId,
        string calldata reasonURI
    ) external {
        challengeWorkflow.closeChallenge(actingRole, challengeId, authorityId, reasonURI);
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
        registry.invalidateStandingComputationStatement(actingRole, statementId, evidenceReceiptId, authorityId, uri);
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

abstract contract AVASkeletonFixture {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    RoleIdentityRegistry roleRegistry;
    AuthorityMatrix authorityMatrix;
    AVAApplicationRegistry applicationRegistry;
    DefaultApplicationModule applicationModule;
    DefaultDisclosurePolicyModule disclosurePolicyModule;
    EvidenceCommitmentRegistry evidenceRegistry;
    DisclosurePolicyRegistry disclosureRegistry;
    AVAStateMachine stateMachine;
    AVAChallengeWorkflow challengeWorkflow;
    AVAWorkflowValidator workflowValidator;
    AVARulePackageRegistry rulePackageRegistry;
    AVARulePackageLifecycleRegistry rulePackageLifecycleRegistry;
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
    StandingRevisionRegistry standingRevisionRegistry;
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
    bytes32 constant PEER_REVIEW_APP_ID = keccak256("peer-review-app");
    bytes32 constant DEFAULT_WORKFLOW = keccak256("default-review-workflow");
    uint256 constant BN254_GROUP_ORDER = 21888242871839275222246405745257275088548364400416034343698204186575808495617;

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

    function setUp() public virtual {
        roleRegistry = new RoleIdentityRegistry();
        authorityMatrix = new AuthorityMatrix(roleRegistry);
        applicationRegistry = new AVAApplicationRegistry();
        applicationRegistry.registerApplication(
            PEER_REVIEW_APP_ID,
            keccak256("peer-review-application-identity-v1"),
            keccak256("peer-review-application-authority"),
            "ipfs://peer-review-application"
        );
        applicationModule = new DefaultApplicationModule(PEER_REVIEW_APP_ID);
        disclosureRegistry = new DisclosurePolicyRegistry(authorityMatrix, applicationRegistry);
        disclosurePolicyModule = new DefaultDisclosurePolicyModule(disclosureRegistry);
        rulePackageRegistry =
            new AVARulePackageRegistry(authorityMatrix, applicationRegistry, new RulePackageIdentityVerifier());
        evidenceRegistry = new EvidenceCommitmentRegistry(
            authorityMatrix, disclosurePolicyModule, disclosureRegistry, rulePackageRegistry
        );
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
        penaltyAdapter = new DefaultPenaltyAdapter(100, 30 days);
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
        workflowValidator = new AVAWorkflowValidator(rulePackageRegistry, evidenceRegistry, disclosureRegistry);
        standingRevisionRegistry = new StandingRevisionRegistry(authorityMatrix, rulePackageRegistry, evidenceRegistry);
        stateMachine = new AVAStateMachine(
            authorityMatrix, rulePackageRegistry, workflowValidator, standingRevisionRegistry, 1 days
        );
        challengeWorkflow = new AVAChallengeWorkflow(
            authorityMatrix, rulePackageRegistry, workflowValidator, stateMachine, standingRevisionRegistry
        );
        stateMachine.bindChallengeWorkflow(address(challengeWorkflow));
        rulePackageLifecycleRegistry = new AVARulePackageLifecycleRegistry(
            authorityMatrix,
            rulePackageRegistry,
            disclosureRegistry,
            IRecognisedStateReader(address(stateMachine)),
            IEvidenceReceiptReader(address(evidenceRegistry))
        );
        authorityApprovalRegistry.bindTargetReaders(
            IApprovalRecognisedStateReader(address(stateMachine)), IApprovalChallengeReader(address(challengeWorkflow))
        );
        consequenceExecutor = new ConsequenceExecutor(
            authorityMatrix,
            stateMachine,
            challengeWorkflow,
            rulePackageRegistry,
            evidenceRegistry,
            standingRevisionRegistry
        );
        standingRegistry = new StandingRegistry(
            authorityMatrix, stateMachine, rulePackageRegistry, evidenceRegistry, standingRevisionRegistry
        );
        standingFormulaRegistry = new StandingFormulaRegistry(
            authorityMatrix, rulePackageRegistry, evidenceRegistry, standingRevisionRegistry
        );
        allocationExecutor =
            new AllocationExecutor(authorityMatrix, stateMachine, rulePackageRegistry, evidenceRegistry);
        valueSettlementExecutor = new ValueSettlementExecutor(
            authorityMatrix, allocationExecutor, consequenceExecutor, standingRevisionRegistry
        );
        consequenceExecutor.bindValueSettlementReader(IValueSettlementReader(address(valueSettlementExecutor)));
        standingCredentialRegistry = new StandingCredentialRegistry(
            authorityMatrix,
            stateMachine,
            evidenceRegistry,
            standingRegistry,
            allocationExecutor,
            consequenceExecutor,
            valueSettlementExecutor,
            standingRevisionRegistry
        );
        auditModule = new AttestationAuditModule(
            authorityMatrix, rulePackageRegistry, evidenceRegistry, stateMachine, challengeWorkflow
        );
        zkProofRegistry =
            new ZKProofRegistry(new SchnorrDisclosureProofVerifier(), rulePackageRegistry, disclosureRegistry);
        zkStandingComputationRegistry = new ZKStandingComputationRegistry(
            new SchnorrDisclosureProofVerifier(), rulePackageRegistry, standingFormulaRegistry, standingRevisionRegistry
        );
        zkStandingCredentialRegistry = new ZKStandingCredentialRegistry(
            authorityMatrix,
            zkStandingComputationRegistry,
            valueSettlementExecutor,
            stateMachine,
            challengeWorkflow,
            standingRevisionRegistry
        );
        standingRevisionRegistry.bindWriter(StandingRevisionRegistry.WriterKind.StateMachine, address(stateMachine));
        standingRevisionRegistry.bindWriter(
            StandingRevisionRegistry.WriterKind.ChallengeWorkflow, address(challengeWorkflow)
        );
        standingRevisionRegistry.bindWriter(
            StandingRevisionRegistry.WriterKind.StandingRegistry, address(standingRegistry)
        );
        standingRevisionRegistry.bindWriter(
            StandingRevisionRegistry.WriterKind.ConsequenceExecutor, address(consequenceExecutor)
        );
        standingRevisionRegistry.bindWriter(
            StandingRevisionRegistry.WriterKind.ValueSettlementExecutor, address(valueSettlementExecutor)
        );
        disclosureExecutionModule = new DefaultDisclosureExecutionModule();
        disclosureAccessExecutor = new DisclosureAccessExecutor(
            authorityMatrix,
            rulePackageRegistry,
            evidenceRegistry,
            disclosureRegistry,
            stateMachine,
            challengeWorkflow,
            zkProofRegistry
        );
        externalOperationRegistry = new ExternalOperationRegistry(
            authorityMatrix, stateMachine, challengeWorkflow, evidenceRegistry, allocationExecutor, consequenceExecutor
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
        authorityMatrix.setPermission(
            AVADataTypes.Role.ProtocolExecutor, AVADataTypes.Action.ExecuteValueSettlement, true
        );
        authorityMatrix.setPermission(AVADataTypes.Role.Panel, AVADataTypes.Action.RecordDisclosureExecution, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Challenger, AVADataTypes.Action.RecordDisclosureExecution, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Panel, AVADataTypes.Action.RecordExternalOperation, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Panel, AVADataTypes.Action.IssueStandingCredential, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Panel, AVADataTypes.Action.RevokeStandingCredential, true);
        authorityMatrix.setPermission(AVADataTypes.Role.Panel, AVADataTypes.Action.SupersedeStandingCredential, true);
        authorityMatrix.setPermission(
            AVADataTypes.Role.Panel, AVADataTypes.Action.RecordStandingCredentialSettlement, true
        );
        authorityMatrix.setPermission(AVADataTypes.Role.Panel, AVADataTypes.Action.RegisterStandingFormula, true);
        authorityMatrix.setPermission(
            AVADataTypes.Role.Panel, AVADataTypes.Action.RegisterStandingSourceSetCommitment, true
        );
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
        authorityMatrix.setPermission(
            AVADataTypes.Role.Panel, AVADataTypes.Action.RecordStandingCommitmentRevision, true
        );
        _registerDefaultRulePackage(DEFAULT_WORKFLOW, "ipfs://default-workflow");
    }

    function recordRecoveryTerminalForFuzz(uint256 obligationId, uint8 terminalKind) external returns (uint256) {
        if (terminalKind % 3 == 0) {
            return valueSettlementExecutor.recordFuturePayoutSetoff(
                AVADataTypes.Role.ProtocolExecutor,
                obligationId,
                keccak256("executor-authority"),
                "ipfs://fuzz-terminal-setoff"
            );
        }
        if (terminalKind % 3 == 1) {
            return valueSettlementExecutor.recordWaiver(
                AVADataTypes.Role.ProtocolExecutor,
                obligationId,
                keccak256("executor-authority"),
                "ipfs://fuzz-terminal-waiver"
            );
        }
        return valueSettlementExecutor.recordSatisfaction(
            AVADataTypes.Role.ProtocolExecutor,
            obligationId,
            keccak256("executor-authority"),
            "ipfs://fuzz-terminal-satisfaction"
        );
    }

    function _assertM56OperationTarget(
        bytes32 workflowKey,
        AVADataTypes.ExternalOperationTargetKind targetKind,
        uint256 targetId,
        uint256 evidenceId
    ) internal {
        uint256 operationId =
            externalOperationRegistry.requestOperation(
                AVADataTypes.Role.Panel,
                workflowKey,
                AVADataTypes.ExternalOperationKind.QueueAdjustmentIntent,
                targetKind,
                targetId,
                evidenceId,
                keccak256("panel-authority"),
                "ipfs://m56-target-operation"
            );
        AVADataTypes.ExternalOperationRecord memory operation =
            externalOperationRegistry.getExternalOperation(operationId);
        require(operation.workflowKey == workflowKey, "operation workflow mismatch");
        require(operation.sourceOperationId == 0, "request has source operation");
        require(operation.status == AVADataTypes.ExternalOperationStatus.Requested, "operation not requested");
        require(operation.targetKind == targetKind, "operation target kind mismatch");
        require(operation.targetId == targetId, "operation target id mismatch");
        require(operation.evidenceReceiptId == evidenceId, "operation evidence mismatch");
        require(operation.packageId != 0, "operation package missing");
    }

    function _registerAuthorManuscript() internal returns (uint256) {
        return stateMachine.registerManuscript(
            AVADataTypes.Role.Author,
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            keccak256("manuscript-ref"),
            "ipfs://manuscript",
            ""
        );
    }

    function _registerDisclosurePolicy(string memory label) internal returns (uint256) {
        return disclosureRegistry.registerDisclosurePolicy(
            AVADataTypes.Role.Editor, PEER_REVIEW_APP_ID, label, string.concat("ipfs://", label)
        );
    }

    function _createChallengeableReviewState() internal returns (uint256) {
        return _createChallengeableReviewStateForWorkflow(DEFAULT_WORKFLOW, "review-for-challenge");
    }

    function _createChallengeableReviewStateForWorkflow(bytes32 workflowKey, string memory seed)
        internal
        returns (uint256)
    {
        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256(bytes(seed)),
            string.concat("ipfs://", seed),
            "review-service-occurrence",
            0
        );
        uint256 reviewContributionId = reviewerActor.registerReviewContributionWithWorkflow(
            stateMachine, AVADataTypes.Role.Reviewer, workflowKey, manuscriptId, REVIEWER_SUBJECT, evidenceId, 0
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
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            0
        );
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        return challengeId;
    }

    function _newChallengerActor(string memory seed) internal returns (Actor actor, bytes32 subjectId) {
        actor = new Actor();
        subjectId = keccak256(abi.encode("challenger-subject", seed));
        roleRegistry.assignRole(
            address(actor), AVADataTypes.Role.Challenger, subjectId, string.concat("ipfs://", seed, "-challenger")
        );
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
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            recognisedStateId,
            challengerSubjectId,
            challengeEvidenceId,
            0
        );
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            outcome,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            string.concat("ipfs://", seed, "-resolution")
        );
        transitionId = challengeWorkflow.getChallenge(challengeId).lastTransitionId;
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
            challengeWorkflow, AVADataTypes.Role.Challenger, recognisedStateId, CHALLENGER_SUBJECT, evidenceId, 0
        );
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        challengeWorkflow.resolveChallenge(
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
        require(
            standingCredentialRegistry.nextStandingCredentialId() == nextCredentialId,
            "inactive evidence wrote credential"
        );

        uint256 nextAttestationId = auditModule.nextAttestationId();
        try auditModule.recordAttestation(
            AVADataTypes.Role.Panel,
            DEFAULT_WORKFLOW,
            AVADataTypes.Action.RecordAttestation,
            bytes32(inactiveEvidenceId),
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
        return _registerRecognisedStateForWorkflowStatusWithSubject(
            workflowKey, REVIEWER_SUBJECT, status, evidenceId, seed
        );
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
        ) {
            initialStatus = AVADataTypes.RecognisedStateStatus.Challengeable;
        } else if (status == AVADataTypes.RecognisedStateStatus.Restored) {
            initialStatus = AVADataTypes.RecognisedStateStatus.Registered;
        }
        uint256 recognisedStateId = stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            PEER_REVIEW_APP_ID,
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
                AVADataTypes.Role.Panel,
                recognisedStateId,
                status,
                keccak256("panel-authority"),
                "ipfs://test-transition"
            );
        } else if (
            status == AVADataTypes.RecognisedStateStatus.Downgraded
                || status == AVADataTypes.RecognisedStateStatus.Voided
        ) {
            uint256 challengeId = challengerActor.fileChallenge(
                challengeWorkflow,
                AVADataTypes.Role.Challenger,
                workflowKey,
                recognisedStateId,
                CHALLENGER_SUBJECT,
                evidenceId,
                0
            );
            challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
            challengeWorkflow.resolveChallenge(
                AVADataTypes.Role.Panel,
                challengeId,
                AVADataTypes.ChallengeOutcome.Upheld,
                status,
                keccak256("panel-authority"),
                string.concat("ipfs://", seed, "-challenge-resolution")
            );
            challengeWorkflow.closeChallenge(
                AVADataTypes.Role.Panel,
                challengeId,
                keccak256("panel-authority"),
                string.concat("ipfs://", seed, "-challenge-closed")
            );
        } else if (status == AVADataTypes.RecognisedStateStatus.Restored) {
            stateMachine.transitionRecognisedState(
                AVADataTypes.Role.Panel,
                recognisedStateId,
                AVADataTypes.RecognisedStateStatus.Vested,
                keccak256("panel-authority"),
                string.concat("ipfs://", seed, "-vested")
            );
            uint256 challengeId = challengerActor.fileChallenge(
                challengeWorkflow,
                AVADataTypes.Role.Challenger,
                workflowKey,
                recognisedStateId,
                CHALLENGER_SUBJECT,
                evidenceId,
                0
            );
            challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
            challengeWorkflow.resolveChallenge(
                AVADataTypes.Role.Panel,
                challengeId,
                AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
                AVADataTypes.RecognisedStateStatus.Vested,
                keccak256("panel-authority"),
                string.concat("ipfs://", seed, "-good-faith-resolution")
            );
            challengeWorkflow.applyRestoration(
                AVADataTypes.Role.Panel,
                challengeId,
                keccak256("panel-authority"),
                string.concat("ipfs://", seed, "-restoration")
            );
            challengeWorkflow.closeChallenge(
                AVADataTypes.Role.Panel,
                challengeId,
                keccak256("panel-authority"),
                string.concat("ipfs://", seed, "-challenge-closed")
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
        return status == AVADataTypes.RecognisedStateStatus.Vested
            || status == AVADataTypes.RecognisedStateStatus.Restored
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
        recordId = allocationExecutor.recordRewardValueWithExecution(AVADataTypes.Role.ProtocolExecutor, context);
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

    function _createM425AuthorRewardSettlement(bytes32 workflowKey, string memory seed, MockERC20 token, uint256 amount)
        internal
        returns (uint256 recordId, uint256 settlementId)
    {
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

    function _createM421RecordOnlyRewardSource(bytes32 workflowKey, string memory seed)
        internal
        returns (uint256 recordId)
    {
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
        recordId =
            allocationExecutor.recordAdministrativePriorityWithExecution(AVADataTypes.Role.ProtocolExecutor, context);
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
        return _createResolvedChallengeForWorkflowSubject(DEFAULT_WORKFLOW, subjectId, seed, outcome, toStatus);
    }

    function _createResolvedChallengeForWorkflowSubject(
        bytes32 workflowKey,
        bytes32 subjectId,
        string memory seed,
        AVADataTypes.ChallengeOutcome outcome,
        AVADataTypes.RecognisedStateStatus toStatus
    ) internal returns (uint256 recognisedStateId, uint256 challengeId, uint256 evidenceId) {
        evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256(bytes(string.concat(seed, "-state-evidence"))),
            string.concat("ipfs://", seed, "-state-evidence"),
            "challenge-linked-penalty-state",
            0
        );
        recognisedStateId = stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            PEER_REVIEW_APP_ID,
            workflowKey,
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
            workflowKey,
            keccak256(bytes(string.concat(seed, "-challenge-evidence"))),
            string.concat("ipfs://", seed, "-challenge-evidence"),
            "challenge-linked-penalty-outcome",
            0
        );
        challengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            workflowKey,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            0
        );
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            outcome,
            toStatus,
            keccak256("panel-authority"),
            string.concat("ipfs://", seed, "-resolution")
        );
    }

    function _recordPenaltyForChallenge(
        uint256 recognisedStateId,
        uint256 challengeId,
        AVADataTypes.GovernanceFindingKind findingKind,
        bytes32 subjectId,
        uint256 evidenceReceiptId,
        bytes32 authorityId,
        string memory uri
    ) internal returns (uint256 penaltyId) {
        penaltyId = consequenceExecutor.recordPenalty(
            AVADataTypes.Role.Panel,
            AVADataTypes.PenaltyConsequenceContext({
                challengeId: challengeId, findingKind: findingKind, originSettlementId: 0
            }),
            _valueContext(
                recognisedStateId,
                subjectId,
                1,
                evidenceReceiptId,
                authorityId,
                uri,
                keccak256(bytes(uri)),
                address(0),
                address(0),
                AVADataTypes.ValueExecutionMode.RecordOnly
            )
        );
    }

    function _assertPenaltyValueAdapterRejects(
        uint256 recognisedStateId,
        uint256 challengeId,
        uint256 evidenceReceiptId,
        bytes32 blockedReference
    ) internal {
        try consequenceExecutor.recordPenalty(
            AVADataTypes.Role.Panel,
            AVADataTypes.PenaltyConsequenceContext({
                challengeId: challengeId,
                findingKind: AVADataTypes.GovernanceFindingKind.IrresponsibleReview,
                originSettlementId: 0
            }),
            _valueContext(
                recognisedStateId,
                REVIEWER_SUBJECT,
                1,
                evidenceReceiptId,
                keccak256("panel-authority"),
                "ipfs://m411-blocked-priority",
                blockedReference,
                address(0),
                address(0),
                AVADataTypes.ValueExecutionMode.RecordOnly
            )
        ) {
            revert("penalty bypassed value execution adapter");
        } catch {}
    }

    function _assertPenaltyAdapterRejects(
        uint256 recognisedStateId,
        uint256 challengeId,
        uint256 evidenceReceiptId,
        bytes32 blockedAuthorityId
    ) internal {
        try consequenceExecutor.recordPenalty(
            AVADataTypes.Role.Panel,
            AVADataTypes.PenaltyConsequenceContext({
                challengeId: challengeId,
                findingKind: AVADataTypes.GovernanceFindingKind.IrresponsibleReview,
                originSettlementId: 0
            }),
            _valueContext(
                recognisedStateId,
                REVIEWER_SUBJECT,
                1,
                evidenceReceiptId,
                blockedAuthorityId,
                "ipfs://penalty-adapter-blocked",
                keccak256("penalty-adapter-blocked"),
                address(0),
                address(0),
                AVADataTypes.ValueExecutionMode.RecordOnly
            )
        ) {
            revert("penalty adapter did not reject bound authority");
        } catch {}
    }

    function _createM422StandingComputationRecord(string memory seed, int256 currentValue)
        internal
        returns (uint256 computationId)
    {
        (uint256 recognisedStateId, uint256 evidenceId) = _createM421EligibleState(DEFAULT_WORKFLOW, seed);
        computationId = _recordStandingComputationForState(recognisedStateId, evidenceId, seed, currentValue);
    }

    function _recordStandingComputationForState(
        uint256 recognisedStateId,
        uint256 evidenceId,
        string memory seed,
        int256 currentValue
    ) internal returns (uint256 computationId) {
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

    function _createM121StandingComputationRecord(
        bytes32 workflowKey,
        bytes32 subjectId,
        string memory seed,
        int256 currentValue,
        bytes32 vectorKey
    ) internal returns (uint256 computationId) {
        (uint256 recognisedStateId, uint256 evidenceId) =
            _createM421EligibleStateForSubject(workflowKey, subjectId, seed);
        AVADataTypes.StandingComputationContext memory context;
        context.recognisedStateId = recognisedStateId;
        context.subjectId = subjectId;
        context.dimension = "procedural-governance-weight";
        context.vectorKey = vectorKey;
        context.currentValue = currentValue;
        context.delta = 0;
        context.effectiveAt = block.timestamp;
        context.epoch = standingRegistry.nextStandingComputationRecordId();
        context.sourceRecordSetHash = keccak256(abi.encode(seed, recognisedStateId, evidenceId, subjectId));
        context.computationRuleHash = _m422ComputationRuleHash();
        context.reversible = true;
        context.fieldKey = keccak256("m121-governance-memory-field");
        context.evidenceReceiptId = evidenceId;
        context.authorityId = keccak256("panel-authority");
        context.actor = address(this);
        computationId = standingRegistry.recordStandingComputationReadiness(
            AVADataTypes.Role.Panel, context, string.concat("ipfs://", seed, "-standing-computation")
        );
    }

    function _m121FileChallengeForWorkflow(bytes32 workflowKey, string memory seed)
        internal
        returns (uint256 challengeId)
    {
        uint256 challengedStateId =
            _createChallengeableReviewStateForWorkflow(workflowKey, string.concat(seed, "-state"));
        uint256 evidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            workflowKey,
            keccak256(bytes(string.concat(seed, "-evidence"))),
            string.concat("ipfs://", seed, "-evidence"),
            "review-quality-challenge",
            0
        );
        challengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            workflowKey,
            challengedStateId,
            CHALLENGER_SUBJECT,
            evidenceId,
            0
        );
    }

    function _m121ResolveMaliciousChallenge(bytes32 workflowKey, string memory seed)
        internal
        returns (uint256 challengeId)
    {
        challengeId = _m121FileChallengeForWorkflow(workflowKey, seed);
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.MaliciousOrFabricated,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            string.concat("ipfs://", seed, "-malicious-resolution")
        );
    }

    function _m121CreateChallengeIntakeRestriction(bytes32 workflowKey, uint256 expiresAt, string memory seed)
        internal
        returns (uint256 restrictionId)
    {
        uint256 challengeId = _m121ResolveMaliciousChallenge(workflowKey, string.concat(seed, "-challenge"));
        AVADataTypes.ChallengeRecord memory challenge = challengeWorkflow.getChallenge(challengeId);
        uint256 penaltyEvidenceId = challenge.evidenceReceiptId;
        uint256 penaltyId = _recordPenaltyForChallenge(
            challenge.challengedRecognisedStateId,
            challengeId,
            AVADataTypes.GovernanceFindingKind.MaliciousOrFabricatedChallenge,
            CHALLENGER_SUBJECT,
            penaltyEvidenceId,
            keccak256("panel-authority"),
            string.concat("ipfs://", seed, "-penalty")
        );
        restrictionId = consequenceExecutor.recordEligibilityRestriction(
            AVADataTypes.Role.Panel,
            penaltyId,
            AVADataTypes.EligibilityRestrictionKind.ChallengeIntake,
            expiresAt,
            penaltyEvidenceId,
            keccak256("panel-authority"),
            string.concat("ipfs://", seed)
        );
    }

    function _m121AssertChallengeFilingRejected(bytes32 workflowKey, string memory seed) internal {
        uint256 challengedStateId =
            _createChallengeableReviewStateForWorkflow(workflowKey, string.concat(seed, "-state"));
        uint256 evidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            workflowKey,
            keccak256(bytes(string.concat(seed, "-evidence"))),
            string.concat("ipfs://", seed, "-evidence"),
            "review-quality-challenge",
            0
        );
        uint256 nextChallengeId = challengeWorkflow.nextChallengeId();
        try challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            workflowKey,
            challengedStateId,
            CHALLENGER_SUBJECT,
            evidenceId,
            0
        ) {
            revert("challenge filing was not rejected");
        } catch {}
        require(challengeWorkflow.nextChallengeId() == nextChallengeId, "rejected challenge wrote record");
    }

    function _createM425BoundRecoveryPenalty(bytes32 workflowKey, string memory seed, MockERC20 token, uint256 amount)
        internal
        returns (uint256 originSourceId, uint256 originSettlementId, uint256 penaltyId, uint256 challengeId)
    {
        _registerM425RecoveryWorkflow(workflowKey, token, seed);
        originSourceId = _createM421RewardSource(
            workflowKey, string.concat(seed, "-origin"), token, amount, AVADataTypes.ValueExecutionMode.Claim
        );
        originSettlementId = valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            originSourceId,
            keccak256("executor-authority"),
            string.concat("ipfs://", seed, "-origin-settlement")
        );
        reviewerActor.approveToken(token, address(valueSettlementExecutor), amount);
        challengeId = _fileAndResolveM425OriginChallenge(workflowKey, originSourceId, seed);
        penaltyId = _recordM425ActivePenalty(originSourceId, originSettlementId, challengeId, token, amount, seed);
    }

    function _registerM425RecoveryWorkflow(bytes32 workflowKey, MockERC20 token, string memory seed) internal {
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            new MockERC20RecoveryValueExecutionAdapter(address(token)),
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-post-audit-recovery-compatible"),
            false,
            string.concat("ipfs://", seed, "-recovery-workflow")
        );
    }

    function _fileAndResolveM425OriginChallenge(bytes32 workflowKey, uint256 originSourceId, string memory seed)
        internal
        returns (uint256 challengeId)
    {
        AVADataTypes.AllocationExecutionRecord memory origin = allocationExecutor.getAllocationExecution(originSourceId);
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            workflowKey,
            keccak256(bytes(string.concat(seed, "-challenge-evidence"))),
            string.concat("ipfs://", seed, "-challenge-evidence"),
            "post-settlement-governance-finding",
            0
        );
        challengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            workflowKey,
            origin.recognisedStateId,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            0
        );
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded,
            keccak256("panel-authority"),
            string.concat("ipfs://", seed, "-resolution")
        );
    }

    function _recordM425ActivePenalty(
        uint256 originSourceId,
        uint256 originSettlementId,
        uint256 challengeId,
        MockERC20 token,
        uint256 amount,
        string memory seed
    ) internal returns (uint256 penaltyId) {
        AVADataTypes.AllocationExecutionRecord memory origin = allocationExecutor.getAllocationExecution(originSourceId);
        penaltyId = consequenceExecutor.recordPenalty(
            AVADataTypes.Role.Panel,
            AVADataTypes.PenaltyConsequenceContext({
                challengeId: challengeId,
                findingKind: AVADataTypes.GovernanceFindingKind.IrresponsibleReview,
                originSettlementId: originSettlementId
            }),
            AVADataTypes.ValueExecutionContext({
                recognisedStateId: origin.recognisedStateId,
                asset: address(token),
                payer: address(this),
                recipientSubjectId: REVIEWER_SUBJECT,
                amount: amount,
                mode: AVADataTypes.ValueExecutionMode.Claim,
                settlementKind: AVADataTypes.ValueSettlementKind.ClawbackTransfer,
                executionReference: keccak256(bytes(string.concat(seed, "-clawback"))),
                authorityId: keccak256("panel-authority"),
                evidenceReceiptId: origin.evidenceReceiptId,
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
        require(fraudInput.findingKind == AVADataTypes.GovernanceFindingKind.AcademicFraud, "fraud kind collapsed");
        require(
            reviewInput.findingKind == AVADataTypes.GovernanceFindingKind.IrresponsibleReview, "review kind collapsed"
        );
        require(
            maliciousInput.findingKind == AVADataTypes.GovernanceFindingKind.MaliciousOrFabricatedChallenge,
            "malicious kind collapsed"
        );
        require(
            fraudInput.delta < reviewInput.delta && reviewInput.delta > maliciousInput.delta,
            "penalty severities collapsed"
        );
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
        require(
            standingCredentialRegistry.getStandingCredential(credentialId).status
                == AVADataTypes.StandingCredentialStatus.Active,
            "invalid settlement mutated credential carrier status"
        );
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
        require(
            zkStandingCredentialRegistry.getCredential(credentialId).status
                == AVADataTypes.StandingCredentialStatus.Active,
            "invalid settlement disabled zk credential"
        );
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
        require(
            zkStandingCredentialRegistry.getCredential(credentialId).status
                == AVADataTypes.StandingCredentialStatus.Active,
            "invalid challenge disabled zk credential"
        );
    }

    function _assertM63CannotSupersedeStandingCredential(
        uint256 credentialId,
        IStandingCredentialIssuer.StandingCredentialInput memory input,
        string memory message
    ) internal {
        try standingCredentialRegistry.supersedeCredential(AVADataTypes.Role.Panel, credentialId, input) {
            revert(message);
        } catch {}
        require(
            standingCredentialRegistry.getStandingCredential(credentialId).status
                == AVADataTypes.StandingCredentialStatus.Active,
            "rejected supersession mutated credential carrier status"
        );
    }

    function _issueM422StandingCredential(uint256 computationId, string memory seed, uint256 expiresAt)
        internal
        returns (uint256 credentialId)
    {
        credentialId = standingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m422CredentialInputForComputation(
                computationId, expiresAt, string.concat("ipfs://", seed, "-standing-credential")
            )
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

    function _m422CredentialInput(uint256 computationId, uint256 epoch, uint256 expiresAt, string memory uri)
        internal
        pure
        returns (IStandingCredentialIssuer.StandingCredentialInput memory input)
    {
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

    function _m422CredentialInputForComputation(uint256 computationId, uint256 expiresAt, string memory uri)
        internal
        view
        returns (IStandingCredentialIssuer.StandingCredentialInput memory input)
    {
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
        AVADataTypes.StandingCredentialRecord memory credential =
            standingCredentialRegistry.getStandingCredential(credentialId);
        return standingCredentialRegistry.credentialProvesSubjectStanding(
            credentialId, credential.packageId, REVIEWER_SUBJECT, _m422VectorKey(), _m422CategoryHash(), threshold
        );
    }

    function _m121ResidualContext(bytes32 workflowKey, uint256 recognisedStateId, uint256 evidenceId)
        internal
        view
        returns (IResidualEditorialAuthorityModule.ResidualEditorialAuthorityContext memory context)
    {
        context = IResidualEditorialAuthorityModule.ResidualEditorialAuthorityContext({
            workflowKey: workflowKey,
            packageId: rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).packageId,
            targetPackageId: rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).packageId,
            actingRole: AVADataTypes.Role.Panel,
            action: AVADataTypes.Action.ResolveChallenge,
            recognisedStateId: recognisedStateId,
            challengeId: 1,
            objectId: bytes32(recognisedStateId),
            evidenceReceiptId: evidenceId,
            authorityId: keccak256("panel-authority"),
            decisionHash: keccak256("m121-credential-gate-decision"),
            actor: address(this)
        });
    }

    function _m121CredentialGateFixture(string memory seed, int256 requiredThreshold)
        internal
        returns (
            bytes32 workflowKey,
            CredentialGatedPanelModule module,
            IResidualEditorialAuthorityModule.ResidualEditorialAuthorityContext memory context
        )
    {
        workflowKey = keccak256(bytes(seed));
        module = new CredentialGatedPanelModule(
            standingCredentialRegistry,
            stateMachine,
            AVADataTypes.Action.ResolveChallenge,
            _m422VectorKey(),
            _m422CategoryHash(),
            requiredThreshold
        );
        _registerM121CredentialGateWorkflow(workflowKey, module, string.concat("ipfs://", seed, "-workflow"));
        uint256 contextStateId =
            _createChallengeableReviewStateForWorkflow(workflowKey, string.concat(seed, "-context"));
        uint256 contextEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            workflowKey,
            keccak256(bytes(string.concat(seed, "-context-evidence"))),
            string.concat("ipfs://", seed, "-context-evidence"),
            "review-quality-challenge",
            0
        );
        context = _m121ResidualContext(workflowKey, contextStateId, contextEvidenceId);
    }

    function _registerM121CredentialGateWorkflow(
        bytes32 workflowKey,
        IResidualEditorialAuthorityModule residualModule,
        string memory uri
    ) internal {
        _registerOrSupersedeRulePackage(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVARulePackageRegistry.RulePackageModules({
                applicationModule: applicationModule,
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
                valueExecutionAdapter: new ClaimEscrowRecordValueAdapter(),
                standingComputationModule: standingComputationModule,
                rulePackageLifecycleModule: rulePackageLifecycleModule,
                evidenceLifecycleModule: evidenceLifecycleModule,
                disclosureLifecycleModule: disclosureLifecycleModule,
                disclosureExecutionModule: disclosureExecutionModule,
                version: 1,
                compatibilityKey: keccak256("ava-m12-1-compatible"),
                dependencyURI: "",
                deprecated: false
            }),
            uri
        );
    }

    function _assertM121CredentialGateRejects(
        CredentialGatedPanelModule module,
        IResidualEditorialAuthorityModule.ResidualEditorialAuthorityContext memory context,
        string memory message
    ) internal view {
        try module.validateResidualEditorialAuthority(context) {
            revert(message);
        } catch {}
    }

    function _suspendM121CredentialBySettlement(bytes32 workflowKey, uint256 credentialId, string memory seed)
        internal
    {
        MockERC20 token = _m421FundedToken(10);
        uint256 sourceId = _createM121RewardSourceForSubject(workflowKey, keccak256("panel-authority"), seed, token, 2);
        uint256 settlementId = valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            string.concat("ipfs://", seed, "-settlement")
        );
        standingCredentialRegistry.recordStandingRelevantSettlement(
            AVADataTypes.Role.Panel,
            credentialId,
            AVADataTypes.StandingRelevantSettlementKind.RewardExecution,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            settlementId,
            keccak256("panel-authority"),
            string.concat("ipfs://", seed, "-credential-suspension")
        );
    }

    function _createM121RewardSourceForSubject(
        bytes32 workflowKey,
        bytes32 subjectId,
        string memory seed,
        MockERC20 token,
        uint256 amount
    ) internal returns (uint256 recordId) {
        (uint256 recognisedStateId, uint256 evidenceId) = _createM421EligibleStateForSubject(
            workflowKey, subjectId, string.concat(seed, "-source")
        );
        AVADataTypes.ValueExecutionContext memory context;
        context.recognisedStateId = recognisedStateId;
        context.asset = address(token);
        context.payer = address(this);
        context.recipientSubjectId = subjectId;
        context.amount = amount;
        context.mode = AVADataTypes.ValueExecutionMode.Claim;
        context.settlementKind = AVADataTypes.ValueSettlementKind.TokenTransfer;
        context.executionReference = bytes32(evidenceId);
        context.authorityId = keccak256("executor-authority");
        context.evidenceReceiptId = evidenceId;
        context.uri = string.concat("ipfs://", seed, "-reward-source");
        context.actor = address(this);
        recordId = allocationExecutor.recordRewardValueWithExecution(AVADataTypes.Role.ProtocolExecutor, context);
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
            proofInput.outputCommitmentHash =
                keccak256(abi.encode(seed, proofInput.subjectCommitment, "standing-output"));
        }
        (formulaId, sourceSetCommitmentId) = _registerM68FormulaAndSourceSet(proofInput, seed);
        uint256 statementEvidenceId =
            _registerM68SourceSetEvidence(proofInput.workflowKey, string.concat(seed, "-statement"));
        uint256 attestationId =
            _registerM92SourceSetCompletenessAttestation(sourceSetCommitmentId, statementEvidenceId, seed);
        IStandingFormulaRegistry.StandingComputationStatementInput memory statementInput =
            _m91ComputationStatementInput(sourceSetCommitmentId, attestationId, proofInput, statementEvidenceId, seed);
        statementId =
            standingFormulaRegistry.registerStandingComputationStatement(AVADataTypes.Role.Panel, statementInput);
        proofInput.standingComputationStatementId = statementId;
    }

    function _m95PreparedStatementInput(
        ZKStandingComputationRegistry.StandingProofInput memory proofInput,
        string memory seed
    ) internal returns (IStandingFormulaRegistry.StandingComputationStatementInput memory statementInput) {
        if (proofInput.outputCommitmentHash == bytes32(0)) {
            proofInput.outputCommitmentHash =
                keccak256(abi.encode(seed, proofInput.subjectCommitment, "standing-output"));
        }
        (, uint256 sourceSetCommitmentId) = _registerM68FormulaAndSourceSet(proofInput, seed);
        uint256 statementEvidenceId =
            _registerM68SourceSetEvidence(proofInput.workflowKey, string.concat(seed, "-statement"));
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
        uint256 proofReceiptId =
            zkStandingComputationRegistry.registerStandingProof(proofInput, _makeSchnorrProof(contextHash, 7, 19));
        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory credentialInput =
            _m66CredentialInput(proofReceiptId, packageId, subjectCommitment, "m95-supersede-new");
        uint256 credentialId = zkStandingCredentialRegistry.issueCredential(AVADataTypes.Role.Panel, credentialInput);
        require(_m95ZkCredentialProves(credentialId, packageId, subjectCommitment, 40), "new credential not active");
    }

    function _m68FormulaInput(bytes32 workflowKey, bytes32 vectorKey, bytes32 computationRuleHash, string memory seed)
        internal
        view
        returns (IStandingFormulaRegistry.StandingFormulaInput memory input)
    {
        input = IStandingFormulaRegistry.StandingFormulaInput({
            appId: PEER_REVIEW_APP_ID,
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

    function _registerM68Formula(ZKStandingComputationRegistry.StandingProofInput memory input, string memory seed)
        internal
        returns (uint256 formulaId)
    {
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
            AVADataTypes.Role.Panel, _m68SourceSetCommitmentInput(formulaId, input, evidenceReceiptId, seed)
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
        context.sourceRecordSetHash =
            keccak256(abi.encode(seed, recognisedStateId, evidenceReceiptId, REVIEWER_SUBJECT));
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
            PEER_REVIEW_APP_ID,
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
        uint256 nextChallengeId = challengeWorkflow.nextChallengeId();
        try challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            workflowKey,
            challengedRecognisedStateId,
            CHALLENGER_SUBJECT,
            evidenceReceiptId,
            0
        ) {
            revert(message);
        } catch {}
        require(challengeWorkflow.nextChallengeId() == nextChallengeId, "wrong-package evidence wrote challenge");
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
        require(
            allocationExecutor.nextAllocationExecutionId() == nextAllocationId,
            "wrong-package evidence wrote allocation"
        );
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
        require(
            consequenceExecutor.nextConsequenceId() == nextConsequenceId, "wrong-package evidence wrote consequence"
        );
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
    ) internal returns (uint256 proofReceiptId) {
        ZKStandingComputationRegistry.StandingProofInput memory proofInput =
            _m65StandingProofInput(workflowKey, subjectCommitment, seed);
        proofInput.epoch = epoch;
        proofInput.sourceRecordSetRoot = keccak256(abi.encode(seed, subjectCommitment, epoch, "source-record-set-root"));
        (proofInput,,,) = _bindM93StandingProofInput(proofInput, seed);
        bytes32 contextHash = zkStandingComputationRegistry.computeStandingComputationContextHash(proofInput);
        proofReceiptId =
            zkStandingComputationRegistry.registerStandingProof(proofInput, _makeSchnorrProof(contextHash, 7, 11));
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
        uint256 packageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).packageId;
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
        useRecordId = zkStandingCredentialRegistry.recordCredentialUse(
            input, _makeSchnorrProof(useContext, credentialSecret, nonce)
        );
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
        try zkStandingCredentialRegistry.recordCredentialUse(
            input, _makeSchnorrProof(useContext, credentialSecret, 29)
        ) {
            revert(message);
        } catch {}
    }

    function _m66CredentialUseInput(uint256 credentialId, int256 requiredThreshold, bytes32 targetContext)
        internal
        view
        returns (IZKStandingCredentialIssuer.ZKStandingCredentialUseInput memory input)
    {
        IZKStandingCredentialIssuer.ZKStandingCredentialRecord memory credential =
            zkStandingCredentialRegistry.getCredential(credentialId);
        bytes32 useContext = zkStandingCredentialRegistry.computeCredentialUseContextHash(
            credentialId,
            credential.packageId,
            credential.subjectCommitment,
            credential.vectorKey,
            credential.categoryHash,
            requiredThreshold,
            targetContext,
            address(this)
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
            ),
            beneficiary: address(this)
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
            input.targetContextHash,
            input.beneficiary
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

    function _recordRecoveryTerminalSettlement(uint256 obligationId, uint8 terminalKind)
        internal
        returns (AVADataTypes.ValueSettlementStatus)
    {
        if (terminalKind % 4 == 0) {
            valueSettlementExecutor.recordFuturePayoutSetoff(
                AVADataTypes.Role.ProtocolExecutor,
                obligationId,
                keccak256("executor-authority"),
                "ipfs://fuzz-terminal-setoff"
            );
            return AVADataTypes.ValueSettlementStatus.SetoffRecorded;
        }
        if (terminalKind % 4 == 1) {
            valueSettlementExecutor.recordWaiver(
                AVADataTypes.Role.ProtocolExecutor,
                obligationId,
                keccak256("executor-authority"),
                "ipfs://fuzz-terminal-waiver"
            );
            return AVADataTypes.ValueSettlementStatus.Waived;
        }
        if (terminalKind % 4 == 2) {
            valueSettlementExecutor.recordSatisfaction(
                AVADataTypes.Role.ProtocolExecutor,
                obligationId,
                keccak256("executor-authority"),
                "ipfs://fuzz-terminal-satisfaction"
            );
            return AVADataTypes.ValueSettlementStatus.Satisfied;
        }
        valueSettlementExecutor.settleClawback(
            AVADataTypes.Role.ProtocolExecutor,
            obligationId,
            keccak256("executor-authority"),
            "ipfs://fuzz-terminal-clawback"
        );
        return AVADataTypes.ValueSettlementStatus.Settled;
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

    function _assertDirectHighStatusRegistrationRejected(AVADataTypes.RecognisedStateStatus status, uint256 evidenceId)
        internal
    {
        try stateMachine.registerRecognisedState(
            AVADataTypes.Role.Editor,
            PEER_REVIEW_APP_ID,
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

    function _assertGenericTransitionRejected(uint256 recognisedStateId, AVADataTypes.RecognisedStateStatus toStatus)
        internal
    {
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
            AVADataTypes.PenaltyConsequenceContext({
                challengeId: 0,
                findingKind: AVADataTypes.GovernanceFindingKind.IrresponsibleReview,
                originSettlementId: 0
            }),
            _valueContext(
                recognisedStateId,
                REVIEWER_SUBJECT,
                1,
                evidenceId,
                keccak256("panel-authority"),
                "ipfs://penalty-rejected",
                keccak256("penalty-rejected"),
                address(0),
                address(0),
                AVADataTypes.ValueExecutionMode.RecordOnly
            )
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

    function _assertM4DownstreamRecords(
        uint256 reviewStateId,
        uint256 evidenceId,
        uint256 positiveStateId,
        uint256 positiveEvidenceId
    ) internal {
        bytes32 subjectId = stateMachine.getRecognisedState(reviewStateId).subjectId;
        _assertM4PositiveAllocationRecords(positiveStateId, positiveEvidenceId, subjectId);
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
        AVADataTypes.RecognisedStateRecord memory reviewState = stateMachine.getRecognisedState(reviewStateId);
        (uint256 penaltyStateId, uint256 penaltyChallengeId, uint256 penaltyEvidenceId) = _createResolvedChallengeForWorkflowSubject(
            reviewState.workflowKey,
            subjectId,
            "m4-penalty",
            AVADataTypes.ChallengeOutcome.Upheld,
            AVADataTypes.RecognisedStateStatus.Downgraded
        );
        uint256 penaltyId = _recordPenaltyForChallenge(
            penaltyStateId,
            penaltyChallengeId,
            AVADataTypes.GovernanceFindingKind.IrresponsibleReview,
            subjectId,
            penaltyEvidenceId,
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
            consequenceExecutor.getConsequence(penaltyId).kind == AVADataTypes.ConsequenceKind.PenaltyRecord,
            "penalty kind"
        );
        require(
            consequenceExecutor.getConsequence(restorationId).kind == AVADataTypes.ConsequenceKind.RestorationRecord,
            "restoration kind"
        );
    }

    function _assertM4PositiveAllocationRecords(uint256 stateId, uint256 evidenceId, bytes32 subjectId) internal {
        uint256 rewardId = allocationExecutor.recordRewardValue(
            AVADataTypes.Role.ProtocolExecutor,
            stateId,
            subjectId,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://m4-reward"
        );
        uint256 priorityId = allocationExecutor.recordAdministrativePriority(
            AVADataTypes.Role.ProtocolExecutor,
            stateId,
            subjectId,
            1,
            evidenceId,
            keccak256("executor-authority"),
            "ipfs://m4-priority"
        );
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
        context.packageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, context.workflowKey).packageId;
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
        stateMachine.openReviewChallengeWindow(AVADataTypes.Role.Editor, context.reviewContributionId, EDITOR_AUTHORITY);
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
        require(
            allocationExecutor.getAllocationExecution(allocationId).packageId == packageId, "allocation package wrong"
        );
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
        context.packageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, context.workflowKey).packageId;

        uint256 evidenceId = context.challenger
            .registerEvidenceReceipt(
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
            PEER_REVIEW_APP_ID,
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
            context, AVADataTypes.Action.FileChallenge, bytes32(context.recognisedStateId), AVADataTypes.Role.Challenger
        );
        context.challengeId = context.challenger
            .fileChallenge(
                challengeWorkflow,
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
        proofUseId = context.challenger
            .recordAnonymousChallengeProofUse(
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
            PEER_REVIEW_APP_ID,
            context.workflowKey,
            AVADataTypes.AVAStage.Verification,
            action,
            objectId,
            actingRole,
            context.policyId,
            context.subjectCommitment
        );
        proofReceiptId = zkProofRegistry.registerProof(
            PEER_REVIEW_APP_ID,
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
        context.packageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, context.workflowKey).packageId;
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
            PEER_REVIEW_APP_ID,
            context.workflowKey,
            AVADataTypes.AVAStage.Verification,
            keccak256(bytes(string.concat(seed, "-review-state"))),
            REVIEWER_SUBJECT,
            reviewEvidenceId,
            0,
            EDITOR_AUTHORITY,
            AVADataTypes.RecognisedStateStatus.Registered
        );
        stateMachine.transitionRecognisedState(
            AVADataTypes.Role.Panel,
            context.recognisedStateId,
            AVADataTypes.RecognisedStateStatus.Vested,
            keccak256("panel-authority"),
            string.concat("ipfs://", seed, "-vested")
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
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            context.workflowKey,
            context.recognisedStateId,
            CHALLENGER_SUBJECT,
            context.challengeEvidenceId,
            0
        );
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, context.challengeId, EDITOR_AUTHORITY);
        challengeWorkflow.resolveChallenge(
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
            AVADataTypes.PenaltyConsequenceContext({
                challengeId: 0,
                findingKind: AVADataTypes.GovernanceFindingKind.IrresponsibleReview,
                originSettlementId: 0
            }),
            _valueContext(
                reviewStateId,
                REVIEWER_SUBJECT,
                1,
                reviewEvidenceId,
                reviewBlockedAuthority,
                "ipfs://blocked-review-penalty",
                keccak256("blocked-review-penalty"),
                address(0),
                address(0),
                AVADataTypes.ValueExecutionMode.RecordOnly
            )
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
        try challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY) {
            revert("challenge lifecycle did not reject screen");
        } catch {}
        require(
            challengeWorkflow.getChallenge(challengeId).status == AVADataTypes.ChallengeLifecycleStatus.ConcernFiled,
            "rejected screen changed state"
        );
    }

    function _assertLifecycleModuleRejectsResolve() internal {
        bytes32 workflowKey = keccak256("m47-reject-resolve");
        uint256 challengeId = _fileChallengeForLifecycleWorkflow(workflowKey, AVADataTypes.Action.ResolveChallenge);
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        try challengeWorkflow.resolveChallenge(
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
            challengeWorkflow.getChallenge(challengeId).status
                == AVADataTypes.ChallengeLifecycleStatus.AdmissibilityScreening,
            "rejected resolve changed state"
        );
    }

    function _assertLifecycleModuleRejectsRestoration() internal {
        bytes32 workflowKey = keccak256("m47-reject-restoration");
        uint256 challengeId = _fileChallengeForLifecycleWorkflow(workflowKey, AVADataTypes.Action.ApplyRestoration);
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://m47-good-faith"
        );
        AVADataTypes.ChallengeRecord memory resolvedChallenge = challengeWorkflow.getChallenge(challengeId);
        try challengeWorkflow.applyRestoration(
            AVADataTypes.Role.Panel, challengeId, keccak256("panel-authority"), "ipfs://m47-rejected-restoration"
        ) {
            revert("challenge lifecycle did not reject restoration");
        } catch {}
        require(
            challengeWorkflow.getChallenge(challengeId).lastTransitionId == resolvedChallenge.lastTransitionId,
            "rejected restoration changed history"
        );
    }

    function _assertLifecycleModuleRejectsClose() internal {
        bytes32 workflowKey = keccak256("m47-reject-close");
        uint256 challengeId = _fileChallengeForLifecycleWorkflow(workflowKey, AVADataTypes.Action.CloseChallenge);
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, challengeId, EDITOR_AUTHORITY);
        challengeWorkflow.resolveChallenge(
            AVADataTypes.Role.Panel,
            challengeId,
            AVADataTypes.ChallengeOutcome.Negligent,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            keccak256("panel-authority"),
            "ipfs://m47-negligent"
        );
        AVADataTypes.ChallengeRecord memory resolvedChallenge = challengeWorkflow.getChallenge(challengeId);
        try challengeWorkflow.closeChallenge(
            AVADataTypes.Role.Panel, challengeId, keccak256("panel-authority"), "ipfs://m47-rejected-close"
        ) {
            revert("challenge lifecycle did not reject close");
        } catch {}
        require(
            challengeWorkflow.getChallenge(challengeId).lastTransitionId == resolvedChallenge.lastTransitionId,
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
        AVARulePackageRegistry.RulePackage memory rulePackage =
            rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey);
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
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            workflowKey,
            recognisedStateId,
            CHALLENGER_SUBJECT,
            evidenceId,
            0
        );
    }

    function _registerDefaultRulePackage(bytes32 workflowKey, string memory uri) internal {
        _registerRulePackage(workflowKey, disclosurePolicyModule, allocationAdapter, consequenceAdapter, uri);
    }

    function _ensureWorkflowPackage(bytes32 workflowKey) internal {
        try rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey) returns (
            AVARulePackageRegistry.RulePackage memory
        ) {}
        catch {
            _registerDefaultRulePackage(workflowKey, "ipfs://test-workflow-evidence-primer");
        }
    }

    function _m419CustomInterfaceModules() internal returns (AVARulePackageRegistry.RulePackageModules memory) {
        return AVARulePackageRegistry.RulePackageModules({
            applicationModule: applicationModule,
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
            applicationModule: applicationModule,
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

    function _registerOrSupersedeRulePackage(
        AVADataTypes.Role actingRole,
        bytes32 workflowKey,
        AVARulePackageRegistry.RulePackageModules memory modules,
        string memory uri
    ) internal returns (uint256 packageId) {
        try rulePackageRegistry.getActivePackageId(PEER_REVIEW_APP_ID, workflowKey) returns (uint256 currentPackageId) {
            AVARulePackageRegistry.RulePackage memory currentPackage =
                rulePackageRegistry.getRulePackageById(currentPackageId);
            if (modules.version <= currentPackage.version) modules.version = currentPackage.version + 1;
            return rulePackageRegistry.supersedeRulePackage(
                actingRole, PEER_REVIEW_APP_ID, workflowKey, currentPackageId, modules, uri
            );
        } catch {
            return rulePackageRegistry.registerRulePackage(actingRole, PEER_REVIEW_APP_ID, workflowKey, modules, uri);
        }
    }

    function _registerRulePackage(
        bytes32 workflowKey,
        IDisclosurePolicyModule disclosureModule,
        IAVAAllocationModule allocationModule,
        IConsequenceAdapter consequenceModule,
        string memory uri
    ) internal {
        _registerOrSupersedeRulePackage(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVARulePackageRegistry.RulePackageModules({
                applicationModule: applicationModule,
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
        _registerOrSupersedeRulePackage(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVARulePackageRegistry.RulePackageModules({
                applicationModule: applicationModule,
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
        _registerOrSupersedeRulePackage(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVARulePackageRegistry.RulePackageModules({
                applicationModule: applicationModule,
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
        _registerOrSupersedeRulePackage(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVARulePackageRegistry.RulePackageModules({
                applicationModule: applicationModule,
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
        _registerOrSupersedeRulePackage(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVARulePackageRegistry.RulePackageModules({
                applicationModule: applicationModule,
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
        _registerOrSupersedeRulePackage(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVARulePackageRegistry.RulePackageModules({
                applicationModule: applicationModule,
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
        _registerOrSupersedeRulePackage(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVARulePackageRegistry.RulePackageModules({
                applicationModule: applicationModule,
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
        _registerOrSupersedeRulePackage(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVARulePackageRegistry.RulePackageModules({
                applicationModule: applicationModule,
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
        _registerOrSupersedeRulePackage(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVARulePackageRegistry.RulePackageModules({
                applicationModule: applicationModule,
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
        return rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey);
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
        new GenericTokenRecordRewardAdapter()
            .validateRewardRecord(
                AVADataTypes.Role.ProtocolExecutor,
                recognisedStateId,
                REVIEWER_SUBJECT,
                1,
                evidenceId,
                keccak256("executor-authority"),
                "ipfs://m49-generic-token-record",
                address(this)
            );
        new RentedPriorityRecordAdapter()
            .validatePriorityRecord(
                AVADataTypes.Role.ProtocolExecutor,
                recognisedStateId,
                REVIEWER_SUBJECT,
                1,
                evidenceId,
                keccak256("executor-authority"),
                "ipfs://m49-rented-priority-record",
                address(this)
            );
        new PriorityReturnObligationRecordAdapter()
            .validatePenaltyRecord(
                AVADataTypes.Role.Panel,
                recognisedStateId,
                1,
                AVADataTypes.GovernanceFindingKind.IrresponsibleReview,
                AVADataTypes.ChallengeOutcome.Upheld,
                REVIEWER_SUBJECT,
                evidenceId,
                keccak256("panel-authority"),
                "ipfs://m49-priority-return-obligation-record",
                address(this)
            );
        new CorrectionRestorationRecordAdapter()
            .validateRestorationRecord(
                AVADataTypes.Role.Panel,
                recognisedStateId,
                REVIEWER_SUBJECT,
                evidenceId,
                keccak256("panel-authority"),
                "ipfs://m49-correction-restoration",
                address(this)
            );
    }

    function _assertM49DownstreamSelectorBoundaries(bytes32 workflowKey) internal {
        AVARulePackageRegistry.RulePackage memory rulePackage =
            rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey);
        _assertNoSelector(address(rulePackage.rewardAdapter), "transferStablecoin(uint256)");
        _assertNoSelector(address(new GenericTokenRecordRewardAdapter()), "transferToken(uint256)");
        _assertNoSelector(address(rulePackage.priorityAdapter), "grantPublicationPriority(uint256)");
        _assertNoSelector(address(rulePackage.priorityAdapter), "boostManuscriptScore(uint256)");
        _assertNoSelector(address(rulePackage.penaltyAdapter), "executeSanction(uint256)");
        _assertNoSelector(address(rulePackage.restorationAdapter), "mintReward(uint256)");
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
        AVARulePackageRegistry.RulePackage memory rulePackage =
            rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, context.workflowKey);
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
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            context.workflowKey,
            context.recognisedStateId,
            CHALLENGER_SUBJECT,
            context.challengeEvidenceId,
            0
        );
        challengeWorkflow.screenChallenge(AVADataTypes.Role.Editor, context.challengeId, EDITOR_AUTHORITY);
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
            _authorityApprovalInput(
                context, action, objectId, authorityId, uint64(block.timestamp + 7 days), "ipfs://authority-approval"
            )
        );
    }

    function _authorityApprovalInput(
        ApprovalAuthorityContext memory context,
        AVADataTypes.Action action,
        bytes32 objectId,
        bytes32 authorityId,
        uint64 expiresAt,
        string memory receiptReasonURI
    ) internal view returns (AuthorityApprovalRegistry.ApprovalInput memory input) {
        input.workflowKey = context.workflowKey;
        input.packageId = context.packageId;
        input.action = action;
        input.recognisedStateId = context.recognisedStateId;
        input.challengeId = context.challengeId;
        input.objectId = objectId;
        input.authorityId = authorityId;
        input.decisionHash = _approvalDecisionHash(context, action);
        input.evidenceReceiptId = context.challengeEvidenceId;
        input.expiresAt = expiresAt;
        input.reasonURI = receiptReasonURI;
    }

    function _approvalDecisionHash(ApprovalAuthorityContext memory context, AVADataTypes.Action action)
        internal
        view
        returns (bytes32)
    {
        AVADataTypes.ChallengeRecord memory challenge = challengeWorkflow.getChallenge(context.challengeId);
        AVADataTypes.RecognisedStateRecord memory state = stateMachine.getRecognisedState(context.recognisedStateId);
        AVADataTypes.RecognisedStateStatus status = state.status;
        AVADataTypes.ChallengeOutcome outcome = action == AVADataTypes.Action.ResolveChallenge
            ? AVADataTypes.ChallengeOutcome.RejectedGoodFaith
            : AVADataTypes.ChallengeOutcome.None;
        return _computeChallengeDecisionHash(
            AVAChallengeWorkflow.ChallengeDecisionContext({
                challengeId: context.challengeId,
                challengePackageId: context.packageId,
                targetPackageId: challenge.targetPackageId,
                action: action,
                lifecycleStatus: challenge.status,
                challengeTransitionId: challenge.lastTransitionId,
                fromStatus: status,
                toStatus: status,
                outcome: outcome,
                evidenceReceiptId: context.challengeEvidenceId,
                targetTransitionId: state.lastTransitionId,
                reasonHash: keccak256(bytes("ipfs://approval-resolution"))
            })
        );
    }

    function _computeChallengeDecisionHash(AVAChallengeWorkflow.ChallengeDecisionContext memory context)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(keccak256("AVA_CHALLENGE_DECISION_V2"), context));
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
        bytes32 attributedObject = rulePackage.attributionModule
            .validateAttribution(
                IAttributionModule.AttributionContext({
                    workflowKey: workflowKey,
                    packageId: rulePackage.packageId,
                    actingRole: AVADataTypes.Role.Reviewer,
                    action: AVADataTypes.Action.RegisterReviewContribution,
                    stage: AVADataTypes.AVAStage.Attribution,
                    objectId: bytes32(manuscriptId),
                    subjectId: REVIEWER_SUBJECT,
                    evidenceReceiptId: evidenceId,
                    disclosurePolicyId: 0,
                    actor: address(reviewerActor)
                })
            );
        rulePackage.verificationModule
            .validateVerification(
                IVerificationModule.VerificationContext({
                    workflowKey: workflowKey,
                    packageId: rulePackage.packageId,
                    actingRole: AVADataTypes.Role.Reviewer,
                    action: AVADataTypes.Action.RegisterReviewContribution,
                    stage: AVADataTypes.AVAStage.Verification,
                    objectId: attributedObject,
                    subjectId: REVIEWER_SUBJECT,
                    evidenceReceiptId: evidenceId,
                    disclosurePolicyId: 0,
                    actor: address(reviewerActor)
                })
            );
        uint256 reviewContributionId = reviewerActor.registerReviewContributionWithWorkflow(
            stateMachine, AVADataTypes.Role.Reviewer, workflowKey, manuscriptId, REVIEWER_SUBJECT, evidenceId, 0
        );
        recognisedStateId =
            stateMachine.provisionallyRecogniseReview(AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);
        rulePackage.transitionRuleModule
            .validateTransition(
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
            PEER_REVIEW_APP_ID,
            workflowKey,
            AVADataTypes.AVAStage.Verification,
            action,
            objectId,
            actingRole,
            disclosurePolicyId,
            subjectCommitment
        );
        proofRegistry.registerProof(
            PEER_REVIEW_APP_ID,
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

    function _registerDefaultAnonymousChallengeDisclosureProof(
        uint256 challengeId,
        uint256 disclosurePolicyId,
        bytes32 subjectCommitment
    ) internal returns (uint256 proofReceiptId) {
        proofReceiptId = zkProofRegistry.nextProofReceiptId();
        _registerZkDisclosureProof(
            zkProofRegistry,
            DEFAULT_WORKFLOW,
            AVADataTypes.Action.RecordDisclosureExecution,
            bytes32(challengeId),
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment
        );
    }

    function _registerDefaultAnonymousChallengeDisclosureProofForPackage(
        uint256 packageId,
        uint256 challengeId,
        uint256 disclosurePolicyId,
        bytes32 subjectCommitment
    ) internal returns (uint256 proofReceiptId) {
        bytes32 contextHash = zkProofRegistry.computeDisclosureContextHashForPackage(
            packageId,
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.RecordDisclosureExecution,
            bytes32(challengeId),
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment
        );
        proofReceiptId = zkProofRegistry.registerProofForPackage(
            packageId,
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.RecordDisclosureExecution,
            bytes32(challengeId),
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment,
            _makeSchnorrProof(contextHash, 7, 11)
        );
    }

    function _assertPackageBoundDisclosureProofRejectsWrongWorkflow(
        uint256 packageId,
        uint256 challengeId,
        uint256 disclosurePolicyId,
        bytes32 subjectCommitment,
        bytes32 packageContextHash
    ) internal {
        try zkProofRegistry.registerProofForPackage(
            packageId,
            PEER_REVIEW_APP_ID,
            keccak256("wrong-workflow"),
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.RecordDisclosureExecution,
            bytes32(challengeId),
            AVADataTypes.Role.Challenger,
            disclosurePolicyId,
            subjectCommitment,
            _makeSchnorrProof(packageContextHash, 7, 13)
        ) {
            revert("package-bound proof accepted wrong workflow");
        } catch {}
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
            PEER_REVIEW_APP_ID,
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
            PEER_REVIEW_APP_ID,
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

    function _assertAnonymousZkChallengePolicyRejected(
        uint256 challengedPolicyId,
        string memory seed,
        string memory message
    ) internal {
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
            zkChallengerActor,
            workflowKey,
            recognisedStateId,
            zkChallengerSubject,
            evidenceId,
            challengedPolicyId,
            message
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
            challengeWorkflow,
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
            PEER_REVIEW_APP_ID,
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
            challengeWorkflow,
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
        assembly ("memory-safe") {
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
