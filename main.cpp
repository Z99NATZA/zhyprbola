#include "components/Backend.h"
#include "components/SoundBackend.h"
#include "components/ScreenshotBackend.h"

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDir>
#include <QFileInfo>
#include <QCommandLineParser>
#include <QDBusConnection>
#include <QDBusInterface>
#include <memory>

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
    parser.addOption(QCommandLineOption(QStringLiteral("resident"),
        QStringLiteral("Keep the screenshots browser ready in the background.")));
    parser.addPositionalArgument(QStringLiteral("qml-file"),
        QStringLiteral("Optional QML file to load for development."));
    parser.process(app);

    const QString panelName = parser.value(panelOption).trimmed();
    std::unique_ptr<Backend> backend;
    std::unique_ptr<SoundBackend> sound;
    ScreenshotBackend screenshots;
    QQmlApplicationEngine engine;
    if (panelName == QLatin1String("screenshots")) {
        app.setQuitOnLastWindowClosed(false);
        auto bus = QDBusConnection::sessionBus();
        if (!bus.registerService(QStringLiteral("org.zhyprbola.Screenshots"))) {
            QDBusInterface existing(QStringLiteral("org.zhyprbola.Screenshots"),
                QStringLiteral("/org/zhyprbola/Screenshots"),
                QStringLiteral("org.zhyprbola.Screenshots"), bus);
            if (!parser.isSet(QStringLiteral("resident"))) existing.call(QStringLiteral("Show"));
            return 0;
        }
        bus.registerObject(QStringLiteral("/org/zhyprbola/Screenshots"), &screenshots,
            QDBusConnection::ExportScriptableSlots | QDBusConnection::ExportScriptableSignals);
        if (parser.isSet(QStringLiteral("resident"))) screenshots.Hide();
        engine.rootContext()->setContextProperty(QStringLiteral("backend"), &screenshots);
    } else {
        backend = std::make_unique<Backend>();
        sound = std::make_unique<SoundBackend>();
        engine.rootContext()->setContextProperty(QStringLiteral("backend"), backend.get());
        engine.rootContext()->setContextProperty(QStringLiteral("sound"), sound.get());
    }
    engine.rootContext()->setContextProperty(QStringLiteral("screenshots"), &screenshots);
    engine.rootContext()->setContextProperty(QStringLiteral("edgeScreenWidth"),
        environmentInt("ZHYPRBOLA_EDGE_SCREEN_WIDTH", 0));
    engine.rootContext()->setContextProperty(QStringLiteral("edgeScreenHeight"),
        environmentInt("ZHYPRBOLA_EDGE_SCREEN_HEIGHT", 0));

    const QStringList positional = parser.positionalArguments();
    const QString defaultQml = panelName.isEmpty()
        ? QStringLiteral("../Main.qml")
        : (panelName == QLatin1String("screenshots")
            ? QStringLiteral("../ScreenshotHost.qml")
            : panelName == QLatin1String("edge-spectrum")
            ? QStringLiteral("../EdgeSpectrum.qml")
            : QStringLiteral("../PanelHost.qml"));
    const QString qmlFile = !positional.isEmpty()
        ? QFileInfo(positional.first()).absoluteFilePath()
        : QDir(app.applicationDirPath()).absoluteFilePath(defaultQml);

    if (!panelName.isEmpty() && panelName != QLatin1String("edge-spectrum")
        && panelName != QLatin1String("screenshots")) {
        engine.setInitialProperties({
            {QStringLiteral("requestedPanel"), panelName}
        });
    }

    engine.load(QUrl::fromLocalFile(qmlFile));
    if (engine.rootObjects().isEmpty())
        return 1;
    return app.exec();
}
