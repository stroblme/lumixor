#include "PreferencesController.h"

#include "../util/Application.h"
#include <QDebug>

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
    if (cfg.slideshowIntervalSeconds == value)
        return;
    cfg.slideshowIntervalSeconds = value;
    emit preferencesChanged();
    autoSave();
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
    if (cfg.transitionDurationMs == value)
        return;
    cfg.transitionDurationMs = value;
    emit preferencesChanged();
    autoSave();
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
    if (cfg.outputScreenIndex == value)
        return;
    cfg.outputScreenIndex = value;
    emit preferencesChanged();
    autoSave();
}

QString PreferencesController::accentColor() const
{
    return m_app ? m_app->config().accentColor : "#78909C";
}

bool PreferencesController::autoPlayNextVideo() const
{
    return m_app ? m_app->config().autoPlayNextVideo : true;
}

void PreferencesController::setAccentColor(const QString &value)
{
    if (!m_app)
        return;
    AppConfig &cfg = m_app->mutableConfig();
    if (cfg.accentColor == value)
        return;
    cfg.accentColor = value;
    emit preferencesChanged();
    autoSave();
}

void PreferencesController::setAutoPlayNextVideo(bool value)
{
    if (!m_app)
        return;
    AppConfig &cfg = m_app->mutableConfig();
    if (cfg.autoPlayNextVideo == value)
        return;
    cfg.autoPlayNextVideo = value;
    emit preferencesChanged();
    autoSave();
}

void PreferencesController::autoSave()
{
    if (m_app)
    {
        m_app->saveConfig();
    }
}

bool PreferencesController::save(QString path)
{
    if (!m_app)
        return false;
    if (path.isEmpty())
        return m_app->saveConfig();

    QString error;
    const AppConfig &cfg = m_app->config();
    return cfg.saveToFile(path, &error);
}
