import QtQuick
import "../"
import "."

// Minecraft take on SystemUsageCard: an inset inventory slot that fills from the bottom
// with pixel blocks of a material (redstone, lapis, lava, emerald, stone). The top row of
// blocks is ragged and shimmers a little while the value changes.
Item {
    id: card

    property real value: 0.0
    property string material: "stone"
    property string icon: ""
    property string title: ""
    property string valueText: ""
    property string subText: ""
    property bool isLive: true
    property var scaleFunc: null
    function s(v) { return typeof scaleFunc === "function" ? scaleFunc(v) : v; }

    default property alias childItems: extra.data

    readonly property real fill: Math.max(0, Math.min(1, value))
    readonly property int px: Math.max(2, Math.round(s(3)))

    readonly property var materials: ({
        "redstone": ["#7a0a0a", "#a81414", "#d42020", "#ff4a3a"],
        "lapis":    ["#13307a", "#1d46a8", "#2a5fd0", "#5f8fff"],
        "lava":     ["#a83a00", "#d45a00", "#ff8a00", "#ffd040"],
        "emerald":  ["#0a6a2a", "#11903a", "#17b34a", "#5cf08a"],
        "stone":    ["#4a4a4a", "#5e5e5e", "#727272", "#8c8c8c"]
    })
    readonly property var pal: materials[material] || materials["stone"]

    McPanel {
        anchors.fill: parent
        inset: true
        bevel: card.px
        fill: "#1a1a1a"
        light: "#0a0a0a"
        dark: "#4a4a4a"
    }

    // pixel-block fill
    Canvas {
        id: blocks
        x: card.px * 2
        y: card.px * 2
        width: card.width - card.px * 4
        height: card.height - card.px * 4
        antialiasing: false
        property real f: card.fill
        property int phase: 0
        onFChanged: requestPaint()
        onPhaseChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            let ctx = getContext("2d");
            ctx.reset();
            let p = card.px;
            let cols = Math.ceil(width / p), rows = Math.ceil(height / p);
            let level = Math.round(rows * f);
            for (let x = 0; x < cols; x++) {
                // ragged top: +-1 block, shifting with phase
                let jag = ((x * 7 + phase) % 5 === 0) ? 1 : (((x * 3 + phase) % 7 === 0) ? -1 : 0);
                let top = rows - level + (level > 1 && level < rows ? jag : 0);
                for (let y = Math.max(0, top); y < rows; y++) {
                    let n = (x * 31 + y * 17 + (x * y) % 11) % 13;
                    let c = n < 3 ? card.pal[0] : (n < 8 ? card.pal[1] : (n < 11 ? card.pal[2] : card.pal[3]));
                    if (y === top) c = card.pal[3];
                    ctx.fillStyle = c;
                    ctx.fillRect(x * p, y * p, p, p);
                }
            }
        }
    }
    Timer {
        interval: 300
        repeat: true
        running: card.isLive && card.visible && shimmer.running
        onTriggered: blocks.phase = (blocks.phase + 1) % 35
    }
    Timer { id: shimmer; interval: 1800 }
    onValueChanged: if (isLive) shimmer.restart()

    // icon slot
    McPanel {
        id: iconSlot
        x: card.px * 3; y: card.px * 3
        width: card.s(26); height: card.s(26)
        bevel: Math.max(1, card.px - 1)
        fill: "#3a3a3a"; light: "#6a6a6a"; dark: "#161616"
        Text {
            anchors.centerIn: parent
            text: card.icon
            font.family: ThemeBackend.iconFont
            font.pixelSize: card.s(14)
            color: card.pal[3]
        }
    }
    McText {
        anchors.verticalCenter: iconSlot.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: card.px * 3
        text: card.title
        font.pixelSize: card.s(12)
        color: "#e0e0e0"
    }
    McText {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: card.px * 3
        visible: card.subText !== ""
        text: card.subText
        font.pixelSize: card.s(12)
    }
    McText {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: card.px * 3
        text: card.valueText
        font.pixelSize: card.s(22)
        font.bold: true
        color: "#ffffff"
    }

    Item {
        id: extra
        anchors.fill: parent
        anchors.margins: card.px * 3
        z: 10
    }
}
