import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes

PanelWindow {
    id: dock

    // Room inward from the dock plate for the magnified icon, the new-instance
    // button, and the tooltip stacked above both.
    // Horizontal docks only need vertical headroom for the tooltip height + button.
    // Vertical docks need horizontal headroom for the tooltip width.
    readonly property int headroom: isVertical
        ? Math.max(140, 40 + (Config.newInstanceButton ? Config.newInstanceSize + Config.newInstanceGap : 0))
        : (34 + (Config.newInstanceButton ? Config.newInstanceSize + Config.newInstanceGap : 0))
    readonly property int plateHeight: Config.cellSize + Config.dockPadding * 2
    readonly property int appsWidth: orderModel.count > 0
        ? (orderModel.count * Config.cellSize + Math.max(0, orderModel.count - 1) * Config.spacing)
        : 0
    readonly property int separatorWidth: 1
    readonly property int separatorMargin: Math.max(4, Config.spacing * 2)
    readonly property int separatorTotalWidth: separatorMargin * 2 + separatorWidth
    readonly property int rightSectionWidth: separatorTotalWidth + Config.cellSize
    readonly property int plateWidth: Math.max(
        Config.cellSize + Config.dockPadding * 2,
        appsWidth + (appsWidth > 0 ? rightSectionWidth : Config.cellSize) + Config.dockPadding * 2)

    // id -> DesktopEntry, kept alongside the ListModel (which holds ids only).
    property var entryMap: ({})

    // ---- direction & orientation ------------------------------------------
    readonly property bool isVertical: Config.position === "left" || Config.position === "right"
    readonly property bool isBottom: Config.position === "bottom"
    readonly property bool isTop: Config.position === "top"
    readonly property bool isLeft: Config.position === "left"
    readonly property bool isRight: Config.position === "right"

    // ---- auto-hide --------------------------------------------------------

    // An auto-hiding dock has to touch the screen edge to be reachable, so it
    // gives up the floating gap. Without auto-hide it can float.
    readonly property int gap: Config.autoHide ? 0 : Config.bottomMargin

    // Corners only make sense flush against the edge; a floating dock has
    // nothing to blend into.
    readonly property bool cornersActive: Config.edgeCorners && gap === 0
    // Reserves window width; stays at full size so the window doesn't resize
    // while the dock slides.
    readonly property int cornerSize: cornersActive ? Config.cornerSize : 0

    // How far down the plate is pushed when hidden, leaving peekHeight showing.
    readonly property int hiddenOffset: plateHeight - Config.peekHeight

    // 0 fully out, 1 fully tucked away.
    readonly property real slideProgress: {
        if (hiddenOffset <= 0) return 0;
        if (isBottom) return Math.max(0, Math.min(1, plate.y / hiddenOffset));
        if (isTop) return Math.max(0, Math.min(1, (gap - plate.y) / hiddenOffset));
        if (isLeft) return Math.max(0, Math.min(1, (gap - plate.x) / hiddenOffset));
        if (isRight) return Math.max(0, Math.min(1, plate.x / hiddenOffset));
        return 0;
    }

    readonly property real visiblePlateHeight: plateHeight - (hiddenOffset * slideProgress)
    readonly property real plateTopRadius: Math.min(Config.radius, visiblePlateHeight)
    readonly property real activeCornerSize: cornersActive
        ? Math.max(0, Math.min(Config.cornerSize,
                               visiblePlateHeight * Config.peekFilletShare,
                               visiblePlateHeight - plateTopRadius))
        : 0
    readonly property real plateBottomRadius: cornersActive ? 0 : Config.radius

    readonly property string silhouettePath: {
        if (!cornersActive || gap > 0) {
            const pw = plate.width;
            const ph = plate.height;
            const px = plate.x;
            const py = plate.y;
            const r = Math.min(Config.radius, pw / 2, ph / 2);
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

        const o = cornerSize;
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

    // Full strength while out, easing to peekOpacity as it goes.
    readonly property real plateOpacity: 1 - slideProgress * (1 - Config.peekOpacity)

    property bool revealed: !Config.autoHide
    // True while an icon is held, so the dock can't slide away mid-drag.
    property bool interacting: false
    // The cell under the pointer, or null. bodyHover covers the dock as a
    // whole; this says *which* icon, which is what the tooltip and the
    // new-instance button hang off.
    property var hoveredCell: null
    property bool settingsOpen: false

    readonly property bool wantRevealed: !Config.autoHide
        || bodyHover.hovered
        || hoveredCell !== null
        || launchArea.containsMouse
        || settingsMouseArea.containsMouse
        || interacting
        || dock.settingsOpen
        || contextMenu.visible

    onWantRevealedChanged: {
        if (wantRevealed) {
            hideTimer.stop();
            revealed = true;
        } else if (!graceTimer.running) {
            hideTimer.restart();
        }
        // Otherwise let the grace period end and re-decide there.
    }

    onRevealedChanged: if (revealed) graceTimer.restart();

    // ---- new-instance button ---------------------------------------------

    // The cell the button belongs to. It outlives the hover so the button
    // stays put while the pointer travels up to it.
    property var launchCell: null
    onHoveredCellChanged: if (hoveredCell) launchCell = hoveredCell;

    readonly property bool launchWanted: Config.newInstanceButton
        && revealed
        && launchCell !== null
        && launchCell.running
        && (hoveredCell === launchCell || launchArea.containsMouse)

    // Crossing from the icon to the button passes over the plate's padding,
    // where neither is hovered. Without a grace period the button would blink
    // out from under the pointer on the way to it.
    property bool launchShown: false

    onLaunchWantedChanged: {
        if (launchWanted) {
            launchHideTimer.stop();
            launchShown = true;
        } else {
            launchHideTimer.restart();
        }
    }

    Timer {
        id: launchHideTimer
        interval: 150
        onTriggered: dock.launchShown = false
    }

    Timer {
        id: graceTimer
        interval: Config.revealGrace
        onTriggered: if (!dock.wantRevealed) hideTimer.restart();
    }

    Timer {
        id: hideTimer
        interval: Config.hideDelay
        onTriggered: dock.revealed = false
    }

    anchors.bottom: isBottom
    anchors.top: isTop
    anchors.left: isLeft
    anchors.right: isRight
    margins.bottom: 0
    margins.top: 0
    margins.left: 0
    margins.right: 0

    // The corners hang off either side of the plate, so the window has to be
    // wide enough to draw them; the plate itself stays centred within it.
    implicitWidth: isVertical ? (plateHeight + headroom + gap) : (plateWidth + cornerSize * 2)
    implicitHeight: isVertical ? (plateWidth + cornerSize * 2) : (plateHeight + headroom + gap)

    color: "transparent"
    exclusiveZone: !Config.reserveSpace ? 0
                 : Config.autoHide ? Config.peekHeight
                 : plateHeight + gap

    // Only the visible part of the plate takes input; everything else in the
    // window (headroom, and the hidden portion of the plate) clicks through to
    // whatever is underneath.
    readonly property int plateTop: body.y + plate.y

    mask: Region {
        x: isLeft ? 0 : isRight ? Math.min(body.x + plate.x, dock.width - Math.max(Config.peekHeight, Config.triggerHeight)) : body.x
        y: isTop ? 0 : isBottom ? Math.min(body.y + plate.y, dock.height - Math.max(Config.peekHeight, Config.triggerHeight)) : body.y
        width: isLeft ? Math.max(body.x + plate.x + dock.plateHeight, Math.max(Config.peekHeight, Config.triggerHeight))
             : isRight ? (dock.width - x)
             : body.width
        height: isTop ? Math.max(body.y + plate.y + dock.plateHeight, Math.max(Config.peekHeight, Config.triggerHeight))
              : isBottom ? (dock.height - y)
              : body.height

        // The button sits in the headroom, which is click-through by default,
        // so it has to add itself back in while it's up.
        Region {
            item: dock.launchShown ? launcher : null
            x: launcher.x
            y: launcher.y
            width: dock.launchShown ? launcher.width : 0
            height: dock.launchShown ? launcher.height : 0
        }
    }

    WlrLayershell.namespace: "quickshell-dock"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Preload recent files on dock startup so it is cached before right-clicking
    property var _preloadRecent: RecentFiles.recentMap

    // ---- model sync -------------------------------------------------------

    // Rebuilds the ListModel from Plasma's favourites merged with the saved
    // order, plus any currently running applications that are not pinned.
    function syncModel() {
        const favourites = PlasmaFavorites.entries;

        const map = ({});
        for (const f of favourites) map[f.id] = f.entry;

        const desired = DockOrder.merge(favourites.map(f => f.id));

        // When showRunningApps is enabled, dynamically add any running apps not in favourites
        if (Config.showRunningApps) {
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
    }

    Component.onCompleted: syncModel()

    ListModel { id: orderModel }

    // ---- chrome -----------------------------------------------------------

    // Everything visible lives inside this container, whose geometry is FIXED
    // at the revealed position and does not follow the sliding plate.
    //
    // It owns the auto-hide HoverHandler, and it has to be an *ancestor* of the
    // icons rather than a sibling: the icons' MouseAreas consume hover events,
    // so a sibling handler would never see them, and Qt won't synthesise a
    // fresh hover enter without pointer motion. Handlers on ancestors are in
    // the delivery path regardless. Keeping the geometry still also means that
    // revealing under a stationary pointer can't slide the hover target out
    // from under it.
    Item {
        id: body

        x: isVertical ? (isRight ? dock.headroom : 0) : dock.cornerSize
        y: isVertical ? dock.cornerSize : (isBottom ? dock.headroom : 0)
        width: isVertical ? (dock.plateHeight + dock.gap) : dock.plateWidth
        height: isVertical ? dock.plateWidth : (dock.plateHeight + dock.gap)

        // Fades the plate and its icons together as one group, so they don't
        // blend through each other on the way out. The input mask is untouched,
        // so however faint the sliver gets it stays just as easy to summon.
        opacity: dock.plateOpacity

        HoverHandler { id: bodyHover }

        // Geometry only -- the dock is drawn by `silhouette` below. Everything
        // still positions against this (the icon row, the tooltip, the input
        // mask), and its animated position is what drives the slide.
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
                NumberAnimation { duration: Config.slideDuration; easing.type: Easing.OutCubic }
            }
            Behavior on y {
                NumberAnimation { duration: Config.slideDuration; easing.type: Easing.OutCubic }
            }
        }

        Shape {
            id: silhouette

            x: isVertical ? 0 : -dock.cornerSize
            y: isVertical ? -dock.cornerSize : 0
            width: isVertical ? body.width : (body.width + dock.cornerSize * 2)
            height: isVertical ? (body.height + dock.cornerSize * 2) : body.height

            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: Config.background
                strokeColor: Config.border
                strokeWidth: Config.borderWidth
                PathSvg { path: dock.silhouettePath }
            }
        }

        Item {
            id: contentRow
            anchors.centerIn: plate
            width: isVertical ? Config.cellSize : (dock.plateWidth - Config.dockPadding * 2)
            height: isVertical ? (dock.plateWidth - Config.dockPadding * 2) : Config.cellSize

            ListView {
                id: list

                x: 0
                y: 0
                width: isVertical ? Config.cellSize : dock.appsWidth
                height: isVertical ? dock.appsWidth : Config.cellSize

                orientation: isVertical ? ListView.Vertical : ListView.Horizontal
                spacing: Config.spacing
                interactive: false
                clip: false
                model: orderModel

            // Animates the neighbours sliding aside as a dragged icon passes over.
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

                // What the task list calls this app. The resolved entry's id is
                // the canonical spelling; the favourite's own token is only a
                // fallback for entries that never resolved.
                readonly property string taskKey: Tasks.key(entry ? entry.id : appId)
                readonly property int windows: Tasks.windowCount(taskKey)
                readonly property bool active: Tasks.isActive(taskKey)
                readonly property bool running: windows > 0

                width: Config.cellSize
                height: Config.cellSize

                // The dragged icon reports its own index through Drag.source.
                property int dragIndex: index

                function returnHome() {
                    content.x = 0;
                    content.y = 0;
                }

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

                    width: Config.cellSize
                    height: Config.cellSize

                    entry: cell.entry
                    hovered: dragArea.containsMouse
                    dragging: dragArea.drag.active
                    windows: cell.windows
                    active: cell.active

                    Drag.active: dragArea.drag.active
                    Drag.source: cell
                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2
                    Drag.keys: ["quickshell-dock-icon"]

                    // While dragging, live in a stable coordinate space above the
                    // list. Without this the icon lurches every time the cells
                    // reorder underneath the cursor.
                    states: State {
                        name: "dragging"
                        when: dragArea.drag.active
                        ParentChange { target: content; parent: dragLayer }
                    }

                    // Fly home after a drop; the reorder itself is animated by the
                    // ListView transitions.
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
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    // Distinguishes a reorder from a plain click-to-launch.
                    property bool didDrag: false

                    drag.target: (dragArea.pressedButtons & Qt.LeftButton) ? content : null
                    drag.axis: isVertical ? Drag.YAxis : Drag.XAxis
                    // Don't start dragging until the pointer has clearly moved.
                    drag.threshold: 8

                    // Entering the next cell can arrive before leaving this
                    // one, so only surrender the slot if it's still ours.
                    onEntered: dock.hoveredCell = cell
                    onExited: if (dock.hoveredCell === cell) dock.hoveredCell = null;

                    // A delegate destroyed while hovered would otherwise leave
                    // a dangling reference and pin the dock open.
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
                    onPositionChanged: if (drag.active) didDrag = true;

                    onReleased: mouse => {
                        dock.interacting = false;
                        if (didDrag) dock.persistOrder();
                        // Runs after the state change has reparented content back,
                        // so the Behaviors animate it into place.
                        Qt.callLater(cell.returnHome);
                    }

                    onCanceled: {
                        dock.interacting = false;
                        Qt.callLater(cell.returnHome);
                    }

                    // A running app raises instead of launching a second copy;
                    // the button above the icon is what opens another window.
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            if (dock.settingsOpen) dock.settingsOpen = false;
                            contextMenu.open(cell);
                            return;
                        }
                        if (didDrag) return;
                        if (contextMenu.visible) contextMenu.close();
                        if (Config.raiseRunning && cell.running && Tasks.activate(cell.taskKey)) return;
                        if (cell.entry) cell.entry.execute();
                    }
                }
            }
        }

            // Separator
            Item {
                id: separatorItem
                visible: dock.appsWidth > 0
                x: isVertical ? 0 : dock.appsWidth
                y: isVertical ? dock.appsWidth : 0
                width: isVertical ? Config.cellSize : dock.separatorTotalWidth
                height: isVertical ? dock.separatorTotalWidth : Config.cellSize

                Rectangle {
                    anchors.centerIn: parent
                    width: isVertical ? Math.round(Config.iconSize * 0.72) : dock.separatorWidth
                    height: isVertical ? dock.separatorWidth : Math.round(Config.iconSize * 0.72)
                    radius: (isVertical ? height : width) / 2
                    color: Config.border
                }
            }

            // Settings button
            Item {
                id: settingsCell
                x: isVertical ? 0 : (dock.appsWidth + (dock.appsWidth > 0 ? dock.separatorTotalWidth : 0))
                y: isVertical ? (dock.appsWidth + (dock.appsWidth > 0 ? dock.separatorTotalWidth : 0)) : 0
                width: Config.cellSize
                height: Config.cellSize

                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: dock.settingsOpen ? Config.dragHighlight
                         : settingsMouseArea.pressed ? Config.dragHighlight
                         : settingsMouseArea.containsMouse ? Config.hoverHighlight
                         : "transparent"

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }
                }

                Item {
                    id: settingsIconContainer
                    anchors.centerIn: parent
                    width: Config.iconSize
                    height: Config.iconSize

                    scale: Config.hoverMagnify && settingsMouseArea.containsMouse ? Config.hoverScale : 1.0

                    Behavior on scale {
                        NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
                    }

                    // Dedicated squircle tile (macOS / Control Center aesthetic)
                    Rectangle {
                        anchors.fill: parent
                        radius: Math.round(width * 0.22)
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: dock.settingsOpen ? "#454d60" : "#353b49" }
                            GradientStop { position: 1.0; color: dock.settingsOpen ? "#262b35" : "#1e222a" }
                        }
                        border.width: 1
                        border.color: dock.settingsOpen ? "#6088ff" : "#40ffffff"

                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        // Dedicated vector Gear
                        Shape {
                            id: gearShape
                            anchors.centerIn: parent
                            width: Math.round(parent.width * 0.58)
                            height: width
                            scale: width / 24
                            transformOrigin: Item.Center
                            rotation: dock.settingsOpen ? 45 : (settingsMouseArea.containsMouse ? 15 : 0)

                            Behavior on rotation {
                                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                            }

                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                fillColor: dock.settingsOpen ? "#60a5fa" : "#f0f2f5"
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
                    acceptedButtons: Qt.LeftButton

                    onClicked: {
                        if (contextMenu.visible) contextMenu.close();
                        dock.settingsOpen = !dock.settingsOpen;
                    }
                }
            }
        }
    }

    // Holds the icon currently being dragged, above the list but below the
    // tooltip. Empty the rest of the time.
    Item {
        id: dragLayer
        anchors.fill: parent
        z: 10
    }

    // ---- new-instance button ----------------------------------------------

    // Clicking a running icon raises what's already open, so opening another
    // window needs a target of its own. It floats over the hovered icon, in the
    // same headroom the magnified icon and the tooltip use.
    //
    // The item is taller than the button it draws: the extra height reaches
    // down to the plate so the pointer never crosses dead space on its way up
    // from the icon.
    Item {
        id: launcher

        z: 15

        readonly property var cell: dock.launchCell

        width: isVertical ? (Config.newInstanceSize + Config.newInstanceGap + Config.dockPadding) : Config.cellSize
        height: isVertical ? Config.cellSize : (Config.newInstanceSize + Config.newInstanceGap + Config.dockPadding)

        visible: opacity > 0
        opacity: dock.launchShown ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }

        x: {
            if (isLeft) return body.x + plate.x + dock.plateHeight - Config.dockPadding;
            if (isRight) return body.x + plate.x + Config.dockPadding - width;
            if (!cell) return 0;
            const centre = cell.mapToItem(null, cell.width / 2, 0).x;
            return Math.max(0, Math.min(dock.width - width, centre - width / 2));
        }

        y: {
            if (isBottom) return body.y + plate.y + Config.dockPadding - height;
            if (isTop) return body.y + plate.y + dock.plateHeight - Config.dockPadding;
            if (!cell) return 0;
            const centre = cell.mapToItem(null, 0, cell.height / 2).y;
            return Math.max(0, Math.min(dock.height - height, centre - height / 2));
        }

        MouseArea {
            id: launchArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            // While fading out it's still drawn but no longer a target, and a
            // disabled MouseArea lets clicks through to whatever is behind.
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
            width: Config.newInstanceSize
            height: Config.newInstanceSize
            radius: height / 2

            color: launchArea.containsMouse ? Config.newInstanceHoverBackground
                                            : Config.newInstanceBackground
            border.width: Config.borderWidth
            border.color: Config.border

            Behavior on color {
                ColorAnimation { duration: 120 }
            }

            // A "+" drawn as two bars, so it scales with the button instead of
            // depending on whatever glyph the font happens to ship.
            Rectangle {
                anchors.centerIn: parent
                width: Math.round(parent.width * 0.42)
                height: Config.newInstanceStroke
                radius: height / 2
                color: Config.newInstanceForeground
            }

            Rectangle {
                anchors.centerIn: parent
                width: Config.newInstanceStroke
                height: Math.round(parent.width * 0.42)
                radius: width / 2
                color: Config.newInstanceForeground
            }
        }
    }

    // ---- tooltip ----------------------------------------------------------

    Item {
        id: tooltip

        // Hovering the button describes the button; otherwise it names the app
        // under the pointer. Both are read straight off the hover state, so
        // there's no ordering to get wrong when the pointer moves between them.
        readonly property var targetAnchor: launchArea.containsMouse
            ? dock.launchCell
            : (settingsMouseArea.containsMouse ? settingsCell : dock.hoveredCell)

        // Retain the last active anchor and text so that when the pointer moves
        // between adjacent icons (or leaves), the tooltip doesn't collapse to 0 width
        // and jump to x: 0 while fading out, which causes a black square artifact.
        property var activeAnchor: null
        property string activeText: ""

        readonly property string targetText: !targetAnchor ? ""
            : launchArea.containsMouse ? Config.newInstanceLabel
            : (settingsMouseArea.containsMouse ? "Dock 设置"
            : (targetAnchor.entry ? targetAnchor.entry.name : (targetAnchor.appId || "")))

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

        z: 20
        readonly property bool shown: targetAnchor !== null && targetText !== "" && dock.revealed && !contextMenu.visible && !dock.settingsOpen

        visible: opacity > 0
        opacity: shown ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }

        width: label.implicitWidth + 18
        height: label.implicitHeight + 10

        y: {
            if (isBottom) return (dock.launchShown ? launcher.y : (body.y + plate.y)) - height - 6;
            if (isTop) return (dock.launchShown ? (launcher.y + launcher.height) : (body.y + plate.y + dock.plateHeight)) + 6;
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
            if (isLeft) return (dock.launchShown ? (launcher.x + launcher.width) : (body.x + plate.x + dock.plateHeight)) + 6;
            if (isRight) return (dock.launchShown ? launcher.x : (body.x + plate.x)) - width - 6;
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
            radius: 7
            color: Config.tooltipBackground
            border.width: 1
            border.color: Config.border
        }

        Text {
            id: label
            anchors.centerIn: parent
            text: tooltip.text
            color: Config.tooltipText
            font.pixelSize: 12
        }
    }

    Loader {
        id: settingsLoader
        active: dock.settingsOpen
        sourceComponent: SettingsPanel {
            anchor.item: settingsCell
            visible: dock.settingsOpen
            onClosed: dock.settingsOpen = false
            onVisibleChanged: if (!visible) dock.settingsOpen = false
        }
    }

    ContextMenu {
        id: contextMenu
        visible: false
    }
}
