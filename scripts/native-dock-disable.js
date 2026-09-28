// Plasma Scripting to remove all native bottom dock panels safely
var removedCount = 0;
while (true) {
    var panels = panelIds;
    var found = false;
    for (var i = 0; i < panels.length; ++i) {
        var p = panelById(panels[i]);
        if (p && p.location === "bottom") {
            p.remove();
            removedCount++;
            found = true;
            break;
        }
    }
    if (!found) break;
}
print("SUCCESS: Removed " + removedCount + " bottom panel(s)");
