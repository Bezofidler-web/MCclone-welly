#Requires -Version 7.0
param([string]$Engine = 'luanti', [int]$Port = 31746, [string]$OutputDirectory)

$ErrorActionPreference = 'Stop'
$game = Get-Item -LiteralPath (Join-Path $PSScriptRoot '../..')
$enginePath = (Get-Command $Engine -CommandType Application -ErrorAction Stop).Source
if (!$OutputDirectory) { $OutputDirectory = Join-Path $game.FullName 'local/test-runs' }
$run = [IO.Path]::GetFullPath((Join-Path $OutputDirectory ('mineclonia-player-test-' + [guid]::NewGuid().ToString('N'))))
$world = Join-Path $run 'world'
$mods = Join-Path $world 'worldmods'
$profile = Join-Path $run 'profile'
$null = New-Item -ItemType Directory -Path $mods, $profile
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'hud_player_probe') -Destination $mods -Recurse
@(
    "gameid = $($game.Name)"
    'backend = sqlite3'
    'player_backend = sqlite3'
    'auth_backend = sqlite3'
    'mod_storage_backend = sqlite3'
    'creative_mode = false'
) | Set-Content -LiteralPath (Join-Path $world 'world.mt')
$config = Join-Path $run 'probe.conf'
@("port = $Port", 'bind_address = 127.0.0.1', 'server_announce = false', 'mg_name = singlenode') |
    Set-Content -LiteralPath $config
$log = Join-Path $run 'server.log'
$start = [Diagnostics.ProcessStartInfo]::new($enginePath)
$start.UseShellExecute = $false
$start.CreateNoWindow = $true
$start.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
$start.WorkingDirectory = $run
$start.Environment['LUANTI_GAME_PATH'] = $game.Parent.FullName
$start.Environment['LUANTI_USER_PATH'] = $profile
foreach ($argument in @('--server', '--world', $world, '--config', $config, '--logfile', $log)) {
    $start.ArgumentList.Add($argument)
}
Write-Output "Test log: $log"
$server = [Diagnostics.Process]::Start($start)
try {
    if (!$server.WaitForExit(240000)) {
        $server.Kill()
        throw 'The test server timed out.'
    }
    $results = @(Select-String -LiteralPath $log -SimpleMatch '[hud_player_probe]')
    $results.Line
    if ($server.ExitCode -ne 0 -or !($results.Line -match '\[hud_player_probe\] TOTAL FAILURES 0$')) {
        Get-Content -LiteralPath $log -Tail 12
        throw 'The player gameplay checks failed.'
    }
} finally {
    $server.Dispose()
}
