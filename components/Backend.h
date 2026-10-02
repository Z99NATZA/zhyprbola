#pragma once

#include <QObject>
#include <QNetworkAccessManager>
#include <QProcess>
#include <QTimer>
#include <QVariantList>

class Backend : public QObject {
    Q_OBJECT
    Q_PROPERTY(int cpuPercent READ cpuPercent NOTIFY systemChanged)
    Q_PROPERTY(int ramPercent READ ramPercent NOTIFY systemChanged)
    Q_PROPERTY(int diskPercent READ diskPercent NOTIFY systemChanged)
    Q_PROPERTY(QString cpuDetail READ cpuDetail NOTIFY systemChanged)
    Q_PROPERTY(QString ramDetail READ ramDetail NOTIFY systemChanged)
    Q_PROPERTY(QString diskDetail READ diskDetail NOTIFY systemChanged)
    Q_PROPERTY(bool batteryAvailable READ batteryAvailable NOTIFY systemChanged)
    Q_PROPERTY(int batteryPercent READ batteryPercent NOTIFY systemChanged)
    Q_PROPERTY(bool wifiConnected READ wifiConnected NOTIFY systemChanged)
    Q_PROPERTY(bool wifiEnabled READ wifiEnabled NOTIFY systemChanged)
    Q_PROPERTY(QString wifiSsid READ wifiSsid NOTIFY systemChanged)
    Q_PROPERTY(int wifiSignalStrength READ wifiSignalStrength NOTIFY systemChanged)
    Q_PROPERTY(QString wifiStatusText READ wifiStatusText NOTIFY systemChanged)
    Q_PROPERTY(QString userName READ userName CONSTANT)
    Q_PROPERTY(bool weatherAvailable READ weatherAvailable NOTIFY weatherChanged)
    Q_PROPERTY(int temperature READ temperature NOTIFY weatherChanged)
    Q_PROPERTY(int high READ high NOTIFY weatherChanged)
    Q_PROPERTY(int low READ low NOTIFY weatherChanged)
    Q_PROPERTY(QString condition READ condition NOTIFY weatherChanged)
    Q_PROPERTY(QString location READ location CONSTANT)
    Q_PROPERTY(bool hasPlayer READ hasPlayer NOTIFY musicChanged)
    Q_PROPERTY(QString songTitle READ songTitle NOTIFY musicChanged)
    Q_PROPERTY(QString artist READ artist NOTIFY musicChanged)
    Q_PROPERTY(QString coverSource READ coverSource NOTIFY musicChanged)
    Q_PROPERTY(int positionSeconds READ positionSeconds NOTIFY musicChanged)
    Q_PROPERTY(int durationSeconds READ durationSeconds NOTIFY musicChanged)
    Q_PROPERTY(bool playing READ playing NOTIFY musicChanged)
    Q_PROPERTY(QVariantList spectrum READ spectrum NOTIFY spectrumChanged)

public:
    explicit Backend(QObject *parent = nullptr);
    ~Backend() override;

    int cpuPercent() const { return m_cpuPercent; }
    int ramPercent() const { return m_ramPercent; }
    int diskPercent() const { return m_diskPercent; }
    QString cpuDetail() const { return m_cpuDetail; }
    QString ramDetail() const { return m_ramDetail; }
    QString diskDetail() const { return m_diskDetail; }
    bool batteryAvailable() const { return m_batteryAvailable; }
    int batteryPercent() const { return m_batteryPercent; }
    bool wifiConnected() const { return m_wifiConnected; }
    bool wifiEnabled() const { return m_wifiEnabled; }
    QString wifiSsid() const { return m_wifiSsid; }
    int wifiSignalStrength() const { return m_wifiSignalStrength; }
    QString wifiStatusText() const { return m_wifiStatusText; }
    QString userName() const { return m_userName; }
    bool weatherAvailable() const { return m_weatherAvailable; }
    int temperature() const { return m_temperature; }
    int high() const { return m_high; }
    int low() const { return m_low; }
    QString condition() const { return m_condition; }
    QString location() const { return m_location; }
    bool hasPlayer() const { return !m_player.isEmpty(); }
    QString songTitle() const { return m_songTitle; }
    QString artist() const { return m_artist; }
    QString coverSource() const { return m_coverSource; }
    int positionSeconds() const { return m_positionSeconds; }
    int durationSeconds() const { return m_durationSeconds; }
    bool playing() const { return m_playing; }
    QVariantList spectrum() const { return m_spectrum; }

    Q_INVOKABLE void togglePlayback();
    Q_INVOKABLE void nextTrack();
    Q_INVOKABLE void previousTrack();
    Q_INVOKABLE void seek(int seconds);
    Q_INVOKABLE bool appAvailable(const QString &name) const;
    Q_INVOKABLE void launchApp(const QString &name);
    Q_INVOKABLE void openWifiSettings();
    Q_INVOKABLE void refreshStatus();
    Q_INVOKABLE void setWifiEnabled(bool enabled);
    Q_INVOKABLE bool componentEnabled(const QString &key) const;
    Q_INVOKABLE void setComponentEnabled(const QString &key, bool enabled);
    Q_INVOKABLE void resetComponentSettings();

signals:
    void systemChanged();
    void weatherChanged();
    void musicChanged();
    void spectrumChanged();
    void componentSettingsChanged();

private:
    void refreshSystem();
    void refreshWeather();
    void refreshMusic();
    void readSpectrum();
    bool playerctlAvailable() const;
    QString playerctl(const QStringList &args) const;
    QStringList mprisPlayers() const;
    QVariant mprisProperty(const QString &service, const QString &property) const;
    void playerCommand(const QStringList &args);

    QNetworkAccessManager m_network;
    QTimer m_systemTimer;
    QTimer m_weatherTimer;
    QTimer m_musicTimer;
    quint64 m_previousTotal = 0;
    quint64 m_previousIdle = 0;
    int m_cpuPercent = 0;
    int m_ramPercent = 0;
    int m_diskPercent = 0;
    QString m_cpuDetail;
    QString m_ramDetail;
    QString m_diskDetail;
    bool m_batteryAvailable = false;
    int m_batteryPercent = 0;
    bool m_wifiConnected = false;
    bool m_wifiEnabled = false;
    QString m_wifiSsid = QStringLiteral("Wi-Fi off");
    int m_wifiSignalStrength = 0;
    QString m_wifiStatusText = QStringLiteral("Wi-Fi unavailable");
    QString m_userName;
    bool m_weatherAvailable = false;
    int m_temperature = 0;
    int m_high = 0;
    int m_low = 0;
    QString m_condition = QStringLiteral("Loading weather");
    QString m_location;
    QString m_player;
    QString m_trackId;
    bool m_playerUsesDbus = false;
    QString m_songTitle = QStringLiteral("No music playing");
    QString m_artist = QStringLiteral("Open a music app");
    QString m_coverSource;
    int m_positionSeconds = 0;
    int m_durationSeconds = 0;
    bool m_playing = false;
    QProcess m_cava;
    QByteArray m_cavaBuffer;
    QVariantList m_spectrum;
};
