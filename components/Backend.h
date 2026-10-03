#pragma once

#include <QObject>
#include <QNetworkAccessManager>
#include <QFileSystemWatcher>
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
    Q_PROPERTY(QVariantList wifiNetworks READ wifiNetworks NOTIFY wifiNetworksChanged)
    Q_PROPERTY(bool bluetoothAvailable READ bluetoothAvailable NOTIFY systemChanged)
    Q_PROPERTY(bool bluetoothEnabled READ bluetoothEnabled NOTIFY systemChanged)
    Q_PROPERTY(bool bluetoothConnected READ bluetoothConnected NOTIFY systemChanged)
    Q_PROPERTY(QString bluetoothDeviceName READ bluetoothDeviceName NOTIFY systemChanged)
    Q_PROPERTY(QString bluetoothStatusText READ bluetoothStatusText NOTIFY systemChanged)
    Q_PROPERTY(QVariantList bluetoothDevices READ bluetoothDevices NOTIFY bluetoothDevicesChanged)
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
    Q_PROPERTY(QString themeName READ themeName NOTIFY themeChanged)
    Q_PROPERTY(QString dockPosition READ dockPosition NOTIFY dockSettingsChanged)
    Q_PROPERTY(bool useWallpaper READ useWallpaper NOTIFY dockSettingsChanged)

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
    QVariantList wifiNetworks() const { return m_wifiNetworks; }
    bool bluetoothAvailable() const { return m_bluetoothAvailable; }
    bool bluetoothEnabled() const { return m_bluetoothEnabled; }
    bool bluetoothConnected() const { return m_bluetoothConnected; }
    QString bluetoothDeviceName() const { return m_bluetoothDeviceName; }
    QString bluetoothStatusText() const { return m_bluetoothStatusText; }
    QVariantList bluetoothDevices() const { return m_bluetoothDevices; }
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
    QString themeName() const { return m_themeName; }
    QString dockPosition() const { return m_dockPosition; }
    bool useWallpaper() const { return m_useWallpaper; }

    Q_INVOKABLE void togglePlayback();
    Q_INVOKABLE void nextTrack();
    Q_INVOKABLE void previousTrack();
    Q_INVOKABLE void seek(int seconds);
    Q_INVOKABLE bool appAvailable(const QString &name) const;
    Q_INVOKABLE void launchApp(const QString &name);
    Q_INVOKABLE void openWifiSettings();
    Q_INVOKABLE void refreshStatus();
    Q_INVOKABLE void setWifiEnabled(bool enabled);
    Q_INVOKABLE void scanWifiNetworks();
    Q_INVOKABLE void connectWifiNetwork(const QString &ssid, bool secure, bool saved,
        const QString &password);
    Q_INVOKABLE void disconnectWifiNetwork(const QString &ssid);
    Q_INVOKABLE void openBluetoothSettings();
    Q_INVOKABLE void setBluetoothEnabled(bool enabled);
    Q_INVOKABLE void scanBluetoothDevices();
    Q_INVOKABLE void connectBluetoothDevice(const QString &address);
    Q_INVOKABLE void disconnectBluetoothDevice(const QString &address);
    Q_INVOKABLE bool componentEnabled(const QString &key) const;
    Q_INVOKABLE void setComponentEnabled(const QString &key, bool enabled);
    Q_INVOKABLE void resetComponentSettings();
    Q_INVOKABLE void setThemeName(const QString &name);
    Q_INVOKABLE void setDockPosition(const QString &position);
    Q_INVOKABLE void setUseWallpaper(bool enabled);

signals:
    void systemChanged();
    void weatherChanged();
    void musicChanged();
    void spectrumChanged();
    void componentSettingsChanged();
    void wifiNetworksChanged();
    void wifiConnectionFinished(const QString &ssid, bool success, bool needsPassword);
    void wifiDisconnectionFinished(const QString &ssid, bool success);
    void bluetoothDevicesChanged();
    void themeChanged();
    void dockSettingsChanged();

private:
    void refreshSystem();
    void refreshWeather();
    void refreshMusic();
    void refreshWifiNetworks();
    void refreshBluetoothDevices();
    void readSpectrum();
    void refreshTheme();
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
    QVariantList m_wifiNetworks;
    bool m_bluetoothAvailable = false;
    bool m_bluetoothEnabled = false;
    bool m_bluetoothConnected = false;
    QString m_bluetoothDeviceName = QStringLiteral("Bluetooth off");
    QString m_bluetoothStatusText = QStringLiteral("Bluetooth unavailable");
    QVariantList m_bluetoothDevices;
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
    QFileSystemWatcher m_themeWatcher;
    QString m_themeName = QStringLiteral("current");
    QString m_dockPosition = QStringLiteral("left");
    bool m_useWallpaper = false;
};
