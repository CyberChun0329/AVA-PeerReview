// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RuleModuleIdentity} from "../interfaces/IRuleModuleIdentity.sol";

import {AVADataTypes} from "../AVADataTypes.sol";
import {DisclosurePolicyRegistry} from "../DisclosurePolicyRegistry.sol";
import {IValueExecutionAdapter} from "../interfaces/IValueExecutionAdapter.sol";
import {IStandingComputationModule} from "../interfaces/IStandingComputationModule.sol";
import {IRulePackageLifecycleModule} from "../interfaces/IRulePackageLifecycleModule.sol";
import {IEvidenceLifecycleModule} from "../interfaces/IEvidenceLifecycleModule.sol";
import {IDisclosureLifecycleModule} from "../interfaces/IDisclosureLifecycleModule.sol";

contract DefaultValueExecutionAdapter is IValueExecutionAdapter, RuleModuleIdentity {
    function validateValueExecution(AVADataTypes.ValueExecutionContext calldata context) external pure {
        if (
            context.recognisedStateId == 0 || context.recipientSubjectId == bytes32(0) || context.amount == 0
                || context.mode != AVADataTypes.ValueExecutionMode.RecordOnly || context.executionReference == bytes32(0)
                || context.settlementKind != AVADataTypes.ValueSettlementKind.None || context.authorityId == bytes32(0)
                || context.evidenceReceiptId == 0 || context.actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
    }
}

/// @notice Demo-only adapter for an asset-bound mock ERC20 reward and recovery path.
/// @dev It validates execution metadata only; token movement remains in ValueSettlementExecutor.
contract MockERC20RecoveryValueExecutionAdapter is IValueExecutionAdapter, RuleModuleIdentity {
    address public immutable MOCK_ASSET;

    constructor(address mockAsset_) {
        if (mockAsset_ == address(0) || mockAsset_.code.length == 0) revert AVADataTypes.EmptyValue();
        MOCK_ASSET = mockAsset_;
    }

    function validateValueExecution(AVADataTypes.ValueExecutionContext calldata context) external view {
        if (
            context.recognisedStateId == 0 || context.recipientSubjectId == bytes32(0) || context.amount == 0
                || context.executionReference == bytes32(0) || context.authorityId == bytes32(0)
                || context.evidenceReceiptId == 0 || context.actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
        if (context.mode == AVADataTypes.ValueExecutionMode.RecordOnly) {
            if (context.settlementKind != AVADataTypes.ValueSettlementKind.None) {
                revert AVADataTypes.InvalidState(context.recognisedStateId);
            }
            return;
        }
        if (
            context.asset != MOCK_ASSET || context.payer == address(0)
                || context.mode != AVADataTypes.ValueExecutionMode.Claim
                || (
                    context.settlementKind != AVADataTypes.ValueSettlementKind.TokenTransfer
                        && context.settlementKind != AVADataTypes.ValueSettlementKind.ClawbackTransfer
                )
        ) {
            revert AVADataTypes.InvalidState(context.recognisedStateId);
        }
    }
}

contract DefaultStandingComputationModule is IStandingComputationModule, RuleModuleIdentity {
    function validateStandingComputation(AVADataTypes.StandingComputationContext calldata context) external pure {
        if (
            context.recognisedStateId == 0 || context.subjectId == bytes32(0) || bytes(context.dimension).length == 0
                || context.vectorKey == bytes32(0) || context.evidenceReceiptId == 0
                || context.epoch == 0 || context.sourceRecordSetHash == bytes32(0)
                || context.computationRuleHash == bytes32(0) || context.authorityId == bytes32(0)
                || context.actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
        bytes32 dimensionHash = keccak256(bytes(context.dimension));
        if (dimensionHash == keccak256("public-prestige") || dimensionHash == keccak256("single-score")) {
            revert AVADataTypes.InvalidState(context.recognisedStateId);
        }
    }
}

contract DefaultRulePackageLifecycleModule is IRulePackageLifecycleModule, RuleModuleIdentity {
    function validateRulePackageLifecycle(RulePackageLifecycleContext calldata context) external pure {
        if (
            context.workflowKey == bytes32(0) || context.modulesHash == bytes32(0)
                || context.modulesIdentityHash == bytes32(0) || context.version == 0
                || context.compatibilityKey == bytes32(0) || context.deprecated || context.actor == address(0)
        ) {
            revert AVADataTypes.InvalidState(uint256(context.workflowKey));
        }
        bool targetRequired = context.kind == AVADataTypes.RulePackageLifecycleKind.SupersessionReady
            || context.kind == AVADataTypes.RulePackageLifecycleKind.MigrationReady;
        if (targetRequired) {
            if (
                context.targetWorkflowKey == bytes32(0) || context.targetPackageId == 0
                    || context.targetModulesHash == bytes32(0) || context.targetModulesIdentityHash == bytes32(0)
                    || context.targetVersion == 0 || context.targetCompatibilityKey == bytes32(0)
            ) {
                revert AVADataTypes.EmptyValue();
            }
        } else if (context.targetWorkflowKey != bytes32(0) || context.targetPackageId != 0) {
            revert AVADataTypes.InvalidState(context.targetPackageId);
        }
    }
}

contract DefaultEvidenceLifecycleModule is IEvidenceLifecycleModule, RuleModuleIdentity {
    function validateEvidenceLifecycle(
        bytes32 workflowKey,
        AVADataTypes.Action,
        uint256 evidenceReceiptId,
        AVADataTypes.EvidenceLifecycleKind,
        uint256,
        bytes32,
        address actor
    ) external pure {
        if (workflowKey == bytes32(0) || evidenceReceiptId == 0 || actor == address(0)) {
            revert AVADataTypes.EmptyValue();
        }
    }
}

contract DefaultDisclosureLifecycleModule is IDisclosureLifecycleModule, RuleModuleIdentity {
    DisclosurePolicyRegistry public immutable disclosureRegistry;

    constructor(DisclosurePolicyRegistry disclosureRegistry_) {
        disclosureRegistry = disclosureRegistry_;
    }

    function validateDisclosureLifecycle(
        bytes32 workflowKey,
        AVADataTypes.Action action,
        uint256 disclosurePolicyId,
        AVADataTypes.DisclosureLifecycleKind kind,
        bytes32 lifecycleReference,
        address actor
    ) external view {
        if (
            workflowKey == bytes32(0) || action != AVADataTypes.Action.RecordDisclosureLifecycle
                || disclosurePolicyId == 0 || kind == AVADataTypes.DisclosureLifecycleKind.None
                || lifecycleReference == bytes32(0) || actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
        disclosureRegistry.getDisclosurePolicy(disclosurePolicyId);
    }
}
