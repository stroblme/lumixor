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
    Q_INVOKABLE void setVideoLayer(int tabId, const QString &path, double brightness, bool playing, int zOrder = -1);
    Q_INVOKABLE void setImageLayer(int tabId, const QString &path, double brightness, int zOrder);
    Q_INVOKABLE void setMediaLayerBrightness(int tabId, double brightness);
    Q_INVOKABLE void removeVideoLayer(int tabId);
    Q_INVOKABLE void removeMediaLayer(int tabId);
    Q_INVOKABLE void setVideoLayerZOrder(int tabId, int zOrder);
    Q_INVOKABLE void setMediaLayerZOrder(int tabId, int zOrder);
    Q_INVOKABLE void stopMediaLayer(int tabId);
    Q_INVOKABLE void setExternalMediaTabsModel(QObject *model);

private:
    QObject *m_root = nullptr;
    PlaybackController *m_playbackController = nullptr;
};