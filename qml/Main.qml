import QtQuick
import QtQuick.Controls
import Mosaic

ApplicationWindow {
    id: window
    width: 1280
    height: 720
    visible: true
    title: "Mosaic"
    color: "#0e0e10"

    NdiFinder { id: finder }

    // Which sources are on the canvas. Tile positions live on the tile
    // items themselves while the app runs (saved layouts come later).
    ListModel { id: tileModel }
    property int topZ: 0
    property bool snapOn: false

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

    Row {
        anchors.fill: parent

        // ------------------------------------------------ source sidebar
        Rectangle {
            id: sidebar
            width: 280
            height: parent.height
            color: "#141417"

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                Text {
                    text: "NDI® Sources"
                    color: "#e8e8ea"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
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

            Text {
                anchors.centerIn: parent
                visible: tileModel.count === 0
                text: finder.sources.length === 0
                      ? "Waiting for NDI® sources to appear on the network…"
                      : "Click sources on the left to add them to the canvas"
                color: "#5a5a60"
                font.pixelSize: 16
            }

            Repeater {
                id: tileRepeater
                model: tileModel

                delegate: Tile {
                    required property int index
                    required property string name
                    sourceName: name
                    snapEnabled: window.snapOn
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

            component ToolBtn: Rectangle {
                property string label
                property bool active: false
                signal activated()
                width: btnText.width + 18
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
                    font.pixelSize: 12
                }
                HoverHandler { id: btnHover }
                TapHandler { onTapped: parent.activated() }
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
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 26
                color: "#141417cc"
                visible: tileModel.count > 0

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
}
