.pragma library

// Day-record storage for history.json: { version, records: [{date, words,
// focusSessions}, ...] }. Kept in memory as a { "YYYY-MM-DD": {words,
// focusSessions} } map, keyed and rolled over in local time.

function pad2(n) {
  return (n < 10 ? "0" : "") + n
}

function localDateKey(date) {
  var d = date || new Date()
  return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate())
}

var DATE_KEY_RE = /^\d{4}-\d{2}-\d{2}$/

// Tolerates a missing, empty, or corrupt file, and drops any record that
// doesn't look like a valid day, rather than throwing.
function parse(rawText) {
  var byDate = {}
  if (!rawText || !rawText.trim()) return byDate
  var parsed
  try { parsed = JSON.parse(rawText) } catch (e) { return byDate }
  var records = parsed && parsed.records
  if (!Array.isArray(records)) return byDate

  for (var i = 0; i < records.length; i++) {
    var entry = records[i]
    if (!entry || typeof entry !== "object") continue
    var key = String(entry.date || "")
    if (!DATE_KEY_RE.test(key)) continue
    var words = Number(entry.words)
    var sessions = Number(entry.focusSessions)
    byDate[key] = {
      words: isFinite(words) && words > 0 ? Math.round(words) : 0,
      focusSessions: isFinite(sessions) && sessions > 0 ? Math.round(sessions) : 0
    }
  }
  return byDate
}

function serialize(byDate) {
  var keys = Object.keys(byDate).sort()
  var records = []
  for (var i = 0; i < keys.length; i++) {
    var k = keys[i]
    records.push({ date: k, words: byDate[k].words, focusSessions: byDate[k].focusSessions })
  }
  return JSON.stringify({ version: 1, records: records }, null, 2) + "\n"
}

// A day with no record is zero, not missing.
function dayRecord(byDate, key) {
  var entry = byDate[key]
  return entry ? entry : { words: 0, focusSessions: 0 }
}

function withFocusSessionIncrement(byDate, key) {
  var next = {}
  for (var k in byDate) next[k] = byDate[k]
  var current = dayRecord(byDate, key)
  next[key] = { words: current.words, focusSessions: current.focusSessions + 1 }
  return next
}
