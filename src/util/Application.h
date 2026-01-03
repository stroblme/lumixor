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

    // path of the config file actually used
    QString configPath() const { return m_configPath; }

    // Save config to file (auto-called or manual)
    bool saveConfig();

    // Get the default config directory path
    static QString defaultConfigDir();
    static QString defaultConfigPath();

private:
    void loadConfigFromCommandLine();
    void loadDefaultConfig();

    AppConfig m_config;
    QString m_configPath;
};