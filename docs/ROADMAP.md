# OpenComputer 分批次路线图

## Batch 1：设计落地和项目骨架

目标：让项目从想法进入可实现状态。

交付物：

- 根 README
- Host / Client / Server 模块 README
- 信令协议草案
- 输入事件协议草案
- 高权限能力协议草案
- 共享 protobuf 消息草案

验收：

- 后续开发可以按模块开工
- 每个协议消息有明确字段和传输通道
- 一键连接和高权限能力有独立设计边界

## Batch 2：Windows Host V0 原型

目标：Host 能采集屏幕并产出编码视频流。

建议实现：

- 使用 PowerShell + FFmpeg 建立第一条可跑通链路
- 支持 gdigrab 桌面采集
- 支持 NVENC H.264 编码，缺失时可指定 libx264 兜底
- 支持输出本地 MP4 或 UDP MPEG-TS
- 后续再替换为 C#/Rust + Windows Graphics Capture

验收：

- 可以生成正确 FFmpeg 捕获命令
- 安装 FFmpeg 后可以稳定采集当前桌面
- 可以产生 Android 可解码的 H.264 流
- FFmpeg 输出中可观察 FPS、编码耗时、码率

## Batch 3：Android Client V0 原型

目标：Client 能接收并显示测试视频流。

建议实现：

- 创建 Android Kotlin 项目
- 使用 MediaCodec 解码 H.264
- 使用 SurfaceView 或 TextureView 渲染
- 显示基础连接和性能状态

验收：

- 手机端可播放 Host 生成的测试流
- 横竖屏切换不崩溃
- 基础延迟可观测

## Batch 4：局域网 WebRTC 串流

目标：Host 与 Client 通过 WebRTC 跑通视频。

建议实现：

- Host 集成 WebRTC 或 libdatachannel
- Client 集成 WebRTC Android
- 先使用手动交换 SDP 或局域网简易信令
- 视频走 WebRTC Video Track

验收：

- 同一 Wi-Fi 下手机可以看到实时桌面
- 支持断开重连
- 720p/1080p 可配置

## Batch 5：局域网输入控制

目标：手机可以控制电脑。

建议实现：

- DataChannel 传输输入事件
- Host 使用 SendInput 注入鼠标键盘
- Client 实现触控板模式和直接点击模式
- 实现远程粘贴中文文本

验收：

- 可以打开程序、拖动窗口、输入文本
- 鼠标移动和点击手感可接受
- 中文输入可通过远程粘贴完成

## Batch 6：自建 Server 和公网连接

目标：通过自建服务完成设备发现和信令。

建议实现：

- 用户登录
- 设备注册
- WebSocket 在线状态
- SDP / ICE 信令转发
- 接入 STUN/TURN

验收：

- 手机 5G 网络可连接家中电脑
- P2P 失败时可走 Relay
- Server 不保存画面和输入内容

## Batch 7：一键高权限连接

目标：可信手机一键连接并启用服务级辅助能力。

建议实现：

- Windows Service
- 用户会话 Agent
- Service 拉起 Agent
- 本地 IPC
- 可信设备 Profile
- PrivilegeBroker RPC

验收：

- 手机点击一次即可进入远控
- Agent 崩溃后 Service 能恢复
- 可信设备可调用受控高权限动作
