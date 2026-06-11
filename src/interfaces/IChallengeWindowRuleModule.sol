// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IChallengeWindowRuleModule {
    /// @notice Optional transition-rule extension for timed review challenge windows.
    /// @dev Validator-only hook. The substrate still owns mutation and open-challenge gates.
    function supportsChallengeWindowRule() external view returns (bool);

    function validateChallengeWindowDuration(
        bytes32 workflowKey,
        uint256 recognisedStateId,
        uint64 openedAt,
        uint64 currentTime,
        address actor
    ) external view;
}
