#Requires -Version 7.0
param(
    [Parameter(Mandatory)][string]$LuantiExe,
    [ValidateSet('flat', 'v7', 'singlenode')][string]$Mapgen = 'flat',
    [switch]$Natural,
    [ValidateSet('overworld', 'nether', 'ocean', 'end', 'river')][string]$Region = 'overworld'
)

$ErrorActionPreference = 'Stop'
$exe = (Resolve-Path -LiteralPath $LuantiExe).Path
$game = (Get-Item "$PSScriptRoot/../..").FullName
$run = Join-Path $game ('local/expeditions-test-' + [Guid]::NewGuid().ToString('N'))
$world = Join-Path $run 'world'
$mods = Join-Path $world 'worldmods'
$userPath = Join-Path $run 'user'
$null = New-Item -ItemType Directory -Path $mods,$userPath
Copy-Item -LiteralPath "$PSScriptRoot/expeditions" -Destination "$mods/mcwelly_expeditions_test" -Recurse
@'
gameid = mineclonia
backend = sqlite3
mod_storage_backend = sqlite3
'@ | Set-Content "$world/world.mt"
$socket = [Net.Sockets.UdpClient]::new([Net.IPEndPoint]::new([Net.IPAddress]::Loopback, 0))
try { $port = $socket.Client.LocalEndPoint.Port } finally { $socket.Dispose() }
@"
port = $port
bind_address = 127.0.0.1
server_announce = false
mg_name = $Mapgen
mgflat_ground_level = 13
fixed_map_seed = 20261113
static_spawnpoint = (0,25,0)
mcl_levelgen_enable_ersatz = $(if ($Mapgen -eq 'v7') { 'true' } else { 'false' })
mcl_singlenode_mapgen = $(if ($Mapgen -eq 'singlenode') { 'true' } else { 'false' })
mcwelly_test_natural_expeditions = $($Natural.IsPresent.ToString().ToLowerInvariant())
mcwelly_test_expedition_region = $Region
mobs_spawn = $(if ($Natural -and $Region -eq 'river') { 'true' } else { 'false' })
num_emerge_threads = 2
debug_log_level = info
"@ | Set-Content "$run/server.conf"

$log = Join-Path $run 'server.log'
Write-Output "Expedition test log: $log"
$info = [Diagnostics.ProcessStartInfo]::new($exe)
$info.UseShellExecute = $false
$info.CreateNoWindow = $true
$info.WorkingDirectory = $run
$info.Environment['LUANTI_USER_PATH'] = $userPath
$info.Environment['LUANTI_GAME_PATH'] = Split-Path $game -Parent
foreach ($argument in '--server','--gameid','mineclonia','--world',$world,'--config',"$run/server.conf",'--logfile',$log) {
    $info.ArgumentList.Add($argument)
}
$server = [Diagnostics.Process]::Start($info)
try {
    if (!$server.WaitForExit(360000)) { throw "Expedition test timed out. See $log" }
    $results = (Select-String -LiteralPath $log -SimpleMatch '[expeditions test]').Line
    $results
    $success = if ($Natural) { 'NATURAL GENERATION PASSED$' } else { 'ALL STRUCTURES PASSED$' }
    if ($server.ExitCode -ne 0 -or !($results -match $success)) {
        Get-Content -LiteralPath $log -Tail 16
        throw "Expedition test failed. See $log"
    }
} finally {
    if (!$server.HasExited) { $server.Kill() }
    $server.Dispose()
}
