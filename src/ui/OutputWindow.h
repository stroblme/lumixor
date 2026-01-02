#pragma once
#include <QObject>

#include "../core/PlaybackController.h"

class OutputWindow : public QObject
{
    Q_OBJECT
public:
    explicit OutputWindow(PlaybackController *playbackController,
                          QObject *parent = nullptr);

    // Attach the QML root Window object (call after engine has loaded the QML)
    Q_INVOKABLE void setRootObject(QObject *root);
    Q_INVOKABLE void close();

    void fullscreenOnScreen(int screenIndex = 1);

public slots:
    Q_INVOKABLE void showVideo();
    Q_INVOKABLE void showImage(const QString &path);
    Q_INVOKABLE void fadeToImage(const QString &path);
    Q_INVOKABLE void setBlackout(bool enable);
    Q_INVOKABLE void setBrightness(double level);
    Q_INVOKABLE void setImageBrightness(double level);
    Q_INVOKABLE void setVideoBrightness(double level);

private:
    QObject *m_root = nullptr;
    PlaybackController *m_playbackController = nullptr;
};