#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


SCRIPT_DIR = Path(__file__).resolve().parent
SKILL_DIR = SCRIPT_DIR.parent

CORE_REQUIREMENTS = SKILL_DIR / "requirements-core.txt"
OCR_REQUIREMENTS = SKILL_DIR / "requirements-ocr.txt"
OCR_LOCK = SKILL_DIR / "requirements-ocr.lock.txt"
BOOK_REQUIREMENTS = SKILL_DIR / "requirements-book.txt"

HASH_PROFILE_DOWNLOAD_TARGETS = {
    "macos-arm64-py313": {
        "platform": "macosx_11_0_arm64",
        "python_version": "3.13",
        "implementation": "cp",
        "abi": "cp313",
    },
    "macos-intel-py313": {
        "platform": "macosx_11_0_x86_64",
        "python_version": "3.13",
        "implementation": "cp",
        "abi": "cp313",
    },
    "macos-intel-py312": {
        "platform": "macosx_11_0_x86_64",
        "python_version": "3.12",
        "implementation": "cp",
        "abi": "cp312",
    },
}

CORE_ZONES = {
    "pdf": ["pdfminer.six", "pdfplumber", "pypdfium2", "pillow"],
    "filetype": ["onnxruntime", "numpy", "protobuf", "flatbuffers"],
}

CORE_SKIP_FREEZE = {"pip", "setuptools", "wheel"}

CORE_CONSTRAINED_PACKAGES = {
    "magika": "MarkItDown currently constrains magika to the 0.6 line; do not refresh magika to 1.x until MarkItDown changes its dependency constraint.",
}


def normalize_name(name: str) -> str:
    return re.sub(r"[-_.]+", "-", name).lower()


def run(command: list[str], *, cwd: Path | None = None, env: dict[str, str] | None = None) -> str:
    proc = subprocess.run(
        command,
        cwd=cwd,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    if proc.returncode != 0:
        print(proc.stdout, end="")
        raise SystemExit(f"refresh-locks: command failed with {proc.returncode}: {' '.join(command)}")
    return proc.stdout


def create_venv(root: Path, python: str, name: str) -> Path:
    venv = root / name
    run([python, "-m", "venv", str(venv)])
    return venv


def venv_python(venv: Path) -> str:
    return str(venv / "bin" / "python")


def pip(venv: Path, *args: str) -> str:
    return run([venv_python(venv), "-m", "pip", *args])


def pip_check(venv: Path) -> None:
    proc = subprocess.run(
        [venv_python(venv), "-m", "pip", "check"],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    if proc.returncode != 0:
        print(proc.stdout, end="")
        raise SystemExit("refresh-locks: pip check failed after refresh; refusing to write incompatible pins")


def freeze(venv: Path, *, include_pip: bool) -> list[tuple[str, str]]:
    args = ["freeze", "--all"] if include_pip else ["freeze"]
    output = pip(venv, *args)
    pins: dict[str, tuple[str, str]] = {}
    for raw_line in output.splitlines():
        line = raw_line.strip()
        if not line or "==" not in line or line.startswith("#"):
            continue
        name, version = line.split("==", 1)
        version = re.split(r"[;#\s\\]", version, maxsplit=1)[0]
        key = normalize_name(name)
        if not include_pip and key in CORE_SKIP_FREEZE:
            continue
        pins[key] = (name, version)
    return [pins[key] for key in sorted(pins)]


def read_pins(path: Path) -> dict[str, str]:
    pins: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip().rstrip("\\").strip()
        if not line or line.startswith("#") or line.startswith("--hash=") or "==" not in line:
            continue
        name, version = line.split("==", 1)
        pins[normalize_name(name)] = re.split(r"[;#\s\\]", version, maxsplit=1)[0]
    return pins


def read_ordered_pins(path: Path) -> list[tuple[str, str]]:
    pins: list[tuple[str, str]] = []
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip().rstrip("\\").strip()
        if not line or line.startswith("#") or line.startswith("--hash=") or "==" not in line:
            continue
        name, version = line.split("==", 1)
        version = re.split(r"[;#\s\\]", version, maxsplit=1)[0]
        pins.append((name, version))
    return pins


def read_existing_hashes(path: Path) -> dict[tuple[str, str], list[str]]:
    if not path.exists():
        return {}
    hashes: dict[tuple[str, str], list[str]] = {}
    current: tuple[str, str] | None = None
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if "==" in line and not line.startswith("--hash="):
            requirement = line.rstrip("\\").strip()
            name, version = requirement.split("==", 1)
            version = re.split(r"[;#\s\\]", version, maxsplit=1)[0]
            current = (normalize_name(name), version)
            hashes.setdefault(current, [])
            continue
        if current and line.startswith("--hash=sha256:"):
            hashes.setdefault(current, []).append(line.removeprefix("--hash=sha256:").strip())
    return {key: value for key, value in hashes.items() if value}


def write_core_requirements(path: Path, pins: list[tuple[str, str]]) -> None:
    header = """# Pinned runtime for the local MarkItDown core profile.
# Rebuild with:
#   python3 -m venv "$HOME/.codex/tools/markitdown-core-venv"
#   "$HOME/.codex/tools/markitdown-core-venv/bin/python" -m pip install -r "$HOME/.codex/skills/doc-to-md/requirements-core.txt"
#
# Scope: local PDF/DOCX/PPTX/XLS/XLSX plus base text/HTML/CSV/JSON/XML/ZIP support.
# Excluded by design: Azure, YouTube, audio transcription, plugins/OCR LLM clients.
# Refreshed by scripts/refresh-locks.py; review conversion output before publishing.
"""
    body = "".join(f"{name}=={version}\n" for name, version in pins)
    path.write_text(header + body, encoding="utf-8")


def write_ocr_lock(path: Path, pins: list[tuple[str, str]]) -> None:
    header = """# Locked OCR runtime for doc-to-md.
# Generated from scripts/refresh-locks.py using the top-level OCR declaration.
# Review mdown-ocrpdf --doctor and an OCR smoke test before publishing.
"""
    body = "".join(f"{name}=={version}\n" for name, version in pins)
    path.write_text(header + body, encoding="utf-8")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def hash_profile_download_args(profile: str) -> list[str]:
    target = HASH_PROFILE_DOWNLOAD_TARGETS.get(profile)
    if target is None:
        supported = ", ".join(sorted(HASH_PROFILE_DOWNLOAD_TARGETS))
        raise SystemExit(
            f"refresh-locks: unsupported hash profile {profile!r}; "
            f"supported profiles: {supported}"
        )
    return [
        "--platform",
        target["platform"],
        "--python-version",
        target["python_version"],
        "--implementation",
        target["implementation"],
        "--abi",
        target["abi"],
    ]


def write_hash_file(component: str, profile: str, pins: list[tuple[str, str]], python: str) -> Path:
    output = SKILL_DIR / f"requirements-{component}.{profile}.hashes.txt"
    existing_hashes = read_existing_hashes(output)
    header_map = {
        "core": "Hash-locked core runtime",
        "book": "Hash-locked optional book audit runtime",
        "ocr": "Hash-locked optional OCR runtime",
    }
    lines = [
        f"# {header_map[component]} for {profile}.",
        "# Generated from exact pinned requirements and downloaded wheel artifacts.",
        "# Scope: platform-specific. Do not use this file as a universal cross-platform lock.",
        "# Install with: python -m pip install --require-hashes -r <this-file>",
        "",
    ]

    with tempfile.TemporaryDirectory(prefix=f"doc-to-md-{component}-hashes.") as tmp_name:
        tmp = Path(tmp_name)
        for name, version in pins:
            reused_hashes = existing_hashes.get((normalize_name(name), version), [])
            if reused_hashes:
                lines.append(f"{name}=={version} \\")
                for index, digest in enumerate(reused_hashes):
                    suffix = " \\" if index < len(reused_hashes) - 1 else ""
                    lines.append(f"    --hash=sha256:{digest}{suffix}")
                continue

            package_dir = tmp / normalize_name(name)
            package_dir.mkdir()
            run(
                [
                    python,
                    "-m",
                    "pip",
                    "download",
                    "--disable-pip-version-check",
                    "--only-binary=:all:",
                    "--no-deps",
                    "--dest",
                    str(package_dir),
                    *hash_profile_download_args(profile),
                    f"{name}=={version}",
                ]
            )
            files = [item for item in package_dir.iterdir() if item.is_file()]
            if len(files) != 1:
                found = ", ".join(item.name for item in files) or "none"
                raise SystemExit(f"refresh-locks: expected one artifact for {name}=={version}, found {found}")
            lines.append(f"{name}=={version} \\")
            lines.append(f"    --hash=sha256:{sha256(files[0])}")

    output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return output


def print_changes(label: str, before: dict[str, str], after_pins: list[tuple[str, str]]) -> None:
    after = {normalize_name(name): version for name, version in after_pins}
    changes = []
    for key in sorted(set(before) | set(after)):
        old = before.get(key)
        new = after.get(key)
        if old != new:
            changes.append((key, old or "new", new or "removed"))
    if not changes:
        print(f"[ok] {label}: no pin changes")
        return
    print(f"[notice] {label}: pin changes")
    for name, old, new in changes:
        print(f"  - {name}: {old} -> {new}")


def refresh_core(args: argparse.Namespace, tmp: Path) -> list[tuple[str, str]]:
    zones: list[str] = []
    if args.core_pdf:
        zones.append("pdf")
    if args.core_filetype:
        zones.append("filetype")
    if not zones and not args.core_markitdown:
        return []

    targets: list[str] = []
    for zone in zones:
        targets.extend(CORE_ZONES[zone])

    if args.core_markitdown:
        print("[notice] not refreshing magika as a standalone target; MarkItDown dependency metadata controls the supported magika range")
    elif args.core_filetype:
        for name, reason in CORE_CONSTRAINED_PACKAGES.items():
            print(f"[notice] not refreshing constrained core package {name}: {reason}")

    venv = create_venv(tmp, args.python, "core-venv")
    pip(venv, "install", "--disable-pip-version-check", "--upgrade", "pip")
    pip(venv, "install", "--disable-pip-version-check", "-r", str(CORE_REQUIREMENTS))
    if args.core_markitdown:
        print(f"[notice] refreshing MarkItDown core package with spec: {args.markitdown_spec}")
        pip(
            venv,
            "install",
            "--disable-pip-version-check",
            "--upgrade",
            "--upgrade-strategy",
            "eager",
            args.markitdown_spec,
        )
    if targets:
        pip(venv, "install", "--disable-pip-version-check", "--upgrade", *targets)
    pip_check(venv)
    pins = freeze(venv, include_pip=False)

    if not args.skip_selftest:
        wrapper = tmp / "markitdown-local"
        wrapper.write_text(
            "#!/usr/bin/env bash\n"
            f"MARKITDOWN_VENV={str(venv)!r} "
            f"MARKITDOWN_BIN={str(venv / 'bin' / 'markitdown')!r} "
            f"MARKITDOWN_REQUIREMENTS={str(CORE_REQUIREMENTS)!r} "
            f"exec {str(SCRIPT_DIR / 'markitdown-local')!r} \"$@\"\n",
            encoding="utf-8",
        )
        wrapper.chmod(0o755)
        env = os.environ.copy()
        env["MDOWN_BIN"] = str(wrapper)
        run([venv_python(venv), str(SCRIPT_DIR / "selftest_doc_to_md.py")], env=env)

    before = read_pins(CORE_REQUIREMENTS)
    print_changes("core pdf/filetype refresh", before, pins)
    if args.apply:
        write_core_requirements(CORE_REQUIREMENTS, pins)
        if args.hashes:
            path = write_hash_file("core", args.hash_profile, pins, args.python)
            print(f"[ok] wrote {path}")
        print(f"[ok] wrote {CORE_REQUIREMENTS}")
    return pins


def refresh_ocr(args: argparse.Namespace, tmp: Path) -> list[tuple[str, str]]:
    if not args.ocr:
        return []

    venv = create_venv(tmp, args.python, "ocr-venv")
    pip(venv, "install", "--disable-pip-version-check", "--upgrade", "pip")
    top_level = [line.strip() for line in OCR_REQUIREMENTS.read_text(encoding="utf-8").splitlines() if line.strip() and not line.startswith("#")]
    if not top_level:
        raise SystemExit(f"refresh-locks: no OCR top-level requirements found in {OCR_REQUIREMENTS}")
    upgrade_specs = []
    for spec in top_level:
        name = re.split(r"[<=>!~\s]", spec, maxsplit=1)[0]
        if normalize_name(name) == "ocrmypdf":
            upgrade_specs.append("ocrmypdf>=17,<18")
        else:
            upgrade_specs.append(spec)
    pip(venv, "install", "--disable-pip-version-check", "--upgrade", *upgrade_specs)
    pip_check(venv)
    pins = freeze(venv, include_pip=True)

    before = read_pins(OCR_LOCK)
    print_changes("OCR dependency graph refresh", before, pins)
    if args.apply:
        write_ocr_lock(OCR_LOCK, pins)
        if args.hashes:
            path = write_hash_file("ocr", args.hash_profile, pins, args.python)
            print(f"[ok] wrote {path}")
        print(f"[ok] wrote {OCR_LOCK}")
    return pins


def selected_hash_only_components(args: argparse.Namespace) -> list[tuple[str, Path]]:
    specific = args.core_pdf or args.core_filetype or args.core_markitdown or args.ocr or args.book_hash
    include_all = args.all or not specific
    components: list[tuple[str, Path]] = []
    if include_all or args.core_pdf or args.core_filetype or args.core_markitdown:
        components.append(("core", CORE_REQUIREMENTS))
    if include_all or args.book_hash:
        components.append(("book", BOOK_REQUIREMENTS))
    if include_all or args.ocr:
        components.append(("ocr", OCR_LOCK))
    return components


def write_hash_only(args: argparse.Namespace) -> None:
    if not args.hashes:
        raise SystemExit("refresh-locks: --hash-only conflicts with --no-hashes")
    components = selected_hash_only_components(args)
    if not args.apply:
        print("[notice] dry run: pass --apply to write hash files")
        for component, requirements in components:
            print(f"[notice] would generate {component} hashes from {requirements} for {args.hash_profile}")
        return
    for component, requirements in components:
        profile_requirements = SKILL_DIR / f"requirements-{component}.{args.hash_profile}.txt"
        if profile_requirements.is_file():
            requirements = profile_requirements
        pins = read_ordered_pins(requirements)
        if not pins:
            raise SystemExit(f"refresh-locks: no pins found in {requirements}")
        path = write_hash_file(component, args.hash_profile, pins, args.python)
        print(f"[ok] wrote {path}")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Refresh doc-to-md dependency pins for high-drift maintenance zones."
    )
    parser.add_argument("--core-pdf", action="store_true", help="Refresh the core PDF extraction stack")
    parser.add_argument("--core-filetype", action="store_true", help="Refresh the core file-type detection stack")
    parser.add_argument("--core-markitdown", action="store_true", help="Explicitly refresh MarkItDown and compatible core transitive dependencies")
    parser.add_argument("--markitdown-spec", default=os.environ.get("DOC_TO_MD_MARKITDOWN_SPEC", "markitdown"), help="Package spec for --core-markitdown, e.g. markitdown==0.2.0")
    parser.add_argument("--ocr", action="store_true", help="Refresh the OCRmyPDF v17 dependency graph")
    parser.add_argument("--book-hash", action="store_true", help="Generate the optional book runtime hash file from current pins")
    parser.add_argument("--hash-only", action="store_true", help="Generate hash files from current pins without refreshing dependency versions")
    parser.add_argument("--all", action="store_true", help="Refresh core PDF, core file-type, and OCR zones")
    parser.add_argument("--apply", action="store_true", help="Write refreshed requirement and hash files")
    parser.add_argument("--no-hashes", dest="hashes", action="store_false", help="Do not regenerate hash files")
    parser.add_argument("--hash-profile", default=os.environ.get("DOC_TO_MD_HASH_PROFILE", "macos-arm64-py313"))
    parser.add_argument("--python", default=os.environ.get("PYTHON", "python3"))
    parser.add_argument("--skip-selftest", action="store_true", help="Skip the core conversion selftest")
    parser.add_argument("--keep-temp", action="store_true", help="Keep temporary venvs for inspection")
    parser.set_defaults(hashes=True)
    args = parser.parse_args(argv)
    if args.all:
        args.core_pdf = True
        args.core_filetype = True
        args.ocr = True
        args.book_hash = True
    if not args.hash_only and not (args.core_pdf or args.core_filetype or args.core_markitdown or args.ocr):
        args.core_pdf = True
        args.core_filetype = True
        args.ocr = True
    if not shutil.which(args.python):
        raise SystemExit(f"refresh-locks: Python not found: {args.python}")
    return args


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    if args.hash_only:
        write_hash_only(args)
        return 0
    if not args.apply:
        print("[notice] dry run: pass --apply to write refreshed requirement files")
    tmp_obj = tempfile.TemporaryDirectory(prefix="doc-to-md-refresh-locks.")
    tmp = Path(tmp_obj.name)
    try:
        refresh_core(args, tmp)
        refresh_ocr(args, tmp)
        if args.keep_temp:
            print(f"[notice] keeping temporary directory: {tmp}")
            tmp_obj = None  # type: ignore[assignment]
        if not args.apply:
            print("[notice] no files were changed")
        else:
            print("[ok] lock refresh complete; rebuild runtimes and run doctors before publishing")
        return 0
    finally:
        if tmp_obj is not None:
            tmp_obj.cleanup()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
