#pragma once
#include <QObject>
#include <QTimer>
#include <QStringList>
#include <QVariant>
#include "MediaManager.h"
#include "MediaItem.h"
#include "../ui/OutputWindow.h"

class SlideshowController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString currentImagePath READ currentImagePath NOTIFY currentImagePathChanged)
public:
    explicit SlideshowController(MediaManager *mediaManager,
                                 OutputWindow *outputWindow,
                                 QObject *parent = nullptr);

    Q_INVOKABLE void start(int intervalMs);
    Q_INVOKABLE void stop();
    Q_INVOKABLE void pause();
    Q_INVOKABLE bool isRunning() const { return m_timer.isActive(); }
    Q_INVOKABLE void setImageList(QVariant listModel); // Set custom image list from QML ListModel

    QString currentImagePath() const { return m_currentImagePath; }

signals:
    void currentImagePathChanged();
    void started(); // Emitted when slideshow starts or resumes

private slots:
    void advance();

private:
    int findNextImageIndex(int from) const;

    MediaManager *m_mediaManager;
    OutputWindow *m_outputWindow;
    QTimer m_timer;
    int m_currentIndex = -1; // index in current image list
    QString m_currentImagePath;
    QStringList m_customImageList; // Custom image paths from QML
    bool m_useCustomList = false;
};