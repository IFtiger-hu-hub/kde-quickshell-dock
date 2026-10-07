import QtQuick
import QtQuick.Effects

// An app icon that can be forced into a uniform circle.
//
// circular: true  -> the artwork is zoomed slightly (overscan) and clipped to a circle,
//                    sitting on a plate that follows the dock's light/dark preset, so
//                    transparent glyph icons get a round background and square icons lose
//                    their corners.
// circular: false -> the plain icon, exactly as the theme ships it.
Item {
    id: root

    property url source
    property bool circular: true
    property bool isLight: true
    property bool shadow: true
    property bool asynchronous: true

    readonly property real diameter: Math.min(width, height)

    // Zoom applied before clipping so already-round icons don't show a thin ring of
    // transparent margin inside the circle.
    property real overscan: 1.125

    // Pixel size the artwork is rasterised (and the clip layer rendered) at. Callers that
    // magnify the icon should pass a value large enough to stay sharp at the peak scale.
    property int renderSize: Math.round(diameter * 2)

    readonly property alias status: icon.status

    // Soft contact shadow under the disc
    Rectangle {
        width: root.diameter
        height: root.diameter
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 1.5
        radius: width / 2
        color: root.isLight ? "#22000000" : "#40000000"
        visible: root.circular && root.shadow
    }

    // Plate, visible through any transparent parts of the artwork.
    // Neutral grey with only a faint shading, so it reads as a surface, not a button.
    Rectangle {
        width: root.diameter
        height: root.diameter
        anchors.centerIn: parent
        radius: width / 2
        visible: root.circular
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.isLight ? "#fafafa" : "#3a3a3c" }
            GradientStop { position: 1.0; color: root.isLight ? "#ededed" : "#2c2c2e" }
        }
    }

    Rectangle {
        id: mask
        width: root.diameter
        height: root.diameter
        radius: width / 2
        visible: false
        layer.enabled: true
        layer.smooth: true
        layer.textureSize: Qt.size(root.renderSize, root.renderSize)
    }

    // Artwork. When circular the Image overflows this item by `overscan`; the layer only
    // captures the item's own bounds, and the mask then rounds it off.
    Item {
        id: art
        width: root.diameter
        height: root.diameter
        anchors.centerIn: parent

        layer.enabled: root.circular
        layer.smooth: true
        layer.textureSize: Qt.size(root.renderSize, root.renderSize)
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }

        Image {
            id: icon
            anchors.centerIn: parent
            width: root.circular ? parent.width * root.overscan : parent.width
            height: width

            readonly property int rasterSize: Math.round(root.renderSize * (root.circular ? root.overscan : 1))
            sourceSize: Qt.size(rasterSize, rasterSize)

            asynchronous: root.asynchronous
            mipmap: true
            smooth: true
            fillMode: Image.PreserveAspectFit
            source: root.source
        }
    }

    // Hairline rim so a white plate still reads as a disc on a light dock
    Rectangle {
        width: root.diameter
        height: root.diameter
        anchors.centerIn: parent
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: root.isLight ? "#1a000000" : "#26ffffff"
        visible: root.circular
    }
}
