# Turn Timeline

Claude Code tells you a turn took `3m 21s`. It never tells you *from when to
when*. This adds that.

```
Here is my answer.

✻ Baked for 3m 21s from 3:06:09 am to 3:09:30 am · still warm
✻ Baked for 3m 21s
```

The second line is Claude Code's own. See [Two lines, not one](#two-lines-not-one).

It also ships `/timeline`, a report over any session you have already run:

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

## Two lines, not one

Claude Code's own `✻ Baked for 3m 21s` still renders below the stamp and cannot
be suppressed. So by default you see the duration twice.

The two are also measured at slightly different moments. This stamp is written
when the final assistant message is displayed; Claude Code's is computed at turn
end, marginally later. They can disagree by a second.

Set `show_duration` to `false` for a line that complements rather than repeats:

```
✻ 3:06:09 am to 3:09:30 am · still warm
✻ Baked for 3m 21s
```

## One stamp per assistant message

The hook fires once per assistant message, not once per turn and not per
streaming chunk. A turn with six tool calls produces six stamps, each showing
the turn start and that message's finish time.

There is no way to know at display time which message will be the turn's last,
so this is not avoidable. Read them as phase timings: the last one, sitting
directly above Claude Code's line, is the one that describes the whole turn.

## Configuration

Set via `/plugin configure turn-timeline@vibecoolertunes`, then
`/reload-plugins`.

| Option | Default | Effect |
| :--- | :--- | :--- |
| `show_duration` | `true` | Set `false` to drop the duplicated duration and show only the range. |
| `closing_line` | `true` | Set `false` to drop the flourish. |
| `clock_format` | `12` | Set `24` for `15:06:09`. |

## Requirements

| Platform | Runtime | Notes |
| :--- | :--- | :--- |
| macOS, Linux | `python3` | Usually preinstalled |
| Windows | PowerShell | Built in |

Both hook entries register on every platform and each script exits immediately
on the other one, so exactly one ever produces output. If neither runtime is
available the stamp is skipped and your message displays normally.

`/timeline` needs Python 3 on all platforms, including Windows.

## Failure behaviour

Every failure path exits 0 and prints nothing, which leaves the message
displayed exactly as it would have been. Malformed input, a missing state file,
an unreadable clock: all produce no stamp rather than a broken one. **A timing
gimmick must never corrupt your actual output.**

The hook is synchronous in the render path and cannot be `async`, because its
output is the point. It has a 5 second timeout. Cost is roughly 150 ms per
message on Windows, near zero on macOS and Linux.

## How /timeline works

No hooks and no state. Claude Code already writes a `system` record with
`subtype: "turn_duration"` carrying the turn's `durationMs` and its end
`timestamp`, so the start is simply end minus duration. That means the report
works **retroactively on every session you have ever run**, including ones from
before you installed this.

`turn_duration` is an internal transcript detail, not a documented API. If the
format changes the report prints "no turn_duration records" rather than
inventing numbers.

## License

MIT
