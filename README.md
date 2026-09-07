# Scrible

A writing companion for novel drafting, built as an [Omarchy shell](https://github.com/basecamp/omarchy) plugin (`trc.scrible`). Three things live behind one bar pill:

- A **Pomodoro timer** — focus / short break / long break, with a long break every few completed focus sessions.
- A **manual word tracker** with a hand-drawn chart (Day / Week / Month / Year) and a single optional daily goal.
- **Scriby**, a small living-quill mascot who rotates between encouragement and short writing quotes, and reacts (visibly, when it matters) to what you're doing.

The bar pill shows a countdown while the timer is running, and today's word count when it's idle. Click it to open the panel.

## Install

If you push this repo to your own git remote:

```
omarchy plugin add <your-repo-url> --enable --yes
```

Or install it by hand — this is exactly what already sitting in `~/.config/omarchy/plugins/trc.scrible/` amounts to:

```
omarchy-shell shell rescanPlugins
omarchy plugin enable trc.scrible
```

Either way, plugins land disabled by default so you can read the code first; only `enable` turns it on.

## Using it

**Timer** — "Start focus" begins a session. A session only counts as completed if the full interval elapses; cancelling never credits it. When a focus session finishes, a break is offered (short, or long once you've hit the configured number of focus sessions) — it waits for you to start it unless you turn on automatic breaks. Notifications are silenced for the duration of a focus session through the shell's own notification service, but only if Scrible is the one that turned them off; if you'd already set Do Not Disturb yourself, it's left alone in both directions. It's restored the moment a focus session ends, is cancelled, or the plugin is disabled, and a crash or shell restart can never leave it stuck muted.

**Words** — log words as you go with the numeric field; each entry adds to the day's running total, so logging twice in one day just adds up. To correct a past (or today's) total outright, click its bar in the Day view of the chart, or use "Edit a different day…" to open a small date picker. The chart's bucket view (Day/Week/Month/Year) and your goal settings persist between sessions.

**Goal** — optional, one per day: a word count or a completed-session count. Shown as a slim progress bar under the word count. Scriby notices when you hit it; missing it, or having a zero day, gets no comment — there's no streak to keep.

## Settings

Configured under **Setup › Plugins**, or by editing the widget's entry in `~/.config/omarchy/shell.json`.

| Setting | Type | Default | Notes |
|---|---|---|---|
| Focus length (minutes) | integer | 25 | |
| Short break length (minutes) | integer | 5 | |
| Long break length (minutes) | integer | 30 | |
| Focus sessions before a long break | integer | 4 | |
| Start breaks automatically | boolean | off | When off, breaks wait for you to start them. |
| Daily goal | enum: None / Words / Sessions | None | Compares against today's logged words or today's completed focus sessions. |
| Daily goal target | integer | 500 | |

## Data

- `~/.local/state/scrible/timer.json` — timer/session machine state (not user-facing; resumes the timer across a shell restart).
- `~/.local/state/scrible/history.json` — one record per day: `{date, words, focusSessions}`. This is your word-count history.

Both files are plain JSON and written atomically (temp file, then rename), so a crash mid-write can't corrupt them. A corrupt or missing file is treated as empty rather than crashing the shell.

## Scriby & quotes.json

Scriby is an original flat SVG silhouette (`scriby.svg`) — a quill shape with two cut-out "eyes" that let the panel's own background show through, colorized to the active theme's accent color at render time. `quotes.json` bundles the lines it draws from: about forty original encouragement lines plus short, attributed lines from long-established writers on the craft of writing, plus a handful of short reactions each for starting a focus session, starting a break, logging words, and reaching your goal. Nothing here calls out to the network, ever.

## Dependencies

None beyond what `omarchy-shell` already provides: Qt/QML, the shell's own `qs.Commons` / `qs.Ui` modules, and Qt6's built-in `QtQuick.Effects` (used to recolor Scriby to the theme's accent — it ships with Qt6 itself, not a separate package).
