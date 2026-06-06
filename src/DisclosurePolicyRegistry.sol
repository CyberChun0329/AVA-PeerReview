// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "./AVADataTypes.sol";
import {AuthorityMatrix} from "./AuthorityMatrix.sol";

contract DisclosurePolicyRegistry {
    AuthorityMatrix public immutable authorityMatrix;
    uint256 public nextDisclosurePolicyId = 1;

    mapping(uint256 => AVADataTypes.DisclosurePolicy) private policies;

    event DisclosurePolicyRegistered(uint256 indexed id, string label, string uri, address registeredBy);

    constructor(AuthorityMatrix authorityMatrix_) {
        authorityMatrix = authorityMatrix_;
    }

    function registerDisclosurePolicy(AVADataTypes.Role actingRole, string calldata label, string calldata uri)
        external
        returns (uint256 id)
    {
        bytes32 authorityId = authorityMatrix.requireAuthorisedCanonicalSubject(
            msg.sender, actingRole, AVADataTypes.Action.RegisterDisclosurePolicy
        );
        if (bytes(label).length == 0) revert AVADataTypes.EmptyValue();

        id = nextDisclosurePolicyId++;
        policies[id] = AVADataTypes.DisclosurePolicy({
            id: id,
            label: label,
            uri: uri,
            authorityRole: actingRole,
            authorityId: authorityId,
            registeredBy: msg.sender,
            active: true
        });

        emit DisclosurePolicyRegistered(id, label, uri, msg.sender);
    }

    function getDisclosurePolicy(uint256 id) external view returns (AVADataTypes.DisclosurePolicy memory) {
        AVADataTypes.DisclosurePolicy memory policy = policies[id];
        if (policy.id == 0) revert AVADataTypes.UnknownReference(id);
        return policy;
    }
}
