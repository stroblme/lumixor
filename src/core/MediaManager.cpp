#include "MediaManager.h"
#include <QFileInfo>
#include <QDir>
#include <QDirIterator>

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

void MediaManager::scanFolderRecursively(const QString &folderPath, QStringList &files)
{
    static const QStringList imageExtensions = {"jpg", "jpeg", "png", "bmp"};
    static const QStringList videoExtensions = {"mp4", "mov", "mkv", "avi"};

    QStringList allExtensions;
    for (const QString &ext : imageExtensions)
        allExtensions << "*." + ext;
    for (const QString &ext : videoExtensions)
        allExtensions << "*." + ext;

    QDirIterator it(folderPath, allExtensions, QDir::Files, QDirIterator::Subdirectories);
    while (it.hasNext())
    {
        files.append(it.next());
    }
}

int MediaManager::addMediaFromFolder(const QString &folderPath)
{
    if (folderPath.isEmpty())
        return 0;

    QStringList files;
    scanFolderRecursively(folderPath, files);

    // Sort files for consistent ordering
    files.sort(Qt::CaseInsensitive);

    int addedCount = 0;
    for (const QString &file : files)
    {
        int prevCount = m_items.size();
        addMedia(file);
        if (m_items.size() > prevCount)
            addedCount++;
    }

    return addedCount;
}

QString MediaManager::getMediaType(const QString &path) const
{
    QFileInfo fi(path);
    QString ext = fi.suffix().toLower();

    if (ext == "mp4" || ext == "mov" || ext == "mkv" || ext == "avi")
    {
        return "video";
    }
    else if (ext == "jpg" || ext == "jpeg" || ext == "png" || ext == "bmp")
    {
        return "image";
    }
    return QString();
}

QStringList MediaManager::getMediaPathsFromFolder(const QString &folderPath, const QString &filterType) const
{
    QStringList result;
    if (folderPath.isEmpty())
        return result;

    QStringList extensions;
    if (filterType == "image" || filterType.isEmpty())
    {
        extensions << "*.jpg" << "*.jpeg" << "*.png" << "*.bmp";
    }
    if (filterType == "video" || filterType.isEmpty())
    {
        extensions << "*.mp4" << "*.mov" << "*.mkv" << "*.avi";
    }

    QDirIterator it(folderPath, extensions, QDir::Files, QDirIterator::Subdirectories);
    while (it.hasNext())
    {
        QString path = it.next();
        // Only include files matching the filter type
        if (!filterType.isEmpty())
        {
            QString type = getMediaType(path);
            if (type == filterType)
            {
                result.append(path);
            }
        }
        else
        {
            result.append(path);
        }
    }

    result.sort(Qt::CaseInsensitive);
    return result;
}