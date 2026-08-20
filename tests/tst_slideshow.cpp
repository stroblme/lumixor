// Unit tests for slideshow navigation: image selection, looping and the end-of-list
// behaviour. These run against the MediaManager backend, which needs no QML.
#include <QtTest>
#include <QSignalSpy>
#include "MediaManager.h"
#include "SlideshowController.h"

class TestSlideshow : public QObject
{
    Q_OBJECT

private slots:
    void startsOnFirstImage();
    void advanceSkipsNonImages();
    void loopEnabled_wrapsToStart();
    void loopDisabled_endsAtLastImage();
    void setCurrentIndex_rejectsOutOfRange();
    void reset_clearsCurrentPath();
    void emptyList_startDoesNothing();
    void zeroInterval_doesNotSpin();
};

void TestSlideshow::startsOnFirstImage()
{
    MediaManager mm;
    mm.addMedia("/x/a.png");
    mm.addMedia("/x/b.png");
    SlideshowController s(&mm);

    s.start(60000);
    QVERIFY(s.isRunning());
    QCOMPARE(s.currentImagePath(), QString("/x/a.png"));
}

void TestSlideshow::advanceSkipsNonImages()
{
    MediaManager mm;
    mm.addMedia("/x/a.png");
    mm.addMedia("/x/clip.mp4"); // must be stepped over, not shown as an image
    mm.addMedia("/x/b.png");
    SlideshowController s(&mm);

    QSignalSpy spy(&s, &SlideshowController::currentImagePathChanged);
    s.start(100);
    QCOMPARE(s.currentImagePath(), QString("/x/a.png"));

    QVERIFY(spy.wait(3000));
    QCOMPARE(s.currentImagePath(), QString("/x/b.png"));
}

void TestSlideshow::loopEnabled_wrapsToStart()
{
    MediaManager mm;
    mm.addMedia("/x/a.png");
    mm.addMedia("/x/b.png");
    SlideshowController s(&mm);
    s.setLoopEnabled(true);

    QSignalSpy spy(&s, &SlideshowController::currentImagePathChanged);
    s.start(100);
    QCOMPARE(s.currentImagePath(), QString("/x/a.png"));

    QVERIFY(spy.wait(3000));
    QCOMPARE(s.currentImagePath(), QString("/x/b.png"));
    QVERIFY(spy.wait(3000));
    QCOMPARE(s.currentImagePath(), QString("/x/a.png"));
    QVERIFY(s.isRunning());
}

void TestSlideshow::loopDisabled_endsAtLastImage()
{
    MediaManager mm;
    mm.addMedia("/x/a.png");
    mm.addMedia("/x/b.png");
    SlideshowController s(&mm);
    s.setLoopEnabled(false);

    QSignalSpy ended(&s, &SlideshowController::slideshowEnded);
    QSignalSpy running(&s, &SlideshowController::runningChanged);
    s.start(100);

    QVERIFY(ended.wait(5000));
    QVERIFY(!s.isRunning());
    // The transport buttons bind to running, so it must report the stop.
    QVERIFY(running.count() >= 2);
}

void TestSlideshow::setCurrentIndex_rejectsOutOfRange()
{
    MediaManager mm;
    mm.addMedia("/x/a.png");
    mm.addMedia("/x/b.png");
    SlideshowController s(&mm);

    s.setCurrentIndex(1);
    QCOMPARE(s.currentImagePath(), QString("/x/b.png"));

    s.setCurrentIndex(99);
    QCOMPARE(s.currentImagePath(), QString("/x/b.png"));
    s.setCurrentIndex(-4);
    QCOMPARE(s.currentImagePath(), QString("/x/b.png"));
}

void TestSlideshow::reset_clearsCurrentPath()
{
    MediaManager mm;
    mm.addMedia("/x/a.png");
    SlideshowController s(&mm);

    s.start(60000);
    QVERIFY(!s.currentImagePath().isEmpty());

    s.reset();
    QVERIFY(!s.isRunning());
    QVERIFY(s.currentImagePath().isEmpty());
}

void TestSlideshow::emptyList_startDoesNothing()
{
    MediaManager mm;
    SlideshowController s(&mm);

    s.start(1000);
    QVERIFY(!s.isRunning());
    QVERIFY(s.currentImagePath().isEmpty());
}

void TestSlideshow::zeroInterval_doesNotSpin()
{
    MediaManager mm;
    mm.addMedia("/x/a.png");
    mm.addMedia("/x/b.png");
    SlideshowController s(&mm);
    s.setLoopEnabled(true);

    QSignalSpy spy(&s, &SlideshowController::currentImagePathChanged);
    s.start(0); // must be clamped, not fire on every event loop pass

    QTest::qWait(400);
    QVERIFY2(spy.count() < 10,
             qPrintable(QString("advanced %1 times in 400ms").arg(spy.count())));
}

QTEST_GUILESS_MAIN(TestSlideshow)
#include "tst_slideshow.moc"
