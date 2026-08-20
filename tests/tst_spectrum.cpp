// Unit tests for the spectrum DSP: transform correctness and band placement.
#include <QtTest>
#include <QtMath>
#include "SpectrumAnalyzer.h"

class TestSpectrum : public QObject
{
    Q_OBJECT

private:
    static QVector<float> sine(float frequencyHz, int sampleCount, float sampleRate, float amplitude = 0.5f);

private slots:
    void fft_dcSignalLandsInBinZero();
    void fft_ignoresNonPowerOfTwo();
    void fftSize_roundsDownToPowerOfTwo();
    void silence_producesNoEnergy();
    void tone_peaksInExpectedBand();
    void higherToneLandsInHigherBand();
    void bandCount_isClamped();
    void reset_clearsBands();
};

QVector<float> TestSpectrum::sine(float frequencyHz, int sampleCount, float sampleRate, float amplitude)
{
    QVector<float> out(sampleCount);
    for (int i = 0; i < sampleCount; ++i)
        out[i] = amplitude * std::sin(2.0f * float(M_PI) * frequencyHz * i / sampleRate);
    return out;
}

void TestSpectrum::fft_dcSignalLandsInBinZero()
{
    const int n = 16;
    QVector<float> real(n, 1.0f), imag(n, 0.0f);
    SpectrumAnalyzer::fft(real, imag);

    QVERIFY(qAbs(real[0] - float(n)) < 1e-3f);
    QVERIFY(qAbs(imag[0]) < 1e-3f);
    for (int k = 1; k < n; ++k)
        QVERIFY2(qAbs(real[k]) < 1e-3f && qAbs(imag[k]) < 1e-3f, qPrintable(QString("bin %1 not empty").arg(k)));
}

void TestSpectrum::fft_ignoresNonPowerOfTwo()
{
    QVector<float> real{1.0f, 2.0f, 3.0f}, imag(3, 0.0f);
    const QVector<float> before = real;
    SpectrumAnalyzer::fft(real, imag); // must be a no-op rather than read out of bounds
    QCOMPARE(real, before);
}

void TestSpectrum::fftSize_roundsDownToPowerOfTwo()
{
    QCOMPARE(SpectrumAnalyzer(1000).fftSize(), 512);
    QCOMPARE(SpectrumAnalyzer(2048).fftSize(), 2048);
}

void TestSpectrum::silence_producesNoEnergy()
{
    SpectrumAnalyzer a(2048);
    const QVector<float> bands = a.process(QVector<float>(2048, 0.0f));
    for (float value : bands)
        QCOMPARE(value, 0.0f);
}

void TestSpectrum::tone_peaksInExpectedBand()
{
    SpectrumAnalyzer a(2048);
    a.setBandCount(20);

    const QVector<float> samples = sine(1000.0f, 2048, 44100.0f);
    QVector<float> bands;
    for (int i = 0; i < 20; ++i) // let the smoothing settle
        bands = a.process(samples);

    int peak = 0;
    for (int i = 1; i < bands.size(); ++i)
        if (bands[i] > bands[peak])
            peak = i;

    // 1 kHz at 44.1 kHz with a 2048-point window is bin ~46. The bands are spread
    // logarithmically over 1024 bins, so band b covers bins [2^(b/2), 2^((b+1)/2)),
    // which puts bin 46 in band 11.
    QVERIFY2(qAbs(peak - 11) <= 1, qPrintable(QString("peak band was %1").arg(peak)));
    QVERIFY(bands[peak] > 0.0f);
}

void TestSpectrum::higherToneLandsInHigherBand()
{
    SpectrumAnalyzer low(2048), high(2048);
    QVector<float> lowBands, highBands;
    for (int i = 0; i < 20; ++i)
    {
        lowBands = low.process(sine(500.0f, 2048, 44100.0f));
        highBands = high.process(sine(8000.0f, 2048, 44100.0f));
    }

    auto argmax = [](const QVector<float> &v) {
        int best = 0;
        for (int i = 1; i < v.size(); ++i)
            if (v[i] > v[best])
                best = i;
        return best;
    };
    QVERIFY(argmax(highBands) > argmax(lowBands));
}

void TestSpectrum::bandCount_isClamped()
{
    SpectrumAnalyzer a(2048);
    a.setBandCount(1);
    QCOMPARE(a.bandCount(), 8);
    a.setBandCount(9999);
    QCOMPARE(a.bandCount(), 128);
    QCOMPARE(a.bands().size(), 128);
}

void TestSpectrum::reset_clearsBands()
{
    SpectrumAnalyzer a(2048);
    a.process(sine(1000.0f, 2048, 44100.0f));

    bool anyEnergy = false;
    for (float value : a.bands())
        anyEnergy = anyEnergy || value > 0.0f;
    QVERIFY(anyEnergy);

    a.reset();
    for (float value : a.bands())
        QCOMPARE(value, 0.0f);
}

QTEST_GUILESS_MAIN(TestSpectrum)
#include "tst_spectrum.moc"
