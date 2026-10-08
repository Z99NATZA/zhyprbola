#pragma once

#include <QAbstractListModel>
#include <QFileSystemWatcher>
#include <QTimer>
#include <QVariantList>

class ScreenshotBackend : public QAbstractListModel {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.zhyprbola.Screenshots")
    Q_PROPERTY(QString directory READ directory CONSTANT)
    Q_PROPERTY(QStringList selectedPaths READ selectedPaths NOTIFY selectionChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    Q_PROPERTY(QString edgeSide READ edgeSide NOTIFY positionChanged)
    Q_PROPERTY(QString edgeAlignment READ edgeAlignment NOTIFY positionChanged)
    Q_PROPERTY(bool opened READ opened NOTIFY openedChanged)
    Q_PROPERTY(QString themeName READ themeName NOTIFY themeChanged)
public:
    explicit ScreenshotBackend(const QString &directory = {}, QObject *parent = nullptr);
    enum Roles { NameRole = Qt::UserRole + 1, PathRole, UrlRole, ModifiedRole };
    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;
    QString directory() const { return m_directory; }
    QStringList selectedPaths() const { return m_selected; }
    QString error() const { return m_error; }
    QString edgeSide() const { return m_side; }
    QString edgeAlignment() const { return m_alignment; }
    bool opened() const { return m_opened; }
    QString themeName() const { return m_theme; }
    Q_INVOKABLE void dismiss();
    Q_INVOKABLE void setPosition(const QString &side, const QString &alignment);
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void select(int index, bool control, bool shift);
    Q_INVOKABLE void selectIndices(const QVariantList &indices);
    Q_INVOKABLE void selectAll();
    Q_INVOKABLE void copyPaths();
    Q_INVOKABLE void deleteSelected();
    Q_INVOKABLE void undo();
public slots:
    Q_SCRIPTABLE void Show();
    Q_SCRIPTABLE void Hide();
    Q_SCRIPTABLE void Quit();
signals:
    void selectionChanged();
    void errorChanged();
    void positionChanged();
    void openedChanged();
    void themeChanged();
    Q_SCRIPTABLE void dismissRequested();
private:
    void setError(const QString &error);
    QString m_directory;
    QStringList m_paths;
    QStringList m_selected;
    QString m_anchor;
    QString m_error;
    QString m_side = QStringLiteral("left");
    QString m_alignment = QStringLiteral("center");
    QString m_settingsPath;
    QString m_theme = QStringLiteral("current");
    bool m_opened = true;
    QFileSystemWatcher m_watcher;
    QTimer m_refreshTimer;
};
