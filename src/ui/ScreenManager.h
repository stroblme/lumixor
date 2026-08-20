#pragma once

#include <QObject>

class QQmlApplicationEngine;
class OutputBridge;
class Application;

// Owns the multi-monitor policy: which screen the output belongs on, whether it may
// go fullscreen, and where the control window starts. Previously spread across main().
class ScreenManager : public QObject
{
    Q_OBJECT
public:
    ScreenManager(Application *app, OutputBridge *output, QObject *parent = nullptr);

    // Resolve the configured output screen against the screens that actually exist.
    // Never writes back: an index that is out of range today may be valid again once
    // the second display is reconnected.
    int resolveOutputScreen();

    // True when the output has a screen of its own and may take it fullscreen. With a
    // single screen a fullscreen output would cover the controls with no reliable way
    // back, because raise() is a no-op on Wayland.
    bool outputHasOwnScreen();

    // Place both windows according to the resolved policy.
    void placeWindows(QQmlApplicationEngine &engine);

private:
    Application *m_app;
    OutputBridge *m_output;
};
