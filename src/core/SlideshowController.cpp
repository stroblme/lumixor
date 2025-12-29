#include "SlideshowController.h"
#include <QDebug>

SlideshowController::SlideshowController(MediaManager *mediaManager,
                                         OutputWindow *outputWindow,
                                         QObject *parent)
    : QObject(parent),
      m_mediaManager(mediaManager),
      m_outputWindow(outputWindow)
{
    connect(&m_timer, &QTimer::timeout,
            this, &SlideshowController::advance);
}

void SlideshowController::start(int intervalMs)
{
    if (!m_mediaManager)
        return;

    const auto &items = m_mediaManager->items();
    if (items.isEmpty())
        return;

    // Start from first image
    m_currentIndex = findNextImageIndex(-1);
    if (m_currentIndex < 0)
        return;

    const MediaItem &item = items[m_currentIndex];
    m_outputWindow->fadeToImage(item.path);

    m_timer.start(intervalMs);
}

void SlideshowController::stop()
{
    m_timer.stop();
}

void SlideshowController::advance()
{
    if (!m_mediaManager)
        return;

    const auto &items = m_mediaManager->items();
    if (items.isEmpty())
        return;

    m_currentIndex = findNextImageIndex(m_currentIndex);
    if (m_currentIndex < 0)
        return;

    const MediaItem &item = items[m_currentIndex];
    m_outputWindow->fadeToImage(item.path);
}

int SlideshowController::findNextImageIndex(int from) const
{
    const auto &items = m_mediaManager->items();
    if (items.isEmpty())
        return -1;

    int count = items.size();
    int idx = from;

    // iterate through list once in cyclic manner, look for image
    for (int i = 0; i < count; ++i)
    {
        idx = (idx + 1 + count) % count;
        if (items[idx].type == MediaType::Image)
            return idx;
    }
    return -1; // no images
}