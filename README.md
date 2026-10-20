# vidfix

[![Stars](https://img.shields.io/github/stars/sametcelikbicak/vidfix?style=social)](https://github.com/sametcelikbicak/vidfix)
[![Forks](https://img.shields.io/github/forks/sametcelikbicak/vidfix?style=social)](https://github.com/sametcelikbicak/vidfix)
[![Release](https://img.shields.io/github/v/release/sametcelikbicak/vidfix)](https://github.com/sametcelikbicak/vidfix/releases/latest)
[![CI](https://github.com/sametcelikbicak/vidfix/actions/workflows/test.yml/badge.svg)](https://github.com/sametcelikbicak/vidfix/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/github/license/sametcelikbicak/vidfix)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-11%2B-lightgrey.svg)](https://www.apple.com/macos/)
[![Linux](https://img.shields.io/badge/Linux-x86_64%2Farm64-lightgrey.svg)](https://www.kernel.org/)
[![Homebrew](https://img.shields.io/badge/brew-install_vidfix-orange?logo=homebrew)](https://github.com/sametcelikbicak/homebrew-tap)

Diagnose why a video will not play, and fix it in one command.

**🇹🇷 Türkçe: [README_TR.md](README_TR.md)**

```
$ vidfix check camera_xavc.mp4
File      : camera_xavc.mp4
Duration  : 00:00:04.00
Video     : h264 (High 4:2:2) 3840x2160 yuv422p10le 59.94fps 201860kb/s
Audio     : pcm_s16be
Hardware  : decoder cannot handle this file (software fallback)
Problems  :
  - 4:2:2/4:4:4 chroma - hardware decoders rarely support it
  - 10-bit colour depth - older GPUs cannot decode it
  - 2160p/59.94fps - too heavy for software decoding to keep up
Suggestion: vidfix "camera_xavc.mp4" --preset 1080p
```

---

## The problem

A video plays the audio but the picture stays frozen. This is not a player bug, it is a codec-support gap — and it has a very specific shape:

| Symptom | Cause |
| --- | --- |
| Sound plays, picture is frozen | The decoder cannot keep up. 4K 10-bit 4:2:2 in software decoding runs at roughly 15 fps on an older CPU |
| Picture is black, sound is fine | The hardware decoder rejected the chroma or bit-depth profile |
| "Unsupported codec" error | The codec is not H.264 / HEVC / VP9 / AV1 |

Camera formats are the usual trigger. Sony XAVC S, Canon XAVC, Panasonic AVCHD-Pro and many drone and phone outputs are **10-bit 4:2:2** (`yuv422p10le`). Almost every laptop GPU — and every consumer player — can decode 8-bit 4:2:0 (`yuv420p`) and nothing else. When the player falls back to software decoding, the picture freezes while the audio keeps running.

## The solution

`vidfix` converts the file to a profile that everything can play: **H.264, 8-bit, 4:2:0, AAC**. The source file is never modified.

```
camera_xavc.mp4   (h264 High 4:2:2 10-bit, 3840x2160, 269 Mbps)
        |
        |  vidfix camera_xavc.mp4
        v
camera_xavc_fixed.mp4   (h264 High 4:2:0 8-bit, 1920x1080, 12 Mbps, AAC)
        |
        v
   plays everywhere: VLC, QuickTime, browsers, phones, TV
```

## Install

```bash
# one-liner (recommended)
curl -fsSL https://raw.githubusercontent.com/sametcelikbicak/vidfix/v1.0.0/install.sh | bash

# or via Homebrew
brew tap sametcelikbicak/tap https://github.com/sametcelikbicak/homebrew-tap
brew trust sametcelikbicak/tap      # Homebrew requires trusting third-party taps
brew install vidfix

# or manually
git clone https://github.com/sametcelikbicak/vidfix
install -m 0755 vidfix/bin/vidfix ~/.local/bin/vidfix
```

Requires **ffmpeg** (`brew install ffmpeg` / `sudo apt install ffmpeg`) and macOS 11+ or Linux.

## Usage

### Diagnose first

```bash
vidfix check film.mp4        # why will this not play?
vidfix check ./videos/       # check every video in a folder
```

The exit code is `0` when the file is healthy and `1` when problems are found, so it can be used in scripts.

### Convert

```bash
vidfix film.mp4                      # -> film_fixed.mp4 (1080p, default)
vidfix ./videos                      # every video in the folder
vidfix film.mp4 --preset 2160p       # keep 4K, but 8-bit 4:2:0
```

The source file is **never** modified. Output is written next to the source as `<name>_fixed.mp4`.

### Options

| Option | Default | Meaning |
| --- | --- | --- |
| `--preset 720p\|1080p\|2160p` | `1080p` | Output resolution |
| `--bitrate 20M` | preset-dependent | Video bitrate (hardware encoders) |
| `--out <file.mp4>` | `<name>_fixed.mp4` | Output path for a single file |
| `--out-dir <folder>` | source folder | Where to write the output |
| `--force` | off | Overwrite an existing output file |
| `--dry-run` | off | Print the ffmpeg command, do not encode |
| `--no-hw` | off | Force software encoding (libx264) |

## How the decision is made

`vidfix check` reads the real stream properties with ffmpeg and flags:

- **4:2:2 / 4:4:4 chroma** — hardware decoders almost never support it
- **10-bit depth** — unsupported on older GPUs
- **4K with more than 30 fps** — too heavy for software decoding
- **unusual codec** — anything outside H.264 / HEVC / VP9 / AV1 / MPEG-4
- **missing video track** — broken container

It then tests hardware decoding for real — one frame through VideoToolbox, VA-API or CUDA — so the verdict is measured, not guessed.

For conversion it picks the best available encoder: VideoToolbox on macOS, NVENC on NVIDIA, otherwise software `libx264`.

## Examples

```bash
# a whole camera card, keeping 4K quality
vidfix /Volumes/SDCARD/DCIM --preset 2160p --bitrate 40M

# batch to another disk, overwriting a previous run
vidfix ./footage --out-dir ~/Movies/fixed --force

# see exactly what will run
vidfix film.mp4 --dry-run
```

## Project layout

```
bin/vidfix         the CLI (POSIX bash, macOS + Linux)
install.sh         curl | bash installer with sha256 verification
tests/run.sh       end-to-end test suite, generates its own fixtures
```

## Development

```bash
./tests/run.sh
```

The suite generates synthetic fixtures with ffmpeg and covers 24 assertions: diagnostics, conversion, output format, source-file integrity, folder mode, dry run, the CLI contract and the installer's sha256 verification.

CI runs the same suite on macOS and Linux, plus a release workflow that publishes the tarball and its checksum on every `v*` tag.

## Troubleshooting

**`ffmpeg not found`** — install ffmpeg: `brew install ffmpeg` or `sudo apt install ffmpeg`.

**Still freezes after converting** — the machine may be too slow even for 1080p. Try `--preset 720p`, or `--no-hw` if a hardware encoder produced a bad file.

**Conversion is very slow** — that is expected. 4K 10-bit sources must be decoded in software first, at roughly 0.2–0.5x realtime on an older CPU. A smaller `--preset` does not speed up decoding, only the encode.

## License

MIT — see [LICENSE](LICENSE).
