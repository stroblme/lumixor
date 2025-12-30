#pragma once

#include <QQuickImageProvider>
#include <QImage>

class ExifImageProvider : public QQuickImageProvider
{
public:
    ExifImageProvider();
    ~ExifImageProvider();

    // QQuickImageProvider API
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;

private:
    int readExifOrientation(const QString &filePath) const;
    QImage applyExifOrientation(const QImage &img, int orientation) const;
};
