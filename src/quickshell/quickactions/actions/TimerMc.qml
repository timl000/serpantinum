import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../reusables"
import "../../"
import "../../mc"

Item {
    id: root

    property int requestedLayoutTemplate: 1
    property bool isActiveTab: typeof isCurrentTarget !== "undefined" ? isCurrentTarget : true
    property string iconFont: "Font Awesome 6 Free Solid"
    property string safeActiveEdge: typeof activeEdge !== "undefined" ? activeEdge : "left"

    property bool stateLoaded: false

    function s(val) {
        return typeof scaleFunc === "function" ? scaleFunc(val) : val;
    }

    property real baseW: s(380)
    property real baseL: s(330)

    property real preferredWidth: (root.safeActiveEdge === "bottom" || root.safeActiveEdge === "top") ? baseL + 50 : baseW
    property real preferredExtraLength: (root.safeActiveEdge === "bottom" || root.safeActiveEdge === "top") ? baseW : baseL

    property real counterRotation: {
        if (root.safeActiveEdge === "right") return 180;
        if (root.safeActiveEdge === "bottom") return 90;
        if (root.safeActiveEdge === "top") return -90;
        return 0;
    }

    function alpha(color, a) { return Qt.rgba(color.r, color.g, color.b, a); }

    function getStorageDir() {
        return Quickshell.env("QS_RUN_FOCUSTIME") || ((Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/serpantinum/focustime");
    }

    QtObject {
        id: stateCache

        property int activeMode: 0

        property real timerTargetEpoch: 0
        property int timerRemainingMs: 5 * 60 * 1000
        property int timerPresetMs: 5 * 60 * 1000

        property real swStartEpoch: 0
        property int swAccumulatedMs: 0

        property int pomoState: 0
        property real pomoTargetEpoch: 0
        property int pomoRemainingMs: 25 * 60 * 1000

        property int pomoWorkLimit: 25
        property int pomoShortBreakLimit: 5
        property int pomoLongBreakLimit: 15
        property int pomoTargetSessions: 4
        property int pomoSessionsCount: 0

        onPomoWorkLimitChanged: {
            if (root.stateLoaded && pomoTargetEpoch === 0 && pomoState === 0) {
                pomoRemainingMs = pomoWorkLimit * 60 * 1000;
                root.saveFullState();
            }
        }

        onPomoShortBreakLimitChanged: {
            if (root.stateLoaded && pomoTargetEpoch === 0 && pomoState === 1) {
                pomoRemainingMs = pomoShortBreakLimit * 60 * 1000;
                root.saveFullState();
            }
        }

        onPomoLongBreakLimitChanged: {
            if (root.stateLoaded && pomoTargetEpoch === 0 && pomoState === 2) {
                pomoRemainingMs = pomoLongBreakLimit * 60 * 1000;
                root.saveFullState();
            }
        }
    }

    property var swLapData: []

    Process {
        id: notifyProc
    }

    Process {
        id: saveFullStateProc
    }

    function saveFullState() {
        if (!root.stateLoaded) return;
        let dir = root.getStorageDir();
        let payload = {
            activeMode: stateCache.activeMode,
            timerTargetEpoch: stateCache.timerTargetEpoch,
            timerRemainingMs: stateCache.timerRemainingMs,
            timerPresetMs: stateCache.timerPresetMs,
            swStartEpoch: stateCache.swStartEpoch,
            swAccumulatedMs: stateCache.swAccumulatedMs,
            swLapData: root.swLapData,
            pomoState: stateCache.pomoState,
            pomoTargetEpoch: stateCache.pomoTargetEpoch,
            pomoRemainingMs: stateCache.pomoRemainingMs,
            pomoWorkLimit: stateCache.pomoWorkLimit,
            pomoShortBreakLimit: stateCache.pomoShortBreakLimit,
            pomoLongBreakLimit: stateCache.pomoLongBreakLimit,
            pomoTargetSessions: stateCache.pomoTargetSessions,
            pomoSessionsCount: stateCache.pomoSessionsCount
        };
        let jsonStr = JSON.stringify(payload);
        saveFullStateProc.running = false;
        saveFullStateProc.command = ["bash", "-c", "mkdir -p '" + dir + "' && echo '" + jsonStr.replace(/'/g, "'\\''") + "' > '" + dir + "/saved_state.json'"];
        saveFullStateProc.running = true;
    }

    function restoreState(rawText) {
        let txt = (rawText || "").trim();
        if (txt !== "") {
            try {
                let data = JSON.parse(txt);
                if (data) {
                    if (data.activeMode !== undefined) stateCache.activeMode = data.activeMode;
                    if (data.timerPresetMs !== undefined) stateCache.timerPresetMs = data.timerPresetMs;
                    if (data.pomoWorkLimit !== undefined) stateCache.pomoWorkLimit = data.pomoWorkLimit;
                    if (data.pomoShortBreakLimit !== undefined) stateCache.pomoShortBreakLimit = data.pomoShortBreakLimit;
                    if (data.pomoLongBreakLimit !== undefined) stateCache.pomoLongBreakLimit = data.pomoLongBreakLimit;
                    if (data.pomoTargetSessions !== undefined) stateCache.pomoTargetSessions = data.pomoTargetSessions;
                    if (data.pomoSessionsCount !== undefined) stateCache.pomoSessionsCount = data.pomoSessionsCount;
                    if (data.pomoState !== undefined) stateCache.pomoState = data.pomoState;
                    if (data.swLapData !== undefined && Array.isArray(data.swLapData)) root.swLapData = data.swLapData;
                    if (data.swAccumulatedMs !== undefined) stateCache.swAccumulatedMs = data.swAccumulatedMs;

                    let now = Date.now();

                    if (data.timerTargetEpoch && data.timerTargetEpoch > 0) {
                        if (now >= data.timerTargetEpoch) {
                            stateCache.timerTargetEpoch = 0;
                            stateCache.timerRemainingMs = 0;
                            root.notify(
                                I18n.t("quickactions.timer.notification.timer_finished_title"),
                                I18n.t("quickactions.timer.notification.timer_finished_body", { time: root.formatTime(stateCache.timerPresetMs, false) }),
                                "preferences-system-time"
                            );
                        } else {
                            stateCache.timerTargetEpoch = data.timerTargetEpoch;
                            stateCache.timerRemainingMs = Math.max(0, data.timerTargetEpoch - now);
                        }
                    } else if (data.timerRemainingMs !== undefined) {
                        stateCache.timerRemainingMs = data.timerRemainingMs;
                        stateCache.timerTargetEpoch = 0;
                    }

                    if (data.swStartEpoch && data.swStartEpoch > 0) {
                        stateCache.swStartEpoch = data.swStartEpoch;
                        stopwatchView.currentDisplayMs = stateCache.swAccumulatedMs + (now - data.swStartEpoch);
                    } else {
                        stateCache.swStartEpoch = 0;
                        stopwatchView.currentDisplayMs = stateCache.swAccumulatedMs;
                    }

                    if (data.pomoTargetEpoch && data.pomoTargetEpoch > 0) {
                        if (now >= data.pomoTargetEpoch) {
                            stateCache.pomoTargetEpoch = 0;
                            stateCache.pomoRemainingMs = 0;
                            let phase = stateCache.pomoState;
                            if (phase === 0) {
                                root.notify(
                                    I18n.t("quickactions.timer.notification.focus_complete_title"),
                                    I18n.t("quickactions.timer.notification.focus_complete_body"),
                                    "preferences-system-time"
                                );
                            } else {
                                root.notify(
                                    I18n.t("quickactions.timer.notification.break_over_title"),
                                    I18n.t("quickactions.timer.notification.break_over_body"),
                                    "preferences-system-time"
                                );
                            }
                            pomodoroView.handleSessionComplete();
                        } else {
                            stateCache.pomoTargetEpoch = data.pomoTargetEpoch;
                            stateCache.pomoRemainingMs = Math.max(0, data.pomoTargetEpoch - now);
                        }
                    } else if (data.pomoRemainingMs !== undefined) {
                        stateCache.pomoRemainingMs = data.pomoRemainingMs;
                        stateCache.pomoTargetEpoch = 0;
                    }
                }
            } catch(e) {}
        }
        root.stateLoaded = true;
        root.updateExportedState();
        root.saveFullState();
    }

    Process {
        id: stateInitProc
        command: ["bash", "-c", "STATE_FILE='" + root.getStorageDir() + "/saved_state.json'; if [ -f \"$STATE_FILE\" ]; then cat \"$STATE_FILE\"; fi"]
        stdout: StdioCollector {
            id: stateInitOut
            onStreamFinished: {
                root.restoreState(stateInitOut.text);
            }
        }
    }

    Component.onCompleted: {
        stateInitProc.running = true;
    }

    function updateExportedState() {
        let list = [];

        if (stateCache.timerTargetEpoch > 0) {
            list.push({ icon: "\uF017", time: root.formatTime(stateCache.timerRemainingMs, false), colorType: "mauve" });
        }
        if (stateCache.swStartEpoch > 0) {
            list.push({ icon: "\uF2F2", time: root.formatTime(stopwatchView.currentDisplayMs, false), colorType: "mauve" });
        }
        if (stateCache.pomoTargetEpoch > 0) {
            list.push({ icon: "\uF085", time: root.formatTime(stateCache.pomoRemainingMs, false), colorType: stateCache.pomoState !== 0 ? "green" : "mauve" });
        }

        TimerState.entries = list;
    }

    function notify(title, message, icon) {
        notifyProc.running = false;
        notifyProc.command = ["notify-send", "-a", I18n.t("quickactions.timer.notification.app_name"), "-i", icon, title, message];
        notifyProc.running = true;
    }

    function toggleActiveTabState() {
        if (!root.isActiveTab || root.isEditingTime) return;
        let now = Date.now();

        if (stateCache.activeMode === 0) {
            if (stateCache.timerTargetEpoch > 0) {
                stateCache.timerTargetEpoch = 0;
            } else {
                if (stateCache.timerRemainingMs <= 0) stateCache.timerRemainingMs = stateCache.timerPresetMs;
                stateCache.timerTargetEpoch = now + stateCache.timerRemainingMs;
            }
        } else if (stateCache.activeMode === 1) {
            if (stateCache.swStartEpoch > 0) {
                stateCache.swAccumulatedMs += (now - stateCache.swStartEpoch);
                stateCache.swStartEpoch = 0;
            } else {
                stateCache.swStartEpoch = now;
            }
        } else if (stateCache.activeMode === 2) {
            if (stateCache.pomoTargetEpoch > 0) {
                stateCache.pomoTargetEpoch = 0;
            } else {
                stateCache.pomoTargetEpoch = now + stateCache.pomoRemainingMs;
            }
        }
        root.saveFullState();
        root.updateExportedState();
    }

    property bool isTimerRunning: stateCache.timerTargetEpoch > 0
    property bool isTimerIdle: !isTimerRunning && stateCache.timerRemainingMs === stateCache.timerPresetMs
    property bool isEditingTime: stateSelector.visible && stateSelector.isEditing

    property bool widgetVisible: parent !== null && parent.visible !== undefined ? parent.visible : true
    property bool anyTimerActive: stateCache.timerTargetEpoch > 0 || stateCache.swStartEpoch > 0 || stateCache.pomoTargetEpoch > 0

    onAnyTimerActiveChanged: root.updateExportedState()

    property var interceptedShortcuts: {
        let arr = ["Return", "Enter"];
        if (root.isEditingTime) {
            arr.push("Left", "Right", "Up", "Down");
        } else if (stateCache.activeMode === 0 && isTimerIdle) {
            arr.push("Left", "Right", "Up", "Down");
        }
        return arr;
    }

    Shortcut { enabled: root.isActiveTab && !root.isEditingTime; sequence: "Return"; onActivated: root.toggleActiveTabState() }
    Shortcut { enabled: root.isActiveTab && !root.isEditingTime; sequence: "Enter"; onActivated: root.toggleActiveTabState() }

    function formatTime(ms, includeMs) {
        if (ms < 0) ms = 0;
        let totalSeconds = Math.floor(ms / 1000);
        let hours = Math.floor(totalSeconds / 3600);
        let minutes = Math.floor((totalSeconds % 3600) / 60);
        let seconds = totalSeconds % 60;

        let out = "";
        if (hours > 0) out += hours.toString().padStart(2, '0') + ":";
        out += minutes.toString().padStart(2, '0') + ":" + seconds.toString().padStart(2, '0');

        if (includeMs) {
            let millis = Math.floor((ms % 1000) / 10);
            out += "." + millis.toString().padStart(2, '0');
        }
        return out;
    }

    Item {
        id: orientedRoot
        anchors.centerIn: parent
        width: (root.counterRotation % 180 !== 0) ? parent.height : parent.width
        height: (root.counterRotation % 180 !== 0) ? parent.width : parent.height
        rotation: root.counterRotation
        clip: true

        McPanel {
            anchors.fill: parent
            z: -1
            bevel: 2
            fill: "#1d1d1d"; light: "#4a4a4a"; dark: "#0a0a0a"
        }

        Timer {
            id: globalTicker
            interval: 32
            repeat: true
            running: root.anyTimerActive
            onTriggered: {
                let now = Date.now();

                if (stateCache.timerTargetEpoch > 0) {
                    let rem = stateCache.timerTargetEpoch - now;
                    if (rem <= 0) {
                        stateCache.timerRemainingMs = 0;
                        stateCache.timerTargetEpoch = 0;
                        root.notify(
                            I18n.t("quickactions.timer.notification.timer_finished_title"),
                            I18n.t("quickactions.timer.notification.timer_finished_body", { time: root.formatTime(stateCache.timerPresetMs, false) }),
                            "preferences-system-time"
                        );
                        root.saveFullState();
                    } else {
                        stateCache.timerRemainingMs = rem;
                    }
                }

                if (stateCache.swStartEpoch > 0) {
                    stopwatchView.currentDisplayMs = stateCache.swAccumulatedMs + (now - stateCache.swStartEpoch);
                } else {
                    stopwatchView.currentDisplayMs = stateCache.swAccumulatedMs;
                }

                if (stateCache.pomoTargetEpoch > 0) {
                    let rem = stateCache.pomoTargetEpoch - now;
                    if (rem <= 0) {
                        stateCache.pomoTargetEpoch = 0;
                        stateCache.pomoRemainingMs = 0;

                        let phase = stateCache.pomoState;
                        if (phase === 0) {
                            root.notify(
                                I18n.t("quickactions.timer.notification.focus_complete_title"),
                                I18n.t("quickactions.timer.notification.focus_complete_body"),
                                "preferences-system-time"
                            );
                        } else {
                            root.notify(
                                I18n.t("quickactions.timer.notification.break_over_title"),
                                I18n.t("quickactions.timer.notification.break_over_body"),
                                "preferences-system-time"
                            );
                        }

                        pomodoroView.handleSessionComplete();
                        root.saveFullState();
                    } else {
                        stateCache.pomoRemainingMs = rem;
                    }
                }

                root.updateExportedState();
            }
        }

        Rectangle {
            id: tabBar
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: root.s(12)
            width: root.s(270)
            height: root.s(36)
            color: "transparent"
            z: 10

            McPanel {
                anchors.fill: parent
                inset: true
                bevel: 2
                fill: "#101010"; light: "#050505"; dark: "#3a3a3a"
            }

            Item {
                id: tabActiveHighlight
                y: root.s(2)
                height: root.s(32)
                z: 0

                McPanel {
                    anchors.fill: parent
                    bevel: 2
                    fill: "#7c7c7c"; light: "#c6c6c6"; dark: "#2e2e2e"
                }
                Rectangle { anchors.fill: parent; color: "transparent"; border.width: 2; border.color: "#ffffff" }

                property int prevIdx: 0
                property int curIdx: stateCache.activeMode

                onCurIdxChanged: {
                    if (curIdx > prevIdx) { rightAnim.duration = 200; leftAnim.duration = 350; }
                    else if (curIdx < prevIdx) { leftAnim.duration = 200; rightAnim.duration = 350; }
                    prevIdx = curIdx;
                }

                property real stepSize: (parent.width - root.s(4)) / 3
                property real targetLeft: root.s(2) + (curIdx * stepSize)
                property real targetRight: targetLeft + stepSize

                property real actualLeft: targetLeft
                property real actualRight: targetRight

                Behavior on actualLeft { NumberAnimation { id: leftAnim; duration: 250; easing.type: Easing.OutExpo } }
                Behavior on actualRight { NumberAnimation { id: rightAnim; duration: 250; easing.type: Easing.OutExpo } }

                x: actualLeft
                width: actualRight - actualLeft
            }

            Row {
                anchors.fill: parent
                anchors.margins: root.s(2)
                z: 1

                Repeater {
                    model: [
                        I18n.t("quickactions.timer.tabs.timer"),
                        I18n.t("quickactions.timer.tabs.stopwatch"),
                        I18n.t("quickactions.timer.tabs.pomodoro")
                    ]
                    Item {
                        width: (tabBar.width - root.s(4)) / 3
                        height: parent.height

                        McText {
                            anchors.centerIn: parent
                            text: modelData
                            font.pixelSize: root.s(12)
                            color: stateCache.activeMode === index ? "#ffff55" : "#c0c0c0"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                stateCache.activeMode = index;
                                root.saveFullState();
                            }
                        }
                    }
                }
            }
        }

        Item {
            anchors.top: tabBar.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: root.s(10)

            Item {
                id: standardTimerView
                anchors.fill: parent
                visible: stateCache.activeMode === 0
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 250 } }

                Item {
                    anchors.top: parent.top
                    anchors.bottom: timerControlsRow.top
                    anchors.left: parent.left
                    anchors.right: parent.right

                    McText {
                        id: mcTimerText
                        anchors.centerIn: parent
                        text: root.formatTime(stateCache.timerRemainingMs, false)
                        font.pixelSize: root.s(56)
                        font.bold: true
                        color: stateCache.timerRemainingMs === 0 && !root.isTimerRunning ? "#ffff55" : "#ffffff"
                        visible: !root.isTimerIdle
                    }

                    // XP bar: how much of the timer is left
                    Item {
                        visible: !root.isTimerIdle && stateCache.timerPresetMs > 0
                        anchors.top: mcTimerText.bottom
                        anchors.topMargin: root.s(8)
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.s(240)
                        height: root.s(8)
                        Rectangle { anchors.fill: parent; color: "#000000" }
                        Rectangle {
                            x: 1; y: 1
                            height: parent.height - 2
                            width: (parent.width - 2) * Math.max(0, Math.min(1, stateCache.timerRemainingMs / Math.max(1, stateCache.timerPresetMs)))
                            color: "#7fff20"
                            Rectangle { width: parent.width; height: Math.max(1, parent.height / 3); color: "#c8ff80" }
                        }
                        Repeater {
                            model: 17
                            Rectangle { x: (index + 1) * parent.width / 18; width: 1; height: parent.height; color: "#000000"; opacity: 0.6 }
                        }
                    }

                    TimeSelector {
                        id: stateSelector
                        anchors.centerIn: parent
                        visible: root.isTimerIdle
                        valueMs: stateCache.timerPresetMs
                        isActive: root.isActiveTab && stateCache.activeMode === 0 && root.isTimerIdle
                        isWidgetVisible: root.widgetVisible
                        iconFont: root.iconFont
                        baseColor: "#262626"
                        accentColor: "#7c7c7c"
                        textColor: "#ffffff"
                        subTextColor: "#a0a0a0"
                        borderColor: "#000000"
                        activeTextColor: "#ffff55"
                        cornerRadius: 0
                        scaleMultiplier: 1.4
                        onValueChanged: function(newMs) {
                            stateCache.timerPresetMs = newMs;
                            stateCache.timerRemainingMs = newMs;
                            root.saveFullState();
                        }
                    }
                }

                Item {
                    id: timerControlsRow
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: root.s(10)
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    height: root.s(64)

                    IconButton {
                        mcStyle: true
                        size: root.s(50)
                        cornerRadius: ThemeBackend.borderRadius
                        buttonIcon: "\uF0E2"
                        iconFontSize: root.s(16)
                        accentColor: ThemeBackend.surface0
                        textColor: ThemeBackend.text
                        anchors.right: timerPlayBtn.left
                        anchors.rightMargin: root.s(20)
                        anchors.verticalCenter: timerPlayBtn.verticalCenter
                        onClicked: {
                            if (!root.isTimerIdle) {
                                stateCache.timerTargetEpoch = 0;
                                stateCache.timerRemainingMs = stateCache.timerPresetMs;
                            } else {
                                stateCache.timerPresetMs = 0;
                                stateCache.timerRemainingMs = 0;
                            }
                            root.saveFullState();
                            root.updateExportedState();
                        }
                    }

                    IconButton {
                        mcStyle: true
                        id: timerPlayBtn
                        size: root.s(64)
                        cornerRadius: ThemeBackend.borderRadius
                        buttonIcon: root.isTimerRunning ? "\uF04C" : "\uF04B"
                        iconFontSize: root.s(24)
                        accentColor: ThemeBackend.mauve
                        textColor: ThemeBackend.mantle
                        anchors.centerIn: parent
                        onClicked: root.toggleActiveTabState()
                    }
                }
            }

            Item {
                id: stopwatchView
                anchors.fill: parent
                visible: stateCache.activeMode === 1
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 250 } }

                property bool isRunning: stateCache.swStartEpoch > 0
                property real currentDisplayMs: 0

                Item {
                    id: swContentArea
                    anchors.top: parent.top
                    anchors.bottom: swControlsRow.top
                    anchors.left: parent.left
                    anchors.right: parent.right

                    Column {
                        anchors.centerIn: parent
                        spacing: root.s(15)

                        McText {
                            id: swTimeText
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.formatTime(stopwatchView.currentDisplayMs, true)
                            font.pixelSize: root.s(44)
                            font.bold: true
                            color: "#ffffff"
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: root.s(270)
                            height: root.swLapData.length > 0 ? Math.min(root.s(130), swContentArea.height - swTimeText.height - root.s(15)) : 0
                            visible: root.swLapData.length > 0
                            color: "transparent"
                            clip: true

                            ListView {
                                id: lapList
                                anchors.fill: parent
                                model: root.swLapData.length
                                spacing: root.s(6)

                                delegate: Rectangle {
                                    width: lapList.width
                                    height: root.s(32)
                                    color: "#262626"
                                    border.width: 2
                                    border.color: "#000000"

                                    property int trueIdx: root.swLapData.length - 1 - index
                                    property var lapItem: root.swLapData[trueIdx]

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: root.s(15); anchors.rightMargin: root.s(15)
                                        Text { text: I18n.t("quickactions.timer.stopwatch.lap", { number: trueIdx + 1 }); color: ThemeBackend.subtext0; font.family: ThemeBackend.fontFamily; font.pixelSize: root.s(12); font.bold: true; Layout.fillWidth: true }
                                        Text { text: lapItem ? "+" + root.formatTime(lapItem.diff, true) : ""; color: "#55ff55"; font.family: ThemeBackend.fontFamily; font.pixelSize: root.s(12) }
                                        Text { text: lapItem ? root.formatTime(lapItem.total, true) : ""; color: ThemeBackend.text; font.family: ThemeBackend.fontFamily; font.pixelSize: root.s(12); font.bold: true; Layout.alignment: Qt.AlignRight }
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    id: swControlsRow
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: root.s(10)
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    height: root.s(64)

                    IconButton {
                        mcStyle: true
                        size: root.s(50)
                        cornerRadius: ThemeBackend.borderRadius
                        buttonIcon: stopwatchView.isRunning ? "\uF024" : "\uF0E2"
                        iconFontSize: root.s(16)
                        accentColor: ThemeBackend.surface0
                        textColor: ThemeBackend.text
                        anchors.right: swPlayBtn.left
                        anchors.rightMargin: root.s(20)
                        anchors.verticalCenter: swPlayBtn.verticalCenter
                        onClicked: {
                            if (stopwatchView.isRunning) {
                                let nowMs = stopwatchView.currentDisplayMs;
                                let lastMs = root.swLapData.length > 0 ? root.swLapData[root.swLapData.length - 1].total : 0;
                                let temp = root.swLapData.slice();
                                temp.push({ total: nowMs, diff: nowMs - lastMs });
                                root.swLapData = temp;
                            } else {
                                stateCache.swStartEpoch = 0;
                                stateCache.swAccumulatedMs = 0;
                                root.swLapData = [];
                                stopwatchView.currentDisplayMs = 0;
                            }
                            root.saveFullState();
                            root.updateExportedState();
                        }
                    }

                    IconButton {
                        mcStyle: true
                        id: swPlayBtn
                        size: root.s(64)
                        cornerRadius: ThemeBackend.borderRadius
                        buttonIcon: stopwatchView.isRunning ? "\uF04C" : "\uF04B"
                        iconFontSize: root.s(24)
                        accentColor: ThemeBackend.mauve
                        textColor: ThemeBackend.mantle
                        anchors.centerIn: parent
                        onClicked: root.toggleActiveTabState()
                    }
                }
            }

            Item {
                id: pomodoroView
                anchors.fill: parent
                visible: stateCache.activeMode === 2
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 250 } }

                property bool isRunning: stateCache.pomoTargetEpoch > 0
                property bool showSettings: false

                function getPhaseColor() {
                    if (stateCache.pomoState === 0) return "#ff5555";
                    if (stateCache.pomoState === 1) return "#55ff55";
                    return "#55ffff";
                }

                function getPhaseLabel() {
                    if (stateCache.pomoState === 0) return I18n.t("quickactions.timer.pomodoro.phases.focus");
                    if (stateCache.pomoState === 1) return I18n.t("quickactions.timer.pomodoro.phases.short_break");
                    return I18n.t("quickactions.timer.pomodoro.phases.long_break");
                }

                function handleSessionComplete() {
                    if (stateCache.pomoState === 0) {
                        stateCache.pomoSessionsCount++;
                        if (stateCache.pomoSessionsCount >= stateCache.pomoTargetSessions) {
                            stateCache.pomoState = 2;
                            stateCache.pomoSessionsCount = 0;
                            stateCache.pomoRemainingMs = stateCache.pomoLongBreakLimit * 60 * 1000;
                        } else {
                            stateCache.pomoState = 1;
                            stateCache.pomoRemainingMs = stateCache.pomoShortBreakLimit * 60 * 1000;
                        }
                    } else {
                        stateCache.pomoState = 0;
                        stateCache.pomoRemainingMs = stateCache.pomoWorkLimit * 60 * 1000;
                    }
                    root.saveFullState();
                    root.updateExportedState();
                }

                Item {
                    anchors.top: parent.top
                    anchors.bottom: pomoControlsRow.top
                    anchors.left: parent.left
                    anchors.right: parent.right

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: root.s(10)
                        visible: !pomodoroView.showSettings

                        McText {
                            Layout.alignment: Qt.AlignHCenter
                            text: pomodoroView.getPhaseLabel() + " (" + stateCache.pomoSessionsCount + "/" + stateCache.pomoTargetSessions + ")"
                            font.pixelSize: root.s(14)
                            color: pomodoroView.getPhaseColor()
                        }

                        McText {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.formatTime(stateCache.pomoRemainingMs, false)
                            font.pixelSize: root.s(56)
                            font.bold: true
                            color: "#ffffff"
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: root.s(270)
                        height: root.s(160)
                        color: "transparent"
                        visible: pomodoroView.showSettings

                        McPanel {
                            anchors.fill: parent
                            inset: true
                            bevel: 2
                            fill: "#151515"; light: "#050505"; dark: "#3a3a3a"
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: root.s(12)

                            Repeater {
                                model: [
                                    { label: I18n.t("quickactions.timer.pomodoro.settings.work"), target: "pomoWorkLimit", step: 5, min: 5, max: 60 },
                                    { label: I18n.t("quickactions.timer.pomodoro.settings.short_break"), target: "pomoShortBreakLimit", step: 1, min: 1, max: 15 },
                                    { label: I18n.t("quickactions.timer.pomodoro.settings.long_break"), target: "pomoLongBreakLimit", step: 5, min: 5, max: 45 },
                                    { label: I18n.t("quickactions.timer.pomodoro.settings.sessions"), target: "pomoTargetSessions", step: 1, min: 1, max: 10 }
                                ]
                                RowLayout {
                                    width: root.s(230)
                                    Text { text: modelData.label; color: ThemeBackend.subtext0; font.family: ThemeBackend.fontFamily; font.pixelSize: root.s(12); Layout.fillWidth: true }
                                    IconButton {
                        mcStyle: true
                                        size: root.s(24)
                                        cornerRadius: ThemeBackend.borderRadius
                                        buttonIcon: "-"
                                        iconFontSize: root.s(14)
                                        accentColor: ThemeBackend.surface1
                                        textColor: ThemeBackend.text
                                        onClicked: {
                                            stateCache[modelData.target] = Math.max(modelData.min, stateCache[modelData.target] - modelData.step);
                                            root.saveFullState();
                                        }
                                    }
                                    Text { text: stateCache[modelData.target]; color: ThemeBackend.text; font.family: ThemeBackend.fontFamily; font.bold: true; font.pixelSize: root.s(14); Layout.minimumWidth: root.s(24); horizontalAlignment: Text.AlignHCenter }
                                    IconButton {
                        mcStyle: true
                                        size: root.s(24)
                                        cornerRadius: ThemeBackend.borderRadius
                                        buttonIcon: "+"
                                        iconFontSize: root.s(14)
                                        accentColor: ThemeBackend.surface1
                                        textColor: ThemeBackend.text
                                        onClicked: {
                                            stateCache[modelData.target] = Math.min(modelData.max, stateCache[modelData.target] + modelData.step);
                                            root.saveFullState();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    id: pomoControlsRow
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: root.s(10)
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    height: root.s(64)

                    IconButton {
                        mcStyle: true
                        size: root.s(50)
                        cornerRadius: ThemeBackend.borderRadius
                        buttonIcon: "\uF013"
                        iconFontSize: root.s(16)
                        accentColor: ThemeBackend.surface0
                        textColor: pomodoroView.showSettings ? "#ffff55" : ThemeBackend.text
                        anchors.right: pomoPlayBtn.left
                        anchors.rightMargin: root.s(20)
                        anchors.verticalCenter: pomoPlayBtn.verticalCenter
                        onClicked: pomodoroView.showSettings = !pomodoroView.showSettings
                    }

                    IconButton {
                        mcStyle: true
                        id: pomoPlayBtn
                        size: root.s(64)
                        cornerRadius: ThemeBackend.borderRadius
                        buttonIcon: pomodoroView.isRunning ? "\uF04C" : "\uF04B"
                        iconFontSize: root.s(24)
                        accentColor: pomodoroView.getPhaseColor()
                        textColor: ThemeBackend.mantle
                        anchors.centerIn: parent
                        onClicked: {
                            if (pomodoroView.showSettings) pomodoroView.showSettings = false;
                            root.toggleActiveTabState();
                        }
                    }

                    IconButton {
                        mcStyle: true
                        size: root.s(50)
                        cornerRadius: ThemeBackend.borderRadius
                        buttonIcon: "\uF051"
                        iconFontSize: root.s(16)
                        accentColor: ThemeBackend.surface0
                        textColor: ThemeBackend.text
                        anchors.left: pomoPlayBtn.right
                        anchors.leftMargin: root.s(20)
                        anchors.verticalCenter: pomoPlayBtn.verticalCenter
                        onClicked: {
                            stateCache.pomoTargetEpoch = 0;
                            let phase = stateCache.pomoState;
                            if (phase === 0) {
                                root.notify(
                                    I18n.t("quickactions.timer.notification.pomo_skipped_title"),
                                    I18n.t("quickactions.timer.notification.pomo_skipped_focus_body"),
                                    "media-skip-forward"
                                );
                            } else {
                                root.notify(
                                    I18n.t("quickactions.timer.notification.pomo_skipped_title"),
                                    I18n.t("quickactions.timer.notification.pomo_skipped_break_body"),
                                    "media-skip-forward"
                                );
                            }
                            pomodoroView.handleSessionComplete();
                        }
                    }
                }
            }
        }
    }
}
