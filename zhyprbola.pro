QT += quick qml network dbus
CONFIG += c++17
TARGET = zhyprbola
SOURCES += main.cpp components/Backend.cpp components/SoundBackend.cpp components/ScreenshotBackend.cpp
HEADERS += components/Backend.h components/SoundBackend.h components/ScreenshotBackend.h
