.PHONY: run check build

QMLLINT := $(shell command -v qmllint || command -v /usr/lib/qt6/bin/qmllint)

build:
	@mkdir -p build
	@cd build && qmake6 ../zpola.pro && $(MAKE)

run: build
	./build/zpola

check:
	@for file in Main.qml components/*.qml; do $(QMLLINT) "$$file" || exit 1; done
