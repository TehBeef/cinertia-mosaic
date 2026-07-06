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
                          : finder.sources.length + " found"
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
                        width: sourceList.width
                        height: 34
                        radius: 3
                        color: viewer.sourceName === modelData ? "#22303e"
                             : hover.hovered ? "#1c1c20" : "transparent"
                        border.width: 1
                        border.color: viewer.sourceName === modelData
                                      ? "#3d7eff" : "#26262b"

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 10
                            text: parent.modelData
                            color: "#d8d8dc"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }

                        HoverHandler { id: hover }
                        TapHandler {
                            onTapped: viewer.sourceName = parent.modelData
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

        // ------------------------------------------------- viewer area
        Rectangle {
            id: viewerArea
            width: parent.width - sidebar.width
            height: parent.height
            color: "#0e0e10"
            clip: true // zoomed/rotated video must not spill outside

            property bool cropMode: false

            VideoView {
                id: viewer
                anchors.fill: parent
                anchors.margins: 12
            }

            HoverHandler { id: areaHover }

            Text {
                anchors.centerIn: parent
                visible: viewer.sourceName === ""
                text: "Select an NDI® source on the left"
                color: "#5a5a60"
                font.pixelSize: 16
            }

            // Small reusable toolbar button.
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

            // Hover-reveal toolbar (minimal chrome: gets out of the way).
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
                visible: viewer.sourceName !== ""
                opacity: (areaHover.hovered || viewerArea.cropMode) ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150 } }

                Row {
                    id: toolRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(viewer.zoomLevel * 100) + "%"
                        color: "#8a8a90"
                        font.pixelSize: 11
                        rightPadding: 6
                    }
                    ToolBtn { label: "⟲ 90";  onActivated: viewer.rotateBy(-90) }
                    ToolBtn { label: "90 ⟳";  onActivated: viewer.rotateBy(90) }
                    ToolBtn {
                        label: "Crop"
                        active: viewerArea.cropMode
                        onActivated: viewerArea.cropMode = !viewerArea.cropMode
                    }
                    ToolBtn {
                        label: "Clear crop"
                        visible: viewer.cropped
                        onActivated: viewer.clearCrop()
                    }
                    ToolBtn { label: "Reset"; onActivated: { viewerArea.cropMode = false; viewer.resetView() } }
                }
            }

            // Crop mode: drag a rectangle over the video to set the crop.
            MouseArea {
                id: cropArea
                anchors.fill: viewer
                visible: viewerArea.cropMode
                cursorShape: Qt.CrossCursor
                property point start: Qt.point(0, 0)
                property rect sel: Qt.rect(0, 0, 0, 0)

                onPressed: mouse => {
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
                        viewer.applyCropFromItemRect(Qt.rect(sel.x, sel.y, sel.width, sel.height))
                    sel = Qt.rect(0, 0, 0, 0)
                    viewerArea.cropMode = false
                }

                Rectangle {
                    anchors.fill: parent
                    color: "#00000055"
                }
                Rectangle {
                    x: cropArea.sel.x
                    y: cropArea.sel.y
                    width: cropArea.sel.width
                    height: cropArea.sel.height
                    color: "#3d7eff18"
                    border.width: 1
                    border.color: "#3d7eff"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 60
                    text: "Drag to select the crop area — Esc to cancel"
                    color: "#d8d8dc"
                    font.pixelSize: 13
                }
            }

            Shortcut {
                sequence: "Escape"
                enabled: viewerArea.cropMode
                onActivated: viewerArea.cropMode = false
            }

            // Status strip: source name, interaction hints, stream info.
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 26
                color: "#141417cc"
                visible: viewer.sourceName !== ""

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    text: viewer.sourceName
                    color: "#d8d8dc"
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
                Text {
                    anchors.centerIn: parent
                    text: "Scroll = zoom · Drag = pan · Ctrl+scroll = rotate · Double-click = reset"
                    color: "#5a5a60"
                    font.pixelSize: 10
                    visible: areaHover.hovered
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    text: viewer.status
                    color: "#8a8a90"
                    font.pixelSize: 11
                }
            }
        }
    }
}
