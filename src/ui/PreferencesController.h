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
    Q_PROPERTY(double uiScale READ uiScale WRITE setUiScale NOTIFY preferencesChanged)

public:
    explicit PreferencesController(Application *app, QObject *parent = nullptr);

    int slideshowIntervalSeconds() const;
    void setSlideshowIntervalSeconds(int value);

    int transitionDurationMs() const;
    void setTransitionDurationMs(int value);

    int outputScreenIndex() const;
    void setOutputScreenIndex(int value);

    QString accentColor() const;
    void setAccentColor(const QString &value);

    double uiScale() const;
    void setUiScale(double value);

    Q_INVOKABLE bool save(QString path = QString());

signals:
    void preferencesChanged();

private:
    void autoSave();

    Application *m_app;
};
