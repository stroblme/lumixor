#include "ExifImageProvider.h"

#include <QFile>
#include <QByteArray>
#include <QImageReader>
#include <QTransform>
#include <QDebug>

ExifImageProvider::ExifImageProvider()
    : QQuickImageProvider(QQuickImageProvider::Image)
{
}

ExifImageProvider::~ExifImageProvider()
{
}

static int readExifOrientationFromFile(const QString &filePath)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly))
        return 1;

    QByteArray data = file.readAll();
    file.close();

    int pos = data.indexOf("Exif");
    if (pos < 0)
        return 1;

    // Skip "Exif\0\0"
    pos += 6;
    if (pos + 8 > data.size())
        return 1;

    // TIFF header (8 bytes: endian, 42, and IFD0 offset)
    bool isLittleEndian;
    if (data[pos] == 'I' && data[pos + 1] == 'I')
    {
        isLittleEndian = true;
    }
    else if (data[pos] == 'M' && data[pos + 1] == 'M')
    {
        isLittleEndian = false;
    }
    else
    {
        return 1;
    }

    auto read16 = [&](int off) -> quint16
    {
        if (off + 2 > data.size())
            return 0;
        const uchar *p = reinterpret_cast<const uchar *>(data.constData() + off);
        return isLittleEndian ? (quint16(p[0]) | (quint16(p[1]) << 8))
                              : (quint16(p[1]) | (quint16(p[0]) << 8));
    };

    auto read32 = [&](int off) -> quint32
    {
        if (off + 4 > data.size())
            return 0;
        const uchar *p = reinterpret_cast<const uchar *>(data.constData() + off);
        if (isLittleEndian)
        {
            return quint32(p[0]) |
                   (quint32(p[1]) << 8) |
                   (quint32(p[2]) << 16) |
                   (quint32(p[3]) << 24);
        }
        else
        {
            return quint32(p[3]) |
                   (quint32(p[2]) << 8) |
                   (quint32(p[1]) << 16) |
                   (quint32(p[0]) << 24);
        }
    };

    // Check TIFF magic (42)
    quint16 magic = read16(pos + 2);
    if (magic != 42)
        return 1;

    // Offset to 1st IFD, relative to start of TIFF header (pos)
    quint32 ifd0Offset = read32(pos + 4);
    if (ifd0Offset == 0 || pos + int(ifd0Offset) >= data.size())
        return 1;

    int ifdOffset = pos + int(ifd0Offset);

    // Number of directory entries (2 bytes)
    quint16 entryCount = read16(ifdOffset);
    int entriesBase = ifdOffset + 2;
    if (entriesBase + entryCount * 12 > data.size())
        return 1;

    // Each IFD entry is 12 bytes
    for (quint16 i = 0; i < entryCount; ++i)
    {
        int entryOffset = entriesBase + i * 12;
        quint16 tag = read16(entryOffset);
        quint16 type = read16(entryOffset + 2);
        quint32 count = read32(entryOffset + 4);
        quint32 valueOffset = read32(entryOffset + 8);

        // Orientation tag 0x0112, type SHORT (3), count = 1
        if (tag == 0x0112 && type == 3 && count == 1)
        {
            quint16 orientation;
            // For SHORT with count==1, value is stored directly in valueOffset field
            if (isLittleEndian)
            {
                orientation = quint16(valueOffset & 0xFFFF);
            }
            else
            {
                orientation = quint16((valueOffset >> 16) & 0xFFFF);
            }
            if (orientation >= 1 && orientation <= 8)
                return int(orientation);
            break;
        }
    }

    return 1; // default "no rotation"
}

static QImage applyExifOrientationToImage(const QImage &img, int orientation)
{
    QImage result = img;
    switch (orientation)
    {
    case 2:
        result = result.mirrored(true, false);
        break;
    case 3:
        result = result.transformed(QTransform().rotate(180));
        break;
    case 4:
        result = result.mirrored(false, true);
        break;
    case 5:
        result = result.mirrored(true, false).transformed(QTransform().rotate(90));
        break;
    case 6:
        result = result.transformed(QTransform().rotate(90));
        break;
    case 7:
        result = result.mirrored(true, false).transformed(QTransform().rotate(270));
        break;
    case 8:
        result = result.transformed(QTransform().rotate(270));
        break;
    default:
        break;
    }
    return result;
}

QImage ExifImageProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    QString decoded = QUrl::fromPercentEncoding(id.toUtf8());
    QString filePath = decoded;

    QImageReader reader(filePath);
    QImage img = reader.read();
    if (img.isNull())
    {
        qWarning() << "ExifImageProvider: failed to read image:" << filePath << " error:" << reader.errorString();
        return QImage();
    }

    int orientation = readExifOrientationFromFile(filePath);
    img = applyExifOrientationToImage(img, orientation);

    // Respect requested size if provided
    if (requestedSize.isValid())
    {
        img = img.scaled(requestedSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    }

    if (size)
        *size = img.size();

    return img;
}
