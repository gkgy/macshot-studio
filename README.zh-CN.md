# Macshot Studio

[English](README.md) | **简体中文**

面向教程录制与视频整理的原生 macOS 截图、录屏工具，由 [gkgy](https://github.com/gkgy) 维护。

本项目是 [sw33tLie/macshot](https://github.com/sw33tLie/macshot) 的独立 Fork，基于 **v4.4.0-beta.6**（`38cb9d27269ac34859d2dd17a7d58fbbece82a3a`）修改。原有截图、标注、录屏和视频编辑器来自上游；本项目保留原作者归属、历史与 **GPLv3 许可**，并在此基础上增加以下功能。它不是 macshot 官方版本。

[新增功能](#在原版基础上增加了什么) · [编译安装](#从源码编译) · [本地字幕](#配置本地-whisper-字幕) · [Sponsor／赞助](#sponsor赞助)

## 在原版基础上增加了什么

| 功能 | Studio 新增内容 |
| --- | --- |
| 头像背景 | **12 款明亮背景**，支持名称下拉框与缩略图选择、亮度和纹理大小调节、自定义图片。图案集中在小头像可见区域，减少缩小后发黑的问题。使用 Apple Vision 在本机分割人像。 |
| 人物稳定 | **人物稳定居中**，通过人脸位置补偿减轻上下左右漂移，强度可调；稳定模式保持头像框大小，减少屏幕缩放造成的大小变化。保留表情和转头动作。 |
| 小头像默认值 | 新项目默认右下角 **10%** 小头像。已有项目明确保存的大小会保留。 |
| 自动平衡音量 | 系统音频与麦克风先分别平衡，再混合并限幅；MP4 导出也处理音量。使用保留时间戳的原生解码，适配开发时遇到的录制音轨。 |
| 本地字幕 | 使用本地 **faster-whisper**，增加中文分句，沿用字幕编辑与 SRT 导出；Studio 字幕流程不依赖 Siri／听写。 |
| 全片调速 | 时间线上方独立入口，提供 **0.5×、0.75×、1×、1.25×、1.5×、2×、3×**，显示预计成片时长；保持原音高，头像与字幕跟随时间轴。例如 90 秒以 1.5× 导出为 60 秒。 |
| 独立应用 | 应用名为 Macshot Studio，使用独立包名、数据目录和 Studio 设置；关闭上游自动更新，构建脚本采用离线功能版本。 |

版本记录见 [Studio 更新说明](CHANGELOG.STUDIO.md)；继承的原版能力见 [保留的上游 README](README.upstream.md)。

## 功能入口与使用说明

- **头像背景与稳定：** 编辑器左侧“摄像头 / 科技背景”。“背景”面板顶部也有“小头像 · 科技背景”入口。选择背景后，可调亮度、纹理大小和稳定强度。当前 Studio 新增控件文案以中文为主；底层应用保留上游语言支持。
- **全片调速：** 时间线上方“全片调速”。选 1× 清除全片变速；操作会替换已有速度片段，可撤销恢复。
- **声音：** 应用默认开启自动平衡，可在“Macshot Studio → Studio 定制设置”中关闭。它不是完美的人声隔离，不同话筒和视频来源仍可能需要手动微调。
- **字幕：** 先配置 Python 与本地模型，再点“生成字幕”。自动识别内容在发布前仍需校对。

### 效果范围与限制

头像背景、人像稳定在 **编辑器播放预览与导出成片** 中生效；录制时悬浮摄像头窗口显示原始画面，原摄像头素材保留。

项目必须有独立 `camera.mp4` 摄像头轨道。已经合成到普通视频里的头像无法还原为可独立编辑图层。人脸遮挡、大幅转头可能导致检测失败，该帧保留原始位置。稳定功能减少位置漂移，不会冻结表情、转头或所有身体动作。

本仓库提供源码，目前未提供经 Apple 公证的公开安装包。本机 ad-hoc 构建需要授予 macOS 权限，重新编译后可能需要刷新授权。为调用本地 Python／FFmpeg，本分支不启用 App Sandbox；录屏、摄像头和麦克风仍受 macOS 权限控制。

## 从源码编译

需要 Mac、完整 Xcode（包含较新的 macOS SDK）和可执行的 FFmpeg。开发验证环境为 Apple Silicon、Xcode 27.1、macOS 27 SDK。Studio 新功能尚未在所有旧系统、Intel Mac 上验证，原项目最低部署版本不代表已完成相应兼容测试。

```bash
git clone --branch studio-custom https://github.com/gkgy/macshot-studio.git
cd macshot-studio
STUDIO_FFMPEG=/绝对路径/ffmpeg scripts/build-studio.sh
```

如果 `ffmpeg` 已在 `PATH` 中，直接运行 `scripts/build-studio.sh`。首次构建会联网解析 SwiftPM 依赖。输出为：

```text
build/Build/Products/Release/Macshot Studio.app
```

脚本执行 Release + OFFLINE 构建并在本机签名。动态链接的 FFmpeg 可能仍依赖应用外的库；如需迁移，使用合适的自包含构建。源码仓库不包含 FFmpeg 可执行文件或模型权重。自行分发二进制时，应保留实际捆绑组件所要求的许可与源码说明。

### 配置本地 Whisper 字幕

使用与固定依赖版本兼容的 Python 3.9+：

```bash
scripts/setup-whisper.sh
```

脚本将 `faster-whisper==1.2.1` 安装到 `~/.local/share/macshot-studio/whisper-venv`，安装过程需要联网。模型权重需要单独下载，例如：

```bash
~/.local/share/macshot-studio/whisper-venv/bin/python - <<'PY'
from huggingface_hub import snapshot_download
snapshot_download(
    repo_id="mobiuslabsgmbh/faster-whisper-large-v3-turbo",
    local_dir="models/faster-whisper-large-v3-turbo",
)
PY
```

在“Studio 定制设置”中填写上述 Python 可执行文件路径，以及下载后模型目录的绝对路径。模型字段留空时检查已有 turbo 模型缓存。转录使用 `local_files_only=True`，不会自动下载模型或调用云端转录 API。当前桥接脚本固定 `language='zh'`，面向中文视频调优；英文语音识别不是已单独验证的 Studio 功能。

### 验证

```bash
CONFIGURATION=Release scripts/run-tests.sh --offline StudioTests
```

开发时 9 项 Studio 测试通过，Release 构建成功；完整视频导出、整段解码、人像位置抽查通过。需要本机 FFmpeg 的媒体测试在 CI 环境可能跳过。线上结果以 Actions 为准，已有本机验证不代表所有环境均已测试。

## Sponsor／赞助

感谢支持 Macshot Studio！赞助者名单统一手动维护在 **[SPONSORS.md](SPONSORS.md)**。

**目前尚未列出赞助者。** 收到支持后，维护者可添加赞助者希望公开的名字和可选链接；不要求公开金额或支付信息。目前未配置收款账号或 GitHub Sponsors 收款资格。

## 致谢与许可

- 原项目：[sw33tLie/macshot](https://github.com/sw33tLie/macshot) 及其贡献者，保留原始历史和声明。
- Studio 定制修改：[gkgy](https://github.com/gkgy)。
- 人像分割、人脸检测：Apple Vision；字幕：faster-whisper／CTranslate2 与另行下载的 Whisper 权重；声音处理：FFmpeg。
- 应用源码继续使用 [GPLv3](LICENSE)。另见 [第三方说明](THIRD_PARTY_NOTICES.md)、[隐私说明](PRIVACY.md)、[贡献指南](CONTRIBUTING.md)。
