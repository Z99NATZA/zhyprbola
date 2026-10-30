#include "../components/Backend.h"
#include <QtTest>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickWindow>
#include <QTemporaryDir>
#include <memory>

class TodoVimTest : public QObject {
    Q_OBJECT
    QByteArray originalConfig;
    std::unique_ptr<QTemporaryDir> testConfig;
    std::unique_ptr<Backend> backend;
    std::unique_ptr<QQmlEngine> engine;
    std::unique_ptr<QQuickWindow> window;
    QScopedPointer<QObject> panel;
    QQuickItem *card = nullptr;
    QQuickItem *editor = nullptr;

    QString taskText(int index = 0) const {
        return backend->tasks().at(index).toMap().value("text").toString();
    }
    void keys(const char *text) {
        for (const char *character = text; *character; ++character)
            QTest::keyClick(window.get(), *character);
    }
    void escape() { QTest::keyClick(window.get(), Qt::Key_Escape); }
    void enableVim() {
        backend->setTaskVimEnabled(true);
        QCoreApplication::processEvents();
        card->forceActiveFocus();
    }
    int cursor() const { return editor->property("cursorPosition").toInt(); }
    QPoint center(QQuickItem *item) const {
        return item->mapToScene(QPointF(item->width()/2, item->height()/2)).toPoint();
    }

private slots:
    void initTestCase() {
        originalConfig = qgetenv("XDG_CONFIG_HOME");
        QQuickWindow::setSceneGraphBackend("software");
    }
    void init() {
        testConfig = std::make_unique<QTemporaryDir>();
        QVERIFY(testConfig->isValid());
        qputenv("XDG_CONFIG_HOME", testConfig->path().toUtf8());
        backend = std::make_unique<Backend>(nullptr, QStringLiteral("todo"));
        backend->addTask("alpha beta tail");
        backend->addTask("second task");
        backend->addTask("third task");
        engine = std::make_unique<QQmlEngine>();
        engine->rootContext()->setContextProperty("backend", backend.get());
        QQmlComponent component(engine.get(), QUrl::fromLocalFile(QFINDTESTDATA("../components/Todo.qml")));
        QVERIFY2(component.isReady(), qPrintable(component.errorString()));
        panel.reset(component.create());
        QVERIFY2(panel, qPrintable(component.errorString()));
        window = std::make_unique<QQuickWindow>();
        window->resize(640, 360);
        auto *root = qobject_cast<QQuickItem *>(panel.data());
        root->setSize(QSizeF(640, 360));
        root->setParentItem(window->contentItem());
        card = panel->findChild<QQuickItem *>("tasks-card");
        editor = panel->findChild<QQuickItem *>("task-vim-editor");
        QVERIFY(card && editor);
        window->show();
        QVERIFY(QTest::qWaitForWindowExposed(window.get()));
    }
    void cleanup() {
        panel.reset();
        window.reset();
        engine.reset();
        backend.reset();
        testConfig.reset();
    }
    void cleanupTestCase() {
        if (originalConfig.isNull()) qunsetenv("XDG_CONFIG_HOME");
        else qputenv("XDG_CONFIG_HOME", originalConfig);
    }
    void togglePrecedesCounterAndPersists() {
        QVERIFY(!backend->taskVimEnabled());
        auto *toggle = panel->findChild<QQuickItem *>("task-vim-toggle");
        auto *progress = panel->findChild<QQuickItem *>("task-progress");
        QVERIFY(toggle && progress);
        QVERIFY(toggle->x() + toggle->width() < progress->x());
        QTest::mouseClick(window.get(), Qt::LeftButton, Qt::NoModifier, center(toggle));
        QVERIFY(backend->taskVimEnabled());
        QCOMPARE(card->property("vimMode").toString(), "normal");
        Backend reopened(nullptr, QStringLiteral("todo"));
        QVERIFY(reopened.taskVimEnabled());
        QTest::mouseClick(window.get(), Qt::LeftButton, Qt::NoModifier, center(toggle));
        QVERIFY(!backend->taskVimEnabled());
        Backend disabled(nullptr, QStringLiteral("todo"));
        QVERIFY(!disabled.taskVimEnabled());
    }
    void normalMotionsAndInsert() {
        enableVim();
        keys("j"); QCOMPARE(card->property("selectedTaskIndex").toInt(), 1);
        keys("k"); QCOMPARE(card->property("selectedTaskIndex").toInt(), 0);
        keys("l"); QCOMPARE(cursor(), 1);
        keys("h"); QCOMPARE(cursor(), 0);
        keys("w"); QCOMPARE(cursor(), 6);
        keys("b"); QCOMPARE(cursor(), 0);
        keys("$"); QCOMPARE(cursor(), 14);
        keys("0"); QCOMPARE(cursor(), 0);
        QCOMPARE(taskText(), "alpha beta tail");
        keys("i"); QCOMPARE(card->property("vimMode").toString(), "insert");
        keys("new "); escape();
        QCOMPARE(taskText(), "new alpha beta tail");
        QCOMPARE(card->property("vimMode").toString(), "normal");
        QVERIFY(card->hasActiveFocus());
        keys("j"); QCOMPARE(card->property("selectedTaskIndex").toInt(), 1);
    }
    void appendAfterCharacterAndAtEnd() {
        enableVim();
        keys("a");
        QCOMPARE(card->property("vimMode").toString(), "insert");
        QCOMPARE(cursor(), 1);
        keys("X"); escape();
        QCOMPARE(taskText(), "aXlpha beta tail");
        keys("0A"); QCOMPARE(cursor(), taskText().size());
        keys(" suffix"); escape();
        QCOMPARE(taskText(), "aXlpha beta tail suffix");
        backend->renameTask(backend->tasks().first().toMap().value("id").toString(),
            QString::fromUtf8("task 🙂"));
        keys("$a!"); escape();
        QCOMPARE(taskText(), QString::fromUtf8("task 🙂!"));
        keys("dddddd");
        QVERIFY(backend->tasks().isEmpty());
        keys("A"); QVERIFY(card->property("adding").toBool());
        keys("new task"); escape();
        QCOMPARE(taskText(), "new task");
    }
    void changeInnerWordAndChangeToEnd() {
        enableVim();
        keys("wciw");
        QCOMPARE(card->property("vimMode").toString(), "insert");
        QCOMPARE(editor->property("text").toString(), "alpha  tail");
        keys("gamma"); escape();
        QCOMPARE(taskText(), "alpha gamma tail");
        keys("0wC");
        QCOMPARE(editor->property("text").toString(), "alpha ");
        keys("end"); escape();
        QCOMPARE(taskText(), "alpha end");
    }
    void singleAndContinuousReplace() {
        enableVim();
        keys("rX"); QCOMPARE(taskText(), "Xlpha beta tail"); QCOMPARE(cursor(), 0);
        keys("r"); escape();
        QCOMPARE(taskText(), "Xlpha beta tail");
        keys("RZQ");
        QCOMPARE(editor->property("text").toString(), "ZQpha beta tail");
        QTest::keyClick(window.get(), Qt::Key_Backspace);
        QCOMPARE(editor->property("text").toString(), "Zlpha beta tail");
        escape(); QCOMPARE(taskText(), "Zlpha beta tail");
        keys("$R!!"); escape();
        QCOMPARE(taskText(), "Zlpha beta tai!!");
    }
    void deleteRowsAndCreateFromEmptyList() {
        enableVim();
        keys("d"); escape(); QCOMPARE(backend->tasks().size(), 3);
        keys("dd"); QCOMPARE(backend->tasks().size(), 2);
        QCOMPARE(taskText(), "second task");
        QCOMPARE(card->property("selectedTaskIndex").toInt(), 0);
        keys("jdd"); QCOMPARE(backend->tasks().size(), 1);
        QCOMPARE(card->property("selectedTaskIndex").toInt(), 0);
        keys("dd"); QVERIFY(backend->tasks().isEmpty());
        keys("i"); QVERIFY(card->property("adding").toBool());
        keys("fresh task"); escape();
        QCOMPARE(backend->tasks().size(), 1);
        QCOMPARE(taskText(), "fresh task");
        QVERIFY(!card->property("adding").toBool());
        QCOMPARE(card->property("vimMode").toString(), "normal");
    }
    void disablingVimSavesDraftAndRestoresPlainTyping() {
        enableVim();
        keys("ichanged ");
        backend->setTaskVimEnabled(false);
        QCOMPARE(taskText(), "changed alpha beta tail");
        QVERIFY(!editor->isVisible());
        auto *input = panel->findChild<QQuickItem *>("new-task-input");
        QVERIFY(QMetaObject::invokeMethod(card, "startAdding"));
        QTRY_VERIFY(input->hasActiveFocus());
        keys("dd ciw h j k l");
        QCOMPARE(input->property("text").toString(), "dd ciw h j k l");
        escape();
        QCOMPARE(backend->tasks().size(), 3);
    }
    void unicodeWordsPunctuationAndCharacters() {
        backend->renameTask(backend->tasks().first().toMap().value("id").toString(),
            QString::fromUtf8("งาน_ไทย abc-def 🙂"));
        enableVim();
        keys("w"); QCOMPARE(cursor(), 8);
        keys("w"); QCOMPARE(cursor(), 11);
        keys("w"); QCOMPARE(cursor(), 12);
        keys("b"); QCOMPARE(cursor(), 11);
        keys("b"); QCOMPARE(cursor(), 8);
        keys("0ciwtask"); escape();
        QCOMPARE(taskText(), QString::fromUtf8("task abc-def 🙂"));
        keys("$r!");
        QCOMPARE(taskText(), "task abc-def !");
    }
    void mouseEditingAndCompletionKeepVimSelection() {
        enableVim();
        const QPoint secondText(130, 62 + 48 + 20);
        QTest::mouseClick(window.get(), Qt::LeftButton, Qt::NoModifier, secondText);
        QCOMPARE(card->property("selectedTaskIndex").toInt(), 1);
        QTest::mouseDClick(window.get(), Qt::LeftButton, Qt::NoModifier, secondText);
        QCOMPARE(card->property("vimMode").toString(), "insert");
        keys("new "); escape();
        QCOMPARE(taskText(1), "new second task");
        keys(" ");
        QVERIFY(backend->tasks().at(1).toMap().value("done").toBool());
        QCOMPARE(card->property("selectedTaskIndex").toInt(), 1);
        keys("0iupdated ");
        QTest::mouseClick(window.get(), Qt::LeftButton, Qt::NoModifier, QPoint(300, 320));
        QCOMPARE(taskText(1), "updated new second task");
        QCOMPARE(card->property("vimMode").toString(), "normal");
        Backend reopened(nullptr, QStringLiteral("todo"));
        QCOMPARE(reopened.tasks().at(1).toMap().value("text").toString(), taskText(1));
    }
    void keyboardSelectionScrollsAndSurvivesReordering() {
        for (int index = 0; index < 20; ++index) backend->addTask(QString::number(index));
        enableVim();
        for (int index = 0; index < 20; ++index) keys("j");
        QCOMPARE(card->property("selectedTaskIndex").toInt(), 20);
        const QPointF visiblePosition = editor->mapToScene(QPointF(0, 0));
        QVERIFY(visiblePosition.y() >= 62 && visiblePosition.y() + editor->height() <= 342);
        const QString selected = card->property("selectedTaskId").toString();
        backend->moveTask(selected, 0);
        QCOMPARE(card->property("selectedTaskId").toString(), selected);
        QCOMPARE(card->property("selectedTaskIndex").toInt(), 0);
        keys("i!"); escape();
        QVERIFY(taskText().startsWith('!'));
    }
    void clickingElsewhereClearsFocusAndPendingCommands() {
        enableVim();
        QVERIFY(card->property("vimHasFocus").toBool());
        keys("d");
        QTest::mouseClick(window.get(), Qt::LeftButton, Qt::NoModifier, QPoint(300, 320));
        QVERIFY(!card->property("vimHasFocus").toBool());
        QVERIFY(!editor->isVisible());
        QVERIFY(!editor->property("cursorVisible").toBool());
        QVERIFY(card->property("vimCommand").toString().isEmpty());
        keys("dd"); QCOMPARE(backend->tasks().size(), 3);
        backend->toggleTask(backend->tasks().first().toMap().value("id").toString());
        QVERIFY(!card->property("vimHasFocus").toBool());
        QTest::mouseClick(window.get(), Qt::LeftButton, Qt::NoModifier, QPoint(130, 130));
        QCOMPARE(card->property("selectedTaskIndex").toInt(), 1);
        QVERIFY(card->property("vimHasFocus").toBool());
        QTest::mouseClick(window.get(), Qt::LeftButton, Qt::NoModifier, QPoint(40, 30));
        QVERIFY(!card->property("vimHasFocus").toBool());
    }
    void clickingAwaySavesInsertAndReplaceDrafts() {
        enableVim();
        keys("iupdated ");
        QTest::mouseClick(window.get(), Qt::LeftButton, Qt::NoModifier, QPoint(300, 320));
        QCOMPARE(taskText(), "updated alpha beta tail");
        QCOMPARE(card->property("vimMode").toString(), "normal");
        QVERIFY(!card->property("vimHasFocus").toBool());
        QTest::mouseClick(window.get(), Qt::LeftButton, Qt::NoModifier, QPoint(130, 82));
        keys("0RXYZ");
        QTest::mouseClick(window.get(), Qt::LeftButton, Qt::NoModifier, QPoint(300, 320));
        QCOMPARE(taskText(), "XYZated alpha beta tail");
        QVERIFY(!card->property("vimHasFocus").toBool());
        QTest::mouseClick(window.get(), Qt::LeftButton, Qt::NoModifier, QPoint(130, 82));
        keys("0icheckbox ");
        QTest::mouseClick(window.get(), Qt::LeftButton, Qt::NoModifier, QPoint(45, 82));
        QCOMPARE(taskText(), "checkbox XYZated alpha beta tail");
        QVERIFY(backend->tasks().first().toMap().value("done").toBool());
        QVERIFY(!card->property("vimHasFocus").toBool());
    }
    void activatingAnotherWindowClearsFocusAndSavesDraft() {
        enableVim();
        keys("idraft ");
        QQuickWindow other;
        other.resize(100, 100);
        other.show();
        other.requestActivate();
        QTRY_VERIFY(other.isActive());
        QCOMPARE(taskText(), "draft alpha beta tail");
        QVERIFY(!card->property("vimHasFocus").toBool());
        window->requestActivate();
        QTRY_VERIFY(window->isActive());
        QVERIFY(!card->property("vimHasFocus").toBool());
    }
};

QTEST_MAIN(TodoVimTest)
#include "todo-vim.test.moc"
