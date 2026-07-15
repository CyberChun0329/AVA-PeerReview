// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVAGovernanceKernel} from "../../core/AVAGovernanceKernel.sol";

interface IAVASettlementReceiptSource {
    struct SettlementSourceContext {
        uint256 id;
        uint256 recognisedStateId;
        uint256 recognisedStateTransitionId;
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 subjectId;
        uint256 evidenceId;
        address sourceRegistry;
        bytes32 sourceTypeKey;
        uint256 sourceRecordId;
        bytes32 settlementKindKey;
        uint256 units;
        bytes32 referenceHash;
    }

    function GOVERNANCE_KERNEL() external view returns (AVAGovernanceKernel);

    function getSettlementSource(uint256 settlementId) external view returns (SettlementSourceContext memory);
}
