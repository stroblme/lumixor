// src/core/PlaybackController.h
#pragma once
#include "MediaItem.h"
#include <QObject>

class PlaybackController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString source READ source NOTIFY sourceChanged)
public:
    explicit PlaybackController(QObject *parent = nullptr);

    QString source() const { return m_source; }

    Q_INVOKABLE void loadMediaPath(const QString &path);
    Q_INVOKABLE void loadMedia(const MediaItem &item) { loadMediaPath(item.path); }
    Q_INVOKABLE void play();
    Q_INVOKABLE void pause();
    Q_INVOKABLE void stop();
    Q_INVOKABLE bool isPlaying() const { return m_isPlaying; }

signals:
    void mediaFinished();
    void playRequested();
    void pauseRequested();
    void stopRequested();
    void sourceChanged();

public slots:
    Q_INVOKABLE void notifyMediaFinished();

private:
    QString m_source;
    bool m_isPlaying = false;
};