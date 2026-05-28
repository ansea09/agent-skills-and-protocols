#!/usr/bin/env python3
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
from typing import Any
from urllib.request import Request, urlopen


PYPI_URL = "https://pypi.org/pypi/{package}/json"
DEFAULT_PACKAGES = [
    ("pdfminer.six", "core-pdf", "requirements-core.txt"),
    ("pdfplumber", "core-pdf", "requirements-core.txt"),
    ("pypdfium2", "core-pdf", "requirements-core.txt"),
    ("PyMuPDF", "book", "requirements-book.txt"),
    ("ocrmypdf", "ocr", "requirements-ocr.lock.txt"),
    ("pikepdf", "ocr", "requirements-ocr.lock.txt"),
    ("pypdfium2", "ocr", "requirements-ocr.lock.txt"),
]


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def normalize_name(name: str) -> str:
    return re.sub(r"[-_.]+", "-", name).lower()


def skill_dir_default() -> Path:
    return Path(__file__).resolve().parents[1]


def codex_home() -> Path:
    return Path(os.environ.get("CODEX_HOME", str(Path.home() / ".codex"))).expanduser()


def default_state_dir() -> Path:
    return Path(os.environ.get("DOC_TO_MD_STATE_DIR", str(codex_home() / "state" / "doc-to-md"))).expanduser()


def default_status_file() -> Path:
    return Path(
        os.environ.get(
            "DOC_TO_MD_DEPENDENCY_STATUS",
            str(default_state_dir() / "dependency-maintenance-status.md"),
        )
    ).expanduser()


def default_state_file() -> Path:
    return Path(
        os.environ.get(
            "DOC_TO_MD_DEPENDENCY_STATE",
            str(default_state_dir() / "dependency-maintenance-state.json"),
        )
    ).expanduser()


def parse_pins(path: Path) -> dict[str, str]:
    pins: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip().rstrip("\\").strip()
        if not line or line.startswith("#") or line.startswith("--hash="):
            continue
        match = re.match(r"([A-Za-z0-9_.-]+)==([^;#\s\\]+)", line)
        if match:
            pins[normalize_name(match.group(1))] = match.group(2)
    return pins


def version_key(version: str) -> Any:
    try:
        from packaging.version import Version

        return Version(version)
    except Exception:  # noqa: BLE001 - fallback keeps monitor dependency-light.
        return tuple(int(part) if part.isdigit() else part for part in re.split(r"([0-9]+)", version))


def compare_versions(left: str, right: str) -> int:
    left_key = version_key(left)
    right_key = version_key(right)
    if left_key == right_key:
        return 0
    return 1 if left_key > right_key else -1


def fetch_json(url: str, timeout: int) -> dict[str, Any]:
    try:
        import requests

        response = requests.get(url, headers={"User-Agent": "doc-to-md-dependency-monitor/1"}, timeout=timeout)
        response.raise_for_status()
        return response.json()
    except ImportError:
        pass

    request = Request(url, headers={"User-Agent": "doc-to-md-dependency-monitor/1"})
    with urlopen(request, timeout=timeout) as response:  # noqa: S310 - fixed public metadata endpoint.
        return json.loads(response.read().decode("utf-8"))


def read_package_metadata(package: str, *, fixture_dir: Path | None, timeout: int) -> dict[str, Any]:
    normalized = normalize_name(package)
    if fixture_dir is not None:
        fixture = fixture_dir / f"{normalized}.json"
        if not fixture.is_file():
            raise FileNotFoundError(f"fixture not found for {package}: {fixture}")
        return json.loads(fixture.read_text(encoding="utf-8"))
    return fetch_json(PYPI_URL.format(package=package), timeout)


def selected_package_specs(args: argparse.Namespace) -> list[tuple[str, str, str]]:
    if not args.packages:
        return DEFAULT_PACKAGES
    requested = {normalize_name(item) for item in args.packages.split(",") if item.strip()}
    return [spec for spec in DEFAULT_PACKAGES if normalize_name(spec[0]) in requested]


def read_state(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f".{path.name}.tmp")
    tmp.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    tmp.replace(path)


def classify(items: list[dict[str, Any]], errors: list[str]) -> str:
    if errors:
        return "blocked"
    if any(item.get("status") == "newer-available" for item in items):
        return "pending"
    return "no-action"


def render_status(payload: dict[str, Any]) -> str:
    lines = [
        "# doc-to-md Dependency Maintenance Status",
        "",
        f"- Checked at: `{payload['checked_at']}`",
        f"- Signal: `{payload['signal']}`",
        f"- Notify user: `{'yes' if payload['notify_user'] else 'no'}`",
        f"- Status file: `{payload['status_file']}`",
        f"- State file: `{payload['state_file']}`",
        "",
        "## Monitored Packages",
        "",
        "| Package | Group | Local | Latest | Status |",
        "| --- | --- | --- | --- | --- |",
    ]
    for item in payload["items"]:
        lines.append(
            f"| `{item['package']}` | `{item['group']}` | `{item.get('local_version') or 'unknown'}` | "
            f"`{item.get('latest_version') or 'unknown'}` | `{item['status']}` |"
        )
    if payload.get("errors"):
        lines.extend(["", "## Errors", ""])
        for error in payload["errors"]:
            lines.append(f"- {error}")
    if payload.get("thread_message"):
        lines.extend(["", "## Notification", "", payload["thread_message"]])
    lines.append("")
    return "\n".join(lines)


def build_thread_message(payload: dict[str, Any]) -> str:
    signal = payload["signal"]
    if signal == "no-action":
        return ""
    updates = [
        f"{item['package']} {item.get('local_version') or 'unknown'} -> {item.get('latest_version') or 'unknown'}"
        for item in payload["items"]
        if item.get("status") == "newer-available"
    ]
    if signal == "pending":
        return "\n".join(
            [
                "What happened: doc-to-md dependency maintenance signal is `pending`.",
                "What it means: one or more monitored PDF/OCR dependencies have newer upstream releases.",
                "What you can do: review the dependency report, then run the explicit lock refresh lane if the update is worth testing.",
                "Consequences: current pinned conversions remain reproducible, but support risk grows if OCR/PDF drift accumulates.",
                f"Status file: {payload['status_file']}",
                f"Evidence: {', '.join(updates)}.",
            ]
        )
    return "\n".join(
        [
            "What happened: doc-to-md dependency maintenance signal is `blocked`.",
            "What it means: the monitor could not prove the current PDF/OCR dependency state.",
            "What you can do: inspect the status file and rerun the monitor when package metadata is available.",
            "Consequences: do not refresh locks from incomplete evidence.",
            f"Status file: {payload['status_file']}",
            f"Evidence: {' '.join(payload.get('errors') or ['unknown blocker'])}",
        ]
    )


def collect(args: argparse.Namespace) -> dict[str, Any]:
    skill_dir = args.skill_dir.resolve()
    pins_by_file: dict[str, dict[str, str]] = {}
    items: list[dict[str, Any]] = []
    errors: list[str] = []
    for package, group, requirement_file in selected_package_specs(args):
        path = skill_dir / requirement_file
        if requirement_file not in pins_by_file:
            try:
                pins_by_file[requirement_file] = parse_pins(path)
            except OSError as exc:
                pins_by_file[requirement_file] = {}
                errors.append(f"Could not read {requirement_file}: {exc}")
        local_version = pins_by_file[requirement_file].get(normalize_name(package))
        item: dict[str, Any] = {
            "package": package,
            "group": group,
            "requirements": str(path),
            "local_version": local_version,
            "latest_version": None,
            "status": "unknown",
        }
        if not local_version:
            item["status"] = "missing-pin"
            errors.append(f"{package} is not pinned in {requirement_file}.")
            items.append(item)
            continue
        try:
            metadata = read_package_metadata(package, fixture_dir=args.fixture_dir, timeout=args.timeout)
            latest_version = str(metadata.get("info", {}).get("version") or "").strip()
            item["latest_version"] = latest_version or None
            if not latest_version:
                item["status"] = "unknown"
                errors.append(f"{package} metadata did not include a latest version.")
            elif compare_versions(latest_version, local_version) > 0:
                item["status"] = "newer-available"
            elif compare_versions(latest_version, local_version) < 0:
                item["status"] = "local-ahead"
            else:
                item["status"] = "current"
        except Exception as exc:  # noqa: BLE001 - metadata fetch errors are evidence.
            item["status"] = "metadata-error"
            errors.append(f"{package} metadata check failed: {exc}")
        items.append(item)

    signal = classify(items, errors)
    fingerprint = json.dumps(
        [{"package": item["package"], "local": item.get("local_version"), "latest": item.get("latest_version"), "status": item["status"]} for item in items],
        sort_keys=True,
    )
    state = read_state(args.state_file)
    notify_user = signal != "no-action" and state.get("last_notified_fingerprint") != fingerprint
    payload: dict[str, Any] = {
        "tool": "doc-to-md-dependency-maintenance-monitor",
        "checked_at": utc_now(),
        "signal": signal,
        "notify_user": notify_user,
        "notify_reason": "no-action is logged only." if signal == "no-action" else "new actionable dependency maintenance signal.",
        "fingerprint": fingerprint,
        "status_file": str(args.status_file),
        "state_file": str(args.state_file),
        "items": items,
        "errors": errors,
    }
    payload["thread_message"] = build_thread_message(payload)
    return payload


def update_state(path: Path, payload: dict[str, Any]) -> None:
    state = read_state(path)
    state["last_checked_at"] = payload["checked_at"]
    state["last_fingerprint"] = payload["fingerprint"]
    state["last_signal"] = payload["signal"]
    if payload.get("notify_user"):
        state["last_notified_fingerprint"] = payload["fingerprint"]
        state["last_notified_at"] = payload["checked_at"]
    write_json(path, state)


def write_outputs(args: argparse.Namespace, payload: dict[str, Any]) -> None:
    if args.no_write:
        payload["write_status"] = "skipped"
        return
    try:
        args.status_file.parent.mkdir(parents=True, exist_ok=True)
        args.status_file.write_text(render_status(payload), encoding="utf-8")
        update_state(args.state_file, payload)
        payload["write_status"] = "ok"
    except OSError as exc:
        payload.setdefault("errors", []).append(f"Could not write dependency maintenance state {args.status_file}: {exc}")
        payload["write_status"] = "failed"
        payload["write_error"] = str(exc)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Check PDF/OCR dependency maintenance status for doc-to-md.")
    parser.add_argument("--skill-dir", type=Path, default=skill_dir_default())
    parser.add_argument("--status-file", type=Path, default=default_status_file())
    parser.add_argument("--state-file", type=Path, default=default_state_file())
    parser.add_argument("--fixture-dir", type=Path, help="Directory with normalized PyPI JSON fixtures.")
    parser.add_argument("--packages", help="Comma-separated package names to check; default checks PDF/OCR maintenance packages.")
    parser.add_argument("--timeout", type=int, default=20)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--no-write-status", dest="no_write", action="store_true", help="Do not write status/state files.")
    parser.add_argument("--no-write", dest="no_write", action="store_true", help="Alias for --no-write-status.")
    args = parser.parse_args(argv)

    payload = collect(args)
    write_outputs(args, payload)
    if args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
    else:
        print(f"signal={payload['signal']}")
        print(f"notify_user={'yes' if payload['notify_user'] else 'no'}")
        print(f"status_file={payload['status_file']}")
        if payload["thread_message"]:
            print()
            print(payload["thread_message"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
