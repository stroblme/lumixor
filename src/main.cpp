// src/main.cpp
#include "util/Application.h"
#include "core/MediaManager.h"
#include "core/PlaybackController.h"
#include "core/SlideshowController.h"
#include "ui/OutputWindow.h"
#include "ui/ControlBridge.h"
#include "ui/ExifImageProvider.h"
#include "ui/PreferencesController.h"
#include "audio/AudioAnalyzer.h"

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
    AudioAnalyzer audioAnalyzer;

    QQmlApplicationEngine engine;
    engine.addImageProvider("exif", new ExifImageProvider());

    engine.rootContext()->setContextProperty("mediaManager", &mediaManager);
    engine.rootContext()->setContextProperty("playbackController", &playbackController);
    engine.rootContext()->setContextProperty("slideshow", &slideshow);
    engine.rootContext()->setContextProperty("controlBridge", &controlBridge);
    engine.rootContext()->setContextProperty("outputWindow", &outputWindow);
    engine.rootContext()->setContextProperty("preferences", &preferences);
    engine.rootContext()->setContextProperty("audioAnalyzer", &audioAnalyzer);

    // Debug: print the loaded values
    qDebug() << "Startup - accentColor from preferences:" << preferences.accentColor();

    engine.load(QUrl(QStringLiteral("qrc:/qml/OutputWindow.qml")));
    engine.load(QUrl(QStringLiteral("qrc:/qml/ControlWindow.qml")));

    const auto screens = app.screens();
    // The control window lives on the primary screen (index 0). Only auto-fullscreen
    // the output when it has a *different* screen to live on; otherwise a fullscreen
    // output covers the controls with no reliable way back (raise() is a no-op on
    // Wayland). In the same-screen / single-screen case we keep it windowed and the
    // user presses F on the output window to fullscreen it where they want.
    int targetScreen = cfg.outputScreenIndex;
    if (targetScreen < 0 || targetScreen >= screens.size())
        targetScreen = screens.size() > 1 ? 1 : 0;
    const bool outputOnOwnScreen = screens.size() > 1 && targetScreen != 0;

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
            if (outputOnOwnScreen)
            {
                outputWindow.fullscreenOnScreen(targetScreen); // dedicated output screen
            }
            else if (w && !screens.isEmpty())
            {
                // Same screen as the controls (or single screen): stay windowed so it
                // never covers the control window. Press F on it to fullscreen.
                w->setScreen(screens[targetScreen]);
            }
        }
    }

    // When the output shares the control window's screen, keep the controls in front
    // (best-effort; some compositors ignore raise()).
    if (controlWindow && outWindow && !outputOnOwnScreen)
    {
        controlWindow->raise();
        controlWindow->requestActivate();
    }

    return app.exec();
}