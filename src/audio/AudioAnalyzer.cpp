// src/audio/AudioAnalyzer.cpp
#include "AudioAnalyzer.h"
#include <QAudioFormat>
#include <QAudioDeviceInfo>
#include <QtMath>
#include <QDebug>
#include <cstring>

AudioAnalyzer::AudioAnalyzer(QObject *parent)
    : QObject(parent)
{
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

    if (deviceInfo.isNull() || deviceInfo.deviceName().isEmpty())
    {
        qWarning() << "AudioAnalyzer: No audio input device available";
        return;
    }

    if (!deviceInfo.isFormatSupported(format))
    {
        qWarning() << "AudioAnalyzer: Default format not supported, trying nearest";
        format = deviceInfo.nearestFormat(format);
    }

    // processAudioData() decodes the stream as signed 16-bit mono. Anything else
    // would be reinterpreted as garbage rather than simply sounding wrong.
    if (format.sampleSize() != 16 || format.sampleType() != QAudioFormat::SignedInt || format.channelCount() != 1)
    {
        qWarning() << "AudioAnalyzer: Unsupported input format"
                   << format.sampleSize() << "bit," << format.channelCount() << "channel(s)";
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
        emit activeChanged();
        return;
    }

    m_audioDevice = m_audioInput->start();

    if (!m_audioDevice)
    {
        qWarning() << "AudioAnalyzer: Failed to start audio input";
        m_audioInput->stop();
        m_audioInput.reset();
        emit activeChanged();
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

    m_analyzer.reset();
    emit spectrumChanged();

    m_active = false;
    emit activeChanged();

    qDebug() << "AudioAnalyzer: Stopped";
}

void AudioAnalyzer::processAudioData()
{
    if (!m_audioDevice || !m_audioInput)
        return;

    const QByteArray data = m_audioDevice->readAll();
    if (data.isEmpty())
        return;

    // setupAudioInput() rejects anything that is not signed 16-bit mono, so the frames
    // can be decoded directly here.
    const int sampleCount = data.size() / int(sizeof(qint16));
    if (sampleCount <= 0)
        return;

    QVector<float> samples(sampleCount);
    const char *raw = data.constData();
    for (int i = 0; i < sampleCount; ++i)
    {
        qint16 frame;
        memcpy(&frame, raw + i * sizeof(qint16), sizeof(qint16));
        samples[i] = frame / 32768.0f;
    }

    m_analyzer.process(samples);
    emit spectrumChanged();
}

QVariantList AudioAnalyzer::spectrum() const
{
    QVariantList list;
    for (float value : m_analyzer.bands())
    {
        list.append(value);
    }
    return list;
}

void AudioAnalyzer::setBandCount(int count)
{
    const int previous = m_analyzer.bandCount();
    m_analyzer.setBandCount(count);
    if (m_analyzer.bandCount() != previous)
    {
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
    const float previous = m_analyzer.gain();
    m_analyzer.setGain(float(gain));
    if (!qFuzzyIsNull(m_analyzer.gain() - previous))
        emit gainChanged();
}