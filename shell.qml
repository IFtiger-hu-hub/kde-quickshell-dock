//@ pragma UseQApplication

import Quickshell

ShellRoot {
    // Dynamically filter active screens based on perScreenConfig or screenMode ("all", "primary", "custom")
    Variants {
        model: {
            Config.screenMode;
            Config.targetScreen;
            Config.perScreenConfig;
            Config.revision;
            const screens = Quickshell.screens;
            if (!screens || screens.length === 0) return [];

            if (Config.perScreenConfig) {
                const result = [];
                for (let i = 0; i < screens.length; i++) {
                    const scName = screens[i].name;
                    if (Config.getVal(scName, "enabled") !== false) {
                        result.push(screens[i]);
                    }
                }
                return result;
            }

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