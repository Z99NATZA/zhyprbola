#include "../components/Backend.h"
#include "../components/SoundBackend.h"

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

class VisualizerBackend : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap keyVisualizerSettings READ keyVisualizerSettings CONSTANT)
    Q_PROPERTY(QString themeName READ themeName CONSTANT)
    Q_PROPERTY(bool keyCaptureAvailable READ keyCaptureAvailable NOTIFY keyCaptureAvailableChanged)
public:
    QVariantMap keyVisualizerSettings() const {
        return {{QStringLiteral("fontSize"), QStringLiteral("md")},
            {QStringLiteral("minWidth"), 180}, {QStringLiteral("maxWidth"), 480},
            {QStringLiteral("widthMode"), QStringLiteral("fit")},
            {QStringLiteral("alignment"), QStringLiteral("center")}};
    }
    QString themeName() const { return QStringLiteral("current"); }
    bool keyCaptureAvailable() const { return m_keyCaptureAvailable; }
    void setKeyCaptureAvailable(bool available) {
        m_keyCaptureAvailable = available;
        emit keyCaptureAvailableChanged();
    }
signals:
    void keyCaptureAvailableChanged();
    void globalKeyPressed(const QString &name, const QString &text,
        bool shift, bool ctrl, bool alt, bool super);
    void globalKeyReleased(const QString &name);
private:
    bool m_keyCaptureAvailable = false;
};

class KeyVisualizerTest : public QObject {
    Q_OBJECT
private slots:
    void opensCustomContextMenuWithRightClick() {
        QTemporaryDir config;
        QVERIFY(config.isValid());
        const QByteArray previous = qgetenv("XDG_CONFIG_HOME");
        qputenv("XDG_CONFIG_HOME", config.path().toUtf8());
        {
            Backend backend;
            SoundBackend sound;
            QQmlEngine engine;
            engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
            engine.rootContext()->setContextProperty(QStringLiteral("sound"), &sound);
            const QString file = QFINDTESTDATA("../PanelHost.qml");
            QVERIFY(!file.isEmpty());
            QQmlComponent component(&engine, QUrl::fromLocalFile(file));
            QVERIFY2(component.isReady(), qPrintable(component.errorString()));
            QScopedPointer<QObject> object(component.createWithInitialProperties(
                {{QStringLiteral("requestedPanel"), QStringLiteral("clock-weather")}}));
            QVERIFY2(object, qPrintable(component.errorString()));
            auto *window = qobject_cast<QQuickWindow *>(object.data());
            QVERIFY(window);
            auto *menu = object->findChild<QObject *>(QStringLiteral("panel-context-menu"));
            auto *pin = object->findChild<QQuickItem *>(QStringLiteral("panel-context-pin"));
            auto *trigger = object->findChild<QQuickItem *>(QStringLiteral("panel-context-trigger"));
            QVERIFY(menu);
            QVERIFY(pin);
            QVERIFY(trigger);
            QVERIFY(!menu->property("visible").toBool());

            window->show();
            QTRY_VERIFY(window->isExposed());
            QSignalSpy rightClicks(trigger, SIGNAL(clicked(QQuickMouseEvent*)));
            QVERIFY(rightClicks.isValid());
            QTest::mouseClick(window, Qt::RightButton, Qt::NoModifier, QPoint(30, 30));
            QTRY_COMPARE(rightClicks.count(), 1);
            QTRY_VERIFY(menu->property("visible").toBool());
            QCOMPARE(pin->property("text").toString(), QStringLiteral("Pin on top"));
            const QPoint click = pin->mapToScene(
                QPointF(pin->width() / 2, pin->height() / 2)).toPoint();
            QVERIFY(pin->window());
            QTest::mouseClick(pin->window(), Qt::LeftButton, Qt::NoModifier, click);
            QTRY_VERIFY(backend.panelPinned(QStringLiteral("clock-weather")));

            QTest::mouseClick(window, Qt::RightButton, Qt::NoModifier, QPoint(30, 30));
            QTRY_VERIFY(menu->property("visible").toBool());
            QCOMPARE(pin->property("text").toString(), QStringLiteral("Unpin"));
            QMetaObject::invokeMethod(menu, "close");

            QScopedPointer<QObject> small(component.createWithInitialProperties(
                {{QStringLiteral("requestedPanel"), QStringLiteral("key-visualizer")}}));
            QVERIFY2(small, qPrintable(component.errorString()));
            auto *smallWindow = qobject_cast<QQuickWindow *>(small.data());
            QVERIFY(smallWindow);
            auto *smallMenu = small->findChild<QObject *>(QStringLiteral("panel-context-menu"));
            auto *smallPin = small->findChild<QQuickItem *>(QStringLiteral("panel-context-pin"));
            QVERIFY(smallMenu);
            QVERIFY(smallPin);
            smallWindow->show();
            QTRY_VERIFY(smallWindow->isExposed());
            QTest::mouseClick(smallWindow, Qt::RightButton, Qt::NoModifier,
                QPoint(20, 20));
            QTRY_VERIFY(smallMenu->property("visible").toBool());
            QVERIFY(smallPin->window() != smallWindow);
            QVERIFY(smallPin->window()->height() > smallWindow->height());
        }
        if (previous.isEmpty()) qunsetenv("XDG_CONFIG_HOME");
        else qputenv("XDG_CONFIG_HOME", previous);
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
