.PHONY: run run-panel dock dock-enable check build

QMLLINT := $(shell command -v qmllint || command -v /usr/lib/qt6/bin/qmllint)

build: build/key-capture-evdev
	@mkdir -p build
	@cd build && qmake6 ../zhyprbola.pro && $(MAKE)

build/key-capture-evdev: scripts/key-capture-evdev.cpp
	@mkdir -p build
	$(CXX) -std=c++17 -O2 -Wall -Wextra -DQT_NO_KEYWORDS $(shell pkg-config --cflags Qt6Core gio-2.0 xkbcommon) $< -o $@ $(shell pkg-config --libs Qt6Core gio-2.0 xkbcommon)

run: build
	./build/zhyprbola

run-panel: build
	./scripts/run-panel bluetooth

dock: build
	./scripts/install-extension
	./scripts/enable-dock

dock-enable:
	./scripts/enable-dock

check:
	@for file in Main.qml PanelHost.qml EdgeSpectrum.qml components/*.qml; do $(QMLLINT) "$$file" || exit 1; done
