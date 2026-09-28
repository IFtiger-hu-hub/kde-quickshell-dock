import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

PanelWindow {
    id: dock

    readonly property string screenName: screen ? screen.name : ""

    // Multi-Screen independent configuration: resolves screen overrides or global defaults
    readonly property string dockPosition: Config.getVal(screenName, "position")
    readonly property int iconSize: Config.getVal(screenName, "iconSize")
    readonly property int cellPadding: Config.getVal(screenName, "cellPadding")
    readonly property int spacing: Config.getVal(screenName, "spacing")
    readonly property int dockPadding: Config.getVal(screenName, "dockPadding")
    readonly property int bottomMargin: Config.getVal(screenName, "bottomMargin")
    readonly property int radius: Config.getVal(screenName, "radius")
    readonly property bool autoHide: Config.getVal(screenName, "autoHide")
    readonly property int peekHeight: Config.getVal(screenName, "peekHeight")
    readonly property real peekOpacity: Config.getVal(screenName, "peekOpacity")
    readonly property int triggerHeight: Config.getVal(screenName, "triggerHeight")
    readonly property int hideDelay: Config.getVal(screenName, "hideDelay")
    readonly property int revealGrace: Config.getVal(screenName, "revealGrace")
    readonly property int slideDuration: Config.getVal(screenName, "slideDuration")
    readonly property bool reserveSpace: Config.getVal(screenName, "reserveSpace")
    readonly property bool hoverMagnify: Config.getVal(screenName, "hoverMagnify")
    readonly property real hoverScale: Config.getVal(screenName, "hoverScale")
    readonly property real waveSpread: Config.getVal(screenName, "waveSpread")
    readonly property bool bounceOnLaunch: Config.getVal(screenName, "bounceOnLaunch")
    readonly property bool runningIndicator: Config.getVal(screenName, "runningIndicator")
    readonly property int indicatorDotSize: Config.getVal(screenName, "indicatorDotSize")
    readonly property int indicatorActiveDotSize: Config.getVal(screenName, "indicatorActiveDotSize")
    readonly property color indicatorColor: Config.getVal(screenName, "indicatorColor")
    readonly property color indicatorActiveColor: Config.getVal(screenName, "indicatorActiveColor")
    readonly property color backgroundColor: Config.getVal(screenName, "backgroundColor")
    readonly property real backgroundOpacity: Config.getVal(screenName, "backgroundOpacity")
    readonly property color background: Qt.rgba(backgroundColor.r, backgroundColor.g, backgroundColor.b, backgroundOpacity)
    readonly property color border: Config.getVal(screenName, "border")
    readonly property real borderWidth: Config.getVal(screenName, "borderWidth")
    readonly property bool glassHighlight: Config.getVal(screenName, "glassHighlight")
    readonly property bool shadowEnabled: Config.getVal(screenName, "shadowEnabled")
    readonly property bool showTrash: Config.getVal(screenName, "showTrash")
    readonly property bool showRunningApps: Config.getVal(screenName, "showRunningApps")
    readonly property bool raiseRunning: Config.getVal(screenName, "raiseRunning")
    readonly property bool minimizeActive: Config.getVal(screenName, "minimizeActive")
    readonly property bool edgeCorners: Config.getVal(screenName, "edgeCorners")
    readonly property int cornerSize: Config.getVal(screenName, "cornerSize")
    readonly property real peekFilletShare: Config.getVal(screenName, "peekFilletShare")
    readonly property bool newInstanceButton: Config.getVal(screenName, "newInstanceButton")
    readonly property int newInstanceSize: Config.getVal(screenName, "newInstanceSize")
    readonly property int newInstanceGap: Config.getVal(screenName, "newInstanceGap")
    readonly property int newInstanceStroke: Config.getVal(screenName, "newInstanceStroke")

    readonly property int cellSize: iconSize + cellPadding * 2

    // Direction & orientation derived from screen dockPosition
    readonly property bool isVertical: dockPosition === "left" || dockPosition === "right"
    readonly property bool isBottom: dockPosition === "bottom"
    readonly property bool isTop: dockPosition === "top"
    readonly property bool isLeft: dockPosition === "left"
    readonly property bool isRight: dockPosition === "right"

    // Headroom inward from the dock plate
    readonly property int headroom: isVertical
        ? Math.max(140, Math.ceil(cellSize * (hoverScale - 1)) + 40)
        : Math.max(48, Math.ceil(cellSize * (hoverScale - 1)) + 36)

    readonly property int plateHeight: cellSize + dockPadding * 2
    readonly property int appsWidth: orderModel.count > 0
        ? (orderModel.count * cellSize + Math.max(0, orderModel.count - 1) * spacing)
        : 0

    readonly property int separatorWidth: 1
    readonly property int separatorMargin: Math.max(5, spacing * 1.5)
    readonly property int separatorTotalWidth: separatorMargin * 2 + separatorWidth
    readonly property int trashWidth: showTrash ? cellSize : 0
    readonly property int trashGap: showTrash ? spacing : 0
    readonly property int rightSectionWidth: separatorTotalWidth + trashWidth + trashGap + cellSize
    readonly property int plateWidth: Math.max(
        cellSize + dockPadding * 2,
        appsWidth + (appsWidth > 0 ? rightSectionWidth : (trashWidth + trashGap + cellSize)) + dockPadding * 2)

    // auto-hide
    readonly property int gap: autoHide ? 0 : bottomMargin
    readonly property bool cornersActive: edgeCorners && gap === 0
    readonly property int cornerSizeVal: cornersActive ? cornerSize : 0
    readonly property int hiddenOffset: plateHeight - peekHeight

    readonly property real slideProgress: {
        if (hiddenOffset <= 0) return 0;
        if (isBottom) return Math.max(0, Math.min(1, plate.y / hiddenOffset));
        if (isTop) return Math.max(0, Math.min(1, (gap - plate.y) / hiddenOffset));
        if (isLeft) return Math.max(0, Math.min(1, (gap - plate.x) / hiddenOffset));
        if (isRight) return Math.max(0, Math.min(1, plate.x / hiddenOffset));
        return 0;
    }

    readonly property real visiblePlateHeight: plateHeight - (hiddenOffset * slideProgress)
    readonly property real plateTopRadius: Math.min(radius, visiblePlateHeight)
    readonly property real activeCornerSize: cornersActive
        ? Math.max(0, Math.min(cornerSize,
                               visiblePlateHeight * peekFilletShare,
                               visiblePlateHeight - plateTopRadius))
        : 0
    readonly property real plateBottomRadius: cornersActive ? 0 : radius

    readonly property string silhouettePath: {
        if (!cornersActive || gap > 0) {
            const pw = plate.width;
            const ph = plate.height;
            const px = plate.x;
            const py = plate.y;
            const r = Math.min(radius, pw / 2, ph / 2);
            return "M " + (px + r) + " " + py +
                   " L " + (px + pw - r) + " " + py +
                   " A " + r + " " + r + " 0 0 1 " + (px + pw) + " " + (py + r) +
                   " L " + (px + pw) + " " + (py + ph - r) +
                   " A " + r + " " + r + " 0 0 1 " + (px + pw - r) + " " + (py + ph) +
                   " L " + (px + r) + " " + (py + ph) +
                   " A " + r + " " + r + " 0 0 1 " + px + " " + (py + ph - r) +
                   " L " + px + " " + (py + r) +
                   " A " + r + " " + r + " 0 0 1 " + (px + r) + " " + py + " Z";
        }

        const o = cornerSizeVal;
        const r = plateTopRadius;
        const f = activeCornerSize;
        const rb = plateBottomRadius;

        if (isBottom) {
            const left = o;
            const right = o + body.width;
            const top = plate.y;
            const bottom = body.height;
            const p = ["M " + (left + r) + " " + top, "L " + (right - r) + " " + top];
            if (r > 0) p.push("A " + r + " " + r + " 0 0 1 " + right + " " + (top + r));
            if (f > 0) {
                p.push("L " + right + " " + (bottom - f));
                p.push("A " + f + " " + f + " 0 0 0 " + (right + f) + " " + bottom);
                p.push("L " + (left - f) + " " + bottom);
                p.push("A " + f + " " + f + " 0 0 0 " + left + " " + (bottom - f));
            } else if (rb > 0) {
                p.push("L " + right + " " + (bottom - rb));
                p.push("A " + rb + " " + rb + " 0 0 1 " + (right - rb) + " " + bottom);
                p.push("L " + (left + rb) + " " + bottom);
                p.push("A " + rb + " " + rb + " 0 0 1 " + left + " " + (bottom - rb));
            } else {
                p.push("L " + right + " " + bottom, "L " + left + " " + bottom);
            }
            p.push("L " + left + " " + (top + r));
            if (r > 0) p.push("A " + r + " " + r + " 0 0 1 " + (left + r) + " " + top);
            p.push("Z");
            return p.join(" ");
        }

        if (isTop) {
            const left = o;
            const right = o + body.width;
            const top = 0;
            const bottom = plate.y + plateHeight;
            const p = [];
            if (f > 0) {
                p.push("M " + (left - f) + " " + top);
                p.push("L " + (right + f) + " " + top);
                p.push("A " + f + " " + f + " 0 0 0 " + right + " " + (top + f));
            } else {
                p.push("M " + left + " " + top);
                p.push("L " + right + " " + top);
            }
            p.push("L " + right + " " + (bottom - r));
            if (r > 0) p.push("A " + r + " " + r + " 0 0 1 " + (right - r) + " " + bottom);
            p.push("L " + (left + r) + " " + bottom);
            if (r > 0) p.push("A " + r + " " + r + " 0 0 1 " + left + " " + (bottom - r));
            if (f > 0) {
                p.push("L " + left + " " + (top + f));
                p.push("A " + f + " " + f + " 0 0 0 " + (left - f) + " " + top);
            } else {
                p.push("L " + left + " " + top);
            }
            p.push("Z");
            return p.join(" ");
        }

        if (isLeft) {
            const top = o;
            const bottom = o + body.height;
            const left = 0;
            const right = plate.x + plateHeight;
            const p = [];
            if (f > 0) {
                p.push("M " + left + " " + (top - f));
                p.push("A " + f + " " + f + " 0 0 0 " + (left + f) + " " + top);
            } else {
                p.push("M " + left + " " + top);
            }
            p.push("L " + (right - r) + " " + top);
            if (r > 0) p.push("A " + r + " " + r + " 0 0 1 " + right + " " + (top + r));
            p.push("L " + right + " " + (bottom - r));
            if (r > 0) p.push("A " + r + " " + r + " 0 0 1 " + (right - r) + " " + bottom);
            if (f > 0) {
                p.push("L " + (left + f) + " " + bottom);
                p.push("A " + f + " " + f + " 0 0 0 " + left + " " + (bottom + f));
            } else {
                p.push("L " + left + " " + bottom);
            }
            p.push("L " + left + " " + (f > 0 ? (top - f) : top));
            p.push("Z");
            return p.join(" ");
        }

        if (isRight) {
            const top = o;
            const bottom = o + body.height;
            const right = body.width;
            const left = plate.x;
            const p = ["M " + (left + r) + " " + top];
            if (f > 0) {
                p.push("L " + (right - f) + " " + top);
                p.push("A " + f + " " + f + " 0 0 0 " + right + " " + (top - f));
                p.push("L " + right + " " + (bottom + f));
                p.push("A " + f + " " + f + " 0 0 0 " + (right - f) + " " + bottom);
            } else {
                p.push("L " + right + " " + top);
                p.push("L " + right + " " + bottom);
            }
            p.push("L " + (left + r) + " " + bottom);
            if (r > 0) p.push("A " + r + " " + r + " 0 0 1 " + left + " " + (bottom - r));
            p.push("L " + left + " " + (top + r));
            if (r > 0) p.push("A " + r + " " + r + " 0 0 1 " + (left + r) + " " + top);
            p.push("Z");
            return p.join(" ");
        }

        return "";
    }

    readonly property real plateOpacity: 1 - slideProgress * (1 - peekOpacity)

    property bool revealed: !autoHide
    property bool interacting: false
    property var hoveredCell: null
    property bool settingsOpen: false

    // ---- Continuous Parabolic Wave Engine --------------------------------
    property real pointerPos: -10000
    property bool pointerInside: false

    function updatePointer(coord) {
        pointerPos = coord;
        pointerInside = true;
        waveLeaveTimer.stop();
    }

    function schedulePointerLeave() {
        waveLeaveTimer.restart();
    }

    Timer {
        id: waveLeaveTimer
        interval: 90
        onTriggered: {
            dock.pointerInside = false;
            dock.pointerPos = -10000;
        }
    }

    readonly property bool wantRevealed: !autoHide
        || bodyHover.hovered
        || hoveredCell !== null
        || pointerInside
        || launchArea.containsMouse
        || settingsMouseArea.containsMouse
        || (showTrash && trashMouseArea.containsMouse)
        || interacting
        || dock.settingsOpen
        || contextMenu.visible
        || trashMenu.visible

    onWantRevealedChanged: {
        if (wantRevealed) {
            hideTimer.stop();
            revealed = true;
        } else if (!graceTimer.running) {
            hideTimer.restart();
        }
    }

    onRevealedChanged: if (revealed) graceTimer.restart();

    // ---- new-instance button ---------------------------------------------
    property var launchCell: null
    onHoveredCellChanged: if (hoveredCell) launchCell = hoveredCell;

    readonly property bool launchWanted: newInstanceButton
        && revealed
        && launchCell !== null
        && launchCell.running
        && (hoveredCell === launchCell || launchArea.containsMouse)

    property bool launchShown: false

    Timer {
        id: launchTimer
        interval: 120
        onTriggered: dock.launchShown = dock.launchWanted
    }

    onLaunchWantedChanged: {
        if (launchWanted) {
            dock.launchShown = true;
            launchTimer.stop();
        } else {
            launchTimer.restart();
        }
    }

    Timer {
        id: hideTimer
        interval: hideDelay
        onTriggered: dock.revealed = false
    }

    Timer {
        id: graceTimer
        interval: revealGrace
        onTriggered: if (!dock.wantRevealed) dock.revealed = false;
    }

    // ---- window anchors & layer shell -------------------------------------
    anchors.bottom: isBottom
    anchors.top: isTop
    anchors.left: isLeft
    anchors.right: isRight
    margins.bottom: 0
    margins.top: 0
    margins.left: 0
    margins.right: 0

    implicitWidth: isVertical ? (plateHeight + headroom + gap) : (plateWidth + cornerSizeVal * 2)
    implicitHeight: isVertical ? (plateWidth + cornerSizeVal * 2) : (plateHeight + headroom + gap)

    color: "transparent"

    // Reserves screen space when floating without auto-hide
    exclusiveZone: !reserveSpace ? 0
                 : autoHide ? peekHeight
                 : plateHeight + gap

    readonly property int plateTop: body.y + plate.y

    mask: Region {
        x: isLeft ? 0 : isRight ? Math.min(body.x + plate.x, dock.width - Math.max(peekHeight, triggerHeight)) : body.x
        y: isTop ? 0 : isBottom ? Math.min(body.y + plate.y, dock.height - Math.max(peekHeight, triggerHeight)) : body.y
        width: isLeft ? Math.max(body.x + plate.x + dock.plateHeight, Math.max(peekHeight, triggerHeight))
             : isRight ? (dock.width - x)
             : body.width
        height: isTop ? Math.max(body.y + plate.y + dock.plateHeight, Math.max(peekHeight, triggerHeight))
              : isBottom ? (dock.height - y)
              : body.height

        Region {
            item: dock.launchShown ? launcher : null
            x: launcher.x
            y: launcher.y
            width: dock.launchShown ? launcher.width : 0
            height: dock.launchShown ? launcher.height : 0
        }
    }

    // Hardware-accelerated background blur via KWin
    BackgroundEffect.blurRegion: Region {
        item: plate
    }

    WlrLayershell.namespace: "quickshell-dock"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    property var _preloadRecent: RecentFiles.recentMap
    // id -> DesktopEntry, kept alongside the ListModel (which holds ids only).
    property var entryMap: ({})

    // ---- model sync -------------------------------------------------------
    function syncModel() {
        const favourites = PlasmaFavorites.entries;
        const map = ({});
        for (const f of favourites) map[f.id] = f.entry;

        const desired = DockOrder.merge(favourites.map(f => f.id));

        if (dock.showRunningApps) {
            const runningKeys = Object.keys(Tasks.apps);
            for (const key of runningKeys) {
                if (Tasks.windowCount(key) <= 0) continue;

                let alreadyPresent = false;
                for (let i = 0; i < desired.length; i++) {
                    const existingId = desired[i];
                    if (existingId === key || Tasks.key(existingId) === key) {
                        alreadyPresent = true;
                        if (!map[key] && map[existingId]) map[key] = map[existingId];
                        break;
                    }
                }

                if (!alreadyPresent) {
                    const entry = Tasks.resolveEntry(key);
                    if (entry) {
                        map[key] = entry;
                        desired.push(key);
                    }
                }
            }
        }

        dock.entryMap = map;

        let same = desired.length === orderModel.count;
        if (same) {
            for (let i = 0; i < desired.length; i++) {
                if (orderModel.get(i).appId !== desired[i]) { same = false; break; }
            }
        }
        if (same) return;

        orderModel.clear();
        for (const id of desired) orderModel.append({ appId: id });
    }

    function persistOrder() {
        const favIds = ({});
        for (const f of PlasmaFavorites.entries) favIds[f.id] = true;

        const ids = [];
        for (let i = 0; i < orderModel.count; i++) {
            const id = orderModel.get(i).appId;
            if (favIds[id]) ids.push(id);
        }
        DockOrder.save(ids);
    }

    Connections {
        target: PlasmaFavorites
        function onEntriesChanged() { dock.syncModel(); }
    }

    Connections {
        target: DockOrder
        function onReadyChanged() { dock.syncModel(); }
    }

    Connections {
        target: Tasks
        function onAppsChanged() { dock.syncModel(); }
    }

    Connections {
        target: Config
        function onShowRunningAppsChanged() { dock.syncModel(); }
        function onShowTrashChanged() { dock.syncModel(); }
    }

    Component.onCompleted: syncModel()

    ListModel { id: orderModel }

    // ---- chrome container -------------------------------------------------
    Item {
        id: body

        x: isVertical ? (isRight ? dock.headroom : 0) : dock.cornerSizeVal
        y: isVertical ? dock.cornerSizeVal : (isBottom ? dock.headroom : 0)
        width: isVertical ? (dock.plateHeight + dock.gap) : dock.plateWidth
        height: isVertical ? dock.plateWidth : (dock.plateHeight + dock.gap)

        opacity: dock.plateOpacity

        HoverHandler {
            id: bodyHover
            onHoveredChanged: {
                if (!hovered) dock.schedulePointerLeave();
            }
        }

        // Sliding plate geometry
        Item {
            id: plate

            x: isLeft ? (dock.revealed ? dock.gap : (dock.gap - dock.hiddenOffset))
             : isRight ? (dock.revealed ? 0 : dock.hiddenOffset)
             : 0
            y: isTop ? (dock.revealed ? dock.gap : (dock.gap - dock.hiddenOffset))
             : isBottom ? (dock.revealed ? 0 : dock.hiddenOffset)
             : 0
            width: isVertical ? dock.plateHeight : body.width
            height: isVertical ? body.height : dock.plateHeight

            Behavior on x {
                NumberAnimation { duration: dock.slideDuration; easing.type: Easing.OutCubic }
            }
            Behavior on y {
                NumberAnimation { duration: dock.slideDuration; easing.type: Easing.OutCubic }
            }

            // ---- Ambient Drop Shadow for Floating macOS Dock ----
            RectangularShadow {
                id: plateShadow
                anchors.fill: parent
                radius: dock.radius
                offset: Qt.vector2d(isLeft ? 4 : isRight ? -4 : 0, isBottom ? 5 : isTop ? -5 : 0)
                color: "#50000000"
                blur: 16
                spread: 0
                visible: dock.shadowEnabled && (!dock.cornersActive || dock.gap > 0)
                z: -1
            }

            // ---- macOS Rounded Glass Plate ----
            Rectangle {
                id: plateGlass
                visible: !dock.cornersActive || dock.gap > 0
                anchors.fill: parent
                radius: dock.radius
                color: dock.background
                border.color: dock.border
                border.width: dock.borderWidth

                // Top 1px Specular Highlight Shelf (Signature macOS Glass Reflection)
                Rectangle {
                    id: topSpecular
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: 0.5
                    anchors.leftMargin: Math.round(dock.radius * 0.75)
                    anchors.rightMargin: Math.round(dock.radius * 0.75)
                    height: 1
                    radius: 0.5
                    visible: isBottom && dock.glassHighlight
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.2; color: "#55ffffff" }
                        GradientStop { position: 0.5; color: "#80ffffff" }
                        GradientStop { position: 0.8; color: "#55ffffff" }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
            }

            // Edge-corners silhouette fallback when dock touches screen edge flush
            Shape {
                id: silhouette
                visible: dock.cornersActive && dock.gap === 0
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: dock.background
                    strokeColor: dock.border
                    strokeWidth: dock.borderWidth
                    PathSvg { path: dock.silhouettePath }
                }
            }
        }

        // ---- Icons Content Row with Unified Parabolic Magnification Wave ----
        Item {
            id: contentRow
            anchors.centerIn: plate
            width: isVertical ? dock.cellSize : (dock.plateWidth - dock.dockPadding * 2)
            height: isVertical ? (dock.plateWidth - dock.dockPadding * 2) : dock.cellSize

            ListView {
                id: list

                x: 0
                y: 0
                width: isVertical ? dock.cellSize : dock.appsWidth
                height: isVertical ? dock.appsWidth : dock.cellSize

                orientation: isVertical ? ListView.Vertical : ListView.Horizontal
                spacing: dock.spacing
                interactive: false
                clip: false
                model: orderModel

                moveDisplaced: Transition {
                    NumberAnimation { properties: "x,y"; duration: 180; easing.type: Easing.OutCubic }
                }
                displaced: Transition {
                    NumberAnimation { properties: "x,y"; duration: 180; easing.type: Easing.OutCubic }
                }

                delegate: Item {
                    id: cell

                    required property int index
                    required property string appId

                    readonly property var entry: dock.entryMap[appId] ?? Tasks.resolveEntry(appId) ?? null
                    readonly property string taskKey: Tasks.key(entry ? entry.id : appId)
                    readonly property int windows: Tasks.windowCount(taskKey)
                    readonly property bool active: Tasks.isActive(taskKey)
                    readonly property bool running: windows > 0

                    width: dock.cellSize
                    height: dock.cellSize
                    property int dragIndex: index

                    // Parabolic Wave Geometry relative to contentRow
                    readonly property real cellCenterPos: isVertical
                        ? (cell.y + cell.height / 2)
                        : (cell.x + cell.width / 2)

                    readonly property real waveDistance: Math.abs(dock.pointerPos - cellCenterPos)
                    readonly property real waveInfluence: dock.cellSize * dock.waveSpread
                    readonly property real waveFactor: (dock.pointerInside && waveDistance < waveInfluence && dock.hoverMagnify && !dragArea.drag.active)
                        ? 0.5 * (1 + Math.cos(Math.PI * waveDistance / waveInfluence))
                        : 0

                    readonly property real targetScale: 1.0 + waveFactor * (dock.hoverScale - 1.0)
                    readonly property real waveLiftY: isBottom ? -Math.round(waveFactor * 7)
                                                    : isTop ? Math.round(waveFactor * 7) : 0
                    readonly property real waveLiftX: isRight ? -Math.round(waveFactor * 7)
                                                    : isLeft ? Math.round(waveFactor * 7) : 0

                    z: Math.round(targetScale * 100)

                    function returnHome() {
                        content.x = 0;
                        content.y = 0;
                    }

                    function publishIconGeometry() {
                        if (!cell.running) return;
                        try {
                            const pt = cell.mapToItem(null, 0, 0);
                            if (!pt || isNaN(pt.x) || isNaN(pt.y)) return;
                            const gx = dock.x + pt.x;
                            const gy = dock.y + pt.y;
                            if (isNaN(gx) || isNaN(gy)) return;
                            Tasks.publishGeometry(cell.taskKey, gx, gy, cell.width, cell.height);
                        } catch (e) {}
                    }

                    onXChanged: publishIconGeometry()
                    onYChanged: publishIconGeometry()

                    Connections {
                        target: cell
                        function onRunningChanged() {
                            if (cell.running) Qt.callLater(cell.publishIconGeometry);
                        }
                        function onActiveChanged() {
                            if (cell.running) Qt.callLater(cell.publishIconGeometry);
                        }
                    }

                    Component.onCompleted: Qt.callLater(publishIconGeometry)

                    DropArea {
                        anchors.fill: parent
                        keys: ["quickshell-dock-icon"]

                        onEntered: drag => {
                            const from = drag.source.dragIndex;
                            const to = cell.index;
                            if (from >= 0 && from !== to) {
                                orderModel.move(from, to, 1);
                            }
                        }
                    }

                    DockIcon {
                        id: content
                        dockRef: dock

                        width: dock.cellSize
                        height: dock.cellSize

                        entry: cell.entry
                        hovered: dragArea.containsMouse
                        dragging: dragArea.drag.active
                        windows: cell.windows
                        active: cell.active

                        currentScale: cell.targetScale
                        liftY: cell.waveLiftY
                        liftX: cell.waveLiftX
                        pressed: dragArea.pressed && !dragArea.drag.active

                        Drag.active: dragArea.drag.active
                        Drag.source: cell
                        Drag.hotSpot.x: width / 2
                        Drag.hotSpot.y: height / 2
                        Drag.keys: ["quickshell-dock-icon"]

                        states: State {
                            name: "dragging"
                            when: dragArea.drag.active
                            ParentChange { target: content; parent: dragLayer }
                        }

                        Behavior on x {
                            enabled: !dragArea.drag.active
                            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                        }
                        Behavior on y {
                            enabled: !dragArea.drag.active
                            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                        }
                    }

                    MouseArea {
                        id: dragArea

                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        property bool didDrag: false
                        drag.target: (dragArea.pressedButtons & Qt.LeftButton) ? content : null
                        drag.axis: isVertical ? Drag.YAxis : Drag.XAxis
                        drag.threshold: 8

                        onPositionChanged: mouse => {
                            const mapped = cell.mapToItem(contentRow, mouse.x, mouse.y);
                            dock.updatePointer(isVertical ? mapped.y : mapped.x);
                            if (drag.active) didDrag = true;
                        }

                        onEntered: {
                            dock.hoveredCell = cell;
                            const mapped = cell.mapToItem(contentRow, cell.width / 2, cell.height / 2);
                            dock.updatePointer(isVertical ? mapped.y : mapped.x);
                        }

                        onExited: {
                            if (dock.hoveredCell === cell) dock.hoveredCell = null;
                            dock.schedulePointerLeave();
                        }

                        Component.onDestruction: {
                            if (dock.hoveredCell === cell) dock.hoveredCell = null;
                            if (dock.launchCell === cell) dock.launchCell = null;
                            if (tooltip.activeAnchor === cell) tooltip.activeAnchor = null;
                        }

                        onPressed: mouse => {
                            didDrag = false;
                            if (mouse.button === Qt.LeftButton) {
                                dock.interacting = true;
                            }
                        }

                        onReleased: mouse => {
                            dock.interacting = false;
                            if (didDrag) dock.persistOrder();
                            Qt.callLater(cell.returnHome);
                        }

                        onCanceled: {
                            dock.interacting = false;
                            Qt.callLater(cell.returnHome);
                        }

                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                if (dock.settingsOpen) dock.settingsOpen = false;
                                contextMenu.open(cell);
                                return;
                            }
                            if (didDrag) return;
                            if (contextMenu.visible) contextMenu.close();

                            // Trigger tactile launch bounce
                            content.launch();

                            if (dock.raiseRunning && cell.running && Tasks.activate(cell.taskKey)) return;
                            if (cell.entry) cell.entry.execute();
                        }
                    }
                }
            }

            // ---- macOS Etched Glass Separator ----
            Item {
                id: separatorItem
                visible: dock.appsWidth > 0
                x: isVertical ? 0 : dock.appsWidth
                y: isVertical ? dock.appsWidth : 0
                width: isVertical ? dock.cellSize : dock.separatorTotalWidth
                height: isVertical ? dock.separatorTotalWidth : dock.cellSize

                Rectangle {
                    anchors.centerIn: parent
                    width: isVertical ? Math.round(dock.iconSize * 0.68) : 1
                    height: isVertical ? 1 : Math.round(dock.iconSize * 0.68)
                    radius: 0.5
                    color: "#28ffffff"
                }
            }

            // ---- macOS Trash Can Cell ----
            Item {
                id: trashCell
                visible: dock.showTrash
                x: isVertical ? 0 : (dock.appsWidth + (dock.appsWidth > 0 ? dock.separatorTotalWidth : 0))
                y: isVertical ? (dock.appsWidth + (dock.appsWidth > 0 ? dock.separatorTotalWidth : 0)) : 0
                width: dock.cellSize
                height: dock.cellSize

                readonly property real cellCenterPos: isVertical
                    ? (trashCell.y + trashCell.height / 2)
                    : (trashCell.x + trashCell.width / 2)

                readonly property real waveDistance: Math.abs(dock.pointerPos - cellCenterPos)
                readonly property real waveInfluence: dock.cellSize * dock.waveSpread
                readonly property real waveFactor: (dock.pointerInside && waveDistance < waveInfluence && dock.hoverMagnify)
                    ? 0.5 * (1 + Math.cos(Math.PI * waveDistance / waveInfluence))
                    : 0

                readonly property real targetScale: 1.0 + waveFactor * (dock.hoverScale - 1.0)
                readonly property real waveLiftY: isBottom ? -Math.round(waveFactor * 7) : 0
                readonly property real waveLiftX: isRight ? -Math.round(waveFactor * 7) : 0

                z: Math.round(targetScale * 100)

                Item {
                    id: trashIconWrapper
                    anchors.centerIn: parent
                    width: dock.iconSize
                    height: dock.iconSize

                    scale: trashCell.targetScale
                    transformOrigin: isBottom ? Item.Bottom : isTop ? Item.Top : isLeft ? Item.Left : Item.Right
                    y: (parent.height - height) / 2 + trashCell.waveLiftY
                    x: (parent.width - width) / 2 + trashCell.waveLiftX

                    Behavior on scale {
                        enabled: !dock.pointerInside
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }

                    Behavior on y {
                        enabled: !dock.pointerInside
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }

                    Image {
                        anchors.fill: parent
                        source: "image://icon/user-trash"
                        sourceSize.width: Math.round(dock.iconSize * dock.hoverScale * 1.5)
                        sourceSize.height: Math.round(dock.iconSize * dock.hoverScale * 1.5)
                        asynchronous: true
                        mipmap: true
                        smooth: true
                        fillMode: Image.PreserveAspectFit
                    }
                }

                MouseArea {
                    id: trashMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    onPositionChanged: mouse => {
                        const mapped = trashCell.mapToItem(contentRow, mouse.x, mouse.y);
                        dock.updatePointer(isVertical ? mapped.y : mapped.x);
                    }

                    onEntered: {
                        const mapped = trashCell.mapToItem(contentRow, trashCell.width / 2, trashCell.height / 2);
                        dock.updatePointer(isVertical ? mapped.y : mapped.x);
                    }

                    onExited: dock.schedulePointerLeave()

                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            trashMenu.open();
                        } else {
                            RecentFiles.launchCommand(["kioclient", "exec", "trash:/"]);
                        }
                    }
                }
            }

            // ---- Settings / Control Center Cell ----
            Item {
                id: settingsCell
                x: isVertical ? 0 : (dock.appsWidth + (dock.appsWidth > 0 ? dock.separatorTotalWidth : 0) + (dock.showTrash ? (dock.cellSize + dock.trashGap) : 0))
                y: isVertical ? (dock.appsWidth + (dock.appsWidth > 0 ? dock.separatorTotalWidth : 0) + (dock.showTrash ? (dock.cellSize + dock.trashGap) : 0)) : 0
                width: dock.cellSize
                height: dock.cellSize

                readonly property real cellCenterPos: isVertical
                    ? (settingsCell.y + settingsCell.height / 2)
                    : (settingsCell.x + settingsCell.width / 2)

                readonly property real waveDistance: Math.abs(dock.pointerPos - cellCenterPos)
                readonly property real waveInfluence: dock.cellSize * dock.waveSpread
                readonly property real waveFactor: (dock.pointerInside && waveDistance < waveInfluence && dock.hoverMagnify)
                    ? 0.5 * (1 + Math.cos(Math.PI * waveDistance / waveInfluence))
                    : 0

                readonly property real targetScale: 1.0 + waveFactor * (dock.hoverScale - 1.0)
                readonly property real waveLiftY: isBottom ? -Math.round(waveFactor * 7) : 0
                readonly property real waveLiftX: isRight ? -Math.round(waveFactor * 7) : 0

                z: Math.round(targetScale * 100)

                Item {
                    id: settingsIconContainer
                    anchors.centerIn: parent
                    width: dock.iconSize
                    height: dock.iconSize

                    scale: settingsCell.targetScale
                    transformOrigin: isBottom ? Item.Bottom : isTop ? Item.Top : isLeft ? Item.Left : Item.Right
                    y: (parent.height - height) / 2 + settingsCell.waveLiftY
                    x: (parent.width - width) / 2 + settingsCell.waveLiftX

                    Behavior on scale {
                        enabled: !dock.pointerInside
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }

                    Behavior on y {
                        enabled: !dock.pointerInside
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }

                    // macOS Control Center Rounded Squircle Tile
                    Rectangle {
                        anchors.fill: parent
                        radius: Math.round(width * 0.22)
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: dock.settingsOpen ? "#454d60" : "#323744" }
                            GradientStop { position: 1.0; color: dock.settingsOpen ? "#262b35" : "#1c2028" }
                        }
                        border.width: 1
                        border.color: dock.settingsOpen ? "#6088ff" : "#35ffffff"

                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        Shape {
                            id: gearShape
                            anchors.centerIn: parent
                            width: Math.round(parent.width * 0.56)
                            height: width
                            scale: width / 24
                            transformOrigin: Item.Center
                            rotation: dock.settingsOpen ? 45 : (settingsMouseArea.containsMouse ? 20 : 0)

                            Behavior on rotation {
                                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                            }

                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                fillColor: dock.settingsOpen ? "#60a5fa" : "#e8edf5"
                                strokeWidth: 0
                                PathSvg {
                                    path: "M12 15.5a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7z M19.43 12.98c.04-.32.07-.64.07-.98s-.03-.66-.07-.98l2.11-1.65c.19-.15.24-.42.12-.64l-2-3.46c-.12-.22-.39-.3-.61-.22l-2.49 1c-.52-.4-1.08-.73-1.69-.98l-.38-2.65A.488.488 0 0 0 14 2h-4c-.25 0-.46.18-.49.42l-.38 2.65c-.61.25-1.17.59-1.69.98l-2.49-1c-.23-.09-.49 0-.61.22l-2 3.46c-.13.22-.07.49.12.64l2.11 1.65c-.04.32-.07.65-.07.98s.03.66.07.98l-2.11 1.65c-.19.15-.24.42-.12.64l2 3.46c.12.22.39.3.61.22l2.49-1c.52.4 1.08.73 1.69.98l.38 2.65c.03.24.24.42.49.42h4c.25 0 .46-.18.49-.42l.38-2.65c.61-.25 1.17-.59 1.69-.98l2.49 1c.23.09.49 0 .61-.22l2-3.46c.12-.22.07-.49-.12-.64l-2.11-1.65z"
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    id: settingsMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onPositionChanged: mouse => {
                        const mapped = settingsCell.mapToItem(contentRow, mouse.x, mouse.y);
                        dock.updatePointer(isVertical ? mapped.y : mapped.x);
                    }

                    onEntered: {
                        const mapped = settingsCell.mapToItem(contentRow, settingsCell.width / 2, settingsCell.height / 2);
                        dock.updatePointer(isVertical ? mapped.y : mapped.x);
                    }

                    onExited: dock.schedulePointerLeave()

                    onClicked: {
                        dock.settingsOpen = !dock.settingsOpen;
                    }
                }
            }
        }
    }

    Item {
        id: dragLayer
        anchors.fill: parent
        z: 10
    }

    // ---- New-instance Button ---------------------------------------------
    Item {
        id: launcher

        readonly property var cell: dock.launchCell
        width: dock.newInstanceSize + dock.dockPadding * 2
        height: dock.newInstanceSize + dock.dockPadding * 2
        z: 15

        visible: opacity > 0
        opacity: dock.launchShown ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }

        x: {
            if (isLeft) return body.x + plate.x + dock.plateHeight - dock.dockPadding;
            if (isRight) return body.x + plate.x + dock.dockPadding - width;
            if (!cell) return 0;
            const centre = cell.mapToItem(null, cell.width / 2, 0).x;
            return Math.max(0, Math.min(dock.width - width, centre - width / 2));
        }

        y: {
            if (isBottom) return body.y + plate.y + dock.dockPadding - height;
            if (isTop) return body.y + plate.y + dock.plateHeight - dock.dockPadding;
            if (!cell) return 0;
            const centre = cell.mapToItem(null, 0, cell.height / 2).y;
            return Math.max(0, Math.min(dock.height - height, centre - height / 2));
        }

        MouseArea {
            id: launchArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: dock.launchShown
            onClicked: if (launcher.cell) Tasks.launchNew(launcher.cell.taskKey);
        }

        Rectangle {
            id: launchButton
            anchors.horizontalCenter: isVertical ? undefined : parent.horizontalCenter
            anchors.verticalCenter: isVertical ? parent.verticalCenter : undefined
            anchors.top: isBottom ? parent.top : undefined
            anchors.bottom: isTop ? parent.bottom : undefined
            anchors.left: isRight ? parent.left : undefined
            anchors.right: isLeft ? parent.right : undefined
            width: dock.newInstanceSize
            height: dock.newInstanceSize
            radius: height / 2

            color: launchArea.containsMouse ? Config.newInstanceHoverBackground : Config.newInstanceBackground
            border.width: dock.borderWidth
            border.color: dock.border

            Behavior on color { ColorAnimation { duration: 120 } }

            Rectangle {
                anchors.centerIn: parent
                width: Math.round(parent.width * 0.42)
                height: dock.newInstanceStroke
                radius: height / 2
                color: Config.newInstanceForeground
            }

            Rectangle {
                anchors.centerIn: parent
                width: dock.newInstanceStroke
                height: Math.round(parent.width * 0.42)
                radius: width / 2
                color: Config.newInstanceForeground
            }
        }
    }

    // ---- macOS Style Frosted Capsule Tooltip ------------------------------
    Item {
        id: tooltip

        readonly property var targetAnchor: launchArea.containsMouse
            ? dock.launchCell
            : ((dock.showTrash && trashMouseArea.containsMouse) ? trashCell
            : (settingsMouseArea.containsMouse ? settingsCell : dock.hoveredCell))

        property var activeAnchor: null
        property string activeText: ""

        readonly property string targetText: !targetAnchor ? ""
            : launchArea.containsMouse ? Config.newInstanceLabel
            : ((dock.showTrash && trashMouseArea.containsMouse) ? "废纸篓"
            : (settingsMouseArea.containsMouse ? "Dock 设置"
            : (targetAnchor.entry ? targetAnchor.entry.name : (targetAnchor.appId || ""))))

        onTargetAnchorChanged: {
            if (targetAnchor) {
                activeAnchor = targetAnchor;
                if (targetText !== "") activeText = targetText;
            }
        }

        onTargetTextChanged: {
            if (targetAnchor && targetText !== "") {
                activeText = targetText;
            }
        }

        readonly property string text: targetText !== "" ? targetText : activeText

        z: 25
        readonly property bool shown: targetAnchor !== null && targetText !== "" && dock.revealed && !contextMenu.visible && !dock.settingsOpen && !trashMenu.visible

        visible: opacity > 0
        opacity: shown ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }

        width: label.implicitWidth + 20
        height: label.implicitHeight + 10

        y: {
            if (isBottom) return (dock.launchShown ? launcher.y : (body.y + plate.y)) - height - 8;
            if (isTop) return (dock.launchShown ? (launcher.y + launcher.height) : (body.y + plate.y + dock.plateHeight)) + 8;
            const anchor = targetAnchor || activeAnchor;
            if (!anchor || !anchor.parent) return tooltip.y;
            try {
                const centre = anchor.mapToItem(null, 0, anchor.height / 2).y;
                return Math.max(0, Math.min(dock.height - height, centre - height / 2));
            } catch (e) {
                return tooltip.y;
            }
        }
        x: {
            if (isLeft) return (dock.launchShown ? (launcher.x + launcher.width) : (body.x + plate.x + dock.plateHeight)) + 8;
            if (isRight) return (dock.launchShown ? launcher.x : (body.x + plate.x)) - width - 8;
            const anchor = targetAnchor || activeAnchor;
            if (!anchor || !anchor.parent) return tooltip.x;
            try {
                const centre = anchor.mapToItem(null, anchor.width / 2, 0).x;
                return Math.max(0, Math.min(dock.width - width, centre - width / 2));
            } catch (e) {
                return tooltip.x;
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: Config.tooltipBackground
            border.width: 1
            border.color: "#30ffffff"
        }

        Text {
            id: label
            anchors.centerIn: parent
            text: tooltip.text
            color: Config.tooltipText
            font.pixelSize: 12
            font.weight: Font.Medium
        }
    }

    Loader {
        id: settingsLoader
        active: dock.settingsOpen
        sourceComponent: SettingsPanel {
            anchor.item: settingsCell
            visible: dock.settingsOpen
            activeScreen: dock.screenName
            onClosed: dock.settingsOpen = false
            onVisibleChanged: if (!visible) dock.settingsOpen = false
        }
    }

    ContextMenu {
        id: contextMenu
        dockRef: dock
        visible: false
    }

    // Context Menu for Trash Can
    PopupWindow {
        id: trashMenu
        anchor.item: trashCell
        anchor.edges: dock.dockPosition === "top" ? Edges.Bottom
                    : dock.dockPosition === "left" ? Edges.Right
                    : dock.dockPosition === "right" ? Edges.Left
                    : Edges.Top
        anchor.gravity: anchor.edges
        anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.SlideY

        implicitWidth: 170
        implicitHeight: 88
        color: "transparent"
        visible: false

        function open() {
            visible = true;
        }

        function close() {
            visible = false;
        }

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: "#f01c202a"
            border.color: "#30ffffff"
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 4

                Rectangle {
                    width: parent.width
                    height: 34
                    radius: 8
                    color: openTrashMouse.containsMouse ? "#20ffffff" : "transparent"
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        spacing: 8
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "打开废纸篓"
                            color: "#ffffff"
                            font.pixelSize: 12
                        }
                    }
                    MouseArea {
                        id: openTrashMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            trashMenu.close();
                            RecentFiles.launchCommand(["kioclient", "exec", "trash:/"]);
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 34
                    radius: 8
                    color: emptyTrashMouse.containsMouse ? "#25ef4444" : "transparent"
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        spacing: 8
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "清空废纸篓"
                            color: emptyTrashMouse.containsMouse ? "#f87171" : "#e0e0e0"
                            font.pixelSize: 12
                        }
                    }
                    MouseArea {
                        id: emptyTrashMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            trashMenu.close();
                            RecentFiles.launchCommand(["sh", "-c", "rm -rf ~/.local/share/Trash/files/* ~/.local/share/Trash/info/*"]);
                        }
                    }
                }
            }
        }
    }
}