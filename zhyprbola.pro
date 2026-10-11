QT += quick qml network dbus
CONFIG += c++17
TARGET = zhyprbola
VERSION = 0.1.0
DEFINES += ZHYPRBOLA_VERSION=\\\"$$VERSION\\\"
SOURCES += main.cpp components/Backend.cpp components/SoundBackend.cpp components/ScreenshotBackend.cpp
HEADERS += components/Backend.h components/SoundBackend.h components/ScreenshotBackend.h
