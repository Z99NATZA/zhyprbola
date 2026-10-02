.PHONY: run run-panel check build

QMLLINT := $(shell command -v qmllint || command -v /usr/lib/qt6/bin/qmllint)

build:
	@mkdir -p build
	@cd build && qmake6 ../zpola.pro && $(MAKE)

run: build
	./build/zpola

run-panel: build
	./scripts/run-panel bluetooth

check:
	@for file in Main.qml PanelHost.qml components/*.qml; do $(QMLLINT) "$$file" || exit 1; done
