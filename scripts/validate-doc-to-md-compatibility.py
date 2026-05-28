#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re
import sys


def unquote(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
        return value[1:-1]
    return value


def frontmatter(text: str, path: Path) -> str:
    lines = text.splitlines()
    if not lines or lines[0] != "---":
        raise ValueError(f"{path} must start with YAML frontmatter")
    for index, line in enumerate(lines[1:], start=1):
        if line == "---":
            return "\n".join(lines[1:index])
    raise ValueError(f"{path} frontmatter is not closed")


def parse_compatibility(block: str) -> dict[str, object]:
    compatibility: dict[str, object] = {}
    in_compat = False
    current_list: str | None = None

    for line in block.splitlines():
        if line == "compatibility:":
            in_compat = True
            current_list = None
            continue
        if not in_compat:
            continue
        if line and not line.startswith(" "):
            break

        key_match = re.match(r"^  ([A-Za-z_][A-Za-z0-9_]*):(.*)$", line)
        if key_match:
            key = key_match.group(1)
            raw_value = key_match.group(2).strip()
            if raw_value:
                compatibility[key] = unquote(raw_value)
                current_list = None
            else:
                compatibility[key] = []
                current_list = key
            continue

        list_match = re.match(r"^    -\s+(.*)$", line)
        if list_match and current_list:
            values = compatibility.setdefault(current_list, [])
            if not isinstance(values, list):
                raise ValueError(f"compatibility.{current_list} mixes scalar and list values")
            values.append(unquote(list_match.group(1)))

    return compatibility


def canonical_environment(value: str) -> str:
    value = value.split(" when ", 1)[0].strip()
    replacements = {
        "Codex on macOS, arm64": "Codex on macOS arm64",
        "Codex on macOS, Intel": "Codex on Intel macOS",
        "Native Windows PowerShell/CMD": "native Windows PowerShell/CMD",
    }
    return replacements.get(value, value)


def parse_support_matrix(path: Path) -> dict[str, str]:
    matrix: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line.startswith("|") or "---" in line:
            continue
        cells = [cell.strip() for cell in line.strip("|").split("|")]
        if len(cells) < 3 or cells[0] == "Environment":
            continue
        environment = canonical_environment(cells[0]).lower()
        status = cells[1].lower()
        matrix[environment] = status
    return matrix


def require_status(
    errors: list[str],
    matrix: dict[str, str],
    key: str,
    values: object,
    expected_status: str,
) -> None:
    if isinstance(values, str):
        candidates = [values]
    elif isinstance(values, list):
        candidates = [str(value) for value in values]
    else:
        errors.append(f"compatibility.{key} is missing or has unsupported type")
        return

    if not candidates:
        errors.append(f"compatibility.{key} must not be empty")
        return

    for value in candidates:
        environment = canonical_environment(value)
        actual = matrix.get(environment.lower())
        if actual != expected_status:
            errors.append(
                f"compatibility.{key} value {value!r} must match support-matrix status "
                f"{expected_status!r}; found {actual or 'missing'}"
            )


def require_optional_status(
    errors: list[str],
    matrix: dict[str, str],
    key: str,
    values: object,
    expected_status: str,
) -> None:
    if values is None:
        return
    require_status(errors, matrix, key, values, expected_status)


def parse_hash_profiles(values: object, errors: list[str]) -> dict[str, list[str]]:
    if not isinstance(values, list) or not values:
        errors.append("compatibility.hash_profiles must list maintained hash profiles")
        return {}

    profiles: dict[str, list[str]] = {}
    valid_components = {"core", "book", "ocr"}
    for raw_value in values:
        value = str(raw_value)
        if ":" not in value:
            errors.append(f"compatibility.hash_profiles value {value!r} must use 'profile: components'")
            continue
        profile, raw_components = value.split(":", 1)
        profile = profile.strip()
        if not re.match(r"^[a-z0-9][a-z0-9_.+-]*-py[0-9]{2,3}$", profile):
            errors.append(f"compatibility.hash_profiles profile {profile!r} must include a Python tag like py313")
            continue
        components = [component.strip().lower() for component in raw_components.split(",") if component.strip()]
        if not components:
            errors.append(f"compatibility.hash_profiles profile {profile!r} has no components")
            continue
        unknown = [component for component in components if component not in valid_components]
        if unknown:
            errors.append(
                f"compatibility.hash_profiles profile {profile!r} has unsupported components: "
                f"{', '.join(unknown)}"
            )
            continue
        profiles[profile] = components
    return profiles


def require_hash_profile_files(
    errors: list[str],
    skill_dir: Path,
    profile_register: Path,
    profiles: dict[str, list[str]],
) -> None:
    register_text = profile_register.read_text(encoding="utf-8") if profile_register.is_file() else ""
    for profile, components in profiles.items():
        if profile not in register_text:
            errors.append(f"hash profile {profile!r} must be documented in references/python-profiles.md")
        for component in components:
            path = skill_dir / f"requirements-{component}.{profile}.hashes.txt"
            if not path.is_file():
                errors.append(f"hash profile {profile!r} is missing {path.name}")


def main(argv: list[str]) -> int:
    repo_root = Path(__file__).resolve().parents[1]
    skill_dir = Path(argv[1]) if len(argv) > 1 else repo_root / "skills" / "doc-to-md"
    skill_md = skill_dir / "SKILL.md"
    support_matrix = skill_dir / "references" / "support-matrix.md"
    profile_register = skill_dir / "references" / "python-profiles.md"

    errors: list[str] = []
    if not skill_md.is_file():
        errors.append(f"missing {skill_md}")
    if not support_matrix.is_file():
        errors.append(f"missing {support_matrix}")
    if not profile_register.is_file():
        errors.append(f"missing {profile_register}")
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    try:
        compat = parse_compatibility(frontmatter(skill_md.read_text(encoding="utf-8"), skill_md))
        matrix = parse_support_matrix(support_matrix)
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    if compat.get("canonical_reference") != "references/support-matrix.md":
        errors.append("compatibility.canonical_reference must be references/support-matrix.md")

    require_status(errors, matrix, "primary_runtime", compat.get("primary_runtime"), "supported")
    require_optional_status(errors, matrix, "supported_runtimes", compat.get("supported_runtimes"), "supported")
    require_status(errors, matrix, "candidate_runtimes", compat.get("candidate_runtimes"), "candidate")
    require_status(errors, matrix, "experimental_runtimes", compat.get("experimental_runtimes"), "experimental")
    require_status(errors, matrix, "unsupported_runtimes", compat.get("unsupported_runtimes"), "unsupported")
    if "Python minor version" not in str(compat.get("python_profile_policy", "")):
        errors.append("compatibility.python_profile_policy must state the Python minor version boundary")

    profiles = parse_hash_profiles(compat.get("hash_profiles"), errors)
    require_hash_profile_files(errors, skill_dir, profile_register, profiles)

    if errors:
        for error in errors:
            print(f"ERROR: doc-to-md compatibility drift: {error}", file=sys.stderr)
        return 1

    print("OK: doc-to-md compatibility frontmatter matches support-matrix.md")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
