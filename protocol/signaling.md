# 信令协议

信令协议用于账号认证、设备发现、连接请求和 WebRTC SDP/ICE 交换。信令走 HTTPS + WebSocket，视频和输入不走信令通道。

## 连接角色

```text
Host    Windows 被控端
Client  Android 控制端
Server  自建信令服务
```

## 设备状态

```text
offline      设备离线
online       设备在线但未连接
connecting   正在协商连接
connected    已连接
relay        已连接且使用中继
error        连接失败
```

## WebSocket 消息信封

所有 WebSocket 消息使用统一信封：

```json
{
  "type": "message_type",
  "request_id": "uuid",
  "timestamp_ms": 1777212000000,
  "payload": {}
}
```

字段说明：

- `type`：消息类型。
- `request_id`：请求级唯一 ID，连接流程内保持一致。
- `timestamp_ms`：发送端毫秒时间戳。
- `payload`：消息体。

## 设备注册

Host 和 Client 登录后向 Server 注册设备在线状态。

```json
{
  "type": "device_register",
  "request_id": "uuid",
  "timestamp_ms": 1777212000000,
  "payload": {
    "device_id": "host-001",
    "device_type": "host",
    "name": "Main Windows PC",
    "public_key": "base64...",
    "capabilities": ["video_h264", "input", "privilege_broker"]
  }
}
```

Server 返回：

```json
{
  "type": "device_register_ack",
  "request_id": "uuid",
  "timestamp_ms": 1777212000100,
  "payload": {
    "accepted": true,
    "server_time_ms": 1777212000100
  }
}
```

## 一键连接请求

Client 请求连接 Host：

```json
{
  "type": "connect_request",
  "request_id": "uuid",
  "timestamp_ms": 1777212000000,
  "payload": {
    "host_id": "host-001",
    "client_id": "phone-001",
    "mode": "full_control",
    "quick_connect": true
  }
}
```

Host 接收后返回：

```json
{
  "type": "connect_response",
  "request_id": "uuid",
  "timestamp_ms": 1777212000100,
  "payload": {
    "accepted": true,
    "reason": null,
    "require_local_confirm": false
  }
}
```

拒绝时：

```json
{
  "type": "connect_response",
  "request_id": "uuid",
  "timestamp_ms": 1777212000100,
  "payload": {
    "accepted": false,
    "reason": "device_not_trusted",
    "require_local_confirm": true
  }
}
```

## WebRTC SDP 交换

Offer：

```json
{
  "type": "webrtc_offer",
  "request_id": "uuid",
  "timestamp_ms": 1777212000200,
  "payload": {
    "from": "host-001",
    "to": "phone-001",
    "sdp": "..."
  }
}
```

Answer：

```json
{
  "type": "webrtc_answer",
  "request_id": "uuid",
  "timestamp_ms": 1777212000300,
  "payload": {
    "from": "phone-001",
    "to": "host-001",
    "sdp": "..."
  }
}
```

ICE Candidate：

```json
{
  "type": "ice_candidate",
  "request_id": "uuid",
  "timestamp_ms": 1777212000400,
  "payload": {
    "from": "host-001",
    "to": "phone-001",
    "candidate": "...",
    "sdp_mid": "0",
    "sdp_mline_index": 0
  }
}
```

## 连接状态上报

```json
{
  "type": "session_state",
  "request_id": "uuid",
  "timestamp_ms": 1777212000500,
  "payload": {
    "session_id": "session-001",
    "state": "connected",
    "relay_used": false,
    "video_codec": "h264",
    "resolution": "1920x1080",
    "fps": 30
  }
}
```

## 错误码

```text
auth_failed
device_not_found
device_offline
device_not_trusted
local_confirm_required
agent_not_ready
webrtc_failed
relay_unavailable
policy_denied
```

