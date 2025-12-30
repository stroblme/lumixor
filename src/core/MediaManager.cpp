#include "MediaManager.h"
#include <QFileInfo>

MediaManager::MediaManager(QObject *parent)
    : QObject(parent)
{
}

void MediaManager::addMedia(const QString &path)
{
    QFileInfo fi(path);
    QString ext = fi.suffix().toLower();

    MediaType type = MediaType::Unknown;
    if (ext == "mp4" || ext == "mov" || ext == "mkv" || ext == "avi")
    {
        type = MediaType::Video;
    }
    else if (ext == "jpg" || ext == "jpeg" || ext == "png" || ext == "bmp")
    {
        type = MediaType::Image;
    }

    if (type == MediaType::Unknown)
        return;

    MediaItem item;
    item.path = path;
    item.type = type;
    m_items.push_back(item);

    emit itemsChanged();
}

int MediaManager::count() const
{
    return m_items.size();
}

QString MediaManager::pathAt(int index) const
{
    if (index < 0 || index >= m_items.size())
        return QString();
    return m_items[index].path;
}

QString MediaManager::typeAt(int index) const
{
    if (index < 0 || index >= m_items.size())
        return QString();
    switch (m_items[index].type)
    {
    case MediaType::Video:
        return "video";
    case MediaType::Image:
        return "image";
    default:
        return "unknown";
    }
}

QVariantList MediaManager::qmlItems() const
{
    QVariantList list;
    for (const auto &item : m_items)
    {
        QVariantMap m;
        m["path"] = item.path;
        m["type"] = (item.type == MediaType::Video) ? QString("video") : QString("image");
        list.append(m);
    }
    return list;
}