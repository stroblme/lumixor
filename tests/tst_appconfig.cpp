// Unit tests for AppConfig load/save (pure file + JSON logic).
// Run with `make test` (or: cmake -B build -DBUILD_TESTS=ON && ctest --test-dir build).
#include <QtTest>
#include <QTemporaryDir>
#include <QFile>
#include "AppConfig.h"

class TestAppConfig : public QObject
{
    Q_OBJECT

private:
    QTemporaryDir m_dir;
    QString write(const QString &name, const QByteArray &content);

private slots:
    void missingFile_reportsOkAndReturnsDefaults();
    void corruptJson_reportsFailure();
    void nonObjectJson_reportsFailure();
    void roundTrip_preservesEveryField();
    void partialJson_keepsDefaultsForAbsentKeys();
    void outOfRangeValues_areClamped();
    void saveToFile_failsOnUnwritablePath();
};

QString TestAppConfig::write(const QString &name, const QByteArray &content)
{
    const QString path = m_dir.filePath(name);
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly))
        return QString();
    f.write(content);
    f.close();
    return path;
}

void TestAppConfig::missingFile_reportsOkAndReturnsDefaults()
{
    bool ok = false;
    const AppConfig c = AppConfig::loadFromFile(m_dir.filePath("does-not-exist.json"), &ok);
    QVERIFY(ok);
    QCOMPARE(c.slideshowIntervalSeconds, AppConfig().slideshowIntervalSeconds);
    QCOMPARE(c.accentColor, AppConfig().accentColor);
}

void TestAppConfig::corruptJson_reportsFailure()
{
    // A truncated/garbled file must NOT be reported as a successful load, otherwise
    // the caller silently overwrites the user's config with defaults on the next save.
    const QString path = write("corrupt.json", "{ \"slideshowIntervalSeconds\": 9, ");
    QVERIFY(!path.isEmpty());

    bool ok = true;
    const AppConfig c = AppConfig::loadFromFile(path, &ok);
    QVERIFY(!ok);
    QCOMPARE(c.slideshowIntervalSeconds, AppConfig().slideshowIntervalSeconds);
}

void TestAppConfig::nonObjectJson_reportsFailure()
{
    const QString path = write("array.json", "[1, 2, 3]");
    QVERIFY(!path.isEmpty());

    bool ok = true;
    AppConfig::loadFromFile(path, &ok);
    QVERIFY(!ok);
}

void TestAppConfig::roundTrip_preservesEveryField()
{
    AppConfig out;
    out.slideshowIntervalSeconds = 12;
    out.transitionDurationMs = 350;
    out.outputWidth = 1920;
    out.outputHeight = 1080;
    out.outputScreenIndex = 2;
    out.accentColor = "#FF5722";
    out.autoPlayNextVideo = false;
    out.loopSlideshows = false;
    out.loopVideos = false;

    const QString path = m_dir.filePath("roundtrip.json");
    QString error;
    QVERIFY2(out.saveToFile(path, &error), qPrintable(error));

    bool ok = false;
    const AppConfig in = AppConfig::loadFromFile(path, &ok);
    QVERIFY(ok);
    QCOMPARE(in.slideshowIntervalSeconds, out.slideshowIntervalSeconds);
    QCOMPARE(in.transitionDurationMs, out.transitionDurationMs);
    QCOMPARE(in.outputWidth, out.outputWidth);
    QCOMPARE(in.outputHeight, out.outputHeight);
    QCOMPARE(in.outputScreenIndex, out.outputScreenIndex);
    QCOMPARE(in.accentColor, out.accentColor);
    QCOMPARE(in.autoPlayNextVideo, out.autoPlayNextVideo);
    QCOMPARE(in.loopSlideshows, out.loopSlideshows);
    QCOMPARE(in.loopVideos, out.loopVideos);
}

void TestAppConfig::partialJson_keepsDefaultsForAbsentKeys()
{
    const QString path = write("partial.json", "{ \"accentColor\": \"#123456\" }");
    QVERIFY(!path.isEmpty());

    bool ok = false;
    const AppConfig c = AppConfig::loadFromFile(path, &ok);
    QVERIFY(ok);
    QCOMPARE(c.accentColor, QString("#123456"));
    QCOMPARE(c.slideshowIntervalSeconds, AppConfig().slideshowIntervalSeconds);
    QCOMPARE(c.autoPlayNextVideo, AppConfig().autoPlayNextVideo);
}

void TestAppConfig::outOfRangeValues_areClamped()
{
    // A zero interval would make QTimer fire every event loop pass; a negative screen
    // index and zero output size are equally unusable downstream.
    const QString path = write("range.json",
                               "{ \"slideshowIntervalSeconds\": 0,"
                               "  \"transitionDurationMs\": -5,"
                               "  \"outputWidth\": 0,"
                               "  \"outputHeight\": -100,"
                               "  \"outputScreenIndex\": -3 }");
    QVERIFY(!path.isEmpty());

    bool ok = false;
    const AppConfig c = AppConfig::loadFromFile(path, &ok);
    QVERIFY(ok);
    QVERIFY(c.slideshowIntervalSeconds >= 1);
    QVERIFY(c.transitionDurationMs >= 0);
    QVERIFY(c.outputWidth >= 1);
    QVERIFY(c.outputHeight >= 1);
    QVERIFY(c.outputScreenIndex >= 0);
}

void TestAppConfig::saveToFile_failsOnUnwritablePath()
{
    AppConfig c;
    QString error;
    QVERIFY(!c.saveToFile(m_dir.filePath("no/such/dir/config.json"), &error));
    QVERIFY(!error.isEmpty());
}

QTEST_GUILESS_MAIN(TestAppConfig)
#include "tst_appconfig.moc"
