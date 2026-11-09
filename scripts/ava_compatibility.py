#!/usr/bin/env python3
"""Compatibility guards for the canonical AVA production surface.

The tool uses only the Python standard library. It locks public ABI shape,
checks Core/App import direction, and validates machine-readable rule-package
manifests without adding any on-chain compatibility machinery.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any


ABI_SCHEMA = "ava-canonical-abi-manifest-v1"
PACKAGE_SCHEMA = "ava-rule-package-manifest-v1"
MAX_CAPABILITIES_PER_PACKAGE = 64

IMPORT_PATTERN = re.compile(
    r"\bimport\s+(?:[^;]*?\sfrom\s+)?[\"']([^\"']+)[\"']\s*;",
    re.MULTILINE,
)
HEX_PATTERN = re.compile(r"^0x[0-9a-fA-F]+$")


def _strip_solidity_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    return re.sub(r"//[^\n]*", "", text)


def _relative_path(path: Path, root: Path) -> str:
    try:
        return path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError as error:
        raise ValueError(f"path escapes project root: {path}") from error


def _resolved_import(source: Path, import_path: str, root: Path) -> Path:
    if import_path.startswith("."):
        target = source.parent / import_path
    else:
        target = root / import_path
    return target.resolve()


def source_closure(project_root: Path, surface: Path) -> set[str]:
    root = project_root.resolve()
    pending = [surface.resolve()]
    visited: set[str] = set()
    while pending:
        source = pending.pop()
        relative = _relative_path(source, root)
        if relative in visited:
            continue
        if not source.is_file():
            raise ValueError(f"missing Solidity source: {relative}")
        visited.add(relative)
        text = _strip_solidity_comments(source.read_text(encoding="utf-8"))
        for import_path in IMPORT_PATTERN.findall(text):
            pending.append(_resolved_import(source, import_path, root))
    return visited


def _canonical_type(parameter: dict[str, Any]) -> str:
    solidity_type = parameter["type"]
    if not solidity_type.startswith("tuple"):
        return solidity_type
    suffix = solidity_type[len("tuple") :]
    components = ",".join(_canonical_type(component) for component in parameter.get("components", []))
    return f"({components}){suffix}"


def _signature(entry: dict[str, Any]) -> str:
    inputs = ",".join(_canonical_type(parameter) for parameter in entry.get("inputs", []))
    return f"{entry['name']}({inputs})"


def _normalised_abi_entry(entry: dict[str, Any]) -> dict[str, Any]:
    entry_type = entry["type"]
    if entry_type == "function":
        return {
            "type": entry_type,
            "signature": _signature(entry),
            "outputs": [_canonical_type(output) for output in entry.get("outputs", [])],
            "stateMutability": entry.get("stateMutability", "nonpayable"),
        }
    if entry_type == "event":
        return {
            "type": entry_type,
            "signature": _signature(entry),
            "indexed": [bool(item.get("indexed", False)) for item in entry.get("inputs", [])],
            "anonymous": bool(entry.get("anonymous", False)),
        }
    if entry_type == "error":
        return {"type": entry_type, "signature": _signature(entry)}
    if entry_type == "constructor":
        return {
            "type": entry_type,
            "inputs": [_canonical_type(item) for item in entry.get("inputs", [])],
            "stateMutability": entry.get("stateMutability", "nonpayable"),
        }
    if entry_type in {"fallback", "receive"}:
        return {
            "type": entry_type,
            "stateMutability": entry.get("stateMutability", "nonpayable"),
        }
    raise ValueError(f"unsupported ABI entry type: {entry_type}")


def _artifact_target(artifact: dict[str, Any]) -> tuple[str, str] | None:
    metadata = artifact.get("metadata", {})
    if isinstance(metadata, str):
        metadata = json.loads(metadata)
    targets = metadata.get("settings", {}).get("compilationTarget", {})
    if len(targets) != 1:
        return None
    return next(iter(targets.items()))


def build_abi_manifest(project_root: Path, artifacts_root: Path, surface: Path) -> dict[str, Any]:
    root = project_root.resolve()
    sources = source_closure(root, surface)
    contracts: dict[str, Any] = {}
    if not artifacts_root.is_dir():
        raise ValueError(f"artifact directory does not exist: {_relative_path(artifacts_root, root)}")

    for artifact_path in sorted(artifacts_root.rglob("*.json")):
        if artifact_path.parent.name == "build-info":
            continue
        try:
            artifact = json.loads(artifact_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError):
            continue
        target = _artifact_target(artifact)
        if target is None:
            continue
        source_path, contract_name = target
        if source_path not in sources:
            continue
        abi = artifact.get("abi", [])
        if not abi:
            continue

        normalised = sorted(
            (_normalised_abi_entry(entry) for entry in abi),
            key=lambda item: json.dumps(item, sort_keys=True, separators=(",", ":")),
        )
        encoded_surface = json.dumps(normalised, sort_keys=True, separators=(",", ":")).encode()
        selectors = {
            signature: selector if selector.startswith("0x") else f"0x{selector}"
            for signature, selector in sorted(artifact.get("methodIdentifiers", {}).items())
        }
        events = [
            {"signature": _signature(entry), "indexed": [bool(item.get("indexed", False)) for item in entry.get("inputs", [])]}
            for entry in abi
            if entry["type"] == "event"
        ]
        errors = [_signature(entry) for entry in abi if entry["type"] == "error"]
        contract_key = f"{source_path}:{contract_name}"
        contracts[contract_key] = {
            "abiSurfaceHash": f"0x{hashlib.sha256(encoded_surface).hexdigest()}",
            "selectors": dict(sorted(selectors.items())),
            "events": sorted(events, key=lambda item: (item["signature"], item["indexed"])),
            "errors": sorted(errors),
        }

    if not contracts:
        raise ValueError("no canonical ABI artifacts matched the production surface")
    return {
        "schema": ABI_SCHEMA,
        "surface": _relative_path(surface, root),
        "contracts": dict(sorted(contracts.items())),
    }


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def check_json(path: Path, actual: dict[str, Any], label: str) -> None:
    if not path.is_file():
        raise ValueError(f"missing {label}: {path}")
    expected = json.loads(path.read_text(encoding="utf-8"))
    if expected == actual:
        return
    expected_contracts = set(expected.get("contracts", {}))
    actual_contracts = set(actual.get("contracts", {}))
    added = sorted(actual_contracts - expected_contracts)
    removed = sorted(expected_contracts - actual_contracts)
    changed = sorted(
        key
        for key in expected_contracts & actual_contracts
        if expected["contracts"][key] != actual["contracts"][key]
    )
    details = []
    if added:
        details.append(f"added={added}")
    if removed:
        details.append(f"removed={removed}")
    if changed:
        details.append(f"changed={changed}")
    suffix = "; ".join(details) if details else "top-level metadata changed"
    raise ValueError(f"{label} drift detected: {suffix}")


def find_import_boundary_violations(project_root: Path) -> list[str]:
    root = project_root.resolve()
    violations: list[str] = []
    for directory in (root / "src/core", root / "src/extensions"):
        if not directory.exists():
            continue
        for source in sorted(directory.rglob("*.sol")):
            text = _strip_solidity_comments(source.read_text(encoding="utf-8"))
            for import_path in IMPORT_PATTERN.findall(text):
                target = _resolved_import(source, import_path, root)
                target_relative = _relative_path(target, root)
                if target_relative.startswith("src/apps/"):
                    source_relative = _relative_path(source, root)
                    violations.append(f"{source_relative} imports application source {target_relative}")
    return violations


def _require_hex(value: Any, byte_length: int, field: str) -> str:
    if not isinstance(value, str) or len(value) != 2 + byte_length * 2 or not HEX_PATTERN.fullmatch(value):
        raise ValueError(f"{field} must be a {byte_length}-byte hex value")
    if int(value, 16) == 0:
        raise ValueError(f"{field} must be nonzero")
    return value.lower()


def validate_package_manifest(manifest: dict[str, Any]) -> None:
    if manifest.get("schema") != PACKAGE_SCHEMA:
        raise ValueError(f"schema must be {PACKAGE_SCHEMA}")
    if not isinstance(manifest.get("chainId"), int) or manifest["chainId"] <= 0:
        raise ValueError("chainId must be a positive integer")

    profile = manifest.get("profile")
    if not isinstance(profile, dict) or not isinstance(profile.get("name"), str) or not profile["name"]:
        raise ValueError("profile name is required")
    required = profile.get("requiredCapabilityKeys")
    if not isinstance(required, list) or not required:
        raise ValueError("requiredCapabilityKeys must be a nonempty list")
    required_keys = [_require_hex(key, 32, "required capability key") for key in required]
    if len(required_keys) != len(set(required_keys)):
        raise ValueError("duplicate required capability")
    if len(required_keys) > MAX_CAPABILITIES_PER_PACKAGE:
        raise ValueError("required capability profile exceeds package limit")

    packages = manifest.get("packages")
    if not isinstance(packages, list) or not packages:
        raise ValueError("packages must be a nonempty list")
    packages_by_id: dict[int, dict[str, Any]] = {}
    package_versions: set[tuple[str, str, int]] = set()
    for package in packages:
        if not isinstance(package, dict):
            raise ValueError("package entry must be an object")
        package_id = package.get("packageId")
        if not isinstance(package_id, int) or package_id <= 0:
            raise ValueError("packageId must be a positive integer")
        if package_id in packages_by_id:
            raise ValueError(f"duplicate packageId {package_id}")
        app_id = _require_hex(package.get("appId"), 32, f"package {package_id} appId")
        workflow_key = _require_hex(package.get("workflowKey"), 32, f"package {package_id} workflowKey")
        compatibility_key = _require_hex(
            package.get("compatibilityKey"), 32, f"package {package_id} compatibilityKey"
        )
        version = package.get("version")
        if not isinstance(version, int) or version <= 0:
            raise ValueError(f"package {package_id} version must be positive")
        version_key = (app_id, workflow_key, version)
        if version_key in package_versions:
            raise ValueError("duplicate application/workflow/version package")
        package_versions.add(version_key)
        for field in ("modulesHash", "modulesIdentityHash", "modulesIdentityFingerprint", "authorityId"):
            _require_hex(package.get(field), 32, f"package {package_id} {field}")
        _require_hex(package.get("registeredBy"), 20, f"package {package_id} registeredBy")
        if not isinstance(package.get("active"), bool):
            raise ValueError(f"package {package_id} active must be boolean")

        capabilities = package.get("capabilities")
        if not isinstance(capabilities, list) or not capabilities:
            raise ValueError(f"package {package_id} capabilities must be nonempty")
        if len(capabilities) > MAX_CAPABILITIES_PER_PACKAGE:
            raise ValueError(f"package {package_id} exceeds capability limit")
        capability_keys: list[str] = []
        for capability in capabilities:
            if not isinstance(capability, dict):
                raise ValueError(f"package {package_id} capability must be an object")
            key = _require_hex(capability.get("key"), 32, f"package {package_id} capability key")
            _require_hex(capability.get("module"), 20, f"package {package_id} capability module")
            _require_hex(
                capability.get("moduleIdentityHash"),
                32,
                f"package {package_id} moduleIdentityHash",
            )
            capability_keys.append(key)
        if len(capability_keys) != len(set(capability_keys)):
            raise ValueError(f"package {package_id} has duplicate capability")
        missing = sorted(set(required_keys) - set(capability_keys))
        if missing:
            raise ValueError(f"package {package_id} is missing required capabilities: {missing}")
        packages_by_id[package_id] = package

    seen_relationships: set[tuple[str, int, int]] = set()
    relationships = manifest.get("relationships", [])
    if not isinstance(relationships, list):
        raise ValueError("relationships must be a list")
    for relationship in relationships:
        if not isinstance(relationship, dict):
            raise ValueError("relationship must be an object")
        kind = relationship.get("kind")
        source_id = relationship.get("sourcePackageId")
        target_id = relationship.get("targetPackageId")
        key = (kind, source_id, target_id)
        if key in seen_relationships:
            raise ValueError("duplicate package relationship")
        seen_relationships.add(key)
        if source_id not in packages_by_id or target_id not in packages_by_id:
            raise ValueError("package relationship references unknown package")
        source = packages_by_id[source_id]
        target = packages_by_id[target_id]
        if kind == "compatible-workflows":
            if source["appId"].lower() != target["appId"].lower():
                raise ValueError("compatible workflows must use the same appId")
            if source["compatibilityKey"].lower() != target["compatibilityKey"].lower():
                raise ValueError("compatible workflows must use the same compatibilityKey")
            if source["workflowKey"].lower() == target["workflowKey"].lower():
                raise ValueError("compatible workflows must use different workflowKey values")
        elif kind == "supersession":
            if (
                source["appId"].lower() != target["appId"].lower()
                or source["workflowKey"].lower() != target["workflowKey"].lower()
                or source["compatibilityKey"].lower() != target["compatibilityKey"].lower()
                or target["version"] != source["version"] + 1
            ):
                raise ValueError("invalid supersession relationship")
        else:
            raise ValueError(f"unsupported package relationship kind: {kind}")


def _abi_command(args: argparse.Namespace) -> None:
    root = args.project_root.resolve()
    manifest = build_abi_manifest(root, (root / args.artifacts).resolve(), (root / args.surface).resolve())
    output = (root / args.output).resolve()
    if args.write:
        write_json(output, manifest)
        print(f"wrote ABI compatibility manifest: {_relative_path(output, root)}")
    else:
        check_json(output, manifest, "ABI compatibility manifest")
        print(f"ABI compatibility manifest matches: {_relative_path(output, root)}")


def _boundary_command(args: argparse.Namespace) -> None:
    violations = find_import_boundary_violations(args.project_root)
    if violations:
        raise ValueError("import boundary violations:\n" + "\n".join(f"- {item}" for item in violations))
    print("Core and extension import boundaries match the application-separation rule")


def _package_command(args: argparse.Namespace) -> None:
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    validate_package_manifest(manifest)
    print(f"rule-package manifest is structurally compatible: {args.manifest}")


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subcommands = parser.add_subparsers(dest="command", required=True)

    abi = subcommands.add_parser("abi", help="write or check the canonical ABI compatibility manifest")
    abi.add_argument("--project-root", type=Path, default=Path.cwd())
    abi.add_argument("--artifacts", default="out-canonical")
    abi.add_argument("--surface", default="src/canonical/AVAProductionSurface.sol")
    abi.add_argument("--output", default="generated/canonical-abi-manifest.json")
    mode = abi.add_mutually_exclusive_group(required=True)
    mode.add_argument("--write", action="store_true")
    mode.add_argument("--check", action="store_true")
    abi.set_defaults(handler=_abi_command)

    boundaries = subcommands.add_parser("boundaries", help="check Core/extension import direction")
    boundaries.add_argument("--project-root", type=Path, default=Path.cwd())
    boundaries.set_defaults(handler=_boundary_command)

    package = subcommands.add_parser("package", help="validate a rule-package manifest")
    package.add_argument("--manifest", type=Path, required=True)
    package.set_defaults(handler=_package_command)
    return parser


def main() -> int:
    args = _parser().parse_args()
    try:
        args.handler(args)
    except (OSError, ValueError) as error:
        print(f"compatibility check failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
