// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IZKProofVerifier {
    struct G1Point {
        uint256 x;
        uint256 y;
    }

    struct SchnorrProof {
        G1Point publicKey;
        G1Point commitment;
        uint256 response;
    }

    /// @notice Verifies a proof against a substrate-built context hash.
    /// @dev Returning true does not reveal identity, grant authority, validate
    /// evidence truth, or write a proof receipt.
    function verify(bytes32 contextHash, SchnorrProof calldata proof) external view returns (bool);

    /// @notice Stable verifier proof-domain identifier used in substrate
    /// context hashes and proof receipts.
    /// @dev This is verifier metadata only; it is not a reveal, authority, or
    /// truth claim.
    function proofDomain() external view returns (bytes32);
}
