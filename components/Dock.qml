import QtQuick

Item {
    id: win

    width: 600
    height: 124


    // ==================================================
    // Background
    // ==================================================


    // ==================================================
    // Moving background circles
    // ==================================================


    // ==================================================
    // Dock
    // ==================================================

    Item {
        id: dock

        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: 26
        }

        width: 560
        height: 72

        // --------------------------------------------------
        // Flat surface
        // --------------------------------------------------

        property color surfaceColor: Theme.cardSurface


        property real cornerRadius:
            22



        // ==================================================
        // Intro animation
        // ==================================================

        opacity: 0

        transform: Translate {
            id: enterTransform
            y: 14
        }

        NumberAnimation on opacity {
            from: 0
            to: 1

            duration: 600

            easing.type:
                Easing.OutCubic
        }

        NumberAnimation {
            target: enterTransform
            property: "y"

            from: 14
            to: 0

            duration: 700

            easing.type:
                Easing.OutCubic

            running: true
        }

        // ==================================================
        // Dock hover
        // ==================================================

        scale:
            dockHover.hovered
                ? 1.02
                : 1.0

        Behavior on scale {
            SpringAnimation {
                spring: 3
                damping: 0.28
                epsilon: 0.001
            }
        }

        HoverHandler {
            id: dockHover
        }

        // ==================================================
        // Flat surface
        // ==================================================

        Rectangle {
            anchors.fill: parent
            radius: dock.cornerRadius
            color: dock.surfaceColor
        }

        // ==================================================
        // Apps
        // ==================================================

        Row {
            id: appRow

            anchors.centerIn:
                parent

            spacing:
                18

            Repeater {
                model:
                    7

                delegate:
                    DockIcon { }
            }

            LauncherIcon { }
        }
    }

    // ==================================================
    // Reusable Placeholder App
    // ==================================================

    component DockIcon: Item {
        id: icon

        width:
            48

        height:
            48

        scale:
            iconHover.hovered
                ? 1.07
                : 1.0

        Behavior on scale {
            SpringAnimation {
                spring: 3
                damping: 0.28
                epsilon: 0.001
            }
        }

        // ==================================================
        // Placeholder folder icon
        // ==================================================

        Item {
            anchors.centerIn:
                parent

            width:
                38

            height:
                32

            // folder tab

            Rectangle {
                x: 4
                y: 1

                width:
                    17

                height:
                    8

                radius:
                    4

                color:
                    Theme.accent
            }

            // folder body

            Rectangle {
                x: 2
                y: 7

                width:
                    36

                height:
                    24

                radius:
                    7

                color:
                    Theme.accent
            }
        }

        HoverHandler {
            id: iconHover
        }

        MouseArea {
            anchors.fill:
                parent

            cursorShape:
                Qt.PointingHandCursor
        }
    }

    // ==================================================
    // Launcher
    // ==================================================

    component LauncherIcon: Item {
        id: launcher

        width:
            48

        height:
            48

        scale:
            launcherHover.hovered
                ? 1.07
                : 1.0

        Behavior on scale {
            SpringAnimation {
                spring: 3
                damping: 0.28
                epsilon: 0.001
            }
        }

        Grid {
            anchors.centerIn:
                parent

            columns:
                2

            spacing:
                5

            Repeater {
                model:
                    4

                delegate: Rectangle {
                    width:
                        11

                    height:
                        11

                    radius:
                        3.5

                    color:
                        Qt.rgba(
                            1,
                            1,
                            1,
                            0.82
                        )

                }
            }
        }

        HoverHandler {
            id: launcherHover
        }

        MouseArea {
            anchors.fill:
                parent

            cursorShape:
                Qt.PointingHandCursor
        }
    }
}
