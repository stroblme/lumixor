#pragma once
#include <QString>

enum class MediaType
{
    Video,
    Image,
    Unknown
};

struct MediaItem
{
    QString path;
    MediaType type = MediaType::Unknown;
};