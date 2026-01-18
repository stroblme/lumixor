#pragma once

#include <QObject>

#include "../util/AppConfig.h"

class Application;

class PreferencesController : public QObject
{
    Q_OBJECT

    Q_PROPERTY(int slideshowIntervalSeconds READ slideshowIntervalSeconds WRITE setSlideshowIntervalSeconds NOTIFY preferencesChanged)
    Q_PROPERTY(int transitionDurationMs READ transitionDurationMs WRITE setTransitionDurationMs NOTIFY preferencesChanged)
    Q_PROPERTY(int outputScreenIndex READ outputScreenIndex WRITE setOutputScreenIndex NOTIFY preferencesChanged)
    Q_PROPERTY(QString accentColor READ accentColor WRITE setAccentColor NOTIFY preferencesChanged)
    Q_PROPERTY(bool autoPlayNextVideo READ autoPlayNextVideo WRITE setAutoPlayNextVideo NOTIFY preferencesChanged)

public:
    explicit PreferencesController(Application *app, QObject *parent = nullptr);

    // Getters
    int slideshowIntervalSeconds() const;
    int transitionDurationMs() const;
    int outputScreenIndex() const;
    QString accentColor() const;
    bool autoPlayNextVideo() const;

    // Setters
    void setSlideshowIntervalSeconds(int value);
    void setTransitionDurationMs(int value);
    void setOutputScreenIndex(int value);
    void setAccentColor(const QString &color);
    void setAutoPlayNextVideo(bool value);

    Q_INVOKABLE bool save(QString path = QString());

signals:
    void preferencesChanged();

private:
    void autoSave();

    Application *m_app;
};
