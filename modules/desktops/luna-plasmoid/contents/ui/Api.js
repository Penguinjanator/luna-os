.pragma library
// Luna dashboard API client for the plasmoid. Talks to the always-on
// `hermes dashboard` on 127.0.0.1:9119, reusing the session-threaded /api/chat
// and the session endpoints — each chat TAB is one Hermes session.

var BASE = "http://127.0.0.1:9119";
var HEADER = "X-Hermes-Session-Token";
var TOKEN_ENV_KEY = "HERMES_DASHBOARD_SESSION_TOKEN=";

// The dashboard session token. QML's XMLHttpRequest CAN'T read local files
// (Qt blocks file:// reads unless QML_XHR_ALLOW_FILE_READ=1), so main.qml reads
// the dashboard's EnvironmentFile through the Plasma executable data source and
// hands the token here once at load. parseToken pulls it from the KEY=value file.
var _token = "";
function setToken(t) { _token = t || ""; }
function hasToken() { return _token.length > 0; }
function parseToken(fileContents) {
    var lines = (fileContents || "").split("\n");
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line.indexOf(TOKEN_ENV_KEY) === 0)
            return line.substring(TOKEN_ENV_KEY.length).trim();
    }
    return "";
}

// Fallback token read: pull it straight off disk with a synchronous XHR. Needs
// QML_XHR_ALLOW_FILE_READ=1 in the session (luna-widget.nix sets it); harmless
// if blocked. The Plasma executable data source in main.qml is the primary path
// -- this just covers a session where that engine isn't available.
var TOKEN_FILE = "file:///var/lib/hermes/dashboard.env";
function _ensureToken() {
    if (_token)
        return;
    try {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", TOKEN_FILE, false);
        xhr.send();
        var t = parseToken(xhr.responseText);
        if (t)
            _token = t;
    } catch (e) {}
}

function _open(method, path) {
    _ensureToken();
    var xhr = new XMLHttpRequest();
    xhr.open(method, BASE + path);
    if (_token)
        xhr.setRequestHeader(HEADER, _token);
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
    if (!hasToken()) {
        onError("no dashboard token — couldn't read /var/lib/hermes/dashboard.env");
        return;
    }
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
        if (xhr.readyState === 4 && xhr.status !== 200) {
            if (xhr.status === 401 || xhr.status === 403)
                onError("auth rejected (" + xhr.status + ") — token mismatch");
            else if (xhr.status === 0)
                onError("can't reach the dashboard — is it running?");
            else
                onError("HTTP " + xhr.status);
        }
    };
    var body = { "message": message };
    if (sessionId)
        body["session_id"] = sessionId;
    xhr.send(JSON.stringify(body));
    return xhr;   // the caller keeps it so it can .abort() (the stop button)
}
