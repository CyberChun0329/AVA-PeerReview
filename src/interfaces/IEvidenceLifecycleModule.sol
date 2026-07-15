// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";
import {IRuleModuleIdentity} from "./IRuleModuleIdentity.sol";

interface IEvidenceLifecycleModule is IRuleModuleIdentity {
    function validateEvidenceLifecycle(
        bytes32 workflowKey,
        AVADataTypes.Action action,
        uint256 evidenceReceiptId,
        AVADataTypes.EvidenceLifecycleKind kind,
        uint256 replacementEvidenceReceiptId,
        bytes32 lifecycleReference,
        address actor
    ) external view;
}
