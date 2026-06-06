// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";

interface IDisclosureLifecycleModule {
    function validateDisclosureLifecycle(
        bytes32 workflowKey,
        AVADataTypes.Action action,
        uint256 disclosurePolicyId,
        AVADataTypes.DisclosureLifecycleKind kind,
        bytes32 lifecycleReference,
        address actor
    ) external view;
}
