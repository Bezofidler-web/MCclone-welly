#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$LuantiExe,
    [string]$Config = (Join-Path $PSScriptRoot '..\local\friends-server.conf'),
    [string]$World = (Join-Path $PSScriptRoot '..\local\world')
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $Config -PathType Leaf)) {
    throw 'Copy friends-server.conf.example to local/friends-server.conf and set up the host account first. See FRIENDS.md.'
}

$exe = (Resolve-Path -LiteralPath $LuantiExe).Path
$configPath = (Resolve-Path -LiteralPath $Config).Path
$worldPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($World)
$log = Join-Path (Split-Path $configPath -Parent) 'server.log'
$game = Split-Path $PSScriptRoot -Parent
$gameId = (Split-Path $game -Leaf) -creplace '(.+)_game$', '$1'
$gamePath = Split-Path $game -Parent

$oldLuantiGamePath = $env:LUANTI_GAME_PATH
$oldMinetestGamePath = $env:MINETEST_GAME_PATH
$start = [Diagnostics.ProcessStartInfo]::new($exe)
foreach ($argument in '--server', '--console', '--gameid', $gameId, '--config', $configPath, '--world', $worldPath, '--logfile', $log) {
    $start.ArgumentList.Add($argument)
}
try {
    $env:LUANTI_GAME_PATH = $gamePath
    $env:MINETEST_GAME_PATH = $gamePath
    $server = [Diagnostics.Process]::Start($start)
    try {
        $server.WaitForExit()
        if ($server.ExitCode -ne 0) { throw "Luanti exited with code $($server.ExitCode). See $log." }
    } finally {
        $server.Dispose()
    }
} finally {
    $env:LUANTI_GAME_PATH = $oldLuantiGamePath
    $env:MINETEST_GAME_PATH = $oldMinetestGamePath
}
