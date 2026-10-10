QT += quick qml network dbus testlib
CONFIG += console testcase c++17
CONFIG -= app_bundle
TARGET = connection-actions-test
SOURCES += connection-actions.test.cpp ../components/Backend.cpp
HEADERS += ../components/Backend.h
