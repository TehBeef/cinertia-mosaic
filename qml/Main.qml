import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: window
    width: 1280
    height: 720
    visible: true
    title: "Mosaic"
    color: "#0e0e10"

    // Dark theme shell — Milestone 1. This becomes the multiviewer canvas later.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 12
        color: "#141417"
        border.color: "#2a2a2e"
        border.width: 1
        radius: 4

        Column {
            anchors.centerIn: parent
            spacing: 8

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Mosaic"
                color: "#e8e8ea"
                font.pixelSize: 28
                font.weight: Font.DemiBold
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Milestone 1 — environment check passed"
                color: "#8a8a90"
                font.pixelSize: 14
            }
        }
    }
}
