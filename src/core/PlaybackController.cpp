// src/core/PlaybackController.cpp
#include "PlaybackController.h"
#include <QDebug>
#include <QUrl>

PlaybackController::PlaybackController(QObject *parent)
    : QObject(parent)
{
}

void PlaybackController::loadMediaPath(const QString &path)
{
    m_source = QUrl::fromLocalFile(path).toString();
    emit sourceChanged();
}

void PlaybackController::play()
{
    if (m_source.isEmpty())
    {
        qWarning() << "No media loaded!";
        return;
    }
    m_isPlaying = true;
    emit playRequested();
}

void PlaybackController::pause()
{
    m_isPlaying = false;
    emit pauseRequested();
}

void PlaybackController::stop()
{
    m_isPlaying = false;
    emit stopRequested();
}

void PlaybackController::notifyMediaFinished()
{
    m_isPlaying = false;
    emit mediaFinished();
}