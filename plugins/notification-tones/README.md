# Notification Tones

Distinct musical tones for each reason Claude Code stops, so you can tell from
another room whether it finished, needs permission, or is waiting on you. Plays
only when the terminal does not have focus.

| Event | Hook | Tone |
| :--- | :--- | :--- |
| Turn finished | `Stop` | E5 → G♯5, ascending major third |
| Permission prompt waiting | `Notification` / `permission_prompt` | E5 → G♯5 → B5, E major arpeggio |
| Waiting on your answer | `Notification` / `idle_prompt` | E5 → pause → G♯5 |

## Install

```
/plugin marketplace add NoiceHax/vibecoolertunes
/plugin install notification-tones@vibecoolertunes
/reload-plugins
/notification-tones:preview
```

## Configuration

Set via `/plugin configure notification-tones@vibecoolertunes`, then
`/reload-plugins`.

| Option | Default | Effect |
| :--- | :--- | :--- |
| `only_when_unfocused` | `true` | Set `false` to play even while you are looking at the terminal. |
| `task_complete_tone` | `true` | Set `false` to drop the end-of-turn tone, which fires on every turn. |
| `question_style` | `ascending-pause` | Set `descending` for G♯5 → E5 instead. |

## Troubleshooting

Set `CCTONES_DEBUG=1` and the scripts print exactly why a tone did or did not
play. On macOS and Linux, `sh scripts/diagnose.sh` produces a full report.

Most common cause of silence: the terminal has focus, which is working as
intended. Run `/notification-tones:preview`, which bypasses focus gating.

---

**Full documentation**, including platform support, focus-detection internals,
sound design, retuning, known limitations, and the open call for macOS and Linux
testing, lives in the [repository README](../../README.md).

## License

MIT
