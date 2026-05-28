#!/usr/bin/env sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
plugins_dir="$repo_root/plugins"
marketplace="$repo_root/.agents/plugins/marketplace.json"
only_plugin="${PLUGINS_VALIDATE_ONLY:-}"
failed=0

. "$repo_root/scripts/lib/skills-publication.sh"

if [ ! -d "$plugins_dir" ]; then
  echo "ERROR: plugins/ directory is missing" >&2
  exit 1
fi

if [ ! -f "$marketplace" ]; then
  echo "ERROR: marketplace is missing: $marketplace" >&2
  failed=1
fi

if [ -n "$only_plugin" ]; then
  assert_safe_skill_name "$only_plugin" || failed=1
  if [ ! -d "$plugins_dir/$only_plugin" ]; then
    echo "ERROR: requested plugin is missing: plugins/$only_plugin" >&2
    failed=1
  fi
  if ! scan_private_markers "$plugins_dir/$only_plugin"; then
    echo "ERROR: private markers found under plugins/$only_plugin" >&2
    failed=1
  fi
elif ! scan_private_markers "$plugins_dir"; then
  echo "ERROR: private markers found under plugins/" >&2
  failed=1
fi

for plugin_dir in "$plugins_dir"/*; do
  [ -d "$plugin_dir" ] || continue
  plugin_name=$(basename "$plugin_dir")
  if [ -n "$only_plugin" ] && [ "$plugin_name" != "$only_plugin" ]; then
    continue
  fi
  manifest="$plugin_dir/.codex-plugin/plugin.json"

  if [ ! -f "$manifest" ]; then
    echo "ERROR: $plugin_name is missing .codex-plugin/plugin.json" >&2
    failed=1
    continue
  fi

  if ! python3 - "$plugin_dir" "$manifest" "$plugin_name" "$marketplace" <<'PY'
import json
import sys
from pathlib import Path

plugin_dir = Path(sys.argv[1])
manifest_path = Path(sys.argv[2])
plugin_name = sys.argv[3]
marketplace_path = Path(sys.argv[4])
errors = []

try:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
except Exception as exc:
    errors.append(f"invalid plugin.json: {exc}")
    manifest = {}

if manifest.get("name") != plugin_name:
    errors.append("plugin.json name must match plugin directory name")

for key in ("version", "description", "skills", "interface"):
    if key not in manifest:
        errors.append(f"plugin.json missing required field: {key}")

if manifest.get("skills") != "./skills/":
    errors.append("plugin.json skills must be ./skills/")

if "hooks" in manifest:
    errors.append("plugin.json must not declare hooks for the base public fpf-work-guide plugin")

skills_dir = plugin_dir / "skills"
if not skills_dir.is_dir():
    errors.append("plugin skills/ directory is missing")
else:
    for skill_dir in sorted(path for path in skills_dir.iterdir() if path.is_dir()):
        skill_md = skill_dir / "SKILL.md"
        if not skill_md.is_file():
            errors.append(f"{skill_dir.name} is missing SKILL.md")
            continue
        text = skill_md.read_text(encoding="utf-8")
        if not text.startswith("---\n"):
            errors.append(f"{skill_dir.name}/SKILL.md must start with YAML frontmatter")
        if f"name: {skill_dir.name}" not in text.split("---", 2)[1]:
            errors.append(f"{skill_dir.name}/SKILL.md name must match skill directory name")
        if "description:" not in text.split("---", 2)[1]:
            errors.append(f"{skill_dir.name}/SKILL.md is missing description")

if marketplace_path.is_file():
    try:
        marketplace = json.loads(marketplace_path.read_text(encoding="utf-8"))
    except Exception as exc:
        errors.append(f"invalid marketplace.json: {exc}")
        marketplace = {}
    entries = marketplace.get("plugins")
    if not isinstance(entries, list):
        errors.append("marketplace.json plugins must be an array")
    else:
        matching = [entry for entry in entries if entry.get("name") == plugin_name]
        if not matching:
            errors.append("marketplace.json does not list this plugin")
        else:
            source = matching[0].get("source", {})
            if source.get("source") != "local":
                errors.append("marketplace source.source must be local")
            if source.get("path") != f"./plugins/{plugin_name}":
                errors.append("marketplace source.path must point to ./plugins/<plugin-name>")
            policy = matching[0].get("policy", {})
            if policy.get("installation") not in {"AVAILABLE", "INSTALLED_BY_DEFAULT", "NOT_AVAILABLE"}:
                errors.append("marketplace policy.installation is invalid")
            if policy.get("authentication") not in {"ON_INSTALL", "ON_USE"}:
                errors.append("marketplace policy.authentication is invalid")

if errors:
    for error in errors:
        print(f"ERROR: {plugin_name}: {error}", file=sys.stderr)
    sys.exit(1)
PY
  then
    failed=1
  fi

  for bundled_skill_dir in "$plugin_dir"/skills/*; do
    [ -d "$bundled_skill_dir" ] || continue
    bundled_skill_name=$(basename "$bundled_skill_dir")
    staged_skill_dir="$repo_root/skills/$bundled_skill_name"
    if [ -d "$staged_skill_dir" ]; then
      if ! diff -qr "$staged_skill_dir" "$bundled_skill_dir" >/dev/null; then
        echo "ERROR: $plugin_name bundled skill '$bundled_skill_name' differs from skills/$bundled_skill_name" >&2
        echo "Run: rsync -a --delete skills/$bundled_skill_name/ plugins/$plugin_name/skills/$bundled_skill_name/" >&2
        failed=1
      fi
    fi
  done
done

if [ "$failed" -ne 0 ]; then
  exit 1
fi

echo "OK: plugins passed structural validation"
