#pragma once
#include "MediaItem.h"
#include <QObject>
#include <QVector>
#include <QVariant>

class MediaManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList qmlItems READ qmlItems NOTIFY itemsChanged)
public:
    explicit MediaManager(QObject *parent = nullptr);

    Q_INVOKABLE int count() const;
    Q_INVOKABLE QString pathAt(int index) const;
    Q_INVOKABLE QString typeAt(int index) const; // "video" or "image"
    Q_INVOKABLE void addMedia(const QString &path);
    Q_INVOKABLE int addMediaFromFolder(const QString &folderPath);
    Q_INVOKABLE QString getMediaType(const QString &path) const; // Returns "video", "image", or empty string
    Q_INVOKABLE QStringList getMediaPathsFromFolder(const QString &folderPath, const QString &filterType) const;

    // Return a QVariantList suitable for binding from QML
    QVariantList qmlItems() const;

    const QVector<MediaItem> &items() const { return m_items; }

signals:
    void itemsChanged();

private:
    void scanFolderRecursively(const QString &folderPath, QStringList &files);
    QVector<MediaItem> m_items;
};