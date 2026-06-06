// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IZKProofVerifier} from "./interfaces/IZKProofVerifier.sol";

contract SchnorrDisclosureProofVerifier is IZKProofVerifier {
    bytes32 public constant CHALLENGE_DOMAIN = keccak256("AVA_SCHNORR_DISCLOSURE_V1");
    uint256 public constant GROUP_ORDER =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    function verify(bytes32 contextHash, SchnorrProof calldata proof) external view returns (bool) {
        if (contextHash == bytes32(0) || proof.response >= GROUP_ORDER) return false;
        if (_isZero(proof.publicKey) || _isZero(proof.commitment)) return false;

        uint256 challenge = uint256(
            keccak256(
                abi.encodePacked(
                    CHALLENGE_DOMAIN,
                    contextHash,
                    proof.publicKey.x,
                    proof.publicKey.y,
                    proof.commitment.x,
                    proof.commitment.y
                )
            )
        ) % GROUP_ORDER;

        (G1Point memory left, bool leftOk) = _ecMul(G1Point({x: 1, y: 2}), proof.response);
        if (!leftOk) return false;

        (G1Point memory challengePublicKey, bool mulOk) = _ecMul(proof.publicKey, challenge);
        if (!mulOk) return false;

        (G1Point memory right, bool addOk) = _ecAdd(proof.commitment, challengePublicKey);
        if (!addOk) return false;

        return left.x == right.x && left.y == right.y;
    }

    function proofDomain() external pure returns (bytes32) {
        return CHALLENGE_DOMAIN;
    }

    function _ecAdd(G1Point memory a, G1Point memory b) internal view returns (G1Point memory result, bool ok) {
        uint256[4] memory input = [a.x, a.y, b.x, b.y];
        uint256[2] memory output;
        assembly {
            ok := staticcall(gas(), 6, input, 0x80, output, 0x40)
        }
        result = G1Point({x: output[0], y: output[1]});
    }

    function _ecMul(G1Point memory point, uint256 scalar) internal view returns (G1Point memory result, bool ok) {
        uint256[3] memory input = [point.x, point.y, scalar];
        uint256[2] memory output;
        assembly {
            ok := staticcall(gas(), 7, input, 0x60, output, 0x40)
        }
        result = G1Point({x: output[0], y: output[1]});
    }

    function _isZero(G1Point memory point) internal pure returns (bool) {
        return point.x == 0 && point.y == 0;
    }
}
