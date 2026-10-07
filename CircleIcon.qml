import QtQuick
import QtQuick.Effects

// An app icon that can be formatted into a uniform circle or rounded square (squircle).
//
// iconShape: "circle"   -> artwork clipped to a circle, sitting on a light/dark plate.
// iconShape: "squircle" -> artwork clipped to a macOS/iOS style squircle (radius ~22.5%).
// iconShape: "original" -> the plain untampered icon from the system theme.
Item {
    id: root

    property url source
    property bool circular: true
    property string iconShape: "circle"
    property bool isLight: true
    property bool shadow: true
    property bool asynchronous: true

    readonly property real diameter: Math.min(width, height)

    readonly property bool isMasked: iconShape !== "original" && (circular || iconShape === "circle" || iconShape === "squircle")
    readonly property real cornerRadius: {
        if (!isMasked) return 0;
        if (iconShape === "circle") return diameter / 2;
        if (iconShape === "squircle") return Math.round(diameter * 0.225);
        return diameter / 2;
    }

    // Zoom applied before clipping so already-round icons don't show thin rings in circle mode (1.125).
    // In squircle mode, 0.86 provides an elegant, perfectly centered 6px margin on all 4 sides with contained drop shadow.
    property real overscan: iconShape === "circle" ? 1.125 : (iconShape === "squircle" ? 0.86 : 1.0)

    // Pixel size the artwork is rasterised (and the clip layer rendered) at.
    property int renderSize: Math.min(256, Math.max(32, Math.round(diameter) * 2))

    readonly property bool needsLayer: root.isMasked && root.diameter > 24

    readonly property alias status: icon.status

    // Soft contact shadow under the disc / plate
    Rectangle {
        width: root.diameter
        height: root.diameter
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.iconShape === "circle" ? 1.0 : 0.0
        radius: root.cornerRadius
        color: root.isLight ? "#1a000000" : "#35000000"
        visible: root.isMasked && root.shadow
    }

    // Plate, visible through any transparent parts of the artwork.
    Rectangle {
        width: root.diameter
        height: root.diameter
        anchors.centerIn: parent
        radius: root.cornerRadius
        visible: root.isMasked
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.isLight ? "#fafafa" : "#3a3a3c" }
            GradientStop { position: 1.0; color: root.isLight ? "#ededed" : "#2c2c2e" }
        }
    }

    Rectangle {
        id: mask
        anchors.centerIn: parent
        width: root.diameter
        height: root.diameter
        radius: root.cornerRadius
        visible: false
        layer.enabled: root.needsLayer
        layer.smooth: true
        layer.mipmap: false
        layer.textureSize: Qt.size(root.renderSize, root.renderSize)
    }

    // Artwork. When masked the Image overflows this item by `overscan`; the layer only
    // captures the item's own bounds, and the mask then rounds it off.
    Item {
        id: art
        width: root.diameter
        height: root.diameter
        anchors.centerIn: parent

        layer.enabled: root.needsLayer
        layer.smooth: true
        layer.mipmap: false
        layer.textureSize: Qt.size(root.renderSize, root.renderSize)
        layer.effect: root.needsLayer ? maskEffect : null

        Component {
            id: maskEffect
            MultiEffect {
                maskEnabled: true
                maskSource: mask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }
        }

        Image {
            id: icon
            anchors.centerIn: parent
            width: Math.round(root.isMasked ? parent.width * root.overscan : parent.width)
            height: width

            readonly property int rasterSize: Math.round(root.renderSize * (root.isMasked ? root.overscan : 1.0) / 2) * 2
            sourceSize: Qt.size(rasterSize, rasterSize)

            asynchronous: root.asynchronous
            mipmap: true
            smooth: true
            fillMode: Image.PreserveAspectFit
            source: root.source
        }
    }

    // Hairline rim so a white plate still reads as a disc/squircle on a light dock
    Rectangle {
        width: root.diameter
        height: root.diameter
        anchors.centerIn: parent
        radius: root.cornerRadius
        color: "transparent"
        border.width: 1
        border.color: root.isLight ? "#1a000000" : "#26ffffff"
        visible: root.isMasked
    }
}
