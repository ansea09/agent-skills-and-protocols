#!/usr/bin/env bash
set -euo pipefail

skill_dir="${SPEECH_TO_MD_SKILL_DIR:-}"
if [ -z "$skill_dir" ]; then
  script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
  skill_dir="$(CDPATH= cd -- "$script_dir/.." && pwd)"
fi

bin_dir="${SPEECH_TO_MD_BIN_DIR:-$HOME/.local/bin}"
mkdir -p "$bin_dir"

shim="$bin_dir/speech-to-md"
target="$skill_dir/scripts/speech-to-md"

if [ ! -f "$target" ]; then
  echo "ERROR: missing speech-to-md script: $target" >&2
  exit 1
fi

ln -sf "$target" "$shim"
chmod +x "$target"

echo "Installed speech-to-md shim: $shim"
echo "Run: speech-to-md --doctor"
