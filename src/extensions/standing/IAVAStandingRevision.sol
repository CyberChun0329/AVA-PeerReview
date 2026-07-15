// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVAGovernanceKernel} from "../../core/AVAGovernanceKernel.sol";

interface IAVAStandingRevision {
    function GOVERNANCE_KERNEL() external view returns (AVAGovernanceKernel);

    function currentRevision(uint256 packageId, bytes32 subjectId) external view returns (uint256);

    function advanceRevision(
        bytes32 appId,
        uint256 packageId,
        bytes32 subjectId,
        bytes32 sourceTypeKey,
        uint256 sourceRecordId
    ) external returns (uint256 revision);
}
