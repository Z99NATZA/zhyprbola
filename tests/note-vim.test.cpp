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
