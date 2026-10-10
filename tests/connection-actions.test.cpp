#include "../components/Backend.h"
#include <QFile>
#include <QDir>
#include <QGuiApplication>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickWindow>
#include <QTemporaryDir>
#include <QtTest>

class ConnectionActionsTest : public QObject {
    Q_OBJECT
    QTemporaryDir directory;
    QByteArray originalPath;

    void write(const QString &name, const QByteArray &contents, bool executable = false) {
        QFile file(directory.filePath(name));
        QVERIFY(file.open(QIODevice::WriteOnly));
        QCOMPARE(file.write(contents), contents.size());
        file.close();
        if (executable) QVERIFY(file.setPermissions(QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner));
    }
    QVariantMap state(const Backend &backend, const QString &radio) {
        return backend.connectionActions().value(radio).toMap();
    }
private slots:
    void initTestCase() {
        QVERIFY(directory.isValid());
        originalPath = qgetenv("PATH");
        qputenv("PATH", directory.path().toUtf8());
        qputenv("XDG_CONFIG_HOME", directory.path().toUtf8());
        qputenv("RADIO_TEST_STATE", directory.filePath("state").toUtf8());
        write("bluetoothctl", R"(#!/bin/sh
case "$1" in
show) read state < "$RADIO_TEST_STATE"; printf 'Controller AA:BB:CC:DD:EE:FF Test\n Powered: %s\n' "$state" ;;
devices) ;;
power)
 /bin/sleep 0.1
 if [ "$RADIO_TEST_FAIL" = "yes" ]; then echo 'Failed to set power: org.bluez.Error.NotAuthorized'; exit 0; fi
 if [ "$RADIO_TEST_NO_CHANGE" = "yes" ]; then exit 0; fi
 if [ "$2" = "on" ]; then echo yes > "$RADIO_TEST_STATE"; else echo no > "$RADIO_TEST_STATE"; fi ;;
--timeout) /bin/sleep 0.1; if [ "$RADIO_TEST_FAIL" = "yes" ]; then echo 'Failed to start discovery'; exit 1; fi ;;
esac
)", true);
        write("nmcli", R"(#!/bin/sh
case "$*" in
'-t radio wifi') read state < "$RADIO_TEST_STATE"; if [ "$state" = yes ]; then echo enabled; else echo disabled; fi ;;
'radio wifi on') /bin/sleep 0.1; echo yes > "$RADIO_TEST_STATE" ;;
'radio wifi off') /bin/sleep 0.1; echo no > "$RADIO_TEST_STATE" ;;
*rescan*) /bin/sleep 0.1; if [ "$RADIO_TEST_FAIL" = yes ]; then echo 'Error: scan failed' >&2; exit 1; fi ;;
esac
)", true);
    }
    void init() {
        write("state", "yes\n");
        qunsetenv("RADIO_TEST_FAIL");
        qunsetenv("RADIO_TEST_NO_CHANGE");
    }
    void cleanupTestCase() { qputenv("PATH", originalPath); }

    void powerTracksBusyAndActualState() {
        Backend backend;
        QVERIFY(backend.bluetoothEnabled());
        backend.setBluetoothEnabled(false);
        QVERIFY(state(backend, "bluetooth").value("busy").toBool());
        QVERIFY(backend.bluetoothEnabled()); // State stays truthful while the command runs.
        backend.setBluetoothEnabled(true); // Duplicate click must not replace the in-flight action.
        QCOMPARE(state(backend, "bluetooth").value("action").toString(), QStringLiteral("power-off"));
        QTRY_VERIFY(!state(backend, "bluetooth").value("busy").toBool());
        QVERIFY(!backend.bluetoothEnabled());
        QVERIFY(state(backend, "bluetooth").value("success").toBool());
        backend.setBluetoothEnabled(true);
        QTRY_VERIFY(!state(backend, "bluetooth").value("busy").toBool());
        QVERIFY(backend.bluetoothEnabled());
        backend.setWifiEnabled(false);
        QVERIFY(state(backend, "wifi").value("busy").toBool());
        QTRY_VERIFY(!state(backend, "wifi").value("busy").toBool());
        QVERIFY(!backend.wifiEnabled());
    }
    void bluezFailureWithZeroExitCodeIsVisible() {
        qputenv("RADIO_TEST_FAIL", "yes");
        Backend backend;
        backend.setBluetoothEnabled(false);
        QTRY_VERIFY(!state(backend, "bluetooth").value("busy").toBool());
        QVERIFY(!state(backend, "bluetooth").value("success").toBool());
        QVERIFY(state(backend, "bluetooth").value("message").toString().contains("NotAuthorized"));
        QVERIFY(backend.bluetoothEnabled());
    }
    void powerCommandMustActuallyChangeTheRadio() {
        qputenv("RADIO_TEST_NO_CHANGE", "yes");
        Backend backend;
        backend.setBluetoothEnabled(false);
        QTRY_VERIFY(!state(backend, "bluetooth").value("busy").toBool());
        QVERIFY(!state(backend, "bluetooth").value("success").toBool());
        QVERIFY(backend.bluetoothEnabled());
    }
    void scansFinishAndReportFailure() {
        Backend backend;
        backend.scanBluetoothDevices();
        QVERIFY(state(backend, "bluetooth").value("busy").toBool());
        QTRY_VERIFY(!state(backend, "bluetooth").value("busy").toBool());
        QVERIFY(state(backend, "bluetooth").value("success").toBool());
        QVERIFY(state(backend, "bluetooth").value("message").toString().startsWith("Scan complete"));
        qputenv("RADIO_TEST_FAIL", "yes");
        backend.scanWifiNetworks();
        QTRY_VERIFY(!state(backend, "wifi").value("busy").toBool());
        QVERIFY(!state(backend, "wifi").value("success").toBool());
    }
    void missingCommandsClearLoadingAndReportErrors() {
        Backend backend;
        const QByteArray path = qgetenv("PATH");
        qputenv("PATH", "/nonexistent");
        backend.scanBluetoothDevices();
        QTRY_VERIFY(!state(backend, "bluetooth").value("busy").toBool());
        QVERIFY(!state(backend, "bluetooth").value("success").toBool());
        backend.openBluetoothSettings();
        QVERIFY(state(backend, "bluetooth").value("busy").toBool());
        QTRY_VERIFY(!state(backend, "bluetooth").value("busy").toBool());
        QVERIFY(state(backend, "bluetooth").value("message").toString().contains("No settings"));
        qputenv("PATH", path);
    }
    void settingsLaunchesTheRequestedPanel() {
        qputenv("RADIO_TEST_SETTINGS", directory.filePath("settings-request").toUtf8());
        write("gnome-control-center", "#!/bin/sh\necho \"$*\" > \"$RADIO_TEST_SETTINGS\"\n", true);
        Backend backend;
        for (const QString &radio : {QStringLiteral("bluetooth"), QStringLiteral("wifi")}) {
            QFile::remove(directory.filePath("settings-request"));
            if (radio == QLatin1String("bluetooth")) backend.openBluetoothSettings();
            else backend.openWifiSettings();
            QVERIFY(state(backend, radio).value("busy").toBool());
            QTRY_VERIFY(!state(backend, radio).value("busy").toBool());
            QVERIFY(state(backend, radio).value("success").toBool());
            QTRY_VERIFY(QFile::exists(directory.filePath("settings-request")));
            QFile request(directory.filePath("settings-request"));
            QVERIFY(request.open(QIODevice::ReadOnly));
            QCOMPARE(QString::fromUtf8(request.readAll()).trimmed(), radio);
        }
        QVERIFY(QFile::remove(directory.filePath("gnome-control-center")));
    }
    void panelsLoadWithSharedPowerAndProgressControls() {
        Backend backend;
        backend.setThemeName(QStringLiteral("mauve"));
        QQmlEngine engine;
        engine.rootContext()->setContextProperty("backend", &backend);
        for (const QString &name : {QStringLiteral("BluetoothPanel"), QStringLiteral("WifiPanel")}) {
            const QString path = QFINDTESTDATA("../components/" + name + ".qml");
            QQmlComponent component(&engine, QUrl::fromLocalFile(path));
            QVERIFY2(component.isReady(), qPrintable(component.errorString()));
            QScopedPointer<QObject> panel(component.createWithInitialProperties(
                {{QStringLiteral("standalone"), true}}));
            QVERIFY2(panel, qPrintable(component.errorString()));
            auto *item = qobject_cast<QQuickItem *>(panel.data());
            QVERIFY(item);
            QQuickWindow window;
            window.resize(430, name == QLatin1String("BluetoothPanel") ? 548 : 576);
            window.setColor(Qt::transparent);
            item->setParentItem(window.contentItem());
            item->setWidth(window.width());
            item->setHeight(window.height());
            item->setProperty("opened", true);
            window.show();
            QTRY_VERIFY(window.isExposed());
            QTest::qWait(200);
            const QString radio = name == QLatin1String("BluetoothPanel") ? "bluetooth" : "wifi";
            QTRY_VERIFY(!state(backend, radio).value("busy").toBool());
            QObject *power = panel->findChild<QObject *>("radioPowerButton");
            QObject *scan = panel->findChild<QObject *>("scanButton");
            QObject *settings = panel->findChild<QObject *>("settingsButton");
            QVERIFY(power && scan && settings);
            QVERIFY(power->property("checked").toBool());
            const auto capture = [&](const QString &suffix) {
                const QString previews = qEnvironmentVariable("CONNECTION_ACTION_PREVIEW_DIR");
                if (!previews.isEmpty()) {
                    QVERIFY(QDir().mkpath(previews));
                    QTest::qWait(20);
                    const QImage image = window.grabWindow();
                    QVERIFY(!image.isNull());
                    QVERIFY(image.save(QDir(previews).filePath(radio + "-" + suffix + ".png")));
                }
            };
            if (radio == QLatin1String("bluetooth")) backend.setBluetoothEnabled(false);
            else backend.setWifiEnabled(false);
            QVERIFY(power->property("busy").toBool());
            QVERIFY(!power->property("enabled").toBool());
            QVERIFY(!scan->property("enabled").toBool());
            QVERIFY(!settings->property("enabled").toBool());
            capture("power-pending");
            QTRY_VERIFY(!state(backend, radio).value("busy").toBool());
            QVERIFY(!power->property("checked").toBool());
            QVERIFY(power->property("enabled").toBool());
            QVERIFY(!scan->property("enabled").toBool());
            capture("off");
            if (radio == QLatin1String("bluetooth")) backend.setBluetoothEnabled(true);
            else backend.setWifiEnabled(true);
            QTRY_VERIFY(!state(backend, radio).value("busy").toBool());
            QVERIFY(power->property("checked").toBool());
            QVERIFY(scan->property("enabled").toBool());
            if (radio == QLatin1String("bluetooth")) backend.scanBluetoothDevices();
            else backend.scanWifiNetworks();
            QVERIFY(scan->property("busy").toBool());
            capture("scanning");
            QTRY_VERIFY(!state(backend, radio).value("busy").toBool());
            capture("on");
            item->setProperty("activeTab", QStringLiteral("details"));
            capture("details");
            item->setParentItem(nullptr);
        }
    }
};

QTEST_MAIN(ConnectionActionsTest)
#include "connection-actions.test.moc"
