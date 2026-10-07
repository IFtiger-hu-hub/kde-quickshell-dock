import Quickshell
import QtQuick
import QtQuick.Effects

// The visual representation of a folder on the dock:
// A rounded/circular frosted-glass plate with a 3x3 mini grid previewing up to 9 apps inside.
// Supports parabolic wave scaling, bounce, tactile press feedback, and drag-and-drop targeting.
Item {
    id: root

    property var dockRef: null
    readonly property var d: dockRef ? dockRef : (typeof dock !== "undefined" ? dock : null)

    readonly property int iconSize: d ? d.iconSize : Config.iconSize
    readonly property string dockPosition: d ? d.dockPosition : "bottom"
    readonly property int radius: d ? d.radius : Config.radius
    readonly property bool hoverMagnify: d ? d.hoverMagnify : Config.hoverMagnify
    readonly property real hoverScale: d ? d.hoverScale : 1.3
    readonly property bool runningIndicator: d ? d.runningIndicator : true
    readonly property int indicatorDotSize: d ? d.indicatorDotSize : 4
    readonly property int indicatorActiveDotSize: d ? d.indicatorActiveDotSize : 6
    readonly property color indicatorColor: d ? d.indicatorColor : "#888888"
    readonly property color indicatorActiveColor: d ? d.indicatorActiveColor : "#0a84ff"
    readonly property bool circularIcons: d ? d.circularIcons : Config.circularIcons
    readonly property bool isLight: d ? d.isLight : true

    required property string folderId
    property bool hovered: false
    property bool pressed: false
    property bool dragging: false
    property bool dragHoverTarget: false

    property int windows: 0
    property bool active: false
    readonly property bool running: windows > 0
    property bool isExpanded: false

    // Wave scale & lift passed down from dock wave engine
    property real currentScale: 1.0
    property real liftX: 0
    property real liftY: 0
    property real bounceY: 0

    readonly property var folderData: DockFolders.getFolder(folderId)
    readonly property var appList: folderData && folderData.apps ? folderData.apps : []

    readonly property real diameter: Math.min(iconWrapper.width, iconWrapper.height)

    // The plate holding the mini 3x3 grid
    Item {
        id: iconWrapper

        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize

        scale: (root.pressed ? 0.92 : (root.dragHoverTarget ? 1.12 : root.currentScale))
        Behavior on scale {
            enabled: !root.dragging
            NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
        }

        transform: Translate {
            x: root.liftX
            y: root.liftY + root.bounceY
        }

        // Soft contact shadow
        Rectangle {
            width: root.diameter
            height: root.diameter
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 1.5
            radius: root.circularIcons ? (width / 2) : Math.max(10, root.radius * 0.8)
            color: root.isLight ? "#22000000" : "#45000000"
            visible: !root.dragging
        }

        // Frosted Glass Base Plate
        Rectangle {
            id: plateBackground
            width: root.diameter
            height: root.diameter
            anchors.centerIn: parent
            radius: root.circularIcons ? (width / 2) : Math.max(10, root.radius * 0.8)

            color: root.dragHoverTarget
                ? (root.isLight ? Qt.rgba(0.04, 0.52, 1.0, 0.22) : Qt.rgba(0.04, 0.52, 1.0, 0.35))
                : (root.isLight ? Qt.rgba(0.95, 0.95, 0.97, 0.55) : Qt.rgba(0.22, 0.22, 0.25, 0.65))

            border.width: root.dragHoverTarget ? 2 : 1
            border.color: root.dragHoverTarget
                ? Theme.accent
                : (root.isLight ? Qt.rgba(0, 0, 0, 0.14) : Qt.rgba(1, 1, 1, 0.20))

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            // Inner subtle gradient
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.isLight ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, 0.12) }
                    GradientStop { position: 1.0; color: root.isLight ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.10) }
                }
            }

            // Subtle hairline rim
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 1
                border.color: root.isLight ? "#1a000000" : "#26ffffff"
                visible: root.circularIcons
            }
        }

        // 3x3 Mini Grid Container
        Item {
            id: gridContainer
            anchors.centerIn: parent
            width: Math.round(root.diameter * 0.72)
            height: width

            // If empty folder, show folder symbol
            Image {
                anchors.centerIn: parent
                width: Math.round(root.diameter * 0.65)
                height: width
                source: "image://icon/folder"
                visible: root.appList.length === 0
                opacity: 0.6
                fillMode: Image.PreserveAspectFit
            }

            // Mini Grid of App Icons (2x2 for <=4 apps, 3x3 for >4 apps)
            Grid {
                id: iconGrid
                anchors.centerIn: parent
                readonly property int gridCols: root.appList.length <= 4 ? 2 : 3
                columns: gridCols
                spacing: gridCols === 2 ? 3.5 : 2.5
                visible: root.appList.length > 0

                readonly property real cellDim: Math.floor((gridContainer.width - spacing * (gridCols - 1)) / gridCols)

                Repeater {
                    model: root.appList.slice(0, iconGrid.gridCols * iconGrid.gridCols)
                    delegate: Item {
                        id: miniCell
                        required property var modelData
                        required property int index

                        width: iconGrid.cellDim
                        height: iconGrid.cellDim

                        readonly property var entry: DockFolders.resolveAppEntry(modelData)
                        readonly property var iconSources: IconResolver.candidates(entry)
                        property int attempt: 0
                        readonly property string currentSource: attempt < iconSources.length ? iconSources[attempt] : ""

                        onModelDataChanged: attempt = 0

                        Rectangle {
                            anchors.fill: parent
                            radius: Math.max(2, width * 0.22)
                            color: "transparent"
                            clip: true

                            Image {
                                id: miniImg
                                anchors.fill: parent
                                anchors.margins: 0.5
                                source: miniCell.currentSource
                                sourceSize.width: 36
                                sourceSize.height: 36
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                mipmap: true
                                smooth: true
                                onStatusChanged: {
                                    if (status === Image.Error && miniCell.attempt < miniCell.iconSources.length - 1) {
                                        miniCell.attempt++;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    readonly property bool isVertical: root.dockPosition === "left" || root.dockPosition === "right"

    // macOS Authentic Centered Running Indicator Dot
    Item {
        id: indicatorContainer

        readonly property int dotSize: root.active ? root.indicatorActiveDotSize : root.indicatorDotSize

        width: dotSize
        height: dotSize

        anchors.horizontalCenter: (!root.isVertical) ? parent.horizontalCenter : undefined
        anchors.verticalCenter: root.isVertical ? parent.verticalCenter : undefined

        x: root.dockPosition === "left"
            ? Math.round((parent.width - root.iconSize) / 2 - dotSize - 2)
            : root.dockPosition === "right"
            ? Math.round(parent.width - (parent.width - root.iconSize) / 2 + 2)
            : 0

        y: root.dockPosition === "top"
            ? Math.round((parent.height - root.iconSize) / 2 - dotSize - 2)
            : root.dockPosition === "bottom"
            ? Math.round(parent.height - (parent.height - root.iconSize) / 2 + 2)
            : 0

        visible: opacity > 0
        opacity: root.runningIndicator && root.running && !root.dragging ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160 } }

        Rectangle {
            id: dot
            anchors.fill: parent
            radius: width / 2

            color: root.active ? root.indicatorActiveColor : root.indicatorColor

            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 140 } }
        }
    }
}
