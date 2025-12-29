#pragma once
#include <QApplication>

class Application : public QApplication
{
public:
    Application(int &argc, char **argv);

    void applyDarkTheme();     // keep if you want
    void applyIOSLightTheme(); // new
};