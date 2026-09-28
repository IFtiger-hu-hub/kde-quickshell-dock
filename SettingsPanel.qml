import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

PopupWindow {
    id: root

    property string activeScreen: ""
    property string selectedScreen: {
        if (activeScreen !== "") return activeScreen;
        const screens = Quickshell.screens;
        return (screens && screens.length > 0) ? screens[0].name : "";
    }

    readonly property string panelPosition: Config.getVal(activeScreen, "position")

    anchor.edges: panelPosition === "top" ? Edges.Bottom
                : panelPosition === "left" ? Edges.Right
                : panelPosition === "right" ? Edges.Left
                : Edges.Top
    anchor.gravity: anchor.edges
    anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.SlideY

    implicitWidth: 520 + (panelPosition === "left" || panelPosition === "right" ? 20 : 0)
    implicitHeight: 590 + (panelPosition === "top" || panelPosition === "bottom" ? 20 : 0)
    color: "transparent"

    // Hardware-accelerated Gaussian Blur behind SettingsPanel via KWin
    BackgroundEffect.blurRegion: Region {
        item: card
    }

    // Ambient diffuse drop shadow
    RectangularShadow {
        id: cardShadow
        anchors.fill: card
        radius: card.radius
        color: root.isLight ? "#30000000" : "#65000000"
        blur: 22
        spread: 0
        z: -1
    }

    property int currentTab: 0

    function getVal(key) {
        Config.revision;
        root.selectedScreen;
        if (Config.perScreenConfig && root.selectedScreen !== "") {
            return Config.getVal(root.selectedScreen, key);
        }
        return Config[key];
    }

    function setVal(key, val) {
        if (Config.perScreenConfig && root.selectedScreen !== "") {
            Config.setScreenVal(root.selectedScreen, key, val);
        } else {
            Config.setVal(key, val);
        }
    }

    // Dynamic Luminance & Theme Colors
    readonly property bool isLight: {
        Config.revision;
        const bg = root.getVal("backgroundColor");
        if (!bg) return false;
        const c = Qt.color(bg);
        return (0.299 * c.r + 0.587 * c.g + 0.114 * c.b) > 0.5;
    }

    // Design Tokens (macOS Frosted Glass & Bento Card System)
    readonly property color cCardBg: isLight ? Qt.rgba(0.97, 0.98, 1.0, 0.93) : Qt.rgba(0.12, 0.14, 0.19, 0.92)
    readonly property color cCardBorder: isLight ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.13)
    readonly property color cGroupBg: isLight ? Qt.rgba(0, 0, 0, 0.035) : Qt.rgba(1, 1, 1, 0.045)
    readonly property color cGroupBorder: isLight ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(1, 1, 1, 0.07)
    readonly property color cDivider: isLight ? Qt.rgba(0, 0, 0, 0.05) : Qt.rgba(1, 1, 1, 0.06)

    readonly property color cTextPrimary: isLight ? "#0f172a" : "#f8fafc"
    readonly property color cTextSecondary: isLight ? "#64748b" : "#94a3b8"
    readonly property color cTextMuted: isLight ? "#94a3b8" : "#64748b"

    readonly property color cAccent: isLight ? "#0284c7" : "#3b82f6"
    readonly property color cAccentHover: isLight ? "#0369a1" : "#60a5fa"
    readonly property color cAccentBg: isLight ? Qt.rgba(2, 132, 199, 0.12) : Qt.rgba(59, 130, 246, 0.20)
    readonly property color cAccentBorder: isLight ? Qt.rgba(2, 132, 199, 0.35) : Qt.rgba(59, 130, 246, 0.40)

    readonly property color cChipBg: isLight ? Qt.rgba(0, 0, 0, 0.05) : Qt.rgba(1, 1, 1, 0.07)
    readonly property color cChipHover: isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.13)
    readonly property color cChipBorder: isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.10)
    readonly property color cChipText: isLight ? "#334155" : "#cbd5e1"

    // Component for a clean Slider Row with real-time thumb tracking and debounced commit
    component SliderRow: Item {
        id: sr
        property string title: ""
        property string desc: ""
        property real min: 0
        property real max: 100
        property real step: 1
        property real value: 0
        property string unit: ""
        signal modified(real val)

        property real localVal: value
        onValueChanged: {
            if (!dragArea.pressed && !debounceTimer.running) {
                localVal = value;
            }
        }

        Timer {
            id: debounceTimer
            interval: 65
            repeat: false
            onTriggered: {
                if (sr.localVal !== sr.value) {
                    sr.modified(sr.localVal);
                }
            }
        }

        function commit() {
            debounceTimer.stop();
            if (sr.localVal !== sr.value) {
                sr.modified(sr.localVal);
            }
        }

        width: parent ? parent.width : 400
        height: 54

        Column {
            anchors.left: parent.left
            anchors.right: sliderBox.left
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                text: sr.title
                color: root.cTextPrimary
                font.pixelSize: 13
                font.weight: Font.Medium
            }
            Text {
                text: sr.desc
                color: root.cTextSecondary
                font.pixelSize: 11
                visible: text !== ""
            }
        }

        Item {
            id: sliderBox
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 176
            height: 28

            readonly property real range: sr.max - sr.min
            readonly property real normalized: range > 0 ? Math.max(0, Math.min(1, (sr.localVal - sr.min) / range)) : 0

            function applyMouse(mouseX) {
                const trackW = width - 52;
                const ratio = Math.max(0, Math.min(1, mouseX / trackW));
                let raw = sr.min + ratio * range;
                if (sr.step > 0) {
                    raw = Math.round(raw / sr.step) * sr.step;
                }
                raw = Math.max(sr.min, Math.min(sr.max, raw));
                sr.localVal = raw;
                debounceTimer.restart();
            }

            Rectangle {
                id: trackBg
                x: 0
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 52
                height: 6
                radius: 3
                color: root.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.12)

                Rectangle {
                    height: parent.height
                    width: parent.width * sliderBox.normalized
                    radius: 3
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: root.cAccent }
                        GradientStop { position: 1.0; color: "#38bdf8" }
                    }
                }
            }

            Rectangle {
                x: (parent.width - 52) * sliderBox.normalized - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                radius: 8
                color: "#ffffff"
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.12)

                scale: dragArea.pressed ? 1.22 : dragArea.containsMouse ? 1.12 : 1.0
                Behavior on scale { NumberAnimation { duration: 100 } }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 22
                radius: 6
                color: root.cChipBg
                border.width: 1
                border.color: root.cChipBorder

                Text {
                    anchors.centerIn: parent
                    text: (sr.step < 1 ? sr.localVal.toFixed(2) : Math.round(sr.localVal)) + sr.unit
                    color: root.cTextPrimary
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }

            MouseArea {
                id: dragArea
                anchors.left: parent.left
                anchors.right: trackBg.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onPressed: mouse => sliderBox.applyMouse(mouse.x)
                onPositionChanged: mouse => {
                    if (pressed) sliderBox.applyMouse(mouse.x);
                }
                onReleased: sr.commit()
                onCanceled: sr.commit()
            }
        }
    }

    // Component for a clean iOS/macOS styled Switch Row
    component SwitchRow: Item {
        id: sw
        property string title: ""
        property string desc: ""
        property bool checked: false
        signal toggled(bool next)

        width: parent ? parent.width : 400
        height: 50

        Column {
            anchors.left: parent.left
            anchors.right: toggleBtn.left
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                text: sw.title
                color: root.cTextPrimary
                font.pixelSize: 13
                font.weight: Font.Medium
            }
            Text {
                text: sw.desc
                color: root.cTextSecondary
                font.pixelSize: 11
                visible: text !== ""
            }
        }

        Item {
            id: toggleBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            height: 24

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: sw.checked ? "#10b981" : (root.isLight ? "#cbd5e1" : "#333d4d")
                border.width: 1
                border.color: sw.checked ? "#059669" : (root.isLight ? "#94a3b8" : "#475569")

                Behavior on color { ColorAnimation { duration: 150 } }

                Rectangle {
                    x: sw.checked ? parent.width - width - 2 : 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.height - 4
                    height: width
                    radius: width / 2
                    color: "#ffffff"

                    Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: sw.toggled(!sw.checked)
            }
        }
    }

    // Main Card background with Ambient Shadow
    Rectangle {
        id: card
        anchors.fill: parent
        anchors.leftMargin: root.panelPosition === "left" ? 16 : 6
        anchors.rightMargin: root.panelPosition === "right" ? 16 : 6
        anchors.topMargin: root.panelPosition === "top" ? 16 : 6
        anchors.bottomMargin: root.panelPosition === "bottom" ? 16 : 6
        radius: 16
        color: root.cCardBg
        border.width: 1
        border.color: root.cCardBorder

        // 1px Top Specular Highlight Shelf (Signature macOS Glass Reflection)
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 1
            height: 1
            radius: 16
            color: root.isLight ? Qt.rgba(1, 1, 1, 0.95) : Qt.rgba(1, 1, 1, 0.22)
        }

        // ---- Header ----
        Item {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 56

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                // Control Center Squircle Icon
                Rectangle {
                    width: 32
                    height: 32
                    radius: 8
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: root.isLight ? "#0284c7" : "#2563eb" }
                        GradientStop { position: 1.0; color: root.isLight ? "#38bdf8" : "#60a5fa" }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "⚙"
                        font.pixelSize: 16
                        color: "#ffffff"
                    }
                }

                Column {
                    spacing: 1
                    Text {
                        text: "macOS Dock 设置"
                        color: root.cTextPrimary
                        font.pixelSize: 14
                        font.weight: Font.Bold
                    }
                    Text {
                        text: Config.perScreenConfig ? ("独立屏幕配置已生效 · " + root.selectedScreen) : "全局配置 · 实时毛玻璃渲染"
                        color: root.cTextSecondary
                        font.pixelSize: 11
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // Light Mode Preset Button
                Rectangle {
                    width: 84
                    height: 26
                    radius: 6
                    color: root.isLight
                        ? (root.isLight ? Qt.rgba(245, 158, 11, 0.16) : Qt.rgba(245, 158, 11, 0.22))
                        : (lightHover.containsMouse ? root.cChipHover : root.cChipBg)
                    border.width: 1
                    border.color: root.isLight ? "#f59e0b" : root.cChipBorder

                    Text {
                        anchors.centerIn: parent
                        text: "☀️ 亮色"
                        color: root.isLight ? "#d97706" : root.cTextSecondary
                        font.pixelSize: 11
                        font.weight: root.isLight ? Font.DemiBold : Font.Normal
                    }

                    MouseArea {
                        id: lightHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Config.applyLightPreset(Config.perScreenConfig ? root.selectedScreen : null)
                    }
                }

                // Dark Mode Preset Button
                Rectangle {
                    width: 84
                    height: 26
                    radius: 6
                    color: !root.isLight
                        ? (root.isLight ? Qt.rgba(59, 130, 246, 0.16) : Qt.rgba(59, 130, 246, 0.25))
                        : (darkHover.containsMouse ? root.cChipHover : root.cChipBg)
                    border.width: 1
                    border.color: !root.isLight ? root.cAccent : root.cChipBorder

                    Text {
                        anchors.centerIn: parent
                        text: "🌙 暗色"
                        color: !root.isLight ? (root.isLight ? "#2563eb" : "#60a5fa") : root.cTextSecondary
                        font.pixelSize: 11
                        font.weight: !root.isLight ? Font.DemiBold : Font.Normal
                    }

                    MouseArea {
                        id: darkHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Config.applyDarkPreset(Config.perScreenConfig ? root.selectedScreen : null)
                    }
                }

                // Reset Button
                Rectangle {
                    width: 68
                    height: 26
                    radius: 6
                    color: resetHover.containsMouse ? root.cChipHover : root.cChipBg
                    border.width: 1
                    border.color: root.cChipBorder

                    Text {
                        anchors.centerIn: parent
                        text: "恢复默认"
                        color: root.cTextSecondary
                        font.pixelSize: 11
                    }

                    MouseArea {
                        id: resetHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Config.resetDefaults(Config.perScreenConfig ? root.selectedScreen : null)
                    }
                }

                // Close Button (×)
                Rectangle {
                    width: 26
                    height: 26
                    radius: 13
                    color: closeHover.containsMouse ? (root.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.15)) : root.cChipBg
                    border.width: 1
                    border.color: root.cChipBorder

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: root.cTextSecondary
                        font.pixelSize: 11
                    }

                    MouseArea {
                        id: closeHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.visible = false
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: root.cDivider
            }
        }

        // ---- Apple Segmented Tab bar ----
        Item {
            id: tabBar
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 44

            Rectangle {
                anchors.centerIn: parent
                width: parent.width - 32
                height: 34
                radius: 8
                color: root.isLight ? Qt.rgba(0, 0, 0, 0.045) : Qt.rgba(0, 0, 0, 0.25)
                border.width: 1
                border.color: root.cGroupBorder

                readonly property var tabs: [
                    { id: 0, name: "位置屏幕" },
                    { id: 1, name: "尺寸边距" },
                    { id: 2, name: "自动隐藏" },
                    { id: 3, name: "动效交互" },
                    { id: 4, name: "运行底板" }
                ]

                readonly property real tabW: (width - 4) / tabs.length

                // Sliding Active Tab Indicator
                Rectangle {
                    x: 2 + root.currentTab * parent.tabW
                    y: 2
                    width: parent.tabW
                    height: parent.height - 4
                    radius: 6
                    color: root.isLight ? "#ffffff" : "#283344"
                    border.width: 1
                    border.color: root.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.12)

                    Behavior on x {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 2

                    Repeater {
                        model: parent.parent.tabs

                        Item {
                            required property var modelData
                            width: parent.parent.tabW
                            height: parent.height

                            Text {
                                anchors.centerIn: parent
                                text: modelData.name
                                color: root.currentTab === modelData.id ? root.cTextPrimary : (root.isLight ? "#475569" : "#94a3b8")
                                font.pixelSize: 11
                                font.weight: root.currentTab === modelData.id ? Font.DemiBold : Font.Normal
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.currentTab = modelData.id
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: root.cDivider
            }
        }

        // ---- Persistent Screen Bar across all tabs when perScreenConfig is active ----
        Rectangle {
            id: screenBar
            visible: Config.perScreenConfig && Quickshell.screens && Quickshell.screens.length > 1
            anchors.top: tabBar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: visible ? 42 : 0
            color: root.isLight ? Qt.rgba(0, 0, 0, 0.02) : Qt.rgba(0, 0, 0, 0.15)

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 18
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "目标显示器:"
                    color: root.cTextSecondary
                    font.pixelSize: 11
                    font.weight: Font.Medium
                }

                Repeater {
                    model: Quickshell.screens

                    Rectangle {
                        required property var modelData
                        required property int index
                        height: 26
                        width: Math.max(90, scrBarLabel.implicitWidth + 20)
                        radius: 6
                        color: root.selectedScreen === modelData.name
                            ? root.cAccentBg
                            : (barHover.containsMouse ? root.cChipHover : root.cChipBg)
                        border.width: 1
                        border.color: root.selectedScreen === modelData.name ? root.cAccentBorder : root.cChipBorder

                        Text {
                            id: scrBarLabel
                            anchors.centerIn: parent
                            text: (modelData.name.indexOf("eDP") >= 0 ? "💻 " : "🖥 ") + modelData.name + (modelData.name === root.activeScreen ? " (当前)" : "")
                            color: root.selectedScreen === modelData.name ? root.cAccent : root.cTextSecondary
                            font.pixelSize: 11
                            font.weight: root.selectedScreen === modelData.name ? Font.DemiBold : Font.Normal
                        }

                        MouseArea {
                            id: barHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectedScreen = modelData.name
                        }
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: root.cDivider
            }
        }

        // ---- Content Area ----
        Flickable {
            id: flick
            anchors.top: screenBar.visible ? screenBar.bottom : tabBar.bottom
            anchors.topMargin: 10
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: parent.right
            anchors.rightMargin: 16
            contentHeight: contentCol.height
            clip: true

            Column {
                id: contentCol
                width: flick.width
                spacing: 10

                // ==================== TAB 0: 位置与屏幕 ====================
                Column {
                    width: parent.width
                    spacing: 10
                    visible: root.currentTab === 0

                    // 1. 多屏幕独立配置主开关卡片 (Bento Group Card)
                    Rectangle {
                        width: parent.width
                        height: perScreenCol.height + 20
                        radius: 12
                        color: root.cGroupBg
                        border.width: 1
                        border.color: Config.perScreenConfig ? root.cAccentBorder : root.cGroupBorder

                        Column {
                            id: perScreenCol
                            anchors.top: parent.top
                            anchors.topMargin: 10
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            spacing: 8

                            Item {
                                width: parent.width
                                height: 44

                                Column {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Text {
                                        text: "多屏幕独立配置 (Per-Screen Customization)"
                                        color: root.cTextPrimary
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                    }
                                    Text {
                                        text: "开启后每个显示器可拥有完全独立的停靠位置、尺寸、自动隐藏与外观"
                                        color: root.cTextSecondary
                                        font.pixelSize: 11
                                    }
                                }

                                Item {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 44
                                    height: 24

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: height / 2
                                        color: Config.perScreenConfig ? "#10b981" : (root.isLight ? "#cbd5e1" : "#333d4d")
                                        border.width: 1
                                        border.color: Config.perScreenConfig ? "#059669" : (root.isLight ? "#94a3b8" : "#475569")

                                        Behavior on color { ColorAnimation { duration: 140 } }

                                        Rectangle {
                                            x: Config.perScreenConfig ? parent.width - width - 2 : 2
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.height - 4
                                            height: width
                                            radius: width / 2
                                            color: "#ffffff"

                                            Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Config.setPerScreenConfig(!Config.perScreenConfig)
                                    }
                                }
                            }

                            // 独立配置开启时的状态与快捷操作
                            Column {
                                width: parent.width
                                spacing: 8
                                visible: Config.perScreenConfig

                                Rectangle {
                                    width: parent.width
                                    height: 1
                                    color: root.cDivider
                                }

                                // 选中屏幕是否开启 Dock
                                Item {
                                    width: parent.width
                                    height: 38

                                    Column {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2
                                        Text {
                                            text: "在此屏幕上启用 Dock"
                                            color: root.cTextPrimary
                                            font.pixelSize: 12
                                            font.weight: Font.Medium
                                        }
                                        Text {
                                            text: "目标屏幕: " + root.selectedScreen
                                            color: root.cTextMuted
                                            font.pixelSize: 10
                                        }
                                    }

                                    Item {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 40
                                        height: 22

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: height / 2
                                            color: root.getVal("enabled") !== false ? "#10b981" : (root.isLight ? "#cbd5e1" : "#333d4d")
                                            border.width: 1
                                            border.color: root.getVal("enabled") !== false ? "#059669" : (root.isLight ? "#94a3b8" : "#475569")

                                            Behavior on color { ColorAnimation { duration: 140 } }

                                            Rectangle {
                                                x: root.getVal("enabled") !== false ? parent.width - width - 2 : 2
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: parent.height - 4
                                                height: width
                                                radius: width / 2
                                                color: "#ffffff"

                                                Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.setVal("enabled", root.getVal("enabled") === false ? true : false)
                                        }
                                    }
                                }

                                // 快捷操作按钮
                                Row {
                                    spacing: 8

                                    Rectangle {
                                        width: 140
                                        height: 26
                                        radius: 6
                                        color: cpGlobalHover.containsMouse ? root.cChipHover : root.cChipBg
                                        border.width: 1
                                        border.color: root.cChipBorder

                                        Text {
                                            anchors.centerIn: parent
                                            text: "📋 复制全局配置至此"
                                            color: root.cTextSecondary
                                            font.pixelSize: 11
                                        }

                                        MouseArea {
                                            id: cpGlobalHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Config.copyGlobalToScreen(root.selectedScreen)
                                        }
                                    }

                                    Rectangle {
                                        width: 130
                                        height: 26
                                        radius: 6
                                        color: rstScrHover.containsMouse ? Qt.rgba(239, 68, 68, 0.18) : root.cChipBg
                                        border.width: 1
                                        border.color: rstScrHover.containsMouse ? "#ef4444" : root.cChipBorder

                                        Text {
                                            anchors.centerIn: parent
                                            text: "🔄 重置此屏幕配置"
                                            color: rstScrHover.containsMouse ? "#ef4444" : root.cTextSecondary
                                            font.pixelSize: 11
                                        }

                                        MouseArea {
                                            id: rstScrHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Config.resetScreenConfig(root.selectedScreen)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 2. 停靠边缘 Bento Group Card
                    Rectangle {
                        width: parent.width
                        height: 60
                        radius: 12
                        color: root.cGroupBg
                        border.width: 1
                        border.color: root.cGroupBorder

                        Item {
                            anchors.fill: parent
                            anchors.margins: 14

                            Column {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    text: "停靠边缘" + (Config.perScreenConfig ? (" (" + root.selectedScreen + ")") : "")
                                    color: root.cTextPrimary
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                }
                                Text {
                                    text: "选择 Dock 在屏幕上停靠吸附的方向"
                                    color: root.cTextSecondary
                                    font.pixelSize: 11
                                }
                            }

                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                readonly property var positions: [
                                    { key: "bottom", label: "⬇ 底部" },
                                    { key: "top", label: "⬆ 顶部" },
                                    { key: "left", label: "⬅ 左侧" },
                                    { key: "right", label: "➡ 右侧" }
                                ]

                                Repeater {
                                    model: parent.positions

                                    Rectangle {
                                        required property var modelData
                                        width: 54
                                        height: 28
                                        radius: 6
                                        color: root.getVal("position") === modelData.key
                                            ? root.cAccentBg
                                            : (posHover.containsMouse ? root.cChipHover : root.cChipBg)
                                        border.width: 1
                                        border.color: root.getVal("position") === modelData.key ? root.cAccentBorder : root.cChipBorder

                                        Behavior on color { ColorAnimation { duration: 100 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.label
                                            color: root.getVal("position") === modelData.key ? root.cAccent : root.cTextSecondary
                                            font.pixelSize: 11
                                            font.weight: root.getVal("position") === modelData.key ? Font.DemiBold : Font.Normal
                                        }

                                        MouseArea {
                                            id: posHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.setVal("position", modelData.key)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 3. 屏幕边缘留白
                    Rectangle {
                        width: parent.width
                        height: 60
                        radius: 12
                        color: root.cGroupBg
                        border.width: 1
                        border.color: root.cGroupBorder

                        Item {
                            anchors.fill: parent
                            anchors.margins: 14

                            SliderRow {
                                anchors.fill: parent
                                title: "屏幕边缘留白"
                                desc: "Dock 距离屏幕边缘的悬浮高度"
                                min: 0; max: 24; step: 1
                                value: root.getVal("bottomMargin"); unit: " px"
                                onModified: val => root.setVal("bottomMargin", Math.round(val))
                            }
                        }
                    }

                    // 4. 全局模式下的显示屏幕策略 (仅在 perScreenConfig 为关闭时显示)
                    Rectangle {
                        width: parent.width
                        height: 60
                        radius: 12
                        color: root.cGroupBg
                        border.width: 1
                        border.color: root.cGroupBorder
                        visible: !Config.perScreenConfig

                        Item {
                            anchors.fill: parent
                            anchors.margins: 14

                            Column {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    text: "多屏显示策略"
                                    color: root.cTextPrimary
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                }
                                Text {
                                    text: "单屏显示可大幅降低显存与内存占用"
                                    color: root.cTextSecondary
                                    font.pixelSize: 11
                                }
                            }

                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                readonly property var modes: [
                                    { key: "all", label: "全部屏幕" },
                                    { key: "primary", label: "仅主屏幕" },
                                    { key: "custom", label: "指定屏幕" }
                                ]

                                Repeater {
                                    model: parent.modes

                                    Rectangle {
                                        required property var modelData
                                        width: 68
                                        height: 28
                                        radius: 6
                                        color: Config.screenMode === modelData.key
                                            ? root.cAccentBg
                                            : (modeHover.containsMouse ? root.cChipHover : root.cChipBg)
                                        border.width: 1
                                        border.color: Config.screenMode === modelData.key ? root.cAccentBorder : root.cChipBorder

                                        Behavior on color { ColorAnimation { duration: 100 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.label
                                            color: Config.screenMode === modelData.key ? root.cAccent : root.cTextSecondary
                                            font.pixelSize: 11
                                            font.weight: Config.screenMode === modelData.key ? Font.DemiBold : Font.Normal
                                        }

                                        MouseArea {
                                            id: modeHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Config.setVal("screenMode", modelData.key)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 4. 当选择“指定屏幕”时展示当前连接的屏幕列表供选择
                    Rectangle {
                        width: parent.width
                        height: scrFlow.height + 36
                        radius: 12
                        color: root.cGroupBg
                        border.width: 1
                        border.color: root.cGroupBorder
                        visible: !Config.perScreenConfig && Config.screenMode === "custom"

                        Column {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 8

                            Text {
                                text: "选择目标屏幕："
                                color: root.cTextPrimary
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }

                            Flow {
                                id: scrFlow
                                width: parent.width
                                spacing: 6

                                Repeater {
                                    model: Quickshell.screens

                                    Rectangle {
                                        required property var modelData
                                        required property int index
                                        width: Math.max(90, scrText.implicitWidth + 24)
                                        height: 28
                                        radius: 6
                                        color: Config.targetScreen === modelData.name
                                            ? root.cAccentBg
                                            : (scrHover.containsMouse ? root.cChipHover : root.cChipBg)
                                        border.width: 1
                                        border.color: Config.targetScreen === modelData.name ? root.cAccentBorder : root.cChipBorder

                                        Text {
                                            id: scrText
                                            anchors.centerIn: parent
                                            text: (modelData.name || ("屏幕 " + index)) + (index === 0 ? " (主)" : "")
                                            color: Config.targetScreen === modelData.name ? root.cAccent : root.cTextSecondary
                                            font.pixelSize: 11
                                        }

                                        MouseArea {
                                            id: scrHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Config.setVal("targetScreen", modelData.name)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ==================== TAB 1: 尺寸与间距 ====================
                Column {
                    width: parent.width
                    spacing: 10
                    visible: root.currentTab === 1

                    // Bento Card 1: 图标与留白
                    Rectangle {
                        width: parent.width
                        height: t1Group1.height + 20
                        radius: 12
                        color: root.cGroupBg
                        border.width: 1
                        border.color: root.cGroupBorder

                        Column {
                            id: t1Group1
                            anchors.top: parent.top
                            anchors.topMargin: 10
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            spacing: 2

                            // 快速尺寸预设
                            Item {
                                width: parent.width
                                height: 38

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "快速尺寸预设"
                                    color: root.cTextPrimary
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                }

                                Row {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6

                                    readonly property var presets: [
                                        { size: 32, label: "小 (32px)" },
                                        { size: 44, label: "标准 (44px)" },
                                        { size: 56, label: "大 (56px)" },
                                        { size: 72, label: "超大 (72px)" }
                                    ]

                                    Repeater {
                                        model: parent.presets

                                        Rectangle {
                                            required property var modelData
                                            width: 72
                                            height: 26
                                            radius: 6
                                            color: root.getVal("iconSize") === modelData.size
                                                ? root.cAccentBg
                                                : (preHover.containsMouse ? root.cChipHover : root.cChipBg)
                                            border.width: 1
                                            border.color: root.getVal("iconSize") === modelData.size ? root.cAccentBorder : root.cChipBorder

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.label
                                                color: root.getVal("iconSize") === modelData.size ? root.cAccent : root.cTextSecondary
                                                font.pixelSize: 11
                                                font.weight: root.getVal("iconSize") === modelData.size ? Font.DemiBold : Font.Normal
                                            }

                                            MouseArea {
                                                id: preHover
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.setVal("iconSize", modelData.size)
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle { width: parent.width; height: 1; color: root.cDivider }

                            SliderRow {
                                title: "Dock 图标与整体大小"
                                desc: "单个图标基础尺寸，底板与所有元素随之等比缩放"
                                min: 24; max: 96; step: 1
                                value: root.getVal("iconSize"); unit: " px"
                                onModified: val => root.setVal("iconSize", Math.round(val))
                            }

                            Item {
                                width: parent.width
                                height: 22

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    text: "💡 快捷拖拽：在 Dock 分割线上按住鼠标上下拖移即可直接调整大小，双击复位默认 (44px)。"
                                    color: root.cTextMuted
                                    font.pixelSize: 10
                                }
                            }

                            Rectangle { width: parent.width; height: 1; color: root.cDivider }

                            SliderRow {
                                title: "单元格内边距"
                                desc: "图标与悬浮高亮边框的间距"
                                min: 0; max: 8; step: 1
                                value: root.getVal("cellPadding"); unit: " px"
                                onModified: val => root.setVal("cellPadding", Math.round(val))
                            }

                            Rectangle { width: parent.width; height: 1; color: root.cDivider }

                            SliderRow {
                                title: "图标间隙"
                                desc: "相邻应用图标之间的间距"
                                min: 0; max: 16; step: 1
                                value: root.getVal("spacing"); unit: " px"
                                onModified: val => root.setVal("spacing", Math.round(val))
                            }

                            Rectangle { width: parent.width; height: 1; color: root.cDivider }

                            SliderRow {
                                title: "Dock 底板内边距"
                                desc: "底板外边缘到图标之间的留白"
                                min: 2; max: 14; step: 1
                                value: root.getVal("dockPadding"); unit: " px"
                                onModified: val => root.setVal("dockPadding", Math.round(val))
                            }
                        }
                    }

                    // Bento Card 2: 底板外观与晶莹度
                    Rectangle {
                        width: parent.width
                        height: t1Group2.height + 20
                        radius: 12
                        color: root.cGroupBg
                        border.width: 1
                        border.color: root.cGroupBorder

                        Column {
                            id: t1Group2
                            anchors.top: parent.top
                            anchors.topMargin: 10
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            spacing: 2

                            SliderRow {
                                title: "底板圆角半径"
                                desc: "Dock 两端及顶部的圆角大小"
                                min: 4; max: 26; step: 1
                                value: root.getVal("radius"); unit: " px"
                                onModified: val => root.setVal("radius", Math.round(val))
                            }

                            Rectangle { width: parent.width; height: 1; color: root.cDivider }

                            SliderRow {
                                title: "底板不透明度"
                                desc: "半透明毛玻璃背景的实心程度"
                                min: 0.1; max: 1.0; step: 0.05
                                value: root.getVal("backgroundOpacity")
                                unit: "%"
                                onModified: val => root.setVal("backgroundOpacity", val)
                            }

                            Rectangle { width: parent.width; height: 1; color: root.cDivider }

                            SliderRow {
                                title: "高精度边框粗细"
                                desc: "Dock 外轮廓单路径描边线条粗细"
                                min: 0; max: 3; step: 0.5
                                value: root.getVal("borderWidth"); unit: " px"
                                onModified: val => root.setVal("borderWidth", val)
                            }
                        }
                    }
                }

                // ==================== TAB 2: 自动隐藏 ====================
                Column {
                    width: parent.width
                    spacing: 10
                    visible: root.currentTab === 2

                    // Bento Card 1: 隐藏策略
                    Rectangle {
                        width: parent.width
                        height: t2Group1.height + 20
                        radius: 12
                        color: root.cGroupBg
                        border.width: 1
                        border.color: root.cGroupBorder

                        Column {
                            id: t2Group1
                            anchors.top: parent.top
                            anchors.topMargin: 10
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            spacing: 2

                            SwitchRow {
                                title: "自动隐藏 Dock"
                                desc: "不使用时向屏幕边缘滑动收起"
                                checked: root.getVal("autoHide")
                                onToggled: val => root.setVal("autoHide", val)
                            }
                        }
                    }

                    // Bento Card 2: 露出微条与召唤
                    Rectangle {
                        width: parent.width
                        height: t2Group2.height + 20
                        radius: 12
                        color: root.cGroupBg
                        border.width: 1
                        border.color: root.cGroupBorder

                        Column {
                            id: t2Group2
                            anchors.top: parent.top
                            anchors.topMargin: 10
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            spacing: 2

                            SliderRow {
                                title: "隐藏露出高度 (Peek)"
                                desc: "收起后露在屏幕边缘的细条高度"
                                min: 0; max: 32; step: 2
                                value: root.getVal("peekHeight"); unit: " px"
                                onModified: val => root.setVal("peekHeight", Math.round(val))
                            }

                            Rectangle { width: parent.width; height: 1; color: root.cDivider }

                            SliderRow {
                                title: "隐藏细条不透明度"
                                desc: "收起细条的可见度 (设为 0 完全隐形)"
                                min: 0.0; max: 1.0; step: 0.05
                                value: root.getVal("peekOpacity"); unit: ""
                                onModified: val => root.setVal("peekOpacity", val)
                            }

                            Rectangle { width: parent.width; height: 1; color: root.cDivider }

                            SliderRow {
                                title: "感应召唤区高度"
                                desc: "鼠标移动至屏幕边缘唤醒 Dock 的感应高度"
                                min: 4; max: 24; step: 2
                                value: root.getVal("triggerHeight"); unit: " px"
                                onModified: val => root.setVal("triggerHeight", Math.round(val))
                            }
                        }
                    }

                    // Bento Card 3: 动效时机
                    Rectangle {
                        width: parent.width
                        height: t2Group3.height + 20
                        radius: 12
                        color: root.cGroupBg
                        border.width: 1
                        border.color: root.cGroupBorder

                        Column {
                            id: t2Group3
                            anchors.top: parent.top
                            anchors.topMargin: 10
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            spacing: 2

                            SliderRow {
                                title: "离开隐藏延迟"
                                desc: "鼠标移开后等待收起的停留时间"
                                min: 100; max: 1000; step: 50
                                value: root.getVal("hideDelay"); unit: " ms"
                                onModified: val => root.setVal("hideDelay", Math.round(val))
                            }

                            Rectangle { width: parent.width; height: 1; color: root.cDivider }

                            SliderRow {
                                title: "滑动动画时长"
                                desc: "弹出与收起动画的平滑耗时"
                                min: 50; max: 300; step: 25
                                value: root.getVal("slideDuration"); unit: " ms"
                                onModified: val => root.setVal("slideDuration", Math.round(val))
                            }
                        }
                    }
                }

                // ==================== TAB 3: 动效与交互 ====================
                Column {
                    width: parent.width
                    spacing: 10
                    visible: root.currentTab === 3

                    // Bento Card 1: 鼠标悬停波浪放大
                    Rectangle {
                        width: parent.width
                        height: t3Group1.height + 20
                        radius: 12
                        color: root.cGroupBg
                        border.width: 1
                        border.color: root.cGroupBorder

                        Column {
                            id: t3Group1
                            anchors.top: parent.top
                            anchors.topMargin: 10
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            spacing: 2

                            SwitchRow {
                                title: "macOS 风格悬停放大"
                                desc: "鼠标悬停在图标上时带有回弹放大动画"
                                checked: root.getVal("hoverMagnify")
                                onToggled: val => root.setVal("hoverMagnify", val)
                            }

                            Rectangle { width: parent.width; height: 1; color: root.cDivider }

                            SliderRow {
                                title: "悬停放大倍率"
                                desc: "波浪鱼眼放大中心的最高缩放比例"
                                min: 1.05; max: 1.8; step: 0.02
                                value: root.getVal("hoverScale"); unit: "x"
                                onModified: val => root.setVal("hoverScale", val)
                            }

                            Rectangle { width: parent.width; height: 1; color: root.cDivider }

                            SliderRow {
                                title: "波浪影响范围 (Wave Spread)"
                                desc: "连续抛物线扩散影响的相邻图标数量"
                                min: 1.2; max: 3.5; step: 0.1
                                value: root.getVal("waveSpread"); unit: " 单元"
                                onModified: val => root.setVal("waveSpread", val)
                            }
                        }
                    }

                    // Bento Card 2: 视效与增强行为
                    Rectangle {
                        width: parent.width
                        height: t3Group2.height + 20
                        radius: 12
                        color: root.cGroupBg
                        border.width: 1
                        border.color: root.cGroupBorder

                        Column {
                            id: t3Group2
                            anchors.top: parent.top
                            anchors.topMargin: 10
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            spacing: 2

                            SwitchRow {
                                title: "点击启动跳跃动效"
                                desc: "点击应用图标时呈现 macOS 标志性上下跳跃反馈"
                                checked: root.getVal("bounceOnLaunch")
                                onToggled: val => root.setVal("bounceOnLaunch", val)
                            }

                            Rectangle { width: parent.width; height: 1; color: root.cDivider }

                            SwitchRow {
                                title: "顶部微光反射条"
                                desc: "Dock 顶边缘呈现 Apple 晶莹质感的 1px 细微高光反光"
                                checked: root.getVal("glassHighlight")
                                onToggled: val => root.setVal("glassHighlight", val)
                            }

                            Rectangle { width: parent.width; height: 1; color: root.cDivider }

                            SwitchRow {
                                title: "柔和环境投影 (Shadow)"
                                desc: "浮动状态下底板四周呈现弥散环境深色柔光投影"
                                checked: root.getVal("shadowEnabled")
                                onToggled: val => root.setVal("shadowEnabled", val)
                            }

                            Rectangle { width: parent.width; height: 1; color: root.cDivider }

                            SwitchRow {
                                title: "显示废纸篓 (Trash)"
                                desc: "在右侧控制区展示 macOS 废纸篓快捷入口与右键清空操作"
                                checked: root.getVal("showTrash")
                                onToggled: val => root.setVal("showTrash", val)
                            }

                            Rectangle { width: parent.width; height: 1; color: root.cDivider }

                            SwitchRow {
                                title: "底边反向平滑过渡角"
                                desc: "Dock 贴底时两侧自然向外扩出融入底边"
                                checked: root.getVal("edgeCorners")
                                onToggled: val => root.setVal("edgeCorners", val)
                            }

                            Rectangle { width: parent.width; height: 1; color: root.cDivider }

                            SliderRow {
                                title: "反向角外扩弧度"
                                desc: "两侧反向圆角的大小"
                                min: 4; max: 24; step: 2
                                value: root.getVal("cornerSize"); unit: " px"
                                onModified: val => root.setVal("cornerSize", Math.round(val))
                            }

                            Rectangle { width: parent.width; height: 1; color: root.cDivider }

                            SwitchRow {
                                title: "独占屏幕空间 (Reserve Space)"
                                desc: "开启后最大化窗口将自动避让 Dock"
                                checked: root.getVal("reserveSpace")
                                onToggled: val => root.setVal("reserveSpace", val)
                            }
                        }
                    }
                }

                // ==================== TAB 4: 运行与来源 ====================
                Column {
                    width: parent.width
                    spacing: 10
                    visible: root.currentTab === 4

                    // Bento Card 1: 运行与指示点
                    Rectangle {
                        width: parent.width
                        height: t4Group1.height + 20
                        radius: 12
                        color: root.cGroupBg
                        border.width: 1
                        border.color: root.cGroupBorder

                        Column {
                            id: t4Group1
                            anchors.top: parent.top
                            anchors.topMargin: 10
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            spacing: 2

                            SwitchRow {
                                title: "显示运行中的应用"
                                desc: "未加入收藏但正在运行的应用也会动态显示在 Dock 上"
                                checked: root.getVal("showRunningApps")
                                onToggled: val => root.setVal("showRunningApps", val)
                            }

                            Rectangle { width: parent.width; height: 1; color: root.cDivider }

                            SwitchRow {
                                title: "运行状态指示点"
                                desc: "图标下方居中显示 macOS 风格晶莹圆点"
                                checked: root.getVal("runningIndicator")
                                onToggled: val => root.setVal("runningIndicator", val)
                            }

                            Rectangle { width: parent.width; height: 1; color: root.cDivider }

                            SliderRow {
                                title: "指示点上限数量"
                                desc: "防止一个应用开过多窗口把图标遮满"
                                min: 1; max: 5; step: 1
                                value: root.getVal("indicatorMaxDots"); unit: " 个"
                                onModified: val => root.setVal("indicatorMaxDots", Math.round(val))
                            }

                            Rectangle { width: parent.width; height: 1; color: root.cDivider }

                            SwitchRow {
                                title: "点击唤醒与轮转窗口"
                                desc: "点击运行中应用激活窗口，多窗口连续点击切换"
                                checked: root.getVal("raiseRunning")
                                onToggled: val => root.setVal("raiseRunning", val)
                            }

                            Rectangle { width: parent.width; height: 1; color: root.cDivider }

                            SwitchRow {
                                title: "单窗口点击最小化"
                                desc: "仅打开一个窗口时，点击已激活的图标可将其最小化"
                                checked: root.getVal("minimizeActive")
                                onToggled: val => root.setVal("minimizeActive", val)
                            }

                            Rectangle { width: parent.width; height: 1; color: root.cDivider }

                            SwitchRow {
                                title: "悬停显示 “+” 新开按钮"
                                desc: "悬停在已运行应用上方时浮现新建窗口按钮"
                                checked: root.getVal("newInstanceButton")
                                onToggled: val => root.setVal("newInstanceButton", val)
                            }
                        }
                    }

                    // Bento Card 2: 数据源与底板主题色
                    Rectangle {
                        width: parent.width
                        height: t4Group2.height + 24
                        radius: 12
                        color: root.cGroupBg
                        border.width: 1
                        border.color: root.cGroupBorder

                        Column {
                            id: t4Group2
                            anchors.top: parent.top
                            anchors.topMargin: 12
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            spacing: 10

                            // Source Selector
                            Item {
                                width: parent.width
                                height: 46

                                Column {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text {
                                        text: "启动器数据源"
                                        color: root.cTextPrimary
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                    }
                                    Text {
                                        text: "读取 Kickoff 收藏或任务栏固定项"
                                        color: root.cTextSecondary
                                        font.pixelSize: 11
                                    }
                                }

                                Row {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6

                                    Rectangle {
                                        width: 92
                                        height: 28
                                        radius: 6
                                        color: root.getVal("source") === "kickoff"
                                            ? root.cAccentBg
                                            : (kickHover.containsMouse ? root.cChipHover : root.cChipBg)
                                        border.width: 1
                                        border.color: root.getVal("source") === "kickoff" ? root.cAccentBorder : root.cChipBorder

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Kickoff 收藏"
                                            color: root.getVal("source") === "kickoff" ? root.cAccent : root.cTextSecondary
                                            font.pixelSize: 11
                                            font.weight: root.getVal("source") === "kickoff" ? Font.DemiBold : Font.Normal
                                        }
                                        MouseArea {
                                            id: kickHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.setVal("source", "kickoff")
                                        }
                                    }

                                    Rectangle {
                                        width: 92
                                        height: 28
                                        radius: 6
                                        color: root.getVal("source") === "taskmanager"
                                            ? root.cAccentBg
                                            : (taskHover.containsMouse ? root.cChipHover : root.cChipBg)
                                        border.width: 1
                                        border.color: root.getVal("source") === "taskmanager" ? root.cAccentBorder : root.cChipBorder

                                        Text {
                                            anchors.centerIn: parent
                                            text: "任务栏固定"
                                            color: root.getVal("source") === "taskmanager" ? root.cAccent : root.cTextSecondary
                                            font.pixelSize: 11
                                            font.weight: root.getVal("source") === "taskmanager" ? Font.DemiBold : Font.Normal
                                        }
                                        MouseArea {
                                            id: taskHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.setVal("source", "taskmanager")
                                        }
                                    }
                                }
                            }

                            Rectangle { width: parent.width; height: 1; color: root.cDivider }

                            // Background Theme Color Palette
                            Item {
                                width: parent.width
                                height: 46

                                Column {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text {
                                        text: "底板预设主题色"
                                        color: root.cTextPrimary
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                    }
                                    Text {
                                        text: "点击切换实时质感与亮暗模式"
                                        color: root.cTextSecondary
                                        font.pixelSize: 11
                                    }
                                }

                                Row {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8

                                    readonly property var colors: [
                                        { hex: "#ffffff", name: "亮色毛玻璃" },
                                        { hex: "#20242c", name: "macOS 深灰" },
                                        { hex: "#1c1f26", name: "经典黑" },
                                        { hex: "#161922", name: "深海蓝" },
                                        { hex: "#0d1117", name: "曜石黑" },
                                        { hex: "#252834", name: "玄铁灰" }
                                    ]

                                    Repeater {
                                        model: parent.colors

                                        Rectangle {
                                            required property var modelData
                                            width: 26
                                            height: 26
                                            radius: 13
                                            color: modelData.hex
                                            border.width: root.getVal("backgroundColor") == modelData.hex ? 2.5 : 1
                                            border.color: root.getVal("backgroundColor") == modelData.hex ? root.cAccent : root.cChipBorder

                                            scale: cMouse.containsMouse ? 1.15 : 1.0
                                            Behavior on scale { NumberAnimation { duration: 120 } }

                                            MouseArea {
                                                id: cMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (modelData.hex === "#ffffff") {
                                                        Config.applyLightPreset(Config.perScreenConfig ? root.selectedScreen : null);
                                                    } else {
                                                        root.setVal("backgroundColor", modelData.hex);
                                                        if (root.getVal("indicatorColor") === "#70334155") {
                                                            root.setVal("indicatorColor", "#b8ffffff");
                                                            root.setVal("indicatorActiveColor", "#ffffff");
                                                            root.setVal("border", "#30ffffff");
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
