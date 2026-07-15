// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "./AVADataTypes.sol";
import {IRuleModuleIdentity} from "./interfaces/IRuleModuleIdentity.sol";

/// @notice Aggregates self-reported, re-verifiable rule-module identities.
/// @dev Proxy modules are intentionally unsupported because a stable proxy
/// address and runtime codehash cannot prove immutable implementation behavior.
contract RulePackageIdentityVerifier {
    bytes32 public constant PACKAGE_IDENTITY_DOMAIN = keccak256("AVA_RULE_PACKAGE_MODULE_IDENTITIES_V1");

    function hashModuleIdentities(address[] calldata modules) external view returns (bytes32) {
        if (modules.length == 0) revert AVADataTypes.EmptyValue();
        bytes32 aggregate = PACKAGE_IDENTITY_DOMAIN;
        for (uint256 i = 0; i < modules.length; i++) {
            address module = modules[i];
            if (module == address(0) || module.code.length == 0) revert AVADataTypes.EmptyValue();
            bytes32 identity = IRuleModuleIdentity(module).moduleIdentityHash();
            if (identity == bytes32(0)) revert AVADataTypes.EmptyValue();
            aggregate = keccak256(abi.encode(aggregate, module, identity));
        }
        return aggregate;
    }
}
