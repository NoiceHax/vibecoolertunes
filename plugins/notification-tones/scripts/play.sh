#!/usr/bin/env sh
# Play one notification tone on macOS or Linux.
#
# Usage: sh play.sh <complete|permission|question>
#
# Always exits 0. If there is no audio device, no player, or the session is
# remote, staying silent is the correct outcome, not an error worth surfacing.

set -u
name="${1:-}"
[ -n "$name" ] || exit 0

root="$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)" || exit 0

# Walk our own process ancestry looking for $1. On macOS and X11 the terminal
# emulator really is our ancestor, unlike on Windows.
is_ancestor() {
  target="$1"
  cur=$$
  i=0
  while [ $i -lt 24 ]; do
    [ "$cur" = "$target" ] && return 0
    cur="$(ps -o ppid= -p "$cur" 2>/dev/null | tr -d ' ')"
    [ -n "$cur" ] || return 1
    [ "$cur" -gt 1 ] 2>/dev/null || return 1
    i=$((i + 1))
  done
  return 1
}

# Returns 0 only when we can positively prove the terminal has focus.
# Undetermined counts as unfocused, so the tone plays. A missed notification
# is worse than one you did not need.
terminal_focused() {
  fg=''
  case "$(uname -s 2>/dev/null)" in
    Darwin)
      command -v lsappinfo >/dev/null 2>&1 || return 1
      asn="$(lsappinfo front 2>/dev/null)"
      [ -n "$asn" ] || return 1
      fg="$(lsappinfo info -only pid "$asn" 2>/dev/null \
            | sed -n 's/.*=[^0-9]*\([0-9][0-9]*\).*/\1/p')"
      ;;
    Linux)
      # Wayland exposes no portable way to read the focused window, so
      # Wayland sessions always play. X11 only below.
      [ -n "${DISPLAY:-}" ] || return 1
      if command -v xdotool >/dev/null 2>&1; then
        fg="$(xdotool getactivewindow getwindowpid 2>/dev/null)"
      elif command -v xprop >/dev/null 2>&1; then
        wid="$(xprop -root _NET_ACTIVE_WINDOW 2>/dev/null \
               | sed -n 's/.*\(0x[0-9a-fA-F][0-9a-fA-F]*\).*/\1/p')"
        [ -n "$wid" ] || return 1
        fg="$(xprop -id "$wid" _NET_WM_PID 2>/dev/null \
              | sed -n 's/.*=[^0-9]*\([0-9][0-9]*\).*/\1/p')"
      else
        return 1
      fi
      ;;
    *)
      return 1
      ;;
  esac

  [ -n "$fg" ] || return 1
  is_ancestor "$fg"
}

# Optional user config, supplied by Claude Code as env vars.
case "$name" in
  complete)
    [ "${CLAUDE_PLUGIN_OPTION_TASK_COMPLETE_TONE:-true}" = "false" ] && exit 0
    ;;
  question)
    [ "${CLAUDE_PLUGIN_OPTION_QUESTION_STYLE:-ascending-pause}" = "descending" ] \
      && name="question-descending"
    ;;
esac

if [ "${CLAUDE_PLUGIN_OPTION_ONLY_WHEN_UNFOCUSED:-true}" != "false" ]; then
  terminal_focused && exit 0
fi

file="$root/sounds/$name.wav"
[ -f "$file" ] || exit 0

# First player that exists wins. ffplay last, it is the heaviest.
if   command -v afplay  >/dev/null 2>&1; then afplay "$file"
elif command -v paplay  >/dev/null 2>&1; then paplay "$file"
elif command -v pw-play >/dev/null 2>&1; then pw-play "$file"
elif command -v aplay   >/dev/null 2>&1; then aplay -q "$file"
elif command -v ffplay  >/dev/null 2>&1; then ffplay -nodisp -autoexit -loglevel quiet "$file"
fi

exit 0
