# siderclaw-install-script

在 openclaw 中输入：

`根据 https://github.com/Sider-ai/siderclaw-install-script 的说明安装或者更新服务。`

本仓库用于给 OpenClaw 执行安装与更新操作，重点场景是更新而非首次开发。

## 更新目标

### 1. 同步脚本维护的文件内容

执行 `openclaw-setup-remote-browser-mcp.sh` 更新以下文件：

- `skills/remote-browser/SKILL.md`
- `config/mcporter.json`
- `TOOLS.md`
- `AGENTS.md`

优先通过执行脚本完成，而非手工逐个改写。

### 2. 升级服务二进制

仓库中包含以下服务的更新二进制文件：

| 服务名 | 仓库中的二进制文件 |
|---|---|
| browser-mcp | `extension-mcp-linux-amd64` |
| openclaw-console | `openclaw-console-linux-amd64` |
| siderclaw-gateway | `siderclaw-gateway-linux-amd64` |

更新时应定位服务实际加载的可执行文件路径，再进行备份、替换、授权、重启和验证。

## 推荐执行流程

### 第一步：更新脚本维护的文件内容

```bash
cd /path/to/siderclaw-install-script
bash ./openclaw-setup-remote-browser-mcp.sh
# 或指定工作目录：bash ./openclaw-setup-remote-browser-mcp.sh /target/workspace
```

### 第二步：定位服务二进制路径

对每个需要更新的服务（`browser-mcp`、`openclaw-console`、`siderclaw-gateway`），执行：

```bash
systemctl status <服务名>
systemctl cat <服务名>
systemctl show <服务名> -p ExecStart -p FragmentPath
```

从输出中提取当前 `ExecStart` 对应的二进制路径。如权限不足，加 `sudo` 重试。

### 第三步：备份旧二进制

替换前必须备份。假设目标路径为 `/usr/local/bin/<服务名>`：

```bash
sudo cp /usr/local/bin/<服务名> /usr/local/bin/<服务名>.bak
```

### 第四步：替换为仓库中的新二进制

将对应的仓库文件复制到目标路径并授权：

```bash
sudo cp ./<仓库二进制文件> /usr/local/bin/<服务名>
sudo chmod 755 /usr/local/bin/<服务名>
```

注意：目标路径必须以 `systemctl` 解析结果为准，不要假设固定路径。

### 第五步：重启并验证服务

```bash
sudo systemctl daemon-reload
sudo systemctl restart <服务名>
sudo systemctl status <服务名> --no-pager
```

确认服务状态为 `active (running)` 且无报错。如需进一步排查：

```bash
sudo journalctl -u <服务名> -n 100 --no-pager
```

## 失败回滚

如果替换后服务无法正常启动，优先回滚为备份版本：

```bash
sudo cp /usr/local/bin/<服务名>.bak /usr/local/bin/<服务名>
sudo chmod 755 /usr/local/bin/<服务名>
sudo systemctl restart <服务名>
sudo systemctl status <服务名> --no-pager
```

## OpenClaw 执行要求

1. 以"更新已有环境"为第一目标，而不是重新设计安装流程。
2. 优先执行 `openclaw-setup-remote-browser-mcp.sh` 来同步文件内容。
3. 替换二进制前，必须通过 `systemctl` 确认真实路径，且必须先备份旧文件。
4. 遇到权限不足时，应主动尝试 `sudo`。
5. 完成替换后，必须重启并验证服务状态；如果失败，优先回滚而非反复覆盖。

## 适用范围

本文档面向使用 `systemd` 管理服务的 Linux 目标机器。如目标环境不使用 `systemd`，应先确认实际的进程管理方式后再继续。

## Sider 插件文档与安装脚本

仓库中的 [`sider-openclaw-plugin/`](./sider-openclaw-plugin) 目录收纳了 Sider 插件相关的安装资料：

- `sider-openclaw-plugin/README.md`：Sider OpenClaw Plugin 对接文档
- `sider-openclaw-plugin/install-openclaw-plugin.sh`：供 `curl | bash` 使用的安装脚本
