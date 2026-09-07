import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "HistoryStore.js" as HistoryStore

// The bar pill: mm:ss while a focus/break interval is running, today's
// logged word count when idle. Click opens the panel below it. Also owns
// the Pomodoro state machine and the day-record history, since this is the
// one instance guaranteed to be mounted for the plugin's whole lifetime;
// Panel.qml reads and drives it through `hostWidget`.
BarWidget {
  id: root
  moduleName: "trc.scrible"

  readonly property int focusMinutes: setting("focusMinutes", 25)
  readonly property int shortBreakMinutes: setting("shortBreakMinutes", 5)
  readonly property int longBreakMinutes: setting("longBreakMinutes", 30)
  readonly property int sessionsUntilLongBreak: setting("sessionsUntilLongBreak", 4)
  readonly property bool autoStartBreaks: !!setting("autoStartBreaks", false)

  readonly property string stateDir: (Quickshell.env("HOME") || "") + "/.local/state/scrible/"

  readonly property var notificationService: bar && bar.shell && typeof bar.shell.firstPartyServiceFor === "function"
    ? bar.shell.firstPartyServiceFor("omarchy.notifications") : null

  // ---- Timer machine ---------------------------------------------------
  property string phase: "idle"            // idle | focus | shortBreak | longBreak
  property double endEpochMs: 0
  property int focusSessionsSinceLongBreak: 0
  property string pendingBreakType: ""     // "" | "short" | "long"
  property bool suppressingNotifications: false
  property double nowMs: Date.now()
  property bool timerStateLoaded: false

  // Scriby's cue: Panel.qml watches lastEventSeq (not lastEventKind alone,
  // since the same kind can legitimately repeat back to back) to know when
  // to react. Not persisted -- purely a live nudge, nothing to resume.
  property string lastEventKind: "" // "focusStart" | "focusComplete" | "breakStart"
  property int lastEventSeq: 0
  function emitEvent(kind) {
    root.lastEventKind = kind
    root.lastEventSeq += 1
  }

  readonly property bool timerRunning: phase !== "idle"
  readonly property int remainingSeconds: timerRunning ? Math.max(0, Math.ceil((endEpochMs - nowMs) / 1000)) : 0
  readonly property string timerRemainingLabel: Model.formatMMSS(remainingSeconds)
  readonly property string phaseLabel: Model.phaseDisplayLabel(phase)

  // What the big readout shows before anything is running: a preview of
  // the interval that Start would begin (the pending break's length once
  // a focus session has just finished, otherwise the next focus length).
  readonly property int previewMinutes: pendingBreakType === "long" ? longBreakMinutes
    : pendingBreakType === "short" ? shortBreakMinutes
    : focusMinutes
  readonly property string timerReadoutLabel: timerRunning ? timerRemainingLabel : Model.formatMMSS(previewMinutes * 60)

  function setDoNotDisturb(value) {
    if (root.notificationService && typeof root.notificationService.setDoNotDisturb === "function")
      root.notificationService.setDoNotDisturb(value)
    root.suppressingNotifications = value
  }

  readonly property bool notificationsAlreadyMuted: root.notificationService
    ? root.notificationService.doNotDisturb === true : false

  // Only takes ownership of DND when it finds it off. If the user already
  // had DND on for their own reasons, Scrible leaves it alone in both
  // directions: it won't flip it on-record as "ours" and won't switch it
  // off underneath the user when the focus session ends.
  function beginFocusSuppression() {
    if (!root.notificationsAlreadyMuted) root.setDoNotDisturb(true)
  }

  function endFocusSuppression() {
    if (root.suppressingNotifications) root.setDoNotDisturb(false)
  }

  function decideNextBreakType() {
    return (root.focusSessionsSinceLongBreak + 1) >= root.sessionsUntilLongBreak ? "long" : "short"
  }

  function startFocus() {
    if (root.phase !== "idle") return
    root.nowMs = Date.now()
    root.phase = "focus"
    root.endEpochMs = root.nowMs + root.focusMinutes * 60000
    root.pendingBreakType = ""
    root.beginFocusSuppression()
    root.persistTimerState()
    root.emitEvent("focusStart")
  }

  function startBreak(kind) {
    root.nowMs = Date.now()
    root.phase = kind === "long" ? "longBreak" : "shortBreak"
    root.endEpochMs = root.nowMs + (kind === "long" ? root.longBreakMinutes : root.shortBreakMinutes) * 60000
    root.pendingBreakType = ""
    root.persistTimerState()
    root.emitEvent("breakStart")
  }

  // Also used for "skip break": both just abandon the running interval
  // without crediting it.
  function cancelCurrent() {
    if (root.phase === "focus") root.endFocusSuppression()
    root.phase = "idle"
    root.endEpochMs = 0
    root.persistTimerState()
  }

  function dismissPendingBreak() {
    root.pendingBreakType = ""
    root.persistTimerState()
  }

  function completeFocus() {
    root.endFocusSuppression()
    // Emitted before the history write below: Panel's focus-complete
    // reaction (a pool rotation) and a goal-just-reached reaction (fired
    // synchronously off the history change, if this session happens to
    // cross the goal) can coincide, and the goal reaction -- being the
    // more specific, visibly-distinct one -- should win as the message
    // left on screen, not get clobbered by the rotation a moment later.
    root.emitEvent("focusComplete")
    root.recordFocusSessionCompleted()

    var nextType = root.decideNextBreakType()
    root.focusSessionsSinceLongBreak = nextType === "long" ? 0 : root.focusSessionsSinceLongBreak + 1
    root.phase = "idle"
    root.endEpochMs = 0

    if (root.autoStartBreaks) root.startBreak(nextType)
    else {
      root.pendingBreakType = nextType
      root.persistTimerState()
    }
  }

  function completeBreak() {
    root.phase = "idle"
    root.endEpochMs = 0
    root.persistTimerState()
  }

  function loadTimerState(rawText) {
    // FileView's onLoaded can fire more than once during startup; the
    // resume decision below has side effects (DND), so it must run once.
    if (root.timerStateLoaded) return
    var state = Model.parseTimerState(rawText)
    root.focusSessionsSinceLongBreak = state.focusSessionsSinceLongBreak
    root.pendingBreakType = state.pendingBreakType
    root.nowMs = Date.now()

    var canResume = state.phase !== "idle" && state.endEpochMs > root.nowMs
    if (canResume) {
      // A genuine resume across a mere process restart: the interval is
      // still running, so pick up exactly where the last run left off,
      // suppression ownership included — trusting the persisted flag
      // directly rather than re-deriving it from the live DND state, since
      // DND being on right now may be *because* this is what we set it to
      // before the restart.
      root.phase = state.phase
      root.endEpochMs = state.endEpochMs
      root.suppressingNotifications = state.suppressingNotifications
      if (state.phase === "focus" && state.suppressingNotifications
          && root.notificationService && typeof root.notificationService.setDoNotDisturb === "function")
        root.notificationService.setDoNotDisturb(true)
    } else {
      // Either idle, or a phase whose interval fully elapsed while the shell
      // was down. An elapsed focus session is not retroactively credited —
      // there is no way to know the user was actually at the keyboard for
      // it — so this just goes idle cleanly. Fail-safe: if Scrible owned an
      // active suppression when this was last written, that ownership ended
      // with the interval — clear it unconditionally so a crash (or a
      // cancel that never got to run) can never leave notifications
      // silently muted.
      if (state.suppressingNotifications) root.setDoNotDisturb(false)
      root.phase = "idle"
      root.endEpochMs = 0
    }

    root.timerStateLoaded = true
    root.persistTimerState()
  }

  function persistTimerState() {
    if (!root.timerStateLoaded) return
    timerStateFile.setText(Model.serializeTimerState({
      phase: root.phase,
      endEpochMs: root.endEpochMs,
      focusSessionsSinceLongBreak: root.focusSessionsSinceLongBreak,
      pendingBreakType: root.pendingBreakType,
      suppressingNotifications: root.suppressingNotifications
    }))
  }

  // ---- History (day records) -------------------------------------------
  property var historyByDate: ({})
  readonly property string todayKey: HistoryStore.localDateKey(new Date())
  readonly property var todayRecord: HistoryStore.dayRecord(historyByDate, todayKey)
  readonly property int todayWordCount: todayRecord.words
  readonly property int todayFocusSessions: todayRecord.focusSessions

  function loadHistory(rawText) {
    root.historyByDate = HistoryStore.parse(rawText)
  }

  function recordFocusSessionCompleted() {
    var next = HistoryStore.withFocusSessionIncrement(root.historyByDate, root.todayKey)
    historyFile.setText(HistoryStore.serialize(next))
    root.historyByDate = next
  }

  // Manual logging only: additive to today's running total.
  function addWordsToday(amount) {
    if (!(amount > 0)) return
    var next = HistoryStore.withWordsAdded(root.historyByDate, root.todayKey, amount)
    historyFile.setText(HistoryStore.serialize(next))
    root.historyByDate = next
  }

  // Editing any day (past or today) from the chart or the date picker
  // replaces its total outright rather than adding to it.
  function setWordsForDate(dateKey, amount) {
    var next = HistoryStore.withWordsSet(root.historyByDate, dateKey, amount)
    historyFile.setText(HistoryStore.serialize(next))
    root.historyByDate = next
  }

  readonly property string wordCountLabel: Model.wordsLabel(todayWordCount)
  readonly property string displayText: timerRunning
    ? timerRemainingLabel
    : (vertical ? String(todayWordCount) : wordCountLabel)

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Component.onCompleted: {
    ensureStateDirProc.running = true
    Qt.callLater(function() {
      timerStateFile.reload()
      historyFile.reload()
    })
  }

  // Covers "disabled": a shell restart never gets a destruction pass over
  // the old tree, so that path relies on the load-time fail-safe above, but
  // disabling the plugin while the shell keeps running does tear this item
  // down — so that path has to restore here, immediately, itself.
  Component.onDestruction: {
    if (root.phase === "focus") root.endFocusSuppression()
  }

  Process {
    id: ensureStateDirProc
    command: ["mkdir", "-p", root.stateDir]
  }

  // atomicWrites gives the required temp-file-then-rename write; onLoaded
  // only fires once the read has actually completed, so state is decoded
  // from real content rather than racing an in-flight async read (which
  // would otherwise read back empty and immediately persist a bogus reset).
  FileView {
    id: timerStateFile
    path: root.stateDir + "timer.json"
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadTimerState(text())
    onLoadFailed: root.loadTimerState("")
  }

  FileView {
    id: historyFile
    path: root.stateDir + "history.json"
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadHistory(text())
    onLoadFailed: root.loadHistory("")
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.timerRunning
    onTriggered: {
      root.nowMs = Date.now()
      if (root.remainingSeconds > 0) return
      if (root.phase === "focus") root.completeFocus()
      else if (root.phase === "shortBreak" || root.phase === "longBreak") root.completeBreak()
    }
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "trc.scrible"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.displayText
    fontSize: root.vertical ? Style.font.bodySmall : Style.font.body
    tooltipText: "Scrible"
    horizontalMargin: 8.5

    onPressed: function(b) { root.togglePanel() }
  }
}
