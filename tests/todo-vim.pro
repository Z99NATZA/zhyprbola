QT += quick qml network dbus testlib
CONFIG += console testcase c++17
CONFIG -= app_bundle
TARGET = todo-vim-test
SOURCES += todo-vim.test.cpp ../components/Backend.cpp
HEADERS += ../components/Backend.h
