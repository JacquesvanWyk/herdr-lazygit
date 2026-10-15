# Windows twin of open-lazygit.sh / open-lazygit-tab.sh. Needs only PowerShell and
# lazygit (no jq, no bash): the toggle reads `herdr pane list` with ConvertFrom-Json.
#
#   -Placement split   OPEN in a split pane / FOCUS (zoom on/off) / CLOSE if focused
#   -Placement tab     OPEN in its own tab / FOCUS / SWITCHTAB (same workspace) / CLOSE
param([ValidateSet('split', 'tab')][string]$Placement = 'split')

$ErrorActionPreference = 'Stop'
# Without a console attached (a detached launch) setting this throws; the toggle still works.
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

$herdr = if ($env:HERDR_BIN_PATH) { $env:HERDR_BIN_PATH } else { 'herdr' }

# Ids must be flag-safe (never start with "-") before they reach an argv.
function Test-SafeId($id) {
    # \z, not $: in .NET `$` also matches before a trailing newline.
    return ($id -is [string]) -and ($id -match '^[A-Za-z0-9_:.][A-Za-z0-9_:.-]*\z')
}

function Get-Panes {
    try {
        $out = (& $herdr pane list) -join "`n"
        if (-not $out.Trim()) { return @() }
        return @((ConvertFrom-Json $out).result.panes)
    } catch {
        return @()
    }
}

# Root lazygit at the invoking pane's directory, not the plugin install dir (herdr
# starts pane commands from the plugin root). Context JSON is injected by herdr on
# action invoke; fall back to the focused pane's cwd, then the home directory.
function Get-TargetCwd($panes) {
    $cwd = ''
    try {
        $ctx = ConvertFrom-Json $env:HERDR_PLUGIN_CONTEXT_JSON
        foreach ($name in 'focused_pane_cwd', 'workspace_cwd', 'cwd') {
            if ($ctx.$name) { $cwd = $ctx.$name; break }
        }
    } catch {}
    if (-not $cwd) {
        $focused = $panes | Where-Object { $_.focused -eq $true } | Select-Object -First 1
        if ($focused -and $focused.cwd) { $cwd = $focused.cwd }
    }
    if (-not $cwd -or -not (Test-Path -LiteralPath $cwd -PathType Container)) { $cwd = $HOME }
    # Windows PowerShell 5.1 quotes a path with spaces as "C:\My Dir\", and the trailing
    # backslash then escapes the closing quote. Drive roots (C:\) have no space to quote.
    if ($cwd.Length -gt 3) { $cwd = $cwd.TrimEnd('\') }
    return $cwd
}

function Open-Lazygit($panes) {
    $openArgs = @('plugin', 'pane', 'open', '--plugin', 'herdr-lazygit', '--entrypoint', 'lazygit')
    if ($Placement -eq 'tab') {
        $openArgs += @('--placement', 'tab', '--focus')
    } else {
        $openArgs += @('--placement', 'split', '--direction', 'right', '--focus')
    }
    $openArgs += @('--cwd', (Get-TargetCwd $panes))
    & $herdr @openArgs
    exit $LASTEXITCODE
}

# Workspace is the prefix of an id ("w1:t2" -> "w1").
function Get-Workspace($pane) {
    $id = if ($pane.tab_id) { $pane.tab_id } else { $pane.pane_id }
    $parts = "$id".Split(':')
    if ($parts.Count -gt 1 -and $parts[0]) { return $parts[0] }
    return $null
}

$panes = Get-Panes
$focused = $panes | Where-Object { $_.focused -eq $true } | Select-Object -First 1
if (-not $focused) { Open-Lazygit $panes }

$lazygits = @($panes | Where-Object { $_.label -ceq 'lazygit' })
$here = $lazygits | Where-Object { $_.tab_id -eq $focused.tab_id } | Select-Object -First 1

if ($here -and (Test-SafeId $here.pane_id)) {
    if ($here.pane_id -eq $focused.pane_id) {
        & $herdr pane close $here.pane_id
        exit $LASTEXITCODE
    }
    # Zoom-on may fail (already zoomed); under -Stop its stderr must not end the script.
    try { & $herdr pane zoom $here.pane_id --on *> $null } catch {}
    & $herdr pane zoom $here.pane_id --off
    exit $LASTEXITCODE
}

# A lazygit pane in another tab of the same workspace is only reused in tab mode, and
# one in another workspace is ignored rather than yanking the user there.
if ($Placement -eq 'tab' -and -not $here) {
    $ws = Get-Workspace $focused
    $elsewhere = $lazygits | Where-Object { $ws -and (Get-Workspace $_) -eq $ws } | Select-Object -First 1
    if ($elsewhere -and (Test-SafeId $elsewhere.tab_id)) {
        & $herdr tab focus $elsewhere.tab_id
        if ($LASTEXITCODE -eq 0) { exit 0 }
    }
}

Open-Lazygit $panes
