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

        property color surfaceColor: Theme.cardSurface


        property color accentColor: Theme.accent

        property color dimColor:
            Qt.alpha(textColor, 0.75)

        property real cornerRadius:
            26



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
        // Flat surface
        // ==================================================

        Rectangle {
            anchors.fill: parent
            radius: card.cornerRadius
            color: card.surfaceColor
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
