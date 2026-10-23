#include "../components/Backend.h"

#include <QGuiApplication>
#include <QDir>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQmlEngine>
#include <QJsonDocument>
#include <QLineF>
#include <QQuickItem>
#include <QQuickWindow>
#include <QFile>
#include <QTemporaryDir>
#include <QtTest>

namespace {
QQuickItem *findItem(QQuickItem *root, const QString &objectName) {
    if (root->objectName() == objectName)
        return root;
    for (QQuickItem *child : root->childItems()) {
        if (QQuickItem *match = findItem(child, objectName))
            return match;
    }
    return nullptr;
}
}

class ScreenshotSettingsStub : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString edgeSide READ edgeSide NOTIFY positionChanged)
    Q_PROPERTY(QString edgeAlignment READ edgeAlignment NOTIFY positionChanged)
    Q_PROPERTY(QString edgeWidth READ edgeWidth CONSTANT)
    Q_PROPERTY(QString edgeHeight READ edgeHeight CONSTANT)
public:
    QString edgeSide() const { return m_side; }
    QString edgeAlignment() const { return m_alignment; }
    QString edgeWidth() const { return QStringLiteral("sm"); }
    QString edgeHeight() const { return QStringLiteral("lg"); }
    Q_INVOKABLE void setPosition(const QString &side, const QString &alignment) {
        m_side = side;
        m_alignment = alignment;
        emit positionChanged();
    }
    Q_INVOKABLE void refresh() { }
signals:
    void positionChanged();
private:
    QString m_side = QStringLiteral("left");
    QString m_alignment = QStringLiteral("3");
};

class DateTimeTest : public QObject {
    Q_OBJECT
private slots:
    void sharedDockRegionsMigrateAndPersistMixedItems() {
        QTemporaryDir directory;
        qputenv("XDG_CONFIG_HOME", directory.path().toUtf8());
        Backend backend;
        auto region = [&backend](int index) {
            return backend.dockLayout().value("regions").toList()[index].toStringList();
        };
        QVERIFY(region(0).isEmpty());
        QCOMPARE(region(1), QStringList{QStringLiteral("running")});
        QVERIFY(region(2).contains(QStringLiteral("settings")));
        QVERIFY(backend.dockLayout().value("hidden").toStringList().contains(QStringLiteral("apps")));
        backend.moveDockLayoutItem("workspaces", "region-1", {});
        backend.moveDockLayoutItem("running", "region-1", {});
        backend.moveDockLayoutItem("time-display", "region-1", "running");
        QCOMPARE(region(0), (QStringList{"workspaces", "time-display", "running"}));
        QVERIFY(region(1).isEmpty());
        backend.moveDockLayoutItem("settings", "region-2", {});
        QCOMPARE(region(1), QStringList{"settings"});
        const auto layout = backend.dockLayout();
        backend.moveDockLayoutItem("settings", "hidden", {});
        backend.moveDockLayoutItem("settings", "quick", {});
        backend.moveDockLayoutItem("running", "quick", {});
        backend.moveDockLayoutItem("workspaces", "quick", {});
        backend.moveDockLayoutItem("wifi", "region-1", "missing");
        QCOMPARE(backend.dockLayout(), layout);
        Backend reopened;
        QCOMPARE(reopened.dockLayout(), layout);
        backend.moveDockComponent("time-display", "hidden", {});
        QVERIFY(!region(0).contains("time-display"));
        backend.moveDockComponent("time-display", "visible", "running");
        QCOMPARE(region(0), (QStringList{"workspaces", "time-display", "running"}));
        backend.moveDockLayoutItem("apps", "region-1", {});
        QVERIFY(region(0).contains("apps") && region(0).contains("running"));
        backend.moveDockLayoutItem("running", "hidden", {});
        QVERIFY(!backend.dockGroups().contains("running"));
        backend.setDockGroupEnabled("running", true);
        QVERIFY(backend.dockGroups().contains("running"));
    }

    void sharedDockLayoutRejectsDuplicatesAndRestoresMissingItems() {
        QTemporaryDir directory;
        qputenv("XDG_CONFIG_HOME", directory.path().toUtf8());
        QVERIFY(QDir().mkpath(directory.filePath("zhyprbola")));
        QFile file(directory.filePath("zhyprbola/dock-layout"));
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write(R"({"regions":[["running","settings","wifi","wifi"],["running","apps","bogus"],[]],"hidden":["settings","wifi","workspaces"],"quick":["running","workspaces","sound"]})");
        file.close();
        Backend backend;
        const auto layout = backend.dockLayout();
        const auto regions = layout.value("regions").toList();
        QCOMPARE(regions[0].toStringList(), (QStringList{"running", "settings", "wifi"}));
        QCOMPARE(regions[1].toStringList(), QStringList{"apps"});
        QCOMPARE(layout.value("hidden").toStringList(), QStringList{"workspaces"});
        QVERIFY(layout.value("quick").toStringList().contains("sound"));
        QStringList all;
        for (const QVariant &value : regions) all.append(value.toStringList());
        all.append(layout.value("hidden").toStringList());
        all.append(layout.value("quick").toStringList());
        QCOMPARE(all.count("running"), 1);
        QCOMPARE(all.count("settings"), 1);
        QCOMPARE(all.count("wifi"), 1);
        QVERIFY(all.contains("date-display") && !all.contains("bogus"));
    }

    void dockLayoutSettingsSupportsClickAndDragPlacement() {
        QTemporaryDir directory;
        qputenv("XDG_CONFIG_HOME", directory.path().toUtf8());
        Backend backend;
        backend.moveDockLayoutItem("workspaces", "region-1", {});
        ScreenshotSettingsStub screenshots;
        QQmlEngine engine;
        engine.rootContext()->setContextProperty("backend", &backend);
        engine.rootContext()->setContextProperty("screenshots", &screenshots);
        QQmlComponent component(&engine, QUrl::fromLocalFile(QFINDTESTDATA("../components/SettingsPanel.qml")));
        QVERIFY2(component.isReady(), qPrintable(component.errorString()));
        QScopedPointer<QObject> object(component.create());
        QVERIFY2(object, qPrintable(component.errorString()));
        object->setProperty("section", "components");
        auto *panel = qobject_cast<QQuickItem *>(object.data());
        QVERIFY(panel);
        QQuickWindow window;
        window.resize(660, qRound(panel->height()));
        panel->setParentItem(window.contentItem());
        window.show();
        QTRY_VERIFY(window.isExposed());
        auto center = [&panel](const QString &name) {
            auto *item = findItem(panel, name);
            return item ? item->mapToScene(QPointF(item->width() / 2, item->height() / 2)).toPoint() : QPoint(-1, -1);
        };
        auto region = [&backend](int index) { return backend.dockLayout().value("regions").toList()[index].toStringList(); };
        const QPoint running = center("dock-component-region-2-running");
        QVERIFY(running.x() >= 0);
        QTest::mouseClick(&window, Qt::LeftButton, Qt::NoModifier, running);
        QTRY_COMPARE(object->property("selectedDockItem").toString(), QStringLiteral("running"));
        QVERIFY(!findItem(panel, "move-dock-item-quick"));
        QTest::mouseClick(&window, Qt::LeftButton, Qt::NoModifier, center("move-dock-item-region-1"));
        QTRY_COMPARE(region(0), (QStringList{"workspaces", "running"}));
        const QPoint date = center("dock-component-region-3-date-display");
        const QPoint first = center("dock-component-region-1-workspaces");
        QVERIFY(date.x() >= 0 && first.x() >= 0);
        QTest::mousePress(&window, Qt::LeftButton, Qt::NoModifier, date);
        QTest::mouseMove(&window, first, 30);
        QTest::mouseRelease(&window, Qt::LeftButton, Qt::NoModifier, first);
        QTRY_COMPARE(region(0), (QStringList{"date-display", "workspaces", "running"}));
        const QPoint settings = center("dock-component-region-3-settings");
        QVERIFY(settings.x() >= 0);
        QTest::mouseClick(&window, Qt::LeftButton, Qt::NoModifier, settings);
        QTRY_COMPARE(object->property("selectedDockItem").toString(), QStringLiteral("settings"));
        QVERIFY(!findItem(panel, "move-dock-item-hidden"));
        QTRY_VERIFY(findItem(panel, "move-dock-item-region-2"));
        QTest::qWait(60);
        QTest::mouseClick(&window, Qt::LeftButton, Qt::NoModifier, center("move-dock-item-region-2"));
        QTRY_COMPARE(region(1), QStringList{"settings"});
        const QString screenshot = qEnvironmentVariable("ZHYPRBOLA_LAYOUT_SCREENSHOT");
        if (!screenshot.isEmpty()) QVERIFY(window.grabWindow().save(screenshot));
    }

    void workspaceComponentPersistsPlacementAndCannotEnterQuick() {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        qputenv("XDG_CONFIG_HOME", directory.path().toUtf8());
        const QString key = QStringLiteral("workspaces");
        Backend backend;
        QCOMPARE(backend.dockVisibleComponents().first(), key);
        QVERIFY(!backend.opacityEnabledComponents().contains(key));
        QVERIFY(!backend.opacityDisabledComponents().contains(key));
        backend.moveDockComponent(key, QStringLiteral("hidden"), {});
        QVERIFY(backend.dockHiddenComponents().contains(key));
        backend.moveDockComponent(key, QStringLiteral("quick"), {});
        QVERIFY(backend.dockHiddenComponents().contains(key));
        QVERIFY(!backend.dockQuickComponents().contains(key));
        Backend reopened;
        QVERIFY(reopened.dockHiddenComponents().contains(key));
        QVERIFY(!reopened.dockVisibleComponents().contains(key));
        QFile file(directory.filePath(QStringLiteral("zhyprbola/dock-components")));
        QVERIFY(file.open(QIODevice::WriteOnly | QIODevice::Truncate));
        file.write(R"({"visible":["settings"],"hidden":[],"quick":["workspaces"]})");
        file.close();
        Backend migrated;
        QCOMPARE(migrated.dockVisibleComponents().first(), key);
        QVERIFY(!migrated.dockQuickComponents().contains(key));
    }

    void spectrumBarLengthsPersistAndKeepTheirBaselineOnEveryEdge() {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        qputenv("XDG_CONFIG_HOME", directory.path().toUtf8());
        Backend settings;
        Backend observer;
        QCOMPARE(settings.edgeSpectrumSize(), QStringLiteral("lg"));

        QQmlEngine engine;
        engine.rootContext()->setContextProperty(QStringLiteral("backend"), &observer);
        engine.rootContext()->setContextProperty(QStringLiteral("edgeScreenWidth"), 800);
        engine.rootContext()->setContextProperty(QStringLiteral("edgeScreenHeight"), 600);
        QQmlComponent component(&engine, QUrl::fromLocalFile(
            QFINDTESTDATA("../EdgeSpectrum.qml")));
        QVERIFY2(component.isReady(), qPrintable(component.errorString()));
        QScopedPointer<QObject> edge(component.create());
        QVERIFY2(edge, qPrintable(component.errorString()));
        auto *window = qobject_cast<QQuickWindow *>(edge.data());
        QVERIFY(window);
        auto *bars = findItem(window->contentItem(), QStringLiteral("edge-spectrum-bars"));
        QVERIFY(bars);

        for (const QString &side : {QStringLiteral("bottom"), QStringLiteral("top"),
                 QStringLiteral("left"), QStringLiteral("right")}) {
            observer.setEdgeSpectrumPosition(side);
            const int count = bars->property("barCount").toInt();
            const qreal thickness = bars->property("inwardBarWidth").toReal();
            for (const QString &size : {QStringLiteral("sm"), QStringLiteral("md"),
                     QStringLiteral("lg")}) {
                settings.setEdgeSpectrumSize(size);
                QTRY_COMPARE(observer.edgeSpectrumSize(), size);
                const int length = size == QLatin1String("sm") ? 54
                    : size == QLatin1String("md") ? 108 : 161;
                QTRY_COMPARE(bars->height(), qreal(length));
                QCOMPARE(bars->property("barCount").toInt(), count);
                QCOMPARE(bars->property("inwardBarWidth").toReal(), thickness);
                QCOMPARE(bars->property("gap").toInt(), 4);
                const QPointF baseline = bars->mapToScene(
                    QPointF(bars->width() / 2, bars->height()));
                const QPointF expected = side == QLatin1String("bottom")
                    ? QPointF(window->width() / 2.0, window->height())
                    : side == QLatin1String("top") ? QPointF(window->width() / 2.0, 0)
                    : side == QLatin1String("left") ? QPointF(0, window->height() / 2.0)
                    : QPointF(window->width(), window->height() / 2.0);
                QVERIFY2(QLineF(baseline, expected).length() < 0.1,
                    qPrintable(QStringLiteral("%1/%2: baseline (%3,%4), expected (%5,%6)")
                        .arg(side, size).arg(baseline.x()).arg(baseline.y())
                        .arg(expected.x()).arg(expected.y())));
                Backend reopened;
                QCOMPARE(reopened.edgeSpectrumSize(), size);
            }
        }
        settings.setEdgeSpectrumSize(QStringLiteral("invalid"));
        QCOMPARE(settings.edgeSpectrumSize(), QStringLiteral("lg"));
        QFile saved(directory.filePath(QStringLiteral("zhyprbola/edge-spectrum-size")));
        QVERIFY(saved.open(QIODevice::WriteOnly | QIODevice::Truncate));
        saved.write("invalid\n");
        saved.close();
        Backend invalid;
        QCOMPARE(invalid.edgeSpectrumSize(), QStringLiteral("lg"));
    }

    void spectrumSettingsOfferClickableLengthChoices() {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        qputenv("XDG_CONFIG_HOME", directory.path().toUtf8());
        Backend backend;
        ScreenshotSettingsStub screenshots;
        QQmlEngine engine;
        engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
        engine.rootContext()->setContextProperty(QStringLiteral("screenshots"), &screenshots);
        QQmlComponent component(&engine, QUrl::fromLocalFile(
            QFINDTESTDATA("../components/SettingsPanel.qml")));
        QVERIFY2(component.isReady(), qPrintable(component.errorString()));
        QScopedPointer<QObject> panel(component.create());
        QVERIFY2(panel, qPrintable(component.errorString()));
        panel->setProperty("section", QStringLiteral("spectrum"));
        auto *item = qobject_cast<QQuickItem *>(panel.data());
        QVERIFY(item);
        QQuickWindow window;
        window.resize(item->width(), item->height());
        item->setParentItem(window.contentItem());
        window.show();
        QTRY_VERIFY(window.isExposed());
        for (const QString &size : {QStringLiteral("sm"), QStringLiteral("md"),
                 QStringLiteral("lg")}) {
            auto *choice = findItem(item, QStringLiteral("spectrum-size-") + size);
            QVERIFY(choice);
            QVERIFY(choice->isVisible());
            const QPointF center = choice->mapToScene(QPointF(
                choice->width() / 2, choice->height() / 2));
            QTest::mouseClick(&window, Qt::LeftButton, Qt::NoModifier, center.toPoint());
            QCOMPARE(backend.edgeSpectrumSize(), size);
            auto *check = findItem(item, QStringLiteral("spectrum-size-check-") + size);
            QVERIFY(check);
            QVERIFY(check->isVisible());
        }
    }

    void formatsAndPersistsIndependentSettings() {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        qputenv("XDG_CONFIG_HOME", directory.path().toUtf8());
        Backend backend;
        Backend observer;
        const QDateTime value(QDate(2026, 10, 7), QTime(14, 5, 9));

        QCOMPARE(backend.formatDate(value), QStringLiteral("2026-10-07"));
        QCOMPARE(backend.formatTime(value), QStringLiteral("14:05"));
        backend.setDateTimeSetting(QStringLiteral("dateFormat"), QStringLiteral("dd/MM/yyyy"));
        QTRY_COMPARE(observer.dateTimeSettings().value(QStringLiteral("dateFormat")).toString(),
            QStringLiteral("dd/MM/yyyy"));
        backend.setDateTimeSetting(QStringLiteral("dateLocale"), QStringLiteral("thai"));
        QCOMPARE(backend.formatDate(value), QStringLiteral("07/10/2569"));
        QCOMPARE(backend.previewDate(QStringLiteral("yyyy-MM-dd"), QStringLiteral("thai")),
            QStringLiteral("2569-10-07"));
        backend.setDateTimeSetting(QStringLiteral("dateFormat"),
            QStringLiteral("ddd, d MMM yyyy"));
        const QString namedDate = backend.formatDate(value);
        QVERIFY(namedDate.contains(QString::fromUtf8("ต.ค.")));
        QVERIFY(namedDate.contains(QStringLiteral("2569")));
        backend.setDateTimeSetting(QStringLiteral("dateFormat"), QStringLiteral("dd/MM/yyyy"));
        backend.setDateTimeSetting(QStringLiteral("timeFormat"), QStringLiteral("12-colon"));
        backend.setDateTimeSetting(QStringLiteral("showSeconds"), true);
        QCOMPARE(backend.formatTime(value), QStringLiteral("02:05:09 PM"));
        backend.setDateTimeSetting(QStringLiteral("timeLocale"), QStringLiteral("thai"));
        QVERIFY(backend.formatTime(value).startsWith(QStringLiteral("02:05:09")));

        Backend reloaded;
        QCOMPARE(reloaded.dateTimeSettings(), backend.dateTimeSettings());
        QCOMPARE(reloaded.formatDate(value), backend.formatDate(value));
        reloaded.setDateTimeSetting(QStringLiteral("dateFormat"), QStringLiteral("invalid"));
        QCOMPARE(reloaded.dateTimeSettings().value(QStringLiteral("dateFormat")).toString(),
            QStringLiteral("yyyy-MM-dd"));
    }

    void keepsDateAndTimeOnDock() {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        qputenv("XDG_CONFIG_HOME", directory.path().toUtf8());
        Backend backend;
        QVERIFY(backend.dockVisibleComponents().contains(QStringLiteral("date-display")));
        QVERIFY(backend.dockVisibleComponents().contains(QStringLiteral("time-display")));
        QVERIFY(backend.dockVisibleComponents().contains(QStringLiteral("key-count")));
        QVERIFY(!backend.dockQuickComponents().contains(QStringLiteral("date-display")));
        QVERIFY(!backend.dockQuickComponents().contains(QStringLiteral("key-count")));
        backend.moveDockComponent(QStringLiteral("key-count"), QStringLiteral("quick"), {});
        QVERIFY(backend.dockVisibleComponents().contains(QStringLiteral("key-count")));
        backend.moveDockComponent(QStringLiteral("date-display"), QStringLiteral("quick"), {});
        QVERIFY(backend.dockVisibleComponents().contains(QStringLiteral("date-display")));
        backend.moveDockComponent(QStringLiteral("date-display"), QStringLiteral("hidden"), {});
        QVERIFY(backend.dockHiddenComponents().contains(QStringLiteral("date-display")));
    }

    void keepsSettingsInShow() {
        for (const QByteArray &saved : {
                 QByteArrayLiteral("{\"visible\":[],\"hidden\":[\"settings\"],\"quick\":[]}"),
                 QByteArrayLiteral("{\"visible\":[],\"hidden\":[],\"quick\":[\"settings\"]}")}) {
            QTemporaryDir directory;
            QVERIFY(directory.isValid());
            qputenv("XDG_CONFIG_HOME", directory.path().toUtf8());
            QVERIFY(QDir().mkpath(directory.filePath(QStringLiteral("zhyprbola"))));
            QFile config(directory.filePath(QStringLiteral("zhyprbola/dock-components")));
            QVERIFY(config.open(QIODevice::WriteOnly));
            QCOMPARE(config.write(saved), saved.size());
            config.close();

            Backend backend;
            const QString settings = QStringLiteral("settings");
            QVERIFY(backend.dockVisibleComponents().contains(settings));
            QVERIFY(!backend.dockHiddenComponents().contains(settings));
            QVERIFY(!backend.dockQuickComponents().contains(settings));
            backend.moveDockComponent(settings, QStringLiteral("hidden"), {});
            backend.moveDockComponent(settings, QStringLiteral("quick"), {});
            QVERIFY(backend.dockVisibleComponents().contains(settings));
            QVERIFY(!backend.dockHiddenComponents().contains(settings));
            QVERIFY(!backend.dockQuickComponents().contains(settings));
            backend.moveDockComponent(settings, QStringLiteral("visible"),
                QStringLiteral("date-display"));
            const QStringList order = backend.dockVisibleComponents();
            QCOMPARE(order.indexOf(settings) + 1, order.indexOf(QStringLiteral("date-display")));
        }
    }

    void movingScreenshotHandlePreservesSizeAndHorizontalSide() {
        QTemporaryDir directory;
        qputenv("XDG_CONFIG_HOME", directory.path().toUtf8());
        QVERIFY(QDir().mkpath(directory.filePath("zhyprbola")));
        QFile file(directory.filePath("zhyprbola/screenshots-edge"));
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write(R"({"side":"top","alignment":"center","width":"lg","height":"md"})");
        file.close();
        Backend backend;
        QCOMPARE(backend.showDesktopEdgeSettings().value("position").toString(),
            QStringLiteral("top"));
        backend.moveEdgeHandle("screenshots", "5", {});
        QVERIFY(file.open(QIODevice::ReadOnly));
        const auto saved = QJsonDocument::fromJson(file.readAll()).object();
        QCOMPARE(saved.value("side").toString(), QStringLiteral("top"));
        QCOMPARE(saved.value("alignment").toString(), QStringLiteral("5"));
        QCOMPARE(saved.value("width").toString(), QStringLiteral("lg"));
        QCOMPARE(saved.value("height").toString(), QStringLiteral("md"));
    }
    void showDesktopEdgeSettingsPersistAndValidate() {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        qputenv("XDG_CONFIG_HOME", directory.path().toUtf8());
        QVERIFY(QDir().mkpath(directory.filePath(QStringLiteral("zhyprbola"))));
        QFile screenshots(directory.filePath(QStringLiteral("zhyprbola/screenshots-edge")));
        QVERIFY(screenshots.open(QIODevice::WriteOnly));
        QVERIFY(screenshots.write("{\"side\":\"right\",\"alignment\":\"center\"}") > 0);
        screenshots.close();

        Backend backend;
        QCOMPARE(backend.showDesktopEdgeSettings().value("position").toString(),
            QStringLiteral("right"));
        QCOMPARE(backend.showDesktopEdgeSettings().value("width").toString(),
            QStringLiteral("sm"));
        QCOMPARE(backend.showDesktopEdgeSettings().value("height").toString(),
            QStringLiteral("sm"));
        QCOMPARE(backend.showDesktopEdgeSettings().value("alignment").toString(),
            QStringLiteral("3"));
        QCOMPARE(backend.showDesktopEdgeSettings().value("order").toString(),
            QStringLiteral("screenshots-first"));
        backend.setShowDesktopEdgeSetting(QStringLiteral("width"), QStringLiteral("lg"));
        backend.setShowDesktopEdgeSetting(QStringLiteral("height"), QStringLiteral("md"));
        backend.moveEdgeHandle(QStringLiteral("show-desktop"),
            QStringLiteral("5"), {});
        backend.moveEdgeHandle(QStringLiteral("screenshots"),
            QStringLiteral("5"), QStringLiteral("show-desktop"));
        QCOMPARE(backend.showDesktopEdgeSettings().value("order").toString(),
            QStringLiteral("screenshots-first"));
        backend.moveEdgeHandle(QStringLiteral("screenshots"),
            QStringLiteral("5"), {});
        QCOMPARE(backend.showDesktopEdgeSettings().value("order").toString(),
            QStringLiteral("show-desktop-first"));
        QFile movedScreenshots(directory.filePath(QStringLiteral("zhyprbola/screenshots-edge")));
        QVERIFY(movedScreenshots.open(QIODevice::ReadOnly));
        QCOMPARE(QJsonDocument::fromJson(movedScreenshots.readAll()).object()
            .value(QStringLiteral("alignment")).toString(), QStringLiteral("5"));

        Backend reopened;
        QCOMPARE(reopened.showDesktopEdgeSettings(), backend.showDesktopEdgeSettings());
        reopened.setShowDesktopEdgeSetting(QStringLiteral("width"), QStringLiteral("invalid"));
        QCOMPARE(reopened.showDesktopEdgeSettings().value("width").toString(),
            QStringLiteral("lg"));
        reopened.setShowDesktopEdgeSetting(QStringLiteral("alignment"),
            QStringLiteral("invalid"));
        QCOMPARE(reopened.showDesktopEdgeSettings().value("alignment").toString(),
            QStringLiteral("5"));
    }

    void loadsDateTimeSettings() {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        qputenv("XDG_CONFIG_HOME", directory.path().toUtf8());
        Backend backend;
        QQmlEngine engine;
        engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
        ScreenshotSettingsStub screenshots;
        engine.rootContext()->setContextProperty(QStringLiteral("screenshots"), &screenshots);
        const QString settingsFile = QFINDTESTDATA("../components/SettingsPanel.qml");
        QVERIFY(!settingsFile.isEmpty());
        QQmlComponent settingsComponent(&engine, QUrl::fromLocalFile(settingsFile));
        QVERIFY2(settingsComponent.isReady(), qPrintable(settingsComponent.errorString()));
        QScopedPointer<QObject> settings(settingsComponent.create());
        QVERIFY2(settings, qPrintable(settingsComponent.errorString()));
        auto *settingsItem = qobject_cast<QQuickItem *>(settings.data());
        QVERIFY(settingsItem);
        QQuickWindow window;
        window.resize(660, 510);
        settingsItem->setParentItem(window.contentItem());
        window.show();
        QTRY_VERIFY(window.isExposed());
        const QVariantList sections = settings->property("sections").toList();
        QVERIFY(!sections.isEmpty());
        bool hasDateTime = false;
        bool hasShowDesktop = false;
        for (const QVariant &section : sections) {
            const QVariantMap entry = section.toMap();
            QVERIFY(!entry.value(QStringLiteral("label")).toString().isEmpty());
            hasDateTime |= entry.value(QStringLiteral("key")).toString()
                == QStringLiteral("date-time");
            hasShowDesktop |= entry.value(QStringLiteral("key")).toString()
                == QStringLiteral("show-desktop");
        }
        QVERIFY(hasDateTime);
        QVERIFY(!hasShowDesktop);
        bool hasEdgeHandles = false;
        for (const QVariant &section : sections)
            hasEdgeHandles |= section.toMap().value(QStringLiteral("key")).toString()
                == QStringLiteral("edge-handles");
        QVERIFY(hasEdgeHandles);
        settings->setProperty("section", QStringLiteral("show-desktop"));
        QTRY_VERIFY(findItem(settingsItem, QStringLiteral("show-desktop-position-left")));
        QTRY_VERIFY(findItem(settingsItem, QStringLiteral("show-desktop-width-sm")));
        QTRY_VERIFY(findItem(settingsItem, QStringLiteral("show-desktop-height-lg")));
        QTRY_VERIFY(findItem(settingsItem,
            QStringLiteral("edge-handle-zone-show-desktop-left-1")));
        QTRY_VERIFY(findItem(settingsItem,
            QStringLiteral("edge-handle-card-show-desktop-left-3-show-desktop")));
        const QString showDesktopScreenshot =
            qEnvironmentVariable("ZHYPRBOLA_TEST_SHOW_DESKTOP_SCREENSHOT");
        if (!showDesktopScreenshot.isEmpty())
            QVERIFY(window.grabWindow().save(showDesktopScreenshot));
        auto *showDesktopCard = findItem(settingsItem,
            QStringLiteral("edge-handle-card-show-desktop-left-3-show-desktop"));
        auto *topZone = findItem(settingsItem,
            QStringLiteral("edge-handle-zone-show-desktop-left-1"));
        QVERIFY(showDesktopCard);
        QVERIFY(topZone);
        auto *edgeScroll = findItem(settingsItem, QStringLiteral("edge-handles-settings-scroll"));
        QVERIFY(edgeScroll);
        edgeScroll->setProperty("contentY", 180);
        const QPoint dragStart = showDesktopCard->mapToScene(QPointF(
            showDesktopCard->width() / 2, showDesktopCard->height() / 2)).toPoint();
        const QPoint dragEnd = topZone->mapToScene(QPointF(
            topZone->width() / 4, topZone->height() / 2)).toPoint();
        QTest::mousePress(&window, Qt::LeftButton, Qt::NoModifier, dragStart);
        QTRY_COMPARE(settings->property("draggedEdgeHandle").toString(),
            QStringLiteral("show-desktop"));
        QTest::mouseMove(&window, dragEnd, 20);
        QTRY_COMPARE(settings->property("draggingEdgeHandle").toBool(), true);
        QTest::mouseRelease(&window, Qt::LeftButton, Qt::NoModifier, dragEnd);
        QTRY_COMPARE(backend.showDesktopEdgeSettings().value(
            QStringLiteral("alignment")).toString(), QStringLiteral("1"));
        auto *movedShowDesktopCard = findItem(settingsItem,
            QStringLiteral("edge-handle-card-show-desktop-left-1-show-desktop"));
        auto *centerZone = findItem(settingsItem,
            QStringLiteral("edge-handle-zone-show-desktop-left-3"));
        QVERIFY(movedShowDesktopCard);
        QVERIFY(centerZone);
        const QPoint reorderStart = movedShowDesktopCard->mapToScene(QPointF(
            movedShowDesktopCard->width() / 2,
            movedShowDesktopCard->height() / 2)).toPoint();
        const QPoint reorderEnd = centerZone->mapToScene(QPointF(
            centerZone->width() / 4, centerZone->height() / 2)).toPoint();
        QTest::mousePress(&window, Qt::LeftButton, Qt::NoModifier, reorderStart);
        QTest::mouseMove(&window, reorderEnd, 20);
        QTest::mouseRelease(&window, Qt::LeftButton, Qt::NoModifier, reorderEnd);
        QTRY_COMPARE(backend.showDesktopEdgeSettings().value(
            QStringLiteral("alignment")).toString(), QStringLiteral("3"));
        QTRY_COMPARE(backend.showDesktopEdgeSettings().value(
            QStringLiteral("order")).toString(), QStringLiteral("show-desktop-first"));
        backend.setShowDesktopEdgeSetting(QStringLiteral("position"), QStringLiteral("top"));
        QQuickItem *leftZone = nullptr;
        QTRY_VERIFY(leftZone = findItem(settingsItem,
            QStringLiteral("edge-handle-zone-show-desktop-top-1")));
        QCOMPARE(leftZone->property("label").toString(), QStringLiteral("1"));
        QTRY_VERIFY(findItem(settingsItem,
            QStringLiteral("edge-handle-card-show-desktop-top-3-show-desktop")));
        settings->setProperty("section", QStringLiteral("screenshots"));
        QCOMPARE(settings->property("section").toString(), QStringLiteral("edge-handles"));
        QTRY_VERIFY(findItem(settingsItem, QStringLiteral("screenshot-position-top")));
        QTRY_VERIFY(findItem(settingsItem, QStringLiteral("screenshot-width-lg")));
        QTRY_VERIFY(findItem(settingsItem, QStringLiteral("screenshot-height-sm")));
        QTRY_VERIFY(findItem(settingsItem,
            QStringLiteral("edge-handle-card-screenshots-left-3-screenshots")));
        settings->setProperty("section", QStringLiteral("themes"));
        QCOMPARE(settings->property("section").toString(), QStringLiteral("themes"));
        QFile request(directory.filePath(QStringLiteral("zhyprbola/settings-section-request")));
        QVERIFY(request.open(QIODevice::WriteOnly));
        QVERIFY(request.write("1:date-time\n") > 0);
        request.close();
        QTRY_COMPARE(settings->property("section").toString(), QStringLiteral("date-time"));
        const QImage image = window.grabWindow();
        QVERIFY(!image.isNull());
        QCOMPARE(image.size(), QSize(660, 510));
        const QString screenshot = qEnvironmentVariable("ZHYPRBOLA_TEST_SCREENSHOT");
        if (!screenshot.isEmpty())
            QVERIFY(image.save(screenshot));
        auto *scroll = settings->findChild<QQuickItem *>(QStringLiteral("date-time-scroll"));
        QVERIFY(scroll);
        QVERIFY(scroll->property("contentHeight").toReal() <= scroll->height());
        const QImage bottomImage = window.grabWindow();
        QVERIFY(!bottomImage.isNull());
        const QString bottomScreenshot = qEnvironmentVariable("ZHYPRBOLA_TEST_BOTTOM_SCREENSHOT");
        if (!bottomScreenshot.isEmpty())
            QVERIFY(bottomImage.save(bottomScreenshot));

        QTest::mouseClick(&window, Qt::LeftButton, Qt::NoModifier, QPoint(545, 94));
        QTRY_COMPARE(backend.dateTimeSettings().value(QStringLiteral("dateLocale")).toString(),
            QStringLiteral("thai"));
        QCOMPARE(backend.dateTimeSettings().value(QStringLiteral("timeLocale")).toString(),
            QStringLiteral("thai"));
        const QString thaiScreenshot = qEnvironmentVariable("ZHYPRBOLA_TEST_THAI_SCREENSHOT");
        if (!thaiScreenshot.isEmpty())
            QVERIFY(window.grabWindow().save(thaiScreenshot));

        QTest::mouseClick(&window, Qt::LeftButton, Qt::NoModifier, QPoint(300, 301));
        QCOMPARE(backend.dateTimeSettings().value(QStringLiteral("dateFormat")).toString(),
            QStringLiteral("d MMM yyyy"));
        QTest::mouseClick(&window, Qt::LeftButton, Qt::NoModifier, QPoint(500, 170));
        QCOMPARE(backend.dateTimeSettings().value(QStringLiteral("dateFormat")).toString(),
            QStringLiteral("dd-MM-yyyy"));
        QTest::mouseClick(&window, Qt::LeftButton, Qt::NoModifier, QPoint(500, 214));
        QCOMPARE(backend.dateTimeSettings().value(QStringLiteral("dateFormat")).toString(),
            QStringLiteral("dd/MM/yyyy"));

        QTest::mouseClick(&window, Qt::LeftButton, Qt::NoModifier, QPoint(595, 379));
        QCOMPARE(backend.dateTimeSettings().value(QStringLiteral("timeFormat")).toString(),
            QStringLiteral("12-dot"));
        QTest::mouseClick(&window, Qt::LeftButton, Qt::NoModifier, QPoint(600, 422));
        QCOMPARE(backend.dateTimeSettings().value(QStringLiteral("showSeconds")).toBool(), true);
    }

    void opensNewSettingsOnRequestedSection() {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        qputenv("XDG_CONFIG_HOME", directory.path().toUtf8());
        QVERIFY(QDir().mkpath(directory.filePath(QStringLiteral("zhyprbola"))));
        QFile request(directory.filePath(QStringLiteral("zhyprbola/settings-section-request")));
        QVERIFY(request.open(QIODevice::WriteOnly));
        QVERIFY(request.write("2:date-time\n") > 0);
        request.close();

        Backend backend;
        QCOMPARE(backend.settingsSectionRequest(), QStringLiteral("2:date-time"));
        QQmlEngine engine;
        engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
        ScreenshotSettingsStub screenshots;
        engine.rootContext()->setContextProperty(QStringLiteral("screenshots"), &screenshots);
        QQmlComponent component(&engine, QUrl::fromLocalFile(
            QFINDTESTDATA("../components/SettingsPanel.qml")));
        QVERIFY2(component.isReady(), qPrintable(component.errorString()));
        QScopedPointer<QObject> settings(component.create());
        QVERIFY2(settings, qPrintable(component.errorString()));
        QCOMPARE(settings->property("section").toString(), QStringLiteral("date-time"));
    }
};

QTEST_MAIN(DateTimeTest)
#include "date-time.test.moc"
