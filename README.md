# ffmpeg-tiny

Minimal, self-compiled FFmpeg builds for Daggermap video backgrounds (and optional image decode).

Sibling of the ApoC monorepo (`../C`). Produces small static `libav*` archives (and optional shared objects) with only the demuxers/decoders Daggermap needs. Consumed later by `kineticon` behind `DAGGERMAP_VIDEO=1`; the `*_extra_images` preset also backs an FFmpeg path in the image API alongside stb_image.

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
| `h264_vp8_vp9` | h264, vp8, vp9 | mov, matroska | Recommended creator video set |
| `h264_vp8_vp9_extra` | + av1, gif, webp, apng/png | + avi, flv, gif, apng, image2 | Anim loops + AV1 + extra containers |
| `h264_vp8_vp9_extra_images` | + mjpeg, bmp, targa, psd, hdr, pnm | + image2pipe, image_*_pipe | Video + stb_image-parity stills |

All presets: `--disable-everything`, `--enable-small`, file protocol only, no programs/docs/network/filters/devices, `swscale` enabled (YUV→RGBA). Image-capable presets also `--enable-zlib` (PNG/APNG/lossless WebP).

## License note

These builds use FFmpeg's LGPL components only (no `--enable-gpl`, no x264/x265). Static linking into a closed binary has LGPL redistribution obligations (provide relinkable objects or prefer shared libs). Prefer shipping a small shared `libkineticon_av.so` / `.dylib` / `.dll` for compliance when we wire this into ApoC.

AV1 is included via FFmpeg's native decoder (LGPL). AOMedia publishes a royalty-free patent license for AV1; that is a stronger posture than HEVC, though third-party patent claims exist in the industry—treat as the usual codec diligence, not legal advice.

## Pin

Default source pin: FFmpeg **n7.1**. Bump deliberately; re-run `make sizes` after upgrades.
