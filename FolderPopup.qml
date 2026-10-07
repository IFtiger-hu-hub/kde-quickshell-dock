import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

// Ultra-premium macOS Liquid Glass popup panel displaying applications in a folder.
// Supports inline renaming, launching apps, removing/moving out apps,
// adding installed apps via searchable picker, and drag-and-drop ingestion.
PopupWindow {
    id: root

    property var dockRef: null
    readonly property string position: dockRef ? dockRef.dockPosition : Config.position
    readonly property bool isLight: dockRef ? dockRef.isLight : true
    readonly property bool circularIcons: dockRef ? dockRef.circularIcons : Config.circularIcons
    readonly property string iconShape: dockRef ? dockRef.iconShape : (Config.iconShape ?? (circularIcons ? "circle" : "original"))

    anchor.edges: position === "top" ? Edges.Bottom
                : position === "left" ? Edges.Right
                : position === "right" ? Edges.Left
                : Edges.Top
    anchor.gravity: anchor.edges
    anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.SlideY

    property var targetCell: null
    property string folderId: ""
    readonly property var folderData: DockFolders.getFolder(folderId)
    readonly property var appList: folderData && folderData.apps ? folderData.apps : []
    readonly property string folderTitle: folderData && folderData.name ? folderData.name : "文件夹"

    property bool pickerMode: false
    property bool editingTitle: false
    property string searchQuery: ""
    property string activeAppMenuId: ""
    property var activeTargetApp: null
    property bool switchingFolder: false

    Timer {
        id: switchTimer
        interval: 35
        onTriggered: {
            root.switchingFolder = false;
            root.visible = true;
        }
    }

    function open(cell, id) {
        if (visible && (folderId !== id || targetCell !== cell)) {
            // Already visible on another folder: unmap immediately to destroy old Wayland popup
            // and avoid flying across the screen or flashing content
            visible = false;
            switchingFolder = true;
            targetCell = cell;
            anchor.item = cell;
            folderId = id;
            pickerMode = false;
            editingTitle = false;
            searchQuery = "";
            activeAppMenuId = "";
            activeTargetApp = null;
            switchTimer.restart();
            return;
        }

        switchTimer.stop();
        switchingFolder = false;
        targetCell = cell;
        anchor.item = cell;
        folderId = id;
        pickerMode = false;
        editingTitle = false;
        searchQuery = "";
        activeAppMenuId = "";
        activeTargetApp = null;
        visible = true;
    }

    function close() {
        switchTimer.stop();
        visible = false;
        switchingFolder = false;
        pickerMode = false;
        editingTitle = false;
        activeAppMenuId = "";
        activeTargetApp = null;
        try { gc(); } catch (e) {}
    }

    Process {
        id: dbusCall
    }

    function pinApp(id) {
        if (!id) return;
        const res = id.startsWith("applications:") ? id : ("applications:" + (id.endsWith(".desktop") ? id : (id + ".desktop")));
        dbusCall.command = ["gdbus", "call", "--session",
            "--dest", "org.kde.ActivityManager",
            "--object-path", "/ActivityManager/Resources/Linking",
            "--method", "org.kde.ActivityManager.ResourcesLinking.LinkResourceToActivity",
            "org.kde.plasma.favorites.applications", res, ":global"];
        dbusCall.startDetached();
        root.activeAppMenuId = "";
        root.activeTargetApp = null;
    }

    function unpinApp(id) {
        if (!id) return;
        const res = id.startsWith("applications:") ? id : ("applications:" + (id.endsWith(".desktop") ? id : (id + ".desktop")));
        dbusCall.command = ["gdbus", "call", "--session",
            "--dest", "org.kde.ActivityManager",
            "--object-path", "/ActivityManager/Resources/Linking",
            "--method", "org.kde.ActivityManager.ResourcesLinking.UnlinkResourceFromActivity",
            "org.kde.plasma.favorites.applications", res, ":global"];
        dbusCall.startDetached();
        root.activeAppMenuId = "";
        root.activeTargetApp = null;
    }

    grabFocus: true
    onClosed: root.close()

    implicitWidth: card.width + 48
    implicitHeight: card.height + 48
    color: "transparent"

    // Hardware-accelerated Gaussian Blur behind folder card via KWin
    BackgroundEffect.blurRegion: Region {
        x: Math.round(card.x)
        y: Math.round(card.y)
        width: Math.round(card.width)
        height: Math.round(card.height)
        radius: card.radius
    }

    // Ambient diffuse drop shadow
    RectangularShadow {
        id: cardAmbientShadow
        anchors.fill: card
        radius: card.radius
        color: root.isLight ? "#22000000" : "#55000000"
        offset: Qt.vector2d(0, 10)
        blur: 36
        spread: 0
        z: -2
    }

    // Contact sharp grounding shadow
    RectangularShadow {
        id: cardContactShadow
        anchors.fill: card
        radius: card.radius
        color: root.isLight ? "#14000000" : "#35000000"
        offset: Qt.vector2d(0, 3)
        blur: 14
        spread: 0
        z: -1
    }

    // Escape key handler
    Item {
        anchors.fill: parent
        focus: root.visible
        Keys.onEscapePressed: {
            if (root.activeAppMenuId !== "") root.activeAppMenuId = "";
            else if (root.pickerMode) root.pickerMode = false;
            else if (root.editingTitle) root.editingTitle = false;
            else root.close();
        }
    }

    // Glass Card Surface
    Rectangle {
        id: card
        anchors.centerIn: parent

        property int gridColumns: Math.min(4, Math.max(3, Math.ceil(Math.sqrt(Math.max(1, root.appList.length)))))
        readonly property int panelWidth: root.pickerMode ? 350 : Math.max(320, gridColumns * 88 + 32)

        width: panelWidth
        height: root.pickerMode ? 440 : (mainColumn.implicitHeight + 32)

        scale: root.visible ? 1.0 : 0.94
        opacity: root.visible ? 1.0 : 0.0

        radius: 20
        border.color: dragInCard.containsDrag ? Theme.accent : (root.isLight ? Qt.rgba(255, 255, 255, 0.75) : Qt.rgba(255, 255, 255, 0.16))
        border.width: dragInCard.containsDrag ? 2 : 1

        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop {
                position: 0.0
                color: root.isLight ? Qt.rgba(0.99, 0.99, 1.0, 0.68) : Qt.rgba(0.20, 0.20, 0.24, 0.72)
            }
            GradientStop {
                position: 1.0
                color: root.isLight ? Qt.rgba(0.93, 0.94, 0.97, 0.58) : Qt.rgba(0.12, 0.12, 0.14, 0.78)
            }
        }

        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 110 } }

        Behavior on width {
            enabled: root.visible && !root.switchingFolder
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            enabled: root.visible && !root.switchingFolder
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
        Behavior on border.color { ColorAnimation { duration: 140 } }

        // Outer contrast hairline that cleanly defines card boundary
        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            radius: parent.radius + 1
            color: "transparent"
            border.width: 1
            border.color: root.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(0, 0, 0, 0.35)
        }

        // Specular top highlight line (macOS Liquid Glass bevel)
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 0.5
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: 1
            radius: 0.5
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.25; color: root.isLight ? "#70ffffff" : "#30ffffff" }
                GradientStop { position: 0.5; color: root.isLight ? "#b5ffffff" : "#55ffffff" }
                GradientStop { position: 0.75; color: root.isLight ? "#70ffffff" : "#30ffffff" }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // DropArea inside popup card to receive dragged apps
        DropArea {
            id: dragInCard
            anchors.fill: parent
            keys: ["quickshell-dock-icon"]

            onDropped: drop => {
                if (drop.source && drop.source.appId && !drop.source.isFolder) {
                    DockFolders.addAppToFolder(root.folderId, drop.source.appId);
                }
            }
        }

        // ==========================================
        // VIEW 1: NORMAL FOLDER APPS GRID VIEW
        // ==========================================
        Column {
            id: mainColumn
            visible: !root.pickerMode
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 16
            spacing: 14

            // Header Row: Folder Title, Count, and Circular Action Buttons
            Item {
                width: parent.width
                height: 32

                // Left: Folder Icon Badge and Title Area
                Row {
                    anchors.left: parent.left
                    anchors.right: headerButtons.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    spacing: 10

                    // Folder Glyph Badge
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 8
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.isLight ? Qt.rgba(0.04, 0.52, 1.0, 0.12) : Qt.rgba(0.2, 0.6, 1.0, 0.20)
                        border.width: 1
                        border.color: root.isLight ? Qt.rgba(0.04, 0.52, 1.0, 0.25) : Qt.rgba(0.2, 0.6, 1.0, 0.35)

                        Shape {
                            id: folderGlyph
                            anchors.centerIn: parent
                            width: 24
                            height: 24
                            scale: 16 / 24
                            transformOrigin: Item.Center
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                fillColor: root.isLight ? "#007aff" : "#60a5fa"
                                strokeColor: "transparent"
                                PathSvg {
                                    path: "M10 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2h-8l-2-2z"
                                }
                            }
                        }
                    }

                    // Title area with click-to-edit
                    Item {
                        id: titleArea
                        width: parent.width - 38
                        height: parent.height
                        anchors.verticalCenter: parent.verticalCenter

                        Row {
                            id: titleDisplayRow
                            visible: !root.editingTitle
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Text {
                                id: titleLabel
                                text: root.folderTitle
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                color: Theme.textPrimary(root.isLight)
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            // App Count Pill
                            Rectangle {
                                height: 18
                                width: Math.max(20, countText.implicitWidth + 10)
                                radius: 9
                                color: root.isLight ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(255, 255, 255, 0.10)
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    id: countText
                                    anchors.centerIn: parent
                                    text: String(root.appList.length)
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    color: Theme.textSecondary(root.isLight)
                                }
                            }

                            // Sleek edit pencil indicator
                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                anchors.verticalCenter: parent.verticalCenter
                                color: titleMouse.containsMouse ? (root.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.12)) : "transparent"
                                opacity: titleMouse.containsMouse ? 1.0 : 0.45
                                Behavior on opacity { NumberAnimation { duration: 120 } }

                                Shape {
                                    anchors.centerIn: parent
                                    width: 24
                                    height: 24
                                    scale: 12 / 24
                                    transformOrigin: Item.Center
                                    preferredRendererType: Shape.CurveRenderer
                                    ShapePath {
                                        fillColor: Theme.textPrimary(root.isLight)
                                        strokeColor: "transparent"
                                        PathSvg {
                                            path: "M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25zM20.71 7.04c.39-.39.39-1.02 0-1.41l-2.34-2.34c-.39-.39-1.02-.39-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83z"
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: titleMouse
                            anchors.fill: parent
                            visible: !root.editingTitle
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                titleInput.text = root.folderTitle;
                                root.editingTitle = true;
                                titleInput.forceActiveFocus();
                                titleInput.selectAll();
                            }
                        }

                        // Inline text editor
                        Rectangle {
                            visible: root.editingTitle
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 8
                            color: root.isLight ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(0.25, 0.25, 0.28, 0.85)
                            border.color: Theme.accent
                            border.width: 1.5

                            TextInput {
                                id: titleInput
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                verticalAlignment: TextInput.AlignVCenter
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: Theme.textPrimary(root.isLight)
                                selectByMouse: true

                                onAccepted: {
                                    if (text.trim() !== "") {
                                        DockFolders.renameFolder(root.folderId, text.trim());
                                    }
                                    root.editingTitle = false;
                                }

                                Keys.onEscapePressed: root.editingTitle = false
                            }
                        }
                    }
                }

                // Right: Circular Glass Action Buttons
                Row {
                    id: headerButtons
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    // Button 1: Add App (+)
                    Rectangle {
                        id: addBtn
                        width: 26
                        height: 26
                        radius: 13
                        anchors.verticalCenter: parent.verticalCenter
                        scale: addMouse.pressed ? 0.92 : (addMouse.containsMouse ? 1.08 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        color: addMouse.pressed
                            ? Theme.pressFill(root.isLight)
                            : (addMouse.containsMouse ? (root.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.15)) : (root.isLight ? Qt.rgba(0, 0, 0, 0.04) : Qt.rgba(255, 255, 255, 0.08)))
                        border.color: root.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.10)
                        border.width: 1

                        Shape {
                            anchors.centerIn: parent
                            width: 24
                            height: 24
                            scale: 14 / 24
                            transformOrigin: Item.Center
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                fillColor: Theme.textPrimary(root.isLight)
                                strokeColor: "transparent"
                                PathSvg {
                                    path: "M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z"
                                }
                            }
                        }

                        MouseArea {
                            id: addMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.searchQuery = "";
                                root.pickerMode = true;
                            }
                        }
                    }

                    // Button 2: Disband Folder (Return apps to dock)
                    Rectangle {
                        id: disbandBtn
                        width: 26
                        height: 26
                        radius: 13
                        anchors.verticalCenter: parent.verticalCenter
                        scale: disbandMouse.pressed ? 0.92 : (disbandMouse.containsMouse ? 1.08 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        color: disbandMouse.containsMouse
                            ? (root.isLight ? "#fee2e2" : Qt.rgba(239, 68, 68, 0.22))
                            : (root.isLight ? Qt.rgba(0, 0, 0, 0.04) : Qt.rgba(255, 255, 255, 0.08))
                        border.color: disbandMouse.containsMouse
                            ? (root.isLight ? "#fca5a5" : Qt.rgba(239, 68, 68, 0.45))
                            : (root.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.10))
                        border.width: 1

                        Shape {
                            anchors.centerIn: parent
                            width: 24
                            height: 24
                            scale: 12 / 24
                            transformOrigin: Item.Center
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                fillColor: disbandMouse.containsMouse
                                    ? (root.isLight ? "#dc2626" : "#f87171")
                                    : Theme.textSecondary(root.isLight)
                                strokeColor: "transparent"
                                PathSvg {
                                    path: "M10 3.2h4c.55 0 1 .45 1 1v1.3H9v-1.3c0-.55.45-1 1-1z M4.5 6.5h15c.55 0 1 .35 1 .8s-.45.8-1 .8h-15c-.55 0-1-.35-1-.8s.45-.8 1-.8z M6 9.5l1.1 9.8c.11.96.93 1.7 1.9 1.7h6c.97 0 1.79-.74 1.9-1.7l1.1-9.8H6zm3.8 9.5H8.3l-.6-7.8h1.5l.6 7.8zm3 0h-1.6v-7.8h1.6v7.8zm3 0h-1.5l.6-7.8h1.5l-.6 7.8z"
                                }
                            }
                        }

                        MouseArea {
                            id: disbandMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                DockFolders.deleteFolder(root.folderId);
                                root.close();
                            }
                        }
                    }

                    // Button 3: Close (✕)
                    Rectangle {
                        id: closeBtn
                        width: 26
                        height: 26
                        radius: 13
                        anchors.verticalCenter: parent.verticalCenter
                        scale: closeMouse.pressed ? 0.92 : (closeMouse.containsMouse ? 1.08 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        color: closeMouse.containsMouse
                            ? (root.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.15))
                            : (root.isLight ? Qt.rgba(0, 0, 0, 0.04) : Qt.rgba(255, 255, 255, 0.08))
                        border.color: root.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.10)
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: Theme.textSecondary(root.isLight)
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.close()
                        }
                    }
                }
            }

            // Soft Hairline Divider (fades to transparent at ends)
            Rectangle {
                width: parent.width
                height: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.15; color: root.isLight ? Qt.rgba(0, 0, 0, 0.07) : Qt.rgba(255, 255, 255, 0.08) }
                    GradientStop { position: 0.85; color: root.isLight ? Qt.rgba(0, 0, 0, 0.07) : Qt.rgba(255, 255, 255, 0.08) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // Empty State
            Item {
                width: parent.width
                height: 140
                visible: root.appList.length === 0

                Column {
                    anchors.centerIn: parent
                    spacing: 8

                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 40
                        height: 40
                        source: "image://icon/folder-open"
                        sourceSize.width: 40
                        sourceSize.height: 40
                        opacity: 0.4
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "文件夹为空"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: Theme.textSecondary(root.isLight)
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "从 Dock 栏拖拽图标放入，或点击右上角 '+' 添加应用"
                        font.pixelSize: 11
                        color: Theme.textTertiary(root.isLight)
                    }
                }
            }

            // Application Grid
            Grid {
                id: appsGrid
                visible: root.appList.length > 0
                width: parent.width
                columns: card.gridColumns
                spacing: 8

                Repeater {
                    model: root.appList
                    delegate: Item {
                        id: appCard
                        required property var modelData
                        required property int index

                        readonly property string appId: modelData
                        readonly property var entry: DockFolders.resolveAppEntry(appId)
                        readonly property string appName: entry && entry.name ? entry.name : appId
                        readonly property var iconSources: IconResolver.candidates(entry)
                        property int attempt: 0
                        readonly property string resolvedIcon: attempt < iconSources.length ? iconSources[attempt] : ""
                        readonly property string taskKey: Tasks.key(entry ? entry.id : appId)
                        readonly property int windowCount: Tasks.windowCount(taskKey)
                        readonly property bool isRunning: windowCount > 0

                        readonly property bool isPinned: {
                            for (const f of PlasmaFavorites.entries) {
                                if (f.id === appCard.appId || Tasks.key(f.id) === appCard.taskKey) return true;
                            }
                            return false;
                        }

                        readonly property var desktopActions: {
                            if (appCard.entry && appCard.entry.actions && appCard.entry.actions.length > 0) {
                                return appCard.entry.actions;
                            }
                            return [];
                        }

                        readonly property var recentList: {
                            RecentFiles.revision;
                            RecentFiles.recentMap;
                            const byKey = RecentFiles.getRecent(appCard.taskKey);
                            if (byKey && byKey.length > 0) return byKey;
                            const byAppId = RecentFiles.getRecent(appCard.appId);
                            if (byAppId && byAppId.length > 0) return byAppId;
                            if (appCard.entry && appCard.entry.name) {
                                const byName = RecentFiles.getRecent(appCard.entry.name);
                                if (byName && byName.length > 0) return byName;
                            }
                            return [];
                        }

                        width: Math.floor((appsGrid.width - (card.gridColumns - 1) * appsGrid.spacing) / card.gridColumns)
                        height: 88

                        // Hover/Active background card
                        Rectangle {
                            anchors.fill: parent
                            radius: 14
                            color: itemMouse.pressed
                                ? (root.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.12))
                                : (itemMouse.containsMouse ? (root.isLight ? Qt.rgba(0, 0, 0, 0.05) : Qt.rgba(255, 255, 255, 0.08)) : "transparent")
                            border.color: (root.activeAppMenuId === appCard.appId)
                                ? Theme.accent
                                : (itemMouse.containsMouse ? (root.isLight ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(255, 255, 255, 0.10)) : "transparent")
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 6

                            // Icon Wrapper with Spring Scale
                            Item {
                                id: iconWrapper
                                width: 46
                                height: 46
                                anchors.horizontalCenter: parent.horizontalCenter
                                scale: itemMouse.pressed ? 0.94 : (itemMouse.containsMouse ? 1.06 : 1.0)
                                Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }

                                CircleIcon {
                                    id: appIcon
                                    anchors.fill: parent
                                    source: appCard.resolvedIcon
                                    circular: root.circularIcons
                                    iconShape: root.iconShape
                                    isLight: root.isLight
                                    renderSize: 92
                                    onStatusChanged: {
                                        if (status === Image.Error && appCard.attempt < appCard.iconSources.length - 1) {
                                            appCard.attempt++;
                                        }
                                    }
                                }

                                // Running Dot with soft diffuse glow
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: -3
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 5
                                    height: 5
                                    radius: 2.5
                                    color: Theme.accent
                                    visible: appCard.isRunning

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 9
                                        height: 9
                                        radius: 4.5
                                        color: Theme.accent
                                        opacity: 0.35
                                        z: -1
                                    }
                                }
                            }

                            // App Label
                            Text {
                                text: appCard.appName
                                width: appCard.width - 8
                                horizontalAlignment: Text.AlignHCenter
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: Theme.textPrimary(root.isLight)
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }

                        // Drag handling to move out of folder
                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            property bool didDrag: false
                            property real startX: 0
                            property real startY: 0

                            onPressed: mouse => {
                                didDrag = false;
                                startX = mouse.x;
                                startY = mouse.y;
                            }

                            onPositionChanged: mouse => {
                                if (mouse.buttons & Qt.LeftButton) {
                                    const dx = mouse.x - startX;
                                    const dy = mouse.y - startY;
                                    if (Math.abs(dx) > 14 || Math.abs(dy) > 14) {
                                        didDrag = true;
                                    }
                                }
                            }

                            onClicked: mouse => {
                                if (didDrag) return;
                                if (mouse.button === Qt.LeftButton) {
                                    if (appCard.windowCount > 1) {
                                        root.close();
                                        if (root.dockRef) {
                                            root.dockRef.expandedAppKey = (root.dockRef.expandedAppKey === appCard.taskKey) ? "" : appCard.taskKey;
                                        }
                                        return;
                                    }
                                    if (appCard.isRunning) {
                                        root.close();
                                        Tasks.activate(appCard.taskKey);
                                        return;
                                    }
                                    if (appCard.entry) {
                                        appCard.entry.execute();
                                    }
                                    root.close();
                                } else if (mouse.button === Qt.RightButton) {
                                    if (root.activeAppMenuId !== appCard.appId) {
                                        RecentFiles.refresh();
                                        root.activeTargetApp = appCard;
                                        root.activeAppMenuId = appCard.appId;
                                    } else {
                                        root.activeAppMenuId = "";
                                        root.activeTargetApp = null;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ==========================================
        // VIEW 2: SEARCHABLE APP PICKER VIEW
        // ==========================================
        Column {
            id: pickerColumn
            visible: root.pickerMode
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // Picker Header Row
            Row {
                width: parent.width
                height: 30
                spacing: 8

                // Back Button (←)
                Rectangle {
                    width: 26
                    height: 26
                    radius: 13
                    anchors.verticalCenter: parent.verticalCenter
                    scale: backMouse.pressed ? 0.92 : (backMouse.containsMouse ? 1.08 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    color: backMouse.pressed
                        ? Theme.pressFill(root.isLight)
                        : (backMouse.containsMouse ? (root.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.15)) : (root.isLight ? Qt.rgba(0, 0, 0, 0.04) : Qt.rgba(255, 255, 255, 0.08)))
                    border.color: root.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.10)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "←"
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: Theme.textPrimary(root.isLight)
                    }

                    MouseArea {
                        id: backMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.pickerMode = false
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "添加应用到文件夹"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: Theme.textPrimary(root.isLight)
                }
            }

            // Search Bar Input (Glass Pill)
            Rectangle {
                width: parent.width
                height: 34
                radius: 12
                color: root.isLight ? Qt.rgba(0, 0, 0, 0.04) : Qt.rgba(255, 255, 255, 0.08)
                border.color: searchInput.activeFocus ? Theme.accent : (root.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.10))
                border.width: searchInput.activeFocus ? 1.5 : 1

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Image {
                        width: 14
                        height: 14
                        anchors.verticalCenter: parent.verticalCenter
                        source: "image://icon/system-search"
                        sourceSize.width: 14
                        sourceSize.height: 14
                        opacity: 0.6
                    }

                    TextInput {
                        id: searchInput
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 50
                        font.pixelSize: 12
                        color: Theme.textPrimary(root.isLight)
                        selectByMouse: true
                        property string placeholder: "搜索已安装应用..."

                        onTextChanged: root.searchQuery = text

                        Text {
                            anchors.fill: parent
                            text: searchInput.placeholder
                            font.pixelSize: 12
                            color: Theme.textTertiary(root.isLight)
                            visible: !searchInput.text && !searchInput.activeFocus
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "✕"
                        font.pixelSize: 11
                        color: Theme.textTertiary(root.isLight)
                        visible: searchInput.text.length > 0
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: searchInput.text = ""
                        }
                    }
                }
            }

            // Apps List
            ListView {
                id: pickerList
                width: parent.width
                height: parent.height - 88
                clip: true
                spacing: 4
                boundsBehavior: Flickable.StopAtBounds
                reuseItems: true
                cacheBuffer: 120

                model: {
                    if (!root.pickerMode) return [];
                    const q = root.searchQuery.toLowerCase().trim();
                    let all = [];
                    try {
                        if (typeof DesktopEntries !== "undefined" && DesktopEntries.applications && DesktopEntries.applications.values) {
                            all = DesktopEntries.applications.values;
                        }
                    } catch (e) {}

                    const result = [];
                    const currentInFolder = ({});
                    for (const a of root.appList) currentInFolder[a] = true;

                    for (let i = 0; i < all.length; i++) {
                        const app = all[i];
                        if (!app || app.noDisplay) continue;
                        if (currentInFolder[app.id]) continue;

                        if (q === "") {
                            result.push(app);
                        } else {
                            const name = (app.name || "").toLowerCase();
                            const id = (app.id || "").toLowerCase();
                            const comment = (app.comment || "").toLowerCase();
                            if (name.indexOf(q) >= 0 || id.indexOf(q) >= 0 || comment.indexOf(q) >= 0) {
                                result.push(app);
                            }
                        }
                    }
                    return result;
                }

                delegate: Rectangle {
                    id: rowItem
                    required property var modelData
                    required property int index

                    readonly property var entry: modelData
                    readonly property var iconSources: IconResolver.candidates(entry)
                    property int attempt: 0
                    readonly property string rowIcon: attempt < iconSources.length ? iconSources[attempt] : ""

                    width: pickerList.width
                    height: 42
                    radius: 10
                    color: rowMouse.pressed
                        ? Theme.pressFill(root.isLight)
                        : (rowMouse.containsMouse ? (root.isLight ? Qt.rgba(0, 0, 0, 0.05) : Qt.rgba(255, 255, 255, 0.08)) : "transparent")

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        Image {
                            width: 26
                            height: 26
                            anchors.verticalCenter: parent.verticalCenter
                            source: rowItem.rowIcon
                            sourceSize: Qt.size(52, 52)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            smooth: true
                            onStatusChanged: {
                                if (status === Image.Error && rowItem.attempt < rowItem.iconSources.length - 1) {
                                    rowItem.attempt++;
                                }
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 80

                            Text {
                                text: rowItem.entry.name || rowItem.entry.id
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: Theme.textPrimary(root.isLight)
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Text {
                                text: rowItem.entry.comment || rowItem.entry.id
                                font.pixelSize: 10
                                color: Theme.textTertiary(root.isLight)
                                elide: Text.ElideRight
                                width: parent.width
                                visible: text !== ""
                            }
                        }

                        // Add pill button
                        Rectangle {
                            width: 22
                            height: 22
                            radius: 11
                            anchors.verticalCenter: parent.verticalCenter
                            color: rowMouse.containsMouse ? Theme.accent : (root.isLight ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(255, 255, 255, 0.10))

                            Text {
                                anchors.centerIn: parent
                                text: "+"
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                color: rowMouse.containsMouse ? "#ffffff" : Theme.textSecondary(root.isLight)
                            }
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            DockFolders.addAppToFolder(root.folderId, rowItem.entry.id);
                        }
                    }
                }
            }
        }
    }

    // Singleton App Context Menu inside Folder (instantiated once, saving significant memory)
    PopupWindow {
        id: appItemMenu
        visible: root.activeAppMenuId !== "" && root.activeTargetApp !== null
        anchor.item: root.activeTargetApp
        anchor.edges: root.position === "bottom" ? Edges.Top : Edges.Bottom
        anchor.gravity: anchor.edges
        anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.SlideY | PopupAdjustment.FlipY
        color: "transparent"
        grabFocus: true
        onClosed: {
            root.activeAppMenuId = "";
            root.activeTargetApp = null;
        }

        readonly property var targetApp: root.activeTargetApp

        implicitWidth: menuCard.width + 16
        implicitHeight: menuCard.height + 16

        BackgroundEffect.blurRegion: Region {
            item: menuCard
            radius: menuCard.radius
        }

        RectangularShadow {
            anchors.fill: menuCard
            radius: menuCard.radius
            color: Theme.shadow(root.isLight)
            blur: 20
            spread: 0
            offset: Qt.vector2d(0, 4)
            z: -1
        }

        Rectangle {
            id: menuCard
            width: 280
            height: menuCol.implicitHeight + 16
            radius: 10
            color: Theme.surface(root.isLight)
            border.color: Theme.surfaceBorder(root.isLight)
            border.width: 1

            Column {
                id: menuCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 8
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 6

                // Header: App Icon, Name, and Status
                Rectangle {
                    width: parent.width
                    height: 44
                    color: "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 4
                        anchors.rightMargin: 4
                        spacing: 10

                        Item {
                            width: 32
                            height: 32
                            anchors.verticalCenter: parent.verticalCenter

                            CircleIcon {
                                anchors.fill: parent
                                source: appItemMenu.targetApp ? appItemMenu.targetApp.resolvedIcon : ""
                                circular: root.circularIcons
                                iconShape: root.iconShape
                                isLight: root.isLight
                                renderSize: 64
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 44
                            spacing: 2

                            Text {
                                width: parent.width
                                text: appItemMenu.targetApp ? appItemMenu.targetApp.appName : ""
                                color: Theme.textPrimary(root.isLight)
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            Text {
                                text: appItemMenu.targetApp
                                    ? (appItemMenu.targetApp.isRunning
                                        ? (appItemMenu.targetApp.windowCount > 1 ? ("运行中 · " + appItemMenu.targetApp.windowCount + " 个窗口") : "正在运行")
                                        : "未运行")
                                    : ""
                                color: Theme.textSecondary(root.isLight)
                                font.pixelSize: 11
                            }
                        }
                    }
                }

                // Section: 最近打开 (Recent Documents)
                Column {
                    width: parent.width
                    spacing: 3
                    visible: appItemMenu.targetApp ? (appItemMenu.targetApp.recentList.length > 0) : false

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.separator(root.isLight)
                    }

                    Item {
                        width: parent.width
                        height: 20

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            text: "最近打开"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: Theme.textSecondary(root.isLight)
                        }
                    }

                    Repeater {
                        model: (appItemMenu.targetApp && appItemMenu.targetApp.recentList) ? appItemMenu.targetApp.recentList.slice(0, 6) : []
                        delegate: Rectangle {
                            id: recentItemRow
                            width: parent.width
                            height: 36
                            radius: 6
                            color: rArea.pressed ? Qt.darker(Theme.accent, 1.12) : (rArea.containsMouse ? Theme.accent : "transparent")
                            Behavior on color { ColorAnimation { duration: 100 } }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                Image {
                                    width: 18; height: 18
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: {
                                        if (modelData.isDir) return "image://icon/folder";
                                        const p = String(modelData.path).toLowerCase();
                                        if (p.endsWith(".pdf")) return "image://icon/application-pdf";
                                        if (p.endsWith(".png") || p.endsWith(".jpg") || p.endsWith(".jpeg") || p.endsWith(".svg") || p.endsWith(".webp")) return "image://icon/image-x-generic";
                                        if (p.endsWith(".md") || p.endsWith(".txt")) return "image://icon/text-plain";
                                        if (p.endsWith(".ts") || p.endsWith(".js") || p.endsWith(".json") || p.endsWith(".qml") || p.endsWith(".py") || p.endsWith(".cpp") || p.endsWith(".c") || p.endsWith(".h")) return "image://icon/text-x-script";
                                        return "image://icon/text-x-generic";
                                    }
                                    sourceSize.width: 18
                                    sourceSize.height: 18
                                    fillMode: Image.PreserveAspectFit
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 44
                                    spacing: 1

                                    Text {
                                        width: parent.width
                                        text: modelData.title
                                        color: rArea.containsMouse ? "#ffffff" : Theme.textPrimary(root.isLight)
                                        font.pixelSize: 12
                                        elide: Text.ElideMiddle
                                    }

                                    Text {
                                        width: parent.width
                                        text: modelData.displayPath
                                        color: rArea.containsMouse ? Qt.rgba(1, 1, 1, 0.75) : Theme.textSecondary(root.isLight)
                                        font.pixelSize: 10
                                        elide: Text.ElideMiddle
                                    }
                                }
                            }

                            MouseArea {
                                id: rArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    if (appItemMenu.targetApp && appItemMenu.targetApp.entry) {
                                        RecentFiles.openFile(appItemMenu.targetApp.entry, modelData.path);
                                    }
                                    root.close();
                                }
                            }
                        }
                    }
                }

                // Section: 快捷操作 (Desktop Actions)
                Column {
                    width: parent.width
                    spacing: 3
                    visible: appItemMenu.targetApp ? (appItemMenu.targetApp.desktopActions.length > 0) : false

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.separator(root.isLight)
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
                            font.weight: Font.DemiBold
                            color: Theme.textSecondary(root.isLight)
                        }
                    }

                    Repeater {
                        model: (appItemMenu.targetApp && appItemMenu.targetApp.desktopActions) ? appItemMenu.targetApp.desktopActions.slice(0, 5) : []
                        delegate: Rectangle {
                            width: parent.width
                            height: 30
                            radius: 6
                            color: dActM.pressed ? Qt.darker(Theme.accent, 1.12) : (dActM.containsMouse ? Theme.accent : "transparent")
                            Behavior on color { ColorAnimation { duration: 100 } }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                Image {
                                    width: 15; height: 15
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: {
                                        const ic = modelData.icon || "application-x-executable";
                                        return (ic.startsWith("/") || ic.indexOf("://") >= 0) ? ic : ("image://icon/" + ic);
                                    }
                                    sourceSize.width: 16
                                    sourceSize.height: 16
                                }

                                Text {
                                    width: parent.width - 24
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.name
                                    color: dActM.containsMouse ? "#ffffff" : Theme.textPrimary(root.isLight)
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: dActM
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    modelData.execute();
                                    root.close();
                                }
                            }
                        }
                    }
                }

                // Section: 窗口与运行控制
                Column {
                    width: parent.width
                    spacing: 3

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.separator(root.isLight)
                    }

                    // New window (if running)
                    Rectangle {
                        width: parent.width
                        height: 30
                        radius: 6
                        visible: appItemMenu.targetApp ? appItemMenu.targetApp.isRunning : false
                        color: newInstM.pressed ? Qt.darker(Theme.accent, 1.12) : (newInstM.containsMouse ? Theme.accent : "transparent")
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            spacing: 8
                            Image {
                                width: 14; height: 14
                                anchors.verticalCenter: parent.verticalCenter
                                source: "image://icon/window-new"
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "新建窗口"
                                color: newInstM.containsMouse ? "#ffffff" : Theme.textPrimary(root.isLight)
                                font.pixelSize: 12
                            }
                        }
                        MouseArea {
                            id: newInstM
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (appItemMenu.targetApp) {
                                    Tasks.launchNew(appItemMenu.targetApp.taskKey);
                                }
                                root.close();
                            }
                        }
                    }

                    // Raise / switch window (if running)
                    Rectangle {
                        width: parent.width
                        height: 30
                        radius: 6
                        visible: appItemMenu.targetApp ? appItemMenu.targetApp.isRunning : false
                        color: raiseM.pressed ? Qt.darker(Theme.accent, 1.12) : (raiseM.containsMouse ? Theme.accent : "transparent")
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            spacing: 8
                            Image {
                                width: 14; height: 14
                                anchors.verticalCenter: parent.verticalCenter
                                source: "image://icon/go-top"
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: (appItemMenu.targetApp && appItemMenu.targetApp.windowCount > 1) ? "切换下一个窗口" : "置顶应用窗口"
                                color: raiseM.containsMouse ? "#ffffff" : Theme.textPrimary(root.isLight)
                                font.pixelSize: 12
                            }
                        }
                        MouseArea {
                            id: raiseM
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (appItemMenu.targetApp) {
                                    Tasks.activate(appItemMenu.targetApp.taskKey, false);
                                }
                                root.close();
                            }
                        }
                    }

                    // Launch app (if NOT running)
                    Rectangle {
                        width: parent.width
                        height: 30
                        radius: 6
                        visible: appItemMenu.targetApp ? !appItemMenu.targetApp.isRunning : false
                        color: launchM.pressed ? Qt.darker(Theme.accent, 1.12) : (launchM.containsMouse ? Theme.accent : "transparent")
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            spacing: 8
                            Image {
                                width: 14; height: 14
                                anchors.verticalCenter: parent.verticalCenter
                                source: "image://icon/media-playback-start"
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "启动应用"
                                color: launchM.containsMouse ? "#ffffff" : Theme.textPrimary(root.isLight)
                                font.pixelSize: 12
                            }
                        }
                        MouseArea {
                            id: launchM
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (appItemMenu.targetApp && appItemMenu.targetApp.entry) {
                                    appItemMenu.targetApp.entry.execute();
                                }
                                root.close();
                            }
                        }
                    }

                    // Pin / Unpin
                    Rectangle {
                        width: parent.width
                        height: 30
                        radius: 6
                        color: pinM.pressed ? Qt.darker(Theme.accent, 1.12) : (pinM.containsMouse ? Theme.accent : "transparent")
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            spacing: 8
                            Image {
                                width: 14; height: 14
                                anchors.verticalCenter: parent.verticalCenter
                                source: (appItemMenu.targetApp && appItemMenu.targetApp.isPinned) ? "image://icon/list-remove" : "image://icon/bookmark-new"
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: (appItemMenu.targetApp && appItemMenu.targetApp.isPinned) ? "从 Dock 移除" : "固定到 Dock"
                                color: pinM.containsMouse ? "#ffffff" : Theme.textPrimary(root.isLight)
                                font.pixelSize: 12
                            }
                        }
                        MouseArea {
                            id: pinM
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (appItemMenu.targetApp) {
                                    if (appItemMenu.targetApp.isPinned) root.unpinApp(appItemMenu.targetApp.appId);
                                    else root.pinApp(appItemMenu.targetApp.appId);
                                }
                            }
                        }
                    }

                    // Move out to Dock
                    Rectangle {
                        width: parent.width
                        height: 30
                        radius: 6
                        color: moveOutM.pressed ? Qt.darker(Theme.accent, 1.12) : (moveOutM.containsMouse ? Theme.accent : "transparent")
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            spacing: 8
                            Image {
                                width: 14; height: 14
                                anchors.verticalCenter: parent.verticalCenter
                                source: "image://icon/go-up"
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "移出到 Dock"
                                color: moveOutM.containsMouse ? "#ffffff" : Theme.textPrimary(root.isLight)
                                font.pixelSize: 12
                            }
                        }
                        MouseArea {
                            id: moveOutM
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (appItemMenu.targetApp) {
                                    DockFolders.removeAppFromFolder(root.folderId, appItemMenu.targetApp.appId);
                                }
                                root.activeAppMenuId = "";
                                root.activeTargetApp = null;
                            }
                        }
                    }

                    // Move to other existing folders
                    Repeater {
                        model: typeof DockFolders !== "undefined" ? DockFolders.folders.filter(f => f.id !== root.folderId) : []
                        delegate: Rectangle {
                            width: parent.width
                            height: 30
                            radius: 6
                            color: otherFM.pressed ? Qt.darker(Theme.accent, 1.12) : (otherFM.containsMouse ? Theme.accent : "transparent")
                            Behavior on color { ColorAnimation { duration: 100 } }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                spacing: 8
                                Image {
                                    width: 14; height: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: "image://icon/folder"
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "移入「" + (modelData.name || "文件夹") + "」"
                                    color: otherFM.containsMouse ? "#ffffff" : Theme.textPrimary(root.isLight)
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                    width: parent.width - 32
                                }
                            }
                            MouseArea {
                                id: otherFM
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    if (appItemMenu.targetApp) {
                                        DockFolders.removeAppFromFolder(root.folderId, appItemMenu.targetApp.appId);
                                        DockFolders.addAppToFolder(modelData.id, appItemMenu.targetApp.appId);
                                    }
                                    root.activeAppMenuId = "";
                                    root.activeTargetApp = null;
                                }
                            }
                        }
                    }

                    // Remove from folder (Destructive)
                    Rectangle {
                        width: parent.width
                        height: 30
                        radius: 6
                        color: deleteM.pressed ? Qt.rgba(1, 0.2, 0.2, 0.25) : (deleteM.containsMouse ? (root.isLight ? "#fee2e2" : Qt.rgba(239, 68, 68, 0.22)) : "transparent")
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            spacing: 8
                            Image {
                                width: 14; height: 14
                                anchors.verticalCenter: parent.verticalCenter
                                source: "image://icon/list-remove"
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "从文件夹移除"
                                color: deleteM.containsMouse ? (root.isLight ? "#dc2626" : "#f87171") : Theme.destructive
                                font.pixelSize: 12
                            }
                        }
                        MouseArea {
                            id: deleteM
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (appItemMenu.targetApp) {
                                    const f = DockFolders.getFolder(root.folderId);
                                    if (f) {
                                        const nextApps = f.apps.filter(a => a !== appItemMenu.targetApp.appId);
                                        f.apps = nextApps;
                                        DockFolders.save();
                                        DockFolders.revision++;
                                    }
                                }
                                root.activeAppMenuId = "";
                                root.activeTargetApp = null;
                            }
                        }
                    }
                }
            }
        }
    }
}
