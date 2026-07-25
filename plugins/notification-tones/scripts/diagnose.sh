#!/usr/bin/env sh
# Collect everything needed to debug notification-tones on macOS or Linux.
#
#   sh scripts/diagnose.sh
#
# Prints a paste-ready report. Reads nothing sensitive: OS version, terminal
# name, which audio players are installed, the raw output of the focus-detection
# commands, and this process's ancestry. No file contents, no environment dump.

set -u
root="$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)" || root="?"
OS="$(uname -s 2>/dev/null || echo unknown)"

echo "=== notification-tones diagnostic ==="
echo

echo "## platform"
echo "uname -srm : $(uname -srm 2>/dev/null || echo '?')"
[ "$OS" = "Darwin" ] && echo "macOS      : $(sw_vers -productVersion 2>/dev/null || echo '?')"
echo "shell      : ${SHELL:-unset}"
echo "plugin root: $root"
echo

echo "## terminal and session"
for v in TERM TERM_PROGRAM TERM_PROGRAM_VERSION DISPLAY WAYLAND_DISPLAY XDG_SESSION_TYPE SSH_CONNECTION; do
  eval "val=\${$v:-<unset>}"
  echo "$v = $val"
done
echo

echo "## audio players on PATH"
found=0
for p in afplay paplay pw-play aplay ffplay; do
  if command -v "$p" >/dev/null 2>&1; then
    echo "  FOUND   $p -> $(command -v "$p")"
    found=$((found + 1))
  else
    echo "  missing $p"
  fi
done
[ "$found" -eq 0 ] && echo "  !! no player available, tones can never play"
echo

echo "## focus detection"
fg=''
case "$OS" in
  Darwin)
    if command -v lsappinfo >/dev/null 2>&1; then
      asn="$(lsappinfo front 2>&1)"
      echo "lsappinfo front       : [$asn]"
      raw="$(lsappinfo info -only pid "$asn" 2>&1)"
      echo "lsappinfo info -only  : [$raw]"
      fg="$(printf '%s' "$raw" | sed -n 's/.*=[^0-9]*\([0-9][0-9]*\).*/\1/p')"
      echo "parsed foreground pid : [${fg:-PARSE FAILED}]"
      [ -z "$fg" ] && echo "  !! parse failed. This is the most likely macOS bug; please include the two [bracketed] lines above."
    else
      echo "lsappinfo not found, cannot detect focus on this Mac"
    fi
    ;;
  Linux)
    echo "DISPLAY = ${DISPLAY:-<unset>}"
    if [ -z "${DISPLAY:-}" ]; then
      echo "no DISPLAY (Wayland or headless): focus undetectable, tones always play"
    elif command -v xdotool >/dev/null 2>&1; then
      raw="$(xdotool getactivewindow getwindowpid 2>&1)"
      echo "xdotool               : [$raw]"
      fg="$(printf '%s' "$raw" | sed -n 's/^\([0-9][0-9]*\)$/\1/p')"
      echo "parsed foreground pid : [${fg:-PARSE FAILED}]"
    elif command -v xprop >/dev/null 2>&1; then
      wraw="$(xprop -root _NET_ACTIVE_WINDOW 2>&1)"
      echo "xprop -root           : [$wraw]"
      wid="$(printf '%s' "$wraw" | sed -n 's/.*\(0x[0-9a-fA-F][0-9a-fA-F]*\).*/\1/p')"
      echo "parsed window id      : [${wid:-PARSE FAILED}]"
      if [ -n "$wid" ]; then
        praw="$(xprop -id "$wid" _NET_WM_PID 2>&1)"
        echo "xprop -id _NET_WM_PID : [$praw]"
        fg="$(printf '%s' "$praw" | sed -n 's/.*=[^0-9]*\([0-9][0-9]*\).*/\1/p')"
        echo "parsed foreground pid : [${fg:-PARSE FAILED}]"
      fi
    else
      echo "neither xdotool nor xprop installed, cannot detect focus"
    fi
    ;;
  *)
    echo "$OS is not a platform play.sh handles; tones always play"
    ;;
esac
echo

echo "## process ancestry (terminal should appear here)"
cur=$$
i=0
match=no
while [ $i -lt 24 ]; do
  line="$(ps -o ppid=,comm= -p "$cur" 2>/dev/null)"
  if [ -z "$line" ]; then
    [ $i -eq 0 ] && echo "  !! 'ps -o ppid=,comm= -p $cur' returned nothing." \
                 && echo "     Focus detection cannot work without it. Please report this."
    break
  fi
  name="$(printf '%s' "$line" | sed 's/^ *[0-9]* *//')"
  mark=''
  if [ -n "$fg" ] && [ "$cur" = "$fg" ]; then mark='   <== FOREGROUND MATCH'; match=yes; fi
  echo "  $cur $name$mark"
  cur="$(printf '%s' "$line" | sed 's/^ *\([0-9]*\).*/\1/')"
  [ -n "$cur" ] || break
  [ "$cur" -gt 1 ] 2>/dev/null || break
  i=$((i + 1))
done
echo
if [ -n "$fg" ]; then
  if [ "$match" = yes ]; then
    echo "RESULT: terminal has focus -> tones correctly suppressed"
  else
    echo "RESULT: foreground pid $fg is NOT an ancestor -> tones will play"
    echo "  If your terminal WAS focused while running this, focus detection is"
    echo "  broken on your setup. Please report the ancestry list above."
  fi
else
  echo "RESULT: focus undetermined -> tones always play (safe fallback)"
fi
echo

echo "## playback test (bypasses focus gating)"
if [ -x "$root/scripts/play.sh" ] || [ -f "$root/scripts/play.sh" ]; then
  echo "playing 'permission' now, you should hear a three-note rising arpeggio..."
  CLAUDE_PLUGIN_OPTION_ONLY_WHEN_UNFOCUSED=false sh "$root/scripts/play.sh" permission
  echo "exit=$?  (0 is expected even when silent)"
else
  echo "!! play.sh not found at $root/scripts/play.sh"
fi
echo
echo "=== end of report ==="
