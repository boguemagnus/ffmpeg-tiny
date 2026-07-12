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

if [[ "$need_cfg" -eq 1 ]]; then
  echo "configure $PRESET -> $OUT"
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
    "${PRESET_ARGS[@]}"
  date -u +%Y-%m-%dT%H:%M:%SZ > "$stamp"
fi

make -j"$JOBS"
make install

# Also link a tiny probe binary so we can measure *linked* stripped size,
# not just .a archive bloat (archives contain unused objects).
PROBE_SRC="$ROOT/scripts/probe_link.c"
PROBE_BIN="$OUT/bin/kineticon_probe"
mkdir -p "$OUT/bin"
cc -O2 -s \
  -I"$OUT/include" \
  "$PROBE_SRC" \
  "$OUT/lib/libavformat.a" \
  "$OUT/lib/libavcodec.a" \
  "$OUT/lib/libswscale.a" \
  "$OUT/lib/libavutil.a" \
  -lm -lpthread \
  -o "$PROBE_BIN" 2>"$OUT/probe_link.log" || {
    echo "probe link failed; see $OUT/probe_link.log" >&2
    # Extra libs some configs need
    cc -O2 -s \
      -I"$OUT/include" \
      "$PROBE_SRC" \
      "$OUT/lib/libavformat.a" \
      "$OUT/lib/libavcodec.a" \
      "$OUT/lib/libswscale.a" \
      "$OUT/lib/libavutil.a" \
      -lm -lpthread -lz \
      -o "$PROBE_BIN"
  }

echo "installed $PRESET -> $OUT"
ls -lh "$OUT/lib"/*.a "$PROBE_BIN"
