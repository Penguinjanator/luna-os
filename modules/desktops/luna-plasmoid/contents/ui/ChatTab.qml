import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "Api.js" as Api
import "Theme.js" as Theme

// One conversation = one Hermes session. sessionId is "" for a fresh chat and
// gets filled in the moment the first reply threads a session; from then on
// every turn continues it. loadHistory() repopulates a reopened session.
Item {
    id: tab

    property string sessionId: ""
    property bool busy: false
    property bool titled: false
    signal titled_(string title)   // emitted once, so the tab strip can label it

    ListModel { id: messages }     // { role: "you"|"luna", text: "" }

    function _append(role, text) {
        messages.append({ "role": role, "text": text });
        listView.positionViewAtEnd();
    }

    function loadHistory() {
        if (!sessionId)
            return;
        titled = true;             // reopened sessions already have a title
        Api.loadMessages(sessionId, function (res) {
            if (!res)
                return;
            var arr = res.data || res.messages || res || [];
            messages.clear();
            for (var i = 0; i < arr.length; i++) {
                var m = arr[i];
                var role = m.role === "user" ? "you"
                         : (m.role === "assistant" ? "luna" : "");
                var content = typeof m.content === "string" ? m.content : "";
                if (role && content)
                    messages.append({ "role": role, "text": content });
            }
            listView.positionViewAtEnd();
        });
    }

    function send(text) {
        text = (text || "").trim();
        if (!text || busy)
            return;
        _append("you", text);
        _append("luna", "");       // the bubble we stream into
        var idx = messages.count - 1;
        busy = true;
        Api.streamChat(text, sessionId,
            function (delta) {
                messages.setProperty(idx, "text", messages.get(idx).text + delta);
                listView.positionViewAtEnd();
            },
            function (sid, finalText) {
                if (sid)
                    tab.sessionId = sid;
                if (finalText && !messages.get(idx).text)
                    messages.setProperty(idx, "text", finalText);
                busy = false;
                if (!titled && tab.sessionId) {
                    var t = text.length > 40 ? text.substring(0, 40) + "…" : text;
                    Api.setTitle(tab.sessionId, t);
                    titled = true;
                    tab.titled_(t);
                }
            },
            function (err) {
                messages.setProperty(idx, "text", "⚠ " + err);
                busy = false;
            });
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        // --- conversation ---
        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Kirigami.Units.largeSpacing
            model: messages
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                width: ListView.view.width
                height: bubble.height + Kirigami.Units.smallSpacing
                property bool mine: model.role === "you"
                property bool empty: model.text.length === 0

                Rectangle {
                    id: bubble
                    width: empty ? 56 : Math.min(parent.width * 0.82, label.implicitWidth + 28)
                    height: empty ? 32 : label.implicitHeight + 20
                    radius: Theme.radius
                    anchors.right: mine ? parent.right : undefined
                    anchors.left: mine ? undefined : parent.left
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: mine ? Theme.youTop : Theme.lunaTop }
                        GradientStop { position: 1.0; color: mine ? Theme.youBot : Theme.lunaBot }
                    }

                    // Aero gloss: a soft white sheen across the top half
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        height: parent.height * 0.52
                        radius: parent.radius
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.30) }
                            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
                        }
                    }

                    QQC2.Label {
                        id: label
                        visible: !empty
                        anchors.fill: parent
                        anchors.margins: 10
                        text: model.text
                        color: Theme.bubbleText
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                    }

                    TypingDots {
                        visible: empty
                        anchors.centerIn: parent
                    }
                }
            }
        }

        // --- input row ---
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Rectangle {
                Layout.fillWidth: true
                height: input.implicitHeight + 12
                radius: Theme.radiusSmall
                color: Theme.glassStrong

                QQC2.TextField {
                    id: input
                    anchors.fill: parent
                    anchors.margins: 2
                    leftPadding: 10
                    rightPadding: 10
                    background: null
                    color: Theme.text
                    placeholderText: tab.busy ? "Luna is thinking…" : "Message Luna…"
                    placeholderTextColor: Theme.textDim
                    enabled: !tab.busy
                    onAccepted: { tab.send(text); text = ""; }
                }
            }

            Rectangle {
                width: height
                height: input.implicitHeight + 12
                radius: Theme.radiusSmall
                opacity: tab.busy ? 0.5 : 1.0
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.accentTop }
                    GradientStop { position: 1.0; color: Theme.accentBot }
                }

                // Aero gloss sheen
                Rectangle {
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: parent.height * 0.5
                    radius: parent.radius
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.35) }
                        GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
                    }
                }

                QQC2.Label {
                    anchors.centerIn: parent
                    text: "➤"
                    color: "white"
                    font.bold: true
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: !tab.busy
                    onClicked: { tab.send(input.text); input.text = ""; }
                }
            }
        }
    }
}
