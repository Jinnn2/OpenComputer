# Batch 2 Host V0 验收记录

日期：2026-04-28

## 结论

Batch 2 Windows Host V0 已在当前机器跑通：

- 项目内 portable FFmpeg 安装成功。
- `gdigrab` 可以采集当前 Windows 桌面。
- `h264_nvenc` 可用，并已完成 1080p / 30fps 目标配置的 5 秒样片录制。
- `libx264` CPU 兜底也已完成 3 秒样片录制。
- MP4 样片可被 `ffprobe` 识别为 H.264 视频。

## FFmpeg

安装方式：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File host-windows\scripts\install-ffmpeg.ps1
```

安装位置：

```text
tools/ffmpeg/bin/ffmpeg.exe
```

版本：

```text
ffmpeg version 8.1-essentials_build-www.gyan.dev
```

下载包 SHA256：

```text
8748283d821613d930b0e7be685aaa9df4ca6f0ad4d0c42fd02622b3623463c6
```

## 验收命令

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File host-windows\scripts\accept-v0.ps1 -CaptureSeconds 5 -TestCapture
```

验收报告：

```text
artifacts/host-v0/acceptance-20260428-010132.md
```

报告目录被 `.gitignore` 忽略；需要复查原始日志时在本机打开即可。

## NVENC 样片

输出文件：

```text
captures/host-v0-acceptance-20260428-010132.mp4
```

`ffprobe` 结果：

```text
codec_name=h264
width=1920
height=1080
avg_frame_rate=28/1
duration=5.000000
size=7001682
```

采集日志显示：

```text
Stream #0:0 -> #0:0 (bmp (native) -> h264 (h264_nvenc))
Video: h264 (Main), yuv420p, 1920x1080, 12000 kb/s, 30 fps
frame=140 ... time=00:00:04.96 ... bitrate=11277.9kbits/s
```

## CPU 兜底样片

命令：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File host-windows\scripts\capture-v0.ps1 -Encoder libx264 -DurationSeconds 3 -Output captures\host-v0-libx264-smoke.mp4
```

结果：

```text
Stream #0:0 -> #0:0 (bmp (native) -> h264 (libx264))
Video: h264, yuv420p, 1920x1080, 12000 kb/s, 30 fps
frame=84 ... time=00:00:02.96 ... speed=0.977x
```

## 当前边界

- 已完成本地 MP4 输出链路。
- 已完成 UDP MPEG-TS 输出命令 dry-run。
- 尚未接 Android 端播放，也尚未接 WebRTC。
- FFmpeg 的 `gdigrab` 是 V0 验证链路；后续正式 Host 仍建议迁移到 Windows Graphics Capture。
