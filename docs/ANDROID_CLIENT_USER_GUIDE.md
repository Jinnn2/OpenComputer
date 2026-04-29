# Android 端操作说明

维护状态：随 Android Client 开发持续更新。

当前版本：Batch 3 / Client V0。

## 当前能做什么

当前 Android 端可以安装 debug APK，并播放 Windows Host V0 生成的 MP4/H.264 桌面样片。

当前还不能实时连接电脑，也不能控制鼠标键盘。实时串流、WebRTC、输入控制会在后续批次接入。

电脑端调试、模拟器调试和 logcat 说明见 [ANDROID_CLIENT_DEBUG_GUIDE.md](ANDROID_CLIENT_DEBUG_GUIDE.md)。

## 1. 准备 APK

在项目根目录执行：

```powershell
powershell -ExecutionPolicy Bypass -File client-android\scripts\build-debug.ps1
```

如果是第一次构建，或本机还没有项目内 Android 工具链：

```powershell
powershell -ExecutionPolicy Bypass -File client-android\scripts\build-debug.ps1 -InstallToolchain
```

构建成功后 APK 位于：

```text
client-android/app/build/outputs/apk/debug/app-debug.apk
```

## 2. 连接 Android 手机

1. 在手机上开启开发者选项。
2. 开启 USB 调试。
3. 用 USB 连接电脑。
4. 手机弹出授权提示时允许当前电脑调试。

检查设备是否连接：

```powershell
tools\android-sdk\platform-tools\adb.exe devices
```

正常情况下会看到类似：

```text
List of devices attached
XXXXXXXX	device
```

如果列表为空，先检查 USB 数据线、手机 USB 模式、USB 调试授权弹窗。

## 3. 安装 APK

推荐使用脚本自动安装：

```powershell
powershell -ExecutionPolicy Bypass -File client-android\scripts\install-debug-apk.ps1 -Launch
```

也可以手动安装：

```powershell
tools\android-sdk\platform-tools\adb.exe install -r client-android\app\build\outputs\apk\debug\app-debug.apk
```

安装成功后手机桌面会出现 `OpenComputer`。

如果提示已安装冲突，可以先卸载再安装：

```powershell
tools\android-sdk\platform-tools\adb.exe uninstall com.opencomputer.client
tools\android-sdk\platform-tools\adb.exe install -r client-android\app\build\outputs\apk\debug\app-debug.apk
```

## 4. 准备 Host V0 样片

先在 Windows Host 侧生成一段桌面采集样片：

```powershell
powershell -ExecutionPolicy Bypass -File host-windows\scripts\capture-v0.ps1 `
  -Encoder h264_nvenc `
  -DurationSeconds 5 `
  -Output captures\opencomputer-host-v0.mp4
```

如果当前机器不能使用 NVENC：

```powershell
powershell -ExecutionPolicy Bypass -File host-windows\scripts\capture-v0.ps1 `
  -Encoder libx264 `
  -DurationSeconds 5 `
  -Output captures\opencomputer-host-v0.mp4
```

## 5. 推送样片到手机

App 默认读取这个路径：

```text
/sdcard/Download/opencomputer-host-v0.mp4
```

推送样片：

```powershell
tools\android-sdk\platform-tools\adb.exe push captures\opencomputer-host-v0.mp4 /sdcard/Download/opencomputer-host-v0.mp4
```

## 6. 播放样片

1. 在手机上打开 `OpenComputer`。
2. 确认输入框中是：

```text
/sdcard/Download/opencomputer-host-v0.mp4
```

3. 点击 `Play path`。
4. 画面区域应显示 Host 桌面样片。
5. 下方状态区会显示 codec、分辨率、时长、已解码帧数和观测 FPS。

也可以点击 `Pick video`，从系统文件选择器中选择任意 MP4/H.264 样片。

## 7. 当前状态区含义

```text
Codec
  Android MediaCodec 实际打开的视频 MIME，例如 video/avc。

Video
  样片分辨率和时长。

Decoded frames
  当前已解码并送到 Surface 的帧数。

Observed FPS
  App 侧根据已渲染帧数和播放耗时估算出的播放帧率。
```

## 8. 常见问题

### adb devices 为空

- 检查手机是否开启 USB 调试。
- 检查手机是否弹出“允许 USB 调试”授权窗口。
- 换一根支持数据传输的 USB 线。
- 重新插拔后再执行：

```powershell
tools\android-sdk\platform-tools\adb.exe devices
```

### install 失败

先卸载旧包：

```powershell
tools\android-sdk\platform-tools\adb.exe uninstall com.opencomputer.client
```

再重新安装。

### Play path 提示文件不存在

确认样片是否真的推送到默认路径：

```powershell
tools\android-sdk\platform-tools\adb.exe shell ls -l /sdcard/Download/opencomputer-host-v0.mp4
```

也可以改用 `Pick video` 从文件选择器选择。

### 播放没有画面

- 确认样片是 H.264 MP4。
- 用 Host V0 默认脚本重新生成样片。
- 优先使用 `h264_nvenc` 或 `libx264` 生成。
- 确认状态区是否出现错误信息。

### Android 13 及以上权限问题

App 会请求视频读取权限。若拒绝权限，仍可尝试通过 `Pick video` 使用系统文件选择器授权单个文件。

## 9. 后续功能维护点

这份文档随开发同步维护：

```text
Batch 3 V0:
  安装 APK，播放 Host V0 MP4 样片。

Batch 3 后续:
  增加 UDP MPEG-TS 接收说明。

Batch 4:
  增加 WebRTC 连接、信令配置、局域网实时桌面播放说明。

Batch 5:
  增加触控板模式、直接点击模式、键盘输入、远程粘贴说明。
```

每次 Android 端入口、按钮、默认路径、权限模型或连接方式变化，都需要同步更新本文档。
