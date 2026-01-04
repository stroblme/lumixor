// src/main.cpp
#include "util/Application.h"
#include "core/MediaManager.h"
#include "core/PlaybackController.h"
#include "core/SlideshowController.h"
#include "ui/OutputWindow.h"
#include "ui/ControlBridge.h"
#include "ui/ExifImageProvider.h"
#include "ui/PreferencesController.h"

#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QScreen>
#include <QWindow>

int main(int argc, char *argv[])
{
    QGuiApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
    QGuiApplication::setAttribute(Qt::AA_UseHighDpiPixmaps);

    Application app(argc, argv);
    app.setWindowIcon(QIcon(":/lumixor.svg"));
    app.applyDarkTheme();

    const AppConfig &cfg = app.config();

    MediaManager mediaManager;
    PlaybackController playbackController;

    OutputWindow outputWindow(&playbackController);
    SlideshowController slideshow(&mediaManager, &outputWindow);

    ControlBridge controlBridge;
    PreferencesController preferences(&app);

    QQmlApplicationEngine engine;
    engine.addImageProvider("exif", new ExifImageProvider());

    engine.rootContext()->setContextProperty("mediaManager", &mediaManager);
    engine.rootContext()->setContextProperty("playbackController", &playbackController);
    engine.rootContext()->setContextProperty("slideshow", &slideshow);
    engine.rootContext()->setContextProperty("controlBridge", &controlBridge);
    engine.rootContext()->setContextProperty("outputWindow", &outputWindow);
    engine.rootContext()->setContextProperty("preferences", &preferences);

    // Debug: print the loaded values
    qDebug() << "Startup - accentColor from preferences:" << preferences.accentColor();

    engine.load(QUrl(QStringLiteral("qrc:/qml/OutputWindow.qml")));
    engine.load(QUrl(QStringLiteral("qrc:/qml/ControlWindow.qml")));

    const auto screens = app.screens();
    const int targetScreen = cfg.outputScreenIndex;
    const bool singleScreen = screens.size() <= 1;

    QWindow *controlWindow = nullptr;
    QWindow *outWindow = nullptr;

    const auto roots = engine.rootObjects();
    for (QObject *root : roots)
    {
        if (root->objectName() == "controlRoot")
        {
            QWindow *w = qobject_cast<QWindow *>(root);
            if (w)
            {
                controlWindow = w;
                // Position on primary screen but let it start maximized
                if (!screens.isEmpty())
                {
                    QRect primaryGeo = screens[0]->geometry();
                    w->setScreen(screens[0]);
                    w->setX(primaryGeo.x());
                    w->setY(primaryGeo.y());
                }
                w->showMaximized();
            }
        }
        else if (root->objectName() == "outputRoot")
        {
            outputWindow.setRootObject(root);
            QWindow *w = qobject_cast<QWindow *>(root);
            if (w)
            {
                outWindow = w;
                w->resize(cfg.outputWidth, cfg.outputHeight);
            }
            outputWindow.fullscreenOnScreen(targetScreen);
        }
    }

    // On single screen, ensure control window is above output window
    if (singleScreen && controlWindow && outWindow)
    {
        controlWindow->raise();
        controlWindow->requestActivate();
    }

    return app.exec();
}