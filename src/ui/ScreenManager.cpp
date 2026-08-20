#include "ScreenManager.h"

#include "OutputBridge.h"
#include "../util/Application.h"

#include <QQmlApplicationEngine>
#include <QScreen>
#include <QWindow>

ScreenManager::ScreenManager(Application *app, OutputBridge *output, QObject *parent)
    : QObject(parent),
      m_app(app),
      m_output(output)
{
}

int ScreenManager::resolveOutputScreen()
{
    const auto screens = m_app->screens();
    const int configured = m_app->config().outputScreenIndex;

    if (configured >= 0 && configured < screens.size())
        return configured;

    // Fall back for this session only. The configured index is deliberately left
    // alone: starting with the projector unplugged must not erase the user's choice
    // of output screen for the next time it is connected.
    return screens.size() > 1 ? 1 : 0;
}

bool ScreenManager::outputHasOwnScreen()
{
    return m_app->screens().size() > 1 && resolveOutputScreen() != 0;
}

void ScreenManager::placeWindows(QQmlApplicationEngine &engine)
{
    const auto screens = m_app->screens();
    if (screens.isEmpty())
        return;

    const int target = resolveOutputScreen();
    const bool ownScreen = outputHasOwnScreen();

    QWindow *controlWindow = nullptr;

    for (QObject *root : engine.rootObjects())
    {
        QWindow *window = qobject_cast<QWindow *>(root);
        if (!window)
            continue;

        if (root->objectName() == "controlRoot")
        {
            controlWindow = window;
            window->setScreen(screens[0]);
            window->showMaximized();
        }
        else if (root->objectName() == "outputRoot")
        {
            if (ownScreen)
            {
                m_output->fullscreenOnScreen(target);
            }
            else
            {
                // Sharing the control window's screen: stay windowed so the output
                // never covers the controls. Press F on it to go fullscreen.
                window->setScreen(screens[target]);
                window->resize(m_app->config().outputWidth, m_app->config().outputHeight);
            }
        }
    }

    // Best effort; some compositors ignore raise().
    if (controlWindow && !ownScreen)
    {
        controlWindow->raise();
        controlWindow->requestActivate();
    }
}
