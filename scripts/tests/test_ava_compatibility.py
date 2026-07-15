import copy
import json
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "scripts"))

import ava_compatibility as compatibility  # noqa: E402


ZERO_BYTES32 = "0x" + "00" * 32
NONZERO_BYTES32 = "0x" + "11" * 32
SECOND_BYTES32 = "0x" + "22" * 32
NONZERO_ADDRESS = "0x" + "33" * 20


class ABIManifestTests(unittest.TestCase):
    def test_manifest_locks_selectors_events_errors_and_full_abi_shape(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            surface = root / "src/canonical/Surface.sol"
            source = root / "src/core/Example.sol"
            artifact = root / "out/Example.sol/Example.json"
            surface.parent.mkdir(parents=True)
            source.parent.mkdir(parents=True)
            artifact.parent.mkdir(parents=True)
            surface.write_text('import "../core/Example.sol";\n', encoding="utf-8")
            source.write_text("contract Example {}\n", encoding="utf-8")
            artifact.write_text(
                json.dumps(
                    {
                        "abi": [
                            {
                                "type": "constructor",
                                "inputs": [{"name": "owner", "type": "address"}],
                                "stateMutability": "nonpayable",
                            },
                            {
                                "type": "function",
                                "name": "read",
                                "inputs": [{"name": "id", "type": "uint256"}],
                                "outputs": [{"name": "value", "type": "bytes32"}],
                                "stateMutability": "view",
                            },
                            {
                                "type": "event",
                                "name": "Recorded",
                                "inputs": [
                                    {"name": "id", "type": "uint256", "indexed": True},
                                    {"name": "value", "type": "bytes32", "indexed": False},
                                ],
                                "anonymous": False,
                            },
                            {
                                "type": "error",
                                "name": "UnknownReference",
                                "inputs": [{"name": "id", "type": "uint256"}],
                            },
                        ],
                        "methodIdentifiers": {"read(uint256)": "0x01020304"},
                        "metadata": {
                            "settings": {
                                "compilationTarget": {"src/core/Example.sol": "Example"}
                            }
                        },
                    }
                ),
                encoding="utf-8",
            )

            manifest = compatibility.build_abi_manifest(root, root / "out", surface)
            contract = manifest["contracts"]["src/core/Example.sol:Example"]
            self.assertEqual(contract["selectors"], {"read(uint256)": "0x01020304"})
            self.assertEqual(
                contract["events"],
                [{"signature": "Recorded(uint256,bytes32)", "indexed": [True, False]}],
            )
            self.assertEqual(contract["errors"], ["UnknownReference(uint256)"])

            changed_artifact = json.loads(artifact.read_text(encoding="utf-8"))
            changed_artifact["abi"][1]["outputs"][0]["type"] = "uint256"
            artifact.write_text(json.dumps(changed_artifact), encoding="utf-8")
            changed = compatibility.build_abi_manifest(root, root / "out", surface)
            self.assertNotEqual(
                contract["abiSurfaceHash"],
                changed["contracts"]["src/core/Example.sol:Example"]["abiSurfaceHash"],
            )
            baseline = root / "generated/abi.json"
            compatibility.write_json(baseline, manifest)
            with self.assertRaisesRegex(ValueError, "ABI compatibility manifest drift"):
                compatibility.check_json(baseline, changed, "ABI compatibility manifest")


class ImportBoundaryTests(unittest.TestCase):
    def test_core_and_extensions_cannot_import_application_sources(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "src/core").mkdir(parents=True)
            (root / "src/extensions").mkdir(parents=True)
            (root / "src/apps/example").mkdir(parents=True)
            (root / "src/apps/example/Example.sol").write_text(
                "contract Example {}\n", encoding="utf-8"
            )
            (root / "src/core/Bad.sol").write_text(
                'import "../apps/example/Example.sol";\n', encoding="utf-8"
            )
            (root / "src/extensions/Good.sol").write_text(
                'import "../core/Bad.sol";\n', encoding="utf-8"
            )

            violations = compatibility.find_import_boundary_violations(root)
            self.assertEqual(len(violations), 1)
            self.assertIn("src/core/Bad.sol", violations[0])
            self.assertIn("src/apps/example/Example.sol", violations[0])


class PackageManifestTests(unittest.TestCase):
    def _valid_manifest(self):
        required = [NONZERO_BYTES32, SECOND_BYTES32]
        package_one = {
            "packageId": 1,
            "appId": NONZERO_BYTES32,
            "workflowKey": "0x" + "44" * 32,
            "version": 1,
            "compatibilityKey": "0x" + "55" * 32,
            "modulesHash": "0x" + "66" * 32,
            "modulesIdentityHash": "0x" + "77" * 32,
            "modulesIdentityFingerprint": "0x" + "88" * 32,
            "authorityId": "0x" + "99" * 32,
            "registeredBy": NONZERO_ADDRESS,
            "active": True,
            "capabilities": [
                {
                    "key": key,
                    "module": NONZERO_ADDRESS,
                    "moduleIdentityHash": "0x" + f"{index + 10:02x}" * 32,
                }
                for index, key in enumerate(required)
            ],
        }
        package_two = copy.deepcopy(package_one)
        package_two["packageId"] = 2
        package_two["workflowKey"] = "0x" + "aa" * 32
        return {
            "schema": "ava-rule-package-manifest-v1",
            "artifactKind": "deterministic-local-demo",
            "chainId": 31337,
            "profile": {
                "name": "ava-executable-core-v1",
                "requiredCapabilityKeys": required,
            },
            "packages": [package_one, package_two],
            "relationships": [
                {
                    "kind": "compatible-workflows",
                    "sourcePackageId": 1,
                    "targetPackageId": 2,
                }
            ],
        }

    def test_valid_manifest_passes_compatibility_checks(self):
        compatibility.validate_package_manifest(self._valid_manifest())

    def test_duplicate_capability_is_rejected(self):
        manifest = self._valid_manifest()
        manifest["packages"][0]["capabilities"].append(
            copy.deepcopy(manifest["packages"][0]["capabilities"][0])
        )
        with self.assertRaisesRegex(ValueError, "duplicate capability"):
            compatibility.validate_package_manifest(manifest)

    def test_missing_required_capability_is_rejected(self):
        manifest = self._valid_manifest()
        manifest["packages"][0]["capabilities"].pop()
        with self.assertRaisesRegex(ValueError, "required capabilities"):
            compatibility.validate_package_manifest(manifest)

    def test_compatible_workflow_relationship_requires_same_app_and_compatibility_key(self):
        manifest = self._valid_manifest()
        manifest["packages"][1]["compatibilityKey"] = ZERO_BYTES32
        with self.assertRaisesRegex(ValueError, "compatibilityKey"):
            compatibility.validate_package_manifest(manifest)


if __name__ == "__main__":
    unittest.main()
