import QtQuick
import QtQuick.Shapes

// A fixed dock cell for the Trash and Settings buttons. It draws a regular
// icon-theme icon through CircleIcon, exactly like an app icon, so it sits in
// the row without a special look. It joins the parabolic wave like an app icon
// does, but carries no drag or window list. "active" shows the same running dot
// apps use (e.g. while the settings panel is open).
Item {
    id: root

    required property var dock
    // Item the wave's pointer coordinate is measured in (the dock's content row).
    required property Item waveSpace

    // Icon-theme names to try in order.
    property var iconNames: []
    // Up to two SVG path strings on a 24x24 grid, drawn only when the icon
    // theme has none of iconNames.
    property var glyphPaths: []
    property bool active: false

    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed

    signal clicked(int button)

    width: dock.cellSize
    height: dock.cellSize

    // ---- icon lookup with fallback ----
    readonly property var sources: {
        const out = [];
        for (const n of iconNames) {
            const p = IconResolver.themed(n);
            if (p && out.indexOf(p) < 0) out.push(p);
        }
        return out;
    }
    property int attempt: 0
    onSourcesChanged: attempt = 0
    readonly property string iconSource: attempt < sources.length ? sources[attempt] : ""

    // ---- wave participation (same curve as the app cells) ----
    readonly property real cellCenterPos: dock.isVertical ? (y + height / 2) : (x + width / 2)
    readonly property real waveDistance: Math.abs(dock.pointerPos - cellCenterPos)
    readonly property real waveInfluence: dock.cellSize * dock.waveSpread
    readonly property real waveFactor: (dock.pointerInside && waveDistance < waveInfluence && dock.hoverMagnify)
        ? 0.5 * (1 + Math.cos(Math.PI * waveDistance / waveInfluence))
        : 0
    readonly property real targetScale: 1.0 + waveFactor * (dock.hoverScale - 1.0)
    readonly property real waveLiftY: dock.isBottom ? -Math.round(waveFactor * 7) : dock.isTop ? Math.round(waveFactor * 7) : 0
    readonly property real waveLiftX: dock.isRight ? -Math.round(waveFactor * 7) : dock.isLeft ? Math.round(waveFactor * 7) : 0

    z: Math.round(targetScale * 100)

    Item {
        id: iconWrapper
        width: root.dock.iconSize
        height: root.dock.iconSize
        x: Math.round((parent.width - width) / 2 + root.waveLiftX)
        y: Math.round((parent.height - height) / 2 + root.waveLiftY)

        scale: root.targetScale * (root.pressed ? 0.90 : 1.0)
        transformOrigin: root.dock.isBottom ? Item.Bottom
                       : root.dock.isTop ? Item.Top
                       : root.dock.isLeft ? Item.Left
                       : Item.Right

        Behavior on scale {
            enabled: !root.dock.pointerInside
            NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
        }
        Behavior on y {
            enabled: !root.dock.pointerInside
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
        Behavior on x {
            enabled: !root.dock.pointerInside
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        CircleIcon {
            id: icon
            anchors.fill: parent
            // Without a themed icon, still give the glyph a plate to sit on.
            circular: root.dock.circularIcons || root.iconSource === ""
            iconShape: root.dock ? root.dock.iconShape : "circle"
            isLight: root.dock.isLight
            source: root.iconSource
            renderSize: Math.round(root.dock.iconSize * Math.max(1.5, root.dock.hoverScale) * 1.5)

            onStatusChanged: {
                if (status === Image.Error && root.attempt < root.sources.length) root.attempt++;
            }
        }

        // Fallback glyph, only when the icon theme had nothing.
        Shape {
            visible: root.iconSource === "" && root.glyphPaths.length > 0
            anchors.centerIn: parent
            width: 24
            height: 24
            scale: parent.width * 0.5 / 24
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: Theme.textSecondary(root.dock.isLight)
                strokeWidth: 0
                PathSvg { path: root.glyphPaths.length > 0 ? root.glyphPaths[0] : "" }
            }
            ShapePath {
                fillColor: Theme.textSecondary(root.dock.isLight)
                strokeWidth: 0
                PathSvg { path: root.glyphPaths.length > 1 ? root.glyphPaths[1] : "" }
            }
        }
    }

    // Same dot as a running app, shown while active.
    Rectangle {
        readonly property int size: root.dock.indicatorDotSize
        width: size
        height: size
        radius: size / 2
        color: root.dock.indicatorActiveColor
        visible: opacity > 0
        opacity: root.active && root.dock.runningIndicator ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160 } }

        x: root.dock.isLeft ? 2 : root.dock.isRight ? (parent.width - width - 2) : (parent.width - width) / 2
        y: root.dock.isBottom ? (parent.height - height - 2) : root.dock.isTop ? 2 : (parent.height - height) / 2
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
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
