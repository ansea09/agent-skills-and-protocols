# Promote Local Skills To Public Staged Skills

## Purpose

Use this workflow to update the public `skills/` directory from local Codex skills without treating the public repository as a live mirror of the local machine.

The method is one-way and curated:

```text
local operational skill -> sanitized staged public skill -> manual diff review -> commit/push
```

Read [`../skill-artifact-model.md`](../skill-artifact-model.md) before promoting a skill. Promotion moves content only between the installed operational copy and the public staged copy; it does not promote private overlays, runtime dependencies, local cache/state, personal automation, or generated outputs.

## Source And Target

Source:

```text
$HOME/.agents/skills or ${CODEX_HOME:-$HOME/.codex}/skills
```

Target:

```text
skills/
```

The local skill is the operational copy used by Codex. The staged public skill is a publication artifact. The public copy may intentionally differ from the local copy when local paths, runtime notes, or private source references need to be removed or generalized. On machines that still use `${CODEX_HOME:-$HOME/.codex}/skills`, treat that path as a local compatibility source, not as the public install contract.

## Artifact Layer Boundary

`fpf-work-guide` has one public skill surface: `skills/fpf-work-guide`. Personal session-start automation, workspace launchers, LaunchAgents, local state directories, and update jobs are local operational infrastructure around that skill. They are not a public skill overlay and are not promoted into `skills/`.

This matters for review: a diff may mention local automation in docs, but no public skill should depend on `bin/codex-fpf`, `jobs/fpf-update`, `.fpf-update/`, `~/.local/state/codex-fpf/`, or a user-specific LaunchAgent.

## Skill Modes

The publication manifest is [`../../skills/promote-manifest.yaml`](../../skills/promote-manifest.yaml).

`auto` means the skill may be copied from the local Codex skills directory by `scripts/promote-skills-from-local.sh`.

`curated` means the staged public copy is maintained manually or semi-manually because public-safe edits may differ from the local operational copy.

`staged-only` means the skill exists in this repository as a publication/workflow artifact and is not copied from local Codex skills by default.

## Workflow

1. Update and test the local skill in Codex.
2. Run drift detection:

```bash
scripts/check-skills-drift.sh
```

3. Promote auto skills when needed:

```bash
scripts/promote-skills-from-local.sh
```

4. Validate staged skills:

```bash
scripts/validate-skills.sh
scripts/validate-plugins.sh
```

5. Review the diff:

```bash
git diff -- skills skills-index.md docs examples scripts registry.yaml README.md
```

6. Update `skills-index.md`, install docs, validation docs, and use cases when the public surface changed.
7. Commit and push only after manual review.

## Safety Rules

- Do not run two-way sync.
- Do not automatically publish every local skill.
- Do not commit generated artifacts such as `.DS_Store`, `__pycache__`, or `.pyc`.
- Do not publish secrets, absolute private paths, local state files, cache files, logs, or machine-specific source references.
- Do not treat private overlays, runtime dependencies, cache/state files, generated outputs, or personal automation as public staged skill content.
- Do not overwrite curated skills with local operational copies unless the public-safe edits have been reapplied and reviewed.

## Expected Failure Modes

The promote script should fail rather than update staged files when:

- a selected skill is not listed in the manifest;
- a selected skill is `curated` or `staged-only`;
- the local skill is missing `SKILL.md`;
- private markers are found in the prepared public copy;
- structural validation fails.

These failures are intentional. They protect the boundary between local operational skills and public publication artifacts.
