import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import Quickshell.Widgets

Scope {
    id: root
    FileView {
        id: cfgFile
        path: Quickshell.env("HOME") + "/.config/quickshell/state/bar-state.json"
        printErrors: false
        onAdapterUpdated: saveTimer.restart()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) writeAdapter();
        }

        adapter: JsonAdapter {
            id: cfg
            property string position: "top"
            property string style: "floating"
            property int thickness: 30
            property int margin: 4
            property real scale: 1.0
            property real bgOpacity: 0.85
            property bool border: true
            property bool showStats: true
            property bool showWs: true
            property bool showMedia: true
            property bool showVolume: true
            property bool showBattery: true
            property bool showNet: true
            property bool showNotif: true
            property bool showWall: true
            property bool showTitle: true
            property bool showTray: true
            property string startMods: "ws,title"
            property string centerMods: "clock"
            property string endMods: "media,stats,tray,volume,battery,net,notif,wall,power"
        }
    }

    Timer {
        id: saveTimer
        interval: 300
        onTriggered: cfgFile.writeAdapter()
    }

    function resetSettings() {
        cfg.position = "top"; cfg.style = "floating"; cfg.thickness = 30; cfg.margin = 4;
        cfg.scale = 1.0; cfg.bgOpacity = 0.85; cfg.border = true;
        cfg.showStats = false; cfg.showWs = true; cfg.showMedia = true;
        cfg.showVolume = true; cfg.showBattery = true; cfg.showNet = true;
        cfg.showNotif = true; cfg.showWall = true; cfg.showTitle = true; cfg.showTray = true;
        cfg.startMods = "ws,title";
        cfg.centerMods = "clock";
        cfg.endMods = "media,stats,tray,volume,battery,net,notif,wall,power";
    }

    readonly property bool vertical: cfg.position === "left" || cfg.position === "right"
    readonly property bool joined: cfg.style !== "floating"
    readonly property int panelThick: vertical ? cfg.thickness + 12 : cfg.thickness
    readonly property int effEdge: cfg.style === "strip" ? 0 : cfg.margin
    readonly property int effGap: cfg.style === "strip" ? 0 : 6
    readonly property real barRadius: cfg.style === "strip" ? 0 : cfg.style === "floating" ? panelThick / 2 : Theme.radius
    readonly property color bgColor: Qt.alpha(Theme.bg, cfg.bgOpacity)
    readonly property color borderColor: Qt.alpha(Theme.accent, 0.14)

    // Bar typeface: proportional sans with Nerd Font glyphs (icons render from the same font)
    readonly property string barFont: "UbuntuSans Nerd Font Propo"

    function s(n) { return Math.round(n * cfg.scale); }

    readonly property int sizeCpuRam: s(12)
    readonly property int sizeClock: s(13)
    readonly property int sizeMarquee: s(12)
    readonly property int sizeMediaVertical: s(26)
    readonly property int sizeNetIcon: s(17)
    readonly property int sizeVolIcon: s(17)
    readonly property int sizeVolText: s(13)
    readonly property int sizeBatIcon: s(13)
    readonly property int sizeBatText: s(12)
    readonly property int sizePowerIcon: s(15)
    readonly property int sizeIconGap: 7
    readonly property int iconYOffset: 1
    readonly property int sizeTitle: s(12)
    readonly property int sizeDate: s(11)

    readonly property int sizeCalTime: s(30)
    readonly property int sizeCalDate: s(12)
    readonly property int sizeCalMonth: s(13)
    readonly property int sizeCalArrow: s(16)
    readonly property int sizeCalWeekday: s(11)
    readonly property int sizeCalDay: s(12)

    readonly property var battery: UPower.devices.values.find(d => d.isLaptopBattery)
        ?? (UPower.displayDevice && UPower.displayDevice.isPresent
            && UPower.displayDevice.type === UPowerDeviceType.Battery
            ? UPower.displayDevice : null)
    readonly property int batPct: battery ? Math.round(battery.percentage * 100) : 0
    readonly property bool batCharging: battery !== null
        && (battery.state === UPowerDeviceState.Charging
            || battery.state === UPowerDeviceState.PendingCharge
            || battery.state === UPowerDeviceState.FullyCharged)
    readonly property bool batLow: battery !== null && !batCharging && batPct <= 15
    readonly property var batIcons: ["\uf244", "\uf243", "\uf242", "\uf241", "\uf240"]
    readonly property string batIcon: batIcons[batPct >= 90 ? 4 : batPct >= 65 ? 3 : batPct >= 40 ? 2 : batPct >= 15 ? 1 : 0]

    readonly property var moduleIds: ["stats", "ws", "title", "media", "tray", "volume", "battery", "net", "notif", "wall", "power"]
    readonly property var moduleDefs: [
        { id: "stats", l: "CPU / RAM (x)", k: "showStats" },
        { id: "ws", l: "Tags", k: "showWs" },
        { id: "title", l: "Window title", k: "showTitle" },
        { id: "media", l: "Media", k: "showMedia" },
        { id: "tray", l: "System tray", k: "showTray" },
        { id: "volume", l: "Volume", k: "showVolume" },
        { id: "battery", l: "Battery", k: "showBattery" },
        { id: "net", l: "Network", k: "showNet" },
        { id: "notif", l: "Notifications", k: "showNotif" },
        { id: "wall", l: "Wallpapers", k: "showWall" },
        { id: "power", l: "Power", k: "" }
    ]

    readonly property var startList: cfg.startMods === "" ? []
        : cfg.startMods.split(",").filter(x => moduleIds.indexOf(x) >= 0)

    readonly property var centerList: {
        const a = cfg.centerMods === "" ? []
            : cfg.centerMods.split(",").filter(x => x === "clock" || moduleIds.indexOf(x) >= 0);
        return a.indexOf("clock") >= 0 ? a : ["clock"].concat(a);
    }

    readonly property var endList: {
        const a = cfg.endMods === "" ? []
            : cfg.endMods.split(",").filter(x => moduleIds.indexOf(x) >= 0);
        const miss = moduleIds.filter(x => startList.indexOf(x) < 0 && centerList.indexOf(x) < 0 && a.indexOf(x) < 0);
        return a.concat(miss);
    }

    function sectionOf(id) {
        if (startList.indexOf(id) >= 0) return "start";
        if (centerList.indexOf(id) >= 0) return "center";
        return "end";
    }

    function moveTo(id, sec) {
        const st = startList.filter(x => x !== id);
        const ce = centerList.filter(x => x !== id);
        const en = endList.filter(x => x !== id);
        (sec === "start" ? st : sec === "center" ? ce : en).push(id);
        cfg.startMods = st.join(",");
        cfg.centerMods = ce.join(",");
        cfg.endMods = en.join(",");
    }

    function shiftBy(id, d) {
        const sec = sectionOf(id);
        const a = (sec === "start" ? startList : sec === "center" ? centerList : endList).slice();
        const i = a.indexOf(id);
        const j = i + d;
        if (i < 0 || j < 0 || j >= a.length) return;
        const t = a[i];
        a[i] = a[j];
        a[j] = t;
        if (sec === "start") cfg.startMods = a.join(",");
        else if (sec === "center") cfg.centerMods = a.join(",");
        else cfg.endMods = a.join(",");
    }

    function modVisible(id) {
        switch (id) {
        case "stats": return cfg.showStats && !vertical;
        case "ws": return cfg.showWs;
        case "media": return cfg.showMedia && Marquee.player !== null && Marquee.title !== "";
        case "tray": return cfg.showTray && SystemTray.items.values.length > 0;
        case "volume": return cfg.showVolume;
        case "battery": return cfg.showBattery && battery !== null;
        case "net": return cfg.showNet;
        case "notif": return cfg.showNotif;
        case "wall": return cfg.showWall;
        case "title": return cfg.showTitle && !vertical && Mango.activeClient !== null && (Mango.activeClient.title || "") !== "";
        default: return true;
        }
    }

    function compFor(id) {
        switch (id) {
        case "stats": return statsC;
        case "ws": return wsC;
        case "media": return mediaC;
        case "tray": return trayC;
        case "volume": return volumeC;
        case "battery": return batteryC;
        case "net": return netC;
        case "notif": return notifC;
        case "wall": return wallC;
        case "title": return titleC;
        case "power": return powerC;
        default: return null;
        }
    }

    property bool barVisible: true
    property bool settingsOpen: false

    property bool barLive: true
    function rebuildBar() { barLive = false; rebuildTimer.restart(); }
    Timer { id: rebuildTimer; interval: 80; onTriggered: root.barLive = true }
    Connections {
        target: cfg
        function onPositionChanged() { root.rebuildBar(); }
        function onStyleChanged() { root.rebuildBar(); }
    }

    IpcHandler {
        target: "bar"
        function toggle(): void { root.barVisible = !root.barVisible; }
        function show(): void { root.barVisible = true; }
        function hide(): void { root.barVisible = false; }
        function setPosition(pos: string): void {
            if (["top", "right", "bottom", "left"].indexOf(pos) >= 0) cfg.position = pos;
        }
        function cyclePosition(): void {
            const order = ["top", "right", "bottom", "left"];
            cfg.position = order[(order.indexOf(cfg.position) + 1) % order.length];
        }
        function setStyle(st: string): void {
            if (["floating", "joined", "strip"].indexOf(st) >= 0) cfg.style = st;
        }
        function customize(): void { root.settingsOpen = !root.settingsOpen; }
        function moveModule(id: string, section: string): void {
            if (root.moduleIds.indexOf(id) >= 0 && ["start", "center", "end"].indexOf(section) >= 0)
                root.moveTo(id, section);
        }
        function shiftModule(id: string, delta: int): void {
            if (root.moduleIds.indexOf(id) >= 0) root.shiftBy(id, delta);
        }
    }

    property int cpuUsage: 0
    property int memPercent: 0
    property string netState: "disconnected"
    property real _prevTotal: 0
    property real _prevIdle: 0

    FileView {
        id: statFile
        path: "/proc/stat"
        onLoaded: {
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1, 9).map(Number);
            const total = f.reduce((a, b) => a + b, 0);
            const idle = f[3] + f[4];
            const dT = total - root._prevTotal;
            const dI = idle - root._prevIdle;
            if (root._prevTotal > 0 && dT > 0)
                root.cpuUsage = Math.round(100 * (dT - dI) / dT);
            root._prevTotal = total;
            root._prevIdle = idle;
        }
    }

    FileView {
        id: memFile
        path: "/proc/meminfo"
        onLoaded: {
            const t = text();
            const kb = k => Number(t.match(new RegExp(k + ":\\s+(\\d+)"))[1]);
            root.memPercent = Math.round(100 * (kb("MemTotal") - kb("MemAvailable")) / kb("MemTotal"));
        }
    }

    Process {
        id: netProc
        command: ["nmcli", "-t", "-f", "TYPE,STATE", "device"]
        stdout: StdioCollector {
            onStreamFinished: {
                let s = "disconnected";
                for (const l of text.split("\n")) {
                    if (l === "ethernet:connected") { s = "ethernet"; break; }
                    if (l === "wifi:connected") s = "wifi";
                }
                if (s !== root.netState) root.netState = s;
            }
        }
    }

    Timer {
        interval: 2000; running: root.barVisible; repeat: true; triggeredOnStart: true
        onTriggered: { statFile.reload(); memFile.reload(); }
    }

    Timer {
        interval: 10000; running: root.barVisible; repeat: true; triggeredOnStart: true
        onTriggered: if (!netProc.running) netProc.running = true
    }

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    Process { id: runner }
    function run(cmd) {
        runner.command = ["sh", "-c", cmd];
        runner.running = true;
    }

    component Lane: GridLayout {
        property int gap: 0
        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: gap
        columnSpacing: gap
    }

    component Panel: Rectangle {
        property Item lane
        visible: lane ? (root.vertical ? lane.implicitHeight : lane.implicitWidth) > 0 : false
        width: root.vertical ? root.panelThick : (lane ? lane.implicitWidth + 10 : 0)
        height: root.vertical ? (lane ? lane.implicitHeight + 10 : 0) : root.panelThick
        radius: root.barRadius
        color: root.joined ? "transparent" : root.bgColor
        border.width: cfg.border && !root.joined ? 1 : 0
        border.color: root.borderColor
    }

    component Mod: Item {
        id: mod
        property string text: ""
        property string vtext: text
        property string glyph: ""
        property string vglyph: glyph
        property real glyphSize: 16
        property real baseSize: 11
        property color color: Theme.text
        property bool bold: false
        property real yOffset: 0
        signal clicked(var mouse)
        signal scrolled(real delta)

        readonly property string shown: root.vertical ? vtext : text
        readonly property string shownGlyph: root.vertical ? vglyph : glyph

        Layout.alignment: Qt.AlignCenter
        implicitWidth: root.vertical ? root.panelThick : content.implicitWidth + 22
        implicitHeight: root.vertical ? Math.max(20, content.implicitHeight + 8)
                                      : Math.max(root.panelThick - 2, content.implicitHeight)

        Rectangle {
            anchors.centerIn: parent
            width: parent.width - (root.vertical ? 6 : 4)
            height: root.vertical ? parent.height - 2 : root.panelThick - 8
            radius: root.barRadius > 0 ? Math.min(height / 2, root.barRadius) : 0
            color: Qt.alpha(Theme.accent, ma.pressed ? 0.22 : 0.12)
            opacity: ma.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
        }

        GridLayout {
            id: content
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.vertical ? 0 : mod.yOffset
            flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
            rowSpacing: 2
            columnSpacing: root.sizeIconGap

            Text {
                visible: mod.shownGlyph !== ""
                Layout.alignment: Qt.AlignCenter
                horizontalAlignment: Text.AlignHCenter
                text: mod.shownGlyph
                color: mod.color
                font.family: root.barFont
                font.pixelSize: mod.glyphSize
                renderType: Text.NativeRendering
            }

            Text {
                visible: mod.shown !== ""
                Layout.alignment: Qt.AlignCenter
                text: mod.shown
                color: mod.color
                horizontalAlignment: Text.AlignHCenter
                font.family: root.barFont
                font.bold: mod.bold
                font.pixelSize: mod.baseSize
                renderType: Text.NativeRendering
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: mouse => mod.clicked(mouse)
            onWheel: wheel => mod.scrolled(wheel.angleDelta.y)
        }
    }

    component Slot: Loader {
        id: slot
        required property string modelData
        property Component clockComp: null
        visible: root.modVisible(modelData)
        Layout.alignment: Qt.AlignCenter
        sourceComponent: modelData === "clock" ? clockComp : root.compFor(modelData)
    }

    component Lbl: Text {
        color: Theme.text
        font.family: root.barFont
        font.pixelSize: 12
    }

    component Seg: Row {
        id: seg
        property var options: []
        property string current: ""
        signal picked(string v)
        spacing: 4
        Repeater {
            model: seg.options
            delegate: Rectangle {
                id: opt
                required property string modelData
                width: Math.max(44, lbl.implicitWidth + 16)
                height: 22
                radius: Theme.radius
                color: opt.modelData === seg.current ? Qt.alpha(Theme.accent, 0.4)
                     : segMa.containsMouse ? Qt.alpha(Theme.text, 0.14)
                     : Qt.alpha(Theme.text, 0.07)
                Text {
                    id: lbl
                    anchors.centerIn: parent
                    text: opt.modelData
                    color: Theme.text
                    font.family: root.barFont
                    font.pixelSize: 11
                }
                MouseArea {
                    id: segMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: seg.picked(opt.modelData)
                }
            }
        }
    }

    component Btn: Rectangle {
        id: btn
        property string label: ""
        signal clicked()
        implicitWidth: 22
        implicitHeight: 22
        radius: Theme.radius
        color: btnMa.containsMouse ? Qt.alpha(Theme.accent, 0.35) : Qt.alpha(Theme.text, 0.07)
        Text {
            anchors.centerIn: parent
            text: btn.label
            color: Theme.text
            font.family: root.barFont
            font.pixelSize: 10
        }
        MouseArea {
            id: btnMa
            anchors.fill: parent
            hoverEnabled: true
            onClicked: btn.clicked()
        }
    }

    component Toggle: Rectangle {
        id: tg
        property bool checked: false
        signal toggled(bool v)
        implicitWidth: 34
        implicitHeight: 18
        radius: 9
        color: checked ? Qt.alpha(Theme.accent, 0.6) : Qt.alpha(Theme.text, 0.15)
        Rectangle {
            width: 14; height: 14; radius: 7; y: 2
            x: tg.checked ? 18 : 2
            color: Theme.text
            Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
        }
        MouseArea { anchors.fill: parent; onClicked: tg.toggled(!tg.checked) }
    }

    component Slide: Item {
        id: sl
        property real from: 0
        property real to: 1
        property real value: 0
        readonly property real frac: (value - from) / (to - from)
        signal moved(real v)
        implicitWidth: 140
        implicitHeight: 20

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: 4; radius: 2
            color: Qt.alpha(Theme.text, 0.15)
            Rectangle { width: parent.width * sl.frac; height: 4; radius: 2; color: Theme.accent }
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: (sl.width - width) * sl.frac
            width: 12; height: 12; radius: 6
            color: Theme.text
        }
        MouseArea {
            anchors.fill: parent
            function upd(px) {
                const f = Math.max(0, Math.min(1, px / width));
                sl.moved(sl.from + f * (sl.to - sl.from));
            }
            onPressed: m => upd(m.x)
            onPositionChanged: m => { if (pressed) upd(m.x); }
        }
    }

    Component {
        id: statsC
        Lane {
            Mod {
                baseSize: root.sizeCpuRam
                glyphSize: root.sizeCpuRam + 4
                glyph: "\uDB81\uDE1A"
                vglyph: "\uDB81\uDE1A"
                text: root.cpuUsage + "%"
                vtext: ""
                color: root.cpuUsage >= 85 ? Theme.danger : Theme.textDim
            }
            Mod {
                baseSize: root.sizeCpuRam
                glyphSize: root.sizeCpuRam + 4
                glyph: "\uDB80\uDF5B"
                vglyph: "\uDB80\uDF5B"
                text: root.memPercent + "%"
                vtext: ""
                color: root.memPercent >= 85 ? Theme.danger : Theme.textDim
            }
        }
    }

    Component {
        id: wsC
        Item {
            id: wsItem
            implicitWidth: root.vertical ? root.panelThick : wsLane.implicitWidth + 12
            implicitHeight: wsLane.implicitHeight + (root.vertical ? 12 : 0)

            Lane {
                id: wsLane
                anchors.centerIn: parent
                gap: 5

                Repeater {
                    model: Mango.tagsFor(wsItem.QsWindow.window && wsItem.QsWindow.window.screen
                        ? wsItem.QsWindow.window.screen.name : "")
                    delegate: Rectangle {
                        id: dot
                        required property var modelData
                        visible: modelData.occupied || modelData.focused
                        Layout.alignment: Qt.AlignCenter
                        readonly property int base: root.panelThick - 10
                        implicitWidth: root.vertical ? base : (modelData.focused ? base * 1.9 : base)
                        implicitHeight: root.vertical ? (modelData.focused ? base * 1.9 : base) : base
                        radius: base / 2
                        color: modelData.urgent ? Theme.danger
                             : modelData.focused ? Theme.accent
                             : dotMa.containsMouse ? Qt.alpha(Theme.accent, 0.18)
                             : Qt.alpha(Theme.text, 0.06)

                        Behavior on implicitWidth { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutQuad } }
                        Behavior on implicitHeight { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutQuad } }
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        Text {
                            anchors.centerIn: parent
                            text: dot.modelData.id
                            color: dot.modelData.focused || dot.modelData.urgent ? Theme._bgBase : Theme.textDim
                            font.family: root.barFont
                            font.pixelSize: s(11)
                            font.bold: true
                            function s(n) { return root.s(n) }
                        }

                        MouseArea {
                            id: dotMa
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: Mango.viewTag(dot.modelData.id, dot.modelData.monitor)
                        }
                    }
                }
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: e => e.angleDelta.y > 0 ? Mango.nextTag() : Mango.prevTag()
            }
        }
    }

    Component {
        id: titleC
        Mod {
            readonly property var client: Mango.activeClient
            baseSize: root.sizeTitle
            glyphSize: root.sizeTitle + 2
            color: Theme.textDim
            glyph: "\uDB82\uDCC6"
            text: {
                const t = client ? (client.title || "") : "";
                return t.length > 60 ? t.substring(0, 59) + "…" : t;
            }
        }
    }

    Component {
        id: mediaC
        Item {
            implicitWidth: root.vertical ? vMedia.implicitWidth : Math.min(Marquee.textW, Marquee.maxW) + 20
            implicitHeight: root.vertical ? vMedia.implicitHeight : 18

            Item {
                visible: !root.vertical
                anchors.fill: parent

                Item {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    clip: true

                    Row {
                        x: Marquee.animating ? Marquee.x : 0
                        spacing: Marquee.gap
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: root.iconYOffset

                        Text {
                            text: Marquee.text
                            color: Theme.text
                            font.family: root.barFont
                            font.pixelSize: root.sizeMarquee
                            renderType: Text.NativeRendering
                            width: Marquee.animating ? Marquee.textW
                                                     : Math.min(Marquee.textW, Marquee.maxW)
                            elide: Marquee.animating ? Text.ElideNone : Text.ElideRight
                        }

                        Text {
                            visible: Marquee.animating
                            text: Marquee.text
                            color: Theme.text
                            font.family: root.barFont
                            font.pixelSize: root.sizeMarquee
                            renderType: Text.NativeRendering
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onClicked: mouse => {
                        const p = Marquee.player;
                        if (!p) return;
                        if (mouse.button === Qt.LeftButton) p.togglePlaying();
                        else if (mouse.button === Qt.RightButton) p.next();
                        else p.previous();
                    }
                }
            }

            Mod {
                id: vMedia
                visible: root.vertical
                anchors.centerIn: parent
                text: "\u266B"
                baseSize: root.sizeMediaVertical
                onClicked: mouse => {
                    const p = Marquee.player;
                    if (!p) return;
                    if (mouse.button === Qt.LeftButton) p.togglePlaying();
                    else if (mouse.button === Qt.RightButton) p.next();
                    else p.previous();
                }
            }
        }
    }

    // System tray (StatusNotifierItem). Quickshell itself acts as the
    // StatusNotifierWatcher, so apps only need to share the session bus.
    // left: activate (or menu for menu-only items), right: menu, middle: secondary
    Component {
        id: trayC
        Item {
            implicitWidth: root.vertical ? root.panelThick : trayLane.implicitWidth + 12
            implicitHeight: root.vertical ? trayLane.implicitHeight + 12 : root.panelThick - 2

            Lane {
                id: trayLane
                anchors.centerIn: parent
                gap: 2

                Repeater {
                    model: SystemTray.items

                    delegate: Item {
                        id: ti
                        required property SystemTrayItem modelData
                        readonly property int box: root.panelThick - 8
                        Layout.alignment: Qt.AlignCenter
                        implicitWidth: box
                        implicitHeight: box

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: Qt.alpha(Theme.accent, tiMa.pressed ? 0.22 : 0.12)
                            opacity: tiMa.containsMouse ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                        }

                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: root.s(16)
                            source: ti.modelData.icon
                            asynchronous: true
                        }

                        function openMenu() {
                            if (!modelData.hasMenu) return;
                            const below = cfg.position !== "bottom";
                            const p = ti.mapToItem(null, 0, below ? ti.height + 6 : -6);
                            modelData.display(ti.QsWindow.window, p.x, p.y);
                        }

                        MouseArea {
                            id: tiMa
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            onClicked: mouse => {
                                const it = ti.modelData;
                                if (mouse.button === Qt.MiddleButton) it.secondaryActivate();
                                else if (mouse.button === Qt.RightButton || it.onlyMenu) ti.openMenu();
                                else it.activate();
                            }
                            onWheel: wheel => ti.modelData.scroll(wheel.angleDelta.y / 120, false)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: volumeC
        Mod {
            readonly property var sink: Pipewire.defaultAudioSink
            readonly property real vol: sink && sink.audio ? sink.audio.volume : 0
            readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
            baseSize: root.sizeVolText
            glyphSize: root.sizeVolIcon
            glyph: muted || vol <= 0 ? "\uDB81\uDF5F" : "\uDB81\uDD7E"
            //text: muted ? "Muted" : Math.round(vol * 100) + "%"
            vtext: ""
            color: muted ? Theme.danger : Theme.text
            onScrolled: delta => {
                if (!sink || !sink.audio) return;
                const v = sink.audio.volume + (delta / 120) * 0.02;
                sink.audio.volume = Math.max(0, Math.min(1.0, v));
            }
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton)
                    root.run("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle");
                else
                    root.run("qs ipc call settings sound");
            }
        }
    }

    Component {
        id: batteryC
        Mod {
            baseSize: root.sizeBatText
            glyphSize: root.sizeBatIcon
            glyph: (root.batCharging ? "\uf0e7 " : "") + root.batIcon
            vglyph: root.batIcon
            text: root.batPct + "%"
            vtext: root.batPct + ""
            color: root.batLow ? Theme.danger
                 : root.vertical && root.batCharging ? Theme.accent : Theme.text
        }
    }

    Component {
        id: netC
        Mod {
            baseSize: root.sizeNetIcon
            yOffset: root.iconYOffset
            text: root.netState === "wifi" ? "\uDB81\uDDA9"
                : root.netState === "ethernet" ? "\uDB80\uDE00" : "\uDB81\uDDAA"
            onClicked: root.run("qs ipc call settings network")
        }
    }

    Component {
        id: notifC
        Mod {
            baseSize: root.sizeNetIcon
            yOffset: root.iconYOffset
            text: "\uDB80\uDC9A"
            onClicked: root.run("qs ipc call notifications toggle")
        }
    }

    Component {
        id: wallC
        Mod {
            baseSize: root.sizeNetIcon
            yOffset: root.iconYOffset
            text: "\uDB80\uDEE9"
            onClicked: root.run("qs -n -p ~/.config/quickshell/hyprquickpaper")
        }
    }

    Component {
        id: powerC
        Mod {
            baseSize: root.sizePowerIcon
            yOffset: root.iconYOffset
            text: "\u23FB"
            onClicked: root.run("qs ipc call powermenu toggle")
        }
    }

    LazyLoader {
        active: root.settingsOpen

        PanelWindow {
            id: sw
            implicitWidth: 440
            implicitHeight: col.implicitHeight + 32
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "bar-settings"

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: Theme.bg
                border.width: 1
                border.color: root.borderColor

                ColumnLayout {
                    id: col
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: "Bar settings"
                            color: Theme.text
                            font.family: root.barFont
                            font.pixelSize: 14
                            font.bold: true
                        }
                        Mod {
                            text: "\u2715"
                            onClicked: root.settingsOpen = false
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Lbl { text: "Position"; Layout.fillWidth: true }
                        Seg {
                            options: ["top", "right", "bottom", "left"]
                            current: cfg.position
                            onPicked: v => cfg.position = v
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Lbl { text: "Style"; Layout.fillWidth: true }
                        Seg {
                            options: ["floating", "joined", "strip"]
                            current: cfg.style
                            onPicked: v => cfg.style = v
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Lbl { text: "Thickness  " + cfg.thickness; Layout.fillWidth: true }
                        Slide {
                            from: 16; to: 40; value: cfg.thickness
                            onMoved: v => cfg.thickness = Math.round(v)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Lbl { text: "Edge margin  " + cfg.margin; Layout.fillWidth: true }
                        Slide {
                            from: 0; to: 16; value: cfg.margin
                            onMoved: v => cfg.margin = Math.round(v)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Lbl { text: "Text scale  " + cfg.scale.toFixed(2); Layout.fillWidth: true }
                        Slide {
                            from: 0.8; to: 1.5; value: cfg.scale
                            onMoved: v => cfg.scale = Math.round(v * 20) / 20
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Lbl { text: "Background  " + Math.round(cfg.bgOpacity * 100) + "%"; Layout.fillWidth: true }
                        Slide {
                            from: 0; to: 1; value: cfg.bgOpacity
                            onMoved: v => cfg.bgOpacity = Math.round(v * 20) / 20
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Lbl { text: "Border"; Layout.fillWidth: true }
                        Toggle { checked: cfg.border; onToggled: v => cfg.border = v }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.alpha(Theme.text, 0.12)
                    }

                    Lbl {
                        text: "Modules"
                        font.bold: true
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: root.moduleDefs
                            delegate: RowLayout {
                                id: mrow
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 8

                                Item {
                                    Layout.preferredWidth: 34
                                    Layout.preferredHeight: 18
                                    Toggle {
                                        anchors.fill: parent
                                        visible: mrow.modelData.k !== ""
                                        checked: mrow.modelData.k !== "" && cfg[mrow.modelData.k]
                                        onToggled: v => cfg[mrow.modelData.k] = v
                                    }
                                }

                                Lbl { text: mrow.modelData.l; Layout.fillWidth: true }

                                Seg {
                                    options: ["start", "center", "end"]
                                    current: root.sectionOf(mrow.modelData.id)
                                    onPicked: v => root.moveTo(mrow.modelData.id, v)
                                }

                                Btn {
                                    label: root.vertical ? "\u25B2" : "\u25C0"
                                    onClicked: root.shiftBy(mrow.modelData.id, -1)
                                }

                                Btn {
                                    label: root.vertical ? "\u25BC" : "\u25B6"
                                    onClicked: root.shiftBy(mrow.modelData.id, 1)
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 32
                        radius: Theme.radius
                        color: resetMa.containsMouse ? Qt.alpha(Theme.accent, 0.2) : Qt.alpha(Theme.text, 0)

                        Text {
                            anchors.centerIn: parent
                            text: "Reset to defaults"
                            color: Theme.text
                            font.family: root.barFont
                            font.pixelSize: 11
                        }

                        MouseArea {
                            id: resetMa
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.resetSettings()
                        }
                    }
                }
            }
        }
    }

    Variants {
        model: root.barLive ? Quickshell.screens : []

        PanelWindow {
            id: bar
            required property var modelData
            screen: modelData

            anchors {
                top: cfg.position !== "bottom"
                bottom: cfg.position !== "top"
                left: cfg.position !== "right"
                right: cfg.position !== "left"
            }
            implicitWidth: root.vertical ? root.panelThick + root.effEdge : 0
            implicitHeight: root.vertical ? 0 : root.panelThick + root.effEdge
            color: "transparent"
            visible: root.barVisible

            Item {
                id: frame
                anchors {
                    fill: parent
                    topMargin: cfg.position === "top" ? root.effEdge : (root.vertical ? root.effGap : 0)
                    bottomMargin: cfg.position === "bottom" ? root.effEdge : (root.vertical ? root.effGap : 0)
                    leftMargin: cfg.position === "left" ? root.effEdge : (root.vertical ? 0 : root.effGap)
                    rightMargin: cfg.position === "right" ? root.effEdge : (root.vertical ? 0 : root.effGap)
                }

                Rectangle {
                    visible: root.joined
                    anchors.fill: parent
                    radius: root.barRadius
                    color: root.bgColor
                    border.width: cfg.border ? 1 : 0
                    border.color: root.borderColor
                }

                Panel {
                    lane: startLane
                    anchors.left: frame.left
                    anchors.top: frame.top

                    Lane {
                        id: startLane
                        anchors.centerIn: parent

                        Repeater {
                            model: root.startList
                            delegate: Slot {}
                        }
                    }
                }

                Panel {
                    id: clockPanel
                    lane: clockLane
                    anchors.horizontalCenter: root.vertical ? undefined : frame.horizontalCenter
                    anchors.verticalCenter: root.vertical ? frame.verticalCenter : undefined
                    anchors.top: root.vertical ? undefined : frame.top
                    anchors.left: root.vertical ? frame.left : undefined

                    property bool calOpen: false
                    property int monthOffset: 0

                    SystemClock { id: clk; precision: SystemClock.Minutes }

                    Component {
                        id: clockC
                        Mod {
                            id: clockMod
                            bold: true
                            baseSize: root.sizeClock
                            text: Qt.formatDateTime(clk.date, "HH:mm") + "  <font color=\"" + Theme.textDim + "\">"
                                  + Qt.formatDateTime(clk.date, "ddd dd MMM") + "</font>"
                            vtext: Qt.formatDateTime(clk.date, "HH") + "\n" + Qt.formatDateTime(clk.date, "mm")
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    root.settingsOpen = !root.settingsOpen;
                                    return;
                                }
                                if (mouse.button !== Qt.LeftButton) return;
                                clockPanel.monthOffset = 0;
                                clockPanel.calOpen = !clockPanel.calOpen;
                            }
                        }
                    }

                    Lane {
                        id: clockLane
                        anchors.centerIn: parent

                        Repeater {
                            model: root.centerList
                            delegate: Slot { clockComp: clockC }
                        }
                    }

                    LazyLoader {
                        active: clockPanel.calOpen

                        PopupWindow {
                            readonly property point p: bar.contentItem.mapFromItem(clockPanel, 0, 0)

                            anchor.window: bar
                            anchor.rect.x: root.vertical
                                ? (cfg.position === "left" ? p.x + clockPanel.width + 6
                                                           : p.x - implicitWidth - 6)
                                : p.x + (clockPanel.width - implicitWidth) / 2
                            anchor.rect.y: root.vertical
                                ? p.y + (clockPanel.height - implicitHeight) / 2
                                : (cfg.position === "top" ? p.y + clockPanel.height + 4
                                                          : p.y - implicitHeight - 4)
                            implicitWidth: calBox.gridW + 2 * calBox.pad
                            implicitHeight: calCol.implicitHeight + 2 * calBox.pad
                            color: "transparent"
                            visible: true

                            Rectangle {
                                id: calBox
                                anchors.fill: parent
                                radius: 4
                                color: Theme.bg
                                border.width: cfg.border ? 1 : 0
                                border.color: root.borderColor

                                readonly property int firstDay: 1
                                readonly property int cellW: 36
                                readonly property int cellH: 30
                                readonly property int pad: 16
                                readonly property int gridW: cellW * 7

                                readonly property date now: clk.date
                                readonly property date view: new Date(now.getFullYear(), now.getMonth() + clockPanel.monthOffset, 1)

                                readonly property var cells: {
                                    const first = (view.getDay() - firstDay + 7) % 7;
                                    const y = view.getFullYear(), m = view.getMonth();
                                    const ty = now.getFullYear(), tm = now.getMonth(), td = now.getDate();
                                    const out = [];
                                    for (let i = 0; i < 42; i++) {
                                        const d = new Date(y, m, i - first + 1);
                                        out.push({
                                            n: d.getDate(),
                                            inMonth: d.getMonth() === m,
                                            today: d.getFullYear() === ty && d.getMonth() === tm && d.getDate() === td
                                        });
                                    }
                                    return out;
                                }

                                WheelHandler {
                                    onWheel: e => clockPanel.monthOffset += (e.angleDelta.y > 0 ? -1 : 1)
                                }

                                Column {
                                    id: calCol
                                    anchors.centerIn: parent
                                    spacing: 12

                                    Column {
                                        spacing: 2
                                        Text {
                                            text: Qt.formatTime(calBox.now, "HH:mm")
                                            color: Theme.text
                                            font.family: root.barFont
                                            font.pixelSize: root.sizeCalTime
                                            font.bold: true
                                        }
                                        Text {
                                            text: Qt.formatDate(calBox.now, "dddd, d MMMM yyyy")
                                            color: Theme.textDim
                                            font.family: root.barFont
                                            font.pixelSize: root.sizeCalDate
                                        }
                                    }

                                    Rectangle {
                                        width: calBox.gridW
                                        height: 1
                                        color: Qt.alpha(Theme.text, 0.12)
                                    }

                                    Item {
                                        width: calBox.gridW
                                        height: 26

                                        Item {
                                            width: 28; height: parent.height
                                            anchors.left: parent.left
                                            Text {
                                                anchors.centerIn: parent
                                                text: "\uDB80\uDD41"
                                                color: prevMa.containsMouse ? Theme.accent : Theme.text
                                                font.family: root.barFont
                                                font.pixelSize: root.sizeCalArrow
                                            }
                                            MouseArea {
                                                id: prevMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: clockPanel.monthOffset -= 1
                                            }
                                        }

                                        Item {
                                            anchors.centerIn: parent
                                            width: monthTitle.implicitWidth + 16
                                            height: parent.height
                                            Text {
                                                id: monthTitle
                                                anchors.centerIn: parent
                                                text: Qt.formatDate(calBox.view, "MMMM yyyy")
                                                color: titleMa.containsMouse ? Theme.accent : Theme.text
                                                font.family: root.barFont
                                                font.pixelSize: root.sizeCalMonth
                                                font.bold: true
                                            }
                                            MouseArea {
                                                id: titleMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: clockPanel.monthOffset = 0
                                            }
                                        }

                                        Item {
                                            width: 28; height: parent.height
                                            anchors.right: parent.right
                                            Text {
                                                anchors.centerIn: parent
                                                text: "\uDB80\uDD42"
                                                color: nextMa.containsMouse ? Theme.accent : Theme.text
                                                font.family: root.barFont
                                                font.pixelSize: root.sizeCalArrow
                                            }
                                            MouseArea {
                                                id: nextMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: clockPanel.monthOffset += 1
                                            }
                                        }
                                    }

                                    Row {
                                        Repeater {
                                            model: 7
                                            delegate: Text {
                                                required property int index
                                                width: calBox.cellW
                                                horizontalAlignment: Text.AlignHCenter
                                                text: Qt.locale().dayName((index + calBox.firstDay) % 7, Locale.ShortFormat)
                                                color: Theme.textDim
                                                font.family: root.barFont
                                                font.pixelSize: root.sizeCalWeekday
                                            }
                                        }
                                    }

                                    Grid {
                                        columns: 7
                                        Repeater {
                                            model: calBox.cells
                                            delegate: Item {
                                                required property var modelData
                                                width: calBox.cellW
                                                height: calBox.cellH

                                                Rectangle {
                                                    visible: parent.modelData.today
                                                    anchors.fill: parent
                                                    anchors.margins: 2
                                                    radius: Theme.radius
                                                    color: Qt.alpha(Theme.accent, 0.45)
                                                    border.width: 1
                                                    border.color: Theme.accent
                                                }
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: parent.modelData.n
                                                    color: parent.modelData.inMonth ? Theme.text : Theme.textFaint
                                                    font.family: root.barFont
                                                    font.pixelSize: root.sizeCalDay
                                                    font.bold: parent.modelData.today
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Panel {
                    lane: endLane
                    anchors.right: root.vertical ? undefined : frame.right
                    anchors.bottom: root.vertical ? frame.bottom : undefined
                    anchors.top: root.vertical ? undefined : frame.top
                    anchors.left: root.vertical ? frame.left : undefined

                    Lane {
                        id: endLane
                        anchors.centerIn: parent

                        Repeater {
                            model: root.endList
                            delegate: Slot {}
                        }
                    }
                }
            }
        }
    }
}