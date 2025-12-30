#include "ControlBridge.h"
#include <QFileDialog>

ControlBridge::ControlBridge(QObject *parent)
    : QObject(parent)
{
}

QStringList ControlBridge::openFileDialog(const QString &caption)
{
    return QFileDialog::getOpenFileNames(nullptr, caption, QString(),
                                         "Media Files (*.jpg *.jpeg *.png *.bmp *.mp4 *.mov *.mkv *.avi);;Images (*.jpg *.jpeg *.png *.bmp);;Videos (*.mp4 *.mov *.mkv *.avi);;All Files (*)",
                                         nullptr, QFileDialog::DontUseCustomDirectoryIcons);
}

QString ControlBridge::openFolderDialog(const QString &caption)
{
    return QFileDialog::getExistingDirectory(nullptr, caption, QString(),
                                             QFileDialog::ShowDirsOnly | QFileDialog::DontUseCustomDirectoryIcons);
}
