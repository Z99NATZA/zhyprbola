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
    QQuickItem *findVisualItem(QQuickItem *root, const QString &name) {
        if (root->objectName() == name) return root;
        for (auto *child : root->childItems())
            if (auto *found = findVisualItem(child, name)) return found;
        return nullptr;
    }
private slots:
    void initTestCase() {
        QVERIFY(directory.isValid());
        originalPath = qgetenv("PATH");
        qputenv("PATH", directory.path().toUtf8());
        qputenv("XDG_CONFIG_HOME", directory.path().toUtf8());
        qputenv("RADIO_TEST_STATE", directory.filePath("state").toUtf8());
        write("bluetoothctl", R"shell(#!/bin/sh
case "$1" in
show) read state < "$RADIO_TEST_STATE"; printf 'Controller AA:BB:CC:DD:EE:FF Test\n Powered: %s\n' "$state" ;;
devices)
 if [ "$RADIO_TEST_DISCOVERY" = yes ]; then
  read discovered < "$RADIO_TEST_STATE-bluetooth-discovered"
  if [ "$discovered" = pending ]; then
   read polls < "$RADIO_TEST_STATE-bluetooth-polls"
   echo "$((polls + 1))" > "$RADIO_TEST_STATE-bluetooth-polls"
   if [ "$polls" -ge 3 ]; then discovered=yes; echo yes > "$RADIO_TEST_STATE-bluetooth-discovered"; fi
  fi
  if [ "$discovered" != yes ]; then exit 0; fi
 fi
 echo 'Device 11:22:33:44:55:66 Black Shark T23' ;;
info)
 read device < "$RADIO_TEST_STATE-device"
 read power < "$RADIO_TEST_STATE"
 if [ "$power" = no ]; then device=no; fi
 printf 'Name: Black Shark T23\nPaired: yes\nTrusted: yes\nConnected: %s\n' "$device" ;;
connect|disconnect)
 echo "$1" >> "$RADIO_TEST_STATE-actions"
 /bin/sleep 0.2
 if [ "$1" = connect ]; then echo yes > "$RADIO_TEST_STATE-device"; else echo no > "$RADIO_TEST_STATE-device"; fi ;;
power)
 /bin/sleep 0.1
 if [ "$RADIO_TEST_FAIL" = "yes" ]; then echo 'Failed to set power: org.bluez.Error.NotAuthorized'; exit 0; fi
 read blocked < "$RADIO_TEST_STATE-blocked"
 if [ "$2" = "on" ] && [ "$blocked" = "yes" ]; then echo 'Failed to set power: org.bluez.Error.Blocked'; exit 1; fi
 if [ "$RADIO_TEST_NO_CHANGE" = "yes" ]; then exit 0; fi
 if [ "$2" = "on" ]; then
  echo no > "$RADIO_TEST_STATE-bluetooth-discovered"
  echo yes > "$RADIO_TEST_STATE"
 else echo no > "$RADIO_TEST_STATE"; fi ;;
--timeout)
 echo bluetooth >> "$RADIO_TEST_STATE-scans"
 /bin/sleep 0.1
 if [ "$RADIO_TEST_FAIL" = yes ] || [ "$RADIO_TEST_SCAN_FAIL" = yes ]; then echo 'Failed to start discovery'; exit 1; fi
 if [ "$RADIO_TEST_DELAYED_DISCOVERY" = yes ]; then echo pending > "$RADIO_TEST_STATE-bluetooth-discovered"; else echo yes > "$RADIO_TEST_STATE-bluetooth-discovered"; fi ;;
esac
)shell", true);
        write("rfkill", R"shell(#!/bin/sh
echo "$*" >> "$RADIO_TEST_STATE-rfkill"
if [ "$RADIO_TEST_RFKILL_FAIL" = yes ]; then exit 1; fi
if [ "$1" = unblock ] && [ "$2" = bluetooth ]; then echo no > "$RADIO_TEST_STATE-blocked"; fi
)shell", true);
        write("nmcli", R"shell(#!/bin/sh
case "$*" in
'-t radio wifi') read state < "$RADIO_TEST_STATE"; if [ "$state" = yes ]; then echo enabled; else echo disabled; fi ;;
'radio wifi on')
 /bin/sleep 0.1
 if [ "$RADIO_TEST_FAIL" = yes ]; then echo 'Error: could not enable Wi-Fi' >&2; exit 1; fi
 echo no > "$RADIO_TEST_STATE-wifi-discovered"
 echo yes > "$RADIO_TEST_STATE" ;;
'radio wifi off') /bin/sleep 0.1; echo no > "$RADIO_TEST_STATE" ;;
*TYPE,STATE,CONNECTION*)
 read power < "$RADIO_TEST_STATE"
 read network < "$RADIO_TEST_STATE-wifi"
 read ssid < "$RADIO_TEST_STATE-wifi-ssid"
 if [ "$power" = yes ] && [ "$network" = yes ]; then printf 'wifi:connected:%s\n' "$ssid"; else echo 'wifi:disconnected:'; fi ;;
*ACTIVE,SSID,SIGNAL,SECURITY*)
 if [ "$RADIO_TEST_DISCOVERY" = yes ]; then
  read discovered < "$RADIO_TEST_STATE-wifi-discovered"
  if [ "$discovered" = pending ]; then
   read polls < "$RADIO_TEST_STATE-wifi-polls"
   echo "$((polls + 1))" > "$RADIO_TEST_STATE-wifi-polls"
   if [ "$polls" -ge 3 ]; then discovered=yes; echo yes > "$RADIO_TEST_STATE-wifi-discovered"; fi
  fi
  if [ "$discovered" != yes ]; then exit 0; fi
 fi
 read power < "$RADIO_TEST_STATE"
 read network < "$RADIO_TEST_STATE-wifi"
 read ssid < "$RADIO_TEST_STATE-wifi-ssid"
 if [ "$power" = no ]; then network=no; fi
 if [ "$ssid" = 'Test Wi-Fi' ]; then
  printf '%s:Test Wi-Fi:80:WPA2\nno:Guest Wi-Fi:60:WPA2\n' "$network"
 else
  printf 'no:Test Wi-Fi:80:WPA2\n%s:Guest Wi-Fi:60:WPA2\n' "$network"
 fi ;;
*NAME,TYPE*) echo 'Test Wi-Fi:802-11-wireless' ;;
*'connection down'*)
 echo disconnect >> "$RADIO_TEST_STATE-wifi-actions"
 /bin/sleep 0.2; echo no > "$RADIO_TEST_STATE-wifi" ;;
*'connection up'*|*'device wifi connect'*)
 echo connect >> "$RADIO_TEST_STATE-wifi-actions"
 echo "$6" > "$RADIO_TEST_STATE-wifi-ssid"
 /bin/sleep 0.2; echo yes > "$RADIO_TEST_STATE-wifi" ;;
*rescan*)
 echo wifi >> "$RADIO_TEST_STATE-scans"
 echo "$*" > "$RADIO_TEST_STATE-wifi-scan-command"
 /bin/sleep 0.1
 if [ "$RADIO_TEST_FAIL" = yes ] || [ "$RADIO_TEST_SCAN_FAIL" = yes ]; then echo 'Error: scan failed' >&2; exit 1; fi
 if [ "$RADIO_TEST_DELAYED_DISCOVERY" = yes ]; then echo pending > "$RADIO_TEST_STATE-wifi-discovered"; else echo yes > "$RADIO_TEST_STATE-wifi-discovered"; fi ;;
esac
)shell", true);
    }
    void init() {
        write("state", "yes\n");
        write("state-device", "yes\n");
        write("state-actions", "");
        write("state-wifi", "yes\n");
        write("state-wifi-ssid", "Test Wi-Fi\n");
        write("state-wifi-actions", "");
        write("state-scans", "");
        write("state-blocked", "no\n");
        write("state-rfkill", "");
        write("state-bluetooth-discovered", "no\n");
        write("state-wifi-discovered", "no\n");
        qunsetenv("RADIO_TEST_FAIL");
        qunsetenv("RADIO_TEST_NO_CHANGE");
        qunsetenv("RADIO_TEST_DISCOVERY");
        qunsetenv("RADIO_TEST_SCAN_FAIL");
        qunsetenv("RADIO_TEST_DELAYED_DISCOVERY");
        qunsetenv("RADIO_TEST_RFKILL_FAIL");
        write("state-bluetooth-polls", "0\n");
        write("state-wifi-polls", "0\n");
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
        QFile refreshRequest(directory.filePath("zhyprbola/connection-refresh"));
        QVERIFY(refreshRequest.open(QIODevice::ReadOnly));
        QVERIFY(!refreshRequest.readAll().trimmed().isEmpty());
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
    void openingPanelsUsesCachedResultsWithoutScanning() {
        Backend backend;
        QVERIFY(!backend.wifiNetworks().isEmpty());
        QVERIFY(!backend.bluetoothDevices().isEmpty());
        QQmlEngine engine;
        engine.rootContext()->setContextProperty("backend", &backend);

        for (const QString &name : {QStringLiteral("BluetoothPanel"), QStringLiteral("WifiPanel")}) {
            QQmlComponent component(&engine, QUrl::fromLocalFile(QFINDTESTDATA(
                "../components/" + name + ".qml")));
            QVERIFY2(component.isReady(), qPrintable(component.errorString()));
            QScopedPointer<QObject> panel(component.createWithInitialProperties(
                {{QStringLiteral("standalone"), true}}));
            QVERIFY2(panel, qPrintable(component.errorString()));
            panel->setProperty("opened", true);
            panel->setProperty("opened", false);
            panel->setProperty("opened", true);
        }

        QFile scans(directory.filePath("state-scans"));
        QVERIFY(scans.open(QIODevice::ReadOnly));
        QCOMPARE(scans.readAll(), QByteArray());
    }
    void requestingTheCurrentPowerStateDoesNothing() {
        Backend backend;
        QVERIFY(backend.wifiEnabled());
        QVERIFY(backend.bluetoothEnabled());

        backend.setWifiEnabled(true);
        backend.setBluetoothEnabled(true);

        QVERIFY(state(backend, "wifi").isEmpty());
        QVERIFY(state(backend, "bluetooth").isEmpty());
        QFile scans(directory.filePath("state-scans"));
        QVERIFY(scans.open(QIODevice::ReadOnly));
        QCOMPARE(scans.readAll(), QByteArray());
    }
    void softBlockedBluetoothIsUnblockedBeforePowerOn() {
        write("state", "no\n");
        write("state-blocked", "yes\n");
        Backend backend;
        QVERIFY(!backend.bluetoothEnabled());

        backend.setBluetoothEnabled(true);

        QTRY_VERIFY(!state(backend, "bluetooth").value("busy").toBool());
        QVERIFY(state(backend, "bluetooth").value("success").toBool());
        QVERIFY(backend.bluetoothEnabled());
        QFile rfkill(directory.filePath("state-rfkill"));
        QVERIFY(rfkill.open(QIODevice::ReadOnly));
        QCOMPARE(rfkill.readAll(), QByteArray("unblock bluetooth\n"));
    }
    void powerOnDiscoversAfterAdapterReady_data() {
        QTest::addColumn<QString>("radio");
        QTest::addColumn<bool>("scanFails");
        QTest::addColumn<bool>("delayed");
        QTest::newRow("bluetooth") << QStringLiteral("bluetooth") << false << false;
        QTest::newRow("wifi") << QStringLiteral("wifi") << false << false;
        QTest::newRow("bluetooth-scan-failure") << QStringLiteral("bluetooth") << true << false;
        QTest::newRow("wifi-scan-failure") << QStringLiteral("wifi") << true << false;
        QTest::newRow("bluetooth-delayed-list") << QStringLiteral("bluetooth") << false << true;
        QTest::newRow("wifi-delayed-list") << QStringLiteral("wifi") << false << true;
    }
    void powerOnDiscoversAfterAdapterReady() {
        QFETCH(QString, radio);
        QFETCH(bool, scanFails);
        QFETCH(bool, delayed);
        if (delayed) qputenv("RADIO_TEST_DELAYED_DISCOVERY", "yes");
        write("state", "no\n");
        qputenv("RADIO_TEST_DISCOVERY", "yes");
        if (scanFails) qputenv("RADIO_TEST_SCAN_FAIL", "yes");
        Backend backend;
        const bool wifi = radio == QLatin1String("wifi");
        QQmlEngine engine;
        engine.rootContext()->setContextProperty("backend", &backend);
        QQmlComponent component(&engine, QUrl::fromLocalFile(QFINDTESTDATA(
            wifi ? "../components/WifiPanel.qml" : "../components/BluetoothPanel.qml")));
        QVERIFY2(component.isReady(), qPrintable(component.errorString()));
        QScopedPointer<QObject> panel(component.createWithInitialProperties(
            {{QStringLiteral("standalone"), true}, {QStringLiteral("opened"), true}}));
        QVERIFY2(panel, qPrintable(component.errorString()));
        QObject *discovery = panel->findChild<QObject *>(radio + "DiscoveryStatus");
        QObject *power = panel->findChild<QObject *>("radioPowerButton");
        QVERIFY(discovery && power);
        const auto powered = [&]() { return wifi ? backend.wifiEnabled() : backend.bluetoothEnabled(); };
        const auto list = [&]() { return wifi ? backend.wifiNetworks() : backend.bluetoothDevices(); };
        const auto setPower = [&](bool enabled) {
            if (wifi) backend.setWifiEnabled(enabled);
            else backend.setBluetoothEnabled(enabled);
        };
        QVERIFY(!powered());
        QVERIFY(list().isEmpty());
        bool scannedWhilePowered = false;
        connect(&backend, &Backend::connectionActionsChanged, this, [&]() {
            if (state(backend, radio).value("action") == "scan"
                && state(backend, radio).value("busy").toBool()) {
                scannedWhilePowered = powered();
            }
        });
        setPower(true);
        QCOMPARE(state(backend, radio).value("action").toString(), QStringLiteral("power-on"));
        QVERIFY(discovery->property("searching").toBool());
        QVERIFY(!power->property("enabled").toBool());
        // Repeated power requests and refreshes must not create extra work.
        setPower(true);
        if (wifi) backend.scanWifiNetworks();
        else backend.scanBluetoothDevices();
        QTRY_VERIFY(scannedWhilePowered);
        if (delayed) {
            QVERIFY(state(backend, radio).value("busy").toBool());
            QVERIFY(list().isEmpty());
            QVERIFY(discovery->property("searching").toBool());
            QVERIFY(!power->property("enabled").toBool());
        }
        QTRY_VERIFY(!state(backend, radio).value("busy").toBool());
        QVERIFY(powered());
        QCOMPARE(state(backend, radio).value("action").toString(), QStringLiteral("scan"));
        QCOMPARE(state(backend, radio).value("success").toBool(), !scanFails);
        QCOMPARE(list().isEmpty(), scanFails);
        QVERIFY(!discovery->property("searching").toBool());
        QVERIFY(power->property("enabled").toBool());
        QVERIFY(state(backend, radio).value("message").toString().startsWith(
            scanFails ? "Could not scan" : "Scan complete"));
        QFile scans(directory.filePath("state-scans"));
        QVERIFY(scans.open(QIODevice::ReadOnly));
        QCOMPARE(scans.readAll(), radio.toUtf8() + '\n');
        if (wifi) {
            QFile command(directory.filePath("state-wifi-scan-command"));
            QVERIFY(command.open(QIODevice::ReadOnly));
            QVERIFY(command.readAll().contains("wifi list --rescan yes"));
        }
    }
    void failedPowerOnDoesNotScan_data() {
        QTest::addColumn<QString>("radio");
        QTest::newRow("bluetooth") << QStringLiteral("bluetooth");
        QTest::newRow("wifi") << QStringLiteral("wifi");
    }
    void failedPowerOnDoesNotScan() {
        QFETCH(QString, radio);
        write("state", "no\n");
        qputenv("RADIO_TEST_FAIL", "yes");
        Backend backend;
        if (radio == QLatin1String("wifi")) backend.setWifiEnabled(true);
        else backend.setBluetoothEnabled(true);
        QTRY_VERIFY(!state(backend, radio).value("busy").toBool());
        QCOMPARE(state(backend, radio).value("action").toString(), QStringLiteral("power-on"));
        QVERIFY(!state(backend, radio).value("success").toBool());
        QVERIFY(!(radio == QLatin1String("wifi") ? backend.wifiEnabled() : backend.bluetoothEnabled()));
        QFile scans(directory.filePath("state-scans"));
        QVERIFY(scans.open(QIODevice::ReadOnly));
        QVERIFY(scans.readAll().isEmpty());
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
            const bool bluetooth = radio == QLatin1String("bluetooth");
            QObject *orb = panel->findChild<QObject *>(radio + "Orb");
            {
                QVERIFY(orb);
                QVERIFY(orb->property("animating").toBool());
                const double phase = orb->property("phase").toDouble();
                QTest::qWait(80);
                QVERIFY(orb->property("phase").toDouble() != phase);
            }
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
            auto *powerItem = qobject_cast<QQuickItem *>(power);
            QVERIFY(powerItem);
            const QPoint powerCenter = powerItem->mapToScene(
                QPointF(powerItem->width() / 2, powerItem->height() / 2)).toPoint();
            QSignalSpy powerClicks(power, SIGNAL(clicked()));
            QTest::mouseClick(&window, Qt::LeftButton, Qt::NoModifier, powerCenter);
            QVERIFY(power->property("busy").toBool());
            QVERIFY(!power->property("pendingChecked").toBool());
            QVERIFY(!power->property("enabled").toBool());
            QVERIFY(!scan->property("enabled").toBool());
            QVERIFY(!settings->property("enabled").toBool());
            QTest::mouseClick(&window, Qt::LeftButton, Qt::NoModifier, powerCenter);
            QCOMPARE(powerClicks.count(), 1);
            QCOMPARE(state(backend, radio).value("action").toString(), QStringLiteral("power-off"));
            if (orb) QVERIFY(orb->property("working").toBool());
            capture("power-pending");
            QTRY_VERIFY(!state(backend, radio).value("busy").toBool());
            QVERIFY(!power->property("checked").toBool());
            if (orb) QVERIFY(!orb->property("animating").toBool());
            QVERIFY(power->property("enabled").toBool());
            QVERIFY(!scan->property("enabled").toBool());
            capture("off");
            if (radio == QLatin1String("bluetooth")) backend.setBluetoothEnabled(true);
            else backend.setWifiEnabled(true);
            QVERIFY(power->property("pendingChecked").toBool());
            QTRY_VERIFY(!state(backend, radio).value("busy").toBool());
            QVERIFY(power->property("checked").toBool());
            QVERIFY(scan->property("enabled").toBool());
            if (radio == QLatin1String("bluetooth")) backend.scanBluetoothDevices();
            else backend.scanWifiNetworks();
            QVERIFY(scan->property("busy").toBool());
            capture("scanning");
            QTRY_VERIFY(!state(backend, radio).value("busy").toBool());
            capture("on");
            if (orb) {
                for (const bool connect : {false, true}) {
                    auto *action = findVisualItem(item, bluetooth
                        ? "bluetoothDeviceAction-11:22:33:44:55:66" : "wifiNetworkAction-Test Wi-Fi");
                    QVERIFY(action);
                    QVERIFY(action->isEnabled());
                    const QPoint center = action->mapToScene(
                        QPointF(action->width() / 2, action->height() / 2)).toPoint();
                    QTest::mouseClick(&window, Qt::LeftButton, Qt::NoModifier, center);
                    const char *busyProperty = bluetooth ? "deviceActionBusy" : "actionBusy";
                    QVERIFY(panel->property(busyProperty).toBool());
                    QVERIFY(orb->property("working").toBool());
                    QVERIFY(!action->isEnabled());
                    QVERIFY(!power->property("enabled").toBool());
                    QVERIFY(!scan->property("enabled").toBool());
                    QVERIFY(!settings->property("enabled").toBool());
                    QTest::mouseClick(&window, Qt::LeftButton, Qt::NoModifier, center);
                    capture(connect ? "connecting" : "disconnecting");
                    QTRY_VERIFY_WITH_TIMEOUT(!panel->property(busyProperty).toBool(), 5000);
                    QCOMPARE(bluetooth ? backend.bluetoothConnected() : backend.wifiConnected(), connect);
                }
                QFile actions(directory.filePath(bluetooth ? "state-actions" : "state-wifi-actions"));
                QVERIFY(actions.open(QIODevice::ReadOnly));
                QCOMPARE(actions.readAll(), QByteArray("disconnect\nconnect\n"));
                auto *devices = panel->findChild<QQuickItem *>(bluetooth ? "bluetoothDevicesPage" : "wifiNetworksPage");
                auto *details = panel->findChild<QQuickItem *>(radio + "DetailsPage");
                auto *indicator = panel->findChild<QQuickItem *>(radio + "TabIndicator");
                QVERIFY(devices && details && indicator);
                auto *deviceDetail = panel->findChild<QQuickItem *>(bluetooth ? "bluetoothDetail-Device" : "wifiDetail-Network");
                auto *backendDetail = panel->findChild<QQuickItem *>(radio + "Detail-Backend");
                QVERIFY(deviceDetail && backendDetail);
                item->setProperty("activeTab", QStringLiteral("details"));
                QVERIFY(!devices->isEnabled());
                QVERIFY(details->isEnabled());
                QTest::qWait(60);
                QVERIFY(details->opacity() > 0 && details->opacity() < 1);
                QVERIFY(devices->opacity() > 0 && devices->opacity() < 1);
                QVERIFY(indicator->x() > 0 && indicator->x() < 199);
                QVERIFY(deviceDetail->opacity() > 0 && deviceDetail->opacity() < 1);
                QCOMPARE(backendDetail->opacity(), 0.0);
                // Reverse mid-transition to check that quick tab clicks settle correctly.
                item->setProperty("activeTab", bluetooth ? QStringLiteral("devices") : QStringLiteral("networks"));
                QTRY_COMPARE(devices->opacity(), 1.0);
                QTRY_COMPARE(details->opacity(), 0.0);
                QTRY_COMPARE(indicator->x(), 0.0);
                QVERIFY(!details->isEnabled());
                QTRY_COMPARE(deviceDetail->opacity(), 0.0);
                QTRY_COMPARE(backendDetail->opacity(), 0.0);
            }
            item->setProperty("activeTab", QStringLiteral("details"));
            QTest::qWait(500);
            if (orb) {
                QCOMPARE(panel->findChild<QQuickItem *>(bluetooth ? "bluetoothDetail-Device" : "wifiDetail-Network")->opacity(), 1.0);
                QCOMPARE(panel->findChild<QQuickItem *>(radio + "Detail-Backend")->opacity(), 1.0);
            }
            capture("details");
            if (!bluetooth) {
                item->setProperty("activeTab", QStringLiteral("networks"));
                QTest::qWait(400);
                auto *guest = findVisualItem(item, "wifiNetworkAction-Guest Wi-Fi");
                QVERIFY(guest);
                const QPoint guestCenter = guest->mapToScene(
                    QPointF(guest->width() / 2, guest->height() / 2)).toPoint();
                QTest::mouseClick(&window, Qt::LeftButton, Qt::NoModifier, guestCenter);
                QCOMPARE(panel->property("passwordSsid").toString(), QStringLiteral("Guest Wi-Fi"));
                auto *input = panel->findChild<QQuickItem *>("wifiPasswordInput");
                auto *submit = panel->findChild<QQuickItem *>("wifiPasswordConnect");
                QVERIFY(input && submit);
                QVERIFY(!submit->isEnabled());
                QTest::qWait(240);
                capture("password");
                input->setProperty("text", QStringLiteral("test-password"));
                QVERIFY(submit->isEnabled());
                const QPoint submitCenter = submit->mapToScene(
                    QPointF(submit->width() / 2, submit->height() / 2)).toPoint();
                QTest::mouseClick(&window, Qt::LeftButton, Qt::NoModifier, submitCenter);
                QVERIFY(panel->property("actionBusy").toBool());
                QVERIFY(!submit->isEnabled());
                QVERIFY(!input->isEnabled());
                QTest::mouseClick(&window, Qt::LeftButton, Qt::NoModifier, submitCenter);
                capture("password-pending");
                QTRY_VERIFY(!panel->property("actionBusy").toBool());
                QCOMPARE(panel->property("passwordSsid").toString(), QString());
                QCOMPARE(backend.wifiSsid(), QStringLiteral("Guest Wi-Fi"));
                QFile actions(directory.filePath("state-wifi-actions"));
                QVERIFY(actions.open(QIODevice::ReadOnly));
                QCOMPARE(actions.readAll(), QByteArray("disconnect\nconnect\nconnect\n"));
            }
            item->setProperty("opened", false);
            if (orb) {
                QVERIFY(!orb->property("animating").toBool());
                const double phase = orb->property("phase").toDouble();
                QTest::qWait(80);
                QCOMPARE(orb->property("phase").toDouble(), phase);
            }
            item->setParentItem(nullptr);
        }
    }
};

QTEST_MAIN(ConnectionActionsTest)
#include "connection-actions.test.moc"
