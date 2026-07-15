// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IRuleModuleIdentity {
    /// @notice Re-verifiable identity for runtime behavior and immutable configuration.
    function moduleIdentityHash() external view returns (bytes32);
}

abstract contract RuleModuleIdentity is IRuleModuleIdentity {
    bytes32 private constant MODULE_IDENTITY_DOMAIN = keccak256("AVA_RULE_MODULE_IDENTITY_V1");

    function moduleIdentityHash() external view virtual returns (bytes32) {
        return keccak256(
            abi.encode(MODULE_IDENTITY_DOMAIN, address(this).codehash, _moduleConfigurationHash())
        );
    }

    function _moduleConfigurationHash() internal view virtual returns (bytes32) {
        return bytes32(0);
    }
}
