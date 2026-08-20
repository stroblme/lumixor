// Guards the two things the provider does beyond a plain image load: it honours the
// EXIF orientation, and it decodes at the size QML asked for so a full-resolution
// texture never reaches the render thread.
#include <QtTest>
#include <QBuffer>
#include <QImage>
#include <QTemporaryDir>
#include "ui/ExifImageProvider.h"

class TestExifImageProvider : public QObject
{
    Q_OBJECT

private:
    QTemporaryDir m_dir;
    QString writeJpeg(const QString &name, const QSize &size, int exifOrientation);

private slots:
    void appliesExifOrientation();
    void decodesAtRequestedSizePreservingAspectRatio();
    void neverUpscalesBeyondTheStoredSize();
    void decodesFullSizeWhenNoSizeRequested();
};

// Writes a JPEG and splices an EXIF APP1 segment carrying nothing but the
// orientation tag straight after the SOI marker, which is where a camera puts it.
QString TestExifImageProvider::writeJpeg(const QString &name, const QSize &size, int exifOrientation)
{
    QImage img(size, QImage::Format_RGB32);
    for (int y = 0; y < size.height(); ++y)
        for (int x = 0; x < size.width(); ++x)
            img.setPixel(x, y, qRgb((x * 7) % 256, (y * 5) % 256, ((x + y) * 3) % 256));

    QByteArray jpeg;
    QBuffer buffer(&jpeg);
    buffer.open(QIODevice::WriteOnly);
    if (!img.save(&buffer, "JPEG", 95))
        return QString();
    buffer.close();

    if (exifOrientation > 0)
    {
        QByteArray app1;
        app1.append("\xFF\xE1", 2);             // APP1 marker
        app1.append("\x00\x22", 2);             // segment length, 34 bytes
        app1.append("Exif\x00\x00", 6);         // EXIF identifier
        app1.append("II\x2A\x00", 4);           // little endian TIFF header
        app1.append("\x08\x00\x00\x00", 4);     // offset of IFD0
        app1.append("\x01\x00", 2);             // one directory entry
        app1.append("\x12\x01", 2);             // tag 0x0112, orientation
        app1.append("\x03\x00", 2);             // type SHORT
        app1.append("\x01\x00\x00\x00", 4);     // count
        app1.append(char(exifOrientation));     // value, stored inline
        app1.append("\x00\x00\x00", 3);
        app1.append("\x00\x00\x00\x00", 4);     // no next IFD
        jpeg.insert(2, app1);                   // after SOI
    }

    const QString path = m_dir.path() + QLatin1Char('/') + name;
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly))
        return QString();
    f.write(jpeg);
    f.close();
    return path;
}

void TestExifImageProvider::appliesExifOrientation()
{
    // Orientation 6 is a quarter turn, so a landscape file displays as a portrait image.
    const QString path = writeJpeg(QStringLiteral("rotated.jpg"), QSize(400, 200), 6);
    QVERIFY(!path.isEmpty());

    ExifImageProvider provider;
    QSize reported;
    const QImage img = provider.requestImage(path, &reported, QSize());

    QCOMPARE(img.size(), QSize(200, 400));
    QCOMPARE(reported, img.size());
}

void TestExifImageProvider::decodesAtRequestedSizePreservingAspectRatio()
{
    const QString path = writeJpeg(QStringLiteral("large.jpg"), QSize(2000, 1000), 0);
    QVERIFY(!path.isEmpty());

    ExifImageProvider provider;
    QSize reported;
    const QImage img = provider.requestImage(path, &reported, QSize(500, 500));

    // Fitted into the requested box rather than stretched to fill it.
    QCOMPARE(img.size(), QSize(500, 250));
    QCOMPARE(reported, img.size());

    // The requested size is measured on the displayed image, so a rotated file has to
    // fit the same box.
    const QString rotated = writeJpeg(QStringLiteral("large-rotated.jpg"), QSize(2000, 1000), 6);
    QVERIFY(!rotated.isEmpty());
    const QImage rotatedImg = provider.requestImage(rotated, &reported, QSize(500, 500));
    QCOMPARE(rotatedImg.size(), QSize(250, 500));
}

void TestExifImageProvider::neverUpscalesBeyondTheStoredSize()
{
    const QString path = writeJpeg(QStringLiteral("small.jpg"), QSize(64, 48), 0);
    QVERIFY(!path.isEmpty());

    ExifImageProvider provider;
    QSize reported;
    const QImage img = provider.requestImage(path, &reported, QSize(3840, 2160));

    QCOMPARE(img.size(), QSize(64, 48));
}

void TestExifImageProvider::decodesFullSizeWhenNoSizeRequested()
{
    const QString path = writeJpeg(QStringLiteral("plain.jpg"), QSize(800, 600), 0);
    QVERIFY(!path.isEmpty());

    ExifImageProvider provider;
    QSize reported;
    const QImage img = provider.requestImage(path, &reported, QSize());

    QCOMPARE(img.size(), QSize(800, 600));
}

QTEST_MAIN(TestExifImageProvider)
#include "tst_exifimageprovider.moc"
