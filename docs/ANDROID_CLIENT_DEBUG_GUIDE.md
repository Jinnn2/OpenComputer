# Android 端电脑调试说明

维护状态：随 Android Client 调试方式持续更新。

当前目标：把“手机上手动装 APK、手动推文件、手动看状态”升级成电脑上一键调试。

## 当前结论

电脑端调试可以走两条路线：

```text
优先：Android Emulator
  在电脑上启动模拟器，自动安装 APK，自动推送 Host 样片，自动拉起 App，使用 logcat 看日志。

兜底：USB 真机
  连接 Android 手机，脚本自动安装 APK，推送样片，拉起 App，使用 logcat 看日志。
```

当前机器已具备：

```text
JDK 17
Android SDK command-line tools
platform-tools / adb
Android Client debug APK 构建能力
Hyper-V / 虚拟化支持
```

当前阻塞：

```text
Android Emulator system image 下载时，sdkmanager 获取 Google manifest 网络超时。
```

脚本已经就位；等 system image 下载成功后即可进入完整模拟器调试。

## 一键模拟器调试

如果本机还没有 Android Studio，可以先安装：

```powershell
powershell -ExecutionPolicy Bypass -File client-android\scripts\install-android-studio.ps1
```

如果你想一次准备 Android Studio、项目工具链和模拟器：

```powershell
powershell -ExecutionPolicy Bypass -File client-android\scripts\setup-android-debug-env.ps1 `
  -InstallAndroidStudio `
  -InstallProjectToolchain `
  -InstallEmulator
```

推荐命令：

```powershell
powershell -ExecutionPolicy Bypass -File client-android\scripts\debug-emulator.ps1 -InstallEmulator
```

这个命令会执行：

```text
1. 安装 Android emulator 和 system image
2. 创建 OpenComputerV0 AVD
3. 构建 app-debug.apk
4. 生成 Host V0 MP4 样片
5. 启动模拟器
6. 等待 Android boot completed
7. 安装 APK
8. 推送样片到 /sdcard/Download/opencomputer-host-v0.mp4
9. 拉起 com.opencomputer.client/.MainActivity
```

无窗口后台启动模拟器：

```powershell
powershell -ExecutionPolicy Bypass -File client-android\scripts\debug-emulator.ps1 -InstallEmulator -NoWindow
```

查看 App 日志：

```powershell
powershell -ExecutionPolicy Bypass -File client-android\scripts\debug-emulator.ps1 -Logcat
```

## 分步模拟器调试

安装 emulator / system image 并创建 AVD：

```powershell
powershell -ExecutionPolicy Bypass -File client-android\scripts\install-emulator.ps1
```

启动模拟器：

```powershell
powershell -ExecutionPolicy Bypass -File client-android\scripts\start-emulator.ps1
```

后台启动：

```powershell
powershell -ExecutionPolicy Bypass -File client-android\scripts\start-emulator.ps1 -NoWindow
```

确认设备：

```powershell
tools\android-sdk\platform-tools\adb.exe devices
```

安装 APK：

```powershell
tools\android-sdk\platform-tools\adb.exe install -r client-android\app\build\outputs\apk\debug\app-debug.apk
```

推送样片：

```powershell
tools\android-sdk\platform-tools\adb.exe push captures\opencomputer-host-v0.mp4 /sdcard/Download/opencomputer-host-v0.mp4
```

启动 App：

```powershell
tools\android-sdk\platform-tools\adb.exe shell am start -n com.opencomputer.client/.MainActivity
```

查看日志：

```powershell
tools\android-sdk\platform-tools\adb.exe logcat -v time OpenComputerClient:D AndroidRuntime:E *:S
```

## USB 真机调试

如果模拟器 system image 暂时下载不下来，先用真机走同样的调试链路：

```powershell
tools\android-sdk\platform-tools\adb.exe devices
powershell -ExecutionPolicy Bypass -File client-android\scripts\build-debug.ps1
tools\android-sdk\platform-tools\adb.exe install -r client-android\app\build\outputs\apk\debug\app-debug.apk
tools\android-sdk\platform-tools\adb.exe push captures\opencomputer-host-v0.mp4 /sdcard/Download/opencomputer-host-v0.mp4
tools\android-sdk\platform-tools\adb.exe shell am start -n com.opencomputer.client/.MainActivity
tools\android-sdk\platform-tools\adb.exe logcat -v time OpenComputerClient:D AndroidRuntime:E *:S
```

如果你已经在本机装好了 Android Studio / Emulator，或已经连接真机，可以直接用安装脚本：

```powershell
powershell -ExecutionPolicy Bypass -File client-android\scripts\install-debug-apk.ps1 -Launch -Logcat
```

只安装 APK，不生成/推送样片：

```powershell
powershell -ExecutionPolicy Bypass -File client-android\scripts\install-debug-apk.ps1 -SkipSample -Launch
```

跳过构建，直接安装当前 APK：

```powershell
powershell -ExecutionPolicy Bypass -File client-android\scripts\install-debug-apk.ps1 -SkipBuild -Launch
```

## 当前日志点

App 使用 `OpenComputerClient` tag 输出：

```text
打开视频源
MediaCodec 配置结果
播放错误
解码帧数 / elapsedMs / observed FPS
状态面板文本
```

## 后续维护点

```text
接 UDP MPEG-TS 后:
  debug 脚本增加本机 UDP 推流 + 模拟器接收验证。

接 WebRTC 后:
  debug 脚本增加本机信令服务、Host、Client 三进程启动。

接输入控制后:
  debug 脚本增加触控事件模拟、adb shell input 辅助验证。
```
