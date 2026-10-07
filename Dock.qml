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
    readonly property bool isLight: (0.299 * backgroundColor.r + 0.587 * backgroundColor.g + 0.114 * backgroundColor.b) > 0.5
    readonly property color border: Config.getVal(screenName, "border")
    readonly property real borderWidth: Config.getVal(screenName, "borderWidth")
    readonly property bool glassHighlight: Config.getVal(screenName, "glassHighlight")
    readonly property bool shadowEnabled: Config.getVal(screenName, "shadowEnabled")
    readonly property bool showTrash: Config.getVal(screenName, "showTrash")
    readonly property bool showDrawer: Config.getVal(screenName, "showDrawer") ?? true
    readonly property bool circularIcons: Config.getVal(screenName, "circularIcons")
    readonly property string iconShape: Config.getVal(screenName, "iconShape") || (circularIcons ? "circle" : "original")
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
        : Math.max(88, Math.ceil(cellSize * (hoverScale - 1)) + 58)

    readonly property int plateHeight: cellSize + dockPadding * 2

    // ---- Dedicated Multi-Window Shelf State & Sizing ----
    property string expandedAppKey: ""
    property var hoveredWindowCard: null
    property var hoveredMultiWindowIcon: null
    property var hoveredMultiWindowIconAnchor: null
    readonly property int cardWidth: 230
    readonly property int cardHeight: Math.max(36, iconSize)

    // Current apps with multiple windows (windowCount >= 2)
    readonly property var multiWindowApps: {
        Tasks.revision;
        const list = [];
        if (!Tasks.apps) return list;
        const keys = Object.keys(Tasks.apps);
        for (let i = 0; i < keys.length; i++) {
            const key = keys[i];
            const count = Tasks.windowCount(key);
            if (count > 1) {
                const entry = Tasks.resolveEntry(key);
                const appRec = Tasks.apps[key];
                list.push({
                    key: key,
                    appId: (appRec && appRec.appId) ? appRec.appId : key,
                    entry: entry || { id: key, icon: (appRec ? appRec.icon : key), name: (appRec ? appRec.name : key) },
                    name: (entry && entry.name) ? entry.name : (appRec && appRec.name ? appRec.name : key),
                    icon: (entry && entry.icon) ? entry.icon : (appRec && appRec.icon ? appRec.icon : key),
                    windows: count,
                    active: appRec ? Boolean(appRec.active) : false
                });
            }
        }
        return list;
    }

    readonly property var expandedWindowList: {
        Tasks.revision;
        return expandedAppKey !== "" ? Tasks.getWindows(expandedAppKey) : [];
    }

    onExpandedWindowListChanged: {
        if (expandedAppKey !== "" && expandedWindowList.length <= 1) {
            expandedAppKey = "";
        }
    }

    onMultiWindowAppsChanged: {
        if (expandedAppKey !== "") {
            let found = false;
            for (let i = 0; i < multiWindowApps.length; i++) {
                if (multiWindowApps[i].key === expandedAppKey) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                expandedAppKey = "";
            }
        }
    }

    // Width/Height along main dock axis for multi-window app icons
    readonly property int multiWindowIconsWidth: multiWindowApps.length > 0
        ? (multiWindowApps.length * cellSize + (multiWindowApps.length - 1) * spacing)
        : 0

    // Width/Height along main dock axis for expanded window cards
    readonly property int multiWindowCardsWidth: (expandedAppKey !== "" && expandedWindowList.length > 1)
        ? (expandedWindowList.length * (isVertical ? cardHeight : cardWidth) + (expandedWindowList.length - 1) * spacing)
        : 0

    // Total target extent along main axis (width for horizontal, height for vertical)
    readonly property int targetShelfWidth: {
        if (multiWindowApps.length === 0) return 0;
        let w = multiWindowIconsWidth;
        if (multiWindowCardsWidth > 0) {
            w += spacing + multiWindowCardsWidth;
        }
        return w;
    }

    property real animShelfWidth: 0
    onTargetShelfWidthChanged: animShelfWidth = targetShelfWidth
    Behavior on animShelfWidth {
        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
    }

    readonly property int baseAppsWidth: orderModel.count > 0
        ? (orderModel.count * cellSize + Math.max(0, orderModel.count - 1) * spacing)
        : 0
    readonly property int appsWidth: baseAppsWidth

    readonly property int separatorWidth: 1
    readonly property int separatorMargin: Math.max(5, spacing * 1.5)
    readonly property int separatorTotalWidth: separatorMargin * 2 + separatorWidth
    readonly property int shelfSectionWidth: animShelfWidth > 0 ? (Math.round(animShelfWidth) + separatorTotalWidth) : 0
    readonly property int trashWidth: showTrash ? cellSize : 0
    readonly property int trashGap: showTrash ? spacing : 0
    readonly property int drawerWidth: showDrawer ? cellSize : 0
    readonly property int drawerGap: showDrawer ? spacing : 0
    readonly property int rightSectionWidth: separatorTotalWidth + shelfSectionWidth + trashWidth + trashGap + cellSize + drawerGap + drawerWidth

    // Screen Boundary & Scrollable Container Max Width Clamping
    readonly property int maxPlateWidth: {
        const sw = screen ? screen.width : 1920;
        const sh = screen ? screen.height : 1080;
        return isVertical ? Math.round(sh * 0.84) : Math.round(sw * 0.88);
    }

    readonly property int naturalPlateWidth: Math.max(
        cellSize + dockPadding * 2,
        appsWidth + (appsWidth > 0 ? rightSectionWidth : (trashWidth + trashGap + cellSize + drawerGap + drawerWidth)) + dockPadding * 2)

    readonly property bool isOverflowing: naturalPlateWidth > maxPlateWidth
    readonly property int plateWidth: isOverflowing ? maxPlateWidth : naturalPlateWidth
    onIsOverflowingChanged: Qt.callLater(scrollListBy, 0)

    readonly property int availableAppsWidth: Math.max(cellSize, plateWidth - dockPadding * 2 - (appsWidth > 0 ? rightSectionWidth : (trashWidth + trashGap + cellSize + drawerGap + drawerWidth)))

    // Move the overflowing icon list by `d` px along the dock axis, clamped to the
    // ListView's real extents (origin can be non-zero). scrollListBy(0) re-clamps.
    function scrollListBy(d) {
        if (!isOverflowing) {
            list.smoothScroll = true;
            list.scrollGoal = list.scrollMin;
            return;
        }
        list.scrollGoal = Math.max(list.scrollMin, Math.min(list.scrollMax, list.scrollGoal + d));
    }

    function ensureCellVisible(c) {
        if (!isOverflowing || !c) return;
        const start = isVertical ? c.y : c.x;
        const end = start + (isVertical ? c.height : c.width);
        const viewSize = isVertical ? list.height : list.width;
        list.smoothScroll = true;
        if (start < list.scrollGoal) {
            scrollListBy(start - 10 - list.scrollGoal);
        } else if (end > list.scrollGoal + viewSize) {
            scrollListBy(end - viewSize + 10 - list.scrollGoal);
        }
    }

    // auto-hide
    readonly property int gap: autoHide ? 0 : bottomMargin
    readonly property bool cornersActive: edgeCorners && gap === 0
    readonly property int cornerSizeVal: cornersActive ? cornerSize : 0
    readonly property int shadowBleed: dock.shadowEnabled ? 28 : 0
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
    property bool isResizingDock: false
    property var hoveredCell: null
    property bool settingsOpen: false
    property bool drawerOpen: false
    property var mergeTargetCell: null
    property var folderTargetCell: null

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
        interval: 160
        onTriggered: {
            if (launchArea.containsMouse) return;
            dock.pointerInside = false;
            dock.pointerPos = -10000;
            if (dock.hoveredCell && !bodyHover.hovered && !launchArea.containsMouse) {
                dock.hoveredCell = null;
            }
        }
    }

    Timer {
        id: collapseTimer
        interval: 1500
        onTriggered: {
            if (dock.expandedAppKey !== "" && !dock.pointerInside && dock.hoveredWindowCard === null) {
                dock.expandedAppKey = "";
            }
        }
    }

    onPointerInsideChanged: {
        if (!pointerInside && dock.expandedAppKey !== "") {
            collapseTimer.restart();
        } else if (pointerInside) {
            collapseTimer.stop();
        }
    }

    readonly property bool wantRevealed: !autoHide
        || bodyHover.hovered
        || hoveredCell !== null
        || pointerInside
        || launchArea.containsMouse
        || settingsCell.hovered
        || (showTrash && trashCell.hovered)
        || (showDrawer && drawerCell.hovered)
        || interacting
        || dock.settingsOpen
        || dock.drawerOpen
        || contextMenu.visible
        || trashMenu.visible
        || dock.expandedAppKey !== ""
        || (typeof folderPopup !== "undefined" && folderPopup.visible)

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
    onHoveredCellChanged: {
        if (hoveredCell && hoveredCell.running && !hoveredCell.isFolder) {
            launchCell = hoveredCell;
        } else if (hoveredCell && (!hoveredCell.running || hoveredCell.isFolder)) {
            // Hovered an app that is not running or a folder:
            // Instantly hide launcher and clear launchCell so + button never flashes on non-running icons or folders
            dock.launchShown = false;
            launchTimer.stop();
            launchCell = null;
        }
    }

    readonly property bool launchWanted: newInstanceButton
        && revealed
        && launchCell !== null
        && !launchCell.isFolder
        && Boolean(launchCell.running)
        && (hoveredCell === launchCell || launchArea.containsMouse)
        && dock.expandedAppKey === ""

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

    implicitWidth: isVertical ? (plateHeight + headroom + gap) : (plateWidth + cornerSizeVal * 2 + shadowBleed * 2)
    implicitHeight: isVertical ? (plateWidth + cornerSizeVal * 2 + shadowBleed * 2) : (plateHeight + headroom + gap)

    color: "transparent"

    // Reserves screen space when floating without auto-hide
    exclusiveZone: !reserveSpace ? 0
                 : autoHide ? peekHeight
                 : plateHeight + gap

    readonly property int plateTop: body.y + plate.y

    mask: Region {
        x: dock.isResizingDock ? 0
             : isLeft ? 0 : isRight ? Math.min(body.x + plate.x, dock.width - Math.max(peekHeight, triggerHeight)) : body.x
        y: dock.isResizingDock ? 0
             : isTop ? 0 : isBottom ? Math.min(body.y + plate.y, dock.height - Math.max(peekHeight, triggerHeight)) : body.y
        width: dock.isResizingDock ? dock.width
             : isLeft ? Math.max(body.x + plate.x + dock.plateHeight, Math.max(peekHeight, triggerHeight))
             : isRight ? (dock.width - x)
             : body.width
        height: dock.isResizingDock ? dock.height
              : isTop ? Math.max(body.y + plate.y + dock.plateHeight, Math.max(peekHeight, triggerHeight))
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

    // Background blur via KWin, rounded to the plate so no square corners show
    BackgroundEffect.blurRegion: Region {
        x: Math.round(body.x + plate.x)
        y: Math.round(body.y + plate.y)
        width: Math.round(plate.width)
        height: Math.round(plate.height)
        radius: dock.radius
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

                // If app is currently contained in an application folder, do not duplicate as standalone item
                if (typeof DockFolders !== "undefined" && DockFolders.isAppInAnyFolder(key)) {
                    continue;
                }

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
            if (favIds[id] || (typeof DockFolders !== "undefined" && DockFolders.isFolder(id))) {
                ids.push(id);
            }
        }
        DockOrder.save(ids);
    }

    function openFolder(cell, folderId) {
        if (folderPopup) folderPopup.open(cell, folderId);
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
        target: DockFolders
        function onRevisionChanged() { dock.syncModel(); }
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

        x: isVertical ? (isRight ? dock.headroom : 0) : (dock.cornerSizeVal + dock.shadowBleed)
        y: isVertical ? (dock.cornerSizeVal + dock.shadowBleed) : (isBottom ? dock.headroom : 0)
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

            // ---- Dual-tier Ambient & Contact Shadow for Floating Dock ----
            RectangularShadow {
                id: plateAmbientShadow
                anchors.fill: parent
                radius: dock.radius
                offset: Qt.vector2d(isLeft ? 5 : isRight ? -5 : 0, isBottom ? 7 : isTop ? -7 : 0)
                color: dock.isLight ? "#1a000000" : "#45000000"
                blur: 32
                spread: 0
                visible: dock.shadowEnabled && (!dock.cornersActive || dock.gap > 0)
                z: -2
            }

            RectangularShadow {
                id: plateContactShadow
                anchors.fill: parent
                radius: dock.radius
                offset: Qt.vector2d(isLeft ? 1.5 : isRight ? -1.5 : 0, isBottom ? 2 : isTop ? -2 : 0)
                color: dock.isLight ? "#12000000" : "#30000000"
                blur: 10
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
                border.color: dock.border
                border.width: dock.borderWidth

                gradient: Gradient {
                    orientation: isVertical ? Gradient.Horizontal : Gradient.Vertical
                    GradientStop {
                        position: 0.0
                        color: {
                            if (dock.isLight) {
                                return Qt.rgba(
                                    Math.min(1.0, dock.backgroundColor.r * 1.04 + 0.04),
                                    Math.min(1.0, dock.backgroundColor.g * 1.04 + 0.04),
                                    Math.min(1.0, dock.backgroundColor.b * 1.04 + 0.04),
                                    Math.min(1.0, dock.backgroundOpacity * 1.12)
                                );
                            } else {
                                return Qt.rgba(
                                    Math.min(1.0, dock.backgroundColor.r + 0.08),
                                    Math.min(1.0, dock.backgroundColor.g + 0.08),
                                    Math.min(1.0, dock.backgroundColor.b + 0.10),
                                    Math.min(1.0, dock.backgroundOpacity * 0.95)
                                );
                            }
                        }
                    }
                    GradientStop {
                        position: 1.0
                        color: {
                            if (dock.isLight) {
                                return Qt.rgba(
                                    dock.backgroundColor.r * 0.94,
                                    dock.backgroundColor.g * 0.94,
                                    dock.backgroundColor.b * 0.96,
                                    Math.max(0.05, dock.backgroundOpacity * 0.88)
                                );
                            } else {
                                return Qt.rgba(
                                    dock.backgroundColor.r,
                                    dock.backgroundColor.g,
                                    dock.backgroundColor.b,
                                    Math.min(1.0, dock.backgroundOpacity * 1.05)
                                );
                            }
                        }
                    }
                }

                // Outer hairline that separates the plate from busy wallpapers
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -1
                    radius: parent.radius + 1
                    color: "transparent"
                    border.width: 1
                    border.color: dock.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(0, 0, 0, 0.40)
                }

                // Specular refraction rim on screen-facing edge
                Rectangle {
                    id: specularRim
                    anchors.top: isBottom ? parent.top : undefined
                    anchors.bottom: isTop ? parent.bottom : undefined
                    anchors.left: isRight ? parent.left : (isVertical ? undefined : parent.left)
                    anchors.right: isLeft ? parent.right : (isVertical ? undefined : parent.right)
                    anchors.topMargin: isBottom ? 0.5 : 0
                    anchors.bottomMargin: isTop ? 0.5 : 0
                    anchors.leftMargin: isRight ? 0.5 : Math.round(dock.radius * 0.6)
                    anchors.rightMargin: isLeft ? 0.5 : Math.round(dock.radius * 0.6)
                    width: isVertical ? 1 : undefined
                    height: isVertical ? (parent.height - Math.round(dock.radius * 1.2)) : 1
                    anchors.verticalCenter: isVertical ? parent.verticalCenter : undefined
                    radius: 0.5
                    visible: dock.glassHighlight
                    gradient: Gradient {
                        orientation: isVertical ? Gradient.Vertical : Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.25; color: dock.isLight ? "#60ffffff" : "#40ffffff" }
                        GradientStop { position: 0.5; color: dock.isLight ? "#a0ffffff" : "#70ffffff" }
                        GradientStop { position: 0.75; color: dock.isLight ? "#60ffffff" : "#40ffffff" }
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

        // ---- Icons Content Row with Unified Parabolic Magnification Wave & Scroll ----
        Item {
            id: contentRow
            anchors.centerIn: plate
            width: isVertical ? dock.cellSize : (dock.plateWidth - dock.dockPadding * 2)
            height: isVertical ? (dock.plateWidth - dock.dockPadding * 2) : dock.cellSize

            // Mouse wheel / touchpad listener to scroll across dock icons when overflowing
            WheelHandler {
                id: dockWheelHandler
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    if (!dock.isOverflowing) return;
                    // Touchpads report pixelDelta: follow the fingers 1:1 without easing.
                    // Wheels report angleDelta in 1/8 degrees (120 per notch): ~90px per notch.
                    const usePixels = event.pixelDelta.x !== 0 || event.pixelDelta.y !== 0;
                    const dx = usePixels ? event.pixelDelta.x : event.angleDelta.x * 0.75;
                    const dy = usePixels ? event.pixelDelta.y : event.angleDelta.y * 0.75;
                    // Use the dominant axis only. Taking y whenever it was non-zero let
                    // small cross-axis jitter at the end of a swipe flip the direction.
                    const delta = Math.abs(dx) > Math.abs(dy) ? dx : dy;
                    if (delta === 0) return;
                    list.smoothScroll = !usePixels;
                    dock.scrollListBy(-delta);
                }
            }

            // Scroll viewport: clips only along the scroll axis when overflowing.
            // On the cross axis it is padded by the magnification headroom so hovered icons
            // can pop out of the plate. On the scroll axis, the viewport strictly confines
            // icons to [0, list.width] so no scrolled-out items can ever bleed onto the desktop
            // or past the separator. End icons avoid clipping via adaptive edgeGuard positioning.
            Item {
                id: listViewport

                readonly property real pad: Math.ceil(dock.iconSize * Math.max(0, dock.hoverScale - 1)) + 24

                x: isVertical ? -pad : 0
                y: isVertical ? 0 : -pad
                width: isVertical ? list.width + pad * 2 : list.width
                height: isVertical ? list.height : list.height + pad * 2
                clip: dock.isOverflowing

                ListView {
                    id: list

                    x: isVertical ? listViewport.pad : 0
                    y: isVertical ? 0 : listViewport.pad
                    width: isVertical ? dock.cellSize : Math.min(dock.appsWidth, dock.availableAppsWidth)
                    height: isVertical ? Math.min(dock.appsWidth, dock.availableAppsWidth) : dock.cellSize

                    orientation: isVertical ? ListView.Vertical : ListView.Horizontal
                    spacing: dock.spacing
                    interactive: false
                    // Clipping is done by listViewport (scroll axis only).
                    clip: false
                    model: orderModel

                    // Keep every delegate alive (a dock holds few items). Otherwise the
                    // ListView re-estimates its origin while recycling delegates and its
                    // own bounds fixup can shove the view away from the start.
                    cacheBuffer: Math.max(320, dock.appsWidth)
                    boundsBehavior: Flickable.StopAtBounds

                    // scrollGoal is the logical target (never animated, safe to read and
                    // accumulate); scrollPos eases towards it for wheel notches only.
                    property real scrollGoal: 0
                    property bool smoothScroll: true
                    property real scrollPos: scrollGoal
                    readonly property real scrollMin: isVertical ? originY : originX
                    readonly property real scrollMax: scrollMin + Math.max(0, isVertical ? (contentHeight - height) : (contentWidth - width))

                    contentX: isVertical ? 0 : scrollPos
                    contentY: isVertical ? scrollPos : 0

                    Behavior on scrollPos {
                        enabled: list.smoothScroll
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }

                    // Re-clamp when items are added/removed or the dock resizes.
                    onScrollMinChanged: dock.scrollListBy(0)
                    onScrollMaxChanged: dock.scrollListBy(0)

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

                        readonly property bool isFolder: typeof DockFolders !== "undefined" && DockFolders.isFolder(appId)
                        readonly property string folderId: isFolder ? DockFolders.extractFolderId(appId) : ""
                        readonly property var folderData: isFolder ? DockFolders.getFolder(folderId) : null

                        readonly property var entry: isFolder ? null : (dock.entryMap[appId] ?? Tasks.resolveEntry(appId) ?? null)
                        readonly property string taskKey: isFolder ? "" : Tasks.key(entry ? entry.id : appId)
                        readonly property int windows: isFolder ? DockFolders.folderWindowCount(folderId) : Tasks.windowCount(taskKey)
                        readonly property bool active: isFolder ? DockFolders.folderIsActive(folderId) : Tasks.isActive(taskKey)
                        readonly property bool running: windows > 0

                        readonly property bool isExpanded: (!cell.isFolder && dock.expandedAppKey === cell.taskKey && cell.windows > 1)
                            || (cell.isFolder && typeof DockFolders !== "undefined" && DockFolders.folderContainsApp(cell.folderId, dock.expandedAppKey))

                        property bool dragOverFolder: false
                        property bool dragMergeTarget: false
                        property real lastClickTime: 0
                        property real lastLaunchTime: 0

                        width: dock.cellSize
                        height: dock.cellSize

                        property int dragIndex: index

                        // Parabolic Wave Geometry relative to contentRow, centered on main icon
                        readonly property real cellCenterPos: isVertical
                            ? (cell.y - list.contentY + dock.cellSize / 2)
                            : (cell.x - list.contentX + dock.cellSize / 2)

                        readonly property real waveDistance: Math.abs(dock.pointerPos - cellCenterPos)
                        readonly property real waveInfluence: dock.cellSize * dock.waveSpread
                        readonly property real waveFactor: (dock.pointerInside && waveDistance < waveInfluence && dock.hoverMagnify && !dragArea.drag.active)
                            ? 0.5 * (1 + Math.cos(Math.PI * waveDistance / waveInfluence))
                            : 0

                        readonly property real targetScale: isExpanded
                            ? (1.0 + waveFactor * 0.15)
                            : (1.0 + waveFactor * (dock.hoverScale - 1.0))

                        // Edge-guard offset: when an icon magnifies near the start or end of the
                        // viewport (especially index 0 at scrollMin), smoothly clamp its magnified bounds
                        // inside [0, list.width] so its circular plate never gets cut off by the clipping box.
                        readonly property real edgeGuardX: {
                            if (isVertical || !dock.isOverflowing) return 0;
                            const halfGrowth = (dock.cellSize * (targetScale - 1.0)) / 2;
                            const viewLeft = cell.x - list.contentX - halfGrowth;
                            if (viewLeft < 0) return -viewLeft;
                            const viewRight = cell.x - list.contentX + dock.cellSize + halfGrowth;
                            if (viewRight > list.width) return list.width - viewRight;
                            return 0;
                        }

                        readonly property real edgeGuardY: {
                            if (!isVertical || !dock.isOverflowing) return 0;
                            const halfGrowth = (dock.cellSize * (targetScale - 1.0)) / 2;
                            const viewTop = cell.y - list.contentY - halfGrowth;
                            if (viewTop < 0) return -viewTop;
                            const viewBottom = cell.y - list.contentY + dock.cellSize + halfGrowth;
                            if (viewBottom > list.height) return list.height - viewBottom;
                            return 0;
                        }

                        readonly property real waveLiftY: (isBottom
                            ? -Math.round(waveFactor * (isExpanded ? 3 : 7))
                            : isTop ? Math.round(waveFactor * (isExpanded ? 3 : 7)) : 0) + edgeGuardY
                        readonly property real waveLiftX: (isRight
                            ? -Math.round(waveFactor * (isExpanded ? 3 : 7))
                            : isLeft ? Math.round(waveFactor * (isExpanded ? 3 : 7)) : 0) + edgeGuardX

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
                            id: cellDropArea
                            width: dock.cellSize
                            height: dock.cellSize
                            keys: ["quickshell-dock-icon"]

                            Timer {
                                id: mergeDwellTimer
                                interval: 80
                                onTriggered: {
                                    if (cellDropArea.containsDrag && !cell.isFolder) {
                                        cell.dragMergeTarget = true;
                                        dock.mergeTargetCell = cell;
                                        dock.folderTargetCell = null;
                                    }
                                }
                            }

                            function handleDragProgress(drag) {
                                if (!drag.source || drag.source === cell || drag.source.appId === cell.appId) return;

                                const from = drag.source.dragIndex;
                                const to = cell.index;
                                if (from < 0) return;

                                const pos = isVertical ? drag.y : drag.x;
                                const total = isVertical ? height : width;
                                const ratio = Math.max(0, Math.min(1, pos / Math.max(1, total)));

                                const isSourceApp = !drag.source.isFolder;
                                const isTargetFolder = cell.isFolder;

                                // Center zone: 20% to 80% of cell extent
                                const inCenterZone = (ratio >= 0.20 && ratio <= 0.80);

                                if (inCenterZone) {
                                    if (isTargetFolder && isSourceApp) {
                                        cell.dragOverFolder = true;
                                        cell.dragMergeTarget = false;
                                        dock.folderTargetCell = cell;
                                        dock.mergeTargetCell = null;
                                        mergeDwellTimer.stop();
                                    } else if (!isTargetFolder && isSourceApp && from !== to) {
                                        cell.dragOverFolder = false;
                                        dock.folderTargetCell = null;
                                        dock.mergeTargetCell = cell;
                                        if (!cell.dragMergeTarget && !mergeDwellTimer.running) {
                                            mergeDwellTimer.restart();
                                        }
                                    }
                                    // In center zone: DO NOT REORDER! Keep item steady so user can drop or dwell!
                                    return;
                                }

                                // Outside center zone: cancel merge target
                                cell.dragOverFolder = false;
                                cell.dragMergeTarget = false;
                                if (dock.mergeTargetCell === cell) dock.mergeTargetCell = null;
                                if (dock.folderTargetCell === cell) dock.folderTargetCell = null;
                                mergeDwellTimer.stop();

                                // Reorder when dragging through to the far side of the item:
                                if (from !== to) {
                                    const movingForward = from < to;
                                    const crossedThreshold = movingForward ? (ratio > 0.82) : (ratio < 0.18);
                                    if (crossedThreshold) {
                                        orderModel.move(from, to, 1);
                                        if (drag.source) drag.source.dragIndex = to;
                                    }
                                }
                            }

                            onPositionChanged: drag => handleDragProgress(drag)
                            onEntered: drag => handleDragProgress(drag)

                            onExited: {
                                cell.dragOverFolder = false;
                                cell.dragMergeTarget = false;
                                if (dock.mergeTargetCell === cell) dock.mergeTargetCell = null;
                                if (dock.folderTargetCell === cell) dock.folderTargetCell = null;
                                mergeDwellTimer.stop();
                            }
                        }

                        readonly property string resolvedIcon: cell.isFolder ? "" : appContent.iconSource

                        Item {
                            id: content

                            function launch() {
                                if (!cell.isFolder && appContent) appContent.launch();
                            }

                            width: dock.cellSize
                            height: dock.cellSize

                            scale: cell.dragMergeTarget ? 0.88 : (dragArea.drag.active ? 1.08 : 1.0)
                            Behavior on scale {
                                NumberAnimation { duration: 160; easing.type: Easing.OutBack }
                            }

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

                            DockIcon {
                                id: appContent
                                visible: !cell.isFolder
                                anchors.fill: parent
                                dockRef: dock
                                isExpanded: cell.isExpanded

                                entry: cell.entry
                                hovered: dragArea.containsMouse
                                dragging: dragArea.drag.active
                                windows: cell.windows
                                active: cell.active

                                currentScale: cell.targetScale
                                liftY: cell.waveLiftY
                                liftX: cell.waveLiftX
                                pressed: dragArea.pressed && !dragArea.drag.active
                            }

                            FolderDockIcon {
                                id: folderContent
                                visible: cell.isFolder
                                anchors.fill: parent
                                dockRef: dock
                                folderId: cell.folderId
                                isExpanded: cell.isExpanded

                                hovered: dragArea.containsMouse
                                dragging: dragArea.drag.active
                                dragHoverTarget: cell.dragOverFolder
                                windows: cell.windows
                                active: cell.active

                                currentScale: cell.targetScale
                                liftY: cell.waveLiftY
                                liftX: cell.waveLiftX
                                pressed: dragArea.pressed && !dragArea.drag.active
                            }

                            // Frosted luminous halo when another app icon is dragged over this app to merge into a folder
                            Rectangle {
                                anchors.centerIn: parent
                                width: Math.round(dock.iconSize * cell.targetScale + 8)
                                height: Math.round(dock.iconSize * cell.targetScale + 8)
                                radius: width / 2
                                visible: cell.dragMergeTarget
                                color: dock.isLight ? Qt.rgba(0.2, 0.45, 0.95, 0.20) : Qt.rgba(0.3, 0.6, 1.0, 0.28)
                                border.color: dock.isLight ? "#2563eb" : "#60a5fa"
                                border.width: 2
                                z: 30

                                Behavior on opacity { NumberAnimation { duration: 140 } }

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 3
                                    radius: width / 2
                                    color: "transparent"
                                    border.color: dock.isLight ? Qt.rgba(37, 99, 235, 0.4) : Qt.rgba(96, 165, 250, 0.4)
                                    border.width: 1
                                }
                            }
                        }

                        MouseArea {
                            id: dragArea

                            width: dock.cellSize
                            height: dock.cellSize
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
                                if (dock.hoveredCell === cell) {
                                    if (!dock.launchShown || dock.launchCell !== cell) {
                                        dock.hoveredCell = null;
                                    }
                                }
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
                                    if (dock.expandedAppKey !== "" && dock.expandedAppKey !== cell.taskKey) {
                                        dock.expandedAppKey = "";
                                    }
                                }
                            }

                            onReleased: mouse => {
                                dock.interacting = false;
                                if (didDrag) {
                                    // 1. Check if dropped onto an existing folder
                                    if (dock.folderTargetCell && !cell.isFolder) {
                                        const targetFolder = dock.folderTargetCell;
                                        dock.folderTargetCell = null;
                                        targetFolder.dragOverFolder = false;
                                        DockFolders.addAppToFolder(targetFolder.folderId, cell.appId);
                                        dock.expandedAppKey = "";
                                        Qt.callLater(cell.returnHome);
                                        return;
                                    }

                                    // 2. Check if dropped onto another app to merge into a new folder
                                    if (dock.mergeTargetCell && !cell.isFolder) {
                                        const target = dock.mergeTargetCell;
                                        dock.mergeTargetCell = null;
                                        target.dragMergeTarget = false;
                                        const targetApp = target.appId;
                                        const draggedApp = cell.appId;
                                        if (targetApp && draggedApp && targetApp !== draggedApp) {
                                            DockFolders.createFolder("应用文件夹", [targetApp, draggedApp], target.index);
                                            dock.expandedAppKey = "";
                                            Qt.callLater(cell.returnHome);
                                            return;
                                        }
                                    }

                                    dock.expandedAppKey = "";
                                    dock.persistOrder();
                                }
                                Qt.callLater(cell.returnHome);
                            }

                            onCanceled: {
                                dock.interacting = false;
                                if (dock.mergeTargetCell) {
                                    dock.mergeTargetCell.dragMergeTarget = false;
                                    dock.mergeTargetCell = null;
                                }
                                if (dock.folderTargetCell) {
                                    dock.folderTargetCell.dragOverFolder = false;
                                    dock.folderTargetCell = null;
                                }
                                Qt.callLater(cell.returnHome);
                            }

                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    if (dock.settingsOpen) dock.settingsOpen = false;
                                    dock.expandedAppKey = "";
                                    contextMenu.open(cell);
                                    return;
                                }
                                if (didDrag) return;
                                if (contextMenu.visible) contextMenu.close();

                                const now = Date.now();

                                // Folder cell -> Toggle folder popup panel (debounced against rapid double-clicks)
                                if (cell.isFolder) {
                                    if (now - cell.lastClickTime < 300) return;
                                    cell.lastClickTime = now;
                                    if (folderPopup.visible && folderPopup.folderId === cell.folderId) {
                                        folderPopup.close();
                                    } else {
                                        folderPopup.open(cell, cell.folderId);
                                    }
                                    return;
                                }

                                // Multiple windows -> Toggle inline expansion shelf (debounced against rapid double-clicks)
                                if (cell.windows > 1) {
                                    if (now - cell.lastClickTime < 300) return;
                                    cell.lastClickTime = now;
                                    if (dock.expandedAppKey === cell.taskKey) {
                                        dock.expandedAppKey = "";
                                    } else {
                                        dock.expandedAppKey = cell.taskKey;
                                        Qt.callLater(() => dock.ensureCellVisible(cell));
                                    }
                                    return;
                                }

                                // Single window running -> Raise / activate existing window (never launch a duplicate copy)
                                if (cell.running) {
                                    if (now - cell.lastClickTime < 300) return;
                                    cell.lastClickTime = now;
                                    dock.expandedAppKey = "";
                                    content.launch(); // Triggers gentle raiseNudge

                                    if (dock.raiseRunning) {
                                        if (!Tasks.activate(cell.taskKey, dock.minimizeActive)) {
                                            Tasks.activate(Tasks.key(cell.appId), dock.minimizeActive);
                                        }
                                        return;
                                    }
                                }

                                // Launch fresh instance (app not running):
                                // Strict debounce: if the app is currently launching (icon bouncing) or was clicked within 1800ms,
                                // reject subsequent clicks to guarantee rapid clicks / double clicks only ever open ONE instance!
                                if ((appContent && appContent.launching) || (now - cell.lastLaunchTime < 1800)) {
                                    return;
                                }

                                cell.lastLaunchTime = now;
                                cell.lastClickTime = now;
                                dock.expandedAppKey = "";
                                content.launch();

                                if (cell.entry) {
                                    cell.entry.execute();
                                }
                            }
                        }
                    }
                }
            }

            // Left soft fade hint when scrollable content exists to the left
            Rectangle {
                x: 0
                y: 0
                height: list.height
                width: 24
                z: 60
                visible: dock.isOverflowing && list.contentX > list.scrollMin + 4 && !dock.isVertical
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: dock.background }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // Right soft fade hint when scrollable content exists to the right
            Rectangle {
                x: list.width - width
                y: 0
                height: list.height
                width: 24
                z: 60
                visible: dock.isOverflowing && (list.contentX < list.scrollMax - 4) && !dock.isVertical
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: dock.background }
                }
            }

            // ---- macOS Etched Glass Separator & Dynamic Drag-to-Resize Handle ----
            Item {
                id: separatorItem
                visible: dock.appsWidth > 0
                x: isVertical ? 0 : list.width
                y: isVertical ? list.height : 0
                width: isVertical ? dock.cellSize : dock.separatorTotalWidth
                height: isVertical ? dock.separatorTotalWidth : dock.cellSize

                Rectangle {
                    anchors.centerIn: parent
                    width: isVertical ? Math.round((resizeMouseArea.resizing ? resizeMouseArea.dragIconSize : dock.iconSize) * 0.68) : (resizeMouseArea.resizing ? 2 : 1)
                    height: isVertical ? (resizeMouseArea.resizing ? 2 : 1) : Math.round((resizeMouseArea.resizing ? resizeMouseArea.dragIconSize : dock.iconSize) * 0.68)
                    radius: 1
                    color: resizeMouseArea.pressed
                        ? Theme.accent
                        : (dock.isLight ? Qt.rgba(0, 0, 0, resizeMouseArea.containsMouse ? 0.30 : 0.16)
                                        : Qt.rgba(1, 1, 1, resizeMouseArea.containsMouse ? 0.32 : 0.18))

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on width { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
                    Behavior on height { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
                }

                MouseArea {
                    id: resizeMouseArea
                    anchors.fill: parent
                    // Extended hit zone for effortless grabbing
                    anchors.leftMargin: isVertical ? 0 : -6
                    anchors.rightMargin: isVertical ? 0 : -6
                    anchors.topMargin: isVertical ? -6 : 0
                    anchors.bottomMargin: isVertical ? -6 : 0

                    hoverEnabled: true
                    preventStealing: true
                    cursorShape: isVertical ? Qt.SplitHCursor : Qt.SplitVCursor

                    property real startPressPos: 0
                    property int startIconSize: 44
                    property int dragIconSize: dock.iconSize
                    property bool resizing: false

                    onPressed: mouse => {
                        dock.expandedAppKey = "";
                        resizing = true;
                        dock.isResizingDock = true;
                        dock.interacting = true;
                        startIconSize = dock.iconSize;
                        dragIconSize = dock.iconSize;
                        startPressPos = isVertical ? mouse.x : mouse.y;
                    }

                    onPositionChanged: mouse => {
                        if (!pressed || !resizing) return;
                        let delta = 0;
                        if (isBottom) {
                            delta = startPressPos - mouse.y;
                        } else if (isTop) {
                            delta = mouse.y - startPressPos;
                        } else if (isLeft) {
                            delta = mouse.x - startPressPos;
                        } else if (isRight) {
                            delta = startPressPos - mouse.x;
                        }
                        dragIconSize = Math.max(24, Math.min(96, Math.round(startIconSize + delta)));
                    }

                    onReleased: {
                        if (resizing) {
                            resizing = false;
                            dock.isResizingDock = false;
                            dock.interacting = false;
                            if (dragIconSize !== dock.iconSize) {
                                if (Config.perScreenConfig && dock.screenName) {
                                    Config.setScreenVal(dock.screenName, "iconSize", dragIconSize);
                                } else {
                                    Config.setVal("iconSize", dragIconSize);
                                }
                            }
                        }
                    }

                    onCanceled: {
                        resizing = false;
                        dock.isResizingDock = false;
                        dock.interacting = false;
                        dragIconSize = dock.iconSize;
                    }

                    onDoubleClicked: {
                        const defSize = 44;
                        dragIconSize = defSize;
                        if (Config.perScreenConfig && dock.screenName) {
                            Config.setScreenVal(dock.screenName, "iconSize", defSize);
                        } else {
                            Config.setVal("iconSize", defSize);
                        }
                    }
                }
            }

            // ---- Dedicated Multi-Window Shelf Section ----
            Item {
                id: shelfSection
                visible: dock.animShelfWidth > 0.5
                opacity: Math.max(0, Math.min(1, dock.animShelfWidth / 40))
                clip: visible && (isVertical ? height > 0 : width > 0)

                x: isVertical ? 0 : (list.width + (dock.appsWidth > 0 ? dock.separatorTotalWidth : 0))
                y: isVertical ? (list.height + (dock.appsWidth > 0 ? dock.separatorTotalWidth : 0)) : 0
                width: isVertical ? dock.cellSize : Math.max(0, Math.round(dock.animShelfWidth))
                height: isVertical ? Math.max(0, Math.round(dock.animShelfWidth)) : dock.cellSize

                // 1. Multi-Window App Icons Container
                Item {
                    id: multiWindowIconsContainer
                    visible: dock.multiWindowApps.length > 0
                    x: 0
                    y: 0
                    width: isVertical ? dock.cellSize : dock.multiWindowIconsWidth
                    height: isVertical ? dock.multiWindowIconsWidth : dock.cellSize

                    Grid {
                        anchors.fill: parent
                        columns: isVertical ? 1 : dock.multiWindowApps.length
                        rows: isVertical ? dock.multiWindowApps.length : 1
                        spacing: dock.spacing

                        Repeater {
                            model: dock.multiWindowApps
                            delegate: Item {
                                id: mwCell
                                required property var modelData
                                width: dock.cellSize
                                height: dock.cellSize

                                readonly property bool isExpanded: dock.expandedAppKey === modelData.key

                                DockIcon {
                                    id: mwIcon
                                    anchors.centerIn: parent
                                    width: dock.cellSize
                                    height: dock.cellSize
                                    dockRef: dock
                                    isExpanded: mwCell.isExpanded
                                    entry: modelData.entry
                                    windows: modelData.windows
                                    active: modelData.active
                                    hovered: mwMouseArea.containsMouse
                                    pressed: mwMouseArea.pressed

                                    scale: mwMouseArea.containsMouse ? 1.08 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                }

                                // Frosted Window Count Badge
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.topMargin: Math.max(3, Math.round((dock.cellSize - dock.iconSize) / 2) - 1)
                                    anchors.rightMargin: Math.max(3, Math.round((dock.cellSize - dock.iconSize) / 2) - 1)
                                    width: Math.max(16, mwBadgeText.implicitWidth + 8)
                                    height: 16
                                    radius: 8
                                    color: mwCell.isExpanded
                                        ? (dock.isLight ? Qt.rgba(0.15, 0.45, 0.95, 0.85) : Qt.rgba(0.25, 0.55, 1.0, 0.85))
                                        : (dock.isLight ? Qt.rgba(0, 0, 0, 0.60) : Qt.rgba(255, 255, 255, 0.28))
                                    border.color: dock.isLight ? Qt.rgba(255, 255, 255, 0.5) : Qt.rgba(0, 0, 0, 0.35)
                                    border.width: 1
                                    z: 25

                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        id: mwBadgeText
                                        anchors.centerIn: parent
                                        text: String(modelData.windows)
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: "#ffffff"
                                    }
                                }

                                MouseArea {
                                    id: mwMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onEntered: {
                                        dock.hoveredMultiWindowIcon = modelData;
                                        dock.hoveredMultiWindowIconAnchor = mwCell;
                                    }
                                    onExited: {
                                        if (dock.hoveredMultiWindowIcon === modelData) {
                                            dock.hoveredMultiWindowIcon = null;
                                            dock.hoveredMultiWindowIconAnchor = null;
                                        }
                                    }
                                    onClicked: {
                                        if (dock.expandedAppKey === modelData.key) {
                                            dock.expandedAppKey = "";
                                        } else {
                                            dock.expandedAppKey = modelData.key;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // 2. Expanded Window Cards Container
                Item {
                    id: multiWindowCardsContainer
                    visible: dock.expandedAppKey !== "" && dock.expandedWindowList.length > 1
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160 } }

                    x: isVertical ? 0 : (dock.multiWindowIconsWidth + (dock.multiWindowIconsWidth > 0 ? dock.spacing : 0))
                    y: isVertical ? (dock.multiWindowIconsWidth + (dock.multiWindowIconsWidth > 0 ? dock.spacing : 0)) : 0
                    width: isVertical ? dock.cellSize : dock.multiWindowCardsWidth
                    height: isVertical ? dock.multiWindowCardsWidth : dock.cellSize

                    Grid {
                        anchors.centerIn: parent
                        columns: isVertical ? 1 : dock.expandedWindowList.length
                        rows: isVertical ? dock.expandedWindowList.length : 1
                        spacing: dock.spacing

                        Repeater {
                            model: (shelfSection.visible && dock.expandedAppKey !== "") ? dock.expandedWindowList : []
                            delegate: WindowCard {
                                required property var modelData
                                dockRef: dock
                                cellRef: null
                                winData: modelData
                            }
                        }
                    }
                }
            }

            // ---- Shelf Etched Glass Separator (between Shelf and Trash/Settings) ----
            Item {
                id: shelfSeparator
                visible: dock.animShelfWidth > 0.5
                x: isVertical ? 0 : (shelfSection.x + (dock.animShelfWidth > 0 ? Math.round(dock.animShelfWidth) : 0))
                y: isVertical ? (shelfSection.y + (dock.animShelfWidth > 0 ? Math.round(dock.animShelfWidth) : 0)) : 0
                width: isVertical ? dock.cellSize : (dock.animShelfWidth > 0 ? dock.separatorTotalWidth : 0)
                height: isVertical ? (dock.animShelfWidth > 0 ? dock.separatorTotalWidth : 0) : dock.cellSize

                Rectangle {
                    anchors.centerIn: parent
                    visible: parent.visible
                    width: isVertical ? Math.round(dock.iconSize * 0.68) : 1
                    height: isVertical ? 1 : Math.round(dock.iconSize * 0.68)
                    color: dock.isLight ? Qt.rgba(0, 0, 0, 0.16) : Qt.rgba(1, 1, 1, 0.18)
                }
            }

            // ---- Trash Cell ----
            UtilityCell {
                id: trashCell
                dock: dock
                waveSpace: contentRow
                visible: dock.showTrash
                x: isVertical ? 0 : (shelfSeparator.x + (dock.animShelfWidth > 0 ? dock.separatorTotalWidth : 0))
                y: isVertical ? (shelfSeparator.y + (dock.animShelfWidth > 0 ? dock.separatorTotalWidth : 0)) : 0
                iconNames: Trash.empty ? ["user-trash"] : ["user-trash-full", "user-trash"]
                glyphPaths: [
                    "M10 3.2h4c.55 0 1 .45 1 1v1.3H9v-1.3c0-.55.45-1 1-1z M4.5 6.5h15c.55 0 1 .35 1 .8s-.45.8-1 .8h-15c-.55 0-1-.35-1-.8s.45-.8 1-.8z",
                    "M6 9.5l1.1 9.8c.11.96.93 1.7 1.9 1.7h6c.97 0 1.79-.74 1.9-1.7l1.1-9.8H6zm3.8 9.5H8.3l-.6-7.8h1.5l.6 7.8zm3 0h-1.6v-7.8h1.6v7.8zm3 0h-1.5l.6-7.8h1.5l-.6 7.8z"
                ]
                onClicked: button => {
                    dock.expandedAppKey = "";
                    if (button === Qt.RightButton) {
                        if (trashMenu.visible) trashMenu.close();
                        else trashMenu.open();
                    } else {
                        trashMenu.close();
                        Trash.open();
                    }
                }
            }

            // ---- Dock Settings Cell ----
            UtilityCell {
                id: settingsCell
                dock: dock
                waveSpace: contentRow
                x: isVertical ? 0 : (trashCell.x + (dock.showTrash ? (dock.cellSize + dock.trashGap) : 0))
                y: isVertical ? (trashCell.y + (dock.showTrash ? (dock.cellSize + dock.trashGap) : 0)) : 0
                active: dock.settingsOpen
                iconNames: ["preferences-system", "systemsettings", "configure"]
                glyphPaths: [
                    "M12 15.5a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7z M19.43 12.98c.04-.32.07-.64.07-.98s-.03-.66-.07-.98l2.11-1.65c.19-.15.24-.42.12-.64l-2-3.46c-.12-.22-.39-.3-.61-.22l-2.49 1c-.52-.4-1.08-.73-1.69-.98l-.38-2.65A.488.488 0 0 0 14 2h-4c-.25 0-.46.18-.49.42l-.38 2.65c-.61.25-1.17.59-1.69.98l-2.49-1c-.23-.09-.49 0-.61.22l-2 3.46c-.13.22-.07.49.12.64l2.11 1.65c-.04.32-.07.65-.07.98s.03.66.07.98l-2.11 1.65c-.19.15-.24.42-.12.64l2 3.46c.12.22.39.3.61.22l2.49-1c.52.4 1.08.73 1.69.98l.38 2.65c.03.24.24.42.49.42h4c.25 0 .46-.18.49-.42l.38-2.65c.61-.25 1.17-.59 1.69-.98l2.49 1c.23.09.49 0 .61-.22l2-3.46c.12-.22.07-.49-.12-.64l-2.11-1.65z"
                ]
                onClicked: button => {
                    if (button !== Qt.LeftButton) return;
                    dock.expandedAppKey = "";
                    if (dock.drawerOpen) {
                        if (drawerLoader.item && typeof drawerLoader.item.requestClose === "function") {
                            drawerLoader.item.requestClose();
                        } else {
                            dock.drawerOpen = false;
                        }
                    }
                    dock.settingsOpen = !dock.settingsOpen;
                }
            }

            // ---- Side Drawer Cell ----
            UtilityCell {
                id: drawerCell
                dock: dock
                waveSpace: contentRow
                visible: dock.showDrawer
                x: isVertical ? 0 : (settingsCell.x + (dock.showDrawer ? (dock.cellSize + dock.drawerGap) : 0))
                y: isVertical ? (settingsCell.y + (dock.showDrawer ? (dock.cellSize + dock.drawerGap) : 0)) : 0
                active: dock.drawerOpen
                iconNames: ["sidebar-expand-right", "view-right-close", "pane-hide-right-symbolic", "sidebar-right", "view-sidebar", "widget", "format-justify-right"]
                glyphPaths: [
                    "M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2zm0 2v12h11V6H4zm13 0v12h3V6h-3z"
                ]
                onClicked: button => {
                    if (button !== Qt.LeftButton) return;
                    dock.expandedAppKey = "";
                    if (dock.drawerOpen) {
                        if (drawerLoader.item && typeof drawerLoader.item.requestClose === "function") {
                            drawerLoader.item.requestClose();
                        } else {
                            dock.drawerOpen = false;
                        }
                    } else {
                        if (dock.settingsOpen) dock.settingsOpen = false;
                        dock.drawerOpen = true;
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

        visible: opacity > 0 && dock.launchShown && Boolean(cell && cell.running)
        opacity: (dock.launchShown && Boolean(cell && cell.running)) ? 1 : 0
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

        property real lastNewInstanceTime: 0

        MouseArea {
            id: launchArea
            anchors.fill: parent
            // Seamless funnel bridge from the icon straight into the + button
            anchors.bottomMargin: isBottom ? -(dock.dockPadding + 8) : 0
            anchors.topMargin: isTop ? -(dock.dockPadding + 8) : 0
            anchors.leftMargin: isRight ? -(dock.dockPadding + 8) : -16
            anchors.rightMargin: isLeft ? -(dock.dockPadding + 8) : -16
            hoverEnabled: true
            enabled: dock.launchShown

            onPositionChanged: {
                if (launcher.cell) {
                    dock.hoveredCell = launcher.cell;
                    dock.updatePointer(launcher.cell.cellCenterPos);
                }
            }

            onEntered: {
                if (launcher.cell) {
                    dock.hoveredCell = launcher.cell;
                    dock.updatePointer(launcher.cell.cellCenterPos);
                }
            }

            onExited: {
                dock.schedulePointerLeave();
            }

            onClicked: {
                if (!launcher.cell) return;
                const now = Date.now();
                if (now - launcher.lastNewInstanceTime < 500) return;
                launcher.lastNewInstanceTime = now;
                Tasks.launchNew(launcher.cell.taskKey);
            }
        }

        Rectangle {
            id: launchButton
            width: dock.newInstanceSize
            height: dock.newInstanceSize
            radius: width / 2

            x: isLeft ? (parent.width - width) : (isRight ? 0 : Math.round((parent.width - width) / 2))
            y: isBottom ? 0 : (isTop ? (parent.height - height) : Math.round((parent.height - height) / 2))

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

        readonly property var targetAnchor: {
            if (dock.hoveredWindowCard) return dock.hoveredWindowCard;
            if (dock.hoveredMultiWindowIconAnchor) return dock.hoveredMultiWindowIconAnchor;
            if (launchArea.containsMouse) return dock.launchCell;
            if (dock.showTrash && trashCell.hovered) return trashCell;
            if (settingsCell.hovered) return settingsCell;
            if (dock.showDrawer && drawerCell.hovered) return drawerCell;
            if (resizeMouseArea.containsMouse || resizeMouseArea.resizing) return separatorItem;
            return dock.hoveredCell;
        }

        property var activeAnchor: null
        property string activeText: ""

        readonly property string targetText: {
            if (dock.hoveredWindowCard) {
                return dock.hoveredWindowCard.windowTitle
                    + (dock.hoveredWindowCard.screenLabel ? (" · " + dock.hoveredWindowCard.screenLabel) : "")
                    + (dock.hoveredWindowCard.isMinimized ? " (已最小化)" : "");
            }
            if (dock.hoveredMultiWindowIcon) {
                return dock.hoveredMultiWindowIcon.name + " (" + dock.hoveredMultiWindowIcon.windows + " 个窗口)";
            }
            if (!targetAnchor) return "";
            if (launchArea.containsMouse) return Config.newInstanceLabel;
            if (dock.showTrash && trashCell.hovered) return "废纸篓";
            if (settingsCell.hovered) return "Dock 设置";
            if (dock.showDrawer && drawerCell.hovered) return "侧边抽屉";
            if (resizeMouseArea.containsMouse || resizeMouseArea.resizing) {
                return resizeMouseArea.resizing ? (resizeMouseArea.dragIconSize + " px") : "拖动以调整大小";
            }
            if (targetAnchor.dragMergeTarget) return "合并为文件夹";
            if (targetAnchor.dragOverFolder) {
                return "移入「" + (targetAnchor.folderData ? targetAnchor.folderData.name : "文件夹") + "」";
            }
            if (targetAnchor.isFolder) {
                return targetAnchor.folderData ? targetAnchor.folderData.name : "文件夹";
            }
            return targetAnchor.entry ? targetAnchor.entry.name : (targetAnchor.appId || "");
        }

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
        readonly property bool shown: targetAnchor !== null && targetText !== "" && dock.revealed && !contextMenu.visible && !dock.settingsOpen && !dock.drawerOpen && !trashMenu.visible && !folderPopup.visible && (dock.expandedAppKey === "" || dock.hoveredWindowCard !== null || dock.hoveredMultiWindowIcon !== null)

        visible: opacity > 0
        opacity: shown ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }

        width: label.implicitWidth + 20
        height: label.implicitHeight + 10

        y: {
            if (isBottom) return Math.max(6, (dock.launchShown ? launcher.y : (body.y + plate.y)) - height - 8);
            if (isTop) return Math.min(dock.height - height - 6, (dock.launchShown ? (launcher.y + launcher.height) : (body.y + plate.y + dock.plateHeight)) + 8);
            const anchor = targetAnchor || activeAnchor;
            if (!anchor || !anchor.parent) return tooltip.y;
            try {
                const centre = anchor.mapToItem(null, 0, anchor.height / 2).y;
                return Math.max(6, Math.min(dock.height - height - 6, centre - height / 2));
            } catch (e) {
                return tooltip.y;
            }
        }
        x: {
            if (isLeft) return Math.min(dock.width - width - 6, (dock.launchShown ? (launcher.x + launcher.width) : (body.x + plate.x + dock.plateHeight)) + 8);
            if (isRight) return Math.max(6, (dock.launchShown ? launcher.x : (body.x + plate.x)) - width - 8);
            const anchor = targetAnchor || activeAnchor;
            if (!anchor || !anchor.parent) return tooltip.x;
            try {
                const centre = anchor.mapToItem(null, anchor.width / 2, 0).x;
                return Math.max(6, Math.min(dock.width - width - 6, centre - width / 2));
            } catch (e) {
                return tooltip.x;
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 6
            color: Theme.surface(dock.isLight)
            border.width: 1
            border.color: Theme.surfaceBorder(dock.isLight)
        }

        Text {
            id: label
            anchors.centerIn: parent
            text: tooltip.text
            color: Theme.textPrimary(dock.isLight)
            font.pixelSize: 12
        }
    }

    Loader {
        id: settingsLoader
        active: dock.settingsOpen
        sourceComponent: SettingsPanel {
            // Screen-pinned, not anchored to settingsCell, so dock resizes don't move it.
            screen: dock.screen
            visible: dock.settingsOpen
            activeScreen: dock.screenName
            onVisibleChanged: if (!visible) dock.settingsOpen = false
        }
    }

    Loader {
        id: drawerLoader
        active: dock.drawerOpen
        sourceComponent: SideDrawer {
            screen: dock.screen
            visible: dock.drawerOpen
            isLight: dock.isLight
            onCloseRequested: dock.drawerOpen = false
            onVisibleChanged: if (!visible) dock.drawerOpen = false
        }
    }

    ContextMenu {
        id: contextMenu
        dockRef: dock
        visible: false
    }

    TrashMenu {
        id: trashMenu
        dock: dock
        anchor.item: trashCell
    }

    FolderPopup {
        id: folderPopup
        dockRef: dock
        visible: false
    }
}
