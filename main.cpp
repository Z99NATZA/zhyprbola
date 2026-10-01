#include "components/Backend.h"

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDir>
#include <QFileInfo>

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    Backend backend;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
    const QString qmlFile = app.arguments().size() > 1
        ? QFileInfo(app.arguments().at(1)).absoluteFilePath()
        : QDir(app.applicationDirPath()).absoluteFilePath(QStringLiteral("../Main.qml"));
    engine.load(QUrl::fromLocalFile(qmlFile));
    if (engine.rootObjects().isEmpty())
        return 1;
    return app.exec();
}
