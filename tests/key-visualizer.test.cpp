#include "../components/Backend.h"

#include <QFile>
#include <QGuiApplication>
#include <QKeyEvent>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickWindow>
#include <QRegularExpression>
#include <QSignalSpy>
#include <QScopeGuard>
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
    void spacesOnlySpecialKeysAndShortcuts() {
        VisualizerBackend backend;
        QQmlEngine engine;
        engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
        QQmlComponent component(&engine,
            QUrl::fromLocalFile(QFINDTESTDATA("../components/KeyVisualizer.qml")));
        QVERIFY2(component.isReady(), qPrintable(component.errorString()));
        QScopedPointer<QObject> object(component.create());
        QVERIFY2(object, qPrintable(component.errorString()));
        const auto check = [&object](const QVariantList &history, const QString &expected) {
            object->setProperty("history", history);
            QCOMPARE(object->property("displayText").toString(), expected);
            QString styled = object->property("styledText").toString();
            styled.remove(QRegularExpression(QStringLiteral("</?font[^>]*>")));
            QCOMPARE(styled, expected);
        };
        check({}, QString());
        check({"h", "e", "l", "l", "o", "1", "!", QString::fromUtf8("ก")},
            QString::fromUtf8("hello1!ก"));
        for (const QString &key : QStringList{QString::fromUtf8("␣"), QString::fromUtf8("⌫"),
                 QString::fromUtf8("↵"), QString::fromUtf8("⇥"), QStringLiteral("Esc"),
                 QString::fromUtf8("⌦"), QString::fromUtf8("←"), QString::fromUtf8("→"),
                 QString::fromUtf8("↑"), QString::fromUtf8("↓"), QStringLiteral("Home"),
                 QStringLiteral("End"), QStringLiteral("PgUp"), QStringLiteral("PgDn"),
                 QStringLiteral("Ctrl+a"), QStringLiteral("Alt+x"),
                 QStringLiteral("Super+a"), QStringLiteral("Ctrl+Alt+a")}) {
            check({"a", "b", key, "c", "d"}, QStringLiteral("ab ") + key + " cd");
            check({key}, key);
            check({key, key}, key + " " + key);
        }
        check({"h", "e", "l", "l", "o", QString::fromUtf8("␣"),
                  "w", "o", "r", "l", "d", "Ctrl+a", QString::fromUtf8("⌫")},
            QString::fromUtf8("hello ␣ world Ctrl+a ⌫"));
        object->setProperty("history", QVariantList{QStringLiteral("helloworld123")});
        const qreal wordWidth = object->property("implicitWidth").toReal();
        QVERIFY(wordWidth > 180);
        QVariantList characters;
        for (const QChar letter : QStringLiteral("helloworld123"))
            characters.append(QString(letter));
        object->setProperty("history", characters);
        QCOMPARE(object->property("implicitWidth").toReal(), wordWidth);
    }

    void appliesAndPersistsPadding() {
        QTemporaryDir config;
        QVERIFY(config.isValid());
        const QByteArray previous = qgetenv("XDG_CONFIG_HOME");
        qputenv("XDG_CONFIG_HOME", config.path().toUtf8());
        const auto restoreConfig = qScopeGuard([previous] {
            if (previous.isNull()) qunsetenv("XDG_CONFIG_HOME");
            else qputenv("XDG_CONFIG_HOME", previous);
        });
        Backend backend;
        QCOMPARE(backend.keyVisualizerSettings().value(QStringLiteral("padding")).toString(),
            QStringLiteral("md"));
        backend.setKeyVisualizerSetting(QStringLiteral("minWidth"), 120);
        QQmlEngine engine;
        engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
        QQmlComponent component(&engine,
            QUrl::fromLocalFile(QFINDTESTDATA("../components/KeyVisualizer.qml")));
        QVERIFY2(component.isReady(), qPrintable(component.errorString()));
        QScopedPointer<QObject> object(component.create());
        QVERIFY2(object, qPrintable(component.errorString()));
        auto *display = object->findChild<QQuickItem *>(QStringLiteral("key-visualizer-display"));
        QVERIFY(display);
        object->setProperty("history", QVariantList{QStringLiteral("Padding test")});
        for (const QString &font : {QStringLiteral("sm"), QStringLiteral("md"),
                 QStringLiteral("lg")}) {
            backend.setKeyVisualizerSetting(QStringLiteral("fontSize"), font);
            backend.setKeyVisualizerSetting(QStringLiteral("padding"), QStringLiteral("md"));
            const qreal defaultWidth = object->property("implicitWidth").toReal();
            const qreal defaultHeight = object->property("implicitHeight").toReal();
            QCOMPARE(defaultHeight, font == QStringLiteral("sm") ? 64.0
                : font == QStringLiteral("lg") ? 96.0 : 78.0);
            backend.setKeyVisualizerSetting(QStringLiteral("padding"), QStringLiteral("sm"));
            QCOMPARE(object->property("padding").toInt(), 4);
            QVERIFY(object->property("implicitWidth").toReal() < defaultWidth);
            QVERIFY(object->property("implicitHeight").toReal() < defaultHeight);
            QCOMPARE(object->property("implicitHeight").toReal(),
                qCeil(display->property("implicitHeight").toReal()) + 8.0);
            backend.setKeyVisualizerSetting(QStringLiteral("padding"), QStringLiteral("lg"));
            QCOMPARE(object->property("implicitWidth").toReal(), defaultWidth + 24);
            QCOMPARE(object->property("implicitHeight").toReal(), defaultHeight + 24);
        }
        backend.setKeyVisualizerSetting(QStringLiteral("padding"), QStringLiteral("sm"));
        Backend reloaded;
        QCOMPARE(reloaded.keyVisualizerSettings().value(QStringLiteral("padding")).toString(),
            QStringLiteral("sm"));
        backend.setKeyVisualizerSetting(QStringLiteral("padding"), QStringLiteral("invalid"));
        QCOMPARE(backend.keyVisualizerSettings().value(QStringLiteral("padding")).toString(),
            QStringLiteral("md"));
    }

    void repeatsWidthButtonsAndAccelerates() {
        QTemporaryDir config;
        QVERIFY(config.isValid());
        const QByteArray previous = qgetenv("XDG_CONFIG_HOME");
        qputenv("XDG_CONFIG_HOME", config.path().toUtf8());
        const auto restoreConfig = qScopeGuard([previous] {
            if (previous.isNull()) qunsetenv("XDG_CONFIG_HOME");
            else qputenv("XDG_CONFIG_HOME", previous);
        });
        Backend backend;
        backend.setKeyVisualizerSetting(QStringLiteral("minWidth"), 120);
        backend.setKeyVisualizerSetting(QStringLiteral("maxWidth"), 180);
        QQmlEngine engine;
        engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
        QQmlComponent component(&engine,
            QUrl::fromLocalFile(QFINDTESTDATA("../components/SettingsPanel.qml")));
        QVERIFY2(component.isReady(), qPrintable(component.errorString()));
        QScopedPointer<QObject> object(component.create());
        QVERIFY2(object, qPrintable(component.errorString()));
        auto *settings = qobject_cast<QQuickItem *>(object.data());
        QVERIFY(settings);
        settings->setProperty("section", QStringLiteral("keys"));
        QQuickWindow window;
        window.resize(660, 510);
        settings->setParentItem(window.contentItem());
        window.show();
        QTRY_VERIFY(window.isExposed());

        std::function<QQuickItem *(QQuickItem *, const QString &)> findButton;
        findButton = [&findButton](QQuickItem *item, const QString &name) {
            if (item->objectName() == name) return item;
            for (auto *child : item->childItems())
                if (auto *found = findButton(child, name)) return found;
            return static_cast<QQuickItem *>(nullptr);
        };
        const auto position = [&findButton, settings](const QString &name) {
            auto *button = findButton(settings, name);
            return button ? button->mapToScene(QPointF(button->width() / 2,
                button->height() / 2)).toPoint() : QPoint(-1, -1);
        };
        const auto width = [&backend](const QString &key) {
            return backend.keyVisualizerSettings().value(key).toInt();
        };
        const QString maxKey = QStringLiteral("maxWidth");
        const QString minKey = QStringLiteral("minWidth");
        const QPoint plus = position(QStringLiteral("key-width-maxWidth-increase"));
        QVERIFY(plus.x() >= 0);
        QTest::mouseClick(&window, Qt::LeftButton, Qt::NoModifier, plus);
        QCOMPARE(width(maxKey), 200);
        QTest::qWait(500);
        QCOMPARE(width(maxKey), 200);

        QSignalSpy changes(&backend, &Backend::keyVisualizerSettingsChanged);
        QTest::mousePress(&window, Qt::LeftButton, Qt::NoModifier, plus);
        QCOMPARE(width(maxKey), 220);
        QTest::qWait(500);
        const int earlyRepeats = changes.count() - 1;
        QVERIFY(earlyRepeats > 0);
        QTest::qWait(700);
        const int beforeLate = changes.count();
        QTest::qWait(500);
        QVERIFY(changes.count() - beforeLate > earlyRepeats);
        QTRY_COMPARE(width(maxKey), 1000);
        QTest::mouseRelease(&window, Qt::LeftButton, Qt::NoModifier, plus);
        QTest::qWait(200);
        QCOMPARE(width(maxKey), 1000);

        const QPoint minus = position(QStringLiteral("key-width-maxWidth-decrease"));
        QVERIFY(minus.x() >= 0);
        QTest::mousePress(&window, Qt::LeftButton, Qt::NoModifier, minus);
        QTest::qWait(550);
        QVERIFY(width(maxKey) < 980);
        QTest::mouseMove(&window, QPoint(650, 500));
        const int afterExit = width(maxKey);
        QTest::qWait(500);
        QCOMPARE(width(maxKey), afterExit);
        QTest::mouseRelease(&window, Qt::LeftButton, Qt::NoModifier, QPoint(650, 500));

        QTest::mousePress(&window, Qt::LeftButton, Qt::NoModifier, minus);
        settings->setProperty("section", QStringLiteral("themes"));
        const int afterHide = width(maxKey);
        QTest::qWait(500);
        QCOMPARE(width(maxKey), afterHide);
        QTest::mouseRelease(&window, Qt::LeftButton, Qt::NoModifier, minus);
        settings->setProperty("section", QStringLiteral("keys"));
        backend.setKeyVisualizerSetting(maxKey, 180);
        const QPoint minPlus = position(QStringLiteral("key-width-minWidth-increase"));
        QVERIFY(minPlus.x() >= 0);
        QTest::mousePress(&window, Qt::LeftButton, Qt::NoModifier, minPlus);
        QTRY_COMPARE(width(minKey), 180);
        QTest::qWait(300);
        QCOMPARE(width(minKey), 180);
        QTest::mouseRelease(&window, Qt::LeftButton, Qt::NoModifier, minPlus);
        QTest::mousePress(&window, Qt::LeftButton, Qt::NoModifier, minus);
        QTest::qWait(550);
        QCOMPARE(width(maxKey), 180);
        QTest::mouseRelease(&window, Qt::LeftButton, Qt::NoModifier, minus);
        const QPoint minMinus = position(QStringLiteral("key-width-minWidth-decrease"));
        QVERIFY(minMinus.x() >= 0);
        QTest::mousePress(&window, Qt::LeftButton, Qt::NoModifier, minMinus);
        QTRY_COMPARE(width(minKey), 120);
        QTest::qWait(300);
        QCOMPARE(width(minKey), 120);
        QTest::mouseRelease(&window, Qt::LeftButton, Qt::NoModifier, minMinus);
    }

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
            QString::fromUtf8("Ctrl+a Super+␣ <&"));
        const QString styled = object->property("styledText").toString();
        QVERIFY(styled.contains(QStringLiteral("<font color=\"#875a82\">Ctrl+</font>a")));
        QVERIFY(styled.contains(QString::fromUtf8(
            "<font color=\"#875a82\">Super+</font><font color=\"#875a82\">␣</font>")));
        QVERIFY(styled.endsWith(QStringLiteral("&lt;&amp;")));
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
        QTRY_VERIFY(window.isExposed());
        auto *scroll = object->findChild<QQuickItem *>(
            QStringLiteral("dock-components-scroll"));
        QVERIFY(scroll);
        scroll->setProperty("contentY", scroll->property("contentHeight").toReal()
            - scroll->height());
        const QString screenshot = qEnvironmentVariable("ZHYPRBOLA_COMPONENTS_SCREENSHOT");
        if (!screenshot.isEmpty())
            QVERIFY(window.grabWindow().save(screenshot));
        auto *box = object->findChild<QQuickItem *>(
            QStringLiteral("dock-component-launcher-box"));
        QVERIFY(box);
        QTRY_COMPARE(box->property("rowCount").toInt(), 2);
        QCOMPARE(box->height(), 136.0);
        auto *repeater = object->findChild<QQuickItem *>(
            QStringLiteral("dock-component-launcher-repeater"));
        QVERIFY(repeater);
        QCOMPARE(repeater->property("count").toInt(), 10);
        const QString keyName = QStringLiteral("dock-component-launcher-key-visualizer");
        QQuickItem *keys = nullptr;
        QQuickItem *first = nullptr;
        QQuickItem *last = nullptr;
        for (int i = 0; i < repeater->property("count").toInt(); ++i) {
            QQuickItem *tile = nullptr;
            QVERIFY(QMetaObject::invokeMethod(repeater, "itemAt",
                Q_RETURN_ARG(QQuickItem *, tile), Q_ARG(int, i)));
            if (tile && tile->objectName() == keyName) keys = tile;
            if (i == 0) first = tile;
            if (i == 9) last = tile;
        }
        QVERIFY(keys && first && last);
        QCOMPARE(first->mapToItem(box, QPointF(0, 0)), QPointF(12, 45));
        QCOMPARE(last->mapToItem(box, QPointF(0, 0)), QPointF(12, 82));
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
                     std::pair{QStringLiteral("padding"), QStringLiteral("md")},
                     std::pair{QStringLiteral("widthMode"), QStringLiteral("fit")},
                     std::pair{QStringLiteral("alignment"), QStringLiteral("center")}}) {
                auto *mark = check(selection.first, selection.second);
                QVERIFY2(mark, qPrintable(checkNames.join(QLatin1Char(','))));
                QVERIFY(mark->isVisible());
            }
            backend.setKeyVisualizerSetting(QStringLiteral("fontSize"), QStringLiteral("lg"));
            backend.setKeyVisualizerSetting(QStringLiteral("padding"), QStringLiteral("sm"));
            backend.setKeyVisualizerSetting(QStringLiteral("widthMode"), QStringLiteral("fixed"));
            backend.setKeyVisualizerSetting(QStringLiteral("alignment"), QStringLiteral("right"));
            QTRY_VERIFY(check(QStringLiteral("fontSize"), QStringLiteral("lg"))->isVisible());
            QTRY_VERIFY(check(QStringLiteral("padding"), QStringLiteral("sm"))->isVisible());
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
            auto *scroll = object->findChild<QQuickItem *>(
                QStringLiteral("key-visualizer-scroll"));
            QVERIFY(scroll);
            settings->setHeight(440);
            QCOMPARE(scroll->height(), 352.0);
            QVERIFY(scroll->clip());
            const qreal bottom = scroll->property("contentHeight").toReal() - scroll->height();
            QVERIFY(bottom > 0);
            QVERIFY(QMetaObject::invokeMethod(scroll, "flick",
                Q_ARG(qreal, 0.0), Q_ARG(qreal, -500.0)));
            QTRY_VERIFY(scroll->property("contentY").toReal() > 0);
            QVERIFY(QMetaObject::invokeMethod(scroll, "cancelFlick"));
            scroll->setProperty("contentY", bottom);
            QVERIFY(button->mapToItem(scroll, QPointF(0, 0)).y() >= 0);
            QVERIFY(button->mapToItem(scroll, QPointF(0, button->height())).y()
                <= scroll->height());
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
            QString::fromUtf8("h Ctrl+a Ctrl+A Aก"));
        QTest::keyClick(&window, Qt::Key_Space);
        QTest::keyClick(&window, Qt::Key_Backspace);
        QTRY_COMPARE(visualizer->property("displayText").toString(),
            QString::fromUtf8("h Ctrl+a Ctrl+A Aก ␣ ⌫"));

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

    void rendersHeldKeysWithoutRepeatingModifiers() {
        VisualizerBackend backend;
        QQmlEngine engine;
        engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
        QQmlComponent component(&engine,
            QUrl::fromLocalFile(QFINDTESTDATA("../components/KeyVisualizer.qml")));
        QVERIFY2(component.isReady(), qPrintable(component.errorString()));
        QScopedPointer<QObject> object(component.create());
        QVERIFY2(object, qPrintable(component.errorString()));
        auto *visualizer = qobject_cast<QQuickItem *>(object.data());
        QVERIFY(visualizer);
        QQuickWindow window;
        window.resize(480, 78);
        visualizer->setParentItem(window.contentItem());
        window.show();
        window.requestActivate();
        visualizer->forceActiveFocus();
        QTRY_VERIFY(visualizer->hasActiveFocus());
        const auto press = [&window](int key, Qt::KeyboardModifiers modifiers,
            const QString &text, bool repeat) {
            QKeyEvent event(QEvent::KeyPress, key, modifiers, text, repeat);
            QCoreApplication::sendEvent(&window, &event);
        };
        press(Qt::Key_A, Qt::NoModifier, QStringLiteral("a"), false);
        press(Qt::Key_A, Qt::NoModifier, QStringLiteral("a"), true);
        press(Qt::Key_A, Qt::NoModifier, QStringLiteral("a"), true);
        QCOMPARE(object->property("displayText").toString(), QStringLiteral("aaa"));
        for (int key : {Qt::Key_Control, Qt::Key_Shift, Qt::Key_Alt, Qt::Key_Meta}) {
            press(key, Qt::NoModifier, QString(), false);
            press(key, Qt::NoModifier, QString(), true);
        }
        QCOMPARE(object->property("displayText").toString(), QStringLiteral("aaa"));
        press(Qt::Key_A, Qt::ShiftModifier, QStringLiteral("A"), true);
        press(Qt::Key_A, Qt::ControlModifier, QString(), true);
        press(Qt::Key_Backspace, Qt::NoModifier, QString(), true);
        QCOMPARE(object->property("displayText").toString(),
            QString::fromUtf8("aaaA Ctrl+a ⌫"));

        object->setProperty("history", QVariantList{});
        backend.setKeyCaptureAvailable(true);
        for (const QString &name : {QStringLiteral("Control_L"),
                 QStringLiteral("Shift_L"), QStringLiteral("Alt_L"),
                 QStringLiteral("Super_L")}) {
            for (int i = 0; i < 3; ++i)
                emit backend.globalKeyPressed(name, QString(), true, true, true, true);
        }
        QCOMPARE(object->property("displayText").toString(), QString());
        for (int i = 0; i < 3; ++i)
            emit backend.globalKeyPressed(QStringLiteral("A"), QStringLiteral("A"),
                true, false, false, false);
        QCOMPARE(object->property("displayText").toString(), QStringLiteral("AAA"));
        for (int i = 0; i < 2; ++i)
            emit backend.globalKeyPressed(QStringLiteral("a"), QString(),
                false, true, false, false);
        QCOMPARE(object->property("displayText").toString(),
            QStringLiteral("AAA Ctrl+a Ctrl+a"));
        emit backend.globalKeyReleased(QStringLiteral("a"));
        emit backend.globalKeyReleased(QStringLiteral("Control_L"));
        emit backend.globalKeyPressed(QStringLiteral("a"), QStringLiteral("a"),
            false, false, false, false);
        QCOMPARE(object->property("displayText").toString(),
            QStringLiteral("AAA Ctrl+a Ctrl+a a"));
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
            QString::fromUtf8("h Ctrl+a Ctrl+A Aก ␣ ⌫"));

        visualizer->setProperty("history", QVariantList{});
        emit backend.globalKeyPressed(QStringLiteral("Shift_L"), QString(),
            true, false, false, false);
        for (const QChar letter : QStringLiteral("HEAD"))
            emit backend.globalKeyPressed(QString(letter), QString(letter),
                true, false, false, false);
        emit backend.globalKeyReleased(QStringLiteral("Shift_L"));
        QCOMPARE(visualizer->property("displayText").toString(), QStringLiteral("HEAD"));
        emit backend.globalKeyPressed(QStringLiteral("a"), QStringLiteral("a"),
            true, false, false, false);
        QCOMPARE(visualizer->property("displayText").toString(), QStringLiteral("HEADa"));

        QQuickWindow window;
        window.resize(480, 78);
        visualizer->setParentItem(window.contentItem());
        window.show();
        window.requestActivate();
        visualizer->forceActiveFocus();
        QTRY_VERIFY(visualizer->hasActiveFocus());
        QTest::keyClick(&window, Qt::Key_X);
        QCOMPARE(visualizer->property("displayText").toString(),
            QStringLiteral("HEADa"));
    }
};

QTEST_MAIN(KeyVisualizerTest)
#include "key-visualizer.test.moc"
