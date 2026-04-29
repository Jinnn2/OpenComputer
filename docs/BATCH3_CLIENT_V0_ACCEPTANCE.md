# Batch 3 Android Client V0 验收记录

日期：2026-04-28

## 结论

Batch 3 Android Client V0 已完成首个可构建 APK：

- 已创建 Android Kotlin 工程。
- 已实现 `SurfaceView + MediaExtractor + MediaCodec` 的 MP4/H.264 样片播放链路。
- 已实现状态面板，显示 codec、分辨率、时长、已解码帧数、观测 FPS。
- 已支持默认路径播放和系统文件选择器播放。
- 已安装项目内 JDK / Android SDK / Gradle，并完成 debug APK 构建。

当前机器未连接 Android 设备，因此真机安装、播放和横竖屏验证尚未执行。

## 构建环境

项目内工具链：

```text
JDK: Temurin 17.0.18
Android SDK: tools/android-sdk
Gradle: 9.3.1
Android Gradle Plugin: 9.1.0
compileSdk: 36
buildTools: 36.0.0
```

AGP 9 已内建 Kotlin 支持，因此未再应用 `org.jetbrains.kotlin.android` 插件。

## 构建命令

首次安装工具链并构建：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File client-android\scripts\build-debug.ps1 -InstallToolchain
```

后续构建：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File client-android\scripts\build-debug.ps1
```

## 构建结果

```text
BUILD SUCCESSFUL in 48s
33 actionable tasks: 33 executed
```

APK：

```text
client-android/app/build/outputs/apk/debug/app-debug.apk
```

大小：

```text
857076 bytes
```

## Gradle Wrapper

```powershell
.\gradlew.bat --version --no-daemon
```

结果：

```text
Gradle 9.3.1
Launcher JVM: 17.0.18
OS: Windows 11 10.0 amd64
```

## 真机验证待办

当前 `adb devices` 输出为空：

```text
List of devices attached
```

连接 Android 手机并开启 USB 调试后执行：

```powershell
tools\android-sdk\platform-tools\adb.exe install -r client-android\app\build\outputs\apk\debug\app-debug.apk
tools\android-sdk\platform-tools\adb.exe push captures\host-v0-acceptance-20260428-010132.mp4 /sdcard/Download/opencomputer-host-v0.mp4
```

随后在 App 内点击 `Play path` 播放默认路径样片，或点击 `Pick video` 选择任意 Host V0 MP4。

## 当前边界

- 目前播放对象是 Host V0 的 MP4/H.264 样片。
- 尚未接 UDP MPEG-TS 实时流。
- 尚未接 WebRTC。
- 尚未实现触控/键盘输入回传。
