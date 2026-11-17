#Requires -Version 7.0
param([Parameter(Mandatory)][string]$LuantiExe)
$ErrorActionPreference = 'Stop'
$exe = (Resolve-Path -LiteralPath $LuantiExe).Path
$game = (Get-Item "$PSScriptRoot/../../..").FullName
$run = Join-Path $game ("local/gameplay-test-" + [Guid]::NewGuid().ToString('N'))
$world = Join-Path $run 'world'
$mod = Join-Path $world 'worldmods/mcwelly_gameplay_test'
$userPath = Join-Path $run 'user'
New-Item -ItemType Directory -Path $mod,$userPath | Out-Null
Copy-Item -LiteralPath "$PSScriptRoot/init.lua","$PSScriptRoot/mod.conf" -Destination $mod
@'
gameid = mineclonia
backend = sqlite3
player_backend = sqlite3
auth_backend = sqlite3
mod_storage_backend = sqlite3
load_mod_mcwelly_gameplay_test = true
'@ | Set-Content "$world/world.mt"

$socket = [Net.Sockets.UdpClient]::new([Net.IPEndPoint]::new([Net.IPAddress]::Loopback, 0))
try { $port = $socket.Client.LocalEndPoint.Port } finally { $socket.Dispose() }
@"
bind_address = 127.0.0.1
port = $port
server_announce = false
ipv6_server = false
mg_name = v7
mobs_spawn = false
"@ | Set-Content "$run/server.conf"
$log = Join-Path $run 'server.log'
$info = [Diagnostics.ProcessStartInfo]::new($exe)
$info.UseShellExecute = $false
$info.CreateNoWindow = $true
$info.WorkingDirectory = $run
$info.Environment['LUANTI_USER_PATH'] = $userPath
$info.Environment['LUANTI_GAME_PATH'] = Split-Path $game -Parent
foreach ($argument in '--server','--gameid','mineclonia','--world',$world,'--config',"$run/server.conf",'--logfile',$log) {
    $info.ArgumentList.Add($argument)
}
$proc = [Diagnostics.Process]::Start($info)
try {
    if (-not $proc.WaitForExit(240000)) { throw "Gameplay test timed out. See $log" }
    if ($proc.ExitCode -ne 0 -or -not (Select-String -LiteralPath $log -SimpleMatch 'GAMEPLAY TEST PASSED' -Quiet)) {
        throw "Gameplay test failed. See $log"
    }
    Select-String -LiteralPath $log -SimpleMatch 'GAMEPLAY TEST' | ForEach-Object Line
    Write-Output $log
} finally {
    if (-not $proc.HasExited) { $proc.Kill() }
    $proc.Dispose()
}
