#include "ExifImageProvider.h"

#include <QImageReader>
#include <QUrl>
#include <QDebug>

ExifImageProvider::ExifImageProvider()
    : QQuickImageProvider(QQuickImageProvider::Image)
{
}

ExifImageProvider::~ExifImageProvider()
{
}

// Size to decode at, expressed in the file's own orientation so that the transformed
// result fits requestedSize. An invalid size means decode the file as stored.
static QSize scaledSizeFor(const QImageReader &reader, const QSize &requestedSize)
{
    const QSize stored = reader.size();
    if (stored.isEmpty())
        return QSize();

    // A quarter turn swaps width and height, so the fit is computed against what will
    // actually be displayed.
    const bool swapsAxes = reader.transformation() & QImageIOHandler::TransformationRotate90;
    const QSize displayed = swapsAxes ? stored.transposed() : stored;

    // QML leaves a dimension at zero when only one half of sourceSize is set, which
    // means that axis is unbounded.
    const int maxWidth = requestedSize.width() > 0 ? requestedSize.width() : displayed.width();
    const int maxHeight = requestedSize.height() > 0 ? requestedSize.height() : displayed.height();

    // Enlarging a small image wastes memory and adds nothing, so only ever scale down.
    if (displayed.width() <= maxWidth && displayed.height() <= maxHeight)
        return QSize();

    const QSize fitted = displayed.scaled(QSize(maxWidth, maxHeight), Qt::KeepAspectRatio);
    return swapsAxes ? fitted.transposed() : fitted;
}

QImage ExifImageProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    const QString filePath = QUrl::fromPercentEncoding(id.toUtf8());

    QImageReader reader(filePath);
    // Applies the EXIF orientation as part of read().
    reader.setAutoTransform(true);

    // Decoding straight to the display size costs about half of decoding at full
    // resolution and rescaling afterwards, and it keeps a full resolution texture off
    // the render thread that also composites the video layers.
    const QSize scaled = scaledSizeFor(reader, requestedSize);
    if (!scaled.isEmpty())
        reader.setScaledSize(scaled);

    const QImage img = reader.read();
    if (img.isNull())
    {
        qWarning() << "ExifImageProvider: failed to read image:" << filePath << " error:" << reader.errorString();
        return QImage();
    }

    if (size)
        *size = img.size();

    return img;
}
