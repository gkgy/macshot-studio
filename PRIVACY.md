# Studio privacy / Studio 隐私说明

Studio's webcam segmentation, face detection/centering, audio balancing and Whisper transcription run on the local Mac. Original media and project settings are stored locally. Whisper uses `local_files_only=True`; transcribing does not upload audio to a cloud transcription service.

Studio 的头像分割、人脸检测与居中、音量平衡、Whisper 转录均在本机执行，素材与项目设置保存在本地。字幕不会上传到云端转录服务。

Building resolves dependencies online. Installing Python packages or downloading model weights also uses the network. The inherited app has other features, including online OCR translation; this page does not claim every upstream feature is offline. See the [preserved upstream policy](PRIVACY.upstream.md) for its original description; Studio's supplied build compiles out cloud upload integrations and disables upstream automatic updates.

首次构建、Python 安装和模型下载需要联网。应用继承的其他功能（例如在线 OCR 翻译）仍可能访问网络；此说明不宣称全部原版功能均离线。提供的构建脚本采用 OFFLINE 功能版本，排除云上传集成，并关闭上游自动更新。

Studio runs without App Sandbox to invoke local Python/FFmpeg. macOS camera, microphone and screen permissions remain required. Do not publish your recording folder or model cache when contributing; provide minimal, redacted examples. Sponsors are listed only with their preferred public name; no payment records are required.

Studio 为调用本地 Python／FFmpeg 关闭 App Sandbox，仍需 macOS 摄像头、麦克风和录屏授权。提交问题时请提供最小、脱敏的复现素材，不要上传整个录制目录或模型缓存。赞助名单只需公开名字，不需要支付记录。
