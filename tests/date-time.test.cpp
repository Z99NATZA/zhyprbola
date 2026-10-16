#include "../components/Backend.h"

#include <QGuiApplication>
#include <QDir>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQmlEngine>
#include <QJsonDocument>
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
            QCOMPARE(backend.dockVisibleComponents().first(), settings);
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
