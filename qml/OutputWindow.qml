import QtQuick

// One extra output canvas in its own window (multi-monitor mode). The
// chrome bar appears only when the mouse is near the top edge, so a
// fullscreen output looks like a clean multiviewer feed. All state that
// must persist (name, monitor, fullscreen) lives in the main window's
// output model — the buttons here only emit signals, and the model
// writes flow back in through the properties.
Window {
    id: out
    width: 960
    height: 540
    minimumWidth: 480
    minimumHeight: 270
    color: "#0e0e10"
    visible: true
    title: outputName + " — Mosaic"

    property string outputName: "Output"
    property bool fullscreenOn: false
    property int screenIndex: 0
    // True while sidebar source clicks land on this canvas.
    property bool isTarget: false

    // Shared app settings, passed straight through to the canvas.
    property bool snapOn: false
    property bool wheelRotateOn: true
    property bool showTileNames: true
    property int tileGap: 8
    property var availableSources: []

    readonly property alias canvas: tc

    signal closeRequested()
    signal fullscreenToggled(bool on)
    signal screenPicked(int index)
    signal targetRequested()
    signal tilesMutated()

    // Set while the whole app quits: closing then must NOT delete this
    // output from the session that was just saved.
    property bool appQuitting: false
    onClosing: {
        if (!appQuitting)
            closeRequested()
    }

    // Fullscreen dance mirrors the main window: dip through windowed when
    // moving between monitors, restore the windowed geometry afterwards.
    property rect savedGeom: Qt.rect(0, 0, 0, 0)

    // The windowed geometry worth saving in the session, even while the
    // output is currently fullscreen.
    function windowedRect() {
        return (visibility === Window.FullScreen && savedGeom.width > 200)
            ? savedGeom : Qt.rect(x, y, width, height)
    }

    onFullscreenOnChanged: Qt.callLater(applyMode)
    onScreenIndexChanged: {
        if (fullscreenOn)
            Qt.callLater(applyMode)
    }
    Component.onCompleted: {
        if (fullscreenOn)
            Qt.callLater(applyMode)
    }

    function applyMode() {
        if (visibility !== Window.FullScreen && width > 200)
            savedGeom = Qt.rect(x, y, width, height)
        if (fullscreenOn) {
            if (visibility === Window.FullScreen)
                visibility = Window.Windowed
            const screens = Qt.application.screens
            out.screen = screens[Math.min(screenIndex, screens.length - 1)]
            visibility = Window.FullScreen
        } else {
            visibility = Window.Windowed
            if (savedGeom.width > 200) {
                x = savedGeom.x
                y = savedGeom.y
                width = savedGeom.width
                height = savedGeom.height
            }
        }
    }

    // Each output window handles its own keys: Esc cancels tile overlays
    // first, then leaves fullscreen; F11 toggles fullscreen.
    Item {
        id: outKeys
        focus: true
        Keys.onEscapePressed: {
            if (!tc.cancelOverlays() && out.fullscreenOn)
                out.fullscreenToggled(false)
        }
        Keys.onPressed: event => {
            if (event.key === Qt.Key_F11) {
                out.fullscreenToggled(!out.fullscreenOn)
                event.accepted = true
            }
        }
    }

    TileCanvas {
        id: tc
        anchors.fill: parent
        snapEnabled: out.snapOn
        wheelRotate: out.wheelRotateOn
        globalShowName: out.showTileNames
        tileGap: out.tileGap
        availableSources: out.availableSources
        focusTarget: outKeys
        emptyHint: out.isTarget
            ? "This canvas is receiving — click sources in the main window to add them here"
            : "Empty canvas — pick it under CANVASES in the main window (or use “Send sources here” at the top edge), then click sources"
        onTilesMutated: out.tilesMutated()
    }

    // Top-edge hover zone reveals the output chrome.
    Item {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 44
        HoverHandler { id: topZone }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 34
        color: "#141417ee"
        visible: opacity > 0
        // Both handlers: the zone alone flickered — once the bar is up,
        // its buttons' own hover handling can take the hover away from
        // the zone behind, hiding the bar mid-click. The bar's own
        // handler keeps it pinned while the mouse is anywhere on it.
        opacity: (topZone.hovered || chromeHover.hovered) ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        HoverHandler { id: chromeHover }

        component OutBtn: Rectangle {
            property string label
            property bool active: false
            signal activated()
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(obText.width + 14, 24)
            height: 24
            radius: 3
            color: active ? "#22303e" : obHover.hovered ? "#2a2a30" : "transparent"
            border.width: active ? 1 : 0
            border.color: "#3d7eff"

            Text {
                id: obText
                anchors.centerIn: parent
                text: parent.label
                color: "#d8d8dc"
                font.pixelSize: 11
            }
            HoverHandler { id: obHover }
            TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: parent.activated() }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 10
            text: out.outputName
            color: "#e8e8ea"
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 8
            spacing: 4

            OutBtn {
                label: out.isTarget ? "● Receiving sources" : "Send sources here"
                active: out.isTarget
                onActivated: out.targetRequested()
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: Qt.application.screens.length > 1
                text: "  Monitor"
                color: "#5a5a60"
                font.pixelSize: 10
            }
            Repeater {
                model: Qt.application.screens.length > 1
                       ? Qt.application.screens.length : 0

                OutBtn {
                    required property int index
                    label: String(index + 1)
                    active: out.screenIndex === index
                    onActivated: out.screenPicked(index)
                }
            }
            OutBtn {
                label: out.fullscreenOn ? "Windowed" : "Fullscreen"
                onActivated: out.fullscreenToggled(!out.fullscreenOn)
            }
            OutBtn {
                label: "✕"
                onActivated: out.closeRequested()
            }
        }
    }
}
