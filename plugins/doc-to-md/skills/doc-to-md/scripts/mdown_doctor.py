#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from typing import Any


CODEX_HOME = Path(os.environ.get("CODEX_HOME", str(Path.home() / ".codex"))).expanduser()
MARKITDOWN_VENV = Path(os.environ.get("MARKITDOWN_VENV", str(CODEX_HOME / "tools" / "markitdown-core-venv")))
MARKITDOWN_BIN = Path(os.environ.get("MARKITDOWN_BIN", str(MARKITDOWN_VENV / "bin" / "markitdown")))
MARKITDOWN_PYTHON = Path(os.environ.get("MARKITDOWN_PYTHON", str(MARKITDOWN_VENV / "bin" / "python")))
MARKITDOWN_REQUIREMENTS = Path(
    os.environ.get("MARKITDOWN_REQUIREMENTS", str(CODEX_HOME / "skills" / "doc-to-md" / "requirements-core.txt"))
)
MARKITDOWN_WRAPPER = Path(os.environ.get("MARKITDOWN_WRAPPER", str(Path.home() / ".local" / "bin" / "markitdown-local")))

ADVANCED_PACKAGES = [
    "azure-ai-documentintelligence",
    "azure-identity",
    "speechrecognition",
    "youtube-transcript-api",
    "pydub",
    "markitdown-ocr",
    "openai",
]


def normalize_name(name: str) -> str:
    return re.sub(r"[-_.]+", "-", name).lower()


def add_check(payload: dict[str, Any], level: str, message: str, **extra: Any) -> None:
    check = {"level": level, "message": message}
    check.update(extra)
    payload["checks"].append(check)


def add_hash_policy_check(payload: dict[str, Any], path: Path, label: str) -> None:
    text = path.read_text(encoding="utf-8")
    if "--hash=" in text:
        add_check(payload, "ok", f"{label} requirements include pip hashes", path=str(path))
    elif path.name.endswith(".hashes.txt") or os.environ.get("DOC_TO_MD_REQUIRE_HASHES") == "1":
        add_check(payload, "warn", f"{label} hash-locked requirements file has no pip hashes", path=str(path))
    else:
        add_check(
            payload,
            "info",
            (
                f"{label} requirements use exact pins without hashes; this is normal for local pinned installs. "
                "Use --hash-locked for public release installs."
            ),
            path=str(path),
            install_mode="normal-pinned",
        )


def command_available(name: str) -> bool:
    return shutil.which(name) is not None


def run(command: list[str], **kwargs: Any) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, **kwargs)


def read_requirement_pins(path: Path) -> list[tuple[str, str]]:
    pins: list[tuple[str, str]] = []
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip().rstrip("\\").strip()
        if not line or line.startswith("#") or line.startswith("--hash="):
            continue
        match = re.match(r"([A-Za-z0-9_.-]+)==([^;#\s\\]+)", line)
        if not match:
            raise ValueError(f"unsupported requirements line for drift check: {line}")
        pins.append(match.groups())
    return pins


def installed_versions(python: Path, names: list[str]) -> dict[str, str | None]:
    code = r"""
import importlib.metadata
import json
import sys

result = {}
for name in sys.argv[1:]:
    try:
        result[name] = importlib.metadata.version(name)
    except importlib.metadata.PackageNotFoundError:
        result[name] = None
print(json.dumps(result, sort_keys=True))
"""
    proc = run([str(python), "-c", code, *names])
    if proc.returncode != 0:
        raise RuntimeError((proc.stderr or proc.stdout or "").strip())
    return json.loads(proc.stdout)


def expected_markitdown_version() -> str | None:
    try:
        for name, version in read_requirement_pins(MARKITDOWN_REQUIREMENTS):
            if normalize_name(name) == "markitdown":
                return version
    except (OSError, ValueError):
        return None
    return None


def check_packages(payload: dict[str, Any]) -> None:
    if not MARKITDOWN_PYTHON.exists() or not os.access(MARKITDOWN_PYTHON, os.X_OK):
        return
    try:
        pins = read_requirement_pins(MARKITDOWN_REQUIREMENTS)
        versions = installed_versions(MARKITDOWN_PYTHON, [name for name, _ in pins] + ADVANCED_PACKAGES)
    except Exception as exc:  # noqa: BLE001 - report actionable doctor failure.
        add_check(payload, "fail", f"could not check core requirements: {exc}")
        return

    mismatches: list[dict[str, str]] = []
    for name, expected in pins:
        installed = versions.get(name)
        if installed == expected:
            add_check(payload, "ok", f"package {name}=={expected}", package=name, expected=expected, installed=installed)
        else:
            mismatches.append({"name": name, "expected": expected, "installed": installed or "missing"})

    for name in ADVANCED_PACKAGES:
        installed = versions.get(name)
        if installed:
            add_check(payload, "warn", f"advanced package installed in core venv: {name}=={installed}", package=name)

    if mismatches:
        add_check(payload, "fail", "core requirements drift", mismatches=mismatches)
    else:
        add_check(payload, "ok", f"core requirements match installed packages ({len(pins)} pins)")


def check_offline_selftest(payload: dict[str, Any]) -> None:
    if not MARKITDOWN_WRAPPER.exists() or not os.access(MARKITDOWN_WRAPPER, os.X_OK):
        return

    with tempfile.TemporaryDirectory(prefix="mdown-doctor.") as tmp_name:
        tmp = Path(tmp_name)
        sample = tmp / "sample.html"
        output = tmp / "sample.md"
        sample.write_text(
            "<!doctype html><html><body><h1>MarkItDown Doctor</h1>"
            "<table><tr><th>Status</th></tr><tr><td>ok</td></tr></table></body></html>\n",
            encoding="utf-8",
        )
        proc = run([str(MARKITDOWN_WRAPPER), str(sample), "-o", str(output)])
        if proc.returncode == 0 and output.is_file() and "MarkItDown Doctor" in output.read_text(
            encoding="utf-8", errors="replace"
        ):
            add_check(payload, "ok", "offline HTML self-test produced Markdown")
        else:
            add_check(
                payload,
                "fail",
                "offline HTML self-test failed",
                returncode=proc.returncode,
                stderr=proc.stderr.splitlines()[:20],
            )


def check_output_file(payload: dict[str, Any], path: str) -> None:
    output = Path(path)
    if not output.is_file():
        add_check(payload, "fail", f"output file does not exist: {path}", path=path)
        return
    data = output.read_bytes()
    lines = data.count(b"\n")
    if not data:
        add_check(payload, "fail", f"output file is empty: {path}", path=path, bytes=0, lines=lines)
        return
    add_check(payload, "ok", f"output file has {len(data)} bytes and {lines} lines", path=path, bytes=len(data), lines=lines)
    if len(data) < 32:
        add_check(payload, "warn", "output file is very small; inspect manually", path=path, bytes=len(data))


def online_dependency_drift(payload: dict[str, Any]) -> None:
    if not MARKITDOWN_PYTHON.exists() or not os.access(MARKITDOWN_PYTHON, os.X_OK):
        add_check(payload, "fail", "cannot run online check without venv python")
        return

    proc = subprocess.run(
        [
            str(MARKITDOWN_PYTHON),
            "-m",
            "pip",
            "list",
            "--outdated",
            "--format=json",
            "--timeout",
            "5",
            "--retries",
            "1",
        ],
        env={**os.environ, "PIP_DISABLE_PIP_VERSION_CHECK": "1"},
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    if proc.returncode != 0:
        add_check(payload, "warn", "online outdated-package check failed; no drift result is available", output=proc.stdout)
        return

    try:
        items = json.loads(proc.stdout or "[]")
    except json.JSONDecodeError:
        add_check(payload, "warn", "online outdated-package check returned non-JSON output", output=proc.stdout)
        return

    if not items:
        add_check(payload, "ok", "online outdated-package check reported no drift")
        return

    zones = {
        "PDF extraction stack": {
            "pdfminer-six",
            "pdfplumber",
            "pypdfium2",
            "pillow",
            "cryptography",
            "cffi",
            "pycparser",
        },
        "file-type detection stack": {
            "magika",
            "onnxruntime",
            "numpy",
            "protobuf",
            "flatbuffers",
        },
        "Office/text extraction stack": {
            "beautifulsoup4",
            "lxml",
            "mammoth",
            "markdownify",
            "openpyxl",
            "pandas",
            "python-pptx",
            "xlrd",
            "xlsxwriter",
        },
        "MarkItDown core package": {"markitdown"},
        "runtime tooling": {"pip", "setuptools", "wheel"},
    }
    grouped: dict[str, list[dict[str, str]]] = {name: [] for name in zones}
    grouped["other transitive dependencies"] = []
    for item in items:
        key = normalize_name(str(item.get("name", "")))
        matched = False
        for zone, names in zones.items():
            if key in names:
                grouped[zone].append(item)
                matched = True
                break
        if not matched:
            grouped["other transitive dependencies"].append(item)

    add_check(payload, "warn", "online outdated-package check reported drift", drift_zones=grouped)
    important_zones = [zone for zone in ("PDF extraction stack", "file-type detection stack", "MarkItDown core package") if grouped.get(zone)]
    constrained_magika = any(normalize_name(str(item.get("name", ""))) == "magika" for item in grouped.get("file-type detection stack", []))
    if important_zones:
        message = "online drift was found in high-impact core conversion zones: " + ", ".join(important_zones)
        add_check(
            payload,
            "warn",
            message,
            what_happened=message,
            what_it_means=(
                "The installed runtime still matches local pins. "
                "MarkItDown constrains magika to ~=0.6.1, so magika 1.x must not be adopted alone."
                if constrained_magika
                else "The installed runtime still matches local pins; drift is a maintainer signal."
            ),
            what_you_can_do=(
                "For public maintenance, run targeted lock refreshes. For MarkItDown upgrades, use "
                "`mdown-refresh-locks --core-markitdown --markitdown-spec 'markitdown==VERSION' --apply`."
            ),
            consequences=(
                "Refreshing pins can change PDF text extraction, file-type detection, OCR preprocessing, and Markdown output."
            ),
        )


def build_payload(args: argparse.Namespace) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "schema_version": 1,
        "tool": "mdown-doctor",
        "paths": {
            "venv": str(MARKITDOWN_VENV),
            "binary": str(MARKITDOWN_BIN),
            "python": str(MARKITDOWN_PYTHON),
            "wrapper": str(MARKITDOWN_WRAPPER),
            "requirements": str(MARKITDOWN_REQUIREMENTS),
        },
        "checks": [],
    }

    if command_available("perl"):
        add_check(payload, "ok", "perl available for wrapper timeout guard")
    else:
        add_check(payload, "fail", "perl not found; wrapper timeout guard cannot run")

    if command_available("python3"):
        add_check(payload, "ok", "python3 available for wrapper path checks")
    else:
        add_check(payload, "fail", "python3 not found; wrapper path checks cannot run")

    if MARKITDOWN_PYTHON.exists() and os.access(MARKITDOWN_PYTHON, os.X_OK):
        proc = run([str(MARKITDOWN_PYTHON), "--version"])
        add_check(payload, "ok", (proc.stdout or proc.stderr).strip())
    else:
        add_check(payload, "fail", f"python is not executable: {MARKITDOWN_PYTHON}")

    if MARKITDOWN_BIN.exists() and os.access(MARKITDOWN_BIN, os.X_OK):
        proc = run([str(MARKITDOWN_BIN), "--version"])
        version_output = (proc.stdout or proc.stderr).strip()
        expected = expected_markitdown_version()
        if proc.returncode == 0 and (expected is None or f"markitdown {expected}" in version_output):
            add_check(payload, "ok", version_output, expected=expected)
        elif proc.returncode == 0:
            add_check(payload, "warn", f"unexpected MarkItDown version output: {version_output}", expected=expected)
        else:
            add_check(payload, "fail", f"markitdown returned {proc.returncode}: {version_output}", expected=expected)
    else:
        add_check(payload, "fail", f"markitdown binary is not executable: {MARKITDOWN_BIN}")

    if MARKITDOWN_WRAPPER.exists() and os.access(MARKITDOWN_WRAPPER, os.X_OK):
        add_check(payload, "ok", "wrapper is executable")
    else:
        add_check(payload, "fail", f"wrapper is not executable: {MARKITDOWN_WRAPPER}")

    if MARKITDOWN_REQUIREMENTS.is_file():
        add_check(payload, "ok", "requirements file exists")
        add_hash_policy_check(payload, MARKITDOWN_REQUIREMENTS, "core")
    else:
        add_check(payload, "fail", f"requirements file missing: {MARKITDOWN_REQUIREMENTS}")

    check_packages(payload)

    if command_available("ffmpeg") or command_available("avconv"):
        add_check(payload, "ok", "ffmpeg/avconv available")
    else:
        add_check(payload, "warn", "ffmpeg/avconv not found; audio is excluded from core and will not be reliable")

    check_offline_selftest(payload)

    if args.output:
        check_output_file(payload, args.output)

    if args.online:
        online_dependency_drift(payload)
    else:
        add_check(payload, "warn", "online outdated-package check skipped; run: mdown-doctor --online")

    levels = {check["level"] for check in payload["checks"]}
    status = "fail" if "fail" in levels else "warn" if "warn" in levels else "ok"
    payload["status"] = status
    payload["exit_code"] = 1 if status == "fail" else 0
    return payload


def print_text(payload: dict[str, Any]) -> None:
    print("MarkItDown core doctor")
    for label in ("venv", "binary", "wrapper", "requirements"):
        print(f"{label}: {payload['paths'][label]}")
    for check in payload["checks"]:
        print(f"[{check['level']}] {check['message']}")
        if check.get("mismatches"):
            for item in check["mismatches"]:
                print(f"  - {item['name']} expected {item['expected']}, installed {item['installed']}")
        if check.get("drift_zones"):
            for zone, items in check["drift_zones"].items():
                if not items:
                    continue
                print(f"[warn] drift zone: {zone}")
                for item in items:
                    print(f"  - {item.get('name', 'unknown')} {item.get('version', '?')} -> {item.get('latest_version', '?')}")
        if check.get("what_happened"):
            print("")
            print(f"What happened: {check['what_happened']}.")
            print(f"What it means: {check['what_it_means']}")
            print(f"What you can do: {check['what_you_can_do']}")
            print(f"Consequences: {check['consequences']}")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Check the local MarkItDown core runtime and wrapper.")
    parser.add_argument("--output", help="Optional Markdown output file to inspect")
    parser.add_argument("--online", action="store_true", help="Check online outdated-package drift")
    parser.add_argument("--json", action="store_true", help="Emit machine-readable doctor output")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    payload = build_payload(args)
    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True))
    else:
        print_text(payload)
    return int(payload["exit_code"])


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
