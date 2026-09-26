pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // ---- Persistence ----
    readonly property string statePath: Quickshell.statePath("dock-config.json")
    property bool ready: false

    // Default configuration values
    readonly property var defaults: ({
        iconSize: 35,
        cellPadding: 2,
        spacing: 2,
        dockPadding: 4,
        bottomMargin: 0,
        position: "bottom",
        screenMode: "all",
        targetScreen: "",
        radius: 15,
        edgeCorners: true,
        cornerSize: 10,
        peekFilletShare: 0.25,
        source: "kickoff",
        autoHide: true,
        peekHeight: 16,
        peekOpacity: 0.4,
        triggerHeight: 8,
        hideDelay: 250,
        revealGrace: 300,
        slideDuration: 100,
        reserveSpace: false,
        hoverMagnify: true,
        hoverScale: 1.22,
        raiseRunning: true,
        minimizeActive: true,
        showRunningApps: true,
        runningIndicator: true,
        indicatorDotSize: 4,
        indicatorSpacing: 3,
        indicatorMaxDots: 3,
        indicatorInsetX: 2,
        indicatorInsetY: 0,
        indicatorPadding: 3,
        newInstanceButton: true,
        newInstanceSize: 20,
        newInstanceGap: 5,
        newInstanceStroke: 2,
        backgroundColor: "#1c1f26",
        backgroundOpacity: 0.8,
        border: "#33ffffff",
        borderWidth: 1,
        indicatorColor: "#ffa8e6a0",
        indicatorActiveColor: "#ff52e05c"
    })

    // ---- Geometry ----
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

    // ---- Behaviour ----
    property bool reserveSpace: defaults.reserveSpace
    property bool hoverMagnify: defaults.hoverMagnify
    property real hoverScale: defaults.hoverScale

    // ---- Running apps ----
    property bool raiseRunning: defaults.raiseRunning
    property bool minimizeActive: defaults.minimizeActive
    property bool showRunningApps: defaults.showRunningApps
    property bool runningIndicator: defaults.runningIndicator
    property int indicatorDotSize: defaults.indicatorDotSize
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
    readonly property string newInstanceLabel: "New window"

    // ---- Appearance ----
    property color backgroundColor: defaults.backgroundColor
    property real backgroundOpacity: defaults.backgroundOpacity

    readonly property color background: Qt.rgba(
        backgroundColor.r, backgroundColor.g, backgroundColor.b, backgroundOpacity)

    property color border: defaults.border
    property real borderWidth: defaults.borderWidth
    readonly property color hoverHighlight: "#22ffffff"
    readonly property color dragHighlight: "#33ffffff"
    readonly property color indicatorBackground: "#b3000000"
    property color indicatorColor: defaults.indicatorColor
    property color indicatorActiveColor: defaults.indicatorActiveColor

    readonly property color newInstanceBackground: "#f5343b49"
    readonly property color newInstanceHoverBackground: "#ff4b5570"
    readonly property color newInstanceForeground: "#ffffff"
    readonly property color tooltipBackground: "#f01c1f26"
    readonly property color tooltipText: "#ffffff"

    // Setter function to update property and trigger debounced persist
    function setVal(key, val) {
        if (root[key] === val) return;
        root[key] = val;
        saveTimer.restart();
    }

    function resetDefaults() {
        for (const k in defaults) {
            root[k] = defaults[k];
        }
        saveTimer.restart();
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
                }
            } catch (e) {
                console.warn("dock: failed to load config:", e);
            }
            root.ready = true;
        }

        onLoadFailed: root.ready = true
    }
}
