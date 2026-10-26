# Third-party notices / 第三方说明

## Upstream application / 上游应用

Macshot Studio derives from [sw33tLie/macshot](https://github.com/sw33tLie/macshot), base tag v4.4.0-beta.6, commit `38cb9d27269ac34859d2dd17a7d58fbbece82a3a`. Original copyright notices, commit history and [GPLv3 license text](LICENSE) are retained. Studio modifications are maintained by gkgy. This fork is not endorsed by the upstream author.

Macshot Studio 基于上述上游项目，保留原始版权声明、提交历史和 GPLv3 许可；Studio 修改由 gkgy 维护，不代表获得上游作者背书。

## Components / 组件

- **Apple Vision / Core Image / AVFoundation:** macOS system frameworks for segmentation, face detection, rendering and media processing.
- **faster-whisper / CTranslate2:** separately installed local Python transcription runtime. See their own licenses in the installed packages; weights have separate model terms. Model files are not included here.
- **FFmpeg:** separately supplied by the builder. Its enabled components and license depend on that build. `scripts/build-studio.sh` captures `ffmpeg -L` from the actual executable into the app; the repository's `studio-resources/FFmpeg-LICENSE.txt` documents the development executable only. A compiled FFmpeg binary is not tracked in this repository.
- **Sparkle, Swift-WebP and libwebp:** inherited SwiftPM dependencies; exact versions and upstream references are in `macshot.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`. Upstream automatic updating is disabled in the Studio startup path.
- **Studio artwork:** the 12 background presets are generated from the Swift source in `StudioCameraBackgrounds.swift`. `StudioBackground.png` is an AI-generated legacy background retained as an optional preset. It contains no recorded webcam imagery.

模型权重、FFmpeg 二进制未随源码提供。自行分发安装包时，请使用与实际组件对应的许可、声明和必要源码材料。开发机器上使用的 FFmpeg 许可信息不能代替你自己构建所用组件的说明。
