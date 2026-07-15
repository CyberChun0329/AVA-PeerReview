// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "./AVADataTypes.sol";
import {AVAApplicationRegistry} from "./AVAApplicationRegistry.sol";
import {AuthorityMatrix} from "./AuthorityMatrix.sol";

contract DisclosurePolicyRegistry {
    AuthorityMatrix public immutable authorityMatrix;
    AVAApplicationRegistry public immutable applicationRegistry;
    uint256 public nextDisclosurePolicyId = 1;

    mapping(uint256 => AVADataTypes.DisclosurePolicy) private policies;

    event DisclosurePolicyRegistered(
        uint256 indexed id, bytes32 indexed appId, string label, string uri, address registeredBy
    );

    constructor(AuthorityMatrix authorityMatrix_, AVAApplicationRegistry applicationRegistry_) {
        if (address(applicationRegistry_) == address(0)) revert AVADataTypes.EmptyValue();
        authorityMatrix = authorityMatrix_;
        applicationRegistry = applicationRegistry_;
    }

    function registerDisclosurePolicy(
        AVADataTypes.Role actingRole,
        bytes32 appId,
        string calldata label,
        string calldata uri
    ) external returns (uint256 id) {
        bytes32 authorityId = authorityMatrix.requireAuthorisedCanonicalSubject(
            msg.sender, actingRole, AVADataTypes.Action.RegisterDisclosurePolicy
        );
        if (appId == bytes32(0) || bytes(label).length == 0) revert AVADataTypes.EmptyValue();
        applicationRegistry.getApplication(appId);

        id = nextDisclosurePolicyId++;
        policies[id] = AVADataTypes.DisclosurePolicy({
            id: id,
            appId: appId,
            label: label,
            uri: uri,
            authorityRole: actingRole,
            authorityId: authorityId,
            registeredBy: msg.sender,
            active: true
        });

        emit DisclosurePolicyRegistered(id, appId, label, uri, msg.sender);
    }

    function getDisclosurePolicy(uint256 id) external view returns (AVADataTypes.DisclosurePolicy memory) {
        AVADataTypes.DisclosurePolicy memory policy = policies[id];
        if (policy.id == 0) revert AVADataTypes.UnknownReference(id);
        return policy;
    }
}
