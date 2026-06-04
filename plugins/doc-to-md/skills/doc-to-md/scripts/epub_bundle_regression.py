#!/usr/bin/env python3
from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from zipfile import ZIP_DEFLATED, ZIP_STORED, ZipFile


SCRIPT_DIR = Path(__file__).resolve().parent
SKILL_DIR = SCRIPT_DIR.parent
REPO_ROOT = SKILL_DIR.parent.parent


def maybe_reexec_in_core_venv() -> None:
    if os.environ.get("DOC_TO_MD_EPUB_REGRESSION_IN_VENV") == "1":
        return
    codex_home = Path(os.environ.get("CODEX_HOME", str(Path.home() / ".codex")))
    python = Path(
        os.environ.get(
            "MARKITDOWN_PYTHON",
            str(codex_home / "tools" / "markitdown-core-venv" / "bin" / "python"),
        )
    )
    if not python.exists() or not os.access(python, os.X_OK):
        return
    if Path(sys.executable) == python:
        return
    os.environ["DOC_TO_MD_EPUB_REGRESSION_IN_VENV"] = "1"
    os.execv(str(python), [str(python), str(Path(__file__).resolve()), *sys.argv[1:]])


maybe_reexec_in_core_venv()


def write_fixture(path: Path) -> None:
    image_png = (
        b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01"
        b"\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc\xf8\xff\xff?"
        b"\x00\x05\xfe\x02\xfeA\x89\x8d\x1d\x00\x00\x00\x00IEND\xaeB`\x82"
    )
    svg = '<svg xmlns="http://www.w3.org/2000/svg" width="120" height="40"><text x="4" y="20">Vector</text></svg>'
    with ZipFile(path, "w") as zf:
        zf.writestr("mimetype", "application/epub+zip", compress_type=ZIP_STORED)
        zf.writestr(
            "META-INF/container.xml",
            """<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
""",
            compress_type=ZIP_DEFLATED,
        )
        zf.writestr(
            "OPS/content.opf",
            """<?xml version="1.0" encoding="UTF-8"?>
<package version="3.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="bookid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>EPUB Bundle Smoke</dc:title>
    <dc:creator>Doc To Md Regression</dc:creator>
    <dc:language>en</dc:language>
    <dc:identifier id="bookid">epub-bundle-smoke</dc:identifier>
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="cover" href="images/cover.png" media-type="image/png" properties="cover-image"/>
    <item id="chapter1" href="chapters/chapter1.xhtml" media-type="application/xhtml+xml"/>
    <item id="chapter2" href="chapters/chapter2.xhtml" media-type="application/xhtml+xml"/>
    <item id="diagram" href="images/nested/diagram.png" media-type="image/png"/>
    <item id="vector" href="images/vector.svg" media-type="image/svg+xml"/>
  </manifest>
  <spine>
    <itemref idref="chapter1"/>
    <itemref idref="chapter2"/>
  </spine>
</package>
""",
            compress_type=ZIP_DEFLATED,
        )
        zf.writestr(
            "OPS/nav.xhtml",
            """<html xmlns="http://www.w3.org/1999/xhtml"><body>
<nav epub:type="toc"><ol>
  <li><a href="chapters/chapter1.xhtml">Chapter One</a></li>
  <li><a href="chapters/chapter2.xhtml">Chapter Two</a></li>
</ol></nav>
</body></html>
""",
            compress_type=ZIP_DEFLATED,
        )
        zf.writestr(
            "OPS/chapters/chapter1.xhtml",
            """<html xmlns="http://www.w3.org/1999/xhtml"><body>
<h1>Chapter One</h1>
<p>Opening text with <a href="chapter2.xhtml#target">an internal link</a> and <a href="https://example.org/ref">external link</a>.</p>
<p>Footnote call <a href="#fn1">note</a>.</p>
<figure><img src="../images/nested/diagram.png" alt="Nested diagram"/><figcaption>Nested asset diagram.</figcaption></figure>
<aside epub:type="footnote" id="fn1"><p>Footnote body for regression.</p></aside>
<table><tr><th colspan="2">Complex</th></tr><tr><td>A</td><td>B</td></tr></table>
</body></html>
""",
            compress_type=ZIP_DEFLATED,
        )
        zf.writestr(
            "OPS/chapters/chapter2.xhtml",
            """<html xmlns="http://www.w3.org/1999/xhtml"><body>
<h1 id="target">Chapter Two</h1>
<p>Math follows <math><mi>x</mi><mo>=</mo><mn>1</mn></math>.</p>
<svg xmlns="http://www.w3.org/2000/svg" width="80" height="40"><text x="4" y="20">Inline</text></svg>
<img src="../images/vector.svg" alt="Vector diagram"/>
</body></html>
""",
            compress_type=ZIP_DEFLATED,
        )
        zf.writestr("OPS/images/cover.png", image_png, compress_type=ZIP_DEFLATED)
        zf.writestr("OPS/images/nested/diagram.png", image_png, compress_type=ZIP_DEFLATED)
        zf.writestr("OPS/images/vector.svg", svg, compress_type=ZIP_DEFLATED)


def main() -> int:
    tmp = Path(tempfile.mkdtemp(prefix="doc-to-md-epub-regression."))
    try:
        source = tmp / "textbook.epub"
        bundle = tmp / "textbook-bundle"
        write_fixture(source)
        env = os.environ.copy()
        env["DOC_TO_MD_EPUB_REQUIREMENTS"] = str(SKILL_DIR / "requirements-core.txt")
        proc = subprocess.run(
            [str(SKILL_DIR / "scripts" / "mdown-epub"), str(source), "-o", str(bundle)],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=env,
        )
        if proc.returncode != 0:
            print(proc.stdout, file=sys.stderr)
            print(proc.stderr, file=sys.stderr)
            return proc.returncode

        required = [
            "LLM_README.md",
            "llm-index.md",
            "content.md",
            "toc.md",
            "assets-index.md",
            "audit.md",
            "manifest.json",
            "links.json",
            "conversion-report.md",
            "chapters",
            "assets",
        ]
        missing = [name for name in required if not (bundle / name).exists()]
        if missing:
            print(f"[fail] missing EPUB bundle outputs: {', '.join(missing)}", file=sys.stderr)
            return 1

        content = (bundle / "content.md").read_text(encoding="utf-8")
        llm_readme = (bundle / "LLM_README.md").read_text(encoding="utf-8")
        report = (bundle / "conversion-report.md").read_text(encoding="utf-8")
        assets_index = (bundle / "assets-index.md").read_text(encoding="utf-8")
        audit = (bundle / "audit.md").read_text(encoding="utf-8")
        manifest = json.loads((bundle / "manifest.json").read_text(encoding="utf-8"))
        links = json.loads((bundle / "links.json").read_text(encoding="utf-8"))
        checks = [
            ("LLM instructions", "LLM reading entrypoint" in content),
            ("chapter split", len(list((bundle / "chapters").glob("*.md"))) == 2),
            ("asset extraction", len(list((bundle / "assets").iterdir())) >= 4),
            ("asset index hint", "Inspect when" in assets_index),
            ("content asset cue", "inspect `assets-index.md` and `audit.md`" in content),
            ("llm asset cue", "explicitly check the asset and audit files" in llm_readme),
            ("human report warnings", "## Warnings" in report and "## Manual Inspection" in report),
            ("footnote", "[^fn1]" in content),
            ("complex table audit", "complex table" in audit.lower()),
            ("manifest tool", manifest.get("tool") == "mdown-epub"),
            ("links recorded", len(links.get("links", [])) >= 2),
        ]
        failed = [label for label, ok in checks if not ok]
        if failed:
            print(f"[fail] EPUB bundle regression checks failed: {', '.join(failed)}", file=sys.stderr)
            return 1

        schema_checks = [
            ("mdown-epub-manifest.schema.json", "manifest.json"),
            ("mdown-epub-links.schema.json", "links.json"),
        ]
        for schema, document in schema_checks:
            proc = subprocess.run(
                [str(REPO_ROOT / "scripts" / "validate-json-schema.py"), str(SKILL_DIR / "schemas" / schema), str(bundle / document)],
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            if proc.returncode != 0:
                print(proc.stdout, file=sys.stderr)
                print(proc.stderr, file=sys.stderr)
                return proc.returncode
        print("[ok] EPUB LLM bundle regression passed")
        return 0
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
