import QtQuick

Text {
    id: popText

    property bool animate: false

    onTextChanged: {
        if (animate)
            pop.restart();
    }

    ParallelAnimation {
        id: pop

        NumberAnimation {
            target: popText
            property: "opacity"
            from: 0.3
            to: 1
            duration: 350
        }

        NumberAnimation {
            target: popText
            property: "scale"
            from: 0.9
            to: 1
            duration: 450
            easing.type: Easing.OutBack
        }
    }
}
