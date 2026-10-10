// Lock.qml — session lock (ext-session-lock-v1 + PAM), replaces hyprlock
// qs ipc call lock lock
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Services.Mpris

Scope {
    id: root

    property bool locked: false
    property string password: ""
    property bool failed: false
    property bool busy: false
    property string wallpaper: ""

    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? null

    function lock() {
        if (locked) return
        password = ""
        failed = false
        busy = false
        stateFile.reload()
        locked = true
    }

    function submit() {
        if (busy || password.length === 0) return
        failed = false
        busy = true
        if (!pam.start()) {
            busy = false
            failed = true
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { root.lock() }
        function isLocked(): bool { return root.locked }
    }

    // Wallpaper recorded by ~/.config/43pr/bin/theme.py
    FileView {
        id: stateFile
        path: Quickshell.env("HOME") + "/.local/state/43pr/state.json"
        printErrors: false
        onLoaded: {
            try {
                root.wallpaper = JSON.parse(text()).wallpaper || ""
            } catch (e) {
                root.wallpaper = ""
            }
        }
    }

    PamContext {
        id: pam
        // Void's /etc/pam.d/system-auth: pam_unix password check, no tty requirements
        configDirectory: "/etc/pam.d"
        config: "system-auth"
        onPamMessage: {
            if (responseRequired) respond(root.password)
        }
        onCompleted: result => {
            root.busy = false
            if (result === PamResult.Success) {
                root.password = ""
                root.locked = false
            } else {
                root.password = ""
                root.failed = true
            }
        }
        onError: {
            root.busy = false
            root.failed = true
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    WlSessionLock {
        id: sessionLock
        locked: root.locked

        WlSessionLockSurface {
            id: surface
            color: Theme._bgBase

            Image {
                id: wall
                anchors.fill: parent
                source: root.wallpaper !== "" ? "file://" + root.wallpaper : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
            }

            MultiEffect {
                anchors.fill: parent
                source: wall
                visible: wall.status === Image.Ready
                blurEnabled: true
                blur: 1.0
                blurMax: 48
                brightness: -0.25
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(Theme._bgBase, 0.35)
            }

            Column {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -60
                spacing: 6

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(clock.date, "HH:mm")
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 96
                    font.bold: true
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDate(clock.date, "dddd, d MMMM").toUpperCase()
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.letterSpacing: 2
                }
            }

            Rectangle {
                id: field
                width: 320
                height: 46
                radius: Theme.radius
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 70
                color: Qt.alpha(Theme.bgPanel, 0.75)
                border.width: 1
                border.color: root.failed ? Theme.danger
                            : input.activeFocus ? Theme.accent : Theme.border

                Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                SequentialAnimation {
                    id: shake
                    loops: 1
                    NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: -12; duration: 50 }
                    NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: 12; duration: 70 }
                    NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: -6; duration: 60 }
                    NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: 0; duration: 50 }
                }

                Connections {
                    target: root
                    function onFailedChanged() { if (root.failed) shake.restart() }
                }

                TextInput {
                    id: input
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    verticalAlignment: TextInput.AlignVCenter
                    horizontalAlignment: TextInput.AlignHCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    font.letterSpacing: 3
                    enabled: !root.busy
                    focus: true
                    clip: true
                    text: root.password
                    onTextEdited: {
                        root.password = text
                        root.failed = false
                    }
                    onAccepted: root.submit()
                    Keys.onEscapePressed: root.password = ""
                    Component.onCompleted: forceActiveFocus()
                }

                Text {
                    anchors.centerIn: parent
                    visible: input.text.length === 0
                    text: root.busy ? "CHECKING…" : root.failed ? "WRONG PASSWORD" : "PASSWORD"
                    color: root.failed ? Theme.danger : Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 2
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 48
                width: Math.min(parent.width - 64, 640)
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                visible: root.player !== null
                text: root.player ? "  " + (root.player.trackArtist ? root.player.trackArtist + " — " : "") + root.player.trackTitle : ""
                color: Theme.textDim
                font.family: Theme.iconFont
                font.pixelSize: 13
            }

            Text {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 24
                text: Quickshell.env("USER")
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.bold: true
                font.letterSpacing: 1
            }
        }
    }
}
