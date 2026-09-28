// Plasma Scripting to remove native bottom dock panel
var panels = panelIds;
var removedCount = 0;
for (var i = 0; i < panels.length; ++i) {
    var p = panelById(panels[i]);
    if (p.location === "bottom") {
        p.remove();
        removedCount++;
    }
}
print("SUCCESS: Removed " + removedCount + " bottom panel(s)");
