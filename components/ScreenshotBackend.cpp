#include "ScreenshotBackend.h"

#include <QClipboard>
#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QSet>
#include <QStandardPaths>
#include <QUuid>
#include <QUrl>

ScreenshotBackend::ScreenshotBackend(const QString &directory, QObject *parent)
    : QAbstractListModel(parent), m_directory(directory.isEmpty()
          ? QDir(QStandardPaths::writableLocation(QStandardPaths::PicturesLocation))
                .filePath(QStringLiteral("Screenshots"))
          : QDir(directory).absolutePath()) {
    const QString configDir = QDir(QStandardPaths::writableLocation(QStandardPaths::ConfigLocation))
        .filePath(QStringLiteral("zhyprbola"));
    QDir().mkpath(configDir);
    m_settingsPath = QDir(configDir).filePath(QStringLiteral("screenshots-edge"));
    m_watcher.addPath(configDir);
    m_refreshTimer.setSingleShot(true);
    m_refreshTimer.setInterval(150);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged,
        &m_refreshTimer, qOverload<>(&QTimer::start));
    connect(&m_refreshTimer, &QTimer::timeout, this, &ScreenshotBackend::refresh);
    refresh();
}

int ScreenshotBackend::rowCount(const QModelIndex &parent) const {
    return parent.isValid() ? 0 : m_paths.size();
}

QVariant ScreenshotBackend::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() < 0 || index.row() >= m_paths.size()) return {};
    const QFileInfo file(m_paths[index.row()]);
    switch (role) {
    case NameRole: return file.fileName();
    case PathRole: return file.absoluteFilePath();
    case UrlRole: return QUrl::fromLocalFile(file.absoluteFilePath());
    case ModifiedRole: return file.lastModified().toString(QStringLiteral("yyyy-MM-dd HH:mm:ss"));
    default: return {};
    }
}

QHash<int, QByteArray> ScreenshotBackend::roleNames() const {
    return {{NameRole, "fileName"}, {PathRole, "filePath"},
        {UrlRole, "imageUrl"}, {ModifiedRole, "modified"}};
}

void ScreenshotBackend::setError(const QString &error) {
    if (m_error == error) return;
    m_error = error;
    emit errorChanged();
}

void ScreenshotBackend::refresh() {
    QFile theme(QDir(QFileInfo(m_settingsPath).absolutePath()).filePath(QStringLiteral("theme")));
    if (theme.open(QIODevice::ReadOnly)) {
        const QString name = QString::fromUtf8(theme.readAll()).trimmed();
        if (!name.isEmpty() && name != m_theme) {
            m_theme = name;
            emit themeChanged();
        }
    }
    QFile settings(m_settingsPath);
    if (settings.open(QIODevice::ReadOnly)) {
        const QJsonObject object = QJsonDocument::fromJson(settings.readAll()).object();
        const QString side = object.value(QStringLiteral("side")).toString();
        const QString alignment = object.value(QStringLiteral("alignment")).toString();
        if ((side == QLatin1String("left") || side == QLatin1String("right"))
            && (alignment == QLatin1String("top") || alignment == QLatin1String("center")
                || alignment == QLatin1String("bottom"))
            && (side != m_side || alignment != m_alignment)) {
            m_side = side;
            m_alignment = alignment;
            emit positionChanged();
        }
    }
    QDir dir(m_directory);
    // Watch the parent too, so a missing Screenshots directory can appear later.
    for (const QString &path : {m_directory, QFileInfo(m_directory).absolutePath()})
        if (QFileInfo::exists(path) && !m_watcher.directories().contains(path))
            m_watcher.addPath(path);
    QStringList paths;
    for (const QFileInfo &file : dir.entryInfoList(
             {QStringLiteral("*.png"), QStringLiteral("*.jpg"), QStringLiteral("*.jpeg"),
              QStringLiteral("*.webp"), QStringLiteral("*.bmp")},
             QDir::Files | QDir::Readable | QDir::NoSymLinks, QDir::Time | QDir::Name))
        paths.append(file.absoluteFilePath());
    if (paths != m_paths) {
        beginResetModel();
        m_paths = paths;
        endResetModel();
    }
    QStringList selected;
    for (const QString &path : m_selected)
        if (m_paths.contains(path)) selected.append(path);
    if (selected != m_selected) {
        m_selected = selected;
        emit selectionChanged();
    }
    if (!m_paths.contains(m_anchor)) m_anchor.clear();
}

void ScreenshotBackend::Show() {
    refresh();
    if (m_opened) return;
    m_opened = true;
    emit openedChanged();
}

void ScreenshotBackend::Hide() {
    if (!m_opened) return;
    m_opened = false;
    emit openedChanged();
}

void ScreenshotBackend::dismiss() {
    Hide();
    emit dismissRequested();
}

void ScreenshotBackend::Quit() {
    QCoreApplication::exit(0);
}

void ScreenshotBackend::setPosition(const QString &side, const QString &alignment) {
    if ((side != QLatin1String("left") && side != QLatin1String("right"))
        || (alignment != QLatin1String("top") && alignment != QLatin1String("center")
            && alignment != QLatin1String("bottom"))) return;
    QSaveFile settings(m_settingsPath);
    const QByteArray json = QJsonDocument(QJsonObject{{QStringLiteral("side"), side},
        {QStringLiteral("alignment"), alignment}}).toJson();
    if (!settings.open(QIODevice::WriteOnly) || settings.write(json) != json.size()
        || !settings.commit()) {
        setError(QStringLiteral("Cannot save edge position."));
        return;
    }
    m_side = side;
    m_alignment = alignment;
    emit positionChanged();
}

void ScreenshotBackend::select(int index, bool control, bool shift) {
    if (index < 0 || index >= m_paths.size()) return;
    const QString path = m_paths[index];
    if (shift && m_paths.contains(m_anchor)) {
        if (!control) m_selected.clear();
        const int anchor = m_paths.indexOf(m_anchor);
        for (int i = qMin(anchor, index); i <= qMax(anchor, index); ++i)
            if (!m_selected.contains(m_paths[i])) m_selected.append(m_paths[i]);
    } else if (control) {
        if (!m_selected.removeAll(path)) m_selected.append(path);
        m_anchor = path;
    } else {
        m_selected = {path};
        m_anchor = path;
    }
    // Clipboard paths always follow the visible order, even after Ctrl-click.
    QStringList ordered;
    for (const QString &item : m_paths)
        if (m_selected.contains(item)) ordered.append(item);
    m_selected = ordered;
    emit selectionChanged();
}

void ScreenshotBackend::selectAll() {
    m_selected = m_paths;
    emit selectionChanged();
}

void ScreenshotBackend::selectIndices(const QVariantList &indices) {
    QSet<int> selectedIndices;
    for (const QVariant &value : indices) {
        bool valid = false;
        const int index = value.toInt(&valid);
        if (valid && index >= 0 && index < m_paths.size()) selectedIndices.insert(index);
    }
    QStringList selected;
    for (int index = 0; index < m_paths.size(); ++index)
        if (selectedIndices.contains(index)) selected.append(m_paths[index]);
    if (selected == m_selected) return;
    m_selected = selected;
    m_anchor = selected.isEmpty() ? QString() : selected.last();
    emit selectionChanged();
}

void ScreenshotBackend::copyPaths() {
    if (!m_selected.isEmpty())
        QGuiApplication::clipboard()->setText(m_selected.join(QLatin1Char('\n')));
}

void ScreenshotBackend::deleteSelected() {
    setError({});
    if (m_selected.isEmpty()) return;
    const QString transaction = QDir(m_directory).filePath(QStringLiteral(".zhyprbola-trash/%1-%2")
        .arg(QDateTime::currentMSecsSinceEpoch(), 16, 10, QLatin1Char('0'))
        .arg(QUuid::createUuid().toString(QUuid::WithoutBraces)));
    if (!QDir().mkpath(transaction)) {
        setError(QStringLiteral("Cannot create undo storage."));
        return;
    }
    QJsonArray names;
    for (const QString &path : m_selected) names.append(QFileInfo(path).fileName());
    // Journal first: a crash between renames remains recoverable with Ctrl+Z.
    QSaveFile manifest(QDir(transaction).filePath(QStringLiteral("manifest.json")));
    const QByteArray json = QJsonDocument(names).toJson();
    if (!manifest.open(QIODevice::WriteOnly) || manifest.write(json) != json.size()
        || !manifest.commit()) {
        QDir(transaction).removeRecursively();
        setError(QStringLiteral("Cannot save undo history; no files deleted."));
        return;
    }
    for (const QString &path : m_selected) {
        if (!m_paths.contains(path)) continue;
        if (!QFile::rename(path, QDir(transaction).filePath(QFileInfo(path).fileName())))
            setError(QStringLiteral("Some images could not be deleted."));
    }
    refresh();
}

void ScreenshotBackend::undo() {
    setError({});
    QDir trash(QDir(m_directory).filePath(QStringLiteral(".zhyprbola-trash")));
    const QStringList transactions = trash.entryList(QDir::Dirs | QDir::NoDotAndDotDot,
        QDir::Name | QDir::Reversed);
    for (const QString &id : transactions) {
        QDir transaction(trash.filePath(id));
        QFile manifest(transaction.filePath(QStringLiteral("manifest.json")));
        if (!manifest.open(QIODevice::ReadOnly)) continue;
        QJsonParseError parseError;
        const QJsonDocument document = QJsonDocument::fromJson(manifest.readAll(), &parseError);
        if (parseError.error != QJsonParseError::NoError || !document.isArray()) continue;
        bool found = false;
        bool conflict = false;
        QStringList restored;
        for (const QJsonValue &entry : document.array()) {
            const QString name = entry.toString();
            if (name.isEmpty() || name == QLatin1String(".") || name == QLatin1String("..")
                || name.contains(QLatin1Char('/')) || name.contains(QLatin1Char('\\'))) continue;
            const QString staged = transaction.filePath(name);
            if (!QFileInfo::exists(staged)) continue;
            found = true;
            const QString destination = QDir(m_directory).filePath(name);
            if (QFileInfo::exists(destination) || !QFile::rename(staged, destination)) {
                conflict = true;
                continue;
            }
            restored.append(destination);
        }
        if (!conflict) {
            QFile::remove(transaction.filePath(QStringLiteral("manifest.json")));
            trash.rmdir(id);
        }
        if (!found) continue;
        refresh();
        m_selected = restored;
        emit selectionChanged();
        if (conflict)
            setError(QStringLiteral("Some files could not be restored. Existing files were kept."));
        return;
    }
}
