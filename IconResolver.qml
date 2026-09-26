pragma Singleton

import Quickshell

// Turns a desktop entry's Icon= value into a list of image sources to try in
// order.
//
// A single lookup isn't enough in practice. Icon= may be an absolute path
// (dbeaver-ce ships Icon=/usr/share/dbeaver-ce/dbeaver.png), and third-party
// icon themes are inconsistent about naming: Ant-Dark has dbeaver.svg but no
// dbeaver-ce.svg, and ships both tilix.svg and com.gexperts.Tilix.svg. Asking
// only for the exact name silently lands on the generic executable icon, which
// looks like the icon simply failed to load.
Singleton {
    id: root
    readonly property var _cache: ({})
    readonly property var _themedCache: ({})

    function candidates(entry) {
        if (!entry) return [];

        const cacheKey = String(entry.id || "") + ":" + String(entry.icon || "") + ":" + String(entry.name || "");
        if (root._cache[cacheKey]) return root._cache[cacheKey];

        const out = [];
        const push = url => { if (url && out.indexOf(url) < 0) out.push(url); };

        const icon = String(entry.icon ?? "");

        // An absolute path bypasses the icon theme entirely.
        if (icon.startsWith("/")) push("file://" + icon);
        else push(root.themed(icon));

        for (const name of root.variants(icon, entry)) push(root.themed(name));

        for (const generic of ["application-x-executable", "application-default-icon", "exec", "unknown"]) {
            push(root.themed(generic));
        }

        // A theme with none of the generics above would otherwise leave nothing
        // to draw, so fall back to asking for the raw name regardless.
        if (out.length === 0 && icon !== "") {
            push(icon.startsWith("/") ? "file://" + icon : "image://icon/" + icon);
        }

        root._cache[cacheKey] = out;
        return out;
    }

    // Empty string when the active theme has no such icon, so callers can skip
    // it rather than rendering a blank.
    function themed(name) {
        if (!name || name.startsWith("/")) return "";
        if (root._themedCache[name] !== undefined) return root._themedCache[name];
        const p = Quickshell.iconPath(name, true);
        root._themedCache[name] = p;
        return p;
    }

    function variants(icon, entry) {
        const out = [];
        const add = name => { if (name && out.indexOf(name) < 0) out.push(name); };

        const bases = [];
        if (icon.startsWith("/")) {
            // /usr/share/dbeaver-ce/dbeaver.png -> dbeaver
            const file = icon.slice(icon.lastIndexOf("/") + 1);
            const dot = file.lastIndexOf(".");
            bases.push(dot > 0 ? file.slice(0, dot) : file);
        } else if (icon !== "") {
            bases.push(icon);
        }
        if (entry.id) bases.push(String(entry.id));

        for (const base of bases) {
            add(base);
            add(base.toLowerCase());

            // com.gexperts.Tilix -> tilix
            if (base.indexOf(".") >= 0) add(base.slice(base.lastIndexOf(".") + 1).toLowerCase());

            // dbeaver-ce -> dbeaver
            const trimmed = base.replace(/-(ce|ee|community|enterprise|desktop|stable|bin|gtk|qt)$/i, "");
            if (trimmed !== base) { add(trimmed); add(trimmed.toLowerCase()); }
        }

        if (entry.name) add(String(entry.name).toLowerCase().replace(/\s+/g, "-"));

        return out;
    }
}
