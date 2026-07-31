#!/usr/bin/env bash
# Ensure Vulkan headers meet FFmpeg n7.1's floor (vulkan >= 1.3.277).
# Ubuntu 24.04 ships ~1.3.275 via libvulkan-dev, which fails configure.
# Writes tools/vulkan-headers/ + tools/pkgconfig/vulkan.pc and prints
# exports for PKG_CONFIG_PATH / extra include (safe for native + MinGW).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VER="${VULKAN_HEADERS_VER:-1.3.296}"
HDR_DIR="$ROOT/tools/vulkan-headers"
PC_DIR="$ROOT/tools/pkgconfig"
PC="$PC_DIR/vulkan.pc"

need_fetch=1
if [[ -f "$HDR_DIR/include/vulkan/vulkan.h" ]]; then
  hv="$(sed -n 's/^#define VK_HEADER_VERSION[[:space:]]*\([0-9][0-9]*\).*/\1/p' \
    "$HDR_DIR/include/vulkan/vulkan_core.h" | head -1)"
  if [[ -n "${hv:-}" ]] && (( hv >= 277 )); then
    need_fetch=0
  fi
fi

if [[ "$need_fetch" -eq 1 ]]; then
  echo "fetching Vulkan-Headers v${VER} -> $HDR_DIR"
  rm -rf "$HDR_DIR"
  git clone --depth 1 --branch "v${VER}" \
    https://github.com/KhronosGroup/Vulkan-Headers.git "$HDR_DIR"
fi

mkdir -p "$PC_DIR"
cat > "$PC" <<EOF
prefix=$HDR_DIR
includedir=\${prefix}/include

Name: Vulkan-Headers
Description: Vulkan API headers (CI/local override for FFmpeg)
Version: ${VER}
Cflags: -I\${includedir}
EOF

echo "Vulkan headers ready (v${VER})"
echo "export PKG_CONFIG_PATH=\"${PC_DIR}\${PKG_CONFIG_PATH:+:\$PKG_CONFIG_PATH}\""
