// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVAApplicationRegistry} from "../AVAApplicationRegistry.sol";
import {AVACoreTypes} from "./AVACoreTypes.sol";
import {AVAIdentityRegistry} from "./AVAIdentityRegistry.sol";

contract AVAAuthorityMatrix {
    address public immutable ADMIN;
    AVAApplicationRegistry public immutable APPLICATION_REGISTRY;
    AVAIdentityRegistry public immutable IDENTITY_REGISTRY;

    mapping(bytes32 => bool) private permissions;

    event PermissionConfigured(bytes32 indexed appId, bytes32 indexed roleKey, bytes32 indexed actionKey, bool allowed);

    constructor(AVAApplicationRegistry applicationRegistry_, AVAIdentityRegistry identityRegistry_) {
        if (address(applicationRegistry_) == address(0) || address(identityRegistry_) == address(0)) {
            revert AVACoreTypes.EmptyValue();
        }
        if (address(identityRegistry_.APPLICATION_REGISTRY()) != address(applicationRegistry_)) {
            revert AVACoreTypes.InvalidState(0);
        }
        ADMIN = msg.sender;
        APPLICATION_REGISTRY = applicationRegistry_;
        IDENTITY_REGISTRY = identityRegistry_;
    }

    modifier onlyAdmin() {
        if (msg.sender != ADMIN) revert AVACoreTypes.NotAdmin(msg.sender);
        _;
    }

    function setPermission(bytes32 appId, bytes32 roleKey, bytes32 actionKey, bool allowed) external onlyAdmin {
        if (appId == bytes32(0) || roleKey == bytes32(0) || actionKey == bytes32(0)) {
            revert AVACoreTypes.EmptyValue();
        }
        APPLICATION_REGISTRY.requireApplicationReference(appId);
        permissions[_permissionKey(appId, roleKey, actionKey)] = allowed;
        emit PermissionConfigured(appId, roleKey, actionKey, allowed);
    }

    function isAuthorised(address account, bytes32 appId, bytes32 roleKey, bytes32 actionKey)
        public
        view
        returns (bool)
    {
        return permissions[_permissionKey(appId, roleKey, actionKey)]
            && IDENTITY_REGISTRY.subjectOf(account, appId, roleKey) != bytes32(0);
    }

    function requireAuthorisedCanonicalSubject(address account, bytes32 appId, bytes32 roleKey, bytes32 actionKey)
        public
        view
        returns (bytes32 subjectId)
    {
        if (!permissions[_permissionKey(appId, roleKey, actionKey)]) {
            revert AVACoreTypes.NotAuthorised(account, actionKey);
        }
        subjectId = IDENTITY_REGISTRY.subjectOf(account, appId, roleKey);
        if (subjectId == bytes32(0)) revert AVACoreTypes.NotAuthorised(account, actionKey);
    }

    function requireAuthorisedSubject(
        address account,
        bytes32 appId,
        bytes32 roleKey,
        bytes32 actionKey,
        bytes32 authorityId
    ) external view returns (bytes32 subjectId) {
        subjectId = requireAuthorisedCanonicalSubject(account, appId, roleKey, actionKey);
        if (subjectId != authorityId) revert AVACoreTypes.SubjectMismatch(subjectId, authorityId);
    }

    function _permissionKey(bytes32 appId, bytes32 roleKey, bytes32 actionKey) internal pure returns (bytes32) {
        return keccak256(abi.encode(appId, roleKey, actionKey));
    }
}
