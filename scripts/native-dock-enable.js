// Plasma Scripting to create macOS-style floating dock panel
var panels = panelIds;
for (var i = 0; i < panels.length; ++i) {
    var p = panelById(panels[i]);
    if (p.location === "bottom") {
        p.remove();
    }
}

var dock = new Panel();
dock.location = "bottom";
dock.alignment = "center";
dock.floating = true;
dock.lengthMode = "fitContent";
dock.height = 56;
dock.opacity = "translucent";
dock.hiding = "windowdodge";

var tasks = dock.addWidget("org.kde.plasma.icontasks");
var sep = dock.addWidget("org.kde.plasma.marginsseparator");
var trash = dock.addWidget("org.kde.plasma.trash");

print("SUCCESS: Created KDE native floating dock panel (ID: " + dock.id + ")");
