#!/usr/bin/env python3
from __future__ import annotations

import argparse
import datetime as dt
import html
import importlib.metadata
import json
import os
from pathlib import Path, PurePosixPath
import posixpath
import re
import shutil
import sys
import tempfile
from typing import Any
from urllib.parse import unquote, urlsplit
import uuid
from zipfile import ZipFile


try:
    from bs4 import BeautifulSoup, NavigableString
except ImportError:  # pragma: no cover - handled by doctor and startup error.
    BeautifulSoup = None  # type: ignore[assignment]
    NavigableString = str  # type: ignore[assignment]

try:
    from defusedxml import ElementTree as SafeET
except ImportError:  # pragma: no cover - handled by doctor and startup error.
    SafeET = None  # type: ignore[assignment]

try:
    from markdownify import markdownify as html_to_markdown
except ImportError:  # pragma: no cover - handled by doctor and startup error.
    html_to_markdown = None  # type: ignore[assignment]


CODEX_HOME = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex")).expanduser()
EPUB_REQUIREMENTS = Path(
    os.environ.get("DOC_TO_MD_EPUB_REQUIREMENTS", CODEX_HOME / "skills" / "doc-to-md" / "requirements-core.txt")
)
LLM_README = "LLM_README.md"
LLM_INDEX = "llm-index.md"
PRIMARY_MARKDOWN = "content.md"
TOC_MARKDOWN = "toc.md"
CHAPTERS_DIR = "chapters"
ASSETS_DIR = "assets"
ASSETS_INDEX = "assets-index.md"
AUDIT_MARKDOWN = "audit.md"
MANIFEST_FILE = "manifest.json"
LINKS_FILE = "links.json"
REPORT_FILE = "conversion-report.md"
GENERATED_NAMES = (
    LLM_README,
    LLM_INDEX,
    PRIMARY_MARKDOWN,
    TOC_MARKDOWN,
    CHAPTERS_DIR,
    ASSETS_DIR,
    ASSETS_INDEX,
    AUDIT_MARKDOWN,
    MANIFEST_FILE,
    LINKS_FILE,
    REPORT_FILE,
)
DEFAULT_MAX_INPUT_MB = int(os.environ.get("DOC_TO_MD_EPUB_MAX_INPUT_MB", "512"))
DEFAULT_MAX_FILES = int(os.environ.get("DOC_TO_MD_EPUB_MAX_FILES", "4096"))
DEFAULT_MAX_UNPACKED_MB = int(os.environ.get("DOC_TO_MD_EPUB_MAX_UNPACKED_MB", "2048"))
TEXT_MEDIA_TYPES = {"application/xhtml+xml", "text/html"}
IMAGE_MEDIA_PREFIX = "image/"
REMOTE_SCHEMES = {"http", "https", "ftp", "sftp"}


def reject_remote(value: str) -> None:
    if "://" in value:
        raise SystemExit("mdown-epub: only trusted local EPUB paths are supported")


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
    raise SystemExit(f"mdown-epub: {label} path is outside {env_name}: {resolved} (allowed: {roots_text})")


def check_input_size(path: Path, max_input_mb: int) -> None:
    if max_input_mb <= 0:
        return
    size_mb = path.stat().st_size / (1024 * 1024)
    if size_mb > max_input_mb:
        raise SystemExit(
            f"mdown-epub: input is {size_mb:.1f} MiB, above --max-input-mb {max_input_mb}; "
            "rerun with a higher limit or --max-input-mb 0"
        )


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
    lock_dir = output_dir.parent / f".{output_dir.name}.mdown-epub.lock"
    for _ in range(2):
        try:
            lock_dir.mkdir()
            (lock_dir / "pid").write_text(f"{os.getpid()}\n", encoding="utf-8")
            return lock_dir
        except FileExistsError:
            if lock_owner_active(lock_dir):
                raise SystemExit(f"mdown-epub: output is locked by another process: {lock_dir}")
            remove_path(lock_dir)
    raise SystemExit(f"mdown-epub: could not acquire output lock: {lock_dir}")


def release_output_lock(lock_dir: Path | None) -> None:
    if lock_dir is not None:
        remove_path(lock_dir)


def existing_generated_artifacts(output_dir: Path) -> list[Path]:
    if not output_dir.exists():
        return []
    return [output_dir / name for name in GENERATED_NAMES if path_exists(output_dir / name)]


def prepare_output_dir(output_dir: Path, force: bool) -> None:
    if output_dir.exists() and not output_dir.is_dir():
        raise SystemExit(f"mdown-epub: output path exists and is not a directory: {output_dir}")
    existing = existing_generated_artifacts(output_dir)
    if existing and not force:
        names = ", ".join(str(path.relative_to(output_dir)) for path in existing)
        raise SystemExit(f"mdown-epub: generated output already exists ({names}); pass --force to replace it")


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
        for name in GENERATED_NAMES:
            target = output_dir / name
            if path_exists(target):
                backup = output_dir / f".{name}.mdown-epub-backup-{token}"
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


def require_runtime() -> None:
    missing = []
    if BeautifulSoup is None:
        missing.append("beautifulsoup4")
    if SafeET is None:
        missing.append("defusedxml")
    if html_to_markdown is None:
        missing.append("markdownify")
    if missing:
        raise SystemExit(
            "mdown-epub: missing core runtime packages: "
            + ", ".join(missing)
            + "\nRebuild the core runtime with: scripts/install.sh"
        )


def local_name(name: str) -> str:
    return name.rsplit("}", 1)[-1]


def xml_from_bytes(data: bytes) -> Any:
    if SafeET is None:
        raise SystemExit("mdown-epub: defusedxml is not installed")
    return SafeET.fromstring(data)


def child_text(parent: Any, tag_name: str) -> str | None:
    for child in parent.iter():
        if local_name(child.tag) == tag_name and child.text:
            return child.text.strip()
    return None


def normalize_zip_path(path: str) -> str:
    path = unquote(path).replace("\\", "/")
    normalized = posixpath.normpath(path)
    if normalized == ".":
        return ""
    return normalized


def resolve_zip_path(base_dir: str, href: str) -> str:
    split = urlsplit(href)
    path = split.path
    if not path:
        return normalize_zip_path(base_dir)
    if path.startswith("/"):
        resolved = normalize_zip_path(path.lstrip("/"))
    else:
        resolved = normalize_zip_path(posixpath.join(base_dir, path))
    if resolved.startswith("../") or "/../" in resolved:
        raise ValueError(f"path escapes EPUB root: {href}")
    return resolved


def split_local_href(href: str) -> tuple[str, str, str]:
    split = urlsplit(href)
    return split.scheme, unquote(split.path), split.fragment


def safe_zip_member_name(name: str) -> None:
    normalized = name.replace("\\", "/")
    if not normalized or normalized.startswith("/") or normalized.startswith("\\"):
        raise SystemExit(f"mdown-epub: unsafe absolute EPUB member path: {name}")
    if re.match(r"^[A-Za-z]:", normalized):
        raise SystemExit(f"mdown-epub: unsafe drive-qualified EPUB member path: {name}")
    parts = PurePosixPath(normalized).parts
    if any(part == ".." for part in parts):
        raise SystemExit(f"mdown-epub: unsafe EPUB member path containing '..': {name}")


def check_epub_safety(zf: ZipFile, max_files: int, max_unpacked_mb: int) -> dict[str, Any]:
    infos = zf.infolist()
    if max_files > 0 and len(infos) > max_files:
        raise SystemExit(f"mdown-epub: EPUB contains {len(infos)} files, above --max-files {max_files}")
    total_size = 0
    for info in infos:
        safe_zip_member_name(info.filename)
        if info.flag_bits & 0x1:
            raise SystemExit(f"mdown-epub: encrypted or DRM-protected EPUB member is unsupported: {info.filename}")
        mode = (info.external_attr >> 16) & 0o170000
        if mode == 0o120000:
            raise SystemExit(f"mdown-epub: symlink member is unsupported: {info.filename}")
        total_size += info.file_size
    total_mb = total_size / (1024 * 1024)
    if max_unpacked_mb > 0 and total_mb > max_unpacked_mb:
        raise SystemExit(
            f"mdown-epub: EPUB unpacked size is {total_mb:.1f} MiB, above --max-unpacked-mb {max_unpacked_mb}"
        )
    if "META-INF/encryption.xml" in zf.namelist():
        raise SystemExit("mdown-epub: EPUB encryption/DRM metadata is unsupported")
    return {"file_count": len(infos), "unpacked_bytes": total_size}


def read_member(zf: ZipFile, name: str) -> bytes:
    try:
        return zf.read(name)
    except KeyError as exc:
        raise SystemExit(f"mdown-epub: required EPUB member is missing: {name}") from exc


def text_from_member(zf: ZipFile, name: str) -> str:
    data = read_member(zf, name)
    for encoding in ("utf-8-sig", "utf-8", "utf-16"):
        try:
            return data.decode(encoding)
        except UnicodeDecodeError:
            continue
    return data.decode("utf-8", errors="replace")


def slugify(value: str, fallback: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9._-]+", "-", value.strip()).strip("-._").lower()
    return cleaned[:80] or fallback


def unique_name(existing: set[str], candidate: str) -> str:
    stem, dot, suffix = candidate.partition(".")
    name = candidate
    index = 2
    while name in existing:
        if dot:
            name = f"{stem}-{index}.{suffix}"
        else:
            name = f"{candidate}-{index}"
        index += 1
    existing.add(name)
    return name


def find_container_rootfile(zf: ZipFile) -> str:
    root = xml_from_bytes(read_member(zf, "META-INF/container.xml"))
    for elem in root.iter():
        if local_name(elem.tag) == "rootfile":
            full_path = elem.attrib.get("full-path")
            if full_path:
                return normalize_zip_path(full_path)
    raise SystemExit("mdown-epub: META-INF/container.xml has no rootfile")


def parse_opf(zf: ZipFile, opf_path: str) -> dict[str, Any]:
    root = xml_from_bytes(read_member(zf, opf_path))
    opf_base = "" if "/" not in opf_path else opf_path.rsplit("/", 1)[0]
    metadata: dict[str, Any] = {}
    manifest: dict[str, dict[str, Any]] = {}
    spine: list[dict[str, Any]] = []
    cover_id: str | None = None
    spine_toc_id: str | None = None

    for elem in root.iter():
        name = local_name(elem.tag)
        if name in {"title", "creator", "language", "identifier", "publisher", "date", "description"}:
            text = (elem.text or "").strip()
            if text:
                key = name
                if key in metadata:
                    if not isinstance(metadata[key], list):
                        metadata[key] = [metadata[key]]
                    metadata[key].append(text)
                else:
                    metadata[key] = text
        elif name == "meta":
            if elem.attrib.get("name") == "cover" and elem.attrib.get("content"):
                cover_id = elem.attrib["content"]
            prop = elem.attrib.get("property")
            text = (elem.text or "").strip()
            if prop and text:
                metadata.setdefault("meta", {})[prop] = text
        elif name == "item":
            item_id = elem.attrib.get("id")
            href = elem.attrib.get("href")
            if not item_id or not href:
                continue
            try:
                resolved = resolve_zip_path(opf_base, href)
            except ValueError as exc:
                raise SystemExit(f"mdown-epub: unsafe manifest href: {exc}") from exc
            manifest[item_id] = {
                "id": item_id,
                "href": href,
                "path": resolved,
                "media_type": elem.attrib.get("media-type", ""),
                "properties": elem.attrib.get("properties", ""),
            }
            if "cover-image" in elem.attrib.get("properties", "").split():
                cover_id = item_id
        elif name == "spine":
            spine_toc_id = elem.attrib.get("toc")
        elif name == "itemref":
            idref = elem.attrib.get("idref")
            if idref:
                spine.append({"idref": idref, "linear": elem.attrib.get("linear", "yes")})

    nav_id = next((item_id for item_id, item in manifest.items() if "nav" in item["properties"].split()), None)
    if not nav_id:
        nav_id = next((item_id for item_id, item in manifest.items() if item["path"].lower().endswith("nav.xhtml")), None)
    ncx_id = spine_toc_id or next(
        (item_id for item_id, item in manifest.items() if item["media_type"] == "application/x-dtbncx+xml"),
        None,
    )
    return {
        "opf_path": opf_path,
        "opf_base": opf_base,
        "metadata": metadata,
        "manifest": manifest,
        "spine": spine,
        "cover_id": cover_id,
        "nav_id": nav_id,
        "ncx_id": ncx_id,
    }


def item_title_from_xhtml(text: str, fallback: str) -> str:
    if BeautifulSoup is None:
        return fallback
    soup = BeautifulSoup(text, "html.parser")
    for selector in ("h1", "h2", "title"):
        tag = soup.find(selector)
        if tag:
            value = tag.get_text(" ", strip=True)
            if value:
                return value
    return fallback


def parse_epub3_nav(zf: ZipFile, nav_path: str) -> list[dict[str, Any]]:
    soup = BeautifulSoup(text_from_member(zf, nav_path), "html.parser")
    nav = None
    for candidate in soup.find_all("nav"):
        nav_type = " ".join(
            [
                candidate.get("epub:type", ""),
                candidate.get("type", ""),
                candidate.get("role", ""),
                candidate.get("aria-label", ""),
            ]
        ).lower()
        if "toc" in nav_type:
            nav = candidate
            break
    if nav is None:
        nav = soup.find("nav")
    if nav is None:
        return []

    entries: list[dict[str, Any]] = []

    def walk(parent: Any, level: int) -> None:
        for li in parent.find_all("li", recursive=False):
            link = li.find("a", recursive=False)
            if link:
                entries.append(
                    {
                        "level": level,
                        "title": link.get_text(" ", strip=True) or "Untitled",
                        "href": link.get("href", ""),
                    }
                )
            child_list = li.find(["ol", "ul"], recursive=False)
            if child_list is not None:
                walk(child_list, level + 1)

    root_list = nav.find(["ol", "ul"])
    if root_list is not None:
        walk(root_list, 1)
    return entries


def parse_epub2_ncx(zf: ZipFile, ncx_path: str) -> list[dict[str, Any]]:
    root = xml_from_bytes(read_member(zf, ncx_path))
    entries: list[dict[str, Any]] = []

    def walk_navpoint(node: Any, level: int) -> None:
        if local_name(node.tag) == "navPoint":
            title = child_text(node, "text") or "Untitled"
            href = ""
            for child in node.iter():
                if local_name(child.tag) == "content":
                    href = child.attrib.get("src", "")
                    break
            entries.append({"level": level, "title": title, "href": href})
            next_level = level + 1
        else:
            next_level = level
        for child in list(node):
            if local_name(child.tag) == "navPoint":
                walk_navpoint(child, next_level)

    for elem in root.iter():
        if local_name(elem.tag) == "navMap":
            walk_navpoint(elem, 1)
            break
    return entries


def classify_href(href: str) -> str:
    scheme = urlsplit(href).scheme.lower()
    if scheme in REMOTE_SCHEMES:
        return "external"
    if scheme in {"mailto", "tel"}:
        return "external"
    if scheme:
        return "unsupported-scheme"
    return "internal"


def is_footnote(tag: Any) -> bool:
    marker = " ".join(
        str(tag.get(attr, ""))
        for attr in ("epub:type", "type", "role", "class", "id")
    ).lower()
    return "footnote" in marker or "endnote" in marker or "doc-endnote" in marker


def is_complex_table(table: Any) -> bool:
    if table.find("table"):
        return True
    for cell in table.find_all(["td", "th"]):
        if cell.get("rowspan") or cell.get("colspan"):
            return True
    return False


def first_heading_before(tag: Any) -> str | None:
    for prev in tag.find_all_previous(["h1", "h2", "h3", "h4", "h5", "h6"]):
        value = prev.get_text(" ", strip=True)
        if value:
            return value
    return None


class EpubConverter:
    def __init__(self, zf: ZipFile, opf: dict[str, Any], staging_dir: Path, profile: str) -> None:
        self.zf = zf
        self.opf = opf
        self.staging_dir = staging_dir
        self.profile = profile
        self.assets_dir = staging_dir / ASSETS_DIR
        self.chapters_dir = staging_dir / CHAPTERS_DIR
        self.assets_dir.mkdir(parents=True, exist_ok=True)
        self.chapters_dir.mkdir(parents=True, exist_ok=True)
        self.assets_seen: set[str] = set()
        self.chapter_seen: set[str] = set()
        self.assets: list[dict[str, Any]] = []
        self.links: list[dict[str, Any]] = []
        self.warnings: list[str] = []
        self.unsupported: list[dict[str, Any]] = []
        self.cover_asset: dict[str, Any] | None = None

    def chapter_records(self) -> list[dict[str, Any]]:
        records: list[dict[str, Any]] = []
        manifest = self.opf["manifest"]
        for index, spine_item in enumerate(self.opf["spine"], start=1):
            item = manifest.get(spine_item["idref"])
            if not item:
                self.warnings.append(f"spine item missing from manifest: {spine_item['idref']}")
                continue
            if item.get("media_type") not in TEXT_MEDIA_TYPES:
                self.warnings.append(f"non-XHTML spine item skipped: {item['path']}")
                continue
            text = text_from_member(self.zf, item["path"])
            title = item_title_from_xhtml(text, f"Chapter {index}")
            chapter_name = unique_name(self.chapter_seen, f"ch{index:03d}-{slugify(title, 'chapter')}.md")
            records.append(
                {
                    "index": index,
                    "idref": spine_item["idref"],
                    "linear": spine_item.get("linear", "yes"),
                    "title": title,
                    "source_path": item["path"],
                    "output": f"{CHAPTERS_DIR}/{chapter_name}",
                    "chapter_file": chapter_name,
                    "text": text,
                }
            )
        return records

    def extract_asset(
        self,
        source_path: str,
        chapter: dict[str, Any] | None,
        kind: str,
        inspect_when: str,
        alt: str = "",
        nearby_heading: str | None = None,
    ) -> dict[str, Any]:
        suffix = Path(source_path).suffix.lower() or ".bin"
        source_name = slugify(Path(source_path).stem, kind)
        prefix = "cover" if chapter is None else f"ch{chapter['index']:03d}"
        filename = unique_name(self.assets_seen, f"{prefix}-{source_name}{suffix}")
        target = self.assets_dir / filename
        target.write_bytes(read_member(self.zf, source_path))
        media_type = next(
            (item["media_type"] for item in self.opf["manifest"].values() if item["path"] == source_path),
            "",
        )
        record = {
            "kind": kind,
            "source_path": source_path,
            "file": f"{ASSETS_DIR}/{filename}",
            "media_type": media_type,
            "chapter": chapter["output"] if chapter else None,
            "chapter_title": chapter["title"] if chapter else None,
            "nearby_heading": nearby_heading,
            "alt": alt,
            "inspect_when": inspect_when,
        }
        self.assets.append(record)
        if media_type == "image/svg+xml" or suffix == ".svg":
            self.unsupported.append(
                {
                    "kind": "svg",
                    "source_path": source_path,
                    "file": record["file"],
                    "message": "SVG extracted but not semantically analyzed",
                }
            )
        return record

    def extract_cover(self) -> None:
        cover_id = self.opf.get("cover_id")
        if not cover_id:
            return
        item = self.opf["manifest"].get(cover_id)
        if not item:
            self.warnings.append(f"cover item missing from manifest: {cover_id}")
            return
        if not item.get("media_type", "").startswith(IMAGE_MEDIA_PREFIX):
            self.warnings.append(f"cover item is not an image: {item['path']}")
            return
        self.cover_asset = self.extract_asset(
            item["path"],
            None,
            "cover",
            "Inspect when the cover/title page may affect edition, title, or visual identity.",
            alt="Cover image",
        )

    def rewrite_link(self, href: str, chapter: dict[str, Any], chapter_by_source: dict[str, dict[str, Any]]) -> tuple[str, dict[str, Any]]:
        kind = classify_href(href)
        record: dict[str, Any] = {
            "source_chapter": chapter["output"],
            "original_href": href,
            "kind": kind,
            "rewritten_href": href,
        }
        if kind != "internal":
            if kind == "unsupported-scheme":
                self.warnings.append(f"unsupported link scheme in {chapter['source_path']}: {href}")
            return href, record

        scheme, path, fragment = split_local_href(href)
        del scheme
        try:
            target_source = chapter["source_path"] if not path else resolve_zip_path(
                "" if "/" not in chapter["source_path"] else chapter["source_path"].rsplit("/", 1)[0],
                path,
            )
        except ValueError:
            record["kind"] = "unsafe-internal"
            self.warnings.append(f"unsafe internal link in {chapter['source_path']}: {href}")
            return href, record

        target_chapter = chapter_by_source.get(target_source)
        if target_chapter:
            rewritten = Path(target_chapter["output"]).name
            if fragment:
                rewritten += f"#{fragment}"
            record["rewritten_href"] = rewritten
            record["target_chapter"] = target_chapter["output"]
            record["fragment"] = fragment
            return rewritten, record
        if fragment and not path:
            rewritten = f"#{fragment}"
            record["rewritten_href"] = rewritten
            record["fragment"] = fragment
            return rewritten, record
        record["kind"] = "unresolved-internal"
        self.warnings.append(f"unresolved internal link in {chapter['source_path']}: {href}")
        return href, record

    def chapter_markdown(self, chapter: dict[str, Any], chapter_by_source: dict[str, dict[str, Any]]) -> str:
        soup = BeautifulSoup(chapter["text"], "html.parser")
        for tag in soup.find_all(["script", "style"]):
            self.warnings.append(f"removed non-content tag <{tag.name}> from {chapter['source_path']}")
            tag.decompose()

        footnotes: dict[str, str] = {}
        for tag in list(soup.find_all(is_footnote)):
            note_id = tag.get("id") or f"note-{len(footnotes) + 1}"
            note_id = slugify(str(note_id), f"note-{len(footnotes) + 1}")
            text = tag.get_text(" ", strip=True)
            if text:
                footnotes[note_id] = text
            tag.decompose()

        for anchor in soup.find_all("a"):
            href = anchor.get("href")
            if not href:
                continue
            _, path, fragment = split_local_href(href)
            if fragment and not path and slugify(fragment, fragment) in footnotes:
                anchor.replace_with(NavigableString(f"[^{slugify(fragment, fragment)}]"))
                continue
            rewritten, link_record = self.rewrite_link(href, chapter, chapter_by_source)
            anchor["href"] = rewritten
            self.links.append(link_record)

        for image_index, image in enumerate(soup.find_all("img"), start=1):
            src = image.get("src")
            if not src:
                self.warnings.append(f"image without src in {chapter['source_path']}")
                continue
            if classify_href(src) != "internal":
                self.unsupported.append(
                    {
                        "kind": "remote-asset",
                        "source_path": chapter["source_path"],
                        "href": src,
                        "message": "Remote assets are not fetched",
                    }
                )
                image.replace_with(NavigableString(f"[Remote image not fetched: {src}]"))
                continue
            try:
                source_path = resolve_zip_path(
                    "" if "/" not in chapter["source_path"] else chapter["source_path"].rsplit("/", 1)[0],
                    split_local_href(src)[1],
                )
            except ValueError:
                self.warnings.append(f"unsafe image path in {chapter['source_path']}: {src}")
                continue
            alt = image.get("alt") or f"Chapter {chapter['index']} image {image_index}"
            record = self.extract_asset(
                source_path,
                chapter,
                "image",
                "Inspect when answering questions that depend on diagrams, figures, maps, equations shown as images, or visual examples.",
                alt=alt,
                nearby_heading=first_heading_before(image),
            )
            image["src"] = f"../{record['file']}"
            image["alt"] = alt
            note = soup.new_tag("blockquote")
            note.string = (
                f"Asset note: {alt}. File: {record['file']}. "
                f"Inspect when: {record['inspect_when']} Source: {source_path}."
            )
            image.insert_after(note)

        for svg_index, svg in enumerate(list(soup.find_all("svg")), start=1):
            filename = unique_name(self.assets_seen, f"ch{chapter['index']:03d}-inline-svg{svg_index:02d}.svg")
            file_path = self.assets_dir / filename
            file_path.write_text(str(svg), encoding="utf-8")
            record = {
                "kind": "inline-svg",
                "source_path": chapter["source_path"],
                "file": f"{ASSETS_DIR}/{filename}",
                "media_type": "image/svg+xml",
                "chapter": chapter["output"],
                "chapter_title": chapter["title"],
                "nearby_heading": first_heading_before(svg),
                "alt": "Inline SVG",
                "inspect_when": "Inspect when the answer depends on vector diagrams or embedded equations.",
            }
            self.assets.append(record)
            self.unsupported.append({**record, "message": "Inline SVG extracted but not semantically analyzed"})
            svg.replace_with(NavigableString(f"[Inline SVG extracted: ../{record['file']}]"))

        for math_index, math_tag in enumerate(list(soup.find_all("math")), start=1):
            filename = unique_name(self.assets_seen, f"ch{chapter['index']:03d}-mathml{math_index:02d}.mathml")
            file_path = self.assets_dir / filename
            file_path.write_text(str(math_tag), encoding="utf-8")
            record = {
                "kind": "mathml",
                "source_path": chapter["source_path"],
                "file": f"{ASSETS_DIR}/{filename}",
                "media_type": "application/mathml+xml",
                "chapter": chapter["output"],
                "chapter_title": chapter["title"],
                "nearby_heading": first_heading_before(math_tag),
                "alt": "MathML expression",
                "inspect_when": "Inspect when the answer depends on exact formulas or symbolic notation.",
            }
            self.assets.append(record)
            self.unsupported.append({**record, "message": "MathML extracted but not converted to semantic Markdown"})
            math_tag.replace_with(NavigableString(f"[MathML expression extracted: ../{record['file']}]"))

        for media in soup.find_all(["audio", "video", "source", "iframe", "embed", "object"]):
            self.unsupported.append(
                {
                    "kind": media.name,
                    "source_path": chapter["source_path"],
                    "message": f"<{media.name}> media is not executed or fetched",
                }
            )
            media.replace_with(NavigableString(f"[Unsupported media element removed: {media.name}]"))

        for table_index, table in enumerate(list(soup.find_all("table")), start=1):
            if is_complex_table(table):
                raw = str(table)
                escaped = html.escape(raw)
                placeholder = BeautifulSoup(
                    (
                        f"<p>Complex table preserved as raw HTML fallback: chapter {chapter['index']} "
                        f"table {table_index}.</p><pre><code>{escaped}</code></pre>"
                    ),
                    "html.parser",
                )
                table.replace_with(placeholder)
                self.warnings.append(f"complex table preserved as raw HTML fallback in {chapter['source_path']}")

        body = soup.find("body") or soup
        markdown = html_to_markdown(str(body), heading_style="ATX", bullets="-") if html_to_markdown else body.get_text("\n")
        markdown = re.sub(r"\n{3,}", "\n\n", markdown).strip()
        if footnotes:
            markdown += "\n\n" + "\n".join(f"[^{key}]: {value}" for key, value in footnotes.items())
        header = [
            f"# {chapter['title']}",
            "",
            f"Source EPUB item: `{chapter['source_path']}`",
            "",
        ]
        return "\n".join(header) + markdown + "\n"

    def convert(self) -> dict[str, Any]:
        self.extract_cover()
        chapters = self.chapter_records()
        chapter_by_source = {chapter["source_path"]: chapter for chapter in chapters}
        content_parts: list[str] = []
        for chapter in chapters:
            markdown = self.chapter_markdown(chapter, chapter_by_source)
            (self.staging_dir / chapter["output"]).write_text(markdown, encoding="utf-8")
            chapter["text"] = None
            chapter["markdown_chars"] = len(markdown)
            content_markdown = markdown.replace("../assets/", "assets/")
            content_markdown = re.sub(r"\]\((ch\d{3}-[^)#]+\.md)(#[^)]+)?\)", r"](chapters/\1\2)", content_markdown)
            content_parts.append(f"<!-- chapter: {chapter['output']} -->\n\n{content_markdown.strip()}\n")

        self.record_manifest_unsupported(chapters)
        nav_entries = self.navigation()
        manifest = {
            "schema_version": 1,
            "tool": "mdown-epub",
            "profile": self.profile,
            "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(),
            "metadata": self.opf.get("metadata", {}),
            "opf_path": self.opf["opf_path"],
            "chapter_count": len(chapters),
            "asset_count": len(self.assets),
            "link_count": len(self.links),
            "warning_count": len(self.warnings),
            "chapters": chapters,
            "assets": self.assets,
            "cover": self.cover_asset,
            "toc": nav_entries,
            "unsupported": self.unsupported,
            "warnings": self.warnings,
            "outputs": {
                "llm_readme": LLM_README,
                "llm_index": LLM_INDEX,
                "content": PRIMARY_MARKDOWN,
                "toc": TOC_MARKDOWN,
                "chapters_dir": CHAPTERS_DIR,
                "assets_dir": ASSETS_DIR,
                "assets_index": ASSETS_INDEX,
                "audit": AUDIT_MARKDOWN,
                "manifest": MANIFEST_FILE,
                "links": LINKS_FILE,
                "report": REPORT_FILE,
            },
        }
        self.write_content(content_parts, manifest)
        self.write_llm_readme(manifest)
        self.write_llm_index(manifest)
        self.write_toc(nav_entries, chapters)
        self.write_assets_index()
        self.write_audit(manifest)
        self.write_links()
        self.write_json(self.staging_dir / MANIFEST_FILE, manifest)
        self.write_report(manifest)
        return manifest

    def navigation(self) -> list[dict[str, Any]]:
        nav_entries: list[dict[str, Any]] = []
        nav_id = self.opf.get("nav_id")
        ncx_id = self.opf.get("ncx_id")
        try:
            if nav_id and nav_id in self.opf["manifest"]:
                nav_entries = parse_epub3_nav(self.zf, self.opf["manifest"][nav_id]["path"])
            elif ncx_id and ncx_id in self.opf["manifest"]:
                nav_entries = parse_epub2_ncx(self.zf, self.opf["manifest"][ncx_id]["path"])
        except Exception as exc:  # noqa: BLE001 - TOC failure should not block chapter extraction.
            self.warnings.append(f"failed to parse EPUB navigation: {exc}")
        return nav_entries

    def record_manifest_unsupported(self, chapters: list[dict[str, Any]]) -> None:
        chapter_paths = {chapter["source_path"] for chapter in chapters}
        asset_paths = {asset["source_path"] for asset in self.assets if asset.get("source_path")}
        for item in self.opf["manifest"].values():
            media_type = item.get("media_type", "")
            if item["path"] in chapter_paths or item["path"] in asset_paths:
                continue
            if media_type.startswith(("audio/", "video/")) or media_type in {"image/svg+xml", "application/mathml+xml"}:
                self.unsupported.append(
                    {
                        "kind": media_type or "unsupported-manifest-item",
                        "source_path": item["path"],
                        "message": "Manifest item was recorded but not converted into running Markdown",
                    }
                )

    def write_content(self, content_parts: list[str], manifest: dict[str, Any]) -> None:
        title = manifest["metadata"].get("title") or "EPUB Textbook"
        lines = [
            f"# {title}",
            "",
            "LLM reading entrypoint: start with this file for continuous text.",
            f"For navigation and asset inspection rules, read `{LLM_README}`.",
            "Before answering questions about diagrams, figures, formula images, MathML, SVG, media, or table layout, inspect `assets-index.md` and `audit.md`.",
            "",
            "## Bundle Map",
            "",
            f"- Full table of contents: `{TOC_MARKDOWN}`",
            f"- Chapter files: `{CHAPTERS_DIR}/`",
            f"- Asset index: `{ASSETS_INDEX}`",
            f"- Conversion audit: `{AUDIT_MARKDOWN}`",
            "",
        ]
        lines.extend(content_parts)
        (self.staging_dir / PRIMARY_MARKDOWN).write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")

    def write_llm_readme(self, manifest: dict[str, Any]) -> None:
        lines = [
            "# LLM Reading Instructions",
            "",
            "This bundle is designed for LLM-based textbook analysis across Codex, Claude Code, and other local agent runtimes.",
            "",
            "## How To Read",
            "",
            f"1. Start with `{PRIMARY_MARKDOWN}` for continuous reading-order text.",
            f"2. Use `{TOC_MARKDOWN}` to jump to specific chapter files under `{CHAPTERS_DIR}/`.",
            f"3. When a question depends on a figure, diagram, table layout, formula image, MathML, SVG, or media object, inspect `{ASSETS_INDEX}` and `{AUDIT_MARKDOWN}` before answering.",
            f"4. Use `{LINKS_FILE}` for internal and external link records.",
            f"5. Use `{MANIFEST_FILE}` for machine-readable provenance and counts.",
            "",
            "Before answering visual, formula, media, or table-layout-sensitive questions, explicitly check the asset and audit files. This bundle surfaces those artifacts; it does not make the continuous Markdown self-sufficient for them.",
            "",
            "## Important Limits",
            "",
            "- Extracted images, SVG, MathML, and media are surfaced for inspection, not semantically analyzed.",
            "- Remote assets are not fetched.",
            "- JavaScript is not executed.",
            "- Encrypted or DRM-marked EPUB files are unsupported.",
            "- Relative links are used so the bundle can move between local agent runtimes.",
            "",
            "## Summary",
            "",
            f"- Chapters: {manifest['chapter_count']}",
            f"- Assets: {manifest['asset_count']}",
            f"- Links: {manifest['link_count']}",
            f"- Warnings: {manifest['warning_count']}",
            "",
        ]
        (self.staging_dir / LLM_README).write_text("\n".join(lines), encoding="utf-8")

    def write_llm_index(self, manifest: dict[str, Any]) -> None:
        lines = [
            "# LLM Index",
            "",
            "Primary route:",
            "",
            f"- Read `{PRIMARY_MARKDOWN}` first.",
            f"- Open chapter files in `{CHAPTERS_DIR}/` for focused context.",
            f"- Open `{ASSETS_INDEX}` before answering visual, formula, table-layout, or media-dependent questions.",
            "",
            "Chapters:",
            "",
        ]
        for chapter in manifest["chapters"]:
            lines.append(f"- [{chapter['title']}]({chapter['output']}) - source `{chapter['source_path']}`")
        lines.extend(["", "Assets needing possible inspection:", ""])
        if self.assets:
            for asset in self.assets:
                lines.append(f"- `{asset['file']}` - {asset['inspect_when']}")
        else:
            lines.append("- None extracted.")
        lines.append("")
        (self.staging_dir / LLM_INDEX).write_text("\n".join(lines), encoding="utf-8")

    def write_toc(self, nav_entries: list[dict[str, Any]], chapters: list[dict[str, Any]]) -> None:
        lines = ["# Table Of Contents", ""]
        if nav_entries:
            lines.append("EPUB navigation:")
            lines.append("")
            for entry in nav_entries:
                indent = "  " * max(0, int(entry.get("level", 1)) - 1)
                lines.append(f"{indent}- {entry['title']} (`{entry.get('href', '')}`)")
            lines.append("")
        lines.append("Chapter files:")
        lines.append("")
        for chapter in chapters:
            lines.append(f"- [{chapter['title']}]({chapter['output']})")
        lines.append("")
        (self.staging_dir / TOC_MARKDOWN).write_text("\n".join(lines), encoding="utf-8")

    def write_assets_index(self) -> None:
        lines = ["# Assets Index", "", "Use this file when LLM analysis may depend on non-textual material.", ""]
        if not self.assets:
            lines.append("No assets were extracted.")
        for asset in self.assets:
            lines.extend(
                [
                    f"## {asset['file']}",
                    "",
                    f"- Kind: {asset['kind']}",
                    f"- Source EPUB item: `{asset['source_path']}`",
                    f"- Chapter: `{asset.get('chapter') or 'cover/metadata'}`",
                    f"- Nearby heading: {asset.get('nearby_heading') or 'unknown'}",
                    f"- Alt/caption: {asset.get('alt') or 'none'}",
                    f"- Inspect when: {asset['inspect_when']}",
                    "",
                ]
            )
            if asset["media_type"].startswith("image/"):
                lines.append(f"![{asset.get('alt') or asset['file']}]({asset['file']})")
                lines.append("")
        (self.staging_dir / ASSETS_INDEX).write_text("\n".join(lines), encoding="utf-8")

    def write_audit(self, manifest: dict[str, Any]) -> None:
        lines = [
            "# EPUB Bundle Audit",
            "",
            "This audit records structures that may affect LLM analysis quality.",
            "",
            "## Counts",
            "",
            f"- Chapters: {manifest['chapter_count']}",
            f"- Assets: {manifest['asset_count']}",
            f"- Links: {manifest['link_count']}",
            f"- Unsupported or risky structures: {len(self.unsupported)}",
            f"- Warnings: {len(self.warnings)}",
            "",
            "## Warnings",
            "",
        ]
        lines.extend(f"- {warning}" for warning in self.warnings) if self.warnings else lines.append("- None.")
        lines.extend(["", "## Unsupported Or Manual-Inspection Items", ""])
        if self.unsupported:
            for item in self.unsupported:
                lines.append(f"- {item.get('kind', 'unknown')}: {item.get('message', '')} `{item.get('source_path', '')}`")
        else:
            lines.append("- None detected.")
        lines.extend(["", "## Safety Boundary", "", "- No remote assets were fetched.", "- JavaScript was not executed."])
        (self.staging_dir / AUDIT_MARKDOWN).write_text("\n".join(lines) + "\n", encoding="utf-8")

    def write_links(self) -> None:
        payload = {"schema_version": 1, "tool": "mdown-epub", "links": self.links}
        self.write_json(self.staging_dir / LINKS_FILE, payload)

    def write_report(self, manifest: dict[str, Any]) -> None:
        lines = [
            "# Conversion Report",
            "",
            f"Tool: `{manifest['tool']}`",
            f"Generated at: `{manifest['generated_at']}`",
            f"Profile: `{manifest['profile']}`",
            "",
            "## Outputs",
            "",
        ]
        for key, value in manifest["outputs"].items():
            lines.append(f"- {key}: `{value}`")
        lines.extend(
            [
                "",
                "## Start Here",
                "",
                f"- For LLM analysis, open `{LLM_README}` first, then `{PRIMARY_MARKDOWN}`.",
                f"- For human review, check this report, then `{AUDIT_MARKDOWN}` if warnings or unsupported items are listed.",
                f"- For figure, diagram, formula, MathML, SVG, media, or table-layout questions, inspect `{ASSETS_INDEX}` before trusting the continuous Markdown alone.",
                "",
                "## Summary",
                "",
                f"- Chapters: {manifest['chapter_count']}",
                f"- Assets: {manifest['asset_count']}",
                f"- Links: {manifest['link_count']}",
                f"- Warnings: {manifest['warning_count']}",
                f"- Unsupported/manual-inspection items: {len(self.unsupported)}",
                "",
                "## Warnings",
                "",
            ]
        )
        if self.warnings:
            lines.extend(f"- {warning}" for warning in self.warnings[:10])
            if len(self.warnings) > 10:
                lines.append(f"- ... {len(self.warnings) - 10} more warnings in `{AUDIT_MARKDOWN}`")
        else:
            lines.append("- None.")
        lines.extend(
            [
                "",
                "## Manual Inspection",
                "",
            ]
        )
        if self.unsupported:
            for item in self.unsupported[:10]:
                lines.append(f"- {item.get('kind', 'unknown')}: {item.get('message', '')} `{item.get('source_path', '')}`")
            if len(self.unsupported) > 10:
                lines.append(f"- ... {len(self.unsupported) - 10} more items in `{AUDIT_MARKDOWN}`")
        else:
            lines.append("- None.")
        lines.extend(
            [
                "",
                "## Quality Boundary",
                "",
                "This workflow improves LLM discoverability and routing for EPUB textbooks.",
                "It does not run OCR, vision, remote fetches, JavaScript, DRM removal, or publication-quality layout reconstruction.",
                "",
            ]
        )
        (self.staging_dir / REPORT_FILE).write_text("\n".join(lines), encoding="utf-8")

    @staticmethod
    def write_json(path: Path, value: dict[str, Any]) -> None:
        path.write_text(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")


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


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def expected_requirements(path: Path) -> dict[str, str]:
    pins: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip().rstrip("\\").strip()
        if not line or line.startswith("#") or line.startswith("--hash="):
            continue
        match = re.match(r"([A-Za-z0-9_.-]+)==([^;#\s\\]+)", line)
        if match:
            pins[match.group(1)] = match.group(2)
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


def finalize_doctor_payload(payload: dict[str, Any]) -> dict[str, Any]:
    levels = {check["level"] for check in payload["checks"]}
    status = "fail" if "fail" in levels else "warn" if "warn" in levels else "ok"
    payload["status"] = status
    payload["exit_code"] = 1 if status == "fail" else 0
    return payload


def build_doctor_payload() -> dict[str, Any]:
    payload: dict[str, Any] = {
        "schema_version": 1,
        "tool": "mdown-epub",
        "paths": {"requirements": str(EPUB_REQUIREMENTS)},
        "checks": [],
    }
    for package in ("beautifulsoup4", "defusedxml", "markdownify"):
        version = installed_version(package)
        if version:
            add_doctor_check(payload, "ok", f"{package} {version}", package=package, installed=version)
        else:
            add_doctor_check(payload, "fail", f"{package} is missing", package=package, installed=None)
    try:
        text = EPUB_REQUIREMENTS.read_text(encoding="utf-8")
        if "--hash=" in text:
            add_doctor_check(payload, "ok", "core requirements include pip hashes", path=str(EPUB_REQUIREMENTS))
        else:
            add_doctor_check(
                payload,
                "info",
                "core requirements use exact pins without hashes; this is normal for local pinned installs",
                path=str(EPUB_REQUIREMENTS),
                install_mode="normal-pinned",
            )
        pins = expected_requirements(EPUB_REQUIREMENTS)
        mismatches = []
        for package in ("beautifulsoup4", "defusedxml", "markdownify"):
            expected = pins.get(package)
            installed = installed_version(package)
            if expected and installed != expected:
                mismatches.append({"name": package, "expected": expected, "installed": installed or "missing"})
        if mismatches:
            add_doctor_check(payload, "fail", "EPUB dependency drift", mismatches=mismatches)
        else:
            add_doctor_check(payload, "ok", "EPUB core dependencies match pinned requirements")
    except OSError as exc:
        add_doctor_check(payload, "fail", f"could not read requirements: {exc}")
    return finalize_doctor_payload(payload)


def print_doctor_payload(payload: dict[str, Any]) -> None:
    print("mdown-epub doctor")
    for check in payload["checks"]:
        print(f"[{check['level']}] {check['message']}")
        if check.get("mismatches"):
            for item in check["mismatches"]:
                print(f"  - {item['name']} expected {item['expected']}, installed {item['installed']}")


def doctor(json_output: bool) -> int:
    payload = build_doctor_payload()
    if json_output:
        print(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True))
    else:
        print_doctor_payload(payload)
    return int(payload["exit_code"])


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Create an LLM-ready EPUB textbook bundle from a trusted local EPUB.")
    parser.add_argument("epub", nargs="?", help="Trusted local EPUB path")
    parser.add_argument("-o", "--output-dir", help="Output directory. Defaults to <epub-stem>-epub-bundle")
    parser.add_argument("--profile", choices=["llm-textbook"], default="llm-textbook", help="Bundle profile")
    parser.add_argument("--force", action="store_true", help="Replace existing generated artifacts; preserve unrelated files")
    parser.add_argument("--max-input-mb", type=int, default=DEFAULT_MAX_INPUT_MB, help="Maximum EPUB archive size in MiB; use 0 to disable")
    parser.add_argument("--max-files", type=int, default=DEFAULT_MAX_FILES, help="Maximum ZIP member count; use 0 to disable")
    parser.add_argument("--max-unpacked-mb", type=int, default=DEFAULT_MAX_UNPACKED_MB, help="Maximum total uncompressed EPUB size in MiB; use 0 to disable")
    parser.add_argument("--sanitize-report", action="store_true", help="Redact local absolute paths from JSON report files")
    parser.add_argument("--doctor", action="store_true", help="Check EPUB workflow dependencies")
    parser.add_argument("--json", action="store_true", help="With --doctor, emit machine-readable output")
    return parser.parse_args(argv)


def convert_epub(args: argparse.Namespace) -> int:
    require_runtime()
    if not args.epub:
        raise SystemExit("mdown-epub: EPUB path is required unless --doctor is used")
    reject_remote(args.epub)
    epub_path = Path(args.epub).expanduser().resolve()
    if not epub_path.exists():
        raise SystemExit(f"mdown-epub: file does not exist: {epub_path}")
    if epub_path.suffix.lower() != ".epub":
        raise SystemExit("mdown-epub: LLM textbook bundle currently supports EPUB input only")
    enforce_roots(epub_path, "DOC_TO_MD_INPUT_ROOTS", "input")
    check_input_size(epub_path, args.max_input_mb)

    output_dir = Path(args.output_dir).expanduser().resolve() if args.output_dir else epub_path.with_name(f"{epub_path.stem}-epub-bundle")
    enforce_roots(output_dir, "DOC_TO_MD_OUTPUT_ROOTS", "output")
    lock_dir = acquire_output_lock(output_dir)
    staging_dir: Path | None = None

    try:
        prepare_output_dir(output_dir, args.force)
        staging_dir = make_staging_dir(output_dir)
        with ZipFile(epub_path) as zf:
            safety = check_epub_safety(zf, args.max_files, args.max_unpacked_mb)
            opf_path = find_container_rootfile(zf)
            opf = parse_opf(zf, opf_path)
            converter = EpubConverter(zf, opf, staging_dir, args.profile)
            manifest = converter.convert()
            manifest["source"] = str(epub_path)
            manifest["epub_archive"] = safety
            if args.sanitize_report:
                manifest = sanitize_value(manifest)
            write_json(staging_dir / MANIFEST_FILE, manifest)
            converter.write_report(manifest)
        publish_staged_output(staging_dir, output_dir)
        staging_dir = None
    finally:
        if staging_dir is not None and staging_dir.exists():
            remove_path(staging_dir)
        release_output_lock(lock_dir)

    print(f"LLM entrypoint: {output_dir / LLM_README}")
    print(f"markdown content: {output_dir / PRIMARY_MARKDOWN}")
    print(f"assets index: {output_dir / ASSETS_INDEX}")
    print(f"manifest: {output_dir / MANIFEST_FILE}")
    print(f"report: {output_dir / REPORT_FILE}")
    return 0


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    if args.doctor:
        return doctor(args.json)
    if args.json:
        raise SystemExit("mdown-epub: --json is only supported with --doctor")
    return convert_epub(args)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
