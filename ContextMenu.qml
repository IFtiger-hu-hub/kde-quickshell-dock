import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Effects

PopupWindow {
    id: root

    property var dockRef: null
    readonly property string position: dockRef ? dockRef.dockPosition : Config.position

    anchor.edges: position === "top" ? Edges.Bottom
                : position === "left" ? Edges.Right
                : position === "right" ? Edges.Left
                : Edges.Top
    anchor.gravity: anchor.edges
    anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.SlideY

    property var targetCell: null
    readonly property var targetEntry: targetCell ? targetCell.entry : null
    readonly property string taskKey: targetCell ? targetCell.taskKey : ""
    readonly property string appId: targetCell ? targetCell.appId : ""
    readonly property bool isRunning: targetCell ? targetCell.running : false
    readonly property int windowCount: targetCell ? targetCell.windows : 0

    readonly property bool isPinned: {
        if (!targetCell) return false;
        for (const f of PlasmaFavorites.entries) {
            if (f.id === targetCell.appId || Tasks.key(f.id) === targetCell.taskKey) return true;
        }
        return false;
    }

    readonly property var recentList: {
        RecentFiles.revision;
        RecentFiles.recentMap;
        if (!targetCell) return [];
        const byKey = RecentFiles.getRecent(taskKey);
        if (byKey && byKey.length > 0) return byKey;
        const byAppId = RecentFiles.getRecent(appId);
        if (byAppId && byAppId.length > 0) return byAppId;
        if (targetEntry && targetEntry.name) {
            const byName = RecentFiles.getRecent(targetEntry.name);
            if (byName && byName.length > 0) return byName;
        }
        return [];
    }

    readonly property var desktopActions: {
        if (targetEntry && targetEntry.actions && targetEntry.actions.length > 0) {
            return targetEntry.actions;
        }
        return [];
    }

    // Icon candidate fallback resolution (matches DockIcon)
    readonly property var iconSources: IconResolver.candidates(targetEntry)
    property int iconAttempt: 0
    readonly property string headerIconSource: iconAttempt < iconSources.length ? iconSources[iconAttempt] : ""
    onTargetEntryChanged: iconAttempt = 0

    function open(cell) {
        targetCell = cell;
        anchor.item = cell;
        iconAttempt = 0;
        RecentFiles.refresh();
        visible = true;
    }

    function close() {
        visible = false;
    }

    grabFocus: true
    onClosed: root.close()

    implicitWidth: card.width + (position === "left" || position === "right" ? 24 : 16)
    implicitHeight: card.height + (position === "top" || position === "bottom" ? 24 : 16)

    color: "transparent"

    // Hardware-accelerated Gaussian Blur behind ContextMenu via KWin
    BackgroundEffect.blurRegion: Region {
        item: card
    }

    // Ambient diffuse drop shadow
    RectangularShadow {
        id: cardShadow
        anchors.fill: card
        radius: card.radius
        color: root.isLight ? "#30000000" : "#65000000"
        blur: 20
        spread: 0
        z: -1
    }

    readonly property bool isLight: dockRef ? dockRef.isLight : ((0.299 * Config.backgroundColor.r + 0.587 * Config.backgroundColor.g + 0.114 * Config.backgroundColor.b) > 0.5)

    Process {
        id: dbusCall
    }

    function pinApp() {
        const id = targetCell ? (targetCell.appId || taskKey) : "";
        if (!id) return;
        const res = id.startsWith("applications:") ? id : ("applications:" + (id.endsWith(".desktop") ? id : (id + ".desktop")));
        dbusCall.command = ["gdbus", "call", "--session",
            "--dest", "org.kde.ActivityManager",
            "--object-path", "/ActivityManager/Resources/Linking",
            "--method", "org.kde.ActivityManager.ResourcesLinking.LinkResourceToActivity",
            "org.kde.plasma.favorites.applications", res, ":global"];
        dbusCall.startDetached();
        root.close();
    }

    function unpinApp() {
        const id = targetCell ? (targetCell.appId || taskKey) : "";
        if (!id) return;
        const res = id.startsWith("applications:") ? id : ("applications:" + (id.endsWith(".desktop") ? id : (id + ".desktop")));
        dbusCall.command = ["gdbus", "call", "--session",
            "--dest", "org.kde.ActivityManager",
            "--object-path", "/ActivityManager/Resources/Linking",
            "--method", "org.kde.ActivityManager.ResourcesLinking.UnlinkResourceFromActivity",
            "org.kde.plasma.favorites.applications", res, ":global"];
        dbusCall.startDetached();
        root.close();
    }

    Rectangle {
        id: card
        width: 300
        height: mainCol.implicitHeight + 16
        anchors.left: position === "right" ? parent.left : undefined
        anchors.right: position === "left" ? parent.right : undefined
        anchors.horizontalCenter: (position === "top" || position === "bottom") ? parent.horizontalCenter : undefined
        anchors.bottom: position === "top" ? parent.bottom : undefined
        anchors.top: position === "top" ? undefined : parent.top

        color: root.isLight ? Qt.rgba(0.97, 0.98, 1.0, 0.92) : "#f2141824"
        radius: 14
        border.color: root.isLight ? Qt.rgba(0, 0, 0, 0.12) : "#28ffffff"
        border.width: 1

        // Top subtle highlight
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 1
            height: 1
            color: root.isLight ? Qt.rgba(1, 1, 1, 0.85) : "#30ffffff"
            radius: 14
        }

        Column {
            id: mainCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 8
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 6

            // App Header
            Rectangle {
                width: parent.width
                height: 50
                color: root.isLight ? Qt.rgba(0, 0, 0, 0.04) : "#12ffffff"
                radius: 10
                border.color: root.isLight ? Qt.rgba(0, 0, 0, 0.06) : "#18ffffff"
                border.width: 1

                Row {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 10

                    Item {
                        width: 34
                        height: 34
                        anchors.verticalCenter: parent.verticalCenter

                        Image {
                            id: appIcon
                            anchors.fill: parent
                            source: root.headerIconSource
                            sourceSize.width: 34
                            sourceSize.height: 34
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            onStatusChanged: {
                                if (status === Image.Error && root.iconAttempt < root.iconSources.length - 1) {
                                    root.iconAttempt++;
                                }
                            }
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 44
                        spacing: 2

                        Text {
                            width: parent.width
                            text: root.targetEntry ? root.targetEntry.name : (root.targetCell ? root.targetCell.appId : "")
                            color: root.isLight ? "#0f172a" : "#ffffff"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Row {
                            spacing: 5

                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                anchors.verticalCenter: parent.verticalCenter
                                color: root.isRunning ? (root.isLight ? "#059669" : "#10b981") : (root.isLight ? "#94a3b8" : "#64748b")
                            }

                            Text {
                                text: root.isRunning
                                    ? (root.windowCount > 1 ? ("运行中 · " + root.windowCount + " 个窗口") : "正在运行")
                                    : "未运行"
                                color: root.isRunning ? (root.isLight ? "#059669" : "#34d399") : (root.isLight ? "#64748b" : "#94a3b8")
                                font.pixelSize: 10
                            }
                        }
                    }
                }
            }

            // Section: 最近打开 (Recent Documents / Projects)
            Column {
                width: parent.width
                spacing: 3
                visible: root.recentList.length > 0

                Rectangle {
                    width: parent.width
                    height: 1
                    color: root.isLight ? Qt.rgba(0, 0, 0, 0.08) : "#18ffffff"
                }

                Item {
                    width: parent.width
                    height: 22

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        spacing: 6

                        Image {
                            source: "image://icon/document-open-recent"
                            sourceSize.width: 13
                            sourceSize.height: 13
                            width: 13
                            height: 13
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: root.isLight ? 0.65 : 0.75
                        }

                        Text {
                            text: "最近打开"
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: root.isLight ? "#64748b" : "#94a3b8"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        text: Math.min(root.recentList.length, 8) + " 项"
                        font.pixelSize: 10
                        color: root.isLight ? "#94a3b8" : "#64748b"
                    }
                }

                Repeater {
                    model: root.recentList.slice(0, 8)

                    delegate: Rectangle {
                        id: recentRow
                        width: parent.width
                        height: 38
                        radius: 8
                        color: itemMouseArea.pressed
                            ? (root.isLight ? Qt.rgba(0, 0, 0, 0.10) : "#35ffffff")
                            : (itemMouseArea.containsMouse ? (root.isLight ? Qt.rgba(0, 0, 0, 0.06) : "#20ffffff") : "transparent")

                        Behavior on color {
                            ColorAnimation { duration: 100 }
                        }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            Item {
                                width: 20
                                height: 20
                                anchors.verticalCenter: parent.verticalCenter

                                Image {
                                    anchors.fill: parent
                                    source: {
                                        if (modelData.isDir) return "image://icon/folder";
                                        const p = String(modelData.path).toLowerCase();
                                        if (p.endsWith(".pdf")) return "image://icon/application-pdf";
                                        if (p.endsWith(".png") || p.endsWith(".jpg") || p.endsWith(".jpeg") || p.endsWith(".svg") || p.endsWith(".webp")) return "image://icon/image-x-generic";
                                        if (p.endsWith(".md") || p.endsWith(".txt")) return "image://icon/text-plain";
                                        if (p.endsWith(".ts") || p.endsWith(".js") || p.endsWith(".json") || p.endsWith(".qml") || p.endsWith(".py") || p.endsWith(".cpp") || p.endsWith(".c") || p.endsWith(".h")) return "image://icon/text-x-script";
                                        return "image://icon/text-x-generic";
                                    }
                                    sourceSize.width: 20
                                    sourceSize.height: 20
                                    fillMode: Image.PreserveAspectFit
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 48
                                spacing: 1

                                Text {
                                    width: parent.width
                                    text: modelData.title
                                    color: itemMouseArea.containsMouse ? (root.isLight ? "#0284c7" : "#ffffff") : (root.isLight ? "#1e293b" : "#e2e8f0")
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    elide: Text.ElideMiddle
                                }

                                Text {
                                    width: parent.width
                                    text: modelData.displayPath
                                    color: root.isLight ? "#64748b" : "#94a3b8"
                                    font.pixelSize: 10
                                    elide: Text.ElideMiddle
                                }
                            }

                            Text {
                                text: "↗"
                                color: root.isLight ? "#0284c7" : "#60a5fa"
                                font.pixelSize: 12
                                anchors.verticalCenter: parent.verticalCenter
                                visible: itemMouseArea.containsMouse
                            }
                        }

                        MouseArea {
                            id: itemMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                RecentFiles.openFile(root.targetEntry, modelData.path);
                                root.close();
                            }
                        }
                    }
                }
            }

            // Section: Desktop Actions
            Column {
                width: parent.width
                spacing: 3
                visible: root.desktopActions.length > 0

                Rectangle {
                    width: parent.width
                    height: 1
                    color: root.isLight ? Qt.rgba(0, 0, 0, 0.08) : "#18ffffff"
                }

                Item {
                    width: parent.width
                    height: 20

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        text: "快捷操作"
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: root.isLight ? "#64748b" : "#94a3b8"
                    }
                }

                Repeater {
                    model: root.desktopActions.slice(0, 5)

                    delegate: Rectangle {
                        width: parent.width
                        height: 32
                        radius: 8
                        color: actMouseArea.pressed
                            ? (root.isLight ? Qt.rgba(0, 0, 0, 0.10) : "#35ffffff")
                            : (actMouseArea.containsMouse ? (root.isLight ? Qt.rgba(0, 0, 0, 0.06) : "#20ffffff") : "transparent")

                        Behavior on color {
                            ColorAnimation { duration: 100 }
                        }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            Image {
                                width: 16
                                height: 16
                                anchors.verticalCenter: parent.verticalCenter
                                source: modelData.icon || "image://icon/application-x-executable"
                                sourceSize.width: 16
                                sourceSize.height: 16
                            }

                            Text {
                                width: parent.width - 24
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name
                                color: actMouseArea.containsMouse ? (root.isLight ? "#0284c7" : "#ffffff") : (root.isLight ? "#1e293b" : "#e2e8f0")
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: actMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                modelData.execute();
                                root.close();
                            }
                        }
                    }
                }
            }

            // Section: Window / Launch Controls
            Column {
                width: parent.width
                spacing: 3

                Rectangle {
                    width: parent.width
                    height: 1
                    color: root.isLight ? Qt.rgba(0, 0, 0, 0.08) : "#18ffffff"
                }

                // If running: New Instance
                Rectangle {
                    width: parent.width
                    height: 32
                    radius: 8
                    visible: root.isRunning
                    color: newInstMouse.pressed
                        ? (root.isLight ? Qt.rgba(0, 0, 0, 0.10) : "#35ffffff")
                        : (newInstMouse.containsMouse ? (root.isLight ? Qt.rgba(0, 0, 0, 0.06) : "#20ffffff") : "transparent")

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        Image {
                            width: 16
                            height: 16
                            anchors.verticalCenter: parent.verticalCenter
                            source: "image://icon/window-new"
                            sourceSize.width: 16
                            sourceSize.height: 16
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "新建窗口"
                            color: newInstMouse.containsMouse ? (root.isLight ? "#0284c7" : "#ffffff") : (root.isLight ? "#1e293b" : "#e2e8f0")
                            font.pixelSize: 12
                        }
                    }

                    MouseArea {
                        id: newInstMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Tasks.launchNew(root.taskKey);
                            root.close();
                        }
                    }
                }

                // If running: Switch / Raise Window
                Rectangle {
                    width: parent.width
                    height: 32
                    radius: 8
                    visible: root.isRunning
                    color: activateMouse.pressed
                        ? (root.isLight ? Qt.rgba(0, 0, 0, 0.10) : "#35ffffff")
                        : (activateMouse.containsMouse ? (root.isLight ? Qt.rgba(0, 0, 0, 0.06) : "#20ffffff") : "transparent")

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        Image {
                            width: 16
                            height: 16
                            anchors.verticalCenter: parent.verticalCenter
                            source: "image://icon/go-top"
                            sourceSize.width: 16
                            sourceSize.height: 16
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.windowCount > 1 ? "切换下一个窗口" : "置顶应用窗口"
                            color: activateMouse.containsMouse ? (root.isLight ? "#0284c7" : "#ffffff") : (root.isLight ? "#1e293b" : "#e2e8f0")
                            font.pixelSize: 12
                        }
                    }

                    MouseArea {
                        id: activateMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Tasks.activate(root.taskKey, false);
                            root.close();
                        }
                    }
                }

                // If NOT running: Launch App
                Rectangle {
                    width: parent.width
                    height: 32
                    radius: 8
                    visible: !root.isRunning
                    color: launchMouse.pressed
                        ? (root.isLight ? Qt.rgba(0, 0, 0, 0.10) : "#35ffffff")
                        : (launchMouse.containsMouse ? (root.isLight ? Qt.rgba(0, 0, 0, 0.06) : "#20ffffff") : "transparent")

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        Image {
                            width: 16
                            height: 16
                            anchors.verticalCenter: parent.verticalCenter
                            source: "image://icon/media-playback-start"
                            sourceSize.width: 16
                            sourceSize.height: 16
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "启动应用"
                            color: launchMouse.containsMouse ? (root.isLight ? "#0284c7" : "#ffffff") : (root.isLight ? "#1e293b" : "#e2e8f0")
                            font.pixelSize: 12
                        }
                    }

                    MouseArea {
                        id: launchMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.targetEntry) root.targetEntry.execute();
                            root.close();
                        }
                    }
                }

                // Pin / Unpin Action
                Rectangle {
                    width: parent.width
                    height: 32
                    radius: 8
                    color: pinMouse.pressed
                        ? (root.isLight ? Qt.rgba(0, 0, 0, 0.10) : "#35ffffff")
                        : (pinMouse.containsMouse ? (root.isLight ? Qt.rgba(0, 0, 0, 0.06) : "#20ffffff") : "transparent")

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        Image {
                            width: 16
                            height: 16
                            anchors.verticalCenter: parent.verticalCenter
                            source: root.isPinned ? "image://icon/list-remove" : "image://icon/bookmark-new"
                            sourceSize.width: 16
                            sourceSize.height: 16
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.isPinned ? "从 Dock 移除" : "固定到 Dock"
                            color: pinMouse.containsMouse ? (root.isPinned ? "#ef4444" : (root.isLight ? "#0284c7" : "#60a5fa")) : (root.isLight ? "#1e293b" : "#e2e8f0")
                            font.pixelSize: 12
                        }
                    }

                    MouseArea {
                        id: pinMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.isPinned) root.unpinApp();
                            else root.pinApp();
                        }
                    }
                }
            }
        }
    }
}
