# FPF Work Guide 0.2.1: DPF Discovery And Optional Suite

Status: local structural checks passed on 2026-09-11. One behavioral probe
completed on 2026-09-10 with acquisition blocked. This is not an end-to-end
download pass or a GitHub release/tag record. The merging PR identifies the
published source revisions.

## Change And Distribution Boundary

The canonical skill and plugin copy now explicitly match DPF creation, update
and review requests. The Suite reference describes per-task acquisition,
validation, reading and release through a separately configured trusted helper.
Plugin version: 0.2.1. See [ADR 0005](../adr/0005-fpf-engineering-suite-source.md).

The public package contains instructions, not the helper implementation,
personal configuration, cache, temporary sources or background job. No runtime
refresh script, protocol revision, host permission policy or Claude-native
profile changed. Users without the helper need setup or supplied sources for
Suite-dependent work. Core cache fallback is not a substitute Suite download.

## Independent Probe

A new local projectless Codex task received a synthetic request to create a
small DPF for a product team with one product manager, four developers and one
tester, addressing excess started work and missed deadlines. Requested output:
scope, principles, a checkable example and clarification questions. Neither the
skill nor Suite was named; no expected routing result or follow-up correction
was supplied. Repositories were not to be edited or published.

The task was not forked from the implementation conversation. The host creation
envelope included a source-task identifier, but the observed trace did not
retrieve that conversation. Installed skills and local settings were shared,
as intended for this personal-install probe. No private conversation export,
machine path or local settings are included here.

| Boundary | Observed outcome |
| --- | --- |
| Implicit selection | Agent selected FPF Work Guide and Operations DPF and read installed SKILL.md with the added description. |
| Suite route | Agent read engineering-suite.md and the configured helper location. |
| Acquisition attempt | Agent invoked the helper's acquire command. |
| Download | Exit 2, external-download-required; no cache created. No subsequent outside-sandbox acquisition in this run. |
| Suite reading / release | Not exercised: no source lease was acquired. |
| Final disclosure | Agent stated Suite was unavailable and named the alternative source basis for its draft. |

This confirms selection and attempted acquisition for one creation request in
one configured environment. It does not demonstrate successful Suite-backed
authoring, public fresh installation, update/review discovery, output quality,
source-fidelity accuracy or cleanup. No A/B baseline or negative control was
run. Broad existing FPF routing and the other installed domain skill are rival
explanations for selection; causation by the new sentence is not established.

## Local Release Checks

Executed against the combined source/Suite/discovery candidate:

```bash
FPF_VALIDATE_FORMAT=required FPF_VALIDATION_PYTHON="$VALIDATION_PYTHON" \
  SKILLS_VALIDATE_ONLY=fpf-work-guide scripts/validate-skills.sh
PLUGINS_VALIDATE_ONLY=fpf-work-guide scripts/validate-plugins.sh
diff -qr skills/fpf-work-guide plugins/fpf-work-guide/skills/fpf-work-guide
git diff --check
```

Use the pinned development environment documented in [validation](../validation.md).
The required format lane, protocol artifact checks, Bash lifecycle fixtures,
plugin structural checks and canonical/plugin equality passed. PowerShell was
unavailable and skipped; no Windows runtime verification is claimed. The
new Suite reference is included in required-file/link structural validation.
These checks do not execute an external Suite helper or grade generated DPFs.

## Replay And Remaining Acceptance Cases

Use a new local task with the installed candidate visible in skill discovery.
For creation, submit an ordinary DPF authoring request without naming the skill
or Suite. For update/review, provide a synthetic existing DPF and a corresponding
request. Keep work in a disposable output directory and do not publish it.

Inspect actual tool records, not just the final answer: skill read, Suite-route
read, acquisition command/result, source commit, relevant body reads and own
lease release after results are stored outside it. Record host permissions and
whether a helper was installed. Do not include personal settings in public logs.

Remaining cases, not claimed passed by this release record:

- Successful permitted external acquisition, source reading and cleanup in a new task.
- Independent DPF update and review requests.
- No-helper and unavailable-network diagnostics on a fresh public installation.
- A non-DPF task that does not download Suite, and cleanup after interruption.

An acquisition block should remain visible and block only the dependent work.
If agent routing or host execution changes, re-run the affected cases. Do not
disable sandbox protections or silently use another source to mark a pass.
