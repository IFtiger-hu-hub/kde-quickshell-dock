#!/usr/bin/env bash
# ==============================================================================
# install.sh — install / uninstall / check kde-quickshell-dock for this user.
#
#   ./scripts/install.sh               install (permission file + autostart) and start the dock
#   ./scripts/install.sh --no-autostart   install without the autostart entry
#   ./scripts/install.sh uninstall      stop the dock and remove what install added
#   ./scripts/install.sh check          only report missing dependencies
#
# Nothing is written outside $HOME. The dock runs straight from this checkout, so
# `git pull` is all an update needs (Quickshell hot-reloads on change).
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SHELL_QML="$REPO_DIR/shell.qml"

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
PERMISSION_FILE="$DATA_HOME/applications/org.quickshell.dock.desktop"
# Same name dock-switch.sh manages, so the two tools never create duplicates.
AUTOSTART_FILE="$CONFIG_HOME/autostart/quickshell-dock.desktop"

GREEN="\033[1;32m"; YELLOW="\033[1;33m"; RED="\033[1;31m"; BOLD="\033[1m"; RESET="\033[0m"
ok()   { echo -e " ${GREEN}✓${RESET} $*"; }
warn() { echo -e " ${YELLOW}!${RESET} $*"; }
fail() { echo -e " ${RED}✗${RESET} $*"; }

# ---- dependency check --------------------------------------------------------
# Returns non-zero only when a hard requirement is missing.
check_deps() {
    local hard_missing=0
    echo -e "${BOLD}Checking dependencies${RESET}"

    if command -v qs >/dev/null 2>&1 || command -v quickshell >/dev/null 2>&1; then
        ok "Quickshell: $(qs --version 2>/dev/null | head -n1 || echo found)"
    else
        fail "Quickshell (qs / quickshell) not found — required"
        hard_missing=1
    fi

    local qml_found=""
    for dir in /usr/lib64/qt6/qml /usr/lib/qt6/qml /usr/lib/x86_64-linux-gnu/qt6/qml /usr/lib/aarch64-linux-gnu/qt6/qml; do
        [ -f "$dir/org/kde/taskmanager/qmldir" ] && qml_found="$dir" && break
    done
    if [ -n "$qml_found" ]; then
        ok "org.kde.taskmanager QML module (plasma-workspace)"
    else
        warn "org.kde.taskmanager QML module not found — running-app features will be off"
    fi

    if command -v ktrash6 >/dev/null 2>&1; then
        ok "ktrash6 (empty trash via KIO)"
    elif command -v gio >/dev/null 2>&1; then
        warn "ktrash6 not found, will fall back to gio for emptying the trash"
    else
        warn "neither ktrash6 nor gio found — \"empty trash\" will fail"
    fi

    command -v kioclient >/dev/null 2>&1 && ok "kioclient (open trash, item count)" \
        || warn "kioclient not found — opening the trash from the dock will fail"

    if command -v sqlite3 >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1; then
        ok "sqlite3 / python3 (read Kickoff favourites)"
    else
        warn "neither sqlite3 nor python3 — favourites fall back to the stale appletsrc list"
    fi

    command -v python3 >/dev/null 2>&1 && ok "python3 (recent files menu)" \
        || warn "python3 not found — recent files menu will be empty"

    command -v gdbus >/dev/null 2>&1 && ok "gdbus (live favourite updates, pin/unpin)" \
        || warn "gdbus not found — favourites won't update live and pin/unpin won't work"

    command -v kbuildsycoca6 >/dev/null 2>&1 || warn "kbuildsycoca6 not found — you may need to log out once for KWin to pick up the permission file"

    return $hard_missing
}

# KWin matches the Wayland client by its real executable, so resolve qs -> quickshell.
quickshell_binary() {
    local bin
    bin="$(command -v quickshell 2>/dev/null || command -v qs)"
    readlink -f "$bin"
}

qs_bin() { command -v qs 2>/dev/null || command -v quickshell; }

stop_dock() {
    # Only this config's instance: other Quickshell shells keep running.
    "$(qs_bin)" kill -p "$SHELL_QML" >/dev/null 2>&1 || true
}

start_dock() {
    stop_dock
    sleep 0.3
    "$(qs_bin)" -d -p "$SHELL_QML" >/dev/null 2>&1
}

do_install() {
    local with_autostart=1
    [ "${1:-}" = "--no-autostart" ] && with_autostart=0

    check_deps || { fail "Install aborted: a required dependency is missing."; exit 1; }
    echo
    echo -e "${BOLD}Installing${RESET}"

    # 1. KWin permission for org_kde_plasma_window_management
    mkdir -p "$(dirname "$PERMISSION_FILE")"
    sed "s|^Exec=.*|Exec=$(quickshell_binary)|" "$REPO_DIR/org.quickshell.dock.desktop" > "$PERMISSION_FILE"
    ok "Window-management permission → $PERMISSION_FILE"
    if command -v kbuildsycoca6 >/dev/null 2>&1; then
        kbuildsycoca6 >/dev/null 2>&1 || true
        ok "Refreshed the application index (kbuildsycoca6)"
    fi

    # 2. Autostart
    if [ $with_autostart -eq 1 ]; then
        mkdir -p "$(dirname "$AUTOSTART_FILE")"
        cat > "$AUTOSTART_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=Quickshell Dock
Comment=macOS-style dock for KDE Plasma
Exec=$(qs_bin) -d -p $SHELL_QML
Icon=preferences-system-windows
Terminal=false
StartupNotify=false
X-KDE-autostart-phase=2
EOF
        ok "Autostart → $AUTOSTART_FILE"
    else
        warn "Skipped autostart (--no-autostart)"
    fi

    # 3. (Re)start so the new permission takes effect
    start_dock
    if "$(qs_bin)" list -p "$SHELL_QML" 2>/dev/null | grep -q "Process ID"; then
        ok "Dock is running"
    else
        warn "Dock did not report as running; try: qs -p $SHELL_QML"
    fi

    echo
    echo "If the running-app dots don't appear, log out and back in once:"
    echo "KWin only reads the permission file for clients started after it exists."
}

do_uninstall() {
    echo -e "${BOLD}Uninstalling${RESET}"
    stop_dock
    ok "Stopped the dock"

    if [ -f "$PERMISSION_FILE" ]; then
        rm -f "$PERMISSION_FILE"
        ok "Removed $PERMISSION_FILE"
        command -v kbuildsycoca6 >/dev/null 2>&1 && kbuildsycoca6 >/dev/null 2>&1 || true
    fi
    if [ -f "$AUTOSTART_FILE" ]; then
        rm -f "$AUTOSTART_FILE"
        ok "Removed $AUTOSTART_FILE"
    fi

    echo
    echo "Your dock settings and icon order are kept in Quickshell's state directory"
    echo "(dock-config.json / dock-order.json). Delete them by hand for a clean slate."
}

case "${1:-install}" in
    install|--no-autostart) do_install "${1:-}" ;;
    uninstall|remove)       do_uninstall ;;
    check|doctor)           check_deps ;;
    -h|--help|help)         sed -n '3,11p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' ;;
    *) echo "Unknown command: $1 (try --help)"; exit 1 ;;
esac
