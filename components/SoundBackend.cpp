#include "SoundBackend.h"

#include <QRegularExpression>
#include <QStandardPaths>
#include <QtMath>

SoundBackend::SoundBackend(QObject *parent) : QObject(parent) {
    m_timeout.setSingleShot(true);
    m_timeout.setInterval(2000);
    connect(&m_timeout, &QTimer::timeout, this, [this]() { m_process.kill(); });
    connect(&m_process, &QProcess::finished, this, [this](int code, QProcess::ExitStatus status) {
        finish(code == 0 && status == QProcess::NormalExit);
    });
    connect(&m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) finish(false);
    });
}

SoundBackend::~SoundBackend() {
    m_timeout.stop();
    m_process.disconnect(this);
    if (m_process.state() != QProcess::NotRunning) {
        m_process.kill();
        m_process.waitForFinished(1000);
    }
}

QString SoundBackend::target(const QString &channel) {
    if (channel == QLatin1String("microphone")) return QStringLiteral("@DEFAULT_AUDIO_SOURCE@");
    if (channel == QLatin1String("speaker")) return QStringLiteral("@DEFAULT_AUDIO_SINK@");
    return {};
}

QVariantMap &SoundBackend::state(const QString &target) {
    return target == QLatin1String("@DEFAULT_AUDIO_SOURCE@") ? m_microphone : m_speaker;
}

void SoundBackend::refresh() {
    if (!m_current.isEmpty() || !m_commands.isEmpty()) return;
    enqueue({QStringLiteral("get-volume"), target(QStringLiteral("microphone"))});
    enqueue({QStringLiteral("get-volume"), target(QStringLiteral("speaker"))});
}

void SoundBackend::setVolume(const QString &channel, int percent) {
    const QString id = target(channel);
    if (id.isEmpty() || !state(id).value(QStringLiteral("available")).toBool()) return;
    percent = qBound(0, percent, 100);
    state(id).insert(QStringLiteral("volume"), percent);
    emit changed();
    enqueue({QStringLiteral("set-volume"), id, QString::number(percent) + QLatin1Char('%')});
}

void SoundBackend::setMuted(const QString &channel, bool muted) {
    const QString id = target(channel);
    if (id.isEmpty() || !state(id).value(QStringLiteral("available")).toBool()) return;
    state(id).insert(QStringLiteral("muted"), muted);
    emit changed();
    enqueue({QStringLiteral("set-mute"), id, muted ? QStringLiteral("1") : QStringLiteral("0")});
}

void SoundBackend::enqueue(const QStringList &command) {
    // Keep the latest pending slider value without launching concurrent writes.
    for (auto &pending : m_commands) {
        if (pending[0] == command[0] && pending[1] == command[1]) {
            pending = command;
            return;
        }
    }
    m_commands.enqueue(command);
    startNext();
}

void SoundBackend::startNext() {
    if (!m_current.isEmpty() || m_commands.isEmpty()) return;
    m_current = m_commands.dequeue();
    if (QStandardPaths::findExecutable(QStringLiteral("wpctl")).isEmpty()) {
        finish(false);
        return;
    }
    m_timeout.start();
    m_process.start(QStringLiteral("wpctl"), m_current);
}

void SoundBackend::finish(bool success) {
    if (m_current.isEmpty()) return;
    m_timeout.stop();
    const QStringList command = m_current;
    m_current.clear();
    const QString output = QString::fromUtf8(m_process.readAllStandardOutput()).trimmed();
    m_process.readAllStandardError();
    if (command[0] == QLatin1String("get-volume")) {
        static const QRegularExpression pattern(QStringLiteral("^Volume:\\s+([0-9]+(?:\\.[0-9]+)?)(?:\\s+(\\[MUTED\\]))?$"));
        const auto match = pattern.match(output);
        success = success && match.hasMatch();
        bool pendingWrite = false;
        for (const auto &pending : m_commands)
            if (pending[1] == command[1] && pending[0] != QLatin1String("get-volume"))
                pendingWrite = true;
        if (!pendingWrite) {
            auto &value = state(command[1]);
            value.insert(QStringLiteral("available"), success);
            if (success) {
                value.insert(QStringLiteral("volume"), qRound(match.captured(1).toDouble() * 100));
                value.insert(QStringLiteral("muted"), !match.captured(2).isEmpty());
            }
        }
    }
    if (!success)
        m_error = QStandardPaths::findExecutable(QStringLiteral("wpctl")).isEmpty()
            ? QStringLiteral("Sound controls require WirePlumber (wpctl).")
            : QStringLiteral("Could not access the default audio device.");
    else if (m_microphone.value(QStringLiteral("available")).toBool()
        && m_speaker.value(QStringLiteral("available")).toBool())
        m_error.clear();
    emit changed();
    if (!m_commands.isEmpty()) startNext();
    else if (command[0] != QLatin1String("get-volume")) refresh();
}
