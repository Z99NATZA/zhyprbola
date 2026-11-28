#include "../components/Backend.h"
#include <QtTest>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickWindow>
#include <QTemporaryDir>
#include <memory>

class NoteVimTest : public QObject {
    Q_OBJECT
    QByteArray originalConfig;
    std::unique_ptr<QTemporaryDir> testConfig;
    std::unique_ptr<QTemporaryDir> files;
    std::unique_ptr<Backend> backend;
    std::unique_ptr<QQmlEngine> engine;
    std::unique_ptr<QQuickWindow> window;
    QScopedPointer<QObject> panel;
    QQuickItem *card = nullptr;
    QQuickItem *editor = nullptr;

    QString text() const { return editor->property("text").toString(); }
    int cursor() const { return editor->property("cursorPosition").toInt(); }
    QString mode() const { return card->property("vimMode").toString(); }
    void keys(const char *sequence) {
        for (const char *character = sequence; *character; ++character)
            QTest::keyClick(window.get(), *character);
    }
    void escape() { QTest::keyClick(window.get(), Qt::Key_Escape); }
    void enter() { QTest::keyClick(window.get(), Qt::Key_Return); }
    QString filePath(const QString &name) const { return files->filePath(name); }
    int tabCount() const { return card->property("tabs").toList().size(); }
    // Repeater delegates are only reachable through the visual item tree.
    static QQuickItem *findItem(QQuickItem *root, const QString &name) {
        if (!root) return nullptr;
        if (root->objectName() == name) return root;
        for (QQuickItem *child : root->childItems()) {
            if (QQuickItem *found = findItem(child, name)) return found;
        }
        return nullptr;
    }
    QQuickItem *item(const QString &name) const { return findItem(window->contentItem(), name); }
    void click(QQuickItem *target) {
        QTest::qWait(30); // let positioners lay out new tabs before hit-testing
        QTest::mouseClick(window.get(), Qt::LeftButton, Qt::NoModifier,
            target->mapToScene(QPointF(target->width() / 2, target->height() / 2)).toPoint());
    }
    QString readFile(const QString &path) const {
        QFile file(path);
        return file.open(QIODevice::ReadOnly) ? QString::fromUtf8(file.readAll()) : QString();
    }
    void writeFile(const QString &path, const QByteArray &data) const {
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write(data);
    }
    void load(const QString &contents) {
        const QString path = filePath("load.txt");
        writeFile(path, contents.toUtf8());
        QVERIFY(QMetaObject::invokeMethod(card, "openPath",
            Q_ARG(QVariant, path), Q_ARG(QVariant, true)));
        QCOMPARE(text(), contents);
        editor->forceActiveFocus();
    }
    void enableVim() {
        backend->setNoteVimEnabled(true);
        QCoreApplication::processEvents();
        editor->forceActiveFocus();
    }

private slots:
    void initTestCase() {
        originalConfig = qgetenv("XDG_CONFIG_HOME");
        QQuickWindow::setSceneGraphBackend("software");
    }
    void init() {
        testConfig = std::make_unique<QTemporaryDir>();
        files = std::make_unique<QTemporaryDir>();
        QVERIFY(testConfig->isValid() && files->isValid());
        qputenv("XDG_CONFIG_HOME", testConfig->path().toUtf8());
        backend = std::make_unique<Backend>(nullptr, QStringLiteral("note"));
        engine = std::make_unique<QQmlEngine>();
        engine->rootContext()->setContextProperty("backend", backend.get());
        QQmlComponent component(engine.get(), QUrl::fromLocalFile(QFINDTESTDATA("../components/Note.qml")));
        QVERIFY2(component.isReady(), qPrintable(component.errorString()));
        panel.reset(component.create());
        QVERIFY2(panel, qPrintable(component.errorString()));
        window = std::make_unique<QQuickWindow>();
        window->resize(560, 460);
        auto *root = qobject_cast<QQuickItem *>(panel.data());
        root->setSize(QSizeF(560, 460));
        root->setParentItem(window->contentItem());
        card = panel->findChild<QQuickItem *>("note-card");
        editor = panel->findChild<QQuickItem *>("note-editor");
        QVERIFY(card && editor);
        window->show();
        QVERIFY(QTest::qWaitForWindowExposed(window.get()));
        editor->forceActiveFocus();
    }
    void cleanup() {
        panel.reset();
        window.reset();
        engine.reset();
        backend.reset();
        files.reset();
        testConfig.reset();
    }
    void cleanupTestCase() {
        if (originalConfig.isNull()) qunsetenv("XDG_CONFIG_HOME");
        else qputenv("XDG_CONFIG_HOME", originalConfig);
    }

    void backendReadsAndWritesTextFiles() {
        const QString path = filePath("note.md");
        QCOMPARE(backend->writeTextFile(QUrl::fromLocalFile(path).toString(), "# Title\nไทย\n"), QString());
        const QVariantMap result = backend->readTextFile(path);
        QVERIFY(result.value("ok").toBool());
        QCOMPARE(result.value("text").toString(), "# Title\nไทย\n");
        QCOMPARE(result.value("path").toString(), path);
        QVERIFY(!backend->readTextFile(filePath("missing.txt")).value("ok").toBool());
        QVERIFY(!backend->writeTextFile(filePath("no/such/dir.txt"), "x").isEmpty());
    }

    void plainEditingOpenSaveAndNew() {
        QVERIFY(!backend->noteVimEnabled());
        keys("hello");
        QCOMPARE(text(), "hello");
        QVERIFY(card->property("dirty").toBool());
        const QString path = filePath("plain.txt");
        QVariant saved;
        QVERIFY(QMetaObject::invokeMethod(card, "writeTo", Q_RETURN_ARG(QVariant, saved), Q_ARG(QVariant, path)));
        QVERIFY(saved.toBool());
        QCOMPARE(readFile(path), "hello");
        QVERIFY(!card->property("dirty").toBool());
        QCOMPARE(backend->noteLastFile(), path);
        QCOMPARE(card->property("fileName").toString(), "plain.txt");

        // Ctrl+S writes to the current file.
        keys(" world");
        QTest::keyClick(window.get(), Qt::Key_S, Qt::ControlModifier);
        QCOMPARE(readFile(path), "hello world");

        // Closing a tab with unsaved edits asks first; Esc cancels.
        keys("!");
        QVERIFY(QMetaObject::invokeMethod(card, "closeTab", Q_ARG(QVariant, 0)));
        QCOMPARE(card->property("pendingAction").toString(), "close-tab");
        auto *prompt = panel->findChild<QQuickItem *>("note-unsaved-prompt");
        QVERIFY(prompt);
        QTRY_VERIFY(prompt->hasActiveFocus());
        escape();
        QCOMPARE(card->property("pendingAction").toString(), QString());
        QVERIFY(!prompt->isVisible());
        QVERIFY(editor->hasActiveFocus());
        QCOMPARE(text(), "hello world!");

        // Ctrl+N opens a new tab and keeps the edited one.
        QTest::keyClick(window.get(), Qt::Key_N, Qt::ControlModifier);
        QCOMPARE(tabCount(), 2);
        QCOMPARE(card->property("currentTab").toInt(), 1);
        QCOMPARE(text(), QString());
        QCOMPARE(card->property("filePath").toString(), QString());

        // Saved tabs reopen when the panel starts.
        QQmlComponent component(engine.get(), QUrl::fromLocalFile(QFINDTESTDATA("../components/Note.qml")));
        QScopedPointer<QObject> reopened(component.create());
        auto *reopenedEditor = reopened->findChild<QQuickItem *>("note-editor");
        QCOMPARE(reopenedEditor->property("text").toString(), "hello world");
    }

    void multipleTabs() {
        const QString first = filePath("first.md");
        const QString second = filePath("second.txt");
        writeFile(first, "first file");
        writeFile(second, "second file");
        QVariant opened;
        QVERIFY(QMetaObject::invokeMethod(card, "openInTab", Q_RETURN_ARG(QVariant, opened),
            Q_ARG(QVariant, first), Q_ARG(QVariant, true)));
        // The empty Untitled tab is reused for the first file.
        QCOMPARE(tabCount(), 1);
        QCOMPARE(text(), "first file");
        editor->forceActiveFocus();
        keys("X");
        QVERIFY(QMetaObject::invokeMethod(card, "openInTab", Q_RETURN_ARG(QVariant, opened),
            Q_ARG(QVariant, second), Q_ARG(QVariant, true)));
        QCOMPARE(tabCount(), 2);
        QCOMPARE(card->property("currentTab").toInt(), 1);
        QCOMPARE(text(), "second file");
        QCOMPARE(backend->noteOpenFiles(), QStringList({first, second}));

        // The first tab keeps its unsaved edit and shows the dot.
        auto *firstTab = item("note-tab-0");
        QVERIFY(firstTab);
        auto *firstDot = findItem(firstTab, "note-dirty-dot");
        QVERIFY(firstDot && firstDot->isVisible());
        click(firstTab);
        QCOMPARE(card->property("currentTab").toInt(), 0);
        QCOMPARE(text(), "Xfirst file");
        QVERIFY(card->property("dirty").toBool());

        // Opening an already-open file switches to its tab.
        QVERIFY(QMetaObject::invokeMethod(card, "openInTab", Q_RETURN_ARG(QVariant, opened),
            Q_ARG(QVariant, second), Q_ARG(QVariant, true)));
        QCOMPARE(tabCount(), 2);
        QCOMPARE(card->property("currentTab").toInt(), 1);

        // Ctrl+Tab cycles; the + button adds a tab after the current one.
        QTest::keyClick(window.get(), Qt::Key_Tab, Qt::ControlModifier);
        QCOMPARE(card->property("currentTab").toInt(), 0);
        auto *plus = item("note-new-tab");
        QVERIFY(plus);
        click(plus);
        QCOMPARE(tabCount(), 3);
        QCOMPARE(card->property("currentTab").toInt(), 1);

        // Vim gt/gT and :q close the tab, not the panel.
        enableVim();
        keys("gt");
        QCOMPARE(card->property("currentTab").toInt(), 2);
        QCOMPARE(text(), "second file");
        keys("gT");
        QCOMPARE(card->property("currentTab").toInt(), 1);
        QSignalSpy closed(panel.data(), SIGNAL(closeRequested()));
        keys(":q"); enter();
        QCOMPARE(tabCount(), 2);
        QCOMPARE(closed.count(), 0);
        QCOMPARE(text(), "second file");

        // Ctrl+W on a clean tab closes it without asking.
        QTest::keyClick(window.get(), Qt::Key_W, Qt::ControlModifier);
        QCOMPARE(tabCount(), 1);
        QCOMPARE(text(), "Xfirst file");
        QCOMPARE(backend->noteOpenFiles(), QStringList({first}));
    }

    void zoomEditorFontSize() {
        QCOMPARE(editor->property("font").value<QFont>().pixelSize(), 15);

        // Ctrl+= and Ctrl++ (Ctrl+Shift+=) grow the text, Ctrl+- shrinks it.
        QTest::keyClick(window.get(), Qt::Key_Equal, Qt::ControlModifier);
        QCOMPARE(card->property("editorFontSize").toInt(), 16);
        QCOMPARE(editor->property("font").value<QFont>().pixelSize(), 16);
        QTest::keyClick(window.get(), Qt::Key_Plus, Qt::ControlModifier | Qt::ShiftModifier);
        QCOMPARE(card->property("editorFontSize").toInt(), 17);
        QTest::keyClick(window.get(), Qt::Key_Minus, Qt::ControlModifier);
        QCOMPARE(card->property("editorFontSize").toInt(), 16);

        // Ctrl+0 resets, and the size stays within its limits.
        QTest::keyClick(window.get(), Qt::Key_0, Qt::ControlModifier);
        QCOMPARE(card->property("editorFontSize").toInt(), 15);
        for (int i = 0; i < 40; ++i)
            QTest::keyClick(window.get(), Qt::Key_Equal, Qt::ControlModifier);
        QCOMPARE(card->property("editorFontSize").toInt(), 40);
        for (int i = 0; i < 60; ++i)
            QTest::keyClick(window.get(), Qt::Key_Minus, Qt::ControlModifier);
        QCOMPARE(card->property("editorFontSize").toInt(), 8);
        QTest::keyClick(window.get(), Qt::Key_0, Qt::ControlModifier);

        // Typing still works after zooming.
        keys("ok");
        QCOMPARE(text(), "ok");
    }

    void contextMenuTogglesVimAndPersists() {
        auto *menu = panel->findChild<QObject *>("note-menu");
        QVERIFY(menu);
        QTest::mouseClick(window.get(), Qt::RightButton, Qt::NoModifier, QPoint(200, 200));
        QTRY_VERIFY(menu->property("opened").toBool());
        auto *row = panel->findChild<QQuickItem *>("note-vim-toggle");
        auto *on = panel->findChild<QQuickItem *>("note-vim-on");
        auto *off = panel->findChild<QQuickItem *>("note-vim-off");
        QVERIFY(row && on && off);
        QVERIFY(off->property("active").toBool());
        QVERIFY(!on->property("active").toBool());
        // Preview is always listed but disabled for non-Markdown files.
        auto *preview = item("note-preview");
        QVERIFY(preview && preview->isVisible() && preview->height() > 0);
        QVERIFY(!preview->isEnabled());
        // Vim is the last entry, after Save as.
        auto *saveAs = panel->findChild<QQuickItem *>("note-save-as");
        QVERIFY(saveAs);
        QVERIFY(row->mapToScene(QPointF(0, 0)).y() > saveAs->mapToScene(QPointF(0, 0)).y());
        const QPoint center = row->mapToScene(QPointF(row->width() / 2, row->height() / 2)).toPoint();
        QTest::mouseClick(window.get(), Qt::LeftButton, Qt::NoModifier, center);
        QVERIFY(backend->noteVimEnabled());
        QVERIFY(on->property("active").toBool());
        QTest::qWait(50);
        QVERIFY(menu->property("visible").toBool());
        Backend reopened(nullptr, QStringLiteral("note"));
        QVERIFY(reopened.noteVimEnabled());
        QTest::mouseClick(window.get(), Qt::LeftButton, Qt::NoModifier, center);
        QVERIFY(!backend->noteVimEnabled());
        QVERIFY(menu->property("visible").toBool());
    }

    void contextMenuOpacitySavesOnceOnRelease() {
        auto *menu = panel->findChild<QObject *>("note-menu");
        QVERIFY(menu);
        QTest::mouseClick(window.get(), Qt::RightButton, Qt::NoModifier, QPoint(200, 200));
        QTRY_VERIFY(menu->property("opened").toBool());
        auto *row = panel->findChild<QQuickItem *>("note-opacity");
        auto *slider = panel->findChild<QQuickItem *>("note-opacity-slider");
        QVERIFY(row && slider);
        QTest::qWait(30);
        const QColor before = card->property("surfaceColor").value<QColor>();
        const QPoint left = slider->mapToScene(QPointF(2, slider->height() / 2)).toPoint();
        const QPoint middle = slider->mapToScene(
            QPointF(slider->width() / 2, slider->height() / 2)).toPoint();

        QTest::mousePress(window.get(), Qt::LeftButton, Qt::NoModifier, left);
        QTest::mouseMove(window.get(), middle);
        QTest::mouseMove(window.get(), middle + QPoint(1, 0));
        // While dragging the card previews the value but nothing is saved yet.
        QTRY_VERIFY(card->property("surfaceColor").value<QColor>().alphaF() < before.alphaF());
        QVERIFY(backend->cardOpacities().isEmpty());
        QVERIFY(!QFile::exists(testConfig->filePath("zhyprbola/card-opacity")));

        QTest::mouseRelease(window.get(), Qt::LeftButton, Qt::NoModifier, middle + QPoint(1, 0));
        QTRY_VERIFY(backend->cardOpacities().contains("note"));
        const int saved = backend->cardOpacities().value("note").toInt();
        QVERIFY(saved > 0 && saved < 100);
        QCOMPARE(qRound(card->property("surfaceColor").value<QColor>().alphaF() * 100), saved);
        QVERIFY(menu->property("visible").toBool());
    }

    void backendRenamesTextFiles() {
        const QString path = filePath("old.txt");
        writeFile(path, "x");
        writeFile(filePath("taken.txt"), "y");
        QVERIFY(!backend->renameTextFile(path, "").value("ok").toBool());
        QVERIFY(!backend->renameTextFile(path, "a/b.txt").value("ok").toBool());
        QVERIFY(!backend->renameTextFile(path, "taken.txt").value("ok").toBool());
        const QVariantMap result = backend->renameTextFile(path, "ไทย.md");
        QVERIFY(result.value("ok").toBool());
        QCOMPARE(result.value("path").toString(), filePath("ไทย.md"));
        QVERIFY(!QFile::exists(path));
        QCOMPARE(readFile(filePath("ไทย.md")), "x");
    }

    QQuickItem *openRename() {
        auto *menu = panel->findChild<QObject *>("note-menu");
        QTest::mouseClick(window.get(), Qt::RightButton, Qt::NoModifier, QPoint(200, 200));
        if (!QTest::qWaitFor([&] { return menu->property("opened").toBool(); })) return nullptr;
        auto *row = panel->findChild<QQuickItem *>("note-rename");
        auto *input = panel->findChild<QQuickItem *>("note-rename-input");
        if (!row || !input || input->isVisible()) return nullptr;
        click(row);
        return input->isVisible() && input->hasActiveFocus() ? input : nullptr;
    }

    void contextMenuRenamesFile() {
        // Untitled notes have nothing on disk to rename.
        QTest::mouseClick(window.get(), Qt::RightButton, Qt::NoModifier, QPoint(200, 200));
        auto *row = panel->findChild<QQuickItem *>("note-rename");
        QTRY_VERIFY(row && row->isVisible());
        QVERIFY(!row->isEnabled());
        QTest::keyClick(window.get(), Qt::Key_Escape);

        load("body");
        auto *input = openRename();
        QVERIFY(input);
        // The field sits right under "Rename", and the name before the extension is selected.
        QVERIFY(input->mapToScene(QPointF(0, 0)).y() > row->mapToScene(QPointF(0, row->height())).y() - 1);
        QCOMPARE(input->property("text").toString(), "load.txt");
        QCOMPARE(input->property("selectedText").toString(), "load");
        keys("renamed");
        enter();
        QCOMPARE(card->property("filePath").toString(), filePath("renamed.txt"));
        QVERIFY(!QFile::exists(filePath("load.txt")));
        QCOMPARE(readFile(filePath("renamed.txt")), "body");
        QTRY_VERIFY(!panel->findChild<QObject *>("note-menu")->property("visible").toBool());
        QCOMPARE(backend->noteOpenFiles(), QStringList{filePath("renamed.txt")});
    }

    void renameFieldUsesVimKeys() {
        load("body");
        enableVim();
        auto *input = openRename();
        QVERIFY(input);
        auto mode = [&] { return card->property("renameMode").toString(); };
        QCOMPARE(mode(), "normal");
        // Normal mode: the cursor rests on the end of the name, keys are commands.
        QCOMPARE(input->property("cursorPosition").toInt(), 3);
        keys("ciw");
        QCOMPARE(mode(), "insert");
        QCOMPARE(input->property("text").toString(), ".txt");
        keys("notes");
        escape();
        QCOMPARE(mode(), "normal");
        keys("x");
        QCOMPARE(input->property("text").toString(), "note.txt");
        keys("u");
        QCOMPARE(input->property("text").toString(), "notes.txt");
        keys("$rd");
        QCOMPARE(input->property("text").toString(), "notes.txd");
        keys("u");
        enter();
        QCOMPARE(card->property("filePath").toString(), filePath("notes.txt"));
        QCOMPARE(readFile(filePath("notes.txt")), "body");
        QCOMPARE(text(), "body");

        // Esc in normal mode closes the menu without renaming.
        input = openRename();
        QVERIFY(input);
        keys("D");
        escape();
        QTRY_VERIFY(!panel->findChild<QObject *>("note-menu")->property("visible").toBool());
        QCOMPARE(card->property("filePath").toString(), filePath("notes.txt"));
        QCOMPARE(mode(), "normal");
    }

    void contextMenuSavesAndMarksDirty() {
        auto *dot = item("note-dirty-dot");
        QVERIFY(dot);
        QVERIFY(!dot->isVisible());
        load("saved");
        keys("!");
        QVERIFY(dot->isVisible());
        QTest::mouseClick(window.get(), Qt::RightButton, Qt::NoModifier, QPoint(200, 200));
        auto *save = panel->findChild<QQuickItem *>("note-save");
        QVERIFY(save);
        QTRY_VERIFY(save->isVisible());
        QTest::mouseClick(window.get(), Qt::LeftButton, Qt::NoModifier,
            save->mapToScene(QPointF(save->width() / 2, save->height() / 2)).toPoint());
        QCOMPARE(readFile(filePath("load.txt")), "!saved");
        QVERIFY(!dot->isVisible());
    }

    void tabCloseClosesFileThenPanel() {
        auto *close = item("note-tab-close");
        QVERIFY(close);
        QVERIFY(panel->findChild<QQuickItem *>("note-close"));
        const QPoint center = close->mapToScene(QPointF(close->width() / 2, close->height() / 2)).toPoint();
        QSignalSpy closed(panel.data(), SIGNAL(closeRequested()));
        load("kept");
        keys("!");
        QTest::mouseClick(window.get(), Qt::LeftButton, Qt::NoModifier, center);
        QCOMPARE(card->property("pendingAction").toString(), "close-tab");
        QVERIFY(QMetaObject::invokeMethod(card, "runAction", Q_ARG(QVariant, "close-tab")));
        QCOMPARE(text(), QString());
        QCOMPARE(card->property("fileName").toString(), "Untitled");
        QCOMPARE(closed.count(), 0);
        QTest::mouseClick(window.get(), Qt::LeftButton, Qt::NoModifier, center);
        QCOMPARE(closed.count(), 1);
    }

    void windowCloseAsksForEachUnsavedTab() {
        const QString a = filePath("a.txt"), b = filePath("b.txt"), c = filePath("c.txt");
        writeFile(a, "a");
        writeFile(b, "b");
        writeFile(c, "c");
        QVariant opened;
        for (const QString &path : {a, b, c})
            QVERIFY(QMetaObject::invokeMethod(card, "openInTab", Q_RETURN_ARG(QVariant, opened),
                Q_ARG(QVariant, path), Q_ARG(QVariant, true)));
        QCOMPARE(tabCount(), 3);
        // Edit a and c; b stays clean.
        QVERIFY(QMetaObject::invokeMethod(card, "switchTab", Q_ARG(QVariant, 0)));
        editor->forceActiveFocus();
        keys("1");
        QVERIFY(QMetaObject::invokeMethod(card, "switchTab", Q_ARG(QVariant, 2)));
        editor->forceActiveFocus();
        keys("3");
        QVERIFY(QMetaObject::invokeMethod(card, "switchTab", Q_ARG(QVariant, 1)));

        QSignalSpy closed(panel.data(), SIGNAL(closeRequested()));
        auto *close = item("note-close");
        QVERIFY(close);
        click(close);
        // The next unsaved tab after the current one (c) is focused first.
        QCOMPARE(card->property("pendingAction").toString(), "close-window");
        QCOMPARE(card->property("fileName").toString(), "c.txt");
        auto *prompt = item("note-unsaved-prompt");
        QVERIFY(prompt);
        // Save writes c and closes its tab, then a is asked about.
        QVERIFY(QMetaObject::invokeMethod(card, "save"));
        QVERIFY(QMetaObject::invokeMethod(card, "afterSave"));
        QCOMPARE(readFile(c), "3c");
        QCOMPARE(tabCount(), 2);
        QCOMPARE(card->property("fileName").toString(), "a.txt");
        QCOMPARE(card->property("pendingAction").toString(), "close-window");
        QCOMPARE(closed.count(), 0);
        // Discard drops a's edit, closes its tab, and with nothing unsaved the panel closes.
        QVERIFY(QMetaObject::invokeMethod(card, "runAction", Q_ARG(QVariant, "close-window")));
        QCOMPARE(readFile(a), "a");
        QCOMPARE(tabCount(), 1);
        QCOMPARE(card->property("fileName").toString(), "b.txt");
        QCOMPARE(closed.count(), 1);

        // Cancel stops without closing anything.
        editor->forceActiveFocus();
        keys("2");
        click(close);
        QCOMPARE(card->property("pendingAction").toString(), "close-window");
        escape();
        QCOMPARE(card->property("pendingAction").toString(), QString());
        QCOMPARE(tabCount(), 1);
        QCOMPARE(closed.count(), 1);
    }

    void normalMotions() {
        load("alpha beta\n  second line\n\nlast");
        enableVim();
        QCOMPARE(mode(), "normal");
        keys("abc"); // "a" enters insert; make sure normal mode never inserts directly
        escape();
        load("alpha beta\n  second line\n\nlast");
        QCOMPARE(mode(), "normal");
        keys("q"); QCOMPARE(text(), "alpha beta\n  second line\n\nlast");
        keys("w"); QCOMPARE(cursor(), 6);
        keys("$"); QCOMPARE(cursor(), 9);
        keys("j"); QCOMPARE(cursor(), 11 + 12); // end of "  second line"
        keys("0"); QCOMPARE(cursor(), 11);
        keys("^"); QCOMPARE(cursor(), 13);
        keys("j"); QCOMPARE(cursor(), 25); // empty line
        keys("j"); QCOMPARE(cursor(), 28); // keeps the goal column across the empty line
        keys("gg"); QCOMPARE(cursor(), 0);
        keys("G"); QCOMPARE(cursor(), 26);
        keys("2G"); QCOMPARE(cursor(), 13);
        keys("k"); QCOMPARE(cursor(), 2);
        keys("e"); QCOMPARE(cursor(), 4);
        keys("b"); QCOMPARE(cursor(), 0);
        keys("l"); QCOMPARE(cursor(), 1);
        keys("h"); QCOMPARE(cursor(), 0);
        keys("h"); QCOMPARE(cursor(), 0);
    }

    void insertCommands() {
        load("one\ntwo");
        enableVim();
        auto *modeLabel = panel->findChild<QQuickItem *>("note-mode");
        QVERIFY(modeLabel);
        QCOMPARE(modeLabel->property("text").toString(), "-- NORMAL --");
        const QColor normalColor = modeLabel->property("color").value<QColor>();
        keys("A"); QCOMPARE(mode(), "insert");
        QCOMPARE(modeLabel->property("text").toString(), "-- INSERT --");
        QVERIFY(modeLabel->property("color").value<QColor>() != normalColor);
        keys("!"); escape();
        QCOMPARE(text(), "one!\ntwo");
        QCOMPARE(cursor(), 3);
        keys("o"); keys("mid"); escape();
        QCOMPARE(text(), "one!\nmid\ntwo");
        keys("O"); keys("top"); escape();
        QCOMPARE(text(), "one!\ntop\nmid\ntwo");
        keys("gg"); keys("I"); keys("> "); escape();
        QCOMPARE(text(), "> one!\ntop\nmid\ntwo");
        keys("u");
        QCOMPARE(text(), "one!\ntop\nmid\ntwo");
        QTest::keyClick(window.get(), Qt::Key_R, Qt::ControlModifier);
        QCOMPARE(text(), "> one!\ntop\nmid\ntwo");
    }

    void operators() {
        load("alpha beta gamma\nline two\nline three");
        enableVim();
        keys("dw"); QCOMPARE(text(), "beta gamma\nline two\nline three");
        keys("x"); QCOMPARE(text(), "eta gamma\nline two\nline three");
        keys("P"); QCOMPARE(text(), "beta gamma\nline two\nline three");
        keys("0cwBETA"); escape();
        QCOMPARE(text(), "BETA gamma\nline two\nline three");
        keys("w"); keys("D"); QCOMPARE(text(), "BETA \nline two\nline three");
        keys("j"); keys("dd"); QCOMPARE(text(), "BETA \nline three");
        keys("p"); QCOMPARE(text(), "BETA \nline three\nline two");
        keys("gg"); keys("yy"); keys("G"); keys("p");
        QCOMPARE(text(), "BETA \nline three\nline two\nBETA ");
        keys("3G"); keys("2dd"); QCOMPARE(text(), "BETA \nline three");
        keys("gg"); keys("J"); QCOMPARE(text(), "BETA line three");
        keys("ciwone"); escape();
        QCOMPARE(text(), "BETA one three");
        keys("0"); keys("~"); QCOMPARE(text(), "bETA one three");
        QCOMPARE(cursor(), 1);
        keys("0rX"); QCOMPARE(text(), "XETA one three");
        QCOMPARE(cursor(), 0);
        keys("R"); keys("ab"); escape(); QCOMPARE(text(), "abTA one three");
        QCOMPARE(cursor(), 1);
        keys("cc"); keys("fresh"); escape(); QCOMPARE(text(), "fresh");
        keys("u"); QCOMPARE(text(), "abTA one three");
    }

    void shiftKeyKeepsPendingCommand() {
        load("abc\nxyz");
        enableVim();
        // Real keyboards send a Shift press before the shifted character.
        const auto shifted = [this](char character) {
            QTest::keyPress(window.get(), Qt::Key_Shift);
            QTest::keyClick(window.get(), character, Qt::ShiftModifier);
            QTest::keyRelease(window.get(), Qt::Key_Shift);
        };
        keys("r"); shifted('X');
        QCOMPARE(text(), "Xbc\nxyz");
        keys("ld"); shifted('$');
        QCOMPARE(text(), "X\nxyz");
        load("ab cd");
        keys("llr"); enter();
        QCOMPARE(text(), "ab\ncd");
        QCOMPARE(cursor(), 3);
    }

    void shiftAndMoveLines() {
        load("one\ntwo\nthree");
        enableVim();
        keys(">>"); QCOMPARE(text(), "    one\ntwo\nthree");
        QCOMPARE(cursor(), 4);
        keys("j2>>"); QCOMPARE(text(), "    one\n    two\n    three");
        keys("<<"); QCOMPARE(text(), "    one\ntwo\n    three");
        load("\tx\n  y");
        keys(">>"); QCOMPARE(text(), "\t\tx\n  y");
        keys("<<j<<"); QCOMPARE(text(), "\tx\ny");

        const auto alt = [this](Qt::Key key) { QTest::keyClick(window.get(), key, Qt::AltModifier); };
        load("a1\nb2\nc3");
        keys("l");
        alt(Qt::Key_J); QCOMPARE(text(), "b2\na1\nc3"); QCOMPARE(cursor(), 4);
        alt(Qt::Key_J); QCOMPARE(text(), "b2\nc3\na1"); QCOMPARE(cursor(), 7);
        alt(Qt::Key_J); QCOMPARE(text(), "b2\nc3\na1");
        alt(Qt::Key_K); QCOMPARE(text(), "b2\na1\nc3"); QCOMPARE(cursor(), 4);
        keys("2"); alt(Qt::Key_K); QCOMPARE(text(), "a1\nb2\nc3"); QCOMPARE(cursor(), 1);
        keys("u"); QCOMPARE(text(), "b2\na1\nc3");
    }

    void starSearchesWholeWord() {
        load("foo food foo\nbar foo");
        enableVim();
        keys("*"); QCOMPARE(cursor(), 9);
        keys("n"); QCOMPARE(cursor(), 17);
        keys("n"); QCOMPARE(cursor(), 0);
        keys("#"); QCOMPARE(cursor(), 17);
        keys("n"); QCOMPARE(cursor(), 9); // "#" makes n search backward
        keys("N"); QCOMPARE(cursor(), 17);
        keys("gg3l*"); QCOMPARE(cursor(), 4); // keyword after the cursor
        QCOMPARE(card->property("message").toString(), "/food");
    }

    void dotRepeatsLastChange() {
        load("abcdef");
        enableVim();
        keys("x"); keys("3."); QCOMPARE(text(), "ef");
        load("one two three");
        keys("ciwXY"); escape();
        keys("w."); QCOMPARE(text(), "XY XY three");
        keys("w."); QCOMPARE(text(), "XY XY XY");
        keys("u"); QCOMPARE(text(), "XY XY three");
        load("a\nb");
        keys("onew"); escape();
        keys("j."); QCOMPARE(text(), "a\nnew\nb\nnew");
        load("x\ny");
        keys(">>j."); QCOMPARE(text(), "    x\n    y");
        load("abc");
        keys("rZl."); QCOMPARE(text(), "ZZc");
        load("abcd\nabcd");
        keys("Rxy"); escape();
        keys("j0."); QCOMPARE(text(), "xycd\nxycd");
        // Backspacing over existing text is replayed too.
        load("hello\nworld");
        keys("A");
        QTest::keyClick(window.get(), Qt::Key_Backspace);
        QTest::keyClick(window.get(), Qt::Key_Backspace);
        keys("p"); escape();
        QCOMPARE(text(), "help\nworld");
        keys("j."); QCOMPARE(text(), "help\nworp");
        // Motions and yanks do not replace the last change.
        keys("0yyw."); QCOMPARE(text(), "help\nwop");
    }

    // Screen point at the middle of the character cell that starts at `position`.
    QPoint editorPoint(int position) const {
        QRectF rect;
        QMetaObject::invokeMethod(editor, "positionToRectangle", Q_RETURN_ARG(QRectF, rect),
            Q_ARG(int, position));
        return editor->mapToScene(rect.center()).toPoint();
    }

    void mouseDragIncludesCharactersUnderPressAndEnd() {
        load("hello world\nfoo");
        enableVim();

        // Forward: press on 'h', drag to the caret after 'o'.
        QTest::mousePress(window.get(), Qt::LeftButton, Qt::NoModifier, editorPoint(0));
        QTest::mouseMove(window.get(), editorPoint(5));
        QTest::mouseRelease(window.get(), Qt::LeftButton, Qt::NoModifier, editorPoint(5));
        QTest::qWait(20);
        QCOMPARE(mode(), "visual");
        QCOMPARE(editor->property("selectedText").toString(), "hello");

        // Backward: press on the space after 'hello', drag to the start.
        escape();
        QTest::mousePress(window.get(), Qt::LeftButton, Qt::NoModifier, editorPoint(5));
        QTest::mouseMove(window.get(), editorPoint(0));
        QTest::mouseRelease(window.get(), Qt::LeftButton, Qt::NoModifier, editorPoint(0));
        QTest::qWait(20);
        QCOMPARE(mode(), "visual");
        QCOMPARE(editor->property("selectedText").toString(), "hello ");
    }

    void visualMode() {
        load("one two three\nfour five\nsix");
        enableVim();
        auto *modeLabel = panel->findChild<QQuickItem *>("note-mode");
        auto *visualCursor = panel->findChild<QQuickItem *>("note-visual-cursor");
        QVERIFY(modeLabel && visualCursor);
        const auto selected = [this] { return editor->property("selectedText").toString(); };

        keys("ve");
        QCOMPARE(mode(), "visual");
        QCOMPARE(modeLabel->property("text").toString(), "-- VISUAL --");
        QCOMPARE(selected(), "one");
        QVERIFY(visualCursor->isVisible());
        keys("o"); QCOMPARE(card->property("visualCursor").toInt(), 0);
        keys("d");
        QCOMPARE(text(), " two three\nfour five\nsix");
        QCOMPARE(mode(), "normal");
        QCOMPARE(selected(), QString());
        QVERIFY(!visualCursor->isVisible());
        keys("u");

        // Motions with counts extend the selection; case operators keep the text.
        keys("wv2lU"); QCOMPARE(text(), "one TWO three\nfour five\nsix");
        QCOMPARE(cursor(), 4);

        keys("jV");
        QCOMPARE(modeLabel->property("text").toString(), "-- VISUAL LINE --");
        QCOMPARE(selected(), "four five\n");
        keys("d"); QCOMPARE(text(), "one TWO three\nsix");
        keys("ggVj>"); QCOMPARE(text(), "    one TWO three\n    six");
        keys("Vj<"); QCOMPARE(text(), "one TWO three\nsix");

        // Escape leaves the cursor on the moving end; gv reselects.
        load("hello world");
        keys("vll"); escape();
        QCOMPARE(mode(), "normal"); QCOMPARE(cursor(), 2);
        keys("gv"); QCOMPARE(mode(), "visual"); QCOMPARE(selected(), "hel");
        keys("v"); QCOMPARE(mode(), "normal");

        // y yanks; p replaces the selection and swaps the register.
        keys("0vey"); QCOMPARE(card->property("vimRegister").toMap().value("text").toString(), "hello");
        keys("wvep"); QCOMPARE(text(), "hello hello");
        QCOMPARE(card->property("vimRegister").toMap().value("text").toString(), "world");
        keys("0v$~"); QCOMPARE(text(), "HELLO HELLO");

        load("abc\ndef");
        keys("vjrx"); QCOMPARE(text(), "xxx\nxef");

        // A mouse selection enters Visual mode; clearing it leaves.
        load("hello");
        QVERIFY(QMetaObject::invokeMethod(editor, "select", Q_ARG(int, 1), Q_ARG(int, 3)));
        QCOMPARE(mode(), "visual");
        keys("d"); QCOMPARE(text(), "hlo");
        QVERIFY(QMetaObject::invokeMethod(editor, "select", Q_ARG(int, 0), Q_ARG(int, 2)));
        QCOMPARE(mode(), "visual");
        QVERIFY(QMetaObject::invokeMethod(editor, "deselect"));
        QCOMPARE(mode(), "normal");
    }

    void searchAndCommandLine() {
        load("find me\nand me too");
        enableVim();
        keys("/me"); enter();
        QCOMPARE(cursor(), 5);
        keys("n"); QCOMPARE(cursor(), 12);
        keys("n"); QCOMPARE(cursor(), 5);
        keys("N"); QCOMPARE(cursor(), 12);
        keys(":1"); enter();
        QCOMPARE(cursor(), 0);
        keys("x");
        const QString target = filePath("command.md");
        keys(":w "); keys(target.toUtf8().constData()); enter();
        QCOMPARE(readFile(target), "ind me\nand me too");
        QCOMPARE(card->property("filePath").toString(), target);
        QSignalSpy closed(panel.data(), SIGNAL(closeRequested()));
        keys("x");
        QVERIFY(card->property("dirty").toBool());
        keys(":q"); enter();
        QCOMPARE(closed.count(), 0);
        keys(":wq"); enter();
        QCOMPARE(closed.count(), 1);
        QCOMPARE(readFile(target), "nd me\nand me too");
    }
};

QTEST_MAIN(NoteVimTest)
#include "note-vim.test.moc"
