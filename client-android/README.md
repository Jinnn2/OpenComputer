# Android Client

Android Client 是控制端，负责连接设备、解码视频、渲染画面和发送输入事件。

Android 端从安装 APK 开始的操作步骤见 [../docs/ANDROID_CLIENT_USER_GUIDE.md](../docs/ANDROID_CLIENT_USER_GUIDE.md)。后续 Android 功能变化优先同步维护该说明文档。

## 目标职责

```text
connection  账号、设备、信令和 WebRTC 连接
decoder     MediaCodec 解码
renderer    SurfaceView/TextureView 渲染
input       触控、键盘、快捷键和剪贴板输入
ui          设备列表、一键连接、控制界面
```

## 推荐技术栈

```text
Kotlin
WebRTC Android
MediaCodec
SurfaceView 或 TextureView
```

## V0 目标

- 连接测试视频源
- 解码 H.264
- 渲染到 Surface
- 显示连接状态、FPS 和码率

## 当前 V0 实现

当前已创建 Android Kotlin 工程：

```text
client-android/app
```

实现范围：

```text
Activity + SurfaceView
MediaExtractor 读取 Host V0 MP4/H.264 样片
MediaCodec 解码到 Surface
状态面板显示 codec、分辨率、时长、已解码帧数和观测 FPS
支持输入本地路径或通过系统文件选择器 Pick video
```

默认样片路径：

```text
/sdcard/Download/opencomputer-host-v0.mp4
```

## 本地构建

首次安装项目内 JDK / Android SDK 并构建 debug APK：

```powershell
powershell -ExecutionPolicy Bypass -File client-android\scripts\build-debug.ps1 -InstallToolchain
```

后续只构建：

```powershell
powershell -ExecutionPolicy Bypass -File client-android\scripts\build-debug.ps1
```

输出：

```text
client-android/app/build/outputs/apk/debug/app-debug.apk
```

## 真机播放 Host V0 样片

连接手机并开启 USB 调试后：

```powershell
tools\android-sdk\platform-tools\adb.exe install -r client-android\app\build\outputs\apk\debug\app-debug.apk
tools\android-sdk\platform-tools\adb.exe push captures\host-v0-acceptance-20260428-010132.mp4 /sdcard/Download/opencomputer-host-v0.mp4
```

打开 OpenComputer，点击 `Play path`。也可以点击 `Pick video` 从系统文件选择器中选择样片。

## V1 目标

- 设备列表
- 一键连接入口
- 触控板模式
- 直接点击模式
- 软键盘输入
- 远程粘贴中文文本

## 输入模式

第一版建议实现两种：

```text
direct_touch
  手机屏幕坐标直接映射到远程桌面坐标。

touchpad
  手机屏幕作为触控板，相对移动鼠标。
```

