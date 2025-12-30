#include "PreferencesController.h"

#include "../util/Application.h"

PreferencesController::PreferencesController(Application *app, QObject *parent)
    : QObject(parent),
      m_app(app)
{
}

int PreferencesController::slideshowIntervalSeconds() const
{
    return m_app ? m_app->config().slideshowIntervalSeconds : 5;
}

void PreferencesController::setSlideshowIntervalSeconds(int value)
{
    if (!m_app)
        return;
    AppConfig &cfg = m_app->mutableConfig();
    cfg.slideshowIntervalSeconds = value;
    emit preferencesChanged();
}

int PreferencesController::transitionDurationMs() const
{
    return m_app ? m_app->config().transitionDurationMs : 200;
}

void PreferencesController::setTransitionDurationMs(int value)
{
    if (!m_app)
        return;
    AppConfig &cfg = m_app->mutableConfig();
    cfg.transitionDurationMs = value;
    emit preferencesChanged();
}

int PreferencesController::outputScreenIndex() const
{
    return m_app ? m_app->config().outputScreenIndex : 1;
}

void PreferencesController::setOutputScreenIndex(int value)
{
    if (!m_app)
        return;
    AppConfig &cfg = m_app->mutableConfig();
    cfg.outputScreenIndex = value;
    emit preferencesChanged();
}

bool PreferencesController::save(QString path)
{
    if (!m_app)
        return false;
    if (path.isEmpty())
        path = m_app->configPath();
    if (path.isEmpty())
        return false;

    QString error;
    const AppConfig &cfg = m_app->config();
    return cfg.saveToFile(path, &error);
}
