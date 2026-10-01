.PHONY: run check

QMLLINT := $(shell command -v qmllint || command -v /usr/lib/qt6/bin/qmllint)

run:
	qml6 Main.qml

check:
	@for file in Main.qml components/*.qml; do $(QMLLINT) "$$file" || exit 1; done
