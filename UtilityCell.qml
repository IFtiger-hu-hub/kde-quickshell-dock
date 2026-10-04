import QtQuick
import QtQuick.Shapes

// A fixed dock cell drawn as a circular glass plate with a vector glyph on top
// -- the Trash and Settings buttons. It joins the parabolic wave like an app
// icon does, but carries no running state, drag or window list.
Item {
    id: root

    required property var dock
    // Item the wave's pointer coordinate is measured in (the dock's content row).
    required property Item waveSpace

    // Up to two SVG path strings, drawn on a 24x24 grid.
    property var glyphPaths: []
    // Highlighted plate (e.g. the settings panel is open).
    property bool active: false
    // Degrees to turn the glyph by on hover / while active; 0 disables it.
    property real hoverRotation: 0
    property real activeRotation: 0

    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed

    signal clicked(int button)

    width: dock.cellSize
    height: dock.cellSize

    // ---- wave participation (same curve as the app cells) ----
    readonly property real cellCenterPos: dock.isVertical ? (y + height / 2) : (x + width / 2)
    readonly property real waveDistance: Math.abs(dock.pointerPos - cellCenterPos)
    readonly property real waveInfluence: dock.cellSize * dock.waveSpread
    readonly property real waveFactor: (dock.pointerInside && waveDistance < waveInfluence && dock.hoverMagnify)
        ? 0.5 * (1 + Math.cos(Math.PI * waveDistance / waveInfluence))
        : 0
    readonly property real targetScale: 1.0 + waveFactor * (dock.hoverScale - 1.0)
    readonly property real waveLiftY: dock.isBottom ? -Math.round(waveFactor * 7) : 0
    readonly property real waveLiftX: dock.isRight ? -Math.round(waveFactor * 7) : 0

    z: Math.round(targetScale * 100)

    Item {
        id: plateWrapper
        width: root.dock.iconSize
        height: root.dock.iconSize
        x: Math.round((parent.width - width) / 2 + root.waveLiftX)
        y: Math.round((parent.height - height) / 2 + root.waveLiftY)

        scale: root.targetScale
        transformOrigin: root.dock.isBottom ? Item.Bottom
                       : root.dock.isTop ? Item.Top
                       : root.dock.isLeft ? Item.Left
                       : Item.Right

        Behavior on scale {
            enabled: !root.dock.pointerInside
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
        Behavior on y {
            enabled: !root.dock.pointerInside
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        // Soft drop shadow under the plate
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "#25000000"
            y: 1.5
            z: -1
            visible: root.dock.shadowEnabled
        }

        // Circular base plate (McMojave / macOS style)
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: root.active ? "#2563eb"
                         : root.pressed ? "#20252e"
                         : root.hovered ? "#475162" : "#374151"
                }
                GradientStop {
                    position: 1.0
                    color: root.active ? "#1d4ed8"
                         : root.pressed ? "#13171e"
                         : root.hovered ? "#28303d" : "#1f2937"
                }
            }
            border.width: 1
            border.color: root.active ? "#60a5fa" : "#30ffffff"
            Behavior on border.color { ColorAnimation { duration: 120 } }

            // Glyph, drawn on a 24x24 grid and scaled to ~54% of the plate
            Item {
                anchors.centerIn: parent
                width: 24
                height: 24
                transformOrigin: Item.Center
                scale: (parent.width * 0.54 / 24) * (root.pressed ? 0.92 : (root.hovered && root.hoverRotation === 0 ? 1.06 : 1.0))
                rotation: root.active ? root.activeRotation : (root.hovered ? root.hoverRotation : 0)

                Behavior on rotation { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: root.active ? "#ffffff" : "#f1f5f9"
                        strokeWidth: 0
                        PathSvg { path: root.glyphPaths.length > 0 ? root.glyphPaths[0] : "" }
                    }
                    ShapePath {
                        fillColor: root.active ? "#ffffff" : "#f1f5f9"
                        strokeWidth: 0
                        PathSvg { path: root.glyphPaths.length > 1 ? root.glyphPaths[1] : "" }
                    }
                }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onPositionChanged: m => {
            const mapped = root.mapToItem(root.waveSpace, m.x, m.y);
            root.dock.updatePointer(root.dock.isVertical ? mapped.y : mapped.x);
        }
        onEntered: {
            const mapped = root.mapToItem(root.waveSpace, root.width / 2, root.height / 2);
            root.dock.updatePointer(root.dock.isVertical ? mapped.y : mapped.x);
        }
        onExited: root.dock.schedulePointerLeave()
        onClicked: m => root.clicked(m.button)
    }
}
