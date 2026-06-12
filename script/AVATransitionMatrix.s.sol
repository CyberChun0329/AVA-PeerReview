// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../src/AVADataTypes.sol";
import {AVADemoScenario} from "./AVADemoScenario.s.sol";

contract AVATransitionMatrix is AVADemoScenario {
    uint256 private constant ROW_COUNT = 35;

    bytes32 private constant AUTHOR_SUBJECT = keccak256("demo-author");
    bytes32 private constant REVIEWER_SUBJECT = keccak256("demo-reviewer");
    bytes32 private constant CHALLENGER_SUBJECT = keccak256("demo-challenger");
    bytes32 private constant EDITOR_AUTHORITY = keccak256("demo-editor-authority");
    bytes32 private constant PANEL_AUTHORITY = keccak256("demo-panel-authority");
    bytes32 private constant DEFAULT_WORKFLOW = keccak256("demo-review-workflow");

    struct Counters {
        uint256 recognisedStateTransitionId;
        uint256 challengeId;
        uint256 challengeTransitionId;
    }

    struct ChallengePath {
        uint256 disclosurePolicyId;
        uint256 recognisedStateId;
        uint256 challengeId;
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
        csv = _header();
        for (uint256 rowId = 0; rowId < ROW_COUNT; rowId++) {
            csv = string.concat(csv, expectedRowString(rowId));
        }
    }

    function expectedRowString(uint256 rowId) public pure returns (string memory) {
        if (rowId == 0) {
            return _row(
                "recognised_state",
                "RegisterRecognisedState",
                "None",
                "Draft",
                "None",
                true,
                "recognised-state-transition",
                "None-to-low-impact-status"
            );
        }
        if (rowId == 1) {
            return _row(
                "recognised_state",
                "RegisterRecognisedState",
                "None",
                "Registered",
                "None",
                true,
                "recognised-state-transition",
                "None-to-low-impact-status"
            );
        }
        if (rowId == 2) {
            return _row(
                "recognised_state",
                "RegisterRecognisedState",
                "None",
                "Provisional",
                "None",
                true,
                "recognised-state-transition",
                "None-to-low-impact-status"
            );
        }
        if (rowId == 3) {
            return _row(
                "recognised_state",
                "RegisterRecognisedState",
                "None",
                "Challengeable",
                "None",
                true,
                "recognised-state-transition",
                "None-to-low-impact-status"
            );
        }
        if (rowId == 4) {
            return _row(
                "recognised_state",
                "RegisterRecognisedState",
                "None",
                "Frozen",
                "None",
                true,
                "recognised-state-transition",
                "downstream-ineligible-low-impact-registration"
            );
        }
        if (rowId == 5) {
            return _row(
                "recognised_state",
                "RegisterRecognisedState",
                "None",
                "Vested",
                "None",
                false,
                "no-ledger",
                "high-impact-status-must-be-transition-generated"
            );
        }
        if (rowId == 6) {
            return _row(
                "recognised_state",
                "RegisterRecognisedState",
                "None",
                "Downgraded",
                "None",
                false,
                "no-ledger",
                "high-impact-status-must-be-challenge-generated"
            );
        }
        if (rowId == 7) {
            return _row(
                "recognised_state",
                "RegisterRecognisedState",
                "None",
                "Voided",
                "None",
                false,
                "no-ledger",
                "high-impact-status-must-be-challenge-generated"
            );
        }
        if (rowId == 8) {
            return _row(
                "recognised_state",
                "RegisterRecognisedState",
                "None",
                "Restored",
                "None",
                false,
                "no-ledger",
                "high-impact-status-must-be-restoration-generated"
            );
        }
        if (rowId == 9) {
            return _row(
                "review_recognition",
                "ProvisionallyRecogniseReview",
                "None",
                "Provisional",
                "None",
                true,
                "recognised-state-transition",
                "review-derived-recognised-state"
            );
        }
        if (rowId == 10) {
            return _row(
                "review_recognition",
                "OpenChallengeWindow",
                "Provisional",
                "Challengeable",
                "None",
                true,
                "recognised-state-transition",
                "opens-challengeable-window"
            );
        }
        if (rowId == 11) {
            return _row(
                "review_recognition",
                "TransitionRecognisedState",
                "Challengeable",
                "Vested",
                "None",
                true,
                "recognised-state-transition",
                "review-vesting-requires-no-open-challenge"
            );
        }
        if (rowId == 12) {
            return _row(
                "generic_transition",
                "TransitionRecognisedState",
                "Registered",
                "Vested",
                "None",
                true,
                "recognised-state-transition",
                "generic-vesting-only"
            );
        }
        if (rowId == 13) {
            return _row(
                "generic_transition",
                "TransitionRecognisedState",
                "Registered",
                "Downgraded",
                "None",
                false,
                "no-ledger",
                "correction-status-needs-challenge-path"
            );
        }
        if (rowId == 14) {
            return _row(
                "generic_transition",
                "TransitionRecognisedState",
                "Registered",
                "Voided",
                "None",
                false,
                "no-ledger",
                "correction-status-needs-challenge-path"
            );
        }
        if (rowId == 15) {
            return _row(
                "generic_transition",
                "TransitionRecognisedState",
                "Registered",
                "Restored",
                "None",
                false,
                "no-ledger",
                "restoration-needs-restoration-path"
            );
        }
        if (rowId == 16) {
            return _row(
                "generic_transition",
                "TransitionRecognisedState",
                "Provisional",
                "Vested",
                "None",
                false,
                "no-ledger",
                "generic-transition-source-must-be-registered"
            );
        }
        if (rowId == 17) {
            return _row(
                "generic_transition",
                "TransitionRecognisedState",
                "Challengeable",
                "Vested",
                "None",
                false,
                "no-ledger",
                "challengeable-review-vesting-uses-review-path"
            );
        }
        if (rowId == 18) {
            return _row(
                "generic_transition",
                "TransitionRecognisedState",
                "Draft",
                "Vested",
                "None",
                false,
                "no-ledger",
                "generic-transition-source-must-be-registered"
            );
        }
        if (rowId == 19) {
            return _row(
                "generic_transition",
                "TransitionRecognisedState",
                "Frozen",
                "Vested",
                "None",
                false,
                "no-ledger",
                "generic-transition-source-must-be-registered"
            );
        }
        if (rowId == 20) {
            return _row(
                "challenge",
                "FileChallenge",
                "Challengeable",
                "Challengeable",
                "None",
                true,
                "challenge-record-only",
                "raw-challenge-does-not-mutate-state"
            );
        }
        if (rowId == 21) {
            return _row(
                "challenge",
                "FileChallenge",
                "Provisional",
                "Provisional",
                "None",
                false,
                "no-ledger",
                "target-must-be-challengeable-recognised-state"
            );
        }
        if (rowId == 22) {
            return _row(
                "challenge",
                "ScreenChallenge",
                "Challengeable",
                "Challengeable",
                "None",
                true,
                "challenge-transition-only",
                "screening-does-not-decide-truth"
            );
        }
        if (rowId == 23) {
            return _row(
                "challenge",
                "ResolveChallenge",
                "Challengeable",
                "Downgraded",
                "Upheld",
                true,
                "challenge-and-recognised-state-transition",
                "upheld-challenge-can-mutate-state"
            );
        }
        if (rowId == 24) {
            return _row(
                "challenge",
                "ResolveChallenge",
                "Challengeable",
                "Voided",
                "Upheld",
                true,
                "challenge-and-recognised-state-transition",
                "upheld-challenge-can-mutate-state"
            );
        }
        if (rowId == 25) {
            return _row(
                "challenge",
                "ResolveChallenge",
                "Challengeable",
                "Challengeable",
                "RejectedGoodFaith",
                true,
                "challenge-transition-only",
                "failed-good-faith-challenge-no-state-mutation"
            );
        }
        if (rowId == 26) {
            return _row(
                "challenge",
                "ResolveChallenge",
                "Challengeable",
                "Challengeable",
                "Negligent",
                true,
                "challenge-transition-only",
                "negligent-challenge-record-no-state-mutation"
            );
        }
        if (rowId == 27) {
            return _row(
                "challenge",
                "ResolveChallenge",
                "Challengeable",
                "Challengeable",
                "MaliciousOrFabricated",
                true,
                "challenge-transition-only",
                "abuse-finding-record-no-sanction-execution"
            );
        }
        if (rowId == 28) {
            return _row(
                "challenge",
                "ResolveChallenge",
                "Challengeable",
                "Vested",
                "Upheld",
                false,
                "no-ledger",
                "upheld-resolution-only-downgrades-or-voids"
            );
        }
        if (rowId == 29) {
            return _row(
                "restoration",
                "ApplyRestoration",
                "Downgraded",
                "Restored",
                "Upheld",
                true,
                "challenge-and-recognised-state-transition",
                "explicit-restoration-after-correction"
            );
        }
        if (rowId == 30) {
            return _row(
                "restoration",
                "ApplyRestoration",
                "Voided",
                "Restored",
                "Upheld",
                true,
                "challenge-and-recognised-state-transition",
                "explicit-restoration-after-correction"
            );
        }
        if (rowId == 31) {
            return _row(
                "restoration",
                "ApplyRestoration",
                "Challengeable",
                "Restored",
                "RejectedGoodFaith",
                true,
                "challenge-and-recognised-state-transition",
                "explicit-restoration-after-failed-good-faith-challenge"
            );
        }
        if (rowId == 32) {
            return _row(
                "restoration",
                "ApplyRestoration",
                "Challengeable",
                "Restored",
                "MaliciousOrFabricated",
                true,
                "challenge-and-recognised-state-transition",
                "explicit-restoration-after-abusive-challenge"
            );
        }
        if (rowId == 33) {
            return _row(
                "restoration",
                "ApplyRestoration",
                "Challengeable",
                "Restored",
                "Negligent",
                false,
                "no-ledger",
                "negligent-outcome-does-not-enable-restoration"
            );
        }
        if (rowId == 34) {
            return _row(
                "challenge",
                "CloseChallenge",
                "Challengeable",
                "Challengeable",
                "RejectedGoodFaith",
                true,
                "challenge-transition-only",
                "closure-does-not-mutate-recognised-state"
            );
        }
        revert("unknown-matrix-row");
    }

    function executeRowString(uint256 rowId) external returns (string memory) {
        if (rowId == 0) {
            return _registrationRow(AVADataTypes.RecognisedStateStatus.Draft, "Draft", "None-to-low-impact-status");
        }
        if (rowId == 1) {
            return _registrationRow(
                AVADataTypes.RecognisedStateStatus.Registered, "Registered", "None-to-low-impact-status"
            );
        }
        if (rowId == 2) {
            return _registrationRow(
                AVADataTypes.RecognisedStateStatus.Provisional, "Provisional", "None-to-low-impact-status"
            );
        }
        if (rowId == 3) {
            return _registrationRow(
                AVADataTypes.RecognisedStateStatus.Challengeable, "Challengeable", "None-to-low-impact-status"
            );
        }
        if (rowId == 4) {
            return _registrationRow(
                AVADataTypes.RecognisedStateStatus.Frozen,
                "Frozen",
                "downstream-ineligible-low-impact-registration"
            );
        }
        if (rowId == 5) {
            return _registrationRow(
                AVADataTypes.RecognisedStateStatus.Vested,
                "Vested",
                "high-impact-status-must-be-transition-generated"
            );
        }
        if (rowId == 6) {
            return _registrationRow(
                AVADataTypes.RecognisedStateStatus.Downgraded,
                "Downgraded",
                "high-impact-status-must-be-challenge-generated"
            );
        }
        if (rowId == 7) {
            return _registrationRow(
                AVADataTypes.RecognisedStateStatus.Voided,
                "Voided",
                "high-impact-status-must-be-challenge-generated"
            );
        }
        if (rowId == 8) {
            return _registrationRow(
                AVADataTypes.RecognisedStateStatus.Restored,
                "Restored",
                "high-impact-status-must-be-restoration-generated"
            );
        }
        if (rowId == 9) return _reviewProvisionalRow();
        if (rowId == 10) return _openChallengeWindowRow();
        if (rowId == 11) return _reviewVestingRow();
        if (rowId == 12) {
            return _genericTransitionRow(
                AVADataTypes.RecognisedStateStatus.Registered,
                "Registered",
                AVADataTypes.RecognisedStateStatus.Vested,
                "Vested",
                "generic-vesting-only"
            );
        }
        if (rowId == 13) {
            return _genericTransitionRow(
                AVADataTypes.RecognisedStateStatus.Registered,
                "Registered",
                AVADataTypes.RecognisedStateStatus.Downgraded,
                "Downgraded",
                "correction-status-needs-challenge-path"
            );
        }
        if (rowId == 14) {
            return _genericTransitionRow(
                AVADataTypes.RecognisedStateStatus.Registered,
                "Registered",
                AVADataTypes.RecognisedStateStatus.Voided,
                "Voided",
                "correction-status-needs-challenge-path"
            );
        }
        if (rowId == 15) {
            return _genericTransitionRow(
                AVADataTypes.RecognisedStateStatus.Registered,
                "Registered",
                AVADataTypes.RecognisedStateStatus.Restored,
                "Restored",
                "restoration-needs-restoration-path"
            );
        }
        if (rowId == 16) {
            return _genericTransitionRow(
                AVADataTypes.RecognisedStateStatus.Provisional,
                "Provisional",
                AVADataTypes.RecognisedStateStatus.Vested,
                "Vested",
                "generic-transition-source-must-be-registered"
            );
        }
        if (rowId == 17) {
            return _genericTransitionRow(
                AVADataTypes.RecognisedStateStatus.Challengeable,
                "Challengeable",
                AVADataTypes.RecognisedStateStatus.Vested,
                "Vested",
                "challengeable-review-vesting-uses-review-path"
            );
        }
        if (rowId == 18) {
            return _genericTransitionRow(
                AVADataTypes.RecognisedStateStatus.Draft,
                "Draft",
                AVADataTypes.RecognisedStateStatus.Vested,
                "Vested",
                "generic-transition-source-must-be-registered"
            );
        }
        if (rowId == 19) {
            return _genericTransitionRow(
                AVADataTypes.RecognisedStateStatus.Frozen,
                "Frozen",
                AVADataTypes.RecognisedStateStatus.Vested,
                "Vested",
                "generic-transition-source-must-be-registered"
            );
        }
        if (rowId == 20) {
            return _fileChallengeRow(
                AVADataTypes.RecognisedStateStatus.Challengeable,
                "Challengeable",
                "raw-challenge-does-not-mutate-state"
            );
        }
        if (rowId == 21) {
            return _fileChallengeRow(
                AVADataTypes.RecognisedStateStatus.Provisional,
                "Provisional",
                "target-must-be-challengeable-recognised-state"
            );
        }
        if (rowId == 22) return _screenChallengeRow();
        if (rowId == 23) {
            return _resolveChallengeRow(
                AVADataTypes.ChallengeOutcome.Upheld,
                "Upheld",
                AVADataTypes.RecognisedStateStatus.Downgraded,
                "Downgraded",
                "upheld-challenge-can-mutate-state"
            );
        }
        if (rowId == 24) {
            return _resolveChallengeRow(
                AVADataTypes.ChallengeOutcome.Upheld,
                "Upheld",
                AVADataTypes.RecognisedStateStatus.Voided,
                "Voided",
                "upheld-challenge-can-mutate-state"
            );
        }
        if (rowId == 25) {
            return _resolveChallengeRow(
                AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
                "RejectedGoodFaith",
                AVADataTypes.RecognisedStateStatus.Challengeable,
                "Challengeable",
                "failed-good-faith-challenge-no-state-mutation"
            );
        }
        if (rowId == 26) {
            return _resolveChallengeRow(
                AVADataTypes.ChallengeOutcome.Negligent,
                "Negligent",
                AVADataTypes.RecognisedStateStatus.Challengeable,
                "Challengeable",
                "negligent-challenge-record-no-state-mutation"
            );
        }
        if (rowId == 27) {
            return _resolveChallengeRow(
                AVADataTypes.ChallengeOutcome.MaliciousOrFabricated,
                "MaliciousOrFabricated",
                AVADataTypes.RecognisedStateStatus.Challengeable,
                "Challengeable",
                "abuse-finding-record-no-sanction-execution"
            );
        }
        if (rowId == 28) {
            return _resolveChallengeRow(
                AVADataTypes.ChallengeOutcome.Upheld,
                "Upheld",
                AVADataTypes.RecognisedStateStatus.Vested,
                "Vested",
                "upheld-resolution-only-downgrades-or-voids"
            );
        }
        if (rowId == 29) {
            return _restorationRow(
                AVADataTypes.ChallengeOutcome.Upheld,
                "Upheld",
                AVADataTypes.RecognisedStateStatus.Downgraded,
                "Downgraded",
                "explicit-restoration-after-correction"
            );
        }
        if (rowId == 30) {
            return _restorationRow(
                AVADataTypes.ChallengeOutcome.Upheld,
                "Upheld",
                AVADataTypes.RecognisedStateStatus.Voided,
                "Voided",
                "explicit-restoration-after-correction"
            );
        }
        if (rowId == 31) {
            return _restorationRow(
                AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
                "RejectedGoodFaith",
                AVADataTypes.RecognisedStateStatus.Challengeable,
                "Challengeable",
                "explicit-restoration-after-failed-good-faith-challenge"
            );
        }
        if (rowId == 32) {
            return _restorationRow(
                AVADataTypes.ChallengeOutcome.MaliciousOrFabricated,
                "MaliciousOrFabricated",
                AVADataTypes.RecognisedStateStatus.Challengeable,
                "Challengeable",
                "explicit-restoration-after-abusive-challenge"
            );
        }
        if (rowId == 33) {
            return _restorationRow(
                AVADataTypes.ChallengeOutcome.Negligent,
                "Negligent",
                AVADataTypes.RecognisedStateStatus.Challengeable,
                "Challengeable",
                "negligent-outcome-does-not-enable-restoration"
            );
        }
        if (rowId == 34) return _closeChallengeRow();
        revert("unknown-matrix-row");
    }

    function _header() internal pure returns (string memory) {
        return "domain,action,from_status,to_status,outcome,admissibility,ledger_effect,notes\n";
    }

    function _registrationRows() internal returns (string memory) {
        return string.concat(
            _registrationRow(AVADataTypes.RecognisedStateStatus.Draft, "Draft", "None-to-low-impact-status"),
            _registrationRow(AVADataTypes.RecognisedStateStatus.Registered, "Registered", "None-to-low-impact-status"),
            _registrationRow(AVADataTypes.RecognisedStateStatus.Provisional, "Provisional", "None-to-low-impact-status"),
            _registrationRow(AVADataTypes.RecognisedStateStatus.Challengeable, "Challengeable", "None-to-low-impact-status"),
            _registrationRow(
                AVADataTypes.RecognisedStateStatus.Frozen, "Frozen", "downstream-ineligible-low-impact-registration"
            ),
            _registrationRow(
                AVADataTypes.RecognisedStateStatus.Vested, "Vested", "high-impact-status-must-be-transition-generated"
            ),
            _registrationRow(
                AVADataTypes.RecognisedStateStatus.Downgraded,
                "Downgraded",
                "high-impact-status-must-be-challenge-generated"
            ),
            _registrationRow(
                AVADataTypes.RecognisedStateStatus.Voided, "Voided", "high-impact-status-must-be-challenge-generated"
            ),
            _registrationRow(
                AVADataTypes.RecognisedStateStatus.Restored, "Restored", "high-impact-status-must-be-restoration-generated"
            )
        );
    }

    function _reviewAndGenericRows() internal returns (string memory) {
        return string.concat(
            _reviewProvisionalRow(),
            _openChallengeWindowRow(),
            _reviewVestingRow(),
            _genericTransitionRow(
                AVADataTypes.RecognisedStateStatus.Registered,
                "Registered",
                AVADataTypes.RecognisedStateStatus.Vested,
                "Vested",
                "generic-vesting-only"
            ),
            _genericTransitionRow(
                AVADataTypes.RecognisedStateStatus.Registered,
                "Registered",
                AVADataTypes.RecognisedStateStatus.Downgraded,
                "Downgraded",
                "correction-status-needs-challenge-path"
            ),
            _genericTransitionRow(
                AVADataTypes.RecognisedStateStatus.Registered,
                "Registered",
                AVADataTypes.RecognisedStateStatus.Voided,
                "Voided",
                "correction-status-needs-challenge-path"
            ),
            _genericTransitionRow(
                AVADataTypes.RecognisedStateStatus.Registered,
                "Registered",
                AVADataTypes.RecognisedStateStatus.Restored,
                "Restored",
                "restoration-needs-restoration-path"
            ),
            _genericTransitionRow(
                AVADataTypes.RecognisedStateStatus.Provisional,
                "Provisional",
                AVADataTypes.RecognisedStateStatus.Vested,
                "Vested",
                "generic-transition-source-must-be-registered"
            ),
            _genericTransitionRow(
                AVADataTypes.RecognisedStateStatus.Challengeable,
                "Challengeable",
                AVADataTypes.RecognisedStateStatus.Vested,
                "Vested",
                "challengeable-review-vesting-uses-review-path"
            ),
            _genericTransitionRow(
                AVADataTypes.RecognisedStateStatus.Draft,
                "Draft",
                AVADataTypes.RecognisedStateStatus.Vested,
                "Vested",
                "generic-transition-source-must-be-registered"
            ),
            _genericTransitionRow(
                AVADataTypes.RecognisedStateStatus.Frozen,
                "Frozen",
                AVADataTypes.RecognisedStateStatus.Vested,
                "Vested",
                "generic-transition-source-must-be-registered"
            )
        );
    }

    function _challengeRows() internal returns (string memory) {
        return string.concat(
            _fileChallengeRow(
                AVADataTypes.RecognisedStateStatus.Challengeable,
                "Challengeable",
                "raw-challenge-does-not-mutate-state"
            ),
            _fileChallengeRow(
                AVADataTypes.RecognisedStateStatus.Provisional,
                "Provisional",
                "target-must-be-challengeable-recognised-state"
            ),
            _screenChallengeRow(),
            _resolveChallengeRow(
                AVADataTypes.ChallengeOutcome.Upheld,
                "Upheld",
                AVADataTypes.RecognisedStateStatus.Downgraded,
                "Downgraded",
                "upheld-challenge-can-mutate-state"
            ),
            _resolveChallengeRow(
                AVADataTypes.ChallengeOutcome.Upheld,
                "Upheld",
                AVADataTypes.RecognisedStateStatus.Voided,
                "Voided",
                "upheld-challenge-can-mutate-state"
            ),
            _resolveChallengeRow(
                AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
                "RejectedGoodFaith",
                AVADataTypes.RecognisedStateStatus.Challengeable,
                "Challengeable",
                "failed-good-faith-challenge-no-state-mutation"
            ),
            _resolveChallengeRow(
                AVADataTypes.ChallengeOutcome.Negligent,
                "Negligent",
                AVADataTypes.RecognisedStateStatus.Challengeable,
                "Challengeable",
                "negligent-challenge-record-no-state-mutation"
            ),
            _resolveChallengeRow(
                AVADataTypes.ChallengeOutcome.MaliciousOrFabricated,
                "MaliciousOrFabricated",
                AVADataTypes.RecognisedStateStatus.Challengeable,
                "Challengeable",
                "abuse-finding-record-no-sanction-execution"
            ),
            _resolveChallengeRow(
                AVADataTypes.ChallengeOutcome.Upheld,
                "Upheld",
                AVADataTypes.RecognisedStateStatus.Vested,
                "Vested",
                "upheld-resolution-only-downgrades-or-voids"
            )
        );
    }

    function _restorationRows() internal returns (string memory) {
        return string.concat(
            _restorationRow(
                AVADataTypes.ChallengeOutcome.Upheld,
                "Upheld",
                AVADataTypes.RecognisedStateStatus.Downgraded,
                "Downgraded",
                "explicit-restoration-after-correction"
            ),
            _restorationRow(
                AVADataTypes.ChallengeOutcome.Upheld,
                "Upheld",
                AVADataTypes.RecognisedStateStatus.Voided,
                "Voided",
                "explicit-restoration-after-correction"
            ),
            _restorationRow(
                AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
                "RejectedGoodFaith",
                AVADataTypes.RecognisedStateStatus.Challengeable,
                "Challengeable",
                "explicit-restoration-after-failed-good-faith-challenge"
            ),
            _restorationRow(
                AVADataTypes.ChallengeOutcome.MaliciousOrFabricated,
                "MaliciousOrFabricated",
                AVADataTypes.RecognisedStateStatus.Challengeable,
                "Challengeable",
                "explicit-restoration-after-abusive-challenge"
            ),
            _restorationRow(
                AVADataTypes.ChallengeOutcome.Negligent,
                "Negligent",
                AVADataTypes.RecognisedStateStatus.Challengeable,
                "Challengeable",
                "negligent-outcome-does-not-enable-restoration"
            ),
            _closeChallengeRow()
        );
    }

    function _registrationRow(
        AVADataTypes.RecognisedStateStatus status,
        string memory toStatus,
        string memory note
    ) internal returns (string memory) {
        _deployAndConfigure();
        uint256 disclosurePolicyId = _registerDisclosurePolicy("registration");
        uint256 evidenceReceiptId = _registerEditorEvidence(disclosurePolicyId, "registration");
        Counters memory beforeCounters = _counters();
        bool allowed;
        try this.tryRegisterMatrixState(
            status, evidenceReceiptId, disclosurePolicyId, keccak256(abi.encode("matrix-registration", status))
        ) returns (uint256) {
            allowed = true;
        } catch {
            allowed = false;
        }
        return _row(
            "recognised_state",
            "RegisterRecognisedState",
            "None",
            toStatus,
            "None",
            allowed,
            _ledgerEffect(beforeCounters),
            note
        );
    }

    function _reviewProvisionalRow() internal returns (string memory) {
        _deployAndConfigure();
        uint256 reviewContributionId = _createSubmittedReview("provisional");
        Counters memory beforeCounters = _counters();
        bool allowed;
        try demoActor.provisionallyRecogniseReview(
            stateMachine, AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY
        ) returns (uint256) {
            allowed = true;
        } catch {
            allowed = false;
        }
        return _row(
            "review_recognition",
            "ProvisionallyRecogniseReview",
            "None",
            "Provisional",
            "None",
            allowed,
            _ledgerEffect(beforeCounters),
            "review-derived-recognised-state"
        );
    }

    function _openChallengeWindowRow() internal returns (string memory) {
        _deployAndConfigure();
        uint256 reviewContributionId = _createProvisionalReview("open-window");
        Counters memory beforeCounters = _counters();
        bool allowed;
        try demoActor.openReviewChallengeWindow(
            stateMachine, AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY
        ) {
            allowed = true;
        } catch {
            allowed = false;
        }
        return _row(
            "review_recognition",
            "OpenChallengeWindow",
            "Provisional",
            "Challengeable",
            "None",
            allowed,
            _ledgerEffect(beforeCounters),
            "opens-challengeable-window"
        );
    }

    function _reviewVestingRow() internal returns (string memory) {
        _deployAndConfigure();
        uint256 reviewContributionId = _createChallengeWindowReview("review-vesting");
        Counters memory beforeCounters = _counters();
        bool allowed;
        try panelDemoActor.vestReviewRecognition(
            stateMachine,
            AVADataTypes.Role.Panel,
            reviewContributionId,
            PANEL_AUTHORITY,
            "ipfs://matrix-review-vesting"
        ) returns (uint256) {
            allowed = true;
        } catch {
            allowed = false;
        }
        return _row(
            "review_recognition",
            "TransitionRecognisedState",
            "Challengeable",
            "Vested",
            "None",
            allowed,
            _ledgerEffect(beforeCounters),
            "review-vesting-requires-no-open-challenge"
        );
    }

    function _genericTransitionRow(
        AVADataTypes.RecognisedStateStatus fromStatus,
        string memory fromStatusLabel,
        AVADataTypes.RecognisedStateStatus toStatus,
        string memory toStatusLabel,
        string memory note
    ) internal returns (string memory) {
        _deployAndConfigure();
        uint256 recognisedStateId = _createDirectRecognisedState(fromStatus, note);
        Counters memory beforeCounters = _counters();
        bool allowed;
        try panelDemoActor.transitionRecognisedState(
            stateMachine, AVADataTypes.Role.Panel, recognisedStateId, toStatus, PANEL_AUTHORITY, "ipfs://matrix-generic"
        ) returns (uint256) {
            allowed = true;
        } catch {
            allowed = false;
        }
        return _row(
            "generic_transition",
            "TransitionRecognisedState",
            fromStatusLabel,
            toStatusLabel,
            "None",
            allowed,
            _ledgerEffect(beforeCounters),
            note
        );
    }

    function _fileChallengeRow(
        AVADataTypes.RecognisedStateStatus fromStatus,
        string memory fromStatusLabel,
        string memory note
    ) internal returns (string memory) {
        _deployAndConfigure();
        ChallengePath memory path = _createDirectChallengeTarget(fromStatus, note);
        uint256 challengeEvidenceId = _registerChallengeEvidence(path.disclosurePolicyId, note);
        Counters memory beforeCounters = _counters();
        bool allowed;
        try challengerDemoActor.fileChallenge(
            stateMachine,
            AVADataTypes.Role.Challenger,
            path.recognisedStateId,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            path.disclosurePolicyId
        ) returns (uint256) {
            allowed = true;
        } catch {
            allowed = false;
        }
        return _row(
            "challenge",
            "FileChallenge",
            fromStatusLabel,
            fromStatusLabel,
            "None",
            allowed,
            _ledgerEffect(beforeCounters),
            note
        );
    }

    function _screenChallengeRow() internal returns (string memory) {
        _deployAndConfigure();
        ChallengePath memory path = _createFiledChallenge("screen");
        Counters memory beforeCounters = _counters();
        bool allowed;
        try demoActor.screenChallenge(stateMachine, AVADataTypes.Role.Editor, path.challengeId, EDITOR_AUTHORITY) {
            allowed = true;
        } catch {
            allowed = false;
        }
        return _row(
            "challenge",
            "ScreenChallenge",
            "Challengeable",
            "Challengeable",
            "None",
            allowed,
            _ledgerEffect(beforeCounters),
            "screening-does-not-decide-truth"
        );
    }

    function _resolveChallengeRow(
        AVADataTypes.ChallengeOutcome outcome,
        string memory outcomeLabel,
        AVADataTypes.RecognisedStateStatus toStatus,
        string memory toStatusLabel,
        string memory note
    ) internal returns (string memory) {
        _deployAndConfigure();
        ChallengePath memory path = _createScreenedChallenge("resolve");
        Counters memory beforeCounters = _counters();
        bool allowed;
        try panelDemoActor.resolveChallenge(
            stateMachine,
            AVADataTypes.Role.Panel,
            path.challengeId,
            outcome,
            toStatus,
            PANEL_AUTHORITY,
            "ipfs://matrix-resolve"
        ) {
            allowed = true;
        } catch {
            allowed = false;
        }
        return _row(
            "challenge",
            "ResolveChallenge",
            "Challengeable",
            toStatusLabel,
            outcomeLabel,
            allowed,
            _ledgerEffect(beforeCounters),
            note
        );
    }

    function _restorationRow(
        AVADataTypes.ChallengeOutcome outcome,
        string memory outcomeLabel,
        AVADataTypes.RecognisedStateStatus fromStatus,
        string memory fromStatusLabel,
        string memory note
    ) internal returns (string memory) {
        _deployAndConfigure();
        authorityMatrix.setPermission(AVADataTypes.Role.Panel, AVADataTypes.Action.ApplyRestoration, true);
        ChallengePath memory path = _createResolvedChallenge(outcome, fromStatus, note);
        Counters memory beforeCounters = _counters();
        bool allowed;
        try panelDemoActor.applyRestoration(
            stateMachine, AVADataTypes.Role.Panel, path.challengeId, PANEL_AUTHORITY, "ipfs://matrix-restoration"
        ) {
            allowed = true;
        } catch {
            allowed = false;
        }
        return _row(
            "restoration",
            "ApplyRestoration",
            fromStatusLabel,
            "Restored",
            outcomeLabel,
            allowed,
            _ledgerEffect(beforeCounters),
            note
        );
    }

    function _closeChallengeRow() internal returns (string memory) {
        _deployAndConfigure();
        authorityMatrix.setPermission(AVADataTypes.Role.Panel, AVADataTypes.Action.CloseChallenge, true);
        ChallengePath memory path = _createResolvedChallenge(
            AVADataTypes.ChallengeOutcome.RejectedGoodFaith,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            "close"
        );
        Counters memory beforeCounters = _counters();
        bool allowed;
        try panelDemoActor.closeChallenge(
            stateMachine, AVADataTypes.Role.Panel, path.challengeId, PANEL_AUTHORITY, "ipfs://matrix-close"
        ) {
            allowed = true;
        } catch {
            allowed = false;
        }
        return _row(
            "challenge",
            "CloseChallenge",
            "Challengeable",
            "Challengeable",
            "RejectedGoodFaith",
            allowed,
            _ledgerEffect(beforeCounters),
            "closure-does-not-mutate-recognised-state"
        );
    }

    function _createSubmittedReview(string memory seed) internal returns (uint256 reviewContributionId) {
        uint256 disclosurePolicyId = _registerDisclosurePolicy(seed);
        uint256 evidenceReceiptId = _registerReviewEvidence(disclosurePolicyId, seed);
        uint256 manuscriptId = demoActor.registerManuscript(
            stateMachine,
            AVADataTypes.Role.Author,
            keccak256(abi.encode("matrix-manuscript", seed)),
            string.concat("ipfs://matrix/", seed, "/manuscript")
        );
        reviewContributionId = demoActor.registerReviewContribution(
            stateMachine,
            AVADataTypes.Role.Reviewer,
            manuscriptId,
            REVIEWER_SUBJECT,
            evidenceReceiptId,
            disclosurePolicyId
        );
    }

    function _createProvisionalReview(string memory seed) internal returns (uint256 reviewContributionId) {
        reviewContributionId = _createSubmittedReview(seed);
        demoActor.provisionallyRecogniseReview(
            stateMachine, AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY
        );
    }

    function _createChallengeWindowReview(string memory seed) internal returns (uint256 reviewContributionId) {
        reviewContributionId = _createProvisionalReview(seed);
        demoActor.openReviewChallengeWindow(stateMachine, AVADataTypes.Role.Editor, reviewContributionId, EDITOR_AUTHORITY);
    }

    function _createDirectRecognisedState(
        AVADataTypes.RecognisedStateStatus status,
        string memory seed
    ) internal returns (uint256 recognisedStateId) {
        uint256 disclosurePolicyId = _registerDisclosurePolicy(seed);
        uint256 evidenceReceiptId = _registerEditorEvidence(disclosurePolicyId, seed);
        recognisedStateId = demoActor.registerRecognisedState(
            stateMachine,
            AVADataTypes.Role.Editor,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            keccak256(abi.encode("matrix-state", seed, status)),
            REVIEWER_SUBJECT,
            evidenceReceiptId,
            disclosurePolicyId,
            EDITOR_AUTHORITY,
            status
        );
    }

    function _createDirectChallengeTarget(
        AVADataTypes.RecognisedStateStatus status,
        string memory seed
    ) internal returns (ChallengePath memory path) {
        path.disclosurePolicyId = _registerDisclosurePolicy(seed);
        uint256 evidenceReceiptId = _registerEditorEvidence(path.disclosurePolicyId, seed);
        path.recognisedStateId = demoActor.registerRecognisedState(
            stateMachine,
            AVADataTypes.Role.Editor,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            keccak256(abi.encode("matrix-challenge-target", seed, status)),
            REVIEWER_SUBJECT,
            evidenceReceiptId,
            path.disclosurePolicyId,
            EDITOR_AUTHORITY,
            status
        );
    }

    function _createFiledChallenge(string memory seed) internal returns (ChallengePath memory path) {
        path = _createDirectChallengeTarget(AVADataTypes.RecognisedStateStatus.Challengeable, seed);
        uint256 challengeEvidenceId = _registerChallengeEvidence(path.disclosurePolicyId, seed);
        path.challengeId = challengerDemoActor.fileChallenge(
            stateMachine,
            AVADataTypes.Role.Challenger,
            path.recognisedStateId,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            path.disclosurePolicyId
        );
    }

    function _createScreenedChallenge(string memory seed) internal returns (ChallengePath memory path) {
        path = _createFiledChallenge(seed);
        demoActor.screenChallenge(stateMachine, AVADataTypes.Role.Editor, path.challengeId, EDITOR_AUTHORITY);
    }

    function _createResolvedChallenge(
        AVADataTypes.ChallengeOutcome outcome,
        AVADataTypes.RecognisedStateStatus toStatus,
        string memory seed
    ) internal returns (ChallengePath memory path) {
        path = _createScreenedChallenge(seed);
        panelDemoActor.resolveChallenge(
            stateMachine,
            AVADataTypes.Role.Panel,
            path.challengeId,
            outcome,
            toStatus,
            PANEL_AUTHORITY,
            "ipfs://matrix-resolved"
        );
    }

    function _registerDisclosurePolicy(string memory seed) internal returns (uint256) {
        return demoActor.registerDisclosurePolicy(
            disclosureRegistry,
            AVADataTypes.Role.Editor,
            string.concat("matrix-policy-", seed),
            string.concat("ipfs://matrix/", seed, "/policy")
        );
    }

    function _registerReviewEvidence(uint256 disclosurePolicyId, string memory seed) internal returns (uint256) {
        return demoActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256(abi.encode("matrix-review-evidence", seed)),
            string.concat("ipfs://matrix/", seed, "/review-evidence"),
            "review-service-occurrence",
            disclosurePolicyId
        );
    }

    function _registerEditorEvidence(uint256 disclosurePolicyId, string memory seed) internal returns (uint256) {
        return demoActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Editor,
            keccak256(abi.encode("matrix-editor-evidence", seed)),
            string.concat("ipfs://matrix/", seed, "/editor-evidence"),
            "matrix-editor-evidence",
            disclosurePolicyId
        );
    }

    function _registerChallengeEvidence(uint256 disclosurePolicyId, string memory seed) internal returns (uint256) {
        return challengerDemoActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            keccak256(abi.encode("matrix-challenge-evidence", seed)),
            string.concat("ipfs://matrix/", seed, "/challenge-evidence"),
            "review-quality-challenge",
            disclosurePolicyId
        );
    }

    function tryRegisterMatrixState(
        AVADataTypes.RecognisedStateStatus status,
        uint256 evidenceReceiptId,
        uint256 disclosurePolicyId,
        bytes32 objectId
    ) external returns (uint256) {
        return demoActor.registerRecognisedState(
            stateMachine,
            AVADataTypes.Role.Editor,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            objectId,
            REVIEWER_SUBJECT,
            evidenceReceiptId,
            disclosurePolicyId,
            EDITOR_AUTHORITY,
            status
        );
    }

    function _counters() internal view returns (Counters memory counters) {
        counters.recognisedStateTransitionId = stateMachine.nextRecognisedStateTransitionId();
        counters.challengeId = stateMachine.nextChallengeId();
        counters.challengeTransitionId = stateMachine.nextChallengeTransitionId();
    }

    function _ledgerEffect(Counters memory beforeCounters) internal view returns (string memory) {
        bool recognisedStateTransition =
            stateMachine.nextRecognisedStateTransitionId() > beforeCounters.recognisedStateTransitionId;
        bool challengeRecord = stateMachine.nextChallengeId() > beforeCounters.challengeId;
        bool challengeTransition = stateMachine.nextChallengeTransitionId() > beforeCounters.challengeTransitionId;

        if (recognisedStateTransition && !challengeRecord && !challengeTransition) {
            return "recognised-state-transition";
        }
        if (!recognisedStateTransition && challengeRecord && !challengeTransition) {
            return "challenge-record-only";
        }
        if (!recognisedStateTransition && !challengeRecord && challengeTransition) {
            return "challenge-transition-only";
        }
        if (recognisedStateTransition && !challengeRecord && challengeTransition) {
            return "challenge-and-recognised-state-transition";
        }
        return "no-ledger";
    }

    function _row(
        string memory domain,
        string memory action,
        string memory fromStatus,
        string memory toStatus,
        string memory outcome,
        bool allowed,
        string memory ledgerEffect,
        string memory notes
    ) internal pure returns (string memory) {
        return string.concat(
            domain,
            ",",
            action,
            ",",
            fromStatus,
            ",",
            toStatus,
            ",",
            outcome,
            ",",
            _admissibility(allowed),
            ",",
            ledgerEffect,
            ",",
            notes,
            "\n"
        );
    }

    function _admissibility(bool allowed) internal pure returns (string memory) {
        return allowed ? "allowed" : "rejected";
    }
}
