#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/package-wcp.sh --variant <x64-x86|arm64ec> --input <runtime-dir> [--output <dist-dir>] [--version <11.6>]
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

VARIANT=""
INPUT_DIR=""
OUTPUT_DIR="$(pwd)/dist"
VERSION="11.6"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --variant)
      VARIANT="$2"
      shift 2
      ;;
    --input)
      INPUT_DIR="$2"
      shift 2
      ;;
    --output)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --version)
      VERSION="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

[[ -n "$VARIANT" && -n "$INPUT_DIR" ]] || {
  usage >&2
  exit 1
}
[[ -d "$INPUT_DIR" ]] || {
  echo "Input runtime dir not found: $INPUT_DIR" >&2
  exit 1
}

case "$VARIANT" in
  x64-x86)
    ARCH_SUFFIX="x86_64"
    ARTIFACT_SUFFIX="x64-x86"
    DISPLAY_VARIANT="x64/x86 (WoW64)"
    ;;
  arm64ec)
    ARCH_SUFFIX="arm64ec"
    ARTIFACT_SUFFIX="arm64ec"
    DISPLAY_VARIANT="arm64ec"
    ;;
  *)
    echo "Unsupported variant: $VARIANT" >&2
    exit 1
    ;;
esac

mkdir -p "$OUTPUT_DIR"
STAGE_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGE_DIR"' EXIT

for dir in bin lib share; do
  if [[ -d "$INPUT_DIR/$dir" ]]; then
    cp -a "$INPUT_DIR/$dir" "$STAGE_DIR/$dir"
  fi
done

if [[ -d "$INPUT_DIR/share/default_pfx" ]]; then
  tar -cJf "$STAGE_DIR/prefixPack.txz" --transform 's,^\./,.wine/,' -C "$INPUT_DIR/share/default_pfx" .
  rm -rf "$STAGE_DIR/share/default_pfx"
else
  tar -cJf "$STAGE_DIR/prefixPack.txz" --files-from /dev/null
fi

export WCP_NAME="Wine ${VERSION} ${DISPLAY_VARIANT}"
export WCP_DESC="Wine ${VERSION} build for Winlator CMOD (StevenMXZ)"
export WCP_VERSION="$VERSION"
export WINE_VERSION_ID="wine-${VERSION}-${ARCH_SUFFIX}"
export PROFILE_VERSION_NAME="${VERSION}-${ARCH_SUFFIX}"
export PROFILE_VERSION_CODE="1"
export STAGE_DIR

python3 - <<'PY'
import json
import os
from pathlib import Path

stage = Path(os.environ["STAGE_DIR"])
wcp = {
    "name": os.environ["WCP_NAME"],
    "version": os.environ["WCP_VERSION"],
    "description": os.environ["WCP_DESC"],
    "wine_version": os.environ["WINE_VERSION_ID"],
}
profile = {
    "name": os.environ["WCP_NAME"],
    "versionName": os.environ["PROFILE_VERSION_NAME"],
    "versionCode": int(os.environ["PROFILE_VERSION_CODE"]),
    "description": os.environ["WCP_DESC"],
    "prefixPack": "prefixPack.txz",
}
(stage / "wcp.json").write_text(json.dumps(wcp, indent=2) + "\n", encoding="utf-8")
(stage / "profile.json").write_text(json.dumps(profile, indent=2) + "\n", encoding="utf-8")
PY

OUT_BASE="wine-${VERSION}-${ARTIFACT_SUFFIX}"
ARCHIVE_ROOT="$OUT_BASE"
ARCHIVE_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGE_DIR" "$ARCHIVE_DIR"' EXIT
mkdir -p "$ARCHIVE_DIR/$ARCHIVE_ROOT"
rsync -a "$INPUT_DIR/" "$ARCHIVE_DIR/$ARCHIVE_ROOT/"

tar -cJf "$OUTPUT_DIR/${OUT_BASE}.tar.xz" -C "$ARCHIVE_DIR" "$ARCHIVE_ROOT"
(
  cd "$STAGE_DIR"
  tar --zstd -cf "$OUTPUT_DIR/${OUT_BASE}.wcp" .
)

echo "Created:"
echo "  $OUTPUT_DIR/${OUT_BASE}.tar.xz"
echo "  $OUTPUT_DIR/${OUT_BASE}.wcp"
