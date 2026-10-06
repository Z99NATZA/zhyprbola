#pragma once

#include <QObject>
#include <QProcess>
#include <QQueue>
#include <QTimer>
#include <QVariantMap>

class SoundBackend : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap microphone READ microphone NOTIFY changed)
    Q_PROPERTY(QVariantMap speaker READ speaker NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)

public:
    explicit SoundBackend(QObject *parent = nullptr);
    ~SoundBackend() override;
    QVariantMap microphone() const { return m_microphone; }
    QVariantMap speaker() const { return m_speaker; }
    QString error() const { return m_error; }
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void setVolume(const QString &channel, int percent);
    Q_INVOKABLE void setMuted(const QString &channel, bool muted);

signals:
    void changed();

private:
    void enqueue(const QStringList &command);
    void startNext();
    void finish(bool success);
    QVariantMap &state(const QString &target);
    static QString target(const QString &channel);
    QProcess m_process;
    QTimer m_timeout;
    QQueue<QStringList> m_commands;
    QStringList m_current;
    QVariantMap m_microphone = {{"available", false}, {"volume", 0}, {"muted", false}};
    QVariantMap m_speaker = m_microphone;
    QString m_error;
};
