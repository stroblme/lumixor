pragma Singleton
import QtQuick 2.12

QtObject {
    // Helper to extract filename from path
    function fileNameFromPath(p) {
        if (!p)
            return "";
        var s = String(p);
        var parts = s.split("/");
        return parts.length > 0 ? parts[parts.length - 1] : s;
    }

    // Helper to create EXIF-aware image URL for local files
    function imageUrlForPath(p) {
        if (!p)
            return "";
        if (p.indexOf(":/") !== -1)
            return p; // already has a scheme
        if (p.startsWith("/"))
            return "image://exif/" + encodeURIComponent(p);
        return p;
    }

    // Helper to create file:// URL for local paths
    function urlForPath(p) {
        if (!p)
            return "";
        if (p.indexOf(":/") !== -1)
            return p; // already has a scheme
        if (p.startsWith("/"))
            return "file://" + p;
        return p;
    }

    // Format milliseconds to mm:ss display
    function formatTime(ms) {
        if (isNaN(ms) || ms < 0)
            return "0:00";
        var totalSec = Math.floor(ms / 1000);
        var min = Math.floor(totalSec / 60);
        var sec = totalSec % 60;
        return min + ":" + (sec < 10 ? "0" : "") + sec;
    }
}
