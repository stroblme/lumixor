#pragma once
#include <QObject>
#include <QTimer>
#include <QStringList>
#include <QVariant>
#include "MediaManager.h"
#include "MediaItem.h"
#include "../ui/OutputWindow.h"

class SlideshowController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString currentImagePath READ currentImagePath NOTIFY currentImagePathChanged)
    Q_PROPERTY(bool loopEnabled READ loopEnabled WRITE setLoopEnabled NOTIFY loopEnabledChanged)
public:
    explicit SlideshowController(MediaManager *mediaManager,
                                 OutputWindow *outputWindow,
                                 QObject *parent = nullptr);

    Q_INVOKABLE void start(int intervalMs);
    Q_INVOKABLE void stop();
    Q_INVOKABLE void pause();
    Q_INVOKABLE void reset(); // Stop and reset to initial state
    Q_INVOKABLE bool isRunning() const { return m_timer.isActive(); }
    Q_INVOKABLE void setImageList(QVariant listModel); // Set custom image list from QML ListModel
    Q_INVOKABLE void setCurrentIndex(int index);       // Jump to a specific index in the slideshow

    QString currentImagePath() const { return m_currentImagePath; }
    bool loopEnabled() const { return m_loopEnabled; }
    void setLoopEnabled(bool enabled);

signals:
    void currentImagePathChanged();
    void started(); // Emitted when slideshow starts or resumes
    void loopEnabledChanged();
    void slideshowEnded(); // Emitted when slideshow reaches end and looping is disabled

private slots:
    void advance();

private:
    int findNextImageIndex(int from) const;

    MediaManager *m_mediaManager;
    OutputWindow *m_outputWindow;
    QTimer m_timer;
    int m_currentIndex = -1; // index in current image list
    QString m_currentImagePath;
    QStringList m_customImageList; // Custom image paths from QML
    bool m_useCustomList = false;
    bool m_loopEnabled = true;
};