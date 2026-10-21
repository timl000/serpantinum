import QtQuick

// Pixel "book and quill" item sprite.
Canvas {
    id: book
    property int px: 2
    property bool quill: true
    width: px * 12
    height: px * 12
    antialiasing: false
    onPxChanged: requestPaint()
    Component.onCompleted: requestPaint()
    readonly property var pal: ({ "B": "#6b3a1e", "b": "#4a2512", "P": "#f3e9c9", "p": "#d6c79a", "F": "#e8e8e8", "f": "#9a9a9a", "k": "#202020" })
    readonly property var sprite: [
        "........FF..",
        ".......FFf..",
        "......FFf...",
        ".BBBBBFf....",
        "BPPPPkfPB...",
        "BPPPkfPPPB..",
        "BPPPPPPPPB..",
        "BpPPPPPPPB..",
        "BbpPPPPPPB..",
        "BbbppppppB..",
        ".bbbbbbbbB..",
        "..BBBBBBB..."
    ]
    onPaint: {
        let ctx = getContext("2d");
        ctx.reset();
        for (let y = 0; y < sprite.length; y++)
            for (let x = 0; x < sprite[y].length; x++) {
                let c = sprite[y][x];
                if (c === "." || (!quill && (c === "F" || c === "f" || c === "k"))) continue;
                ctx.fillStyle = pal[c];
                ctx.fillRect(x * px, y * px, px, px);
            }
    }
}
