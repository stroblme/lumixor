#pragma once

#include <QVector>

// Turns a block of mono samples into smoothed, normalised band magnitudes for the
// spectrometer. Free of Qt GUI and audio types so it can be tested directly.
class SpectrumAnalyzer
{
public:
    // fftSize must be a power of two.
    explicit SpectrumAnalyzer(int fftSize = 2048);

    void setBandCount(int count);
    int bandCount() const { return m_bandCount; }

    void setGain(float gain);
    float gain() const { return m_gain; }

    int fftSize() const { return m_fftSize; }

    // Clear the smoothing state and zero the bands.
    void reset();

    // Feed mono samples in [-1, 1]. Fewer than fftSize() samples are zero padded, more
    // than fftSize() keeps the most recent window. Returns the band values in [0, 1].
    const QVector<float> &process(const QVector<float> &samples);

    const QVector<float> &bands() const { return m_bands; }

    // In-place iterative radix-2 Cooley-Tukey transform. Exposed for testing.
    static void fft(QVector<float> &real, QVector<float> &imag);

private:
    static float hammingWindow(int n, int windowSize);

    int m_fftSize;
    int m_bandCount = 20;
    float m_gain = 1.2f;

    QVector<float> m_bands;
    QVector<float> m_smoothed;

    static constexpr float kSmoothingFactor = 0.3f;
    // The band values are tiny in absolute terms; this lifts them into a 0-1 display
    // range and matches what the spectrometer was calibrated against.
    static constexpr float kDisplayScale = 10.0f;
};
