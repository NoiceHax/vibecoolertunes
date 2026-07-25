# Play one notification tone on Windows.
#
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File play.ps1 <name>
#
# Always exits 0. Silence is the correct outcome when there is no audio
# device, not an error worth surfacing to the user.
#
# Set CCTONES_DEBUG=1 to print why a tone did or did not play.

param([string]$Name)

$ErrorActionPreference = 'SilentlyContinue'

function Trace($msg) { if ($env:CCTONES_DEBUG) { Write-Host "[tones] $msg" } }

# PowerShell 7 on macOS or Linux: let play.sh handle those platforms.
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) { exit 0 }
if (-not $Name) { exit 0 }

# Terminal emulators that host a console over a pseudoconsole sit outside our
# process ancestry, and under Windows 11 default-terminal handoff they set no
# identifying environment variable either. Name matching is the only link left.
# See the README for the multi-window caveat this implies.
$TERMINALS = @(
    'WindowsTerminal', 'WindowsTerminalPreview', 'OpenConsole', 'conhost',
    'cmd', 'powershell', 'pwsh', 'alacritty', 'wezterm-gui', 'mintty',
    'Hyper', 'ConEmu', 'ConEmu64', 'Code', 'Cursor'
)

# Returns $true only when the terminal can be shown to have focus. Anything
# undetermined counts as unfocused so the tone still plays: a missed
# notification is worse than one you did not need.
#
# Deliberately avoids enumerating processes for an ancestry walk. That costs
# well over a second on Windows and catches nothing the name check above misses,
# and a notification that arrives a second late is a worse bug than an
# occasional extra chime.
function Test-TerminalFocused {
    try {
        Add-Type -Namespace CCTones -Name Win -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
'@ -ErrorAction Stop

        $fh = [CCTones.Win]::GetForegroundWindow()
        if ($fh -eq [IntPtr]::Zero) { Trace 'no foreground window'; return $false }
        $fg = 0
        [void][CCTones.Win]::GetWindowThreadProcessId($fh, [ref]$fg)
        if ($fg -eq 0) { Trace 'no foreground pid'; return $false }

        # 1. Exact: the focused window is our own console host.
        $ch = [CCTones.Win]::GetConsoleWindow()
        if ($ch -ne [IntPtr]::Zero) {
            $cp = 0
            [void][CCTones.Win]::GetWindowThreadProcessId($ch, [ref]$cp)
            if ($cp -ne 0 -and $cp -eq $fg) { Trace "focused: own console host (pid $cp)"; return $true }
        }

        # 2. Inexact: a terminal has focus and we cannot prove it is not ours.
        $fgName = (Get-Process -Id $fg -ErrorAction Stop).ProcessName
        if ($TERMINALS -contains $fgName) { Trace "focused: terminal '$fgName' (pid $fg)"; return $true }

        Trace "not focused: foreground is '$fgName' (pid $fg)"
        return $false
    } catch {
        Trace "focus check failed, treating as unfocused: $_"
        return $false
    }
}

# Optional user config, supplied by Claude Code as env vars.
if ($Name -eq 'complete' -and $env:CLAUDE_PLUGIN_OPTION_TASK_COMPLETE_TONE -eq 'false') {
    Trace 'completion tone disabled'; exit 0
}
if ($Name -eq 'question' -and $env:CLAUDE_PLUGIN_OPTION_QUESTION_STYLE -eq 'descending') {
    $Name = 'question-descending'
}
if ($env:CLAUDE_PLUGIN_OPTION_ONLY_WHEN_UNFOCUSED -ne 'false') {
    if (Test-TerminalFocused) { Trace "suppressed '$Name'"; exit 0 }
} else {
    Trace 'focus gating disabled'
}

$file = Join-Path (Split-Path -Parent $PSScriptRoot) "sounds\$Name.wav"
if (-not (Test-Path $file)) { Trace "missing sound file: $file"; exit 0 }

try {
    Trace "playing $Name"
    $player = New-Object System.Media.SoundPlayer $file
    $player.PlaySync()
} catch {
    Trace "playback failed: $_"
}

exit 0
