# macOS Apple Silicon M1 使用指南

适用机器：

- macOS Apple Silicon / M1 / arm64
- 当前用户普通权限运行
- OpenClaw 原生 gateway 监听 `127.0.0.1:18789`
- OpenClaw Chat Gateway 面板监听 `127.0.0.1:3115`

## 一键安装/修复

进入项目目录：

```bash
cd ~/Desktop/OpenClaw-Chat-Gateway/OpenClaw-Chat-Gateway
```

拉取最新代码：

```bash
git pull origin main
```

执行 M1 专用脚本：

```bash
chmod +x scripts/macos-m1-setup.sh
./scripts/macos-m1-setup.sh
```

如果要指定面板端口，例如 8080：

```bash
./scripts/macos-m1-setup.sh 8080
```

## 脚本会做什么

1. 检查 macOS / Apple Silicon 环境。
2. 检查 `git`、`node`、`npm`、`openclaw`、`launchctl`、`lsof`。
3. 安装项目依赖。
4. 构建 backend 和 frontend。
5. 尝试修补 `~/.openclaw/openclaw.json`，让本地控制 UI 可以连接。
6. 创建原生 OpenClaw gateway 后台服务：

```text
~/Library/LaunchAgents/cc.openclaw.gateway.18789.plist
```

7. 创建 OpenClaw Chat Gateway 面板后台服务：

```text
~/Library/LaunchAgents/cc.angeworld.clawui.3115.plist
```

8. 启动两个后台服务。
9. 检查端口监听状态。

## 访问地址

OpenClaw Chat Gateway 面板：

```text
http://localhost:3115
```

原生 OpenClaw gateway：

```text
ws://127.0.0.1:18789
```

## 查看状态

原生 OpenClaw gateway：

```bash
launchctl print gui/$(id -u)/cc.openclaw.gateway.18789
```

OpenClaw Chat Gateway：

```bash
launchctl print gui/$(id -u)/cc.angeworld.clawui.3115
```

检查端口：

```bash
lsof -nP -iTCP:18789 -sTCP:LISTEN
lsof -nP -iTCP:3115 -sTCP:LISTEN
```

## 查看日志

原生 OpenClaw gateway：

```bash
tail -f ~/Library/Logs/OpenClaw-Chat-Gateway/openclaw-gateway.err.log
```

OpenClaw Chat Gateway：

```bash
tail -f ~/Library/Logs/OpenClaw-Chat-Gateway/clawui-3115.err.log
```

## 停止服务

```bash
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/cc.openclaw.gateway.18789.plist
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/cc.angeworld.clawui.3115.plist
```

## 重新启动服务

```bash
launchctl kickstart -k gui/$(id -u)/cc.openclaw.gateway.18789
launchctl kickstart -k gui/$(id -u)/cc.angeworld.clawui.3115
```

## Token 连接说明

如果面板提示 token 不匹配，先执行：

```bash
openclaw dashboard
```

使用它输出的 dashboard URL 或 token。

也可以读取本机配置：

```bash
node -e "const fs=require('fs');const p=process.env.HOME+'/.openclaw/openclaw.json';const c=JSON.parse(fs.readFileSync(p,'utf8'));const port=c.gateway?.port||18789;console.log('WebSocket URL: ws://127.0.0.1:'+port);console.log('Token:', c.gateway?.auth?.token || c.gateway?.token || '');console.log('Password:', c.gateway?.auth?.password || c.gateway?.password || '');"
```

## 不建议启用的功能

macOS 下暂不建议启用：

- 主机接管助手
- Host takeover
- 最大权限 root 接管

这些功能原设计偏 Linux/systemd 主机，macOS 上容易触发 sudo/root/helper/sudoers 不兼容。普通智能体工作区、文件读写、聊天、多智能体配置不需要它。
