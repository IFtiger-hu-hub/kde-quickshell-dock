pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Queries KActivities SQLite database for recent files / projects for all applications.
// Updates automatically on startup and exposes easy lookup by application ID or key.
Singleton {
    id: root

    readonly property string scriptPath: Quickshell.shellPath("recent_files.py")

    // Map of normalized app keys -> array of { path, title, displayPath, isDir, mimetype, time }
    property var recentMap: ({})
    property int revision: 0
    property bool loading: false

    function refresh() {
        worker.running = false;
        worker.running = true;
    }

    function getRecent(rawKey) {
        if (!rawKey) return [];
        let k = String(rawKey).trim().toLowerCase();
        if (k.endsWith(".desktop")) k = k.slice(0, -8);
        if (k.startsWith("applications:")) k = k.slice(13);
        const slash = k.lastIndexOf("/");
        if (slash >= 0) k = k.slice(slash + 1);

        // Direct match
        if (root.recentMap[k] && root.recentMap[k].length > 0) {
            return root.recentMap[k];
        }

        // Substring / prefix fallbacks
        if (k.startsWith("org.kde.")) {
            const sub = k.slice(8);
            if (root.recentMap[sub] && root.recentMap[sub].length > 0) return root.recentMap[sub];
        }

        if (k.indexOf("jetbrains-") >= 0) {
            const parts = k.split("-");
            if (parts.length >= 2 && root.recentMap[parts[1]] && root.recentMap[parts[1]].length > 0) {
                return root.recentMap[parts[1]];
            }
        }

        // Word-based match (e.g. "webstorm 2026.2.2" -> "webstorm")
        const words = k.split(/[\s\-_.]+/);
        for (const w of words) {
            if (w.length >= 4 && root.recentMap[w] && root.recentMap[w].length > 0) {
                return root.recentMap[w];
            }
        }

        for (const candidate of Object.keys(root.recentMap)) {
            if (candidate.length >= 4 && (k.indexOf(candidate) >= 0 || candidate.indexOf(k) >= 0)) {
                return root.recentMap[candidate];
            }
        }

        return [];
    }

    // Launch a recent file / project with the application
    function openFile(entry, filePath) {
        if (!filePath) return;
        if (entry && entry.command && entry.command.length > 0) {
            launcher.command = entry.command.concat([filePath]);
        } else {
            launcher.command = ["xdg-open", filePath];
        }
        launcher.startDetached();
    }

    // Launch desktop action or arbitrary command
    function launchCommand(cmd) {
        if (!cmd || cmd.length === 0) return;
        launcher.command = cmd;
        launcher.startDetached();
    }

    Process {
        id: launcher
    }

    Process {
        id: worker
        running: true
        command: ["python3", root.scriptPath]

        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                try {
                    const data = JSON.parse(this.text);
                    root.recentMap = data;
                    root.revision++;
                } catch(e) {
                    console.warn("RecentFiles: failed to parse JSON output:", e);
                }
            }
        }

        onExited: code => {
            root.loading = false;
            if (code !== 0) {
                console.warn("RecentFiles: python script exited with code", code);
            }
        }
    }
}
