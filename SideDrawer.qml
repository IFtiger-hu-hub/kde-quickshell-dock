import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Effects

// Slide-out Drawer Panel anchored to the right side of the screen.
// Features macOS-style Liquid Glass blur, slide-in animation, quick utilities,
// scratchpad notes, and a dedicated slot for future custom widgets.
PanelWindow {
    id: root

    property bool isLight: true
    signal closeRequested()

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell-dock-drawer"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    color: "transparent"

    property real slideOffset: 380

    ParallelAnimation {
        id: openAnim
        NumberAnimation {
            target: root
            property: "slideOffset"
            from: 380
            to: 0
            duration: 250
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: backdrop
            property: "opacity"
            from: 0
            to: root.isLight ? 0.18 : 0.40
            duration: 250
            easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: closeAnim
        NumberAnimation {
            target: root
            property: "slideOffset"
            from: root.slideOffset
            to: 380
            duration: 220
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: backdrop
            property: "opacity"
            from: backdrop.opacity
            to: 0
            duration: 220
            easing.type: Easing.OutCubic
        }
        onFinished: {
            root.closeRequested();
        }
    }

    Component.onCompleted: {
        openAnim.start();
    }

    function requestClose() {
        if (closeAnim.running) return;
        openAnim.stop();
        closeAnim.start();
    }

    // Escape key closes the drawer
    Item {
        focus: true
        Keys.onEscapePressed: root.requestClose()
        Component.onCompleted: forceActiveFocus()
    }

    // Process runner for quick actions
    Process {
        id: cmdProc
    }

    function runCmd(args) {
        cmdProc.command = args;
        cmdProc.startDetached();
    }

    // Dimmed Backdrop (click outside to dismiss)
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: "#000000"
        opacity: 0

        MouseArea {
            anchors.fill: parent
            onClicked: root.requestClose()
        }
    }

    // Hardware-accelerated blur behind drawer card
    BackgroundEffect.blurRegion: Region {
        item: drawerCard
        radius: drawerCard.radius
    }

    // Ambient Drop Shadow on the left edge
    RectangularShadow {
        anchors.fill: drawerCard
        radius: drawerCard.radius
        color: root.isLight ? "#25000000" : "#70000000"
        blur: 28
        spread: 0
        offset: Qt.vector2d(-6, 0)
        z: -1
    }

    // Sliding Drawer Card
    Rectangle {
        id: drawerCard
        width: 380
        height: parent.height
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.rightMargin: -root.slideOffset

        color: root.isLight ? Qt.rgba(0.97, 0.97, 0.99, 0.90) : Qt.rgba(0.14, 0.14, 0.17, 0.92)
        border.color: root.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.12)
        border.width: 1

        // Consume mouse clicks so they don't propagate to the backdrop
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        Column {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 16

            // Header Row
            Item {
                width: parent.width
                height: 38

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Rectangle {
                        width: 34
                        height: 34
                        radius: 10
                        color: root.isLight ? Qt.rgba(0, 0, 0, 0.05) : Qt.rgba(255, 255, 255, 0.08)
                        anchors.verticalCenter: parent.verticalCenter

                        Image {
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            source: "image://icon/sidebar-expand-right"
                            fillMode: Image.PreserveAspectFit
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            text: "侧边抽屉"
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            color: Theme.textPrimary(root.isLight)
                        }

                        Text {
                            text: "扩展功能与工具中心"
                            font.pixelSize: 11
                            color: Theme.textTertiary(root.isLight)
                        }
                    }
                }

                // Close Button (✕)
                Rectangle {
                    id: closeBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    radius: 14
                    color: closeMouse.pressed
                        ? Theme.pressFill(root.isLight)
                        : (closeMouse.containsMouse ? Theme.hoverFill(root.isLight) : "transparent")

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: Theme.textSecondary(root.isLight)
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.requestClose()
                    }
                }
            }

            // Divider line
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.separator(root.isLight)
            }

            // Scrollable Content
            Flickable {
                id: scrollContent
                width: parent.width
                height: parent.height - 70
                contentWidth: width
                contentHeight: contentCol.implicitHeight + 20
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: contentCol
                    width: parent.width
                    spacing: 14

                    // Section 1: Welcome & Status Card
                    Rectangle {
                        width: parent.width
                        height: welcomeCol.implicitHeight + 24
                        radius: 12
                        color: root.isLight ? Qt.rgba(0.2, 0.4, 0.9, 0.08) : Qt.rgba(0.3, 0.5, 1.0, 0.12)
                        border.color: root.isLight ? Qt.rgba(0.2, 0.4, 0.9, 0.18) : Qt.rgba(0.3, 0.5, 1.0, 0.22)
                        border.width: 1

                        Column {
                            id: welcomeCol
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 12
                            spacing: 5

                            Row {
                                spacing: 6
                                Text {
                                    text: "✨"
                                    font.pixelSize: 13
                                }
                                Text {
                                    text: "抽屉面板已启用"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    color: Theme.textPrimary(root.isLight)
                                }
                            }

                            Text {
                                width: parent.width
                                wrapMode: Text.Wrap
                                text: "右侧滑出抽屉已就绪。你可以直接点击右上角 ✕、按 ESC 或点击遮罩空白处随时关闭。"
                                font.pixelSize: 11
                                color: Theme.textSecondary(root.isLight)
                                lineHeight: 1.3
                            }
                        }
                    }

                    // Section 2: Quick Tools (快捷工具)
                    Column {
                        width: parent.width
                        spacing: 8

                        Text {
                            text: "快捷操作"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: Theme.textSecondary(root.isLight)
                        }

                        Grid {
                            width: parent.width
                            columns: 2
                            spacing: 8

                            // Screenshot
                            Rectangle {
                                width: Math.floor((parent.width - 8) / 2)
                                height: 42
                                radius: 10
                                color: shotMouse.pressed ? Theme.pressFill(root.isLight) : (shotMouse.containsMouse ? Theme.hoverFill(root.isLight) : (root.isLight ? Qt.rgba(0, 0, 0, 0.03) : Qt.rgba(255, 255, 255, 0.05)))
                                border.color: root.isLight ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(255, 255, 255, 0.08)
                                border.width: 1

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    Image {
                                        width: 16; height: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: "image://icon/spectacle"
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "区域截屏"
                                        font.pixelSize: 12
                                        color: Theme.textPrimary(root.isLight)
                                    }
                                }

                                MouseArea {
                                    id: shotMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.requestClose();
                                        root.runCmd(["spectacle", "-r"]);
                                    }
                                }
                            }

                            // Terminal
                            Rectangle {
                                width: Math.floor((parent.width - 8) / 2)
                                height: 42
                                radius: 10
                                color: termMouse.pressed ? Theme.pressFill(root.isLight) : (termMouse.containsMouse ? Theme.hoverFill(root.isLight) : (root.isLight ? Qt.rgba(0, 0, 0, 0.03) : Qt.rgba(255, 255, 255, 0.05)))
                                border.color: root.isLight ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(255, 255, 255, 0.08)
                                border.width: 1

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    Image {
                                        width: 16; height: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: "image://icon/utilities-terminal"
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "打开终端"
                                        font.pixelSize: 12
                                        color: Theme.textPrimary(root.isLight)
                                    }
                                }

                                MouseArea {
                                    id: termMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.requestClose();
                                        root.runCmd(["konsole"]);
                                    }
                                }
                            }

                            // System Monitor
                            Rectangle {
                                width: Math.floor((parent.width - 8) / 2)
                                height: 42
                                radius: 10
                                color: monMouse.pressed ? Theme.pressFill(root.isLight) : (monMouse.containsMouse ? Theme.hoverFill(root.isLight) : (root.isLight ? Qt.rgba(0, 0, 0, 0.03) : Qt.rgba(255, 255, 255, 0.05)))
                                border.color: root.isLight ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(255, 255, 255, 0.08)
                                border.width: 1

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    Image {
                                        width: 16; height: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: "image://icon/plasma-systemmonitor"
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "系统监视器"
                                        font.pixelSize: 12
                                        color: Theme.textPrimary(root.isLight)
                                    }
                                }

                                MouseArea {
                                    id: monMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.requestClose();
                                        root.runCmd(["plasma-systemmonitor"]);
                                    }
                                }
                            }

                            // Lock Screen
                            Rectangle {
                                width: Math.floor((parent.width - 8) / 2)
                                height: 42
                                radius: 10
                                color: lockMouse.pressed ? Theme.pressFill(root.isLight) : (lockMouse.containsMouse ? Theme.hoverFill(root.isLight) : (root.isLight ? Qt.rgba(0, 0, 0, 0.03) : Qt.rgba(255, 255, 255, 0.05)))
                                border.color: root.isLight ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(255, 255, 255, 0.08)
                                border.width: 1

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    Image {
                                        width: 16; height: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: "image://icon/system-lock-screen"
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "锁定屏幕"
                                        font.pixelSize: 12
                                        color: Theme.textPrimary(root.isLight)
                                    }
                                }

                                MouseArea {
                                    id: lockMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.requestClose();
                                        root.runCmd(["loginctl", "lock-session"]);
                                    }
                                }
                            }
                        }
                    }

                    // Section 3: Quick Notes / Scratchpad (快捷便签)
                    Column {
                        width: parent.width
                        spacing: 8

                        Text {
                            text: "临时便签"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: Theme.textSecondary(root.isLight)
                        }

                        Rectangle {
                            width: parent.width
                            height: 120
                            radius: 12
                            color: root.isLight ? Qt.rgba(0, 0, 0, 0.03) : Qt.rgba(255, 255, 255, 0.05)
                            border.color: noteEdit.activeFocus ? Theme.accent : (root.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.10))
                            border.width: 1

                            Flickable {
                                anchors.fill: parent
                                anchors.margins: 10
                                contentWidth: width
                                contentHeight: noteEdit.paintedHeight
                                clip: true

                                TextEdit {
                                    id: noteEdit
                                    width: parent.width
                                    wrapMode: TextEdit.Wrap
                                    font.pixelSize: 12
                                    color: Theme.textPrimary(root.isLight)
                                    selectByMouse: true

                                    Text {
                                        anchors.fill: parent
                                        visible: !noteEdit.text && !noteEdit.activeFocus
                                        text: "记录临时想法、备忘或暂存文本..."
                                        font.pixelSize: 12
                                        color: Theme.textTertiary(root.isLight)
                                    }
                                }
                            }
                        }
                    }

                    // =========================================================================
                    // Section 4: 开发者自定义功能扩展槽位 (后续可以在此处添加你的新功能)
                    // =========================================================================
                    Column {
                        width: parent.width
                        spacing: 8

                        Text {
                            text: "功能扩展槽位"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: Theme.textSecondary(root.isLight)
                        }

                        Rectangle {
                            width: parent.width
                            height: 80
                            radius: 12
                            color: "transparent"
                            border.color: root.isLight ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(255, 255, 255, 0.15)
                            border.width: 1

                            Column {
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "➕ 预留功能卡片区"
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    color: Theme.textSecondary(root.isLight)
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "可在 SideDrawer.qml 中直接嵌入自定义组件"
                                    font.pixelSize: 10
                                    color: Theme.textTertiary(root.isLight)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
