// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVACoreTransitionRules} from "../src/core/AVACoreTransitionRules.sol";
import {AVACoreTypes} from "../src/core/AVACoreTypes.sol";

/// @notice Exhaustive rendering of the transition graph used by AVAGovernanceKernel.
contract AVATransitionMatrix {
    uint256 private constant STATUS_COUNT = 10;
    uint256 private constant INITIAL_START = 0;
    uint256 private constant GENERIC_START = INITIAL_START + STATUS_COUNT;
    uint256 private constant VESTING_START = GENERIC_START + STATUS_COUNT * STATUS_COUNT;
    uint256 private constant CHALLENGE_TARGET_START = VESTING_START + STATUS_COUNT;
    uint256 private constant CORRECTION_START = CHALLENGE_TARGET_START + STATUS_COUNT;
    uint256 private constant RESTORATION_START = CORRECTION_START + STATUS_COUNT * STATUS_COUNT;
    uint256 private constant ROW_COUNT = RESTORATION_START + STATUS_COUNT * STATUS_COUNT;

    struct MatrixCase {
        string domain;
        string action;
        AVACoreTypes.RecognisedStateStatus fromStatus;
        AVACoreTypes.RecognisedStateStatus toStatus;
        AVACoreTypes.TransitionKind kind;
        bool allowed;
        string ledgerEffect;
    }

    function artifactPath() external pure returns (string memory) {
        return "generated/recognised-state-transition-matrix.csv";
    }

    function rowCount() external pure returns (uint256) {
        return ROW_COUNT;
    }

    function matrixHash() external pure returns (bytes32) {
        return keccak256(bytes(matrixCsv()));
    }

    function runMatrix() external pure returns (string memory) {
        return matrixCsv();
    }

    function matrixCsv() public pure returns (string memory csv) {
        csv = "domain,action,from_status,to_status,transition_kind,admissibility,ledger_effect,notes\n";
        for (uint256 rowId; rowId < ROW_COUNT; ++rowId) {
            csv = string.concat(csv, expectedRowString(rowId));
        }
    }

    function expectedRowString(uint256 rowId) public pure returns (string memory) {
        MatrixCase memory matrixCase = _matrixCase(rowId);
        return string.concat(
            matrixCase.domain,
            ",",
            matrixCase.action,
            ",",
            _statusName(matrixCase.fromStatus),
            ",",
            _statusName(matrixCase.toStatus),
            ",",
            _kindName(matrixCase.kind),
            ",",
            matrixCase.allowed ? "allowed" : "rejected",
            ",",
            matrixCase.ledgerEffect,
            ",kernel-shared-transition-rule\n"
        );
    }

    function _matrixCase(uint256 rowId) private pure returns (MatrixCase memory matrixCase) {
        if (rowId >= ROW_COUNT) revert("unknown-matrix-row");
        if (rowId < GENERIC_START) return _initialCase(rowId);
        if (rowId < VESTING_START) return _genericCase(rowId - GENERIC_START);
        if (rowId < CHALLENGE_TARGET_START) return _vestingCase(rowId - VESTING_START);
        if (rowId < CORRECTION_START) return _challengeTargetCase(rowId - CHALLENGE_TARGET_START);
        if (rowId < RESTORATION_START) {
            return _sourceBoundCase(
                rowId - CORRECTION_START,
                "challenge_correction",
                AVACoreTypes.TransitionKind.ChallengeCorrection
            );
        }
        return _sourceBoundCase(
            rowId - RESTORATION_START, "restoration", AVACoreTypes.TransitionKind.Restoration
        );
    }

    function _initialCase(uint256 localRow) private pure returns (MatrixCase memory matrixCase) {
        AVACoreTypes.RecognisedStateStatus toStatus = _status(localRow);
        bool allowed = AVACoreTransitionRules.isInitialStatus(toStatus);
        return MatrixCase({
            domain: "initial_formation",
            action: "FormRecognisedState",
            fromStatus: AVACoreTypes.RecognisedStateStatus.None,
            toStatus: toStatus,
            kind: AVACoreTypes.TransitionKind.InitialFormation,
            allowed: allowed,
            ledgerEffect: allowed ? "recognised-state-transition" : "no-ledger"
        });
    }

    function _genericCase(uint256 localRow) private pure returns (MatrixCase memory matrixCase) {
        AVACoreTypes.RecognisedStateStatus fromStatus = _status(localRow / STATUS_COUNT);
        AVACoreTypes.RecognisedStateStatus toStatus = _status(localRow % STATUS_COUNT);
        bool allowed = AVACoreTransitionRules.isGenericTransition(fromStatus, toStatus);
        return MatrixCase({
            domain: "generic_transition",
            action: "TransitionRecognisedState",
            fromStatus: fromStatus,
            toStatus: toStatus,
            kind: AVACoreTypes.TransitionKind.Generic,
            allowed: allowed,
            ledgerEffect: allowed ? "recognised-state-transition" : "no-ledger"
        });
    }

    function _vestingCase(uint256 localRow) private pure returns (MatrixCase memory matrixCase) {
        AVACoreTypes.RecognisedStateStatus fromStatus = _status(localRow);
        bool allowed = AVACoreTransitionRules.isVestingSource(fromStatus);
        return MatrixCase({
            domain: "vesting",
            action: "VestRecognisedState",
            fromStatus: fromStatus,
            toStatus: AVACoreTypes.RecognisedStateStatus.Vested,
            kind: AVACoreTypes.TransitionKind.Vesting,
            allowed: allowed,
            ledgerEffect: allowed ? "recognised-state-transition" : "no-ledger"
        });
    }

    function _challengeTargetCase(uint256 localRow) private pure returns (MatrixCase memory matrixCase) {
        AVACoreTypes.RecognisedStateStatus status = _status(localRow);
        bool allowed = AVACoreTransitionRules.isChallengeTarget(status);
        return MatrixCase({
            domain: "challenge_target",
            action: "FileChallenge",
            fromStatus: status,
            toStatus: status,
            kind: AVACoreTypes.TransitionKind.None,
            allowed: allowed,
            ledgerEffect: allowed ? "challenge-lifecycle-and-challenge-state-transition" : "no-ledger"
        });
    }

    function _sourceBoundCase(uint256 localRow, string memory domain, AVACoreTypes.TransitionKind kind)
        private
        pure
        returns (MatrixCase memory matrixCase)
    {
        AVACoreTypes.RecognisedStateStatus fromStatus = _status(localRow / STATUS_COUNT);
        AVACoreTypes.RecognisedStateStatus toStatus = _status(localRow % STATUS_COUNT);
        bool allowed = AVACoreTransitionRules.isSourceBoundTransition(fromStatus, toStatus, kind);
        return MatrixCase({
            domain: domain,
            action: "RequestSourceBoundTransition",
            fromStatus: fromStatus,
            toStatus: toStatus,
            kind: kind,
            allowed: allowed,
            ledgerEffect: allowed ? "recognised-state-transition" : "no-ledger"
        });
    }

    function _status(uint256 value) private pure returns (AVACoreTypes.RecognisedStateStatus) {
        return AVACoreTypes.RecognisedStateStatus(value);
    }

    function _statusName(AVACoreTypes.RecognisedStateStatus status) private pure returns (string memory) {
        if (status == AVACoreTypes.RecognisedStateStatus.None) return "None";
        if (status == AVACoreTypes.RecognisedStateStatus.Draft) return "Draft";
        if (status == AVACoreTypes.RecognisedStateStatus.Registered) return "Registered";
        if (status == AVACoreTypes.RecognisedStateStatus.Provisional) return "Provisional";
        if (status == AVACoreTypes.RecognisedStateStatus.Challengeable) return "Challengeable";
        if (status == AVACoreTypes.RecognisedStateStatus.Vested) return "Vested";
        if (status == AVACoreTypes.RecognisedStateStatus.Frozen) return "Frozen";
        if (status == AVACoreTypes.RecognisedStateStatus.Downgraded) return "Downgraded";
        if (status == AVACoreTypes.RecognisedStateStatus.Voided) return "Voided";
        return "Restored";
    }

    function _kindName(AVACoreTypes.TransitionKind kind) private pure returns (string memory) {
        if (kind == AVACoreTypes.TransitionKind.None) return "None";
        if (kind == AVACoreTypes.TransitionKind.InitialFormation) return "InitialFormation";
        if (kind == AVACoreTypes.TransitionKind.Generic) return "Generic";
        if (kind == AVACoreTypes.TransitionKind.Vesting) return "Vesting";
        if (kind == AVACoreTypes.TransitionKind.ChallengeCorrection) return "ChallengeCorrection";
        return "Restoration";
    }
}
