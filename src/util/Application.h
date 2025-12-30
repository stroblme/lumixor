#pragma once
#include <QApplication>
#include <QString>

#include "AppConfig.h"

class Application : public QApplication
{
    Q_OBJECT
public:
    Application(int &argc, char **argv);

    void applyDarkTheme();

    const AppConfig &config() const { return m_config; }
    AppConfig &mutableConfig() { return m_config; }

    // path of the config file actually used (may be empty)
    QString configPath() const { return m_configPath; }

private:
    void loadConfigFromCommandLine();

    AppConfig m_config;
    QString m_configPath;
};