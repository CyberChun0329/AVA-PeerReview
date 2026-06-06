// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "../AVADataTypes.sol";
import {DisclosurePolicyRegistry} from "../DisclosurePolicyRegistry.sol";
import {ZKProofRegistry} from "../ZKProofRegistry.sol";
import {IDisclosurePolicyModule} from "../interfaces/IDisclosurePolicyModule.sol";

contract ZKBackedDisclosureModule is IDisclosurePolicyModule {
    DisclosurePolicyRegistry public immutable disclosureRegistry;
    ZKProofRegistry public immutable proofRegistry;
    uint256 public immutable zkDisclosurePolicyId;

    struct ProofContext {
        uint256 packageId;
        bytes32 workflowKey;
        AVADataTypes.AVAStage stage;
        AVADataTypes.Action action;
        bytes32 objectId;
        AVADataTypes.Role actingRole;
        uint256 disclosurePolicyId;
        bytes32 subjectCommitment;
    }

    constructor(
        DisclosurePolicyRegistry disclosureRegistry_,
        ZKProofRegistry proofRegistry_,
        uint256 zkDisclosurePolicyId_
    ) {
        if (address(disclosureRegistry_) == address(0) || address(proofRegistry_) == address(0)) {
            revert AVADataTypes.EmptyValue();
        }
        if (zkDisclosurePolicyId_ == 0) revert AVADataTypes.EmptyValue();
        disclosureRegistry = disclosureRegistry_;
        proofRegistry = proofRegistry_;
        zkDisclosurePolicyId = zkDisclosurePolicyId_;
    }

    function validateDisclosurePolicy(uint256 disclosurePolicyId) external view {
        _validateZkPolicy(disclosurePolicyId);
    }

    function validateDisclosureForAction(
        uint256 disclosurePolicyId,
        AVADataTypes.Role actingRole,
        AVADataTypes.Action action,
        AVADataTypes.AVAStage stage,
        bytes32 objectId,
        bytes32 workflowKey,
        uint256 packageId,
        bytes32 subjectCommitment
    ) external view {
        _validateZkPolicy(disclosurePolicyId);

        ProofContext memory context = ProofContext({
            packageId: packageId,
            workflowKey: workflowKey,
            stage: stage,
            action: action,
            objectId: objectId,
            actingRole: actingRole,
            disclosurePolicyId: disclosurePolicyId,
            subjectCommitment: subjectCommitment
        });
        bytes32 contextHash = _contextHash(context);
        uint256 proofReceiptId = proofRegistry.getProofReceiptId(contextHash);
        if (contextHash == bytes32(0) || proofReceiptId == 0) {
            revert AVADataTypes.InvalidState(disclosurePolicyId);
        }
        if (proofRegistry.getProofReceipt(proofReceiptId).packageId != packageId) {
            revert AVADataTypes.InvalidState(disclosurePolicyId);
        }
    }

    function _contextHash(ProofContext memory context) internal view returns (bytes32) {
        return proofRegistry.computeDisclosureContextHashForPackage(
            context.packageId,
            context.workflowKey,
            context.stage,
            context.action,
            context.objectId,
            context.actingRole,
            context.disclosurePolicyId,
            context.subjectCommitment
        );
    }

    function _validateZkPolicy(uint256 disclosurePolicyId) internal view {
        if (disclosurePolicyId != zkDisclosurePolicyId) revert AVADataTypes.InvalidState(disclosurePolicyId);
        disclosureRegistry.getDisclosurePolicy(disclosurePolicyId);
    }
}
