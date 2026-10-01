import QtQuick

Image {
    property string name: ""

    width: 52
    height: 52
    source: Qt.resolvedUrl("icons/" + name.toLowerCase() + ".png")
    sourceSize.width: 156
    sourceSize.height: 156
    fillMode: Image.PreserveAspectFit
    smooth: true
    mipmap: true
}
