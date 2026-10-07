pragma Singleton

import Quickshell
import Quickshell.Io

// Persists the dock's own ordering.
//
// Plasma stays the source of truth for *which* apps are favourites; this only
// remembers the sequence the user dragged them into. Reordering the dock
// therefore never writes to Plasma's config (plasmashell keeps that file in
// memory and would clobber us anyway).
Singleton {
    id: root

    readonly property string statePath: Quickshell.statePath("dock-order.json")

    // Saved order. May contain ids that are no longer favourites; merge() filters.
    property var saved: []
    property bool ready: false

    // Set when save() is called before the state file has finished loading, so
    // an early drag isn't silently discarded.
    property bool pendingWrite: false

    // Plasma's list wins on membership, the saved list wins on position:
    // known ids first in remembered order, then anything newly favourited.
    // Folders from DockFolders are preserved, and apps inside folders are hidden from the top-level dock.
    function merge(plasmaIds) {
        const present = ({});
        for (const id of plasmaIds) present[id] = true;

        if (typeof DockFolders !== "undefined" && DockFolders.folders) {
            for (let i = 0; i < DockFolders.folders.length; i++) {
                const f = DockFolders.folders[i];
                if (f && f.id) present["folder:" + f.id] = true;
            }
        }

        const keptSeen = ({});
        const kept = [];
        for (const id of root.saved) {
            if (typeof DockFolders !== "undefined" && DockFolders.isAppInAnyFolder(id)) {
                continue;
            }

            if (present[id] && !keptSeen[id]) {
                keptSeen[id] = true;
                kept.push(id);
            }
        }

        const added = plasmaIds.filter(id => {
            if (keptSeen[id]) return false;
            if (typeof DockFolders !== "undefined" && DockFolders.isAppInAnyFolder(id)) return false;
            return true;
        });

        if (typeof DockFolders !== "undefined" && DockFolders.folders) {
            for (let i = 0; i < DockFolders.folders.length; i++) {
                const f = DockFolders.folders[i];
                const tag = "folder:" + f.id;
                if (!keptSeen[tag]) {
                    keptSeen[tag] = true;
                    kept.push(tag);
                }
            }
        }

        return kept.concat(added);
    }

    function save(ids) {
        root.saved = ids.slice();
        if (root.ready) root.flush();
        else root.pendingWrite = true;
    }

    function flush() {
        root.pendingWrite = false;
        file.setText(JSON.stringify({ order: root.saved }, null, 2));
    }

    // Becoming ready with a queued write means the user reordered during
    // startup; the in-memory order wins over whatever was on disk.
    onReadyChanged: if (ready && pendingWrite) flush()

    // statePath's directory may not exist on first run.
    Process {
        running: true
        command: ["mkdir", "-p", Quickshell.statePath("")]
        onExited: file.reload()
    }

    FileView {
        id: file
        path: root.statePath
        atomicWrites: true
        printErrors: false

        onLoaded: {
            // Don't let a slow read clobber an order the user just dragged.
            if (!root.pendingWrite) {
                try {
                    const parsed = JSON.parse(this.text());
                    if (parsed && Array.isArray(parsed.order)) root.saved = parsed.order;
                } catch (e) {
                    console.warn("dock: ignoring unreadable order file:", e);
                }
            }
            root.ready = true;
        }

        // No file yet -- first run. Nothing saved, and writes are now allowed.
        onLoadFailed: root.ready = true
    }
}
