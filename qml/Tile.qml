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
    readonly property string status: video.status

    signal closeRequested()
    signal selectRequested()

    width: 480
    height: 270

    readonly property int minW: 160
    readonly property int minH: 90

    function snap(v) { return Math.round(v / gridSize) * gridSize }

    Rectangle {
        anchors.fill: parent
        color: "#101013"
        border.width: 1
        border.color: tile.selected ? "#3d7eff" : "#26262b"
        clip: true // video must never draw outside its tile

        // Shared move-the-tile drag logic. The body instance sits under the
        // video: it receives drags when the video is at fit zoom (nothing
        // to pan), so grabbing a tile anywhere moves it.
        component MoveArea: MouseArea {
            property point pressPos
            onPressed: mouse => {
                tile.selectRequested()
                pressPos = Qt.point(mouse.x, mouse.y)
            }
            onPositionChanged: mouse => {
                if (!pressed)
                    return
                let nx = tile.x + mouse.x - pressPos.x
                let ny = tile.y + mouse.y - pressPos.y
                if (tile.snapEnabled || (mouse.modifiers & Qt.ControlModifier)) {
                    nx = tile.snap(nx)
                    ny = tile.snap(ny)
                }
                tile.x = Math.max(0, Math.min(nx, tile.parent.width - tile.width))
                tile.y = Math.max(0, Math.min(ny, tile.parent.height - tile.height))
            }
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
            onInteracted: tile.selectRequested()
        }

        HoverHandler { id: tileHover }

        component TileBtn: Rectangle {
            property string label
            property bool active: false
            signal activated()
            width: btnText.width + 10
            height: 18
            radius: 2
            color: active ? "#22303e" : btnHover.hovered ? "#2a2a30" : "transparent"
            border.width: active ? 1 : 0
            border.color: "#3d7eff"
            Text {
                id: btnText
                anchors.centerIn: parent
                text: parent.label
                color: "#d8d8dc"
                font.pixelSize: 11
            }
            HoverHandler { id: btnHover }
            TapHandler { onTapped: parent.activated() }
        }

        // Hover header: drag to move the tile; per-tile controls right.
        Rectangle {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 1
            height: 24
            color: "#1a1a1ee6"
            opacity: (tileHover.hovered || moveArea.pressed) ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 120 } }

            MoveArea {
                id: moveArea
                anchors.fill: parent
                cursorShape: Qt.SizeAllCursor
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 8
                width: parent.width - controls.width - 24
                text: tile.sourceName
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

                TileBtn { label: "⟲"; onActivated: video.rotateBy(-90) }
                TileBtn { label: "⟳"; onActivated: video.rotateBy(90) }
                TileBtn {
                    label: "Crop"
                    active: tile.cropMode
                    onActivated: tile.cropMode = !tile.cropMode
                }
                TileBtn {
                    label: "Fit"
                    onActivated: { tile.cropMode = false; video.resetView() }
                }
                TileBtn { label: "✕"; onActivated: tile.closeRequested() }
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

                if (tile.snapEnabled || (mouse.modifiers & Qt.ControlModifier)) {
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
