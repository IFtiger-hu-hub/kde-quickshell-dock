import QtQuick
import QtQuick.Effects

// A stunning, immersive macOS frosted glass card with an enlarged Gaussian-blurred icon artwork backdrop
Item {
    id: root

    property var winData: null
    property var dockRef: null
    property var cellRef: null

    readonly property bool isLight: dockRef ? dockRef.isLight : false
    readonly property bool circularIcons: dockRef ? dockRef.circularIcons : Config.circularIcons
    readonly property bool isActive: {
        Tasks.revision;
        if (winData && winData.modelIndex) {
            return Tasks.isWindowActive(winData.modelIndex);
        }
        return winData ? winData.active === true : false;
    }
    readonly property bool isMinimized: {
        Tasks.revision;
        if (winData && winData.modelIndex) {
            return Tasks.isWindowMinimized(winData.modelIndex);
        }
        return winData ? winData.minimized === true : false;
    }

    readonly property var targetEntry: (cellRef && cellRef.entry)
        ? cellRef.entry
        : Tasks.resolveEntry(dockRef ? dockRef.expandedAppKey : "")

    // App name & icon resolution with full fallback chain
    readonly property string appName: (targetEntry && targetEntry.name)
        ? targetEntry.name
        : (cellRef && cellRef.appId ? cellRef.appId : (dockRef ? dockRef.expandedAppKey : ""))

    readonly property string resolvedIcon: {
        if (cellRef && cellRef.resolvedIcon && cellRef.resolvedIcon !== "") {
            return cellRef.resolvedIcon;
        }
        if (cellRef && cellRef.content && cellRef.content.iconSource && cellRef.content.iconSource !== "") {
            return cellRef.content.iconSource;
        }
        if (targetEntry) {
            const list = IconResolver.candidates(targetEntry);
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

    readonly property bool isVertical: dockRef ? dockRef.isVertical : false
    readonly property string dockPosition: dockRef ? dockRef.dockPosition : "bottom"

    readonly property string screenLabel: {
        const screens = Quickshell.screens;
        if (!screens || screens.length <= 1) return "";
        const sg = (winData && winData.screenGeometry) ? winData.screenGeometry : null;
        const wg = (winData && winData.geometry) ? winData.geometry : null;
        for (let i = 0; i < screens.length; i++) {
            const sc = screens[i];
            if (!sc) continue;
            // 1. Direct name match if present
            if (sg && sg.name && sc.name && sg.name === sc.name) return sc.name;
            // 2. Exact screen origin match
            if (sg && typeof sg.x !== "undefined" && typeof sc.x !== "undefined" && sc.x === sg.x && sc.y === sg.y) {
                return sc.name || ("屏幕 " + (i + 1));
            }
            // 3. Screen geometry containment
            if (sg && typeof sg.x !== "undefined" && typeof sc.x !== "undefined") {
                const cx = sg.x + (sg.width || 0) / 2;
                const cy = sg.y + (sg.height || 0) / 2;
                if (cx >= sc.x && cx < (sc.x + sc.width) && cy >= sc.y && cy < (sc.y + sc.height)) {
                    return sc.name || ("屏幕 " + (i + 1));
                }
            }
            // 4. Window geometry center fallback
            if (wg && typeof wg.x !== "undefined" && typeof sc.x !== "undefined") {
                const wcx = wg.x + (wg.width || 0) / 2;
                const wcy = wg.y + (wg.height || 0) / 2;
                if (wcx >= sc.x && wcx < (sc.x + sc.width) && wcy >= sc.y && wcy < (sc.y + sc.height)) {
                    return sc.name || ("屏幕 " + (i + 1));
                }
            }
        }
        return "";
    }

    readonly property string screenNumber: {
        const screens = Quickshell.screens;
        if (!screens || screens.length <= 1) return "";
        const sg = (winData && winData.screenGeometry) ? winData.screenGeometry : null;
        const wg = (winData && winData.geometry) ? winData.geometry : null;
        for (let i = 0; i < screens.length; i++) {
            const sc = screens[i];
            if (!sc) continue;
            if (sg && sg.name && sc.name && sg.name === sc.name) return String(i + 1);
            if (sg && typeof sg.x !== "undefined" && typeof sc.x !== "undefined" && sc.x === sg.x && sc.y === sg.y) {
                return String(i + 1);
            }
            if (sg && typeof sg.x !== "undefined" && typeof sc.x !== "undefined") {
                const cx = sg.x + (sg.width || 0) / 2;
                const cy = sg.y + (sg.height || 0) / 2;
                if (cx >= sc.x && cx < (sc.x + sc.width) && cy >= sc.y && cy < (sc.y + sc.height)) {
                    return String(i + 1);
                }
            }
            if (wg && typeof wg.x !== "undefined" && typeof sc.x !== "undefined") {
                const wcx = wg.x + (wg.width || 0) / 2;
                const wcy = wg.y + (wg.height || 0) / 2;
                if (wcx >= sc.x && wcx < (sc.x + sc.width) && wcy >= sc.y && wcy < (sc.y + sc.height)) {
                    return String(i + 1);
                }
            }
        }
        return "";
    }

    width: isVertical ? (dockRef ? dockRef.cardHeight : 44) : (dockRef ? dockRef.cardWidth : 230)
    height: dockRef ? dockRef.cardHeight : 44

    // Smooth press and hover scaling
    scale: cardMouse.pressed ? 0.97 : 1.0
    Behavior on scale {
        NumberAnimation { duration: 130; easing.type: Easing.OutQuad }
    }

    // Mask plate for rounded corner clipping
    Rectangle {
        id: maskPlate
        width: Math.max(1, root.width)
        height: Math.max(1, root.height)
        radius: root.isVertical ? Math.min(10, Math.round(root.width / 4)) : 12
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
                width: Math.max(1, Math.max(parent.width, parent.height) * 1.1)
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
                visible: root.width > 0 && root.height > 0
                blurEnabled: true
                blur: 1.0
                blurMax: 48
                saturation: 0.35
                maskEnabled: true
                maskSource: maskPlate
                opacity: root.isLight ? 0.20 : 0.30
            }
        }

        // Layer 2: Frosted glass tinted plate
        Rectangle {
            id: glassPlate
            anchors.fill: parent
            radius: root.isVertical ? Math.min(10, Math.round(root.width / 4)) : 12

            color: root.isActive
                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, root.isLight ? 0.12 : 0.20)
                : (cardMouse.containsMouse
                    ? (root.isLight ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(0.20, 0.20, 0.21, 0.85))
                    : (root.isLight ? Qt.rgba(1, 1, 1, 0.70) : Qt.rgba(0.14, 0.14, 0.15, 0.78)))

            border.width: 1
            border.color: root.isActive
                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.55)
                : Theme.surfaceBorder(root.isLight)

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }
        }

        // Card MouseArea: Handles hover and activation clicks across the card surface
        MouseArea {
            id: cardMouse
            anchors.fill: parent
            hoverEnabled: true
            z: 0

            onEntered: {
                if (root.dockRef) root.dockRef.hoveredWindowCard = root;
            }
            onExited: {
                if (root.dockRef && root.dockRef.hoveredWindowCard === root) {
                    root.dockRef.hoveredWindowCard = null;
                }
            }
            onClicked: mouse => {
                // Dual-layer safety: if click fell inside closeBtn or vertCloseBtn, route to closeWindow!
                if (!root.isVertical && closeBtn.visible) {
                    const pt = closeBtn.mapToItem(cardMouse, 0, 0);
                    if (mouse.x >= pt.x - 4 && mouse.x <= pt.x + closeBtn.width + 4 &&
                        mouse.y >= pt.y - 4 && mouse.y <= pt.y + closeBtn.height + 4) {
                        if (root.dockRef && root.dockRef.hoveredWindowCard === root) {
                            root.dockRef.hoveredWindowCard = null;
                        }
                        if (root.winData && root.winData.modelIndex) {
                            Tasks.closeWindow(root.winData.modelIndex);
                        }
                        return;
                    }
                } else if (root.isVertical && vertCloseBtn.visible) {
                    const ptV = vertCloseBtn.mapToItem(cardMouse, 0, 0);
                    if (mouse.x >= ptV.x - 4 && mouse.x <= ptV.x + vertCloseBtn.width + 4 &&
                        mouse.y >= ptV.y - 4 && mouse.y <= ptV.y + vertCloseBtn.height + 4) {
                        if (root.dockRef && root.dockRef.hoveredWindowCard === root) {
                            root.dockRef.hoveredWindowCard = null;
                        }
                        if (root.winData && root.winData.modelIndex) {
                            Tasks.closeWindow(root.winData.modelIndex);
                        }
                        return;
                    }
                }

                if (root.winData && root.winData.modelIndex) {
                    Tasks.activateWindow(root.winData.modelIndex);
                }
                if (root.dockRef) {
                    root.dockRef.hoveredWindowCard = null;
                    root.dockRef.expandedAppKey = "";
                }
            }
        }

        // Layer 3A: Foreground Content for Horizontal Dock (!isVertical)
        Row {
            id: horizontalRow
            visible: !root.isVertical
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10
            z: 1

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
                    visible: !root.circularIcons
                }

                CircleIcon {
                    id: fgIcon
                    anchors.fill: parent
                    source: root.resolvedIcon
                    circular: root.circularIcons
                    isLight: root.isLight
                    renderSize: 56
                }
            }

            // Window Details Column
            Column {
                id: infoCol
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 28 - (closeBtn.visible ? 26 : 6) - 10
                spacing: 2

                // Top: app name, plus "已最小化" and screen label when relevant
                Text {
                    width: parent.width
                    text: (root.appName !== "" ? root.appName : "应用")
                        + (root.isMinimized ? " · 已最小化" : "")
                        + (root.screenLabel ? (" · " + root.screenLabel) : "")
                    color: Theme.textSecondary(root.isLight)
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }

                // Bottom: Actual Window Title
                Text {
                    id: titleText
                    width: parent.width
                    text: root.windowTitle
                    color: Theme.textPrimary(root.isLight)
                    font.pixelSize: 12
                    font.weight: root.isActive ? Font.DemiBold : Font.Normal
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
                z: 10

                Rectangle {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    radius: 10
                    color: closeMouse.containsMouse ? Theme.destructive : (root.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.12))
                    scale: closeMouse.pressed ? 0.88 : 1.0

                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on scale { NumberAnimation { duration: 80 } }

                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -0.5
                        text: "×"
                        font.pixelSize: 13
                        font.bold: true
                        color: closeMouse.containsMouse ? "#ffffff" : Theme.textSecondary(root.isLight)
                    }
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    preventStealing: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        mouse.accepted = true;
                        if (root.dockRef && root.dockRef.hoveredWindowCard === root) {
                            root.dockRef.hoveredWindowCard = null;
                        }
                        if (root.winData && root.winData.modelIndex) {
                            Tasks.closeWindow(root.winData.modelIndex);
                        }
                    }
                }
            }
        }

        // Layer 3B: Foreground Content for Vertical Dock (isVertical)
        Item {
            id: verticalBox
            visible: root.isVertical
            anchors.fill: parent
            z: 1

            // Crisp Centered App Icon
            Item {
                anchors.centerIn: parent
                width: Math.max(18, Math.min(26, root.width - 12))
                height: width
                opacity: root.isMinimized ? 0.60 : 1.0

                Rectangle {
                    anchors.fill: parent
                    radius: 5
                    color: "#25000000"
                    y: 1
                    z: -1
                    visible: !root.circularIcons
                }

                CircleIcon {
                    anchors.fill: parent
                    source: root.resolvedIcon
                    circular: root.circularIcons
                    isLight: root.isLight
                    renderSize: 48
                }
            }

            // Active accent indicator dot at the bottom
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 3
                width: 4
                height: 4
                radius: 2
                color: Theme.accent
                visible: root.isActive
            }

            // Multi-screen number indicator badge in bottom-left
            Text {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.leftMargin: 3
                anchors.bottomMargin: 1
                text: root.screenNumber
                font.pixelSize: 8
                font.weight: Font.DemiBold
                color: Theme.textSecondary(root.isLight)
                visible: Quickshell.screens && Quickshell.screens.length > 1 && root.screenNumber !== ""
            }

            // Corner Close Button on hover
            Item {
                id: vertCloseBtn
                width: 16
                height: 16
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 2
                anchors.rightMargin: 2
                visible: cardMouse.containsMouse || vertCloseMouse.containsMouse
                z: 10

                Rectangle {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    radius: 7
                    color: vertCloseMouse.containsMouse ? Theme.destructive : Qt.rgba(0, 0, 0, 0.50)
                    scale: vertCloseMouse.pressed ? 0.88 : 1.0

                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on scale { NumberAnimation { duration: 80 } }

                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -0.5
                        text: "×"
                        font.pixelSize: 11
                        font.bold: true
                        color: "#ffffff"
                    }
                }

                MouseArea {
                    id: vertCloseMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    preventStealing: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        mouse.accepted = true;
                        if (root.dockRef && root.dockRef.hoveredWindowCard === root) {
                            root.dockRef.hoveredWindowCard = null;
                        }
                        if (root.winData && root.winData.modelIndex) {
                            Tasks.closeWindow(root.winData.modelIndex);
                        }
                    }
                }
            }
        }
    }
}
