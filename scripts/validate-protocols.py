#!/usr/bin/env python3
"""Check protocol packaging/links, not YAML semantics or answer quality."""

import argparse
from pathlib import Path
import re
import shutil
import tempfile
from urllib.parse import unquote, urlsplit


REQUIRED = (
    "protocols/00-definitions.md",
    "protocols/01-classification.md",
    "protocols/02-routing-table.md",
    "protocols/03-pattern-use.md",
    "protocols/04-source-fidelity.md",
    "protocols/checklists/simple-medium.md",
    "protocols/checklists/complex/00-master.md",
    "protocols/templates/protocol-execution-record.yaml",
    "protocols/templates/source-fidelity-observation.yaml",
    "protocols/regressions/source-condition-attribution.md",
)


def inside(root, path):
    return path.resolve().is_relative_to(root.resolve())


def validate(root):
    errors = []
    for name in ("registry.yaml",) + REQUIRED:
        path = root / name
        if not inside(root, path) or not path.is_file():
            errors.append(f"missing or unsafe required file: {name}")
    if errors:
        return errors
    registry = (root / "registry.yaml").read_text(encoding="utf-8")
    if not re.search(r'^protocol_revision: [\"\']2\.0[\"\']\s*$', registry, re.M):
        errors.append("expected protocol_revision: \"2.0\" in registry.yaml")
    # Check this repository's plain path scalars, not arbitrary YAML semantics.
    for name in re.findall(r"^\s+\w+: (protocols/[^\s]+)\s*$", registry, re.M):
        path = root / name
        if ".." in Path(name).parts or not inside(root, path) or not path.is_file():
            errors.append(f"missing or unsafe registry target: {name}")
    for path in sorted((root / "protocols").rglob("*.md")):
        if not inside(root, path):
            errors.append(f"protocol symlink escapes repository: {path.name}")
            continue
        for target in re.findall(r"\]\(([^\s)]+)\)", path.read_text(encoding="utf-8")):
            url = urlsplit(target)
            if url.scheme or url.netloc or not url.path:
                continue
            linked = path.parent / unquote(url.path)
            if not inside(root, linked) or not linked.exists():
                errors.append(f"{path.relative_to(root)}: broken/unsafe link {target}")
    return errors


def self_test(root):
    with tempfile.TemporaryDirectory(prefix="fpf-protocol-check-") as tmp:
        fixture = Path(tmp) / "repo"
        fixture.mkdir()
        shutil.copy(root / "registry.yaml", fixture)
        shutil.copytree(root / "protocols", fixture / "protocols")
        shutil.copytree(root / "docs", fixture / "docs")
        assert not validate(fixture), validate(fixture)
        required = fixture / REQUIRED[3]
        original = required.read_text(encoding="utf-8")
        required.unlink()
        assert validate(fixture), "missing required file accepted"
        required.write_text(original + "\n[broken](absent.md)\n", encoding="utf-8")
        assert validate(fixture), "broken link accepted"
        required.unlink()
        required.symlink_to(root / REQUIRED[3])
        assert validate(fixture), "symlink escape accepted"
    print("Protocol validator self-test passed (valid/missing/link/escape).")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", nargs="?", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    errors = validate(args.root)
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    if args.self_test:
        self_test(args.root)
    print("Protocol artifact checks passed; no semantic grading was performed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
