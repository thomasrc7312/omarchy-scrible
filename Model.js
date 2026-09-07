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

function formatCount(n) {
  var s = String(Math.max(0, Math.round(n)))
  var out = ""
  while (s.length > 3) {
    out = "," + s.slice(-3) + out
    s = s.slice(0, -3)
  }
  return s + out
}

function wordsLabel(n) {
  return formatCount(n) + (n === 1 ? " word" : " words")
}

// Monday-start month grid for the date picker: six weeks of seven
// {key, day, inMonth, isToday, isFuture} cells, using the same YYYY-MM-DD
// key as HistoryStore so a cell tap can address a day record directly.
function monthGrid(year, month, todayKey) {
  var firstOfMonth = new Date(year, month, 1)
  var mondayOffset = (firstOfMonth.getDay() + 6) % 7
  var cursor = new Date(year, month, 1 - mondayOffset)
  var weeks = []
  for (var w = 0; w < 6; w++) {
    var days = []
    for (var d = 0; d < 7; d++) {
      var key = cursor.getFullYear() + "-" + pad2(cursor.getMonth() + 1) + "-" + pad2(cursor.getDate())
      days.push({
        key: key,
        day: cursor.getDate(),
        inMonth: cursor.getMonth() === month,
        isToday: key === todayKey,
        isFuture: key > todayKey
      })
      cursor.setDate(cursor.getDate() + 1)
    }
    weeks.push(days)
  }
  return weeks
}
