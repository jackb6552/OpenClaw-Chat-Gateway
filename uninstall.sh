#!/bin/bash
set -e

# Configuration
INSTALL_DIR="$HOME/OpenClaw-Chat-Gateway"
OS_NAME="$(uname -s 2>/dev/null || echo unknown)"

# Terminal Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SERVICE_DIR="$HOME/.config/systemd/user"
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
DB_PATH="$HOME/.clawui/clawui.sqlite"
WORKSPACE_BASE="$HOME/.openclaw"
HAS_SYSTEMCTL=0
HAS_LAUNCHCTL=0

if command -v systemctl &>/dev/null; then
    HAS_SYSTEMCTL=1
fi
if command -v launchctl &>/dev/null; then
    HAS_LAUNCHCTL=1
fi

SERVICES=""
[ -d "$SERVICE_DIR" ] && SERVICES=$(ls $SERVICE_DIR/clawui-*.service 2>/dev/null || true)
if [ -f "$SERVICE_DIR/clawui.service" ]; then
    SERVICES="$SERVICES $SERVICE_DIR/clawui.service"
fi

LAUNCH_AGENTS=""
[ -d "$LAUNCH_AGENT_DIR" ] && LAUNCH_AGENTS=$(ls $LAUNCH_AGENT_DIR/cc.angeworld.clawui.*.plist 2>/dev/null || true)

DETECTED_DIRS=""
for S_PATH in $SERVICES; do
    W_DIR=$(grep "^WorkingDirectory=" "$S_PATH" | cut -d'=' -f2 | sed 's/ /\\ /g')
    P_DIR=$(dirname "$W_DIR")
    if [ -d "$P_DIR" ]; then
        DETECTED_DIRS="$DETECTED_DIRS $P_DIR"
    fi
done

for P_PATH in $LAUNCH_AGENTS; do
    W_DIR=$(grep -A1 "<key>WorkingDirectory</key>" "$P_PATH" | tail -n 1 | sed 's/.*<string>\(.*\)<\/string>.*/\1/' | sed 's/&amp;/\&/g; s/&lt;/</g; s/&gt;/>/g; s/&quot;/"/g; s/&apos;/'"'"'/g')
    P_DIR=$(dirname "$W_DIR")
    if [ -d "$P_DIR" ]; then
        DETECTED_DIRS="$DETECTED_DIRS $P_DIR"
    fi
done

if [ -f "./uninstall.sh" ]; then
    DETECTED_DIRS="$DETECTED_DIRS $(pwd)"
fi

CLEAN_DIRS=$(echo "$DETECTED_DIRS $INSTALL_DIR" | tr ' ' '\n' | sort -u | grep -v "^$" || true)

TARGET_WORKSPACES=""

if [ -f "$DB_PATH" ] && command -v sqlite3 &>/dev/null; then
    AGENT_IDS=$(sqlite3 "$DB_PATH" "SELECT DISTINCT agentId FROM characters;" 2>/dev/null || true)
    for id in $AGENT_IDS; do
        if [ "$id" == "main" ]; then
            TARGET_WORKSPACES="$TARGET_WORKSPACES $WORKSPACE_BASE/workspace-main"
        else
            TARGET_WORKSPACES="$TARGET_WORKSPACES $WORKSPACE_BASE/workspace-$id"
        fi
    done
fi

OPENCLAW_CONFIG="$WORKSPACE_BASE/openclaw.json"
if [ -f "$OPENCLAW_CONFIG" ]; then
    if command -v jq &>/dev/null; then
        JSON_WS=$(jq -r '.agents.list[].workspace' "$OPENCLAW_CONFIG" 2>/dev/null || true)
        TARGET_WORKSPACES="$TARGET_WORKSPACES $JSON_WS"
    else
        JSON_WS=$(grep '"workspace":' "$OPENCLAW_CONFIG" | sed 's/.*"workspace": "\(.*\)".*/\1/' || true)
        TARGET_WORKSPACES="$TARGET_WORKSPACES $JSON_WS"
    fi
fi

if [ -d "$WORKSPACE_BASE" ]; then
    H_WS=$(find "$WORKSPACE_BASE" -maxdepth 2 -type f -name "SOUL.md" | xargs -I {} dirname {} | grep "/workspace-" || true)
    TARGET_WORKSPACES="$TARGET_WORKSPACES $H_WS"
fi

[ -d "$WORKSPACE_BASE/workspace-main" ] && TARGET_WORKSPACES="$TARGET_WORKSPACES $WORKSPACE_BASE/workspace-main"

CLEAN_WS=""
for ws in $TARGET_WORKSPACES; do
    if [ -d "$ws" ]; then
        CLEAN_WS="$CLEAN_WS $ws"
    fi
done
TARGET_WORKSPACES=$(echo "$CLEAN_WS" | tr ' ' '\n' | sort -u | grep -v "^$" || true)

echo -e "${RED}警告: 这将停止所有相关服务并删除以下内容:${NC}"
for s in $SERVICES; do
    echo -e " - $s (systemd 服务文件)"
done
for p in $LAUNCH_AGENTS; do
    echo -e " - $p (macOS launchd 服务文件)"
done
for d in $CLEAN_DIRS; do
    echo -e " - $d (项目文件)"
done
for ws in $TARGET_WORKSPACES; do
    echo -e " - $ws (工作区)"
done
echo -e " - $HOME/.clawui (本项目专用数据库及运行时数据)"
[ -d "$HOME/.clawui_release" ] && echo -e " - ~/.clawui_release (旧版数据)"
echo ""

read -p "您确定要卸载并删除本项目相关的数据吗? (y/N) " confirm < /dev/tty

if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "卸载已取消。"
    exit 0
fi

echo -e "\n${BLUE}步骤 1: 正在停止并移除系统服务...${NC}"
if [ "$HAS_SYSTEMCTL" = "1" ]; then
    for S_PATH in $SERVICES; do
        S_FILE=$(basename "$S_PATH")
        echo "正在停止 systemd 服务: $S_FILE"
        systemctl --user stop "$S_FILE" 2>/dev/null || true
        systemctl --user disable "$S_FILE" 2>/dev/null || true
        rm -f "$S_PATH"
    done
    systemctl --user daemon-reload 2>/dev/null || true
fi

if [ "$HAS_LAUNCHCTL" = "1" ]; then
    for P_PATH in $LAUNCH_AGENTS; do
        LABEL=$(basename "$P_PATH" .plist)
        echo "正在停止 launchd 服务: $LABEL"
        launchctl bootout "gui/$(id -u)" "$P_PATH" 2>/dev/null || true
        rm -f "$P_PATH"
    done
fi

if [ "$HAS_SYSTEMCTL" != "1" ] && [ "$HAS_LAUNCHCTL" != "1" ]; then
    echo "未检测到 systemctl 或 launchctl，跳过系统服务停止步骤。"
fi

echo -e "\n${BLUE}步骤 2: 正在清理本项目相关的数据和设置...${NC}"
for ws in $TARGET_WORKSPACES; do
    if [ -d "$ws" ]; then
        rm -rf "$ws"
        echo "已删除工作区: $ws"
    fi
done

rm -rf "$HOME/.clawui"
rm -rf "$HOME/.clawui_release"
[ -d "$HOME/.clawui_dev" ] && rm -rf "$HOME/.clawui_dev"
[ -d "$HOME/Library/Logs/OpenClaw-Chat-Gateway" ] && rm -rf "$HOME/Library/Logs/OpenClaw-Chat-Gateway"
echo "已清理本项目相关的配置和数据库数据。"

echo -e "\n${BLUE}步骤 3: 正在移除项目文件...${NC}"
for d in $CLEAN_DIRS; do
    if [ -d "$d" ]; then
        rm -rf "$d"
        echo "已删除项目目录: $d"
    fi
done

echo -e "\n${GREEN}================================================${NC}"
echo -e "${GREEN}   卸载完成！                                   ${NC}"
echo -e "${GREEN}================================================${NC}"
