import QtQuick

Item {
    id: win

    width: 420
    height: 245

    signal settingsRequested()


    // ==================================================
    // Background
    // Same tone as ClockWeatherCard
    // ==================================================


    // ==================================================
    // Moving background circles
    // ==================================================


    // ==================================================
    // App Launcher Card
    // ==================================================

    Item {
        id: card

        anchors.centerIn: parent

        width: 420
        height: 245

        // --------------------------------------------------
        // Style
        // Same values as ClockWeatherCard
        // --------------------------------------------------

        property color textColor: Theme.text

        property color glassColor: Theme.cardSurface

        property color borderColor: Theme.cardBorder

        property color accentColor: Theme.accent

        property color dimColor:
            Qt.alpha(textColor, 0.75)

        property real cornerRadius:
            26

        property real rimStrength:
            0.20

        property int rimSize:
            4

        readonly property string family:
            Qt.application.font.family

        // ==================================================
        // Intro animation
        // Same feeling as ClockWeatherCard
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
        // Card hover
        // ==================================================

        scale:
            cardHover.hovered
                ? 1.025
                : 1.0

        Behavior on scale {
            SpringAnimation {
                spring: 3
                damping: 0.28
                epsilon: 0.001
            }
        }

        HoverHandler {
            id: cardHover
        }

        // ==================================================
        // Glass body
        // ==================================================

        Rectangle {
            anchors.fill: parent

            radius:
                card.cornerRadius

            color:
                card.glassColor

            border.width:
                1

            border.color:
                card.borderColor

            // --------------------------------------------------
            // Glass soft gradient
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
                    card.rimSize

                delegate: Rectangle {
                    required property int index

                    anchors.fill:
                        parent

                    anchors.margins:
                        1 + index

                    radius:
                        Math.max(
                            0,
                            card.cornerRadius
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
                            card.rimStrength
                                * Math.pow(
                                    1
                                        - index
                                        / card.rimSize,
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

        Grid {
            id: appGrid

            anchors.centerIn:
                parent

            columns:
                4

            columnSpacing:
                22

            rowSpacing:
                14

            LauncherApp {
                name: "Code"
            }

            LauncherApp {
                name: "Browser"
            }

            LauncherApp {
                name: "Terminal"
            }

            LauncherApp {
                name: "Files"
            }

            LauncherApp {
                name: "Docker"
            }

            LauncherApp {
                name: "Git"
            }

            LauncherApp {
                name: "Music"
            }

            LauncherApp {
                name: "Settings"
            }
        }
    }

    // ==================================================
    // App component
    // ==================================================

    component LauncherApp: Item {
        id: app

        property string name:
            "App"
        readonly property bool available: name === "Settings" || backend.appAvailable(name)

        opacity: available ? 1 : 0.45

        width:
            76

        height:
            88

        // --------------------------------------------------
        // Hover
        //
        // Only scale.
        // Do NOT change y because Grid position should stay
        // stable.
        // --------------------------------------------------

        scale:
            appHover.hovered
                ? 1.045
                : 1.0

        Behavior on scale {
            SpringAnimation {
                spring: 3
                damping: 0.28
                epsilon: 0.001
            }
        }

        // ==================================================
        // Icon
        // ==================================================

        Item {
            id: iconWrap

            anchors {
                horizontalCenter:
                    parent.horizontalCenter

                top:
                    parent.top

                topMargin:
                    5
            }

            width:
                52

            height:
                52

            Rectangle {
                anchors.fill: parent
                radius: 14
                color: Qt.rgba(1, 1, 1, appHover.hovered ? 0.09 : 0)
            }

            AppIcon {
                anchors.fill: parent
                name: app.name
            }
        }

        // ==================================================
        // App name
        // ==================================================

        Text {
            anchors {
                horizontalCenter:
                    parent.horizontalCenter

                top:
                    iconWrap.bottom

                topMargin:
                    7
            }

            width:
                parent.width

            horizontalAlignment:
                Text.AlignHCenter

            text:
                app.name

            color:
                card.textColor

            opacity:
                appHover.hovered
                    ? 1.0
                    : 0.90

            Behavior on opacity {
                NumberAnimation {
                    duration:
                        150
                }
            }

            elide:
                Text.ElideRight

            font {
                family:
                    card.family

                pixelSize:
                    13

                weight:
                    Font.Medium
            }
        }

        HoverHandler {
            id: appHover
        }

        MouseArea {
            anchors.fill:
                parent

            enabled: app.available
            cursorShape:
                Qt.PointingHandCursor
            onClicked: {
                if (app.name === "Settings") {
                    win.settingsRequested()
                } else {
                    backend.launchApp(app.name)
                }
            }
        }
    }
}
