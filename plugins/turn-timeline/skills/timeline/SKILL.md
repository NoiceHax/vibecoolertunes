---
name: timeline
description: Show when each turn in a Claude Code session actually ran, with start and end times, durations, and a working-versus-idle breakdown.
disable-model-invocation: true
allowed-tools: Bash
---

# Turn timeline

Run the bundled report and show the user its output verbatim in a code block.
Do not reformat the table; it is already aligned.

```
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/timeline.py"
```

If `python3` is not found, retry with `python`. If neither exists, tell the user
this report needs Python 3 and stop; do not attempt to parse the transcript
yourself, because a session transcript can run to thousands of records.

With no argument it reads the most recently modified transcript, which is
normally the current session. To report on a different one, pass its path:

```
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/timeline.py" /path/to/transcript.jsonl
```

Transcripts live under `~/.claude/projects/<encoded-project-path>/<session-id>.jsonl`.
If the user asks about a past session and you need to find it, list that
directory by modification time rather than guessing.

## Reading the output

- **started / ended** are wall-clock times for each turn
- **elapsed** is the turn duration, the same figure Claude Code reports
- **working** is the sum of all turn durations
- **idle** is the remaining wall-clock time: reading, typing, or away

A low working percentage is normal and not a problem worth flagging. Most of a
session is usually the human thinking.

## If it reports no turns

The report reads `system` records with `subtype: "turn_duration"`. A transcript
with none of them is either a session that never completed a turn, or a
transcript written by a Claude Code version that does not emit that record. Say
which of those it is if you can tell, rather than guessing at numbers.
