pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

// Interface style picked in Settings > Theme ("default" or "minecraft").
// Small tweaks bind to `minecraft`; whole popups have a *Mc.qml twin that comp() swaps in.
Item {
    id: root

    readonly property var styles: ["default", "minecraft"]

    readonly property string style: {
        let t = Config.rawSettings && Config.rawSettings.theme;
        let s = t && t.uiStyle;
        return root.styles.indexOf(s) !== -1 ? s : "default";
    }
    readonly property bool minecraft: style === "minecraft"

    readonly property var mcVariants: ({
        "calendar/CalendarPopup.qml": "calendar/CalendarPopupMc.qml",
        "media/MusicPopup.qml": "media/MusicPopupMc.qml",
        "network/NetworkPopup.qml": "network/NetworkPopupMc.qml",
        "volume/VolumePopup.qml": "volume/VolumePopupMc.qml",
        "syspanel/SystemPanel.qml": "syspanel/SystemPanelMc.qml"
    })

    function comp(path) {
        if (typeof path !== "string") return path;
        return (root.minecraft && root.mcVariants[path]) ? root.mcVariants[path] : path;
    }
    function hasVariant(path) {
        return typeof path === "string" && root.mcVariants[path] !== undefined;
    }

    // Switch style. Minecraft also sets the pixel font, square corners and the
    // Steve workspaces; the previous values are kept and restored on the way back.
    function apply(newStyle) {
        if (root.styles.indexOf(newStyle) === -1 || newStyle === root.style) return;
        // Write on the next event-loop turn: changing settings in the middle of an IPC
        // call or a button handler rebuilds half the shell under the caller's feet.
        Qt.callLater(root._write, newStyle);
    }

    function _write(newStyle) {
        if (newStyle === root.style) return;
        let theme = Config.getSetting("theme", {});
        let bar = Config.getSetting("bar", {});
        if (newStyle === "minecraft") {
            theme.uiStyleSaved = {
                fontFamily: theme.fontFamily,
                borderRadius: theme.borderRadius,
                workspacesStyle: bar.workspacesStyle
            };
            theme.fontFamily = "Monocraft";
            theme.borderRadius = 0;
            bar.workspacesStyle = "minecraft";
        } else {
            let saved = theme.uiStyleSaved || {};
            theme.fontFamily = (saved.fontFamily && saved.fontFamily !== "Monocraft") ? saved.fontFamily : "Adwaita Mono";
            theme.borderRadius = (saved.borderRadius !== undefined && saved.borderRadius !== 0) ? saved.borderRadius : 8;
            bar.workspacesStyle = (saved.workspacesStyle && saved.workspacesStyle !== "minecraft") ? saved.workspacesStyle : "pills";
        }
        theme.uiStyle = newStyle;
        Config.updateJsonBulk({ "theme": theme, "bar": bar });
    }

    // qs ipc call uistyle set minecraft|default
    IpcHandler {
        target: "uistyle"
        function set(name: string): void { root.apply(name); }
        function get(): string { return root.style; }
    }
}
