#pragma once
#include "MediaItem.h"
#include <QObject>
#include <QVector>

class MediaManager : public QObject
{
    Q_OBJECT
public:
    explicit MediaManager(QObject *parent = nullptr);

    Q_INVOKABLE int count() const;
    Q_INVOKABLE QString pathAt(int index) const;
    Q_INVOKABLE QString typeAt(int index) const; // "video" or "image"
    Q_INVOKABLE void addMedia(const QString &path);

    const QVector<MediaItem> &items() const { return m_items; }

private:
    QVector<MediaItem> m_items;
};