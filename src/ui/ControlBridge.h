#pragma once
#include <QObject>
#include <QStringList>

class ControlBridge : public QObject
{
    Q_OBJECT
public:
    explicit ControlBridge(QObject *parent = nullptr);

    Q_INVOKABLE QStringList openFileDialog(const QString &caption = "Select media");
};
