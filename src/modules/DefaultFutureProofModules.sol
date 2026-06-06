// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";
import {DisclosurePolicyRegistry} from "../DisclosurePolicyRegistry.sol";
import {IValueExecutionAdapter} from "../interfaces/IValueExecutionAdapter.sol";
import {IStandingComputationModule} from "../interfaces/IStandingComputationModule.sol";
import {IRulePackageLifecycleModule} from "../interfaces/IRulePackageLifecycleModule.sol";
import {IEvidenceLifecycleModule} from "../interfaces/IEvidenceLifecycleModule.sol";
import {IDisclosureLifecycleModule} from "../interfaces/IDisclosureLifecycleModule.sol";

contract DefaultValueExecutionAdapter is IValueExecutionAdapter {
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

contract DefaultStandingComputationModule is IStandingComputationModule {
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

contract DefaultRulePackageLifecycleModule is IRulePackageLifecycleModule {
    function validateRulePackageLifecycle(RulePackageLifecycleContext calldata context) external pure {
        if (
            context.workflowKey == bytes32(0) || context.modulesHash == bytes32(0)
                || context.modulesCodeHash == bytes32(0) || context.version == 0
                || context.compatibilityKey == bytes32(0) || context.deprecated || context.actor == address(0)
        ) {
            revert AVADataTypes.InvalidState(uint256(context.workflowKey));
        }
        bool targetRequired = context.kind == AVADataTypes.RulePackageLifecycleKind.SupersessionReady
            || context.kind == AVADataTypes.RulePackageLifecycleKind.MigrationReady;
        if (targetRequired) {
            if (
                context.targetWorkflowKey == bytes32(0) || context.targetPackageId == 0
                    || context.targetModulesHash == bytes32(0) || context.targetModulesCodeHash == bytes32(0)
                    || context.targetVersion == 0 || context.targetCompatibilityKey == bytes32(0)
            ) {
                revert AVADataTypes.EmptyValue();
            }
        } else if (context.targetWorkflowKey != bytes32(0) || context.targetPackageId != 0) {
            revert AVADataTypes.InvalidState(context.targetPackageId);
        }
    }
}

contract DefaultEvidenceLifecycleModule is IEvidenceLifecycleModule {
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

contract DefaultDisclosureLifecycleModule is IDisclosureLifecycleModule {
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
