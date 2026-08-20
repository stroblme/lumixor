#pragma once
#include "MediaItem.h"

#include <QString>
#include <QStringList>

// Single source of truth for which file extensions the app treats as media.
// Adding a format here updates classification, folder scanning and the file dialog
// filter together.
namespace MediaTypes
{
MediaType typeFor(const QString &path);

// "video", "image", or an empty string for MediaType::Unknown.
QString nameFor(MediaType type);
MediaType fromName(const QString &name);

// Glob patterns for QDirIterator. MediaType::Unknown yields every known pattern.
QStringList globs(MediaType type);

// Filter string for QFileDialog.
QString dialogFilter();
}
