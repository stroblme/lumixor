// src/ui/ControlWindow.cpp
#include "ControlWindow.h"
#include "forms/ui_ControlWindow.h"

#include <QCloseEvent>
#include <QFileDialog>
#include <QFileInfo>
#include <QListWidget>

ControlWindow::ControlWindow(MediaManager *mediaManager,
                             PlaybackController *playbackController,
                             OutputWindow *outputWindow,
                             QWidget *parent)
    : QMainWindow(parent),
      ui(new Ui::ControlWindow),
      m_mediaManager(mediaManager),
      m_playbackController(playbackController),
      m_outputWindow(outputWindow),
      m_slideshow(mediaManager, outputWindow, this)
{
    ui->setupUi(this);
    setMinimumSize(500, 400); // avoid too cramped UI

    // Set icon size and spacing for both lists
    ui->listWidgetImages->setIconSize(QSize(0, 32));
    ui->listWidgetImages->setSpacing(2);
    ui->listWidgetVideos->setIconSize(QSize(0, 32));
    ui->listWidgetVideos->setSpacing(2);

    connect(ui->btnAdd, &QPushButton::clicked,
            this, &ControlWindow::onAddMedia);
    connect(ui->btnPlay, &QPushButton::clicked,
            this, &ControlWindow::onPlaySelected);
    connect(ui->btnStop, &QPushButton::clicked,
            this, &ControlWindow::onStop);
    connect(ui->btnBlackout, &QPushButton::clicked, this, &ControlWindow::onBlackoutClicked);

    connect(m_playbackController, &PlaybackController::mediaFinished,
            this, &ControlWindow::onMediaFinished);

    // slideshow buttons
    connect(ui->btnSlideshowStart, &QPushButton::clicked,
            this, &ControlWindow::onStartSlideshow);
    connect(ui->btnSlideshowStop, &QPushButton::clicked,
            this, &ControlWindow::onStopSlideshow);

    refreshLists();
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
    refreshLists();
}

void ControlWindow::refreshImageList()
{
    ui->listWidgetImages->clear();
    const auto &items = m_mediaManager->items();
    for (const auto &item : items)
    {
        if (item.type == MediaType::Image)
        {
            QListWidgetItem *listItem = new QListWidgetItem(item.path);
            ui->listWidgetImages->addItem(listItem);
        }
    }
}

void ControlWindow::refreshVideoList()
{
    ui->listWidgetVideos->clear();
    const auto &items = m_mediaManager->items();
    for (const auto &item : items)
    {
        if (item.type == MediaType::Video)
        {
            QListWidgetItem *listItem = new QListWidgetItem(item.path);
            ui->listWidgetVideos->addItem(listItem);
        }
    }
}

void ControlWindow::refreshLists()
{
    refreshImageList();
    refreshVideoList();
}

void ControlWindow::onPlaySelected()
{
    // Stop slideshow if running (manual override)
    if (m_slideshow.isRunning())
        m_slideshow.stop();

    int row = ui->listWidgetVideos->currentRow();
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

void ControlWindow::onStartSlideshow()
{
    int seconds = ui->spinSlideshowSeconds->value();
    if (seconds < 1)
        seconds = 1;

    // stop any video
    m_playbackController->stop();

    m_slideshow.start(seconds * 1000);
    ui->statusLabel->setText(
        tr("Slideshow started (%1 s per image)").arg(seconds));
}

void ControlWindow::onStopSlideshow()
{
    m_slideshow.stop();
    ui->statusLabel->setText(tr("Slideshow stopped"));
}

void ControlWindow::onBlackoutClicked()
{
    static bool isBlack = false;
    static bool wasVideoPlaying = false;
    static bool wasSlideshowRunning = false;
    isBlack = !isBlack;

    if (isBlack)
    {
        // Pause video if playing
        wasVideoPlaying = m_playbackController->isPlaying();
        if (wasVideoPlaying)
            m_playbackController->pause();
        // Pause slideshow if running
        wasSlideshowRunning = m_slideshow.isRunning();
        if (wasSlideshowRunning)
            m_slideshow.stop();
    }
    else
    {
        // Resume video if it was playing
        if (wasVideoPlaying)
            m_playbackController->play();
        // Resume slideshow if it was running
        if (wasSlideshowRunning)
            m_slideshow.start(ui->spinSlideshowSeconds->value() * 1000);
    }
    m_outputWindow->setBlackout(isBlack);
    ui->btnBlackout->setText(isBlack ? "Unblackout" : "Blackout");
}

void ControlWindow::closeEvent(QCloseEvent *event)
{
    if (m_outputWindow)
    {
        m_outputWindow->close();
    }
    QMainWindow::closeEvent(event);
}