pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Shared visual tokens. The accent follows the KDE colour scheme
// (kdeglobals: [General] AccentColor, else [Colors:Selection] BackgroundNormal)
// and updates live when the user changes it in System Settings.
// Neutrals are plain greys modelled on macOS system colours.
Singleton {
    id: root

    property color accent: "#0a84ff"

    function pick(isLight, light, dark) { return isLight ? light : dark; }

    // Text
    function textPrimary(isLight)   { return isLight ? Qt.rgba(0, 0, 0, 0.85) : Qt.rgba(1, 1, 1, 0.88); }
    function textSecondary(isLight) { return isLight ? Qt.rgba(0, 0, 0, 0.50) : Qt.rgba(1, 1, 1, 0.55); }
    function textTertiary(isLight)  { return isLight ? Qt.rgba(0, 0, 0, 0.30) : Qt.rgba(1, 1, 1, 0.30); }

    // Surfaces (popover / menu / panel)
    function surface(isLight)       { return isLight ? Qt.rgba(0.96, 0.96, 0.96, 0.86) : Qt.rgba(0.16, 0.16, 0.17, 0.86); }
    function surfaceBorder(isLight) { return isLight ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(1, 1, 1, 0.10); }
    function groupFill(isLight)     { return isLight ? Qt.rgba(0, 0, 0, 0.035) : Qt.rgba(1, 1, 1, 0.05); }
    function separator(isLight)     { return isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.08); }
    function hoverFill(isLight)     { return isLight ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(1, 1, 1, 0.08); }
    function pressFill(isLight)     { return isLight ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.12); }
    function controlFill(isLight)   { return isLight ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(1, 1, 1, 0.10); }
    function trackFill(isLight)     { return isLight ? Qt.rgba(0, 0, 0, 0.14) : Qt.rgba(1, 1, 1, 0.18); }
    function shadow(isLight)        { return isLight ? Qt.rgba(0, 0, 0, 0.18) : Qt.rgba(0, 0, 0, 0.45); }

    // Destructive actions
    readonly property color destructive: "#ff453a"

    function parseColor(v) {
        if (!v) return null;
        const s = v.trim();
        if (s.startsWith("#")) return s;
        const p = s.split(",").map(x => parseInt(x));
        if (p.length < 3 || p.some(x => isNaN(x))) return null;
        return Qt.rgba(p[0] / 255, p[1] / 255, p[2] / 255, 1);
    }

    FileView {
        id: kdeglobals
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/kdeglobals"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const g = Ini.parse(text());
            const c = root.parseColor(g["[General]"] && g["[General]"]["AccentColor"])
                   ?? root.parseColor(g["[Colors:Selection]"] && g["[Colors:Selection]"]["BackgroundNormal"]);
            if (c) root.accent = c;
        }
    }
}
