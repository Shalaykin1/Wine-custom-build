#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Build Wine 11.6 for Winlator CMOD (StevenMXZ).

Usage:
  scripts/build-winlator-wine.sh <x64-x86|arm64ec|all>

Optional env vars:
  WINE_REPO              Upstream Git URL (default: https://github.com/wine-mirror/wine.git)
  WINE_REF               Upstream tag/branch (default: wine-11.6)
  WORK_DIR               Working directory (default: ./work)
  DIST_DIR               Output directory (default: ./dist)
  LLVM_MINGW_ROOT        Existing llvm-mingw path
  LLVM_MINGW_VERSION     llvm-mingw release tag if auto-downloading
  JOBS                   Parallel jobs (default: nproc)
  ANDROID_IMAGEFS_RPATH  Runtime linker path inside Winlator imagefs
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

VARIANT="${1:-all}"
case "$VARIANT" in
  x64-x86|arm64ec|all) ;;
  *)
    usage >&2
    exit 1
    ;;
esac

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-$ROOT_DIR/work}"
SRC_DIR="${SRC_DIR:-$WORK_DIR/wine-src}"
BUILD_ROOT="${BUILD_ROOT:-$WORK_DIR/build}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
WINE_REPO="${WINE_REPO:-https://github.com/wine-mirror/wine.git}"
WINE_REF="${WINE_REF:-wine-11.6}"
LLVM_MINGW_VERSION="${LLVM_MINGW_VERSION:-20251007}"
LLVM_MINGW_ROOT="${LLVM_MINGW_ROOT:-$WORK_DIR/toolchains/llvm-mingw-${LLVM_MINGW_VERSION}}"
JOBS="${JOBS:-$(nproc)}"
ANDROID_IMAGEFS_RPATH="${ANDROID_IMAGEFS_RPATH:-/data/data/com.winlator/files/imagefs/usr/lib}"
HOST_TRIPLE_ARM64="${HOST_TRIPLE_ARM64:-aarch64-linux-gnu}"
HOST_TOOLS_DIR="$BUILD_ROOT/wine-tools"

mkdir -p "$WORK_DIR" "$BUILD_ROOT" "$DIST_DIR"

log() {
  printf '\n[%s] %s\n' "$(date +'%H:%M:%S')" "$*"
}

require_cmds() {
  local missing=()
  for cmd in git curl tar python3 zstd xz; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    printf 'Missing required commands: %s\n' "${missing[*]}" >&2
    printf 'Run ./scripts/install-build-deps.sh first.\n' >&2
    exit 1
  fi
}

download_llvm_mingw() {
  if [[ -x "$LLVM_MINGW_ROOT/bin/clang" ]]; then
    return 0
  fi

  local archive_name="llvm-mingw-${LLVM_MINGW_VERSION}-ucrt-ubuntu-22.04-x86_64.tar.xz"
  local url="https://github.com/mstorsjo/llvm-mingw/releases/download/${LLVM_MINGW_VERSION}/${archive_name}"
  local toolchains_dir
  toolchains_dir="$(dirname "$LLVM_MINGW_ROOT")"

  log "Downloading ${archive_name}"
  mkdir -p "$toolchains_dir"
  rm -rf "${toolchains_dir}/.tmp-llvm-mingw"
  mkdir -p "${toolchains_dir}/.tmp-llvm-mingw"
  curl -fL "$url" -o "${toolchains_dir}/${archive_name}"
  tar -xJf "${toolchains_dir}/${archive_name}" -C "${toolchains_dir}/.tmp-llvm-mingw"
  rm -f "${toolchains_dir}/${archive_name}"

  local extracted
  extracted="$(find "${toolchains_dir}/.tmp-llvm-mingw" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
  mv "$extracted" "$LLVM_MINGW_ROOT"
  rmdir "${toolchains_dir}/.tmp-llvm-mingw"
}

clone_source() {
  if [[ ! -d "$SRC_DIR/.git" ]]; then
    log "Cloning Wine source (${WINE_REF})"
    git clone --depth 1 --branch "$WINE_REF" "$WINE_REPO" "$SRC_DIR"
    return 0
  fi

  log "Refreshing Wine source (${WINE_REF})"
  git -C "$SRC_DIR" fetch --depth 1 origin "$WINE_REF"
  git -C "$SRC_DIR" checkout --force FETCH_HEAD
  git -C "$SRC_DIR" clean -fdx
}

COMMON_DISABLE_FLAGS=(
  --disable-tests
  --disable-win16
  --without-capi
  --without-coreaudio
  --without-cups
  --without-gphoto
  --without-gstreamer
  --without-netapi
  --without-oss
  --without-pcsclite
  --without-piper
  --without-sane
  --without-udev
  --without-usb
  --without-v4l2
  --without-vosk
  --without-wayland
  --without-xinerama
)

build_host_tools() {
  log "Configuring host tools"
  rm -rf "$HOST_TOOLS_DIR"
  mkdir -p "$HOST_TOOLS_DIR"
  export PATH="$LLVM_MINGW_ROOT/bin:$PATH"

  pushd "$HOST_TOOLS_DIR" >/dev/null
  CC=clang CXX=clang++ "$SRC_DIR/configure" \
    --enable-win64 \
    --with-mingw=clang \
    "${COMMON_DISABLE_FLAGS[@]}"
  make __tooldeps__ -j"$JOBS"
  make -C nls -j"$JOBS" || true
  popd >/dev/null
}

flatten_destdir() {
  local destdir="$1"
  local prefix="$2"

  mkdir -p "$destdir/.runtime"
  if [[ -d "${destdir}${prefix}" ]]; then
    rsync -a "${destdir}${prefix}/" "$destdir/.runtime/"
  fi
}

package_variant() {
  local variant="$1"
  local destdir="$2"

  "$ROOT_DIR/scripts/package-wcp.sh" \
    --variant "$variant" \
    --input "$destdir/.runtime" \
    --output "$DIST_DIR" \
    --version "${WINE_REF#wine-}"
}

build_x64_x86() {
  local build_dir="$BUILD_ROOT/x64-x86"
  local stage_dir="$DIST_DIR/stage/x64-x86"
  local prefix="/opt/wine-${WINE_REF#wine-}-x64-x86"

  log "Building x64/x86 (WoW64) variant"
  rm -rf "$build_dir" "$stage_dir"
  mkdir -p "$build_dir" "$stage_dir"

  export PATH="$LLVM_MINGW_ROOT/bin:$PATH"
  export CC=clang
  export CXX=clang++
  export CFLAGS="-O2 -pipe -Wno-error=implicit-function-declaration -Wno-error=incompatible-pointer-types"
  export CROSSCFLAGS="$CFLAGS"
  export CROSSLDFLAGS="-s -Wl,--sort-common,--as-needed"

  pushd "$build_dir" >/dev/null
  "$SRC_DIR/configure" \
    --prefix "$prefix" \
    --enable-win64 \
    --with-mingw=clang \
    --enable-archs=i386,x86_64 \
    "${COMMON_DISABLE_FLAGS[@]}"
  make -j"$JOBS"
  make install DESTDIR="$stage_dir"
  popd >/dev/null

  flatten_destdir "$stage_dir" "$prefix"
  package_variant "x64-x86" "$stage_dir"
}

build_arm64ec() {
  local build_dir="$BUILD_ROOT/arm64ec"
  local stage_dir="$DIST_DIR/stage/arm64ec"
  local prefix="/opt/wine-${WINE_REF#wine-}-arm64ec"

  command -v "${HOST_TRIPLE_ARM64}-gcc" >/dev/null 2>&1 || {
    echo "Missing ${HOST_TRIPLE_ARM64}-gcc. Run ./scripts/install-build-deps.sh first." >&2
    exit 1
  }

  log "Building arm64ec variant"
  rm -rf "$build_dir" "$stage_dir"
  mkdir -p "$build_dir" "$stage_dir"

  export PATH="$LLVM_MINGW_ROOT/bin:$PATH"
  export PKG_CONFIG_LIBDIR="/usr/lib/${HOST_TRIPLE_ARM64}/pkgconfig:/usr/share/pkgconfig"
  export CC="${HOST_TRIPLE_ARM64}-gcc"
  export CXX="${HOST_TRIPLE_ARM64}-g++"
  export AR="${HOST_TRIPLE_ARM64}-ar"
  export RANLIB="${HOST_TRIPLE_ARM64}-ranlib"
  export STRIP="${HOST_TRIPLE_ARM64}-strip"
  export CFLAGS="-O2 -pipe -Wno-error=implicit-function-declaration -Wno-error=incompatible-pointer-types"
  export CROSSCFLAGS="$CFLAGS"
  export LDFLAGS="-s -Wl,--dynamic-linker=${ANDROID_IMAGEFS_RPATH}/ld-linux-aarch64.so.1 -Wl,-rpath=${ANDROID_IMAGEFS_RPATH} -Wl,--sort-common,--as-needed"
  export CROSSLDFLAGS="-s"

  pushd "$build_dir" >/dev/null
  "$SRC_DIR/configure" \
    --prefix "$prefix" \
    --enable-win64 \
    --with-mingw=clang \
    --enable-archs=arm64ec,aarch64,i386 \
    --host="$HOST_TRIPLE_ARM64" \
    host_alias="$HOST_TRIPLE_ARM64" \
    build_alias=x86_64-linux-gnu \
    --with-wine-tools="$HOST_TOOLS_DIR" \
    "${COMMON_DISABLE_FLAGS[@]}"
  make -j"$JOBS"
  make install DESTDIR="$stage_dir"
  popd >/dev/null

  flatten_destdir "$stage_dir" "$prefix"
  package_variant "arm64ec" "$stage_dir"
}

require_cmds
download_llvm_mingw
clone_source
build_host_tools

case "$VARIANT" in
  x64-x86)
    build_x64_x86
    ;;
  arm64ec)
    build_arm64ec
    ;;
  all)
    build_x64_x86
    build_arm64ec
    ;;
esac

log "Artifacts written to $DIST_DIR"
