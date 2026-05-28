#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DEFAULT_SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd -P)"
if [[ -n "${DOC_TO_MD_SKILL_DIR:-}" ]]; then
  SKILL_DIR="$(cd "$DOC_TO_MD_SKILL_DIR" && pwd -P)"
else
  SKILL_DIR="$DEFAULT_SKILL_DIR"
fi
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
BIN_DIR="${DOC_TO_MD_BIN_DIR:-$HOME/.local/bin}"
TOOLS_DIR="${DOC_TO_MD_TOOLS_DIR:-$CODEX_HOME_DIR/tools}"

install_core=1
install_book=0
install_ocr=0
run_selftest=1
rebuild=0
wrappers_only=0
hash_locked=0
hash_profile="${DOC_TO_MD_HASH_PROFILE:-}"
core_requirements=""
book_requirements=""
ocr_requirements=""

usage() {
  cat <<'EOF'
Usage:
  bash scripts/install.sh [--core] [--book] [--ocr] [--all] [--wrappers-only] [--rebuild] [--no-selftest] [--hash-locked]

Installs the doc-to-md wrappers and selected local runtimes.

Defaults:
  - install core runtime and wrappers
  - do not install optional PyMuPDF book runtime unless --book or --all is passed
  - do not install optional OCRmyPDF runtime unless --ocr or --all is passed

Environment:
  CODEX_HOME              defaults to $HOME/.codex
  DOC_TO_MD_SKILL_DIR     defaults to the parent directory of this install script
  DOC_TO_MD_BIN_DIR       defaults to $HOME/.local/bin
  DOC_TO_MD_TOOLS_DIR     defaults to ${CODEX_HOME}/tools
  DOC_TO_MD_HASH_PROFILE  defaults to the detected platform/Python profile when --hash-locked is used
  PYTHON                  defaults to python3
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --core)
      install_core=1
      shift
      ;;
    --book)
      install_book=1
      shift
      ;;
    --ocr)
      install_ocr=1
      shift
      ;;
    --all)
      install_core=1
      install_book=1
      install_ocr=1
      shift
      ;;
    --rebuild)
      rebuild=1
      shift
      ;;
    --wrappers-only)
      install_core=0
      install_book=0
      install_ocr=0
      run_selftest=0
      wrappers_only=1
      shift
      ;;
    --hash-locked)
      hash_locked=1
      shift
      ;;
    --no-selftest)
      run_selftest=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'install.sh: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

PYTHON_BIN="${PYTHON:-python3}"
if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  printf 'install.sh: Python not found: %s\n' "$PYTHON_BIN" >&2
  exit 127
fi

python_tag() {
  "$PYTHON_BIN" - <<'PY'
import sys
print(f"py{sys.version_info.major}{sys.version_info.minor}")
PY
}

profile_python_tag() {
  local profile="$1"
  case "$profile" in
    *-py[0-9][0-9]) printf '%s\n' "${profile##*-}" ;;
    *) printf '\n' ;;
  esac
}

default_hash_profile() {
  local os_name
  local arch_name
  local py_tag
  os_name="$(uname -s)"
  arch_name="$(uname -m)"
  py_tag="$(python_tag)"

  case "$os_name:$arch_name" in
    Darwin:arm64) printf 'macos-arm64-%s\n' "$py_tag" ;;
    Darwin:x86_64) printf 'macos-intel-%s\n' "$py_tag" ;;
    Linux:x86_64) printf 'linux-x86_64-%s\n' "$py_tag" ;;
    *) printf '%s-%s-%s\n' "$os_name" "$arch_name" "$py_tag" | tr '[:upper:]' '[:lower:]' ;;
  esac
}

is_maintained_profile() {
  case "$1" in
    macos-arm64-py313|macos-intel-py312) return 0 ;;
    *) return 1 ;;
  esac
}

if [[ -z "$hash_profile" ]]; then
  hash_profile="$(default_hash_profile)"
fi

actual_python_tag="$(python_tag)"
required_python_tag="$(profile_python_tag "$hash_profile")"
if [[ -n "$required_python_tag" && "$required_python_tag" != "$actual_python_tag" ]]; then
  printf 'install.sh: hash profile %s requires Python %s, but %s is %s\n' \
    "$hash_profile" "$required_python_tag" "$PYTHON_BIN" "$actual_python_tag" >&2
  printf 'install.sh: set PYTHON to a matching interpreter, for example PYTHON=python3.12 for macos-intel-py312.\n' >&2
  exit 66
fi

mkdir -p "$BIN_DIR" "$TOOLS_DIR"

canonical_path() {
  "$PYTHON_BIN" - "$1" <<'PY'
from pathlib import Path
import sys

print(Path(sys.argv[1]).expanduser().resolve(strict=False))
PY
}

safe_rebuild_path() {
  local label="$1"
  local venv="$2"
  local expected_name=""
  case "$label" in
    core) expected_name="markitdown-core-venv" ;;
    book) expected_name="doc-to-md-book-venv" ;;
    ocr) expected_name="doc-to-md-ocr-venv" ;;
    *)
      printf 'install.sh: unknown runtime label for rebuild guard: %s\n' "$label" >&2
      exit 67
      ;;
  esac

  local resolved_tools
  local resolved_venv
  resolved_tools="$(canonical_path "$TOOLS_DIR")"
  resolved_venv="$(canonical_path "$venv")"

  if [[ -z "$resolved_tools" || "$resolved_tools" == "/" ]]; then
    printf 'install.sh: refusing unsafe DOC_TO_MD_TOOLS_DIR for rebuild: %s\n' "$TOOLS_DIR" >&2
    exit 67
  fi
  if [[ "$resolved_venv" != "$resolved_tools/$expected_name" ]]; then
    printf 'install.sh: refusing to rebuild unexpected %s venv path: %s\n' "$label" "$venv" >&2
    printf 'install.sh: expected exactly: %s/%s\n' "$resolved_tools" "$expected_name" >&2
    exit 67
  fi
}

shell_quote() {
  local value="$1"
  printf "'"
  printf "%s" "$value" | sed "s/'/'\\\\''/g"
  printf "'"
}

install_wrapper() {
  local name="$1"
  local target="$BIN_DIR/$name"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'set -euo pipefail\n'
    printf 'if [[ -z "${DOC_TO_MD_SKILL_DIR:-}" ]]; then\n'
    printf '  DOC_TO_MD_SKILL_DIR=%s\n' "$(shell_quote "$SKILL_DIR")"
    printf 'fi\n'
    printf 'if [[ -z "${DOC_TO_MD_BIN_DIR:-}" ]]; then\n'
    printf '  DOC_TO_MD_BIN_DIR=%s\n' "$(shell_quote "$BIN_DIR")"
    printf 'fi\n'
    printf 'if [[ -z "${DOC_TO_MD_TOOLS_DIR:-}" ]]; then\n'
    printf '  DOC_TO_MD_TOOLS_DIR=%s\n' "$(shell_quote "$TOOLS_DIR")"
    printf 'fi\n'
    printf 'export DOC_TO_MD_SKILL_DIR DOC_TO_MD_BIN_DIR DOC_TO_MD_TOOLS_DIR\n'
    printf 'wrapper="$DOC_TO_MD_SKILL_DIR/scripts/%s"\n' "$name"
    printf 'if [[ ! -x "$wrapper" ]]; then\n'
    printf '  printf "%s: wrapper not found or not executable: %%s\\n" "$wrapper" >&2\n' "$name"
    printf '  exit 127\n'
    printf 'fi\n'
    printf 'exec "$wrapper" "$@"\n'
  } > "$target"
  chmod 0755 "$target"
}

install_wrapper markitdown-local
install_wrapper mdown-doctor
install_wrapper mdown-book
install_wrapper mdown-ocrpdf
install_wrapper mdown-refresh-locks
install_wrapper mdown-markitdown-monitor
install_wrapper mdown-prepare-markitdown-upgrade
install_wrapper mdown-dependency-monitor
install_wrapper mdown-dependency-audit
ln -sfn "$BIN_DIR/markitdown-local" "$BIN_DIR/mdown"

select_requirements() {
  local component="$1"
  local default_requirements="$2"

  if [[ "$hash_locked" -eq 0 ]]; then
    local profiled_requirements="$SKILL_DIR/requirements-${component}.${hash_profile}.txt"
    if [[ -f "$profiled_requirements" ]]; then
      printf '%s\n' "$profiled_requirements"
    elif [[ "$component" == "core" && "$(uname -s):$(uname -m)" == "Darwin:x86_64" ]]; then
      printf 'install.sh: Codex on Intel macOS currently has a maintained core profile only for Python 3.12: macos-intel-py312\n' >&2
      printf 'install.sh: run with PYTHON=python3.12, or add a reviewed requirements-core.%s.txt profile before installing.\n' "$hash_profile" >&2
      exit 66
    else
      if ! is_maintained_profile "$hash_profile"; then
        printf 'install.sh: normal pinned install for unverified profile %s; hash-locked support requires a reviewed matching profile.\n' "$hash_profile" >&2
      fi
      printf '%s\n' "$default_requirements"
    fi
    return 0
  fi

  local hashed_requirements="$SKILL_DIR/requirements-${component}.${hash_profile}.hashes.txt"
  if [[ ! -f "$hashed_requirements" ]]; then
    printf 'install.sh: hash-locked requirements not found for %s profile %s: %s\n' \
      "$component" "$hash_profile" "$hashed_requirements" >&2
    printf 'install.sh: use normal pinned install without --hash-locked as candidate/unverified, or publish a matching platform/Python hash file.\n' >&2
    exit 66
  fi
  printf '%s\n' "$hashed_requirements"
}

install_runtime() {
  local label="$1"
  local venv="$2"
  local requirements="$3"

  if [[ "$rebuild" -eq 1 && -d "$venv" ]]; then
    safe_rebuild_path "$label" "$venv"
    rm -rf "$venv"
  fi
  if [[ ! -x "$venv/bin/python" ]]; then
    "$PYTHON_BIN" -m venv "$venv"
  fi
  if [[ "$hash_locked" -eq 1 ]]; then
    "$venv/bin/python" -m pip install --require-hashes -r "$requirements"
  else
    "$venv/bin/python" -m pip install --upgrade pip
    "$venv/bin/python" -m pip install -r "$requirements"
  fi
  printf '%s\n' "$requirements" > "$venv/.doc-to-md-requirements"
  printf '[ok] installed %s runtime at %s\n' "$label" "$venv"
}

if [[ "$install_core" -eq 1 ]]; then
  core_requirements="$(select_requirements core "$SKILL_DIR/requirements-core.txt")"
  install_runtime core "$TOOLS_DIR/markitdown-core-venv" "$core_requirements"
fi

if [[ "$install_book" -eq 1 ]]; then
  printf '[notice] The book audit workflow installs PyMuPDF, which is AGPL/commercial licensed. Review THIRD_PARTY_NOTICES.md before redistribution.\n'
  book_requirements="$(select_requirements book "$SKILL_DIR/requirements-book.txt")"
  install_runtime book "$TOOLS_DIR/doc-to-md-book-venv" "$book_requirements"
fi

if [[ "$install_ocr" -eq 1 ]]; then
  printf '[notice] The OCR workflow installs OCRmyPDF Python packages. External Tesseract must be installed separately and checked with mdown-ocrpdf --doctor.\n'
  ocr_requirements="$(select_requirements ocr "$SKILL_DIR/requirements-ocr.lock.txt")"
  install_runtime ocr "$TOOLS_DIR/doc-to-md-ocr-venv" "$ocr_requirements"
fi

if [[ "$wrappers_only" -eq 0 || -x "$TOOLS_DIR/markitdown-core-venv/bin/python" ]]; then
  MARKITDOWN_REQUIREMENTS="${core_requirements:-$SKILL_DIR/requirements-core.txt}" PATH="$BIN_DIR:$PATH" mdown-doctor
else
  printf '[warn] skipped mdown-doctor because the core runtime is not installed\n'
fi

if [[ "$install_book" -eq 1 ]]; then
  DOC_TO_MD_BOOK_REQUIREMENTS="${book_requirements:-$SKILL_DIR/requirements-book.txt}" PATH="$BIN_DIR:$PATH" mdown-book --doctor
fi

if [[ "$install_ocr" -eq 1 ]]; then
  DOC_TO_MD_OCR_REQUIREMENTS="${ocr_requirements:-$SKILL_DIR/requirements-ocr.lock.txt}" PATH="$BIN_DIR:$PATH" mdown-ocrpdf --doctor
fi

if [[ "$run_selftest" -eq 1 && "$install_core" -eq 1 ]]; then
  PATH="$BIN_DIR:$PATH" "$TOOLS_DIR/markitdown-core-venv/bin/python" "$SCRIPT_DIR/selftest_doc_to_md.py"
fi

if [[ "$wrappers_only" -eq 1 ]]; then
  printf '[ok] wrappers installed without rebuilding runtimes\n'
fi

printf '[ok] doc-to-md install complete\n'
printf 'Add %s to PATH if mdown is not found in new shells.\n' "$BIN_DIR"
