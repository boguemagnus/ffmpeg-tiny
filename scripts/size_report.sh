#!/usr/bin/env bash
# Emit markdown size table for all built presets under out/.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/out"

bytes() {
  local f="$1"
  if [[ -f "$f" ]]; then
    wc -c <"$f" | tr -d ' '
  else
    echo 0
  fi
}

human() {
  local b="$1"
  if command -v numfmt >/dev/null 2>&1; then
    numfmt --to=iec --suffix=B "$b"
  else
    echo "${b}B"
  fi
}

sum_libs() {
  local dir="$1"
  local total=0
  local f
  for f in libavutil.a libavcodec.a libavformat.a libswscale.a; do
    total=$((total + $(bytes "$dir/lib/$f")))
  done
  echo "$total"
}

bt() { printf '`%s`' "$1"; }

echo "# FFmpeg tiny — size report"
echo
echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo
echo "Host: $(uname -m) $(uname -s)"
echo
echo "Measurements:"
echo
echo "- **.a sum** — libavutil + libavcodec + libavformat + libswscale archive bytes (upper bound; unused objects remain)."
echo "- **probe stripped** — tiny program statically linked against those libs, then cc -s (closest to app binary delta)."
echo

echo "| Preset | .a sum | probe stripped | configs |"
echo "|--------|-------:|---------------:|---------|"

shopt -s nullglob
for dir in "$OUT"/*/; do
  preset="$(basename "$dir")"
  a_sum=$(sum_libs "$dir")
  probe=$(bytes "$dir/bin/kineticon_probe")
  cfg=""
  if [[ -f "$ROOT/configs/${preset}.conf" ]]; then
    # shellcheck disable=SC1090
    source "$ROOT/configs/${preset}.conf"
    cfg="${PRESET_SUMMARY:-}"
  fi
  echo "| $(bt "$preset") | $(human "$a_sum") | $(human "$probe") | $cfg |"
done

echo
echo "## Per-library breakdown"
echo
echo "| Preset | avutil | avcodec | avformat | swscale |"
echo "|--------|-------:|--------:|---------:|--------:|"

for dir in "$OUT"/*/; do
  preset="$(basename "$dir")"
  echo "| $(bt "$preset") | $(human "$(bytes "$dir/lib/libavutil.a")") | $(human "$(bytes "$dir/lib/libavcodec.a")") | $(human "$(bytes "$dir/lib/libavformat.a")") | $(human "$(bytes "$dir/lib/libswscale.a")") |"
done

echo
echo "## Notes"
echo
echo "- Prefer **probe stripped** when budgeting Daggermap binary growth."
echo "- Cross-compile (Windows/macOS/Android) sizes will differ; re-run per target before shipping."
echo "- VP9 decoder tables dominate growth past H.264-only."
echo "- Host build used nasm (x86asm enabled). Without nasm, configure needs --disable-x86asm (slower; size differs)."
