# Validation

Run this before installing or sharing staged skills or plugins from this repository.

```bash
scripts/validate-skills.sh
scripts/validate-plugins.sh
```

`scripts/validate-skills.sh` also validates the source-only Claude Code install
profiles under `claude-code/`. To run that lane directly:

```bash
scripts/validate-claude-code-profiles.sh
```

For a `doc-to-md` public source/plugin release, run the stricter source gate:

```bash
scripts/validate-doc-to-md-release.sh
```

The source gate uses staged requirements, staged wrappers, and either a
temporary runtime or a reusable `DOC_TO_MD_CI_RUNTIME` cache root. It does not
require the public skill to be installed under `${CODEX_HOME:-$HOME/.codex}`.
For public publication evidence, require online dependency SCA:

```bash
DOC_TO_MD_SCA_MODE=required scripts/validate-doc-to-md-release.sh
```

For a local promotion from an installed operational copy, run:

```bash
scripts/validate-doc-to-md-release.sh --promotion
```

The validation checks:

- every directory under `skills/` contains `SKILL.md`;
- each `SKILL.md` starts with YAML frontmatter;
- frontmatter contains `name` and `description`;
- the frontmatter `name` matches the skill directory name;
- no `.DS_Store`, `__pycache__`, or `.pyc` files are present;
- every staged skill is listed in `skills-index.md`;
- every skill listed in `skills/promote-manifest.yaml` exists under `skills/`;
- no high-risk private markers are present under `skills/`;
- `doc-to-md` frontmatter compatibility matches
  `skills/doc-to-md/references/support-matrix.md`;
- `doc-to-md` frontmatter hash profiles are documented in
  `skills/doc-to-md/references/python-profiles.md` and have matching
  `requirements-*.hashes.txt` files.

For `fpf-work-guide`, `scripts/validate-skills.sh` runs
`scripts/validate-fpf-work-guide-cross-platform.sh`. That gate always runs Bash
golden-output fixtures for chunk source commit behavior, protocol cache output,
context-gate lifecycle, doctor output, lock handling, unavailable state
directories, cache reset guards, cache marker content validation, protocol
provenance fields, and CMD wrapper delegation. If `pwsh` is available, it also
runs the PowerShell spec updater, protocol updater, context gate, doctor, lock
behavior, state-dir-unavailable behavior, and cache reset guard through
`pwsh -NoProfile -File ...` on the same fixture shape. These local tests prove
implementation parity for the exercised fixtures; native Windows release claims
still require a Windows or `pwsh` validation lane, and CMD release claims require
CMD smoke validation on a Windows host. Set `FPF_VALIDATE_POWERSHELL=required`
on a CI or maintainer machine where missing `pwsh` should fail validation. Set
`FPF_VALIDATE_CMD=required` on a Windows host where missing `cmd.exe` wrapper
smoke coverage should fail validation.

Plugin validation checks:

- every directory under `plugins/` contains `.codex-plugin/plugin.json`;
- each plugin manifest has `name`, `version`, `description`, `skills`, and `interface`;
- the manifest `name` matches the plugin directory name;
- bundled skills under `plugins/<name>/skills/` contain valid `SKILL.md` files;
- the repo-local marketplace `.agents/plugins/marketplace.json` lists the plugin;
- no high-risk private markers are present under `plugins/`;
- bundled plugin skills match their staged `skills/<name>/` source.

Claude Code profile validation checks:

- each maintained profile contains its README, installer, slash-command
  templates, and subagent file;
- Bash installers parse and pass `--check` without writing to `~/.claude`;
- PowerShell installers pass `-Check` when `pwsh` is available;
- slash-command templates call the public `fpf-work-guide` refresh gate and
  doctor scripts;
- Claude Code profiles remain source-only adapter artifacts and do not bundle
  cache, state, private overlays, or generated outputs.

`doc-to-md` release validation additionally checks:

- staged `skills/doc-to-md` matches bundled
  `plugins/doc-to-md/skills/doc-to-md`;
- source mode does not require an installed operational copy;
- source mode builds or reuses repo-scoped CI runtimes from staged
  requirements and staged wrappers;
- promotion mode additionally checks that staged `skills/doc-to-md` matches the
  installed operational copy at `${CODEX_HOME:-$HOME/.codex}/skills/doc-to-md`,
  unless `DOC_TO_MD_INSTALLED_SKILL_DIR` points elsewhere;
- `mdown-doctor --json`, `mdown-book --doctor --json`, and
  `mdown-ocrpdf --doctor --json` validate against
  `skills/doc-to-md/schemas/*.schema.json`;
- the dependency license/runtime audit runs for core, book, and OCR profiles;
- `DOC_TO_MD_SCA_MODE=required` additionally fails closed if online package
  vulnerability metadata cannot be checked;
- the dependency maintenance monitor has a fixture-backed smoke check for
  OCR/PDF drift signals;
- the synthetic regression corpus matches expected Markdown snapshots before a
  MarkItDown upgrade is published;
- the generated audit bundle regression verifies PDF page/image/link evidence;
- promotion mode additionally checks installed `mdown-book --doctor --json` and
  `mdown-ocrpdf --doctor --json` as releasable runtime evidence.

Manual review checklist:

- The staged copy is classified using [skill-artifact-model.md](skill-artifact-model.md) before review.
- The skill does not expose secrets, tokens, local private paths, or private data.
- Skill `README.md` files are optional user/maintainer documentation for published, operationally complex, or plugin-packaged skills; `SKILL.md` remains the executable routing contract.
- Do not require README files for every skill. Do not add one when it only duplicates `SKILL.md` or `references/`.
- Plugin-bundled skill copies include the same skill `README.md` as `skills/<name>/` when the staged skill has one.
- `fpf-work-guide` installation docs include the one-time portable doctor command.
- `fpf-work-guide` has a staged `README.md` covering install targets, portable invocation, Windows entrypoints, diagnostics, release notes, and publication boundaries.
- `fpf-work-guide` behavior docs define `substantive task`, non-substantive interactions, and the agent-side task-admission start event with examples.
- `doc-to-md` has a staged `README.md` covering install targets, workflow profiles, audit/OCR paths, diagnostics, release notes, and publication boundaries.
- `doc-to-md` documentation describes one public skill with reusable workflow profiles, not a required `doc-to-md-private` companion skill.
- `doc-to-md` frontmatter contains a short `compatibility` summary aligned with `references/support-matrix.md`.
- `doc-to-md` Python minor-version claims are profile-specific and documented in `references/python-profiles.md`; unlisted Python minors stay candidate/unverified.
- `doc-to-md` keeps personal OCR language preferences and local defaults in private local policy files, outside staged skill and plugin artifacts.
- `doc-to-md` plugin copy is synchronized with `skills/doc-to-md/`, including reference files such as `workflow-profiles.md` and `local-policy-migration.md`.
- `doc-to-md` installed, staged, and plugin copies have no release drift.
- `doc-to-md` MarkItDown upgrades run `skills/doc-to-md/scripts/regression_corpus.py` and compare snapshot diffs before publishing.
- `doc-to-md` MarkItDown upgrades follow `skills/doc-to-md/references/markitdown-upgrade.md`; `magika 1.x` is not promoted alone until upstream MarkItDown metadata allows it.
- `doc-to-md` public review includes `skills/doc-to-md/references/threat-model.md`; trusted-local guardrails are not represented as sandboxing.
- `doc-to-md` does not add a high-fidelity textbook parser to core; higher-quality textbook parsing stays in a separate experimental workflow until it has its own runtime, support matrix, and release gate.
- `doc-to-md` user-facing diagnostics are documented in `references/diagnostics.md` and cover runtime, doctor, guardrail, output quality, audit, OCR, write-safety, platform, and publication boundaries.
- `doc-to-md` docs state that `eng+rus` is an English/Russian OCR choice when the language packs are installed, not a universal default.
- Installation docs distinguish modern Codex skill discovery locations such as `.agents/skills` from local legacy/current compatibility paths such as `${CODEX_HOME:-$HOME/.codex}/skills`.
- Installation docs state that plugins are the distribution path for reusable skills shared beyond local authoring or a single repo-scoped workflow.
- `fpf-work-guide` states its compatibility contract: Codex/macOS-first, Git required for fresh refresh, Bash path supported on Unix-like shells, native Windows PowerShell implemented through `.ps1` scripts, CMD implemented through `.cmd` wrappers, cache fallback supported, WSL supported, Git Bash best effort, and Windows/CI claims marked release-verified only when the relevant validation lane has passed.
- `fpf-work-guide` does not require hard-coded `$HOME/.codex`, `$HOME/.agents`, or `$PWD/.fpf-update` invocation when installed for Claude Code or another non-Codex agent; the docs show `FPF_WORK_GUIDE_SKILL_DIR`, `FPF_CACHE_HOME`, and `FPF_UPDATE_STATE_DIR`.
- `fpf-work-guide` doctor output reports path modes for skill, cache, state, and overall path policy.
- `fpf-work-guide` has PowerShell equivalents for the refresh gate, spec updater, protocols updater, environment checker, and doctor.
- `fpf-work-guide` has CMD wrappers for the refresh gate and doctor, and those wrappers delegate to PowerShell rather than reimplementing refresh logic.
- `fpf-work-guide` emits `FPF_CHUNKS_SOURCE_COMMIT`; when it differs from `FPF_SPEC_COMMIT`, chunks are `stale` and full-spec-first behavior is used.
- `fpf-work-guide` documents protocol repository trust policy because the protocol repository is an instruction source, not only reference text.
- `fpf-work-guide` protects `git reset --hard` behind a valid cache marker with matching kind/repository/branch, matching remote verification, or explicit `FPF_ALLOW_NONSTANDARD_CACHE_RESET=1`.
- `fpf-work-guide` emits protocol provenance fields: `FPF_PROTOCOLS_REPO_URL`, `FPF_PROTOCOLS_BRANCH`, `FPF_PROTOCOLS_REMOTE_URL`, and `FPF_PROTOCOLS_CACHE_TRUST_STATUS`.
- `fpf-work-guide` keeps durable gate state (`latest.env`) separate from wrapper-captured gate output (`latest-output.env`).
- `fpf-work-guide` treats `FPF_REFRESH_AUTO_STATE_FILE` as explicit opt-in and emits `FPF_REFRESH_LAST_ATTEMPT_STATE_PATH`.
- Personal automation around `fpf-work-guide` is documented as local infrastructure, not as a public skill overlay or staged skill dependency.
- Symlinked workspaces use explicit `FPF_UPDATE_STATE_DIR` in launchers/hooks when stable human-facing diagnostics matter.
- `fpf-work-guide` documents that workspace state and launcher/global state can both exist; reviewers inspect `FPF_REFRESH_STATE_PATH` before interpreting refresh decisions.
- `fpf-work-guide` classifies an unavailable or unwritable state directory as `state-dir-unavailable`, not `active-refresh`.
- Public plugin artifacts do not include personal launchers, LaunchAgents, workspace jobs, `.fpf-update/`, cache, logs, or machine-local env files.
- Private overlays, runtime venvs, caches, local state files, logs, generated outputs, and upstream mirrors are not committed as staged skill content unless explicitly reviewed as public fixtures or examples.
- Public examples do not imply capabilities that are not included in the repository.
- Any optional runtime dependency is disclosed in `skills-index.md` and the skill's `SKILL.md`.
- Root README, `skills-index.md`, staged skill READMEs, plugin READMEs, install docs, validation docs, and registry anchors describe the same public skill inventory.
- `fpf-work-guide` and other FPF-backed skills disclose cached/fresh status rather than claiming "latest" when only cache is available.
- `fpf-work-guide` treats `fpf-chunks-layout.env` as a parsed key/value layout contract, never as sourced shell code.
- `fpf-work-guide` has been tested for at least: normal cache-only run, invalid state path fallback, staged/plugin/runtime copy sync, and plugin/skill structural validation.
- The repository README, `skills-index.md`, install instructions, and collaboration scenario still describe the same staged scope.
- Auto-promotable skills are safe to regenerate from local copies; curated skills keep their public-safe edits.
