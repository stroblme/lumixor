#include "Application.h"
#include <QPalette>
#include <QFile>
#include <QTextStream>

Application::Application(int &argc, char **argv)
    : QApplication(argc, argv)
{
}

void Application::applyDarkTheme()
{
    // Not used now; keep if you want both themes later
}

void Application::applyIOSLightTheme()
{
    // Light palette
    QPalette pal;

    pal.setColor(QPalette::Window, QColor("#F2F2F7")); // iOS system grouped background
    pal.setColor(QPalette::WindowText, QColor("#000000"));
    pal.setColor(QPalette::Base, QColor("#FFFFFF"));
    pal.setColor(QPalette::AlternateBase, QColor("#F2F2F7"));
    pal.setColor(QPalette::ToolTipBase, QColor("#FFFFFF"));
    pal.setColor(QPalette::ToolTipText, QColor("#000000"));
    pal.setColor(QPalette::Text, QColor("#000000"));
    pal.setColor(QPalette::Button, QColor("#FFFFFF"));
    pal.setColor(QPalette::ButtonText, QColor("#007AFF")); // iOS blue
    pal.setColor(QPalette::BrightText, QColor("#FF3B30")); // iOS red
    pal.setColor(QPalette::Highlight, QColor("#007AFF"));
    pal.setColor(QPalette::HighlightedText, QColor("#FFFFFF"));

    setPalette(pal);

    setStyle("Fusion");

    QFile f("src/ui/style/ios_light.qss");
    if (f.open(QIODevice::ReadOnly | QIODevice::Text))
    {
        QTextStream in(&f);
        const QString qss = in.readAll();
        setStyleSheet(qss);
    }
}