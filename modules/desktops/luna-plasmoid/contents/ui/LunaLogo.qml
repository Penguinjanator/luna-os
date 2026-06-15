import QtQuick
import "Theme.js" as Theme

// Luna's mark: a glossy aqua orb with a white crescent moon and an Aero gloss.
// Pure Canvas, so it scales crisply from the panel icon to a header badge.
Canvas {
    id: logo
    implicitWidth: 24
    implicitHeight: 24

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        var w = width, h = height;
        var cx = w / 2, cy = h / 2, r = Math.min(w, h) * 0.46;

        // glossy aqua orb
        ctx.beginPath();
        ctx.arc(cx, cy, r, 0, 2 * Math.PI);
        var orb = ctx.createLinearGradient(0, cy - r, 0, cy + r);
        orb.addColorStop(0, Theme.accentTop);
        orb.addColorStop(1, Theme.accentBot);
        ctx.fillStyle = orb;
        ctx.fill();

        // white crescent moon: a disc with an offset bite removed
        ctx.save();
        ctx.beginPath();
        ctx.arc(cx, cy, r * 0.64, 0, 2 * Math.PI);
        ctx.clip();
        ctx.fillStyle = "#ffffff";
        ctx.fillRect(cx - r, cy - r, 2 * r, 2 * r);
        ctx.globalCompositeOperation = "destination-out";
        ctx.beginPath();
        ctx.arc(cx + r * 0.34, cy - r * 0.14, r * 0.62, 0, 2 * Math.PI);
        ctx.fill();
        ctx.restore();

        // Aero gloss: a soft white highlight up and to the left
        var hg = ctx.createRadialGradient(cx - r * 0.32, cy - r * 0.42, 0,
                                          cx - r * 0.32, cy - r * 0.42, r * 1.05);
        hg.addColorStop(0, "rgba(255,255,255,0.55)");
        hg.addColorStop(1, "rgba(255,255,255,0.0)");
        ctx.beginPath();
        ctx.arc(cx, cy, r, 0, 2 * Math.PI);
        ctx.fillStyle = hg;
        ctx.fill();
    }

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
}
