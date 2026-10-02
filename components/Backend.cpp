#include "Backend.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QCoreApplication>
#include <QProcess>
#include <QSettings>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QUrlQuery>
#include <QtMath>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusInterface>
#include <QDBusObjectPath>
#include <QDBusReply>
#include <QDBusVariant>

namespace {
QString formatGiB(quint64 bytes) {
    return QString::number(double(bytes) / 1073741824.0, 'f', 1) + QStringLiteral(" GB");
}

QString weatherDescription(int code) {
    if (code == 0) return QStringLiteral("Clear sky");
    if (code <= 3) return QStringLiteral("Partly cloudy");
    if (code == 45 || code == 48) return QStringLiteral("Foggy");
    if (code >= 51 && code <= 57) return QStringLiteral("Drizzle");
    if (code >= 61 && code <= 67) return QStringLiteral("Rainy");
    if (code >= 71 && code <= 77) return QStringLiteral("Snowy");
    if (code >= 80 && code <= 82) return QStringLiteral("Rain showers");
    if (code >= 85 && code <= 86) return QStringLiteral("Snow showers");
    if (code >= 95) return QStringLiteral("Thunderstorm");
    return QStringLiteral("Cloudy");
}

QStringList commandForApp(const QString &name) {
    if (name == QLatin1String("Code")) return {QStringLiteral("code")};
    if (name == QLatin1String("Browser")) {
        for (const auto &program : {"firefox", "google-chrome", "chromium"})
            if (!QStandardPaths::findExecutable(QString::fromLatin1(program)).isEmpty())
                return {QString::fromLatin1(program)};
    }
    if (name == QLatin1String("Terminal")) {
        for (const auto &program : {"x-terminal-emulator", "gnome-terminal", "konsole"})
            if (!QStandardPaths::findExecutable(QString::fromLatin1(program)).isEmpty())
                return {QString::fromLatin1(program)};
    }
    if (name == QLatin1String("Files")) return {QStringLiteral("xdg-open"), QDir::homePath()};
    if (name == QLatin1String("Docker")) return {QStringLiteral("docker-desktop")};
    if (name == QLatin1String("Git")) {
        for (const auto &program : {"git-gui", "gitk"})
            if (!QStandardPaths::findExecutable(QString::fromLatin1(program)).isEmpty())
                return {QString::fromLatin1(program)};
    }
    if (name == QLatin1String("Music")) {
        for (const auto &program : {"spotify", "rhythmbox", "amarok"})
            if (!QStandardPaths::findExecutable(QString::fromLatin1(program)).isEmpty())
                return {QString::fromLatin1(program)};
    }
    if (name == QLatin1String("Settings")) return {QStringLiteral("gnome-control-center")};
    return {};
}

int wifiSignalFromProc() {
    QFile wireless(QStringLiteral("/proc/net/wireless"));
    if (!wireless.open(QIODevice::ReadOnly)) return 0;

    for (const QByteArray &line : wireless.readAll().split('\n')) {
        const int colon = line.indexOf(':');
        if (colon < 0) continue;

        const QList<QByteArray> fields = line.mid(colon + 1).simplified().split(' ');
        if (fields.size() < 2) continue;

        bool valid = false;
        const double linkQuality = fields.at(1).toDouble(&valid);
        if (valid) return qBound(0, qRound(linkQuality * 100.0 / 70.0), 100);
    }
    return 0;
}

QStringList componentKeys() {
    return {
        QStringLiteral("clock"),
        QStringLiteral("music"),
        QStringLiteral("apps"),
        QStringLiteral("system"),
        QStringLiteral("todo"),
        QStringLiteral("calendar"),
        QStringLiteral("spectrum")
    };
}

bool validComponentKey(const QString &key) {
    return componentKeys().contains(key);
}
}

Backend::Backend(QObject *parent) : QObject(parent) {
    m_location = qEnvironmentVariable("ZPOLA_LOCATION", "Bangkok");
    m_userName = qEnvironmentVariable("USER", "User");

    QFile cpuInfo(QStringLiteral("/proc/cpuinfo"));
    if (cpuInfo.open(QIODevice::ReadOnly)) {
        for (const QByteArray &line : cpuInfo.readAll().split('\n')) {
            if (line.startsWith("model name")) {
                m_cpuDetail = QString::fromUtf8(line.mid(line.indexOf(':') + 1)).trimmed();
                break;
            }
        }
    }
    if (m_cpuDetail.isEmpty()) m_cpuDetail = QStringLiteral("CPU");

    connect(&m_systemTimer, &QTimer::timeout, this, &Backend::refreshSystem);
    m_systemTimer.start(2000);
    refreshSystem();

    connect(&m_weatherTimer, &QTimer::timeout, this, &Backend::refreshWeather);
    m_weatherTimer.start(15 * 60 * 1000);
    refreshWeather();

    connect(&m_musicTimer, &QTimer::timeout, this, &Backend::refreshMusic);
    m_musicTimer.start(2000);
    refreshMusic();

    const QString config = QDir(QCoreApplication::applicationDirPath())
        .absoluteFilePath(QStringLiteral("../components/cava.conf"));
    if (!QStandardPaths::findExecutable(QStringLiteral("cava")).isEmpty()
        && QFileInfo::exists(config)) {
        connect(&m_cava, &QProcess::readyReadStandardOutput, this, &Backend::readSpectrum);
        m_cava.start(QStringLiteral("cava"), {QStringLiteral("-p"), config});
    }
}

Backend::~Backend() {
    if (m_cava.state() != QProcess::NotRunning) {
        m_cava.terminate();
        if (!m_cava.waitForFinished(500)) {
            m_cava.kill();
            m_cava.waitForFinished(500);
        }
    }
}

void Backend::readSpectrum() {
    m_cavaBuffer.append(m_cava.readAllStandardOutput());
    if (m_cavaBuffer.size() > 65536) m_cavaBuffer.clear();
    int end = m_cavaBuffer.indexOf('\n');
    while (end >= 0) {
        const QByteArray frame = m_cavaBuffer.left(end).trimmed();
        m_cavaBuffer.remove(0, end + 1);
        QVariantList levels;
        for (const QByteArray &entry : frame.split(';')) {
            if (entry.isEmpty()) continue;
            bool valid = false;
            const double value = entry.toDouble(&valid);
            if (valid) levels.append(qBound(0.0, value / 100.0, 1.0));
        }
        if (!levels.isEmpty()) {
            m_spectrum = levels;
            emit spectrumChanged();
        }
        end = m_cavaBuffer.indexOf('\n');
    }
}

void Backend::refreshSystem() {
    QFile stat(QStringLiteral("/proc/stat"));
    if (stat.open(QIODevice::ReadOnly)) {
        const QList<QByteArray> fields = stat.readLine().simplified().split(' ');
        if (fields.size() >= 5 && fields.first() == "cpu") {
            quint64 total = 0;
            for (int i = 1; i < fields.size(); ++i) total += fields.at(i).toULongLong();
            const quint64 idle = fields.at(4).toULongLong()
                + (fields.size() > 5 ? fields.at(5).toULongLong() : 0);
            if (m_previousTotal && total > m_previousTotal) {
                const double busy = 1.0 - double(idle - m_previousIdle) / double(total - m_previousTotal);
                m_cpuPercent = qBound(0, qRound(busy * 100), 100);
            }
            m_previousTotal = total;
            m_previousIdle = idle;
        }
    }

    QFile memory(QStringLiteral("/proc/meminfo"));
    if (memory.open(QIODevice::ReadOnly)) {
        quint64 totalKiB = 0;
        quint64 availableKiB = 0;
        for (const QByteArray &line : memory.readAll().split('\n')) {
            if (line.startsWith("MemTotal:")) totalKiB = line.mid(9).trimmed().split(' ').first().toULongLong();
            if (line.startsWith("MemAvailable:")) availableKiB = line.mid(13).trimmed().split(' ').first().toULongLong();
        }
        if (totalKiB) {
            const quint64 used = totalKiB - qMin(totalKiB, availableKiB);
            m_ramPercent = qRound(double(used) * 100 / double(totalKiB));
            m_ramDetail = formatGiB(used * 1024) + QStringLiteral(" / ") + formatGiB(totalKiB * 1024);
        }
    }

    const QStorageInfo disk = QStorageInfo::root();
    if (disk.isValid() && disk.bytesTotal() > 0) {
        const quint64 total = disk.bytesTotal();
        const quint64 used = total - disk.bytesAvailable();
        m_diskPercent = qRound(double(used) * 100 / double(total));
        m_diskDetail = formatGiB(used) + QStringLiteral(" / ") + formatGiB(total);
    }

    m_batteryAvailable = false;
    const QDir power(QStringLiteral("/sys/class/power_supply"));
    for (const QString &device : power.entryList({QStringLiteral("BAT*")}, QDir::Dirs | QDir::NoDotAndDotDot)) {
        QFile capacity(power.filePath(device + QStringLiteral("/capacity")));
        if (capacity.open(QIODevice::ReadOnly)) {
            bool valid = false;
            const int percent = capacity.readAll().trimmed().toInt(&valid);
            if (valid) {
                m_batteryAvailable = true;
                m_batteryPercent = qBound(0, percent, 100);
                break;
            }
        }
    }

    m_wifiConnected = false;
    m_wifiEnabled = false;
    m_wifiSsid = QStringLiteral("Wi-Fi off");
    m_wifiSignalStrength = 0;
    m_wifiStatusText = QStringLiteral("Wi-Fi unavailable");
    if (!QStandardPaths::findExecutable(QStringLiteral("nmcli")).isEmpty()) {
        QProcess radio;
        radio.start(QStringLiteral("nmcli"), {QStringLiteral("-t"), QStringLiteral("radio"), QStringLiteral("wifi")});
        if (radio.waitForFinished(500) && radio.exitCode() == 0) {
            m_wifiEnabled = QString::fromUtf8(radio.readAllStandardOutput()).trimmed()
                == QLatin1String("enabled");
        }

        QProcess nmcli;
        nmcli.start(QStringLiteral("nmcli"),
            {QStringLiteral("-t"), QStringLiteral("-f"),
             QStringLiteral("TYPE,STATE,CONNECTION"), QStringLiteral("dev"), QStringLiteral("status")});
        if (nmcli.waitForFinished(500) && nmcli.exitCode() == 0) {
            for (const QByteArray &row : nmcli.readAllStandardOutput().split('\n')) {
                const QList<QByteArray> fields = row.split(':');
                if (fields.size() < 3 || fields.at(0) != "wifi") continue;

                const QString state = QString::fromUtf8(fields.at(1)).trimmed();
                const QString connection = QString::fromUtf8(fields.mid(2).join(":")).trimmed();
                m_wifiConnected = state.startsWith(QStringLiteral("connected"));
                m_wifiSsid = m_wifiConnected && !connection.isEmpty()
                    ? connection
                    : (m_wifiEnabled ? QStringLiteral("Wi-Fi disconnected") : QStringLiteral("Wi-Fi off"));
                m_wifiSignalStrength = m_wifiConnected ? wifiSignalFromProc() : 0;
                m_wifiStatusText = m_wifiConnected
                    ? QStringLiteral("%1% signal").arg(m_wifiSignalStrength)
                    : (m_wifiEnabled ? state : QStringLiteral("Radio disabled"));
                break;
            }
        }
    }
    emit systemChanged();
}

void Backend::refreshWeather() {
    QUrl url(QStringLiteral("https://api.open-meteo.com/v1/forecast"));
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("latitude"), qEnvironmentVariable("ZPOLA_LATITUDE", "13.7563"));
    query.addQueryItem(QStringLiteral("longitude"), qEnvironmentVariable("ZPOLA_LONGITUDE", "100.5018"));
    query.addQueryItem(QStringLiteral("current"), QStringLiteral("temperature_2m,weather_code"));
    query.addQueryItem(QStringLiteral("daily"), QStringLiteral("temperature_2m_max,temperature_2m_min"));
    query.addQueryItem(QStringLiteral("timezone"), QStringLiteral("auto"));
    query.addQueryItem(QStringLiteral("forecast_days"), QStringLiteral("1"));
    url.setQuery(query);

    QNetworkRequest request(url);
    request.setTransferTimeout(10000);
    QNetworkReply *reply = m_network.get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        const QJsonDocument json = QJsonDocument::fromJson(reply->readAll());
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError || !json.isObject()) {
            if (!m_weatherAvailable) {
                m_condition = QStringLiteral("Weather unavailable");
                emit weatherChanged();
            }
            return;
        }
        const QJsonObject root = json.object();
        const QJsonObject current = root.value(QStringLiteral("current")).toObject();
        const QJsonObject daily = root.value(QStringLiteral("daily")).toObject();
        const QJsonArray highs = daily.value(QStringLiteral("temperature_2m_max")).toArray();
        const QJsonArray lows = daily.value(QStringLiteral("temperature_2m_min")).toArray();
        if (!current.value(QStringLiteral("temperature_2m")).isDouble() || highs.isEmpty() || lows.isEmpty())
            return;
        m_temperature = qRound(current.value(QStringLiteral("temperature_2m")).toDouble());
        m_high = qRound(highs.first().toDouble());
        m_low = qRound(lows.first().toDouble());
        m_condition = weatherDescription(current.value(QStringLiteral("weather_code")).toInt());
        m_weatherAvailable = true;
        emit weatherChanged();
    });
}

QString Backend::playerctl(const QStringList &args) const {
    if (!playerctlAvailable()) return {};
    QProcess process;
    process.start(QStringLiteral("playerctl"), args);
    if (!process.waitForFinished(700)) {
        process.kill();
        process.waitForFinished(100);
        return {};
    }
    return process.exitCode() == 0 ? QString::fromUtf8(process.readAllStandardOutput()).trimmed() : QString();
}

bool Backend::playerctlAvailable() const {
    return !QStandardPaths::findExecutable(QStringLiteral("playerctl")).isEmpty();
}

QStringList Backend::mprisPlayers() const {
    QDBusConnectionInterface *interface = QDBusConnection::sessionBus().interface();
    if (!interface) return {};

    const QDBusReply<QStringList> reply = interface->registeredServiceNames();
    if (!reply.isValid()) return {};

    QStringList players;
    for (const QString &service : reply.value()) {
        if (service.startsWith(QStringLiteral("org.mpris.MediaPlayer2.")))
            players.append(service);
    }
    return players;
}

QVariant Backend::mprisProperty(const QString &service, const QString &property) const {
    QDBusInterface properties(service,
        QStringLiteral("/org/mpris/MediaPlayer2"),
        QStringLiteral("org.freedesktop.DBus.Properties"),
        QDBusConnection::sessionBus());
    if (!properties.isValid()) return {};

    const QDBusReply<QDBusVariant> reply = properties.call(QStringLiteral("Get"),
        QStringLiteral("org.mpris.MediaPlayer2.Player"), property);
    return reply.isValid() ? reply.value().variant() : QVariant();
}

void Backend::refreshMusic() {
    const QStringList players = playerctlAvailable()
        ? playerctl({QStringLiteral("-l")}).split('\n', Qt::SkipEmptyParts)
        : QStringList();
    QString selected;
    for (const QString &player : players) {
        if (playerctl({QStringLiteral("-p"), player, QStringLiteral("status")}) == QLatin1String("Playing")) {
            selected = player;
            break;
        }
    }
    if (selected.isEmpty() && !players.isEmpty()) selected = players.first();

    if (!selected.isEmpty()) {
        m_player = selected;
        m_trackId.clear();
        m_playerUsesDbus = false;
    } else {
        const QStringList dbusPlayers = mprisPlayers();
        for (const QString &player : dbusPlayers) {
            if (mprisProperty(player, QStringLiteral("PlaybackStatus")).toString() == QLatin1String("Playing")) {
                selected = player;
                break;
            }
        }
        if (selected.isEmpty() && !dbusPlayers.isEmpty()) selected = dbusPlayers.first();
        m_player = selected;
        m_playerUsesDbus = !selected.isEmpty();
    }

    if (selected.isEmpty()) {
        m_songTitle = QStringLiteral("No music playing");
        m_artist = QStringLiteral("Open a music app");
        m_coverSource.clear();
        m_trackId.clear();
        m_positionSeconds = 0;
        m_durationSeconds = 0;
        m_playing = false;
        emit musicChanged();
        return;
    }

    if (m_playerUsesDbus) {
        const QVariantMap metadata = qdbus_cast<QVariantMap>(mprisProperty(selected, QStringLiteral("Metadata")));
        const QStringList artists = metadata.value(QStringLiteral("xesam:artist")).toStringList();
        const QDBusObjectPath trackPath = metadata.value(QStringLiteral("mpris:trackid")).value<QDBusObjectPath>();

        m_songTitle = metadata.value(QStringLiteral("xesam:title")).toString();
        if (m_songTitle.isEmpty()) m_songTitle = QStringLiteral("Unknown track");
        m_artist = artists.isEmpty() ? selected.section('.', -1) : artists.join(QStringLiteral(", "));
        m_durationSeconds = qMax(0, int(metadata.value(QStringLiteral("mpris:length")).toLongLong() / 1000000));
        m_coverSource = metadata.value(QStringLiteral("mpris:artUrl")).toString();
        m_trackId = trackPath.path();
        m_positionSeconds = qMax(0, int(mprisProperty(selected, QStringLiteral("Position")).toLongLong() / 1000000));
        m_playing = mprisProperty(selected, QStringLiteral("PlaybackStatus")).toString() == QLatin1String("Playing");
        emit musicChanged();
        return;
    }

    const QString metadata = playerctl({QStringLiteral("-p"), selected, QStringLiteral("metadata"),
        QStringLiteral("--format"), QStringLiteral("{{title}}\x1f{{artist}}\x1f{{mpris:length}}\x1f{{mpris:artUrl}}")});
    const QStringList fields = metadata.split(QChar(0x1f));
    m_songTitle = fields.value(0).isEmpty() ? QStringLiteral("Unknown track") : fields.value(0);
    m_artist = fields.value(1).isEmpty() ? selected.section('.', 0, 0) : fields.value(1);
    m_durationSeconds = qMax(0, int(fields.value(2).toLongLong() / 1000000));
    m_coverSource = fields.value(3);
    m_positionSeconds = qMax(0, qRound(playerctl({QStringLiteral("-p"), selected, QStringLiteral("position")}).toDouble()));
    m_playing = playerctl({QStringLiteral("-p"), selected, QStringLiteral("status")}) == QLatin1String("Playing");
    emit musicChanged();
}

void Backend::playerCommand(const QStringList &args) {
    if (m_player.isEmpty()) return;
    if (m_playerUsesDbus) {
        QDBusInterface player(m_player,
            QStringLiteral("/org/mpris/MediaPlayer2"),
            QStringLiteral("org.mpris.MediaPlayer2.Player"),
            QDBusConnection::sessionBus());
        if (!player.isValid()) return;

        const QString command = args.value(0);
        if (command == QLatin1String("play-pause")) {
            player.asyncCall(QStringLiteral("PlayPause"));
        } else if (command == QLatin1String("next")) {
            player.asyncCall(QStringLiteral("Next"));
        } else if (command == QLatin1String("previous")) {
            player.asyncCall(QStringLiteral("Previous"));
        } else if (command == QLatin1String("position") && !m_trackId.isEmpty()) {
            player.asyncCall(QStringLiteral("SetPosition"),
                QVariant::fromValue(QDBusObjectPath(m_trackId)),
                qlonglong(qMax(0, args.value(1).toInt()) * 1000000));
        }
        QTimer::singleShot(350, this, &Backend::refreshMusic);
        return;
    }

    QStringList command = {QStringLiteral("-p"), m_player};
    command.append(args);
    QProcess::startDetached(QStringLiteral("playerctl"), command);
    QTimer::singleShot(350, this, &Backend::refreshMusic);
}

void Backend::togglePlayback() { playerCommand({QStringLiteral("play-pause")}); }
void Backend::nextTrack() { playerCommand({QStringLiteral("next")}); }
void Backend::previousTrack() { playerCommand({QStringLiteral("previous")}); }
void Backend::seek(int seconds) { playerCommand({QStringLiteral("position"), QString::number(qMax(0, seconds))}); }

bool Backend::appAvailable(const QString &name) const {
    const QStringList command = commandForApp(name);
    return !command.isEmpty() && !QStandardPaths::findExecutable(command.first()).isEmpty();
}

void Backend::launchApp(const QString &name) {
    const QStringList command = commandForApp(name);
    if (command.isEmpty() || !appAvailable(name)) return;
    QProcess::startDetached(command.first(), command.mid(1));
}

void Backend::openWifiSettings() {
    QStringList command;
    if (!QStandardPaths::findExecutable(QStringLiteral("gnome-control-center")).isEmpty()) {
        command = {QStringLiteral("gnome-control-center"), QStringLiteral("wifi")};
    } else if (!QStandardPaths::findExecutable(QStringLiteral("nm-connection-editor")).isEmpty()) {
        command = {QStringLiteral("nm-connection-editor")};
    }
    if (!command.isEmpty()) QProcess::startDetached(command.first(), command.mid(1));
}

void Backend::refreshStatus() {
    refreshSystem();
}

void Backend::setWifiEnabled(bool enabled) {
    if (QStandardPaths::findExecutable(QStringLiteral("nmcli")).isEmpty()) return;

    QProcess::startDetached(QStringLiteral("nmcli"),
        {QStringLiteral("radio"), QStringLiteral("wifi"),
         enabled ? QStringLiteral("on") : QStringLiteral("off")});
    QTimer::singleShot(800, this, &Backend::refreshSystem);
}

bool Backend::componentEnabled(const QString &key) const {
    if (!validComponentKey(key)) return true;

    QSettings settings;
    return settings.value(QStringLiteral("components/%1").arg(key), true).toBool();
}

void Backend::setComponentEnabled(const QString &key, bool enabled) {
    if (!validComponentKey(key) || componentEnabled(key) == enabled) return;

    QSettings settings;
    settings.setValue(QStringLiteral("components/%1").arg(key), enabled);
    emit componentSettingsChanged();
}

void Backend::resetComponentSettings() {
    QSettings settings;
    for (const QString &key : componentKeys())
        settings.remove(QStringLiteral("components/%1").arg(key));
    emit componentSettingsChanged();
}
