.pragma library
// Luna dashboard API client for the plasmoid. Talks to the always-on
// `hermes dashboard` on 127.0.0.1:9119, reusing the session-threaded /api/chat
// and the session endpoints — each chat TAB is one Hermes session.

var BASE = "http://127.0.0.1:9119";
var TOKEN_FILE = "file:///var/lib/hermes/dashboard.env";
var HEADER = "X-Hermes-Session-Token";
var _TOKEN_KEY = "HERMES_DASHBOARD_SESSION_TOKEN=";

// Read the per-machine session token luna-os mints into the dashboard's
// EnvironmentFile (the same file the `luna` CLI falls back to). Synchronous: a
// tiny local file we need before each request. "" if unreadable.
function token() {
    try {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", TOKEN_FILE, false);
        xhr.send();
        var lines = (xhr.responseText || "").split("\n");
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (line.indexOf(_TOKEN_KEY) === 0)
                return line.substring(_TOKEN_KEY.length).trim();
        }
    } catch (e) {}
    return "";
}

function _open(method, path) {
    var xhr = new XMLHttpRequest();
    xhr.open(method, BASE + path);
    var t = token();
    if (t)
        xhr.setRequestHeader(HEADER, t);
    return xhr;
}

function _getJson(path, onResult) {
    var xhr = _open("GET", path);
    xhr.onreadystatechange = function () {
        if (xhr.readyState !== 4)
            return;
        if (xhr.status === 200) {
            try { onResult(JSON.parse(xhr.responseText)); }
            catch (e) { onResult(null); }
        } else {
            onResult(null);
        }
    };
    xhr.send();
}

// GET /api/sessions — recent conversations, to reopen as tabs.
function listSessions(limit, onResult) {
    _getJson("/api/sessions?limit=" + (limit || 20), onResult);
}

// GET /api/sessions/{id}/messages — a tab's history when you reopen it.
function loadMessages(sessionId, onResult) {
    _getJson("/api/sessions/" + encodeURIComponent(sessionId) + "/messages", onResult);
}

// PATCH /api/sessions/{id} — name a tab (e.g. from its first message).
function setTitle(sessionId, title) {
    var xhr = _open("PATCH", "/api/sessions/" + encodeURIComponent(sessionId));
    xhr.setRequestHeader("Content-Type", "application/json");
    xhr.send(JSON.stringify({ "title": title }));
}

// DELETE /api/sessions/{id} — close a conversation for good.
function deleteSession(sessionId, onDone) {
    var xhr = _open("DELETE", "/api/sessions/" + encodeURIComponent(sessionId));
    xhr.onreadystatechange = function () {
        if (xhr.readyState === 4 && onDone)
            onDone(xhr.status === 200);
    };
    xhr.send();
}

// POST /api/chat (SSE). Streams deltas, then resolves the threaded session id.
// sessionId "" starts a fresh conversation — its id arrives via onDone, so the
// tab can keep threading. Falls back gracefully: if the transport buffers
// instead of streaming, onDone still carries the full final text.
function streamChat(message, sessionId, onDelta, onDone, onError) {
    var xhr = _open("POST", "/api/chat");
    xhr.setRequestHeader("Content-Type", "application/json");
    var seen = 0;   // chars of responseText already parsed
    xhr.onreadystatechange = function () {
        if (xhr.readyState >= 3) {
            var buf = xhr.responseText || "";
            while (true) {
                var nl = buf.indexOf("\n", seen);
                if (nl < 0)
                    break;
                var line = buf.substring(seen, nl).trim();
                seen = nl + 1;
                if (line.indexOf("data: ") !== 0)
                    continue;
                var ev;
                try { ev = JSON.parse(line.substring(6)); }
                catch (e) { continue; }
                if (ev.type === "delta" && ev.text)
                    onDelta(ev.text);
                else if (ev.type === "done")
                    onDone(ev.session_id || sessionId, ev.final || "");
                else if (ev.type === "error")
                    onError(ev.error || "unknown error");
            }
        }
        if (xhr.readyState === 4 && xhr.status !== 200)
            onError("HTTP " + xhr.status + " — is the dashboard running?");
    };
    var body = { "message": message };
    if (sessionId)
        body["session_id"] = sessionId;
    xhr.send(JSON.stringify(body));
}
