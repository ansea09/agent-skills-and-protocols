#!/usr/bin/env python3
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

import markitdown_upstream_monitor as monitor


AUTO_PREPARE_SIGNALS = {"ready-for-lane", "magika-unblocked"}


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def run(command: list[str], *, cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)


def git_output(repo_root: Path, *args: str) -> str:
    proc = run(["git", *args], cwd=repo_root)
    if proc.returncode != 0:
        raise RuntimeError(proc.stdout.strip() or f"git {' '.join(args)} failed")
    return proc.stdout.strip()


def repo_default(skill_dir: Path) -> Path:
    resolved = skill_dir.resolve()
    try:
        return resolved.parents[1]
    except IndexError as exc:
        raise SystemExit(f"cannot infer repository root from skill dir: {skill_dir}") from exc


def safe_version(version: str) -> str:
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", version):
        raise ValueError(f"unsafe version for branch name: {version}")
    return version.replace("_", "-")


def report_path_default() -> Path:
    return monitor.default_state_dir() / "markitdown-auto-prepare-report.md"


def write_report(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "# doc-to-md MarkItDown Auto-Prepare Report",
        "",
        f"- Prepared at: `{payload['prepared_at']}`",
        f"- Action status: `{payload['action_status']}`",
        f"- Signal: `{payload['monitor']['signal']}`",
        f"- Local MarkItDown: `{payload['monitor']['local'].get('markitdown') or 'unknown'}`",
        f"- Upstream MarkItDown: `{payload.get('target_version') or 'unknown'}`",
        f"- Branch: `{payload.get('branch') or 'none'}`",
        f"- Installed promotion: `not-run`",
        "",
        "## Summary",
        "",
        payload.get("summary", ""),
        "",
    ]
    if payload.get("commands"):
        lines.extend(["## Commands", ""])
        for item in payload["commands"]:
            lines.append(f"- `{item['command']}` -> `{item['status']}`")
        lines.append("")
    if payload.get("git_status"):
        lines.extend(["## Git Status", "", "```text", payload["git_status"], "```", ""])
    if payload.get("git_diff_stat"):
        lines.extend(["## Git Diff Stat", "", "```text", payload["git_diff_stat"], "```", ""])
    if payload.get("errors"):
        lines.extend(["## Errors", ""])
        for error in payload["errors"]:
            lines.append(f"- {error}")
        lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")


def automation_output(payload: dict[str, Any]) -> str:
    action_status = payload["action_status"]
    if action_status == "not-needed":
        return ""

    monitor_payload = payload["monitor"]
    signal = monitor_payload["signal"]
    target_version = payload.get("target_version") or "unknown"
    report_file = payload.get("report_file") or "unknown"
    branch = payload.get("branch") or "none"
    lines = [
        f"What happened: doc-to-md MarkItDown auto-prepare status is `{action_status}`.",
        f"What it means: monitor signal is `{signal}`, target MarkItDown is `{target_version}`, branch is `{branch}`.",
        f"What you can do: review the report at `{report_file}`.",
        "Consequences: installed doc-to-md was not promoted or changed.",
    ]
    if action_status == "prepared":
        lines.append("Next step: review the branch diff and source gate output; installed promotion still requires explicit approval.")
    elif action_status == "blocked":
        lines.append("Next step: resolve the blocker before an upgrade branch can be prepared.")
    elif action_status == "not-prepared":
        lines.append("Next step: wait for a ready-for-lane or magika-unblocked signal, or inspect the status file manually.")
    elif action_status in {"prepare-failed", "gate-failed"}:
        lines.append("Next step: inspect the failed command output in the report; installed promotion is blocked.")
    summary = payload.get("summary")
    if summary:
        lines.append(f"Evidence: {summary}")
    return "\n".join(lines)


def collect_monitor(args: argparse.Namespace) -> dict[str, Any]:
    monitor_args = argparse.Namespace(
        skill_dir=args.skill_dir,
        status_file=args.status_file,
        state_file=args.state_file,
        fixture=args.fixture,
        github_fixture=args.github_fixture,
        no_github=args.no_github,
        timeout=args.timeout,
    )
    payload = monitor.collect(monitor_args)
    if not args.no_write_status:
        try:
            args.status_file.parent.mkdir(parents=True, exist_ok=True)
            args.status_file.write_text(monitor.render_status(payload), encoding="utf-8")
            monitor.update_state(args.state_file, payload)
            payload["write_status"] = "ok"
        except OSError as exc:
            monitor.record_write_error(payload, args.status_file, exc)
    else:
        payload["write_status"] = "skipped"
    return payload


def add_command(payload: dict[str, Any], command: list[str], proc: subprocess.CompletedProcess[str]) -> None:
    payload.setdefault("commands", []).append(
        {
            "command": " ".join(command),
            "status": "ok" if proc.returncode == 0 else f"failed:{proc.returncode}",
            "output_tail": "\n".join((proc.stdout or "").splitlines()[-80:]),
        }
    )


def prepare(args: argparse.Namespace) -> dict[str, Any]:
    monitor_payload = collect_monitor(args)
    repo_root = args.repo_root.resolve()
    target_version = monitor_payload["upstream"].get("pypi_version") or monitor_payload["upstream"].get("github_version")
    payload: dict[str, Any] = {
        "tool": "doc-to-md-markitdown-auto-prepare",
        "prepared_at": utc_now(),
        "monitor": monitor_payload,
        "target_version": target_version,
        "action_status": "not-needed",
        "branch": None,
        "commands": [],
        "errors": [],
        "installed_promotion": "not-run",
        "report_file": str(args.report_file),
    }

    signal = monitor_payload["signal"]
    if signal == "no-action":
        payload["summary"] = "No upgrade branch was prepared because the local MarkItDown pin already matches upstream."
        return payload
    if signal not in AUTO_PREPARE_SIGNALS:
        payload["action_status"] = "not-prepared"
        payload["summary"] = f"No upgrade branch was prepared because signal `{signal}` is not an auto-prepare signal."
        return payload
    if not target_version:
        payload["action_status"] = "blocked"
        payload["errors"].append("No target MarkItDown version was available.")
        payload["summary"] = "Auto-prepare is blocked because no target version was available."
        return payload

    try:
        git_status = git_output(repo_root, "status", "--porcelain")
    except RuntimeError as exc:
        payload["action_status"] = "blocked"
        payload["errors"].append(str(exc))
        payload["summary"] = "Auto-prepare is blocked because repository status could not be checked."
        return payload
    if git_status:
        payload["action_status"] = "blocked"
        payload["git_status"] = git_status
        payload["summary"] = "Auto-prepare is blocked because the repository worktree is not clean."
        return payload

    version_slug = safe_version(str(target_version))
    branch = f"codex/doc-to-md-markitdown-{version_slug}"
    payload["branch"] = branch
    existing = run(["git", "rev-parse", "--verify", "--quiet", branch], cwd=repo_root)
    if existing.returncode == 0:
        payload["action_status"] = "blocked"
        payload["errors"].append(f"Branch already exists: {branch}")
        payload["summary"] = "Auto-prepare is blocked because the target branch already exists."
        return payload

    command = ["git", "switch", "-c", branch]
    proc = run(command, cwd=repo_root)
    add_command(payload, command, proc)
    if proc.returncode != 0:
        payload["action_status"] = "prepare-failed"
        payload["errors"].append(proc.stdout.strip())
        payload["summary"] = "Auto-prepare failed while creating the upgrade branch."
        return payload

    refresh = [
        sys.executable,
        str(args.skill_dir / "scripts" / "refresh-locks.py"),
        "--core-markitdown",
        "--markitdown-spec",
        f"markitdown=={target_version}",
        "--apply",
    ]
    proc = run(refresh, cwd=repo_root)
    add_command(payload, refresh, proc)
    if proc.returncode != 0:
        payload["action_status"] = "prepare-failed"
        payload["errors"].append("MarkItDown lock refresh failed.")
        payload["summary"] = "Auto-prepare failed while refreshing MarkItDown pins."
        payload["git_status"] = run(["git", "status", "--short"], cwd=repo_root).stdout.strip()
        return payload

    if not args.skip_gate:
        gate = [str(repo_root / "scripts" / "validate-doc-to-md-release.sh"), "--source"]
        proc = run(gate, cwd=repo_root)
        add_command(payload, gate, proc)
        if proc.returncode != 0:
            payload["action_status"] = "gate-failed"
            payload["errors"].append("Source release gate failed.")
            payload["summary"] = "Upgrade branch was created, but the source release gate failed. Installed promotion is blocked."
            payload["git_status"] = run(["git", "status", "--short"], cwd=repo_root).stdout.strip()
            payload["git_diff_stat"] = run(["git", "diff", "--stat"], cwd=repo_root).stdout.strip()
            return payload

    payload["action_status"] = "prepared"
    payload["summary"] = "Upgrade branch was prepared and source gate passed. Installed promotion still requires explicit user approval."
    payload["git_status"] = run(["git", "status", "--short"], cwd=repo_root).stdout.strip()
    payload["git_diff_stat"] = run(["git", "diff", "--stat"], cwd=repo_root).stdout.strip()
    return payload


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Prepare a reviewed MarkItDown upgrade branch without installed promotion.")
    parser.add_argument("--skill-dir", type=Path, default=monitor.skill_dir_default())
    parser.add_argument("--repo-root", type=Path)
    parser.add_argument("--status-file", type=Path, default=monitor.default_status_file())
    parser.add_argument("--state-file", type=Path, default=monitor.default_state_file())
    parser.add_argument("--report-file", type=Path, default=report_path_default())
    parser.add_argument("--fixture", type=Path, help="Use a local PyPI JSON fixture instead of network.")
    parser.add_argument("--github-fixture", type=Path, help="Use a local GitHub release JSON fixture instead of network.")
    parser.add_argument("--no-github", action="store_true")
    parser.add_argument("--timeout", type=int, default=20)
    parser.add_argument("--no-write-status", action="store_true")
    parser.add_argument("--no-write", dest="no_write_status", action="store_true", help="Alias for --no-write-status.")
    parser.add_argument("--skip-gate", action="store_true", help="Prepare branch without running the source release gate.")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--automation-output", action="store_true", help="Print only the user-facing automation message; print nothing for no-action.")
    args = parser.parse_args(argv)
    args.skill_dir = args.skill_dir.resolve()
    if args.repo_root is None:
        args.repo_root = repo_default(args.skill_dir)

    payload = prepare(args)
    if args.no_write_status:
        payload["report_file"] = ""
    else:
        try:
            write_report(args.report_file, payload)
            payload["report_file"] = str(args.report_file)
        except OSError as exc:
            payload.setdefault("errors", []).append(f"Could not write auto-prepare report {args.report_file}: {exc}")
            payload["report_file"] = ""
    if args.automation_output:
        output = automation_output(payload)
        if output:
            print(output)
    elif args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
    else:
        print(f"action_status={payload['action_status']}")
        print(f"signal={payload['monitor']['signal']}")
        print(f"branch={payload.get('branch') or ''}")
        print(f"report_file={payload['report_file']}")
        print(payload.get("summary", ""))
    return 0 if payload["action_status"] in {"not-needed", "not-prepared", "prepared", "blocked"} else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
