#include "components/Backend.h"

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDir>
#include <QFileInfo>
#include <QCommandLineParser>

namespace {
int environmentInt(const char *name, int fallback) {
    bool valid = false;
    const int value = qEnvironmentVariableIntValue(name, &valid);
    return valid && value > 0 ? value : fallback;
}
}

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    app.setOrganizationName(QStringLiteral("zhyprbola"));
    app.setApplicationName(QStringLiteral("Zhyprbola Desktop"));

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Zhyprbola desktop and panel host"));
    parser.addHelpOption();
    QCommandLineOption panelOption(QStringLiteral("panel"),
        QStringLiteral("Open a focused panel host for the named panel."),
        QStringLiteral("name"));
    parser.addOption(panelOption);
    parser.addPositionalArgument(QStringLiteral("qml-file"),
        QStringLiteral("Optional QML file to load for development."));
    parser.process(app);

    Backend backend;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
    engine.rootContext()->setContextProperty(QStringLiteral("edgeScreenWidth"),
        environmentInt("ZHYPRBOLA_EDGE_SCREEN_WIDTH", 0));
    engine.rootContext()->setContextProperty(QStringLiteral("edgeScreenHeight"),
        environmentInt("ZHYPRBOLA_EDGE_SCREEN_HEIGHT", 0));

    const QString panelName = parser.value(panelOption).trimmed();
    const QStringList positional = parser.positionalArguments();
    const QString defaultQml = panelName.isEmpty()
        ? QStringLiteral("../Main.qml")
        : (panelName == QLatin1String("edge-spectrum")
            ? QStringLiteral("../EdgeSpectrum.qml")
            : QStringLiteral("../PanelHost.qml"));
    const QString qmlFile = !positional.isEmpty()
        ? QFileInfo(positional.first()).absoluteFilePath()
        : QDir(app.applicationDirPath()).absoluteFilePath(defaultQml);

    if (!panelName.isEmpty() && panelName != QLatin1String("edge-spectrum")) {
        engine.setInitialProperties({
            {QStringLiteral("requestedPanel"), panelName}
        });
    }

    engine.load(QUrl::fromLocalFile(qmlFile));
    if (engine.rootObjects().isEmpty())
        return 1;
    return app.exec();
}
