# 输入事件协议

输入事件通过 WebRTC DataChannel 发送。实时鼠标键盘事件使用 `input.realtime` 通道，剪贴板和配置类输入使用可靠通道。

## 通用信封

```json
{
  "type": "mouse_move",
  "seq": 1024,
  "timestamp_ms": 1777212000000,
  "payload": {}
}
```

字段说明：

- `type`：事件类型。
- `seq`：单连接内递增序号，用于丢包和乱序观测。
- `timestamp_ms`：Client 发送时间。
- `payload`：事件内容。

## 坐标系统

第一版使用归一化绝对坐标：

```text
x: 0.0 到 1.0
y: 0.0 到 1.0
screen: 显示器编号，MVP 固定为 0
```

Host 根据当前显示器分辨率和 DPI 缩放映射到 Windows 坐标。

## 鼠标移动

```json
{
  "type": "mouse_move",
  "seq": 1,
  "timestamp_ms": 1777212000000,
  "payload": {
    "x": 0.52,
    "y": 0.38,
    "screen": 0,
    "mode": "absolute"
  }
}
```

`mode` 可选：

```text
absolute  直接映射到屏幕坐标
relative  触控板相对移动
```

## 鼠标按键

```json
{
  "type": "mouse_button",
  "seq": 2,
  "timestamp_ms": 1777212000010,
  "payload": {
    "button": "left",
    "action": "down"
  }
}
```

`button`：

```text
left
right
middle
back
forward
```

`action`：

```text
down
up
click
double_click
```

## 鼠标滚轮

```json
{
  "type": "mouse_wheel",
  "seq": 3,
  "timestamp_ms": 1777212000020,
  "payload": {
    "delta_x": 0,
    "delta_y": -120
  }
}
```

## 键盘事件

```json
{
  "type": "key",
  "seq": 4,
  "timestamp_ms": 1777212000030,
  "payload": {
    "code": "KEY_A",
    "action": "down",
    "modifiers": ["ctrl"]
  }
}
```

`action`：

```text
down
up
press
```

常用 `code` 使用跨平台语义名，例如 `KEY_A`、`ENTER`、`ESCAPE`、`BACKSPACE`、`CTRL_LEFT`。

## 快捷键

快捷键可作为高级语义事件发送，Host 再展开为具体键盘事件。

```json
{
  "type": "shortcut",
  "seq": 5,
  "timestamp_ms": 1777212000040,
  "payload": {
    "name": "ctrl_alt_delete"
  }
}
```

第一版建议支持：

```text
ctrl_c
ctrl_v
ctrl_x
alt_tab
win_d
ctrl_alt_delete
```

其中 `ctrl_alt_delete` 在普通用户态注入中可能不可用，后续由 PrivilegeBroker 或系统专用能力处理。

## 文本粘贴

中文输入第一版通过远程粘贴实现：

```json
{
  "type": "paste_text",
  "seq": 6,
  "timestamp_ms": 1777212000050,
  "payload": {
    "text": "中文输入内容",
    "method": "clipboard_ctrl_v"
  }
}
```

Host 行为：

1. 写入当前用户剪贴板。
2. 模拟 `Ctrl+V`。
3. 可选恢复原剪贴板内容。

## 触控手势

Client 可以在本地把触控手势转换为鼠标事件；复杂手势也可以直接上报：

```json
{
  "type": "gesture",
  "seq": 7,
  "timestamp_ms": 1777212000060,
  "payload": {
    "name": "pinch",
    "scale": 1.12,
    "center_x": 0.5,
    "center_y": 0.5
  }
}
```

MVP 里 `gesture` 可先不实现。

