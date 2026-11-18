#Requires -Version 7.0
param([Parameter(Mandatory)][string]$LuantiExe)

$ErrorActionPreference = 'Stop'
$exe = (Resolve-Path -LiteralPath $LuantiExe).Path
$game = (Get-Item "$PSScriptRoot/../..").FullName
$run = Join-Path $game ('local/mount-test-' + [Guid]::NewGuid().ToString('N'))
$world = Join-Path $run 'world'
$mods = Join-Path $world 'worldmods'
$null = New-Item -ItemType Directory -Path $mods
Copy-Item -LiteralPath "$PSScriptRoot/mounts" -Destination "$mods/mcwelly_mount_test" -Recurse
@'
gameid = mineclonia
backend = sqlite3
player_backend = sqlite3
auth_backend = sqlite3
mod_storage_backend = sqlite3
enable_damage = false
creative_mode = false
'@ | Set-Content "$world/world.mt"

$socket = [Net.Sockets.UdpClient]::new([Net.IPEndPoint]::new([Net.IPAddress]::Loopback, 0))
try { $port = $socket.Client.LocalEndPoint.Port } finally { $socket.Dispose() }
@"
port = $port
bind_address = 127.0.0.1
server_announce = false
mg_name = flat
mgflat_ground_level = 8
static_spawnpoint = (0,10,0)
mcl_levelgen_enable_ersatz = false
mobs_spawn = false
time_speed = 0
"@ | Set-Content "$run/server.conf"
@'
screen_w = 640
screen_h = 480
fps_max = 20
enable_sound = false
debug_log_level = warning
'@ | Set-Content "$run/client.conf"
$javaPack = Join-Path $game 'local/textures/mineclonia-java-26.3'
if (Test-Path -LiteralPath (Join-Path $javaPack 'texture_pack.conf')) {
    Add-Content "$run/client.conf" "texture_path = $javaPack"
}

function Start-Luanti([string]$Profile, [string[]]$Arguments) {
    $userPath = Join-Path $run $Profile
    $null = New-Item -ItemType Directory -Path $userPath
    $info = [Diagnostics.ProcessStartInfo]::new($exe)
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $info.WorkingDirectory = $run
    $info.Environment['LUANTI_USER_PATH'] = $userPath
    $info.Environment['LUANTI_GAME_PATH'] = Split-Path $game -Parent
    foreach ($argument in $Arguments) { $info.ArgumentList.Add($argument) }
    return [Diagnostics.Process]::Start($info)
}

$log = Join-Path $run 'server.log'
Write-Output "Mount test log: $log"
$server = Start-Luanti 'server' @('--server', '--gameid', 'mineclonia', '--world', $world,
    '--config', "$run/server.conf", '--logfile', $log)
$clients = @()
try {
    $deadline = (Get-Date).AddSeconds(120)
    while (!(Test-Path $log) -or !(Select-String -LiteralPath $log -SimpleMatch 'listening on' -Quiet)) {
        if ($server.HasExited -or (Get-Date) -gt $deadline) { throw "Mount test server did not start. See $log" }
        Start-Sleep -Milliseconds 500
    }
    foreach ($suffix in 'A', 'B') {
        $name = "MountTest$suffix"
        $clients += Start-Luanti $name @('--go', '--address', '127.0.0.1', '--port', "$port",
            '--name', $name, '--config', "$run/client.conf", '--logfile', "$run/client-$suffix.log")
    }
    if (!$server.WaitForExit(150000)) { throw "Mount test server timed out. See $log" }
    $results = (Select-String -LiteralPath $log -SimpleMatch '[mount test]').Line
    $results
    if ($server.ExitCode -ne 0 -or !($results -match '\[mount test\] TOTAL FAILURES 0$')) {
        throw "Mount test failed. See $log"
    }
    $mediaPattern = 'GenericCAO::addToScene\(\): Model .* is missing'
    $mediaWarnings = Select-String -LiteralPath "$run/client-A.log","$run/client-B.log" -Pattern $mediaPattern
    if ($mediaWarnings) { throw ($mediaWarnings.Line -join [Environment]::NewLine) }
} finally {
    foreach ($process in @($server) + $clients) {
        if (!$process.HasExited) { $process.Kill() }
        $process.Dispose()
    }
}
