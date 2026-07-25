# Append a wall-clock range to Claude Code's turn output. Windows twin of
# stamp.py; see that file for the full explanation.
#
# Handles UserPromptSubmit (record start, print nothing) and MessageDisplay
# (append the range to the shown text). Every failure path exits 0 without
# printing, leaving the message exactly as it would have displayed.

$ErrorActionPreference = 'SilentlyContinue'

# stamp.py owns macOS and Linux.
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) { exit 0 }

$GLYPH = [char]0x273B   # six-petal asterisk, matching Claude Code
$DOT   = [char]0x00B7

$CLOSERS = @(
    'still warm', 'fresh out the oven', 'cooled and plated', 'no notes',
    'worth the wait', 'let it rest', "chef's kiss", 'crumbs everywhere',
    'second helpings?', 'hot and ready', 'off the heat', 'seasoned to taste',
    'risen nicely', 'golden on top', 'one for the road'
)

function Opt($name, $default) {
    $v = [Environment]::GetEnvironmentVariable("CLAUDE_PLUGIN_OPTION_$($name.ToUpper())")
    if ([string]::IsNullOrEmpty($v)) { return $default }
    return $v
}

function StateDir {
    $base = $env:CLAUDE_PLUGIN_DATA
    if (-not $base) { $base = Join-Path $env:TEMP 'claude-turn-timeline' }
    if (-not (Test-Path $base)) { New-Item -ItemType Directory -Path $base -Force | Out-Null }
    return $base
}

function StatePath($session) {
    $safe = ($session -replace '[^A-Za-z0-9\-_]', '')
    if ($safe.Length -gt 64) { $safe = $safe.Substring(0, 64) }
    if (-not $safe) { $safe = 'default' }
    return (Join-Path (StateDir) "start-$safe")
}

function Clock($dt) {
    if ((Opt 'clock_format' '12') -eq '24') { return $dt.ToString('HH:mm:ss') }
    return $dt.ToString('h:mm:ss tt').ToLower()
}

function Human($seconds) {
    $s = [int][Math]::Round($seconds)
    if ($s -lt 60) { return "${s}s" }
    $m = [int][Math]::Floor($s / 60); $s = $s % 60
    if ($m -lt 60) { return "${m}m ${s}s" }
    $h = [int][Math]::Floor($m / 60); $m = $m % 60
    return "${h}h ${m}m ${s}s"
}

# Escape every non-ASCII char so the emitted JSON is byte-safe regardless of
# the console code page.
function AsciiJson($obj) {
    $json = $obj | ConvertTo-Json -Depth 6 -Compress
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $json.ToCharArray()) {
        if ([int]$ch -gt 127) { [void]$sb.AppendFormat('\u{0:x4}', [int]$ch) }
        else { [void]$sb.Append($ch) }
    }
    return $sb.ToString()
}

try {
    # Read stdin as UTF-8 explicitly. [Console]::In uses the console code page,
    # which on a cp437/cp850 box silently mangles every non-ASCII character in
    # the message: an em dash round-trips to "ΓÇö", an accented e to "├⌐".
    $stdinStream = [Console]::OpenStandardInput()
    $reader = New-Object System.IO.StreamReader(
        $stdinStream, (New-Object System.Text.UTF8Encoding($false)))
    $raw = $reader.ReadToEnd()
    if (-not $raw) { exit 0 }
    $p = $raw | ConvertFrom-Json
} catch { exit 0 }

$session = if ($p.session_id) { $p.session_id } else { 'default' }

if ($p.hook_event_name -eq 'UserPromptSubmit') {
    # Print nothing: UserPromptSubmit stdout is injected into Claude's context.
    try {
        [System.IO.File]::WriteAllText((StatePath $session),
            [string]([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() / 1000.0))
    } catch { }
    exit 0
}

if ($p.hook_event_name -ne 'MessageDisplay') { exit 0 }
if ($p.final -ne $true) { exit 0 }
if (-not $p.delta) { exit 0 }

try {
    $startEpoch = [double]([System.IO.File]::ReadAllText((StatePath $session)).Trim())
} catch { exit 0 }

$nowEpoch = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() / 1000.0
if ($nowEpoch -lt $startEpoch) { exit 0 }

$start = [DateTimeOffset]::FromUnixTimeMilliseconds([long]($startEpoch * 1000)).LocalDateTime
$now   = [DateTimeOffset]::FromUnixTimeMilliseconds([long]($nowEpoch   * 1000)).LocalDateTime

$parts = @("$GLYPH")
if ((Opt 'show_duration' 'true') -ne 'false') {
    $parts += "Baked for $(Human ($nowEpoch - $startEpoch))"
    $parts += "from $(Clock $start) to $(Clock $now)"
} else {
    $parts += "$(Clock $start) to $(Clock $now)"
}
if ((Opt 'closing_line' 'true') -ne 'false') {
    $parts += "$DOT $($CLOSERS | Get-Random)"
}

$line = $parts -join ' '

$out = @{
    hookSpecificOutput = @{
        hookEventName  = 'MessageDisplay'
        displayContent = "$($p.delta)`n`n$line"
    }
}

Write-Output (AsciiJson $out)
exit 0
