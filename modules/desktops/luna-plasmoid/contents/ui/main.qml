import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import "Api.js" as Api
import "Theme.js" as Theme

PlasmoidItem {
    id: root
    Plasmoid.title: "Luna"
    preferredRepresentation: compactRepresentation

    // Read the dashboard token once on load. QML's XMLHttpRequest can't read
    // local files, but the Plasma executable engine can -- cat the dashboard's
    // EnvironmentFile and hand the token to Api. Lives at the root (not in the
    // popup) so the token is ready well before the popup is first opened.
    P5Support.DataSource {
        id: tokenReader
        engine: "executable"
        connectedSources: []
        onNewData: function (source, data) {
            disconnectSource(source);
            Api.setToken(Api.parseToken(data["stdout"]));
        }
        Component.onCompleted: connectSource("cat /var/lib/hermes/dashboard.env")
    }

    // --- panel icon: a glossy neon orb ---
    compactRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.iconSizes.medium
        Layout.minimumHeight: Kirigami.Units.iconSizes.medium

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.accentTop }
                GradientStop { position: 1.0; color: Theme.accentBot }
            }
            border.width: 1
            border.color: Theme.glassEdge
            QQC2.Label {
                anchors.centerIn: parent
                text: "L"
                color: "white"
                font.bold: true
                font.pixelSize: parent.height * 0.55
            }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }
    }

    // --- the chat popup: tabs (= sessions) over a vaporwave dusk gradient ---
    fullRepresentation: Item {
        id: chatRoot
        Layout.preferredWidth: 420
        Layout.preferredHeight: 560
        Layout.minimumWidth: 320
        Layout.minimumHeight: 380

        // { title, sessionId } — one entry per open tab.
        ListModel { id: tabsModel }

        function addTab(sessionId, title) {
            tabsModel.append({ "title": title || "New chat", "sessionId": sessionId || "" });
            stack.currentIndex = tabsModel.count - 1;
        }
        function closeTab(i) {
            tabsModel.remove(i);
            if (tabsModel.count === 0)
                addTab("", "New chat");
            else
                stack.currentIndex = Math.min(stack.currentIndex, tabsModel.count - 1);
        }

        Component.onCompleted: addTab("", "New chat")

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.bgTop }
                GradientStop { position: 0.5; color: Theme.bgMid }
                GradientStop { position: 1.0; color: Theme.bgBottom }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            // --- glass tab strip ---
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                ListView {
                    id: tabStrip
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    orientation: ListView.Horizontal
                    clip: true
                    spacing: 4
                    model: tabsModel

                    delegate: Rectangle {
                        height: 28
                        width: Math.min(150, tlabel.implicitWidth + 36)
                        radius: Theme.radiusSmall
                        color: index === stack.currentIndex ? Theme.glassStrong : Theme.glassFill
                        border.width: 1
                        border.color: index === stack.currentIndex ? Theme.glassEdge : "transparent"

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 6
                            spacing: 4
                            QQC2.Label {
                                id: tlabel
                                width: Math.min(implicitWidth, 110)
                                anchors.verticalCenter: parent.verticalCenter
                                text: model.title
                                color: Theme.text
                                elide: Text.ElideRight
                            }
                            QQC2.Label {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "×"
                                color: Theme.textDim
                                MouseArea { anchors.fill: parent; onClicked: chatRoot.closeTab(index) }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            z: -1
                            onClicked: stack.currentIndex = index
                        }
                    }
                }

                // new tab
                Rectangle {
                    width: 28
                    height: 28
                    radius: Theme.radiusSmall
                    color: Theme.glassFill
                    border.width: 1
                    border.color: Theme.glassEdge
                    QQC2.Label {
                        anchors.centerIn: parent
                        text: "+"
                        color: Theme.text
                        font.bold: true
                        font.pixelSize: 18
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: chatRoot.addTab("", "New chat")
                    }
                }
            }

            // --- one ChatTab per open conversation ---
            StackLayout {
                id: stack
                Layout.fillWidth: true
                Layout.fillHeight: true

                Repeater {
                    model: tabsModel
                    delegate: ChatTab {
                        property int tabIndex: index
                        Component.onCompleted: {
                            sessionId = model.sessionId;
                            if (sessionId)
                                loadHistory();
                        }
                        onTitled_: tabsModel.setProperty(tabIndex, "title", title)
                    }
                }
            }
        }
    }
}
