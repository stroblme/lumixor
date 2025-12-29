#include "OutputWindow.h"
#include "forms/ui_OutputWindow.h"

#include <QApplication>
#include <QScreen>
#include <QPixmap>
#include <QDebug>

OutputWindow::OutputWindow(PlaybackController *playbackController,
                           QWidget *parent)
    : QMainWindow(parent),
      ui(new Ui::OutputWindow),
      m_playbackController(playbackController)
{
    ui->setupUi(this);

    // Ensure the label’s object name is "imageLabel" (matches QSS)
    ui->imageLabel->setObjectName("imageLabel");

    m_playbackController->player()->setVideoOutput(ui->videoWidget);
}

OutputWindow::~OutputWindow()
{
    delete ui;
}

void OutputWindow::fullscreenOnScreen(int screenIndex)
{
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

    QRect geo = target->geometry();
    move(geo.topLeft());
    showFullScreen();
}

void OutputWindow::showVideo()
{
    ui->stackedLayout->setCurrentWidget(ui->videoWidget);
}

void OutputWindow::showImage(const QString &path)
{
    QPixmap pix(path);
    if (pix.isNull())
    {
        qWarning() << "Failed to load image:" << path;
        return;
    }
    ui->imageLabel->setPixmap(
        pix.scaled(size(), Qt::KeepAspectRatio, Qt::SmoothTransformation));
    ui->stackedLayout->setCurrentWidget(ui->imageLabel);
}

void OutputWindow::setBlackout(bool enable)
{
    if (enable)
    {
        ui->stackedLayout->setCurrentWidget(ui->blackoutWidget);
    }
    else
    {
        // Use non-deprecated overload
        QPixmap pixmap = ui->imageLabel->pixmap(Qt::ReturnByValue);
        if (!pixmap.isNull())
        {
            ui->stackedLayout->setCurrentWidget(ui->imageLabel);
        }
        else
        {
            ui->stackedLayout->setCurrentWidget(ui->videoWidget);
        }
    }
}