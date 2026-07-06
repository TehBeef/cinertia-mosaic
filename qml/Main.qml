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

    // ------------------------------------------------------ app state
    // Which sources are on the canvas. Tile positions live on the tile
    // items themselves while the app runs (saved layouts come later).
    ListModel { id: tileModel }
    property int topZ: 0
    property bool snapOn: false
    property bool wheelRotateOn: true

    // Display modes: 0 = windowed, 1 = fullscreen, 2 = windowless
    property int displayMode: 0
    property bool alwaysOnTop: false
    property int fsScreenIndex: 0
    property bool sidebarCollapsed: false
    property bool settingsOpen: false

    onDisplayModeChanged: {
        // Sidebar gets out of the way in fullscreen/windowless (Max's spec);
        // the left-edge hover strip brings it back on demand.
        sidebarCollapsed = displayMode !== 0
        settingsOpen = false
        applyDisplayMode()
    }
    onAlwaysOnTopChanged: applyDisplayMode()
    onFsScreenIndexChanged: {
        if (displayMode === 1) {
            window.visibility = Window.Windowed
            applyDisplayMode()
        }
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

    // Esc: first cancel any active crop; otherwise return to windowed.
    Shortcut {
        sequence: "Escape"
        onActivated: {
            let cancelled = false
            for (let i = 0; i < tileRepeater.count; i++) {
                const t = tileRepeater.itemAt(i)
                if (t && t.cropMode) {
                    t.cropMode = false
                    cancelled = true
                }
            }
            if (window.settingsOpen) {
                window.settingsOpen = false
                cancelled = true
            }
            if (!cancelled && window.displayMode !== 0)
                window.displayMode = 0
        }
    }

    function sourceOnCanvas(name) {
        for (let i = 0; i < tileModel.count; i++)
            if (tileModel.get(i).name === name)
                return true
        return false
    }

    function toggleSource(name) {
        for (let i = 0; i < tileModel.count; i++) {
            if (tileModel.get(i).name === name) {
                tileModel.remove(i)
                return
            }
        }
        tileModel.append({ name: name })
    }

    // Preset layouts arrange the tiles that are already on the canvas.
    function applyGrid(cols) {
        const n = tileRepeater.count
        if (n === 0)
            return
        const rows = Math.ceil(n / cols)
        const gut = 8
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
        const gut = 8
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
        TapHandler { onTapped: parent.activated() }
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

            Column {
                width: 256
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.margins: 12
                spacing: 8

                Item {
                    width: parent.width
                    height: 30

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "NDI® Sources"
                        color: "#e8e8ea"
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
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
                    text: finder.sources.length === 0
                          ? "Searching the network…"
                          : finder.sources.length + " found — click to add/remove"
                    color: "#8a8a90"
                    font.pixelSize: 11
                }

                ListView {
                    id: sourceList
                    width: parent.width
                    height: parent.height - y - footer.height - 16
                    clip: true
                    spacing: 4
                    model: finder.sources

                    delegate: Rectangle {
                        required property string modelData
                        // Depends on tileModel.count so it re-evaluates on
                        // every add/remove.
                        property bool onCanvas: {
                            tileModel.count
                            return window.sourceOnCanvas(modelData)
                        }
                        width: sourceList.width
                        height: 34
                        radius: 3
                        color: onCanvas ? "#22303e"
                             : hover.hovered ? "#1c1c20" : "transparent"
                        border.width: 1
                        border.color: onCanvas ? "#3d7eff" : "#26262b"

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
                            text: parent.onCanvas ? "●" : ""
                            color: "#3d7eff"
                            font.pixelSize: 9
                        }

                        HoverHandler { id: hover }
                        TapHandler {
                            onTapped: window.toggleSource(parent.modelData)
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

            HoverHandler { id: canvasHover }

            // Click empty canvas to deselect.
            TapHandler {
                onTapped: canvas.selectedTile = null
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
                        gridSize: 16
                        selected: canvas.selectedTile === this
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
                    }
                }
            }

            // Hover-reveal canvas toolbar: layout presets + snap toggle.
            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 20
                width: toolRow.width + 16
                height: 34
                radius: 4
                color: "#1a1a1ee6"
                border.width: 1
                border.color: "#2a2a2e"
                visible: tileModel.count > 0
                opacity: canvasHover.hovered ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150 } }

                Row {
                    id: toolRow
                    anchors.centerIn: parent
                    spacing: 4

                    ToolBtn { label: "2×2"; onActivated: window.applyGrid(2) }
                    ToolBtn { label: "3×3"; onActivated: window.applyGrid(3) }
                    ToolBtn { label: "1+side"; onActivated: window.applyOnePlusSide() }
                    ToolBtn {
                        label: "Snap"
                        active: window.snapOn
                        onActivated: window.snapOn = !window.snapOn
                    }
                }
            }

            // Status strip: selected tile info + interaction hints.
            // Windowless mode is pure canvas — the strip only shows on hover.
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 26
                color: "#141417cc"
                visible: tileModel.count > 0
                opacity: (window.displayMode !== 2 || canvasHover.hovered) ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150 } }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    text: canvas.selectedTile
                          ? canvas.selectedTile.sourceName
                          : tileModel.count + " tile" + (tileModel.count === 1 ? "" : "s")
                    color: "#d8d8dc"
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
                Text {
                    anchors.centerIn: parent
                    text: "Scroll = zoom · Drag = move tile (pans when zoomed in) · Alt+scroll = rotate · Corners = resize · Ctrl = snap"
                    color: "#5a5a60"
                    font.pixelSize: 10
                    visible: canvasHover.hovered
                }
                Text {
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
            TapHandler { onTapped: parent.toggled() }
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

            Text {
                text: "Esc returns to windowed mode"
                color: "#5a5a60"
                font.pixelSize: 10
            }
        }
    }
}
