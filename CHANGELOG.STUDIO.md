# Studio changes / Studio 更新记录

Studio is based on upstream macshot v4.4.0-beta.6 (`38cb9d27269ac34859d2dd17a7d58fbbece82a3a`). Inherited upstream history is in [CHANGELOG.md](CHANGELOG.md).
Studio 基于上述上游版本；原版更新记录保留在 CHANGELOG.md。

## 0.2.0 — 2026-10-26

- Added 12 centered, bright webcam backgrounds, with names, thumbnails, brightness and pattern-size controls. 新增 12 款适合小头像的明亮背景、名称和缩略图选择、亮度和纹理大小调节。
- Added face-position-based portrait centering and adjustable strength; stabilization keeps bubble size fixed during screen zooms. 新增人物稳定居中和强度调节；稳定模式固定头像框尺寸。
- Preserved expressions/head turns and original camera media. Detection failures retain the original position for that frame. 保留表情、转头和原始摄像头素材；检测失败帧保留原始位置。

## 0.1.1 — 2026-10-25

- Added a visible whole-video speed control with estimated duration. 新增直接可见的全片调速入口及预计成片时长。
- Added a webcam-background shortcut in the Background panel, clearer labels, and a missing-camera-track explanation. 新增头像背景快捷入口、明确标签和缺少摄像头轨道时的说明。

## 0.1.0 — 2026-10-25

- Added local webcam segmentation/background replacement and a 10% bubble default. 新增本地人像分割、头像背景替换和 10% 小头像默认值。
- Added local faster-whisper captions, Chinese phrase splitting and a configurable Python/model path. 新增本地 Whisper 字幕、中文分句及 Python／模型路径设置。
- Added automatic audio balancing, native timestamp-aware audio extraction and pitch-preserving whole-video speed presets. 新增自动平衡音量、保留时间戳的原生音频提取、保持原音高的全片变速。
- Created independent Macshot Studio app identity, data folders and offline build packaging. 新增独立应用标识、数据目录和离线构建打包。

## Source publication / 源码公开整理 — 2026-10-26

- Added English/Chinese READMEs, an empty sponsor wall with manual update instructions, attribution and third-party notes. 新增中英文首页、可手动维护的空赞助墙、上游归属和第三方说明。
- Made FFmpeg build input configurable and added a standard local Whisper environment setup script. 增加可配置的 FFmpeg 构建路径与标准本地 Whisper 环境安装脚本。
- Kept upstream publishing workflows as reference files rather than enabling upstream signing, Sparkle or Homebrew release jobs in this fork. 上游发布工作流作为参考保留，不在本分支启用原作者的签名、更新源和 Homebrew 发布流程。
