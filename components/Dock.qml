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
        // Same glass style as ClockWeatherCard
        // --------------------------------------------------

        property color glassColor:
            Qt.rgba(0.22, 0.17, 0.25, 0.84)

        property color borderColor:
            Qt.rgba(1, 1, 1, 0.24)

        property real cornerRadius:
            22

        property real rimStrength:
            0.20

        property int rimSize:
            4

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
        // Glass body
        // ==================================================

        Rectangle {
            anchors.fill: parent

            radius:
                dock.cornerRadius

            color:
                dock.glassColor

            border.width:
                1

            border.color:
                dock.borderColor

            // --------------------------------------------------
            // Soft glass gradient
            // --------------------------------------------------

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1

                radius:
                    parent.radius - 1

                gradient: Gradient {
                    GradientStop {
                        position: 0.0

                        color:
                            Qt.rgba(
                                1,
                                1,
                                1,
                                0.07
                            )
                    }

                    GradientStop {
                        position: 0.50

                        color:
                            Qt.rgba(
                                1,
                                1,
                                1,
                                0.01
                            )
                    }

                    GradientStop {
                        position: 1.0

                        color:
                            Qt.rgba(
                                1,
                                1,
                                1,
                                0.03
                            )
                    }
                }
            }

            // --------------------------------------------------
            // Inner rim
            // --------------------------------------------------

            Repeater {
                model:
                    dock.rimSize

                delegate: Rectangle {
                    required property int index

                    anchors.fill:
                        parent

                    anchors.margins:
                        1 + index

                    radius:
                        Math.max(
                            0,
                            dock.cornerRadius
                                - 1
                                - index
                        )

                    color:
                        "transparent"

                    border.width:
                        1

                    border.color:
                        Qt.rgba(
                            1,
                            1,
                            1,
                            dock.rimStrength
                                * Math.pow(
                                    1
                                        - index
                                        / dock.rimSize,
                                    2
                                )
                        )
                }
            }

            // --------------------------------------------------
            // Moving sheen
            // --------------------------------------------------

            Rectangle {
                id: sheen

                property real p:
                    0

                anchors.fill:
                    parent

                anchors.margins:
                    1

                radius:
                    parent.radius - 1

                gradient: Gradient {
                    orientation:
                        Gradient.Horizontal

                    GradientStop {
                        position: 0.0

                        color:
                            "transparent"
                    }

                    GradientStop {
                        position:
                            Math.max(
                                0.01,
                                Math.min(
                                    0.99,
                                    sheen.p
                                )
                            )

                        color:
                            Qt.rgba(
                                1,
                                1,
                                1,
                                0.12
                                    * Math.sin(
                                        Math.PI
                                            * sheen.p
                                    )
                            )
                    }

                    GradientStop {
                        position: 1.0

                        color:
                            "transparent"
                    }
                }

                SequentialAnimation on p {
                    loops:
                        Animation.Infinite

                    PauseAnimation {
                        duration:
                            5000
                    }

                    NumberAnimation {
                        from: 0
                        to: 1

                        duration:
                            1800

                        easing.type:
                            Easing.InOutSine
                    }
                }
            }
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
                    "#F6ADB2"
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

                gradient: Gradient {
                    GradientStop {
                        position:
                            0.0

                        color:
                            "#FFC0C0"
                    }

                    GradientStop {
                        position:
                            1.0

                        color:
                            "#EF858C"
                    }
                }
            }

            // subtle highlight

            Rectangle {
                x: 5
                y: 10

                width:
                    30

                height:
                    2

                radius:
                    1

                color:
                    Qt.rgba(
                        1,
                        1,
                        1,
                        0.14
                    )
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

                    border.width:
                        1

                    border.color:
                        Qt.rgba(
                            1,
                            1,
                            1,
                            0.14
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
