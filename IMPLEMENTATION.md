# OpenComputer 实现文档

## 1. 项目目标

OpenComputer 是一个自用远程桌面系统，优先目标不是复刻 Microsoft RDP，而是实现：

- 低延迟电脑屏幕串流
- 手机端触控、键盘、剪贴板输入控制
- 自建账号、设备发现、NAT 穿透和中继服务
- 可信设备的一键连接和高权限便捷控制

第一阶段验收目标：

```text
同一 Wi-Fi 下，Android 手机可流畅查看并控制 Windows 桌面。
目标体验：1080p / 30fps / 端到端延迟尽量低于 100ms。
```

功能优先级高于安全完备性，但权限获取必须基于自有设备上的显式安装授权，不设计系统权限绕过、隐藏连接或无授权接管。

## 2. 总体架构

```text
Windows Host
  屏幕采集 -> GPU 编码 -> WebRTC Video Track -> 网络
  输入接收 <- WebRTC DataChannel <- 网络
  输入注入 / 剪贴板 / 文件能力 / 高权限代理

Android Client
  网络 -> MediaCodec 硬解码 -> Surface 渲染
  触控/键盘/快捷栏 -> DataChannel -> Host

Self-hosted Server
  账号认证 / 设备注册 / 在线状态
  WebSocket 信令 / SDP 与 ICE 交换
  NAT 穿透协调 / TURN 或自建 Relay
```

推荐第一版采用 WebRTC，原因是 WebRTC 已经内置音视频实时传输、DataChannel、拥塞控制、NAT 穿透、DTLS/SRTP 加密。后续如果需要极限低延迟，再替换为自定义 UDP/QUIC 协议。

## 3. 技术选型

### 3.1 Windows Host

推荐主路线：

```text
语言：Rust 或 C#
采集：Windows Graphics Capture，必要时补充 DXGI Desktop Duplication
编码：FFmpeg + NVENC H.264，后续支持 HEVC/AV1
网络：WebRTC Native / libdatachannel
输入：SendInput + 剪贴板 API + 服务代理
高权限：Windows Service + 用户会话 Agent + 本地 IPC
```

实现建议：

- MVP 优先支持单显示器、H.264、固定码率和固定分辨率。
- RTX 5080 机器优先走 NVENC，不做 CPU 编码默认路径。
- Host 分成常驻服务和用户会话进程，避免把采集、编码、权限管理全部塞进一个进程。

### 3.2 Android Client

推荐主路线：

```text
语言：Kotlin
解码：MediaCodec
渲染：SurfaceView 或 TextureView
网络：WebRTC Android
输入：触控事件、虚拟键盘、快捷键栏
```

手机端核心功能：

- 低延迟解码和渲染
- 触控板模式、直接点击模式
- 双指缩放、拖动、右键、滚轮
- 软键盘输入
- 中文输入临时方案：手机输入文本后发送到 Host 剪贴板并模拟 Ctrl+V
- 横竖屏适配、码率和分辨率切换

### 3.3 Server

推荐主路线：

```text
语言：Go 或 Rust
接口：HTTPS REST + WebSocket
数据库：SQLite 起步，后续 PostgreSQL
中继：先接入 coturn，后续实现自建 Relay
部署：Docker Compose
```

Server 不处理明文画面和明文输入，只负责账号、设备、信令和必要时的转发。

## 4. 仓库结构

建议目录结构：

```text
opencomputer/
├── host-windows/
│   ├── agent/
│   ├── service/
│   ├── capture/
│   ├── encoder/
│   ├── input/
│   ├── network/
│   ├── privilege/
│   └── security/
├── client-android/
│   ├── app/
│   ├── decoder/
│   ├── renderer/
│   ├── input/
│   └── connection/
├── server/
│   ├── auth/
│   ├── signaling/
│   ├── device/
│   ├── relay/
│   └── migrations/
├── protocol/
│   ├── messages.proto
│   ├── signaling.md
│   ├── input-events.md
│   └── privilege.md
└── docs/
    ├── IMPLEMENTATION.md
    └── ROADMAP.md
```

当前文件可作为 `docs/IMPLEMENTATION.md` 的内容来源；如果仓库继续保持轻量，也可以放在根目录。

## 5. 分阶段实现路线

### V0：局域网投屏版

目标：手机能看到电脑画面。

Host：

- 枚举显示器
- 使用 Windows Graphics Capture 获取帧
- NVENC 编码 H.264
- 通过 WebRTC Video Track 或局域网 RTP 推给 Client

Client：

- 连接 Host
- MediaCodec 解码 H.264
- SurfaceView 渲染
- 显示基本统计：FPS、码率、延迟估计

验收：

- 同一 Wi-Fi 下可看到桌面
- 支持 720p/1080p 切换
- 断线后可重连

### V1：局域网远控版

目标：手机能控制电脑。

新增：

- WebRTC DataChannel
- 鼠标移动、点击、滚轮
- 键盘输入和快捷键
- 触控板模式、直接点击模式
- 基础连接码鉴权
- Host 端连接提示

验收：

- 手机可完成打开程序、输入文本、拖动窗口等基本操作
- 输入延迟主观可接受
- 中文输入先通过剪贴板粘贴实现

### V2：公网连接版

目标：外网手机能连接家中电脑。

新增：

- 自建 Server
- 账号登录
- 设备注册和在线状态
- WebSocket 信令
- SDP / ICE 交换
- STUN / TURN
- Relay fallback

验收：

- 手机 5G 网络可连接家中电脑
- P2P 失败时自动走 Relay
- Server 可显示设备在线、离线、连接中状态

### V3：可信设备和高权限便捷版

目标：可信手机可以一键连接，Host 能自动准备高权限控制环境。

新增：

- 设备绑定
- 可信设备免 Host 手动确认
- Windows Service 常驻
- Host Agent 自动拉起
- 高权限 Privilege Broker
- 一键连接按钮
- Wake-on-LAN
- 连接策略 Profile

验收：

- 手机点击一次目标设备即可完成唤醒、发现、信令协商、连接和控制
- Host Agent 崩溃后 Service 能自动恢复
- 需要管理员能力的功能可由 Broker 执行

### V4：体验优化版

新增：

- 动态码率
- 自适应分辨率
- 60fps / 高帧率模式
- 音频传输
- 多显示器
- 文件传输
- 剪贴板双向同步
- 快捷键栏
- 游戏模式
- 远程更新 Host

## 6. 一键高权限连接设计

### 6.1 设计目标

用户希望手机端尽量像“点一下就接管电脑”：

```text
打开 Android App
-> 选择已绑定电脑
-> 点击一键连接
-> 自动唤醒 / 自动信令 / 自动拉起 Host / 自动进入远控
```

为了达到这个效果，Windows Host 需要采用服务化架构。

### 6.2 Windows 进程拆分

```text
OpenComputerService
  类型：Windows Service
  权限：LocalSystem 或管理员安装的服务账号
  职责：
    - 开机自启
    - 保持设备在线
    - 接收 Server 信令
    - 唤起用户会话 Agent
    - 管理可信设备策略
    - 执行有限的高权限操作

OpenComputerAgent
  类型：用户会话进程
  权限：当前登录用户
  职责：
    - 屏幕采集
    - 视频编码
    - 输入注入
    - 桌面悬浮状态提示
    - 普通剪贴板和文件交互

PrivilegeBroker
  类型：Service 内部模块或独立高权限 helper
  权限：随 Service
  职责：
    - 执行管理员级操作
    - 拉起或重启 Agent
    - 安装更新
    - 修改 Host 配置
    - 提供功能优先的远程管理 RPC
```

Service 与 Agent 之间使用本地命名管道或 Unix domain socket 等本机 IPC。所有来自手机端的高权限请求必须先经过 Agent/Service 的会话校验，再进入 Broker。

### 6.3 一键连接状态机

```text
Idle
  -> ClientRequest
  -> CheckTrustedDevice
  -> WakeOrLaunchAgent
  -> CreateWebRTCSession
  -> StartVideo
  -> StartInput
  -> ConnectedFullControl
```

手机端点击“一键连接”后的具体流程：

1. Client 向 Server 发起 `connect_request(host_id, client_device_id, mode=full_control)`。
2. Server 检查账号关系和设备绑定关系，转发请求给 Host Service。
3. Host Service 判断该手机是否在可信设备列表中。
4. 若电脑休眠，Client 先请求 Server 发送 Wake-on-LAN，或由同网段辅助节点唤醒。
5. Host Service 检查用户会话，若 Agent 未运行则拉起 Agent。
6. Agent 与 Client 通过 Server 交换 WebRTC SDP / ICE。
7. WebRTC 建立后，视频走 Video Track，输入走 DataChannel。
8. Service 切换当前连接状态为 `FullControl`，允许可信设备调用高权限能力。

### 6.4 连接 Profile

Host 本地保存连接策略：

```json
{
  "trusted_devices": [
    {
      "device_id": "phone-001",
      "name": "My Android Phone",
      "public_key": "base64...",
      "quick_connect": true,
      "full_control": true,
      "require_local_confirm": false,
      "allow_clipboard": true,
      "allow_file_transfer": true,
      "allow_privileged_actions": true
    }
  ],
  "default_policy": {
    "require_local_confirm": true,
    "allow_privileged_actions": false
  }
}
```

策略含义：

- `quick_connect`：允许手机端一键连接。
- `full_control`：允许进入完整控制模式。
- `require_local_confirm`：是否需要电脑端点击确认。
- `allow_privileged_actions`：是否允许调用 Broker。

### 6.5 高权限能力范围

第一版建议把高权限能力限定为功能明确的 RPC，而不是裸露任意系统接口：

```text
Service 控制：
  - 启动 Agent
  - 重启 Agent
  - 重启 OpenComputerService
  - 更新 Host 程序

系统控制：
  - 锁屏
  - 重启电脑
  - 关机
  - 注销当前用户
  - Wake-on-LAN 配置

远控辅助：
  - 启动指定程序
  - 以管理员权限启动指定程序
  - 开启/关闭剪贴板同步
  - 开启/关闭文件传输
  - 切换性能模式
```

开发调试阶段可以保留 `debug_admin_command`，但默认关闭，并且只允许本地配置文件显式开启。正式自用版本仍建议保留操作日志，方便回查误操作。

### 6.6 UAC 和安全桌面处理

普通 `SendInput` 不能可靠控制 Windows UAC 安全桌面、登录界面等特殊桌面。功能优先版可以按阶段处理：

```text
阶段 1：
  不支持控制 UAC 安全桌面。
  通过 Broker 提供“以管理员权限启动程序”等能力，减少直接操作 UAC 弹窗的需求。

阶段 2：
  安装时提供“功能优先模式”选项。
  该模式提示用户会降低本机交互隔离强度，然后允许远控流程更容易处理提权类操作。

阶段 3：
  研究 UIAccess 签名程序、服务辅助输入、专用虚拟 HID 驱动等方案。
  这部分复杂度高，不放入 MVP。
```

关键原则：

- 安装 Host 时由用户主动授予管理员权限。
- 不做无提示提权。
- 不隐藏连接状态。
- 高权限能力优先通过 Service/Broker 的明确接口实现。

## 7. 协议设计

### 7.1 信令消息

```json
{
  "type": "connect_request",
  "request_id": "uuid",
  "host_id": "host-001",
  "client_id": "phone-001",
  "mode": "full_control"
}
```

```json
{
  "type": "webrtc_offer",
  "request_id": "uuid",
  "sdp": "..."
}
```

```json
{
  "type": "ice_candidate",
  "request_id": "uuid",
  "candidate": "..."
}
```

### 7.2 输入事件

鼠标移动：

```json
{
  "type": "mouse_move",
  "x": 0.52,
  "y": 0.38,
  "screen": 0,
  "mode": "absolute"
}
```

鼠标点击：

```json
{
  "type": "mouse_button",
  "button": "left",
  "action": "down"
}
```

键盘：

```json
{
  "type": "key",
  "code": "KEY_A",
  "action": "press",
  "modifiers": ["ctrl"]
}
```

远程粘贴：

```json
{
  "type": "paste_text",
  "text": "中文输入内容"
}
```

高权限 RPC：

```json
{
  "type": "privileged_action",
  "action": "restart_agent",
  "request_id": "uuid"
}
```

### 7.3 DataChannel 划分

建议建立多个 DataChannel：

```text
input.realtime     鼠标、键盘、滚轮
control.reliable   连接状态、配置修改、模式切换
clipboard          剪贴板同步
file               文件传输
privilege          高权限 RPC
```

实时输入通道可以牺牲少量可靠性换低延迟；控制、高权限和文件通道必须可靠有序。

## 8. 服务端数据模型

最小表结构：

```text
users
  id
  email
  password_hash
  created_at

devices
  id
  user_id
  name
  type              host/client
  public_key
  last_seen_at
  online_state

pairings
  id
  user_id
  host_device_id
  client_device_id
  quick_connect
  full_control
  created_at

sessions
  id
  host_device_id
  client_device_id
  state
  relay_used
  started_at
  ended_at
```

Server 只保存连接元数据，不保存视频帧、输入内容、剪贴板内容和文件内容。

## 9. MVP 开发顺序

推荐从最短闭环开始：

1. 建立 `host-windows` 原型，能采集屏幕并编码 H.264。
2. 建立 `client-android` 原型，能接收并显示测试 H.264 流。
3. 接入 WebRTC，跑通局域网视频。
4. 加 DataChannel，跑通鼠标移动和点击。
5. 加键盘输入和远程粘贴。
6. 加 `server`，实现登录、设备注册、信令交换。
7. 加 Windows Service，支持开机上线和一键拉起 Agent。
8. 加可信设备 Profile 和一键连接。
9. 加 PrivilegeBroker 的第一批高权限 RPC。

## 10. 主要风险和处理策略

```text
低延迟采集难：
  先固定 Windows 10/11 + 单显示器 + WGC。

编码链路复杂：
  先用 FFmpeg NVENC，后续再做更底层封装优化。

WebRTC Native 集成成本高：
  C# 可先用成熟封装，Rust 可评估 libdatachannel。

中文输入麻烦：
  第一版只做远程粘贴。

UAC 安全桌面难控制：
  第一版通过 Broker 的管理员动作绕开直接操作弹窗。

公网连接不稳定：
  第一版直接接入 coturn，先保证能连，再优化成本。

高权限误操作风险：
  可信设备默认只给自用手机，操作日志本地保存。
```

## 11. 第一批可交付物

建议下一步创建这些最小文件和模块：

```text
protocol/input-events.md
protocol/signaling.md
protocol/privilege.md
server/README.md
host-windows/README.md
client-android/README.md
```

随后开始实现 V0/V1：

```text
host-windows:
  capture -> encoder -> webrtc sender

client-android:
  webrtc receiver -> MediaCodec -> renderer

protocol:
  input events + connect flow
```

做到 V1 后，这个项目就已经具备自用价值；V2/V3 再把公网、自建中继和一键高权限连接补齐。
