//@ pragma UseQApplication
// (QApplication mode is required for the system tray context menus)
import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: shell

    // Overlay windows (menus, OSDs, notifications) are created once and keep the
    // screen they were created on. When every output disappears (monitor powered
    // off / standby / re-plugged, a game switching modes), Qt moves them to a
    // placeholder screen and they never show again — the power menu stops
    // opening. So whenever the screen list changes they are rebuilt.
    // The bar follows Quickshell.screens by itself; the lock screen is kept out:
    // destroying a WlSessionLock while locked would leave the session stuck.
    property bool overlaysLive: true

    function recreateOverlays() {
        overlaysLive = false;
        recreateTimer.restart();
    }

    Timer {
        id: recreateTimer
        interval: 400
        onTriggered: shell.overlaysLive = true
    }

    // Debounced: a re-plug usually fires several changes in a row.
    Timer {
        id: screensSettled
        interval: 800
        onTriggered: if (Quickshell.screens.length > 0) shell.recreateOverlays()
    }

    Connections {
        target: Quickshell
        function onScreensChanged() { screensSettled.restart(); }
    }

    IpcHandler {
        target: "shell"
        // Manual recovery without restarting Quickshell: qs ipc call shell recreate
        function recreate(): void { shell.recreateOverlays(); }
    }

    LazyLoader {
        active: shell.overlaysLive

        Scope {
            VolumeOsd {}
            ScreenshotOsd {}
            SettingsWindow {}
            Notifications {}
            PowerMenu {}
            Todo {}
            Wheel {}
        }
    }

    Bar {}
    Lock {}
}
