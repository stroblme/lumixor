// src/main.cpp
#include "util/Application.h"
#include "core/MediaManager.h"
#include "core/PlaybackController.h"
#include "core/SlideshowController.h"
#include "ui/OutputWindow.h"
#include "ui/ControlWindow.h"

#include <QScreen>

int main(int argc, char *argv[])
{
    QGuiApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
    QGuiApplication::setAttribute(Qt::AA_UseHighDpiPixmaps);

    Application app(argc, argv);
    app.applyDarkTheme();

    MediaManager mediaManager;
    PlaybackController playbackController;

    OutputWindow outputWindow(&playbackController);
    ControlWindow controlWindow(&mediaManager, &playbackController, &outputWindow);

    const auto screens = app.screens();
    if (screens.size() > 1)
    {
        QRect primaryGeo = screens[0]->geometry();
        controlWindow.move(primaryGeo.topLeft());
        controlWindow.show();

        outputWindow.fullscreenOnScreen(1);
    }
    else
    {
        controlWindow.show();
        outputWindow.show();
    }

    return app.exec();
}