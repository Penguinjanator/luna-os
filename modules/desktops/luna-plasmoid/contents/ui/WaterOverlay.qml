import QtQuick

// A gentle "liquid glass" shimmer: a few translucent cyan sine-wave bands that
// slowly drift, faking light moving through water over the clear blurred panel.
// Pure Canvas -- Plasma can't sample what's behind the window to do true
// refraction (QtQuick backing-store limit), so this approximates it. Kept very
// subtle, and only animates while the popup is open.
Canvas {
    id: water
    property real phase: 0

    Timer {
        interval: 70                 // ~14 fps drift -- cheap, slow, dreamy
        running: water.visible
        repeat: true
        onTriggered: {
            water.phase += 0.06;
            water.requestPaint();
        }
    }

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        var w = width, h = height;
        for (var b = 0; b < 3; b++) {
            var baseY = h * (0.32 + b * 0.24);
            var amp = 9 + b * 5;
            var freq = 1.4 + b * 0.6;
            ctx.beginPath();
            ctx.moveTo(0, baseY);
            for (var x = 0; x <= w; x += 8) {
                var y = baseY + Math.sin((x / w) * 6.2832 * freq + water.phase + b) * amp;
                ctx.lineTo(x, y);
            }
            ctx.lineTo(w, h);
            ctx.lineTo(0, h);
            ctx.closePath();
            ctx.fillStyle = "rgba(130, 215, 255, " + (0.055 - b * 0.014) + ")";
            ctx.fill();
        }
    }

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
}
