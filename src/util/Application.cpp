// src/util/Application.cpp
#include "Application.h"
#include <QPalette>
#include <QFile>
#include <QTextStream>
#include <QCommandLineParser>
#include <QStandardPaths>
#include <QDir>
#include <QDebug>

Application::Application(int &argc, char **argv)
    : QApplication(argc, argv)
{
    loadConfigFromCommandLine();
}

QString Application::defaultConfigDir()
{
    // Use XDG config directory on Linux, AppData on Windows, etc.
    QString configDir = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation);
    return configDir + "/lumixor";
}

QString Application::defaultConfigPath()
{
    return defaultConfigDir() + "/config.json";
}

void Application::loadDefaultConfig()
{
    QString defaultPath = defaultConfigPath();

    // Ensure the config directory exists
    QDir dir(defaultConfigDir());
    if (!dir.exists())
    {
        dir.mkpath(".");
    }

    bool ok = false;
    if (QFile::exists(defaultPath))
    {
        m_config = AppConfig::loadFromFile(defaultPath, &ok);
        if (ok)
        {
            m_configPath = defaultPath;
            qDebug() << "Loaded config from:" << defaultPath;
            return;
        }
    }

    // No config file exists yet, use defaults and set path for future saves
    m_config = AppConfig();
    m_configPath = defaultPath;
    qDebug() << "Using default config, will save to:" << defaultPath;
}

void Application::loadConfigFromCommandLine()
{
    QCommandLineParser parser;
    parser.setApplicationDescription("Lumixor Qt presenter");
    parser.addHelpOption();

    QCommandLineOption configOpt(QStringList() << "c" << "config",
                                 "Path to workspace configuration JSON file.",
                                 "file");
    parser.addOption(configOpt);

    parser.process(*this);

    if (parser.isSet(configOpt))
    {
        // Use explicitly provided config file
        m_configPath = parser.value(configOpt);
        bool ok = false;
        m_config = AppConfig::loadFromFile(m_configPath, &ok);
        if (!ok)
        {
            qWarning() << "Failed to load config from:" << m_configPath;
            m_config = AppConfig();
        }
    }
    else
    {
        // Use default config location
        loadDefaultConfig();
    }
}

bool Application::saveConfig()
{
    if (m_configPath.isEmpty())
    {
        m_configPath = defaultConfigPath();
    }

    // Ensure directory exists
    QDir dir(QFileInfo(m_configPath).absolutePath());
    if (!dir.exists())
    {
        dir.mkpath(".");
    }

    QString error;
    bool ok = m_config.saveToFile(m_configPath, &error);
    if (!ok)
    {
        qWarning() << "Failed to save config:" << error;
    }
    else
    {
        qDebug() << "Config saved to:" << m_configPath;
    }
    return ok;
}

void Application::applyDarkTheme()
{
    QPalette darkPalette;

    QColor windowColor(0x12, 0x12, 0x12);
    QColor baseColor(0x1E, 0x1E, 0x1E);
    QColor textColor(0xE0, 0xE0, 0xE0);
    QColor disabledText(0x60, 0x60, 0x60);
    QColor accentColor(0x42, 0xA5, 0xF5); // blue

    darkPalette.setColor(QPalette::Window, windowColor);
    darkPalette.setColor(QPalette::WindowText, textColor);
    darkPalette.setColor(QPalette::Base, baseColor);
    darkPalette.setColor(QPalette::AlternateBase, QColor(0x25, 0x25, 0x25));
    darkPalette.setColor(QPalette::ToolTipBase, baseColor);
    darkPalette.setColor(QPalette::ToolTipText, textColor);
    darkPalette.setColor(QPalette::Text, textColor);
    darkPalette.setColor(QPalette::Button, baseColor);
    darkPalette.setColor(QPalette::ButtonText, textColor);
    darkPalette.setColor(QPalette::BrightText, Qt::red);
    darkPalette.setColor(QPalette::Highlight, accentColor);
    darkPalette.setColor(QPalette::HighlightedText, QColor(0x12, 0x12, 0x12));

    darkPalette.setColor(QPalette::Disabled, QPalette::Text, disabledText);
    darkPalette.setColor(QPalette::Disabled, QPalette::ButtonText, disabledText);
    darkPalette.setColor(QPalette::Disabled, QPalette::WindowText, disabledText);

    setStyle("Fusion");
    setPalette(darkPalette);

    // Load dark QSS
    QFile f("src/ui/style/dark_theme.qss");
    if (f.open(QIODevice::ReadOnly | QIODevice::Text))
    {
        QTextStream in(&f);
        setStyleSheet(in.readAll());
    }
}