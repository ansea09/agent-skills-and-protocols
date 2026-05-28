#!/usr/bin/env python3
from __future__ import annotations

import argparse
import datetime as dt
import importlib.metadata
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from typing import Any
import uuid


def env_int(names: tuple[str, ...], default: int) -> int:
    for name in names:
        value = os.environ.get(name)
        if value is None:
            continue
        if not value.isdigit():
            raise SystemExit(f"mdown-book: {name} must be a non-negative integer, got {value!r}")
        return int(value)
    return default


CODEX_HOME = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex")).expanduser()
LOW_TEXT_CHARS = 64
PRIMARY_MARKDOWN = "content.md"
AUDIT_MARKDOWN = "audit.md"
ASSETS_DIR = "assets"
MANIFEST_FILE = "manifest.json"
REPORT_FILE = "conversion-report.md"
GENERATED_NAMES = (PRIMARY_MARKDOWN, AUDIT_MARKDOWN, ASSETS_DIR, MANIFEST_FILE, REPORT_FILE)
LEGACY_GENERATED_NAMES = ("book.md",)
CLEANABLE_NAMES = GENERATED_NAMES + LEGACY_GENERATED_NAMES
DEFAULT_MARKITDOWN_TIMEOUT_SECONDS = env_int(("DOC_TO_MD_MARKITDOWN_TIMEOUT_SECONDS", "DOC_TO_MD_TIMEOUT_SECONDS"), 600)
DEFAULT_MAX_INPUT_MB = env_int(("DOC_TO_MD_MAX_INPUT_MB",), 1024)
BOOK_REQUIREMENTS = Path(
    os.environ.get("DOC_TO_MD_BOOK_REQUIREMENTS", CODEX_HOME / "skills" / "doc-to-md" / "requirements-book.txt")
)


def load_pymupdf():
    try:
        import pymupdf

        return pymupdf
    except ImportError as exc:
        raise SystemExit(
            "mdown-book: PyMuPDF is not installed in the audit bundle venv.\n"
            "Rebuild with: "
            "python3 -m venv ~/.codex/tools/doc-to-md-book-venv && "
            "~/.codex/tools/doc-to-md-book-venv/bin/python -m pip install -r "
            "~/.codex/skills/doc-to-md/requirements-book.txt"
        ) from exc


def resolve_mdown() -> str:
    env_bin = os.environ.get("MDOWN_BIN")
    if env_bin:
        return env_bin

    preferred = [
        Path.home() / ".local" / "bin" / "mdown",
        Path.home() / ".local" / "bin" / "markitdown-local",
    ]
    for candidate in preferred:
        if candidate.exists() and os.access(candidate, os.X_OK):
            return str(candidate)

    found = shutil.which("mdown")
    if found:
        return found
    fallback = Path.home() / ".local" / "bin" / "mdown"
    if fallback.exists():
        return str(fallback)
    raise SystemExit("mdown-book: could not find the mdown/markitdown-local wrapper")


def reject_remote(value: str) -> None:
    if "://" in value:
        raise SystemExit("mdown-book: only trusted local PDF paths are supported")


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
    raise SystemExit(f"mdown-book: {label} path is outside {env_name}: {resolved} (allowed: {roots_text})")


def path_exists(path: Path) -> bool:
    return path.exists() or path.is_symlink()


def remove_path(path: Path) -> None:
    if not path_exists(path):
        return
    if path.is_dir() and not path.is_symlink():
        shutil.rmtree(path)
    else:
        path.unlink()


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


def acquire_output_lock(output_dir: Path) -> Path:
    output_dir.parent.mkdir(parents=True, exist_ok=True)
    lock_dir = output_dir.parent / f".{output_dir.name}.mdown-book.lock"
    for _ in range(2):
        try:
            lock_dir.mkdir()
            (lock_dir / "pid").write_text(f"{os.getpid()}\n", encoding="utf-8")
            return lock_dir
        except FileExistsError:
            if lock_owner_active(lock_dir):
                raise SystemExit(f"mdown-book: output is locked by another process: {lock_dir}")
            remove_path(lock_dir)
    raise SystemExit(f"mdown-book: could not acquire output lock: {lock_dir}")


def release_output_lock(lock_dir: Path | None) -> None:
    if lock_dir is not None:
        remove_path(lock_dir)


def check_input_size(path: Path, max_input_mb: int) -> None:
    if max_input_mb <= 0:
        return
    size_mb = path.stat().st_size / (1024 * 1024)
    if size_mb > max_input_mb:
        raise SystemExit(
            f"mdown-book: input is {size_mb:.1f} MiB, above --max-input-mb {max_input_mb}; "
            "rerun with a higher limit or --max-input-mb 0"
        )


def existing_generated_artifacts(output_dir: Path) -> list[Path]:
    if not output_dir.exists():
        return []
    return [output_dir / name for name in CLEANABLE_NAMES if path_exists(output_dir / name)]


def prepare_output_dir(output_dir: Path, force: bool) -> None:
    if output_dir.exists() and not output_dir.is_dir():
        raise SystemExit(f"mdown-book: output path exists and is not a directory: {output_dir}")

    existing = existing_generated_artifacts(output_dir)
    if existing and not force:
        names = ", ".join(str(path.relative_to(output_dir)) for path in existing)
        raise SystemExit(f"mdown-book: generated output already exists ({names}); pass --force to replace it")


def make_staging_dir(output_dir: Path) -> Path:
    output_dir.parent.mkdir(parents=True, exist_ok=True)
    return Path(tempfile.mkdtemp(prefix=f".{output_dir.name}.", suffix=".tmp", dir=str(output_dir.parent)))


def publish_staged_output(staging_dir: Path, output_dir: Path) -> None:
    if not output_dir.exists():
        os.replace(staging_dir, output_dir)
        return

    output_dir.mkdir(parents=True, exist_ok=True)
    token = uuid.uuid4().hex[:12]
    backups: list[tuple[Path, Path]] = []
    moved: list[Path] = []

    try:
        for name in CLEANABLE_NAMES:
            target = output_dir / name
            if path_exists(target):
                backup = output_dir / f".{name}.mdown-book-backup-{token}"
                os.replace(target, backup)
                backups.append((target, backup))

        for name in GENERATED_NAMES:
            source = staging_dir / name
            if path_exists(source):
                target = output_dir / name
                os.replace(source, target)
                moved.append(target)

        remove_path(staging_dir)
        for _, backup in backups:
            remove_path(backup)
    except Exception:
        for target in reversed(moved):
            remove_path(target)
        for target, backup in reversed(backups):
            if path_exists(backup):
                if path_exists(target):
                    remove_path(target)
                os.replace(backup, target)
        raise


def rect_to_list(rect: Any) -> list[float] | None:
    if rect is None:
        return None
    try:
        return [round(float(rect.x0), 2), round(float(rect.y0), 2), round(float(rect.x1), 2), round(float(rect.y1), 2)]
    except AttributeError:
        try:
            return [round(float(x), 2) for x in rect]
        except TypeError:
            return None


def run_markitdown(pdf_path: Path, content_md: Path, timeout: int) -> dict[str, Any]:
    mdown_bin = resolve_mdown()
    cmd = [mdown_bin, str(pdf_path), "-o", str(content_md)]
    try:
        proc = subprocess.run(cmd, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout or None)
    except subprocess.TimeoutExpired as exc:
        return {
            "command": cmd,
            "returncode": 124,
            "stdout": exc.stdout or "",
            "stderr": f"MarkItDown timed out after {timeout} seconds",
            "timeout_seconds": timeout,
        }
    return {
        "command": cmd,
        "returncode": proc.returncode,
        "stdout": proc.stdout,
        "stderr": proc.stderr,
        "timeout_seconds": timeout,
    }


def extract_pdf(pdf_path: Path, output_dir: Path, profile: str) -> dict[str, Any]:
    pymupdf = load_pymupdf()
    assets_dir = output_dir / ASSETS_DIR
    if profile == "assets":
        assets_dir.mkdir(parents=True, exist_ok=True)

    doc = pymupdf.open(str(pdf_path))
    pages: list[dict[str, Any]] = []
    image_count = 0
    link_count = 0
    warnings: list[str] = []

    for page_index in range(len(doc)):
        page = doc[page_index]
        text = page.get_text("text") or ""
        page_record: dict[str, Any] = {
            "page": page_index + 1,
            "text_chars": len(text.strip()),
            "images": [],
            "links": [],
        }

        if len(text.strip()) < LOW_TEXT_CHARS:
            page_record["warning"] = "low extractable text; OCR may be required"

        for link in page.get_links():
            link_record = {
                "kind": link.get("kind"),
                "from": rect_to_list(link.get("from")),
                "uri": link.get("uri"),
                "page": link.get("page"),
                "xref": link.get("xref"),
            }
            page_record["links"].append(link_record)
            link_count += 1

        if profile == "assets":
            for image_index, image in enumerate(page.get_images(full=True), start=1):
                xref = image[0]
                try:
                    extracted = doc.extract_image(xref)
                    data = extracted.get("image")
                    ext = extracted.get("ext") or "bin"
                    if not data:
                        raise ValueError("empty image data")
                    filename = f"p{page_index + 1:04d}-img{image_index:02d}.{ext}"
                    target = assets_dir / filename
                    target.write_bytes(data)
                    image_record = {
                        "xref": xref,
                        "file": f"assets/{filename}",
                        "ext": ext,
                        "width": extracted.get("width"),
                        "height": extracted.get("height"),
                        "colorspace": extracted.get("colorspace"),
                    }
                    page_record["images"].append(image_record)
                    image_count += 1
                except Exception as exc:  # noqa: BLE001 - record and continue extraction.
                    page_record["images"].append({"xref": xref, "error": str(exc)})
                    warnings.append(f"page {page_index + 1}: failed to extract image xref {xref}: {exc}")

        pages.append(page_record)

    low_text_pages = [page["page"] for page in pages if page.get("text_chars", 0) < LOW_TEXT_CHARS]
    if low_text_pages:
        warnings.append(f"{len(low_text_pages)} pages have low extractable text")

    metadata = dict(doc.metadata or {})
    toc = [{"level": item[0], "title": item[1], "page": item[2]} for item in doc.get_toc(simple=True)]
    doc.close()

    return {
        "page_count": len(pages),
        "image_count": image_count,
        "link_count": link_count,
        "low_text_pages": low_text_pages,
        "metadata": metadata,
        "toc": toc,
        "pages": pages,
        "warnings": warnings,
    }


def write_audit_markdown(audit_md: Path, manifest: dict[str, Any]) -> None:
    lines: list[str] = []
    lines.append("# PDF Audit Bundle Page And Asset Index")
    lines.append("")
    lines.append("This audit appendix is generated by `mdown-book` to preserve PDF page traceability.")
    lines.append("It is not inline image or link placement.")
    lines.append("")

    for page in manifest["pdf"]["pages"]:
        page_no = page["page"]
        lines.append(f"<!-- page: {page_no} -->")
        lines.append(f"### Page {page_no}")
        lines.append("")
        lines.append(f"Text characters detected in PDF layer: {page.get('text_chars', 0)}")
        if page.get("warning"):
            lines.append("")
            lines.append(f"Warning: {page['warning']}.")
        if page.get("images"):
            lines.append("")
            lines.append("Images:")
            lines.append("")
            for image in page["images"]:
                if "file" in image:
                    alt = f"page {page_no} image {image.get('xref')}"
                    lines.append(f"![{alt}]({image['file']})")
                else:
                    lines.append(f"- image xref {image.get('xref')}: {image.get('error', 'not extracted')}")
        if page.get("links"):
            lines.append("")
            lines.append("Links:")
            for link in page["links"]:
                if link.get("uri"):
                    lines.append(f"- {link['uri']}")
                elif link.get("page") is not None:
                    lines.append(f"- internal page target: {link['page'] + 1}")
                else:
                    lines.append(f"- link annotation xref {link.get('xref')}")
        lines.append("")

    with audit_md.open("w", encoding="utf-8") as handle:
        handle.write("\n".join(lines))


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


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


def sanitize_manifest(manifest: dict[str, Any]) -> dict[str, Any]:
    sanitized = sanitize_value(manifest)
    if isinstance(sanitized, dict):
        sanitized["sanitized_for_external_transfer"] = True
    return sanitized


def export_sanitized_bundle(source_dir: Path, output_dir: Path, force: bool) -> None:
    if not source_dir.exists() or not source_dir.is_dir():
        raise SystemExit(f"mdown-book: audit bundle does not exist: {source_dir}")
    if not (source_dir / MANIFEST_FILE).is_file():
        raise SystemExit(f"mdown-book: audit bundle manifest is missing: {source_dir / MANIFEST_FILE}")
    if output_dir == source_dir or source_dir in output_dir.parents:
        raise SystemExit("mdown-book: refusing to export sanitized bundle into the source bundle")
    if path_exists(output_dir) and not force:
        raise SystemExit(f"mdown-book: export output already exists, pass --force to replace it: {output_dir}")

    staging_dir = make_staging_dir(output_dir)
    copied_bundle = staging_dir / output_dir.name
    try:
        shutil.copytree(
            source_dir,
            copied_bundle,
            ignore=shutil.ignore_patterns(
                ".*.tmp",
                "*.mdown-book-backup-*",
                "*.mdown-ocrpdf.lock",
                "*.mdown-book.lock",
            ),
        )
        manifest_path = copied_bundle / MANIFEST_FILE
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        sanitized = sanitize_manifest(manifest)
        write_json(manifest_path, sanitized)
        write_report(copied_bundle / REPORT_FILE, sanitized)

        if path_exists(output_dir):
            remove_path(output_dir)
        os.replace(copied_bundle, output_dir)
        remove_path(staging_dir)
    except Exception:
        if staging_dir.exists():
            remove_path(staging_dir)
        raise


def expected_requirements(path: Path) -> dict[str, str]:
    pins: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip().rstrip("\\").strip()
        if not line or line.startswith("#") or line.startswith("--hash="):
            continue
        match = re.match(r"([A-Za-z0-9_.-]+)==([^;#\s\\]+)", line)
        if not match:
            raise ValueError(f"unsupported requirements line: {line}")
        name, expected = match.groups()
        pins[name] = expected
    return pins


def installed_version(name: str) -> str | None:
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
        add_doctor_check(payload, "ok", f"{label} requirements include pip hashes", path=str(path))
    elif path.name.endswith(".hashes.txt") or os.environ.get("DOC_TO_MD_REQUIRE_HASHES") == "1":
        add_doctor_check(payload, "warn", f"{label} hash-locked requirements file has no pip hashes", path=str(path))
    else:
        add_doctor_check(
            payload,
            "info",
            (
                f"{label} requirements use exact pins without hashes; this is normal for local pinned installs. "
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


def write_report(path: Path, manifest: dict[str, Any]) -> None:
    pdf = manifest["pdf"]
    mid = manifest["markitdown"]
    lines = [
        "# Conversion Report",
        "",
        f"Source: `{manifest['source']}`",
        f"Generated at: `{manifest['generated_at']}`",
        f"Profile: `{manifest['profile']}`",
        "",
        "## Summary",
        "",
        f"- Pages: {pdf['page_count']}",
        f"- Extracted images: {pdf['image_count']}",
        f"- PDF links found: {pdf['link_count']}",
        f"- Low-text pages: {len(pdf['low_text_pages'])}",
        f"- MarkItDown return code: {mid['returncode']}",
        "",
        "## Warnings",
        "",
    ]
    warnings = list(pdf.get("warnings", []))
    if mid.get("stderr"):
        warnings.append("MarkItDown wrote stderr; inspect manifest.json for details")
    if not warnings:
        lines.append("- None from automated checks.")
    else:
        lines.extend(f"- {warning}" for warning in warnings)

    files = ["- `content.md`"]
    if manifest["outputs"].get("audit_markdown"):
        files.append("- `audit.md`")
    files.extend(["- `assets/`", "- `manifest.json`", "- `conversion-report.md`"])
    lines.extend(
        [
            "",
            "## OCR Boundary",
            "",
            "No OCR or vision model was run by this workflow. Low-text pages, formulas,",
            "scanned pages, image-only diagrams, and captions require explicit OCR or",
            "manual review.",
            "",
            "## Files",
            "",
            *files,
            "",
        ]
    )
    path.write_text("\n".join(lines), encoding="utf-8")


def build_doctor_payload() -> dict[str, Any]:
    payload: dict[str, Any] = {
        "schema_version": 1,
        "tool": "mdown-book",
        "paths": {
            "requirements": str(BOOK_REQUIREMENTS),
        },
        "checks": [],
    }
    try:
        pymupdf = load_pymupdf()
        pymupdf_version = pymupdf.version[0] if hasattr(pymupdf, "version") else installed_version("PyMuPDF")
        add_doctor_check(payload, "ok", f"PyMuPDF {pymupdf_version or 'installed'}", package="PyMuPDF", installed=pymupdf_version)
    except SystemExit as exc:
        add_doctor_check(payload, "fail", str(exc))
        return finalize_doctor_payload(payload)

    try:
        requirements_text = BOOK_REQUIREMENTS.read_text(encoding="utf-8")
        add_hash_policy_check(payload, BOOK_REQUIREMENTS, "book", requirements_text)
        pins = expected_requirements(BOOK_REQUIREMENTS)
        mismatches = []
        for name, expected in pins.items():
            installed = installed_version(name)
            if installed == expected:
                add_doctor_check(payload, "ok", f"package {name}=={expected}", package=name, expected=expected, installed=installed)
            else:
                mismatches.append({"name": name, "expected": expected, "installed": installed or "missing"})
        if mismatches:
            add_doctor_check(payload, "fail", "book requirements drift", mismatches=mismatches)
        else:
            add_doctor_check(payload, "ok", f"book requirements match installed packages ({len(pins)} pins)")
    except (OSError, ValueError) as exc:
        add_doctor_check(payload, "fail", f"could not check book requirements: {exc}")

    try:
        mdown_bin = resolve_mdown()
        result = subprocess.run([mdown_bin, "--version"], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        output = (result.stdout or result.stderr).strip()
        if result.returncode == 0:
            add_doctor_check(payload, "ok", output, binary=mdown_bin)
        else:
            add_doctor_check(payload, "fail", f"mdown returned {result.returncode}: {output}", binary=mdown_bin)
    except SystemExit as exc:
        add_doctor_check(payload, "fail", str(exc))
    return finalize_doctor_payload(payload)


def print_doctor_payload(payload: dict[str, Any]) -> None:
    print("mdown-book doctor")
    for check in payload["checks"]:
        print(f"[{check['level']}] {check['message']}")
        if check.get("mismatches"):
            for item in check["mismatches"]:
                print(f"  - {item['name']} expected {item['expected']}, installed {item['installed']}")


def doctor(json_output: bool = False) -> int:
    payload = build_doctor_payload()
    if json_output:
        print(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True))
    else:
        print_doctor_payload(payload)
    return int(payload["exit_code"])


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Create a source-tethered PDF audit bundle from a local textbook-like PDF.")
    parser.add_argument("pdf", nargs="?", help="Trusted local PDF path")
    parser.add_argument("-o", "--output-dir", help="Output directory. Defaults to <pdf-stem>-audit-bundle")
    parser.add_argument("--profile", choices=["basic", "assets"], default="assets", help="Audit bundle profile")
    parser.add_argument("--force", action="store_true", help="Replace existing generated artifacts; preserve unrelated files")
    parser.add_argument("--timeout", type=int, default=DEFAULT_MARKITDOWN_TIMEOUT_SECONDS, help="MarkItDown timeout in seconds; use 0 to disable")
    parser.add_argument("--max-input-mb", type=int, default=DEFAULT_MAX_INPUT_MB, help="Maximum input PDF size in MiB; use 0 to disable")
    parser.add_argument("--sanitize-report", action="store_true", help="Redact local absolute paths from manifest.json and conversion-report.md")
    parser.add_argument("--export-sanitized", metavar="BUNDLE_DIR", help="Copy an existing audit bundle and redact local paths in reports")
    parser.add_argument("--no-audit-md", action="store_true", help="Do not write audit.md")
    parser.add_argument("--no-asset-index", dest="no_audit_md", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--doctor", action="store_true", help="Check audit bundle dependencies")
    parser.add_argument("--json", action="store_true", help="With --doctor, emit machine-readable output")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    if args.doctor:
        return doctor(args.json)
    if args.json:
        raise SystemExit("mdown-book: --json is only supported with --doctor")
    if args.export_sanitized:
        reject_remote(args.export_sanitized)
        source_dir = Path(args.export_sanitized).expanduser().resolve()
        enforce_roots(source_dir, "DOC_TO_MD_INPUT_ROOTS", "input")
        output_dir = (
            Path(args.output_dir).expanduser().resolve()
            if args.output_dir
            else source_dir.with_name(f"{source_dir.name}-sanitized")
        )
        enforce_roots(output_dir, "DOC_TO_MD_OUTPUT_ROOTS", "output")
        export_sanitized_bundle(source_dir, output_dir, args.force)
        print(f"sanitized audit bundle: {output_dir}")
        print(f"sanitized manifest: {output_dir / MANIFEST_FILE}")
        print(f"sanitized report: {output_dir / REPORT_FILE}")
        return 0
    if not args.pdf:
        raise SystemExit("mdown-book: PDF path is required unless --doctor is used")

    reject_remote(args.pdf)
    pdf_path = Path(args.pdf).expanduser().resolve()
    if not pdf_path.exists():
        raise SystemExit(f"mdown-book: file does not exist: {pdf_path}")
    if pdf_path.suffix.lower() != ".pdf":
        raise SystemExit("mdown-book: audit bundle currently supports PDF input only")
    enforce_roots(pdf_path, "DOC_TO_MD_INPUT_ROOTS", "input")
    check_input_size(pdf_path, args.max_input_mb)

    output_dir = Path(args.output_dir).expanduser().resolve() if args.output_dir else pdf_path.with_name(f"{pdf_path.stem}-audit-bundle")
    enforce_roots(output_dir, "DOC_TO_MD_OUTPUT_ROOTS", "output")
    output_lock: Path | None = acquire_output_lock(output_dir)
    staging_dir: Path | None = None

    try:
        prepare_output_dir(output_dir, args.force)
        staging_dir = make_staging_dir(output_dir)
        content_md = staging_dir / PRIMARY_MARKDOWN

        mid = run_markitdown(pdf_path, content_md, args.timeout)
        if mid["returncode"] != 0:
            stderr = (mid.get("stderr") or "").strip()
            detail = f": {stderr.splitlines()[0]}" if stderr else ""
            raise SystemExit(f"mdown-book: MarkItDown failed with exit code {mid['returncode']}{detail}")

        pdf = extract_pdf(pdf_path, staging_dir, args.profile)
        manifest = {
            "source": str(pdf_path),
            "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(),
            "profile": args.profile,
            "outputs": {
                "markdown": PRIMARY_MARKDOWN,
                "audit_markdown": AUDIT_MARKDOWN if not args.no_audit_md else None,
                "assets_dir": ASSETS_DIR,
                "manifest": MANIFEST_FILE,
                "report": REPORT_FILE,
            },
            "markitdown": mid,
            "pdf": pdf,
        }
        if not args.no_audit_md:
            write_audit_markdown(staging_dir / AUDIT_MARKDOWN, manifest)
        report_manifest = sanitize_manifest(manifest) if args.sanitize_report else manifest
        write_json(staging_dir / MANIFEST_FILE, report_manifest)
        write_report(staging_dir / REPORT_FILE, report_manifest)
        publish_staged_output(staging_dir, output_dir)
        staging_dir = None
    finally:
        if staging_dir is not None and staging_dir.exists():
            remove_path(staging_dir)
        release_output_lock(output_lock)

    print(f"markdown content: {output_dir / PRIMARY_MARKDOWN}")
    if path_exists(output_dir / AUDIT_MARKDOWN):
        print(f"audit markdown: {output_dir / AUDIT_MARKDOWN}")
    print(f"manifest: {output_dir / MANIFEST_FILE}")
    print(f"report: {output_dir / REPORT_FILE}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
