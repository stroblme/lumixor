// src/audio/AudioAnalyzer.cpp
#include "AudioAnalyzer.h"
#include <QAudioFormat>
#include <QAudioDeviceInfo>
#include <QtMath>
#include <QDebug>

AudioAnalyzer::AudioAnalyzer(QObject *parent)
    : QObject(parent)
{
    m_spectrum.resize(m_bandCount);
    m_smoothedSpectrum.resize(m_bandCount);
    m_spectrum.fill(0.0f);
    m_smoothedSpectrum.fill(0.0f);

    connect(&m_updateTimer, &QTimer::timeout, this, &AudioAnalyzer::processAudioData);
}

AudioAnalyzer::~AudioAnalyzer()
{
    stop();
}

void AudioAnalyzer::setupAudioInput()
{
    QAudioFormat format;
    format.setSampleRate(SAMPLE_RATE);
    format.setChannelCount(1);
    format.setSampleSize(16);
    format.setCodec("audio/pcm");
    format.setByteOrder(QAudioFormat::LittleEndian);
    format.setSampleType(QAudioFormat::SignedInt);

    // TODO: replace with direct video feed
    QAudioDeviceInfo deviceInfo = QAudioDeviceInfo::defaultInputDevice();

    if (!deviceInfo.isFormatSupported(format))
    {
        qWarning() << "AudioAnalyzer: Default format not supported, trying nearest";
        format = deviceInfo.nearestFormat(format);
    }

    if (deviceInfo.deviceName().isEmpty())
    {
        qWarning() << "AudioAnalyzer: No audio input device available";
        return;
    }

    qDebug() << "AudioAnalyzer: Using device:" << deviceInfo.deviceName();

    m_audioInput = std::make_unique<QAudioInput>(deviceInfo, format);
    m_audioInput->setBufferSize(BUFFER_SIZE * 2);
}

void AudioAnalyzer::start()
{
    if (m_active)
        return;

    setupAudioInput();

    if (!m_audioInput)
    {
        qWarning() << "AudioAnalyzer: Failed to create audio input";
        return;
    }

    m_audioDevice = m_audioInput->start();

    if (!m_audioDevice)
    {
        qWarning() << "AudioAnalyzer: Failed to start audio input";
        return;
    }

    m_updateTimer.start(33); // ~30 fps
    m_active = true;
    emit activeChanged();

    qDebug() << "AudioAnalyzer: Started";
}

void AudioAnalyzer::stop()
{
    if (!m_active)
        return;

    m_updateTimer.stop();

    if (m_audioInput)
    {
        m_audioInput->stop();
        m_audioInput.reset();
    }
    m_audioDevice = nullptr;

    // Clear spectrum
    m_spectrum.fill(0.0f);
    m_smoothedSpectrum.fill(0.0f);
    emit spectrumChanged();

    m_active = false;
    emit activeChanged();

    qDebug() << "AudioAnalyzer: Stopped";
}

void AudioAnalyzer::processAudioData()
{
    if (!m_audioDevice || !m_audioInput)
        return;

    QByteArray data = m_audioDevice->readAll();

    if (data.isEmpty())
        return;

    // Convert to float samples
    QVector<float> samples;
    samples.reserve(data.size() / 2);

    const qint16 *rawData = reinterpret_cast<const qint16 *>(data.constData());
    int sampleCount = data.size() / 2;

    for (int i = 0; i < sampleCount; ++i)
    {
        samples.append(rawData[i] / 32768.0f);
    }

    if (samples.size() >= BUFFER_SIZE)
    {
        performFFT(samples.mid(samples.size() - BUFFER_SIZE, BUFFER_SIZE));
    }
    else if (samples.size() > 0)
    {
        // Pad with zeros if we don't have enough samples
        QVector<float> padded(BUFFER_SIZE, 0.0f);
        for (int i = 0; i < samples.size(); ++i)
        {
            padded[i] = samples[i];
        }
        performFFT(padded);
    }
}

float AudioAnalyzer::hammingWindow(int n, int N)
{
    return 0.54f - 0.46f * qCos(2.0f * M_PI * n / (N - 1));
}

void AudioAnalyzer::performFFT(const QVector<float> &samples)
{
    const int N = samples.size();

    // Apply Hamming window and prepare complex array
    QVector<float> real(N);
    QVector<float> imag(N, 0.0f);

    for (int i = 0; i < N; ++i)
    {
        real[i] = samples[i] * hammingWindow(i, N);
    }

    // Simple DFT (for production, use FFT library like FFTW or KissFFT)
    // This is a simplified radix-2 DFT for demonstration
    // For better performance, consider using a proper FFT implementation

    const int halfN = N / 2;
    QVector<float> magnitudes(halfN);

    // Calculate magnitudes for frequency bins
    // We use a simplified approach: group frequencies into bands
    for (int k = 0; k < halfN; ++k)
    {
        float sumReal = 0.0f;
        float sumImag = 0.0f;

        // Simplified DFT calculation (consider using FFT for better performance)
        // Using stride to reduce computation
        int stride = qMax(1, N / 256);
        for (int n = 0; n < N; n += stride)
        {
            float angle = 2.0f * M_PI * k * n / N;
            sumReal += real[n] * qCos(angle);
            sumImag -= real[n] * qSin(angle);
        }
        sumReal *= stride;
        sumImag *= stride;

        magnitudes[k] = qSqrt(sumReal * sumReal + sumImag * sumImag) / N;
    }

    // Map to frequency bands (logarithmic distribution for better visualization)
    QVector<float> newSpectrum(m_bandCount, 0.0f);

    for (int band = 0; band < m_bandCount; ++band)
    {
        // Logarithmic frequency distribution
        float lowFreq = qPow(halfN, static_cast<float>(band) / m_bandCount);
        float highFreq = qPow(halfN, static_cast<float>(band + 1) / m_bandCount);

        int lowBin = qMax(1, static_cast<int>(lowFreq));
        int highBin = qMin(halfN - 1, static_cast<int>(highFreq));

        float sum = 0.0f;
        int count = 0;

        for (int bin = lowBin; bin <= highBin; ++bin)
        {
            sum += magnitudes[bin];
            count++;
        }

        if (count > 0)
        {
            newSpectrum[band] = (sum / count) * m_gain;
        }
    }

    // Apply smoothing
    for (int i = 0; i < m_bandCount; ++i)
    {
        m_smoothedSpectrum[i] = m_smoothedSpectrum[i] * (1.0f - SMOOTHING_FACTOR) +
                                newSpectrum[i] * SMOOTHING_FACTOR;
        // Clamp to 0-1 range
        m_spectrum[i] = qMin(1.0f, qMax(0.0f, m_smoothedSpectrum[i] * 10.0f));
    }

    emit spectrumChanged();
}

QVariantList AudioAnalyzer::spectrum() const
{
    QVariantList list;
    for (float value : m_spectrum)
    {
        list.append(value);
    }
    return list;
}

void AudioAnalyzer::setBandCount(int count)
{
    if (count < 8)
        count = 8;
    if (count > 128)
        count = 128;

    if (m_bandCount != count)
    {
        m_bandCount = count;
        m_spectrum.resize(count);
        m_smoothedSpectrum.resize(count);
        m_spectrum.fill(0.0f);
        m_smoothedSpectrum.fill(0.0f);
        emit bandCountChanged();
        emit spectrumChanged();
    }
}

void AudioAnalyzer::setActive(bool active)
{
    if (active)
    {
        start();
    }
    else
    {
        stop();
    }
}

void AudioAnalyzer::setGain(qreal gain)
{
    if (!qFuzzyCompare(m_gain, gain))
    {
        m_gain = gain;
        emit gainChanged();
    }
}