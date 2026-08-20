#pragma once
#include <QObject>
#include <QPointer>

// Proxy to the QML output window: forwards layer and brightness calls to the root
// object of OutputWindow.qml. Not a window itself, despite the previous name.
class OutputBridge : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int screenCount READ screenCount NOTIFY screenCountChanged)
public:
    explicit OutputBridge(QObject *parent = nullptr);

    // Attach the QML root Window object (call after engine has loaded the QML)
    Q_INVOKABLE void setRootObject(QObject *root);
    Q_INVOKABLE void close();

    void fullscreenOnScreen(int screenIndex = 1);
    Q_INVOKABLE void moveToScreen(int screenIndex);
    Q_INVOKABLE int screenCount() const;

signals:
    void screenCountChanged();

public slots:
    Q_INVOKABLE void setBrightness(double level);
    Q_INVOKABLE void setVideoLayer(int tabId, const QString &path, double brightness, bool playing, int zOrder = -1);
    Q_INVOKABLE void setImageLayer(int tabId, const QString &path, double brightness, int zOrder);
    Q_INVOKABLE void setMediaLayerBrightness(int tabId, double brightness);
    Q_INVOKABLE void setVideoLayerVolume(int tabId, double volume);
    Q_INVOKABLE void removeMediaLayer(int tabId);
    Q_INVOKABLE void setMediaLayerZOrder(int tabId, int zOrder);
    Q_INVOKABLE void stopMediaLayer(int tabId);
    Q_INVOKABLE void seekVideoLayer(int tabId, int position);

private:
    QPointer<QObject> m_root;
};