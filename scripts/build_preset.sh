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

# Prefer vendored Vulkan headers (see scripts/ensure_vulkan_headers.sh).
# Ubuntu apt libvulkan-dev is often < 1.3.277 required by FFmpeg n7.1.
if [[ -f "$ROOT/tools/pkgconfig/vulkan.pc" ]]; then
  export PKG_CONFIG_PATH="$ROOT/tools/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
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

# Detect current platform (default to linux if environment variable is missing)
PLATFORM="${TARGET_PLATFORM:-linux}"
# Windows DX11 alt build: HW_API=d3d11; default Vulkan for linux/windows Vulkan SKUs.
HW_API="${HW_API:-}"

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
    # Dynamically find the iOS device SDK sysroot path on macOS
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

  ios-simulator)
    # arm64 iPhone Simulator (Apple Silicon). Device .a cannot link into sim.
    SDK_PATH=$(xcrun --sdk iphonesimulator --show-sdk-path)

    EXTRA_CONF_ARGS+=(
      "--target-os=darwin"
      "--arch=arm64"
      "--enable-cross-compile"
      "--cc=$(xcrun --sdk iphonesimulator -f clang)"
      "--extra-cflags=-arch arm64 -mios-simulator-version-min=13.0 -isysroot $SDK_PATH"
      "--extra-ldflags=-arch arm64 -mios-simulator-version-min=13.0 -isysroot $SDK_PATH"
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

# GPU-aligned hwaccel for presets that set PRESET_ENABLE_HW=1.
# Soft video decoders in PRESET_ARGS remain as FFmpeg hwaccel shells.
# Vulkan needs headers only at build time (no GPU on the builder).
append_vulkan_hwaccel() {
  local vk_inc="$ROOT/tools/vulkan-headers/include"
  EXTRA_CONF_ARGS+=(
    "--enable-vulkan"
    "--enable-hwaccel=h264_vulkan,av1_vulkan"
  )
  # MinGW (and some hosts) won't see /usr/include; force vendored headers when present.
  if [[ -d "$vk_inc" ]]; then
    EXTRA_CONF_ARGS+=("--extra-cflags=-I${vk_inc}")
  fi
}

if [[ "${PRESET_ENABLE_HW:-0}" == "1" ]]; then
  case "$PLATFORM" in
    linux)
      append_vulkan_hwaccel
      ;;
    windows)
      case "${HW_API:-vulkan}" in
        d3d11)
          EXTRA_CONF_ARGS+=(
            "--enable-d3d11va"
            "--enable-hwaccel=h264_d3d11va,h264_d3d11va2,vp9_d3d11va,vp9_d3d11va2,av1_d3d11va,av1_d3d11va2"
          )
          ;;
        vulkan)
          append_vulkan_hwaccel
          ;;
        *)
          echo "Error: unsupported HW_API=${HW_API} (use vulkan or d3d11)" >&2
          exit 1
          ;;
      esac
      ;;
    macos|ios|ios-simulator)
      EXTRA_CONF_ARGS+=(
        "--enable-videotoolbox"
        "--enable-hwaccel=h264_videotoolbox,vp9_videotoolbox,mpeg4_videotoolbox"
      )
      ;;
    android)
      EXTRA_CONF_ARGS+=(
        "--enable-jni"
        "--enable-mediacodec"
        "--enable-decoder=h264_mediacodec,mpeg4_mediacodec,vp8_mediacodec,vp9_mediacodec,av1_mediacodec"
      )
      ;;
    *)
      echo "Error: PRESET_ENABLE_HW=1 unsupported for PLATFORM=$PLATFORM" >&2
      exit 1
      ;;
  esac
fi

# Reconfigure when conf, script, platform, or HW_API identity changes.
stamp="$BUILD/.configure.stamp"
stamp_id="${PLATFORM}:${HW_API:-}:${PRESET_ENABLE_HW:-0}"
need_cfg=1
if [[ -f "$stamp" ]] && [[ "$stamp" -nt "$CFG" ]] && [[ "$stamp" -nt "$0" ]] \
  && [[ -f "$BUILD/ffbuild/config.mak" ]] \
  && [[ "$(cat "$stamp" 2>/dev/null | head -1)" == "$stamp_id" ]]; then
  need_cfg=0
fi

if [[ "$need_cfg" -eq 1 ]]; then
  echo "configure $PRESET [$PLATFORM${HW_API:+/$HW_API}] -> $OUT"
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
  printf '%s\n%s\n' "$stamp_id" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$stamp"
fi

make -j"$JOBS"
make install

echo "installed $PRESET [$PLATFORM${HW_API:+/$HW_API}] -> $OUT"
ls -lh "$OUT/lib"/*.a