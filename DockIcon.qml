import Quickshell
import QtQuick
import QtQuick.Effects

// The visual for one dock cell: macOS style parabolic wave icon, centered bottom
// running indicator dot, launch bounce animation, tactile press feedback, and drag-and-drop.
Item {
    id: root

    property var dockRef: null
    readonly property var d: dockRef ? dockRef : (typeof dock !== "undefined" ? dock : null)

    readonly property int iconSize: d ? d.iconSize : Config.iconSize
    readonly property string dockPosition: d ? d.dockPosition : root.dockPosition
    readonly property int radius: d ? d.radius : Config.radius
    readonly property bool hoverMagnify: d ? d.hoverMagnify : Config.hoverMagnify
    readonly property real hoverScale: d ? d.hoverScale : root.hoverScale
    readonly property bool bounceOnLaunch: d ? d.bounceOnLaunch : Config.bounceOnLaunch
    readonly property bool runningIndicator: d ? d.runningIndicator : root.runningIndicator
    readonly property int indicatorDotSize: d ? d.indicatorDotSize : root.indicatorDotSize
    readonly property int indicatorActiveDotSize: d ? d.indicatorActiveDotSize : root.indicatorActiveDotSize
    readonly property color indicatorColor: d ? d.indicatorColor : root.indicatorColor
    readonly property color indicatorActiveColor: d ? d.indicatorActiveColor : root.indicatorActiveColor
    readonly property bool circularIcons: d ? d.circularIcons : Config.circularIcons
    readonly property string iconShape: d ? d.iconShape : (Config.iconShape ?? (circularIcons ? "circle" : "original"))
    readonly property bool isLight: d ? d.isLight : true

    required property var entry
    property bool hovered: false
    property bool pressed: false
    property bool dragging: false
    property bool isExpanded: false

    // How many windows this app has open, and whether one of them has focus.
    property int windows: 0
    property bool active: false
    readonly property bool running: windows > 0

    // True while launching an app until its window appears
    property bool launching: false
    property int bounceCount: 0
    readonly property int maxBounces: 4

    onWindowsChanged: {
        if (windows > 0) {
            root.launching = false;
        }
    }

    onLaunchingChanged: {
        if (!launching) {
            launchTimeoutTimer.stop();
            if (!launchBounce.running && root.bounceOffset !== 0) {
                bounceResetAnim.restart();
            }
        }
    }

    Timer {
        id: launchTimeoutTimer
        interval: 3500
        repeat: false
        onTriggered: {
            root.launching = false;
        }
    }

    // Directional bounce offsets supporting all 4 dock edges (bottom, top, left, right)
    property real bounceOffset: 0
    readonly property real bounceOffsetX: root.dockPosition === "left" ? root.bounceOffset
                                        : root.dockPosition === "right" ? -root.bounceOffset
                                        : 0
    readonly property real bounceOffsetY: root.dockPosition === "top" ? root.bounceOffset
                                        : (root.dockPosition === "bottom" || !root.dockPosition) ? -root.bounceOffset
                                        : 0
    readonly property real bounceY: root.bounceOffsetY

    // Wave scale & lift passed down from dock wave engine
    property real currentScale: 1.0
    property real liftX: 0
    property real liftY: 0

    // Sources to try in order; advance past any that fail to load.
    readonly property var sources: IconResolver.candidates(entry)
    property int attempt: 0
    readonly property string iconSource: attempt < sources.length ? sources[attempt] : ""

    onSourcesChanged: attempt = 0

    function launch() {
        if (!root.running) {
            if (!root.entry) return;
            if (root.launching) return;
            root.bounceCount = 0;
            root.launching = true;
            launchTimeoutTimer.restart();
            if (root.bounceOnLaunch) {
                launchBounce.restart();
            }
        } else {
            raiseNudge.restart();
        }
    }

    // Smooth reset animation guaranteeing the icon never freezes in mid-air
    NumberAnimation {
        id: bounceResetAnim
        target: root
        property: "bounceOffset"
        to: 0
        duration: 140
        easing.type: Easing.OutQuad
    }

    // Continuous rhythm bouncing while app is booting up (macOS authentic behavior)
    // Runs single complete bounce arcs, strictly bounded to maxBounces to prevent infinite loops
    SequentialAnimation {
        id: launchBounce
        running: false
        loops: 1

        NumberAnimation {
            target: root
            property: "bounceOffset"
            from: 0; to: 15
            duration: 160
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: root
            property: "bounceOffset"
            from: 15; to: 0
            duration: 180
            easing.type: Easing.InQuad
        }
        NumberAnimation {
            target: root
            property: "bounceOffset"
            from: 0; to: 6
            duration: 110
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: root
            property: "bounceOffset"
            from: 6; to: 0
            duration: 130
            easing.type: Easing.OutBounce
        }

        onFinished: {
            if (root.launching && (root.bounceCount + 1 < root.maxBounces)) {
                root.bounceCount++;
                launchBounce.restart();
            } else {
                root.launching = false;
                root.bounceCount = 0;
                root.bounceOffset = 0;
            }
        }

        onStopped: {
            if (root.bounceOffset !== 0) {
                bounceResetAnim.restart();
            }
        }
    }

    // Gentle raise nudge when switching to an already-running app
    SequentialAnimation {
        id: raiseNudge
        running: false
        loops: 1

        NumberAnimation {
            target: root
            property: "bounceOffset"
            from: 0; to: 7
            duration: 90
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: root
            property: "bounceOffset"
            from: 7; to: 0
            duration: 120
            easing.type: Easing.OutQuad
        }

        onFinished: {
            root.bounceOffset = 0;
        }

        onStopped: {
            if (root.bounceOffset !== 0) {
                bounceResetAnim.restart();
            }
        }
    }


    // Drag placeholder highlight
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.dragging ? Config.dragHighlight
             : (root.hovered && !root.hoverMagnify) ? Config.hoverHighlight
             : "transparent"

        Behavior on color {
            ColorAnimation { duration: 120 }
        }
    }

    // Icon Container with Parabolic Wave Magnification & Bottom Anchoring
    Item {
        id: iconWrapper

        width: root.iconSize
        height: root.iconSize

        // Press depression haptic scale (0.90 on press)
        scale: root.currentScale * (root.pressed ? 0.90 : 1.0)
        transformOrigin: root.dockPosition === "top" ? Item.Top
                       : root.dockPosition === "left" ? Item.Left
                       : root.dockPosition === "right" ? Item.Right
                       : Item.Bottom

        y: (parent.height - height) / 2 + root.liftY + root.bounceOffsetY
        x: (parent.width - width) / 2 + root.liftX + root.bounceOffsetX

        Behavior on scale {
            enabled: (d ? !d.pointerInside : true) && !root.dragging
            NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
        }

        Behavior on y {
            enabled: (d ? !d.pointerInside : true) && !launchBounce.running && !raiseNudge.running && !bounceResetAnim.running && !root.dragging
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        Behavior on x {
            enabled: (d ? !d.pointerInside : true) && !launchBounce.running && !raiseNudge.running && !bounceResetAnim.running && !root.dragging
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        // Expanded state: faint neutral disc behind the icon (scales with it)
        Rectangle {
            id: expandedAura
            anchors.centerIn: parent
            width: parent.width + 8
            height: parent.height + 8
            radius: width / 2
            visible: root.isExpanded
            z: -1
            color: root.isLight ? Qt.rgba(0, 0, 0, root.hovered ? 0.10 : 0.07)
                                : Qt.rgba(1, 1, 1, root.hovered ? 0.16 : 0.11)
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        CircleIcon {
            id: icon
            anchors.fill: parent

            circular: root.circularIcons
            iconShape: root.iconShape
            isLight: root.isLight
            source: root.iconSource

            // Render at high resolution so wave magnification remains razor sharp
            renderSize: Math.round(root.iconSize * Math.max(1.5, root.hoverScale) * 1.5)

            onStatusChanged: {
                if (status === Image.Error && root.attempt < root.sources.length - 1) {
                    root.attempt++;
                }
            }
        }
    }

    // Soft drop shadow only instantiated while the icon is actively being dragged
    Loader {
        active: root.dragging
        anchors.fill: iconWrapper
        sourceComponent: MultiEffect {
            source: iconWrapper
            shadowEnabled: true
            shadowBlur: 0.7
            shadowColor: "#bb000000"
            shadowVerticalOffset: 4
        }
    }

    readonly property bool isVertical: root.dockPosition === "left" || root.dockPosition === "right"

    // ---- Modern Linux / Plasma 6 Multi-Window Running Indicator ----
    Item {
        id: indicatorContainer

        readonly property bool hasMultiWindows: !root.isExpanded && root.windows > 1
        readonly property int dotThickness: root.isExpanded ? 3 : (root.active ? root.indicatorActiveDotSize : root.indicatorDotSize)
        readonly property int targetWidth: root.isVertical ? dotThickness : (root.isExpanded ? 16 : (hasMultiWindows ? (root.indicatorDotSize * 2 + 3) : dotThickness))
        readonly property int targetHeight: root.isVertical ? (root.isExpanded ? 16 : (hasMultiWindows ? (root.indicatorDotSize * 2 + 3) : dotThickness)) : dotThickness

        width: targetWidth
        height: targetHeight

        // Center along transverse axis
        anchors.horizontalCenter: (!root.isVertical) ? parent.horizontalCenter : undefined
        anchors.verticalCenter: root.isVertical ? parent.verticalCenter : undefined

        // Position in the plate padding margin outside the icon
        x: root.dockPosition === "left"
            ? Math.round((parent.width - root.iconSize) / 2 - targetWidth - 2)
            : root.dockPosition === "right"
            ? Math.round(parent.width - (parent.width - root.iconSize) / 2 + 2)
            : 0

        y: root.dockPosition === "top"
            ? Math.round((parent.height - root.iconSize) / 2 - targetHeight - 2)
            : root.dockPosition === "bottom"
            ? Math.round(parent.height - (parent.height - root.iconSize) / 2 + 2)
            : 0

        visible: opacity > 0
        opacity: root.runningIndicator && (root.running || root.launching) && !root.dragging ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 160 }
        }
        Behavior on width {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }

        readonly property color activeAccent: Theme.accent
        readonly property color normalColor: root.indicatorColor
        readonly property color currentIndicatorColor: (root.isExpanded || root.active || root.launching)
            ? activeAccent
            : normalColor

        // Subtle ambient glow for active or expanded app
        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 4
            height: parent.height + 4
            radius: Math.min(width, height) / 2
            color: Theme.accent
            opacity: (root.active || root.isExpanded) ? 0.35 : 0
            visible: opacity > 0
            z: -1
            Behavior on opacity { NumberAnimation { duration: 180 } }
        }

        // Layout: Single Dot / Expanded Capsule
        Rectangle {
            id: dot
            anchors.fill: parent
            visible: !indicatorContainer.hasMultiWindows
            radius: Math.min(width, height) / 2

            color: indicatorContainer.currentIndicatorColor
            Behavior on color { ColorAnimation { duration: 140 } }

            SequentialAnimation {
                id: dotPulseAnim
                running: root.launching
                loops: Animation.Infinite
                NumberAnimation { target: dot; property: "opacity"; from: 0.25; to: 1.0; duration: 380; easing.type: Easing.InOutQuad }
                NumberAnimation { target: dot; property: "opacity"; from: 1.0; to: 0.25; duration: 380; easing.type: Easing.InOutQuad }
                onStopped: dot.opacity = 1.0
            }
        }

        // Layout: Multi-Window Distinct Dual Indicator Dots
        Grid {
            id: multiDotsGrid
            anchors.centerIn: parent
            visible: indicatorContainer.hasMultiWindows
            columns: root.isVertical ? 1 : 2
            rows: root.isVertical ? 2 : 1
            spacing: 3

            Rectangle {
                width: root.active ? root.indicatorActiveDotSize : root.indicatorDotSize
                height: width
                radius: width / 2
                color: root.active ? Theme.accent : root.indicatorColor
                Behavior on color { ColorAnimation { duration: 140 } }
            }

            Rectangle {
                width: root.indicatorDotSize
                height: width
                radius: width / 2
                color: root.active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.65) : root.indicatorColor
                Behavior on color { ColorAnimation { duration: 140 } }
            }
        }
    }
}