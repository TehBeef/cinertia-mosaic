import QtQuick

// One tile canvas — the surface the tiles live on. The main window has
// one; in multi-monitor mode every extra output window carries its own.
// Each canvas owns its tile list, selection, hover logic, snap grid,
// preset layouts and the capture/apply used by profiles and the session.
Rectangle {
    id: canvas
    color: "#0e0e10"
    clip: true

    // App-wide settings, wired in by the owning window.
    property bool snapEnabled: false
    property bool wheelRotate: true
    property bool globalShowName: true
    property int tileGap: 8
    // Source names offered in each tile's "change source" list.
    property var availableSources: []
    // Windowless mode: dragging empty canvas moves the whole window.
    property bool moveWindowOnDrag: false
    // Keyboard focus returns here after canvas clicks (the owning
    // window's key catcher) so Esc keeps working after text boxes.
    property Item focusTarget: null
    // Shown in the middle while the canvas has no tiles.
    property string emptyHint: ""

    readonly property int tileCount: tileModel.count
    property var selectedTile: null
    property int topZ: 0

    // Anything the sidebar's source dots must recount: add, remove, swap.
    signal tilesMutated()

    ListModel { id: tileModel }
    onTileCountChanged: canvas.tilesMutated()

    function sourceCount(name) {
        let count = 0
        for (let i = 0; i < tileModel.count; i++)
            if (tileModel.get(i).name === name)
                count++
        return count
    }

    // Duplicates ON: every click adds another instance. Duplicates OFF:
    // classic toggle — add if absent, otherwise remove every instance.
    function sourceClicked(name, allowDuplicates) {
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

    // ------------------------------------------- capture/apply (profiles)
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

    // A canvas inside a window that is still opening has no size yet —
    // hold the tiles and apply them on the first real size.
    property var pendingTiles: null
    function flushPendingTiles() {
        if (pendingTiles && width > 0 && height > 0) {
            const t = pendingTiles
            pendingTiles = null
            applyTiles(t)
        }
    }

    function applyTiles(tiles) {
        if (!tiles)
            return
        if (width <= 0 || height <= 0) {
            pendingTiles = tiles
            return
        }
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
        canvas.topZ = maxZ + 1
        canvas.selectedTile = null
    }

    // ------------------------------------------------- preset layouts
    // These arrange the tiles that are already on the canvas.
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

    function closeTilePopups() {
        for (let i = 0; i < tileRepeater.count; i++) {
            const t = tileRepeater.itemAt(i)
            if (t)
                t.closePopups()
        }
    }

    // Esc support: cancel any open crop/menus. Returns true if it did.
    function cancelOverlays() {
        let cancelled = false
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
        return cancelled
    }

    // Any mouse movement wakes the selected tile's accent so the user can
    // always find the active tile by nudging the mouse. Video repaints
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

    // The canvas changes size when the window mode changes or the sidebar
    // collapses. Scale the tile layout proportionally so the arrangement
    // survives every switch — otherwise tiles kept absolute positions and
    // could end up clipped out of view.
    property size prevSize: Qt.size(0, 0)
    onWidthChanged: {
        rescaleTiles()
        flushPendingTiles()
    }
    onHeightChanged: {
        rescaleTiles()
        flushPendingTiles()
    }

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

    // Track which tile is topmost under the cursor: only that tile shows
    // its hover UI, so with overlapping tiles the buttons you see are
    // always the buttons you hit.
    property var hoverTile: null

    function updateHoverTile(pos) {
        // childAt ignores z-order, so find the topmost tile manually:
        // highest z wins, later creation breaks ties (matching the scene
        // graph's paint order).
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
        onPointChanged: {
            canvas.mouseActivity(point.position)
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
            canvas.closeTilePopups()
            // Reclaim keyboard focus (e.g. after typing in a size box)
            // so Esc keeps working.
            if (canvas.focusTarget)
                canvas.focusTarget.forceActiveFocus()
        }
    }

    // In windowless mode, dragging empty canvas moves the window. Only
    // armed while the cursor is over EMPTY canvas: a DragHandler is
    // allowed to steal an in-progress drag from any MouseArea, and the
    // tiles' move/resize/crop areas are all MouseAreas — without this
    // guard, resizing a tile yanked the whole window around instead.
    DragHandler {
        enabled: canvas.moveWindowOnDrag && !canvas.hoverTile
        target: null
        onActiveChanged: if (active) canvas.Window.window.startSystemMove()
    }

    Text {
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 560)
        visible: tileModel.count === 0
        text: canvas.emptyHint
        color: "#5a5a60"
        font.pixelSize: 16
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
    }

    // Snap grid: appears only while a tile is being dragged or resized
    // with snapping engaged (Max's spec).
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

    // Tiles live in their own layer so their z-order competition stays
    // among themselves — chrome and status strip are siblings drawn above
    // this layer and can never be covered.
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
                snapEnabled: canvas.snapEnabled
                wheelRotate: canvas.wheelRotate
                globalShowName: canvas.globalShowName
                availableSources: canvas.availableSources
                gridSize: 16
                selected: canvas.selectedTile === this
                hoverTop: canvas.hoverTile === this
                onSnapDragActiveChanged:
                    canvas.snapDragCount += snapDragActive ? 1 : -1
                Component.onCompleted: {
                    x = 24 + (index % 5) * 40
                    y = 24 + (index % 5) * 40
                    z = ++canvas.topZ
                    canvas.selectedTile = this
                }
                onSelectRequested: {
                    canvas.selectedTile = this
                    z = ++canvas.topZ
                }
                onCloseRequested: {
                    if (canvas.selectedTile === this)
                        canvas.selectedTile = null
                    tileModel.remove(index)
                }
                // Swap the tile to another source in place: the model
                // rename flows into sourceName, the receiver reconnects
                // and the view resets to fit.
                onSwapRequested: newName => {
                    tileModel.setProperty(index, "name", newName)
                    canvas.tilesMutated()
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

    // Auto-hiding status bar: tiles get the whole canvas; move the mouse
    // to the bottom edge to peek at selected-tile info.
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
