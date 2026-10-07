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
        QCOMPARE(backend.formatDate(value), QString::fromUtf8("๐๗/๑๐/๒๕๖๙"));
        backend.setDateTimeSetting(QStringLiteral("dateFormat"),
            QStringLiteral("ddd, d MMM yyyy"));
        const QString namedDate = backend.formatDate(value);
        QVERIFY(namedDate.contains(QString::fromUtf8("ต.ค.")));
        QVERIFY(namedDate.contains(QString::fromUtf8("๒๕๖๙")));
        backend.setDateTimeSetting(QStringLiteral("dateFormat"), QStringLiteral("dd/MM/yyyy"));
        backend.setDateTimeSetting(QStringLiteral("timeFormat"), QStringLiteral("12-colon"));
        backend.setDateTimeSetting(QStringLiteral("showSeconds"), true);
        QCOMPARE(backend.formatTime(value), QStringLiteral("02:05:09 PM"));
        backend.setDateTimeSetting(QStringLiteral("timeLocale"), QStringLiteral("thai"));
        QVERIFY(backend.formatTime(value).startsWith(QString::fromUtf8("๐๒:๐๕:๐๙")));

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
        QString previousLabel;
        for (const QVariant &section : sections) {
            const QString label = section.toMap().value(QStringLiteral("label")).toString();
            QVERIFY(!label.isEmpty());
            QVERIFY(QString::compare(previousLabel, label, Qt::CaseInsensitive) <= 0);
            previousLabel = label;
        }
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
        scroll->setProperty("contentY", 350);
        QTRY_VERIFY(scroll->property("contentY").toReal() > 0);
        const QImage bottomImage = window.grabWindow();
        QVERIFY(!bottomImage.isNull());
        const QString bottomScreenshot = qEnvironmentVariable("ZHYPRBOLA_TEST_BOTTOM_SCREENSHOT");
        if (!bottomScreenshot.isEmpty())
            QVERIFY(bottomImage.save(bottomScreenshot));
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
