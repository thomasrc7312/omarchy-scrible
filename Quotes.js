.pragma library

// Bundled locally in quotes.json: ~40 lines of original encouragement plus
// short, attributed writing quotes, and a handful of short reaction lines
// per event. No network calls, ever.

function fallback() {
  return {
    pool: [{ text: "Whatever you wrote today counts.", author: "" }],
    focusStart: ["Focus time."],
    breakStart: ["Rest counts too."],
    wordsLogged: ["Logged."],
    goalReached: ["Goal met."]
  }
}

function arrayOr(value, fallbackArray) {
  return Array.isArray(value) && value.length > 0 ? value : fallbackArray
}

// Tolerates a missing or corrupt file: a small built-in fallback keeps
// Scriby talking rather than leaving the bubble empty or crashing the shell.
function parse(rawText) {
  var fb = fallback()
  if (!rawText || !rawText.trim()) return fb
  var parsed
  try { parsed = JSON.parse(rawText) } catch (e) { return fb }
  if (!parsed || typeof parsed !== "object") return fb

  return {
    pool: arrayOr(parsed.pool, fb.pool),
    focusStart: arrayOr(parsed.focusStart, fb.focusStart),
    breakStart: arrayOr(parsed.breakStart, fb.breakStart),
    wordsLogged: arrayOr(parsed.wordsLogged, fb.wordsLogged),
    goalReached: arrayOr(parsed.goalReached, fb.goalReached)
  }
}

// Pool entries are already {text, author}; the per-event arrays are plain
// strings and need wrapping into the same shape for display.
function randomFrom(arr) {
  if (!arr || arr.length === 0) return null
  return arr[Math.floor(Math.random() * arr.length)]
}

function randomLine(arr) {
  var s = randomFrom(arr)
  return { text: s || "", author: "" }
}

function randomPoolEntry(pool) {
  var entry = randomFrom(pool)
  return entry || { text: "", author: "" }
}
