// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVADataTypes} from "./AVADataTypes.sol";
import {AVARulePackageRegistry} from "./AVARulePackageRegistry.sol";
import {DisclosurePolicyRegistry} from "./DisclosurePolicyRegistry.sol";
import {IZKProofVerifier} from "./interfaces/IZKProofVerifier.sol";

contract ZKProofRegistry {
    bytes32 public constant DISCLOSURE_CONTEXT_DOMAIN = keccak256("AVA_DISCLOSURE_CONTEXT_V1");
    bytes32 public constant NULLIFIER_DOMAIN = keccak256("AVA_DISCLOSURE_NULLIFIER_V1");

    struct ProofReceipt {
        uint256 id;
        uint256 packageId;
        address verifier;
        bytes32 proofDomainHash;
        bytes32 contextHash;
        bytes32 subjectCommitment;
        bytes32 nullifierHash;
        bytes32 proofHash;
        address registeredBy;
    }

    IZKProofVerifier public immutable verifier;
    AVARulePackageRegistry public immutable rulePackageRegistry;
    DisclosurePolicyRegistry public immutable disclosureRegistry;
    uint256 public nextProofReceiptId = 1;

    mapping(uint256 => ProofReceipt) private proofReceipts;
    mapping(bytes32 => uint256) private receiptIdByContextHash;
    mapping(bytes32 => uint256) private receiptIdByNullifierHash;

    event ZKProofVerified(
        uint256 indexed id,
        bytes32 indexed contextHash,
        bytes32 indexed nullifierHash,
        uint256 packageId,
        address verifier,
        bytes32 proofDomainHash,
        bytes32 subjectCommitment,
        bytes32 proofHash,
        address registeredBy
    );

    constructor(
        IZKProofVerifier verifier_,
        AVARulePackageRegistry rulePackageRegistry_,
        DisclosurePolicyRegistry disclosureRegistry_
    ) {
        if (
            address(verifier_) == address(0) || address(rulePackageRegistry_) == address(0)
                || address(disclosureRegistry_) == address(0)
        ) {
            revert AVADataTypes.EmptyValue();
        }
        verifier = verifier_;
        rulePackageRegistry = rulePackageRegistry_;
        disclosureRegistry = disclosureRegistry_;
    }

    function registerProof(
        bytes32 workflowKey,
        AVADataTypes.AVAStage stage,
        AVADataTypes.Action action,
        bytes32 objectId,
        AVADataTypes.Role actingRole,
        uint256 disclosurePolicyId,
        bytes32 subjectCommitment,
        IZKProofVerifier.SchnorrProof calldata proof
    ) external returns (uint256 id) {
        uint256 packageId = _activePackageIdOrZero(workflowKey);
        bytes32 proofDomainHash = verifier.proofDomain();
        bytes32 contextHash =
            computeDisclosureContextHash(workflowKey, stage, action, objectId, actingRole, disclosurePolicyId, subjectCommitment);
        bytes32 nullifierHash = computeNullifierHash(contextHash, subjectCommitment);
        if (
            proofDomainHash == bytes32(0) || contextHash == bytes32(0) || nullifierHash == bytes32(0) || receiptIdByContextHash[contextHash] != 0
                || receiptIdByNullifierHash[nullifierHash] != 0
        ) {
            revert AVADataTypes.InvalidState(uint256(contextHash));
        }
        disclosureRegistry.getDisclosurePolicy(disclosurePolicyId);
        if (subjectCommitment != computeSubjectCommitment(proof.publicKey)) {
            revert AVADataTypes.InvalidState(uint256(subjectCommitment));
        }
        if (!verifier.verify(contextHash, proof)) revert AVADataTypes.InvalidState(uint256(contextHash));

        id = nextProofReceiptId++;
        bytes32 proofHash = keccak256(abi.encode(proof));
        proofReceipts[id] = ProofReceipt({
            id: id,
            packageId: packageId,
            verifier: address(verifier),
            proofDomainHash: proofDomainHash,
            contextHash: contextHash,
            subjectCommitment: subjectCommitment,
            nullifierHash: nullifierHash,
            proofHash: proofHash,
            registeredBy: msg.sender
        });
        receiptIdByContextHash[contextHash] = id;
        receiptIdByNullifierHash[nullifierHash] = id;

        emit ZKProofVerified(
            id, contextHash, nullifierHash, packageId, address(verifier), proofDomainHash, subjectCommitment, proofHash, msg.sender
        );
    }

    function computeDisclosureContextHash(
        bytes32 workflowKey,
        AVADataTypes.AVAStage stage,
        AVADataTypes.Action action,
        bytes32 objectId,
        AVADataTypes.Role actingRole,
        uint256 disclosurePolicyId,
        bytes32 subjectCommitment
    ) public view returns (bytes32) {
        uint256 packageId = _activePackageIdOrZero(workflowKey);
        return computeDisclosureContextHashForPackageAndProofDomain(
            packageId,
            verifier.proofDomain(),
            workflowKey,
            stage,
            action,
            objectId,
            actingRole,
            disclosurePolicyId,
            subjectCommitment
        );
    }

    function computeDisclosureContextHashForPackage(
        uint256 packageId,
        bytes32 workflowKey,
        AVADataTypes.AVAStage stage,
        AVADataTypes.Action action,
        bytes32 objectId,
        AVADataTypes.Role actingRole,
        uint256 disclosurePolicyId,
        bytes32 subjectCommitment
    ) public view returns (bytes32) {
        return computeDisclosureContextHashForPackageAndProofDomain(
            packageId,
            verifier.proofDomain(),
            workflowKey,
            stage,
            action,
            objectId,
            actingRole,
            disclosurePolicyId,
            subjectCommitment
        );
    }

    function computeDisclosureContextHashForPackageAndProofDomain(
        uint256 packageId,
        bytes32 proofDomainHash,
        bytes32 workflowKey,
        AVADataTypes.AVAStage stage,
        AVADataTypes.Action action,
        bytes32 objectId,
        AVADataTypes.Role actingRole,
        uint256 disclosurePolicyId,
        bytes32 subjectCommitment
    ) public pure returns (bytes32) {
        if (
            packageId == 0 || proofDomainHash == bytes32(0) || workflowKey == bytes32(0) || objectId == bytes32(0) || disclosurePolicyId == 0
                || subjectCommitment == bytes32(0)
        ) {
            return bytes32(0);
        }
        return keccak256(
            abi.encode(
                DISCLOSURE_CONTEXT_DOMAIN,
                packageId,
                proofDomainHash,
                workflowKey,
                stage,
                action,
                objectId,
                actingRole,
                disclosurePolicyId,
                subjectCommitment
            )
        );
    }

    function computeSubjectCommitment(IZKProofVerifier.G1Point calldata publicKey) public pure returns (bytes32) {
        return keccak256(abi.encode(publicKey.x, publicKey.y));
    }

    function computeNullifierHash(bytes32 contextHash, bytes32 subjectCommitment) public pure returns (bytes32) {
        if (contextHash == bytes32(0) || subjectCommitment == bytes32(0)) return bytes32(0);
        return keccak256(abi.encode(NULLIFIER_DOMAIN, contextHash, subjectCommitment));
    }

    function _activePackageIdOrZero(bytes32 workflowKey) internal view returns (uint256) {
        if (workflowKey == bytes32(0)) return 0;
        try rulePackageRegistry.getRulePackage(workflowKey) returns (AVARulePackageRegistry.RulePackage memory rulePackage) {
            return rulePackage.packageId;
        } catch {
            return 0;
        }
    }

    function hasVerifiedProof(bytes32 contextHash) external view returns (bool) {
        return receiptIdByContextHash[contextHash] != 0;
    }

    function getProofReceiptId(bytes32 contextHash) external view returns (uint256) {
        return receiptIdByContextHash[contextHash];
    }

    function getProofReceiptIdByNullifier(bytes32 nullifierHash) external view returns (uint256) {
        return receiptIdByNullifierHash[nullifierHash];
    }

    function getProofReceipt(uint256 id) external view returns (ProofReceipt memory) {
        ProofReceipt memory receipt = proofReceipts[id];
        if (receipt.id == 0) revert AVADataTypes.UnknownReference(id);
        return receipt;
    }
}
