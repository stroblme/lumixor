// src/main.cpp
#include "util/Application.h"
#include "core/MediaManager.h"
#include "core/PlaybackController.h"
#include "core/SlideshowController.h"
#include "ui/OutputBridge.h"
#include "ui/ControlBridge.h"
#include "ui/ExifImageProvider.h"
#include "ui/PreferencesController.h"
#include "ui/ScreenManager.h"
#include "audio/AudioAnalyzer.h"

#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDebug>

int main(int argc, char *argv[])
{
    QGuiApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
    QGuiApplication::setAttribute(Qt::AA_UseHighDpiPixmaps);

    Application app(argc, argv);
    app.setWindowIcon(QIcon(":/lumixor.svg"));
    app.applyDarkTheme();

    MediaManager mediaManager;
    PlaybackController playbackController;

    OutputBridge outputBridge;
    SlideshowController slideshow(&mediaManager);

    ControlBridge controlBridge;
    PreferencesController preferences(&app);
    AudioAnalyzer audioAnalyzer;

    QQmlApplicationEngine engine;
    engine.addImageProvider("exif", new ExifImageProvider());

    engine.rootContext()->setContextProperty("mediaManager", &mediaManager);
    engine.rootContext()->setContextProperty("playbackController", &playbackController);
    engine.rootContext()->setContextProperty("slideshow", &slideshow);
    engine.rootContext()->setContextProperty("controlBridge", &controlBridge);
    engine.rootContext()->setContextProperty("outputWindow", &outputBridge); // QML name kept: used across every panel
    engine.rootContext()->setContextProperty("preferences", &preferences);
    engine.rootContext()->setContextProperty("audioAnalyzer", &audioAnalyzer);

    // Attach the output root as soon as it is created, i.e. before ControlWindow.qml
    // is loaded. Attaching after both loads would let the control window's
    // Component.onCompleted run while OutputBridge still has no root, and every call
    // it makes would be silently dropped by the null-root guards.
    bool qmlLoadFailed = false;
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [&outputBridge, &qmlLoadFailed](QObject *obj, const QUrl &url)
                     {
        if (!obj)
        {
            qCritical() << "Failed to load QML:" << url;
            qmlLoadFailed = true;
            return;
        }
        if (obj->objectName() == "outputRoot")
            outputBridge.setRootObject(obj); });

    engine.load(QUrl(QStringLiteral("qrc:/qml/OutputWindow.qml")));
    engine.load(QUrl(QStringLiteral("qrc:/qml/ControlWindow.qml")));

    if (qmlLoadFailed || engine.rootObjects().size() != 2)
    {
        qCritical() << "QML failed to load; aborting startup.";
        return 1;
    }

    ScreenManager screens(&app, &outputBridge);
    screens.placeWindows(engine);

    return app.exec();
}