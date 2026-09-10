#!/usr/bin/env python3
"""Release-only Agent Skills format check using the pinned reference library."""
import argparse
import importlib.metadata as metadata
import json
from pathlib import Path
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    requirements = root / "scripts/requirements-skill-validation.txt"
    try:
        for line in requirements.read_text().splitlines():
            if "==" in line and not line.startswith("#"):
                name, version = line.split("==")
                if metadata.version(name) != version:
                    raise ValueError(f"wrong version of {name}; expected {version}")
            elif line.startswith("skills-ref @ git+"):
                expected = line.split(".git@", 1)[1].split("#", 1)[0]
                provenance = json.loads(metadata.distribution("skills-ref").read_text("direct_url.json") or "{}")
                if provenance.get("vcs_info", {}).get("commit_id") != expected:
                    raise ValueError("skills-ref does not match the pinned Git commit")
        from skills_ref import validate
    except (ImportError, metadata.PackageNotFoundError, ValueError) as error:
        print(f"ERROR: validation toolchain unavailable or mismatched: {error}")
        print(f"Install {requirements} in a Python 3.11+ development venv; no auto-install performed.")
        return 2
    paths = [root / p for p in (
        "skills/fpf-work-guide", "plugins/fpf-work-guide/skills/fpf-work-guide",
        "claude-code/fpf-work-guide",
    )]
    failed = False
    for path in paths:
        errors = validate(path)
        print(f"{path.relative_to(root)}: " + ("; ".join(errors) if errors else "format valid"))
        failed = failed or bool(errors)
    if args.self_test:
        with tempfile.TemporaryDirectory(prefix="skill-format-") as tmp:
            skill = Path(tmp) / "example"
            skill.mkdir()
            prefix = "---\nname: example\ndescription: Format fixture.\n"
            cases = (("compatibility: Requires Bash\n", False),
                     ("compatibility:\n  runtime: Bash\n", True),
                     ("compatibility: " + "x" * 501 + "\n", True),
                     ("unknown_field: value\n", True))
            for content, must_fail in cases:
                (skill / "SKILL.md").write_text(prefix + content + "---\n# Example\n")
                if bool(validate(skill)) != must_fail:
                    raise RuntimeError(f"reference validator regression: {content[:60]}")
        print("Format self-test passed: valid string, object, length, unknown field.")
    print("Format validation does not establish runtime compatibility or answer correctness.")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
