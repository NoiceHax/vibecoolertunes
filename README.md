# vibecoolertunes

A Claude Code plugin that gives a **distinct musical tone to each reason Claude
stops**, so you can tell from another room whether it finished, needs
permission, or is waiting on you.

| Event | Tone |
| :--- | :--- |
| Turn finished | E5 → G♯5, ascending major third |
| Permission prompt waiting | E5 → G♯5 → B5, an E major arpeggio |
| Waiting on your answer | E5 → pause → G♯5 |

All three share a root, so they read as one family rather than three unrelated
alerts. Tones play **only when the terminal does not have focus**, because a
chime for something already on screen in front of you is just noise.

Full docs: [plugins/notification-tones/README.md](plugins/notification-tones/README.md)

## Install

```
/plugin marketplace add NoiceHax/vibecoolertunes
/plugin install notification-tones@vibecoolertunes
/reload-plugins
/notification-tones:preview
```

Or run it without installing:

```
claude --plugin-dir ./plugins/notification-tones
```

---

## 🧪 Testing wanted: macOS and Linux

**Status: `v0.1.0`, Windows verified on real hardware, macOS and Linux are not.**

The audio playback and focus detection are written per platform. The POSIX path
passes syntax checks under `sh`, `bash`, and `dash`, and every branch was tested
against stubbed platform tools, but **no part of it has run on a real Mac or
Linux box.** Three things specifically need confirming:

1. `lsappinfo front` and `lsappinfo info -only pid` output formats on macOS
2. `xprop _NET_WM_PID` output format on Linux X11
3. That the terminal emulator really is a process ancestor of the session
   (it is not on Windows, which is what made that platform hard)

Everything is designed to **fail toward playing the tone**, never toward
silence, so the worst case if detection breaks is that tones play when you are
looking at the terminal. Nothing should crash or go permanently quiet.

### How to help

```sh
git clone https://github.com/NoiceHax/vibecoolertunes
cd vibecoolertunes
sh plugins/notification-tones/scripts/diagnose.sh
```

The diagnostic prints your OS, terminal, available audio players, the **raw**
output of each focus-detection command, and your process ancestry, then plays a
tone. It reads no file contents and does not dump your environment.

Then [open an issue](https://github.com/NoiceHax/vibecoolertunes/issues/new?template=platform-report.yml)
and paste the output. Reports are useful **even when everything worked**, since
that is exactly the confirmation that is missing right now.

The most valuable single case: run the diagnostic **while your terminal is
focused**. It should end with `RESULT: terminal has focus`. If it says the
foreground pid is not an ancestor, focus detection is broken on your setup and
the ancestry list in the report is what pins down why.

---

## Repo layout

```
.claude-plugin/marketplace.json     marketplace catalog
plugins/notification-tones/
├── .claude-plugin/plugin.json      manifest and user config
├── hooks/hooks.json                Stop + Notification wiring
├── scripts/play.sh                 macOS and Linux playback + focus check
├── scripts/play.ps1                Windows playback + focus check
├── scripts/diagnose.sh             tester diagnostic report
├── skills/preview/SKILL.md         /notification-tones:preview
├── sounds/*.wav                    4 pre-rendered tones
└── tools/gen_tones.py              stdlib-only renderer, edit and re-run
```

## License

MIT
