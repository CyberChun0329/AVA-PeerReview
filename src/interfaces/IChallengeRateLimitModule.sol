// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IChallengeRateLimitModule {
    /// @notice Optional anti-abuse extension for repeated challenge filing checks.
    /// @dev Success means only that the package-selected module did not veto this filing.
    function supportsChallengeRateLimit() external view returns (bool);

    function validateChallengeFiling(
        bytes32 workflowKey,
        uint256 challengedRecognisedStateId,
        bytes32 challengerSubjectId,
        uint256 priorFilingCount,
        address actor
    ) external view;
}
