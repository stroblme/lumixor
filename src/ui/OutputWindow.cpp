#include "OutputWindow.h"
#include <QMetaObject>
#include <QWindow>
#include <QScreen>
#include <QGuiApplication>
#include <QDebug>

OutputWindow::OutputWindow(PlaybackController *playbackController,
                           QObject *parent)
    : QObject(parent),
      m_playbackController(playbackController)
{
}

void OutputWindow::setRootObject(QObject *root)
{
    m_root = root;
    qDebug() << "OutputWindow: attached to QML root" << root;
}

void OutputWindow::fullscreenOnScreen(int screenIndex)
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

    window->setScreen(target);
    QRect geo = target->geometry();
    window->setX(geo.x());
    window->setY(geo.y());
    window->showFullScreen();
}

void OutputWindow::showVideo()
{
    qDebug() << "OutputWindow: showVideo()" << (m_root != nullptr);
    if (!m_root)
        return;
    QMetaObject::invokeMethod(m_root, "showVideo");
}

void OutputWindow::showImage(const QString &path)
{
    qDebug() << "OutputWindow: showImage(" << path << ") root=" << (m_root != nullptr);
    if (!m_root)
        return;
    QMetaObject::invokeMethod(m_root, "showImage", Q_ARG(QVariant, QVariant(path)));
}

void OutputWindow::fadeToImage(const QString &path)
{
    qDebug() << "OutputWindow: fadeToImage(" << path << ") root=" << (m_root != nullptr);
    if (!m_root)
        return;
    QMetaObject::invokeMethod(m_root, "fadeToImage", Q_ARG(QVariant, QVariant(path)));
}

void OutputWindow::setBlackout(bool enable)
{
    qDebug() << "OutputWindow: setBlackout(" << enable << ")";
    if (!m_root)
        return;
    QMetaObject::invokeMethod(m_root, "setBlackout", Q_ARG(QVariant, QVariant(enable)));
}

void OutputWindow::setBrightness(double level)
{
    qDebug() << "OutputWindow: setBrightness(" << level << ")";
    if (!m_root)
        return;
    QMetaObject::invokeMethod(m_root, "setBrightness", Q_ARG(QVariant, QVariant(level)));
}

void OutputWindow::setImageBrightness(double level)
{
    qDebug() << "OutputWindow: setImageBrightness(" << level << ")";
    if (!m_root)
        return;
    QMetaObject::invokeMethod(m_root, "setImageBrightness", Q_ARG(QVariant, QVariant(level)));
}

void OutputWindow::setVideoBrightness(double level)
{
    qDebug() << "OutputWindow: setVideoBrightness(" << level << ")";
    if (!m_root)
        return;
    QMetaObject::invokeMethod(m_root, "setVideoBrightness", Q_ARG(QVariant, QVariant(level)));
}

void OutputWindow::setVideoLayer(int tabId, const QString &path, double brightness, bool playing)
{
    qDebug() << "OutputWindow: setVideoLayer(" << tabId << "," << path << "," << brightness << "," << playing << ")";
    if (!m_root)
        return;
    QMetaObject::invokeMethod(m_root, "setVideoLayer",
                              Q_ARG(QVariant, QVariant(tabId)),
                              Q_ARG(QVariant, QVariant(path)),
                              Q_ARG(QVariant, QVariant(brightness)),
                              Q_ARG(QVariant, QVariant(playing)));
}

void OutputWindow::removeVideoLayer(int tabId)
{
    qDebug() << "OutputWindow: removeVideoLayer(" << tabId << ")";
    if (!m_root)
        return;
    QMetaObject::invokeMethod(m_root, "removeVideoLayer", Q_ARG(QVariant, QVariant(tabId)));
}

void OutputWindow::close()
{
    qDebug() << "OutputWindow: close() root=" << (m_root != nullptr);
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