// Dark-theme hello-world window. Uses the real Mosaic palette so this is a
// genuine preview of the app's shell on macOS:
//   background #0e0e10, accent #3d7eff, text #d8d8dc / dim #8a8a90.
import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: window
    visible: true
    width: 720
    height: 460
    minimumWidth: 480
    minimumHeight: 320
    title: "Mosaic — macOS port"
    color: "#0e0e10"
    flags: stayOnTop ? (Qt.Window | Qt.WindowStaysOnTopHint) : Qt.Window

    // Subtle centered card with a thin accent border — the flat, minimal-chrome
    // look called for in the brief.
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 520)
        height: 260
        radius: 10
        color: "#141417"
        border.color: "#2a2a2e"
        border.width: 1

        // Which RHI backend Qt Quick actually chose. GraphicsInfo is an attached
        // property on an Item (this card), and updates once the scene graph is
        // initialised. On macOS this should read "Metal" — our confirmation the
        // GPU render path is live. (Same code will report Direct3D on Windows.)
        readonly property string backend: {
            switch (GraphicsInfo.api) {
            case GraphicsInfo.Metal:      return "Metal"
            case GraphicsInfo.OpenGL:     return "OpenGL"
            case GraphicsInfo.Vulkan:     return "Vulkan"
            case GraphicsInfo.Direct3D11: return "Direct3D 11"
            case GraphicsInfo.Direct3D12: return "Direct3D 12"
            case GraphicsInfo.Software:   return "Software"
            default:                      return "initialising…"
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 14
            width: parent.width - 64

            // Accent bar, like an active-tile highlight.
            Rectangle {
                width: 44; height: 4; radius: 2
                color: "#3d7eff"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Mosaic"
                color: "#e8e8ea"
                font.pixelSize: 40
                font.weight: Font.DemiBold
                font.letterSpacing: 1
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "macOS port · milestone 8 · hello world"
                color: "#8a8a90"
                font.pixelSize: 14
            }

            Rectangle { // hairline divider
                width: parent.width; height: 1; color: "#2a2a2e"
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                text: "Qt " + qtVersion + "   ·   render backend: " + card.backend
                color: "#5a5a60"
                font.pixelSize: 12
            }
        }
    }

    // NDI® trademark line kept visible even in the hello-world, per the license
    // notes in the project brief — good habit to carry from the start.
    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 12
        text: "NDI® is a registered trademark of Vizrt NDI AB."
        color: "#3a3a3f"
        font.pixelSize: 10
    }
}
