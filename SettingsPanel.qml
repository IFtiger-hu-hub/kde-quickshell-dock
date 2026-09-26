import Quickshell
import QtQuick

PopupWindow {
    id: root

    anchor.edges: Config.position === "top" ? Edges.Bottom
                : Config.position === "left" ? Edges.Right
                : Config.position === "right" ? Edges.Left
                : Edges.Top
    anchor.gravity: anchor.edges
    anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.SlideY

    implicitWidth: 460 + (Config.position === "left" || Config.position === "right" ? 10 : 0)
    implicitHeight: 560 + (Config.position === "top" || Config.position === "bottom" ? 10 : 0)
    color: "transparent"

    // Click-through on transparent areas (including the gap between panel and dock)
    mask: Region {
        item: card
    }

    property int currentTab: 0

    // Component for a clean Slider Row with real-time thumb tracking and debounced/throttled commit
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

        // Local state so thumb tracks cursor with 0ms lag
        property real localVal: value
        onValueChanged: {
            if (!dragArea.pressed && !debounceTimer.running) {
                localVal = value;
            }
        }

        // Debounce timer: wait 65ms of stillness during drag before updating Config to prevent dock layout jitter
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
        height: 52

        Column {
            anchors.left: parent.left
            anchors.right: sliderBox.left
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                text: sr.title
                color: "#f0f0f5"
                font.pixelSize: 13
                font.weight: Font.Medium
            }
            Text {
                text: sr.desc
                color: "#8e95a5"
                font.pixelSize: 11
                visible: text !== ""
            }
        }

        Item {
            id: sliderBox
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 170
            height: 28

            readonly property real range: sr.max - sr.min
            readonly property real normalized: range > 0 ? Math.max(0, Math.min(1, (sr.localVal - sr.min) / range)) : 0

            function applyMouse(mouseX) {
                const trackW = width - 48; // leave room for badge
                const ratio = Math.max(0, Math.min(1, mouseX / trackW));
                let raw = sr.min + ratio * range;
                if (sr.step > 0) {
                    raw = Math.round(raw / sr.step) * sr.step;
                }
                // Cap strictly within min and max
                raw = Math.max(sr.min, Math.min(sr.max, raw));
                sr.localVal = raw;
                debounceTimer.restart();
            }

            // Track background
            Rectangle {
                id: trackBg
                x: 0
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 48
                height: 5
                radius: 2.5
                color: "#28ffffff"

                // Active fill
                Rectangle {
                    height: parent.height
                    width: parent.width * sliderBox.normalized
                    radius: 2.5
                    color: "#388bfd"
                }
            }

            // Thumb
            Rectangle {
                x: (parent.width - 48) * sliderBox.normalized - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                radius: 7
                color: "#ffffff"
                border.width: 1
                border.color: "#80ffffff"

                scale: dragArea.pressed ? 1.25 : dragArea.containsMouse ? 1.12 : 1.0
                Behavior on scale { NumberAnimation { duration: 100 } }
            }

            // Value badge
            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 42
                height: 20
                radius: 4
                color: "#18ffffff"

                Text {
                    anchors.centerIn: parent
                    text: (sr.step < 1 ? sr.localVal.toFixed(2) : Math.round(sr.localVal)) + sr.unit
                    color: "#d0d7de"
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
        height: 48

        Column {
            anchors.left: parent.left
            anchors.right: toggleBtn.left
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                text: sw.title
                color: "#f0f0f5"
                font.pixelSize: 13
                font.weight: Font.Medium
            }
            Text {
                text: sw.desc
                color: "#8e95a5"
                font.pixelSize: 11
                visible: text !== ""
            }
        }

        Item {
            id: toggleBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 42
            height: 22

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: sw.checked ? "#388bfd" : "#28ffffff"
                border.width: 1
                border.color: sw.checked ? "#4d80ff" : "#20ffffff"

                Behavior on color { ColorAnimation { duration: 140 } }

                Rectangle {
                    x: sw.checked ? parent.width - width - 2 : 2
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
                onClicked: sw.toggled(!sw.checked)
            }
        }
    }

    // Main Card background (with 16px floating gap towards the dock)
    Rectangle {
        id: card
        anchors.fill: parent
        anchors.leftMargin: Config.position === "left" ? 16 : 6
        anchors.rightMargin: Config.position === "right" ? 16 : 6
        anchors.topMargin: Config.position === "top" ? 16 : 6
        anchors.bottomMargin: Config.position === "bottom" ? 16 : 6
        radius: 14
        color: "#f21b1f28"
        border.width: 1
        border.color: "#33ffffff"

        // ---- Header ----
        Item {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 54

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Rectangle {
                    width: 28
                    height: 28
                    radius: 7
                    color: "#28388bfd"
                    border.width: 1
                    border.color: "#40388bfd"

                    Text {
                        anchors.centerIn: parent
                        text: "⚙"
                        font.pixelSize: 14
                    }
                }

                Column {
                    spacing: 1
                    Text {
                        text: "Dock 设置"
                        color: "#ffffff"
                        font.pixelSize: 14
                        font.weight: Font.Bold
                    }
                    Text {
                        text: "参数修改即时生效并自动保存"
                        color: "#8e95a5"
                        font.pixelSize: 11
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // Reset Button
                Rectangle {
                    width: 72
                    height: 26
                    radius: 6
                    color: resetHover.containsMouse ? "#2bffffff" : "#14ffffff"
                    border.width: 1
                    border.color: "#20ffffff"

                    Text {
                        anchors.centerIn: parent
                        text: "恢复默认"
                        color: "#c0c7d4"
                        font.pixelSize: 11
                    }

                    MouseArea {
                        id: resetHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Config.resetDefaults()
                    }
                }

                // Close Button (×)
                Rectangle {
                    width: 26
                    height: 26
                    radius: 13
                    color: closeHover.containsMouse ? "#33ffffff" : "#18ffffff"

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: "#d0d7de"
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
                color: "#18ffffff"
            }
        }

        // ---- Tab bar ----
        Item {
            id: tabBar
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 38

            Row {
                anchors.centerIn: parent
                spacing: 6

                readonly property var tabs: [
                    { id: 0, name: "位置与屏幕" },
                    { id: 1, name: "尺寸与间距" },
                    { id: 2, name: "自动隐藏" },
                    { id: 3, name: "动效交互" },
                    { id: 4, name: "运行与来源" }
                ]

                Repeater {
                    model: parent.tabs

                    Rectangle {
                        required property var modelData
                        width: 78
                        height: 26
                        radius: 6
                        color: root.currentTab === modelData.id
                            ? "#388bfd"
                            : tabHover.containsMouse ? "#1affffff" : "transparent"

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.name
                            color: root.currentTab === modelData.id ? "#ffffff" : "#a2aab8"
                            font.pixelSize: 11
                            font.weight: root.currentTab === modelData.id ? Font.DemiBold : Font.Normal
                        }

                        MouseArea {
                            id: tabHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.currentTab = modelData.id
                        }
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: "#14ffffff"
            }
        }

        // ---- Content Area ----
        Flickable {
            id: flick
            anchors.top: tabBar.bottom
            anchors.topMargin: 8
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.right: parent.right
            anchors.rightMargin: 18
            contentHeight: contentCol.height
            clip: true

            Column {
                id: contentCol
                width: flick.width
                spacing: 4

                // ==================== TAB 0: 位置与屏幕 ====================
                Column {
                    width: parent.width
                    spacing: 8
                    visible: root.currentTab === 0

                    // 1. 停靠边缘
                    Item {
                        width: parent.width
                        height: 56

                        Column {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                text: "停靠边缘"
                                color: "#f0f0f5"
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }
                            Text {
                                text: "选择 Dock 在屏幕上显示的方向"
                                color: "#8e95a5"
                                font.pixelSize: 11
                            }
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

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
                                    width: 50
                                    height: 28
                                    radius: 6
                                    color: Config.position === modelData.key ? "#388bfd" : posHover.containsMouse ? "#20ffffff" : "#12ffffff"
                                    border.width: 1
                                    border.color: Config.position === modelData.key ? "#58a6ff" : "#20ffffff"

                                    Behavior on color { ColorAnimation { duration: 100 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        color: Config.position === modelData.key ? "#ffffff" : "#d0d7de"
                                        font.pixelSize: 11
                                        font.weight: Config.position === modelData.key ? Font.DemiBold : Font.Normal
                                    }

                                    MouseArea {
                                        id: posHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Config.setVal("position", modelData.key)
                                    }
                                }
                            }
                        }
                    }

                    // 2. 显示屏幕策略
                    Item {
                        width: parent.width
                        height: 56

                        Column {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                text: "多屏显示策略"
                                color: "#f0f0f5"
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }
                            Text {
                                text: "单屏显示可大幅降低显存与内存占用"
                                color: "#8e95a5"
                                font.pixelSize: 11
                            }
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            readonly property var modes: [
                                { key: "all", label: "全部屏幕" },
                                { key: "primary", label: "仅主屏幕" },
                                { key: "custom", label: "指定屏幕" }
                            ]

                            Repeater {
                                model: parent.modes

                                Rectangle {
                                    required property var modelData
                                    width: 66
                                    height: 28
                                    radius: 6
                                    color: Config.screenMode === modelData.key ? "#388bfd" : modeHover.containsMouse ? "#20ffffff" : "#12ffffff"
                                    border.width: 1
                                    border.color: Config.screenMode === modelData.key ? "#58a6ff" : "#20ffffff"

                                    Behavior on color { ColorAnimation { duration: 100 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        color: Config.screenMode === modelData.key ? "#ffffff" : "#d0d7de"
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

                    // 3. 当选择“指定屏幕”时，展示当前连接的屏幕列表供选择
                    Column {
                        width: parent.width
                        spacing: 6
                        visible: Config.screenMode === "custom"

                        Text {
                            text: "选择目标屏幕："
                            color: "#c0c7d4"
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }

                        Flow {
                            width: parent.width
                            spacing: 6

                            Repeater {
                                model: Quickshell.screens

                                Rectangle {
                                    required property var modelData
                                    required property int index
                                    width: Math.max(90, scrText.implicitWidth + 24)
                                    height: 30
                                    radius: 6
                                    color: Config.targetScreen === modelData.name ? "#388bfd" : scrHover.containsMouse ? "#20ffffff" : "#14ffffff"
                                    border.width: 1
                                    border.color: Config.targetScreen === modelData.name ? "#58a6ff" : "#20ffffff"

                                    Text {
                                        id: scrText
                                        anchors.centerIn: parent
                                        text: (modelData.name || ("屏幕 " + index)) + (index === 0 ? " (主)" : "")
                                        color: Config.targetScreen === modelData.name ? "#ffffff" : "#d0d7de"
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

                // ==================== TAB 1: 尺寸与间距 ====================
                Column {
                    width: parent.width
                    spacing: 4
                    visible: root.currentTab === 1

                    SliderRow {
                        title: "图标大小"
                        desc: "单个应用图标的像素尺寸"
                        min: 24; max: 64; step: 1
                        value: Config.iconSize; unit: " px"
                        onModified: val => Config.setVal("iconSize", Math.round(val))
                    }

                    SliderRow {
                        title: "单元格内边距"
                        desc: "图标与悬浮高亮边框的间距"
                        min: 0; max: 8; step: 1
                        value: Config.cellPadding; unit: " px"
                        onModified: val => Config.setVal("cellPadding", Math.round(val))
                    }

                    SliderRow {
                        title: "图标间隙"
                        desc: "相邻应用图标之间的间距"
                        min: 0; max: 16; step: 1
                        value: Config.spacing; unit: " px"
                        onModified: val => Config.setVal("spacing", Math.round(val))
                    }

                    SliderRow {
                        title: "Dock 底板内边距"
                        desc: "底板外边缘到图标之间的留白"
                        min: 2; max: 14; step: 1
                        value: Config.dockPadding; unit: " px"
                        onModified: val => Config.setVal("dockPadding", Math.round(val))
                    }

                    SliderRow {
                        title: "底板圆角半径"
                        desc: "Dock 两端及顶部的圆角大小"
                        min: 4; max: 26; step: 1
                        value: Config.radius; unit: " px"
                        onModified: val => Config.setVal("radius", Math.round(val))
                    }

                    SliderRow {
                        title: "底板不透明度"
                        desc: "半透明毛玻璃背景的实心程度"
                        min: 0.1; max: 1.0; step: 0.05
                        value: Config.backgroundOpacity
                        unit: "%"
                        onModified: val => Config.setVal("backgroundOpacity", val)
                    }

                    SliderRow {
                        title: "高精度边框粗细"
                        desc: "Dock 外轮廓单路径描边线条粗细"
                        min: 0; max: 3; step: 0.5
                        value: Config.borderWidth; unit: " px"
                        onModified: val => Config.setVal("borderWidth", val)
                    }
                }

                // ==================== TAB 2: 自动隐藏 ====================
                Column {
                    width: parent.width
                    spacing: 4
                    visible: root.currentTab === 2

                    SwitchRow {
                        title: "自动隐藏 Dock"
                        desc: "不使用时向屏幕底部滑动收起"
                        checked: Config.autoHide
                        onToggled: val => Config.setVal("autoHide", val)
                    }

                    SliderRow {
                        title: "隐藏露出高度 (Peek)"
                        desc: "收起后露在屏幕底部的细条高度"
                        min: 0; max: 32; step: 2
                        value: Config.peekHeight; unit: " px"
                        onModified: val => Config.setVal("peekHeight", Math.round(val))
                    }

                    SliderRow {
                        title: "隐藏细条不透明度"
                        desc: "收起细条的可见度 (设为 0 完全隐形)"
                        min: 0.0; max: 1.0; step: 0.05
                        value: Config.peekOpacity; unit: ""
                        onModified: val => Config.setVal("peekOpacity", val)
                    }

                    SliderRow {
                        title: "感应召唤区高度"
                        desc: "鼠标移动至屏幕边缘唤醒 Dock 的感应高度"
                        min: 4; max: 24; step: 2
                        value: Config.triggerHeight; unit: " px"
                        onModified: val => Config.setVal("triggerHeight", Math.round(val))
                    }

                    SliderRow {
                        title: "离开隐藏延迟"
                        desc: "鼠标移开后等待收起的停留时间"
                        min: 100; max: 1000; step: 50
                        value: Config.hideDelay; unit: " ms"
                        onModified: val => Config.setVal("hideDelay", Math.round(val))
                    }

                    SliderRow {
                        title: "滑动动画时长"
                        desc: "弹出与收起动画的平滑耗时"
                        min: 50; max: 300; step: 25
                        value: Config.slideDuration; unit: " ms"
                        onModified: val => Config.setVal("slideDuration", Math.round(val))
                    }
                }

                // ==================== TAB 3: 动效与交互 ====================
                Column {
                    width: parent.width
                    spacing: 4
                    visible: root.currentTab === 3

                    SwitchRow {
                        title: "macOS 风格悬停放大"
                        desc: "鼠标悬停在图标上时带有回弹放大动画"
                        checked: Config.hoverMagnify
                        onToggled: val => Config.setVal("hoverMagnify", val)
                    }

                    SliderRow {
                        title: "悬停放大倍率"
                        desc: "悬停时图标的缩放比例"
                        min: 1.05; max: 1.5; step: 0.02
                        value: Config.hoverScale; unit: "x"
                        onModified: val => Config.setVal("hoverScale", val)
                    }

                    SwitchRow {
                        title: "底边反向平滑过渡角"
                        desc: "Dock 贴底时两侧自然向外扩出融入底边"
                        checked: Config.edgeCorners
                        onToggled: val => Config.setVal("edgeCorners", val)
                    }

                    SliderRow {
                        title: "反向角外扩弧度"
                        desc: "两侧反向圆角的大小"
                        min: 4; max: 24; step: 2
                        value: Config.cornerSize; unit: " px"
                        onModified: val => Config.setVal("cornerSize", Math.round(val))
                    }

                    SwitchRow {
                        title: "独占屏幕空间 (Reserve Space)"
                        desc: "开启后最大化窗口将自动避让 Dock"
                        checked: Config.reserveSpace
                        onToggled: val => Config.setVal("reserveSpace", val)
                    }
                }

                // ==================== TAB 4: 运行与来源 ====================
                Column {
                    width: parent.width
                    spacing: 6
                    visible: root.currentTab === 4

                    SwitchRow {
                        title: "显示运行中的应用"
                        desc: "未加入收藏但正在运行的应用也会动态显示在 Dock 上"
                        checked: Config.showRunningApps
                        onToggled: val => Config.setVal("showRunningApps", val)
                    }

                    SwitchRow {
                        title: "运行状态指示点"
                        desc: "图标左上角根据窗口数量显示圆点"
                        checked: Config.runningIndicator
                        onToggled: val => Config.setVal("runningIndicator", val)
                    }

                    SliderRow {
                        title: "指示点上限数量"
                        desc: "防止一个应用开过多窗口把图标遮满"
                        min: 1; max: 5; step: 1
                        value: Config.indicatorMaxDots; unit: " 个"
                        onModified: val => Config.setVal("indicatorMaxDots", Math.round(val))
                    }

                    SwitchRow {
                        title: "点击唤醒与轮转窗口"
                        desc: "点击运行中应用激活窗口，多窗口连续点击切换"
                        checked: Config.raiseRunning
                        onToggled: val => Config.setVal("raiseRunning", val)
                    }

                    SwitchRow {
                        title: "单窗口点击最小化"
                        desc: "仅打开一个窗口时，点击已激活的图标可将其最小化"
                        checked: Config.minimizeActive
                        onToggled: val => Config.setVal("minimizeActive", val)
                    }

                    SwitchRow {
                        title: "悬停显示 “+” 新开按钮"
                        desc: "悬停在已运行应用上方时浮现新建窗口按钮"
                        checked: Config.newInstanceButton
                        onToggled: val => Config.setVal("newInstanceButton", val)
                    }

                    // Source Selector
                    Item {
                        width: parent.width
                        height: 52

                        Column {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text {
                                text: "启动器数据源"
                                color: "#f0f0f5"
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }
                            Text {
                                text: "读取 Kickoff 收藏或任务栏固定项"
                                color: "#8e95a5"
                                font.pixelSize: 11
                            }
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Rectangle {
                                width: 90
                                height: 26
                                radius: 6
                                color: Config.source === "kickoff" ? "#388bfd" : "#20ffffff"
                                Text {
                                    anchors.centerIn: parent
                                    text: "Kickoff 收藏"
                                    color: "#ffffff"
                                    font.pixelSize: 11
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Config.setVal("source", "kickoff")
                                }
                            }

                            Rectangle {
                                width: 90
                                height: 26
                                radius: 6
                                color: Config.source === "taskmanager" ? "#388bfd" : "#20ffffff"
                                Text {
                                    anchors.centerIn: parent
                                    text: "任务栏固定"
                                    color: "#ffffff"
                                    font.pixelSize: 11
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Config.setVal("source", "taskmanager")
                                }
                            }
                        }
                    }

                    // Background Theme Color Palette
                    Item {
                        width: parent.width
                        height: 50

                        Column {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text {
                                text: "底板预设主题色"
                                color: "#f0f0f5"
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }
                            Text {
                                text: "搭配不透明度形成不同质感"
                                color: "#8e95a5"
                                font.pixelSize: 11
                            }
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            readonly property var colors: [
                                { hex: "#1c1f26", name: "经典黑" },
                                { hex: "#161922", name: "深海蓝" },
                                { hex: "#0d1117", name: "曜石黑" },
                                { hex: "#252834", name: "玄铁灰" }
                            ]

                            Repeater {
                                model: parent.colors
                                Rectangle {
                                    required property var modelData
                                    width: 24
                                    height: 24
                                    radius: 12
                                    color: modelData.hex
                                    border.width: Config.backgroundColor == modelData.hex ? 2 : 1
                                    border.color: Config.backgroundColor == modelData.hex ? "#388bfd" : "#50ffffff"

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Config.setVal("backgroundColor", modelData.hex)
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
