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

安装并写入 `channels.sider` 配置：

```bash
curl -fsSL https://raw.githubusercontent.com/Sider-ai/siderclaw-install-script/main/sider-openclaw-plugin/install-openclaw-plugin.sh | \
  SIDER_GATEWAY_URL='http://127.0.0.1:8080' \
  bash
```

如需同时写入默认发送目标（以及兼容旧版的单 session 过滤配置）：

```bash
curl -fsSL https://raw.githubusercontent.com/Sider-ai/siderclaw-install-script/main/sider-openclaw-plugin/install-openclaw-plugin.sh | \
  SIDER_GATEWAY_URL='http://127.0.0.1:8080' \
  SIDER_SESSION_ID='s1' \
  bash
```

安装参数说明：
- `SIDER_SESSION_ID`：可选；若提供，会写入 `sessionId/sessionKey/defaultTo`，用于默认发送目标和兼容旧版单 session 过滤
- `SIDER_GATEWAY_URL`：可选，默认 `http://127.0.0.1:8080`
- `SIDER_RELAY_ID`：可选，不传则使用插件默认值
- `SIDER_RELAY_TOKEN`：可选，仅在 gateway 开启 relay token 校验时需要
- `SIDER_SESSION_KEY`：旧变量名，脚本会自动映射到 `SIDER_SESSION_ID`

不传 `SIDER_SESSION_ID` 时，relay monitor 默认接收所有 session 的消息。

---

## 2. OpenClaw 配置示例

`~/.openclaw/openclaw.json`：

```json
{
  "channels": {
    "sider": {
      "enabled": true,
      "gatewayUrl": "http://127.0.0.1:8080",
      "relayId": "openclaw-default"
    }
  }
}
```

如需给主动发送场景提供默认目标，可额外设置：

```json
{
  "channels": {
    "sider": {
      "defaultTo": "session:siderclaw-default"
    }
  }
}
```

兼容旧版单 session 监听时，也可保留：
- `sessionId`
- `sessionKey`

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
