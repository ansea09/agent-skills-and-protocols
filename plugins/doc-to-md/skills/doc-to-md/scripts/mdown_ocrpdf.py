#!/usr/bin/env python3
from __future__ import annotations

import argparse
import datetime as dt
import importlib.metadata
import json
import os
import platform
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from typing import Any


def env_int(names: tuple[str, ...], default: int) -> int:
    for name in names:
        value = os.environ.get(name)
        if value is None:
            continue
        if not value.isdigit():
            raise SystemExit(f"mdown-ocrpdf: {name} must be a non-negative integer, got {value!r}")
        return int(value)
    return default


DEFAULT_OCR_TIMEOUT_SECONDS = env_int(("DOC_TO_MD_OCR_TIMEOUT_SECONDS", "DOC_TO_MD_TIMEOUT_SECONDS"), 3600)
DEFAULT_MAX_INPUT_MB = env_int(("DOC_TO_MD_MAX_INPUT_MB",), 1024)
OCR_LOCKFILE = Path(
    os.environ.get("DOC_TO_MD_OCR_REQUIREMENTS", Path(__file__).resolve().parent.parent / "requirements-ocr.lock.txt")
)


def reject_remote(value: str) -> None:
    if "://" in value:
        raise SystemExit("mdown-ocrpdf: only trusted local PDF paths are supported")


def path_roots(env_name: str) -> list[Path]:
    value = os.environ.get(env_name, "")
    return [Path(part).expanduser().resolve() for part in value.split(os.pathsep) if part.strip()]


def enforce_roots(path: Path, env_name: str, label: str) -> None:
    roots = path_roots(env_name)
    if not roots:
        return
    resolved = path.expanduser().resolve()
    if any(resolved == root or root in resolved.parents for root in roots):
        return
    roots_text = os.pathsep.join(str(root) for root in roots)
    raise SystemExit(f"mdown-ocrpdf: {label} path is outside {env_name}: {resolved} (allowed: {roots_text})")


def resolve_ocrmypdf() -> str:
    env_bin = os.environ.get("OCRMYPDF_BIN")
    if env_bin:
        return env_bin
    script = Path(sys.executable).with_name("ocrmypdf")
    if script.exists():
        return str(script)
    found = shutil.which("ocrmypdf")
    if found:
        return found
    raise SystemExit("mdown-ocrpdf: could not find ocrmypdf in the OCR venv or PATH")


def command_version(command: str) -> dict[str, Any]:
    path = shutil.which(command)
    if not path:
        return {"command": command, "found": False}
    proc = subprocess.run([path, "--version"], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return {
        "command": command,
        "found": True,
        "path": path,
        "returncode": proc.returncode,
        "stdout": proc.stdout.strip(),
        "stderr": proc.stderr.strip(),
    }


def binary_arches(path: str) -> list[str]:
    if sys.platform != "darwin":
        return []
    proc = subprocess.run(["lipo", "-archs", path], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        return []
    return proc.stdout.strip().split()


def distribution_version(name: str) -> str | None:
    try:
        return importlib.metadata.version(name)
    except importlib.metadata.PackageNotFoundError:
        return None


def add_doctor_check(payload: dict[str, Any], level: str, message: str, **extra: Any) -> None:
    check = {"level": level, "message": message}
    check.update(extra)
    payload["checks"].append(check)


def add_hash_policy_check(payload: dict[str, Any], path: Path, label: str, text: str) -> None:
    if "--hash=" in text:
        add_doctor_check(payload, "ok", f"{label} lockfile includes pip hashes", path=str(path))
    elif path.name.endswith(".hashes.txt") or os.environ.get("DOC_TO_MD_REQUIRE_HASHES") == "1":
        add_doctor_check(payload, "warn", f"{label} hash-locked lockfile has no pip hashes", path=str(path))
    else:
        add_doctor_check(
            payload,
            "info",
            (
                f"{label} lockfile uses exact pins without hashes; this is normal for local pinned installs. "
                "Use --hash-locked for public release installs."
            ),
            path=str(path),
            install_mode="normal-pinned",
        )


def finalize_doctor_payload(payload: dict[str, Any]) -> dict[str, Any]:
    levels = {check["level"] for check in payload["checks"]}
    status = "fail" if "fail" in levels else "warn" if "warn" in levels else "ok"
    payload["status"] = status
    payload["exit_code"] = 1 if status == "fail" else 0
    return payload


def first_version(text: str) -> str | None:
    match = re.search(r"\d+(?:\.\d+)+", text)
    return match.group(0) if match else None


def version_tuple(version: str) -> tuple[int, ...]:
    parts = [int(part) for part in re.findall(r"\d+", version)]
    return tuple(parts)


def version_at_least(version: str, minimum: str) -> bool:
    left = list(version_tuple(version))
    right = list(version_tuple(minimum))
    width = max(len(left), len(right))
    left.extend([0] * (width - len(left)))
    right.extend([0] * (width - len(right)))
    return tuple(left) >= tuple(right)


def split_languages(language: str | None) -> list[str]:
    if not language:
        return []
    return [part.strip() for part in language.split("+") if part.strip()]


def sanitize_value(value: Any) -> Any:
    if isinstance(value, dict):
        return {key: sanitize_value(item) for key, item in value.items()}
    if isinstance(value, list):
        return [sanitize_value(item) for item in value]
    if isinstance(value, str):
        try:
            path = Path(value)
        except (OSError, ValueError):
            return value
        if path.is_absolute():
            return f"<redacted-path:{path.name or 'root'}>"
    return value


def sanitize_report(value: dict[str, Any]) -> dict[str, Any]:
    sanitized = sanitize_value(value)
    if isinstance(sanitized, dict):
        sanitized["sanitized_for_external_transfer"] = True
    return sanitized


def export_sanitized_report(input_report: Path, output_report: Path, force: bool) -> None:
    if not input_report.exists() or not input_report.is_file():
        raise SystemExit(f"mdown-ocrpdf: OCR report does not exist: {input_report}")
    if output_report == input_report:
        raise SystemExit("mdown-ocrpdf: refusing to write sanitized report over the source report")
    if output_report.exists() and not force:
        raise SystemExit(f"mdown-ocrpdf: sanitized report already exists, pass --force to replace it: {output_report}")
    report = json.loads(input_report.read_text(encoding="utf-8"))
    write_report(output_report, sanitize_report(report))


def check_input_size(path: Path, max_input_mb: int) -> None:
    if max_input_mb <= 0:
        return
    size_mb = path.stat().st_size / (1024 * 1024)
    if size_mb > max_input_mb:
        raise SystemExit(
            f"mdown-ocrpdf: input is {size_mb:.1f} MiB, above --max-input-mb {max_input_mb}; "
            "rerun with a higher limit or --max-input-mb 0"
        )


def process_is_running(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def lock_owner_active(lock_dir: Path) -> bool:
    try:
        pid_text = (lock_dir / "pid").read_text(encoding="utf-8").strip()
        return bool(pid_text) and process_is_running(int(pid_text))
    except (OSError, ValueError):
        return False


def acquire_output_lock(output_pdf: Path) -> Path:
    output_pdf.parent.mkdir(parents=True, exist_ok=True)
    lock_dir = output_pdf.parent / f".{output_pdf.name}.mdown-ocrpdf.lock"
    for _ in range(2):
        try:
            lock_dir.mkdir()
            (lock_dir / "pid").write_text(f"{os.getpid()}\n", encoding="utf-8")
            return lock_dir
        except FileExistsError:
            if lock_owner_active(lock_dir):
                raise SystemExit(f"mdown-ocrpdf: output is locked by another process: {lock_dir}")
            shutil.rmtree(lock_dir, ignore_errors=True)
    raise SystemExit(f"mdown-ocrpdf: could not acquire output lock: {lock_dir}")


def release_output_lock(lock_dir: Path | None) -> None:
    if lock_dir is not None:
        shutil.rmtree(lock_dir, ignore_errors=True)


def tesseract_languages() -> tuple[list[str], str]:
    path = shutil.which("tesseract")
    if not path:
        return [], ""
    proc = subprocess.run([path, "--list-langs"], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    output = "\n".join(part for part in (proc.stdout, proc.stderr) if part)
    if proc.returncode != 0:
        return [], output.strip()
    languages = [
        line.strip()
        for line in output.splitlines()
        if line.strip() and not line.lower().startswith("list of available languages")
    ]
    return languages, output.strip()


def print_python_dependency(name: str, minimum: str | None = None) -> bool:
    version = distribution_version(name)
    if not version:
        print(f"[fail] missing Python dependency: {name}")
        return False
    if minimum and not version_at_least(version, minimum):
        print(f"[fail] {name} {version}; OCRmyPDF v17 requires >= {minimum}")
        return False
    print(f"[ok] {name} {version}")
    return True


def add_python_dependency_check(payload: dict[str, Any], name: str, minimum: str | None = None) -> None:
    version = distribution_version(name)
    if not version:
        add_doctor_check(payload, "fail", f"missing Python dependency: {name}", package=name)
        return
    if minimum and not version_at_least(version, minimum):
        add_doctor_check(
            payload,
            "fail",
            f"{name} {version}; OCRmyPDF v17 requires >= {minimum}",
            package=name,
            installed=version,
            minimum=minimum,
        )
        return
    add_doctor_check(payload, "ok", f"{name} {version}", package=name, installed=version, minimum=minimum)


def check_lockfile(path: Path = OCR_LOCKFILE) -> bool:
    if not path.exists():
        print(f"[fail] OCR lockfile missing: {path}")
        return False

    text = path.read_text(encoding="utf-8")
    if "--hash=" in text:
        print("[ok] OCR lockfile includes pip hashes")
    elif path.name.endswith(".hashes.txt") or os.environ.get("DOC_TO_MD_REQUIRE_HASHES") == "1":
        print("[warn] OCR hash-locked lockfile has no pip hashes")
    else:
        print("[info] OCR lockfile uses exact pins without hashes; this is normal for local pinned installs. Use --hash-locked for public release installs.")

    mismatches: list[str] = []
    checked = 0
    for raw_line in text.splitlines():
        line = raw_line.strip().rstrip("\\").strip()
        if not line or line.startswith("#") or line.startswith("--hash=") or "==" not in line:
            continue
        name, expected = line.split("==", 1)
        expected = re.split(r"[;#\s\\]", expected, maxsplit=1)[0]
        installed = distribution_version(name)
        checked += 1
        if installed != expected:
            mismatches.append(f"{name} expected {expected}, installed {installed or 'missing'}")

    if mismatches:
        print("[fail] OCR lockfile drift:")
        for mismatch in mismatches:
            print(f"  - {mismatch}")
        return False

    print(f"[ok] OCR lockfile matches installed packages ({checked} pins)")
    return True


def add_lockfile_checks(payload: dict[str, Any], path: Path = OCR_LOCKFILE) -> None:
    if not path.exists():
        add_doctor_check(payload, "fail", f"OCR lockfile missing: {path}", path=str(path))
        return

    text = path.read_text(encoding="utf-8")
    add_hash_policy_check(payload, path, "OCR", text)

    mismatches: list[dict[str, str]] = []
    checked = 0
    for raw_line in text.splitlines():
        line = raw_line.strip().rstrip("\\").strip()
        if not line or line.startswith("#") or line.startswith("--hash=") or "==" not in line:
            continue
        name, expected = line.split("==", 1)
        expected = re.split(r"[;#\s\\]", expected, maxsplit=1)[0]
        installed = distribution_version(name)
        checked += 1
        if installed != expected:
            mismatches.append({"name": name, "expected": expected, "installed": installed or "missing"})

    if mismatches:
        add_doctor_check(payload, "fail", "OCR lockfile drift", mismatches=mismatches)
    else:
        add_doctor_check(payload, "ok", f"OCR lockfile matches installed packages ({checked} pins)", checked=checked)


def normalize_package_name(name: str) -> str:
    return re.sub(r"[-_.]+", "-", name).lower()


def online_dependency_drift() -> None:
    proc = subprocess.run(
        [
            sys.executable,
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
        print("[warn] online OCR outdated-package check failed; no drift result is available")
        if proc.stdout.strip():
            print(proc.stdout.strip())
        return

    try:
        items = json.loads(proc.stdout or "[]")
    except json.JSONDecodeError:
        print("[warn] online OCR outdated-package check returned non-JSON output:")
        print(proc.stdout.strip())
        return

    if not items:
        print("[ok] online OCR outdated-package check reported no drift")
        return

    zones = {
        "OCR engine graph": {
            "ocrmypdf",
            "pikepdf",
            "pypdfium2",
            "pdfminer-six",
            "img2pdf",
            "pi-heif",
            "pillow",
            "lxml",
            "cryptography",
        },
        "OCR rendering/report stack": {"fpdf2", "uharfbuzz", "fonttools"},
        "OCR validation/runtime stack": {
            "pydantic",
            "pydantic-core",
            "rich",
            "pluggy",
            "typing-extensions",
            "typing-inspection",
            "pip",
            "setuptools",
            "wheel",
        },
    }
    grouped: dict[str, list[dict[str, str]]] = {name: [] for name in zones}
    grouped["other OCR transitive dependencies"] = []
    for item in items:
        key = normalize_package_name(str(item.get("name", "")))
        matched = False
        for zone, names in zones.items():
            if key in names:
                grouped[zone].append(item)
                matched = True
                break
        if not matched:
            grouped["other OCR transitive dependencies"].append(item)

    print("[warn] online OCR outdated-package check reported drift:")
    for zone, zone_items in grouped.items():
        if not zone_items:
            continue
        print(f"[warn] drift zone: {zone}")
        for item in zone_items:
            print(f"  - {item.get('name', 'unknown')} {item.get('version', '?')} -> {item.get('latest_version', '?')}")

    impact_zones = [zone for zone in ("OCR engine graph", "OCR rendering/report stack") if grouped.get(zone)]
    if impact_zones:
        print("")
        print("What happened: online drift was found in high-impact OCR dependency zones: " + ", ".join(impact_zones) + ".")
        print("What it means: the installed OCR runtime still matches the local lockfile; drift is a maintainer signal, not an immediate OCR failure.")
        print("What you can do: for public maintenance, run `mdown-refresh-locks --ocr --apply`, rebuild the OCR runtime, then rerun `mdown-ocrpdf --doctor --online` and an OCR smoke test.")
        print("Consequences: refreshing OCR pins can change recognition quality, PDF rasterization, and generated OCR text layers; review sample textbook PDFs before publishing.")
    elif grouped.get("OCR validation/runtime stack"):
        print("")
        print("What happened: online drift was found only in the OCR validation/runtime stack.")
        print("What it means: the installed OCR runtime still matches the local lockfile; this is not an OCR conversion failure, and some packages may be constrained by their parent dependency.")
        print("What you can do: for ordinary use, take no action. For public maintenance, run `mdown-refresh-locks --ocr --apply`; it will refuse incompatible pins if `pip check` fails.")
        print("Consequences: ignoring validation/runtime-only drift preserves current OCR behavior until a reviewed maintenance refresh is published.")


def add_online_dependency_drift(payload: dict[str, Any]) -> None:
    proc = subprocess.run(
        [
            sys.executable,
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
        add_doctor_check(payload, "warn", "online OCR outdated-package check failed; no drift result is available", output=proc.stdout)
        return

    try:
        items = json.loads(proc.stdout or "[]")
    except json.JSONDecodeError:
        add_doctor_check(payload, "warn", "online OCR outdated-package check returned non-JSON output", output=proc.stdout)
        return

    if not items:
        add_doctor_check(payload, "ok", "online OCR outdated-package check reported no drift")
        return

    zones = {
        "OCR engine graph": {
            "ocrmypdf",
            "pikepdf",
            "pypdfium2",
            "pdfminer-six",
            "img2pdf",
            "pi-heif",
            "pillow",
            "lxml",
            "cryptography",
        },
        "OCR rendering/report stack": {"fpdf2", "uharfbuzz", "fonttools"},
        "OCR validation/runtime stack": {
            "pydantic",
            "pydantic-core",
            "rich",
            "pluggy",
            "typing-extensions",
            "typing-inspection",
            "pip",
            "setuptools",
            "wheel",
        },
    }
    grouped: dict[str, list[dict[str, str]]] = {name: [] for name in zones}
    grouped["other OCR transitive dependencies"] = []
    for item in items:
        key = normalize_package_name(str(item.get("name", "")))
        matched = False
        for zone, names in zones.items():
            if key in names:
                grouped[zone].append(item)
                matched = True
                break
        if not matched:
            grouped["other OCR transitive dependencies"].append(item)

    add_doctor_check(payload, "warn", "online OCR outdated-package check reported drift", drift_zones=grouped)
    impact_zones = [zone for zone in ("OCR engine graph", "OCR rendering/report stack") if grouped.get(zone)]
    if impact_zones:
        add_doctor_check(
            payload,
            "warn",
            "online drift was found in high-impact OCR dependency zones: " + ", ".join(impact_zones),
            what_happened="online drift was found in high-impact OCR dependency zones: " + ", ".join(impact_zones),
            what_it_means="The installed OCR runtime still matches the local lockfile; drift is a maintainer signal, not an immediate OCR failure.",
            what_you_can_do="For public maintenance, run `mdown-refresh-locks --ocr --apply`, rebuild, rerun OCR doctor, and run an OCR smoke test.",
            consequences="Refreshing OCR pins can change recognition quality, PDF rasterization, and generated OCR text layers.",
        )
    elif grouped.get("OCR validation/runtime stack"):
        add_doctor_check(
            payload,
            "warn",
            "online drift was found only in the OCR validation/runtime stack",
            what_happened="online drift was found only in the OCR validation/runtime stack",
            what_it_means="The installed OCR runtime still matches the local lockfile; this is not an OCR conversion failure.",
            what_you_can_do="For ordinary use, take no action. For public maintenance, run `mdown-refresh-locks --ocr --apply`.",
            consequences="Ignoring validation/runtime-only drift preserves current OCR behavior until a reviewed maintenance refresh is published.",
        )


def build_doctor_payload(language: str | None = "eng", output_type: str = "pdf", online: bool = False) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "schema_version": 1,
        "tool": "mdown-ocrpdf",
        "paths": {
            "python": sys.executable,
            "lockfile": str(OCR_LOCKFILE),
        },
        "checks": [],
    }

    if sys.version_info < (3, 11):
        add_doctor_check(payload, "fail", f"Python {sys.version.split()[0]}; OCRmyPDF v17 requires Python >= 3.11")
    else:
        add_doctor_check(payload, "ok", f"Python {sys.version.split()[0]}")

    try:
        ocrmypdf_bin = resolve_ocrmypdf()
        proc = subprocess.run([ocrmypdf_bin, "--version"], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        output = (proc.stdout or proc.stderr).strip()
        if proc.returncode == 0:
            add_doctor_check(payload, "ok", f"ocrmypdf {output}", binary=ocrmypdf_bin)
        else:
            add_doctor_check(payload, "fail", f"ocrmypdf returned {proc.returncode}: {output}", binary=ocrmypdf_bin)
    except SystemExit as exc:
        add_doctor_check(payload, "fail", str(exc))

    for package, minimum in (("fpdf2", "2.8"), ("uharfbuzz", None), ("pikepdf", None)):
        add_python_dependency_check(payload, package, minimum)

    add_lockfile_checks(payload)

    pypdfium2_version = distribution_version("pypdfium2")
    gs_info = command_version("gs")
    gs_version = first_version((gs_info.get("stdout") or gs_info.get("stderr") or "")) if gs_info.get("found") else None
    if pypdfium2_version:
        add_doctor_check(payload, "ok", f"pypdfium2 {pypdfium2_version} (default PDF rasterizer)", package="pypdfium2")
    elif gs_info["found"] and gs_info.get("returncode") == 0 and gs_version and version_at_least(gs_version, "9.54"):
        add_doctor_check(payload, "ok", f"Ghostscript {gs_version} (fallback PDF rasterizer)", binary=gs_info.get("path"))
    elif gs_info["found"] and gs_info.get("returncode") == 0:
        add_doctor_check(payload, "fail", f"Ghostscript {gs_version or 'unknown'}; OCRmyPDF v17 requires >= 9.54 when pypdfium2 is absent")
    else:
        add_doctor_check(payload, "fail", "missing PDF rasterizer: install Python package pypdfium2 or Ghostscript >= 9.54")

    if pypdfium2_version and not gs_info["found"]:
        add_doctor_check(payload, "warn", "Ghostscript not found; OK for default PDF output, but some PDF/A conversions may need Ghostscript")
    elif gs_info["found"] and gs_info.get("returncode") == 0:
        add_doctor_check(payload, "ok", f"Ghostscript {gs_version or 'installed'}", binary=gs_info.get("path"))
    elif gs_info["found"]:
        add_doctor_check(payload, "warn", f"Ghostscript found at {gs_info['path']} but --version returned {gs_info.get('returncode')}")

    tesseract_info = command_version("tesseract")
    if tesseract_info["found"] and tesseract_info.get("returncode") == 0:
        host_arch = platform.machine()
        arches = binary_arches(tesseract_info["path"])
        if host_arch == "arm64" and arches and "arm64" not in arches:
            add_doctor_check(payload, "fail", f"tesseract binary is not native arm64: {tesseract_info['path']} ({', '.join(arches)})")
        elif arches:
            add_doctor_check(payload, "ok", f"tesseract binary architecture: {', '.join(arches)}", binary=tesseract_info["path"])

        text = tesseract_info.get("stdout") or tesseract_info.get("stderr") or ""
        version = first_version(text)
        first_line = text.splitlines()[0] if text.splitlines() else version or "installed"
        if version and version_at_least(version, "4.1.1"):
            add_doctor_check(payload, "ok", f"tesseract: {first_line}", binary=tesseract_info["path"], version=version)
        else:
            add_doctor_check(payload, "fail", f"tesseract: {first_line}; OCRmyPDF v17 requires >= 4.1.1")
    elif tesseract_info["found"]:
        add_doctor_check(payload, "fail", f"tesseract found at {tesseract_info['path']} but --version returned {tesseract_info.get('returncode')}")
    else:
        add_doctor_check(payload, "fail", "missing external dependency: tesseract >= 4.1.1")

    requested_languages = split_languages(language)
    if requested_languages and tesseract_info.get("found"):
        installed_languages, error = tesseract_languages()
        if installed_languages:
            missing = [lang for lang in requested_languages if lang not in installed_languages]
            if missing:
                add_doctor_check(payload, "fail", f"missing Tesseract language data: {', '.join(missing)}", missing_languages=missing)
            else:
                add_doctor_check(payload, "ok", f"Tesseract language data: {'+'.join(requested_languages)}", languages=requested_languages)
        else:
            detail = f": {error.splitlines()[0]}" if error else ""
            add_doctor_check(payload, "warn", f"could not list Tesseract language data{detail}")

    if output_type.startswith("pdfa"):
        verapdf_info = command_version("verapdf")
        if gs_info["found"] and gs_info.get("returncode") == 0:
            add_doctor_check(payload, "ok", "PDF/A support: Ghostscript available")
        elif verapdf_info["found"] and verapdf_info.get("returncode") == 0:
            add_doctor_check(payload, "ok", "PDF/A support: verapdf available")
        else:
            add_doctor_check(payload, "fail", "PDF/A output needs Ghostscript or verapdf with OCRmyPDF v17")

    qpdf_info = command_version("qpdf")
    if qpdf_info["found"]:
        add_doctor_check(payload, "info", "qpdf CLI found but not required by OCRmyPDF v17; pikepdf provides qpdf integration")
    else:
        add_doctor_check(payload, "info", "qpdf CLI not found; OK for OCRmyPDF v17")

    if online:
        add_online_dependency_drift(payload)
    else:
        add_doctor_check(payload, "warn", "online OCR outdated-package check skipped; run: mdown-ocrpdf --doctor --online")

    return finalize_doctor_payload(payload)


def print_doctor_payload(payload: dict[str, Any]) -> None:
    print("mdown-ocrpdf doctor")
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
    if payload["status"] == "fail":
        print("Install the missing OCRmyPDF v17 runtime requirements before running OCR.")
        print("Minimum for default PDF output: Python >= 3.11, OCRmyPDF, Tesseract >= 4.1.1, fpdf2, uharfbuzz, and pypdfium2 or Ghostscript >= 9.54.")
        print("On macOS, OCRmyPDF's project documentation recommends Homebrew's `brew install ocrmypdf` for system dependencies.")


def doctor(language: str | None = "eng", output_type: str = "pdf", online: bool = False, json_output: bool = False) -> int:
    payload = build_doctor_payload(language, output_type, online)
    if json_output:
        print(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True))
    else:
        print_doctor_payload(payload)
    return int(payload["exit_code"])


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Add a local OCR text layer to a trusted PDF before the audit bundle workflow.")
    parser.add_argument("pdf", nargs="?", help="Trusted local PDF path")
    parser.add_argument("-o", "--output", help="Output OCR PDF path. Defaults to <input-stem>-ocr.pdf")
    parser.add_argument("-l", "--language", default=os.environ.get("OCR_LANG", "eng"), help="Tesseract language(s), e.g. eng or eng+rus")
    parser.add_argument("--force", action="store_true", help="Overwrite an existing output file")
    parser.add_argument("--redo-ocr", action="store_true", help="Redo OCR on pages that already have text")
    parser.add_argument("--force-ocr", action="store_true", help="Rasterize pages and force OCR even if text exists")
    parser.add_argument("--skip-text", action="store_true", default=True, help="Skip pages that already have text; default")
    parser.add_argument("--no-skip-text", dest="skip_text", action="store_false", help="Do not pass --skip-text")
    parser.add_argument("--deskew", action="store_true", default=True, help="Deskew pages; default")
    parser.add_argument("--no-deskew", dest="deskew", action="store_false", help="Do not pass --deskew")
    parser.add_argument("--rotate-pages", action="store_true", default=True, help="Auto-rotate pages; default")
    parser.add_argument("--no-rotate-pages", dest="rotate_pages", action="store_false", help="Do not pass --rotate-pages")
    parser.add_argument("--output-type", default="pdf", choices=["pdf", "pdfa", "pdfa-1", "pdfa-2", "pdfa-3"], help="OCRmyPDF output type")
    parser.add_argument("--jobs", type=int, help="Number of worker jobs to pass to OCRmyPDF")
    parser.add_argument("--timeout", type=int, default=DEFAULT_OCR_TIMEOUT_SECONDS, help="OCR timeout in seconds; use 0 to disable")
    parser.add_argument("--max-input-mb", type=int, default=DEFAULT_MAX_INPUT_MB, help="Maximum input PDF size in MiB; use 0 to disable")
    parser.add_argument("--report", help="JSON report path. Defaults to <output>.ocr-report.json")
    parser.add_argument("--sanitize-report", action="store_true", help="Redact local absolute paths from the OCR JSON report")
    parser.add_argument("--export-sanitized-report", metavar="REPORT_JSON", help="Copy an existing OCR JSON report with local paths redacted")
    parser.add_argument("--doctor", action="store_true", help="Check OCRmyPDF and external OCR dependencies")
    parser.add_argument("--online", action="store_true", help="During --doctor, check online dependency drift")
    parser.add_argument("--json", action="store_true", help="With --doctor, emit machine-readable output")
    return parser.parse_args(argv)


def build_command(args: argparse.Namespace, input_pdf: Path, output_pdf: Path) -> list[str]:
    command = [resolve_ocrmypdf()]
    if args.language:
        command.extend(["-l", args.language])
    if args.deskew:
        command.append("--deskew")
    if args.rotate_pages:
        command.append("--rotate-pages")
    if args.force_ocr:
        command.append("--force-ocr")
    elif args.redo_ocr:
        command.append("--redo-ocr")
    elif args.skip_text:
        command.append("--skip-text")
    if args.output_type:
        command.extend(["--output-type", args.output_type])
    if args.jobs:
        command.extend(["--jobs", str(args.jobs)])
    command.extend([str(input_pdf), str(output_pdf)])
    return command


def write_report(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path.parent, prefix=f".{path.name}.", suffix=".tmp", delete=False) as handle:
        tmp_path = Path(handle.name)
        handle.write(json.dumps(value, ensure_ascii=False, indent=2) + "\n")
    os.replace(tmp_path, path)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    if args.doctor:
        return doctor(args.language, args.output_type, args.online, args.json)
    if args.json:
        raise SystemExit("mdown-ocrpdf: --json is only supported with --doctor")
    if args.export_sanitized_report:
        reject_remote(args.export_sanitized_report)
        input_report = Path(args.export_sanitized_report).expanduser().resolve()
        output_report = (
            Path(args.report).expanduser().resolve()
            if args.report
            else input_report.with_name(f"{input_report.stem}.sanitized{input_report.suffix}")
        )
        enforce_roots(input_report, "DOC_TO_MD_INPUT_ROOTS", "input")
        enforce_roots(output_report, "DOC_TO_MD_OUTPUT_ROOTS", "output")
        export_sanitized_report(input_report, output_report, args.force)
        print(f"sanitized OCR report: {output_report}")
        return 0
    if not args.pdf:
        raise SystemExit("mdown-ocrpdf: PDF path is required unless --doctor is used")
    reject_remote(args.pdf)

    input_pdf = Path(args.pdf).expanduser().resolve()
    if not input_pdf.exists():
        raise SystemExit(f"mdown-ocrpdf: file does not exist: {input_pdf}")
    if input_pdf.suffix.lower() != ".pdf":
        raise SystemExit("mdown-ocrpdf: OCR preprocessor currently supports PDF input only")
    enforce_roots(input_pdf, "DOC_TO_MD_INPUT_ROOTS", "input")
    check_input_size(input_pdf, args.max_input_mb)

    output_pdf = Path(args.output).expanduser().resolve() if args.output else input_pdf.with_name(f"{input_pdf.stem}-ocr.pdf")
    if output_pdf == input_pdf:
        raise SystemExit("mdown-ocrpdf: refusing to write OCR output over the input PDF")
    enforce_roots(output_pdf, "DOC_TO_MD_OUTPUT_ROOTS", "output")
    output_pdf.parent.mkdir(parents=True, exist_ok=True)
    output_lock: Path | None = acquire_output_lock(output_pdf)
    staging_dir: Path | None = None
    try:
        if output_pdf.exists() and not args.force:
            raise SystemExit(f"mdown-ocrpdf: output already exists, pass --force to overwrite: {output_pdf}")

        staging_dir = Path(tempfile.mkdtemp(prefix=f".{output_pdf.name}.", suffix=".tmp", dir=output_pdf.parent))
        tmp_output_pdf = staging_dir / output_pdf.name
        command = build_command(args, input_pdf, tmp_output_pdf)
        started_at = dt.datetime.now(dt.timezone.utc).isoformat()

        try:
            proc = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=args.timeout or None)
            returncode = proc.returncode
            stdout = proc.stdout
            stderr = proc.stderr
        except subprocess.TimeoutExpired as exc:
            returncode = 124
            stdout = exc.stdout or ""
            stderr = f"OCRmyPDF timed out after {args.timeout} seconds"
        finished_at = dt.datetime.now(dt.timezone.utc).isoformat()
        report_path = Path(args.report).expanduser().resolve() if args.report else output_pdf.with_suffix(output_pdf.suffix + ".ocr-report.json")
        report = {
            "source": str(input_pdf),
            "output": str(output_pdf),
            "temporary_output": str(tmp_output_pdf),
            "started_at": started_at,
            "finished_at": finished_at,
            "command": command,
            "timeout_seconds": args.timeout,
            "returncode": returncode,
            "stdout": stdout,
            "stderr": stderr,
            "temporary_output_exists": tmp_output_pdf.exists(),
            "temporary_output_bytes": tmp_output_pdf.stat().st_size if tmp_output_pdf.exists() else 0,
            "output_exists": output_pdf.exists(),
            "output_bytes": output_pdf.stat().st_size if output_pdf.exists() else 0,
        }
        write_report(report_path, sanitize_report(report) if args.sanitize_report else report)

        if returncode != 0:
            print(f"mdown-ocrpdf: OCRmyPDF failed with exit code {returncode}", file=sys.stderr)
            print(f"report: {report_path}", file=sys.stderr)
            return returncode

        os.replace(tmp_output_pdf, output_pdf)
        report["temporary_output_exists"] = tmp_output_pdf.exists()
        report["temporary_output_bytes"] = tmp_output_pdf.stat().st_size if tmp_output_pdf.exists() else 0
        report["output_exists"] = output_pdf.exists()
        report["output_bytes"] = output_pdf.stat().st_size if output_pdf.exists() else 0
        write_report(report_path, sanitize_report(report) if args.sanitize_report else report)
    finally:
        if staging_dir is not None:
            shutil.rmtree(staging_dir, ignore_errors=True)
        release_output_lock(output_lock)

    print(f"ocr pdf: {output_pdf}")
    print(f"report: {report_path}")
    print(f"next: mdown-book {output_pdf} -o {output_pdf.with_suffix('').name}-audit-bundle")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
