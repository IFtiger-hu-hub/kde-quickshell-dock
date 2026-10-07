pragma Singleton

import Quickshell
import QtQuick
import org.kde.taskmanager as TaskManager

// Live view of which favourites are actually running, so the dock can badge
// them, raise their windows instead of starting a second copy, and open extra
// windows on demand.
//
// This reads Plasma's own libtaskmanager rather than Quickshell's
// ToplevelManager, because KWin implements no foreign-toplevel protocol at all
// -- neither the wlr one nor ext-foreign-toplevel-list -- so ToplevelManager
// stays permanently empty on a Plasma session. libtaskmanager also does the
// awkward part for us: mapping a window back to the .desktop file it was
// launched from, which is exactly the key the dock is indexed by.
//
// The catch is that org_kde_plasma_window_management is a restricted Wayland
// interface. KWin only hands it to clients whose .desktop file names it in
// X-KDE-Wayland-Interfaces, so the dock ships org.quickshell.dock.desktop (see
// the README). Without that file the model simply stays empty and everything
// here degrades to "nothing is running", which leaves the dock working as the
// plain launcher it was before.
Singleton {
    id: root

    // Role ids, pulled off the model type once instead of spelling out the
    // fully qualified enum at every call site.
    readonly property int roleLauncherUrl: TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon
    readonly property int roleAppId: TaskManager.AbstractTasksModel.AppId
    readonly property int roleAppName: TaskManager.AbstractTasksModel.AppName
    readonly property int roleIcon: Qt.DecorationRole
    readonly property int roleIsWindow: TaskManager.AbstractTasksModel.IsWindow
    readonly property int roleIsGroupParent: TaskManager.AbstractTasksModel.IsGroupParent
    readonly property int roleChildCount: TaskManager.AbstractTasksModel.ChildCount
    readonly property int roleIsActive: TaskManager.AbstractTasksModel.IsActive
    readonly property int roleIsMinimized: TaskManager.AbstractTasksModel.IsMinimized
    readonly property int roleScreenGeometry: TaskManager.AbstractTasksModel.ScreenGeometry
    readonly property int roleGeometry: TaskManager.AbstractTasksModel.Geometry

    // key -> { row, windows, active }. Replaced wholesale on every change, so
    // reading it in a binding is enough to stay current.
    property var apps: ({})

    // ---- queries ----------------------------------------------------------

    // Reduces anything that names an application -- a desktop id, a
    // "applications:foo.desktop" launcher url, an absolute .desktop path -- to
    // one comparable key, so both sides of the lookup normalise the same way.
    function key(id) {
        let s = String(id ?? "").trim();
        if (s === "") return "";

        const query = s.indexOf("?");
        if (query >= 0) s = s.slice(0, query);

        if (s.startsWith("applications:")) s = s.slice("applications:".length);

        const slash = s.lastIndexOf("/");
        if (slash >= 0) s = s.slice(slash + 1);

        if (s.endsWith(".desktop")) s = s.slice(0, -".desktop".length);
        return s.toLowerCase();
    }

    function info(key) { return (key && root.apps[key]) || null; }

    function windowCount(key) {
        const rec = root.info(key);
        return rec ? rec.windows : 0;
    }

    function isActive(key) {
        const rec = root.info(key);
        return rec ? rec.active : false;
    }

    // Resolves a running application key to a DesktopEntry, with fallback to TaskManager data
    function resolveEntry(key) {
        if (!key) return null;
        const cleanKey = root.key(key);
        const rec = root.apps[cleanKey];

        // 1. Try DesktopEntries by exact key or variations
        let entry = DesktopEntries.byId(cleanKey)
                 || DesktopEntries.heuristicLookup(cleanKey);

        if (!entry && rec && rec.appId) {
            const cleanAppId = root.key(rec.appId);
            entry = DesktopEntries.byId(cleanAppId) || DesktopEntries.heuristicLookup(cleanAppId);
        }

        if (!entry && rec && rec.name) {
            entry = DesktopEntries.heuristicLookup(rec.name);
        }

        if (entry) return entry;

        // 2. Synthetic entry fallback if no desktop file exists
        if (rec) {
            return {
                id: cleanKey,
                name: rec.name || cleanKey,
                icon: rec.icon || cleanKey,
                noDisplay: false,
                execute: function() { root.activate(cleanKey); }
            };
        }
        return null;
    }

    // Returns array of individual windows: [{ modelIndex, title, active, minimized, icon }]
    function getWindows(key) {
        if (!key) return [];
        const cleanKey = root.key(key);
        const rec = root.info(cleanKey);
        if (!rec) return [];

        const list = [];
        const rows = rec.rows || [rec.row];

        for (let r = 0; r < rows.length; r++) {
            const rowIndex = rows[r];
            const row = tasks.index(rowIndex, 0);
            if (!row || !row.valid) continue;

            const isGroup = tasks.data(row, root.roleIsGroupParent);
            if (isGroup) {
                const count = tasks.rowCount(row);
                for (let i = 0; i < count; i++) {
                    const child = tasks.index(i, 0, row);
                    if (!child || !child.valid) continue;
                    const winTitle = tasks.data(child, Qt.DisplayRole) || tasks.data(child, root.roleAppName) || (rec.name ? (rec.name + " " + (i + 1)) : "");
                    const geom = tasks.data(child, root.roleScreenGeometry);
                    const winGeom = tasks.data(child, root.roleGeometry);
                    list.push({
                        modelIndex: child,
                        title: winTitle || (rec.name ? (rec.name + " (" + (i + 1) + ")") : "窗口"),
                        active: tasks.data(child, root.roleIsActive) === true,
                        minimized: tasks.data(child, root.roleIsMinimized) === true,
                        icon: tasks.data(child, root.roleIcon) || rec.icon || "",
                        screenGeometry: geom || null,
                        geometry: winGeom || null
                    });
                }
            } else {
                const geom = tasks.data(row, root.roleScreenGeometry);
                const winGeom = tasks.data(row, root.roleGeometry);
                list.push({
                    modelIndex: row,
                    title: tasks.data(row, Qt.DisplayRole) || rec.name || cleanKey,
                    active: tasks.data(row, root.roleIsActive) === true,
                    minimized: tasks.data(row, root.roleIsMinimized) === true,
                    icon: tasks.data(row, root.roleIcon) || rec.icon || "",
                    screenGeometry: geom || null,
                    geometry: winGeom || null
                });
            }
        }
        return list;
    }

    // Revision tracker bumped on any window state/activation change
    property int revision: 0

    function isWindowActive(modelIndex) {
        if (!modelIndex || !modelIndex.valid) return false;
        try {
            return tasks.data(modelIndex, root.roleIsActive) === true;
        } catch (e) {
            return false;
        }
    }

    function isWindowMinimized(modelIndex) {
        if (!modelIndex || !modelIndex.valid) return false;
        try {
            return tasks.data(modelIndex, root.roleIsMinimized) === true;
        } catch (e) {
            return false;
        }
    }

    function activateWindow(modelIndex) {
        const res = root.raise(modelIndex);
        root.revision++;
        rebuildTimer.restart();
        return res;
    }

    function closeWindow(modelIndex) {
        if (!modelIndex || !modelIndex.valid) return false;
        try {
            tasks.requestClose(modelIndex);
            root.revision++;
            rebuildTimer.restart();
            return true;
        } catch (e) {
            console.warn("Tasks: requestClose failed:", e);
            return false;
        }
    }

    // ---- actions ----------------------------------------------------------

    // Raises the app's windows. When it owns several, each call steps to the
    // next one, so repeated clicks cycle the group instead of arguing over
    // which single window counts as "the" window.
    // When only one window is open and minimizeActive is enabled, clicking
    // the already-active window minimizes it.
    function activate(key, allowMinimize = true) {
        const rec = root.info(key);
        if (!rec) return false;

        const row = tasks.index(rec.row, 0);
        const children = tasks.data(row, root.roleIsGroupParent) ? tasks.rowCount(row) : 0;

        // Toggle minimize for single window if currently active
        if (allowMinimize && Config.minimizeActive && rec.windows === 1) {
            const target = root.windowIndex(key);
            if (target && target.valid) {
                const isActive = tasks.data(target, root.roleIsActive) === true || tasks.data(row, root.roleIsActive) === true;
                if (isActive) {
                    tasks.requestToggleMinimized(target);
                    return true;
                }
                return root.raise(target);
            }
        }

        if (children === 0) return root.raise(row);

        let next = 0;
        for (let i = 0; i < children; i++) {
            if (tasks.data(tasks.index(i, 0, row), root.roleIsActive)) {
                next = (i + 1) % children;
                break;
            }
        }
        return root.raise(tasks.index(next, 0, row));
    }

    // Opens another window even though the app is already running -- the whole
    // point of the button above the icon.
    function launchNew(key) {
        const index = root.windowIndex(key);
        if (!index) return false;

        tasks.requestNewInstance(index);
        return true;
    }

    // A group parent is a synthetic row standing in for its children, so
    // resolve it to a real window before asking the model to act on it.
    function windowIndex(key) {
        const rec = root.info(key);
        if (!rec) return null;

        const row = tasks.index(rec.row, 0);
        if (tasks.data(row, root.roleIsGroupParent) && tasks.rowCount(row) > 0)
            return tasks.index(0, 0, row);
        return row;
    }

    function raise(index) {
        if (!index || !index.valid) return false;

        // requestActivate on its own leaves a minimized window minimized.
        if (tasks.data(index, root.roleIsMinimized)) tasks.requestToggleMinimized(index);
        tasks.requestActivate(index);
        return true;
    }

    // Publishes the icon screen geometry to KWin for authentic Magic Lamp (Genie effect) window minimize/restore
    function publishGeometry(key, x, y, width, height) {
        if (!key) return;
        if (isNaN(x) || isNaN(y) || isNaN(width) || isNaN(height)) return;
        const rec = root.info(key);
        if (!rec) return;
        const row = tasks.index(rec.row, 0);
        if (!row || !row.valid) return;
        try {
            tasks.requestPublishDelegateGeometry(row, Qt.rect(Math.round(x), Math.round(y), Math.round(width), Math.round(height)));
        } catch (e) {
            // Ignored if compositor does not support delegate geometry
        }
    }

    // ---- model ------------------------------------------------------------

    TaskManager.TasksModel {
        id: tasks

        // One row per application with its windows underneath, so an app with
        // three windows is still one dock icon carrying three dots.
        groupMode: TaskManager.TasksModel.GroupApplications
        groupInline: false

        onCountChanged: rebuildTimer.restart()
        onActiveTaskChanged: rebuildTimer.restart()
        onDataChanged: rebuildTimer.restart()
        onModelReset: rebuildTimer.restart()
        onLayoutChanged: rebuildTimer.restart()
        onRowsInserted: rebuildTimer.restart()
        onRowsRemoved: rebuildTimer.restart()
        onRowsMoved: rebuildTimer.restart()
    }

    // Coalesce high-frequency bursts (e.g. streaming window titles) into 50ms batches
    Timer {
        id: rebuildTimer
        interval: 50
        onTriggered: root.rebuild()
    }

    // What the last rebuild produced. Comparing against it keeps `apps` -- and
    // therefore every icon's bindings -- untouched when nothing the dock shows
    // has actually changed.
    property string signature: ""

    function rebuild() {
        const apps = ({});

        for (let i = 0; i < tasks.count; i++) {
            const row = tasks.index(i, 0);
            if (!tasks.data(row, root.roleIsWindow)) continue;

            const launcherUrl = tasks.data(row, root.roleLauncherUrl);
            const appIdVal = tasks.data(row, root.roleAppId);
            const appName = tasks.data(row, root.roleAppName);
            const iconVal = tasks.data(row, root.roleIcon);

            let key = root.key(launcherUrl);
            if (key === "") key = root.key(appIdVal);
            if (key === "") key = root.key(appName);
            if (key === "") continue;

            const grouped = tasks.data(row, root.roleIsGroupParent);
            const windows = grouped ? Math.max(1, tasks.data(row, root.roleChildCount)) : 1;

            // An app can hold more than one top-level row when its windows
            // aren't groupable, so accumulate rather than overwrite.
            let rec = apps[key];
            if (!rec) {
                rec = {
                    row: i,
                    rows: [i],
                    windows: 0,
                    active: false,
                    launcherUrl: launcherUrl,
                    appId: appIdVal || key,
                    name: appName || key,
                    icon: iconVal || key
                };
                apps[key] = rec;
            } else {
                if (rec.rows.indexOf(i) < 0) rec.rows.push(i);
            }
            rec.windows += windows;
            rec.active = rec.active || tasks.data(row, root.roleIsActive) === true;
        }

        const parts = [String(tasks.activeTask)];
        for (const key of Object.keys(apps).sort()) {
            const rec = apps[key];
            parts.push(key + ":" + rec.row + ":" + rec.windows + ":" + rec.active);
        }

        const signature = parts.join("|");
        if (signature === root.signature) return;

        root.signature = signature;
        root.apps = apps;
        root.revision++;
    }

    Component.onCompleted: rebuild()
}
