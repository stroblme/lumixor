#pragma once
#include <QObject>
#include <QTimer>
#include "MediaManager.h"
#include "MediaItem.h"
#include "../ui/OutputWindow.h"

class SlideshowController : public QObject
{
    Q_OBJECT
public:
    explicit SlideshowController(MediaManager *mediaManager,
                                 OutputWindow *outputWindow,
                                 QObject *parent = nullptr);

    void start(int intervalMs);
    void stop();
    void pause();
    bool isRunning() const { return m_timer.isActive(); }

private slots:
    void advance();

private:
    int findNextImageIndex(int from) const;

    MediaManager *m_mediaManager;
    OutputWindow *m_outputWindow;
    QTimer m_timer;
    int m_currentIndex = -1; // index in MediaManager::items()
};