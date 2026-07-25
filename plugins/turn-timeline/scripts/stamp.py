#!/usr/bin/env python3
"""Append a wall-clock range to Claude Code's turn output.

Claude Code reports "Baked for 3m 21s" but never says from when to when. This
handles two hook events from one entry point:

  UserPromptSubmit  record the turn's start time, print nothing
  MessageDisplay    append "from 3:06:09 pm to 3:09:54 pm" to the shown text

MessageDisplay output is screen-only: the transcript and Claude's context keep
the original text, so this costs zero tokens.

Every failure path exits 0 without printing, which leaves the message displayed
exactly as it would have been. A broken stamp must never corrupt your output.
"""

import json
import os
import random
import sys
import tempfile
import time

GLYPH = "✻"  # the same six-petal asterisk Claude Code uses

CLOSERS = [
    "still warm", "fresh out the oven", "cooled and plated", "no notes",
    "worth the wait", "let it rest", "chef's kiss", "crumbs everywhere",
    "second helpings?", "hot and ready", "off the heat", "seasoned to taste",
    "risen nicely", "golden on top", "one for the road",
]


def opt(name, default=""):
    return os.environ.get("CLAUDE_PLUGIN_OPTION_" + name.upper(), default)


def state_dir():
    base = os.environ.get("CLAUDE_PLUGIN_DATA") or os.path.join(
        tempfile.gettempdir(), "claude-turn-timeline"
    )
    try:
        os.makedirs(base, exist_ok=True)
    except OSError:
        base = tempfile.gettempdir()
    return base


def state_path(session_id):
    safe = "".join(c for c in str(session_id) if c.isalnum() or c in "-_")[:64]
    return os.path.join(state_dir(), "start-%s" % (safe or "default"))


def clock(epoch):
    fmt = "%H:%M:%S" if opt("clock_format", "12") == "24" else "%I:%M:%S %p"
    out = time.strftime(fmt, time.localtime(epoch))
    return out.lstrip("0").lower() if fmt.startswith("%I") else out


def human(seconds):
    if seconds < 60:
        return "%ds" % int(round(seconds))
    m, s = divmod(int(round(seconds)), 60)
    if m < 60:
        return "%dm %ds" % (m, s)
    h, m = divmod(m, 60)
    return "%dh %dm %ds" % (h, m, s)


def main():
    # stamp.ps1 owns Windows. Both hook entries are registered on every
    # platform, so without this guard a Windows box with Python installed
    # would emit two competing displayContent values for the same message.
    if sys.platform == "win32":
        return

    try:
        # Decode stdin as UTF-8 explicitly rather than trusting the locale.
        # A mis-decoded delta corrupts every non-ASCII character in the message.
        payload = json.loads(sys.stdin.buffer.read().decode("utf-8"))
    except Exception:
        return

    event = payload.get("hook_event_name")
    session = payload.get("session_id", "default")

    if event == "UserPromptSubmit":
        # Print nothing. UserPromptSubmit stdout is injected into Claude's
        # context, so anything written here would cost tokens every turn.
        try:
            with open(state_path(session), "w") as fh:
                fh.write(str(time.time()))
        except OSError:
            pass
        return

    if event != "MessageDisplay" or not payload.get("final"):
        return

    delta = payload.get("delta")
    if not delta:
        return

    try:
        with open(state_path(session)) as fh:
            start = float(fh.read().strip())
    except (OSError, ValueError):
        return

    now = time.time()
    if now < start:
        return

    parts = [GLYPH]
    if opt("show_duration", "true") != "false":
        parts.append("Baked for %s" % human(now - start))
        parts.append("from %s to %s" % (clock(start), clock(now)))
    else:
        parts.append("%s to %s" % (clock(start), clock(now)))

    if opt("closing_line", "true") != "false":
        parts.append("· %s" % random.choice(CLOSERS))

    line = " ".join(parts)

    json.dump(
        {
            "hookSpecificOutput": {
                "hookEventName": "MessageDisplay",
                "displayContent": "%s\n\n%s" % (delta, line),
            }
        },
        sys.stdout,
    )


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
