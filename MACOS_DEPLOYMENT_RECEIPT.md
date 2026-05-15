# macOS 部署支持修改回执

本次修改目标：在保留 Linux systemd 部署能力的前提下，让 fork 仓库 `jackb6552/OpenClaw-Chat-Gateway` 可以在 macOS 上通过一键脚本安装、启动、升级和卸载。

## 已修改文件

### 1. `install.sh`

- 将 `REPO_URL` 从上游仓库改为当前 fork：

```text
https://github.com/jackb6552/OpenClaw-Chat-Gateway.git
```

- 将原本只允许 Linux 的系统检查改为支持：
  - Linux：继续要求 `systemctl`
  - macOS：要求 `launchctl`
- 增加 macOS 本地 IP 获取逻辑。
- LibreOffice 提示中增加 macOS 安装命令：

```bash
brew install --cask libreoffice
```

### 2. `deploy-release.sh`

- 保留 Linux 原有 `systemd --user` 部署路径。
- 新增 macOS `launchd` 部署路径。
- macOS 下会生成：

```text
~/Library/LaunchAgents/cc.angeworld.clawui.<端口>.plist
```

- macOS 服务启动方式：

```bash
launchctl bootstrap gui/$(id -u) <plist>
launchctl kickstart -k gui/$(id -u)/cc.angeworld.clawui.<端口>
```

- macOS 日志路径：

```text
~/Library/Logs/OpenClaw-Chat-Gateway/clawui-<端口>.out.log
~/Library/Logs/OpenClaw-Chat-Gateway/clawui-<端口>.err.log
```

- 服务环境变量包含：
  - `PORT`
  - `NODE_ENV=production`
  - `CLAWUI_DATA_DIR=.clawui_release`
  - `HOME`
  - `PATH`
- `PATH` 增加 `/opt/homebrew/bin`，兼容 Apple Silicon Homebrew。

### 3. `update.sh`

- 将原 Linux-only 更新流程改为支持 Linux 和 macOS。
- Linux 继续检测：

```text
~/.config/systemd/user/clawui-*.service
```

- macOS 检测：

```text
~/Library/LaunchAgents/cc.angeworld.clawui.*.plist
```

- 自动识别已有端口后调用：

```bash
./deploy-release.sh <端口>
```

### 4. `uninstall.sh`

- 支持清理 Linux systemd 服务。
- 支持清理 macOS launchd plist 服务。
- 会清理：
  - 项目目录
  - `.clawui` / `.clawui_release` / `.clawui_dev`
  - OpenClaw workspace 目录
  - `~/Library/Logs/OpenClaw-Chat-Gateway`

### 5. `README.md`

- 将安装、更新、卸载命令改为当前 fork 地址。
- 将系统要求说明从“只支持 Linux”改为“支持 Linux(systemd) 和 macOS(launchd)”。
- 增加 macOS LibreOffice 安装说明。

## 当前 macOS 安装命令

默认端口 3115：

```bash
curl -fsSL https://raw.githubusercontent.com/jackb6552/OpenClaw-Chat-Gateway/main/install.sh | bash
```

自定义端口，例如 8080：

```bash
curl -fsSL https://raw.githubusercontent.com/jackb6552/OpenClaw-Chat-Gateway/main/install.sh | bash -s 8080
```

## macOS 服务状态查看

默认端口 3115：

```bash
launchctl print gui/$(id -u)/cc.angeworld.clawui.3115
```

## macOS 日志查看

```bash
tail -f ~/Library/Logs/OpenClaw-Chat-Gateway/clawui-3115.out.log
tail -f ~/Library/Logs/OpenClaw-Chat-Gateway/clawui-3115.err.log
```

## 注意事项

- 本次修改解决的是 OpenClaw Chat Gateway 的 macOS 部署层问题。
- Gateway 是否能完整工作，还取决于 OpenClaw 本体是否已经在 macOS 上可正常运行。
- 如果 Mac 上没有 `openclaw` 命令，部署脚本会跳过 `openclaw gateway restart`，但仍会继续安装并启动 Gateway Web 服务。

## 相关提交

- `f78922a831dd20f0564bc7dc816dd09d36c92a6e`：允许 installer 在 macOS 运行
- `1acaf6331fee753ba4df9ef2b6699eccb29c2f66`：支持 macOS launchd 部署
- `f31c215e776c9eff73faed8416a90c56a2d09287`：支持 macOS update 流程
- `9f3006dd99230e6e81d24f57e18a01db9f41247c`：更新 README 文档
- `97ef5ef9143c8fb1e83d26f25b682f95b921b349`：支持 macOS uninstall 流程
