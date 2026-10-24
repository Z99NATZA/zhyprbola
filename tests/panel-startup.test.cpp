#include "../components/Backend.h"
#include "../components/SoundBackend.h"
#include "../components/ScreenshotBackend.h"
#include <QtTest>
#include <QFile>
#include <QTemporaryDir>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickItem>
#include <QQuickWindow>
#include <QDBusVirtualObject>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QScopeGuard>

class MprisStub : public QDBusVirtualObject {
public:
    bool playing = false;
    QString lastCommand;
    QVariantList lastArguments;
    QString introspect(const QString &) const override { return {}; }
    bool handleMessage(const QDBusMessage &message, const QDBusConnection &connection) override {
        if (message.interface() == QLatin1String("org.freedesktop.DBus.Properties")) {
            const QVariantMap metadata{{QStringLiteral("xesam:title"), QStringLiteral("Bus song")},
                {QStringLiteral("xesam:artist"), QStringList{QStringLiteral("Bus artist")}},
                {QStringLiteral("mpris:length"), qlonglong(180000000)},
                {QStringLiteral("mpris:trackid"), QVariant::fromValue(QDBusObjectPath("/track/1"))}};
            const QVariantMap properties{{QStringLiteral("Metadata"), metadata},
                {QStringLiteral("Position"), qlonglong(4000000)},
                {QStringLiteral("PlaybackStatus"), playing ? QStringLiteral("Playing") : QStringLiteral("Paused")}};
            connection.send(message.createReply(QVariantList{properties}));
        } else {
            lastCommand = message.member();
            lastArguments = message.arguments();
            connection.send(message.createReply());
        }
        return true;
    }
};

class PanelStartupTest : public QObject {
    Q_OBJECT
    QTemporaryDir directory;
    QByteArray originalPath;
    QByteArray originalConfig;
    QString logPath;

    QByteArray calls() {
        QFile file(logPath);
        return file.open(QIODevice::ReadOnly) ? file.readAll() : QByteArray();
    }
    void clearCalls() { QFile file(logPath); QVERIFY(file.open(QIODevice::WriteOnly)); }
private slots:
    void initTestCase() {
        QVERIFY(directory.isValid());
        QQuickWindow::setSceneGraphBackend("software");
        originalPath = qgetenv("PATH");
        originalConfig = qgetenv("XDG_CONFIG_HOME");
        qputenv("PATH", directory.path().toUtf8());
        qputenv("XDG_CONFIG_HOME", directory.path().toUtf8());
        logPath = directory.filePath("calls");
        qputenv("PANEL_TEST_CALLS", logPath.toUtf8());
        const QByteArray script = R"shell(#!/bin/sh
echo "$0 $*" >> "$PANEL_TEST_CALLS"
if [ -n "$PANEL_TEST_DELAY" ]; then /bin/sleep "$PANEL_TEST_DELAY"; fi
if [ "$PANEL_TEST_FAIL" = yes ]; then exit 1; fi
case "$0" in
*/nmcli)
 case "$*" in
 '-t radio wifi') echo enabled ;;
 *TYPE,STATE,CONNECTION*) echo 'wifi:connected:Office' ;;
 *ACTIVE,SSID,SIGNAL,SECURITY*) echo 'yes:Office:80:WPA2' ;;
 *NAME,TYPE*) echo 'Office:802-11-wireless' ;;
 esac ;;
*/bluetoothctl)
 case "$1" in
 show) printf 'Powered: yes\n' ;;
 devices) echo 'Device 11:22:33:44:55:66 Headphones' ;;
 info) printf 'Name: Headphones\nPaired: yes\nTrusted: yes\nConnected: yes\n' ;;
 esac ;;
*/playerctl)
 case "$*" in
 '-l') echo sample ;;
 *metadata*) printf 'Song\037Artist\037120000000\n' ;;
 *position*) echo 12.5 ;;
 *status*) echo Playing ;;
 esac ;;
*/cava) exec /bin/sleep 30 ;;
*/gjs) echo '{"type":"ready"}'; exec /bin/sleep 30 ;;
esac
)shell";
        for (const QString &name : {QStringLiteral("nmcli"), QStringLiteral("bluetoothctl"),
                 QStringLiteral("playerctl"), QStringLiteral("cava"), QStringLiteral("gjs")}) {
            QFile file(directory.filePath(name));
            QVERIFY(file.open(QIODevice::WriteOnly));
            file.write(script);
            file.close();
            QVERIFY(file.setPermissions(QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner));
        }
    }
    void init() {
        clearCalls();
        qunsetenv("PANEL_TEST_DELAY");
        qunsetenv("PANEL_TEST_FAIL");
    }
    void cleanupTestCase() {
        qputenv("PATH", originalPath);
        if (originalConfig.isEmpty()) qunsetenv("XDG_CONFIG_HOME");
        else qputenv("XDG_CONFIG_HOME", originalConfig);
        qunsetenv("PANEL_TEST_CALLS");
        qunsetenv("PANEL_TEST_DELAY");
        qunsetenv("PANEL_TEST_FAIL");
    }
    void localPanelsDoNotStartUnrelatedHelpers_data() {
        QTest::addColumn<QString>("name");
        for (const char *name : {"calendar", "todo", "settings", "key-visualizer", "sound"})
            QTest::newRow(name) << QString::fromLatin1(name);
    }
    void localPanelsDoNotStartUnrelatedHelpers() {
        QFETCH(QString, name);
        Backend backend(nullptr, name);
        backend.setPanelActive(true);
        QTest::qWait(100);
        QVERIFY(calls().isEmpty());
    }
    void slowWifiQueriesDoNotBlockUiOrDiscardCachedData() {
        qputenv("PANEL_TEST_DELAY", "0.15");
        Backend backend(nullptr, QStringLiteral("wifi"));
        backend.setPanelActive(true);
        bool heartbeat = false;
        QTimer::singleShot(20, this, [&heartbeat]() { heartbeat = true; });
        QTRY_VERIFY_WITH_TIMEOUT(heartbeat, 100);
        QVERIFY(backend.wifiNetworks().isEmpty());
        QTRY_VERIFY(backend.wifiConnected());
        QTRY_VERIFY(!backend.wifiNetworks().isEmpty());
        QCOMPARE(backend.wifiSsid(), QStringLiteral("Office"));
        QVERIFY(!calls().contains("bluetoothctl"));
        QVERIFY(!calls().contains("playerctl"));
        QVERIFY(!calls().contains("cava"));
        backend.setPanelActive(false);
        qputenv("PANEL_TEST_FAIL", "yes");
        backend.setPanelActive(true);
        QTest::qWait(400);
        QVERIFY(backend.wifiConnected());
        QCOMPARE(backend.wifiSsid(), QStringLiteral("Office"));
        QVERIFY(!backend.wifiNetworks().isEmpty());
    }
    void bluetoothQueriesAreAsyncAndLimitedToBluetooth() {
        qputenv("PANEL_TEST_DELAY", "0.15");
        Backend backend(nullptr, QStringLiteral("bluetooth"));
        backend.setPanelActive(true);
        bool heartbeat = false;
        QTimer::singleShot(20, this, [&heartbeat]() { heartbeat = true; });
        QTRY_VERIFY_WITH_TIMEOUT(heartbeat, 100);
        QVERIFY(backend.bluetoothDevices().isEmpty());
        QTRY_VERIFY(backend.bluetoothConnected());
        QCOMPARE(backend.bluetoothDeviceName(), QStringLiteral("Headphones"));
        QVERIFY(!calls().contains("nmcli"));
        QVERIFY(!calls().contains("playerctl"));
    }
    void musicQueriesAreAsyncAndPauseWhenHidden() {
        qputenv("PANEL_TEST_DELAY", "0.1");
        Backend backend(nullptr, QStringLiteral("music"));
        backend.setPanelActive(true);
        bool heartbeat = false;
        QTimer::singleShot(20, this, [&heartbeat]() { heartbeat = true; });
        QTRY_VERIFY_WITH_TIMEOUT(heartbeat, 100);
        QVERIFY(!backend.hasPlayer());
        QTRY_COMPARE(backend.songTitle(), QStringLiteral("Song"));
        QCOMPARE(backend.artist(), QStringLiteral("Artist"));
        QCOMPARE(backend.durationMs(), qint64(120000));
        QCOMPARE(backend.positionMs(), qint64(12500));
        QVERIFY(backend.playing());
        QVERIFY(!calls().contains("nmcli"));
        QVERIFY(!calls().contains("bluetoothctl"));
        backend.setPanelActive(false);
        QTest::qWait(50);
        const auto stopped = calls();
        QTest::qWait(2100);
        QCOMPARE(calls(), stopped);
        backend.setPanelActive(true);
        QTRY_VERIFY(calls().size() > stopped.size());
    }
    void spectrumSurvivesImmediateHideAndRestore() {
        Backend backend(nullptr, QStringLiteral("audio-spectrum"));
        backend.setPanelActive(true);
        QTRY_VERIFY(calls().contains("cava"));
        backend.setPanelActive(false);
        backend.setPanelActive(true);
        QTRY_VERIFY(calls().count("/cava ") >= 2);
        QVERIFY(!calls().contains("nmcli"));
        QVERIFY(!calls().contains("bluetoothctl"));
        QVERIFY(!calls().contains("playerctl"));
    }
    void mprisFallbackSelectsPlayingPlayerAndControlsItAsynchronously() {
        const QString playerctl = directory.filePath("playerctl");
        QVERIFY(QFile::rename(playerctl, playerctl + ".disabled"));
        auto cleanup = qScopeGuard([playerctl]() {
            QFile::rename(playerctl + ".disabled", playerctl);
            QDBusConnection::disconnectFromBus(QStringLiteral("test-paused-player"));
            QDBusConnection::disconnectFromBus(QStringLiteral("test-playing-player"));
        });
        auto pausedBus = QDBusConnection::connectToBus(QDBusConnection::SessionBus, QStringLiteral("test-paused-player"));
        auto playingBus = QDBusConnection::connectToBus(QDBusConnection::SessionBus, QStringLiteral("test-playing-player"));
        MprisStub paused, playing;
        playing.playing = true;
        QVERIFY(pausedBus.registerService(QStringLiteral("org.mpris.MediaPlayer2.aaa_startup_test")));
        QVERIFY(playingBus.registerService(QStringLiteral("org.mpris.MediaPlayer2.zzz_startup_test")));
        QVERIFY(pausedBus.registerVirtualObject(QStringLiteral("/org/mpris/MediaPlayer2"), &paused));
        QVERIFY(playingBus.registerVirtualObject(QStringLiteral("/org/mpris/MediaPlayer2"), &playing));
        Backend backend(nullptr, QStringLiteral("music"));
        backend.setPanelActive(true);
        QTRY_COMPARE(backend.songTitle(), QStringLiteral("Bus song"));
        QVERIFY(backend.playing());
        QCOMPARE(backend.artist(), QStringLiteral("Bus artist"));
        QCOMPARE(backend.durationMs(), qint64(180000));
        QCOMPARE(backend.positionMs(), qint64(4000));
        backend.togglePlayback();
        QTRY_COMPARE(playing.lastCommand, QStringLiteral("PlayPause"));
        QVERIFY(paused.lastCommand.isEmpty());
        backend.seek(42);
        QTRY_COMPARE(playing.lastCommand, QStringLiteral("SetPosition"));
        QCOMPARE(playing.lastArguments.at(0).value<QDBusObjectPath>().path(), QStringLiteral("/track/1"));
        QCOMPARE(playing.lastArguments.at(1).toLongLong(), qlonglong(42000000));
    }
    void focusedHostsLoadOnlyTheirOwnComponent_data() {
        QTest::addColumn<QString>("name");
        QTest::addColumn<QString>("type");
        QTest::newRow("calendar") << QStringLiteral("calendar") << QStringLiteral("Calendar");
        QTest::newRow("settings") << QStringLiteral("settings") << QStringLiteral("SettingsPanel");
        QTest::newRow("tasks") << QStringLiteral("tasks") << QStringLiteral("Todo");
        QTest::newRow("wifi") << QStringLiteral("wifi") << QStringLiteral("WifiPanel");
        QTest::newRow("bluetooth") << QStringLiteral("bluetooth") << QStringLiteral("BluetoothPanel");
        QTest::newRow("music") << QStringLiteral("music") << QStringLiteral("MusicPlayer");
        QTest::newRow("sound") << QStringLiteral("sound") << QStringLiteral("SoundPanel");
        QTest::newRow("keys") << QStringLiteral("key-visualizer") << QStringLiteral("KeyVisualizer");
    }
    void focusedHostsLoadOnlyTheirOwnComponent() {
        QFETCH(QString, name);
        QFETCH(QString, type);
        Backend backend(nullptr, name);
        SoundBackend sound;
        ScreenshotBackend screenshots(directory.filePath("images"));
        QQmlApplicationEngine engine;
        engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
        engine.rootContext()->setContextProperty(QStringLiteral("sound"), &sound);
        engine.rootContext()->setContextProperty(QStringLiteral("screenshots"), &screenshots);
        engine.setInitialProperties({{QStringLiteral("requestedPanel"), name}});
        QSignalSpy warnings(&engine, &QQmlEngine::warnings);
        engine.load(QUrl::fromLocalFile(QFINDTESTDATA("../PanelHost.qml")));
        QVERIFY(!engine.rootObjects().isEmpty());
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QVERIFY(window);
        QTRY_VERIFY(window->isExposed());
        QObject *loader = window->findChild<QObject *>(QStringLiteral("panel-loader"));
        QVERIFY(loader);
        QObject *item = loader->property("item").value<QObject *>();
        QVERIFY(item);
        QVERIFY(QString::fromLatin1(item->metaObject()->className()).startsWith(type));
        if (name == QLatin1String("wifi") || name == QLatin1String("bluetooth")) {
            QTRY_VERIFY(item->property("opened").toBool());
            QTRY_COMPARE(item->property("opacity").toReal(), 1.0);
            const QImage frame = window->grabWindow();
            QVERIFY(!frame.isNull());
            QVERIFY2(frame.pixelColor(100, 100).alpha() > 240,
                "The radio card must render inside the window, not leave only its border");
        }
        // Other component roots must not exist anywhere in the host's object tree.
        for (QObject *object : window->findChildren<QObject *>()) {
            const QString className = QString::fromLatin1(object->metaObject()->className());
            for (const QString &other : {QStringLiteral("Calendar"), QStringLiteral("SettingsPanel"),
                     QStringLiteral("WifiPanel"), QStringLiteral("BluetoothPanel"), QStringLiteral("MusicPlayer")})
                if (other != type) QVERIFY2(!className.startsWith(other + QLatin1Char('_')), qPrintable(className));
        }
        if (name == QLatin1String("tasks")) {
            window->resize(500, 500);
            QTRY_COMPARE(qobject_cast<QQuickItem *>(item)->width(), 500.0);
        }
        if (name == QLatin1String("key-visualizer")) {
            QTRY_VERIFY(backend.keyCaptureAvailable());
            backend.setKeyVisualizerSetting(QStringLiteral("maxWidth"), 500);
            backend.setKeyVisualizerSetting(QStringLiteral("widthMode"), QStringLiteral("fixed"));
            QTRY_COMPARE(window->width(), 500);
        }
        window->hide();
        if (name == QLatin1String("key-visualizer")) QVERIFY(!backend.keyCaptureAvailable());
        window->show();
        if (name == QLatin1String("wifi") || name == QLatin1String("bluetooth")) {
            QTRY_VERIFY(item->property("opened").toBool());
            QTRY_COMPARE(item->property("opacity").toReal(), 1.0);
            const QImage restored = window->grabWindow();
            QVERIFY(!restored.isNull());
            QVERIFY(restored.pixelColor(100, 100).alpha() > 240);
        }
        if (name == QLatin1String("key-visualizer")) QTRY_VERIFY(backend.keyCaptureAvailable());
        QCOMPARE(loader->property("item").value<QObject *>(), item);
        QCOMPARE(warnings.size(), 0);
    }
};
QTEST_MAIN(PanelStartupTest)
#include "panel-startup.test.moc"
