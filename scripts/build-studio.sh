#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcodebuild -project macshot.xcodeproj -scheme macshot -configuration Release -derivedDataPath build -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO SWIFT_ACTIVE_COMPILATION_CONDITIONS=OFFLINE MARKETING_VERSION=0.2.0 CURRENT_PROJECT_VERSION=3 build > studio-build.log 2>&1
studio_app='build/Build/Products/Release/Macshot Studio.app'
cp studio-resources/StudioBackground.png "$studio_app/Contents/Resources/"
cp studio-resources/studio-whisper.py "$studio_app/Contents/Resources/"
studio_ffmpeg="${STUDIO_FFMPEG:-$(command -v ffmpeg || true)}"
if [[ -z "$studio_ffmpeg" && -x "$HOME/Documents/moxingdeep/bin/ffmpeg" ]]; then
    studio_ffmpeg="$HOME/Documents/moxingdeep/bin/ffmpeg"
fi
if [[ ! -x "$studio_ffmpeg" ]]; then
    echo 'FFmpeg not found. Install it or set STUDIO_FFMPEG=/absolute/path/to/ffmpeg.' >&2
    exit 1
fi
cp "$studio_ffmpeg" "$studio_app/Contents/Resources/studio-ffmpeg"
cp LICENSE "$studio_app/Contents/Resources/Upstream-GPLv3-LICENSE.txt"
"$studio_ffmpeg" -L > "$studio_app/Contents/Resources/FFmpeg-LICENSE.txt" 2>&1
chmod +x "$studio_app/Contents/Resources/studio-ffmpeg"
codesign --force --sign - "$studio_app/Contents/Resources/studio-ffmpeg"
codesign --force --deep --sign - --entitlements studio.entitlements "$studio_app"
codesign --verify --deep --strict "$studio_app"
echo "$PWD/$studio_app"
