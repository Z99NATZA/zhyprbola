import QtQuick

Image {
    width: 24
    height: 24
    source: Qt.resolvedUrl("../gnome-extension/icons/music.svg")
    sourceSize: Qt.size(width * 2, height * 2)
    fillMode: Image.PreserveAspectFit
    smooth: true
}
