// src/core/PlaybackController.h
#pragma once
#include "MediaItem.h"
#include <QObject>
#include <QMediaPlayer>
#include <QUrl>

class PlaybackController : public QObject
{
    Q_OBJECT
public:
    explicit PlaybackController(QObject *parent = nullptr);

    QMediaPlayer *player() { return &m_player; }

    // Load via MediaItem (as used by ControlWindow.cpp)
    void loadMedia(const MediaItem &item);
    void play();
    void pause();
    void stop();
    bool isPlaying() const { return m_player.state() == QMediaPlayer::PlayingState; }

signals:
    void mediaFinished();

private slots:
    void handleStateChanged(QMediaPlayer::State state);

private:
    QMediaPlayer m_player;
};