// =============================================================================
// Plasma 6 Scripting: 构建高仿 macOS 风格居中浮动 Dock 面板
// =============================================================================

// 1. 清理已有底栏面板（防止重叠，保留顶栏系统栏）
var panels = panelIds;
for (var i = 0; i < panels.length; ++i) {
    var p = panelById(panels[i]);
    if (p.location === "bottom") {
        p.remove();
    }
}

// 2. 为各屏幕创建 macOS 浮动 Dock
function createMacDockForScreen(sIdx) {
    var dock = new Panel();
    dock.screen = sIdx;
    dock.location = "bottom";
    dock.alignment = "center";
    dock.floating = true;
    dock.lengthMode = "fit";
    dock.minimumLength = 0;
    dock.maximumLength = Math.round(screenGeometry(sIdx).width * 0.9);
    dock.height = 58;
    dock.opacity = "translucent";
    dock.hiding = "none"; // "none" (常驻) 或 "dodgewindows" (窗口智能避让)

    // 图标任务栏 (仿 macOS 应用程序区)
    var tasks = dock.addWidget("org.kde.plasma.icontasks");
    tasks.currentConfigGroup = ["General"];
    tasks.writeConfig("launchers", [
        "applications:org.kde.dolphin.desktop",
        "applications:org.kde.discover.desktop",
        "applications:microsoft-edge.desktop",
        "applications:antigravity-ide.desktop",
        "applications:jetbrains-webstorm-d88bba36-d382-4442-b98c-79876c6671dd.desktop",
        "applications:org.kde.konsole.desktop",
        "applications:systemsettings.desktop"
    ]);

    // 固定宽度小间距分隔
    var spacer = dock.addWidget("org.kde.plasma.panelspacer");
    spacer.currentConfigGroup = ["Configuration", "General"];
    spacer.writeConfig("expanding", false);
    spacer.writeConfig("length", 12);

    // 废纸篓 (仿 macOS Dock 右侧回收站)
    var trash = dock.addWidget("org.kde.plasma.trash");

    dock.reloadConfig();
    return dock.id;
}

// 在所有可用屏幕上构建 macOS Dock
var created = [];
for (var s = 0; s < screenCount; ++s) {
    var dId = createMacDockForScreen(s);
    created.push("Screen " + s + " (ID: " + dId + ")");
}

print("SUCCESS: Created KDE macOS floating dock on: " + created.join(", "));
