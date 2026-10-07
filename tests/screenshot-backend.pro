QT = core gui quick qml testlib
CONFIG += console testcase c++17
CONFIG -= app_bundle
TARGET = screenshot-backend-test
SOURCES += screenshot-backend.test.cpp ../components/ScreenshotBackend.cpp
HEADERS += ../components/ScreenshotBackend.h
