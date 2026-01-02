#include "SlideshowController.h"
#include <QDebug>
#include <QQmlListReference>
#include <QAbstractListModel>

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

void SlideshowController::setImageList(QVariant listModel)
{
    m_customImageList.clear();
    m_currentIndex = -1;

    QObject *obj = listModel.value<QObject *>();
    if (!obj)
    {
        m_useCustomList = false;
        return;
    }

    // Try to read from QML ListModel
    QAbstractListModel *model = qobject_cast<QAbstractListModel *>(obj);
    if (model)
    {
        int count = model->rowCount();
        QHash<int, QByteArray> roleNames = model->roleNames();
        int pathRole = -1;
        for (auto it = roleNames.begin(); it != roleNames.end(); ++it)
        {
            if (it.value() == "path")
            {
                pathRole = it.key();
                break;
            }
        }

        if (pathRole >= 0)
        {
            for (int i = 0; i < count; ++i)
            {
                QModelIndex idx = model->index(i, 0);
                QString path = model->data(idx, pathRole).toString();
                if (!path.isEmpty())
                {
                    m_customImageList.append(path);
                }
            }
        }
    }

    m_useCustomList = !m_customImageList.isEmpty();
    qDebug() << "SlideshowController: setImageList with" << m_customImageList.size() << "images";
}

void SlideshowController::start(int intervalMs)
{
    int itemCount = 0;

    if (m_useCustomList)
    {
        itemCount = m_customImageList.size();
    }
    else if (m_mediaManager)
    {
        const auto &items = m_mediaManager->items();
        itemCount = items.size();
    }

    if (itemCount == 0)
        return;

    qDebug() << "Slideshow start:" << intervalMs << "ms, items:" << itemCount << "currentIndex:" << m_currentIndex << "useCustomList:" << m_useCustomList;

    // Resume from last image if paused, otherwise start from first image
    if (m_currentIndex < 0 || m_currentIndex >= itemCount)
    {
        m_currentIndex = findNextImageIndex(-1);
    }

    // Show current image if not already shown
    if (m_currentIndex >= 0)
    {
        QString imagePath;
        if (m_useCustomList)
        {
            imagePath = m_customImageList[m_currentIndex];
        }
        else
        {
            const auto &items = m_mediaManager->items();
            if (m_currentIndex < items.size())
            {
                imagePath = items[m_currentIndex].path;
            }
        }

        if (!imagePath.isEmpty())
        {
            qDebug() << "Slideshow showing image index" << m_currentIndex << ":" << imagePath;
            m_currentImagePath = imagePath;
            emit currentImagePathChanged();
            m_outputWindow->fadeToImage(imagePath);
        }
    }

    m_timer.start(intervalMs);
    emit started();
}

void SlideshowController::stop()
{
    qDebug() << "Slideshow stop";
    m_timer.stop();
}

void SlideshowController::reset()
{
    qDebug() << "Slideshow reset";
    m_timer.stop();
    m_currentIndex = -1;
    m_currentImagePath.clear();
    emit currentImagePathChanged();
}

void SlideshowController::pause()
{
    qDebug() << "Slideshow pause";
    m_timer.stop();
}

void SlideshowController::setCurrentIndex(int index)
{
    int itemCount = 0;

    if (m_useCustomList)
    {
        itemCount = m_customImageList.size();
    }
    else if (m_mediaManager)
    {
        itemCount = m_mediaManager->items().size();
    }

    if (index < 0 || index >= itemCount)
    {
        qDebug() << "SlideshowController::setCurrentIndex: invalid index" << index << ", itemCount=" << itemCount;
        return;
    }

    m_currentIndex = index;

    // Update the current image path
    QString imagePath;
    if (m_useCustomList)
    {
        imagePath = m_customImageList[m_currentIndex];
    }
    else
    {
        const auto &items = m_mediaManager->items();
        if (m_currentIndex < items.size())
        {
            imagePath = items[m_currentIndex].path;
        }
    }

    if (!imagePath.isEmpty() && imagePath != m_currentImagePath)
    {
        m_currentImagePath = imagePath;
        emit currentImagePathChanged();
        qDebug() << "SlideshowController::setCurrentIndex: jumped to index" << index << "path=" << imagePath;
    }

    // If the slideshow is running, restart the timer to give full interval for the new image
    if (m_timer.isActive())
    {
        int interval = m_timer.interval();
        m_timer.start(interval);
    }
}

void SlideshowController::setLoopEnabled(bool enabled)
{
    if (m_loopEnabled != enabled)
    {
        m_loopEnabled = enabled;
        emit loopEnabledChanged();
        qDebug() << "SlideshowController: loop enabled =" << enabled;
    }
}

void SlideshowController::advance()
{
    int itemCount = 0;

    if (m_useCustomList)
    {
        itemCount = m_customImageList.size();
    }
    else if (m_mediaManager)
    {
        itemCount = m_mediaManager->items().size();
    }

    if (itemCount == 0)
        return;

    int nextIndex = findNextImageIndex(m_currentIndex);

    // Check if we've reached the end (findNextImageIndex returns -1 when looping is disabled and at end)
    if (nextIndex < 0)
    {
        qDebug() << "Slideshow reached end, looping disabled - stopping";
        m_timer.stop();
        emit slideshowEnded();
        return;
    }

    m_currentIndex = nextIndex;

    QString imagePath;
    if (m_useCustomList)
    {
        imagePath = m_customImageList[m_currentIndex];
    }
    else
    {
        const auto &items = m_mediaManager->items();
        if (m_currentIndex < items.size())
        {
            imagePath = items[m_currentIndex].path;
        }
    }

    if (!imagePath.isEmpty())
    {
        qDebug() << "Slideshow advance to" << m_currentIndex << ":" << imagePath;
        m_currentImagePath = imagePath;
        emit currentImagePathChanged();
        m_outputWindow->fadeToImage(imagePath);
    }
}

int SlideshowController::findNextImageIndex(int from) const
{
    int count = 0;

    if (m_useCustomList)
    {
        count = m_customImageList.size();
        if (count == 0)
            return -1;

        int nextIdx = from + 1;

        // Check if we've reached the end
        if (nextIdx >= count)
        {
            if (m_loopEnabled)
            {
                return 0; // Loop back to beginning
            }
            else
            {
                return -1; // No more images, don't loop
            }
        }

        return nextIdx;
    }

    // Fall back to MediaManager
    if (!m_mediaManager)
        return -1;

    const auto &items = m_mediaManager->items();
    if (items.isEmpty())
        return -1;

    count = items.size();
    int idx = from;
    int startIdx = from;

    // iterate through list looking for next image
    for (int i = 0; i < count; ++i)
    {
        idx = idx + 1;

        // Check if we've gone past the end
        if (idx >= count)
        {
            if (m_loopEnabled)
            {
                idx = 0; // Wrap around
            }
            else
            {
                return -1; // No more images, don't loop
            }
        }

        // Don't loop back to where we started if we've wrapped
        if (idx == startIdx && !m_loopEnabled)
            return -1;

        if (items[idx].type == MediaType::Image)
            return idx;
    }
    return -1; // no images
}