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

// Manual logging is additive: each entry adds to the day's running total.
function withWordsAdded(byDate, key, amount) {
  var next = {}
  for (var k in byDate) next[k] = byDate[k]
  var current = dayRecord(byDate, key)
  next[key] = { words: Math.max(0, current.words + amount), focusSessions: current.focusSessions }
  return next
}

// Editing a day (from the chart or the date picker) replaces its total.
function withWordsSet(byDate, key, amount) {
  var next = {}
  for (var k in byDate) next[k] = byDate[k]
  var current = dayRecord(byDate, key)
  next[key] = { words: Math.max(0, amount), focusSessions: current.focusSessions }
  return next
}

// ---- Chart bucketing --------------------------------------------------
// All local time throughout; weeks start Monday.

function startOfLocalDay(date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate())
}

function addDays(date, n) {
  var d = startOfLocalDay(date)
  d.setDate(d.getDate() + n)
  return d
}

function mondayOnOrBefore(date) {
  var d = startOfLocalDay(date)
  var dow = d.getDay() // 0 = Sunday .. 6 = Saturday
  return addDays(d, -((dow + 6) % 7))
}

function sumWordsInRange(byDate, startDate, endDate) {
  var sum = 0
  var cur = startOfLocalDay(startDate)
  var end = startOfLocalDay(endDate)
  while (cur.getTime() <= end.getTime()) {
    sum += dayRecord(byDate, localDateKey(cur)).words
    cur = addDays(cur, 1)
  }
  return sum
}

var MONTH_SHORT = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
var MONTH_FULL = ["January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December"]

function formatDayLabel(d) {
  return MONTH_SHORT[d.getMonth()] + " " + d.getDate() + ", " + d.getFullYear()
}

function formatWeekLabel(monday, sunday) {
  if (monday.getMonth() === sunday.getMonth())
    return MONTH_SHORT[monday.getMonth()] + " " + monday.getDate() + "–" + sunday.getDate() + ", " + sunday.getFullYear()
  return MONTH_SHORT[monday.getMonth()] + " " + monday.getDate() + " – "
    + MONTH_SHORT[sunday.getMonth()] + " " + sunday.getDate() + ", " + sunday.getFullYear()
}

function formatMonthLabel(d) {
  return MONTH_FULL[d.getMonth()] + " " + d.getFullYear()
}

// One bucket per day: the last `count` days ending today.
function dayBuckets(byDate, today, count) {
  var todayKey = localDateKey(today)
  var start = addDays(today, -(count - 1))
  var buckets = []
  for (var i = 0; i < count; i++) {
    var d = addDays(start, i)
    var key = localDateKey(d)
    buckets.push({
      key: key,
      value: dayRecord(byDate, key).words,
      isCurrent: key === todayKey,
      rangeLabel: formatDayLabel(d)
    })
  }
  return buckets
}

// One bucket per Monday-start week: the last `count` weeks, current week
// (however incomplete) included.
function weekBuckets(byDate, today, count) {
  var currentMonday = mondayOnOrBefore(today)
  var startMonday = addDays(currentMonday, -7 * (count - 1))
  var buckets = []
  for (var i = 0; i < count; i++) {
    var monday = addDays(startMonday, 7 * i)
    var sunday = addDays(monday, 6)
    buckets.push({
      key: localDateKey(monday),
      value: sumWordsInRange(byDate, monday, sunday),
      isCurrent: monday.getTime() === currentMonday.getTime(),
      rangeLabel: formatWeekLabel(monday, sunday)
    })
  }
  return buckets
}

// One bucket per calendar month: the last `count` months, current month
// included.
function monthBuckets(byDate, today, count) {
  var y = today.getFullYear(), m = today.getMonth()
  var buckets = []
  for (var i = count - 1; i >= 0; i--) {
    var d = new Date(y, m - i, 1)
    var monthStart = new Date(d.getFullYear(), d.getMonth(), 1)
    var monthEnd = new Date(d.getFullYear(), d.getMonth() + 1, 0)
    buckets.push({
      key: d.getFullYear() + "-" + pad2(d.getMonth() + 1),
      value: sumWordsInRange(byDate, monthStart, monthEnd),
      isCurrent: d.getFullYear() === y && d.getMonth() === m,
      rangeLabel: formatMonthLabel(d)
    })
  }
  return buckets
}

// One bucket per calendar year found in the store, plus the current year —
// so a fresh install still shows a (zero) bucket for this year.
function yearBuckets(byDate, today) {
  var years = {}
  for (var key in byDate) {
    var y = parseInt(key.substring(0, 4), 10)
    if (isFinite(y)) years[y] = true
  }
  years[today.getFullYear()] = true

  var sorted = Object.keys(years).map(Number).sort(function(a, b) { return a - b })
  var buckets = []
  for (var i = 0; i < sorted.length; i++) {
    var y = sorted[i]
    buckets.push({
      key: String(y),
      value: sumWordsInRange(byDate, new Date(y, 0, 1), new Date(y, 11, 31)),
      isCurrent: y === today.getFullYear(),
      rangeLabel: String(y)
    })
  }
  return buckets
}
