// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVACoreTypes} from "./core/AVACoreTypes.sol";

/// @notice Append-only registry of AVA application namespaces.
/// @dev Application lifecycle and migration are intentionally outside M14.2.
contract AVAApplicationRegistry {
    struct ApplicationRecord {
        bytes32 appId;
        bytes32 applicationIdentityHash;
        bytes32 authorityId;
        string uri;
        address registeredBy;
    }

    address public immutable ADMIN;

    mapping(bytes32 => ApplicationRecord) private applications;

    event ApplicationRegistered(
        bytes32 indexed appId,
        bytes32 indexed applicationIdentityHash,
        bytes32 indexed authorityId,
        string uri,
        address registeredBy
    );

    constructor() {
        ADMIN = msg.sender;
    }

    function registerApplication(
        bytes32 appId,
        bytes32 applicationIdentityHash,
        bytes32 authorityId,
        string calldata uri
    ) external {
        if (msg.sender != ADMIN) revert AVACoreTypes.NotAdmin(msg.sender);
        if (
            appId == bytes32(0) || applicationIdentityHash == bytes32(0) || authorityId == bytes32(0)
                || bytes(uri).length == 0
        ) {
            revert AVACoreTypes.EmptyValue();
        }
        if (applications[appId].appId != bytes32(0)) {
            revert AVACoreTypes.InvalidState(uint256(appId));
        }

        applications[appId] = ApplicationRecord({
            appId: appId,
            applicationIdentityHash: applicationIdentityHash,
            authorityId: authorityId,
            uri: uri,
            registeredBy: msg.sender
        });
        emit ApplicationRegistered(appId, applicationIdentityHash, authorityId, uri, msg.sender);
    }

    function getApplication(bytes32 appId) public view returns (ApplicationRecord memory record) {
        record = applications[appId];
        if (record.appId == bytes32(0)) revert AVACoreTypes.UnknownReference(uint256(appId));
    }

    /// @notice Validates an application reference without returning dynamic metadata.
    function requireApplicationReference(bytes32 appId) external view {
        if (applications[appId].appId == bytes32(0)) revert AVACoreTypes.UnknownReference(uint256(appId));
    }
}
