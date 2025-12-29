// src/ui/ControlWindow.h
#pragma once
#include <QMainWindow>

#include "../core/MediaManager.h"
#include "../core/PlaybackController.h"
#include "OutputWindow.h"

namespace Ui
{
    class ControlWindow;
}

class ControlWindow : public QMainWindow
{
    Q_OBJECT
public:
    ControlWindow(MediaManager *mediaManager,
                  PlaybackController *playbackController,
                  OutputWindow *outputWindow,
                  QWidget *parent = nullptr);
    ~ControlWindow(); // <-- explicitly declared

private slots:
    void onAddMedia();
    void onPlaySelected();
    void onStop();
    void onMediaFinished();

private:
    void refreshList();

    Ui::ControlWindow *ui;
    MediaManager *m_mediaManager;
    PlaybackController *m_playbackController;
    OutputWindow *m_outputWindow;
};