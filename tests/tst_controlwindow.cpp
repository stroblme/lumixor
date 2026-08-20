// Integration smoke test: loads the real QML with the real controllers behind it and
// exercises the tab/slideshow state machine. Guards the properties the transport
// buttons bind to, which unit tests on the C++ classes alone cannot reach.
#include <QtTest>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlExpression>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QImage>

#include "util/Application.h"
#include "core/MediaManager.h"
#include "core/PlaybackController.h"
#include "core/SlideshowController.h"
#include "ui/OutputBridge.h"
#include "ui/ControlBridge.h"
#include "ui/PreferencesController.h"
#include "ui/ExifImageProvider.h"
#include "audio/AudioAnalyzer.h"

static QStringList g_warnings;
static QtMessageHandler g_previousHandler = nullptr;

// QTest installs its own handler inside qExec(), so this one has to be layered on top
// from initTestCase() and must forward, or the test output disappears.
static void captureWarnings(QtMsgType type, const QMessageLogContext &context, const QString &msg)
{
    if (type == QtWarningMsg || type == QtCriticalMsg || type == QtFatalMsg)
        g_warnings << msg;
    if (g_previousHandler)
        g_previousHandler(type, context, msg);
}

// The video tests use invented clip paths that the platform media backend cannot
// open. Its complaints are a fixture artefact; anything else is a real problem.
static QStringList warningsIgnoringMissingClips()
{
    QStringList real;
    for (const QString &warning : g_warnings)
    {
        if (!warning.contains(QLatin1String("/clips/")))
            real << warning;
    }
    return real;
}

class TestControlWindow : public QObject
{
    Q_OBJECT

public:
    explicit TestControlWindow(Application *app) : m_app(app) {}

private:
    Application *m_app;
    QQmlApplicationEngine m_engine;
    QObject *m_root = nullptr;
    QObject *m_outputRoot = nullptr;
    OutputBridge *m_output = nullptr;
    QTemporaryDir m_mediaDir;
    QString m_imageA;
    QString m_imageB;

    // Real files, so the EXIF image provider does not warn about missing paths and the
    // no-warning assertions stay meaningful.
    QString writeImage(const QString &name)
    {
        const QString path = m_mediaDir.filePath(name);
        QImage image(4, 4, QImage::Format_RGB32);
        image.fill(Qt::blue);
        return image.save(path, "PNG") ? path : QString();
    }

    QVariant eval(const QString &expression) { return evalIn(m_root, expression); }

    // Walk the object tree for the first item carrying `marker` as a property. Used to
    // reach components that are nested several layouts deep.
    QVariant findByProperty(const QString &marker, const QString &readProperty)
    {
        return findWhere(QString("item.%1 !== undefined").arg(marker), readProperty);
    }

    // Same walk, but the caller supplies the predicate over `item`.
    QVariant findWhere(const QString &condition, const QString &readProperty)
    {
        return eval(QString("(function () {"
                            "  function walk(item) {"
                            "    if (!item) return null;"
                            "    if (%1) return item;"
                            "    var kids = item.children || [];"
                            "    for (var i = 0; i < kids.length; ++i) {"
                            "      var hit = walk(kids[i]);"
                            "      if (hit) return hit;"
                            "    }"
                            "    return null;"
                            "  }"
                            "  var found = walk(controlRoot.contentItem);"
                            "  return found ? found.%2 : undefined;"
                            "})()")
                       .arg(condition, readProperty));
    }

    QVariant evalIn(QObject *scope, const QString &expression)
    {
        QQmlExpression expr(qmlContext(scope), scope, expression);
        const QVariant value = expr.evaluate();
        if (expr.hasError())
        {
            qWarning() << "expression failed:" << expression << expr.error().toString();
            return QVariant();
        }
        return value;
    }

private slots:
    void initTestCase();
    void init() { g_warnings.clear(); }
    void loadsWithoutWarnings();
    void addMediaTab_appendsRowAndSelectsIt();
    void transportStateFollowsController();
    void slideshowUpdatesCorrectRowAfterReorder();
    void removingRunningSlideshowTabClearsActiveId();
    void preferencesAreTheSingleSourceOfTruth();
    void previewLayerReportsContentRect();
    void previewFollowsOutputWindowAspectRatio();
    void outputDrivesVideoProgress();
    void outputDrivesPlaylistAdvance();
    void lastVideoStopsWhenLoopingIsOff();
};

void TestControlWindow::initTestCase()
{
    g_previousHandler = qInstallMessageHandler(captureWarnings);

    QVERIFY(m_mediaDir.isValid());
    m_imageA = writeImage("a.png");
    m_imageB = writeImage("b.png");
    QVERIFY(!m_imageA.isEmpty());
    QVERIFY(!m_imageB.isEmpty());

    MediaManager *mediaManager = new MediaManager(this);
    PlaybackController *playback = new PlaybackController(this);
    OutputBridge *output = new OutputBridge(this);
    m_output = output;
    SlideshowController *slideshow = new SlideshowController(mediaManager, this);
    ControlBridge *bridge = new ControlBridge(this);
    PreferencesController *preferences = new PreferencesController(m_app, this);
    AudioAnalyzer *audio = new AudioAnalyzer(this);

    m_engine.addImageProvider("exif", new ExifImageProvider());
    QQmlContext *ctx = m_engine.rootContext();
    ctx->setContextProperty("mediaManager", mediaManager);
    ctx->setContextProperty("playbackController", playback);
    ctx->setContextProperty("slideshow", slideshow);
    ctx->setContextProperty("controlBridge", bridge);
    ctx->setContextProperty("outputWindow", output);
    ctx->setContextProperty("preferences", preferences);
    ctx->setContextProperty("audioAnalyzer", audio);

    m_engine.load(QUrl(QStringLiteral("qrc:/qml/OutputWindow.qml")));
    m_engine.load(QUrl(QStringLiteral("qrc:/qml/ControlWindow.qml")));

    QCOMPARE(m_engine.rootObjects().size(), 2);
    for (QObject *root : m_engine.rootObjects())
    {
        if (root->objectName() == "controlRoot")
            m_root = root;
        else if (root->objectName() == "outputRoot")
        {
            m_outputRoot = root;
            output->setRootObject(root);
        }
    }
    QVERIFY2(m_root, "ControlWindow.qml did not produce a root named controlRoot");
    QVERIFY2(m_outputRoot, "OutputWindow.qml did not produce a root named outputRoot");
    QVERIFY2(g_warnings.isEmpty(), qPrintable("QML loaded with warnings:\n" + g_warnings.join("\n")));
}

void TestControlWindow::loadsWithoutWarnings()
{
    // initTestCase already loaded the QML; re-check that a fresh interaction with the
    // root produces no binding errors.
    QCOMPARE(eval("mediaTabsModel.count").toInt(), 0);

    // The extracted panels must really be part of the tree, not silently absent.
    QVERIFY2(eval("rightSide.children.length").toInt() >= 3,
             "right column is missing the preview, spectrometer or blackout panel");
    QVERIFY2(g_warnings.isEmpty(), qPrintable(g_warnings.join("\n")));
}

void TestControlWindow::addMediaTab_appendsRowAndSelectsIt()
{
    const int row = eval("addMediaTab('slideshow')").toInt();
    QCOMPARE(row, 0);
    QCOMPARE(eval("mediaTabsModel.count").toInt(), 1);
    QCOMPARE(eval("mediaTabsModel.get(0).tabType").toString(), QString("slideshow"));
    // indexOfTab must agree with the row that was just appended.
    QCOMPARE(eval("indexOfTab(mediaTabsModel.get(0).tabId)").toInt(), 0);

    // The tab bar and the tab's content must actually be built, otherwise the
    // no-warnings assertions below would cover nothing.
    QCOMPARE(eval("mediaTabsRepeater.count").toInt(), 1);
    QVERIFY2(eval("mediaTabsRepeater.itemAt(0) !== null").toBool(),
             "tab bar delegate was never instantiated");
    // Select the tab so the delegate's checked branch is evaluated too: bindings on
    // the unselected branch of a ternary are never run and hide broken references.
    eval("mainTabs.currentIndex = 2");
    QVERIFY2(eval("mediaTabsRepeater.itemAt(0).checked").toBool(), "media tab did not become current");
    QCOMPARE(eval("mediaTabsRepeater.itemAt(0).tabName").toString(), QString("Slideshow 1"));
    QVERIFY2(g_warnings.isEmpty(), qPrintable(g_warnings.join("\n")));
}

void TestControlWindow::transportStateFollowsController()
{
    eval(QString("mediaTabsModel.get(0).mediaModel.append({'path': '%1', 'type': 'image'})").arg(m_imageA));
    eval(QString("mediaTabsModel.get(0).mediaModel.append({'path': '%1', 'type': 'image'})").arg(m_imageB));
    QCOMPARE(eval("mediaTabsModel.get(0).mediaModel.count").toInt(), 2);

    eval("activeSlideshowTabId = mediaTabsModel.get(0).tabId");
    eval("slideshow.setImageList(mediaTabsModel.get(0).mediaModel)");
    eval("slideshow.start(60000)");

    // This is exactly the expression the play/pause button binds its checked state to.
    QVERIFY(eval("activeSlideshowTabId === mediaTabsModel.get(0).tabId && slideshow.running").toBool());

    // Reach the extracted SlideshowTransport and confirm its play button really
    // follows the controller rather than keeping its own checked flag.
    QCOMPARE(findByProperty("slideshowPlayChecked", "slideshowPlayChecked").toBool(), true);

    eval("slideshow.pause()");
    QVERIFY(!eval("slideshow.running").toBool());
    QCOMPARE(findByProperty("slideshowPlayChecked", "slideshowPlayChecked").toBool(), false);
    QVERIFY2(g_warnings.isEmpty(), qPrintable(g_warnings.join("\n")));
}

void TestControlWindow::slideshowUpdatesCorrectRowAfterReorder()
{
    // Add a second tab and move the running slideshow to the far side, then make the
    // controller emit a new image. The update must land on the slideshow's own row.
    eval("addMediaTab('video')");
    QCOMPARE(eval("mediaTabsModel.count").toInt(), 2);

    const int slideshowTabId = eval("activeSlideshowTabId").toInt();
    QVERIFY(slideshowTabId >= 0);

    eval("moveMediaTab(0, 1)");
    QCOMPARE(eval("indexOfTab(activeSlideshowTabId)").toInt(), 1);

    eval("slideshow.setCurrentIndex(1)");
    QCOMPARE(eval("slideshow.currentImagePath").toString(), m_imageB);

    // Row 1 is the slideshow tab after the move; row 0 is the video tab and must be
    // untouched. Before indexOfTab() this wrote to whichever row was cached at start.
    QCOMPARE(eval("mediaTabsModel.get(1).currentPath").toString(), m_imageB);
    QCOMPARE(eval("mediaTabsModel.get(0).currentPath").toString(), QString(""));

    // The same update must have reached the output window through OutputBridge.cpp,
    // which is what actually instantiates a MediaLayer for the projector.
    const int layerRow = evalIn(m_outputRoot, QString("indexOfLayer(%1)").arg(slideshowTabId)).toInt();
    QVERIFY2(layerRow >= 0, "slideshow image never reached the output window");
    QCOMPARE(evalIn(m_outputRoot, QString("mediaLayersModel.get(%1).path").arg(layerRow)).toString(), m_imageB);
    QVERIFY2(g_warnings.isEmpty(), qPrintable(g_warnings.join("\n")));
}

void TestControlWindow::removingRunningSlideshowTabClearsActiveId()
{
    const int row = eval("indexOfTab(activeSlideshowTabId)").toInt();
    QCOMPARE(row, 1);
    eval(QString("removeMediaTab(%1)").arg(row));
    QCOMPARE(eval("activeSlideshowTabId").toInt(), -1);
    QCOMPARE(eval("mediaTabsModel.count").toInt(), 1);
    QVERIFY2(g_warnings.isEmpty(), qPrintable(g_warnings.join("\n")));
}

void TestControlWindow::preferencesAreTheSingleSourceOfTruth()
{
    // The window holds read-only views, so a change on the controller must show up
    // without any panel signal relaying it back.
    eval("preferences.slideshowIntervalSeconds = 11");
    QCOMPARE(eval("slideshowDelaySeconds").toInt(), 11);

    // loopSlideshows and loopVideos previously existed only as QML properties and were
    // lost on every restart; they are now backed by the controller.
    eval("preferences.loopSlideshows = false");
    QCOMPARE(eval("loopSlideshows").toBool(), false);
    QCOMPARE(eval("slideshow.loopEnabled").toBool(), false);

    eval("preferences.loopVideos = false");
    QCOMPARE(eval("loopVideos").toBool(), false);

    eval("preferences.accentColor = '#EF5350'");
    QCOMPARE(eval("prefAccentColor").toString(), QString("#EF5350"));
    // The palette now lives in the Theme singleton, driven by a Binding.
    QCOMPARE(eval("Components.Theme.accentColor.toString()").toString(), QString("#ef5350"));

    QVERIFY2(g_warnings.isEmpty(), qPrintable(g_warnings.join("\n")));
}

void TestControlWindow::previewLayerReportsContentRect()
{
    // The preview now renders through the shared MediaLayer. Its contentRect drives
    // the outline showing how the media sits inside the real output, so it must
    // describe the painted area, not the whole letterboxed item.
    const int row = eval("addMediaTab('slideshow')").toInt();
    QVERIFY(row >= 0);
    eval(QString("mediaTabsModel.setProperty(%1, 'currentPath', '%2')").arg(row).arg(m_imageA));

    const QString isSlideshowLayer = "item.contentRect !== undefined && item.layerType === 'slideshow'";

    QTRY_VERIFY2(findWhere(isSlideshowLayer, "contentReady").toBool(),
                 "preview MediaLayer never finished loading the image");

    const QRectF rect = findWhere(isSlideshowLayer, "contentRect").toRectF();
    QVERIFY2(rect.width() > 0 && rect.height() > 0,
             qPrintable(QString("contentRect was %1x%2").arg(rect.width()).arg(rect.height())));

    // A square image inside the 16:9 preview frame is pillarboxed, so the painted
    // area must be narrower than the layer and as tall as it.
    const qreal layerWidth = findWhere(isSlideshowLayer, "width").toReal();
    const qreal layerHeight = findWhere(isSlideshowLayer, "height").toReal();
    QVERIFY2(rect.width() < layerWidth,
             qPrintable(QString("expected pillarboxing: content %1 vs layer %2").arg(rect.width()).arg(layerWidth)));
    QVERIFY2(qAbs(rect.height() - layerHeight) < 1.0,
             qPrintable(QString("expected full height: content %1 vs layer %2").arg(rect.height()).arg(layerHeight)));

    QVERIFY2(g_warnings.isEmpty(), qPrintable(g_warnings.join("\n")));
}

// Build a video tab with two clips, playing the first one. Returns its row.
static const char *kVideoSetup =
    "(function () {"
    "  var row = addMediaTab('video');"
    "  var tab = mediaTabsModel.get(row);"
    "  tab.mediaModel.append({'path': '/clips/one.mp4'});"
    "  tab.mediaModel.append({'path': '/clips/two.mp4'});"
    "  mediaTabsModel.setProperty(row, 'currentPath', '/clips/one.mp4');"
    "  mediaTabsModel.setProperty(row, 'currentIndex', 0);"
    "  mediaTabsModel.setProperty(row, 'isPlaying', true);"
    "  return row;"
    "})()";

// The preview only shows what the audience will see if it is shaped like the output
// window. A portrait image over a landscape video crops differently at 16:9 than at
// 9:16, so a preview stuck at a fixed ratio misleads exactly when it matters.
void TestControlWindow::previewFollowsOutputWindowAspectRatio()
{
    QWindow *outputWindow = qobject_cast<QWindow *>(m_outputRoot);
    QVERIFY(outputWindow);

    outputWindow->resize(800, 600);
    QTRY_COMPARE(m_output->outputAspect(), 800.0 / 600.0);
    QTRY_COMPARE(findByProperty("outputAspect", "outputAspect").toDouble(), 800.0 / 600.0);

    // A vertical output, which is where a fixed 16:9 preview is most wrong.
    outputWindow->resize(1080, 1920);
    QTRY_COMPARE(m_output->outputAspect(), 1080.0 / 1920.0);
    QTRY_COMPARE(findByProperty("outputAspect", "outputAspect").toDouble(), 1080.0 / 1920.0);

    outputWindow->resize(800, 600);
    QVERIFY2(g_warnings.isEmpty(), qPrintable(g_warnings.join("\n")));
}

void TestControlWindow::outputDrivesVideoProgress()
{
    const int row = eval(kVideoSetup).toInt();
    const int tabId = eval(QString("mediaTabsModel.get(%1).tabId").arg(row)).toInt();

    // Progress reported by the output window must reach the transport's model.
    m_output->notifyMediaDuration(tabId, 5000);
    m_output->notifyMediaPosition(tabId, 1234);
    QCOMPARE(eval(QString("mediaTabsModel.get(%1).videoDuration").arg(row)).toInt(), 5000);
    QCOMPARE(eval(QString("mediaTabsModel.get(%1).videoPosition").arg(row)).toInt(), 1234);

    // While the user drags the seek slider the position must be left alone.
    eval(QString("mediaTabsModel.setProperty(%1, 'isSeeking', true)").arg(row));
    m_output->notifyMediaPosition(tabId, 4321);
    QCOMPARE(eval(QString("mediaTabsModel.get(%1).videoPosition").arg(row)).toInt(), 1234);

    eval(QString("mediaTabsModel.setProperty(%1, 'isSeeking', false)").arg(row));
    m_output->notifyMediaPosition(tabId, 4321);
    QCOMPARE(eval(QString("mediaTabsModel.get(%1).videoPosition").arg(row)).toInt(), 4321);

    // An id that no longer has a tab must be ignored rather than throw.
    m_output->notifyMediaPosition(9999, 10);
    QVERIFY2(warningsIgnoringMissingClips().isEmpty(),
             qPrintable(warningsIgnoringMissingClips().join("\n")));
}

void TestControlWindow::outputDrivesPlaylistAdvance()
{
    const int row = eval(kVideoSetup).toInt();
    const int tabId = eval(QString("mediaTabsModel.get(%1).tabId").arg(row)).toInt();
    eval("preferences.autoPlayNextVideo = true");

    // End of the first clip advances to the second. This used to be driven by the
    // preview panel, so it broke whenever the preview was not on screen.
    m_output->notifyMediaEnded(tabId);
    QCOMPARE(eval(QString("mediaTabsModel.get(%1).currentIndex").arg(row)).toInt(), 1);
    QCOMPARE(eval(QString("mediaTabsModel.get(%1).currentPath").arg(row)).toString(), QString("/clips/two.mp4"));
    QCOMPARE(eval(QString("mediaTabsModel.get(%1).videoPosition").arg(row)).toInt(), 0);
    QVERIFY(eval(QString("mediaTabsModel.get(%1).isPlaying").arg(row)).toBool());

    // Past the last clip it wraps, because looping is on.
    eval("preferences.loopVideos = true");
    m_output->notifyMediaEnded(tabId);
    QCOMPARE(eval(QString("mediaTabsModel.get(%1).currentIndex").arg(row)).toInt(), 0);

    // Exercise the same call the output window's QML makes, from the output window's
    // own scope, so a renamed or missing invokable is caught here and not on stage.
    evalIn(m_outputRoot, QString("outputWindow.notifyMediaDuration(%1, 7000)").arg(tabId));
    evalIn(m_outputRoot, QString("outputWindow.notifyMediaPosition(%1, 250)").arg(tabId));
    evalIn(m_outputRoot, QString("outputWindow.notifyMediaEnded(%1)").arg(tabId));
    QCOMPARE(eval(QString("mediaTabsModel.get(%1).videoDuration").arg(row)).toInt(), 7000);
    QCOMPARE(eval(QString("mediaTabsModel.get(%1).currentIndex").arg(row)).toInt(), 1);
    QVERIFY2(warningsIgnoringMissingClips().isEmpty(),
             qPrintable(warningsIgnoringMissingClips().join("\n")));
}

void TestControlWindow::lastVideoStopsWhenLoopingIsOff()
{
    const int row = eval(kVideoSetup).toInt();
    const int tabId = eval(QString("mediaTabsModel.get(%1).tabId").arg(row)).toInt();
    eval("preferences.autoPlayNextVideo = true");
    eval("preferences.loopVideos = false");

    m_output->notifyMediaEnded(tabId); // -> clip two
    QCOMPARE(eval(QString("mediaTabsModel.get(%1).currentIndex").arg(row)).toInt(), 1);

    m_output->notifyMediaEnded(tabId); // past the end, looping off
    QCOMPARE(eval(QString("mediaTabsModel.get(%1).currentIndex").arg(row)).toInt(), 1);
    QCOMPARE(eval(QString("mediaTabsModel.get(%1).isPlaying").arg(row)).toBool(), false);

    // With auto-advance off the tab simply stops instead of moving on.
    eval("preferences.autoPlayNextVideo = false");
    eval(QString("mediaTabsModel.setProperty(%1, 'currentIndex', 0)").arg(row));
    eval(QString("mediaTabsModel.setProperty(%1, 'isPlaying', true)").arg(row));
    m_output->notifyMediaEnded(tabId);
    QCOMPARE(eval(QString("mediaTabsModel.get(%1).currentIndex").arg(row)).toInt(), 0);
    QCOMPARE(eval(QString("mediaTabsModel.get(%1).isPlaying").arg(row)).toBool(), false);
    QVERIFY2(warningsIgnoringMissingClips().isEmpty(),
             qPrintable(warningsIgnoringMissingClips().join("\n")));
}

int main(int argc, char *argv[])
{
    // Keep the user's real config file out of reach of the test run.
    QStandardPaths::setTestModeEnabled(true);

    // Application's constructor runs QCommandLineParser::process(), which exits on any
    // option it does not know, so it must not see QTest's own arguments.
    int appArgc = 1;
    char *appArgv[] = {argv[0], nullptr};
    Application app(appArgc, appArgv);

    TestControlWindow tc(&app);
    const int result = QTest::qExec(&tc, argc, argv);

    // Restore Qt's default handler, not the one captured in initTestCase: that one
    // belongs to QTest, whose loggers are gone once qExec returns, and it asserts if
    // anything logs during teardown.
    qInstallMessageHandler(nullptr);
    g_previousHandler = nullptr;
    return result;
}

#include "tst_controlwindow.moc"
