# Macshot Studio

**English** | [简体中文](README.zh-CN.md)

A native macOS screenshot and recording app with local tools for making tutorial videos. Maintained by [gkgy](https://github.com/gkgy).

This is an independent fork of [sw33tLie/macshot](https://github.com/sw33tLie/macshot), based on **v4.4.0-beta.6** (`38cb9d27269ac34859d2dd17a7d58fbbece82a3a`). The original capture, annotation and video editor are upstream work. Studio adds the features below and retains the **GPLv3 license**. It is not an official macshot release.

[What changed](#added-on-top-of-macshot) · [Build](#build-from-source) · [Whisper setup](#local-whisper-captions) · [Sponsor](#sponsor) · [Chinese documentation](README.zh-CN.md)

## Added on top of macshot

| Area | Studio additions |
| --- | --- |
| Webcam backgrounds | **12 bright presets** with names and thumbnails; adjustable brightness and pattern size; custom-image option. Centered artwork stays visible in a small webcam bubble. Uses local Apple Vision person segmentation. |
| Portrait positioning | **Stable portrait centering** offsets head-position movement. Adjustable strength; keeps bubble size fixed during screen zooms. It preserves facial expressions and head rotation rather than freezing the person. |
| Small webcam bubble | New-project default is a **10%** bubble at the bottom right. Explicit sizes in existing projects are preserved. |
| Audio balancing | System audio and microphone tracks are balanced separately before mixing, then limited. MP4 export also balances audio. Native timestamp-aware decoding handles the recordings used during development. |
| Local captions | Local **faster-whisper** transcription, Chinese phrase grouping, and existing subtitle editing/SRT export. The Studio caption path does not require Siri or Dictation. |
| Whole-video speed | A visible **whole-video speed** control: **0.5×, 0.75×, 1×, 1.25×, 1.5×, 2×, 3×**. Shows estimated output duration, preserves pitch, and keeps webcam/captions aligned. 90 seconds at 1.5× becomes 60 seconds. |
| Independent app | “Macshot Studio”, separate app identifier/data folders, Studio settings, and upstream automatic updates disabled. The supplied build script compiles the offline variant. |

See [Studio changes](CHANGELOG.STUDIO.md) for version history and [the preserved upstream README](README.upstream.md) for inherited features.

## Using the new controls

- **Webcam:** open **Camera / Tech background** in the editor. The Background panel also has a shortcut to the webcam panel. Choose a preset or thumbnail, then adjust brightness, pattern size and stabilization strength. Current custom labels are Chinese; the underlying app also includes upstream language support.
- **Whole-video speed:** use the button above the timeline. Selecting 1× removes whole-video speed changes. This replaces existing speed segments; Undo restores them.
- **Audio:** automatic balancing is enabled by default for the app. Configure it in **Macshot Studio → Studio settings**. Volume matching is not perfect speech isolation; different microphones and source material may still need adjustment.
- **Captions:** configure Python and a local model first, then choose **Generate captions**. Review recognized text before publishing.

### What to expect

Webcam background replacement and portrait centering work in **editor playback and exported videos**. The floating webcam preview during recording shows the original feed. Original camera media is retained.

A separate `camera.mp4` in a Studio recording project is required. A flattened video cannot recover its original webcam layer. Face detection can fail during occlusion or large turns; that frame falls back to the original position. Centering reduces translation, not all body motion.

The source is published here; this repository does not currently provide an Apple-notarized public binary. Local ad-hoc builds require macOS permissions and may need permission renewal after rebuilding. This fork disables App Sandbox so it can run local Python/FFmpeg; macOS screen, microphone and camera permission controls still apply.

## Build from source

Requirements: a Mac, full Xcode with a recent macOS SDK, and an executable FFmpeg build. Development validation used Apple Silicon, Xcode 27.1 and macOS 27 SDK. Broader hardware/older-OS support has not been validated for the Studio additions. The inherited project deployment target is not a compatibility guarantee.

```bash
git clone --branch studio-custom https://github.com/gkgy/macshot-studio.git
cd macshot-studio
# Install FFmpeg separately, or provide its absolute path:
STUDIO_FFMPEG=/absolute/path/to/ffmpeg scripts/build-studio.sh
```

If `ffmpeg` is on `PATH`, simply run `scripts/build-studio.sh`. First build resolves SwiftPM dependencies over the network. Output:

```text
build/Build/Products/Release/Macshot Studio.app
```

The script builds Release + OFFLINE and signs locally with an ad-hoc signature. A dynamically linked FFmpeg may still depend on libraries outside the app; use a suitable self-contained build for portability. FFmpeg/model binaries are not included in the source repository. Before distributing your own binaries, retain required third-party license/source notices for the binaries you actually bundle.

### Local Whisper captions

Use Python 3.9+ compatible with the pinned faster-whisper dependency:

```bash
scripts/setup-whisper.sh
```

This installs `faster-whisper==1.2.1` into `~/.local/share/macshot-studio/whisper-venv`. Dependencies are downloaded during setup. Model weights are a separate download; for example:

```bash
~/.local/share/macshot-studio/whisper-venv/bin/python - <<'PY'
from huggingface_hub import snapshot_download
snapshot_download(
    repo_id="mobiuslabsgmbh/faster-whisper-large-v3-turbo",
    local_dir="models/faster-whisper-large-v3-turbo",
)
PY
```

In **Studio settings**, configure the Python executable above and the absolute path to your downloaded model folder. A blank model field checks the existing turbo-model cache. Transcription uses `local_files_only=True`: it does not automatically fetch weights or call a cloud transcription API. The current bridge is tuned for Chinese (`language='zh'`); English transcription is not a separately validated Studio feature.

### Validation

```bash
CONFIGURATION=Release scripts/run-tests.sh --offline StudioTests
```

Development checks: 9 Studio tests passed; Release build succeeded; local full-video export/decode and sampled portrait-position checks passed. Hardware/audio tests that require a local FFmpeg installation may skip on CI. CI results are shown under Actions; local results are not a promise that every environment has been tested.

## Sponsor

Thank you for supporting Macshot Studio! Sponsor names are maintained manually in **[SPONSORS.md](SPONSORS.md)**.

**No sponsors are listed yet.** After receiving support, the maintainer can add the sponsor's preferred public name and optional link. Amounts and private payment information are not required. No payment account or GitHub Sponsors enrollment is configured here yet.

## Credits and license

- Original application: [sw33tLie/macshot](https://github.com/sw33tLie/macshot), with its contributors and retained history/notices.
- Studio modifications: [gkgy](https://github.com/gkgy).
- Person segmentation/face detection: Apple Vision. Captions: faster-whisper/CTranslate2 and separately downloaded Whisper weights. Audio processing: FFmpeg.
- Application source remains under [GPLv3](LICENSE). See [third-party notes](THIRD_PARTY_NOTICES.md), [privacy](PRIVACY.md), and [contributing](CONTRIBUTING.md).
