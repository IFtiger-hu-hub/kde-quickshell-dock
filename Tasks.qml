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
    readonly property int roleIsWindow: TaskManager.AbstractTasksModel.IsWindow
    readonly property int roleIsGroupParent: TaskManager.AbstractTasksModel.IsGroupParent
    readonly property int roleChildCount: TaskManager.AbstractTasksModel.ChildCount
    readonly property int roleIsActive: TaskManager.AbstractTasksModel.IsActive
    readonly property int roleIsMinimized: TaskManager.AbstractTasksModel.IsMinimized

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

    // ---- actions ----------------------------------------------------------

    // Raises the app's windows. When it owns several, each call steps to the
    // next one, so repeated clicks cycle the group instead of arguing over
    // which single window counts as "the" window.
    function activate(key) {
        const rec = root.info(key);
        if (!rec) return false;

        const row = tasks.index(rec.row, 0);
        const children = tasks.data(row, root.roleIsGroupParent) ? tasks.rowCount(row) : 0;
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

    // dataChanged fires for things the dock doesn't care about (window titles,
    // most of all), so coalesce a burst into one rebuild at the end of the
    // event loop turn.
    Timer {
        id: rebuildTimer
        interval: 0
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

            const key = root.key(tasks.data(row, root.roleLauncherUrl));
            if (key === "") continue;

            const grouped = tasks.data(row, root.roleIsGroupParent);
            const windows = grouped ? Math.max(1, tasks.data(row, root.roleChildCount)) : 1;

            // An app can hold more than one top-level row when its windows
            // aren't groupable, so accumulate rather than overwrite.
            let rec = apps[key];
            if (!rec) {
                rec = { row: i, windows: 0, active: false };
                apps[key] = rec;
            }
            rec.windows += windows;
            rec.active = rec.active || tasks.data(row, root.roleIsActive) === true;
        }

        const parts = [];
        for (const key of Object.keys(apps).sort()) {
            const rec = apps[key];
            parts.push(key + ":" + rec.row + ":" + rec.windows + ":" + rec.active);
        }

        const signature = parts.join("|");
        if (signature === root.signature) return;

        root.signature = signature;
        root.apps = apps;
    }

    Component.onCompleted: rebuild()
}
