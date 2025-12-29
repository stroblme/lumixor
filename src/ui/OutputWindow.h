#pragma once
#include <QMainWindow>

#include "../core/PlaybackController.h"

namespace Ui
{
    class OutputWindow;
}

class OutputWindow : public QMainWindow
{
    Q_OBJECT
public:
    explicit OutputWindow(PlaybackController *playbackController,
                          QWidget *parent = nullptr);
    ~OutputWindow();

    void fullscreenOnScreen(int screenIndex = 1);

public slots:
    void showVideo();
    void showImage(const QString &path);
    void setBlackout(bool enable);

private:
    Ui::OutputWindow *ui;
    PlaybackController *m_playbackController;
};