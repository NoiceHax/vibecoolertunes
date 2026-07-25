# vibecoolertunes

**Distinct musical tones for each reason Claude Code stops.**

A single alert tells you *something* happened. It does not tell you whether it is
worth walking back to your desk. This plugin gives Claude Code three different
sounds for the three different reasons it stops, so you can tell from the next
room whether it finished, is blocked on a permission prompt, or is waiting for
you to answer a question.

It only plays when you are not looking at the terminal.

```
/plugin marketplace add NoiceHax/vibecoolertunes
/plugin install notification-tones@vibecoolertunes
/reload-plugins
/notification-tones:preview
```

---

## Contents

- [Why](#why)
- [The tones](#the-tones)
- [Install](#install)
- [Configuration](#configuration)
- [Only when you are not looking](#only-when-you-are-not-looking)
- [Platform support](#platform-support)
- [How it works](#how-it-works)
- [Sound design](#sound-design)
- [Retuning the tones](#retuning-the-tones)
- [Troubleshooting](#troubleshooting)
- [Known limitations](#known-limitations)
- [Accessibility](#accessibility)
- [Uninstall](#uninstall)
- [Repo layout](#repo-layout)
- [Testing needed](#-testing-needed)

---

## Why

Claude Code already knows *why* it stopped. It fires structured events with a
`notification_type` that distinguishes a permission prompt from an idle prompt
from a finished turn. That taxonomy is the expensive part of this problem and it
already exists. What did not exist was any way to turn it into sound.

By default on most terminals you get nothing at all. Claude Code sends desktop
notifications only on Ghostty, Kitty, and iTerm2. Everywhere else you either
watch the terminal or you miss the moment it needed you. Setting
`preferredNotifChannel` to `terminal_bell` gets you one undifferentiated beep,
which brings you back to the desk to discover it was just a completed turn.

This plugin binds a distinct tone to each event type. After about a day you stop
consciously decoding them and just know whether to get up.

## The tones

| Event | Hook | Tone | Reads as |
| :--- | :--- | :--- | :--- |
| Turn finished | `Stop` | E5 → G♯5, ascending major third | resolved, done |
| Permission prompt waiting | `Notification` / `permission_prompt` | E5 → G♯5 → B5, E major arpeggio | an invitation, opens upward |
| Waiting on your answer | `Notification` / `idle_prompt` | E5 → pause → G♯5 | "your turn" |

All three are built on the same root, so they sound like one family rather than
three unrelated alerts. The permission tone climbs because it is asking you to
come back. The question tone uses a gap instead of a third note, which lands as a
prompt rather than a statement.

An alternate descending voicing for the question tone (G♯5 → E5) ships as well.
See [Configuration](#configuration).

## Install

**From the marketplace** (recommended):

```
/plugin marketplace add NoiceHax/vibecoolertunes
/plugin install notification-tones@vibecoolertunes
/reload-plugins
```

Enter those one at a time. Then confirm it works:

```
/notification-tones:preview
```

**Without installing**, to try it or to hack on it:

```sh
git clone https://github.com/NoiceHax/vibecoolertunes
claude --plugin-dir ./vibecoolertunes/plugins/notification-tones
```

**From the CLI**, outside a session:

```sh
claude plugin marketplace add NoiceHax/vibecoolertunes
claude plugin install notification-tones@vibecoolertunes
```

There are no dependencies to install. The tones ship as pre-rendered WAV files
and playback uses a program your OS already has.

## Configuration

```
/plugin configure notification-tones@vibecoolertunes
```

Run `/reload-plugins` after any change.

| Option | Type | Default | Effect |
| :--- | :--- | :--- | :--- |
| `only_when_unfocused` | boolean | `true` | Stay silent while the terminal has focus. Set `false` to always play. |
| `task_complete_tone` | boolean | `true` | Set `false` to drop the end-of-turn tone and keep only permission and question tones. |
| `question_style` | string | `ascending-pause` | Set `descending` for G♯5 → E5 instead of E5 → pause → G♯5. |

**On `task_complete_tone`:** the `Stop` hook fires at the end of *every* turn,
including one-line answers. If that feels chatty, turning this off leaves you
with tones that fire only when Claude is actually blocked on you, which is the
higher-signal subset.

## Only when you are not looking

A chime for something already on screen in front of you is noise. By default
tones play only when the terminal does not have focus.

The governing rule on every platform: **undetermined focus counts as unfocused,
so the tone plays.** A missed notification is a worse failure than an unnecessary
one, so every detection path fails in that direction.

| Platform | Method | Precision |
| :--- | :--- | :--- |
| macOS | `lsappinfo front`, then walk process ancestry | exact |
| Linux (X11) | `xdotool` or `xprop`, then walk process ancestry | exact |
| Linux (Wayland) | no portable method exists | always plays |
| Windows | console-host window owner, else foreground process name | approximate, see below |

**The Windows caveat.** On macOS and Linux the terminal emulator is a genuine
ancestor of the session, so matching the focused window's process against the
ancestry chain is exact. On Windows it is not. A terminal hosting a console over
a pseudoconsole sits entirely outside the process tree, and under Windows 11
default-terminal handoff it cannot inject an identifying environment variable
either, because it did not create the process. Neither `WT_SESSION` nor
`TERM_PROGRAM` is set. With nothing left to link a session to its window, the
fallback checks whether the foreground process *is* a terminal at all.

The practical consequence: with two terminal windows open on Windows, focusing
the other one also suppresses the tone. Set `only_when_unfocused` to `false` if
that trade is wrong for you.

Focus checking adds roughly 250 ms before playback, and hooks run with
`async: true`, so nothing ever blocks the session.

## Platform support

| Platform | Playback | Requirement |
| :--- | :--- | :--- |
| Windows | `System.Media.SoundPlayer` via PowerShell | built in |
| macOS | `afplay` | built in |
| Linux | first available of `paplay`, `pw-play`, `aplay`, `ffplay` | install `pulseaudio-utils` or `alsa-utils` |

**The scripts always exit 0 and stay silent when they cannot play.** Silence is a
correct outcome, not an error worth surfacing. You will correctly hear nothing
in these cases:

- **No audio player installed.** Common on minimal Linux images.
- **SSH, devcontainers, WSL, Codespaces.** Audio would play on the *remote*
  machine, into an empty room. See [Known limitations](#known-limitations).
- **Headless contexts.** `claude -p`, CI, scheduled tasks, the SDK.

## How it works

The plugin is hooks plus WAV files. There is no daemon, no MCP server, and no
background process.

**Event wiring.** `hooks/hooks.json` binds the `Stop` event and two matchers on
the `Notification` event. The question matcher covers
`idle_prompt|agent_needs_input|elicitation_dialog` so it catches subagent
questions and MCP elicitation dialogs as well as ordinary prompts.

**One plugin, three operating systems.** Each event registers *two* hook entries,
one invoking `sh` and one invoking `powershell`. The wrong-platform entry fails
to exec and Claude Code treats that as a non-blocking error, so it is silent.
This avoids OS detection entirely and means there is no platform branch to get
wrong. If you run `/reload-plugins` you will see `6 hooks` load, which is three
events times two entries.

**Exec form, not shell form.** Hooks use `command` plus `args` rather than a
shell string. `${CLAUDE_PLUGIN_ROOT}` is passed as a single argument with no
quoting, which matters because plugin cache paths routinely contain spaces.

**Fail open.** Every failure path in both scripts leads to playing the tone or
exiting 0. Nothing throws, nothing blocks, and no failure mode results in
permanently silent notifications.

## Sound design

Each note is a sine fundamental plus two harmonics that decay much faster than
the root:

- 2nd partial at 0.22 amplitude, 55 ms decay constant
- 3rd partial at 0.07 amplitude, 28 ms decay constant
- fundamental decays with a 220 ms constant

That fast-decaying harmonic content is what produces a struck-glass character
instead of a square-wave beep. Every note gets a 7 ms attack and release ramp,
which eliminates the click you otherwise get from starting or cutting a waveform
mid-cycle.

Peak amplitude is normalised to 0.55 rather than 1.0. These are meant to be
noticed from the next room without being startling.

Frequencies are equal temperament at A4 = 440: E5 = 659.255 Hz,
G♯5 = 830.609 Hz, B5 = 987.767 Hz.

## Retuning the tones

`tools/gen_tones.py` renders every WAV from scratch using only the Python
standard library. No dependencies, no build step.

```sh
python plugins/notification-tones/tools/gen_tones.py
```

Edit the `TONES` table to change the music:

```python
TONES = {
    "complete": (1.10, [
        (E5,  0.000, 0.65, 0.90),
        (GS5, 0.115, 0.85, 0.95),
    ]),
}
```

Each entry is `(total_seconds, [(frequency, start, duration, amplitude), ...])`.
Notes may overlap freely; they are summed and the result is normalised. The
envelope constants, peak amplitude, and note frequencies are all named constants
at the top of the file.

## Troubleshooting

Both scripts explain themselves when you set `CCTONES_DEBUG=1`:

```sh
# macOS / Linux
CCTONES_DEBUG=1 sh plugins/notification-tones/scripts/play.sh complete
```

```powershell
# Windows
$env:CCTONES_DEBUG=1
powershell -File plugins\notification-tones\scripts\play.ps1 complete
```

It prints the exact decision, for example `not focused: foreground is 'brave'`
or `focused: terminal 'WindowsTerminal'` or `no player available`.

For a full report on macOS or Linux:

```sh
sh plugins/notification-tones/scripts/diagnose.sh
```

That prints your OS, terminal, which audio players exist, the raw output of each
focus-detection command, your process ancestry, and then plays a tone.

**"I hear nothing."** Most often the terminal has focus, which is working as
intended. Run `/notification-tones:preview`, which bypasses focus gating. If the
preview is silent too, it is a playback problem, not a focus problem.

**"It plays when I am looking at the terminal."** Focus detection failed and fell
back to playing. Run the diagnostic and open an issue with the output.

**"I hear every tone twice."** You have both the plugin installed and a leftover
`hooks` block in `~/.claude/settings.json`. Remove the settings block.

## Known limitations

**Remote sessions.** This is structural, not a bug. Claude Code's built-in
notifications use terminal escape sequences precisely because those travel back
down the SSH pipe and fire on your local machine. There is no escape sequence for
"play a chord", so a bundled sound file fundamentally cannot cross that boundary.
Over SSH the audio would play on the remote host. For remote work use
`preferredNotifChannel: "terminal_bell"` or Remote Control push notifications
instead.

**Wayland.** No portable way exists to query the focused window, so Wayland
sessions always play regardless of focus.

**Multiple terminal windows on Windows.** See the
[Windows caveat](#only-when-you-are-not-looking) above.

**Headless.** No audio device, so nothing plays. Intentional.

## Accessibility

These tones are **additive**. They never replace Claude Code's visual state or
any existing notification channel, and disabling the plugin loses no information.

Audio-only signalling excludes Deaf and hard-of-hearing users. If you are
configuring this for a team, pair it with `preferredNotifChannel` or a
`Notification` hook that surfaces a visual toast, so that sound is an
enhancement rather than the only path.

## Uninstall

```
/plugin uninstall notification-tones@vibecoolertunes
/plugin marketplace remove vibecoolertunes
```

Nothing is left behind outside the plugin cache.

## Repo layout

```
.claude-plugin/marketplace.json      marketplace catalog
.github/ISSUE_TEMPLATE/              platform report form
plugins/notification-tones/
├── .claude-plugin/plugin.json       manifest, version, userConfig schema
├── hooks/hooks.json                 Stop + Notification event wiring
├── scripts/play.sh                  macOS and Linux playback + focus check
├── scripts/play.ps1                 Windows playback + focus check
├── scripts/diagnose.sh              tester diagnostic report
├── skills/preview/SKILL.md          /notification-tones:preview
├── sounds/*.wav                     4 pre-rendered tones
└── tools/gen_tones.py               stdlib-only renderer
```

---

## 🧪 Testing needed

**Status: `v0.1.0`. Windows is verified on real hardware. macOS and Linux are
not.**

The POSIX path passes syntax checks under `sh`, `bash`, and `dash`, and every
branch was tested against stubbed platform tools, including the player fallback
ladder and malformed input. But **no part of it has ever run on a real Mac or
Linux machine.** Three things specifically need confirming:

1. **`lsappinfo` output format on macOS.** The parser was tested against
   fixtures assumed to look like `"ASN:0x0-0x1e01e:"` and `"pid"=1234`. If real
   macOS formats these differently, focus detection silently stops working.
2. **`xprop _NET_WM_PID` output format on Linux X11.** Same concern.
3. **That the terminal emulator is genuinely a process ancestor.** This is
   standard on macOS and Linux, and it is exactly what turned out *not* to hold
   on Windows, which is what made that platform hard.

Every one of those failures degrades to "focus undetermined", which plays the
tone. So the worst case is the pre-focus-gating behaviour, not a crash and not
silence.

### How to help

```sh
git clone https://github.com/NoiceHax/vibecoolertunes
cd vibecoolertunes
sh plugins/notification-tones/scripts/diagnose.sh
```

Then [open an issue](https://github.com/NoiceHax/vibecoolertunes/issues/new?template=platform-report.yml)
and paste the output. It reports your OS, terminal, available players, the raw
focus-detection output, and your process ancestry. It reads no file contents and
does not dump your environment.

**Reports are useful even when everything worked.** That confirmation is exactly
what is missing right now.

### The single most valuable test

Run the diagnostic **while your terminal window has focus**. It should end with:

```
RESULT: terminal has focus -> tones correctly suppressed
```

If it instead says the foreground pid is not an ancestor, focus detection is
broken on your setup, and the ancestry listing in the report is what pins down
why. That one case is worth more than any other report.

---

## License

MIT
