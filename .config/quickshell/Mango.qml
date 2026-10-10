// Mango.qml — mangowc IPC (via `mmsg`), replaces Quickshell.Hyprland
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    // [{ name, active, x, y, width, height, scale, tags: [...], active_tags, active_client }]
    property var monitors: []
    readonly property var focusedMonitor: monitors.find(m => m.active) ?? monitors[0] ?? null
    readonly property var activeClient: focusedMonitor ? focusedMonitor.active_client ?? null : null

    // Tags of a monitor as workspace-like objects: { id, focused, urgent, occupied }
    function tagsFor(monName) {
        const mon = monitors.find(m => m.name === monName) ?? focusedMonitor
        if (!mon || !mon.tags) return []
        return mon.tags.map(t => ({
            id: t.index,
            focused: t.is_active,
            urgent: t.is_urgent,
            occupied: t.client_count > 0,
            monitor: mon.name
        }))
    }

    function dispatch(args) {
        Quickshell.execDetached({ command: ["mmsg", "dispatch", args] })
    }

    function viewTag(id, monName) {
        if (monName && focusedMonitor && monName !== focusedMonitor.name)
            Quickshell.execDetached({ command: ["sh", "-c",
                "mmsg dispatch focusmon," + monName + " && mmsg dispatch view," + id + ",0"] })
        else
            dispatch("view," + id + ",0")
    }

    function nextTag() { dispatch("viewtoright_have_client") }
    function prevTag() { dispatch("viewtoleft_have_client") }

    Process {
        id: watcher
        running: true
        command: ["mmsg", "watch", "all-monitors"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    root.monitors = JSON.parse(line).monitors ?? []
                } catch (e) {
                    console.warn("mango: bad mmsg line:", e)
                }
            }
        }
        // mmsg exits if the compositor restarts its IPC; reconnect.
        onExited: restartTimer.restart()
    }

    Timer {
        id: restartTimer
        interval: 1000
        onTriggered: watcher.running = true
    }
}
