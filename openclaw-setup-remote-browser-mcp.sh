#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_DIR="${1:-$(cd "$(dirname "$0")" && pwd)}"
SKILL_DIR="$WORKSPACE_DIR/skills/remote-browser"
CONFIG_DIR="$WORKSPACE_DIR/config"
MCPORTER_FILE="$CONFIG_DIR/mcporter.json"
TOOLS_FILE="$WORKSPACE_DIR/TOOLS.md"
AGENTS_FILE="$WORKSPACE_DIR/AGENTS.md"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
skip() { echo -e "  ${YELLOW}→${NC} $1 (已存在，跳过)"; }

echo "=========================================="
echo " OpenClaw Remote Browser 一键配置脚本"
echo "=========================================="
echo "工作目录: $WORKSPACE_DIR"
echo ""

# ──────────────────────────────────────────────
# Step 1: 安装 remote-browser 技能
# ──────────────────────────────────────────────
echo "[1/4] 安装 remote-browser 技能..."
mkdir -p "$SKILL_DIR"

if [ -f "$SKILL_DIR/SKILL.md" ]; then
    if grep -q 'MCPorter 调用语法' "$SKILL_DIR/SKILL.md"; then
        skip "skills/remote-browser/SKILL.md（已是最新版本）"
    else
        echo "  → 检测到旧版 SKILL.md（缺少 --args 语法规范），正在升级..."
        rm -f "$SKILL_DIR/SKILL.md"
    fi
fi

if [ ! -f "$SKILL_DIR/SKILL.md" ]; then
    cat > "$SKILL_DIR/SKILL.md" << 'SKILL_EOF'
---
name: remote-browser
description: 操控用户本地浏览器执行自动化任务。当用户要求在其浏览器中完成任何操作时必须使用此 skill，包括：打开/跳转网页、点击按钮/链接、表单填写与提交、截图、抓取页面内容或结构、监控网络请求、读取控制台日志、多标签页并行操作，以及注入脚本修改网页 UI。此 skill 通过 MCPorter + remote-browser MCP 服务，基于 Chrome DevTools Protocol (CDP) 直接接管用户当前标签页——注意这是用户真实浏览器，而非沙盒环境。
---

# Remote Browser — 浏览器工具的网页自动化工具

浏览器任务通常需要长时间运行的自主代理能力。当你遇到一个看起来耗时较长或范围较大的用户请求时，你应当坚持完成任务，并使用所有可用的上下文来达成目标。用户知道你存在上下文限制，并期望你能自主工作直到任务完成。如果任务需要，应充分利用完整的上下文窗口。

你具备同时操作多个浏览器标签页的能力。这能让你更高效地并行处理不同任务。

## 工具使用要求
- 先使用 "read_page" 工具为所有 DOM 元素分配引用标识并获取页面概览。这样即使视口大小变化，或者元素滚动到可视区域之外，OpenClaw 也能可靠地在页面上执行操作。
- OpenClaw 在页面上执行操作时，会尽可能使用 DOM 元素的显式引用（例如 ref_123），通过 “computer” 工具的 “left_click” 动作以及 "fill_form" 工具来操作。只有在引用方式失败，或者 OpenClaw 需要使用引用方式不支持的操作（例如拖拽）时，才使用基于坐标的操作。
- OpenClaw 会避免反复向下滚动长网页来阅读内容，而是改用 “get_page_text” 和 “read_page” 工具高效读取页面内容。
- 对于一些复杂的网页应用，例如 Google Docs、Figma、Canva 和 Google Slides，视觉工具更容易使用。如果 OpenClaw 在使用 “read_page” 工具时没有找到有意义的页面内容，那么 OpenClaw 会使用截图来查看内容。


## 最佳实践
- 如果你还没有有效 tabId，务必先调用 get_tabs
- 使用多个标签页提升效率（例如在一个标签页做研究，同时在另一个标签页填写表单）
- 每次工具调用后都要留意返回的标签页上下文
- 通过点击链接或使用 tab_create 创建的新标签页会自动加入可用列表
- 每个标签页保持自己的状态（滚动位置、页面加载状态等）
- **任务完成后，必须调用 task_done 工具通知用户**


**所有的操作都需要基于 MCPorter 调度 remote-browser MCP 服务完成。**

## MCPorter 调用语法（极其重要，必须严格遵守）

必须使用 `--args` 参数传递 JSON 对象，这是唯一正确的调用方式：

```
mcporter call remote-browser.<tool_name> --args '<JSON>' --output json
```

### 常见错误（禁止使用）

```
# 错误 1：直接传 JSON 作为位置参数（mcporter 会按冒号拆分导致参数错乱）
mcporter call remote-browser.navigate '{"url": "https://example.com", "tabId": 123}'

# 错误 2：key=value 中 URL 包含冒号会导致解析失败
mcporter call remote-browser.navigate url=https://example.com tabId=123

# 错误 3：function-call 语法容易出错
mcporter call 'remote-browser.navigate(url: "...", tabId: 123)'
```

**始终且只能使用 `--args '<JSON>'` 格式传参。**

## 工具列表与参数说明（共 12 个工具）

以下是所有可用工具，参数名必须与文档完全一致，不得使用别名。

### 1. get_tabs — 获取标签页列表
无需参数。如果你还没有有效的 tabId，必须首先调用此工具。
```
mcporter call remote-browser.get_tabs --output json
```

### 2. navigate — 页面导航
参数：`url`（必填，字符串）、`tabId`（必填，数字）
```
mcporter call remote-browser.navigate --args '{"url": "https://example.com", "tabId": 123456}' --output json
```

### 3. read_page — 读取页面可访问性树
参数：`tabId`（必填）、`filter`（可选："interactive"|"all"）、`depth`（可选，数字）、`ref_id`（可选，字符串）、`max_chars`（可选，数字）
```
mcporter call remote-browser.read_page --args '{"tabId": 123456}' --output json
mcporter call remote-browser.read_page --args '{"tabId": 123456, "filter": "interactive"}' --output json
```

### 4. execute_script — 执行 JavaScript
参数：**`code`**（必填，字符串，注意参数名是 code 不是 script）、`tabId`（必填）
```
mcporter call remote-browser.execute_script --args '{"code": "document.title", "tabId": 123456}' --output json
```

### 5. computer — 鼠标键盘与截图
参数：`action`（必填）、`tabId`（必填），以及各 action 对应的额外参数。

截图：
```
mcporter call remote-browser.computer --args '{"action": "screenshot", "tabId": 123456}' --output json
```
点击：
```
mcporter call remote-browser.computer --args '{"action": "left_click", "coordinate": [500, 300], "tabId": 123456}' --output json
```
输入文字：
```
mcporter call remote-browser.computer --args '{"action": "type", "text": "hello world", "tabId": 123456}' --output json
```
按键：
```
mcporter call remote-browser.computer --args '{"action": "key", "text": "Enter", "tabId": 123456}' --output json
```
滚动：
```
mcporter call remote-browser.computer --args '{"action": "scroll", "coordinate": [500, 300], "scroll_direction": "down", "tabId": 123456}' --output json
```
等待：
```
mcporter call remote-browser.computer --args '{"action": "wait", "duration": 3, "tabId": 123456}' --output json
```
局部放大查看：
```
mcporter call remote-browser.computer --args '{"action": "zoom", "region": [100, 100, 400, 400], "tabId": 123456}' --output json
```
滚动到元素：
```
mcporter call remote-browser.computer --args '{"action": "scroll_to", "ref": "ref_5", "tabId": 123456}' --output json
```

### 6. get_page_text — 获取页面纯文本
参数：`tabId`（必填）、`max_chars`（可选）
```
mcporter call remote-browser.get_page_text --args '{"tabId": 123456}' --output json
```

### 7. fill_form — 填写表单
参数：`ref`（必填，来自 read_page 的 ref ID）、`value`（必填）、`tabId`（必填）
```
mcporter call remote-browser.fill_form --args '{"ref": "ref_1", "value": "hello", "tabId": 123456}' --output json
```

### 8. tab_create — 创建新标签页
无需参数。
```
mcporter call remote-browser.tab_create --output json
```

### 9. read_console_messages — 读取控制台消息
参数：`tabId`（必填）、`pattern`（推荐提供）、`onlyErrors`（可选，布尔）、`clear`（可选，布尔）、`limit`（可选，数字）
```
mcporter call remote-browser.read_console_messages --args '{"tabId": 123456, "pattern": "error"}' --output json
```

### 10. read_network_requests — 读取网络请求
参数：`tabId`（必填）、`urlPattern`（可选）、`clear`（可选，布尔）、`limit`（可选，数字）
```
mcporter call remote-browser.read_network_requests --args '{"tabId": 123456, "urlPattern": "/api/"}' --output json
```

### 11. resize_window — 调整窗口大小
参数：`width`（必填）、`height`（必填）、`tabId`（必填）
```
mcporter call remote-browser.resize_window --args '{"width": 1280, "height": 800, "tabId": 123456}' --output json
```

### 12. task_done — 任务完成
无需参数。任务完成后必须调用此工具。
```
mcporter call remote-browser.task_done --output json
```

SKILL_EOF
    ok "skills/remote-browser/SKILL.md 已创建"
fi

# ──────────────────────────────────────────────
# Step 2: 配置 config/mcporter.json
# ──────────────────────────────────────────────
echo ""
echo "[2/4] 配置 config/mcporter.json..."
mkdir -p "$CONFIG_DIR"

REMOTE_BROWSER_ENTRY='"remote-browser": { "baseUrl": "http://localhost:3000/mcp" }'

if [ -f "$MCPORTER_FILE" ]; then
    if grep -q '"remote-browser"' "$MCPORTER_FILE"; then
        skip "mcporter.json 中 remote-browser 配置"
    else
        python3 -c "
import json, sys
with open('$MCPORTER_FILE', 'r') as f:
    data = json.load(f)
if 'mcpServers' not in data:
    data['mcpServers'] = {}
data['mcpServers']['remote-browser'] = {'baseUrl': 'http://localhost:3000/mcp'}
if 'imports' not in data:
    data['imports'] = []
with open('$MCPORTER_FILE', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"
        ok "mcporter.json 已更新，添加 remote-browser"
    fi
else
    cat > "$MCPORTER_FILE" << 'JSON_EOF'
{
  "mcpServers": {
    "remote-browser": {
      "baseUrl": "http://localhost:3000/mcp"
    }
  },
  "imports": []
}
JSON_EOF
    ok "mcporter.json 已创建"
fi

# ──────────────────────────────────────────────
# Step 3: 在 TOOLS.md 中添加 MCP Servers 描述
# ──────────────────────────────────────────────
echo ""
echo "[3/4] 更新 TOOLS.md..."

MCP_BLOCK='## MCP Servers

- **remote-browser** — Remote browser control via MCP at http://localhost:3000/mcp
  - Use `mcporter call remote-browser.<tool>` to invoke tools'

if [ ! -f "$TOOLS_FILE" ]; then
    cat > "$TOOLS_FILE" << 'TOOLS_EOF'
# TOOLS.md - Local Notes

Skills define _how_ tools work. This file is for _your_ specifics — the stuff that's unique to your setup.

## MCP Servers

- **remote-browser** — Remote browser control via MCP at http://localhost:3000/mcp
  - Use `mcporter call remote-browser.<tool>` to invoke tools
TOOLS_EOF
    ok "TOOLS.md 已创建（含 MCP Servers 段落）"
elif grep -q 'remote-browser.*Remote browser control via MCP' "$TOOLS_FILE"; then
    skip "TOOLS.md 中 remote-browser 描述"
elif grep -q '## MCP Servers' "$TOOLS_FILE"; then
    python3 -c "
import sys
with open('$TOOLS_FILE', 'r') as f:
    content = f.read()
insert = '''
- **remote-browser** — Remote browser control via MCP at http://localhost:3000/mcp
  - Use \`mcporter call remote-browser.<tool>\` to invoke tools
'''
idx = content.find('## MCP Servers')
line_end = content.find('\n', idx)
content = content[:line_end+1] + insert + content[line_end+1:]
with open('$TOOLS_FILE', 'w') as f:
    f.write(content)
"
    ok "TOOLS.md 的 MCP Servers 段落已追加 remote-browser"
else
    printf '\n%s\n' "$MCP_BLOCK" >> "$TOOLS_FILE"
    ok "TOOLS.md 已追加 MCP Servers 段落"
fi

# ──────────────────────────────────────────────
# Step 4: 在 AGENTS.md 的 ## Every Session 中添加 sider 规则
# ──────────────────────────────────────────────
echo ""
echo "[4/4] 更新 AGENTS.md..."

SIDER_RULE='- 在 channel=sider 且用户请求浏览器操作时，必须基于 remote-browser skill 优先走 mcporter remote-browser；若不可用，直接报错并提示修复，不得回退到内置 browser 工具。'

if [ ! -f "$AGENTS_FILE" ]; then
    cat > "$AGENTS_FILE" << AGENTS_EOF
# AGENTS.md - Your Workspace

## Every Session

Before doing anything else:

1. Read \`SOUL.md\` — this is who you are
2. Read \`USER.md\` — this is who you're helping
3. Read \`memory/YYYY-MM-DD.md\` (today + yesterday) for recent context
$SIDER_RULE

Don't ask permission. Just do it.
AGENTS_EOF
    ok "AGENTS.md 已创建（含 sider 规则）"
elif grep -qF 'channel=sider' "$AGENTS_FILE"; then
    skip "AGENTS.md 中 sider 规则"
elif grep -q '## Every Session' "$AGENTS_FILE"; then
    python3 -c "
import sys
agents_file = '$AGENTS_FILE'
with open(agents_file, 'r') as f:
    lines = f.readlines()

sider_rule = '- 在 channel=sider 且用户请求浏览器操作时，必须基于 remote-browser skill 优先走 mcporter remote-browser；若不可用，直接报错并提示修复，不得回退到内置 browser 工具。\n'

in_every_session = False
next_section_idx = None

for i, line in enumerate(lines):
    if line.strip() == '## Every Session':
        in_every_session = True
        continue
    if in_every_session and line.startswith('## ') and 'Every Session' not in line:
        next_section_idx = i
        break

if next_section_idx is not None:
    insert_before = next_section_idx
    while insert_before > 0 and lines[insert_before - 1].strip() == '':
        insert_before -= 1
    lines.insert(insert_before, sider_rule + '\n')
elif in_every_session:
    if lines and lines[-1].strip() != '':
        lines.append('\n')
    lines.append(sider_rule + '\n')

with open(agents_file, 'w') as f:
    f.writelines(lines)
"
    ok "AGENTS.md 的 Every Session 段落已追加 sider 规则"
else
    printf '\n## Every Session\n\n%s\n' "$SIDER_RULE" >> "$AGENTS_FILE"
    ok "AGENTS.md 已追加 Every Session 段落（含 sider 规则）"
fi

# ──────────────────────────────────────────────
# 完成
# ──────────────────────────────────────────────
echo ""
echo "=========================================="
echo " 配置完成！"
echo "=========================================="
echo ""
echo "已配置项目:"
echo "  1. skills/remote-browser/SKILL.md"
echo "  2. config/mcporter.json"
echo "  3. TOOLS.md (MCP Servers 段落)"
echo "  4. AGENTS.md (Every Session sider 规则)"
echo ""
echo "验证命令:"
echo "  mcporter servers        # 确认 remote-browser 在列表中"
echo "  mcporter tools remote-browser  # 查看可用工具"
