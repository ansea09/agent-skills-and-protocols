#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import base64
import json
import os
import shutil
import subprocess
import sys
import tempfile


def maybe_reexec_in_book_venv() -> None:
    if os.environ.get("DOC_TO_MD_AUDIT_REGRESSION_IN_VENV") == "1":
        return
    codex_home = Path(os.environ.get("CODEX_HOME", str(Path.home() / ".codex")))
    python = Path(os.environ.get("DOC_TO_MD_BOOK_PYTHON", str(codex_home / "tools" / "doc-to-md-book-venv" / "bin" / "python")))
    if not python.exists() or not os.access(python, os.X_OK):
        return
    if Path(sys.executable) == python:
        return
    os.environ["DOC_TO_MD_AUDIT_REGRESSION_IN_VENV"] = "1"
    os.execv(str(python), [str(python), str(Path(__file__).resolve()), *sys.argv[1:]])


maybe_reexec_in_book_venv()


def find_mdown_book() -> str:
    env = os.environ.get("MDOWN_BOOK_BIN")
    if env:
        return env
    found = shutil.which("mdown-book")
    if found:
        return found
    fallback = Path.home() / ".local" / "bin" / "mdown-book"
    if fallback.exists():
        return str(fallback)
    raise SystemExit("audit regression: could not find mdown-book")


def write_fixture_pdf(path: Path) -> None:
    try:
        import pymupdf
    except ImportError as exc:
        raise SystemExit("audit regression: PyMuPDF is required; install the book runtime") from exc

    # Tiny red PNG. Keeping it embedded avoids external binary fixtures.
    png = base64.b64decode(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="
    )
    doc = pymupdf.open()
    page = doc.new_page(width=360, height=220)
    page.insert_text((36, 42), "Audit Bundle Smoke", fontsize=18)
    page.insert_text((36, 150), "Audit link target", fontsize=11)
    page.insert_image(pymupdf.Rect(36, 64, 96, 124), stream=png)
    page.insert_link(
        {
            "kind": pymupdf.LINK_URI,
            "from": pymupdf.Rect(36, 136, 150, 158),
            "uri": "https://example.com/doc-to-md-audit",
        }
    )
    doc.save(path)
    doc.close()


def assert_contains(path: Path, needle: str) -> None:
    text = path.read_text(encoding="utf-8", errors="replace")
    if needle not in text:
        raise SystemExit(f"audit regression: expected {needle!r} in {path}")


def main() -> int:
    mdown_book = find_mdown_book()
    tmp = Path(tempfile.mkdtemp(prefix="doc-to-md-audit-regression."))
    keep = os.environ.get("DOC_TO_MD_KEEP_AUDIT_REGRESSION") == "1"
    try:
        source = tmp / "audit-fixture.pdf"
        bundle = tmp / "audit-bundle"
        write_fixture_pdf(source)
        proc = subprocess.run(
            [mdown_book, str(source), "-o", str(bundle), "--force"],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        if proc.returncode != 0:
            raise SystemExit(f"audit regression: mdown-book failed: {proc.stderr.strip()}")

        manifest_path = bundle / "manifest.json"
        if not manifest_path.is_file():
            raise SystemExit("audit regression: missing manifest.json")
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        pdf = manifest.get("pdf", {})
        if pdf.get("page_count") != 1:
            raise SystemExit(f"audit regression: expected one page, got {pdf.get('page_count')}")
        if int(pdf.get("image_count") or 0) < 1:
            raise SystemExit("audit regression: expected at least one extracted image")
        if int(pdf.get("link_count") or 0) < 1:
            raise SystemExit("audit regression: expected at least one link")
        assets = sorted((bundle / "assets").glob("*"))
        if not assets:
            raise SystemExit("audit regression: expected extracted asset file")

        assert_contains(bundle / "content.md", "Audit Bundle Smoke")
        assert_contains(bundle / "audit.md", "https://example.com/doc-to-md-audit")
        assert_contains(bundle / "conversion-report.md", "Extracted images: 1")
        print("[ok] audit bundle regression passed")
        return 0
    finally:
        if not keep:
            shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
