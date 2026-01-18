#pragma once

#include <QString>

struct AppConfig
{
    int slideshowIntervalSeconds = 5; // delay between images
    int transitionDurationMs = 200;   // fade animation duration

    int controlWidth = 640;
    int controlHeight = 480;

    int outputWidth = 800;
    int outputHeight = 600;

    int outputScreenIndex = 1; // second screen by default

    // UI customization
    QString accentColor = "#78909C"; // accent color for UI elements

    // Playback settings
    bool autoPlayNextVideo = true; // automatically play next video when current finishes

    static AppConfig loadFromFile(const QString &filePath, bool *ok = nullptr);
    bool saveToFile(const QString &filePath, QString *error = nullptr) const;
};
