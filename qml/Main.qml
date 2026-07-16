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
    // Hides the mouse over Mosaic's windows after 3 s of no movement.
    CursorGuard { id: cursorGuard; enabled: window.hideCursor }
    // Asks GitHub once, a moment after startup, whether a newer release
    // exists. Notify-only: the notice appears in Settings and About and
    // links to the releases page — nothing installs itself (show machines).
    UpdateChecker { id: updateChecker }
    Timer {
        interval: 3000
        running: window.checkUpdates
        onTriggered: updateChecker.check()
    }

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
                    tiles: canvas.tileCount
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
                case "2+1": window.applyTwoPlusOne(); break
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
    // Tiles live on the canvases now (see TileCanvas.qml): the main
    // canvas plus one per extra output window (multi-monitor mode).
    property bool snapOn: false
    property bool wheelRotateOn: true
    // Gutter used by the layout templates. 0 = seamless, edge to edge.
    property int tileGap: 8
    // Master switch for all tile name labels.
    property bool showTileNames: true
    // Small tiles automatically receive the NDI proxy stream (big
    // CPU/network savings); the per-tile Low bandwidth toggle still
    // forces it regardless of size.
    property bool autoLowBw: true
    // Per-tile stream status dots (red = down, yellow = stalling).
    property bool statusDots: true
    // Hide the mouse cursor over the app after a few idle seconds.
    property bool hideCursor: true
    // Check GitHub for a newer release at startup (notify-only).
    property bool checkUpdates: true
    // Off (default): sidebar clicks toggle a source on/off the canvas.
    // On: every click adds another tile of the source, so one shot can be
    // cropped to several regions.
    property bool allowDuplicates: false

    // ---------------------------------------------- canvas targeting
    // Which canvas sidebar clicks and layout buttons act on:
    // 0 = the main canvas, 1.. = extra output windows in model order.
    property int targetCanvas: 0
    // Bumped whenever any canvas's tiles change (add/remove/swap) so the
    // sidebar source dots recount.
    property int canvasRevision: 0
    // Set during shutdown so closing output windows doesn't delete them
    // from the session that was just saved.
    property bool quitting: false

    function canvasAt(i) {
        if (i === 0)
            return canvas
        const w = outputInst.objectAt(i - 1)
        return w ? w.canvas : null
    }
    function targetCanvasItem() {
        return canvasAt(targetCanvas) || canvas
    }
    function targetName() {
        return (targetCanvas === 0 || targetCanvas > outputModel.count)
            ? "Main" : outputModel.get(targetCanvas - 1).name
    }

    function addOutput() {
        // First extra window is "Output 2" (the main canvas is 1); pick
        // the first free name so re-adding after a close stays tidy.
        let n = 2
        const used = []
        for (let i = 0; i < outputModel.count; i++)
            used.push(outputModel.get(i).name)
        while (used.indexOf("Output " + n) !== -1)
            n++
        // Default to the next monitor over, if there is one.
        const si = Math.min(Qt.application.screens.length - 1,
                            outputModel.count + 1)
        outputModel.append({ name: "Output " + n,
                             screenIndex: si, mode: 0 })
        targetCanvas = outputModel.count
    }

    function removeOutput(i) {
        if (targetCanvas === i + 1)
            targetCanvas = 0
        else if (targetCanvas > i + 1)
            targetCanvas--
        outputModel.remove(i)
    }

    // Keep the display awake (show-day mode).
    property bool neverSleep: false
    // Switching profiles: keep canvases the profile doesn't include open
    // (true, default) or close them (false).
    property bool keepCanvases: true
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
    property bool shortcutsOpen: false

    // Esc: first close dialogs / cancel crops; otherwise return to windowed.
    function escapePressed() {
        let cancelled = false
        if (aboutOpen) {
            aboutOpen = false
            cancelled = true
        }
        if (shortcutsOpen) {
            shortcutsOpen = false
            cancelled = true
        }
        if (canvas.cancelOverlays())
            cancelled = true
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

    // Sidebar clicks act on whichever canvas is the current target.
    function sourceClicked(name) {
        const c = targetCanvasItem()
        if (c)
            c.sourceClicked(name, allowDuplicates)
    }
    function activeSourceCount(name) {
        const c = targetCanvasItem()
        return c ? c.sourceCount(name) : 0
    }

    // Layout presets also act on the target canvas (sidebar + remote).
    function applyGrid(cols) { targetCanvasItem().applyGrid(cols) }
    function applyOnePlusSide() { targetCanvasItem().applyOnePlusSide() }
    function applyTwoPlusEight() { targetCanvasItem().applyTwoPlusEight() }
    function applyTwoPlusOne() { targetCanvasItem().applyTwoPlusOne() }

    // ------------------------------------------------------- profiles
    // A profile bundles sources + tile layout + per-tile views. Applying
    // one is diff-based: tiles whose source is in both profiles keep
    // their receiver running, so switching feels instant during a show.
    property var profiles: []
    property string currentProfile: ""

    // Tile geometry inside each canvas is stored normalized (0..1), see
    // TileCanvas.captureTiles(). Profiles keep the main canvas in
    // `tiles` (same shape as before, so old profiles still load) and the
    // extra output canvases in `outputs`. Session saves also record each
    // output window's windowed geometry.
    function captureOutputs(withGeom) {
        const arr = []
        for (let i = 0; i < outputModel.count; i++) {
            const w = outputInst.objectAt(i)
            if (!w)
                continue
            const m = outputModel.get(i)
            const o = {
                name: m.name,
                screenIndex: m.screenIndex,
                mode: m.mode || 0, // 0 windowed, 1 fullscreen, 2 windowless
                tiles: w.canvas.captureTiles()
            }
            if (withGeom) {
                const r = w.windowedRect()
                o.wx = r.x
                o.wy = r.y
                o.ww = r.width
                o.wh = r.height
            }
            arr.push(o)
        }
        return arr
    }

    // keepExtra: canvases beyond the profile's list stay open untouched
    // (they fold into the now-active profile on the next autosave)
    // instead of closing — the "Keep canvases when switching profiles"
    // setting.
    function applyOutputs(outputs, keepExtra) {
        if (!outputs)
            outputs = []
        // Match window count to the target: surplus windows close (their
        // receivers shut down), missing ones open.
        if (!keepExtra)
            while (outputModel.count > outputs.length)
                outputModel.remove(outputModel.count - 1)
        while (outputModel.count < outputs.length)
            outputModel.append({ name: "Output " + (outputModel.count + 2),
                                 screenIndex: 0, mode: 0 })
        for (let i = 0; i < outputs.length; i++) {
            const o = outputs[i]
            // Saves from 0.3.0 stored `fullscreen: true/false` instead
            // of the three-way `mode` — map old files onto the new field.
            const mode = o.mode !== undefined ? o.mode
                       : (o.fullscreen === true ? 1 : 0)
            outputModel.set(i, {
                name: o.name || ("Output " + (i + 2)),
                screenIndex: o.screenIndex || 0,
                mode: mode
            })
            const w = outputInst.objectAt(i)
            if (!w)
                continue
            if (mode !== 1 && o.ww !== undefined && o.ww > 200) {
                w.x = o.wx
                w.y = o.wy
                w.width = o.ww
                w.height = o.wh
            }
            w.canvas.applyTiles(o.tiles || [])
        }
        if (targetCanvas > outputModel.count)
            targetCanvas = 0
    }

    function saveProfilesFile() {
        storage.save("profiles.json",
                     JSON.stringify({ version: 1, profiles: profiles }))
    }

    function saveProfile(name) {
        name = name.trim()
        if (name === "")
            return
        const p = { name: name, tiles: canvas.captureTiles(),
                    outputs: captureOutputs(false) }
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
        const tiles = canvas.captureTiles()
        const outputs = captureOutputs(false)
        if (JSON.stringify(profiles[idx].tiles) === JSON.stringify(tiles)
                && JSON.stringify(profiles[idx].outputs || [])
                   === JSON.stringify(outputs))
            return
        profiles[idx].tiles = tiles
        profiles[idx].outputs = outputs
        profiles = profiles.slice()
        saveProfilesFile()
    }

    function applyProfile(name) {
        const p = profiles.find(x => x.name === name)
        if (!p)
            return
        syncActiveProfile() // don't lose changes made since the last tick
        canvas.applyTiles(p.tiles)
        // Canvases the profile doesn't know: kept open or closed per the
        // "Keep canvases when switching profiles" setting.
        applyOutputs(p.outputs, keepCanvases)
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
            version: 2,
            snapOn: snapOn,
            wheelRotateOn: wheelRotateOn,
            tileGap: tileGap,
            showTileNames: showTileNames,
            allowDuplicates: allowDuplicates,
            autoLowBw: autoLowBw,
            statusDots: statusDots,
            hideCursor: hideCursor,
            checkUpdates: checkUpdates,
            neverSleep: neverSleep,
            keepCanvases: keepCanvases,
            remoteEnabled: remoteEnabled,
            remotePort: remotePort,
            currentProfile: currentProfile,
            targetCanvas: targetCanvas,
            tiles: canvas.captureTiles(),
            outputs: captureOutputs(true)
        }))
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
                autoLowBw = s.autoLowBw !== false
                statusDots = s.statusDots !== false
                hideCursor = s.hideCursor !== false
                checkUpdates = s.checkUpdates !== false
                neverSleep = s.neverSleep === true
                keepCanvases = s.keepCanvases !== false
                remoteEnabled = s.remoteEnabled === true
                if (s.remotePort !== undefined)
                    remotePort = s.remotePort
                currentProfile = s.currentProfile || ""
                canvas.applyTiles(s.tiles || [])
                applyOutputs(s.outputs)
                if (s.targetCanvas !== undefined)
                    targetCanvas = Math.max(0, Math.min(s.targetCanvas,
                                                        outputModel.count))
            }
        } catch (e) {
            console.warn("Could not read session.json:", e)
        }
    }

    // With extra output windows open, closing the main window would just
    // leave them orphaned — save everything, then quit the whole app.
    onClosing: {
        saveSession()
        quitting = true
        Qt.quit()
    }

    // Autosave so a crash or power loss never costs the arrangement.
    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: window.saveSession()
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
                onPointChanged: canvas.mouseActivity(point.position)
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
                    text: {
                        window.canvasRevision // re-evaluate on renames too
                        if (finder.sources.length === 0)
                            return "Searching the network…"
                        let t = finder.sources.length + (window.allowDuplicates
                            ? " found — click to add (again for another copy)"
                            : " found — click to add/remove")
                        if (window.targetCanvas > 0)
                            t += " → " + window.targetName()
                        return t
                    }
                    color: window.targetCanvas > 0 ? "#3d7eff" : "#8a8a90"
                    font.pixelSize: 11
                }

                ListView {
                    id: sourceList
                    width: parent.width
                    height: parent.height - y - layoutsSec.height - outputsSec.height - profilesSec.height - footer.height - 56
                    clip: true
                    spacing: 4
                    model: finder.sources

                    delegate: Rectangle {
                        required property string modelData
                        // Re-counts whenever any canvas's tiles change or
                        // the target canvas switches. Several tiles may
                        // show the same source (different crops of a shot).
                        property int instances: {
                            window.canvasRevision
                            window.targetCanvas
                            return window.activeSourceCount(modelData)
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
                        ToolBtn { label: "2+1"; height: 24; onActivated: window.applyTwoPlusOne() }
                        ToolBtn {
                            label: "Snap"
                            height: 24
                            active: window.snapOn
                            onActivated: window.snapOn = !window.snapOn
                        }
                    }
                }

                // ------------------------------- canvases (multi-monitor)
                Column {
                    id: outputsSec
                    width: parent.width
                    spacing: 4

                    Text {
                        text: "CANVASES"
                        color: "#5a5a60"
                        font.pixelSize: 10
                    }

                    Flow {
                        width: parent.width
                        spacing: 4

                        ToolBtn {
                            label: "Main"
                            height: 24
                            active: window.targetCanvas === 0
                            onActivated: window.targetCanvas = 0
                        }
                        Repeater {
                            model: outputModel

                            ToolBtn {
                                required property int index
                                required property string name
                                label: name
                                height: 24
                                active: window.targetCanvas === index + 1
                                onActivated: window.targetCanvas = index + 1
                            }
                        }
                        ToolBtn {
                            label: "+ Add"
                            height: 24
                            onActivated: window.addOutput()
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

                    // Update notice: always on screen in the main window,
                    // so no menu needs opening to learn a release is out.
                    Row {
                        visible: updateChecker.updateAvailable
                        spacing: 6

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 7
                            height: 7
                            radius: 3.5
                            color: "#3d7eff"
                        }
                        Text {
                            text: "Update available — <a href='"
                                + updateChecker.releaseUrl
                                + "' style='color:#3d7eff;text-decoration:none;'>Download "
                                + updateChecker.latestVersion + "</a>"
                            color: "#d8d8dc"
                            linkColor: "#3d7eff"
                            font.pixelSize: 11
                            textFormat: Text.RichText
                            onLinkActivated: link => Qt.openUrlExternally(link)
                        }
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
        TileCanvas {
            id: canvas
            width: parent.width - sidebar.width
            height: parent.height
            snapEnabled: window.snapOn
            wheelRotate: window.wheelRotateOn
            globalShowName: window.showTileNames
            tileGap: window.tileGap
            autoLowBw: window.autoLowBw
            statusDots: window.statusDots
            cursorGuard: cursorGuard
            availableSources: finder.sources
            moveWindowOnDrag: window.displayMode === 2
            focusTarget: keyCatcher
            emptyHint: finder.sources.length === 0
                       ? "Waiting for NDI® sources to appear on the network…"
                       : "Click sources on the left to add them to the canvas"
            onTilesMutated: window.canvasRevision++
        }
    }

    // ------------------------------------------- extra output canvases
    // Multi-monitor mode: each entry is one more window with its own
    // canvas, typically sent fullscreen to another monitor. The model is
    // the single source of truth for name/monitor/fullscreen; windows
    // only emit signals and the writes flow back in via bindings.
    ListModel { id: outputModel }

    Instantiator {
        id: outputInst
        model: outputModel

        delegate: OutputWindow {
            outputName: model.name
            screenIndex: model.screenIndex
            windowMode: model.mode
            isTarget: window.targetCanvas === index + 1
            snapOn: window.snapOn
            wheelRotateOn: window.wheelRotateOn
            showTileNames: window.showTileNames
            tileGap: window.tileGap
            autoLowBw: window.autoLowBw
            statusDots: window.statusDots
            cursorGuard: cursorGuard
            availableSources: finder.sources
            appQuitting: window.quitting
            onCloseRequested: window.removeOutput(index)
            onRenameRequested: nm => {
                outputModel.setProperty(index, "name", nm)
                window.canvasRevision++ // sidebar hint shows the new name
            }
            onModeChangeRequested: m =>
                outputModel.setProperty(index, "mode", m)
            onScreenPicked: si =>
                outputModel.setProperty(index, "screenIndex", si)
            onTargetRequested: window.targetCanvas = index + 1
            onTilesMutated: window.canvasRevision++
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
        // Never taller than the window — the content scrolls instead,
        // so every setting stays reachable on small displays.
        height: Math.min(settingsCol.height + 28, window.height - 58)
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

        Flickable {
            id: settingsFlick
            anchors.fill: parent
            anchors.margins: 14
            contentWidth: width
            contentHeight: settingsCol.height
            clip: true

        Column {
            id: settingsCol
            width: settingsFlick.width
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
                label: "Stream status indicators"
                checked: window.statusDots
                onToggled: window.statusDots = !window.statusDots
            }
            CheckRow {
                label: "Hide mouse when idle"
                checked: window.hideCursor
                onToggled: window.hideCursor = !window.hideCursor
            }
            CheckRow {
                label: "Auto low bandwidth for small tiles"
                checked: window.autoLowBw
                onToggled: window.autoLowBw = !window.autoLowBw
            }
            CheckRow {
                label: "Keep canvases when switching profiles"
                checked: window.keepCanvases
                onToggled: window.keepCanvases = !window.keepCanvases
            }
            CheckRow {
                label: "Keep display awake"
                checked: window.neverSleep
                onToggled: window.neverSleep = !window.neverSleep
            }
            CheckRow {
                label: "Check for updates at startup"
                checked: window.checkUpdates
                onToggled: window.checkUpdates = !window.checkUpdates
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

            Row {
                spacing: 6

                ToolBtn {
                    label: "Shortcuts…"
                    onActivated: {
                        window.settingsOpen = false
                        window.shortcutsOpen = true
                    }
                }
                ToolBtn {
                    label: "About Mosaic…"
                    onActivated: {
                        window.settingsOpen = false
                        window.aboutOpen = true
                    }
                }
            }
        }
        }

        // Slim gray scroll indicator drawn on the panel background (the
        // native control style does not allow restyling ScrollBar).
        Rectangle {
            visible: settingsFlick.visibleArea.heightRatio < 1
            anchors.right: parent.right
            anchors.rightMargin: 4
            y: 14 + settingsFlick.visibleArea.yPosition * settingsFlick.height
            height: settingsFlick.visibleArea.heightRatio * settingsFlick.height
            width: 4
            radius: 2
            color: "#3a3a40"
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
                    text: "Version 0.6.0 — Cinertia Systems"
                    color: "#8a8a90"
                    font.pixelSize: 12
                }
                Row {
                    visible: updateChecker.updateAvailable
                    spacing: 6

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 7
                        height: 7
                        radius: 3.5
                        color: "#3d7eff"
                    }
                    Text {
                        text: "Update available — <a href='"
                            + updateChecker.releaseUrl
                            + "' style='color:#3d7eff;text-decoration:none;'>Download "
                            + updateChecker.latestVersion + "</a>"
                        color: "#d8d8dc"
                        linkColor: "#3d7eff"
                        font.pixelSize: 11
                        textFormat: Text.RichText
                        onLinkActivated: link => Qt.openUrlExternally(link)
                    }
                }
                Text {
                    width: parent.width
                    text: "A professional multiviewer for NDI® video sources."
                    color: "#d8d8dc"
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
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
                Text {
                    text: "Downloads and release notes: <a href='https://github.com/MaxDeRoin/cinertia-mosaic'>GitHub</a>"
                    color: "#8a8a90"
                    linkColor: "#3d7eff"
                    font.pixelSize: 11
                    textFormat: Text.RichText
                    onLinkActivated: link => Qt.openUrlExternally(link)
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
                Item { width: 1; height: 4 }
                ToolBtn {
                    label: "Close"
                    anchors.right: parent.right
                    onActivated: window.aboutOpen = false
                }
            }
        }
    }

    // --------------------------------------------------- shortcuts dialog
    Rectangle {
        anchors.fill: parent
        visible: window.shortcutsOpen
        z: 300
        color: "#000000a0"

        MouseArea {
            anchors.fill: parent
            onClicked: window.shortcutsOpen = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: 480
            height: shortcutsCol.height + 40
            radius: 6
            color: "#1a1a1e"
            border.width: 1
            border.color: "#2a2a2e"

            MouseArea { anchors.fill: parent } // keep clicks inside

            // One shortcut line: key chip on the left, action text right.
            component KeyRow: Row {
                property string keys
                property string action
                spacing: 8

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: keyText.width + 12
                    height: 18
                    radius: 3
                    color: "#101013"
                    border.width: 1
                    border.color: "#2a2a2e"

                    Text {
                        id: keyText
                        anchors.centerIn: parent
                        text: parent.parent.keys
                        color: "#d8d8dc"
                        font.pixelSize: 10
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.action
                    color: "#8a8a90"
                    font.pixelSize: 11
                }
            }
            component GroupTitle: Text {
                color: "#5a5a60"
                font.pixelSize: 9
                font.letterSpacing: 0.5
            }

            Column {
                id: shortcutsCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 20
                spacing: 10

                Text {
                    text: "Shortcuts"
                    color: "#e8e8ea"
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }

                Row {
                    width: parent.width
                    spacing: 24

                    Column {
                        width: (parent.width - 24) / 2
                        spacing: 5

                        GroupTitle { text: "INSIDE A TILE" }
                        KeyRow { keys: "Scroll"; action: "Zoom toward the cursor" }
                        KeyRow { keys: "Drag"; action: "Pan when zoomed in" }
                        KeyRow { keys: "Shift+drag"; action: "Move the picture" }
                        KeyRow { keys: "Alt+scroll"; action: "Rotate in fine steps" }
                        KeyRow { keys: "Double-click"; action: "Reset zoom and pan" }
                        KeyRow { keys: "Esc"; action: "Cancel a crop" }

                        Item { width: 1; height: 6 }
                        GroupTitle { text: "DISPLAY AND PROFILES" }
                        KeyRow { keys: "F11"; action: "Fullscreen" }
                        KeyRow { keys: "Esc"; action: "Back to windowed" }
                        KeyRow { keys: "Ctrl+1–9"; action: "Switch profiles" }
                    }

                    Column {
                        width: (parent.width - 24) / 2
                        spacing: 5

                        GroupTitle { text: "ON THE CANVAS" }
                        KeyRow { keys: "Drag"; action: "Move a tile" }
                        KeyRow { keys: "Edges/corners"; action: "Resize a tile" }
                        KeyRow { keys: "Ctrl+drag"; action: "Snap to the grid" }
                        KeyRow { keys: "Alt+drag"; action: "Move touching tiles" }
                        KeyRow { keys: "Alt+resize"; action: "Resize touching tiles" }

                        Item { width: 1; height: 6 }
                        GroupTitle { text: "TILE HEADER" }
                        KeyRow { keys: "⟲ ⟳"; action: "Rotate 90°" }
                        KeyRow { keys: "Fit"; action: "Fit the picture" }
                        KeyRow { keys: "Reset"; action: "Undo crop, rotation, zoom" }
                    }
                }

                Item { width: 1; height: 4 }
                ToolBtn {
                    label: "Close"
                    anchors.right: parent.right
                    onActivated: window.shortcutsOpen = false
                }
            }
        }
    }
}

