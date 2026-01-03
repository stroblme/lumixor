#include "AppConfig.h"

#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>

static AppConfig fromJson(const QJsonObject &o)
{
    AppConfig c;
    if (o.contains("slideshowIntervalSeconds"))
        c.slideshowIntervalSeconds = o.value("slideshowIntervalSeconds").toInt(c.slideshowIntervalSeconds);
    if (o.contains("transitionDurationMs"))
        c.transitionDurationMs = o.value("transitionDurationMs").toInt(c.transitionDurationMs);
    if (o.contains("controlWidth"))
        c.controlWidth = o.value("controlWidth").toInt(c.controlWidth);
    if (o.contains("controlHeight"))
        c.controlHeight = o.value("controlHeight").toInt(c.controlHeight);
    if (o.contains("outputWidth"))
        c.outputWidth = o.value("outputWidth").toInt(c.outputWidth);
    if (o.contains("outputHeight"))
        c.outputHeight = o.value("outputHeight").toInt(c.outputHeight);
    if (o.contains("outputScreenIndex"))
        c.outputScreenIndex = o.value("outputScreenIndex").toInt(c.outputScreenIndex);
    if (o.contains("accentColor"))
        c.accentColor = o.value("accentColor").toString(c.accentColor);
    if (o.contains("uiScale"))
        c.uiScale = o.value("uiScale").toDouble(c.uiScale);
    if (o.contains("autoPlayNextVideo"))
        c.autoPlayNextVideo = o.value("autoPlayNextVideo").toBool(c.autoPlayNextVideo);
    return c;
}

AppConfig AppConfig::loadFromFile(const QString &filePath, bool *ok)
{
    if (ok)
        *ok = false;
    QFile f(filePath);
    if (!f.open(QIODevice::ReadOnly))
    {
        // return defaults if file missing
        if (ok)
            *ok = true;
        return AppConfig();
    }

    const QByteArray data = f.readAll();
    f.close();

    QJsonParseError err;
    QJsonDocument doc = QJsonDocument::fromJson(data, &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject())
    {
        return AppConfig();
    }

    if (ok)
        *ok = true;
    return fromJson(doc.object());
}

bool AppConfig::saveToFile(const QString &filePath, QString *error) const
{
    QJsonObject o;
    o["slideshowIntervalSeconds"] = slideshowIntervalSeconds;
    o["transitionDurationMs"] = transitionDurationMs;
    o["controlWidth"] = controlWidth;
    o["controlHeight"] = controlHeight;
    o["outputWidth"] = outputWidth;
    o["outputHeight"] = outputHeight;
    o["outputScreenIndex"] = outputScreenIndex;
    o["accentColor"] = accentColor;
    o["uiScale"] = uiScale;
    o["autoPlayNextVideo"] = autoPlayNextVideo;

    QJsonDocument doc(o);

    QFile f(filePath);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate))
    {
        if (error)
            *error = QObject::tr("Failed to open %1 for writing").arg(filePath);
        return false;
    }

    f.write(doc.toJson(QJsonDocument::Indented));
    f.close();
    return true;
}
