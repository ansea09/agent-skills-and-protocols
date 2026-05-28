#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import subprocess
from typing import Any
from urllib.request import Request, urlopen


PYPI_VERSION_URL = "https://pypi.org/pypi/{package}/{version}/json"
REVIEW_REQUIRED_LICENSE_PACKAGES = {"pymupdf"}


def normalize_name(name: str) -> str:
    return re.sub(r"[-_.]+", "-", name).lower()


def parse_label_path(value: str) -> tuple[str, Path]:
    if "=" not in value:
        raise argparse.ArgumentTypeError("expected LABEL=PATH")
    label, path = value.split("=", 1)
    if not label or not path:
        raise argparse.ArgumentTypeError("expected LABEL=PATH")
    return label, Path(path)


def parse_pins(path: Path) -> dict[str, str]:
    pins: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip().rstrip("\\").strip()
        if not line or line.startswith("#") or line.startswith("--hash="):
            continue
        match = re.match(r"([A-Za-z0-9_.-]+)==([^;#\s\\]+)", line)
        if match:
            pins[normalize_name(match.group(1))] = match.group(2)
    return pins


def fetch_json(url: str, timeout: int) -> dict[str, Any]:
    try:
        import requests

        response = requests.get(url, headers={"User-Agent": "doc-to-md-dependency-audit/1"}, timeout=timeout)
        response.raise_for_status()
        return response.json()
    except ImportError:
        pass

    request = Request(url, headers={"User-Agent": "doc-to-md-dependency-audit/1"})
    with urlopen(request, timeout=timeout) as response:  # noqa: S310 - fixed public metadata endpoint.
        return json.loads(response.read().decode("utf-8"))


def metadata_from_python(python: Path) -> dict[str, dict[str, Any]]:
    code = r"""
import importlib.metadata as metadata
import json

items = {}
for dist in metadata.distributions():
    meta = dist.metadata
    name = meta.get("Name")
    if not name:
        continue
    norm = name.replace("_", "-").replace(".", "-").lower()
    classifiers = meta.get_all("Classifier") or []
    license_classifiers = [item for item in classifiers if item.startswith("License ::")]
    items[norm] = {
        "name": name,
        "version": dist.version,
        "license_expression": meta.get("License-Expression"),
        "license": meta.get("License"),
        "license_classifiers": license_classifiers,
    }
print(json.dumps(items, sort_keys=True))
"""
    proc = subprocess.run([str(python), "-c", code], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or f"{python} metadata probe failed")
    return json.loads(proc.stdout)


def license_value(metadata: dict[str, Any], pypi_info: dict[str, Any] | None = None) -> str:
    values: list[str] = []
    for source in (metadata, pypi_info or {}):
        expression = source.get("license_expression")
        if expression:
            values.append(str(expression))
        license_text = source.get("license")
        if license_text:
            values.append(str(license_text).splitlines()[0])
        for classifier in source.get("license_classifiers") or []:
            values.append(str(classifier))
    return "; ".join(dict.fromkeys(value for value in values if value and value != "UNKNOWN"))


def has_review_license(license_text: str) -> bool:
    upper = license_text.upper()
    return "AGPL" in upper or "GPL" in upper


def audit(args: argparse.Namespace) -> dict[str, Any]:
    checks: list[dict[str, Any]] = []
    packages: list[dict[str, Any]] = []
    failed = False
    warned = False
    requirements = dict(args.requirements)
    pythons = dict(args.python)

    metadata_by_label: dict[str, dict[str, dict[str, Any]]] = {}
    for label, python in pythons.items():
        try:
            metadata_by_label[label] = metadata_from_python(python)
            checks.append({"level": "ok", "message": f"read installed package metadata for {label}", "python": str(python)})
        except Exception as exc:  # noqa: BLE001 - audit must report environment errors.
            failed = True
            checks.append({"level": "fail", "message": f"could not read installed package metadata for {label}: {exc}", "python": str(python)})
            metadata_by_label[label] = {}

    online_errors: list[str] = []
    for label, requirement_path in requirements.items():
        pins = parse_pins(requirement_path)
        installed = metadata_by_label.get(label, {})
        for normalized, expected_version in sorted(pins.items()):
            item: dict[str, Any] = {
                "profile": label,
                "package": normalized,
                "expected_version": expected_version,
                "installed_version": None,
                "license": "",
                "license_review": "ok",
                "vulnerabilities": [],
            }
            metadata = installed.get(normalized, {})
            if metadata:
                item["package"] = metadata.get("name") or normalized
                item["installed_version"] = metadata.get("version")
                if item["installed_version"] != expected_version:
                    failed = True
                    checks.append(
                        {
                            "level": "fail",
                            "message": f"{label} package {item['package']} installed version {item['installed_version']} does not match pin {expected_version}",
                        }
                    )
            else:
                failed = True
                checks.append({"level": "fail", "message": f"{label} package {normalized} is pinned but not installed in the audited runtime"})

            pypi_info: dict[str, Any] | None = None
            if args.online:
                try:
                    pypi_payload = fetch_json(PYPI_VERSION_URL.format(package=normalized, version=expected_version), args.timeout)
                    pypi_info = pypi_payload.get("info") or {}
                    vulnerabilities = pypi_payload.get("vulnerabilities") or []
                    item["vulnerabilities"] = vulnerabilities
                    if vulnerabilities:
                        failed = True
                        checks.append(
                            {
                                "level": "fail",
                                "message": f"{label} package {normalized} has {len(vulnerabilities)} vulnerability advisory item(s)",
                            }
                        )
                except Exception as exc:  # noqa: BLE001 - online advisory errors are reported by policy.
                    online_errors.append(f"{normalized}=={expected_version}: {exc}")

            license_text = license_value(metadata, pypi_info)
            item["license"] = license_text
            if not license_text:
                warned = True
                item["license_review"] = "missing"
                checks.append({"level": "warn", "message": f"{label} package {normalized} has no license metadata"})
            elif has_review_license(license_text):
                warned = True
                item["license_review"] = "review-required"
                if normalized not in REVIEW_REQUIRED_LICENSE_PACKAGES:
                    checks.append({"level": "warn", "message": f"{label} package {normalized} has review-required license metadata: {license_text}"})
                else:
                    checks.append({"level": "info", "message": f"{label} package {normalized} has documented review-required license metadata"})
            packages.append(item)

    if args.online:
        if online_errors:
            level = "fail" if args.require_online else "warn"
            failed = failed or args.require_online
            warned = warned or not args.require_online
            checks.append({"level": level, "message": "online vulnerability metadata errors", "errors": online_errors})
        else:
            checks.append({"level": "ok", "message": "online vulnerability metadata check completed"})
    else:
        warned = True
        checks.append({"level": "warn", "message": "online vulnerability audit skipped; set DOC_TO_MD_SCA_MODE=required for publication SCA"})

    status = "fail" if failed else "warn" if warned else "ok"
    return {
        "schema_version": 1,
        "tool": "doc-to-md-dependency-audit",
        "status": status,
        "exit_code": 1 if failed else 0,
        "online": args.online,
        "require_online": args.require_online,
        "checks": checks,
        "packages": packages,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Audit doc-to-md dependency licenses and vulnerability metadata.")
    parser.add_argument("--requirements", action="append", type=parse_label_path, required=True, help="Dependency file as LABEL=PATH.")
    parser.add_argument("--python", action="append", type=parse_label_path, required=True, help="Runtime Python as LABEL=PATH.")
    parser.add_argument("--online", action="store_true", help="Fetch PyPI vulnerability and license metadata.")
    parser.add_argument("--require-online", action="store_true", help="Fail if online vulnerability metadata cannot be fetched.")
    parser.add_argument("--timeout", type=int, default=20)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args(argv)

    payload = audit(args)
    text = json.dumps(payload, indent=2, sort_keys=True)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text + "\n", encoding="utf-8")
    if args.json or not args.output:
        print(text)
    return payload["exit_code"]


if __name__ == "__main__":
    raise SystemExit(main())
