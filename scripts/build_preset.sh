#!/usr/bin/env bash
# Build one named preset into out/<preset>/.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PRESET="${1:?usage: build_preset.sh <preset>}"
CFG="$ROOT/configs/${PRESET}.conf"
SRC="$ROOT/src"
OUT="$ROOT/out/${PRESET}"
BUILD="$SRC/build-${PRESET}"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"

# Prefer local nasm if present (no root install required).
if [[ -x "$ROOT/tools/nasm-prefix/bin/nasm" ]]; then
  export PATH="$ROOT/tools/nasm-prefix/bin:$PATH"
fi

if [[ ! -f "$CFG" ]]; then
  echo "unknown preset: $PRESET (missing $CFG)" >&2
  exit 1
fi
if [[ ! -x "$SRC/configure" ]]; then
  echo "missing FFmpeg source at $SRC" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$CFG"

mkdir -p "$BUILD" "$OUT"
cd "$BUILD"

# Reconfigure only when conf or configure stamp changes.
stamp="$BUILD/.configure.stamp"
need_cfg=1
if [[ -f "$stamp" ]] && [[ "$stamp" -nt "$CFG" ]] && [[ -f "$BUILD/ffbuild/config.mak" ]]; then
  need_cfg=0
fi

# Detect current platform (default to linux if environment variable is missing)
PLATFORM="${TARGET_PLATFORM:-linux}"

# Base architecture / cross-compile flags
EXTRA_CONF_ARGS=()
PROBE_CC="cc"
PROBE_LDFLAGS=("-lm" "-lpthread" "-lz")

case "$PLATFORM" in
  linux)
    # Native Linux build; defaults are fine
    ;;

  windows)
    # Cross-compile to x64 Windows using MinGW toolchain
    EXTRA_CONF_ARGS+=(
      "--target-os=mingw32" 
      "--cross-prefix=x86_64-w64-mingw32-" 
      "--arch=x86_64"
    )
    PROBE_CC="x86_64-w64-mingw32-gcc"
    # Windows doesn't strictly link -lm or -lpthread like Linux does
    PROBE_LDFLAGS=("-lz") 
    ;;

  macos)
    # Native Apple Silicon build on macOS runner
    EXTRA_CONF_ARGS+=(
      "--target-os=darwin" 
      "--arch=arm64"
    )
    ;;

  ios)
    # Dynamically find the iOS SDK sysroot path on macOS
    SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path)
    
    EXTRA_CONF_ARGS+=(
      "--target-os=darwin"
      "--arch=arm64"
      "--enable-cross-compile"
      "--cc=$(xcrun --sdk iphoneos -f clang)"
      "--extra-cflags=-arch arm64 -miphoneos-version-min=13.0 -isysroot $SDK_PATH"
      "--extra-ldflags=-arch arm64 -miphoneos-version-min=13.0 -isysroot $SDK_PATH"
    )
    ;;

  android)
    # 1. Cascaded search to find a valid NDK directory
    NDK_ROOT=""
    for candidate in \
      "${ANDROID_NDK_HOME:-}" \
      "${ANDROID_NDK_LATEST_HOME:-}" \
      "${ANDROID_SDK_ROOT:-/usr/local/lib/android/sdk}/ndk-bundle" \
      $(ls -d ${ANDROID_SDK_ROOT:-/usr/local/lib/android/sdk}/ndk/* 2>/dev/null | sort -V | tail -n 1); do
      if [[ -d "$candidate" ]]; then
        NDK_ROOT="$candidate"
        break
      fi
    done

    if [[ -z "$NDK_ROOT" ]]; then
      echo "Error: Android NDK could not be located." >&2
      exit 1
    fi

    TOOLCHAIN="$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64"
    
    # We use the explicit compiler script, which already self-packages target, sysroot, and headers.
    # FFmpeg requires '--cc' and '--cxx' for cross-compilation configurations.
    CC_COMPILER="$TOOLCHAIN/bin/aarch64-linux-android33-clang"
    CXX_COMPILER="$TOOLCHAIN/bin/aarch64-linux-android33-clang++"
    
    # Ensure the target compiler actually exists at the resolved path
    if [[ ! -x "$CC_COMPILER" ]]; then
      echo "Error: Compiler not found at $CC_COMPILER" >&2
      exit 1
    fi

    EXTRA_CONF_ARGS+=(
      "--target-os=android"
      "--arch=aarch64"
      "--enable-cross-compile"
      "--cc=$CC_COMPILER"
      "--cxx=$CXX_COMPILER"
    )
    ;;
esac

if [[ "$need_cfg" -eq 1 ]]; then
  echo "configure $PRESET [$PLATFORM] -> $OUT"
  # Expand PRESET_ARGS as words; configs define a bash array.
  "$SRC/configure" \
    --prefix="$OUT" \
    --enable-static \
    --disable-shared \
    --disable-programs \
    --disable-doc \
    --disable-htmlpages \
    --disable-manpages \
    --disable-podpages \
    --disable-txtpages \
    --disable-network \
    --disable-autodetect \
    --disable-debug \
    --disable-everything \
    --enable-avutil \
    --enable-avcodec \
    --enable-avformat \
    --enable-swscale \
    --disable-avdevice \
    --disable-avfilter \
    --disable-swresample \
    --disable-postproc \
    --enable-protocol=file \
    --enable-small \
    "${EXTRA_CONF_ARGS[@]}" \
    "${PRESET_ARGS[@]}"
  date -u +%Y-%m-%dT%H:%M:%SZ > "$stamp"
fi

make -j"$JOBS"
make install

echo "installed $PRESET [$PLATFORM] -> $OUT"
ls -lh "$OUT/lib"/*.a