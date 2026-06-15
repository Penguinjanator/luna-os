.pragma library
// Luna's look — frutiger aero. Glossy and glassy, bright and optimistic: aqua,
// sky-blue and fresh green over a clean light-glass gradient, water-clear
// translucency and white-gloss highlights. (Dialed brighter + calmer than the
// first vaporwave pass — meant to feel like a native glossy panel.)

// --- aero brights ---
var aqua      = "#3fc9f5";
var sky       = "#4f9eea";
var skyDeep   = "#2e7fd0";
var green     = "#7fd96a";
var greenDeep = "#4fb24a";
var white     = "#ffffff";

// --- background: bright sky -> aqua -> mint glass ---
var bgTop    = "#e6f5ff";
var bgMid    = "#d6edfb";
var bgBottom = "#e8f8ef";

// --- glass (Aero gloss: light translucent whites with a cool edge) ---
function glass(a) { return Qt.rgba(1, 1, 1, a === undefined ? 0.42 : a); }
var glassFill   = Qt.rgba(1, 1, 1, 0.42);
var glassStrong = Qt.rgba(1, 1, 1, 0.66);
var glassEdge   = Qt.rgba(1, 1, 1, 0.88);
var glassShadow = Qt.rgba(0.08, 0.32, 0.50, 0.22);

// --- text ---
var text       = "#143a52";                       // deep slate-blue on light glass
var textDim    = Qt.rgba(0.08, 0.23, 0.32, 0.55);
var bubbleText = "#ffffff";                        // on the glossy colored bubbles

// --- chat bubbles (glossy gradients) ---
// Luna speaks in aqua->sky; you speak in fresh green.
var lunaTop = Qt.rgba(0.25, 0.79, 0.96, 0.94);
var lunaBot = Qt.rgba(0.18, 0.55, 0.85, 0.94);
var youTop  = Qt.rgba(0.50, 0.85, 0.42, 0.94);
var youBot  = Qt.rgba(0.31, 0.70, 0.29, 0.94);

// --- accent (orb, send button) ---
var accentTop = "#5bd6f0";
var accentBot = "#2e7fd0";

// --- metrics ---
var radius      = 16;
var radiusSmall = 10;
var glow        = 16;
