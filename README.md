# ffmpeg-tiny

Minimal, self-compiled FFmpeg builds for Daggermap video backgrounds.

Sibling of the ApoC monorepo (`../C`). Produces small static `libav*` archives (and optional shared objects) with only the demuxers/decoders Daggermap needs. Consumed later by `kineticon` behind `DAGGERMAP_VIDEO=1`.

## Why

Per-platform Media Foundation / AVFoundation / MediaCodec / libvpx stacks are a lot of code for the same job. A trimmed FFmpeg decode path is one backend, one build recipe, and ~1–3 MiB of binary depending on codec set.

## Layout

```
src/           FFmpeg source (shallow clone; not committed)
configs/       Named configure presets
scripts/       Build + size report helpers
out/<preset>/  Install prefix per preset (libs, headers)
SIZE_REPORT.md Generated after `make sizes`
```

## Quick start

```bash
# First time: ensure src/ exists (n7.1 tag)
git clone --depth 1 --branch n7.1 https://github.com/FFmpeg/FFmpeg.git src

# Build all size-comparison presets (Linux host)
make sizes

# Or one preset
make build PRESET=h264
make build PRESET=h264_vp8_vp9
```

## Presets

| Preset | Decoders | Demuxers | Intent |
|--------|----------|----------|--------|
| `h264` | h264 | mov | Minimal MP4/H.264 |
| `h264_vp8` | h264, vp8 | mov, matroska | MP4 + WebM/VP8 |
| `h264_vp8_vp9` | h264, vp8, vp9 | mov, matroska | Recommended creator set |
| `h264_vp8_vp9_extra` | same | mov, matroska, avi, flv | Optional wrappers if size OK |

All presets: `--disable-everything`, `--enable-small`, file protocol only, no programs/docs/network/filters/devices, `swscale` enabled (YUV→RGBA).

## License note

These builds use FFmpeg's LGPL components only (no `--enable-gpl`, no x264/x265). Static linking into a closed binary has LGPL redistribution obligations (provide relinkable objects or prefer shared libs). Prefer shipping a small shared `libkineticon_av.so` / `.dylib` / `.dll` for compliance when we wire this into ApoC.

## Pin

Default source pin: FFmpeg **n7.1**. Bump deliberately; re-run `make sizes` after upgrades.
