#!/usr/bin/env sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
skills_dir="$repo_root/skills"
manifest="$skills_dir/promote-manifest.yaml"
only_skill="${SKILLS_VALIDATE_ONLY:-}"
failed=0
public_text_private_marker_paths="
$repo_root/docs
$repo_root/claude-code
$repo_root/protocols
$repo_root/README.md
$repo_root/README.ru.md
$repo_root/skills-index.md
$repo_root/registry.yaml
$repo_root/.agents/plugins/marketplace.json
"

. "$repo_root/scripts/lib/skills-publication.sh"

if [ ! -d "$skills_dir" ]; then
  echo "ERROR: skills/ directory is missing" >&2
  exit 1
fi

scan_generated_artifacts() {
  label="$1"
  shift

  if find "$@" -name .DS_Store -print | grep -q .; then
    echo "ERROR: .DS_Store files are present under $label" >&2
    find "$@" -name .DS_Store -print >&2
    failed=1
  fi

  if find "$@" -name '*.pyc' -print | grep -q .; then
    echo "ERROR: .pyc files are present under $label" >&2
    find "$@" -name '*.pyc' -print >&2
    failed=1
  fi

  if find "$@" -name __pycache__ -type d -print | grep -q .; then
    echo "ERROR: __pycache__ directories are present under $label" >&2
    find "$@" -name __pycache__ -type d -print >&2
    failed=1
  fi
}

if [ -n "$only_skill" ]; then
  assert_safe_skill_name "$only_skill" || failed=1
  if [ ! -d "$skills_dir/$only_skill" ]; then
    echo "ERROR: requested skill is missing: skills/$only_skill" >&2
    failed=1
  fi
  scan_generated_artifacts "skills/$only_skill and scripts" "$skills_dir/$only_skill" "$repo_root/scripts"
else
  scan_generated_artifacts "repository" "$repo_root"
fi

if [ ! -f "$manifest" ]; then
  echo "ERROR: missing publication manifest: $manifest" >&2
  failed=1
fi

for skill_dir in "$skills_dir"/*; do
  [ -d "$skill_dir" ] || continue

  dir_name=$(basename "$skill_dir")
  if [ -n "$only_skill" ] && [ "$dir_name" != "$only_skill" ]; then
    continue
  fi
  skill_md="$skill_dir/SKILL.md"

  if [ ! -f "$skill_md" ]; then
    echo "ERROR: $dir_name is missing SKILL.md" >&2
    failed=1
    continue
  fi

  first_line=$(sed -n '1p' "$skill_md")
  if [ "$first_line" != "---" ]; then
    echo "ERROR: $dir_name/SKILL.md must start with YAML frontmatter" >&2
    failed=1
  fi

  skill_name=$(awk '
    NR == 1 && $0 != "---" { exit 1 }
    NR > 1 && $0 == "---" { exit 0 }
    NR > 1 && $1 == "name:" {
      sub(/^name:[[:space:]]*/, "")
      gsub(/^"|"$/, "")
      print
      exit 0
    }
  ' "$skill_md")

  if [ -z "$skill_name" ]; then
    echo "ERROR: $dir_name/SKILL.md is missing frontmatter name" >&2
    failed=1
  elif [ "$skill_name" != "$dir_name" ]; then
    echo "ERROR: $dir_name/SKILL.md name '$skill_name' does not match directory name" >&2
    failed=1
  fi

  if ! awk '
    NR == 1 && $0 != "---" { exit 1 }
    NR > 1 && $0 == "---" { exit found ? 0 : 1 }
    NR > 1 && $1 == "description:" { found = 1 }
  ' "$skill_md"; then
    echo "ERROR: $dir_name/SKILL.md is missing frontmatter description" >&2
    failed=1
  fi

  if ! grep -q "(skills/$dir_name/)" "$repo_root/skills-index.md"; then
    echo "ERROR: $dir_name is missing from skills-index.md" >&2
    failed=1
  fi

  if [ "$dir_name" = "fpf-work-guide" ]; then
    for reference in \
      references/chunk-lookup.md \
      references/diagnostics.md \
      references/protocol-trust.md \
      references/source-selection.md
    do
      if [ ! -f "$skill_dir/$reference" ]; then
        echo "ERROR: fpf-work-guide is missing canonical reference: $reference" >&2
        failed=1
      elif ! grep -q "$reference" "$skill_md"; then
        echo "ERROR: fpf-work-guide/SKILL.md does not link canonical reference: $reference" >&2
        failed=1
      fi
    done

    for script_file in \
      scripts/update_fpf_context.sh \
      scripts/update_fpf_spec.sh \
      scripts/update_fpf_protocols.sh \
      scripts/check_fpf_environment.sh \
      scripts/fpf-work-guide-doctor \
      scripts/fpf_common.ps1 \
      scripts/update_fpf_context.ps1 \
      scripts/update_fpf_spec.ps1 \
      scripts/update_fpf_protocols.ps1 \
      scripts/check_fpf_environment.ps1 \
      scripts/fpf-work-guide-doctor.ps1 \
      scripts/update_fpf_context.cmd \
      scripts/fpf-work-guide-doctor.cmd
    do
      if [ ! -f "$skill_dir/$script_file" ]; then
        echo "ERROR: fpf-work-guide is missing cross-platform script: $script_file" >&2
        failed=1
      fi
    done

    if ! "$repo_root/scripts/validate-fpf-work-guide-cross-platform.sh"; then
      failed=1
    fi
  fi

  if [ "$dir_name" = "doc-to-md" ]; then
    if ! grep -q "## Document Roles" "$skill_md"; then
      echo "ERROR: doc-to-md/SKILL.md must declare document roles" >&2
      failed=1
    fi

    for reference in \
      references/workflow-profiles.md \
      references/diagnostics.md \
      references/scenario-boundaries.md \
      references/audit-bundle.md \
      references/epub-bundle.md \
      references/ocr-paths.md \
      references/support-matrix.md \
      references/python-profiles.md \
      references/lock-refresh.md \
      references/markitdown-upgrade.md \
      references/threat-model.md \
      references/publishing.md
    do
      if [ ! -f "$skill_dir/$reference" ]; then
        echo "ERROR: doc-to-md is missing canonical reference: $reference" >&2
        failed=1
      elif ! grep -q "$reference" "$skill_md"; then
        echo "ERROR: doc-to-md/SKILL.md does not link canonical reference: $reference" >&2
        failed=1
      fi
    done

    if ! "$repo_root/scripts/validate-doc-to-md-compatibility.py" "$skill_dir"; then
      failed=1
    fi

    for profile_file in \
      requirements-core.macos-arm64-py313.hashes.txt \
      requirements-book.macos-arm64-py313.hashes.txt \
      requirements-ocr.macos-arm64-py313.hashes.txt \
      requirements-core.macos-intel-py312.txt \
      requirements-core.macos-intel-py312.hashes.txt \
      requirements-book.macos-intel-py312.hashes.txt
    do
      if [ ! -f "$skill_dir/$profile_file" ]; then
        echo "ERROR: doc-to-md is missing maintained profile file: $profile_file" >&2
        failed=1
      fi
    done
  fi
done

if [ -z "$only_skill" ] && [ -f "$manifest" ]; then
  for skill_name in $(manifest_skills "$manifest"); do
    assert_safe_skill_name "$skill_name" || failed=1
    if [ ! -d "$skills_dir/$skill_name" ]; then
      echo "ERROR: manifest references missing staged skill: $skill_name" >&2
      failed=1
    fi
  done
fi

if [ -n "$only_skill" ]; then
  if ! scan_private_markers "$skills_dir/$only_skill"; then
    echo "ERROR: private markers found under skills/$only_skill" >&2
    failed=1
  fi
else
  if ! scan_private_markers "$skills_dir"; then
    echo "ERROR: private markers found under skills/" >&2
    failed=1
  fi
  for public_text_path in $public_text_private_marker_paths; do
    if [ -e "$public_text_path" ] && ! scan_private_markers "$public_text_path"; then
      echo "ERROR: private markers found under ${public_text_path#$repo_root/}" >&2
      failed=1
    fi
  done
fi

if [ "$failed" -ne 0 ]; then
  exit 1
fi

if [ -z "$only_skill" ]; then
  "$repo_root/scripts/validate-claude-code-profiles.sh"
fi

echo "OK: staged skills passed structural validation"
