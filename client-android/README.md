# Android Client

Android Client 是控制端，负责连接设备、解码视频、渲染画面和发送输入事件。

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

