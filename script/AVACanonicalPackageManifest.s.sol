// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRuleModuleIdentity} from "../src/interfaces/IRuleModuleIdentity.sol";
import {AVACoreRulePackageRegistry} from "../src/core/AVACoreRulePackageRegistry.sol";
import {CanonicalPeerReviewFixture} from "./helpers/CanonicalPeerReviewFixture.sol";

interface AVAManifestVm {
    function toString(address value) external pure returns (string memory);

    function toString(bytes32 value) external pure returns (string memory);

    function toString(uint256 value) external pure returns (string memory);

    function writeFile(string calldata path, string calldata data) external;
}

/// @notice Generates a machine-readable manifest from the deployed canonical package records.
/// @dev Addresses describe the deterministic local script run. Package semantics are reconstructed from registry reads.
contract AVACanonicalPackageManifest is CanonicalPeerReviewFixture {
    AVAManifestVm private constant VM = AVAManifestVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct PackageManifestRecord {
        uint256 packageId;
        bytes32 appId;
        bytes32 workflowKey;
        uint64 version;
        bytes32 compatibilityKey;
        bytes32 modulesHash;
        bytes32 modulesIdentityHash;
        bytes32 modulesIdentityFingerprint;
        bytes32 authorityId;
        address registeredBy;
        bool active;
        uint256 capabilityCount;
    }

    function artifactPath() public pure returns (string memory) {
        return "generated/canonical-rule-package-manifest.json";
    }

    function run() external returns (string memory manifest) {
        _deployCanonicalPeerReview();
        manifest = _renderDeployedManifest();
        // forge-lint: disable-next-line(unsafe-cheatcode)
        VM.writeFile(artifactPath(), string.concat(manifest, "\n"));
    }

    function renderManifest() external returns (string memory manifest) {
        _deployCanonicalPeerReview();
        manifest = _renderDeployedManifest();
    }

    function manifestRecords()
        external
        returns (PackageManifestRecord memory review, PackageManifestRecord memory challenge)
    {
        _deployCanonicalPeerReview();
        review = _record(reviewPackageId);
        challenge = _record(challengePackageId);
    }

    function _record(uint256 packageId) private view returns (PackageManifestRecord memory record) {
        AVACoreRulePackageRegistry.RulePackage memory package = packageRegistry.getRulePackageById(packageId);
        record = PackageManifestRecord({
            packageId: package.packageId,
            appId: package.appId,
            workflowKey: package.workflowKey,
            version: package.version,
            compatibilityKey: package.compatibilityKey,
            modulesHash: package.modulesHash,
            modulesIdentityHash: package.modulesIdentityHash,
            modulesIdentityFingerprint: package.modulesIdentityFingerprint,
            authorityId: package.authorityId,
            registeredBy: package.registeredBy,
            active: package.active,
            capabilityCount: packageRegistry.getCapabilityKeys(packageId).length
        });
    }

    function _renderDeployedManifest() private view returns (string memory) {
        bytes32[] memory requiredCapabilities = packageRegistry.getCapabilityKeys(reviewPackageId);
        string memory prefix = string.concat(
            '{"schema":"ava-rule-package-manifest-v1","artifactKind":"deterministic-local-demo","chainId":',
            VM.toString(block.chainid),
            ',"profile":{"name":"canonical-peer-review-v1","requiredCapabilityKeys":',
            _bytes32ArrayJson(requiredCapabilities),
            '},"packages":['
        );
        string memory relationship = string.concat(
            '],"relationships":[{"kind":"compatible-workflows","sourcePackageId":',
            VM.toString(reviewPackageId),
            ',"targetPackageId":',
            VM.toString(challengePackageId),
            "}]}"
        );
        return string.concat(prefix, _packageJson(reviewPackageId), ",", _packageJson(challengePackageId), relationship);
    }

    function _packageJson(uint256 packageId) private view returns (string memory) {
        AVACoreRulePackageRegistry.RulePackage memory package = packageRegistry.getRulePackageById(packageId);
        bytes32[] memory capabilityKeys = packageRegistry.getCapabilityKeys(packageId);
        (, address[] memory modules) = packageRegistry.getVerifiedModulesCompact(packageId, capabilityKeys);
        string memory identity = string.concat(
            '{"packageId":',
            VM.toString(package.packageId),
            ',"appId":"',
            VM.toString(package.appId),
            '","workflowKey":"',
            VM.toString(package.workflowKey),
            '","version":',
            VM.toString(uint256(package.version)),
            ',"compatibilityKey":"',
            VM.toString(package.compatibilityKey),
            '","modulesHash":"',
            VM.toString(package.modulesHash),
            '"'
        );
        string memory provenance = string.concat(
            ',"modulesIdentityHash":"',
            VM.toString(package.modulesIdentityHash),
            '","modulesIdentityFingerprint":"',
            VM.toString(package.modulesIdentityFingerprint),
            '","authorityId":"',
            VM.toString(package.authorityId),
            '","registeredBy":"',
            VM.toString(package.registeredBy),
            '","active":',
            package.active ? "true" : "false",
            ',"capabilities":'
        );
        return string.concat(identity, provenance, _capabilitiesJson(capabilityKeys, modules), "}");
    }

    function _capabilitiesJson(bytes32[] memory keys, address[] memory modules)
        private
        view
        returns (string memory json)
    {
        json = "[";
        for (uint256 i; i < keys.length; ++i) {
            if (i != 0) json = string.concat(json, ",");
            json = string.concat(
                json,
                '{"key":"',
                VM.toString(keys[i]),
                '","module":"',
                VM.toString(modules[i]),
                '","moduleIdentityHash":"',
                VM.toString(IRuleModuleIdentity(modules[i]).moduleIdentityHash()),
                '"}'
            );
        }
        return string.concat(json, "]");
    }

    function _bytes32ArrayJson(bytes32[] memory values) private pure returns (string memory json) {
        json = "[";
        for (uint256 i; i < values.length; ++i) {
            if (i != 0) json = string.concat(json, ",");
            json = string.concat(json, '"', VM.toString(values[i]), '"');
        }
        return string.concat(json, "]");
    }
}
