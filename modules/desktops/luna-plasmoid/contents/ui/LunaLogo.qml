import QtQuick
import org.kde.kirigami as Kirigami

// Luna's mark: a flat crescent moon. Monochrome so it behaves like a standard
// toolbar icon -- dark on light panels, light on dark -- by following the theme
// text colour. Pass `tint` to override (e.g. the popup header wants it light).
Canvas {
    id: logo
    property color tint: Kirigami.Theme.textColor
    implicitWidth: 22
    implicitHeight: 22

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        var cx = width / 2, cy = height / 2, r = Math.min(width, height) * 0.44;

        // a disc...
        ctx.fillStyle = logo.tint;
        ctx.beginPath();
        ctx.arc(cx, cy, r, 0, 2 * Math.PI);
        ctx.fill();

        // ...minus an offset disc = a clean crescent
        ctx.globalCompositeOperation = "destination-out";
        ctx.beginPath();
        ctx.arc(cx + r * 0.44, cy - r * 0.16, r * 0.88, 0, 2 * Math.PI);
        ctx.fill();
        ctx.globalCompositeOperation = "source-over";
    }

    onTintChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
}
