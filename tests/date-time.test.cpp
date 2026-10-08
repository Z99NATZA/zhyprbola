#include "../components/Backend.h"

#include <QGuiApplication>
#include <QDir>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickWindow>
#include <QFile>
#include <QTemporaryDir>
#include <QtTest>

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
        QVERIFY(!backend.dockQuickComponents().contains(QStringLiteral("date-display")));
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

    void loadsDateTimeSettings() {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        qputenv("XDG_CONFIG_HOME", directory.path().toUtf8());
        Backend backend;
        QQmlEngine engine;
        engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
        const QString settingsFile = QFINDTESTDATA("../components/SettingsPanel.qml");
        QVERIFY(!settingsFile.isEmpty());
        QQmlComponent settingsComponent(&engine, QUrl::fromLocalFile(settingsFile));
        QVERIFY2(settingsComponent.isReady(), qPrintable(settingsComponent.errorString()));
        QScopedPointer<QObject> settings(settingsComponent.create());
        QVERIFY2(settings, qPrintable(settingsComponent.errorString()));
        const QVariantList sections = settings->property("sections").toList();
        QVERIFY(!sections.isEmpty());
        bool hasDateTime = false;
        for (const QVariant &section : sections) {
            const QVariantMap entry = section.toMap();
            QVERIFY(!entry.value(QStringLiteral("label")).toString().isEmpty());
            hasDateTime |= entry.value(QStringLiteral("key")).toString()
                == QStringLiteral("date-time");
        }
        QVERIFY(hasDateTime);
        QCOMPARE(settings->property("section").toString(), QStringLiteral("themes"));
        QFile request(directory.filePath(QStringLiteral("zhyprbola/settings-section-request")));
        QVERIFY(request.open(QIODevice::WriteOnly));
        QVERIFY(request.write("1:date-time\n") > 0);
        request.close();
        QTRY_COMPARE(settings->property("section").toString(), QStringLiteral("date-time"));
        auto *settingsItem = qobject_cast<QQuickItem *>(settings.data());
        QVERIFY(settingsItem);
        QQuickWindow window;
        window.resize(660, 510);
        settingsItem->setParentItem(window.contentItem());
        window.show();
        QTRY_VERIFY(window.isExposed());
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
