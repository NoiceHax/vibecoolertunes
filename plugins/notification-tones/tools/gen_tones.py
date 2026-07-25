#!/usr/bin/env python3
"""Render the notification tones into ../sounds as 16-bit mono WAVs.

The voice is a sine fundamental plus two fast-decaying partials, giving a
soft struck-glass character rather than a square-wave beep. Every note gets
a short attack and release ramp so there is no click at the edges.

Run from anywhere:  python tools/gen_tones.py
Stdlib only, no dependencies.
"""

import math
import os
import struct
import wave

RATE = 44100
PEAK = 0.55          # normalised peak amplitude, deliberately gentle
ATTACK = 0.007       # seconds of fade in and fade out, kills edge clicks
DECAY = 0.22         # seconds, exponential decay time constant

# Equal temperament, A4 = 440
E5 = 659.255
GS5 = 830.609
B5 = 987.767

# name -> (total seconds, [(freq, start, duration, amplitude), ...])
TONES = {
    # Task complete: ascending major third. Resolved, but not final sounding.
    "complete": (1.10, [
        (E5,  0.000, 0.65, 0.90),
        (GS5, 0.115, 0.85, 0.95),
    ]),
    # Needs permission: E major arpeggio. Opens upward, reads as an invitation.
    "permission": (1.40, [
        (E5,  0.000, 0.60, 0.85),
        (GS5, 0.105, 0.65, 0.90),
        (B5,  0.210, 0.95, 1.00),
    ]),
    # Question: same third, but the gap before the second note reads as "your turn".
    "question": (1.30, [
        (E5,  0.000, 0.50, 0.90),
        (GS5, 0.265, 0.85, 0.85),
    ]),
    # Question, alternate voicing: descending third. Settles instead of asking.
    "question-descending": (1.20, [
        (GS5, 0.000, 0.55, 0.90),
        (E5,  0.115, 0.90, 0.95),
    ]),
}


def add_note(buf, freq, start, dur, amp):
    s0 = int(start * RATE)
    n = int(dur * RATE)
    attack = max(1, int(ATTACK * RATE))

    for i in range(n):
        idx = s0 + i
        if idx >= len(buf):
            break

        t = i / RATE
        w = 2.0 * math.pi * freq * t

        v = math.sin(w)
        v += 0.22 * math.sin(2.0 * w) * math.exp(-t / 0.055)
        v += 0.07 * math.sin(3.0 * w) * math.exp(-t / 0.028)

        env = math.exp(-t / DECAY)
        if i < attack:
            env *= i / attack
        if i > n - attack:
            env *= (n - i) / attack

        buf[idx] += v * env * amp


def write_wav(buf, path):
    peak = max((abs(s) for s in buf), default=0.0) or 1.0
    gain = (PEAK / peak) * 32767.0

    frames = bytearray()
    for s in buf:
        v = int(round(s * gain))
        frames += struct.pack("<h", max(-32768, min(32767, v)))

    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(frames))


def main():
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "sounds")
    out = os.path.normpath(out)
    os.makedirs(out, exist_ok=True)

    for name, (seconds, notes) in TONES.items():
        buf = [0.0] * int(seconds * RATE)
        for freq, start, dur, amp in notes:
            add_note(buf, freq, start, dur, amp)

        path = os.path.join(out, name + ".wav")
        write_wav(buf, path)
        print("wrote %s (%d bytes)" % (path, os.path.getsize(path)))


if __name__ == "__main__":
    main()
