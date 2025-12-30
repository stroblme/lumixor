// src/ui/ControlWindow.cpp
#include "ControlWindow.h"
#include "forms/ui_ControlWindow.h"

#include <QCloseEvent>
#include <QFileDialog>
#include <QFileInfo>
#include <QListWidget>
#include <QCoreApplication>

#include "../util/Application.h"

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
    connect(ui->btnBlackout, &QPushButton::clicked, this, &ControlWindow::onBlackoutClicked);
    connect(m_playbackController, &PlaybackController::mediaFinished,
            this, &ControlWindow::onMediaFinished);

    // New toggle buttons
    connect(ui->btnPlayToggle, &QPushButton::toggled,
            this, &ControlWindow::onPlayToggle);
    connect(ui->btnSlideshowToggle, &QPushButton::toggled,
            this, &ControlWindow::onSlideshowToggle);

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

// Add member variable to track loaded video index
int m_loadedVideoIndex = -1;

void ControlWindow::onPlayToggle(bool checked)
{
    if (checked)
    {
        int row = ui->listWidgetVideos->currentRow();
        if (row < 0)
        {
            ui->btnPlayToggle->setChecked(false);
            return;
        }
        // Only load media if a new video is selected
        if (row != m_loadedVideoIndex)
        {
            const auto &items = m_mediaManager->items();
            int videoIdx = 0;
            for (const auto &item : items)
            {
                if (item.type == MediaType::Video)
                {
                    if (videoIdx == row)
                    {
                        m_playbackController->loadMedia(item);
                        m_outputWindow->showVideo();
                        m_loadedVideoIndex = row;
                        ui->statusLabel->setText("Playing video: " + item.path);
                        break;
                    }
                    videoIdx++;
                }
            }
        }
        m_playbackController->play();
        ui->btnPlayToggle->setText("Pause");
    }
    else
    {
        m_playbackController->pause();
        ui->statusLabel->setText("Video paused");
        ui->btnPlayToggle->setText("Resume");
    }
}

void ControlWindow::onSlideshowToggle(bool checked)
{
    Application *app = qobject_cast<Application *>(QCoreApplication::instance());
    int seconds = app ? app->config().slideshowIntervalSeconds : 5;

    if (checked)
    {
        // Only pause video if not already paused
        if (m_playbackController->isPlaying())
            m_playbackController->pause();
        m_slideshow.start(seconds * 1000);
        ui->statusLabel->setText(tr("Slideshow started (%1 s per image)").arg(seconds));
        ui->btnSlideshowToggle->setText("Pause Slideshow");
    }
    else
    {
        m_slideshow.pause();
        ui->statusLabel->setText(tr("Slideshow paused"));
        ui->btnSlideshowToggle->setText("Resume Slideshow");
    }
}

void ControlWindow::onMediaFinished()
{
    ui->statusLabel->setText("Media finished");
    ui->btnPlayToggle->setChecked(false);
    ui->btnPlayToggle->setText("Play");
    m_loadedVideoIndex = -1;
}

void ControlWindow::onBlackoutClicked()
{
    Application *app = qobject_cast<Application *>(QCoreApplication::instance());
    int seconds = app ? app->config().slideshowIntervalSeconds : 5;

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
            m_slideshow.start(seconds * 1000);
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