// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVAApplicationRegistry} from "../AVAApplicationRegistry.sol";
import {AVAAuthorityMatrix} from "./AVAAuthorityMatrix.sol";
import {AVACoreTypes} from "./AVACoreTypes.sol";

contract AVADisclosurePolicyRegistry {
    /// @notice Fixed-size disclosure policy context for contract-to-contract validation paths.
    /// @dev Full labels, URI, registrar, and timestamp remain available through getPolicy.
    struct DisclosurePolicyReference {
        uint256 id;
        bytes32 appId;
        bytes32 policyKey;
        bytes32 authorityId;
        bool active;
    }

    AVAApplicationRegistry public immutable APPLICATION_REGISTRY;
    AVAAuthorityMatrix public immutable AUTHORITY_MATRIX;

    mapping(uint256 => AVACoreTypes.DisclosurePolicyRecord) private policies;
    mapping(bytes32 => uint256) private policyIdByApplicationKey;
    uint256 public nextPolicyId = 1;

    event DisclosurePolicyRegistered(
        uint256 indexed policyId,
        bytes32 indexed appId,
        bytes32 indexed policyKey,
        bytes32 authorityId,
        address registeredBy
    );

    constructor(AVAApplicationRegistry applicationRegistry_, AVAAuthorityMatrix authorityMatrix_) {
        if (address(applicationRegistry_) == address(0) || address(authorityMatrix_) == address(0)) {
            revert AVACoreTypes.EmptyValue();
        }
        if (address(authorityMatrix_.APPLICATION_REGISTRY()) != address(applicationRegistry_)) {
            revert AVACoreTypes.InvalidState(0);
        }
        APPLICATION_REGISTRY = applicationRegistry_;
        AUTHORITY_MATRIX = authorityMatrix_;
    }

    function registerPolicy(
        bytes32 appId,
        bytes32 roleKey,
        bytes32 authorityId,
        bytes32 policyKey,
        string calldata label,
        string calldata uri
    ) external returns (uint256 policyId) {
        if (
            appId == bytes32(0) || roleKey == bytes32(0) || authorityId == bytes32(0)
                || policyKey == bytes32(0) || bytes(label).length == 0
        ) {
            revert AVACoreTypes.EmptyValue();
        }
        APPLICATION_REGISTRY.requireApplicationReference(appId);
        bytes32 callerAuthorityId = AUTHORITY_MATRIX.requireAuthorisedCanonicalSubject(
            msg.sender, appId, roleKey, AVACoreTypes.ACTION_REGISTER_DISCLOSURE_POLICY
        );
        if (callerAuthorityId != authorityId) {
            revert AVACoreTypes.SubjectMismatch(callerAuthorityId, authorityId);
        }
        bytes32 policyIndexKey = keccak256(abi.encode(appId, policyKey));
        if (policyIdByApplicationKey[policyIndexKey] != 0) {
            revert AVACoreTypes.InvalidState(policyIdByApplicationKey[policyIndexKey]);
        }

        policyId = nextPolicyId++;
        policies[policyId] = AVACoreTypes.DisclosurePolicyRecord({
            id: policyId,
            appId: appId,
            policyKey: policyKey,
            label: label,
            uri: uri,
            authorityId: authorityId,
            registeredBy: msg.sender,
            registeredAt: uint64(block.timestamp),
            active: true
        });
        policyIdByApplicationKey[policyIndexKey] = policyId;
        emit DisclosurePolicyRegistered(policyId, appId, policyKey, authorityId, msg.sender);
    }

    function getPolicy(uint256 policyId) public view returns (AVACoreTypes.DisclosurePolicyRecord memory policy) {
        policy = policies[policyId];
        if (policy.id == 0) revert AVACoreTypes.UnknownReference(policyId);
    }

    function getPolicyReference(uint256 policyId)
        external
        view
        returns (DisclosurePolicyReference memory policyRef)
    {
        AVACoreTypes.DisclosurePolicyRecord storage policy = _policyStorage(policyId);
        policyRef = DisclosurePolicyReference({
            id: policy.id,
            appId: policy.appId,
            policyKey: policy.policyKey,
            authorityId: policy.authorityId,
            active: policy.active
        });
    }

    function requireActivePolicy(uint256 policyId, bytes32 appId)
        external
        view
        returns (AVACoreTypes.DisclosurePolicyRecord memory policy)
    {
        policy = getPolicy(policyId);
        if (!policy.active || policy.appId != appId) revert AVACoreTypes.InvalidState(policyId);
    }

    function requireActivePolicyReference(uint256 policyId, bytes32 appId) external view {
        AVACoreTypes.DisclosurePolicyRecord storage policy = _policyStorage(policyId);
        if (!policy.active || policy.appId != appId) revert AVACoreTypes.InvalidState(policyId);
    }

    function _policyStorage(uint256 policyId)
        private
        view
        returns (AVACoreTypes.DisclosurePolicyRecord storage policy)
    {
        policy = policies[policyId];
        if (policy.id == 0) revert AVACoreTypes.UnknownReference(policyId);
    }
}
