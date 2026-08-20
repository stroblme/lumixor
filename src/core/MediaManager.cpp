#include "MediaManager.h"
#include "MediaTypes.h"
#include <QDir>
#include <QDirIterator>

MediaManager::MediaManager(QObject *parent)
    : QObject(parent)
{
}

bool MediaManager::appendItem(const QString &path)
{
    const MediaType type = MediaTypes::typeFor(path);
    if (type == MediaType::Unknown)
        return false;

    MediaItem item;
    item.path = path;
    item.type = type;
    m_items.push_back(item);
    return true;
}

void MediaManager::addMedia(const QString &path)
{
    if (appendItem(path))
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
    return MediaTypes::nameFor(m_items[index].type);
}

QVariantList MediaManager::qmlItems() const
{
    QVariantList list;
    for (const auto &item : m_items)
    {
        QVariantMap m;
        m["path"] = item.path;
        m["type"] = MediaTypes::nameFor(item.type);
        list.append(m);
    }
    return list;
}

void MediaManager::scanFolderRecursively(const QString &folderPath, QStringList &files)
{
    QDirIterator it(folderPath, MediaTypes::globs(MediaType::Unknown), QDir::Files, QDirIterator::Subdirectories);
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
        if (appendItem(file))
            addedCount++;
    }

    if (addedCount > 0)
        emit itemsChanged();

    return addedCount;
}

QString MediaManager::getMediaType(const QString &path) const
{
    return MediaTypes::nameFor(MediaTypes::typeFor(path));
}

QStringList MediaManager::getMediaPathsFromFolder(const QString &folderPath, const QString &filterType) const
{
    QStringList result;
    if (folderPath.isEmpty())
        return result;

    QDirIterator it(folderPath, MediaTypes::globs(MediaTypes::fromName(filterType)),
                    QDir::Files, QDirIterator::Subdirectories);
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