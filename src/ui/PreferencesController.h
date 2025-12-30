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

public:
    explicit PreferencesController(Application *app, QObject *parent = nullptr);

    int slideshowIntervalSeconds() const;
    void setSlideshowIntervalSeconds(int value);

    int transitionDurationMs() const;
    void setTransitionDurationMs(int value);

    int outputScreenIndex() const;
    void setOutputScreenIndex(int value);

    Q_INVOKABLE bool save(QString path = QString());

signals:
    void preferencesChanged();

private:
    Application *m_app;
};
