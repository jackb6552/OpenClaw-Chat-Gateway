#!/bin/bash
set -e

# Configuration
# If not in a project dir, default to ~/OpenClaw-Chat-Gateway
INSTALL_DIR="$HOME/OpenClaw-Chat-Gateway"
OS_NAME="$(uname -s 2>/dev/null || echo unknown)"

emit_phase() {
    echo "::clawui-update-phase::$1"
}

require_supported_host() {
    case "$OS_NAME" in
        Linux)
            if ! command -v systemctl >/dev/null 2>&1; then
                echo "Error: systemctl was not found. Please update on a Linux host with user-level systemd."
                exit 1
            fi
            ;;
        Darwin)
            if ! command -v launchctl >/dev/null 2>&1; then
                echo "Error: launchctl was not found. Please update from a normal macOS user session."
                exit 1
            fi
            ;;
        *)
            echo "Error: current OS is $OS_NAME."
            echo "OpenClaw Chat Gateway update currently supports Linux(systemd) and macOS(launchd)."
            exit 1
            ;;
    esac
}

detect_existing_port() {
    local existing_port=""
    if [ "$OS_NAME" = "Linux" ]; then
        local service_dir="$HOME/.config/systemd/user"
        local services first_service
        services=$(ls $service_dir/clawui-*.service 2>/dev/null | sort -V || true)
        if [ -n "$services" ]; then
            first_service=$(echo "$services" | head -n 1)
            existing_port=$(basename "$first_service" | sed 's/clawui-\([0-9]*\)\.service/\1/')
        elif [ -f "$service_dir/clawui.service" ]; then
            existing_port="3115"
        fi
    elif [ "$OS_NAME" = "Darwin" ]; then
        local launch_agent_dir="$HOME/Library/LaunchAgents"
        local plists first_plist
        plists=$(ls $launch_agent_dir/cc.angeworld.clawui.*.plist 2>/dev/null | sort -V || true)
        if [ -n "$plists" ]; then
            first_plist=$(echo "$plists" | head -n 1)
            existing_port=$(basename "$first_plist" | sed 's/cc\.angeworld\.clawui\.\([0-9]*\)\.plist/\1/')
        fi
    fi
    echo "$existing_port"
}

require_supported_host

if [ -f "deploy-release.sh" ]; then
    PROJECT_ROOT="$(pwd)"
elif [ -d "$INSTALL_DIR" ]; then
    PROJECT_ROOT="$INSTALL_DIR"
else
    echo "Error: Could not find OpenClaw Chat Gateway installation."
    echo "Checked: $(pwd) and $INSTALL_DIR"
    exit 1
fi

echo "================================================"
echo "   OpenClaw Chat Gateway - 更新脚本"
echo "================================================"

emit_phase "detect-service"
EXISTING_PORT="$(detect_existing_port)"
if [ -n "$EXISTING_PORT" ]; then
    echo "检测到正在运行的端口: $EXISTING_PORT"
fi
TARGET_PORT=${1:-$EXISTING_PORT}
TARGET_PORT=${TARGET_PORT:-3115}

emit_phase "git-pull"
echo "正在从 GitHub 强制同步代码，目录: $PROJECT_ROOT..."
cd "$PROJECT_ROOT"
git fetch origin main --tags
git reset --hard origin/main
git clean -fd

emit_phase "deploy-release"
echo "开始升级端口 $TARGET_PORT 的服务..."
./deploy-release.sh "$TARGET_PORT"

emit_phase "complete"
echo "================================================"
echo "升级完成！"
echo "您的配置和数据已保留。"
echo "================================================"
