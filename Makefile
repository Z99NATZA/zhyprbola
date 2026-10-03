.PHONY: run run-panel dock dock-enable check build

QMLLINT := $(shell command -v qmllint || command -v /usr/lib/qt6/bin/qmllint)

build:
	@mkdir -p build
	@cd build && qmake6 ../zhyprbola.pro && $(MAKE)

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
