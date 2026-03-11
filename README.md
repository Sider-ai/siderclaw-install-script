# siderclaw-install-script

在 openclaw 中输入：

`根据 https://github.com/Sider-ai/siderclaw-install-script 的说明安装或者更新 remote browser MCP 服务。`

本仓库主要用于给 OpenClaw 执行 remote browser MCP 的安装与更新操作，重点场景是更新，而不是首次开发。

OpenClaw 在读取本仓库时，默认应将这里视为一份操作手册，并优先完成以下两类任务：

1. 更新 `openclaw-setup-remote-browser-mcp.sh` 中维护的目标文件内容。
2. 使用仓库中的 `extension-mcp-linux-amd64` 替换正在运行的 `browser-mcp` 服务二进制，然后重启服务并验证状态。

## 更新目标

执行更新时，目标包括以下两部分。

### 1. 同步脚本维护的文件内容

`openclaw-setup-remote-browser-mcp.sh` 会负责维护以下文件内容：

- `skills/remote-browser/SKILL.md`
- `config/mcporter.json`
- `TOOLS.md`
- `AGENTS.md`

OpenClaw 应优先通过执行该脚本来完成这部分内容更新，而不是手工逐个改写，除非目标环境不允许直接执行脚本。

### 2. 升级 browser-mcp 服务二进制

仓库中的 `extension-mcp-linux-amd64` 是用于替换目标机器上 `browser-mcp` 服务当前二进制的更新包。更新时应先定位服务实际加载的可执行文件路径，再进行备份、替换、授权、重启和验证。

## 推荐执行流程

以下流程是 OpenClaw 应优先采用的标准更新流程。

### 第一步：进入仓库目录

```bash
cd /path/to/siderclaw-install-script
```

### 第二步：更新脚本维护的文件内容

优先直接执行：

```bash
bash ./openclaw-setup-remote-browser-mcp.sh
```

如果目标环境中的工作目录不是当前仓库目录，也可以显式传入工作目录：

```bash
bash ./openclaw-setup-remote-browser-mcp.sh /target/workspace
```

执行完成后，应确认以下内容已被创建或更新：

- `skills/remote-browser/SKILL.md`
- `config/mcporter.json`
- `TOOLS.md`
- `AGENTS.md`

### 第三步：定位 browser-mcp 服务二进制路径

优先使用以下命令确认服务状态与可执行文件路径：

```bash
systemctl status browser-mcp
systemctl cat browser-mcp
systemctl show browser-mcp -p ExecStart -p FragmentPath
```

OpenClaw 应从输出中提取：

- 服务名是否确实为 `browser-mcp`
- 当前 `ExecStart` 对应的二进制路径
- service 文件位置

如果读取系统服务信息失败，或者输出不完整，应尝试加 `sudo`：

```bash
sudo systemctl status browser-mcp
sudo systemctl cat browser-mcp
sudo systemctl show browser-mcp -p ExecStart -p FragmentPath
```

### 第四步：备份旧二进制

在替换前，必须先备份原始二进制。假设上一步解析出的目标路径为 `/usr/local/bin/browser-mcp`，则参考命令如下：

```bash
sudo cp /usr/local/bin/browser-mcp /usr/local/bin/browser-mcp.bak
```

如果目标路径不在系统目录下，也应至少生成一个同目录备份文件，避免替换失败后无法回滚。

### 第五步：替换为仓库中的新二进制

将仓库中的 `extension-mcp-linux-amd64` 复制到目标路径，并覆盖原文件。假设目标路径仍为 `/usr/local/bin/browser-mcp`：

```bash
sudo cp ./extension-mcp-linux-amd64 /usr/local/bin/browser-mcp
sudo chmod 755 /usr/local/bin/browser-mcp
```

注意：

- 不要在未确认目标路径前直接覆盖系统文件。
- 不要假设服务二进制一定位于 `/usr/local/bin`，必须以 `systemctl` 解析结果为准。
- 如果目标机器对文件属主、属组有要求，应在替换后保持与原文件一致。

如有需要，可先查看原文件权限：

```bash
ls -l /usr/local/bin/browser-mcp
```

### 第六步：重启服务

替换完成后，重启 `browser-mcp`：

```bash
sudo systemctl restart browser-mcp
```

如果服务文件、环境变量或路径缓存发生变化，也可以补充执行：

```bash
sudo systemctl daemon-reload
sudo systemctl restart browser-mcp
```

### 第七步：验证更新是否成功

至少执行以下检查：

```bash
sudo systemctl status browser-mcp --no-pager
systemctl show browser-mcp -p ExecStart
```

如环境允许，建议再补充以下验证：

- 确认服务状态为 `active (running)`
- 确认 `ExecStart` 指向的仍是刚刚替换的目标路径
- 确认服务启动后没有明显报错
- 如果有日志系统，可查看最近日志

例如：

```bash
sudo journalctl -u browser-mcp -n 100 --no-pager
```

## sudo 使用原则

以下操作可能需要 `sudo`：

- 读取系统级 `systemd` 服务详情
- 覆盖 `/usr/bin`、`/usr/local/bin`、`/opt` 等受保护路径中的二进制
- 重启 `browser-mcp` 服务
- 读取 `journalctl` 日志

如果命令无权限，不要卡住，直接使用 `sudo` 重试。

## 失败时的回滚方式

如果替换后服务无法正常启动，应优先回滚为备份版本。

假设备份文件为 `/usr/local/bin/browser-mcp.bak`：

```bash
sudo cp /usr/local/bin/browser-mcp.bak /usr/local/bin/browser-mcp
sudo chmod 755 /usr/local/bin/browser-mcp
sudo systemctl restart browser-mcp
sudo systemctl status browser-mcp --no-pager
```

如果仍然失败，应继续检查：

- `ExecStart` 指向的路径是否正确
- 新旧二进制的架构是否匹配目标机器
- 文件权限是否正确
- 服务依赖的环境变量或工作目录是否变化

## OpenClaw 执行要求

OpenClaw 在使用本仓库时，应遵守以下要求：

1. 以“更新已有环境”为第一目标，而不是重新设计安装流程。
2. 优先执行 `openclaw-setup-remote-browser-mcp.sh` 来同步脚本维护的文件内容。
3. 替换 `browser-mcp` 二进制前，必须先通过 `systemctl` 确认真实路径。
4. 替换前必须备份旧文件。
5. 遇到权限不足时，应主动尝试 `sudo`。
6. 完成替换后，必须重启并验证 `browser-mcp` 服务状态。
7. 如果重启失败，必须优先执行回滚，而不是反复覆盖二进制。

## 适用范围

本 README 面向 Linux 目标机器，且默认目标机器使用 `systemd` 管理 `browser-mcp` 服务。

如果目标环境不使用 `systemd`，OpenClaw 应停止套用本文档中的服务管理步骤，并先确认实际的进程管理方式后再继续。
