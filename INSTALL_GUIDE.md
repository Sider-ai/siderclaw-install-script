# OpenClaw 插件安装指南

本文档介绍如何为 OpenClaw 安装两个组件：**Sider Plugin** 和 **Remote Browser MCP**。

---

## 1. 安装 Sider Plugin

脚本会自动执行 `openclaw plugins install @hywkp/sider`；若已安装，自动尝试 `openclaw plugins update sider`。

### 方式一：Setup Token 模式

```bash
curl -fsSL https://raw.githubusercontent.com/Sider-ai/siderclaw-install-script/main/sider-openclaw-plugin/install-openclaw-plugin.sh | \
  SIDER_SETUP_TOKEN='<one-time-token>' \
  bash
```

脚本会写入 `channels.sider.enabled=true` 和 `channels.sider.setupToken`。
插件首次换取成功后，会自动写入长期 `gatewayUrl + token`，并删除 `setupToken`。
如果当前账号已经配置了 `gatewayUrl/token`，需要先移除，否则 setup token 交换不会触发。

### 方式二：直接配置 Gateway URL + Token

```bash
curl -fsSL https://raw.githubusercontent.com/Sider-ai/siderclaw-install-script/main/sider-openclaw-plugin/install-openclaw-plugin.sh | \
  SIDER_GATEWAY_URL='https://<gateway-url>' \
  SIDER_TOKEN='<access-token>' \
  bash
```

> 两种模式不要混用。

---

## 2. 安装 Remote Browser MCP

1. 安装 mcporter 工具

```bash
curl -fsSL https://raw.githubusercontent.com/Sider-ai/siderclaw-install-script/main/openclaw-setup-remote-browser-mcp.sh | \
  bash -s /path/to/workspace http://<browser-mcp-url>
```

| 参数 | 说明 |
|---|---|
| 第 1 个参数 | OpenClaw 工作目录路径 |
| 第 2 个参数 | Browser MCP 服务的实际地址（替换为真实 IP 或域名），脚本会自动拼接 `/mcp` 作为 MCP 端点 |

脚本会在工作目录下创建/更新以下文件：

1. `skills/remote-browser/SKILL.md` — remote-browser 技能定义
2. `config/mcporter.json` — 注册 remote-browser MCP Server
3. `TOOLS.md` — 添加 MCP Servers 描述
4. `AGENTS.md` — 添加 sider 浏览器操作规则

脚本具有幂等性，已存在且内容一致的文件会自动跳过。

---

## 3. 验证

### Sider Plugin

```bash
openclaw channels list
openclaw status --json
```

预期输出：`Sider default: configured, enabled`。

### Remote Browser MCP

```bash
mcporter servers                  # 确认 remote-browser 在列表中
mcporter tools remote-browser     # 查看可用工具
```
