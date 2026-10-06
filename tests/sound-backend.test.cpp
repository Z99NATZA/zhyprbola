#include "../components/SoundBackend.h"

#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTemporaryDir>
#include <QtTest>

class SoundTest : public QObject {
    Q_OBJECT
    QTemporaryDir m_directory;
    QByteArray m_originalPath;
    QString m_statePath;

    QJsonObject device(const QString &channel) {
        QFile file(m_statePath);
        if (!file.open(QIODevice::ReadOnly)) return {};
        return QJsonDocument::fromJson(file.readAll()).object().value(channel).toObject();
    }

private slots:
    void initTestCase() {
        QVERIFY(m_directory.isValid());
        m_originalPath = qgetenv("PATH");
        const QString fake = QFINDTESTDATA("fixtures/wpctl");
        QVERIFY(!fake.isEmpty());
        const QString program = m_directory.filePath(QStringLiteral("wpctl"));
        QVERIFY(QFile::copy(fake, program));
        QVERIFY(QFile::setPermissions(program, QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner));
        qputenv("PATH", m_directory.path().toUtf8() + ':' + m_originalPath);
        m_statePath = m_directory.filePath(QStringLiteral("state.json"));
        qputenv("SOUND_TEST_STATE", m_statePath.toUtf8());
    }
    void init() {
        qunsetenv("SOUND_TEST_MODE");
        QFile file(m_statePath);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write(R"({"microphone":{"volume":100,"muted":false},"speaker":{"volume":40,"muted":false}})");
    }
    void cleanupTestCase() {
        qputenv("PATH", m_originalPath);
        qunsetenv("SOUND_TEST_STATE");
        qunsetenv("SOUND_TEST_MODE");
    }
    void readsBothDefaultDevices() {
        SoundBackend sound;
        sound.refresh();
        QTRY_VERIFY(sound.microphone().value("available").toBool());
        QTRY_VERIFY(sound.speaker().value("available").toBool());
        QCOMPARE(sound.microphone().value("volume").toInt(), 100);
        QCOMPARE(sound.speaker().value("volume").toInt(), 40);
    }
    void rapidWritesKeepLatestVolumeAndIndependentMute() {
        SoundBackend sound;
        sound.refresh();
        QTRY_VERIFY(sound.speaker().value("available").toBool());
        for (int level = 10; level <= 80; ++level) sound.setVolume("speaker", level);
        sound.setMuted("speaker", true);
        sound.setMuted("speaker", false);
        sound.setVolume("microphone", 35);
        QTRY_COMPARE(device("speaker").value("volume").toInt(), 80);
        QTRY_COMPARE(device("microphone").value("volume").toInt(), 35);
        QVERIFY(!device("speaker").value("muted").toBool());
        QTRY_COMPARE(sound.speaker().value("volume").toInt(), 80);
        QCOMPARE(sound.microphone().value("volume").toInt(), 35);
    }
    void volumeIsClampedAndMutePreservesVolume() {
        SoundBackend sound;
        sound.refresh();
        QTRY_VERIFY(sound.speaker().value("available").toBool());
        sound.setVolume("speaker", 150);
        sound.setMuted("speaker", true);
        QTRY_VERIFY(device("speaker").value("muted").toBool());
        QCOMPARE(device("speaker").value("volume").toInt(), 100);
        sound.setMuted("speaker", false);
        QTRY_VERIFY(!device("speaker").value("muted").toBool());
        QCOMPARE(device("speaker").value("volume").toInt(), 100);
    }
    void missingMicrophoneDoesNotDisableSpeaker() {
        qputenv("SOUND_TEST_MODE", "missing_microphone");
        SoundBackend sound;
        sound.refresh();
        QTRY_VERIFY(sound.speaker().value("available").toBool());
        QVERIFY(!sound.microphone().value("available").toBool());
        sound.setVolume("microphone", 20);
        sound.setVolume("speaker", 25);
        QTRY_COMPARE(device("speaker").value("volume").toInt(), 25);
        QCOMPARE(device("microphone").value("volume").toInt(), 100);
    }
    void failedWriteIsReconciledWithDeviceState() {
        SoundBackend sound;
        sound.refresh();
        QTRY_VERIFY(sound.speaker().value("available").toBool());
        qputenv("SOUND_TEST_MODE", "write_failure");
        sound.setVolume("speaker", 70);
        QTRY_COMPARE(sound.speaker().value("volume").toInt(), 40);
    }
    void malformedOutputIsUnavailable() {
        qputenv("SOUND_TEST_MODE", "malformed");
        SoundBackend sound;
        sound.refresh();
        QTRY_VERIFY(!sound.error().isEmpty());
        QVERIFY(!sound.microphone().value("available").toBool());
        QVERIFY(!sound.speaker().value("available").toBool());
    }
    void timeoutDoesNotHangAndAllowsRecovery() {
        qputenv("SOUND_TEST_MODE", "timeout");
        SoundBackend sound;
        sound.refresh();
        QTRY_VERIFY_WITH_TIMEOUT(!sound.error().isEmpty(), 5000);
        qunsetenv("SOUND_TEST_MODE");
        QTimer polling;
        connect(&polling, &QTimer::timeout, &sound, &SoundBackend::refresh);
        polling.start(100);
        QTRY_VERIFY_WITH_TIMEOUT(sound.speaker().value("available").toBool(), 5000);
        QTRY_VERIFY(sound.microphone().value("available").toBool());
    }
};

QTEST_GUILESS_MAIN(SoundTest)
#include "sound-backend.test.moc"
