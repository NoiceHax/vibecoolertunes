#!/usr/bin/env node
/*
 * Pick the right player script for this platform and run it.
 *
 *   node dispatch.js <complete|permission|question>
 *
 * Why this exists: Claude Code resolves a hook's command against the real PATH
 * and surfaces a visible "Executable not found in $PATH" error on every event
 * when it misses. Registering one `sh` entry and one `powershell` entry, and
 * letting the wrong-platform one fail, does not work: it fails loudly. On
 * Windows `sh` is not on the PATH Claude Code spawns with even when Git Bash is
 * installed, and on macOS `powershell` is absent. No hook form suppresses the
 * error.
 *
 * So the hook invokes one command, and the platform choice happens here, where
 * a missing interpreter is a catchable spawn error rather than a hook failure.
 *
 * Always exits 0. Silence is the correct outcome when audio is unavailable.
 */

'use strict';

const path = require('path');
const { spawnSync } = require('child_process');

const name = process.argv[2];
if (!name) process.exit(0);

const scripts = path.join(__dirname);

try {
  if (process.platform === 'win32') {
    spawnSync('powershell', [
      '-NoProfile', '-ExecutionPolicy', 'Bypass',
      '-File', path.join(scripts, 'play.ps1'), name,
    ], { stdio: 'ignore', windowsHide: true });
  } else {
    spawnSync('/bin/sh', [path.join(scripts, 'play.sh'), name], { stdio: 'ignore' });
  }
} catch (e) {
  // No player, no audio device, no shell: staying quiet is correct.
}

process.exit(0);
