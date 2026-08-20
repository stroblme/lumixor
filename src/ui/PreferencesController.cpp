#include "PreferencesController.h"

#include "../util/Application.h"
#include <QDebug>

PreferencesController::PreferencesController(Application *app, QObject *parent)
    : QObject(parent),
      m_app(app)
{
    // Every setter used to rewrite the whole config file, so dragging a colour picker
    // produced one synchronous write per frame. Coalesce them instead.
    m_saveTimer.setSingleShot(true);
    m_saveTimer.setInterval(500);
    connect(&m_saveTimer, &QTimer::timeout, this, [this]
            {
        if (m_app)
            m_app->saveConfig(); });
}

PreferencesController::~PreferencesController()
{
    flushPendingSave();
}

int PreferencesController::slideshowIntervalSeconds() const
{
    return m_app ? m_app->config().slideshowIntervalSeconds : AppConfig().slideshowIntervalSeconds;
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
    return m_app ? m_app->config().transitionDurationMs : AppConfig().transitionDurationMs;
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
    return m_app ? m_app->config().outputScreenIndex : AppConfig().outputScreenIndex;
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
    return m_app ? m_app->config().accentColor : AppConfig().accentColor;
}

bool PreferencesController::autoPlayNextVideo() const
{
    return m_app ? m_app->config().autoPlayNextVideo : AppConfig().autoPlayNextVideo;
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

bool PreferencesController::loopSlideshows() const
{
    return m_app ? m_app->config().loopSlideshows : AppConfig().loopSlideshows;
}

void PreferencesController::setLoopSlideshows(bool value)
{
    if (!m_app)
        return;
    AppConfig &cfg = m_app->mutableConfig();
    if (cfg.loopSlideshows == value)
        return;
    cfg.loopSlideshows = value;
    emit preferencesChanged();
    autoSave();
}

bool PreferencesController::loopVideos() const
{
    return m_app ? m_app->config().loopVideos : AppConfig().loopVideos;
}

void PreferencesController::setLoopVideos(bool value)
{
    if (!m_app)
        return;
    AppConfig &cfg = m_app->mutableConfig();
    if (cfg.loopVideos == value)
        return;
    cfg.loopVideos = value;
    emit preferencesChanged();
    autoSave();
}

void PreferencesController::autoSave()
{
    m_saveTimer.start();
}

void PreferencesController::flushPendingSave()
{
    if (!m_saveTimer.isActive())
        return;
    m_saveTimer.stop();
    if (m_app)
        m_app->saveConfig();
}

bool PreferencesController::save(QString path)
{
    if (!m_app)
        return false;

    m_saveTimer.stop();
    if (path.isEmpty())
        return m_app->saveConfig();

    // Save-as: subsequent autosaves must follow the file the user just chose,
    // otherwise they silently keep writing to the previous one.
    return m_app->saveConfigAs(path);
}
