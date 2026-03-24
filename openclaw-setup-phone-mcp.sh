#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_DIR="${1:-$(cd "$(dirname "$0")" && pwd)}"
BASE_URL="${2:-http://localhost:14355}"
MCP_URL="$BASE_URL/mcp"
SKILL_DIR="$WORKSPACE_DIR/skills/remote-phone"
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
echo " OpenClaw Phone MCP 一键配置脚本"
echo "=========================================="
echo "工作目录: $WORKSPACE_DIR"
echo "MCP 地址: $MCP_URL"
echo ""

# ──────────────────────────────────────────────
# Step 1: 安装 remote-phone 技能
# ──────────────────────────────────────────────
echo "[1/4] 安装 remote-phone 技能..."
mkdir -p "$SKILL_DIR"

# 获取技能内容（优先从同目录读取，否则使用内嵌版本）
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_SOURCE=""
if [ -f "$SCRIPT_DIR/openclaw-skill/SKILL.md" ]; then
    SKILL_SOURCE="$SCRIPT_DIR/openclaw-skill/SKILL.md"
fi

install_skill() {
    if [ -n "$SKILL_SOURCE" ]; then
        cp "$SKILL_SOURCE" "$SKILL_DIR/SKILL.md"
        ok "skills/remote-phone/SKILL.md 已从源文件复制"
    else
        cat > "$SKILL_DIR/SKILL.md" << 'SKILL_EOF'
---
name: remote_phone
description: "Control Android devices — observe screen, tap, swipe, input text, launch apps, run shell. Activates when the user asks to interact with their phone."
metadata:
  { "openclaw": { "emoji": "📱", "requires": { "bins": ["mcporter"] } } }
allowed-tools: ["exec"]
user-invocable: false
---

# Android Device Automation

你是一个 Android 设备自动化代理。通过观察当前屏幕、选择最佳操作、并在每次有意义的交互后验证结果来完成用户目标。

所有操作通过 MCPorter 调用 siderclaw-phone MCP 服务完成。

## MCPorter 调用语法（必须严格遵守）

```
mcporter call siderclaw-phone.<工具名> --args '<JSON>' --output json
```

### 禁止的调用方式
```
# 错误：直接传 JSON 作为位置参数（mcporter 会按冒号拆分导致参数错乱）
mcporter call siderclaw-phone.tap '{"x": 100, "y": 200}'

# 错误：key=value 格式
mcporter call siderclaw-phone.tap x=100 y=200
```

**始终且只能使用 `--args '<JSON>'` 格式传参。**

## 可用工具

- health_check：检查设备连接性和核心能力可用性。
- get_device_info：查看当前前台应用、锁屏状态和屏幕信息。
- get_capabilities：查看支持的操作和运行时能力。
- list_displays：查看可用的物理和虚拟显示。
- create_virtual_display：需要独立显示时创建托管虚拟显示。
- release_display：释放不再需要的虚拟显示。
- list_apps：目标应用不明确时查看已安装的应用。
- capture_screen：从指定显示截取原始截图，返回 `filePath`（不含 base64）。
- launch_app：通过包名直接打开已知应用。
- launch_intent：启动任意 Android Intent（action + data URI + extras）。
- get_ui_tree：获取原始无障碍树，包含每个节点的完整文本。
- observe：截取当前屏幕截图和 UI 摘要，返回短元素 ID 和截图 `filePath`。
- find_element：使用选择器对象搜索当前无障碍树。
- tap：直接点击精确坐标。
- long_press：直接长按精确坐标。
- smart_tap：通过 ID、文本查询或坐标点击可见元素。
- input_text：在已聚焦的输入框中输入文字。
- smart_input：聚焦输入框并输入文字。
- run_shell：在设备上执行 Shell 命令。
- swipe：滚动或在屏幕外内容间移动。
- press_back：返回上一页或关闭对话框。
- press_home：返回启动器。

## 工具调用示例

```
mcporter call siderclaw-phone.observe --args '{"displayId": 0}' --output json
mcporter call siderclaw-phone.smart_tap --args '{"on": "B3"}' --output json
mcporter call siderclaw-phone.smart_input --args '{"on": "T1", "text": "你好"}' --output json
mcporter call siderclaw-phone.swipe --args '{"startX": 540, "startY": 1500, "endX": 540, "endY": 500}' --output json
mcporter call siderclaw-phone.launch_app --args '{"packageName": "com.tencent.mm"}' --output json
mcporter call siderclaw-phone.press_back --output json
```
SKILL_EOF
        ok "skills/remote-phone/SKILL.md 已创建（内嵌版本）"
    fi
}

if [ -f "$SKILL_DIR/SKILL.md" ]; then
    if [ -n "$SKILL_SOURCE" ]; then
        if diff -q "$SKILL_SOURCE" "$SKILL_DIR/SKILL.md" > /dev/null 2>&1; then
            skip "skills/remote-phone/SKILL.md（已是最新版本）"
        else
            echo "  → 检测到旧版 SKILL.md，正在升级..."
            install_skill
        fi
    else
        skip "skills/remote-phone/SKILL.md"
    fi
else
    install_skill
fi

# ──────────────────────────────────────────────
# Step 2: 配置 config/mcporter.json
# ──────────────────────────────────────────────
echo ""
echo "[2/4] 配置 config/mcporter.json..."
mkdir -p "$CONFIG_DIR"

PHONE_BASEURL="$MCP_URL"

if [ -f "$MCPORTER_FILE" ]; then
    CURRENT_URL=$(python3 -c "
import json
try:
    with open('$MCPORTER_FILE', 'r') as f:
        data = json.load(f)
    url = data.get('mcpServers', {}).get('siderclaw-phone', {}).get('baseUrl', '')
    print(url)
except Exception:
    print('')
" 2>/dev/null || true)
    if [ "$CURRENT_URL" = "$PHONE_BASEURL" ]; then
        skip "mcporter.json 中 siderclaw-phone 配置（已是正确 baseUrl）"
    else
        python3 -c "
import json
with open('$MCPORTER_FILE', 'r') as f:
    data = json.load(f)
if 'mcpServers' not in data:
    data['mcpServers'] = {}
data['mcpServers']['siderclaw-phone'] = {'baseUrl': '$PHONE_BASEURL'}
if 'imports' not in data:
    data['imports'] = []
with open('$MCPORTER_FILE', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"
        if [ -n "$CURRENT_URL" ]; then
            ok "mcporter.json 已升级 siderclaw-phone baseUrl → $PHONE_BASEURL"
        else
            ok "mcporter.json 已更新，添加 siderclaw-phone"
        fi
    fi
else
    cat > "$MCPORTER_FILE" << JSON_EOF
{
  "mcpServers": {
    "siderclaw-phone": {
      "baseUrl": "$PHONE_BASEURL"
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

TOOLS_CANONICAL_LINE="- **siderclaw-phone** — Android device control via MCP at $MCP_URL"

if [ ! -f "$TOOLS_FILE" ]; then
    cat > "$TOOLS_FILE" << TOOLS_EOF
# TOOLS.md - Local Notes

Skills define _how_ tools work. This file is for _your_ specifics — the stuff that's unique to your setup.

## MCP Servers

- **siderclaw-phone** — Android device control via MCP at $MCP_URL
  - Use \`mcporter call siderclaw-phone.<tool>\` to invoke tools
TOOLS_EOF
    ok "TOOLS.md 已创建（含 MCP Servers 段落）"
elif grep -qF "$TOOLS_CANONICAL_LINE" "$TOOLS_FILE"; then
    skip "TOOLS.md 中 siderclaw-phone 描述（已是最新）"
else
    python3 -c "
import re
tools_file = '$TOOLS_FILE'
canonical = '''- **siderclaw-phone** — Android device control via MCP at $MCP_URL
  - Use \`mcporter call siderclaw-phone.<tool>\` to invoke tools'''
with open(tools_file, 'r') as f:
    content = f.read()

# 若已有任意 siderclaw-phone 或旧版 phone 条目，先删掉整段（含所有缩进子行）
content = re.sub(
    r'\n- \*\*(?:siderclaw-)?phone\*\*.*?(?=\n(?:- \*\*|\#\#)|$)',
    '',
    content,
    count=1,
    flags=re.DOTALL
)
# 确保有 ## MCP Servers 段落
if '## MCP Servers' not in content:
    content = content.rstrip() + '\n\n## MCP Servers\n\n' + canonical + '\n'
else:
    idx = content.find('## MCP Servers')
    line_end = content.find('\n', idx)
    content = content[:line_end+1] + canonical + '\n' + content[line_end+1:]
with open(tools_file, 'w') as f:
    f.write(content)
"
    ok "TOOLS.md 已更新/升级 siderclaw-phone 描述"
fi

# ──────────────────────────────────────────────
# Step 4: 在 AGENTS.md 的 ## Every Session 中添加 siderclaw-phone 规则
# ──────────────────────────────────────────────
echo ""
echo "[4/4] 更新 AGENTS.md..."

PHONE_RULE='- 当用户要求操作手机、Android 设备时，必须基于 remote-phone skill 走 mcporter siderclaw-phone；若不可用，直接报错并提示修复，不得回退到其他工具。'

if [ ! -f "$AGENTS_FILE" ]; then
    cat > "$AGENTS_FILE" << AGENTS_EOF
# AGENTS.md - Your Workspace

## Every Session

Before doing anything else:

1. Read \`SOUL.md\` — this is who you are
2. Read \`USER.md\` — this is who you're helping
3. Read \`memory/YYYY-MM-DD.md\` (today + yesterday) for recent context
$PHONE_RULE

Don't ask permission. Just do it.
AGENTS_EOF
    ok "AGENTS.md 已创建（含 siderclaw-phone 规则）"
elif grep -qF "$PHONE_RULE" "$AGENTS_FILE"; then
    skip "AGENTS.md 中 siderclaw-phone 规则（已是最新）"
elif grep -q 'mcporter siderclaw-phone' "$AGENTS_FILE"; then
    python3 -c "
agents_file = '$AGENTS_FILE'
phone_rule = '- 当用户要求操作手机、Android 设备时，必须基于 remote-phone skill 走 mcporter siderclaw-phone；若不可用，直接报错并提示修复，不得回退到其他工具。\n'
with open(agents_file, 'r') as f:
    lines = f.readlines()
new_lines = []
for line in lines:
    if 'mcporter siderclaw-phone' in line and line.strip().startswith('-'):
        new_lines.append(phone_rule)
    else:
        new_lines.append(line)
with open(agents_file, 'w') as f:
    f.writelines(new_lines)
"
    ok "AGENTS.md 已升级 siderclaw-phone 规则为最新表述"
elif grep -q '## Every Session' "$AGENTS_FILE"; then
    python3 -c "
agents_file = '$AGENTS_FILE'
with open(agents_file, 'r') as f:
    lines = f.readlines()

phone_rule = '- 当用户要求操作手机、Android 设备时，必须基于 remote-phone skill 走 mcporter siderclaw-phone；若不可用，直接报错并提示修复，不得回退到其他工具。\n'

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
    lines.insert(insert_before, phone_rule + '\n')
elif in_every_session:
    if lines and lines[-1].strip() != '':
        lines.append('\n')
    lines.append(phone_rule + '\n')

with open(agents_file, 'w') as f:
    f.writelines(lines)
"
    ok "AGENTS.md 的 Every Session 段落已追加 siderclaw-phone 规则"
else
    printf '\n## Every Session\n\n%s\n' "$PHONE_RULE" >> "$AGENTS_FILE"
    ok "AGENTS.md 已追加 Every Session 段落（含 siderclaw-phone 规则）"
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
echo "  1. skills/remote-phone/SKILL.md"
echo "  2. config/mcporter.json"
echo "  3. TOOLS.md (MCP Servers 段落)"
echo "  4. AGENTS.md (Every Session siderclaw-phone 规则)"
echo ""
echo "验证命令:"
echo "  mcporter servers              # 确认 siderclaw-phone 在列表中"
echo "  mcporter tools siderclaw-phone          # 查看可用工具"
echo "  mcporter call siderclaw-phone.health_check --output json"
