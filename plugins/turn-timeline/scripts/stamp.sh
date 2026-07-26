#!/usr/bin/env sh
# Dispatch a hook payload to the right interpreter for this platform.
#
# Registering "python3" directly as the hook command breaks on Windows, where
# Claude Code cannot resolve it and surfaces a visible "Executable not found in
# $PATH" error on every prompt. `sh` exists on macOS and Linux always, and on
# Windows whenever Git Bash is present, so this indirection keeps the
# not-found case out of the user's face.
#
# Reads stdin and passes it straight through. Always exits 0.

case "$(uname -s 2>/dev/null)" in
  MINGW*|MSYS*|CYGWIN*|Windows*)
    # stamp.ps1 handles Windows. Exit quietly so we do not double-stamp.
    exit 0
    ;;
esac

dir="$(cd "$(dirname "$0")" 2>/dev/null && pwd)" || exit 0

for py in python3 python; do
  if command -v "$py" >/dev/null 2>&1; then
    "$py" "$dir/stamp.py"
    exit 0
  fi
done

# No Python at all: emit nothing, message displays unchanged.
exit 0
