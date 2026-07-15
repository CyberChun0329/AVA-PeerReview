// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVAApplicationRegistry} from "../AVAApplicationRegistry.sol";
import {AVACoreTypes} from "./AVACoreTypes.sol";

contract AVAIdentityRegistry {
    struct SubjectContext {
        bytes32 subjectId;
        bytes32 appId;
        bytes32 roleKey;
        address account;
        bool active;
    }

    address public immutable ADMIN;
    AVAApplicationRegistry public immutable APPLICATION_REGISTRY;

    mapping(bytes32 => AVACoreTypes.SubjectRecord) private subjects;
    mapping(bytes32 => bytes32) private canonicalSubjectByAccountRole;

    event SubjectAssigned(
        bytes32 indexed subjectId, bytes32 indexed appId, bytes32 indexed roleKey, address account, string uri
    );
    event SubjectDeactivated(
        bytes32 indexed subjectId, bytes32 indexed appId, bytes32 indexed roleKey, address account
    );

    constructor(AVAApplicationRegistry applicationRegistry_) {
        if (address(applicationRegistry_) == address(0)) revert AVACoreTypes.EmptyValue();
        ADMIN = msg.sender;
        APPLICATION_REGISTRY = applicationRegistry_;
    }

    modifier onlyAdmin() {
        if (msg.sender != ADMIN) revert AVACoreTypes.NotAdmin(msg.sender);
        _;
    }

    function assignSubject(address account, bytes32 appId, bytes32 roleKey, bytes32 subjectId, string calldata uri)
        external
        onlyAdmin
    {
        if (account == address(0) || appId == bytes32(0) || roleKey == bytes32(0) || subjectId == bytes32(0)) {
            revert AVACoreTypes.EmptyValue();
        }
        APPLICATION_REGISTRY.requireApplicationReference(appId);
        if (subjects[subjectId].subjectId != bytes32(0)) revert AVACoreTypes.InvalidState(uint256(subjectId));

        bytes32 canonicalKey = _canonicalKey(account, appId, roleKey);
        bytes32 existingSubjectId = canonicalSubjectByAccountRole[canonicalKey];
        if (existingSubjectId != bytes32(0) && subjects[existingSubjectId].active) {
            revert AVACoreTypes.InvalidState(uint256(existingSubjectId));
        }

        subjects[subjectId] = AVACoreTypes.SubjectRecord({
            subjectId: subjectId,
            appId: appId,
            roleKey: roleKey,
            account: account,
            uri: uri,
            active: true,
            assignedAt: uint64(block.timestamp),
            deactivatedAt: 0
        });
        canonicalSubjectByAccountRole[canonicalKey] = subjectId;
        emit SubjectAssigned(subjectId, appId, roleKey, account, uri);
    }

    function deactivateSubject(bytes32 subjectId) external onlyAdmin {
        AVACoreTypes.SubjectRecord storage subject = subjects[subjectId];
        if (subject.subjectId == bytes32(0)) revert AVACoreTypes.UnknownReference(uint256(subjectId));
        if (!subject.active) revert AVACoreTypes.InvalidState(uint256(subjectId));

        subject.active = false;
        subject.deactivatedAt = uint64(block.timestamp);
        bytes32 canonicalKey = _canonicalKey(subject.account, subject.appId, subject.roleKey);
        if (canonicalSubjectByAccountRole[canonicalKey] == subjectId) {
            delete canonicalSubjectByAccountRole[canonicalKey];
        }
        emit SubjectDeactivated(subjectId, subject.appId, subject.roleKey, subject.account);
    }

    function subjectOf(address account, bytes32 appId, bytes32 roleKey) public view returns (bytes32 subjectId) {
        subjectId = canonicalSubjectByAccountRole[_canonicalKey(account, appId, roleKey)];
        if (subjectId != bytes32(0) && !subjects[subjectId].active) return bytes32(0);
    }

    function hasRole(address account, bytes32 appId, bytes32 roleKey) external view returns (bool) {
        return subjectOf(account, appId, roleKey) != bytes32(0);
    }

    function requireActiveSubject(bytes32 subjectId, bytes32 appId)
        external
        view
        returns (AVACoreTypes.SubjectRecord memory subject)
    {
        AVACoreTypes.SubjectRecord storage stored = _requireActiveSubject(subjectId, appId);
        subject = stored;
    }

    function getSubject(bytes32 subjectId) external view returns (AVACoreTypes.SubjectRecord memory subject) {
        AVACoreTypes.SubjectRecord storage stored = _subject(subjectId);
        subject = stored;
    }

    function getSubjectContext(bytes32 subjectId) external view returns (SubjectContext memory context) {
        context = _subjectContext(_subject(subjectId));
    }

    function requireActiveSubjectContext(bytes32 subjectId, bytes32 appId)
        external
        view
        returns (SubjectContext memory context)
    {
        context = _subjectContext(_requireActiveSubject(subjectId, appId));
    }

    function requireActiveSubjectReference(bytes32 subjectId, bytes32 appId) external view {
        _requireActiveSubject(subjectId, appId);
    }

    function _subject(bytes32 subjectId) private view returns (AVACoreTypes.SubjectRecord storage subject) {
        subject = subjects[subjectId];
        if (subject.subjectId == bytes32(0)) revert AVACoreTypes.UnknownReference(uint256(subjectId));
    }

    function _requireActiveSubject(bytes32 subjectId, bytes32 appId)
        private
        view
        returns (AVACoreTypes.SubjectRecord storage subject)
    {
        subject = _subject(subjectId);
        if (!subject.active) revert AVACoreTypes.UnknownReference(uint256(subjectId));
        if (subject.appId != appId) revert AVACoreTypes.CrossApplicationReference(appId, subject.appId);
    }

    function _subjectContext(AVACoreTypes.SubjectRecord storage subject)
        private
        view
        returns (SubjectContext memory context)
    {
        context = SubjectContext({
            subjectId: subject.subjectId,
            appId: subject.appId,
            roleKey: subject.roleKey,
            account: subject.account,
            active: subject.active
        });
    }

    function _canonicalKey(address account, bytes32 appId, bytes32 roleKey) internal pure returns (bytes32) {
        return keccak256(abi.encode(account, appId, roleKey));
    }
}
