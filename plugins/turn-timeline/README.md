# Turn Timeline

Claude Code tells you a turn took `3m 21s`. It never tells you *from when to
when*. This adds that.

```
I'll dig into the repo to find what's issuing the redirect.

✻ Started 1:16:54 pm

  … tool calls, more messages …

✻ Baked for 1m 58s
```

One line at the top of the turn, Claude Code's own line at the bottom. Together
they give you the full range.

It also ships `/timeline`, a report over sessions you have already run:

```
  #  started       ended         elapsed    prompt
  1  1:18:07 am    1:19:57 am    1m 49s     I want to make claude code a little…
  2  1:21:08 am    1:24:21 am    3m 13s     here is what i want to see/love, Ta…
  3  1:27:26 am    1:33:45 am    6m 19s     build it as a plugin

  9 turns   1:18:07 am → 3:05:01 am
  working  33m 38s      (31% of wall clock)
  idle     1h 13m 16s
  wall     1h 46m 54s
```

## Install

```
/plugin marketplace add NoiceHax/vibecoolertunes
/plugin install turn-timeline@vibecoolertunes
/reload-plugins
```

Updating later needs `/plugin update turn-timeline@vibecoolertunes`. Plain
`install` is a no-op when any version is already present.

## How the live stamp works

A `MessageDisplay` hook returns `hookSpecificOutput.displayContent`, which
replaces the text **on screen only**. The transcript and Claude's context keep
the original, so this costs **zero tokens per turn**.

That distinction is the whole design. The obvious alternative, a `Stop` hook
that prints the line, does not work: `Stop` stdout is injected into Claude's
context rather than shown to you, so it would burn tokens every turn and you
would never see it.

Turn start comes from a `UserPromptSubmit` hook writing one epoch timestamp to a
small state file. That hook deliberately prints nothing, for the same reason.

## Why one stamp per turn, not per message

`MessageDisplay` fires once per assistant message, and **nothing in its payload
reveals which message will be the turn's last.** A tool-heavy turn produces one
event per narration line, so stamping all of them looks like this:

```
✻ Baked for 5s    from 1:16:54 pm to 1:16:59 pm
✻ Baked for 1m 14s from 1:16:54 pm to 1:18:08 pm
✻ Baked for 1m 33s from 1:16:54 pm to 1:18:26 pm
✻ Baked for 1m 53s from 1:16:54 pm to 1:18:47 pm
```

Every line is correct and the whole thing is unreadable. So the default stamps
only the **first** message of each turn, with the start time, and lets Claude
Code's own closing line supply the duration. Set `stamp_mode` to `every` if you
want per-phase timings back.

## Configuration

Set via `/plugin configure turn-timeline@vibecoolertunes`, then
`/reload-plugins`.

| Option | Default | Effect |
| :--- | :--- | :--- |
| `stamp_mode` | `once` | `once` = one line per turn showing the start. `every` = full range on every assistant message. `off` = no inline stamp, `/timeline` only. |
| `show_duration` | `true` | `every` mode only. Set `false` to drop the duration, which Claude Code prints anyway, and show just the range. |
| `closing_line` | `true` | `every` mode only. Set `false` to drop the flourish. |
| `clock_format` | `12` | Set `24` for `15:06:09`. |

## Requirements

**`node` on your PATH**, on every platform. The stamp is a single Node script
and the hook invokes it directly.

That is a deliberate choice rather than a preference. Claude Code resolves a
hook's command against the real PATH and prints a visible
`Executable not found in $PATH` error every time it misses, on every matching
event. Naming `python3` produced that error on Windows, where it is only a Store
app-execution alias. Naming `sh` produced it too, because Git Bash's
`/usr/bin/sh` exists only inside MSYS's own view and never reaches the PATH
Claude Code spawns with. Exec form, shell form, `shell: bash` and
`shell: powershell` were all measured against a missing binary and all four
error, so there is no form that fails quietly.

A single `node` entry point is the only arrangement that avoids the error on
Windows, macOS and Linux alike.

`/timeline` additionally needs Python 3, but it is a command you run explicitly
rather than a hook, so a missing Python is a plain error rather than noise on
every prompt.

## Failure behaviour

Every failure path exits 0 and prints nothing, which leaves the message
displayed exactly as it would have been. Malformed input, a missing state file,
no Python installed: all produce no stamp rather than a broken one. **A timing
gimmick must never corrupt your actual output.**

The hook is synchronous in the render path and cannot be `async`, because its
output is the point. It has a 5 second timeout.

Both scripts read stdin as UTF-8 explicitly. Decoding it with the console code
page instead silently corrupts every non-ASCII character in the message: an em
dash round-trips to `ΓÇö`, an accented `e` to `├⌐`.

## How /timeline works

No hooks and no state. Claude Code already writes a `system` record with
`subtype: "turn_duration"` carrying the turn's `durationMs` and its end
`timestamp`, so the start is simply end minus duration. That means the report
works **retroactively on interactive sessions you ran before installing this**.

**Headless `claude -p` sessions write no `turn_duration` records**, so the report
has nothing to read for those and says so rather than inventing numbers.

`turn_duration` is an internal transcript detail, not a documented API. If the
format changes the report degrades the same way.

## License

MIT
