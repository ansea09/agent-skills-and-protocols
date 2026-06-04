#!/usr/bin/env sh
set -eu
export PYTHONDONTWRITEBYTECODE=1

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
staged_skill="$repo_root/skills/doc-to-md"
plugin_skill="$repo_root/plugins/doc-to-md/skills/doc-to-md"
installed_skill="${DOC_TO_MD_INSTALLED_SKILL_DIR:-${CODEX_HOME:-$HOME/.codex}/skills/doc-to-md}"
mode=source
failed=0
tmp_runtime=""
monitor_tmp=""

usage() {
  cat <<'EOF'
Usage:
  scripts/validate-doc-to-md-release.sh [--source|--promotion]

Modes:
  --source      CI-safe public source/plugin gate. It uses staged requirements,
                staged wrappers, and either DOC_TO_MD_CI_RUNTIME or a temporary
                repo-scoped runtime. It does not require an installed skill copy.
  --promotion   Local promotion gate. Runs the source gate plus installed-copy
                drift and installed workflow doctors.

Environment:
  DOC_TO_MD_CI_RUNTIME  Optional runtime cache root containing or receiving:
                        markitdown-core-venv, doc-to-md-book-venv,
                        and doc-to-md-ocr-venv.
  DOC_TO_MD_SCA_MODE    Dependency audit mode: best-effort (default), online,
                        required, or skip. Use required for public publication.
  PYTHON                Python used to create temporary CI runtimes.
EOF
}

cleanup() {
  if [ -n "$tmp_runtime" ] && [ -d "$tmp_runtime" ]; then
    rm -rf "$tmp_runtime"
  fi
  if [ -n "$monitor_tmp" ] && [ -d "$monitor_tmp" ]; then
    rm -rf "$monitor_tmp"
  fi
}
trap cleanup EXIT INT TERM

while [ "$#" -gt 0 ]; do
  case "$1" in
    --source)
      mode=source
      shift
      ;;
    --promotion|--installed)
      mode=promotion
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

python_bin="${PYTHON:-python3}"
sca_mode="${DOC_TO_MD_SCA_MODE:-best-effort}"
if ! command -v "$python_bin" >/dev/null 2>&1; then
  echo "ERROR: Python not found: $python_bin" >&2
  exit 127
fi

if [ -n "${DOC_TO_MD_CI_RUNTIME:-}" ]; then
  ci_runtime="${DOC_TO_MD_CI_RUNTIME%/}"
else
  tmp_runtime=$(mktemp -d "${TMPDIR:-/tmp}/doc-to-md-ci-runtime.XXXXXX")
  ci_runtime="$tmp_runtime"
fi

core_venv="$ci_runtime/markitdown-core-venv"
book_venv="$ci_runtime/doc-to-md-book-venv"
ocr_venv="$ci_runtime/doc-to-md-ocr-venv"
core_python="$core_venv/bin/python"
book_python="$book_venv/bin/python"
ocr_python="$ocr_venv/bin/python"

check_dir() {
  label="$1"
  path="$2"
  if [ ! -d "$path" ]; then
    echo "ERROR: missing $label doc-to-md skill copy: $path" >&2
    failed=1
  fi
}

check_diff() {
  label="$1"
  left="$2"
  right="$3"
  if ! diff -qr "$left" "$right" >/dev/null; then
    echo "ERROR: doc-to-md drift between $label" >&2
    diff -qr "$left" "$right" || true
    failed=1
  else
    echo "OK: doc-to-md $label match"
  fi
}

setup_runtime() {
  label="$1"
  venv="$2"
  requirements="$3"
  python="$venv/bin/python"

  if [ -x "$python" ]; then
    echo "OK: using existing $label CI runtime at $venv"
    return 0
  fi

  echo "OK: creating $label CI runtime from staged requirements"
  mkdir -p "$(dirname "$venv")"
  "$python_bin" -m venv "$venv" || return 1
  "$python" -m pip install --disable-pip-version-check --upgrade pip || return 1
  "$python" -m pip install --disable-pip-version-check -r "$requirements" || return 1
}

validate_doctor_json() {
  schema="$1"
  expected_tool="$2"
  label="$3"
  allow_fail="$4"
  shift 4
  doctor_json=$(mktemp "${TMPDIR:-/tmp}/doc-to-md-doctor.XXXXXX")

  set +e
  "$@" >"$doctor_json"
  doctor_status=$?
  set -e

  if [ "$doctor_status" -ne 0 ] && [ "$allow_fail" != "allow-fail" ]; then
    cat "$doctor_json" >&2 || true
    rm -f "$doctor_json"
    failed=1
    return 0
  fi

  if ! "$repo_root/scripts/validate-json-schema.py" "$schema" "$doctor_json"; then
    failed=1
  fi

  python3 - "$doctor_json" "$expected_tool" "$label" "$allow_fail" "$doctor_status" <<'PY' || failed=1
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
expected_tool = sys.argv[2]
label = sys.argv[3]
allow_fail = sys.argv[4] == "allow-fail"
doctor_status = int(sys.argv[5])
payload = json.loads(path.read_text(encoding="utf-8"))
if payload.get("tool") != expected_tool:
    print(f"ERROR: unexpected {label} doctor tool in JSON payload: {payload.get('tool')}", file=sys.stderr)
    sys.exit(1)
status = payload.get("status")
if allow_fail:
    if status not in {"ok", "warn", "fail"}:
        print(f"ERROR: {label} doctor JSON status is invalid: {status}", file=sys.stderr)
        sys.exit(1)
else:
    if payload.get("exit_code") != 0 or doctor_status != 0:
        print(f"ERROR: {label} doctor JSON reports non-zero exit", file=sys.stderr)
        sys.exit(1)
    if status not in {"ok", "warn"}:
        print(f"ERROR: {label} doctor JSON status is not releasable: {status}", file=sys.stderr)
        sys.exit(1)
print(f"OK: {label} doctor --json schema valid status={status}")
PY
  rm -f "$doctor_json"
}

check_dir "staged" "$staged_skill"
check_dir "plugin" "$plugin_skill"
if [ "$mode" = "promotion" ]; then
  check_dir "installed" "$installed_skill"
fi

if [ "$failed" -eq 0 ]; then
  check_diff "staged and plugin copies" "$staged_skill" "$plugin_skill"
  if [ "$mode" = "promotion" ]; then
    check_diff "staged and installed copies" "$staged_skill" "$installed_skill"
  fi
fi

if [ ! -f "$staged_skill/SKILL.md" ]; then
  echo "ERROR: staged doc-to-md is missing SKILL.md" >&2
  failed=1
fi
if [ ! -f "$plugin_skill/SKILL.md" ]; then
  echo "ERROR: plugin doc-to-md bundled skill is missing SKILL.md" >&2
  failed=1
fi
if [ ! -f "$repo_root/plugins/doc-to-md/.codex-plugin/plugin.json" ]; then
  echo "ERROR: doc-to-md plugin manifest is missing" >&2
  failed=1
fi
"$repo_root/scripts/validate-doc-to-md-compatibility.py" "$staged_skill" || failed=1

if [ "$failed" -eq 0 ]; then
  setup_runtime core "$core_venv" "$staged_skill/requirements-core.txt" || failed=1
  setup_runtime book "$book_venv" "$staged_skill/requirements-book.txt" || failed=1
  setup_runtime ocr "$ocr_venv" "$staged_skill/requirements-ocr.lock.txt" || failed=1
fi

run_core() {
  env \
    MARKITDOWN_VENV="$core_venv" \
    MARKITDOWN_BIN="$core_venv/bin/markitdown" \
    MARKITDOWN_PYTHON="$core_python" \
    MARKITDOWN_REQUIREMENTS="$staged_skill/requirements-core.txt" \
    MARKITDOWN_WRAPPER="$staged_skill/scripts/markitdown-local" \
    DOC_TO_MD_CORE_DOCTOR_SCRIPT="$staged_skill/scripts/mdown_doctor.py" \
    MDOWN_BIN="$staged_skill/scripts/markitdown-local" \
    "$@"
}

run_core_book() {
  env \
    MARKITDOWN_VENV="$core_venv" \
    MARKITDOWN_BIN="$core_venv/bin/markitdown" \
    MARKITDOWN_PYTHON="$core_python" \
    MARKITDOWN_REQUIREMENTS="$staged_skill/requirements-core.txt" \
    MARKITDOWN_WRAPPER="$staged_skill/scripts/markitdown-local" \
    DOC_TO_MD_CORE_DOCTOR_SCRIPT="$staged_skill/scripts/mdown_doctor.py" \
    MDOWN_BIN="$staged_skill/scripts/markitdown-local" \
    DOC_TO_MD_BOOK_VENV="$book_venv" \
    DOC_TO_MD_BOOK_PYTHON="$book_python" \
    DOC_TO_MD_BOOK_SCRIPT="$staged_skill/scripts/mdown_book.py" \
    DOC_TO_MD_BOOK_REQUIREMENTS="$staged_skill/requirements-book.txt" \
    MDOWN_BOOK_BIN="$staged_skill/scripts/mdown-book" \
    "$@"
}

run_core_epub() {
  env \
    MARKITDOWN_VENV="$core_venv" \
    MARKITDOWN_BIN="$core_venv/bin/markitdown" \
    MARKITDOWN_PYTHON="$core_python" \
    MARKITDOWN_REQUIREMENTS="$staged_skill/requirements-core.txt" \
    MARKITDOWN_WRAPPER="$staged_skill/scripts/markitdown-local" \
    DOC_TO_MD_EPUB_REQUIREMENTS="$staged_skill/requirements-core.txt" \
    DOC_TO_MD_EPUB_SCRIPT="$staged_skill/scripts/mdown_epub.py" \
    "$@"
}

run_ocr() {
  env \
    DOC_TO_MD_OCR_VENV="$ocr_venv" \
    DOC_TO_MD_OCR_PYTHON="$ocr_python" \
    DOC_TO_MD_OCR_SCRIPT="$staged_skill/scripts/mdown_ocrpdf.py" \
    DOC_TO_MD_OCR_REQUIREMENTS="$staged_skill/requirements-ocr.lock.txt" \
    "$@"
}

if [ "$failed" -eq 0 ]; then
  monitor_tmp=$(mktemp -d "${TMPDIR:-/tmp}/doc-to-md-monitor.XXXXXX")
  "$python_bin" "$staged_skill/scripts/markitdown_upstream_monitor.py" \
    --skill-dir "$staged_skill" \
    --fixture "$staged_skill/tests/fixtures/markitdown-upstream/pypi-current.json" \
    --no-github \
    --no-write \
    --json >/dev/null || failed=1
  "$python_bin" "$staged_skill/scripts/prepare_markitdown_upgrade_lane.py" \
    --skill-dir "$staged_skill" \
    --repo-root "$repo_root" \
    --fixture "$staged_skill/tests/fixtures/markitdown-upstream/pypi-current.json" \
    --no-github \
    --no-write \
    --report-file "$monitor_tmp/auto-prepare-report.md" \
    --json >/dev/null || failed=1
  "$python_bin" "$staged_skill/scripts/dependency_maintenance_monitor.py" \
    --skill-dir "$staged_skill" \
    --packages ocrmypdf \
    --fixture-dir "$staged_skill/tests/fixtures/dependency-maintenance" \
    --no-write \
    --json >/dev/null || failed=1

  if [ "$sca_mode" != "skip" ]; then
    sca_flags=""
    case "$sca_mode" in
      best-effort)
        ;;
      online)
        sca_flags="--online"
        ;;
      required)
        sca_flags="--online --require-online"
        ;;
      *)
        echo "ERROR: unsupported DOC_TO_MD_SCA_MODE: $sca_mode" >&2
        failed=1
        ;;
    esac
    if [ "$failed" -eq 0 ]; then
      "$core_python" "$staged_skill/scripts/dependency_audit.py" \
        --requirements core="$staged_skill/requirements-core.txt" \
        --requirements book="$staged_skill/requirements-book.txt" \
        --requirements ocr="$staged_skill/requirements-ocr.lock.txt" \
        --python core="$core_python" \
        --python book="$book_python" \
        --python ocr="$ocr_python" \
        $sca_flags \
        --output "$monitor_tmp/dependency-audit.json" \
        --json >/dev/null || failed=1
    fi
  else
    echo "WARN: dependency SCA/license audit skipped by DOC_TO_MD_SCA_MODE=skip" >&2
  fi

  run_core "$staged_skill/scripts/regression_corpus.py" || failed=1
  run_core_epub "$staged_skill/scripts/epub_bundle_regression.py" || failed=1
  run_core_book "$staged_skill/scripts/audit_bundle_regression.py" || failed=1

  validate_doctor_json \
    "$staged_skill/schemas/mdown-doctor.schema.json" \
    mdown-doctor \
    "source core" \
    no-fail \
    run_core "$staged_skill/scripts/mdown-doctor" --json

  validate_doctor_json \
    "$staged_skill/schemas/mdown-book-doctor.schema.json" \
    mdown-book \
    "source book" \
    no-fail \
    run_core_book "$staged_skill/scripts/mdown-book" --doctor --json

  validate_doctor_json \
    "$staged_skill/schemas/mdown-epub-doctor.schema.json" \
    mdown-epub \
    "source EPUB" \
    no-fail \
    run_core_epub "$staged_skill/scripts/mdown-epub" --doctor --json

  validate_doctor_json \
    "$staged_skill/schemas/mdown-ocrpdf-doctor.schema.json" \
    mdown-ocrpdf \
    "source OCR" \
    allow-fail \
    run_ocr "$staged_skill/scripts/mdown-ocrpdf" --doctor --json
fi

if [ "$mode" = "promotion" ]; then
  if command -v mdown-doctor >/dev/null 2>&1; then
    validate_doctor_json "$staged_skill/schemas/mdown-doctor.schema.json" mdown-doctor "installed core" no-fail mdown-doctor --json
  elif [ -x "$HOME/.local/bin/mdown-doctor" ]; then
    validate_doctor_json "$staged_skill/schemas/mdown-doctor.schema.json" mdown-doctor "installed core" no-fail "$HOME/.local/bin/mdown-doctor" --json
  else
    echo "ERROR: mdown-doctor not found for promotion gate" >&2
    failed=1
  fi

  if command -v mdown-book >/dev/null 2>&1; then
    validate_doctor_json "$staged_skill/schemas/mdown-book-doctor.schema.json" mdown-book "installed book" no-fail mdown-book --doctor --json
  elif [ -x "$HOME/.local/bin/mdown-book" ]; then
    validate_doctor_json "$staged_skill/schemas/mdown-book-doctor.schema.json" mdown-book "installed book" no-fail "$HOME/.local/bin/mdown-book" --doctor --json
  else
    echo "ERROR: mdown-book not found for promotion gate" >&2
    failed=1
  fi

  if command -v mdown-epub >/dev/null 2>&1; then
    validate_doctor_json "$staged_skill/schemas/mdown-epub-doctor.schema.json" mdown-epub "installed EPUB" no-fail mdown-epub --doctor --json
  elif [ -x "$HOME/.local/bin/mdown-epub" ]; then
    validate_doctor_json "$staged_skill/schemas/mdown-epub-doctor.schema.json" mdown-epub "installed EPUB" no-fail "$HOME/.local/bin/mdown-epub" --doctor --json
  else
    echo "ERROR: mdown-epub not found for promotion gate" >&2
    failed=1
  fi

  if command -v mdown-ocrpdf >/dev/null 2>&1; then
    validate_doctor_json "$staged_skill/schemas/mdown-ocrpdf-doctor.schema.json" mdown-ocrpdf "installed OCR" no-fail mdown-ocrpdf --doctor --json
  elif [ -x "$HOME/.local/bin/mdown-ocrpdf" ]; then
    validate_doctor_json "$staged_skill/schemas/mdown-ocrpdf-doctor.schema.json" mdown-ocrpdf "installed OCR" no-fail "$HOME/.local/bin/mdown-ocrpdf" --doctor --json
  else
    echo "ERROR: mdown-ocrpdf not found for promotion gate" >&2
    failed=1
  fi
fi

if [ "$failed" -ne 0 ]; then
  exit 1
fi

echo "OK: doc-to-md $mode release gate passed"
