pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // ---- Multi-Screen Independent Configuration ----
    property bool perScreenConfig: false
    property var screensConfig: ({})
    property int revision: 0

    function getVal(screenName, key) {
        root.revision;
        if (root.perScreenConfig && screenName && root.screensConfig && root.screensConfig[screenName]) {
            const sc = root.screensConfig[screenName];
            if (sc && sc.hasOwnProperty(key)) {
                return sc[key];
            }
        }
        return root[key];
    }

    function setScreenVal(screenName, key, val) {
        if (!screenName || !root.perScreenConfig) {
            setVal(key, val);
            return;
        }
        const copy = JSON.parse(JSON.stringify(root.screensConfig || {}));
        if (!copy[screenName]) {
            copy[screenName] = {};
            for (const k in defaults) {
                copy[screenName][k] = root[k];
            }
        }
        copy[screenName][key] = val;
        root.screensConfig = copy;
        root.revision++;
        saveTimer.restart();
    }

    function setPerScreenConfig(enabled) {
        if (enabled && !root.perScreenConfig) {
            enablePerScreenConfig();
        } else {
            root.perScreenConfig = enabled;
            root.revision++;
            saveTimer.restart();
        }
    }

    function enablePerScreenConfig() {
        const copy = JSON.parse(JSON.stringify(root.screensConfig || {}));
        const screens = Quickshell.screens || [];
        for (let i = 0; i < screens.length; i++) {
            const name = screens[i].name;
            if (!copy[name]) {
                const sc = {};
                for (const k in defaults) {
                    sc[k] = root[k];
                }
                copy[name] = sc;
            }
        }
        root.screensConfig = copy;
        root.perScreenConfig = true;
        root.revision++;
        saveTimer.restart();
    }

    function copyGlobalToScreen(screenName) {
        if (!screenName) return;
        const copy = JSON.parse(JSON.stringify(root.screensConfig || {}));
        const sc = {};
        for (const k in defaults) {
            sc[k] = root[k];
        }
        copy[screenName] = sc;
        root.screensConfig = copy;
        root.revision++;
        saveTimer.restart();
    }

    function resetScreenConfig(screenName) {
        if (!screenName) return;
        const copy = JSON.parse(JSON.stringify(root.screensConfig || {}));
        delete copy[screenName];
        root.screensConfig = copy;
        root.revision++;
        saveTimer.restart();
    }

    // ---- Persistence ----
    readonly property string statePath: Quickshell.statePath("dock-config.json")
    property bool ready: false

    // Default configuration values - Tuned for Authentic macOS Dock Aesthetics
    readonly property var defaults: ({
        enabled: true,
        iconSize: 44,
        cellPadding: 4,
        spacing: 6,
        dockPadding: 7,
        bottomMargin: 6,
        position: "bottom",
        screenMode: "all",
        targetScreen: "",
        radius: 20,
        edgeCorners: false,
        cornerSize: 10,
        peekFilletShare: 0.25,
        source: "kickoff",
        autoHide: false,
        peekHeight: 16,
        peekOpacity: 0.4,
        triggerHeight: 8,
        hideDelay: 250,
        revealGrace: 300,
        slideDuration: 140,
        reserveSpace: false,
        hoverMagnify: true,
        hoverScale: 1.45,
        waveSpread: 2.2,
        bounceOnLaunch: true,
        raiseRunning: true,
        minimizeActive: true,
        showRunningApps: true,
        runningIndicator: true,
        indicatorDotSize: 4,
        indicatorActiveDotSize: 5,
        indicatorSpacing: 3,
        indicatorMaxDots: 1,
        indicatorInsetX: 0,
        indicatorInsetY: 2,
        indicatorPadding: 2,
        newInstanceButton: false,
        newInstanceSize: 18,
        newInstanceGap: 4,
        newInstanceStroke: 2,
        backgroundColor: "#f6f6f6",
        backgroundOpacity: 0.45,
        border: "#55ffffff",
        borderWidth: 1,
        glassHighlight: false,
        shadowEnabled: true,
        showTrash: true,
        circularIcons: true,
        indicatorColor: "#80000000",
        indicatorActiveColor: "#cc000000",
        styleVersion: 2
    })

    // Appearance values for the light / dark presets (neutral greys, macOS-like).
    function presetValues(light) {
        return light ? {
            backgroundColor: "#f6f6f6",
            backgroundOpacity: 0.45,
            border: "#55ffffff",
            borderWidth: 1,
            glassHighlight: false,
            shadowEnabled: true,
            indicatorColor: "#80000000",
            indicatorActiveColor: "#cc000000"
        } : {
            backgroundColor: "#1e1e1e",
            backgroundOpacity: 0.55,
            border: "#26ffffff",
            borderWidth: 1,
            glassHighlight: false,
            shadowEnabled: true,
            indicatorColor: "#99ffffff",
            indicatorActiveColor: "#e6ffffff"
        };
    }

    function isLightColor(c) {
        const q = Qt.color(c);
        return (0.299 * q.r + 0.587 * q.g + 0.114 * q.b) > 0.5;
    }

    // One-time move of saved configs from the old slate/blue look (styleVersion < 2)
    // to the neutral presets, keeping each screen's light/dark choice.
    property int styleVersion: defaults.styleVersion
    function migrateStyle() {
        const g = presetValues(isLightColor(root.backgroundColor));
        for (const k in g) root[k] = g[k];
        const copy = JSON.parse(JSON.stringify(root.screensConfig || {}));
        for (const name in copy) {
            const sc = copy[name];
            if (!sc) continue;
            const p = presetValues(isLightColor(sc.backgroundColor || root.backgroundColor));
            for (const k in p) sc[k] = p[k];
        }
        root.screensConfig = copy;
        root.styleVersion = 2;
        root.revision++;
        persist();
    }

    // ---- Screen Enabled & Geometry ----
    property bool enabled: defaults.enabled
    property int iconSize: defaults.iconSize
    property int cellPadding: defaults.cellPadding
    property int spacing: defaults.spacing
    property int dockPadding: defaults.dockPadding
    property int bottomMargin: defaults.bottomMargin
    property string position: defaults.position
    property string screenMode: defaults.screenMode
    property string targetScreen: defaults.targetScreen
    property int radius: defaults.radius

    readonly property int cellSize: iconSize + cellPadding * 2

    // ---- Edge corners ----
    property bool edgeCorners: defaults.edgeCorners
    property int cornerSize: defaults.cornerSize
    property real peekFilletShare: defaults.peekFilletShare

    // ---- Source ----
    property string source: defaults.source

    // ---- Auto-hide ----
    property bool autoHide: defaults.autoHide
    property int peekHeight: defaults.peekHeight
    property real peekOpacity: defaults.peekOpacity
    property int triggerHeight: defaults.triggerHeight
    property int hideDelay: defaults.hideDelay
    property int revealGrace: defaults.revealGrace
    property int slideDuration: defaults.slideDuration

    // ---- Behaviour & Magnification ----
    property bool reserveSpace: defaults.reserveSpace
    property bool hoverMagnify: defaults.hoverMagnify
    property real hoverScale: defaults.hoverScale
    property real waveSpread: defaults.waveSpread
    property bool bounceOnLaunch: defaults.bounceOnLaunch

    // ---- Running apps ----
    property bool raiseRunning: defaults.raiseRunning
    property bool minimizeActive: defaults.minimizeActive
    property bool showRunningApps: defaults.showRunningApps
    property bool runningIndicator: defaults.runningIndicator
    property int indicatorDotSize: defaults.indicatorDotSize
    property int indicatorActiveDotSize: defaults.indicatorActiveDotSize
    property int indicatorSpacing: defaults.indicatorSpacing
    property int indicatorMaxDots: defaults.indicatorMaxDots
    property int indicatorInsetX: defaults.indicatorInsetX
    property int indicatorInsetY: defaults.indicatorInsetY
    property int indicatorPadding: defaults.indicatorPadding

    // ---- New instance button ----
    property bool newInstanceButton: defaults.newInstanceButton
    property int newInstanceSize: defaults.newInstanceSize
    property int newInstanceGap: defaults.newInstanceGap
    property int newInstanceStroke: defaults.newInstanceStroke
    readonly property string newInstanceLabel: "新建窗口"

    // ---- Appearance ----
    property color backgroundColor: defaults.backgroundColor
    property real backgroundOpacity: defaults.backgroundOpacity

    readonly property color background: Qt.rgba(
        backgroundColor.r, backgroundColor.g, backgroundColor.b, backgroundOpacity)

    property color border: defaults.border
    property real borderWidth: defaults.borderWidth
    property bool glassHighlight: defaults.glassHighlight
    property bool shadowEnabled: defaults.shadowEnabled
    property bool showTrash: defaults.showTrash
    property bool circularIcons: defaults.circularIcons

    readonly property color hoverHighlight: "#1effffff"
    readonly property color dragHighlight: "#2affffff"
    readonly property color indicatorBackground: "#40000000"
    property color indicatorColor: defaults.indicatorColor
    property color indicatorActiveColor: defaults.indicatorActiveColor

    readonly property color newInstanceBackground: "#e6303030"
    readonly property color newInstanceHoverBackground: "#ff4a4a4a"
    readonly property color newInstanceForeground: "#ffffff"
    readonly property color tooltipBackground: "#e0262626"
    readonly property color tooltipText: "#ffffff"

    // Setter function to update property and trigger debounced persist
    function setVal(key, val) {
        if (root[key] === val) return;
        root[key] = val;
        saveTimer.restart();
    }

    function resetDefaults(screenName) {
        if (root.perScreenConfig && screenName) {
            resetScreenConfig(screenName);
        } else {
            for (const k in defaults) {
                root[k] = defaults[k];
            }
            saveTimer.restart();
        }
    }

    // Light preset
    function applyLightPreset(screenName) {
        const p = presetValues(true);
        if (root.perScreenConfig && screenName) {
            for (const k in p) setScreenVal(screenName, k, p[k]);
        } else {
            for (const k in p) setVal(k, p[k]);
        }
        saveTimer.restart();
    }

    // Dark preset
    function applyDarkPreset(screenName) {
        const p = presetValues(false);
        if (root.perScreenConfig && screenName) {
            for (const k in p) setScreenVal(screenName, k, p[k]);
        } else {
            for (const k in p) setVal(k, p[k]);
        }
        saveTimer.restart();
    }

    // Force apply the authentic macOS Dock preset
    function applyMacosPreset(screenName) {
        const p = {
            position: "bottom",
            iconSize: 44,
            cellPadding: 4,
            spacing: 6,
            dockPadding: 7,
            bottomMargin: 6,
            radius: 20,
            edgeCorners: false,
            autoHide: false,
            hoverMagnify: true,
            hoverScale: 1.45,
            waveSpread: 2.2,
            bounceOnLaunch: true,
            runningIndicator: true,
            indicatorDotSize: 4,
            indicatorActiveDotSize: 5,
            indicatorColor: "#99ffffff",
            indicatorActiveColor: "#e6ffffff",
            backgroundColor: "#1e1e1e",
            backgroundOpacity: 0.55,
            border: "#26ffffff",
            borderWidth: 1,
            glassHighlight: false,
            shadowEnabled: true,
            showRunningApps: true,
            raiseRunning: true,
            minimizeActive: true,
            newInstanceButton: false,
            showTrash: true,
            enabled: true
        };
        if (root.perScreenConfig && screenName) {
            for (const k in p) {
                setScreenVal(screenName, k, p[k]);
            }
        } else {
            for (const k in p) {
                setVal(k, p[k]);
            }
        }
        persist();
    }

    Timer {
        id: saveTimer
        interval: 150
        onTriggered: root.persist()
    }

    function persist() {
        const obj = {};
        for (const k in defaults) {
            if (k === "backgroundColor" || k === "border" || k === "indicatorColor" || k === "indicatorActiveColor") {
                obj[k] = root[k].toString();
            } else {
                obj[k] = root[k];
            }
        }
        obj["perScreenConfig"] = root.perScreenConfig;
        obj["screensConfig"] = root.screensConfig;
        configFile.setText(JSON.stringify(obj, null, 2));
    }

    Process {
        running: true
        command: ["mkdir", "-p", Quickshell.statePath("")]
        onExited: configFile.reload()
    }

    FileView {
        id: configFile
        path: root.statePath
        atomicWrites: true
        printErrors: false

        onLoaded: {
            let needsMigration = false;
            try {
                const parsed = JSON.parse(this.text());
                if (parsed && typeof parsed === "object") {
                    needsMigration = !(parsed.styleVersion >= 2);
                    for (const k in parsed) {
                        if (root.defaults.hasOwnProperty(k)) {
                            root[k] = parsed[k];
                        }
                    }
                    if (parsed.hasOwnProperty("perScreenConfig")) {
                        root.perScreenConfig = parsed.perScreenConfig;
                    }
                    if (parsed.hasOwnProperty("screensConfig") && typeof parsed.screensConfig === "object") {
                        root.screensConfig = parsed.screensConfig;
                    }
                }
            } catch (e) {
                console.warn("dock: failed to load config:", e);
            }
            if (needsMigration) root.migrateStyle();
            root.ready = true;
        }

        onLoadFailed: root.ready = true
    }
}