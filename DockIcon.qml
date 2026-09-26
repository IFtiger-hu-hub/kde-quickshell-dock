import Quickshell
import QtQuick
import QtQuick.Effects

// The visual for one dock cell: highlight plate, application icon, and the
// running badge in its top-left corner.
Item {
    id: root

    required property var entry
    property bool hovered: false
    property bool dragging: false

    // How many windows this app has open, and whether one of them has focus.
    property int windows: 0
    property bool active: false

    readonly property bool running: windows > 0

    // Sources to try in order; advance past any that fail to load.
    readonly property var sources: IconResolver.candidates(entry)
    property int attempt: 0
    readonly property string iconSource: attempt < sources.length ? sources[attempt] : ""

    onSourcesChanged: attempt = 0

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: root.dragging ? Config.dragHighlight
             : root.hovered  ? Config.hoverHighlight
             : "transparent"

        Behavior on color {
            ColorAnimation { duration: 120 }
        }
    }

    Image {
        id: icon

        anchors.centerIn: parent
        width: Config.iconSize
        height: Config.iconSize

        // Render at the magnified size so scaling up stays crisp.
        sourceSize.width: Math.round(Config.iconSize * Config.hoverScale)
        sourceSize.height: Math.round(Config.iconSize * Config.hoverScale)

        asynchronous: true
        fillMode: Image.PreserveAspectFit
        source: root.iconSource

        onStatusChanged: {
            if (status === Image.Error && root.attempt < root.sources.length - 1) root.attempt++;
        }

        scale: Config.hoverMagnify && root.hovered && !root.dragging ? Config.hoverScale : 1.0

        Behavior on scale {
            NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
        }
    }

    // Soft drop shadow only instantiated while the icon is actively being carried
    Loader {
        active: root.dragging
        anchors.fill: icon
        sourceComponent: MultiEffect {
            source: icon
            shadowEnabled: true
            shadowBlur: 0.7
            shadowColor: "#aa000000"
            shadowVerticalOffset: 3
        }
    }

    // One dot per open window, capped so a browser with a dozen windows can't
    // run the badge across the whole icon. The accent colour marks the app that
    // currently has focus.
    //
    // Drawn over the icon's top-left corner rather than in a strip of its own,
    // so running apps don't make the dock any taller. Declared last so it stays
    // above the artwork.
    Rectangle {
        id: indicator

        x: Config.cellPadding + Config.indicatorInsetX
        y: Config.cellPadding + Config.indicatorInsetY
        width: dots.width + Config.indicatorPadding * 2
        height: dots.height + Config.indicatorPadding * 2
        radius: height / 2

        color: Config.indicatorBackground

        visible: opacity > 0
        opacity: Config.runningIndicator && root.running && !root.dragging ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 140 }
        }

        Row {
            id: dots

            anchors.centerIn: parent
            spacing: Config.indicatorSpacing

            Repeater {
                model: Math.min(root.windows, Config.indicatorMaxDots)

                Rectangle {
                    width: Config.indicatorDotSize
                    height: Config.indicatorDotSize
                    radius: height / 2
                    color: root.active ? Config.indicatorActiveColor : Config.indicatorColor

                    Behavior on color {
                        ColorAnimation { duration: 160 }
                    }
                }
            }
        }
    }
}
