#!/usr/bin/env node
/*
 * Append a wall-clock range to Claude Code's turn output.
 *
 *   UserPromptSubmit  record the turn's start time, print nothing
 *   MessageDisplay    append the range to the text shown on screen
 *
 * MessageDisplay output is screen-only: the transcript and Claude's context
 * keep the original text, so this costs zero tokens.
 *
 * Why Node rather than sh or python3: Claude Code resolves a hook's command
 * against the real PATH and surfaces a visible "Executable not found in $PATH"
 * error on every prompt when it misses. There is no interpreter present on
 * Windows, macOS and Linux alike except the one Claude Code itself runs on, and
 * no hook form suppresses that error. Registering two entries and letting the
 * wrong-platform one fail does not work: it fails loudly. So this is a single
 * entry point that does any platform-specific work internally, where a failure
 * is catchable instead of fatal.
 *
 * Every failure path exits 0 without printing, leaving the message displayed
 * exactly as it would have been. A timing stamp must never corrupt real output.
 */

'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');

const GLYPH = '✻'; // six-petal asterisk, matching Claude Code
const DOT = '·';

const CLOSERS = [
  'still warm', 'fresh out the oven', 'cooled and plated', 'no notes',
  'worth the wait', 'let it rest', "chef's kiss", 'crumbs everywhere',
  'second helpings?', 'hot and ready', 'off the heat', 'seasoned to taste',
  'risen nicely', 'golden on top', 'one for the road',
];

function opt(name, fallback) {
  const v = process.env['CLAUDE_PLUGIN_OPTION_' + name.toUpperCase()];
  return v === undefined || v === '' ? fallback : v;
}

function stateDir() {
  let base = process.env.CLAUDE_PLUGIN_DATA;
  if (!base) base = path.join(os.tmpdir(), 'claude-turn-timeline');
  try { fs.mkdirSync(base, { recursive: true }); } catch (e) { base = os.tmpdir(); }
  return base;
}

function statePath(session) {
  const safe = String(session).replace(/[^A-Za-z0-9_-]/g, '').slice(0, 64) || 'default';
  return path.join(stateDir(), 'start-' + safe);
}

function clock(ms) {
  const d = new Date(ms);
  const pad = (n) => String(n).padStart(2, '0');
  if (opt('clock_format', '12') === '24') {
    return pad(d.getHours()) + ':' + pad(d.getMinutes()) + ':' + pad(d.getSeconds());
  }
  const h24 = d.getHours();
  const h = h24 % 12 === 0 ? 12 : h24 % 12;
  return h + ':' + pad(d.getMinutes()) + ':' + pad(d.getSeconds()) +
    (h24 < 12 ? ' am' : ' pm');
}

function human(ms) {
  const total = Math.round(ms / 1000);
  if (total < 60) return total + 's';
  const m = Math.floor(total / 60), s = total % 60;
  if (m < 60) return m + 'm ' + s + 's';
  return Math.floor(m / 60) + 'h ' + (m % 60) + 'm ' + s + 's';
}

// Escape every non-ASCII code unit so the emitted JSON is byte-safe no matter
// what encoding the receiving end assumes.
function asciiJson(obj) {
  return JSON.stringify(obj).replace(/[-￿]/g, (c) =>
    '\\u' + c.charCodeAt(0).toString(16).padStart(4, '0'));
}

function emit(delta, line) {
  process.stdout.write(asciiJson({
    hookSpecificOutput: {
      hookEventName: 'MessageDisplay',
      displayContent: delta + '\n\n' + line,
    },
  }));
}

function run(payload) {
  const session = payload.session_id || 'default';

  if (payload.hook_event_name === 'UserPromptSubmit') {
    // Print nothing: UserPromptSubmit stdout is injected into Claude's context.
    try { fs.writeFileSync(statePath(session), String(Date.now())); } catch (e) {}
    return;
  }

  if (payload.hook_event_name !== 'MessageDisplay' || payload.final !== true) return;

  const mode = opt('stamp_mode', 'once');
  if (mode === 'off') return;

  const delta = payload.delta;
  if (!delta) return;

  let start;
  try { start = parseFloat(fs.readFileSync(statePath(session), 'utf8').trim()); }
  catch (e) { return; }
  if (!isFinite(start)) return;

  const now = Date.now();
  if (now < start) return;

  // A turn emits one MessageDisplay per assistant message, and nothing at
  // display time reveals which will be the turn's last. Stamping all of them
  // buries the transcript, so by default only the first is stamped, showing the
  // start. Claude Code's own "Baked for" line closes the range.
  if (mode !== 'every') {
    const marker = statePath(session) + '.turn';
    const turn = String(payload.turn_id || '');
    try { if (fs.readFileSync(marker, 'utf8').trim() === turn) return; } catch (e) {}
    try { fs.writeFileSync(marker, turn); } catch (e) {}
    emit(delta, GLYPH + ' Started ' + clock(start));
    return;
  }

  const parts = [GLYPH];
  if (opt('show_duration', 'true') !== 'false') {
    parts.push('Baked for ' + human(now - start));
    parts.push('from ' + clock(start) + ' to ' + clock(now));
  } else {
    parts.push(clock(start) + ' to ' + clock(now));
  }
  if (opt('closing_line', 'true') !== 'false') {
    parts.push(DOT + ' ' + CLOSERS[Math.floor(Math.random() * CLOSERS.length)]);
  }
  emit(delta, parts.join(' '));
}

const chunks = [];
process.stdin.on('data', (c) => chunks.push(c));
process.stdin.on('end', () => {
  try { run(JSON.parse(Buffer.concat(chunks).toString('utf8'))); } catch (e) {}
  process.exit(0);
});
process.stdin.on('error', () => process.exit(0));
