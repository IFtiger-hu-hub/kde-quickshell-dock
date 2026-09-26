//@ pragma UseQApplication

import Quickshell

ShellRoot {
    // Dynamically filter active screens based on Config.screenMode ("all", "primary", "custom")
    // Only instantiates Dock on selected screens, significantly saving memory and GPU resources.
    Variants {
        model: {
            Config.screenMode;
            Config.targetScreen;
            const screens = Quickshell.screens;
            if (!screens || screens.length === 0) return [];
            if (Config.screenMode === "primary") {
                return [screens[0]];
            }
            if (Config.screenMode === "custom" && Config.targetScreen !== "") {
                for (let i = 0; i < screens.length; i++) {
                    if (screens[i].name === Config.targetScreen) {
                        return [screens[i]];
                    }
                }
            }
            return screens;
        }

        Dock {
            required property var modelData
            screen: modelData
        }
    }
}
