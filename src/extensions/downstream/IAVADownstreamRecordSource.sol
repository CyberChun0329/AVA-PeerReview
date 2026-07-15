// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVAGovernanceKernel} from "../../core/AVAGovernanceKernel.sol";

interface IAVADownstreamRecordSource {
    struct DownstreamSourceContext {
        uint256 id;
        bytes32 sourceTypeKey;
        uint256 recognisedStateId;
        uint256 recognisedStateTransitionId;
        bytes32 appId;
        bytes32 workflowKey;
        uint256 packageId;
        bytes32 subjectId;
        uint256 evidenceId;
        bytes32 recordTypeKey;
        uint256 units;
    }

    function GOVERNANCE_KERNEL() external view returns (AVAGovernanceKernel);

    function getDownstreamSource(uint256 recordId) external view returns (DownstreamSourceContext memory);
}
