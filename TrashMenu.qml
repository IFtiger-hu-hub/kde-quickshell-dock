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

    grabFocus: true
    onClosed: root.close()

    property bool confirming: false
    readonly property bool isLight: dock.isLight

    implicitWidth: card.width
    implicitHeight: card.height
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

    BackgroundEffect.blurRegion: Region { item: card; radius: card.radius }

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
        width: 200
        height: root.confirming ? (confirmCol.implicitHeight + 20) : (menuCol.implicitHeight + 12)
        radius: 10
        color: Theme.surface(root.isLight)
        border.color: Theme.surfaceBorder(root.isLight)
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
                color: Theme.textPrimary(root.isLight)
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            Text {
                width: parent.width
                text: (Trash.count > 0 ? ("共 " + Trash.count + " 个项目，") : "") + "此操作无法撤销。"
                wrapMode: Text.WordWrap
                color: Theme.textSecondary(root.isLight)
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
        signal activated()

        readonly property bool highlighted: rowMouse.containsMouse && enabled

        width: parent ? parent.width : 0
        height: 28
        radius: 6
        color: highlighted ? Theme.accent : "transparent"

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 10
            text: row.text
            color: row.highlighted ? "#ffffff"
                 : row.enabled ? Theme.textPrimary(root.isLight)
                 : Theme.textTertiary(root.isLight)
            font.pixelSize: 13
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: row.enabled
            onClicked: row.activated()
        }
    }

    component PillButton: Rectangle {
        id: pill
        property string text
        property bool destructive: false
        signal activated()

        width: Math.max(64, pillLabel.implicitWidth + 24)
        height: 24
        radius: 6
        color: destructive
            ? (pillMouse.pressed ? Qt.darker(Theme.destructive, 1.15) : Theme.destructive)
            : (pillMouse.pressed ? Theme.pressFill(root.isLight) : Theme.controlFill(root.isLight))

        Text {
            id: pillLabel
            anchors.centerIn: parent
            text: pill.text
            color: pill.destructive ? "#ffffff" : Theme.textPrimary(root.isLight)
            font.pixelSize: 12
        }

        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: pill.activated()
        }
    }
}
