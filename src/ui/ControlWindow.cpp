// src/ui/ControlWindow.cpp
#include "ControlWindow.h"
#include "forms/ui_ControlWindow.h"

#include <QFileDialog>
#include <QFileInfo>

ControlWindow::ControlWindow(MediaManager *mediaManager,
                             PlaybackController *playbackController,
                             OutputWindow *outputWindow,
                             QWidget *parent)
    : QMainWindow(parent),
      ui(new Ui::ControlWindow),
      m_mediaManager(mediaManager),
      m_playbackController(playbackController),
      m_outputWindow(outputWindow)
{
    ui->setupUi(this);

    connect(ui->btnAdd, &QPushButton::clicked,
            this, &ControlWindow::onAddMedia);
    connect(ui->btnPlay, &QPushButton::clicked,
            this, &ControlWindow::onPlaySelected);
    connect(ui->btnStop, &QPushButton::clicked,
            this, &ControlWindow::onStop);

    connect(m_playbackController, &PlaybackController::mediaFinished,
            this, &ControlWindow::onMediaFinished);
}

ControlWindow::~ControlWindow()
{
    delete ui;
}

void ControlWindow::onAddMedia()
{
    QStringList paths = QFileDialog::getOpenFileNames(
        this, tr("Select media"));
    if (paths.isEmpty())
        return;

    for (const QString &p : paths)
    {
        m_mediaManager->addMedia(p);
    }
    refreshList();
}

void ControlWindow::onPlaySelected()
{
    int row = ui->listWidget->currentRow();
    if (row < 0)
        return;

    const auto &items = m_mediaManager->items();
    if (row >= items.size())
        return;

    const MediaItem &item = items[row];

    if (item.type == MediaType::Video)
    {
        m_playbackController->loadMedia(item);
        m_outputWindow->showVideo();
        m_playbackController->play();
        ui->statusLabel->setText("Playing video: " + item.path);
    }
    else if (item.type == MediaType::Image)
    {
        m_playbackController->stop();
        m_outputWindow->showImage(item.path);
        ui->statusLabel->setText("Showing image: " + item.path);
    }
}

void ControlWindow::onStop()
{
    m_playbackController->stop();
    ui->statusLabel->setText("Stopped");
}

void ControlWindow::onMediaFinished()
{
    ui->statusLabel->setText("Media finished");
}

void ControlWindow::refreshList()
{
    ui->listWidget->clear();
    const auto &items = m_mediaManager->items();
    for (const auto &item : items)
    {
        QString typeStr;
        switch (item.type)
        {
        case MediaType::Video:
            typeStr = "VIDEO";
            break;
        case MediaType::Image:
            typeStr = "IMAGE";
            break;
        default:
            typeStr = "UNKNOWN";
            break;
        }
        QFileInfo fi(item.path);
        ui->listWidget->addItem(typeStr + ": " + fi.fileName());
    }
}