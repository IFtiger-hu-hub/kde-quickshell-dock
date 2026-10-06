import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

// Pinned to the screen edge (not to the dock), so resizing the dock from the
// sliders never moves the panel. Only the dock position setting changes
// which edge it sits on.
PanelWindow {
    id: root

    property string activeScreen: ""
    property string selectedScreen: {
        if (activeScreen !== "") return activeScreen;
        const screens = Quickshell.screens;
        return (screens && screens.length > 0) ? screens[0].name : "";
    }

    readonly property string panelPosition: Config.getVal(activeScreen, "position")

    // Fixed distance from the screen edge. Clears the thickest dock the sliders
    // allow (icon 96 + cell padding 2x8 + plate padding 2x14 + edge gap 24 = 164)
    // and is deliberately independent of the current dock geometry.
    readonly property int edgeOffset: {
        const sw = screen ? screen.width : 1920;
        const sh = screen ? screen.height : 1080;
        const room = (panelPosition === "left" || panelPosition === "right")
            ? (sw - implicitWidth) : (sh - implicitHeight);
        return Math.max(0, Math.min(172, room - 8));
    }

    anchors.bottom: panelPosition === "bottom" || panelPosition === ""
    anchors.top: panelPosition === "top"
    anchors.left: panelPosition === "left"
    anchors.right: panelPosition === "right"
    margins.bottom: anchors.bottom ? edgeOffset : 0
    margins.top: anchors.top ? edgeOffset : 0
    margins.left: anchors.left ? edgeOffset : 0
    margins.right: anchors.right ? edgeOffset : 0

    // Measure from the raw screen edge, ignoring the dock's reserved zone,
    // otherwise toggling/resizing a reserving dock would shift the panel.
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell-dock-settings"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

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

    // Design tokens: neutral greys + the KDE accent colour (see Theme.qml)
    readonly property color cCardBg: Theme.surface(isLight)
    readonly property color cCardBorder: Theme.surfaceBorder(isLight)
    readonly property color cGroupBg: Theme.groupFill(isLight)
    readonly property color cGroupBorder: "transparent"
    readonly property color cDivider: Theme.separator(isLight)

    readonly property color cTextPrimary: Theme.textPrimary(isLight)
    readonly property color cTextSecondary: Theme.textSecondary(isLight)
    readonly property color cTextMuted: Theme.textTertiary(isLight)

    readonly property color cAccent: Theme.accent
    readonly property color cAccentHover: Qt.darker(Theme.accent, 1.1)
    readonly property color cAccentBg: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, isLight ? 0.12 : 0.22)
    readonly property color cAccentBorder: "transparent"

    readonly property color cChipBg: Theme.controlFill(isLight)
    readonly property color cChipHover: Theme.pressFill(isLight)
    readonly property color cChipBorder: "transparent"
    readonly property color cChipText: Theme.textPrimary(isLight)


    readonly property var screenOptions: {
        const a = [];
        const s = Quickshell.screens;
        for (let i = 0; s && i < s.length; i++) a.push({ key: s[i].name, label: s[i].name });
        return a;
    }

    // ---- Shared building blocks ----

    // Inset section of a grouped list
    component Group: Rectangle {
        default property alias content: groupCol.data
        width: parent ? parent.width : 400
        height: groupCol.height + 8
        radius: 10
        color: root.cGroupBg

        Column {
            id: groupCol
            x: 14
            y: 4
            width: parent.width - 28
        }
    }

    component Divider: Rectangle {
        width: parent ? parent.width : 0
        height: 1
        color: root.cDivider
    }

    // Segmented control: neutral track, raised segment marks the selection
    component Segmented: Rectangle {
        id: seg
        property var options: []    // [{ key, label }]
        property var current
        property real segWidth: 64
        signal picked(var key)

        readonly property int currentIndex: {
            for (let i = 0; i < options.length; i++)
                if (options[i].key === current) return i;
            return -1;
        }

        width: options.length * segWidth + 4
        height: 26
        radius: 7
        color: Theme.controlFill(root.isLight)

        Rectangle {
            visible: seg.currentIndex >= 0
            x: 2 + Math.max(0, seg.currentIndex) * seg.segWidth
            y: 2
            width: seg.segWidth
            height: seg.height - 4
            radius: 5
            color: root.isLight ? "#ffffff" : Qt.rgba(1, 1, 1, 0.16)
            border.width: root.isLight ? 1 : 0
            border.color: Qt.rgba(0, 0, 0, 0.06)

            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }

        Row {
            x: 2
            y: 2

            Repeater {
                model: seg.options

                Item {
                    required property var modelData
                    required property int index
                    width: seg.segWidth
                    height: seg.height - 4

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 8
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: modelData.label
                        color: index === seg.currentIndex ? root.cTextPrimary : root.cTextSecondary
                        font.pixelSize: 11
                        font.weight: index === seg.currentIndex ? Font.Medium : Font.Normal
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: seg.picked(modelData.key)
                    }
                }
            }
        }
    }

    // Title (+ optional description) on the left, segmented control on the right
    component ChoiceRow: Item {
        id: cr
        property string title: ""
        property string desc: ""
        property alias options: crSeg.options
        property alias current: crSeg.current
        property alias segWidth: crSeg.segWidth
        signal picked(var key)

        width: parent ? parent.width : 400
        height: desc !== "" ? 54 : 44

        Column {
            anchors.left: parent.left
            anchors.right: crSeg.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: cr.title
                color: root.cTextPrimary
                font.pixelSize: 13
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: cr.desc
                color: root.cTextSecondary
                font.pixelSize: 11
                visible: text !== ""
            }
        }

        Segmented {
            id: crSeg
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            onPicked: key => cr.picked(key)
        }
    }

    // Plain push button
    component PushButton: Rectangle {
        id: pb
        property string text: ""
        signal clicked()

        width: pbLabel.implicitWidth + 24
        height: 24
        radius: 6
        color: pbArea.pressed ? Theme.pressFill(root.isLight) : Theme.controlFill(root.isLight)

        Text {
            id: pbLabel
            anchors.centerIn: parent
            text: pb.text
            color: root.cTextPrimary
            font.pixelSize: 12
        }

        MouseArea {
            id: pbArea
            anchors.fill: parent
            onClicked: pb.clicked()
        }
    }

    // Slider row with live thumb tracking and debounced commit
    component SliderRow: Item {
        id: sr
        property string title: ""
        property string desc: ""
        property real min: 0
        property real max: 100
        property real step: 1
        property real value: 0
        property string unit: ""
        property bool percent: false
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

        readonly property string valueText: {
            if (percent) return Math.round(localVal * 100) + "%";
            const decimals = step < 0.1 ? 2 : (step < 1 ? 1 : 0);
            return localVal.toFixed(decimals) + unit;
        }

        width: parent ? parent.width : 400
        height: desc !== "" ? 54 : 44

        Column {
            anchors.left: parent.left
            anchors.right: sliderBox.left
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: sr.title
                color: root.cTextPrimary
                font.pixelSize: 13
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
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
                height: 4
                radius: 2
                color: Theme.trackFill(root.isLight)

                Rectangle {
                    height: parent.height
                    width: parent.width * sliderBox.normalized
                    radius: 2
                    color: root.cAccent
                }
            }

            Rectangle {
                x: (parent.width - 52) * sliderBox.normalized - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18
                radius: 9
                color: dragArea.pressed ? "#f0f0f0" : "#ffffff"
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.15)
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                horizontalAlignment: Text.AlignRight
                text: sr.valueText
                color: root.cTextSecondary
                font.pixelSize: 12
                font.features: { "tnum": 1 }
            }

            MouseArea {
                id: dragArea
                anchors.left: parent.left
                anchors.right: trackBg.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom

                onPressed: mouse => sliderBox.applyMouse(mouse.x)
                onPositionChanged: mouse => {
                    if (pressed) sliderBox.applyMouse(mouse.x);
                }
                onReleased: sr.commit()
                onCanceled: sr.commit()
            }
        }
    }

    // Switch row
    component SwitchRow: Item {
        id: sw
        property string title: ""
        property string desc: ""
        property bool checked: false
        signal toggled(bool next)

        width: parent ? parent.width : 400
        height: desc !== "" ? 54 : 44

        Column {
            anchors.left: parent.left
            anchors.right: toggleBtn.left
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: sw.title
                color: root.cTextPrimary
                font.pixelSize: 13
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
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
            width: 38
            height: 22

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: sw.checked ? root.cAccent : Theme.trackFill(root.isLight)

                Behavior on color { ColorAnimation { duration: 150 } }

                Rectangle {
                    x: sw.checked ? parent.width - width - 2 : 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.height - 4
                    height: width
                    radius: width / 2
                    color: "#ffffff"
                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, 0.08)

                    Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: sw.toggled(!sw.checked)
            }
        }
    }

    // ---- Card ----
    Rectangle {
        id: card
        anchors.fill: parent
        anchors.leftMargin: root.panelPosition === "left" ? 16 : 6
        anchors.rightMargin: root.panelPosition === "right" ? 16 : 6
        anchors.topMargin: root.panelPosition === "top" ? 16 : 6
        anchors.bottomMargin: root.panelPosition === "bottom" ? 16 : 6
        radius: 12
        color: root.cCardBg
        border.width: 1
        border.color: root.cCardBorder

        // ---- Header ----
        Item {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 52

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    text: "Dock"
                    color: root.cTextPrimary
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
                Text {
                    visible: Config.perScreenConfig
                    text: "正在编辑：" + root.selectedScreen
                    color: root.cTextSecondary
                    font.pixelSize: 11
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Segmented {
                    anchors.verticalCenter: parent.verticalCenter
                    segWidth: 48
                    options: [{ key: true, label: "浅色" }, { key: false, label: "深色" }]
                    current: root.isLight
                    onPicked: key => {
                        const scr = Config.perScreenConfig ? root.selectedScreen : null;
                        if (key) Config.applyLightPreset(scr);
                        else Config.applyDarkPreset(scr);
                    }
                }

                PushButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "恢复默认"
                    onClicked: Config.resetDefaults(Config.perScreenConfig ? root.selectedScreen : null)
                }

                // Close
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24
                    radius: 12
                    color: closeArea.containsMouse ? Theme.hoverFill(root.isLight) : "transparent"

                    Repeater {
                        model: [45, -45]
                        Rectangle {
                            required property int modelData
                            anchors.centerIn: parent
                            width: 10
                            height: 1.5
                            radius: 0.75
                            rotation: modelData
                            color: root.cTextSecondary
                        }
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.visible = false
                    }
                }
            }
        }

        // ---- Tabs ----
        Item {
            id: tabBar
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 40

            Segmented {
                anchors.centerIn: parent
                height: 28
                segWidth: (tabBar.width - 32 - 4) / options.length
                options: [
                    { key: 0, label: "位置" },
                    { key: 1, label: "大小" },
                    { key: 2, label: "自动隐藏" },
                    { key: 3, label: "效果" },
                    { key: 4, label: "行为" }
                ]
                current: root.currentTab
                onPicked: key => root.currentTab = key
            }
        }

        // ---- Display picker (per-screen mode with several displays) ----
        Item {
            id: screenBar
            visible: Config.perScreenConfig && root.screenOptions.length > 1
            anchors.top: tabBar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: visible ? 36 : 0

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                text: "显示器"
                color: root.cTextSecondary
                font.pixelSize: 12
            }

            Segmented {
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                segWidth: 96
                options: root.screenOptions
                current: root.selectedScreen
                onPicked: key => root.selectedScreen = key
            }
        }

        // ---- Content ----
        Flickable {
            id: flick
            anchors.top: screenBar.bottom
            anchors.topMargin: 4
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: parent.right
            anchors.rightMargin: 16
            contentHeight: contentCol.height
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Column {
                id: contentCol
                width: flick.width

                // ==================== 位置 ====================
                Column {
                    width: parent.width
                    spacing: 14
                    visible: root.currentTab === 0

                    Group {
                        SwitchRow {
                            title: "每个显示器单独设置"
                            desc: "为每个显示器分别设置位置、大小和外观"
                            checked: Config.perScreenConfig
                            onToggled: next => Config.setPerScreenConfig(next)
                        }
                        Divider { visible: Config.perScreenConfig }
                        SwitchRow {
                            visible: Config.perScreenConfig
                            title: "在此显示器上显示 Dock"
                            desc: root.selectedScreen
                            checked: root.getVal("enabled") !== false
                            onToggled: next => root.setVal("enabled", next)
                        }
                        Divider { visible: Config.perScreenConfig }
                        Item {
                            visible: Config.perScreenConfig
                            width: parent.width
                            height: 44

                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                PushButton {
                                    text: "复制全局设置"
                                    onClicked: Config.copyGlobalToScreen(root.selectedScreen)
                                }
                                PushButton {
                                    text: "还原此显示器"
                                    onClicked: Config.resetScreenConfig(root.selectedScreen)
                                }
                            }
                        }
                    }

                    Group {
                        ChoiceRow {
                            title: "屏幕上的位置"
                            segWidth: 48
                            options: [
                                { key: "left", label: "左侧" },
                                { key: "bottom", label: "底部" },
                                { key: "right", label: "右侧" },
                                { key: "top", label: "顶部" }
                            ]
                            current: root.getVal("position")
                            onPicked: key => root.setVal("position", key)
                        }
                        Divider {}
                        SliderRow {
                            title: "与屏幕边缘的距离"
                            min: 0; max: 24; step: 1
                            value: root.getVal("bottomMargin"); unit: " px"
                            onModified: val => root.setVal("bottomMargin", Math.round(val))
                        }
                    }

                    Group {
                        visible: !Config.perScreenConfig
                        ChoiceRow {
                            title: "显示在"
                            segWidth: 76
                            options: [
                                { key: "all", label: "所有显示器" },
                                { key: "primary", label: "主显示器" },
                                { key: "custom", label: "指定显示器" }
                            ]
                            current: Config.screenMode
                            onPicked: key => Config.setVal("screenMode", key)
                        }
                        Divider { visible: Config.screenMode === "custom" }
                        ChoiceRow {
                            visible: Config.screenMode === "custom"
                            title: "显示器"
                            segWidth: 96
                            options: root.screenOptions
                            current: Config.targetScreen
                            onPicked: key => Config.setVal("targetScreen", key)
                        }
                    }
                }

                // ==================== 大小 ====================
                Column {
                    width: parent.width
                    spacing: 14
                    visible: root.currentTab === 1

                    Group {
                        ChoiceRow {
                            title: "大小"
                            segWidth: 44
                            options: [
                                { key: 32, label: "小" },
                                { key: 44, label: "中" },
                                { key: 56, label: "大" },
                                { key: 72, label: "特大" }
                            ]
                            current: root.getVal("iconSize")
                            onPicked: key => root.setVal("iconSize", key)
                        }
                        Divider {}
                        SliderRow {
                            title: "图标大小"
                            desc: "也可以拖动 Dock 上的分隔线调整，双击还原"
                            min: 24; max: 96; step: 1
                            value: root.getVal("iconSize"); unit: " px"
                            onModified: val => root.setVal("iconSize", Math.round(val))
                        }
                        Divider {}
                        SliderRow {
                            title: "图标内边距"
                            min: 0; max: 8; step: 1
                            value: root.getVal("cellPadding"); unit: " px"
                            onModified: val => root.setVal("cellPadding", Math.round(val))
                        }
                        Divider {}
                        SliderRow {
                            title: "图标间距"
                            min: 0; max: 16; step: 1
                            value: root.getVal("spacing"); unit: " px"
                            onModified: val => root.setVal("spacing", Math.round(val))
                        }
                        Divider {}
                        SliderRow {
                            title: "底板内边距"
                            min: 2; max: 14; step: 1
                            value: root.getVal("dockPadding"); unit: " px"
                            onModified: val => root.setVal("dockPadding", Math.round(val))
                        }
                    }

                    Group {
                        Item {
                            width: parent.width
                            height: 44

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "底板颜色"
                                color: root.cTextPrimary
                                font.pixelSize: 13
                            }

                            Row {
                                anchors.right: parent.right
                                anchors.rightMargin: 3
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 12

                                Repeater {
                                    model: ["#f6f6f6", "#d4d4d6", "#3a3a3c", "#1e1e1e", "#000000"]

                                    Rectangle {
                                        required property string modelData
                                        readonly property bool selected: Qt.colorEqual(root.getVal("backgroundColor"), modelData)
                                        width: 20
                                        height: 20
                                        radius: 10
                                        color: modelData
                                        border.width: 1
                                        border.color: root.isLight ? Qt.rgba(0, 0, 0, 0.15) : Qt.rgba(1, 1, 1, 0.2)

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: parent.width + 6
                                            height: width
                                            radius: width / 2
                                            color: "transparent"
                                            border.width: 2
                                            border.color: root.cAccent
                                            visible: parent.selected
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: -3
                                            onClicked: {
                                                const scr = Config.perScreenConfig ? root.selectedScreen : null;
                                                if (Config.isLightColor(parent.modelData)) Config.applyLightPreset(scr);
                                                else Config.applyDarkPreset(scr);
                                                root.setVal("backgroundColor", parent.modelData);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        Divider {}
                        SliderRow {
                            title: "不透明度"
                            min: 0.1; max: 1.0; step: 0.05; percent: true
                            value: root.getVal("backgroundOpacity")
                            onModified: val => root.setVal("backgroundOpacity", val)
                        }
                        Divider {}
                        SliderRow {
                            title: "圆角"
                            min: 4; max: 26; step: 1
                            value: root.getVal("radius"); unit: " px"
                            onModified: val => root.setVal("radius", Math.round(val))
                        }
                        Divider {}
                        SliderRow {
                            title: "描边粗细"
                            min: 0; max: 3; step: 0.5
                            value: root.getVal("borderWidth"); unit: " px"
                            onModified: val => root.setVal("borderWidth", val)
                        }
                    }
                }

                // ==================== 自动隐藏 ====================
                Column {
                    width: parent.width
                    spacing: 14
                    visible: root.currentTab === 2

                    Group {
                        SwitchRow {
                            title: "自动隐藏和显示 Dock"
                            checked: root.getVal("autoHide")
                            onToggled: val => root.setVal("autoHide", val)
                        }
                    }

                    Group {
                        SliderRow {
                            title: "隐藏后保留的高度"
                            min: 0; max: 32; step: 2
                            value: root.getVal("peekHeight"); unit: " px"
                            onModified: val => root.setVal("peekHeight", Math.round(val))
                        }
                        Divider {}
                        SliderRow {
                            title: "隐藏后的不透明度"
                            desc: "设为 0 则完全隐藏"
                            min: 0.0; max: 1.0; step: 0.05; percent: true
                            value: root.getVal("peekOpacity")
                            onModified: val => root.setVal("peekOpacity", val)
                        }
                        Divider {}
                        SliderRow {
                            title: "唤出区域高度"
                            desc: "鼠标距屏幕边缘多近时显示 Dock"
                            min: 4; max: 24; step: 2
                            value: root.getVal("triggerHeight"); unit: " px"
                            onModified: val => root.setVal("triggerHeight", Math.round(val))
                        }
                    }

                    Group {
                        SliderRow {
                            title: "隐藏延迟"
                            min: 100; max: 1000; step: 50
                            value: root.getVal("hideDelay"); unit: " ms"
                            onModified: val => root.setVal("hideDelay", Math.round(val))
                        }
                        Divider {}
                        SliderRow {
                            title: "动画时长"
                            min: 50; max: 300; step: 25
                            value: root.getVal("slideDuration"); unit: " ms"
                            onModified: val => root.setVal("slideDuration", Math.round(val))
                        }
                    }
                }

                // ==================== 效果 ====================
                Column {
                    width: parent.width
                    spacing: 14
                    visible: root.currentTab === 3

                    Group {
                        SwitchRow {
                            title: "放大"
                            checked: root.getVal("hoverMagnify")
                            onToggled: val => root.setVal("hoverMagnify", val)
                        }
                        Divider {}
                        SliderRow {
                            title: "放大倍率"
                            min: 1.05; max: 1.8; step: 0.02
                            value: root.getVal("hoverScale"); unit: "×"
                            onModified: val => root.setVal("hoverScale", val)
                        }
                        Divider {}
                        SliderRow {
                            title: "放大范围"
                            desc: "受影响的相邻图标数量"
                            min: 1.2; max: 3.5; step: 0.1
                            value: root.getVal("waveSpread")
                            onModified: val => root.setVal("waveSpread", val)
                        }
                    }

                    Group {
                        SwitchRow {
                            title: "启动时弹跳"
                            checked: root.getVal("bounceOnLaunch")
                            onToggled: val => root.setVal("bounceOnLaunch", val)
                        }
                        Divider {}
                        SwitchRow {
                            title: "圆形图标"
                            desc: "将所有图标统一为圆形"
                            checked: root.getVal("circularIcons")
                            onToggled: val => root.setVal("circularIcons", val)
                        }
                        Divider {}
                        SwitchRow {
                            title: "顶部高光"
                            checked: root.getVal("glassHighlight")
                            onToggled: val => root.setVal("glassHighlight", val)
                        }
                        Divider {}
                        SwitchRow {
                            title: "阴影"
                            checked: root.getVal("shadowEnabled")
                            onToggled: val => root.setVal("shadowEnabled", val)
                        }
                    }

                    Group {
                        SwitchRow {
                            title: "贴边圆角"
                            desc: "Dock 贴边时两端向外过渡"
                            checked: root.getVal("edgeCorners")
                            onToggled: val => root.setVal("edgeCorners", val)
                        }
                        Divider {}
                        SliderRow {
                            title: "贴边圆角大小"
                            min: 4; max: 24; step: 2
                            value: root.getVal("cornerSize"); unit: " px"
                            onModified: val => root.setVal("cornerSize", Math.round(val))
                        }
                    }
                }

                // ==================== 行为 ====================
                Column {
                    width: parent.width
                    spacing: 14
                    visible: root.currentTab === 4

                    Group {
                        ChoiceRow {
                            title: "固定项来源"
                            segWidth: 92
                            options: [
                                { key: "kickoff", label: "Kickoff 收藏" },
                                { key: "taskmanager", label: "任务栏固定项" }
                            ]
                            current: root.getVal("source")
                            onPicked: key => root.setVal("source", key)
                        }
                        Divider {}
                        SwitchRow {
                            title: "显示未固定的运行中应用"
                            checked: root.getVal("showRunningApps")
                            onToggled: val => root.setVal("showRunningApps", val)
                        }
                        Divider {}
                        SwitchRow {
                            title: "显示废纸篓"
                            checked: root.getVal("showTrash")
                            onToggled: val => root.setVal("showTrash", val)
                        }
                        Divider {}
                        SwitchRow {
                            title: "为 Dock 预留空间"
                            desc: "最大化的窗口不会覆盖 Dock"
                            checked: root.getVal("reserveSpace")
                            onToggled: val => root.setVal("reserveSpace", val)
                        }
                    }

                    Group {
                        SwitchRow {
                            title: "显示运行指示点"
                            checked: root.getVal("runningIndicator")
                            onToggled: val => root.setVal("runningIndicator", val)
                        }
                        Divider {}
                        SliderRow {
                            title: "指示点最多显示"
                            min: 1; max: 5; step: 1
                            value: root.getVal("indicatorMaxDots"); unit: " 个"
                            onModified: val => root.setVal("indicatorMaxDots", Math.round(val))
                        }
                    }

                    Group {
                        SwitchRow {
                            title: "点击切换窗口"
                            desc: "有多个窗口时，重复点击依次切换"
                            checked: root.getVal("raiseRunning")
                            onToggled: val => root.setVal("raiseRunning", val)
                        }
                        Divider {}
                        SwitchRow {
                            title: "点击当前窗口时最小化"
                            desc: "仅在应用只有一个窗口时生效"
                            checked: root.getVal("minimizeActive")
                            onToggled: val => root.setVal("minimizeActive", val)
                        }
                        Divider {}
                        SwitchRow {
                            title: "悬停时显示新建窗口按钮"
                            checked: root.getVal("newInstanceButton")
                            onToggled: val => root.setVal("newInstanceButton", val)
                        }
                    }
                }
            }
        }
    }
}
