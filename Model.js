.pragma library

function pad2(n) {
  return (n < 10 ? "0" : "") + n
}

// Monospace bar/panel font already gives fixed-width digits, so a plain
// mm:ss string doesn't jitter as it ticks.
function formatMMSS(totalSeconds) {
  var s = Math.max(0, Math.floor(totalSeconds))
  var m = Math.floor(s / 60)
  var r = s % 60
  return pad2(m) + ":" + pad2(r)
}

function phaseDisplayLabel(phase) {
  if (phase === "focus") return "Focus"
  if (phase === "shortBreak") return "Short break"
  if (phase === "longBreak") return "Long break"
  return "Idle"
}

var VALID_PHASES = ["idle", "focus", "shortBreak", "longBreak"]
var VALID_PENDING = ["", "short", "long"]

function defaultTimerState() {
  return {
    phase: "idle",
    endEpochMs: 0,
    focusSessionsSinceLongBreak: 0,
    pendingBreakType: "",
    suppressingNotifications: false
  }
}

// Tolerates a missing, empty, or corrupt file: anything that doesn't parse
// or doesn't look like a valid state degrades to a fresh idle state rather
// than throwing.
function parseTimerState(rawText) {
  var fallback = defaultTimerState()
  if (!rawText || !rawText.trim()) return fallback
  var parsed
  try { parsed = JSON.parse(rawText) } catch (e) { return fallback }
  if (!parsed || typeof parsed !== "object") return fallback

  var phase = VALID_PHASES.indexOf(parsed.phase) !== -1 ? parsed.phase : "idle"
  var endEpochMs = Number(parsed.endEpochMs)
  if (!isFinite(endEpochMs) || endEpochMs < 0) endEpochMs = 0
  var sinceLongBreak = Number(parsed.focusSessionsSinceLongBreak)
  if (!isFinite(sinceLongBreak) || sinceLongBreak < 0) sinceLongBreak = 0
  var pendingBreakType = VALID_PENDING.indexOf(parsed.pendingBreakType) !== -1 ? parsed.pendingBreakType : ""

  return {
    phase: phase,
    endEpochMs: endEpochMs,
    focusSessionsSinceLongBreak: Math.round(sinceLongBreak),
    pendingBreakType: pendingBreakType,
    suppressingNotifications: parsed.suppressingNotifications === true
  }
}

function serializeTimerState(state) {
  return JSON.stringify({
    version: 1,
    phase: state.phase,
    endEpochMs: state.endEpochMs,
    focusSessionsSinceLongBreak: state.focusSessionsSinceLongBreak,
    pendingBreakType: state.pendingBreakType,
    suppressingNotifications: state.suppressingNotifications
  }, null, 2) + "\n"
}
