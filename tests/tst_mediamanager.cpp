// Unit tests for MediaManager (pure logic: extension classification + folder scan).
// Run with `make test` (or: cmake -B build -DBUILD_TESTS=ON && ctest --test-dir build).
#include <QtTest>
#include <QTemporaryDir>
#include <QFile>
#include "MediaManager.h"

class TestMediaManager : public QObject
{
    Q_OBJECT

private slots:
    void getMediaType_data();
    void getMediaType();
    void addMedia_filtersUnknownAndTracksState();
    void getMediaPathsFromFolder_filtersByType();
};

void TestMediaManager::getMediaType_data()
{
    QTest::addColumn<QString>("path");
    QTest::addColumn<QString>("expected");

    QTest::newRow("mp4") << "/a/b/clip.mp4" << "video";
    QTest::newRow("mov uppercase") << "/a/b/CLIP.MOV" << "video";
    QTest::newRow("mkv") << "movie.mkv" << "video";
    QTest::newRow("avi") << "movie.avi" << "video";
    QTest::newRow("jpg") << "/p/img.jpg" << "image";
    QTest::newRow("JPG uppercase") << "/p/IMG.JPG" << "image";
    QTest::newRow("jpeg") << "img.jpeg" << "image";
    QTest::newRow("png") << "img.png" << "image";
    QTest::newRow("bmp") << "img.bmp" << "image";
    QTest::newRow("webm unsupported") << "clip.webm" << "";
    QTest::newRow("txt") << "notes.txt" << "";
    QTest::newRow("no extension") << "/path/README" << "";
    QTest::newRow("empty") << "" << "";
}

void TestMediaManager::getMediaType()
{
    QFETCH(QString, path);
    QFETCH(QString, expected);
    MediaManager m;
    QCOMPARE(m.getMediaType(path), expected);
}

void TestMediaManager::addMedia_filtersUnknownAndTracksState()
{
    MediaManager m;
    QCOMPARE(m.count(), 0);

    m.addMedia("/x/photo.png");
    m.addMedia("/x/clip.mp4");
    m.addMedia("/x/notes.txt"); // unknown extension -> ignored

    QCOMPARE(m.count(), 2);
    QCOMPARE(m.typeAt(0), QString("image"));
    QCOMPARE(m.typeAt(1), QString("video"));
    QCOMPARE(m.pathAt(0), QString("/x/photo.png"));

    // out-of-range access returns empty, not a crash
    QCOMPARE(m.pathAt(5), QString());
    QCOMPARE(m.typeAt(-1), QString());
}

void TestMediaManager::getMediaPathsFromFolder_filtersByType()
{
    QTemporaryDir dir;
    QVERIFY(dir.isValid());

    auto touch = [&](const QString &name) {
        QFile f(dir.filePath(name));
        QVERIFY(f.open(QIODevice::WriteOnly));
        f.write("x");
        f.close();
    };
    touch("a.jpg");
    touch("b.png");
    touch("c.mp4");
    touch("d.txt"); // ignored by both filters

    MediaManager m;

    const QStringList images = m.getMediaPathsFromFolder(dir.path(), "image");
    QCOMPARE(images.size(), 2);

    const QStringList videos = m.getMediaPathsFromFolder(dir.path(), "video");
    QCOMPARE(videos.size(), 1);
    QVERIFY(videos.first().endsWith("c.mp4"));
}

QTEST_GUILESS_MAIN(TestMediaManager)
#include "tst_mediamanager.moc"
