#include "OutputBridge.h"
#include <QMetaObject>
#include <QWindow>
#include <QScreen>
#include <QGuiApplication>
#include <QDebug>

OutputBridge::OutputBridge(QObject *parent)
    : QObject(parent)
{
    connect(qApp, &QGuiApplication::screenAdded, this, &OutputBridge::screenCountChanged);
    connect(qApp, &QGuiApplication::screenRemoved, this, &OutputBridge::screenCountChanged);
}

void OutputBridge::setRootObject(QObject *root)
{
    m_root = root;
}

void OutputBridge::fullscreenOnScreen(int screenIndex)
{
    if (!m_root)
        return;

    QWindow *window = qobject_cast<QWindow *>(m_root);
    if (!window)
        return;

    const auto screens = qApp->screens();
    if (screens.isEmpty())
        return;

    QScreen *target = nullptr;
    if (screenIndex >= 0 && screenIndex < screens.size())
    {
        target = screens.at(screenIndex);
    }
    else
    {
        target = screens.at(0);
    }


    // First, ensure we're not in fullscreen mode to allow screen change
    if (window->windowState() & Qt::WindowFullScreen)
    {
        window->showNormal();
    }

    // Set the screen and move window to target screen's position
    window->setScreen(target);
    QRect geo = target->geometry();
    window->setGeometry(geo);
    window->showFullScreen();

}

void OutputBridge::moveToScreen(int screenIndex)
{
    fullscreenOnScreen(screenIndex);
}

int OutputBridge::screenCount() const
{
    return qApp->screens().size();
}

void OutputBridge::notifyMediaPosition(int tabId, int position)
{
    emit mediaPositionChanged(tabId, position);
}

void OutputBridge::notifyMediaDuration(int tabId, int duration)
{
    emit mediaDurationChanged(tabId, duration);
}

void OutputBridge::notifyMediaEnded(int tabId)
{
    emit mediaEnded(tabId);
}

void OutputBridge::setBrightness(double level)
{
    if (!m_root)
        return;
    QMetaObject::invokeMethod(m_root, "setBrightness", Q_ARG(QVariant, QVariant(level)));
}

void OutputBridge::setVideoLayer(int tabId, const QString &path, double brightness, bool playing, int zOrder)
{
    if (!m_root)
        return;
    QMetaObject::invokeMethod(m_root, "setVideoLayer",
                              Q_ARG(QVariant, QVariant(tabId)),
                              Q_ARG(QVariant, QVariant(path)),
                              Q_ARG(QVariant, QVariant(brightness)),
                              Q_ARG(QVariant, QVariant(playing)),
                              Q_ARG(QVariant, QVariant(zOrder)));
}

void OutputBridge::setImageLayer(int tabId, const QString &path, double brightness, int zOrder)
{
    if (!m_root)
        return;
    QMetaObject::invokeMethod(m_root, "setImageLayer",
                              Q_ARG(QVariant, QVariant(tabId)),
                              Q_ARG(QVariant, QVariant(path)),
                              Q_ARG(QVariant, QVariant(brightness)),
                              Q_ARG(QVariant, QVariant(zOrder)));
}

void OutputBridge::setMediaLayerBrightness(int tabId, double brightness)
{
    if (!m_root)
        return;
    QMetaObject::invokeMethod(m_root, "setMediaLayerBrightness",
                              Q_ARG(QVariant, QVariant(tabId)),
                              Q_ARG(QVariant, QVariant(brightness)));
}

void OutputBridge::setVideoLayerVolume(int tabId, double volume)
{
    if (!m_root)
        return;
    QMetaObject::invokeMethod(m_root, "setVideoLayerVolume",
                              Q_ARG(QVariant, QVariant(tabId)),
                              Q_ARG(QVariant, QVariant(volume)));
}

void OutputBridge::removeMediaLayer(int tabId)
{
    if (!m_root)
        return;
    QMetaObject::invokeMethod(m_root, "removeMediaLayer", Q_ARG(QVariant, QVariant(tabId)));
}

void OutputBridge::setMediaLayerZOrder(int tabId, int zOrder)
{
    if (!m_root)
        return;
    QMetaObject::invokeMethod(m_root, "setMediaLayerZOrder",
                              Q_ARG(QVariant, QVariant(tabId)),
                              Q_ARG(QVariant, QVariant(zOrder)));
}

void OutputBridge::stopMediaLayer(int tabId)
{
    if (!m_root)
        return;
    QMetaObject::invokeMethod(m_root, "stopMediaLayer",
                              Q_ARG(QVariant, QVariant(tabId)));
}

void OutputBridge::seekVideoLayer(int tabId, int position)
{
    if (!m_root)
        return;
    QMetaObject::invokeMethod(m_root, "seekVideoLayer",
                              Q_ARG(QVariant, QVariant(tabId)),
                              Q_ARG(QVariant, QVariant(position)));
}

void OutputBridge::close()
{
    if (!m_root)
        return;

    QWindow *window = qobject_cast<QWindow *>(m_root);
    if (window)
    {
        window->close();
    }
    else
    {
        // Fallback: try invoking a close() method on the QML side
        QMetaObject::invokeMethod(m_root, "close");
    }
}