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
    return m_app ? m_app->config().accentColor : "#42A5F5";
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

double PreferencesController::uiScale() const
{
    return m_app ? m_app->config().uiScale : 1.0;
}

void PreferencesController::setUiScale(double value)
{
    if (!m_app)
        return;
    // Clamp value between 0.5 and 2.0
    value = qBound(0.5, value, 2.0);
    AppConfig &cfg = m_app->mutableConfig();
    if (qFuzzyCompare(cfg.uiScale, value))
        return;
    cfg.uiScale = value;
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
