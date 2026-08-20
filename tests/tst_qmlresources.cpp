// Guards the QML wiring that has no compile-time check: a .qml file missing from
// qml.qrc is absent at runtime, and one missing from its qmldir cannot be imported
// even though it ships in the binary.
#include <QtTest>
#include <QDir>
#include <QFile>
#include <QRegularExpression>

class TestQmlResources : public QObject
{
    Q_OBJECT

private:
    static QString qmlRoot() { return QStringLiteral(SOURCE_QML_DIR); }
    static QString readAll(const QString &path);
    static QStringList qmlFilesIn(const QString &subdir);

private slots:
    void everyQmlFileIsInTheResourceFile();
    void everyResourceEntryExistsOnDisk();
    void everyComponentAndPanelIsDeclaredInQmldir();
    void everyQmldirEntryExistsOnDisk();
};

QString TestQmlResources::readAll(const QString &path)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return QString();
    return QString::fromUtf8(f.readAll());
}

QStringList TestQmlResources::qmlFilesIn(const QString &subdir)
{
    QDir dir(qmlRoot() + QLatin1Char('/') + subdir);
    return dir.entryList({"*.qml"}, QDir::Files, QDir::Name);
}

static QStringList resourceEntries(const QString &qrc)
{
    QStringList entries;
    QRegularExpression re("<file>(.*?)</file>");
    auto it = re.globalMatch(qrc);
    while (it.hasNext())
        entries << it.next().captured(1);
    return entries;
}

void TestQmlResources::everyQmlFileIsInTheResourceFile()
{
    const QStringList entries = resourceEntries(readAll(qmlRoot() + "/qml.qrc"));
    QVERIFY(!entries.isEmpty());

    QDirIterator it(qmlRoot(), {"*.qml"}, QDir::Files, QDirIterator::Subdirectories);
    while (it.hasNext())
    {
        const QString relative = QDir(qmlRoot()).relativeFilePath(it.next());
        QVERIFY2(entries.contains(relative),
                 qPrintable(QString("%1 is not listed in qml.qrc, so it is absent at runtime").arg(relative)));
    }
}

void TestQmlResources::everyResourceEntryExistsOnDisk()
{
    for (const QString &entry : resourceEntries(readAll(qmlRoot() + "/qml.qrc")))
    {
        QVERIFY2(QFile::exists(qmlRoot() + QLatin1Char('/') + entry),
                 qPrintable(QString("qml.qrc lists %1, which does not exist").arg(entry)));
    }
}

void TestQmlResources::everyComponentAndPanelIsDeclaredInQmldir()
{
    for (const QString &subdir : {QStringLiteral("components"), QStringLiteral("panels")})
    {
        const QString qmldir = readAll(qmlRoot() + "/" + subdir + "/qmldir");
        QVERIFY2(!qmldir.isEmpty(), qPrintable(subdir + "/qmldir is missing or empty"));

        for (const QString &file : qmlFilesIn(subdir))
        {
            QVERIFY2(qmldir.contains(file),
                     qPrintable(QString("%1/%2 is not declared in %1/qmldir, so it cannot be imported")
                                    .arg(subdir, file)));
        }
    }
}

void TestQmlResources::everyQmldirEntryExistsOnDisk()
{
    QRegularExpression re("(\\S+\\.qml)");
    for (const QString &subdir : {QStringLiteral("components"), QStringLiteral("panels")})
    {
        const QString qmldir = readAll(qmlRoot() + "/" + subdir + "/qmldir");
        auto it = re.globalMatch(qmldir);
        while (it.hasNext())
        {
            const QString file = it.next().captured(1);
            QVERIFY2(QFile::exists(qmlRoot() + "/" + subdir + "/" + file),
                     qPrintable(QString("%1/qmldir declares %2, which does not exist").arg(subdir, file)));
        }
    }
}

QTEST_GUILESS_MAIN(TestQmlResources)
#include "tst_qmlresources.moc"
