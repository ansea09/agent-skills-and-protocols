#!/usr/bin/env python3
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import sys
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


PYPI_URL = "https://pypi.org/pypi/markitdown/json"
GITHUB_LATEST_URL = "https://api.github.com/repos/microsoft/markitdown/releases/latest"
SIGNALS = {"no-action", "pending", "blocked", "ready-for-lane", "magika-unblocked"}


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
            "DOC_TO_MD_MAINTENANCE_STATUS",
            str(default_state_dir() / "markitdown-upstream-status.md"),
        )
    ).expanduser()


def default_state_file() -> Path:
    return Path(
        os.environ.get(
            "DOC_TO_MD_MAINTENANCE_STATE",
            str(default_state_dir() / "markitdown-upstream-state.json"),
        )
    ).expanduser()


def fetch_json(url: str, timeout: int) -> dict[str, Any]:
    try:
        import requests

        response = requests.get(url, headers={"User-Agent": "doc-to-md-markitdown-monitor/1"}, timeout=timeout)
        response.raise_for_status()
        return response.json()
    except ImportError:
        pass

    request = Request(url, headers={"User-Agent": "doc-to-md-markitdown-monitor/1"})
    with urlopen(request, timeout=timeout) as response:  # noqa: S310 - fixed public metadata endpoints.
        data = response.read()
    return json.loads(data.decode("utf-8"))


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f".{path.name}.tmp")
    tmp.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    tmp.replace(path)


def record_write_error(payload: dict[str, Any], target: Path, exc: OSError) -> None:
    payload.setdefault("errors", []).append(f"Could not write maintenance state {target}: {exc}")
    payload["write_status"] = "failed"
    payload["write_error"] = str(exc)


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
    except Exception:  # noqa: BLE001 - fallback keeps monitor dependency-free.
        return tuple(int(part) if part.isdigit() else part for part in re.split(r"([0-9]+)", version))


def compare_versions(left: str, right: str) -> int:
    left_key = version_key(left)
    right_key = version_key(right)
    if left_key == right_key:
        return 0
    return 1 if left_key > right_key else -1


def requirement_name_and_spec(requirement: str) -> tuple[str, str]:
    try:
        from packaging.requirements import Requirement

        parsed = Requirement(requirement)
        return normalize_name(parsed.name), str(parsed.specifier)
    except Exception:  # noqa: BLE001 - tolerate metadata strings without packaging.
        match = re.match(r"\s*([A-Za-z0-9_.-]+)\s*([^;]*)", requirement)
        if not match:
            return "", ""
        return normalize_name(match.group(1)), match.group(2).strip()


def spec_allows_version(specifier: str, version: str) -> bool | None:
    if not specifier:
        return True
    try:
        from packaging.specifiers import SpecifierSet

        return SpecifierSet(specifier).contains(version, prereleases=True)
    except Exception:  # noqa: BLE001 - conservative regex fallback.
        normalized = specifier.replace(" ", "")
        if "~=0." in normalized or "<1" in normalized or "==0." in normalized:
            return False
        if ">=1" in normalized or ">1" in normalized:
            return True
        return None


def python_requirement_allows_current(requires_python: str | None) -> tuple[bool | None, str]:
    if not requires_python:
        return True, "No requires_python constraint declared."
    current = ".".join(str(part) for part in sys.version_info[:3])
    try:
        from packaging.specifiers import SpecifierSet

        allowed = SpecifierSet(requires_python).contains(current, prereleases=True)
        return allowed, f"Current Python {current} {'satisfies' if allowed else 'does not satisfy'} upstream requires_python {requires_python}."
    except Exception:  # noqa: BLE001 - conservative fallback.
        return None, f"Could not evaluate upstream requires_python {requires_python} against current Python {current}."


def analyze_magika(requirements: list[str]) -> dict[str, Any]:
    matches: list[dict[str, Any]] = []
    allows_ge1 = False
    unknown = False
    for requirement in requirements:
        name, specifier = requirement_name_and_spec(requirement)
        if name != "magika":
            continue
        allowed = spec_allows_version(specifier, "1.0.0")
        if allowed is True:
            allows_ge1 = True
        elif allowed is None:
            unknown = True
        matches.append({"requirement": requirement, "specifier": specifier, "allows_1_0_0": allowed})

    if not matches:
        return {
            "requirements": [],
            "allows_ge1": True,
            "reason": "MarkItDown metadata does not declare a magika constraint.",
        }
    return {
        "requirements": matches,
        "allows_ge1": allows_ge1 and not unknown,
        "reason": "MarkItDown metadata allows magika >=1." if allows_ge1 and not unknown else "MarkItDown metadata still constrains magika below 1.x or cannot be proven compatible.",
    }


def analyze_upgrade_doc(path: Path, local_version: str | None) -> dict[str, Any]:
    if not path.is_file():
        return {"status": "missing", "stale": True, "reason": "markitdown-upgrade.md is missing."}
    text = path.read_text(encoding="utf-8")
    stale_mentions: list[str] = []
    if local_version:
        pattern = re.compile(
            rf"MarkItDown\s+{re.escape(local_version)}\s+is\s+a\s+current\s+pending\s+converter\s+upgrade",
            re.IGNORECASE,
        )
        if pattern.search(text):
            stale_mentions.append(
                f"Document still calls already-pinned MarkItDown {local_version} a current pending converter upgrade."
            )
    if stale_mentions:
        return {"status": "stale", "stale": True, "reason": " ".join(stale_mentions), "path": str(path)}
    return {"status": "current", "stale": False, "reason": "No stale current-pending candidate wording detected.", "path": str(path)}


def github_latest(payload: dict[str, Any]) -> str | None:
    tag = str(payload.get("tag_name") or payload.get("name") or "").strip()
    if not tag:
        return None
    return tag.lstrip("v")


def classify(
    *,
    local_version: str | None,
    latest_version: str | None,
    magika: dict[str, Any],
    upgrade_doc: dict[str, Any],
    upstream_errors: list[str],
    requires_python: str | None,
) -> tuple[str, list[str]]:
    reasons: list[str] = []
    if not local_version:
        return "blocked", ["requirements-core.txt does not pin markitdown."]
    if not latest_version:
        return "blocked", ["No upstream MarkItDown version could be determined.", *upstream_errors]

    cmp = compare_versions(latest_version, local_version)
    if cmp < 0:
        return "blocked", [f"Upstream latest {latest_version} is older than local pin {local_version}; metadata source may be inconsistent."]

    if upgrade_doc.get("stale"):
        reasons.append(str(upgrade_doc.get("reason") or "markitdown-upgrade.md needs maintenance."))

    if cmp == 0:
        if reasons:
            return "pending", reasons
        return "no-action", [f"Local MarkItDown pin {local_version} matches latest upstream release."]

    if requires_python:
        python_allowed, python_reason = python_requirement_allows_current(requires_python)
        reasons.append(python_reason)
        if python_allowed is False:
            return "blocked", reasons
        if python_allowed is None:
            return "blocked", reasons

    if magika.get("allows_ge1"):
        reasons.append(str(magika.get("reason")))
        return "magika-unblocked", reasons

    if upstream_errors:
        return "pending", [
            f"MarkItDown {latest_version} is newer than local pin {local_version}, but not all upstream sources were available.",
            *upstream_errors,
        ]

    reasons.append(f"MarkItDown {latest_version} is newer than local pin {local_version}; use an explicit upgrade lane.")
    reasons.append(str(magika.get("reason")))
    return "ready-for-lane", reasons


def fingerprint(payload: dict[str, Any]) -> str:
    material = {
        "signal": payload.get("signal"),
        "local_markitdown": payload.get("local", {}).get("markitdown"),
        "latest_pypi": payload.get("upstream", {}).get("pypi_version"),
        "latest_github": payload.get("upstream", {}).get("github_version"),
        "magika": payload.get("upstream", {}).get("magika"),
        "upgrade_doc": payload.get("upgrade_doc"),
    }
    return json.dumps(material, sort_keys=True, separators=(",", ":"))


def load_state(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}


def notification_policy(signal: str, current_fingerprint: str, state: dict[str, Any]) -> tuple[bool, str]:
    if signal == "no-action":
        return False, "no-action is logged only."
    decision = state.get("decision")
    decision_fingerprint = state.get("decision_fingerprint")
    last_notified = state.get("last_notified_fingerprint")
    if decision == "declined" and decision_fingerprint == current_fingerprint:
        return False, "user declined this upstream signal; repeat warning only when upstream changes."
    if last_notified == current_fingerprint:
        return False, "same actionable signal was already notified."
    return True, "new actionable maintenance signal."


def human_signal(signal: str) -> str:
    return {
        "no-action": "No action",
        "pending": "Maintenance pending",
        "blocked": "Maintenance blocked",
        "ready-for-lane": "Ready for upgrade lane",
        "magika-unblocked": "Magika 1.x unblocked upstream",
    }[signal]


def build_thread_message(payload: dict[str, Any]) -> str:
    signal = payload["signal"]
    local = payload["local"].get("markitdown") or "unknown"
    latest = payload["upstream"].get("pypi_version") or payload["upstream"].get("github_version") or "unknown"
    status_file = payload.get("status_file")
    reasons = payload.get("reasons") or []
    next_action = {
        "pending": "Review the status file and decide whether to approve a MarkItDown upgrade lane.",
        "blocked": "Do not upgrade yet. Review the blocker, then update policy or wait for upstream changes.",
        "ready-for-lane": "The automation can prepare an upgrade branch, run the source gate, and report the branch for review. Installed promotion still needs explicit approval.",
        "magika-unblocked": "The automation can prepare a dedicated MarkItDown upgrade branch. Review it before any installed promotion; do not upgrade magika alone.",
    }.get(signal, "No action is needed.")
    consequences = (
        "If you decline or postpone this update, current pinned conversions may keep working, "
        "but long-term support risk grows as upstream changes accumulate."
    )
    return "\n".join(
        [
            f"What happened: doc-to-md maintenance signal is `{signal}` ({human_signal(signal)}).",
            f"What it means: local MarkItDown is `{local}`, upstream latest is `{latest}`.",
            f"What you can do: {next_action}",
            f"Consequences: {consequences}",
            f"Status file: {status_file}",
            "Evidence: " + " ".join(str(reason) for reason in reasons[:3]),
        ]
    )


def render_status(payload: dict[str, Any]) -> str:
    local = payload["local"]
    upstream = payload["upstream"]
    lines = [
        "# doc-to-md MarkItDown Maintenance Status",
        "",
        f"- Last checked: `{payload['checked_at']}`",
        f"- Signal: `{payload['signal']}` ({human_signal(payload['signal'])})",
        f"- User notification: `{'yes' if payload['notify_user'] else 'no'}` - {payload['notify_reason']}",
        f"- Local MarkItDown pin: `{local.get('markitdown') or 'unknown'}`",
        f"- Local magika pin: `{local.get('magika') or 'unknown'}`",
        f"- PyPI latest MarkItDown: `{upstream.get('pypi_version') or 'unknown'}`",
        f"- GitHub latest MarkItDown: `{upstream.get('github_version') or 'unknown'}`",
        f"- Magika upstream status: {upstream.get('magika', {}).get('reason', 'unknown')}",
        f"- Upgrade reference status: `{payload['upgrade_doc'].get('status')}`",
        "",
        "## What Happened",
        "",
        build_thread_message(payload).split("\n", 1)[0].removeprefix("What happened: "),
        "",
        "## Reasons",
        "",
    ]
    for reason in payload.get("reasons") or []:
        lines.append(f"- {reason}")
    if payload.get("errors"):
        lines.extend(["", "## Upstream Check Warnings", ""])
        for error in payload["errors"]:
            lines.append(f"- {error}")
    lines.extend(["", "## Thread Notification", ""])
    if payload.get("notify_user"):
        lines.extend(["```text", build_thread_message(payload), "```", ""])
    else:
        lines.extend([f"No thread notification is sent: {payload['notify_reason']}", ""])
    return "\n".join(lines)


def collect(args: argparse.Namespace) -> dict[str, Any]:
    skill_dir = args.skill_dir.resolve()
    requirements_path = skill_dir / "requirements-core.txt"
    upgrade_doc_path = skill_dir / "references" / "markitdown-upgrade.md"
    pins = parse_pins(requirements_path)
    errors: list[str] = []

    if args.fixture:
        pypi = read_json(args.fixture)
    else:
        try:
            pypi = fetch_json(PYPI_URL, args.timeout)
        except (HTTPError, URLError, TimeoutError, json.JSONDecodeError, Exception) as exc:
            pypi = {}
            errors.append(f"PyPI metadata check failed: {exc}")

    github_version = None
    if not args.no_github:
        if args.github_fixture:
            github_version = github_latest(read_json(args.github_fixture))
        else:
            try:
                github_version = github_latest(fetch_json(GITHUB_LATEST_URL, args.timeout))
            except (HTTPError, URLError, TimeoutError, json.JSONDecodeError, Exception) as exc:
                errors.append(f"GitHub latest-release check failed: {exc}")

    info = pypi.get("info") or {}
    latest_version = str(info.get("version") or "").strip() or None
    requires_dist = [str(item) for item in (info.get("requires_dist") or [])]
    requires_python = str(info.get("requires_python") or "").strip() or None
    magika = analyze_magika(requires_dist)
    upgrade_doc = analyze_upgrade_doc(upgrade_doc_path, pins.get("markitdown"))
    signal, reasons = classify(
        local_version=pins.get("markitdown"),
        latest_version=latest_version,
        magika=magika,
        upgrade_doc=upgrade_doc,
        upstream_errors=errors,
        requires_python=requires_python,
    )
    if signal not in SIGNALS:
        raise RuntimeError(f"invalid maintenance signal: {signal}")

    payload: dict[str, Any] = {
        "tool": "doc-to-md-markitdown-upstream-monitor",
        "checked_at": utc_now(),
        "signal": signal,
        "reasons": reasons,
        "errors": errors,
        "local": {"markitdown": pins.get("markitdown"), "magika": pins.get("magika"), "requirements": str(requirements_path)},
        "upstream": {
            "pypi_version": latest_version,
            "github_version": github_version,
            "requires_python": requires_python,
            "requires_dist": requires_dist,
            "magika": magika,
        },
        "upgrade_doc": upgrade_doc,
    }
    current_fingerprint = fingerprint(payload)
    state = load_state(args.state_file)
    notify_user, notify_reason = notification_policy(signal, current_fingerprint, state)
    payload["fingerprint"] = current_fingerprint
    payload["notify_user"] = notify_user
    payload["notify_reason"] = notify_reason
    payload["status_file"] = str(args.status_file)
    payload["state_file"] = str(args.state_file)
    payload["thread_message"] = build_thread_message(payload) if notify_user else ""
    return payload


def update_state(path: Path, payload: dict[str, Any], decision: str | None = None) -> None:
    state = load_state(path)
    state.update(
        {
            "last_checked_at": payload["checked_at"],
            "last_signal": payload["signal"],
            "last_fingerprint": payload["fingerprint"],
        }
    )
    if payload.get("notify_user"):
        state["last_notified_fingerprint"] = payload["fingerprint"]
        state["last_notified_at"] = payload["checked_at"]
    if decision:
        state["decision"] = decision
        state["decision_fingerprint"] = payload["fingerprint"]
        state["decision_recorded_at"] = payload["checked_at"]
    write_json(path, state)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Check upstream MarkItDown maintenance status for doc-to-md.")
    parser.add_argument("--skill-dir", type=Path, default=skill_dir_default())
    parser.add_argument("--status-file", type=Path, default=default_status_file())
    parser.add_argument("--state-file", type=Path, default=default_state_file())
    parser.add_argument("--fixture", type=Path, help="Use a local PyPI JSON fixture instead of network.")
    parser.add_argument("--github-fixture", type=Path, help="Use a local GitHub release JSON fixture instead of network.")
    parser.add_argument("--no-github", action="store_true", help="Skip GitHub latest-release metadata.")
    parser.add_argument("--timeout", type=int, default=20)
    parser.add_argument("--json", action="store_true", help="Print the machine-readable payload.")
    parser.add_argument("--no-write-status", action="store_true", help="Do not write the Markdown status file or state file.")
    parser.add_argument("--no-write", dest="no_write_status", action="store_true", help="Alias for --no-write-status.")
    parser.add_argument(
        "--record-decision",
        choices=["approved", "declined", "clear"],
        help="Record the user's decision for the current upstream fingerprint.",
    )
    args = parser.parse_args(argv)

    payload = collect(args)
    decision = None if args.record_decision == "clear" else args.record_decision
    write_ok = True
    if args.record_decision == "clear":
        if args.no_write_status:
            payload.setdefault("errors", []).append("--record-decision clear was requested with --no-write; no decision state changed.")
            payload["write_status"] = "skipped"
            write_ok = False
        else:
            try:
                state = load_state(args.state_file)
                state.pop("decision", None)
                state.pop("decision_fingerprint", None)
                state.pop("decision_recorded_at", None)
                write_json(args.state_file, state)
                payload["write_status"] = "ok"
            except OSError as exc:
                record_write_error(payload, args.state_file, exc)
                write_ok = False
    elif not args.no_write_status:
        try:
            args.status_file.parent.mkdir(parents=True, exist_ok=True)
            args.status_file.write_text(render_status(payload), encoding="utf-8")
            update_state(args.state_file, payload, decision)
            payload["write_status"] = "ok"
        except OSError as exc:
            record_write_error(payload, args.status_file, exc)
            write_ok = False
    else:
        payload["write_status"] = "skipped"

    if args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
    else:
        print(f"signal={payload['signal']}")
        print(f"notify_user={'yes' if payload['notify_user'] else 'no'}")
        print(f"status_file={payload['status_file']}")
        if payload["signal"] != "no-action":
            print()
            print(payload["thread_message"])
        if args.record_decision == "declined":
            print()
            print(
                "Support risk warning: current pinned conversions may keep working, "
                "but support risk grows if MarkItDown updates are repeatedly declined."
            )
        if args.record_decision == "approved":
            print()
            print("Approval recorded. Start the explicit upgrade lane from references/markitdown-upgrade.md.")
    return 0 if write_ok or not args.record_decision else 1


if __name__ == "__main__":
    raise SystemExit(main())
