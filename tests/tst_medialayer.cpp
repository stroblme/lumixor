// A synchronous Image decode runs on the GUI thread, and the GStreamer video backend
// blocks its streaming thread until the GUI thread accepts each frame, so a
// synchronous slideshow load stalls video playback for the length of the decode.
// MediaLayer therefore decodes into an asynchronous back buffer and hands the result
// to the visible Image, which must find it in the pixmap cache rather than decode it
// a second time.
//
// The layer is built without a Window on purpose: an Image loads from the engine, not
// from a scene graph, so the test needs no OpenGL and runs on a headless machine.
#include <QtTest>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickImageProvider>
#include <QQuickItem>
#include <QThread>

static QThread *s_guiThread = nullptr;
static QStringList s_requests;
static QSize s_lastRequestedSize;
static bool s_decodedOnGuiThread = false;

// Stands in for ExifImageProvider, recording which thread each decode ran on.
class SpyImageProvider : public QQuickImageProvider
{
public:
    SpyImageProvider() : QQuickImageProvider(QQuickImageProvider::Image) {}

    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override
    {
        s_requests << id;
        s_lastRequestedSize = requestedSize;
        if (QThread::currentThread() == s_guiThread)
            s_decodedOnGuiThread = true;
        // Long enough that a decode on the GUI thread would be plainly visible.
        QThread::msleep(250);
        QImage img(400, 300, QImage::Format_RGB32);
        img.fill(id.contains(QLatin1String("two")) ? Qt::green : Qt::red);
        if (size)
            *size = img.size();
        return img;
    }
};

class TestMediaLayer : public QObject
{
    Q_OBJECT

private slots:
    void slideshowDecodesOffGuiThreadAndKeepsPreviousImage();
};

void TestMediaLayer::slideshowDecodesOffGuiThreadAndKeepsPreviousImage()
{
    s_guiThread = QThread::currentThread();
    s_requests.clear();
    s_lastRequestedSize = QSize();
    s_decodedOnGuiThread = false;

    QQmlEngine engine;
    engine.addImageProvider(QStringLiteral("exif"), new SpyImageProvider());

    QQmlComponent component(&engine);
    component.setData(
        "import QtQuick 2.12\n"
        "import \"components\" as Components\n"
        "Components.MediaLayer { width: 400; height: 300;\n"
        "  layerType: \"slideshow\"; layerPath: \"/one.jpg\" }\n",
        QUrl::fromLocalFile(QStringLiteral(SOURCE_QML_DIR) + "/tst_medialayer.qml"));
    QVERIFY2(!component.isError(), qPrintable(component.errorString()));

    QScopedPointer<QObject> object(component.create());
    QVERIFY(object);
    QQuickItem *layer = qobject_cast<QQuickItem *>(object.data());
    QVERIFY(layer);

    QTRY_VERIFY(layer->property("contentReady").toBool());
    QVERIFY2(!s_decodedOnGuiThread, "the first slideshow image decoded on the GUI thread, which stalls video playback");

    layer->setProperty("layerPath", "/two.jpg");

    // While the next image decodes, the layer has to keep showing the previous one.
    // Dropping it would replace the video stall with a black flash on the output.
    for (int elapsed = 0; elapsed < 180; elapsed += 60)
    {
        QTest::qWait(60);
        QVERIFY2(layer->property("contentReady").toBool(),
                 "the previous slideshow image was dropped before the next one was ready, "
                 "which flashes black on the output");
    }

    QTRY_COMPARE(s_requests.count(QStringLiteral("/two.jpg")), 1);
    QTRY_VERIFY(layer->property("contentReady").toBool());

    QVERIFY2(!s_decodedOnGuiThread, "a slideshow image decoded on the GUI thread, which stalls video playback");
    // One decode per image. A second decode means the visible Image missed the pixmap
    // cache, which happens when its cache key stops matching the back buffer's.
    QCOMPARE(s_requests.count(QStringLiteral("/one.jpg")), 1);
    QCOMPARE(s_requests.count(QStringLiteral("/two.jpg")), 1);
    // Without a decode size the provider hands the render thread a full resolution
    // texture, which stalls it while it is also compositing the video layers.
    QVERIFY2(!s_lastRequestedSize.isEmpty(), "MediaLayer did not ask for a bounded decode size");
}

QTEST_MAIN(TestMediaLayer)
#include "tst_medialayer.moc"
