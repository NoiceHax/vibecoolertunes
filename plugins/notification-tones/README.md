# Notification Tones

Claude Code already knows *why* it stopped. This plugin makes that audible.

The problem it solves is not "I want a beep". It is that a single undifferentiated
alert tells you something happened but not whether it is worth walking back to the
keyboard. Three sounds, three meanings, learnable in about a day:

| Event | Hook | Tone | Reads as |
| :--- | :--- | :--- | :--- |
| Turn finished | `Stop` | E5 → G♯5, ascending major third | resolved, done |
| Permission prompt waiting | `Notification` / `permission_prompt` | E5 → G♯5 → B5, E major arpeggio | an invitation, opens upward |
| Waiting on your answer | `Notification` / `idle_prompt` | E5 → pause → G♯5 | "your turn" |

All three share the same root, so they sound like one family rather than three
unrelated alerts. Tones are sine fundamentals with two fast-decaying partials and
a 7 ms attack and release ramp, which gives a struck-glass character instead of a
square-wave beep. Peak amplitude is normalised to 0.55, deliberately quiet.

## Install

```
/plugin marketplace add NoiceHax/vibecoolertunes
/plugin install notification-tones@vibecoolertunes
/reload-plugins
```

Then preview them:

```
/notification-tones:preview
```

## Only when you are not looking

By default a tone plays **only when the terminal does not have focus.** If you
are watching the session you can already see what happened, and a chime for
something on screen in front of you is noise.

Focus is resolved differently per platform, and the rule everywhere is that
**undetermined focus counts as unfocused, so the tone plays.** A missed
notification is worse than one you did not need.

| Platform | Method | Precision |
| :--- | :--- | :--- |
| macOS | `lsappinfo front`, then walk our process ancestry | exact |
| Linux (X11) | `xdotool` or `xprop`, then walk our process ancestry | exact |
| Linux (Wayland) | none available | always plays |
| Windows | console-host window owner, else foreground process name | see caveat |

**The Windows caveat.** A terminal hosting a console over a pseudoconsole is not
in the process ancestry, and under Windows 11 default-terminal handoff it sets no
identifying environment variable either, so there is nothing to link the session
to its window. The fallback is to check whether the foreground process *is* a
terminal at all. The practical consequence: with two terminal windows open,
focusing the other one also suppresses the tone. Set `only_when_unfocused` to
`false` if that trade is wrong for you.

Focus checking adds roughly 250 ms before playback, and the hooks run with
`async: true`, so nothing blocks the session.

## Configuration

Set these through `/plugin`, then run `/reload-plugins`.

| Option | Default | Effect |
| :--- | :--- | :--- |
| `only_when_unfocused` | `true` | Set `false` to play tones even while you are looking at the terminal. |
| `task_complete_tone` | `true` | Set `false` to drop the completion tone. It fires at the end of *every* turn including one-line answers, which some people find chatty. |
| `question_style` | `ascending-pause` | Set `descending` for G♯5 → E5 instead. Both signal "your turn"; pick whichever reads that way to your ear. |

## Troubleshooting

Set `CCTONES_DEBUG=1` and the scripts print exactly why a tone did or did not
play. Run `/notification-tones:preview`, which bypasses focus gating, to confirm
audio works at all.

## Platform support

| Platform | Player |
| :--- | :--- |
| macOS | `afplay` (built in) |
| Linux | first of `paplay`, `pw-play`, `aplay`, `ffplay` |
| Windows | `System.Media.SoundPlayer` via PowerShell (built in) |

**The scripts always exit 0 and stay silent when they cannot play.** That is
deliberate. Three situations where you will correctly hear nothing:

- **No audio player installed.** Common on minimal Linux images. Install
  `pulseaudio-utils` or `alsa-utils` if you want sound.
- **SSH, devcontainers, WSL, Codespaces.** Audio would play on the *remote*
  machine, into an empty room. Claude Code's built-in notifications use terminal
  escape sequences precisely because those travel back to your local terminal.
  There is no escape sequence for "play a chord", so a bundled sound file
  fundamentally cannot cross that boundary. For remote work, use
  `preferredNotifChannel: "terminal_bell"` or Remote Control push instead.
- **Headless contexts.** `claude -p`, CI, scheduled tasks, the SDK. No audio device.

## Retuning the sounds

`tools/gen_tones.py` renders every WAV from scratch using only the Python
standard library. Edit the `TONES` table and re-run it:

```
python tools/gen_tones.py
```

Each entry is `(total_seconds, [(frequency, start, duration, amplitude), ...])`.
The note frequencies, decay constant, and peak amplitude are all named constants
at the top of the file.

## Accessibility

These tones are **additive**. They never replace Claude Code's visual state or
its existing notification channels, and disabling the plugin loses no
information. Audio-only signalling excludes Deaf and hard-of-hearing users, so if
you are configuring this for a team, pair it with `preferredNotifChannel` or a
`Notification` hook that surfaces a visual toast.

## License

MIT
