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

    // Brings an app's window to the front: switches to its tag and focuses it.
    // Matched by desktop entry or app name against the client appid, ignoring
    // case and punctuation ("Google Chrome" / "google-chrome", "Slack" / "slack").
    function focusApp(desktopEntry, appName) {
        Quickshell.execDetached({ command: ["sh", "-c", `
            target=$(mmsg get all-clients | jq -r --arg a "$1" --arg b "$2" '
                def norm: ascii_downcase | gsub("[^a-z0-9]"; "");
                def hit($x; $k): ($k | norm) as $k | $k != "" and (($x | contains($k)) or ($k | contains($x)));
                [.clients[] | (.appid // "" | norm) as $x | select($x != "" and (hit($x; $a) or hit($x; $b)))]
                | first // empty | "\\(.id) \\(.tags[0] // 0)"')
            [ -n "$target" ] || exit 0
            set -- $target
            [ "$2" -gt 0 ] && mmsg dispatch "view,$2,0"
            mmsg dispatch "focusid,$1"
        `, "focus-app", desktopEntry || "", appName || ""] })
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
