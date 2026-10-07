QT += quick qml network dbus testlib
CONFIG += console testcase c++17
CONFIG -= app_bundle
TARGET = key-visualizer-test
SOURCES += key-visualizer.test.cpp ../components/Backend.cpp ../components/SoundBackend.cpp
HEADERS += ../components/Backend.h ../components/SoundBackend.h
