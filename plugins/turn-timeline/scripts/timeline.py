#!/usr/bin/env python3
"""Print when each turn in a Claude Code session actually ran.

Claude Code reports "Baked for 3m 45s" but not from when to when. The transcript
already records both: a system record with subtype 'turn_duration' carries the
turn's durationMs and its end timestamp, so the start is simply end - duration.

Usage:
    python timeline.py [transcript.jsonl]     # defaults to newest transcript
"""

import glob
import json
import os
import sys
from datetime import datetime, timedelta, timezone


def newest_transcript():
    root = os.path.join(os.path.expanduser("~"), ".claude", "projects")
    files = glob.glob(os.path.join(root, "*", "*.jsonl"))
    if not files:
        sys.exit("No transcripts found under %s" % root)
    return max(files, key=os.path.getmtime)


def parse_ts(s):
    # Stored as UTC with a trailing Z, e.g. 2026-07-25T19:49:57.143Z
    return datetime.fromisoformat(s.replace("Z", "+00:00")).astimezone()


def human(ms):
    s = ms / 1000.0
    if s < 60:
        return "%.0fs" % s
    m, s = divmod(int(round(s)), 60)
    if m < 60:
        return "%dm %02ds" % (m, s)
    h, m = divmod(m, 60)
    return "%dh %02dm %02ds" % (h, m, s)


def clock(dt):
    return dt.strftime("%I:%M:%S %p").lstrip("0").lower()


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else newest_transcript()

    records = []
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                records.append(json.loads(line))
            except ValueError:
                continue

    # Pair each turn_duration with the most recent typed prompt before it.
    prompts = []
    for r in records:
        if r.get("type") == "user" and r.get("promptSource") == "typed":
            msg = r.get("message", {})
            content = msg.get("content", "")
            if isinstance(content, list):
                content = " ".join(
                    p.get("text", "") for p in content if isinstance(p, dict)
                )
            prompts.append((parse_ts(r["timestamp"]), " ".join(content.split())))

    turns = []
    for r in records:
        if r.get("type") == "system" and r.get("subtype") == "turn_duration":
            end = parse_ts(r["timestamp"])
            dur = int(r.get("durationMs", 0))
            start = end - timedelta(milliseconds=dur)
            prompt = ""
            for pts, text in prompts:
                if pts <= end:
                    prompt = text
                else:
                    break
            turns.append((start, end, dur, prompt))

    if not turns:
        sys.exit("No turn_duration records in %s" % os.path.basename(path))

    print("session : %s" % os.path.basename(path).replace(".jsonl", ""))
    print("date    : %s" % turns[0][0].strftime("%a %d %b %Y"))
    print()
    print("  #  started       ended         elapsed    prompt")
    print("  -  ------------  ------------  ---------  " + "-" * 40)

    total = 0
    for i, (start, end, dur, prompt) in enumerate(turns, 1):
        total += dur
        snippet = (prompt[:40] + "…") if len(prompt) > 40 else prompt
        print("  %-2d %-13s %-13s %-10s %s"
              % (i, clock(start), clock(end), human(dur), snippet))

    span = turns[-1][1] - turns[0][0]
    span_ms = int(span.total_seconds() * 1000)
    idle = span_ms - total

    print()
    print("  %d turns   %s → %s"
          % (len(turns), clock(turns[0][0]), clock(turns[-1][1])))
    print("  working  %-12s (%.0f%% of wall clock)"
          % (human(total), 100.0 * total / span_ms if span_ms else 0))
    print("  idle     %-12s (thinking time, reading, away from keyboard)"
          % human(idle))
    print("  wall     %s" % human(span_ms))


if __name__ == "__main__":
    main()
