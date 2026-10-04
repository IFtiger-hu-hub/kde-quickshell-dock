import Quickshell
import Quickshell.Wayland
import QtQuick

// Right-click menu for the Trash cell. Emptying is permanent, so it asks first:
// the "清空废纸篓" row turns the menu into an inline confirmation showing how many
// items will go, and nothing is deleted until that is confirmed.
PopupWindow {
    id: root

    required property var dock

    anchor.edges: dock.dockPosition === "top" ? Edges.Bottom
                : dock.dockPosition === "left" ? Edges.Right
                : dock.dockPosition === "right" ? Edges.Left
                : Edges.Top
    anchor.gravity: anchor.edges
    anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.SlideY

    property bool confirming: false
    readonly property bool isLight: dock.isLight

    implicitWidth: confirming ? 220 : 170
    implicitHeight: card.implicitHeight
    color: "transparent"
    visible: false

    function open() {
        confirming = false;
        Trash.refresh();
        visible = true;
    }

    function close() {
        visible = false;
        confirming = false;
    }

    BackgroundEffect.blurRegion: Region { item: card }

    // Escape cancels the confirmation first, then closes.
    Item {
        anchors.fill: parent
        focus: root.visible
        Keys.onEscapePressed: {
            if (root.confirming) root.confirming = false;
            else root.close();
        }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        implicitHeight: root.confirming ? (confirmCol.implicitHeight + 20) : (menuCol.implicitHeight + 12)
        radius: 12
        color: root.isLight ? Qt.rgba(0.97, 0.98, 1.0, 0.85) : "#f01c202a"
        border.color: root.isLight ? Qt.rgba(0, 0, 0, 0.10) : "#30ffffff"
        border.width: 1

        // ---- normal menu ----
        Column {
            id: menuCol
            visible: !root.confirming
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 6
            spacing: 4

            MenuRow {
                text: "打开废纸篓"
                onActivated: {
                    root.close();
                    Trash.open();
                }
            }

            MenuRow {
                text: Trash.empty ? "废纸篓是空的" : "清空废纸篓…"
                destructive: !Trash.empty
                enabled: !Trash.empty && !Trash.busy
                onActivated: root.confirming = true
            }
        }

        // ---- confirmation ----
        Column {
            id: confirmCol
            visible: root.confirming
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10
            spacing: 8

            Text {
                width: parent.width
                text: "确定要永久删除废纸篓中的项目吗？"
                wrapMode: Text.WordWrap
                color: root.isLight ? "#0f172a" : "#ffffff"
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            Text {
                width: parent.width
                text: (Trash.count > 0 ? ("共 " + Trash.count + " 个项目，") : "") + "此操作无法撤销。"
                wrapMode: Text.WordWrap
                color: root.isLight ? "#475569" : "#94a3b8"
                font.pixelSize: 11
            }

            Row {
                anchors.right: parent.right
                spacing: 6

                PillButton {
                    text: "取消"
                    onActivated: root.confirming = false
                }
                PillButton {
                    text: "清空"
                    destructive: true
                    onActivated: {
                        Trash.emptyTrash();
                        root.close();
                    }
                }
            }
        }
    }

    component MenuRow: Rectangle {
        id: row
        property string text
        property bool destructive: false
        signal activated()

        width: parent ? parent.width : 0
        height: 34
        radius: 8
        opacity: enabled ? 1 : 0.5
        color: !rowMouse.containsMouse || !enabled ? "transparent"
             : destructive ? "#25ef4444"
             : (root.isLight ? Qt.rgba(0, 0, 0, 0.06) : "#20ffffff")

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 10
            text: row.text
            color: row.destructive ? "#ef4444" : (root.isLight ? "#0f172a" : "#ffffff")
            font.pixelSize: 12
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: row.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: row.activated()
        }
    }

    component PillButton: Rectangle {
        id: pill
        property string text
        property bool destructive: false
        signal activated()

        width: pillLabel.implicitWidth + 24
        height: 26
        radius: 13
        color: destructive
            ? (pillMouse.containsMouse ? "#dc2626" : "#ef4444")
            : (pillMouse.containsMouse
                ? (root.isLight ? Qt.rgba(0, 0, 0, 0.12) : "#30ffffff")
                : (root.isLight ? Qt.rgba(0, 0, 0, 0.06) : "#18ffffff"))

        Text {
            id: pillLabel
            anchors.centerIn: parent
            text: pill.text
            color: pill.destructive ? "#ffffff" : (root.isLight ? "#0f172a" : "#ffffff")
            font.pixelSize: 12
            font.weight: Font.Medium
        }

        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.activated()
        }
    }
}
