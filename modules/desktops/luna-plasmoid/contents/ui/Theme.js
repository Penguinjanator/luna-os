.pragma library
// Luna's look — frutiger-aero "dark glass". A real frosted-glass panel: the
// Plasma dialog + KWin Blur effect show the desktop through a translucent DARK
// tint (dark enough that light text stays crisp), with glossy aqua / sky-blue /
// fresh-green glass elements floating on it. The palette lives here; the
// translucency + blur come from the Plasma dialog (needs the KWin "Blur" desktop
// effect on — default in KDE — and a translucent Plasma style like Breeze).

// --- aero brights (glass elements + accents) ---
var aqua      = "#5bd6f0";
var sky       = "#4f9eea";
var skyDeep   = "#2e7fd0";
var green      = "#7fd96a";
var greenDeep = "#4fb24a";

// --- panel: translucent DARK tint, so the blur + desktop bleed through ---
var bgTop    = Qt.rgba(0.07, 0.12, 0.21, 0.45);
var bgMid    = Qt.rgba(0.05, 0.09, 0.16, 0.52);
var bgBottom = Qt.rgba(0.03, 0.06, 0.12, 0.58);

// --- glass elements (light translucent on the dark panel) ---
function glass(a) { return Qt.rgba(1, 1, 1, a === undefined ? 0.10 : a); }
var glassFill   = Qt.rgba(1, 1, 1, 0.10);
var glassStrong = Qt.rgba(1, 1, 1, 0.18);
var glassEdge   = Qt.rgba(1, 1, 1, 0.34);   // gloss highlight / hairline border
var glassShadow = Qt.rgba(0, 0, 0, 0.35);

// --- text (light, on the dark glass) ---
var text       = "#eaf3ff";
var textDim    = Qt.rgba(1, 1, 1, 0.62);
var bubbleText = "#ffffff";

// --- chat bubbles (glossy translucent glass) ---
// Luna speaks in aqua->sky; you speak in fresh green.
var lunaTop = Qt.rgba(0.36, 0.84, 0.94, 0.88);
var lunaBot = Qt.rgba(0.18, 0.50, 0.82, 0.88);
var youTop  = Qt.rgba(0.50, 0.85, 0.42, 0.85);
var youBot  = Qt.rgba(0.31, 0.66, 0.29, 0.85);

// --- accent (orb, send button) ---
var accentTop = "#5bd6f0";
var accentBot = "#2e7fd0";

// --- metrics ---
var radius      = 16;
var radiusSmall = 10;
var glow        = 16;
