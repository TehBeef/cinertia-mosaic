import QtQuick
import Mosaic

// One source tile on the canvas. Drag the hover header to move, drag the
// corners to resize. Hold Ctrl while dragging (or turn on Snap) to snap
// to the grid. The video inside keeps its own zoom/pan/rotate/crop.
Item {
    id: tile

    property string sourceName: ""
    property bool selected: false
    property bool snapEnabled: false
    property int gridSize: 16
    property bool cropMode: false
    property bool wheelRotate: true
    property bool sizeOpen: false
    property bool optsOpen: false
    // Per-tile options (persisted with profiles and the session).
    property bool showName: true
    property bool showMeter: false
    property bool lowBw: false
    // Custom label (e.g. "CAM 1 — STAGE LEFT"); empty = show source name.
    property string customName: ""
    readonly property string displayName: customName !== "" ? customName : sourceName
    // True while the user drags/resizes this tile with snapping engaged —
    // the canvas shows the snap grid while any tile has this set.
    property bool snapDragActive: false
    readonly property string status: video.status

    function viewState() { return video.viewState() }
    function setViewState(s) { video.setViewState(s) }

    signal closeRequested()
    signal selectRequested()

    width: 480
    height: 270

    // Selection accent fades out after a few seconds of no interaction.
    property bool highlightFaded: false
    onSelectedChanged: highlightFaded = false
    onSelectRequested: highlightFaded = false
    Timer {
        interval: 3000
        running: tile.selected && !tileHover.hovered && !tile.highlightFaded
        onTriggered: tile.highlightFaded = true
    }

    function closePopups() {
        optsOpen = false
        sizeOpen = false
    }

    readonly property int minW: 160
    readonly property int minH: 90

    function snap(v) { return Math.round(v / gridSize) * gridSize }

    Rectangle {
        anchors.fill: parent
        color: "#101013"
        border.width: 1
        border.color: (tile.selected && !tile.highlightFaded) ? "#3d7eff" : "#26262b"
        Behavior on border.color { ColorAnimation { duration: 400 } }
        clip: true // video must never draw outside its tile

        // Shared move-the-tile drag logic. The body instance sits under the
        // video: it receives drags when the video is at fit zoom (nothing
        // to pan), so grabbing a tile anywhere moves it.
        component MoveArea: MouseArea {
            // The header instance keeps popups open (their buttons live
            // there); a press anywhere else counts as clicking off them.
            property bool closesPopups: true
            property point pressPos
            onPressed: mouse => {
                tile.selectRequested()
                if (closesPopups)
                    tile.closePopups()
                pressPos = Qt.point(mouse.x, mouse.y)
            }
            onPositionChanged: mouse => {
                if (!pressed)
                    return
                const doSnap = tile.snapEnabled || (mouse.modifiers & Qt.ControlModifier)
                tile.snapDragActive = doSnap
                let nx = tile.x + mouse.x - pressPos.x
                let ny = tile.y + mouse.y - pressPos.y
                if (doSnap) {
                    nx = tile.snap(nx)
                    ny = tile.snap(ny)
                }
                tile.x = Math.max(0, Math.min(nx, tile.parent.width - tile.width))
                tile.y = Math.max(0, Math.min(ny, tile.parent.height - tile.height))
            }
            onReleased: tile.snapDragActive = false
            onCanceled: tile.snapDragActive = false
        }

        MoveArea {
            anchors.fill: parent
        }

        VideoView {
            id: video
            anchors.fill: parent
            anchors.margins: 1
            sourceName: tile.sourceName
            wheelRotateEnabled: tile.wheelRotate
            lowBandwidth: tile.lowBw
            meterEnabled: tile.showMeter
            onInteracted: {
                tile.selectRequested()
                tile.closePopups()
            }
        }

        // Source name overlay (broadcast-style label, bottom center).
        Rectangle {
            visible: tile.showName
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(nameLabel.implicitWidth + 16, tile.width - 24)
            height: 20
            radius: 3
            color: "#000000b0"

            Text {
                id: nameLabel
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                text: tile.displayName
                color: "#e8e8ea"
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }

        // Audio meter overlay (visual only, right edge).
        component MeterBar: Rectangle {
            property real level: 0
            width: 5
            radius: 2
            color: "#000000a0"

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.height * parent.level
                radius: 2
                color: parent.level > 0.9 ? "#ff4040"
                     : parent.level > 0.75 ? "#ffd040" : "#40d060"
            }
        }

        Row {
            visible: tile.showMeter
            anchors.right: parent.right
            anchors.rightMargin: 7
            anchors.top: parent.top
            anchors.topMargin: 34
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            spacing: 2

            MeterBar { height: parent.height; level: video.audioLeft }
            MeterBar { height: parent.height; level: video.audioRight }
        }

        HoverHandler {
            id: tileHover
            // Leaving the tile closes its popup menus (click-away/move-away)
            // and wakes the selection highlight while hovering.
            onHoveredChanged: {
                if (hovered)
                    tile.highlightFaded = false
                else
                    tile.closePopups()
            }
        }

        component TileBtn: Rectangle {
            property string label
            property bool active: false
            property int fontSize: 12
            signal activated()
            width: Math.max(btnText.width + 12, 22)
            height: 22
            radius: 2
            color: active ? "#22303e" : btnHover.hovered ? "#2a2a30" : "transparent"
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

        // Hover header: drag to move the tile; per-tile controls right.
        Rectangle {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 1
            height: 28
            color: "#1a1a1ee6"
            opacity: (tileHover.hovered || moveArea.pressed || tile.sizeOpen || tile.optsOpen) ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 120 } }

            MoveArea {
                id: moveArea
                anchors.fill: parent
                cursorShape: Qt.SizeAllCursor
                closesPopups: false
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 8
                width: parent.width - controls.width - 24
                text: tile.displayName
                color: "#d8d8dc"
                font.pixelSize: 11
                elide: Text.ElideRight
            }

            Row {
                id: controls
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 4
                spacing: 2

                TileBtn { label: "⟲"; fontSize: 15; onActivated: video.rotateBy(-90) }
                TileBtn { label: "⟳"; fontSize: 15; onActivated: video.rotateBy(90) }
                TileBtn {
                    label: "Crop"
                    active: tile.cropMode
                    onActivated: tile.cropMode = !tile.cropMode
                }
                TileBtn {
                    label: "Fit"
                    onActivated: {
                        // Reset the view AND shape the tile to the video so
                        // the picture fills the frame with no black bars.
                        tile.cropMode = false
                        video.resetView()
                        const vs = video.videoSize
                        if (vs.width > 0 && vs.height > 0) {
                            const nh = Math.max(tile.minH,
                                Math.round(tile.width * vs.height / vs.width))
                            tile.height = nh
                        }
                    }
                }
                TileBtn {
                    label: "Size"
                    active: tile.sizeOpen
                    onActivated: {
                        tile.sizeOpen = !tile.sizeOpen
                        tile.optsOpen = false
                    }
                }
                TileBtn {
                    label: "⋯"
                    fontSize: 15
                    active: tile.optsOpen
                    onActivated: {
                        tile.optsOpen = !tile.optsOpen
                        tile.sizeOpen = false
                    }
                }
                TileBtn { label: "✕"; fontSize: 14; onActivated: tile.closeRequested() }
            }
        }

        // Custom tile size entry (opens from the Size button).
        component NumBox: Rectangle {
            property alias text: input.text
            property int value: 0
            width: 56
            height: 22
            radius: 2
            color: "#101013"
            border.width: 1
            border.color: input.activeFocus ? "#3d7eff" : "#2a2a2e"
            onValueChanged: input.text = value

            TextInput {
                id: input
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

        Rectangle {
            visible: tile.sizeOpen
            anchors.top: header.bottom
            anchors.right: parent.right
            anchors.margins: 4
            width: sizeRow.width + 16
            height: 32
            radius: 3
            color: "#1a1a1e"
            border.width: 1
            border.color: "#2a2a2e"

            Row {
                id: sizeRow
                anchors.centerIn: parent
                spacing: 6

                NumBox { id: wBox; value: Math.round(tile.width) }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "×"
                    color: "#8a8a90"
                    font.pixelSize: 12
                }
                NumBox { id: hBox; value: Math.round(tile.height) }
                TileBtn {
                    label: "Set"
                    onActivated: {
                        tile.width = Math.max(tile.minW, parseInt(wBox.text) || tile.width)
                        tile.height = Math.max(tile.minH, parseInt(hBox.text) || tile.height)
                        tile.sizeOpen = false
                    }
                }
            }
        }

        // Per-tile options panel (opens from the ⋯ button).
        Rectangle {
            visible: tile.optsOpen
            anchors.top: header.bottom
            anchors.right: parent.right
            anchors.margins: 4
            width: 160
            height: optsCol.height + 16
            radius: 3
            color: "#1a1a1e"
            border.width: 1
            border.color: "#2a2a2e"

            MouseArea { anchors.fill: parent } // swallow stray presses

            component OptCheck: Item {
                property string label
                property bool checked: false
                signal toggled()
                width: optsCol.width
                height: 22

                Rectangle {
                    id: optBox
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14
                    height: 14
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
                    anchors.left: optBox.right
                    anchors.leftMargin: 8
                    text: parent.label
                    color: "#d8d8dc"
                    font.pixelSize: 12
                }
                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: parent.toggled()
                }
            }

            Column {
                id: optsCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 8
                spacing: 4

                Text {
                    text: "TILE NAME"
                    color: "#5a5a60"
                    font.pixelSize: 9
                }
                Rectangle {
                    width: optsCol.width
                    height: 24
                    radius: 2
                    color: "#101013"
                    border.width: 1
                    border.color: renameInput.activeFocus ? "#3d7eff" : "#2a2a2e"

                    TextInput {
                        id: renameInput
                        anchors.fill: parent
                        anchors.margins: 4
                        color: "#d8d8dc"
                        font.pixelSize: 11
                        selectByMouse: true
                        clip: true
                        text: tile.customName
                        onTextEdited: tile.customName = text
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 4
                        anchors.right: parent.right
                        text: tile.sourceName
                        color: "#5a5a60"
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        visible: renameInput.text === "" && !renameInput.activeFocus
                    }
                }

                OptCheck {
                    label: "Source name"
                    checked: tile.showName
                    onToggled: tile.showName = !tile.showName
                }
                OptCheck {
                    label: "Audio meter"
                    checked: tile.showMeter
                    onToggled: tile.showMeter = !tile.showMeter
                }
                OptCheck {
                    label: "Low bandwidth"
                    checked: tile.lowBw
                    onToggled: tile.lowBw = !tile.lowBw
                }
            }
        }

        // Crop mode: drag a rectangle over the video.
        MouseArea {
            id: cropArea
            anchors.fill: video
            visible: tile.cropMode
            cursorShape: Qt.CrossCursor
            property point start: Qt.point(0, 0)
            property rect sel: Qt.rect(0, 0, 0, 0)

            onPressed: mouse => {
                tile.selectRequested()
                start = Qt.point(mouse.x, mouse.y)
                sel = Qt.rect(mouse.x, mouse.y, 0, 0)
            }
            onPositionChanged: mouse => {
                if (!pressed)
                    return
                sel = Qt.rect(Math.min(start.x, mouse.x),
                              Math.min(start.y, mouse.y),
                              Math.abs(mouse.x - start.x),
                              Math.abs(mouse.y - start.y))
            }
            onReleased: {
                if (sel.width > 10 && sel.height > 10)
                    video.applyCropFromItemRect(Qt.rect(sel.x, sel.y, sel.width, sel.height))
                sel = Qt.rect(0, 0, 0, 0)
                tile.cropMode = false
            }

            Rectangle { anchors.fill: parent; color: "#00000055" }
            Rectangle {
                x: cropArea.sel.x
                y: cropArea.sel.y
                width: cropArea.sel.width
                height: cropArea.sel.height
                color: "#3d7eff18"
                border.width: 1
                border.color: "#3d7eff"
            }
        }

        // Corner resize grips (invisible, cursor changes on hover).
        component Grip: MouseArea {
            property bool onLeft: false
            property bool onTop: false
            width: 14
            height: 14
            z: 10
            cursorShape: (onLeft === onTop) ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor
            property point pressScene
            property rect startGeom

            onPressed: mouse => {
                tile.selectRequested()
                pressScene = mapToItem(tile.parent, mouse.x, mouse.y)
                startGeom = Qt.rect(tile.x, tile.y, tile.width, tile.height)
            }
            onReleased: tile.snapDragActive = false
            onCanceled: tile.snapDragActive = false
            onPositionChanged: mouse => {
                if (!pressed)
                    return
                const p = mapToItem(tile.parent, mouse.x, mouse.y)
                const dx = p.x - pressScene.x
                const dy = p.y - pressScene.y
                let nx = startGeom.x, ny = startGeom.y
                let nw = startGeom.width, nh = startGeom.height

                if (onLeft) { nx = startGeom.x + dx; nw = startGeom.width - dx }
                else        { nw = startGeom.width + dx }
                if (onTop)  { ny = startGeom.y + dy; nh = startGeom.height - dy }
                else        { nh = startGeom.height + dy }

                tile.snapDragActive = tile.snapEnabled || (mouse.modifiers & Qt.ControlModifier)
                if (tile.snapDragActive) {
                    if (onLeft) { const s = tile.snap(nx); nw += nx - s; nx = s }
                    else        { nw = tile.snap(nx + nw) - nx }
                    if (onTop)  { const s = tile.snap(ny); nh += ny - s; ny = s }
                    else        { nh = tile.snap(ny + nh) - ny }
                }

                if (nw < tile.minW) { if (onLeft) nx -= (tile.minW - nw); nw = tile.minW }
                if (nh < tile.minH) { if (onTop)  ny -= (tile.minH - nh); nh = tile.minH }

                tile.x = nx
                tile.y = ny
                tile.width = nw
                tile.height = nh
            }
        }

        Grip { anchors.left: parent.left;  anchors.top: parent.top;       onLeft: true;  onTop: true }
        Grip { anchors.right: parent.right; anchors.top: parent.top;      onLeft: false; onTop: true }
        Grip { anchors.left: parent.left;  anchors.bottom: parent.bottom; onLeft: true;  onTop: false }
        Grip { anchors.right: parent.right; anchors.bottom: parent.bottom; onLeft: false; onTop: false }
    }
}

