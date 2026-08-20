#include "SlideshowController.h"
#include "MediaTypes.h"
#include <QDebug>
#include <QQmlListReference>
#include <QAbstractListModel>

SlideshowController::SlideshowController(MediaManager *mediaManager,
                                         QObject *parent)
    : QObject(parent),
      m_mediaManager(mediaManager)
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

int SlideshowController::count() const
{
    if (m_useCustomList)
        return m_customImageList.size();
    return m_mediaManager ? m_mediaManager->items().size() : 0;
}

QString SlideshowController::pathAt(int index) const
{
    if (index < 0 || index >= count())
        return QString();
    if (m_useCustomList)
        return m_customImageList.at(index);
    return m_mediaManager->items().at(index).path;
}

bool SlideshowController::isImageAt(int index) const
{
    if (index < 0 || index >= count())
        return false;
    if (m_useCustomList)
        return MediaTypes::typeFor(m_customImageList.at(index)) == MediaType::Image;
    return m_mediaManager->items().at(index).type == MediaType::Image;
}

void SlideshowController::stopTimer()
{
    if (!m_timer.isActive())
        return;
    m_timer.stop();
    emit runningChanged();
}

// Publish the image at index, emitting only on an actual change of path.
void SlideshowController::showIndex(int index)
{
    const QString imagePath = pathAt(index);
    if (imagePath.isEmpty())
        return;
    m_currentIndex = index;
    if (imagePath == m_currentImagePath)
        return;
    m_currentImagePath = imagePath;
    emit currentImagePathChanged();
}

void SlideshowController::start(int intervalMs)
{
    // A zero or negative interval makes QTimer fire on every event loop pass, which
    // pins a CPU core and starves the UI.
    intervalMs = qBound(100, intervalMs, 3600 * 1000);

    if (count() == 0)
        return;

    qDebug() << "Slideshow start:" << intervalMs << "ms, items:" << count() << "currentIndex:" << m_currentIndex;

    // Resume from last image if paused, otherwise start from first image
    if (m_currentIndex < 0 || m_currentIndex >= count())
    {
        m_currentIndex = findNextImageIndex(-1);
    }

    // Show current image if not already shown
    if (m_currentIndex >= 0)
        showIndex(m_currentIndex);

    const bool wasRunning = m_timer.isActive();
    m_timer.start(intervalMs);
    emit started();
    if (!wasRunning)
        emit runningChanged();
}

void SlideshowController::stop()
{
    stopTimer();
}

void SlideshowController::reset()
{
    stopTimer();
    m_currentIndex = -1;
    m_currentImagePath.clear();
    emit currentImagePathChanged();
}

void SlideshowController::pause()
{
    // Same effect as stop(); kept separate because QML pauses and resumes without
    // discarding the current position, which reset() does discard.
    stopTimer();
}

void SlideshowController::setCurrentIndex(int index)
{
    if (index < 0 || index >= count())
    {
        qDebug() << "SlideshowController::setCurrentIndex: invalid index" << index;
        return;
    }

    showIndex(index);

    // If the slideshow is running, restart the timer to give the new image a full interval
    if (m_timer.isActive())
        m_timer.start(m_timer.interval());
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
    if (count() == 0)
        return;

    const int nextIndex = findNextImageIndex(m_currentIndex);
    if (nextIndex < 0)
    {
        // No further image and looping is off.
        stopTimer();
        emit slideshowEnded();
        return;
    }

    showIndex(nextIndex);
}

int SlideshowController::findNextImageIndex(int from) const
{
    const int total = count();
    if (total == 0)
        return -1;

    // Both backends are searched the same way, so a custom list no longer treats
    // every entry as an image while the MediaManager list filters by type.
    if (from < -1)
        from = -1;

    for (int step = 1; step <= total; ++step)
    {
        int idx = from + step;
        if (idx >= total)
        {
            if (!m_loopEnabled)
                return -1;
            idx %= total;
        }
        if (isImageAt(idx))
            return idx;
    }
    return -1;
}
