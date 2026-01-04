// src/audio/AudioAnalyzer.h
#pragma once

#include <QObject>
#include <QAudioInput>
#include <QIODevice>
#include <QTimer>
#include <QVector>
#include <QVariantList>
#include <memory>

class AudioAnalyzer : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList spectrum READ spectrum NOTIFY spectrumChanged)
    Q_PROPERTY(int bandCount READ bandCount WRITE setBandCount NOTIFY bandCountChanged)
    Q_PROPERTY(bool active READ isActive WRITE setActive NOTIFY activeChanged)

public:
    explicit AudioAnalyzer(QObject *parent = nullptr);
    ~AudioAnalyzer();

    QVariantList spectrum() const;
    int bandCount() const { return m_bandCount; }
    bool isActive() const { return m_active; }

    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();

public slots:
    void setBandCount(int count);
    void setActive(bool active);

signals:
    void spectrumChanged();
    void bandCountChanged();
    void activeChanged();

private slots:
    void processAudioData();

private:
    void setupAudioInput();
    void performFFT(const QVector<float> &samples);
    float hammingWindow(int n, int N);

    std::unique_ptr<QAudioInput> m_audioInput;
    QIODevice *m_audioDevice = nullptr;
    QTimer m_updateTimer;

    QVector<float> m_spectrum;
    QVector<float> m_smoothedSpectrum;
    int m_bandCount = 32;
    bool m_active = false;

    static constexpr int SAMPLE_RATE = 44100;
    static constexpr int BUFFER_SIZE = 2048;
    static constexpr float SMOOTHING_FACTOR = 0.3f;
};
