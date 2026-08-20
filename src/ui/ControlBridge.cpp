#include "ControlBridge.h"
#include "../core/MediaTypes.h"
#include <QFileDialog>

ControlBridge::ControlBridge(QObject *parent)
    : QObject(parent)
{
}

QStringList ControlBridge::openFileDialog(const QString &caption)
{
    return QFileDialog::getOpenFileNames(nullptr, caption, QString(), MediaTypes::dialogFilter());
}

QString ControlBridge::openFolderDialog(const QString &caption)
{
    return QFileDialog::getExistingDirectory(nullptr, caption, QString(),
                                             QFileDialog::ShowDirsOnly);
}
