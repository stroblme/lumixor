// src/main.cpp
#include "util/Application.h"
#include "core/MediaManager.h"
#include "core/PlaybackController.h"
#include "core/SlideshowController.h"
#include "ui/OutputWindow.h"
#include "ui/ControlBridge.h"
#include "ui/ExifImageProvider.h"

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

    MediaManager mediaManager;
    PlaybackController playbackController;

    // OutputWindow is a small QObject proxy which will attach to the QML OutputWindow
    OutputWindow outputWindow(&playbackController);

    // SlideshowController still uses the OutputWindow proxy
    SlideshowController slideshow(&mediaManager, &outputWindow);

    ControlBridge controlBridge;

    QQmlApplicationEngine engine;

    // Register image provider for EXIF-corrected images
    engine.addImageProvider("exif", new ExifImageProvider());

    engine.rootContext()->setContextProperty("mediaManager", &mediaManager);
    engine.rootContext()->setContextProperty("playbackController", &playbackController);
    engine.rootContext()->setContextProperty("slideshow", &slideshow);
    engine.rootContext()->setContextProperty("controlBridge", &controlBridge);
    engine.rootContext()->setContextProperty("outputWindow", &outputWindow);

    engine.load(QUrl(QStringLiteral("qrc:/qml/OutputWindow.qml")));
    engine.load(QUrl(QStringLiteral("qrc:/qml/ControlWindow.qml")));

    const auto screens = app.screens();
    if (screens.size() > 1)
    {
        // Place control window on the primary screen and the output on the second screen (full screen)
        const auto roots = engine.rootObjects();
        for (QObject *root : roots)
        {
            if (root->objectName() == "controlRoot")
            {
                QWindow *w = qobject_cast<QWindow *>(root);
                if (w)
                {
                    QRect primaryGeo = screens[0]->geometry();
                    w->setX(primaryGeo.x());
                    w->setY(primaryGeo.y());
                    w->show();
                }
            }
            else if (root->objectName() == "outputRoot")
            {
                outputWindow.setRootObject(root);
                outputWindow.fullscreenOnScreen(1);
            }
        }
    }
    else
    {
        const auto roots = engine.rootObjects();
        for (QObject *root : roots)
        {
            if (root->objectName() == "controlRoot")
            {
                QWindow *w = qobject_cast<QWindow *>(root);
                if (w)
                    w->show();
            }
            else if (root->objectName() == "outputRoot")
            {
                outputWindow.setRootObject(root);
                QWindow *w = qobject_cast<QWindow *>(root);
                if (w)
                    w->show();
            }
        }
    }

    return app.exec();
}