# 高权限能力协议

高权限能力用于支持可信设备的一键连接、Host 自动恢复和管理员级辅助操作。该协议不暴露任意系统调用，而是定义一组明确的 RPC。

## 组件

```text
OpenComputerService
  Windows Service，开机自启，负责在线状态、Agent 管理、策略校验。

OpenComputerAgent
  当前用户会话进程，负责屏幕采集、编码、普通输入注入。

PrivilegeBroker
  Service 内部模块或独立 helper，负责受控管理员动作。
```

## 调用通道

远端 Client 通过 WebRTC `privilege` DataChannel 发送请求。

Host 内部：

```text
Client -> Agent -> Service -> PrivilegeBroker
```

Agent 和 Service 之间使用本机 IPC，例如 Windows named pipe。

## 请求信封

```json
{
  "type": "privileged_action",
  "request_id": "uuid",
  "timestamp_ms": 1777212000000,
  "payload": {
    "action": "restart_agent",
    "args": {}
  }
}
```

响应：

```json
{
  "type": "privileged_action_result",
  "request_id": "uuid",
  "timestamp_ms": 1777212000100,
  "payload": {
    "ok": true,
    "error": null,
    "data": {}
  }
}
```

## 策略校验

执行前必须检查：

```text
client_device_id 是否已绑定
quick_connect 是否允许
full_control 是否允许
allow_privileged_actions 是否允许
当前会话是否仍处于 connected/full_control
```

第一版策略文件：

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
      "allow_privileged_actions": true
    }
  ]
}
```

## 第一批动作

### restart_agent

重启当前用户会话的 Agent。

```json
{
  "action": "restart_agent",
  "args": {}
}
```

### launch_agent

在指定用户会话中启动 Agent。

```json
{
  "action": "launch_agent",
  "args": {
    "session_id": 1
  }
}
```

### lock_screen

锁定 Windows 会话。

```json
{
  "action": "lock_screen",
  "args": {}
}
```

### shutdown

关闭或重启电脑。

```json
{
  "action": "shutdown",
  "args": {
    "mode": "restart",
    "delay_seconds": 5
  }
}
```

`mode`：

```text
shutdown
restart
logoff
```

### launch_process

启动指定程序。第一版只允许启动白名单路径。

```json
{
  "action": "launch_process",
  "args": {
    "path": "C:\\Windows\\System32\\notepad.exe",
    "elevated": false
  }
}
```

### set_feature

切换 Host 功能。

```json
{
  "action": "set_feature",
  "args": {
    "name": "clipboard_sync",
    "enabled": true
  }
}
```

## 暂不进入 MVP 的动作

```text
任意命令执行
直接控制 UAC 安全桌面
隐藏连接状态
无授权安装服务
绕过系统权限模型的提权
```

开发调试可以保留本地 `debug_admin_command`，但必须由 Host 本地配置显式打开，且不得作为默认能力。

