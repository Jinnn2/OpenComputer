# Windows Host

Windows Host 是被控端，负责屏幕采集、编码、WebRTC 发送、输入注入和高权限辅助。

## 目标职责

```text
capture   屏幕采集
encoder   GPU 编码
network   WebRTC 连接
input     鼠标键盘注入
service   开机自启和在线状态
agent     用户会话采集与控制进程
privilege 高权限 Broker
security 设备绑定和策略校验
```

## 当前 V0 实现

当前 V0 先使用 PowerShell + FFmpeg 建立可运行原型：

```text
gdigrab desktop capture -> H.264 encode -> MP4 file or UDP MPEG-TS
```

脚本位置：

```text
host-windows/scripts/capture-v0.ps1
host-windows/scripts/check-v0.ps1
host-windows/scripts/accept-v0.ps1
```

配置示例：

```text
host-windows/config/host-v0.example.json
```

这条链路的目标是尽快验证分辨率、帧率、码率、NVENC 可用性和 Android 端可解码性。后续再把采集和编码封装迁移到 C# 或 Rust。

## FFmpeg 查找规则

脚本按顺序查找 FFmpeg：

```text
1. -FfmpegPath 显式参数
2. FFMPEG_PATH 环境变量
3. tools/ffmpeg/bin/ffmpeg.exe
4. PATH 中的 ffmpeg.exe
```

当前 Codex 环境没有安装 FFmpeg；在你的本机安装后即可直接运行脚本。

## 安装项目内 FFmpeg

如果系统 PATH 没有 FFmpeg，可以下载 portable FFmpeg 到项目内：

```powershell
powershell -ExecutionPolicy Bypass -File host-windows\scripts\install-ffmpeg.ps1
```

脚本会下载 gyan.dev 的 `ffmpeg-release-essentials.zip`，校验 SHA256，然后把可执行文件放到：

```text
tools/ffmpeg/bin/ffmpeg.exe
```

## V0 验收脚本

执行 Host V0 的批量验收：

```powershell
powershell -ExecutionPolicy Bypass -File host-windows\scripts\accept-v0.ps1
```

验收脚本会依次执行：

```text
1. FFmpeg / H.264 encoder preflight
2. 配置文件 dry-run
3. CPU 编码 dry-run
4. UDP MPEG-TS dry-run
5. 若 preflight 通过，则录制一个短 MP4 样片
6. 使用 ffprobe 检查样片元数据
```

报告输出到：

```text
artifacts/host-v0/acceptance-*.md
```

## V0 预检

检查 FFmpeg、H.264 编码器和推荐命令：

```powershell
powershell -ExecutionPolicy Bypass -File host-windows\scripts\check-v0.ps1
```

顺便测试一帧桌面采集：

```powershell
powershell -ExecutionPolicy Bypass -File host-windows\scripts\check-v0.ps1 -TestCapture
```

## V0 使用方式

只打印命令，不实际录制：

```powershell
powershell -ExecutionPolicy Bypass -File host-windows\scripts\capture-v0.ps1 -DryRun -Encoder libx264
```

使用 NVENC 录制 MP4：

```powershell
powershell -ExecutionPolicy Bypass -File host-windows\scripts\capture-v0.ps1 `
  -Mode file `
  -Encoder h264_nvenc `
  -Output captures\host-v0.mp4 `
  -Width 1920 `
  -Height 1080 `
  -Fps 30 `
  -VideoBitrateKbps 12000
```

录制 10 秒后自动退出：

```powershell
powershell -ExecutionPolicy Bypass -File host-windows\scripts\capture-v0.ps1 `
  -Mode file `
  -Encoder libx264 `
  -DurationSeconds 10 `
  -Output captures\host-v0-10s.mp4
```

使用 CPU 编码兜底：

```powershell
powershell -ExecutionPolicy Bypass -File host-windows\scripts\capture-v0.ps1 `
  -Mode file `
  -Encoder libx264 `
  -Output captures\host-v0.mp4
```

推送 UDP MPEG-TS：

```powershell
powershell -ExecutionPolicy Bypass -File host-windows\scripts\capture-v0.ps1 `
  -Mode udp `
  -Encoder h264_nvenc `
  -UdpUrl "udp://127.0.0.1:5000?pkt_size=1316"
```

使用配置文件：

```powershell
powershell -ExecutionPolicy Bypass -File host-windows\scripts\capture-v0.ps1 `
  -Config host-windows\config\host-v0.example.json
```

列出当前 FFmpeg 支持的编码器：

```powershell
powershell -ExecutionPolicy Bypass -File host-windows\scripts\capture-v0.ps1 -ListEncoders
```

## 推荐技术栈

候选：

```text
C# + Windows Graphics Capture + FFmpeg/NVENC + WebRTC 封装
Rust + windows-rs + FFmpeg/NVENC + libdatachannel
```

Batch 2 开始前需要明确使用 C# 还是 Rust。优先级是先跑通 Windows 桌面采集和 NVENC 编码。

## 进程模型

```text
OpenComputerService
  开机自启，负责设备在线、信令常驻、Agent 管理和高权限 Broker。

OpenComputerAgent
  用户登录后运行，负责采集桌面、编码视频、输入注入和显示连接提示。
```

Service 和 Agent 通过本机 IPC 通信。

## V0 目标

- 采集主显示器
- 编码 H.264
- 输出测试流或文件
- 记录 FPS、编码耗时和码率
- 为 Android V0 解码测试提供输入流

## V1 目标

- 接入 WebRTC
- DataChannel 接收输入事件
- 使用 SendInput 注入鼠标键盘
- 支持远程粘贴文本
