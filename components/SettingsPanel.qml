import QtQuick

Item {
    id: panel

    width: 560
    height: 420
    property string section: "themes"
    signal closeRequested()

    readonly property var sections: [
        {key: "themes", label: "Themes"},
        {key: "dock", label: "Dock"},
        {key: "groups", label: "Groups"},
        {key: "spectrum", label: "Spectrum"},
        {key: "wallpaper", label: "Wallpaper"}
    ]
    readonly property var themes: [
        {key: "current", label: "Purple", accent: "#875A82"},
        {key: "white", label: "White Mist", accent: "#467B9D"},
        {key: "white-sky", label: "White Sky", accent: "#1E73E7"},
        {key: "forest", label: "Forest Calm", accent: "#477F6D"},
        {key: "one-half-gray", label: "One Half Gray", accent: "#68717D"},
        {key: "red", label: "Red", accent: "#B83252"}
    ]
    readonly property var positions: [
        {key: "left", label: "Left"},
        {key: "right", label: "Right"},
        {key: "top", label: "Top"},
        {key: "bottom", label: "Bottom"}
    ]
    readonly property var groupLabels: ({
        apps: "Apps", zhyprbola: "Zhyprbola", running: "Running"
    })
    readonly property var groupPlaces: backend.dockPosition === "left"
        || backend.dockPosition === "right"
        ? ["Top", "Center", "Bottom"] : ["Left", "Center", "Right"]

    Rectangle {
        anchors.fill: parent
        radius: 22
        color: Theme.panelSurface
    }

    Rectangle {
        x: 12
        y: 12
        width: 150
        height: parent.height - 24
        radius: 15
        color: Theme.control

        Text {
            x: 15
            y: 17
            text: "Settings"
            color: Theme.text
            font.family: Qt.application.font.family
            font.pixelSize: 19
            font.weight: Font.DemiBold
        }

        Column {
            x: 8
            y: 60
            width: parent.width - 16
            spacing: 5

            Repeater {
                model: panel.sections

                delegate: Rectangle {
                    required property var modelData
                    width: 134
                    height: 40
                    radius: 10
                    color: panel.section === modelData.key
                        ? Theme.accent
                        : (navMouse.containsMouse ? Theme.controlHover : "transparent")

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 13
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: panel.section === modelData.key
                            ? Theme.accentText : Theme.text
                        font.family: Qt.application.font.family
                        font.pixelSize: 14
                        font.weight: panel.section === modelData.key
                            ? Font.DemiBold : Font.Normal
                    }

                    MouseArea {
                        id: navMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.section = modelData.key
                    }
                }
            }
        }
    }

    Text {
        x: 184
        y: 29
        text: panel.section === "themes" ? "Themes"
            : (panel.section === "dock" ? "Dock position"
            : (panel.section === "groups" ? "Dock groups"
            : (panel.section === "spectrum" ? "Edge spectrum" : "Wallpaper")))
        color: Theme.text
        font.family: Qt.application.font.family
        font.pixelSize: 20
        font.weight: Font.DemiBold
    }

    Rectangle {
        x: parent.width - 45
        y: 20
        width: 29
        height: 29
        radius: 9
        color: closeMouse.containsMouse ? Theme.controlHover : Theme.control

        Text {
            anchors.centerIn: parent
            text: "×"
            color: Theme.text
            font.family: Qt.application.font.family
            font.pixelSize: 20
        }

        MouseArea {
            id: closeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: panel.closeRequested()
        }
    }

    Column {
        x: 184
        y: 76
        width: 358
        spacing: 7
        visible: panel.section === "themes"

        Repeater {
            model: panel.themes

            delegate: Rectangle {
                required property var modelData
                width: 358
                height: 44
                radius: 11
                color: backend.themeName === modelData.key
                    ? Theme.selected
                    : (themeMouse.containsMouse ? Theme.controlHover : Theme.control)

                Rectangle {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 22
                    radius: 7
                    color: modelData.accent
                }

                Text {
                    x: 47
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.label
                    color: Theme.text
                    font.family: Qt.application.font.family
                    font.pixelSize: 14
                    font.weight: backend.themeName === modelData.key
                        ? Font.DemiBold : Font.Normal
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    visible: backend.themeName === modelData.key
                    text: "✓"
                    color: Theme.accent
                    font.family: Qt.application.font.family
                    font.pixelSize: 16
                    font.weight: Font.Bold
                }

                MouseArea {
                    id: themeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: backend.setThemeName(modelData.key)
                }
            }
        }
    }

    Column {
        x: 184
        y: 76
        width: 358
        spacing: 8
        visible: panel.section === "dock"

        Repeater {
            model: panel.positions

            delegate: Rectangle {
                required property var modelData
                width: 358
                height: 49
                radius: 11
                color: backend.dockPosition === modelData.key
                    ? Theme.selected
                    : (positionMouse.containsMouse ? Theme.controlHover : Theme.control)

                Text {
                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.label
                    color: Theme.text
                    font.family: Qt.application.font.family
                    font.pixelSize: 14
                    font.weight: backend.dockPosition === modelData.key
                        ? Font.DemiBold : Font.Normal
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    visible: backend.dockPosition === modelData.key
                    text: "✓"
                    color: Theme.accent
                    font.family: Qt.application.font.family
                    font.pixelSize: 16
                    font.weight: Font.Bold
                }

                MouseArea {
                    id: positionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: backend.setDockPosition(modelData.key)
                }
            }
        }
    }

    Column {
        x: 184
        y: 76
        width: 358
        spacing: 12
        visible: panel.section === "groups"

        Row {
            id: groupSlots
            spacing: 8

            Repeater {
                model: backend.dockGroupOrder

                delegate: Rectangle {
                    id: groupCard
                    required property string modelData
                    required property int index
                    readonly property string groupName: modelData
                    property bool dropHovered: false
                    width: 114
                    height: 90
                    radius: 11
                    color: dropHovered ? Theme.selected : Theme.control
                    border.width: dragArea.drag.active ? 2 : 0
                    border.color: Theme.accent
                    z: dragArea.drag.active ? 2 : 0
                    Drag.active: dragArea.drag.active
                    Drag.source: groupCard
                    Drag.keys: ["dock-group"]
                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2

                    Text {
                        x: 10
                        y: 9
                        text: panel.groupPlaces[groupCard.index]
                        color: Theme.secondary
                        font.family: Qt.application.font.family
                        font.pixelSize: 12
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 35
                        text: panel.groupLabels[groupCard.groupName]
                        color: Theme.text
                        font.family: Qt.application.font.family
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 9
                        y: 7
                        text: "⋮⋮"
                        color: Theme.secondary
                        font.pixelSize: 13
                    }

                    DropArea {
                        anchors.fill: parent
                        keys: ["dock-group"]
                        onEntered: groupCard.dropHovered = true
                        onExited: groupCard.dropHovered = false
                        onDropped: function(drop) {
                            groupCard.dropHovered = false
                            backend.swapDockGroups(drop.source.groupName, groupCard.groupName)
                        }
                    }

                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        drag.target: groupCard
                        drag.axis: Drag.XAxis
                        cursorShape: Qt.OpenHandCursor
                        onReleased: {
                            groupCard.Drag.drop()
                            Qt.callLater(() => {
                                groupCard.x = groupCard.index * (groupCard.width + groupSlots.spacing)
                            })
                        }
                    }
                }
            }
        }

        Text {
            text: "Show groups"
            color: Theme.secondary
            font.family: Qt.application.font.family
            font.pixelSize: 13
        }

        Repeater {
            model: ["zhyprbola", "apps", "running"]

            delegate: Rectangle {
                required property string modelData
                required property int index
                readonly property bool active: backend.dockGroups.includes(modelData)

                width: 358
                height: 48
                radius: 11
                color: active ? Theme.selected : Theme.control

                Text {
                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: panel.groupLabels[modelData]
                    color: Theme.text
                    font.family: Qt.application.font.family
                    font.pixelSize: 14
                    font.weight: active ? Font.DemiBold : Font.Normal
                }

                Rectangle {
                    x: 299
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    height: 26
                    radius: 13
                    color: active ? Theme.accent : Theme.track

                    Rectangle {
                        x: active ? 21 : 3
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        radius: 10
                        color: "#ffffff"
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: modelData !== "zhyprbola"
                        cursorShape: Qt.PointingHandCursor
                        onClicked: backend.setDockGroupEnabled(modelData, !active)
                    }
                }
            }
        }
    }

    Column {
        x: 184
        y: 76
        width: 358
        spacing: 8
        visible: panel.section === "spectrum"

        Rectangle {
            width: 358
            height: 53
            radius: 11
            color: Theme.control

            Text {
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                text: "Show edge spectrum"
                color: Theme.text
                font.family: Qt.application.font.family
                font.pixelSize: 14
            }

            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 15
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 26
                radius: 13
                color: backend.edgeSpectrumEnabled ? Theme.accent : Theme.track

                Rectangle {
                    x: backend.edgeSpectrumEnabled ? 21 : 3
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 20
                    radius: 10
                    color: "#ffffff"
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: backend.setEdgeSpectrumEnabled(!backend.edgeSpectrumEnabled)
            }
        }

        Repeater {
            model: panel.positions

            delegate: Rectangle {
                required property var modelData
                width: 358
                height: 49
                radius: 11
                color: backend.edgeSpectrumPosition === modelData.key
                    ? Theme.selected
                    : (edgePositionMouse.containsMouse ? Theme.controlHover : Theme.control)

                Text {
                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.label
                    color: Theme.text
                    font.family: Qt.application.font.family
                    font.pixelSize: 14
                    font.weight: backend.edgeSpectrumPosition === modelData.key
                        ? Font.DemiBold : Font.Normal
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    visible: backend.edgeSpectrumPosition === modelData.key
                    text: "✓"
                    color: Theme.accent
                    font.family: Qt.application.font.family
                    font.pixelSize: 16
                    font.weight: Font.Bold
                }

                MouseArea {
                    id: edgePositionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: backend.setEdgeSpectrumPosition(modelData.key)
                }
            }
        }
    }

    Rectangle {
        x: 184
        y: 76
        width: 358
        height: 64
        radius: 11
        color: Theme.control
        visible: panel.section === "wallpaper"

        Text {
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            text: "Use theme wallpaper"
            color: Theme.text
            font.family: Qt.application.font.family
            font.pixelSize: 14
        }

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 15
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            height: 26
            radius: 13
            color: backend.useWallpaper ? Theme.accent : Theme.track

            Rectangle {
                x: backend.useWallpaper ? 21 : 3
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20
                radius: 10
                color: "#ffffff"
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: backend.setUseWallpaper(!backend.useWallpaper)
        }
    }
}
