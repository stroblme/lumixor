// src/util/Application.cpp
#include "Application.h"
#include <QPalette>
#include <QFile>
#include <QTextStream>
#include <QCommandLineParser>

Application::Application(int &argc, char **argv)
    : QApplication(argc, argv)
{
    loadConfigFromCommandLine();
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
        m_configPath = parser.value(configOpt);
    }
    else
    {
        m_configPath.clear();
    }

    bool ok = false;
    m_config = AppConfig::loadFromFile(m_configPath, &ok);
    if (!ok)
    {
        // fall back to defaults
        m_config = AppConfig();
        m_configPath.clear();
    }
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