import QtQuick
import "Theme.js" as Theme

// "Luna is thinking" — three dots pulsing in a wave. Shown in her bubble until
// the first token of the reply streams in.
Row {
    id: dots
    property color color: Theme.bubbleText
    spacing: 5

    Repeater {
        model: 3
        delegate: Rectangle {
            width: 7
            height: 7
            radius: height / 2
            color: dots.color
            opacity: 0.35

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: dots.visible
                PauseAnimation { duration: index * 180 }
                NumberAnimation { to: 1.0; duration: 300; easing.type: Easing.InOutQuad }
                NumberAnimation { to: 0.35; duration: 300; easing.type: Easing.InOutQuad }
                PauseAnimation { duration: (2 - index) * 180 }
            }
        }
    }
}
