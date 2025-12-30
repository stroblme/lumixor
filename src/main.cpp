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

    engine.load(QUrl(QStringLiteral("qrc:/qml/OutputWindow.qml")));
    engine.load(QUrl(QStringLiteral("qrc:/qml/ControlWindow.qml")));

    const auto screens = app.screens();
    const int targetScreen = cfg.outputScreenIndex;

    const auto roots = engine.rootObjects();
    for (QObject *root : roots)
    {
        if (root->objectName() == "controlRoot")
        {
            QWindow *w = qobject_cast<QWindow *>(root);
            if (w)
            {
                w->setWidth(cfg.controlWidth);
                w->setHeight(cfg.controlHeight);

                if (!screens.isEmpty())
                {
                    QRect primaryGeo = screens[0]->geometry();
                    w->setX(primaryGeo.x());
                    w->setY(primaryGeo.y());
                }
                w->show();
            }
        }
        else if (root->objectName() == "outputRoot")
        {
            outputWindow.setRootObject(root);
            QWindow *w = qobject_cast<QWindow *>(root);
            if (w)
            {
                w->resize(cfg.outputWidth, cfg.outputHeight);
            }
            outputWindow.fullscreenOnScreen(targetScreen);
        }
    }

    return app.exec();
}