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

    m_currentIndex = findNextImageIndex(m_currentIndex);
    if (m_currentIndex < 0)
        return;

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

        // All items in custom list are images, just cycle through
        return (from + 1 + count) % count;
    }

    // Fall back to MediaManager
    if (!m_mediaManager)
        return -1;

    const auto &items = m_mediaManager->items();
    if (items.isEmpty())
        return -1;

    count = items.size();
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