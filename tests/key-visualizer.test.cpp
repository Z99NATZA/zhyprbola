#include "../components/Backend.h"

#include <QFile>
#include <QGuiApplication>
#include <QKeyEvent>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickWindow>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QtTest>
#include <functional>
#include <utility>

class VisualizerBackend : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap keyVisualizerSettings READ keyVisualizerSettings CONSTANT)
    Q_PROPERTY(QString themeName READ themeName NOTIFY themeChanged)
    Q_PROPERTY(bool keyCaptureAvailable READ keyCaptureAvailable NOTIFY keyCaptureAvailableChanged)
public:
    QVariantMap keyVisualizerSettings() const {
        return {{QStringLiteral("fontSize"), QStringLiteral("md")},
            {QStringLiteral("minWidth"), 180}, {QStringLiteral("maxWidth"), 480},
            {QStringLiteral("widthMode"), QStringLiteral("fit")},
            {QStringLiteral("alignment"), QStringLiteral("center")}};
    }
    QString themeName() const { return m_themeName; }
    void setThemeName(const QString &name) {
        m_themeName = name;
        emit themeChanged();
    }
    bool keyCaptureAvailable() const { return m_keyCaptureAvailable; }
    void setKeyCaptureAvailable(bool available) {
        m_keyCaptureAvailable = available;
        emit keyCaptureAvailableChanged();
    }
signals:
    void keyCaptureAvailableChanged();
    void themeChanged();
    void globalKeyPressed(const QString &name, const QString &text,
        bool shift, bool ctrl, bool alt, bool super);
    void globalKeyReleased(const QString &name);
private:
    bool m_keyCaptureAvailable = false;
    QString m_themeName = QStringLiteral("current");
};

class KeyVisualizerTest : public QObject {
    Q_OBJECT
private slots:
    void colorsSpecialKeysWithTheme() {
        VisualizerBackend backend;
        QQmlEngine engine;
        engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
        const QString file = QFINDTESTDATA("../components/KeyVisualizer.qml");
        QVERIFY(!file.isEmpty());
        QQmlComponent component(&engine, QUrl::fromLocalFile(file));
        QVERIFY2(component.isReady(), qPrintable(component.errorString()));
        QScopedPointer<QObject> object(component.create());
        QVERIFY2(object, qPrintable(component.errorString()));
        auto *display = object->findChild<QQuickItem *>(
            QStringLiteral("key-visualizer-display"));
        QVERIFY(display);

        emit backend.globalKeyPressed(QStringLiteral("a"), QStringLiteral("a"),
            false, true, false, false);
        emit backend.globalKeyPressed(QStringLiteral("space"), QStringLiteral(" "),
            false, false, false, true);
        emit backend.globalKeyPressed(QStringLiteral("less"), QStringLiteral("<"),
            false, false, false, false);
        emit backend.globalKeyPressed(QStringLiteral("ampersand"), QStringLiteral("&"),
            false, false, false, false);
        QCOMPARE(object->property("displayText").toString(),
            QString::fromUtf8("Ctrl+a Super+␣ < &"));
        const QString styled = object->property("styledText").toString();
        QVERIFY(styled.contains(QStringLiteral("<font color=\"#875a82\">Ctrl+</font>a")));
        QVERIFY(styled.contains(QString::fromUtf8(
            "<font color=\"#875a82\">Super+</font><font color=\"#875a82\">␣</font>")));
        QVERIFY(styled.endsWith(QStringLiteral("&lt; &amp;")));
        QCOMPARE(display->property("text").toString(), styled);

        backend.setThemeName(QStringLiteral("white"));
        QTRY_VERIFY(object->property("styledText").toString().contains(
            QStringLiteral("<font color=\"#467b9d\">Ctrl+</font>")));

        auto *visualizer = qobject_cast<QQuickItem *>(object.data());
        QVERIFY(visualizer);
        QQuickWindow window;
        window.resize(480, 78);
        visualizer->setParentItem(window.contentItem());
        visualizer->setSize(QSizeF(480, 78));
        window.show();
        QTRY_VERIFY(window.isExposed());
        const QImage image = window.grabWindow();
        int accentPixels = 0;
        for (int y = 0; y < image.height(); ++y) {
            for (int x = 0; x < image.width(); ++x) {
                const QColor pixel = image.pixelColor(x, y);
                if (qAbs(pixel.red() - 70) < 18 && qAbs(pixel.green() - 123) < 18
                    && qAbs(pixel.blue() - 157) < 18)
                    ++accentPixels;
            }
        }
        QVERIFY(accentPixels > 20);
    }

    void fitsLauncherIconsInsideSettings() {
        Backend backend;
        QQmlEngine engine;
        engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
        const QString file = QFINDTESTDATA("../components/SettingsPanel.qml");
        QVERIFY(!file.isEmpty());
        QQmlComponent component(&engine, QUrl::fromLocalFile(file));
        QVERIFY2(component.isReady(), qPrintable(component.errorString()));
        QScopedPointer<QObject> object(component.create());
        QVERIFY2(object, qPrintable(component.errorString()));
        auto *settings = qobject_cast<QQuickItem *>(object.data());
        QVERIFY(settings);
        settings->setProperty("section", QStringLiteral("components"));
        QQuickWindow window;
        window.resize(660, 510);
        settings->setParentItem(window.contentItem());
        window.show();
        auto *scroll = object->findChild<QQuickItem *>(
            QStringLiteral("dock-components-scroll"));
        QVERIFY(scroll);
        scroll->setProperty("contentY", scroll->property("contentHeight").toReal()
            - scroll->height());
        auto *box = object->findChild<QQuickItem *>(
            QStringLiteral("dock-component-launcher-box"));
        QVERIFY(box);
        QTRY_COMPARE(box->property("rowCount").toInt(), 2);
        QCOMPARE(box->property("columnCount").toInt(), 5);
        auto *repeater = object->findChild<QQuickItem *>(
            QStringLiteral("dock-component-launcher-repeater"));
        QVERIFY(repeater);
        QCOMPARE(repeater->property("count").toInt(), 10);
        const QString keyName = QStringLiteral("dock-component-launcher-key-visualizer");
        QQuickItem *keys = nullptr;
        for (int i = 0; i < repeater->property("count").toInt(); ++i) {
            QQuickItem *tile = nullptr;
            QVERIFY(QMetaObject::invokeMethod(repeater, "itemAt",
                Q_RETURN_ARG(QQuickItem *, tile), Q_ARG(int, i)));
            if (tile && tile->objectName() == keyName) keys = tile;
        }
        QVERIFY(keys);
        const QPointF position = keys->mapToItem(box, QPointF(0, 0));
        QVERIFY(position.x() >= 0 && position.x() + keys->width() <= box->width());
        QVERIFY(position.y() >= 0 && position.y() + keys->height() < box->height());
    }

    void opensKeyVisualizerFromSettings() {
        QTemporaryDir config;
        QVERIFY(config.isValid());
        const QByteArray previous = qgetenv("XDG_CONFIG_HOME");
        qputenv("XDG_CONFIG_HOME", config.path().toUtf8());
        {
            Backend backend;
            QQmlEngine engine;
            engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
            const QString file = QFINDTESTDATA("../components/SettingsPanel.qml");
            QVERIFY(!file.isEmpty());
            QQmlComponent component(&engine, QUrl::fromLocalFile(file));
            QVERIFY2(component.isReady(), qPrintable(component.errorString()));
            QScopedPointer<QObject> object(component.create());
            QVERIFY2(object, qPrintable(component.errorString()));
            auto *settings = qobject_cast<QQuickItem *>(object.data());
            QVERIFY(settings);
            settings->setProperty("section", QStringLiteral("keys"));
            QSignalSpy closeRequests(settings, SIGNAL(closeRequested()));
            QVERIFY(closeRequests.isValid());
            QQuickWindow window;
            window.resize(660, 510);
            settings->setParentItem(window.contentItem());
            window.show();

            QStringList checkNames;
            std::function<QQuickItem *(QQuickItem *, const QString &)> findVisual;
            findVisual = [&findVisual, &checkNames](QQuickItem *item, const QString &name) {
                if (!item->objectName().isEmpty()) checkNames.append(item->objectName());
                if (item->objectName() == name) return item;
                for (auto *child : item->childItems()) {
                    if (auto *found = findVisual(child, name)) return found;
                }
                return static_cast<QQuickItem *>(nullptr);
            };
            const auto check = [&findVisual, settings](const QString &key,
                const QString &value) {
                return findVisual(settings, QStringLiteral("key-choice-check-")
                    + key + QLatin1Char('-') + value);
            };
            for (const auto &selection : {
                     std::pair{QStringLiteral("fontSize"), QStringLiteral("md")},
                     std::pair{QStringLiteral("widthMode"), QStringLiteral("fit")},
                     std::pair{QStringLiteral("alignment"), QStringLiteral("center")}}) {
                auto *mark = check(selection.first, selection.second);
                QVERIFY2(mark, qPrintable(checkNames.join(QLatin1Char(','))));
                QVERIFY(mark->isVisible());
            }
            backend.setKeyVisualizerSetting(QStringLiteral("fontSize"), QStringLiteral("lg"));
            backend.setKeyVisualizerSetting(QStringLiteral("widthMode"), QStringLiteral("fixed"));
            backend.setKeyVisualizerSetting(QStringLiteral("alignment"), QStringLiteral("right"));
            QTRY_VERIFY(check(QStringLiteral("fontSize"), QStringLiteral("lg"))->isVisible());
            QTRY_VERIFY(check(QStringLiteral("widthMode"), QStringLiteral("fixed"))->isVisible());
            QTRY_VERIFY(check(QStringLiteral("alignment"), QStringLiteral("right"))->isVisible());
            QVERIFY(!check(QStringLiteral("fontSize"), QStringLiteral("md"))->isVisible());
            const QString screenshot = qEnvironmentVariable("ZHYPRBOLA_KEY_CHOICE_SCREENSHOT");
            if (!screenshot.isEmpty())
                QVERIFY(window.grabWindow().save(screenshot));

            auto *button = object->findChild<QQuickItem *>(
                QStringLiteral("open-key-visualizer"));
            QVERIFY(button);
            QVERIFY(button->isVisible());
            const QPoint click = button->mapToScene(
                QPointF(button->width() / 2, button->height() / 2)).toPoint();
            QTest::mouseClick(&window, Qt::LeftButton, Qt::NoModifier, click);
            QCOMPARE(closeRequests.count(), 0);

            QFile request(config.filePath(QStringLiteral("zhyprbola/panel-request")));
            QVERIFY(request.open(QIODevice::ReadOnly));
            QVERIFY(request.readAll().trimmed().endsWith(":key-visualizer"));
        }
        if (previous.isEmpty()) qunsetenv("XDG_CONFIG_HOME");
        else qputenv("XDG_CONFIG_HOME", previous);
    }

    void rendersTypedKeys() {
        VisualizerBackend backend;
        QQmlEngine engine;
        engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
        const QString file = QFINDTESTDATA("../components/KeyVisualizer.qml");
        QVERIFY(!file.isEmpty());
        QQmlComponent component(&engine, QUrl::fromLocalFile(file));
        QVERIFY2(component.isReady(), qPrintable(component.errorString()));
        QScopedPointer<QObject> object(component.create());
        QVERIFY2(object, qPrintable(component.errorString()));
        auto *visualizer = qobject_cast<QQuickItem *>(object.data());
        QVERIFY(visualizer);
        QQuickWindow window;
        window.resize(480, 78);
        visualizer->setParentItem(window.contentItem());
        visualizer->setSize(QSizeF(480, 78));
        window.show();
        window.requestActivate();
        visualizer->forceActiveFocus();
        QTRY_VERIFY(visualizer->hasActiveFocus());

        QTest::keyClick(&window, Qt::Key_H);
        QTRY_COMPARE(visualizer->property("displayText").toString(), QStringLiteral("h"));
        QTest::keyClick(&window, Qt::Key_A, Qt::ControlModifier);
        QTRY_COMPARE(visualizer->property("displayText").toString(), QStringLiteral("h Ctrl+a"));
        QKeyEvent ctrlShift(QEvent::KeyPress, Qt::Key_A,
            Qt::ControlModifier | Qt::ShiftModifier, QString());
        QCoreApplication::sendEvent(&window, &ctrlShift);
        QCOMPARE(visualizer->property("displayText").toString(),
            QStringLiteral("h Ctrl+a Ctrl+A"));
        QKeyEvent shifted(QEvent::KeyPress, Qt::Key_A, Qt::ShiftModifier,
            QStringLiteral("A"));
        QCoreApplication::sendEvent(&window, &shifted);
        QCOMPARE(visualizer->property("displayText").toString(),
            QStringLiteral("h Ctrl+a Ctrl+A A"));
        QTest::keyClick(&window, Qt::Key_Shift);
        QCOMPARE(visualizer->property("displayText").toString(),
            QStringLiteral("h Ctrl+a Ctrl+A A"));

        QKeyEvent thai(QEvent::KeyPress, Qt::Key_unknown, Qt::NoModifier,
            QString::fromUtf8("ก"));
        QCoreApplication::sendEvent(&window, &thai);
        QTRY_COMPARE(visualizer->property("displayText").toString(),
            QString::fromUtf8("h Ctrl+a Ctrl+A A ก"));
        QTest::keyClick(&window, Qt::Key_Space);
        QTest::keyClick(&window, Qt::Key_Backspace);
        QTRY_COMPARE(visualizer->property("displayText").toString(),
            QString::fromUtf8("h Ctrl+a Ctrl+A A ก ␣ ⌫"));

        const QImage image = window.grabWindow();
        QVERIFY(!image.isNull());
        int inkPixels = 0;
        for (int y = 0; y < image.height(); ++y) {
            for (int x = 0; x < image.width(); ++x) {
                const QColor pixel = image.pixelColor(x, y);
                if (pixel.red() < 130 && pixel.green() < 130 && pixel.blue() < 130)
                    ++inkPixels;
            }
        }
        QVERIFY(inkPixels > 30);
    }

    void rendersGlobalKeysWithoutWindowFocus() {
        VisualizerBackend backend;
        QQmlEngine engine;
        engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
        const QString file = QFINDTESTDATA("../components/KeyVisualizer.qml");
        QVERIFY(!file.isEmpty());
        QQmlComponent component(&engine, QUrl::fromLocalFile(file));
        QVERIFY2(component.isReady(), qPrintable(component.errorString()));
        QScopedPointer<QObject> object(component.create());
        QVERIFY2(object, qPrintable(component.errorString()));
        auto *visualizer = qobject_cast<QQuickItem *>(object.data());
        QVERIFY(visualizer);
        backend.setKeyCaptureAvailable(true);

        emit backend.globalKeyPressed(QStringLiteral("h"), QStringLiteral("h"),
            false, false, false, false);
        emit backend.globalKeyPressed(QStringLiteral("a"), QStringLiteral("a"),
            false, true, false, false);
        emit backend.globalKeyPressed(QStringLiteral("A"), QString(),
            true, true, false, false);
        emit backend.globalKeyPressed(QStringLiteral("Shift_L"), QString(),
            true, false, false, false);
        emit backend.globalKeyPressed(QStringLiteral("A"), QStringLiteral("A"),
            true, false, false, false);
        emit backend.globalKeyReleased(QStringLiteral("Shift_L"));
        emit backend.globalKeyPressed(QStringLiteral("Thai_kokai"),
            QString::fromUtf8("ก"), false, false, false, false);
        emit backend.globalKeyPressed(QStringLiteral("space"), QStringLiteral(" "),
            false, false, false, false);
        emit backend.globalKeyPressed(QStringLiteral("BackSpace"), QString(),
            false, false, false, false);
        QCOMPARE(visualizer->property("displayText").toString(),
            QString::fromUtf8("h Ctrl+a Ctrl+A A ก ␣ ⌫"));

        visualizer->setProperty("history", QVariantList{});
        emit backend.globalKeyPressed(QStringLiteral("Shift_L"), QString(),
            true, false, false, false);
        for (const QChar letter : QStringLiteral("HEAD"))
            emit backend.globalKeyPressed(QString(letter), QString(letter),
                true, false, false, false);
        emit backend.globalKeyReleased(QStringLiteral("Shift_L"));
        QCOMPARE(visualizer->property("displayText").toString(), QStringLiteral("H E A D"));
        emit backend.globalKeyPressed(QStringLiteral("a"), QStringLiteral("a"),
            true, false, false, false);
        QCOMPARE(visualizer->property("displayText").toString(), QStringLiteral("H E A D a"));

        QQuickWindow window;
        window.resize(480, 78);
        visualizer->setParentItem(window.contentItem());
        window.show();
        window.requestActivate();
        visualizer->forceActiveFocus();
        QTRY_VERIFY(visualizer->hasActiveFocus());
        QTest::keyClick(&window, Qt::Key_X);
        QCOMPARE(visualizer->property("displayText").toString(),
            QStringLiteral("H E A D a"));
    }
};

QTEST_MAIN(KeyVisualizerTest)
#include "key-visualizer.test.moc"
