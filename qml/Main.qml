import QtQuick
import QtQuick.Controls
import Mosaic

ApplicationWindow {
    id: window
    width: 1280
    height: 720
    minimumWidth: 640
    minimumHeight: 360
    visible: true
    title: "Mosaic"
    color: "#0e0e10"

    NdiFinder { id: finder }
    Storage { id: storage }
    PowerGuard { keepAwake: window.neverSleep }

    RemoteControl {
        id: remote
        enabled: window.remoteEnabled
        port: window.remotePort
        onCommandReceived: (command, argument) => {
            let ok = true
            switch (command) {
            case "profiles":
            case "profiles?":
                remote.reply("PROFILES "
                    + JSON.stringify(window.profiles.map(p => p.name)))
                return
            case "status":
            case "status?":
                remote.reply("STATUS " + JSON.stringify({
                    profile: window.currentProfile,
                    mode: window.modeName(),
                    tiles: tileModel.count
                }))
                return
            case "profile": {
                const p = window.profiles.find(
                    x => x.name.toLowerCase() === argument.toLowerCase())
                if (p)
                    window.applyProfile(p.name)
                else
                    ok = false
                break
            }
            case "profileindex": {
                const i = parseInt(argument) - 1
                if (!isNaN(i) && i >= 0 && i < window.profiles.length)
                    window.applyProfile(window.profiles[i].name)
                else
                    ok = false
                break
            }
            case "layout":
                switch (argument.toLowerCase()) {
                case "2x2": window.applyGrid(2); break
                case "3x3": window.applyGrid(3); break
                case "4x4": window.applyGrid(4); break
                case "1+side": window.applyOnePlusSide(); break
                case "2+8": window.applyTwoPlusEight(); break
                default: ok = false
                }
                break
            case "mode":
                switch (argument.toLowerCase()) {
                case "windowed": window.displayMode = 0; break
                case "fullscreen": window.displayMode = 1; break
                case "windowless": window.displayMode = 2; break
                default: ok = false
                }
                break
            case "ping":
                break
            default:
                ok = false
            }
            remote.reply(ok ? "OK" : "ERR " + command)
        }
    }

    // ------------------------------------------------------ app state
    // Which sources are on the canvas. Tile positions live on the tile
    // items themselves while the app runs (saved layouts come later).
    ListModel { id: tileModel }
    property int topZ: 0
    property bool snapOn: false
    property bool wheelRotateOn: true
    // Gutter used by the layout templates. 0 = seamless, edge to edge.
    property int tileGap: 8
    // Master switch for all tile name labels.
    property bool showTileNames: true
    // Off (default): sidebar clicks toggle a source on/off the canvas.
    // On: every click adds another tile of the source, so one shot can be
    // cropped to several regions.
    property bool allowDuplicates: false

    // Any mouse movement wakes the selected tile's accent so the user can
    // always find the active tile by nudging the mouse. Wired to hover
    // handlers on ANCESTOR items (canvas, sidebar) — a full-window overlay
    // handler would steal hover from tile headers. Video repaints
    // re-deliver hover with the mouse still, so only genuine position
    // changes count, or the highlight would never fade.
    property point lastWakePos: Qt.point(-1, -1)
    function mouseActivity(pos) {
        if (pos.x === lastWakePos.x && pos.y === lastWakePos.y)
            return
        lastWakePos = Qt.point(pos.x, pos.y)
        if (canvas.selectedTile)
            canvas.selectedTile.wakeHighlight()
    }
    // Keep the display awake (show-day mode).
    property bool neverSleep: false
    // TCP remote control for Stream Deck / Bitfocus Companion.
    property bool remoteEnabled: false
    property int remotePort: 9955

    // Display modes: 0 = windowed, 1 = fullscreen, 2 = windowless
    property int displayMode: 0
    function modeName() {
        return ["windowed", "fullscreen", "windowless"][displayMode]
    }

    // State push for remote controllers: whenever the active profile, the
    // profile list, or the display mode changes — regardless of what
    // caused it — every connected client hears about it, so Companion
    // buttons can highlight the active profile.
    onCurrentProfileChanged: remote.broadcast("EVENT PROFILE " + currentProfile)
    onProfilesChanged: remote.broadcast(
        "EVENT PROFILES " + JSON.stringify(profiles.map(p => p.name)))
    property bool alwaysOnTop: false
    property int fsScreenIndex: 0
    property bool sidebarCollapsed: false
    property bool settingsOpen: false

    onDisplayModeChanged: {
        remote.broadcast("EVENT MODE " + modeName())
        // Sidebar gets out of the way in fullscreen/windowless (Max's spec);
        // the left-edge hover strip brings it back on demand.
        sidebarCollapsed = displayMode !== 0
        settingsOpen = false
        // Deferred: changing window flags rebuilds the native window, and
        // doing that inside a click gesture made Windows re-deliver the
        // click into the rebuilt window — where it landed on the source
        // list under the (now closed) settings panel and toggled a source
        // off. Wait until the click is fully finished before rebuilding.
        Qt.callLater(applyDisplayMode)
    }
    onAlwaysOnTopChanged: Qt.callLater(applyDisplayMode)
    onFsScreenIndexChanged: {
        if (displayMode === 1)
            Qt.callLater(applyDisplayMode)
    }

    // Windows recreates the native window when its style flags change and
    // can reset the size in the process — so remember the last windowed
    // geometry and put it back after every mode switch.
    property rect savedGeom: Qt.rect(0, 0, 0, 0)

    function applyDisplayMode() {
        const onTop = alwaysOnTop ? Qt.WindowStaysOnTopHint : 0
        if (window.visibility !== Window.FullScreen && window.width > 200)
            savedGeom = Qt.rect(window.x, window.y, window.width, window.height)

        if (displayMode === 1) {
            // Moving between monitors while already fullscreen needs a dip
            // through windowed state or Windows keeps the old monitor.
            if (window.visibility === Window.FullScreen)
                window.visibility = Window.Windowed
            window.flags = Qt.Window | onTop
            const screens = Qt.application.screens
            window.screen = screens[Math.min(fsScreenIndex, screens.length - 1)]
            window.visibility = Window.FullScreen
        } else {
            window.visibility = Window.Windowed
            window.flags = displayMode === 2
                ? Qt.Window | Qt.FramelessWindowHint | onTop
                : Qt.Window | onTop
            if (savedGeom.width > 200) {
                window.x = savedGeom.x
                window.y = savedGeom.y
                window.width = savedGeom.width
                window.height = savedGeom.height
            }
            window.visible = true
        }
    }

    property bool aboutOpen: false

    // Esc: first close dialogs / cancel crops; otherwise return to windowed.
    function escapePressed() {
        let cancelled = false
        if (aboutOpen) {
            aboutOpen = false
            cancelled = true
        }
        for (let i = 0; i < tileRepeater.count; i++) {
            const t = tileRepeater.itemAt(i)
            if (!t)
                continue
            if (t.cropMode) {
                t.cropMode = false
                cancelled = true
            }
            if (t.optsOpen || t.sizeOpen) {
                t.closePopups()
                cancelled = true
            }
        }
        if (settingsOpen) {
            settingsOpen = false
            cancelled = true
        }
        if (!cancelled && displayMode !== 0)
            displayMode = 0
    }

    // Focused key catcher — Shortcut proved unreliable with nothing else
    // holding keyboard focus, so this item owns focus and handles all
    // hotkeys: Esc, F11 fullscreen, Ctrl+1..9 profile switching.
    Item {
        id: keyCatcher
        focus: true
        Keys.onEscapePressed: window.escapePressed()
        Keys.onPressed: event => {
            if (event.key === Qt.Key_F11) {
                window.displayMode = window.displayMode === 1 ? 0 : 1
                event.accepted = true
                return
            }
            if ((event.modifiers & Qt.ControlModifier)
                    && event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                const idx = event.key - Qt.Key_1
                if (idx < window.profiles.length)
                    window.applyProfile(window.profiles[idx].name)
                event.accepted = true
            }
        }
    }

    function sourceCount(name) {
        let count = 0
        for (let i = 0; i < tileModel.count; i++)
            if (tileModel.get(i).name === name)
                count++
        return count
    }

    // Duplicates ON: every click adds another instance. Duplicates OFF:
    // classic toggle — add if absent, otherwise remove every instance.
    function sourceClicked(name) {
        if (allowDuplicates) {
            tileModel.append({ name: name })
            return
        }
        const had = sourceCount(name) > 0
        for (let i = tileModel.count - 1; i >= 0; i--) {
            if (tileModel.get(i).name === name)
                tileModel.remove(i)
        }
        if (!had)
            tileModel.append({ name: name })
    }

    // ------------------------------------------------------- profiles
    // A profile bundles sources + tile layout + per-tile views. Applying
    // one is diff-based: tiles whose source is in both profiles keep
    // their receiver running, so switching feels instant during a show.
    property var profiles: []
    property string currentProfile: ""

    // Geometry is stored normalized (0..1 of canvas size) so a profile
    // saved windowed applies cleanly in fullscreen and vice versa.
    function captureTiles() {
        const arr = []
        for (let i = 0; i < tileRepeater.count; i++) {
            const it = tileRepeater.itemAt(i)
            if (!it)
                continue
            arr.push({
                source: it.sourceName,
                x: it.x / canvas.width,
                y: it.y / canvas.height,
                w: it.width / canvas.width,
                h: it.height / canvas.height,
                z: it.z,
                view: it.viewState(),
                showName: it.showName,
                showMeter: it.showMeter,
                lowBw: it.lowBw,
                lowLat: it.lowLat,
                customName: it.customName
            })
        }
        return arr
    }

    function applyTiles(tiles) {
        if (!tiles)
            return
        // Group target entries by source — duplicates are allowed, so the
        // diff works on instance COUNTS per source. Tiles kept across the
        // switch never reconnect; only surplus/missing instances change.
        const target = {}
        for (const t of tiles) {
            if (!target[t.source])
                target[t.source] = []
            target[t.source].push(t)
        }
        const have = {}
        for (let i = 0; i < tileModel.count; i++) {
            const nm = tileModel.get(i).name
            have[nm] = (have[nm] || 0) + 1
        }
        for (let i = tileModel.count - 1; i >= 0; i--) {
            const nm = tileModel.get(i).name
            const need = target[nm] ? target[nm].length : 0
            if (have[nm] > need) {
                tileModel.remove(i)
                have[nm]--
            }
        }
        for (const s in target) {
            for (let k = have[s] || 0; k < target[s].length; k++)
                tileModel.append({ name: s })
        }
        // Pair surviving/new tiles with target entries per source, in
        // order, and apply geometry, view and options.
        const buckets = {}
        for (let i = 0; i < tileRepeater.count; i++) {
            const it = tileRepeater.itemAt(i)
            if (!it)
                continue
            if (!buckets[it.sourceName])
                buckets[it.sourceName] = []
            buckets[it.sourceName].push(it)
        }
        let maxZ = 0
        for (const s in target) {
            const items = buckets[s] || []
            for (let k = 0; k < target[s].length; k++) {
                const t = target[s][k]
                const it = items[k]
                if (!it)
                    continue
                it.x = t.x * canvas.width
                it.y = t.y * canvas.height
                it.width = Math.max(it.minW, t.w * canvas.width)
                it.height = Math.max(it.minH, t.h * canvas.height)
                it.z = t.z || 0
                maxZ = Math.max(maxZ, it.z)
                if (t.view)
                    it.setViewState(t.view)
                it.showName = t.showName !== false
                it.showMeter = t.showMeter === true
                it.lowBw = t.lowBw === true
                it.lowLat = t.lowLat === true
                it.customName = t.customName || ""
            }
        }
        window.topZ = maxZ + 1
        canvas.selectedTile = null
    }

    function saveProfilesFile() {
        storage.save("profiles.json",
                     JSON.stringify({ version: 1, profiles: profiles }))
    }

    function saveProfile(name) {
        name = name.trim()
        if (name === "")
            return
        const p = { name: name, tiles: captureTiles() }
        const idx = profiles.findIndex(x => x.name === name)
        if (idx >= 0)
            profiles[idx] = p
        else
            profiles.push(p)
        profiles = profiles.slice() // new array so QML sees the change
        currentProfile = name
        saveProfilesFile()
    }

    // The active profile follows the user: any change to the canvas is
    // folded back into it automatically (no manual Save needed). Called
    // by the autosave timer, on close, and right before switching away.
    function syncActiveProfile() {
        if (currentProfile === "")
            return
        const idx = profiles.findIndex(x => x.name === currentProfile)
        if (idx < 0)
            return
        const tiles = captureTiles()
        if (JSON.stringify(profiles[idx].tiles) === JSON.stringify(tiles))
            return
        profiles[idx].tiles = tiles
        profiles = profiles.slice()
        saveProfilesFile()
    }

    function applyProfile(name) {
        const p = profiles.find(x => x.name === name)
        if (!p)
            return
        syncActiveProfile() // don't lose changes made since the last tick
        applyTiles(p.tiles)
        currentProfile = name
    }

    function deleteProfile(name) {
        profiles = profiles.filter(x => x.name !== name)
        if (currentProfile === name)
            currentProfile = ""
        saveProfilesFile()
    }

    // ------------------------------------------------- session restore
    function saveSession() {
        syncActiveProfile()
        storage.save("session.json", JSON.stringify({
            version: 1,
            snapOn: snapOn,
            wheelRotateOn: wheelRotateOn,
            tileGap: tileGap,
            showTileNames: showTileNames,
            allowDuplicates: allowDuplicates,
            neverSleep: neverSleep,
            remoteEnabled: remoteEnabled,
            remotePort: remotePort,
            currentProfile: currentProfile,
            tiles: captureTiles()
        }))
    }

    function closeTilePopups() {
        for (let i = 0; i < tileRepeater.count; i++) {
            const t = tileRepeater.itemAt(i)
            if (t)
                t.closePopups()
        }
    }

    Component.onCompleted: {
        try {
            const p = JSON.parse(storage.load("profiles.json") || "{}")
            if (p.profiles)
                profiles = p.profiles
        } catch (e) {
            console.warn("Could not read profiles.json:", e)
        }
        try {
            const s = JSON.parse(storage.load("session.json") || "null")
            if (s) {
                snapOn = s.snapOn === true
                wheelRotateOn = s.wheelRotateOn !== false
                if (s.tileGap !== undefined)
                    tileGap = s.tileGap
                showTileNames = s.showTileNames !== false
                allowDuplicates = s.allowDuplicates === true
                neverSleep = s.neverSleep === true
                remoteEnabled = s.remoteEnabled === true
                if (s.remotePort !== undefined)
                    remotePort = s.remotePort
                currentProfile = s.currentProfile || ""
                applyTiles(s.tiles || [])
            }
        } catch (e) {
            console.warn("Could not read session.json:", e)
        }
    }

    onClosing: saveSession()

    // Autosave so a crash or power loss never costs the arrangement.
    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: window.saveSession()
    }


    // Preset layouts arrange the tiles that are already on the canvas.
    function applyGrid(cols) {
        const n = tileRepeater.count
        if (n === 0)
            return
        const rows = Math.ceil(n / cols)
        const gut = tileGap
        const cw = (canvas.width - gut * (cols + 1)) / cols
        const ch = (canvas.height - gut * (rows + 1)) / rows
        for (let i = 0; i < n; i++) {
            const it = tileRepeater.itemAt(i)
            const c = i % cols
            const r = Math.floor(i / cols)
            it.x = gut + c * (cw + gut)
            it.y = gut + r * (ch + gut)
            it.width = cw
            it.height = ch
        }
    }

    function applyOnePlusSide() {
        const n = tileRepeater.count
        if (n === 0)
            return
        if (n === 1) {
            applyGrid(1)
            return
        }
        const gut = tileGap
        const bigW = (canvas.width - gut * 3) * 2 / 3
        const big = tileRepeater.itemAt(0)
        big.x = gut
        big.y = gut
        big.width = bigW
        big.height = canvas.height - 2 * gut
        const colX = gut * 2 + bigW
        const colW = canvas.width - colX - gut
        const side = n - 1
        const ch = (canvas.height - gut * (side + 1)) / side
        for (let i = 1; i < n; i++) {
            const it = tileRepeater.itemAt(i)
            it.x = colX
            it.y = gut + (i - 1) * (ch + gut)
            it.width = colW
            it.height = ch
        }
    }

    // Classic production multiview: two large monitors on top (preview /
    // program), the rest in rows of four below.
    function applyTwoPlusEight() {
        const n = tileRepeater.count
        if (n === 0)
            return
        const gut = tileGap
        const topN = Math.min(2, n)
        const rest = n - topN
        const topH = rest > 0 ? (canvas.height - 2 * gut) * 0.55
                              : canvas.height - 2 * gut
        const tw = (canvas.width - gut * (topN + 1)) / topN
        for (let i = 0; i < topN; i++) {
            const it = tileRepeater.itemAt(i)
            it.x = gut + i * (tw + gut)
            it.y = gut
            it.width = tw
            it.height = topH
        }
        if (rest > 0) {
            const cols = 4
            const rows = Math.ceil(rest / cols)
            const bottomY = gut + topH + gut
            const bh = (canvas.height - bottomY - gut * rows) / rows
            const bw = (canvas.width - gut * (cols + 1)) / cols
            for (let i = 0; i < rest; i++) {
                const it = tileRepeater.itemAt(topN + i)
                const c = i % cols
                const r = Math.floor(i / cols)
                it.x = gut + c * (bw + gut)
                it.y = bottomY + r * (bh + gut)
                it.width = bw
                it.height = bh
            }
        }
    }

    // Small button used by the sidebar, toolbar and settings panel.
    component ToolBtn: Rectangle {
        property string label
        property bool active: false
        property int fontSize: 12
        signal activated()
        width: Math.max(btnText.width + 18, height)
        height: 26
        radius: 3
        color: active ? "#22303e"
             : btnHover.hovered ? "#2a2a30" : "transparent"
        border.width: active ? 1 : 0
        border.color: "#3d7eff"

        Text {
            id: btnText
            anchors.centerIn: parent
            text: parent.label
            color: "#d8d8dc"
            font.pixelSize: parent.fontSize
        }
        HoverHandler { id: btnHover }
        TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: parent.activated() }
    }

    Row {
        anchors.fill: parent

        // ------------------------------------------------ source sidebar
        Rectangle {
            id: sidebar
            width: window.sidebarCollapsed ? 0 : 280
            height: parent.height
            color: "#141417"
            clip: true
            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

            HoverHandler {
                onPointChanged: window.mouseActivity(point.position)
            }

            Column {
                width: 256
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.margins: 12
                spacing: 8

                // App title bar: logo + name, settings gear, collapse.
                Item {
                    width: parent.width
                    height: 34

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            source: "../resources/mosaic-logo.png"
                            width: 24
                            height: 24
                            smooth: true
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Mosaic"
                            color: "#e8e8ea"
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                        }
                    }
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        spacing: 4

                        ToolBtn {
                            label: "⚙"
                            fontSize: 17
                            height: 30
                            active: window.settingsOpen
                            onActivated: window.settingsOpen = !window.settingsOpen
                        }
                        ToolBtn {
                            label: "«"
                            fontSize: 17
                            height: 30
                            onActivated: window.sidebarCollapsed = true
                        }
                    }
                }

                Text {
                    text: "NDI® SOURCES"
                    color: "#5a5a60"
                    font.pixelSize: 10
                }
                Text {
                    text: finder.sources.length === 0
                          ? "Searching the network…"
                          : finder.sources.length + (window.allowDuplicates
                              ? " found — click to add (again for another copy)"
                              : " found — click to add/remove")
                    color: "#8a8a90"
                    font.pixelSize: 11
                }

                ListView {
                    id: sourceList
                    width: parent.width
                    height: parent.height - y - layoutsSec.height - profilesSec.height - footer.height - 48
                    clip: true
                    spacing: 4
                    model: finder.sources

                    delegate: Rectangle {
                        required property string modelData
                        // Depends on tileModel.count so it re-evaluates on
                        // every add/remove. Several tiles may show the
                        // same source (different crops of one shot).
                        property int instances: {
                            tileModel.count
                            return window.sourceCount(modelData)
                        }
                        width: sourceList.width
                        height: 34
                        radius: 3
                        color: instances > 0 ? "#22303e"
                             : hover.hovered ? "#1c1c20" : "transparent"
                        border.width: 1
                        border.color: instances > 0 ? "#3d7eff" : "#26262b"

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: mark.left
                            anchors.margins: 10
                            text: parent.modelData
                            color: "#d8d8dc"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                        Text {
                            id: mark
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            text: parent.instances === 0 ? ""
                                : parent.instances === 1 ? "●"
                                : "● " + parent.instances
                            color: "#3d7eff"
                            font.pixelSize: 10
                        }

                        HoverHandler { id: hover }
                        TapHandler {
                            // Exclusive grab: without this, taps aimed at
                            // overlays above (settings panel) also fire here.
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: window.sourceClicked(parent.modelData)
                        }
                    }
                }

                // --------------------------------------------- layouts
                Column {
                    id: layoutsSec
                    width: parent.width
                    spacing: 4

                    Text {
                        text: "LAYOUTS"
                        color: "#5a5a60"
                        font.pixelSize: 10
                    }

                    Flow {
                        width: parent.width
                        spacing: 4

                        ToolBtn { label: "2×2"; height: 24; onActivated: window.applyGrid(2) }
                        ToolBtn { label: "3×3"; height: 24; onActivated: window.applyGrid(3) }
                        ToolBtn { label: "4×4"; height: 24; onActivated: window.applyGrid(4) }
                        ToolBtn { label: "1+side"; height: 24; onActivated: window.applyOnePlusSide() }
                        ToolBtn { label: "2+8"; height: 24; onActivated: window.applyTwoPlusEight() }
                        ToolBtn {
                            label: "Snap"
                            height: 24
                            active: window.snapOn
                            onActivated: window.snapOn = !window.snapOn
                        }
                    }
                }

                // -------------------------------------------- profiles
                Column {
                    id: profilesSec
                    width: parent.width
                    spacing: 4

                    Text {
                        text: "PROFILES"
                        color: "#5a5a60"
                        font.pixelSize: 10
                    }

                    Repeater {
                        model: window.profiles

                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool isActive:
                                window.currentProfile === modelData.name
                            width: profilesSec.width
                            height: 30
                            radius: 3
                            color: isActive ? "#22303e"
                                 : profHover.hovered ? "#1c1c20" : "transparent"
                            border.width: 1
                            border.color: isActive ? "#3d7eff" : "#26262b"

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.right: delBtn.left
                                anchors.margins: 10
                                text: parent.modelData.name
                                color: "#d8d8dc"
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                            Text {
                                id: delBtn
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                text: "✕"
                                color: delHover.hovered ? "#ff6060" : "#5a5a60"
                                font.pixelSize: 13
                                visible: profHover.hovered

                                HoverHandler { id: delHover }
                                TapHandler {
                                    gesturePolicy: TapHandler.ReleaseWithinBounds
                                    onTapped: window.deleteProfile(
                                        delBtn.parent.modelData.name)
                                }
                            }

                            HoverHandler { id: profHover }
                            TapHandler {
                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                onTapped: window.applyProfile(parent.modelData.name)
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 4

                        Rectangle {
                            width: parent.width - saveBtn.width - 4
                            height: 28
                            radius: 3
                            color: "#101013"
                            border.width: 1
                            border.color: profName.activeFocus ? "#3d7eff" : "#26262b"

                            TextInput {
                                id: profName
                                anchors.fill: parent
                                anchors.margins: 6
                                color: "#d8d8dc"
                                font.pixelSize: 12
                                selectByMouse: true
                                clip: true
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 6
                                text: window.currentProfile !== ""
                                      ? window.currentProfile : "profile name"
                                color: "#5a5a60"
                                font.pixelSize: 12
                                visible: profName.text === "" && !profName.activeFocus
                            }
                        }
                        ToolBtn {
                            id: saveBtn
                            label: "Save"
                            height: 28
                            onActivated: {
                                const name = profName.text.trim() !== ""
                                    ? profName.text : window.currentProfile
                                if (name.trim() === "")
                                    return
                                window.saveProfile(name)
                                profName.text = ""
                                keyCatcher.forceActiveFocus()
                            }
                        }
                    }
                }

                Column {
                    id: footer
                    width: parent.width
                    spacing: 4

                    Text {
                        text: "Learn more at <a href='https://ndi.video/'>ndi.video</a>"
                        color: "#8a8a90"
                        linkColor: "#3d7eff"
                        font.pixelSize: 11
                        textFormat: Text.RichText
                        onLinkActivated: link => Qt.openUrlExternally(link)
                    }
                    Text {
                        width: parent.width
                        text: "NDI® is a registered trademark of Vizrt NDI AB."
                        color: "#5a5a60"
                        font.pixelSize: 10
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        // -------------------------------------------------- tile canvas
        Rectangle {
            id: canvas
            width: parent.width - sidebar.width
            height: parent.height
            color: "#0e0e10"
            clip: true

            property var selectedTile: null

            // The canvas changes size when the window mode changes or the
            // sidebar collapses. Scale the tile layout proportionally so
            // the arrangement survives every switch — otherwise tiles kept
            // absolute positions and could end up clipped out of view.
            property size prevSize: Qt.size(0, 0)
            onWidthChanged: rescaleTiles()
            onHeightChanged: rescaleTiles()

            function rescaleTiles() {
                const pw = prevSize.width
                const ph = prevSize.height
                if (pw > 0 && ph > 0 && width > 0 && height > 0
                        && (pw !== width || ph !== height)) {
                    const sx = width / pw
                    const sy = height / ph
                    for (let i = 0; i < tileRepeater.count; i++) {
                        const it = tileRepeater.itemAt(i)
                        if (!it)
                            continue
                        it.x *= sx
                        it.y *= sy
                        it.width = Math.max(it.minW, it.width * sx)
                        it.height = Math.max(it.minH, it.height * sy)
                    }
                }
                prevSize = Qt.size(width, height)
            }

            // Track which tile is topmost under the cursor: only that tile
            // shows its hover UI, so with overlapping tiles the buttons you
            // see are always the buttons you hit.
            property var hoverTile: null

            function updateHoverTile(pos) {
                // childAt ignores z-order, so find the topmost tile
                // manually: highest z wins, later creation breaks ties
                // (matching the scene graph's paint order).
                let best = null
                for (let i = 0; i < tileRepeater.count; i++) {
                    const it = tileRepeater.itemAt(i)
                    if (!it)
                        continue
                    if (pos.x >= it.x && pos.x <= it.x + it.width
                            && pos.y >= it.y && pos.y <= it.y + it.height) {
                        if (!best || it.z >= best.z)
                            best = it
                    }
                }
                hoverTile = best
            }

            HoverHandler {
                id: canvasHover
                onPointChanged: {
                    window.mouseActivity(point.position)
                    canvas.updateHoverTile(point.position)
                }
                onHoveredChanged: {
                    if (!hovered)
                        canvas.hoverTile = null
                }
            }

            // Click empty canvas to deselect and close any open tile menus.
            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: {
                    canvas.selectedTile = null
                    window.closeTilePopups()
                    // Reclaim keyboard focus (e.g. after typing in a size box)
                    // so Esc keeps working.
                    keyCatcher.forceActiveFocus()
                }
            }

            // In windowless mode, dragging empty canvas moves the window.
            DragHandler {
                enabled: window.displayMode === 2
                target: null
                onActiveChanged: if (active) window.startSystemMove()
            }

            Text {
                anchors.centerIn: parent
                visible: tileModel.count === 0
                text: finder.sources.length === 0
                      ? "Waiting for NDI® sources to appear on the network…"
                      : "Click sources on the left to add them to the canvas"
                color: "#5a5a60"
                font.pixelSize: 16
            }

            // Snap grid: appears only while a tile is being dragged or
            // resized with snapping engaged (Max's spec).
            property int snapDragCount: 0

            Canvas {
                id: snapGrid
                anchors.fill: parent
                visible: canvas.snapDragCount > 0
                opacity: 0.55
                onVisibleChanged: if (visible) requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.strokeStyle = "#2a2a30"
                    ctx.lineWidth = 1
                    ctx.beginPath()
                    for (let x = 16.5; x < width; x += 16) {
                        ctx.moveTo(x, 0)
                        ctx.lineTo(x, height)
                    }
                    for (let y = 16.5; y < height; y += 16) {
                        ctx.moveTo(0, y)
                        ctx.lineTo(width, y)
                    }
                    ctx.stroke()
                }
            }

            // Tiles live in their own layer so their z-order competition
            // stays among themselves — toolbar and status strip are
            // siblings drawn above this layer and can never be covered.
            Item {
                id: tileLayer
                anchors.fill: parent

                Repeater {
                    id: tileRepeater
                    model: tileModel

                    delegate: Tile {
                        required property int index
                        required property string name
                        sourceName: name
                        snapEnabled: window.snapOn
                        wheelRotate: window.wheelRotateOn
                        globalShowName: window.showTileNames
                        gridSize: 16
                        selected: canvas.selectedTile === this
                        hoverTop: canvas.hoverTile === this
                        onSnapDragActiveChanged:
                            canvas.snapDragCount += snapDragActive ? 1 : -1
                        Component.onCompleted: {
                            x = 24 + (index % 5) * 40
                            y = 24 + (index % 5) * 40
                            z = ++window.topZ
                            canvas.selectedTile = this
                        }
                        onSelectRequested: {
                            canvas.selectedTile = this
                            z = ++window.topZ
                        }
                        onCloseRequested: {
                            if (canvas.selectedTile === this)
                                canvas.selectedTile = null
                            tileModel.remove(index)
                        }
                        Component.onDestruction: {
                            if (snapDragActive)
                                canvas.snapDragCount--
                            if (canvas.hoverTile === this)
                                canvas.hoverTile = null
                        }
                    }
                }
            }

            // Auto-hiding status bar: tiles get the whole canvas; move the
            // mouse to the bottom edge to peek at selected-tile info.
            Item {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 44
                HoverHandler { id: bottomZone }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 28
                color: "#141417ee"
                visible: opacity > 0 && tileModel.count > 0
                opacity: bottomZone.hovered ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150 } }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.right: stripStatus.left
                    anchors.rightMargin: 12
                    text: canvas.selectedTile
                          ? canvas.selectedTile.displayName
                          : tileModel.count + " tile" + (tileModel.count === 1 ? "" : "s")
                    color: "#d8d8dc"
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
                Text {
                    id: stripStatus
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    text: canvas.selectedTile ? canvas.selectedTile.status : ""
                    color: "#8a8a90"
                    font.pixelSize: 11
                }
            }
        }
    }

    // Frameless windows have no OS resize borders — provide our own edges
    // and corners in windowless mode via startSystemResize.
    component ResizeEdge: MouseArea {
        property int edges
        z: 200
        onPressed: window.startSystemResize(edges)
    }

    Item {
        anchors.fill: parent
        visible: window.displayMode === 2
        z: 200

        ResizeEdge { x: 0; y: 10; width: 7; height: parent.height - 20; edges: Qt.LeftEdge; cursorShape: Qt.SizeHorCursor }
        ResizeEdge { x: parent.width - 7; y: 10; width: 7; height: parent.height - 20; edges: Qt.RightEdge; cursorShape: Qt.SizeHorCursor }
        ResizeEdge { x: 10; y: 0; width: parent.width - 20; height: 7; edges: Qt.TopEdge; cursorShape: Qt.SizeVerCursor }
        ResizeEdge { x: 10; y: parent.height - 7; width: parent.width - 20; height: 7; edges: Qt.BottomEdge; cursorShape: Qt.SizeVerCursor }
        ResizeEdge { x: 0; y: 0; width: 12; height: 12; edges: Qt.LeftEdge | Qt.TopEdge; cursorShape: Qt.SizeFDiagCursor }
        ResizeEdge { x: parent.width - 12; y: 0; width: 12; height: 12; edges: Qt.RightEdge | Qt.TopEdge; cursorShape: Qt.SizeBDiagCursor }
        ResizeEdge { x: 0; y: parent.height - 12; width: 12; height: 12; edges: Qt.LeftEdge | Qt.BottomEdge; cursorShape: Qt.SizeBDiagCursor }
        ResizeEdge { x: parent.width - 12; y: parent.height - 12; width: 12; height: 12; edges: Qt.RightEdge | Qt.BottomEdge; cursorShape: Qt.SizeFDiagCursor }
    }

    // Left-edge hover strip: brings the collapsed sidebar back.
    MouseArea {
        width: 24
        height: parent.height
        hoverEnabled: true
        visible: window.sidebarCollapsed
        onClicked: window.sidebarCollapsed = false

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            height: 88
            radius: 4
            color: "#1a1a1ee6"
            border.width: 1
            border.color: "#2a2a2e"
            visible: parent.containsMouse

            Text {
                anchors.centerIn: parent
                text: "»"
                color: "#d8d8dc"
                font.pixelSize: 20
            }
        }
    }

    // ---------------------------------------------------- settings panel
    MouseArea {
        anchors.fill: parent
        visible: window.settingsOpen
        onClicked: window.settingsOpen = false
    }

    Rectangle {
        visible: window.settingsOpen
        x: 12
        y: 46
        z: 100
        width: 264
        height: settingsCol.height + 28
        radius: 6
        color: "#1a1a1e"
        border.width: 1
        border.color: "#2a2a2e"

        // Swallow every press on the panel body so nothing can leak
        // through to the source list sitting underneath it.
        MouseArea { anchors.fill: parent }

        component CheckRow: Item {
            property string label
            property bool checked: false
            signal toggled()
            width: parent.width
            height: 24

            Rectangle {
                id: box
                anchors.verticalCenter: parent.verticalCenter
                width: 15
                height: 15
                radius: 2
                color: "transparent"
                border.width: 1
                border.color: parent.checked ? "#3d7eff" : "#4a4a50"

                Rectangle {
                    anchors.centerIn: parent
                    width: 8
                    height: 8
                    radius: 1
                    color: "#3d7eff"
                    visible: parent.parent.checked
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: box.right
                anchors.leftMargin: 8
                text: parent.label
                color: "#d8d8dc"
                font.pixelSize: 12
            }
            TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: parent.toggled() }
        }

        Column {
            id: settingsCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 14
            spacing: 10

            Text {
                text: "Settings"
                color: "#e8e8ea"
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            Text {
                text: "DISPLAY MODE"
                color: "#5a5a60"
                font.pixelSize: 10
            }
            Row {
                spacing: 4
                ToolBtn {
                    label: "Windowed"
                    active: window.displayMode === 0
                    onActivated: window.displayMode = 0
                }
                ToolBtn {
                    label: "Fullscreen"
                    active: window.displayMode === 1
                    onActivated: window.displayMode = 1
                }
                ToolBtn {
                    label: "Windowless"
                    active: window.displayMode === 2
                    onActivated: window.displayMode = 2
                }
            }

            Text {
                visible: Qt.application.screens.length > 1
                text: "FULLSCREEN MONITOR"
                color: "#5a5a60"
                font.pixelSize: 10
            }
            Column {
                visible: Qt.application.screens.length > 1
                width: parent.width
                spacing: 2

                Repeater {
                    model: Qt.application.screens

                    ToolBtn {
                        required property int index
                        required property var modelData
                        width: parent.width
                        label: (index + 1) + ": " + modelData.name
                        active: window.fsScreenIndex === index
                        onActivated: window.fsScreenIndex = index
                    }
                }
            }

            Text {
                visible: window.displayMode !== 1
                text: "WINDOW SIZE"
                color: "#5a5a60"
                font.pixelSize: 10
            }
            Row {
                visible: window.displayMode !== 1
                spacing: 6

                component NumBox: Rectangle {
                    property alias text: numInput.text
                    property int value: 0
                    width: 62
                    height: 24
                    radius: 2
                    color: "#101013"
                    border.width: 1
                    border.color: numInput.activeFocus ? "#3d7eff" : "#2a2a2e"
                    onValueChanged: numInput.text = value

                    TextInput {
                        id: numInput
                        anchors.fill: parent
                        anchors.margins: 3
                        color: "#d8d8dc"
                        font.pixelSize: 12
                        horizontalAlignment: TextInput.AlignHCenter
                        validator: IntValidator { bottom: 1; top: 16384 }
                        selectByMouse: true
                        text: parent.value
                    }
                }

                NumBox { id: winW; value: window.width }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "×"
                    color: "#8a8a90"
                    font.pixelSize: 12
                }
                NumBox { id: winH; value: window.height }
                ToolBtn {
                    label: "Set"
                    onActivated: {
                        window.width = Math.max(window.minimumWidth, parseInt(winW.text) || window.width)
                        window.height = Math.max(window.minimumHeight, parseInt(winH.text) || window.height)
                    }
                }
            }

            CheckRow {
                label: "Always on top"
                checked: window.alwaysOnTop
                onToggled: window.alwaysOnTop = !window.alwaysOnTop
            }
            CheckRow {
                label: "Rotate with Alt+scroll"
                checked: window.wheelRotateOn
                onToggled: window.wheelRotateOn = !window.wheelRotateOn
            }
            CheckRow {
                label: "Show tile names"
                checked: window.showTileNames
                onToggled: window.showTileNames = !window.showTileNames
            }
            CheckRow {
                label: "Allow duplicate sources"
                checked: window.allowDuplicates
                onToggled: window.allowDuplicates = !window.allowDuplicates
            }
            CheckRow {
                label: "Keep display awake"
                checked: window.neverSleep
                onToggled: window.neverSleep = !window.neverSleep
            }

            Text {
                text: "REMOTE CONTROL (COMPANION / STREAM DECK)"
                color: "#5a5a60"
                font.pixelSize: 10
            }
            CheckRow {
                label: "Enable TCP remote control"
                checked: window.remoteEnabled
                onToggled: window.remoteEnabled = !window.remoteEnabled
            }
            Row {
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Port"
                    color: "#8a8a90"
                    font.pixelSize: 11
                }
                NumBox { id: portBox; value: window.remotePort }
                ToolBtn {
                    label: "Set"
                    onActivated: {
                        const p = parseInt(portBox.text)
                        if (!isNaN(p) && p > 0 && p < 65536)
                            window.remotePort = p
                        portBox.value = window.remotePort
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: remote.listening ? "● listening"
                         : window.remoteEnabled ? "● port busy?" : ""
                    color: remote.listening ? "#40d060" : "#ff6060"
                    font.pixelSize: 11
                }
            }

            Text {
                text: "TILE SPACING (LAYOUTS)"
                color: "#5a5a60"
                font.pixelSize: 10
            }
            Row {
                spacing: 6

                NumBox { id: gapBox; value: window.tileGap }
                ToolBtn {
                    label: "Set"
                    onActivated: {
                        const g = parseInt(gapBox.text)
                        window.tileGap = isNaN(g) ? 0 : Math.max(0, Math.min(64, g))
                        gapBox.value = window.tileGap
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "px — 0 = seamless"
                    color: "#5a5a60"
                    font.pixelSize: 11
                }
            }

            ToolBtn {
                label: "About Mosaic…"
                onActivated: {
                    window.settingsOpen = false
                    window.aboutOpen = true
                }
            }

            Text {
                width: parent.width
                text: "Scroll = zoom · Drag = move tile (pans when zoomed in) · Alt+scroll = rotate · Corners = resize · Ctrl = snap · Esc = windowed · F11 = fullscreen · Ctrl+1–9 = profiles"
                color: "#5a5a60"
                font.pixelSize: 10
                wrapMode: Text.WordWrap
            }
        }
    }

    // ------------------------------------------------------ About dialog
    Rectangle {
        anchors.fill: parent
        visible: window.aboutOpen
        z: 300
        color: "#000000a0"

        MouseArea {
            anchors.fill: parent
            onClicked: window.aboutOpen = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: 360
            height: aboutCol.height + 40
            radius: 6
            color: "#1a1a1e"
            border.width: 1
            border.color: "#2a2a2e"

            MouseArea { anchors.fill: parent } // keep clicks inside

            Column {
                id: aboutCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 20
                spacing: 10

                Text {
                    text: "Mosaic"
                    color: "#e8e8ea"
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                }
                Text {
                    text: "Version 0.2.0 — Cinertia Systems"
                    color: "#8a8a90"
                    font.pixelSize: 12
                }
                Text {
                    width: parent.width
                    text: "A professional multiviewer for NDI® video sources."
                    color: "#d8d8dc"
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }
                Text {
                    width: parent.width
                    text: "NDI® is a registered trademark of Vizrt NDI AB."
                    color: "#8a8a90"
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }
                Text {
                    text: "Learn more at <a href='https://ndi.video/'>ndi.video</a>"
                    color: "#8a8a90"
                    linkColor: "#3d7eff"
                    font.pixelSize: 11
                    textFormat: Text.RichText
                    onLinkActivated: link => Qt.openUrlExternally(link)
                }
                Text {
                    text: "Support: <a href='mailto:max@cinertia.systems'>max@cinertia.systems</a>"
                    color: "#8a8a90"
                    linkColor: "#3d7eff"
                    font.pixelSize: 11
                    textFormat: Text.RichText
                    onLinkActivated: link => Qt.openUrlExternally(link)
                }
                Text {
                    text: "<a href='https://cinertia.systems/'>Cinertia.Systems</a>"
                    color: "#8a8a90"
                    linkColor: "#3d7eff"
                    font.pixelSize: 11
                    textFormat: Text.RichText
                    onLinkActivated: link => Qt.openUrlExternally(link)
                }
                Item { width: 1; height: 4 }
                ToolBtn {
                    label: "Close"
                    anchors.right: parent.right
                    onActivated: window.aboutOpen = false
                }
            }
        }
    }
}

