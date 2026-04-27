# Self-hosted Server

Server 负责账号认证、设备注册、在线状态、WebRTC 信令和 NAT 穿透辅助。Server 不保存画面、输入、剪贴板和文件内容。

## 目标职责

```text
auth       用户登录和 token
device     Host/Client 注册、在线状态、设备绑定
signaling  WebSocket 信令、SDP/ICE 转发
relay      TURN/Relay 接入和状态记录
migrations 数据库迁移
```

## 推荐技术栈

候选：

```text
Go + SQLite/PostgreSQL + WebSocket + Docker Compose
Rust + SQLite/PostgreSQL + WebSocket + Docker Compose
```

MVP 推荐先用 SQLite，避免部署成本过早变高。公网和多用户稳定后再切 PostgreSQL。

## 最小 API

```text
POST /api/login
POST /api/devices/register
GET  /api/devices
GET  /ws/signaling
```

## WebSocket 能力

- 设备上线/离线
- 一键连接请求
- 连接响应
- SDP 转发
- ICE Candidate 转发
- 连接状态上报

## V2 目标

- 手机和 Host 都能登录 Server
- Server 能显示设备在线状态
- Client 能请求连接 Host
- Host 和 Client 能通过 Server 完成 WebRTC 协商
- P2P 失败时可走 TURN/Relay

