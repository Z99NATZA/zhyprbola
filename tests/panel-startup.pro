QT += quick qml network dbus testlib
CONFIG += console testcase c++17
CONFIG -= app_bundle
TARGET = panel-startup-test
DESTDIR = ..
SOURCES += panel-startup.test.cpp ../components/Backend.cpp ../components/SoundBackend.cpp ../components/ScreenshotBackend.cpp
HEADERS += ../components/Backend.h ../components/SoundBackend.h ../components/ScreenshotBackend.h
