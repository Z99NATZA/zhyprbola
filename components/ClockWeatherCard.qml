import QtQuick

Rectangle {
    id: card

    property string componentKey: ""
    property bool ready: false
    readonly property color textColor: Theme.text
    readonly property color dimColor: Qt.alpha(textColor, 0.75)
    readonly property string family: Qt.application.font.family

    radius: 26
    color: Theme.componentSurfaceFor(componentKey)
    border.width: borderMenu.borderVisible ? 1 : 0
    border.color: borderMenu.borderColor
    Component.onCompleted: ready = true

    CardBorderMenu {
        id: borderMenu
        componentKey: card.componentKey
    }

    transform: Translate {
        id: enterTransform
    }
    NumberAnimation on opacity {
        from: 0
        to: 1
        duration: 600
        easing.type: Easing.OutCubic
    }
    NumberAnimation {
        target: enterTransform
        property: "y"
        from: 14
        to: 0
        duration: 700
        easing.type: Easing.OutCubic
        running: true
    }
}
