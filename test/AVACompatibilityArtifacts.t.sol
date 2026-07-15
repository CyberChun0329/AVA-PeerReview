// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PeerReviewTypes} from "../src/apps/peerreview/PeerReviewTypes.sol";
import {AVACanonicalPackageManifest} from "../script/AVACanonicalPackageManifest.s.sol";

contract AVACompatibilityArtifactsTest {
    function testCanonicalPackageManifestReconstructsCompatibleWorkflowPackages() public {
        (
            AVACanonicalPackageManifest.PackageManifestRecord memory review,
            AVACanonicalPackageManifest.PackageManifestRecord memory challenge
        ) = new AVACanonicalPackageManifest().manifestRecords();
        require(review.packageId != 0 && challenge.packageId != 0, "package id missing");
        require(review.packageId != challenge.packageId, "workflow packages collapsed");
        require(review.appId == PeerReviewTypes.APP_ID && challenge.appId == PeerReviewTypes.APP_ID, "wrong app");
        require(review.workflowKey != challenge.workflowKey, "workflow key reused");
        require(review.compatibilityKey == challenge.compatibilityKey, "workflow compatibility drift");
        require(review.version == 1 && challenge.version == 1, "wrong package version");
        require(review.capabilityCount == 12 && challenge.capabilityCount == 12, "profile widened");
        require(review.modulesHash != bytes32(0) && challenge.modulesHash != bytes32(0), "modules hash missing");
        require(
            review.modulesIdentityFingerprint != bytes32(0) && challenge.modulesIdentityFingerprint != bytes32(0),
            "module identity fingerprint missing"
        );
    }

    function testCanonicalPackageManifestRendersMachineReadableSchemaAndRelationship() public {
        string memory manifest = new AVACanonicalPackageManifest().renderManifest();
        _assertContains(manifest, '"schema":"ava-rule-package-manifest-v1"');
        _assertContains(manifest, '"profile":{"name":"canonical-peer-review-v1"');
        _assertContains(manifest, '"kind":"compatible-workflows"');
        _assertContains(manifest, '"packages":[');
        _assertContains(manifest, '"capabilities":[');
    }

    function _assertContains(string memory text, string memory needle) private pure {
        bytes memory haystack = bytes(text);
        bytes memory target = bytes(needle);
        require(target.length != 0 && target.length <= haystack.length, "manifest token missing");
        for (uint256 i; i <= haystack.length - target.length; ++i) {
            bool matched = true;
            for (uint256 j; j < target.length; ++j) {
                if (haystack[i + j] != target[j]) {
                    matched = false;
                    break;
                }
            }
            if (matched) return;
        }
        revert("manifest token missing");
    }
}
