pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Manages application folders/groups for the dock.
// Persists folders in ~/.local/state/quickshell/dock-folders.json.
// Folders can contain multiple applications, displayed as a 3x3 mini grid icon
// on the dock, which pops open a beautiful glassmorphic panel on click.
Singleton {
    id: root

    readonly property string statePath: Quickshell.statePath("dock-folders.json")

    property var folders: []
    property bool ready: false
    property bool pendingWrite: false
    property int revision: 0

    // ---- Folder Identifier Utilities ----
    function isFolder(id) {
        return typeof id === "string" && id.indexOf("folder:") === 0;
    }

    function extractFolderId(id) {
        if (typeof id !== "string") return "";
        return id.indexOf("folder:") === 0 ? id.slice("folder:".length) : id;
    }

    function formatFolderId(id) {
        if (typeof id !== "string") return "";
        return id.indexOf("folder:") === 0 ? id : "folder:" + id;
    }

    // ---- Query Helpers ----
    function getFolder(folderId) {
        root.revision;
        const cleanId = extractFolderId(folderId);
        for (let i = 0; i < root.folders.length; i++) {
            if (root.folders[i] && root.folders[i].id === cleanId) {
                return root.folders[i];
            }
        }
        return null;
    }

    function hasFolder(folderId) {
        return root.getFolder(folderId) !== null;
    }

    function isAppInAnyFolder(appId) {
        root.revision;
        if (!appId || isFolder(appId)) return false;
        for (let i = 0; i < root.folders.length; i++) {
            const f = root.folders[i];
            if (f && Array.isArray(f.apps)) {
                for (let j = 0; j < f.apps.length; j++) {
                    if (f.apps[j] === appId || Tasks.key(f.apps[j]) === Tasks.key(appId)) {
                        return true;
                    }
                }
            }
        }
        return false;
    }

    function folderContainsApp(folderId, appId) {
        root.revision;
        if (!folderId || !appId) return false;
        const cleanId = extractFolderId(folderId);
        const f = getFolder(cleanId);
        if (!f || !Array.isArray(f.apps)) return false;
        const targetKey = Tasks.key(appId);
        for (let i = 0; i < f.apps.length; i++) {
            if (f.apps[i] === appId || Tasks.key(f.apps[i]) === targetKey) {
                return true;
            }
        }
        return false;
    }

    function getFolderForApp(appId) {
        root.revision;
        if (!appId || isFolder(appId)) return null;
        for (let i = 0; i < root.folders.length; i++) {
            const f = root.folders[i];
            if (f && Array.isArray(f.apps)) {
                for (let j = 0; j < f.apps.length; j++) {
                    if (f.apps[j] === appId || Tasks.key(f.apps[j]) === Tasks.key(appId)) {
                        return f;
                    }
                }
            }
        }
        return null;
    }

    // Resolve an app entry by its desktop id or heuristic lookup
    function resolveAppEntry(appId) {
        if (!appId) return null;
        return PlasmaFavorites.lookup(appId) ?? Tasks.resolveEntry(appId) ?? null;
    }

    // Window & Running Status of all apps inside the folder
    function folderWindowCount(folderId) {
        Tasks.revision;
        const folder = getFolder(folderId);
        if (!folder || !folder.apps) return 0;
        let count = 0;
        for (let i = 0; i < folder.apps.length; i++) {
            const appId = folder.apps[i];
            const entry = resolveAppEntry(appId);
            const taskKey = Tasks.key(entry ? entry.id : appId);
            count += Tasks.windowCount(taskKey);
        }
        return count;
    }

    function folderIsActive(folderId) {
        Tasks.revision;
        const folder = getFolder(folderId);
        if (!folder || !folder.apps) return false;
        for (let i = 0; i < folder.apps.length; i++) {
            const appId = folder.apps[i];
            const entry = resolveAppEntry(appId);
            const taskKey = Tasks.key(entry ? entry.id : appId);
            if (Tasks.isActive(taskKey)) return true;
        }
        return false;
    }

    // ---- Mutations ----
    function createFolder(name, initialAppIds, targetIndex) {
        const id = "folder_" + Date.now().toString(36) + "_" + Math.floor(Math.random() * 1000);
        const folderName = (name && name.trim()) ? name.trim() : "应用文件夹";
        const appList = [];
        if (Array.isArray(initialAppIds)) {
            for (let i = 0; i < initialAppIds.length; i++) {
                const appId = initialAppIds[i];
                if (appId && !isFolder(appId) && appList.indexOf(appId) < 0) {
                    appList.push(appId);
                }
            }
        }
        const newFolder = {
            id: id,
            name: folderName,
            apps: appList
        };

        const next = root.folders.slice();
        next.push(newFolder);
        root.folders = next;
        root.save();

        const folderTag = "folder:" + id;
        const currentOrder = DockOrder.saved.slice();
        // Remove contained apps from top-level order so they don't remain as ghosts
        const filteredOrder = currentOrder.filter(x => appList.indexOf(x) < 0);
        const insertIdx = (typeof targetIndex === "number" && targetIndex >= 0)
            ? Math.min(targetIndex, filteredOrder.length)
            : filteredOrder.length;
        filteredOrder.splice(insertIdx, 0, folderTag);
        DockOrder.save(filteredOrder);
        root.revision++;
        return id;
    }

    function deleteFolder(folderId) {
        const cleanId = extractFolderId(folderId);
        const target = getFolder(cleanId);
        if (!target) return;

        // Disband: Return contained apps back to DockOrder near folder's location
        const folderTag = "folder:" + cleanId;
        const currentOrder = DockOrder.saved.slice();
        const fIdx = currentOrder.indexOf(folderTag);
        if (fIdx >= 0) {
            currentOrder.splice(fIdx, 1);
            if (Array.isArray(target.apps)) {
                for (let i = 0; i < target.apps.length; i++) {
                    currentOrder.splice(fIdx + i, 0, target.apps[i]);
                }
            }
        } else if (Array.isArray(target.apps)) {
            for (let j = 0; j < target.apps.length; j++) {
                currentOrder.push(target.apps[j]);
            }
        }
        DockOrder.save(currentOrder);

        const next = root.folders.filter(f => f.id !== cleanId);
        root.folders = next;
        root.save();
        root.revision++;
    }

    function renameFolder(folderId, newName) {
        const cleanId = extractFolderId(folderId);
        const name = (newName && newName.trim()) ? newName.trim() : "文件夹";
        let found = false;
        const next = root.folders.map(f => {
            if (f.id === cleanId) {
                found = true;
                return { id: f.id, name: name, apps: (f.apps || []).slice() };
            }
            return f;
        });
        if (found) {
            root.folders = next;
            root.save();
            root.revision++;
        }
    }

    function addAppToFolder(folderId, appId) {
        if (!appId || isFolder(appId)) return false;
        const cleanId = extractFolderId(folderId);
        let changed = false;

        const next = root.folders.map(f => {
            if (f.id === cleanId) {
                const apps = f.apps ? f.apps.slice() : [];
                if (apps.indexOf(appId) < 0) {
                    apps.push(appId);
                    changed = true;
                }
                return { id: f.id, name: f.name, apps: apps };
            } else if (f.apps && f.apps.indexOf(appId) >= 0) {
                // If moving from another folder, remove from old folder
                changed = true;
                return { id: f.id, name: f.name, apps: f.apps.filter(a => a !== appId) };
            }
            return f;
        });

        if (changed) {
            root.folders = next;
            root.save();
            const currentOrder = DockOrder.saved.slice();
            const fIdx = currentOrder.indexOf(appId);
            if (fIdx >= 0) {
                currentOrder.splice(fIdx, 1);
                DockOrder.save(currentOrder);
            }
            root.revision++;
            return true;
        }
        return false;
    }

    function removeAppFromFolder(folderId, appId) {
        const cleanId = extractFolderId(folderId);
        let changed = false;

        const next = root.folders.map(f => {
            if (f.id === cleanId && f.apps && f.apps.indexOf(appId) >= 0) {
                changed = true;
                return { id: f.id, name: f.name, apps: f.apps.filter(a => a !== appId) };
            }
            return f;
        });

        if (changed) {
            root.folders = next;
            root.save();

            // Insert removed app back onto dock right next to the folder
            const folderTag = "folder:" + cleanId;
            const currentOrder = DockOrder.saved.slice();
            const fIdx = currentOrder.indexOf(folderTag);
            if (fIdx >= 0) {
                currentOrder.splice(fIdx + 1, 0, appId);
            } else {
                currentOrder.push(appId);
            }
            DockOrder.save(currentOrder);

            root.revision++;
            return true;
        }
        return false;
    }

    function reorderAppInFolder(folderId, fromIndex, toIndex) {
        const cleanId = extractFolderId(folderId);
        const folder = getFolder(cleanId);
        if (!folder || !folder.apps) return;
        if (fromIndex < 0 || fromIndex >= folder.apps.length) return;
        if (toIndex < 0 || toIndex >= folder.apps.length) return;
        if (fromIndex === toIndex) return;

        const apps = folder.apps.slice();
        const item = apps.splice(fromIndex, 1)[0];
        apps.splice(toIndex, 0, item);

        const next = root.folders.map(f => {
            if (f.id === cleanId) return { id: f.id, name: f.name, apps: apps };
            return f;
        });
        root.folders = next;
        root.save();
        root.revision++;
    }

    // ---- Persistence ----
    function save() {
        if (root.ready) root.flush();
        else root.pendingWrite = true;
    }

    function flush() {
        root.pendingWrite = false;
        file.setText(JSON.stringify({ folders: root.folders }, null, 2));
    }

    onReadyChanged: if (ready && pendingWrite) flush()

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
            if (!root.pendingWrite) {
                try {
                    const parsed = JSON.parse(this.text());
                    if (parsed && Array.isArray(parsed.folders)) {
                        root.folders = parsed.folders;
                    }
                } catch (e) {
                    console.warn("dock: ignoring unreadable folders file:", e);
                }
            }
            root.ready = true;
        }

        onLoadFailed: root.ready = true
    }
}
