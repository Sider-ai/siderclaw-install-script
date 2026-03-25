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
插件会调用 `POST https://selfclaw.apps.wisebox.ai/v1/claws/register`。
插件首次换取成功后，会自动写入长期 `token`，并删除 `setupToken`。

### 方式二：直接配置 Token

```bash
curl -fsSL https://raw.githubusercontent.com/Sider-ai/siderclaw-install-script/main/sider-openclaw-plugin/install-openclaw-plugin.sh | \
  SIDER_TOKEN='<relay-token>' \
  bash
```

> 两种模式不要混用；直接模式必须提供 `SIDER_TOKEN`。

---

## 2. 安装 Remote Browser MCP

1. 安装 mcporter 工具

2. 安装 remote browser skill 和配置

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

## 3. 安装 Phone MCP

配置 remote-phone skill 和 MCPorter siderclaw-phone 服务端。

```bash
curl -fsSL https://raw.githubusercontent.com/Sider-ai/siderclaw-install-script/main/openclaw-setup-phone-mcp.sh | \
  bash -s /path/to/workspace http://<phone-mcp-url>
```

| 参数 | 说明 |
|---|---|
| 第 1 个参数 | OpenClaw 工作目录路径 |
| 第 2 个参数 | Browser MCP 服务的实际地址（替换为真实 IP 或域名），脚本会自动拼接 `/mcp` 作为 MCP 端点 |

脚本会在工作目录下创建/更新以下文件：

1. `skills/remote-phone/SKILL.md` — remote-phone 技能定义
2. `config/mcporter.json` — 注册 siderclaw-phone MCP Server
3. `TOOLS.md` — 添加 MCP Servers 描述
4. `AGENTS.md` — 添加 siderclaw-phone 操作规则

脚本具有幂等性，已存在且内容一致的文件会自动跳过。

---

## 4. 验证

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

### Phone MCP

```bash
mcporter servers              # 确认 siderclaw-phone 在列表中
mcporter tools siderclaw-phone          # 查看可用工具
mcporter call siderclaw-phone.health_check --output json
```

---

## 4. 常见问题

### `Error: Cannot find module 'openclaw/plugin-sdk/plugin-entry'`

通常是本地还在使用旧版 `sider` 插件，或本次安装不完整。

新版插件已将 `openclaw` 作为依赖，更新或重新安装 `sider` 后会自动安装。若更新后仍有问题，删除本地 `sider` 插件后重新安装一次。
