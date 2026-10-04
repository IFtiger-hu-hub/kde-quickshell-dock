#!/usr/bin/env bash
# ==============================================================================
# dock-switch.sh: KDE Plasma macOS 风格 Dock 双方案一键切换管理工具
# 方案 1: Quickshell 极致物理质感 macOS Dock (推荐，全特效+波浪放大+多屏独立)
# 方案 2: KDE Plasma 6 原生浮动 Dock 面板 (极简轻量，0额外进程，~40MB开销)
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SHELL_QML="$REPO_DIR/shell.qml"
AUTOSTART_DIR="$HOME/.config/autostart"
AUTOSTART_FILE="$AUTOSTART_DIR/quickshell-dock.desktop"

# Color helpers
GREEN="\033[1;32m"
BLUE="\033[1;34m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
RED="\033[1;31m"
BOLD="\033[1m"
RESET="\033[0m"

is_qs_running() {
    # Scoped to this config: other Quickshell shells don't count as "the dock".
    qs list -p "$SHELL_QML" 2>/dev/null | grep -q "Process ID"
}

dock_pid() {
    qs list -p "$SHELL_QML" 2>/dev/null | awk '/Process ID/{print $3; exit}'
}

stop_dock() {
    qs kill -p "$SHELL_QML" >/dev/null 2>&1 || true
}

has_native_bottom_panel() {
    local check_js='
    var panels = panelIds;
    var found = false;
    for (var i = 0; i < panels.length; ++i) {
        var p = panelById(panels[i]);
        if (p.location === "bottom") {
            found = true;
            break;
        }
    }
    print(found ? "YES" : "NO");
    '
    local res
    res=$(qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$check_js" 2>/dev/null || echo "NO")
    [[ "$res" =~ "YES" ]]
}

show_status() {
    echo -e "${BOLD}======================================================${RESET}"
    echo -e "${BOLD}       KDE Plasma macOS Dock 方案运行状态检查        ${RESET}"
    echo -e "${BOLD}======================================================${RESET}"

    local qs_active=false
    local native_active=false

    if is_qs_running; then
        local pid
        pid=$(dock_pid)
        local mem
        mem=$(ps -p "$pid" -o rss= 2>/dev/null || echo "0")
        local mem_mb=$((mem / 1024))
        echo -e " [●] ${GREEN}方案 1 (Quickshell 极致 macOS Dock):${RESET} ${GREEN}正在运行${RESET} (PID: $pid, 物理内存: ~${mem_mb}MB)"
        qs_active=true
    else
        echo -e " [ ] ${YELLOW}方案 1 (Quickshell 极致 macOS Dock):${RESET} 未运行"
    fi

    if has_native_bottom_panel; then
        echo -e " [●] ${CYAN}方案 2 (KDE 原生浮动 Dock 面板):${RESET} ${CYAN}已激活并在屏幕底边展示${RESET}"
        native_active=true
    else
        echo -e " [ ] ${YELLOW}方案 2 (KDE 原生浮动 Dock 面板):${RESET} 未激活"
    fi

    echo -e "------------------------------------------------------"
    if [ -f "$AUTOSTART_FILE" ]; then
        echo -e " 开机自启状态: ${GREEN}已配置 Quickshell Dock 开机自启${RESET}"
    else
        echo -e " 开机自启状态: ${YELLOW}未配置独立 Quickshell 自启 (若用原生方案，Plasma 会自动保留面板)${RESET}"
    fi
    echo -e "${BOLD}======================================================${RESET}"
}

use_quickshell() {
    echo -e "${BLUE}>>> 正在切换至【方案 1：Quickshell 极致 macOS Dock】...${RESET}"
    
    # 1. 禁用 KDE 原生底边面板（避免两者重叠）
    if has_native_bottom_panel; then
        echo -e " -> 正在关闭 KDE 原生底部面板..."
        qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
            "$(cat "$SCRIPT_DIR/native-dock-disable.js")" >/dev/null 2>&1 || true
    fi

    # 2. 启动 / 重启 Quickshell 守护进程
    echo -e " -> 正在启动 Quickshell macOS Dock 进程..."
    stop_dock
    sleep 0.4
    qs -d -p "$SHELL_QML"
    sleep 0.8

    if is_qs_running; then
        echo -e "${GREEN}✓ 方案 1 (Quickshell) 已成功激活并运行！${RESET}"
        echo -e "  - 支持连续抛物线波浪鱼眼放大、跳跃触感、KWin神灯特效与多屏独立配置。"
    else
        echo -e "${RED}✗ 启动失败，请检查终端日志或运行 qs -p $SHELL_QML 排查。${RESET}"
        exit 1
    fi
}

use_native() {
    echo -e "${CYAN}>>> 正在切换至【方案 2：KDE 原生浮动 macOS Dock】...${RESET}"

    # 1. 停止 Quickshell
    if is_qs_running; then
        echo -e " -> 正在停止 Quickshell 守护进程..."
        stop_dock
        sleep 0.3
    fi

    # 2. 调用 Plasma 脚本创建底部浮动面板
    echo -e " -> 正在通过 Plasma 脚本创建原生居中浮动 Dock 面板..."
    local res
    res=$(qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
        "$(cat "$SCRIPT_DIR/native-dock-enable.js")" 2>&1)
    
    echo "$res"

    if has_native_bottom_panel; then
        echo -e "${GREEN}✓ 方案 2 (KDE 原生面板) 已成功激活！${RESET}"
        echo -e "  - 特性：0 额外独立守护进程，极低内存增量（~40MB），窗口自动避让。"
    else
        echo -e "${RED}✗ 创建原生面板失败，请检查 Plasma 状态。${RESET}"
        exit 1
    fi
}

set_autostart() {
    local mode="$1"
    mkdir -p "$AUTOSTART_DIR"

    case "$mode" in
        "quickshell"|"1")
            cat << EOF_DESKTOP > "$AUTOSTART_FILE"
[Desktop Entry]
Type=Application
Name=Quickshell macOS Dock
Comment=Authentic macOS Dock for KDE Plasma Wayland
Exec=qs -d -p $SHELL_QML
Icon=preferences-desktop-display
Terminal=false
StartupNotify=false
Categories=Utility;
X-KDE-autostart-phase=2
EOF_DESKTOP
            chmod +x "$AUTOSTART_FILE"
            echo -e "${GREEN}✓ 已开启【方案 1：Quickshell Dock】开机自启动！${RESET}"
            ;;
        "native"|"2"|"disable"|"none")
            rm -f "$AUTOSTART_FILE"
            echo -e "${YELLOW}✓ 已移除 Quickshell 自启项。${RESET}"
            echo -e "  (注: KDE 原生面板由 plasmashell 自身原生记忆保存，每次开机会自动恢复，无需 desktop 文件)"
            ;;
        *)
            echo "用法: $0 autostart [quickshell|native|disable]"
            exit 1
            ;;
    esac
}

case "$1" in
    "status")
        show_status
        ;;
    "quickshell"|"qs"|"1")
        use_quickshell
        ;;
    "native"|"kde"|"2")
        use_native
        ;;
    "autostart")
        set_autostart "$2"
        ;;
    *)
        echo -e "${BOLD}KDE Plasma macOS 风格 Dock 双方案管理工具${RESET}"
        echo -e "用法:"
        echo -e "  ${GREEN}$0 1${RESET} 或 ${GREEN}$0 quickshell${RESET}   : 切换至【方案 1：Quickshell 极致 macOS Dock】"
        echo -e "  ${CYAN}$0 2${RESET} 或 ${CYAN}$0 native${RESET}       : 切换至【方案 2：KDE 原生浮动 macOS Dock】"
        echo -e "  $0 status              : 查看当前哪套方案正在生效"
        echo -e "  $0 autostart quickshell: 设置方案 1 开机自动启动"
        echo -e "  $0 autostart native    : 取消方案 1 自启，默认使用原生方案"
        echo ""
        show_status
        ;;
esac
