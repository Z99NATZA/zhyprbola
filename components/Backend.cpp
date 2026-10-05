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
#include <QDateTime>
#include <QProcess>
#include <QRegularExpression>
#include <QSettings>
#include <QSaveFile>
#include <QSet>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QUuid>
#include <QVariantMap>
#include <QUrlQuery>
#include <QtMath>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusInterface>
#include <QDBusObjectPath>
#include <QDBusReply>
#include <QDBusVariant>
#include <algorithm>

namespace {
QString dockConfigPath(const QString &name) {
    return QDir(QStandardPaths::writableLocation(QStandardPaths::ConfigLocation))
        .filePath(QStringLiteral("zhyprbola/") + name);
}

bool writeDockConfig(const QString &name, const QString &value) {
    const QString path = dockConfigPath(name);
    if (!QDir().mkpath(QFileInfo(path).absolutePath())) return false;

    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly)) return false;
    if (file.write((value + QLatin1Char('\n')).toUtf8()) < 0) return false;
    return file.commit();
}

QString timestamp() {
    return QDateTime::currentDateTime().toString(Qt::ISODateWithMs);
}

QString formatGiB(quint64 bytes) {
    return QString::number(double(bytes) / 1073741824.0, 'f', 1);
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

QStringList dockComponentKeys() {
    return {QStringLiteral("settings"), QStringLiteral("bluetooth"),
        QStringLiteral("wifi"), QStringLiteral("clock-weather"),
        QStringLiteral("system-status"), QStringLiteral("audio-spectrum"),
        QStringLiteral("music"), QStringLiteral("todo"),
        QStringLiteral("calendar"), QStringLiteral("input-source"),
        QStringLiteral("power")};
}

QList<QByteArray> splitNetworkRow(const QByteArray &row) {
    QList<QByteArray> fields = row.split(':');
    if (fields.size() <= 4) return fields;

    QList<QByteArray> normalized;
    normalized.append(fields.takeFirst());
    const QByteArray security = fields.takeLast();
    const QByteArray signal = fields.takeLast();
    normalized.append(fields.join(":"));
    normalized.append(signal);
    normalized.append(security);
    return normalized;
}

QString runBluetoothctl(const QStringList &args, int timeoutMs = 900) {
    if (QStandardPaths::findExecutable(QStringLiteral("bluetoothctl")).isEmpty()) return {};

    QProcess process;
    process.start(QStringLiteral("bluetoothctl"), args);
    if (!process.waitForFinished(timeoutMs)) {
        process.kill();
        process.waitForFinished(100);
        return {};
    }
    return process.exitCode() == 0 ? QString::fromUtf8(process.readAllStandardOutput()).trimmed() : QString();
}

QString bluetoothInfoValue(const QString &info, const QString &key) {
    const QString prefix = key + QStringLiteral(":");
    for (const QString &line : info.split('\n')) {
        const QString trimmed = line.trimmed();
        if (trimmed.startsWith(prefix))
            return trimmed.mid(prefix.size()).trimmed();
    }
    return {};
}
}

Backend::Backend(QObject *parent) : QObject(parent) {
    connect(&m_themeWatcher, &QFileSystemWatcher::directoryChanged,
        this, &Backend::refreshTheme);
    connect(&m_themeWatcher, &QFileSystemWatcher::fileChanged,
        this, &Backend::refreshTheme);
    refreshTheme();
    QFile dockPositionFile(dockConfigPath(QStringLiteral("dock-position")));
    if (dockPositionFile.open(QIODevice::ReadOnly)) {
        const QString position = QString::fromUtf8(dockPositionFile.readAll()).trimmed();
        if (position == QLatin1String("right") || position == QLatin1String("top")
            || position == QLatin1String("bottom"))
            m_dockPosition = position;
    }
    QFile dockBgOpacityFile(dockConfigPath(QStringLiteral("dock-bg-opacity")));
    if (dockBgOpacityFile.open(QIODevice::ReadOnly)) {
        bool valid = false;
        const int opacity = dockBgOpacityFile.readAll().trimmed().toInt(&valid);
        if (valid && opacity >= 0 && opacity <= 100)
            m_dockBgOpacity = opacity;
    }
    QFile dockUngroupWindowsFile(dockConfigPath(QStringLiteral("dock-ungroup-windows")));
    if (dockUngroupWindowsFile.open(QIODevice::ReadOnly))
        m_dockUngroupWindows = dockUngroupWindowsFile.readAll().trimmed() == "true";
    QFile dockGroupsFile(dockConfigPath(QStringLiteral("dock-groups")));
    if (dockGroupsFile.open(QIODevice::ReadOnly)) {
        static const QStringList names = {QStringLiteral("apps"),
            QStringLiteral("zhyprbola"), QStringLiteral("running")};
        m_dockGroups.clear();
        const QString contents = QString::fromUtf8(dockGroupsFile.readAll());
        for (const QString &name : contents.split(QRegularExpression(QStringLiteral("[\\s,]+")),
                 Qt::SkipEmptyParts)) {
            if (names.contains(name) && !m_dockGroups.contains(name))
                m_dockGroups.append(name);
        }
        if (!m_dockGroups.contains(QStringLiteral("zhyprbola")))
            m_dockGroups.append(QStringLiteral("zhyprbola"));
    }
    QFile dockGroupOrderFile(dockConfigPath(QStringLiteral("dock-group-order")));
    if (dockGroupOrderFile.open(QIODevice::ReadOnly)) {
        const QStringList names = m_dockGroupOrder;
        QStringList order;
        const QString contents = QString::fromUtf8(dockGroupOrderFile.readAll());
        for (const QString &name : contents.split(QRegularExpression(QStringLiteral("[\\s,]+")),
                 Qt::SkipEmptyParts)) {
            if (names.contains(name) && !order.contains(name)) order.append(name);
        }
        for (const QString &name : names)
            if (!order.contains(name)) order.append(name);
        m_dockGroupOrder = order;
    }
    const QStringList componentNames = dockComponentKeys();
    m_dockVisibleComponents = componentNames;
    QFile dockComponentsFile(dockConfigPath(QStringLiteral("dock-components")));
    if (dockComponentsFile.open(QIODevice::ReadOnly)) {
        const QJsonDocument document = QJsonDocument::fromJson(dockComponentsFile.readAll());
        const QJsonObject object = document.object();
        if (object.value(QStringLiteral("visible")).isArray()
            && object.value(QStringLiteral("hidden")).isArray()) {
            m_dockVisibleComponents.clear();
            for (const auto &entry : object.value(QStringLiteral("visible")).toArray()) {
                const QString name = entry.toString();
                if (componentNames.contains(name) && !m_dockVisibleComponents.contains(name))
                    m_dockVisibleComponents.append(name);
            }
            for (const auto &entry : object.value(QStringLiteral("hidden")).toArray()) {
                const QString name = entry.toString();
                if (componentNames.contains(name) && !m_dockVisibleComponents.contains(name)
                    && !m_dockHiddenComponents.contains(name))
                    m_dockHiddenComponents.append(name);
            }
            for (const QString &name : componentNames)
                if (!m_dockVisibleComponents.contains(name)
                    && !m_dockHiddenComponents.contains(name))
                    m_dockVisibleComponents.append(name);
        }
    }
    QFile wallpaperFile(dockConfigPath(QStringLiteral("use-wallpaper")));
    if (wallpaperFile.open(QIODevice::ReadOnly))
        m_useWallpaper = wallpaperFile.readAll().trimmed() == "true";
    QFile edgeEnabledFile(dockConfigPath(QStringLiteral("edge-spectrum-enabled")));
    if (edgeEnabledFile.open(QIODevice::ReadOnly))
        m_edgeSpectrumEnabled = edgeEnabledFile.readAll().trimmed() == "true";
    QFile edgePositionFile(dockConfigPath(QStringLiteral("edge-spectrum-position")));
    if (edgePositionFile.open(QIODevice::ReadOnly)) {
        const QString position = QString::fromUtf8(edgePositionFile.readAll()).trimmed();
        if (position == QLatin1String("left") || position == QLatin1String("right")
            || position == QLatin1String("top") || position == QLatin1String("bottom"))
            m_edgeSpectrumPosition = position;
    }
    loadTasks();

    m_location = qEnvironmentVariable("ZHYPRBOLA_LOCATION", "Bangkok");
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

void Backend::refreshTheme() {
    const QString configRoot = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation);
    QDir().mkpath(configRoot);
    const QString themeDir = QDir(configRoot).filePath(QStringLiteral("zhyprbola"));
    const QString themeFile = QDir(themeDir).filePath(QStringLiteral("theme"));
    for (const QString &path : {configRoot, themeDir, themeFile}) {
        if (QFileInfo::exists(path) && !m_themeWatcher.files().contains(path)
            && !m_themeWatcher.directories().contains(path))
            m_themeWatcher.addPath(path);
    }

    QFile file(themeFile);
    QString name = QStringLiteral("current");
    if (file.open(QIODevice::ReadOnly)) {
        const QString value = QString::fromUtf8(file.readAll()).trimmed();
        if (value == QLatin1String("white") || value == QLatin1String("white-sky")
            || value == QLatin1String("forest") || value == QLatin1String("one-half-gray")
            || value == QLatin1String("red"))
            name = value;
    }
    if (name != m_themeName) {
        m_themeName = name;
        emit themeChanged();
    }
}

void Backend::setThemeName(const QString &name) {
    static const QStringList names = {QStringLiteral("current"), QStringLiteral("white"),
        QStringLiteral("white-sky"), QStringLiteral("forest"),
        QStringLiteral("one-half-gray"), QStringLiteral("red")};
    if (!names.contains(name) || name == m_themeName) return;
    if (writeDockConfig(QStringLiteral("theme"), name)) refreshTheme();
}

void Backend::setDockPosition(const QString &position) {
    static const QStringList positions = {QStringLiteral("left"), QStringLiteral("right"),
        QStringLiteral("top"), QStringLiteral("bottom")};
    if (!positions.contains(position) || position == m_dockPosition) return;
    if (!writeDockConfig(QStringLiteral("dock-position"), position)) return;
    m_dockPosition = position;
    emit dockSettingsChanged();
}

void Backend::setDockBgOpacity(int opacity) {
    opacity = qBound(0, opacity, 100);
    if (opacity == m_dockBgOpacity) return;
    if (!writeDockConfig(QStringLiteral("dock-bg-opacity"), QString::number(opacity))) return;
    m_dockBgOpacity = opacity;
    emit dockSettingsChanged();
}

void Backend::setDockGroupEnabled(const QString &group, bool enabled) {
    static const QStringList names = {QStringLiteral("apps"),
        QStringLiteral("zhyprbola"), QStringLiteral("running")};
    if (!names.contains(group) || (group == QLatin1String("zhyprbola") && !enabled)
        || m_dockGroups.contains(group) == enabled) return;

    QStringList next = m_dockGroups;
    if (enabled) next.append(group);
    else next.removeAll(group);
    if (!writeDockConfig(QStringLiteral("dock-groups"), next.join(QLatin1Char(',')))) return;
    m_dockGroups = next;
    emit dockSettingsChanged();
}

void Backend::moveDockGroup(const QString &source, int targetIndex) {
    const int from = m_dockGroupOrder.indexOf(source);
    if (from < 0 || targetIndex < 0 || targetIndex >= m_dockGroupOrder.size()
        || from == targetIndex) return;
    QStringList next = m_dockGroupOrder;
    next.removeAt(from);
    next.insert(targetIndex, source);
    if (!writeDockConfig(QStringLiteral("dock-group-order"), next.join(QLatin1Char(',')))) return;
    m_dockGroupOrder = next;
    emit dockSettingsChanged();
}

void Backend::moveDockComponent(const QString &key, const QString &destination,
    const QString &beforeKey) {
    if (!dockComponentKeys().contains(key) || beforeKey == key
        || (destination != QLatin1String("visible")
            && destination != QLatin1String("hidden"))) return;

    QStringList visible = m_dockVisibleComponents;
    QStringList hidden = m_dockHiddenComponents;
    visible.removeAll(key);
    hidden.removeAll(key);
    QStringList &target = destination == QLatin1String("visible") ? visible : hidden;
    int index = beforeKey.isEmpty() ? target.size() : target.indexOf(beforeKey);
    if (index < 0) return;
    target.insert(index, key);
    if (visible == m_dockVisibleComponents && hidden == m_dockHiddenComponents) return;

    QJsonObject object;
    object.insert(QStringLiteral("visible"), QJsonArray::fromStringList(visible));
    object.insert(QStringLiteral("hidden"), QJsonArray::fromStringList(hidden));
    if (!writeDockConfig(QStringLiteral("dock-components"),
            QString::fromUtf8(QJsonDocument(object).toJson(QJsonDocument::Compact)))) return;
    m_dockVisibleComponents = visible;
    m_dockHiddenComponents = hidden;
    emit dockSettingsChanged();
}

void Backend::setDockUngroupWindows(bool enabled) {
    if (enabled == m_dockUngroupWindows) return;
    if (!writeDockConfig(QStringLiteral("dock-ungroup-windows"),
            enabled ? QStringLiteral("true") : QStringLiteral("false"))) return;
    m_dockUngroupWindows = enabled;
    emit dockSettingsChanged();
}

void Backend::setUseWallpaper(bool enabled) {
    if (enabled == m_useWallpaper) return;
    if (!writeDockConfig(QStringLiteral("use-wallpaper"), enabled ? QStringLiteral("true")
        : QStringLiteral("false"))) return;
    m_useWallpaper = enabled;
    emit dockSettingsChanged();
}

void Backend::setEdgeSpectrumEnabled(bool enabled) {
    if (enabled == m_edgeSpectrumEnabled) return;
    if (!writeDockConfig(QStringLiteral("edge-spectrum-enabled"),
        enabled ? QStringLiteral("true") : QStringLiteral("false"))) return;
    m_edgeSpectrumEnabled = enabled;
    emit edgeSpectrumSettingsChanged();
}

void Backend::setEdgeSpectrumPosition(const QString &position) {
    static const QStringList positions = {QStringLiteral("left"), QStringLiteral("right"),
        QStringLiteral("top"), QStringLiteral("bottom")};
    if (!positions.contains(position) || position == m_edgeSpectrumPosition) return;
    if (!writeDockConfig(QStringLiteral("edge-spectrum-position"), position)) return;
    m_edgeSpectrumPosition = position;
    emit edgeSpectrumSettingsChanged();
}

void Backend::loadTasks() {
    QFile file(dockConfigPath(QStringLiteral("tasks.json")));
    if (!file.open(QIODevice::ReadOnly))
        return;

    const QJsonDocument document = QJsonDocument::fromJson(file.readAll());
    if (!document.isArray())
        return;

    QVariantList tasks;
    for (const QJsonValue &value : document.array()) {
        const QJsonObject object = value.toObject();
        const QString id = object.value(QStringLiteral("id")).toString();
        const QString text = object.value(QStringLiteral("text")).toString().trimmed();
        if (id.isEmpty() || text.isEmpty())
            continue;

        QVariantMap task;
        task.insert(QStringLiteral("id"), id);
        task.insert(QStringLiteral("text"), text);
        task.insert(QStringLiteral("done"), object.value(QStringLiteral("done")).toBool());
        task.insert(QStringLiteral("createdAt"),
            object.value(QStringLiteral("createdAt")).toString());
        task.insert(QStringLiteral("doneAt"),
            object.value(QStringLiteral("doneAt")).toString());
        tasks.append(task);
    }
    m_tasks = tasks;
}

bool Backend::saveTasks() const {
    const QString path = dockConfigPath(QStringLiteral("tasks.json"));
    if (!QDir().mkpath(QFileInfo(path).absolutePath()))
        return false;

    QJsonArray array;
    for (const QVariant &entry : m_tasks) {
        const QVariantMap task = entry.toMap();
        QJsonObject object;
        object.insert(QStringLiteral("id"), task.value(QStringLiteral("id")).toString());
        object.insert(QStringLiteral("text"), task.value(QStringLiteral("text")).toString());
        object.insert(QStringLiteral("done"), task.value(QStringLiteral("done")).toBool());
        object.insert(QStringLiteral("createdAt"),
            task.value(QStringLiteral("createdAt")).toString());
        object.insert(QStringLiteral("doneAt"), task.value(QStringLiteral("doneAt")).toString());
        array.append(object);
    }

    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return false;
    if (file.write(QJsonDocument(array).toJson(QJsonDocument::Indented)) < 0)
        return false;
    return file.commit();
}

int Backend::taskIndex(const QString &id) const {
    for (int index = 0; index < m_tasks.size(); ++index) {
        if (m_tasks.at(index).toMap().value(QStringLiteral("id")).toString() == id)
            return index;
    }
    return -1;
}

void Backend::addTask(const QString &text) {
    const QString trimmed = text.trimmed();
    if (trimmed.isEmpty())
        return;

    QVariantMap task;
    task.insert(QStringLiteral("id"), QStringLiteral("%1-%2")
        .arg(QDateTime::currentMSecsSinceEpoch())
        .arg(QUuid::createUuid().toString(QUuid::Id128).left(8)));
    task.insert(QStringLiteral("text"), trimmed);
    task.insert(QStringLiteral("done"), false);
    task.insert(QStringLiteral("createdAt"), timestamp());
    task.insert(QStringLiteral("doneAt"), QString());

    QVariantList next = m_tasks;
    next.append(task);
    m_tasks = next;
    if (saveTasks())
        emit tasksChanged();
}

void Backend::toggleTask(const QString &id) {
    const int index = taskIndex(id);
    if (index < 0)
        return;

    QVariantMap task = m_tasks.at(index).toMap();
    const bool done = !task.value(QStringLiteral("done")).toBool();
    task.insert(QStringLiteral("done"), done);
    task.insert(QStringLiteral("doneAt"), done ? timestamp() : QString());
    m_tasks[index] = task;
    if (saveTasks())
        emit tasksChanged();
}

void Backend::renameTask(const QString &id, const QString &text) {
    const int index = taskIndex(id);
    const QString trimmed = text.trimmed();
    if (index < 0 || trimmed.isEmpty())
        return;

    QVariantMap task = m_tasks.at(index).toMap();
    if (task.value(QStringLiteral("text")).toString() == trimmed)
        return;
    task.insert(QStringLiteral("text"), trimmed);
    m_tasks[index] = task;
    if (saveTasks())
        emit tasksChanged();
}

void Backend::moveTask(const QString &id, int targetIndex) {
    const int from = taskIndex(id);
    if (from < 0 || m_tasks.size() < 2)
        return;

    targetIndex = qBound(0, targetIndex, m_tasks.size());
    if (from == targetIndex || from + 1 == targetIndex)
        return;

    const QVariant task = m_tasks.takeAt(from);
    if (from < targetIndex)
        --targetIndex;
    m_tasks.insert(targetIndex, task);
    if (saveTasks())
        emit tasksChanged();
}

void Backend::deleteTask(const QString &id) {
    const int index = taskIndex(id);
    if (index < 0)
        return;

    m_tasks.removeAt(index);
    if (saveTasks())
        emit tasksChanged();
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
            m_ramDetail = formatGiB(used * 1024) + QStringLiteral("/")
                + formatGiB(totalKiB * 1024) + QStringLiteral("GB");
        }
    }

    const QStorageInfo disk = QStorageInfo::root();
    if (disk.isValid() && disk.bytesTotal() > 0) {
        const quint64 total = disk.bytesTotal();
        const quint64 used = total - disk.bytesAvailable();
        m_diskPercent = qRound(double(used) * 100 / double(total));
        m_diskDetail = formatGiB(used) + QStringLiteral("/")
            + formatGiB(total) + QStringLiteral("GB");
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

    refreshBluetoothDevices();
    emit systemChanged();
}

void Backend::refreshWeather() {
    QUrl url(QStringLiteral("https://api.open-meteo.com/v1/forecast"));
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("latitude"), qEnvironmentVariable("ZHYPRBOLA_LATITUDE", "13.7563"));
    query.addQueryItem(QStringLiteral("longitude"), qEnvironmentVariable("ZHYPRBOLA_LONGITUDE", "100.5018"));
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
        m_trackId.clear();
        m_positionMs = 0;
        m_durationMs = 0;
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
        m_durationMs = qMax<qint64>(0, metadata.value(QStringLiteral("mpris:length")).toLongLong() / 1000);
        m_trackId = trackPath.path();
        m_positionMs = qMax<qint64>(0, mprisProperty(selected, QStringLiteral("Position")).toLongLong() / 1000);
        m_playing = mprisProperty(selected, QStringLiteral("PlaybackStatus")).toString() == QLatin1String("Playing");
        emit musicChanged();
        return;
    }

    const QString metadata = playerctl({QStringLiteral("-p"), selected, QStringLiteral("metadata"),
        QStringLiteral("--format"), QStringLiteral("{{title}}\x1f{{artist}}\x1f{{mpris:length}}")});
    const QStringList fields = metadata.split(QChar(0x1f));
    m_songTitle = fields.value(0).isEmpty() ? QStringLiteral("Unknown track") : fields.value(0);
    m_artist = fields.value(1).isEmpty() ? selected.section('.', 0, 0) : fields.value(1);
    m_durationMs = qMax<qint64>(0, fields.value(2).toLongLong() / 1000);
    m_positionMs = qMax<qint64>(0, qRound64(playerctl({QStringLiteral("-p"), selected, QStringLiteral("position")}).toDouble() * 1000));
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
    refreshWifiNetworks();
}

void Backend::setWifiEnabled(bool enabled) {
    if (QStandardPaths::findExecutable(QStringLiteral("nmcli")).isEmpty()) return;

    QProcess::startDetached(QStringLiteral("nmcli"),
        {QStringLiteral("radio"), QStringLiteral("wifi"),
         enabled ? QStringLiteral("on") : QStringLiteral("off")});
    QTimer::singleShot(800, this, &Backend::refreshSystem);
}

void Backend::refreshWifiNetworks() {
    QVariantList networks;
    if (QStandardPaths::findExecutable(QStringLiteral("nmcli")).isEmpty()) {
        if (m_wifiNetworks != networks) {
            m_wifiNetworks = networks;
            emit wifiNetworksChanged();
        }
        return;
    }

    QProcess nmcli;
    nmcli.start(QStringLiteral("nmcli"),
        {QStringLiteral("-t"), QStringLiteral("-f"),
         QStringLiteral("ACTIVE,SSID,SIGNAL,SECURITY"),
         QStringLiteral("dev"), QStringLiteral("wifi"), QStringLiteral("list"),
         QStringLiteral("--rescan"), QStringLiteral("no")});
    if (!nmcli.waitForFinished(900) || nmcli.exitCode() != 0) return;

    QSet<QString> savedSsids;
    QProcess profiles;
    profiles.start(QStringLiteral("nmcli"),
        {QStringLiteral("-t"), QStringLiteral("--escape"), QStringLiteral("no"),
         QStringLiteral("-f"), QStringLiteral("NAME,TYPE"),
         QStringLiteral("connection"), QStringLiteral("show")});
    if (profiles.waitForFinished(900) && profiles.exitCode() == 0) {
        for (const QByteArray &line : profiles.readAllStandardOutput().split('\n')) {
            const int separator = line.lastIndexOf(':');
            if (separator < 0) continue;
            const QByteArray type = line.mid(separator + 1).trimmed();
            if (type == "wifi" || type == "802-11-wireless")
                savedSsids.insert(QString::fromUtf8(line.left(separator)));
        }
    }

    QMap<QString, QVariantMap> bySsid;
    for (const QByteArray &row : nmcli.readAllStandardOutput().split('\n')) {
        if (row.trimmed().isEmpty()) continue;

        const QList<QByteArray> fields = splitNetworkRow(row);
        if (fields.size() < 4) continue;

        const QString ssid = QString::fromUtf8(fields.at(1)).trimmed();
        if (ssid.isEmpty()) continue;

        bool validSignal = false;
        const int signal = QString::fromUtf8(fields.at(2)).trimmed().toInt(&validSignal);
        const bool active = fields.at(0).trimmed() == "yes";
        const QString security = QString::fromUtf8(fields.at(3)).trimmed();
        const bool secure = !security.isEmpty() && security != QLatin1String("--");

        QVariantMap entry = bySsid.value(ssid);
        const int existingSignal = entry.value(QStringLiteral("signal")).toInt();
        if (entry.isEmpty() || active || (validSignal && signal > existingSignal)) {
            entry.insert(QStringLiteral("ssid"), ssid);
            entry.insert(QStringLiteral("signal"), validSignal ? qBound(0, signal, 100) : 0);
            entry.insert(QStringLiteral("secure"), secure);
            entry.insert(QStringLiteral("saved"), savedSsids.contains(ssid));
            entry.insert(QStringLiteral("security"), secure ? security : QStringLiteral("Open"));
            entry.insert(QStringLiteral("active"), active);
            bySsid.insert(ssid, entry);
        }
    }

    QList<QVariantMap> sorted;
    for (const QVariantMap &entry : bySsid)
        sorted.append(entry);
    std::sort(sorted.begin(), sorted.end(), [](const QVariantMap &a, const QVariantMap &b) {
        if (a.value(QStringLiteral("active")).toBool() != b.value(QStringLiteral("active")).toBool())
            return a.value(QStringLiteral("active")).toBool();
        return a.value(QStringLiteral("signal")).toInt() > b.value(QStringLiteral("signal")).toInt();
    });

    for (const QVariantMap &entry : sorted)
        networks.append(entry);

    if (m_wifiNetworks != networks) {
        m_wifiNetworks = networks;
        emit wifiNetworksChanged();
    }
}

void Backend::scanWifiNetworks() {
    if (QStandardPaths::findExecutable(QStringLiteral("nmcli")).isEmpty()) return;

    refreshSystem();
    refreshWifiNetworks();
    QProcess::startDetached(QStringLiteral("nmcli"),
        {QStringLiteral("dev"), QStringLiteral("wifi"), QStringLiteral("rescan")});
    QTimer::singleShot(1400, this, [this]() {
        refreshSystem();
        refreshWifiNetworks();
    });
}

void Backend::connectWifiNetwork(const QString &ssid, bool secure, bool saved,
    const QString &password) {
    if (ssid.isEmpty() || QStandardPaths::findExecutable(QStringLiteral("nmcli")).isEmpty()) return;

    QStringList arguments = {QStringLiteral("--wait"), QStringLiteral("20")};
    if (saved && password.isEmpty())
        arguments << QStringLiteral("connection") << QStringLiteral("up")
                  << QStringLiteral("id") << ssid;
    else
        arguments << QStringLiteral("device") << QStringLiteral("wifi")
                  << QStringLiteral("connect") << ssid;
    if (!password.isEmpty())
        arguments << QStringLiteral("password") << password;

    auto *process = new QProcess(this);
    const bool needsPasswordOnFailure = secure && password.isEmpty();
    connect(process, &QProcess::finished, this,
        [this, process, ssid, needsPasswordOnFailure](int exitCode, QProcess::ExitStatus status) {
        const bool success = status == QProcess::NormalExit && exitCode == 0;
        refreshSystem();
        refreshWifiNetworks();
        emit wifiConnectionFinished(ssid, success, !success && needsPasswordOnFailure);
        process->deleteLater();
    });
    connect(process, &QProcess::errorOccurred, this,
        [this, process, ssid](QProcess::ProcessError error) {
        if (error != QProcess::FailedToStart) return;
        emit wifiConnectionFinished(ssid, false, false);
        process->deleteLater();
    });
    process->start(QStringLiteral("nmcli"), arguments);
}

void Backend::disconnectWifiNetwork(const QString &ssid) {
    if (ssid.isEmpty() || !m_wifiConnected
        || QStandardPaths::findExecutable(QStringLiteral("nmcli")).isEmpty()) return;

    const QString profileName = m_wifiSsid;
    auto *process = new QProcess(this);
    connect(process, &QProcess::finished, this,
        [this, process, ssid](int exitCode, QProcess::ExitStatus status) {
        const bool success = status == QProcess::NormalExit && exitCode == 0;
        refreshSystem();
        refreshWifiNetworks();
        emit wifiDisconnectionFinished(ssid, success);
        process->deleteLater();
    });
    connect(process, &QProcess::errorOccurred, this,
        [this, process, ssid](QProcess::ProcessError error) {
        if (error != QProcess::FailedToStart) return;
        emit wifiDisconnectionFinished(ssid, false);
        process->deleteLater();
    });
    process->start(QStringLiteral("nmcli"),
        {QStringLiteral("--wait"), QStringLiteral("10"),
         QStringLiteral("connection"), QStringLiteral("down"),
         QStringLiteral("id"), profileName});
}

void Backend::refreshBluetoothDevices() {
    const bool available = !QStandardPaths::findExecutable(QStringLiteral("bluetoothctl")).isEmpty();
    m_bluetoothAvailable = available;
    m_bluetoothEnabled = false;
    m_bluetoothConnected = false;
    m_bluetoothDeviceName = QStringLiteral("Bluetooth off");
    m_bluetoothStatusText = available ? QStringLiteral("Bluetooth off") : QStringLiteral("Bluetooth unavailable");

    QVariantList devices;
    if (!available) {
        if (m_bluetoothDevices != devices) {
            m_bluetoothDevices = devices;
            emit bluetoothDevicesChanged();
        }
        return;
    }

    const QString show = runBluetoothctl({QStringLiteral("show")});
    m_bluetoothEnabled = bluetoothInfoValue(show, QStringLiteral("Powered")) == QLatin1String("yes");
    if (!m_bluetoothEnabled) {
        const QString powerState = bluetoothInfoValue(show, QStringLiteral("PowerState"));
        m_bluetoothStatusText = powerState.isEmpty()
            ? QStringLiteral("Radio disabled")
            : powerState;
    }

    const QString output = runBluetoothctl({QStringLiteral("devices")});
    QList<QVariantMap> parsedDevices;
    for (const QString &line : output.split('\n')) {
        const QString trimmed = line.trimmed();
        if (!trimmed.startsWith(QStringLiteral("Device "))) continue;

        const QString address = trimmed.section(' ', 1, 1);
        const QString fallbackName = trimmed.section(' ', 2).trimmed();
        if (address.isEmpty()) continue;

        const QString info = runBluetoothctl({QStringLiteral("info"), address});
        const QString name = bluetoothInfoValue(info, QStringLiteral("Name"));
        const bool paired = bluetoothInfoValue(info, QStringLiteral("Paired")) == QLatin1String("yes");
        const bool trusted = bluetoothInfoValue(info, QStringLiteral("Trusted")) == QLatin1String("yes");
        const bool connected = bluetoothInfoValue(info, QStringLiteral("Connected")) == QLatin1String("yes");
        const QString icon = bluetoothInfoValue(info, QStringLiteral("Icon"));

        QVariantMap device;
        device.insert(QStringLiteral("address"), address);
        device.insert(QStringLiteral("name"), name.isEmpty() ? fallbackName : name);
        device.insert(QStringLiteral("paired"), paired);
        device.insert(QStringLiteral("trusted"), trusted);
        device.insert(QStringLiteral("connected"), connected);
        device.insert(QStringLiteral("icon"), icon);
        parsedDevices.append(device);

        if (connected) {
            m_bluetoothConnected = true;
            m_bluetoothDeviceName = device.value(QStringLiteral("name")).toString();
            m_bluetoothStatusText = QStringLiteral("Connected");
        }
    }

    if (m_bluetoothEnabled && !m_bluetoothConnected) {
        m_bluetoothDeviceName = QStringLiteral("Bluetooth on");
        m_bluetoothStatusText = parsedDevices.isEmpty()
            ? QStringLiteral("No devices")
            : QStringLiteral("%1 device%2").arg(parsedDevices.size()).arg(parsedDevices.size() == 1 ? QString() : QStringLiteral("s"));
    }

    std::sort(parsedDevices.begin(), parsedDevices.end(), [](const QVariantMap &a, const QVariantMap &b) {
        if (a.value(QStringLiteral("connected")).toBool() != b.value(QStringLiteral("connected")).toBool())
            return a.value(QStringLiteral("connected")).toBool();
        if (a.value(QStringLiteral("paired")).toBool() != b.value(QStringLiteral("paired")).toBool())
            return a.value(QStringLiteral("paired")).toBool();
        return a.value(QStringLiteral("name")).toString().localeAwareCompare(
            b.value(QStringLiteral("name")).toString()) < 0;
    });

    for (const QVariantMap &device : parsedDevices)
        devices.append(device);

    if (m_bluetoothDevices != devices) {
        m_bluetoothDevices = devices;
        emit bluetoothDevicesChanged();
    }
}

void Backend::openBluetoothSettings() {
    QStringList command;
    if (!QStandardPaths::findExecutable(QStringLiteral("gnome-control-center")).isEmpty()) {
        command = {QStringLiteral("gnome-control-center"), QStringLiteral("bluetooth")};
    } else if (!QStandardPaths::findExecutable(QStringLiteral("blueman-manager")).isEmpty()) {
        command = {QStringLiteral("blueman-manager")};
    }
    if (!command.isEmpty()) QProcess::startDetached(command.first(), command.mid(1));
}

void Backend::setBluetoothEnabled(bool enabled) {
    if (QStandardPaths::findExecutable(QStringLiteral("bluetoothctl")).isEmpty()) return;

    QProcess::startDetached(QStringLiteral("bluetoothctl"),
        {QStringLiteral("power"), enabled ? QStringLiteral("on") : QStringLiteral("off")});
    QTimer::singleShot(900, this, &Backend::refreshSystem);
}

void Backend::scanBluetoothDevices() {
    if (QStandardPaths::findExecutable(QStringLiteral("bluetoothctl")).isEmpty()) return;

    refreshBluetoothDevices();
    QProcess::startDetached(QStringLiteral("bluetoothctl"),
        {QStringLiteral("--timeout"), QStringLiteral("5"), QStringLiteral("scan"), QStringLiteral("on")});
    QTimer::singleShot(1400, this, &Backend::refreshBluetoothDevices);
    QTimer::singleShot(5400, this, &Backend::refreshSystem);
}

void Backend::connectBluetoothDevice(const QString &address) {
    if (address.isEmpty() || QStandardPaths::findExecutable(QStringLiteral("bluetoothctl")).isEmpty()) return;

    QProcess::startDetached(QStringLiteral("bluetoothctl"), {QStringLiteral("connect"), address});
    QTimer::singleShot(1600, this, &Backend::refreshSystem);
    QTimer::singleShot(4000, this, &Backend::refreshSystem);
}

void Backend::disconnectBluetoothDevice(const QString &address) {
    if (address.isEmpty() || QStandardPaths::findExecutable(QStringLiteral("bluetoothctl")).isEmpty()) return;

    QProcess::startDetached(QStringLiteral("bluetoothctl"), {QStringLiteral("disconnect"), address});
    QTimer::singleShot(1000, this, &Backend::refreshSystem);
    QTimer::singleShot(3000, this, &Backend::refreshSystem);
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
