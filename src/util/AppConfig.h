#pragma once

#include <QString>

struct AppConfig
{
    int slideshowIntervalSeconds = 5; // delay between images
    int transitionDurationMs = 200;   // fade animation duration

    int outputWidth = 800;
    int outputHeight = 600;

    int outputScreenIndex = 1; // second screen by default

    // UI customization
    QString accentColor = "#78909C"; // accent color for UI elements

    // Playback settings
    bool autoPlayNextVideo = true; // automatically play next video when current finishes
    bool loopSlideshows = true;    // restart a slideshow after the last image
    bool loopVideos = true;        // restart a video playlist after the last clip

    static AppConfig loadFromFile(const QString &filePath, bool *ok = nullptr);
    bool saveToFile(const QString &filePath, QString *error = nullptr) const;
};
