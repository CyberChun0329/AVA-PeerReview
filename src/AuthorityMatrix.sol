// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "./AVADataTypes.sol";
import {RoleIdentityRegistry} from "./RoleIdentityRegistry.sol";

contract AuthorityMatrix {
    address public immutable admin;
    RoleIdentityRegistry public immutable roleRegistry;

    mapping(AVADataTypes.Role => mapping(AVADataTypes.Action => bool)) public isPermitted;

    event PermissionSet(AVADataTypes.Role indexed role, AVADataTypes.Action indexed action, bool permitted);

    modifier onlyAdmin() {
        if (msg.sender != admin) revert AVADataTypes.NotAdmin(msg.sender);
        _;
    }

    constructor(RoleIdentityRegistry roleRegistry_) {
        admin = msg.sender;
        roleRegistry = roleRegistry_;
    }

    function setPermission(AVADataTypes.Role role, AVADataTypes.Action action, bool permitted) external onlyAdmin {
        if (role == AVADataTypes.Role.None) revert AVADataTypes.InvalidRole();
        isPermitted[role][action] = permitted;
        emit PermissionSet(role, action, permitted);
    }

    function requireAuthorised(address actor, AVADataTypes.Role role, AVADataTypes.Action action) external view {
        if (!roleRegistry.hasRole(actor, role) || !isPermitted[role][action]) {
            revert AVADataTypes.NotAuthorised(actor, action);
        }
    }

    function requireAuthorisedSubject(
        address actor,
        AVADataTypes.Role role,
        AVADataTypes.Action action,
        bytes32 subjectId
    ) external view {
        if (
            !roleRegistry.hasRole(actor, role) || !isPermitted[role][action]
                || !roleRegistry.isSubjectFor(actor, role, subjectId)
        ) {
            revert AVADataTypes.NotAuthorised(actor, action);
        }
    }

    function requireAuthorisedCanonicalSubject(address actor, AVADataTypes.Role role, AVADataTypes.Action action)
        external
        view
        returns (bytes32 subjectId)
    {
        subjectId = roleRegistry.subjectOf(actor, role);
        if (
            subjectId == bytes32(0) || !roleRegistry.hasRole(actor, role) || !isPermitted[role][action]
                || !roleRegistry.isSubjectFor(actor, role, subjectId)
        ) {
            revert AVADataTypes.NotAuthorised(actor, action);
        }
    }

    function requireSubjectForRole(address actor, AVADataTypes.Role role, bytes32 subjectId) external view {
        if (!roleRegistry.isSubjectFor(actor, role, subjectId)) {
            revert AVADataTypes.NotAuthorised(actor, AVADataTypes.Action.RegisterRecognisedState);
        }
    }

    function requireKnownActiveSubject(bytes32 subjectId) external view {
        if (!roleRegistry.isKnownActiveSubject(subjectId)) {
            revert AVADataTypes.UnknownSubject(subjectId);
        }
    }
}
