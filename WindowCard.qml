import QtQuick
import QtQuick.Effects

// A stunning, immersive macOS frosted glass card with an enlarged Gaussian-blurred icon artwork backdrop
Item {
    id: root

    property var winData: null
    property var dockRef: null
    property var cellRef: null

    readonly property bool isLight: dockRef ? dockRef.isLight : false
    readonly property bool isActive: winData ? winData.active === true : false
    readonly property bool isMinimized: winData ? winData.minimized === true : false

    // App name & icon resolution with full fallback chain
    readonly property string appName: (cellRef && cellRef.entry && cellRef.entry.name)
        ? cellRef.entry.name
        : (cellRef && cellRef.appId ? cellRef.appId : "")

    readonly property string resolvedIcon: {
        if (cellRef && cellRef.resolvedIcon && cellRef.resolvedIcon !== "") {
            return cellRef.resolvedIcon;
        }
        if (cellRef && cellRef.content && cellRef.content.iconSource && cellRef.content.iconSource !== "") {
            return cellRef.content.iconSource;
        }
        if (cellRef && cellRef.entry) {
            const list = IconResolver.candidates(cellRef.entry);
            if (list && list.length > 0) return list[0];
        }
        if (winData && winData.icon) {
            if (winData.icon.startsWith("/") || winData.icon.startsWith("image://") || winData.icon.startsWith("file://")) {
                return winData.icon;
            }
            return "image://icon/" + winData.icon;
        }
        return "";
    }

    readonly property string rawTitle: winData ? (winData.title || "") : ""
    readonly property string cleanTitle: {
        if (!rawTitle) return "";
        let t = rawTitle.trim();
        const appNames = [];
        if (appName) {
            appNames.push(appName);
            const first = appName.split(" ")[0];
            if (first && first.length >= 3 && first !== appName) appNames.push(first);
        }
        for (const name of appNames) {
            for (const sep of [" — ", " - ", " | "]) {
                if (t.endsWith(sep + name)) {
                    t = t.slice(0, -(sep.length + name.length)).trim();
                    break;
                }
            }
            const mid = " - " + name + " - ";
            if (t.indexOf(mid) >= 0) {
                const parts = t.split(mid);
                if (parts.length === 2) {
                    t = parts[1].trim() + " (" + parts[0].trim() + ")";
                    break;
                }
            }
            const mid2 = " — " + name + " — ";
            if (t.indexOf(mid2) >= 0) {
                const parts = t.split(mid2);
                if (parts.length === 2) {
                    t = parts[1].trim() + " (" + parts[0].trim() + ")";
                    break;
                }
            }
        }
        return t || rawTitle;
    }

    readonly property string windowTitle: {
        if (cleanTitle !== "" && cleanTitle !== "窗口") return cleanTitle;
        if (rawTitle !== "" && rawTitle !== "窗口") return rawTitle;
        if (appName !== "") return appName;
        return "窗口";
    }

    width: dockRef ? dockRef.cardWidth : 230
    height: Math.max(38, (dockRef ? dockRef.cellSize : 52) - 6)

    // Smooth press and hover scaling
    scale: cardMouse.pressed ? 0.96 : (cardMouse.containsMouse ? 1.02 : 1.0)
    Behavior on scale {
        NumberAnimation { duration: 130; easing.type: Easing.OutQuad }
    }

    // Mask plate for rounded corner clipping
    Rectangle {
        id: maskPlate
        width: root.width
        height: root.height
        radius: 12
        color: "#ffffff"
        visible: false
    }

    // Main Card Box
    Item {
        id: container
        anchors.fill: parent

        // Layer 1: Enlarged Gaussian-blurred icon artwork backdrop for full immersion
        Item {
            id: blurredBackdrop
            anchors.fill: parent

            Image {
                id: bgArt
                anchors.centerIn: parent
                width: Math.max(parent.width, parent.height) * 1.1
                height: width
                fillMode: Image.PreserveAspectFit
                source: root.resolvedIcon
                smooth: true
                mipmap: true
                visible: false
            }

            MultiEffect {
                source: bgArt
                anchors.fill: parent
                blurEnabled: true
                blur: 1.0
                blurMax: 48
                saturation: 0.35
                maskEnabled: true
                maskSource: maskPlate
                opacity: root.isLight ? 0.28 : 0.42
            }
        }

        // Layer 2: Frosted glass tinted plate
        Rectangle {
            id: glassPlate
            anchors.fill: parent
            radius: 12

            color: root.isActive
                ? (root.isLight ? Qt.rgba(0.01, 0.52, 0.78, 0.18) : Qt.rgba(0.23, 0.51, 0.96, 0.28))
                : (cardMouse.containsMouse
                    ? (root.isLight ? Qt.rgba(1, 1, 1, 0.88) : Qt.rgba(0.13, 0.16, 0.23, 0.88))
                    : (root.isLight ? Qt.rgba(1, 1, 1, 0.75) : Qt.rgba(0.08, 0.11, 0.18, 0.80)))

            border.width: root.isActive ? 1.5 : 1
            border.color: root.isActive
                ? (root.isLight ? "#0284c7" : "#3b82f6")
                : (cardMouse.containsMouse
                    ? (root.isLight ? Qt.rgba(0, 0, 0, 0.18) : Qt.rgba(1, 1, 1, 0.26))
                    : (root.isLight ? Qt.rgba(0, 0, 0, 0.09) : Qt.rgba(1, 1, 1, 0.13)))

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            // Top specular highlight shelf reflection
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 1
                height: 1
                radius: 12
                color: root.isLight ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(1, 1, 1, 0.20)
            }
        }

        // Layer 3: Foreground Content
        Row {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10

            // High-DPI Crisp App Icon with soft depth shadow
            Item {
                width: 28
                height: 28
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: "#25000000"
                    y: 1.5
                    z: -1
                }

                Image {
                    id: fgIcon
                    anchors.fill: parent
                    source: root.resolvedIcon
                    sourceSize.width: 56
                    sourceSize.height: 56
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    mipmap: true
                }
            }

            // Window Details Column
            Column {
                id: infoCol
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 28 - (closeBtn.visible ? 26 : 6) - 10
                spacing: 2

                // Top: App Name and Status Badge
                Row {
                    spacing: 6
                    width: parent.width

                    Text {
                        text: root.appName !== "" ? root.appName : "应用"
                        color: root.isLight
                            ? (root.isActive ? "#0284c7" : "#475569")
                            : (root.isActive ? "#60a5fa" : "#94a3b8")
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Row {
                        spacing: 3
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            width: 5
                            height: 5
                            radius: 2.5
                            anchors.verticalCenter: parent.verticalCenter
                            color: root.isActive
                                ? (root.isLight ? "#059669" : "#10b981")
                                : (root.isMinimized ? "#f59e0b" : (root.isLight ? "#94a3b8" : "#64748b"))
                        }

                        Text {
                            text: root.isActive ? "当前" : (root.isMinimized ? "最小化" : "")
                            font.pixelSize: 9
                            color: root.isLight ? "#64748b" : "#94a3b8"
                            anchors.verticalCenter: parent.verticalCenter
                            visible: text !== ""
                        }
                    }
                }

                // Bottom: Actual Window Title
                Text {
                    id: titleText
                    width: parent.width
                    text: root.windowTitle
                    color: root.isLight
                        ? (root.isActive ? "#0284c7" : "#0f172a")
                        : (root.isActive ? "#ffffff" : "#f1f5f9")
                    font.pixelSize: 12
                    font.weight: root.isActive ? Font.Bold : Font.Medium
                    elide: Text.ElideRight
                }
            }

            // Right: macOS Circular Close Button
            Item {
                id: closeBtn
                width: 20
                height: 20
                anchors.verticalCenter: parent.verticalCenter
                visible: cardMouse.containsMouse || closeMouse.containsMouse

                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: closeMouse.containsMouse
                        ? "#ef4444"
                        : (root.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.15))

                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: closeMouse.containsMouse
                            ? "#ffffff"
                            : (root.isLight ? "#475569" : "#cbd5e1")
                    }
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        mouse.accepted = true;
                        if (root.winData && root.winData.modelIndex) {
                            Tasks.closeWindow(root.winData.modelIndex);
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        id: cardMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.winData && root.winData.modelIndex) {
                Tasks.activateWindow(root.winData.modelIndex);
            }
            if (root.dockRef) {
                root.dockRef.expandedAppKey = "";
            }
        }
    }
}
