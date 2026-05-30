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

`doc-to-md` has one public skill surface: `skills/doc-to-md`. Personal conversion defaults such as preferred OCR language strings or audit-first habits belong in private local policy files, not in a second public skill and not in the plugin artifact. The staged `doc-to-md` copy is curated because publication docs, optional runtime boundaries, and plugin packaging need manual review.

## Skill Modes

The publication manifest is [`../../skills/promote-manifest.yaml`](../../skills/promote-manifest.yaml).

`auto` means the skill may be copied from the local Codex skills directory by `scripts/promote-skills-from-local.sh`.

`curated` means the staged public copy is maintained manually or semi-manually because public-safe edits may differ from the local operational copy.

`staged-only` means the skill exists in this repository as a publication/workflow artifact and is not copied from local Codex skills by default.

## Workflow

1. Update and test the local skill in Codex.
2. Run promotion drift detection:

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

5. For `doc-to-md`, run the release gate before publishing:

```bash
scripts/validate-doc-to-md-release.sh
```

This is stricter than structural validation. It requires installed, staged, and
plugin copies to match, checks compatibility frontmatter against the support
matrix, reads `mdown-doctor --json`, and runs the synthetic regression corpus.

6. Review the diff:

```bash
git diff -- skills plugins skills-index.md docs examples scripts registry.yaml README.md .agents/plugins/marketplace.json
```

7. Update root README, skill README, plugin README, `skills-index.md`, install docs, validation docs, registry anchors, and use cases when the public surface changed.
8. Commit and push only after manual review.

## Personal Runtime Sync Check

Use this check when the installed personal runtime copy should follow the
staged public source, for example after a public rename or after reinstalling a
skill from this repository:

```bash
scripts/check-skills-drift.sh --installed-runtime --skill fpf-work-guide
```

This check compares the installed skill at
`${LOCAL_SKILLS_DIR:-${CODEX_HOME:-$HOME/.codex}/skills}/fpf-work-guide` with
`skills/fpf-work-guide` after removing generated artifacts such as `.DS_Store`,
`__pycache__`, and `.pyc`. It does not promote local edits into the public
repository. It only answers whether the installed runtime copy and staged
source have drifted.

If the check reports drift and the staged source is the intended source of
truth, sync the installed copy from `skills/fpf-work-guide`, then rerun the
check. Keep private overlays, cache, state files, launcher hooks, and generated
runtime artifacts outside the skill directory.

## Safety Rules

- Do not run two-way sync.
- Do not automatically publish every local skill.
- Do not commit generated artifacts such as `.DS_Store`, `__pycache__`, or `.pyc`.
- Do not publish secrets, absolute private paths, local state files, cache files, logs, or machine-specific source references.
- Do not treat private overlays, runtime dependencies, cache/state files, generated outputs, or personal automation as public staged skill content.
- Do not treat private local policy files as public staged skill content.
- Do not overwrite curated skills with local operational copies unless the public-safe edits have been reapplied and reviewed.

## Expected Failure Modes

The promote script should fail rather than update staged files when:

- a selected skill is not listed in the manifest;
- a selected skill is `curated` or `staged-only`;
- the local skill is missing `SKILL.md`;
- private markers are found in the prepared public copy;
- structural validation fails.

These failures are intentional. They protect the boundary between local operational skills and public publication artifacts.
