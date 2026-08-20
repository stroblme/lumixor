#include "SpectrumAnalyzer.h"

#include <QtMath>
#include <algorithm>

SpectrumAnalyzer::SpectrumAnalyzer(int fftSize)
    : m_fftSize(fftSize)
{
    // Round down to a power of two: the radix-2 transform requires it.
    int size = 2;
    while (size * 2 <= fftSize)
        size *= 2;
    m_fftSize = size;

    m_bands.fill(0.0f, m_bandCount);
    m_smoothed.fill(0.0f, m_bandCount);
}

void SpectrumAnalyzer::setBandCount(int count)
{
    count = qBound(8, count, 128);
    if (count == m_bandCount)
        return;
    m_bandCount = count;
    reset();
}

void SpectrumAnalyzer::setGain(float gain)
{
    m_gain = qBound(0.0f, gain, 10.0f);
}

void SpectrumAnalyzer::reset()
{
    m_bands.fill(0.0f, m_bandCount);
    m_smoothed.fill(0.0f, m_bandCount);
}

float SpectrumAnalyzer::hammingWindow(int n, int windowSize)
{
    return 0.54f - 0.46f * std::cos(2.0f * float(M_PI) * n / (windowSize - 1));
}

void SpectrumAnalyzer::fft(QVector<float> &real, QVector<float> &imag)
{
    const int n = real.size();
    if (n < 2 || (n & (n - 1)) != 0 || imag.size() != n)
        return;

    // Bit-reversal permutation.
    for (int i = 1, j = 0; i < n; ++i)
    {
        int bit = n >> 1;
        for (; j & bit; bit >>= 1)
            j ^= bit;
        j ^= bit;
        if (i < j)
        {
            std::swap(real[i], real[j]);
            std::swap(imag[i], imag[j]);
        }
    }

    for (int len = 2; len <= n; len <<= 1)
    {
        const double angle = -2.0 * M_PI / len;
        const float stepReal = float(std::cos(angle));
        const float stepImag = float(std::sin(angle));
        const int half = len / 2;

        for (int start = 0; start < n; start += len)
        {
            float wReal = 1.0f;
            float wImag = 0.0f;
            for (int k = 0; k < half; ++k)
            {
                const int a = start + k;
                const int b = a + half;

                const float vReal = real[b] * wReal - imag[b] * wImag;
                const float vImag = real[b] * wImag + imag[b] * wReal;

                real[b] = real[a] - vReal;
                imag[b] = imag[a] - vImag;
                real[a] += vReal;
                imag[a] += vImag;

                const float nextReal = wReal * stepReal - wImag * stepImag;
                wImag = wReal * stepImag + wImag * stepReal;
                wReal = nextReal;
            }
        }
    }
}

const QVector<float> &SpectrumAnalyzer::process(const QVector<float> &samples)
{
    const int n = m_fftSize;

    QVector<float> real(n, 0.0f);
    QVector<float> imag(n, 0.0f);

    // Keep the most recent window; zero padding covers a short block.
    const int available = std::min(samples.size(), n);
    const int offset = samples.size() > n ? samples.size() - n : 0;
    for (int i = 0; i < available; ++i)
        real[i] = samples[offset + i] * hammingWindow(i, n);

    fft(real, imag);

    const int halfN = n / 2;
    QVector<float> magnitudes(halfN);
    for (int k = 0; k < halfN; ++k)
        magnitudes[k] = std::sqrt(real[k] * real[k] + imag[k] * imag[k]) / n;

    // Logarithmic band distribution, so low frequencies are not crushed into one bar.
    QVector<float> fresh(m_bandCount, 0.0f);
    for (int band = 0; band < m_bandCount; ++band)
    {
        const float lowFreq = std::pow(float(halfN), float(band) / m_bandCount);
        const float highFreq = std::pow(float(halfN), float(band + 1) / m_bandCount);

        const int lowBin = qMax(1, int(lowFreq));
        const int highBin = qMin(halfN - 1, int(highFreq));

        float sum = 0.0f;
        int count = 0;
        for (int bin = lowBin; bin <= highBin; ++bin)
        {
            sum += magnitudes[bin];
            count++;
        }
        if (count > 0)
            fresh[band] = (sum / count) * m_gain;
    }

    for (int i = 0; i < m_bandCount; ++i)
    {
        m_smoothed[i] = m_smoothed[i] * (1.0f - kSmoothingFactor) + fresh[i] * kSmoothingFactor;
        m_bands[i] = qBound(0.0f, m_smoothed[i] * kDisplayScale, 1.0f);
    }

    return m_bands;
}
