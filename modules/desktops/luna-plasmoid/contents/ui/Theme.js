.pragma library
// Luna's look — frutiger-aero-vaporwave. Glassy translucent panels (Aero gloss)
// floating over a neon dusk gradient (vaporwave). One palette, shared by every
// tab, bubble, and button. Mirrored in the GNOME extension's CSS.

// --- vaporwave neons ---
var pink     = "#ff71ce";
var cyan     = "#05ffd6";
var purple   = "#b967ff";
var blue     = "#4d8aff";
var mint     = "#7bf1a8";
var lavender = "#c8a2ff";

// --- background: deep dusk gradient (indigo -> plum -> teal) ---
var bgTop    = "#1b1033";
var bgMid    = "#3a1d5e";
var bgBottom = "#0e2b3d";

// --- glass (Aero gloss) ---
function glass(a)       { return Qt.rgba(1, 1, 1, a === undefined ? 0.10 : a); }
var glassFill   = Qt.rgba(1, 1, 1, 0.10);
var glassStrong = Qt.rgba(1, 1, 1, 0.18);
var glassEdge   = Qt.rgba(1, 1, 1, 0.38);   // top highlight / hairline borders
var glassShadow = Qt.rgba(0, 0, 0, 0.35);

// --- text ---
var text    = "#f4ecff";
var textDim = Qt.rgba(1, 1, 1, 0.62);

// --- chat bubbles (glassy gradients) ---
// Luna speaks in pink->purple; you speak in cyan->blue.
var lunaTop = Qt.rgba(1.00, 0.44, 0.81, 0.30);
var lunaBot = Qt.rgba(0.73, 0.40, 1.00, 0.30);
var youTop  = Qt.rgba(0.02, 1.00, 0.84, 0.26);
var youBot  = Qt.rgba(0.30, 0.54, 1.00, 0.26);

// --- accent (active tab, send button) ---
var accentTop = "#ff71ce";
var accentBot = "#b967ff";

// --- metrics ---
var radius      = 16;
var radiusSmall = 10;
var glow        = 18;   // soft-glow blur radius for accents
