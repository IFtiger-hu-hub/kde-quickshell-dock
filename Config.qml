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
        backgroundColor: "#20242c",
        backgroundOpacity: 0.58,
        border: "#30ffffff",
        borderWidth: 1,
        glassHighlight: true,
        shadowEnabled: true,
        showTrash: true,
        indicatorColor: "#b8ffffff",
        indicatorActiveColor: "#ffffff"
    })

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

    readonly property color hoverHighlight: "#1effffff"
    readonly property color dragHighlight: "#2affffff"
    readonly property color indicatorBackground: "#40000000"
    property color indicatorColor: defaults.indicatorColor
    property color indicatorActiveColor: defaults.indicatorActiveColor

    readonly property color newInstanceBackground: "#f5343b49"
    readonly property color newInstanceHoverBackground: "#ff4b5570"
    readonly property color newInstanceForeground: "#ffffff"
    readonly property color tooltipBackground: "#e01c1f26"
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
            indicatorColor: "#b8ffffff",
            indicatorActiveColor: "#ffffff",
            backgroundColor: "#20242c",
            backgroundOpacity: 0.58,
            border: "#30ffffff",
            borderWidth: 1,
            glassHighlight: true,
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
            try {
                const parsed = JSON.parse(this.text());
                if (parsed && typeof parsed === "object") {
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
            root.ready = true;
        }

        onLoadFailed: root.ready = true
    }
}