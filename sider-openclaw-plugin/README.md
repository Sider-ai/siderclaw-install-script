# Sider OpenClaw Plugin 对接文档

本文档面向两类同学：
- 需要安装 `openclaw-plugins/sider` 的运维/后端同学
- 需要消费 `typing/stream/tool` 事件的客户端同学（Web/iOS/Android）

目标：自动安装 `sider` 插件，并可选写入 `channels.sider` 配置。

---

## 1. 一键安装

安装脚本默认执行：
- `openclaw plugins install @hywkp/sider`
- 若已安装（`plugin already exists`），自动尝试：`openclaw plugins update sider`

仅安装插件（不改配置）：

```bash
curl -fsSL https://raw.githubusercontent.com/Sider-ai/siderclaw-install-script/main/sider-openclaw-plugin/install-openclaw-plugin.sh | RUN_CONFIGURE=0 bash
```

配置方式 1：只启用 `setup token` 模式：

```bash
curl -fsSL https://raw.githubusercontent.com/Sider-ai/siderclaw-install-script/main/sider-openclaw-plugin/install-openclaw-plugin.sh | \
  SIDER_SETUP_TOKEN='<one-time-token>' \
  bash
```

说明：
- 脚本会写入 `channels.sider.enabled=true`
- 脚本会把一次性 token 写入 `channels.sider.setupToken`
- 插件换取成功后，会自动写入长期 `gatewayUrl + token`，并删除 `setupToken`
- 若当前账号已经配置了 `gatewayUrl/token`，需先移除；否则 setup token 交换不会触发

配置方式 2：直接写入 `gatewayUrl + token`：

```bash
curl -fsSL https://raw.githubusercontent.com/Sider-ai/siderclaw-install-script/main/sider-openclaw-plugin/install-openclaw-plugin.sh | \
  SIDER_GATEWAY_URL='https://<gateway-url>' \
  SIDER_TOKEN='<access-token>' \
  bash
```

安装参数说明：
- `SIDER_SETUP_TOKEN`：启用 setup token 模式；脚本会写入 `channels.sider.setupToken`
- `SIDER_GATEWAY_URL`：直接配置模式下写入 `channels.sider.gatewayUrl`
- `SIDER_TOKEN`：直接配置模式下写入 `channels.sider.token`
- `RUN_CONFIGURE=0`：仅安装插件，不写入配置

约束：
- 不要混用 `SIDER_SETUP_TOKEN` 和 `SIDER_GATEWAY_URL` / `SIDER_TOKEN`
- 直接配置模式下，若不传 `SIDER_TOKEN`，脚本只会写入 `gatewayUrl`；仅适用于不校验 relay token 的 gateway

如需其他高级字段，请安装后手动修改 `openclaw.json`。

---

## 2. OpenClaw 配置示例

`~/.openclaw/openclaw.json`：

```json
{
  "channels": {
    "sider": {
      "enabled": true,
      "gatewayUrl": "https://<gateway-url>",
      "token": "<access-token>"
    }
  }
}
```

setup token 模式下，`openclaw.json` 最小只需要：

```json
{
  "channels": {
    "sider": {
      "enabled": true,
      "setupToken": "<one-time-token>"
    }
  }
}
```

说明：
- setup 成功前，一次性 token 会暂存在 `channels.sider.setupToken`
- setup 成功后，插件会把 `gatewayUrl + token` 自动写回 `channels.sider`，并删除 `setupToken`
- 兼容旧配置时，插件仍会读取 `relayToken`，但新配置建议统一写 `token`
- 如需其他高级字段，请按需手动写入配置

检查状态：

```bash
openclaw channels list
openclaw status --json
```

预期：`Sider default: configured, enabled`，且不再出现 `Sider: not configured`。

---

## 3. 基础协议（relay 侧）

WebSocket 连接：
- `ws://<gateway>/ws/relay`

握手首帧：

```json
{"type":"register","relay_id":"<relay_id>","token":"<optional>"}
```

发送持久化消息：

```json
{
  "type":"message",
  "session_id":"<session_id>",
  "client_req_id":"<uuid>",
  "parts":[{"type":"core.text","payload":{"text":"hello"}}]
}
```

发送实时事件：

```json
{
  "type":"event",
  "session_id":"<session_id>",
  "client_req_id":"<uuid>",
  "event_type":"typing",
  "payload":{"on":true},
  "meta":{}
}
```

ACK：

```json
{"type":"ack","session_id":"<session_id>","id":"<id>"}
```

说明：
- 握手不再绑定 `session_id`
- 消息帧中的 `session_id` 仍然用于路由和持久化

---

## 4. 客户端事件约定（typing / stream / tool）

插件会发送以下实时事件（`type=event`，`source_role=relay`）。

### 4.1 typing

开始输入：

```json
{
  "event_type":"typing",
  "payload":{
    "on":true,
    "state":"typing",
    "session_id":"<session_id>",
    "ts":1730000000000
  },
  "meta":{
    "channel":"sider",
    "account_id":"default",
    "schema_version":1
  }
}
```

停止输入时：`on=false`，`state=idle`。

### 4.2 stream.start

```json
{
  "event_type":"stream.start",
  "payload":{
    "session_id":"<session_id>",
    "stream_id":"<uuid>",
    "ts":1730000000000
  }
}
```

### 4.3 stream.delta

```json
{
  "event_type":"stream.delta",
  "payload":{
    "session_id":"<session_id>",
    "stream_id":"<uuid>",
    "seq":1,
    "delta":"你好，",
    "text":"你好，",
    "done":false,
    "chunk_chars":3,
    "ts":1730000000001
  }
}
```

说明：
- `delta` 为本帧新增文本
- `text` 为应用本帧后的完整可见文本快照，便于客户端直接覆盖当前流式内容

### 4.4 stream.done

```json
{
  "event_type":"stream.done",
  "payload":{
    "session_id":"<session_id>",
    "stream_id":"<uuid>",
    "seq":99,
    "done":true,
    "reason":"final|interrupted",
    "ts":1730000000999
  }
}
```

说明：
- `reason=final`：流式正常结束
- `reason=interrupted`：流式被中断（例如上游出错或中断）

### 4.5 tool.call

工具调用开始事件（来源于 OpenClaw `before_tool_call`）：

```json
{
  "event_type":"tool.call",
  "payload":{
    "session_id":"<session_id>",
    "seq":1,
    "call_id":"<uuid>",
    "phase":"start",
    "tool_name":"read",
    "tool_call_id":"<provider_call_id>",
    "run_id":"<run_id>",
    "session_key":"agent:main:...",
    "tool_args":{"path":"README.md"},
    "error":null,
    "duration_ms":null,
    "ts":1730000000002
  },
  "meta":{
    "channel":"sider",
    "account_id":"default",
    "schema_version":1
  }
}
```

说明：
- `call_id` 用于把同一次工具调用的 `tool.call` 和 `tool.result` 关联起来。
- `tool_args` 即工具参数（例如 `read` 的 `path`）。
- `tool_call_id` 为 provider 侧 call id（有则透传）。

### 4.6 tool.result

工具结果事件（来源于 OpenClaw `after_tool_call`）：

```json
{
  "event_type":"tool.result",
  "payload":{
    "session_id":"<session_id>",
    "seq":2,
    "call_id":"<uuid>",
    "tool_name":"read",
    "tool_call_id":"<provider_call_id>",
    "run_id":"<run_id>",
    "session_key":"agent:main:...",
    "tool_args":{"path":"README.md"},
    "result":{"content":[{"type":"text","text":"..."}]},
    "error":null,
    "duration_ms":32,
    "text":"",
    "has_text":false,
    "media_urls":[],
    "media_count":0,
    "is_error":false,
    "ts":1730000000003
  }
}
```

说明：
- `result` 为工具返回值（JSON-safe 序列化后）。
- `error` 非空时表示工具执行失败。
- `text` 为插件提取的“可读摘要”，仅从 `result.text/content/message/output/stdout` 取值，不做回退。
- `tool.result` 是工具阶段的实时事件，不替代最终 `type=message`。

---

## 5. 客户端渲染建议

- 使用 `stream_id + seq` 作为流式排序键；可继续按 `delta` 递增拼接，也可直接用 `text` 覆盖当前流式内容
- `stream.*` 仅用于实时渲染，不作为历史消息源
- `tool.call/tool.result` 仅用于实时状态，不作为历史消息源
- 最终以 `type=message` 的持久化消息为准（用于会话历史）
- 收到 `stream.done` 后，等待最终 `message` 到达再收敛 UI

---

## 6. 常见排查

- 看不到 typing/stream：
  - 检查是否连接到了同一个 `session_id`
  - 检查客户端是否处理了 `type=event`
- 发送成功但没收到最终回复：
  - 检查是否收到 `ack`
  - 检查 OpenClaw 日志中的 `sider` 相关错误
- 收到 `replaced`：
  - 表示同 `relay_id` 有新连接顶掉旧连接，需重连
