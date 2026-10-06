pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Everything the dock does with the trash, routed through KIO.
//
// The trash is not just ~/.local/share/Trash: every mounted volume can carry its
// own .Trash-$UID, and KIO keeps a `directorysizes` cache alongside. Deleting
// files/ and info/ by hand misses the external volumes and leaves that cache
// stale, so emptying goes through `ktrash6 --empty` (KIO's own trash worker),
// falling back to `gio trash --empty` on systems without it. Both handle every
// trash location and keep the bookkeeping consistent.
Singleton {
    id: root

    // Number of top-level items in trash:/ (-1 until the first count lands).
    property int count: -1
    readonly property bool empty: count === 0
    property bool busy: false

    function refresh() {
        lister.running = false;
        lister.running = true;
    }

    function open() {
        opener.command = ["kioclient", "exec", "trash:/"];
        opener.startDetached();
    }

    function emptyTrash() {
        if (root.busy) return;
        root.busy = true;
        emptier.running = true;
    }

    // `kioclient ls trash:/` lists one entry per line, "." included.
    Process {
        id: lister
        command: ["kioclient", "ls", "trash:/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n").filter(l => l !== "" && l !== "." && l !== "..");
                root.count = lines.length;
            }
        }
    }

    Process {
        id: opener
        command: ["kioclient", "exec", "trash:/"]
    }

    Process {
        id: emptier
        command: ["sh", "-c", "if command -v ktrash6 >/dev/null 2>&1; then exec ktrash6 --empty; else exec gio trash --empty; fi"]
        onExited: (code, status) => {
            root.busy = false;
            if (code !== 0) console.warn("dock: emptying the trash failed, exit code", code);
            root.refresh();
        }
    }

    Component.onCompleted: refresh()
}
