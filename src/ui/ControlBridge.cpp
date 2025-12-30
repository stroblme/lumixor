#include "ControlBridge.h"
#include <QFileDialog>

ControlBridge::ControlBridge(QObject *parent)
    : QObject(parent)
{
}

QStringList ControlBridge::openFileDialog(const QString &caption)
{
    return QFileDialog::getOpenFileNames(nullptr, caption);
}
