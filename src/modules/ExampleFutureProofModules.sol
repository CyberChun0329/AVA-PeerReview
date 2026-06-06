// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";
import {IValueExecutionAdapter} from "../interfaces/IValueExecutionAdapter.sol";
import {IStandingComputationModule} from "../interfaces/IStandingComputationModule.sol";
import {IRulePackageLifecycleModule} from "../interfaces/IRulePackageLifecycleModule.sol";
import {IEvidenceLifecycleModule} from "../interfaces/IEvidenceLifecycleModule.sol";
import {IDisclosureLifecycleModule} from "../interfaces/IDisclosureLifecycleModule.sol";

contract ClaimEscrowRecordValueAdapter is IValueExecutionAdapter {
    function validateValueExecution(AVADataTypes.ValueExecutionContext calldata context) external pure {
        if (
            context.recognisedStateId == 0 || context.recipientSubjectId == bytes32(0) || context.amount == 0
                || context.executionReference == bytes32(0) || context.authorityId == bytes32(0)
                || context.evidenceReceiptId == 0 || context.actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
        if (context.mode == AVADataTypes.ValueExecutionMode.None) {
            revert AVADataTypes.InvalidState(context.recognisedStateId);
        }
        if (
            (context.mode == AVADataTypes.ValueExecutionMode.RecordOnly
                && context.settlementKind != AVADataTypes.ValueSettlementKind.None)
                || (context.mode != AVADataTypes.ValueExecutionMode.RecordOnly
                    && context.settlementKind == AVADataTypes.ValueSettlementKind.None)
        ) {
            revert AVADataTypes.InvalidState(context.recognisedStateId);
        }
        if (
            context.mode != AVADataTypes.ValueExecutionMode.RecordOnly
                && (context.asset == address(0) || context.payer == address(0))
        ) {
            revert AVADataTypes.EmptyValue();
        }
    }
}

contract VectorStandingComputationModule is IStandingComputationModule {
    function validateStandingComputation(AVADataTypes.StandingComputationContext calldata context) external pure {
        if (
            context.recognisedStateId == 0 || context.subjectId == bytes32(0) || context.vectorKey == bytes32(0)
                || context.fieldKey == bytes32(0) || context.evidenceReceiptId == 0
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

contract FormulaV0StandingComputationModule is IStandingComputationModule {
    bytes32 public constant FORMULA_RULE_DOMAIN =
        keccak256("ava-standing-formula-v0-weighted-ledger-decay-confidence");
    bytes32 public constant REVIEW_RELIABILITY_VECTOR = keccak256("review_reliability");
    bytes32 public constant CHALLENGE_INTEGRITY_VECTOR = keccak256("challenge_integrity");
    bytes32 public constant CORRECTION_RESPONSIVENESS_VECTOR = keccak256("correction_responsiveness");
    bytes32 public constant PROCEDURAL_PARTICIPATION_VECTOR = keccak256("procedural_participation");
    int256 public constant MIN_STANDING_VALUE = -100;
    int256 public constant MAX_STANDING_VALUE = 100;
    int256 public constant MAX_ABS_DELTA = 20;

    function formulaRuleHash(bytes32 vectorKey) public pure returns (bytes32) {
        return keccak256(abi.encode(FORMULA_RULE_DOMAIN, vectorKey));
    }

    function validateStandingComputation(AVADataTypes.StandingComputationContext calldata context) external pure {
        if (
            context.recognisedStateId == 0 || context.subjectId == bytes32(0)
                || bytes(context.dimension).length == 0 || context.vectorKey == bytes32(0)
                || context.fieldKey == bytes32(0) || context.evidenceReceiptId == 0 || context.epoch == 0
                || context.effectiveAt == 0 || context.sourceRecordSetHash == bytes32(0)
                || context.computationRuleHash == bytes32(0) || context.authorityId == bytes32(0)
                || context.actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
        bytes32 dimensionHash = keccak256(bytes(context.dimension));
        if (dimensionHash == keccak256("public-prestige") || dimensionHash == keccak256("single-score")) {
            revert AVADataTypes.InvalidState(context.recognisedStateId);
        }
        if (dimensionHash != context.vectorKey || !_isFormulaVector(context.vectorKey)) {
            revert AVADataTypes.InvalidState(context.recognisedStateId);
        }
        if (context.computationRuleHash != formulaRuleHash(context.vectorKey) || !context.reversible) {
            revert AVADataTypes.InvalidState(context.recognisedStateId);
        }
        if (
            context.currentValue < MIN_STANDING_VALUE || context.currentValue > MAX_STANDING_VALUE
                || context.delta < -MAX_ABS_DELTA || context.delta > MAX_ABS_DELTA
        ) {
            revert AVADataTypes.InvalidState(context.recognisedStateId);
        }
    }

    function _isFormulaVector(bytes32 vectorKey) internal pure returns (bool) {
        return vectorKey == REVIEW_RELIABILITY_VECTOR || vectorKey == CHALLENGE_INTEGRITY_VECTOR
            || vectorKey == CORRECTION_RESPONSIVENESS_VECTOR || vectorKey == PROCEDURAL_PARTICIPATION_VECTOR;
    }
}

contract VersionedRulePackageLifecycleModule is IRulePackageLifecycleModule {
    uint64 public immutable minimumVersion;

    constructor(uint64 minimumVersion_) {
        if (minimumVersion_ == 0) revert AVADataTypes.EmptyValue();
        minimumVersion = minimumVersion_;
    }

    function validateRulePackageLifecycle(RulePackageLifecycleContext calldata context) external view {
        if (
            context.workflowKey == bytes32(0) || context.modulesHash == bytes32(0)
                || context.modulesCodeHash == bytes32(0) || context.version < minimumVersion
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

contract RejectingEvidenceLifecycleModule is IEvidenceLifecycleModule {
    AVADataTypes.Action public blockedAction;

    constructor(AVADataTypes.Action blockedAction_) {
        blockedAction = blockedAction_;
    }

    function validateEvidenceLifecycle(
        bytes32 workflowKey,
        AVADataTypes.Action action,
        uint256 evidenceReceiptId,
        AVADataTypes.EvidenceLifecycleKind,
        uint256,
        bytes32,
        address actor
    ) external view {
        if (workflowKey == bytes32(0) || evidenceReceiptId == 0 || actor == address(0)) {
            revert AVADataTypes.EmptyValue();
        }
        if (action == blockedAction) revert AVADataTypes.InvalidState(evidenceReceiptId);
    }
}

contract RejectingDisclosureLifecycleModule is IDisclosureLifecycleModule {
    AVADataTypes.DisclosureLifecycleKind public blockedKind;

    constructor(AVADataTypes.DisclosureLifecycleKind blockedKind_) {
        blockedKind = blockedKind_;
    }

    function validateDisclosureLifecycle(
        bytes32 workflowKey,
        AVADataTypes.Action,
        uint256 disclosurePolicyId,
        AVADataTypes.DisclosureLifecycleKind kind,
        bytes32 lifecycleReference,
        address actor
    ) external view {
        if (
            workflowKey == bytes32(0) || disclosurePolicyId == 0 || kind == AVADataTypes.DisclosureLifecycleKind.None
                || lifecycleReference == bytes32(0) || actor == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
        if (kind == blockedKind) revert AVADataTypes.InvalidState(uint256(kind));
    }
}
