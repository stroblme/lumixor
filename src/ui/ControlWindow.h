// src/ui/ControlWindow.h
#pragma once
#include <QMainWindow>

#include "../core/MediaManager.h"
#include "../core/PlaybackController.h"
#include "../core/SlideshowController.h"
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
    ~ControlWindow();

protected:
    void closeEvent(QCloseEvent *event) override;

private slots:
    void onAddMedia();
    void onPlaySelected();
    void onStop();
    void onMediaFinished();

    void onStartSlideshow(); // must exist in .cpp
    void onStopSlideshow();  // must exist in .cpp
    void onBlackoutClicked();

private:
    void refreshImageList();
    void refreshVideoList();
    void refreshLists();

    Ui::ControlWindow *ui;
    MediaManager *m_mediaManager;
    PlaybackController *m_playbackController;
    OutputWindow *m_outputWindow;

    SlideshowController m_slideshow;
};