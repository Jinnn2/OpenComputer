# OpenComputer

OpenComputer 是一个自用远程桌面项目，核心路线是低延迟屏幕串流、加密输入控制和自建信令/中继服务。

第一阶段不复刻 RDP 协议，而是实现：

- Windows Host 采集桌面并通过 GPU 编码推流
- Android Client 低延迟解码显示并回传触控/键盘事件
- Self-hosted Server 负责账号、设备发现、信令和 NAT 穿透
- 可信设备支持一键连接和服务级高权限辅助能力

## 当前阶段

当前处于 Batch 2：Windows Host V0 原型。

主要文档：

- [IMPLEMENTATION.md](IMPLEMENTATION.md)：总体实现文档
- [protocol/signaling.md](protocol/signaling.md)：信令流程
- [protocol/input-events.md](protocol/input-events.md)：输入事件协议
- [protocol/privilege.md](protocol/privilege.md)：高权限能力协议
- [protocol/messages.proto](protocol/messages.proto)：跨端共享消息结构草案
- [docs/ROADMAP.md](docs/ROADMAP.md)：分批次路线图

## 目标架构

```text
host-windows  ->  WebRTC Video Track  ->  client-android
host-windows  <-  WebRTC DataChannel  <-  client-android

host-windows  <->  server  <->  client-android
              signaling / auth / relay
```

## 第一批次交付物

- 固定项目边界
- 固定核心协议草案
- 固定 Host / Client / Server 的职责划分
- 为 V0/V1 开发留下明确入口

## V0 快速运行

当前 V0 先用 PowerShell + FFmpeg 跑通 Windows 桌面采集和 H.264 编码：

```powershell
powershell -ExecutionPolicy Bypass -File host-windows\scripts\capture-v0.ps1 -Encoder h264_nvenc
```

如果本机暂时没有 NVENC 可用，可以用 CPU 编码做功能验证：

```powershell
powershell -ExecutionPolicy Bypass -File host-windows\scripts\capture-v0.ps1 -Encoder libx264
```

只查看将要执行的 FFmpeg 命令：

```powershell
powershell -ExecutionPolicy Bypass -File host-windows\scripts\capture-v0.ps1 -DryRun -Encoder libx264
```
