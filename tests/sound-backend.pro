QT = core testlib
CONFIG += console testcase c++17
CONFIG -= app_bundle
TARGET = sound-backend-test
SOURCES += sound-backend.test.cpp ../components/SoundBackend.cpp
HEADERS += ../components/SoundBackend.h
