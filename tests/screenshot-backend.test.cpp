#include "../components/ScreenshotBackend.h"
#include <QClipboard>
#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlPropertyMap>
#include <QPointer>
#include <QSaveFile>
#include <QQuickWindow>
#include <QQuickItem>
#include <QWheelEvent>
#include <QtTest>

class ScreenshotTest : public QObject {
    Q_OBJECT
    static void write(const QString &path, const QByteArray &data = "image") {
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly));
        QCOMPARE(file.write(data), data.size());
    }
    static QString pathAt(ScreenshotBackend &model, int row) {
        return model.data(model.index(row), ScreenshotBackend::PathRole).toString();
    }
private slots:
    void initTestCase() {
        QStandardPaths::setTestModeEnabled(true);
        QQuickWindow::setSceneGraphBackend("software");
    }
    void selectionAndClipboard() {
        QTemporaryDir dir;
        for (const QString name : {"a.png", "b.png", "c.png", "d.png"}) write(dir.filePath(name));
        write(dir.filePath("ignored.txt"));
        ScreenshotBackend model(dir.path());
        QCOMPARE(model.rowCount(), 4);
        const QString a = pathAt(model, 0), b = pathAt(model, 1), c = pathAt(model, 2);
        model.select(0, false, false);
        model.select(2, true, false);
        QCOMPARE(model.selectedPaths(), QStringList({a, c}));
        model.select(1, false, true);
        QCOMPARE(model.selectedPaths(), QStringList({b, c}));
        model.copyPaths();
        QCOMPARE(QGuiApplication::clipboard()->text(), b + '\n' + c);
        model.select(1, true, false);
        QCOMPARE(model.selectedPaths(), QStringList({c}));
        model.selectAll();
        QCOMPARE(model.selectedPaths().size(), 4);
    }
    void batchDeleteAndPersistentUndo() {
        QTemporaryDir dir;
        write(dir.filePath("one.png"), "one");
        write(dir.filePath("two.png"), "two");
        {
            ScreenshotBackend model(dir.path());
            model.selectAll();
            model.deleteSelected();
            QCOMPARE(model.rowCount(), 0);
            QVERIFY(!QFileInfo::exists(dir.filePath("one.png")));
            QVERIFY(model.error().isEmpty());
        }
        ScreenshotBackend reopened(dir.path());
        reopened.undo();
        QCOMPARE(reopened.rowCount(), 2);
        QCOMPARE(reopened.selectedPaths().size(), 2);
        QFile file(dir.filePath("one.png"));
        QVERIFY(file.open(QIODevice::ReadOnly));
        QCOMPARE(file.readAll(), QByteArray("one"));
    }
    void undoNeverOverwritesNewFiles() {
        QTemporaryDir dir;
        write(dir.filePath("one.png"), "original");
        ScreenshotBackend model(dir.path());
        model.selectAll();
        model.deleteSelected();
        write(dir.filePath("one.png"), "replacement");
        model.undo();
        QVERIFY(!model.error().isEmpty());
        QFile file(dir.filePath("one.png"));
        QVERIFY(file.open(QIODevice::ReadOnly));
        QCOMPARE(file.readAll(), QByteArray("replacement"));
        file.close();
        QVERIFY(file.remove());
        model.undo();
        QVERIFY(file.open(QIODevice::ReadOnly));
        QCOMPARE(file.readAll(), QByteArray("original"));
    }
    void undoUsesLastDeleteFirstAndDirectoryChangesRefresh() {
        QTemporaryDir dir;
        write(dir.filePath("a.png"));
        ScreenshotBackend model(dir.path());
        model.selectAll();
        model.deleteSelected();
        QTest::qWait(2);
        write(dir.filePath("b.png"));
        QTRY_COMPARE(model.rowCount(), 1);
        model.selectAll();
        model.deleteSelected();
        model.undo();
        QCOMPARE(model.rowCount(), 1);
        QCOMPARE(QFileInfo(pathAt(model, 0)).fileName(), QString("b.png"));
        model.undo();
        QCOMPARE(model.rowCount(), 2);
    }
    void positionIsValidatedAndPersisted() {
        QTemporaryDir dir;
        ScreenshotBackend model(dir.path());
        const auto side = model.edgeSide(), alignment = model.edgeAlignment();
        model.setPosition("right", "bottom");
        ScreenshotBackend reopened(dir.path());
        QCOMPARE(reopened.edgeSide(), QString("right"));
        QCOMPARE(reopened.edgeAlignment(), QString("bottom"));
        reopened.setPosition("invalid", "invalid");
        QCOMPARE(reopened.edgeSide(), QString("right"));
        model.setPosition(side, alignment);
    }
    void screenshotsOpacityCanBeDisabledAndRestored() {
        QTemporaryDir config;
        QTemporaryDir images;
        const QByteArray previous = qgetenv("XDG_CONFIG_HOME");
        QStandardPaths::setTestModeEnabled(false);
        qputenv("XDG_CONFIG_HOME", config.path().toUtf8());
        const auto restoreConfig = qScopeGuard([previous] {
            if (previous.isNull()) qunsetenv("XDG_CONFIG_HOME");
            else qputenv("XDG_CONFIG_HOME", previous);
            QStandardPaths::setTestModeEnabled(true);
        });
        QImage sample(600, 600, QImage::Format_RGB32);
        sample.fill(Qt::red);
        QVERIFY(sample.save(images.filePath("sample.png")));
        ScreenshotBackend model(images.path());
        QVERIFY(model.opacityEnabledComponents().contains(QStringLiteral("screenshots")));
        const auto saveSetting = [&config](const QString &name, const QByteArray &data) {
            QSaveFile file(config.filePath("zhyprbola/" + name));
            QVERIFY(file.open(QIODevice::WriteOnly));
            QCOMPARE(file.write(data), data.size());
            QVERIFY(file.commit());
        };
        saveSetting("component-opacity", "35");
        QQmlApplicationEngine engine;
        engine.rootContext()->setContextProperty("screenshots", &model);
        engine.rootContext()->setContextProperty("backend", &model);
        engine.load(QUrl::fromLocalFile(QFINDTESTDATA("../ScreenshotHost.qml")));
        QVERIFY(!engine.rootObjects().isEmpty());
        auto *surface = engine.rootObjects().first()->findChild<QQuickItem *>("screenshotSurface");
        QVERIFY(surface);
        QTRY_COMPARE(surface->property("color").value<QColor>().alpha(), 89);
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QVERIFY(QTest::qWaitForWindowExposed(window));
        QTest::mouseDClick(window, Qt::LeftButton, Qt::NoModifier, QPoint(200, 95));
        auto *preview = window->findChild<QQuickWindow *>("screenshotPreviewWindow");
        QVERIFY(preview);
        QTRY_VERIFY(preview->isVisible());
        auto *image = preview->findChild<QQuickItem *>("screenshotPreviewImage");
        QVERIFY(image);
        QCOMPARE(image->opacity(), 0.35);
        saveSetting("component-opacity-components",
            R"({"opacity":[],"default":["screenshots"]})");
        QTRY_COMPARE(surface->property("color").value<QColor>().alpha(), 255);
        QCOMPARE(image->opacity(), 1.0);
        ScreenshotBackend reloaded(images.path());
        QVERIFY(reloaded.opacityDisabledComponents().contains(QStringLiteral("screenshots")));
        saveSetting("component-opacity-components",
            R"({"opacity":["screenshots"],"default":[]})");
        QTRY_COMPARE(surface->property("color").value<QColor>().alpha(), 89);
        QCOMPARE(image->opacity(), 0.35);
        auto *close = preview->findChild<QQuickItem *>("screenshotPreviewCloseButton");
        auto *resize = preview->findChild<QQuickItem *>("screenshotPreviewResizeHandle");
        QVERIFY(close);
        QVERIFY(resize);
        QCOMPARE(close->opacity(), 1.0);
        QCOMPARE(resize->opacity(), 1.0);
    }
    void scrollbarOnlyAppearsOnOverflowAndKeepsReservedWidth() {
        QTemporaryDir dir;
        ScreenshotBackend model(dir.path());
        QQmlPropertyMap theme;
        theme.insert("themeName", "current");
        theme.insert("componentOpacity", 100);
        theme.insert("opacityEnabledComponents", QStringList{});
        theme.insert("opacityDisabledComponents", QStringList{});
        QQmlApplicationEngine engine;
        engine.rootContext()->setContextProperty("screenshots", &model);
        engine.rootContext()->setContextProperty("backend", &theme);
        engine.load(QUrl::fromLocalFile(QFINDTESTDATA("../ScreenshotHost.qml")));
        QVERIFY(!engine.rootObjects().isEmpty());
        auto window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QVERIFY(window);
        QVERIFY(QTest::qWaitForWindowExposed(window));
        auto list = window->findChild<QQuickItem *>("screenshotList");
        auto scrollbar = window->findChild<QQuickItem *>("screenshotScrollBar");
        QVERIFY(list);
        QVERIFY(scrollbar);
        const qreal width = list->width();
        QTRY_VERIFY(!scrollbar->isVisible());
        QImage image(10, 10, QImage::Format_RGB32);
        image.fill(Qt::red);
        for (int i = 0; i < 2; ++i) QVERIFY(image.save(dir.filePath(QString::number(i) + ".png")));
        model.refresh();
        QTRY_COMPARE(model.rowCount(), 2);
        QTRY_VERIFY(list->property("contentHeight").toReal() > 0);
        QTRY_VERIFY(!scrollbar->isVisible());
        QCOMPARE(list->width(), width);
        for (int i = 2; i < 12; ++i) QVERIFY(image.save(dir.filePath(QString::number(i) + ".png")));
        model.refresh();
        QTRY_VERIFY(scrollbar->isVisible());
        QCOMPARE(list->width(), width);
        QWheelEvent wheel(QPointF(200, 200), window->mapToGlobal(QPoint(200, 200)),
            {}, QPoint(0, -120), Qt::NoButton, Qt::NoModifier, Qt::NoScrollPhase, false);
        QCoreApplication::sendEvent(window, &wheel);
        QVERIFY(list->property("moving").toBool());
        QTRY_VERIFY(list->property("contentY").toReal() > 0);
        model.selectAll();
        model.deleteSelected();
        QTRY_VERIFY(!scrollbar->isVisible());
        QCOMPARE(list->width(), width);
        model.undo();
        QTRY_VERIFY(scrollbar->isVisible());
        QCOMPARE(list->width(), width);
    }
    void doubleClickOpensResizableTransparentPreview_data() {
        QTest::addColumn<QSize>("imageSize");
        QTest::newRow("landscape") << QSize(1600, 900);
        QTest::newRow("portrait") << QSize(900, 1600);
        QTest::newRow("square") << QSize(600, 600);
    }
    void doubleClickOpensResizableTransparentPreview() {
        QFETCH(QSize, imageSize);
        QTemporaryDir dir;
        const QString path = dir.filePath(QStringLiteral("preview.png"));
        const QString sample = qEnvironmentVariable("ZHYPRBOLA_PREVIEW_TEST_IMAGE");
        if (sample.isEmpty()) {
            QImage screenshot(imageSize, QImage::Format_RGB32);
            screenshot.fill(Qt::red);
            QVERIFY(screenshot.save(path));
        } else {
            QVERIFY(QFile::copy(sample, path));
        }
        ScreenshotBackend model(dir.path());
        QQmlPropertyMap theme;
        theme.insert("themeName", "current");
        theme.insert("componentOpacity", 100);
        theme.insert("opacityEnabledComponents", QStringList{});
        theme.insert("opacityDisabledComponents", QStringList{});
        QQmlApplicationEngine engine;
        engine.rootContext()->setContextProperty("screenshots", &model);
        engine.rootContext()->setContextProperty("backend", &theme);
        engine.load(QUrl::fromLocalFile(QFINDTESTDATA("../ScreenshotHost.qml")));
        QVERIFY(!engine.rootObjects().isEmpty());
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QVERIFY(window);
        QVERIFY(QTest::qWaitForWindowExposed(window));
        QVERIFY(!window->findChild<QQuickWindow *>("screenshotPreviewWindow"));
        QSignalSpy dismissed(&model, &ScreenshotBackend::dismissRequested);

        QTest::mouseDClick(window, Qt::LeftButton, Qt::NoModifier, QPoint(200, 95));
        QPointer<QQuickWindow> preview = window->findChild<QQuickWindow *>("screenshotPreviewWindow");
        QVERIFY(preview);
        QTRY_VERIFY(preview->isVisible());
        QCOMPARE(model.selectedPaths(), QStringList{path});
        QVERIFY(!window->isVisible());
        QVERIFY(!model.opened());
        QCOMPARE(dismissed.count(), 1);
        QVERIFY(!preview->transientParent());
        QCOMPARE(preview->modality(), Qt::NonModal);
        QVERIFY(preview->flags() & Qt::FramelessWindowHint);
        QCOMPARE(preview->color().alpha(), 0);
        const QSize originalSize = QImage(path).size();
        const qreal aspect = qreal(originalSize.width()) / originalSize.height();
        const auto checkAspect = [aspect](QQuickWindow *target) {
            QVERIFY(qAbs(target->width() - target->height() * aspect) <= qMax(1.0, aspect));
        };
        checkAspect(preview);
        QVERIFY(preview->width() <= 660);
        QVERIFY(preview->height() <= 510);
        const QSize initialSize = preview->size();

        auto *image = preview->findChild<QQuickItem *>("screenshotPreviewImage");
        auto *close = preview->findChild<QQuickItem *>("screenshotPreviewCloseButton");
        auto *resize = preview->findChild<QQuickItem *>("screenshotPreviewResizeHandle");
        QVERIFY(image);
        QVERIFY(close);
        QVERIFY(resize);
        QVERIFY(QTest::qWaitForWindowExposed(preview));
        QTest::mouseMove(preview, QPoint(preview->width() / 2, preview->height() / 2));
        QTRY_VERIFY(close->isVisible());
        QVERIFY(resize->isVisible());
        QEvent leave(QEvent::Leave);
        QCoreApplication::sendEvent(preview, &leave);
        QTest::qWait(30);
        QVERIFY(close->isVisible());
        QVERIFY(resize->isVisible());
        QTest::mouseMove(preview, QPoint(preview->width() / 3, preview->height() / 3));
        QTest::qWait(120);
        QVERIFY(close->isVisible());
        QVERIFY(resize->isVisible());
        QCoreApplication::sendEvent(preview, &leave);
        QTest::qWait(150);
        QVERIFY(!close->isVisible());
        QVERIFY(!resize->isVisible());
        QTest::mouseMove(preview, QPoint(preview->width() / 2, preview->height() / 2));
        QTRY_VERIFY(close->isVisible());
        QVERIFY(resize->isVisible());
        QCOMPARE(image->property("source").toUrl(), QUrl::fromLocalFile(path));
        QTRY_VERIFY(image->property("paintedWidth").toReal() > 0);
        QCOMPARE(image->size(), preview->size());
        const QString previewCapture = qEnvironmentVariable("ZHYPRBOLA_PREVIEW_TEST_SCREENSHOT");
        if (!previewCapture.isEmpty())
            QVERIFY(preview->grabWindow().save(previewCapture));
        const auto checkCloseOffset = [preview, close, resize] {
            QCOMPARE(preview->width() - close->x() - close->width(), 20.0);
            QCOMPARE(close->y(), 20.0);
            QCOMPARE(resize->x() + resize->width(), qreal(preview->width()));
            QCOMPARE(resize->y() + resize->height(), qreal(preview->height()));
        };
        checkCloseOffset();
        const QPoint resizePoint = resize->mapToScene(
            QPointF(resize->width() / 2, resize->height() / 2)).toPoint();
        QTest::mouseMove(preview, resizePoint);
        QTest::mousePress(preview, Qt::LeftButton, Qt::NoModifier, resizePoint);
        QTest::mouseMove(preview, resizePoint + QPoint(80, 60));
        QTest::mouseRelease(preview, Qt::LeftButton, Qt::NoModifier, resizePoint + QPoint(80, 60));
        QTRY_VERIFY(preview->width() > initialSize.width());
        QTRY_VERIFY(preview->height() > initialSize.height());
        checkAspect(preview);
        QTRY_COMPARE(image->size(), QSizeF(preview->size()));
        QVERIFY(qAbs(image->property("paintedWidth").toReal() - preview->width()) <= 1);
        QVERIFY(qAbs(image->property("paintedHeight").toReal() - preview->height()) <= 1);
        checkCloseOffset();

        const QPoint closePoint = close->mapToScene(
            QPointF(close->width() / 2, close->height() / 2)).toPoint();
        QTest::mouseMove(preview, closePoint);
        QTRY_VERIFY(close->isVisible());
        QTest::mouseClick(preview, Qt::LeftButton, Qt::NoModifier, closePoint);
        QTRY_VERIFY(preview.isNull());
        QVERIFY(!window->isVisible());
        model.Show();
        QVERIFY(QTest::qWaitForWindowExposed(window));
        QTest::mouseDClick(window, Qt::LeftButton, Qt::NoModifier, QPoint(200, 95));
        preview = window->findChild<QQuickWindow *>("screenshotPreviewWindow");
        QVERIFY(preview);
        QTRY_VERIFY(preview->isVisible());
        model.Show();
        QTRY_VERIFY(window->isVisible());
        QVERIFY(preview->isVisible());
        model.Hide();
        QVERIFY(!window->isVisible());
        QVERIFY(preview->isVisible());

        // Reopening the same image creates another window without replacing the first.
        model.Show();
        QVERIFY(QTest::qWaitForWindowExposed(window));
        QTest::mouseDClick(window, Qt::LeftButton, Qt::NoModifier, QPoint(200, 95));
        auto previews = window->findChildren<QQuickWindow *>("screenshotPreviewWindow");
        QCOMPARE(previews.size(), 2);
        QPointer<QQuickWindow> second = previews[0] == preview ? previews[1] : previews[0];
        QVERIFY(second != preview);
        QTRY_VERIFY(second->isVisible());
        QVERIFY(preview->isVisible());
        QCOMPARE(preview->size(), initialSize);
        QVERIFY(!window->isVisible());
        QTest::keyClick(second, Qt::Key_Escape);
        QTRY_VERIFY(second.isNull());
        QVERIFY(preview->isVisible());
        QCOMPARE(preview->findChild<QQuickItem *>("screenshotPreviewImage")
            ->property("source").toUrl(), QUrl::fromLocalFile(path));
        preview->requestActivate();
        QVERIFY(QTest::qWaitForWindowActive(preview));
        QTest::keyClick(preview, Qt::Key_Escape);
        QTRY_VERIFY(preview.isNull());
        QVERIFY(!window->isVisible());
    }
    void mouseSelectionAndKeyboardShortcuts() {
        QTemporaryDir dir;
        for (const QString name : {"a.png", "b.png", "c.png"}) {
            QImage image(10, 10, QImage::Format_RGB32);
            image.fill(Qt::red);
            QVERIFY(image.save(dir.filePath(name)));
        }
        ScreenshotBackend model(dir.path());
        QQmlPropertyMap theme;
        theme.insert("themeName", "current");
        theme.insert("componentOpacity", 100);
        theme.insert("opacityEnabledComponents", QStringList{});
        theme.insert("opacityDisabledComponents", QStringList{});
        QQmlApplicationEngine engine;
        engine.rootContext()->setContextProperty("screenshots", &model);
        engine.rootContext()->setContextProperty("backend", &theme);
        engine.load(QUrl::fromLocalFile(QFINDTESTDATA("../ScreenshotHost.qml")));
        QVERIFY(!engine.rootObjects().isEmpty());
        auto window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QVERIFY(window);
        QVERIFY(QTest::qWaitForWindowExposed(window));
        window->requestActivate();
        QTRY_VERIFY(window->isActive());
        auto deleteButton = window->findChild<QQuickItem *>("screenshotDeleteButton");
        QVERIFY(deleteButton);
        QVERIFY(!deleteButton->isEnabled());
        QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, QPoint(200, 90));
        QCOMPARE(model.selectedPaths().size(), 1);
        QVERIFY(deleteButton->isEnabled());
        QTest::mouseClick(window, Qt::LeftButton, Qt::ControlModifier, QPoint(200, 280));
        QCOMPARE(model.selectedPaths().size(), 2);
        QTest::mouseClick(window, Qt::LeftButton, Qt::ShiftModifier, QPoint(200, 185));
        QCOMPARE(model.selectedPaths().size(), 2);
        QTest::keyClick(window, Qt::Key_C, Qt::ControlModifier);
        QCOMPARE(QGuiApplication::clipboard()->text(), model.selectedPaths().join('\n'));
        QTest::keyClick(window, Qt::Key_Delete);
        QCOMPARE(model.rowCount(), 1);
        QTest::keyClick(window, Qt::Key_Z, Qt::ControlModifier);
        QCOMPARE(model.rowCount(), 3);
        QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier,
            deleteButton->mapToScene(QPointF(deleteButton->width() / 2, deleteButton->height() / 2)).toPoint());
        QCOMPARE(model.rowCount(), 1);
        QVERIFY(!deleteButton->isEnabled());
        QTest::keyClick(window, Qt::Key_Z, Qt::ControlModifier);
        QCOMPARE(model.rowCount(), 3);
        const QStringList selection = model.selectedPaths();
        for (int i = 0; i < 5; ++i) {
            model.Hide();
            QTRY_VERIFY(!window->isVisible());
            model.Show();
            QTRY_VERIFY(window->isVisible());
            QCOMPARE(engine.rootObjects().first(), window);
            QCOMPARE(model.selectedPaths(), selection);
        }
        window->requestActivate();
        QTRY_VERIFY(window->isActive());
        QTest::keyClick(window, Qt::Key_Escape);
        QTRY_VERIFY(!model.opened());
        QTRY_VERIFY(!window->isVisible());
    }

    void selectAllButtonAndMarqueeFromGutter() {
        QTemporaryDir dir;
        QImage image(10, 10, QImage::Format_RGB32);
        image.fill(Qt::red);
        for (const QString name : {"a.png", "b.png", "c.png", "d.png"})
            QVERIFY(image.save(dir.filePath(name)));
        ScreenshotBackend model(dir.path());
        QQmlPropertyMap theme;
        theme.insert("themeName", "current");
        theme.insert("componentOpacity", 100);
        theme.insert("opacityEnabledComponents", QStringList{});
        theme.insert("opacityDisabledComponents", QStringList{});
        QQmlApplicationEngine engine;
        engine.rootContext()->setContextProperty("screenshots", &model);
        engine.rootContext()->setContextProperty("backend", &theme);
        engine.load(QUrl::fromLocalFile(QFINDTESTDATA("../ScreenshotHost.qml")));
        QVERIFY(!engine.rootObjects().isEmpty());
        auto window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QVERIFY(window);
        QVERIFY(QTest::qWaitForWindowExposed(window));
        auto selectAll = window->findChild<QQuickItem *>("screenshotSelectAllButton");
        auto deleteButton = window->findChild<QQuickItem *>("screenshotDeleteButton");
        auto selectionArea = window->findChild<QQuickItem *>("screenshotSelectionArea");
        QVERIFY(selectAll);
        QVERIFY(deleteButton);
        QVERIFY(selectionArea);
        QVERIFY(selectAll->x() + selectAll->width() <= deleteButton->x());
        QCOMPARE(selectAll->property("text").toString(), QStringLiteral("Select all"));
        const QPoint selectAllCenter = selectAll->mapToScene(
            QPointF(selectAll->width() / 2, selectAll->height() / 2)).toPoint();
        QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, selectAllCenter);
        QCOMPARE(model.selectedPaths().size(), 4);
        QCOMPARE(selectAll->property("text").toString(), QStringLiteral("Deselect all"));
        QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, selectAllCenter);
        QCOMPARE(model.selectedPaths().size(), 0);
        QCOMPARE(selectAll->property("text").toString(), QStringLiteral("Select all"));

        QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, QPoint(80, 90));
        QCOMPARE(model.selectedPaths().size(), 1);
        QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier,
            selectAllCenter);
        QCOMPARE(model.selectedPaths().size(), 4);

        QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, QPoint(20, 90));
        QCOMPARE(model.selectedPaths().size(), 0);
        QTest::mousePress(window, Qt::LeftButton, Qt::NoModifier, QPoint(20, 72));
        QTest::mouseMove(window, QPoint(150, 300), 10);
        QCOMPARE(model.selectedPaths().size(), 3);
        const QString screenshot = qEnvironmentVariable("ZHYPRBOLA_MARQUEE_TEST_SCREENSHOT");
        if (!screenshot.isEmpty())
            QVERIFY(window->grabWindow().save(screenshot));
        QTest::mouseMove(window, QPoint(150, 210), 10);
        QCOMPARE(model.selectedPaths().size(), 2);
        QTest::mouseRelease(window, Qt::LeftButton, Qt::NoModifier, QPoint(150, 210));
        QCOMPARE(model.selectedPaths().size(), 2);
        QCOMPARE(model.selectedPaths(), QStringList({pathAt(model, 0), pathAt(model, 1)}));
    }
};
QTEST_MAIN(ScreenshotTest)
#include "screenshot-backend.test.moc"
