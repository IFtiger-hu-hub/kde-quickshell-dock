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

    onWindowsChanged: {
        if (windows > 0) {
            root.launching = false;
        }
    }

    Timer {
        id: launchTimeoutTimer
        interval: 6000
        repeat: false
        onTriggered: root.launching = false
    }

    // Wave scale & lift passed down from dock wave engine
    property real currentScale: 1.0
    property real liftX: 0
    property real liftY: 0
    property real bounceY: 0

    // Sources to try in order; advance past any that fail to load.
    readonly property var sources: IconResolver.candidates(entry)
    property int attempt: 0
    readonly property string iconSource: attempt < sources.length ? sources[attempt] : ""

    onSourcesChanged: attempt = 0

    function launch() {
        rippleAnim.restart();
        if (!root.running) {
            root.launching = true;
            launchTimeoutTimer.restart();
            if (root.bounceOnLaunch) {
                launchBounce.restart();
            }
        } else {
            raiseNudge.restart();
        }
    }

    // Continuous rhythm bouncing while app is booting up (macOS behavior)
    SequentialAnimation {
        id: launchBounce
        running: false
        loops: root.launching ? Animation.Infinite : 1

        NumberAnimation {
            target: root
            property: "bounceY"
            from: 0; to: -15
            duration: 160
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: root
            property: "bounceY"
            from: -15; to: 0
            duration: 180
            easing.type: Easing.InQuad
        }
        NumberAnimation {
            target: root
            property: "bounceY"
            from: 0; to: -7
            duration: 110
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: root
            property: "bounceY"
            from: -7; to: 0
            duration: 130
            easing.type: Easing.OutBounce
        }
    }

    // Gentle raise nudge when switching to an already-running app
    SequentialAnimation {
        id: raiseNudge
        running: false
        NumberAnimation {
            target: root
            property: "bounceY"
            from: 0; to: -7
            duration: 90
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: root
            property: "bounceY"
            from: -7; to: 0
            duration: 120
            easing.type: Easing.OutQuad
        }
    }

    // Click Ripple wave expanding from center
    Rectangle {
        id: clickRipple
        anchors.centerIn: parent
        width: root.iconSize
        height: width
        radius: width / 2
        color: "transparent"
        border.color: "#80ffffff"
        border.width: 1.5
        opacity: 0
        scale: 0.8
    }

    ParallelAnimation {
        id: rippleAnim
        NumberAnimation {
            target: clickRipple
            property: "scale"
            from: 0.8; to: 1.45
            duration: 250
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: clickRipple
            property: "opacity"
            from: 0.8; to: 0
            duration: 250
            easing.type: Easing.OutCubic
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

        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize

        // Press depression haptic scale (0.90 on press)
        scale: root.currentScale * (root.pressed ? 0.90 : 1.0)
        transformOrigin: root.dockPosition === "top" ? Item.Top
                       : root.dockPosition === "left" ? Item.Left
                       : root.dockPosition === "right" ? Item.Right
                       : Item.Bottom

        y: (parent.height - height) / 2 + root.liftY + root.bounceY
        x: (parent.width - width) / 2 + root.liftX

        Behavior on scale {
            enabled: !dock.pointerInside && !root.dragging
            NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
        }

        Behavior on y {
            enabled: !dock.pointerInside && !launchBounce.running && !raiseNudge.running && !root.dragging
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        Behavior on x {
            enabled: !dock.pointerInside && !root.dragging
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        // Expanded State: Soft subtle circular ambient aura (clean, no harsh boxy borders)
        Rectangle {
            id: expandedAura
            anchors.centerIn: parent
            width: parent.width + 8
            height: parent.height + 8
            radius: width / 2
            visible: root.isExpanded
            z: -1
            opacity: root.hovered ? 1.0 : 0.65

            color: (root.d && root.d.isLight) ? Qt.rgba(0.01, 0.52, 0.78, 0.14) : Qt.rgba(0.23, 0.51, 0.96, 0.22)
            border.color: (root.d && root.d.isLight) ? Qt.rgba(2, 132, 199, 0.45) : Qt.rgba(96, 165, 250, 0.55)
            border.width: 1.2

            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        Image {
            id: icon
            anchors.fill: parent

            // Render at high resolution so wave magnification remains razor sharp
            sourceSize.width: Math.round(root.iconSize * Math.max(1.5, root.hoverScale) * 1.5)
            sourceSize.height: Math.round(root.iconSize * Math.max(1.5, root.hoverScale) * 1.5)

            asynchronous: true
            mipmap: true
            smooth: true
            fillMode: Image.PreserveAspectFit
            source: root.iconSource

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

    // ---- macOS Authentic Centered Running Indicator Dot ----
    Item {
        id: indicatorContainer

        anchors.horizontalCenter: (root.dockPosition === "top" || root.dockPosition === "bottom") ? parent.horizontalCenter : undefined
        anchors.verticalCenter: (root.dockPosition === "left" || root.dockPosition === "right") ? parent.verticalCenter : undefined

        anchors.bottom: root.dockPosition === "bottom" ? parent.bottom : undefined
        anchors.top: root.dockPosition === "top" ? parent.top : undefined
        anchors.left: root.dockPosition === "left" ? parent.left : undefined
        anchors.right: root.dockPosition === "right" ? parent.right : undefined

        anchors.bottomMargin: root.dockPosition === "bottom" ? 2 : 0
        anchors.topMargin: root.dockPosition === "top" ? 2 : 0
        anchors.leftMargin: root.dockPosition === "left" ? 2 : 0
        anchors.rightMargin: root.dockPosition === "right" ? 2 : 0

        width: root.isExpanded ? 20 : 14
        height: 14

        visible: opacity > 0
        opacity: root.runningIndicator && (root.running || root.launching) && !root.dragging ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 160 }
        }
        Behavior on width {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }

        // Ambient glow behind active dot / capsule
        Rectangle {
            anchors.centerIn: parent
            width: dot.width + (root.isExpanded ? 6 : 4)
            height: dot.height + (root.isExpanded ? 6 : 4)
            radius: width / 2
            color: root.isExpanded
                ? (root.d && root.d.isLight ? Qt.rgba(2, 132, 199, 0.25) : Qt.rgba(96, 165, 250, 0.35))
                : (root.active ? "#40ffffff" : "transparent")
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        // Running Dot / Expanded Indicator Capsule
        Rectangle {
            id: dot
            anchors.centerIn: parent
            width: root.isExpanded ? 16 : (root.active ? root.indicatorActiveDotSize : root.indicatorDotSize)
            height: root.isExpanded ? 3.5 : (root.active ? root.indicatorActiveDotSize : root.indicatorDotSize)
            radius: root.isExpanded ? 2 : (width / 2)

            color: root.isExpanded
                ? (root.d && root.d.isLight ? "#0284c7" : "#60a5fa")
                : (root.launching ? "#ffffff"
                    : root.active ? root.indicatorActiveColor
                    : root.indicatorColor)

            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            Behavior on radius { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 140 } }

            SequentialAnimation on opacity {
                running: root.launching
                loops: Animation.Infinite
                NumberAnimation { from: 0.25; to: 1.0; duration: 380; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 1.0; to: 0.25; duration: 380; easing.type: Easing.InOutQuad }
            }
        }
    }
}