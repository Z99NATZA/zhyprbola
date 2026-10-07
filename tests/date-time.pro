QT += quick qml network dbus testlib
CONFIG += console testcase c++17
CONFIG -= app_bundle
TARGET = date-time-test
SOURCES += date-time.test.cpp ../components/Backend.cpp
HEADERS += ../components/Backend.h
