// src/core/PlaybackController.cpp
#include "PlaybackController.h"
#include <QDebug>

PlaybackController::PlaybackController(QObject *parent)
    : QObject(parent)
{
    m_player.setVolume(100);
    connect(&m_player, &QMediaPlayer::stateChanged,
            this, &PlaybackController::handleStateChanged);
}

void PlaybackController::loadMedia(const MediaItem &item)
{
    QUrl url = QUrl::fromLocalFile(item.path);
    m_player.setMedia(url);
}

void PlaybackController::play()
{
    if (m_player.mediaStatus() != QMediaPlayer::NoMedia)
    {
        m_player.play();
    }
    else
    {
        qWarning() << "No media loaded!";
    }
}

void PlaybackController::pause()
{
    m_player.pause();
}

void PlaybackController::stop()
{
    m_player.stop();
}

void PlaybackController::handleStateChanged(QMediaPlayer::State state)
{
    if (state == QMediaPlayer::StoppedState)
    {
        emit mediaFinished();
    }
}