import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes

PanelWindow {
    id: dock

    // Room above the dock plate for the magnified icon, the new-instance
    // button, and the tooltip stacked above both.
    readonly property int headroom: 34 + (Config.newInstanceButton
        ? Config.newInstanceSize + Config.newInstanceGap : 0)
    readonly property int plateHeight: Config.cellSize + Config.dockPadding * 2
    readonly property int plateWidth: Math.max(
        Config.cellSize + Config.dockPadding * 2,
        orderModel.count * Config.cellSize
            + Math.max(0, orderModel.count - 1) * Config.spacing
            + Config.dockPadding * 2)

    // id -> DesktopEntry, kept alongside the ListModel (which holds ids only).
    property var entryMap: ({})

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

    // How much of the plate is currently on screen: full height when revealed,
    // down to peekHeight when hidden.
    readonly property real visiblePlateHeight: plateHeight - plate.y

    // What peeks above the screen edge is the plate's *top* edge, so on a thin
    // sliver the rounded top corner and the edge fillet compete for the same few
    // pixels -- and since the dock is one continuous path, their arcs can't
    // overlap vertically or the outline doubles back on itself.
    //
    // The radius gets first claim and the fillet takes what's left (capped again
    // by peekFilletShare), because the alternative leaves a thin sliver looking
    // like a flat-ended box. So a thin sliver is a pure rounded cap, and the
    // flare grows in as the dock expands past the radius.
    readonly property real plateTopRadius: Math.min(
        Config.radius, visiblePlateHeight)

    readonly property real activeCornerSize: cornersActive
        ? Math.max(0, Math.min(Config.cornerSize,
                               visiblePlateHeight * Config.peekFilletShare,
                               visiblePlateHeight - plateTopRadius))
        : 0

    // Bottom corners: the fillets take over when they're active, otherwise a
    // floating dock rounds them off like the top.
    readonly property real plateBottomRadius: cornersActive ? 0 : Config.radius

    // Outline of the whole dock, in `silhouette`'s coordinates. Convex corners
    // sweep one way (SVG flag 1), the concave fillets the other (flag 0).
    readonly property string silhouettePath: {
        const o = Config.cornerSize;          // horizontal room reserved for fillets
        const left = o;
        const right = o + body.width;
        const top = plate.y;
        // Fillets pin to the screen edge; a floating dock ends at the plate.
        const bottom = cornersActive ? body.height : plate.y + plateHeight;

        const r = plateTopRadius;
        const f = activeCornerSize;
        const rb = plateBottomRadius;

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

    // How far down the plate is pushed when hidden, leaving peekHeight showing.
    readonly property int hiddenOffset: plateHeight - Config.peekHeight

    // 0 fully out, 1 fully tucked away. Taken from where the plate actually is
    // rather than from `revealed`, so anything driven off it rides the existing
    // slide animation instead of needing one of its own -- a second animation
    // would have to be kept in step with the first by hand.
    readonly property real slideProgress: hiddenOffset > 0
        ? Math.max(0, Math.min(1, plate.y / hiddenOffset))
        : 0

    // Full strength while out, easing to peekOpacity as it goes.
    readonly property real plateOpacity: 1 - slideProgress * (1 - Config.peekOpacity)

    property bool revealed: !Config.autoHide
    // True while an icon is held, so the dock can't slide away mid-drag.
    property bool interacting: false
    // The cell under the pointer, or null. bodyHover covers the dock as a
    // whole; this says *which* icon, which is what the tooltip and the
    // new-instance button hang off.
    property var hoveredCell: null

    readonly property bool wantRevealed: !Config.autoHide
        || bodyHover.hovered
        || hoveredCell !== null
        || launchArea.containsMouse
        || interacting

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

    // Anchoring only the bottom edge lets the layer shell centre us horizontally.
    anchors.bottom: true
    margins.bottom: 0

    // The corners hang off either side of the plate, so the window has to be
    // wide enough to draw them; the plate itself stays centred within it.
    implicitWidth: plateWidth + cornerSize * 2
    implicitHeight: plateHeight + headroom + gap

    color: "transparent"
    exclusiveZone: !Config.reserveSpace ? 0
                 : Config.autoHide ? Config.peekHeight
                 : plateHeight + gap

    // Only the visible part of the plate takes input; everything else in the
    // window (headroom, and the hidden portion of the plate) clicks through to
    // whatever is underneath. While hidden the region is widened up to
    // triggerHeight so the sliver is still easy to hit.
    // plate.y is relative to body, so lift it into window coordinates.
    readonly property int plateTop: body.y + plate.y
    readonly property int maskTop: Math.min(
        plateTop, dock.height - Math.max(Config.peekHeight, Config.triggerHeight))

    mask: Region {
        x: body.x
        y: dock.maskTop
        width: body.width
        height: dock.height - dock.maskTop

        // The button sits in the headroom, which is click-through by default,
        // so it has to add itself back in while it's up.
        //
        // The geometry is given twice on purpose: `item` is what the region
        // actually measures, while the explicit bindings are what notice the
        // button sliding to a different icon and ask for a rebuild.
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

    // ---- model sync -------------------------------------------------------

    // Rebuilds the ListModel from Plasma's favourites merged with the saved
    // order. No-ops when the result already matches, so our own drag-reorders
    // (which write to DockOrder) don't bounce back and clobber the drag.
    function syncModel() {
        const favourites = PlasmaFavorites.entries;

        const map = ({});
        for (const f of favourites) map[f.id] = f.entry;
        dock.entryMap = map;

        const desired = DockOrder.merge(favourites.map(f => f.id));

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
        const ids = [];
        for (let i = 0; i < orderModel.count; i++) ids.push(orderModel.get(i).appId);
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

        x: (dock.width - dock.plateWidth) / 2
        y: dock.height - dock.gap - dock.plateHeight
        width: dock.plateWidth
        height: dock.plateHeight + dock.gap

        // Fades the plate and its icons together as one group, so they don't
        // blend through each other on the way out. The input mask is untouched,
        // so however faint the sliver gets it stays just as easy to summon.
        opacity: dock.plateOpacity

        HoverHandler { id: bodyHover }

        // Geometry only -- the dock is drawn by `silhouette` below. Everything
        // still positions against this (the icon row, the tooltip, the input
        // mask), and its animated y is what drives the slide.
        Item {
            id: plate

            y: dock.revealed ? 0 : dock.hiddenOffset
            width: body.width
            height: dock.plateHeight

            Behavior on y {
                NumberAnimation { duration: Config.slideDuration; easing.type: Easing.OutCubic }
            }
        }

        // The whole dock outline -- rounded top, sides, and either the edge
        // fillets or rounded bottom corners -- as ONE path.
        //
        // It was a Rectangle plus two separate Corner items, which meant the
        // outline couldn't be stroked: Rectangle borders apply to all four edges
        // at once, so the hairline ran down the sides and straight across the
        // join with the fillets. One continuous path strokes cleanly, and also
        // avoids double-blending where translucent shapes would have overlapped.
        Shape {
            id: silhouette

            x: -Config.cornerSize
            y: 0
            width: body.width + Config.cornerSize * 2
            height: body.height

            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: Config.background
                strokeColor: Config.border
                strokeWidth: Config.borderWidth
                PathSvg { path: dock.silhouettePath }
            }
        }

        ListView {
            id: list

                anchors.centerIn: plate
            width: plate.width - Config.dockPadding * 2
            height: Config.cellSize

            orientation: ListView.Horizontal
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

                readonly property var entry: dock.entryMap[appId] ?? null

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
                    acceptedButtons: Qt.LeftButton

                    // Distinguishes a reorder from a plain click-to-launch.
                    property bool didDrag: false

                    drag.target: content
                    drag.axis: Drag.XAxis
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
                    }

                    onPressed: {
                        didDrag = false;
                        dock.interacting = true;
                    }
                    onPositionChanged: if (drag.active) didDrag = true;

                    onReleased: {
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
                    onClicked: {
                        if (didDrag) return;
                        if (Config.raiseRunning && cell.running && Tasks.activate(cell.taskKey)) return;
                        if (cell.entry) cell.entry.execute();
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

        width: Config.cellSize
        height: Config.newInstanceSize + Config.newInstanceGap + Config.dockPadding

        visible: opacity > 0
        opacity: dock.launchShown ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }

        // Bottom edge lands on the icon's own top edge, not the plate's.
        y: dock.plateTop + Config.dockPadding - height
        x: {
            if (!cell) return 0;
            const centre = cell.mapToItem(null, cell.width / 2, 0).x;
            return Math.max(0, Math.min(dock.width - width, centre - width / 2));
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

            anchors.horizontalCenter: parent.horizontalCenter
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
        readonly property var anchorItem: launchArea.containsMouse
            ? dock.launchCell : dock.hoveredCell
        readonly property string text: !anchorItem ? ""
            : launchArea.containsMouse ? Config.newInstanceLabel
            : (anchorItem.entry ? anchorItem.entry.name : anchorItem.appId)

        z: 20
        readonly property bool shown: anchorItem !== null && text !== "" && dock.revealed

        visible: opacity > 0
        opacity: shown ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }

        width: label.implicitWidth + 18
        height: label.implicitHeight + 10

        // Sits above the new-instance button when that's up, so the two don't
        // stack on top of each other.
        y: (dock.launchShown ? launcher.y : dock.plateTop) - height - 6
        x: {
            if (!anchorItem) return 0;
            // null maps to scene coordinates, which for a window are its own.
            const centre = anchorItem.mapToItem(null, anchorItem.width / 2, 0).x;
            return Math.max(0, Math.min(dock.width - width, centre - width / 2));
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
}
