#include "AppConfig.h"

#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>

namespace
{

// The one place a persisted field is named. Load and save both walk this list, so a
// new setting cannot be added to one direction and forgotten in the other.
template <typename Config, typename Visitor>
void visitFields(Config &c, Visitor &&visit)
{
    visit("slideshowIntervalSeconds", c.slideshowIntervalSeconds);
    visit("transitionDurationMs", c.transitionDurationMs);
    visit("outputWidth", c.outputWidth);
    visit("outputHeight", c.outputHeight);
    visit("outputScreenIndex", c.outputScreenIndex);
    visit("accentColor", c.accentColor);
    visit("autoPlayNextVideo", c.autoPlayNextVideo);
    visit("loopSlideshows", c.loopSlideshows);
    visit("loopVideos", c.loopVideos);
}

struct JsonReader
{
    const QJsonObject &object;

    void operator()(const char *key, int &value) const
    {
        if (object.contains(key))
            value = object.value(key).toInt(value);
    }
    void operator()(const char *key, bool &value) const
    {
        if (object.contains(key))
            value = object.value(key).toBool(value);
    }
    void operator()(const char *key, QString &value) const
    {
        if (object.contains(key))
            value = object.value(key).toString(value);
    }
};

struct JsonWriter
{
    QJsonObject &object;

    void operator()(const char *key, int value) const { object[key] = value; }
    void operator()(const char *key, bool value) const { object[key] = value; }
    void operator()(const char *key, const QString &value) const { object[key] = value; }
};

// Keep values inside ranges the rest of the app can actually use. A zero interval
// makes QTimer fire on every event loop pass and a zero output size or negative
// screen index is unusable downstream.
void clampToUsableRanges(AppConfig &c)
{
    c.slideshowIntervalSeconds = qBound(1, c.slideshowIntervalSeconds, 3600);
    c.transitionDurationMs = qBound(0, c.transitionDurationMs, 10000);
    c.outputWidth = qBound(1, c.outputWidth, 16384);
    c.outputHeight = qBound(1, c.outputHeight, 16384);
    c.outputScreenIndex = qMax(0, c.outputScreenIndex);
}

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
        // Leave ok false: the caller must not treat an unreadable file as absent and
        // overwrite it with defaults.
        return AppConfig();
    }

    AppConfig c;
    const QJsonObject object = doc.object();
    visitFields(c, JsonReader{object});
    clampToUsableRanges(c);

    if (ok)
        *ok = true;
    return c;
}

bool AppConfig::saveToFile(const QString &filePath, QString *error) const
{
    QJsonObject o;
    visitFields(*this, JsonWriter{o});

    QJsonDocument doc(o);

    // QSaveFile writes to a temporary and renames on commit, so an interrupted write
    // cannot leave a truncated config behind.
    QSaveFile f(filePath);
    if (!f.open(QIODevice::WriteOnly))
    {
        if (error)
            *error = QObject::tr("Failed to open %1 for writing").arg(filePath);
        return false;
    }

    if (f.write(doc.toJson(QJsonDocument::Indented)) < 0 || !f.commit())
    {
        if (error)
            *error = QObject::tr("Failed to write %1: %2").arg(filePath, f.errorString());
        return false;
    }
    return true;
}
