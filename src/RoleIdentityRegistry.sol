// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "./AVADataTypes.sol";

contract RoleIdentityRegistry {
    address public immutable admin;

    mapping(address => mapping(AVADataTypes.Role => bool)) public hasRole;
    mapping(bytes32 => AVADataTypes.RoleSubject) private subjects;
    mapping(address => mapping(AVADataTypes.Role => bytes32)) public subjectOf;

    event RoleAssigned(
        address indexed account, AVADataTypes.Role indexed role, bytes32 indexed subjectId, string metadataURI
    );
    event RoleDeactivated(bytes32 indexed subjectId);

    modifier onlyAdmin() {
        if (msg.sender != admin) revert AVADataTypes.NotAdmin(msg.sender);
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function assignRole(address account, AVADataTypes.Role role, bytes32 subjectId, string calldata metadataURI)
        external
        onlyAdmin
    {
        if (account == address(0) || subjectId == bytes32(0)) revert AVADataTypes.EmptyValue();
        if (role == AVADataTypes.Role.None) revert AVADataTypes.InvalidRole();
        bytes32 currentSubjectId = subjectOf[account][role];
        if (currentSubjectId != bytes32(0) && subjects[currentSubjectId].active) {
            revert AVADataTypes.InvalidState(uint256(currentSubjectId));
        }
        if (subjects[subjectId].subjectId != bytes32(0)) {
            revert AVADataTypes.InvalidState(uint256(subjectId));
        }

        hasRole[account][role] = true;
        subjectOf[account][role] = subjectId;
        subjects[subjectId] = AVADataTypes.RoleSubject({
            account: account, role: role, subjectId: subjectId, metadataURI: metadataURI, active: true
        });

        emit RoleAssigned(account, role, subjectId, metadataURI);
    }

    function deactivateSubject(bytes32 subjectId) external onlyAdmin {
        AVADataTypes.RoleSubject storage subject = subjects[subjectId];
        if (subject.subjectId == bytes32(0)) revert AVADataTypes.UnknownSubject(subjectId);

        subject.active = false;
        if (subjectOf[subject.account][subject.role] == subjectId) {
            subjectOf[subject.account][subject.role] = bytes32(0);
            hasRole[subject.account][subject.role] = false;
        }

        emit RoleDeactivated(subjectId);
    }

    function getSubject(bytes32 subjectId) external view returns (AVADataTypes.RoleSubject memory) {
        AVADataTypes.RoleSubject memory subject = subjects[subjectId];
        if (subject.subjectId == bytes32(0)) revert AVADataTypes.UnknownSubject(subjectId);
        return subject;
    }

    function isKnownActiveSubject(bytes32 subjectId) external view returns (bool) {
        AVADataTypes.RoleSubject memory subject = subjects[subjectId];
        return subject.subjectId != bytes32(0) && subject.active;
    }

    function isSubjectFor(address account, AVADataTypes.Role role, bytes32 subjectId) external view returns (bool) {
        AVADataTypes.RoleSubject memory subject = subjects[subjectId];
        return subject.subjectId != bytes32(0) && subject.active && subject.account == account && subject.role == role
            && subjectOf[account][role] == subjectId;
    }
}
