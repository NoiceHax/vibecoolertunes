---
name: preview
description: Play each notification tone in turn so the user can hear what completion, permission, and question sound like.
disable-model-invocation: true
allowed-tools: Bash
---

# Preview the notification tones

Play each tone once, in this order, announcing each one before you play it.
Leave roughly a second of silence between them.

`CLAUDE_PLUGIN_OPTION_ONLY_WHEN_UNFOCUSED=false` is required on every command
below. Without it nothing plays, because the user is looking at the terminal
right now and that is exactly when the plugin stays quiet.

On macOS or Linux:

```
CLAUDE_PLUGIN_OPTION_ONLY_WHEN_UNFOCUSED=false sh "${CLAUDE_PLUGIN_ROOT}/scripts/play.sh" complete
CLAUDE_PLUGIN_OPTION_ONLY_WHEN_UNFOCUSED=false sh "${CLAUDE_PLUGIN_ROOT}/scripts/play.sh" permission
CLAUDE_PLUGIN_OPTION_ONLY_WHEN_UNFOCUSED=false sh "${CLAUDE_PLUGIN_ROOT}/scripts/play.sh" question
```

On Windows:

```
CLAUDE_PLUGIN_OPTION_ONLY_WHEN_UNFOCUSED=false powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/play.ps1" complete
CLAUDE_PLUGIN_OPTION_ONLY_WHEN_UNFOCUSED=false powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/play.ps1" permission
CLAUDE_PLUGIN_OPTION_ONLY_WHEN_UNFOCUSED=false powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/play.ps1" question
```

Then tell the user what each one means:

- **complete** (E5 to G#5, ascending major third): the turn finished
- **permission** (E5, G#5, B5, an E major arpeggio): a permission prompt is waiting
- **question** (E5, pause, G#5): Claude is waiting on an answer from you

Also remind them that in normal use these only play when the terminal does not
have focus, so they will not hear them while watching this session.

## If the user says nothing played

Re-run one command with `CCTONES_DEBUG=1` also set. The script prints the exact
reason it stayed silent. The usual causes are:

- The terminal had focus and gating was left on
- No audio player installed (Linux: install `pulseaudio-utils` or `alsa-utils`)
- A remote or SSH session, where audio would play on the wrong machine
- A headless environment with no audio device

## Other adjustments

- Descending voicing for questions: set `question_style` to `descending`
- Silence the end-of-turn tone: set `task_complete_tone` to `false`
- Always play regardless of focus: set `only_when_unfocused` to `false`

All three are set via `/plugin`, followed by `/reload-plugins`.
