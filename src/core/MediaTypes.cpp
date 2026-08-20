#include "MediaTypes.h"

#include <QFileInfo>

namespace
{
struct Entry
{
    const char *extension;
    MediaType type;
};

const Entry kTable[] = {
    {"jpg", MediaType::Image},
    {"jpeg", MediaType::Image},
    {"png", MediaType::Image},
    {"bmp", MediaType::Image},
    {"mp4", MediaType::Video},
    {"mov", MediaType::Video},
    {"mkv", MediaType::Video},
    {"avi", MediaType::Video},
};
}

namespace MediaTypes
{

MediaType typeFor(const QString &path)
{
    const QString extension = QFileInfo(path).suffix().toLower();
    if (extension.isEmpty())
        return MediaType::Unknown;

    for (const Entry &entry : kTable)
    {
        if (extension == QLatin1String(entry.extension))
            return entry.type;
    }
    return MediaType::Unknown;
}

QString nameFor(MediaType type)
{
    switch (type)
    {
    case MediaType::Video:
        return QStringLiteral("video");
    case MediaType::Image:
        return QStringLiteral("image");
    default:
        return QString();
    }
}

MediaType fromName(const QString &name)
{
    if (name == QLatin1String("video"))
        return MediaType::Video;
    if (name == QLatin1String("image"))
        return MediaType::Image;
    return MediaType::Unknown;
}

QStringList globs(MediaType type)
{
    QStringList patterns;
    for (const Entry &entry : kTable)
    {
        if (type == MediaType::Unknown || entry.type == type)
            patterns << (QStringLiteral("*.") + QLatin1String(entry.extension));
    }
    return patterns;
}

QString dialogFilter()
{
    const QString images = globs(MediaType::Image).join(QLatin1Char(' '));
    const QString videos = globs(MediaType::Video).join(QLatin1Char(' '));
    const QString all = globs(MediaType::Unknown).join(QLatin1Char(' '));
    return QStringLiteral("Media Files (%1);;Images (%2);;Videos (%3);;All Files (*)")
        .arg(all, images, videos);
}

}
